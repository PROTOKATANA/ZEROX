#!/usr/bin/env python3
"""
r8d_a1b_reactivo.py — el menu del ancla BLUE_SCORE realizable EN LINEA, y el barrido de
alpha bajo (que es donde el steering muerde, porque g ~ 1/sqrt(alpha)).

Atacante REACTIVO (restriccion de D9-c A1(c)): solo usa bloques suyos creados EN O DESPUES
del instante en que ya existe el ocupante de referencia, y los publica al instante. No
retiene, no retrasa, no mira al futuro. Es la cota INFERIOR realizable.

Se leen las dos anclas en la misma ejecucion: POS (D9-c) y BS (esta ronda).
Criterio alpha: alpha = 0 -> menu 1 en las dos.
"""
import statistics, sys
from r8d_lib import Mundo
from r8d_a1_menu import K, MP, BANDA, lee, ancla_T


def menu_reactivo(alpha, semilla, P, T=260.0, ventana=30.0, u3_mode="dynamic"):
    m = Mundo(alpha, T, semilla, k=K, mp=MP, u3_mode=u3_mode)
    d0, tip0 = m.corre({})
    ch0 = d0.selected_chain(tip0)
    if P >= len(ch0):
        return None
    tP = d0.B[ch0[P]].t
    T0 = d0.gd[ch0[P]].blue_score
    Ts = list(range(T0 - BANDA, T0 + BANDA + 1))
    idx = [i for i, (t, q, *_) in enumerate(m.ev) if q == "a" and tP <= t <= tP + ventana]
    ests = [{}]
    for pol in ("sp", ("retro", 1), ("retro", 2), ("retro", 4)):
        ests.append({i: (0.0, pol) for i in idx})
    for i in idx:
        for pol in ("sp", ("retro", 1), ("retro", 3)):
            ests.append({i: (0.0, pol)})
    vis_pos, vis_bs = set(), {T: set() for T in Ts}
    for e in ests:
        d, tip = m.corre(e)
        perfil = lee(d, tip)
        if P < len(perfil):
            vis_pos.add(perfil[P][1])
        for T in Ts:
            s = ancla_T(perfil, T)
            if s is not None:
                vis_bs[T].add(s)
    mbs = sum(len(v) for v in vis_bs.values()) / len(vis_bs)
    return len(vis_pos), mbs, max(len(v) for v in vis_bs.values()), len(idx)


if __name__ == "__main__":
    P = int(sys.argv[1]) if len(sys.argv) > 1 else 30
    print("=== A1b · menu REACTIVO (en linea, gratis) — POS frente a BLUE_SCORE ===")
    print(f"k={K}, mp={MP}, u3_mode=dynamic, P={P}, T0+-{BANDA}. Adversario del paper.\n")
    print(f"{'alpha':>6} | {'m_POS (D9-c)':>13} | {'m_BS medio':>11} {'max':>5} {'>1':>8} "
          f"| {'bloques disp.':>14}")
    for a in (0.0, 0.05, 0.10, 0.15, 0.25, 0.33, 0.40):
        rs = [menu_reactivo(a, s, P) for s in range(1, 13)]
        rs = [r for r in rs if r]
        if not rs:
            continue
        mp_ = statistics.mean(r[0] for r in rs)
        mb = statistics.mean(r[1] for r in rs)
        mx = max(r[2] for r in rs)
        n1 = sum(1 for r in rs if r[1] > 1.0)
        nb = statistics.mean(r[3] for r in rs)
        print(f"{a:>6.2f} | {mp_:>13.2f} | {mb:>11.2f} {mx:>5} {n1:>4}/{len(rs):<3} "
              f"| {nb:>14.1f}")
