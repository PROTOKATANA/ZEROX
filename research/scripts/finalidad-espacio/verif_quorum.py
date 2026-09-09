#!/usr/bin/env python3
"""
La restriccion que manda: quorum de 2/3 con granjeros domesticos.
Filecoin F3 exige >= 2/3 del poder TOTAL de la tabla, no de los presentes.
Si la participacion honesta es p, hay quorum solo si (1-alpha)*p >= 2/3.
"""
from scipy.stats import binom
import math

print("=" * 70)
print("A) Participacion honesta MINIMA para que exista quorum de 2/3")
print("=" * 70)
print(f"{'alpha':>7} {'p minima':>10}")
for a in [0.00, 0.10, 0.20, 0.25, 0.28, 0.30, 0.33]:
    p = (2/3) / (1 - a)
    estado = f"{100*p:8.1f} %" if p <= 1 else "IMPOSIBLE"
    print(f"{a:7.2f} {estado:>10}")

print()
print("=" * 70)
print("B) P(no hay quorum) por instancia, K=1000, comite sorteado")
print("   honestos presentes ~ Binom(K*(1-alpha), p); hace falta >= 2K/3")
print("=" * 70)
K = 1000
need = math.ceil(2 * K / 3)
print(f"  K={K}, hacen falta {need} firmas")
print(f"{'p':>6} " + "".join(f"{'a='+str(a):>12}" for a in [0.10, 0.20, 0.25, 0.30]))
for p in [0.70, 0.80, 0.90, 0.95, 0.98, 0.995]:
    fila = []
    for a in [0.10, 0.20, 0.25, 0.30]:
        n_h = int(K * (1 - a))
        # P(presentes < need)
        fila.append(f"{binom.cdf(need - 1, n_h, p):12.2e}")
    print(f"{p:6.3f} " + "".join(fila))

print()
print("=" * 70)
print("C) Salida: comite solo con granjeros con prueba de vida reciente")
print("   Si el comite se sortea entre quienes ganaron un bloque en los")
print("   ultimos T segundos, p sube: siguen online casi con seguridad.")
print("=" * 70)
print("  Poblacion elegible (bloques ganados en la ventana viva), lambda=1 b/s:")
for T in [60, 300, 900, 3600]:
    print(f"    T={T:5d} s -> {int(T)} bloques -> hasta {int(T)} claves distintas")
print()
print("  Restriccion: el comite K no puede exceder la poblacion elegible.")
print("  Con K=1000 hace falta T >= 1000 s de ventana viva (mas si hay")
print("  granjeros que ganan varios bloques).")

print()
print("=" * 70)
print("D) Alternativa: quorum sobre el comite PRESENTE con umbral mayor")
print("=" * 70)
print("  Si se exige 2/3 de los PRESENTES en vez del total, un atacante")
print("  que silencia honestos sube su fraccion. Con alpha del comite a")
print("  y fraccion presente p de los honestos:")
for a in [0.25, 0.30]:
    for p in [0.7, 0.8, 0.9]:
        ef = a / (a + (1 - a) * p)
        print(f"    alpha={a:.2f}, p={p:.2f} -> alpha efectivo entre presentes = {100*ef:5.1f} %"
              + ("  <-- ROMPE 1/3" if ef > 1/3 else ""))
