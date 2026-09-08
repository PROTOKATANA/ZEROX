#!/usr/bin/env python3
"""
d8_a5b_equilibrio.py — A5 (segunda parte) · el EQUILIBRIO del sobornador, y su acoplamiento
con las constantes.

A5 midio, en simulacion, que sobornar `b` granjeros del cruce da un menu de EXACTAMENTE
`m = b+1` entropias (12 semillas, 21 umbrales, alpha = 0,00..0,40; `b=0 -> m=1`, control de
capacidad). El menu deja de depender de `alpha`: el sobornador no necesita espacio propio
para FABRICAR candidatos, solo dinero para RETIRARLOS.

Eso rompe el supuesto que sostiene las constantes. El diseno dimensiona `I` y `F` con la `m`
que un atacante consigue **produciendo sus propios bloques** (`m = 2,548`, D9-f). Con soborno
`m` es una variable de decision del atacante, no una propiedad del protocolo:

    valor del steering (bloques/epoca) = c_m * sqrt(alpha*lambda*I)    [dag-poas-voto-auditoria.md L197-199]
    coste del soborno  (bloques/epoca) >= b = m - 1                    [1 recompensa por granjero retirado]
    I = (c_m/g)^2 / (alpha*lambda)                                     [el propio mapa del diseno]

Se calculan tres cosas:
  (1) el `b` maximo que sigue siendo RENTABLE (valor/coste > 1) con las constantes publicadas;
  (2) el `m*` de un sobornador RACIONAL (maximiza valor - coste) y el PUNTO FIJO al
      redimensionar `I` y `F` para esa `m*`;
  (3) el tope duro: R-FIN-1a. Retirar `b` bloques de cadena consecutivos abre un hueco de
      `b/lambda` segundos; si supera `S_max` el siguiente bloque honesto es INVALIDO. Luego
      `m <= 1 + lambda*S_max`, **que es exactamente la «garantia por construccion» del diseno**:
      el soborno la convierte de cota lejana en objetivo alcanzable.

Sin `alpha` no hay steering que vender (fila alpha = 0: el soborno solo compra censura).
"""
import math
import sys

sys.path.insert(0, "/home/katana/zeo/ZEROX/research/scripts/d9-ronda8c")
from r8c_steering import c_m                                            # noqa: E402

G, WK, LAM = 0.036, 1.22, 1.0
I_PUB = 4200.0
CACHE = {}


def cm(m):
    m = int(round(m))
    if m < 1:
        return 0.0
    if m not in CACHE:
        CACHE[m] = c_m(m)
    return CACHE[m]


if __name__ == "__main__":
    print("=== A5b · equilibrio del sobornador y punto fijo de las constantes ===")
    print(f"g <= {G}, W/kappa <= {WK}, lambda = {LAM}. m = b+1 MEDIDO en d8_a5_soborno.py.\n")

    print("--- (1) rentabilidad con las constantes PUBLICADAS (I = 4 200 s) ---")
    print(f"{'alpha':>6} | " + " ".join(f"{'b='+str(b):>10}" for b in (1, 2, 4, 8, 16, 32, 64)))
    print(f"{'':>6} | " + " ".join(f"{'val/coste':>10}" for _ in range(7)))
    for a in (0.0, 0.10, 0.25, 0.33, 0.40):
        if a == 0:
            print(f"{a:>6.2f} | " + " ".join(f"{'-':>10}" for _ in range(7)) +
                  "   (sin espacio propio no hay steering que vender: solo censura)")
            continue
        fila = []
        for b in (1, 2, 4, 8, 16, 32, 64):
            val = cm(b + 1) * math.sqrt(a * LAM * I_PUB)
            fila.append(val / b)
        print(f"{a:>6.2f} | " + " ".join(f"{v:>10.2f}" for v in fila))
    print("\n   b maximo RENTABLE (valor/coste = 1):")
    for a in (0.10, 0.25, 0.33, 0.40):
        b = 1
        while b < 5000 and cm(b + 1) * math.sqrt(a * LAM * I_PUB) > b:
            b += 1
        print(f"      alpha={a:.2f}  ->  b_max = {b-1}   (m = {b})")

    print("\n--- (2) sobornador RACIONAL: m* = argmax (valor - coste), y punto fijo de I y F ---")
    print(f"{'alpha':>6} {'iter':>5} | {'m*':>6} {'c_m*':>8} {'I (s)':>9} {'I (h)':>8} "
          f"{'F (h)':>8} {'lookahead (h)':>14}")
    for a in (0.10, 0.25, 0.33, 0.40):
        I = I_PUB
        for it in range(12):
            mejor = max(range(1, 400), key=lambda m: cm(m) * math.sqrt(a * LAM * I) - (m - 1))
            c = cm(mejor)
            I2 = (c / G) ** 2 / (a * LAM)
            if abs(I2 - I) / I < 1e-4:
                I = I2
                break
            I = I2
        F = I / (WK - 1)
        print(f"{a:>6.2f} {it:>5} | {mejor:>6} {c:>8.4f} {I:>9.0f} {I/3600:>8.2f} "
              f"{F/3600:>8.2f} {(I+F)/3600:>14.2f}")

    print("\n--- (3) el tope duro es R-FIN-1a, que ES la «garantia por construccion» ---")
    print(f"{'S_max (s)':>10} {'m <= 1+lambda*S_max':>21} {'c_m':>8} {'I (h)':>8} "
          f"{'F (h)':>8} {'look (h)':>10} {'margen B hoy (41 h)':>20}")
    for S in (20, 30, 60, 150):
        m = 1 + int(LAM * S)
        c = cm(m)
        I = (c / G) ** 2 / (0.10 * LAM)
        F = I / (WK - 1)
        L = (I + F) / 3600
        print(f"{S:>10} {m:>21} {c:>8.4f} {I/3600:>8.2f} {F/3600:>8.2f} {L:>10.2f} "
              f"{41.0/L:>20.2f}")
    print("\n   El diseno trata `m <= 1+lambda*S_max` como una cota LEJANA (mide 2,548).")
    print("   Con soborno es un OBJETIVO ALCANZABLE a coste lineal: `b = m-1` recompensas.")
