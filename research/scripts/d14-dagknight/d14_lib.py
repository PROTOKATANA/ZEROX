#!/usr/bin/env python3
"""
d14_lib.py — Instrumento de D14A (DAGKNIGHT sobre el DAG de PoAS).

IMPORTA, no copia, los instrumentos de las rondas anteriores (patron de d9-ronda8d/r8d_lib.py:1-30):
  · r8c_gd.py   — GHOSTDAG fiel a rusty-kaspa @ c338d495. Aqui se usa como COLORADOR REPLAY:
                  se le da una topologia ya fijada y se colorea con k variable.
  · r8c_sim.py  — generador de eventos y adversario del paper. Aqui se usa para producir el DAG
                  de ZEROX con la seleccion de padres real (pick_virtual_parents, R-FIN-12).
  · r9a_a3_frontera.py — `prev()` (Skellam + carrera), para el margen de reversion m(alpha, eps).

Definiciones propias (documentadas):
  · k*  = minimo k tal que el k-cluster (coloracion GHOSTDAG) cubre >= 50 % del DAG sin genesis.
          Es el "Minimal k Majority Cluster" de dagknight.txt:114-119 y el pie 9 de :804-805.
  · UMC = cobertura de mayoria uniforme; aqui se aproxima por la cobertura global >= 50 %
          (simplificacion declarada: el paper exige mayoria del future de cada miembro, :709-719).
  · El colorador por bitsets es una version VORAZ del k-cluster, solo para exploracion rapida;
          los numeros que se publican salen del replay fiel en r8c_gd.

Modelo del paper (control positivo):
  · creacion Poisson de tasa lambda; bloque del atacante con prob. alpha.
  · honesto creado en s es visible a los honestos en s + D; el atacante ve todo al instante
    (dagknight.txt:312-327) y publica sus bloques en t (modo 'instant') o todos al final (modo
    'oculto', el "invisible, secret attacker" de :195-197).
  · cada bloque referencia TODAS las puntas visibles (dagknight.txt:907-910).

NO se modifica ningun fichero de otras rondas.
"""
import os
import random
import sys

_DIR = os.path.dirname(os.path.abspath(__file__))
_D9C = os.path.normpath(os.path.join(_DIR, "..", "d9-ronda8c"))
_D9A = os.path.normpath(os.path.join(_DIR, "..", "d9-ronda9a"))
for _p in (_D9C, _D9A):
    if _p not in sys.path:
        sys.path.insert(0, _p)

from r8c_gd import DAG as GD_DAG  # noqa: E402
import r8c_sim  # noqa: E402
from r8c_sim import Mundo  # noqa: E402
import r9a_a3_frontera as A9  # noqa: E402

prev = A9.prev  # reversion con ventaja inicial `offset` (bloques) tras t segundos

GEN = "G"


# =============================================================================================
# 1 · Modelo del paper (control positivo)
# =============================================================================================
def genera_eventos(lam, alpha, T, seed):
    """Calendario fijo: lista de (t, quien). Numeros aleatorios comunes (patron r8c_sim.Mundo)."""
    rng = random.Random(seed)
    ev = []
    t = 0.0
    while True:
        t += rng.expovariate(lam)
        if t > T:
            break
        ev.append((t, "a" if rng.random() < alpha else "h"))
    return ev


def _tips(visibles, padres_de):
    ref = set()
    for b in visibles:
        ref.update(padres_de[b])
    return sorted(visibles - ref)


def construye_paper(ev, D, modo):
    """Devuelve [(bid, padres, t, creador)] en orden topologico.

    modo: 'oculto' (atacante invisible a los honestos hasta el final, se publica al final),
          'instant' (el atacante publica al instante; lo ven todos).
    El atacante ve todo al instante en ambos modos (dagknight.txt:321-327).
    """
    bloques = [(GEN, tuple(), 0.0, "g")]
    padres_de = {GEN: tuple()}
    vis_h = {GEN: 0.0}          # instante en que un honesto lo ve
    for i, (t, quien) in enumerate(ev):
        bid = f"b{i}"
        if quien == "h":
            vis = {b for b in padres_de if vis_h[b] <= t}
            padres = tuple(_tips(vis, padres_de))
        else:
            padres = tuple(_tips(set(padres_de), padres_de))   # ve todo al instante
        bloques.append((bid, padres, t, quien))
        padres_de[bid] = padres
        vis_h[bid] = t + D if quien == "h" else (t if modo == "instant" else float("inf"))
    return bloques


# =============================================================================================
# 2 · Coloracion voraz por bitsets (exploracion rapida)
# =============================================================================================
def _mascaras(bloques):
    idx = {b[0]: i for i, b in enumerate(bloques)}
    n = len(bloques)
    past = [0] * n
    for i, (bid, ps, t, c) in enumerate(bloques):
        m = 0
        for p in ps:
            m |= past[idx[p]] | (1 << idx[p])
        past[i] = m
    children = [[] for _ in range(n)]
    for i, (bid, ps, t, c) in enumerate(bloques):
        for p in ps:
            children[idx[p]].append(i)
    future = [0] * n
    for i in range(n - 1, -1, -1):
        m = 0
        for j in children[i]:
            m |= (1 << j) | future[j]
        future[i] = m
    return idx, past, future


def _blues_bitset(bloques, k):
    idx, past, future = _mascaras(bloques)
    blue = 0
    for i in range(len(bloques)):
        anti = blue & ~(past[i] | future[i] | (1 << i))
        if bin(anti).count("1") <= k:
            blue |= 1 << i
    return blue


def cobertura_bitset(bloques, k):
    blue = _blues_bitset(bloques, k)
    total = len(bloques) - 1
    nb = bin(blue).count("1") - 1          # sin genesis
    return nb / total


def k_estrella_bitset(bloques, k_max=60, frac=0.5):
    for k in range(k_max + 1):
        c = cobertura_bitset(bloques, k)
        if c >= frac:
            return k, c
    return None, cobertura_bitset(bloques, k_max)


# =============================================================================================
# 3 · Replay fiel en r8c_gd (instrumento importado)
# =============================================================================================
def replay_gd(bloques, k):
    """Colorea la topologia dada con r8c_gd.DAG(k). Devuelve (d, tip)."""
    d = GD_DAG(k=k, u2=False, u3_mode="off", max_parents=10 ** 9, mergeset_limit=10 ** 9)
    d.genesis(GEN)
    for bid, ps, t, c in bloques[1:]:
        ok, mot = d.add(bid, list(ps), t=t, creator=c, ident=None, sd=0, seed=0, enforce=False)
        if not ok:
            raise AssertionError(f"replay rechazo {bid}: {mot}")
    tip = d.virtual_sp()
    return d, tip


def cobertura_replay(bloques, k):
    d, tip = replay_gd(bloques, k)
    nb = len(d.blueset(tip) - {GEN})
    return nb / (len(bloques) - 1)


def k_estrella_replay(bloques, k_max=60, frac=0.5):
    """Primer k con cobertura >= frac. Devuelve (k, cobertura)."""
    for k in range(k_max + 1):
        c = cobertura_replay(bloques, k)
        if c >= frac:
            return k, c
    return None, cobertura_replay(bloques, k_max)


# =============================================================================================
# 4 · Margen de reversion m(alpha, eps)
# =============================================================================================
def margen_paseo(alpha, eps):
    """Bloques de ventaja honesta para que P(alcance del atacante) <= eps: r^m <= eps,
    r = alpha/(1-alpha). Cota clasica del block race (Nakamoto); es el mecanismo del `offset`
    de prev() (r9a_a3_frontera.py:37-49)."""
    import math
    if alpha <= 0:
        return 0
    if alpha >= 0.5:
        return None
    return int(math.ceil(math.log(eps) / math.log(alpha / (1 - alpha))))


def margen_prev(alpha, eps, t_max=7200.0, lam=1.0, hf=1.0, margen_min=0):
    """Offset minimo tal que prev(alpha, lam, t_max, offset, hf) <= eps (paso 1)."""
    off = int(margen_min)
    while prev(alpha, lam, t_max, off, hf) > eps and off < 100000:
        off += 1
    return off
