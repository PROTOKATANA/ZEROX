#!/usr/bin/env python3
"""
r9a_a1b_control.py — CONTROL POSITIVO de la contabilidad de A1 (regla 4).

A1 midio `R/Ablue <= 1` en las 37 maniobras y los 9 alphas, incluidos alpha = 0,55 y 0,70.
Un resultado que NUNCA cruza el umbral es sospechoso: hay que demostrar que el instrumento
PUEDE medir R/Ablue > 1 y Wpub/H < 1. Aqui se construye ese caso.

Mecanismo: subir `Delta`. Con anticono honesto ~ Poisson(2*Delta*lambda), en cuanto
2*Delta*lambda se acerca a k = 30 los bloques honestos se vuelven rojos ENTRE ELLOS, sin que
el atacante gaste un solo bloque: R > 0 con Ablue = 0, luego R/Ablue = infinito y Wpub/H < 1.
Es la unica fuente de `delta` que NO cuesta bloques del atacante — y es un parametro de RED,
no una palanca del adversario del paper (L1024-1027: no puede retrasar honesto<->honesto por
encima de Dmax). Sirve por tanto a la vez de control positivo y de respuesta a
"el delta que el atacante SI puede imponer gratis".

`Delta` se parchea en el modulo d8_lib EN TIEMPO DE EJECUCION (d8_lib.DELTA), sin tocar el
fichero (regla 11). Se declara aqui explicitamente.
"""
import sys
import time
from multiprocessing import Pool

sys.path.insert(0, "/home/katana/zeo/ZEROX/research/scripts/d9-ronda9a")
from r9a_lib import MundoL9, contabilidad, K                    # noqa: E402
import d8_lib                                                   # noqa: E402  (r9a_lib ya puso su ruta en sys.path)
from scipy.stats import poisson                                 # noqa: E402

SEMS = list(range(1, 13))
DELTAS = [4.0, 8.0, 12.0, 16.0, 20.0, 24.0, 32.0]
ALPHAS = [0.00, 0.35]
HOR = 1800.0


def una(args):
    delta_red, alpha, sem = args
    d8_lib.DELTA = delta_red            # parche declarado
    m = MundoL9(alpha, HOR, sem, k=K, mp=15)
    d, tip, llega = m.corre_l9(J=31, d_fork=1, giveup=None, modo="parasito")
    c = contabilidad(d, tip, llega, 60.0, HOR - 60.0)
    c["raf"] = m.n_rafagas
    return (delta_red, alpha, c)


if __name__ == "__main__":
    tareas = [(dr, a, s) for dr in DELTAS for a in ALPHAS for s in SEMS]
    print("=== A1b · control positivo: que la contabilidad SI puede ver R/Ablue > 1 ===")
    print(f"k={K}, lambda=1, mp=15, u3=dynamic, horizonte {HOR:.0f} s, {len(SEMS)} semillas, "
          f"maniobra = parasita J=31.\n")
    t0 = time.time()
    with Pool(24) as p:
        res = p.map(una, tareas, chunksize=2)
    print(f"[{time.time()-t0:.0f} s]\n")
    por = {}
    for dr, a, c in res:
        por.setdefault((dr, a), []).append(c)
    print(f"{'Delta':>6} {'2*D*lam':>8} {'P(Poi>k)':>10} {'alpha':>6} | {'H':>6} {'R':>6} "
          f"{'Ablue':>6} | {'delta_0 medido':>14} {'R/Ablue':>9} {'Wpub/H':>7} {'raf':>5}")
    for dr in DELTAS:
        for a in ALPHAS:
            rs = por[(dr, a)]
            n = len(rs)
            g = {kk: sum(r[kk] for r in rs) / n for kk in rs[0]}
            rab = (g["R"] / g["Ablue"]) if g["Ablue"] else float("inf")
            print(f"{dr:>6.0f} {2*dr:>8.0f} {poisson.sf(K, 2*dr):>10.2e} {a:>6.2f} | "
                  f"{g['H']:>6.0f} {g['R']:>6.1f} {g['Ablue']:>6.1f} | "
                  f"{g['R']/g['H']:>14.4f} {rab:>9.3f} "
                  f"{g['Wpub']/g['H']:>7.4f} {g['raf']:>5.1f}")
        print()
    print("LECTURA: si a Delta grande y alpha=0 sale R>0 con Ablue=0 (R/Ablue = inf, "
          "Wpub/H < 1),\nel instrumento SI detecta lo que A1 no encontro, y el 'R/Ablue <= 1' "
          "de A1 es un hallazgo, no una ceguera.")
