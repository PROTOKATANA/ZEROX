#!/usr/bin/env python3
"""
r8d_a3c_horizonte.py — CONTROL de mi propia medida de delta_hon: ?es permanente el dano,
o solo «todavia no fusionado»?

Se fija la VENTANA en tiempo absoluto [80, 300] s y se alarga el HORIZONTE de simulacion
(400, 800, 1200 s). Si delta_hon baja al alargar el horizonte, los honestos solo estaban
pendientes de fusion y mi medida estaba inflada. Si no baja, el dano es permanente.

Criterio alpha: alpha = 0 -> delta_hon ~ 0 (solo huerfanos honestos genuinos).
"""
from r8d_lib import Mundo, LAMBDA
from r8d_a1_menu import K, MP

T1, T2 = 80.0, 300.0


def medida(alpha, semilla, T, u3_mode, copias, pol):
    m = Mundo(alpha, T, semilla, k=K, mp=MP, u3_mode=u3_mode)
    est = {i: (0.0, pol) for i, (t, q, *_) in enumerate(m.ev) if q == "a"}
    d, tip = m.corre(est, copias=copias)
    az = d.blueset(tip)
    hon = [h for h in d.B if d.B[h].creator == "h" and T1 < d.B[h].t <= T2]
    ha = sum(1 for h in hon if h in az)
    nf = sum(1 for h in hon if h != tip and h not in d.anc[tip])
    return 1 - ha / ((1 - alpha) * LAMBDA * (T2 - T1)), nf


if __name__ == "__main__":
    print("=== A3(3) · control de horizonte sobre delta_hon (ventana fija [80, 300] s) ===\n")
    print(f"{'u3':>8} {'cop':>4} | {'alpha':>5} | " +
          " ".join(f"{'T=' + str(T):>18}" for T in (400, 800, 1200)))
    for u3, cop, pol in (("dynamic", 0, "tips"), ("dynamic", 14, ("retro", 1)),
                         ("filter", 14, ("retro", 1))):
        for a in (0.0, 0.25, 0.40):
            fila = f"{u3:>8} {cop:>4} | {a:>5.2f} |"
            for T in (400, 800, 1200):
                rs = [medida(a, s, T, u3, cop, pol) for s in range(1, 6)]
                dh = sum(r[0] for r in rs) / len(rs)
                nf = sum(r[1] for r in rs) / len(rs)
                fila += f"  d={dh:>6.4f} nf={nf:>4.1f}"
            print(fila)
