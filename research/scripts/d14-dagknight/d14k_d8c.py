#!/usr/bin/env python3
r"""
d14k_d8c.py — Cierre del Punto 2: selección de subgrupo bajo ataque.

Mide, para las estrategias que más inflan, si al rank k_ref le queda algún ganador
mayoritariamente honesto (oráculo) y si el tie-breaking tipo Alg. 4 (argmin de
max_{B∈F} |anticone(B) ∩ cadena|, F = cluster libre a g(k)=isqrt(k)) lo elige.
Salida: salida_d8c.txt.
"""
import multiprocessing as mp
import os
import sys

_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, _DIR)

ALPHAS = [0.25, 0.40]
DELTAS = [4.0, 16.0, 20.0]
SEMILLAS = [11, 23, 37, 41, 59, 67, 73, 89, 97, 101, 113, 127]
ESTRATEGIAS = ["retraso20", "retraso60", "parasita5", "retro500"]
T = 400.0


def _estrategia(m, nombre):
    at = [(i, e) for i, e in enumerate(m.ev) if e[1] == "a"]
    if nombre == "retraso20":
        return {i: (20.0, "tips") for i, _ in at}
    if nombre == "retraso60":
        return {i: (60.0, "tips") for i, _ in at}
    if nombre == "parasita5":
        return {i: (0.0, ("retro", 5)) for i, _ in at}
    if nombre == "retro500":
        return {i: (0.0, ("retro", 500)) for i, _ in at}
    raise ValueError(nombre)


def _tarea(args):
    alpha, delta, seed, nombre = args
    import math
    import d14k_ref
    import r8c_sim
    from r8c_sim import Mundo
    from d14k_lib import kdag_from_r8c, popcount
    from d14k_ref import (rank_dag, global_blue_work, committed_coloring,
                          virtual_coloring, umc_voting, next_after)

    r8c_sim.LAMBDA = 1.0
    r8c_sim.DELTA = delta
    m = Mundo(alpha=alpha, T=T, seed=seed)
    d, tip = m.corre(estrategia=_estrategia(m, nombre))
    kd, idx = kdag_from_r8c(d)
    Hmask = 0
    for i in range(kd.n):
        if kd.creators[i] == "h":
            Hmask |= 1 << i
    k_ref, winners = rank_dag(kd, kmax=40)
    if k_ref is None or not winners:
        return (alpha, delta, seed, nombre, k_ref, 0.0, 0.0, 0, 0)

    def hon(bmask):
        b = 0
        for i in bmask:
            b |= 1 << i
        return popcount(b & Hmask) / max(1, popcount(b))

    hons = [hon(w[3]) for w in winners]
    hon_max = max(hons)
    # tie-break tipo Alg. 4 (proxy): F libre a g(k); C_i = max_B |anticone(B) ∩ cadena_i|
    tips = [i for i in range(kd.n) if not kd.future[i]]
    bw = global_blue_work(kd)
    if len(tips) == 1:
        cg = 0
    else:
        cg = tips[0]
        for t in tips[1:]:
            cg = kd.chain_lca(cg, t)
    kfree = math.isqrt(k_ref)
    from d14k_lib import VirtualColouring
    vc = VirtualColouring(kd)
    F, _ = vc.cluster_virtual(kfree, True, kd.full & ~kd.past[cg])
    scores = []
    for w in winners:
        vsp = w[2]
        chain_mask = 0
        cur = vsp
        while cur is not None:
            chain_mask |= 1 << cur
            if cur == cg:
                break
            cur = kd.chain_parent[cur]
        c = 0
        for B in range(kd.n):
            if (F >> B) & 1:
                if popcount(kd.anticone(B, kd.full) & chain_mask) > k_ref:
                    c += 1
        scores.append(c)
    sel = min(range(len(winners)), key=lambda i: (scores[i], winners[i][2]))
    hon_sel = hons[sel]
    return (alpha, delta, seed, nombre, k_ref, hon_max, hon_sel,
            int(hon_max >= 0.5), int(hon_sel >= 0.5))


def main():
    tareas = [(a, dd, s, e) for a in ALPHAS for dd in DELTAS for s in SEMILLAS
              for e in ESTRATEGIAS]
    with mp.Pool(processes=min(16, os.cpu_count() or 4)) as pool:
        res = pool.map(_tarea, tareas, chunksize=1)
    with open(os.path.join(_DIR, "salida_d8c_crudo.txt"), "w") as f:
        f.write("alpha delta seed estrategia k_ref hon_max hon_sel hay_hon sel_hon\n")
        for r in res:
            f.write(" ".join(str(x) for x in r) + "\n")
    lineas = []

    def p(s=""):
        lineas.append(s)

    p("=" * 96)
    p("D8c — selección de subgrupo bajo ataque (12 semillas). hon_max = mejor honestidad entre")
    p("los ganadores de k_ref; hon_sel = honestidad del elegido por el tie-break Alg. 4 (proxy).")
    p("=" * 96)
    p(f"{'α':>5} {'Δ':>4} {'estrategia':>11} | {'k_ref med':>9} {'hon_max':>8} "
      f"{'hon_sel':>8} | {'hay ganador honesto':>19} {'tie-break elige honesto':>24}")
    for a in ALPHAS:
        for dd in DELTAS:
            for e in ESTRATEGIAS:
                filas = [r for r in res if r[0] == a and r[1] == dd and r[3] == e]
                if not filas:
                    continue
                import statistics as st
                kref = [r[4] for r in filas if r[4] is not None]
                hm = [r[5] for r in filas]
                hs = [r[6] for r in filas]
                hay = sum(r[7] for r in filas)
                sel = sum(r[8] for r in filas)
                p(f"{a:>5.2f} {dd:>4.0f} {e:>11} | {st.mean(kref):>9.1f} "
                  f"{st.mean(hm):>8.2f} {st.mean(hs):>8.2f} | {hay:>8}/12          "
                  f"{sel:>8}/12")
    texto = "\n".join(lineas)
    print(texto)
    with open(os.path.join(_DIR, "salida_d8c.txt"), "w") as f:
        f.write(texto + "\n")


if __name__ == "__main__":
    main()
