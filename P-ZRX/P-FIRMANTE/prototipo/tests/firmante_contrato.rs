//! Contrato del firmante seguro: los seis puntos del encargo §3, con tests.
//!
//! # Cómo se prueban los procesos hostiles
//!
//! Los tests `hijo_*` están marcados `#[ignore]` a propósito: **no** son tests normales, son puntos
//! de entrada que el test padre ejecuta en un **proceso hijo** con este mismo binario de test
//! re-ejecutado (`std::env::current_exe()`), la variable `FIRMANTE_PUNTO_DE_ABORTO` puesta y el
//! filtro exacto por nombre. El hijo llama al API pública y llama a `std::process::abort()`
//! —SIGABRT, señal 6—: sin destructores, sin búferes vaciados, sin sincronización adicional. Si el
//! registro sobrevive, sobrevive porque el `fsync` ocurrió antes.
//!
//! Ejecutar los tests normales **no** ejecuta los `hijo_*`. Para verlos todos:
//! `cargo test -- --include-ignored` (los `hijo_*` abortan el proceso y hay que lanzarlos por
//! separado; por eso el padre los invoca uno a uno).

#![expect(clippy::unwrap_used, reason = "los tests fallan con panic por diseño")]
#![expect(clippy::expect_used, reason = "los tests fallan con panic por diseño")]
#![expect(
    clippy::panic,
    reason = "media docena de comprobaciones y los puntos de entrada de los hijos fallan con panic"
)]

use std::path::PathBuf;
use std::process::Command;

use ed25519_zebra::{SigningKey, VerificationKey};
use firmante_seguro::aborto;
use firmante_seguro::{
    Firmante, IdentidadOportunidad, IdentidadTicket, Registro, RegistroError, Resultado,
    S_MAX_SLOTS_NOMINAL,
};
use zx_core::preimage::dag::{DagBlockHeader, PadresDag, SolucionPoas};
use zx_core::{BlockHash, BodyCommitment, ClavePublica, Digest, MerkleRoot};

// ─────────────────────────────────────────────────────────────────────────────
// Utilidades comunes
// ─────────────────────────────────────────────────────────────────────────────

fn sk() -> SigningKey {
    SigningKey::from([42u8; 32])
}

fn clave_publica() -> ClavePublica {
    ClavePublica::desde_bytes(VerificationKey::from(&sk()).into())
}

/// Un candidato distinto por `padre` (y opcionalmente por `chunk`/`slot`). Cambiar el padre cambia
/// el `pre_hash` y **no** cambia la identidad de oportunidad: es exactamente FP1/FP5.
fn candidato(padre: u8, chunk: u8, slot: u64) -> DagBlockHeader {
    DagBlockHeader {
        consensus_branch_id: 0,
        merkle_root: MerkleRoot::from_digest(Digest::from_bytes([0x22; 32])),
        timestamp: 1_700_000_000,
        height: 10,
        slot,
        pot_output: [0x11; 16],
        rango_solucion: 7,
        sol: SolucionPoas {
            public_key: clave_publica(),
            sector_index: 1,
            history_size: 1 << 20,
            chunk: [chunk; 32],
            ..SolucionPoas::default()
        },
        body_commitment: BodyCommitment::from_digest(Digest::from_bytes([0x33; 32])),
        padres: PadresDag::nuevo(
            BlockHash::from_digest(Digest::from_bytes([padre; 32])),
            &[],
        )
        .unwrap(),
        sello: [0u8; 64],
    }
}

fn identidad_de(c: &DagBlockHeader) -> IdentidadTicket {
    Firmante::identidad(c)
}

/// Lanza este mismo binario de test en un proceso hijo, con filtro exacto y el dispositivo de
/// aborto armado.
fn lanzar_hijo(nombre_test: &str, punto: &str, extras: &[(&str, String)]) -> std::process::Output {
    let exe = std::env::current_exe().expect("current_exe");
    let mut cmd = Command::new(exe);
    cmd.arg("--ignored")
        .arg("--exact")
        .arg(nombre_test)
        .arg("--test-threads=1")
        .env(aborto::VAR, punto);
    for (k, v) in extras {
        cmd.env(k, v);
    }
    cmd.output().expect("lanzar el proceso hijo")
}

/// Igual que [`lanzar_hijo`] pero **sin esperar**: devuelve el `JoinHandle` del hilo que espera al
/// hijo, para poder tomar el cerrojo desde el padre mientras el hijo sigue vivo.
fn lanzar_hijo_en_hilo(
    nombre_test: &str,
    punto: &str,
    extras: &[(&str, String)],
) -> std::thread::JoinHandle<std::process::Output> {
    let nombre_test = nombre_test.to_string();
    let punto = punto.to_string();
    let extras: Vec<(String, String)> = extras
        .iter()
        .map(|(k, v)| ((*k).to_string(), v.clone()))
        .collect();
    std::thread::spawn(move || {
        let exe = std::env::current_exe().expect("current_exe");
        let mut cmd = Command::new(exe);
        cmd.arg("--ignored")
            .arg("--exact")
            .arg(&nombre_test)
            .arg("--test-threads=1")
            .env(aborto::VAR, &punto);
        for (k, v) in &extras {
            cmd.env(k, v);
        }
        cmd.output().expect("lanzar el proceso hijo")
    })
}

fn hex_de(bytes: &[u8]) -> String {
    let mut s = String::with_capacity(bytes.len() * 2);
    for b in bytes {
        s.push_str(&format!("{b:02x}"));
    }
    s
}

fn desde_hex_32(hex: &str) -> [u8; 32] {
    assert_eq!(hex.len(), 64, "se esperaban 32 bytes en hex");
    let mut out = [0u8; 32];
    for (i, trozo) in hex.as_bytes().chunks_exact(2).enumerate() {
        let s = std::str::from_utf8(trozo).unwrap();
        if let Some(dst) = out.get_mut(i) {
            *dst = u8::from_str_radix(s, 16).unwrap();
        }
    }
    out
}

fn murio_por_sigabrt(salida: &std::process::Output) -> bool {
    use std::os::unix::process::ExitStatusExt as _;
    salida.status.signal() == Some(libc::SIGABRT)
}

/// Cerrojo que serializa los tests que lanzan procesos hijos.
///
/// **Por qué hace falta, y no es un capricho.** El arnés de `cargo test` corre los tests de un
/// fichero **en paralelo**, y los tests que lanzan hijos comparten el árbol de `target/` y el
/// directorio de trabajo del hijo. Sin serializar, dos de esos tests lanzan a la vez un proceso que
/// re-ejecuta el arnés y el desenlace deja de depender solo del código bajo prueba. Con el cerrojo,
/// cada test de proceso ve exactamente el montaje que declara. Es un artefacto del montaje de la
/// prueba, no del código bajo prueba; el cerrojo vive aquí y solo aquí.
static CERROJO_HIJOS: std::sync::Mutex<()> = std::sync::Mutex::new(());

/// Ciclo abrir-cerrar-reabrir repetido: cada reapertura tiene que poder tomar el cerrojo.
///
/// Es el test que reproduce el fallo intermitente del descriptor heredado: con el `flock`
/// sobreviviendo dentro de un proceso hijo, alguna de las 200 reaperturas falla con
/// [`RegistroError::Bloqueado`] aunque el padre haya cerrado su descriptor. Se veía en ~1 de cada
/// 10 pasadas antes de poner `FD_CLOEXEC`.
#[test]
fn el_ciclo_abrir_cerrar_reabrir_no_deja_el_cerrojo_vivo() {
    let dir = tempfile::tempdir().unwrap();
    for i in 0..200u64 {
        let ruta = dir.path().join(format!("r-{i}.log"));
        {
            let reg = Registro::nueva(&ruta, S_MAX_SLOTS_NOMINAL).unwrap();
            let f = Firmante::con_s_max_nominal(&reg);
            let mut c = candidato(1, 5, 500 + i);
            assert_eq!(f.firmar(&mut c, &sk()).unwrap(), Resultado::Sellado);
        }
        let reg = match Registro::abrir(&ruta, 500 + i, S_MAX_SLOTS_NOMINAL) {
            Ok(reg) => reg,
            Err(e) => {
                diagnostico_bloqueo(&ruta);
                panic!("iteración {i}: {e:?}");
            }
        };
        assert_eq!(reg.entradas(), 1);
    }
}

/// Imprime el inodo del fichero, los descriptores propios que lo tienen abierto y las líneas de
/// `/proc/locks` que corresponden a ese inodo.
fn diagnostico_bloqueo(ruta: &std::path::Path) {
    use std::os::unix::fs::MetadataExt as _;
    let meta = std::fs::metadata(ruta);
    eprintln!("[diag] pid={} ruta={}", std::process::id(), ruta.display());
    if let Ok(m) = &meta {
        eprintln!("[diag] ino={} dev={}:{}", m.ino(), m.dev() >> 8, m.dev() & 0xff);
        let ino = format!("{}", m.ino());
        if let Ok(locks) = std::fs::read_to_string("/proc/locks") {
            for l in locks.lines() {
                if l.split_whitespace().any(|c| c == ino) {
                    eprintln!("[diag] lock: {l}");
                }
            }
        }
    }
    if let Ok(fds) = std::fs::read_dir("/proc/self/fd") {
        for fd in fds.flatten() {
            if let Ok(d) = std::fs::read_link(fd.path())
                && d == ruta
            {
                let info = std::fs::read_to_string(format!("/proc/self/fdinfo/{}", fd.path().display()))
                    .unwrap_or_default();
                eprintln!("[diag] propio {} -> {} :: {}", fd.path().display(), d.display(), info.trim());
            }
        }
    }
}

/// **Diagnóstico**: ¿sobrevive el descriptor del registro a un `fork`+`exec`?
///
/// Se queda como test porque el fallo que descubre no es obvio y la comprobación es barata: el
/// descriptor del registro **MUST NOT** aparecer en el inventario del hijo. La primera versión del
/// registro lo heredaba, y con él el `flock`: el padre cerraba el registro y seguía sin poder
/// reabrirlo porque un hijo lo tenía abierto.
#[test]
fn el_descriptor_del_registro_no_sobrevive_a_un_exec() {
    let _turno = CERROJO_HIJOS.lock().unwrap_or_else(|e| e.into_inner());
    let dir = tempfile::tempdir().unwrap();
    let ruta = dir.path().join("r.log");
    let _reg = Registro::nueva(&ruta, S_MAX_SLOTS_NOMINAL).unwrap();
    let acta = dir.path().join("acta.txt");
    let salida = lanzar_hijo(
        "hijo_inventaria_sus_descriptores",
        "ninguno",
        &[("FIRMANTE_TEST_ACTA", acta.display().to_string())],
    );
    assert!(salida.status.success(), "{:?}", salida.status);
    let inventario = std::fs::read_to_string(&acta).unwrap();
    assert!(
        !inventario.contains("r.log"),
        "el hijo heredó el descriptor del registro; el flock sobreviviría al padre:\n{inventario}"
    );
}

// ─────────────────────────────────────────────────────────────────────────────
// §3.1 y §3.2 — los seis puntos del encargo
// ─────────────────────────────────────────────────────────────────────────────

/// **Punto 5.** Con entrada previa y otro `pre_hash`, no firma.
#[test]
fn caso_5_con_entrada_previa_y_otro_pre_hash_no_firma() {
    let dir = tempfile::tempdir().unwrap();
    let reg = Registro::nueva(dir.path().join("r.log"), S_MAX_SLOTS_NOMINAL).unwrap();
    let f = Firmante::con_s_max_nominal(&reg);

    let mut a = candidato(1, 5, 500);
    assert_eq!(f.firmar(&mut a, &sk()).unwrap(), Resultado::Sellado);
    assert_ne!(a.sello, [0u8; 64]);
    a.verificar_sello().unwrap();

    // Mismo billete, mismo slot, OTRA punta: dos `pre_hash`, y solo uno puede llevar sello.
    let mut b = candidato(2, 5, 500);
    assert_ne!(a.pre_hash(), b.pre_hash());
    assert_eq!(identidad_de(&a).huella(), identidad_de(&b).huella());

    let r = f.firmar(&mut b, &sk()).unwrap();
    assert!(matches!(r, Resultado::AbstenidoPorConflicto { .. }), "{r:?}");
    assert_eq!(b.sello, [0u8; 64]);
}

/// **Punto 4.** Reemitir el mismo bloque funciona: un nodo que se reinicia y republica no queda
/// roto.
#[test]
fn caso_4_reemitir_el_mismo_bloque_funciona() {
    let dir = tempfile::tempdir().unwrap();
    let ruta = dir.path().join("r.log");
    let sello;
    {
        let reg = Registro::nueva(&ruta, S_MAX_SLOTS_NOMINAL).unwrap();
        let f = Firmante::con_s_max_nominal(&reg);
        let mut a = candidato(1, 5, 500);
        assert_eq!(f.firmar(&mut a, &sk()).unwrap(), Resultado::Sellado);
        sello = a.sello;
    }
    // Reinicio: el registro se reabre desde disco y el MISMO bloque se vuelve a emitir.
    let reg = Registro::abrir(&ruta, 500, S_MAX_SLOTS_NOMINAL).unwrap();
    let f = Firmante::con_s_max_nominal(&reg);
    let mut otra_vez = candidato(1, 5, 500);
    assert_eq!(f.firmar(&mut otra_vez, &sk()).unwrap(), Resultado::Reemitido);
    assert_eq!(otra_vez.sello, sello);
    otra_vez.verificar_sello().unwrap();
}

/// **Puntos 3 y 4, con el proceso muerto en medio.** El hijo persiste `pre_hash(B)` para
/// `(identidad, slot)` y aborta **antes** de firmar. Al reiniciar, el registro está: el candidato C
/// con **otro** `pre_hash` y la misma oportunidad se abstiene, y B se puede reemitir.
///
/// Distingue los dos desenlaces: si el registro sobrevivió, C da `AbstenidoPorConflicto`; si el
/// `fsync` no hubiera ocurrido, C daría `Sellado` —el accidente—. La prueba no depende de que el
/// fichero exista o no, sino de **qué decide el firmante** al reiniciar.
#[test]
fn durabilidad_el_proceso_muere_entre_la_escritura_y_la_firma() {
    let _turno = CERROJO_HIJOS.lock().unwrap_or_else(|e| e.into_inner());
    let dir = tempfile::tempdir().unwrap();
    let ruta = dir.path().join("r.log");
    let slot = 900u64;
    let b = candidato(1, 7, slot);
    let ph_b = b.pre_hash();

    let salida = lanzar_hijo(
        "hijo_persiste_y_aborta",
        "tras-persistir",
        &[
            ("FIRMANTE_TEST_RUTA", ruta.display().to_string()),
            ("FIRMANTE_TEST_SLOT", slot.to_string()),
            ("FIRMANTE_TEST_HUELLA", hex_de(&identidad_de(&b).huella())),
            ("FIRMANTE_TEST_PRE_HASH", hex_de(ph_b.as_bytes())),
        ],
    );
    assert!(
        murio_por_sigabrt(&salida),
        "el hijo debe morir por SIGABRT, no salir limpiamente: {:?}\n{}",
        salida.status,
        String::from_utf8_lossy(&salida.stderr)
    );

    // Reinicio: el registro tiene que estar en disco.
    let reg = Registro::abrir(&ruta, slot, S_MAX_SLOTS_NOMINAL).unwrap();
    assert_eq!(reg.entradas(), 1, "la entrada del hijo tiene que sobrevivir");
    let f = Firmante::con_s_max_nominal(&reg);

    // El MISMO bloque se puede reemitir (caso 4)…
    let mut b_otra_vez = candidato(1, 7, slot);
    assert_eq!(f.firmar(&mut b_otra_vez, &sk()).unwrap(), Resultado::Reemitido);

    // …y el candidato contradictorio C NO se firma (caso 5). Aquí es donde se ve el accidente
    // evitado: sin el `fsync` previo, C habría sellado.
    let mut c = candidato(2, 7, slot);
    assert_ne!(c.pre_hash(), ph_b);
    let r = f.firmar(&mut c, &sk()).unwrap();
    assert!(
        matches!(r, Resultado::AbstenidoPorConflicto { .. }),
        "el candidato contradictorio no puede sellar tras el reinicio: {r:?}"
    );
    assert_eq!(c.sello, [0u8; 64]);
}

/// **Control negativo del test anterior.** El mismo montaje, pero el hijo aborta **sin** escribir.
/// El reinicio no encuentra nada y el candidato contradictorio **sí** se firma: demuestra que el
/// test de durabilidad no pasa por casualidad ni por el mero hecho de reiniciar.
#[test]
fn control_negativo_sin_escritura_el_conflicto_no_se_detecta() {
    let _turno = CERROJO_HIJOS.lock().unwrap_or_else(|e| e.into_inner());
    let dir = tempfile::tempdir().unwrap();
    let ruta = dir.path().join("r.log");
    let slot = 900u64;
    let b = candidato(1, 7, slot);

    let salida = lanzar_hijo(
        "hijo_persiste_y_aborta",
        "sin-persistir",
        &[
            ("FIRMANTE_TEST_RUTA", ruta.display().to_string()),
            ("FIRMANTE_TEST_SLOT", slot.to_string()),
            ("FIRMANTE_TEST_HUELLA", hex_de(&identidad_de(&b).huella())),
            ("FIRMANTE_TEST_PRE_HASH", hex_de(b.pre_hash().as_bytes())),
        ],
    );
    assert!(murio_por_sigabrt(&salida), "{:?}", salida.status);

    let reg = Registro::abrir(&ruta, slot, S_MAX_SLOTS_NOMINAL).unwrap();
    assert_eq!(reg.entradas(), 0, "sin escritura no hay entrada");
    let f = Firmante::con_s_max_nominal(&reg);
    let mut c = candidato(2, 7, slot);
    assert_eq!(
        f.firmar(&mut c, &sk()).unwrap(),
        Resultado::Sellado,
        "sin entrada previa el candidato sella: el control negativo es el esperado"
    );
}

/// **Punto 4 (abstención).** Tras perder el registro, la abstención dura **exactamente**
/// `S_max_slots` y no más: no se firma en `slot_perdida + 1 … slot_perdida + S_max`, y sí en
/// `slot_perdida + S_max + 1`.
#[test]
fn la_abstencion_tras_perder_el_registro_dura_exactamente_s_max_slots() {
    let dir = tempfile::tempdir().unwrap();
    let s_max = S_MAX_SLOTS_NOMINAL;
    let slot_perdida = 1_000u64;

    // `abrir` sobre un fichero que no existe: el registro se declara perdido en `slot_perdida`.
    let reg = Registro::abrir(dir.path().join("r.log"), slot_perdida, s_max).unwrap();
    let f = Firmante::con_s_max_nominal(&reg);

    // Los `S_max` slots siguientes: ni uno solo se firma.
    for slot in (slot_perdida + 1)..=(slot_perdida + s_max) {
        let mut c = candidato(1, 9, slot);
        let e = f.firmar(&mut c, &sk()).unwrap_err();
        assert!(
            matches!(
                e,
                firmante_seguro::FirmanteError::Registro(RegistroError::EnAbstinencia {
                    slot_actual,
                    hasta,
                    ..
                }) if slot_actual == slot && hasta == slot_perdida + s_max
            ),
            "slot {slot}: {e:?}"
        );
        assert_eq!(c.sello, [0u8; 64], "slot {slot}: no puede haber sello");
    }

    // El slot siguiente ya se firma: la abstención no compra nada de más.
    let mut c = candidato(1, 9, slot_perdida + s_max + 1);
    assert_eq!(f.firmar(&mut c, &sk()).unwrap(), Resultado::Sellado);
    assert_ne!(c.sello, [0u8; 64]);
    assert!(!reg.en_abstinencia(slot_perdida + s_max + 1));
    // Y no se firmó nada durante la ventana: una sola entrada en el registro.
    assert_eq!(reg.entradas(), 1);
}

/// **Punto 5 (concurrencia).** Ocho hilos que intentan firmar la misma oportunidad a la vez con
/// `pre_hash` distintos: **solo uno** sella.
#[test]
fn concurrencia_dos_hilos_no_firman_los_dos() {
    let dir = tempfile::tempdir().unwrap();
    let reg = Registro::nueva(dir.path().join("r.log"), S_MAX_SLOTS_NOMINAL).unwrap();
    let f = Firmante::con_s_max_nominal(&reg);
    let slot = 2_000u64;

    let mut cabeceras: Vec<DagBlockHeader> = (1u8..=8).map(|p| candidato(p, 3, slot)).collect();
    let huella = identidad_de(cabeceras.first().unwrap()).huella();

    let resultados: Vec<Resultado> = std::thread::scope(|s| {
        let mut handles = Vec::new();
        for c in cabeceras.iter_mut() {
            let f = &f;
            handles.push(s.spawn(move || f.firmar(c, &sk()).unwrap()));
        }
        handles.into_iter().map(|h| h.join().unwrap()).collect()
    });

    for (i, c) in cabeceras.iter().enumerate() {
        assert_eq!(identidad_de(c).huella(), huella, "cabecera {i}");
    }
    let sellados = resultados
        .iter()
        .filter(|r| matches!(r, Resultado::Sellado | Resultado::Reemitido))
        .count();
    let abstenidos = resultados
        .iter()
        .filter(|r| matches!(r, Resultado::AbstenidoPorConflicto { .. }))
        .count();
    assert_eq!(sellados, 1, "exactamente uno sella: {resultados:?}");
    assert_eq!(abstenidos, 7);
    assert_eq!(
        cabeceras.iter().filter(|c| c.sello != [0u8; 64]).count(),
        1
    );
}

/// **Punto 5 (dos procesos).** Un segundo **proceso** sobre el mismo fichero acaba rechazado con
/// [`RegistroError::Bloqueado`]: no hay dos escritores descoordinados. Lo que esto **no** cubre
/// está en el informe.
///
/// El montaje tiene tres piezas, y las tres hacen falta:
///
/// 1. El **hijo** abre el registro primero y se queda dentro.
/// 2. El **padre** toma el cerrojo con un `flock` directo y lo mantiene más de `PLAZO_BLOQUEO`
///    (2 s). Eso distingue un titular permanente —el caso que se prueba— de uno transitorio: si
///    fuera transitorio, el hijo abriría tras reintentar.
/// 3. El padre comprueba en el **acta** que, tras liberar el cerrojo, el mismo hijo ya puede
///    abrir. Es el control positivo: el test no puede pasar por un fallo del montaje.
#[test]
#[expect(unsafe_code, reason = "dos llamadas a flock(2) para montar el caso de dos procesos")]
fn dos_procesos_sobre_el_mismo_fichero_no_se_pisan() {
    use std::os::unix::io::AsRawFd as _;

    let _turno = CERROJO_HIJOS.lock().unwrap_or_else(|e| e.into_inner());
    let dir = tempfile::tempdir().unwrap();
    let ruta = dir.path().join("r.log");
    let acta = dir.path().join("acta.txt");
    let listo = dir.path().join("hijo-dentro");
    std::fs::write(&ruta, b"").unwrap();

    // 1) El hijo abre y avisa con un fichero `listo`, para que el padre sepa que ya está dentro.
    let hijo = lanzar_hijo_en_hilo(
        "hijo_intenta_abrir_y_reporta",
        "ninguno",
        &[
            ("FIRMANTE_TEST_RUTA", ruta.display().to_string()),
            ("FIRMANTE_TEST_ACTA", acta.display().to_string()),
            ("FIRMANTE_TEST_LISTO", listo.display().to_string()),
            ("FIRMANTE_TEST_ESPERA", "1".to_string()),
        ],
    );
    // Espera acotada a que el hijo entre. Se sondea el acta (que el hijo escribe al final) y el
    // fichero `listo` (que escribe justo antes de la segunda fase).
    let inicio = std::time::Instant::now();
    while !listo.exists() && inicio.elapsed() < std::time::Duration::from_secs(5) {
        std::thread::sleep(std::time::Duration::from_millis(5));
    }
    assert!(listo.exists(), "el hijo no llegó a abrir el registro");

    // 2) El padre toma el cerrojo y lo mantiene más allá del plazo de reintento.
    let candado = std::fs::OpenOptions::new()
        .read(true)
        .write(true)
        .open(&ruta)
        .unwrap();
    // SAFETY: `flock` sobre un descriptor válido; el efecto es el estado de bloqueo del fichero.
    let rc = unsafe { libc::flock(candado.as_raw_fd(), libc::LOCK_EX) };
    assert_eq!(rc, 0, "el padre no pudo tomar el cerrojo");
    std::thread::sleep(std::time::Duration::from_millis(2_500));

    // 3) Se libera y el hijo reintenta: ahí sí tiene que abrir.
    // SAFETY: ídem, para liberar el cerrojo del padre.
    let rc = unsafe { libc::flock(candado.as_raw_fd(), libc::LOCK_UN) };
    assert_eq!(rc, 0);
    let salida = hijo.join().unwrap();
    assert!(salida.status.success(), "{:?}", salida.status);
    let texto = std::fs::read_to_string(&acta).unwrap();
    assert!(
        texto.contains("BLOQUEADO") && texto.contains("TRAS-LIBERAR-ABIERTO"),
        "el hijo tenía que verse bloqueado mientras el padre sostenía el cerrojo, y abrir después; dijo: {texto}"
    );
}

/// **Punto 6.** La identidad es un punto de extensión y funciona con dos implementaciones
/// distintas, sin mezclar sus espacios de claves.
#[test]
fn la_identidad_funciona_con_dos_implementaciones() {
    let dir = tempfile::tempdir().unwrap();
    let reg = Registro::nueva(dir.path().join("r.log"), S_MAX_SLOTS_NOMINAL).unwrap();
    let f = Firmante::con_s_max_nominal(&reg);

    let mut a = candidato(1, 4, 300);
    let vigente = identidad_de(&a);
    let con_red = IdentidadTicket::TicketConRed {
        red: [0xCD; 32],
        public_key: a.sol.public_key,
        sector_index: a.sol.sector_index,
        history_size: a.sol.history_size,
        chunk: a.sol.chunk,
        slot: a.slot,
    };
    assert_ne!(vigente.huella(), con_red.huella());

    assert_eq!(f.firmar(&mut a, &sk()).unwrap(), Resultado::Sellado);
    let sello_a = a.sello;

    // La misma tupla bajo IDV-01 es una oportunidad distinta para este registro.
    let mut b = candidato(2, 4, 300);
    assert_eq!(
        f.firmar_con_identidad(&mut b, &con_red, &sk()).unwrap(),
        Resultado::Sellado
    );
    // Y cada implementación sigue recordando lo suyo.
    let mut a_repetido = candidato(1, 4, 300);
    assert_eq!(
        f.firmar_con_identidad(&mut a_repetido, &vigente, &sk()).unwrap(),
        Resultado::Reemitido
    );
    assert_eq!(a_repetido.sello, sello_a);
    let mut c = candidato(3, 4, 300);
    assert!(matches!(
        f.firmar_con_identidad(&mut c, &con_red, &sk()).unwrap(),
        Resultado::AbstenidoPorConflicto { .. }
    ));
}

// ─────────────────────────────────────────────────────────────────────────────
// Hijos: puntos de entrada que el padre re-ejecuta. NO son tests normales.
// ─────────────────────────────────────────────────────────────────────────────

/// Persiste `(huella, slot) -> pre_hash` con el camino real y **aborta sin firmar**. Lo lanza
/// [`durabilidad_el_proceso_muere_entre_la_escritura_y_la_firma`].
///
/// Usa [`Registro::nueva`] a propósito: el punto que se prueba es el que cae entre la persistencia
/// y la emisión del sello **en el camino normal de firma**, no el de un registro perdido. La
/// abstención por pérdida tiene su propio test.
#[test]
#[ignore = "punto de entrada para el proceso hijo; aborta a propósito"]
fn hijo_persiste_y_aborta() {
    let ruta = PathBuf::from(std::env::var("FIRMANTE_TEST_RUTA").expect("ruta"));
    let slot: u64 = std::env::var("FIRMANTE_TEST_SLOT")
        .expect("slot")
        .parse()
        .expect("slot numérico");
    let huella = std::env::var("FIRMANTE_TEST_HUELLA").expect("huella");
    let pre_hash_hex = std::env::var("FIRMANTE_TEST_PRE_HASH").expect("pre_hash");

    let reg = Registro::nueva(&ruta, S_MAX_SLOTS_NOMINAL).expect("abrir el registro del hijo");
    // `IdentidadFija` reproduce exactamente la oportunidad que calculó el padre.
    let identidad = IdentidadFija {
        huella: desde_hex_32(&huella),
        slot,
    };
    let pre_hash = zx_core::PreHash::from_digest(Digest::from_bytes(desde_hex_32(&pre_hash_hex)));

    let _ = aborto::aborto_si_procede(&reg, &identidad, pre_hash);
    // Si el dispositivo no estaba armado, esto es un fallo del montaje.
    panic!("el dispositivo de aborto no se disparó");
}

/// Escribe en `FIRMANTE_TEST_ACTA` el inventario de sus descriptores. Lo usa el diagnóstico de
/// `O_CLOEXEC`.
#[test]
#[ignore = "punto de entrada para el proceso hijo"]
fn hijo_inventaria_sus_descriptores() {
    let acta = PathBuf::from(std::env::var("FIRMANTE_TEST_ACTA").expect("acta"));
    let mut texto = String::new();
    for n in 0..12 {
        let camino = format!("/proc/self/fd/{n}");
        match std::fs::read_link(&camino) {
            Ok(d) => texto.push_str(&format!("fd{n} -> {}\n", d.display())),
            Err(_) => texto.push_str(&format!("fd{n} -> (cerrado)\n")),
        }
    }
    std::fs::write(&acta, texto).unwrap();
}

/// Intenta abrir un registro ya tomado y deja el desenlace en el fichero que indica
/// `FIRMANTE_TEST_ACTA`. Lo lanza [`dos_procesos_sobre_el_mismo_fichero_no_se_pisan`].
///
/// No usa `println!` porque el arnés de tests de Rust **captura** la salida estándar de cada test,
/// y el padre no la vería. Un fichero acta es observable sin depender de eso.
///
/// Con `FIRMANTE_TEST_ESPERA` puesta, hace dos intentos: el primero **mantiene** el registro
/// abierto y avisa con el fichero `FIRMANTE_TEST_LISTO` (el padre toma entonces el cerrojo), y el
/// segundo, tras esperar a que el padre lo suelte, comprueba que el reintento acaba abriendo.
#[test]
#[ignore = "punto de entrada para el proceso hijo"]
fn hijo_intenta_abrir_y_reporta() {
    let ruta = PathBuf::from(std::env::var("FIRMANTE_TEST_RUTA").expect("ruta"));
    let acta = PathBuf::from(std::env::var("FIRMANTE_TEST_ACTA").expect("acta"));
    let mut texto = String::new();

    let primer = match Registro::nueva(&ruta, S_MAX_SLOTS_NOMINAL) {
        Ok(reg) => {
            texto.push_str("ABIERTO\n");
            Some(reg)
        }
        Err(RegistroError::Bloqueado { .. }) => {
            texto.push_str("BLOQUEADO\n");
            None
        }
        Err(otro) => {
            std::fs::write(&acta, format!("OTRO {otro:?}")).unwrap();
            return;
        }
    };

    if std::env::var_os("FIRMANTE_TEST_ESPERA").is_some() {
        if let Some(listo) = std::env::var_os("FIRMANTE_TEST_LISTO") {
            std::fs::write(listo, b"dentro").unwrap();
        }
        // El padre tardará 2,5 s en soltar; aquí se espera 1 s y se comprueba que el registro
        // **sigue** bloqueado pese a los reintentos internos.
        std::thread::sleep(std::time::Duration::from_millis(1_000));
        text_append(&acta, &texto);
        texto.clear();
        match Registro::nueva(&ruta, S_MAX_SLOTS_NOMINAL) {
            Ok(_) => texto.push_str("ABIERTO\n"),
            Err(RegistroError::Bloqueado { .. }) => texto.push_str("BLOQUEADO\n"),
            Err(otro) => texto.push_str(&format!("OTRO {otro:?}\n")),
        }
        text_append(&acta, &texto);
        texto.clear();
        // Se suelta el registro y se da tiempo al padre a liberar su cerrojo.
        drop(primer);
        std::thread::sleep(std::time::Duration::from_millis(2_000));
        match Registro::nueva(&ruta, S_MAX_SLOTS_NOMINAL) {
            Ok(_) => texto.push_str("TRAS-LIBERAR-ABIERTO\n"),
            Err(RegistroError::Bloqueado { .. }) => texto.push_str("TRAS-LIBERAR-BLOQUEADO\n"),
            Err(otro) => texto.push_str(&format!("TRAS-LIBERAR-OTRO {otro:?}\n")),
        }
    }
    text_append(&acta, &texto);
}

/// Añade `texto` al final del acta (append). El hijo escribe en dos tandas.
fn text_append(ruta: &std::path::Path, texto: &str) {
    use std::io::Write as _;
    let mut f = std::fs::OpenOptions::new()
        .create(true)
        .append(true)
        .open(ruta)
        .unwrap();
    f.write_all(texto.as_bytes()).unwrap();
    f.sync_all().unwrap();
}

// ─────────────────────────────────────────────────────────────────────────────
// Apoyo: una identidad construida desde una huella ya calculada.
// ─────────────────────────────────────────────────────────────────────────────

/// Identidad mínima que **fija la huella**: permite al hijo reproducir exactamente la oportunidad
/// que el padre calculó. Vive en los tests, no en el crate: no es una implementación de producción
/// y no aporta nada al punto de extensión (las dos de producción están en `src/identidad.rs`).
#[derive(Debug)]
struct IdentidadFija {
    huella: [u8; 32],
    slot: u64,
}

impl IdentidadOportunidad for IdentidadFija {
    fn huella(&self) -> [u8; 32] {
        self.huella
    }
    fn bytes_canonicos(&self) -> Vec<u8> {
        self.huella.to_vec()
    }
    fn slot(&self) -> u64 {
        self.slot
    }
    fn ttl_slots(&self) -> u64 {
        S_MAX_SLOTS_NOMINAL
    }
}
