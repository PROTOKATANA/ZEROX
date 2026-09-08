#!/usr/bin/env python3
"""
A · CONTROL POSITIVO. Antes de medir nada nuevo se reproducen numeros YA PUBLICADOS con el
mismo instrumento:
  1. frontera con F = 19 080 s, I = 4 200 s: 46,8784 % (delta=0) y 36,5431 % (delta D8)
     -- `research/scripts/d9-ronda9a/informe.md` §L5.1 y `verif_frontera_vs_F.salida.txt` L1.
  2. la fila F = 2 h / I = 851 s de la bitacora §11.4: 44,57 % / 35,08 % y las tres uniones.
  3. `F_carrera` de la bitacora §11.4: 0,28 h y 0,99 h al 33 %; 0,35 h y 1,92 h al 35 %.
El punto 3 se recalcula con `r10b_lib.f_carrera` (brentq directo sobre F), que es un camino
DISTINTO al del script del principal (brentq sobre `g(F)` con `set_F_I(F, 851)` dentro): si los
dos dan lo mismo, el instrumento de esta ronda esta validado.

CRITERIO ALPHA: la ultima tabla barre alpha; con alpha = 0 `prev()` devuelve 0 y F_carrera = 0.
"""
import time

import r10b_lib as L
import r9a_a3_frontera as A

hf0 = lambda a: 1.0
hfD8 = lambda a: 1 - A.delta_interp(a)

if __name__ == "__main__":
    t0 = time.time()
    print("=== A · control positivo de la ronda 10b ===")
    print("prev() = r9a_a3_frontera.prev = d8_a1c_riesgo.py:29-40 = verif_constantes.py:44-50\n")

    L.set_ventaja(90)                      # 3k con k = 30, el del diseno
    L.set_F_I(19080, 4200)
    fr0 = L.frontera_gruesa(hf0); frD = L.frontera_gruesa(hfD8)
    print(f"1 · F=19 080 s, I=4 200 s, ventaja 3k=90:")
    print(f"    frontera delta=0  = {fr0:.4%}   (publicado 46,8784 %)   {'OK' if abs(fr0-0.468784)<5e-5 else 'DIFIERE'}")
    print(f"    frontera delta D8 = {frD:.4%}   (publicado 36,5431 %)   {'OK' if abs(frD-0.365431)<5e-5 else 'DIFIERE'}")

    L.set_F_I(7200, 851)
    fr0 = L.frontera_gruesa(hf0); frD = L.frontera_gruesa(hfD8)
    u33 = A.union10(0.33, 1.0); u35 = A.union10(0.35, 1.0); u33D = A.union10(0.33, hfD8(0.33))
    print(f"\n2 · fila F = 2 h, I = 851 s (bitacora §11.4):")
    print(f"    frontera delta=0  = {fr0:.2%}   (publicado 44,57 %)   {'OK' if abs(fr0-0.4457)<1e-4 else 'DIFIERE'}")
    print(f"    frontera delta D8 = {frD:.2%}   (publicado 35,08 %)   {'OK' if abs(frD-0.3508)<1e-4 else 'DIFIERE'}")
    print(f"    union10(0,33; delta=0) = {u33:.2e} (publicado 1,4e-169)")
    print(f"    union10(0,35; delta=0) = {u35:.2e} (publicado 5,6e-129)")
    print(f"    union10(0,33; delta D8) = {u33D:.2e} (publicado 3,1e-32)")

    print(f"\n3 · F_carrera por brentq directo sobre F (camino distinto), I = 851 s, obj 1e-10:")
    pub = {(0.33, "d=0"): 1019, (0.35, "d=0"): 1249, (0.33, "dD8"): 3547, (0.35, "dD8"): 6900}
    for a, hf, nom in ((0.33, hf0, "d=0"), (0.35, hf0, "d=0"), (0.33, hfD8, "dD8"), (0.35, hfD8, "dD8")):
        F = L.f_carrera(a, hf(a))
        p = pub[(a, nom)]
        print(f"    alpha={a:.2f} {nom:>4}: F_carrera = {F:7.0f} s = {F/3600:.2f} h   "
              f"(publicado {p} s = {p/3600:.2f} h)   {'OK' if abs(F-p) <= 2 else 'DIFIERE'}")

    print(f"\n4 · CRITERIO ALPHA (el resultado debe moverse con alpha), delta = 0:")
    print(f"    {'alpha':>6} {'r':>7} {'F_carrera (s)':>14} {'(h)':>7}")
    for a in (0.0, 0.10, 0.25, 0.33, 0.35, 0.40, 0.45):
        F = L.f_carrera(a, 1.0)
        r = L.r_base(a, 1.0) if a > 0 else 0.0
        print(f"    {a:>6.2f} {r:>7.3f} {F:>14.0f} {F/3600:>7.2f}")
    print(f"\n[{time.time()-t0:.0f} s]")
