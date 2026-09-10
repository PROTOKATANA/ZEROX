#!/usr/bin/env python3
"""
d14_fp.py — Punto fijo del k adaptativo: la topologia del DAG depende del color (blue_work fija
el sp), y el color adaptativo depende de la topologia. Se itera:

    k_{n+1} = k*(DAG generado con color k_n),  k*(D) = min k con cobertura >= 50 %

hasta que k se estabiliza. Se mide tambien la cobertura a varios k y el numero de iteraciones.
"""
import os
import sys

_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, _DIR)


def k_estrella_de_dag(d, kmax=40):
    import d14_lib
    from d14_lib import cobertura_replay
    bl = [(bid, d.B[bid].parents, d.B[bid].t, d.B[bid].creator) for bid in d.B]
    cob = {}
    for k in range(kmax + 1):
        c = cobertura_replay(bl, k)
        cob[k] = c
        if c >= 0.5:
            return k, cob
    return None, cob


def punto_fijo(alpha, delta, seed, T=400.0, kmax=40, iters=6):
    import d14_lib  # noqa: F401  (fija sys.path antes de r8c_sim)
    import r8c_sim
    from r8c_sim import Mundo
    r8c_sim.LAMBDA = 1.0
    r8c_sim.DELTA = delta
    k = 30
    hist = []
    for _ in range(iters):
        m = Mundo(alpha=alpha, T=T, seed=seed, k=k)
        d, tip = m.corre()
        k_new, cob = k_estrella_de_dag(d, kmax)
        hist.append((k, k_new))
        if k_new is None or k_new == k:
            return k_new, hist, d
        k = k_new
    return k, hist, d


if __name__ == "__main__":
    casos = [(0.10, 1.0), (0.10, 4.0), (0.10, 16.0), (0.10, 20.0),
             (0.25, 4.0), (0.25, 16.0), (0.25, 20.0),
             (0.33, 20.0), (0.40, 20.0)]
    print("=" * 90)
    print("PUNTO FIJO del k adaptativo — lambda=1, T=400, seed=11")
    print("=" * 90)
    for a, dd in casos:
        kf, hist, d = punto_fijo(a, dd, 11)
        print(f"alpha={a:>4} Delta={dd:>4}: historial k -> k* = {hist}  | punto fijo k*={kf}")
