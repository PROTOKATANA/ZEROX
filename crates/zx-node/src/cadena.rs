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
use zx_core::digest::BlockHash;
use zx_core::preimage::block::BlockHeader;
use zx_core::red::Red;
use zx_core::target::{CompactBits, trabajo_bloque};
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
/// # Por qué hay un índice y por qué el hash va guardado
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
        self.cabeceras
            .read()
            .map(|i| u32::try_from(i.len().saturating_sub(1)).unwrap_or(u32::MAX))
            .unwrap_or(0)
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
        if let Ok(mut i) = self.cabeceras.write() {
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
    }

    /// Trabajo acumulado de nuestra cadena hasta la punta.
    #[must_use]
    pub fn trabajo(&self) -> U256 {
        self.cabeceras
            .read()
            .map(|i| trabajo_de(&i.cadena))
            .unwrap_or_default()
    }

    /// Trabajo acumulado **hasta un hash concreto** de nuestra cadena, o `None` si no lo conocemos.
    ///
    /// Es lo que C-NET-04 necesita para juzgar una cadena candidata: el trabajo de la rama que el
    /// peer propone es *lo que compartimos hasta el ancla* más lo que él añade. Sumar al trabajo de
    /// la **punta** —que fue el primer intento— cuenta trabajo que no es de esa rama, y deja pasar
    /// cualquier bifurcación profunda.
    #[must_use]
    pub fn trabajo_hasta(&self, h: BlockHash) -> Option<U256> {
        let i = self.cabeceras.read().ok()?;
        // `O(1)` gracias al índice. Antes era `O(n)` **con un SHA3 por cabecera**, y se ejecutaba
        // sobre un `prev_hash` que el peer elige — o sea, un escaneo completo de nuestra cadena a
        // petición de cualquiera, antes de haber validado nada.
        let pos = *i.posicion.get(&h)?;
        Some(trabajo_de(i.cadena.get(..=pos)?))
    }

    /// Trabajo de un solo bloque a la dificultad de la punta, para el umbral de C-NET-04.
    #[must_use]
    pub fn trabajo_de_un_bloque(&self) -> U256 {
        self.cabeceras
            .read()
            .ok()
            .and_then(|i| i.punta())
            .and_then(|(_, c)| CompactBits::from_u32(c.bits).decodificar().ok())
            .and_then(trabajo_bloque)
            .unwrap_or_else(U256::one)
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
        let Ok(mut i) = self.cabeceras.write() else {
            return 0;
        };
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
        let Ok(idx) = self.cabeceras.read() else {
            return Vec::new();
        };
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

impl ManejadorEntrante for Cadena {
    fn estado(&self) -> Estado {
        Estado {
            genesis: self.genesis,
            tip: self
                .cabeceras
                .read()
                .ok()
                .and_then(|i| i.punta().map(|(h, _)| h))
                .unwrap_or(self.genesis),
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
        let Ok(idx) = self.cabeceras.read() else {
            return Vec::new();
        };
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

    fn bloques_por_hash(&self, _hashes: &[BlockHash]) -> Vec<BloqueRed> {
        // TODO(zx-storage): los cuerpos vivirán en disco. Hoy el nodo solo tiene cabeceras.
        Vec::new()
    }
}

/// Cuántas cabeceras se sirven como mucho en una respuesta.
///
/// Coincide con el límite de transporte de `zx-p2p`, y se aplica **antes de clonar**: recortar
/// después, como hacía la primera versión, significa que la asignación grande ya ocurrió.
const MAX_CABECERAS_SERVIDAS: usize = 2_000;

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
pub fn hash_cero() -> BlockHash {
    BlockHash::from_digest(zx_core::digest::Digest::from_bytes([0u8; 32]))
}

#[cfg(test)]
#[expect(
    clippy::unwrap_used,
    clippy::expect_used,
    reason = "los tests fallan con panic por diseño"
)]
mod tests {
    use super::Cadena;
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

    #[test]
    fn un_locator_con_el_genesis_se_reconoce() {
        let c = Cadena::nueva(Red::Testnet).unwrap();
        // No hay bloques tras el génesis todavía, así que la lista es vacía; lo que importa es que
        // el camino de "sí te reconozco" se recorre sin error.
        assert!(c.cabeceras_desde(&[c.genesis()], None).is_empty());
    }
}
