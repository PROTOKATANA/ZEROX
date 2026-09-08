#!/usr/bin/env python3
"""
r8c_sim.py — simulador dirigido por eventos sobre el GHOSTDAG de `r8c_gd.py`.

Modelo (el del paper, seccion 4 / L1020-1045):
  · creacion de bloques: Poisson de tasa lambda; cada bloque es del atacante con prob. alpha.
  · retardo: un bloque honesto creado en t lo ven TODOS los honestos en t+Delta (peor caso Dmax).
  · el atacante ve todo al instante y entrega sus bloques al instante en que decide soltarlos
    (ventaja maxima; el paper: "suffers no internal delays or delays from or to honest nodes").
  · seleccion de padres del honesto: FIEL a `pick_virtual_parents`
    (virtual_processor/processor.rs:1092-1118): candidatos = puntas en orden DESCENDENTE de
    blue_work, sp = el primero, y se anaden hasta `max_block_parents` mientras el presupuesto
    `mergeset_size_limit` lo permita.

NUMEROS PROPIOS DE CADA BLOQUE, FIJADOS EN LA CREACION y jamas recalculados:
  `seed`  entropia que aportaria como inyector (R-FIN-2). El MENU se cuenta sobre `seed`, nunca
          sobre etiquetas: renombrar bloques no puede cambiarlo (error del principal, sol. §5.3).
  `sd`    solution_distance (desempate), `ident` identidad de billete (R-FIN-11).
"""
import random
from r8c_gd import DAG

LAMBDA = 1.0
DELTA = 4.0


class Mundo:
    """Un 'mundo' = un calendario fijo de creaciones. Cambiar la estrategia del atacante NO
    cambia el calendario (numeros aleatorios comunes)."""

    def __init__(self, alpha, T, seed, k=30, mp=15, msl=180, u3_mode="dynamic",
                 atacante_sin_retardo=True):
        self.alpha, self.T, self.k, self.mp, self.msl = alpha, T, k, mp, msl
        self.u3_mode = u3_mode
        # True = modelo del paper (L1024-1027: el atacante no sufre retardo ni hacia ni desde los
        # honestos). False = control: el atacante sufre el mismo Delta que todos.
        self.atacante_sin_retardo = atacante_sin_retardo
        rng = random.Random(seed)
        self.ev = []          # (t, quien, sd, seed_entropia, ident)
        t = 0.0
        i = 0
        while True:
            t += rng.expovariate(LAMBDA)
            if t > T:
                break
            quien = "a" if rng.random() < alpha else "h"
            self.ev.append((t, quien, rng.randrange(10**9),
                            rng.randrange(10**12), (quien, i)))
            i += 1

    # ---------- seleccion de padres, pick_virtual_parents ----------
    def _padres(self, d, visibles):
        cands = sorted(d.tips(visibles), key=lambda h: -d.gd[h].blue_work)
        sp = cands[0]
        padres = [sp]
        ms = 1
        for c in cands[1:]:
            if ms >= self.msl or len(padres) >= self.mp:
                break
            inc = len(d.unordered_mergeset(sp, padres + [c])) + 1 - ms
            if ms + inc <= self.msl:
                padres.append(c)
                ms += inc
        return padres

    # ---------- una ejecucion completa ----------
    def corre(self, estrategia=None, copias=0):
        """`estrategia`: dict {indice_de_evento -> (retraso_de_publicacion, politica_de_padres)}.
        politica: 'tips' | 'sp' | ('retro', n) = colgar del ancestro de cadena n posiciones atras.
        `copias`: si >0, cada bloque del atacante se acompana de `copias` copias de SU billete
                  (R-FIN-11: solo tienen efecto si u3_mode no las neutraliza)."""
        est = estrategia or {}
        d = DAG(k=self.k, u2=True, u3_mode=self.u3_mode,
                max_parents=self.mp, mergeset_limit=self.msl)
        g = d.genesis()
        llega = {g: 0.0}                       # bid -> instante en que lo ve el honesto
        for i, (t, quien, sd, sde, ident) in enumerate(self.ev):
            visibles = [h for h, ta in llega.items() if ta <= t]
            if quien == "h":
                padres = self._padres(d, visibles)
                bid = f"b{i}"
                ok, _ = d.add(bid, padres, t=t, creator="h", ident=ident, sd=sd, seed=sde)
                if ok:
                    llega[bid] = t + DELTA
            else:
                retraso, pol = est.get(i, (0.0, "tips"))
                if retraso is None:                     # retenido para siempre
                    continue
                # paper: ve TODO al instante. control: la misma vista que un honesto.
                todos = list(llega.keys()) if self.atacante_sin_retardo else visibles
                if pol == "tips":
                    padres = self._padres(d, todos)
                elif pol == "sp":
                    padres = [d.virtual_sp(todos)]
                elif isinstance(pol, tuple) and pol[0] == "retro":
                    tip = d.virtual_sp(todos)
                    ch = d.selected_chain(tip)
                    padres = [ch[max(0, len(ch) - 1 - pol[1])]]
                else:
                    raise ValueError(pol)
                bid = f"b{i}"
                ok, _ = d.add(bid, padres, t=t, creator="a", ident=ident, sd=sd, seed=sde)
                if not ok:
                    continue
                extra = 0.0 if self.atacante_sin_retardo else DELTA
                llega[bid] = t + retraso + extra
                for c in range(copias):                 # copias del MISMO billete (R-FIN-11)
                    cid = f"b{i}c{c}"
                    okc, _ = d.add(cid, padres, t=t, creator="a", ident=ident,
                                   sd=sd + 1 + c, seed=sde)
                    if okc:
                        llega[cid] = t + retraso + extra
        # vista honesta final (todo entregado)
        tip = d.virtual_sp([h for h in llega])
        return d, tip

    # ---------- lectura del ancla, R-FIN-1 ----------
    @staticmethod
    def ancla(d, tip, P):
        ch = d.selected_chain(tip)
        if P >= len(ch):
            return None
        b = ch[P]
        return d.B[b].seed          # ESTRUCTURAL: fijado en la creacion
