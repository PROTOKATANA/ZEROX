#!/usr/bin/env python3
"""d14-instancia · Punto 5: frontera de Pareto (c, K, motor) por presupuesto de red.

Restricciones:
  (i)   presupuesto de subida por nodo (gossip completo f=4, s_v=484 B)
  (ii)  umbral de seguridad < 1/3 dentro del comité: alpha <= alpha_max(c, 1e-6 anual)
  (iii) viveza: p >= p_min(c, alpha, 1e-6 anual) si existe
Objetivo: minimizar la irreversibilidad media = c/2 + r*delta.

Motores y rondas hasta finalidad (T_cons): Simplex 3, Cordial Miners 3 (ES), GossiPBFT
3 fases + DECIDE = 4, BA* 8 (lambda). delta = entrega real; se usa delta = 4 s como
condicion de d12 (d12-quorum/informe.md:513-515) y delta = 6 s (default FIP).
"""
import math
from modelo_trafico import c_min_full, c_min_lider, jerarquia_optima, BUDGETS, instancias_anio
from modelo_seguridad import p_e1_m, p_parada_exacta, alpha_max, p_min_anual

K = 4000
S_V = 484
F = 4
MOTORES = {"Simplex": 3, "Cordial Miners (ES)": 3, "GossiPBFT": 4, "BA*": 8}
DELTAS = (1, 4, 6)


def topologias(B):
    """(nombre, c_min) por topología para un presupuesto de subida B (B/s)."""
    _, c_lider_bid = c_min_lider(K, S_V, B)
    filas = [("gossip completo", c_min_full(F, K, S_V, B)),
             ("líder/agregador", c_lider_bid)]
    cuello, G, g = jerarquia_optima(K, S_V)
    filas.append((f"jerárquica (G={G},g={g})", cuello / B))
    return filas


def main():
    print("=" * 78)
    print("P5 · FRONTERA DE PARETO · K=4000, s_v=484 B, f=4 votos/instancia")
    print("=" * 78)
    a_lim = {}
    for c in (30, 10, 5, 2, 1, 0.5, 0.2, 0.1):
        a_lim[c] = alpha_max(K, c, 1e-6, m=1.0)
    print("\nalpha_max(c) para riesgo anual de seguridad < 1e-6 (K=4000, m=1):")
    for c, a in a_lim.items():
        print(f"  c={c:>4} s -> alpha_max={a:.4%}  (N={instancias_anio(c):,.0f})")

    print("\n" + "=" * 78)
    print("FRONTERA · por presupuesto y topología: c_min, ronda del motor y media")
    print("=" * 78)
    for nombre, B in BUDGETS.items():
        print(f"\n### {nombre}")
        for topo, cmin in topologias(B):
            c = max(cmin, 0.05)  # suelo técnico de instancia (una entrega de 50 ms)
            fila = [f"  {topo:<24} c_min={cmin:>8.4f} s"]
            for motor, r in MOTORES.items():
                if motor == "BA*" and topo == "gossip completo":
                    pass
                media = c / 2 + r * 4  # delta=4 (condicion d12)
                fila.append(f"{motor}: {media:>6.2f}")
            print("    " + " | ".join(fila))
        print("    (media con delta=4 s; r = T_cons en entregas)")

    print("\n" + "=" * 78)
    print("RECOMENDACIÓN POR PRESUPUESTO · tupla (c, K, motor) y coste")
    print("  se elige el motor de mínimo r viable y c = max(c_min, 1 s) doméstico")
    print("=" * 78)
    for nombre, B in BUDGETS.items():
        c_full = c_min_full(F, K, S_V, B)
        _, c_lead = c_min_lider(K, S_V, B)
        # doméstico: no bajar de 1 s (margen sobre el pico, y c<1 s no compra latencia)
        c_rec = max(c_full, 1.0) if nombre == "50 Mbps" else max(c_full, 0.2)
        a = alpha_max(K, c_rec, 1e-6, m=1.0)
        print(f"\n  {nombre}:")
        print(f"    c_min gossip completo={c_full:.4f} s · líder={c_lead:.4f} s")
        print(f"    tupla recomendada: (c={c_rec:.2f} s, K=4000, Simplex r=3) · "
              f"alpha_max(1e-6)={a:.3%}")
        for delta in DELTAS:
            print(f"      delta={delta} s -> media {c_rec/2+3*delta:>6.2f} s "
                  f"(GossiPBFT r=4: {c_rec/2+4*delta:>6.2f} s · BA* r=8: {c_rec/2+8*delta:>6.2f} s)")

    print("\n" + "=" * 78)
    print("COMPARACIÓN CON LA AFIRMACIÓN d13 ('21 TB/año a 5 s es inasumible')")
    print("=" * 78)
    for c in (30, 5, 1):
        tb = F * K * S_V * instancias_anio(c) / 1e12
        mbps = F * K * S_V / c * 8 / 1e6
        print(f"  c={c:>2} s: {tb:>8.2f} TB/año/nodo = {mbps:>7.2f} Mbps de subida sostenida")
    print("  (50 Mbps aguanta hasta c=1,24 s con 4 votos de 484 B; a 5 s son 12,4 Mbps,")
    print("   no un problema de ancho de banda doméstico: era un problema de volumen/mes)")
    print("\n  Si el mensaje real es el QUALITY con la cadena (~68 kB, cota de 99 tipsets,")
    print("  fip-0086.md:654), c_min a 50 Mbps = 174 s y el gossip SÍ manda: LAGUNA sin medir.")


if __name__ == "__main__":
    main()
