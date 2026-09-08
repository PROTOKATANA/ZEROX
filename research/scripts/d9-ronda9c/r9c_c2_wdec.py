#!/usr/bin/env python3
"""
r9c_c2_wdec.py — punto C, SEGUNDA VERSION. Corrige un error MIO en `r9c_c1_wdec.py`.

ERROR DE r9c_c1 (declarado, regla 10): el menu se calculaba como
    `len(menu | {base})`, con `base` = corrida SIN retencion ninguna.
Pero `base` y las corridas del menu difieren en una decision tomada en `T_j` (retener el
lote), no en `T_j + d`. El contraste correcto exige PREFIJO COMUN: todas las ramas retienen
el lote y solo se diferencian en QUE se libera EN `T_j + d`. Con el prefijo contaminado,
`W_dec` saturaba la rejilla (300 s) para todo alpha >= 0,25, que es justo lo que hay que
medir bien.

Aqui:
  menu_i(d)  = { ancla(liberar NADA en T_j+d) } U { ancla(liberar SOLO X en T_j+d) : X in lote }
               — prefijo comun: TODO el lote retenido desde su creacion.
  menu_ii(d) = por cada P (inicio de la cadena privada en T_j-P), el par
               { ancla(soltar la privada en T_j+d), ancla(no soltarla nunca) }.
               Prefijo comun: la privada se construye igual en las dos ramas.
  W_dec = max{ d : |menu(d)| >= 2 }.  -1 = el ancla nunca cambia por una decision en T_j+d.

Se guarda ADEMAS quien es cada ancla (creador y slot) para diagnosticar el mecanismo.
Adversario del paper (phantom-ghostdag.txt L1024-1027). 12 semillas literales. Fila alpha=0.
"""
import sys, os, time, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from r9c_lib import MundoR9, COB, SEMILLAS, eventos_atacante, slot_de

TJ = 200.0
HOR = 1200.0
ALPHAS = [0.0, 0.10, 0.25, 0.33, 0.40]
GRID = [0, 20, 45, 80, 120, 150, 200, 300, 450, 600]
TOPE = 15
COB2 = {"lote_recortado": 0, "lote_total": 0, "sin_ancla": 0, "runs": 0,
        "menu_i_ge2": 0, "menu_ii_ge2": 0, "ancla_atacante": 0, "ancla_honesta": 0}


def submuestrea(xs, n):
    if len(xs) <= n:
        return xs
    COB2["lote_recortado"] += 1
    paso = len(xs) / n
    return [xs[int(i * paso)] for i in range(n)]


def lee(mu, est):
    d, tip = mu.corre(est); COB2["runs"] += 1
    sd, t = mu.ancla(d, tip, TJ)
    if sd is None:
        COB2["sin_ancla"] += 1
        return None
    # quien es: se busca el bloque de la cadena con esa seed
    for b in d.selected_chain(tip):
        if d.B[b].seed == sd:
            COB2["ancla_atacante" if d.B[b].creator == "a" else "ancla_honesta"] += 1
            return (sd, round(t, 2), d.B[b].creator, slot_de(t))
    return (sd, round(t, 2), "?", slot_de(t))


def mide(a, s, smax):
    mu = MundoR9(a, HOR, s, s_max=smax)
    res = {"i": {}, "ii": {}, "anclas_i": {}, "anclas_ii": {}}
    for d in GRID:
        trel = TJ + d
        # ---- (i) retencion del lote, liberacion de UNO en T_j+d (prefijo comun) ----
        # CONSISTENCIA (2a correccion, ronda 9c): se retiene TODO el lote de la ventana,
        # no una submuestra. Si solo se retuviese una submuestra, los bloques del atacante
        # NO retenidos que cuelgan de los retenidos los sacarian a la luz antes de `trel`
        # (clausura de publicacion) y `W_dec` saldria inflado.
        todos_lote = eventos_atacante(mu, TJ, trel)
        lote = submuestrea(todos_lote, TOPE)
        COB2["lote_total"] += len(lote)
        ret = {i: (None, "tips") for i in todos_lote}
        menu = {lee(mu, ret)}
        for X in lote:
            e = dict(ret); e[X] = (trel - mu.ev[X][0], "tips")
            menu.add(lee(mu, e))
        menu.discard(None)
        res["i"][d] = len(menu)
        res["anclas_i"][d] = sorted(str(x) for x in menu)
        if len(menu) >= 2:
            COB2["menu_i_ge2"] += 1
        # ---- (ii) carrera privada: soltarla en T_j+d vs no soltarla nunca ----
        mejor, anclas = 1, []
        for P in (0, 30, 90):
            idx = eventos_atacante(mu, TJ - P, trel)
            if not idx:
                continue
            e1 = {i: (max(0.0, trel - mu.ev[i][0]), "sp") for i in idx}
            e2 = {i: (None, "sp") for i in idx}
            m2 = {lee(mu, e1), lee(mu, e2)}
            m2.discard(None)
            mejor = max(mejor, len(m2))
            anclas.append([P, sorted(str(x) for x in m2)])
        res["ii"][d] = mejor
        res["anclas_ii"][d] = anclas
        if mejor >= 2:
            COB2["menu_ii_ge2"] += 1
    return res


def wdec(dic):
    ds = [d for d in GRID if dic[d] >= 2]
    return max(ds) if ds else -1


def q(v, p):
    v = sorted(v); return v[min(len(v) - 1, int(p * len(v)))]


if __name__ == "__main__":
    t0 = time.time()
    out = {}
    print(f"# TJ={TJ}  HOR={HOR}  GRID={GRID}  TOPE_LOTE={TOPE}  semillas={SEMILLAS}")
    print("# PREFIJO COMUN: todas las ramas de un mismo `d` comparten todo lo anterior a T_j+d.")
    for smax in (150, 20):
        print()
        print("=" * 104)
        print(f"S_max = {smax} s")
        print(f"{'alpha':>6} | {'W_dec(i) liberar 1 de m':>26} | {'W_dec(ii) soltar privada':>26} | "
              f"{'W_dec union':>22} | {'T* carrera':>10}")
        print(f"{'':>6} | {'med  p90  max  #camb/12':>26} | {'med  p90  max  #camb/12':>26} | "
              f"{'med  p90  max':>22} | {'k/((1-2a))':>10}")
        for a in ALPHAS:
            wi, wii, wu = [], [], []
            for s in SEMILLAS:
                r = mide(a, s, smax)
                out[f"{smax}|{a}|{s}"] = r
                x, y = wdec(r["i"]), wdec(r["ii"])
                wi.append(x); wii.append(y); wu.append(max(x, y))
            Tt = 30.0 / (1 - 2 * a) if a < 0.5 else float("inf")
            print(f"{a:>6.2f} | {q(wi,.5):>4} {q(wi,.9):>4} {max(wi):>4} "
                  f"{sum(1 for v in wi if v>=0):>6}/12{'':>3} | "
                  f"{q(wii,.5):>4} {q(wii,.9):>4} {max(wii):>4} "
                  f"{sum(1 for v in wii if v>=0):>6}/12{'':>3} | "
                  f"{q(wu,.5):>6} {q(wu,.9):>4} {max(wu):>4}{'':>5} | {Tt:>10.0f}")
    print()
    print("# menu(d) medio por d (via i), S_max=150 — el `m` que ve el atacante si decide en T_j+d")
    print(f"{'alpha':>6} | " + "  ".join(f"{d:>5}" for d in GRID))
    for a in ALPHAS:
        fila = []
        for d in GRID:
            vs = [out[f"150|{a}|{s}"]["i"][d] for s in SEMILLAS]
            fila.append(sum(vs) / len(vs))
        print(f"{a:>6.2f} | " + "  ".join(f"{v:>5.2f}" for v in fila))
    print()
    print("Cobertura de rama:", {**COB, **COB2})
    print(f"tiempo {time.time()-t0:.0f} s")
    with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "wdec2.json"), "w") as f:
        json.dump({"grid": GRID, "tj": TJ, "hor": HOR, "datos": out}, f)
