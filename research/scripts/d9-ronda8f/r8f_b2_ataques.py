#!/usr/bin/env python3
"""
r8f_b2_ataques.py — PARTE B, ataques al ancla SLOT y los TRES NIVELES DE COSTE.

Reproduce la tabla de niveles de D9-d (A5: gratis / +retraso / +retencion) leyendo las DOS
anclas en la MISMA ejecucion, y anade lo que solo el ancla slot puede fallar:

  · `gap` = slot(ancla) - T_j. R-FIN-1a acota `slot(B) - slot(sp(B)) <= S_max = 150`, luego
    DETERMINISTICAMENTE `gap < S_max`: el ancla existe siempre y cae dentro de la ventana.
    Se MIDE el gap real y su maximo, y se cuenta cuantas veces roza S_max.
  · `lam_chain`, `lam_azul` en la vista honesta final: lo que el atacante mueve. Con el ancla
    `blue_score` la DURACION de la epoca es `c/lam_azul`; con el ancla `slot` es `I` exacta.
  · retencion: bloques nunca publicados (`retraso = None`), la palanca que en D9-d subio
    m_BS de 3,03 a 7,53.

CAPACIDAD DEL INSTRUMENTO (regla 4): `ancla!=` cuenta las veces que los dos anclas caen en
BLOQUES distintos. Si fuera 0 la comparacion seria vacia. Criterio alpha: alpha=0 -> m=1.
"""
import sys
import time

from r8f_lib import Mundo, perfil, ancla_bs_T, ancla_slot_T, slot_de, idx_ventana, \
    K, MP, BANDA, HOR, S_MAX

P = 30
SEMS = list(range(1, 13))
POLS = ["sp", ("retro", 1), ("retro", 2), ("retro", 4), ("retro", 8), ("retro", 16)]


def tiers(mundo, tP, W=30.0):
    """Tres niveles ANIDADOS, calcados de r8d_a1_menu.estrategias pero con la familia
    saturada de A1 (retro hasta 16, global y bloque a bloque)."""
    idx = idx_ventana(mundo, tP, W)
    g1 = [{}]
    for pol in POLS:
        g1.append({i: (0.0, pol) for i in idx})
        for i in idx:
            g1.append({i: (0.0, pol)})
    g2 = []
    for r in (2.0, 6.0, 15.0, 40.0, 150.0):
        g2.append({i: (r, "tips") for i in idx})
        for pol in POLS[:3]:
            g2.append({i: (r, pol) for i in idx})
    g3 = [{i: (None, "tips") for i in idx}]
    for i in idx:
        for pol in ["tips"] + POLS[:3]:
            for r in (0.0, 4.0, 12.0):
                e = {j: (None, "tips") for j in idx}
                e[i] = (r, pol)
                g3.append(e)
    return (g1, g2, g3), idx


def corrida(alpha, semilla, gran=1.0, u3_mode="dynamic"):
    mundo = Mundo(alpha, HOR, semilla, k=K, mp=MP, u3_mode=u3_mode)
    d0, tip0 = mundo.corre({}, copias=0)
    ch0 = d0.selected_chain(tip0)
    if P >= len(ch0):
        return None
    tP = d0.B[ch0[P]].t
    T0 = d0.gd[ch0[P]].blue_score
    S0 = slot_de(tP, gran)
    Ts = list(range(T0 - BANDA, T0 + BANDA + 1))
    Ss = [slot_de(tP + u, gran) for u in range(-BANDA, BANDA + 1)]   # 1 s de PoT de paso
    gs, idx = tiers(mundo, tP)

    ac_bs = {T: set() for T in Ts}
    ac_sl = {S: set() for S in Ss}
    res = []
    dif = tot = 0
    gaps = []
    roza = 0
    for g in gs:
        for e in g:
            d, tip = mundo.corre(e, copias=0)
            pf = perfil(d, tip, gran=gran)
            for T in Ts:
                s, _ = ancla_bs_T(pf, T)
                if s is not None:
                    ac_bs[T].add(s)
            for S in Ss:
                s, i = ancla_slot_T(pf, S)
                if s is not None:
                    ac_sl[S].add(s)
                    gp_slots = pf[i][1] - S
                    gaps.append(gp_slots * (gran if gran > 0 else 1.0))   # en SEGUNDOS
                    if gp_slots >= S_MAX:                                  # S_max en SLOTS
                        roza += 1
            for T, S in zip(Ts, Ss):
                _, ib = ancla_bs_T(pf, T)
                _, isl = ancla_slot_T(pf, S)
                if ib is not None and isl is not None:
                    tot += 1
                    if ib != isl:
                        dif += 1
        mb = [len(ac_bs[T]) for T in Ts]
        ms = [len(ac_sl[S]) for S in Ss]
        res.append((sum(mb) / len(mb), max(mb), sum(ms) / len(ms), max(ms)))
    # tasas en la vista honesta final SIN estrategia
    lam_ch = (len(ch0) - 1) / d0.B[tip0].t
    lam_az = d0.gd[tip0].blue_score / d0.B[tip0].t
    return res, dif, tot, gaps, roza, lam_ch, lam_az, len(idx)


if __name__ == "__main__":
    gran = float(sys.argv[1]) if len(sys.argv) > 1 else 1.0
    print("=== B2 · los tres niveles de coste, para las DOS anclas, misma ejecucion ===")
    print(f"k={K}, mp={MP}, horizonte {HOR:.0f} s, u3_mode=dynamic, P={P}, 21 umbrales,")
    print(f"semillas {SEMS[0]}..{SEMS[-1]}, granularidad de slot = {gran} s. "
          f"S_max = {S_MAX} (R-FIN-1a).")
    print("Referencia D9-d (A5): m_BS 3,03 gratis / 4,29 +retraso / 7,53 +retencion "
          "a alpha=0,25.\n")
    print(f"{'nivel':>12} {'alpha':>6} | {'m_BS med':>9} {'m_BS max':>9} | "
          f"{'m_SLOT med':>11} {'m_SLOT max':>11} | {'ancla!=':>8} {'de':>8} | "
          f"{'gap med s':>9} {'gap max s':>9} {'gap>=Smax':>10} | {'lam_ch':>7} {'lam_az':>7}")
    t0 = time.time()
    NIV = ("gratis", "+retraso", "+retencion")
    for alpha in (0.0, 0.10, 0.25, 0.33, 0.40):
        rs = [corrida(alpha, s, gran) for s in SEMS]
        rs = [r for r in rs if r]
        if not rs:
            print(f"{'':>12} {alpha:>6.2f} sin datos"); continue
        n = len(rs)
        for j, nom in enumerate(NIV):
            print(f"{nom:>12} {alpha:>6.2f} | "
                  f"{sum(r[0][j][0] for r in rs)/n:>9.3f} {max(r[0][j][1] for r in rs):>9} | "
                  f"{sum(r[0][j][2] for r in rs)/n:>11.3f} "
                  f"{max(r[0][j][3] for r in rs):>11} | "
                  + (f"{sum(r[1] for r in rs):>8} {sum(r[2] for r in rs):>8} | "
                     f"{sum(sum(r[3]) for r in rs)/max(sum(len(r[3]) for r in rs),1):>9.2f} "
                     f"{max(max(r[3]) for r in rs):>9.2f} {sum(r[4] for r in rs):>10} | "
                     f"{sum(r[5] for r in rs)/n:>7.4f} {sum(r[6] for r in rs)/n:>7.4f}"
                     if j == len(NIV) - 1 else ""))
        print()
    print(f"[{time.time()-t0:.0f} s]")
