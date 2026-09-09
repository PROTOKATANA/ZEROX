#!/usr/bin/env python3
"""
r11b_a2_fv.py — PUNTO A (segunda parte) · barrido en `f_v` de la variante (ii) 'filtro' con
`paso = 0` (aislamiento total de bloques, el PoT pasa), horizonte largo.

Lo que verifica: la forma cerrada `P(invalido) = exp(-(f_v + paso*(1-f_v))*lambda*S_max)`
—que es la de D8 A3b (M3) generalizada al filtro parcial— contra la medida del DAG completo.
La forma cerrada solo depende del PRODUCTO `tasa*S_max`, asi que barrer `f_v` x `S_max`
cubre el rango entero de ese producto sin necesitar horizontes de 10^6 s.

Ademas mide `rojo_V`: la fraccion de bloques de `V` que quedan FUERA del blueset de la vista
publica final. Es el dano real, y es independiente de `S_max`.

Criterio alpha: `alpha in {0; 0,10; 0,33}`. Control negativo: `paso = 1` (sin eclipse).
"""
import math
import sys
import time
from multiprocessing import Pool

sys.path.insert(0, "/home/katana/zeo/ZEROX/research/scripts/d8-ronda11b")
from r11b_lib import MundoVictima, LAMBDA, K, MP                      # noqa: E402

SEMS = list(range(1, 13))
HOR = 2400.0
T_ECL = 300.0
T_REG = 600.0
SMAXES = [4, 20, 30, 150]
ALPHAS = [0.0, 0.10, 0.33]
FVS = [0.01, 0.05, 0.09, 0.20]
PASOS = [1.0, 0.0]


def una(args):
    alpha, f_v, paso, sem = args
    m = MundoVictima(alpha, HOR, sem, k=K, mp=MP, u3_mode="dynamic")
    d, tip, _ = m.corre_victima("filtro", f_v=f_v, paso=paso, t_ecl=T_ECL, sem=sem)
    az = d.blueset(tip)
    mal = {S: 0 for S in SMAXES}
    n = rojo = 0
    for t, gp, bid in zip(m.t_V, m.gaps_V, m.ids_V):
        if t < T_REG:
            continue
        n += 1
        if bid not in az:
            rojo += 1
        for S in SMAXES:
            if gp > S:
                mal[S] += 1
    lleg = sum(1 for x in m.llegadas_V if T_REG <= x <= HOR)
    return (alpha, f_v, paso), (n, rojo, mal, lleg)


if __name__ == "__main__":
    t0 = time.time()
    print("=== A2 · barrido en f_v de la variante (ii) 'filtro', horizonte largo ===")
    print(f"k={K}, mp={MP}, lambda={LAMBDA}, horizonte {HOR:.0f} s, eclipse en t={T_ECL:.0f} s, "
          f"regimen desde t={T_REG:.0f} s, {len(SEMS)} semillas.\n")
    tareas = [(a, f, p, s) for p in PASOS for f in FVS for a in ALPHAS for s in SEMS]
    with Pool() as pool:
        res = pool.map(una, tareas)
    acc = {}
    for clave, (n, rojo, mal, lleg) in res:
        if clave not in acc:
            acc[clave] = [0, 0, {S: 0 for S in SMAXES}, 0]
        acc[clave][0] += n
        acc[clave][1] += rojo
        acc[clave][3] += lleg
        for S in SMAXES:
            acc[clave][2][S] += mal[S]

    print(f"{'paso':>5} {'f_v':>5} {'alpha':>6} | {'n_V':>5} " +
          " ".join(f"{'med S='+str(S):>10}" for S in SMAXES) + " | " +
          " ".join(f"{'cer S='+str(S):>10}" for S in SMAXES) +
          f" | {'tasa_obs':>9} {'rojo_V':>7}")
    for paso in PASOS:
        for f_v in FVS:
            for alpha in ALPHAS:
                n, rojo, mal, lleg = acc[(alpha, f_v, paso)]
                dur = (HOR - T_REG) * len(SEMS)
                tasa = lleg / dur
                tasa_enc = f_v * LAMBDA + tasa
                if n == 0:
                    print(f"{paso:>5.2f} {f_v:>5.2f} {alpha:>6.2f} | n_V = 0: la fila no dice nada")
                    continue
                print(f"{paso:>5.2f} {f_v:>5.2f} {alpha:>6.2f} | {n:>5} " +
                      " ".join(f"{mal[S]/n:>10.4f}" for S in SMAXES) + " | " +
                      " ".join(f"{math.exp(-tasa_enc*S):>10.4f}" for S in SMAXES) +
                      f" | {tasa:>9.4f} {rojo/n:>7.4f}")
    print(f"\n[{time.time()-t0:.0f} s]")
