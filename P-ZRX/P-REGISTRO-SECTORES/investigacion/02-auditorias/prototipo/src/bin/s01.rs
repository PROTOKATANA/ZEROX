//! Driver de S01: plotea un sector real, calcula R1/R2, encuentra soluciones ganadoras, las
//! verifica con el verificador PoAS real, abre contra R2 y ejecuta los negativos y las mediciones.
//!
//! Uso: `s01 <pieces_in_sector> <slots_max> <directorio_resultados>`.
//!
//! No se usa Python en ningún punto.

use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use std::time::Instant;

use prototipo_s01::r2::{
    Apertura, CamposPublicos, CompromisoR2, ErrorApertura, compromiso_r2, compromiso_r2_con_version,
    verificar_apertura,
};
use prototipo_s01::registro::{ErrorRegistro, RegistroSectores};
use prototipo_s01::sector::{Entorno, ParametrosPlot, Sector};
use subspace_core_primitives::solutions::Solution;

/// Salida de PoT de fixture para el barrido (valor de test, no de red): la misma del antiguo
/// `farmer_disco.rs` (`SALIDA_D2 = [13u8; 16]`).
const SALIDA_DEV: [u8; 16] = [13u8; 16];

/// Rango de test: `u64::MAX`, el del `farmer_disco.rs` antiguo. No es parámetro de red.
const RANGO_PRUEBA: u64 = u64::MAX;

fn hex32(b: &[u8; 32]) -> String {
    hex::encode(b)
}

fn leer_vmhwm_kib() -> u64 {
    let texto = fs::read_to_string("/proc/self/status").unwrap_or_default();
    for linea in texto.lines() {
        if let Some(resto) = linea.strip_prefix("VmHWM:") {
            let n: u64 = resto
                .trim()
                .split_whitespace()
                .next()
                .and_then(|s| s.parse().ok())
                .unwrap_or(0);
            return n;
        }
    }
    0
}

struct Salida {
    lineas: Vec<(String, String)>,
}

impl Salida {
    fn new() -> Self {
        Self { lineas: Vec::new() }
    }
    fn push(&mut self, clave: &str, valor: impl ToString) {
        self.lineas.push((clave.to_string(), valor.to_string()));
    }
    fn escribir(&self, ruta: &Path) -> std::io::Result<()> {
        let mut texto = String::new();
        for (k, v) in &self.lineas {
            texto.push_str(k);
            texto.push('\t');
            texto.push_str(v);
            texto.push('\n');
        }
        fs::write(ruta, texto)
    }
}

/// Ejecuta `verificar_apertura` y devuelve el error legible si lo hay.
fn resultado_apertura(
    r2: &CompromisoR2,
    ap: &Apertura,
    sol: &Solution<()>,
    s_bucket: u16,
    campos: &CamposPublicos,
) -> Result<(), ErrorApertura> {
    verificar_apertura(r2, ap, sol, s_bucket, campos)
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args: Vec<String> = env::args().collect();
    let piezas: u16 = args.get(1).and_then(|s| s.parse().ok()).unwrap_or(2);
    let slots_max: u64 = args.get(2).and_then(|s| s.parse().ok()).unwrap_or(64);
    let outdir = PathBuf::from(args.get(3).cloned().unwrap_or_else(|| ".".into()));
    fs::create_dir_all(&outdir)?;

    let mut res = Salida::new();
    res.push("piezas_in_sector", piezas);
    res.push("slots_max", slots_max);
    res.push("salida_dev", hex::encode(SALIDA_DEV));
    res.push("rango", RANGO_PRUEBA);

    // 1. Entorno dev (historia archivada + KZG + erasure coding).
    let t = Instant::now();
    let entorno = Entorno::construir_dev()?;
    res.push("t_entorno_s", format!("{:.6}", t.elapsed().as_secs_f64()));
    res.push(
        "segment_commitment",
        hex::encode(entorno.segment_commitment().as_ref()),
    );

    // 2. Ploteo real y construcción del objeto comprometible (R2), medidos por separado.
    let p = ParametrosPlot {
        pieces_in_sector: piezas,
        ..ParametrosPlot::default()
    };
    let t = Instant::now();
    let (bytes, plotted) = entorno.plotear_crudo(&p)?;
    let t_plot = t.elapsed();
    let longitud_sector = bytes.len();
    let t = Instant::now();
    let sector = Sector::construir(bytes, plotted, p.public_key, p.slot_alta)?;
    let t_r2 = t.elapsed();
    let ram_kib = leer_vmhwm_kib();

    res.push("t_plot_s", format!("{:.6}", t_plot.as_secs_f64()));
    res.push("t_r2_s", format!("{:.6}", t_r2.as_secs_f64()));
    res.push("ram_vmhwm_kib", ram_kib);
    res.push("sector_bytes", longitud_sector);
    res.push("n_hojas", sector.campos.n);
    res.push("hojas_rellenadas", sector.arbol.hojas_rellenadas());
    let (mapa_sz, chunks_sz, meta_sz) = sector.tamanos_regiones();
    res.push("region_mapa_bytes", mapa_sz);
    res.push("region_chunks_bytes", chunks_sz);
    res.push("region_meta_bytes", meta_sz);

    let r1 = sector.r1();
    let r2 = sector.r2();
    res.push("r1_hex", hex32(&r1.0));
    res.push("r2_hex", hex32(&r2.0));
    res.push("r1_bytes", 32);
    res.push("r2_bytes", 32);
    res.push("digest_mapa_hex", hex32(&sector.digest_mapa));
    res.push("digest_meta_hex", hex32(&sector.digest_meta));
    res.push("raiz_chunks_hex", hex32(&sector.arbol.raiz()));

    // 3. Volcado binario para el oráculo Julia.
    let ruta_dump = outdir.join(format!("sector-P{piezas}.dump"));
    sector.escribir_volcado(&ruta_dump)?;
    res.push("dump", ruta_dump.display().to_string());

    // 4. Buscar soluciones ganadoras reales y verificarlas con el verificador PoAS real.
    let mut soluciones: Vec<(u64, u16, Solution<()>, u64)> = Vec::new();
    let mut slots_hallados: Vec<u64> = Vec::new();
    let mut barridos = 0u64;
    let t_busqueda = Instant::now();
    'busqueda: for slot in 0..slots_max {
        barridos += 1;
        let candidatas = entorno.soluciones_slot(&sector, SALIDA_DEV, slot, RANGO_PRUEBA)?;
        let mut en_este_slot = 0usize;
        for sol in candidatas {
            let distancia =
                entorno.verificar_solucion(&sol, &p, SALIDA_DEV, slot, RANGO_PRUEBA)?;
            let s_bucket = entorno.s_bucket_auditado(&sector, SALIDA_DEV, slot);
            soluciones.push((slot, s_bucket, sol, distancia));
            en_este_slot += 1;
        }
        if en_este_slot > 0 {
            slots_hallados.push(slot);
        }
        if slots_hallados.len() >= 3 {
            break 'busqueda;
        }
    }
    res.push("t_busqueda_s", format!("{:.6}", t_busqueda.elapsed().as_secs_f64()));
    res.push("slots_barridos", barridos);
    res.push("soluciones_verificadas", soluciones.len());
    res.push("slots_con_solucion", slots_hallados.len());

    if soluciones.is_empty() {
        res.push("veredicto_parcial", "sin_soluciones");
        res.escribir(&outdir.join(format!("resumen-P{piezas}.tsv")))?;
        eprintln!(
            "[S01] P{piezas}: no se encontró ninguna solución en {barridos} slots; se para y se informa."
        );
        return Ok(());
    }

    // 5. Positivos: apertura válida de >= 3 soluciones en slots distintos.
    let mut positivos: Vec<(String, String)> = Vec::new();
    let mut primera_apertura: Option<(Apertura, CamposPublicos, u16, u64)> = None;
    let mut usados_slots: Vec<u64> = Vec::new();
    for (slot, s_bucket, sol, distancia) in &soluciones {
        if usados_slots.contains(slot) {
            continue;
        }
        usados_slots.push(*slot);
        let ap = sector.apertura(sol, *s_bucket)?;
        let r = resultado_apertura(&r2, &ap, sol, *s_bucket, &sector.campos);
        positivos.push((
            format!("slot_{slot}_s_bucket_{s_bucket}"),
            match r {
                Ok(()) => "OK".to_string(),
                Err(e) => format!("RECHAZADA:{e}"),
            },
        ));
        positivos.push((format!("slot_{slot}_distancia"), distancia.to_string()));
        positivos.push((
            format!("slot_{slot}_chunk_location"),
            ap.chunk_location.to_string(),
        ));
        positivos.push((format!("slot_{slot}_camino_len"), ap.camino.len().to_string()));
        if primera_apertura.is_none() {
            primera_apertura = Some((ap, sector.campos, *s_bucket, *slot));
        }
        if usados_slots.len() >= 3 {
            break;
        }
    }
    res.push("positivos_slots_distintos", usados_slots.len());
    let ruta_pos = outdir.join(format!("positivos-P{piezas}.tsv"));
    let mut texto = String::new();
    for (k, v) in &positivos {
        texto.push_str(k);
        texto.push('\t');
        texto.push_str(v);
        texto.push('\n');
    }
    fs::write(&ruta_pos, texto)?;

    let (ap0, campos0, sb0, slot0) = primera_apertura.expect("hay al menos una solución; qed");
    let (_, _, sol0, _) = soluciones
        .iter()
        .find(|(s, sb, _, _)| *s == slot0 && *sb == sb0)
        .expect("la primera apertura viene de una solución listada; qed");

    // Tamaño de la apertura byte a byte.
    let bytes_apertura = 4 + ap0.camino.len() * 32 + 1 + 32 + 32 + 32 + 2 + 2;
    res.push("apertura_bytes", bytes_apertura);
    res.push("apertura_camino_len", ap0.camino.len());

    // 5b. Segundo sector REAL (índice distinto) para el negativo «R2 de otro sector».
    let p2 = ParametrosPlot {
        sector_index: p.sector_index.wrapping_add(1),
        ..p
    };
    let (bytes2, plotted2) = entorno.plotear_crudo(&p2)?;
    let sector2 = Sector::construir(bytes2, plotted2, p2.public_key, p2.slot_alta)?;
    let r2_sector2 = sector2.r2();
    res.push("r2_sector2_hex", hex32(&r2_sector2.0));
    res.push("sector2_index", p2.sector_index);

    // 6. Negativos: cada uno con su error.
    let mut negativos: Vec<(String, String, String)> = Vec::new();
    let mut comprobar = |nombre: &str, esperado: &str, r: Result<(), ErrorApertura>| {
        let observado = match r {
            Ok(()) => "ACEPTADA(!!)".to_string(),
            Err(e) => format!("{e:?}"),
        };
        negativos.push((nombre.to_string(), esperado.to_string(), observado));
    };

    {
        let mut c = campos0;
        c.public_key[0] ^= 1;
        comprobar(
            "clave_publica_cambiada",
            "ClaveDistinta",
            resultado_apertura(&r2, &ap0, sol0, sb0, &c),
        );
    }
    {
        let mut c = campos0;
        c.sector_index = c.sector_index.wrapping_add(1);
        comprobar(
            "sector_index_cambiado",
            "SectorDistinto",
            resultado_apertura(&r2, &ap0, sol0, sb0, &c),
        );
    }
    {
        let mut c = campos0;
        c.history_size = c.history_size.wrapping_add(1);
        comprobar(
            "history_size_cambiado",
            "HistoriaDistinta",
            resultado_apertura(&r2, &ap0, sol0, sb0, &c),
        );
    }
    {
        let r2_v2 = compromiso_r2_con_version(
            2,
            &campos0,
            &ap0.digest_mapa,
            &ap0.digest_meta,
            &ap0.raiz_chunks,
        );
        comprobar(
            "version_cambiada",
            "R2NoCoincide",
            resultado_apertura(&r2_v2, &ap0, sol0, sb0, &campos0),
        );
    }
    {
        let mut c = campos0;
        c.cbid ^= 1;
        comprobar(
            "cbid_cambiado",
            "R2NoCoincide",
            resultado_apertura(&r2, &ap0, sol0, sb0, &c),
        );
    }
    {
        let mut ap = ap0.clone();
        ap.piece_offset ^= 1;
        comprobar(
            "hoja_otro_piece_offset",
            "PieceOffsetDistinto",
            resultado_apertura(&r2, &ap, sol0, sb0, &campos0),
        );
    }
    {
        let sb_malo = sb0 ^ 1;
        comprobar(
            "hoja_otro_s_bucket",
            "SBucketDistinto",
            resultado_apertura(&r2, &ap0, sol0, sb_malo, &campos0),
        );
    }
    {
        let mut ap = ap0.clone();
        ap.codificado = 0;
        comprobar(
            "codificado_cero",
            "CodificadoNoUno",
            resultado_apertura(&r2, &ap, sol0, sb0, &campos0),
        );
    }
    {
        let mut ap = ap0.clone();
        ap.chunk_location = (ap.chunk_location + 1) % campos0.n;
        comprobar(
            "camino_de_otra_posicion",
            "CaminoNoCoincide",
            resultado_apertura(&r2, &ap, sol0, sb0, &campos0),
        );
    }
    {
        let mut ap = ap0.clone();
        ap.camino[0][0] ^= 1;
        comprobar(
            "camino_de_otra_hoja",
            "CaminoNoCoincide",
            resultado_apertura(&r2, &ap, sol0, sb0, &campos0),
        );
    }
    {
        // R2 de un segundo sector REAL ploteado (índice `sector_index+1`).
        comprobar(
            "raiz_de_otro_sector",
            "R2NoCoincide",
            resultado_apertura(&r2_sector2, &ap0, sol0, sb0, &campos0),
        );
    }
    {
        let r2_raiz_ajena = compromiso_r2(&campos0, &ap0.digest_mapa, &ap0.digest_meta, &[0u8; 32]);
        comprobar(
            "raiz_ajena",
            "R2NoCoincide",
            resultado_apertura(&r2_raiz_ajena, &ap0, sol0, sb0, &campos0),
        );
    }
    {
        let mut ap = ap0.clone();
        ap.digest_mapa[0] ^= 1;
        comprobar(
            "digest_mapa_ajeno",
            "R2NoCoincide",
            resultado_apertura(&r2, &ap, sol0, sb0, &campos0),
        );
    }

    // Registro abstracto: duplicado y caducado.
    {
        let mut reg = RegistroSectores::nuevo(10);
        let _ = reg.alta(&campos0, r2, 100, 100);
        let dup = reg.alta(&campos0, r2, 100, 100);
        negativos.push((
            "alta_duplicada".to_string(),
            "Duplicado".to_string(),
            match dup {
                Err(ErrorRegistro::Duplicado { .. }) => "Duplicado".to_string(),
                Ok(()) => "ACEPTADA(!!)".to_string(),
                Err(e) => format!("{e:?}"),
            },
        ));
        let mut reg2 = RegistroSectores::nuevo(10);
        let cad = reg2.alta(&campos0, r2, 100, 111);
        negativos.push((
            "alta_caducada".to_string(),
            "Caducado".to_string(),
            match cad {
                Err(ErrorRegistro::Caducado { .. }) => "Caducado".to_string(),
                Ok(()) => "ACEPTADA(!!)".to_string(),
                Err(e) => format!("{e:?}"),
            },
        ));
    }

    let ruta_neg = outdir.join(format!("negativos-P{piezas}.tsv"));
    let mut texto = String::new();
    for (n, e, o) in &negativos {
        texto.push_str(&format!("{n}\t{e}\t{o}\n"));
    }
    fs::write(&ruta_neg, texto)?;
    let rechazados = negativos
        .iter()
        .filter(|(_, esperado, observado)| observado.starts_with(esperado.as_str()))
        .count();
    res.push("negativos_total", negativos.len());
    res.push("negativos_rechazados_como_esperado", rechazados);

    // 7. Medición: mediana de >= 1000 verificaciones de apertura tras calentar.
    for _ in 0..100 {
        let _ = verificar_apertura(&r2, &ap0, sol0, sb0, &campos0);
    }
    let mut tiempos: Vec<u128> = Vec::with_capacity(1000);
    for _ in 0..1000 {
        let t = Instant::now();
        let _ = verificar_apertura(&r2, &ap0, sol0, sb0, &campos0);
        tiempos.push(t.elapsed().as_nanos());
    }
    tiempos.sort_unstable();
    let mediana = tiempos[tiempos.len() / 2];
    let minimo = tiempos[0];
    let maximo = tiempos[tiempos.len() - 1];
    res.push("verif_apertura_mediana_ns", mediana);
    res.push("verif_apertura_min_ns", minimo);
    res.push("verif_apertura_max_ns", maximo);
    res.push("verif_apertura_n", 1000);

    // Tiempo del verificador PoAS REAL para la misma solución (mediana de 100 tras calentar).
    for _ in 0..10 {
        let _ = entorno.verificar_solucion(sol0, &p, SALIDA_DEV, slot0, RANGO_PRUEBA);
    }
    let mut tiempos_poas: Vec<u128> = Vec::with_capacity(100);
    for _ in 0..100 {
        let t = Instant::now();
        let _ = entorno.verificar_solucion(sol0, &p, SALIDA_DEV, slot0, RANGO_PRUEBA);
        tiempos_poas.push(t.elapsed().as_nanos());
    }
    tiempos_poas.sort_unstable();
    res.push("verif_poas_real_mediana_ns", tiempos_poas[tiempos_poas.len() / 2]);
    res.push("verif_poas_real_n", 100);

    // R0: sin registro ni apertura.
    res.push("r0_bytes", 0);
    res.push("r0_verificacion_ns", 0);

    // Resultado de verificación PoAS real de la primera solución.
    let distancia = entorno.verificar_solucion(sol0, &p, SALIDA_DEV, slot0, RANGO_PRUEBA)?;
    res.push("poas_verificador_real_distancia", distancia);
    res.push("primera_solucion_slot", slot0);
    res.push("primera_solucion_s_bucket", sb0);

    res.push(
        "veredicto_parcial",
        if rechazados == negativos.len() && usados_slots.len() >= 3 {
            "superada_parcial"
        } else {
            "revisar"
        },
    );

    res.escribir(&outdir.join(format!("resumen-P{piezas}.tsv")))?;
    eprintln!(
        "[S01] P{piezas}: soluciones={} slots={} negativos={}/{} t_plot={:.2}s t_r2={:.2}s",
        soluciones.len(),
        usados_slots.len(),
        rechazados,
        negativos.len(),
        t_plot.as_secs_f64(),
        t_r2.as_secs_f64()
    );
    Ok(())
}
