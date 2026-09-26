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

use std::sync::mpsc::{Receiver, Sender};

use zx_core::PadresDag;
use zx_core::wire_dag::BloqueDag;
use zx_farmer::farmer::ParcelaDisco;
use zx_farmer::productor_poas::convertir_candidatos_locales;
use zx_poas::HistoriaGenesis;
use zx_post::productor::{FuenteSoluciones, ParametrosProductor, SolucionCandidata};
use zx_post::productor_regimen::{CuerpoProductor, producir_en_regimen};
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
    /// Pide los padres canónicos actuales de un bloque de régimen.
    PeticionPadres,
    /// Un bloque PoST ya producido y firmado, para verificar y admitir.
    Post(Box<BloqueDag>),
}

/// Respuestas del bucle al hilo productor.
#[expect(
    clippy::large_enum_variant,
    reason = "un mensaje por producción intentada (~1/s); boxear `PadresDag` (Copy, 481 B) solo movería el coste a una asignación de montón sin beneficio medible"
)]
pub enum MsgBucle {
    /// Padres canónicos (`padres::padres_de_regimen`).
    Padres(PadresDag),
    /// El bloque enviado se admitió: sigue produciendo.
    Continuar,
    /// Condición de parada alcanzada (`--parada-tras-slots`): el hilo debe terminar.
    Parar,
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
) {
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

    loop {
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

        if tx.send(MsgProductor::PeticionPadres).is_err() {
            return; // el bucle cerró el canal: apagado normal del proceso.
        }
        let padres = match rx.recv() {
            Ok(MsgBucle::Padres(p)) => p,
            Ok(_otro) => panic!("hilo productor: se esperaba Padres, llegó otro mensaje del bucle"),
            Err(_) => return, // el bucle cerró el canal: apagado normal del proceso.
        };

        for (i, candidata) in ganadoras {
            let Some(cp) = claves.get(i) else {
                panic!("hilo productor: índice de clave {i} fuera de rango")
            };
            let mut parametros_bloque = parametros;
            parametros_bloque.timestamp = std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .map(|d| d.as_secs())
                .unwrap_or(0);
            let fuente_fija = SolucionFija(candidata);
            let bloque = producir_en_regimen(
                padres,
                slot,
                &mut servicio,
                &fuente_fija,
                &cp.clave.sk,
                &parametros_bloque,
                CuerpoProductor::vacio(),
            )
            .unwrap_or_else(|e| panic!("hilo productor: producir_en_regimen falló: {e}"));
            let hash = bloque.cabecera.block_hash();
            servicio
                .registrar_validado(hash, slot)
                .unwrap_or_else(|e| panic!("hilo productor: registrar el bloque producido: {e}"));

            if tx.send(MsgProductor::Post(Box::new(bloque))).is_err() {
                return; // el bucle cerró el canal: apagado normal del proceso.
            }
            match rx.recv() {
                Ok(MsgBucle::Continuar) => {}
                Ok(MsgBucle::Parar) | Err(_) => return,
                Ok(MsgBucle::Padres(_)) => {
                    panic!("hilo productor: se esperaba Continuar/Parar, llegó Padres")
                }
            }
        }
    }
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
