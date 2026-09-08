#!/usr/bin/env python3
"""
d8_a4c_rachas.py — A4 (2) y (3), version barata y dirigida.

(2) RETENCION HASTA `S_max`. ¿Puede el atacante fabricar un bloque con `slot >= T_j`,
    retenerlo y soltarlo justo antes de que `S_max` expire, para ser EL ancla? Se barre el
    retraso `r` desde 0 hasta `S_max = 150 s` y se cuenta cuantas anclas DISTINTAS aparecen
    (`m`) y cuantas son del ATACANTE (`nA`).

(3) EPOCAS CONSECUTIVAS. El steering `g = c_m/sqrt(alpha*lambda*I)` supone epocas
    INDEPENDIENTES. Se recorren umbrales `T_j` separados `paso` segundos y se mide (a) cuantas
    epocas captura el atacante (el ancla es un bloque suyo) y (b) la RACHA maxima de epocas
    consecutivas capturadas, con y sin ataque dirigido.

Barato por construccion: pocas estrategias (una politica global por corrida) y MUCHOS
umbrales, que es lo contrario de A4/A4b. Criterio alpha: fila alpha = 0 (0 capturas).
"""
import sys
import time

sys.path.insert(0, "/home/katana/zeo/ZEROX/research/scripts/d9-ronda8f")
from r8f_lib import Mundo, perfil, ancla_slot_T, K, MP                    # noqa: E402

SEMS = list(range(1, 13))
ALPHAS = [0.0, 0.10, 0.25, 0.33, 0.40]
POLS = ["tips", "sp", ("retro", 1), ("retro", 2), ("retro", 4), ("retro", 8), ("retro", 16)]
RETRASOS = [0.0, 4.0, 12.0, 40.0, 150.0]        # hasta S_max (R-FIN-1a)
HOR = 900.0
PASO = 20
INI, FIN = 80, 820


def corridas(alpha, sem, con_retraso):
    """Una corrida por (politica, retraso). Devuelve la lista de perfiles."""
    mundo = Mundo(alpha, HOR, sem, k=K, mp=MP, u3_mode="dynamic")
    idx = [i for i, (t, q, *_) in enumerate(mundo.ev) if q == "a"]
    ests = [{}]
    rs = RETRASOS if con_retraso else [0.0]
    for pol in POLS:
        for r in rs:
            ests.append({i: (r, pol) for i in idx})
    ests.append({i: (None, "tips") for i in idx})       # retencion total
    out = []
    for e in ests:
        d, tip = mundo.corre(e, copias=14)
        out.append((d, perfil(d, tip, gran=1.0)))
    return out, len(ests)


def mide(alpha, sem, con_retraso):
    corr, nest = corridas(alpha, sem, con_retraso)
    Ss = list(range(INI, FIN, PASO))
    menus = {S: set() for S in Ss}
    nA = {S: 0 for S in Ss}
    capt = {S: False for S in Ss}
    base = {}
    for j, (d, pf) in enumerate(corr):
        for S in Ss:
            s, i = ancla_slot_T(pf, S)
            if s is None:
                continue
            menus[S].add(s)
            es_a = d.B[pf[i][3]].creator == "a"
            if es_a:
                nA[S] += 1
                capt[S] = True
            if j == 0:
                base[S] = es_a
    ms = [len(menus[S]) for S in Ss if menus[S]]
    seq_b = [base.get(S, False) for S in Ss]
    seq_c = [capt[S] for S in Ss]

    def rmax(v):
        r = mx = 0
        for x in v:
            r = r + 1 if x else 0
            mx = max(mx, r)
        return mx
    return (sum(ms) / len(ms), max(ms), sum(nA.values()), nest, len(Ss),
            sum(seq_b), rmax(seq_b), sum(seq_c), rmax(seq_c))


if __name__ == "__main__":
    print("=== A4c · retencion hasta S_max, y rachas de epocas consecutivas ===")
    print(f"k={K}, mp={MP}, lambda=1, Delta=4, u3=dynamic, copias=14, horizonte {HOR:.0f} s, "
          f"{len(SEMS)} semillas, umbrales T_j cada {PASO} s de {INI} a {FIN} "
          f"({len(range(INI, FIN, PASO))} epocas por corrida).")
    print("Retrasos barridos: " + ", ".join(f"{r:.0f}" for r in RETRASOS) +
          " s (S_max = 150 s, R-FIN-1a) + retencion total.\n")
    t0 = time.time()
    for con_retraso in (False, True):
        print(f"--- {'CON retraso/retencion' if con_retraso else 'SIN retraso (control)'} ---")
        print(f"{'alpha':>6} | {'m medio':>8} {'m max':>6} {'nA':>7} {'estrat':>7} | "
              f"{'capt. sin dirigir':>18} {'racha':>6} | {'capt. dirigidas':>16} "
              f"{'racha':>6} {'de':>6}")
        for alpha in ALPHAS:
            rs = [mide(alpha, s, con_retraso) for s in SEMS]
            n = len(rs)
            print(f"{alpha:>6.2f} | {sum(r[0] for r in rs)/n:>8.3f} "
                  f"{max(r[1] for r in rs):>6} {sum(r[2] for r in rs):>7} "
                  f"{rs[0][3]:>7} | {sum(r[5] for r in rs):>18} "
                  f"{max(r[6] for r in rs):>6} | {sum(r[7] for r in rs):>16} "
                  f"{max(r[8] for r in rs):>6} {sum(r[4] for r in rs):>6}")
        print(f"   [{time.time()-t0:.0f} s]\n")
