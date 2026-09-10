#!/usr/bin/env python3
"""d14-instancia · Punto 1: modelo de tráfico de la capa de comité por instancia.

Unidades: TB decimal = 1e12 B (el mismo que usa audita-d9.md cifra 19: 484 B x 4000 x
1 051 200 = 2,04 TB). Se imprime también TiB = 2^40 B para no confundir.
Ancho de banda: Mbps decimal = 1e6 bit/s (convención de operador).

Modelos (los tres del encargo):
  (a) gossip completo de votos: cada nodo retransmite los f votos de los K miembros
      -> subida/bajada por nodo e instancia = f*K*s_v   [ancla verificada: 1 voto de
      484 B x K=4000 x 1 051 200 = 2,04 TB/año]
  (b) líder/agregador: K votos al líder + certificado BLS de 724 B difundido
  (c) agregación jerárquica: G grupos de g=K/G; agregado de grupo = 96 + ceil(g/8) B

Presupuestos de subida: 50 Mbps, 1 Gbps, 10 Gbps.
Criterio del encargo: "presupuestos de subida". Para el líder y la jerarquía el cuello
puede ser la BAJADA (K*s_v/c en el líder). Se dan las dos lecturas:
  c_up   = mínimo por subida estricta
  c_bid  = mínimo si el presupuesto cubre subida+bajada del nodo más cargado (conservador)
"""
import math

B_DEC = 1e12          # TB decimal
B_TIB = 2.0 ** 40     # TiB
SEG_ANIO = 365 * 24 * 3600
BUDGETS = {"50 Mbps": 50e6 / 8, "1 Gbps": 1e9 / 8, "10 Gbps": 10e9 / 8}  # B/s

CERT_BLS = 128 + 96 + 500          # 724 B a K=4000 (f1-p040-latencia.md §6.2)
SIG_AGG = 96                       # firma BLS agregada G2
K_GRID = (500, 1000, 2000, 4000)
C_GRID = (30, 10, 5, 2, 1)
S_GRID = (200, 484)


def instancias_anio(c):
    """N(c) = 365*24*3600/c. A 30 s -> 1 051 200 (audita-d9.md cifra 8)."""
    return SEG_ANIO / c


def tb_anual(bytes_por_instancia, c):
    """TB decimal/año de un flujo de bytes_por_instancia cada c segundos."""
    return bytes_por_instancia * instancias_anio(c) / B_DEC


def tib_anual(bytes_por_instancia, c):
    return bytes_por_instancia * instancias_anio(c) / B_TIB


def c_min_full(f, K, s_v, B):
    """Gossip completo: subida = bajada = f*K*s_v por nodo e instancia."""
    return f * K * s_v / B


def c_min_lider(K, s_v, B):
    """Líder: recibe K*s_v, difunde 724 B. Nodo más cargado = líder.
    Lectura subida estricta: solo el certificado de 724 B sale del líder.
    Lectura bidireccional: la bajada del líder K*s_v/c manda."""
    return 724 / B, K * s_v / B


def agg_grupo(g):
    """Certificado de grupo BLS: firma agregada + mapa de bits (sin cabecera de 128 B)."""
    return SIG_AGG + math.ceil(g / 8)


def jerarquia_optima(K, s_v):
    """Elige G (nº de grupos, divisores de K) que minimiza el máximo de los dos cuellos:
    bajada del jefe de grupo (g*s_v) y bajada del jefe global (G*agg(g))."""
    mejor = None
    for G in range(1, K + 1):
        if K % G:
            continue
        g = K // G
        cuello = max(g * s_v, G * agg_grupo(g))
        if mejor is None or cuello < mejor[0]:
            mejor = (cuello, G, g)
    return mejor  # (bytes_por_instancia_nodo_mas_cargado, G, g)


def fmt(x):
    return f"{x:,.4f}".replace(",", " ")


def main():
    print("=" * 78)
    print("P1 · MODELO DE TRÁFICO · capa de comité derivada del espacio")
    print("=" * 78)
    print(f"instancias/año: c=30 -> {instancias_anio(30):,.0f}; c=1 -> {instancias_anio(1):,.0f}")
    print(f"control positivo (ancla d13): 484*4000*{instancias_anio(30):,.0f}/1e12 = "
          f"{484*4000*instancias_anio(30)/B_DEC:.4f} TB/año (audita-d9 cifra 19: 2,04)")

    print("\n" + "=" * 78)
    print("(a) GOSSIP COMPLETO · TB/año por nodo · s_v=484 B")
    print("    (subida = bajada; f = votos por miembro e instancia)")
    print("=" * 78)
    print(f"{'K':>5} {'c(s)':>5} | {'f=1 TB/año':>12} {'f=3 TB/año':>12} {'f=4 TB/año':>12} | {'f=4 TiB/año':>12}")
    for K in K_GRID:
        for c in C_GRID:
            vals = [tb_anual(f * K * 484, c) for f in (1, 3, 4)]
            print(f"{K:>5} {c:>5} | {vals[0]:>12.4f} {vals[1]:>12.4f} {vals[2]:>12.4f} | "
                  f"{tib_anual(4*K*484, c):>12.4f}")
        print("-" * 78)

    print("\n" + "=" * 78)
    print("(a) GOSSIP COMPLETO · mínimo c viable (s) por presupuesto de subida")
    print("    c = f*K*s_v/B · s_v=484 B")
    print("=" * 78)
    for nombre, B in BUDGETS.items():
        print(f"\n  presupuesto {nombre} = {B/1e6:.4f} MB/s")
        print(f"  {'K':>5} | " + " ".join(f"{'f='+str(f):>10}" for f in (1, 3, 4)) + "  |  f=4 s_v=200")
        for K in K_GRID:
            c4_484 = c_min_full(4, K, 484, B)
            c4_200 = c_min_full(4, K, 200, B)
            print(f"  {K:>5} | " + " ".join(f"{c_min_full(f, K, 484, B):>10.4f}" for f in (1, 3, 4))
                  + f"  |  {c4_200:>12.4f}")

    print("\n" + "=" * 78)
    print("(b) LÍDER/AGREGADOR · K votos al líder + certificado 724 B difundido")
    print("=" * 78)
    print(f"{'K':>5} | {'subida líder':>12} {'bajada líder':>13} | "
          + " ".join(f"{'c 50Mbps':>9}" for _ in [0]) + " (bidireccional, s)")
    print("  c_up = 724/B (solo subida estricta); c_bid = K*s_v/B (subida+bajada del líder)")
    for K in K_GRID:
        for s_v in S_GRID:
            fila = []
            for nombre, B in BUDGETS.items():
                _, cbid = c_min_lider(K, s_v, B)
                fila.append(f"{cbid:.4f}")
            c_up_50 = 724 / BUDGETS["50 Mbps"]
            print(f"  K={K:>4} s_v={s_v:>3} | c_up(50Mbps)={c_up_50*1000:.3f} ms | "
                  f"c_bid: 50Mbps={fila[0]} 1Gbps={fila[1]} 10Gbps={fila[2]} s")

    print("\n" + "=" * 78)
    print("(c) AGREGACIÓN JERÁRQUICA · G grupos de g, agregado de grupo 96+ceil(g/8) B")
    print("=" * 78)
    for K in K_GRID:
        for s_v in S_GRID:
            cuello, G, g = jerarquia_optima(K, s_v)
            print(f"  K={K:>4} s_v={s_v:>3}: G={G:>4} grupos de g={g:>4} · "
                  f"cuello={cuello:>8,.0f} B/instancia · "
                  f"c_bid 50Mbps={cuello/BUDGETS['50 Mbps']:.6f} s · "
                  f"1Gbps={cuello/BUDGETS['1 Gbps']:.6f} s")

    print("\n" + "=" * 78)
    print("(b)/(c) BYTES/AÑO POR ROL · TB decimal/año (s_v=484, c=30 s)")
    print("=" * 78)
    c = 30
    for K in K_GRID:
        lider = (K * 484 + CERT_BLS) * instancias_anio(c) / B_DEC
        regular = (484 + CERT_BLS) * instancias_anio(c) / B_DEC
        red_total = (K * 484 + K * CERT_BLS) * instancias_anio(c) / B_DEC
        print(f"  (b) K={K:>4}: líder={lider:>8.3f} TB/año · regular={regular:>6.4f} TB/año · "
              f"red total={red_total:>8.3f} TB/año")
    for K in K_GRID:
        cuello, G, g = jerarquia_optima(K, 484)
        jefe_grupo = max(g * 484, agg_grupo(g)) * instancias_anio(c) / B_DEC
        jefe_global = max(G * agg_grupo(g), CERT_BLS) * instancias_anio(c) / B_DEC
        miembro = 484 * instancias_anio(c) / B_DEC
        print(f"  (c) K={K:>4} (G={G:>4},g={g:>4}): jefe de grupo={jefe_grupo:>6.3f} TB/año · "
              f"jefe global={jefe_global:>6.3f} TB/año · miembro={miembro:.4f} TB/año")

    print("\n" + "=" * 78)
    print("SENSIBILIDAD · si el mensaje real no es 484 B (QUALITY lleva la cadena)")
    print("  c_min full gossip, K=4000, f=4, 50 Mbps")
    print("=" * 78)
    for s_v in (200, 484, 1000, 4096, 68000):
        c = c_min_full(4, 4000, s_v, BUDGETS["50 Mbps"])
        print(f"  s_v={s_v:>6} B -> c_min={c:>9.4f} s   (TB/año a c=30: {tb_anual(4*4000*s_v,30):>8.3f})")


if __name__ == "__main__":
    main()
