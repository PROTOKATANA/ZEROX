#!/usr/bin/env python3
"""
d14_explora4.py — CONTROL del TIEMPO. Hipotesis natural de cliente:

    el cliente confirma cuando un k-cluster de ancho k_target cubre >= 50 % de SU vista actual.

k_target = 4 / 1 / 0 para D = 2 / 1 / 0,1 (el k de la figura). DAG solo-honesto, tasa
(1-alpha)*lambda = 3,0. Se mide el primer instante de cruce por semilla. Objetivo: 12 / 6 / 1,2 s.
"""
import os
import sys

_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, _DIR)

from d14_lib import genera_eventos, construye_paper, cobertura_replay, GEN

LAM = 3.75
ALPHA = 0.2
MU = (1 - ALPHA) * LAM
SEMILLAS = list(range(1, 13))
OBJ = {2.0: (4, 12.0), 1.0: (1, 6.0), 0.1: (0, 1.2)}


def primer_cruce(bloques, k, frac=0.5):
    """Primer instante t en que el prefijo (bloques creados <= t) tiene cobertura >= frac.
    Devuelve (t, n)."""
    pref = [bloques[0]]
    for b in bloques[1:]:
        pref.append(b)
        if len(pref) - 1 < 2:
            continue
        if cobertura_replay(pref, k) >= frac:
            return b[2], len(pref) - 1
    return None, len(bloques) - 1


def main():
    print("=" * 100)
    print("CONTROL TIEMPO — 'confirmar cuando el k-cluster cubre >= 50 % de mi vista'")
    print("Objetivo paper: D=2 -> k=4, 12 s | D=1 -> k=1, 6 s | D=0,1 -> k=0, 1,2 s")
    print("=" * 100)
    for D, (k, obj) in OBJ.items():
        ts = []
        for s in SEMILLAS:
            ev = genera_eventos(MU, 0.0, 60.0, s)
            bl = construye_paper(ev, D, "oculto")
            t, n = primer_cruce(bl, k)
            ts.append(t)
        vals = [t for t in ts if t is not None]
        med = sum(vals) / len(vals) if vals else float("nan")
        print(f"D={D:>4}  k={k}  cruces (s): {[None if t is None else round(t,2) for t in ts]}")
        print(f"        media = {med:.2f} s   (objetivo {obj} s)   n_cruce~{MU*med:.1f} bloques")
    print()
    # sensibilidad al k elegido
    print("Sensibilidad: media del primer cruce para k_target +- 1")
    for D in (2.0, 1.0, 0.1):
        base = OBJ[D][0]
        for k in (max(0, base - 1), base, base + 1):
            vals = []
            for s in SEMILLAS:
                ev = genera_eventos(MU, 0.0, 60.0, s)
                bl = construye_paper(ev, D, "oculto")
                t, n = primer_cruce(bl, k)
                if t is not None:
                    vals.append(t)
            print(f"   D={D:>4} k={k}: media {sum(vals)/len(vals):.2f} s ({len(vals)}/12)")


if __name__ == "__main__":
    main()
