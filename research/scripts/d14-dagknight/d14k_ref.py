#!/usr/bin/env python3
r"""
d14k_ref.py — Modelo del rank de DAGKNIGHT FIEL a la implementación de referencia.

Fuente primaria: rama `dagknight` de kaspanet/rusty-kaspa (leída el 2026-09-10):
  · consensus/src/processes/dagknight/protocol.rs   (select_parent_from_k_colouring, rank)
  · consensus/src/processes/dagknight/manager.rs    (fill_zone_data, k_colouring)
  · consensus/src/processes/dagknight/umc_baseline.rs (Alg. 6 ponderado por trabajo)
  · consensus/umc_fixture.json                      (vector con score esperado 4w)

Algoritmo (por vista de DAG):
  1. tips; CG = LCA de cadena de los tips (si hay 1 tip, CG = genesis).
  2. Subgrupos = tips agrupados por su next-chain-ancestor (NCA) por encima de CG.
  3. Para cada subgrupo y cada k:
     a. Coloreado comprometido de la zona: se rellena la zona (descendientes de cadena
        del NCA hasta los tips) con GHOSTDAG(k) y sp forzado a padres "que acuerdan"
        (los del subgrupo). Igual que `fill_zone_data` (manager.rs:440-580).
     b. Bloque virtual: parents = TODOS los tips, sp = VSP del subgrupo
        (max blue_work). Se colorea su mergeset con GHOSTDAG(k).
     c. UMC-Voting base (umc_baseline.rs): se recorren los mergesets de la cadena del
        virtual hasta CG; rojos que descienden del NCA son GRISES (no votan).
        vote(B) = sign(Σ votos azules en future(B) − |rojos ∩ future(B)| + g(k)) · work(B).
        virtual_score = Σ votos + g(k) − |rojos|; aceptado si ≥ 0.
  4. rank(vista) = mínimo k con algún subgrupo aceptado (RankSearcher lineal).

Pesos: en ZEROX y en el control del paper todos los bloques pesan 1 (work = 1), como en
la simulación del paper; el modelo usa conteos (documentado).
"""
import math
import os
import sys

_DIR = os.path.dirname(os.path.abspath(__file__))
_D9C = os.path.normpath(os.path.join(_DIR, "..", "d9-ronda8c"))
if _D9C not in sys.path:
    sys.path.insert(0, _D9C)
sys.path.insert(0, _DIR)

from r8c_gd import DAG as GD_DAG, GD  # noqa: E402
from d14k_lib import popcount, iter_bits  # noqa: E402


class ZoneDAG(GD_DAG):
    """GHOSTDAG(k) sobre la zona, con reachability del DAG COMPLETO (necesaria para
    comparar candidatos de otros subgrupos contra la cadena comprometida)."""

    def __init__(self, kdag, k):
        super().__init__(k=k, u2=False, u3_mode="off",
                         max_parents=10 ** 9, mergeset_limit=10 ** 9)
        self.kdag = kdag

    def is_ancestor(self, a, b):
        if a == b:
            return True
        return bool((self.kdag.past[b] >> a) & 1)


def global_blue_work(kdag, k=30):
    """blue_work global (GHOSTDAG k=30, como el nodo DK real corre GHOSTDAG en paralelo).
    Devuelve lista bid -> blue_work."""
    d = GD_DAG(k=k, u2=False, u3_mode="off", max_parents=10 ** 9, mergeset_limit=10 ** 9)
    d.genesis("G")
    bw = {0: 0}
    ids = {0: "G"}
    for i in range(1, kdag.n):
        bid = f"b{i}"
        ids[i] = bid
        ok, mot = d.add(bid, [ids[p] for p in kdag.parents[i]],
                        t=kdag.times[i], creator=kdag.creators[i],
                        ident=None, sd=0, seed=0, enforce=False)
        assert ok, (i, mot)
        bw[i] = d.gd[bid].blue_work
    return bw


def next_after(kdag, x, g):
    """Primer ancestro de cadena de x estrictamente por encima de g (None si x == g)."""
    cur = x
    while cur != g:
        p = kdag.chain_parent[cur]
        if p is None or p == g:
            return cur
        cur = p
    return None


def zone_of(kdag, tips, nca):
    """Zona comprometida: descendientes de cadena de nca dentro de past(tips) ∪ tips."""
    union = 0
    for t in tips:
        union |= kdag.past[t] | (1 << t)
    zone = 0
    for x in iter_bits(union):
        if kdag.in_chain(nca, x):
            zone |= 1 << x
    return zone


def committed_coloring(kdag, tips, nca, cg, k):
    """Rellena la zona con GHOSTDAG(k) y padres filtrados a la zona (fill_zone_data).
    La raíz del relleno es el NCA; su sp en la cadena comprometida es CG."""
    zone = zone_of(kdag, tips, nca)
    zd = ZoneDAG(kdag, k)
    zd.genesis(nca)
    zd.gd[nca] = GD(sp=cg, mergeset_blues=[cg], mergeset_reds=[],
                    blues_anticone_sizes={cg: 0})
    zd.gd[cg] = GD(sp=None, mergeset_blues=[], mergeset_reds=[],
                   blues_anticone_sizes={})
    for x in iter_bits(zone):
        if x == nca:
            continue
        ps = [p for p in kdag.parents[x] if (zone >> p) & 1]
        if not ps:
            ps = [nca]
        ok, mot = zd.add(x, ps, t=kdag.times[x], creator=kdag.creators[x],
                         ident=None, sd=0, seed=0, enforce=False)
        assert ok, (x, mot)
    return zd, zone


def virtual_coloring(kdag, zd, all_tips, vsp, cg, k, bw):
    """Colorea el bloque virtual (parents = todos los tips, sp = vsp) con GHOSTDAG(k).
    El mergeset se restringe a la zona de conflicto Future(CG) ∩ past(tips)."""
    union = 0
    for t in all_tips:
        union |= kdag.past[t] | (1 << t)
    zone_desc = kdag.future[cg] | (1 << cg)
    ms = union & ~(kdag.past[vsp] | (1 << vsp)) & zone_desc
    ordered = sorted(iter_bits(ms), key=lambda h: (bw[h], h))
    nd = GD(sp=vsp, mergeset_blues=[vsp], mergeset_reds=[], blues_anticone_sizes={vsp: 0})
    for cand in ordered:
        col, cbas, cbs = zd.check_blue_candidate(nd, cand)
        if col == "blue":
            nd.mergeset_blues.append(cand)
            nd.blues_anticone_sizes[cand] = cbas
            for h, s in cbs.items():
                nd.blues_anticone_sizes[h] = s + 1
        else:
            nd.mergeset_reds.append(cand)
    return nd


def umc_voting(kdag, zd, cg, nca, virtual_nd, k, bw):
    """Alg. 6 (umc_baseline.rs) con grises. Devuelve (accepted, virtual_score, blues, reds)."""
    blues, reds = [], []
    cur = virtual_nd
    while cur.sp != cg:
        blues.extend(cur.mergeset_blues)
        for r in cur.mergeset_reds:
            if not kdag.in_chain(nca, r):
                reds.append(r)
        cur = zd.gd[cur.sp]
    blues.append(cg)
    deficit = math.isqrt(k)
    redset = set(reds)
    votes = {}
    for B in sorted(blues, key=lambda h: (-bw[h], h)):
        fb = kdag.future[B]
        val = sum(v for C, v in votes.items() if (fb >> C) & 1)
        rw = sum(1 for r in redset if (fb >> r) & 1)
        votes[B] = 1 if val - rw + deficit >= 0 else -1
    virtual_score = sum(votes.values()) + deficit - len(reds)
    return virtual_score >= 0, virtual_score, blues, reds


def rank_view(kdag, tips, bw, kmax=40):
    """Rank de la vista: mínimo k con algún subgrupo aceptado. Devuelve
    (k, lista_de_ganadores) con ganadores = [(cg, subgroup, vsp, blues, reds, score)]."""
    if not tips:
        return 0, []
    if len(tips) == 1:
        cg = 0
    else:
        cg = tips[0]
        for t in tips[1:]:
            cg = kdag.chain_lca(cg, t)
    groups = {}
    for t in tips:
        nca = next_after(kdag, t, cg)
        groups.setdefault(nca, []).append(t)
    survivors = list(groups.items())
    for k in range(kmax + 1):
        winners = []
        for nca, gtips in survivors:
            zd, _ = committed_coloring(kdag, gtips, nca, cg, k)
            vsp = max(gtips, key=lambda t: (bw[t], -t))
            vnd = virtual_coloring(kdag, zd, tips, vsp, cg, k, bw)
            ok, score, blues, reds = umc_voting(kdag, zd, cg, nca, vnd, k, bw)
            if ok:
                winners.append((nca, gtips, vsp, blues, reds, score))
        if winners:
            return k, winners
    return None, []


def rank_dag(kdag, kmax=40):
    """Rank de la vista completa (todos los tips)."""
    tips = list(iter_bits(kdag.tips_mask()))
    bw = global_blue_work(kdag)
    return rank_view(kdag, tips, bw, kmax)
