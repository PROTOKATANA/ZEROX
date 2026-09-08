#!/usr/bin/env python3
"""
B.2 (tercera parte) · CIERRE DE LA LAGUNA de B.2(iii): re-medir el `delta` de D8 con k != 30.

La tabla (iii) de `r10b_b2_k.py` usaba el `delta` de D8 (`r9a_a3_frontera.MED`) para k in
{20,25,40}, pero ese `delta` esta MEDIDO SOLO A k = 30 (`d8-ronda8/salida_a1b.txt`). El intento
anterior de esta ronda lo declaro LAGUNA «por presupuesto»; el metodo (regla 3, 2026-09-08) lo
prohibe. Aqui se mide de verdad.

QUE SE REUTILIZA SIN REESCRIBIR:
  * `d8_lib.MundoL9`  (la maniobra parasita del Lema 9, D8) y `d8_lib.delta_hon`
  * el protocolo exacto de `d8-ronda8/d8_a1b_umbral.py:60-95`: 12 semillas, J in {16,31,48,64,96},
    horizonte 1800 s, ventana [60, HOR-60], modo='parasito', d_fork=1, y para cada alpha se toma
    el J que MAXIMIZA el delta medio (el peor caso para el honesto).
Unico cambio: `k` es parametro, y con el viajan las constantes que R-FIN-12 ata a `k`
(`max_block_parents = max(10, k//2)`, `mergeset_size_limit = max(180, 2k)`,
`dag-poas-delta-real.md` §4 L88-90). A k = 30 eso da mp=15, msl=180: EXACTAMENTE los de D8, asi
que la fila k=30 es un CONTROL POSITIVO — debe reproducir `salida_a1b.txt` columna a columna.

CRITERIO ALPHA (regla 4): fila alpha = 0 (delta debe salir 0,0000) y barrido completo.
COBERTURA DE RAMA (regla 5): se imprimen `raf` (rafagas publicadas) y `sok`; si raf = 0 la
maniobra no se ejecuto y la fila no dice nada.
12 SEMILLAS (regla 5): SEMS = 1..12, y se reporta media y max sobre ellas.
"""
import os
import sys
import time
from multiprocessing import Pool

sys.path.insert(0, "/home/katana/zeo/ZEROX/research/scripts/d8-ronda8")
from d8_lib import MundoL9, delta_hon, DELTA                          # noqa: E402

SEMS = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
ALPHAS = [0.0, 0.25, 0.30, 0.33, 0.35, 0.37, 0.40, 0.45]
JS = [16, 31, 48, 64, 96]
KS = [20, 25, 30, 40]
HOR = 1800.0
# control: la fila k=30 debe dar esto (d8-ronda8/salida_a1b.txt L6-13)
CTRL30 = {0.00: 0.0000, 0.25: 0.1544, 0.30: 0.2079, 0.33: 0.2867,
          0.35: 0.3065, 0.37: 0.3448, 0.40: 0.4366, 0.45: 0.5834}


def mp_de_k(k):
    return max(10, k // 2)


def msl_de_k(k):
    return max(180, 2 * k)


def una(args):
    """Una corrida. `alpha` se usa para construir el mundo: si no lo usara, todas las filas
    saldrian iguales (criterio alpha)."""
    k, alpha, sem, J = args
    m = MundoL9(alpha, HOR, sem, k=k, mp=mp_de_k(k), msl=msl_de_k(k))
    d, tip, llega = m.corre_l9(J=J, d_fork=1, giveup=None, modo="parasito")
    dl, n = delta_hon(d, tip, 60.0, HOR - 60.0)
    return (k, alpha, J, sem, (dl or 0.0), m.n_rafagas, m.n_score_ok, m.n_rechazados)


if __name__ == "__main__":
    t0 = time.time()
    tareas = [(k, a, s, J) for k in KS for a in ALPHAS for J in JS for s in SEMS]
    print("=== B.2b · el `delta` de D8 RE-MEDIDO con k in {20,25,30,40} (cierra la LAGUNA) ===")
    print(f"MundoL9 de d8_lib (maniobra parasita), Delta={DELTA}, lambda=1, horizonte {HOR:.0f} s, "
          f"ventana [60,{HOR-60:.0f}], {len(SEMS)} semillas, J in {JS}, d_fork=1, u3=dynamic.")
    print("mp = max(10, k//2), msl = max(180, 2k)  (R-FIN-12, delta-real.md §4 L88-90).")
    print(f"{len(tareas)} corridas.\n", flush=True)

    with Pool(min(32, os.cpu_count())) as p:
        res = p.map(una, tareas, chunksize=1)

    por = {}
    for k, a, J, s, dl, raf, sok, rech in res:
        por.setdefault((k, a, J), []).append((dl, raf, sok, rech))

    tabla = {}
    for k in KS:
        print(f"--- k = {k}  (mp={mp_de_k(k)}, msl={msl_de_k(k)}, 3k={3*k}) ---")
        print(f"{'alpha':>6} {'J*':>4} | {'delta medio':>11} {'IC95 (12 sem)':>20} {'max':>7} "
              f"{'min':>7} | {'(1-a)(1-d)':>10} {'r':>7} | {'raf':>5} {'sok':>6} {'rech':>5}")
        for a in ALPHAS:
            mejor = (-1.0, None, None)
            for J in JS:
                vs = por[(k, a, J)]
                med = sum(v[0] for v in vs) / len(vs)
                if med > mejor[0]:
                    mejor = (med, J, vs)
            dlt, J, vs = mejor
            raf = sum(v[1] for v in vs); sok = sum(v[2] for v in vs); rech = sum(v[3] for v in vs)
            crec = (1 - a) * (1 - dlt)
            r = a / crec if crec > 0 else float("inf")
            tabla[(k, a)] = dlt
            marca = ""
            if k == 30:
                ok = abs(dlt - CTRL30[a]) < 5e-4
                marca = f"   CONTROL a1b {CTRL30[a]:.4f} {'OK' if ok else 'DIFIERE'}"
            xs = [v[0] for v in vs]
            n = len(xs)
            sd = (sum((x - dlt) ** 2 for x in xs) / (n - 1)) ** 0.5 if n > 1 else 0.0
            ic = 2.201 * sd / n ** 0.5            # t_{0,975; 11} = 2,201
            print(f"{a:>6.2f} {J:>4} | {dlt:>11.4f} [{dlt-ic:>7.4f},{dlt+ic:>7.4f}] "
                  f"{max(xs):>7.4f} {min(xs):>7.4f} | {crec:>10.4f} {r:>7.3f} | "
                  f"{raf:>5} {sok:>6} {rech:>5}{marca}")
        print(flush=True)

    print("--- resumen: delta(alpha) por k, para alimentar F_carrera ---")
    print("DELTA_K = {")
    for k in KS:
        print(f"    {k}: {{" + ", ".join(f"{a:.2f}: {tabla[(k,a)]:.4f}" for a in ALPHAS) + "},")
    print("}")
    print(f"\n[{time.time()-t0:.0f} s]")
