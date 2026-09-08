#!/usr/bin/env python3
"""
r8c_gd.py — GHOSTDAG minimo FIEL a rusty-kaspa @ c338d495.

Correspondencia linea a linea con el clon en /home/katana/zeo/fuentes/rusty-kaspa:

  find_selected_parent      <- protocol.rs:99-106   (max de SortableBlock sobre padres)
  SortableBlock::cmp        <- ordering.rs:38-42    (blue_work asc, desempate por hash asc;
                                                     AQUI: desempate por menor solution_distance,
                                                     segun R-FIN de ZEROX -> clave (bw, -sd))
  sort_blocks               <- ordering.rs:44-50
  unordered_mergeset_...    <- mergeset.rs:9-40     (BFS; se poda por is_dag_ancestor_of(sp))
  ordered_mergeset_...      <- mergeset.rs:43-45    (= sort_blocks(unordered))
  ghostdag()                <- protocol.rs:121-165  (voraz sobre ordered_mergeset, add_blue/add_red)
  check_blue_candidate      <- protocol.rs:246-283  (tope k+1 en mergeset_blues; bucle por la
                                                     cadena seleccionada del bloque nuevo)
  check_blue_candidate_with_chain_block <- protocol.rs:170-225
  blue_anticone_size        <- protocol.rs:229-244
  mergeset_size             <- model/stores/ghostdag.rs:111-113 (azules + ROJOS)
  orden de consenso         <- model/stores/ghostdag.rs:83-91 consensus_ordered_mergeset
                               = [sp] ++ mergeset ascendente  =>  concatenando por la cadena:
                                 g, mergeset(C1), C1, mergeset(C2), C2, ...
                               (el bloque va DESPUES de su mergeset; coincide con el paper L297-300)

Reglas de ZEROX que se pueden activar/desactivar para auditarlas:
  u2          R-FIN-11 U2: misma identidad en el past -> bloque INVALIDO.
  u3_mode     'off'      : GHOSTDAG puro.
              'post'     : U3' como posproceso (forma refutada por D9-a).
              'filter'   : U3'-filtro TAL COMO ESTA ESCRITA en R-FIN-11:
                           candidata a azul solo si su identidad NO es ya azul en past(sp).
              'dynamic'  : la reparacion que propongo: ademas de past(sp), tambien las
                           identidades ya coloreadas de azul EN ESTE MISMO mergeset.
  max_parents R-FIN-12 (bps.rs:57-72)   -> 12 a k=25
  mergeset_limit R-FIN-12 (bps.rs:75-80) -> 180 a k=25; superarlo = bloque INVALIDO
                           (post_pow_validation.rs:30-37, RuleError::MergeSetTooBig)
"""
from dataclasses import dataclass, field

K_DEFAULT = 25
MAX_PARENTS = 12          # bps.rs:57-72 con k=25 -> max(10, min(16, 25/2)) = 12
MERGESET_LIMIT = 180      # bps.rs:75-80 con k=25 -> max(180, min(512, 50)) = 180


@dataclass
class Block:
    bid: str
    parents: tuple
    t: float = 0.0          # instante de CREACION (invariante al renombrado)
    creator: str = "h"      # 'h' honesto, 'a' atacante
    ident: object = None    # identidad de billete (public_key, sector, hist, chunk, slot)
    sd: int = 0             # solution_distance: desempate, menor gana
    seed: int = 0           # entropia que aportaria como inyector; FIJA en la creacion


@dataclass
class GD:
    sp: str = None
    mergeset_blues: list = field(default_factory=list)   # [sp] + azules en orden de coloreado
    mergeset_reds: list = field(default_factory=list)
    blues_anticone_sizes: dict = field(default_factory=dict)
    blue_score: int = 0
    blue_work: int = 0
    pos: int = 0            # R-FIN-1: pos(B) = pos(sp(B)) + 1
    blue_idents: frozenset = frozenset()   # identidades azules en blueset(B) u {B}

    def mergeset_size(self):
        # ghostdag.rs:111-113 -> azules + rojos
        return len(self.mergeset_blues) + len(self.mergeset_reds)


class DAG:
    """DAG con reachability por cierre transitivo (exacto, coste O(n^2) en bits)."""

    def __init__(self, k=K_DEFAULT, u2=True, u3_mode="filter",
                 max_parents=MAX_PARENTS, mergeset_limit=MERGESET_LIMIT):
        self.k = k
        self.u2 = u2
        self.u3_mode = u3_mode
        self.max_parents = max_parents
        self.mergeset_limit = mergeset_limit
        self.B = {}          # bid -> Block
        self.gd = {}         # bid -> GD
        self.anc = {}        # bid -> set de ancestros ESTRICTOS
        self.n = 0

    # ---------- reachability ----------
    def is_ancestor(self, a, b):
        """is_dag_ancestor_of(a, b): a esta en past(b). Kaspa lo usa con a==b -> True."""
        return a == b or a in self.anc[b]

    # ---------- genesis ----------
    def genesis(self, bid="G", seed=0):
        blk = Block(bid, tuple(), t=0.0, creator="g", ident=("G", 0), sd=0, seed=seed)
        self.B[bid] = blk
        self.anc[bid] = set()
        self.gd[bid] = GD(sp=None, mergeset_blues=[bid], mergeset_reds=[],
                          blues_anticone_sizes={bid: 0}, blue_score=0, blue_work=0,
                          pos=0, blue_idents=frozenset({blk.ident}))
        self.n = 1
        return bid

    # ---------- ordering.rs ----------
    def _key(self, h):
        """SortableBlock::cmp — ordering.rs:38-42. blue_work asc; desempate: menor sd gana
        (ZEROX sustituye el hash de Kaspa por solution_distance)."""
        return (self.gd[h].blue_work, -self.B[h].sd, h)

    def sort_blocks(self, hs):
        return sorted(hs, key=self._key)

    def find_selected_parent(self, parents):
        # protocol.rs:99-106 -> .max()
        return max(parents, key=self._key)

    # ---------- mergeset.rs:9-40 ----------
    def unordered_mergeset(self, sp, parents):
        # Kaspa arranca con `parents \ {sp}` porque los padres son SIEMPRE una anticadena
        # (son tips). Aqui filtramos ademas los que sean ancestros de sp, para que la funcion
        # siga siendo exactamente past(B) \ (past(sp) u {sp}) tambien con padres no-tips
        # (el paper L1032 permite al atacante apuntar a bloques que no son tips).
        queue = [p for p in parents if p != sp and not self.is_ancestor(p, sp)]
        mergeset = set(queue)
        past = set()
        while queue:
            cur = queue.pop(0)
            for p in self.B[cur].parents:
                if p in mergeset or p in past:
                    continue
                if self.is_ancestor(p, sp):
                    past.add(p)
                    continue
                mergeset.add(p)
                queue.append(p)
        return mergeset

    # ---------- protocol.rs:229-244 ----------
    def blue_anticone_size(self, block, ctx_sizes, ctx_sp):
        sizes = dict(ctx_sizes)
        cur = ctx_sp
        while True:
            if block in sizes:
                return sizes[block]
            if cur is None:
                raise AssertionError(f"{block} no esta en el blue set del contexto")
            sizes = self.gd[cur].blues_anticone_sizes
            cur = self.gd[cur].sp

    # ---------- protocol.rs:170-225 ----------
    def _check_with_chain_block(self, new_sizes, new_sp, chain_hash, chain_data,
                                cand, cand_sizes, cand_size):
        if chain_hash is not None and self.is_ancestor(chain_hash, cand):
            return "blue", cand_size
        for peer in chain_data.mergeset_blues:
            if self.is_ancestor(peer, cand):
                continue
            pbas = self.blue_anticone_size(peer, new_sizes, new_sp)
            cand_sizes[peer] = pbas
            cand_size += 1
            if cand_size > self.k:
                return "red", cand_size
            if pbas == self.k:
                return "red", cand_size
            assert pbas <= self.k
        return "pending", cand_size

    # ---------- protocol.rs:246-283 ----------
    def check_blue_candidate(self, nd, cand):
        if len(nd.mergeset_blues) == self.k + 1:
            return ("red", None, None)
        cand_sizes = {}
        cand_size = 0
        chain_hash, chain_data = None, nd
        while True:
            state, cand_size = self._check_with_chain_block(
                nd.blues_anticone_sizes, nd.sp, chain_hash, chain_data, cand, cand_sizes, cand_size)
            if state == "blue":
                return ("blue", cand_size, cand_sizes)
            if state == "red":
                return ("red", None, None)
            chain_hash = chain_data.sp
            chain_data = self.gd[chain_hash]

    # ---------- protocol.rs:121-165 + reglas ZEROX ----------
    def add(self, bid, parents, t=0.0, creator="h", ident=None, sd=0, seed=0,
            enforce=True):
        """Devuelve (ok, motivo). Si ok=False el bloque NO se anade (invalido)."""
        parents = tuple(parents)
        assert parents, "genesis se anade con genesis()"
        if enforce and len(parents) > self.max_parents:
            return (False, "TooManyParents")

        blk = Block(bid, parents, t=t, creator=creator, ident=ident, sd=sd, seed=seed)
        anc = set()
        for p in parents:
            anc.add(p)
            anc |= self.anc[p]

        # R-FIN-11 U2: misma identidad en el past -> INVALIDO
        if enforce and self.u2 and ident is not None:
            for x in anc:
                if self.B[x].ident == ident:
                    return (False, "U2")

        self.B[bid] = blk
        self.anc[bid] = anc

        sp = self.find_selected_parent(parents)
        nd = GD(sp=sp, mergeset_blues=[sp], mergeset_reds=[],
                blues_anticone_sizes={sp: 0})
        ms = self.unordered_mergeset(sp, parents)

        if enforce and (len(ms) + 1) > self.mergeset_limit:
            # post_pow_validation.rs:30-37 — mergeset_size cuenta azules Y rojos
            del self.B[bid]
            del self.anc[bid]
            return (False, "MergeSetTooBig")

        ordered = self.sort_blocks(ms)          # menor a mayor blue_work

        sp_bi = self.gd[sp].blue_idents
        seen_blue_idents = set()                # para u3_mode='dynamic'
        for cand in ordered:
            cid = self.B[cand].ident
            filtered = False
            if self.u3_mode in ("filter", "dynamic") and cid is not None:
                if cid in sp_bi:
                    filtered = True
                if self.u3_mode == "dynamic" and cid in seen_blue_idents:
                    filtered = True
            if filtered:
                nd.mergeset_reds.append(cand)
                continue
            col, cbas, cbs = self.check_blue_candidate(nd, cand)
            if col == "blue":
                nd.mergeset_blues.append(cand)
                nd.blues_anticone_sizes[cand] = cbas
                for h, s in cbs.items():
                    nd.blues_anticone_sizes[h] = s + 1
                if cid is not None:
                    seen_blue_idents.add(cid)
            else:
                nd.mergeset_reds.append(cand)

        if self.u3_mode == "post":
            # forma REFUTADA por D9-a: degradar despues del voraz
            keep, drop = [], []
            for h in nd.mergeset_blues:
                cid = self.B[h].ident
                if cid is not None and (cid in sp_bi or cid in {self.B[x].ident for x in keep}):
                    drop.append(h)
                else:
                    keep.append(h)
            for h in drop:
                nd.mergeset_blues.remove(h)
                nd.mergeset_reds.append(h)

        nd.blue_score = self.gd[sp].blue_score + len(nd.mergeset_blues)
        nd.blue_work = self.gd[sp].blue_work + len(nd.mergeset_blues)   # work = 1 por bloque
        nd.pos = self.gd[sp].pos + 1                                     # R-FIN-1
        nd.blue_idents = sp_bi | {self.B[h].ident for h in nd.mergeset_blues
                                  if self.B[h].ident is not None}
        if ident is not None:
            nd.blue_idents = nd.blue_idents | {ident}

        self.gd[bid] = nd
        self.n += 1
        return (True, "ok")

    # ---------- virtual ----------
    def tips(self, visible=None):
        vis = set(self.B) if visible is None else set(visible)
        haspar = set()
        for h in vis:
            for p in self.B[h].parents:
                haspar.add(p)
        return sorted(vis - haspar)

    def virtual_sp(self, visible=None):
        return self.find_selected_parent(self.tips(visible))

    def selected_chain(self, tip):
        """De genesis a tip; chain[i] = bloque en la posicion i (R-FIN-1)."""
        ch = []
        cur = tip
        while cur is not None:
            ch.append(cur)
            cur = self.gd[cur].sp
        ch.reverse()
        return ch

    def total_order(self, tip):
        """ghostdag.rs:83-91 consensus_ordered_mergeset concatenado por la cadena:
        g, mergeset(C1), C1, mergeset(C2), C2, ...  (el bloque va DESPUES de su mergeset)."""
        ch = self.selected_chain(tip)
        order = [ch[0]]
        for c in ch[1:]:
            nd = self.gd[c]
            ms = [h for h in nd.mergeset_blues[1:]] + list(nd.mergeset_reds)
            order.extend(self.sort_blocks(ms))
            order.append(c)
        return order

    def blueset(self, tip):
        """blues(tip) u {tip}. mergeset_blues(C_i) incluye a sp=C_{i-1}, asi que la union
        sobre la cadena da {C_0..C_{h-1}} u (azules fusionados); el propio tip se anade."""
        s = {tip}
        for c in self.selected_chain(tip):
            s.update(self.gd[c].mergeset_blues)
        return s
