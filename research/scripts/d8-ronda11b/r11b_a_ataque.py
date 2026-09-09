#!/usr/bin/env python3
"""
r11b_a_ataque.py — PUNTO A · el eclipse cuantificado en NUESTRO diseno, tres variantes.

CONTROL POSITIVO (metodo, regla 4), antes de medir nada nuevo: se reproduce con el
instrumento heredado (`d8-ronda8/d8_a3_smax.MundoEclipse`) la fila de D8 A3b
`E = 200 s, alpha = 0, S_max = 150 s -> 0,5460` (global) y el `0,77` en REGIMEN (segunda
mitad del horizonte) que la auditoria 7 §A3b declaro como el numero bueno.

Despues, con `MundoVictima`, las tres variantes del encargo:
  (i)   'pot'     el atacante RETIENE el PoT.
  (ii)  'filtro'  el PoT pasa, los bloques honestos se filtran (pasa la fraccion `paso`).
  (iii) 'retraso' el PoT pasa, todo llega con `E` s de retraso.

Para cada una: cuantos bloques hace la victima, cuantos son INVALIDOS por R-FIN-1a/S_max,
cuantos quedan fuera del blueset publico (robados de hecho), y que tasa observa.

Criterio alpha: todas las tablas llevan `alpha = 0` (el eclipse NO necesita espacio) y
`alpha = 0,33`. Cobertura: se imprime `n_V`; con `n_V = 0` la fila no dice nada.
"""
import math
import sys
import time

sys.path.insert(0, "/home/katana/zeo/ZEROX/research/scripts/d8-ronda11b")
from r11b_lib import (MundoVictima, LAMBDA, DELTA, K, MP, S_MAX)     # noqa: E402

sys.path.insert(0, "/home/katana/zeo/ZEROX/research/scripts/d8-ronda8")
from d8_a3_smax import MundoEclipse                                  # noqa: E402

SEMS = list(range(1, 13))
HOR = 900.0
SMAXES = [4, 20, 30, 150]
ALPHAS = [0.0, 0.10, 0.33]
FVS = [0.01, 0.05, 0.09, 0.20]


def control_positivo():
    print("--- CONTROL POSITIVO: reproducir D8 A3b (M2), E=200 s, f=5 %, 12 semillas ---")
    print("    esperado (salida_a3b.txt): alpha=0 -> S=4 0,8218  S=20 0,6513  S=30 0,5920  "
          "S=150 0,5460")
    for alpha in (0.0, 0.25):
        tot = {S: 0 for S in SMAXES}
        totr = {S: 0 for S in SMAXES}
        n = nr = 0
        for sem in SEMS:
            m = MundoEclipse(alpha, HOR, sem, k=K, mp=MP, u3_mode="dynamic")
            gs, nc = m.corre_ecl(200.0, sem=sem)
            n += nc
            for S in SMAXES:
                tot[S] += sum(1 for x in gs if x > S)
            # regimen = segunda mitad del horizonte. `corre_ecl` no devuelve los instantes,
            # asi que se usa la mitad final de la SECUENCIA de bloques de C, que en un
            # proceso de Poisson homogeneo es la mitad final del tiempo salvo O(sqrt(n)).
            mitad = gs[len(gs) // 2:]
            nr += len(mitad)
            for S in SMAXES:
                totr[S] += sum(1 for x in mitad if x > S)
        print(f"    alpha={alpha:.2f} GLOBAL  | " +
              "  ".join(f"S={S}: {tot[S]/max(n,1):.4f}" for S in SMAXES) + f" | n_C={n}")
        print(f"    alpha={alpha:.2f} REGIMEN | " +
              "  ".join(f"S={S}: {totr[S]/max(nr,1):.4f}" for S in SMAXES) + f" | n_C={nr}")


def cerrada_invalidos(tasa, s_max):
    """Forma cerrada de D8 A3b (M3): un nodo que solo puede colgar de bloques que llegan a
    tasa `tasa` tiene huecos Exp(tasa); P(invalido) = P(hueco > s_max) = exp(-tasa*s_max)."""
    return math.exp(-tasa * s_max)


def tabla_variante(modo, param, valores, alphas=ALPHAS, f_v=0.05, t_ecl=300.0,
                   t_reg=600.0):
    """Tabla por variante. Dos ventanas: [t_ecl, HOR] (todo el eclipse, con transitorio) y
    REGIMEN [t_reg, HOR] (ya saturado). `rojo_V` = fraccion de bloques de `V` creados en la
    ventana que NO estan en el blueset de la vista publica final: los que el atacante le roba
    de hecho, aunque sean validos."""
    print(f"\n--- variante '{modo}' · f_v = {f_v:.2f} · eclipse desde t = {t_ecl:.0f} s "
          f"· regimen desde t = {t_reg:.0f} s ---")
    print(f"{param:>9} {'alpha':>6} | {'n_ecl':>6} " +
          " ".join(f"{'inv S='+str(S):>10}" for S in SMAXES) +
          f" | {'n_reg':>6} " + " ".join(f"{'reg S='+str(S):>10}" for S in SMAXES) +
          f" | {'tasa_obs':>9} {'rojo_V':>7} | " +
          " ".join(f"{'cerr S='+str(S):>11}" for S in SMAXES))
    filas = []
    for v in valores:
        for alpha in alphas:
            acc = {S: 0 for S in SMAXES}
            accr = {S: 0 for S in SMAXES}
            nve = nvr = 0
            n_lleg = 0
            n_rojo = n_tot_rojo = 0
            for sem in SEMS:
                m = MundoVictima(alpha, HOR, sem, k=K, mp=MP, u3_mode="dynamic")
                kw = dict(f_v=f_v, t_ecl=t_ecl, sem=sem)
                if modo == "filtro":
                    kw["paso"] = v
                elif modo == "retraso":
                    kw["E"] = v
                d, tip, _ = m.corre_victima(modo, **kw)
                az = d.blueset(tip)
                for t, gp, bid in zip(m.t_V, m.gaps_V, m.ids_V):
                    if t >= t_ecl:
                        nve += 1
                        for S in SMAXES:
                            if gp > S:
                                acc[S] += 1
                    if t >= t_reg:
                        nvr += 1
                        n_tot_rojo += 1
                        if bid not in az:
                            n_rojo += 1
                        for S in SMAXES:
                            if gp > S:
                                accr[S] += 1
                # se recortan a HOR: las llegadas posteriores al horizonte NO tienen
                # detras un intervalo simulado completo (error propio, corregido).
                n_lleg += sum(1 for x in m.llegadas_V if t_reg <= x <= HOR)
            dur = (HOR - t_reg) * len(SEMS)
            tasa = n_lleg / dur
            # tasa a la que `V` puede ENCADENAR: su propio espacio mas lo que le entra
            tasa_enc = f_v * LAMBDA + tasa
            print(f"{v:>9} {alpha:>6.2f} | {nve:>6} " +
                  " ".join(f"{acc[S]/max(nve,1):>10.4f}" for S in SMAXES) +
                  f" | {nvr:>6} " +
                  " ".join(f"{accr[S]/max(nvr,1):>10.4f}" for S in SMAXES) +
                  f" | {tasa:>9.4f} {n_rojo/max(n_tot_rojo,1):>7.4f} | " +
                  " ".join(f"{cerrada_invalidos(tasa_enc, S):>11.5f}" for S in SMAXES))
            filas.append((v, alpha, nvr, {S: accr[S] / max(nvr, 1) for S in SMAXES}, tasa,
                          n_rojo / max(n_tot_rojo, 1)))
    return filas


if __name__ == "__main__":
    t0 = time.time()
    print("=== A · el eclipse en nuestro diseno, tres variantes ===")
    print(f"k={K}, mp={MP}, lambda={LAMBDA}, Delta={DELTA}, horizonte {HOR:.0f} s, "
          f"{len(SEMS)} semillas, sigma=1 s, S_max={S_MAX:.0f} s.\n")
    control_positivo()

    print("\n=== (i) 'pot' · el atacante RETIENE el PoT ===")
    print("Hipotesis declarada: la victima NO corre timelord propio (granjero = PC con SSD;")
    print("el timelord lo opera el proyecto). Sin PoT no hay slot que justificar -> 0 bloques.")
    for alpha in ALPHAS:
        for f_v in FVS:
            nv_pre = nv_post = 0
            for sem in SEMS:
                m = MundoVictima(alpha, HOR, sem, k=K, mp=MP, u3_mode="dynamic")
                m.corre_victima("pot", f_v=f_v, t_ecl=300.0, sem=sem)
                nv_pre += sum(1 for t in m.t_V if t < 300.0)
                nv_post += sum(1 for t in m.t_V if t >= 300.0)
            print(f"    alpha={alpha:.2f} f_v={f_v:.2f} | bloques antes del eclipse {nv_pre:>5} "
                  f"| despues {nv_post:>3} | llegadas a su vista tras el eclipse: 0")

    print("\n=== (ii) 'filtro' · el PoT pasa, los bloques honestos se filtran ===")
    tabla_variante("filtro", "paso", [1.0, 0.33, 0.10, 0.0])

    print("\n=== (iii) 'retraso' · el PoT pasa, todo llega con E s de retraso ===")
    tabla_variante("retraso", "E", [0.0, 20.0, 60.0, 200.0])

    print("\n--- (ii) y la forma cerrada P(invalido) = exp(-(f_v + paso*(1-f_v))*S_max) ---")
    print(f"{'f_v':>6} {'paso':>6} | " + " ".join(f"{'S='+str(S):>11}" for S in SMAXES))
    for f_v in FVS:
        for paso in (0.0, 0.10, 0.33):
            tasa = f_v * LAMBDA + paso * (1 - f_v) * LAMBDA
            print(f"{f_v:>6.2f} {paso:>6.2f} | " +
                  " ".join(f"{cerrada_invalidos(tasa, S):>11.5f}" for S in SMAXES))

    print(f"\n[{time.time()-t0:.0f} s]")
