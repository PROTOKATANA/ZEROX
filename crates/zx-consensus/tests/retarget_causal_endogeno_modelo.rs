//! Kernel entero estructural RCE-v0.1, exclusivo de tests.
//!
//! No reutiliza LWMA, no calibra PoAS y no fija parámetros de red. Los valores proceden de
//! fixtures etiquetados del modelo Julia. La simulación endógena completa permanece en Veritas.

#![expect(
    clippy::expect_used,
    clippy::integer_division,
    clippy::panic,
    reason = "el arnés falla ante fixtures mal formados; todas las divisiones enteras están especificadas"
)]

use std::collections::{BTreeMap, BTreeSet};

const FIXTURES: &str =
    include_str!("../../../veritas/consenso/retarget-causal-endogeno-v1/fixtures/CONTROLADOR.txt");

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum Rounding {
    Floor,
    NearestEven,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
struct Config {
    target: u64,
    gain_num: u64,
    gain_den: u64,
    lo_num: u64,
    lo_den: u64,
    hi_num: u64,
    hi_den: u64,
    range_min: u64,
    range_max: u64,
    delay_windows: u64,
    rounding: Rounding,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum Error {
    InvalidConfig,
    Overflow,
    InvalidWindow,
    ActivationCollision,
    WrongContext,
    UndeclaredDivergence,
}

impl Config {
    fn validate(self, current: u64) -> Result<Self, Error> {
        if self.target == 0
            || self.gain_num == 0
            || self.gain_num > self.gain_den
            || self.lo_num == 0
            || self.lo_den == 0
            || self.hi_num == 0
            || self.hi_den == 0
            || self.lo_num > self.lo_den
            || self.hi_num < self.hi_den
            || self.range_min == 0
            || self.range_min > current
            || current > self.range_max
            || self.delay_windows == 0
        {
            return Err(Error::InvalidConfig);
        }
        let lo_hi = u128::from(self.lo_num)
            .checked_mul(u128::from(self.hi_den))
            .ok_or(Error::Overflow)?;
        let hi_lo = u128::from(self.hi_num)
            .checked_mul(u128::from(self.lo_den))
            .ok_or(Error::Overflow)?;
        if lo_hi > hi_lo {
            return Err(Error::InvalidConfig);
        }
        // Dominio exacto del kernel u128 declarado en CONTRATO.md.
        u128::from(self.range_max)
            .checked_mul(u128::from(self.gain_den))
            .and_then(|value| value.checked_mul(u128::from(u64::MAX)))
            .ok_or(Error::InvalidConfig)?;
        Ok(self)
    }
}

fn divide_round(num: u128, den: u128, rounding: Rounding) -> Result<u128, Error> {
    if den == 0 {
        return Err(Error::InvalidConfig);
    }
    let quotient = num / den;
    let remainder = num % den;
    if rounding == Rounding::Floor {
        return Ok(quotient);
    }
    // Comparar con el complemento evita `2*remainder`, que no cabe en todo el dominio u128.
    let complement = den.checked_sub(remainder).ok_or(Error::Overflow)?;
    if remainder < complement || (remainder == complement && quotient.is_multiple_of(2)) {
        Ok(quotient)
    } else {
        quotient.checked_add(1).ok_or(Error::Overflow)
    }
}

fn ceil_ratio(value: u64, num: u64, den: u64) -> Result<u128, Error> {
    let product = u128::from(value)
        .checked_mul(u128::from(num))
        .ok_or(Error::Overflow)?;
    let denominator = u128::from(den);
    let quotient = product / denominator;
    if product % denominator == 0 {
        Ok(quotient)
    } else {
        quotient.checked_add(1).ok_or(Error::Overflow)
    }
}

fn next_range(current: u64, observed: u64, config: Config) -> Result<(u64, bool), Error> {
    let config = config.validate(current)?;
    if observed == 0 {
        return Ok((current, false));
    }
    let blend = u128::from(config.gain_den - config.gain_num)
        .checked_mul(u128::from(observed))
        .and_then(|left| {
            u128::from(config.gain_num)
                .checked_mul(u128::from(config.target))
                .and_then(|right| left.checked_add(right))
        })
        .ok_or(Error::Overflow)?;
    let numerator = u128::from(current)
        .checked_mul(blend)
        .ok_or(Error::Overflow)?;
    let denominator = u128::from(config.gain_den)
        .checked_mul(u128::from(observed))
        .ok_or(Error::Overflow)?;
    let raw = divide_round(numerator, denominator, config.rounding)?;
    let lower = u128::from(current)
        .checked_mul(u128::from(config.lo_num))
        .ok_or(Error::Overflow)?
        / u128::from(config.lo_den);
    let upper = ceil_ratio(current, config.hi_num, config.hi_den)?;
    let stepped = raw.clamp(lower, upper);
    let bounded = stepped.clamp(u128::from(config.range_min), u128::from(config.range_max));
    let narrowed = u64::try_from(bounded).map_err(|_| Error::Overflow)?;
    Ok((narrowed, bounded != raw))
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum StepCode {
    Pending,
    HeldZero,
    Scheduled,
    Missed,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
struct Step {
    code: StepCode,
    next: u64,
    activation: u64,
    clamped: bool,
}

fn causal_step(
    current: u64,
    observed: Option<u64>,
    cutoff: u64,
    seal_slot: u64,
    width: u64,
    config: Config,
) -> Result<Step, Error> {
    let config = config.validate(current)?;
    if width == 0 || seal_slot < cutoff {
        return Err(Error::InvalidWindow);
    }
    let Some(observed) = observed else {
        return Ok(Step {
            code: StepCode::Pending,
            next: current,
            activation: 0,
            clamped: false,
        });
    };
    let first_boundary = (cutoff / width)
        .checked_add(1)
        .and_then(|value| value.checked_mul(width))
        .ok_or(Error::Overflow)?;
    let delay_extra = config
        .delay_windows
        .checked_sub(1)
        .and_then(|value| value.checked_mul(width))
        .ok_or(Error::Overflow)?;
    let activation = first_boundary
        .checked_add(delay_extra)
        .ok_or(Error::Overflow)?;
    if seal_slot >= activation {
        return Ok(Step {
            code: StepCode::Missed,
            next: current,
            activation,
            clamped: false,
        });
    }
    if observed == 0 {
        // Enmienda Z0 (2026-09-12): HeldZero es no-op. Activación 0, en paralelo exacto
        // con Pending, para que ningún llamante pueda agendar la propuesta.
        return Ok(Step {
            code: StepCode::HeldZero,
            next: current,
            activation: 0,
            clamped: false,
        });
    }
    let (next, clamped) = next_range(current, observed, config)?;
    Ok(Step {
        code: StepCode::Scheduled,
        next,
        activation,
        clamped,
    })
}

#[test]
fn pending_no_elude_validacion_de_ventana() {
    let config = feedback_config();
    assert_eq!(
        causal_step(100, None, 10, 10, 0, config),
        Err(Error::InvalidWindow)
    );
    assert_eq!(
        causal_step(100, None, 10, 9, 10, config),
        Err(Error::InvalidWindow)
    );
}

fn parse_u64(token: Option<&str>, line: usize) -> u64 {
    token
        .unwrap_or_else(|| panic!("falta entero en línea {line}"))
        .parse()
        .unwrap_or_else(|_| panic!("entero inválido en línea {line}"))
}

#[test]
fn fixtures_enteros_compartidos_con_julia() {
    for (index, raw) in FIXTURES.lines().enumerate() {
        let line_number = index + 1;
        let line = raw.split('#').next().unwrap_or_default().trim();
        if line.is_empty() {
            continue;
        }
        let mut fields = line.split_whitespace();
        assert_eq!(
            fields.next(),
            Some("STEP"),
            "directiva en línea {line_number}"
        );
        let current = parse_u64(fields.next(), line_number);
        let observed = match fields.next() {
            Some("-") => None,
            token => Some(parse_u64(token, line_number)),
        };
        let cutoff = parse_u64(fields.next(), line_number);
        let seal = parse_u64(fields.next(), line_number);
        let width = parse_u64(fields.next(), line_number);
        let target = parse_u64(fields.next(), line_number);
        let gain_num = parse_u64(fields.next(), line_number);
        let gain_den = parse_u64(fields.next(), line_number);
        let lo_num = parse_u64(fields.next(), line_number);
        let lo_den = parse_u64(fields.next(), line_number);
        let hi_num = parse_u64(fields.next(), line_number);
        let hi_den = parse_u64(fields.next(), line_number);
        let range_min = parse_u64(fields.next(), line_number);
        let range_max = parse_u64(fields.next(), line_number);
        let delay_windows = parse_u64(fields.next(), line_number);
        let rounding = match fields.next() {
            Some("Floor") => Rounding::Floor,
            Some("NearestEven") => Rounding::NearestEven,
            _ => panic!("redondeo inválido en línea {line_number}"),
        };
        let expected_code = match fields.next() {
            Some("Pending") => StepCode::Pending,
            Some("HeldZero") => StepCode::HeldZero,
            Some("Scheduled") => StepCode::Scheduled,
            Some("Missed") => StepCode::Missed,
            _ => panic!("código inválido en línea {line_number}"),
        };
        let expected = fields.next().expect("falta resultado");
        let mut parts = expected.split(':');
        let expected_next = parse_u64(parts.next(), line_number);
        let expected_activation = parse_u64(parts.next(), line_number);
        let expected_clamped = match parts.next() {
            Some("0") => false,
            Some("1") => true,
            _ => panic!("clamp inválido en línea {line_number}"),
        };
        assert!(
            parts.next().is_none(),
            "resultado sobrante en línea {line_number}"
        );
        assert!(
            fields.next().is_none(),
            "campo sobrante en línea {line_number}"
        );
        let config = Config {
            target,
            gain_num,
            gain_den,
            lo_num,
            lo_den,
            hi_num,
            hi_den,
            range_min,
            range_max,
            delay_windows,
            rounding,
        };
        assert_eq!(
            causal_step(current, observed, cutoff, seal, width, config),
            Ok(Step {
                code: expected_code,
                next: expected_next,
                activation: expected_activation,
                clamped: expected_clamped,
            }),
            "línea {line_number}"
        );
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord)]
struct EventId(u64, u64);

#[derive(Clone, Debug, PartialEq, Eq)]
struct Event {
    id: EventId,
    window: u64,
}

#[derive(Clone, Debug, Default, PartialEq, Eq)]
struct Journal {
    events: Vec<Event>,
    sealed: BTreeMap<u64, Vec<EventId>>,
}

impl Journal {
    fn append(&mut self, event: Event) -> Result<(), Error> {
        if self.events.iter().any(|known| known.id == event.id) {
            return Err(Error::InvalidWindow);
        }
        self.events.push(event);
        Ok(())
    }

    fn payable(&self, window: u64) -> Vec<EventId> {
        self.events
            .iter()
            .filter(|event| event.window == window)
            .map(|event| event.id)
            .collect()
    }

    fn counted(&self, window: u64) -> Vec<EventId> {
        self.sealed
            .get(&window)
            .cloned()
            .unwrap_or_else(|| self.payable(window))
    }

    fn seal(&mut self, window: u64) {
        let ids = self.payable(window);
        self.sealed.entry(window).or_insert(ids);
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
struct Proposal {
    source_context: u64,
    source_window: u64,
    counted_ids: Vec<EventId>,
    base_range: u64,
    next_range: u64,
}

#[derive(Clone, Debug, PartialEq, Eq)]
struct FeedbackState {
    context: u64,
    active_range: u64,
    journal: Journal,
    schedule: BTreeMap<u64, Proposal>,
}

#[derive(Clone, Debug)]
struct Undo {
    new_context: u64,
    before: FeedbackState,
}

impl FeedbackState {
    fn transact<F>(&mut self, new_context: u64, operation: F) -> Result<Undo, Error>
    where
        F: FnOnce(&mut Self) -> Result<(), Error>,
    {
        let before = self.clone();
        let mut next = before.clone();
        // El contexto identifica la nueva vista; no es una altura comparable.
        next.context = new_context;
        operation(&mut next)?;
        *self = next;
        Ok(Undo {
            new_context,
            before,
        })
    }

    fn undo(&mut self, undo: Undo) -> Result<(), Error> {
        if self.context != undo.new_context {
            return Err(Error::WrongContext);
        }
        *self = undo.before;
        Ok(())
    }

    fn close(
        &mut self,
        window: u64,
        cutoff: u64,
        seal_slot: u64,
        width: u64,
        config: Config,
        divergence_declared: bool,
    ) -> Result<Step, Error> {
        self.journal.seal(window);
        let counted = self.journal.counted(window);
        let payable = self.journal.payable(window);
        if counted != payable && !divergence_declared {
            return Err(Error::UndeclaredDivergence);
        }
        let observed = u64::try_from(counted.len()).map_err(|_| Error::Overflow)?;
        let step = causal_step(
            self.active_range,
            Some(observed),
            cutoff,
            seal_slot,
            width,
            config,
        )?;
        if step.code == StepCode::Scheduled {
            let proposal = Proposal {
                source_context: self.context,
                source_window: window,
                counted_ids: counted,
                base_range: self.active_range,
                next_range: step.next,
            };
            if self.schedule.contains_key(&step.activation) {
                return Err(Error::ActivationCollision);
            }
            self.schedule.insert(step.activation, proposal);
        }
        Ok(step)
    }

    fn activate(&mut self, slot: u64) {
        if let Some(proposal) = self.schedule.remove(&slot) {
            self.active_range = proposal.next_range;
        }
    }
}

fn add_window_events(state: &mut FeedbackState, context: u64, window: u64, count: u64) {
    for block in 1..=count {
        state
            .journal
            .append(Event {
                id: EventId(context, block),
                window,
            })
            .expect("IDs sintéticos únicos");
    }
}

fn feedback_config() -> Config {
    Config {
        target: 10,
        gain_num: 1,
        gain_den: 1,
        lo_num: 1,
        lo_den: 10,
        hi_num: 10,
        hi_den: 1,
        range_min: 1,
        range_max: 1_000,
        delay_windows: 1,
        rounding: Rounding::Floor,
    }
}

#[test]
fn cada_rama_realimenta_su_propio_rango_y_undo_no_contamina() {
    let common = FeedbackState {
        context: 77,
        active_range: 100,
        journal: Journal::default(),
        schedule: BTreeMap::new(),
    };
    let mut scarce = common.clone();
    let mut abundant = common.clone();
    let config = feedback_config();

    let undo_scarce = scarce
        .transact(9, |branch| {
            add_window_events(branch, 9, 0, 5);
            branch.close(0, 10, 10, 10, config, false)?;
            Ok(())
        })
        .expect("rama escasa válida");
    let first_scarce = scarce.clone();
    abundant
        .transact(3, |branch| {
            add_window_events(branch, 3, 0, 20);
            branch.close(0, 10, 10, 10, config, false)?;
            Ok(())
        })
        .expect("rama abundante válida");
    let first_abundant = abundant.clone();
    // B0: cerrar sólo agenda; el rango inicial sigue activo hasta la frontera causal.
    assert_eq!(scarce.active_range, 100);
    assert_eq!(abundant.active_range, 100);

    scarce.activate(20);
    abundant.activate(20);
    assert_eq!(scarce.active_range, 200);
    assert_eq!(abundant.active_range, 50);
    let scarce_first = first_scarce.schedule.get(&20).expect("propuesta escasa");
    let abundant_first = first_abundant
        .schedule
        .get(&20)
        .expect("propuesta abundante");
    assert_eq!(scarce_first.source_context, 9);
    assert_eq!(abundant_first.source_context, 3);
    assert_eq!(scarce_first.counted_ids, first_scarce.journal.payable(0));
    assert_eq!(
        abundant_first.counted_ids,
        first_abundant.journal.payable(0)
    );

    // La siguiente ventana parte del rango propio ya activado, no del de la otra variante.
    scarce
        .transact(5, |branch| {
            add_window_events(branch, 5, 1, 10);
            branch.close(1, 20, 20, 10, config, false)?;
            Ok(())
        })
        .expect("segunda ventana escasa");
    abundant
        .transact(4, |branch| {
            add_window_events(branch, 4, 1, 10);
            branch.close(1, 20, 20, 10, config, false)?;
            Ok(())
        })
        .expect("segunda ventana abundante");
    assert_eq!(scarce.schedule.get(&30).expect("propuesta").base_range, 200);
    assert_eq!(
        abundant.schedule.get(&30).expect("propuesta").base_range,
        50
    );

    // Los contextos son opacos (9 no es una altura). Un undo solo acepta su contexto exacto.
    let mut restored = common.clone();
    restored.context = 8;
    assert_eq!(restored.undo(undo_scarce.clone()), Err(Error::WrongContext));
    let mut first_branch = first_scarce;
    first_branch.undo(undo_scarce).expect("undo contextual");
    assert_eq!(first_branch, common);
    assert_ne!(scarce.journal.events, abundant.journal.events);
}

#[test]
fn error_transaccional_no_publica_estado_parcial() {
    let original = FeedbackState {
        context: 41,
        active_range: 100,
        journal: Journal::default(),
        schedule: BTreeMap::new(),
    };
    let mut state = original.clone();
    let result = state.transact(7, |working| {
        add_window_events(working, 7, 0, 1);
        working.close(0, u64::MAX, u64::MAX, 1, feedback_config(), false)?;
        Ok(())
    });
    assert!(matches!(result, Err(Error::Overflow)));
    assert_eq!(state, original);
}

#[test]
fn dominio_u128_se_rechaza_antes_del_kernel() {
    let at_limit = Config {
        target: u64::MAX,
        gain_num: 1,
        gain_den: 1,
        lo_num: 1,
        lo_den: 1,
        hi_num: 1,
        hi_den: 1,
        range_min: 1,
        range_max: u64::MAX,
        delay_windows: 1,
        rounding: Rounding::Floor,
    };
    assert_eq!(at_limit.validate(u64::MAX), Ok(at_limit));

    let outside = Config {
        gain_den: 2,
        ..at_limit
    };
    assert_eq!(outside.validate(u64::MAX), Err(Error::InvalidConfig));
}

#[test]
fn sello_y_pago_salen_del_mismo_journal_sin_retroactividad() {
    let mut journal = Journal::default();
    journal
        .append(Event {
            id: EventId(10, 1),
            window: 0,
        })
        .expect("evento");
    journal.seal(0);
    journal
        .append(Event {
            id: EventId(20, 2),
            window: 0,
        })
        .expect("evento tardío L0");
    assert_eq!(journal.counted(0), vec![EventId(10, 1)]);
    assert_eq!(journal.payable(0), vec![EventId(10, 1), EventId(20, 2)]);
    assert_eq!(journal.sealed.get(&0), Some(&vec![EventId(10, 1)]));
    assert_eq!(
        journal
            .events
            .iter()
            .map(|event| event.id)
            .collect::<BTreeSet<_>>()
            .len(),
        journal.events.len()
    );
}

#[path = "soporte/admision_retarget_multivista_frontera.rs"]
mod arm_frontera;
