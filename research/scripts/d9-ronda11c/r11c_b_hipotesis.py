#!/usr/bin/env python3
"""
r11c_b_hipotesis.py — PUNTO B · `m`, `c_m` e `I` bajo las seis lecturas del ancla.

Las SEIS reglas se leen sobre LA MISMA cadena seleccionada de LA MISMA corrida (numeros
aleatorios comunes): cualquier diferencia entre columnas es de la REGLA, no del ruido.

  BASE  R-FIN-1 vigente : menor blue_work entre los de slot >= T_j
  H1    slot exacto (informe 52 problemas §6b)
  H2    desempate por solution_distance (§6c) aplicado a toda la ventana
  H1H2  H1 + desempate por solution_distance  <- la forma literal de §6c
  H3    S_max en dos escalas (§10): candidato solo si pub_slot - slot < 45 s
  H1H3  H1 + la restriccion de candidatura

`I = c_m * sqrt(n_eval/(alpha*lambda))/g` con n_eval = 135 (rho_max = 3 x W_dec = 45 s),
g = 3,6 %, alpha de calibracion 0,10 (R-FIN-14 (f); reproduce los 851 s de 9c con m=2,955).

Criterio alpha: fila alpha = 0 -> m = 1,000 en las seis columnas.
Cobertura de rama: COB11 se acumula DENTRO de cada worker y se suma aqui. Si
`difiere[H2]` fuese 0 la comparacion no diria nada; si `cand_multi` fuese 0, el filtro de
H1 no se habria ejercitado nunca.
"""
import multiprocessing as mp
import sys
import time

sys.path.insert(0, "/home/katana/zeo/ZEROX/research/scripts/d9-ronda11c")
import r11c_lib as L                                            # noqa: E402
from r11c_lib import (MundoR11, perfil, anclas, fam_retencion,   # noqa: E402
                      slot_de, REGLAS, I_de, S_MAX)

P = 30
BANDA = 10
HOR = 260.0
W = 30.0
SEMS = list(range(1, 13))
SEMS_9C = [11, 23, 37, 41, 59, 67, 73, 89, 97, 101, 113, 127]    # robustez (9c)
ALPHAS = (0.0, 0.10, 0.25, 0.40)
NPROC = 12


def reinicia_cobertura():
    """Pone a cero los contadores de cobertura de ESTE worker. No toca ningun resultado."""
    for k in list(L.COB11):
        L.COB11[k] = {r: 0 for r in REGLAS} if k == "difiere" else 0


def una(args):
    alpha, semilla, copias = args
    reinicia_cobertura()
    mundo = MundoR11(alpha, HOR, semilla, s_max=S_MAX)
    d0, tip0 = mundo.corre({}, copias=0)
    ch0 = d0.selected_chain(tip0)
    if P >= len(ch0):
        return None
    tP = d0.B[ch0[P]].t
    Ss = [slot_de(tP + u) for u in range(-BANDA, BANDA + 1)]
    ests, idx = fam_retencion(mundo, tP, W)
    ac = {r: {S: set() for S in Ss} for r in REGLAS}
    for e in ests:
        d, tip = mundo.corre(e, copias=copias)
        pf = perfil(d, tip)
        for S in Ss:
            a = anclas(pf, S)
            for r in REGLAS:
                if a[r][0] is not None:
                    ac[r][S].add(a[r][0])
    ms = {r: sum(len(ac[r][S]) for S in Ss) / len(Ss) for r in REGLAS}
    mx = {r: max(len(ac[r][S]) for S in Ss) for r in REGLAS}
    cob = {k: (dict(v) if isinstance(v, dict) else v) for k, v in L.COB11.items()}
    return ms, mx, len(ests), cob


def suma_cob(cobs):
    tot = {k: ({r: 0 for r in REGLAS} if k == "difiere" else 0) for k in cobs[0]}
    for c in cobs:
        for k, v in c.items():
            if k == "difiere":
                for r in REGLAS:
                    tot[k][r] += v[r]
            elif k == "cand_multi_max":
                tot[k] = max(tot[k], v)
            else:
                tot[k] += v
    return tot


def barrido(sems, etiq, copias=(0, 14)):
    print(f"\n--- {etiq} ---")
    print(f"{'copias':>7} {'alpha':>6} | " + " ".join(f"{r:>7}" for r in REGLAS) +
          f" | {'estrat':>7}")
    res = {}
    cobs_all = []
    for cop in copias:
        for alpha in ALPHAS:
            with mp.Pool(NPROC) as pool:
                rs = [r for r in pool.map(una, [(alpha, s, cop) for s in sems]) if r]
            n = len(rs)
            ms = {r: sum(x[0][r] for x in rs) / n for r in REGLAS}
            res[(cop, alpha)] = (ms, {r: max(x[1][r] for x in rs) for r in REGLAS}, n)
            cobs_all.extend(x[3] for x in rs)
            print(f"{cop:>7} {alpha:>6.2f} | " + " ".join(f"{ms[r]:>7.3f}" for r in REGLAS)
                  + f" | {sum(x[2] for x in rs)/n:>7.1f}")
        print()
    return res, suma_cob(cobs_all)


if __name__ == "__main__":
    print("=== B · `m` bajo BASE / H1 / H2 / H1+H2 / H3 / H1+H3, mismas corridas ===")
    print(f"k=30, mp=15, lambda=1, Delta=4, horizonte {HOR:.0f} s, P={P}, 21 umbrales,")
    print(f"tau = 1 s, S_max(validez) = {S_MAX} s, S_max(ancla) = {L.S_ANCLA} s,")
    print("familia D9-f + retencion hasta S_max (retrasos 0/4/12/30/60/100/149 s).\n")
    t0 = time.time()
    res, cob = barrido(SEMS, "semillas 1..12 (las de D9-f B1)")
    res9, cob9 = barrido(SEMS_9C, "semillas de 9c (robustez, copias = 0): "
                         "11,23,37,41,59,67,73,89,97,101,113,127", copias=(0,))

    print("=" * 100)
    print("COBERTURA DE RAMA (acumulada en los workers, semillas 1..12 + las de 9c)")
    c = suma_cob([cob, cob9])
    print(f"   perfiles de cadena leidos ............ {c['perfiles']:>10,}")
    print(f"   comparaciones de ancla ............... {c['comparaciones']:>10,}")
    print(f"   ventana BASE con >1 candidato ........ {c['ventana_multi']:>10,}")
    print(f"   conjunto H1 (mismo slot) con >1 ...... {c['cand_multi']:>10,}"
          f"   (maximo: {c['cand_multi_max']})")
    print(f"   H3 descarta algun candidato .......... {c['h3_muerde']:>10,}")
    print(f"   H3 descarta el ancla de BASE ......... {c['h3_descarta_ancla']:>10,}")
    print(f"   H3 deja el conjunto VACIO ............ {c['h3_vacio']:>10,}")
    print(f"   tip sin sucesor (pub_slot = inf) ..... {c['sin_sucesor']:>10,}")
    for r in REGLAS:
        print(f"   ancla({r}) != ancla(BASE) {'.'*(12-len(r))} {c['difiere'][r]:>10,}")

    print("\n" + "=" * 100)
    print(f"CONSTANTES  ·  I = c_m*sqrt(n_eval/(alpha*lambda))/g,  n_eval = {L.N_EVAL:.0f} "
          f"(rho_max=3 x W_dec=45 s),  g = {100*L.G_OBJ:.1f} %,  alpha_cal = {L.A_CAL}")
    print("Se usa la `m` de DISENO = maximo sobre alpha y copias de la m media (el peor caso).")
    print(f"{'regla':>7} | {'m (a=0,10)':>11} {'m (a=0,25)':>11} {'m (a=0,40)':>11} "
          f"{'m diseno':>9} | {'c_m':>7} {'I (s)':>8} {'F (h)':>7} | {'I vs BASE':>10}")
    Ibase = None
    for r in REGLAS:
        mdis = max(res[(c2, a)][0][r] for c2 in (0, 14) for a in (0.10, 0.25, 0.40))
        mdis = max(mdis, max(res9[(0, a)][0][r] for a in (0.10, 0.25, 0.40)))
        cm, I, F = I_de(mdis)
        if r == "BASE":
            Ibase = I
        print(f"{r:>7} | {res[(14,0.10)][0][r]:>11.3f} {res[(14,0.25)][0][r]:>11.3f} "
              f"{res[(14,0.40)][0][r]:>11.3f} {mdis:>9.3f} | {cm:>7.4f} {I:>8.0f} "
              f"{F/3600:>7.2f} | {I/Ibase:>9.3f}x")
    print(f"\n[{time.time()-t0:.0f} s]")
