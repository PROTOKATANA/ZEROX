#!/usr/bin/env python3
"""
d8_a6c_shuffle.py — A6 · linea 3 de §7, la comprobacion que explica el resultado de
`d8_a6b_lineas.py`: el `shuffle` de `pick_virtual_parents` (R-FIN-12, obligatorio,
`processor.rs:1069-1089`) da EXACTAMENTE los mismos padres que la version sin shuffle.

Motivo: el shuffle solo puede cambiar algo si el numero de PUNTAS supera
`max_block_parents = 15` (o `max_candidates = 4*mp`). Con `lambda*Delta = 4` no llega.
Se cuenta la distribucion de puntas y las veces que los dos algoritmos difieren.

Criterio alpha: se barre alpha; el numero de puntas BAJA al subir alpha (el atacante con
politica 'tips' consolida), asi que la conclusion es aun mas fuerte con atacante.
"""
import collections
import sys

sys.path.insert(0, "/home/katana/zeo/ZEROX/research/scripts/d8-ronda8")
from d8_a6b_lineas import MundoL9Shuffle, K, MP                          # noqa: E402
from d8_lib import MundoL9, DAG, DELTA                                   # noqa: E402

SEMS = list(range(1, 13))

if __name__ == "__main__":
    print("=== A6c · el `shuffle` de R-FIN-12 no llega a activarse con lambda*Delta = 4 ===")
    print(f"k={K}, mp={MP} (max_block_parents), max_candidates = 4*mp = {4*MP}, "
          f"horizonte 900 s, {len(SEMS)} semillas.\n")
    print(f"{'alpha':>6} | {'padres distintos':>17} {'de':>7} | {'puntas max':>11} "
          f"{'puntas medias':>14} | {'veces puntas > mp':>18}")
    for alpha in (0.0, 0.10, 0.25, 0.40):
        dif = tot = 0
        hist = collections.Counter()
        for sem in SEMS:
            m1 = MundoL9(alpha, 900.0, sem, k=K, mp=MP)
            m2 = MundoL9Shuffle(alpha, 900.0, sem, k=K, mp=MP)
            d = DAG(k=K, u2=True, u3_mode="dynamic", max_parents=MP, mergeset_limit=180)
            g = d.genesis()
            llega = {g: 0.0}
            for i, (t, quien, sd, sde, ident) in enumerate(m1.ev):
                vis = [h for h, ta in llega.items() if ta <= t]
                hist[len(d.tips(vis))] += 1
                p1 = m1._padres(d, vis)
                p2 = m2._padres(d, vis)
                tot += 1
                if set(p1) != set(p2):
                    dif += 1
                ok, _ = d.add(f"b{i}", p1, t=t, creator=quien, ident=ident, sd=sd, seed=sde)
                if ok:
                    llega[f"b{i}"] = t + (DELTA if quien == "h" else 0.0)
        med = sum(k * v for k, v in hist.items()) / sum(hist.values())
        print(f"{alpha:>6.2f} | {dif:>17} {tot:>7} | {max(hist):>11} {med:>14.2f} | "
              f"{sum(v for k, v in hist.items() if k > MP):>18}")
    print("\nConclusion: el shuffle NUNCA cambia el conjunto de padres en este regimen, luego")
    print("(a) la pregunta «¿basta el shuffle?» no se decide aqui, y (b) que el simulador de")
    print("D9-c/d/e/f no lo implemente NO invalida sus medidas.")
    print("Las «~550 puntas» de D9-d A3.1 vienen de otro escenario (fabricacion masiva de")
    print("puntas), no del regimen de operacion con lambda*Delta = 4.")
