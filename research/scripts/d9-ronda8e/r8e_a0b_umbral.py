#!/usr/bin/env python3
"""
r8e_a0b_umbral.py — ¿A PARTIR DE QUE `epsilon` el peso real DECIDE algo distinto del conteo?

A0 encontro que con `(W, gamma)` razonables la rama del peso se ejecuta (miles de bloques
con `w != 1`, cientos de decisiones de padre seleccionado con candidatos de PESOS DISTINTOS)
y aun asi `argmax(blue_work) == argmax(blue_score)` SIEMPRE. Eso no es un resultado hasta
que se sepa donde esta la frontera: si esta a `epsilon = 10 %` el margen es enorme, si esta
a `epsilon = 12 %` es estrecho.

Aqui se barre `(W, gamma)` hasta ROMPERLO: se busca el primer punto en que
`sp_discrepa > 0` y/o la cadena seleccionada cambia respecto a la de peso 1 en el MISMO
mundo. `sd(ln w)` medido es el `epsilon` del empalme.

Criterio alpha: se corre a alpha = 0 y alpha = 0,25; el DAG y las cuentas cambian con alpha
(columnas `sp llam` y `sort llam` distintas por fila).
"""
import sys
from r8e_lib import MundoW, PesoCfg

K, MP = 30, 15
HOR = 260.0
SEMS = list(range(1, 9))


def punto(alpha, W, gamma, lam_obj=0.97, modo="desliz"):
    """Mismo mundo, peso 1 vs peso (W, gamma). Devuelve cobertura agregada."""
    tot = dict(sp_llam=0, w_dist=0, sp_dis=0, sort_llam=0, sort_dis=0,
               cad_dif=0, sd=0.0, lo=0.0, hi=0.0, clamps=0, nsem=0, prim=[])
    for s in SEMS:
        m1 = MundoW(alpha, HOR, s, k=K, mp=MP, u3_mode="dynamic", wcfg=PesoCfg(W=None))
        d1, t1 = m1.corre({})
        m2 = MundoW(alpha, HOR, s, k=K, mp=MP, u3_mode="dynamic",
                    wcfg=PesoCfg(W=W, gamma=gamma, lam_obj=lam_obj, modo=modo))
        d2, t2 = m2.corre({})
        c1, c2 = d1.selected_chain(t1), d2.selected_chain(t2)
        n = min(len(c1), len(c2))
        difs = sum(1 for i in range(n) if c1[i] != c2[i]) + abs(len(c1) - len(c2))
        pr = next((i for i in range(n) if c1[i] != c2[i]), None)
        if pr is not None:
            tot["prim"].append(pr)
        c = d2.cobertura()
        tot["sp_llam"] += c["sp_llamadas"]; tot["w_dist"] += c["sp_pesos_dist"]
        tot["sp_dis"] += c["sp_discrepa"]
        tot["sort_llam"] += c["sort_llamadas"]; tot["sort_dis"] += c["sort_discrepa"]
        tot["cad_dif"] += difs
        tot["sd"] += c["spread_lnw"]; tot["clamps"] += c["clamps"]
        tot["lo"] = min(tot["lo"], c["rango_lnw"][0]); tot["hi"] = max(tot["hi"], c["rango_lnw"][1])
        tot["nsem"] += 1
    tot["sd"] /= tot["nsem"]
    return tot


if __name__ == "__main__":
    print("=== A0b · frontera: ¿cuanto `epsilon` hace falta para que el peso decida? ===")
    print(f"k={K}, mp={MP}, horizonte {HOR:.0f} s, {len(SEMS)} semillas, u3_mode=dynamic.")
    print("`sd(ln w)` = epsilon MEDIDO. `sp!=` = veces que el padre seleccionado por PESO")
    print("no es el que elegiria el CONTEO. `cad dif` = bloques de cadena que cambian.\n")
    print(f"{'modo':>7} {'alpha':>6} {'W (s)':>7} {'gam':>5} | {'sd(ln w)':>9} {'rango ln w':>17} "
          f"{'clamps':>7} | {'sp llam':>8} {'w!=':>7} {'sp!=':>6} "
          f"| {'sort llam':>10} {'sort!=':>7} | {'cad dif':>8} {'1er':>5}")
    combos = ((3083.0, 0.25), (80.0, 0.25), (40.0, 0.25), (20.0, 0.25), (20.0, 1.0),
              (10.0, 1.0), (10.0, 1.9), (5.0, 1.9), (5.0, 6.0), (5.0, 20.0), (3.0, 20.0))
    for modo in ("desliz", "epoca"):
      for alpha in (0.0, 0.25):
        for W, gamma in combos:
            t = punto(alpha, W, gamma, modo=modo)
            pr = (sum(t["prim"]) / len(t["prim"])) if t["prim"] else float("nan")
            print(f"{modo:>7} {alpha:>6.2f} {W:>7.1f} {gamma:>5.2f} | {t['sd']:>9.4f} "
                  f"{f'[{t['lo']:+.2f}, {t['hi']:+.2f}]':>17} {t['clamps']:>7} "
                  f"| {t['sp_llam']:>8} {t['w_dist']:>7} {t['sp_dis']:>6} "
                  f"| {t['sort_llam']:>10} {t['sort_dis']:>7} | {t['cad_dif']:>8} {pr:>5.1f}")
        print()
