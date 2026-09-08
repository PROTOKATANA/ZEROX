#!/usr/bin/env python3
"""
B.2 · La palanca `k`. `F_carrera` para k in {20, 25, 30, 40}, en los modelos de `delta` que
tienen `k` dentro y en el que no lo tiene.

Tres modelos, y hay que separarlos porque solo dos son k-coherentes:

 (i)  `delta = 0` (el de 9a): `k` entra SOLO por la ventaja inicial `3k`. lambda = 1.
 (ii) `delta_real(k)` del sesgo del retarget (`research/dag-poas-delta-real.md` §1, tabla L26-33):
        lambda_real = k*lambda_obj/(k - 2*D*lambda_obj)     (D = 4 s, lambda_obj = 1/s)
        delta_real  = 2*D*lambda_real/(k + 2*D*lambda_real)
      k-coherente en `delta`, en `lambda` Y en la ventaja. Se controla contra la tabla publicada
      (k=25 -> 1,471/0,320; k=30 -> 1,364/0,267; k=40 -> 1,250/0,200) antes de usarla.
      Y se comprueba el punto fijo del retarget: k >= k_Poisson(2*D*lambda_real, 1e-3).
 (iii) `delta` de D8 (`r9a_a3_frontera.MED`): MEDIDA A k = 30 y solo a k = 30
      (`d8-ronda8/salida_a1b.txt`). NO es k-coherente: usarla con otro k es una LAGUNA declarada.
      Se reporta igualmente, con la etiqueta puesta, porque es el modelo pesimista que la
      bitacora publica.

CRITERIO ALPHA: todas las tablas llevan la fila alpha = 0 o barren alpha.
"""
import time

import numpy as np
from scipy.stats import poisson

import r10b_lib as L
import r9a_a3_frontera as A

D = 4.0
KS = [20, 25, 30, 40]
PUB = {25: (1.471, 0.320), 30: (1.364, 0.267), 40: (1.250, 0.200)}   # delta-real.md L30-33


def lam_real(k):
    return k * 1.0 / (k - 2 * D * 1.0)


def delta_real(k):
    lr = lam_real(k)
    return 2 * D * lr / (k + 2 * D * lr)


def k_poisson(k):
    """k minimo que la cola de Poisson exige a la tasa real (dag-poas-delta-real.md §1)."""
    return next(kk for kk in range(1, 500) if poisson.sf(kk, 2 * D * lam_real(k)) < 1e-3)


if __name__ == "__main__":
    t0 = time.time()
    print("=== B.2 · la palanca k ===")
    print("CONTROL del modelo (ii) contra dag-poas-delta-real.md L30-33:")
    for k in (25, 30, 40):
        lr, dr = lam_real(k), delta_real(k)
        ok = abs(lr - PUB[k][0]) < 1e-3 and abs(dr - PUB[k][1]) < 1e-3
        print(f"   k={k}: lambda_real={lr:.3f} (pub {PUB[k][0]}), delta_real={dr:.3f} "
              f"(pub {PUB[k][1]})  {'OK' if ok else 'DIFIERE'}")

    print(f"\n--- (i) delta = 0 (modelo de 9a): k entra solo por la ventaja 3k. I = {L.I_DIS:.0f} s ---")
    print(f"{'k':>4} {'3k':>5} | {'F_carrera 33 %':>16} {'(h)':>6} | {'35 %':>10} {'(h)':>6}")
    for k in KS:
        L.set_ventaja(3 * k)
        f33 = L.f_carrera(0.33, 1.0); f35 = L.f_carrera(0.35, 1.0)
        print(f"{k:>4} {3*k:>5} | {f33:>14.0f} s {f33/3600:>6.2f} | {f35:>8.0f} s {f35/3600:>6.2f}")

    print("\n--- (ii) delta_real(k) y lambda_real(k) autoconsistentes (k-coherente) ---")
    print(f"{'k':>4} {'lam_real':>9} {'delta_real':>11} {'k_Poisson':>10} {'admisible':>10} "
          f"| {'F_carrera 33 %':>16} {'(h)':>6} | {'35 %':>12} {'(h)':>6} | {'r(0,33)':>8}")
    for k in KS:
        lr, dr, kp = lam_real(k), delta_real(k), k_poisson(k)
        adm = "SI" if k >= kp else "NO"
        L.set_ventaja(3 * k)
        r33 = L.r_base(0.33, 1 - dr)
        f33 = L.f_carrera(0.33, 1 - dr, lam=lr)
        f35 = L.f_carrera(0.35, 1 - dr, lam=lr)
        print(f"{k:>4} {lr:>9.3f} {dr:>11.3f} {kp:>10} {adm:>10} | {f33:>14.0f} s {f33/3600:>6.2f} "
              f"| {f35:>10.0f} s {f35/3600:>6.2f} | {r33:>8.3f}")

    print("\n--- (iii) delta de D8 (medida SOLO a k=30): LAGUNA fuera de k=30 ---")
    print(f"{'k':>4} {'delta(0,33)':>12} {'delta(0,35)':>12} | {'F_carrera 33 %':>16} {'(h)':>6} "
          f"| {'35 %':>12} {'(h)':>6}")
    for k in KS:
        L.set_ventaja(3 * k)
        d33, d35 = A.delta_interp(0.33), A.delta_interp(0.35)
        f33 = L.f_carrera(0.33, 1 - d33); f35 = L.f_carrera(0.35, 1 - d35)
        marca = "  <- k de la medida" if k == 30 else "  <- LAGUNA (delta no recalibrada)"
        print(f"{k:>4} {d33:>12.4f} {d35:>12.4f} | {f33:>14.0f} s {f33/3600:>6.2f} "
              f"| {f35:>10.0f} s {f35/3600:>6.2f}{marca}")

    print("\n--- criterio alpha en el modelo (ii), k = 30 ---")
    lr, dr = lam_real(30), delta_real(30)
    L.set_ventaja(90)
    print(f"{'alpha':>6} {'r':>7} {'F_carrera (s)':>14}")
    for a in (0.0, 0.10, 0.25, 0.33, 0.35, 0.40):
        f = L.f_carrera(a, 1 - dr, lam=lr)
        print(f"{a:>6.2f} {(L.r_base(a,1-dr) if a>0 else 0):>7.3f} {f:>14.0f}")
    print(f"\n[{time.time()-t0:.0f} s]")
