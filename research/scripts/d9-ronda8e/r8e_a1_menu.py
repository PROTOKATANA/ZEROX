#!/usr/bin/env python3
"""
r8e_a1_menu.py — LINEA A1. El menu `m` del ancla `blue_score` CON EL PESO REAL.

D9-d midio `m` con `blue_work = blue_score` (peso 1). Aqui se repite EXACTAMENTE el mismo
experimento — mismas semillas, mismo `P`, misma banda de umbrales, MISMA familia dirigida
de estrategias, importada literalmente de `r8d_a1_menu.py` — cambiando solo el peso:

    blue_work(B) = blue_work(sp) + Σ_{h ∈ mergeset_blues(B)} w(SR(h))    protocol.rs:155-161

con el retarget de R-FIN-13 en dos formas (`desliz` = la de Kaspa, por bloque, sobre
ventana deslizante; `epoca` = la lectura literal «ventana de W slots»).

Se declaran SIEMPRE, junto a cada fila, los contadores de COBERTURA DE RAMA: si
`peso!=1` es 0 la rama no corrio y la fila no dice nada; si `sp!=` es 0, el peso corrio
pero NO cambio ninguna decision de GHOSTDAG.

Configuraciones (`eps` = sd(ln w) MEDIDA en el horizonte, no supuesta):
   W=None        peso 1 — CONTROL, debe reproducir la tabla de D9-d cifra a cifra
   W=3083, g=.25 PUNTO DE DISEÑO de R-FIN-13
   W=80,   g=.25 eps ~7x el de diseño
   W=20,   g=.25 eps ~33x
   W=20,   g=1.0 eps ~130x  (viola R-FIN-13, sirve de cota superior)

Criterio alpha: con alpha=0 el menu debe valer 1 en todas las configuraciones.
"""
import sys
from r8e_lib import MundoW, PesoCfg
from r8d_a1_menu import estrategias, lee, ancla_T, BANDA, K, MP

HOR = 260.0
SEMS = list(range(1, 13))

CFGS = [
    ("peso 1 (D9-d)", PesoCfg(W=None)),
    ("desliz W=3083 g=.25", PesoCfg(W=3083.0, gamma=0.25, modo="desliz")),
    ("desliz W=80 g=.25", PesoCfg(W=80.0, gamma=0.25, modo="desliz")),
    ("desliz W=20 g=.25", PesoCfg(W=20.0, gamma=0.25, modo="desliz")),
    ("desliz W=20 g=1.0", PesoCfg(W=20.0, gamma=1.0, modo="desliz")),
    ("epoca  W=20 g=.25", PesoCfg(W=20.0, gamma=0.25, modo="epoca")),
]


def menus_peso(alpha, semilla, wcfg, P=30, u3_mode="dynamic"):
    """Copia funcional de `r8d_a1_menu.menus` con `MundoW` en vez de `Mundo`. La familia
    de estrategias y la lectura se IMPORTAN de D9-d, no se reescriben."""
    m = MundoW(alpha, HOR, semilla, k=K, mp=MP, u3_mode=u3_mode, wcfg=wcfg)
    d0, tip0 = m.corre({})
    ch0 = d0.selected_chain(tip0)
    if P >= len(ch0):
        return None
    tP = d0.B[ch0[P]].t
    T0 = d0.gd[ch0[P]].blue_score
    Ts = list(range(T0 - BANDA, T0 + BANDA + 1))
    tiers, idx = estrategias(m, tP)

    acum_pos = set()
    acum_bs = {T: set() for T in Ts}
    res_pos, res_bs_med, res_bs_max = [], [], []
    cob = dict(peso=0, inc=0, spd=0, sortd=0, sppd=0, retg=0, sd=0.0, n=0)
    for g in tiers:
        for e in g:
            d, tip = m.corre(e)
            c = d.cobertura()
            cob["peso"] += c["peso_distinto"]; cob["inc"] += c["inc_distinto"]
            cob["spd"] += c["sp_discrepa"]; cob["sortd"] += c["sort_discrepa"]
            cob["sppd"] += c["sp_pesos_dist"]; cob["retg"] += c["retargets"]
            cob["sd"] += c["spread_lnw"]; cob["n"] += 1
            perfil = lee(d, tip)
            if P < len(perfil):
                acum_pos.add(perfil[P][1])
            for T in Ts:
                s = ancla_T(perfil, T)
                if s is not None:
                    acum_bs[T].add(s)
        res_pos.append(len(acum_pos))
        tam = [len(acum_bs[T]) for T in Ts]
        res_bs_med.append(sum(tam) / len(tam))
        res_bs_max.append(max(tam))
    cob["sd"] /= max(cob["n"], 1)
    return res_pos, res_bs_med, res_bs_max, len(idx), cob


if __name__ == "__main__":
    P = int(sys.argv[1]) if len(sys.argv) > 1 else 30
    print("=== A1 · menu del ancla BLUE_SCORE con PESO REAL frente al de D9-d (peso 1) ===")
    print(f"k={K}, mp={MP}, lambda=1, Delta=4, horizonte {HOR:.0f} s, u3_mode=dynamic, "
          f"P={P}, T0+-{BANDA}, semillas 1..12.")
    print("Menu contado sobre `seed` (fijado en la creacion). Adversario del paper (sin retardo).")
    print("Familia de estrategias IMPORTADA de r8d_a1_menu.py — identica a la de D9-d.\n")
    print(f"{'configuracion':>21} {'alpha':>6} | {'m_BS gratis':>12} {'+retraso':>10} "
          f"{'+retencion':>11} | {'m_POS gratis':>13} | {'eps=sd(lnw)':>11} "
          f"{'peso!=1':>9} {'w!=':>7} {'sp!=':>6} {'sort!=':>7}")
    for nombre, wcfg in CFGS:
        for alpha in (0.0, 0.10, 0.25, 0.33, 0.40):
            filas = [menus_peso(alpha, s, wcfg, P) for s in SEMS]
            filas = [f for f in filas if f is not None]
            if not filas:
                print(f"{nombre:>21} {alpha:>6.2f} sin datos"); continue
            bs = [[f[1][t] for f in filas] for t in range(3)]
            pos = [f[0][0] for f in filas]
            C = [f[4] for f in filas]
            print(f"{nombre:>21} {alpha:>6.2f} | "
                  + " ".join(f"{sum(b)/len(b):>12.2f}" if i == 0 else
                             f"{sum(b)/len(b):>10.2f}" if i == 1 else
                             f"{sum(b)/len(b):>11.2f}" for i, b in enumerate(bs))
                  + f" | {sum(pos)/len(pos):>13.2f} | "
                  f"{sum(c['sd'] for c in C)/len(C):>11.5f} "
                  f"{sum(c['peso'] for c in C):>9} "
                  f"{sum(c['sppd'] for c in C):>7} "
                  f"{sum(c['spd'] for c in C):>6} "
                  f"{sum(c['sortd'] for c in C):>7}")
        print()
    print("Referencia D9-d (salida_a1_menu.txt), m_BS medio gratis / +retraso / +retencion:")
    print("  a=0.00  1.00 / 1.00 / 1.00   a=0.10  2.33 / 3.38 / 4.35")
    print("  a=0.25  3.03 / 4.29 / 7.53   a=0.33  3.17 / 4.32 / 8.24   a=0.40  3.25 / 4.34 / 8.17")
