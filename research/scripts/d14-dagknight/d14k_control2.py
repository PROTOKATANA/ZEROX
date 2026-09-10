#!/usr/bin/env python3
r"""
d14k_control2.py — Punto 1 (D14B): control positivo con la regla FIEL.

Objetivo del paper (dagknight.txt:182-197 / PDF fig. 3):
  λ=3,75, α=0,2, D=0,1/1/2 s, ε=0,05 -> k = 0/1/4 y tiempos 1,2/6/12 s.

Se mide, para 12 semillas y T en {1,2; 6; 12; 24} s:
  A · k del problema de optimización M_kMC fiel (Alg. 1: mínimo k con el mayor
      k-cluster cubriendo >= 50 %) sobre (i) la vista honesta y (ii) el DAG completo
      (atacante invisible revelado al final).
  B · rank del protocolo según la implementación de referencia (d14k_ref): la vista
      honesta y el DAG completo.
  C · reglas de cliente candidatas basadas en el rank (estabilización del rank y
      primer cruce del rank final) — la tabla 1,2/6/12 s exige la regla del paper,
      que NO está publicada.
Salida: salida_control2.txt.
"""
import os
import statistics as st
import sys

_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, _DIR)

from d14_lib import genera_eventos, construye_paper  # noqa: E402
from d14k_lib import (KDag, paper_honest_dag, chain_from_ghostdag,  # noqa: E402
                      VirtualColouring, kdag_from_r8c)
from d14k_ref import rank_dag, global_blue_work  # noqa: E402

LAM = 3.75
ALPHA = 0.2
MU = (1 - ALPHA) * LAM
SEMILLAS = list(range(1, 13))
OBJ = {0.1: (0, 1.2), 1.0: (1, 6.0), 2.0: (4, 12.0)}
T_LISTA = (1.2, 6.0, 12.0, 24.0)


def kdag_paper_completo(ev, D):
    bl = construye_paper(ev, D, "oculto")
    idx = {b[0]: i for i, b in enumerate(bl)}
    parents = [tuple(idx[p] for p in b[1]) for b in bl]
    return KDag(parents, [b[2] for b in bl], [b[3] for b in bl])


def rank_prefijo(kdag, t_max, kmax=30):
    """Rank de la vista truncada a bloques con t <= t_max (prefijo topológico)."""
    idx = [i for i in range(kdag.n) if kdag.times[i] <= t_max]
    if not idx:
        return None
    m = 0
    for i in idx:
        m |= 1 << i
    # sub-DAG inducido por el prefijo (es past-clausurado si el orden es topológico)
    bw = global_blue_work(kdag)
    from d14k_ref import rank_view
    tips = [i for i in idx if not (kdag.future[i] & m)]
    k, _ = rank_view(kdag, tips, bw, kmax)
    return k


def main():
    lineas = []

    def p(s=""):
        lineas.append(s)

    p("=" * 108)
    p("CONTROL POSITIVO D14B — regla fiel (Alg. 1 + implementación de referencia)")
    p(f"λ={LAM}, α={ALPHA}, vista honesta μ={MU}/s, ε={0.05}, 12 semillas")
    p("Objetivo del paper: k=0/1/4 y conf. times 1,2/6/12 s (fig. 3)")
    p("=" * 108)
    p()
    p("A · M_kMC fiel (mínimo k con |k-cluster| >= 50 %) — vista honesta")
    p(f"{'D':>5} {'T':>5} | {'k honesta (semillas)':<38} {'media':>6} | {'objetivo':>8}")
    for D, (k_obj, t_obj) in OBJ.items():
        for T in T_LISTA:
            ks = []
            for s in SEMILLAS:
                d = paper_honest_dag(MU, T, D, s)
                chain_from_ghostdag(d)
                k, _ = VirtualColouring(d).kmmc(kmax=30)
                ks.append(k)
            p(f"{D:>5} {T:>5} | {str(ks):<38} {st.mean(ks):>6.2f} | {k_obj:>8}")
        p(f"      (figura: k={k_obj}, tiempo {t_obj} s)")
    p()
    p("B · M_kMC fiel — DAG completo (atacante invisible revelado al final)")
    p(f"{'D':>5} {'T':>5} | {'k completo (semillas)':<38} {'media':>6} | {'objetivo':>8}")
    for D, (k_obj, t_obj) in OBJ.items():
        for T in T_LISTA:
            ks = []
            for s in SEMILLAS:
                ev = genera_eventos(LAM, ALPHA, T, s)
                d = kdag_paper_completo(ev, D)
                chain_from_ghostdag(d)
                k, _ = VirtualColouring(d).kmmc(kmax=30)
                ks.append(k)
            p(f"{D:>5} {T:>5} | {str(ks):<38} {st.mean(ks):>6.2f} | {k_obj:>8}")
    p()
    p("C · rank del protocolo (implementación de referencia, d14k_ref)")
    p(f"{'D':>5} {'T':>5} | {'rank honesta':<30} {'media':>6} | {'rank completo':<30} {'media':>6}")
    for D, (k_obj, t_obj) in OBJ.items():
        for T in T_LISTA:
            kh, kc = [], []
            for s in SEMILLAS:
                d = paper_honest_dag(MU, T, D, s)
                chain_from_ghostdag(d)
                kh.append(rank_dag(d, kmax=30)[0])
                ev = genera_eventos(LAM, ALPHA, T, s)
                d = kdag_paper_completo(ev, D)
                chain_from_ghostdag(d)
                kc.append(rank_dag(d, kmax=30)[0])
            mh = st.mean([x for x in kh if x is not None])
            mc = st.mean([x for x in kc if x is not None])
            p(f"{D:>5} {T:>5} | {str(kh):<30} {mh:>6.2f} | {str(kc):<30} {mc:>6.2f}")
    p()
    p("D · reglas de cliente candidatas sobre la vista honesta (media de 12 semillas)")
    p(f"{'D':>5} | {'T final':>7} | {'rank final':>10} | {'1er rank==final':>16} | {'1er rank<=final':>16} | {'objetivo':>8}")
    for D, (k_obj, t_obj) in OBJ.items():
        T = t_obj
        t_est, t_le, kfin = [], [], []
        for s in SEMILLAS:
            d = paper_honest_dag(MU, T, D, s)
            chain_from_ghostdag(d)
            bw = global_blue_work(d)
            from d14k_ref import rank_view
            tips = list(range(d.n))
            tips = [i for i in tips if not (d.future[i])]
            k_fin, _ = rank_view(d, tips, bw, 30)
            kfin.append(k_fin)
            t1 = t2 = None
            for i in range(1, d.n):
                tmax = d.times[i]
                kk = rank_prefijo(d, tmax, 30)
                if kk is None:
                    continue
                if t1 is None and kk == k_fin:
                    t1 = tmax
                if t2 is None and kk is not None and kk <= k_fin:
                    t2 = tmax
            if t1 is not None:
                t_est.append(t1)
            if t2 is not None:
                t_le.append(t2)
        m = lambda v: (st.mean(v) if v else float("nan"))
        p(f"{D:>5} | {T:>7} | {m(kfin):>10.2f} | {m(t_est):>16.2f} | {m(t_le):>16.2f} | {t_obj:>8.1f}")
    p()
    p("E · cota optimista del paper en segundos: (ln(1/ε)+Dλ)/((1−2α)λ)+D²λ (:1007)")
    import math
    for D in OBJ:
        c = (math.log(1 / 0.05) + D * LAM) / ((1 - 2 * ALPHA) * LAM) + D * D * LAM
        p(f"   D={D}: {c:.2f} s  (figura {OBJ[D][1]:.1f} s)")
    p()
    p("VEREDICTO DEL CONTROL: PARCIAL. El k de M_kMC fiel cae en el rango publicado")
    p("(0 / 1-2 / 3-4 frente a 0/1/4; medias 0,2/1,9/3,3 con el atacante revelado), pero")
    p("la tabla exacta 1,2/6/12 s NO se reproduce: el paper no publica la regla de")
    p("cliente ni la simulación, y la implementación de referencia (rusty-kaspa@dagknight)")
    p("solo contiene el consenso (rank + tie-breaking), no el cliente. LAGUNA.")
    texto = "\n".join(lineas)
    print(texto)
    with open(os.path.join(_DIR, "salida_control2.txt"), "w") as f:
        f.write(texto + "\n")


if __name__ == "__main__":
    main()
