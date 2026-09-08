#!/usr/bin/env python3
"""
r10c_e_palanca_L.py — HALLAZGO ADICIONAL (no pedido por el encargo): `L` es una palanca aparte
de `F`, y es JUSTO la palanca que acorta la ventana del sembrador sin tocar `F`.

Hoy el diseno ata `L = F` (`dag-poas-ancla-de-orden.md`, nota de R-FIN-7: «ZEROX I = 4 200 s,
F = L = 5,3 h»), y la ronda 7 ya habia dejado escrita la alternativa sin explotarla
(`dag-poas-ancla-de-finalidad.md:99`: «L rezago de aplicacion; candidatos: L = F (incondicional)
o L ~ F/4 (probabilistico)»). Pero el lookahead del sembrador es

      lookahead = (L - W_dec) + I(1 - 1/rho)          (punto A, VERIFICADO)

es decir, depende de **L**, no de F. Y `F` es lo que fija la frontera y la garantia por regla.
Desatarlos permite elegir cada cosa con su palanca.

QUE EXIGE `L` POR SI SOLA. `L` es la profundidad a la que el ancla `I_j` debe estar ACORDADA
cuando se aplica en `t_j = slot(I_j) + L`. Si dos honestos leen anclas distintas, el flujo se
parte (R-FIN-5: los flujos no se fusionan). Esa probabilidad es la misma reorganizacion que
mide `prev()`, evaluada en `L`. Luego  L >= F_carrera(alpha_obj, modelo)  — el MISMO numero que
`r10c_c2_frontera.py` calcula para F, pero aplicado a L.

QUE SE PAGA. La tolerancia a particiones pasa de `F` a `L`: una particion mas larga que `L` puede
dar dos anclas distintas y dos flujos irreconciliables, aunque dure menos que `F`.

Criterio de variacion: todo cambia con alpha (via F_carrera), con rho y con I.
"""
import os
import sys

import numpy as np
from scipy.optimize import brentq

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import r10c_lib as L  # noqa: E402

A10 = L.A_ESTRELLA_10X_H["B"] * 3600.0
WD = L.w_dec_de(0.33)
I = 851.0


def f_carrera(alpha, I_, hf):
    def g(F):
        return np.log10(max(L.union10(alpha, hf(alpha), F, I_), 1e-320)) + 10.0
    return brentq(g, 30.0, 400000.0, xtol=1.0)


print("=" * 116)
print("E1 · CONTROL: L_min = F_carrera, con el mismo instrumento (debe reproducir C2a)")
print("=" * 116)
for a in (0.33, 0.35):
    for nom, hf in (("delta = 0", L.hf_delta0), ("delta D8", L.hf_d8)):
        v = f_carrera(a, I, hf)
        print(f"   alpha = {a:.2f}  {nom:>9}:  L_min = {v:7.0f} s = {v/3600:.2f} h")

print()
print("=" * 116)
print("E2 · DESATAR L DE F: que compra cada pareja (I = 851 s, alpha objetivo = 0,33)")
print("=" * 116)
print(f"{'L':>18} {'F':>18} {'rho':>5} | {'lookahead (s)':>14} {'margen A*10x':>13} "
      f"{'W/kappa = look/F':>17} {'BDK 1,00?':>10} | {'tol. particion':>15}")
for Ln, Lv in (("F_carrera d=0 0,28 h", 1019.0), ("F_carrera D8 0,99 h", 3547.0),
               ("1 h", 3600.0), ("2 h (atado)", 7200.0)):
    for Fn, Fv in (("1 h", 3600.0), ("2 h", 7200.0), ("5,3 h", 19080.0)):
        if Lv > Fv:
            continue
        for rho in (1.0, 1.5, 3.0):
            look = L.cinematica_rapida(rho, Lv, I, WD, False)[0]
            look = max(look, 1.0 + L.LAM * L.D_AUT) if rho <= 1.0 else look
            mar = A10 / look
            wk = look / Fv
            print(f"{Ln:>18} {Fn:>18} {rho:>5.3g} | {look:>14.1f} {mar:>12.1f}x "
                  f"{wk:>17.4f} {'SI' if wk <= 1.0 else 'no':>10} | {Lv/3600:>14.2f} h")

print()
print("=" * 116)
print("E3 · LA CONFIGURACION QUE SALE DE AHI, contra las dos atadas")
print("=" * 116)
print(f"{'configuracion':>34} | {'lookahead':>11} {'margen 10x':>11} {'W/kappa':>9} "
      f"{'frontera fijada por':>20} {'tol. particion':>15} {'garantia':>9}")
casos = [("ATADA  L = F = 1 h, rho=3", 3600.0, 3600.0, 3.0),
         ("ATADA  L = F = 2 h, rho=3", 7200.0, 7200.0, 3.0),
         ("DESATADA L = 1 h, F = 2 h, rho=3", 3600.0, 7200.0, 3.0),
         ("DESATADA L = 1 h, F = 2 h, rho=1,5", 3600.0, 7200.0, 1.5),
         ("DESATADA L = 0,99 h, F = 5,3 h, rho=3", 3547.0, 19080.0, 3.0),
         ("(h) L = F = 2 h, rho=3", 7200.0, 7200.0, 3.0)]
for nom, Lv, Fv, rho in casos:
    ret = nom.startswith("(h)")
    look = L.cinematica_rapida(rho, Lv, I, WD, ret)[0]
    print(f"{nom:>34} | {look:>11.0f} {A10/look:>10.1f}x {look/Fv:>9.4f} "
          f"{'F = ' + f'{Fv/3600:.2f} h':>20} {Lv/3600:>14.2f} h {Fv/3600:>8.2f} h")
print()
print("   `frontera fijada por F` y `garantia por regla = F` no cambian al desatar; lo que cambia")
print("   es que el SEMBRADOR paga L y la PARTICION tolerada baja de F a L.")
