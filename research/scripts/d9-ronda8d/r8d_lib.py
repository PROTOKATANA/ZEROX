#!/usr/bin/env python3
"""
r8d_lib.py — EXTENSION del instrumento de D9-c. No reescribe nada: importa
`r8c_gd.py` (GHOSTDAG fiel a rusty-kaspa @ c338d495) y `r8c_sim.py` (simulador de
eventos, adversario del paper L1024-1027 sin retardo) y les anade solo lo que la
ronda 8d necesita:

  · ancla_bs(d, tip, T)  R-FIN-1 TERCER ANCLA: `seed` del PRIMER bloque de la cadena
                         seleccionada con blue_score >= T. Estructural: `seed` se fija
                         en la creacion (r8c_sim.py L?), renombrar no lo altera.
  · bs_chain(d, tip)     lista de (bid, blue_score) de la cadena seleccionada.
  · wH(d, visibles)      score del bloque VIRTUAL del nodo honesto = w_H(t) del paper
                         (phantom-ghostdag.txt L1035-1037: "The honest score wH(t) is
                         defined as the score of the virtual block of the honest node
                         at time t"). Se usa para medir delta_ef via el Lema 9.

Criterio alpha: todo lo de aqui es lectura; los adversarios viven en los scripts A*.
"""
import sys, os

_D9C = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "d9-ronda8c")
if _D9C not in sys.path:
    sys.path.insert(0, os.path.normpath(_D9C))

from r8c_gd import DAG, Block, GD, K_DEFAULT, MAX_PARENTS, MERGESET_LIMIT   # noqa: E402
from r8c_sim import Mundo, LAMBDA, DELTA                                    # noqa: E402


def bs_chain(d, tip):
    """[(bid, blue_score)] de genesis a tip. blue_score es ESTRICTAMENTE creciente:
    blue_score(C) = blue_score(sp) + |mergeset_blues(C)| y mergeset_blues siempre
    contiene a sp (ghostdag.rs:115-120), luego el incremento es >= 1."""
    return [(b, d.gd[b].blue_score) for b in d.selected_chain(tip)]


def ancla_bs(d, tip, T):
    """R-FIN-1 (tercer ancla): PRIMER bloque de la cadena seleccionada con
    blue_score >= T. Devuelve su `seed` (estructural) o None si la cadena no llega."""
    for b in d.selected_chain(tip):
        if d.gd[b].blue_score >= T:
            return d.B[b].seed
    return None


def ancla_bs_bid(d, tip, T):
    for b in d.selected_chain(tip):
        if d.gd[b].blue_score >= T:
            return b
    return None


_VCOUNT = [0]


def wH(d, visibles, mundo):
    """w_H = score del bloque virtual del nodo honesto con la vista `visibles`.
    Se construye el virtual con `pick_virtual_parents` (el mismo _padres del
    simulador de D9-c) y se retira despues; el DAG queda intacto."""
    padres = mundo._padres(d, visibles)
    _VCOUNT[0] += 1
    vid = f"__virt{_VCOUNT[0]}"
    ok, motivo = d.add(vid, padres, t=0.0, creator="h", ident=None, sd=0, seed=0)
    if not ok:
        return None
    s = d.gd[vid].blue_score
    del d.B[vid]; del d.anc[vid]; del d.gd[vid]
    d.n -= 1
    return s


def llega_de(mundo, d, est=None, copias=0):
    """Reconstruye el instante en que el nodo honesto VE cada bloque, a partir del
    calendario del mundo y de la estrategia (r8c_sim.py `corre`): honesto -> t+DELTA;
    atacante (adversario del paper, sin retardo) -> t + retraso."""
    est = est or {}
    ll = {"G": 0.0}
    for i, (t, quien, sd, sde, ident) in enumerate(mundo.ev):
        bid = f"b{i}"
        if bid not in d.B:
            continue
        if quien == "h":
            ll[bid] = t + DELTA
        else:
            retraso, _pol = est.get(i, (0.0, "tips"))
            if retraso is None:
                continue
            ll[bid] = t + retraso
            for c in range(copias):
                cid = f"b{i}c{c}"
                if cid in d.B:
                    ll[cid] = t + retraso
    return ll
