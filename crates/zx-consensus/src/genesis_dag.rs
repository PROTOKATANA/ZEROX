//! Génesis DAG de **desarrollo**: construcción y comprobación de estructura y hash (SPEC §15,
//! §6.1–§6.2).
//!
//! # Qué es y qué no es
//!
//! Este módulo prepara la pieza C3 sin cerrarla: construye un candidato a génesis DAG a partir de
//! parámetros **explícitos de desarrollo** y comprueba que su estructura y su `block_hash`
//! coinciden con un hash congelado que llega de fuera. **No admite PoST**, no verifica PoT, PoAS ni
//! sello, no deriva altura ni rama y no inserta nada en el estado. La ruta activa del nodo sigue
//! siendo la lineal.
//!
//! [`EstructuraYHashGenesisDagDev`] es un **testigo de estructura y hash**, no una admisión del
//! génesis. La decisión de arranque C3-ARRANQUE sigue abierta: no se elige una exención PoST, no se
//! deriva la semilla del hash final y no se declara válido ningún génesis de red.
//!
//! # La circularidad que este módulo NO resuelve
//!
//! La regla de flujo del génesis (§7.1.3) define `semilla(f_0, 0) = blake3(block_hash(génesis) ‖
//! entropía_externa)[0..16)`, mientras que `block_hash` sí incluye `pot_output`, la solución PoAS y
//! el sello (C-HDR-09). Si se exigieran al génesis las reglas ordinarias de PoT y PoAS, el reto y
//! la salida dependerían de su propio hash: cambiar la solución para satisfacer el reto cambiaría a
//! su vez el reto. Resolver esa circularidad es exactamente lo que falta en C3-ARRANQUE; esta API
//! **no la resuelve** —solo construye y comprueba la forma y el hash de un fixture de desarrollo—.
//! Tampoco copia la exención de PoW del génesis lineal: aquí no hay ninguna afirmación de exención,
//! solo comprobaciones estructurales sobre datos de prueba.
//!
//! # Límites, dichos sin adorno
//!
//! - El mensaje de la coinbase se reutiliza de [`crate::genesis::coinbase_genesis`], que lo
//!   condensa por XOR en 32 B. **No** preserva el texto legible en el wire; la referencia pública
//!   verificable de C-GEN-05 sigue pendiente y no se declara cumplida aquí.
//! - La coinbase de este génesis vale cero y **no entra** en el UTXO set (C-GEN-03). Este módulo no
//!   inserta en estado.
//! - `consensus_branch_id` es un dato **explícito de desarrollo elegido para el fixture**, no una
//!   afirmación de C-HDR-02b ni la rama activa de ninguna red. El módulo no usa
//!   [`crate::activacion::Red`].
//! - `hash_esperado` lo aporta el llamante. La comprobación **no** lo calcula del bloque para
//!   volver a usarlo: eso sería una tautología y no probaría nada. Que el llamante lo tenga
//!   congelado por una configuración de red **no** lo garantiza este tipo; integrarlo al arranque
//!   sigue pendiente (C-GEN-07).
//! - No hay `Default` ni constantes de génesis de mainnet/testnet: confundir un fixture de
//!   desarrollo con un parámetro de red es el error que este módulo evita cometer.

use thiserror::Error;

use zx_core::preimage::block::merkle_root;
use zx_core::{
    Amount, BlockHash, BloqueDag, DagBlockHeader, EncodingError, HASH_NULO, JustificacionPot,
    PadresDag, SolucionPoas, body_commitment, txid,
};

use crate::genesis::{TIMESTAMP_MINIMO_GENESIS, coinbase_genesis};

/// Parámetros **explícitos** de un génesis DAG de desarrollo.
///
/// Todos los campos son datos de entrada: no hay `Default` y no existe ninguna constante de este
/// tipo que pueda confundirse con los parámetros de mainnet o testnet. `mensaje_marca_dev` es un
/// préstamo con lifetime propio para no imponer `'static` a un fixture de test.
#[derive(Clone, Copy, Debug)]
pub struct ParametrosGenesisDagDev<'a> {
    /// Mensaje de la marca de la coinbase (fixture; ver [`crate::genesis::coinbase_genesis`]).
    ///
    /// Se condensa por XOR en 32 B y **no** conserva el texto legible en el wire.
    pub mensaje_marca_dev: &'a [u8],
    /// Segundos Unix declarados. Debe ser `>= TIMESTAMP_MINIMO_GENESIS` (C-GEN-06).
    pub timestamp: u64,
    /// Identificador de rama **de desarrollo**, dato explícito del fixture.
    ///
    /// No es la rama activa de ninguna red ni una afirmación de C-HDR-02b.
    pub consensus_branch_id: u32,
    /// Salida PoT declarada del génesis (16 B, campo de cabecera).
    pub pot_output: [u8; 16],
    /// Rango de solución declarado.
    pub rango_solucion: u64,
    /// Solución PoAS declarada. El fixture es arbitrario; aquí **no** se verifica.
    pub solucion: SolucionPoas,
    /// Sello declarado. El fixture es arbitrario; aquí **no** se verifica la firma.
    pub sello: [u8; 64],
    /// `block_hash` esperado, **dato externo congelado** (no se calcula del bloque).
    pub hash_esperado: BlockHash,
}

/// Fallo tipado al construir o comprobar el génesis DAG de desarrollo.
#[derive(Debug, Error, PartialEq, Eq, Clone)]
pub enum ErrorGenesisDagDev {
    /// C-GEN-06: el timestamp es anterior a [`TIMESTAMP_MINIMO_GENESIS`].
    #[error("C-GEN-06: timestamp del génesis DAG dev {0} anterior a TIMESTAMP_MINIMO_GENESIS")]
    TimestampNoPlausible(u64),
    /// C-HDR-02: el génesis MUST tener `height = 0`.
    #[error("C-HDR-02: el génesis DAG dev MUST tener height = 0; tiene {0}")]
    AlturaNoEsCero(u32),
    /// C-HDR-05: el génesis MUST tener `slot = 0`.
    #[error("C-HDR-05: el génesis DAG dev MUST tener slot = 0; tiene {0}")]
    SlotNoEsCero(u64),
    /// El génesis MUST tener cero padres.
    #[error("el génesis DAG dev MUST tener cero padres; parent_count = {0}")]
    PadresNoVacios(u8),
    /// `prev_hash` del génesis MUST ser el hash nulo.
    #[error("el génesis DAG dev MUST tener prev_hash nulo")]
    PadreSeleccionadoNoNulo,
    /// C-HDR-07: el génesis usa cero portadores de PoT.
    #[error("C-HDR-07: el génesis DAG dev MUST llevar justificación vacía; lleva {0} portadores")]
    JustificacionNoVacia(usize),
    /// El génesis tiene exactamente una transacción: la coinbase.
    #[error("el génesis DAG dev MUST tener exactamente una transacción; tiene {0}")]
    NumeroDeTransacciones(usize),
    /// El génesis tiene exactamente una lista de testigos.
    #[error("el génesis DAG dev MUST tener exactamente una lista de testigos; tiene {0}")]
    NumeroDeTestigos(usize),
    /// C-BLK-07: la coinbase no tiene entradas.
    #[error("C-BLK-07: la coinbase del génesis DAG dev MUST NOT tener entradas; tiene {0}")]
    CoinbaseConEntradas(usize),
    /// C-EMIT-04: la coinbase del génesis declara `expiry_height = 0`.
    #[error("C-EMIT-04: expiry_height de la coinbase del génesis DAG dev MUST ser 0; es {0}")]
    CoinbaseConExpiry(u32),
    /// C-GEN-03 / C-EMIT-02: la suma de salidas de la coinbase es cero.
    #[error("C-GEN-03/C-EMIT-02: Σ value(salidas) = {0} ≠ 0")]
    CoinbaseConValor(i64),
    /// La lista de testigos de la coinbase MUST estar vacía.
    #[error(
        "el testigo de la coinbase del génesis DAG dev MUST ser la lista vacía; tiene {0} entradas"
    )]
    TestigoCoinbaseNoVacio(usize),
    /// C-BLK-01: el `merkle_root` recalculado no coincide con la cabecera.
    #[error("C-BLK-01: merkle_root recalculado no coincide con la cabecera del génesis DAG dev")]
    MerkleNoCoincide,
    /// El `body_commitment` recalculado no coincide con la cabecera.
    #[error("body_commitment recalculado no coincide con la cabecera del génesis DAG dev")]
    CuerpoNoCoincide,
    /// La coinbase no es la derivada de `mensaje_marca_dev`.
    #[error("la coinbase del génesis DAG dev no es la derivada de mensaje_marca_dev")]
    CoinbaseNoEsLaDerivada,
    /// Un campo declarado de la cabecera no coincide con el parámetro explícito.
    #[error("campo {campo} de la cabecera no coincide con el parámetro explícito")]
    CampoNoCoincide {
        /// Nombre del campo que discrepa.
        campo: &'static str,
    },
    /// C-HDR-09: el `block_hash` no coincide con `hash_esperado`.
    #[error("C-HDR-09: block_hash del génesis DAG dev no coincide con hash_esperado")]
    HashNoCoincide {
        /// Hash congelado que se esperaba.
        esperado: BlockHash,
        /// Hash calculado del candidato.
        obtenido: BlockHash,
    },
    /// Error tipado de `zx-core` al calcular compromisos o sumar importes.
    #[error("error de zx-core en el génesis DAG dev: {0}")]
    Core(#[from] EncodingError),
}

/// Testigo de que un candidato a génesis DAG de desarrollo superó la comprobación de **estructura y
/// hash**.
///
/// Es un testigo **opaco**: no conserva el hash ni ningún otro dato que el llamante pueda leer o
/// recomponer. La comprobación de hash se hace contra `hash_esperado`, que aporta el llamante; que
/// ese valor esté congelado por una configuración de red **no** lo garantiza este tipo y sigue
/// pendiente de integración al arranque (C-GEN-07).
///
/// **No es `GenesisValido` y no habilita la admisión PoST.** No acredita la prueba de espacio ni la
/// de tiempo, no verifica el sello, no deriva la rama activa (C-HDR-02b) ni la altura, y **no**
/// debe usarse para insertar el génesis en el estado: la coinbase del génesis no entra en el UTXO
/// set (C-GEN-03).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct EstructuraYHashGenesisDagDev {
    /// Campo privado sin información: acredita que la comprobación terminó, nada más.
    _privado: (),
}

/// Construye un candidato a génesis DAG de **desarrollo** (C-GEN-01 como maquinaria, sin valores de
/// red).
///
/// Reutiliza [`crate::genesis::coinbase_genesis`] como fixture de coinbase de valor cero; los dos
/// compromisos se calculan del mismo tx bajo la rama explícita. Fija `height = 0`, `slot = 0`,
/// padres de génesis y justificación PoT vacía.
///
/// # Errores
/// [`ErrorGenesisDagDev::Core`] si `zx-core` rechaza la codificación (aritmética o descuadre).
pub fn construir_dag_dev(p: &ParametrosGenesisDagDev<'_>) -> Result<BloqueDag, ErrorGenesisDagDev> {
    let coinbase = coinbase_genesis(p.mensaje_marca_dev);
    let txids = [txid(&coinbase, p.consensus_branch_id)];
    let merkle_root_calculado = merkle_root(&txids);
    let testigos: Vec<Vec<Vec<u8>>> = vec![Vec::new()];
    let body_commitment_calculado = body_commitment(
        core::slice::from_ref(&coinbase),
        &testigos,
        p.consensus_branch_id,
    )?;

    let cabecera = DagBlockHeader {
        consensus_branch_id: p.consensus_branch_id,
        merkle_root: merkle_root_calculado,
        timestamp: p.timestamp,
        height: 0,
        slot: 0,
        pot_output: p.pot_output,
        rango_solucion: p.rango_solucion,
        sol: p.solucion,
        body_commitment: body_commitment_calculado,
        padres: PadresDag::genesis(),
        sello: p.sello,
    };

    let bloque = BloqueDag::nuevo(
        cabecera,
        JustificacionPot::vacia(),
        vec![coinbase],
        testigos,
    )?;
    Ok(bloque)
}

/// Comprueba **estructura y hash** de un candidato a génesis DAG de desarrollo.
///
/// No admite PoST ni verifica PoT, PoAS o sello. Devuelve un testigo opaco; ver
/// [`EstructuraYHashGenesisDagDev`].
///
/// La comparación de hash es contra `hash_esperado`, proporcionado por el llamante. El tipo **no**
/// garantiza que ese valor esté congelado por una configuración de red: esa garantía sigue pendiente
/// de integración al arranque (C-GEN-07).
///
/// El orden de las comprobaciones es deliberado: primero la forma (timestamp, altura, slot, padres,
/// justificación y cuerpo), después los campos declarados explícitos, luego la coinbase derivada y
/// los dos compromisos recalculados, y por último el `block_hash` contra el hash externo. Así una
/// mutación concreta se reporta con el motivo que le corresponde en vez de caer siempre en el hash.
///
/// # Errores
/// El [`ErrorGenesisDagDev`] concreto del primer requisito que falle. Nunca entra en pánico ante un
/// candidato recibido.
pub fn comprobar_estructura_y_hash_dag_dev(
    bloque: &BloqueDag,
    p: &ParametrosGenesisDagDev<'_>,
) -> Result<EstructuraYHashGenesisDagDev, ErrorGenesisDagDev> {
    let c = &bloque.cabecera;

    if c.timestamp < TIMESTAMP_MINIMO_GENESIS {
        return Err(ErrorGenesisDagDev::TimestampNoPlausible(c.timestamp));
    }
    if c.height != 0 {
        return Err(ErrorGenesisDagDev::AlturaNoEsCero(c.height));
    }
    if c.slot != 0 {
        return Err(ErrorGenesisDagDev::SlotNoEsCero(c.slot));
    }
    if c.padres.count() != 0 {
        return Err(ErrorGenesisDagDev::PadresNoVacios(c.padres.count()));
    }
    if c.padres.seleccionado() != HASH_NULO {
        return Err(ErrorGenesisDagDev::PadreSeleccionadoNoNulo);
    }
    if !bloque.justificacion.is_empty() {
        return Err(ErrorGenesisDagDev::JustificacionNoVacia(
            bloque.justificacion.len(),
        ));
    }

    let txs = bloque.txs();
    let testigos = bloque.testigos();
    if txs.len() != 1 {
        return Err(ErrorGenesisDagDev::NumeroDeTransacciones(txs.len()));
    }
    if testigos.len() != 1 {
        return Err(ErrorGenesisDagDev::NumeroDeTestigos(testigos.len()));
    }
    let Some(coinbase) = txs.first() else {
        return Err(ErrorGenesisDagDev::NumeroDeTransacciones(0));
    };
    if !coinbase.inputs.is_empty() {
        return Err(ErrorGenesisDagDev::CoinbaseConEntradas(
            coinbase.inputs.len(),
        ));
    }
    if coinbase.expiry_height != 0 {
        return Err(ErrorGenesisDagDev::CoinbaseConExpiry(
            coinbase.expiry_height,
        ));
    }
    // Suma **comprobada** (C-ENC-03): no se usa una suma cruda que desbordaría en silencio.
    let total = Amount::suma(coinbase.outputs.iter().map(|o| o.value))?;
    if total != Amount::CERO {
        return Err(ErrorGenesisDagDev::CoinbaseConValor(total.brek()));
    }
    let Some(testigo_coinbase) = testigos.first() else {
        return Err(ErrorGenesisDagDev::NumeroDeTestigos(0));
    };
    if !testigo_coinbase.is_empty() {
        return Err(ErrorGenesisDagDev::TestigoCoinbaseNoVacio(
            testigo_coinbase.len(),
        ));
    }

    // Campos declarados explícitos.
    if c.consensus_branch_id != p.consensus_branch_id {
        return Err(ErrorGenesisDagDev::CampoNoCoincide {
            campo: "consensus_branch_id",
        });
    }
    if c.timestamp != p.timestamp {
        return Err(ErrorGenesisDagDev::CampoNoCoincide { campo: "timestamp" });
    }
    if c.pot_output != p.pot_output {
        return Err(ErrorGenesisDagDev::CampoNoCoincide {
            campo: "pot_output",
        });
    }
    if c.rango_solucion != p.rango_solucion {
        return Err(ErrorGenesisDagDev::CampoNoCoincide {
            campo: "rango_solucion",
        });
    }
    if c.sol != p.solucion {
        return Err(ErrorGenesisDagDev::CampoNoCoincide { campo: "solucion" });
    }
    if c.sello != p.sello {
        return Err(ErrorGenesisDagDev::CampoNoCoincide { campo: "sello" });
    }

    if *coinbase != coinbase_genesis(p.mensaje_marca_dev) {
        return Err(ErrorGenesisDagDev::CoinbaseNoEsLaDerivada);
    }

    // Ambos compromisos con las funciones existentes, no con una copia. El `merkle_root` cubre los
    // datos de efecto; el `body_commitment` cubre efectos y autorización.
    let merkle_recalculado = merkle_root(&[txid(coinbase, c.consensus_branch_id)]);
    if merkle_recalculado != c.merkle_root {
        return Err(ErrorGenesisDagDev::MerkleNoCoincide);
    }
    let cuerpo_recalculado = body_commitment(txs, testigos, c.consensus_branch_id)?;
    if cuerpo_recalculado != c.body_commitment {
        return Err(ErrorGenesisDagDev::CuerpoNoCoincide);
    }

    let obtenido = c.block_hash();
    if obtenido != p.hash_esperado {
        return Err(ErrorGenesisDagDev::HashNoCoincide {
            esperado: p.hash_esperado,
            obtenido,
        });
    }

    Ok(EstructuraYHashGenesisDagDev { _privado: () })
}

#[cfg(test)]
#[expect(clippy::unwrap_used, reason = "los tests fallan con panic por diseño")]
mod tests {
    use super::{
        ErrorGenesisDagDev, ParametrosGenesisDagDev, comprobar_estructura_y_hash_dag_dev,
        construir_dag_dev,
    };
    use zx_core::{BlockHash, Digest, SolucionPoas};

    fn parametros_marcador() -> ParametrosGenesisDagDev<'static> {
        ParametrosGenesisDagDev {
            mensaje_marca_dev: b"marcador de posicion",
            // Marcador deliberado: incumple C-GEN-06 y no habilita ningún arranque.
            timestamp: 0,
            consensus_branch_id: 0x0D06_0001,
            pot_output: [0; 16],
            rango_solucion: 0,
            solucion: SolucionPoas::default(),
            sello: [0; 64],
            hash_esperado: BlockHash::from_digest(Digest::from_bytes([0; 32])),
        }
    }

    /// El smoke interno mantiene los puntos de entrada del módulo alcanzados por `zx-consensus`.
    #[test]
    fn el_timestamp_marcador_se_rechaza() {
        let p = parametros_marcador();
        let bloque = construir_dag_dev(&p).unwrap();
        assert!(matches!(
            comprobar_estructura_y_hash_dag_dev(&bloque, &p),
            Err(ErrorGenesisDagDev::TimestampNoPlausible(0))
        ));
    }
}
