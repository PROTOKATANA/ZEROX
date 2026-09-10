#!/usr/bin/env python3
r"""
audita4_tiebreak.py — Tie-breaking con DOS cadenas honestas de igual rank.

Caso que D14B no aisló: una partición deja dos cadenas honestas A y B, ambas con
rank 0. El atacante no necesita ganar el rank: le basta con empatar y ganar el
desempate (Alg. 4). Se construye un DAG sintético:

  G(0)
   ├── A1(1)-A2(2)-A3(3)                 cadena A (honesta)
   └── B1(4)-B2(5)-B3(6)                 cadena B (honesta)
  atacante: 7,8,9 colgando de A3 (sin referenciar B) -> rojos de B, entran en F
            y su anticono corta la cadena de B (manipulación de C_i del Alg. 4).

Se compara: ganador con el proxy de D8c (argmin max|anticone∩chain|) y con el Alg. 4
fiel de audita1 (C_i = max_k' #{B∈F: |anticone(B)∩chain_{i,k'}|>k'}, hash=id).
"""
import os
import sys

_DIR = os.path.dirname(os.path.abspath(__file__))
D14K = os.path.normpath(os.path.join(_DIR, "..", "..", "d14-dagknight"))
D9C = os.path.normpath(os.path.join(_DIR, "..", "..", "d9-ronda8c"))
for p in (D14K, D9C):
    if p not in sys.path:
        sys.path.insert(0, p)

import audita1_grupos as A  # noqa: E402


def construye(n_atac):
    """n_atac bloques del atacante colgando de A3, sin referenciar B."""
    parents = [
        (),          # 0 G
        (0,),        # 1 A1
        (1,),        # 2 A2
        (2,),        # 3 A3
        (0,),        # 4 B1
        (4,),        # 5 B2
        (5,),        # 6 B3
    ]
    creators = ["g", "h", "h", "h", "h", "h", "h"]
    for j in range(n_atac):
        parents.append((3 + j,))          # 7←3, 8←7, ...
        creators.append("a")
    from d14k_lib import KDag
    kd = KDag(parents, [float(i) for i in range(len(parents))], creators)
    cp = [None] * kd.n
    for i in range(1, kd.n):
        cp[i] = kd.parents[i][0]          # cadena por el primer padre
    kd.set_chain(cp)
    return kd


def analiza(n_atac, verbose=True):
    import d14k_ref as R
    from d14k_lib import popcount
    kd = construye(n_atac)
    tips = [i for i in range(kd.n) if not (kd.future[i] & kd.full)]
    bw = R.global_blue_work(kd)
    kv, grupos, cg = A._rank_grupos(kd, tips, bw)
    if kv is None:
        if verbose:
            print(f"n_atac={n_atac}: sin ganador")
        return None
    wins = [g for g in grupos if g["k"] == kv]
    gsel = A._tie_break_fiel(kd, wins, kv, cg)
    if verbose:
        print(f"n_atac={n_atac} tips={tips} k_view={kv} cg={cg}")
        for g in grupos:
            print(f"   nca={g['nca']}({kd.creators[g['nca']]}) vsp={g['vsp']}"
                  f"({kd.creators[g['vsp']]}) k={g['k']} score={g['score']} "
                  f"ntips={len(g['tips'])}")
        print(f"   -> ganador Alg.4 = b{gsel['vsp']} ({kd.creators[gsel['vsp']]})")
    return kd.creators[gsel["vsp"]]


def main():
    print("=" * 100)
    print("Tie-breaking sintético: dos cadenas honestas A y B de igual rank + atacante en A")
    print("=" * 100)
    for n in range(0, 8):
        analiza(n)
    print()
    print("Si el ganador pasa de 'h' a 'a' al añadir bloques del atacante, el desempate")
    print("es manipulable sin ganar el rank; si sigue 'h', el proxy no se deja manipular.")


if __name__ == "__main__":
    main()
