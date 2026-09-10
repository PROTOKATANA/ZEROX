#!/usr/bin/env python3
r"""
audita3_reps.py — ¿El "None" del rank honesto es un hecho o un fallo de búsqueda?

D14B (d14k_lib.py:25-27, S3) usa como representantes SOLO los tips del subgrupo.
El paper (dagknight.txt:589-594, Def. 4) define reps_G(X) = {x ∈ past(X) \
past(tips(G)\X) : x agrees with X} — el pasado exclusivo del subgrupo, que contiene
muchos más bloques que los tips. Un "None" con tips-only NO prueba que el subgrupo
no tenga rank: prueba que la búsqueda no encontró representante.

Este script compara, para el grupo del tip honesto:
  · k_tips  = rank con reps = tips (lo de D14B; d14k_lib.KColouring.rank_tips)
  · k_reps  = rank con reps = Def. 4 completa (mismo motor Alg. 5 + Alg. 6)
Casos: los `instant` (red pública, sin ataque) donde D14B/D8c dirían "sin ganador
honesto", y casos retraso20 para comparar.
"""
import math
import os
import sys

_DIR = os.path.dirname(os.path.abspath(__file__))
D14K = os.path.normpath(os.path.join(_DIR, "..", "..", "d14-dagknight"))
D9C = os.path.normpath(os.path.join(_DIR, "..", "..", "d9-ronda8c"))
for p in (D14K, D9C):
    if p not in sys.path:
        sys.path.insert(0, p)

import audita1_grupos as A  # noqa: E402


def reps_def4(kd, gtips, cg):
    """reps = past(X) \\ past(tips\\X), x agree with X (LCA(x,t) != cg para todo t∈X)."""
    from d14k_lib import iter_bits
    Xmask = 0
    for t in gtips:
        Xmask |= 1 << t
    pastX = 0
    for t in gtips:
        pastX |= kd.past[t] | (1 << t)
    otros = [i for i in range(kd.n)
             if not (kd.future[i] & kd.full) and i not in gtips]
    pastOtros = 0
    for t in otros:
        pastOtros |= kd.past[t] | (1 << t)
    cand = pastX & ~pastOtros
    out = 0
    for x in iter_bits(cand):
        ok = True
        for t in gtips:
            if x != t and kd.chain_lca(x, t) == cg:
                ok = False
                break
        if ok:
            out |= 1 << x
    return out


def k_grupo(kd, gtips, cg, kmax=25):
    from d14k_lib import KColouring, popcount, iter_bits
    kc = KColouring(kd)
    # tips-only (S3 de D14B)
    tips_mask = 0
    for t in gtips:
        tips_mask |= 1 << t
    k_tips, r_tips, _ = kc.rank_tips(tips_mask, kd.full, kmax)
    # Def. 4 completa
    rm = reps_def4(kd, gtips, cg)
    k_reps, r_reps, _ = kc.rank_tips(rm, kd.full, kmax)
    return k_tips, r_tips, k_reps, r_reps, popcount(rm), popcount(tips_mask)


def main():
    import r8c_sim
    from r8c_sim import Mundo
    from d14k_lib import kdag_from_r8c, popcount
    import d14k_ref as R

    casos = []
    for seed in [11, 23, 37, 41, 59, 67]:
        for a, dd in [(0.40, 16.0), (0.40, 20.0), (0.25, 16.0), (0.25, 20.0)]:
            casos.append((a, dd, seed, "instant"))
            casos.append((a, dd, seed, "retraso20"))
    lineas = []

    def p(s=""):
        print(s)
        lineas.append(s)

    p("=" * 118)
    p("AUDITA-D8B · reps tips-only (S3) vs reps Def.4 completa, grupo del tip honesto")
    p("=" * 118)
    p(f"{'α':>5} {'Δ':>4} {'seed':>4} {'estrategia':>10} | {'tips':>4} {'k_tips':>7} "
      f"{'reps':>5} {'k_reps':>7} | {'k_view':>7} {'n_tips':>6}")
    for a, dd, seed, nombre in casos:
        r8c_sim.LAMBDA = 1.0
        r8c_sim.DELTA = dd
        m = Mundo(alpha=a, T=400.0, seed=seed)
        d, tip = m.corre(estrategia=A._estrategia(m, nombre))
        kd, idx = kdag_from_r8c(d)
        Hmask = 0
        for i in range(kd.n):
            if kd.creators[i] == "h":
                Hmask |= 1 << i
        tips = [i for i in range(kd.n) if not (kd.future[i] & kd.full)]
        bw = R.global_blue_work(kd)
        kv, grupos, cg = A._rank_grupos(kd, tips, bw)
        h_tips = [t for t in tips if (Hmask >> t) & 1]
        if not h_tips:
            p(f"{a:>5.2f} {dd:>4.0f} {seed:>4} {nombre:>10} | sin tips honestos")
            continue
        Htip = max(h_tips, key=lambda i: (bw[i], -i))
        gh = None
        nca_h = R.next_after(kd, Htip, cg)
        for g in grupos:
            if g["nca"] == nca_h:
                gh = g
                break
        if gh is None:
            p(f"{a:>5.2f} {dd:>4.0f} {seed:>4} {nombre:>10} | Htip sin grupo")
            continue
        kt, rt, kr, rr, nreps, ntips = k_grupo(kd, gh["tips"], cg)
        p(f"{a:>5.2f} {dd:>4.0f} {seed:>4} {nombre:>10} | {ntips:>4} {str(kt):>7} "
          f"{nreps:>5} {str(kr):>7} | {str(kv):>7} {len(tips):>6}")
    with open(os.path.join(_DIR, "salida3_reps.txt"), "w") as f:
        f.write("\n".join(lineas) + "\n")


if __name__ == "__main__":
    main()
