#!/usr/bin/env python3
"""
r8e_a1c2_copias.py — versión REDUCIDA de `r8e_a1c_copias.py`, para que la comparación
peso 1 ↔ peso real en el régimen de COPIAS quepa en tiempo.

Diferencia declarada: la familia de estrategias es solo la GLOBAL (7 estrategias: la nula,
`sp`, y `retro` 1/2/4/8/16 aplicadas a TODOS los bloques del atacante de la banda), sin las
variantes bloque a bloque. Por eso el `m` de aquí **NO es comparable con el de A1 ni con el
de A1c**: solo son comparables las COLUMNAS entre sí, que es lo que se pregunta.

Criterio alpha: alpha=0 -> m = 1 y sp_discrepa = 0 en todas las configuraciones.
"""
import sys
from r8e_lib import MundoW, PesoCfg
from r8d_a1_menu import lee, ancla_T, BANDA, K, MP

HOR = 260.0
SEMS = list(range(1, 7))
POLS = ["sp", ("retro", 1), ("retro", 2), ("retro", 4), ("retro", 8), ("retro", 16)]


def menu(alpha, semilla, wcfg, copias, P=30):
    m = MundoW(alpha, HOR, semilla, k=K, mp=MP, u3_mode="dynamic", wcfg=wcfg)
    d0, tip0 = m.corre({}, copias=copias)
    ch0 = d0.selected_chain(tip0)
    if P >= len(ch0):
        return None
    tP = d0.B[ch0[P]].t
    T0 = d0.gd[ch0[P]].blue_score
    Ts = list(range(T0 - BANDA, T0 + BANDA + 1))
    idx = [i for i, (t, q, *_) in enumerate(m.ev) if q == "a" and tP - 30 <= t <= tP + 30]
    ests = [{}] + [{i: (0.0, pol) for i in idx} for pol in POLS]
    acum = {T: set() for T in Ts}
    spd = pd = sortd = 0
    for e in ests:
        d, tip = m.corre(e, copias=copias)
        c = d.cobertura()
        spd += c["sp_discrepa"]; pd += c["peso_distinto"]; sortd += c["sort_discrepa"]
        perfil = lee(d, tip)
        for T in Ts:
            s = ancla_T(perfil, T)
            if s is not None:
                acum[T].add(s)
    tam = [len(acum[T]) for T in Ts]
    return sum(tam) / len(tam), max(tam), spd, pd, sortd


CFGS = [
    ("peso 1", PesoCfg(W=None)),
    ("desliz W=200 g=.25", PesoCfg(W=200.0, gamma=0.25, modo="desliz")),
    ("desliz W=20 g=1.0", PesoCfg(W=20.0, gamma=1.0, modo="desliz")),
]

if __name__ == "__main__":
    print("=== A1c2 · menu en el regimen de COPIAS, peso 1 vs peso real (familia REDUCIDA) ===")
    print(f"k={K}, mp={MP}, horizonte {HOR:.0f} s, {len(SEMS)} semillas, P=30, T0+-{BANDA}.")
    print("Familia: 7 estrategias GLOBALES (nula, sp, retro 1/2/4/8/16). El `m` absoluto")
    print("NO es comparable con A1/A1c; solo las columnas entre si.\n")
    print(f"{'configuracion':>21} {'copias':>7} {'alpha':>6} | {'m_BS medio':>11} "
          f"{'m_BS max':>9} | {'sp!=':>7} {'sort!=':>8} {'peso!=1':>9}")
    for nombre, wcfg in CFGS:
        for cop in (0, 14):
            for alpha in (0.0, 0.25, 0.40):
                rs = [menu(alpha, s, wcfg, cop) for s in SEMS]
                rs = [r for r in rs if r]
                if not rs:
                    print(f"{nombre:>21} {cop:>7} {alpha:>6.2f} | sin datos"); continue
                print(f"{nombre:>21} {cop:>7} {alpha:>6.2f} | "
                      f"{sum(r[0] for r in rs)/len(rs):>11.2f} "
                      f"{max(r[1] for r in rs):>9} | {sum(r[2] for r in rs):>7} "
                      f"{sum(r[4] for r in rs):>8} {sum(r[3] for r in rs):>9}")
        print()
