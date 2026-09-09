#!/usr/bin/env python3
"""
El ataque principal contra la capa (§6.2): el atacante elige entre m anclas,
luego entre m sorteos, y se queda con el comite que mas le conviene.
P(al menos uno de m sorteos le da la fraccion f) = 1 - (1-p)^m.
m = 2,955 medido por D8 (A4.2, con retencion); m <= 1 + lambda*S_max = 151
garantizado por construccion (D9-f, cota E).
"""
from scipy.stats import binom
import math

def p_frac(alpha, K, frac):
    return binom.sf(math.ceil(frac * K) - 1, K, alpha)

def p_best_of_m(p, m):
    # 1 - (1-p)^m, estable para p pequeno
    if p < 1e-12:
        return p * m
    return 1 - (1 - p) ** m

print("=" * 78)
print("Sesgo del sorteo: el atacante se queda con el mejor de m comites")
print("=" * 78)
for K in [1000, 4000]:
    print(f"\n--- K = {K} ---")
    print(f"{'alpha':>6} {'m':>7} {'P(>=1/3) para':>15} {'P(>=2/3) MENTIRA':>20}")
    for a in [0.20, 0.25, 0.30, 0.33]:
        p13 = p_frac(a, K, 1/3)
        p23 = p_frac(a, K, 2/3)
        for m in [1, 2.955, 151]:
            mm = max(1, int(math.ceil(m)))
            print(f"{a:6.2f} {m:7.3f} {p_best_of_m(p13, mm):15.2e} {p_best_of_m(p23, mm):20.2e}")

print()
print("=" * 78)
print("VEREDICTO")
print("=" * 78)
for K in [1000, 4000]:
    p23 = p_frac(0.33, K, 2/3)
    print(f"  K={K}, alpha=0,33, m=151 (cota garantizada): P(mentira) = {p_best_of_m(p23,151):.2e}")
p13 = p_frac(0.25, 1000, 1/3)
print(f"  K=1000, alpha=0,25, m=151: P(parada) = {p_best_of_m(p13,151):.2e}")
p13b = p_frac(0.25, 4000, 1/3)
print(f"  K=4000, alpha=0,25, m=151: P(parada) = {p_best_of_m(p13b,151):.2e}")
print()
print("CRITERIO ALPHA: K=1000, m=151 -> a=0,20: %.2e ; a=0,30: %.2e"
      % (p_best_of_m(p_frac(0.20,1000,1/3),151), p_best_of_m(p_frac(0.30,1000,1/3),151)))
