#!/usr/bin/env python3
"""
F · Entrega: **qué `k` y qué `lambda` publicar para cada `Δ_p99` que se mida.**

Criterio, explícito: se elige el **menor `k` cuyo `Δ_max` con 2 puntos de colchón sobre el
33 % (C.2) cubre el extremo superior del rango de `Δ_p99`**, porque todo lo que `k` compra se
paga en `F_carrera` (3k), en coloreado y en padres (D). `Δ_max(k)` es monótona creciente y
está medida en 7 puntos de `k`; entre ellos se interpola linealmente y se REDONDEA HACIA
ARRIBA al siguiente `k` medido, para no recomendar un `k` que no se ha medido.

Se reporta para cada rango: `k` con `lambda = 1`, `k` con `lambda = 1/2`, y el coste de cada uno.
CRITERIO ALPHA: los `Δ_max` vienen de C.2, cuyas tablas barren alpha.
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
RANGOS = [(4.0, 8.0), (8.0, 12.0), (12.0, 16.0), (16.0, 20.0), (20.0, 24.0)]


def k_minimo(dmax_por_k, objetivo):
    """Menor k MEDIDO con Delta_max >= objetivo. None si ninguno llega."""
    for k in sorted(dmax_por_k):
        v = dmax_por_k[k]
        if np.isfinite(v) and v >= objetivo:
            return k
    return None


if __name__ == "__main__":
    t0 = time.time()
    dat = json.load(open(os.path.join(AQUI, "c1_delta0.json")))
    ent = json.load(open(os.path.join(AQUI, "c2_deltamax.json")))
    coste, KS = dat["coste"], dat["ks"]
    D0 = {float(lam): {int(k): {float(D): v for D, v in dd.items()}
                       for k, dd in kk.items()} for lam, kk in dat["delta0"].items()}
    DM = {}
    for key, v in ent.items():
        lam, k = key.split("|")
        DM.setdefault(float(lam), {})[int(k)] = v[0]        # v = [Delta_max 2p, Delta_max 0p]
    DM0 = {}
    for key, v in ent.items():
        lam, k = key.split("|")
        DM0.setdefault(float(lam), {})[int(k)] = v[1]

    print("=== F · qué k y qué lambda publicar para cada Delta_p99 medido ===\n")

    print("--- F.1 · Delta_max con 2 puntos de colchon sobre el 33 %, por k (de C.2) ---")
    print(f"{'k':>5} | {'lambda = 1':>12} {'lambda = 1/2':>14} | {'sin colchon, lam=1':>19}")
    for k in KS:
        print(f"{k:>5} | {DM[1.0][k]:>10.1f} s {DM[0.5][k]:>12.1f} s | "
              f"{DM0[1.0][k]:>17.1f} s")

    print("\n--- F.2 · LA RECOMENDACION ---")
    print(f"{'Delta_p99':>12} | {'k (lam=1)':>10} {'Delta_max':>10} {'GB/ano':>8} "
          f"{'F_car 33%':>10} {'colorea/blq':>12} | {'k (lam=1/2)':>12} {'Delta_max':>10} "
          f"{'GB/ano':>8} {'latencia':>9}")
    for lo, hi in RANGOS:
        k1 = k_minimo(DM[1.0], hi)
        k2 = k_minimo(DM[0.5], hi)
        if k1 is None:
            s1 = f"{'>60 (no medido)':>10} {'':>10} {'':>8} {'':>10} {'':>12}"
        else:
            c = coste[f"1.0|{k1}|{min(16.0, hi)}"]
            gb = SEG_ANO * 1.0 * (R.BYTES_BASE + R.BYTES_PADRE * c["padres"]) / 1e9
            f33 = R.f_carrera_con(0.0, k1, alpha=0.33, I=R.I_DIS, lam=1.0)
            s1 = (f"{k1:>10} {DM[1.0][k1]:>8.1f} s {gb:>8.2f} {f33:>8.0f} s "
                  f"{c['n_bas']/c['n_blk']:>12.1f}")
        if k2 is None:
            s2 = f"{'>60 (no medido)':>12} {'':>10} {'':>8} {'':>9}"
        else:
            c2 = coste[f"0.5|{k2}|{min(16.0, hi)}"]
            gb2 = SEG_ANO * 0.5 * (R.BYTES_BASE + R.BYTES_PADRE * c2["padres"]) / 1e9
            s2 = f"{k2:>12} {DM[0.5][k2]:>8.1f} s {gb2:>8.2f} {2.0:>7.1f} s"
        print(f"{f'{lo:.0f}-{hi:.0f} s':>12} | {s1} | {s2}")

    print("\n--- F.3 · lo que se paga por ir del k del diseno (30) al k recomendado ---")
    print(f"{'k':>5} | {'GB/ano (D=16)':>14} {'vs k=30':>8} | {'colorea/blq (D=16)':>19} "
          f"{'vs k=30':>8} | {'F_car 33% d=0':>14} {'vs k=30':>8} | {'rev 600 s a=0,25':>17}")
    base = None
    for k in KS:
        c = coste[f"1.0|{k}|16.0"]
        gb = SEG_ANO * (R.BYTES_BASE + R.BYTES_PADRE * c["padres"]) / 1e9
        col = c["n_bas"] / c["n_blk"]
        f33 = R.f_carrera_con(0.0, k, alpha=0.33, I=R.I_DIS, lam=1.0)
        rev = A.prev(0.25, 1.0, 600, 3 * k, 1.0)
        if base is None:
            base = (gb, col, f33)
        print(f"{k:>5} | {gb:>14.2f} {gb/base[0]-1:>+7.2%} | {col:>19.1f} "
              f"{col/base[1]-1:>+7.2%} | {f33:>12.0f} s {f33/base[2]-1:>+7.2%} | {rev:>17.3e}")

    print("\n--- F.4 · el margen que da cada recomendacion sobre su rango ---")
    print(f"{'Delta_p99':>12} {'k':>5} | {'frontera a Delta = hi':>22} {'vs 33 %':>9} "
          f"| {'delta_0 a hi':>13}")
    for lo, hi in RANGOS:
        k1 = k_minimo(DM[1.0], hi)
        if k1 is None:
            continue
        d0 = R.interp(D0[1.0][k1], hi)
        fr = R.frontera_con(d0, k1, F=R.F_PROV, I=R.I_DIS, lam=1.0, paso=0.001)
        print(f"{f'{lo:.0f}-{hi:.0f} s':>12} {k1:>5} | {fr:>21.4%} {fr-0.33:>+8.2%} "
              f"| {d0:>13.4f}")
    print(f"\n[{time.time()-t0:.0f} s]")
