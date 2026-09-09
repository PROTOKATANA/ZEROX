#!/usr/bin/env python3
"""
C.1b · CRITERIO ALPHA bien hecho: `delta(alpha, Delta, k)` con la ráfaga del Lema 9 **escalada
con `k`**.

ERROR PROPIO que este script corrige. El control de alpha de C.1 usa `J = 31` fijo, que es
`k + 1` **solo para `k = 30`**. La maniobra del Lema 9 (`phantom-ghostdag.txt:1136-1141`) exige
publicar `k + 1` bloques en el anticono del padre seleccionado; con `k = 60` y `J = 31` la
ráfaga es demasiado corta y `delta` sale artificialmente bajo (0,0595 frente a 0,3066 de
`k = 30` a `Delta = 4 s`). Ese número NO dice que `k = 60` reduzca `delta` bajo ataque: dice
que el atacante estaba mal parametrizado. `delta_0` (alpha = 0) NO está afectado — sin atacante
no hay ráfaga —, así que C.1, C.2, D, E y F siguen en pie; lo que se corrige es el control.

Protocolo, el mismo que `d9-ronda10b/r10b_b2b_delta_k.py` (que a su vez repite
`d8-ronda8/d8_a1b_umbral.py:60-95`): para cada celda se toma el `J` que **maximiza** `delta`
sobre una rejilla que **escala con `k`**, 12 semillas, horizonte 1 800 s, ventana (60, 1 740],
`modo='parasito'`, `d_fork=1`, y las constantes de R-FIN-12 atadas a cada `k`.

Rejilla: `J in {k+1, 2k, 3k, 96}` (la de 10b era {16,31,48,64,96}, calibrada a k=30).
`k in {30, 40, 50, 60}`, `Delta in {4, 12, 20, 32}` s, `alpha in {0, 0,25, 0,33, 0,35, 0,40}`.
CONTROL: la celda `k=30, Delta=4, alpha in {0,25; 0,33; 0,35; 0,40}` debe reproducir
`d8-ronda8/salida_a1b.txt` (0,1544 / 0,2867 / 0,3065 / 0,4366), que 10b ya verificó.
"""
import os
import sys
import time
from multiprocessing import Pool

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import r11a_lib as R                                            # noqa: E402
from r9a_lib import MundoL9, contabilidad                       # noqa: E402
import d8_lib                                                   # noqa: E402
import r8c_sim                                                  # noqa: E402

SEMS = list(range(1, 13))
KS = [30, 40, 50, 60]
DELTAS = [4.0, 12.0, 20.0, 32.0]
ALPHAS = [0.00, 0.25, 0.33, 0.35, 0.40]
PUB_D8 = {0.25: 0.1544, 0.33: 0.2867, 0.35: 0.3065, 0.40: 0.4366}   # d8 salida_a1b.txt, k=30, D=4


def una(args):
    D, k, alpha, J, sem = args
    d8_lib.DELTA = D
    r8c_sim.LAMBDA = 1.0
    d8_lib.DAG = R.DAGContado
    m = MundoL9(alpha, 1800.0, sem, k=k, mp=R.max_block_parents(k),
                msl=R.mergeset_size_limit(k))
    d, tip, llega = m.corre_l9(J=J, d_fork=1, giveup=None, modo="parasito")
    c = contabilidad(d, tip, llega, 60.0, 1740.0)
    return (D, k, alpha, J, c["R"], c["H"], c["Wpub"], m.n_rafagas)


if __name__ == "__main__":
    t0 = time.time()
    tareas = []
    for k in KS:
        for J in sorted({k + 1, 2 * k, 3 * k, 96}):
            for D in DELTAS:
                for a in ALPHAS:
                    for s in SEMS:
                        tareas.append((D, k, a, J, s))
    print("=== C.1b · criterio alpha con la rafaga del Lema 9 ESCALADA con k ===")
    print(f"{len(tareas)} corridas; J in {{k+1, 2k, 3k, 96}}, 12 semillas, se toma el J que "
          f"MAXIMIZA delta (protocolo de r10b_b2b_delta_k.py).\n", flush=True)
    with Pool(30) as p:
        res = p.map(una, tareas, chunksize=4)
    print(f"[{time.time()-t0:.0f} s]\n", flush=True)

    acc = {}
    for D, k, a, J, Rr, H, W, raf in res:
        e = acc.setdefault((D, k, a, J), [0.0, 0.0, 0.0, 0.0, 0])
        e[0] += Rr; e[1] += H; e[2] += W; e[3] += raf; e[4] += 1

    mejor = {}
    for (D, k, a, J), e in acc.items():
        d = e[0] / e[1] if e[1] else 0.0
        cur = mejor.get((D, k, a))
        if cur is None or d > cur[0]:
            mejor[(D, k, a)] = (d, J, e[2] / e[1] if e[1] else 0.0, e[3] / e[4])

    print("--- CONTROL: k = 30, Delta = 4 s frente a d8-ronda8/salida_a1b.txt ---")
    ok = True
    for a in (0.25, 0.33, 0.35, 0.40):
        d, J, wh, raf = mejor[(4.0, 30, a)]
        bien = abs(d - PUB_D8[a]) < 0.02
        ok &= bien
        print(f"    alpha={a:.2f}: delta = {d:.4f} (J* = {J}), publicado {PUB_D8[a]:.4f}  "
              f"{'OK' if bien else 'DIFIERE'}")
    print(f"    -> {'4/4 OK' if ok else 'REVISAR'}\n")

    print("--- delta(alpha, Delta, k) con J* = argmax_J delta ---")
    for D in DELTAS:
        print(f"  Delta = {D:.0f} s")
        print(f"{'alpha':>7} | " + " ".join(f"{'k=%d' % k:>16}" for k in KS))
        for a in ALPHAS:
            fila = []
            for k in KS:
                d, J, wh, raf = mejor[(D, k, a)]
                fila.append(f"{d:>8.4f} (J={J:<3d}{'' if raf else '*'})"[:16].rjust(16))
            print(f"{a:>7.2f} | " + " ".join(fila))
        print()
    print("    (* = 0 rafagas: la maniobra NO se ejecuto y la celda no dice nada)")

    print("\n--- cobertura: rafagas medias por celda (alpha > 0) ---")
    print(f"{'Delta':>6} {'k':>4} | " + " ".join(f"{'a=%.2f' % a:>9}" for a in ALPHAS))
    for D in DELTAS:
        for k in KS:
            print(f"{D:>6.0f} {k:>4} | " +
                  " ".join(f"{mejor[(D,k,a)][3]:>9.1f}" for a in ALPHAS))
    print(f"\n[{time.time()-t0:.0f} s]")
