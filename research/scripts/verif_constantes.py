#!/usr/bin/env python3
"""
Reconstrucción (tras el reinicio del 2026-09-08) de los tres cálculos que fijan las constantes del
DAG sobre PoAS. Fórmulas y valores esperados están en los informes commiteados:
  research/dag-poas-ancla-de-finalidad-metaauditoria.md  (§7, §10 quinquies)
  research/dag-poas-ancla-de-orden.md                     (§1.1)

  1. phi_c de BDK+19 (arXiv 1910.02218v3, §5.4 ec. 39; Tabla 3 con Delta=0).
  2. La ec. (2) de GHOSTDAG descompuesta en sus dos términos (cola de Poisson vs merma del Lema 9).
  3. El óptimo autoconsistente de k: delta(k) = 2c/(k+2c), ventaja inicial 3k (Lema 10),
     carrera de Nakamoto con crecimiento honesto (1-alpha)(1-delta).
"""
import math
import numpy as np
from scipy.optimize import brentq
from scipy.stats import poisson, skellam

# ---------- 1 · phi_c (BDK+19 ec. 39) ----------
def phi(c):
    if c <= 1:
        return math.e
    f = lambda t: (-math.log(-t) - (c - 1) * math.log(1 - t)) - (-1 + (c - 1) * t / (1 - t))
    t = brentq(f, -1e6, -1e-9, maxiter=500)
    return -c * t / (math.log(-t) + (c - 1) * math.log(1 - t))

TABLA3 = [math.e, 2.22547, 2.01030, 1.88255, 1.79545, 1.73110, 1.68103, 1.64060, 1.60705, 1.57860]
print("1 · phi_c contra la Tabla 3 de BDK+19 (Delta = 0)")
ok = all(abs(phi(c) - TABLA3[c - 1]) < 5e-5 for c in range(1, 11))
print(f"   10 valores reproducidos con error < 5e-5: {ok}")
for c in (16, 50, 500):
    print(f"   phi_{c} = {phi(c):.4f}   1/(1+phi) = {1/(1+phi(c)):.1%}   (16 -> el 1,47 de Chia)")

# ---------- 2 · ec. (2) de GHOSTDAG ----------
C = 4.0 * 1.0                       # Dmax * lambda, con Dmax = 4 s, lambda = 1 bloque/s
t1 = lambda k: poisson.sf(k, 2 * C)  # P(anticono > k)
t2 = lambda k: 2 * C / (k + 2 * C)   # merma del Lema 9
k1 = next(k for k in range(1, 5000) if t1(k) < 0.01)
k2 = next(k for k in range(1, 5000) if t2(k) < 0.01)
print("\n2 · ec. (2): max{ cola de Poisson , 2c/(k+2c) } < delta = 0,01")
print(f"   solo el término de probabilidad exige k = {k1}")
print(f"   solo el término de merma exige     k = {k2}   <- de aquí sale el 793")

# ---------- 3 · óptimo autoconsistente de k ----------
def prev(a, lam, t, offset, hf):
    mh = (1 - a) * lam * t * hf; ma = a * lam * t; r = a / ((1 - a) * hf)
    ds = np.arange(-400, 6000); p = skellam.pmf(ds, mh, ma); d = ds - offset
    with np.errstate(over="ignore"):
        catch = np.where(d >= 0, np.power(r, np.minimum(d + 1.0, 700)), 1.0)
    return float(np.sum(p * catch))

print("\n3 · óptimo de k con delta(k) autoconsistente y ventaja 3k (alpha = 0,25, t = 600 s)")
best = min(range(10, 60), key=lambda k: prev(0.25, 1.0, 600, 3 * k, 1 - 2 * C / (k + 2 * C)))
for k in (18, 24, 25, 30, 793):
    d = 2 * C / (k + 2 * C)
    print(f"   k={k:4d}  delta={d:.3f}  reversión(600 s)={prev(0.25, 1.0, 600, 3*k, 1-d):.2e}" + ("   <- ÓPTIMO" if k == best else ""))
print(f"   lineal de ZEROX (q=120) a 600 s: {prev(0.25, 1/120, 600, 0, 1.0):.3e}")
print(f"   óptimo del barrido: k = {best}")
