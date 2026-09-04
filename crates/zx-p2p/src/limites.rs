//! Límites explícitos de la capa de red (SPEC §16.3, C-NET-11).
//!
//! # Por qué existe este módulo
//!
//! **La capa de transporte de libp2p no es segura por defecto para una cadena**, y lo peor es que
//! ninguno de sus defectos falla al compilar. Cuatro defaults, verificados contra
//! `rust-libp2p@v0.56.0` (ver `research/libp2p-arquitectura.md` §0 y §3):
//!
//! | Límite | Default | Qué provoca en ZEROX |
//! |---|---|---|
//! | `gossipsub::max_transmit_size` | **65 536 B** | Un bloque típico mide 100-200 KB: **ninguno se propaga** |
//!
//! Y un quinto, que no es de libp2p sino nuestro: **el límite de gossip no puede ser una
//! constante**, porque el tamaño de bloque de ZEROX crece sin techo. Ver [`limite_gossip`].
//! | `gossipsub::validate_messages` | **`false`** | El mensaje se reenvía **antes** de validarlo |
//! | `ConnectionLimits` | todo `None` | Sin límite de conexiones |
//! | Tamaño en `request_response::Codec` | **no existe** | El trait no impone ninguno |
//!
//! Reunirlos aquí, con nombre y con la razón al lado, es lo que impide que alguien "simplifique"
//! uno de ellos más adelante sin saber qué está quitando.

/// Cuántas veces el límite de consenso vigente admite el transporte.
///
/// El transporte **MUST** dejar pasar cualquier bloque que el consenso acepte, con holgura para la
/// cabecera, los sobres del protocolo y el crecimiento de la mediana entre reinicios del nodo.
pub const FACTOR_MARGEN: u64 = 8;

/// Zona libre de consenso, en unidades de peso (§6.5).
///
/// **Se declara aquí y no se importa de `zx-consensus` a propósito**: este crate no depende de
/// consenso —ver el diagrama en `lib.rs`—, así que la copia se mantiene sincronizada por un test
/// que sí lo importa como dev-dependency. Si alguien cambia `ZONA_LIBRE` en consenso, ese test falla.
const ZONA_LIBRE_CONSENSO: u64 = 100_000;

/// Límite de bloque en el génesis: `LIMITE(0) = 2·M(0) = 2·ZONA_LIBRE` (C-WGT-09).
pub const LIMITE_BLOQUE_GENESIS: u64 = 2 * ZONA_LIBRE_CONSENSO;

/// Tamaño máximo de un mensaje de gossipsub **derivado del límite de bloque vigente**.
///
/// # Por qué esto NO puede ser una constante, aunque lo fuera hasta hace un rato
///
/// El tamaño de bloque de ZEROX es **dinámico**: `LIMITE(H) = 2·M(H)` (C-WGT-09), y `M(H)` crece
/// con la mediana larga, **sin techo**. El propio SPEC estima el crecimiento anual máximo de `Mlt`
/// en **≈2,9×**. Partiendo de `LIMITE(0) = 200 000`:
///
/// | | `Mlt` | `LIMITE(H)` | ¿cabía en la constante fija de 800 000? |
/// |---|---|---|---|
/// | año 0 | 100 000 | 200 000 | sí |
/// | año 1 | 290 000 | 580 000 | sí |
/// | año 2 | 841 000 | **1 682 000** | **NO** |
/// | año 3 | 2 438 900 | **4 877 800** | **NO** |
///
/// Con un límite de transporte fijo, **en el año 2 un bloque perfectamente válido deja de poder
/// propagarse**. Y no hace falta ningún ataque: es exactamente el caso para el que existe la
/// mediana larga, demanda legítima sostenida.
///
/// Peor todavía, el límite que decide es el del **receptor**, no el del emisor
/// (`libp2p-gossipsub`, `src/protocol.rs`: el códec de lectura se construye con
/// `default_max_transmit_size` propio). Así que nodos con versiones distintas de esta constante
/// **se particionan entre sí** en silencio: unos aceptan el bloque y otros lo descartan por tamaño
/// de frame, sin que ninguno emita un error de consenso.
///
/// Lo cazó la primera revisión adversarial del crate. Lo incómodo es que el docstring anterior
/// **describía este mismo escenario** —"se convierte en una partición de red silenciosa el día que
/// los bloques crezcan"— y la solución que implementaba era multiplicar por 8 la zona libre de
/// **hoy**, que no está atada a nada que crezca. El aviso estaba escrito; el arreglo no.
#[must_use]
pub const fn limite_gossip(limite_bloque: u64) -> usize {
    // `saturating_mul` y no `*`: un `limite_bloque` absurdo debe dar un techo enorme, no envolver.
    let bytes = limite_bloque.saturating_mul(FACTOR_MARGEN);
    // En un objetivo de 64 bits esto nunca trunca; en uno de 32 satura, que es lo correcto.
    if bytes > usize::MAX as u64 {
        usize::MAX
    } else {
        bytes as usize
    }
}

/// Límite de gossip en el arranque de una cadena nueva. Es `limite_gossip(LIMITE_BLOQUE_GENESIS)`.
pub const MAX_GOSSIP_BYTES_GENESIS: usize = limite_gossip(LIMITE_BLOQUE_GENESIS);

/// A partir de qué fracción del margen el nodo **se niega a seguir**.
///
/// Con `FACTOR_MARGEN = 8`, exigir que sobre un factor 2 significa parar cuando el límite de bloque
/// ha consumido 4 de las 8 veces. A un crecimiento máximo de 2,9×/año, ir de 8× a 2× de margen
/// lleva `log(4)/log(2,9) ≈ 1,3 años`: tiempo de sobra para publicar una versión nueva.
pub const MARGEN_MINIMO: u64 = 2;

/// ¿Puede este nodo seguir sirviendo la cadena con el límite de transporte que tiene?
///
/// # Por qué esto existe, y por qué falla ruidosamente
///
/// El límite de gossipsub se fija **al construir el behaviour** y no se puede cambiar en caliente.
/// Un nodo que lleva meses encendido mientras la cadena crece puede quedarse con un límite que ya
/// no da. La alternativa a comprobarlo es descubrirlo cuando los bloques dejen de llegar.
///
/// Es el mismo patrón que C-GEN-06: **convertir un fallo silencioso en una negativa a arrancar**.
/// Un nodo que se para diciendo "mi límite de transporte se ha quedado corto, actualiza" es
/// infinitamente mejor que uno que sigue corriendo y deja de ver la mitad de los bloques.
#[must_use]
pub const fn margen_suficiente(limite_bloque: u64, limite_transporte: usize) -> bool {
    let necesario = limite_bloque.saturating_mul(MARGEN_MINIMO);
    necesario <= limite_transporte as u64
}

/// Tamaño máximo de una **petición** de sincronización, en bytes.
///
/// Una petición es un locator: unos pocos cientos de hashes de 32 bytes como mucho. Que sea
/// pequeño es la primera línea de defensa — no hay razón legítima para una petición grande.
pub const MAX_PETICION_BYTES: u64 = 64 * 1024;

/// Tamaño máximo de una **respuesta** de sincronización, en bytes.
///
/// Una respuesta puede traer un lote de bloques, así que es el límite grande del crate. Aun así
/// está acotado: sin él, un peer puede hacer que reservemos memoria arbitraria **antes** de que el
/// parser tenga oportunidad de rechazar nada.
pub const MAX_RESPUESTA_BYTES: u64 = MAX_GOSSIP_BYTES_GENESIS as u64 * 16;

/// Cabeceras por respuesta de `Headers`.
///
/// A 112 bytes por cabecera son ~224 KB por respuesta llena. Bitcoin usa 2000 y zcashd 160 —este
/// último por el tamaño de las soluciones Equihash, que ZEROX no tiene.
pub const MAX_CABECERAS_POR_RESPUESTA: usize = 2_000;

/// Bloques por respuesta de `Blocks`.
pub const MAX_BLOQUES_POR_RESPUESTA: usize = 16;

/// Peers salientes: los que **elegimos** nosotros.
pub const MAX_PEERS_SALIENTES: u32 = 24;

/// Peers entrantes: los que nos eligen a nosotros.
///
/// Mayor que el de salientes **a propósito**, y es un compromiso incómodo que conviene tener
/// escrito: aceptar más entrantes hace la red más útil para los demás, pero significa que la
/// mayoría de nuestros peers pueden ser peers que no elegimos. Zebra documenta exactamente el mismo
/// trade-off con un multiplicador de 5 (`zebra-network/src/constants.rs:64-81`).
pub const MAX_PEERS_ENTRANTES: u32 = 72;

/// Conexiones establecidas simultáneas, en total.
pub const MAX_CONEXIONES: u32 = MAX_PEERS_SALIENTES + MAX_PEERS_ENTRANTES;

/// Conexiones establecidas con un **mismo** peer.
///
/// Una basta. Permitir varias multiplica por N lo que un solo peer puede consumir.
pub const MAX_CONEXIONES_POR_PEER: u32 = 1;

/// Conexiones entrantes a medio negociar.
///
/// Es la defensa contra *slowloris*: abrir conexiones y no terminar nunca el handshake.
pub const MAX_CONEXIONES_PENDIENTES: u32 = 32;

/// Peers en modo de **alto ancho de banda** para el relé compacto (C-NET-10).
///
/// Literal de BIP 152: *"Nodes MUST NOT send such sendcmpct messages to more than three peers, as
/// it encourages wasting outbound bandwidth across the network."*
pub const MAX_PEERS_ALTO_ANCHO_BANDA: usize = 3;

// El límite de gossip MUST superar cualquier transacción individual: si una tx que el consenso
// acepta no cupiera en un mensaje, sería invalidez de facto impuesta por el transporte.
// (`MAX_TX_WEIGHT == ZONA_LIBRE` en consenso; el test lo verifica contra el crate real.)
const _: () = assert!(
    MAX_GOSSIP_BYTES_GENESIS as u64 > ZONA_LIBRE_CONSENSO,
    "C-NET-11: el límite de gossip debe superar el peso máximo de una tx, o el transporte \
     censuraría transacciones válidas"
);

// Y el margen del génesis MUST ser suficiente, o el nodo no arrancaría nunca.
const _: () = assert!(margen_suficiente(
    LIMITE_BLOQUE_GENESIS,
    MAX_GOSSIP_BYTES_GENESIS
));

// Y MUST superar el default de libp2p, o no estaríamos arreglando nada.
const _: () = assert!(
    MAX_GOSSIP_BYTES_GENESIS > 65_536,
    "C-NET-11: el default de libp2p es 65536 y es demasiado pequeño para un bloque de ZEROX"
);

// Una respuesta de sincronización carga varios bloques: MUST ser mayor que un mensaje suelto.
const _: () = assert!(MAX_RESPUESTA_BYTES > MAX_GOSSIP_BYTES_GENESIS as u64);

// Una petición es un locator, no un lote: MUST ser mucho menor que una respuesta.
const _: () = assert!(MAX_PETICION_BYTES * 100 < MAX_RESPUESTA_BYTES);

// Coherencia de los límites de conexión. Son constantes, así que van aquí y no en un test: una
// aserción de compilación no se puede saltar con `--skip`.
const _: () = assert!(MAX_CONEXIONES == MAX_PEERS_SALIENTES + MAX_PEERS_ENTRANTES);
const _: () = assert!(
    MAX_PEERS_ENTRANTES > MAX_PEERS_SALIENTES,
    "trade-off asumido: aceptamos más peers de los que elegimos"
);
const _: () = assert!(MAX_PEERS_SALIENTES > 0 && MAX_CONEXIONES_POR_PEER == 1);
const _: () = assert!(
    MAX_PEERS_ALTO_ANCHO_BANDA < MAX_PEERS_SALIENTES as usize,
    "C-NET-10: no se puede tener más peers de alto ancho de banda que peers salientes"
);

#[cfg(test)]
#[expect(
    clippy::integer_division,
    reason = "aritmética entera deliberada: modelar el crecimiento con enteros evita floats"
)]
mod tests {
    use super::{
        LIMITE_BLOQUE_GENESIS, MARGEN_MINIMO, MAX_BLOQUES_POR_RESPUESTA,
        MAX_CABECERAS_POR_RESPUESTA, MAX_GOSSIP_BYTES_GENESIS, MAX_PEERS_ALTO_ANCHO_BANDA,
        MAX_RESPUESTA_BYTES, limite_gossip, margen_suficiente,
    };
    use zx_consensus::peso::{MAX_TX_WEIGHT, ZONA_LIBRE};
    use zx_core::preimage::block::TAMANO_CABECERA;

    /// **C-NET-13 · el fallo que la revisión adversarial encontró, ahora como test.**
    ///
    /// Con un límite de transporte **fijo** de 800 000 B, un bloque legítimo del año 2 —cuando la
    /// mediana larga ha crecido a su ritmo máximo permitido— no cabía. Este test reproduce esa
    /// trayectoria y comprueba que ahora el techo la sigue.
    #[test]
    fn el_limite_de_transporte_sigue_al_crecimiento_del_bloque() {
        // ≈2,9×/año es el crecimiento máximo de Mlt que estima el propio SPEC (C-WGT-04).
        let mut limite = LIMITE_BLOQUE_GENESIS;
        for anio in 0..6u32 {
            let techo = limite_gossip(limite);
            assert!(
                techo as u64 >= limite,
                "año {anio}: un bloque de {limite} B no cabe en un techo de {techo} B"
            );
            assert!(
                margen_suficiente(limite, techo),
                "año {anio}: el margen debe bastar cuando el techo se deriva del límite"
            );
            limite = limite * 29 / 10;
        }

        // Y lo contrario: la constante vieja SÍ se quedaba corta.
        const CONSTANTE_VIEJA: usize = 800_000;
        let limite_ano_2 = LIMITE_BLOQUE_GENESIS * 29 / 10 * 29 / 10;
        assert!(
            limite_ano_2 > CONSTANTE_VIEJA as u64,
            "el fallo original: {limite_ano_2} B no cabían en {CONSTANTE_VIEJA} B"
        );
    }

    /// **C-NET-13.** Cuando el margen se agota, el nodo debe **negarse**, no seguir a medias.
    #[test]
    fn sin_margen_suficiente_se_detecta() {
        let techo = limite_gossip(LIMITE_BLOQUE_GENESIS);

        // Justo en el borde: el límite consume exactamente 1/MARGEN_MINIMO del techo.
        let borde = techo as u64 / MARGEN_MINIMO;
        assert!(margen_suficiente(borde, techo), "el borde exacto vale");
        assert!(
            !margen_suficiente(borde + 1, techo),
            "un byte más allá del borde MUST detectarse"
        );

        // Y un límite absurdo no envuelve, satura.
        assert!(!margen_suficiente(u64::MAX, techo));
        assert!(limite_gossip(u64::MAX) > 0, "satura, no envuelve a cero");
    }

    /// **C-NET-11.** El límite de gossip supera un bloque típico con margen de sobra.
    ///
    /// Este test es el que habría cazado el default de 64 KiB. Un bloque en la zona libre mide
    /// 100 KB, así que con el default **no se habría propagado ni uno solo**, sin error visible.
    #[test]
    fn el_limite_de_gossip_admite_bloques_reales() {
        // LIMITE(0) = 2·ZONA_LIBRE = 200 000 B, por el margen de 8.
        assert_eq!(MAX_GOSSIP_BYTES_GENESIS, 1_600_000);
    }

    /// **La copia local de `ZONA_LIBRE` sigue coincidiendo con la de consenso.**
    ///
    /// `zx-p2p` **no depende** de `zx-consensus` (solo en dev, para este test): así el código de red
    /// no puede llamar a consenso ni por accidente. El precio es una constante duplicada, y este
    /// test es lo que la mantiene honesta — si alguien cambia `ZONA_LIBRE` en consenso, falla aquí
    /// y no en producción.
    #[test]
    fn el_limite_de_gossip_se_deriva_de_la_zona_libre_de_consenso() {
        assert_eq!(
            super::ZONA_LIBRE_CONSENSO,
            ZONA_LIBRE,
            "la copia local de ZONA_LIBRE se ha desincronizado de zx-consensus"
        );
        // LIMITE(0) = 2·M(0) = 2·ZONA_LIBRE (C-WGT-09), y el techo es eso por el margen.
        assert_eq!(LIMITE_BLOQUE_GENESIS, 2 * ZONA_LIBRE);
        assert_eq!(
            MAX_GOSSIP_BYTES_GENESIS as u64,
            LIMITE_BLOQUE_GENESIS * super::FACTOR_MARGEN
        );
        assert!(
            MAX_GOSSIP_BYTES_GENESIS as u64 > MAX_TX_WEIGHT,
            "una tx que el consenso acepta MUST caber en un mensaje"
        );
    }

    /// Un lote lleno de cabeceras **MUST** caber en el límite de respuesta.
    ///
    /// Sin esta comprobación, los dos límites podrían fijarse por separado y dejar un lote máximo
    /// que nunca se puede entregar: el nodo pediría algo que su propio transporte rechaza.
    #[test]
    fn un_lote_lleno_de_cabeceras_cabe_en_una_respuesta() {
        let lote = (MAX_CABECERAS_POR_RESPUESTA * TAMANO_CABECERA) as u64;
        assert!(
            lote < MAX_RESPUESTA_BYTES,
            "{MAX_CABECERAS_POR_RESPUESTA} cabeceras son {lote} B y el techo es \
             {MAX_RESPUESTA_BYTES} B"
        );
    }

    /// Y un lote lleno de bloques también, contando cada uno en la zona libre.
    #[test]
    fn un_lote_lleno_de_bloques_cabe_en_una_respuesta() {
        let lote = MAX_BLOQUES_POR_RESPUESTA as u64 * ZONA_LIBRE;
        assert!(
            lote <= MAX_RESPUESTA_BYTES,
            "{MAX_BLOQUES_POR_RESPUESTA} bloques de {ZONA_LIBRE} B son {lote} B y el techo es \
             {MAX_RESPUESTA_BYTES} B"
        );
    }

    /// **C-NET-10, BIP 152.** Tres, y el BIP lo dice con MUST NOT.
    ///
    /// La coherencia con los demás límites está en aserciones de compilación, arriba. Aquí solo se
    /// fija el número, que es el que cita el BIP literalmente.
    #[test]
    fn el_modo_de_alto_ancho_de_banda_esta_limitado_a_tres() {
        assert_eq!(
            MAX_PEERS_ALTO_ANCHO_BANDA, 3,
            "BIP 152: MUST NOT send such sendcmpct messages to more than three peers"
        );
    }
}
