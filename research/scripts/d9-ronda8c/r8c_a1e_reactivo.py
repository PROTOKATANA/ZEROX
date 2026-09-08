#!/usr/bin/env python3
"""
r8c_a1e_reactivo.py — autocritica dura de A1: ?es el menu REALIZABLE EN LINEA?

`r8c_a1_menu.py` cuenta el conjunto de resultados alcanzables EX POST: enumero estrategias y miro
que sale. Eso es una COTA SUPERIOR del menu que un atacante puede realizar de verdad, porque
algunas decisiones hay que tomarlas ANTES de saber que bloque va a caer en la posicion P.

Aqui restrinjo al atacante a ser REACTIVO: solo puede usar bloques suyos creados a partir del
instante en que el ocupante de referencia de la posicion P ya existe (tP). Es decir: ve el
candidato, y solo entonces decide si lo desplaza. Todo lo anterior lo juega honesto.

Si el menu reactivo sigue siendo > 1, el ataque es realizable en linea y no es un artefacto de
mirar hacia atras.
"""
import statistics
from r8c_sim import Mundo
from r8c_a1_menu import K, MP


def menu_reactivo(alpha, semilla, P, T=260.0, ventana=30.0):
    m = Mundo(alpha, T, semilla, k=K, mp=MP, u3_mode="dynamic")
    d0, tip0 = m.corre({})
    ch0 = d0.selected_chain(tip0)
    if P >= len(ch0):
        return None
    tP = d0.B[ch0[P]].t
    # SOLO bloques del atacante creados EN O DESPUES de tP: decision reactiva
    idx = [i for i, (t, q, *_) in enumerate(m.ev) if q == "a" and tP <= t <= tP + ventana]
    ests = [{}]
    for pol in ("sp", ("retro", 1), ("retro", 2), ("retro", 4)):
        ests.append({i: (0.0, pol) for i in idx})
    for i in idx:
        for pol in ("sp", ("retro", 1), ("retro", 3)):
            ests.append({i: (0.0, pol)})
    vis = set()
    for e in ests:
        d, tip = m.corre(e)
        s = Mundo.ancla(d, tip, P)
        if s is not None:
            vis.add(s)
    return len(vis), len(idx)


if __name__ == "__main__":
    print("=== A1e · menu REACTIVO (solo bloques creados >= tP, y publicados al instante) ===")
    print("Es el menu GRATIS y EN LINEA: el atacante ve el candidato y decide si lo desplaza.\n")
    print(f"{'alpha':>6} {'menu reactivo':>14} {'max':>5} {'>1':>7} {'bloques disponibles':>21}")
    for a in (0.0, 0.10, 0.25, 0.33, 0.40):
        rs = [menu_reactivo(a, s, 30) for s in range(1, 13)]
        rs = [r for r in rs if r]
        if not rs:
            continue
        ms = [r[0] for r in rs]
        nb = [r[1] for r in rs]
        print(f"{a:>6.2f} {statistics.mean(ms):>14.2f} {max(ms):>5} "
              f"{sum(1 for x in ms if x > 1):>3}/{len(ms):<3} {statistics.mean(nb):>21.1f}")
