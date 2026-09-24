//! Contrato del **alta local del productor dev** (D3): clave nueva, registro limpio, reinicio y
//! fallo cerrado.
//!
//! # Qué prueba y qué no
//!
//! Prueba la **política local de aprovisionamiento**, no la validez de un bloque. Las cabeceras de
//! prueba llevan una solución PoAS *placeholder* (`SolucionPoas::default()`): el firmante no la
//! verifica, solo deriva de ella la identidad de oportunidad de `C-GD-07`; lo que sí se comprueba
//! es que el sello resultante verifica bajo la clave pública (`C-HDR-04`). PoAS real, cuerpo,
//! reloj y admisión siguen fuera de este contrato.
//!
//! # Casos
//!
//! 1. Alta nueva con `slot_actual = 0`, `s_max_slots = 150` ⇒ se firma el `slot 1`, clave de
//!    exactamente 96 B y modo `0600` en Unix.
//! 2. Cerrar y reabrir conserva clave y registro: la misma cabecera reemite y otra con la misma
//!    oportunidad se abstiene con el sello intacto.
//! 3. Borrar **solo** `firmas.log` con la clave presente ⇒ abstención hasta 151 inclusive,
//!    persistente tras otro reinicio, y primera firma en el 152.
//! 4. Clave parcial, checksum alterado y bytes extra fallan cerrado sin crear registro limpio ni
//!    filtrar la semilla.
//! 5. Un segundo alta simultánea sobre el mismo directorio falla por bloqueo.
//! 6. Registro preexistente con clave ausente ⇒ la creación inicial falla sin sobrescribirlo.

#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    reason = "los tests fallan con panic por diseño y manipulan bytes con índices constantes"
)]

use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicU64, Ordering};

use zx_consensus::firmante::alta::{
    ErrorAltaFirmante, IdentidadProductorLocal, NOMBRE_BLOQUEO, NOMBRE_CLAVE, NOMBRE_REGISTRO,
    TAMANO_CLAVE,
};
use zx_consensus::{FirmanteError, RegistroError, Resultado};
use zx_core::preimage::dag::{DagBlockHeader, PadresDag, SolucionPoas};
use zx_core::{BlockHash, BodyCommitment, ClavePublica, Digest, MerkleRoot};

static CONTADOR: AtomicU64 = AtomicU64::new(0);

struct DirTemporal {
    ruta: PathBuf,
}

impl DirTemporal {
    fn nuevo(etiqueta: &str) -> Self {
        let pid = std::process::id();
        let n = CONTADOR.fetch_add(1, Ordering::Relaxed);
        let unico = format!("zx-alta-firmante-{pid}-{n}-{etiqueta}");
        let ruta = std::env::temp_dir().join(unico);
        std::fs::create_dir_all(&ruta).unwrap();
        Self { ruta }
    }

    fn ruta(&self) -> &Path {
        &self.ruta
    }
}

impl Drop for DirTemporal {
    fn drop(&mut self) {
        let _ = std::fs::remove_dir_all(&self.ruta);
    }
}

/// Cabecera de prueba. El PoAS es un *placeholder*: solo aporta los campos de la identidad
/// `C-GD-07` y el `slot`. Cambiar `padre` cambia el `pre_hash` sin cambiar la oportunidad.
fn candidato(clave: ClavePublica, padre: u8, chunk: u8, slot: u64) -> DagBlockHeader {
    DagBlockHeader {
        consensus_branch_id: 0,
        merkle_root: MerkleRoot::from_digest(Digest::from_bytes([0x22; 32])),
        timestamp: 1_700_000_000,
        height: 10,
        slot,
        pot_output: [0x11; 16],
        rango_solucion: 7,
        sol: SolucionPoas {
            public_key: clave,
            sector_index: 1,
            history_size: 1 << 20,
            chunk: [chunk; 32],
            ..SolucionPoas::default()
        },
        body_commitment: BodyCommitment::from_digest(Digest::from_bytes([0x33; 32])),
        padres: PadresDag::nuevo(BlockHash::from_digest(Digest::from_bytes([padre; 32])), &[])
            .unwrap(),
        sello: [0u8; 64],
    }
}

/// **Caso 1.** Alta nueva: `slot 1` firma y la clave mide 96 B con modo `0600` en Unix.
#[test]
fn alta_nueva_firma_el_slot_uno_y_deja_clave_de_96_bytes() {
    let dir = DirTemporal::nuevo("alta-nueva");
    let id = IdentidadProductorLocal::abrir_o_crear(dir.ruta(), 0, 150).unwrap();

    let mut h = candidato(id.public_key(), 1, 5, 1);
    assert_eq!(id.firmar(&mut h).unwrap(), Resultado::Sellado);
    h.verificar_sello().unwrap();
    assert_ne!(h.sello, [0u8; 64]);
    assert_eq!(id.entradas(), 1);
    assert!(!id.en_abstinencia(1), "un alta nueva no se abstiene");
    // Todo el primer hijo `{G}` (`slot = 1..=150`) queda disponible: el alta no se abstiene.
    for slot in 1..=150u64 {
        assert!(
            !id.en_abstinencia(slot),
            "slot {slot} no debe estar en abstención"
        );
    }

    let meta = std::fs::metadata(dir.ruta().join(NOMBRE_CLAVE)).unwrap();
    assert_eq!(meta.len(), TAMANO_CLAVE, "la clave mide exactamente 96 B");
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt as _;
        assert_eq!(
            meta.permissions().mode() & 0o777,
            0o600,
            "la clave es de solo lectura/escritura del dueño"
        );
    }
}

/// **Caso 2.** Reabrir conserva clave y registro; reemitir funciona y el conflicto se abstiene.
#[test]
fn reabrir_conserva_clave_y_registro_y_reemite_o_se_abstiene() {
    let dir = DirTemporal::nuevo("reabrir");
    let clave;
    {
        let id = IdentidadProductorLocal::abrir_o_crear(dir.ruta(), 0, 150).unwrap();
        clave = id.public_key();
        let mut h = candidato(clave, 1, 5, 1);
        assert_eq!(id.firmar(&mut h).unwrap(), Resultado::Sellado);
        h.verificar_sello().unwrap();
    }

    let id = IdentidadProductorLocal::abrir_o_crear(dir.ruta(), 1, 150).unwrap();
    assert_eq!(id.public_key(), clave, "la clave sobrevive al cierre");
    assert_eq!(id.entradas(), 1, "el registro sobrevive al cierre");

    let mut misma = candidato(clave, 1, 5, 1);
    assert_eq!(id.firmar(&mut misma).unwrap(), Resultado::Reemitido);
    misma.verificar_sello().unwrap();

    let mut otra = candidato(clave, 2, 5, 1);
    assert_ne!(otra.pre_hash(), misma.pre_hash());
    assert!(
        matches!(
            id.firmar(&mut otra).unwrap(),
            Resultado::AbstenidoPorConflicto { .. }
        ),
        "otra cabecera con la misma oportunidad no puede sellar"
    );
    assert_eq!(
        otra.sello, [0u8; 64],
        "el candidato descartado no lleva sello"
    );
}

/// **Caso 3.** Pérdida del registro: abstención exacta hasta 151, persistente, y firma en 152.
#[test]
fn perder_el_registro_se_abstiene_hasta_151_y_vuelve_a_firmar_en_152() {
    let dir = DirTemporal::nuevo("perdida");
    let ruta_registro = dir.ruta().join(NOMBRE_REGISTRO);
    let clave;
    {
        let id = IdentidadProductorLocal::abrir_o_crear(dir.ruta(), 0, 150).unwrap();
        clave = id.public_key();
        let mut h = candidato(clave, 1, 5, 1);
        assert_eq!(id.firmar(&mut h).unwrap(), Resultado::Sellado);
    }

    // Borradura SOLO dentro del test: no es una receta de producción.
    std::fs::remove_file(&ruta_registro).unwrap();

    {
        let id = IdentidadProductorLocal::abrir_o_crear(dir.ruta(), 1, 150).unwrap();
        assert_eq!(id.abstener_hasta(), Some(151));
        assert!(id.en_abstinencia(151));
        for slot in 2..=151u64 {
            let mut h = candidato(clave, 1, 5, slot);
            let e = id.firmar(&mut h).unwrap_err();
            assert!(
                matches!(
                    &e,
                    ErrorAltaFirmante::Firmante(FirmanteError::Registro(
                        RegistroError::EnAbstinencia { .. }
                    ))
                ),
                "slot {slot}: {e:?}"
            );
            assert_eq!(h.sello, [0u8; 64]);
        }
    }

    // Otro reinicio: la abstención vive en la cabecera durable y el 152 ya firma.
    let id = IdentidadProductorLocal::abrir_o_crear(dir.ruta(), 1, 150).unwrap();
    assert_eq!(id.abstener_hasta(), Some(151));
    assert!(id.en_abstinencia(151));
    let mut libre = candidato(clave, 1, 5, 152);
    assert_eq!(id.firmar(&mut libre).unwrap(), Resultado::Sellado);
    libre.verificar_sello().unwrap();
    assert_eq!(id.entradas(), 1);
}

/// **Caso 4 (común).** Con la clave corrupta, el alta falla cerrado, no crea registro limpio y no
/// filtra la semilla en el mensaje de error.
fn corromper_y_rechazar(etiqueta: &str, corromper: impl FnOnce(&Path)) {
    let dir = DirTemporal::nuevo(etiqueta);
    let ruta_clave = dir.ruta().join(NOMBRE_CLAVE);
    let ruta_registro = dir.ruta().join(NOMBRE_REGISTRO);
    {
        let id = IdentidadProductorLocal::abrir_o_crear(dir.ruta(), 0, 150).unwrap();
        let mut h = candidato(id.public_key(), 1, 5, 1);
        assert_eq!(id.firmar(&mut h).unwrap(), Resultado::Sellado);
    }

    // Semilla guardada, para comprobar que ningún mensaje la filtra.
    let bytes = std::fs::read(&ruta_clave).unwrap();
    let semilla = bytes[16..48].to_vec();
    // Sin registro: si la clave corrupta creara un registro limpio, se vería.
    std::fs::remove_file(&ruta_registro).unwrap();

    corromper(&ruta_clave);

    let e = IdentidadProductorLocal::abrir_o_crear(dir.ruta(), 1, 150).unwrap_err();
    assert!(
        matches!(&e, ErrorAltaFirmante::ClaveCorrupta { .. }),
        "{etiqueta}: {e:?}"
    );
    assert!(
        !ruta_registro.exists(),
        "{etiqueta}: no debe crearse un registro limpio con una clave corrupta"
    );

    let mensaje = e.to_string();
    let hex: String = semilla.iter().map(|b| format!("{b:02x}")).collect();
    assert!(
        !mensaje.contains(&hex),
        "{etiqueta}: el error filtra la semilla"
    );
    assert!(
        !mensaje.contains(&format!("{semilla:?}")),
        "{etiqueta}: el error filtra la semilla"
    );
}

/// **Caso 4.** Los tres modos de corrupción de `productor.key`.
#[test]
fn clave_parcial_checksum_alterado_y_bytes_extra_fallan_cerrado() {
    corromper_y_rechazar("clave-parcial", |ruta| {
        let bytes = std::fs::read(ruta).unwrap();
        std::fs::write(ruta, &bytes[..50]).unwrap();
    });
    corromper_y_rechazar("clave-checksum", |ruta| {
        let mut bytes = std::fs::read(ruta).unwrap();
        bytes[80] ^= 0x01;
        std::fs::write(ruta, &bytes).unwrap();
    });
    corromper_y_rechazar("clave-extra", |ruta| {
        let mut bytes = std::fs::read(ruta).unwrap();
        bytes.push(0x00);
        std::fs::write(ruta, &bytes).unwrap();
    });
}

/// **Caso 5.** Un segundo alta simultánea sobre el mismo directorio no lee ni escribe.
#[test]
fn segundo_alta_simultanea_sobre_el_mismo_directorio_falla_por_bloqueo() {
    let dir = DirTemporal::nuevo("bloqueo");
    let _primera = IdentidadProductorLocal::abrir_o_crear(dir.ruta(), 0, 150).unwrap();
    let e = IdentidadProductorLocal::abrir_o_crear(dir.ruta(), 1, 150).unwrap_err();
    assert!(
        matches!(&e, ErrorAltaFirmante::BloqueoOcupado { .. }),
        "{e:?}"
    );
}

/// **Caso 6.** Registro preexistente con la clave ausente: la creación inicial falla y no
/// sobrescribe el fichero.
#[test]
fn registro_preexistente_y_clave_ausente_falla_sin_sobrescribir() {
    let dir = DirTemporal::nuevo("registro-previo");
    let ruta_registro = dir.ruta().join(NOMBRE_REGISTRO);
    std::fs::write(&ruta_registro, []).unwrap();
    assert_eq!(std::fs::metadata(&ruta_registro).unwrap().len(), 0);

    let e = IdentidadProductorLocal::abrir_o_crear(dir.ruta(), 0, 150).unwrap_err();
    assert!(
        matches!(&e, ErrorAltaFirmante::Registro(RegistroError::Io { .. })),
        "se esperaba el fallo de `create_new`, llegó {e:?}"
    );
    assert_eq!(
        std::fs::metadata(&ruta_registro).unwrap().len(),
        0,
        "el registro preexistente no se sobrescribe"
    );
    // La secuencia exige escribir la clave antes de crear el registro, así que la clave queda.
    assert!(dir.ruta().join(NOMBRE_CLAVE).exists());
}

// ─────────────────────────────────────────────────────────────────────────
// Frontera local del secreto: enlaces simbólicos y permisos de la clave
// ─────────────────────────────────────────────────────────────────────────

/// Fichero regular fuera del directorio de alta, con limpieza propia.
struct ArchivoExterno {
    ruta: PathBuf,
}

impl ArchivoExterno {
    fn nuevo(etiqueta: &str) -> Self {
        let pid = std::process::id();
        let n = CONTADOR.fetch_add(1, Ordering::Relaxed);
        let unico = format!("zx-alta-externo-{pid}-{n}-{etiqueta}");
        let ruta = std::env::temp_dir().join(unico);
        Self { ruta }
    }

    fn ruta(&self) -> &Path {
        &self.ruta
    }
}

impl Drop for ArchivoExterno {
    fn drop(&mut self) {
        let _ = std::fs::remove_file(&self.ruta);
    }
}

/// Crea un enlace simbólico a `objetivo`, exista o no.
#[cfg(unix)]
fn enlazar_simbolico(objetivo: &Path, enlace: &Path) {
    std::os::unix::fs::symlink(objetivo, enlace).unwrap();
}

/// **Caso 7 (Unix).** Una clave existente legible por grupo/otros falla por permisos antes de leer
/// la semilla y de recrear el registro.
#[cfg(unix)]
#[test]
fn clave_con_permisos_para_grupo_u_otros_falla_antes_de_recrear_el_registro() {
    use std::os::unix::fs::PermissionsExt as _;

    let dir = DirTemporal::nuevo("permisos-clave");
    let ruta_clave = dir.ruta().join(NOMBRE_CLAVE);
    let ruta_registro = dir.ruta().join(NOMBRE_REGISTRO);
    {
        let _id = IdentidadProductorLocal::abrir_o_crear(dir.ruta(), 0, 150).unwrap();
    }
    // Se borra SOLO el registro: si la comprobación de permisos no cortara antes, se recrearía.
    std::fs::remove_file(&ruta_registro).unwrap();
    std::fs::set_permissions(&ruta_clave, std::fs::Permissions::from_mode(0o644)).unwrap();

    let e = IdentidadProductorLocal::abrir_o_crear(dir.ruta(), 1, 150).unwrap_err();
    assert!(
        matches!(&e, ErrorAltaFirmante::ClaveCorrupta { .. }),
        "se esperaba el rechazo por permisos, llegó {e:?}"
    );
    assert!(
        !ruta_registro.exists(),
        "el registro no debe recrearse antes de comprobar los permisos"
    );

    // Restaurar el modo para que la limpieza no dependa de él.
    std::fs::set_permissions(&ruta_clave, std::fs::Permissions::from_mode(0o600)).unwrap();
}

/// **Caso 8 (Unix).** `productor.key` como enlace simbólico se rechaza antes de tocar el registro.
#[cfg(unix)]
#[test]
fn clave_como_enlace_simbolico_falla_sin_abrir_el_registro() {
    let dir = DirTemporal::nuevo("clave-symlink");
    let ruta_clave = dir.ruta().join(NOMBRE_CLAVE);
    let ruta_registro = dir.ruta().join(NOMBRE_REGISTRO);

    let externo = ArchivoExterno::nuevo("clave-destino");
    {
        let _id = IdentidadProductorLocal::abrir_o_crear(dir.ruta(), 0, 150).unwrap();
    }
    // La clave real se mueve fuera y en su sitio queda un enlace simbólico.
    std::fs::rename(&ruta_clave, externo.ruta()).unwrap();
    enlazar_simbolico(externo.ruta(), &ruta_clave);
    std::fs::remove_file(&ruta_registro).unwrap();

    let e = IdentidadProductorLocal::abrir_o_crear(dir.ruta(), 1, 150).unwrap_err();
    assert!(
        e.to_string().contains("enlace simbólico"),
        "el rechazo debe nombrar el enlace simbólico: {e:?}"
    );
    assert!(
        !ruta_registro.exists(),
        "no debe crearse el registro tras rechazar la clave"
    );
}

/// **Caso 9 (Unix).** `alta.lock` como enlace simbólico se rechaza sin crear el destino externo.
#[cfg(unix)]
#[test]
fn bloqueo_como_enlace_simbolico_falla_sin_crear_el_destino() {
    let dir = DirTemporal::nuevo("bloqueo-symlink");
    let ruta_bloqueo = dir.ruta().join(NOMBRE_BLOQUEO);
    let externo = ArchivoExterno::nuevo("bloqueo-destino");
    enlazar_simbolico(externo.ruta(), &ruta_bloqueo);

    let e = IdentidadProductorLocal::abrir_o_crear(dir.ruta(), 0, 150).unwrap_err();
    assert!(
        e.to_string().contains("enlace simbólico"),
        "el rechazo debe nombrar el enlace simbólico: {e:?}"
    );
    assert!(
        !externo.ruta().exists(),
        "el destino externo del cerrojo no debe crearse"
    );
}

/// **Caso 10 (Unix).** `firmas.log` como enlace simbólico con clave existente se rechaza sin crear
/// el destino externo.
#[cfg(unix)]
#[test]
fn registro_como_enlace_simbolico_falla_sin_crear_el_destino() {
    let dir = DirTemporal::nuevo("registro-symlink");
    let ruta_registro = dir.ruta().join(NOMBRE_REGISTRO);
    let externo = ArchivoExterno::nuevo("registro-destino");
    {
        let _id = IdentidadProductorLocal::abrir_o_crear(dir.ruta(), 0, 150).unwrap();
    }
    std::fs::remove_file(&ruta_registro).unwrap();
    enlazar_simbolico(externo.ruta(), &ruta_registro);

    let e = IdentidadProductorLocal::abrir_o_crear(dir.ruta(), 1, 150).unwrap_err();
    assert!(
        e.to_string().contains("enlace simbólico"),
        "el rechazo debe nombrar el enlace simbólico: {e:?}"
    );
    assert!(
        !externo.ruta().exists(),
        "el destino externo del registro no debe crearse"
    );
}

/// **Caso 11 (Unix).** Un directorio de alta que es un enlace simbólico se rechaza como
/// `DirectorioInvalido`, sin crear ninguna ruta en su destino.
#[cfg(unix)]
#[test]
fn directorio_de_alta_como_enlace_simbolico_se_rechaza() {
    let real = DirTemporal::nuevo("dir-real");
    let enlace = std::env::temp_dir().join(format!(
        "zx-alta-dir-symlink-{}-{}",
        std::process::id(),
        CONTADOR.fetch_add(1, Ordering::Relaxed)
    ));
    enlazar_simbolico(real.ruta(), &enlace);

    let e = IdentidadProductorLocal::abrir_o_crear(&enlace, 0, 150).unwrap_err();
    assert!(
        matches!(&e, ErrorAltaFirmante::DirectorioInvalido { .. }),
        "se esperaba DirectorioInvalido, llegó {e:?}"
    );
    assert!(
        !real.ruta().join(NOMBRE_CLAVE).exists(),
        "no debe crearse ninguna ruta al rechazar el directorio"
    );
    std::fs::remove_file(&enlace).unwrap();
}
