#!/usr/bin/env python3
r"""
d14k_sondeo.py — sondeo rápido: ¿qué semillas capturan con retención+cadena privada?
No publicable; guía el diseño de d14k_ataque2.py.
"""
import os
import sys

_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, _DIR)
sys.path.insert(0, os.path.normpath(os.path.join(_DIR, "..", "d9-ronda8c")))

from d14k_ataque2 import estrategia, rank_por_grupo, tie_break_fiel  # noqa: E402

import r8c_sim  # noqa: E402
from r8c_sim import Mundo  # noqa: E402
from d14k_lib import kdag_from_r8c, iter_bits  # noqa: E402
import d14k_ref as R  # noqa: E402


def main():
    a = float(sys.argv[1]) if len(sys.argv) > 1 else 0.40
    dd = float(sys.argv[2]) if len(sys.argv) > 2 else 20.0
    nombre = sys.argv[3] if len(sys.argv) > 3 else "retraso20_sp"
    for seed in [11, 23, 37, 41, 59, 67, 73, 89, 97, 101, 113, 127]:
        r8c_sim.LAMBDA = 1.0
        r8c_sim.DELTA = dd
        m = Mundo(alpha=a, T=400.0, seed=seed)
        d, _ = m.corre(estrategia=estrategia(m, nombre))
        kd, _ = kdag_from_r8c(d)
        tips = list(iter_bits(kd.tips_mask()))
        bw = R.global_blue_work(kd)
        kv, grupos, cg = rank_por_grupo(kd, tips, bw)
        Hmask = 0
        for i in range(kd.n):
            if kd.creators[i] == "h":
                Hmask |= 1 << i
        h_tips = [t for t in tips if (Hmask >> t) & 1]
        Htip = max(h_tips, key=lambda i: (bw[i], -i)) if h_tips else None
        gan_is_att = captura = 0
        gan_vsp = None
        if kv is not None:
            wins = [g for g in grupos if g["k"] == kv]
            gsel = tie_break_fiel(kd, wins, kv, cg)
            gan_vsp = gsel["vsp"]
            gan_is_att = int(kd.creators[gan_vsp] == "a")
            if gan_is_att and Htip is not None:
                captura = int(not ((kd.past[gan_vsp] >> Htip) & 1))
        print(f"seed={seed:3d} n={kd.n} tips={len(tips)} grupos={len(grupos)} kv={kv} "
              f"gan=b{gan_vsp}({kd.creators[gan_vsp] if gan_vsp is not None else '-'}) "
              f"Htip=b{Htip} captura={captura}")


if __name__ == "__main__":
    main()
