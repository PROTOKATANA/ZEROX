#!/usr/bin/env python3
"""
d8_a3_smax.py — A3 · PARTICION + `S_max` + R-FIN-7, SIN particion real.

R-FIN-1a: `slot(B) - slot(sp(B)) <= S_max`, `S_max in [20, 150] s`. Un bloque que la viole
**no es huerfano: es INVALIDO** — R-FIN-8 ni siquiera se le aplica, la red lo rechaza.
D9-d A4.2 lo vio como tolerancia a particiones («un lado con f < 0,09 fabrica bloques
invalidos»). D8 le da la vuelta: **es una regla de censura que el atacante puede provocar**.

Tres medidas, todas con `alpha` y con la fila `alpha = 0`:

 (M1) SIN ECLIPSE. Fraccion de bloques HONESTOS cuyo `slot(B) - slot(sp(B))` supera `S_max`,
      bajo la familia completa del atacante (politicas por bloque + retraso + retencion).
      Se convierte a **bloques honestos invalidados por hora** con lambda = 1 b/s.
      El atacante NO necesita particion: le basta con mover la cadena seleccionada.

 (M2) ECLIPSE PARCIAL. Un honesto `H_C` recibe TODO con `E` segundos de retraso extra
      (eclipse parcial: el atacante le retiene las puntas, no le corta la red). Se mide la
      fraccion de SUS bloques que quedan invalidos, para `E` de 0 a 200 s.

 (M3) ECLIPSE TOTAL, forma cerrada y comprobada por Monte Carlo: un grupo aislado con
      fraccion `f` del espacio solo puede colgar de sus propios bloques, separados
      Exp(f*lambda); `P(invalido) = exp(-f*lambda*S_max)`. Es la cota de la que sale el
      «f >= 0,09» de R-FIN-7, aqui recalculada para los tres `S_max`.

CAPACIDAD (regla 4): M1 imprime `gap max` y `n`; si `gap max` nunca superase `S_max` el
instrumento no podria detectar invalidaciones — el control es `S_max = 4 s`, que SI las ve.
"""
import math
import random
import sys
import time
from collections import defaultdict

sys.path.insert(0, "/home/katana/zeo/ZEROX/research/scripts/d9-ronda8f")
from r8f_lib import Mundo, K, MP, idx_ventana                              # noqa: E402

SEMS = list(range(1, 13))
ALPHAS = [0.0, 0.10, 0.25, 0.33, 0.40]
SMAXES = [4, 20, 30, 150]                    # 4 s = control de capacidad
HOR = 900.0
POLS = ["tips", "sp", ("retro", 1), ("retro", 2), ("retro", 4), ("retro", 8), ("retro", 16)]
RETRASOS = [0.0, 12.0, 40.0, 150.0]


def gaps_honestos(d, tip):
    """slot(B) - slot(sp(B)) de cada bloque HONESTO del DAG (slot = indice de PoT, gran 1 s).
    Se mide sobre TODOS los bloques honestos, no solo los de cadena: R-FIN-1a es una regla
    de VALIDEZ, se aplica a todo bloque en el momento de crearlo."""
    g = []
    for b, blk in d.B.items():
        if blk.creator != "h":
            continue
        sp = d.gd[b].sp
        if sp is None:
            continue
        g.append(math.floor(blk.t) - math.floor(d.B[sp].t))
    return g


def m1(alpha, sem):
    mundo = Mundo(alpha, HOR, sem, k=K, mp=MP, u3_mode="dynamic")
    idx = [i for i, (t, q, *_) in enumerate(mundo.ev) if q == "a"]
    ests = [{}]
    for pol in POLS:
        for r in RETRASOS:
            ests.append({i: (r, pol) for i in idx})
    ests.append({i: (None, "tips") for i in idx})          # retencion total
    peor = {S: 0.0 for S in SMAXES}
    gmax = 0
    nh = 0
    for e in ests:
        d, tip = mundo.corre(e, copias=14)
        g = gaps_honestos(d, tip)
        if not g:
            continue
        nh = max(nh, len(g))
        gmax = max(gmax, max(g))
        for S in SMAXES:
            peor[S] = max(peor[S], sum(1 for x in g if x > S) / len(g))
    return peor, gmax, nh, len(ests)


class MundoEclipse(Mundo):
    """M2 · un tercer honesto `H_C` con fraccion `fc` del espacio que recibe TODO con `E`
    segundos de retraso EXTRA (eclipse parcial). Sus bloques llegan a los demas al instante
    (el atacante le retiene la entrada, no la salida: es el caso que mas le conviene, porque
    los bloques invalidos de C se propagan y se rechazan)."""

    def corre_ecl(self, E, sem=0, fc=0.05, pol="tips", retraso=0.0):
        from r8f_lib import DAG
        rng = random.Random(f"{sem}|{self.T}|{self.alpha}|{E}|{fc}")
        d = DAG(k=self.k, u2=True, u3_mode=self.u3_mode,
                max_parents=self.mp, mergeset_limit=self.msl)
        g = d.genesis()
        llega = {g: 0.0}
        llegaC = {g: 0.0}
        gapsC = []
        nC = 0
        for i, (t, quien, sd, sde, ident) in enumerate(self.ev):
            visibles = [h for h, ta in llega.items() if ta <= t]
            visC = [h for h, ta in llegaC.items() if ta <= t]
            if quien == "h" and rng.random() < fc:
                padres = self._padres(d, visC)                # C usa SU vista
                bid = f"c{i}"
                ok, _ = d.add(bid, padres, t=t, creator="h", ident=ident, sd=sd, seed=sde)
                if ok:
                    sp = d.gd[bid].sp
                    gapsC.append(math.floor(t) - math.floor(d.B[sp].t))
                    nC += 1
                    llega[bid] = t + 4.0
                    llegaC[bid] = t
                continue
            if quien == "h":
                padres = self._padres(d, visibles)
                bid = f"b{i}"
                ok, _ = d.add(bid, padres, t=t, creator="h", ident=ident, sd=sd, seed=sde)
                if ok:
                    llega[bid] = t + 4.0
                    llegaC[bid] = t + 4.0 + E
            else:
                todos = list(llega.keys())
                if pol == "tips":
                    padres = self._padres(d, todos)
                elif pol == "sp":
                    padres = [d.virtual_sp(todos)]
                else:
                    tip = d.virtual_sp(todos)
                    ch = d.selected_chain(tip)
                    padres = [ch[max(0, len(ch) - 1 - pol[1])]]
                bid = f"a{i}"
                ok, _ = d.add(bid, padres, t=t, creator="a", ident=ident, sd=sd, seed=sde)
                if ok:
                    llega[bid] = t + retraso
                    llegaC[bid] = t + retraso + E
        return gapsC, nC


if __name__ == "__main__":
    print("=== A3 · S_max como arma: bloques honestos INVALIDOS sin particion real ===")
    print(f"k={K}, mp={MP}, lambda=1, Delta=4, u3=dynamic, horizonte {HOR:.0f} s, "
          f"{len(SEMS)} semillas, copias=14.")
    print("R-FIN-1a: slot(B)-slot(sp(B)) <= S_max. S_max=4 s es CONTROL de capacidad.\n")
    t0 = time.time()

    print("--- (M1) sin eclipse: peor fraccion de bloques honestos con gap > S_max ---")
    cab = f"{'alpha':>6} | " + " ".join(f"{'S='+str(S):>12}" for S in SMAXES) + \
          f" | {'gap max':>8} {'n_hon':>7} {'estrat':>7}"
    print(cab); print("-" * len(cab))
    for alpha in ALPHAS:
        acc = {S: 0.0 for S in SMAXES}
        gm = 0; nh = 0; ne = 0
        for sem in SEMS:
            peor, gmax, n, e = m1(alpha, sem)
            for S in SMAXES:
                acc[S] = max(acc[S], peor[S])
            gm = max(gm, gmax); nh = max(nh, n); ne = e
        fila = " ".join(f"{acc[S]:>12.5f}" for S in SMAXES)
        print(f"{alpha:>6.2f} | {fila} | {gm:>8} {nh:>7} {ne:>7}")
    print("\n   -> bloques honestos invalidados POR HORA = fraccion x 3600 x (1-alpha)")
    for alpha in ALPHAS:
        acc = {S: 0.0 for S in SMAXES}
        for sem in SEMS:
            peor, *_ = m1(alpha, sem)
            for S in SMAXES:
                acc[S] = max(acc[S], peor[S])
        fila = " ".join(f"{acc[S]*3600*(1-alpha):>12.1f}" for S in SMAXES)
        print(f"{alpha:>6.2f} | {fila}")

    print("\n--- (M2) eclipse parcial: un honesto con f=5 % recibe todo con E s de retraso ---")
    print(f"{'E (s)':>7} {'alpha':>6} | " +
          " ".join(f"{'inv S='+str(S):>12}" for S in SMAXES) + f" | {'n_C':>6}")
    for E in (0.0, 10.0, 20.0, 40.0, 100.0, 200.0):
        for alpha in (0.0, 0.25):
            tot = defaultdict(int); n = 0
            for sem in SEMS:
                m = MundoEclipse(alpha, HOR, sem, k=K, mp=MP, u3_mode="dynamic")
                gs, nc = m.corre_ecl(E)
                n += nc
                for S in SMAXES:
                    tot[S] += sum(1 for x in gs if x > S)
            fila = " ".join(f"{tot[S]/max(n,1):>12.4f}" for S in SMAXES)
            print(f"{E:>7.0f} {alpha:>6.2f} | {fila} | {n:>6}")

    print("\n--- (M3) eclipse total de un grupo con fraccion f: P(invalido) = exp(-f*S_max) ---")
    print(f"{'f':>7} " + " ".join(f"{'S='+str(S):>12}" for S in SMAXES))
    for f in (0.005, 0.01, 0.02, 0.05, 0.09, 0.20):
        print(f"{f:>7.3f} " + " ".join(f"{math.exp(-f*S):>12.5f}" for S in SMAXES))
    print("   (comprobacion Monte Carlo, f=0,05, S_max=20, 200 000 muestras):")
    rng = random.Random(7)
    n = 200000
    c = sum(1 for _ in range(n) if rng.expovariate(0.05) > 20)
    print(f"      medido {c/n:.5f}   cerrado {math.exp(-0.05*20):.5f}")
    print(f"\n[{time.time()-t0:.0f} s]")
