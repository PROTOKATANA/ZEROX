#!/usr/bin/env python3
"""
B.2 (iii) REHECHO con el `delta` medido a cada k — la LAGUNA queda CERRADA.

`r10b_b2_k.py` tabla (iii) uso `delta(0,33) = 0,2867` para los cuatro k porque el `delta` de D8
esta medido solo a k = 30. `r10b_b2b_delta_k.py` lo ha medido a k in {20,25,30,40} (misma
maniobra parasita de d8_lib, 12 semillas, 1920 corridas, y la fila k=30 reproduce
`d8-ronda8/salida_a1b.txt` en las 8 filas). Aqui se propaga a `F_carrera`.

FUENTE de los numeros de abajo: `research/scripts/d9-ronda10b/salida_b2b.txt` L52-55 (bloque
DELTA_K) y L8-48 (las tablas con IC95 de 12 semillas). NO son de memoria.
"""
import time

import r10b_lib as L

# salida_b2b.txt L52-55 (media de 12 semillas en el J* de peor caso)
DELTA_K = {
    20: {0.00: 0.0005, 0.25: 0.1498, 0.30: 0.2035, 0.33: 0.2425, 0.35: 0.2903,
         0.37: 0.3601, 0.40: 0.4022, 0.45: 0.5745},
    25: {0.00: 0.0000, 0.25: 0.1528, 0.30: 0.1897, 0.33: 0.2824, 0.35: 0.3279,
         0.37: 0.3515, 0.40: 0.3915, 0.45: 0.5690},
    30: {0.00: 0.0000, 0.25: 0.1544, 0.30: 0.2079, 0.33: 0.2867, 0.35: 0.3065,
         0.37: 0.3448, 0.40: 0.4366, 0.45: 0.5834},
    40: {0.00: 0.0000, 0.25: 0.1553, 0.30: 0.2187, 0.33: 0.2514, 0.35: 0.3171,
         0.37: 0.3579, 0.40: 0.4619, 0.45: 0.6133},
}
# salida_b2b.txt: intervalos de confianza al 95 % en alpha = 0,33 y 0,35
IC33 = {20: (0.2145, 0.2706), 25: (0.2594, 0.3055), 30: (0.2650, 0.3085), 40: (0.2197, 0.2831)}

if __name__ == "__main__":
    t0 = time.time()
    print("=== B.2c · modelo (iii) con el `delta` de D8 RE-MEDIDO a cada k (LAGUNA cerrada) ===")
    print("delta de salida_b2b.txt (12 semillas, maniobra parasita, Delta=4 s, k-coherente en "
          "mp/msl).\n")
    print(f"{'k':>4} {'3k':>5} {'delta(0,33)':>12} {'IC95':>18} {'delta(0,35)':>12} | "
          f"{'F_carrera 33 %':>15} {'(h)':>6} | {'35 %':>10} {'(h)':>6} | {'antes (0,2867)':>15}")
    for k in (20, 25, 30, 40):
        d33, d35 = DELTA_K[k][0.33], DELTA_K[k][0.35]
        L.set_ventaja(3 * k)
        f33 = L.f_carrera(0.33, 1 - d33)
        f35 = L.f_carrera(0.35, 1 - d35)
        ant = L.f_carrera(0.33, 1 - 0.2867)          # la fila antigua, no recalibrada
        lo, hi = IC33[k]
        print(f"{k:>4} {3*k:>5} {d33:>12.4f} [{lo:.4f},{hi:.4f}] {d35:>12.4f} | "
              f"{f33:>13.0f} s {f33/3600:>6.2f} | {f35:>8.0f} s {f35/3600:>6.2f} | "
              f"{ant/3600:>13.2f} h")

    print("\n--- cuanto de esa F es incertidumbre de la MEDIDA (extremos del IC95 a 33 %) ---")
    print(f"{'k':>4} | {'F con delta bajo':>17} {'F con delta medio':>18} {'F con delta alto':>17}")
    for k in (20, 25, 30, 40):
        L.set_ventaja(3 * k)
        lo, hi = IC33[k]
        fl = L.f_carrera(0.33, 1 - lo); fm = L.f_carrera(0.33, 1 - DELTA_K[k][0.33])
        fh = L.f_carrera(0.33, 1 - hi)
        print(f"{k:>4} | {fl/3600:>15.2f} h {fm/3600:>16.2f} h {fh/3600:>15.2f} h")

    print("\n--- criterio alpha: F_carrera(alpha) con el delta medido a cada k ---")
    print(f"{'alpha':>6} | " + " ".join(f"{'k=%d' % k:>10}" for k in (20, 25, 30, 40)))
    for a in (0.0, 0.25, 0.30, 0.33, 0.35, 0.37):
        fila = []
        for k in (20, 25, 30, 40):
            L.set_ventaja(3 * k)
            fila.append(L.f_carrera(a, 1 - DELTA_K[k][a]))
        print(f"{a:>6.2f} | " + " ".join(f"{f:>10.0f}" for f in fila))
    print(f"\n[{time.time()-t0:.0f} s]")
