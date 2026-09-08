#!/usr/bin/env python3
"""
r8e_z_auditoria.py — lectura de las TRES marcas que `AUDITA_SCRIPTS.py` pone a esta ronda.
El detector marca sospechas; cada marca hay que leerla. Aqui se leen, y la que se puede
comprobar se comprueba con codigo.

  [T2] r8e_lib.py L164: `n` calculado en L160 y SOBRESCRITO con 0.5
       Es el bucle del modo 'epoca' cuando el bloque cruza MAS DE UNA frontera de ventana
       de golpe: el primer paso usa `N_obs` de la epoca del padre (`n = max(nobs_sp, 0.5)`)
       y los pasos siguientes corresponden a epocas INTERMEDIAS VACIAS, cuyo `N_obs` es 0 y
       se acota por abajo a 0,5 para que `ln` exista. NO es un payoff cableado. Aqui se
       CUENTA cuantas veces se ejecuta ese camino: si es 0, la marca es inocua por partida
       doble (el codigo ni siquiera corre).

  [T3] r8e_a3_lema9.py L118-119: `r[2] == r[2]`, `r[3] == r[3]`
       Es el modismo de descarte de NaN (`x != x` sólo para NaN), no una comparación
       tautológica: filtra las semillas en que no hubo ningun honesto rojo y la media sale
       NaN. Se demuestra abajo que el modismo hace lo que se dice.

Criterio alpha: el conteo del camino T2 se hace a varios alpha.
"""
import math
from r8e_lib import DAGW, MezclaPeso, PesoCfg
from r8c_sim import Mundo
from r8d_a1_menu import K, MP


class DAGcuenta(DAGW):
    """Cuenta cuantas veces el modo 'epoca' cruza MAS DE UNA frontera (el camino T2)."""

    def __init__(self, *a, **kw):
        super().__init__(*a, **kw)
        self.n_multipaso = 0
        self.n_unipaso = 0

    def _retarget(self, sp, n_nuevos_azules):
        cfg = self.wcfg
        if cfg.W is not None and cfg.modo == "epoca":
            sp_de_sp = self.gd[sp].sp
            e_new = int(self.B[sp].t // cfg.W)
            e_sp = 0 if sp_de_sp is None else int(self.B[sp_de_sp].t // cfg.W)
            if e_new - e_sp > 1:
                self.n_multipaso += 1
            elif e_new - e_sp == 1:
                self.n_unipaso += 1
        return super()._retarget(sp, n_nuevos_azules)


class MundoCuenta(MezclaPeso, Mundo):
    def _fabrica(self, **kw):
        d = DAGcuenta(wcfg=self.wcfg, **kw)
        self.ultimo = d
        return d


if __name__ == "__main__":
    print("=== Z · lectura de las marcas de AUDITA_SCRIPTS.py ===\n")
    print("[T2] r8e_lib.py L164 — ¿se ejecuta el camino de MAS DE UNA frontera de golpe?")
    print(f"{'W (s)':>7} {'alpha':>6} | {'cruces de 1 frontera':>21} "
          f"{'cruces de >1 (camino T2)':>26}")
    tot_multi = 0
    for W in (20.0, 80.0, 3083.0):
        for alpha in (0.0, 0.25, 0.40):
            uni = mul = 0
            for s in range(1, 9):
                m = MundoCuenta(alpha, 300.0, s, k=K, mp=MP, u3_mode="dynamic",
                                wcfg=PesoCfg(W=W, gamma=0.25, modo="epoca"))
                d, t = m.corre({})
                uni += d.n_unipaso; mul += d.n_multipaso
            tot_multi += mul
            print(f"{W:>7.0f} {alpha:>6.2f} | {uni:>21} {mul:>26}")
    print(f"\n  -> el camino marcado por T2 se ejecuta {tot_multi} veces en total.")
    print("     Si es 0, la marca es doblemente inocua: ni es un payoff cableado ni corre.\n")

    print("[T3] r8e_a3_lema9.py L118-119 — `x == x` es el descarte de NaN, no tautologia:")
    for v in (1.0, float("nan"), 0.0, float("inf")):
        print(f"     v={v!r:>6}  ->  (v == v) = {v == v}   math.isnan(v) = {math.isnan(v)}")
    print("     El filtro `[r for r in rs if r[2] == r[2]]` descarta EXACTAMENTE los NaN.")
