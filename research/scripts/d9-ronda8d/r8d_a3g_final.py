#!/usr/bin/env python3
"""
r8d_a3g_final.py — A3 DEFINITIVO. Corrige un defecto de mis propias medidas anteriores y
mide delta_ef con `pick_virtual_parents` COMPLETO (presupuesto + sustitucion + shuffle).

MI ERROR (declarado): en `r8d_a3_delta.py`, `r8d_a3b_optim.py`, `r8d_a3c/d/f` normalice por
la ESPERANZA (1-alpha)*lambda*r. El numero de honestos realmente creados en la ventana es
Poisson y fluctua ~3% con 5 semillas, asi que a alpha=0 salia delta_hon = 0,031 cuando el
valor verdadero es ~0 (con 8 semillas y T=900 salia 0,0063: era RUIDO). Aqui se normaliza
por los honestos REALMENTE creados en la ventana:

    delta_hon = 1 - (honestos de la ventana que acaban AZULES) / (honestos creados en la ventana)

Es la fraccion de bloques honestos que el atacante consigue dejar fuera del blue set: la
magnitud del Lema 9 (phantom-ghostdag.txt L1074-1077) sin el ruido de Poisson.

Criterio alpha: alpha = 0 -> delta_hon = huerfanos genuinos, que a k=30, lambda=1, D=4
deben ser ~0 (R-FIN-8 publica 1,2e-6).
"""
import sys
from r8d_lib import Mundo
from r8d_a3d_kaspa import MundoKaspa
from r8d_a3f_shuffle import MundoShuffle
from r8d_a1_menu import K, MP

T1, T2 = 80.0, 300.0
DELTA_NOM, DELTA_REAL = 8 / 38, 0.267


def delta(cls, alpha, semilla, T, u3_mode, copias, pol, retraso=0.0):
    m = cls(alpha, T, semilla, k=K, mp=MP, u3_mode=u3_mode)
    est = {i: (retraso, pol) for i, (t, q, *_) in enumerate(m.ev) if q == "a"}
    d, tip = m.corre(est, copias=copias)
    az = d.blueset(tip)
    hon = [h for h in d.B if d.B[h].creator == "h" and T1 < d.B[h].t <= T2]
    if not hon:
        return None
    return 1 - sum(1 for h in hon if h in az) / len(hon)


def prom(cls, alpha, u3, cop, pol, ret, sems, T=400.0):
    rs = [delta(cls, alpha, s, T, u3, cop, pol, ret) for s in sems]
    rs = [r for r in rs if r is not None]
    return sum(rs) / len(rs), max(rs)


if __name__ == "__main__":
    sems = list(range(1, 11))
    print("=== A3 DEFINITIVO · delta_ef con pick_virtual_parents COMPLETO ===")
    print(f"k={K}, mp={MP}, ventana [80,300] s, horizonte 400 s, 10 semillas.")
    print("Normalizado por los honestos REALMENTE creados (sin ruido de Poisson).")
    print(f"Cotas: nominal {DELTA_NOM:.4f} · real {DELTA_REAL}\n")
    print(f"{'u3':>8} {'cop':>4} {'pol':>11} {'ret':>4} | " +
          " ".join(f"{'a=' + f'{a:.2f}':>15}" for a in (0.0, 0.10, 0.25, 0.40)))
    peor = (0.0, None)
    escen = [("dynamic", 0, "tips", 0.0),
             ("dynamic", 0, ("retro", 1), 0.0),
             ("dynamic", 2, ("retro", 1), 0.0),
             ("dynamic", 6, ("retro", 1), 0.0),
             ("dynamic", 14, ("retro", 1), 0.0),
             ("dynamic", 14, ("retro", 2), 0.0),
             ("dynamic", 14, ("retro", 8), 0.0),
             ("dynamic", 14, ("retro", 1), 12.0),
             ("dynamic", 14, "tips", 0.0),
             ("filter", 14, ("retro", 1), 0.0),
             ("off", 14, ("retro", 1), 0.0)]
    for u3, cop, pol, ret in escen:
        fila = f"{u3:>8} {cop:>4} {str(pol):>11} {ret:>4.0f} |"
        for a in (0.0, 0.10, 0.25, 0.40):
            md, mx = prom(MundoShuffle, a, u3, cop, pol, ret, sems)
            fila += f"  {md:>7.4f}/{mx:>6.4f}"
            if u3 == "dynamic" and md > peor[0]:
                peor = (md, (cop, pol, ret, a))
        print(fila)
    print("\n(medio/peor semilla)")
    print(f"\nPEOR delta_hon medio con U3'' DINAMICA y pick_virtual_parents completo: "
          f"{peor[0]:.4f}  {peor[1]}")
    print(f"  vs cota nominal {DELTA_NOM:.4f}: {'SUPERA' if peor[0] > DELTA_NOM else 'NO la supera'}")
    print(f"  vs cota real    {DELTA_REAL}:  {'SUPERA' if peor[0] > DELTA_REAL else 'NO la supera'}")
