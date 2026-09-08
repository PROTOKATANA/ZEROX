#!/usr/bin/env python3
"""
B.3 · El OBJETIVO DE RIESGO. «Union a 10 anos < 1e-10» es una eleccion de diseno, no una ley.
Aqui se (1) reproduce lo que de hecho garantizan Bitcoin y GHOSTDAG/Chia, (2) se pone a ZEROX y a
Bitcoin BAJO EL MISMO CRITERIO, y (3) se tabula `F_carrera` para objetivos {1e-6,1e-8,1e-10,1e-12}.

FUENTES (fichero y linea; el PDF de Nakamoto NO esta en `research/fuentes/`, ver informe):
  * `research/fork-choice-reorg.md:193-195`: Grunspan & Perez-Marco (arXiv:1702.02867) corrigen un
    error real de Nakamoto §11 (usa Q_z donde va Q_{z+1}, SUBESTIMA el riesgo) y dan la forma
    cerrada exacta del doble gasto tras `z` confirmaciones:  P(z) = I_{4pq}(z, 1/2).
  * `research/fork-choice-reorg.md:197-208`: su Tabla 4 — `z` para P < 0,1 % (y la columna
    «Nakamoto optimista», que es lo que el paper de 2008 daba: 6 confirmaciones a q=10 %).
  * `research/fork-choice-reorg.md:210-215`: Rosenfeld (arXiv:1402.2009) Tabla 1.
  * `research/fuentes/phantom-ghostdag.txt:827-830`: el propio paper de GHOSTDAG fija su ejemplo
    con «an attacker with alpha <= 0.25, and an allowed error of epsilon = 0.1 %» -> 45 s.
  * `research/chia-documentacion-oficial.md:308-321`: Chia recomienda 6 bloques (~2 min) y 32
    (~10 min) bajo el supuesto «< 42.7 % (* vdf advantage) colluding»; NO publica un epsilon.

CONTROL POSITIVO (se ejecuta primero y debe pasar antes de mirar nada nuevo):
  (a) la Tabla 4 entera de Grunspan, 8 filas, con I_{4pq}(z,1/2);
  (b) la Tabla 1 de Rosenfeld, 10 celdas;
  (c) `F_carrera(33 %) = 1019 s / 3547 s` de la bitacora §11.4 (el instrumento de esta ronda).

CRITERIO ALPHA: todas las tablas barren alpha/q, y la fila alpha=0 da F_carrera = 0.
"""
import time

import numpy as np
from scipy.special import betainc

import r10b_lib as L
import r9a_a3_frontera as A

hf0 = lambda a: 1.0
hfD8 = lambda a: 1 - A.delta_interp(a)

# fork-choice-reorg.md:199-208 — (q, z_correcto, z_Nakamoto_optimista)
T4 = [(0.10, 6, 5), (0.15, 9, 8), (0.20, 13, 11), (0.25, 20, 15),
      (0.30, 32, 24), (0.35, 58, 41), (0.40, 133, 81), (0.45, 539, 340)]
# fork-choice-reorg.md:212-215 — Rosenfeld Tabla 1
T1 = {0.10: {1: 0.200, 2: 0.056, 3: 0.0171, 4: 0.00546, 6: 0.00059},
      0.20: {1: 0.400, 2: 0.208, 3: 0.11584, 4: 0.06669, 6: 0.02331}}
OBJS = [1e-6, 1e-8, 1e-10, 1e-12]
T_BLOQUE_BTC = 600.0                      # s
BLQ_10A = 10 * 365 * 24 * 3600 / T_BLOQUE_BTC


def p_doble_gasto(q, z):
    """Grunspan & Perez-Marco, forma cerrada exacta: P(z) = I_{4pq}(z, 1/2).
    `q` es la cuota del atacante: si no entrara aqui, todas las filas serian iguales."""
    if z <= 0:
        return 1.0
    return float(betainc(z, 0.5, 4 * q * (1 - q)))


def z_para(q, obj):
    """Menor z con P(z) < obj. Rejilla gruesa x2 + bisección (no pierde precision)."""
    if q >= 0.5:
        return None
    hi = 1
    while p_doble_gasto(q, hi) >= obj:
        hi *= 2
        if hi > 2 ** 22:
            return None
    lo = hi // 2
    while lo + 1 < hi:
        m = (lo + hi) // 2
        if p_doble_gasto(q, m) < obj:
            hi = m
        else:
            lo = m
    return hi


def f_evento(a, hf, eps, ventaja=90.0, lo=1.0, hi=200000.0):
    """F minima con `prev` POR EPOCA < eps (SIN union): el criterio por evento, que es el que
    usan Bitcoin (por transaccion) y el paper de GHOSTDAG (epsilon del comerciante).
    Misma `prev()` de d8_a1c_riesgo.py:29-40; monotona decreciente en F."""
    from scipy.optimize import brentq
    g = lambda F: np.log10(max(A.prev(a, 1.0, F, ventaja, hf), 1e-320)) - np.log10(eps)
    if g(lo) < 0:
        return 0.0
    if g(hi) > 0:
        return float("nan")
    return brentq(g, lo, hi, xtol=0.5)


if __name__ == "__main__":
    t0 = time.time()
    print("=== B.3 · el objetivo de riesgo: 1e-10 a 10 anos comparado con Bitcoin y Chia ===\n")

    print("--- CONTROL (a): Tabla 4 de Grunspan (fork-choice-reorg.md:199-208), z con P < 1e-3 ---")
    okA = True
    for q, zc, zn in T4:
        z = z_para(q, 1e-3)
        bien = (z == zc)
        okA &= bien
        print(f"    q={q:.0%}: z calculado {z:>4}   tabla {zc:>4}  {'OK' if bien else 'DIFIERE'}"
              f"   (Nakamoto optimista, transcrito: {zn})")
    print(f"    -> {'8/8 OK' if okA else 'HAY DIFERENCIAS'}\n")

    print("--- CONTROL (b): Tabla 1 de Rosenfeld (fork-choice-reorg.md:212-215) ---")
    okB = True
    for q in sorted(T1):
        fila = []
        for n, v in sorted(T1[q].items()):
            c = p_doble_gasto(q, n)
            bien = abs(c - v) < 6e-4
            okB &= bien
            fila.append(f"n={n}: {c:.5f} vs {v:.5f} {'OK' if bien else 'DIF'}")
        print(f"    q={q:.2f}  " + " | ".join(fila))
    print(f"    -> {'10/10 OK' if okB else 'HAY DIFERENCIAS'}\n")

    print("--- CONTROL (c): F_carrera(33 %) del instrumento de esta ronda (bitacora §11.4) ---")
    L.set_ventaja(90)
    c0 = L.f_carrera(0.33, 1.0); cD = L.f_carrera(0.33, hfD8(0.33))
    print(f"    delta=0: {c0:.0f} s (publicado 1019)  {'OK' if abs(c0-1019)<=2 else 'DIFIERE'}   "
          f"delta D8: {cD:.0f} s (publicado 3547)  {'OK' if abs(cD-3547)<=2 else 'DIFIERE'}\n")

    print("=== 1 · lo que de hecho se garantiza por ahi fuera, en las MISMAS unidades ===")
    print("    Bitcoin (practica): 6 confirmaciones a q=10 %  ->  P(doble gasto) = "
          f"{p_doble_gasto(0.10, 6):.2e} POR TRANSACCION, ~60 min")
    print("    Bitcoin a q=33 %, 6 confirmaciones            ->  P = "
          f"{p_doble_gasto(0.33, 6):.2e} POR TRANSACCION  (el 1e-3 se pierde por completo)")
    z33 = z_para(0.33, 1e-3)
    print(f"    Bitcoin a q=33 % para P < 1e-3               ->  z = {z33} bloques = "
          f"{z33*T_BLOQUE_BTC/3600:.1f} h")
    print("    GHOSTDAG (paper, L827-830): alpha <= 0,25 y epsilon = 0,1 % -> 45 s de espera")
    print("    Chia (chia-documentacion-oficial.md:308-321): 6 bloques (~2 min) natural, 32 "
          "(~10 min)\n        contra foliage re-org, bajo «< 42,7 % colluding». NO publica epsilon: LAGUNA.\n")

    print("=== 2 · ZEROX y Bitcoin BAJO EL MISMO CRITERIO (union a 10 anos < obj) ===")
    print(f"    ZEROX: {365*86400/L.I_DIS*10:.0f} epocas en 10 anos (I = {L.I_DIS:.0f} s). "
          f"Bitcoin: {BLQ_10A:.0f} bloques (T = 600 s).")
    print(f"{'objetivo':>10} | {'ZEROX F_carrera d=0':>21} {'d D8':>12} | "
          f"{'BTC z (q=33 %)':>15} {'BTC horas':>10} | {'BTC z (q=10 %)':>15} {'horas':>7}")
    for obj in OBJS:
        L.set_ventaja(90)
        f0 = L.f_carrera(0.33, 1.0, obj=obj)
        fD = L.f_carrera(0.33, hfD8(0.33), obj=obj)
        zb = z_para(0.33, obj / BLQ_10A)
        zb10 = z_para(0.10, obj / BLQ_10A)
        print(f"{obj:>10.0e} | {f0:>13.0f} s {f0/3600:>6.2f} h {fD/3600:>10.2f} h | "
              f"{zb:>15} {zb*T_BLOQUE_BTC/3600:>10.1f} | {zb10:>15} {zb10*T_BLOQUE_BTC/3600:>7.1f}")

    print("\n=== 3 · el mismo objetivo, tambien a alpha = 35 % (criterio alpha) ===")
    print(f"{'objetivo':>10} | {'F_carrera 33 % d=0':>19} {'35 % d=0':>10} | "
          f"{'33 % d D8':>11} {'35 % d D8':>11}")
    for obj in OBJS:
        L.set_ventaja(90)
        vals = [L.f_carrera(a, hf(a), obj=obj) / 3600
                for a, hf in ((0.33, hf0), (0.35, hf0), (0.33, hfD8), (0.35, hfD8))]
        print(f"{obj:>10.0e} | {vals[0]:>17.2f} h {vals[1]:>8.2f} h | "
              f"{vals[2]:>9.2f} h {vals[3]:>9.2f} h")

    print("\n=== 4 · el objetivo POR EVENTO que 1e-10/10 anos implica, y el de Bitcoin ===")
    n_ep = 365 * 86400 / L.I_DIS * 10
    print(f"    ZEROX  1e-10 en {n_ep:.0f} epocas  ->  {1e-10/n_ep:.2e} por epoca (por evento)")
    print(f"    Bitcoin practica                ->  {p_doble_gasto(0.10,6):.2e} por transaccion")
    print(f"    razon: el criterio de ZEROX es {p_doble_gasto(0.10,6)/(1e-10/n_ep):.2e} veces mas "
          f"estricto POR EVENTO que la practica de Bitcoin.")
    print("    Y al reves: la F que le bastaria a ZEROX con el criterio POR EVENTO de Bitcoin")
    print("    (P(reversion mas alla de F) < eps en UNA epoca, sin union; ERROR PROPIO corregido:")
    print("     la primera version pedia esto con `f_carrera`, que aplica la union y satura en 1).")
    print(f"      {'alpha':>6} {'modelo':>6} | {'F(eps=1e-3)':>12} {'(min)':>7} | {'F(eps=1e-6)':>12} {'(min)':>7}")
    for a, hf, nom in ((0.33, hf0, "d=0"), (0.33, hfD8, "d D8"), (0.35, hf0, "d=0"), (0.35, hfD8, "d D8")):
        f3 = f_evento(a, hf(a), 1e-3)
        f6 = f_evento(a, hf(a), 1e-6)
        print(f"      {a:>6.2f} {nom:>6} | {f3:>10.0f} s {f3/60:>7.1f} | {f6:>10.0f} s {f6/60:>7.1f}")

    print("\n=== 5 · criterio alpha del propio objetivo (delta = 0, obj 1e-10 vs 1e-6) ===")
    print(f"{'alpha':>6} | {'F(1e-6)':>9} {'F(1e-10)':>10} {'F(1e-12)':>10} | {'coste 1e-6->1e-12':>18}")
    for a in (0.0, 0.10, 0.25, 0.33, 0.35, 0.40):
        L.set_ventaja(90)
        f6 = L.f_carrera(a, 1.0, obj=1e-6)
        f10 = L.f_carrera(a, 1.0, obj=1e-10)
        f12 = L.f_carrera(a, 1.0, obj=1e-12)
        print(f"{a:>6.2f} | {f6:>9.0f} {f10:>10.0f} {f12:>10.0f} | {(f12-f6):>15.0f} s")
    print(f"\n[{time.time()-t0:.0f} s]")
