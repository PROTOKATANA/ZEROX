#!/usr/bin/env python3
"""
C (segunda parte) · La condicion que hay que MEDIR para poder bajar `F`.

C dice cual es la `F` minima por modelo. Esto dice lo inverso, que es lo que Katana necesita para
decidir: **dado un `F`, hasta que `Delta` se conserva el colchon de 2 puntos** (frontera >= 35 %),
y **dado un `Delta`, cual es la `F` minima con 2 puntos**. Reutiliza `delta_max` y `d0_interp` de
`r10b_b5_delta_red.py` sin reescribirlos.

CONTROL: `delta_max(F, alpha=0.33)` debe reproducir la tabla de B.5 (13,6 / 16,1 / 18,0 s).
CRITERIO ALPHA: las dos columnas son alpha = 0,33 (umbral operativo) y 0,35 (umbral + 2 puntos).
"""
import time

import numpy as np

import r10b_lib as L
from r10b_b5_delta_red import D0, d0_interp, delta_max, delta_r1

PUB_B5 = {0.5: 13.6, 1.0: 16.1, 2.0: 18.0}          # salida_b5.txt, tabla «Delta MAXIMO»

if __name__ == "__main__":
    t0 = time.time()
    print("=== C.2 · el Delta que cada F tolera, con y sin los 2 puntos de colchon ===\n")
    print("--- CONTROL: reproducir la columna Delta_max(33 %) de salida_b5.txt ---")
    ok = True
    for F, pub in sorted(PUB_B5.items()):
        d = delta_max(F * 3600, alpha=0.33)
        bien = abs(d - pub) < 0.15
        ok &= bien
        print(f"    F = {F:.2f} h: Delta_max = {d:.1f} s (publicado {pub})  "
              f"{'OK' if bien else 'DIFIERE'}")
    print(f"    -> {'3/3 OK' if ok else 'HAY DIFERENCIAS'}")
    print(f"    r = 1 en Delta = {delta_r1(0.33):.1f} s (33 %) y {delta_r1(0.35):.1f} s (35 %)\n")

    print("--- Delta maximo tolerable por F: al 33 % (sin colchon) y al 35 % (+2 puntos) ---")
    print(f"{'F (h)':>7} {'F (s)':>8} | {'Delta_max 33 %':>15} | {'Delta_max 35 % (+2 pts)':>24}")
    for Fh in (0.35, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0, 5.3):
        d33 = delta_max(Fh * 3600, alpha=0.33)
        d35 = delta_max(Fh * 3600, alpha=0.35)
        s33 = f"{d33:>15.1f}" if np.isfinite(d33) else f"{'ninguno':>15}"
        s35 = f"{d35:>24.1f}" if np.isfinite(d35) else f"{'ninguno':>24}"
        print(f"{Fh:>7.2f} {Fh*3600:>8.0f} | {s33} | {s35}")

    print("\n--- y al reves: la F minima con +2 puntos, en funcion del Delta que se mida ---")
    print(f"{'Delta (s)':>10} {'delta_0':>9} | {'F_carrera 33 %':>15} {'(h)':>7} | "
          f"{'F MINIMA +2 pts':>16} {'(h)':>7} {'(min)':>7}")
    for D in (4, 6, 8, 10, 12, 13, 14, 15, 16, 18, 20):
        d = d0_interp(float(D))
        L.set_ventaja(90)
        f33 = L.f_carrera(0.33, 1 - d)
        f35 = L.f_carrera(0.35, 1 - d)
        s33 = f"{f33:>13.0f} s {f33/3600:>7.2f}" if np.isfinite(f33) else f"{'sin cruce':>13} {'':>9}"
        s35 = (f"{f35:>14.0f} s {f35/3600:>7.2f} {f35/60:>7.0f}" if np.isfinite(f35)
               else f"{'sin cruce':>14} {'':>16}")
        print(f"{D:>10} {d:>9.4f} | {s33} | {s35}")
    print(f"\n[{time.time()-t0:.0f} s]")
