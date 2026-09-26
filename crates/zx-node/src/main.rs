//! Binario `zx-node` (`ORDEN-W06d1`).

use clap::Parser as _;
use zx_node::cli::{Cli, Papel};
use zx_node::nodo::{Config, Nodo};

fn main() {
    let cli = Cli::parse();

    if cli.papel != Papel::Ambos {
        eprintln!(
            "papel {:?}: sin red (ORDEN-W06d1) un proceso aislado no puede solo minar o solo \
             producir y aun así alcanzar el corte; use --papel ambos",
            cli.papel
        );
        std::process::exit(2);
    }
    if cli.claves.is_empty() {
        eprintln!("--claves no puede estar vacío: el nodo necesita al menos una clave propia");
        std::process::exit(2);
    }

    let cfg = Config {
        dir_datos: cli.datos,
        ruta_registro: cli.registro,
        red: cli.red.into(),
        semilla: cli.semilla,
        indices_claves: cli.claves,
        n_dev: cli.n_dev,
        sr_dev: cli.sr_dev,
        parada_tras_slots: cli.parada_tras_slots,
    };

    let resultado = Nodo::arrancar(&cfg).and_then(|mut nodo| nodo.ejecutar());
    if let Err(e) = resultado {
        eprintln!("zx-node: error fatal: {e}");
        std::process::exit(1);
    }
}
