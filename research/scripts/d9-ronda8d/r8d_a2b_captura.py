#!/usr/bin/env python3
"""
r8d_a2b_captura.py — LINEA A2 (2). ?Puede el atacante CAPTURAR el ancla, es decir, hacer
que el bloque que cruza c*j sea SUYO?

Distincion que importa: si el ancla cae en un bloque honesto, el atacante solo ELIGE entre
`m` entropias que no controla (steering). Si cae en un bloque SUYO, elige la entropia
DIRECTAMENTE: puede molerla (regrinding) con cualquier cosa que module su `chunk`/slot, y
el menu efectivo deja de ser `m` y pasa a ser el que le de su capacidad de computo.

Se mide, por umbral T y sobre la familia dirigida de tier 1 (GRATIS):
  p_cap = fraccion de umbrales para los que EXISTE una estrategia gratis que pone un
          bloque del ATACANTE como primer bloque de cadena con blue_score >= T.
  p_nat = fraccion de umbrales cuyo ancla ya es del atacante SIN hacer nada (referencia).

Criterio alpha: alpha = 0 -> p_cap = p_nat = 0.
"""
import sys
from r8d_lib import Mundo
from r8d_a1_menu import K, MP, BANDA


def perfil_bid(d, tip):
    return [(d.gd[b].blue_score, b, d.B[b].creator) for b in d.selected_chain(tip)]


def cruza(perfil, T):
    for bs, b, cr in perfil:
        if bs >= T:
            return b, cr
    return None, None


def captura(alpha, semilla, P=30, T_hor=260.0):
    m = Mundo(alpha, T_hor, semilla, k=K, mp=MP, u3_mode="dynamic")
    d0, tip0 = m.corre({})
    ch0 = d0.selected_chain(tip0)
    if P >= len(ch0):
        return None
    tP = d0.B[ch0[P]].t
    T0 = d0.gd[ch0[P]].blue_score
    Ts = list(range(T0 - BANDA, T0 + BANDA + 1))
    idx = [i for i, (t, q, *_) in enumerate(m.ev) if q == "a" and tP - 30 <= t <= tP + 30]
    ests = [{}]
    for pol in ("sp", ("retro", 1), ("retro", 2), ("retro", 4)):
        ests.append({i: (0.0, pol) for i in idx})
    for i in idx:
        for pol in ("sp", ("retro", 1), ("retro", 3)):
            ests.append({i: (0.0, pol)})
    p0 = perfil_bid(d0, tip0)
    nat = sum(1 for T in Ts if cruza(p0, T)[1] == "a")
    cap = set()
    for e in ests:
        d, tip = m.corre(e)
        pf = perfil_bid(d, tip)
        for T in Ts:
            if cruza(pf, T)[1] == "a":
                cap.add(T)
    return nat / len(Ts), len(cap) / len(Ts)


if __name__ == "__main__":
    P = int(sys.argv[1]) if len(sys.argv) > 1 else 30
    print("=== A2b · captura del ancla BLUE_SCORE por el atacante ===")
    print(f"k={K}, mp={MP}, u3_mode=dynamic, P={P}, {2*BANDA+1} umbrales, 12 semillas.")
    print("tier 1 GRATIS: publicacion inmediata, solo eleccion de padres.\n")
    print(f"{'alpha':>6} | {'p_nat (sin atacar)':>19} | {'p_cap (eligiendo padres)':>25}")
    for a in (0.0, 0.05, 0.10, 0.25, 0.33, 0.40):
        rs = [captura(a, s, P) for s in range(1, 13)]
        rs = [r for r in rs if r]
        pn = sum(r[0] for r in rs) / len(rs)
        pc = sum(r[1] for r in rs) / len(rs)
        print(f"{a:>6.2f} | {pn:>18.1%} | {pc:>24.1%}")
