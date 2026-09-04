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

use std::sync::RwLock;

use zx_consensus::activacion::rama_activa;
use zx_core::digest::BlockHash;
use zx_core::preimage::block::BlockHeader;
use zx_core::red::Red;
use zx_p2p::entrante::{ManejadorEntrante, Veredicto};
use zx_p2p::mensaje::{BloqueRed, Estado};

/// Lo que el nodo sabe de su propia cadena.
///
/// De momento solo la punta y las cabeceras que ha visto. El UTXO set y el mempool se conectarán
/// cuando exista el sincronizador — meterlos ahora sería cablear algo que todavía no se usa.
#[derive(Debug)]
pub struct Cadena {
    red: Red,
    genesis: BlockHash,
    /// Cabeceras por altura, de menor a mayor. La punta es la última.
    ///
    /// `RwLock` y no un actor con canal: las lecturas son muy frecuentes —cada petición entrante
    /// consulta el estado— y las escrituras raras, una por bloque aceptado. Es exactamente el
    /// patrón para el que un `RwLock` es la respuesta correcta, y montar un actor aquí sería
    /// complejidad sin problema que resolver.
    cabeceras: RwLock<Vec<BlockHeader>>,
}

impl Cadena {
    /// Arranca la cadena en su génesis.
    ///
    /// # Errores
    /// Lo que devuelva la comprobación de arranque del génesis (C-GEN-01, C-GEN-06, C-GEN-07).
    pub fn nueva(red: Red) -> Result<Self, zx_consensus::error::ConsensusError> {
        let params = match red {
            Red::Mainnet => zx_consensus::genesis::GENESIS_MAINNET,
            Red::Testnet => zx_consensus::genesis::GENESIS_TESTNET,
        };

        // C-GEN-07 · esto es lo que aborta el arranque si el binario no es de esta cadena.
        let genesis = zx_consensus::genesis::comprobar_al_arrancar(params)?;
        let (cabecera, _) = zx_consensus::genesis::construir(params)?;

        Ok(Self {
            red,
            genesis,
            cabeceras: RwLock::new(vec![cabecera]),
        })
    }

    /// La red de esta cadena.
    ///
    /// Todavía sin consumidor: lo usará el sincronizador.
    #[expect(dead_code, reason = "lo usará el sincronizador")]
    #[must_use]
    pub const fn red(&self) -> Red {
        self.red
    }

    /// El hash del génesis.
    #[must_use]
    pub const fn genesis(&self) -> BlockHash {
        self.genesis
    }

    /// Altura de la punta.
    #[must_use]
    pub fn altura(&self) -> u32 {
        self.cabeceras
            .read()
            .map(|c| u32::try_from(c.len().saturating_sub(1)).unwrap_or(u32::MAX))
            .unwrap_or(0)
    }

    /// La rama de consenso activa a la altura actual.
    ///
    /// # Errores
    /// [`zx_consensus::error::ConsensusError::SinRamaActiva`] con una tabla mal formada.
    pub fn rama(&self) -> Result<u32, zx_consensus::error::ConsensusError> {
        rama_activa(self.red, self.altura())
    }

    /// Un locator de la punta hacia atrás: denso al principio, espaciado después.
    ///
    /// La densidad no es estética. Un locator lineal necesitaría tantas peticiones como bloques de
    /// bifurcación haya; uno con espaciado exponencial encuentra el punto de bifurcación en
    /// `O(log n)`. Es el mecanismo de Bitcoin desde el principio, y la razón de que la petición de
    /// cabeceras lleve una **lista** y no una altura: pedir "desde la altura N" supondría que los
    /// dos estamos en la misma cadena, que es justo lo que hay que averiguar.
    // `cfg_attr(not(test), ...)` y no un `expect` a secas: en la compilación de tests **sí** se
    // usa —hay un test del locator—, así que allí la expectativa quedaría sin cumplir y clippy lo
    // señalaría, con razón.
    #[cfg_attr(
        not(test),
        expect(
            dead_code,
            reason = "lo usará el sincronizador; ya está escrito y probado, no se borra para \
                      reescribirlo dentro de dos días"
        )
    )]
    #[must_use]
    pub fn locator(&self) -> Vec<BlockHash> {
        let Ok(cs) = self.cabeceras.read() else {
            return Vec::new();
        };
        let mut v = Vec::new();
        let mut paso = 1usize;
        let mut i = cs.len();

        while i > 0 {
            i = i.saturating_sub(paso);
            if let Some(c) = cs.get(i) {
                v.push(c.block_hash());
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
                .and_then(|c| c.last().map(BlockHeader::block_hash))
                .unwrap_or(self.genesis),
            altura: self.altura(),
            // TODO: el trabajo acumulado real sale de `zx_core::target::TrabajoAcumulado` cuando
            // exista el sincronizador. Cero es honesto mientras no haya cadena que acumular.
            trabajo: [0u8; 32],
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
        let Ok(cs) = self.cabeceras.read() else {
            return Vec::new();
        };
        // El primer hash del locator que reconozcamos marca desde dónde servir. Que no
        // reconozcamos ninguno es una respuesta legítima: significa que no compartimos historia.
        for h in locator {
            if let Some(pos) = cs.iter().position(|c| c.block_hash() == *h) {
                return cs.get(pos + 1..).unwrap_or_default().to_vec();
            }
        }
        Vec::new()
    }

    fn bloques_por_hash(&self, _hashes: &[BlockHash]) -> Vec<BloqueRed> {
        // TODO(zx-storage): los cuerpos vivirán en disco. Hoy el nodo solo tiene cabeceras.
        Vec::new()
    }
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
    #[test]
    fn un_locator_con_el_genesis_se_reconoce() {
        let c = Cadena::nueva(Red::Testnet).unwrap();
        // No hay bloques tras el génesis todavía, así que la lista es vacía; lo que importa es que
        // el camino de "sí te reconozco" se recorre sin error.
        assert!(c.cabeceras_desde(&[c.genesis()], None).is_empty());
    }
}
