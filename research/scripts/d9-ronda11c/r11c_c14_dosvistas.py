#!/usr/bin/env python3
"""
r11c_c14_dosvistas.py — PUNTOS C.1 y C.4 · ¿rompen las hipotesis el acuerdo honesto?

Instrumento: `d8-ronda8/d8_lib.MundoDosVistas` (D8 A2), LITERAL — dos honestos H_A y H_B
separados por `Delta`, el atacante del paper (sin retardo) que puede entregar a UNO solo,
y la correccion de D8 «entregar un bloque entrega todo su pasado» (`_entrega`). Lo unico
que cambia respecto de `d8_a2_dosvistas.py` es la LECTURA del ancla: las seis reglas.

C.1 · El ataque A1 de la ronda 7 (desplazamiento de inyector) se manifiesta como DOS
      HONESTOS QUE LEEN `I_j` DISTINTO en `t_j`. Si H1/H2/H3 subieran esa probabilidad
      respecto de BASE a la misma profundidad, la hipotesis reabriria A1.
C.4 · «el slot del primer referenciador es funcion de past(B)»: se comprueba leyendo H3
      en las dos vistas y comparando. Si H3 desacordase mas que BASE, la magnitud nueva
      no seria legible en local.

Criterio alpha: la fila alpha = 0 esta (el desacuerdo residual a alpha=0 es el suelo que
impone `Delta`, no el atacante).
Cobertura: `div_sp` = fraccion de instantes con padre seleccionado virtual distinto. Si
fuese 0 las dos vistas serian la misma y la medida no diria nada.
"""
import multiprocessing as mp
import sys
import time
from collections import defaultdict

sys.path.insert(0, "/home/katana/zeo/ZEROX/research/scripts/d9-ronda11c")
sys.path.insert(0, "/home/katana/zeo/ZEROX/research/scripts/d8-ronda8")
from d8_lib import MundoDosVistas, vista_en                      # noqa: E402
from r11c_lib import perfil, anclas, REGLAS                      # noqa: E402

K, HOR = 30, 900.0
SEMS = list(range(1, 13))
ALPHAS = [0.0, 0.10, 0.25, 0.33, 0.40]
SS = list(range(100, 301, 20))
DEVS = [4, 8, 16, 32, 64, 128, 256, 512]
POLS = ["tips", "sp", ("retro", 2), ("retro", 8)]
SESGOS = ["ambos", "A", "alterna"]
FRACS = [1.0, 0.5]
NPROC = 12


def una(args):
    alpha, sem, pol, sesgo, frac = args
    m = MundoDosVistas(alpha, HOR, sem, k=K, mp=15, u3_mode="dynamic")
    d, lA, lB = m.corre_2v(sesgo=sesgo, pol=pol, frac_sesgada=frac)
    des = {r: defaultdict(lambda: [0, 0]) for r in REGLAS}
    divsp = [0, 0]
    cache = {}
    for S in SS:
        for Dv in DEVS:
            t = S + Dv
            if t > HOR:
                continue
            if t not in cache:
                _, spA = vista_en(d, lA, t)
                _, spB = vista_en(d, lB, t)
                cache[t] = (spA, spB, perfil(d, spA), perfil(d, spB))
            spA, spB, pfA, pfB = cache[t]
            divsp[1] += 1
            if spA != spB:
                divsp[0] += 1
            AA = anclas(pfA, S, contar=False)
            AB = anclas(pfB, S, contar=False)
            for r in REGLAS:
                if AA[r][0] is None or AB[r][0] is None:
                    continue
                des[r][Dv][1] += 1
                if AA[r][0] != AB[r][0]:
                    des[r][Dv][0] += 1
    return {r: {k: list(v) for k, v in des[r].items()} for r in REGLAS}, divsp, m.n_sesgados


if __name__ == "__main__":
    print("=== C.1 / C.4 · P(dos honestos leen I_j distinto) con las seis reglas ===")
    print(f"k={K}, lambda=1, Delta=4, mp=15, u3=dynamic, horizonte {HOR:.0f} s, 12 semillas,")
    print(f"{len(SS)} umbrales de PoT, tau = 1 s. Familia del atacante: pol in "
          "{tips, sp, retro2, retro8}")
    print("x sesgo in {ambos, A, alterna} x frac in {1,0, 0,5}. Se reporta el MAXIMO sobre")
    print("la familia (la fila que cuenta). Referencia BASE = `d8-ronda8/salida_a2.txt`.\n")
    t0 = time.time()
    tareas = [(a, s, p, g, f) for a in ALPHAS for s in SEMS
              for p in POLS for g in SESGOS for f in FRACS]
    with mp.Pool(NPROC) as pool:
        res = pool.map(una, tareas)
    idx = {}
    for (a, s, p, g, f), r in zip(tareas, res):
        idx.setdefault((a, p, g, f), []).append(r)

    for r in REGLAS:
        print(f"--- regla {r} · MAXIMO sobre la familia ---")
        print(f"{'alpha':>6} | " + " ".join(f"{'D='+str(dv):>9}" for dv in DEVS) +
              f" | {'div_sp':>7} {'sesgados':>9}")
        for a in ALPHAS:
            mx = {dv: 0.0 for dv in DEVS}
            dsp = [0, 0]; nses = 0
            for (aa, p, g, f), lst in idx.items():
                if aa != a:
                    continue
                sub = {dv: [0, 0] for dv in DEVS}
                for des, divsp, ns in lst:
                    for dv, (x, y) in des[r].items():
                        sub[dv][0] += x; sub[dv][1] += y
                    dsp[0] += divsp[0]; dsp[1] += divsp[1]; nses += ns
                for dv in DEVS:
                    if sub[dv][1]:
                        mx[dv] = max(mx[dv], sub[dv][0] / sub[dv][1])
            print(f"{a:>6.2f} | " + " ".join(f"{mx[dv]:>9.5f}" for dv in DEVS) +
                  f" | {dsp[0]/max(dsp[1],1):>7.3f} {nses:>9}")
        print()
    print(f"[{time.time()-t0:.0f} s]")
