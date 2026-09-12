//! Modelo estructural ventana-retarget-causal-v1, exclusivo de tests.
//!
//! No calcula rango, PoAS, PoT ni GHOSTDAG. El orden, color y estado del cuerpo son entradas
//! sintéticas. Su única salida para un futuro controlador es el conjunto exacto de `EventId`
//! adjudicados; no contiene una fórmula ni parámetros de red.

#![expect(
    clippy::expect_used,
    clippy::integer_division,
    clippy::panic,
    reason = "el arnés falla inmediatamente ante fixtures mal formados; la división entera define cohortes"
)]

use std::collections::{BTreeMap, BTreeSet};

const FIXTURES: &str =
    include_str!("../../../veritas/consenso/ventana-retarget-causal-v1/fixtures/CASOS.txt");

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum Selection {
    P0,
    P1,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum LatePolicy {
    /// CBE-06: `[incorporation_slot - W_adm, incorporation_slot]`, con resta saturada.
    L0 { admission_width: u64 },
    /// Candidato por cohortes; no es una variante homogénea de L0.
    Lg,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum Color {
    Blue,
    RedK,
    RedU3,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum Body {
    Complete,
    Pending,
    Invalid,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord)]
struct EventId {
    context: u64,
    block: u64,
}

#[derive(Clone, Debug, PartialEq, Eq)]
struct Event {
    id: EventId,
    ticket: u64,
    original_slot: u64,
    incorporation_slot: u64,
    subsidy: u64,
    fees: u64,
}

#[derive(Clone, Debug, PartialEq, Eq)]
struct WindowSeal {
    event_ids: Vec<EventId>,
    /// Contexto exacto que produjo el sello. Dos contextos pueden compartir slot.
    context: u64,
    context_slot: u64,
}

#[derive(Clone, Debug, Default, PartialEq, Eq)]
struct State {
    context: u64,
    context_slot: u64,
    journal: Vec<Event>,
    tickets: BTreeMap<u64, EventId>,
    seen_blocks: BTreeSet<u64>,
    causal_exclusions: Vec<u64>,
    sealed_windows: BTreeMap<u64, WindowSeal>,
}

#[derive(Clone, Debug)]
struct Controller {
    width: u64,
    grace: u64,
    origin: u64,
}

impl Controller {
    fn bounds(&self, window_id: u64) -> Result<(u64, u64, u64), ApplyResult> {
        if self.width == 0 {
            return Err(ApplyResult::Invalid);
        }
        let start = window_id
            .checked_mul(self.width)
            .and_then(|offset| self.origin.checked_add(offset))
            .ok_or(ApplyResult::Invalid)?;
        let end = start.checked_add(self.width).ok_or(ApplyResult::Invalid)?;
        let close = end.checked_add(self.grace).ok_or(ApplyResult::Invalid)?;
        Ok((start, end, close))
    }

    fn window_for_slot(&self, slot: u64) -> Result<(u64, u64, u64, u64), ApplyResult> {
        let offset = slot.checked_sub(self.origin).ok_or(ApplyResult::Invalid)?;
        let window_id = offset / self.width;
        let (start, end, close) = self.bounds(window_id)?;
        Ok((window_id, start, end, close))
    }
}

#[derive(Clone, Debug)]
struct Block {
    id: u64,
    ticket: u64,
    original_slot: u64,
    rank: u64,
    color: Color,
    body: Body,
    subsidy: u64,
    fees: u64,
}

#[derive(Clone, Debug)]
struct Batch {
    context: u64,
    parent: u64,
    incorporation_slot: u64,
    blocks: Vec<Block>,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum ApplyResult {
    Applied,
    Pending,
    Invalid,
}

#[derive(Clone, Debug, PartialEq, Eq)]
enum QueryResult {
    Bootstrap,
    Pending,
    Ready(Vec<EventId>),
}

fn event_ids(state: &State) -> Vec<EventId> {
    state.journal.iter().map(|event| event.id).collect()
}

/// Pagos y observaciones no se reconstruyen desde colores ni bloques: son dos proyecciones del
/// mismo journal. Comparar los IDs detecta divergencias que una mera igualdad de cardinalidad
/// podría ocultar.
fn economic_projections(
    state: &State,
    controller: &Controller,
    window_id: u64,
) -> Result<(Vec<EventId>, Vec<EventId>), ApplyResult> {
    let (start, end, _) = controller.bounds(window_id)?;
    let payable = state
        .journal
        .iter()
        .filter(|event| start <= event.original_slot && event.original_slot < end)
        .map(|event| event.id)
        .collect::<Vec<_>>();
    let counted = state
        .sealed_windows
        .get(&window_id)
        .map_or_else(|| payable.clone(), |seal| seal.event_ids.clone());
    Ok((counted, payable))
}

fn assert_journal_invariants(state: &State, controller: &Controller) {
    let ids = event_ids(state);
    assert_eq!(
        ids.iter().copied().collect::<BTreeSet<_>>().len(),
        ids.len()
    );
    assert_eq!(state.tickets.len(), state.journal.len());
    for event in &state.journal {
        assert_eq!(state.tickets.get(&event.ticket), Some(&event.id));
        assert!(state.seen_blocks.contains(&event.id.block));
        // El evento conserva importes aunque la igualdad económica no dependa de que sean > 0.
        let _ = (event.subsidy, event.fees);
    }
    for (window_id, seal) in &state.sealed_windows {
        // Los IDs de contexto son opacos: no se infiere causalidad de su orden numérico.
        let _ = (seal.context, seal.context_slot);
        let (counted, _) = economic_projections(state, controller, *window_id)
            .expect("parámetros estructurales válidos");
        assert_eq!(counted, seal.event_ids);
    }
}

fn is_late(
    policy: LatePolicy,
    controller: &Controller,
    block: &Block,
    incorporation_slot: u64,
) -> Result<bool, ApplyResult> {
    match policy {
        LatePolicy::L0 { admission_width } => {
            let low = incorporation_slot.saturating_sub(admission_width);
            Ok(!(low <= block.original_slot && block.original_slot <= incorporation_slot))
        }
        LatePolicy::Lg => {
            let (_, start, end, close) = controller.window_for_slot(block.original_slot)?;
            Ok(!(start <= block.original_slot
                && block.original_slot < end
                && incorporation_slot < close))
        }
    }
}

/// Condición suficiente puramente entera: como `s < origin + W`, una admisión L0 cumple
/// `i <= s + W_adm`; así, `G >= W_adm` implica `i < origin + W + G`.
/// No fija ningún valor de red ni redefine L0.
fn causal_sufficient(policy: LatePolicy, controller: &Controller) -> bool {
    match policy {
        LatePolicy::L0 { admission_width } => controller.grace >= admission_width,
        LatePolicy::Lg => true,
    }
}

fn apply(
    state: &mut State,
    batch: &Batch,
    selection: Selection,
    policy: LatePolicy,
    controller: &Controller,
) -> (ApplyResult, Vec<u64>, Option<State>) {
    if batch.parent != state.context
        || batch.context == 0
        || batch.context == state.context
        || batch.incorporation_slot < state.context_slot
    {
        return (ApplyResult::Invalid, Vec::new(), None);
    }

    let mut blocks = BTreeSet::new();
    let mut ranks = BTreeSet::new();
    let mut ticket_slots = BTreeMap::new();
    for block in &batch.blocks {
        if block.id == 0
            || block.ticket == 0
            || !blocks.insert(block.id)
            || state.seen_blocks.contains(&block.id)
            || !ranks.insert(block.rank)
            || block.original_slot > batch.incorporation_slot
            || block.original_slot < controller.origin
            || block.body == Body::Invalid
            || ticket_slots
                .insert(block.ticket, block.original_slot)
                .is_some_and(|slot| slot != block.original_slot)
            || state
                .tickets
                .get(&block.ticket)
                .and_then(|id| state.journal.iter().find(|event| event.id == *id))
                .is_some_and(|event| event.original_slot != block.original_slot)
        {
            return (ApplyResult::Invalid, Vec::new(), None);
        }
    }
    if batch.blocks.iter().any(|block| block.body == Body::Pending) {
        return (ApplyResult::Pending, Vec::new(), None);
    }

    let mut ordered: Vec<_> = batch.blocks.iter().collect();
    ordered.sort_by_key(|block| block.rank);
    let mut winners: BTreeMap<u64, &Block> = BTreeMap::new();
    for block in &ordered {
        let late = match is_late(policy, controller, block, batch.incorporation_slot) {
            Ok(late) => late,
            Err(result) => return (result, Vec::new(), None),
        };
        if block.color == Color::RedU3 || late || state.tickets.contains_key(&block.ticket) {
            continue;
        }
        match winners.get(&block.ticket) {
            None => {
                winners.insert(block.ticket, block);
            }
            Some(previous)
                if selection == Selection::P1
                    && previous.color == Color::RedK
                    && block.color == Color::Blue =>
            {
                winners.insert(block.ticket, block);
            }
            Some(_) => {}
        }
    }

    let mut next = state.clone();
    let mut winner_ids = Vec::new();
    for block in ordered {
        if winners.get(&block.ticket).map(|winner| winner.id) != Some(block.id) {
            continue;
        }
        let event_id = EventId {
            context: batch.context,
            block: block.id,
        };
        let Ok((_window_id, _, _, _)) = controller.window_for_slot(block.original_slot) else {
            return (ApplyResult::Invalid, Vec::new(), None);
        };
        if next.tickets.insert(block.ticket, event_id).is_some() {
            return (ApplyResult::Invalid, Vec::new(), None);
        }
        next.journal.push(Event {
            id: event_id,
            ticket: block.ticket,
            original_slot: block.original_slot,
            incorporation_slot: batch.incorporation_slot,
            subsidy: block.subsidy,
            fees: block.fees,
        });
        winner_ids.push(block.id);
    }
    next.seen_blocks.extend(blocks);
    next.context = batch.context;
    next.context_slot = batch.incorporation_slot;
    assert_journal_invariants(&next, controller);
    let before = state.clone();
    *state = next;
    (ApplyResult::Applied, winner_ids, Some(before))
}

fn query(
    state: &mut State,
    controller: &Controller,
    window_id: u64,
    query_slot: u64,
    unresolved: bool,
) -> Result<QueryResult, ApplyResult> {
    let (start, end, close) = controller.bounds(window_id)?;
    let next_window =
        u64::try_from(state.sealed_windows.len()).map_err(|_| ApplyResult::Invalid)?;
    if query_slot > state.context_slot || window_id > next_window {
        return Err(ApplyResult::Invalid);
    }
    if let Some(sealed) = state.sealed_windows.get(&window_id) {
        return Ok(QueryResult::Ready(sealed.event_ids.clone()));
    }
    if query_slot < close {
        return Ok(QueryResult::Bootstrap);
    }
    if unresolved {
        return Ok(QueryResult::Pending);
    }
    let ids: Vec<_> = state
        .journal
        .iter()
        .filter(|event| {
            start <= event.original_slot
                && event.original_slot < end
                && event.incorporation_slot <= query_slot
        })
        .map(|event| event.id)
        .collect();
    state.sealed_windows.insert(
        window_id,
        WindowSeal {
            event_ids: ids.clone(),
            context: state.context,
            context_slot: state.context_slot,
        },
    );
    Ok(QueryResult::Ready(ids))
}

fn parse_u64(token: Option<&str>, line: usize) -> u64 {
    token
        .unwrap_or_else(|| panic!("falta entero en línea {line}"))
        .parse()
        .unwrap_or_else(|_| panic!("entero no canónico en línea {line}"))
}

fn parse_ids(token: Option<&str>, line: usize) -> Vec<EventId> {
    let token = token.unwrap_or_else(|| panic!("falta lista en línea {line}"));
    if token == "-" {
        return Vec::new();
    }
    token
        .split(',')
        .map(|item| {
            let (context, block) = item
                .split_once(':')
                .unwrap_or_else(|| panic!("EventId no canónico en línea {line}"));
            EventId {
                context: context
                    .parse()
                    .unwrap_or_else(|_| panic!("contexto inválido en línea {line}")),
                block: block
                    .parse()
                    .unwrap_or_else(|_| panic!("bloque inválido en línea {line}")),
            }
        })
        .collect()
}

fn parse_winners(token: Option<&str>, line: usize) -> Vec<u64> {
    let token = token.unwrap_or_else(|| panic!("falta lista en línea {line}"));
    if token == "-" {
        Vec::new()
    } else {
        token
            .split(',')
            .map(|item| {
                item.parse()
                    .unwrap_or_else(|_| panic!("ID inválido en línea {line}"))
            })
            .collect()
    }
}

fn parse_u64_list(token: Option<&str>, line: usize) -> Vec<u64> {
    parse_winners(token, line)
}

#[test]
fn fixtures_compartidos_con_julia() {
    let mut state = State::default();
    let mut selection = Selection::P0;
    let mut policy = LatePolicy::L0 { admission_width: 0 };
    let mut controller = Controller {
        width: 1,
        grace: 0,
        origin: 0,
    };
    let mut batch: Option<Batch> = None;
    let mut last_apply: Option<(ApplyResult, Vec<u64>)> = None;
    let mut last_undo: Option<(u64, State)> = None;
    let mut case_name = String::new();

    for (index, raw) in FIXTURES.lines().enumerate() {
        let line_number = index + 1;
        let line = raw.split('#').next().unwrap_or_default().trim();
        if line.is_empty() {
            continue;
        }
        let mut fields = line.split_whitespace();
        match fields.next().expect("línea no vacía") {
            "CASE" => {
                state = State::default();
                last_undo = None;
                batch = None;
                last_apply = None;
                case_name = fields.next().expect("CASE sin nombre").to_owned();
                selection = match fields.next() {
                    Some("P0") => Selection::P0,
                    Some("P1") => Selection::P1,
                    _ => panic!("selección inválida en {case_name}"),
                };
                let policy_name = fields.next();
                let admission = fields.next().expect("falta W_adm");
                let controller_width = parse_u64(fields.next(), line_number);
                let grace = parse_u64(fields.next(), line_number);
                let origin = parse_u64(fields.next(), line_number);
                policy = match (policy_name, admission) {
                    (Some("L0"), value) if value != "-" => LatePolicy::L0 {
                        admission_width: value.parse().expect("W_adm inválido"),
                    },
                    (Some("LG"), "-") => LatePolicy::Lg,
                    _ => panic!("política/anchura inválida en {case_name}"),
                };
                controller = Controller {
                    width: controller_width,
                    grace,
                    origin,
                };
                assert_eq!(
                    controller.origin, 0,
                    "el perfil fixture se ancla al génesis"
                );
            }
            "BATCH" => {
                batch = Some(Batch {
                    context: parse_u64(fields.next(), line_number),
                    parent: parse_u64(fields.next(), line_number),
                    incorporation_slot: parse_u64(fields.next(), line_number),
                    blocks: Vec::new(),
                });
            }
            "BLOCK" => {
                let block = Block {
                    id: parse_u64(fields.next(), line_number),
                    ticket: parse_u64(fields.next(), line_number),
                    original_slot: parse_u64(fields.next(), line_number),
                    rank: parse_u64(fields.next(), line_number),
                    color: match fields.next() {
                        Some("B") => Color::Blue,
                        Some("K") => Color::RedK,
                        Some("U") => Color::RedU3,
                        _ => panic!("color inválido en línea {line_number}"),
                    },
                    body: match fields.next() {
                        Some("C") => Body::Complete,
                        Some("P") => Body::Pending,
                        Some("I") => Body::Invalid,
                        _ => panic!("cuerpo inválido en línea {line_number}"),
                    },
                    subsidy: parse_u64(fields.next(), line_number),
                    fees: parse_u64(fields.next(), line_number),
                };
                batch.as_mut().expect("BLOCK sin BATCH").blocks.push(block);
            }
            "APPLY" => {
                let current = batch.as_ref().expect("APPLY sin BATCH");
                let (result, winners, undo) =
                    apply(&mut state, current, selection, policy, &controller);
                last_undo = undo.map(|before| (current.context, before));
                last_apply = Some((result, winners));
            }
            "EXPECT" => {
                let expected_result = match fields.next() {
                    Some("Applied") => ApplyResult::Applied,
                    Some("Pending") => ApplyResult::Pending,
                    Some("Invalid") => ApplyResult::Invalid,
                    _ => panic!("EXPECT inválido en línea {line_number}"),
                };
                let expected_winners = parse_winners(fields.next(), line_number);
                let expected_events = parse_ids(fields.next(), line_number);
                let window_id = parse_u64(fields.next(), line_number);
                let expected_counted = parse_ids(fields.next(), line_number);
                let expected_payable = parse_ids(fields.next(), line_number);
                let expected_exclusions = parse_u64_list(fields.next(), line_number);
                let expected_equal = match fields.next() {
                    Some("Equal") => true,
                    Some("Diverges") => false,
                    _ => panic!("marcador de igualdad inválido en línea {line_number}"),
                };
                let (result, winners) = last_apply.as_ref().expect("EXPECT sin APPLY");
                assert_eq!(*result, expected_result, "resultado en {case_name}");
                assert_eq!(*winners, expected_winners, "ganadores en {case_name}");
                assert_eq!(event_ids(&state), expected_events, "journal en {case_name}");
                let (counted, payable) = economic_projections(&state, &controller, window_id)
                    .expect("ventana EXPECT válida");
                assert_eq!(counted, expected_counted, "conteo en {case_name}");
                assert_eq!(payable, expected_payable, "pagables en {case_name}");
                assert_eq!(
                    counted == payable,
                    expected_equal,
                    "igualdad en {case_name}"
                );
                if causal_sufficient(policy, &controller) {
                    assert_eq!(counted, payable, "suficiencia causal en {case_name}");
                }
                assert_eq!(
                    state.causal_exclusions, expected_exclusions,
                    "exclusiones en {case_name}"
                );
                assert_journal_invariants(&state, &controller);
            }
            "QUERY" => {
                let window_id = parse_u64(fields.next(), line_number);
                let query_slot = parse_u64(fields.next(), line_number);
                let unresolved = match fields.next() {
                    Some("true") => true,
                    Some("false") => false,
                    _ => panic!("unresolved inválido en línea {line_number}"),
                };
                let expected_kind = fields.next().expect("QUERY sin resultado");
                let expected_ids = parse_ids(fields.next(), line_number);
                let actual = query(&mut state, &controller, window_id, query_slot, unresolved)
                    .unwrap_or_else(|result| panic!("query inválida {result:?} en {case_name}"));
                let expected = match expected_kind {
                    "Bootstrap" => QueryResult::Bootstrap,
                    "Pending" => QueryResult::Pending,
                    "Ready" => QueryResult::Ready(expected_ids),
                    _ => panic!("resultado QUERY inválido en línea {line_number}"),
                };
                assert_eq!(actual, expected, "query en {case_name}");
            }
            "UNDO" => {
                let (new_context, before) = last_undo.take().expect("UNDO sin lote aplicado");
                assert_eq!(state.context, new_context, "undo ligado a otro contexto");
                state = before;
                batch = None;
                last_apply = None;
                assert_journal_invariants(&state, &controller);
            }
            "STATE" => {
                let expected_context = parse_u64(fields.next(), line_number);
                let expected_events = parse_ids(fields.next(), line_number);
                let window_id = parse_u64(fields.next(), line_number);
                let expected_counted = parse_ids(fields.next(), line_number);
                let expected_payable = parse_ids(fields.next(), line_number);
                let expected_exclusions = parse_u64_list(fields.next(), line_number);
                let expected_sealed = parse_u64_list(fields.next(), line_number);
                assert_eq!(state.context, expected_context, "contexto en {case_name}");
                assert_eq!(event_ids(&state), expected_events, "journal en {case_name}");
                let (counted, payable) = economic_projections(&state, &controller, window_id)
                    .expect("ventana STATE válida");
                assert_eq!(counted, expected_counted, "conteo en {case_name}");
                assert_eq!(payable, expected_payable, "pagables en {case_name}");
                assert_eq!(
                    state.causal_exclusions, expected_exclusions,
                    "exclusiones en {case_name}"
                );
                assert_eq!(
                    state.sealed_windows.keys().copied().collect::<Vec<_>>(),
                    expected_sealed,
                    "sellos en {case_name}"
                );
            }
            "END" => {
                assert_journal_invariants(&state, &controller);
            }
            other => panic!("directiva {other} desconocida en línea {line_number}"),
        }
        assert!(
            fields.next().is_none(),
            "campos sobrantes en línea {line_number}"
        );
    }
}
