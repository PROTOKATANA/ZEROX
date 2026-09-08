#!/usr/bin/env python3
"""
C · ENTREGA. La `F` mas corta que conserva >= 2 PUNTOS de colchon sobre el 33 % en cada modelo
y configuracion, y el peso de `I`.

IDENTIDAD QUE SE USA (y se comprueba antes de usarla): «frontera(F) = 35 %» y
«F_carrera(35 %) = F» son la MISMA ecuacion, porque las dos dicen union10 = 1e-10 en (F, 35 %).
La frontera es el PRIMER cruce en alpha y `union10` crece con alpha mientras `r < 1`, asi que la
equivalencia vale exactamente donde `r(0,35) < 1`. Se verifica numericamente en el control 2.

MODELOS (los cinco que las rondas 8-10 dejan sobre la mesa; B.4 argumenta cual se usa):
  M1  delta = 0                      — 9a, atacante de espacio unico, Delta = 4 s
  M2  delta_0(Delta = 8 s)  = 0,0020 — atacante de RED barato (9a A6)
  M3  delta_0(Delta = 12 s) = 0,0828 — atacante de red medio
  M4  delta_0(Delta = 16 s) = 0,2858 — atacante de red fuerte; el limite que `k = 30` aguanta
  M5  delta de D8 (0,2867 / 0,3065)  — el pesimista de la auditoria 7; 9a lo declara doble conteo
  M6  delta_real(k=30) = 0,267, lambda_real = 1,364 — el sesgo del retarget; 9b lo anula (R-FIN-13')

`I` entra SOLO por el numero de epocas de la union (EP_ANO = 365*86400/I): mas epocas, union mas
exigente, `F` mas larga. Se barre I in {300, 491, 602, 851, 4200} s (los candidatos de
`auditoria-8c.md` §3 y la bitacora §6.1) para medir cuanto pesa.

CRITERIO ALPHA: las tablas llevan 33 % y 35 % y la ultima barre alpha.
"""
import time

import numpy as np

import r10b_lib as L
import r9a_a3_frontera as A

D_REAL, LAM_REAL = 0.267, 1.364          # dag-poas-delta-real.md L32 (k = 30)
hfD8 = lambda a: 1 - A.delta_interp(a)

MODELOS = [
    ("M1  delta = 0 (9a, Delta = 4 s)", lambda a: 1.0, 1.0),
    ("M2  delta_0(Delta = 8 s) = 0,0020", lambda a: 1 - 0.0020, 1.0),
    ("M3  delta_0(Delta = 12 s) = 0,0828", lambda a: 1 - 0.0828, 1.0),
    ("M4  delta_0(Delta = 16 s) = 0,2858", lambda a: 1 - 0.2858, 1.0),
    ("M5  delta de D8 (pesimista)", hfD8, 1.0),
    ("M6  delta_real(k=30) + lambda_real", lambda a: 1 - D_REAL, LAM_REAL),
]
IS = [300.0, 491.0, 602.0, 851.0, 4200.0]
FS_CAND = [0.5, 0.75, 1.0, 1.5, 2.0, 3.0]


def frontera_de_F(F, hf, I, lam=1.0):
    """La frontera (primer cruce union = 1e-10) a esa F. Con lam != 1 se usa `union_lam`."""
    L.set_F_I(F, I)
    f = lambda a: np.log10(max(L.union_lam(a, hf(a), lam), 1e-320)) + 10.0
    from scipy.optimize import brentq
    ant = None
    for a in np.arange(0.20, 0.499 + 1e-9, 0.005):
        v = f(a)
        if ant is not None and ant[1] < 0 <= v:
            return brentq(f, ant[0], a, xtol=1e-5)
        ant = (a, v)
    return float("nan")


if __name__ == "__main__":
    t0 = time.time()
    print("=== C · la F mas corta con >= 2 puntos de colchon sobre el 33 % ===\n")

    print("--- CONTROL 1: fila F = 2 h, I = 851 s de la bitacora §11.4 (44,57 % / 35,08 %) ---")
    L.set_ventaja(90)
    f0 = frontera_de_F(7200, lambda a: 1.0, 851.0)
    fD = frontera_de_F(7200, hfD8, 851.0)
    print(f"    delta=0 {f0:.2%} {'OK' if abs(f0-0.4457)<1e-4 else 'DIFIERE'}   "
          f"delta D8 {fD:.2%} {'OK' if abs(fD-0.3508)<1e-4 else 'DIFIERE'}\n")

    print("--- CONTROL 2: la identidad «frontera(F_carrera(35 %)) = 35 %» ---")
    for nom, hf, lam in MODELOS:
        L.set_ventaja(90)
        F = L.f_carrera(0.35, hf(0.35), lam=lam)
        fr = frontera_de_F(F, hf, L.I_DIS, lam) if np.isfinite(F) else float("nan")
        print(f"    {nom:>36}: F_carrera(35 %) = {F:>7.0f} s -> frontera = {fr:.4%}  "
              f"{'OK' if np.isfinite(fr) and abs(fr-0.35) < 3e-4 else 'DIFIERE'}")

    print(f"\n=== TABLA C · la F minima por modelo (I = {L.I_DIS:.0f} s, ventaja 3k = 90, "
          f"obj 1e-10 a 10 anos) ===")
    print(f"{'modelo':>36} | {'F_carrera 33 %':>15} | {'F MINIMA (+2 pts)':>18} {'(h)':>7} "
          f"| {'r(0,35)':>8}")
    fmin = {}
    for nom, hf, lam in MODELOS:
        L.set_ventaja(90)
        f33 = L.f_carrera(0.33, hf(0.33), lam=lam)
        f35 = L.f_carrera(0.35, hf(0.35), lam=lam)
        fmin[nom] = f35
        r35 = L.r_base(0.35, hf(0.35))
        print(f"{nom:>36} | {f33:>10.0f} s {f33/3600:>4.2f} h | {f35:>16.0f} s {f35/3600:>7.2f} "
              f"| {r35:>8.3f}")

    print("\n=== COLCHON REAL de cada F candidata, por modelo (frontera - 33 %) ===")
    print(f"{'modelo':>36} | " + " ".join(f"{'F=%.2fh' % F:>9}" for F in FS_CAND))
    for nom, hf, lam in MODELOS:
        fila = []
        for F in FS_CAND:
            L.set_ventaja(90)
            fr = frontera_de_F(F * 3600, hf, L.I_DIS, lam)
            fila.append(f"{(fr-0.33)*100:>+8.1f}p" if np.isfinite(fr) else f"{'nan':>9}")
        print(f"{nom:>36} | " + " ".join(fila))

    print(f"\n=== EL PESO DE `I` (entra solo por EP_ANO = 365*86400/I) ===")
    print(f"{'I (s)':>7} {'epocas/ano':>11} {'epocas 10 a':>12} | "
          f"{'F_carr 33 % M1':>15} {'F min M1':>10} | {'F_carr 33 % M5':>15} {'F min M5':>10}")
    for I in IS:
        L.set_ventaja(90)
        a1 = L.f_carrera(0.33, 1.0, I=I); b1 = L.f_carrera(0.35, 1.0, I=I)
        a5 = L.f_carrera(0.33, hfD8(0.33), I=I); b5 = L.f_carrera(0.35, hfD8(0.35), I=I)
        print(f"{I:>7.0f} {365*86400/I:>11.0f} {365*86400/I*10:>12.0f} | "
              f"{a1:>13.0f} s {b1:>8.0f} s | {a5:>13.0f} s {b5:>8.0f} s")
    print("    (I = 300 s vs 851 s: 2,84x mas epocas; el efecto es logaritmico, ver informe)")

    print("\n=== criterio alpha: F minima con +2 puntos sobre distintos umbrales operativos ===")
    print(f"{'umbral':>7} {'objetivo':>9} | " + " ".join(f"{n.split()[0]:>9}" for n, _, _ in MODELOS))
    for u in (0.25, 0.30, 0.33, 0.35):
        fila = []
        for nom, hf, lam in MODELOS:
            L.set_ventaja(90)
            f = L.f_carrera(u + 0.02, hf(u + 0.02), lam=lam)
            fila.append(f"{f:>9.0f}" if np.isfinite(f) else f"{'sin cruce':>9}")
        print(f"{u:>7.0%} {u+0.02:>9.0%} | " + " ".join(fila))
    print(f"\n[{time.time()-t0:.0f} s]")
