#!/usr/bin/env python3
"""
r11c_d_censura.py — PUNTO D · ¿censura H3 al granjero honesto lento?

Modelo: una fraccion `FRAC` de los granjeros honestos publica con `E` segundos de retraso
EXTRA sobre `Delta` (vista retrasada, enlace lento, nodo cargado). Su bloque sigue siendo
valido mientras cumpla R-FIN-1a (`S_max = 150 s`) y COBRA igual: R-FIN-8′ paga a azules y
`rojo_k` su propia coinbase y **no menciona el ancla en ningun sitio**
(`research/dag-poas-ancla-de-orden.md:314-325`), y R-FIN-13′ cuenta para el retarget
«exactamente los bloques que cobran» (`:229-231`). Ser ancla no paga.

Se miden, para E in {0, 20, 45, 60, 150} s:
  · `perdidos`   bloques honestos que NO se crean por no tener ningun `sp` valido bajo
                 R-FIN-1a (COB['sin_sp_h']) — esta es la censura REAL, la de la validez,
                 y no depende de H3.
  · `sp_filtr.`  veces que el honesto tuvo que elegir un `sp` peor por R-FIN-1a.
  · `azules`     fraccion de bloques de granjeros lentos que acaban AZULES (cobran).
  · `ancla BASE` veces que un bloque de granjero lento es el ancla bajo la regla vigente.
  · `ancla H3`   ... y bajo H3. La diferencia es lo que H3 le quita: candidatura, no dinero.

Criterio alpha: fila alpha = 0; y toda columna cambia con E (el parametro estudiado).
"""
import multiprocessing as mp
import sys
import time

sys.path.insert(0, "/home/katana/zeo/ZEROX/research/scripts/d9-ronda11c")
import r11c_lib as L                                                    # noqa: E402
from r11c_lib import MundoR11, perfil, anclas, fam_retencion, slot_de, S_MAX, S_ANCLA  # noqa: E402

P, BANDA, HOR, W = 30, 10, 260.0, 30.0
SEMS = list(range(1, 13))
ALPHAS = (0.0, 0.10, 0.25, 0.40)
ES = (0.0, 20.0, 45.0, 60.0, 150.0)
FRAC = 0.25
NPROC = 12


def una(args):
    alpha, semilla, E = args
    for k in list(L.COB):
        L.COB[k] = 0
    mundo = MundoR11(alpha, HOR, semilla, s_max=S_MAX,
                     retraso_honesto=E, frac_lenta=FRAC)
    d0, tip0 = mundo.corre({}, copias=0)
    ch0 = d0.selected_chain(tip0)
    if P >= len(ch0):
        return None
    tP = d0.B[ch0[P]].t
    Ss = [slot_de(tP + u) for u in range(-BANDA, BANDA + 1)]
    ests, idx = fam_retencion(mundo, tP, W)
    nB = nH3 = nB_lento = nH3_lento = 0
    az_lentos = [0, 0]
    for e in ests:
        d, tip = mundo.corre(e, copias=0)
        pf = perfil(d, tip)
        blue = d.blueset(tip)
        for b in mundo.lentos:
            if b in d.B:
                az_lentos[1] += 1
                if b in blue:
                    az_lentos[0] += 1
        for S in Ss:
            a = anclas(pf, S, contar=False)
            if a["BASE"][0] is not None:
                nB += 1
                if pf[a["BASE"][1]][1] in mundo.lentos:
                    nB_lento += 1
            if a["H3"][0] is not None:
                nH3 += 1
                if pf[a["H3"][1]][1] in mundo.lentos:
                    nH3_lento += 1
    return (nB, nB_lento, nH3, nH3_lento, az_lentos,
            L.COB["sin_sp_h"], L.COB["sp_filtrado_h"], L.COB["bloques_h"], len(ests))


if __name__ == "__main__":
    print("=== D · censura del granjero honesto lento bajo H3 ===")
    print(f"k=30, mp=15, lambda=1, Delta=4, horizonte {HOR:.0f} s, P={P}, 21 umbrales,")
    print(f"tau = 1 s, S_max(validez) = {S_MAX} s, S_ancla = {S_ANCLA} s, semillas 1..12,")
    print(f"fraccion de granjeros lentos = {FRAC:.0%}, retraso extra E sobre Delta.\n")
    t0 = time.time()
    print(f"{'alpha':>6} {'E (s)':>6} | {'h. perdidos':>12} {'sp filtrado':>12} "
          f"{'bloques h':>10} | {'lentos azules':>14} | {'ancla BASE lenta':>17} "
          f"{'ancla H3 lenta':>15} | {'ancla lenta perdida':>20}")
    for alpha in ALPHAS:
        for E in ES:
            with mp.Pool(NPROC) as pool:
                rs = [r for r in pool.map(una, [(alpha, s, E) for s in SEMS]) if r]
            nB = sum(r[0] for r in rs); nBl = sum(r[1] for r in rs)
            nH = sum(r[2] for r in rs); nHl = sum(r[3] for r in rs)
            az = [sum(r[4][0] for r in rs), sum(r[4][1] for r in rs)]
            perd = sum(r[5] for r in rs); spf = sum(r[6] for r in rs)
            bh = sum(r[7] for r in rs)
            print(f"{alpha:>6.2f} {E:>6.0f} | {perd:>12,} {spf:>12,} {bh:>10,} | "
                  f"{az[0]/max(az[1],1):>13.1%} | {nBl:>7,}/{nB:<9,} "
                  f"{nHl:>6,}/{nH:<8,} | {nBl-nHl:>20,}")
        print()
    print(f"[{time.time()-t0:.0f} s]")
