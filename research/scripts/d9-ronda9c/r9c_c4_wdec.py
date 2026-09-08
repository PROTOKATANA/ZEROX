#!/usr/bin/env python3
"""
r9c_c4_wdec.py — punto C, TERCERA y definitiva version. Corrige DOS errores mios:

  (1) r9c_c1: prefijo contaminado (`menu | {base}` mezclaba una decision de `T_j` con una
      de `T_j+d`).  -> corregido en c2.
  (2) r9c_c2 (primera pasada): el atacante «retenia» un bloque y publicaba un HIJO suyo,
      lo que en la red real publica tambien al padre. Se anadio la CLAUSURA DE PUBLICACION
      a `MundoR9.corre` (`llega[ancestro] <- min(...)`). Con ella, c2 con retencion parcial
      medía en realidad el instante del primer descendiente publicado.
  (2b) c2 con retencion TOTAL de la ventana es consistente pero SOBRE-CORRIGE: el atacante
      tira todos sus bloques de la ventana, que no es su mejor estrategia.

Aqui la estrategia CONSISTENTE Y BARATA:
  · prefijo comun: los `m` candidatos `C` (bloques del atacante con slot >= T_j) se retienen
    desde su creacion; TODOS los demas bloques del atacante usan la politica `tips_pub`
    (cuelgan solo de bloques YA PUBLICADOS), de modo que ninguno delata a un candidato.
  · decision en `T_j + d`: liberar UNO de `C`, o ninguno.
  · menu(d) = { anclas alcanzables }.  W_dec = max{d : |menu(d)| >= 2}.

Adversario del paper (sin retardo). 12 semillas literales. Fila alpha = 0.
"""
import sys, os, time, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from r9c_lib import MundoR9, COB, SEMILLAS, eventos_atacante, slot_de

TJ, HOR = 200.0, 1000.0
ALPHAS = [0.0, 0.10, 0.25, 0.33, 0.40]
GRID = [0, 10, 20, 45, 80, 120, 150, 200, 300, 450]
TOPE = 10
COB2 = {"recortes": 0, "cand_total": 0, "sin_ancla": 0, "runs": 0,
        "menu_ge2": 0, "menu_ii_ge2": 0, "anc_atac": 0, "anc_hon": 0}


def sub(xs, n):
    if len(xs) <= n:
        return xs
    COB2["recortes"] += 1
    paso = len(xs) / n
    return [xs[int(i * paso)] for i in range(n)]


def lee(mu, est):
    d, tip = mu.corre(est); COB2["runs"] += 1
    sd, t = mu.ancla(d, tip, TJ)
    if sd is None:
        COB2["sin_ancla"] += 1
        return None
    for b in d.selected_chain(tip):
        if d.B[b].seed == sd:
            COB2["anc_atac" if d.B[b].creator == "a" else "anc_hon"] += 1
            return (sd, round(t, 2), d.B[b].creator)
    return (sd, round(t, 2), "?")


def mide(a, s, smax):
    mu = MundoR9(a, HOR, s, s_max=smax)
    res = {"i": {}, "ii": {}, "anclas": {}}
    todos_a = eventos_atacante(mu, 0.0, HOR)
    for d in GRID:
        trel = TJ + d
        C = sub(eventos_atacante(mu, TJ, trel), TOPE)
        COB2["cand_total"] += len(C)
        # prefijo: candidatos retenidos; el RESTO del atacante en `tips_pub`
        pref = {i: (0.0, "tips_pub") for i in todos_a}
        for i in C:
            pref[i] = (None, "tips")
        menu = {lee(mu, pref)}
        for X in C:
            e = dict(pref); e[X] = (trel - mu.ev[X][0], "tips")
            menu.add(lee(mu, e))
        menu.discard(None)
        res["i"][d] = len(menu)
        res["anclas"][d] = sorted(str(x) for x in menu)
        if len(menu) >= 2:
            COB2["menu_ge2"] += 1
        # (ii) carrera privada: soltarla en T_j+d  vs  no soltarla nunca (mismo prefijo)
        mejor = 1
        for P in (0, 30, 90):
            idx = eventos_atacante(mu, TJ - P, trel)
            if not idx:
                continue
            base = {i: (0.0, "tips_pub") for i in todos_a}
            e1 = dict(base); e2 = dict(base)
            for i in idx:
                e1[i] = (max(0.0, trel - mu.ev[i][0]), "sp")
                e2[i] = (None, "sp")
            m2 = {lee(mu, e1), lee(mu, e2)}
            m2.discard(None)
            mejor = max(mejor, len(m2))
        res["ii"][d] = mejor
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
    print(f"# TJ={TJ} HOR={HOR} GRID={GRID} TOPE={TOPE} semillas={SEMILLAS}")
    for smax in (150, 20):
        print()
        print("=" * 100)
        print(f"S_max = {smax} s")
        print(f"{'alpha':>6} | {'W_dec(i) liberar 1 de m':>25} | {'W_dec(ii) privada':>22} | "
              f"{'union':>18} | {'T* carrera':>10}")
        print(f"{'':>6} | {'med  p90  max  #camb/12':>25} | {'med  p90  max  #c/12':>22} | "
              f"{'med  p90  max':>18} | {'k/(1-2a)':>10}")
        for a in ALPHAS:
            wi, wii, wu = [], [], []
            for s in SEMILLAS:
                r = mide(a, s, smax)
                out[f"{smax}|{a}|{s}"] = r
                x, y = wdec(r["i"]), wdec(r["ii"])
                wi.append(x); wii.append(y); wu.append(max(x, y))
            Tt = 30.0 / (1 - 2 * a) if a < 0.5 else float("inf")
            print(f"{a:>6.2f} | {q(wi,.5):>4} {q(wi,.9):>4} {max(wi):>4} "
                  f"{sum(1 for v in wi if v>=0):>5}/12{'':>3} | "
                  f"{q(wii,.5):>4} {q(wii,.9):>4} {max(wii):>4} "
                  f"{sum(1 for v in wii if v>=0):>3}/12{'':>2} | "
                  f"{q(wu,.5):>5} {q(wu,.9):>4} {max(wu):>4}{'':>2} | {Tt:>10.0f}")
    print()
    print("# menu(d) medio (via i), S_max=150 — el `m` real si la decision se toma en T_j+d")
    print(f"{'alpha':>6} | " + "  ".join(f"{d:>5}" for d in GRID))
    for a in ALPHAS:
        print(f"{a:>6.2f} | " + "  ".join(
            f"{sum(out[f'150|{a}|{s}']['i'][d] for s in SEMILLAS)/len(SEMILLAS):>5.2f}"
            for d in GRID))
    print()
    print("Cobertura de rama:", {**COB, **COB2})
    print(f"tiempo {time.time()-t0:.0f} s")
    with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "wdec4.json"), "w") as f:
        json.dump({"grid": GRID, "tj": TJ, "hor": HOR, "datos": out}, f)
