#!/usr/bin/env python3
"""
r10c_c2_frontera.py — PUNTO C (segunda parte) y entrada del punto D.

Dos magnitudes que SI dependen de `F`:
  · `F_carrera(alpha, I, modelo)` = la `F` minima con union a 10 anos < 1e-10 (el termino que
    la auditoria 8c llama `F_carrera` en `F = max(F_carrera, I/(W/kappa - 1))`);
  · la frontera de flujo unico (el mayor `alpha` que aguanta) para cada pareja (F, I).

Instrumento: `frontera`/`union10` de `d9-ronda9a/r9a_a3_frontera.py` SIN TOCAR, exactamente como
`research/scripts/verif_frontera_vs_F.py` del agente principal. Control: reproducir 46,8784 % y
36,5431 % con F = 19 080 s, I = 4 200 s (ya hecho en r10c_c0_control.py P3; se repite aqui).

Criterio alpha: la frontera ES un alpha; y `F_carrera` cambia con alpha por construccion.
"""
import os
import sys
import time

import numpy as np
from scipy.optimize import brentq

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import r10c_lib as L  # noqa: E402

IS = [491.0, 602.0, 851.0, 4200.0]
FS = [(1224.0, "0,34 h"), (3600.0, "1 h"), (3868.0, "1,07 h (pinza rho=3)"),
      (7200.0, "2 h"), (19080.0, "5,3 h")]
ALPHAS_OBJ = [0.33, 0.35, 0.40]


def frontera_de(F, I, hf):
    L.union10(0.30, 1.0, F, I)          # fija los globales F_SEG/I_EP de 9a
    return L.A9.frontera(hf)


def f_carrera(alpha, I, hf, lo=30.0, hi=400000.0):
    """F minima con union a 10 anos < 1e-10, a I fija."""
    def g(F):
        return np.log10(max(L.union10(alpha, hf(alpha), F, I), 1e-320)) + 10.0
    if g(hi) >= 0:
        return float("inf")
    if g(lo) < 0:
        return lo
    return brentq(g, lo, hi, xtol=1.0)


t0 = time.time()
print("=" * 104)
print("CONTROL · frontera con F = 19 080 s, I = 4 200 s (9a publica 46,8784 % y 36,5431 %)")
f0 = frontera_de(19080.0, 4200.0, lambda a: 1.0)
fD = frontera_de(19080.0, 4200.0, lambda a: 1 - L.delta_interp(a))
print(f"   delta = 0: {f0:.4%}  {'OK' if abs(f0-0.468784) < 5e-4 else 'DISCREPA'} · "
      f"delta D8: {fD:.4%}  {'OK' if abs(fD-0.365431) < 5e-4 else 'DISCREPA'}   [{time.time()-t0:.0f} s]",
      flush=True)

print()
print("=" * 104)
print("C2a · F_carrera: la F minima que exige la CARRERA (union 10 anos < 1e-10)")
print("=" * 104)
print(f"{'I (s)':>7} {'alpha objetivo':>15} | {'F_carrera d=0 (s)':>18} {'(h)':>7} | "
      f"{'F_carrera D8 (s)':>17} {'(h)':>7}", flush=True)
for I in IS:
    for a in ALPHAS_OBJ:
        f1 = f_carrera(a, I, L.hf_delta0)
        f2 = f_carrera(a, I, L.hf_d8)
        s1 = "inf" if f1 == float("inf") else f"{f1:.0f}"
        s2 = "inf" if f2 == float("inf") else f"{f2:.0f}"
        h1 = "inf" if f1 == float("inf") else f"{f1/3600:.2f}"
        h2 = "inf" if f2 == float("inf") else f"{f2/3600:.2f}"
        print(f"{I:>7.0f} {a:>15.2f} | {s1:>18} {h1:>7} | {s2:>17} {h2:>7}", flush=True)

print()
print("=" * 104)
print("C2b · FRONTERA de flujo unico (mayor alpha con union 10 anos < 1e-10) para cada (F, I)")
print("     Acortar F BAJA la frontera: es el precio de seguridad de una F corta.")
print("=" * 104)
print(f"{'F':>22} {'I (s)':>7} | {'frontera d=0':>13} {'frontera D8':>12} | "
      f"{'union alpha=0,33 d=0':>21} {'D8':>11}", flush=True)
for F, nomF in FS:
    for I in (491.0, 851.0):
        t = time.time()
        fr0 = frontera_de(F, I, lambda a: 1.0)
        frD = frontera_de(F, I, lambda a: 1 - L.delta_interp(a))
        u0 = L.union10(0.33, 1.0, F, I)
        uD = L.union10(0.33, L.hf_d8(0.33), F, I)
        print(f"{nomF:>22} {I:>7.0f} | {fr0:>13.2%} {frD:>12.2%} | {u0:>21.2e} {uD:>11.2e}"
              f"   [{time.time()-t:.0f} s]", flush=True)
print(f"\n[total {time.time()-t0:.0f} s]")
