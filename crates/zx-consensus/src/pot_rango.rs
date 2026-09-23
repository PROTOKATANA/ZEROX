//! Núcleo de verificación de un **rango PoT** de un bloque DAG (SPEC §7.1.2 y §7.1.5).
//!
//! Verifica la justificación `PotCheckpoints` que cubre `(slot(sp(B)) + D, slot(B) + D]` contra
//! una **instantánea contextual** del pasado, y ancla el resultado en `cabecera.pot_output`
//! (`C-POT-05`, `C-HDR-07`). Devuelve **tres estados** expresa y únicamente tres:
//! [`EstadoPot::PotValido`], [`EstadoPot::PotInvalido`] y [`EstadoPot::PotPendiente`]
//! (`C-POT-06`). Ningún pendiente se convierte en válido por defecto.
//!
//! # Qué comprueba y en qué orden (`C-POT-08`)
//!
//! - **Estructura, sin AES** (paso 1, `C-HDR-05` · `C-FLU-02`, `C-HDR-07`): `slot(p) ≤ slot(B)`
//!   para todos los padres, `d = slot(B) − slot(sp(B))` sin underflow, `d ≤ 150` y número real
//!   de portadores igual a `d`.
//! - **Flujo, sin AES** (paso 1b, `C-FLU-14`): `flujo(B, slot(X)) == flujo(X, slot(X))` para
//!   todo `X ∈ past(B)`. Discrepar es `Inválido`; que falte pasado es `Pendiente`.
//! - **Caché por clave contextual** (paso 3, `C-POT-07`): `(f, s, semilla(f,s), N(s))`, los
//!   cuatro del contexto. Una discrepancia **bajo la misma clave** es `Inválido`; una entrada
//!   de **otra clave no invalida**.
//! - **Cadena AES del rango** (paso 4, `C-POT-01`, `C-POT-02`, `C-POT-04`): se parte de la
//!   salida ya validada en `slot(sp(B)) + D`, se aplica la inyección declarada **exactamente en
//!   su slot** (a lo sumo una, `C-FLU-12`), se proyecta `N(s)`, se verifica cada portador con
//!   [`verificar_slot_aes`] y se encadena la salida. El último resultado **MUST** ser
//!   `cabecera.pot_output`; con `d = 0` se exige que el ancla acreditada del mismo slot sea
//!   `pot_output`, sin declarar válido un rango vacío por omisión.
//!
//! El **paso 2** (cabecera y sello, `C-HDR-03`/`C-HDR-04`) y el **paso 5** (reto y solución
//! PoAS) de `C-POT-08` **no** se cubren aquí: pertenecen a la validación de cabecera y al
//! verificador PoAS, y este núcleo no los sustituye ni los finge. Tampoco se llama
//! `validar_bloque`.
//!
//! # Prohibición de circularidad (`C-POT-06`)
//!
//! El flujo, la semilla del rango, las inyecciones, `N(s)` y `D` llegan **solo** por
//! [`InstantaneaPot`], cuyos métodos no reciben la cabecera ni el cuerpo. Eso evita una vía
//! directa de lectura, pero un implementador podría haber capturado datos del candidato por
//! otra vía: la procedencia causal sigue siendo una precondición por acreditar. El candidato
//! aporta únicamente su `slot`, sus padres, los portadores y el `pot_output` que se usa como
//! **redundancia comprobada**, nunca como fuente de verdad.
//!
//! # Qué acredita hoy `past(B)` — y qué no
//!
//! **Ningún objeto del código actual acredita un `past(B)` validado para el PoT, y este módulo
//! no fabrica la fábrica que lo aparente.**
//!
//! - `AlmacenGhostdag` guarda por bloque `id`, `padres`, `slot`, `rango_espacio` validado e
//!   identidad, y responde a las consultas de `ContextoDag` (`slot_de_padre`,
//!   `esta_en_el_pasado_de`, `padre_seleccionado`). **No** guarda `pot_output`, ni el
//!   identificador de flujo, ni las inyecciones, ni `N(s)`, ni las salidas de slot; y su entrada
//!   sintética (`anadir_sintetico`) admite datos libres.
//! - `zx_core::wire_dag::ContextoVerificacionPot` es una interfaz **sin implementación de
//!   producción**.
//! - La derivación del identificador de flujo de §7.1.4 y el cálculo de la vista de época
//!   `V_j(B)` y del ancla de §7.1.3 **no existen**. Por eso [`InstantaneaPot`] se declara como
//!   la costura que el derivador real deberá implementar, y su precondición —derivar todo del
//!   pasado DAG validado— queda documentada, **no comprobada** por el núcleo.
//!
//! Consecuencia, dicha sin adorno: **este núcleo no puede producir `PotValido` para un bloque en
//! la ruta activa**, porque no hay fuente causal que produzca una [`InstantaneaPot`] acreditada.
//! `zx_core::wire_dag::verificar_justificacion_pot` sigue devolviendo
//! [`zx_core::wire_dag::IntegracionPotPendiente`] hasta que exista esa integración. Las
//! implementaciones de prueba del trait que viven en los tests **no acreditan** la validez de
//! ningún bloque: sirven para probar el núcleo.
//!
//! # Tensión literal de `C-POT-07` (documentada, sin tocar el SPEC)
//!
//! `C-POT-07` define `valor = salida(f, s)` (16 B) y a la vez ordena decidir una discrepancia
//! comparando **128 B sin AES**. Una coincidencia de solo 16 B **no** acredita los siete
//! checkpoints anteriores. Este módulo lo resuelve así: [`EntradaCachePot`] conserva, cuando
//! existe, el **portador completo previamente verificado**; un acierto rápido compara los 128 B.
//! Si la entrada solo tiene la salida de 16 B, el núcleo **no** acepta por esa coincidencia:
//! verifica el portador con AES o devuelve `Pendiente` si no hay presupuesto. Una discrepancia de
//! 16 B bajo la misma clave sí basta para `Inválido`, porque el PoT es determinista.
//!
//! # Contexto circular cuando `D ≥ L_slots`
//!
//! No se presupone `D < L_slots`. Si un bloque puede ser su propia ancla, la entropía de
//! `C-FLU-12` dependería de su propio `pot_output`. [`InyeccionPot`] declara el **ancla** de cada
//! inyección; si el ancla es el propio candidato, el estado es `Pendiente` por contexto circular,
//! nunca `Inválido` ni `Válido`. Tampoco se fijan aquí `D`, `L_slots`, `N(s)` ni presupuesto
//! alguno: los tres primeros llegan por el contexto y el presupuesto se inyecta.

use zx_core::BlockHash;
use zx_core::wire_dag::{
    ErrorDiferenciaSlots, JustificacionPot, MAX_BUNDLES_POT, POT_OUTPUT_BYTES, PotCheckpoints,
};

use crate::pot::{
    ENTROPIA_BYTES, ErrorContextoPot, checkpoints_a_primitiva, proyectar_iteraciones,
    semilla_siguiente, verificar_slot_aes,
};

/// Bytes de un identificador de flujo (definición del flujo, §7.1.4).
pub const FLUJO_BYTES: usize = 32;

/// Estado de la verificación de un rango PoT. Son **tres**, no dos (`C-POT-06`).
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum EstadoPot {
    /// Cadena completa verificada y anclada en `pot_output`.
    PotValido,
    /// Defecto **del candidato**, verificable y final.
    PotInvalido(MotivoPotInvalido),
    /// Sin prueba de invalidez, pero tampoco de validez. Nunca pasa a válido por defecto.
    PotPendiente(MotivoPotPendiente),
}

/// Defecto del candidato: la prueba es falsa o está descuadrada (`C-POT-06`).
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum MotivoPotInvalido {
    /// `C-HDR-07`: underflow `slot(B) < slot(sp)`, diferencia `> 150` o número de portadores
    /// distinto de `d`. Reutiliza la semántica del código de `zx-core`.
    DiferenciaDeSlots(ErrorDiferenciaSlots),
    /// `C-HDR-05` · `C-FLU-02`: algún padre tiene un `slot` posterior al del bloque.
    SlotDePadrePosterior {
        /// Padre infractor.
        padre: BlockHash,
        /// Su `slot`, tomado del contexto.
        slot_padre: u64,
        /// El `slot` declarado por el bloque.
        slot_bloque: u64,
    },
    /// `C-FLU-14`: el flujo del candidato en el slot de un ancestro no es el del ancestro.
    FlujoDePasadoDiscrepa {
        /// Ancestro cuyo flujo discrepó.
        bloque: BlockHash,
        /// Slot en el que se comparó.
        slot: u64,
    },
    /// `C-POT-07`: discrepancia con la caché **bajo la misma clave**.
    CacheDiscrepante {
        /// Slot del portador.
        slot: u64,
    },
    /// `C-POT-02`: la cadena AES no reproduce el portador con la semilla y `N(s)` del contexto.
    AesFallido {
        /// Slot del portador.
        slot: u64,
    },
    /// `C-POT-05` · `C-HDR-07`: el resultado encadenado no es `cabecera.pot_output`.
    PotOutputNoCoincide {
        /// Salida obtenida del contexto y de la cadena.
        obtenido: [u8; POT_OUTPUT_BYTES],
    },
    /// `C-HDR-07`: el génesis lleva portadores; su número canónico es cero.
    PortadoresEnGenesis {
        /// Portadores declarados.
        portadores: usize,
    },
}

/// Falta de contexto o imposibilidad de verificarlo: **no** es una prueba inválida (`C-POT-06`).
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum MotivoPotPendiente {
    /// El contexto no puede aportar un dato del pasado validado.
    ContextoAusente {
        /// Qué dato falta.
        que: &'static str,
    },
    /// `C-FLU-14`: el contexto no tiene todo `past(B)` o no puede enumerarlo.
    PasadoIncompleto,
    /// `C-POT-04`: `N(s)` fuera del dominio de la primitiva (cero, `> u32::MAX` o no múltiplo
    /// de 16). Es fallo del pasado validado, nunca del candidato.
    IteracionesFueraDeDominio {
        /// Slot cuyo `N(s)` falló.
        slot: u64,
        /// Diagnóstico de `C-POT-04`.
        error: ErrorContextoPot,
    },
    /// `C-NET-32.2`: hay slots del rango por delante del reloj PoT del nodo. Se retienen.
    RelojFuturo {
        /// Primer slot retenido.
        slot: u64,
        /// Reloj PoT declarado por el nodo.
        reloj_pot: u64,
    },
    /// `C-NET-33`: presupuesto agotado. **Nunca** `Inválido`.
    PresupuestoAgotado {
        /// Slot que no se pudo verificar.
        slot: u64,
    },
    /// `C-POT-01`: el contexto declara más de una inyección en un slot.
    InyeccionesMultiples {
        /// Slot con más de una inyección.
        slot: u64,
    },
    /// `C-FLU-12`: el ancla de una inyección del rango es el propio candidato, así que su
    /// entropía dependería de su `pot_output`. No se presupone `D < L_slots`.
    ContextoCircular {
        /// Slot de la inyección circular.
        slot: u64,
    },
    /// `slot + D` no cabe en `u64` con aritmética comprobada.
    AritmeticaDeSlotsDesbordada,
    /// La semilla del génesis (§7.1.3) exige `entropía_externa`, parámetro de lanzamiento que
    /// este núcleo **no** inventa.
    GenesisSinEntropiaExterna,
}

/// Un bloque de `past(B)` con lo que `C-FLU-14` necesita de él.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct BloqueDelPasado {
    /// Identificador del ancestro.
    pub hash: BlockHash,
    /// Su slot validado.
    pub slot: u64,
    /// `flujo(X, slot(X))` ya validado de `X`.
    pub flujo: [u8; FLUJO_BYTES],
}

/// Inyección declarada por el pasado en un slot (`C-POT-01`, `C-FLU-12`).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct InyeccionPot {
    /// Los 32 B de entropía de la inyección.
    pub entropia: [u8; ENTROPIA_BYTES],
    /// Ancla `I_j(B)` que la produce. Sirve para detectar el contexto circular.
    pub ancla: BlockHash,
}

/// Cuántas inyecciones declara el contexto en un slot.
///
/// Existe para que el núcleo pueda rechazar **más de una** sin confiar en que el contexto las
/// cuente bien (`C-POT-01`).
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum InyeccionesPot {
    /// Ninguna.
    Ninguna,
    /// Exactamente una.
    Una(InyeccionPot),
    /// Más de una: `Pendiente` por error de contexto.
    Varias,
}

/// Instantánea contextual **acreditada** del pasado de un candidato (`C-POT-06`).
///
/// # Precondición que el núcleo NO comprueba
///
/// Toda implementación de producción **MUST** derivar estos valores **exclusivamente** del pasado
/// DAG validado de `B`, y **MUST NOT** aceptarlos del candidato, de su cabecera, de su cuerpo, del
/// orden de llegada, del reloj local ni de la punta local. Ninguno de los métodos recibe la
/// cabecera directamente. Una implementación aún podría capturar datos del candidato por
/// fuera: excluir esa circularidad y acreditar el pasado son precondiciones que este contrato
/// **no** demuestra.
///
/// Una implementación de prueba (o un mock) cumple la firma pero **no acredita** procedencia
/// alguna: sirve para probar el núcleo, no para declarar válido un bloque.
pub trait InstantaneaPot {
    /// `flujo(B, s)` del candidato, derivado de `past(B)` (§7.1.4).
    ///
    /// # Errores
    /// [`MotivoPotPendiente::ContextoAusente`] si la derivación no existe todavía: en ese caso el
    /// núcleo devuelve `Pendiente`, nunca un flujo supuesto.
    fn flujo_candidato_en(&self, slot: u64) -> Result<[u8; FLUJO_BYTES], MotivoPotPendiente>;

    /// `past(B)` completo, para la comprobación `C-FLU-14`.
    ///
    /// # Errores
    /// [`MotivoPotPendiente::PasadoIncompleto`] si no puede enumerarse entero.
    fn pasado(&self) -> Result<&[BloqueDelPasado], MotivoPotPendiente>;

    /// Inyecciones declaradas por el pasado **exactamente** en `slot` (`C-POT-01`, `C-FLU-12`).
    ///
    /// # Errores
    /// El error contextual que impida calcularlas (por ejemplo, ancla no derivable).
    fn inyecciones_en(&self, slot: u64) -> Result<InyeccionesPot, MotivoPotPendiente>;

    /// `N(s)` vigente en el slot, del pasado validado (`C-POT-04`).
    ///
    /// # Errores
    /// [`MotivoPotPendiente::ContextoAusente`] si el calendario no está disponible.
    fn iteraciones(&self, slot: u64) -> Result<u64, MotivoPotPendiente>;

    /// Retardo de autoría `D` del contexto.
    ///
    /// # Errores
    /// [`MotivoPotPendiente::ContextoAusente`] si no está fijado.
    fn retardo_autoria(&self) -> Result<u64, MotivoPotPendiente>;

    /// `salida(f, s)` **ya validada** en el pasado, para anclar el rango (`C-POT-05`).
    ///
    /// # Errores
    /// [`MotivoPotPendiente::ContextoAusente`] si esa salida no está anclada en un bloque
    /// anterior.
    fn salida_validada(&self, slot: u64) -> Result<[u8; POT_OUTPUT_BYTES], MotivoPotPendiente>;
}

/// Clave de caché contextual de `C-POT-07`: los **cuatro** valores del contexto.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct ClaveCachePot {
    /// `f`, identificador de flujo.
    pub flujo: [u8; FLUJO_BYTES],
    /// Slot `s`.
    pub slot: u64,
    /// `semilla(f, s)`.
    pub semilla: [u8; POT_OUTPUT_BYTES],
    /// `N(s)` en `u64`.
    pub iteraciones: u64,
}

/// Valor de caché contextual (`C-POT-07`).
///
/// Conserva la salida de 16 B y, cuando el nodo la tenga, el **portador completo** de 128 B que
/// ya verificó. El portador es la evidencia auxiliar que permite un acierto rápido sin AES; la
/// salida sola no acredita los siete checkpoints anteriores (tensión literal de `C-POT-07`).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct EntradaCachePot {
    /// `salida(f, s)`, 16 B.
    pub salida: [u8; POT_OUTPUT_BYTES],
    /// Portador de 128 B previamente verificado, si se conservó.
    pub portador: Option<PotCheckpoints>,
}

/// Caché del nodo indexada por [`ClaveCachePot`] (`C-POT-07`).
///
/// Una entrada **de otra clave no invalida** al candidato: son cadenas de PoT distintas, ambas
/// legítimas.
pub trait CachePot {
    /// Busca la entrada de esa clave, si existe.
    fn buscar(&self, clave: &ClaveCachePot) -> Option<EntradaCachePot>;
    /// Registra o reemplaza la entrada de esa clave.
    fn registrar(&mut self, clave: ClaveCachePot, entrada: EntradaCachePot);
}

/// Presupuesto de CPU inyectado (`C-NET-33`).
///
/// El núcleo **no fija** `PRESUP_PAR` ni `PRESUP_NODO`: los aporta el llamante. Se consume una
/// unidad por **verificación AES**; un acierto rápido de caché no consume. Agotarlo produce
/// `Pendiente`, nunca `Inválido`.
///
/// # Alcance del medidor
///
/// Este núcleo **solo** acota la cadena AES del rango. El coste estructural del paso 1b
/// (`C-FLU-14`) y el trabajo de adopción de flujo rival de §16.6 pertenecen al nodo, cuyos
/// presupuestos siguen `<<PENDIENTE>>`: el núcleo no los calibra ni los sustituye.
pub trait PresupuestoPot {
    /// Intenta consumir una verificación AES del slot `slot`; `false` si no queda presupuesto.
    fn consumir_slot(&mut self, slot: u64) -> bool;
}

/// Verifica el rango PoT de `cabecera` contra su instantánea contextual (`C-POT-08`).
///
/// # Entradas
///
/// - `cabecera`: **candidato**. Solo se leen `slot`, `padres` y `pot_output`.
/// - `justificacion`: los portadores del candidato, evidencia reemplazable.
/// - `contexto`: la instantánea del pasado validado ([`InstantaneaPot`]). Aporta `f`, las
///   inyecciones, `N(s)`, `D` y la salida ancla; **nunca** el candidato.
/// - `reloj_pot`: reloj PoT **del nodo** (`C-NET-32.2`), estado local que no viaja en el bloque.
/// - `cache`: caché del nodo (`C-POT-07`).
/// - `presupuesto`: presupuesto de CPU inyectado (`C-NET-33`).
///
/// # Qué NO hace
///
/// No comprueba el sello (`C-HDR-04`), ni el reto y la solución PoAS (`C-POT-03`), ni la
/// anticadena, ni que `prev_hash` sea el `sp` de GHOSTDAG (`C-GD-03`): usa el padre seleccionado
/// **declarado** como base de `d`, igual que el gate de `zx-core`. No es `validar_bloque`.
#[must_use]
pub fn verificar_rango_pot<C, K, P>(
    cabecera: &zx_core::DagBlockHeader,
    justificacion: &JustificacionPot,
    contexto: &C,
    reloj_pot: u64,
    cache: &mut K,
    presupuesto: &mut P,
) -> EstadoPot
where
    C: InstantaneaPot,
    K: CachePot,
    P: PresupuestoPot,
{
    // 0 · Génesis, por separado y sin inventar `entropía_externa`.
    if cabecera.padres.count() == 0 {
        if !justificacion.is_empty() {
            return EstadoPot::PotInvalido(MotivoPotInvalido::PortadoresEnGenesis {
                portadores: justificacion.len(),
            });
        }
        return EstadoPot::PotPendiente(MotivoPotPendiente::GenesisSinEntropiaExterna);
    }

    // 1 · Estructura, sin AES: cota de slot de TODOS los padres (C-HDR-05 · C-FLU-02).
    let pasado = match contexto.pasado() {
        Ok(p) => p,
        Err(motivo) => return EstadoPot::PotPendiente(motivo),
    };
    let seleccionado = cabecera.padres.seleccionado();
    let mut slot_sp: Option<u64> = None;
    for padre in core::iter::once(&seleccionado).chain(cabecera.padres.extras().iter()) {
        let Some(entrada) = entrada_de(pasado, padre) else {
            return EstadoPot::PotPendiente(MotivoPotPendiente::PasadoIncompleto);
        };
        if entrada.slot > cabecera.slot {
            return EstadoPot::PotInvalido(MotivoPotInvalido::SlotDePadrePosterior {
                padre: *padre,
                slot_padre: entrada.slot,
                slot_bloque: cabecera.slot,
            });
        }
        if padre == &seleccionado {
            slot_sp = Some(entrada.slot);
        }
    }
    let Some(slot_sp) = slot_sp else {
        return EstadoPot::PotPendiente(MotivoPotPendiente::PasadoIncompleto);
    };

    // 1 · `d = slot(B) − slot(sp(B))` y número real de portadores (C-HDR-07).
    if let Err(motivo) = diferencia_de_slots(justificacion, cabecera.slot, slot_sp) {
        return EstadoPot::PotInvalido(MotivoPotInvalido::DiferenciaDeSlots(motivo));
    }

    // 1b · Flujo, sin AES: pasado consistente de flujo (C-FLU-14).
    match contexto.flujo_candidato_en(cabecera.slot) {
        Ok(_) => {}
        Err(motivo) => return EstadoPot::PotPendiente(motivo),
    }
    for x in pasado {
        match contexto.flujo_candidato_en(x.slot) {
            Ok(flujo_candidato) if flujo_candidato == x.flujo => {}
            Ok(_) => {
                return EstadoPot::PotInvalido(MotivoPotInvalido::FlujoDePasadoDiscrepa {
                    bloque: x.hash,
                    slot: x.slot,
                });
            }
            Err(motivo) => return EstadoPot::PotPendiente(motivo),
        }
    }

    // 4 · Aritmética comprobada del rango y reloj PoT (C-NET-32.2).
    let retardo = match contexto.retardo_autoria() {
        Ok(d) => d,
        Err(motivo) => return EstadoPot::PotPendiente(motivo),
    };
    let Some(slot_base) = slot_sp.checked_add(retardo) else {
        return EstadoPot::PotPendiente(MotivoPotPendiente::AritmeticaDeSlotsDesbordada);
    };
    let Some(slot_fin) = cabecera.slot.checked_add(retardo) else {
        return EstadoPot::PotPendiente(MotivoPotPendiente::AritmeticaDeSlotsDesbordada);
    };
    if slot_fin > reloj_pot {
        let primer_slot_del_rango = if justificacion.is_empty() {
            slot_fin
        } else {
            let Some(slot) = slot_base.checked_add(1) else {
                return EstadoPot::PotPendiente(MotivoPotPendiente::AritmeticaDeSlotsDesbordada);
            };
            slot
        };
        return EstadoPot::PotPendiente(MotivoPotPendiente::RelojFuturo {
            slot: primer_slot_del_rango.max(reloj_pot.saturating_add(1)),
            reloj_pot,
        });
    }

    // 4 · Salida ya validada en `slot(sp(B)) + D`, del pasado (C-POT-05).
    let mut salida = match contexto.salida_validada(slot_base) {
        Ok(s) => s,
        Err(motivo) => return EstadoPot::PotPendiente(motivo),
    };
    let hash_candidato = cabecera.block_hash();

    for (indice, portador) in justificacion.bundles().iter().enumerate() {
        let indice = u64::try_from(indice).unwrap_or(u64::MAX);
        let Some(slot) = slot_base.checked_add(indice.saturating_add(1)) else {
            return EstadoPot::PotPendiente(MotivoPotPendiente::AritmeticaDeSlotsDesbordada);
        };

        // Inyección declarada EXACTAMENTE en su slot, a lo sumo una (C-POT-01, C-FLU-12).
        let entropia = match contexto.inyecciones_en(slot) {
            Ok(InyeccionesPot::Ninguna) => None,
            Ok(InyeccionesPot::Una(inyeccion)) => {
                if inyeccion.ancla == hash_candidato {
                    return EstadoPot::PotPendiente(MotivoPotPendiente::ContextoCircular { slot });
                }
                Some(inyeccion.entropia)
            }
            Ok(InyeccionesPot::Varias) => {
                return EstadoPot::PotPendiente(MotivoPotPendiente::InyeccionesMultiples { slot });
            }
            Err(motivo) => return EstadoPot::PotPendiente(motivo),
        };
        let semilla = semilla_siguiente(salida, entropia);

        // `N(s)` del contexto, proyectado sin panic ni envoltura (C-POT-04).
        let iteraciones = match contexto.iteraciones(slot) {
            Ok(n) => n,
            Err(motivo) => return EstadoPot::PotPendiente(motivo),
        };
        if let Err(error) = proyectar_iteraciones(iteraciones) {
            return EstadoPot::PotPendiente(MotivoPotPendiente::IteracionesFueraDeDominio {
                slot,
                error,
            });
        }

        // El rango puede cruzar `t_j`: la clave usa el flujo vigente EN ESTE slot,
        // no el de `slot(B)` (SPEC §7.1.3–4, C-POT-07).
        let flujo = match contexto.flujo_candidato_en(slot) {
            Ok(f) => f,
            Err(motivo) => return EstadoPot::PotPendiente(motivo),
        };
        let salida_portador = salida_de(portador);
        let clave = ClaveCachePot {
            flujo,
            slot,
            semilla,
            iteraciones,
        };

        // 3 · Caché por clave contextual (C-POT-07).
        let mut verificado_sin_aes = false;
        if let Some(entrada) = cache.buscar(&clave) {
            if entrada.salida != salida_portador {
                return EstadoPot::PotInvalido(MotivoPotInvalido::CacheDiscrepante { slot });
            }
            match entrada.portador {
                Some(portador_cacheado) if portador_cacheado == *portador => {
                    verificado_sin_aes = true;
                }
                // Misma clave y mismo resultado de 16 B pero portador distinto: discrepancia.
                Some(_) => {
                    return EstadoPot::PotInvalido(MotivoPotInvalido::CacheDiscrepante { slot });
                }
                // Solo la salida: no acredita los siete checkpoints; hay que pasar por AES.
                None => {}
            }
        }

        // 4 · Cadena AES del rango (C-POT-02).
        if !verificado_sin_aes {
            if !presupuesto.consumir_slot(slot) {
                return EstadoPot::PotPendiente(MotivoPotPendiente::PresupuestoAgotado { slot });
            }
            match verificar_slot_aes(semilla, iteraciones, portador) {
                Ok(true) => {}
                Ok(false) => {
                    return EstadoPot::PotInvalido(MotivoPotInvalido::AesFallido { slot });
                }
                Err(error) => {
                    return EstadoPot::PotPendiente(
                        MotivoPotPendiente::IteracionesFueraDeDominio { slot, error },
                    );
                }
            }
            cache.registrar(
                clave,
                EntradaCachePot {
                    salida: salida_portador,
                    portador: Some(*portador),
                },
            );
        }

        salida = salida_portador;
    }

    // 5 · Anclaje final (C-POT-05). Con `d = 0` la «cadena» es el ancla acreditada del mismo
    //     slot: no se declara válido un rango vacío por omisión.
    if salida != cabecera.pot_output {
        return EstadoPot::PotInvalido(MotivoPotInvalido::PotOutputNoCoincide { obtenido: salida });
    }

    EstadoPot::PotValido
}

/// `slot(B) − slot(sp(B))` comprobado, con el número real de portadores (`C-HDR-07`).
///
/// Reutiliza la semántica y el tipo de error del gate de `zx-core`
/// (`comprobar_diferencia_slots_del_bloque`), que toma el bloque entero; aquí la entrada es la
/// pareja cabecera + justificación y el `slot(sp)` lo aporta el contexto.
fn diferencia_de_slots(
    justificacion: &JustificacionPot,
    slot_b: u64,
    slot_sp: u64,
) -> Result<(), ErrorDiferenciaSlots> {
    let Some(d) = slot_b.checked_sub(slot_sp) else {
        return Err(ErrorDiferenciaSlots::Underflow { slot_b, slot_sp });
    };
    if d > MAX_BUNDLES_POT as u64 {
        return Err(ErrorDiferenciaSlots::ExcedeMaximo { diferencia: d });
    }
    let portadores = u64::try_from(justificacion.len()).unwrap_or(u64::MAX);
    if portadores != d {
        return Err(ErrorDiferenciaSlots::NoCoincide {
            bundles: portadores,
            diferencia: d,
        });
    }
    Ok(())
}

/// Busca un ancestro en el pasado por su identificador.
fn entrada_de<'a>(pasado: &'a [BloqueDelPasado], hash: &BlockHash) -> Option<&'a BloqueDelPasado> {
    pasado.iter().find(|bloque| &bloque.hash == hash)
}

/// La salida de un portador es su **último** checkpoint (`C-POT-02`).
fn salida_de(portador: &PotCheckpoints) -> [u8; POT_OUTPUT_BYTES] {
    *checkpoints_a_primitiva(portador).output()
}
