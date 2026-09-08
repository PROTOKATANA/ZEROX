#!/usr/bin/env python3
"""
d8_a6b_lineas.py — A6 · las dos lineas de §7 que ningun D9 cerro (ademas del margen
economico, que esta en d8_a6_presupuesto.py).

LINEA 5 · «¿es `3k` la ventaja REAL o solo una cota?» (§5.5). Todo el calculo de `k` y toda
la tabla de riesgo desplazan la carrera de Nakamoto por `3k = 90` (Lema 10,
`phantom-ghostdag.txt` L1226-1236). D9-b midio un maximo real de 26 ~ `k` y concluyo que la
cota es holgada — pero lo midio con estrategias que publican al instante. Con la maniobra
PARASITA de A1 la ventaja se acumula. Se mide directamente:
      ventaja(t) = blue_work(punta privada del atacante) - blue_work(sp honesto)
y se reporta su MAXIMO. Si supera 3k, la tabla de riesgo del diseno es OPTIMISTA.

LINEA 3 · «rojos cerca del cruce con U3'': ¿basta el `shuffle`?» (§7.3). **Hallazgo previo
que hay que declarar:** el simulador de D9 (`r8c_sim.Mundo._padres`) **NO implementa el
shuffle**: ordena las puntas por `blue_work` descendente y llena hasta `max_block_parents`.
R-FIN-12 lo declara OBLIGATORIO (`processor.rs:1069-1089`: se conservan
`max_block_parents/2` por `blue_work` y el resto se elige AL AZAR). Luego todas las medidas
de D9-c/d/e/f —y las mias de A1— son de la variante SIN shuffle. Aqui se implementa el
shuffle fiel y se mide si cambia el `delta` de la maniobra parasita.

CRITERIO ALPHA (regla 1): filas alpha = 0. CAPACIDAD (regla 4): la ventaja a alpha=0 debe ser
<= 0 (sin atacante no hay ventaja) y el contador `n_medidas` dice cuantas veces se midio.
"""
import random
import sys
import time

sys.path.insert(0, "/home/katana/zeo/ZEROX/research/scripts/d8-ronda8")
from d8_lib import MundoL9, delta_hon, DAG, DELTA                      # noqa: E402

K, MP, MSL = 30, 15, 180
SEMS = list(range(1, 13))
ALPHAS = [0.0, 0.10, 0.25, 0.33, 0.40]
HOR = 1800.0
JS = [16, 31, 48, 64]


class MundoL9Shuffle(MundoL9):
    """`pick_virtual_parents` CON el shuffle de Kaspa (processor.rs:1069-1089), que el
    simulador de D9 no tiene. `max_candidates` = 4*max_block_parents (Kaspa:
    max_virtual_parent_candidates)."""

    def __init__(self, *a, **kw):
        super().__init__(*a, **kw)
        self.rng_sh = random.Random(0xC0FFEE)
        self.n_shuffles = 0

    def _padres(self, d, visibles):
        cands = sorted(d.tips(visibles), key=lambda h: -d.gd[h].blue_work)
        maxc = 4 * self.mp
        if len(cands) > self.mp // 2:
            self.n_shuffles += 1
            fijos = cands[:self.mp // 2]
            resto = cands[self.mp // 2:]
            self.rng_sh.shuffle(resto)
            cands = (fijos + resto)[:maxc]
        sp = max(cands, key=d._key)          # el sp NO se sortea (Kaspa lo pasa aparte)
        padres = [sp]
        ms = 1
        for c in cands:
            if c == sp:
                continue
            if ms >= self.msl or len(padres) >= self.mp:
                break
            inc = len(d.unordered_mergeset(sp, padres + [c])) + 1 - ms
            if ms + inc <= self.msl:
                padres.append(c)
                ms += inc
        return padres


def ventaja_max(alpha, sem, J, cls):
    """MAXIMO de blue_work(punta privada) - blue_work(sp honesto) a lo largo de la corrida.
    Se instrumenta re-ejecutando la maniobra y midiendo en cada evento del atacante."""
    m = cls(alpha, HOR, sem, k=K, mp=MP)
    d = DAG(k=K, u2=True, u3_mode=m.u3_mode, max_parents=MP, mergeset_limit=MSL)
    g = d.genesis()
    llega = {g: 0.0}
    priv = []
    vmax = -10**9
    nmed = 0
    for i, (t, quien, sd, sde, ident) in enumerate(m.ev):
        visibles = [h for h, ta in llega.items() if ta <= t]
        if quien == "h":
            padres = m._padres(d, visibles)
            bid = f"b{i}"
            ok, _ = d.add(bid, padres, t=t, creator="h", ident=ident, sd=sd, seed=sde)
            if ok:
                llega[bid] = t + DELTA
            continue
        sp_h = d.virtual_sp(visibles)
        ph = m._padres(d, visibles)
        padres = ([priv[-1]] + [x for x in ph if x != priv[-1]][:MP - 1]) if priv else ph[:MP]
        bid = f"a{i}"
        ok, _ = d.add(bid, padres, t=t, creator="a", ident=ident, sd=sd, seed=sde)
        if not ok:
            continue
        priv.append(bid)
        v = d.gd[bid].blue_work - d.gd[sp_h].blue_work
        vmax = max(vmax, v)
        nmed += 1
        if len(priv) >= J and d._key(bid) > d._key(sp_h):
            for b in priv:
                llega[b] = t
            priv = []
    return vmax, nmed


if __name__ == "__main__":
    print("=== A6b · lineas 5 y 3 de §7 ===")
    print(f"k={K}, 3k={3*K}, mp={MP}, lambda=1, Delta={DELTA}, horizonte {HOR:.0f} s, "
          f"{len(SEMS)} semillas, maniobra parasita.\n")
    t0 = time.time()

    print("--- LINEA 5 · ventaja real frente a la cota 3k = 90 del Lema 10 ---")
    print(f"{'alpha':>6} {'J':>4} | {'ventaja MAX':>12} {'/ k':>7} {'/ 3k':>7} "
          f"{'n_medidas':>10}")
    for alpha in ALPHAS:
        for J in JS:
            vs = [ventaja_max(alpha, s, J, MundoL9) for s in SEMS]
            v = max(x[0] for x in vs)
            n = sum(x[1] for x in vs)
            print(f"{alpha:>6.2f} {J:>4} | {v:>12} {v/K:>7.2f} {v/(3*K):>7.2f} {n:>10}")
        print()

    print("--- LINEA 3 · el `shuffle` obligatorio de R-FIN-12, que el simulador de D9 "
          "no tiene ---")
    print(f"{'alpha':>6} {'J':>4} | {'delta SIN shuffle':>18} {'delta CON shuffle':>18} "
          f"{'n_shuffles':>11}")
    for alpha in ALPHAS:
        for J in (31, 48):
            ds, dc, nsh = [], [], 0
            for sem in SEMS:
                m1 = MundoL9(alpha, HOR, sem, k=K, mp=MP)
                d1, t1, _ = m1.corre_l9(J=J, d_fork=1, modo="parasito")
                x, _ = delta_hon(d1, t1, 60.0, HOR - 60.0)
                ds.append(x or 0.0)
                m2 = MundoL9Shuffle(alpha, HOR, sem, k=K, mp=MP)
                d2, t2, _ = m2.corre_l9(J=J, d_fork=1, modo="parasito")
                y, _ = delta_hon(d2, t2, 60.0, HOR - 60.0)
                dc.append(y or 0.0)
                nsh += m2.n_shuffles
            print(f"{alpha:>6.2f} {J:>4} | {sum(ds)/len(ds):>18.4f} "
                  f"{sum(dc)/len(dc):>18.4f} {nsh:>11}")
    print(f"\n[{time.time()-t0:.0f} s]")
