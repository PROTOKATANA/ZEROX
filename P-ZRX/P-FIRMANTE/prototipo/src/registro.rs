//! Registro persistente de oportunidades: `(identidad, slot) -> pre_hash`.
//!
//! Es la pieza que hace que el firmante seguro sirva de algo. El punto 3 de la regla
//! (`ESPECIFICACION.md` §3.1) no es «apuntar el bloque»: es **persistir antes de firmar**, de forma
//! **atómica y duradera**. Un `Vec` en memoria, o un `write` sin `fsync`, reproducen exactamente el
//! accidente que se quiere evitar: corte de energía entre la firma y el apunte.
//!
//! # Formato
//!
//! Un fichero por registro, solo-anexar, con cabecera de 32 bytes y entradas de 80:
//!
//! ```text
//! cabecera (32 B)
//!   0..8    magia "ZXRGFIRM"
//!   8..16   versión de formato (u64 LE)
//!   16..24  max_slot: el mayor slot jamás escrito en este fichero (u64 LE)
//!   24..32  reservado, ceros
//! entrada (80 B)
//!   0..8    slot (u64 LE)
//!   8..40   huella de la identidad de oportunidad (32 B)
//!   40..72  pre_hash (32 B)
//!   72..80  comprobación = SHA3-256(entrada[0..72])[0..8]
//! ```
//!
//! `max_slot` es **la** pieza de estado que hace exacta la abstención: un registro vacío pero con
//! `max_slot = s` no puede saber si firmó algo para `s`, así que se abstiene. Ver
//! [`Registro::abrir`] y [`crate::firmante`].
//!
//! # Qué garantiza y qué no
//!
//! - **Durabilidad**: `append` escribe y llama a `sync_all` (fsync) **antes** de devolver `Ok`. Si
//!   devuelve `Ok`, la entrada está en el disco. Si falla, el índice en memoria **no** se actualiza
//!   y el firmante **no** firma.
//! - **Exclusión entre procesos**: `flock(LOCK_EX | LOCK_NB)` sobre el descriptor durante toda la
//!   vida del [`Registro`]. Un segundo proceso sobre el mismo fichero recibe
//!   [`RegistroError::Bloqueado`] en vez de corromper el log. Es exclusión, no coordinación: ver
//!   el §5 del informe y la lista de lo que NO cubre.
//! - **Exclusión entre hilos**: `Mutex` alrededor del estado.
//! - **NO** cubre: dos procesos que copien el fichero, un atacante que lo borre, ni dos ficheros
//!   distintos para la misma parcela. `ESPECIFICACION.md` §3.4.

// La excepción de `unsafe` es una sola llamada a `flock(2)`: no hay opción estable en `std` para
// el bloqueo de fichero entre procesos, y la alternativa (riesgo de dos escritores) es peor. Está
// confinada en `bloquear()` y no toca memoria.
#![allow(unsafe_code, reason = "una llamada a flock(2), sin acceso a memoria")]

use std::fs::File;
use std::io::{Read, Seek, SeekFrom, Write};
use std::os::unix::io::AsRawFd;
use std::path::{Path, PathBuf};
use std::sync::Mutex;

use zx_core::PreHash;

use crate::identidad::{IdentidadOportunidad, LONGITUD_HUELLA};

/// Magia del fichero. Ocho bytes, sin ceros, para que un fichero vacío o de basura no se confunda.
pub const MAGIA: [u8; 8] = *b"ZXRGFIRM";

/// Versión del formato de fichero.
pub const VERSION_FORMATO: u64 = 1;

/// Longitud de la cabecera, en bytes.
pub const TAMANO_CABECERA: u64 = 32;

/// Longitud de una entrada, en bytes.
pub const TAMANO_ENTRADA: u64 = 80;

/// Offset de `max_slot` dentro de la cabecera.
const OFFSET_MAX_SLOT: u64 = 16;

/// Offset del campo de comprobación dentro de la entrada.
const OFFSET_COMPROBACION: usize = 72;

/// Longitud del campo de comprobación.
const TAMANO_COMPROBACION: usize = 8;

/// Offset de la huella dentro de la entrada.
const OFFSET_HUELLA: usize = 8;

/// Offset del `pre_hash` dentro de la entrada.
const OFFSET_PRE_HASH: usize = 40;

/// Lo que el registro sabe de una oportunidad.
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Resolucion {
    /// No había entrada: se escribió, se sincronizó y **ahora** se puede firmar.
    Nueva,
    /// Ya había entrada con el **mismo** `pre_hash`: es el mismo bloque. Firmar es correcto
    /// (caso 4 de la regla: un nodo que se reinicia y republica no queda roto).
    Conocida,
    /// Ya había entrada con **otro** `pre_hash`: no se firma y el candidato se descarta (caso 5).
    Conflicto {
        /// El `pre_hash` que ya estaba registrado.
        pre_hash_registrado: PreHash,
    },
}

/// Fallos del registro. Todos son **motivo para no firmar**.
#[derive(Debug, thiserror::Error)]
pub enum RegistroError {
    /// El fichero no se pudo abrir o crear.
    #[error("registro: E/S en {ruta}: {origen}")]
    Io {
        /// Ruta del registro.
        ruta: PathBuf,
        /// Error de E/S subyacente.
        #[source]
        origen: std::io::Error,
    },

    /// Otro proceso tiene el registro bloqueado. No se escribe nada.
    #[error("registro: {ruta} está bloqueado por otro proceso ({origen})")]
    Bloqueado {
        /// Ruta del registro.
        ruta: PathBuf,
        /// Error de E/S subyacente (normalmente `EWOULDBLOCK`).
        #[source]
        origen: std::io::Error,
    },

    /// El fichero no empieza por la magia esperada.
    #[error("registro: {ruta} no es un registro del firmante (magia inesperada)")]
    MagiaInvalida {
        /// Ruta del registro.
        ruta: PathBuf,
    },

    /// El fichero declara una versión de formato que este binario no sabe leer.
    #[error("registro: {ruta} declara versión de formato {encontrada}, esperada {esperada}")]
    VersionInvalida {
        /// Ruta del registro.
        ruta: PathBuf,
        /// Versión encontrada.
        encontrada: u64,
        /// Versión que este binario escribe.
        esperada: u64,
    },

    /// Hay bytes alterados en medio del log. **No se trunca**: truncar silenciosamente perdería
    /// entradas posteriores válidas —y olvidar una entrada es la única forma de doble-firmar—,
    /// así que se falla cerrado y el operador decide.
    #[error(
        "registro: {ruta} corrupto en el byte {offset} ({bytes_perdidos} bytes posteriores no vacíos)"
    )]
    Corrupto {
        /// Ruta del registro.
        ruta: PathBuf,
        /// Offset del primer byte inválido.
        offset: u64,
        /// Bytes posteriores que no son cero (prueba de que no es una cola truncada).
        bytes_perdidos: u64,
    },

    /// El registro está en su ventana de abstención: perdió el estado y aún no puede firmar.
    #[error(
        "registro: abstinencia por pérdida; slot actual {slot_actual} ≤ {hasta} (S_max_slots = {s_max_slots})"
    )]
    EnAbstinencia {
        /// Slot actual de la consulta.
        slot_actual: u64,
        /// Último slot en el que todavía se abstiene (`max_slot + S_max_slots`).
        hasta: u64,
        /// `S_max_slots` vigente en esta instancia.
        s_max_slots: u64,
    },
}

/// Clave del índice en memoria: la huella de la identidad y el slot.
type Clave = ([u8; LONGITUD_HUELLA], u64);

/// Índice en memoria del registro.
type Indice = std::collections::HashMap<Clave, PreHash>;

/// Estado mutable protegido por el mutex.
struct Estado {
    fichero: File,
    ruta: PathBuf,
    /// Índice en memoria: `(huella, slot) -> pre_hash`. Se actualiza **solo** tras un `fsync`
    /// correcto.
    indice: Indice,
    /// Mayor slot jamás escrito en este fichero.
    max_slot: u64,
    /// ¿Está activa la abstención por pérdida de estado?
    ///
    /// No se deduce de `max_slot`: un registro **nuevo** sin historia no tiene nada de lo que
    /// abstenerse aunque su `max_slot` sea 0, y uno recién **perdido** sí. Solo
    /// [`Registro::abrir`] sobre un fichero inexistente la activa; un fichero que existe ya tiene
    /// su historia en disco y no hay nada que suplir.
    abstencion_activa: bool,
    /// Número de entradas vivas en el índice (tras podar).
    entradas: u64,
    /// `S_max_slots` con el que se abrió.
    s_max_slots: u64,
}

impl std::fmt::Debug for Estado {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("Estado")
            .field("ruta", &self.ruta)
            .field("entradas", &self.entradas)
            .field("max_slot", &self.max_slot)
            .field("abstencion_activa", &self.abstencion_activa)
            .field("s_max_slots", &self.s_max_slots)
            .finish()
    }
}

/// El registro persistente.
///
/// Se comparte entre hilos con `&Registro` (lleva su propio `Mutex`); ver
/// [`crate::firmante::Firmante`].
#[derive(Debug)]
pub struct Registro {
    estado: Mutex<Estado>,
}

impl Registro {
    /// Abre el registro de `ruta`, creándolo si no existe.
    ///
    /// Si el fichero **no existe**, se crea con `max_slot = slot_actual`: el registro no sabe qué
    /// firmó antes de existir, así que se declara en abstención. Es la ruta segura y es la que hay
    /// que usar tras una pérdida de estado (`ESPECIFICACION.md` §3.2). Para un registro nuevo sin
    /// historia —tests, o alta de una parcela que nunca firmó— está [`Registro::nueva`].
    ///
    /// # Errores
    /// [`RegistroError::Bloqueado`] si otro proceso lo tiene abierto;
    /// [`RegistroError::Corrupto`] si encuentra entradas alteradas en medio del log;
    /// [`RegistroError::Io`] para el resto de fallos de E/S.
    pub fn abrir(
        ruta: impl AsRef<Path>,
        slot_actual: u64,
        s_max_slots: u64,
    ) -> Result<Self, RegistroError> {
        Self::abrir_con_politica(ruta, slot_actual, s_max_slots, true)
    }

    /// Abre un registro **nuevo**, sin abstención.
    ///
    /// Declara que este fichero no ha firmado nunca nada y que no hay nada que perder. Es
    /// exactamente lo que **no** se puede afirmar tras un reinicio con pérdida de estado; úsese
    /// solo donde esa afirmación sea verdad (primera instalación, tests).
    ///
    /// # Errores
    /// Las mismas que [`Registro::abrir`].
    pub fn nueva(
        ruta: impl AsRef<Path>,
        s_max_slots: u64,
    ) -> Result<Self, RegistroError> {
        Self::abrir_con_politica(ruta, 0, s_max_slots, false)
    }

    fn abrir_con_politica(
        ruta: impl AsRef<Path>,
        slot_actual: u64,
        s_max_slots: u64,
        abstener_si_nuevo: bool,
    ) -> Result<Self, RegistroError> {
        let ruta = ruta.as_ref().to_path_buf();
        let mut fichero = abrir_sin_herederos(&ruta)?;
        bloquear(&fichero, &ruta)?;

        let len = fichero
            .metadata()
            .map_err(|origen| RegistroError::Io {
                ruta: ruta.clone(),
                origen,
            })?
            .len();

        let (indice, max_slot, entradas, abstencion_activa) = if len == 0 {
            // Fichero recién creado: cabecera. `max_slot` = slot de pérdida declarado.
            let max_slot_inicial = if abstener_si_nuevo { slot_actual } else { 0 };
            let cabecera = cabecera_bytes(max_slot_inicial);
            fichero
                .write_all(&cabecera)
                .and_then(|()| fichero.sync_all())
                .map_err(|origen| RegistroError::Io {
                    ruta: ruta.clone(),
                    origen,
                })?;
            (
                std::collections::HashMap::new(),
                max_slot_inicial,
                0u64,
                abstener_si_nuevo,
            )
        } else {
            // Un fichero que existe ya trae su historia: no hay nada que suplir con abstención.
            let (indice, max_slot, entradas) = recuperar(&mut fichero, &ruta)?;
            (indice, max_slot, entradas, false)
        };

        Ok(Self {
            estado: Mutex::new(Estado {
                fichero,
                ruta,
                indice,
                max_slot,
                abstencion_activa,
                entradas,
                s_max_slots,
            }),
        })
    }

    /// Consulta y, si procede, **persiste antes de devolver**: el punto 3 de la regla.
    ///
    /// Es la única operación de escritura que el firmante usa, y es atómica respecto de la clave:
    /// mira, decide, escribe y sincroniza bajo el mismo cerrojo.
    ///
    /// - Sin entrada: escribe `(huella, slot) -> pre_hash`, `fsync`, y devuelve
    ///   [`Resolucion::Nueva`]. **Solo entonces** el llamante puede firmar.
    /// - Con entrada y el mismo `pre_hash`: [`Resolucion::Conocida`], sin escritura.
    /// - Con entrada y otro `pre_hash`: [`Resolucion::Conflicto`], **sin escritura**.
    ///
    /// # Errores
    /// [`RegistroError::EnAbstinencia`] si el registro perdió el estado y aún no puede firmar;
    /// [`RegistroError::Io`] si el `fsync` falla (y entonces el índice en memoria **no** cambia).
    pub fn resolver(
        &self,
        identidad: &impl IdentidadOportunidad,
        pre_hash: PreHash,
    ) -> Result<Resolucion, RegistroError> {
        let mut estado = self.estado.lock().unwrap_or_else(|e| e.into_inner());
        let slot = identidad.slot();
        let huella = identidad.huella();

        // La abstención va primero: si el registro no es de fiar, no se escribe ni se firma.
        if let Some(hasta) = estado.abstencion_hasta()
            && slot <= hasta
        {
            return Err(RegistroError::EnAbstinencia {
                slot_actual: slot,
                hasta,
                s_max_slots: estado.s_max_slots,
            });
        }

        if let Some(registrado) = estado.indice.get(&(huella, slot)).copied() {
            if registrado == pre_hash {
                return Ok(Resolucion::Conocida);
            }
            return Ok(Resolucion::Conflicto {
                pre_hash_registrado: registrado,
            });
        }

        // Camino de escritura: entrada nueva. Se persiste y se sincroniza ANTES de devolver.
        estado.escribir_entrada(slot, &huella, pre_hash)?;
        Ok(Resolucion::Nueva)
    }

    /// ¿Está `(identidad, slot)` ya en el registro con **este** `pre_hash`?
    ///
    /// Consulta **de solo lectura**: no escribe, no sincroniza y **no** activa la abstención. Un
    /// `false` no significa «se puede firmar» —para eso está [`Registro::resolver`], que además
    /// persiste— sino «no había entrada con este `pre_hash`», que es lo que necesitan el
    /// diagnóstico y los tests.
    #[must_use]
    pub fn contiene(
        &self,
        identidad: &impl IdentidadOportunidad,
        pre_hash: PreHash,
    ) -> bool {
        let estado = self.estado.lock().unwrap_or_else(|e| e.into_inner());
        estado
            .indice
            .get(&(identidad.huella(), identidad.slot()))
            .is_some_and(|registrado| registrado == &pre_hash)
    }

    /// El `pre_hash` registrado para esa oportunidad, si lo hay. Solo lectura.
    #[must_use]
    pub fn registrado(
        &self,
        identidad: &impl IdentidadOportunidad,
    ) -> Option<PreHash> {
        let estado = self.estado.lock().unwrap_or_else(|e| e.into_inner());
        estado
            .indice
            .get(&(identidad.huella(), identidad.slot()))
            .copied()
    }

    /// ¿Está el registro en abstención para `slot`?
    #[must_use]
    pub fn en_abstinencia(&self, slot: u64) -> bool {
        let estado = self.estado.lock().unwrap_or_else(|e| e.into_inner());
        estado.abstencion_hasta().is_some_and(|hasta| slot <= hasta)
    }

    /// El mayor slot escrito en este registro.
    #[must_use]
    pub fn max_slot(&self) -> u64 {
        self.estado
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .max_slot
    }

    /// Número de entradas vivas en el índice.
    #[must_use]
    pub fn entradas(&self) -> u64 {
        self.estado
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .entradas
    }

    /// Tamaño del fichero en bytes.
    ///
    /// # Errores
    /// [`RegistroError::Io`] si el `metadata` falla.
    pub fn tamano_bytes(&self) -> Result<u64, RegistroError> {
        let estado = self.estado.lock().unwrap_or_else(|e| e.into_inner());
        estado
            .fichero
            .metadata()
            .map(|m| m.len())
            .map_err(|origen| RegistroError::Io {
                ruta: estado.ruta.clone(),
                origen,
            })
    }

    /// El umbral de poda: una entrada con `slot + ttl_slots() < max_slot` ya no puede colisionar
    /// (`C-GD-04`: `slot(B) − slot(sp(B)) ≤ S_max`), así que se puede tirar.
    #[must_use]
    pub fn umbral_poda(&self) -> u64 {
        let estado = self.estado.lock().unwrap_or_else(|e| e.into_inner());
        estado.max_slot.saturating_sub(estado.s_max_slots)
    }

    /// Poda las entradas que ya no pueden colisionar y **compacta** el fichero.
    ///
    /// Es una operación de mantenimiento, **fuera del camino crítico de producción**: reescribe el
    /// log, lo sincroniza y solo entonces sustituye el contenido. Mientras corre, el cerrojo del
    /// registro está tomado y ninguna firma avanza.
    ///
    /// Devuelve cuántas entradas se tiraron.
    ///
    /// # Errores
    /// [`RegistroError::Io`] si falla la escritura o el `fsync` de la compactación.
    pub fn podar(&self) -> Result<u64, RegistroError> {
        let mut estado = self.estado.lock().unwrap_or_else(|e| e.into_inner());
        let viejas: Vec<(Clave, PreHash)> = estado
            .indice
            .iter()
            .filter(|((_, slot), _)| *slot + estado.s_max_slots < estado.max_slot)
            .map(|(k, v)| (*k, *v))
            .collect();
        if viejas.is_empty() {
            return Ok(0);
        }
        let vivas: Vec<(Clave, PreHash)> = estado
            .indice
            .iter()
            .filter(|(k, _)| !viejas.iter().any(|(vk, _)| vk == *k))
            .map(|(k, v)| (*k, *v))
            .collect();

        let mut nuevo = Vec::with_capacity(
            usize::try_from(TAMANO_CABECERA).unwrap_or(32) + vivas.len() * 80,
        );
        nuevo.extend_from_slice(&cabecera_bytes(estado.max_slot));
        for ((huella, slot), pre_hash) in &vivas {
            nuevo.extend_from_slice(&entrada_bytes(*slot, huella, *pre_hash));
        }

        estado
            .fichero
            .seek(SeekFrom::Start(0))
            .and_then(|_| estado.fichero.write_all(&nuevo))
            .and_then(|()| estado.fichero.set_len(u64::try_from(nuevo.len()).unwrap_or(0)))
            .and_then(|()| estado.fichero.sync_all())
            .map_err(|origen| RegistroError::Io {
                ruta: estado.ruta.clone(),
                origen,
            })?;

        estado.indice = vivas.into_iter().collect();
        estado.entradas = u64::try_from(estado.indice.len()).unwrap_or(0);
        Ok(u64::try_from(viejas.len()).unwrap_or(0))
    }

    /// Fuerza a disco el estado actual del fichero. No hace falta en el camino normal
    /// ([`Registro::resolver`] ya sincroniza); existe para los tests de durabilidad.
    ///
    /// # Errores
    /// [`RegistroError::Io`] si el `fsync` falla.
    pub fn sincronizar(&self) -> Result<(), RegistroError> {
        let estado = self.estado.lock().unwrap_or_else(|e| e.into_inner());
        estado.fichero.sync_all().map_err(|origen| RegistroError::Io {
            ruta: estado.ruta.clone(),
            origen,
        })
    }

    /// La ruta del fichero.
    #[must_use]
    pub fn ruta(&self) -> PathBuf {
        self.estado
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .ruta
            .clone()
    }
}

impl Estado {
    /// Último slot en el que este registro todavía se abstiene.
    ///
    /// **Es la fórmula exacta del §3.2**: un bloque para el slot `s` solo puede aparecer mientras
    /// `slot(B) − slot(sp(B)) ≤ S_max_slots`, así que pasado `s + S_max_slots` ningún bloque nuevo
    /// puede reclamar `s`. Devuelve `None` cuando no hay abstención activa, que es el caso de un
    /// registro **nuevo** (nada firmado nunca) y el de un fichero **existente** (su historia está
    /// en disco).
    fn abstencion_hasta(&self) -> Option<u64> {
        if !self.abstencion_activa {
            return None;
        }
        Some(self.max_slot.saturating_add(self.s_max_slots))
    }

    fn escribir_entrada(
        &mut self,
        slot: u64,
        huella: &[u8; LONGITUD_HUELLA],
        pre_hash: PreHash,
    ) -> Result<(), RegistroError> {
        let bytes = entrada_bytes(slot, huella, pre_hash);
        // Solo-anexar: la posición de escritura se calcula desde el tamaño lógico del fichero.
        let fin = self
            .fichero
            .seek(SeekFrom::End(0))
            .map_err(|origen| RegistroError::Io {
                ruta: self.ruta.clone(),
                origen,
            })?;
        debug_assert_eq!(fin % TAMANO_ENTRADA, TAMANO_CABECERA % TAMANO_ENTRADA);

        self.fichero
            .write_all(&bytes)
            .and_then(|()| self.fichero.sync_all())
            .map_err(|origen| RegistroError::Io {
                ruta: self.ruta.clone(),
                origen,
            })?;

        // A partir de aquí la entrada está en disco. El índice en memoria se actualiza DESPUÉS.
        self.indice.insert((*huella, slot), pre_hash);
        self.entradas = u64::try_from(self.indice.len()).unwrap_or(0);

        // Se llegó aquí porque `slot > abstencion_hasta()`: la ventana de pérdida ya no cubre este
        // slot, y a partir de ahora la durabilidad del fichero es la que responde. Dejar la
        // abstención activa haría que el registro se abstuviera para siempre —y una abstención que
        // no termina no es el §3.2, es una parcela muerta.
        self.abstencion_activa = false;

        if slot > self.max_slot {
            self.max_slot = slot;
            let mut pos = [0u8; 8];
            pos.copy_from_slice(&slot.to_le_bytes());
            self.fichero
                .seek(SeekFrom::Start(OFFSET_MAX_SLOT))
                .and_then(|_| self.fichero.write_all(&pos))
                .and_then(|()| self.fichero.sync_all())
                .map_err(|origen| RegistroError::Io {
                    ruta: self.ruta.clone(),
                    origen,
                })?;
        }
        Ok(())
    }
}

/// Cabecera de 32 bytes.
fn cabecera_bytes(max_slot: u64) -> [u8; 32] {
    let mut c = [0u8; 32];
    c[0..8].copy_from_slice(&MAGIA);
    c[8..16].copy_from_slice(&VERSION_FORMATO.to_le_bytes());
    c[16..24].copy_from_slice(&max_slot.to_le_bytes());
    c
}

/// Comprobación de integridad de una entrada: `SHA3-256(entrada[0..72])[0..8]`.
fn comprobacion(entrada: &[u8]) -> [u8; TAMANO_COMPROBACION] {
    let d = zx_core::sha3_256_publico(entrada.get(..OFFSET_COMPROBACION).unwrap_or(&[]));
    let mut c = [0u8; TAMANO_COMPROBACION];
    if let (Some(dst), Some(src)) = (c.get_mut(..), d.as_bytes().get(..TAMANO_COMPROBACION)) {
        dst.copy_from_slice(src);
    }
    c
}

/// Serializa una entrada.
fn entrada_bytes(slot: u64, huella: &[u8; LONGITUD_HUELLA], pre_hash: PreHash) -> [u8; 80] {
    let mut e = [0u8; 80];
    e[0..8].copy_from_slice(&slot.to_le_bytes());
    e[OFFSET_HUELLA..OFFSET_HUELLA + LONGITUD_HUELLA].copy_from_slice(huella);
    e[OFFSET_PRE_HASH..OFFSET_PRE_HASH + 32].copy_from_slice(pre_hash.as_bytes());
    let c = comprobacion(&e);
    e[OFFSET_COMPROBACION..].copy_from_slice(&c);
    e
}

/// Abre el fichero del registro con `O_CLOEXEC` **en el propio `open(2)`**.
///
/// # Por qué a mano y no con `OpenOptions`
///
/// El descriptor del registro lleva un `flock`, y `flock` vive en la *open file description*: si el
/// descriptor sobrevive a un `fork`, el hijo lo comparte y mantiene el cerrojo. Un nodo —o un
/// arnés de tests— que lance cualquier proceso hijo con el registro abierto deja el registro
/// bloqueado durante la ventana entre el `fork` y el `exec`, y si en ese hueco cierra y reabre su
/// registro, se encuentra un `EWOULDBLOCK` que no es culpa de nadie. Medido en este prototipo: en
/// ~10 % de las pasadas de la suite.
///
/// Marcar el descriptor **después** de abrirlo no cierra la ventana, y pasar `O_CLOEXEC` por
/// `OpenOptions::custom_flags` **no funcionó** aquí: el descriptor acababa con
/// `flags: 02100002` (`O_RDWR|O_LARGEFILE`, sin `O_CLOEXEC`) y el fallo seguía. Abrir con
/// `O_CLOEXEC` en los flags del `open` es atómico: el descriptor nace sin posibilidad de heredarse.
///
/// # Errores
/// [`RegistroError::Io`] si el `open(2)` falla.
fn abrir_sin_herederos(ruta: &Path) -> Result<File, RegistroError> {
    use std::os::unix::ffi::OsStrExt as _;
    use std::os::unix::io::FromRawFd as _;

    let mut c_ruta = Vec::with_capacity(ruta.as_os_str().as_bytes().len() + 1);
    c_ruta.extend_from_slice(ruta.as_os_str().as_bytes());
    c_ruta.push(0);

    // SAFETY: `c_ruta` termina en NUL; `open` solo lee esa cadena. Los flags son constantes y el
    // modo solo se usa al crear. Quien recibe el descriptor es `File::from_raw_fd`, que toma su
    // propiedad, así que no hay doble cierre.
    let fd = unsafe {
        libc::open(
            c_ruta.as_ptr().cast::<libc::c_char>(),
            libc::O_RDWR | libc::O_CREAT | libc::O_CLOEXEC,
            0o644,
        )
    };
    if fd < 0 {
        return Err(RegistroError::Io {
            ruta: ruta.to_path_buf(),
            origen: std::io::Error::last_os_error(),
        });
    }
    // SAFETY: `fd` es un descriptor válido y recién abierto, y no lo usa nadie más.
    Ok(unsafe { File::from_raw_fd(fd) })
}

/// Toma el bloqueo exclusivo del fichero, con reintentos acotados.
///
/// # Por qué reintenta, y por qué está acotado
///
/// `flock` vive en la *open file description*. Un `fork` —el de cualquier `Command::spawn` del
/// nodo o del arnés de tests— duplica las descripciones abiertas del padre; el hijo las cierra al
/// hacer `exec` gracias a `O_CLOEXEC` (ver [`abrir_sin_herederos`]), pero entre el `fork` y el
/// `exec` el cerrojo lo sostiene el hijo. En esa ventana, cerrar y reabrir el registro da
/// `EWOULDBLOCK` **sin que haya un segundo escritor**: es un titular transitorio, no una colisión.
/// Medido en este prototipo antes de reintentar: 1–4 fallos por cada 10 pasadas de la suite con
/// hilos en paralelo, siempre en la reapertura.
///
/// Por eso se reintenta durante `PLAZO_BLOQUEO`: un segundo escritor **real** no suelta el cerrojo,
/// así que al agotar el plazo se devuelve [`RegistroError::Bloqueado`] igual. El reintento no abre
/// ninguna puerta a dos escritores: solo deja de confundir un titular transitorio con uno
/// permanente, y el cerrojo se sigue tomando **antes** de leer o escribir nada.
fn bloquear(fichero: &File, ruta: &Path) -> Result<(), RegistroError> {
    /// Cuánto se espera a que un titular transitorio suelte el cerrojo.
    const PLAZO_BLOQUEO: std::time::Duration = std::time::Duration::from_secs(2);
    /// Primer intervalo entre reintentos.
    const INTERVALO_INICIAL: std::time::Duration = std::time::Duration::from_micros(50);
    /// Techo del intervalo entre reintentos.
    const INTERVALO_MAXIMO: std::time::Duration = std::time::Duration::from_millis(20);

    let inicio = std::time::Instant::now();
    let mut intervalo = INTERVALO_INICIAL;
    loop {
        // SAFETY: `flock(2)` sobre un descriptor válido y vivo; no hay memoria compartida ni
        // punteros. El único efecto es el estado de bloqueo del open file description.
        let rc = unsafe { libc::flock(fichero.as_raw_fd(), libc::LOCK_EX | libc::LOCK_NB) };
        if rc == 0 {
            return Ok(());
        }
        let origen = std::io::Error::last_os_error();
        if origen.raw_os_error() != Some(libc::EWOULDBLOCK) {
            // Un error que no es «ocupado» no se arregla esperando.
            return Err(RegistroError::Io {
                ruta: ruta.to_path_buf(),
                origen,
            });
        }
        let esperado = inicio.elapsed();
        if esperado >= PLAZO_BLOQUEO {
            diagnostico_de_bloqueo(ruta, fichero.as_raw_fd());
            return Err(RegistroError::Bloqueado {
                ruta: ruta.to_path_buf(),
                origen,
            });
        }
        std::thread::sleep(intervalo.min(PLAZO_BLOQUEO - esperado));
        intervalo = (intervalo * 2).min(INTERVALO_MAXIMO);
    }
}

/// Diagnóstico de un bloqueo inesperado, **solo** si `FIRMANTE_DIAGNOSTICO` está puesta.
///
/// Existe porque el síntoma —«mi propio registro está bloqueado y no tengo ningún descriptor
/// abierto»— es indistinguible de un fallo de la lógica hasta que se ve **quién** tiene el
/// descriptor. Recorre `/proc/<pid>/fd` de todos los procesos vivos buscando enlaces al fichero.
fn diagnostico_de_bloqueo(ruta: &Path, fd: libc::c_int) {
    if std::env::var_os("FIRMANTE_DIAGNOSTICO").is_none() {
        return;
    }
    let objetivo = std::fs::canonicalize(ruta).unwrap_or_else(|_| ruta.to_path_buf());
    eprintln!(
        "[diag] pid={} fd={fd} no pudo bloquear {} (canónico {})",
        std::process::id(),
        ruta.display(),
        objetivo.display()
    );
    if let Ok(info) = std::fs::read_to_string(format!("/proc/self/fdinfo/{fd}")) {
        eprintln!("[diag]   fdinfo del candidato: {}", info.replace('\n', " | "));
    }
    // ¿Cuántos procesos vivos hay y cuántos hijos tengo?
    if let Ok(estado) = std::fs::read_to_string("/proc/self/status") {
        for l in estado.lines().filter(|l| l.starts_with("Threads")) {
            eprintln!("[diag]   {l}");
        }
    }
    let Ok(entradas) = std::fs::read_dir("/proc") else {
        return;
    };
    for entrada in entradas.flatten() {
        let nombre = entrada.file_name();
        let Some(pid) = nombre.to_str().filter(|s| s.chars().all(|c| c.is_ascii_digit())) else {
            continue;
        };
        let Ok(fds) = std::fs::read_dir(format!("/proc/{pid}/fd")) else {
            continue;
        };
        for fd in fds.flatten() {
            if let Ok(destino) = std::fs::read_link(fd.path()) {
                let destino_canon = std::fs::canonicalize(&destino).unwrap_or(destino);
                if destino_canon == objetivo {
                    let n = fd.file_name();
                    let info = std::fs::read_to_string(format!(
                        "/proc/{pid}/fdinfo/{}",
                        n.to_string_lossy()
                    ))
                    .unwrap_or_default();
                    eprintln!(
                        "[diag]   pid {pid} tiene abierto {} :: {}",
                        fd.path().display(),
                        info.replace('\n', " | ")
                    );
                }
            }
        }
    }
}

/// Recupera índice y `max_slot`, truncando una cola incompleta y rechazando corrupción en medio.
fn recuperar(
    fichero: &mut File,
    ruta: &Path,
) -> Result<(Indice, u64, u64), RegistroError> {
    let mut todo = Vec::new();
    fichero
        .seek(SeekFrom::Start(0))
        .and_then(|_| fichero.read_to_end(&mut todo))
        .map_err(|origen| RegistroError::Io {
            ruta: ruta.to_path_buf(),
            origen,
        })?;

    let cabecera = todo.get(..32).ok_or_else(|| RegistroError::Corrupto {
        ruta: ruta.to_path_buf(),
        offset: 0,
        bytes_perdidos: u64::try_from(todo.len()).unwrap_or(0),
    })?;
    if cabecera.get(..8) != Some(MAGIA.as_slice()) {
        return Err(RegistroError::MagiaInvalida {
            ruta: ruta.to_path_buf(),
        });
    }
    let version = leer_u64(cabecera.get(8..16));
    if version != VERSION_FORMATO {
        return Err(RegistroError::VersionInvalida {
            ruta: ruta.to_path_buf(),
            encontrada: version,
            esperada: VERSION_FORMATO,
        });
    }
    let max_slot_cabecera = leer_u64(cabecera.get(16..24));

    let mut indice = std::collections::HashMap::new();
    let mut max_slot = max_slot_cabecera;
    let mut offset = 32usize;
    let mut fin_valido = 32usize;
    while let Some(entrada) = todo.get(offset..offset + 80) {
        let c = comprobacion(entrada);
        if entrada.get(OFFSET_COMPROBACION..) != Some(c.as_slice()) {
            break;
        }
        let slot = leer_u64(entrada.get(0..8));
        let mut huella = [0u8; LONGITUD_HUELLA];
        if let Some(h) = entrada.get(OFFSET_HUELLA..OFFSET_HUELLA + LONGITUD_HUELLA) {
            huella.copy_from_slice(h);
        }
        let mut ph = [0u8; 32];
        if let Some(p) = entrada.get(OFFSET_PRE_HASH..OFFSET_PRE_HASH + 32) {
            ph.copy_from_slice(p);
        }
        indice.insert((huella, slot), PreHash::from_digest(zx_core::Digest::from_bytes(ph)));
        max_slot = max_slot.max(slot);
        offset += 80;
        fin_valido = offset;
    }

    if fin_valido < todo.len() {
        // ¿Cola incompleta (bytes a cero) o corrupción en medio? La diferencia importa: truncar
        // corrupción en medio perdería entradas posteriores, y olvidar una entrada es la única
        // forma de doble-firmar.
        let resto = todo.get(fin_valido..).unwrap_or(&[]);
        let no_cero = resto.iter().filter(|b| **b != 0).count();
        if no_cero > 0 {
            return Err(RegistroError::Corrupto {
                ruta: ruta.to_path_buf(),
                offset: u64::try_from(fin_valido).unwrap_or(0),
                bytes_perdidos: u64::try_from(no_cero).unwrap_or(0),
            });
        }
        // Cola a ceros: es una escritura que no llegó a completarse. Se trunca; el operador no
        // firmó nada de esa entrada porque el `fsync` nunca devolvió `Ok`.
        fichero
            .set_len(u64::try_from(fin_valido).unwrap_or(u64::MAX))
            .and_then(|()| fichero.sync_all())
            .map_err(|origen| RegistroError::Io {
                ruta: ruta.to_path_buf(),
                origen,
            })?;
    }

    let entradas = u64::try_from(indice.len()).unwrap_or(0);
    Ok((indice, max_slot, entradas))
}

fn leer_u64(bytes: Option<&[u8]>) -> u64 {
    let mut b = [0u8; 8];
    if let Some(s) = bytes
        && s.len() == 8
    {
        b.copy_from_slice(s);
    }
    u64::from_le_bytes(b)
}

#[cfg(test)]
#[expect(clippy::unwrap_used, reason = "los tests fallan con panic por diseño")]
mod tests {
    use super::{MAGIA, Registro, RegistroError, Resolucion, TAMANO_ENTRADA};
    use crate::identidad::IdentidadTicket;
    use std::io::{Seek, SeekFrom, Write};
    use zx_core::{ClavePublica, Digest, PreHash};

    fn id(chunk: u8, slot: u64) -> IdentidadTicket {
        IdentidadTicket::vigente(
            ClavePublica::desde_bytes([1u8; 32]),
            0,
            1 << 20,
            [chunk; 32],
            slot,
        )
    }

    fn ph(n: u8) -> PreHash {
        PreHash::from_digest(Digest::from_bytes([n; 32]))
    }

    #[test]
    fn entrada_nueva_conocida_y_conflicto() {
        let dir = tempfile::tempdir().unwrap();
        let reg = Registro::nueva(dir.path().join("r.log"), 150).unwrap();

        assert_eq!(reg.resolver(&id(1, 100), ph(1)).unwrap(), Resolucion::Nueva);
        assert_eq!(
            reg.resolver(&id(1, 100), ph(1)).unwrap(),
            Resolucion::Conocida
        );
        assert_eq!(
            reg.resolver(&id(1, 100), ph(2)).unwrap(),
            Resolucion::Conflicto {
                pre_hash_registrado: ph(1)
            }
        );
        // Y la clave incluye el slot: otra oportunidad no colisiona.
        assert_eq!(reg.resolver(&id(1, 101), ph(2)).unwrap(), Resolucion::Nueva);
        assert_eq!(reg.entradas(), 2);
    }

    #[test]
    fn sobrevive_a_reabrir() {
        let dir = tempfile::tempdir().unwrap();
        let ruta = dir.path().join("r.log");
        {
            let reg = Registro::nueva(&ruta, 150).unwrap();
            assert_eq!(reg.resolver(&id(1, 100), ph(1)).unwrap(), Resolucion::Nueva);
            assert_eq!(reg.resolver(&id(2, 140), ph(3)).unwrap(), Resolucion::Nueva);
        }
        let reg = Registro::abrir(&ruta, 140, 150).unwrap();
        assert_eq!(reg.entradas(), 2);
        assert_eq!(reg.max_slot(), 140);
        assert_eq!(
            reg.resolver(&id(1, 100), ph(9)).unwrap(),
            Resolucion::Conflicto {
                pre_hash_registrado: ph(1)
            }
        );
    }

    #[test]
    fn un_registro_creado_por_abrir_no_firma_antes_de_s_max() {
        let dir = tempfile::tempdir().unwrap();
        let reg = Registro::abrir(dir.path().join("r.log"), 1_000, 150).unwrap();
        assert!(reg.en_abstinencia(1_150));
        let e = reg.resolver(&id(1, 1_150), ph(1)).unwrap_err();
        assert!(matches!(e, RegistroError::EnAbstinencia { .. }));
        assert_eq!(reg.resolver(&id(1, 1_151), ph(1)).unwrap(), Resolucion::Nueva);
    }

    #[test]
    fn una_cola_a_ceros_se_trunca() {
        let dir = tempfile::tempdir().unwrap();
        let ruta = dir.path().join("r.log");
        {
            let reg = Registro::nueva(&ruta, 150).unwrap();
            assert_eq!(reg.resolver(&id(1, 100), ph(1)).unwrap(), Resolucion::Nueva);
        }
        // Simula una escritura a medias: media entrada más basura a cero.
        let mut f = std::fs::OpenOptions::new().write(true).open(&ruta).unwrap();
        f.seek(SeekFrom::End(0)).unwrap();
        f.write_all(&[0u8; 40]).unwrap();
        f.sync_all().unwrap();
        drop(f);

        let reg = Registro::abrir(&ruta, 100, 150).unwrap();
        assert_eq!(reg.entradas(), 1);
        assert_eq!(
            reg.tamano_bytes().unwrap(),
            super::TAMANO_CABECERA + TAMANO_ENTRADA
        );
    }

    #[test]
    #[expect(clippy::panic, reason = "el test falla con panic por diseño")]
    fn bytes_alterados_en_medio_fallan_cerrado() {
        let dir = tempfile::tempdir().unwrap();
        let ruta = dir.path().join("r.log");
        {
            let reg = Registro::nueva(&ruta, 150).unwrap();
            assert_eq!(reg.resolver(&id(1, 100), ph(1)).unwrap(), Resolucion::Nueva);
            assert_eq!(reg.resolver(&id(2, 200), ph(2)).unwrap(), Resolucion::Nueva);
        }
        // Un bit cambiado en la PRIMERA entrada, con una segunda válida detrás.
        let mut f = std::fs::OpenOptions::new().write(true).open(&ruta).unwrap();
        f.seek(SeekFrom::Start(super::TAMANO_CABECERA + 10)).unwrap();
        f.write_all(&[0xFF]).unwrap();
        f.sync_all().unwrap();
        drop(f);

        let e = Registro::abrir(&ruta, 200, 150).unwrap_err();
        match e {
            RegistroError::Corrupto { offset, .. } => {
                assert_eq!(offset, super::TAMANO_CABECERA);
            }
            otro => panic!("se esperaba Corrupto, llegó {otro:?}"),
        }
    }

    #[test]
    fn una_magia_ajena_se_rechaza() {
        let dir = tempfile::tempdir().unwrap();
        let ruta = dir.path().join("r.log");
        std::fs::write(&ruta, [0u8; 32]).unwrap();
        assert!(matches!(
            Registro::abrir(&ruta, 0, 150).unwrap_err(),
            RegistroError::MagiaInvalida { .. }
        ));
        assert_eq!(&MAGIA, b"ZXRGFIRM");
    }

    #[test]
    fn la_poda_tira_lo_que_ya_no_puede_colisionar() {
        let dir = tempfile::tempdir().unwrap();
        let reg = Registro::nueva(dir.path().join("r.log"), 150).unwrap();
        // Una entrada vieja y una reciente.
        assert_eq!(reg.resolver(&id(1, 100), ph(1)).unwrap(), Resolucion::Nueva);
        assert_eq!(reg.resolver(&id(2, 1_000), ph(2)).unwrap(), Resolucion::Nueva);
        assert_eq!(reg.umbral_poda(), 850);
        // 100 + 150 < 1000 ⇒ podable.
        assert_eq!(reg.podar().unwrap(), 1);
        assert_eq!(reg.entradas(), 1);
        // Pero la huella podada se recuerda como firmada: volver a verla sería un conflicto si
        // apareciera, y como ya no puede aparecer, tirarla es correcto.
        assert_eq!(reg.max_slot(), 1_000);
        assert_eq!(reg.resolver(&id(2, 1_000), ph(2)).unwrap(), Resolucion::Conocida);
    }

    #[test]
    fn el_bloqueo_entre_procesos_se_puede_probar_con_dos_descriptores() {
        // `flock` es por open file description: dos `File` distintos del mismo proceso SÍ chocan,
        // que es lo que permite probar aquí el camino de Bloqueado sin lanzar un proceso.
        let dir = tempfile::tempdir().unwrap();
        let ruta = dir.path().join("r.log");
        let _primero = Registro::nueva(&ruta, 150).unwrap();
        let segundo = Registro::nueva(&ruta, 150);
        assert!(matches!(segundo, Err(RegistroError::Bloqueado { .. })));
    }
}
