#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
latencia_snowball.py — Latencia de irreversibilidad de Snowball en ZEROX.

Rondas medidas con el instrumento de D15A (snowball_agentes.py, 20 semillas).
Tiempo de ronda: T = 2*Delta (consulta-respuesta) o T = Delta (voto por gossip).
Profundidad de alineacion d = Delta/lambda bloques (lambda=1) para que el checkpoint
este en el pasado de todos los honestos antes de votar.
Baseline GHOSTDAG k=30, alpha=0,33: 130,41 s (d14-dagknight/salida_zerox2.txt:32).
epsilon conservador: MTTF de salida_ctmc.txt (Slush, sin contadores), P ~ T/MTTF.
"""
import numpy as np
from snowball_agentes import corre_config

OUT = []
BASE = 130.41


def p(s):
    OUT.append(s)
    print(s)


def main():
    p("=" * 108)
    p("D15A · latencia de irreversibilidad Snowball en ZEROX · 20 semillas · f=0,33")
    p(f"Baseline GHOSTDAG k=30, alpha=0,33: {BASE:.2f} s")
    p("Rondas: r90 = percentil 90 del numero de ronda en que decide cada honesto.")
    p("=" * 108)
    p("")
    configs = [
        ("k=20,q=12,q/k=0,60,b=11", dict(k=20, q=12, beta_conf=11)),
        ("k=50,q=30,q/k=0,60,b=11", dict(k=50, q=30, beta_conf=11)),
        ("k=50,q=32,q/k=0,64,b=11", dict(k=50, q=32, beta_conf=11)),
        ("k=100,q=60,q/k=0,60,b=11", dict(k=100, q=60, beta_conf=11)),
        ("k=100,q=65,q/k=0,65,b=11", dict(k=100, q=65, beta_conf=11)),
    ]
    medidas = {}
    p("--- Rondas medidas (alpha=0,33, p0=1, sin retardo) ---")
    p(f"{'config':>26} {'rondas_med':>10} {'r90':>6} {'rondas_max':>10} "
      f"{'mixtas':>7} {'con_rojo':>9}")
    for nombre, cfg in configs:
        r = corre_config(0.33, cfg["k"], cfg["q"], beta_conf=cfg["beta_conf"])
        medidas[nombre] = r
        p(f"{nombre:>26} {r['rondas_med']:10.1f} {r['r90_med']:6.0f} {r['rondas_max']:10d} "
          f"{r['mixtos']:7d} {r['rojos']:9d}")
    p("")
    p("--- LATENCIA (s) = d + r90 * T, con d = Delta (alineacion) ---")
    p("  T = 2*Delta (consulta-respuesta)  |  T = Delta (voto en gossip)")
    p(f"{'Delta':>6} {'d':>4} | " +
      " | ".join(f"{n.split(',')[0]:>22}" for n, _ in configs))
    for Delta in (1, 4, 16, 20):
        d = Delta
        for T_mult, etiqueta in ((2, "2D"), (1, "1D")):
            vals = []
            for nombre, _ in configs:
                r90 = medidas[nombre]["r90_med"]
                vals.append(d + r90 * T_mult * Delta)
            p(f"{Delta:6d} {d:4d} | " + " | ".join(f"{v:22.0f}" for v in vals) +
              f"   [{etiqueta}]")
    p("")
    p("--- GANA / PIERDE frente al baseline (r90, T=2D y T=1D) ---")
    p(f"{'Delta':>6} {'k=50,q=30 2D':>14} {'k=50,q=30 1D':>14} {'k=100,q=60 2D':>15} "
      f"{'k=100,q=60 1D':>15} {'veredicto':>22}")
    for Delta in (1, 2, 4, 8, 16, 20):
        r50 = medidas["k=50,q=30,q/k=0,60,b=11"]["r90_med"]
        r100 = medidas["k=100,q=60,q/k=0,60,b=11"]["r90_med"]
        v50_2 = Delta + r50 * 2 * Delta
        v50_1 = Delta + r50 * 1 * Delta
        v100_2 = Delta + r100 * 2 * Delta
        v100_1 = Delta + r100 * 1 * Delta
        mejor = min(v50_2, v100_2)
        ver = "GANA" if mejor < BASE else "PIERDE"
        p(f"{Delta:6d} {v50_2:14.0f} {v50_1:14.0f} {v100_2:15.0f} {v100_1:15.0f} "
          f"{ver:>22}")
    p("")
    p("--- EPSILON CONSERVADOR (CTMC Slush, salida_ctmc.txt) ---")
    p("f=0,33, k=50, q=30, n=10000: frontera del valle 0,7849 de los honestos;")
    p("log10 MTTF_c = 1692,4 rondas (10^1684,9 anos). P(fallo en T) ~ T/MTTF.")
    for T in (14, 30, 60, 130.41, 600):
        p(f"  T={T:7.2f} s -> log10 P_fallo ~ {-1692.4 + np.log10(T):.1f}")
    p("  Snowball con confianza es estrictamente mas fuerte que este Slush sin")
    p("  contadores (paper A.4); el numero es COTA, no medida de Snowball.")
    p("")
    p("--- COSTE DE GOSSIP (consulta dirigida) ---")
    p("Cada nodo que vota envia k consultas y recibe k respuestas por ronda.")
    p("Tamano de mensaje ~ 100 B (clave + firma Ed25519 64 B + color).")
    p(f"{'k':>4} {'bytes/nodo/ronda':>18} {'n=1000 (MB/s)':>14} {'n=10000 (MB/s)':>15} "
      f"{'n=100000 (MB/s)':>16}")
    for k in (20, 50, 100):
        b = 2 * k * 100
        p(f"{k:4d} {b:18d} {b*1000/1e6:14.1f} {b*10000/1e6:15.1f} {b*100000/1e6:16.1f}")
    p("  Solo si TODOS los nodos votan cada ronda. Con 1 decision/s y n=10000,")
    p("  k=50 son ~100 MB/s de red agregada: el PoT de ZEROX ya cuesta 9,6 % de")
    p("  un nucleo por nodo (dag-poas-ancla-de-orden.md:312). Voto embebido en")
    p("  bloque: ~32-64 B/bloque, 1-2 GB/ano, sin mensajes nuevos.")
    p("")
    with open("salida_latencia.txt", "w") as fh:
        fh.write("\n".join(OUT) + "\n")


if __name__ == "__main__":
    main()
