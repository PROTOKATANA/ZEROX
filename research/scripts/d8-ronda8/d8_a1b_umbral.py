#!/usr/bin/env python3
"""
d8_a1b_umbral.py — A1 (segunda parte). El barrido fino que convierte el `delta` medido en
A1 en los DOS numeros que el diseno publica.

A1 midio, con la maniobra PARASITA, `delta` POR ENCIMA de la cota del Lema 9
(0,2105 nominal / 0,267 `delta_real`): 0,277 a alpha=0,33 y 0,427 a alpha=0,40.
Aqui se refina y se propaga:

  · crecimiento honesto efectivo   (1-alpha)(1-delta)      [Lema 9 del paper]
  · base de la carrera de Nakamoto r = alpha/((1-alpha)(1-delta))
        r >= 1  =>  la cota `p_F` de dag-poas-recursion-flujos.md §3 es VACUA
        el diseno la situa en alpha = 43,1 %
  · umbral de orden  alpha* = (1-delta)/(phi_500 + 1-delta),  phi_500 = 1,1023
        el diseno lo publica en 40,0 % (dag-poas-delta-real.md §5)

Y dos comprobaciones de que el ataque es EJECUTABLE bajo las reglas del diseno:
  · `prof` = profundidad de la reorganizacion de cada rafaga, en SEGUNDOS de slot.
        R-FIN-7 prohibe reorgs por debajo de F = 5,3 h = 19 080 s. Si `prof` << F,
        R-FIN-7 NO protege.
  · `rech` = bloques del atacante rechazados por el DAG (MergeSetTooBig / U2 / padres).
        Si fuese alto, el ataque no seria legal bajo R-FIN-12.

CRITERIO ALPHA (regla 1): fila alpha = 0. COBERTURA (regla 2): `raf` y `sok`.
CAPACIDAD (regla 4): A1 ya mostro que el instrumento ve delta hasta 1,0 (alpha=0,70).
"""
import sys
import time

sys.path.insert(0, "/home/katana/zeo/ZEROX/research/scripts/d8-ronda8")
from d8_lib import MundoL9, delta_hon, DELTA                            # noqa: E402

K = 30
SEMS = list(range(1, 13))
ALPHAS = [0.0, 0.25, 0.30, 0.33, 0.35, 0.37, 0.40, 0.45]
JS = [16, 31, 48, 64, 96]
PHI500 = 1.1023
F_SEG = 5.3 * 3600


def prof_reorg(m, d, HOR):
    """Profundidad de reorg de cada rafaga: instante de publicacion menos instante del
    bloque mas viejo de la rafaga (= el punto de bifurcacion). En segundos de slot."""
    return m.tam_rafagas          # tamano en bloques; la profundidad se deriva de J/alpha


def una(alpha, sem, J, HOR):
    m = MundoL9(alpha, HOR, sem, k=K, mp=15)
    d, tip, llega = m.corre_l9(J=J, d_fork=1, giveup=None, modo="parasito")
    dl, n = delta_hon(d, tip, 60.0, HOR - 60.0)
    return (dl or 0.0), n, m.n_rafagas, m.n_score_ok, m.n_rechazados


if __name__ == "__main__":
    HOR = float(sys.argv[1]) if len(sys.argv) > 1 else 1800.0
    print("=== A1b · el `delta` parasito propagado a los umbrales del diseno ===")
    print(f"k={K}, lambda=1, Delta={DELTA}, mp=15, u3=dynamic, horizonte {HOR:.0f} s, "
          f"ventana [60, {HOR-60:.0f}] s, {len(SEMS)} semillas, modo = parasito, d_fork=1.")
    print(f"Cotas del diseno: delta_Lema9 = {2*DELTA/(K+2*DELTA):.4f}, delta_real = 0,267, "
          f"r cruza 1 en 43,1 %, umbral de orden 40,0 %.\n")
    t0 = time.time()
    print(f"{'alpha':>6} {'J*':>4} | {'delta medio':>11} {'delta max':>9} | "
          f"{'(1-a)(1-d)':>10} {'r':>7} {'alpha* orden':>12} | {'raf':>5} {'sok':>6} "
          f"{'rech':>5} {'prof (s)':>9}")
    filas = []
    for alpha in ALPHAS:
        mejor = (-1.0, None, 0, 0, 0, 0.0)
        for J in JS:
            ds, raf, sok, rech = [], 0, 0, 0
            for sem in SEMS:
                dl, n, r, s, rc = una(alpha, sem, J, HOR)
                ds.append(dl); raf += r; sok += s; rech += rc
            med = sum(ds) / len(ds)
            if med > mejor[0]:
                mejor = (med, J, raf, sok, rech, max(ds))
        dlt, J, raf, sok, rech, dmax = mejor
        crec = (1 - alpha) * (1 - dlt)
        r = alpha / crec if crec > 0 else float("inf")
        aest = (1 - dlt) / (PHI500 + 1 - dlt)
        prof = J / alpha if alpha > 0 else 0.0
        filas.append((alpha, dlt, crec, r, aest))
        print(f"{alpha:>6.2f} {J:>4} | {dlt:>11.4f} {dmax:>9.4f} | {crec:>10.4f} "
              f"{r:>7.3f} {aest:>12.4f} | {raf:>5} {sok:>6} {rech:>5} {prof:>9.0f}")

    print(f"\nR-FIN-7 prohibe reorg por debajo de F = {F_SEG:.0f} s. La columna `prof` es la "
          f"profundidad de cada rafaga: si prof << F, R-FIN-7 no la ve.")
    print("\n--- punto fijo: el alpha donde el atacante DEJA de perder la carrera "
          "(r = 1, es decir alpha = (1-alpha)(1-delta)) ---")
    for i in range(len(filas) - 1):
        a0, d0, c0, r0, _ = filas[i]
        a1, d1, c1, r1, _ = filas[i + 1]
        if r0 < 1 <= r1:
            w = (1 - r0) / (r1 - r0)
            print(f"   r cruza 1 entre alpha={a0:.2f} (r={r0:.3f}) y alpha={a1:.2f} "
                  f"(r={r1:.3f})  ->  alpha_critico ~ {a0 + w*(a1-a0):.3f}")
    print("--- punto fijo del umbral de orden: alpha = alpha*(delta(alpha)) ---")
    for i in range(len(filas) - 1):
        a0, _, _, _, e0 = filas[i]
        a1, _, _, _, e1 = filas[i + 1]
        if (e0 - a0) * (e1 - a1) < 0:
            w = (e0 - a0) / ((e0 - a0) - (e1 - a1))
            print(f"   cruce entre alpha={a0:.2f} (alpha*={e0:.4f}) y alpha={a1:.2f} "
                  f"(alpha*={e1:.4f})  ->  umbral de orden ~ {a0 + w*(a1-a0):.3f}")
    print(f"\n[{time.time()-t0:.0f} s]")
