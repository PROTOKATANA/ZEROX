#!/usr/bin/env python3
"""
r8f_b1_slot.py — PARTE B. El ancla por SLOT frente al ancla por BLUE_SCORE, en la MISMA
ejecucion, con el MISMO instrumento, las MISMAS semillas y la MISMA familia que D9-e.

  ancla BS   (R-FIN-1 vigente): primer bloque de cadena con `blue_score >= T`.
  ancla SLOT (candidata)      : primer bloque de cadena con `slot >= S`,
                                `slot` = INDICE DE PoT (R-FIN-13), infalsificable.
                                Equivale a «el de MENOR blue_work con slot >= S» por
                                R-FIN-1a (slot estrictamente creciente por la cadena) y el
                                Lema A4b de D9-e (blue_work creciente por la cadena) — y se
                                COMPRUEBA en cada ejecucion (`equiv!=`, debe ser 0).

Familia: la de `r8e_a1c_copias.py` (D9-e) LITERAL — pols = sp, retro 1/2/4/8/16, global y
bloque a bloque, ventana +-30 s, copias 0 y 14. Es la familia con la que salio `m = 5,77`.

CAPACIDAD DEL INSTRUMENTO (regla 4). Se declaran en cada fila:
  `ancla!=`  ejecuciones×umbral en que el BLOQUE del ancla SLOT NO es el del ancla BS.
             Si fuera 0, las dos columnas serian la misma por construccion y la
             comparacion no diria nada.
  `equiv!=`  discrepancias entre las dos formas del ancla slot (debe ser 0).
Y el criterio alpha: alpha=0 -> m=1 en las dos anclas.

Granularidad del slot: `gran=1.0` es la lectura LITERAL del diseno (R-FIN-7 escribe
`F = 11 520` slots para `F = 3,2 h` => 1 slot = 1 s). `gran=0` = PoT de grano fino.
"""
import math
import sys
import time

from r8f_lib import Mundo, perfil, ancla_bs_T, ancla_slot_T, ancla_slot_minbw, \
    slot_de, idx_ventana, K, MP, BANDA, HOR

P = 30
SEMS = list(range(1, 13))
POLS = ["sp", ("retro", 1), ("retro", 2), ("retro", 4), ("retro", 8), ("retro", 16)]


def menus(alpha, semilla, copias, gran, W=30.0, u3_mode="dynamic"):
    mundo = Mundo(alpha, HOR, semilla, k=K, mp=MP, u3_mode=u3_mode)
    d0, tip0 = mundo.corre({}, copias=0)
    ch0 = d0.selected_chain(tip0)
    if P >= len(ch0):
        return None
    tP = d0.B[ch0[P]].t
    T0 = d0.gd[ch0[P]].blue_score
    S0 = slot_de(tP, gran)
    Ts = list(range(T0 - BANDA, T0 + BANDA + 1))
    # Umbrales separados UN SEGUNDO de PoT, sea cual sea la granularidad: asi los 21
    # umbrales cubren la MISMA region temporal (21 s) que los 21 umbrales de blue_score
    # (21 azules / lambda_azul ~ 21 s) y las dos columnas son comparables.
    Ss = [slot_de(tP + u, gran) for u in range(-BANDA, BANDA + 1)]

    idx = idx_ventana(mundo, tP, W)
    ests = [{}]
    for pol in POLS:
        ests.append({i: (0.0, pol) for i in idx})
    for i in idx:
        for pol in POLS:
            ests.append({i: (0.0, pol)})

    ac_bs = {T: set() for T in Ts}
    ac_sl = {S: set() for S in Ss}
    dif = tot = equiv_mal = 0
    gaps = []
    for e in ests:
        d, tip = mundo.corre(e, copias=copias)
        pf = perfil(d, tip, gran=gran)
        for T in Ts:
            s, i = ancla_bs_T(pf, T)
            if s is not None:
                ac_bs[T].add(s)
        for S in Ss:
            s, i = ancla_slot_T(pf, S)
            s2, i2 = ancla_slot_minbw(pf, S)
            if s is None:
                continue
            ac_sl[S].add(s)
            gaps.append(pf[i][1] - S)
            tot += 1
            if (s2, i2) != (s, i):
                equiv_mal += 1
        # ¿el BLOQUE del ancla slot coincide con el del ancla bs? (capacidad del instrumento)
        for T, S in zip(Ts, Ss):
            _, ib = ancla_bs_T(pf, T)
            _, isl = ancla_slot_T(pf, S)
            if ib is not None and isl is not None and ib != isl:
                dif += 1
    mb = [len(ac_bs[T]) for T in Ts]
    ms = [len(ac_sl[S]) for S in Ss]
    return (sum(mb) / len(mb), max(mb), sum(ms) / len(ms), max(ms),
            dif, tot, equiv_mal, len(ests), sum(gaps) / max(len(gaps), 1), max(gaps or [0]))


if __name__ == "__main__":
    gran = float(sys.argv[1]) if len(sys.argv) > 1 else 1.0
    print("=== B1 · ancla SLOT vs ancla BLUE_SCORE, mismo instrumento y mismas semillas ===")
    print(f"k={K}, mp={MP}, lambda=1, Delta=4, horizonte {HOR:.0f} s, u3_mode=dynamic, P={P},")
    print(f"21 umbrales (T0+-{BANDA} azules / S0+-{BANDA} slots), semillas {SEMS[0]}..{SEMS[-1]},")
    print(f"granularidad de slot = {gran} s. Familia LITERAL de r8e_a1c_copias.py (D9-e):")
    print("pols = sp, retro 1/2/4/8/16, global y bloque a bloque, ventana +-30 s.")
    print("Referencia D9-e (salida_a1c.txt, peso 1, 8 semillas): m_BS = 4,62 (cop 0) / "
          "5,77 (cop 14) a alpha=0,25.\n")
    print(f"{'copias':>7} {'alpha':>6} | {'m_BS medio':>11} {'m_BS max':>9} | "
          f"{'m_SLOT medio':>13} {'m_SLOT max':>11} | {'ancla!=':>8} {'de':>7} "
          f"{'equiv!=':>8} | {'gap medio':>10} {'gap max':>8} {'estrat':>7}")
    t0 = time.time()
    for cop in (0, 14):
        for alpha in (0.0, 0.10, 0.25, 0.40):
            rs = [menus(alpha, s, cop, gran) for s in SEMS]
            rs = [r for r in rs if r]
            if not rs:
                print(f"{cop:>7} {alpha:>6.2f} | sin datos"); continue
            n = len(rs)
            print(f"{cop:>7} {alpha:>6.2f} | {sum(r[0] for r in rs)/n:>11.3f} "
                  f"{max(r[1] for r in rs):>9} | {sum(r[2] for r in rs)/n:>13.3f} "
                  f"{max(r[3] for r in rs):>11} | {sum(r[4] for r in rs):>8} "
                  f"{sum(r[5] for r in rs):>7} {sum(r[6] for r in rs):>8} | "
                  f"{sum(r[8] for r in rs)/n:>10.2f} {max(r[9] for r in rs):>8.1f} "
                  f"{sum(r[7] for r in rs)/n:>7.1f}")
        print()
    print(f"[{time.time()-t0:.0f} s]")
