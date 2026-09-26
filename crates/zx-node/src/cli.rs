//! CLI del binario `zx-node` (decisión 10).

use std::path::PathBuf;

use clap::{Parser, ValueEnum};
use zx_core::Red;

/// Papel del nodo (decisión 10). En esta orden (sin red), solo `Ambos` puede alcanzar el corte por
/// sí mismo: `Minero`/`Productor` son la forma de la CLI que W06d2 (con red) necesitará para un
/// nodo que solo mina o solo produce; en un proceso aislado, uno de los dos se quedaría esperando
/// bloques que nadie le va a mandar.
#[derive(Clone, Copy, Debug, PartialEq, Eq, ValueEnum)]
pub enum Papel {
    /// Solo mina PoW (no llega a producir PoST por sí solo sin red).
    Minero,
    /// Solo produce PoST (no cruza el corte por sí solo sin red).
    Productor,
    /// Mina PoW y produce PoST: el único papel autosuficiente sin red.
    Ambos,
}

/// Red aceptada por la CLI. Solo `dev` es válida (decisión 2); las otras existen para que el
/// rechazo sea un valor de CLI reconocido y no un `Red` inventado.
#[derive(Clone, Copy, Debug, PartialEq, Eq, ValueEnum)]
pub enum RedCli {
    /// Red de desarrollo: la única que arranca.
    Dev,
    /// Red principal: la CLI la acepta como valor, el nodo se niega a arrancar.
    Mainnet,
    /// Red de pruebas: la CLI la acepta como valor, el nodo se niega a arrancar.
    Testnet,
}

impl From<RedCli> for Red {
    fn from(r: RedCli) -> Self {
        match r {
            RedCli::Dev => Self::Dev,
            RedCli::Mainnet => Self::Mainnet,
            RedCli::Testnet => Self::Testnet,
        }
    }
}

/// `zx-node`: nodo de la red dev de ZEROX, sin red (`ORDEN-W06d1`).
#[derive(Parser, Debug)]
#[command(name = "zx-node", version, about)]
pub struct Cli {
    /// Directorio de datos (almacén y parcelas).
    #[arg(long, value_name = "DIR")]
    pub datos: PathBuf,

    /// Red configurada. Solo `dev` arranca (decisión 2).
    #[arg(long, value_enum, default_value_t = RedCli::Dev)]
    pub red: RedCli,

    /// Semilla de derivación de claves dev.
    #[arg(long, default_value_t = 1)]
    pub semilla: u64,

    /// Índices de claves a derivar, separados por comas (p. ej. `0,1,2`).
    #[arg(long, value_delimiter = ',', default_value = "0,1,2")]
    pub claves: Vec<u32>,

    /// Papel del nodo.
    #[arg(long, value_enum, default_value_t = Papel::Ambos)]
    pub papel: Papel,

    /// `N_dev`: iteraciones AES por slot.
    #[arg(long, default_value_t = 138_873_760)]
    pub n_dev: u64,

    /// `SR_dev`: rango de solución.
    #[arg(long, default_value_t = u64::MAX)]
    pub sr_dev: u64,

    /// Ruta del registro estructurado (JSON, una línea por evento).
    #[arg(long, value_name = "RUTA")]
    pub registro: PathBuf,

    /// Para el nodo tras producir/alcanzar este slot de régimen (para pruebas y mediciones).
    #[arg(long)]
    pub parada_tras_slots: Option<u64>,

    /// Dirección donde escuchar (`ORDEN-W06d2`). Sin esto ni `--red-marcar`, el nodo corre
    /// exactamente como en `ORDEN-W06d1`: sin red.
    #[arg(long, value_name = "MULTIADDR")]
    pub red_escuchar: Option<String>,

    /// Direcciones de pares a marcar al arrancar, repetible.
    #[arg(long = "red-marcar", value_name = "MULTIADDR")]
    pub red_marcar: Vec<String>,
}
