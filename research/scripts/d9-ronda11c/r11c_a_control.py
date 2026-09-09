#!/usr/bin/env python3
"""
r11c_a_control.py — PUNTO A · CONTROL POSITIVO y linea base.

Reproduce `m = 2,54` (D9-f B1, `d9-ronda8f/salida_b1_gran1.txt`, fila copias=14 /
alpha=0,25) con el MISMO instrumento y las MISMAS semillas (1..12) y la MISMA familia
(global y bloque a bloque, pols = sp / retro 1,2,4,8,16, ventana +-30 s), pero con:

  (i)  R-FIN-1a aplicada como regla de VALIDEZ (`MundoR9`, 9c), y
  (ii) la CLAUSURA DE PUBLICACION de 9c: publicar un bloque publica todos sus ancestros.

Esa es la linea base de la ronda, y de paso cierra la LAGUNA 41 del catalogo («`m` con
retencion posiblemente inflada»): la columna `+retencion` usa la familia con retencion
HASTA S_max = 150 s (retrasos 0/4/12/30/60/100/149 s), que sin la clausura era irreal.

Criterio alpha: la fila `alpha = 0` debe dar `m = 1,000` en las dos columnas.
Cobertura: se imprimen los contadores de `r11c_lib.COB11` y de `r9c_lib.COB`.
"""
import multiprocessing as mp
import sys
import time

sys.path.insert(0, "/home/katana/zeo/ZEROX/research/scripts/d9-ronda11c")
from r11c_lib import (MundoR11, perfil, anclas, fam_d9f, fam_retencion,   # noqa: E402
                      slot_de, COB11, COB, S_MAX)

P = 30
BANDA = 10
HOR = 260.0
W = 30.0
SEMS = list(range(1, 13))          # las 12 de D9-f B1, para que el control sea comparable
ALPHAS = (0.0, 0.10, 0.25, 0.40)
NPROC = 12


def una(args):
    alpha, semilla, copias, con_retencion = args
    mundo = MundoR11(alpha, HOR, semilla, s_max=S_MAX)
    d0, tip0 = mundo.corre({}, copias=0)
    ch0 = d0.selected_chain(tip0)
    if P >= len(ch0):
        return None
    tP = d0.B[ch0[P]].t
    Ss = [slot_de(tP + u) for u in range(-BANDA, BANDA + 1)]
    ests, idx = (fam_retencion(mundo, tP, W) if con_retencion else fam_d9f(mundo, tP, W))
    ac = {S: set() for S in Ss}
    for e in ests:
        d, tip = mundo.corre(e, copias=copias)
        pf = perfil(d, tip)
        for S in Ss:
            a = anclas(pf, S)["BASE"]
            if a[0] is not None:
                ac[S].add(a[0])
    ms = [len(ac[S]) for S in Ss]
    return (sum(ms) / len(ms), max(ms), len(ests), len(idx),
            dict(COB11["difiere"]), COB11["ventana_multi"], COB11["cand_multi"])


if __name__ == "__main__":
    print("=== A · CONTROL · `m` del ancla vigente (R-FIN-1, por slot) con la clausura de 9c ===")
    print(f"k=30, mp=15, lambda=1, Delta=4, horizonte {HOR:.0f} s, u3=dynamic, P={P},")
    print(f"21 umbrales S0+-{BANDA} slots, tau = 1 s, S_max = {S_MAX} s, semillas 1..12.")
    print("Familia D9-f: {} + global(pols) + bloque a bloque(pols), pols = sp, retro 1/2/4/8/16.")
    print("Familia +retencion: la anterior + retener TODO menos uno, liberado con")
    print("   retraso in {0,4,12,30,60,100,149} s y politica in {tips_pub, pols}.")
    print("REFERENCIA D9-f (salida_b1_gran1.txt, SIN clausura ni R-FIN-1a de validez):")
    print("   m_SLOT = 1,000 / 2,079 / 2,452 / 2,917 (copias 0) y 1,000 / 2,238 / 2,540 /")
    print("   3,024 (copias 14) para alpha = 0 / 0,10 / 0,25 / 0,40.\n")
    t0 = time.time()
    print(f"{'copias':>7} {'alpha':>6} | {'m sin retencion':>16} {'max':>4} "
          f"{'estrat':>7} | {'m +retencion':>13} {'max':>4} {'estrat':>7} | {'|idx|':>6}")
    filas = {}
    for cop in (0, 14):
        for alpha in ALPHAS:
            out = {}
            for cr in (False, True):
                tareas = [(alpha, s, cop, cr) for s in SEMS]
                with mp.Pool(NPROC) as pool:
                    rs = [r for r in pool.map(una, tareas) if r]
                n = len(rs)
                out[cr] = (sum(r[0] for r in rs) / n, max(r[1] for r in rs),
                           sum(r[2] for r in rs) / n, sum(r[3] for r in rs) / n, n)
            filas[(cop, alpha)] = out
            print(f"{cop:>7} {alpha:>6.2f} | {out[False][0]:>16.3f} {out[False][1]:>4} "
                  f"{out[False][2]:>7.1f} | {out[True][0]:>13.3f} {out[True][1]:>4} "
                  f"{out[True][2]:>7.1f} | {out[True][3]:>6.1f}")
        print()
    print(f"[{time.time()-t0:.0f} s]  (semillas efectivas por fila: "
          f"{filas[(14, 0.25)][True][4]}/12)")
    print("\nNOTA de comparabilidad: los contadores COB/COB11 de este proceso principal solo")
    print("cubren la corrida final; el trabajo va en subprocesos. La cobertura de rama se")
    print("reporta en r11c_b_hipotesis.py, que la acumula dentro de cada worker.")
