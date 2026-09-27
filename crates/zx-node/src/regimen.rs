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

// `clippy::panic` está denegado a nivel de workspace («en código de consenso un panic es un vector
// de DoS»): aquí no aplica esa razón. Este hilo no valida entradas ajenas —W06d1 no tiene red; todo
// lo que produce y consume es propio— así que un `panic!` aquí nunca es alcanzable por un tercero,
// solo por una incoherencia interna del propio nodo (equivalente a `unreachable!()`). `fase_pow`
// convierte el panic del hilo (vía `JoinHandle::join`) en un `ErrorNodo` fatal explícito (decisión
// 4: un fallo interno del nodo termina el proceso con código ≠ 0, nunca en silencio): el bug real
// que motivó este cambio (`PROGRESO.md`) era exactamente un hilo que moría sin decir por qué.
#![expect(
    clippy::panic,
    reason = "hilo sin entrada ajena (sin red); un panic aquí es una incoherencia interna, y fase_regimen lo convierte en ErrorNodo fatal vía JoinHandle::join, nunca en un Ok silencioso"
)]

use std::collections::BTreeSet;
use std::sync::mpsc::{Receiver, Sender};
use std::time::Instant;

use zx_core::wire_dag::BloqueDag;
use zx_core::{ClavePublica, PadresDag};
use zx_farmer::farmer::ParcelaDisco;
use zx_farmer::productor_poas::convertir_candidatos_locales;
use zx_poas::HistoriaGenesis;
use zx_post::firmante::{Firmante, Registro as RegistroFirmante};
use zx_post::productor::{
    FuenteSoluciones, MotivoAbstencion, ParametrosProductor, ProductoFirmado, SolucionCandidata,
};
use zx_post::productor_regimen::{CuerpoProductor, producir_en_regimen_con_firmante};
use zx_post::servicio_pot::ServicioPot;

use crate::claves::ClaveDev;

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
    /// tienen la ventana abierta en el bloque que se va a construir).
    PeticionPadres(u64),
    /// Un bloque PoST ya producido y firmado, para verificar y admitir, junto con el instante en
    /// que este hilo obtuvo la salida PoT del slot (`ORDEN-W07a`: `retraso_slot_ns`).
    Post(Box<BloqueDag>, Instant),
    /// `ORDEN-SL4b2` decisión 2: el firmante seguro se abstuvo para esta candidata (conflicto de
    /// identidad o pérdida de registro): no se produjo bloque. El bucle escribe el evento
    /// `firmante_abstenido` (esquema v1, crítico) y contesta [`MsgBucle::Continuar`]: el nodo sigue
    /// validando y propagando, solo no produce esta oportunidad.
    Abstenido {
        /// Slot de la candidata abstenida.
        slot: u64,
        /// Causa de la abstención.
        motivo: MotivoAbstencion,
    },
}

/// Respuestas del bucle al hilo productor.
#[expect(
    clippy::large_enum_variant,
    reason = "un mensaje por producción intentada (~1/s); boxear `PadresDag` (Copy, 481 B) solo movería el coste a una asignación de montón sin beneficio medible"
)]
pub enum MsgBucle {
    /// Padres canónicos (`padres::padres_de_regimen`), con `(hash, slot)` de **cada** padre
    /// (seleccionado y extras).
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
    Padres(
        PadresDag,
        Vec<(zx_core::BlockHash, u64)>,
        BTreeSet<ClavePublica>,
        /// `ORDEN-SL4b2` decisión 4: hasta `MAX_EVIDENCIAS_POR_BLOQUE` `EvidenceTx` pendientes que
        /// el bucle ya filtró (incidente no procesado en el estado sobre el que se construye,
        /// ventana abierta en `slot_objetivo`). El hilo las mete en el cuerpo tal cual, sin volver
        /// a decidir nada sobre ellas.
        Vec<zx_core::Tx>,
    ),
    /// El bloque enviado se admitió: sigue produciendo.
    Continuar,
    /// Condición de parada alcanzada (`--parada-tras-slots`): el hilo debe terminar.
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

/// Resultado de esperar un mensaje del bucle que puede venir intercalado con
/// [`MsgBucle::CambiarTerminal`] (decisión 0).
enum Recepcion {
    /// El mensaje esperado (o cualquier otro no relacionado con el cambio de terminal). Boxeado:
    /// `MsgBucle::Padres` es grande (lleva un `PadresDag` y vectores) y `Interrumpido`/`Cerrado` no
    /// llevan nada.
    Mensaje(Box<MsgBucle>),
    /// Se aplicó un cambio de terminal: el hilo debe abandonar el intercambio en curso y volver al
    /// principio de su bucle principal (el próximo `avanzar()` ya usa el `ServicioPot` nuevo).
    Interrumpido,
    /// El bucle cerró el canal: apagado normal del proceso.
    Cerrado,
}

/// Espera el próximo mensaje del bucle, aplicando en el sitio cualquier
/// [`MsgBucle::CambiarTerminal`] que llegue (decisión 0 de `ORDEN-SL4b2`): a diferencia de los
/// demás mensajes, este no es la respuesta a ninguna petición del hilo, así que puede intercalarse
/// antes de la respuesta que el hilo realmente esperaba. Si eso ocurre, la espera se declara
/// **interrumpida**: el hilo no debe fingir que recibió la respuesta original (los padres o el
/// resultado de admisión que esperaba pertenecían al terminal anterior).
fn recibir_o_cambiar_terminal(rx: &Receiver<MsgBucle>, servicio: &mut ServicioPot) -> Recepcion {
    match rx.recv() {
        Ok(MsgBucle::CambiarTerminal(nuevo)) => {
            *servicio = nuevo;
            Recepcion::Interrumpido
        }
        Ok(otro) => Recepcion::Mensaje(Box::new(otro)),
        Err(_) => Recepcion::Cerrado,
    }
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
/// Termina cuando `parada_tras_slots` se alcanza, cuando el bucle contesta [`MsgBucle::Parar`] o
/// cuando el canal con el bucle se cierra (fin del proceso).
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

    'outer: loop {
        if let Some(limite) = parada_tras_slots
            && servicio.slot_actual() >= limite
        {
            return;
        }
        // `avanzar()` solo falla por desbordamiento aritmético de slot o si la primitiva PoT
        // rechaza una terna con `N_dev` válido: ninguno de los dos debería ocurrir aquí. Un fallo
        // real es un bug, no un cierre limpio: se hace ruido en vez de terminar en silencio (el bug
        // real de la primera ejecución de V4 fue exactamente un hilo que moría sin decir por qué).
        let slot = servicio
            .avanzar()
            .unwrap_or_else(|e| panic!("hilo productor: avanzar el PoT falló: {e}"));
        // `ORDEN-W07a`: instante en que este hilo tuvo la salida PoT del slot, para `retraso_slot_ns`.
        let instante_salida = Instant::now();
        let salida = servicio
            .salida_de(slot)
            .unwrap_or_else(|e| panic!("hilo productor: salida del slot {slot} ausente: {e}"));

        // Audita las tres parcelas locales en este mismo hilo (ver la nota de simplificación). Un
        // candidato sin solución no es error (contrato de `FuenteSoluciones`); un `Err` de la
        // auditoría sí lo es y se hace ruido, no se trata como «sin solución».
        let mut ganadoras: Vec<(usize, SolucionCandidata)> = Vec::new();
        for (i, cp) in claves.iter().enumerate() {
            let fuente = FuenteParcela {
                parcela: &cp.parcela,
                historia,
            };
            let mut candidatas = fuente
                .soluciones(salida, slot, sr_dev)
                .unwrap_or_else(|e| panic!("hilo productor: auditoría de la clave {i}: {e}"));
            if let Some(c) = candidatas.pop() {
                ganadoras.push((i, c));
            }
        }
        if ganadoras.is_empty() {
            continue;
        }

        if tx.send(MsgProductor::PeticionPadres(slot)).is_err() {
            return; // el bucle cerró el canal: apagado normal del proceso.
        }
        let (padres, info_padres, con_garantia, evidencias) =
            match recibir_o_cambiar_terminal(rx, &mut servicio) {
                Recepcion::Mensaje(msg) => match *msg {
                    MsgBucle::Padres(p, info, g, ev) => (p, info, g, ev),
                    _otro => {
                        panic!("hilo productor: se esperaba Padres, llegó otro mensaje del bucle")
                    }
                },
                // Decisión 0: el terminal cambió antes de que el bucle contestara esta petición
                // (era del terminal anterior). Se abandona esta candidata/slot sin fingir una
                // respuesta: el próximo `avanzar()` ya corre sobre el `ServicioPot` del terminal
                // nuevo.
                Recepcion::Interrumpido => continue 'outer,
                Recepcion::Cerrado => return, // el bucle cerró el canal: apagado normal del proceso.
            };
        // `ORDEN-W06d5` decisión 2 (`REVISION-W06d4.md`, V5-2): el padre seleccionado que incumple
        // `slot(padre) < slot_objetivo` ya lo descarta con gracia `producir_en_regimen` más abajo
        // (`ErrorRegimen::SlotNoProgreso`), pero ese cheque **no** cubre los padres extra del
        // mergeset GHOSTDAG (`C-HDR-05`/`C-FLU-02`: la regla alcanza a **todos** los padres). Se
        // excluyen aquí, antes de construir ningún bloque, en vez de descubrirlo en la verificación
        // completa (donde, al ser un bloque propio, era fatal).
        let padres = filtrar_padres_extra_por_slot(padres, &info_padres, slot);
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
            if slot_padre > servicio.slot_actual() {
                servicio.avanzar_hasta(slot_padre).unwrap_or_else(|e| {
                    panic!("hilo productor: no se pudo alcanzar el slot {slot_padre} del padre ajeno {hash}: {e}")
                });
            }
            match servicio.registrar_validado(hash, slot_padre) {
                Ok(()) | Err(zx_post::servicio_pot::ErrorServicioPot::BloqueDuplicado { .. }) => {}
                Err(e) => panic!(
                    "hilo productor: no se pudo registrar el padre ajeno {hash} (slot {slot_padre}): {e}"
                ),
            }
        }

        for (i, candidata) in ganadoras {
            let Some(cp) = claves.get(i) else {
                panic!("hilo productor: índice de clave {i} fuera de rango")
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
            let cuerpo = CuerpoProductor::nuevo(evidencias.clone(), testigos_evidencias)
                .unwrap_or_else(|e| {
                    panic!("hilo productor: cuerpo con evidencias del bucle inválido: {e}")
                });
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
                // `producir_en_regimen_con_firmante` sigue siendo una incoherencia interna real.
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
                Err(e) => panic!("hilo productor: producir_en_regimen_con_firmante falló: {e}"),
            };
            // `ORDEN-SL4b2` decisión 2: el firmante puede negarse (conflicto de identidad o
            // pérdida de registro, FIR-01…FIR-10). No es un error: se avisa al bucle
            // (`firmante_abstenido`, esquema v1) y se sigue con la siguiente candidata/slot, sin
            // producir esta.
            let bloque = match producto {
                ProductoFirmado::Bloque(b, _resultado_firmante) => b,
                ProductoFirmado::Abstenido { motivo } => {
                    if tx.send(MsgProductor::Abstenido { slot, motivo }).is_err() {
                        return; // el bucle cerró el canal: apagado normal del proceso.
                    }
                    match recibir_o_cambiar_terminal(rx, &mut servicio) {
                        Recepcion::Mensaje(msg) => match *msg {
                            MsgBucle::Continuar => continue,
                            MsgBucle::Parar => return,
                            _otro => panic!(
                                "hilo productor: se esperaba Continuar/Parar tras Abstenido, \
                                 llegó otro mensaje"
                            ),
                        },
                        Recepcion::Cerrado => return,
                        Recepcion::Interrumpido => continue,
                    }
                }
            };
            let hash = bloque.cabecera.block_hash();
            servicio
                .registrar_validado(hash, slot)
                .unwrap_or_else(|e| panic!("hilo productor: registrar el bloque producido: {e}"));

            if tx
                .send(MsgProductor::Post(Box::new(bloque), instante_salida))
                .is_err()
            {
                return; // el bucle cerró el canal: apagado normal del proceso.
            }
            match recibir_o_cambiar_terminal(rx, &mut servicio) {
                Recepcion::Mensaje(msg) => match *msg {
                    MsgBucle::Continuar => {}
                    MsgBucle::Parar => return,
                    MsgBucle::Padres(..) => {
                        panic!("hilo productor: se esperaba Continuar/Parar, llegó Padres")
                    }
                    MsgBucle::CambiarTerminal(..) => unreachable!(
                        "recibir_o_cambiar_terminal absorbe CambiarTerminal antes de devolverlo"
                    ),
                },
                Recepcion::Cerrado => return,
                // Decisión 0: el bloque ya se mandó y el bucle puede haberlo admitido igualmente
                // (es válido en su propio terminal, aunque ya no sea el seleccionado); no hace
                // falta la confirmación explícita para seguir con seguridad: el siguiente `avanzar()`
                // ya corre sobre el `ServicioPot` del terminal nuevo, y si `parada_tras_slots` se
                // hubiera alcanzado, el propio `avanzar()`/chequeo de cabecera de bucle lo detiene.
                Recepcion::Interrumpido => {}
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
/// (docstring de [`MsgBucle::Padres`]). Su ausencia es una incoherencia interna, no un caso de red.
fn filtrar_padres_extra_por_slot(
    padres: PadresDag,
    info_padres: &[(zx_core::BlockHash, u64)],
    slot_objetivo: u64,
) -> PadresDag {
    let seleccionado = padres.seleccionado();
    let extras_validos: Vec<zx_core::BlockHash> = padres
        .extras()
        .iter()
        .copied()
        .filter(|h| {
            let &(_, slot_padre) =
                info_padres
                    .iter()
                    .find(|(hp, _)| hp == h)
                    .unwrap_or_else(|| {
                        panic!("hilo productor: padre extra {h} sin información de slot del bucle")
                    });
            if slot_padre >= slot_objetivo {
                tracing::info!(
                    padre = ?h,
                    slot_padre,
                    slot_objetivo,
                    "padre extra descartado: su slot no es anterior al del bloque objetivo"
                );
                false
            } else {
                true
            }
        })
        .collect();
    PadresDag::nuevo(seleccionado, &extras_validos).unwrap_or_else(|e| {
        panic!("hilo productor: reconstruir PadresDag tras filtrar padres extra: {e}")
    })
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

        let filtrados = filtrar_padres_extra_por_slot(padres, &info_padres, 10);

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
        let filtrados = filtrar_padres_extra_por_slot(padres, &[(seleccionado, 1)], 100);
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
        let filtrados = filtrar_padres_extra_por_slot(padres, &info, 100);
        let mut extras = filtrados.extras().to_vec();
        extras.sort();
        let mut esperado = vec![e1, e2];
        esperado.sort();
        assert_eq!(extras, esperado);
    }
}
