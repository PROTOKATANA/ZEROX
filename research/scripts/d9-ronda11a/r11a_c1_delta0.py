#!/usr/bin/env python3
"""
C.1 · `delta_0(Delta, k, lambda)` MEDIDO con el instrumento de 9a (`r9a_a1b_control.py`,
via `r11a_lib.mide`), a `alpha = 0` y 12 semillas. NO la cola de Poisson: 9a midio que
sobreestima (a Delta = 16 s, k = 30 da 0,594 frente a 0,286 medido; `salida_a1b.txt`).

Rejilla: Delta cada 2 s de 2 a 32 s, mas 36 y 40 s (18 puntos);
         k in {30, 35, 40, 45, 50, 55, 60} (los cuatro del encargo mas tres intermedios,
         que no cuestan y hacen solida la interpolacion de Delta_max);
         lambda in {1, 1/2}; 12 semillas.
Cada k lleva SUS `max_block_parents` y `mergeset_size_limit` de R-FIN-12 (bps.rs:56-85):
subir k sin subir el tope de padres seria medir otra cosa.

CRITERIO ALPHA (regla 4): ademas de alpha = 0, un subgrid con alpha = 0,35 — si el numero
no cambiara al mover alpha, no seria una simulacion. Se imprime al final.
COBERTURA (regla 5): H, n_blk y `raf` (rafagas de la parasita) en cada fila.

Salida: `salida_c1.txt` (tabla legible) y `c1_delta0.json` (para C.2 y E, sin recalcular).
"""
import json
import os
import sys
import time
from multiprocessing import Pool

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import r11a_lib as R                                            # noqa: E402

AQUI = os.path.dirname(os.path.abspath(__file__))
SEMS = list(range(1, 13))
DELTAS = [2.0, 4.0, 6.0, 8.0, 10.0, 12.0, 14.0, 16.0, 18.0, 20.0,
          22.0, 24.0, 26.0, 28.0, 30.0, 32.0, 36.0, 40.0]
KS = [30, 35, 40, 45, 50, 55, 60]
LAMS = [1.0, 0.5]
ALPHA_CTRL = 0.35
KS_CTRL = [30, 60]
DELTAS_CTRL = [4.0, 12.0, 20.0, 32.0]


def agrega(res, campos):
    """Media por campo, y `delta` como COCIENTE DE MEDIAS sum(R)/sum(H) — que es como lo
    agrega `r9a_a1b_control.py:78-84` (`g['R']/g['H']`), no como media de cocientes.
    ERROR PROPIO CORREGIDO: la primera version promediaba `r['delta']` y salia 0,0824 donde
    9a publica 0,0828 (Delta = 12 s). Diferencia <= 0,0006, pero el control A.2 no pasaba."""
    n = len(res)
    g = {c: sum(r[c] for r in res) / n for c in campos}
    g["delta"] = (g["R"] / g["H"]) if g["H"] else 0.0
    return g


if __name__ == "__main__":
    t0 = time.time()
    tareas = [(D, k, lam, 0.0, s)
              for lam in LAMS for k in KS for D in DELTAS for s in SEMS]
    tareas += [(D, k, lam, ALPHA_CTRL, s)
               for lam in LAMS for k in KS_CTRL for D in DELTAS_CTRL for s in SEMS]
    print("=== C.1 · delta_0(Delta, k, lambda) medido, alpha = 0, 12 semillas ===")
    print(f"instrumento: r9a_a1b_control.py (MundoL9, maniobra parasita J=31, u3=dynamic), "
          f"ventana (60, T-60], horizonte 1800/lambda s.")
    print(f"{len(tareas)} corridas ({len(DELTAS)} Delta x {len(KS)} k x {len(LAMS)} lambda x "
          f"{len(SEMS)} semillas, mas el control de alpha).\n", flush=True)
    with Pool(30) as p:
        res = p.map(R.mide, tareas, chunksize=4)
    print(f"[{time.time()-t0:.0f} s de simulacion]\n", flush=True)

    CAMPOS = ["H", "R", "Ablue", "Apub", "Wpub", "delta", "padres", "mergeset",
              "n_chain", "n_bas", "n_cand", "n_blk", "raf"]
    por = {}
    for r in res:
        por.setdefault((r["lam"], r["k"], r["delta_red"], r["alpha"]), []).append(r)
    agg = {kk: agrega(v, CAMPOS) for kk, v in por.items()}

    tabla = {}
    for lam in LAMS:
        print(f"--- lambda = {lam} b/s, alpha = 0 ---")
        print(f"{'Delta':>6} {'2*D*lam':>8} | " +
              " ".join(f"{'k=%d' % k:>8}" for k in KS) +
              f" | {'H(k=30)':>8} {'pad(k=30)':>10} {'pad(k=60)':>10}")
        for D in DELTAS:
            fila = []
            for k in KS:
                g = agg[(lam, k, D, 0.0)]
                fila.append(f"{g['delta']:>8.4f}")
                tabla.setdefault(f"{lam}", {}).setdefault(str(k), {})[str(D)] = g["delta"]
            g30 = agg[(lam, 30, D, 0.0)]
            g60 = agg[(lam, 60, D, 0.0)]
            print(f"{D:>6.0f} {2*D*lam:>8.1f} | " + " ".join(fila) +
                  f" | {g30['H']:>8.0f} {g30['padres']:>10.2f} {g60['padres']:>10.2f}")
        print()

    print("--- COBERTURA y coste de coloreado (alpha = 0, lambda = 1) ---")
    print(f"{'Delta':>6} {'k':>4} | {'n_blk':>7} {'padres':>7} {'mergeset':>9} "
          f"{'cadena/blq':>11} {'blue_ant/blq':>13} {'cand/blq':>9}")
    for D in (4.0, 12.0, 20.0, 32.0):
        for k in KS:
            g = agg[(1.0, k, D, 0.0)]
            print(f"{D:>6.0f} {k:>4} | {g['n_blk']:>7.0f} {g['padres']:>7.2f} "
                  f"{g['mergeset']:>9.2f} {g['n_chain']/g['n_blk']:>11.2f} "
                  f"{g['n_bas']/g['n_blk']:>13.2f} {g['n_cand']/g['n_blk']:>9.2f}")
        print()

    print(f"--- CRITERIO ALPHA: mismo instrumento con alpha = {ALPHA_CTRL} ---")
    print(f"{'lambda':>7} {'Delta':>6} {'k':>4} | {'delta_0 (a=0)':>14} "
          f"{'delta (a=0,35)':>15} {'rafagas':>8} {'Wpub/H':>8}")
    for lam in LAMS:
        for D in DELTAS_CTRL:
            for k in KS_CTRL:
                g0 = agg[(lam, k, D, 0.0)]
                ga = agg[(lam, k, D, ALPHA_CTRL)]
                print(f"{lam:>7.2f} {D:>6.0f} {k:>4} | {g0['delta']:>14.4f} "
                      f"{ga['delta']:>15.4f} {ga['raf']:>8.1f} {ga['Wpub']/ga['H']:>8.4f}")
    print("\n(si delta no cambiara con alpha, no seria una simulacion: regla 4)")

    with open(os.path.join(AQUI, "c1_delta0.json"), "w") as f:
        json.dump({"delta0": tabla,
                   "coste": {f"{lam}|{k}|{D}": agg[(lam, k, D, 0.0)]
                             for lam in LAMS for k in KS for D in DELTAS},
                   "deltas": DELTAS, "ks": KS, "lams": LAMS, "sems": len(SEMS)},
                  f, indent=1)
    print(f"\n-> c1_delta0.json escrito. [{time.time()-t0:.0f} s]")
