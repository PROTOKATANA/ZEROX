//! El **alta local del productor dev**: una clave nueva y un registro limpio en una sola
//! operación de aprovisionamiento.
//!
//! # El bloqueo que resuelve
//!
//! [`crate::firmante::Registro::abrir`] nace en abstención (`slot_perdida = slot_actual`,
//! `abstener_hasta = slot_actual + s_max_slots`) porque no puede distinguir «primer arranque» de
//! «registro perdido». Bajo el perfil del primer hijo dev —`slot = 1..150`, `S_max_slots = 150`
//! (`C-HDR-07`, `C-GD-04`)— esa abstención dejaría al productor sin poder firmar **ningún** slot
//! permitido. Bajar `S_max` no es una opción: dejaría una ventana de doble firma tras una pérdida
//! real.
//!
//! La decisión `ALTA-FIRMANTE-DAG-DEV` de `P-ZRX/PIEZAS-DE-CODIGO/DECISIONES-0.0.1.md` elige la
//! opción A: **atar un registro inicialmente limpio a una clave generada en la misma operación**.
//! Si la clave ya existe y falta el registro, la única ruta es `Registro::abrir`, que se abstiene.
//!
//! # Frontera: política local, no consenso
//!
//! Esto **no** es una regla de validez ni un mecanismo de seguridad. Es aprovisionamiento local
//! del productor: ningún verificador lo ejecuta, la clave no entra en el wire y el registro no
//! altera `C-HASH-05`. Es un filtro de accidentes honestos, no una defensa (ver
//! `P-ZRX/P-FIRMANTE/ESPECIFICACION.md` §3.4).
//!
//! # Rutas fijas dentro del directorio
//!
//! [`IdentidadProductorLocal::abrir_o_crear`] recibe un directorio **existente** y escribe tres
//! rutas fijas, sin crear ninguna fuera de él:
//!
//! - `productor.key` — la semilla y su clave pública derivada, en formato fijo de 96 B.
//! - `firmas.log` — el registro durable de `(identidad, slot) -> pre_hash` (formato v3).
//! - `alta.lock` — el cerrojo de aprovisionamiento entre procesos, tomado **antes** de mirar la
//!   clave o el registro y conservado hasta `Drop`.
//!
//! Antes de abrir cualquiera de las tres, el directorio y cada ruta fija se inspeccionan con
//! `symlink_metadata`: ni el directorio ni las rutas fijas pueden ser enlaces simbólicos, y una
//! ruta existente debe ser un fichero regular. Un error de E/S distinto de `NotFound` nunca se
//! interpreta como ausencia. Es un filtro de accidentes honestos: **no** cierra la carrera de un
//! atacante que cambie una ruta entre la comprobación y la apertura.
//!
//! # Formato de `productor.key` (96 B)
//!
//! ```text
//!   0..8    magia ASCII "ZXRGPKEY"
//!   8..16   versión (u64 LE) = 1
//!   16..48  semilla Ed25519 (32 B)
//!   48..80  clave pública derivada (32 B)
//!   80..96  SHA3-256(clave[0..80])[0..16]
//! ```
//!
//! La semilla **no** se imprime, no se incluye en `Debug`, no viaja en errores ni logs y no tiene
//! getter. El fichero se crea con modo `0600` en Unix.
//!
//! # Lo que todavía no cierra
//!
//! `slot_actual` sigue viniendo del llamante: D3 no se cierra hasta acreditar su fuente PoT y
//! conectar este objeto al productor D2. `s_max_slots` es un parámetro del perfil, nunca una
//! constante inventada aquí. Firmar con esta identidad tampoco convierte al bloque en válido:
//! PoAS, cuerpo, reloj y admisión siguen pendientes.

use std::fs::{File, OpenOptions, TryLockError};
use std::io::{Read, Write};
use std::path::{Path, PathBuf};

use ed25519_zebra::{SigningKey, VerificationKey};

use super::registro::{Registro, RegistroError};
use super::{Firmante, FirmanteError, Resultado};
use zx_core::ClavePublica;
use zx_core::preimage::dag::DagBlockHeader;
use zx_core::sha3_256_publico;

/// Nombre fijo de la clave del productor dentro del directorio de alta.
pub const NOMBRE_CLAVE: &str = "productor.key";

/// Nombre fijo del registro durable dentro del directorio de alta.
pub const NOMBRE_REGISTRO: &str = "firmas.log";

/// Nombre fijo del cerrojo de aprovisionamiento dentro del directorio de alta.
pub const NOMBRE_BLOQUEO: &str = "alta.lock";

/// Magia de `productor.key`. Ocho bytes sin ceros.
const MAGIA_CLAVE: [u8; 8] = *b"ZXRGPKEY";

/// Versión del formato de `productor.key`.
const VERSION_CLAVE: u64 = 1;

/// Longitud exacta de `productor.key`, en bytes.
pub const TAMANO_CLAVE: u64 = 96;

/// Longitud de la semilla Ed25519.
const TAMANO_SEMILLA: usize = 32;

/// Longitud de la clave pública Ed25519.
const TAMANO_CLAVE_PUBLICA: usize = 32;

/// Fallos del alta local. Todos significan que **no se devolvió** una identidad utilizable.
#[derive(Debug, thiserror::Error)]
pub enum ErrorAltaFirmante {
    /// El directorio de alta no existe o no es un directorio.
    #[error("alta: {ruta} no existe o no es un directorio")]
    DirectorioInvalido {
        /// Ruta recibida.
        ruta: PathBuf,
    },

    /// Otro proceso tiene el cerrojo de aprovisionamiento. No se lee ni se escribe nada.
    #[error("alta: {ruta} está bloqueado por otro proceso de aprovisionamiento")]
    BloqueoOcupado {
        /// Ruta del fichero de bloqueo.
        ruta: PathBuf,
    },

    /// La clave apareció entre la comprobación de existencia y el `create_new`.
    ///
    /// La llamada actual **no** la carga: eso sería adivinar si la generó un proceso concurrente
    /// que todavía no terminó de sincronizarla. Se falla cerrado y el operador reintenta.
    #[error("alta: {ruta} apareció durante la carrera de creación; se falla cerrado")]
    ClaveAparicionEnCarrera {
        /// Ruta del fichero de clave.
        ruta: PathBuf,
    },

    /// El fichero de clave existe pero no es utilizable: formato inesperado o permisos demasiado
    /// abiertos para grupo u otros. No se lee la semilla si el motivo son los permisos.
    #[error("alta: el fichero de clave {ruta} no es válido: {motivo}")]
    ClaveCorrupta {
        /// Ruta del fichero de clave.
        ruta: PathBuf,
        /// Qué comprobación falló. Nunca incluye bytes de la semilla ni el modo encontrado.
        motivo: &'static str,
    },

    /// El sistema no entregó entropía para la semilla nueva.
    #[error("alta: no se pudo obtener entropía del sistema: {origen}")]
    Entropia {
        /// Error del origen de entropía. No contiene la semilla.
        origen: getrandom::Error,
    },

    /// El registro falló (E/S, bloqueo, corrupción o abstención). No se firmó nada.
    #[error("alta: {0}")]
    Registro(#[from] RegistroError),

    /// El firmante rechazó el candidato. No se firmó nada.
    #[error("alta: {0}")]
    Firmante(#[from] FirmanteError),

    /// Fallo de E/S de la clave o del directorio, con la ruta culpable.
    #[error("alta: E/S en {ruta}: {origen}")]
    Io {
        /// Ruta donde falló la operación.
        ruta: PathBuf,
        /// Error subyacente.
        #[source]
        origen: std::io::Error,
    },
}

/// La identidad local de un productor: su clave, su registro y el cerrojo del alta.
///
/// Se construye **solo** con [`IdentidadProductorLocal::abrir_o_crear`]. Los campos son privados:
/// no hay getter de [`SigningKey`] ni del [`Registro`], y la única operación de firma pasa por
/// [`IdentidadProductorLocal::firmar`], que delega en [`Firmante::firmar`].
pub struct IdentidadProductorLocal {
    /// Clave privada Ed25519 del productor. Nunca se expone.
    sk: SigningKey,
    /// Registro durable `(identidad, slot) -> pre_hash`.
    registro: Registro,
    /// Cerrojo de aprovisionamiento entre procesos, vivo hasta `Drop`.
    _bloqueo: File,
}

impl std::fmt::Debug for IdentidadProductorLocal {
    /// `Debug` deliberadamente **no** imprime la semilla; solo la clave pública.
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("IdentidadProductorLocal")
            .field("public_key", &self.public_key())
            .finish_non_exhaustive()
    }
}

impl IdentidadProductorLocal {
    /// Abre o crea la identidad local en `directorio_existente`.
    ///
    /// El directorio **debe existir** y ser un directorio real: no se sigue un enlace simbólico ni
    /// se crea ninguna ruta fuera de él. El procedimiento es:
    ///
    /// 1. Inspeccionar `alta.lock` con `symlink_metadata` —rechazar un enlace simbólico o un objeto
    ///    que no sea fichero regular—, abrirlo o crearlo y tomar su `try_lock` exclusivo **antes**
    ///    de mirar la clave o el registro. Si está ocupado,
    ///    [`ErrorAltaFirmante::BloqueoOcupado`] sin espera.
    /// 2. Inspeccionar `productor.key` sin seguir enlaces. Si **no existe**: obtener 32 bytes con el
    ///    sistema, construir la clave dentro de esta función (nunca aceptar una semilla externa),
    ///    escribir el formato de 96 B con `create_new`, sincronizar el fichero y el directorio, y
    ///    **solo entonces** crear el registro con [`Registro::crear_inicial_sin_historia`].
    /// 3. Si `productor.key` **ya existe** y es regular: en Unix exigir `mode & 0o077 == 0` antes de
    ///    leer nada; validarla entera (magia, versión, checksum y que la clave pública corresponda
    ///    a la semilla) y abrir el registro **solo** con [`Registro::abrir`]. Si el registro falta,
    ///    la abstención `slot_actual + s_max_slots` es la ruta conservadora y sobrevive a los
    ///    reinicios. Jamás se llama a `crear_inicial_sin_historia` con una clave existente.
    ///
    /// `firmas.log` se inspecciona igual antes de tocarlo: si existe y no es un fichero regular, se
    /// falla cerrado y no se crea ni se abre nada. La inspección es contra accidentes honestos, no
    /// contra un atacante que sustituya una ruta entre la comprobación y la apertura.
    ///
    /// `slot_actual` y `s_max_slots` son entradas explícitas del llamante: el perfil no se fija
    /// aquí. Cuando la clave ya existía, `slot_actual` solo se usa si hay que abrir un registro
    /// ausente, para anclar la abstención.
    ///
    /// # Errores
    /// [`ErrorAltaFirmante::DirectorioInvalido`], [`ErrorAltaFirmante::BloqueoOcupado`],
    /// [`ErrorAltaFirmante::ClaveCorrupta`], [`ErrorAltaFirmante::ClaveAparicionEnCarrera`],
    /// [`ErrorAltaFirmante::Entropia`], [`ErrorAltaFirmante::Registro`] o
    /// [`ErrorAltaFirmante::Io`].
    pub fn abrir_o_crear(
        directorio_existente: &Path,
        slot_actual: u64,
        s_max_slots: u64,
    ) -> Result<Self, ErrorAltaFirmante> {
        // 0. El directorio de alta debe existir y ser un directorio real. `symlink_metadata` no
        //    sigue enlaces: un symlink —aunque apunte a un directorio— y cualquier objeto que no
        //    sea directorio se rechazan como `DirectorioInvalido`. Solo `NotFound` es ausencia.
        match std::fs::symlink_metadata(directorio_existente) {
            Ok(metadatos) if metadatos.file_type().is_dir() => {}
            Ok(_) => {
                return Err(ErrorAltaFirmante::DirectorioInvalido {
                    ruta: directorio_existente.to_path_buf(),
                });
            }
            Err(origen) if origen.kind() == std::io::ErrorKind::NotFound => {
                return Err(ErrorAltaFirmante::DirectorioInvalido {
                    ruta: directorio_existente.to_path_buf(),
                });
            }
            Err(origen) => {
                return Err(ErrorAltaFirmante::Io {
                    ruta: directorio_existente.to_path_buf(),
                    origen,
                });
            }
        }

        let ruta_bloqueo = directorio_existente.join(NOMBRE_BLOQUEO);
        let ruta_clave = directorio_existente.join(NOMBRE_CLAVE);
        let ruta_registro = directorio_existente.join(NOMBRE_REGISTRO);

        // 1. Inspeccionar `alta.lock` ANTES de abrirlo: ni un enlace simbólico ni un objeto que no
        //    sea fichero regular sirven como cerrojo. Así no se crea ni se abre nada fuera del
        //    directorio por seguir un enlace preexistente.
        inspeccionar_ruta_fija(&ruta_bloqueo)?;

        // Cerrojo de aprovisionamiento ANTES de leer la clave o el registro.
        let bloqueo = OpenOptions::new()
            .read(true)
            .write(true)
            .create(true)
            .truncate(false)
            .open(&ruta_bloqueo)
            .map_err(|origen| ErrorAltaFirmante::Io {
                ruta: ruta_bloqueo.clone(),
                origen,
            })?;
        match bloqueo.try_lock() {
            Ok(()) => {}
            Err(TryLockError::WouldBlock) => {
                return Err(ErrorAltaFirmante::BloqueoOcupado { ruta: ruta_bloqueo });
            }
            Err(TryLockError::Error(origen)) => {
                return Err(ErrorAltaFirmante::Io {
                    ruta: ruta_bloqueo,
                    origen,
                });
            }
        }

        // 2. ¿Existe la clave? La clasificación se hace con `symlink_metadata`, no con `exists()`:
        //    un enlace simbólico se rechaza y cualquier error distinto de "no existe" falla cerrado.
        // 3. Con la clave presente, el registro solo se abre por la ruta conservadora.
        if inspeccionar_ruta_fija(&ruta_clave)? {
            // En Unix la clave existente no puede ser legible por grupo/otros. La comprobación
            // precede a leer la semilla y a tocar `firmas.log`.
            #[cfg(unix)]
            comprobar_permisos_clave(&ruta_clave)?;
            let sk = leer_clave(&ruta_clave)?;
            inspeccionar_ruta_fija(&ruta_registro)?;
            let registro = Registro::abrir(&ruta_registro, slot_actual, s_max_slots)?;
            return Ok(Self {
                sk,
                registro,
                _bloqueo: bloqueo,
            });
        }

        // 4. Clave ausente: `firmas.log` debe ser regular si existe, y si no, se crea limpio.
        inspeccionar_ruta_fija(&ruta_registro)?;
        let mut semilla = [0u8; TAMANO_SEMILLA];
        getrandom::fill(&mut semilla).map_err(|origen| ErrorAltaFirmante::Entropia { origen })?;
        let sk = SigningKey::from(semilla);
        let clave_publica: [u8; TAMANO_CLAVE_PUBLICA] = VerificationKey::from(&sk).into();
        // Clave y su sincronización ANTES de crear el registro limpio.
        escribir_clave_nueva(&ruta_clave, &semilla, &clave_publica)?;
        let registro = Registro::crear_inicial_sin_historia(&ruta_registro, s_max_slots)?;
        Ok(Self {
            sk,
            registro,
            _bloqueo: bloqueo,
        })
    }

    /// La clave pública del plot, derivada de la clave privada local.
    ///
    /// Es lo que el productor publica: la semilla no se expone.
    #[must_use]
    pub fn public_key(&self) -> ClavePublica {
        ClavePublica::desde_bytes(VerificationKey::from(&self.sk).into())
    }

    /// Aplica la regla del firmante local al candidato, delegando **exclusivamente** en
    /// [`Firmante::firmar`].
    ///
    /// Persiste la oportunidad en `firmas.log` antes de firmar y conserva los errores tipados de
    /// [`FirmanteError`]. No hay ninguna ruta de firma directa: la clave no sale de este tipo.
    ///
    /// # Errores
    /// [`ErrorAltaFirmante::Firmante`] con el motivo del rechazo.
    pub fn firmar(&self, header: &mut DagBlockHeader) -> Result<Resultado, ErrorAltaFirmante> {
        Firmante::nuevo(&self.registro)
            .firmar(header, &self.sk)
            .map_err(ErrorAltaFirmante::from)
    }

    /// Diagnóstico de solo lectura: ¿el registro se abstiene todavía para `slot`?
    #[must_use]
    pub fn en_abstinencia(&self, slot: u64) -> bool {
        self.registro.en_abstinencia(slot)
    }

    /// Diagnóstico de solo lectura: horizonte de abstención declarado, si lo hay.
    #[must_use]
    pub fn abstener_hasta(&self) -> Option<u64> {
        self.registro.abstener_hasta()
    }

    /// Diagnóstico de solo lectura: número de entradas vivas en el registro.
    #[must_use]
    pub fn entradas(&self) -> u64 {
        self.registro.entradas()
    }
}

/// Inspecciona una ruta fija sin seguir enlaces.
///
/// Devuelve `true` cuando existe y es un fichero regular; `false` cuando no existe (`NotFound`).
/// Un enlace simbólico, un directorio, un dispositivo o cualquier otro objeto se rechazan con
/// [`ErrorAltaFirmante::Io`] y un motivo estático: el tipo no es el esperado. Cualquier error de
/// E/S distinto de `NotFound` se propaga tal cual, **nunca** se trata como ausencia.
fn inspeccionar_ruta_fija(ruta: &Path) -> Result<bool, ErrorAltaFirmante> {
    match std::fs::symlink_metadata(ruta) {
        Ok(metadatos) if metadatos.file_type().is_file() => Ok(true),
        Ok(metadatos) => {
            let motivo = if metadatos.file_type().is_symlink() {
                "es un enlace simbólico, no un fichero regular"
            } else {
                "existe, pero no es un fichero regular"
            };
            Err(ErrorAltaFirmante::Io {
                ruta: ruta.to_path_buf(),
                origen: std::io::Error::new(std::io::ErrorKind::InvalidData, motivo),
            })
        }
        Err(origen) if origen.kind() == std::io::ErrorKind::NotFound => Ok(false),
        Err(origen) => Err(ErrorAltaFirmante::Io {
            ruta: ruta.to_path_buf(),
            origen,
        }),
    }
}

/// En Unix, exige que `productor.key` no conceda permisos a grupo ni a otros
/// (`mode & 0o077 == 0`).
///
/// Se ejecuta **antes** de leer la semilla y de tocar `firmas.log`. No corrige los permisos: falla
/// cerrado para que el operador inspeccione el fichero. El motivo es estático y no incluye el modo
/// ni bytes de la semilla.
#[cfg(unix)]
fn comprobar_permisos_clave(ruta: &Path) -> Result<(), ErrorAltaFirmante> {
    use std::os::unix::fs::PermissionsExt as _;
    let metadatos = std::fs::symlink_metadata(ruta).map_err(|origen| ErrorAltaFirmante::Io {
        ruta: ruta.to_path_buf(),
        origen,
    })?;
    if metadatos.permissions().mode() & 0o077 != 0 {
        return Err(ErrorAltaFirmante::ClaveCorrupta {
            ruta: ruta.to_path_buf(),
            motivo: "permisos de grupo u otros activos; se exige modo 0600",
        });
    }
    Ok(())
}

/// Escribe una clave nueva con `create_new`, formato fijo de 96 B y modo `0600` en Unix.
///
/// Si el fichero apareció durante la carrera, devuelve
/// [`ErrorAltaFirmante::ClaveAparicionEnCarrera`] y **no** lo carga. Si falla la escritura o la
/// sincronización, devuelve error y **no** borra el fichero ambiguo.
fn escribir_clave_nueva(
    ruta: &Path,
    semilla: &[u8; TAMANO_SEMILLA],
    clave_publica: &[u8; TAMANO_CLAVE_PUBLICA],
) -> Result<(), ErrorAltaFirmante> {
    let mut opciones = OpenOptions::new();
    opciones.write(true).create_new(true);
    #[cfg(unix)]
    {
        use std::os::unix::fs::OpenOptionsExt as _;
        opciones.mode(0o600);
    }

    let mut fichero = match opciones.open(ruta) {
        Ok(fichero) => fichero,
        Err(origen) if origen.kind() == std::io::ErrorKind::AlreadyExists => {
            return Err(ErrorAltaFirmante::ClaveAparicionEnCarrera {
                ruta: ruta.to_path_buf(),
            });
        }
        Err(origen) => {
            return Err(ErrorAltaFirmante::Io {
                ruta: ruta.to_path_buf(),
                origen,
            });
        }
    };

    let mut formato = [0u8; TAMANO_CLAVE as usize];
    formato[0..8].copy_from_slice(&MAGIA_CLAVE);
    formato[8..16].copy_from_slice(&VERSION_CLAVE.to_le_bytes());
    formato[16..48].copy_from_slice(semilla);
    formato[48..80].copy_from_slice(clave_publica);
    let comprobacion = sha3_256_publico(&formato[..80]);
    formato[80..96].copy_from_slice(&comprobacion.as_bytes()[..16]);

    fichero
        .write_all(&formato)
        .and_then(|()| fichero.sync_all())
        .map_err(|origen| ErrorAltaFirmante::Io {
            ruta: ruta.to_path_buf(),
            origen,
        })?;
    // La creación de la clave también tiene que ser durable antes de crear el registro.
    sincronizar_directorio(ruta)
}

/// Lee y valida una `productor.key` existente, sin truncar ni regenerar nada.
///
/// Rechaza longitudes distintas de 96 B (cola parcial o bytes extra), magia o versión ajenas,
/// checksum inválido y clave pública que no corresponda a la semilla. Falla cerrado con
/// [`ErrorAltaFirmante::ClaveCorrupta`] y nunca firma.
fn leer_clave(ruta: &Path) -> Result<SigningKey, ErrorAltaFirmante> {
    let mut fichero = File::open(ruta).map_err(|origen| ErrorAltaFirmante::Io {
        ruta: ruta.to_path_buf(),
        origen,
    })?;

    let mut bytes = [0u8; TAMANO_CLAVE as usize];
    match fichero.read_exact(&mut bytes) {
        Ok(()) => {}
        Err(origen) if origen.kind() == std::io::ErrorKind::UnexpectedEof => {
            return Err(ErrorAltaFirmante::ClaveCorrupta {
                ruta: ruta.to_path_buf(),
                motivo: "longitud menor de 96 bytes (cola parcial)",
            });
        }
        Err(origen) => {
            return Err(ErrorAltaFirmante::Io {
                ruta: ruta.to_path_buf(),
                origen,
            });
        }
    }

    // Leer un byte más: un fichero de 96 B no puede tener cola.
    let mut sobra = [0u8; 1];
    match fichero.read(&mut sobra) {
        Ok(0) => {}
        Ok(_) => {
            return Err(ErrorAltaFirmante::ClaveCorrupta {
                ruta: ruta.to_path_buf(),
                motivo: "bytes extra después de los 96 bytes",
            });
        }
        Err(origen) => {
            return Err(ErrorAltaFirmante::Io {
                ruta: ruta.to_path_buf(),
                origen,
            });
        }
    }

    if bytes[0..8] != MAGIA_CLAVE {
        return Err(ErrorAltaFirmante::ClaveCorrupta {
            ruta: ruta.to_path_buf(),
            motivo: "magia inesperada",
        });
    }

    let mut version_bytes = [0u8; 8];
    version_bytes.copy_from_slice(&bytes[8..16]);
    if u64::from_le_bytes(version_bytes) != VERSION_CLAVE {
        return Err(ErrorAltaFirmante::ClaveCorrupta {
            ruta: ruta.to_path_buf(),
            motivo: "versión de formato desconocida",
        });
    }

    let comprobacion = sha3_256_publico(&bytes[..80]);
    if bytes[80..96] != comprobacion.as_bytes()[..16] {
        return Err(ErrorAltaFirmante::ClaveCorrupta {
            ruta: ruta.to_path_buf(),
            motivo: "comprobación de integridad inválida",
        });
    }

    let mut semilla = [0u8; TAMANO_SEMILLA];
    semilla.copy_from_slice(&bytes[16..48]);
    let mut guardada = [0u8; TAMANO_CLAVE_PUBLICA];
    guardada.copy_from_slice(&bytes[48..80]);

    let sk = SigningKey::from(semilla);
    let derivada: [u8; TAMANO_CLAVE_PUBLICA] = VerificationKey::from(&sk).into();
    if derivada != guardada {
        return Err(ErrorAltaFirmante::ClaveCorrupta {
            ruta: ruta.to_path_buf(),
            motivo: "la clave pública no corresponde a la semilla guardada",
        });
    }

    Ok(sk)
}

/// Sincroniza el directorio padre para que la creación del fichero sea durable.
///
/// Si no se puede abrir o sincronizar, se devuelve error: el alta no finge una durabilidad que no
/// puede garantizar.
fn sincronizar_directorio(ruta: &Path) -> Result<(), ErrorAltaFirmante> {
    let padre = ruta
        .parent()
        .filter(|p| !p.as_os_str().is_empty())
        .unwrap_or_else(|| Path::new("."));
    let dir = File::open(padre).map_err(|origen| ErrorAltaFirmante::Io {
        ruta: ruta.to_path_buf(),
        origen,
    })?;
    dir.sync_all().map_err(|origen| ErrorAltaFirmante::Io {
        ruta: ruta.to_path_buf(),
        origen,
    })
}
