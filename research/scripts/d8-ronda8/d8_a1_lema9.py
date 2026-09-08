#!/usr/bin/env python3
"""
d8_a1_lema9.py — A1 · ¿es SOSTENIBLE el sesgo `delta` del Lema 9?

La pregunta. Todos los umbrales del diseno (orden 40,0 %, flujo unico ~35 %,
`dag-poas-delta-real.md`) usan `delta = 2*D*lambda_real/(k+2*D*lambda_real) = 0,267`
(o 0,2105 con `lambda=1`). Ese numero sale del Lema 9
(`research/fuentes/phantom-ghostdag.txt` L1131-1141), que describe **un solo evento**:

  «the adversary gains the most by publishing k+1 blocks in the anticone of the selected
   parent such that the most recent published block has score at least as large as that of
   the selected parent ... On average, there are at most 2*D*lambda such blocks, so that the
   adversary has managed to replace k + 2*D*lambda blue blocks with k+1 blue blocks.»

Un evento **no es un ritmo**. Cada rafaga consume `J >= k+1` bloques del atacante, que
tarda `J/(alpha*lambda)` segundos en fabricar; en ese tiempo los honestos fabrican
`(1-alpha)*lambda*J/alpha`. De donde la COTA DE RITMO:

      delta_sost(alpha) = min( 2*D*lambda / (J*(1-alpha)/alpha) ,  delta_max )
                        = min( 2*D*alpha / (J*(1-alpha)) , 2*D*lambda/(k+2*D*lambda) )

Con D=4, lambda=1, k=30, J=k+1=31:  alpha=0,25 -> 0,086 ; 0,40 -> 0,172 ; 0,449 -> 0,2105.
Es una PREDICCION, no un resultado. Aqui se MIDE.

TRES FAMILIAS de maniobra (anidadas en J; `modo` es la estructura de la rafaga):
  'cadena'   cadena privada pura desde `ancla` (la lectura literal del Lema 9).
  'abanico'  J-1 en paralelo desde `ancla` + 1 de cierre.
  'parasito' NUEVO EN D8. Cada bloque privado fusiona la VISTA HONESTA del instante
             (todo lo ya entregado) MAS la punta privada: el atacante hereda el blue_work
             honesto y su ventaja crece a ritmo `alpha` sin carrera. Ninguna estrategia de
             D9-c/d/e/f la contiene (todas publican inmediatamente o con retraso fijo).

CAPACIDAD DEL INSTRUMENTO (regla 4). Se imprime `raf` = rafagas EJECUTADAS y `sok` = veces
que se cumplio la condicion de score. Si `raf = 0` la maniobra NO ocurrio y la fila no dice
nada sobre delta; el control `alpha = 0,55/0,70` demuestra que el instrumento SI detecta un
delta grande cuando existe.
CRITERIO ALPHA (regla 1): la fila `alpha = 0` es el valor neutro.
"""
import sys
import time
from collections import defaultdict

sys.path.insert(0, "/home/katana/zeo/ZEROX/research/scripts/d8-ronda8")
from d8_lib import MundoL9, delta_hon                                    # noqa: E402
from d8_lib import DELTA                                                 # noqa: E402

K = 30
HOR = 600.0
T0, T1 = 60.0, 540.0          # ventana de medida: fuera del calentamiento y de la cola
SEMS = list(range(1, 13))     # 12 semillas (regla 3)
ALPHAS = [0.0, 0.10, 0.25, 0.33, 0.40, 0.45, 0.55, 0.70]
JS = [2, 4, 8, 16, 31, 48, 96]
MODOS = ["cadena", "abanico", "parasito"]
DFORKS = [1, 4]
GIVEUPS = [None, 20]

DELTA_MAX = 2 * DELTA * 1.0 / (K + 2 * DELTA * 1.0)          # 0,2105  (lambda = 1)
DELTA_MAX_REAL = 0.267                                        # dag-poas-delta-real.md


def prediccion(alpha, J):
    if alpha <= 0:
        return 0.0
    return min(2 * DELTA * alpha / (J * (1 - alpha)), DELTA_MAX)


def una(alpha, sem, modo, J, d_fork, giveup):
    m = MundoL9(alpha, HOR, sem, k=K, mp=15)
    d, tip, llega = m.corre_l9(J=J, d_fork=d_fork, giveup=giveup, modo=modo)
    dl, n = delta_hon(d, tip, T0, T1)
    return (dl if dl is not None else 0.0), n, m.n_rafagas, m.n_score_ok


if __name__ == "__main__":
    print("=== A1 · sostenibilidad del sesgo del Lema 9 ===")
    print(f"k={K}, lambda=1, Delta={DELTA}, mp=15, u3=dynamic, horizonte {HOR:.0f} s, "
          f"ventana de medida [{T0:.0f}, {T1:.0f}] s, {len(SEMS)} semillas.")
    print(f"delta_max (Lema 9, lambda=1) = {DELTA_MAX:.4f}; "
          f"delta_real (dag-poas-delta-real.md) = {DELTA_MAX_REAL:.3f}")
    print("delta MEDIDO = fraccion de bloques honestos creados en la ventana que NO estan en "
          "el blue set de la vista honesta final.\n")
    t_ini = time.time()

    # ---- barrido completo: para cada alpha, el MAXIMO sobre la familia ----
    print(f"{'alpha':>6} | {'delta MAX medido':>16} {'estrategia que lo logra':>34} | "
          f"{'raf':>5} {'sok':>6} | {'pred. ritmo':>11} {'delta_max':>9}")
    resumen = {}
    detalle = defaultdict(dict)
    for alpha in ALPHAS:
        mejor = (-1.0, None, 0, 0)
        for modo in MODOS:
            for J in JS:
                for d_fork in DFORKS:
                    for giveup in GIVEUPS:
                        ds, raf, sok, nh = [], 0, 0, 0
                        for sem in SEMS:
                            dl, n, r, s = una(alpha, sem, modo, J, d_fork, giveup)
                            ds.append(dl); raf += r; sok += s; nh += n
                        med = sum(ds) / len(ds)
                        detalle[alpha][(modo, J, d_fork, giveup)] = (med, raf, sok)
                        if med > mejor[0]:
                            mejor = (med, (modo, J, d_fork, giveup), raf, sok)
        resumen[alpha] = mejor
        Jm = mejor[1][1]
        print(f"{alpha:>6.2f} | {mejor[0]:>16.4f} {str(mejor[1]):>34} | "
              f"{mejor[2]:>5} {mejor[3]:>6} | {prediccion(alpha, Jm):>11.4f} "
              f"{DELTA_MAX:>9.4f}")

    print("\n--- por modo (maximo sobre J, d_fork, giveup) ---")
    print(f"{'alpha':>6} | " + " ".join(f"{m:>22}" for m in MODOS))
    for alpha in ALPHAS:
        fila = []
        for modo in MODOS:
            sub = [(v[0], k, v[1]) for k, v in detalle[alpha].items() if k[0] == modo]
            mx = max(sub)
            fila.append(f"{mx[0]:>8.4f} (J={mx[1][1]:>2},raf={mx[2]:>3})")
        print(f"{alpha:>6.2f} | " + " ".join(f"{f:>22}" for f in fila))

    print("\n--- curva delta_sost(alpha) del modo 'parasito' con J = k+1 = 31 "
          "frente a la prediccion de ritmo ---")
    print(f"{'alpha':>6} {'medido':>9} {'predicho':>9} {'raf':>5} {'cociente':>9}")
    for alpha in ALPHAS:
        v = detalle[alpha].get(("parasito", 31, 1, None))
        if v is None:
            continue
        p = prediccion(alpha, 31)
        print(f"{alpha:>6.2f} {v[0]:>9.4f} {p:>9.4f} {v[1]:>5} "
              f"{(v[0]/p if p > 0 else float('nan')):>9.3f}")

    print(f"\n[{time.time()-t_ini:.0f} s]")
