#!/usr/bin/env python3
"""d14-instancia · Punto 2: modelo de latencia e irreversibilidad.

Modelo del encargo (audita-d9.md §3.3):
    latencia = espera [0,c] + T_cons,  media = c/2 + T_cons,  cota = c + T_cons
T_cons = r entregas BFT, r = 3-4 (fip-0086.md:255 "three communication steps").

Motores (fuentes en fuentes/):
  GossiPBFT : 3 fases + DECIDE -> r=3-4 (fip-0086.md:441-454)
  Simplex   : confirmación de propuesta 3δ, bloque cada 2δ -> extremo a extremo 5δ
              (ePrint 2023/463, Tabla 1 y Teorema 3.2)
  Cordial   : caso bueno 3 rondas (ES), esperado 4,5 (arXiv:2205.09174v6, Tabla 1)
  BA*       : 8λ+Λ con líder honesto, esperado (12/p_h+10)λ+Λ
              (arXiv:1607.01341v9, §1.2 y §5)

Advertencia de pipelining: si c < T_cons y el motor no pipelinea instancias, la
cadencia efectiva es max(c, T_cons) y la espera deja de ser [0,c].
"""
BUDGETS = {"50 Mbps": 50e6 / 8, "1 Gbps": 1e9 / 8, "10 Gbps": 10e9 / 8}
C_GRID = (30, 10, 5, 2, 1)
D_GRID = (1, 4, 6, 16)
K = 4000


def t_cons(r, delta):
    return r * delta


def media(c, r, delta):
    return c / 2 + t_cons(r, delta)


def cota(c, r, delta):
    return c + t_cons(r, delta)


def c_min_full(f, K_, s_v, B):
    return f * K_ * s_v / B


def c_min_lider(K_, s_v, B):
    return K_ * s_v / B


def main():
    print("=" * 78)
    print("P2 · LATENCIA = espera[0,c] + T_cons · T_cons = 3 y 4 entregas")
    print("=" * 78)
    for r in (3, 4):
        print(f"\n--- r = {r} entregas ---")
        print(f"{'c(s)':>5} | " + " ".join(f"{'D='+str(d):>16}" for d in D_GRID))
        print(f"{'':>5} | " + " ".join(f"{'media/cota':>16}" for _ in D_GRID))
        for c in C_GRID:
            celdas = []
            for d in D_GRID:
                celdas.append(f"{media(c,r,d):>7.2f}/{cota(c,r,d):>7.2f}")
            print(f"{c:>5} | " + " ".join(f"{x:>16}" for x in celdas))

    print("\n" + "=" * 78)
    print("P2b · MÍNIMO POR PRESUPUESTO · c_min de P1 (gossip completo, f=4) + T_cons")
    print("     media = c_min/2 + r*Delta (s)")
    print("=" * 78)
    for nombre, B in BUDGETS.items():
        print(f"\n  {nombre}:")
        for s_v in (200, 484):
            cmin = c_min_full(4, K, s_v, B)
            print(f"    s_v={s_v} B -> c_min={cmin:.4f} s")
            for d in D_GRID:
                print(f"      Delta={d:>2} s: r=3 -> media {cmin/2+3*d:>7.2f} s (cota {cmin+3*d:>7.2f})"
                      f" | r=4 -> media {cmin/2+4*d:>7.2f} s (cota {cmin+4*d:>7.2f})")
        # líder/agregador: el cuello es la bajada del líder
        cmin_l = c_min_lider(K, 484, B)
        print(f"    líder (s_v=484): c_min={cmin_l:.4f} s -> "
              f"r=3,Delta=4: media {cmin_l/2+12:.2f} s | r=4,Delta=4: media {cmin_l/2+16:.2f} s")

    print("\n" + "=" * 78)
    print("P2c · MOTORES · T_cons (entregas hasta finalidad) y extremo a extremo")
    print("=" * 78)
    motores = [
        ("GossiPBFT (F3)", 3, 4, 4, 5, "3 fases + DECIDE; +1 de espera (fip-0086.md:441-454)"),
        ("Simplex", 3, 3, 5, 5, "propuesta 3δ + 2δ de espera = 5δ (ePrint 2023/463, Tabla 1)"),
        ("Cordial Miners (ES)", 3, 3, 4, 6, "bueno 3+1 rondas; esperado 4,5+1 (arXiv:2205.09174v6)"),
        ("BA* (Algorand)", 8, 8, 8, 32, "8λ+Λ líder honesto; esperado ~32λ (arXiv:1607.01341v9)"),
    ]
    print(f"{'motor':<22} {'T_cons':>8} {'e2e':>8} | " +
          " ".join(f"{'D='+str(d):>8}" for d in D_GRID))
    for nombre, r_min, r_max, e2e_min, e2e_max, nota in motores:
        tcons = f"{r_min}" if r_min == r_max else f"{r_min}-{r_max}"
        e2e = f"{e2e_min}" if e2e_min == e2e_max else f"{e2e_min}-{e2e_max}"
        celdas = " ".join(f"{e2e_max*d:>8.1f}" for d in D_GRID)
        print(f"{nombre:<22} {tcons:>8} {e2e:>8} | {celdas}")
    print("\n  celdas = e2e máximo en unidades de la entrega real δ (no del timeout Δ);")
    print("  T_cons = rondas de mensajes; e2e = T_cons + espera de inclusión.")
    print("  BA*: λ = propagación de un paso (~1 entrega); 8λ es el caso bueno, 32λ el esperado pesimista.")

    print("\n" + "=" * 78)
    print("P2e · δ (entrega real, caso bueno) vs Δ (timeout, recuperación)")
    print("=" * 78)
    print("  El FIP mide: 'reach almost all participants within 6 seconds, with a majority")
    print("  receiving them even after 2 seconds' (fip-0086.md:711). Δ=6 s es el TIMEOUT inicial")
    print("  (fip-0086.md:713), no el tiempo de entrega del caso bueno.")
    for delta in D_GRID:
        print(f"  entrega δ={delta:>2} s -> T_cons r=3: {3*delta:>5.1f} s · r=4: {4*delta:>5.1f} s "
              f"| timeout de fase 2Δ con Δ={delta}: {2*delta:>5.1f} s")

    print("\n" + "=" * 78)
    print("P2d · ¿CUÁNDO MANDA EL GOSSIP Y CUÁNDO DELTA?")
    print("=" * 78)
    for nombre, B in BUDGETS.items():
        cmin = c_min_full(4, K, 484, B)
        print(f"  {nombre}: c_min={cmin:.4f} s. Para Delta>=1 s, c_min/2 <= {cmin/2:.3f} s "
              f"({100*cmin/2:.1f}% de T_cons con r=4,Delta=1) -> manda Delta, no el ancho de banda")
    print("  Si el mensaje real fuese el peor caso QUALITY (~68 kB), c_min=174 s a 50 Mbps y")
    print("  el gossip volvería a mandar (LAGUNA: tamano real de GossiPBFTMessage sin medir).")


if __name__ == "__main__":
    main()
