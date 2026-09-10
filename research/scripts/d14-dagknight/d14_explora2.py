#!/usr/bin/env python3
"""
d14_explora2.py — Segunda exploracion del control: el DAG de la figura 3 tiene el tamano del
instante de confirmacion (T = 12 / 6 / 1,2 s), no un DAG maduro de 60 s. Se prueba:

  · k* con cobertura global >= 50 % sobre el DAG solo-honesto de tasa (1-alpha)*lambda
  · k* con la condicion UMC real del paper (dagknight.txt:600-602, 709-719):
        para todo B del cluster: |future(B) cap C| + g(k) >= |future(B) \\ C|, g(k)=floor(sqrt(k))
  · varias semillas y varios T para ver la dispersion
"""
import os
import sys

_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, _DIR)

from d14_lib import (genera_eventos, construye_paper, cobertura_replay,
                     replay_gd, GEN)

LAM = 3.75
ALPHA = 0.2
MU = (1 - ALPHA) * LAM          # tasa honesta
SEMILLAS = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]


def umc_pasa(bloques, k, frac=0.5, verbose=False):
    """Minimo k tal que el k-cluster (replay r8c) cumple UMC con deficit g(k)=floor(sqrt(k)).
    Devuelve (k, cobertura_global, umc_ok)."""
    import math
    d, tip = replay_gd(bloques, k)
    blues = d.blueset(tip) - {GEN}
    n = len(bloques) - 1
    cob = len(blues) / n
    # UMC: para cada bloque del cluster, su future (estricto) cubierto salvo g(k)
    g = int(math.isqrt(k))
    idx = {b[0]: i for i, b in enumerate(bloques)}
    fut = {bid: set() for bid in d.B}
    for bid, ps, t, c in bloques:
        for p in ps:
            fut[p].add(bid)
    # cierre transitivo
    orden = [b[0] for b in bloques]
    for bid in reversed(orden):
        acum = set()
        for h in fut[bid]:
            acum |= fut[h]
        fut[bid] |= acum
    for b in blues:
        fb = fut[b]
        if len(fb) == 0:
            continue
        dentro = len(fb & blues)
        fuera = len(fb - blues)
        if dentro + g < fuera:
            return k, cob, False
    return k, cob, True


def k_estrella_umc(bloques, k_max=30, frac=0.5):
    for k in range(k_max + 1):
        kk, cob, ok = umc_pasa(bloques, k, frac)
        if ok and cob >= frac:
            return kk, cob
    return None, None


def main():
    print("=" * 100)
    print("CONTROL v2 — DAG solo-honesto, tasa (1-alpha)*lambda = 3,0 bloques/s")
    print("k* = minimo k con cobertura global >= 50 % (replay r8c_gd)")
    print("=" * 100)
    for T in (1.2, 6.0, 12.0, 24.0, 60.0):
        filas = []
        for s in SEMILLAS:
            ev = genera_eventos(MU, 0.0, T, s)
            bl = construye_paper(ev, 0.0, "oculto")   # solo hay honestos
            ks = [k for k in range(0, 25) if cobertura_replay(bl, k) >= 0.5]
            filas.append(ks[0] if ks else None)
        print(f"T={T:>5} s (n~{MU*T:>4.0f})  k* por semilla: {filas}")
    print()
    print("=" * 100)
    print("CONTROL v2b — condicion UMC real, g(k)=floor(sqrt(k))  (12 semillas)")
    print("=" * 100)
    for D in (2.0, 1.0, 0.1):
        for T in (12.0, 24.0, 60.0):
            vals = []
            for s in SEMILLAS[:6]:
                ev = genera_eventos(MU, 0.0, T, s)
                bl = construye_paper(ev, D, "oculto")
                k, cob = k_estrella_umc(bl, k_max=20)
                vals.append(k)
            print(f"D={D:>4} T={T:>5} s  k*_umc por semilla: {vals}")


if __name__ == "__main__":
    main()
