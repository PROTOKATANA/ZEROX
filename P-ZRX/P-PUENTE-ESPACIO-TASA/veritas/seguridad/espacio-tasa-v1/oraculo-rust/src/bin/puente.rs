#![feature(generic_const_exprs)]
#![expect(
    incomplete_features,
    reason = "ab-proof-of-space usa generic_const_exprs; el binario nombra Proofs<20>"
)]

//! CLI del oraculo Rust: aplica la logica PoAS fijada y escribe datos legibles por maquina.
//!
//! Uso:
//! ```text
//! puente vectores --out DIR
//! puente bits     --piezas M --retos K --out DIR [--hilos N]
//! puente audita   --piezas M --retos K --out DIR [--hilos N] [--sr a,b,c]
//! puente prueba   --out DIR
//! ```

use ab_proof_of_space::chiapos::TablesCache;
use oraculo_espacio_tasa as oet;
use rayon::prelude::*;
use std::fmt::Write as _;
use std::fs;
use std::io::Write as _;
use std::num::NonZeroUsize;
use std::path::{Path, PathBuf};
use subspace_core_primitives::pieces::PieceOffset;
use subspace_core_primitives::pos::PosProof;
use subspace_core_primitives::sectors::SBucket;
use subspace_core_primitives::solutions::{SolutionPotVerifier, SolutionRange};

// ---------------------------------------------------------------------------------------------
// Utilidades
// ---------------------------------------------------------------------------------------------

fn arg(args: &[String], clave: &str) -> Option<String> {
    args.iter()
        .position(|a| a == clave)
        .and_then(|i| args.get(i + 1).cloned())
}

fn arg_usize(args: &[String], clave: &str, def: usize) -> usize {
    arg(args, clave)
        .map(|v| v.parse().expect("entero"))
        .unwrap_or(def)
}

fn arg_srs(args: &[String]) -> Vec<SolutionRange> {
    match arg(args, "--sr") {
        Some(s) => s
            .split(',')
            .map(|v| v.trim().parse().expect("u64"))
            .collect(),
        None => srs_por_defecto(),
    }
}

/// Valores de `SR` del barrido. **Son escenarios experimentales, no decisiones de consenso.**
/// Incluye extremos (0, `u64::MAX`), paridad (1, 2, 3, 7, 8) y valores de red plausibles.
fn srs_por_defecto() -> Vec<SolutionRange> {
    vec![
        0,
        1,
        2,
        3,
        7,
        8,
        255,
        256,
        4096,
        1 << 20,
        1 << 31,
        u64::MAX - 1,
        u64::MAX,
    ]
}

/// `SR` con los que se evalua cada **par** de retos. Deben ser discriminantes: con `u64::MAX`
/// todo chunk gana y la estadistica conjunta de candidatos degenera. Por omision se usan valores
/// que cubren `p ∈ {1/2, 1/8, 1/128}` y el `SR` calibrado de una red de 1000 piezas
/// (`pieces_to_solution_range(1000, (1,6)) = 6_148_914_691_236_495`), que es el régimen realista
/// de un sector aislado.
fn arg_srs_pares(args: &[String]) -> Vec<SolutionRange> {
    match arg(args, "--sr-pares") {
        Some(s) => s
            .split(',')
            .map(|v| v.trim().parse().expect("u64"))
            .collect(),
        None => vec![
            9_223_372_036_854_775_806, // p = 1/2
            2_305_843_009_213_693_950, // p = 1/8
            144_115_188_075_855_870,   // p = 1/128
            6_148_914_691_236_495,     // SR calibrado de una red de 1000 piezas (1/6 por slot)
        ],
    }
}

/// Semilla de 32 bytes para el crate de codigo de borrado.
fn erasure() -> subspace_erasure_coding::ErasureCoding {
    subspace_erasure_coding::ErasureCoding::new(
        NonZeroUsize::new(oet::ERASURE_SCALE).expect("escala no nula; qed"),
    )
    .expect("escala 16 valida; qed")
}

fn escribir(ruta: &Path, contenido: &str) {
    if let Some(p) = ruta.parent() {
        fs::create_dir_all(p).expect("crear directorio de resultados");
    }
    let mut f = fs::File::create(ruta).expect("crear fichero de resultados");
    f.write_all(contenido.as_bytes()).expect("escribir");
}


/// Hex de cualquier valor que exponga `AsRef<[u8]>`. `Blake3Hash` y `SectorId` solo tienen esa
/// implementacion, asi que la llamada generica evita la ambiguedad de `try_into`.
fn hex_asref<T: AsRef<[u8]>>(v: &T) -> String {
    hex::encode(v.as_ref())
}

// ---------------------------------------------------------------------------------------------
// `vectores`: casos minimos para que Julia compruebe orden de bytes y predicado
// ---------------------------------------------------------------------------------------------

fn cmd_vectores(out: &Path) {
    let cache = TablesCache::default();
    let era = erasure();
    let sectores = 3_usize;
    let piezas_por_sector = 8_usize;
    let retos_por_sector = 3_u64;
    let chunks_por_caso = 4_usize;

    let srs: Vec<SolutionRange> = vec![
        0,
        1,
        2,
        3,
        7,
        8,
        255,
        256,
        1000,
        4096,
        1 << 40,
        u64::MAX - 1,
        u64::MAX,
    ];

    let mut tsv = String::from(
        "caso\tsr\tbucket\tssc_hex\tglobal_hex\tchunk_hex\taudit_chunk_hex\tdistancia\tgana\n",
    );
    let mut buckets = String::from("caso\tsector\tsector_id_hex\tglobal_hex\tssc_hex\tbucket\n");
    let mut caso = 0_usize;
    for s in 0..sectores {
        let sid = oet::sector_id_i(s as u64);
        let piezas: Vec<oet::Pieza> = (0..piezas_por_sector)
            .map(|p| {
                oet::construir_pieza(
                    &sid,
                    PieceOffset::from(p as u16),
                    &cache,
                    &era,
                )
            })
            .collect();
        let refs: Vec<&oet::Pieza> = piezas.iter().collect();
        for r in 0..retos_por_sector {
            let gc = oet::reto_i(s as u64 * 1000 + r);
            let ssc = sid.derive_sector_slot_challenge(&gc);
            let b = usize::from(ssc.s_bucket_audit_index());
            let _ = writeln!(
                buckets,
                "{caso}\t{s}\t{}\t{}\t{}\t{b}",
                hex_asref(&sid),
                hex_asref(&gc),
                hex_asref(&*ssc),
            );
            // Chunks realmente almacenados en ese s-bucket, en orden de pieza.
            let mut emitidos = 0_usize;
            for p in &refs {
                if emitidos >= chunks_por_caso {
                    break;
                }
                let Some(idx) = oet::indice_denso(p, b) else {
                    continue;
                };
                let chunk = &p.chunks[idx];
                let ac = oet::audit_chunk_de(&ssc, chunk);
                let d = oet::distancia_referencia(&gc, chunk, &ssc);
                // Contraste obligatorio con la via upstream.
                for &sr in &srs {
                    let up = subspace_verification::is_within_solution_range(&gc, chunk, &ssc, sr);
                    let gana = d <= sr / 2;
                    assert_eq!(up.is_some(), gana, "discrepancia upstream/referencia");
                    let _ = writeln!(
                        tsv,
                        "{caso}\t{sr}\t{b}\t{}\t{}\t{}\t{}\t{d}\t{}",
                        hex_asref(&*ssc),
                        hex_asref(&gc),
                        hex::encode(chunk),
                        hex_asref(&ac),
                        u8::from(gana),
                    );
                }
                emitidos += 1;
            }
            caso += 1;
        }
    }

    // Contraste del rank/select local contra `Proofs::for_s_bucket` en todos los buckets.
    let sid0 = oet::sector_id_i(0);
    let (p0, tabla0) = oet::construir_pieza_con_tabla(
        &sid0,
        PieceOffset::from(0_u16),
        &cache,
        &era,
    );
    let n_rank = oet::contrastar_rank_select(&p0, &tabla0);

    escribir(&out.join("vectores.tsv"), &tsv);
    escribir(&out.join("vectores-buckets.tsv"), &buckets);
    escribir(
        &out.join("vectores-meta.tsv"),
        &format!(
            "campo\tvalor\nsectores\t{sectores}\npiezas_por_sector\t{piezas_por_sector}\n\
             retos_por_sector\t{retos_por_sector}\nchunks_por_caso\t{chunks_por_caso}\n\
             buckets_contrastados_rank_select\t{n_rank}\n"
        ),
    );
    println!("vectores: caso total {caso}; rank/select contrastado en {n_rank} buckets");
}

// ---------------------------------------------------------------------------------------------
// `bits`: mapas de presencia reales de M piezas
// ---------------------------------------------------------------------------------------------

fn cmd_bits(out: &Path, m: usize, retos: usize, hilos: usize) {
    let sid = oet::sector_id_i(0);
    // La generacion de tablas chiapos consume varios MiB de pila por llamada; el valor por
    // omision de rayon (2 MiB) desborda. 64 MiB por hilo es memoria virtual, no residente.
    let pool = rayon::ThreadPoolBuilder::new()
        .stack_size(64 * 1024 * 1024)
        .num_threads(hilos)
        .build()
        .expect("pool; qed");

    let t0 = std::time::Instant::now();
    let mut mapas: Vec<Option<([u8; oet::BITMAP_BYTES], usize)>> =
        (0..m).map(|_| None).collect();
    pool.install(|| {
        mapas.par_iter_mut().enumerate().for_each(|(i, slot)| {
            // Cache **por llamada**: compartirla entre hilos corrompe el monton.
            let cache = TablesCache::default();
            *slot = Some(oet::construir_bitmap(
                &sid,
                PieceOffset::from(i as u16),
                &cache,
            ));
        });
    });
    let t_construir = t0.elapsed().as_secs_f64();
    let mapas: Vec<([u8; oet::BITMAP_BYTES], usize)> = mapas
        .into_iter()
        .map(|x| x.expect("relleno; qed"))
        .collect();

    // `bitmaps.bin`: M x 8192 B, orden de pieza.
    let mut bin = Vec::with_capacity(m * oet::BITMAP_BYTES);
    for (bmp, _) in &mapas {
        bin.extend_from_slice(bmp);
    }
    fs::create_dir_all(out).expect("crear out");
    fs::write(out.join("bitmaps.bin"), &bin).expect("escribir bitmaps.bin");

    let mut meta = String::from("campo\tvalor\n");
    let _ = writeln!(meta, "piezas\t{m}");
    let _ = writeln!(meta, "hilos\t{hilos}");
    let _ = writeln!(
        meta,
        "sector_id_hex\t{}",
        hex_asref(&sid)
    );
    let _ = writeln!(meta, "bitmap_bytes\t{}", oet::BITMAP_BYTES);
    let _ = writeln!(meta, "num_s_buckets\t{}", oet::NUM_S_BUCKETS);
    let _ = writeln!(meta, "num_chunks\t{}", oet::NUM_CHUNKS);
    let _ = writeln!(meta, "t_construir_s\t{t_construir:.6}");
    let _ = writeln!(meta, "camino_tabla\t{}", oet::camino_tabla());
    escribir(&out.join("bits-meta.tsv"), &meta);

    let mut por_pieza = String::from("pieza\tpruebas\tbucket_min\tbucket_max\n");
    for (i, (bmp, n)) in mapas.iter().enumerate() {
        let mut min = usize::MAX;
        let mut max = 0_usize;
        for b in 0..oet::NUM_S_BUCKETS {
            if bmp[b / 8] & (1 << (b % 8)) != 0 {
                if b < min {
                    min = b;
                }
                if b > max {
                    max = b;
                }
            }
        }
        let _ = writeln!(por_pieza, "{i}\t{n}\t{min}\t{max}");
    }
    escribir(&out.join("bits-por-pieza.tsv"), &por_pieza);

    // Retos usados en la fase de auditoria (mismos en `bits` y `audita`).
    let mut rt = String::from("i\thex\n");
    for k in 0..retos {
        let gc = oet::reto_i(k as u64);
        let _ = writeln!(
            rt,
            "{k}\t{}",
            hex_asref(&gc)
        );
    }
    escribir(&out.join("retos.tsv"), &rt);

    println!(
        "bits: {m} piezas en {t_construir:.2} s ({:.2} tablas/s, {hilos} hilos)",
        m as f64 / t_construir
    );
}

// ---------------------------------------------------------------------------------------------
// `audita`: candidatos reales por slot y solapamiento entre dos retos
// ---------------------------------------------------------------------------------------------

fn cmd_audita(out: &Path, m: usize, retos: usize, hilos: usize) {
    let sid = oet::sector_id_i(0);
    let srs = arg_srs(&std::env::args().collect::<Vec<_>>());
    let t0 = std::time::Instant::now();
    let piezas = oet::construir_sector(&sid, m, hilos);
    let t_sector = t0.elapsed().as_secs_f64();
    let refs: Vec<&oet::Pieza> = piezas.iter().collect();

    let mut filas =
        String::from("reto\tsr\tbucket\tchunks_leidos\tcandidatos\tdistancia_minima\n");
    let mut t_auditar = 0.0_f64;
    for k in 0..retos {
        let gc = oet::reto_i(k as u64);
        let ssc = sid.derive_sector_slot_challenge(&gc);
        for &sr in &srs {
            let ta = std::time::Instant::now();
            let a = oet::auditar(&refs, &gc, &ssc, sr, true);
            t_auditar += ta.elapsed().as_secs_f64();
            let dmin = a.distancias.iter().copied().min().unwrap_or(u64::MAX);
            let _ = writeln!(
                filas,
                "{k}\t{sr}\t{}\t{}\t{}\t{dmin}",
                a.bucket, a.chunks_leidos, a.candidatos
            );
        }
    }
    escribir(&out.join("audita-retos.tsv"), &filas);

    // Pares de retos divergentes sobre la MISMA parcela: solapamiento de oportunidades.
    //
    // Se evaluan **varios SR** y no solo el mayor. Con `SR = u64::MAX` todo chunk gana y la
    // estadistica conjunta de candidatos degenera en la de chunks auditados; hace falta un SR
    // discriminante para poder ver si los dois retos comparten *ganadores*, no solo *oportunidades*.
    let pares: Vec<(usize, usize)> = (0..retos.min(64))
        .flat_map(|i| ((i + 1)..retos.min(64)).map(move |j| (i, j)))
        .collect();
    let srs_pares = arg_srs_pares(&std::env::args().collect::<Vec<_>>());
    let mut tsv = String::from(
        "sr\ti\tj\tbucket_i\tbucket_j\tbucket_igual\tleidos_i\tleidos_j\tchunks_comunes\t\
         cand_i\tcand_j\tcand_comunes\tdist_min_i\tdist_min_j\n",
    );
    let mut resultado: Vec<String> = (0..pares.len()).map(|_| String::new()).collect();
    // Cada par se evalua en su propia posicion: escritura disjunta, reduccion ordenada por indice.
    resultado.par_iter_mut().enumerate().for_each(|(idx, slot)| {
        let (i, j) = pares[idx];
        let gci = oet::reto_i(i as u64);
        let gcj = oet::reto_i(j as u64);
        let ssci = sid.derive_sector_slot_challenge(&gci);
        let sscj = sid.derive_sector_slot_challenge(&gcj);
        let bi = usize::from(ssci.s_bucket_audit_index());
        let bj = usize::from(sscj.s_bucket_audit_index());
        // Una sola pasada por pieza: se guardan las distancias y luego se prueba cada SR.
        let mut di = vec![u64::MAX; m];
        let mut dj = vec![u64::MAX; m];
        let mut leidos_i = 0_usize;
        let mut leidos_j = 0_usize;
        let mut comunes = 0_usize;
        for (idx_p, p) in refs.iter().enumerate() {
            let ci = oet::indice_denso(p, bi);
            let cj = oet::indice_denso(p, bj);
            if ci.is_some() {
                leidos_i += 1;
            }
            if cj.is_some() {
                leidos_j += 1;
            }
            if ci.is_some() && cj.is_some() {
                comunes += 1;
            }
            if let Some(a) = ci {
                di[idx_p] = oet::distancia_referencia(&gci, &p.chunks[a], &ssci);
            }
            if let Some(b) = cj {
                dj[idx_p] = oet::distancia_referencia(&gcj, &p.chunks[b], &sscj);
            }
        }
        let mut lineas = String::new();
        for &sr in &srs_pares {
            let umbral = sr / 2;
            let mut cand_i = 0_usize;
            let mut cand_j = 0_usize;
            let mut cand_comunes = 0_usize;
            let mut dmin_i = u64::MAX;
            let mut dmin_j = u64::MAX;
            for idx_p in 0..m {
                let gi = di[idx_p] <= umbral;
                let gj = dj[idx_p] <= umbral;
                if gi {
                    cand_i += 1;
                    dmin_i = dmin_i.min(di[idx_p]);
                }
                if gj {
                    cand_j += 1;
                    dmin_j = dmin_j.min(dj[idx_p]);
                }
                if gi && gj {
                    cand_comunes += 1;
                }
            }
            let _ = writeln!(
                lineas,
                "{sr}\t{i}\t{j}\t{bi}\t{bj}\t{}\t{leidos_i}\t{leidos_j}\t{comunes}\t\
                 {cand_i}\t{cand_j}\t{cand_comunes}\t{dmin_i}\t{dmin_j}",
                u8::from(bi == bj)
            );
        }
        *slot = lineas;
    });
    for linea in resultado {
        // `linea` ya termina en '\n' (se construyo con `writeln!`); anadir otro insertaba 2016
        // lineas en blanco intercaladas. Lo detecto la revision independiente.
        tsv.push_str(&linea);
    }
    escribir(&out.join("audita-pares.tsv"), &tsv);

    let mut meta = String::from("campo\tvalor\n");
    let _ = writeln!(meta, "piezas\t{m}");
    let _ = writeln!(meta, "retos\t{retos}");
    let _ = writeln!(meta, "hilos\t{hilos}");
    let _ = writeln!(meta, "sr_pares\t{}", srs_pares.iter().map(|v| v.to_string()).collect::<Vec<_>>().join(","));
    let _ = writeln!(meta, "t_sector_s\t{t_sector:.6}");
    let _ = writeln!(meta, "t_auditar_total_s\t{t_auditar:.6}");
    let _ = writeln!(
        meta,
        "pares_evaluados\t{}",
        pares.len()
    );
    let _ = writeln!(
        meta,
        "sector_id_hex\t{}",
        hex_asref(&sid)
    );
    escribir(&out.join("audita-meta.tsv"), &meta);

    println!(
        "audita: {m} piezas en {t_sector:.2} s; {} auditorias en {t_auditar:.2} s",
        retos * srs.len()
    );
}

// ---------------------------------------------------------------------------------------------
// `prueba`: verificacion COMPLETA (PoS) de candidatos, y un candidato corrupto
// ---------------------------------------------------------------------------------------------

/// Verifica la prueba **PoS** de un candidato con `is_proof_valid`, y una copia con un byte
/// invertido que debe rechazarse.
///
/// **Alcance, explicito.** Esto NO es `verify_solution`: no se comprueba el compromiso de
/// registro, ni el testigo KZG, ni la firma, ni la cabecera, ni el PoT, ni la admision DAG. Se
/// llama `prueba_pos_validas` y no `pruebas_completas_validas` justamente por eso.
fn cmd_prueba(out: &Path) {
    use subspace_proof_of_space::chia_v2::ChiaV2Table;
    let sid = oet::sector_id_i(0);
    let cache = TablesCache::default();
    let era = erasure();

    // La tabla PoS se conserva viva: hace falta para obtener los objetos `PosProof` que se
    // verifican con `is_proof_valid`, la misma funcion que usa el nodo.
    let (pieza, tabla) = oet::construir_pieza_con_tabla(
        &sid,
        PieceOffset::from(0_u16),
        &cache,
        &era,
    );
    let seed = sid.derive_evaluation_seed(PieceOffset::from(0_u16));

    let sr = u64::MAX; // escenario que maximiza el numero de candidatos observables
    let gc = oet::reto_i(0);
    let ssc = sid.derive_sector_slot_challenge(&gc);
    let b = usize::from(ssc.s_bucket_audit_index());

    let mut tsv = String::from(
        "bucket\tchunk_hex\tdistancia\tprueba_valida\tprueba_corrupta_valida\tsr\n",
    );
    let mut n_cand = 0_usize;
    let mut n_validas = 0_usize;
    let mut n_corruptas_validas = 0_usize;
    let mut mostrados = 0_usize;
    for (p_idx, p) in std::iter::once(&pieza).enumerate() {
        let _ = p_idx;
        if let Some(idx) = oet::indice_denso(p, b) {
            let chunk = &p.chunks[idx];
            let d = oet::distancia_referencia(&gc, chunk, &ssc);
            if d <= sr / 2 {
                n_cand += 1;
                let proof = tabla
                    .for_s_bucket(SBucket::from(b as u16)).map(PosProof::from)
                    .expect("el bucket tiene prueba; qed");
                let valida =
                    <ChiaV2Table as SolutionPotVerifier>::is_proof_valid(&seed, b as u32, &proof);
                let mut corrupta = proof;
                corrupta.as_mut()[0] ^= 0xFF;
                let corrupta_valida = <ChiaV2Table as SolutionPotVerifier>::is_proof_valid(
                    &seed,
                    b as u32,
                    &corrupta,
                );
                if valida {
                    n_validas += 1;
                }
                if corrupta_valida {
                    n_corruptas_validas += 1;
                }
                if mostrados < 8 {
                    let _ = writeln!(
                        tsv,
                        "{b}\t{}\t{d}\t{}\t{}\t{sr}",
                        hex::encode(chunk),
                        u8::from(valida),
                        u8::from(corrupta_valida)
                    );
                    mostrados += 1;
                }
            }
        }
    }
    escribir(&out.join("prueba.tsv"), &tsv);
    escribir(
        &out.join("prueba-meta.tsv"),
        &format!(
            "campo\tvalor\nbucket\t{b}\tsr\t{sr}\ncandidatos\t{n_cand}\n\
             pruebas_pos_validas\t{n_validas}\n\
             pruebas_pos_corruptas_aceptadas\t{n_corruptas_validas}\n"
        ),
    );
    println!(
        "prueba: {n_cand} candidatos en 1 pieza (SR=u64::MAX), {n_validas} pruebas validas, \
         {n_corruptas_validas} corruptas aceptadas"
    );
    // El bucket 0..65535 se cubre con `SBucket`; se referencia para evitar avisos si cambia.
    let _ = SBucket::ZERO;
}

// ---------------------------------------------------------------------------------------------

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let Some(cmd) = args.get(1).map(String::as_str) else {
        eprintln!("uso: puente <vectores|bits|audita|prueba|constantes> --out DIR [--piezas M] [--retos K] [--hilos N] [--sr a,b,c]");
        std::process::exit(2);
    };
    let out: PathBuf = arg(&args, "--out")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("resultados"));
    let piezas = arg_usize(&args, "--piezas", 256);
    let retos = arg_usize(&args, "--retos", 256);
    let hilos = arg_usize(&args, "--hilos", 16);

    match cmd {
        "vectores" => cmd_vectores(&out),
        "bits" => cmd_bits(&out, piezas, retos, hilos),
        "audita" => cmd_audita(&out, piezas, retos, hilos),
        "prueba" => cmd_prueba(&out),
        "constantes" => cmd_constantes(&out),
        otro => {
            eprintln!("subcomando desconocido: {otro}");
            std::process::exit(2);
        }
    }
}

// ---------------------------------------------------------------------------------------------
// `constantes`: contabilidad de bytes leida de la API upstream (sin transcribir a mano)
// ---------------------------------------------------------------------------------------------

/// Imprime los tamanos exactos que el formato usa, **llamando a las funciones publicas del clon**.
///
/// Motivo: el informe publicaba una diferencia `sector_size(1000) − 1000·Piece::SIZE` calculada a
/// mano y estaba mal (8 224 frente a 8 192 064). Esta orden la deriva del codigo fijado.
fn cmd_constantes(out: &Path) {
    use subspace_core_primitives::hashes::Blake3Hash;
    use subspace_core_primitives::pieces::{Piece, Record};
    use subspace_farmer_components::sector::{
        SectorContentsMap, SectorMetadataChecksummed, sector_record_chunks_size,
        sector_record_metadata_size, sector_size,
    };

    let piezas: u16 = 1000;
    let ss = sector_size(piezas);
    let chunks = sector_record_chunks_size(piezas);
    let meta_reg = sector_record_metadata_size(piezas);
    let mapa = SectorContentsMap::encoded_size(piezas);
    let meta_sector = SectorMetadataChecksummed::encoded_size();
    let pieza = Piece::SIZE;
    let nominal_piezas = pieza * usize::from(piezas);

    let mut s = String::from("campo\tvalor\tnota\n");
    let mut fila = |k: &str, v: usize, n: &str| {
        s.push_str(&format!("{k}\t{v}\t{n}\n"));
    };
    fila("num_chunks", Record::NUM_CHUNKS, "pieces.rs:561");
    fila("num_s_buckets", Record::NUM_S_BUCKETS, "pieces.rs:565");
    fila("record_size", Record::SIZE, "pieces.rs:570: 32*2^15");
    fila("piece_size", pieza, "pieces.rs:1226: Record + commitment 48 + witness 48");
    fila("sector_record_chunks_size_1000", chunks, "1000*Record::SIZE");
    fila("sector_record_metadata_size_1000", meta_reg, "1000*RecordMetadata::encoded_size()");
    fila("sector_contents_map_encoded_size_1000", mapa, "sector.rs:362-364 (encoded_size)");
    fila("sector_size_1000", ss, "sector.rs:47-53");
    fila("blake3_hash_size", Blake3Hash::SIZE, "hashes.rs:116");
    fila("sector_metadata_checksummed_size", meta_sector,
         "SectorMetadataChecksummed::encoded_size(), FUERA de sector_size()");
    s.push_str(&format!(
        "sector_size_menos_1000_piece_size\t{}\tss - 1000*Piece::SIZE\n",
        ss - nominal_piezas
    ));
    // Correccion: la nota anterior sumaba 8 192 064 (1000*8192 + 32 + 32) y no incluia el
    // termino 1000*32 del `piece_checksum`, que es parte de la diferencia.
    s.push_str(&format!(
        "desglose_extra\t{}\t1000*32 (piece_checksum de cada registro) + 1000*8192 (mapa) + 32 (checksum del mapa) + 32 (checksum del sector)\n",
        ss - nominal_piezas
    ));
    s.push_str(&format!(
        "piece_size_menos_record_size\t{}\tcommitment+witness\n",
        pieza - Record::SIZE
    ));
    escribir(&out.join("constantes.tsv"), &s);
    println!("constantes: sector_size(1000)={ss}  1000*Piece::SIZE={nominal_piezas}  diferencia={}",
             ss - nominal_piezas);
}
