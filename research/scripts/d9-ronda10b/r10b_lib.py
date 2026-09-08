#!/usr/bin/env python3
"""
r10b_lib.py — la capa fina de la ronda 10b. NO reimplementa nada.

Reutiliza SIN REESCRIBIR:
  * `r9a_a3_frontera.prev()`   (= d8_a1c_riesgo.py:29-40 = verif_constantes.py:44-50)
  * `r9a_a3_frontera.union10()` cuando lambda = 1 (el caso del diseno)
  * `r9a_a3_frontera.delta_interp()` (la `delta` pesimista de D8)
y el patron de barrido grueso + brentq de `verif_frontera_vs_F.py`.

Dos aclaraciones sobre variables globales del modulo de 9a, porque se manipulan aqui:
  - `A.F_SEG`, `A.I_EP`, `A.EP_ANO`: F y el numero de epocas por ano (EP_ANO = 365*86400/I).
  - `A.K`: en `union10()` **solo** aparece como `3*A.K`, es decir, la VENTAJA INICIAL del Lema 10.
    Para estudiar la palanca «ventaja» (B.1) se fija `A.K = ventaja/3`: no cambia el `k` fisico
    del protocolo (que no entra en `prev()`), solo el desplazamiento de la carrera.

`union_lam()` es `A.union10` con `lambda` explicito: identica formula
(`A.prev(a, lam, F, 3*A.K, hf) * EP_ANO * ANOS`), necesaria porque `A.union10` cablea lam = 1
y el modelo `delta_real(k)` de `dag-poas-delta-real.md` §1 infla la tasa a `lambda_real`.
"""
import sys

sys.path.insert(0, "/home/katana/zeo/ZEROX/research/scripts/d9-ronda9a")
import r9a_a3_frontera as A                                            # noqa: E402
import numpy as np                                                     # noqa: E402
from scipy.optimize import brentq                                      # noqa: E402

OBJ = 1e-10          # objetivo de riesgo: union a 10 anos
ANOS = 10.0
I_DIS = 851.0        # I del diseno usado en la tabla de la bitacora §11.4


def set_F_I(F, I):
    A.F_SEG = float(F)
    A.I_EP = float(I)
    A.EP_ANO = 365 * 24 * 3600 / A.I_EP


def set_ventaja(v):
    """La ventaja inicial de la carrera (Lema 10). union10 la lee como 3*A.K."""
    A.K = v / 3.0


def union_lam(a, hf, lam=1.0):
    """A.union10 con lambda explicito. Misma formula, mismo prev()."""
    return min(1.0, A.prev(a, lam, A.F_SEG, 3 * A.K, hf) * A.EP_ANO * ANOS)


def f_carrera(alpha, hf, lam=1.0, I=I_DIS, obj=OBJ, lo=1.0, hi=200000.0):
    """F minima (s) con union(10 anos) = obj. `prev` DECRECE con F (el deficit crece), asi que
    la funcion es monotona y brentq basta. Devuelve nan si no hay cruce en [lo, hi]."""
    def g(F):
        set_F_I(F, I)
        return np.log10(max(union_lam(alpha, hf, lam), 1e-320)) - np.log10(obj)
    try:
        if g(lo) < 0:
            return 0.0                     # ya cumple con F = 1 s: el suelo no lo pone la carrera
        if g(hi) > 0:
            return float("nan")            # no se cumple ni con F = hi
        return brentq(g, lo, hi, xtol=0.5)
    except ValueError:
        return float("nan")


def frontera_gruesa(hf_de_alpha, lo=0.20, hi=0.499, paso=0.005):
    """IDENTICA a verif_frontera_vs_F.frontera_gruesa (primer cruce; la funcion NO es monotona
    en alpha por encima del punto r=1)."""
    f = lambda a: np.log10(max(A.union10(a, hf_de_alpha(a)), 1e-320)) + 10.0
    ant = None
    for a in np.arange(lo, hi + 1e-9, paso):
        v = f(a)
        if ant is not None and ant[1] < 0 <= v:
            return brentq(f, ant[0], a, xtol=1e-5)
        ant = (a, v)
    return float("nan")


def r_base(a, hf):
    """r = alpha/((1-alpha)*hf). Si r >= 1 la carrera no tiene deriva a favor del honesto y
    NINGUNA F basta (la cota se vuelve vacua)."""
    return a / ((1 - a) * hf)
