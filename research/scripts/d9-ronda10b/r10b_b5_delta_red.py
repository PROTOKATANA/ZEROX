#!/usr/bin/env python3
"""
B.5 · La palanca `Delta`. `F_carrera` al 33 % para Delta in {4, 8, 16, 20} s (y los demas Delta
que 9a midio: 12, 24, 32), con la relacion `delta_0(Delta)` MEDIDA en
`research/scripts/d9-ronda9a/r9a_a6_frontera_delta.py:36-38` (DELTA0_MEDIDO), que a su vez sale de
`r9a_a1b_control.py` -> `d9-ronda9a/salida_a1b.txt`: el `delta` que un atacante de RED impone a
alpha = 0, SIN GASTAR ESPACIO. 9a eligio la medida y NO la cola de Poisson P(Poisson(2*Delta*lam)>k),
que sobreestima (a Delta=16 da 0,59 y lo medido es 0,286) — su propio comentario, L28-31.

CONTROL POSITIVO (antes de nada): reproducir la tabla de fronteras de 9a
(`dag-poas-ancla-de-orden-auditoria-8a.md` §4): 46,88 / 46,83 / 44,65 / 38,33 / 32,38 % para
Delta = 4 / 8 / 12 / 16 / 20 s, con F = 19 080 s e I = 4 200 s.

Y la pregunta que C necesita: dado un `F`, cual es el `Delta` MAXIMO tolerable al 33 %.

CRITERIO ALPHA: fila alpha = 0 y barrido de alpha en la ultima tabla.
"""
import time

import numpy as np
from scipy.optimize import brentq

import r10b_lib as L
import r9a_a3_frontera as A

# r9a_a6_frontera_delta.py:36-38 — delta_0 medido a alpha = 0 (atacante de red, gratis)
D0 = {4.0: 0.0000, 8.0: 0.0020, 12.0: 0.0828, 16.0: 0.2858, 20.0: 0.4428,
      24.0: 0.5401, 32.0: 0.6526}
# auditoria-8a.md §4: frontera publicada por 9a con F = 19 080 s, I = 4 200 s
FRONT_PUB = {4.0: 0.4688, 8.0: 0.4683, 12.0: 0.4465, 16.0: 0.3833, 20.0: 0.3238}


def d0_interp(D):
    """delta_0(Delta) por interpolacion lineal entre los puntos MEDIDOS (mismo criterio que
    `A.delta_interp` usa para delta(alpha)). Fuera del rango medido, se satura."""
    xs = sorted(D0)
    if D <= xs[0]:
        return D0[xs[0]]
    if D >= xs[-1]:
        return D0[xs[-1]]
    for i in range(len(xs) - 1):
        if xs[i] <= D <= xs[i + 1]:
            w = (D - xs[i]) / (xs[i + 1] - xs[i])
            return D0[xs[i]] + w * (D0[xs[i + 1]] - D0[xs[i]])


def delta_max(F, alpha=0.33, obj=1e-10, I=None, lo=4.0, hi=32.0):
    """Delta maximo tolerable: el mayor Delta con union(10 anos) < obj a `alpha`."""
    I = I or L.I_DIS
    def g(D):
        L.set_F_I(F, I)
        u = L.union_lam(alpha, 1 - d0_interp(D))
        return np.log10(max(u, 1e-320)) - np.log10(obj)
    if g(lo) > 0:
        return float("nan")           # ni con Delta = 4 s
    if g(hi) < 0:
        return hi                     # aguanta hasta el final del rango medido
    return brentq(g, lo, hi, xtol=0.01)


if __name__ == "__main__":
    t0 = time.time()
    print("=== B.5 · la palanca Delta (el `delta` que NO cuesta espacio) ===\n")

    print("--- CONTROL: la tabla de fronteras de 9a (auditoria-8a.md §4), F=19 080 s, I=4 200 s ---")
    ok = True
    for D in sorted(FRONT_PUB):
        L.set_F_I(19080, 4200); L.set_ventaja(90)
        fr = L.frontera_gruesa(lambda a, d=D0[D]: 1 - d)
        bien = abs(fr - FRONT_PUB[D]) < 6e-4
        ok &= bien
        print(f"    Delta={D:>4.0f} s  delta_0={D0[D]:.4f}  frontera {fr:.4%}  "
              f"(publicado {FRONT_PUB[D]:.2%})  {'OK' if bien else 'DIFIERE'}")
    print(f"    -> {'5/5 OK' if ok else 'HAY DIFERENCIAS'}\n")

    print(f"--- F_carrera al 33 % y al 35 % por Delta (I = {L.I_DIS:.0f} s, ventaja 3k = 90, "
          f"obj 1e-10) ---")
    print(f"{'Delta (s)':>10} {'delta_0':>9} {'r(0,33)':>8} | {'F_carrera 33 %':>16} {'(h)':>7} "
          f"| {'35 %':>12} {'(h)':>7} | {'frontera a F=2 h':>17}")
    for D in sorted(D0):
        d = D0[D]
        L.set_ventaja(90)
        f33 = L.f_carrera(0.33, 1 - d)
        f35 = L.f_carrera(0.35, 1 - d)
        L.set_F_I(7200, L.I_DIS)
        fr2 = L.frontera_gruesa(lambda a, d=d: 1 - d)
        r33 = L.r_base(0.33, 1 - d)
        s33 = f"{f33:>14.0f} s {f33/3600:>7.2f}" if np.isfinite(f33) else f"{'sin cruce':>14} {'':>9}"
        s35 = f"{f35:>10.0f} s {f35/3600:>7.2f}" if np.isfinite(f35) else f"{'sin cruce':>10} {'':>9}"
        marca = "  <- DISENO" if D == 4 else ""
        print(f"{D:>10.0f} {d:>9.4f} {r33:>8.3f} | {s33} | {s35} | {fr2:>16.2%}{marca}")

    print("\n--- la pregunta de C: Delta MAXIMO tolerable al 33 % para cada F (obj 1e-10) ---")
    print(f"{'F (h)':>7} {'F (s)':>8} | {'Delta_max (s)':>14} | {'colchon sobre Delta=4 s':>24}")
    for Fh in (0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 3.0, 5.3):
        dm = delta_max(Fh * 3600)
        s = f"{dm:>14.1f}" if np.isfinite(dm) else f"{'ninguno':>14}"
        c = f"{dm-4:>+23.1f} s" if np.isfinite(dm) else f"{'--':>24}"
        print(f"{Fh:>7.2f} {Fh*3600:>8.0f} | {s} | {c}")

    print("\n--- criterio alpha: F_carrera(alpha) para cada Delta ---")
    print(f"{'alpha':>6} | " + " ".join(f"{'D=%d' % D:>11}" for D in (4, 8, 12, 16, 20)))
    for a in (0.0, 0.10, 0.25, 0.33, 0.35, 0.40):
        fila = []
        for D in (4, 8, 12, 16, 20):
            L.set_ventaja(90)
            f = L.f_carrera(a, 1 - D0[float(D)])
            fila.append(f"{f:>11.0f}" if np.isfinite(f) else f"{'sin cruce':>11}")
        print(f"{a:>6.2f} | " + " ".join(fila))
    print(f"\n[{time.time()-t0:.0f} s]")
