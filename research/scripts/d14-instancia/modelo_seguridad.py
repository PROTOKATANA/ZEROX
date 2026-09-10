#!/usr/bin/env python3
"""d14-instancia · Punto 4: seguridad y viveza de la capa de comité.

Modelo:
  Comité de K plazas por sorteo ponderado. A ~ Bin(K, alpha) plazas del atacante.
  Seguridad BFT: el argumento de intersección de quórums exige A < K/3
    (fip-0086.md:65, :248). P(fallo) = P(A >= ceil(K/3))  [E1 de f1 §3.1].
  Viveza: el quórum exige >= 2/3 del total; con honestos encendidos p,
    H ~ Bin(K-A, p); P(parada) = sum_A P(A) * P(H < ceil(2K/3) - A)  [f1 §4.3].
  m anclas: el atacante elige el mejor de m comités -> P_m = 1-(1-p)^m
    (capa-finalidad.md §4.D). m del diseño vivo = 2,822 (ancla-de-orden.md:156);
    cota garantizada m <= 1 + lambda*S_max = 151.
  Riesgo anual con N(c) = 365*24*3600/c instancias (anualización con expm1/log1p).

Criterio alpha (METODO-AGENTES §4): todo resultado cambia con alpha; se comprueba
imprimiendo la tabla y resolviendo el alpha máximo.
"""
import math
from scipy.stats import binom
from scipy.optimize import brentq

K_GRID = (500, 1000, 2000, 4000)
ALPHAS = (0.25, 0.28, 0.30, 0.33)
MS = (1.0, 2.822, 2.955, 151.0)
PS = (0.90, 0.95, 0.98, 1.00)
C_GRID = (30, 10, 5, 2, 1)
SEG_ANIO = 365 * 24 * 3600


def instancias_anio(c):
    return SEG_ANIO / c


def p_e1(K, alpha):
    """P[Bin(K,alpha) >= ceil(K/3)]: el atacante alcanza el tercio. log estable."""
    umbral = math.ceil(K / 3)
    return math.exp(binom.logsf(umbral - 1, K, alpha))


def p_e1_m(K, alpha, m):
    """Best-of-m anclas: el atacante se queda con el mejor comité."""
    p = p_e1(K, alpha)
    if p <= 0:
        return 0.0
    return -math.expm1(m * math.log1p(-p))


def p_parada_exacta(K, alpha, p):
    """P(no quórum) con sortición: A~Bin(K,alpha), H~Bin(K-A,p).

    El atacante que censura RETIENE sus votos (f1 §4.3): los honestos deben llegar
    solos a 2/3 del total. Parada <=> H < need, con H~Bin(K-A,p):
      K-A < need        -> parada segura (ni con todos los honestos)
      K-A >= need       -> P(H < need)
    Control contra f1 §4.3: (0.25,0.90)=1.3e-1; (0.30,0.95)=5.9e-1;
    (0.33,0.98)=9.1e-1; (0.33,1.00)=3.2e-1.
    """
    need = math.ceil(2 * K / 3)
    total = 0.0
    for A in range(K + 1):
        pa = binom.pmf(A, K, alpha)
        if pa < 1e-300:
            continue
        if K - A < need:
            ph = 1.0
        else:
            ph = binom.cdf(need - 1, K - A, p)
        total += pa * ph
    return total


def riesgo_anual(p, n):
    """1-(1-p)^n estable. Para p*n << 1 devuelve p*n (misma precisión relativa)."""
    if p <= 0:
        return 0.0
    if p >= 1:
        return 1.0
    if p < 1e-8:
        return p * n
    return -math.expm1(n * math.log1p(-p))


def alpha_max(K, c, objetivo, m=1.0):
    """alpha tal que el riesgo anual de fallo de seguridad = objetivo."""
    n = instancias_anio(c)
    return brentq(lambda a: _log_riesgo(p_e1_m(K, a, m), n) - math.log(objetivo),
                  0.05, 0.3333, xtol=1e-14)


def _log_riesgo(q, n):
    """log del riesgo anual 1-(1-q)^n, con centinelas finitos para q=0 y q=1."""
    if q <= 0:
        return -1e300
    if q >= 1:
        return 1e300
    if q < 1e-8:
        return math.log(q) + math.log(n)
    return math.log(-math.expm1(n * math.log1p(-q)))


def p_min_anual(K, alpha, c, objetivo):
    """p de encendido mínimo para riesgo anual de parada <= objetivo.

    Devuelve None si ni con p=1 se alcanza (el suelo de parada es P(E1) con el
    umbral de viveza: P[K-A < need] = P[A > K-need]).
    """
    n = instancias_anio(c)
    q_min = p_parada_exacta(K, alpha, 1 - 1e-12)
    if q_min > objetivo / n:
        return None
    return brentq(lambda p: _log_riesgo(p_parada_exacta(K, alpha, p), n) - math.log(objetivo),
                  0.5, 1 - 1e-12, xtol=1e-15)


def main():
    print("=" * 78)
    print("P4 · SEGURIDAD Y VIVEZA · capa de comité (K plazas, sorteo ponderado)")
    print("=" * 78)
    print("control positivo: P[Bin(4000,0,33)>=1334] = "
          f"{p_e1(4000,0.33):.6f} (audita-d9 cifra 7: 0,3244)")

    print("\n" + "=" * 78)
    print("E1 · P(el atacante alcanza 1/3 del comité) por instancia")
    print("=" * 78)
    print(f"{'K':>5} | " + " ".join(f"{'a='+str(a):>12}" for a in ALPHAS))
    for K in K_GRID:
        print(f"{K:>5} | " + " ".join(f"{p_e1(K,a):>12.4e}" for a in ALPHAS))

    print("\n" + "=" * 78)
    print("E1 con m anclas · best-of-m (K=4000)")
    print("=" * 78)
    print(f"{'alpha':>6} | " + " ".join(f"{'m='+str(m):>12}" for m in MS))
    for a in ALPHAS:
        print(f"{a:>6} | " + " ".join(f"{p_e1_m(4000,a,m):>12.4e}" for m in MS))

    print("\n" + "=" * 78)
    print("VIVEZA · P(no quórum) exacta con sortición (K=4000, m=1)")
    print("=" * 78)
    print(f"{'alpha':>6} | " + " ".join(f"{'p='+str(p):>12}" for p in PS))
    for a in ALPHAS:
        fila = []
        for p in PS:
            fila.append(f"{p_parada_exacta(4000, a, p):>12.3e}")
        print(f"{a:>6} | " + " ".join(fila))
    print("\n  umbral media-campo p >= (2/3)/(1-alpha):")
    for a in ALPHAS:
        print(f"    alpha={a}: p >= {(2/3)/(1-a):.4f}")
    print("\n  control positivo f1 §4.3 (K=4000): "
          f"(0.25,0.90)={p_parada_exacta(4000,0.25,0.90):.3e} "
          f"(0.30,0.95)={p_parada_exacta(4000,0.30,0.95):.3e} "
          f"(0.33,0.98)={p_parada_exacta(4000,0.33,0.98):.3e} "
          f"(0.33,1.00)={p_parada_exacta(4000,0.33,1.00):.3e}")

    print("\n" + "=" * 78)
    print("VIVEZA ANUAL · p mínimo para riesgo de parada < 1e-2 y < 1e-6 (K=4000, m=1)")
    print("  la cadencia c cambia N(c): bajar c endurece también la viveza")
    print("=" * 78)
    print(f"  {'alpha':>6} {'c(s)':>5} | {'p_min 1e-2':>11} {'p_min 1e-6':>11} | "
          f"{'paradas/año p=0.98':>19} {'paradas/año p=0.99':>19}")
    for a in (0.25, 0.28, 0.30, 0.33):
        for c in C_GRID:
            q98 = riesgo_anual(p_parada_exacta(4000, a, 0.98), instancias_anio(c))
            q99 = riesgo_anual(p_parada_exacta(4000, a, 0.99), instancias_anio(c))
            p2 = p_min_anual(4000, a, c, 1e-2)
            p6 = p_min_anual(4000, a, c, 1e-6)
            s2 = f"{p2:.6f}" if p2 is not None else "imposible"
            s6 = f"{p6:.6f}" if p6 is not None else "imposible"
            print(f"  {a:>6} {c:>5} | {s2:>11} {s6:>11} | {q98:>19.4e} {q99:>19.4e}")
        print("-" * 78)

    print("\n" + "=" * 78)
    print("VIVEZA con m anclas · P(parada) = 1-(1-P1)^m (K=4000)")
    print("=" * 78)
    print(f"  {'alpha':>6} {'p':>6} | " + " ".join(f"{'m='+str(m):>12}" for m in MS))
    for a, p in ((0.28, 0.98), (0.30, 0.98), (0.33, 0.98)):
        base = p_parada_exacta(4000, a, p)
        print(f"  {a:>6} {p:>6} | " + " ".join(f"{(1-(1-base)**m):>12.3e}" for m in MS))

    print("\n" + "=" * 78)
    print("RIESGO ANUAL · alpha_max para riesgo < 1e-6 y < 1e-12")
    print("  (la cadencia c cambia N(c); bajar c endurece el presupuesto anual)")
    print("=" * 78)
    for m in (1.0, 3.0, 151.0):
        print(f"\n  m = {m}")
        print(f"  {'K':>5} {'c(s)':>5} | {'N/año':>12} | {'a_max 1e-6':>10} {'a_max 1e-12':>11}")
        for K in (1000, 4000):
            for c in C_GRID:
                a6 = alpha_max(K, c, 1e-6, m)
                a12 = alpha_max(K, c, 1e-12, m)
                print(f"  {K:>5} {c:>5} | {instancias_anio(c):>12,.0f} | {a6:>10.4%} {a12:>11.4%}")

    print("\n" + "=" * 78)
    print("RECUPERACIÓN · instancias hasta cerrar y tiempo (atacante pasivo que bloquea)")
    print("=" * 78)
    for a in (0.25, 0.30, 0.33):
        p = p_e1(4000, a)
        esp = 1 / (1 - p) if p < 1 else math.inf
        print(f"  alpha={a}: P(E1)={p:.4e} -> E[instancias]={esp:.2f} | "
              f"c=30: {30*esp:.1f} s · c=5: {5*esp:.1f} s · c=1: {esp:.1f} s")
    for m in (2.822, 2.955, 151.0):
        p = p_e1_m(4000, 0.33, m)
        esp = 1 / (1 - p) if p < 1 else math.inf
        print(f"  alpha=0.33 m={m}: P(E1)={p:.4f} -> E[instancias]={esp if esp == math.inf else round(esp,2)}")
    print("\n  Si el ataque persiste y m=151 (P(E1)=1), la capa no vuelve: fallback R-FIN-7 F=2 h.")


if __name__ == "__main__":
    main()
