#!/usr/bin/env python3
"""
r8c_a1b_mecanismo.py — LINEA A1, ?POR QUE se mueve el ancla de cadena?

Hipotesis: `pos(B) = pos(sp(B)) + 1` cuenta SALTOS de cadena, y GHOSTDAG optimiza `blue_work`,
que es AGNOSTICO al numero de saltos. Un bloque que fusiona mucho gana mucho blue_work con UN
salto; uno que fusiona poco gasta un salto por poco peso. El atacante, que segun el modelo del
paper no sufre retardo (L1030-1035), decide cuantos saltos mete el DAG por segundo.

Consecuencia: mover el ancla NO necesita reorganizar nada. Basta con anadir o quitar un salto
por debajo de la posicion objetivo: TODO lo que hay a partir de ahi se desplaza.

Se mide:
  1. fraccion de posiciones de cadena que ocupa el atacante SIN atacar (juego honesto).
  2. para cada estrategia: quien ocupa P, y a que posicion se ha ido el ocupante de referencia.
"""
import statistics
from r8c_sim import Mundo
from r8c_a1_menu import estrategias, K, MP


def ocupacion(alpha, semillas=range(1, 9), T=200.0):
    fr, lc = [], []
    for s in semillas:
        m = Mundo(alpha, T, s, k=K, mp=MP, u3_mode="dynamic")
        d, tip = m.corre({})
        ch = d.selected_chain(tip)
        lc.append((len(ch) - 1) / T)
        fr.append(sum(1 for b in ch[1:] if d.B[b].creator == "a") / max(1, len(ch) - 1))
    return statistics.mean(lc), statistics.mean(fr)


def desplazamiento(alpha, semilla, P, T=260.0):
    m = Mundo(alpha, T, semilla, k=K, mp=MP, u3_mode="dynamic")
    d0, tip0 = m.corre({})
    ch0 = d0.selected_chain(tip0)
    if P >= len(ch0):
        return None
    ref_seed = d0.B[ch0[P]].seed
    tiers, idx = estrategias(m, P, d0, tip0)
    salidas = {}
    for g in tiers:
        for e in g:
            d, tip = m.corre(e)
            ch = d.selected_chain(tip)
            if P >= len(ch):
                continue
            b = ch[P]
            # a que posicion se ha movido el ocupante de referencia (por `seed`, estructural)
            nuevo_pos = next((i for i, x in enumerate(ch) if d.B[x].seed == ref_seed), None)
            salidas.setdefault(d.B[b].seed, (d.B[b].creator, nuevo_pos, len(ch)))
    creadores = [v[0] for v in salidas.values()]
    desp = [v[1] - P for v in salidas.values() if v[1] is not None]
    largos = [v[2] for v in salidas.values()]
    return dict(menu=len(salidas), n_atac=creadores.count("a"), n_hon=creadores.count("h"),
                desp=sorted(set(desp)), largos=(min(largos), max(largos)),
                fuera=sum(1 for v in salidas.values() if v[1] is None))


if __name__ == "__main__":
    print("=== A1b · mecanismo ===\n")
    print("(1) Ocupacion de la cadena SIN atacar (el atacante juega honesto).")
    print("    En el modelo del paper el atacante no sufre retardo, asi que sus bloques")
    print("    cuelgan siempre de la punta mas fresca y ganan la carrera de sp.\n")
    print(f"{'alpha':>6} {'lambda_chain':>13} {'% posiciones de cadena del atacante':>37}")
    for a in (0.0, 0.10, 0.25, 0.33, 0.40):
        lc, fr = ocupacion(a)
        print(f"{a:>6.2f} {lc:>13.4f} {100*fr:>36.1f}%")

    print("\n(2) De que esta hecho el menu de la posicion 30 (12 semillas).")
    print(f"{'alpha':>6} {'menu':>6} {'entropias del ATACANTE':>23} {'entropias honestas':>19} "
          f"{'desplazamiento del ocupante':>28}")
    for a in (0.0, 0.10, 0.25, 0.33, 0.40):
        ms, na, nh, ds = [], [], [], set()
        for s in range(1, 13):
            r = desplazamiento(a, s, 30)
            if r is None:
                continue
            ms.append(r["menu"]); na.append(r["n_atac"]); nh.append(r["n_hon"])
            ds |= set(r["desp"])
        if not ms:
            continue
        print(f"{a:>6.2f} {statistics.mean(ms):>6.2f} {statistics.mean(na):>23.2f} "
              f"{statistics.mean(nh):>19.2f} {sorted(ds)!s:>28}")
    print("\n  'desplazamiento' = a cuantas posiciones se va el ocupante de referencia.")
    print("  Si contiene valores != 0, el ancla se mueve por CAMBIO DE NUMERO DE SALTOS,")
    print("  no por reorganizacion.")
