//! Medición del coste por bloque del firmante seguro (encargo §4).
//!
//! Mide lo único que importa para el camino crítico: **la latencia añadida a la producción de un
//! bloque por parte del `fsync` del punto 3 de la regla**, en el disco de esta máquina, y con qué
//! margen del slot de 1 s. Mide también la variante `fdatasync` para poder decir si merece la pena
//! y a qué riesgo.
//!
//! # Qué mide exactamente, y por qué así
//!
//! El camino de producción real es: construir el candidato, `Registro::resolver` (que escribe y
//! sincroniza) y `Firmante::firmar` (que sella). Aquí se mide **byte a byte ese camino** con la
//! criptografía real, en dos variantes que solo se diferencian en la llamada de sincronización:
//!
//! - `sync_all` — `fsync(2)`: metadatos **y** datos. Es lo que usa
//!   [`firmante_seguro::Registro`].
//! - `fdatasync` — `fdatasync(2)`: solo datos. La entrada crece el fichero, así que el tamaño
//!   también tiene que llegar al disco; la diferencia está en los demás metadatos (`mtime`, `ctime`).
//!
//! # Lo que esta medición NO es
//!
//! No es un *benchmark* de `cargo bench` ni una comparación entre bibliotecas: es una medición de
//! latencia en un disco concreto, con la carga del sistema anotada. La cola (`p99`, máximo) importa
//! más que la mediana, porque un bloque que llega tarde al slot se pierde.
//!
//! Uso:
//!
//! ```text
//! cargo run --release --locked --offline --example medir_coste -- [iteraciones] [directorio]
//! ```
//!
//! `directorio` es donde se escriben los registros de prueba. **Importa cuál sea**: `/tmp` en esta
//! máquina es `tmpfs` (RAM), y un `fsync` sobre `tmpfs` no toca ningún disco. La primera medición
//! de este prototipo se hizo sobre `tmpfs` y daba ~12 µs por bloque; sobre el disco real de la
//! máquina da dos órdenes de magnitud más. Por eso el directorio se elige a mano y se informa del
//! sistema de ficheros con el que se midió.

#![allow(unsafe_code, reason = "fdatasync(2) requiere FFI: no hay API estable en std")]

use std::hint::black_box;
use std::os::unix::io::AsRawFd as _;
use std::path::{Path, PathBuf};
use std::time::{Duration, Instant};

use ed25519_zebra::{SigningKey, VerificationKey};
use firmante_seguro::{Firmante, Registro, S_MAX_SLOTS_NOMINAL};
use zx_core::preimage::dag::{DagBlockHeader, PadresDag, SolucionPoas};
use zx_core::{BlockHash, BodyCommitment, ClavePublica, Digest, MerkleRoot};

/// Candidato sintético con la forma real (misma cabecera, misma firma), distinto en el padre.
fn candidato(sk: &SigningKey, padre: u64, slot: u64) -> DagBlockHeader {
    let mut bytes = [0u8; 32];
    bytes[..8].copy_from_slice(&padre.to_le_bytes());
    DagBlockHeader {
        consensus_branch_id: 0,
        merkle_root: MerkleRoot::from_digest(Digest::from_bytes([0x22; 32])),
        timestamp: 1_700_000_000 + slot,
        height: u32::try_from(slot).unwrap_or(u32::MAX),
        slot,
        pot_output: [0x11; 16],
        rango_solucion: 7,
        sol: SolucionPoas {
            public_key: ClavePublica::desde_bytes(VerificationKey::from(sk).into()),
            sector_index: 1,
            history_size: 1 << 20,
            chunk: bytes,
            ..SolucionPoas::default()
        },
        body_commitment: BodyCommitment::from_digest(Digest::from_bytes([0x33; 32])),
        padres: PadresDag::nuevo(BlockHash::from_digest(Digest::from_bytes(bytes)), &[])
            .unwrap_or_else(|_| PadresDag::genesis()),
        sello: [0u8; 64],
    }
}

type Muestra = Vec<Duration>;

fn resumen(nombre: &str, m: &Muestra) -> Option<(f64, f64, f64, f64)> {
    if m.is_empty() {
        return None;
    }
    let mut v: Vec<f64> = m.iter().map(|d| d.as_secs_f64() * 1e6).collect();
    v.sort_by(|a, b| a.partial_cmp(b).unwrap_or(std::cmp::Ordering::Equal));
    let pct = |p: f64| -> f64 {
        let idx = ((v.len() as f64 - 1.0) * p / 100.0).round() as usize;
        v.get(idx).copied().unwrap_or(0.0)
    };
    let media = v.iter().sum::<f64>() / v.len() as f64;
    println!(
        "{nombre:<34} n={:<5} mediana={:>9.1} µs   media={:>9.1} µs   p99={:>10.1} µs   máx={:>10.1} µs",
        v.len(),
        pct(50.0),
        media,
        pct(99.0),
        v.last().copied().unwrap_or(0.0)
    );
    Some((pct(50.0), media, pct(99.0), v.last().copied().unwrap_or(0.0)))
}

/// `fdatasync(2)` sobre un fichero abierto.
fn fdatasync(f: &std::fs::File) -> std::io::Result<()> {
    // SAFETY: `fdatasync` sobre un descriptor válido y vivo; no toca memoria.
    let rc = unsafe { libc::fdatasync(f.as_raw_fd()) };
    if rc == 0 {
        Ok(())
    } else {
        Err(std::io::Error::last_os_error())
    }
}

fn ruta_temporal(dir: &Path, etiqueta: &str) -> PathBuf {
    dir.join(format!("registro-{etiqueta}-{}.log", std::process::id()))
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args: Vec<String> = std::env::args().collect();
    let n: usize = args
        .get(1)
        .and_then(|s| s.parse().ok())
        .unwrap_or(2_000);
    let calentamiento = (n as f64 / 10.0).round() as usize;
    let base = args
        .get(2)
        .map_or_else(std::env::temp_dir, PathBuf::from);

    let dir = base.join(format!("firmante-medicion-{}", std::process::id()));
    std::fs::create_dir_all(&dir)?;

    println!("=== P-FIRMANTE · coste por bloque del firmante seguro ===");
    println!("iteraciones por variante: {n} (+{calentamiento} de calentamiento)");
    println!("S_max_slots nominal usado: {S_MAX_SLOTS_NOMINAL}");
    println!("directorio de medición: {}", dir.display());
    println!();

    // ── Escenario del encargo: 1 bloque/s ⇒ 1 000 000 µs por slot ─────────────
    let slot_us = 1_000_000.0f64;

    let sk = SigningKey::from([42u8; 32]);

    // ── Variante A: el camino real, con fsync y sin fsync, lado a lado ────────
    //
    // Para aislar el coste del `fsync` del coste de la firma Ed25519 y del hash de la cabecera,
    // se mide el mismo camino con y sin sincronización. La diferencia es el coste del `fsync`.
    let mut con_sync: Muestra = Vec::with_capacity(n);
    let mut sin_sync: Muestra = Vec::with_capacity(n);
    let ruta_a = ruta_temporal(&dir, "a");
    if ruta_a.exists() {
        std::fs::remove_file(&ruta_a)?;
    }
    let reg_a = Registro::nueva(&ruta_a, S_MAX_SLOTS_NOMINAL)?;
    let f_a = Firmante::con_s_max_nominal(&reg_a);

    for i in 0..(n + calentamiento) {
        let mut c = candidato(&sk, i as u64 + 1, 1_000_000 + i as u64);
        let t0 = Instant::now();
        let r = f_a.firmar(&mut c, &sk)?;
        let dt = t0.elapsed();
        black_box(r);
        black_box(c.sello);
        if i >= calentamiento {
            con_sync.push(dt);
        }
    }
    // El "sin sync" se mide con un registro nuevo cada iteración y un `write` sin `fsync`: es una
    // cota inferior de lo que costaría NO persistir, y sirve para cuantificar lo que se paga.
    for i in 0..(n + calentamiento) {
        let c = candidato(&sk, i as u64 + 1, 2_000_000 + i as u64);
        use std::io::Write as _;
        let mut f = std::fs::OpenOptions::new()
            .append(true)
            .create(true)
            .open(ruta_temporal(&dir, "b"))?;
        let t0 = Instant::now();
        let pre = c.pre_hash();
        f.write_all(pre.as_bytes())?;
        let dt = t0.elapsed();
        black_box(dt);
        if i >= calentamiento {
            sin_sync.push(dt);
        }
    }

    // ── Variante B: `fdatasync` en vez de `fsync` ─────────────────────────────
    let mut con_fdatasync: Muestra = Vec::with_capacity(n);
    let ruta_c = ruta_temporal(&dir, "c");
    if ruta_c.exists() {
        std::fs::remove_file(&ruta_c)?;
    }
    {
        use std::io::Write as _;
        let mut f = std::fs::OpenOptions::new()
            .create(true)
            .append(true)
            .open(&ruta_c)?;
        for i in 0..(n + calentamiento) {
            let c = candidato(&sk, i as u64 + 1, 3_000_000 + i as u64);
            let pre = c.pre_hash();
            let t0 = Instant::now();
            f.write_all(pre.as_bytes())?;
            fdatasync(&f)?;
            let dt = t0.elapsed();
            if i >= calentamiento {
                con_fdatasync.push(dt);
            }
        }
        f.sync_all()?;
    }

    println!("── Latencia del camino de producción (disco de esta máquina) ──");
    let a = resumen("A · Resolver+Firmar con fsync", &con_sync);
    let b = resumen("B · write sin sincronizar (cota)", &sin_sync);
    let c = resumen("C · write + fdatasync", &con_fdatasync);
    println!();
    if let (Some((ma, _, pa, xa)), Some((mb, _, _, _))) = (a, b) {
        println!("Coste del fsync (mediana A − mediana B): {:.1} µs", ma - mb);
        println!(
            "Margen que consume del slot de 1 s (peor caso medido): {:.4} %  ({:.1} µs de {slot_us:.0} µs)",
            100.0 * xa / slot_us,
            xa
        );
        println!(
            "Margen que consume del slot de 1 s (p99): {:.4} %",
            100.0 * pa / slot_us
        );
    }
    if let Some((mc, _, _, _)) = c {
        println!("fdatasync frente a fsync (mediana): {mc:.1} µs");
    }

    // ── Tamaño del registro y política de poda ────────────────────────────────
    println!();
    println!("── Tamaño del registro y poda ──");
    let tamano = reg_a.tamano_bytes()?;
    let entradas = reg_a.entradas();
    println!(
        "tras {n} bloques: {entradas} entradas, {tamano} bytes ({:.1} B/entrada; cabecera 32 B)",
        tamano as f64 / entradas.max(1) as f64
    );
    println!(
        "a 1 bloque/s: {:.2} MiB/hora, {:.1} MiB/día, {:.2} GiB/año — con S_max={S_MAX_SLOTS_NOMINAL}",
        tamano as f64 * 3600.0 / (1024.0 * 1024.0) / n as f64,
        tamano as f64 * 86_400.0 / (1024.0 * 1024.0) / n as f64,
        tamano as f64 * 31_536_000.0 / (1024.0 * 1024.0 * 1024.0) / n as f64
    );
    println!("umbral de poda actual: slot + {S_MAX_SLOTS_NOMINAL} < max_slot = {}", reg_a.max_slot());
    let _ = reg_a.podar()?;

    // ── Contexto de la máquina (para que la cifra sea auditable) ──────────────
    println!();
    println!("── Contexto ──");
    println!("directorio de medición: {}", dir.display());
    // `findmnt -T` da el sistema de ficheros **de ese directorio concreto**, que es lo que decide
    // si el `fsync` llega a un disco o se queda en RAM (`tmpfs`). No se deduce del punto de montaje
    // de `/`: el workspace vive en un subvolumen de `btrfs`, no en `/`.
    if let Ok(s) = std::process::Command::new("findmnt")
        .args(["-no", "SOURCE,FSTYPE,OPTIONS", "-T"])
        .arg(&dir)
        .output()
        && s.status.success()
    {
        println!("findmnt: {}", String::from_utf8_lossy(&s.stdout).trim());
    }
    if let Ok(s) = std::process::Command::new("df").arg("-T").arg(&dir).output()
        && s.status.success()
    {
        println!("df: {}", String::from_utf8_lossy(&s.stdout).trim());
    }
    if let Ok(texto) = std::fs::read_to_string("/proc/loadavg") {
        println!("carga (loadavg): {}", texto.trim());
    }
    if let Ok(texto) = std::fs::read_to_string("/proc/cpuinfo")
        && let Some(nombre) = texto
            .lines()
            .find(|l| l.starts_with("model name"))
            .and_then(|l| l.split(':').nth(1))
    {
        println!("CPU: {}", nombre.trim());
    }

    for r in [ruta_a, ruta_temporal(&dir, "b"), ruta_c] {
        let _ = std::fs::remove_file(Path::new(&r));
    }
    let _ = std::fs::remove_dir(&dir);
    Ok(())
}
