#!/usr/bin/env python3
"""
d14_d8.py — Punto 6 (D8 propio): ¿puede el atacante inflar k* y congelar la confirmacion?

Estrategias del atacante sobre el MISMO calendario (numeros aleatorios comunes, r8c_sim):
  instant     — publica al instante (adversario del paper, control)
  retraso20   — todos sus bloques salen 20 s tarde
  retraso60   — 60 s tarde
  burst300    — todos retenidos hasta t=300 s
  parasita5   — cuelga de un ancestro de cadena 5 posiciones atras (cadena parásita)
  retro500    — cuelga de 500 posiciones atras (cadena desconectada)

Se mide k*_hon (cluster mayoritariamente honesto que cubre >= 50 % de los honestos) sobre el DAG
completo y sobre el prefijo t<=200 (sostenibilidad). El suelo adaptativo bajo ataque es
3*k*_hon/((1-alpha)*lambda); el baseline es 3*30/((1-alpha)*lambda).
"""
import multiprocessing as mp
import os
import sys

_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, _DIR)

ALPHAS = [0.10, 0.25, 0.40]
DELTAS = [1.0, 4.0, 16.0, 20.0]
SEMILLAS = [11, 23, 37, 41, 59, 67, 73, 89, 97, 101, 113, 127]
ESTRATEGIAS = ["instant", "retraso20", "retraso60", "burst300", "parasita5", "retro500"]
T = 400.0


def _k_hon(bloques, kmax=60):
    import d14_lib
    from d14_lib import replay_gd, GEN
    H = {b[0] for b in bloques if b[3] == "h"}
    for k in range(kmax + 1):
        d, tip = replay_gd(bloques, k)
        blue = d.blueset(tip) - {GEN}
        bh = blue & H
        if len(bh) >= 0.5 * len(blue) and len(bh) >= 0.5 * len(H):
            return k, len(bh) / len(H)
    return None, None


def _estrategia(m, nombre):
    at = [(i, e) for i, e in enumerate(m.ev) if e[1] == "a"]
    if nombre == "instant":
        return {}
    if nombre == "retraso20":
        return {i: (20.0, "tips") for i, _ in at}
    if nombre == "retraso60":
        return {i: (60.0, "tips") for i, _ in at}
    if nombre == "burst300":
        return {i: (max(0.0, 300.0 - e[0]), "tips") for i, e in at}
    if nombre == "parasita5":
        return {i: (0.0, ("retro", 5)) for i, _ in at}
    if nombre == "retro500":
        return {i: (0.0, ("retro", 500)) for i, _ in at}
    raise ValueError(nombre)


def _tarea(args):
    alpha, delta, seed, nombre = args
    import d14_lib  # noqa: F401
    import r8c_sim
    from r8c_sim import Mundo

    r8c_sim.LAMBDA = 1.0
    r8c_sim.DELTA = delta
    m = Mundo(alpha=alpha, T=T, seed=seed)
    d, tip = m.corre(estrategia=_estrategia(m, nombre))
    bl = [(bid, d.B[bid].parents, d.B[bid].t, d.B[bid].creator) for bid in d.B]
    k_full, cob = _k_hon(bl)
    pre = [b for b in bl if b[0] == "G" or b[2] <= 200.0]
    k_pre, _ = _k_hon(pre, kmax=60)
    return (alpha, delta, seed, nombre, k_full, k_pre, cob)


def main():
    tareas = [(a, dd, s, e) for a in ALPHAS for dd in DELTAS for s in SEMILLAS
              for e in ESTRATEGIAS]
    with mp.Pool(processes=min(16, os.cpu_count() or 4)) as pool:
        res = pool.map(_tarea, tareas, chunksize=1)
    with open(os.path.join(_DIR, "salida_d8_crudo.txt"), "w") as f:
        f.write("alpha delta seed estrategia k_full k_pre cobH\n")
        for r in res:
            f.write(" ".join(str(x) for x in r) + "\n")

    def stats(v):
        v = [x for x in v if x is not None]
        if not v:
            return float("nan"), float("nan"), float("nan")
        return sum(v) / len(v), min(v), max(v)

    print("=" * 110)
    print("D8 — k*_hon bajo estrategias del atacante (12 semillas). Suelo adaptativo = 3*k*/((1-a)l)")
    print("=" * 110)
    print(f"{'alpha':>6} {'Delta':>6} | " +
          " ".join(f"{e:>13}" for e in ESTRATEGIAS))
    for a in ALPHAS:
        for dd in DELTAS:
            celdas = []
            for e in ESTRATEGIAS:
                ks = [r[4] for r in res if r[0] == a and r[1] == dd and r[3] == e]
                mm, mn, mx = stats(ks)
                celdas.append(f"{mm:>5.1f}[{mn},{mx}]")
            print(f"{a:>6.2f} {dd:>6.1f} | " + " ".join(f"{c:>13}" for c in celdas))
        print("-" * 110)

    print()
    print("=" * 110)
    print("SOSTENIBILIDAD: k*_hon en prefijo t<=200 (media[min,max])")
    print("=" * 110)
    print(f"{'alpha':>6} {'Delta':>6} | " +
          " ".join(f"{e:>13}" for e in ESTRATEGIAS))
    for a in ALPHAS:
        for dd in DELTAS:
            celdas = []
            for e in ESTRATEGIAS:
                ks = [r[5] for r in res if r[0] == a and r[1] == dd and r[3] == e]
                mm, mn, mx = stats(ks)
                celdas.append(f"{mm:>5.1f}[{mn},{mx}]")
            print(f"{a:>6.2f} {dd:>6.1f} | " + " ".join(f"{c:>13}" for c in celdas))

    print()
    print("=" * 110)
    print("SUELO bajo la peor estrategia por (alpha, Delta): 3*k*max/((1-a)l) vs baseline 3*30/((1-a)l)")
    print("=" * 110)
    for a in ALPHAS:
        for dd in DELTAS:
            filas = [r for r in res if r[0] == a and r[1] == dd]
            peor = max((r[4] for r in filas if r[4] is not None), default=None)
            inst = [r[4] for r in filas if r[3] == "instant" and r[4] is not None]
            mi = sum(inst) / len(inst) if inst else float("nan")
            base = 3 * 30 / ((1 - a) * 1.0)
            if peor is not None:
                print(f"alpha={a:>4.2f} D={dd:>4}: k*_inst media {mi:>4.1f} | peor k* {peor:>3} "
                      f"-> suelo {3*peor/((1-a)*1.0):>6.1f} s (baseline {base:.1f} s)")


if __name__ == "__main__":
    main()
