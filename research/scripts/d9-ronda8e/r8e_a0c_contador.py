#!/usr/bin/env python3
"""
r8e_a0c_contador.py — el contador `sp_discrepa` vale 0 en TODO el barrido de A0b. Antes de
publicar eso hay que demostrar dos cosas:

  (1) que el contador PUEDE dispararse (si no, es el error de D9-d otra vez: una rama que
      no corre y una tabla que sale «igual» por construccion). Se fuerza a mano un DAG con
      pesos que invierten el orden y se comprueba que `sp_discrepa` sube.

  (2) POR QUE no se dispara en el simulador: se mide la `epsilon` que de verdad importa,
      que NO es la del empalme. `dag-poas-empalme-peso.md` §2-3 acota la DERIVA TOTAL de
      `ln w` sobre el horizonte `F`; pero en `find_selected_parent` la deriva comun se
      CANCELA (es un factor comun a las dos ramas). Lo que decide es la deriva
      DIFERENCIAL entre las dos ramas en competencia. Se mide:

        eps_dif = max(ln w) − min(ln w) entre los CANDIDATOS de la misma llamada
        margen  = (bw(X) − bw(Y)) / (bs(X) − bs(Y)) / w_medio   para los dos mejores
                  candidatos; si el peso fuera irrelevante valdria 1, si fuera a punto de
                  invertir el orden valdria 0.

  (3) los EMPATES: bajo peso 1 hay empates de `blue_score` que resuelve el desempate de
      ZEROX (menor `solution_distance`); bajo peso real esos empates desaparecen porque el
      peso los rompe antes. Se cuentan los dos.

Criterio alpha: (2) y (3) se miden a varios alpha y cambian con alpha.
"""
import math
import sys
from r8e_lib import DAGW, MundoW, PesoCfg

K, MP = 30, 15
HOR = 260.0
SEMS = list(range(1, 9))


# ---------------------------------------------------------------- (1) el contador dispara
def prueba_contador():
    """DAG a mano: dos padres X, Y con bs(X) > bs(Y) pero bw(X) < bw(Y) por el peso.
    Se fabrica poniendo `lnsr` a mano (es lo que haria un retarget extremo)."""
    d = DAGW(k=K, u2=False, u3_mode="off", max_parents=MP, mergeset_limit=10_000,
             wcfg=PesoCfg(W=None))
    g = d.genesis()
    # cadena A: 3 bloques ligeros colgando de G (w = e^-2 = 0,135)
    prev = g
    for i in range(3):
        bid = f"A{i}"
        d.add(bid, [prev], t=1.0 + i, creator="h", ident=("A", i), sd=i)
        d.lnsr[bid] = 2.0          # ln SR = +2 -> w = e^-2 (ligero)
        nd = d.gd[bid]
        nd.blue_work = d.gd[nd.sp].blue_work + sum(d.w(h) for h in nd.mergeset_blues)
        prev = bid
    X = prev
    # cadena B: 2 bloques pesados colgando de G (w = e^+2 = 7,39)
    prev = g
    for i in range(2):
        bid = f"B{i}"
        d.add(bid, [prev], t=1.0 + i, creator="h", ident=("B", i), sd=100 + i)
        d.lnsr[bid] = -2.0         # ln SR = -2 -> w = e^+2 (pesado)
        nd = d.gd[bid]
        nd.blue_work = d.gd[nd.sp].blue_work + sum(d.w(h) for h in nd.mergeset_blues)
        prev = bid
    Y = prev
    antes = d.n_sp_discrepa
    sp = d.find_selected_parent([X, Y])
    print(f"  bs(X)={d.gd[X].blue_score} bw(X)={d.gd[X].blue_work:.4f}   "
          f"bs(Y)={d.gd[Y].blue_score} bw(Y)={d.gd[Y].blue_work:.4f}")
    print(f"  argmax por CONTEO = {max([X, Y], key=d._key_conteo)}   "
          f"argmax por PESO = {sp}")
    print(f"  sp_discrepa: {antes} -> {d.n_sp_discrepa}   "
          f"{'CONTADOR VIVO' if d.n_sp_discrepa > antes else '*** CONTADOR MUERTO ***'}")
    return d.n_sp_discrepa > antes


# ------------------------------------------------- (2)(3) la epsilon DIFERENCIAL y empates
class DAGmed(DAGW):
    """Instrumenta `find_selected_parent` para medir el margen real."""

    def __init__(self, *a, **kw):
        super().__init__(*a, **kw)
        self.eps_dif = []       # max ln w - min ln w entre candidatos
        self.margen = []        # (bw(X)-bw(Y))/((bs(X)-bs(Y)) * w_medio)
        self.empates_bs = 0     # bs(X) == bs(Y): con peso 1 decide `sd`
        self.empates_bw = 0     # bw(X) == bw(Y): con peso real decide `sd`

    def find_selected_parent(self, parents):
        ps = list(parents)
        if len(ps) > 1:
            lw = [-self.lnsr.get(p, 0.0) for p in ps]
            self.eps_dif.append(max(lw) - min(lw))
            orden = sorted(ps, key=self._key, reverse=True)
            X, Y = orden[0], orden[1]
            dbs = self.gd[X].blue_score - self.gd[Y].blue_score
            dbw = self.gd[X].blue_work - self.gd[Y].blue_work
            if dbs == 0:
                self.empates_bs += 1
            if abs(dbw) < 1e-12:
                self.empates_bw += 1
            if dbs != 0:
                wm = sum(self.w(b) for b in self.B) / len(self.B)
                self.margen.append(dbw / (dbs * wm))
        return super().find_selected_parent(ps)


class MundoMed(MundoW):
    def _fabrica(self, **kw):
        d = DAGmed(wcfg=self.wcfg, **kw)
        self.ultimo = d
        return d


def mide(alpha, W, gamma, modo="desliz"):
    eps, mar, ebs, ebw, npar = [], [], 0, 0, 0
    for s in SEMS:
        m = MundoMed(alpha, HOR, s, k=K, mp=MP, u3_mode="dynamic",
                     wcfg=PesoCfg(W=W, gamma=gamma, modo=modo))
        d, t = m.corre({})
        eps += d.eps_dif; mar += d.margen
        ebs += d.empates_bs; ebw += d.empates_bw
        npar += d.n_sp_llamadas
    eps_med = sum(eps) / len(eps) if eps else 0.0
    eps_max = max(eps) if eps else 0.0
    mar_min = min(mar) if mar else float("nan")
    mar_med = sum(mar) / len(mar) if mar else float("nan")
    return eps_med, eps_max, mar_med, mar_min, ebs, ebw, npar


if __name__ == "__main__":
    print("=== A0c · ¿esta VIVO el contador, y por que no se dispara? ===\n")
    print("(1) el contador `sp_discrepa` SE DISPARA cuando debe (DAG construido a mano):")
    vivo = prueba_contador()
    print()
    print("(2) la `epsilon` que decide NO es la del empalme: es la DIFERENCIAL entre las")
    print("    ramas en competencia. `margen` = 1 significa «el peso se comporta como el")
    print("    conteo»; `margen` <= 0 seria una inversion.")
    print(f"{'modo':>7} {'W':>7} {'gam':>5} {'alpha':>6} | {'eps_dif med':>12} {'eps_dif max':>12} "
          f"| {'margen med':>11} {'margen MIN':>11} | {'empates bs':>11} {'empates bw':>11} "
          f"{'llamadas':>9}")
    for modo in ("desliz", "epoca"):
        for W, gamma in ((3083.0, 0.25), (20.0, 0.25), (20.0, 1.0), (10.0, 1.0)):
            for alpha in (0.0, 0.25, 0.40):
                r = mide(alpha, W, gamma, modo)
                print(f"{modo:>7} {W:>7.0f} {gamma:>5.2f} {alpha:>6.2f} | {r[0]:>12.4f} "
                      f"{r[1]:>12.4f} | {r[2]:>11.4f} {r[3]:>11.4f} | {r[4]:>11} {r[5]:>11} "
                      f"{r[6]:>9}")
        print()
    print("(3) `empates bs` = veces que el CONTEO empata y decide el desempate de ZEROX")
    print("    (menor solution_distance). `empates bw` = lo mismo con el PESO real.")
    print(f"\nCONTADOR {'VIVO' if vivo else 'MUERTO'}.")
