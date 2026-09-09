#!/usr/bin/env python3
"""
r11c_c3_lema.py — PUNTO C.3 · el Lema A4-slot bajo cada regla.

Estructura copiada de `d9-ronda8f/r8f_b3_prop7.py` (D9-f), citada: mismas vistas honestas
crecientes, mismas parejas de vistas, mismo enunciado. Lo unico que cambia es la LECTURA
del ancla, que aqui son las seis reglas de la ronda 11c.

LEMA A4-slot (D9-f): «si el ancla cambia entre dos vistas, las dos cadenas difieren en una
posicion `p <= idx(ancla)`». Su prueba usa que el ancla es EL PRIMER indice con una
propiedad, luego queda determinada por el prefijo `0..idx`. Con el desempate por
`solution_distance` (H2) el ancla YA NO es el primer indice: es el minimo de `sd` sobre un
conjunto que se extiende HACIA ADELANTE, y el prefijo `0..idx` no lo determina. Aqui se
mide si el lema se rompe de hecho, y `p_max_h2` da la profundidad que haria falta.

Se anade la version REPARADA para H1H2: `p <= idx_ultimo_candidato + 1` (el prefijo hasta
el primer bloque de slot mayor). Si esa columna sale 100 % y la otra no, el diagnostico
esta cerrado.

Criterio alpha: el numero de reorganizaciones y de cambios de ancla crece con alpha.
"""
import multiprocessing as mp
import sys

sys.path.insert(0, "/home/katana/zeo/ZEROX/research/scripts/d9-ronda11c")
from r11c_lib import (MundoR11, perfil, anclas, slot_de, REGLAS,      # noqa: E402
                      _cands_base, _cands_h1, _filtro_h3, S_MAX, S_ANCLA, DELTA)

HOR = 200.0
PASOS = 40
SEMS = list(range(1, 13))
ALPHAS = (0.0, 0.10, 0.25, 0.40)
NPROC = 12


def una(args):
    alpha, semilla = args
    m = MundoR11(alpha, HOR, semilla, s_max=S_MAX)
    d, tip = m.corre({})
    llega = m.llega
    ts = [HOR * (j + 1) / PASOS for j in range(PASOS)]
    vistas = []
    for tt in ts:
        vis = [h for h, ta in llega.items() if ta <= tt]
        if len(vis) < 2:
            continue
        sp = d.virtual_sp(vis)
        vistas.append((d.selected_chain(sp), perfil(d, sp)))
    Ss = [slot_de(u) for u in range(1, int(HOR), max(1, int(HOR) // 40))]

    ok = {r: [0, 0] for r in REGLAS}          # [cumple, total de cambios de ancla]
    rep = [0, 0]                              # version reparada para H1H2
    pmax = {r: 0 for r in REGLAS}
    for a in range(len(vistas) - 1):
        for b in range(a + 1, len(vistas)):
            c1, pf1 = vistas[a]
            c2, pf2 = vistas[b]
            Lm = min(len(c1), len(c2))
            p = next((i for i in range(Lm) if c1[i] != c2[i]), None)
            if p is None or p == 0:
                continue
            for S in Ss:
                A1 = anclas(pf1, S, contar=False)
                A2 = anclas(pf2, S, contar=False)
                for r in REGLAS:
                    if A1[r][0] is None or A2[r][0] is None or A1[r] == A2[r]:
                        continue
                    ok[r][1] += 1
                    if p <= A1[r][1]:
                        ok[r][0] += 1
                    else:
                        pmax[r] = max(pmax[r], p - A1[r][1])
                # reparacion para H1H2: hasta el ULTIMO candidato del mismo slot, +1
                if A1["H1H2"][0] is not None and A2["H1H2"][0] is not None \
                        and A1["H1H2"] != A2["H1H2"]:
                    cs = _cands_h1(_cands_base(pf1, S))
                    lim = (max(e[0] for e in cs) + 1) if cs else A1["H1H2"][1]
                    rep[1] += 1
                    if p <= lim:
                        rep[0] += 1
    return ok, rep, pmax, len(vistas)


if __name__ == "__main__":
    print("=== C.3 · Lema A4-slot bajo las seis reglas ===")
    print(f"k=30, mp=15, horizonte {HOR:.0f} s, {PASOS} vistas crecientes, 12 semillas,")
    print(f"tau = 1 s, S_max = {S_MAX} s, S_ancla = {S_ANCLA} s, Delta = {DELTA} s.")
    print("(A4x) = «el ancla cambia => la cadena difiere en p <= idx(ancla)»: cumple/total.\n")
    print(f"{'alpha':>6} | " + " ".join(f"{r:>15}" for r in REGLAS) +
          f" | {'H1H2 reparado':>15}")
    for alpha in ALPHAS:
        with mp.Pool(NPROC) as pool:
            rs = pool.map(una, [(alpha, s) for s in SEMS])
        tot = {r: [sum(x[0][r][0] for x in rs), sum(x[0][r][1] for x in rs)] for r in REGLAS}
        rep = [sum(x[1][0] for x in rs), sum(x[1][1] for x in rs)]
        pm = {r: max(x[2][r] for x in rs) for r in REGLAS}
        print(f"{alpha:>6.2f} | " + " ".join(f"{tot[r][0]:>7}/{tot[r][1]:<7}" for r in REGLAS)
              + f" | {rep[0]:>7}/{rep[1]:<7}")
        print(f"{'':>6} | " + " ".join(f"{'exceso p-idx max '+str(pm[r]):>15}" for r in REGLAS))
    print("\nLectura: una columna con cumple<total REFUTA el lema para esa regla, y el")
    print("'exceso p-idx max' dice cuanto mas profundo hay que mirar. La columna reparada")
    print("es la version del lema que SI se puede demostrar para H1H2.")
