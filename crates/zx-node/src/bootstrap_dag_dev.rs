//! Bootstrap aislado del génesis DAG de **desarrollo** (pieza C3, incremento parcial).
//!
//! # Qué es
//!
//! Construye con [`construir_dag_dev`] un génesis DAG de desarrollo a partir de un perfil
//! **explícito y privado**, lo comprueba con [`comprobar_estructura_y_hash_dag_dev`] contra un
//! `block_hash` **congelado literal** y, solo si ambas cosas pasan, expone un estado inicial para
//! la futura ruta DAG: el bloque completo, su hash congelado, `f_0` y el `pot_output` del génesis
//! como **ancla PoT confiada del slot 0**.
//!
//! Este módulo **no cierra C3** ni habilita una red. Es la excepción provisional C3-ARRANQUE,
//! aislada en una ruta optativa: el nodo activo (`main.rs`, `cadena.rs` y la cabecera lineal)
//! **no lo llama** y sigue intacto. El binario que lo ejecuta es `zx-dag-dev`.
//!
//! # La doble circularidad que este bootstrap NO resuelve
//!
//! `C-FLU-06` define `semilla(f_0, 0) = blake3(block_hash(génesis) ‖ entropía_externa)[0..16)`,
//! mientras que `block_hash` incluye `pot_output`, la solución PoAS y el sello (`C-HDR-09`). Si se
//! exigieran al génesis las reglas ordinarias de PoT y PoAS, el reto y la salida dependerían de su
//! propio hash: cambiar la solución para satisfacer el reto cambiaría a su vez el reto. A eso se
//! suma que, con `D = 0`, `pot_output(G)` sería a la vez la salida del slot 0 (`C-POT-05`) y un
//! campo del hash que fija la semilla con la que se evalúa esa misma salida. Resolver esa
//! circularidad es exactamente lo que falta en C3-ARRANQUE; este módulo **no la resuelve**.
//!
//! Por eso el `pot_output(G)` del hash literal congelado se trata como **ancla confiada del slot
//! 0** —un dato fijado de común acuerdo con el perfil— y **no** como una salida AES acreditada
//! desde `semilla(f_0, 0)`. La función pura `zx_consensus::pot::semilla_genesis` podría calcular
//! esa semilla, pero este módulo **no la usa** ni para validar el ancla ni para derivarla: usarla
//! para afirmar que se verificó el ancla reintroduciría el punto fijo que la decisión señala.
//!
//! # Qué NO hace
//!
//! - **No admite PoST.** No verifica PoT, PoAS ni sello del génesis, no deriva altura ni rama y no
//!   declara el bloque válido. La coinbase del génesis tiene valor cero y este bootstrap **no la
//!   inserta** en ningún UTXO ni expone un método para aplicarla; comprobar que **no queda un UTXO
//!   activo** sigue **pendiente de integración** y no se presenta aquí como verificado.
//! - **No elige parámetros de lanzamiento.** Todos los números son **elegidos para el fixture
//!   dev** y están congelados aquí; no son medidos, no son valores de red y no pueden confundirse
//!   con mainnet ni testnet. El perfil fija `D_dev = 0`, un solo flujo y el `SR` fijo del fixture
//!   **solo para preparación**; **no** fija `N_dev` ni la tasa de slots.
//! - **No toca la red.** El binario `zx-dag-dev` no acepta `--red`, `--peer` ni `--datos`, no abre
//!   sockets y no abre RocksDB.
//! - **No usa `AlmacenAdmitidosDag`** ni `AlmacenGhostdag::anadir_sintetico`: atribuirían admisión
//!   PoST a un fixture.
//!
//! # La entropía pública dev
//!
//! [`ENTROPIA_PUBLICA_DEV`] es un literal **elegido para desarrollo** y se expone como dato del
//! perfil a través de [`EstadoBootstrapDagDev::entropia_publica_dev`]. No es un precompromiso de
//! lanzamiento, no se presenta como tal y este módulo no lo usa para validar ni derivar el ancla:
//! `C-FLU-06` deja `<<PENDIENTE>>` el valor de entropía externa por red.

use thiserror::Error;

use zx_consensus::genesis_dag::{
    ErrorGenesisDagDev, ParametrosGenesisDagDev, comprobar_estructura_y_hash_dag_dev,
    construir_dag_dev,
};
use zx_core::preimage::flow::flujo_genesis;
use zx_core::{BlockHash, BloqueDag, ClavePublica, Digest, SolucionPoas};

/// Marca de la coinbase del fixture dev. Se condensa por XOR en 32 B: es la misma que usa el
/// fixture congelado de `zx-consensus/tests/genesis_dag.rs`. **Elegida para el fixture dev**, no
/// un mensaje de lanzamiento (`C-GEN-05` sigue pendiente).
const MENSAJE_DEV: &[u8] = b"ZEROX DAG dev genesis fixture - elegido para test, sin valor";

/// Segundos Unix del fixture dev, posteriores a `TIMESTAMP_MINIMO_GENESIS` (`C-GEN-06`).
/// **Elegido para el fixture dev**, no medido.
const TIMESTAMP_DEV: u64 = 1_800_000_000;

/// Rama de consenso del fixture dev. Dato explícito de desarrollo; **no** es la rama activa de
/// ninguna red ni una afirmación de `C-HDR-02b`.
const RAMA_DEV: u32 = 0x0D06_0001;

/// `pot_output` del fixture dev. Se trata como **ancla PoT confiada del slot 0**, no como salida
/// AES acreditada. **Elegido para el fixture dev**, no medido.
const POT_DEV: [u8; 16] = [
    0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88, 0x99, 0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xF0, 0x0F,
];

/// Rango de solución del fixture dev. Fijo **solo para preparación**; no es el rango de una red.
const SR_DEV: u64 = 0x00AB_CDEF;

/// Retardo de preparación `D_dev` del perfil dev. **Elegido solo para desarrollo** (`0`): no es una
/// norma de consenso ni un dato medido, y el perfil no fija `N_dev` ni la tasa de slots.
const RETARDO_DEV: u64 = 0;

/// Sello del fixture dev. No es una firma Ed25519 válida y este módulo no lo verifica. **Elegido
/// para el fixture dev**.
const SELLO_DEV: [u8; 64] = [0x5A; 64];

/// `block_hash` **congelado** del fixture dev, obtenido una sola vez de la construcción
/// determinista y fijado como literal. Es el ancla de confianza de C3-ARRANQUE: la comparación se
/// hace contra este literal, **nunca** contra el hash del bloque recién construido.
const HASH_DEV: [u8; 32] = [
    4, 0, 228, 160, 3, 45, 150, 243, 155, 108, 165, 251, 38, 47, 168, 55, 66, 41, 232, 57, 230, 84,
    144, 102, 6, 224, 105, 216, 129, 184, 225, 127,
];

/// Entropía pública del perfil dev. **Elegida para desarrollo**: no es un precompromiso de
/// lanzamiento y este módulo no la usa para validar ni derivar el ancla del slot 0.
const ENTROPIA_PUBLICA_DEV: &[u8] =
    b"ZEROX entropia publica dev - elegida para desarrollo, sin precompromiso";

/// Perfil del fixture dev. Todos los valores salen de las constantes privadas de este módulo y el
/// `hash_esperado` es el literal congelado, no el hash del bloque recién construido.
fn parametros_dev() -> ParametrosGenesisDagDev<'static> {
    ParametrosGenesisDagDev {
        mensaje_marca_dev: MENSAJE_DEV,
        timestamp: TIMESTAMP_DEV,
        consensus_branch_id: RAMA_DEV,
        pot_output: POT_DEV,
        rango_solucion: SR_DEV,
        solucion: solucion_fixture_dev(),
        sello: SELLO_DEV,
        hash_esperado: BlockHash::from_digest(Digest::from_bytes(HASH_DEV)),
    }
}

/// Solución PoAS del fixture dev. Es un dato arbitrario **elegido para el fixture**: este módulo
/// **no** la verifica (ni KZG, ni prueba de espacio, ni sello).
fn solucion_fixture_dev() -> SolucionPoas {
    SolucionPoas {
        public_key: ClavePublica::desde_bytes([0x21; 32]),
        sector_index: 7,
        history_size: 0x0102_0304_0506_0708,
        piece_offset: 9,
        record_commitment: [0x31; 48],
        record_witness: [0x32; 48],
        chunk: [0x33; 32],
        chunk_witness: [0x34; 48],
        proof_of_space: [0x35; 160],
    }
}

/// Fallo tipado del bootstrap aislado del génesis DAG de desarrollo.
#[derive(Debug, Error)]
pub enum ErrorBootstrapDagDev {
    /// La construcción o la comprobación de estructura y hash del candidato dev falló.
    #[error("el génesis DAG dev no superó estructura y hash: {0}")]
    GenesisDagDev(#[from] ErrorGenesisDagDev),
}

/// Estado inicial de la ruta DAG de **desarrollo** tras un bootstrap que superó estructura y hash.
///
/// Conserva el bloque completo, el hash **congelado** del literal, `f_0` y el `pot_output(G)` como
/// **ancla PoT confiada del slot 0**. Sus campos son privados y ningún getter nombra una admisión
/// PoST: los nombres dicen explícitamente `dev`. **No** es un estado de producción: este bootstrap
/// no inserta la coinbase del génesis en el UTXO set ni ofrece método para aplicarla, pero la
/// **ausencia de un UTXO activo sigue pendiente de integración** y no queda comprobada por él.
#[derive(Clone, Debug)]
pub struct EstadoBootstrapDagDev {
    bloque: BloqueDag,
    hash_congelado: BlockHash,
    f0: [u8; 32],
    ancla_pot_slot_0: [u8; 16],
    retardo_pot_dev: u64,
}

impl EstadoBootstrapDagDev {
    /// Bloque génesis del fixture dev. Es el candidato que superó estructura y hash; **no** es un
    /// bloque admitido por PoST y no debe insertarse en el estado.
    #[must_use]
    pub fn bloque_dev(&self) -> &BloqueDag {
        &self.bloque
    }

    /// Hash **congelado** del génesis dev. Es el literal de [`HASH_DEV`] con el que se comparó; no
    /// se recalcula del bloque para devolverlo.
    #[must_use]
    pub fn hash_congelado_dev(&self) -> BlockHash {
        self.hash_congelado
    }

    /// `f_0 = H_flujo(ETIQUETA_GENESIS ‖ block_hash(génesis))` (`C-FLU-06`) del hash congelado.
    #[must_use]
    pub fn f0_dev(&self) -> [u8; 32] {
        self.f0
    }

    /// `pot_output(G)` del génesis dev, tratado como **ancla PoT confiada del slot 0**.
    ///
    /// No es una salida AES acreditada desde `semilla(f_0, 0)`: es el dato del hash congelado con
    /// el que arranca la futura ruta DAG. Los bloques de slot ≥ 1 tendrán que demostrar PoT por AES
    /// **desde esta ancla**; este estado no lo hace por ellos.
    #[must_use]
    pub fn ancla_pot_slot_0_dev(&self) -> [u8; 16] {
        self.ancla_pot_slot_0
    }

    /// Entropía pública del perfil dev, expuesta como dato.
    ///
    /// Es un literal **elegido para desarrollo**, no un precompromiso de lanzamiento, y este
    /// bootstrap no la usa para validar ni derivar el ancla del slot 0.
    #[must_use]
    pub fn entropia_publica_dev(&self) -> &'static [u8] {
        ENTROPIA_PUBLICA_DEV
    }

    /// `D_dev` del perfil dev: retardo de preparación que fija el ancla confiada del slot 0.
    ///
    /// Es un valor **elegido solo para desarrollo**, no una norma de consenso ni un dato medido; el
    /// perfil no fija `N_dev` ni la tasa de slots.
    #[must_use]
    pub fn retardo_pot_dev(&self) -> u64 {
        self.retardo_pot_dev
    }
}

/// Construye, comprueba y **solo entonces** crea el estado a partir de un perfil explícito.
///
/// Es **privado a propósito**: la única ruta pública es [`iniciar_bootstrap_dag_dev`], que lo llama
/// con [`parametros_dev`]. No es API pública ni acepta un perfil desde el binario; existe para que
/// las pruebas ejerzan exactamente el mismo camino que la función pública.
fn iniciar_con_parametros_dev(
    parametros: &ParametrosGenesisDagDev<'_>,
) -> Result<EstadoBootstrapDagDev, ErrorBootstrapDagDev> {
    let bloque = construir_dag_dev(parametros)?;
    let _testigo = comprobar_estructura_y_hash_dag_dev(&bloque, parametros)?;

    // El hash congelado sale del `hash_esperado` externo del perfil, no del bloque recién
    // construido (la comprobación previa ya garantizó que coinciden).
    let hash_congelado = parametros.hash_esperado;
    let f0 = flujo_genesis(&hash_congelado);
    let ancla_pot_slot_0 = bloque.cabecera.pot_output;

    Ok(EstadoBootstrapDagDev {
        bloque,
        hash_congelado,
        f0,
        ancla_pot_slot_0,
        retardo_pot_dev: RETARDO_DEV,
    })
}

/// Arranca el bootstrap aislado del génesis DAG de desarrollo.
///
/// Construye el candidato con [`construir_dag_dev`], lo comprueba con
/// [`comprobar_estructura_y_hash_dag_dev`] contra el hash congelado y **solo entonces** crea el
/// estado. No verifica PoT, PoAS ni sello, no deriva la rama activa y no inserta la coinbase en
/// ningún UTXO.
///
/// El perfil está fijado en este módulo: **no** recibe argumentos, de modo que no existe una API
/// pública para inyectar un perfil arbitrario en producción.
///
/// # Errores
/// [`ErrorBootstrapDagDev::GenesisDagDev`] si el candidato no supera estructura y hash.
pub fn iniciar_bootstrap_dag_dev() -> Result<EstadoBootstrapDagDev, ErrorBootstrapDagDev> {
    iniciar_con_parametros_dev(&parametros_dev())
}

#[cfg(test)]
#[allow(
    clippy::unwrap_used,
    clippy::panic,
    clippy::indexing_slicing,
    reason = "los tests fallan con panic por diseño; el índice es sobre un array de anchura fija"
)]
mod pruebas {
    use super::{
        ErrorBootstrapDagDev, comprobar_estructura_y_hash_dag_dev, construir_dag_dev,
        iniciar_con_parametros_dev, parametros_dev,
    };
    use zx_consensus::genesis_dag::ErrorGenesisDagDev;
    use zx_core::{BlockHash, Digest};

    #[test]
    fn mutar_el_pot_output_del_fixture_dev_da_campo_no_coincide() {
        let p = parametros_dev();
        let mut bloque = construir_dag_dev(&p).unwrap();
        bloque.cabecera.pot_output[0] ^= 1;
        assert!(matches!(
            comprobar_estructura_y_hash_dag_dev(&bloque, &p),
            Err(ErrorGenesisDagDev::CampoNoCoincide {
                campo: "pot_output"
            })
        ));
    }

    #[test]
    fn el_bootstrap_rechaza_el_perfil_dev_con_hash_esperado_mutado() {
        // Mismo perfil dev, por el mismo camino privado que usa la función pública: el bootstrap
        // MUST negarse a crear estado cuando el hash esperado no es el literal congelado.
        let mut p_malo = parametros_dev();
        p_malo.hash_esperado = BlockHash::from_digest(Digest::from_bytes([0xFF; 32]));
        assert!(matches!(
            iniciar_con_parametros_dev(&p_malo),
            Err(ErrorBootstrapDagDev::GenesisDagDev(
                ErrorGenesisDagDev::HashNoCoincide { .. }
            ))
        ));
    }
}
