#!/usr/bin/env python3
"""
r9a_a4_parcial.py — LINEA 4. Sub-pregunta (ii)-b: publicar PARTE de la cadena privada para
enrojecer y seguir con el resto en privado.

Si esta maniobra funcionase, el atacante compraria `delta` con bloques publicados y
CONSERVARIA la ventaja privada: los presupuestos dejarian de ser disjuntos y la tesis del
agente principal caeria. Se mide `frac_pub` de 1,0 (parasita de D8, control) a 0,25.

Magnitudes: la contabilidad de A1 (R, Ablue, Wpub/H) + la ventaja RETENIDA de la parte
privada (`adv_max`, `adv_fin`) y `n_cambios` (cuantas publicaciones parciales SI hicieron
cambiar de cadena a la red honesta; si es 0, la maniobra no existe y la fila no dice nada).

REGLA 1: fila alpha = 0.  REGLA 2: n_raf y n_cambios.  REGLA 3: 12 semillas.
"""
import sys
import time
from multiprocessing import Pool

sys.path.insert(0, "/home/katana/zeo/ZEROX/research/scripts/d9-ronda9a")
from r9a_lib import MundoParcial, contabilidad, K, DELTA        # noqa: E402

SEMS = list(range(1, 13))
ALPHAS = [0.00, 0.25, 0.33, 0.35, 0.40, 0.45]
FRACS = [1.0, 0.75, 0.5, 0.25]
JS = [16, 31, 48, 64]
HOR = 1800.0


def una(args):
    alpha, sem, J, fp = args
    m = MundoParcial(alpha, HOR, sem, k=K, mp=15)
    d, tip, llega = m.corre_parcial(J=J, frac_pub=fp)
    c = contabilidad(d, tip, llega, 60.0, HOR - 60.0)
    c.update(raf=m.n_rafagas, cambios=m.n_cambios, npub=m.n_publicados,
             npriv=m.n_bloques_priv, adv_max=m.adv_max, adv_fin=m.adv_fin)
    return (alpha, J, fp, c)


if __name__ == "__main__":
    tareas = [(a, s, J, fp) for a in ALPHAS for J in JS for fp in FRACS for s in SEMS]
    print("=== A4 · publicar solo parte de la cadena privada ===")
    print(f"k={K}, lambda=1, Delta={DELTA}, horizonte {HOR:.0f} s, {len(SEMS)} semillas, "
          f"{len(tareas)} corridas.\n")
    t0 = time.time()
    with Pool(24) as p:
        res = p.map(una, tareas, chunksize=4)
    print(f"[{time.time()-t0:.0f} s]\n")
    por = {}
    for a, J, fp, c in res:
        por.setdefault((a, J, fp), []).append(c)
    ag = {kk: {x: sum(r[x] for r in v)/len(v) for x in v[0]} for kk, v in por.items()}

    print(f"{'alpha':>6} {'frac_pub':>9} {'J':>4} | {'delta':>7} {'R/Ablue':>8} {'Wpub/H':>7} "
          f"| {'adv_max':>8} {'adv_fin':>8} | {'raf':>5} {'cambios':>8} {'npub':>6} {'npriv':>6}")
    for a in ALPHAS:
        for fp in FRACS:
            cands = [(J, ag[(a, J, fp)]) for J in JS]
            conraf = [(J, c) for J, c in cands if c["raf"] > 0] or cands
            J, c = max(conraf, key=lambda x: x[1]["delta"])
            print(f"{a:>6.2f} {fp:>9.2f} {J:>4} | {c['delta']:>7.4f} "
                  f"{(c['R']/c['Ablue'] if c['Ablue'] else float('nan')):>8.3f} "
                  f"{c['Wpub_sobre_H'] if 'Wpub_sobre_H' in c else c['Wpub']/c['H']:>7.4f} | "
                  f"{c['adv_max']:>8.1f} {c['adv_fin']:>8.1f} | {c['raf']:>5.1f} "
                  f"{c['cambios']:>8.1f} {c['npub']:>6.0f} {c['npriv']:>6.0f}")
        print()
    print("LECTURA: si al bajar `frac_pub` el `delta` cae y `adv_max` NO sube por encima de "
          "3k = 90,\npublicar parte de la cadena no compra `delta` gratis: la ventaja "
          "retenida no se conserva.")
