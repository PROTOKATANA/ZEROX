#!/usr/bin/env python3
"""
r8d_a2c_sesgo.py — COMPROBACION de un resultado que no me esperaba (A2b): el ancla
BLUE_SCORE cae en un bloque del ATACANTE mas a menudo que la fraccion de bloques de
cadena que son suyos. Si el ancla fuera neutral, la probabilidad de caer en un bloque
del atacante seria su cuota de UMBRALES = (suma de sus incrementos)/(blue_score total),
no su cuota de BLOQUES.

Se mide sobre la cadena ENTERA (no una banda), sin ninguna estrategia: el atacante juega
limpio (publica al instante en las puntas). Adversario del paper (sin retardo).

Criterio alpha: alpha = 0 -> todas las cuotas del atacante = 0.
"""
import sys
from r8d_lib import Mundo
from r8d_a1_menu import K, MP


def cuotas(alpha, semilla, T=900.0):
    m = Mundo(alpha, T, semilla, k=K, mp=MP, u3_mode="dynamic")
    d, tip = m.corre({})
    ch = d.selected_chain(tip)
    inc_a = inc_h = n_a = n_h = 0
    for i in range(1, len(ch)):
        inc = d.gd[ch[i]].blue_score - d.gd[ch[i - 1]].blue_score
        if d.B[ch[i]].creator == "a":
            inc_a += inc; n_a += 1
        else:
            inc_h += inc; n_h += 1
    return n_a, n_h, inc_a, inc_h


if __name__ == "__main__":
    print("=== A2c · ?esta SESGADO el ancla blue_score hacia el atacante? ===")
    print(f"k={K}, mp={MP}, u3_mode=dynamic, cadena entera, horizonte 900 s, 8 semillas.\n")
    print(f"{'alpha':>6} | {'% BLOQUES de cadena':>20} | {'% UMBRALES (cuota bs)':>22} "
          f"| {'incr. medio atac.':>18} {'incr. medio hon.':>17}")
    for a in (0.0, 0.05, 0.10, 0.25, 0.33, 0.40):
        rs = [cuotas(a, s) for s in range(1, 9)]
        na = sum(r[0] for r in rs); nh = sum(r[1] for r in rs)
        ia = sum(r[2] for r in rs); ih = sum(r[3] for r in rs)
        pb = na / (na + nh) if na + nh else 0
        pu = ia / (ia + ih) if ia + ih else 0
        print(f"{a:>6.2f} | {pb:>19.1%} | {pu:>21.1%} "
              f"| {ia/na if na else 0:>18.2f} {ih/nh if nh else 0:>17.2f}")
