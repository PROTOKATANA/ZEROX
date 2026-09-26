//! RI-1b · Reproducción del coste no acotado de U2 (`pasado_contiene_ident`) en
//! `AlmacenGhostdag::anadir_sintetico`.
//!
//! Hipótesis a comprobar: incluso en una cadena **lineal** (un solo padre por bloque, sin
//! mergeset), insertar un bloque con identidad de billete real (`u2 = true`, el valor por
//! defecto) recorre `anc[padre]` completo -- el pasado estricto entero del padre -- antes de
//! aceptarlo. Eso hace el coste de CADA inserción O(profundidad de la cadena), y el coste total
//! de construir una cadena de N bloques, O(N²).
//!
//! El test mide el tiempo de las últimas 200 inserciones en dos cadenas de profundidad distinta
//! (N1 y N2 = 8×N1) y comprueba que el tiempo por inserción al final de la cadena larga es
//! sustancialmente mayor (no acotado por una constante), lo que es la firma de un coste que
//! crece con el tamaño del DAG, tal como advierte el propio módulo (`ghostdag.rs`, sección
//! "Límites pendientes").
//!
//! Ejecutar en release para que el ruido de compilación de depuración no domine la medida:
//! `cargo test --test ri1b_coste_u2_lineal --release -- --nocapture`

use std::time::Instant;

use zx_dag::ghostdag::{
    Algoritmo, AlmacenGhostdag, BloqueGhostdag, IdentidadGhostdag, Parametros,
};
use zx_dag::bloque_dag::RangoSolucionValidado;
use zx_core::digest::{BlockHash, Digest};

fn id(n: u64) -> BlockHash {
    let mut b = [0u8; 32];
    b[..8].copy_from_slice(&n.to_le_bytes());
    BlockHash::from_digest(Digest::from_bytes(b))
}

/// Construye una cadena lineal de `n` bloques (padre único, sin extras), cada uno con una
/// identidad de billete SINTÉTICA DISTINTA (para que U2 nunca rechace por duplicado), y devuelve
/// el tiempo (ns) de cada una de las últimas `medir` inserciones.
fn tiempos_ultimas_inserciones(n: u64, medir: u64) -> Vec<u128> {
    let genesis = id(0);
    let mut almacen = AlmacenGhostdag::nuevo(
        Parametros::default(),
        Algoritmo::Kernel,
        genesis,
        0,
        RangoSolucionValidado::para_oraculos(0),
        0, // raíz sin billete
    );

    let mut tiempos = Vec::new();
    for i in 1..=n {
        let bloque = BloqueGhostdag {
            id: id(i),
            padres: vec![id(i - 1)],
            slot: i,
            solution_distance: 0,
            rango_espacio: RangoSolucionValidado::para_oraculos(0),
            // Identidad sintética DISTINTA en cada bloque: U2 nunca encuentra duplicado, así que
            // el bloque siempre se acepta, pero el chequeo U2 sigue recorriendo TODO el pasado
            // del padre antes de concluir que no hay duplicado.
            identidad: IdentidadGhostdag::de_fixture(i + 1),
        };
        let t0 = Instant::now();
        almacen
            .anadir_sintetico(bloque)
            .expect("cadena lineal sin billetes repetidos, siempre debe aceptarse");
        let dt = t0.elapsed().as_nanos();
        if i > n - medir {
            tiempos.push(dt);
        }
    }
    tiempos
}

fn media(v: &[u128]) -> f64 {
    v.iter().sum::<u128>() as f64 / v.len() as f64
}

#[test]
fn el_coste_por_insercion_de_u2_crece_con_la_profundidad_de_la_cadena() {
    const MEDIR: u64 = 200;
    let n_corta: u64 = 2_000;
    let n_larga: u64 = 16_000;

    let t_corta = tiempos_ultimas_inserciones(n_corta, MEDIR);
    let t_larga = tiempos_ultimas_inserciones(n_larga, MEDIR);

    let media_corta = media(&t_corta);
    let media_larga = media(&t_larga);
    let razon = media_larga / media_corta;

    eprintln!(
        "media últimas {MEDIR} inserciones @ N={n_corta}: {media_corta:.0} ns/inserción\n\
         media últimas {MEDIR} inserciones @ N={n_larga}: {media_larga:.0} ns/inserción\n\
         razón (N={n_larga}/N={n_corta}) = {razon:.2}× (escala de profundidad = {:.0}×)",
        n_larga as f64 / n_corta as f64
    );

    // Si el coste por inserción fuera O(1) (acotado, independiente del tamaño del DAG), la razón
    // debería rondar 1×. Con U2 recorriendo `anc[padre]` completo, la razón debe acercarse a la
    // razón de profundidades (8×). Umbral conservador: al menos 3× para tolerar ruido de la
    // máquina, muy por encima de lo que un coste O(1) admitiría.
    assert!(
        razon > 3.0,
        "coste por inserción no crece con el tamaño del DAG (razón {razon:.2}×): \
         si esto falla, U2 dejó de ser O(profundidad) y el hallazgo no se reproduce en esta máquina"
    );
}
