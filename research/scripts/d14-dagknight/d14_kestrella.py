#!/usr/bin/env python3
"""
d14_kestrella.py — Punto 3a: mide k* (minimo k con k-cluster >= 50 % del DAG) sobre el DAG de
ZEROX generado con el instrumento importado r8c_sim (adversario del paper, sin retardo) y
colorado con r8c_gd. Rejilla: lambda=1, alpha en {0,10; 0,25; 0,33; 0,40}, Delta en {1,4,16,20},
12 semillas. T=400 s. Se mide tambien k* sobre prefijos (estabilidad) y la cobertura a k=0.
"""
import multiprocessing as mp
import os
import sys

_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, _DIR)

ALPHAS = [0.10, 0.25, 0.33, 0.40]
DELTAS = [1.0, 4.0, 16.0, 20.0]
SEMILLAS = [11, 23, 37, 41, 59, 67, 73, 89, 97, 101, 113, 127]
T = 400.0


def _tarea(args):
    alpha, delta, seed = args
    import d14_lib  # noqa: F401  (fija sys.path)
    import r8c_sim
    from r8c_sim import Mundo
    from d14_lib import cobertura_replay

    r8c_sim.LAMBDA = 1.0
    r8c_sim.DELTA = delta
    m = Mundo(alpha=alpha, T=T, seed=seed)
    d, tip = m.corre()
    bl = [(bid, d.B[bid].parents, d.B[bid].t, d.B[bid].creator) for bid in d.B]

    def k_de(bloques, kmax=40):
        for k in range(kmax + 1):
            if cobertura_replay(bloques, k) >= 0.5:
                return k
        return None

    k_final = k_de(bl)
    cob0 = cobertura_replay(bl, 0)
    # estabilidad: prefijos por tiempo
    pref = [b for b in bl if b[0] == "G" or b[2] <= 200.0]
    pref2 = [b for b in bl if b[0] == "G" or b[2] <= 300.0]
    k_200 = k_de(pref)
    k_300 = k_de(pref2)
    return (alpha, delta, seed, k_final, cob0, k_200, k_300, len(bl))


def main():
    tareas = [(a, dd, s) for a in ALPHAS for dd in DELTAS for s in SEMILLAS]
    with mp.Pool(processes=min(16, os.cpu_count() or 4)) as pool:
        res = pool.map(_tarea, tareas, chunksize=1)
    print("=" * 100)
    print("k* ZEROX — lambda=1, T=400 s, adversario del paper (sin retardo), 12 semillas")
    print("k* = minimo k con cobertura >= 50 % (replay r8c_gd sobre el DAG de r8c_sim)")
    print("=" * 100)
    print(f"{'alpha':>6} {'Delta':>6} | {'k*(400) por semilla':<52} {'media':>6} {'k*(200)':>8} {'k*(300)':>8} {'cob(k=0)':>9}")
    for a in ALPHAS:
        for dd in DELTAS:
            filas = [r for r in res if r[0] == a and r[1] == dd]
            ks = [r[3] for r in filas]
            k2 = [r[5] for r in filas]
            k3 = [r[6] for r in filas]
            c0 = [r[4] for r in filas]
            med = sum(ks) / len(ks)
            print(f"{a:>6.2f} {dd:>6.1f} | {str(ks):<52} {med:>6.2f} "
                  f"{sum(k2)/len(k2):>8.2f} {sum(k3)/len(k3):>8.2f} {sum(c0)/len(c0):>9.3f}")
    # guardar crudo
    with open(os.path.join(_DIR, "salida_kestrella_crudo.txt"), "w") as f:
        f.write("alpha delta seed k400 cob0 k200 k300 n\n")
        for r in res:
            f.write(" ".join(str(x) for x in r) + "\n")


if __name__ == "__main__":
    main()
