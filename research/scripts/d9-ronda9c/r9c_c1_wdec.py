#!/usr/bin/env python3
"""
r9c_c1_wdec.py — punto C: la ventana de decision `W_dec` del ancla, MEDIDA.

Pregunta: hasta cuando despues de `T_j` puede el atacante todavia CAMBIAR cual sera
`I_j` (R-FIN-1: menor `blue_work` con `slot >= T_j` en la cadena seleccionada)?

Dos vias, medidas por separado y luego unidas:

  (i)  RETENCION/LIBERACION de candidatos propios. El atacante retiene todos los bloques
       que crea en `[T_j, T_j+d]` (su reserva de opciones) y en el instante `T_j+d`
       LIBERA exactamente uno (los demas se pierden). Desde `T_j+d` publica normal.
       Acotada por R-FIN-1a: un bloque retenido `d` segundos solo puede ser extendido por
       un bloque cuyo slot este a `<= S_max` de el.
  (ii) REORGANIZACION por carrera privada. El atacante encadena en privado desde
       `T_j - P` (P in {0,30,90}) y suelta la cadena entera en `T_j+d`. Si gana la
       cadena seleccionada, el primer bloque con `slot >= T_j` es OTRO.
       Acotada por la carrera con ventaja `k`: `J* = k*alpha/(1-2alpha)` bloques,
       `T* = J*/(alpha*lambda) = k/((1-2alpha)*lambda)` segundos.

`W_dec(mundo) = max{ d : |menu(d)| >= 2 }`, con `menu(d)` el conjunto de anclas
alcanzables por una decision tomada en `T_j+d`. `-1` = el ancla nunca cambia.

Adversario del paper (`phantom-ghostdag.txt` L1024-1027): sin retardo.
12 semillas literales. Fila `alpha = 0` obligatoria.
"""
import sys, os, time, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from r9c_lib import MundoR9, COB, SEMILLAS, eventos_atacante

TJ = 200.0
HOR = 800.0
ALPHAS = [0.0, 0.10, 0.25, 0.33, 0.40]
GRID = [0, 10, 20, 30, 45, 60, 80, 100, 120, 150, 175, 200, 250, 300]
TOPE_POOL = 25          # cota de coste; se cuenta cuantas veces muerde
COB2 = {"pool_recortado": 0, "pool_total": 0, "sin_ancla": 0, "runs": 0}


def submuestrea(xs, n):
    if len(xs) <= n:
        return xs
    COB2["pool_recortado"] += 1
    paso = len(xs) / n
    return [xs[int(i * paso)] for i in range(n)]


def mide(a, s, smax):
    mu = MundoR9(a, HOR, s, s_max=smax)
    d0, t0 = mu.corre(); COB2["runs"] += 1
    base, tbase = mu.ancla(d0, t0, TJ)
    if base is None:
        COB2["sin_ancla"] += 1
    res = {"base": base, "t_base": tbase, "i": {}, "ii": {}}
    for d in GRID:
        trel = TJ + d
        # ---- via (i) retencion/liberacion ----
        pool = submuestrea(eventos_atacante(mu, TJ, trel), TOPE_POOL)
        COB2["pool_total"] += len(pool)
        ret = {i: (None, "tips") for i in pool}
        menu = set()
        dd, tt = mu.corre(ret); COB2["runs"] += 1          # liberar ninguno
        sd, _ = mu.ancla(dd, tt, TJ)
        menu.add(sd)
        for X in pool:
            est = dict(ret)
            est[X] = (trel - mu.ev[X][0], "tips")
            dd, tt = mu.corre(est); COB2["runs"] += 1
            sd, _ = mu.ancla(dd, tt, TJ)
            menu.add(sd)
        res["i"][d] = len(menu | {base})
        # ---- via (ii) carrera privada ----
        menu2 = {base}
        for P in (0, 30, 90):
            idx = eventos_atacante(mu, TJ - P, trel)
            if not idx:
                continue
            est = {i: (max(0.0, trel - mu.ev[i][0]), "sp") for i in idx}
            dd, tt = mu.corre(est); COB2["runs"] += 1
            sd, _ = mu.ancla(dd, tt, TJ)
            menu2.add(sd)
        res["ii"][d] = len(menu2)
    return res


def wdec(dic):
    ds = [d for d in GRID if dic[d] >= 2]
    return max(ds) if ds else -1


if __name__ == "__main__":
    t0 = time.time()
    out = {}
    print(f"# TJ={TJ}  HOR={HOR}  GRID={GRID}  semillas={SEMILLAS}")
    for smax in (150, 20):
        print()
        print("=" * 100)
        print(f"S_max = {smax} s")
        print(f"{'alpha':>6} | {'W_dec(i) retencion':>28} | {'W_dec(ii) reorg':>24} | "
              f"{'W_dec union':>22} | {'T* teorico':>10}")
        print(f"{'':>6} | {'mediana  p90  max  #cambia':>28} | {'mediana  p90  max':>24} | "
              f"{'mediana  p90  max':>22} | {'k/((1-2a)L)':>10}")
        for a in ALPHAS:
            wi, wii, wu = [], [], []
            for s in SEMILLAS:
                r = mide(a, s, smax)
                out[f"{smax}_{a}_{s}"] = r
                x, y = wdec(r["i"]), wdec(r["ii"])
                wi.append(x); wii.append(y); wu.append(max(x, y))
            def q(v, p):
                v = sorted(v); return v[min(len(v) - 1, int(p * len(v)))]
            Tteo = 30.0 / (1 - 2 * a) if a < 0.5 else float("inf")
            ncam = sum(1 for x in wu if x >= 0)
            print(f"{a:>6.2f} | {q(wi,.5):>7} {q(wi,.9):>4} {max(wi):>4} {ncam:>6}/12{'':>4} | "
                  f"{q(wii,.5):>7} {q(wii,.9):>4} {max(wii):>4}{'':>5} | "
                  f"{q(wu,.5):>7} {q(wu,.9):>4} {max(wu):>4}{'':>3} | {Tteo:>10.0f}")
    print()
    print("Cobertura de rama:", {**COB, **COB2})
    print(f"tiempo {time.time()-t0:.0f} s")
    with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "wdec.json"), "w") as f:
        json.dump({"grid": GRID, "tj": TJ, "hor": HOR, "datos": out}, f)
