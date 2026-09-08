#!/usr/bin/env python3
"""
Sesgo del retarget bajo ataque (ronda 3 §7, PLAUSIBLE; empalme-peso §4 LAGUNA 1), recalculado a k=25.
Modelo de la ronda 3: el observador cuenta azules y el Lema 9 le quita el factor (1-delta),
  lambda_obs = lambda * k/(k + 2*D*lambda)          (delta = 2Dl/(k+2Dl))
El controlador empuja lambda_obs -> lambda_obj = 1/q = 1 bloque/s. Luego la tasa REAL se infla:
  resolver lambda_real * k/(k + 2 D lambda_real) = lambda_obj   =>   lambda_real = k*lambda_obj/(k - 2 D lambda_obj)
Condición de existencia: lambda_obj < k/(2D). Después: delta_real = 2 D lambda_real/(k + 2 D lambda_real),
y el punto fijo k = min{k : P(Poisson(2 D lambda_real) > k) < 1e-3}.
"""
from scipy.stats import poisson
D, LOBJ = 4.0, 1.0
print(f"D={D} s, lambda_objetivo={LOBJ}/s. Techo de existencia k/(2D):\n")
print(f"{'k':>4} {'techo k/2D':>10} {'lambda_real':>12} {'inflación':>10} {'delta_nom':>10} {'delta_real':>11} {'k_Poisson(2Dλ_real)':>20} {'autoconsistente':>16}")
print("-"*100)
for k in (18, 24, 25, 30, 40):
    techo = k/(2*D)
    if LOBJ >= techo:
        print(f"{k:4d} {techo:10.2f}  *** sin punto fijo: lambda_obj >= k/2D ***"); continue
    lreal = k*LOBJ/(k - 2*D*LOBJ)
    dnom  = 2*D*LOBJ/(k + 2*D*LOBJ)
    dreal = 2*D*lreal/(k + 2*D*lreal)
    kp = next(kk for kk in range(1, 500) if poisson.sf(kk, 2*D*lreal) < 1e-3)
    ok = "sí" if kp <= k else f"no (pide {kp})"
    print(f"{k:4d} {techo:10.2f} {lreal:12.3f} {lreal/LOBJ:9.2f}x {dnom:10.4f} {dreal:11.4f} {kp:20d} {ok:>16}")
print("""
Lectura:
 - La ronda 3 dio k=18 -> ×1,80 y pedía k=24. A k=25 la inflación es ×1,47 y la Poisson pide k<=25: AUTOCONSISTENTE.
 - PERO delta_real (con lambda inflada) es mayor que el delta nominal 0,2424 usado en todos los umbrales.
   Ese delta_real es el que debe entrar en alpha* = (1-delta)/(phi_c+1-delta) y en la recursión.""")
