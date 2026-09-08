#!/usr/bin/env python3
"""
B.1 (segunda parte) · ¿es legitimo disenar con la ventaja MEDIDA (0,56*3k) en vez de la cota 3k?

D8 midio el maximo de `adv` sobre 12 semillas x 1 800 s (salida_a6b.txt L2 y L14-18). La union
que define `F_carrera` corre sobre 10 ANOS. La cola estacionaria de `adv` en el Lema 10 es
geometrica de base `r = alpha/((1-alpha)(1-delta))` (phantom-ghostdag.txt L1232-1236: «the
stationary distribution is governed by an exponent with base alpha/((1-alpha)(1-delta))»), luego
el maximo sobre N observaciones crece como ln(N)/ln(1/r). Aqui se extrapola.

Etiqueta del resultado: PLAUSIBLE (argumento de valor extremo sobre la cola que el paper declara;
no es una medida y no cierra el argumento).
"""
import numpy as np

N_D8 = 12 * 1800.0                       # bloques observados por D8 (lambda = 1/s)
N_10A = 365 * 24 * 3600 * 10.0           # bloques en 10 anos
MEDIDO = {0.10: 17, 0.25: 30, 0.33: 50, 0.40: 41}   # salida_a6b.txt, maximo sobre J

if __name__ == "__main__":
    print("=== B.1b · extrapolacion del maximo de la ventaja de 1 800 s a 10 anos ===")
    print(f"N_D8 = {N_D8:.0f} bloques, N_10anos = {N_10A:.3g} bloques, razon {N_10A/N_D8:.0f}x\n")
    print(f"{'alpha':>6} {'r (delta=0)':>12} {'medido D8':>10} {'incremento':>11} "
          f"{'max 10 anos est.':>17} {'vs 3k = 90':>11}")
    for a in sorted(MEDIDO):
        r = a / (1 - a)
        inc = np.log(N_10A / N_D8) / np.log(1 / r)
        est = MEDIDO[a] + inc
        print(f"{a:>6.2f} {r:>12.3f} {MEDIDO[a]:>10d} {inc:>11.1f} {est:>17.1f} "
              f"{('POR DEBAJO' if est < 90 else 'LA SUPERA'):>11}")
    print("\nLectura: la cota 3k no se satura ni extrapolada a 10 anos, pero el margen a")
    print("alpha = 0,33 pasa de 40 bloques (90-50) a 26 (90-63,5). Y la extrapolacion supone")
    print("estacionariedad y una sola cola geometrica: es PLAUSIBLE, no VERIFICADO.")
