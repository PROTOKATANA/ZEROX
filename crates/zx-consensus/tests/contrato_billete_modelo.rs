//! Modelo estructural CBE-v0.1 EXCLUSIVO DE TESTS, no consenso de producción.
//!
//! Identidad, rango de orden, color y validación son entradas del contrato. Aquí NO
//! se verifican PoAS, PoT, firmas, GHOSTDAG, UTXO reales ni pruebas Orchard.
//! Referencia documental: veritas/consenso/contrato-billete-v1/CONTRATO.md.
//! BTreeMap/BTreeSet y snapshots completos favorecen claridad y reproducibilidad;
//! no representan una propuesta de almacenamiento ni un benchmark de rendimiento.

use std::collections::{BTreeMap, BTreeSet};

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum Color {
    Blue,
    RedK,
    RedU3,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum Body {
    Valid,
    Pending,
    Invalid,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum Policy {
    First,
    Blue,
}

#[derive(Clone, Debug, PartialEq, Eq, PartialOrd, Ord)]
enum Spend {
    Transparent(String),
    Shielded(String),
}

#[derive(Clone, Debug, PartialEq, Eq)]
struct Tx {
    id: String,
    spend: Spend,
    fee: u64,
}

#[derive(Clone, Debug, PartialEq, Eq)]
struct Block {
    id: String,
    ticket: String,
    slot: u64,
    rank: u64,
    color: Color,
    body: Body,
    subsidy: u64,
    txs: Vec<Tx>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
struct Batch {
    id: String,
    parent: String,
    slot: u64,
    window: u64,
    blocks: Vec<Block>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
struct Event {
    ticket: String,
    representative: String,
    context: String,
    slot: u64,
    incorporated_slot: u64,
    subsidy: u64,
    fees: u64,
}

#[derive(Clone, Debug, PartialEq, Eq)]
struct State {
    context: String,
    slot: u64,
    ledger: BTreeMap<String, Event>,
    spent: BTreeSet<Spend>,
    accepted: Vec<String>,
    events: Vec<Event>,
    subsidy: u64,
    fees: u64,
    count: u64,
    seen_blocks: BTreeSet<String>,
    active_contexts: BTreeSet<String>,
}

impl Default for State {
    fn default() -> Self {
        Self {
            context: "0".into(),
            slot: 0,
            ledger: BTreeMap::new(),
            spent: BTreeSet::new(),
            accepted: Vec::new(),
            events: Vec::new(),
            subsidy: 0,
            fees: 0,
            count: 0,
            seen_blocks: BTreeSet::new(),
            active_contexts: BTreeSet::from(["0".into()]),
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum Rejected {
    Pending,
    Invalid,
}

#[derive(Clone, Debug, PartialEq, Eq)]
struct Undo {
    before: State,
    after: State,
}

fn checked_add(left: u64, right: u64) -> Result<u64, Rejected> {
    left.checked_add(right).ok_or(Rejected::Invalid)
}

fn positive_id(id: &str) -> bool {
    id.parse::<u64>()
        .is_ok_and(|number| number > 0 && number.to_string() == id)
}

// Los snapshots hacen explícito que ningún fallo publica un prefijo parcial.
fn apply(state: &mut State, batch: &Batch, policy: Policy) -> Result<Undo, Rejected> {
    if batch.parent != state.context
        || !positive_id(&batch.id)
        || state.active_contexts.contains(&batch.id)
        || batch.slot < state.slot
    {
        return Err(Rejected::Invalid);
    }
    let mut ids = BTreeSet::new();
    let mut ranks = BTreeSet::new();
    let mut ticket_slots = BTreeMap::new();
    let mut transactions = BTreeMap::new();
    for block in &batch.blocks {
        if !positive_id(&block.id)
            || !positive_id(&block.ticket)
            || !ids.insert(&block.id)
            || state.seen_blocks.contains(&block.id)
            || !ranks.insert(block.rank)
            || block.slot > batch.slot
            || block.body == Body::Invalid
        {
            return Err(Rejected::Invalid);
        }
        if ticket_slots
            .insert(&block.ticket, block.slot)
            .is_some_and(|slot| slot != block.slot)
            || state
                .ledger
                .get(&block.ticket)
                .is_some_and(|event| event.slot != block.slot)
        {
            return Err(Rejected::Invalid);
        }
        for tx in &block.txs {
            let (Spend::Transparent(key) | Spend::Shielded(key)) = &tx.spend;
            if !positive_id(&tx.id)
                || !positive_id(key)
                || transactions
                    .insert(&tx.id, tx)
                    .is_some_and(|previous| previous != tx)
            {
                return Err(Rejected::Invalid);
            }
        }
    }
    // Incluye cuerpos de perdedores, tardíos y rojo_U3: no se salta información.
    if batch.blocks.iter().any(|block| block.body == Body::Pending) {
        return Err(Rejected::Pending);
    }

    let minimum_slot = batch.slot.saturating_sub(batch.window);
    let mut ordered: Vec<_> = batch.blocks.iter().collect();
    ordered.sort_by_key(|block| block.rank);
    let mut winners: BTreeMap<&str, &Block> = BTreeMap::new();
    for block in &ordered {
        if block.color == Color::RedU3
            || block.slot < minimum_slot
            || state.ledger.contains_key(&block.ticket)
        {
            continue;
        }
        match winners.get(block.ticket.as_str()) {
            None => {
                winners.insert(&block.ticket, block);
            }
            Some(previous)
                if policy == Policy::Blue
                    && previous.color == Color::RedK
                    && block.color == Color::Blue =>
            {
                winners.insert(&block.ticket, block);
            }
            Some(_) => {}
        }
    }

    let mut next = state.clone();
    for block in ordered {
        if winners.get(block.ticket.as_str()).map(|winner| &winner.id) != Some(&block.id) {
            continue;
        }
        let mut event = Event {
            ticket: block.ticket.clone(),
            representative: block.id.clone(),
            context: batch.id.clone(),
            slot: block.slot,
            incorporated_slot: batch.slot,
            subsidy: block.subsidy,
            fees: 0,
        };
        next.count = checked_add(next.count, 1)?;
        next.subsidy = checked_add(next.subsidy, block.subsidy)?;
        // El ganador conserva su rank; la preferencia azul no mueve su cuerpo.
        for tx in &block.txs {
            if next.spent.insert(tx.spend.clone()) {
                next.fees = checked_add(next.fees, tx.fee)?;
                event.fees = checked_add(event.fees, tx.fee)?;
                next.accepted.push(tx.id.clone());
            }
        }
        next.ledger.insert(block.ticket.clone(), event.clone());
        next.events.push(event);
    }
    next.context.clone_from(&batch.id);
    next.slot = batch.slot;
    next.seen_blocks
        .extend(batch.blocks.iter().map(|block| block.id.clone()));
    next.active_contexts.insert(batch.id.clone());
    let undo = Undo {
        before: state.clone(),
        after: next.clone(),
    };
    *state = next;
    Ok(undo)
}

fn undo(state: &mut State, record: &Undo) -> Result<(), Rejected> {
    // No basta que coincida una etiqueta: no se pisa un estado alterado.
    if *state != record.after {
        return Err(Rejected::Invalid);
    }
    *state = record.before.clone();
    Ok(())
}

fn switch_branch(
    state: &mut State,
    rollback_newest_first: &[Undo],
    replacement: &[Batch],
    policy: Policy,
) -> Result<Vec<Undo>, Rejected> {
    let mut candidate = state.clone();
    for record in rollback_newest_first {
        undo(&mut candidate, record)?;
    }
    let mut records = Vec::new();
    for batch in replacement {
        records.push(apply(&mut candidate, batch, policy)?);
    }
    *state = candidate;
    Ok(records)
}

fn block(id: &str, ticket: &str, rank: u64, color: Color) -> Block {
    Block {
        id: id.into(),
        ticket: ticket.into(),
        slot: 10,
        rank,
        color,
        body: Body::Valid,
        subsidy: 5,
        txs: Vec::new(),
    }
}

fn batch(id: &str, parent: &str, blocks: Vec<Block>) -> Batch {
    Batch {
        id: id.into(),
        parent: parent.into(),
        slot: 10,
        window: 10,
        blocks,
    }
}

fn tx(id: &str, key: &str, fee: u64, shielded: bool) -> Tx {
    Tx {
        id: id.into(),
        spend: if shielded {
            Spend::Shielded(key.into())
        } else {
            Spend::Transparent(key.into())
        },
        fee,
    }
}

#[test]
fn roja_antes_azul_despues_no_sustituye_el_representante() -> Result<(), Rejected> {
    for policy in [Policy::First, Policy::Blue] {
        let mut state = State::default();
        apply(
            &mut state,
            &batch("1", "0", vec![block("11", "21", 0, Color::RedK)]),
            policy,
        )?;
        apply(
            &mut state,
            &batch("2", "1", vec![block("12", "21", 0, Color::Blue)]),
            policy,
        )?;
        assert_eq!(
            state
                .ledger
                .get("21")
                .map(|event| event.representative.as_str()),
            Some("11")
        );
        assert_eq!((state.count, state.subsidy, state.events.len()), (1, 5, 1));
    }
    Ok(())
}

#[test]
fn prioridad_azul_no_adelanta_la_ejecucion_del_ganador() -> Result<(), Rejected> {
    let mut red = block("11", "21", 0, Color::RedK);
    red.txs.push(tx("31", "41", 1, false));
    let mut middle = block("12", "22", 1, Color::Blue);
    middle.txs.push(tx("32", "41", 2, false));
    let mut blue = block("13", "21", 2, Color::Blue);
    blue.txs.push(tx("33", "41", 4, false));
    let input = batch("1", "0", vec![blue, red, middle]);
    let mut first = State::default();
    let mut preferred = State::default();
    apply(&mut first, &input, Policy::First)?;
    apply(&mut preferred, &input, Policy::Blue)?;
    assert_eq!(first.accepted, ["31"]);
    assert_eq!(preferred.accepted, ["32"]);
    assert_eq!((first.fees, preferred.fees), (1, 2));
    assert_eq!(
        preferred
            .ledger
            .get("21")
            .map(|event| event.representative.as_str()),
        Some("13")
    );
    Ok(())
}

#[test]
fn dominios_de_gasto_separados_y_ticket_vacio_consumido() -> Result<(), Rejected> {
    let mut one = block("11", "21", 0, Color::Blue);
    one.subsidy = 0;
    one.txs = vec![
        tx("31", "41", 2, false),
        tx("32", "41", 3, true),
        tx("33", "41", 100, false),
    ];
    let mut state = State::default();
    apply(&mut state, &batch("1", "0", vec![one]), Policy::First)?;
    assert_eq!(state.accepted, ["31", "32"]);
    assert_eq!((state.count, state.subsidy, state.fees), (1, 0, 5));
    apply(
        &mut state,
        &batch("2", "1", vec![block("12", "21", 0, Color::Blue)]),
        Policy::First,
    )?;
    assert_eq!((state.count, state.subsidy), (1, 0));
    Ok(())
}

#[test]
fn pendiente_o_invalido_no_publica_ni_siquiera_perdedores() {
    for color in [Color::Blue, Color::RedK, Color::RedU3] {
        for status in [Body::Pending, Body::Invalid] {
            let mut loser = block("12", "22", 1, color);
            loser.body = status;
            loser.slot = 0;
            let mut input = batch("1", "0", vec![block("11", "21", 0, Color::Blue), loser]);
            input.window = 0;
            let mut state = State::default();
            let before = state.clone();
            let expected = if status == Body::Pending {
                Rejected::Pending
            } else {
                Rejected::Invalid
            };
            assert_eq!(apply(&mut state, &input, Policy::First), Err(expected));
            assert_eq!(state, before);
        }
    }
}

#[test]
fn ventana_inclusiva_y_late_l0_no_consumen() -> Result<(), Rejected> {
    let mut early = block("11", "21", 0, Color::Blue);
    early.slot = 4;
    let mut edge = block("12", "22", 1, Color::RedK);
    edge.slot = 5;
    let mut input = batch(
        "1",
        "0",
        vec![early, edge, block("13", "23", 2, Color::Blue)],
    );
    input.window = 5;
    let mut state = State::default();
    apply(&mut state, &input, Policy::First)?;
    assert!(!state.ledger.contains_key("21"));
    assert_eq!(state.count, 2);
    Ok(())
}

#[test]
fn desbordamientos_y_undo_erroneo_son_atomicos() -> Result<(), Rejected> {
    let mut first = block("11", "21", 0, Color::Blue);
    first.subsidy = u64::MAX;
    let input = batch("1", "0", vec![first, block("12", "22", 1, Color::Blue)]);
    let mut state = State::default();
    assert_eq!(
        apply(&mut state, &input, Policy::First),
        Err(Rejected::Invalid)
    );
    assert_eq!(state, State::default());
    let record = apply(
        &mut state,
        &batch("1", "0", vec![block("11", "21", 0, Color::Blue)]),
        Policy::First,
    )?;
    let mut altered = state.clone();
    altered.fees = 1;
    let unchanged = altered.clone();
    assert_eq!(undo(&mut altered, &record), Err(Rejected::Invalid));
    assert_eq!(altered, unchanged);
    undo(&mut state, &record)?;
    assert_eq!(state, State::default());
    Ok(())
}

#[test]
fn cambio_de_rama_fallido_restaura_toda_la_rama_anterior() -> Result<(), Rejected> {
    let mut state = State::default();
    let old = apply(
        &mut state,
        &batch("1", "0", vec![block("11", "21", 0, Color::Blue)]),
        Policy::First,
    )?;
    let snapshot = state.clone();
    for status in [Body::Pending, Body::Invalid] {
        let first = batch("2", "0", vec![block("12", "21", 0, Color::RedK)]);
        let mut second = batch("3", "2", vec![block("13", "22", 0, Color::Blue)]);
        if let Some(candidate) = second.blocks.first_mut() {
            candidate.body = status;
        }
        assert!(
            switch_branch(
                &mut state,
                std::slice::from_ref(&old),
                &[first, second],
                Policy::First
            )
            .is_err()
        );
        assert_eq!(state, snapshot);
    }
    let replacement = batch("2", "0", vec![block("12", "21", 0, Color::RedK)]);
    let records = switch_branch(&mut state, &[old], &[replacement], Policy::First)?;
    assert_eq!(
        state
            .ledger
            .get("21")
            .map(|event| event.representative.as_str()),
        Some("12")
    );
    assert_eq!(records.len(), 1);
    Ok(())
}

#[test]
fn todos_los_conflictos_o_cuerpo_vacio_consumen_sin_reintento() -> Result<(), Rejected> {
    let mut state = State::default();
    state.spent.insert(Spend::Transparent("41".into()));
    let mut conflicts = block("11", "21", 0, Color::Blue);
    conflicts.subsidy = 0;
    conflicts.txs.push(tx("31", "41", u64::MAX, false));
    let mut empty = block("12", "22", 1, Color::RedK);
    empty.subsidy = 0;
    apply(
        &mut state,
        &batch("1", "0", vec![conflicts, empty]),
        Policy::First,
    )?;
    assert!(state.accepted.is_empty());
    assert_eq!((state.count, state.subsidy, state.fees), (2, 0, 0));
    apply(
        &mut state,
        &batch(
            "2",
            "1",
            vec![
                block("13", "21", 0, Color::Blue),
                block("14", "22", 1, Color::Blue),
            ],
        ),
        Policy::First,
    )?;
    assert_eq!((state.count, state.subsidy), (2, 0));
    Ok(())
}

#[test]
fn overflow_de_fee_y_contador_no_publica_prefijos() {
    let mut fees = block("11", "21", 0, Color::Blue);
    fees.txs = vec![tx("31", "41", u64::MAX, false), tx("32", "42", 1, false)];
    let mut state = State::default();
    assert_eq!(
        apply(&mut state, &batch("1", "0", vec![fees]), Policy::First),
        Err(Rejected::Invalid)
    );
    assert_eq!(state, State::default());

    // Inyección de borde aritmético; no simula un historial de u64::MAX eventos.
    state.count = u64::MAX;
    let before = state.clone();
    assert_eq!(
        apply(
            &mut state,
            &batch("1", "0", vec![block("11", "21", 0, Color::Blue)]),
            Policy::First
        ),
        Err(Rejected::Invalid)
    );
    assert_eq!(state, before);
}

#[test]
fn prioridad_de_errores_es_independiente_de_llegada() {
    let mut pending = block("11", "21", 0, Color::Blue);
    pending.body = Body::Pending;
    let mut invalid = block("12", "22", 1, Color::RedU3);
    invalid.body = Body::Invalid;
    for blocks in [
        vec![pending.clone(), invalid.clone()],
        vec![invalid, pending.clone()],
    ] {
        let mut state = State::default();
        assert_eq!(
            apply(&mut state, &batch("1", "0", blocks), Policy::First),
            Err(Rejected::Invalid)
        );
        assert_eq!(state, State::default());
    }
    let mut maximum = block("12", "22", 1, Color::Blue);
    maximum.subsidy = u64::MAX;
    let mut state = State::default();
    assert_eq!(
        apply(
            &mut state,
            &batch(
                "1",
                "0",
                vec![pending, maximum, block("13", "23", 2, Color::Blue)]
            ),
            Policy::First
        ),
        Err(Rejected::Pending)
    );
    assert_eq!(state, State::default());
}

#[test]
fn preflight_rechaza_metadatos_inconsistentes_sin_mutacion() {
    let original = batch(
        "1",
        "0",
        vec![
            block("11", "21", 0, Color::Blue),
            block("12", "22", 1, Color::RedK),
        ],
    );
    let mut inputs = Vec::new();
    let mut wrong_parent = original.clone();
    wrong_parent.parent = "99".into();
    inputs.push(wrong_parent);
    let mut zero_context = original.clone();
    zero_context.id = "0".into();
    inputs.push(zero_context);
    for mutation in 0..5 {
        let mut input = original.clone();
        if let Some(second) = input.blocks.get_mut(1) {
            match mutation {
                0 => second.id = "11".into(),
                1 => second.rank = 0,
                2 => second.slot = 11,
                3 => second.ticket = "0".into(),
                _ => {
                    second.ticket = "21".into();
                    second.slot = 9;
                }
            }
        }
        inputs.push(input);
    }
    for input in inputs {
        let mut state = State::default();
        assert_eq!(
            apply(&mut state, &input, Policy::First),
            Err(Rejected::Invalid)
        );
        assert_eq!(state, State::default());
    }
}

#[test]
fn undo_restaura_seen_inertes_y_contextos() -> Result<(), Rejected> {
    let mut state = State::default();
    let original = state.clone();
    let record = apply(
        &mut state,
        &batch("1", "0", vec![block("11", "21", 0, Color::RedU3)]),
        Policy::First,
    )?;
    assert!(state.seen_blocks.contains("11"));
    assert_eq!(state.count, 0);
    let unchanged = state.clone();
    assert_eq!(
        apply(
            &mut state,
            &batch("2", "1", vec![block("11", "21", 0, Color::Blue)]),
            Policy::First
        ),
        Err(Rejected::Invalid)
    );
    assert_eq!(state, unchanged);
    undo(&mut state, &record)?;
    assert_eq!(state, original);
    apply(
        &mut state,
        &batch("1", "0", vec![block("11", "21", 0, Color::Blue)]),
        Policy::First,
    )?;
    assert_eq!(state.count, 1);
    Ok(())
}

fn list_or_dash(items: impl IntoIterator<Item = String>) -> String {
    let values: Vec<_> = items.into_iter().collect();
    if values.is_empty() {
        "-".into()
    } else {
        values.join(",")
    }
}

fn numeric_order(left: &str, right: &str) -> std::cmp::Ordering {
    // Sólo IDs decimales canónicos: longitud y orden lexical equivalen al numérico.
    left.len().cmp(&right.len()).then_with(|| left.cmp(right))
}

fn snapshot(state: &State, status: &str) -> String {
    let mut ledger: Vec<_> = state.ledger.values().collect();
    ledger.sort_by(|left, right| numeric_order(&left.ticket, &right.ticket));
    let ledger = list_or_dash(ledger.into_iter().map(|event| {
        format!(
            "{}:{}:{}:{}",
            event.ticket, event.representative, event.context, event.slot
        )
    }));
    let mut spent: Vec<_> = state
        .spent
        .iter()
        .map(|spend| match spend {
            Spend::Transparent(key) => (0, "T", key),
            Spend::Shielded(key) => (1, "S", key),
        })
        .collect();
    spent.sort_by(|left, right| {
        left.0
            .cmp(&right.0)
            .then_with(|| numeric_order(left.2, right.2))
    });
    let spent = list_or_dash(
        spent
            .into_iter()
            .map(|(_, domain, key)| format!("{domain}:{key}")),
    );
    let mut seen: Vec<_> = state.seen_blocks.iter().cloned().collect();
    seen.sort_by(|left, right| numeric_order(left, right));
    format!(
        "{status} {} {} {} {} {} {ledger} {} {spent} {}",
        state.context,
        state.slot,
        state.count,
        state.subsidy,
        state.fees,
        list_or_dash(state.accepted.iter().cloned()),
        list_or_dash(seen)
    )
}

fn number(text: &str) -> Result<u64, String> {
    text.parse()
        .map_err(|error| format!("entero u64 inválido {text}: {error}"))
}

fn run_fixtures(source: &str) -> Result<usize, String> {
    let mut state = State::default();
    let mut history = Vec::new();
    let mut prepared: Option<Batch> = None;
    let mut policy = Policy::First;
    let mut case: Option<&str> = None;
    let mut status = "Invalid";
    let mut checks = 0;
    for (line_number, line) in source.lines().enumerate() {
        let data = line.split('#').next().unwrap_or_default().trim();
        let fields: Vec<_> = data.split_whitespace().collect();
        match fields.as_slice() {
            [] => {}
            ["CASE", name, choice] if case.is_none() => {
                policy = match *choice {
                    "first" => Policy::First,
                    "blue" => Policy::Blue,
                    _ => return Err(format!("política desconocida {choice}")),
                };
                case = Some(name);
                state = State::default();
                history.clear();
                prepared = None;
                status = "Invalid";
            }
            ["BATCH", id, parent, slot, window] if case.is_some() => {
                prepared = Some(Batch {
                    id: number(id)?.to_string(),
                    parent: number(parent)?.to_string(),
                    slot: number(slot)?,
                    window: number(window)?,
                    blocks: Vec::new(),
                });
            }
            ["BLOCK", id, ticket, slot, rank, color, body, subsidy] if case.is_some() => {
                let input = prepared.as_mut().ok_or("BLOCK sin BATCH")?;
                input.blocks.push(Block {
                    id: number(id)?.to_string(),
                    ticket: number(ticket)?.to_string(),
                    slot: number(slot)?,
                    rank: number(rank)?,
                    subsidy: number(subsidy)?,
                    color: match *color {
                        "B" => Color::Blue,
                        "R" => Color::RedK,
                        "U" => Color::RedU3,
                        _ => return Err(format!("color inválido {color}")),
                    },
                    body: match *body {
                        "V" => Body::Valid,
                        "P" => Body::Pending,
                        "I" => Body::Invalid,
                        _ => return Err(format!("estado de cuerpo inválido {body}")),
                    },
                    txs: Vec::new(),
                });
            }
            ["TX", id, domain, key, fee] if case.is_some() => {
                let input = prepared.as_mut().ok_or("TX sin BATCH")?;
                let current = input.blocks.last_mut().ok_or("TX sin BLOCK")?;
                let key = number(key)?.to_string();
                current.txs.push(Tx {
                    id: number(id)?.to_string(),
                    fee: number(fee)?,
                    spend: match *domain {
                        "T" => Spend::Transparent(key),
                        "S" => Spend::Shielded(key),
                        _ => return Err(format!("dominio inválido {domain}")),
                    },
                });
            }
            ["APPLY"] if case.is_some() => {
                let input = prepared.as_ref().ok_or("APPLY sin BATCH")?;
                let before = state.clone();
                status = match apply(&mut state, input, policy) {
                    Ok(record) => {
                        history.push(record);
                        "Applied"
                    }
                    Err(Rejected::Pending) => {
                        assert_eq!(state, before);
                        "Pending"
                    }
                    Err(Rejected::Invalid) => {
                        assert_eq!(state, before);
                        "Invalid"
                    }
                };
            }
            ["UNDO"] if case.is_some() => {
                let before = state.clone();
                status = if let Some(record) = history.last() {
                    if undo(&mut state, record).is_ok() {
                        history.pop();
                        "Reverted"
                    } else {
                        assert_eq!(state, before);
                        "Invalid"
                    }
                } else {
                    "Invalid"
                };
            }
            ["EXPECT", expected @ ..] if case.is_some() && expected.len() == 10 => {
                let expected = expected.join(" ");
                let actual = snapshot(&state, status);
                if actual != expected {
                    return Err(format!(
                        "caso {case:?}, línea {}:\nesperado: {expected}\nobtenido: {actual}",
                        line_number + 1
                    ));
                }
                checks += 1;
            }
            ["END"] if case.is_some() => {
                case = None;
                prepared = None;
            }
            _ => {
                return Err(format!(
                    "sintaxis inválida en línea {}: {line}",
                    line_number + 1
                ));
            }
        }
    }
    if case.is_some() {
        return Err("falta END al final del fixture".into());
    }
    Ok(checks)
}

#[test]
fn vectores_compartidos_cbe_v01() -> Result<(), String> {
    let source = include_str!("../../../veritas/consenso/contrato-billete-v1/fixtures/CASOS.txt");
    let checks = run_fixtures(source)?;
    assert!(checks > 0, "el archivo debe contener EXPECT ejecutados");
    eprintln!("CBE-v0.1 Rust: {checks} EXPECT completos comprobados");
    Ok(())
}

#[test]
fn permutar_la_entrada_no_cambia_el_orden_ni_estado() -> Result<(), Rejected> {
    let a = block("11", "21", 0, Color::RedK);
    let mut b = block("12", "21", 1, Color::Blue);
    b.txs.push(tx("31", "41", 2, false));
    let mut c = block("13", "22", 2, Color::Blue);
    c.txs.push(tx("32", "41", 3, false));
    for policy in [Policy::First, Policy::Blue] {
        let permutations = [
            vec![a.clone(), b.clone(), c.clone()],
            vec![a.clone(), c.clone(), b.clone()],
            vec![b.clone(), a.clone(), c.clone()],
            vec![b.clone(), c.clone(), a.clone()],
            vec![c.clone(), a.clone(), b.clone()],
            vec![c.clone(), b.clone(), a.clone()],
        ];
        let mut reference = State::default();
        apply(
            &mut reference,
            &batch("1", "0", vec![a.clone(), b.clone(), c.clone()]),
            policy,
        )?;
        for input in permutations {
            let mut state = State::default();
            let record = apply(&mut state, &batch("1", "0", input), policy)?;
            assert_eq!(state, reference);
            undo(&mut state, &record)?;
            assert_eq!(state, State::default());
        }
    }
    Ok(())
}
