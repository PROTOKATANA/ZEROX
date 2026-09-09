#!/usr/bin/env python3
"""
C.2 · Tolerancia REAL de cada `k`: frontera de flujo unico a `F = 2 h` con el `delta_0(Delta, k,
lambda)` MEDIDO en C.1, `F_carrera(33 %)`, la `F` minima con 2 puntos de colchon, y el
**`Delta_max` que cada `k` tolera con 2 puntos de colchon sobre el 33 %**.

Instrumento: `r9a_a3_frontera.prev/union10` via `r10b_lib`, reutilizados SIN reescribir
(`r11a_lib.frontera_con` / `f_carrera_con` solo fijan `A.K = ventaja/3`, `A.F_SEG`, `A.I_EP`).
Constantes del diseno: `F = 2 h` PROVISIONAL e `I = 4 200 s` (`dag-poas-ancla-de-orden.md`:156,
:110). Se anade la columna con `I = 851 s` (la `I` que uso 10b) para poder comparar filas.

Identidad que se usa y que conviene decir en voz alta: la frontera es el PRIMER `alpha` con
`union(10 anos) = 1e-10`, luego **frontera >= 35 % <=> union(0,35) <= 1e-10 <=> F >= F_carrera(0,35)**.
Por eso «la F minima con 2 puntos de colchon» ES `F_carrera(35 %)`, y el `Delta_max` a `F = 2 h`
es el mayor `Delta` con `F_carrera(35 %) <= 7 200 s`. Se comprueba numericamente en la salida.

Regla 6 (cota != realidad): `r = alpha/((1-alpha)(1-delta_0))`. Donde `r >= 1` la formula de
`prev()` es una COTA VACUA (el recorte a `r^700` que D8 declaro) y la celda NO es un resultado.
CRITERIO ALPHA: la columna `r(0,33)` y la tabla final de `F_carrera(alpha)` barren alpha.
"""
import json
import os
import sys
import time
from multiprocessing import Pool

import numpy as np
from scipy.optimize import brentq

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import r11a_lib as R                                            # noqa: E402
import r10b_lib as L                                            # noqa: E402

AQUI = os.path.dirname(os.path.abspath(__file__))
COLCHON = 0.02                     # 2 puntos sobre el 33 %
PASO = 0.001


def celda(args):
    lam, k, D, d0 = args
    out = {"lam": lam, "k": k, "D": D, "d0": d0}
    out["r33"] = L.r_base(0.33, 1 - d0)
    out["r35"] = L.r_base(0.35, 1 - d0)
    out["fr2h"] = R.frontera_con(d0, k, F=R.F_PROV, I=R.I_DIS, lam=lam, paso=PASO)
    out["fr2h_I851"] = R.frontera_con(d0, k, F=R.F_PROV, I=851.0, lam=lam, paso=PASO)
    out["f33"] = R.f_carrera_con(d0, k, alpha=0.33, I=R.I_DIS, lam=lam)
    out["f35"] = R.f_carrera_con(d0, k, alpha=0.35, I=R.I_DIS, lam=lam)
    return out


def delta_max(tab, k, lam, objetivo):
    """Mayor Delta con F_carrera(objetivo) <= F_PROV, por barrido 0,1 s + brentq.
    `tab` es {Delta: delta_0} medido; entre puntos se interpola linealmente (mismo criterio
    que `r10b_b5_delta_red.d0_interp`)."""
    def g(D):
        d0 = R.interp(tab, D)
        if L.r_base(objetivo, 1 - d0) >= 1.0:
            return -1.0                       # cota vacua: no hay F que baste
        f = R.f_carrera_con(d0, k, alpha=objetivo, I=R.I_DIS, lam=lam)
        if not np.isfinite(f):
            return -1.0
        return R.F_PROV - f
    lo, hi = min(tab), max(tab)
    if g(lo) < 0:
        return float("nan")
    ant = (lo, g(lo))
    for D in np.arange(lo + 0.1, hi + 1e-9, 0.1):
        v = g(D)
        if ant[1] >= 0 > v:
            return brentq(g, ant[0], D, xtol=0.005)
        ant = (D, v)
    return hi


if __name__ == "__main__":
    t0 = time.time()
    dat = json.load(open(os.path.join(AQUI, "c1_delta0.json")))
    D0 = {float(lam): {int(k): {float(D): v for D, v in dd.items()}
                       for k, dd in kk.items()} for lam, kk in dat["delta0"].items()}
    KS, DELTAS, LAMS = dat["ks"], dat["deltas"], dat["lams"]

    print("=== C.2 · frontera, F_carrera y Delta_max con el delta_0 MEDIDO ===")
    print(f"F = {R.F_PROV:.0f} s (2 h, provisional), I = {R.I_DIS:.0f} s, ventaja inicial 3k, "
          f"objetivo union(10 anos) = 1e-10, umbral operativo 33 %, colchon {COLCHON:.0%}.\n",
          flush=True)

    tareas = [(lam, k, D, D0[lam][k][D]) for lam in LAMS for k in KS for D in DELTAS]
    with Pool(30) as p:
        res = p.map(celda, tareas, chunksize=1)
    C = {(r["lam"], r["k"], r["D"]): r for r in res}
    print(f"[{time.time()-t0:.0f} s de fronteras]\n", flush=True)

    for lam in LAMS:
        print(f"===== lambda = {lam} bloque/s =====")
        for k in KS:
            print(f"--- k = {k} (max_block_parents = {R.max_block_parents(k)}, "
                  f"mergeset_size_limit = {R.mergeset_size_limit(k)}, ventaja 3k = {3*k}) ---")
            print(f"{'Delta':>6} {'delta_0':>9} {'r(0,33)':>8} | {'frontera F=2h':>14} "
                  f"{'vs 33 %':>8} | {'F_carrera 33 %':>15} {'(h)':>6} | "
                  f"{'F min colchon 2 p':>18} {'(h)':>6}")
            for D in DELTAS:
                c = C[(lam, k, D)]
                if c["r33"] >= 1.0:
                    print(f"{D:>6.0f} {c['d0']:>9.4f} {c['r33']:>8.3f} | "
                          f"{'COTA VACUA (r>=1): ninguna F basta, la celda no es un resultado':>60}")
                    continue
                s33 = (f"{c['f33']:>13.0f} s {c['f33']/3600:>6.2f}"
                       if np.isfinite(c["f33"]) else f"{'sin cruce':>13}   {'':>6}")
                s35 = (f"{c['f35']:>16.0f} s {c['f35']/3600:>6.2f}"
                       if np.isfinite(c["f35"]) else f"{'sin cruce':>16}   {'':>6}")
                print(f"{D:>6.0f} {c['d0']:>9.4f} {c['r33']:>8.3f} | {c['fr2h']:>13.4%} "
                      f"{c['fr2h']-0.33:>+7.2%} | {s33} | {s35}")
            print()

    print("===== LA ENTREGA DE C: Delta_max por k, con 2 puntos de colchon sobre el 33 % =====")
    print("(Delta_max = mayor Delta con frontera >= 35 % a F = 2 h  <=>  F_carrera(35 %) <= 7 200 s)")
    print(f"{'lambda':>7} {'k':>4} | {'Delta_max colchon 2 p':>22} | {'Delta_max sin colchon':>22} "
          f"| {'frontera a Delta=4 s':>21} | {'delta_0 en Delta_max':>21}")
    ENTREGA = {}
    for lam in LAMS:
        for k in KS:
            tab = D0[lam][k]
            dm2 = delta_max(tab, k, lam, 0.35)
            dm0 = delta_max(tab, k, lam, 0.33)
            fr4 = C[(lam, k, 4.0)]["fr2h"]
            d0m = R.interp(tab, dm2) if np.isfinite(dm2) else float("nan")
            ENTREGA[(lam, k)] = (dm2, dm0)
            s2 = f"{dm2:>19.1f} s" if np.isfinite(dm2) else f"{'ninguno':>21}"
            s0 = f"{dm0:>19.1f} s" if np.isfinite(dm0) else f"{'ninguno':>21}"
            print(f"{lam:>7.2f} {k:>4} | {s2} | {s0} | {fr4:>20.4%} | {d0m:>21.4f}")
        print()

    print("--- comprobacion de la identidad 'frontera >= 35 % <=> F_carrera(35 %) <= F' ---")
    mal = 0
    for lam in LAMS:
        for k in KS:
            for D in DELTAS:
                c = C[(lam, k, D)]
                if c["r35"] >= 1.0:
                    continue
                a = (c["fr2h"] >= 0.35 - 1e-9)
                b = (np.isfinite(c["f35"]) and c["f35"] <= R.F_PROV + 1.0)
                if a != b:
                    mal += 1
                    print(f"   DISCREPA lam={lam} k={k} D={D}: frontera={c['fr2h']:.4%} "
                          f"F35={c['f35']:.0f}")
    print(f"   {'0 discrepancias' if mal == 0 else f'{mal} discrepancias'} "
          f"sobre {len(LAMS)*len(KS)*len(DELTAS)} celdas.\n")

    print("--- CRITERIO ALPHA: F_carrera(alpha) a lambda = 1, Delta = 20 s, por k ---")
    print(f"{'alpha':>6} | " + " ".join(f"{'k=%d' % k:>12}" for k in KS))
    for a in (0.0, 0.10, 0.25, 0.33, 0.35, 0.40):
        fila = []
        for k in KS:
            d0 = D0[1.0][k][20.0]
            if a > 0 and L.r_base(a, 1 - d0) >= 1.0:
                fila.append(f"{'r>=1':>12}")
                continue
            f = R.f_carrera_con(d0, k, alpha=a, I=R.I_DIS, lam=1.0) if a > 0 else 0.0
            fila.append(f"{f:>12.0f}" if np.isfinite(f) else f"{'sin cruce':>12}")
        print(f"{a:>6.2f} | " + " ".join(fila))

    json.dump({f"{lam}|{k}": list(v) for (lam, k), v in ENTREGA.items()},
              open(os.path.join(AQUI, "c2_deltamax.json"), "w"), indent=1)
    print(f"\n-> c2_deltamax.json escrito. [{time.time()-t0:.0f} s]")
