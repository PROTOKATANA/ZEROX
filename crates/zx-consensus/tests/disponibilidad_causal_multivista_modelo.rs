//! Modelo estructural DCM-v0.1, exclusivo de tests.
//!
//! No deriva GHOSTDAG ni valida cuerpos reales. `COMPLETE`, `VALID` e `INVALID` son entradas
//! del fixture. Los identificadores permanecen en `u64`, sin convertirlos a índices de host, y
//! no hay aritmética de consenso que pueda saturar. Cada undo guarda un delta, no un snapshot por
//! profundidad; replay usa una única copia privada y sólo la publica si termina por completo.

#![expect(
    clippy::expect_used,
    clippy::indexing_slicing,
    clippy::panic,
    reason = "el arnes falla ante fixtures mal formados y usa tokens de aridad comprobada"
)]

use std::collections::{BTreeMap, BTreeSet};

const FIXTURES: &str = include_str!(
    "../../../veritas/consenso/disponibilidad-causal-multivista-v1/fixtures/CASOS.txt"
);

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, PartialOrd, Ord)]
struct HistoryId(u64);

#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord)]
struct WindowId(u64);

#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord)]
struct BlockId(u64);

#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord)]
struct TicketId(u64);

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum Policy {
    P0,
    P1,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum Color {
    Blue,
    RedK,
    RedU,
}

#[derive(Clone, Debug, PartialEq, Eq)]
struct BlockSpec {
    id: BlockId,
    ticket: TicketId,
    origin_window: WindowId,
    rank: u64,
    color: Color,
    parents: Vec<BlockId>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
struct HistorySpec {
    id: HistoryId,
    parent: HistoryId,
    window: WindowId,
    blocks: Vec<BlockId>,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord)]
struct EventId {
    history: HistoryId,
    block: BlockId,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord)]
struct InertKey {
    history: HistoryId,
    window: WindowId,
    block: BlockId,
}

#[derive(Clone, Debug)]
struct Catalog {
    blocks: BTreeMap<BlockId, BlockSpec>,
    histories: BTreeMap<HistoryId, HistorySpec>,
    body_truth: BTreeMap<BlockId, bool>,
    context_truth: BTreeMap<(HistoryId, BlockId), bool>,
}

impl Catalog {
    fn build(
        blocks: &[BlockSpec],
        histories: &[HistorySpec],
        body_truth: &BTreeMap<BlockId, bool>,
        context_truth: &BTreeMap<(HistoryId, BlockId), bool>,
    ) -> Option<Self> {
        let mut block_map = BTreeMap::new();
        let mut ticket_windows = BTreeMap::new();
        for block in blocks {
            if block.id.0 == 0 || block.ticket.0 == 0 {
                return None;
            }
            if block_map.insert(block.id, block.clone()).is_some() {
                return None;
            }
            match ticket_windows.insert(block.ticket, block.origin_window) {
                Some(prior) if prior != block.origin_window => return None,
                _ => {}
            }
        }
        let mut history_map = BTreeMap::new();
        for history in histories {
            if history.id.0 == 0 || history_map.insert(history.id, history.clone()).is_some() {
                return None;
            }
        }
        if body_truth.keys().copied().collect::<BTreeSet<_>>()
            != block_map.keys().copied().collect::<BTreeSet<_>>()
            || context_truth.keys().any(|(history, block)| {
                !history_map.contains_key(history) || !block_map.contains_key(block)
            })
        {
            return None;
        }
        Some(Self {
            blocks: block_map,
            histories: history_map,
            body_truth: body_truth.clone(),
            context_truth: context_truth.clone(),
        })
    }

    fn history_chain(&self, target: HistoryId) -> Option<Vec<HistoryId>> {
        let mut chain = Vec::new();
        let mut seen = BTreeSet::new();
        let mut cursor = target;
        while cursor != HistoryId::default() {
            if !seen.insert(cursor) {
                return None;
            }
            let history = self.histories.get(&cursor)?;
            chain.push(cursor);
            cursor = history.parent;
        }
        chain.reverse();
        Some(chain)
    }

    fn history_structure_valid(&self, target: HistoryId) -> bool {
        let Some(chain) = self.history_chain(target) else {
            return false;
        };
        let mut past_blocks = BTreeSet::new();
        let mut past_windows = BTreeSet::new();
        for history_id in chain {
            let Some(history) = self.histories.get(&history_id) else {
                return false;
            };
            let current = history.blocks.iter().copied().collect::<BTreeSet<_>>();
            if current.len() != history.blocks.len() || past_windows.contains(&history.window) {
                return false;
            }
            for block_id in &history.blocks {
                let Some(block) = self.blocks.get(block_id) else {
                    return false;
                };
                if past_blocks.contains(block_id)
                    || (block.origin_window != history.window
                        && !past_windows.contains(&block.origin_window))
                {
                    return false;
                }
                if block
                    .parents
                    .iter()
                    .any(|parent| !past_blocks.contains(parent) && !current.contains(parent))
                {
                    return false;
                }
            }
            past_blocks.extend(current);
            past_windows.insert(history.window);
        }

        // Kahn visita cada bloque/arista sin recursión ni un límite inventado de profundidad.
        // Los mapas ordenados añaden log(B) al coste O(B+E) del recorrido.
        let mut remaining = BTreeMap::new();
        let mut children = BTreeMap::<BlockId, Vec<BlockId>>::new();
        let mut ready = Vec::new();
        for id in &past_blocks {
            let parents = &self.blocks[id].parents;
            remaining.insert(*id, parents.len());
            if parents.is_empty() {
                ready.push(*id);
            }
            for parent in parents {
                children.entry(*parent).or_default().push(*id);
            }
        }
        let mut visited = 0_usize;
        while let Some(parent) = ready.pop() {
            visited = visited
                .checked_add(1)
                .expect("bloques visitados representables");
            if let Some(dependents) = children.get(&parent) {
                for child in dependents {
                    let count = remaining.get_mut(child).expect("hijo catalogado");
                    *count = count
                        .checked_sub(1)
                        .expect("arista pendiente contabilizada");
                    if *count == 0 {
                        ready.push(*child);
                    }
                }
            }
        }
        visited == past_blocks.len()
    }

    fn winners(
        &self,
        history: &HistorySpec,
        policy: Policy,
        consumed: &BTreeSet<TicketId>,
    ) -> Vec<BlockSpec> {
        let mut chosen = BTreeMap::<TicketId, BlockSpec>::new();
        for id in &history.blocks {
            let block = &self.blocks[id];
            if consumed.contains(&block.ticket)
                || block.origin_window != history.window
                || block.color == Color::RedU
            {
                continue;
            }
            let replace = chosen
                .get(&block.ticket)
                .is_none_or(|old| selection_key(block, policy) < selection_key(old, policy));
            if replace {
                chosen.insert(block.ticket, block.clone());
            }
        }
        let mut winners = chosen.into_values().collect::<Vec<_>>();
        winners.sort_by_key(|block| (block.rank, block.id));
        winners
    }

    fn required_bodies(&self, winners: &[BlockSpec]) -> BTreeSet<BlockId> {
        let mut required = BTreeSet::new();
        let mut stack = winners.iter().map(|block| block.id).collect::<Vec<_>>();
        while let Some(id) = stack.pop() {
            if required.insert(id) {
                stack.extend(self.blocks[&id].parents.iter().copied());
            }
        }
        required
    }
}

fn selection_key(block: &BlockSpec, policy: Policy) -> (u8, u64, BlockId) {
    let color_priority = match policy {
        Policy::P0 => 0,
        Policy::P1 if block.color == Color::Blue => 0,
        Policy::P1 => 1,
    };
    (color_priority, block.rank, block.id)
}

#[derive(Clone, Debug, Default, PartialEq, Eq)]
struct PublicState {
    current: HistoryId,
    journal: Vec<EventId>,
    counted: BTreeMap<WindowId, Vec<EventId>>,
    payable: BTreeMap<WindowId, Vec<EventId>>,
    inert: BTreeSet<InertKey>,
    applied_blocks: BTreeSet<BlockId>,
    consumed: BTreeSet<TicketId>,
    path: Vec<HistoryId>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
struct UndoDelta {
    applied: HistoryId,
    parent: HistoryId,
    journal_len: usize,
    window: WindowId,
    inert_added: Vec<InertKey>,
    blocks_added: Vec<BlockId>,
    consumed_added: Vec<TicketId>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
struct View {
    policy: Policy,
    headers: BTreeSet<BlockId>,
    complete_bodies: BTreeSet<BlockId>,
    rejected_deliveries: BTreeSet<BlockId>,
    invalid_bodies: BTreeSet<BlockId>,
    context_valid: BTreeSet<(HistoryId, BlockId)>,
    context_invalid: BTreeSet<(HistoryId, BlockId)>,
    public: PublicState,
    undo: Vec<UndoDelta>,
    pending: Option<HistoryId>,
}

impl Default for View {
    fn default() -> Self {
        Self::new(Policy::P0)
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum Outcome {
    Applied,
    Pending,
    Invalid,
    PolicyMismatch,
}

impl View {
    fn new(policy: Policy) -> Self {
        Self {
            policy,
            headers: BTreeSet::new(),
            complete_bodies: BTreeSet::new(),
            rejected_deliveries: BTreeSet::new(),
            invalid_bodies: BTreeSet::new(),
            context_valid: BTreeSet::new(),
            context_invalid: BTreeSet::new(),
            public: PublicState::default(),
            undo: Vec::new(),
            pending: None,
        }
    }

    fn deliver_body(&mut self, catalog: &Catalog, block: BlockId, state: &str) -> bool {
        let Some(truth) = catalog.body_truth.get(&block).copied() else {
            return false;
        };
        match state {
            "COMPLETE" => {
                if !truth || self.invalid_bodies.contains(&block) {
                    return false;
                }
                self.rejected_deliveries.remove(&block);
                self.complete_bodies.insert(block);
                true
            }
            "REJECT" => {
                if !self.complete_bodies.contains(&block) && !self.invalid_bodies.contains(&block) {
                    self.rejected_deliveries.insert(block);
                }
                true
            }
            "INVALID" => {
                if truth || self.complete_bodies.contains(&block) {
                    return false;
                }
                self.rejected_deliveries.remove(&block);
                self.invalid_bodies.insert(block);
                true
            }
            _ => panic!("estado de cuerpo desconocido: {state}"),
        }
    }

    fn deliver_context(
        &mut self,
        catalog: &Catalog,
        history: HistoryId,
        block: BlockId,
        valid: bool,
    ) -> bool {
        let key = (history, block);
        if catalog.context_truth.get(&key) != Some(&valid) {
            return false;
        }
        if valid {
            if self.context_invalid.contains(&key) {
                return false;
            }
            self.context_valid.insert(key);
            true
        } else {
            if self.context_valid.contains(&key) {
                return false;
            }
            self.context_invalid.insert(key);
            true
        }
    }

    fn apply(&mut self, catalog: &Catalog, target: HistoryId, policy: Policy) -> Outcome {
        if policy != self.policy {
            return Outcome::PolicyMismatch;
        }
        let Some(history) = catalog.histories.get(&target) else {
            self.pending = None;
            return Outcome::Invalid;
        };
        if !catalog.history_structure_valid(target) || history.parent != self.public.current {
            self.pending = None;
            return Outcome::Invalid;
        }
        if history.blocks.iter().any(|id| !self.headers.contains(id)) {
            self.pending = Some(target);
            return Outcome::Pending;
        }

        let winners = catalog.winners(history, policy, &self.public.consumed);
        let required = catalog.required_bodies(&winners);
        if required.iter().any(|id| {
            self.invalid_bodies.contains(id) || self.context_invalid.contains(&(target, *id))
        }) {
            self.pending = None;
            return Outcome::Invalid;
        }
        if required.iter().any(|id| {
            !self.complete_bodies.contains(id) || !self.context_valid.contains(&(target, *id))
        }) {
            self.pending = Some(target);
            return Outcome::Pending;
        }

        let winner_ids = winners
            .iter()
            .map(|block| block.id)
            .collect::<BTreeSet<_>>();
        let events = winners
            .iter()
            .map(|block| EventId {
                history: target,
                block: block.id,
            })
            .collect::<Vec<_>>();
        let inert_added = history
            .blocks
            .iter()
            .filter(|id| !winner_ids.contains(id))
            .map(|id| InertKey {
                history: target,
                window: history.window,
                block: *id,
            })
            .collect::<Vec<_>>();
        let consumed_added = winners.iter().map(|block| block.ticket).collect::<Vec<_>>();
        let delta = UndoDelta {
            applied: target,
            parent: self.public.current,
            journal_len: self.public.journal.len(),
            window: history.window,
            inert_added: inert_added.clone(),
            blocks_added: history.blocks.clone(),
            consumed_added: consumed_added.clone(),
        };

        // Publicación lógica única: ninguna comprobación falible ocurre tras este punto.
        self.public.journal.extend(events.iter().copied());
        self.public.counted.insert(history.window, events.clone());
        self.public.payable.insert(history.window, events);
        self.public.inert.extend(inert_added);
        self.public
            .applied_blocks
            .extend(history.blocks.iter().copied());
        self.public.consumed.extend(consumed_added);
        self.public.current = target;
        self.public.path.push(target);
        self.undo.push(delta);
        self.pending = None;
        Outcome::Applied
    }

    fn undo(&mut self, expected: HistoryId) -> Outcome {
        let Some(delta) = self.undo.last() else {
            self.pending = None;
            return Outcome::Invalid;
        };
        if self.public.current != expected || delta.applied != expected {
            self.pending = None;
            return Outcome::Invalid;
        }
        let delta = self.undo.pop().expect("undo comprobado");
        self.public.journal.truncate(delta.journal_len);
        self.public.counted.remove(&delta.window);
        self.public.payable.remove(&delta.window);
        for key in delta.inert_added {
            self.public.inert.remove(&key);
        }
        for block in delta.blocks_added {
            self.public.applied_blocks.remove(&block);
        }
        for ticket in delta.consumed_added {
            self.public.consumed.remove(&ticket);
        }
        self.public.path.pop();
        self.public.current = delta.parent;
        self.pending = None;
        Outcome::Applied
    }

    fn replay(&mut self, catalog: &Catalog, target: HistoryId, policy: Policy) -> Outcome {
        if policy != self.policy {
            return Outcome::PolicyMismatch;
        }
        let Some(target_chain) = catalog.history_chain(target) else {
            self.pending = None;
            return Outcome::Invalid;
        };
        if !catalog.history_structure_valid(target) {
            self.pending = None;
            return Outcome::Invalid;
        }
        let common = self
            .public
            .path
            .iter()
            .zip(&target_chain)
            .take_while(|(left, right)| left == right)
            .count();
        let mut staged = self.clone();
        while staged.public.path.len() > common {
            let tip = staged.public.current;
            if staged.undo(tip) != Outcome::Applied {
                self.pending = None;
                return Outcome::Invalid;
            }
        }
        for history in target_chain.iter().skip(common) {
            match staged.apply(catalog, *history, policy) {
                Outcome::Applied => {}
                Outcome::Pending => {
                    self.pending = staged.pending;
                    return Outcome::Pending;
                }
                Outcome::Invalid => {
                    self.pending = None;
                    return Outcome::Invalid;
                }
                Outcome::PolicyMismatch => return Outcome::PolicyMismatch,
            }
        }
        self.public = staged.public;
        self.undo = staged.undo;
        self.pending = None;
        Outcome::Applied
    }

    fn assert_projection_invariant(&self) {
        assert_eq!(self.public.counted, self.public.payable);
        let counted = self
            .public
            .counted
            .values()
            .flatten()
            .copied()
            .collect::<BTreeSet<_>>();
        let payable = self
            .public
            .payable
            .values()
            .flatten()
            .copied()
            .collect::<BTreeSet<_>>();
        let journal = self.public.journal.iter().copied().collect::<BTreeSet<_>>();
        assert_eq!(counted, payable);
        assert_eq!(counted, journal);
        assert_eq!(journal.len(), self.public.journal.len());
        let projected_len = self
            .public
            .counted
            .values()
            .map(Vec::len)
            .try_fold(0_usize, usize::checked_add)
            .expect("longitud de proyección representable");
        assert_eq!(projected_len, self.public.journal.len());
        assert_eq!(self.undo.len(), self.public.path.len());
        assert!(
            self.undo
                .iter()
                .zip(&self.public.path)
                .all(|(delta, history)| delta.applied == *history)
        );
    }
}

fn parse_u64(token: &str, line: usize) -> u64 {
    assert!(
        !token.is_empty() && token.bytes().all(|byte| byte.is_ascii_digit()),
        "entero decimal ASCII inválido en línea {line}"
    );
    token
        .parse()
        .unwrap_or_else(|_| panic!("entero inválido en línea {line}"))
}

fn parse_block_list(token: &str, line: usize) -> Vec<BlockId> {
    if token == "-" {
        Vec::new()
    } else {
        token
            .split(',')
            .map(|item| BlockId(parse_u64(item, line)))
            .collect()
    }
}

fn parse_events(token: &str, line: usize) -> Vec<EventId> {
    if token == "-" {
        return Vec::new();
    }
    let events = token
        .split(',')
        .map(|item| {
            let (history, block) = item
                .split_once(':')
                .unwrap_or_else(|| panic!("EventId inválido en línea {line}"));
            EventId {
                history: HistoryId(parse_u64(history, line)),
                block: BlockId(parse_u64(block, line)),
            }
        })
        .collect::<Vec<_>>();
    assert_eq!(
        events.iter().copied().collect::<BTreeSet<_>>().len(),
        events.len(),
        "EventId duplicado en línea {line}"
    );
    events
}

fn parse_snapshots(token: &str, line: usize) -> BTreeMap<WindowId, Vec<EventId>> {
    let mut snapshots = BTreeMap::new();
    if token == "-" {
        return snapshots;
    }
    for item in token.split('/') {
        let (window, events) = item
            .split_once('=')
            .unwrap_or_else(|| panic!("snapshot inválido en línea {line}"));
        assert!(
            snapshots
                .insert(
                    WindowId(parse_u64(window, line)),
                    parse_events(events, line)
                )
                .is_none(),
            "ventana duplicada en línea {line}"
        );
    }
    snapshots
}

fn parse_inert(token: &str, line: usize) -> BTreeSet<InertKey> {
    if token == "-" {
        return BTreeSet::new();
    }
    let entries = token
        .split(',')
        .map(|item| {
            let parts = item.split(':').collect::<Vec<_>>();
            assert_eq!(parts.len(), 3, "InertKey inválida en línea {line}");
            InertKey {
                history: HistoryId(parse_u64(parts[0], line)),
                window: WindowId(parse_u64(parts[1], line)),
                block: BlockId(parse_u64(parts[2], line)),
            }
        })
        .collect::<Vec<_>>();
    let unique = entries.iter().copied().collect::<BTreeSet<_>>();
    assert_eq!(
        unique.len(),
        entries.len(),
        "InertKey duplicada en línea {line}"
    );
    unique
}

fn parse_tickets(token: &str, line: usize) -> BTreeSet<TicketId> {
    if token == "-" {
        BTreeSet::new()
    } else {
        let entries = token
            .split(',')
            .map(|item| TicketId(parse_u64(item, line)))
            .collect::<Vec<_>>();
        let unique = entries.iter().copied().collect::<BTreeSet<_>>();
        assert_eq!(
            unique.len(),
            entries.len(),
            "TicketId duplicado en línea {line}"
        );
        unique
    }
}

fn parse_outcome(token: &str, line: usize) -> Outcome {
    match token {
        "Applied" => Outcome::Applied,
        "Pending" => Outcome::Pending,
        "Invalid" => Outcome::Invalid,
        _ => panic!("resultado inválido en línea {line}"),
    }
}

#[derive(Debug, PartialEq, Eq)]
struct FixtureCounts {
    cases: u64,
    // Una directiva APPLY/REPLAY/UNDO/EXPECT/EQUAL; no cuenta cada assert! interno.
    checked_directives: u64,
}

fn execute_fixture(input: &str) -> FixtureCounts {
    let mut policy = Policy::P0;
    let mut block_specs = Vec::new();
    let mut history_specs = Vec::new();
    let mut body_truth = BTreeMap::new();
    let mut context_truth = BTreeMap::new();
    let mut catalog = None;
    let mut views = BTreeMap::<String, View>::new();
    let mut cases = 0_u64;
    let mut checked_directives = 0_u64;
    let mut in_case = false;
    let mut frozen = false;

    for (index, raw) in input.lines().enumerate() {
        let line_number = index + 1;
        let line = raw.split('#').next().unwrap_or_default().trim();
        if line.is_empty() {
            continue;
        }
        let fields = line.split_whitespace().collect::<Vec<_>>();
        assert!(
            fields[0] == "CASE" || in_case,
            "directiva fuera de CASE en línea {line_number}"
        );
        if matches!(
            fields[0],
            "BLOCK" | "HISTORY" | "BODY_TRUTH" | "CONTEXT_TRUTH"
        ) {
            assert!(
                !frozen,
                "definición tras congelar catálogo en línea {line_number}"
            );
        }
        match fields[0] {
            "CASE" => {
                assert!(!in_case, "CASE anidado en línea {line_number}");
                assert_eq!(fields.len(), 3, "CASE en línea {line_number}");
                policy = match fields[2] {
                    "P0" => Policy::P0,
                    "P1" => Policy::P1,
                    _ => panic!("política inválida en línea {line_number}"),
                };
                block_specs.clear();
                history_specs.clear();
                body_truth.clear();
                context_truth.clear();
                views.clear();
                catalog = None;
                in_case = true;
                frozen = false;
            }
            "BLOCK" => {
                assert_eq!(fields.len(), 7, "BLOCK en línea {line_number}");
                block_specs.push(BlockSpec {
                    id: BlockId(parse_u64(fields[1], line_number)),
                    ticket: TicketId(parse_u64(fields[2], line_number)),
                    origin_window: WindowId(parse_u64(fields[3], line_number)),
                    rank: parse_u64(fields[4], line_number),
                    color: match fields[5] {
                        "B" => Color::Blue,
                        "R" => Color::RedK,
                        "U" => Color::RedU,
                        _ => panic!("color inválido en línea {line_number}"),
                    },
                    parents: parse_block_list(fields[6], line_number),
                });
            }
            "HISTORY" => {
                assert_eq!(fields.len(), 5, "HISTORY en línea {line_number}");
                history_specs.push(HistorySpec {
                    id: HistoryId(parse_u64(fields[1], line_number)),
                    parent: if fields[2] == "-" {
                        HistoryId::default()
                    } else {
                        HistoryId(parse_u64(fields[2], line_number))
                    },
                    window: WindowId(parse_u64(fields[3], line_number)),
                    blocks: parse_block_list(fields[4], line_number),
                });
            }
            "BODY_TRUTH" => {
                assert_eq!(fields.len(), 3, "BODY_TRUTH en línea {line_number}");
                let truth = match fields[2] {
                    "COMPLETE" => true,
                    "INVALID" => false,
                    _ => panic!("verdad de cuerpo inválida en línea {line_number}"),
                };
                assert!(
                    body_truth
                        .insert(BlockId(parse_u64(fields[1], line_number)), truth)
                        .is_none(),
                    "verdad de cuerpo duplicada en línea {line_number}"
                );
            }
            "CONTEXT_TRUTH" => {
                assert_eq!(fields.len(), 4, "CONTEXT_TRUTH en línea {line_number}");
                let truth = match fields[3] {
                    "VALID" => true,
                    "INVALID" => false,
                    _ => panic!("verdad contextual inválida en línea {line_number}"),
                };
                assert!(
                    context_truth
                        .insert(
                            (
                                HistoryId(parse_u64(fields[1], line_number)),
                                BlockId(parse_u64(fields[2], line_number)),
                            ),
                            truth,
                        )
                        .is_none(),
                    "verdad contextual duplicada en línea {line_number}"
                );
            }
            "VIEW" => {
                assert_eq!(fields.len(), 2, "VIEW en línea {line_number}");
                let current_catalog = catalog.get_or_insert_with(|| {
                    Catalog::build(&block_specs, &history_specs, &body_truth, &context_truth)
                        .expect("catálogo o verdad global inválidos")
                });
                assert!(!current_catalog.histories.is_empty());
                assert!(
                    views
                        .insert(fields[1].to_owned(), View::new(policy))
                        .is_none()
                );
                frozen = true;
            }
            "HEADER" => {
                assert_eq!(fields.len(), 3, "HEADER en línea {line_number}");
                let block = BlockId(parse_u64(fields[2], line_number));
                assert!(
                    catalog
                        .as_ref()
                        .expect("catálogo no construido")
                        .blocks
                        .contains_key(&block),
                    "cabecera desconocida en línea {line_number}"
                );
                views
                    .get_mut(fields[1])
                    .expect("vista desconocida")
                    .headers
                    .insert(block);
            }
            "BODY" => {
                assert_eq!(fields.len(), 4, "BODY en línea {line_number}");
                let block = BlockId(parse_u64(fields[2], line_number));
                assert!(
                    catalog
                        .as_ref()
                        .expect("catálogo no construido")
                        .blocks
                        .contains_key(&block),
                    "cuerpo desconocido en línea {line_number}"
                );
                let accepted = views
                    .get_mut(fields[1])
                    .expect("vista desconocida")
                    .deliver_body(
                        catalog.as_ref().expect("catálogo no construido"),
                        block,
                        fields[3],
                    );
                assert!(accepted, "entrega contradictoria en línea {line_number}");
            }
            "CONTEXT" => {
                assert_eq!(fields.len(), 5, "CONTEXT en línea {line_number}");
                let history = HistoryId(parse_u64(fields[2], line_number));
                let block = BlockId(parse_u64(fields[3], line_number));
                let known = catalog.as_ref().expect("catálogo no construido");
                assert!(
                    known.histories.contains_key(&history) && known.blocks.contains_key(&block),
                    "evidencia contextual desconocida en línea {line_number}"
                );
                let valid = match fields[4] {
                    "VALID" => true,
                    "INVALID" => false,
                    _ => panic!("contexto inválido en línea {line_number}"),
                };
                let accepted = views
                    .get_mut(fields[1])
                    .expect("vista desconocida")
                    .deliver_context(known, history, block, valid);
                assert!(accepted, "contexto contradictorio en línea {line_number}");
            }
            "APPLY" | "REPLAY" => {
                assert_eq!(fields.len(), 4, "transición en línea {line_number}");
                let target = HistoryId(parse_u64(fields[2], line_number));
                let expected = parse_outcome(fields[3], line_number);
                let catalog = catalog.as_ref().expect("catálogo no construido");
                let view = views.get_mut(fields[1]).expect("vista desconocida");
                let before = view.public.clone();
                let actual = if fields[0] == "APPLY" {
                    view.apply(catalog, target, policy)
                } else {
                    view.replay(catalog, target, policy)
                };
                assert_eq!(actual, expected, "resultado en línea {line_number}");
                if actual != Outcome::Applied {
                    assert_eq!(
                        view.public, before,
                        "publicación parcial en línea {line_number}"
                    );
                }
                view.assert_projection_invariant();
            }
            "UNDO" => {
                assert_eq!(fields.len(), 4, "UNDO en línea {line_number}");
                let expected = parse_outcome(fields[3], line_number);
                let view = views.get_mut(fields[1]).expect("vista desconocida");
                let before = view.public.clone();
                let actual = view.undo(HistoryId(parse_u64(fields[2], line_number)));
                assert_eq!(actual, expected, "undo en línea {line_number}");
                if actual == Outcome::Invalid {
                    assert_eq!(view.public, before, "undo parcial en línea {line_number}");
                }
                view.assert_projection_invariant();
            }
            "EXPECT" => {
                assert_eq!(fields.len(), 9, "EXPECT en línea {line_number}");
                let view = views.get(fields[1]).expect("vista desconocida");
                let expected_current = if fields[2] == "-" {
                    HistoryId::default()
                } else {
                    HistoryId(parse_u64(fields[2], line_number))
                };
                assert_eq!(
                    view.public.current, expected_current,
                    "current en línea {line_number}"
                );
                assert_eq!(view.public.journal, parse_events(fields[3], line_number));
                assert_eq!(view.public.counted, parse_snapshots(fields[4], line_number));
                assert_eq!(view.public.payable, parse_snapshots(fields[5], line_number));
                assert_eq!(view.public.inert, parse_inert(fields[6], line_number));
                assert_eq!(view.public.consumed, parse_tickets(fields[7], line_number));
                let expected_pending = if fields[8] == "-" {
                    None
                } else {
                    Some(HistoryId(parse_u64(fields[8], line_number)))
                };
                assert_eq!(
                    view.pending, expected_pending,
                    "pending en línea {line_number}"
                );
                view.assert_projection_invariant();
            }
            "EQUAL" => {
                assert_eq!(fields.len(), 3, "EQUAL en línea {line_number}");
                let left = views.get(fields[1]).expect("vista desconocida");
                let right = views.get(fields[2]).expect("vista desconocida");
                assert_eq!(
                    left.policy, right.policy,
                    "políticas distintas en línea {line_number}"
                );
                assert_eq!(
                    left.public, right.public,
                    "vistas distintas en línea {line_number}"
                );
                assert_eq!(
                    left.undo, right.undo,
                    "undo distinto en línea {line_number}"
                );
                assert_eq!(
                    left.pending, right.pending,
                    "Pending distinto en línea {line_number}"
                );
            }
            "END" => {
                assert_eq!(fields.len(), 1, "END en línea {line_number}");
                assert!(catalog.is_some(), "CASE vacío en línea {line_number}");
                cases = cases.checked_add(1).expect("demasiados casos");
                in_case = false;
            }
            directive => panic!("directiva {directive} desconocida en línea {line_number}"),
        }
        if matches!(fields[0], "APPLY" | "REPLAY" | "UNDO" | "EXPECT" | "EQUAL") {
            checked_directives = checked_directives
                .checked_add(1)
                .expect("demasiadas comprobaciones");
        }
    }
    assert!(!in_case, "CASE sin END al terminar el archivo");
    assert!(cases > 0, "fixture sin casos");
    FixtureCounts {
        cases,
        checked_directives,
    }
}

#[test]
fn fixtures_compartidos_con_julia() {
    assert_eq!(
        execute_fixture(FIXTURES),
        FixtureCounts {
            cases: 12,
            checked_directives: 59
        }
    );
}

#[test]
fn evidencias_monotonas_y_contextuales_no_se_reetiquetan() {
    let block = BlockId(u64::MAX);
    let blocks = [BlockSpec {
        id: block,
        ticket: TicketId(1),
        origin_window: WindowId(1),
        rank: 1,
        color: Color::Blue,
        parents: Vec::new(),
    }];
    let histories = [
        HistorySpec {
            id: HistoryId(900),
            parent: HistoryId::default(),
            window: WindowId(1),
            blocks: vec![block],
        },
        HistorySpec {
            id: HistoryId(2),
            parent: HistoryId::default(),
            window: WindowId(1),
            blocks: vec![block],
        },
    ];
    let body_truth = BTreeMap::from([(block, true)]);
    let context_truth = BTreeMap::from([
        ((HistoryId(900), block), true),
        ((HistoryId(2), block), false),
    ]);
    let catalog = Catalog::build(&blocks, &histories, &body_truth, &context_truth)
        .expect("verdad global coherente");
    let mut view = View::default();
    assert!(view.deliver_body(&catalog, block, "COMPLETE"));
    assert!(!view.deliver_body(&catalog, block, "INVALID"));
    assert!(view.deliver_body(&catalog, block, "REJECT"));
    assert!(!view.rejected_deliveries.contains(&block));
    assert!(view.deliver_context(&catalog, HistoryId(900), block, true));
    assert!(!view.deliver_context(&catalog, HistoryId(900), block, false));
    assert!(view.deliver_context(&catalog, HistoryId(2), block, false));
    assert!(view.context_valid.contains(&(HistoryId(900), block)));
    assert!(view.context_invalid.contains(&(HistoryId(2), block)));

    let before_unknown = view.clone();
    assert!(!view.deliver_body(&catalog, BlockId(7), "COMPLETE"));
    assert!(!view.deliver_context(&catalog, HistoryId(8), block, true));
    assert_eq!(view, before_unknown);
}

#[test]
fn replay_pending_es_atomico_y_reintentable() {
    let blocks = [
        BlockSpec {
            id: BlockId(1),
            ticket: TicketId(1),
            origin_window: WindowId(10),
            rank: 1,
            color: Color::Blue,
            parents: Vec::new(),
        },
        BlockSpec {
            id: BlockId(2),
            ticket: TicketId(2),
            origin_window: WindowId(20),
            rank: 1,
            color: Color::Blue,
            parents: vec![BlockId(1)],
        },
        BlockSpec {
            id: BlockId(3),
            ticket: TicketId(3),
            origin_window: WindowId(30),
            rank: 1,
            color: Color::Blue,
            parents: vec![BlockId(1)],
        },
    ];
    let histories = [
        HistorySpec {
            id: HistoryId(900),
            parent: HistoryId::default(),
            window: WindowId(10),
            blocks: vec![BlockId(1)],
        },
        HistorySpec {
            id: HistoryId(2),
            parent: HistoryId(900),
            window: WindowId(20),
            blocks: vec![BlockId(2)],
        },
        HistorySpec {
            id: HistoryId(700),
            parent: HistoryId(900),
            window: WindowId(30),
            blocks: vec![BlockId(3)],
        },
    ];
    let body_truth = BTreeMap::from([(BlockId(1), true), (BlockId(2), true), (BlockId(3), true)]);
    let context_truth = BTreeMap::from([
        ((HistoryId(900), BlockId(1)), true),
        ((HistoryId(2), BlockId(1)), true),
        ((HistoryId(2), BlockId(2)), true),
        ((HistoryId(700), BlockId(1)), true),
        ((HistoryId(700), BlockId(3)), true),
    ]);
    let catalog =
        Catalog::build(&blocks, &histories, &body_truth, &context_truth).expect("catálogo");
    let mut view = View::default();
    view.headers.extend([BlockId(1), BlockId(2), BlockId(3)]);
    assert!(view.deliver_body(&catalog, BlockId(1), "COMPLETE"));
    assert!(view.deliver_body(&catalog, BlockId(2), "COMPLETE"));
    for evidence in [
        (HistoryId(900), BlockId(1)),
        (HistoryId(2), BlockId(1)),
        (HistoryId(2), BlockId(2)),
    ] {
        assert!(view.deliver_context(&catalog, evidence.0, evidence.1, true));
    }
    assert_eq!(
        view.apply(&catalog, HistoryId(900), Policy::P0),
        Outcome::Applied
    );
    assert_eq!(
        view.apply(&catalog, HistoryId(2), Policy::P0),
        Outcome::Applied
    );
    let public_before = view.public.clone();
    let undo_before = view.undo.clone();

    assert_eq!(
        view.replay(&catalog, HistoryId(700), Policy::P0),
        Outcome::Pending
    );
    assert_eq!(view.public, public_before);
    assert_eq!(view.undo, undo_before);
    assert_eq!(view.pending, Some(HistoryId(700)));

    assert!(view.deliver_body(&catalog, BlockId(3), "COMPLETE"));
    assert!(view.deliver_context(&catalog, HistoryId(700), BlockId(1), true));
    assert!(view.deliver_context(&catalog, HistoryId(700), BlockId(3), true));
    assert_eq!(
        view.replay(&catalog, HistoryId(700), Policy::P0),
        Outcome::Applied
    );
    assert_eq!(view.undo(HistoryId(700)), Outcome::Applied);
    assert_eq!(
        view.replay(&catalog, HistoryId(2), Policy::P0),
        Outcome::Applied
    );
    assert_eq!(view.public, public_before);
    assert_eq!(view.undo, undo_before);
    view.assert_projection_invariant();
}

#[test]
fn parser_rechaza_estructura_y_definiciones_fuera_de_contrato() {
    let mut cases = vec![
        ("CASE anidado", format!("CASE abandonado P0\n{FIXTURES}")),
        (
            "fuera de CASE",
            format!("BLOCK 777 777 777 0 B -\n{FIXTURES}"),
        ),
        ("CASE sin END", format!("{FIXTURES}\nCASE pendiente P0")),
        (
            "VIEW con sufijo",
            FIXTURES.replacen("VIEW Ana\n", "VIEW Ana EXTRA\n", 1),
        ),
        (
            "END con sufijo",
            FIXTURES.replacen("\nEND", "\nEND EXTRA", 1),
        ),
        ("vacío", String::new()),
        ("sólo comentarios", "# sin casos\n".to_owned()),
        ("CASE vacío", "CASE vacio P0\nEND\n".to_owned()),
        (
            "sin CASE",
            FIXTURES.replacen("CASE ana_bruno_particion P0\n", "", 1),
        ),
        ("END repetido", format!("{FIXTURES}\nEND")),
        (
            "vista duplicada",
            FIXTURES.replacen("VIEW Ana\n", "VIEW Ana\nVIEW Ana\n", 1),
        ),
        (
            "directiva desconocida",
            FIXTURES.replacen("VIEW Ana\n", "VIEW Ana\nUNKNOWN\n", 1),
        ),
    ];
    for definition in [
        "BLOCK 777 777 777 0 B -",
        "HISTORY 777 - 777 -",
        "BODY_TRUTH 777 COMPLETE",
        "CONTEXT_TRUTH 100 2 VALID",
    ] {
        cases.push((
            "definición después de congelar",
            FIXTURES.replacen("VIEW Ana\n", &format!("VIEW Ana\n{definition}\n"), 1),
        ));
    }
    for (name, input) in cases {
        assert!(
            std::panic::catch_unwind(|| execute_fixture(&input)).is_err(),
            "aceptó {name}"
        );
    }
}

#[test]
fn expectativas_rechazan_subcampos_y_duplicados() {
    for token in ["+1", "-0", "0x1", "18446744073709551616", "", "１"] {
        assert!(
            std::panic::catch_unwind(|| parse_u64(token, 1)).is_err(),
            "entero no canónico: {token}"
        );
    }
    assert_eq!(parse_u64("18446744073709551615", 1), u64::MAX);
    assert_eq!(parse_u64("0001", 1), 1);
    let pending_zero =
        "CASE sin_pending P0\nHISTORY 1 - 0 -\nVIEW Ana\nEXPECT Ana - - - - - - 0\nEND\n";
    assert!(std::panic::catch_unwind(|| execute_fixture(pending_zero)).is_err());
    for token in ["1:2:3", "1", "1:", "1:2,1:2"] {
        assert!(
            std::panic::catch_unwind(|| parse_events(token, 1)).is_err(),
            "evento: {token}"
        );
    }
    for token in ["1:2:3:4", "1:2", "1:2:3,1:2:3"] {
        assert!(
            std::panic::catch_unwind(|| parse_inert(token, 1)).is_err(),
            "Inert: {token}"
        );
    }
    for token in ["1=1:2=3", "1=1:2/1=1:3", "1=1:2,1:2"] {
        assert!(
            std::panic::catch_unwind(|| parse_snapshots(token, 1)).is_err(),
            "snapshot: {token}"
        );
    }
    assert!(std::panic::catch_unwind(|| parse_tickets("1,1", 1)).is_err());
    assert!(std::panic::catch_unwind(|| parse_outcome("PolicyMismatch", 1)).is_err());
    assert_eq!(
        parse_events("18446744073709551615:18446744073709551615", 1),
        vec![EventId {
            history: HistoryId(u64::MAX),
            block: BlockId(u64::MAX),
        }]
    );
}

fn policy_catalog() -> Catalog {
    let blocks = [
        BlockSpec {
            id: BlockId(1),
            ticket: TicketId(1),
            origin_window: WindowId(10),
            rank: 1,
            color: Color::RedK,
            parents: Vec::new(),
        },
        BlockSpec {
            id: BlockId(2),
            ticket: TicketId(1),
            origin_window: WindowId(10),
            rank: 2,
            color: Color::Blue,
            parents: Vec::new(),
        },
        BlockSpec {
            id: BlockId(3),
            ticket: TicketId(2),
            origin_window: WindowId(20),
            rank: 1,
            color: Color::Blue,
            parents: Vec::new(),
        },
        BlockSpec {
            id: BlockId(4),
            ticket: TicketId(3),
            origin_window: WindowId(30),
            rank: 1,
            color: Color::Blue,
            parents: Vec::new(),
        },
    ];
    let histories = [
        HistorySpec {
            id: HistoryId(100),
            parent: HistoryId(0),
            window: WindowId(10),
            blocks: vec![BlockId(1), BlockId(2)],
        },
        HistorySpec {
            id: HistoryId(200),
            parent: HistoryId(100),
            window: WindowId(20),
            blocks: vec![BlockId(3)],
        },
        HistorySpec {
            id: HistoryId(300),
            parent: HistoryId(100),
            window: WindowId(30),
            blocks: vec![BlockId(4)],
        },
    ];
    let body_truth = blocks.iter().map(|block| (block.id, true)).collect();
    let context_truth = BTreeMap::from([
        ((HistoryId(100), BlockId(1)), true),
        ((HistoryId(100), BlockId(2)), true),
        ((HistoryId(200), BlockId(3)), true),
        ((HistoryId(300), BlockId(4)), true),
    ]);
    Catalog::build(&blocks, &histories, &body_truth, &context_truth).expect("catálogo de políticas")
}

fn assert_policy_mismatch_unchanged(
    view: &mut View,
    catalog: &Catalog,
    target: HistoryId,
    other: Policy,
) {
    let before = view.clone();
    assert_eq!(view.apply(catalog, target, other), Outcome::PolicyMismatch);
    assert_eq!(
        *view, before,
        "apply cambió la vista ante política incompatible"
    );
    assert_eq!(view.replay(catalog, target, other), Outcome::PolicyMismatch);
    assert_eq!(
        *view, before,
        "replay cambió la vista ante política incompatible"
    );
}

#[test]
fn politica_fijada_sobrevive_pending_ramas_replay_y_undo_a_genesis() {
    let catalog = policy_catalog();
    for (policy, other, winner) in [
        (Policy::P0, Policy::P1, BlockId(1)),
        (Policy::P1, Policy::P0, BlockId(2)),
    ] {
        let mut view = View::new(policy);
        assert_policy_mismatch_unchanged(&mut view, &catalog, HistoryId(100), other);
        assert_eq!(
            view.apply(&catalog, HistoryId(100), policy),
            Outcome::Pending
        );
        for target in [
            HistoryId(0),
            HistoryId(100),
            HistoryId(200),
            HistoryId(300),
            HistoryId(999),
        ] {
            assert_policy_mismatch_unchanged(&mut view, &catalog, target, other);
        }
        for block in catalog.blocks.keys() {
            view.headers.insert(*block);
            assert!(view.deliver_body(&catalog, *block, "COMPLETE"));
        }
        for ((history, block), valid) in &catalog.context_truth {
            assert!(view.deliver_context(&catalog, *history, *block, *valid));
        }
        assert_eq!(
            view.apply(&catalog, HistoryId(100), policy),
            Outcome::Applied
        );
        assert_eq!(
            view.public.journal,
            vec![EventId {
                history: HistoryId(100),
                block: winner
            }]
        );
        assert_policy_mismatch_unchanged(&mut view, &catalog, HistoryId(100), other);
        assert_policy_mismatch_unchanged(&mut view, &catalog, HistoryId(200), other);
        assert_eq!(
            view.apply(&catalog, HistoryId(200), policy),
            Outcome::Applied
        );
        assert_policy_mismatch_unchanged(&mut view, &catalog, HistoryId(300), other);
        assert_eq!(
            view.replay(&catalog, HistoryId(300), policy),
            Outcome::Applied
        );
        assert_eq!(view.policy, policy);
        assert_eq!(
            view.replay(&catalog, HistoryId(0), policy),
            Outcome::Applied
        );
        assert_eq!(view.public, PublicState::default());
        assert_eq!(view.policy, policy);
        assert_policy_mismatch_unchanged(&mut view, &catalog, HistoryId(100), other);
        assert_eq!(
            view.apply(&catalog, HistoryId(100), policy),
            Outcome::Applied
        );
        assert_eq!(view.undo(HistoryId(100)), Outcome::Applied);
        assert_eq!(view.public, PublicState::default());
        assert_eq!(view.policy, policy);
        assert_policy_mismatch_unchanged(&mut view, &catalog, HistoryId(100), other);
        view.assert_projection_invariant();
    }
}

#[test]
fn estructura_profunda_y_ciclo_con_ids_inversos_sin_recursion() {
    // Vector estructural del instrumento, no traza GHOSTDAG ni parámetro de red.
    // Los padres tienen ID mayor: la antigua DFS agotaba la pila con estos 50.000 bloques.
    let depth = 50_000_u64;
    let mut blocks = (1..=depth)
        .map(|id| BlockSpec {
            id: BlockId(id),
            ticket: TicketId(id),
            origin_window: WindowId(1),
            rank: depth.checked_sub(id).expect("id no excede profundidad"),
            color: Color::Blue,
            parents: if id == depth {
                Vec::new()
            } else {
                vec![BlockId(id.checked_add(1).expect("padre representable"))]
            },
        })
        .collect::<Vec<_>>();
    let histories = [HistorySpec {
        id: HistoryId(1),
        parent: HistoryId(0),
        window: WindowId(1),
        blocks: (1..=depth).map(BlockId).collect(),
    }];
    let body_truth = blocks.iter().map(|block| (block.id, true)).collect();
    let catalog = Catalog::build(&blocks, &histories, &body_truth, &BTreeMap::new())
        .expect("cadena profunda");
    assert!(catalog.history_structure_valid(HistoryId(1)));
    blocks
        .last_mut()
        .expect("cadena no vacía")
        .parents
        .push(BlockId(1));
    let cyclic = Catalog::build(&blocks, &histories, &body_truth, &BTreeMap::new())
        .expect("catálogo con ciclo");
    assert!(!cyclic.history_structure_valid(HistoryId(1)));
}

#[test]
fn dominio_de_ids_y_contexto_ausente_no_se_aceptan_por_defecto() {
    for (block_id, ticket_id, history_id, expected) in [
        (0, 1, 1, false),
        (1, 0, 1, false),
        (1, 1, 0, false),
        (u64::MAX, u64::MAX, u64::MAX, true),
    ] {
        let block = BlockId(block_id);
        let history = HistoryId(history_id);
        let blocks = [BlockSpec {
            id: block,
            ticket: TicketId(ticket_id),
            origin_window: WindowId(0),
            rank: u64::MAX,
            color: Color::Blue,
            parents: Vec::new(),
        }];
        let histories = [HistorySpec {
            id: history,
            parent: HistoryId(0),
            window: WindowId(0),
            blocks: vec![block],
        }];
        let catalog = Catalog::build(
            &blocks,
            &histories,
            &BTreeMap::from([(block, true)]),
            &BTreeMap::new(),
        );
        assert_eq!(catalog.is_some(), expected);
        if let Some(catalog) = catalog {
            assert!(catalog.history_structure_valid(history));
            let mut view = View::default();
            view.headers.insert(block);
            assert!(view.deliver_body(&catalog, block, "COMPLETE"));
            assert_eq!(view.apply(&catalog, history, Policy::P0), Outcome::Pending);
            let before = view.clone();
            assert!(!view.deliver_context(&catalog, history, block, true));
            assert!(!view.deliver_context(&catalog, history, block, false));
            assert_eq!(view, before);
        }
    }
}

#[test]
fn rechazo_de_descarga_no_revive_cuerpo_invalido() {
    let block = BlockId(1);
    let blocks = [BlockSpec {
        id: block,
        ticket: TicketId(1),
        origin_window: WindowId(0),
        rank: 0,
        color: Color::Blue,
        parents: Vec::new(),
    }];
    let histories = [HistorySpec {
        id: HistoryId(1),
        parent: HistoryId(0),
        window: WindowId(0),
        blocks: vec![block],
    }];
    let catalog = Catalog::build(
        &blocks,
        &histories,
        &BTreeMap::from([(block, false)]),
        &BTreeMap::new(),
    )
    .expect("cuerpo inválido objetivo");
    let mut view = View::default();
    assert!(view.deliver_body(&catalog, block, "REJECT"));
    assert!(view.rejected_deliveries.contains(&block));
    assert!(view.deliver_body(&catalog, block, "INVALID"));
    assert!(!view.rejected_deliveries.contains(&block));
    let before = view.clone();
    assert!(view.deliver_body(&catalog, block, "REJECT"));
    assert!(!view.deliver_body(&catalog, block, "COMPLETE"));
    assert_eq!(view, before);
}
