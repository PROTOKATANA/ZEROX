#!/usr/bin/env python3
"""
r8f_a1b_copias.py — A1, barrido `C` REDUCIDO y llevado MAS LEJOS.

`r8f_a1_saturacion.py C` corre la familia completa (global + bloque a bloque) hasta
`C = 30` y tarda >40 min. Aqui se sacrifica la familia —solo las 7 estrategias GLOBALES,
`pols_hasta(32)`— para llegar a `C = 60`, que es lo que decide si las COPIAS saturan.

El `m` absoluto de aqui NO es comparable con el de A1 ni con el de D9-e (familia menor);
**solo son comparables las filas entre si**, que es lo que se pregunta.

Anidamiento: el nivel `C` incluye TODAS las corridas con `copias ∈ {0,6,14,30,60} ∩ [0,C]`,
luego `m` es monotona no decreciente en `C` por construccion. `nuevas` cuenta las corridas
que ese nivel ejecuta por primera vez; `aporta` los umbrales en que anadio un `seed` nuevo.

Criterio alpha: alpha=0 -> m=1 en todos los niveles.
"""
import sys
import time

from r8f_lib import Mundo, perfil, ancla_bs_T, ancla_slot_T, slot_de, pols_hasta, \
    idx_ventana, K, MP, BANDA, HOR

P = 30
SEMS = list(range(1, 13))
CS = [0, 6, 14, 30, 60]


def barrido(alpha, semilla, gran=1.0, W=30.0, D=32):
    mundo = Mundo(alpha, HOR, semilla, k=K, mp=MP, u3_mode="dynamic")
    d0, tip0 = mundo.corre({}, copias=0)
    ch0 = d0.selected_chain(tip0)
    if P >= len(ch0):
        return None
    tP = d0.B[ch0[P]].t
    T0 = d0.gd[ch0[P]].blue_score
    Ts = list(range(T0 - BANDA, T0 + BANDA + 1))
    Ss = [slot_de(tP + u, gran) for u in range(-BANDA, BANDA + 1)]
    idx = idx_ventana(mundo, tP, W)
    pols = pols_hasta(D)
    ests = [{}] + [{i: (0.0, pol) for i in idx} for pol in pols]

    ac_bs = {T: set() for T in Ts}
    ac_sl = {S: set() for S in Ss}
    out = []
    for C in CS:
        antes_bs = {T: len(ac_bs[T]) for T in Ts}
        antes_sl = {S: len(ac_sl[S]) for S in Ss}
        nuevas = 0
        for e in ests:
            d, tip = mundo.corre(e, copias=C)
            nuevas += 1
            pf = perfil(d, tip, gran=gran)
            for T in Ts:
                s, _ = ancla_bs_T(pf, T)
                if s is not None:
                    ac_bs[T].add(s)
            for S in Ss:
                s, _ = ancla_slot_T(pf, S)
                if s is not None:
                    ac_sl[S].add(s)
        ap_bs = sum(1 for T in Ts if len(ac_bs[T]) > antes_bs[T])
        ap_sl = sum(1 for S in Ss if len(ac_sl[S]) > antes_sl[S])
        mb = [len(ac_bs[T]) for T in Ts]
        ms = [len(ac_sl[S]) for S in Ss]
        out.append((sum(mb) / len(mb), max(mb), sum(ms) / len(ms), max(ms),
                    nuevas, ap_bs, ap_sl))
    return out


if __name__ == "__main__":
    print("=== A1b · ¿SATURAN las COPIAS? (familia GLOBAL de 8 estrategias, C hasta 60) ===")
    print(f"k={K}, mp={MP}, horizonte {HOR:.0f} s, u3_mode=dynamic, P={P}, 21 umbrales,")
    print(f"semillas {SEMS[0]}..{SEMS[-1]}, D=32, W=30 s, granularidad de slot = 1 s.")
    print("`m` absoluto NO comparable con A1/D9-e (familia menor); comparar FILAS.\n")
    print(f"{'C':>5} {'alpha':>6} | {'m_BS med':>9} {'m_BS max':>9} {'apBS/21':>8} | "
          f"{'m_SL med':>9} {'m_SL max':>9} {'apSL/21':>8} | {'nuevas':>7}")
    t0 = time.time()
    for alpha in (0.0, 0.10, 0.25, 0.40):
        rs = [barrido(alpha, s) for s in SEMS]
        rs = [r for r in rs if r]
        n = len(rs)
        for j, C in enumerate(CS):
            print(f"{C:>5} {alpha:>6.2f} | {sum(r[j][0] for r in rs)/n:>9.3f} "
                  f"{max(r[j][1] for r in rs):>9} {sum(r[j][5] for r in rs)/n:>8.2f} | "
                  f"{sum(r[j][2] for r in rs)/n:>9.3f} {max(r[j][3] for r in rs):>9} "
                  f"{sum(r[j][6] for r in rs)/n:>8.2f} | {sum(r[j][4] for r in rs):>7}")
        print()
    print(f"[{time.time()-t0:.0f} s]")
