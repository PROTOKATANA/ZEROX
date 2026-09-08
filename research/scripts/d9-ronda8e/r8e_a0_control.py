#!/usr/bin/env python3
"""
r8e_a0_control.py — CONTROL OBLIGATORIO antes de medir nada (regla 11 + criterio de
cobertura de rama).

(1) IDENTIDAD: con `W = None` (peso constante) `DAGW` debe dar EXACTAMENTE el mismo DAG,
    la misma cadena seleccionada y los mismos `blue_score` que el `DAG` de D9-c, en las
    mismas semillas. Si no, cualquier diferencia posterior seria mia, no del peso.

(2) COBERTURA DE RAMA: con `W` finita hay que DEMOSTRAR que la rama del peso real se
    ejecuta — `retargets > 0`, `peso_distinto > 0`, `inc_distinto > 0`, `spread_lnw > 0` —
    y ademas que el peso CAMBIA LA CADENA (numero de bloques de cadena que difieren de la
    corrida con peso 1 en el mismo mundo).

Criterio alpha: (1) y (2) se ejecutan a varios alpha; el DAG cambia con alpha (lo prueba
la columna `n` = numero de bloques del DAG, que crece con las colisiones del atacante).
"""
import sys
from r8e_lib import MundoW, PesoCfg   # inserta las rutas de d9-ronda8c/8d en sys.path
from r8c_sim import Mundo                # noqa: E402

K, MP = 30, 15
HOR = 260.0
SEMS = list(range(1, 13))


def identidad(alpha, semilla):
    m0 = Mundo(alpha, HOR, semilla, k=K, mp=MP, u3_mode="dynamic")
    d0, tip0 = m0.corre({})
    m1 = MundoW(alpha, HOR, semilla, k=K, mp=MP, u3_mode="dynamic", wcfg=PesoCfg(W=None))
    d1, tip1 = m1.corre({})
    ch0 = d0.selected_chain(tip0)
    ch1 = d1.selected_chain(tip1)
    bs0 = [d0.gd[b].blue_score for b in ch0]
    bs1 = [d1.gd[b].blue_score for b in ch1]
    igual = (sorted(d0.B) == sorted(d1.B)) and (ch0 == ch1) and (bs0 == bs1)
    return igual, len(d0.B), len(ch0), d1.cobertura()


def divergencia(alpha, semilla, W, gamma=0.25):
    """Mismo mundo, peso 1 vs peso real: ¿cuanto difiere la cadena seleccionada?"""
    m1 = MundoW(alpha, HOR, semilla, k=K, mp=MP, u3_mode="dynamic", wcfg=PesoCfg(W=None))
    d1, t1 = m1.corre({})
    m2 = MundoW(alpha, HOR, semilla, k=K, mp=MP, u3_mode="dynamic",
                wcfg=PesoCfg(W=W, gamma=gamma))
    d2, t2 = m2.corre({})
    c1, c2 = d1.selected_chain(t1), d2.selected_chain(t2)
    n = min(len(c1), len(c2))
    difs = sum(1 for i in range(n) if c1[i] != c2[i]) + abs(len(c1) - len(c2))
    prim = next((i for i in range(n) if c1[i] != c2[i]), None)
    return difs, prim, len(c1), len(c2), d2.cobertura()


if __name__ == "__main__":
    print("=== A0 · control de identidad y COBERTURA DE RAMA ===")
    print(f"k={K}, mp={MP}, lambda=1, Delta=4, horizonte {HOR:.0f} s, "
          f"u3_mode=dynamic, semillas {SEMS[0]}..{SEMS[-1]}\n")

    print("(1) IDENTIDAD  DAGW(W=None)  ==  DAG de D9-c")
    print(f"{'alpha':>6} | {'semillas iguales':>17} | {'n bloques':>10} {'cadena':>7} "
          f"| {'retargets':>10} {'peso!=1':>8} {'inc!=cont':>10}")
    todo_ok = True
    for alpha in (0.0, 0.10, 0.25, 0.33, 0.40):
        rs = [identidad(alpha, s) for s in SEMS]
        ok = sum(1 for r in rs if r[0])
        todo_ok &= (ok == len(rs))
        nb = sum(r[1] for r in rs) / len(rs)
        nc = sum(r[2] for r in rs) / len(rs)
        cob = [r[3] for r in rs]
        print(f"{alpha:>6.2f} | {ok:>8}/{len(rs):<8} | {nb:>10.1f} {nc:>7.1f} "
              f"| {sum(c['retargets'] for c in cob):>10} "
              f"{sum(c['peso_distinto'] for c in cob):>8} "
              f"{sum(c['inc_distinto'] for c in cob):>10}")
    print(f"\n  -> identidad {'CONFIRMADA' if todo_ok else 'ROTA'}; y con W=None los tres "
          f"contadores de la rama del peso valen 0, como debe ser (control negativo).\n")

    print("(2) COBERTURA con W finita: la rama del peso real SE EJECUTA, ?y DECIDE algo?")
    print("    sp!=  : veces que argmax(blue_work) != argmax(blue_score) al elegir padre sel.")
    print("    w!=   : veces que los padres candidatos NO tenian todos el mismo w")
    print("    sort!=: veces que el orden del mergeset por peso != por conteo")
    print(f"{'W (s)':>7} {'gam':>5} {'alpha':>6} | {'retarg':>7} {'peso!=1':>8} "
          f"{'inc!=c':>7} | {'sd(ln w)':>9} {'rango ln w':>17} "
          f"| {'sp llam':>8} {'w!=':>6} {'sp!=':>5} | {'sort llam':>10} {'sort!=':>7} "
          f"| {'cadena dif':>11}")
    for W in (20.0, 40.0, 80.0, 3083.0):
        for gamma in (0.25,):
            for alpha in (0.0, 0.25, 0.40):
                rs = [divergencia(alpha, s, W, gamma) for s in SEMS]
                cob = [r[4] for r in rs]
                difs = sum(r[0] for r in rs) / len(rs)
                prims = [r[1] for r in rs if r[1] is not None]
                lo = min(c['rango_lnw'][0] for c in cob)
                hi = max(c['rango_lnw'][1] for c in cob)
                print(f"{W:>7.0f} {gamma:>5.2f} {alpha:>6.2f} | "
                      f"{sum(c['retargets'] for c in cob):>7} "
                      f"{sum(c['peso_distinto'] for c in cob):>8} "
                      f"{sum(c['inc_distinto'] for c in cob):>7} | "
                      f"{sum(c['spread_lnw'] for c in cob)/len(cob):>9.4f} "
                      f"{f'[{lo:+.3f}, {hi:+.3f}]':>17} | "
                      f"{sum(c['sp_llamadas'] for c in cob):>8} "
                      f"{sum(c['sp_pesos_dist'] for c in cob):>6} "
                      f"{sum(c['sp_discrepa'] for c in cob):>5} | "
                      f"{sum(c['sort_llamadas'] for c in cob):>10} "
                      f"{sum(c['sort_discrepa'] for c in cob):>7} | "
                      f"{difs:>11.2f}")
        print()
    print("Lectura: `sd(ln w)` es el `epsilon` del empalme (dag-poas-empalme-peso.md §2-3)")
    print("MEDIDO en el horizonte simulado. W=3083 s con horizonte 260 s => 0 retargets:")
    print("es el punto de DISEÑO, y por construccion NO se distingue del peso 1.")
