#!/usr/bin/env python3
"""
r10c_a2_ancla_mc.py — PUNTO A, parte estocastica (regla 5: >= 12 semillas).

La cinematica de A1 supone `slot(I_j) = T_j + delta_ancla` con `delta_ancla = 0`. Bajo R-FIN-1
el ancla es el bloque de MENOR blue_work con `slot >= T_j` de la cadena seleccionada, asi que
`delta_ancla = slot(I_j) - T_j >= 0` y desplaza `t_j = slot(I_j) + L`, es decir, desplaza el tope
de conocimiento del atacante SLOT A SLOT (`cap = I + delta_ancla + L - 1 - W_dec`).

Aqui se MIDE `delta_ancla` con el simulador de 9c (`r9c_lib.MundoR9`, que ya lleva R-FIN-1a como
regla de validez y la clausura de publicacion), 12 semillas literales, S_max in {20, 150},
alpha in {0; 0,10; 0,25; 0,33; 0,40} y varias T_j; y se propaga a la cota de A1.

Criterio alpha: la fila alpha = 0 esta; y `delta_ancla` debe crecer con alpha (el atacante puede
retener y desplazar el ancla) o declararse que no se mueve.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                                 "..", "d9-ronda9c")))
import r10c_lib as L                                            # noqa: E402
from r9c_lib import MundoR9, SEMILLAS, COB, slot_de, eventos_atacante  # noqa: E402

HOR = 1200.0
TJS = [200.0, 400.0, 600.0, 800.0, 1000.0]
ALPHAS = [0.00, 0.10, 0.25, 0.33, 0.40]

print("=" * 100)
print("A2 · delta_ancla = slot(I_j) - T_j  MEDIDO (12 semillas literales, simulador de 9c)")
print(f"     semillas = {SEMILLAS}")
print(f"     horizonte {HOR:.0f} s, T_j en {TJS}")
print("=" * 100)
print(f"{'S_max':>6} {'alpha':>6} | {'n':>4} {'media':>7} {'p90':>6} {'max':>5} | "
      f"{'con retencion: media':>21} {'p90':>6} {'max':>5}")

res = {}
for smax in (150, 20):
    for a in ALPHAS:
        libre, ret = [], []
        for s in SEMILLAS:
            mu = MundoR9(a, HOR, s, s_max=smax)
            d0, tip0 = mu.corre()
            for T in TJS:
                sd, tc = mu.ancla(d0, tip0, T)
                if sd is not None:
                    libre.append(slot_de(tc) - T)
            # peor caso para el atacante: retiene TODOS sus bloques del entorno de cada T_j
            idx = eventos_atacante(mu, 0.0, HOR)
            est = {i: (None, "tips_pub") for i in idx}
            d1, tip1 = mu.corre(est)
            for T in TJS:
                sd, tc = mu.ancla(d1, tip1, T)
                if sd is not None:
                    ret.append(slot_de(tc) - T)

        def q(v, p):
            v = sorted(v)
            return v[min(len(v) - 1, int(p * len(v)))] if v else float("nan")
        res[(smax, a)] = (max(libre) if libre else 0, max(ret) if ret else 0)
        print(f"{smax:>6} {a:>6.2f} | {len(libre):>4} {sum(libre)/len(libre):>7.2f} "
              f"{q(libre,0.9):>6.0f} {max(libre):>5.0f} | {sum(ret)/len(ret):>21.2f} "
              f"{q(ret,0.9):>6.0f} {max(ret):>5.0f}")

print()
print("Cobertura de rama (COB, acumulada):")
for kk, vv in sorted(COB.items()):
    print(f"   {kk:>22} = {vv}")
print("   Ramas con 0: se declaran en el informe (no ejercitadas).")

print()
print("=" * 100)
print("A2b · propagacion a la cota de A1: cuanto mueve delta_ancla el lookahead del sembrador")
print("=" * 100)
dmax = max(v[1] for v in res.values())
print(f"   delta_ancla maximo medido (peor alpha, peor S_max, con retencion) = {dmax:.0f} s")
print(f"{'F':>8} {'I':>5} {'rho':>5} | {'look (delta=0)':>15} {'look (delta=max)':>17} {'dif rel':>9}")
for F in (3600.0, 7200.0):
    for rho in (1.5, 3.0):
        wd = L.w_dec_de(0.33)
        a0, _, _ = L.cinematica_rapida(rho, F, 851.0, wd, False, delta_ancla=0.0)
        a1, _, _ = L.cinematica_rapida(rho, F, 851.0, wd, False, delta_ancla=float(dmax))
        print(f"{F:>8.0f} {851:>5} {rho:>5.3g} | {a0:>15.1f} {a1:>17.1f} {(a1-a0)/a0:>8.2%}")
