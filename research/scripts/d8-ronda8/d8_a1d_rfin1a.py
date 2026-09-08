#!/usr/bin/env python3
"""
d8_a1d_rfin1a.py — A1 · AUTOCRITICA. ¿Es la maniobra parasita LEGAL bajo R-FIN-1a?

El simulador heredado (`r8c_gd.DAG.add`) valida `max_block_parents`, `mergeset_size_limit` y
U2/U3'', pero **NO valida R-FIN-1a** (`slot(B) - slot(sp(B)) <= S_max`). Ese es un hueco del
instrumento, no del diseno, y afecta a MI ataque: si una parte de los bloques parasitos
violase R-FIN-1a, serian INVALIDOS y el `delta` de A1 estaria inflado.

Se mide, sobre la maniobra parasita: la distribucion de `slot(B) - slot(sp(B))` de los
bloques del ATACANTE, y que fraccion superaria `S_max = 20 / 30 / 150 s`. Y se recalcula el
`delta` **descontando** los bloques ilegales (se les prohibe entrar: el atacante los pierde).

Criterio alpha: fila alpha = 0 (sin bloques del atacante, `n = 0`, la fila no dice nada, y se
declara). Capacidad: `S_max = 4 s` como control — ahi la violacion SI debe verse.
"""
import math
import sys
import time

sys.path.insert(0, "/home/katana/zeo/ZEROX/research/scripts/d8-ronda8")
from d8_lib import MundoL9, delta_hon, DAG, DELTA                        # noqa: E402

K, MP, MSL = 30, 15, 180
SEMS = list(range(1, 13))
ALPHAS = [0.0, 0.10, 0.25, 0.33, 0.37, 0.40]
SMAXES = [4, 20, 30, 150]
HOR = 1800.0


class MundoL9SMax(MundoL9):
    """Maniobra parasita CON R-FIN-1a aplicada: un bloque cuyo `slot - slot(sp) > S_max` se
    rechaza (el atacante lo pierde). `n_ilegales` cuenta cuantos."""

    def corre_par(self, J, S_max=None):
        d = DAG(k=self.k, u2=True, u3_mode=self.u3_mode,
                max_parents=self.mp, mergeset_limit=self.msl)
        g = d.genesis()
        llega = {g: 0.0}
        priv = []
        self.n_ilegales = 0
        self.gaps_a = []
        self.n_rafagas = 0
        for i, (t, quien, sd, sde, ident) in enumerate(self.ev):
            visibles = [h for h, ta in llega.items() if ta <= t]
            if quien == "h":
                padres = self._padres(d, visibles)
                bid = f"b{i}"
                ok, _ = d.add(bid, padres, t=t, creator="h", ident=ident, sd=sd, seed=sde)
                if ok:
                    llega[bid] = t + DELTA
                continue
            ph = self._padres(d, visibles)
            padres = ([priv[-1]] + [x for x in ph if x != priv[-1]][:self.mp - 1]) \
                if priv else ph[:self.mp]
            bid = f"a{i}"
            ok, _ = d.add(bid, padres, t=t, creator="a", ident=ident, sd=sd, seed=sde)
            if not ok:
                continue
            gap = math.floor(t) - math.floor(d.B[d.gd[bid].sp].t)
            self.gaps_a.append(gap)
            if S_max is not None and gap > S_max:      # R-FIN-1a: INVALIDO
                self.n_ilegales += 1
                del d.B[bid]; del d.anc[bid]; del d.gd[bid]; d.n -= 1
                continue
            priv.append(bid)
            sp_h = d.virtual_sp(visibles)
            if len(priv) >= J and d._key(bid) > d._key(sp_h):
                for b in priv:
                    llega[b] = t
                self.n_rafagas += 1
                priv = []
        tip = d.virtual_sp([h for h in llega])
        return d, tip


if __name__ == "__main__":
    print("=== A1d · ¿es legal la maniobra parasita bajo R-FIN-1a? (autocritica) ===")
    print(f"k={K}, mp={MP}, lambda=1, Delta={DELTA}, horizonte {HOR:.0f} s, "
          f"{len(SEMS)} semillas, J = 31 (y 48 en la segunda tabla).\n")
    t0 = time.time()
    print("--- (a) gaps de los bloques del ATACANTE y fraccion que R-FIN-1a invalidaria ---")
    print(f"{'alpha':>6} | " + " ".join(f"{'S='+str(S):>10}" for S in SMAXES) +
          f" | {'gap max':>8} {'gap medio':>10} {'n_a':>7}")
    for alpha in ALPHAS:
        gs = []
        for sem in SEMS:
            m = MundoL9SMax(alpha, HOR, sem, k=K, mp=MP)
            m.corre_par(31, S_max=None)
            gs.extend(m.gaps_a)
        if not gs:
            print(f"{alpha:>6.2f} | (n_a = 0: sin bloques del atacante, la fila no dice nada)")
            continue
        fila = " ".join(f"{sum(1 for x in gs if x > S)/len(gs):>10.5f}" for S in SMAXES)
        print(f"{alpha:>6.2f} | {fila} | {max(gs):>8} {sum(gs)/len(gs):>10.2f} {len(gs):>7}")

    print("\n--- (b) `delta` recalculado APLICANDO R-FIN-1a (el atacante pierde los "
          "ilegales) ---")
    print(f"{'alpha':>6} {'J':>4} | {'delta sin R-FIN-1a':>19} " +
          " ".join(f"{'delta S='+str(S):>13}" for S in (20, 30, 150)) + f" {'ilegales':>9}")
    for alpha in ALPHAS:
        for J in (31, 48):
            base = []
            porS = {S: [] for S in (20, 30, 150)}
            ile = 0
            for sem in SEMS:
                m = MundoL9SMax(alpha, HOR, sem, k=K, mp=MP)
                d, tip = m.corre_par(J, S_max=None)
                x, _ = delta_hon(d, tip, 60.0, HOR - 60.0)
                base.append(x or 0.0)
                for S in (20, 30, 150):
                    m2 = MundoL9SMax(alpha, HOR, sem, k=K, mp=MP)
                    d2, t2 = m2.corre_par(J, S_max=S)
                    y, _ = delta_hon(d2, t2, 60.0, HOR - 60.0)
                    porS[S].append(y or 0.0)
                    if S == 20:
                        ile += m2.n_ilegales
            print(f"{alpha:>6.2f} {J:>4} | {sum(base)/len(base):>19.4f} " +
                  " ".join(f"{sum(porS[S])/len(porS[S]):>13.4f}" for S in (20, 30, 150)) +
                  f" {ile:>9}")
    print(f"\n[{time.time()-t0:.0f} s]")
