#!/usr/bin/env python3
r"""
d14k_explora_cierre.py — traza de un caso del ataque retención+cadena privada (sp con
retraso) para diseñar las mitigaciones. No genera tablas publicables.
Uso: python3 d14k_explora_cierre.py [alpha delta seed estrategia]
"""
import os
import sys

_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, _DIR)
_D9C = os.path.normpath(os.path.join(_DIR, "..", "d9-ronda8c"))
sys.path.insert(0, _D9C)

import math  # noqa: E402


def estrategia(m, nombre):
    at = [(i, e) for i, e in enumerate(m.ev) if e[1] == "a"]
    if nombre == "instant":
        return {}
    if nombre == "retraso20_sp":
        return {i: (20.0, "sp") for i, _ in at}
    if nombre == "retraso60_sp":
        return {i: (60.0, "sp") for i, _ in at}
    if nombre == "retraso20":
        return {i: (20.0, "tips") for i, _ in at}
    if nombre == "privada_inf":
        return {i: (1000.0, "sp") for i, _ in at}
    raise ValueError(nombre)


def main():
    a = float(sys.argv[1]) if len(sys.argv) > 1 else 0.40
    dd = float(sys.argv[2]) if len(sys.argv) > 2 else 20.0
    seed = int(sys.argv[3]) if len(sys.argv) > 3 else 11
    nombre = sys.argv[4] if len(sys.argv) > 4 else "retraso20_sp"

    import r8c_sim
    from r8c_sim import Mundo
    from d14k_lib import kdag_from_r8c, popcount, iter_bits
    import d14k_ref as R

    r8c_sim.LAMBDA = 1.0
    r8c_sim.DELTA = dd
    m = Mundo(alpha=a, T=400.0, seed=seed)
    d, tip = m.corre(estrategia=estrategia(m, nombre))
    kd, idx = kdag_from_r8c(d)
    H = {i for i in range(kd.n) if kd.creators[i] == "h"}
    tips = list(iter_bits(kd.tips_mask()))
    bw = R.global_blue_work(kd)

    print(f"α={a} Δ={dd} seed={seed} {nombre}: n={kd.n} tips={len(tips)}")
    print("tips:", [(f"b{t}", kd.creators[t], round(bw[t], 1)) for t in tips])
    # cadena GHOSTDAG global
    chain = set()
    for t in tips:
        cur = t
        while cur is not None:
            chain.add(cur)
            cur = kd.chain_parent[cur]
    ch_creators = "".join(kd.creators[c] for c in sorted(chain))
    print(f"cadena global (sp GHOSTDAG): {len(chain)} bloques, creadores h={ch_creators.count('h')} "
          f"a={ch_creators.count('a')}")
    # tip de la cadena global = max blue_work de los tips
    vsp_global = max(tips, key=lambda t: (bw[t], -t))
    print(f"vsp global b{vsp_global} creador={kd.creators[vsp_global]}")
    # Htip
    Htip = max([i for i in range(kd.n) if i in H], key=lambda i: (bw[i], -i))
    print(f"Htip b{Htip} en cadena global: {Htip in chain}")

    if len(tips) == 1:
        cg = 0
    else:
        cg = tips[0]
        for t in tips[1:]:
            cg = kd.chain_lca(cg, t)
    print(f"CG b{cg} creador={kd.creators[cg]}")

    grupos = {}
    for t in tips:
        nca = R.next_after(kd, t, cg)
        grupos.setdefault(nca, []).append(t)

    Hmask = 0
    for i in H:
        Hmask |= 1 << i

    for nca, gts in grupos.items():
        vsp = max(gts, key=lambda t: (bw[t], -t))
        print(f"\n--- subgrupo NCA=b{nca}({kd.creators[nca]}) vsp=b{vsp}({kd.creators[vsp]}) "
              f"tips={[f'b{t}' for t in gts]}")
        for k in range(0, 41):
            zd, zone = R.committed_coloring(kd, gts, nca, cg, k)
            vnd = R.virtual_coloring(kd, zd, tips, vsp, cg, k, bw)
            ok, score, blues, reds = R.umc_voting(kd, zd, cg, nca, vnd, k, bw)
            if ok:
                bmask = 0
                for b in blues:
                    bmask |= 1 << b
                hon = popcount(bmask & Hmask) / max(1, popcount(bmask))
                # cobertura de la cadena global
                falta = [c for c in chain if c != 0 and not ((bmask >> c) & 1)]
                # cierre de ancestros en la zona (futuro de cg)
                huecos = []
                for b in blues:
                    for p in kd.parents[b]:
                        if (zone >> p) & 1 and not ((bmask >> p) & 1):
                            huecos.append((b, p))
                print(f"  k={k:2d} ok score={score:4d} blues={len(blues)} reds={len(reds)} "
                      f"hon={hon:.2f} falta_cadena={len(falta)} huecos={len(huecos)} "
                      f"vsp_en_pasado_Htip={(kd.past[vsp] >> Htip) & 1 if kd.creators[vsp]=='a' else '-'}")
                break
        else:
            print("  k hasta 40: NINGÚN k acepta la UMC (congelación)")

    print("\nrank de la vista:", R.rank_dag(kd, kmax=40)[0])


if __name__ == "__main__":
    main()
