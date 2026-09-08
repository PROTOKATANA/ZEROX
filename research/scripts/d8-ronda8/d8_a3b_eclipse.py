#!/usr/bin/env python3
"""
d8_a3b_eclipse.py — A3, partes (M1 alpha=0,40), (M2) y (M3).

`d8_a3_smax.py` imprimio M1 hasta alpha=0,33 y se corto: una segunda tabla redundante
recalculaba todo el barrido para convertirlo a bloques/hora (error mio de escritura,
declarado en el informe). Aqui se completa la fila que faltaba y se ejecutan las dos medidas
de eclipse, que son las que llevan el vector.

(M2) ECLIPSE PARCIAL: un honesto `H_C` con el 5 % del espacio recibe TODO con `E` segundos de
     retraso extra — el atacante le retiene las puntas, no le corta la red. Se mide que
     fraccion de SUS bloques viola R-FIN-1a (y por tanto es INVALIDA, no huerfana).
(M3) ECLIPSE TOTAL de un grupo con fraccion `f`: solo puede colgar de sus propios bloques,
     separados Exp(f*lambda), luego `P(invalido) = exp(-f*lambda*S_max)`. Forma cerrada mas
     comprobacion Monte Carlo. Es la cota de la que sale el «f >= 0,09» de R-FIN-7.

Criterio alpha (regla 1): M2 se corre con alpha = 0 y 0,25; el eclipse NO necesita atacante
con espacio, y esa es justamente la conclusion.
"""
import math
import random
import sys
import time
from collections import defaultdict

sys.path.insert(0, "/home/katana/zeo/ZEROX/research/scripts/d8-ronda8")
from d8_a3_smax import m1, MundoEclipse, SMAXES, SEMS, HOR, K, MP        # noqa: E402

if __name__ == "__main__":
    print("=== A3b · eclipse: la parte de A3 que lleva el vector ===")
    print(f"k={K}, mp={MP}, lambda=1, Delta=4, u3=dynamic, horizonte {HOR:.0f} s, "
          f"{len(SEMS)} semillas.\n")
    t0 = time.time()

    print("--- (M2) eclipse parcial: honesto con f=5 % que recibe todo con E s de retraso ---")
    print(f"{'E (s)':>7} {'alpha':>6} | " +
          " ".join(f"{'inv S='+str(S):>12}" for S in SMAXES) + f" | {'n_C':>6}")
    for E in (0.0, 10.0, 20.0, 40.0, 100.0, 200.0):
        for alpha in (0.0, 0.25):
            tot = defaultdict(int)
            n = 0
            for sem in SEMS:
                m = MundoEclipse(alpha, HOR, sem, k=K, mp=MP, u3_mode="dynamic")
                gs, nc = m.corre_ecl(E, sem=sem)
                n += nc
                for S in SMAXES:
                    tot[S] += sum(1 for x in gs if x > S)
            print(f"{E:>7.0f} {alpha:>6.2f} | " +
                  " ".join(f"{tot[S]/max(n,1):>12.4f}" for S in SMAXES) + f" | {n:>6}")
    print(f"   [{time.time()-t0:.0f} s]")

    print("\n--- (M3) eclipse total de un grupo con fraccion f: P(invalido)=exp(-f*S_max) ---")
    print(f"{'f':>7} " + " ".join(f"{'S='+str(S):>12}" for S in SMAXES))
    for f in (0.005, 0.01, 0.02, 0.05, 0.09, 0.20):
        print(f"{f:>7.3f} " + " ".join(f"{math.exp(-f*S):>12.5f}" for S in SMAXES))
    rng = random.Random(7)
    n = 200000
    c = sum(1 for _ in range(n) if rng.expovariate(0.05) > 20)
    print(f"   Monte Carlo (f=0,05, S_max=20, {n} muestras): medido {c/n:.5f}  "
          f"cerrado {math.exp(-0.05*20):.5f}")

    print("\n--- (M1) la fila que faltaba: alpha = 0,40 ---")
    print(f"{'alpha':>6} | " + " ".join(f"{'S='+str(S):>12}" for S in SMAXES) +
          f" | {'gap max':>8} {'n_hon':>7}")
    acc = {S: 0.0 for S in SMAXES}
    gm = nh = 0
    for sem in SEMS:
        peor, gmax, n2, e = m1(0.40, sem)
        for S in SMAXES:
            acc[S] = max(acc[S], peor[S])
        gm = max(gm, gmax)
        nh = max(nh, n2)
    print(f"{0.40:>6.2f} | " + " ".join(f"{acc[S]:>12.5f}" for S in SMAXES) +
          f" | {gm:>8} {nh:>7}")
    print(f"   -> invalidados/hora = {acc[20]*3600*0.6:.1f} (S_max=20 s), "
          f"{acc[30]*3600*0.6:.1f} (30 s), {acc[150]*3600*0.6:.1f} (150 s)")
    print(f"\n[{time.time()-t0:.0f} s]")
