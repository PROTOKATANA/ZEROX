#!/usr/bin/env python3
"""
r11a_lib.py — capa fina de la ronda 11a. NO reimplementa ningun instrumento.

Reutiliza SIN REESCRIBIR (regla 11 del metodo: parametrizar importando):
  * `r9a_a3_frontera.prev()`      (= d8_a1c_riesgo.py:29-40 = verif_constantes.py:44-50)
  * `r9a_a3_frontera.union10()`   y `A.K`, `A.F_SEG`, `A.I_EP`, `A.EP_ANO` como globales
  * `r10b_lib.{set_F_I, set_ventaja, union_lam, f_carrera, frontera_gruesa, r_base}`
  * `r9a_lib.{MundoL9, contabilidad}` y el patron de medida de `r9a_a1b_control.py`
    (parche declarado `d8_lib.DELTA`, alpha = 0, 12 semillas, horizonte 1 800 s, ventana
    (60, T-60], maniobra parasita J=31) — aqui ademas con `k` y `lambda` como parametros.

Lo UNICO copiado (y no importado) es `kopt`, de `research/scripts/verif_tau_vs_lambda.py:16-30`:
se copia literalmente y solo se le sacan dos constantes cableadas a parametros —
`D` (era global `D = 4.0`, L11) y el techo del barrido (era `range(6, 80)`, L19)— porque
con `D >= 20 s` el punto fijo cae fuera de 80 y el original no podria contestar. La formula,
los criterios (`lr <= 2*lam`, `k >= k_Poisson(2*D*lr, 1e-3)`, minimizar `prev(0,25, lr, 600,
3k, 1-dr)`) y `prev()` mismo son los del original, importado como `V`.

R-FIN-12 (`consensus/core/src/config/bps.rs:56-85` de rusty-kaspa @ c338d495):
    max_block_parents  = clamp(k // 2, 10, 16)
    mergeset_size_limit = clamp(2*k, 180, 512)
"""
import io
import os
import sys

_AQUI = os.path.dirname(os.path.abspath(__file__))
_SCR = os.path.normpath(os.path.join(_AQUI, ".."))
for _p in (_SCR, os.path.join(_SCR, "d9-ronda9a"), os.path.join(_SCR, "d9-ronda10b")):
    if _p not in sys.path:
        sys.path.insert(0, _p)

import numpy as np                                              # noqa: E402
from scipy.stats import poisson                                 # noqa: E402
from scipy.optimize import brentq                               # noqa: E402

import r9a_a3_frontera as A                                     # noqa: E402
import r10b_lib as L                                            # noqa: E402
from r9a_lib import MundoL9, contabilidad                       # noqa: E402
import d8_lib                                                   # noqa: E402
import r8c_sim                                                  # noqa: E402
from r8c_gd import DAG                                          # noqa: E402

# ---- constantes del diseno vigente (dag-poas-ancla-de-orden.md:156) ----
I_DIS = 4200.0        # I = 4 200 s, medido (ancla-de-orden.md:110)
F_PROV = 7200.0       # F = 2 h PROVISIONAL, DECIDIDO por Katana (ancla-de-orden.md:156)
UMBRAL = 0.33         # umbral operativo publicado (ancla-de-orden.md:156)
BYTES_BASE = 683 - 4 * 32     # cabecera de 683 B con 4 padres (ancla-de-orden.md:424)
BYTES_PADRE = 32              # 32 B por padre (ancla-de-orden.md:424)


# =======================================================================================
# R-FIN-12 — bps.rs:56-85
# =======================================================================================
def max_block_parents(k):
    """bps.rs:57-72: val = k/2 (entera); <10 -> 10; >16 -> 16."""
    val = k // 2
    return 10 if val < 10 else (16 if val > 16 else val)


def mergeset_size_limit(k):
    """bps.rs:75-85: val = 2k; <180 -> 180; >512 -> 512."""
    val = 2 * k
    return 180 if val < 180 else (512 if val > 512 else val)


# =======================================================================================
# EL PUNTO FIJO k*(D, lambda) — copia literal de verif_tau_vs_lambda.py:16-30
# con `D` y el techo del barrido como parametros (justificado en el docstring).
# =======================================================================================
def kopt(lam, D, kmax=400):
    """optimo autoconsistente: k >= k_Poisson(2*D*lam_real, 1e-3) y lam_real <= 2*lam.

    `verif_tau_vs_lambda` se importa AQUI y no arriba porque su cuerpo de modulo imprime su
    propia tabla y tarda 13 s: solo se paga cuando de verdad se usa `prev()` del original.
    """
    import contextlib
    with contextlib.redirect_stdout(io.StringIO()):
        import verif_tau_vs_lambda as V          # prev() del original, sin tocar
    best = None
    for k in range(6, kmax):
        if k <= 2 * D * lam:
            continue
        lr = k * lam / (k - 2 * D * lam)
        if lr > 2 * lam:
            continue                       # demasiado cerca del polo: no es punto de operacion
        kp = next(kk for kk in range(1, 5000) if poisson.sf(kk, 2 * D * lr) < 1e-3)
        if k < kp:
            continue                       # punto fijo del retarget (ronda 3)
        dr = 2 * D * lr / (k + 2 * D * lr)
        p = V.prev(0.25, lr, 600, 3 * k, 1 - dr)     # prev() del original, sin tocar
        if not np.isfinite(p):
            continue
        if best is None or p < best[1]:
            best = (k, p, dr, lr)
    return best


# =======================================================================================
# CONTADOR DE COSTE DE COLOREADO — subclase de r8c_gd.DAG, sin duplicar logica
# =======================================================================================
class DAGContado(DAG):
    """Cuenta el trabajo de GHOSTDAG sin reescribirlo: delega en `super()` y solo suma.

      n_chain  llamadas a `_check_with_chain_block` = bloques de cadena recorridos
               (protocol.rs:246-283, el bucle `loop`).
      n_bas    llamadas a `blue_anticone_size` = peers NO ancestros del candidato, que es
               el coste real (protocol.rs:205, una llamada por peer que cuenta).
      n_cand   candidatos evaluados (llamadas a `check_blue_candidate`).
      n_blk    bloques anadidos con exito.
    """

    def __init__(self, *a, **kw):
        super().__init__(*a, **kw)
        self.n_chain = 0
        self.n_bas = 0
        self.n_cand = 0
        self.n_blk = 0
        self.sum_padres = 0
        self.sum_mergeset = 0

    def _check_with_chain_block(self, *a, **kw):
        self.n_chain += 1
        return super()._check_with_chain_block(*a, **kw)

    def blue_anticone_size(self, *a, **kw):
        self.n_bas += 1
        return super().blue_anticone_size(*a, **kw)

    def check_blue_candidate(self, *a, **kw):
        self.n_cand += 1
        return super().check_blue_candidate(*a, **kw)

    def add(self, bid, parents, *a, **kw):
        ok, motivo = super().add(bid, parents, *a, **kw)
        if ok:
            self.n_blk += 1
            self.sum_padres += len(parents)
            self.sum_mergeset += self.gd[bid].mergeset_size()
        return ok, motivo


# =======================================================================================
# LA MEDIDA DE delta_0(Delta, k, lambda) — instrumento de r9a_a1b_control.py, parametrizado
# =======================================================================================
def mide(args):
    """(delta_red, k, lam, alpha, semilla) -> dict con delta_0 y los contadores de coste.

    Parches declarados, en tiempo de ejecucion y sin tocar ningun fichero ajeno:
      d8_lib.DELTA  <- delta_red     (igual que r9a_a1b_control.py:41)
      r8c_sim.LAMBDA <- lam          (tasa de creacion, r8c_sim.py:24 y :40)
      d8_lib.DAG    <- DAGContado    (subclase que solo cuenta)
    El horizonte se escala con 1/lam para que el numero de bloques sea el mismo.
    """
    delta_red, k, lam, alpha, sem = args
    d8_lib.DELTA = delta_red
    r8c_sim.LAMBDA = lam
    d8_lib.DAG = DAGContado
    hor = 1800.0 / lam
    m = MundoL9(alpha, hor, sem, k=k, mp=max_block_parents(k),
                msl=mergeset_size_limit(k))
    d, tip, llega = m.corre_l9(J=31, d_fork=1, giveup=None, modo="parasito")
    c = contabilidad(d, tip, llega, 60.0, hor - 60.0)
    c.update(delta_red=delta_red, k=k, lam=lam, alpha=alpha, sem=sem,
             n_chain=d.n_chain, n_bas=d.n_bas, n_cand=d.n_cand, n_blk=d.n_blk,
             padres=d.sum_padres / max(1, d.n_blk),
             mergeset=d.sum_mergeset / max(1, d.n_blk),
             raf=m.n_rafagas)
    return c


def interp(tabla, x):
    """Interpolacion lineal sobre los puntos MEDIDOS, saturando fuera (mismo criterio que
    `r9a_a3_frontera.delta_interp` y `r10b_b5_delta_red.d0_interp`)."""
    xs = sorted(tabla)
    if x <= xs[0]:
        return tabla[xs[0]]
    if x >= xs[-1]:
        return tabla[xs[-1]]
    for i in range(len(xs) - 1):
        if xs[i] <= x <= xs[i + 1]:
            w = (x - xs[i]) / (xs[i + 1] - xs[i])
            return tabla[xs[i]] + w * (tabla[xs[i + 1]] - tabla[xs[i]])


def frontera_con(d0, k, F=F_PROV, I=I_DIS, lam=1.0, paso=0.0005, lo=0.05, hi=0.499):
    """Frontera de flujo unico (union a 10 anos = 1e-10) con `delta` constante = d0 y
    ventaja inicial 3k. Mismo barrido de primer cruce que `r9a_a3_frontera.frontera`
    (la funcion NO es monotona por encima del punto r=1)."""
    L.set_F_I(F, I)
    L.set_ventaja(3 * k)
    f = lambda a: np.log10(max(L.union_lam(a, 1 - d0, lam), 1e-320)) + 10.0
    ant = None
    for a in np.arange(lo, hi + 1e-9, paso):
        v = f(a)
        if ant is not None and ant[1] < 0 <= v:
            return brentq(f, ant[0], a, xtol=1e-6)
        ant = (a, v)
    return hi if f(hi) >= 0 else float("nan")


def f_carrera_con(d0, k, alpha=UMBRAL, I=I_DIS, lam=1.0):
    """F minima (s) con union(10 anos) = 1e-10 a `alpha`, con delta = d0 y ventaja 3k."""
    L.set_ventaja(3 * k)
    return L.f_carrera(alpha, 1 - d0, lam=lam, I=I)


def delta_max_colchon(tabla_d0, k, colchon=0.02, F=F_PROV, I=I_DIS, lam=1.0,
                      lo=2.0, hi=40.0):
    """El Delta maximo con frontera >= UMBRAL + colchon. Barrido grueso 0,25 s + brentq.
    Devuelve nan si ni a `lo` se alcanza; `hi` si aguanta todo el rango medido."""
    obj = UMBRAL + colchon
    g = lambda D: frontera_con(interp(tabla_d0, D), k, F=F, I=I, lam=lam, paso=0.002) - obj
    if not np.isfinite(g(lo)) or g(lo) < 0:
        return float("nan")
    ant = (lo, g(lo))
    for D in np.arange(lo + 0.25, hi + 1e-9, 0.25):
        v = g(D)
        if not np.isfinite(v):
            return ant[0]
        if ant[1] >= 0 > v:
            return brentq(g, ant[0], D, xtol=0.01)
        ant = (D, v)
    return hi
