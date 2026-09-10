#!/usr/bin/env python3
r"""
d14k_zerox2.py — Puntos 3-4 (D14B): rejilla ZEROX con la regla FIEL.

λ=1, T=400 s, 12 semillas, α ∈ {0,10; 0,25; 0,33; 0,40}, Δ ∈ {1,4,8,16,20}.
Medidas por semilla:
  · k_ref  = rank del protocolo (d14k_ref, fiel a rusty-kaspa@dagknight).
  · k_mkmc = M_kMC fiel (Alg. 1: mínimo k con el mayor k-cluster >= 50 %).
  · Margen adaptativo (adaptación declarada, la misma fórmula que la 1.ª pasada):
      M = max(3k, m(α,ε)),  m = ceil(ln ε / ln(α/(1−α))).
    Latencia = tiempo de calendario hasta el M-ésimo bloque HONESTO tras B*
    (B* = primer honesto con t >= 200 s). El suelo teórico es M/((1−α)λ).
  · Baseline publicado k=30: M=90; mismo calendario.
Salidas: salida_zerox2.txt y salida_zerox2_crudo.txt.
"""
import math
import multiprocessing as mp
import os
import statistics as st
import sys

_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, _DIR)

ALPHAS = [0.10, 0.25, 0.33, 0.40]
DELTAS = [1.0, 4.0, 8.0, 16.0, 20.0]
SEMILLAS = [11, 23, 37, 41, 59, 67, 73, 89, 97, 101, 113, 127]
EPSILONS = [0.05, 1e-3, 1e-6, 1e-12]
T = 400.0
T_TX = 200.0
K_BASE = 30


def margen_paseo(alpha, eps):
    if alpha <= 0:
        return 0
    return int(math.ceil(math.log(eps) / math.log(alpha / (1 - alpha))))


def _tarea(args):
    alpha, delta, seed = args
    import d14_lib  # noqa: F401
    import d14k_ref
    import r8c_sim
    from r8c_sim import Mundo
    from d14k_lib import kdag_from_r8c, VirtualColouring
    from d14k_ref import rank_dag

    r8c_sim.LAMBDA = 1.0
    r8c_sim.DELTA = delta
    m = Mundo(alpha=alpha, T=T, seed=seed)
    d, tip = m.corre()
    kd, idx = kdag_from_r8c(d)
    k_ref, _ = rank_dag(kd, kmax=40)
    k_mkmc, _ = VirtualColouring(kd).kmmc(kmax=40)

    honestos = [e[0] for e in m.ev if e[1] == "h"]
    idx_tx = next((i for i, t in enumerate(honestos) if t >= T_TX), 0)
    t_tx = honestos[idx_tx]

    def tiempo_a_M(M):
        if M <= 0:
            return 0.0
        j = idx_tx + M
        if j >= len(honestos):
            return None
        return honestos[j] - t_tx

    t_base = tiempo_a_M(3 * K_BASE)
    m_eps = {e: margen_paseo(alpha, e) for e in EPSILONS}
    t_ref = {e: tiempo_a_M(max(3 * (k_ref or 0), m_eps[e])) for e in EPSILONS}
    t_mkmc = {e: tiempo_a_M(max(3 * (k_mkmc or 0), m_eps[e])) for e in EPSILONS}
    return {
        "alpha": alpha, "delta": delta, "seed": seed,
        "k_ref": k_ref, "k_mkmc": k_mkmc,
        "t_base": t_base, "m_eps": m_eps, "t_ref": t_ref, "t_mkmc": t_mkmc,
    }


def main():
    tareas = [(a, dd, s) for a in ALPHAS for dd in DELTAS for s in SEMILLAS]
    with mp.Pool(processes=min(16, os.cpu_count() or 4)) as pool:
        res = pool.map(_tarea, tareas, chunksize=1)

    with open(os.path.join(_DIR, "salida_zerox2_crudo.txt"), "w") as f:
        f.write("alpha delta seed k_ref k_mkmc t_base " +
                " ".join(f"m{e} t_ref{e} t_mkmc{e}" for e in EPSILONS) + "\n")
        for r in res:
            f.write(f"{r['alpha']} {r['delta']} {r['seed']} {r['k_ref']} {r['k_mkmc']} "
                    f"{r['t_base']} ")
            for e in EPSILONS:
                f.write(f"{r['m_eps'][e]} {r['t_ref'][e]} {r['t_mkmc'][e]} ")
            f.write("\n")

    lineas = []

    def p(s=""):
        lineas.append(s)

    p("=" * 116)
    p("ZEROX D14B — λ=1, T=400 s, 12 semillas. k_ref = rank fiel (rusty-kaspa@dagknight);")
    p("k_mkmc = M_kMC fiel. Margen adaptativo (adaptación propia): M = max(3k, m(α,ε)).")
    p("=" * 116)

    p()
    p("A · k por (α, Δ): media[min,max] sobre 12 semillas")
    p(f"{'α':>5} | {'Δ':>4} | {'k_ref':>14} | {'k_mkmc':>14}")
    for a in ALPHAS:
        for dd in DELTAS:
            filas = [r for r in res if r["alpha"] == a and r["delta"] == dd]
            kr = [r["k_ref"] for r in filas if r["k_ref"] is not None]
            km = [r["k_mkmc"] for r in filas if r["k_mkmc"] is not None]
            p(f"{a:>5.2f} | {dd:>4.0f} | {st.mean(kr):>6.2f}[{min(kr)},{max(kr)}] | "
              f"{st.mean(km):>6.2f}[{min(km)},{max(km)}]")
    p()
    p("B · baseline k=30: tiempo medido hasta 90 honestos tras B* (media[min,max] sobre α,Δ)")
    for a in ALPHAS:
        v = [r["t_base"] for r in res if r["alpha"] == a and r["t_base"] is not None]
        p(f"   α={a:.2f}: {st.mean(v):.2f} [{min(v):.2f},{max(v):.2f}] s  "
          f"(suelo teórico {3*K_BASE/((1-a)*1.0):.1f} s)")
    p()
    p("C · latencia con k_ref (adaptación): media[min,max] por (α,Δ,ε)")
    p(f"{'α':>5} {'Δ':>4} | " + " | ".join(f"{'ε='+str(e):>20}" for e in EPSILONS))
    for a in ALPHAS:
        for dd in DELTAS:
            celdas = []
            for e in EPSILONS:
                v = [r["t_ref"][e] for r in res
                     if r["alpha"] == a and r["delta"] == dd and r["t_ref"][e] is not None]
                if v:
                    celdas.append(f"{st.mean(v):>8.2f}[{min(v):>6.2f}]")
                else:
                    celdas.append(f"{'--':>20}")
            p(f"{a:>5.2f} {dd:>4.0f} | " + " | ".join(celdas))
        p("-" * 116)
    p()
    p("D · RESUMEN por (α,ε): latencia media/mínima sobre Δ y semillas, con k_ref")
    p(f"{'α':>5} | " + " | ".join(f"{'ε='+str(e):>24}" for e in EPSILONS)
      + f" | {'baseline med/min':>20}")
    for a in ALPHAS:
        celdas = []
        for e in EPSILONS:
            vals = [r["t_ref"][e] for r in res if r["alpha"] == a and r["t_ref"][e] is not None]
            suelos = [max(3 * (r["k_ref"] or 0), r["m_eps"][e]) / ((1 - a) * 1.0)
                      for r in res if r["alpha"] == a]
            if vals:
                celdas.append(f"{st.mean(vals):>9.2f}/{min(vals):<6.2f}({st.mean(suelos):>5.1f})")
            else:
                celdas.append(f"{'--':>24}")
        v = [r["t_base"] for r in res if r["alpha"] == a and r["t_base"] is not None]
        p(f"{a:>5.2f} | " + " | ".join(celdas)
          + f" | {st.mean(v):>9.2f}/{min(v):<9.2f}")
    p()
    p("E · α=0,33 (el caso de la 1.ª pasada): latencia con k_ref y con k_mkmc, por ε")
    a = 0.33
    for e in EPSILONS:
        vals = [r["t_ref"][e] for r in res if r["alpha"] == a and r["t_ref"][e] is not None]
        vm = [r["t_mkmc"][e] for r in res if r["alpha"] == a and r["t_mkmc"][e] is not None]
        kr = [r["k_ref"] for r in res if r["alpha"] == a and r["k_ref"] is not None]
        km = [r["k_mkmc"] for r in res if r["alpha"] == a and r["k_mkmc"] is not None]
        p(f"   ε={e:<8}: k_ref {st.mean(kr):.2f} -> {st.mean(vals):7.2f} s "
          f"[{min(vals):6.2f},{max(vals):7.2f}] | k_mkmc {st.mean(km):.2f} -> "
          f"{st.mean(vm):7.2f} s [{min(vm):6.2f},{max(vm):7.2f}]")
    p()
    p("F · cota optimista del paper (:1007) en segundos, como referencia superior")
    for dd in DELTAS:
        vals = []
        for e in EPSILONS:
            c = (math.log(1 / e) + dd * 1.0) / ((1 - 2 * 0.33) * 1.0) + dd * dd * 1.0
            vals.append(c)
        p(f"   Δ={dd:>4.0f}: " + " ".join(f"ε={e}: {c:7.1f}s" for e, c in zip(EPSILONS, vals)))
    texto = "\n".join(lineas)
    print(texto)
    with open(os.path.join(_DIR, "salida_zerox2.txt"), "w") as f:
        f.write(texto + "\n")


if __name__ == "__main__":
    main()
