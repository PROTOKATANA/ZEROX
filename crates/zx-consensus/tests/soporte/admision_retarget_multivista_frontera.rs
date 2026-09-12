//! Frontera temporal ARM-v0.1, módulo hijo del test RCE para reutilizar sus APIs privadas.
//!
//! Estas comprobaciones sólo acoplan eventos sintéticos al controlador entero RCE.
//! No ejecutan DCM, PoAS/PoT, GHOSTDAG, autorización ni transición económica.
//! Al ejecutar el test RCE sin filtro también se ejecutan sus seis pruebas heredadas.
//! Enmienda Z0 (2026-09-12): HeldZero es no-op en Julia y en Rust; ya no hay dos
//! semánticas que contrastar. `FeedbackState::close` agendaba sólo Scheduled y era
//! correcto; el adaptador que completaba la agenda HeldZero se retiró.

#![expect(
    clippy::indexing_slicing,
    reason = "vectores de prueba con longitud explícita"
)]

use super::*;

fn config() -> Config {
    Config {
        target: 10,
        gain_num: 1,
        gain_den: 1,
        lo_num: 1,
        lo_den: 2,
        hi_num: 2,
        hi_den: 1,
        range_min: 1,
        range_max: 1_000,
        delay_windows: 1,
        rounding: Rounding::Floor,
    }
}

#[derive(Clone, Debug)]
struct Frame {
    history: u64,
    cohort: u64,
    causal_seal: u64,
    // None representa evidencia incompleta; Some([]), una cohorte realmente vacía.
    events: Option<Vec<EventId>>,
}

fn frame(history: u64, cohort: u64, causal_seal: u64, count: u64) -> Frame {
    Frame {
        history,
        cohort,
        causal_seal,
        events: Some((1..=count).map(|block| EventId(history, block)).collect()),
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
struct State {
    feedback: FeedbackState,
    observations: Vec<(u64, u64, Step)>,
    activations: Vec<(u64, Proposal)>,
}

impl State {
    fn genesis() -> Self {
        Self {
            feedback: FeedbackState {
                context: 0,
                active_range: 100,
                journal: Journal::default(),
                schedule: BTreeMap::new(),
            },
            observations: Vec::new(),
            activations: Vec::new(),
        }
    }

    fn activate_through(&mut self, causal_slot: u64) {
        let due = self
            .feedback
            .schedule
            .range(..=causal_slot)
            .map(|(slot, proposal)| (*slot, proposal.clone()))
            .collect::<Vec<_>>();
        for (slot, proposal) in due {
            self.feedback.activate(slot);
            self.activations.push((slot, proposal));
        }
    }
}

#[derive(Debug, PartialEq, Eq)]
enum Replay {
    Applied,
    Pending,
}

fn reconstruct(frames: &[Frame]) -> Result<Option<State>, Error> {
    reconstruct_with_config(frames, config())
}

fn reconstruct_with_config(frames: &[Frame], controller: Config) -> Result<Option<State>, Error> {
    controller.validate(100)?;
    let mut histories = BTreeSet::new();
    let mut previous_seal = 0;
    // Validación de descriptores antes de preparar/publicar estado.
    for (index, frame) in frames.iter().enumerate() {
        let expected = u64::try_from(index).map_err(|_| Error::Overflow)?;
        let cutoff = expected
            .checked_add(1)
            .and_then(|v| v.checked_mul(10))
            .ok_or(Error::Overflow)?;
        if frame.history == 0
            || !histories.insert(frame.history)
            || frame.cohort != expected
            || frame.causal_seal < cutoff
            || frame.causal_seal < previous_seal
        {
            return Err(Error::InvalidWindow);
        }
        previous_seal = frame.causal_seal;
    }
    // Nunca llamar a close con N=0 inferido de un cuerpo/contexto ausente.
    if frames.iter().any(|frame| frame.events.is_none()) {
        return Ok(None);
    }
    let mut candidate = State::genesis();
    for frame in frames {
        let cutoff = frame
            .cohort
            .checked_add(1)
            .and_then(|v| v.checked_mul(10))
            .ok_or(Error::Overflow)?;
        let events = frame.events.as_ref().expect("evidencia comprobada");
        if events.iter().any(|id| id.0 != frame.history || id.1 == 0) {
            return Err(Error::InvalidWindow);
        }
        candidate.activate_through(frame.causal_seal);
        let mut observed_step = None;
        candidate.feedback.transact(frame.history, |working| {
            for id in events {
                working.journal.append(Event {
                    id: *id,
                    window: frame.cohort,
                })?;
            }
            observed_step = Some(working.close(
                frame.cohort,
                cutoff,
                frame.causal_seal,
                10,
                controller,
                false,
            )?);
            Ok(())
        })?;
        candidate.observations.push((
            frame.history,
            frame.cohort,
            observed_step.expect("sello transaccional completado"),
        ));
    }
    Ok(Some(candidate))
}

fn replay(public: &mut State, frames: &[Frame]) -> Result<Replay, Error> {
    let Some(candidate) = reconstruct(frames)? else {
        return Ok(Replay::Pending);
    };
    *public = candidate;
    Ok(Replay::Applied)
}

fn local_control(objective: &Frame, local_ready: u64) -> Result<Option<State>, Error> {
    let cutoff = objective
        .cohort
        .checked_add(1)
        .and_then(|v| v.checked_mul(10))
        .ok_or(Error::Overflow)?;
    let mut local = objective.clone();
    // Composición deliberadamente incorrecta: sustituye el sello causal común.
    // No pretende modelar el planificador de recepción/cierre del nodo.
    local.causal_seal = cutoff.max(local_ready);
    reconstruct(&[local])
}

#[test]
fn reloj_local_diverge_con_los_mismos_ids_y_fronteras_19_20_21() {
    let objective = frame(900, 0, 10, 5);
    // Evidencia disponible en 9, antes del cierre en 10; no invertir fases RCE.
    let mut ana = local_control(&objective, 9)
        .expect("marco válido")
        .expect("evidencia completa");
    assert_eq!(ana.feedback.active_range, 100);
    assert_eq!(ana.observations[0].2.code, StepCode::Scheduled);
    assert_eq!(
        ana.feedback.schedule.get(&20).expect("agenda").next_range,
        200
    );
    ana.activate_through(20);
    assert_eq!(ana.feedback.active_range, 200);
    for (receipt, expected_code, expected_range) in [
        (19, StepCode::Scheduled, 200),
        (20, StepCode::Missed, 100),
        (21, StepCode::Missed, 100),
    ] {
        let mut bruno = local_control(&objective, receipt)
            .expect("marco válido")
            .expect("completo");
        assert_eq!(bruno.observations[0].2.code, expected_code);
        bruno.activate_through(21);
        assert_eq!(bruno.feedback.active_range, expected_range);
        assert_eq!(ana.feedback.journal, bruno.feedback.journal);
        assert_eq!(
            bruno.feedback.journal.counted(0),
            objective.events.clone().expect("IDs")
        );
    }
}

#[test]
fn replay_causal_tardio_converge_con_fuentes_y_activaciones_exactas() {
    let frames = [frame(900, 0, 10, 5), frame(2, 1, 20, 0)];
    let mut ana = State::genesis();
    assert_eq!(replay(&mut ana, &frames), Ok(Replay::Applied));
    assert_eq!(ana.feedback.active_range, 200);
    let activation = ana.activations.first().expect("activación ancestral");
    assert_eq!(activation.0, 20);
    assert_eq!(activation.1.source_context, 900);
    assert_eq!(activation.1.source_window, 0);
    assert_eq!(activation.1.base_range, 100);
    assert_eq!(activation.1.next_range, 200);
    assert_eq!(
        activation.1.counted_ids,
        frames[0].events.clone().expect("IDs")
    );
    let mut bruno = State::genesis();
    let before = bruno.clone();
    let mut incomplete = frames.clone();
    incomplete[0].events = None;
    assert_eq!(replay(&mut bruno, &incomplete), Ok(Replay::Pending));
    assert_eq!(bruno, before);
    // Tras recepción local tardía, se reproduce el mismo prefijo objetivo.
    assert_eq!(replay(&mut bruno, &frames), Ok(Replay::Applied));
    assert_eq!(ana, bruno);
    assert_eq!(replay(&mut bruno, &frames), Ok(Replay::Applied));
    assert_eq!(ana, bruno);
}

#[test]
fn missed_causal_y_ventana_vacia_no_se_confunden_con_pending() {
    let missed = reconstruct(&[frame(900, 0, 20, 5)])
        .expect("marco válido")
        .expect("completo");
    assert_eq!(missed.observations[0].2.code, StepCode::Missed);
    assert_eq!(missed.feedback.active_range, 100);
    assert!(missed.feedback.schedule.is_empty());
    let empty = reconstruct(&[frame(900, 0, 10, 0)])
        .expect("marco válido")
        .expect("completo");
    assert_eq!(empty.observations[0].2.code, StepCode::HeldZero);
    assert_eq!(empty.observations[0].2.activation, 0);
    // Enmienda Z0 (2026-09-12): la ventana vacía sí se sella y sí se registra…
    assert_eq!(empty.feedback.journal.sealed.get(&0), Some(&Vec::new()));
    // …pero HeldZero no agenda: la agenda queda vacía.
    assert!(empty.feedback.schedule.is_empty());
    let mut incomplete = frame(900, 0, 10, 0);
    incomplete.events = None;
    let mut public = missed.clone();
    assert_eq!(replay(&mut public, &[incomplete]), Ok(Replay::Pending));
    assert_eq!(public, missed);
}

#[test]
fn reorg_reemplaza_agendas_y_prefijo_o_genesis_retiraran_el_sufijo() {
    let first = frame(900, 0, 10, 5);
    let alternative = frame(901, 0, 10, 20);
    let mut public = reconstruct(&[first])
        .expect("rama válida")
        .expect("completa");
    assert_eq!(
        public
            .feedback
            .schedule
            .get(&20)
            .expect("agenda")
            .next_range,
        200
    );
    assert_eq!(
        replay(&mut public, std::slice::from_ref(&alternative)),
        Ok(Replay::Applied)
    );
    let proposal = public
        .feedback
        .schedule
        .get(&20)
        .expect("agenda alternativa");
    assert_eq!(proposal.source_context, 901);
    assert_eq!(proposal.next_range, 50);
    assert_eq!(public.feedback.schedule.len(), 1);
    let prefix = public.clone();
    assert_eq!(
        replay(&mut public, &[alternative.clone(), frame(3, 1, 20, 10)]),
        Ok(Replay::Applied)
    );
    assert_eq!(public.feedback.active_range, 50);
    assert_eq!(public.activations[0].1.source_context, 901);
    assert_eq!(
        public
            .feedback
            .schedule
            .get(&30)
            .expect("agenda nueva")
            .base_range,
        50
    );
    assert_eq!(replay(&mut public, &[alternative]), Ok(Replay::Applied));
    assert_eq!(public, prefix);
    assert_eq!(replay(&mut public, &[]), Ok(Replay::Applied));
    assert_eq!(public, State::genesis());
}

#[test]
fn errores_de_marco_y_overflow_no_publican() {
    let mut public = reconstruct(&[frame(900, 0, 10, 5)])
        .expect("válido")
        .expect("completo");
    let before = public.clone();
    let mut duplicate = frame(901, 0, 10, 1);
    duplicate
        .events
        .as_mut()
        .expect("completo")
        .push(EventId(901, 1));
    let mut foreign = frame(901, 0, 10, 1);
    foreign.events = Some(vec![EventId(900, 1)]);
    for invalid in [
        vec![frame(0, 0, 10, 5)],
        vec![frame(901, 1, 20, 5)],
        vec![frame(901, 0, 9, 5)],
        vec![frame(901, 0, 21, 5), frame(2, 1, 20, 5)],
        vec![frame(901, 0, 10, 5), frame(901, 1, 20, 5)],
        vec![duplicate],
        vec![foreign],
    ] {
        assert!(replay(&mut public, &invalid).is_err());
        assert_eq!(public, before);
    }
    let mut feedback = before.feedback.clone();
    let original = feedback.clone();
    let overflow = feedback.transact(2, |working| {
        working.close(1, u64::MAX, u64::MAX, 10, config(), false)?;
        Ok(())
    });
    assert!(matches!(overflow, Err(Error::Overflow)));
    assert_eq!(feedback, original);
}

#[test]
fn undo_rce_restaura_rango_agenda_snapshot_y_eventos() {
    let mut state = State::genesis().feedback;
    let original = state.clone();
    let undo = state
        .transact(900, |working| {
            add_window_events(working, 900, 0, 5);
            working.close(0, 10, 10, 10, config(), false)?;
            Ok(())
        })
        .expect("transición válida");
    state.activate(20);
    assert_eq!(state.active_range, 200);
    state.undo(undo).expect("contexto exacto");
    assert_eq!(state, original);
}

#[test]
fn held_zero_con_delay_dos_es_no_op_y_converge_con_julia() {
    // Enmienda Z0 (2026-09-12). Vector elegido ARM: W=10 slots, R0=100, Q=10,
    // ganancia=1, desfase=2 ventanas. N0=5 en sello10 propone 200@30; N1=0 en
    // sello20 ya no agenda nada: el rango en el slot 40 es 200, no 100.
    let controller = Config {
        delay_windows: 2,
        ..config()
    };
    let frames = [frame(900, 0, 10, 5), frame(2, 1, 20, 0)];
    assert_eq!(
        causal_step(100, Some(0), 20, 20, 10, controller),
        Ok(Step {
            code: StepCode::HeldZero,
            next: 100,
            activation: 0,
            clamped: false,
        })
    );
    let mut arm = reconstruct_with_config(&frames, controller)
        .expect("marcos válidos")
        .expect("evidencia completa");
    // En el slot 40 ya no hay nada agendado; la propuesta 200@30 sigue ahí.
    assert!(!arm.feedback.schedule.contains_key(&40));
    assert_eq!(
        arm.feedback
            .schedule
            .get(&30)
            .expect("propuesta previa")
            .next_range,
        200
    );

    // Control legado: close sin adaptador. Enmienda Z0: ambos caminos coinciden.
    let mut legacy = State::genesis().feedback;
    legacy
        .transact(900, |working| {
            add_window_events(working, 900, 0, 5);
            assert_eq!(
                working.close(0, 10, 10, 10, controller, false)?.code,
                StepCode::Scheduled
            );
            Ok(())
        })
        .expect("primer sello legado");
    legacy
        .transact(2, |working| {
            assert_eq!(
                working.close(1, 20, 20, 10, controller, false)?.code,
                StepCode::HeldZero
            );
            Ok(())
        })
        .expect("segundo sello legado");
    assert_eq!(legacy.journal, arm.feedback.journal);
    assert_eq!(legacy.schedule, arm.feedback.schedule);
    assert!(!legacy.schedule.contains_key(&40));
    legacy.activate(30);
    arm.activate_through(30);
    assert_eq!(legacy.active_range, 200);
    assert_eq!(arm.feedback.active_range, 200);
    arm.activate_through(39);
    assert_eq!(arm.feedback.active_range, 200);
    legacy.activate(40);
    arm.activate_through(40);
    assert_eq!(legacy.active_range, 200);
    assert_eq!(arm.feedback.active_range, 200);
    assert_eq!(arm.activations.len(), 1);
    assert_eq!(arm.activations.first().map(|(slot, _)| *slot), Some(30));
    assert_eq!(legacy, arm.feedback);
    println!("held_zero_delay_dos_converge=true legacy_range_at_40=200 arm_range_at_40=200");
}
