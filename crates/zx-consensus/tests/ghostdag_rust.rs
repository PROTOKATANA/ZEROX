//! Pruebas Rust de GHOSTDAG y `rank` (encargo 03 §5).
//!
//! Cubren: referencia vs kernel sobre DAGs generados, determinismo con ≥ 1000 órdenes de
//! llegada, desbordamiento de `blue_work`, límites de R-FIN-12, ancestría, totalidad de
//! `rank`, la decisión C (hermanos y copias) y `ContextoDag` real contra
//! `comprobar_padres_contextual`.

#![expect(clippy::unwrap_used, reason = "los tests fallan con panic por diseño")]
#![expect(clippy::expect_used, reason = "los tests fallan con panic por diseño")]
#![expect(clippy::panic, reason = "el test falla ruidosamente")]
#![expect(
    clippy::indexing_slicing,
    reason = "índices sobre vectores construidos en el propio test"
)]

use std::collections::HashMap;

use primitive_types::U256;
use zx_consensus::ConsensusError;
use zx_consensus::bloque_dag::comprobar_padres_contextual;
use zx_consensus::ghostdag::{
    Algoritmo, AlmacenGhostdag, BloqueGhostdag, Color, Idx, ModoMerge, ModoSp, Parametros, Rank,
    hash_de_id_textual, peso, sumar_blue_work,
};
use zx_core::digest::{BlockHash, BodyCommitment, Digest, MerkleRoot};
use zx_core::{DagBlockHeader, PadresDag, SolucionPoas};

// ─────────────────────────────────────────────────────────────────────────────
// Generador determinista de DAGs (semilla fija en el código).
// ─────────────────────────────────────────────────────────────────────────────

struct Azar(u64);

impl Azar {
    const fn nuevo(semilla: u64) -> Self {
        Self(semilla)
    }

    fn siguiente(&mut self) -> u64 {
        self.0 = self.0.wrapping_add(0x9E37_79B9_7F4A_7C15);
        let mut z = self.0;
        z = (z ^ (z >> 30)).wrapping_mul(0xBF58_476D_1CE4_E5B9);
        z = (z ^ (z >> 27)).wrapping_mul(0x94D0_49BB_1331_11EB);
        z ^ (z >> 31)
    }

    fn rango(&mut self, lo: u64, hi: u64) -> u64 {
        if hi <= lo {
            return lo;
        }
        lo + self.siguiente() % (hi - lo + 1)
    }
}

#[derive(Clone)]
struct Nodo {
    id: BlockHash,
    padres: Vec<usize>,
    slot: u64,
    sd: u64,
    sr: u64,
    ident: u64,
}

fn generar(n: usize, ventana: usize, semilla: u64) -> Vec<Nodo> {
    let mut rng = Azar::nuevo(semilla);
    let mut nodos = vec![Nodo {
        id: hash_de_id_textual("G"),
        padres: Vec::new(),
        slot: 0,
        sd: 0,
        sr: 0,
        ident: 0,
    }];
    for i in 1..n {
        let mut ident = 0u64;
        let mut padres_fijados: Option<Vec<usize>> = None;
        if i % 8 == 0 {
            ident = i as u64;
        } else if i % 8 == 1 && nodos[i - 1].ident != 0 {
            ident = nodos[i - 1].ident;
            padres_fijados = Some(nodos[i - 1].padres.clone());
        }
        let tiene_fijados = padres_fijados.is_some();
        let padres = if let Some(p) = padres_fijados.clone() {
            p
        } else {
            // 0-based: los candidatos van de `lo` a `i-1` (el génesis es 0).
            let lo = i.saturating_sub(ventana);
            let npadres = (i - lo).min(1 + rng.rango(0, 3) as usize);
            let mut elegidos: Vec<usize> = Vec::new();
            while elegidos.len() < npadres {
                let p = lo + rng.rango(0, (i - lo - 1) as u64) as usize;
                if !elegidos.contains(&p) {
                    elegidos.push(p);
                }
            }
            elegidos
        };
        let max_slot = padres.iter().map(|p| nodos[*p].slot).max().unwrap_or(0);
        let slot = max_slot + rng.rango(0, 2);
        let sr = match rng.rango(0, 4) {
            0 => 0,
            1 => 1,
            2 => u64::MAX - 1,
            3 => u64::MAX,
            _ => rng.rango(0, i64::MAX as u64),
        };
        let sd = if tiene_fijados && i >= 1 {
            nodos[i - 1].sd
        } else {
            rng.rango(0, 1 << 20)
        };
        nodos.push(Nodo {
            id: hash_de_id_textual(&format!("B{i}")),
            padres,
            slot,
            sd,
            sr,
            ident,
        });
    }
    nodos
}

fn orden_topologico(rng: &mut Azar, nodos: &[Nodo]) -> Vec<usize> {
    let n = nodos.len();
    let mut entregados = vec![false; n];
    let mut orden = Vec::with_capacity(n);
    entregados[0] = true;
    orden.push(0);
    while orden.len() < n {
        let disponibles: Vec<usize> = (1..n)
            .filter(|i| !entregados[*i] && nodos[*i].padres.iter().all(|p| entregados[*p]))
            .collect();
        if disponibles.is_empty() {
            panic!("el DAG no es acíclico");
        }
        let e = disponibles[rng.rango(0, (disponibles.len() - 1) as u64) as usize];
        entregados[e] = true;
        orden.push(e);
    }
    orden
}

fn entregar(
    nodos: &[Nodo],
    orden: &[usize],
    params: Parametros,
    algoritmo: Algoritmo,
) -> AlmacenGhostdag {
    let mut almacen = AlmacenGhostdag::nuevo(
        params,
        algoritmo,
        nodos[0].id,
        nodos[0].slot,
        nodos[0].sr,
        nodos[0].ident,
    );
    let mut mapa: HashMap<usize, Idx> = HashMap::new();
    mapa.insert(0, 0);
    for spec_idx in orden.iter().skip(1) {
        let nodo = &nodos[*spec_idx];
        let padres = nodo.padres.iter().map(|p| nodos[*p].id).collect();
        let idx = almacen
            .anadir(BloqueGhostdag {
                id: nodo.id,
                padres,
                slot: nodo.slot,
                solution_distance: nodo.sd,
                rango_espacio: nodo.sr,
                identidad: nodo.ident,
            })
            .unwrap_or_else(|e| panic!("DAG válido rechazado: {e}"));
        mapa.insert(*spec_idx, idx);
    }
    almacen
}

#[derive(Clone, Debug, PartialEq, Eq)]
struct Proy {
    sp: Option<usize>,
    ms: Vec<usize>,
    blues: Vec<usize>,
    rojos: Vec<usize>,
    colores: Vec<(usize, u8)>,
    score: u64,
    bw: U256,
}

fn proyeccion(almacen: &AlmacenGhostdag, nodos: &[Nodo]) -> Vec<Proy> {
    let mut hash_a_spec: HashMap<BlockHash, usize> = HashMap::new();
    for (i, n) in nodos.iter().enumerate() {
        hash_a_spec.insert(n.id, i);
    }
    let mut idx_a_spec: HashMap<Idx, usize> = HashMap::new();
    for idx in 0..almacen.len() as Idx {
        let h = almacen.id(idx).unwrap();
        idx_a_spec.insert(idx, hash_a_spec[&h]);
    }
    // Indexado por índice de nodo (spec), no por índice del almacén: dos órdenes de llegada
    // distintos dan índices de almacén distintos para el mismo bloque.
    let mut salida: Vec<Option<Proy>> = vec![None; nodos.len()];
    for idx in 0..almacen.len() as Idx {
        let gd = almacen.datos(idx).unwrap();
        let conv = |v: &[Idx]| v.iter().map(|x| idx_a_spec[x]).collect::<Vec<_>>();
        let proy = Proy {
            sp: gd.sp.map(|s| idx_a_spec[&s]),
            ms: conv(&gd.orden_mergeset),
            blues: conv(&gd.blues),
            rojos: conv(&gd.rojos),
            colores: gd
                .colores
                .iter()
                .map(|(c, color)| (idx_a_spec[c], if *color == Color::RojoU3 { 2 } else { 1 }))
                .collect(),
            score: gd.blue_score,
            bw: gd.blue_work,
        };
        salida[idx_a_spec[&idx]] = Some(proy);
    }
    salida
        .into_iter()
        .map(|x| x.expect("todo nodo fue entregado"))
        .collect()
}

fn params_regla_c() -> Parametros {
    Parametros {
        sp: ModoSp::Zerox,
        merge: ModoMerge::Terna,
        ..Parametros::default()
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1 · Referencia vs kernel
// ─────────────────────────────────────────────────────────────────────────────

#[test]
fn referencia_y_kernel_coinciden_en_dags_generados() {
    let mut choques = 0usize;
    for semilla in 0..60u64 {
        let n = 4 + (semilla as usize * 7) % 80;
        let ventana = 1 + (semilla as usize % 8) * 4;
        let nodos = generar(n, ventana, 0xD1F_F000 + semilla);
        let a = entregar(
            &nodos,
            &(0..n).collect::<Vec<_>>(),
            params_regla_c(),
            Algoritmo::Referencia,
        );
        let b = entregar(
            &nodos,
            &(0..n).collect::<Vec<_>>(),
            params_regla_c(),
            Algoritmo::Kernel,
        );
        if proyeccion(&a, &nodos) != proyeccion(&b, &nodos) {
            choques += 1;
        }
    }
    assert_eq!(choques, 0, "referencia y kernel divergen en {choques} DAGs");
}

// ─────────────────────────────────────────────────────────────────────────────
// 2 · Determinismo (C-GD-09): ≥ 1000 órdenes de llegada
// ─────────────────────────────────────────────────────────────────────────────

#[test]
fn determinismo_con_mil_ordenes_de_llegada() {
    for familia in 0..3u64 {
        let n = 120;
        let ventana = if familia == 0 { 6 } else { 30 };
        let nodos = generar(n, ventana, 0x6D60 + familia);
        let mut rng = Azar::nuevo(0xA11CE + familia);
        let base = proyeccion(
            &entregar(
                &nodos,
                &(0..n).collect::<Vec<_>>(),
                params_regla_c(),
                Algoritmo::Kernel,
            ),
            &nodos,
        );
        for ronda in 0..1000 {
            let orden = orden_topologico(&mut rng, &nodos);
            let est = entregar(&nodos, &orden, params_regla_c(), Algoritmo::Kernel);
            assert_eq!(
                proyeccion(&est, &nodos),
                base,
                "determinismo roto en familia {familia}, ronda {ronda}"
            );
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3 · Desbordamiento de blue_work (C-GD-02)
// ─────────────────────────────────────────────────────────────────────────────

#[test]
fn desbordamiento_de_blue_work_es_error_explicito() {
    assert_eq!(
        sumar_blue_work(U256::MAX, U256::one()),
        Err(ConsensusError::BlueWorkDesbordado)
    );
    assert_eq!(sumar_blue_work(U256::MAX, U256::zero()), Ok(U256::MAX));
}

#[test]
fn peso_fronteras() {
    // SR=0 → 2^128; SR=2^64−1 → 2^64.
    assert_eq!(peso(0), U256::one() << 128usize);
    assert_eq!(peso(u64::MAX), U256::one() << 64usize);
    for sr in [0u64, 1, 2, 1 << 32, u64::MAX - 1, u64::MAX] {
        assert!(peso(sr) >= (U256::one() << 64usize));
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// 4 · Límites de R-FIN-12 (C-GD-04)
// ─────────────────────────────────────────────────────────────────────────────

#[test]
fn quince_padres_se_aceptan_y_dieciseis_se_rechazan() {
    let mut almacen = AlmacenGhostdag::nuevo(
        params_regla_c(),
        Algoritmo::Kernel,
        hash_de_id_textual("G"),
        0,
        0,
        0,
    );
    for i in 1..=16 {
        almacen
            .anadir(BloqueGhostdag {
                id: hash_de_id_textual(&format!("P{i}")),
                padres: vec![hash_de_id_textual("G")],
                slot: 1,
                solution_distance: 1,
                rango_espacio: i,
                identidad: 0,
            })
            .unwrap();
    }
    let quince: Vec<BlockHash> = (1..=15)
        .map(|i| hash_de_id_textual(&format!("P{i}")))
        .collect();
    let dieciseis: Vec<BlockHash> = (1..=16)
        .map(|i| hash_de_id_textual(&format!("P{i}")))
        .collect();
    assert!(
        almacen
            .anadir(BloqueGhostdag {
                id: hash_de_id_textual("A"),
                padres: quince,
                slot: 1,
                solution_distance: 0,
                rango_espacio: 0,
                identidad: 0,
            })
            .is_ok()
    );
    assert_eq!(
        almacen.anadir(BloqueGhostdag {
            id: hash_de_id_textual("B"),
            padres: dieciseis,
            slot: 1,
            solution_distance: 0,
            rango_espacio: 0,
            identidad: 0,
        }),
        Err(ConsensusError::DemasiadosPadresDag {
            declarados: 16,
            maximo: 15,
        })
    );
}

/// Brazo con dos cadenas desde el génesis: la segunda aporta el mergeset del bloque de unión.
fn construir_brazo(largo_p: usize, largo_q: usize) -> AlmacenGhostdag {
    let mut almacen = AlmacenGhostdag::nuevo(
        params_regla_c(),
        Algoritmo::Kernel,
        hash_de_id_textual("G"),
        0,
        0,
        0,
    );
    let mut anterior_p = hash_de_id_textual("G");
    for i in 1..=largo_p {
        let id = hash_de_id_textual(&format!("P{i}"));
        almacen
            .anadir(BloqueGhostdag {
                id,
                padres: vec![anterior_p],
                slot: i as u64,
                solution_distance: 0,
                rango_espacio: 100,
                identidad: 0,
            })
            .unwrap();
        anterior_p = id;
    }
    let mut anterior_q = hash_de_id_textual("G");
    for i in 1..=largo_q {
        let id = hash_de_id_textual(&format!("Q{i}"));
        almacen
            .anadir(BloqueGhostdag {
                id,
                padres: vec![anterior_q],
                slot: i as u64,
                solution_distance: 0,
                rango_espacio: 100,
                identidad: 0,
            })
            .unwrap();
        anterior_q = id;
    }
    almacen
}

#[test]
fn bordes_exactos_de_mergeset_180_y_181() {
    // 179 bloques en la cadena Q ⇒ |mergeset| = 179 ⇒ +1 = 180: se acepta.
    let mut acepta = construir_brazo(180, 179);
    let ok = acepta.anadir(BloqueGhostdag {
        id: hash_de_id_textual("U"),
        padres: vec![hash_de_id_textual("P180"), hash_de_id_textual("Q179")],
        slot: 180,
        solution_distance: 0,
        rango_espacio: 100,
        identidad: 0,
    });
    assert!(ok.is_ok(), "180 debe aceptarse: {ok:?}");

    // 180 bloques en Q ⇒ |mergeset| = 180 ⇒ +1 = 181: se rechaza.
    let mut rechaza = construir_brazo(180, 180);
    assert_eq!(
        rechaza.anadir(BloqueGhostdag {
            id: hash_de_id_textual("V"),
            padres: vec![hash_de_id_textual("P180"), hash_de_id_textual("Q180")],
            slot: 180,
            solution_distance: 0,
            rango_espacio: 100,
            identidad: 0,
        }),
        Err(ConsensusError::MergesetExcedeLimite {
            tamano: 181,
            maximo: 180,
        })
    );
}

// ─────────────────────────────────────────────────────────────────────────────
// 5 · Ancestralidad y totalidad de rank (C-ORD-01)
// ─────────────────────────────────────────────────────────────────────────────

#[test]
fn todo_padre_tiene_menor_rank_que_su_hijo() {
    for semilla in 0..40u64 {
        let n = 20 + (semilla as usize * 3) % 60;
        let nodos = generar(n, 6, 0xA5CE + semilla);
        let almacen = entregar(
            &nodos,
            &(0..n).collect::<Vec<_>>(),
            params_regla_c(),
            Algoritmo::Kernel,
        );
        for idx in 0..almacen.len() as Idx {
            let r = almacen.rank(idx).unwrap();
            for p in almacen.padres_de(idx).unwrap() {
                assert!(almacen.rank(*p).unwrap() < r, "padre con rank >= hijo");
            }
        }
    }
}

#[test]
fn rank_es_total_sobre_el_corpus() {
    for semilla in 0..20u64 {
        let n = 40 + (semilla as usize * 5) % 80;
        let nodos = generar(n, 30, 0x70A1 + semilla);
        let almacen = entregar(
            &nodos,
            &(0..n).collect::<Vec<_>>(),
            params_regla_c(),
            Algoritmo::Kernel,
        );
        let mut ranques: Vec<Rank> = (0..almacen.len() as Idx)
            .map(|idx| almacen.rank(idx).unwrap())
            .collect();
        ranques.sort();
        ranques.dedup();
        assert_eq!(
            ranques.len(),
            almacen.len(),
            "rank no es total en el DAG de semilla {semilla}: hay tuplas repetidas"
        );
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// 6 · Decisión C: hermanos y copias de billete (C-GD-03, C-ORD-02)
// ─────────────────────────────────────────────────────────────────────────────

fn almacen_hermanos() -> (AlmacenGhostdag, BlockHash) {
    let mut almacen = AlmacenGhostdag::nuevo(
        params_regla_c(),
        Algoritmo::Kernel,
        hash_de_id_textual("G"),
        0,
        0,
        0,
    );
    // Hermana 1: menor id, mismo bw y sd.
    almacen
        .anadir(BloqueGhostdag {
            id: hash_de_id_textual("A1"),
            padres: vec![hash_de_id_textual("G")],
            slot: 1,
            solution_distance: 7,
            rango_espacio: 5,
            identidad: 0,
        })
        .unwrap();
    // Hermana 2: mismo bw y sd, id mayor.
    almacen
        .anadir(BloqueGhostdag {
            id: hash_de_id_textual("A2"),
            padres: vec![hash_de_id_textual("G")],
            slot: 1,
            solution_distance: 7,
            rango_espacio: 5,
            identidad: 0,
        })
        .unwrap();
    (almacen, hash_de_id_textual("G"))
}

#[test]
fn sp_empatado_en_bw_y_sd_elige_el_menor_id() {
    let (mut almacen, g) = almacen_hermanos();
    let c = almacen
        .anadir(BloqueGhostdag {
            id: hash_de_id_textual("C"),
            padres: vec![hash_de_id_textual("A2"), hash_de_id_textual("A1")],
            slot: 1,
            solution_distance: 0,
            rango_espacio: 5,
            identidad: 0,
        })
        .unwrap();
    let sp = almacen.datos(c).unwrap().sp.unwrap();
    assert_eq!(almacen.id(sp).unwrap(), hash_de_id_textual("A1"));
    let _ = g;
}

#[test]
fn sp_empatado_en_bw_elige_el_menor_sd() {
    let mut almacen = AlmacenGhostdag::nuevo(
        params_regla_c(),
        Algoritmo::Kernel,
        hash_de_id_textual("G"),
        0,
        0,
        0,
    );
    for (id, sd) in [("A1", 9u64), ("A2", 3u64)] {
        almacen
            .anadir(BloqueGhostdag {
                id: hash_de_id_textual(id),
                padres: vec![hash_de_id_textual("G")],
                slot: 1,
                solution_distance: sd,
                rango_espacio: 5,
                identidad: 0,
            })
            .unwrap();
    }
    let c = almacen
        .anadir(BloqueGhostdag {
            id: hash_de_id_textual("C"),
            padres: vec![hash_de_id_textual("A1"), hash_de_id_textual("A2")],
            slot: 1,
            solution_distance: 0,
            rango_espacio: 5,
            identidad: 0,
        })
        .unwrap();
    let sp = almacen.datos(c).unwrap().sp.unwrap();
    assert_eq!(almacen.id(sp).unwrap(), hash_de_id_textual("A2"));
}

#[test]
fn sp_elige_el_mayor_blue_work() {
    let mut almacen = AlmacenGhostdag::nuevo(
        params_regla_c(),
        Algoritmo::Kernel,
        hash_de_id_textual("G"),
        0,
        0,
        0,
    );
    almacen
        .anadir(BloqueGhostdag {
            id: hash_de_id_textual("A"),
            padres: vec![hash_de_id_textual("G")],
            slot: 1,
            solution_distance: 0,
            rango_espacio: 5,
            identidad: 0,
        })
        .unwrap();
    almacen
        .anadir(BloqueGhostdag {
            id: hash_de_id_textual("B"),
            padres: vec![hash_de_id_textual("A")],
            slot: 1,
            solution_distance: 0,
            rango_espacio: 5,
            identidad: 0,
        })
        .unwrap();
    let c = almacen
        .anadir(BloqueGhostdag {
            id: hash_de_id_textual("C"),
            padres: vec![hash_de_id_textual("A"), hash_de_id_textual("B")],
            slot: 1,
            solution_distance: 0,
            rango_espacio: 5,
            identidad: 0,
        })
        .unwrap();
    let sp = almacen.datos(c).unwrap().sp.unwrap();
    assert_eq!(almacen.id(sp).unwrap(), hash_de_id_textual("B"));
}

#[test]
fn copia_de_billete_direccion_coherente_entre_padres_y_mergeset() {
    let params = Parametros {
        k: 30,
        ..params_regla_c()
    };
    let mut almacen =
        AlmacenGhostdag::nuevo(params, Algoritmo::Kernel, hash_de_id_textual("G"), 0, 0, 0);
    // A (sin billete) y dos copias s1,s2 del billete 7. A es el sp por tener menor sd.
    almacen
        .anadir(BloqueGhostdag {
            id: hash_de_id_textual("A"),
            padres: vec![hash_de_id_textual("G")],
            slot: 1,
            solution_distance: 0,
            rango_espacio: 5,
            identidad: 0,
        })
        .unwrap();
    for id in ["S1", "S2"] {
        almacen
            .anadir(BloqueGhostdag {
                id: hash_de_id_textual(id),
                padres: vec![hash_de_id_textual("G")],
                slot: 1,
                solution_distance: 5,
                rango_espacio: 5,
                identidad: 7,
            })
            .unwrap();
    }
    // C con A como sp (menor sd) y S1,S2 en el mergeset.
    let c = almacen
        .anadir(BloqueGhostdag {
            id: hash_de_id_textual("C"),
            padres: vec![
                hash_de_id_textual("A"),
                hash_de_id_textual("S1"),
                hash_de_id_textual("S2"),
            ],
            slot: 1,
            solution_distance: 0,
            rango_espacio: 5,
            identidad: 0,
        })
        .unwrap();
    // Los dos hermanos van en orden de rank (S1 antes que S2) y el primero queda azul, el
    // segundo rojo_U3; la copia seleccionada es S1, la misma dirección que elegiría el sp.
    let ms: Vec<BlockHash> = almacen
        .datos(c)
        .unwrap()
        .orden_mergeset
        .iter()
        .map(|i| almacen.id(*i).unwrap())
        .collect();
    assert_eq!(ms, vec![hash_de_id_textual("S1"), hash_de_id_textual("S2")]);
    let idx_s1 = almacen
        .datos(c)
        .unwrap()
        .orden_mergeset
        .first()
        .copied()
        .unwrap();
    let idx_s2 = *almacen.datos(c).unwrap().orden_mergeset.get(1).unwrap();
    assert_eq!(almacen.color_en(c, idx_s1), Some(Color::Azul));
    assert_eq!(almacen.color_en(c, idx_s2), Some(Color::RojoU3));
    let ganadora = almacen
        .seleccionar_copia(&[(idx_s1, Color::Azul), (idx_s2, Color::RojoU3)])
        .unwrap();
    assert_eq!(ganadora, idx_s1);
    // Y si las dos fuesen rojo_k (sin copia azul), gana la de menor rank: S1.
    let ganadora_sin_azul = almacen
        .seleccionar_copia(&[(idx_s2, Color::RojoK), (idx_s1, Color::RojoK)])
        .unwrap();
    assert_eq!(ganadora_sin_azul, idx_s1);
}

// ─────────────────────────────────────────────────────────────────────────────
// 7 · U2 frente a U3″ (C-GD-07)
// ─────────────────────────────────────────────────────────────────────────────

#[test]
fn u2_invalida_y_u3_colorea() {
    let mut almacen = AlmacenGhostdag::nuevo(
        params_regla_c(),
        Algoritmo::Kernel,
        hash_de_id_textual("G"),
        0,
        0,
        0,
    );
    // A lleva el billete 7.
    almacen
        .anadir(BloqueGhostdag {
            id: hash_de_id_textual("A"),
            padres: vec![hash_de_id_textual("G")],
            slot: 1,
            solution_distance: 5,
            rango_espacio: 5,
            identidad: 7,
        })
        .unwrap();
    // S es copia (mismo billete) pero hermana, no descendiente de A: U2 NO la invalida.
    let s = almacen
        .anadir(BloqueGhostdag {
            id: hash_de_id_textual("S"),
            padres: vec![hash_de_id_textual("G")],
            slot: 1,
            solution_distance: 5,
            rango_espacio: 5,
            identidad: 7,
        })
        .unwrap();
    // U2 NO la rechaza: es hermana de A, no descendiente. El bloque existe.
    assert!(almacen.datos(s).is_some());

    // D es descendiente de A: el billete 7 ya está en el pasado estricto de su padre ⇒ U2.
    assert_eq!(
        almacen.anadir(BloqueGhostdag {
            id: hash_de_id_textual("D"),
            padres: vec![hash_de_id_textual("A")],
            slot: 1,
            solution_distance: 0,
            rango_espacio: 5,
            identidad: 7,
        }),
        Err(ConsensusError::BilleteDuplicadoU2 { identidad: 7 })
    );

    // C fusiona A (sp) y S: S no se evalúa contra el k-cluster, queda rojo_U3.
    let c = almacen
        .anadir(BloqueGhostdag {
            id: hash_de_id_textual("C"),
            padres: vec![hash_de_id_textual("A"), hash_de_id_textual("S")],
            slot: 1,
            solution_distance: 0,
            rango_espacio: 5,
            identidad: 0,
        })
        .unwrap();
    let idx_s = almacen.datos(c).unwrap().rojos.first().copied().unwrap();
    assert_eq!(almacen.color_en(c, idx_s), Some(Color::RojoU3));
}

// ─────────────────────────────────────────────────────────────────────────────
// 8 · ContextoDag real contra comprobar_padres_contextual (H-04)
// ─────────────────────────────────────────────────────────────────────────────

const CBID: u32 = 0xc478_80ea;

fn cabecera(padres: PadresDag, n: u8) -> DagBlockHeader {
    DagBlockHeader {
        consensus_branch_id: CBID,
        merkle_root: MerkleRoot::from_digest(Digest::from_bytes([n; 32])),
        timestamp: 1_788_480_000 + u64::from(n),
        height: u32::from(n),
        slot: u64::from(n),
        pot_output: [n; 16],
        rango_solucion: 42,
        sol: SolucionPoas::default(),
        body_commitment: BodyCommitment::from_digest(Digest::from_bytes([0; 32])),
        padres,
        sello: [0u8; 64],
    }
}

struct Escenario {
    almacen: AlmacenGhostdag,
    h_genesis: DagBlockHeader,
    h_a: DagBlockHeader,
    h_b: DagBlockHeader,
    h_c: DagBlockHeader,
}

fn escenario_dag() -> Escenario {
    let h_genesis = cabecera(PadresDag::genesis(), 0);
    let mut almacen = AlmacenGhostdag::nuevo(
        params_regla_c(),
        Algoritmo::Kernel,
        h_genesis.block_hash(),
        0,
        0,
        0,
    );
    // Génesis → A → B (B desciende de A).
    let h_a = cabecera(PadresDag::nuevo(h_genesis.block_hash(), &[]).unwrap(), 1);
    almacen
        .anadir(BloqueGhostdag {
            id: h_a.block_hash(),
            padres: vec![h_genesis.block_hash()],
            slot: 1,
            solution_distance: 1,
            rango_espacio: 5,
            identidad: 0,
        })
        .unwrap();
    let h_b = cabecera(PadresDag::nuevo(h_a.block_hash(), &[]).unwrap(), 2);
    almacen
        .anadir(BloqueGhostdag {
            id: h_b.block_hash(),
            padres: vec![h_a.block_hash()],
            slot: 2,
            solution_distance: 1,
            rango_espacio: 5,
            identidad: 0,
        })
        .unwrap();
    // C es hermana de A (anticadena con A).
    let h_c = cabecera(PadresDag::nuevo(h_genesis.block_hash(), &[]).unwrap(), 3);
    almacen
        .anadir(BloqueGhostdag {
            id: h_c.block_hash(),
            padres: vec![h_genesis.block_hash()],
            slot: 1,
            solution_distance: 2,
            rango_espacio: 5,
            identidad: 0,
        })
        .unwrap();
    Escenario {
        almacen,
        h_genesis,
        h_a,
        h_b,
        h_c,
    }
}

#[test]
fn el_genesis_sin_padres_pasa_contra_el_almacen_real() {
    let esc = escenario_dag();
    assert!(comprobar_padres_contextual(&esc.h_genesis, &esc.almacen).is_ok());
}

#[test]
fn un_padre_no_validado_se_rechaza_contra_el_almacen_real() {
    let esc = escenario_dag();
    let impostor: BlockHash = cabecera(PadresDag::genesis(), 0xEE).block_hash();
    let h = cabecera(
        PadresDag::nuevo(esc.h_a.block_hash(), &[impostor]).unwrap(),
        9,
    );
    assert!(matches!(
        comprobar_padres_contextual(&h, &esc.almacen),
        Err(ConsensusError::PadreNoValidado { .. })
    ));
}

#[test]
fn la_anticadena_se_comprueba_contra_el_almacen_real() {
    let esc = escenario_dag();
    // Padres B (seleccionado) y A (extra): A está en el pasado de B.
    let h = cabecera(
        PadresDag::nuevo(esc.h_b.block_hash(), &[esc.h_a.block_hash()]).unwrap(),
        9,
    );
    assert_eq!(
        comprobar_padres_contextual(&h, &esc.almacen),
        Err(ConsensusError::PadresNoAnticadena {
            antepasado: esc.h_a.block_hash(),
            descendiente: esc.h_b.block_hash(),
        })
    );
}

#[test]
fn el_prev_hash_que_no_es_sp_se_rechaza_contra_el_almacen_real() {
    let esc = escenario_dag();
    // Padres anticadena A y C; pero se declara C como seleccionado. El sp real (mayor bw)
    // es A, porque A y C tienen el mismo bw y A tiene menor sd.
    let h = cabecera(
        PadresDag::nuevo(esc.h_c.block_hash(), &[esc.h_a.block_hash()]).unwrap(),
        9,
    );
    assert_eq!(
        comprobar_padres_contextual(&h, &esc.almacen),
        Err(ConsensusError::PadreSeleccionadoIncorrecto {
            esperado: esc.h_a.block_hash(),
            encontrado: esc.h_c.block_hash(),
        })
    );
}

#[test]
fn padres_validados_y_anticadena_pasan_contra_el_almacen_real() {
    let esc = escenario_dag();
    // A y C son hermanas (anticadena), y A es el sp (menor sd).
    let h = cabecera(
        PadresDag::nuevo(esc.h_a.block_hash(), &[esc.h_c.block_hash()]).unwrap(),
        9,
    );
    assert!(comprobar_padres_contextual(&h, &esc.almacen).is_ok());
}
