#!/usr/bin/env python3
"""
r10c_c_reversion.py — PUNTO C. Lo que espera el usuario, no lo que garantiza `F`.

`F` es el limite de reorganizacion (R-FIN-7): una garantia POR REGLA. Un comerciante no espera
`F`: espera a que la probabilidad de reversion baje. Aqui se tabula esa probabilidad a
{60, 300, 600, 1 800, 3 600} s para alpha in {0,10; 0,25; 0,33} con los dos modelos:

  · CORREGIDO (9a):  delta = 0, ventaja inicial 3k = 90  (`hf = 1`)
  · PESIMISTA (D8):  delta(alpha) MEDIDO por D8, interpolado (`hf = 1 - delta`)

Instrumento: `prev()` de `d9-ronda9a/r9a_a3_frontera.py`, que es LITERALMENTE
`verif_constantes.py:44-50` y `d8-ronda8/d8_a1c_riesgo.py:29-40`. No se reescribe el modelo.
El control positivo (P1/P2 de r10c_c0_control.py) ya reprodujo 2,45e-7 / 6,59e-8 / 1,11e-7 y la
fila alpha = 0,33 de `salida_a1c.txt` (5,538e-01 y 2,059e-103).

VALIDACION INDEPENDIENTE (C2): Monte Carlo del mismo proceso (12 semillas), en el regimen
alpha in {0,40; 0,45; 0,48} donde la probabilidad es medible por muestreo. No se puede validar
por MC a 1e-8; se dice y se acota.

Criterio alpha: fila alpha = 0 (riesgo exactamente 0) en todas las tablas.
"""
import os
import sys
import multiprocessing as mp

import numpy as np
from scipy.optimize import brentq

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import r10c_lib as L  # noqa: E402

TS = [60.0, 300.0, 600.0, 1800.0, 3600.0]
ALPHAS = [0.0, 0.10, 0.25, 0.33]
SEMILLAS = [11, 23, 37, 41, 59, 67, 73, 89, 97, 101, 113, 127]   # 12, literales (las de 9c)


def tabla():
    print("=" * 104)
    print("C1 · PROBABILIDAD DE REVERSION frente al tiempo de espera del comerciante")
    print(f"     k = {L.K}, lambda = 1 bloque/s, ventaja inicial 3k = {3*L.K} (Lema 10 de GHOSTDAG)")
    print("     NO depende de F: `prev()` no lleva F. F solo entra en la union a 10 anos y en la")
    print("     frontera (C3). Esto es lo que decide la espera del usuario.")
    print("=" * 104)
    for nom, hf in (("CORREGIDO (9a, delta = 0)", L.hf_delta0), ("PESIMISTA (delta medido por D8)", L.hf_d8)):
        print(f"\n--- {nom} ---")
        print(f"{'alpha':>6} {'delta':>7} {'r':>7} | " + " ".join(f"{t:>11.0f} s" for t in TS))
        for a in ALPHAS:
            d = 0.0 if hf is L.hf_delta0 else L.delta_interp(a)
            h = hf(a)
            r = a / ((1 - a) * h) if a > 0 else 0.0
            fila = " ".join(f"{L.prev(a, 1.0, t, 3 * L.K, h):>13.3e}" for t in TS)
            print(f"{a:>6.2f} {d:>7.4f} {r:>7.3f} | {fila}")


def espera_para(umbral):
    print()
    print("=" * 104)
    print(f"C1b · SEGUNDOS DE ESPERA para que la reversion baje de cada umbral (brentq sobre t)")
    print("=" * 104)
    print(f"{'modelo':>32} {'alpha':>6} | " + " ".join(f"{u:>13.0e}" for u in umbral))
    for nom, hf in (("CORREGIDO (delta = 0)", L.hf_delta0), ("PESIMISTA (delta D8)", L.hf_d8)):
        for a in (0.10, 0.25, 0.33):
            cel = []
            for u in umbral:
                f = lambda t, a=a, hf=hf, u=u: np.log10(max(L.prev(a, 1.0, t, 3 * L.K, hf(a)), 1e-320)) - np.log10(u)
                try:
                    if f(30.0) < 0:
                        cel.append("      < 30 s")
                    elif f(200000.0) > 0:
                        cel.append("    > 55,6 h")
                    else:
                        cel.append(f"{brentq(f, 30.0, 200000.0, xtol=0.5):>10.0f} s")
                except ValueError:
                    cel.append("       n/d")
            print(f"{nom:>32} {a:>6.2f} | " + " ".join(f"{c:>13}" for c in cel))


# ------------------------------------------------------------------ C2 · Monte Carlo independiente
def _mc(args):
    a, hf, t, semilla, n, tope = args
    rng = np.random.default_rng(semilla)
    mh, ma = (1 - a) * t * hf, a * t
    ch = rng.poisson(mh, n)
    ca = rng.poisson(ma, n)
    lead = ch.astype(np.int64) - ca.astype(np.int64) - 3 * L.K      # ventaja honesta neta
    p = ma / (ma + mh)                                              # prob. de que el proximo bloque sea del atacante
    gana = 0
    for d0 in lead:
        d = int(d0)
        if d < 0:
            gana += 1
            continue
        # carrera de alcance: cada evento es del atacante con prob p; alcanzar = llegar a d = -1
        pasos = 0
        while d >= 0 and d < tope and pasos < 200000:
            d += -1 if rng.random() < p else 1
            pasos += 1
        if d < 0:
            gana += 1
    return gana, n


def montecarlo():
    print()
    print("=" * 104)
    print("C2 · VALIDACION INDEPENDIENTE por Monte Carlo (12 semillas), en el regimen medible")
    print("     Instrumento distinto: se simula la carrera bloque a bloque (Poisson + paseo)")
    print("     en vez de sumar la serie de Skellam. Tope de abandono = 400 bloques de ventaja")
    print("     honesta (r^401 < 1e-30 en el peor r de la tabla).")
    print("=" * 104)
    print(f"{'alpha':>6} {'hf':>6} {'t':>6} | {'MC media':>11} {'MC min':>11} {'MC max':>11} "
          f"{'analitico':>11} {'razon':>7}")
    tareas = []
    casos = []
    for a, hf in ((0.40, 1.0), (0.45, 1.0), (0.48, 1.0), (0.45, 1 - L.delta_interp(0.45))):
        for t in (60.0, 300.0):
            casos.append((a, hf, t))
            for s in SEMILLAS:
                tareas.append((a, hf, t, s, 4000, 400))
    with mp.Pool() as pool:
        res = pool.map(_mc, tareas)
    idx = 0
    for a, hf, t in casos:
        ps = []
        for _ in SEMILLAS:
            g, n = res[idx]; idx += 1
            ps.append(g / n)
        an = L.prev(a, 1.0, t, 3 * L.K, hf)
        m = float(np.mean(ps))
        print(f"{a:>6.2f} {hf:>6.3f} {t:>6.0f} | {m:>11.4f} {min(ps):>11.4f} {max(ps):>11.4f} "
              f"{an:>11.4f} {m/an if an > 0 else float('nan'):>7.3f}")
    print("   Control negativo alpha = 0 (analitico): "
          f"{L.prev(0.0, 1.0, 600.0, 3*L.K, 1.0):.3e}")


def usuario():
    print()
    print("=" * 104)
    print("C3 · QUE GANA EL USUARIO CON F = 1 h FRENTE A F = 2 h")
    print("=" * 104)
    print("(i) Riesgo probabilistico al esperar t segundos: IDENTICO, `prev` no depende de F.")
    for a in (0.10, 0.25, 0.33):
        for nom, hf in (("d=0", L.hf_delta0), ("dD8", L.hf_d8)):
            v = [L.prev(a, 1.0, t, 3 * L.K, hf(a)) for t in (3600.0, 7200.0)]
            print(f"    alpha={a:.2f} {nom:>4}: reversion a 3 600 s = {v[0]:.3e} · a 7 200 s = {v[1]:.3e}")
    print()
    print("(ii) Garantia por regla (R-FIN-7): llega en F. Lo que compra adelantar F de 2 h a 1 h")
    print("     es el intervalo [1 h, 2 h] en el que hoy el riesgo ya vale:")
    for a in (0.10, 0.25, 0.33):
        print(f"    alpha={a:.2f}: d=0 {L.prev(a,1.0,3600.0,3*L.K,1.0):.3e} · "
              f"dD8 {L.prev(a,1.0,3600.0,3*L.K,L.hf_d8(a)):.3e}")


if __name__ == "__main__":
    tabla()
    espera_para([1e-3, 1e-6, 1e-9, 1e-12])
    usuario()
    montecarlo()
