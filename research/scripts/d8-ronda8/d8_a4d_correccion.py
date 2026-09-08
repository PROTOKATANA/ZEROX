#!/usr/bin/env python3
"""
d8_a4d_correccion.py — A4 · CORRECCION DE UN ERROR MIO.

En la primera version del cierre de A4 escribi que la retencion hasta `S_max` da `m = 2,955`
y que eso obliga a subir `I` y `F` porque el diseno usa `m = 2,548`. **Es una comparacion
mal hecha.** El mapa del diseno es

        I(m, alpha) = (c_m/g)^2 / (alpha*lambda)

y va como `1/alpha`: el peor caso NO es la `m` mas grande, es el `max` sobre `alpha` del
`I` que resulta de la pareja CONSISTENTE `(m(alpha), alpha)`. D9-f toma `alpha = 0,10` por
eso, y su `m = 2,548` es la medida A ESE alpha. Mi 2,955 es a `alpha = 0,40`, donde `I` se
divide por 4.

Aqui se hace la cuenta bien: `I(m(alpha), alpha)` para cada `alpha`, con las `m` que mide
`d8_a4c_rachas.py` (familia de D8) y con las de D9-f donde existen, y se toma el maximo.
"""
import math
import sys

sys.path.insert(0, "/home/katana/zeo/ZEROX/research/scripts/d9-ronda8c")
from r8c_steering import c_m                                             # noqa: E402

G, WK, LAM = 0.036, 1.22, 1.0
CACHE = {}


def cm(m):
    lo, hi = math.floor(m), math.ceil(m)
    for x in (lo, hi):
        if x not in CACHE:
            CACHE[x] = c_m(x)
    return CACHE[lo] if lo == hi else CACHE[lo] + (m - lo) * (CACHE[hi] - CACHE[lo])


# m MEDIDA por d8_a4c_rachas.py (familia D8: 37 estrategias globales, retrasos 0..S_max=150 s
# + retencion total, horizonte 900 s, 12 semillas, 37 umbrales por corrida)
M_D8 = {0.10: 2.282, 0.25: 2.822, 0.33: 2.905, 0.40: 2.955}
# m MEDIDA por D9-f (familia r8e_a1c: pols global Y bloque a bloque, ventana +-30 s,
# copias 0 y 14, horizonte 260 s) — salida_b1_gran1.txt y salida_c.txt
M_D9F = {0.10: 2.238, 0.25: 2.540, 0.40: 3.024}
M_D9F_RET = {0.10: 2.548}      # «+retencion, slot», la que el diseno usa

if __name__ == "__main__":
    print("=== A4d · la cuenta bien hecha: max sobre alpha de I(m(alpha), alpha) ===")
    print(f"g = {G}, W/kappa = {WK}, lambda = {LAM}. I = (c_m/g)^2/(alpha*lambda); "
          f"F = I/(W/kappa - 1); lookahead = I + F.\n")
    for nombre, tabla in (("D8 (familia global + retencion hasta S_max)", M_D8),
                          ("D9-f (familia bloque a bloque, sin retencion)", M_D9F),
                          ("D9-f «+retencion» — LA QUE USA EL DISENO", M_D9F_RET)):
        print(f"--- {nombre} ---")
        print(f"{'alpha':>6} {'m':>8} {'c_m':>8} {'I (s)':>9} {'I (h)':>7} {'F (h)':>7} "
              f"{'look (h)':>9} {'margen B 10x':>13}")
        peor = None
        for a in sorted(tabla):
            c = cm(tabla[a])
            I = (c / G) ** 2 / (a * LAM)
            F = I / (WK - 1)
            L = (I + F) / 3600
            print(f"{a:>6.2f} {tabla[a]:>8.3f} {c:>8.4f} {I:>9.0f} {I/3600:>7.2f} "
                  f"{F/3600:>7.2f} {L:>9.2f} {4.1/L:>13.2f}")
            if peor is None or L > peor[0]:
                peor = (L, a, I, F)
        print(f"   -> PEOR CASO: alpha = {peor[1]:.2f}, I = {peor[2]:.0f} s "
              f"({peor[2]/3600:.2f} h), F = {peor[3]/3600:.2f} h, lookahead = {peor[0]:.2f} h\n")

    print("CONCLUSION. El peor caso de la familia de D8 (alpha = 0,10) da un lookahead MENOR")
    print("que el del diseno, porque mi familia a alpha = 0,10 es MAS PEQUENA que la de D9-f")
    print("(37 estrategias globales frente a global + bloque a bloque con ventana +-30 s).")
    print("Luego A4 NO obliga a rehacer las constantes: la `m = 2,548` del diseno sigue siendo")
    print("la cota mas alta medida en el punto que manda, que es alpha = 0,10.")
    print("Mi afirmacion anterior («m = 2,955 obliga a subir I y F») era una comparacion entre")
    print("alphas distintos y es INCORRECTA. Queda retirada.")
