#![feature(portable_simd)]

//! M5 · sonda de la ruta GPU del codigo fijado.
//!
//! Pasos, en orden, con salida legible aunque falle algo:
//!   1. Enumerar dispositivos wgpu (Vulkan/Metal) por la API publica del clon.
//!   2. Si aparece una GPU discreta, medir `generate_and_encode_pospace` — que es el equivalente
//!      GPU de `record_encoding` en `crates/subspace-farmer-components/src/plotting.rs:616-667`:
//!      tabla + erasure coding + enmascarado con la prueba.
//!   3. Si no hay dispositivo o falla, imprimir el motivo y terminar. El resultado es
//!      «GPU no medida».
//!
//! NO se extrapola a partir de esta tarjeta (GTX 1070, Pascal 2016): si midiera, su cifra seria
//! una cota INFERIOR de lo que hace una GPU actual.

use futures::executor::block_on;
use std::num::NonZeroU8;
use std::num::NonZeroUsize;
use std::time::Instant;
use subspace_core_primitives::pieces::Record;
use subspace_core_primitives::pos::PosSeed;
use subspace_erasure_coding::ErasureCoding;
use subspace_proof_of_space_wgpu::{Device, DeviceType, WgpuDevice};

fn semilla(i: u64) -> PosSeed {
    let mut buf = [0_u8; 16];
    buf[..8].copy_from_slice(b"INTENTO1");
    buf[8..].copy_from_slice(&i.to_le_bytes());
    PosSeed::from(*blake3::hash(&buf).as_bytes())
}

fn main() {
    let repeticiones: usize = std::env::args()
        .nth(1)
        .map(|v| v.parse().expect("entero"))
        .unwrap_or(3);

    println!("SONDA\tinicio");
    println!("BACKENDS_ENV\t{}", std::env::var("WGPU_BACKEND").unwrap_or_else(|_| "sin definir".into()));

    let t0 = Instant::now();
    let dispositivos = block_on(Device::enumerate(|_tipo| NonZeroU8::new(1).expect("no cero")));
    println!("ENUMERACION_S\t{:.3}", t0.elapsed().as_secs_f64());
    println!("DISPOSITIVOS\t{}", dispositivos.len());

    if dispositivos.is_empty() {
        println!("RESULTADO\tGPU no medida: wgpu no encontro ningun adaptador");
        return;
    }

    for d in &dispositivos {
        println!(
            "DISPOSITIVO\tid={}\tnombre={}\ttipo={:?}\tbackend={:?}",
            d.id(),
            d.name(),
            d.device_type(),
            d.backend()
        );
    }

    let Some(indice) = dispositivos
        .iter()
        .position(|d| matches!(d.device_type(), DeviceType::DiscreteGpu))
    else {
        println!("RESULTADO\tGPU no medida: no hay GPU discreta (solo integrada o software)");
        return;
    };

    let dispositivo = &dispositivos[indice];
    println!("ELEGIDO\t{}", dispositivo.name());

    let erasure = ErasureCoding::new(
        NonZeroUsize::new(Record::NUM_S_BUCKETS.next_power_of_two().ilog2() as usize)
            .expect("no cero"),
    )
    .expect("escala valida");

    let instancias = dispositivo.create_proofs_encoder_instances();
    println!("COLAS\t{}", instancias.len());
    let Some(instancia) = instancias.into_iter().next() else {
        println!("RESULTADO\tGPU no medida: el dispositivo no expone ninguna cola");
        return;
    };
    let mut encoder = WgpuDevice::new(instancia, erasure);

    let mut tiempos = Vec::new();
    for i in 0..repeticiones {
        let mut record = Record::new_boxed();
        let mut usado = vec![false; Record::NUM_S_BUCKETS];
        let s = semilla(i as u64);
        let t = Instant::now();
        match encoder.generate_and_encode_pospace(&s, &mut record, usado.iter_mut()) {
            Ok(()) => {
                let s = t.elapsed().as_secs_f64();
                let usados = usado.iter().filter(|v| **v).count();
                println!("ITER\t{i}\t{s:.6}\tchunks_usados={usados}");
                tiempos.push(s);
            }
            Err(error) => {
                println!("RESULTADO\tGPU no medida: fallo al generar: {error}");
                return;
            }
        }
    }

    tiempos.sort_by(|a, b| a.partial_cmp(b).expect("sin NaN"));
    let mediana = tiempos[tiempos.len() / 2];
    println!("MEDIANA_S\t{mediana:.6}");
    println!("TABLAS_POR_S\t{:.4}", 1.0 / mediana);
    println!(
        "RESULTADO\tmedido en {} ({}). Cota INFERIOR de una GPU actual: es de 2016.",
        dispositivo.name(),
        format!("{:?}", dispositivo.backend())
    );
}
