#!/usr/bin/env python3
"""
r8c_a1d_control.py — CONTROL de modelo. ?Cuanto de la `m` que mido viene de darle al atacante
el privilegio del paper (retardo cero en las dos direcciones, L1024-1027)?

Se repite todo con `atacante_sin_retardo=False`: el atacante sufre el MISMO Delta = 4 s que los
honestos, tanto para ver como para entregar. Es el modelo MAS FAVORABLE al diseno.

Si `m` sigue siendo > 1 con este control, el ataque no depende del privilegio del modelo.
"""
import statistics
from r8c_sim import Mundo
from r8c_a1_menu import estrategias, K, MP


def mide(alpha, semilla, P, sin_retardo, T=260.0):
    m = Mundo(alpha, T, semilla, k=K, mp=MP, u3_mode="dynamic",
              atacante_sin_retardo=sin_retardo)
    d0, tip0 = m.corre({})
    ch = d0.selected_chain(tip0)
    lc = (len(ch) - 1) / T
    fr = sum(1 for b in ch[1:] if d0.B[b].creator == "a") / max(1, len(ch) - 1)
    tiers, idx = estrategias(m, P, d0, tip0)
    if tiers is None:
        return None
    acum, res = set(), []
    for g in tiers:
        for e in g:
            d, tip = m.corre(e)
            s = Mundo.ancla(d, tip, P)
            if s is not None:
                acum.add(s)
        res.append(len(acum))
    return lc, fr, res


if __name__ == "__main__":
    print("=== A1d · control de modelo: el atacante TAMBIEN sufre Delta = 4 s ===\n")
    for sin_ret in (True, False):
        etq = "paper (atacante sin retardo)" if sin_ret else "CONTROL (atacante con Delta)"
        print(f"--- {etq} ---")
        print(f"{'alpha':>6} {'lambda_chain':>13} {'% cadena atac.':>15} "
              f"{'m GRATIS':>10} {'m +retraso':>12} {'m +retencion':>14}")
        for a in (0.0, 0.10, 0.25, 0.40):
            filas = [mide(a, s, 30, sin_ret) for s in range(1, 9)]
            filas = [f for f in filas if f]
            if not filas:
                continue
            lc = statistics.mean(f[0] for f in filas)
            fr = statistics.mean(f[1] for f in filas)
            m1 = statistics.mean(f[2][0] for f in filas)
            m2 = statistics.mean(f[2][1] for f in filas)
            m3 = statistics.mean(f[2][2] for f in filas)
            print(f"{a:>6.2f} {lc:>13.4f} {100*fr:>14.1f}% {m1:>10.2f} {m2:>12.2f} {m3:>14.2f}")
        print()
