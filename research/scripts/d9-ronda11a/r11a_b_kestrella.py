#!/usr/bin/env python3
"""
B · `k*(Delta)`: el punto fijo de `verif_tau_vs_lambda.py` (copiado con cita en
`r11a_lib.kopt`, con `D` y el techo del barrido como parametros) para
`D in {4, 8, 12, 16, 20, 24, 32}` s, con `tau = 1 s`, y con `lambda = 1` y `lambda = 1/2`.

Que es `k*`: el `k` que MINIMIZA la reversion a 600 s (`prev(0,25, lambda_real, 600, 3k,
1-delta_real)`) sujeto a las dos restricciones autoconsistentes del original:
   lambda_real = k*lambda/(k - 2*D*lambda) <= 2*lambda        (fuera del polo)
   k >= k_Poisson(2*D*lambda_real, 1e-3)                      (punto fijo del retarget)
`delta_real = 2*D*lambda_real/(k + 2*D*lambda_real)` es el `delta` del Lema 9 bajo el sesgo
sostenido del retarget (`research/dag-poas-delta-real.md` §1).

OJO — lo que esta tabla NO es: `delta_real` es la COTA del Lema 9 (caso peor del paper, bajo
ataque sostenido), no lo que se mide. El `delta_0` MEDIDO a alpha = 0 va en C. Regla 6.

Cabeceras/ano: `365*86400*lambda*B/1e9` GB con B = 683 B (la cabecera del diseno con 4 padres,
`dag-poas-ancla-de-orden.md`:424) y con B = 555 + 32*max_block_parents(k) (el tope de R-FIN-12,
cota superior). Bytes reales medidos, en D.
"""
import os
import sys
import time
from multiprocessing import Pool

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import r11a_lib as R                                            # noqa: E402

DS = [4.0, 8.0, 12.0, 16.0, 20.0, 24.0, 32.0]
LAMS = [1.0, 0.5]
SEG_ANO = 365 * 24 * 3600


def una(args):
    lam, D = args
    kmax = int(max(120, 12 * D * lam + 120))
    r = R.kopt(lam, D, kmax)
    return (lam, D, r, kmax)


if __name__ == "__main__":
    t0 = time.time()
    print("=== B · k*(Delta) del punto fijo, tau = 1 s ===")
    print("copia parametrizada de verif_tau_vs_lambda.py:16-30 (control A.1: k*(4, lam=1) = 29)\n")
    with Pool(14) as p:
        res = p.map(una, [(lam, D) for lam in LAMS for D in DS])
    tab = {(lam, D): r for lam, D, r, _ in res}
    kmaxs = {(lam, D): km for lam, D, _, km in res}

    for lam in LAMS:
        print(f"--- lambda = {lam} bloque/s (intervalo {1/lam:.0f} s), tau = 1 s ---")
        print(f"{'Delta':>6} {'2*D*lam':>8} {'k*':>5} {'2*D*lam/k*':>11} {'lam_real':>9} "
              f"{'delta_real':>11} {'rev 600 s':>11} {'padres':>7} {'msl':>5} "
              f"{'cab/ano 683B':>13} {'cab/ano tope':>13} {'techo k':>8}")
        for D in DS:
            r = tab[(lam, D)]
            if r is None:
                print(f"{D:>6.0f} {2*D*lam:>8.1f} {'SIN PUNTO FIJO':>60}")
                continue
            k, pr, dr, lr = r
            mbp = R.max_block_parents(k)
            msl = R.mergeset_size_limit(k)
            cab683 = SEG_ANO * lam * 683 / 1e9
            cabtop = SEG_ANO * lam * (R.BYTES_BASE + R.BYTES_PADRE * mbp) / 1e9
            print(f"{D:>6.0f} {2*D*lam:>8.1f} {k:>5} {2*D*lam/k:>11.3f} {lr:>9.3f} "
                  f"{dr:>11.4f} {pr:>11.2e} {mbp:>7} {msl:>5} "
                  f"{cab683:>10.1f} GB {cabtop:>10.1f} GB {kmaxs[(lam,D)]:>8}")
        print()

    print("--- lectura directa: cuanto k pide cada Delta, y el cociente 2*D*lam/k* ---")
    print(f"{'Delta':>6} | {'k* (lam=1)':>11} {'k* (lam=1/2)':>13} | "
          f"{'k*(1)/k*(1/2)':>14} | {'delta_real(1)':>14} {'delta_real(1/2)':>16}")
    for D in DS:
        r1, r2 = tab[(1.0, D)], tab[(0.5, D)]
        if r1 is None or r2 is None:
            continue
        print(f"{D:>6.0f} | {r1[0]:>11} {r2[0]:>13} | {r1[0]/r2[0]:>14.2f} | "
              f"{r1[2]:>14.4f} {r2[2]:>16.4f}")
    print(f"\n[{time.time()-t0:.0f} s]")
