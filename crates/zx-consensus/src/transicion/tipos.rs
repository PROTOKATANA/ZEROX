//! Tipos del motor de transición (`ORDEN-W03` §3.2–§3.5, `CONTRATO-v0` §1–§3).
//!
//! Se usan los tipos **reales** de `zx-core`: transacciones v1/v2/v3, `OutPoint`, `ClavePublica`,
//! `Lock`, `Amount`, `BlockHash`. Las únicas adiciones locales son las que la orden fija con nombre
//! propio (`HechosCabecera`, `BloqueTransicion`, `ParametrosTransicion`, `Estado`, `Undo`).

use std::collections::{BTreeMap, BTreeSet};

use primitive_types::U256;
use zx_core::{Amount, BlockHash, ClavePublica, DagBlockHeader, Lock, OutPoint, Tx, TxId};

use crate::transicion::ErrorTransicion;

/// Lo que las verificaciones de cabecera, **que no son de esta orden**, ya decidieron (§3.2).
///
/// El motor no comprueba PoW, PoT, PoAS ni sellos: recibe el veredicto. Lo único que mira es que los
/// indicadores `pow_valido`/`prueba_valida` sean verdaderos y usa el resto de campos para la
/// transición.
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum HechosCabecera {
    /// Bloque génesis: solo su hash. La coinbase constructiva la valida `aplicar_genesis`.
    Genesis {
        /// `block_hash` del génesis.
        hash: BlockHash,
    },
    /// Bloque de la fase PoW de arranque.
    PoW {
        /// `block_hash` del bloque.
        hash: BlockHash,
        /// `block_hash` del padre.
        padre: BlockHash,
        /// Altura declarada en la cabecera.
        altura: u32,
        /// Trabajo aportado por el bloque (`≥ 1`).
        trabajo: U256,
        /// Resultado de la verificación de PoW, ya decidida.
        pow_valido: bool,
    },
    /// Bloque `PoAS_PoT_DAG` (fase PoST).
    PoST {
        /// `block_hash` del bloque.
        hash: BlockHash,
        /// `block_hash` del padre seleccionado.
        padre: BlockHash,
        /// Índice de PoT del bloque (`≥ 1`).
        slot: u64,
        /// Clave del productor (`sol.public_key`).
        productor: ClavePublica,
        /// Peso PoST del bloque (`≥ 1`).
        peso: u128,
        /// Resultado de la verificación de sello/prueba, ya decidida.
        prueba_valida: bool,
        /// `requisito` declarado en la cabecera. Se ignora para decidir (`X-10`).
        requisito_declarado: u64,
    },
}

impl HechosCabecera {
    /// Hash del bloque.
    #[must_use]
    pub const fn hash(&self) -> BlockHash {
        match self {
            Self::Genesis { hash } | Self::PoW { hash, .. } | Self::PoST { hash, .. } => *hash,
        }
    }

    /// Hash del padre, si el bloque tiene uno (el génesis no).
    #[must_use]
    pub const fn padre(&self) -> Option<BlockHash> {
        match self {
            Self::Genesis { .. } => None,
            Self::PoW { padre, .. } | Self::PoST { padre, .. } => Some(*padre),
        }
    }

    /// Altura de un bloque PoW, si la tiene.
    #[must_use]
    pub const fn altura(&self) -> Option<u32> {
        match self {
            Self::PoW { altura, .. } => Some(*altura),
            _ => None,
        }
    }

    /// Slot de un bloque PoST, si lo tiene.
    #[must_use]
    pub const fn slot(&self) -> Option<u64> {
        match self {
            Self::PoST { slot, .. } => Some(*slot),
            _ => None,
        }
    }

    /// Clave del productor de un bloque PoST, si la tiene.
    #[must_use]
    pub const fn productor(&self) -> Option<ClavePublica> {
        match self {
            Self::PoST { productor, .. } => Some(*productor),
            _ => None,
        }
    }
}

/// Un bloque de la transición: sus hechos de cabecera, sus transacciones con testigos y, para PoST,
/// la cabecera real si el llamante la tiene.
///
/// `txs` lleva cada transacción con **su lista de testigos** en el orden del wire.
///
/// El campo `cabecera_post` es una adición **aditiva** a §3.2 (ver `PROGRESO.md`, falta de
/// definición 2): permite llamar a `validar_forma_cabecera_post` (F-03) cuando el llamante construye
/// la cabecera real. Si es `None` el motor no la exige; el arnés siempre la aporta con `height = 0`.
#[derive(Clone, PartialEq, Eq, Debug)]
pub struct BloqueTransicion {
    /// Hechos ya decididos por las verificaciones de cabecera.
    pub hechos: HechosCabecera,
    /// Transacciones con sus testigos.
    pub txs: Vec<(Tx, Vec<Vec<u8>>)>,
    /// Cabecera PoST real, si el llamante la tiene (F-03).
    pub cabecera_post: Option<DagBlockHeader>,
}

impl BloqueTransicion {
    /// Construye un bloque sin cabecera PoST explícita.
    #[must_use]
    pub fn nuevo(hechos: HechosCabecera, txs: Vec<(Tx, Vec<Vec<u8>>)>) -> Self {
        Self {
            hechos,
            txs,
            cabecera_post: None,
        }
    }

    /// Construye un bloque PoST con su cabecera real.
    #[must_use]
    pub fn con_cabecera_post(
        hechos: HechosCabecera,
        txs: Vec<(Tx, Vec<Vec<u8>>)>,
        cabecera_post: DagBlockHeader,
    ) -> Self {
        Self {
            hechos,
            txs,
            cabecera_post: Some(cabecera_post),
        }
    }

    /// Hash del bloque.
    #[must_use]
    pub const fn hash(&self) -> BlockHash {
        self.hechos.hash()
    }

    /// Hash del padre, si lo tiene.
    #[must_use]
    pub const fn padre(&self) -> Option<BlockHash> {
        self.hechos.padre()
    }
}

/// Parámetros simbólicos de la transición (§3.3). **Ningún valor por defecto**: los fija la red dev.
#[derive(Clone, Copy)]
pub struct ParametrosTransicion {
    /// Primera altura PoW que admite depósitos (`H_dep`).
    pub h_dep: u32,
    /// Madurez de la coinbase PoW (`M_cb`).
    pub m_cb: u32,
    /// Madurez de un depósito aplicado en fase PoW (`M_dep`).
    pub m_dep: u32,
    /// Altura mínima del terminal (`H_corte_min`).
    pub h_corte_min: u32,
    /// Trabajo acumulado mínimo del terminal (`W_min`).
    pub w_min: U256,
    /// Garantía activa total mínima para el corte (`S_min`).
    pub s_min: Amount,
    /// Garantía activa mínima por clave para `Φ` (`q`).
    pub q: Amount,
    /// Número mínimo de claves con garantía activa (`K_min`).
    pub k_min: u32,
    /// Madurez residual de coinbases PoW en el sufijo (`M_res_slots`).
    pub m_res_slots: u64,
    /// Madurez de depósitos no maduros en el terminal (`M_dep_slots`).
    pub m_dep_slots: u64,
    /// Madurez del crédito de coinbase PoST (`M_rec_slots`).
    pub m_rec_slots: u64,
    /// Retención tras retiro (`R_slots`).
    pub r_slots: u64,
    /// Profundidad máxima de sustitución para un nodo en línea (`F_slots`; `None` = sin tope).
    pub f_slots: Option<u64>,
    /// `subsidio_pow(altura)`.
    pub subsidio_pow: fn(u32) -> Amount,
    /// `subsidio_post(slot)`.
    pub subsidio_post: fn(u64) -> Amount,
}

/// Fase del estado.
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Fase {
    /// Fase génesis (antes de aplicar `G`).
    Genesis,
    /// Fase PoW de arranque.
    PoW,
    /// Fase PoST, después del corte.
    PoST,
}

/// Punto de aplicación: altura PoW o slot PoST (§3.3).
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Debug)]
pub enum Punto {
    /// Altura de la fase PoW.
    Altura(u32),
    /// Slot de la fase PoST.
    Slot(u64),
}

impl Punto {
    /// La altura, si es un punto de altura.
    #[must_use]
    pub const fn como_altura(self) -> Option<u32> {
        match self {
            Self::Altura(h) => Some(h),
            Self::Slot(_) => None,
        }
    }

    /// El slot, si es un punto de slot.
    #[must_use]
    pub const fn como_slot(self) -> Option<u64> {
        match self {
            Self::Slot(s) => Some(s),
            Self::Altura(_) => None,
        }
    }

    /// Representación `i64` usada por el render canónico del oráculo (`-1` = no aplica).
    #[must_use]
    pub const fn como_i64(self) -> i64 {
        match self {
            Self::Altura(h) => h as i64,
            Self::Slot(s) => s as i64,
        }
    }
}

/// Origen de una salida del UTXO (`CONTRATO-v0` §3.1).
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Origen {
    /// Salida de una coinbase PoW.
    CoinbasePow,
    /// Salida de una transferencia o del cambio de un depósito.
    Tx,
    /// Salida implícita de una liberación de garantía.
    Liberacion,
}

/// Una salida no gastada.
#[derive(Clone, PartialEq, Eq, Debug)]
pub struct EntradaUtxo {
    /// Importe.
    pub valor: Amount,
    /// Condición de gasto (`P2K` o `MultiSig`).
    pub lock: Lock,
    /// Origen.
    pub origen: Origen,
    /// Punto en que se creó (altura PoW o slot PoST).
    pub creada: Punto,
}

/// Un pendiente de garantía con su doble madurez (falta de definición 3 de `PROGRESO.md`).
///
/// Un depósito creado en fase PoW madura por **altura** dentro de la fase PoW y por **slot** una vez
/// cruzado el corte; por eso se conservan ambos, como en el oráculo T01.
#[derive(Clone, PartialEq, Eq, Debug)]
pub struct Pendiente {
    /// Importe pendiente.
    pub importe: Amount,
    /// Altura de madurez, si madura por altura.
    pub madura_en_altura: Option<u32>,
    /// Slot de madurez, si madura por slot.
    pub madura_en_slot: Option<u64>,
}

/// Una retirada viva.
#[derive(Clone, PartialEq, Eq, Debug)]
pub struct EnRetirada {
    /// Importe retirado.
    pub importe: Amount,
    /// Slot desde el que cuenta `R_slots`.
    pub inicio_slot: u64,
}

/// Garantía de una clave (`C-BON-01`).
#[derive(Clone, PartialEq, Eq, Debug)]
pub struct Garantia {
    /// Garantía activa.
    pub activo: Amount,
    /// Pendientes con su madurez.
    pub pendientes: Vec<Pendiente>,
    /// Retiradas vivas.
    pub en_retirada: Vec<EnRetirada>,
    /// Congelado (siempre 0 en v0).
    pub congelado: Amount,
    /// Créditos D-T08 pendientes de madurar.
    pub creditos: Vec<Pendiente>,
}

impl Garantia {
    /// Garantía vacía.
    #[must_use]
    pub const fn nueva() -> Self {
        Self {
            activo: Amount::CERO,
            pendientes: Vec::new(),
            en_retirada: Vec::new(),
            congelado: Amount::CERO,
            creditos: Vec::new(),
        }
    }
}

/// Estado canónico de consenso (§3.4).
#[derive(Clone, PartialEq, Eq, Debug)]
pub struct Estado {
    /// Salidas no gastadas.
    pub utxo: BTreeMap<OutPoint, EntradaUtxo>,
    /// Garantías por clave.
    pub garantias: BTreeMap<ClavePublica, Garantia>,
    /// Suma de subsidios efectivos (puede ser negativa en el término de tarifas).
    pub emitido: i128,
    /// Pérdidas por `C-SLA` (siempre 0 en v0).
    pub quemado: i128,
    /// Fase.
    pub fase: Fase,
    /// Hash del terminal de esta rama, si existe.
    pub terminal: Option<BlockHash>,
    /// Altura PoW alcanzada.
    pub altura: u32,
    /// Trabajo PoW acumulado.
    pub trabajo: U256,
    /// Último slot PoST aplicado.
    pub slot: u64,
    /// Slot de referencia del corte (`s_0`).
    pub s0: u64,
    /// Peso PoST del sufijo.
    pub peso_sufijo: u128,
    /// Altura del terminal, para la madurez residual.
    pub altura_terminal: Option<u32>,
    /// Suma de subsidios nominales, para `I-1b`.
    pub subsidio_acum: i128,
    /// Contador de salidas implícitas (`Liberacion`), para que dos liberaciones idénticas no
    /// colisionen en el mismo `OutPoint` (ver `PROGRESO.md`, falta de definición 9).
    pub prox_salida: u64,
}

/// Escalares del estado, para el undo por delta (`ORDEN-W03` §3.5).
#[derive(Clone, PartialEq, Eq, Debug)]
pub struct Escalares {
    /// `emitido`.
    pub emitido: i128,
    /// `quemado`.
    pub quemado: i128,
    /// `fase`.
    pub fase: Fase,
    /// `terminal`.
    pub terminal: Option<BlockHash>,
    /// `altura`.
    pub altura: u32,
    /// `trabajo`.
    pub trabajo: U256,
    /// `slot`.
    pub slot: u64,
    /// `s0`.
    pub s0: u64,
    /// `peso_sufijo`.
    pub peso_sufijo: u128,
    /// `altura_terminal`.
    pub altura_terminal: Option<u32>,
    /// `subsidio_acum`.
    pub subsidio_acum: i128,
    /// `prox_salida`.
    pub prox_salida: u64,
}

impl From<&Estado> for Escalares {
    fn from(e: &Estado) -> Self {
        Self {
            emitido: e.emitido,
            quemado: e.quemado,
            fase: e.fase,
            terminal: e.terminal,
            altura: e.altura,
            trabajo: e.trabajo,
            slot: e.slot,
            s0: e.s0,
            peso_sufijo: e.peso_sufijo,
            altura_terminal: e.altura_terminal,
            subsidio_acum: e.subsidio_acum,
            prox_salida: e.prox_salida,
        }
    }
}

/// Undo por **delta**: valor previo de cada `OutPoint` y `ClavePublica` tocados y escalares previos.
#[derive(Clone, PartialEq, Eq, Debug)]
pub struct Undo {
    /// Escalares previos.
    pub escalares: Escalares,
    /// `(outpoint, valor previo)` de cada salida tocada, en orden de primer toque.
    pub utxo: Vec<(OutPoint, Option<EntradaUtxo>)>,
    /// `(clave, garantía previa)` de cada garantía tocada, en orden de primer toque.
    pub garantias: Vec<(ClavePublica, Option<Garantia>)>,
    pub(crate) utxo_vistos: BTreeSet<OutPoint>,
    pub(crate) garantia_vistos: BTreeSet<ClavePublica>,
}

/// Marca de posición dentro de un [`Undo`], para revertir una transacción descartada en modo fusión.
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct Marca {
    /// Longitud de la lista de UTXO.
    pub utxo: usize,
    /// Longitud de la lista de garantías.
    pub garantias: usize,
}

/// Una transacción descartada en modo fusión (`ED-4`…`ED-6`) con su motivo.
#[derive(Clone, PartialEq, Eq, Debug)]
pub struct TxDescartada {
    /// Índice de la transacción dentro del bloque.
    pub indice: usize,
    /// `txid` de la transacción descartada.
    pub txid: TxId,
    /// Motivo.
    pub motivo: ErrorTransicion,
}
