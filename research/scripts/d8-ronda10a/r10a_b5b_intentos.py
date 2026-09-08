#!/usr/bin/env python3
"""
D8 ronda 10a · B.5.b — ¿cubre la cota de la union el «elegir cuándo atacar»?

El argumento de B.6 es este, y hay que ponerle numero:

  `union10(alpha) = prev(alpha) * N` con `N` = epocas en 10 anos, es una COTA DE LA UNION sobre
  `N` instantes de arranque. Para cualquier conjunto `S` de instantes de arranque,
  `P(union de exitos sobre S) <= |S| * prev(alpha)`. Elegir la mejor ventana dentro del lookahead
  es elegir un `S`, no cambiar `prev`. Luego, mientras `|S| <= N`, la frontera publicada YA lo cubre
  y sumar el exceso al `offset` seria contarlo dos veces.

  Pero `|S|` no siempre es `<= N`: con `V < I` el atacante distingue MAS ventanas que epocas hay.
  Aqui se mide la sensibilidad de la frontera al numero de intentos, multiplicandolo por
  factores de 1 a 851 (= I, el maximo: un intento por segundo).

Control positivo: con factor 1 hay que reproducir 46,8784 % / 36,5432 % a (F, I) = (19 080, 4 200),
que es lo que publica `verif_frontera_vs_F.salida.txt`.
"""
import math
import sys

import numpy as np
from scipy.optimize import brentq

sys.path.insert(0, "/home/katana/zeo/ZEROX/research/scripts/d9-ronda9a")
import r9a_a3_frontera as A                     # noqa: E402

K = 30


def set_F_I(F, I):
    A.F_SEG = float(F)
    A.I_EP = float(I)
    A.EP_ANO = 365 * 24 * 3600 / A.I_EP


def frontera_factor(hf, factor, offset=3 * K, lo=0.20, hi=0.499, paso=0.005):
    """Frontera con `factor` veces mas intentos en la union. `factor` es el unico parametro nuevo:
    todo lo demas es el `prev()` de 9a sin tocar."""
    def f(a):
        pf = A.prev(a, 1.0, A.F_SEG, offset, hf(a))
        return math.log10(max(min(1.0, pf * A.EP_ANO * A.ANOS * factor), 1e-320)) + 10.0
    ant = None
    for a in np.arange(lo, hi + 1e-9, paso):
        v = f(a)
        if ant is not None and ant[1] < 0 <= v:
            return brentq(f, ant[0], a, xtol=1e-5)
        ant = (a, v)
    return float("nan")


def main():
    hf0 = lambda a: 1.0                          # noqa: E731
    hfD = lambda a: 1 - A.delta_interp(a)        # noqa: E731
    print("=" * 110)
    print("CONTROL — factor = 1 tiene que dar 46,8784 % / 36,5432 % con (F, I) = (19 080, 4 200)")
    set_F_I(19080, 4200)
    f0 = frontera_factor(hf0, 1.0)
    fD = frontera_factor(hfD, 1.0)
    ok = abs(f0 - 0.468784) < 1e-5 and abs(fD - 0.365432) < 1e-5
    print(f"  {f0:.4%} / {fD:.4%}   [{'IDENTICO' if ok else 'DISCREPA'}]")

    print("=" * 110)
    print("B.5.b — SENSIBILIDAD de la frontera al numero de intentos de la union")
    print("        factor 851 = un intento por SEGUNDO en vez de uno por epoca (I = 851 s)")
    print(f"{'F (h)':>6} {'I':>5} {'factor':>8} {'intentos/10 anos':>18} | {'frontera delta=0':>17} "
          f"{'vs factor 1':>12} | {'frontera delta D8':>18} {'vs factor 1':>12}")
    for F, I in ((7200, 851), (3600, 851), (19080, 4200)):
        set_F_I(F, I)
        b0 = frontera_factor(hf0, 1.0)
        bD = frontera_factor(hfD, 1.0)
        for factor in (1.0, 2.22, 10.0, 100.0, float(I)):
            n = A.EP_ANO * A.ANOS * factor
            a0 = frontera_factor(hf0, factor)
            aD = frontera_factor(hfD, factor)
            print(f"{F/3600:>6.2f} {I:>5} {factor:>8.2f} {n:>18.3e} | {a0:>17.4%} {a0-b0:>+12.4%} | "
                  f"{aD:>18.4%} {aD-bD:>+12.4%}")

    print("=" * 110)
    print("B.5.c — CUANTAS ventanas distingue el atacante, frente a cuantos intentos une la cota")
    print(f"{'L (h)':>6} {'I':>5} {'rho':>5} {'reg.':>8} {'V (s)':>7} | {'ventanas en 10 anos':>20} "
          f"{'epocas en 10 anos':>18} {'|S|/N':>8} {'¿cubierto?':>11}")
    diez = 10 * 365 * 24 * 3600.0
    for L, I in ((7200.0, 851.0), (3600.0, 851.0)):
        N = diez / I
        for rho in (1.05, 1.2, 1.5, 2.0, 2.5, 3.0):
            for etiq, V in (("sin (h)", L + I * (1 - 1 / rho)), ("con (h)", (L + I) * (1 - 1 / rho))):
                if V < 1.0:
                    continue
                S = diez / V
                print(f"{L/3600:>6.2f} {I:>5.0f} {rho:>5.2f} {etiq:>8} {V:>7.0f} | {S:>20.3e} "
                      f"{N:>18.3e} {S/N:>8.3f} {'si' if S <= N else 'NO':>11}")


if __name__ == "__main__":
    main()
