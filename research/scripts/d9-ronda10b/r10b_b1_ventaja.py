#!/usr/bin/env python3
"""
B.1 · La palanca «ventaja inicial». `F_carrera` con ventaja `3k`, `2k`, `1,68k` y `k` (k = 30).

FUENTE DEL «0,56 * 3k» (localizada, con fichero y linea):
  research/scripts/d8-ronda8/salida_a6b.txt L14-18 (bloque alpha = 0.33): la fila `J = 64` da
  `ventaja MAX = 50`, `/k = 1.67`, `/3k = 0.56`, `n_medidas = 7144`.
  Cabecera del mismo fichero L2: k=30, 3k=90, mp=15, lambda=1, Delta=4.0, horizonte 1800 s,
  12 semillas, maniobra parasita.  Script: d8-ronda8/d8_a6b_lineas.py:73-80 (`ventaja_max`).
  Transcrito en d8-ronda8/informe.md:427-430 y en dag-poas-ancla-de-orden-auditoria-7.md:183.
  1,68k = 0,56*3k = 50,4  (la medida entera es 50).

En `union10` la ventaja entra como `3*A.K`; aqui se fija `A.K = ventaja/3` (ver r10b_lib).
El `k` fisico NO cambia: `prev()` no lo usa. Esto aisla la palanca.

CRITERIO ALPHA: fila alpha = 0 en la tabla (F_carrera = 0: sin atacante no hay carrera) y
barrido de alpha en la ultima tabla.
"""
import time

import r10b_lib as L
import r9a_a3_frontera as A

hf0 = lambda a: 1.0
hfD8 = lambda a: 1 - A.delta_interp(a)
K_FIS = 30
VENT = [("3k", 3 * K_FIS), ("2k", 2 * K_FIS), ("1,68k (0,56*3k, medida D8)", 1.68 * K_FIS),
        ("k", 1.0 * K_FIS)]

if __name__ == "__main__":
    t0 = time.time()
    print("=== B.1 · ventaja inicial de la carrera (Lema 10) ===")
    print("k fisico = 30 en todas las filas; solo cambia el desplazamiento 3k de la carrera.")
    print(f"I = {L.I_DIS:.0f} s, objetivo union 10 anos < 1e-10.\n")

    print(f"{'ventaja':>28} {'valor':>7} | {'F_carrera 33 % d=0':>20} {'35 % d=0':>12} "
          f"| {'33 % dD8':>12} {'35 % dD8':>12}")
    for nom, v in VENT:
        L.set_ventaja(v)
        f33 = L.f_carrera(0.33, hf0(0.33)); f35 = L.f_carrera(0.35, hf0(0.35))
        d33 = L.f_carrera(0.33, hfD8(0.33)); d35 = L.f_carrera(0.35, hfD8(0.35))
        print(f"{nom:>28} {v:>7.1f} | {f33:>13.0f} s {f33/3600:>5.2f} h {f35/3600:>10.2f} h "
              f"| {d33/3600:>10.2f} h {d35/3600:>10.2f} h")

    print("\n--- criterio alpha: ventaja 3k vs 1,68k a lo largo de alpha (delta = 0) ---")
    print(f"{'alpha':>6} | {'3k = 90':>12} {'1,68k = 50,4':>14} {'k = 30':>10} | {'ahorro 3k->1,68k':>17}")
    for a in (0.0, 0.10, 0.25, 0.33, 0.35, 0.40):
        fs = []
        for _, v in ((None, 90), (None, 50.4), (None, 30)):
            L.set_ventaja(v)
            fs.append(L.f_carrera(a, 1.0))
        aho = (fs[0] - fs[1]) / fs[0] if fs[0] > 0 else 0.0
        print(f"{a:>6.2f} | {fs[0]:>10.0f} s {fs[1]:>12.0f} s {fs[2]:>8.0f} s | {aho:>16.1%}")

    print("\n--- sensibilidad: cuanta F compra cada bloque de ventaja (delta = 0, alpha = 0,33) ---")
    print(f"{'ventaja':>8} {'F_carrera (s)':>14} {'dF/dventaja (s/bloque)':>24}")
    ant = None
    for v in (0, 15, 30, 45, 50.4, 60, 75, 90, 120):
        L.set_ventaja(max(v, 1e-9))
        F = L.f_carrera(0.33, 1.0)
        d = "" if ant is None else f"{(F-ant[1])/(v-ant[0]):>24.1f}"
        print(f"{v:>8.1f} {F:>14.0f} {d}")
        ant = (v, F)
    print(f"\n[{time.time()-t0:.0f} s]")
