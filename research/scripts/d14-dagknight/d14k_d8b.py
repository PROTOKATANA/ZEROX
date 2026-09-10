#!/usr/bin/env python3
r"""
d14k_d8b.py — Punto 2 (D14B): manipulación de k, umbral de Δ y mitigaciones.

Estrategias del atacante (mismo calendario, r8c_sim): instant, retraso20, retraso60,
burst300, parasita5, retro500. α ∈ {0,10;0,25;0,40}, Δ ∈ {1,4,8,16,20}, 12 semillas.
Medidas:
  · k_ref  = rank fiel (d14k_ref);  k_mkmc = M_kMC fiel.
  · fracción honesta del cluster ganador de k_ref (oráculo, solo análisis).
  · suelo adaptativo 3k/((1−α)λ) y baseline 3·30/((1−α)λ); umbral de Δ.
Mitigaciones sobre el rank:
  M1 tope de k (cap K): k_cap = min(k_ref, K); se mide si el cluster a k_cap sigue
     siendo mayoritariamente honesto (si no, el tope es inseguro).
  M2 exigir que el k-cluster cubra la cadena seleccionada (sp de GHOSTDAG):
     k_chain = mínimo k ≥ k_ref con la cadena dentro de los azules.
  M3 exigir mayoría honesta y cobertura >= 50 % de honestos: k_hon (criterio 1.ª pasada).
  M4 tie-breaking del paper (Alg. 4 simplificado): entre los ganadores de k_ref, elegir
     el de mayor cobertura de su cadena por el cluster libre F_{g(k)}; se mide si el
     ganador elegido es mayoritariamente honesto.
Salidas: salida_d8b.txt y salida_d8b_crudo.txt.
"""
import multiprocessing as mp
import os
import statistics as st
import sys

_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, _DIR)

ALPHAS = [0.10, 0.25, 0.40]
DELTAS = [1.0, 4.0, 8.0, 16.0, 20.0]
SEMILLAS = [11, 23, 37, 41, 59, 67, 73, 89, 97, 101, 113, 127]
ESTRATEGIAS = ["instant", "retraso20", "retraso60", "burst300", "parasita5", "retro500"]
T = 400.0
K_BASE = 30
CAPS = [4, 8, 16]


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
    import d14k_ref
    import r8c_sim
    from r8c_sim import Mundo
    from d14k_lib import kdag_from_r8c, VirtualColouring, popcount
    from d14k_ref import rank_dag, rank_view, global_blue_work

    r8c_sim.LAMBDA = 1.0
    r8c_sim.DELTA = delta
    m = Mundo(alpha=alpha, T=T, seed=seed)
    d, tip = m.corre(estrategia=_estrategia(m, nombre))
    kd, idx = kdag_from_r8c(d)
    H = {i for i in range(kd.n) if kd.creators[i] == "h"}
    k_ref, winners = rank_dag(kd, kmax=40)
    k_mkmc, _ = VirtualColouring(kd).kmmc(kmax=40)
    hon_frac = float("nan")
    if winners:
        bmask = 0
        for i in winners[0][3]:
            bmask |= 1 << i
        hmask = 0
        for i in H:
            hmask |= 1 << i
        hon_frac = popcount(bmask & hmask) / popcount(bmask)
    # mitigación M2: k_chain
    bw = global_blue_work(kd)
    tips = [i for i in range(kd.n) if not (kd.future[i] & kd.full)]
    chain = set()
    for t in tips:
        cur = t
        while cur is not None:
            chain.add(cur)
            cur = kd.chain_parent[cur]
    k_chain = None
    if k_ref is not None:
        for k in range(k_ref, 41):
            ws = _winners_at(kd, tips, bw, k)
            if ws:
                bmask = 0
                for i in ws[0][3]:
                    bmask |= 1 << i
                if all((bmask >> c) & 1 for c in chain if c != 0):
                    k_chain = k
                    break
    # mitigación M3: mayoría honesta + cobertura >= 50 % de honestos
    k_hon = None
    if k_ref is not None:
        for k in range(k_ref, 41):
            ws = _winners_at(kd, tips, bw, k)
            ok = False
            for (_nca, _g, _vsp, blues, _reds, _sc) in ws:
                bmask = 0
                for i in blues:
                    bmask |= 1 << i
                bh = popcount(bmask & sum(1 << i for i in H))
                if bh >= 0.5 * len(blues) and bh >= 0.5 * len(H):
                    ok = True
                    break
            if ok:
                k_hon = k
                break
    return (alpha, delta, seed, nombre, k_ref, k_mkmc, hon_frac, k_chain, k_hon,
            kd.n, len(winners))


def _winners_at(kd, tips, bw, k):
    """Ganadores del rank evaluados exactamente en k (subgrupos que pasan)."""
    from d14k_ref import (next_after, committed_coloring, virtual_coloring, umc_voting)
    if len(tips) == 1:
        cg = 0
    else:
        cg = tips[0]
        for t in tips[1:]:
            cg = kd.chain_lca(cg, t)
    groups = {}
    for t in tips:
        groups.setdefault(next_after(kd, t, cg), []).append(t)
    out = []
    for nca, gtips in groups.items():
        zd, _ = committed_coloring(kd, gtips, nca, cg, k)
        vsp = max(gtips, key=lambda t: (bw[t], -t))
        vnd = virtual_coloring(kd, zd, tips, vsp, cg, k, bw)
        ok, score, blues, reds = umc_voting(kd, zd, cg, nca, vnd, k, bw)
        if ok:
            out.append((nca, gtips, vsp, blues, reds, score))
    return out


def main():
    import math
    tareas = [(a, dd, s, e) for a in ALPHAS for dd in DELTAS for s in SEMILLAS
              for e in ESTRATEGIAS]
    with mp.Pool(processes=min(16, os.cpu_count() or 4)) as pool:
        res = pool.map(_tarea, tareas, chunksize=1)
    with open(os.path.join(_DIR, "salida_d8b_crudo.txt"), "w") as f:
        f.write("alpha delta seed estrategia k_ref k_mkmc hon_frac k_chain k_hon n winners\n")
        for r in res:
            f.write(" ".join(str(x) for x in r) + "\n")

    lineas = []

    def p(s=""):
        lineas.append(s)

    p("=" * 118)
    p("D8b — manipulación de k con la regla FIEL (12 semillas). Suelo 3k/((1−α)λ) vs baseline 3·30/((1−α)λ)")
    p("=" * 118)
    for etiqueta, idx in (("k_ref (rank fiel)", 4), ("k_mkmc (M_kMC fiel)", 5)):
        p()
        p(f"A · {etiqueta}: media[min,max] sobre 12 semillas")
        p(f"{'α':>5} {'Δ':>4} | " + " ".join(f"{e:>12}" for e in ESTRATEGIAS))
        for a in ALPHAS:
            for dd in DELTAS:
                celdas = []
                for e in ESTRATEGIAS:
                    ks = [r[idx] for r in res if r[0] == a and r[1] == dd and r[3] == e
                          and r[idx] is not None]
                    if ks:
                        celdas.append(f"{st.mean(ks):>5.1f}[{min(ks)},{max(ks)}]".rjust(12))
                    else:
                        celdas.append(f"{'--':>12}")
                p(f"{a:>5.2f} {dd:>4.0f} | " + " ".join(celdas))
            p("-" * 118)
    p()
    p("B · fracción honesta media del cluster ganador de k_ref (oráculo)")
    p(f"{'α':>5} {'Δ':>4} | " + " ".join(f"{e:>12}" for e in ESTRATEGIAS))
    for a in ALPHAS:
        for dd in DELTAS:
            celdas = []
            for e in ESTRATEGIAS:
                vs = [r[6] for r in res if r[0] == a and r[1] == dd and r[3] == e
                      and r[6] is not None and not math.isnan(r[6])]
                celdas.append(f"{st.mean(vs):>12.2f}" if vs else f"{'--':>12}")
            p(f"{a:>5.2f} {dd:>4.0f} | " + " ".join(celdas))
    p()
    p("C · SUELO bajo la peor estrategia (max k sobre estrategias): 3k/((1−α)λ) vs baseline")
    for etiqueta, idx in (("k_ref", 4), ("k_mkmc", 5), ("k_hon (M3)", 8)):
        p(f"   -- {etiqueta} --")
        for a in ALPHAS:
            base = 3 * K_BASE / ((1 - a) * 1.0)
            fila = []
            for dd in DELTAS:
                peor = max((r[idx] for r in res if r[0] == a and r[1] == dd and r[idx] is not None),
                           default=None)
                if peor is None:
                    fila.append(f"Δ={dd:>2}: --")
                else:
                    fila.append(f"Δ={dd:>2}: {3*peor/((1-a)*1.0):>6.1f}s")
            p(f"      α={a:.2f} baseline {base:>5.1f}s | " + " | ".join(fila))
    p()
    p("D · mitigaciones en Δ≥16 (peor caso). Media[min,max] del k resultante y del suelo")
    p(f"{'α':>5} {'Δ':>4} {'estrategia':>11} | {'k_ref':>7} {'k_cap4':>7} {'k_cap8':>7} "
      f"{'k_cap16':>7} {'k_chain':>7} {'k_hon':>7} | {'suelo_ref':>9} {'suelo_hon':>9}")
    for a in ALPHAS:
        for dd in (16.0, 20.0):
            for e in ("retraso60", "parasita5", "burst300"):
                filas = [r for r in res if r[0] == a and r[1] == dd and r[3] == e]
                if not filas:
                    continue
                def mm(idx):
                    v = [r[idx] for r in filas if r[idx] is not None]
                    return f"{st.mean(v):.1f}[{min(v)},{max(v)}]" if v else "--"
                kref = [r[4] for r in filas if r[4] is not None]
                sueloref = 3 * st.mean(kref) / ((1 - a) * 1.0) if kref else float("nan")
                kh = [r[8] for r in filas if r[8] is not None]
                sueloh = 3 * st.mean(kh) / ((1 - a) * 1.0) if kh else float("nan")
                cap = lambda K: [min(r[4], K) for r in filas if r[4] is not None]
                p(f"{a:>5.2f} {dd:>4.0f} {e:>11} | {mm(4):>7} "
                  f"{st.mean(cap(4)):>7.1f} {st.mean(cap(8)):>7.1f} {st.mean(cap(16)):>7.1f} "
                  f"{mm(7):>7} {mm(8):>7} | {sueloref:>9.1f} {sueloh:>9.1f}")
    p()
    p("E · umbral de Δ: mayor Δ donde el suelo con k_ref sigue por debajo del baseline")
    for a in ALPHAS:
        base = 3 * K_BASE / ((1 - a) * 1.0)
        umbral = None
        for dd in DELTAS:
            peor = max((r[4] for r in res if r[0] == a and r[1] == dd and r[4] is not None),
                       default=None)
            if peor is not None and 3 * peor / ((1 - a) * 1.0) < base:
                umbral = dd
        p(f"   α={a:.2f}: Δ máximo con ganancia (k_ref) = {umbral}  (baseline {base:.1f} s)")
    texto = "\n".join(lineas)
    print(texto)
    with open(os.path.join(_DIR, "salida_d8b.txt"), "w") as f:
        f.write(texto + "\n")


if __name__ == "__main__":
    main()
