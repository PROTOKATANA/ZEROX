#!/usr/bin/env python3
"""
d14_explora.py — Exploracion previa al control positivo.

Objetivo: decidir COMO se mide k* (el k minimo cuyo k-cluster cubre >= 50 % del DAG) para que
el instrumento reproduzca los k = 4 / 1 / 0 de dagknight.txt:182-197 (lambda=3,75, alpha=0,2,
D = 2 / 1 / 0,1 s). Se comparan dos coloraciones sobre el MISMO DAG:

  (a) voraz topologica con bitsets (anticone azul <= k)  -> rapida, aproximada
  (b) replay fiel en r8c_gd.DAG (GHOSTDAG de rusty-kaspa) -> lenta, es el instrumento importado

y tres variantes del DAG:
  (i)   solo honestos, tasa (1-alpha)*lambda, retardo D
  (ii)  DAG completo, atacante OCULTO que publica todo al final
  (iii) DAG completo, atacante INSTANTANEO (publica al momento)

Modelo del paper: cada bloque referencia TODAS las puntas visibles
(dagknight.txt:907-910). El atacante ve todo al instante (dagknight.txt:321-327).
"""
import os
import sys

_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, _DIR)

from d14_lib import (genera_eventos, construye_paper, k_estrella_bitset,
                     k_estrella_replay, cobertura_bitset, cobertura_replay)

LAM = 3.75
ALPHA = 0.2
T = 60.0
SEED = 1


def main():
    print("=" * 100)
    print("EXPLORACION — lambda=3,75  alpha=0,2  T=60 s  seed=1")
    print("k* = minimo k con cobertura azul >= 50 % del DAG (sin genesis)")
    print("=" * 100)
    for D in (2.0, 1.0, 0.1):
        casos = {
            "solo_h": genera_eventos((1 - ALPHA) * LAM, 0.0, T, SEED),
            "oculto": genera_eventos(LAM, ALPHA, T, SEED),
            "instant": genera_eventos(LAM, ALPHA, T, SEED),
        }
        for modo, ev in casos.items():
            bl = construye_paper(ev, D, "oculto" if modo == "solo_h" else modo)
            n = len(bl)
            kb, cb = k_estrella_bitset(bl, k_max=60, frac=0.5)
            kr, cr = k_estrella_replay(bl, k_max=60, frac=0.5)
            print(f"D={D:>4}  modo={modo:>8}  n={n:>4} | "
                  f"bitset k*={kb!s:>4} (cob {cb:.3f}) | replay k*={kr!s:>4} (cob {cr:.3f})")
        print()
    ev = genera_eventos(LAM, ALPHA, T, SEED)
    bl = construye_paper(ev, 2.0, "oculto")
    print("Curva de cobertura (D=2, oculto):")
    print(f"{'k':>3} {'bitset':>8} {'replay':>8}")
    for k in range(0, 10):
        print(f"{k:>3} {cobertura_bitset(bl, k):>8.4f} {cobertura_replay(bl, k):>8.4f}")


if __name__ == "__main__":
    main()
