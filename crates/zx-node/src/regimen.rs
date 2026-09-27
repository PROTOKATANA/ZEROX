//! Fase PoST en régimen: hilo productor (decisión 3, 5 y 6; «Relanzamiento» punto 3).
//!
//! **Simplificación deliberada y documentada** (`PROGRESO.md`): la orden pide un hilo PoT y un hilo
//! granjero separados. Este ejecutor los fusiona en **un** hilo productor porque:
//!
//! 1. `zx_post::ServicioPot` no expone forma de inyectar una salida calculada en otro hilo (solo
//!    `avanzar`, que recalcula el AES); separarlos habría obligado a *recalcular* el mismo PoT dos
//!    veces (una por hilo) sin ganar concurrencia real.
//! 2. Auditar tres parcelas de 2 piezas cuesta milisegundos frente al ~1 s del PoT: no hay trabajo
//!    que valga la pena mover a un tercer hilo.
//! 3. Sin red (W06d1), el bucle de consenso no tiene ningún otro evento externo que atender durante
//!    el segundo del slot: la separación de responsabilidades que pide la orden importa para
//!    W06d2 (con red), no aquí.
//!
//! El bucle de consenso sigue siendo el único dueño de `zx-cadena`/`zx-storage`: este hilo solo
//! **pide** los padres canónicos (los calcula `zx-cadena` con el GHOSTDAG real) y **entrega**
//! bloques ya producidos para que el bucle los verifique y admita. Mantiene su **propia** copia
//! independiente de `ServicioPot`, arrancada del mismo terminal y el mismo `N_dev`: como el PoT es
//! una función determinista de `(terminal, N_dev)`, esta copia y la que usa el bucle para verificar
//! calculan exactamente las mismas salidas, sin compartir memoria ni bloquearse mutuamente.
//!
//! # Protocolo numerado (`ORDEN-W06d8`)
//!
//! Bajo cambio de terminal en caliente (`ORDEN-SL4b2` decisión 0) el bucle puede haber contestado ya
//! una petición que el hilo **abandonó** al recibir [`MsgBucle::CambiarTerminal`]; esa respuesta
//! atrasada llegaba después, donde el hilo esperaba otra cosa, y lo tiraba con un `panic!`
//! (`regimen.rs:438`, hallazgo de W07b). El protocolo ahora **numera** cada mensaje del hilo
//! (`PeticionPadres`, `Post`, `Abstenido`) con un `id: u64` creciente y el bucle devuelve ese `id`
//! en su respuesta (`Padres`, `Continuar`). Al esperar la respuesta `n`, el hilo:
//!
//! - **descarta** toda respuesta con `id < n` (es de una petición que ya abandonó) y escribe el
//!   evento de diagnóstico `productor_respuesta_descartada` con ambos `id`;
//! - atiende `Parar` **siempre**, sea cual sea el `id` pendiente;
//! - trata `id > n` (respuesta de una petición futura, imposible si el bucle responde en orden) como
//!   violación de invariante: envía [`MsgProductor::Fallo`] y termina **sin pánico**.
//!
//! [`MsgBucle::CambiarTerminal`] se sigue absorbiendo en el punto de espera, como antes.
//!
//! # Sin pánicos alcanzables
//!
//! Este módulo no usa `panic!`/`unreachable!`/`unwrap`/`expect`: cualquier fallo que el hilo no pueda
//! resolver (PoT que no avanza, padre ajeno sin información, producción que devuelve un error que no
//! es `SlotNoProgreso`, …) se convierte en [`MsgProductor::Fallo`], y el bucle lo traduce en el
//! evento crítico `fallo_productor` más una salida ≠ 0 (decisión 3 de `ORDEN-W06d8`). Nunca queda un
//! nodo que valida pero ha dejado de producir sin decirlo.

use std::cmp::Ordering;
use std::collections::BTreeSet;
use std::sync::mpsc::{Receiver, Sender};
use std::time::Instant;

use zx_core::wire_dag::BloqueDag;
use zx_core::{BlockHash, ClavePublica, PadresDag, Tx};
use zx_farmer::farmer::ParcelaDisco;
use zx_farmer::productor_poas::convertir_candidatos_locales;
use zx_poas::HistoriaGenesis;
use zx_post::firmante::{Firmante, Registro as RegistroFirmante};
use zx_post::productor::{
    FuenteSoluciones, MotivoAbstencion, ParametrosProductor, ProductoFirmado, SolucionCandidata,
};
use zx_post::productor_regimen::{CuerpoProductor, ErrorRegimen, producir_en_regimen_con_firmante};
use zx_post::servicio_pot::{ErrorServicioPot, ServicioPot};

use crate::claves::ClaveDev;
use crate::registro::Registro;

/// Puente `FuenteSoluciones → ParcelaDisco`, igual que `crates/zx-post/tests/regimen.rs`.
struct FuenteParcela<'a> {
    parcela: &'a ParcelaDisco,
    historia: &'a HistoriaGenesis,
}

impl FuenteSoluciones for FuenteParcela<'_> {
    type Error = zx_farmer::ErrorProductorPoas;

    fn soluciones(
        &self,
        salida: [u8; 16],
        slot: u64,
        rango: u64,
    ) -> Result<Vec<SolucionCandidata>, Self::Error> {
        let params = self.historia.params_pieza();
        let resultado = convertir_candidatos_locales(
            self.parcela,
            salida,
            slot,
            rango,
            &params,
            self.historia.kzg(),
            self.historia.erasure_coding(),
        )?;
        Ok(resultado
            .soluciones()
            .iter()
            .map(|c| SolucionCandidata {
                solucion: *c.solucion(),
                distancia: c.distancia(),
            })
            .collect())
    }
}

/// Mensajes que el hilo productor envía al bucle.
pub enum MsgProductor {
    /// Pide los padres canónicos actuales de un bloque de régimen, para el `slot` dado (decisión 4
    /// de `ORDEN-SL4b2`: el bucle necesita el slot objetivo para filtrar qué evidencias pendientes
    /// tienen la ventana abierta en el bloque que se va a construir). `id` numera la petición: la
    /// respuesta debe traerlo de vuelta.
    PeticionPadres {
        /// Identificador creciente de la petición.
        id: u64,
        /// Slot objetivo del bloque que se va a construir.
        slot: u64,
    },
    /// Un bloque PoST ya producido y firmado, para verificar y admitir, junto con el instante en
    /// que este hilo obtuvo la salida PoT del slot (`ORDEN-W07a`: `retraso_slot_ns`). `id` numera el
    /// envío: la respuesta (`Continuar`/`Parar`) debe traerlo de vuelta.
    Post {
        /// Identificador creciente del envío.
        id: u64,
        /// Bloque producido.
        bloque: Box<BloqueDag>,
        /// Instante en que se obtuvo la salida PoT del slot.
        instante_salida: Instant,
    },
    /// `ORDEN-SL4b2` decisión 2: el firmante seguro se abstuvo para esta candidata (conflicto de
    /// identidad o pérdida de registro): no se produjo bloque. El bucle escribe el evento
    /// `firmante_abstenido` (esquema v1, crítico) y contesta [`MsgBucle::Continuar`]: el nodo sigue
    /// validando y propagando, solo no produce esta oportunidad.
    Abstenido {
        /// Identificador creciente del envío.
        id: u64,
        /// Slot de la candidata abstenida.
        slot: u64,
        /// Causa de la abstención.
        motivo: MotivoAbstencion,
    },
    /// `ORDEN-W06d8` decisión 3: el hilo productor detectó una violación de invariante (o un fallo
    /// interno irrecuperable) y termina. El bucle escribe el evento crítico `fallo_productor` con el
    /// motivo y devuelve error: el proceso sale con código ≠ 0, nunca en silencio ni a medias.
    Fallo {
        /// Motivo legible de la parada.
        motivo: String,
    },
}

/// Respuestas del bucle al hilo productor.
#[expect(
    clippy::large_enum_variant,
    reason = "un mensaje por producción intentada (~1/s); boxear `PadresDag` (Copy, 481 B) solo movería el coste a una asignación de montón sin beneficio medible"
)]
pub enum MsgBucle {
    /// Padres canónicos (`padres::padres_de_regimen`), con `(hash, slot)` de **cada** padre
    /// (seleccionado y extras). `id` es el de la `PeticionPadres` a la que responde.
    ///
    /// `ORDEN-W06d3`, hallazgo en vivo (`PROGRESO.md`): con red, un padre puede ser un bloque
    /// **ajeno** que este proceso nunca produjo — el bucle lo admitió y lo conoce (`Cadena`,
    /// `self.servicio_verificacion`), pero el `ServicioPot` **propio** del hilo productor (una
    /// copia independiente, ver el docstring del módulo) nunca lo vio, porque solo se actualiza
    /// cuando el propio hilo produce un bloque (`registrar_validado`, más abajo). Sin esta
    /// información, `producir_en_regimen` fallaba con «el padre seleccionado no está registrado en
    /// el `ServicioPot`» en cuanto GHOSTDAG elegía un padre de otro nodo.
    ///
    /// `ORDEN-W06d5` decisión 1: además, las claves (entre las que gestiona el hilo) con garantía
    /// activa `>= q` en `Estado(padre_seleccionado)` — RD-9. El bucle las calcula porque solo él
    /// tiene `Cadena`/`params.q`; el hilo nunca intenta `producir_en_regimen` para una clave que no
    /// esté en este conjunto (causa de `ErrGarantia` fatal en V5 de `REVISION-W06d4.md`).
    Padres {
        /// `id` de la `PeticionPadres` a la que responde.
        id: u64,
        /// Padres canónicos del bloque.
        padres: PadresDag,
        /// `(hash, slot)` de cada padre (seleccionado y extras).
        info_padres: Vec<(BlockHash, u64)>,
        /// Claves con garantía activa `>= q` en el estado del padre seleccionado.
        con_garantia: BTreeSet<ClavePublica>,
        /// `ORDEN-SL4b2` decisión 4: hasta `MAX_EVIDENCIAS_POR_BLOQUE` `EvidenceTx` pendientes que
        /// el bucle ya filtró (incidente no procesado en el estado sobre el que se construye,
        /// ventana abierta en `slot_objetivo`). El hilo las mete en el cuerpo tal cual, sin volver
        /// a decidir nada sobre ellas.
        evidencias: Vec<Tx>,
    },
    /// El bloque o la abstención enviados se procesaron: sigue produciendo. `id` es el del mensaje
    /// (`Post` o `Abstenido`) al que responde.
    Continuar {
        /// `id` del `Post`/`Abstenido` al que responde.
        id: u64,
    },
    /// Condición de parada alcanzada (`--parada-tras-slots`): el hilo debe terminar. No lleva `id`:
    /// se atiende siempre, sea cual sea la respuesta que el hilo esperaba.
    Parar,
    /// `ORDEN-SL4b2` decisión 0: el terminal **seleccionado** cambió mientras el hilo producía
    /// (FC-3, `ORDEN-W06d7`). El bucle manda el `ServicioPot` de verificación del nuevo terminal
    /// (ya avanzado con toda su historia admitida): el hilo lo adopta como su propio `ServicioPot`
    /// de régimen y abandona cualquier candidata/petición en vuelo del terminal anterior (esas
    /// candidatas pertenecían a un flujo PoT que ya no es el seleccionado; perder esa única
    /// oportunidad de slot es preferible a mezclar dos terminales en un mismo bloque, `ErrTerminalAmbiguo`/I-4).
    /// Puede llegar en cualquier punto de espera del hilo, incluso en medio de un intercambio
    /// `PeticionPadres`/`Post`.
    CambiarTerminal(ServicioPot),
}

/// Payload de una respuesta `Padres`, boxeado dentro de [`Recepcion`]: el `PadresDag` (481 B) más
/// los vectores harían que todas las variantes del enum cargasen ~560 B aunque la respuesta sea un
/// `Continuar`/`Parar` de 8 B (mismo criterio que el `Box` del mensaje del bucle).
struct PadresRecibidos {
    /// Padres canónicos.
    padres: PadresDag,
    /// `(hash, slot)` de cada padre.
    info_padres: Vec<(BlockHash, u64)>,
    /// Claves con garantía activa `>= q`.
    con_garantia: BTreeSet<ClavePublica>,
    /// Evidencias ya filtradas por el bucle.
    evidencias: Vec<Tx>,
}

/// Resultado de esperar una respuesta del bucle con el `id` esperado (o de absorber un cambio de
/// terminal). Ver el docstring del módulo para la regla de descarte.
enum Recepcion {
    /// Respuesta `Padres` con el `id` esperado.
    Padres(Box<PadresRecibidos>),
    /// Respuesta `Continuar` con el `id` esperado.
    Continuar,
    /// El bucle pidió parar; se atiende siempre.
    Parar,
    /// Se aplicó un cambio de terminal: el hilo debe abandonar el intercambio en curso y volver al
    /// principio de su bucle principal (el próximo `avanzar()` ya usa el `ServicioPot` nuevo).
    Interrumpido,
    /// El bucle cerró el canal: apagado normal del proceso.
    Cerrado,
    /// Violación de invariante del protocolo: el hilo debe terminar con [`MsgProductor::Fallo`].
    Violacion(String),
}

/// Escribe el evento de diagnóstico de una respuesta atrasada descartada, con ambos `id`.
fn registrar_descarte(registro: &Registro, id_esperado: u64, id_recibido: u64) {
    let _ = registro.escribir(
        registro
            .evento("productor_respuesta_descartada")
            .u64("id_esperado", id_esperado)
            .u64("id_recibido", id_recibido),
        false,
    );
}

/// `ORDEN-W06d9` decisión 2(b): escribe el evento de diagnóstico `produccion_omitida` con el slot y
/// el motivo. No es un evento crítico: el nodo sigue validando y produciendo en los slots
/// siguientes; solo deja de producir este bloque, que no puede justificar con esos padres.
fn registrar_produccion_omitida(registro: &Registro, slot: u64, motivo: &str) {
    let _ = registro.escribir(
        registro
            .evento("produccion_omitida")
            .u64("slot", slot)
            .str("motivo", motivo),
        false,
    );
}

/// `ORDEN-W06d9` decisión 2: clasifica un fallo de `producir_en_regimen_con_firmante` como una
/// **producción omitible** (no se pudo justificar el bloque con esos padres: hueco de portadores no
/// recomputable o rango fuera del formato) o como un fallo interno que sí debe tumbar al productor.
///
/// Un portador ausente **no** es una violación de invariante del productor (decisión 2): se omite la
/// producción de ese slot y se sigue. Cualquier otro error sigue siendo `fallo_productor`.
fn motivo_produccion_omitida<E>(error: &ErrorRegimen<E>) -> Option<String>
where
    E: std::error::Error + 'static,
{
    match error {
        ErrorRegimen::Servicio(ErrorServicioPot::PortadorAusente { slot }) => {
            Some(format!("portador ausente para el slot {slot}"))
        }
        ErrorRegimen::Servicio(ErrorServicioPot::RecompletarExcedeMaximo {
            base_slot,
            d,
            max,
            ..
        }) => Some(format!(
            "no se pudo recompletar el rango de portadores: la salida conocida más cercana está en \
             el slot {base_slot} (distancia {d} > MAX_BUNDLES_POT={max})"
        )),
        ErrorRegimen::RangoExcedeMaximo { d, max } => {
            Some(format!("el rango {d} excede MAX_BUNDLES_POT={max}"))
        }
        _ => None,
    }
}

/// Espera el próximo mensaje del bucle aplicando la regla del protocolo numerado: descarta
/// respuestas atrasadas (`id <` el esperado, con evento de diagnóstico), atiende `Parar` siempre,
/// absorbe [`MsgBucle::CambiarTerminal`] en el sitio (decisión 0) y declara violación de invariante
/// una respuesta con `id` del futuro (`>`). Nunca entra en pánico.
fn esperar(
    rx: &Receiver<MsgBucle>,
    servicio: &mut ServicioPot,
    registro: &Registro,
    id_esperado: u64,
) -> Recepcion {
    loop {
        match rx.recv() {
            Err(_) => return Recepcion::Cerrado,
            Ok(MsgBucle::CambiarTerminal(nuevo)) => {
                *servicio = nuevo;
                return Recepcion::Interrumpido;
            }
            Ok(MsgBucle::Parar) => return Recepcion::Parar,
            Ok(MsgBucle::Padres {
                id,
                padres,
                info_padres,
                con_garantia,
                evidencias,
            }) => match id.cmp(&id_esperado) {
                Ordering::Less => {
                    registrar_descarte(registro, id_esperado, id);
                    continue;
                }
                Ordering::Greater => {
                    return Recepcion::Violacion(format!(
                        "el bucle respondió `Padres` con id {id} > esperado {id_esperado}: \
                         respuestas fuera de orden"
                    ));
                }
                Ordering::Equal => {
                    return Recepcion::Padres(Box::new(PadresRecibidos {
                        padres,
                        info_padres,
                        con_garantia,
                        evidencias,
                    }));
                }
            },
            Ok(MsgBucle::Continuar { id }) => match id.cmp(&id_esperado) {
                Ordering::Less => {
                    registrar_descarte(registro, id_esperado, id);
                    continue;
                }
                Ordering::Greater => {
                    return Recepcion::Violacion(format!(
                        "el bucle respondió `Continuar` con id {id} > esperado {id_esperado}: \
                         respuestas fuera de orden"
                    ));
                }
                Ordering::Equal => return Recepcion::Continuar,
            },
        }
    }
}

/// Envía al bucle una parada ordenada por violación de invariante (decisión 3). Si el canal ya
/// está cerrado, el bucle ya terminó: no hay nada más que hacer.
fn reportar_fallo(tx: &Sender<MsgProductor>, motivo: String) {
    let _ = tx.send(MsgProductor::Fallo { motivo });
}

/// Una clave dev con su parcela ya abierta.
pub struct ClaveConParcela {
    /// La clave.
    pub clave: ClaveDev,
    /// Su parcela.
    pub parcela: ParcelaDisco,
}

/// Cuerpo del hilo productor en régimen.
///
/// Cada slot: avanza el PoT, audita las parcelas locales, y si hay solución para alguna clave, pide
/// los padres **una sola vez** para todo el slot (los hermanos del mismo slot comparten padres: si
/// se pidieran de nuevo tras admitir el primero, el segundo podría heredarlo como `sp` del mismo
/// slot y `producir_en_regimen` lo rechazaría con `SlotNoProgreso`) y produce un bloque por clave
/// ganadora.
///
/// Termina cuando `parada_tras_slots` se alcanza, cuando el bucle contesta [`MsgBucle::Parar`],
/// cuando el canal con el bucle se cierra (fin del proceso) o cuando detecta una violación de
/// invariante (envía [`MsgProductor::Fallo`] y devuelve).
#[expect(
    clippy::too_many_arguments,
    reason = "el estado de arranque de régimen ya viene mínimo; agruparlo ocultaría su procedencia"
)]
pub fn hilo_productor_regimen(
    mut servicio: ServicioPot,
    n_dev: u64,
    sr_dev: u64,
    cbid: u32,
    importe_coinbase: zx_core::Amount,
    claves: Vec<ClaveConParcela>,
    historia: &HistoriaGenesis,
    parada_tras_slots: Option<u64>,
    rx: &Receiver<MsgBucle>,
    tx: &Sender<MsgProductor>,
    registro_firmante: &RegistroFirmante,
    registro: &Registro,
) {
    // `ORDEN-SL4b2` decisión 2: el nodo produce **solo** con el firmante seguro (`C-EVP-06`,
    // FIR-01…FIR-15); un único `Firmante` para las tres claves del nodo, porque el registro es
    // único por nodo (la identidad RAT-1 ya distingue `public_key`, FIR-02).
    let mut firmante = Firmante::nuevo(registro_firmante);
    // `servicio` es un **clon** del `ServicioPot` de verificación del bucle (`Nodo::
    // servicio_verificacion`), no uno construido desde cero: ya trae registrado el terminal y
    // *todo* bloque PoST admitido hasta ahora (el de transición si acaba de producirse, o toda la
    // historia de régimen si `fase_regimen` arranca tras un reinicio). Construir uno nuevo con
    // `ServicioPot::nuevo(terminal, ...)` aquí fue el bug real de la primera ejecución de V4
    // (`PROGRESO.md`): el hilo no conocía el bloque de transición, `slot_de(padre)` fallaba siempre
    // y `producir_en_regimen` fallaba en silencio para cada intento.
    let parametros = ParametrosProductor {
        n_dev,
        sr_dev,
        max_slots: 150,
        consensus_branch_id: cbid,
        timestamp: 0,
        importe_coinbase,
    };

    // `ORDEN-W06d8` decisión 1: contador creciente de mensajes enviados al bucle. `wrapping_add` es
    // deliberado: llegar a 2^64 mensajes (~5.8·10^11 años a un mensaje por segundo) es inalcanzable,
    // y así ni el modo debug (comprobación de desbordamiento) puede entrar en pánico por el `id`.
    let mut proximo_id: u64 = 0;

    'outer: loop {
        if let Some(limite) = parada_tras_slots
            && servicio.slot_actual() >= limite
        {
            return;
        }
        // `avanzar()` solo falla por desbordamiento aritmético de slot o si la primitiva PoT
        // rechaza una terna con `N_dev` válido: ninguno de los dos debería ocurrir aquí. Un fallo
        // real es un bug, no un cierre limpio: se reporta al bucle (`fallo_productor`) en vez de
        // terminar en silencio (el bug real de la primera ejecución de V4 fue exactamente un hilo que
        // moría sin decir por qué).
        let slot = match servicio.avanzar() {
            Ok(slot) => slot,
            Err(e) => {
                reportar_fallo(tx, format!("avanzar el PoT falló: {e}"));
                return;
            }
        };
        // `ORDEN-W07a`: instante en que este hilo tuvo la salida PoT del slot, para `retraso_slot_ns`.
        let instante_salida = Instant::now();
        let salida = match servicio.salida_de(slot) {
            Ok(salida) => salida,
            Err(e) => {
                reportar_fallo(tx, format!("salida del slot {slot} ausente: {e}"));
                return;
            }
        };

        // Audita las tres parcelas locales en este mismo hilo (ver la nota de simplificación). Un
        // candidato sin solución no es error (contrato de `FuenteSoluciones`); un `Err` de la
        // auditoría sí lo es y se reporta, no se trata como «sin solución».
        let mut ganadoras: Vec<(usize, SolucionCandidata)> = Vec::new();
        for (i, cp) in claves.iter().enumerate() {
            let fuente = FuenteParcela {
                parcela: &cp.parcela,
                historia,
            };
            let mut candidatas = match fuente.soluciones(salida, slot, sr_dev) {
                Ok(candidatas) => candidatas,
                Err(e) => {
                    reportar_fallo(tx, format!("auditoría de la clave {i}: {e}"));
                    return;
                }
            };
            if let Some(c) = candidatas.pop() {
                ganadoras.push((i, c));
            }
        }
        if ganadoras.is_empty() {
            continue;
        }

        let id_peticion = proximo_id;
        proximo_id = proximo_id.wrapping_add(1);
        if tx
            .send(MsgProductor::PeticionPadres {
                id: id_peticion,
                slot,
            })
            .is_err()
        {
            return; // el bucle cerró el canal: apagado normal del proceso.
        }
        let (padres, info_padres, con_garantia, evidencias) =
            match esperar(rx, &mut servicio, registro, id_peticion) {
                Recepcion::Padres(p) => {
                    let PadresRecibidos {
                        padres,
                        info_padres,
                        con_garantia,
                        evidencias,
                    } = *p;
                    (padres, info_padres, con_garantia, evidencias)
                }
                Recepcion::Continuar => {
                    reportar_fallo(
                        tx,
                        format!(
                            "se esperaba `Padres` para el id {id_peticion} y llegó `Continuar`"
                        ),
                    );
                    return;
                }
                // Decisión 0: el terminal cambió antes de que el bucle contestara esta petición
                // (era del terminal anterior). Se abandona esta candidata/slot sin fingir una
                // respuesta: el próximo `avanzar()` ya corre sobre el `ServicioPot` del terminal
                // nuevo.
                Recepcion::Interrumpido => continue 'outer,
                Recepcion::Parar => return,
                Recepcion::Cerrado => return, // el bucle cerró el canal: apagado normal del proceso.
                Recepcion::Violacion(motivo) => {
                    reportar_fallo(tx, motivo);
                    return;
                }
            };
        // `ORDEN-W06d5` decisión 2 (`REVISION-W06d4.md`, V5-2): el padre seleccionado que incumple
        // `slot(padre) < slot_objetivo` ya lo descarta con gracia `producir_en_regimen` más abajo
        // (`ErrorRegimen::SlotNoProgreso`), pero ese cheque **no** cubre los padres extra del
        // mergeset GHOSTDAG (`C-HDR-05`/`C-FLU-02`: la regla alcanza a **todos** los padres). Se
        // excluyen aquí, antes de construir ningún bloque, en vez de descubrirlo en la verificación
        // completa (donde, al ser un bloque propio, era fatal).
        let padres = match filtrar_padres_extra_por_slot(padres, &info_padres, slot) {
            Ok(padres) => padres,
            Err(motivo) => {
                reportar_fallo(tx, motivo);
                return;
            }
        };
        // Registra en el `ServicioPot` propio cualquier padre que este hilo no haya producido él
        // mismo (ver el docstring de `MsgBucle::Padres`). `BloqueDuplicado` es el caso normal (un
        // padre que sí produjo este mismo hilo, o que ya se registró en una vuelta anterior porque
        // dos candidatas del mismo slot comparten padres): no es un error, es la confirmación de que
        // ya estaba. Cualquier otro fallo (`SlotFuturo`, `NDevInvalido`) sí es una incoherencia real.
        for (hash, slot_padre) in info_padres {
            // El flujo PoT es único y global (D-P10): si un padre ajeno viene de un slot **más
            // adelantado** que el que este hilo lleva calculado localmente (su propio `avanzar()`
            // va a su propio ritmo de AES, independiente de qué tan rápido admita el bucle
            // principal bloques de red ya calculados por otros), `avanzar_hasta` recalcula de
            // verdad las salidas que faltan —no las inventa ni las salta— hasta alcanzarlo. Es el
            // mismo coste que ya paga el flujo normal, solo que de golpe en vez de un slot por
            // vuelta.
            if slot_padre > servicio.slot_actual()
                && let Err(e) = servicio.avanzar_hasta(slot_padre)
            {
                reportar_fallo(
                    tx,
                    format!("no se pudo alcanzar el slot {slot_padre} del padre ajeno {hash}: {e}"),
                );
                return;
            }
            match servicio.registrar_validado(hash, slot_padre) {
                Ok(()) | Err(zx_post::servicio_pot::ErrorServicioPot::BloqueDuplicado { .. }) => {}
                Err(e) => {
                    reportar_fallo(
                        tx,
                        format!(
                            "no se pudo registrar el padre ajeno {hash} (slot {slot_padre}): {e}"
                        ),
                    );
                    return;
                }
            }
        }

        for (i, candidata) in ganadoras {
            let Some(cp) = claves.get(i) else {
                // Invariante del propio código (`i` sale de `claves.iter().enumerate()`): se
                // defiende sin pánico por si un cambio futuro rompe esa garantía.
                tracing::error!(indice = i, "candidata con índice de clave fuera de rango");
                continue;
            };
            // `ORDEN-W06d5` decisión 1 (`REVISION-W06d4.md`, V5-1): «producir solo con garantía».
            // No se **intenta** `producir_en_regimen` para una clave sin garantía activa `>= q` en
            // el estado de la punta elegida: intentarlo de todos modos solo para que el motor lo
            // rechace con `ErrGarantia` (fatal, decisión 4 de `ORDEN-W06d1`) es exactamente el
            // hallazgo V5-1 (un nodo que sincroniza tarde, con una clave nueva que nunca depositó).
            if !con_garantia.contains(&cp.clave.pk) {
                tracing::info!(
                    indice = i,
                    clave = ?cp.clave.pk,
                    slot,
                    "candidata descartada: la clave no tiene garantía activa >= q en el estado \
                     de la punta elegida (RD-9); no se intenta producir"
                );
                continue;
            }
            let mut parametros_bloque = parametros;
            parametros_bloque.timestamp = std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .map(|d| d.as_secs())
                .unwrap_or(0);
            let fuente_fija = SolucionFija(candidata);
            // `ORDEN-SL4b2` decisión 4: hasta `MAX_EVIDENCIAS_POR_BLOQUE` `EvidenceTx` ya
            // filtradas por el bucle (`evidencias`, de `MsgBucle::Padres`); ninguna lleva testigos
            // (EV-01: sin entradas, salidas ni testigos de transacción).
            let testigos_evidencias = vec![Vec::new(); evidencias.len()];
            let cuerpo = match CuerpoProductor::nuevo(evidencias.clone(), testigos_evidencias) {
                Ok(cuerpo) => cuerpo,
                Err(e) => {
                    reportar_fallo(tx, format!("cuerpo con evidencias del bucle inválido: {e}"));
                    return;
                }
            };
            let producto = match producir_en_regimen_con_firmante(
                padres,
                slot,
                &mut servicio,
                &fuente_fija,
                &cp.clave.sk,
                &parametros_bloque,
                cuerpo,
                &mut firmante,
            ) {
                Ok(p) => p,
                // `ORDEN-W06d3`, hallazgo en vivo (`PROGRESO.md`): con red, el padre elegido por
                // GHOSTDAG puede ser un bloque **más nuevo** que `slot` (otro nodo ya produjo, para
                // el mismo slot o uno posterior, con el padre que este hilo eligió cuando pidió
                // `PeticionPadres` — el propio catch-up de arriba, que adelanta `servicio` hasta el
                // slot del padre, es la prueba de que esto es normal, no un error). No es un bug de
                // este nodo: el candidato ya no puede ser un bloque de cadena válido (`slot(B)` MUST
                // ser mayor que `slot(sp)`), así que se descarta esta candidata concreta y se sigue
                // con la siguiente (o con el siguiente slot si no hay más). Cualquier otro error de
                // `producir_en_regimen_con_firmante` sigue siendo una incoherencia interna real y se
                // reporta al bucle.
                Err(zx_post::productor_regimen::ErrorRegimen::SlotNoProgreso {
                    slot: slot_bloque,
                    slot_sp,
                }) => {
                    tracing::info!(
                        slot_bloque,
                        slot_sp,
                        "candidata descartada: el padre elegido ya es de este slot o uno \
                         posterior (otro nodo se adelantó)"
                    );
                    continue;
                }
                Err(e) => {
                    // `ORDEN-W06d9` decisión 2: un hueco de portadores que no se pudo recompletar
                    // (o un rango fuera de formato) no es una violación de invariante del productor:
                    // el bloque no se puede justificar con esos padres, así que se omite la
                    // producción de este slot con diagnóstico y se sigue con el siguiente. Cualquier
                    // otro error sigue siendo un fallo interno del productor.
                    if let Some(motivo) = motivo_produccion_omitida(&e) {
                        registrar_produccion_omitida(registro, slot, &motivo);
                        continue 'outer;
                    }
                    reportar_fallo(tx, format!("producir_en_regimen_con_firmante falló: {e}"));
                    return;
                }
            };
            // `ORDEN-SL4b2` decisión 2: el firmante puede negarse (conflicto de identidad o
            // pérdida de registro, FIR-01…FIR-10). No es un error: se avisa al bucle
            // (`firmante_abstenido`, esquema v1) y se sigue con la siguiente candidata/slot, sin
            // producir esta.
            let bloque = match producto {
                ProductoFirmado::Bloque(b, _resultado_firmante) => b,
                ProductoFirmado::Abstenido { motivo, .. } => {
                    let id_abstenido = proximo_id;
                    proximo_id = proximo_id.wrapping_add(1);
                    if tx
                        .send(MsgProductor::Abstenido {
                            id: id_abstenido,
                            slot,
                            motivo,
                        })
                        .is_err()
                    {
                        return; // el bucle cerró el canal: apagado normal del proceso.
                    }
                    match esperar(rx, &mut servicio, registro, id_abstenido) {
                        Recepcion::Continuar => continue,
                        Recepcion::Parar => return,
                        Recepcion::Cerrado => return,
                        Recepcion::Interrumpido => continue 'outer,
                        Recepcion::Padres(..) => {
                            reportar_fallo(
                                tx,
                                format!(
                                    "se esperaba `Continuar`/`Parar` tras `Abstenido` (id \
                                     {id_abstenido}) y llegó `Padres`"
                                ),
                            );
                            return;
                        }
                        Recepcion::Violacion(motivo) => {
                            reportar_fallo(tx, motivo);
                            return;
                        }
                    }
                }
            };
            let hash = bloque.cabecera.block_hash();
            if let Err(e) = servicio.registrar_validado(hash, slot) {
                reportar_fallo(tx, format!("registrar el bloque producido: {e}"));
                return;
            }

            let id_post = proximo_id;
            proximo_id = proximo_id.wrapping_add(1);
            if tx
                .send(MsgProductor::Post {
                    id: id_post,
                    bloque: Box::new(bloque),
                    instante_salida,
                })
                .is_err()
            {
                return; // el bucle cerró el canal: apagado normal del proceso.
            }
            match esperar(rx, &mut servicio, registro, id_post) {
                Recepcion::Continuar => {}
                Recepcion::Parar => return,
                // Decisión 0: el bloque ya se mandó y el bucle puede haberlo admitido igualmente
                // (es válido en su propio terminal, aunque ya no sea el seleccionado); se abandona
                // el resto de candidatas de este slot (sus `padres` pertenecen al terminal
                // anterior) y el siguiente `avanzar()` ya corre sobre el `ServicioPot` nuevo. Si
                // `parada_tras_slots` se hubiera alcanzado, el chequeo de cabecera de bucle lo
                // detiene.
                Recepcion::Interrumpido => continue 'outer,
                Recepcion::Cerrado => return,
                Recepcion::Padres(..) => {
                    reportar_fallo(
                        tx,
                        format!(
                            "se esperaba `Continuar`/`Parar` tras `Post` (id {id_post}) y llegó \
                             `Padres`"
                        ),
                    );
                    return;
                }
                Recepcion::Violacion(motivo) => {
                    reportar_fallo(tx, motivo);
                    return;
                }
            }
        }
    }
}

/// `ORDEN-W06d5` decisión 2: reconstruye `padres` excluyendo cualquier padre **extra** cuyo `slot`
/// no sea anterior a `slot_objetivo` (`C-HDR-05`/`C-FLU-02`: la cota alcanza a todos los padres, no
/// solo al seleccionado). El padre seleccionado no se toca aquí — si él mismo incumple la cota, lo
/// descarta con gracia `producir_en_regimen` (`ErrorRegimen::SlotNoProgreso`), más abajo.
///
/// `info_padres` **MUST** traer el slot de cada padre (seleccionado y extras): lo construye el
/// bucle a partir de `Cadena::bloque`, que siempre lo conoce para un padre de régimen ya admitido
/// (docstring de [`MsgBucle::Padres`]). Su ausencia se devuelve como error explícito (el llamante lo
/// convierte en `fallo_productor`), nunca como pánico.
fn filtrar_padres_extra_por_slot(
    padres: PadresDag,
    info_padres: &[(BlockHash, u64)],
    slot_objetivo: u64,
) -> Result<PadresDag, String> {
    let seleccionado = padres.seleccionado();
    let mut extras_validos: Vec<BlockHash> = Vec::with_capacity(padres.extras().len());
    for h in padres.extras() {
        let Some(&(_, slot_padre)) = info_padres.iter().find(|(hp, _)| hp == h) else {
            return Err(format!("padre extra {h} sin información de slot del bucle"));
        };
        if slot_padre >= slot_objetivo {
            tracing::info!(
                padre = ?h,
                slot_padre,
                slot_objetivo,
                "padre extra descartado: su slot no es anterior al del bloque objetivo"
            );
        } else {
            extras_validos.push(*h);
        }
    }
    PadresDag::nuevo(seleccionado, &extras_validos)
        .map_err(|e| format!("reconstruir PadresDag tras filtrar padres extra: {e}"))
}

/// Fuente de soluciones que siempre devuelve la misma candidata ya auditada (evita volver a auditar
/// la parcela al construir el bloque: la auditoría ya se hizo una vez por slot, arriba).
struct SolucionFija(SolucionCandidata);

impl FuenteSoluciones for SolucionFija {
    type Error = std::convert::Infallible;

    fn soluciones(
        &self,
        _salida: [u8; 16],
        _slot: u64,
        _rango: u64,
    ) -> Result<Vec<SolucionCandidata>, Self::Error> {
        Ok(vec![self.0])
    }
}

/// `ORDEN-W06d6` decisión 5: test pendiente de `ORDEN-W06d5` decisión 2 (padres extra) —
/// `filtrar_padres_extra_por_slot` es la función que la implementa; se probaba solo con ejecuciones
/// reales (V6(b)), sin test unitario.
#[cfg(test)]
#[expect(clippy::unwrap_used, reason = "el test falla con panic por diseño")]
mod tests_filtrar_padres_extra {
    use zx_core::digest::Digest;
    use zx_core::{BlockHash, PadresDag};

    use super::filtrar_padres_extra_por_slot;

    fn h(n: u8) -> BlockHash {
        BlockHash::from_digest(Digest::from_bytes([n; 32]))
    }

    /// Un padre extra cuyo slot **no** es anterior al objetivo (`>=`) se descarta; uno anterior se
    /// conserva. El seleccionado nunca se toca aquí (lo descarta `producir_en_regimen` con gracia,
    /// no este filtro).
    #[test]
    fn descarta_solo_los_extras_cuyo_slot_no_es_anterior_al_objetivo() {
        let seleccionado = h(1);
        let extra_valido = h(2); // slot 5 < 10: se conserva.
        let extra_igual = h(3); // slot 10 == 10: se descarta (no es "anterior").
        let extra_posterior = h(4); // slot 11 > 10: se descarta.

        let padres =
            PadresDag::nuevo(seleccionado, &[extra_valido, extra_igual, extra_posterior]).unwrap();
        let info_padres = vec![
            (seleccionado, 3), // el slot del seleccionado no importa a este filtro.
            (extra_valido, 5),
            (extra_igual, 10),
            (extra_posterior, 11),
        ];

        let filtrados = filtrar_padres_extra_por_slot(padres, &info_padres, 10).unwrap();

        assert_eq!(
            filtrados.seleccionado(),
            seleccionado,
            "el seleccionado no se toca"
        );
        assert_eq!(
            filtrados.extras(),
            &[extra_valido],
            "solo sobrevive el extra con slot estrictamente anterior al objetivo"
        );
    }

    /// Sin ningún extra que filtrar, la reconstrucción es un no-op.
    #[test]
    fn sin_extras_no_cambia_nada() {
        let seleccionado = h(9);
        let padres = PadresDag::nuevo(seleccionado, &[]).unwrap();
        let filtrados = filtrar_padres_extra_por_slot(padres, &[(seleccionado, 1)], 100).unwrap();
        assert_eq!(filtrados.seleccionado(), seleccionado);
        assert!(filtrados.extras().is_empty());
    }

    /// Todos los extras por debajo del objetivo: ninguno se descarta.
    #[test]
    fn todos_los_extras_anteriores_sobreviven() {
        let seleccionado = h(1);
        let e1 = h(2);
        let e2 = h(3);
        let padres = PadresDag::nuevo(seleccionado, &[e1, e2]).unwrap();
        let info = vec![(seleccionado, 0), (e1, 1), (e2, 2)];
        let filtrados = filtrar_padres_extra_por_slot(padres, &info, 100).unwrap();
        let mut extras = filtrados.extras().to_vec();
        extras.sort();
        let mut esperado = vec![e1, e2];
        esperado.sort();
        assert_eq!(extras, esperado);
    }

    /// Un extra sin información de slot no es un pánico: se devuelve el motivo (el llamante lo
    /// convierte en `fallo_productor`, decisión 3).
    #[test]
    fn extra_sin_informacion_es_error_explicito() {
        let seleccionado = h(1);
        let extra = h(2);
        let padres = PadresDag::nuevo(seleccionado, &[extra]).unwrap();
        let err = filtrar_padres_extra_por_slot(padres, &[(seleccionado, 0)], 10).unwrap_err();
        assert!(err.contains("sin información de slot"), "{err}");
    }
}

/// `ORDEN-W06d8` V1: protocolo productor↔bucle con un bucle simulado. Se inyectan respuestas
/// atrasadas (`Padres`/`Continuar` tras `Interrumpido`), duplicadas, `Parar` en el punto de espera e
/// `id` del futuro, y se comprueba que el hilo (la función [`esperar`]) descarta, para o reporta
/// violación **sin pánico**, según la decisión 1 (y la 3 para el `id` del futuro).
#[cfg(test)]
#[expect(
    clippy::unwrap_used,
    clippy::panic,
    reason = "el test falla con panic por diseño"
)]
mod tests_protocolo {
    use std::sync::mpsc;

    use zx_core::digest::Digest;
    use zx_core::{BlockHash, PadresDag};

    use super::{MsgBucle, Recepcion, esperar};
    use crate::registro::Registro;
    use zx_post::servicio_pot::ServicioPot;

    fn h(n: u8) -> BlockHash {
        BlockHash::from_digest(Digest::from_bytes([n; 32]))
    }

    fn servicio() -> ServicioPot {
        // `N_dev` debe ser múltiplo de 16 (`proyectar_iteraciones`); 16 es el mínimo válido.
        ServicioPot::nuevo(h(1), 16, 4096).unwrap()
    }

    fn registro() -> (tempfile::TempDir, Registro) {
        let dir = tempfile::tempdir().unwrap();
        let registro = Registro::abrir(&dir.path().join("registro.jsonl")).unwrap();
        (dir, registro)
    }

    fn leer_registro(dir: &tempfile::TempDir) -> String {
        std::fs::read_to_string(dir.path().join("registro.jsonl")).unwrap()
    }

    fn padres(id: u64, selector: u8) -> MsgBucle {
        MsgBucle::Padres {
            id,
            padres: PadresDag::nuevo(h(selector), &[]).unwrap(),
            info_padres: vec![(h(selector), u64::from(selector))],
            con_garantia: Default::default(),
            evidencias: Vec::new(),
        }
    }

    /// `Padres` con un `id` atrasado llega tras un `Interrumpido`: se descarta (con evento de
    /// diagnóstico) y se entrega la respuesta correcta, sin pánico. Es el caso que tumbaba a W07b
    /// (`regimen.rs:438`).
    #[test]
    fn padres_atrasado_tras_interrumpido_se_descarta() {
        let (dir, registro) = registro();
        let (tx, rx) = mpsc::channel::<MsgBucle>();
        // El terminal cambia mientras el hilo esperaba la respuesta a la petición id 0: la espera
        // se declara **interrumpida** y el hilo abandona esa petición. El bucle, que ya la había
        // contestado, deja la respuesta id 0 atrasada en el canal; el hilo ya espera la petición
        // viva id 1. El hash seleccionado distingue cuál se entregó.
        let mut nuevo = servicio();
        nuevo.avanzar().unwrap();
        tx.send(MsgBucle::CambiarTerminal(nuevo)).unwrap();
        tx.send(padres(0, 10)).unwrap();
        tx.send(padres(1, 11)).unwrap();

        let mut serv = servicio();
        assert!(matches!(
            esperar(&rx, &mut serv, &registro, 0),
            Recepcion::Interrumpido
        ));
        match esperar(&rx, &mut serv, &registro, 1) {
            Recepcion::Padres(p) => {
                assert_eq!(p.padres.seleccionado(), h(11), "se descarta el atrasado");
                assert_eq!(p.info_padres, vec![(h(11), 11)]);
            }
            _ => panic!("se esperaba la respuesta Padres viva"),
        }
        let texto = leer_registro(&dir);
        assert!(
            texto.contains("productor_respuesta_descartada"),
            "falta el evento de descarte: {texto}"
        );
        assert!(texto.contains("\"id_esperado\":1"), "{texto}");
        assert!(texto.contains("\"id_recibido\":0"), "{texto}");
    }

    /// `Continuar` duplicado (respuesta repetida de un `Post` ya abandonado): se descarta y se
    /// atiende la respuesta con el `id` esperado.
    #[test]
    fn continuar_duplicado_se_descarta() {
        let (dir, registro) = registro();
        let (tx, rx) = mpsc::channel::<MsgBucle>();
        tx.send(MsgBucle::Continuar { id: 3 }).unwrap();
        tx.send(MsgBucle::Continuar { id: 4 }).unwrap();

        let mut serv = servicio();
        assert!(matches!(
            esperar(&rx, &mut serv, &registro, 4),
            Recepcion::Continuar
        ));
        let texto = leer_registro(&dir);
        assert!(texto.contains("productor_respuesta_descartada"), "{texto}");
        assert!(texto.contains("\"id_esperado\":4"), "{texto}");
        assert!(texto.contains("\"id_recibido\":3"), "{texto}");
    }

    /// `Parar` se atiende siempre, incluso tras descartar una respuesta atrasada y aunque el `id`
    /// que el hilo esperaba no haya llegado.
    #[test]
    fn parar_se_atiende_siempre() {
        let (_dir, registro) = registro();
        let (tx, rx) = mpsc::channel::<MsgBucle>();
        tx.send(padres(0, 1)).unwrap();
        tx.send(MsgBucle::Parar).unwrap();

        let mut serv = servicio();
        assert!(matches!(
            esperar(&rx, &mut serv, &registro, 9),
            Recepcion::Parar
        ));
    }

    /// Un `id` del futuro es una violación de invariante: el hilo la reporta (el llamante envía
    /// `Fallo` y termina ordenadamente), no entra en pánico.
    #[test]
    fn id_del_futuro_es_violacion() {
        let (_dir, registro) = registro();
        let (tx, rx) = mpsc::channel::<MsgBucle>();
        tx.send(padres(7, 1)).unwrap();
        let mut serv = servicio();
        match esperar(&rx, &mut serv, &registro, 2) {
            Recepcion::Violacion(motivo) => assert!(motivo.contains("id 7"), "{motivo}"),
            _ => panic!("se esperaba violación de invariante Padres"),
        }

        let (tx2, rx2) = mpsc::channel::<MsgBucle>();
        tx2.send(MsgBucle::Continuar { id: 7 }).unwrap();
        match esperar(&rx2, &mut serv, &registro, 2) {
            Recepcion::Violacion(motivo) => assert!(motivo.contains("id 7"), "{motivo}"),
            _ => panic!("se esperaba violación de invariante Continuar"),
        }
    }

    /// `CambiarTerminal` se absorbe en el sitio: la espera se declara interrumpida y el servicio se
    /// sustituye por el nuevo.
    #[test]
    fn cambiar_terminal_se_absorbe_y_sustituye_el_servicio() {
        let (_dir, registro) = registro();
        let (tx, rx) = mpsc::channel::<MsgBucle>();
        let mut nuevo = servicio();
        nuevo.avanzar().unwrap();
        tx.send(MsgBucle::CambiarTerminal(nuevo)).unwrap();

        let mut serv = servicio();
        assert_eq!(serv.slot_actual(), 0);
        assert!(matches!(
            esperar(&rx, &mut serv, &registro, 0),
            Recepcion::Interrumpido
        ));
        assert_eq!(
            serv.slot_actual(),
            1,
            "el servicio se sustituyó por el nuevo"
        );
    }

    /// El canal cerrado no es un pánico: es el apagado normal.
    #[test]
    fn canal_cerrado_es_apagado_normal() {
        let (_dir, registro) = registro();
        let (tx, rx) = mpsc::channel::<MsgBucle>();
        drop(tx);
        let mut serv = servicio();
        assert!(matches!(
            esperar(&rx, &mut serv, &registro, 0),
            Recepcion::Cerrado
        ));
    }
}

/// `ORDEN-W06d9` V2: un portador ausente (o un rango no recompletable) es una **producción
/// omitida**, no un `fallo_productor`; el evento de diagnóstico lleva slot y motivo.
#[cfg(test)]
#[expect(
    clippy::unwrap_used,
    clippy::expect_used,
    reason = "el test falla con panic por diseño"
)]
mod tests_produccion_omitida {
    use std::convert::Infallible;

    use zx_post::productor_regimen::ErrorRegimen;
    use zx_post::servicio_pot::ErrorServicioPot;

    use super::{motivo_produccion_omitida, registrar_produccion_omitida};
    use crate::registro::Registro;

    /// Un portador ausente que no se pudo recompletar es omitible (nunca `fallo_productor`).
    #[test]
    fn un_portador_ausente_es_omisible() {
        let error: ErrorRegimen<Infallible> =
            ErrorRegimen::Servicio(ErrorServicioPot::PortadorAusente { slot: 6 });
        let motivo = motivo_produccion_omitida(&error).expect("omisible");
        assert!(motivo.contains("slot 6"), "{motivo}");
    }

    /// Un rango que excede la cota de recálculo o la del formato también es omitible.
    #[test]
    fn un_rango_no_recompletable_es_omisible() {
        let rango: ErrorRegimen<Infallible> =
            ErrorRegimen::Servicio(ErrorServicioPot::RecompletarExcedeMaximo {
                sp_slot: 100,
                b_slot: 200,
                base_slot: 0,
                d: 200,
                max: 150,
            });
        assert!(motivo_produccion_omitida(&rango).is_some());

        let formato: ErrorRegimen<Infallible> =
            ErrorRegimen::RangoExcedeMaximo { d: 160, max: 150 };
        let motivo = motivo_produccion_omitida(&formato).expect("omisible");
        assert!(motivo.contains("MAX_BUNDLES_POT"), "{motivo}");
    }

    /// Un error interno real sigue siendo `fallo_productor` (no se enmascara como omisión).
    #[test]
    fn un_error_interno_no_es_omisible() {
        let error: ErrorRegimen<Infallible> = ErrorRegimen::SinPadres;
        assert!(motivo_produccion_omitida(&error).is_none());
    }

    /// El evento `produccion_omitida` se escribe con `slot` y `motivo`.
    #[test]
    fn produccion_omitida_escribe_el_evento_con_slot_y_motivo() {
        let dir = tempfile::tempdir().unwrap();
        let registro = Registro::abrir(&dir.path().join("registro.jsonl")).unwrap();
        registrar_produccion_omitida(&registro, 7, "portador ausente para el slot 6");
        let texto = std::fs::read_to_string(dir.path().join("registro.jsonl")).unwrap();
        assert!(texto.contains("\"tipo\":\"produccion_omitida\""), "{texto}");
        assert!(texto.contains("\"slot\":7"), "{texto}");
        assert!(texto.contains("portador ausente para el slot 6"), "{texto}");
    }
}
