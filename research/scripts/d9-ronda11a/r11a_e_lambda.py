#!/usr/bin/env python3
"""
E · `lambda = 1/2` como alternativa a subir `k`. Misma tabla que C y D, y la pregunta del
encargo: **¿compra más tolerancia a `Δ` por unidad de coste que subir `k`?**

Lo que se compara, todo con números de esta ronda:
  tolerancia  `Delta_max` con 2 puntos de colchón sobre el 33 % (C.2, `c2_deltamax.json`).
  coste       GB/año de cabeceras (D.2, padres MEDIDOS), latencia `1/lambda`, coste de
              coloreado por bloque y por segundo (C.1), `F_carrera(33 %)` con `delta = 0`,
              y la **reversión a 600 s**, que es donde `lambda = 1/2` paga: la mitad de
              bloques en la misma ventana.
La rama (B) de `verif_tau_vs_lambda.py` (`lambda = 1/6`) perdía 7 órdenes de reversión a 600 s
frente a `lambda = 1` (4,31e-10 -> 1,26e-02). Aquí se mide lo que pierde `lambda = 1/2`.

Se añade la invariancia que C.1 hace evidente y que conviene decir con número:
`delta_0` depende de `Delta` y `lambda` **solo por el producto `2*Delta*lambda`**. Si es así,
`lambda = 1/2` duplica exactamente el `Delta` tolerado, ni más ni menos, y no es una palanca
independiente de `k`: es la misma palanca con otro nombre. Se contrasta celda a celda.

CRITERIO ALPHA: la tabla de reversión barre alpha, con la fila alpha = 0.
"""
import json
import os
import sys
import time

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import r11a_lib as R                                            # noqa: E402
import r9a_a3_frontera as A                                     # noqa: E402

AQUI = os.path.dirname(os.path.abspath(__file__))
SEG_ANO = 365 * 24 * 3600

if __name__ == "__main__":
    t0 = time.time()
    dat = json.load(open(os.path.join(AQUI, "c1_delta0.json")))
    ent = json.load(open(os.path.join(AQUI, "c2_deltamax.json")))
    D0 = {float(lam): {int(k): {float(D): v for D, v in dd.items()}
                       for k, dd in kk.items()} for lam, kk in dat["delta0"].items()}
    coste, KS, DELTAS = dat["coste"], dat["ks"], dat["deltas"]

    print("=== E · lambda = 1/2 frente a subir k ===\n")

    print("--- E.1 · ¿delta_0 depende solo de 2*Delta*lambda? (celda a celda) ---")
    print("    si lo hace, lambda = 1/2 duplica el Delta tolerado y NO es palanca nueva")
    print(f"{'2*D*lam':>8} {'k':>4} | {'lam=1 (Delta)':>15} {'delta_0':>9} | "
          f"{'lam=1/2 (Delta)':>16} {'delta_0':>9} | {'|dif|':>8}")
    difs = []
    for x in (8.0, 16.0, 24.0, 32.0, 40.0, 48.0, 64.0, 80.0):
        for k in (30, 45, 60):
            D1, D2 = x / 2.0, x / 1.0
            if D1 not in D0[1.0][k] or D2 not in D0[0.5][k]:
                continue
            a, b = D0[1.0][k][D1], D0[0.5][k][D2]
            difs.append(abs(a - b))
            print(f"{x:>8.0f} {k:>4} | {D1:>15.0f} {a:>9.4f} | {D2:>16.0f} {b:>9.4f} | "
                  f"{abs(a-b):>8.4f}")
    print(f"    -> diferencia maxima {max(difs):.4f}, media {sum(difs)/len(difs):.4f} "
          f"sobre {len(difs)} pares\n")

    print("--- E.2 · tolerancia por coste: las dos palancas en la misma tabla ---")
    print(f"{'lambda':>7} {'k':>4} | {'Delta_max 2p':>13} {'Delta_max 0p':>13} | "
          f"{'GB/ano':>8} {'latencia':>9} {'3k':>5} {'F_car 33% d=0':>14} "
          f"{'rev 600 s (a=0,25)':>19} {'colorea/blq':>12} {'colorea/s':>10}")
    filas = []
    for lam in (1.0, 0.5):
        for k in KS:
            dm2, dm0 = ent[f"{lam}|{k}"]
            c16 = coste[f"{lam}|{k}|16.0"]
            pa = c16["padres"]
            gb = SEG_ANO * lam * (R.BYTES_BASE + R.BYTES_PADRE * pa) / 1e9
            f33 = R.f_carrera_con(0.0, k, alpha=0.33, I=R.I_DIS, lam=lam)
            rev = A.prev(0.25, lam, 600, 3 * k, 1.0)
            col = c16["n_bas"] / c16["n_blk"]
            filas.append((lam, k, dm2, dm0, gb, f33, rev, col))
            print(f"{lam:>7.2f} {k:>4} | {dm2:>11.1f} s {dm0:>11.1f} s | {gb:>8.2f} "
                  f"{1/lam:>7.1f} s {3*k:>5} {f33:>12.0f} s {rev:>19.3e} "
                  f"{col:>12.1f} {col*lam:>10.1f}")
        print()

    print("--- E.3 · lo que paga lambda = 1/2 en reversion a 600 s (delta = 0, ventaja 3k) ---")
    print(f"{'alpha':>6} {'k':>4} | {'lam=1':>12} {'lam=1/2':>12} {'ordenes perdidos':>17} "
          f"| {'lam=1/6 (rama B)':>17}")
    for a in (0.0, 0.10, 0.25, 0.33, 0.35):
        for k in (30, 60):
            p1 = A.prev(a, 1.0, 600, 3 * k, 1.0)
            p2 = A.prev(a, 0.5, 600, 3 * k, 1.0)
            p6 = A.prev(a, 1 / 6, 600, 3 * k, 1.0)
            ordenes = (np.log10(p2) - np.log10(p1)) if (p1 > 0 and p2 > 0) else float("nan")
            print(f"{a:>6.2f} {k:>4} | {p1:>12.3e} {p2:>12.3e} {ordenes:>17.2f} "
                  f"| {p6:>17.3e}")
        print()
    print("    (alpha = 0: reversion 0 por construccion — no hay atacante)")

    print("--- E.4 · lo mismo con el delta_real(k) del retarget a Delta = 4 s ---")
    print(f"{'k':>4} | {'lam_obj=1: k*, delta, rev':>32} | {'lam_obj=1/2: k*, delta, rev':>32}")
    for lam in (1.0, 0.5):
        r = R.kopt(lam, 4.0, 120)
        if r is None:
            continue
        k, p, dr, lr = r
        print(f"{'':>4} | lambda_obj = {lam:.1f}: k* = {k}, delta_real = {dr:.4f}, "
              f"lambda_real = {lr:.3f}, rev 600 s = {p:.3e}")
    print(f"\n[{time.time()-t0:.0f} s]")
