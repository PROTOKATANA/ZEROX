#!/usr/bin/env python3
"""
Comite por SORTEO ponderado (no 'los K mayores'): K plazas sorteadas con la
entropia del PoT entre los bloques cobrados de la ventana. Un granjero entra
con probabilidad proporcional a su espacio, sea grande o pequeno.
Coste: el comite es una muestra de tamano K, mas ruidosa que la ventana entera.
"""
from scipy.stats import binom
import math

def p_frac(alpha, K, frac):
    k = math.ceil(frac * K)
    return binom.sf(k - 1, K, alpha)

print("=" * 74)
print("A) P(el atacante toma >= 1/3 del comite sorteado) -> para la finalidad")
print("=" * 74)
alphas = [0.10, 0.20, 0.25, 0.28, 0.30, 0.33]
print(f"{'K':>7} " + "".join(f"{'a='+str(a):>12}" for a in alphas))
for K in [100, 400, 1000, 2000, 4000]:
    print(f"{K:>7} " + "".join(f"{p_frac(a,K,1/3):12.2e}" for a in alphas))

print()
print("=" * 74)
print("B) P(el atacante toma >= 2/3) -> finaliza una mentira, IRREVERSIBLE")
print("=" * 74)
print(f"{'K':>7} " + "".join(f"{'a='+str(a):>12}" for a in alphas))
for K in [100, 400, 1000, 2000, 4000]:
    print(f"{K:>7} " + "".join(f"{p_frac(a,K,2/3):12.2e}" for a in alphas))

print()
print("=" * 74)
print("C) K minimo para que P(>=1/3) < 1e-9 y P(>=2/3) < 1e-18")
print("=" * 74)
for a in alphas:
    k13 = k23 = None
    for K in range(50, 60001, 10):
        if k13 is None and p_frac(a, K, 1/3) < 1e-9:
            k13 = K
        if k23 is None and p_frac(a, K, 2/3) < 1e-18:
            k23 = K
        if k13 and k23:
            break
    s13 = f"{k13}" if k13 else "> 60000"
    s23 = f"{k23}" if k23 else "> 60000"
    print(f"  alpha={a:.2f}:  K(1/3) = {s13:>8}   K(2/3) = {s23:>8}")

print()
print("=" * 74)
print("D) Coste del certificado con BLS agregada, por K")
print("=" * 74)
for K in [1000, 2000, 4000]:
    b = 128 + 96 + math.ceil(K/8)
    for per in [10, 30]:
        print(f"  K={K:5d}  cert {b:5d} B  cada {per:2d} s -> {b*365*86400/per/1e9:5.2f} GB/ano")

print()
print("CRITERIO ALPHA: K=1000 -> a=0.10: %.2e ; a=0.30: %.2e" %
      (p_frac(0.10,1000,1/3), p_frac(0.30,1000,1/3)))
