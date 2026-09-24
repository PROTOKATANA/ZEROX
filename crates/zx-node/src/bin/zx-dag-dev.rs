//! `zx-dag-dev`: ejecuta el bootstrap aislado del génesis DAG de **desarrollo**.
//!
//! # Alcance
//!
//! Llama **solo** a [`zx_node::bootstrap_dag_dev::iniciar_bootstrap_dag_dev`]. No levanta
//! sockets, no abre RocksDB, no acepta `--red`, `--peer` ni `--datos`: cualquier argumento se
//! rechaza, de modo que no puede confundirse con `zx-node` ni compartir identidad con testnet.
//! En éxito imprime el hash dev y el aviso del alcance acotado; en fallo sale con código distinto
//! de cero.
//!
//! **No cierra C3.** El bootstrap no admite PoST, no verifica PoT/PoAS/sello y no inserta la
//! coinbase del génesis en ningún UTXO; solo comprueba estructura y hash contra el literal
//! congelado y expone el ancla confiada del slot 0.

use std::process::ExitCode;

use clap::Parser;

use zx_node::bootstrap_dag_dev::iniciar_bootstrap_dag_dev;

/// Argumentos del binario dev. Está **vacío a propósito**: no hay red, peers ni datos que aceptar,
/// y clap rechaza cualquier argumento desconocido antes de ejecutar el bootstrap.
#[derive(Parser, Debug)]
#[command(
    name = "zx-dag-dev",
    version,
    about = "Bootstrap local del génesis DAG de desarrollo (sin red)"
)]
struct Args {}

fn main() -> ExitCode {
    // Parseo sin parámetros: un `--red`, `--peer` o `--datos` se rechaza aquí, con salida distinta
    // de cero, antes de tocar nada.
    let _args = Args::parse();

    match iniciar_bootstrap_dag_dev() {
        Ok(estado) => {
            println!("bootstrap DAG dev: estructura y hash congelado, OK");
            println!("hash dev: {}", hex(estado.hash_congelado_dev().as_bytes()));
            println!("aviso: solo bootstrap local; sin red, persistencia ni admisión PoST");
            ExitCode::SUCCESS
        }
        Err(e) => {
            eprintln!("fallo del bootstrap DAG dev: {e}");
            ExitCode::FAILURE
        }
    }
}

/// Hexadecimal en minúsculas, para la salida del hash.
fn hex(bytes: &[u8]) -> String {
    bytes.iter().map(|b| format!("{b:02x}")).collect()
}
