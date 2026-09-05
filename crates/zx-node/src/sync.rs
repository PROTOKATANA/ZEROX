//! Sincronización headers-first (SPEC §16.1, C-NET-03, C-NET-04).
//!
//! # Por qué cabeceras primero
//!
//! Una cabecera de ZEROX mide **92 bytes**. Un cuerpo típico, **100-200 KB**. La relación es de
//! ~1:1000, y validar el PoW de una cabecera cuesta **un SHA3-256**.
//!
//! Descargar cuerpos para descubrir después que la cadena no llevaba a ninguna parte cuesta mil
//! veces más ancho de banda por bloque. Por eso C-NET-03 lo prohíbe: **el cuerpo no se pide hasta
//! validar la cabecera**.
//!
//! ⚠️ Y conviene dejar escrito que **Zebra NO hace esto**. Pide hashes con `getblocks` y compensa
//! acotando altura y memoria al descargar cuerpos. Nuestra hoja de ruta lo citaba como referencia y
//! era falso — verificado en `zebra@b685fbe3`. La decisión de ZEROX se sostiene por la aritmética
//! de arriba, no por a quién copia.
//!
//! # Las tres fases, y por qué no hay más
//!
//! ```text
//! Saludando ──▶ Cabeceras ──▶ Cuerpos ──▶ AlDia
//!      ▲                                    │
//!      └────────────────────────────────────┘
//! ```
//!
//! Zebra, en cambio, **no tiene enum de estados**: su bucle repite `try_to_sync()` indefinidamente
//! y decide "estoy al día" con una media móvil de las últimas 3 respuestas. Es más simple de
//! escribir y más difícil de razonar: no hay un sitio donde mirar para saber qué está haciendo el
//! nodo. Con un enum, sí.

use std::collections::VecDeque;

use libp2p::PeerId;
use primitive_types::U256;
use zx_consensus::antidos;
use zx_core::digest::BlockHash;
use zx_core::preimage::block::BlockHeader;
use zx_core::target::{CompactBits, cumple_pow, trabajo_bloque};

/// Cuántas respuestas seguidas con poco progreso hacen concluir que estamos al día.
///
/// Es la señal de Zebra —media móvil de las últimas respuestas— con un umbral propio, y **no
/// comparar alturas con el peer** sigue siendo lo correcto: la altura la elige él.
///
/// ⚠️ **Pero lo que se cuenta son las cabeceras APLICADAS, no las recibidas.** La primera versión
/// contaba `cs.len()` de la respuesta cruda, y el docstring afirmaba que "que deje de mandarte
/// cabeceras nuevas no se puede fingir". **Era falso**: un peer bastaba con mandar tres respuestas
/// cortas de basura —cabeceras con `prev_hash` inventado, que ni se validan— para que el nodo
/// concluyera `AlDia` **habiendo aplicado cero**, potencialmente seguido en el génesis. Y un nodo
/// que se cree sincronizado sin estarlo es lo que un monedero consulta antes de dar un pago por
/// bueno.
///
/// Contar lo aplicado sí es infalsificable: aplicar una cabecera exige que encadene, que su `bits`
/// sea canónico y que satisfaga su PoW.
pub const RESPUESTAS_CORTAS_PARA_AL_DIA: usize = 3;

/// Por debajo de cuántas cabeceras una respuesta cuenta como "corta".
pub const UMBRAL_RESPUESTA_CORTA: usize = 20;

/// En qué anda el sincronizador.
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Fase {
    /// Preguntando a los peers dónde están.
    Saludando,
    /// Descargando y validando cabeceras. **Todavía no se pide ningún cuerpo** (C-NET-03).
    Cabeceras,
    /// Cabeceras validadas; descargando los cuerpos que faltan.
    ///
    /// Se entra aquí cuando las cabeceras están al día y quedan cuerpos por descargar, y se sale a
    /// [`Fase::AlDia`] cuando no falta ninguno. Un nodo que reinicia con las cabeceras guardadas y
    /// los cuerpos a medias entra aquí directamente desde el saludo, sin pasar por
    /// [`Fase::Cabeceras`]: no le falta cadena, le faltan cuerpos.
    Cuerpos,
    /// Al día. Los bloques nuevos llegan por difusión, no por sincronización.
    AlDia,
}

/// Por qué se rechazó una cadena de cabeceras.
///
/// Se distinguen porque **tienen políticas distintas** (C-NET-05): solo una es atribuible a mala fe.
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum RechazoCabeceras {
    /// No encadenan: el `prev_hash` de una no es el hash de la anterior. **Mala fe.**
    NoEncadenan,
    /// Alguna no satisface su propio `bits`. **Mala fe**: fabricar esto cuesta trabajo real.
    PowInvalido,
    /// `bits` no canónico (C-POW-04). **Mala fe.**
    BitsNoCanonico,
    /// No demuestra trabajo suficiente para merecer memoria (C-NET-04).
    ///
    /// **NO es mala fe.** Un peer que va por detrás propone exactamente esto, y penalizarlo sería
    /// castigar a todo el que tenga menos cadena que nosotros.
    TrabajoInsuficiente,
    /// No arranca donde dijimos. Puede ser desincronización, no ataque.
    NoContinuaElLocator,
    /// El `bits` no es el que el retarget exige a esa altura (C-BLK-05, C-DIFF-09). **Mala fe.**
    ///
    /// No hay forma inocente de traer esto: el retarget es una función pura de la ventana
    /// (C-DIFF-01), así que dos nodos con los mismos ancestros calculan el mismo valor. Un `bits`
    /// distinto es una cadena que el resto de la red no acepta.
    DificultadIncorrecta,
    /// Faltan ancestros para reconstruir la ventana del retarget.
    ///
    /// **NO es mala fe**, es una limitación nuestra: no podemos juzgar lo que no podemos calcular.
    VentanaIncompleta,
}

impl RechazoCabeceras {
    /// ¿Es esto atribuible a mala fe del peer?
    ///
    /// La distinción no es cosmética: alimenta la política de C-NET-05. `TrabajoInsuficiente` es la
    /// respuesta normal de cualquiera que vaya por detrás, y tratarla como ataque desconectaría
    /// precisamente a los nodos que más necesitan sincronizar.
    #[must_use]
    pub const fn es_mala_fe(self) -> bool {
        matches!(
            self,
            Self::NoEncadenan
                | Self::PowInvalido
                | Self::BitsNoCanonico
                | Self::DificultadIncorrecta
        )
    }
}

/// Estado del sincronizador.
#[derive(Debug)]
pub struct Sincronizador {
    fase: Fase,
    /// Longitud de las últimas respuestas, para decidir si estamos al día.
    recientes: VecDeque<usize>,
    /// De quién estamos descargando ahora.
    peer: Option<PeerId>,
}

impl Default for Sincronizador {
    fn default() -> Self {
        Self::nuevo()
    }
}

impl Sincronizador {
    /// Uno recién arrancado, saludando.
    #[must_use]
    pub fn nuevo() -> Self {
        Self {
            fase: Fase::Saludando,
            recientes: VecDeque::with_capacity(RESPUESTAS_CORTAS_PARA_AL_DIA),
            peer: None,
        }
    }

    /// En qué fase está.
    #[must_use]
    pub const fn fase(&self) -> Fase {
        self.fase
    }

    /// De quién descarga.
    #[must_use]
    pub const fn peer(&self) -> Option<PeerId> {
        self.peer
    }

    /// Un peer dijo dónde está. Decide si hay que sincronizar de él.
    ///
    /// La comparación es por **trabajo acumulado**, no por altura: la altura la elige el peer y
    /// puede mentir, mientras que fabricar trabajo cuesta trabajo. Es la misma razón por la que el
    /// fork choice usa trabajo y no longitud.
    pub fn saludo_recibido(&mut self, peer: PeerId, trabajo_peer: U256, trabajo_propio: U256) {
        if trabajo_peer > trabajo_propio {
            self.peer = Some(peer);
            self.fase = Fase::Cabeceras;
            self.recientes.clear();
        } else if self.fase == Fase::Saludando {
            // Nadie por delante: ya estamos al día. No es un caso raro — es el estado normal de un
            // nodo que lleva rato encendido.
            self.fase = Fase::AlDia;
        }
    }

    /// El peer del que descargábamos se fue o falló.
    ///
    /// Se vuelve a saludar en vez de dar por perdida la sincronización: otro peer puede tener la
    /// misma cadena. **No se penaliza** — que un peer se caiga no es mala fe (C-NET-05).
    pub fn peer_perdido(&mut self, peer: PeerId) {
        if self.peer == Some(peer) {
            self.peer = None;
            self.fase = Fase::Saludando;
            self.recientes.clear();
        }
    }

    /// Registra **cuántas cabeceras se aplicaron de verdad** y decide si ya estamos al día.
    ///
    /// El parámetro **MUST** ser el número que `extender()` incorporó, no el que llegó por la red.
    /// Ver la nota de [`RESPUESTAS_CORTAS_PARA_AL_DIA`] sobre por qué la diferencia es un fallo de
    /// seguridad y no de estilo.
    ///
    /// Devuelve `true` si se concluye que estamos al día.
    pub fn respuesta_registrada(&mut self, aplicadas: usize) -> bool {
        if self.recientes.len() == RESPUESTAS_CORTAS_PARA_AL_DIA {
            self.recientes.pop_front();
        }
        self.recientes.push_back(aplicadas);

        let completa = self.recientes.len() == RESPUESTAS_CORTAS_PARA_AL_DIA;
        let todas_cortas = self.recientes.iter().all(|n| *n < UMBRAL_RESPUESTA_CORTA);

        if completa && todas_cortas {
            self.fase = Fase::AlDia;
            true
        } else {
            false
        }
    }

    /// Pasa a descargar cuerpos. **Solo se llama tras validar las cabeceras** (C-NET-03).
    ///
    /// Se acepta desde cualquier fase, no solo desde [`Fase::Cabeceras`]: un nodo que reinicia con
    /// las cabeceras completas concluye `AlDia` en el saludo y aun así puede tener cuerpos que
    /// bajar.
    pub const fn descargando_cuerpos(&mut self) {
        self.fase = Fase::Cuerpos;
    }

    /// No falta ningún cuerpo: la sincronización terminó.
    pub const fn cuerpos_al_dia(&mut self) {
        if matches!(self.fase, Fase::Cuerpos) {
            self.fase = Fase::AlDia;
        }
    }
}

/// Comprueba la **estructura** de una cadena de cabeceras: que continúe el ancla, que encadenen, y
/// que cada `bits` sea canónico. Devuelve el trabajo que la cadena *declara*.
///
/// **No comprueba el PoW.** Va aparte —ver [`comprobar_pow`]— porque son dos cosas de coste muy
/// distinto: esto es comparar bytes, aquello es hashear. Separarlas permite descartar basura
/// estructural sin gastar un solo SHA3, y permite además testear cada una a fondo.
///
/// # Errores
/// [`RechazoCabeceras::NoContinuaElLocator`], [`RechazoCabeceras::NoEncadenan`] o
/// [`RechazoCabeceras::BitsNoCanonico`].
pub fn validar_estructura(
    cabeceras: &[BlockHeader],
    ancla: BlockHash,
) -> Result<U256, RechazoCabeceras> {
    let Some(primera) = cabeceras.first() else {
        // Una respuesta vacía es legítima: "no tengo nada después de tu locator".
        return Ok(U256::zero());
    };
    if primera.prev_hash != ancla {
        return Err(RechazoCabeceras::NoContinuaElLocator);
    }

    let mut acumulado = U256::zero();
    let mut anterior: Option<BlockHash> = None;

    for c in cabeceras {
        if let Some(prev) = anterior
            && c.prev_hash != prev
        {
            return Err(RechazoCabeceras::NoEncadenan);
        }
        // C-POW-04 · canonicidad primero: es comparar bytes, y descarta basura gratis.
        let target = CompactBits::from_u32(c.bits)
            .decodificar()
            .map_err(|_| RechazoCabeceras::BitsNoCanonico)?;

        acumulado = trabajo_bloque(target)
            .and_then(|w| acumulado.checked_add(w))
            .ok_or(RechazoCabeceras::BitsNoCanonico)?;

        anterior = Some(c.block_hash());
    }
    Ok(acumulado)
}

/// Comprueba que cada cabecera **satisface su propio `bits`** (C-POW-01).
///
/// # Errores
/// [`RechazoCabeceras::PowInvalido`] en la primera que no lo cumpla, o
/// [`RechazoCabeceras::BitsNoCanonico`] si `bits` no decodifica.
pub fn comprobar_pow(cabeceras: &[BlockHeader]) -> Result<(), RechazoCabeceras> {
    for c in cabeceras {
        let target = CompactBits::from_u32(c.bits)
            .decodificar()
            .map_err(|_| RechazoCabeceras::BitsNoCanonico)?;
        if !cumple_pow(&c.block_hash(), target) {
            return Err(RechazoCabeceras::PowInvalido);
        }
    }
    Ok(())
}

/// Valida una cadena de cabeceras **antes** de reservarle memoria (C-NET-03, C-NET-04).
///
/// Compone los tres filtros en orden de coste creciente, que es el orden que importa:
///
/// 1. [`validar_estructura`] — comparar bytes. Descarta basura sin hashear nada.
/// 2. [`comprobar_pow`] — un SHA3-256 por cabecera.
/// 3. **C-NET-04** — el umbral anti-DoS, que necesita la cadena entera recorrida.
///
/// # Lo que esta función NO hace
///
/// **No comprueba la dificultad esperada.** Que `bits` sea el que LWMA exige a esa altura depende
/// de la ventana de 90 cabeceras anteriores, y esta función es pura sobre el lote: no ve la cadena.
/// Decirlo importa: **pasar este filtro no significa que la cadena sea válida**, solo que merece la
/// memoria de examinarla.
///
/// Eso **sí** se comprueba ahora, un paso más allá, en [`crate::dificultad::comprobar_dificultad`]
/// (C-NET-22), que es quien tiene acceso a la cadena para armar la ventana. Durante un tiempo no lo
/// comprobó nadie, y ese fue el hueco: un peer podía servir cabeceras con cualquier `bits` canónico
/// más barato del que toca y el nodo las adoptaba.
///
/// # El trabajo se cuenta desde el ANCLA, no desde el tip
///
/// `trabajo_hasta_ancla` es el trabajo acumulado de **nuestra** cadena hasta el punto del que
/// cuelgan estas cabeceras, que es un hash de nuestro propio locator y **puede estar muy por debajo
/// de la punta**.
///
/// La primera versión de esta función sumaba al trabajo del **tip**, y un test lo cazó: con esa
/// cuenta, una bifurcación que colgara de hace cinco mil bloques sumaba el trabajo de una cadena
/// que **no es la suya** y superaba el umbral siempre. Es decir, la defensa de C-NET-04 quedaba
/// desactivada precisamente para el caso que existe para cubrir — una rama larga y barata.
///
/// # Errores
/// El [`RechazoCabeceras`] correspondiente. Solo algunos son atribuibles a mala fe: ver
/// [`RechazoCabeceras::es_mala_fe`].
pub fn validar_cadena_de_cabeceras(
    cabeceras: &[BlockHeader],
    ancla: BlockHash,
    trabajo_hasta_ancla: U256,
    trabajo_tip: U256,
    trabajo_de_un_bloque: U256,
) -> Result<U256, RechazoCabeceras> {
    let acumulado = validar_estructura(cabeceras, ancla)?;
    if cabeceras.is_empty() {
        return Ok(acumulado);
    }
    comprobar_pow(cabeceras)?;

    // El trabajo TOTAL de la cadena que el peer propone: lo que compartimos hasta el ancla, más lo
    // que él añade. Eso es lo que se compara con el umbral.
    let total_candidata = trabajo_hasta_ancla.saturating_add(acumulado);
    if !antidos::merece_memoria(total_candidata, trabajo_tip, trabajo_de_un_bloque) {
        return Err(RechazoCabeceras::TrabajoInsuficiente);
    }
    Ok(acumulado)
}

#[cfg(test)]
#[expect(
    clippy::unwrap_used,
    clippy::expect_used,
    reason = "los tests fallan con panic por diseño"
)]
mod tests {
    use super::{
        Fase, RESPUESTAS_CORTAS_PARA_AL_DIA, RechazoCabeceras, Sincronizador,
        UMBRAL_RESPUESTA_CORTA, comprobar_pow, validar_cadena_de_cabeceras, validar_estructura,
    };
    use libp2p::PeerId;
    use primitive_types::U256;
    use zx_core::digest::{BlockHash, Digest, MerkleRoot};
    use zx_core::preimage::block::BlockHeader;
    use zx_core::target::{CompactBits, trabajo_bloque};

    fn hash(n: u8) -> BlockHash {
        BlockHash::from_digest(Digest::from_bytes([n; 32]))
    }

    /// # Por qué estos tests NO minan de verdad
    ///
    /// El target más fácil que el protocolo admite es `POW_LIMIT ≈ 2²²⁴`, y satisfacerlo exige
    /// **2³² hashes esperados** — unos siete minutos por cabecera en una compilación de debug. No
    /// cabe en un test unitario, y bajarlo "solo para el test" significaría probar una función
    /// distinta de la que corre en producción.
    ///
    /// Así que las responsabilidades están **separadas en el código**, no fingidas en el test:
    ///
    /// - [`validar_estructura`] no hashea nada, así que se prueba a fondo con cabeceras sin minar.
    /// - [`comprobar_pow`] se prueba por el **lado negativo**, que sí es barato: una cabecera que no
    ///   cumple su target se detecta al primer hash.
    ///
    /// El lado positivo del PoW ya lo cubre `zx-core::target`, con sus propios tests sobre
    /// `cumple_pow`, y lo cubrirá de extremo a extremo el arnés con minero de la Fase 8.
    fn cabecera(altura: u32, prev: BlockHash) -> BlockHeader {
        BlockHeader {
            consensus_branch_id: 0xc478_80ea,
            prev_hash: prev,
            merkle_root: MerkleRoot::from_digest(Digest::from_bytes([altura as u8; 32])),
            timestamp: 1_788_480_000 + u64::from(altura) * 120,
            bits: 0x1d00_ffff,
            nonce: u64::from(altura),
            height: altura,
        }
    }

    /// Una cadena **encadenada** de `n` cabeceras. Sin minar: ver la nota de arriba.
    fn cadena(n: u32, ancla: BlockHash) -> Vec<BlockHeader> {
        let mut v = Vec::with_capacity(n as usize);
        let mut prev = ancla;
        for i in 1..=n {
            let c = cabecera(i, prev);
            prev = c.block_hash();
            v.push(c);
        }
        v
    }

    fn trabajo_por_bloque() -> U256 {
        trabajo_bloque(CompactBits::from_u32(0x1d00_ffff).decodificar().unwrap()).unwrap()
    }

    // ── La máquina de estados ────────────────────────────────────────────────

    /// Se sincroniza de quien tiene **más trabajo**, no de quien dice tener más altura.
    ///
    /// La altura la elige el peer y puede mentir; fabricar trabajo cuesta trabajo. Es la misma
    /// razón por la que el fork choice usa trabajo y no longitud.
    #[test]
    fn solo_se_sincroniza_de_quien_tiene_mas_trabajo() {
        let mut s = Sincronizador::nuevo();
        let p = PeerId::random();

        s.saludo_recibido(p, U256::from(50u32), U256::from(100u32));
        assert_eq!(s.fase(), Fase::AlDia, "nadie por delante ⇒ al día");
        assert_eq!(s.peer(), None);

        let mut s = Sincronizador::nuevo();
        s.saludo_recibido(p, U256::from(200u32), U256::from(100u32));
        assert_eq!(s.fase(), Fase::Cabeceras);
        assert_eq!(s.peer(), Some(p));
    }

    /// Perder al peer vuelve a saludar, **no** aborta la sincronización.
    #[test]
    fn perder_al_peer_vuelve_a_saludar() {
        let mut s = Sincronizador::nuevo();
        let p = PeerId::random();
        s.saludo_recibido(p, U256::from(200u32), U256::zero());
        assert_eq!(s.fase(), Fase::Cabeceras);

        // Perder a OTRO peer no cambia nada.
        s.peer_perdido(PeerId::random());
        assert_eq!(s.fase(), Fase::Cabeceras);

        s.peer_perdido(p);
        assert_eq!(
            s.fase(),
            Fase::Saludando,
            "otro peer puede tener la misma cadena"
        );
        assert_eq!(s.peer(), None);
    }

    /// **Se concluye "al día" por progreso real, no por comparar alturas.**
    ///
    /// Lo que se cuenta son cabeceras **aplicadas**. Ver el test de abajo sobre por qué contar las
    /// recibidas era falsificable.
    #[test]
    fn al_dia_se_concluye_por_respuestas_cortas_seguidas() {
        let mut s = Sincronizador::nuevo();
        s.saludo_recibido(PeerId::random(), U256::from(9u32), U256::zero());

        // Una respuesta larga rompe la racha, por muchas cortas que hubiera antes.
        for _ in 0..RESPUESTAS_CORTAS_PARA_AL_DIA - 1 {
            assert!(!s.respuesta_registrada(1));
        }
        assert!(
            !s.respuesta_registrada(UMBRAL_RESPUESTA_CORTA + 500),
            "una larga rompe la racha"
        );
        assert_eq!(s.fase(), Fase::Cabeceras);

        // Y la racha completa sí concluye.
        for _ in 0..RESPUESTAS_CORTAS_PARA_AL_DIA - 1 {
            assert!(!s.respuesta_registrada(0));
        }
        assert!(
            s.respuesta_registrada(0),
            "la racha completa concluye al día"
        );
        assert_eq!(s.fase(), Fase::AlDia);
    }

    /// **El "al día" falsificable, ahora imposible.**
    ///
    /// La primera versión contaba `cs.len()` de la respuesta cruda, y el docstring afirmaba que
    /// "que deje de mandarte cabeceras nuevas no se puede fingir". Era falso: bastaba con mandar
    /// tres respuestas cortas de basura —cabeceras con `prev_hash` inventado, que ni llegan a
    /// validarse— para que el nodo se declarase sincronizado **habiendo aplicado cero**.
    ///
    /// Y un nodo que se cree al día sin estarlo es lo que un monedero consulta antes de dar un pago
    /// por bueno.
    ///
    /// Ahora el parámetro son las **aplicadas**, y aplicar exige encadenar, `bits` canónico y PoW.
    /// Este test fija que basura corta —cero aplicadas— **también** concluye al día… porque cero
    /// aplicadas es indistinguible de "no hay nada nuevo", que es el caso legítimo. La defensa
    /// real está en que el atacante ya no puede hacer que el contador suba con basura, ni evitar
    /// que baje: no controla el número, solo puede no aportar nada.
    #[test]
    fn el_contador_de_al_dia_mide_lo_aplicado_y_no_lo_recibido() {
        let mut s = Sincronizador::nuevo();
        s.saludo_recibido(PeerId::random(), U256::from(9u32), U256::zero());

        // Un peer que manda 2000 cabeceras de las que NO se aplica ninguna no impide concluir al
        // día — y eso es correcto: no está aportando cadena. Lo que ya no puede hacer es lo
        // contrario, mantenernos en `Cabeceras` para siempre mandando volumen sin progreso.
        for _ in 0..RESPUESTAS_CORTAS_PARA_AL_DIA - 1 {
            assert!(!s.respuesta_registrada(0));
        }
        assert!(
            s.respuesta_registrada(0),
            "sin progreso aplicado, se concluye al día en vez de reintentar sin fin"
        );

        // Y con progreso real por encima del umbral, NO se concluye: hay más cadena que traer.
        let mut s = Sincronizador::nuevo();
        s.saludo_recibido(PeerId::random(), U256::from(9u32), U256::zero());
        for _ in 0..RESPUESTAS_CORTAS_PARA_AL_DIA * 2 {
            assert!(
                !s.respuesta_registrada(UMBRAL_RESPUESTA_CORTA + 100),
                "con progreso grande sostenido NO estamos al día"
            );
        }
        assert_eq!(s.fase(), Fase::Cabeceras);
    }

    /// El umbral es estricto: exactamente `UMBRAL_RESPUESTA_CORTA` **no** cuenta como corta.
    #[test]
    fn el_borde_del_umbral_de_respuesta_corta() {
        let mut s = Sincronizador::nuevo();
        s.saludo_recibido(PeerId::random(), U256::from(9u32), U256::zero());
        for _ in 0..RESPUESTAS_CORTAS_PARA_AL_DIA {
            assert!(
                !s.respuesta_registrada(UMBRAL_RESPUESTA_CORTA),
                "el umbral justo NO es corta"
            );
        }
        for _ in 0..RESPUESTAS_CORTAS_PARA_AL_DIA - 1 {
            assert!(!s.respuesta_registrada(UMBRAL_RESPUESTA_CORTA - 1));
        }
        assert!(
            s.respuesta_registrada(UMBRAL_RESPUESTA_CORTA - 1),
            "uno menos sí"
        );
    }

    // ── La validación de cabeceras ───────────────────────────────────────────

    #[test]
    fn una_cadena_bien_encadenada_pasa_la_estructura() {
        let ancla = hash(0);
        let cs = cadena(5, ancla);
        let w = validar_estructura(&cs, ancla).expect("una cadena encadenada debe pasar");
        assert_eq!(w, trabajo_por_bloque() * U256::from(5u32));
    }

    /// Una respuesta vacía es legítima: "no tengo nada después de tu locator".
    #[test]
    fn una_respuesta_vacia_no_es_un_error() {
        assert_eq!(validar_estructura(&[], hash(0)), Ok(U256::zero()));
        assert_eq!(
            validar_cadena_de_cabeceras(
                &[],
                hash(0),
                U256::zero(),
                U256::zero(),
                trabajo_por_bloque()
            ),
            Ok(U256::zero())
        );
    }

    /// **No encadenar es mala fe.** Cambiar un `prev_hash` obliga a rehacer el PoW desde ahí.
    #[test]
    fn una_cadena_que_no_encadena_se_rechaza_como_mala_fe() {
        let ancla = hash(0);
        let mut cs = cadena(4, ancla);
        if let Some(c) = cs.get_mut(2) {
            c.prev_hash = hash(0xff);
        }
        let e = validar_estructura(&cs, ancla).expect_err("MUST rechazarse");
        assert_eq!(e, RechazoCabeceras::NoEncadenan);
        assert!(e.es_mala_fe());
    }

    /// Se rechaza en **cualquier** posición del corte, no solo en la primera.
    #[test]
    fn el_eslabon_roto_se_detecta_en_cualquier_posicion() {
        let ancla = hash(0);
        for pos in 1..6usize {
            let mut cs = cadena(6, ancla);
            if let Some(c) = cs.get_mut(pos) {
                c.prev_hash = hash(0xee);
            }
            assert_eq!(
                validar_estructura(&cs, ancla),
                Err(RechazoCabeceras::NoEncadenan),
                "eslabón roto en la posición {pos}"
            );
        }
    }

    /// **C-POW-04.** Un `bits` no canónico se rechaza, y es mala fe.
    #[test]
    fn un_bits_no_canonico_se_rechaza_como_mala_fe() {
        let ancla = hash(0);
        for malo in [0x0000_0000u32, 0x2100_ffff, 0x1d80_0000, 0xff00_0001] {
            let mut cs = cadena(3, ancla);
            if let Some(c) = cs.get_mut(1) {
                c.bits = malo;
                // Rehacer el encadenado tras tocar la cabecera, para aislar el fallo a `bits`.
                let nuevo_prev = c.block_hash();
                if let Some(sig) = cs.get_mut(2) {
                    sig.prev_hash = nuevo_prev;
                }
            }
            let e = validar_estructura(&cs, ancla).expect_err("MUST rechazarse: {malo:#010x}");
            assert_eq!(e, RechazoCabeceras::BitsNoCanonico, "{malo:#010x}");
            assert!(e.es_mala_fe());
        }
    }

    /// Una cadena que no continúa el locator se rechaza, pero **no es mala fe**.
    #[test]
    fn no_continuar_el_locator_no_es_mala_fe() {
        let cs = cadena(3, hash(1));
        let e = validar_estructura(&cs, hash(9)).expect_err("MUST rechazarse");
        assert_eq!(e, RechazoCabeceras::NoContinuaElLocator);
        assert!(!e.es_mala_fe(), "puede ser desincronización, no ataque");
    }

    /// **C-POW-01 por el lado negativo**, que es el que sí cabe en un test.
    ///
    /// Una cabecera con `bits` válido pero cuyo hash no lo satisface se detecta al primer hash.
    #[test]
    fn una_cabecera_que_no_cumple_su_target_se_detecta() {
        // `0x1d00ffff` exige que los cuatro bytes altos del hash sean cero. La probabilidad de que
        // una cabecera arbitraria lo cumpla es 2⁻³², así que esto falla con certeza práctica.
        let cs = cadena(3, hash(0));
        let e = comprobar_pow(&cs).expect_err("una cabecera sin minar NO cumple su target");
        assert_eq!(e, RechazoCabeceras::PowInvalido);
        assert!(e.es_mala_fe());
    }

    /// Y una lista vacía pasa el PoW trivialmente: no hay nada que comprobar.
    #[test]
    fn una_lista_vacia_pasa_el_pow() {
        assert_eq!(comprobar_pow(&[]), Ok(()));
    }

    /// **C-NET-04 · el ataque de CVE-2019-25220 — y el fallo que este test encontró.**
    ///
    /// El escenario es una **bifurcación profunda y barata**: el peer cuelga dos cabeceras de un
    /// punto de hace cinco mil bloques. Su cadena total vale 5002 bloques de trabajo frente a
    /// nuestros 10 000: no merece que le reservemos memoria.
    ///
    /// La primera versión de `validar_cadena_de_cabeceras` sumaba al trabajo del **tip** en vez de
    /// al del **ancla**, así que contaba trabajo que no era de esa rama y **el umbral se superaba
    /// siempre**. La defensa quedaba desactivada justo para el caso que existe para cubrir. Este
    /// test lo destapó.
    #[test]
    fn una_bifurcacion_profunda_y_barata_no_merece_memoria() {
        let bloque = trabajo_por_bloque();
        let tip = bloque * U256::from(10_000u32);
        let hasta_ancla = bloque * U256::from(5_000u32); // el ancla está a mitad de nuestra cadena

        let w = bloque * U256::from(2u32); // el peer añade dos cabeceras
        assert!(
            !zx_consensus::antidos::merece_memoria(hasta_ancla + w, tip, bloque),
            "5002 bloques de trabajo frente a 10 000 NO merecen memoria"
        );

        // Y con la cuenta equivocada —sumar al tip— sí pasaba. Se deja escrito para que nadie
        // "simplifique" la firma volviendo a la versión anterior.
        assert!(
            zx_consensus::antidos::merece_memoria(tip + w, tip, bloque),
            "sumar al tip habría dejado pasar la bifurcación: esa era la versión rota"
        );

        assert!(
            !RechazoCabeceras::TrabajoInsuficiente.es_mala_fe(),
            "C-NET-05: ir por detrás NO es mala fe, y penalizarlo castigaría al que sincroniza"
        );
    }

    /// Una extensión honesta de nuestra propia punta **sí** pasa.
    #[test]
    fn una_extension_de_nuestra_punta_pasa() {
        let bloque = trabajo_por_bloque();
        let tip = bloque * U256::from(10_000u32);
        let w = bloque * U256::from(2u32);
        assert!(
            zx_consensus::antidos::merece_memoria(tip + w, tip, bloque),
            "colgar de la punta y añadir dos bloques es el caso normal"
        );
    }

    /// Y sin historia propia, cualquier cadena honesta merece examinarse.
    ///
    /// Es la comprobación de que el umbral es relativo y no un suelo absoluto que impediría
    /// arrancar una cadena nueva — CVE-2019-25220 por la vía contraria.
    #[test]
    fn sin_historia_propia_cualquier_cadena_honesta_merece_examinarse() {
        let ancla = hash(0);
        let cs = cadena(2, ancla);
        let bloque = trabajo_por_bloque();
        let w = validar_estructura(&cs, ancla).unwrap();
        assert!(zx_consensus::antidos::merece_memoria(
            w,
            U256::zero(),
            bloque
        ));
    }
}
