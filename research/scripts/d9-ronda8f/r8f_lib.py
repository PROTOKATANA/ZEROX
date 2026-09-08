#!/usr/bin/env python3
"""
r8f_lib.py — EXTENSION de D9-c/D9-d/D9-e. No reescribe nada: importa el GHOSTDAG fiel
(`r8c_gd.py`, rusty-kaspa @ c338d495), el simulador de eventos (`r8c_sim.py`, adversario
del paper L1024-1027 sin retardo) y las lecturas de D9-d/D9-e, y anade SOLO lo que la
ronda 8f necesita:

  · `perfil(d, tip)`      UNA pasada por la cadena seleccionada que alimenta a la vez las
                          DOS anclas: `blue_score` (R-FIN-1 vigente) y `slot` (candidata).
  · `ancla_bs_T`          R-FIN-1: primer bloque de cadena con blue_score >= T.
  · `ancla_slot_T`        CANDIDATA: primer bloque de cadena con slot >= S.
                          Equivale a «el de MENOR blue_work entre los que tienen slot >= S»
                          porque (a) R-FIN-1a hace `slot` estrictamente creciente por la
                          cadena y (b) el Lema A4b de D9-e hace `blue_work` estrictamente
                          creciente por la cadena. Se COMPRUEBA, no se supone: `chequea_equiv`.
  · `slot_de(t, gran)`    `slot` = INDICE DE PoT (R-FIN-13), no sello de cabecera. En el
                          simulador el indice de PoT de un bloque creado en `t` es
                          floor(t/gran); `gran = 0` = continuo (PoT de grano fino).
                          R-FIN-7 usa `F` en slots con `F = 11 520` para `F = 3,2 h`, luego
                          en el diseno **1 slot = 1 s**: `gran = 1.0` es la lectura literal.
  · familias ANIDADAS de estrategias, parametrizadas, para medir SATURACION de `m`:
                          `fam(mundo, tP, ventana, retros, retrasos, retencion, copias)`.
                          Anidadas por construccion: subir cualquier parametro solo ANADE
                          estrategias, luego `m` es monotona no decreciente en cada uno.
  · `c_m`, `constantes`   el mapa `m -> (I, c, F)` de D9-d (`r8c_steering.py`), reimportado.

Criterio alpha: aqui no hay adversario, solo lectura y combinatoria; el adversario vive en
los scripts `r8f_a*.py` / `r8f_b*.py`, y todos declaran la fila `alpha = 0`.
"""
import math
import os
import sys

_D9C = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "d9-ronda8c"))
_D9D = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "d9-ronda8d"))
_D9E = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "d9-ronda8e"))
for _p in (_D9C, _D9D, _D9E):
    if _p not in sys.path:
        sys.path.insert(0, _p)

from r8c_gd import DAG, K_DEFAULT, MAX_PARENTS, MERGESET_LIMIT     # noqa: E402,F401
from r8c_sim import Mundo, LAMBDA, DELTA                           # noqa: E402
from r8c_steering import c_interp                                  # noqa: E402

K, MP = 30, 15
BANDA = 10            # 21 umbrales, igual que D9-d/D9-e
HOR = 260.0
S_MAX = 150           # R-FIN-1a, cota superior del salto de slot


# --------------------------------------------------------------------------------------
# LECTURA — una sola pasada alimenta las dos anclas
# --------------------------------------------------------------------------------------
def slot_de(t, gran=1.0):
    """Indice de PoT del bloque creado en `t`. gran<=0 => PoT continuo (grano fino)."""
    return t if gran <= 0 else math.floor(t / gran)


def perfil(d, tip, gran=1.0):
    """[(blue_score, slot, seed, bid, blue_work)] de la cadena seleccionada, de genesis a tip.
    `seed` es ESTRUCTURAL (fijado en la creacion, r8c_sim.py): renombrar no lo altera."""
    return [(d.gd[b].blue_score, slot_de(d.B[b].t, gran), d.B[b].seed, b, d.gd[b].blue_work)
            for b in d.selected_chain(tip)]


def ancla_bs_T(pf, T):
    """R-FIN-1 vigente: PRIMER bloque de cadena con blue_score >= T. Devuelve (seed, idx)."""
    for i, (bs, sl, sd, b, bw) in enumerate(pf):
        if bs >= T:
            return sd, i
    return None, None


def ancla_slot_T(pf, S):
    """CANDIDATA (Parte B): PRIMER bloque de cadena con slot >= S. Devuelve (seed, idx)."""
    for i, (bs, sl, sd, b, bw) in enumerate(pf):
        if sl >= S:
            return sd, i
    return None, None


def ancla_slot_minbw(pf, S):
    """La forma LITERAL del enunciado: el de MENOR blue_work entre los de slot >= S.
    Se calcula por separado para poder CONTRASTARLA con `ancla_slot_T` (chequea_equiv)."""
    cands = [(bw, i, sd) for i, (bs, sl, sd, b, bw) in enumerate(pf) if sl >= S]
    if not cands:
        return None, None
    bw, i, sd = min(cands)
    return sd, i


def chequea_equiv(pf, Ss):
    """Devuelve (n_comprobaciones, n_discrepancias) entre `ancla_slot_T` y `ancla_slot_minbw`.
    Si n_comprobaciones == 0 la comprobacion NO CORRIO: la fila no dice nada."""
    n = disc = 0
    for S in Ss:
        a, ia = ancla_slot_T(pf, S)
        b, ib = ancla_slot_minbw(pf, S)
        if a is None and b is None:
            continue
        n += 1
        if a != b or ia != ib:
            disc += 1
    return n, disc


def banda_bs(d, tip, T):
    """Lema B1: blue_score(ancla) - T. Debe caer en [0, k]. Devuelve None si no hay ancla."""
    for b in d.selected_chain(tip):
        if d.gd[b].blue_score >= T:
            return d.gd[b].blue_score - T
    return None


# --------------------------------------------------------------------------------------
# FAMILIAS ANIDADAS DE ESTRATEGIAS
# --------------------------------------------------------------------------------------
RETROS = [1, 2, 4, 8, 16, 32, 64, 128, 256]


def pols_hasta(D):
    """['sp'] + retro r para r <= D. ANIDADA en D por construccion."""
    return ["sp"] + [("retro", r) for r in RETROS if r <= D]


def idx_ventana(mundo, tP, W):
    """Indices de eventos del ATACANTE en +-W s de tP. ANIDADA en W."""
    return [i for i, (t, q, *_) in enumerate(mundo.ev) if q == "a" and tP - W <= t <= tP + W]


def fam(mundo, tP, W=30.0, D=4, retrasos=(), retencion=False, por_bloque=True):
    """Familia dirigida ANIDADA. Devuelve lista de (estrategia, copias=None) — las copias
    se pasan aparte porque cambian el mundo, no la estrategia.

    Nesting: W' >= W, D' >= D, retrasos' ⊇ retrasos, retencion' >= retencion  =>  familia ⊇.
    """
    idx = idx_ventana(mundo, tP, W)
    pols = pols_hasta(D)
    ests = [{}]
    for pol in pols:                                   # global
        ests.append({i: (0.0, pol) for i in idx})
    if por_bloque:                                     # bloque a bloque
        for i in idx:
            for pol in pols:
                ests.append({i: (0.0, pol)})
    for r in retrasos:                                 # +retraso
        ests.append({i: (r, "tips") for i in idx})
        for pol in pols:
            ests.append({i: (r, pol) for i in idx})
    if retencion:                                      # +retencion (nunca publicar)
        ests.append({i: (None, "tips") for i in idx})
        for i in idx:
            for pol in ["tips"] + pols:
                for r in (0.0, 4.0, 12.0):
                    e = {j: (None, "tips") for j in idx}
                    e[i] = (r, pol)
                    ests.append(e)
    return ests, idx


# --------------------------------------------------------------------------------------
# STEERING — el mapa m -> (I, c, F). Identico a D9-d A5 (r8c_steering.py + informe L297).
# --------------------------------------------------------------------------------------
G_TECHO = 0.036          # techo de steering de la propuesta
WK_TECHO = 1.22          # W/kappa = 1 + I/F <= 1,22  (BDK+19 §2)


def constantes(m, alpha, lam=1.0, g=G_TECHO, wk=WK_TECHO, lam_azul=0.97):
    """I = (c_m/g)^2/(alpha*lam);  F = I/(wk-1);  c = I*lam_azul (azules) o I (slots)."""
    cm = c_interp(m)
    I = (cm / g) ** 2 / (alpha * lam) if alpha > 0 else 0.0
    F = I / (wk - 1.0)
    return cm, I, F, I * lam_azul
