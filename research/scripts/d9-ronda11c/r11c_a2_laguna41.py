#!/usr/bin/env python3
"""
r11c_a2_laguna41.py — PUNTO A (segunda parte) · LAGUNA 41 del catalogo,
«`m` con retencion posiblemente inflada».

El catalogo dice: los simuladores de D8/D9-c..f permitian publicar un hijo de un bloque
retenido, imposible en la red real; 9c lo corrigio con la clausura de publicacion, y las
`m` con retencion (2,82-2,96) pueden estar infladas.

Aqui se aisla el efecto CAMBIANDO UNA SOLA COSA: el mundo.
  · `Mundo`     (r8c_sim.py, D9-c/D9-f): SIN clausura y SIN R-FIN-1a de validez.
  · `MundoR11`  (= MundoR9 de 9c + politica 'propio'): CON clausura y CON R-FIN-1a.
Misma familia, mismas semillas, mismos umbrales, misma lectura del ancla (R-FIN-1 literal:
menor blue_work entre los de slot >= T). Dos rejillas de retraso:
  · la LITERAL de D9-f/D8 (`r8f_lib.fam`, retencion=True): retrasos 0 / 4 / 12 s;
  · la de esta ronda: 0/4/12/30/60/100/149 s («retencion hasta S_max»), que es un
    SUPERCONJUNTO — la familia esta anidada, luego su `m` es >= por construccion.

Criterio alpha: fila alpha = 0 -> m = 1,000 en las cuatro columnas.
"""
import multiprocessing as mp
import sys
import time

sys.path.insert(0, "/home/katana/zeo/ZEROX/research/scripts/d9-ronda11c")
from r11c_lib import (MundoR11, perfil, anclas, fam_retencion,          # noqa: E402
                      slot_de, S_MAX, POLS_D9F)
sys.path.insert(0, "/home/katana/zeo/ZEROX/research/scripts/d9-ronda8c")
from r8c_sim import Mundo                                               # noqa: E402

P, BANDA, HOR, W = 30, 10, 260.0, 30.0
SEMS = list(range(1, 13))
ALPHAS = (0.0, 0.10, 0.25, 0.40)
NPROC = 12
REJILLAS = {"D9-f (0/4/12 s)": (0.0, 4.0, 12.0),
            "11c (hasta 149 s)": (0.0, 4.0, 12.0, 30.0, 60.0, 100.0, 149.0)}


def ancla_lit(d, tip, T):
    """R-FIN-1 literal sobre cualquier DAG: menor blue_work entre los de slot >= T."""
    mejor = None
    for b in d.selected_chain(tip):
        if slot_de(d.B[b].t) >= T:
            bw = d.gd[b].blue_work
            if mejor is None or bw < mejor[0]:
                mejor = (bw, d.B[b].seed)
    return None if mejor is None else mejor[1]


def una(args):
    alpha, semilla, copias, con_clausura, retenciones = args
    if con_clausura:
        mundo = MundoR11(alpha, HOR, semilla, s_max=S_MAX)
    else:
        mundo = Mundo(alpha, HOR, semilla, k=30, mp=15, u3_mode="dynamic")
    d0, tip0 = mundo.corre({}, copias=0)
    ch0 = d0.selected_chain(tip0)
    if P >= len(ch0):
        return None
    tP = d0.B[ch0[P]].t
    Ss = [slot_de(tP + u) for u in range(-BANDA, BANDA + 1)]
    # la familia se construye sobre el calendario, que es identico en los dos mundos
    ests, idx = fam_retencion(mundo, tP, W, POLS_D9F, retenciones)
    if not con_clausura:
        ests = [{k: (r, ("tips" if p == "tips_pub" else p)) for k, (r, p) in e.items()}
                for e in ests]           # `Mundo` no conoce 'tips_pub'
    ac = {S: set() for S in Ss}
    for e in ests:
        d, tip = mundo.corre(e, copias=copias)
        for S in Ss:
            s = ancla_lit(d, tip, S)
            if s is not None:
                ac[S].add(s)
    ms = [len(ac[S]) for S in Ss]
    return sum(ms) / len(ms), max(ms), len(ests)


if __name__ == "__main__":
    print("=== A.2 · LAGUNA 41 · ¿inflaba la `m` con retencion la falta de clausura? ===")
    print(f"k=30, mp=15, lambda=1, Delta=4, horizonte {HOR:.0f} s, P={P}, 21 umbrales,")
    print("tau = 1 s, semillas 1..12, ancla = R-FIN-1 literal (menor blue_work, slot>=T).")
    print("Unica diferencia entre columnas: el MUNDO (clausura + R-FIN-1a) y la rejilla.\n")
    t0 = time.time()
    cab = f"{'copias':>7} {'alpha':>6} |"
    for rej in REJILLAS:
        cab += f" {'sin claus. '+rej:>26} {'CON claus. '+rej:>26} |"
    print(cab)
    for cop in (0, 14):
        for alpha in ALPHAS:
            fila = f"{cop:>7} {alpha:>6.2f} |"
            for rej, rets in REJILLAS.items():
                for cc in (False, True):
                    tareas = [(alpha, s, cop, cc, rets) for s in SEMS]
                    with mp.Pool(NPROC) as pool:
                        rs = [r for r in pool.map(una, tareas) if r]
                    fila += f" {sum(r[0] for r in rs)/len(rs):>19.3f} (n={len(rs)})"
                fila += " |"
            print(fila)
        print()
    print(f"[{time.time()-t0:.0f} s]")
