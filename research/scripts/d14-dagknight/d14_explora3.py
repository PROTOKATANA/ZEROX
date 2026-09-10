#!/usr/bin/env python3
"""
d14_explora3.py — Tercera exploracion del control: k* sobre el DAG solo-honesto (tasa mu) con
retardo D, en el tamano real de la figura 3 (T = instante de confirmacion). Compara el colorador
voraz por bitsets (cota de maximizacion libre, F_k del paper) con el replay GHOSTDAG de r8c_gd.
"""
import os
import sys

_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, _DIR)

from d14_lib import genera_eventos, construye_paper, k_estrella_bitset, k_estrella_replay

LAM = 3.75
ALPHA = 0.2
SEMILLAS = list(range(1, 13))


def fila(mu, D, T, metodo, kmax=25):
    vals = []
    for s in SEMILLAS:
        ev = genera_eventos(mu, 0.0, T, s)
        bl = construye_paper(ev, D, "oculto")
        if metodo == "bitset":
            k, _ = k_estrella_bitset(bl, k_max=kmax, frac=0.5)
        else:
            k, _ = k_estrella_replay(bl, k_max=kmax, frac=0.5)
        vals.append(k)
    return vals


def main():
    print("=" * 100)
    print("CONTROL v3 — DAG solo-honesto. k* por semilla (12 semillas). Objetivo paper: 4 / 1 / 0")
    print("=" * 100)
    for mu_nom, mu in (("(1-a)l=3,0", 3.0), ("l=3,75", 3.75), ("2,5", 2.5)):
        print(f"\n--- tasa honesta mu = {mu_nom} ---")
        for D in (2.0, 1.0, 0.1):
            for T in (6.0, 12.0, 24.0, 60.0):
                vb = fila(mu, D, T, "bitset")
                vr = fila(mu, D, T, "replay")
                vb2 = [(-1 if x is None else x) for x in vb]
                vr2 = [(-1 if x is None else x) for x in vr]
                print(f"D={D:>4} T={T:>5} | bitset {vb2}  media {sum(vb2)/len(vb2):.2f} | "
                      f"replay {vr2}  media {sum(vr2)/len(vr2):.2f}")


if __name__ == "__main__":
    main()
