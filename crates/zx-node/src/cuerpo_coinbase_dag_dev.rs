//! Cuerpo coinbase cero del **primer hijo** DAG de desarrollo (incremento D2/B3/C3 parcial).
//!
//! # Qué es
//!
//! [`CuerpoCoinbaseCeroDagDev`] construye el cuerpo mínimo que la decisión provisional
//! `COINBASE-CERO-PRIMER-HIJO-DEV` permite para el primer bloque posterior al génesis dev `G`:
//! **exactamente una** transacción coinbase, sin entradas, con una única salida de valor
//! [`Amount::CERO`] pagada a una clave, `lock_time = 0` y `expiry_height` igual a la altura
//! derivada. Los dos compromisos que la cabecera DAG publica —`merkle_root` y `body_commitment`—
//! se calculan con las primitivas de `zx-core`, no con una copia local.
//!
//! [`comprobar_cuerpo_coinbase_cero_dev`] es el comprobador **limitado** que exige esa misma forma
//! y, después, recalcula los dos compromisos contra la cabecera con
//! [`comprobar_compromisos_cuerpo_dag`](zx_consensus::bloque_dag::comprobar_compromisos_cuerpo_dag),
//! conservando el error tipado de `zx-consensus` para que un Merkle roto y un `body_commitment`
//! roto sigan siendo distinguibles.
//!
//! Ambos están acotados al perfil **dev** del primer hijo `{G}`: no son una regla de
//! mainnet/testnet ni cierran D2/B3.
//!
//! # El cobro cero NO es un subsidio de consenso
//!
//! `C-EMIT-03` permite que `Σ value(salidas) ≤ subsidio(H) + Σ fees(bloque)`, así que
//! `Σ value(salidas) = 0` es un subcaso válido como **cobro voluntariamente inferior**. No es una
//! exención de `C-EMIT-03`, no es un subsidio y no decide la ruta económica: el subsidio, la
//! mediana efectiva `M(H)` y la penalización de `C-EMIT-06` siguen sin fuente causal en el DAG y no
//! se fabrican aquí.
//!
//! # Frontera: lo que este módulo NO cubre
//!
//! - **No es admisión.** No verifica PoT, PoAS, sello, UTXO, orden GHOSTDAG, reloj de pared ni
//!   publicación atómica.
//! - **No usa el validador lineal.** No llama a `validar_cuerpo` sobre la cabecera DAG: ese
//!   validador toma `Bloque<'_, BlockHeader>` lineal y no aplica aquí.
//! - **No cubre la ruta económica completa.** No comprueba subsidio, peso dinámico, firmas de
//!   gasto, timelocks, reloj ni UTXO. El comprobador solo afirma la forma del cuerpo coinbase cero
//!   y la coincidencia de `merkle_root`/`body_commitment`.
//! - **No acepta transacciones de usuario ni una segunda coinbase.** El perfil admite exactamente
//!   una transacción; cualquier otra cosa es un error explícito, nunca un `Ok`.
//! - **La rama es un supuesto dev.** El `consensus_branch_id` se copia de `G` **solo** como dato
//!   del fixture para esta construcción. No afirma la rama activa normativa de `C-HDR-02b`.
//!
//! # Reglas citadas
//!
//! - `C-BLK-01`: el `merkle_root` es la raíz sobre los `txid` en orden de aparición.
//! - `C-BLK-02`: los nodos internos del árbol usan la etiqueta de dominio del bloque.
//! - `C-BLK-03`: un nodo suelto se empareja con la hoja nula, nunca se duplica.
//! - `C-BLK-07`: la primera transacción es la coinbase; ninguna otra lo es.
//! - `C-EMIT-03`: la coinbase no tiene entradas y su suma de salidas es acotada; aquí es cero.
//! - `C-EMIT-04`: `expiry_height` de la coinbase es la altura de su bloque.

use thiserror::Error;

use zx_consensus::ConsensusError;
use zx_consensus::validacion::VERSION_TX;
use zx_core::preimage::block::merkle_root;
use zx_core::{
    Amount, BloqueDag, BodyCommitment, ClavePublica, EncodingError, Lock, MerkleRoot, Tx, TxOut,
    body_commitment, txid,
};

use crate::bootstrap_dag_dev::EstadoBootstrapDagDev;

/// Fallo tipado del cuerpo coinbase cero del primer hijo DAG dev.
///
/// Distingue las condiciones de forma del perfil dev (altura, rama, número de transacciones,
/// salida, `expiry_height`) de los dos errores de compromiso, que se conservan como
/// [`ConsensusError`] original para no confundir un Merkle roto con un `body_commitment` roto.
#[derive(Debug, Error)]
pub enum ErrorCuerpoCoinbaseDev {
    /// El génesis `G` del bootstrap declara una altura distinta de `0`.
    ///
    /// El perfil de este incremento solo cubre el **primer** hijo, así que exige `height(G) = 0`
    /// (`C-HDR-02`) antes de derivar la altura.
    #[error("C-HDR-02: G debe tener height = 0 para el perfil del primer hijo; declara {altura}")]
    GenesisConAlturaNoCero {
        /// Altura declarada por el génesis.
        altura: u32,
    },
    /// La altura derivada del primer hijo desborda `u32`.
    #[error("la altura derivada de G + 1 desborda u32")]
    AlturaDesbordada,
    /// `zx-core` rechazó el cálculo del `body_commitment`.
    #[error("error de zx-core al calcular el compromiso del cuerpo: {0}")]
    CompromisoDelCuerpo(#[from] EncodingError),
    /// Los padres del bloque no son exactamente `{G}`.
    #[error("los padres del bloque no son exactamente {{G}}")]
    PadresNoSonGenesis,
    /// La altura declarada no es la derivada de `G`.
    #[error("la altura declarada {encontrada} no es la derivada del primer hijo {esperada}")]
    AlturaNoEsPrimerHijo {
        /// Altura derivada de `G`.
        esperada: u32,
        /// Altura declarada por la cabecera.
        encontrada: u32,
    },
    /// La rama de consenso no es la rama dev copiada de `G`.
    ///
    /// Es una comprobación del **perfil dev**, no una afirmación de `C-HDR-02b`.
    #[error("la rama {encontrada:#010x} no es la rama dev de G {esperada:#010x}")]
    RamaDevNoCoincide {
        /// Rama dev copiada de `G`.
        esperada: u32,
        /// Rama declarada por la cabecera.
        encontrada: u32,
    },
    /// El bloque no lleva ninguna transacción (`C-BLK-07`).
    #[error("C-BLK-07: el bloque no lleva ninguna transacción; la primera MUST ser la coinbase")]
    BloqueSinCoinbase,
    /// El bloque lleva más de una transacción: el perfil solo admite la coinbase.
    #[error(
        "el perfil dev del primer hijo solo admite la coinbase; el bloque trae {encontradas} \
         transacciones"
    )]
    TransaccionesFueraDePerfil {
        /// Número de transacciones observadas.
        encontradas: usize,
    },
    /// El número de listas de testigos no es exactamente uno.
    #[error("la coinbase dev MUST llevar exactamente una lista de testigos; hay {encontradas}")]
    NumeroDeTestigosFueraDePerfil {
        /// Número de listas observadas.
        encontradas: usize,
    },
    /// La lista de testigos de la coinbase no está vacía.
    #[error("la lista de testigos de la coinbase dev MUST estar vacía; tiene {entradas} entradas")]
    TestigoDeCoinbaseNoVacio {
        /// Número de testigos de entrada observados.
        entradas: usize,
    },
    /// La versión de la coinbase no es `VERSION_TX`.
    #[error("la versión de la coinbase no es la admitida: {version}")]
    VersionDeCoinbaseNoAdmitida {
        /// Versión declarada.
        version: u32,
    },
    /// La coinbase lleva entradas (`C-BLK-07`, `C-EMIT-03`).
    #[error("la coinbase dev MUST NOT tener entradas; tiene {entradas}")]
    CoinbaseConEntradas {
        /// Número de entradas observadas.
        entradas: usize,
    },
    /// El número de salidas de la coinbase no es exactamente uno.
    #[error("la coinbase dev MUST tener exactamente una salida; tiene {salidas}")]
    NumeroDeSalidasFueraDePerfil {
        /// Número de salidas observadas.
        salidas: usize,
    },
    /// La salida de la coinbase no vale cero (`C-EMIT-03`).
    #[error("C-EMIT-03: la salida de la coinbase dev MUST ser de valor cero")]
    SalidaDeCoinbaseNoCero,
    /// La salida de la coinbase no bloquea a la clave del sello del bloque.
    #[error("la salida de la coinbase dev no bloquea a la clave del sello del bloque")]
    SalidaNoPagaAlSellador,
    /// La coinbase no lleva `lock_time = 0`.
    #[error("la coinbase dev MUST llevar lock_time = 0")]
    LockTimeNoCero,
    /// `expiry_height` de la coinbase no es la altura del bloque (`C-EMIT-04`).
    #[error("C-EMIT-04: expiry_height {expiry} de la coinbase distinto de la altura {altura}")]
    CoinbaseSinAltura {
        /// Altura del bloque.
        altura: u32,
        /// `expiry_height` declarado por la coinbase.
        expiry: u32,
    },
    /// Los compromisos del cuerpo no coinciden con la cabecera.
    ///
    /// Conserva el [`ConsensusError`] de `zx-consensus` sin reetiquetarlo, de modo que
    /// `MerkleRaizNoCoincide` y `CuerpoCompromisoNoCoincide` siguen siendo distinguibles.
    #[error("compromisos del cuerpo DAG: {0}")]
    Compromisos(#[from] ConsensusError),
}

/// Cuerpo de la coinbase cero del primer hijo DAG dev: una transacción y sus compromisos.
///
/// Los campos son privados y solo se exponen por getters de lectura. **No** acredita admisión ni
/// validez de bloque: es la materia del `BloqueDag` dev que el llamante debe ensamblar, no un
/// bloque admitido.
#[derive(Clone, PartialEq, Eq, Debug)]
pub struct CuerpoCoinbaseCeroDagDev {
    txs: Vec<Tx>,
    testigos: Vec<Vec<Vec<u8>>>,
    merkle_root: MerkleRoot,
    body_commitment: BodyCommitment,
}

impl CuerpoCoinbaseCeroDagDev {
    /// Construye el cuerpo coinbase cero para el primer hijo de `bootstrap`.
    ///
    /// Deriva la altura como `height(G) + 1` (**comprobada**, sin desbordamiento) y exige
    /// `height(G) = 0`, porque este incremento solo cubre el primer hijo. El
    /// `consensus_branch_id` se copia de `G` **como supuesto dev** para calcular `txid`,
    /// `merkle_root` y `body_commitment`; **no** afirma la rama activa normativa de `C-HDR-02b`.
    ///
    /// La única transacción es una coinbase de versión
    /// [`VERSION_TX`](zx_consensus::validacion::VERSION_TX), sin entradas, con una salida de valor
    /// [`Amount::CERO`] bloqueada a `productor`, `lock_time = 0` y `expiry_height = altura`. Su
    /// lista de testigos es la lista vacía.
    ///
    /// # Errores
    /// [`ErrorCuerpoCoinbaseDev::GenesisConAlturaNoCero`] o
    /// [`ErrorCuerpoCoinbaseDev::AlturaDesbordada`] si la altura de `G` no permite derivar la del
    /// primer hijo; [`ErrorCuerpoCoinbaseDev::CompromisoDelCuerpo`] si `zx-core` rechaza el
    /// compromiso.
    pub fn construir(
        bootstrap: &EstadoBootstrapDagDev,
        productor: ClavePublica,
    ) -> Result<Self, ErrorCuerpoCoinbaseDev> {
        let altura = altura_del_primer_hijo(bootstrap)?;
        // Supuesto dev, no `C-HDR-02b`: la rama del fixture G es la única disponible aquí.
        let rama_dev = bootstrap.bloque_dev().cabecera.consensus_branch_id;

        let coinbase = Tx {
            version: VERSION_TX,
            inputs: Vec::new(),
            outputs: vec![TxOut {
                value: Amount::CERO,
                lock: Lock::PubKey { pubkey: productor },
            }],
            lock_time: 0,
            expiry_height: altura,
        };

        let txs = vec![coinbase];
        let testigos: Vec<Vec<Vec<u8>>> = vec![Vec::new()];

        let txids: Vec<_> = txs.iter().map(|t| txid(t, rama_dev)).collect();
        let merkle = merkle_root(&txids);
        let body = body_commitment(&txs, &testigos, rama_dev)?;

        Ok(Self {
            txs,
            testigos,
            merkle_root: merkle,
            body_commitment: body,
        })
    }

    /// Las transacciones, en orden. La primera es la coinbase.
    #[must_use]
    pub fn txs(&self) -> &[Tx] {
        &self.txs
    }

    /// `testigos[i][j]` es el testigo de la entrada `j` de la transacción `i`.
    #[must_use]
    pub fn testigos(&self) -> &[Vec<Vec<u8>>] {
        &self.testigos
    }

    /// Raíz de Merkle de los `txid` de este cuerpo (`C-BLK-01`, `C-BLK-02`, `C-BLK-03`).
    #[must_use]
    pub fn merkle_root(&self) -> MerkleRoot {
        self.merkle_root
    }

    /// Compromiso completo del cuerpo (efectos y autorización) de este cuerpo.
    #[must_use]
    pub fn body_commitment(&self) -> BodyCommitment {
        self.body_commitment
    }
}

/// Comprueba la forma de la coinbase cero y los compromisos del primer hijo dev `{G}`.
///
/// Es una comprobación **limitada** y deliberadamente estrecha:
///
/// 1. los padres son exactamente `{G}`;
/// 2. la rama es la rama dev copiada de `G` (supuesto dev, no `C-HDR-02b`);
/// 3. la altura es la derivada de `G`;
/// 4. hay exactamente una transacción y una lista de testigos, y está vacía;
/// 5. la coinbase tiene versión `VERSION_TX`, ninguna entrada, una salida de valor cero a la clave
///    `bloque.cabecera.sol.public_key`, `lock_time = 0` y `expiry_height` igual a la altura;
/// 6. [`comprobar_compromisos_cuerpo_dag`](zx_consensus::bloque_dag::comprobar_compromisos_cuerpo_dag)
///    recalcula `merkle_root` y `body_commitment` contra la cabecera.
///
/// Un bloque sin transacciones devuelve [`ErrorCuerpoCoinbaseDev::BloqueSinCoinbase`] (`C-BLK-07`);
/// una segunda transacción o una coinbase con otra forma devuelven un error explícito. **Nunca**
/// se devuelve `Ok` por aceptación: el perfil solo admite la coinbase cero descrita, y esa
/// aceptación **no** cubre subsidio, peso, firmas, timelocks, reloj ni UTXO.
///
/// # Errores
/// La variante de [`ErrorCuerpoCoinbaseDev`] del primer requisito incumplido. Los dos fallos de
/// compromiso se conservan dentro de [`ErrorCuerpoCoinbaseDev::Compromisos`].
pub fn comprobar_cuerpo_coinbase_cero_dev(
    bootstrap: &EstadoBootstrapDagDev,
    bloque: &BloqueDag,
) -> Result<(), ErrorCuerpoCoinbaseDev> {
    let altura = altura_del_primer_hijo(bootstrap)?;
    let genesis = bootstrap.hash_congelado_dev();
    let rama_dev = bootstrap.bloque_dev().cabecera.consensus_branch_id;

    // 1 · Padres exactamente {G}.
    let padres = &bloque.cabecera.padres;
    if padres.count() != 1 || padres.seleccionado() != genesis || !padres.extras().is_empty() {
        return Err(ErrorCuerpoCoinbaseDev::PadresNoSonGenesis);
    }

    // 2 · Rama dev del fixture (supuesto, no la rama activa normativa de C-HDR-02b).
    if bloque.cabecera.consensus_branch_id != rama_dev {
        return Err(ErrorCuerpoCoinbaseDev::RamaDevNoCoincide {
            esperada: rama_dev,
            encontrada: bloque.cabecera.consensus_branch_id,
        });
    }

    // 3 · Altura derivada de G.
    if bloque.cabecera.height != altura {
        return Err(ErrorCuerpoCoinbaseDev::AlturaNoEsPrimerHijo {
            esperada: altura,
            encontrada: bloque.cabecera.height,
        });
    }

    // 4 · Exactamente una transacción (C-BLK-07) y una lista de testigos vacía.
    let Some(coinbase) = bloque.txs().first() else {
        return Err(ErrorCuerpoCoinbaseDev::BloqueSinCoinbase);
    };
    if bloque.txs().len() != 1 {
        return Err(ErrorCuerpoCoinbaseDev::TransaccionesFueraDePerfil {
            encontradas: bloque.txs().len(),
        });
    }
    if bloque.testigos().len() != 1 {
        return Err(ErrorCuerpoCoinbaseDev::NumeroDeTestigosFueraDePerfil {
            encontradas: bloque.testigos().len(),
        });
    }
    let Some(testigo) = bloque.testigos().first() else {
        return Err(ErrorCuerpoCoinbaseDev::NumeroDeTestigosFueraDePerfil { encontradas: 0 });
    };
    if !testigo.is_empty() {
        return Err(ErrorCuerpoCoinbaseDev::TestigoDeCoinbaseNoVacio {
            entradas: testigo.len(),
        });
    }

    // 5 · Forma de la coinbase.
    if coinbase.version != VERSION_TX {
        return Err(ErrorCuerpoCoinbaseDev::VersionDeCoinbaseNoAdmitida {
            version: coinbase.version,
        });
    }
    if !coinbase.inputs.is_empty() {
        return Err(ErrorCuerpoCoinbaseDev::CoinbaseConEntradas {
            entradas: coinbase.inputs.len(),
        });
    }
    if coinbase.outputs.len() != 1 {
        return Err(ErrorCuerpoCoinbaseDev::NumeroDeSalidasFueraDePerfil {
            salidas: coinbase.outputs.len(),
        });
    }
    let Some(salida) = coinbase.outputs.first() else {
        return Err(ErrorCuerpoCoinbaseDev::NumeroDeSalidasFueraDePerfil { salidas: 0 });
    };
    if salida.value != Amount::CERO {
        return Err(ErrorCuerpoCoinbaseDev::SalidaDeCoinbaseNoCero);
    }
    let esperado = Lock::PubKey {
        pubkey: bloque.cabecera.sol.public_key,
    };
    if salida.lock != esperado {
        return Err(ErrorCuerpoCoinbaseDev::SalidaNoPagaAlSellador);
    }
    if coinbase.lock_time != 0 {
        return Err(ErrorCuerpoCoinbaseDev::LockTimeNoCero);
    }
    if coinbase.expiry_height != altura {
        return Err(ErrorCuerpoCoinbaseDev::CoinbaseSinAltura {
            altura,
            expiry: coinbase.expiry_height,
        });
    }

    // 6 · Compromisos contra la cabecera, con la puerta de zx-consensus y su error distinguible.
    zx_consensus::bloque_dag::comprobar_compromisos_cuerpo_dag(
        &bloque.cabecera,
        bloque.txs(),
        bloque.testigos(),
    )?;

    Ok(())
}

/// Altura del primer hijo dev: `height(G) + 1`, comprobada, con `height(G) = 0` exigida.
///
/// El `0` del perfil es una precondición explícita del incremento —solo cubre el primer hijo—, no
/// una cifra de consenso.
fn altura_del_primer_hijo(
    bootstrap: &EstadoBootstrapDagDev,
) -> Result<u32, ErrorCuerpoCoinbaseDev> {
    let genesis = &bootstrap.bloque_dev().cabecera;
    if genesis.height != 0 {
        return Err(ErrorCuerpoCoinbaseDev::GenesisConAlturaNoCero {
            altura: genesis.height,
        });
    }
    genesis
        .height
        .checked_add(1)
        .ok_or(ErrorCuerpoCoinbaseDev::AlturaDesbordada)
}
