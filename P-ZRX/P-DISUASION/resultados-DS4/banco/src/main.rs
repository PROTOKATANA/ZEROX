//! DS-4 — banco de medida CPU/GPU de la regeneración de un registro PoAS.
//!
//! Reproduce `record_encoding` (privado en `subspace-farmer-components`, ver
//! `PDF/autonomys-subspace/crates/subspace-farmer-components/src/plotting.rs:616`) con la API
//! pública del clon fijado `f8842d0`: tabla de prueba de espacio (Chia, K=20) + codificación
//! erasure + enmascarado XOR con el hash de la prueba. Se llama a esta reconstrucción
//! "generate_and_encode_pospace", igual que la vía GPU de
//! `shared/subspace-proof-of-space-wgpu/src/host.rs`, que declara explícitamente reflejar el
//! mismo algoritmo para que la salida sea idéntica byte a byte. No se reimplementa PoS, KZG ni
//! erasure coding: son llamadas directas a los crates del clon.
//!
//! Subcomandos:
//!   enumerar                    — lista dispositivos wgpu (igual que la sonda de P-INTENTO)
//!   validar <n>                 — compara CPU vs GPU byte a byte en `n` semillas, sha256 de cada vía
//!   medir cpu <segundos>        — registros/s en CPU (usa RAYON_NUM_THREADS del entorno)
//!   medir gpu <segundos>        — registros/s en GPU (requiere una GPU discreta)

#![feature(portable_simd)]

use futures::executor::block_on;
use sha2::{Digest, Sha256};
use std::env;
use std::num::NonZeroU8;
use std::num::NonZeroUsize;
use std::simd::Simd;
use std::time::{Duration, Instant};
use subspace_core_primitives::ScalarBytes;
use subspace_core_primitives::pieces::Record;
use subspace_core_primitives::pos::PosSeed;
use subspace_erasure_coding::ErasureCoding;
use subspace_kzg::Scalar;
use subspace_proof_of_space::chia_v2::ChiaV2Table;
use subspace_proof_of_space::{Table, TableGenerator};
use subspace_proof_of_space_wgpu::{Device, DeviceType, WgpuDevice};

/// Semilla determinista: prefijo + índice, hasheados con blake3 (igual criterio que la sonda de
/// P-INTENTO, `banco-rust-gpu/src/main.rs`).
fn semilla(prefijo: &str, i: u64) -> PosSeed {
    let mut buf = [0u8; 24];
    let p = prefijo.as_bytes();
    let n = p.len().min(16);
    buf[..n].copy_from_slice(&p[..n]);
    buf[16..24].copy_from_slice(&i.to_le_bytes());
    PosSeed::from(*blake3::hash(&buf).as_bytes())
}

fn erasure_coding() -> ErasureCoding {
    ErasureCoding::new(
        NonZeroUsize::new(Record::NUM_S_BUCKETS.next_power_of_two().ilog2() as usize)
            .expect("no cero"),
    )
    .expect("escala valida")
}

/// Reproduce el algoritmo de `record_encoding` a partir de una tabla PoS ya generada en CPU
/// (`ChiaV2Table`). Es la misma secuencia que `WgpuDevice::generate_and_encode_pospace`
/// (`shared/subspace-proof-of-space-wgpu/src/host.rs:33-116`), sustituyendo el buffer de pruebas de
/// la GPU por `tabla.find_proof(s_bucket)`.
fn cpu_generate_and_encode(
    tabla: &ChiaV2Table,
    erasure: &ErasureCoding,
    record: &mut Record,
    encoded_chunks_used_output: &mut [bool],
) {
    let source_record_chunks = record.to_vec();
    let parity_record_chunks = erasure
        .extend(
            &source_record_chunks
                .iter()
                .map(|scalar_bytes| {
                    Scalar::try_from(scalar_bytes).expect("chunk de registro valido")
                })
                .collect::<Vec<_>>(),
        )
        .expect("erasure coding valido para esta escala")
        .into_iter()
        .map(<[u8; ScalarBytes::FULL_BYTES]>::from)
        .collect::<Vec<_>>();

    let mut encoded_chunks_used = vec![false; Record::NUM_S_BUCKETS];
    let mut chunks_scratch =
        Vec::<[u8; ScalarBytes::FULL_BYTES]>::with_capacity(Record::NUM_S_BUCKETS);
    for s_bucket in 0..Record::NUM_S_BUCKETS {
        let record_chunk = if s_bucket % 2 == 0 {
            &source_record_chunks[s_bucket / 2]
        } else {
            &parity_record_chunks[s_bucket / 2]
        };
        let encoded_chunk = match tabla.find_proof(s_bucket as u32) {
            Some(proof) => (Simd::from(*record_chunk) ^ Simd::from(*proof.hash())).to_array(),
            None => [0u8; ScalarBytes::FULL_BYTES],
        };
        chunks_scratch.push(encoded_chunk);
    }

    let num_successfully_encoded_chunks = chunks_scratch
        .drain(..)
        .zip(encoded_chunks_used.iter_mut())
        .filter_map(|(maybe_encoded_chunk, encoded_chunk_used)| {
            if maybe_encoded_chunk == [0u8; ScalarBytes::FULL_BYTES] {
                None
            } else {
                *encoded_chunk_used = true;
                Some(maybe_encoded_chunk)
            }
        })
        .take(record.len())
        .zip(record.iter_mut())
        .map(|(input_chunk, output_chunk)| *output_chunk = input_chunk)
        .count();

    source_record_chunks
        .iter()
        .zip(&parity_record_chunks)
        .flat_map(|(a, b)| [a, b])
        .zip(encoded_chunks_used.iter())
        .filter_map(|(record_chunk, used)| if *used { None } else { Some(record_chunk) })
        .zip(record.iter_mut().skip(num_successfully_encoded_chunks))
        .for_each(|(input_chunk, output_chunk)| *output_chunk = *input_chunk);

    encoded_chunks_used_output.copy_from_slice(&encoded_chunks_used);
}

fn elegir_gpu_discreta() -> Result<WgpuDevice, String> {
    let dispositivos = block_on(Device::enumerate(|_tipo| NonZeroU8::new(1).expect("no cero")));
    if dispositivos.is_empty() {
        return Err("wgpu no encontro ningun adaptador".into());
    }
    for d in &dispositivos {
        eprintln!(
            "DISPOSITIVO\tid={}\tnombre={}\ttipo={:?}\tbackend={:?}",
            d.id(),
            d.name(),
            d.device_type(),
            d.backend()
        );
    }
    let indice = dispositivos
        .iter()
        .position(|d| matches!(d.device_type(), DeviceType::DiscreteGpu))
        .ok_or_else(|| "no hay GPU discreta (solo integrada o software)".to_string())?;
    let dispositivo = &dispositivos[indice];
    eprintln!("ELEGIDO\t{} ({:?})", dispositivo.name(), dispositivo.backend());
    let instancias = dispositivo.create_proofs_encoder_instances();
    if instancias.is_empty() {
        return Err("el dispositivo no expone ninguna cola".into());
    }
    let instancia = instancias.into_iter().next().expect("no vacio");
    Ok(WgpuDevice::new(instancia, erasure_coding()))
}

fn cmd_enumerar() {
    let dispositivos = block_on(Device::enumerate(|_tipo| NonZeroU8::new(1).expect("no cero")));
    println!("DISPOSITIVOS\t{}", dispositivos.len());
    for d in &dispositivos {
        println!(
            "DISPOSITIVO\tid={}\tnombre={}\ttipo={:?}\tbackend={:?}",
            d.id(),
            d.name(),
            d.device_type(),
            d.backend()
        );
    }
}

fn cmd_validar(n: u64) {
    let generador = ChiaV2Table::generator();
    let erasure = erasure_coding();
    let mut gpu = match elegir_gpu_discreta() {
        Ok(g) => g,
        Err(motivo) => {
            println!("RESULTADO\tGPU no medida: {motivo}");
            return;
        }
    };

    let mut hasher_cpu = Sha256::new();
    let mut hasher_gpu = Sha256::new();
    let mut discrepancias: u64 = 0;
    let mut usados_cpu = vec![false; Record::NUM_S_BUCKETS];
    let mut usados_gpu = vec![false; Record::NUM_S_BUCKETS];
    let mut usados_discrepantes: u64 = 0;

    for i in 0..n {
        let s = semilla("DS4VALID", i);

        let mut rec_cpu = Record::new_boxed();
        let tabla = generador.generate_parallel(&s);
        cpu_generate_and_encode(&tabla, &erasure, &mut rec_cpu, &mut usados_cpu);

        let mut rec_gpu = Record::new_boxed();
        if let Err(error) =
            gpu.generate_and_encode_pospace(&s, &mut rec_gpu, usados_gpu.iter_mut())
        {
            println!("RESULTADO\tGPU no medida: fallo al generar en validacion: {error}");
            return;
        }

        if AsRef::<[u8]>::as_ref(rec_cpu.as_ref()) != AsRef::<[u8]>::as_ref(rec_gpu.as_ref()) {
            discrepancias += 1;
            if discrepancias <= 5 {
                eprintln!("DISCREPANCIA\tsemilla_idx={i}");
            }
        }
        if usados_cpu != usados_gpu {
            usados_discrepantes += 1;
        }

        hasher_cpu.update(AsRef::<[u8]>::as_ref(rec_cpu.as_ref()));
        hasher_gpu.update(AsRef::<[u8]>::as_ref(rec_gpu.as_ref()));
    }

    let sha_cpu = hex::encode(hasher_cpu.finalize());
    let sha_gpu = hex::encode(hasher_gpu.finalize());
    println!("N\t{n}");
    println!("SHA256_CPU\t{sha_cpu}");
    println!("SHA256_GPU\t{sha_gpu}");
    println!("DISCREPANCIAS_BYTES\t{discrepancias}");
    println!("DISCREPANCIAS_MAPA_USADOS\t{usados_discrepantes}");
    if discrepancias == 0 && usados_discrepantes == 0 && sha_cpu == sha_gpu {
        println!("RESULTADO\tVALIDACION_OK: {n} registros identicos bit a bit CPU/GPU");
    } else {
        println!("RESULTADO\tVALIDACION_FALLIDA");
    }
}

fn cmd_medir_cpu(segundos: f64) {
    let generador = ChiaV2Table::generator();
    let erasure = erasure_coding();
    let mut usados = vec![false; Record::NUM_S_BUCKETS];
    let hilos = std::env::var("RAYON_NUM_THREADS").unwrap_or_else(|_| "auto".into());
    eprintln!("HILOS_RAYON\t{hilos}");

    let inicio = Instant::now();
    let limite = Duration::from_secs_f64(segundos);
    let mut i: u64 = 0;
    let mut ultimo: f64 = 0.0;
    loop {
        let s = semilla("DS4MEDCPU", i);
        let mut rec = Record::new_boxed();
        let tabla = generador.generate_parallel(&s);
        cpu_generate_and_encode(&tabla, &erasure, &mut rec, &mut usados);
        std::hint::black_box(&rec);
        i += 1;
        let transcurrido = inicio.elapsed();
        if transcurrido >= limite {
            ultimo = transcurrido.as_secs_f64();
            break;
        }
    }
    println!("DISPOSITIVO\tCPU");
    println!("HILOS_RAYON\t{hilos}");
    println!("ITERACIONES\t{i}");
    println!("SEGUNDOS\t{ultimo:.6}");
    println!("REGISTROS_POR_S\t{:.6}", i as f64 / ultimo);
    println!("S_POR_REGISTRO\t{:.6}", ultimo / i as f64);
}

fn cmd_medir_gpu(segundos: f64) {
    let mut gpu = match elegir_gpu_discreta() {
        Ok(g) => g,
        Err(motivo) => {
            println!("RESULTADO\tGPU no medida: {motivo}");
            return;
        }
    };
    let mut usados = vec![false; Record::NUM_S_BUCKETS];

    let inicio = Instant::now();
    let limite = Duration::from_secs_f64(segundos);
    let mut i: u64 = 0;
    let mut ultimo: f64 = 0.0;
    loop {
        let s = semilla("DS4MEDGPU", i);
        let mut rec = Record::new_boxed();
        if let Err(error) = gpu.generate_and_encode_pospace(&s, &mut rec, usados.iter_mut()) {
            println!("RESULTADO\tGPU no medida: fallo al generar durante la medida: {error}");
            return;
        }
        std::hint::black_box(&rec);
        i += 1;
        let transcurrido = inicio.elapsed();
        if transcurrido >= limite {
            ultimo = transcurrido.as_secs_f64();
            break;
        }
    }
    println!("DISPOSITIVO\tGPU");
    println!("ITERACIONES\t{i}");
    println!("SEGUNDOS\t{ultimo:.6}");
    println!("REGISTROS_POR_S\t{:.6}", i as f64 / ultimo);
    println!("S_POR_REGISTRO\t{:.6}", ultimo / i as f64);
}

fn main() {
    let args: Vec<String> = env::args().collect();
    match args.get(1).map(String::as_str) {
        Some("enumerar") => cmd_enumerar(),
        Some("validar") => {
            let n: u64 = args.get(2).and_then(|v| v.parse().ok()).unwrap_or(1000);
            cmd_validar(n);
        }
        Some("medir") => match args.get(2).map(String::as_str) {
            Some("cpu") => {
                let s: f64 = args.get(3).and_then(|v| v.parse().ok()).unwrap_or(30.0);
                cmd_medir_cpu(s);
            }
            Some("gpu") => {
                let s: f64 = args.get(3).and_then(|v| v.parse().ok()).unwrap_or(30.0);
                cmd_medir_gpu(s);
            }
            _ => eprintln!("uso: ds4 medir <cpu|gpu> <segundos>"),
        },
        _ => eprintln!("uso: ds4 <enumerar|validar <n>|medir <cpu|gpu> <segundos>>"),
    }
}
