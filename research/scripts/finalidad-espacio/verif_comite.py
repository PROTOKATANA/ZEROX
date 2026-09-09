#!/usr/bin/env python3
"""
Capa de finalidad ponderada por espacio para ZEROX (estilo Filecoin F3).
Pregunta central: si el comite se muestrea de los bloques GANADOS en una ventana
de W segundos, cuanto se desvia su composicion del espacio real?

Modelo: lambda = 1 bloque/s (rama A''), N = lambda*W bloques en la ventana.
El atacante con fraccion alpha del espacio gana X ~ Binomial(N, alpha).
Su peso en el comite es X/N (peso = bloques cobrados por R-FIN-8').

Criterio alpha (METODO-AGENTES): el resultado DEBE cambiar con alpha. Se comprueba.
"""
from scipy.stats import binom
import math

LAMBDA = 1.0  # bloques/s, rama (A'')

def p_exceeds(alpha, W, frac):
    """P(peso del atacante en el comite >= frac)."""
    N = int(LAMBDA * W)
    # P(X >= ceil(frac*N))
    k = math.ceil(frac * N)
    return binom.sf(k - 1, N, alpha), N

print("=" * 78)
print("A) P(el atacante alcanza 1/3 del comite) -> PARA la finalidad rapida")
print("=" * 78)
ventanas = [(600, "10 min"), (1800, "30 min"), (3600, "1 h"), (7200, "2 h"), (86400, "24 h")]
alphas = [0.10, 0.20, 0.25, 0.28, 0.30, 0.33]
print(f"{'ventana':>8} {'N':>7} " + "".join(f"{'a='+str(a):>12}" for a in alphas))
for W, etiq in ventanas:
    fila = []
    for a in alphas:
        p, N = p_exceeds(a, W, 1/3)
        fila.append(f"{p:12.2e}")
    print(f"{etiq:>8} {N:>7} " + "".join(fila))

print()
print("=" * 78)
print("B) P(el atacante alcanza 2/3 del comite) -> FINALIZA UNA MENTIRA, irreversible")
print("=" * 78)
print(f"{'ventana':>8} {'N':>7} " + "".join(f"{'a='+str(a):>12}" for a in alphas))
for W, etiq in ventanas:
    fila = []
    for a in alphas:
        p, N = p_exceeds(a, W, 2/3)
        fila.append(f"{p:12.2e}")
    print(f"{etiq:>8} {N:>7} " + "".join(fila))

print()
print("=" * 78)
print("C) Ventana minima para P(>=1/3) < 1e-9, por alpha")
print("=" * 78)
for a in alphas:
    if a >= 1/3:
        print(f"  alpha={a:.2f}: NO EXISTE (alpha >= 1/3: el atacante ESTA en el umbral)")
        continue
    W = 60
    while W <= 30 * 86400:
        p, N = p_exceeds(a, W, 1/3)
        if p < 1e-9:
            print(f"  alpha={a:.2f}: W = {W:7d} s = {W/3600:7.2f} h  (N={N}, p={p:.2e})")
            break
        W = int(W * 1.05) + 1
    else:
        print(f"  alpha={a:.2f}: > 30 dias")

print()
print("=" * 78)
print("CRITERIO ALPHA: el resultado cambia con alpha?")
p1, _ = p_exceeds(0.10, 3600, 1/3)
p2, _ = p_exceeds(0.30, 3600, 1/3)
print(f"  W=1h: alpha=0.10 -> {p1:.3e} ; alpha=0.30 -> {p2:.3e} ; ratio {p2/p1:.3e}")
print(f"  PASA: {'SI' if p2 > p1 * 1e6 else 'NO'}")
