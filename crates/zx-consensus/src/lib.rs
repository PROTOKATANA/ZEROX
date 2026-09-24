//! Reglas de consenso de ZEROX: dificultad, timestamps, peso de bloque, emisión y selección de
//! cadena.
//!
//! Todo lo de aquí es **consensus-critical**: una divergencia de un bit entre dos nodos es un split
//! de cadena. Cada elemento cita la regla `C-XXX` del SPEC que implementa.

#![doc = include_str!("../README.md")]

pub mod activacion;
pub mod antidos;
pub mod bloque;
pub mod bloque_dag;
pub mod cabecera_conjunta;
pub mod dificultad;
pub mod emision;
pub mod error;
pub mod firmante;
pub mod fork_choice;
pub mod genesis;
pub mod genesis_dag;
pub mod ghostdag;
pub mod peso;
pub mod poas;
pub mod pot;
pub mod pot_rango;
pub mod testigo;
pub mod timestamps;
pub mod validacion;

pub use activacion::{Rama, Red, comprobar_branch_id, rama_activa};
pub use bloque::{Bloque, BloqueValidado, ContextoBloque, validar_bloque};
pub use bloque_dag::{
    CandidatoSinRango, ContextoDag, ContextoRangoDag, RangoSolucionValidado,
    comprobar_compromisos_cuerpo_dag, comprobar_padres_contextual, comprobar_rango_contextual,
};
pub use cabecera_conjunta::{
    ComprobacionCabecera, EstadoCabeceraConjunta, MotivoCabeceraInvalida, MotivoCabeceraPendiente,
    verificar_cabecera_conjunta,
};
pub use dificultad::{VentanaRetarget, siguiente_target};
pub use emision::{recompensa_base, subsidio};
pub use error::ConsensusError;
pub use firmante::{Firmante, FirmanteError, IdentidadTicket, Registro, RegistroError, Resultado};
pub use fork_choice::{ClaveVentana, MAX_REORG_LENGTH, Preferencia, Tip, preferir};
pub use genesis::{GENESIS_MAINNET, GENESIS_TESTNET, ParametrosGenesis, construir};
pub use ghostdag::{
    Algoritmo, AlmacenGhostdag, BloqueGhostdag, Color, IdentidadGhostdag, Idx, ModoMerge, ModoSp,
    Parametros, Rank, sumar_blue_work,
};
pub use peso::{PesoValidado, limite, mediana_efectiva};
pub use poas::{ErrorPoas, verificar_solucion_poas};
pub use pot::{
    ALEATORIEDAD_BYTES, ENTROPIA_BYTES, ErrorContextoPot, aleatoriedad_de_salida,
    checkpoints_a_primitiva, checkpoints_a_wire, proyectar_iteraciones, reto_desde_salida,
    semilla_siguiente, verificar_slot_aes,
};
pub use pot_rango::{
    BloqueDelPasado, CachePotVerificada, ClaveCachePot, EstadoPot, FLUJO_BYTES, InstantaneaPot,
    InyeccionPot, InyeccionesPot, MotivoPotInvalido, MotivoPotPendiente, PresupuestoPot,
    TokenRangoPot, verificar_rango_pot, verificar_rango_pot_fase_aes,
    verificar_rango_pot_fase_previa,
};
pub use testigo::{ContextoGasto, satisface};
pub use validacion::{ConjuntoUtxo, EntradaUtxo, peso_tx, validar_tx};
