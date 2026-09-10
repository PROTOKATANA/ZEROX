#!/usr/bin/env python3
"""Verificación independiente de los números de la ronda d13.

Cada bloque imprime el valor recalculado y el valor que afirma el informe.
PASS/FAIL es comparación numérica, no opinión.
"""
import math
from scipy.stats import poisson, binom
from scipy.optimize import brentq

PASS, FAIL = "PASS", "FAIL"

def check(nombre, calc, esperado, tol=5e-3, rel=True):
    if esperado is None:
        print(f"  {nombre}: {calc}")
        return
    if rel:
        ok = abs(calc - esperado) <= tol * max(abs(esperado), 1e-30)
    else:
        ok = abs(calc - esperado) <= tol
    print(f"  [{PASS if ok else FAIL}] {nombre}: calc={calc!r} informe={esperado!r}")

def poisson_sf(lam, n):
    """P[X >= n] para X ~ Poisson(lam)."""
    return poisson.sf(n - 1, lam)

print("=" * 72)
print("A · POA de HotPoW (d12 §F.7 / f0b)")
print("  fórmula del instrumento d12: poisson_sf(k, 2k)")
check("Bitcoin k=1: P[X>=2]", poisson_sf(1, 2), 0.2642411)
for k, esp in ((16, 2.762e-04), (64, 1.272367e-12), (256, 3.959e-45)):
    check(f"Def.1 k={k}: P[X>=2k]", poisson_sf(k, 2 * k), esp)
# Equivocación: dos quórums en conflicto con k ATVs (una solución vota ambos)
for k, esp in ((16, 0.5333), (64, 0.516624), (256, 0.5083)):
    check(f"Equiv. k={k}: P[X>=k]", poisson_sf(k, k), esp)
# ¿la mediana de Poisson(k)? comprobación de que P[X>=k] ~ 0.5
for k in (16, 64, 256):
    print(f"    k={k}: P[X>=k]={poisson_sf(k,k):.6f}  P[X>=k+1]={poisson_sf(k,k+1):.6f}")

print("=" * 72)
print("B · Umbral de viveza p >= (2/3)/(1-alpha) (f1 §3)")
for a, esp in ((0.00, 0.667), (0.25, 0.889), (0.30, 0.952), (0.33, 0.995)):
    check(f"alpha={a}", (2/3) / (1 - a), esp, tol=1e-3)

print("=" * 72)
print("C · Riesgo anual BFT (f1 §3): K=4000, cadencia 30 s")
K = 4000
N = 365 * 24 * 3600 / 30  # instancias/año
umbral = math.ceil(K / 3)  # 1334: el atacante alcanza 1/3 del comité

def p_falla(alpha):
    """P[Bin(K,alpha) >= ceil(K/3)]: el comité no alcanza 2/3 honesto."""
    return binom.sf(umbral - 1, K, alpha)

print(f"  N instancias/año = {N:,.0f}, umbral = {umbral}")
for a, esp_p, esp_anual in ((0.33, 0.324, None), (0.30, 2.5e-06, None), (0.28, None, None)):
    p = p_falla(a)
    print(f"  alpha={a}: P(parada por instancia)={p:.6e}  riesgo anual={1-(1-p)**N:.6e}")
check("alpha=0.33 P(parada) vs 0.324", p_falla(0.33), 0.324, tol=0.005)
check("alpha=0.30 P(parada) vs 2.5e-06", p_falla(0.30), 2.5e-06, tol=0.05)
alfa_seguro = brentq(lambda a: 1 - (1 - p_falla(a))**N - 1e-6, 0.2, 0.33)
check("alpha para riesgo anual 1e-6 vs 28,2 %", alfa_seguro, 0.282, tol=0.005)
check("paradas/año a alpha=0.33 vs 340 999", p_falla(0.33) * N, 340999, tol=0.01)

print("=" * 72)
print("D · Umbral espacio-tiempo con honestos al 80 % (f1 §3.4)")
# alpha / (alpha + 0.8(1-alpha)) = 1/3
alfa_st = brentq(lambda a: a / (a + 0.8 * (1 - a)) - 1/3, 0.01, 0.5)
check("alpha espacio-tiempo vs 28,6 %", alfa_st, 0.286, tol=0.005)
print(f"  forma cerrada 0.8/2.8 = {0.8/2.8:.6f}")

print("=" * 72)
print("E · Certificado y bytes/año (f1 §6.2)")
N30 = 365 * 24 * 3600 / 30
for Kk, esp_b, esp_gb in ((1000, 66128, 69.51), (4000, 264128, 277.65)):
    # composición 66 B/firma + 128 B de cabecera
    calc_b = Kk * 66 + 128
    calc_gb = calc_b * N30 / 1e9
    check(f"Ed25519 K={Kk} bytes", calc_b, esp_b, tol=0)
    check(f"Ed25519 K={Kk} GB/año", calc_gb, esp_gb, tol=0.005)
for Kk, esp_b, esp_gb in ((1000, 349, 0.37), (4000, 724, 0.76)):
    calc_gb = esp_b * N30 / 1e9
    check(f"BLS K={Kk} GB/año", calc_gb, esp_gb, tol=0.02)

print("=" * 72)
print("F · Ploteo y castigo de espacio (f0a)")
for rate, esp_s, esp_min in ((83.608, 83.6, 89.2), (69.363, 69.4, 74.0)):
    calc_min = rate * 64 / 60
    check(f"64 GiB a {rate} s/GiB -> min", calc_min, esp_min, tol=0.01)
check("GPU tope 4,3 s/GiB -> min", 4.3 * 64 / 60, 4.6, tol=0.05)
check("GPU tope 9,9 s/GiB -> min", 9.9 * 64 / 60, 10.6, tol=0.05)
check("cuota 64 GiB en red 10 TiB, alpha=0.33", 64 / (0.33 * 10 * 1024), 0.019, tol=0.05)
check("cuota 64 GiB en red 1 PiB, alpha=0.33", 64 / (0.33 * 1024 * 1024), 0.00019, tol=0.05)

print("=" * 72)
print("G · Latencias con timeouts 2*Delta (f1 §5.2): columnas 3, 4 y 10 rondas")
for d, esp3, esp4, esp10 in ((6, 18, 24, 60), (10, 30, 40, 100), (16, 48, 64, 160), (20, 60, 80, 200)):
    check(f"Delta={d}: 3 rondas", 3 * d, esp3, tol=0)
    check(f"Delta={d}: 4 rondas", 4 * d, esp4, tol=0)
    check(f"Delta={d}: ronda perdida", 10 * d, esp10, tol=0)

print("=" * 72)
print("H · Gossip de certificados (f1 §4): orden de magnitud")
for Kk, tam in ((4000, 264128), (4000, 724)):
    gb = tam * N30 / 1e9
    print(f"  K={Kk}, {tam} B/cert, 30 s: {gb:.2f} GB/año por flujo")
# votos sueltos: 484 B (d12 F.1) x K, por instancia
for Kk in (1000, 4000):
    tb = 484 * Kk * N30 / 1e12
    print(f"  votos sueltos 484 B x {Kk} x {N30:,.0f} = {tb:.2f} TB/año")

print("=" * 72)
print("FIN")
