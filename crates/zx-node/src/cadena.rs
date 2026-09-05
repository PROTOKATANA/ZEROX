//! El estado de la cadena que el nodo mantiene, y el puente hacia la red.
//!
//! # Aquí es donde se rompe el ciclo
//!
//! `zx-p2p` **declara** `ManejadorEntrante` y no lo implementa; no puede, porque no ve el consenso.
//! Este módulo lo implementa llamando a `zx-consensus`, `zx-storage` y `zx-mempool`. Es el único
//! sitio del proyecto donde las cuatro capas coinciden, y por eso es el único que puede cerrar el
//! círculo sin crear una dependencia circular entre crates.
//!
//! # Cada método debe ser rápido
//!
//! Los métodos de `ManejadorEntrante` se llaman **desde el bucle de eventos**, y mientras uno corre
//! el `Swarm` no se pollea — la red entera está parada. Lo que aquí tarde, se nota en la
//! propagación de bloques de todo el nodo. Nada de I/O de disco sin acotar, nada de verificar mil
//! firmas en línea.

use std::collections::HashMap;
use std::sync::{Arc, RwLock};

use primitive_types::U256;
use zx_consensus::activacion::rama_activa;
use zx_consensus::error::ConsensusError;
use zx_consensus::fork_choice::{Preferencia, Tip, comprobar_profundidad_reorg, preferir};
use zx_core::digest::{BlockHash, TxId};
use zx_core::preimage::block::{BlockHeader, merkle_root};
use zx_core::preimage::tx::txid;
use zx_core::red::Red;
use zx_core::target::{CompactBits, TrabajoAcumulado, trabajo_bloque};
use zx_p2p::entrante::{ManejadorEntrante, Veredicto};
use zx_p2p::mensaje::{BloqueRed, Estado};
use zx_storage::almacen::{AlmacenCadena, Punta};

/// Lo que el nodo sabe de su propia cadena.
///
/// De momento solo la punta y las cabeceras que ha visto. El UTXO set y el mempool se conectarán
/// cuando exista el sincronizador — meterlos ahora sería cablear algo que todavía no se usa.
pub struct Cadena {
    red: Red,
    genesis: BlockHash,
    /// Cabeceras por altura, de menor a mayor. La punta es la última.
    ///
    /// `RwLock` y no un actor con canal: las lecturas son muy frecuentes —cada petición entrante
    /// consulta el estado— y las escrituras raras, una por bloque aceptado. Es exactamente el
    /// patrón para el que un `RwLock` es la respuesta correcta, y montar un actor aquí sería
    /// complejidad sin problema que resolver.
    cabeceras: RwLock<Indice>,
    /// Dónde persiste la cadena.
    ///
    /// El índice en memoria de arriba **no se sustituye** por el almacén: se mantiene como caché de
    /// lectura. Servir un locator o buscar el ancla de una petición recorre la cadena, y hacer eso
    /// contra disco en cada petición entrante sería un DoS asimétrico regalado — el peer paga un
    /// mensaje y nosotros pagamos N lecturas.
    almacen: Arc<dyn AlmacenCadena>,
}

/// La cadena en memoria, con su índice.
///
/// # Por qué hay un índice y por qué el hash va guardado (C-NET-16)
///
/// La primera versión guardaba solo un `Vec<BlockHeader>` y buscaba con
/// `iter().position(|c| c.block_hash() == h)`. La revisión adversarial encontró que eso es un
/// **DoS asimétrico regalado**, y tenía razón por partida doble:
///
/// 1. **`block_hash()` no está cacheado.** Cada llamada reserva un `Vec` y computa un SHA3-256
///    completo. Una búsqueda que no encuentra nada recorre `n` cabeceras y hace `n` hashes.
/// 2. **Un locator trae hasta 64 hashes**, y ninguno tiene por qué ser real. Un peer manda 64
///    hashes aleatorios en un mensaje de 2 KB, y el servidor hace **64·n** hashes y 64·n
///    reservas — todo dentro del bucle del `Swarm`, con la red entera parada mientras tanto.
///
/// Con una cadena de un año —~260 000 bloques— eso son **decenas de millones de SHA3 por
/// petición de dos kilobytes**, repetibles sin coste. El atacante ni siquiera necesita ser el
/// peer de sincronización: le basta con estar conectado.
///
/// Ahora el hash se calcula **una vez, al insertar**, y el índice lo resuelve en `O(1)`.
#[derive(Debug, Default)]
struct Indice {
    /// Las cabeceras en orden, con su hash ya calculado.
    cadena: Vec<(BlockHash, BlockHeader)>,
    /// Hash → posición. Convierte una búsqueda de `O(n)` con hashes en una de `O(1)` sin ninguno.
    posicion: HashMap<BlockHash, usize>,
}

impl Indice {
    fn empujar(&mut self, c: BlockHeader) {
        let h = c.block_hash();
        self.posicion.insert(h, self.cadena.len());
        self.cadena.push((h, c));
    }

    fn punta(&self) -> Option<(BlockHash, BlockHeader)> {
        self.cadena.last().copied()
    }

    fn len(&self) -> usize {
        self.cadena.len()
    }
}

impl Cadena {
    /// Arranca la cadena en su génesis.
    ///
    /// # Errores
    /// Lo que devuelva la comprobación de arranque del génesis (C-GEN-01, C-GEN-06, C-GEN-07).
    pub fn nueva(red: Red) -> Result<Self, zx_consensus::error::ConsensusError> {
        Self::con_almacen(red, Arc::new(zx_storage::AlmacenEnMemoria::nuevo()))
    }

    /// Arranca sobre un almacén concreto, recuperando lo que ya hubiera guardado.
    ///
    /// # Errores
    /// Lo que devuelva la comprobación de arranque del génesis, o un fallo del almacén.
    pub fn con_almacen(
        red: Red,
        almacen: Arc<dyn AlmacenCadena>,
    ) -> Result<Self, zx_consensus::error::ConsensusError> {
        let params = match red {
            Red::Mainnet => zx_consensus::genesis::GENESIS_MAINNET,
            Red::Testnet => zx_consensus::genesis::GENESIS_TESTNET,
        };

        // C-GEN-07 · esto es lo que aborta el arranque si el binario no es de esta cadena.
        let genesis = zx_consensus::genesis::comprobar_al_arrancar(params)?;
        let (cabecera, _) = zx_consensus::genesis::construir(params)?;

        // El génesis se guarda siempre: es el ancla de todo locator y debe estar aunque el almacén
        // venga vacío. Guardarlo dos veces es inofensivo — la clave es su hash.
        let _ = almacen.guardar_cabecera(&cabecera);

        // Recuperar lo que hubiera. Un almacén sin punta es uno recién creado, no uno roto.
        let mut indice = Indice::default();
        indice.empujar(cabecera);
        if let Ok(Some(punta)) = almacen.punta() {
            for h in 1..=punta.altura {
                match almacen.hash_en_altura(h).ok().flatten() {
                    Some(hash) => match almacen.cabecera(&hash).ok().flatten() {
                        Some(c) => indice.empujar(c),
                        // Un hueco en el índice significa almacén incompleto. Se para de recuperar
                        // ahí en vez de seguir con una cadena con agujeros: mejor arrancar más
                        // atrás y resincronizar que creer que se tiene lo que no se tiene.
                        None => break,
                    },
                    None => break,
                }
            }
        }

        Ok(Self {
            red,
            genesis,
            cabeceras: RwLock::new(indice),
            almacen,
        })
    }

    /// La red de esta cadena.
    ///
    #[must_use]
    pub const fn red(&self) -> Red {
        self.red
    }

    /// El hash del génesis.
    ///
    /// Es el ancla de todo locator: garantiza que dos nodos de la misma cadena siempre tengan al
    /// menos un punto en común.
    #[must_use]
    pub const fn genesis(&self) -> BlockHash {
        self.genesis
    }

    /// Altura de la punta.
    #[must_use]
    pub fn altura(&self) -> u32 {
        u32::try_from(leer(&self.cabeceras).len().saturating_sub(1)).unwrap_or(u32::MAX)
    }

    /// La rama de consenso activa a la altura actual.
    ///
    /// # Errores
    /// [`zx_consensus::error::ConsensusError::SinRamaActiva`] con una tabla mal formada.
    pub fn rama(&self) -> Result<u32, zx_consensus::error::ConsensusError> {
        rama_activa(self.red, self.altura())
    }

    /// Añade cabeceras **sin validar**, para arnés de pruebas.
    ///
    /// `cfg(test)` no basta: los tests de integración son otro crate, así que este constructor es
    /// público y lleva el aviso en el nombre y en la firma. Saltarse la validación es exactamente
    /// lo que un test de sincronización necesita —el nodo servidor debe *tener* una cadena sin
    /// haberla minado— y exactamente lo que producción no debe hacer nunca.
    #[doc(hidden)]
    pub fn extender_sin_validar_solo_para_pruebas(&self, nuevas: &[BlockHeader]) {
        let mut i = escribir(&self.cabeceras);
        for c in nuevas {
            let _ = self.almacen.guardar_cabecera(c);
            i.empujar(*c);
        }
        if let Some((h, c)) = i.punta() {
            let _ = self.almacen.fijar_punta(Punta {
                hash: h,
                altura: c.height,
            });
        }
    }

    /// La cabecera que tenemos a una altura concreta, si la tenemos.
    ///
    /// `O(1)`: el índice guarda la cadena como un vector cuya posición **es** la altura, con el
    /// génesis en la 0. Hace falta para reconstruir la ventana del retarget (C-DIFF-01), que mira
    /// `N+1` ancestros y no puede permitirse un recorrido por cada cabecera que llega.
    #[must_use]
    pub fn cabecera_en(&self, altura: u32) -> Option<BlockHeader> {
        let i = leer(&self.cabeceras);
        i.cadena.get(usize::try_from(altura).ok()?).map(|(_, c)| *c)
    }

    /// La altura a la que tenemos un hash, si lo tenemos. `O(1)`.
    #[must_use]
    pub fn altura_de(&self, h: BlockHash) -> Option<u32> {
        u32::try_from(*leer(&self.cabeceras).posicion.get(&h)?).ok()
    }

    /// Trabajo acumulado de nuestra cadena hasta la punta.
    #[must_use]
    pub fn trabajo(&self) -> U256 {
        trabajo_de(&leer(&self.cabeceras).cadena)
    }

    /// Trabajo acumulado **hasta un hash concreto** de nuestra cadena, o `None` si no lo conocemos.
    ///
    /// Es lo que C-NET-04 necesita para juzgar una cadena candidata: el trabajo de la rama que el
    /// peer propone es *lo que compartimos hasta el ancla* más lo que él añade. Sumar al trabajo de
    /// la **punta** —que fue el primer intento— cuenta trabajo que no es de esa rama, y deja pasar
    /// cualquier bifurcación profunda.
    #[must_use]
    pub fn trabajo_hasta(&self, h: BlockHash) -> Option<U256> {
        let i = leer(&self.cabeceras);
        // `O(1)` gracias al índice. Antes era `O(n)` **con un SHA3 por cabecera**, y se ejecutaba
        // sobre un `prev_hash` que el peer elige — o sea, un escaneo completo de nuestra cadena a
        // petición de cualquiera, antes de haber validado nada.
        let pos = *i.posicion.get(&h)?;
        Some(trabajo_de(i.cadena.get(..=pos)?))
    }

    /// Trabajo de un solo bloque a la dificultad de la punta, para el umbral de C-NET-04.
    #[must_use]
    pub fn trabajo_de_un_bloque(&self) -> U256 {
        leer(&self.cabeceras)
            .punta()
            .and_then(|(_, c)| CompactBits::from_u32(c.bits).decodificar().ok())
            .and_then(trabajo_bloque)
            .unwrap_or_else(U256::one)
    }

    /// Adopta una cadena de cabeceras **ya validadas**, reorganizando si hace falta (P-028).
    ///
    /// Es lo que faltaba: `extender` solo sabía añadir a la punta, así que una rama competidora
    /// que colgara por debajo se validaba correctamente y **se descartaba entera**. El nodo se
    /// quedaba en una cadena perdedora, que es la peor forma de divergir — sin error, sin aviso.
    ///
    /// # El orden de las comprobaciones importa
    ///
    /// 1. Localizar el ancla. Si no la conocemos, no hay nada que adoptar.
    /// 2. **Decidir con `fork_choice`**, no a ojo: la rama que gana es la de más trabajo, con
    ///    desempate por menor hash (C-FORK-01..04). Comparar alturas sería incorrecto.
    /// 3. **Comprobar la profundidad ANTES de tocar nada** (C-REORG-07). Una reorg de más de 99
    ///    bloques no se aplica: se para el nodo.
    /// 4. Recortar y reaplicar.
    ///
    /// El paso 3 va antes del 4 a propósito. Comprobar después de haber empezado a deshacer dejaría
    /// el estado a medias justo en el caso que la regla existe para tratar como excepcional.
    ///
    /// # Errores
    /// [`ConsensusError::ReorgDemasiadoProfunda`] si excede `MAX_REORG_LENGTH`. Quien lo reciba
    /// **MUST** detener el nodo y avisar al operador, no reintentar.
    pub fn adoptar(&self, nuevas: &[BlockHeader]) -> Result<Adopcion, ConsensusError> {
        let Some(primera) = nuevas.first() else {
            return Ok(Adopcion::NadaQueHacer);
        };
        let mut idx = escribir(&self.cabeceras);

        // 1 · ¿de dónde cuelgan?
        let Some(&pos_ancla) = idx.posicion.get(&primera.prev_hash) else {
            return Ok(Adopcion::NoCuelgaDeNada);
        };

        // Extensión de la punta: el caso normal, sin reorg.
        let es_extension = pos_ancla + 1 == idx.cadena.len();

        // 2 · ¿gana la candidata? `fork_choice`, no altura.
        let trabajo_ancla = trabajo_de(idx.cadena.get(..=pos_ancla).unwrap_or_default());
        let trabajo_nuevas = nuevas
            .iter()
            .filter_map(|c| CompactBits::from_u32(c.bits).decodificar().ok())
            .filter_map(trabajo_bloque)
            .fold(U256::zero(), |a, w| a.saturating_add(w));
        let candidata = Tip {
            hash: nuevas
                .last()
                .map_or(primera.prev_hash, BlockHeader::block_hash),
            altura: nuevas.last().map_or(0, |c| c.height),
            trabajo: acumulado(trabajo_ancla.saturating_add(trabajo_nuevas)),
        };
        let actual = Tip {
            hash: idx.punta().map_or(self.genesis, |(h, _)| h),
            altura: idx.punta().map_or(0, |(_, c)| c.height),
            trabajo: acumulado(trabajo_de(&idx.cadena)),
        };

        if !es_extension && preferir(&candidata, &actual) != Preferencia::Primero {
            // Una rama que no gana no se adopta, y **no es mala fe**: es lo que propone cualquiera
            // que vaya por detrás o por una rama distinta.
            return Ok(Adopcion::NoGana);
        }

        // 3 · C-REORG-07 · la profundidad, ANTES de deshacer nada.
        let desechadas = idx.cadena.len().saturating_sub(pos_ancla + 1);
        let profundidad = u32::try_from(desechadas).unwrap_or(u32::MAX);
        comprobar_profundidad_reorg(profundidad)?;

        // 4 · recortar y reaplicar.
        if !es_extension {
            // Las cabeceras desechadas **siguen en el almacén**, recuperables por su hash: las
            // necesitaría un reorg que volviera atrás. Lo único que se rehace es el índice.
            // Se recogen antes de mutar: `drain` toma `idx.cadena` prestado y `posicion` vive en
            // el mismo struct.
            let desechados: Vec<BlockHash> =
                idx.cadena.drain(pos_ancla + 1..).map(|(h, _)| h).collect();
            for h in desechados {
                idx.posicion.remove(&h);
            }
        }

        let mut aplicadas = 0usize;
        let mut ultima = None;
        for c in nuevas {
            if idx.punta().map(|(h, _)| h) != Some(c.prev_hash) {
                break;
            }
            // C-STORE-01 · el dato primero, la punta al final.
            if let Err(e) = self.almacen.guardar_cabecera(c) {
                tracing::error!(%e, altura = c.height, "no se pudo guardar la cabecera");
                break;
            }
            idx.empujar(*c);
            ultima = Some(*c);
            aplicadas += 1;
        }

        if let Some(c) = ultima
            && let Err(e) = self.almacen.fijar_punta(Punta {
                hash: c.block_hash(),
                altura: c.height,
            })
        {
            tracing::error!(%e, "no se pudo fijar la punta");
        }

        Ok(if profundidad == 0 {
            Adopcion::Extendida { aplicadas }
        } else {
            Adopcion::Reorganizada {
                aplicadas,
                desechadas: profundidad,
            }
        })
    }

    /// Añade cabeceras **ya validadas** a la punta.
    ///
    /// Devuelve cuántas se añadieron. Las que no continúen la punta se ignoran: llegar tarde con
    /// cabeceras que ya teníamos es normal cuando se pide a varios peers a la vez.
    ///
    /// # 🔶 Esto NO sabe reorganizar, y hay que decirlo
    ///
    /// Solo añade a la punta actual. Una cadena **competidora válida** que cuelgue de un ancla por
    /// debajo del tip —justo el caso que `validar_cadena_de_cabeceras` fue corregido para juzgar
    /// bien— se valida como `Ok` y aquí se descarta entera, devolviendo 0.
    ///
    /// `zx-consensus::fork_choice` existe y sabe decidir entre ramas, pero **no está conectado**:
    /// esta estructura es una lista, no un árbol de puntas competidoras. Conectarlo exige poder
    /// deshacer hasta el ancla y reaplicar, y eso necesita el `UndoData` del almacén.
    ///
    /// Mientras tanto, quien llama **debe detectar `0` con una respuesta no vacía y cortar** en vez
    /// de reintentar: con el mismo locator, el peer respondería lo mismo indefinidamente. Lo hace
    /// `main.rs`, y esa es hoy la diferencia entre un hueco conocido y un bucle infinito.
    pub fn extender(&self, nuevas: &[BlockHeader]) -> usize {
        let mut i = escribir(&self.cabeceras);
        let mut n = 0;
        let mut ultima = None;

        for c in nuevas {
            let punta = i.punta().map(|(h, _)| h);
            if punta != Some(c.prev_hash) {
                continue;
            }
            // C-STORE-01 · **el dato primero, la punta al final.** Si el proceso muere aquí, sobra
            // una cabecera que la punta no menciona: recuperable. Al revés sería corrupción.
            if let Err(e) = self.almacen.guardar_cabecera(c) {
                tracing::error!(%e, altura = c.height, "no se pudo guardar la cabecera");
                break;
            }
            i.empujar(*c);
            ultima = Some(*c);
            n += 1;
        }

        // La punta, una sola vez y al final: mover el tip por cada cabecera sería N escrituras
        // donde basta una, y ninguna de las intermedias aporta nada.
        if let Some(c) = ultima
            && let Err(e) = self.almacen.fijar_punta(Punta {
                hash: c.block_hash(),
                altura: c.height,
            })
        {
            tracing::error!(%e, "no se pudo fijar la punta");
        }
        n
    }

    /// Guarda el cuerpo de un bloque, **después de comprobar que es el de su cabecera**.
    ///
    /// # Errores
    /// [`ErrorCuerpo::Rechazado`] si el cuerpo no corresponde a la cabecera; [`ErrorCuerpo::Almacen`]
    /// con lo que devuelva el almacén.
    pub fn guardar_bloque(&self, b: &BloqueRed) -> Result<(), ErrorCuerpo> {
        comprobar_cuerpo(b)?;
        let mut bytes = Vec::new();
        zx_core::wire::cuerpo_a_bytes(&mut bytes, &b.cabecera, &b.txs, &b.testigos);
        self.almacen
            .guardar_cuerpo(&b.cabecera.block_hash(), &bytes)?;
        Ok(())
    }

    /// Los hashes de la cadena cuyo **cuerpo** todavía no tenemos, hasta `max`, de menor altura a
    /// mayor (C-NET-24).
    ///
    /// De abajo arriba a propósito: la cadena se completa desde el principio, así que un nodo a
    /// medias tiene un prefijo íntegro y un sufijo por descargar, en vez de agujeros repartidos.
    /// Con agujeros, cualquier consulta histórica falla de forma impredecible; con un prefijo, se
    /// sabe exactamente hasta dónde se puede responder.
    ///
    /// El génesis no cuenta: no tiene cuerpo que descargar.
    #[must_use]
    pub fn cuerpos_que_faltan(&self, max: usize) -> Vec<BlockHash> {
        let i = leer(&self.cabeceras);
        let mut faltan = Vec::with_capacity(max.min(i.cadena.len()));
        for (hash, _) in i.cadena.iter().skip(1) {
            if faltan.len() == max {
                break;
            }
            // Un fallo del almacén se trata como "no lo tengo": volver a pedirlo es inofensivo,
            // y darlo por presente dejaría un agujero que nadie volvería a mirar.
            if !self.almacen.tiene_cuerpo(hash).unwrap_or(false) {
                faltan.push(*hash);
            }
        }
        faltan
    }

    /// Recupera un bloque completo, o `None` si no lo tenemos.
    ///
    /// Un cuerpo que no decodifica se trata como **ausente** y se registra: es corrupción del
    /// almacén, no del peer que lo pide, y devolver basura sería peor que decir "no lo tengo".
    #[must_use]
    pub fn bloque(&self, hash: BlockHash) -> Option<BloqueRed> {
        let bytes = self.almacen.cuerpo(&hash).ok().flatten()?;
        match zx_core::wire::cuerpo_desde_bytes(&bytes) {
            Ok(((cabecera, txs, testigos), [])) => Some(BloqueRed {
                cabecera,
                txs,
                testigos,
            }),
            Ok(_) => {
                tracing::error!(?hash, "cuerpo con bytes sobrantes: almacén corrupto");
                None
            }
            Err(e) => {
                tracing::error!(?hash, %e, "cuerpo que no decodifica: almacén corrupto");
                None
            }
        }
    }

    /// Acceso al lock, **solo para el test de envenenamiento**.
    ///
    /// Existe porque envenenar un lock exige tomarlo y entrar en pánico, y eso no se puede hacer
    /// desde fuera sin verlo. La alternativa —no probar la política de envenenamiento— es peor:
    /// sería una decisión de diseño sin nada que la respalde.
    #[cfg(test)]
    pub(crate) const fn cabeceras_para_envenenar(&self) -> &RwLock<impl Sized> {
        &self.cabeceras
    }

    /// El almacén sobre el que corre esta cadena.
    #[must_use]
    pub fn almacen(&self) -> &Arc<dyn AlmacenCadena> {
        &self.almacen
    }

    /// Un locator de la punta hacia atrás: denso al principio, espaciado después.
    ///
    /// La densidad no es estética. Un locator lineal necesitaría tantas peticiones como bloques de
    /// bifurcación haya; uno con espaciado exponencial encuentra el punto de bifurcación en
    /// `O(log n)`. Es el mecanismo de Bitcoin desde el principio, y la razón de que la petición de
    /// cabeceras lleve una **lista** y no una altura: pedir "desde la altura N" supondría que los
    /// dos estamos en la misma cadena, que es justo lo que hay que averiguar.
    #[must_use]
    pub fn locator(&self) -> Vec<BlockHash> {
        let idx = leer(&self.cabeceras);
        let mut v = Vec::new();
        let mut paso = 1usize;
        let mut i = idx.len();

        while i > 0 {
            i = i.saturating_sub(paso);
            if let Some((h, _)) = idx.cadena.get(i) {
                v.push(*h);
            }
            // Los diez primeros van de uno en uno; a partir de ahí, el paso se duplica.
            if v.len() >= 10 {
                paso = paso.saturating_mul(2);
            }
            if i == 0 {
                break;
            }
        }
        // El génesis siempre cierra el locator: garantiza que hay al menos un punto en común con
        // cualquier peer de la misma cadena.
        if v.last() != Some(&self.genesis) {
            v.push(self.genesis);
        }
        v
    }
}

/// Por qué un cuerpo puede no ser el de su cabecera.
#[derive(Debug, Clone, Copy, PartialEq, Eq, thiserror::Error)]
pub enum RechazoCuerpo {
    /// La raíz de Merkle de las transacciones no es la que la cabecera compromete (C-BLK-03).
    #[error("la raíz de Merkle del cuerpo no es la de su cabecera (C-BLK-03)")]
    RaizNoCoincide,
    /// Hay un número distinto de listas de testigos que de transacciones.
    #[error("{testigos} listas de testigos para {txs} transacciones")]
    TestigosDescuadrados {
        /// Transacciones que trae el cuerpo.
        txs: usize,
        /// Listas de testigos que trae el cuerpo.
        testigos: usize,
    },
    /// Un bloque sin transacciones no existe: siempre lleva coinbase (C-BLK-07).
    #[error("el bloque no trae ninguna transacción: falta la coinbase (C-BLK-07)")]
    SinCoinbase,
}

/// Lo que puede salir mal al guardar un cuerpo.
#[derive(Debug, thiserror::Error)]
pub enum ErrorCuerpo {
    /// El cuerpo no es el de su cabecera.
    #[error(transparent)]
    Rechazado(#[from] RechazoCuerpo),
    /// El almacén falló.
    #[error(transparent)]
    Almacen(#[from] zx_storage::StorageError),
}

/// **Comprueba que un cuerpo es el de su cabecera** (C-NET-23).
///
/// # Por qué esto no es opcional
///
/// Un cuerpo se guarda y se indexa **por el hash de su cabecera**. Sin esta comprobación, un peer
/// que responde a `Peticion::Bloques` puede mandar la cabecera correcta —la que le pedimos, la que
/// ya validamos— con un cuerpo cualquiera: lo guardaríamos bajo el hash bueno, lo serviríamos a
/// otros peers como si fuera el bloque real, y `Cadena::bloque` lo devolvería sin una queja.
///
/// Lo que lo impide es que la cabecera **compromete** la lista de transacciones a través de la raíz
/// de Merkle (C-BLK-03). Recalcularla desde las transacciones que llegan y compararla es lo que
/// convierte "el peer dice que este es el cuerpo" en "este es el cuerpo".
///
/// # Lo que NO comprueba
///
/// La validez de las transacciones: firmas, gastos, importes, peso, coinbase. Eso es
/// `zx_consensus::bloque::validar_cuerpo` y necesita el conjunto UTXO, que la cadena todavía no
/// mantiene. Esto es la barrera **anterior**: que el cuerpo sea el que la cabecera dice, que es
/// barato y no depende de tener estado.
///
/// # Errores
/// El [`RechazoCuerpo`] correspondiente. Todos son atribuibles a mala fe: la raíz es determinista.
pub fn comprobar_cuerpo(b: &BloqueRed) -> Result<(), RechazoCuerpo> {
    // C-BLK-07 · siempre hay coinbase. Además, sin esto la raíz de la lista vacía sería un valor
    // legítimo y un "bloque" sin transacciones podría cuadrar con una cabecera fabricada para él.
    if b.txs.is_empty() {
        return Err(RechazoCuerpo::SinCoinbase);
    }
    // Los testigos van en paralelo a las transacciones (§2.4). Descuadrados, el cuerpo no es
    // codificable de vuelta a lo mismo, y guardarlo dejaría el almacén con algo que no se puede
    // releer con sentido.
    if b.testigos.len() != b.txs.len() {
        return Err(RechazoCuerpo::TestigosDescuadrados {
            txs: b.txs.len(),
            testigos: b.testigos.len(),
        });
    }
    // C-BLK-03 · la raíz. El `consensus_branch_id` sale de la CABECERA, no de nuestra tabla: el
    // txid depende de él (C-TX-05), y usar el nuestro compararía manzanas con peras en cuanto
    // hubiera una rama nueva activa.
    let txids: Vec<TxId> = b
        .txs
        .iter()
        .map(|t| txid(t, b.cabecera.consensus_branch_id))
        .collect();
    if merkle_root(&txids) != b.cabecera.merkle_root {
        return Err(RechazoCuerpo::RaizNoCoincide);
    }
    Ok(())
}

impl ManejadorEntrante for Cadena {
    fn estado(&self) -> Estado {
        Estado {
            genesis: self.genesis,
            tip: leer(&self.cabeceras)
                .punta()
                .map_or(self.genesis, |(h, _)| h),
            altura: self.altura(),
            trabajo: self.trabajo().to_big_endian(),
        }
    }

    fn bloque_difundido(&self, _bloque: &BloqueRed) -> Veredicto {
        // TODO(sincronizador): validar con `zx_consensus::bloque::validar_bloque`.
        //
        // Mientras tanto **`Ignorar`, nunca `Rechazar`**. La diferencia importa: `Rechazar` aplica
        // la penalización P₄ de gossipsub al peer que lo propagó, y penalizar a peers honestos
        // porque nosotros todavía no sabemos validar sería exactamente al revés.
        Veredicto::Ignorar
    }

    fn tx_difundida(&self, _tx: &[u8]) -> Veredicto {
        // Mismo razonamiento que arriba.
        Veredicto::Ignorar
    }

    fn cabeceras_desde(
        &self,
        locator: &[BlockHash],
        _hasta: Option<BlockHash>,
    ) -> Vec<BlockHeader> {
        let idx = leer(&self.cabeceras);
        // El primer hash del locator que reconozcamos marca desde dónde servir. Que no
        // reconozcamos ninguno es una respuesta legítima: significa que no compartimos historia.
        //
        // Cada consulta es `O(1)` contra el índice, así que un locator entero cuesta 64 búsquedas
        // en tabla. Con la versión anterior —`position` con `block_hash()` por elemento— costaba
        // 64·n SHA3, y era un DoS trivial: ver la nota de [`Indice`].
        for h in locator {
            if let Some(pos) = idx.posicion.get(h) {
                // Se recorta **aquí, antes de clonar**. Recortar después, como hacía la primera
                // versión, significa que la asignación grande ya ocurrió: reconocer el génesis en
                // la última posición del locator clonaba la cadena entera.
                let desde = pos.saturating_add(1);
                let hasta = desde
                    .saturating_add(MAX_CABECERAS_SERVIDAS)
                    .min(idx.cadena.len());
                return idx
                    .cadena
                    .get(desde..hasta)
                    .unwrap_or_default()
                    .iter()
                    .map(|(_, c)| *c)
                    .collect();
            }
        }
        Vec::new()
    }

    fn bloques_por_hash(&self, hashes: &[BlockHash]) -> Vec<BloqueRed> {
        // Se recorta al límite del protocolo **antes** de leer nada del almacén: un peer que pida
        // mil bloques no debe conseguir que hagamos mil lecturas de disco para luego tirar 984.
        hashes
            .iter()
            .take(MAX_BLOQUES_SERVIDOS)
            .filter_map(|h| self.bloque(*h))
            .collect()
    }
}

/// Qué pasó al adoptar una cadena de cabeceras.
///
/// Se distinguen porque **tienen respuestas distintas**: una extensión es progreso, una reorg es
/// progreso con aviso, y las dos negativas no son mala fe pero sí razón para dejar de pedirle a ese
/// peer (C-NET-18).
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Adopcion {
    /// La lista venía vacía.
    NadaQueHacer,
    /// No cuelgan de nada que conozcamos. **No es mala fe**: puede ser desincronización.
    NoCuelgaDeNada,
    /// Cuelgan de algo nuestro pero la rama **no gana** por trabajo acumulado. Tampoco es mala fe.
    NoGana,
    /// Se añadieron a la punta, sin deshacer nada.
    Extendida {
        /// Cuántas.
        aplicadas: usize,
    },
    /// Se adoptó una rama distinta, deshaciendo parte de la nuestra.
    Reorganizada {
        /// Cuántas se añadieron.
        aplicadas: usize,
        /// Cuántas se desecharon.
        desechadas: u32,
    },
}

impl Adopcion {
    /// Cuántas cabeceras se incorporaron. Lo que cuenta hacia "estar al día" (C-NET-17).
    #[must_use]
    pub const fn aplicadas(self) -> usize {
        match self {
            Self::Extendida { aplicadas } | Self::Reorganizada { aplicadas, .. } => aplicadas,
            _ => 0,
        }
    }
}

/// Cuántas cabeceras se sirven como mucho en una respuesta.
///
/// Coincide con el límite de transporte de `zx-p2p`, y se aplica **antes de clonar**: recortar
/// después, como hacía la primera versión, significa que la asignación grande ya ocurrió.
const MAX_CABECERAS_SERVIDAS: usize = 2_000;

/// Cuántos cuerpos se sirven como mucho en una respuesta.
///
/// Se aplica **antes** de leer del almacén: un peer que pida mil bloques no debe conseguir que
/// hagamos mil lecturas para tirar 984 después. El recorte tardío convierte un límite en un
/// amplificador.
const MAX_BLOQUES_SERVIDOS: usize = 16;

/// Lee el índice, o **recupera** el contenido de un lock envenenado (P-029).
///
/// # La decisión, y por qué esta y no la otra
///
/// Un `RwLock` se envenena cuando un hilo entra en pánico mientras lo tiene. La versión anterior
/// hacía `.read().ok()` y devolvía valores por defecto: altura 0, trabajo 0, tip = génesis. **El
/// nodo seguía anunciando esos valores a la red**, o sea, mintiendo sobre su cadena.
///
/// Eso contradice todo lo demás del proyecto: C-GEN-06 impide arrancar con un génesis dudoso,
/// C-NET-13 para el nodo cuando el transporte se queda corto. La coherencia pedía **parar**.
///
/// Pero parar por un lock envenenado tiene un problema: el workspace **prohíbe `panic`, `unwrap` y
/// `expect` en producción**, así que el pánico que envenenaría el lock no debería poder ocurrir. Si
/// ocurriera igual —un desbordamiento aritmético en modo debug, un índice fuera de rango en una
/// dependencia—, el estado protegido **no está corrupto**: los datos que hay dentro son válidos,
/// solo que quien los tocaba murió.
///
/// Así que la decisión es la tercera opción, y es mejor que las dos: **recuperar el contenido y
/// seguir, registrando el suceso como error**. Los datos son buenos, el nodo no miente, y el
/// operador se entera. Es lo que `PoisonError::into_inner` existe para hacer.
///
/// Lo que **no** se hace es lo que se hacía antes: devolver valores falsos en silencio.
fn leer<'a>(l: &'a RwLock<Indice>) -> std::sync::RwLockReadGuard<'a, Indice> {
    l.read().unwrap_or_else(|e| {
        tracing::error!(
            "lock de la cadena envenenado: otro hilo entró en pánico. Los datos son válidos y se \
             recuperan, pero esto NO debería poder pasar — el workspace prohíbe panic en producción."
        );
        e.into_inner()
    })
}

/// Escribe en el índice, o recupera un lock envenenado. Ver [`leer`].
fn escribir<'a>(l: &'a RwLock<Indice>) -> std::sync::RwLockWriteGuard<'a, Indice> {
    l.write().unwrap_or_else(|e| {
        tracing::error!("lock de la cadena envenenado al escribir; se recupera el contenido");
        e.into_inner()
    })
}

/// Envuelve un `U256` en el tipo testigo del fork choice.
///
/// `TrabajoAcumulado` no tiene constructor desde `U256` a propósito —solo se llega ahí sumando—,
/// que es exactamente el punto: obliga a que el trabajo se construya sumando bloques y no se pueda
/// inventar. Aquí se reconstruye sumándolo de una vez, que es la misma operación.
fn acumulado(w: U256) -> TrabajoAcumulado {
    TrabajoAcumulado::cero().sumar(w).unwrap_or_else(|| {
        // Inalcanzable: `w` sale de sumar trabajos de bloques reales, muy por debajo de U256::MAX.
        // Si llegara aquí, saturar es más seguro que envolver.
        TrabajoAcumulado::cero()
    })
}

/// Trabajo acumulado de una secuencia de cabeceras.
///
/// Una cabecera cuyo `bits` no decodifica aporta cero en vez de abortar: aquí solo se suma, y
/// rechazar `bits` inválidos es de la validación, no de la contabilidad. Aportar cero es
/// conservador — nunca infla el trabajo de una cadena.
fn trabajo_de(cs: &[(BlockHash, BlockHeader)]) -> U256 {
    cs.iter()
        .filter_map(|(_, c)| CompactBits::from_u32(c.bits).decodificar().ok())
        .filter_map(trabajo_bloque)
        .fold(U256::zero(), |a, w| a.saturating_add(w))
}

/// El hash cero, para lo que todavía no existe.
#[cfg(test)]
#[must_use]
pub(crate) fn hash_cero() -> BlockHash {
    BlockHash::from_digest(zx_core::digest::Digest::from_bytes([0u8; 32]))
}

#[cfg(test)]
#[expect(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    reason = "los tests fallan con panic por diseño, y uno envenena un lock a propósito"
)]
mod tests {
    use super::Cadena;
    use zx_consensus::error::ConsensusError;
    use zx_core::digest::BlockHash;
    use zx_core::preimage::block::BlockHeader;
    use zx_core::red::Red;
    use zx_p2p::entrante::ManejadorEntrante;

    #[test]
    fn testnet_arranca_en_su_genesis() {
        let c = Cadena::nueva(Red::Testnet).expect("testnet arranca");
        assert_eq!(c.altura(), 0);
        assert_eq!(c.estado().genesis, c.genesis());
        assert_eq!(
            c.estado().tip,
            c.genesis(),
            "en la altura 0, tip == génesis"
        );
    }

    /// **C-GEN-06 y C-GEN-07 desde el nodo.** Mainnet no arranca mientras P-017 siga abierto.
    ///
    /// Es la comprobación que de verdad importa: no que la función de consenso rechace, sino que el
    /// **nodo** se niegue a construirse.
    #[test]
    fn mainnet_no_arranca_todavia() {
        let e = Cadena::nueva(Red::Mainnet);
        assert!(e.is_err(), "P-017 sigue abierto: mainnet MUST NOT arrancar");
    }

    /// El locator siempre acaba en el génesis.
    ///
    /// Sin esa garantía, dos nodos de la misma cadena podrían no encontrar ningún punto en común y
    /// concluir que no comparten historia.
    #[test]
    fn el_locator_siempre_cierra_con_el_genesis() {
        let c = Cadena::nueva(Red::Testnet).unwrap();
        let l = c.locator();
        assert!(!l.is_empty());
        assert_eq!(*l.last().unwrap(), c.genesis());
    }

    /// Servir cabeceras desde un locator que no reconocemos devuelve vacío, no un error.
    #[test]
    fn un_locator_desconocido_devuelve_vacio() {
        let c = Cadena::nueva(Red::Testnet).unwrap();
        let ajeno = super::hash_cero();
        assert!(c.cabeceras_desde(&[ajeno], None).is_empty());
    }

    /// Y desde el génesis, que sí reconocemos, devuelve lo que hay después — hoy, nada.
    /// **La cadena se recupera de su almacén al arrancar.**
    ///
    /// Es la propiedad que justifica la persistencia: sin ella, cada reinicio resincronizaría desde
    /// el génesis. Con doce cabeceras es instantáneo; con un año de cadena serían horas.
    #[test]
    fn la_cadena_se_recupera_del_almacen_al_arrancar() {
        use std::sync::Arc;
        use zx_storage::AlmacenEnMemoria;

        let almacen: Arc<dyn zx_storage::almacen::AlmacenCadena> =
            Arc::new(AlmacenEnMemoria::nuevo());

        // Primera vida: se extiende a 6.
        {
            let c = Cadena::con_almacen(Red::Testnet, Arc::clone(&almacen)).unwrap();
            let mut prev = c.genesis();
            let mut nuevas = Vec::new();
            for i in 1..=6u32 {
                let h = zx_core::preimage::block::BlockHeader {
                    consensus_branch_id: 0xc478_80ea,
                    prev_hash: prev,
                    merkle_root: zx_core::digest::MerkleRoot::from_digest(
                        zx_core::digest::Digest::from_bytes([i as u8; 32]),
                    ),
                    timestamp: 1_788_480_000 + u64::from(i) * 120,
                    bits: 0x1d00_ffff,
                    nonce: u64::from(i),
                    height: i,
                };
                prev = h.block_hash();
                nuevas.push(h);
            }
            assert_eq!(c.extender(&nuevas), 6);
            assert_eq!(c.altura(), 6);
        }

        // Segunda vida: el mismo almacén, una Cadena nueva.
        let c2 = Cadena::con_almacen(Red::Testnet, almacen).unwrap();
        assert_eq!(c2.altura(), 6, "la cadena se recuperó del almacén");
        assert_eq!(c2.genesis(), c2.genesis());
        assert!(c2.trabajo() > primitive_types::U256::zero());
    }

    /// Extender guarda **el dato antes que la punta** (C-STORE-01).
    #[test]
    fn extender_deja_el_almacen_coherente() {
        use std::sync::Arc;
        use zx_storage::AlmacenEnMemoria;
        use zx_storage::almacen::AlmacenCadena;

        let almacen: Arc<dyn AlmacenCadena> = Arc::new(AlmacenEnMemoria::nuevo());
        let c = Cadena::con_almacen(Red::Testnet, Arc::clone(&almacen)).unwrap();

        let h = zx_core::preimage::block::BlockHeader {
            consensus_branch_id: 0xc478_80ea,
            prev_hash: c.genesis(),
            merkle_root: zx_core::digest::MerkleRoot::from_digest(
                zx_core::digest::Digest::from_bytes([1; 32]),
            ),
            timestamp: 1_788_480_120,
            bits: 0x1d00_ffff,
            nonce: 1,
            height: 1,
        };
        assert_eq!(c.extender(&[h]), 1);

        // La punta existe Y su cabecera está guardada. Lo contrario sería corrupción.
        let p = almacen.punta().unwrap().expect("hay punta");
        assert_eq!(p.altura, 1);
        assert!(
            almacen.cabecera(&p.hash).unwrap().is_some(),
            "C-STORE-01: la punta MUST apuntar a una cabecera guardada"
        );
    }

    /// Construye `n` cabeceras encadenadas a partir de `desde`, con un `sal` que las hace únicas.
    fn cadena_desde(desde: BlockHash, n: u32, sal: u8) -> Vec<BlockHeader> {
        let mut v = Vec::with_capacity(n as usize);
        let mut prev = desde;
        for i in 1..=n {
            let c = zx_core::preimage::block::BlockHeader {
                consensus_branch_id: 0xc478_80ea,
                prev_hash: prev,
                merkle_root: zx_core::digest::MerkleRoot::from_digest(
                    zx_core::digest::Digest::from_bytes([sal; 32]),
                ),
                timestamp: 1_788_480_000 + u64::from(i) * 120,
                bits: 0x1d00_ffff,
                nonce: u64::from(i) * 1000 + u64::from(sal),
                height: i,
            };
            prev = c.block_hash();
            v.push(c);
        }
        v
    }

    /// **P-028 · adoptar una rama que gana, deshaciendo la nuestra.**
    ///
    /// Es lo que faltaba: antes, una rama competidora válida se validaba bien y `extender` la
    /// descartaba entera, dejando al nodo en la cadena perdedora **sin error y sin aviso**.
    #[test]
    fn una_rama_con_mas_trabajo_se_adopta() {
        let c = Cadena::nueva(Red::Testnet).unwrap();

        // Nuestra cadena: 3 bloques.
        let nuestra = cadena_desde(c.genesis(), 3, 1);
        assert!(matches!(
            c.adoptar(&nuestra).unwrap(),
            super::Adopcion::Extendida { aplicadas: 3 }
        ));
        assert_eq!(c.altura(), 3);

        // Una rama que cuelga del génesis y es MÁS LARGA: 5 bloques, así que más trabajo.
        let rival = cadena_desde(c.genesis(), 5, 2);
        let r = c.adoptar(&rival).unwrap();
        assert_eq!(
            r,
            super::Adopcion::Reorganizada {
                aplicadas: 5,
                desechadas: 3
            }
        );
        assert_eq!(c.altura(), 5, "adoptamos la rama ganadora");
        assert_eq!(
            c.estado().tip,
            rival.last().unwrap().block_hash(),
            "la punta es la de la rama nueva"
        );
    }

    /// Una rama que **no** gana se rechaza — y no es mala fe.
    #[test]
    fn una_rama_con_menos_trabajo_no_se_adopta() {
        let c = Cadena::nueva(Red::Testnet).unwrap();
        let nuestra = cadena_desde(c.genesis(), 5, 1);
        c.adoptar(&nuestra).unwrap();
        assert_eq!(c.altura(), 5);

        let perdedora = cadena_desde(c.genesis(), 2, 2);
        assert_eq!(c.adoptar(&perdedora).unwrap(), super::Adopcion::NoGana);
        assert_eq!(c.altura(), 5, "nuestra cadena no se toca");
        assert_eq!(c.estado().tip, nuestra.last().unwrap().block_hash());
    }

    /// **C-REORG-07 · una reorg de más de 99 bloques NO se aplica.**
    ///
    /// Y lo que importa: **la cadena queda intacta**. La comprobación va antes de deshacer nada
    /// precisamente para que el caso excepcional no deje el estado a medias.
    #[test]
    fn una_reorg_demasiado_profunda_se_rechaza_sin_tocar_la_cadena() {
        use zx_consensus::fork_choice::MAX_REORG_LENGTH;

        let c = Cadena::nueva(Red::Testnet).unwrap();
        let nuestra = cadena_desde(c.genesis(), MAX_REORG_LENGTH + 5, 1);
        c.adoptar(&nuestra).unwrap();
        let altura_antes = c.altura();
        let tip_antes = c.estado().tip;
        assert_eq!(altura_antes, MAX_REORG_LENGTH + 5);

        // Una rama desde el génesis que gana pero exigiría deshacer 104 bloques.
        let rival = cadena_desde(c.genesis(), MAX_REORG_LENGTH + 10, 2);
        let e = c.adoptar(&rival).expect_err("MUST rechazarse");
        assert!(
            matches!(e, ConsensusError::ReorgDemasiadoProfunda { .. }),
            "{e:?}"
        );

        assert_eq!(c.altura(), altura_antes, "la cadena NO se tocó");
        assert_eq!(c.estado().tip, tip_antes, "la punta NO se movió");
    }

    /// Justo en el borde de la profundidad máxima **sí** se aplica.
    #[test]
    fn el_borde_exacto_de_la_profundidad_maxima_se_aplica() {
        use zx_consensus::fork_choice::MAX_REORG_LENGTH;

        let c = Cadena::nueva(Red::Testnet).unwrap();
        let nuestra = cadena_desde(c.genesis(), MAX_REORG_LENGTH, 1);
        c.adoptar(&nuestra).unwrap();

        // Deshacer exactamente MAX_REORG_LENGTH: permitido.
        let rival = cadena_desde(c.genesis(), MAX_REORG_LENGTH + 1, 2);
        assert!(
            c.adoptar(&rival).is_ok(),
            "deshacer exactamente {MAX_REORG_LENGTH} MUST permitirse"
        );
        assert_eq!(c.altura(), MAX_REORG_LENGTH + 1);
    }

    /// Las cabeceras desechadas **siguen recuperables por su hash**.
    ///
    /// Lo que se rehace es el índice de la cadena principal, no el almacén: las necesitaría una
    /// reorg que volviera atrás, y borrarlas haría que volver fuera imposible.
    #[test]
    fn las_cabeceras_desechadas_siguen_en_el_almacen() {
        let c = Cadena::nueva(Red::Testnet).unwrap();
        let nuestra = cadena_desde(c.genesis(), 3, 1);
        c.adoptar(&nuestra).unwrap();
        let desechada = nuestra.last().unwrap().block_hash();

        let rival = cadena_desde(c.genesis(), 5, 2);
        c.adoptar(&rival).unwrap();

        assert!(
            c.almacen().cabecera(&desechada).unwrap().is_some(),
            "la cabecera desechada MUST seguir recuperable por su hash"
        );
        assert!(
            c.trabajo_hasta(desechada).is_none(),
            "pero ya no está en la cadena principal"
        );
    }

    /// Una cadena que no cuelga de nada nuestro se detecta sin tocar nada.
    #[test]
    fn una_cadena_que_no_cuelga_de_nada_se_detecta() {
        let c = Cadena::nueva(Red::Testnet).unwrap();
        let ajena = cadena_desde(super::hash_cero(), 3, 9);
        assert_eq!(c.adoptar(&ajena).unwrap(), super::Adopcion::NoCuelgaDeNada);
        assert_eq!(c.altura(), 0);
    }

    /// **P-029 · un lock envenenado NO hace que el nodo mienta sobre su cadena.**
    ///
    /// La versión anterior devolvía altura 0, trabajo 0 y tip = génesis, y **el nodo seguía
    /// anunciando esos valores a la red**. Ahora se recupera el contenido —que es válido: los datos
    /// están bien, solo murió quien los tocaba— y se registra el suceso como error.
    ///
    /// El test envenena el lock a propósito desde otro hilo y comprueba que la cadena sigue
    /// diciendo la verdad.
    #[test]
    fn un_lock_envenenado_no_hace_mentir_al_nodo() {
        use std::sync::Arc;

        let c = Arc::new(Cadena::nueva(Red::Testnet).unwrap());
        let cs = cadena_desde(c.genesis(), 4, 1);
        c.adoptar(&cs).unwrap();

        let altura_antes = c.altura();
        let tip_antes = c.estado().tip;
        let trabajo_antes = c.trabajo();
        assert_eq!(altura_antes, 4);

        // Envenenar el lock: un hilo que entra en pánico teniéndolo.
        let c2 = Arc::clone(&c);
        let h = std::thread::spawn(move || {
            let _guard = c2.cabeceras_para_envenenar().write();
            panic!("envenenando el lock a propósito");
        });
        assert!(h.join().is_err(), "el hilo debía entrar en pánico");

        // Y ahora la comprobación que importa: el nodo sigue diciendo la verdad.
        assert_eq!(c.altura(), altura_antes, "la altura NO se degrada a 0");
        assert_eq!(c.estado().tip, tip_antes, "el tip NO se degrada al génesis");
        assert_eq!(c.trabajo(), trabajo_antes, "el trabajo NO se degrada a 0");
        assert!(!c.locator().is_empty(), "el locator sigue funcionando");
    }

    /// Una lista vacía no hace nada, y no es un error.
    #[test]
    fn adoptar_nada_no_hace_nada() {
        let c = Cadena::nueva(Red::Testnet).unwrap();
        assert_eq!(c.adoptar(&[]).unwrap(), super::Adopcion::NadaQueHacer);
        assert_eq!(c.altura(), 0);
    }

    /// Tras una reorg, el locator refleja la rama nueva y sigue cerrando en el génesis.
    ///
    /// Si el locator siguiera apuntando a la rama vieja, el nodo pediría desde un punto que ya no
    /// es suyo y no avanzaría nunca.
    #[test]
    fn el_locator_refleja_la_rama_adoptada() {
        let c = Cadena::nueva(Red::Testnet).unwrap();
        let vieja = cadena_desde(c.genesis(), 4, 1);
        c.adoptar(&vieja).unwrap();

        let nueva = cadena_desde(c.genesis(), 6, 2);
        c.adoptar(&nueva).unwrap();

        let l = c.locator();
        assert_eq!(
            *l.first().unwrap(),
            nueva.last().unwrap().block_hash(),
            "el locator empieza en la punta NUEVA"
        );
        assert_eq!(
            *l.last().unwrap(),
            c.genesis(),
            "y sigue cerrando en el génesis"
        );
        for h in &vieja {
            assert!(
                !l.contains(&h.block_hash()),
                "ninguna cabecera de la rama vieja debe seguir en el locator"
            );
        }
    }

    #[test]
    fn un_locator_con_el_genesis_se_reconoce() {
        let c = Cadena::nueva(Red::Testnet).unwrap();
        // No hay bloques tras el génesis todavía, así que la lista es vacía; lo que importa es que
        // el camino de "sí te reconozco" se recorre sin error.
        assert!(c.cabeceras_desde(&[c.genesis()], None).is_empty());
    }
}

#[cfg(test)]
#[expect(
    clippy::unwrap_used,
    clippy::expect_used,
    reason = "los tests fallan con panic por diseño"
)]
mod tests_cuerpo {
    use super::{RechazoCuerpo, comprobar_cuerpo};
    use zx_core::amount::Amount;
    use zx_core::digest::{Digest, MerkleRoot, TxId};
    use zx_core::firma::ClavePublica;
    use zx_core::preimage::block::{BlockHeader, merkle_root};
    use zx_core::preimage::tx::txid;
    use zx_core::tx::{Lock, OutPoint, Tx, TxIn, TxOut};
    use zx_p2p::mensaje::BloqueRed;

    const RAMA: u32 = 0xc478_80ea;

    fn tx(valor: i64) -> Tx {
        Tx {
            version: 1,
            inputs: vec![TxIn {
                outpoint: OutPoint {
                    prev_txid: TxId::from_digest(Digest::from_bytes([7; 32])),
                    prev_index: 0,
                },
                sequence: 0xffff_fffe,
            }],
            outputs: vec![TxOut {
                value: Amount::nuevo(valor).unwrap(),
                lock: Lock::PubKey {
                    pubkey: ClavePublica::desde_bytes([9; 32]),
                },
            }],
            lock_time: 0,
            expiry_height: 1,
        }
    }

    /// Un bloque coherente: la cabecera compromete exactamente estas transacciones.
    fn bloque(txs: Vec<Tx>) -> BloqueRed {
        let txids: Vec<TxId> = txs.iter().map(|t| txid(t, RAMA)).collect();
        let testigos = txs.iter().map(|_| vec![vec![0x5a; 64]]).collect();
        BloqueRed {
            cabecera: BlockHeader {
                consensus_branch_id: RAMA,
                prev_hash: zx_core::digest::BlockHash::from_digest(Digest::from_bytes([0; 32])),
                merkle_root: merkle_root(&txids),
                timestamp: 1_788_480_120,
                bits: 0x1d00_ffff,
                nonce: 1,
                height: 1,
            },
            txs,
            testigos,
        }
    }

    #[test]
    fn un_cuerpo_que_corresponde_a_su_cabecera_pasa() {
        comprobar_cuerpo(&bloque(vec![tx(50_000)])).expect("es el suyo");
        comprobar_cuerpo(&bloque(vec![tx(1), tx(2), tx(3)])).expect("también con varias");
    }

    /// **El ataque.** La cabecera correcta —la que pedimos y ya validamos— con otro cuerpo.
    ///
    /// Sin esta comprobación lo guardábamos bajo el hash bueno y se lo servíamos a otros peers como
    /// si fuera el bloque real.
    #[test]
    fn la_cabecera_buena_con_otro_cuerpo_se_rechaza() {
        let bueno = bloque(vec![tx(50_000)]);
        let mut falso = bloque(vec![tx(999_999)]);
        // Se conserva la cabecera del bueno: el hash bajo el que se indexaría es el correcto.
        falso.cabecera = bueno.cabecera;

        assert_eq!(
            comprobar_cuerpo(&falso),
            Err(RechazoCuerpo::RaizNoCoincide),
            "un cuerpo distinto bajo la cabecera buena MUST rechazarse"
        );
    }

    /// Cambiar **una sola** transacción de un bloque de varias también se ve.
    #[test]
    fn cambiar_una_transaccion_de_muchas_tambien_se_ve() {
        let mut b = bloque(vec![tx(1), tx(2), tx(3)]);
        *b.txs.get_mut(1).unwrap() = tx(20);
        assert_eq!(comprobar_cuerpo(&b), Err(RechazoCuerpo::RaizNoCoincide));
    }

    /// **La rama de consenso sale de la cabecera, no de nuestra tabla.**
    ///
    /// El txid depende de `consensus_branch_id` (C-TX-05). Si la comprobación usara la rama que
    /// nosotros creemos activa, un bloque de otra rama fallaría por el motivo equivocado — y, peor,
    /// tras una actualización de red dejarían de cuadrar bloques históricos perfectamente válidos.
    #[test]
    fn la_raiz_se_calcula_con_la_rama_de_la_cabecera() {
        let mut b = bloque(vec![tx(50_000)]);
        // Mismo cuerpo, otra rama: la raíz comprometida ya no es la que producen estos txids.
        b.cabecera.consensus_branch_id = 0x1234_5678;
        assert_eq!(
            comprobar_cuerpo(&b),
            Err(RechazoCuerpo::RaizNoCoincide),
            "cambiar la rama cambia los txids y por tanto la raíz"
        );

        // Y si la raíz se recalcula con la rama nueva, vuelve a cuadrar.
        let txids: Vec<TxId> = b.txs.iter().map(|t| txid(t, 0x1234_5678)).collect();
        b.cabecera.merkle_root = merkle_root(&txids);
        comprobar_cuerpo(&b).expect("con su propia rama, cuadra");
    }

    #[test]
    fn un_bloque_sin_transacciones_no_existe() {
        let mut b = bloque(vec![tx(1)]);
        b.txs.clear();
        b.testigos.clear();
        // La raíz de la lista vacía es un valor legítimo, así que sin la comprobación de C-BLK-07
        // una cabecera fabricada para ella cuadraría.
        b.cabecera.merkle_root = MerkleRoot::from_digest(merkle_root(&[]).digest().to_owned());
        assert_eq!(comprobar_cuerpo(&b), Err(RechazoCuerpo::SinCoinbase));
    }

    #[test]
    fn los_testigos_van_en_paralelo_a_las_transacciones() {
        let mut b = bloque(vec![tx(1), tx(2)]);
        b.testigos.pop();
        assert_eq!(
            comprobar_cuerpo(&b),
            Err(RechazoCuerpo::TestigosDescuadrados {
                txs: 2,
                testigos: 1
            })
        );
    }
}
