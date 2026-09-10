#!/usr/bin/env python3
"""
d14_zerox.py — Punto 3 y 4: rejilla ZEROX completa (version corregida).

Correccion respecto del primer intento (ver informe, "Errores propios"): el margen del baseline
publicado `3k/((1-alpha)lambda)` se cuenta en BLOQUES HONESTOS, no en blue_score (el blue_score
incluye azules del atacante y a alpha=0,40 daba ~88 s en vez de 150 s). Aqui:

  · k*(alpha, Delta) = punto fijo del k adaptativo (min k con k-cluster >= 50 % del DAG de ZEROX,
    regenerando el DAG con el color k; converge en un paso).
  · M_baseline = 3k = 90 (cota estructural del Lema 10, independiente de eps).
  · M_ada(eps) = max(3k*, m(alpha, eps)) con m = ceil(ln(eps)/ln(alpha/(1-alpha))) (ruina del
    jugador; es la probabilidad de que el atacante alcance alguna vez desde un deficit de m).
  · T = tiempo de calendario hasta el M-esimo bloque HONESTO posterior a B* (B* = primer honesto
    con t >= 200 s). El suelo teorico es M/((1-alpha)lambda).

lambda = 1, T = 400 s, 12 semillas. Salida cruda: salida_zerox_crudo.txt
"""
import math
import multiprocessing as mp
import os
import sys

_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, _DIR)

ALPHAS = [0.10, 0.25, 0.33, 0.40]
DELTAS = [1.0, 4.0, 16.0, 20.0]
SEMILLAS = [11, 23, 37, 41, 59, 67, 73, 89, 97, 101, 113, 127]
EPSILONS = [0.05, 1e-3, 1e-6, 1e-12]
T = 400.0
T_TX = 200.0
K_BASE = 30


def margen_paseo(alpha, eps):
    if alpha <= 0:
        return 0
    return int(math.ceil(math.log(eps) / math.log(alpha / (1 - alpha))))


def _k_estrella(d, kmax=40):
    """Devuelve (k*_hon, k*_all).
    k*_hon = minimo k cuyo k-cluster es MAYORITARIAMENTE HONESTO (>= 50 % de sus bloques) y
    cubre >= 50 % de los bloques honestos. Es el criterio con relevancia de seguridad: el
    cluster "mayoritario" a secas puede ser la cadena del atacante (a alpha alto, k*_all = 0
    espurio; ver informe, "Errores propios"). k*_all = minimo k con cobertura global >= 50 %."""
    from d14_lib import replay_gd, cobertura_replay, GEN
    bl = [(bid, d.B[bid].parents, d.B[bid].t, d.B[bid].creator) for bid in d.B]
    H = {b[0] for b in bl if b[3] == "h"}
    k_hon = None
    for k in range(kmax + 1):
        dd, tip = replay_gd(bl, k)
        blue = dd.blueset(tip) - {GEN}
        bh = blue & H
        if len(bh) >= 0.5 * len(blue) and len(bh) >= 0.5 * len(H):
            k_hon = k
            break
    k_all = None
    for k in range(kmax + 1):
        if cobertura_replay(bl, k) >= 0.5:
            k_all = k
            break
    return k_hon, k_all


def _tarea(args):
    alpha, delta, seed = args
    import d14_lib  # noqa: F401
    import r8c_sim
    from r8c_sim import Mundo

    r8c_sim.LAMBDA = 1.0
    r8c_sim.DELTA = delta

    # ---- k* adaptativo por punto fijo
    k = K_BASE
    d = None
    for _ in range(3):
        mk = Mundo(alpha=alpha, T=T, seed=seed, k=k)
        d, _ = mk.corre()
        kn, _ = _k_estrella(d)
        if kn is None or kn == k:
            k = k if kn is None else kn
            break
        k = kn
    kstar = k
    kstar_all = _k_estrella(d)[1]

    # ---- calendario honesto (identico para baseline y adaptativo: depende de lambda, alpha, seed)
    m = Mundo(alpha=alpha, T=T, seed=seed)
    honestos = [e[0] for e in m.ev if e[1] == "h"]
    idx_tx = next((i for i, t in enumerate(honestos) if t >= T_TX), 0)
    t_tx = honestos[idx_tx]

    def tiempo_a_M(M):
        if M <= 0:
            return 0.0
        j = idx_tx + M
        if j >= len(honestos):
            return None
        return honestos[j] - t_tx

    t_base = tiempo_a_M(3 * K_BASE)
    m_eps = {e: margen_paseo(alpha, e) for e in EPSILONS}
    t_ada = {e: tiempo_a_M(max(3 * kstar, m_eps[e])) for e in EPSILONS}
    return {
        "alpha": alpha, "delta": delta, "seed": seed, "kstar": kstar,
        "kstar_all": kstar_all,
        "n": len(d.B), "t_tx": t_tx, "t_base": t_base,
        "m_eps": m_eps, "t_ada": t_ada,
        "suelo_base": 3 * K_BASE / ((1 - alpha) * 1.0),
        "suelo_ada": {e: max(3 * kstar, m_eps[e]) / ((1 - alpha) * 1.0) for e in EPSILONS},
    }


def main():
    tareas = [(a, dd, s) for a in ALPHAS for dd in DELTAS for s in SEMILLAS]
    with mp.Pool(processes=min(16, os.cpu_count() or 4)) as pool:
        res = pool.map(_tarea, tareas, chunksize=1)

    with open(os.path.join(_DIR, "salida_zerox_crudo.txt"), "w") as f:
        f.write("alpha delta seed kstar kstar_all n t_tx t_base " +
                " ".join(f"m{e} t{e} suelo{e}" for e in EPSILONS) + " suelo_base\n")
        for r in res:
            f.write(f"{r['alpha']} {r['delta']} {r['seed']} {r['kstar']} {r['kstar_all']} {r['n']} "
                    f"{r['t_tx']:.4f} {r['t_base']:.4f} ")
            for e in EPSILONS:
                f.write(f"{r['m_eps'][e]} {r['t_ada'][e]} {r['suelo_ada'][e]:.4f} ")
            f.write(f"{r['suelo_base']:.4f}\n")

    def med(v):
        v = [x for x in v if x is not None]
        return (sum(v) / len(v), min(v)) if v else (float("nan"), float("nan"))

    print("=" * 112)
    print("ZEROX — lambda=1, T=400 s, 12 semillas. Baseline publicado: 3k/((1-a)l) = 100-134 s (a=0,10..0,33)")
    print("T = tiempo hasta el M-esimo bloque honesto tras B*; M_ada = max(3k*, m(a,eps))")
    print("=" * 112)
    print(f"{'alpha':>6} {'Delta':>6} | {'k*h':>5} {'k*a':>5} | {'base med':>8} {'min':>6} | "
          + " ".join(f"{'ada'+str(e):>8} {'min':>6}" for e in EPSILONS))
    for a in ALPHAS:
        for dd in DELTAS:
            filas = [r for r in res if r["alpha"] == a and r["delta"] == dd]
            ks = [r["kstar"] for r in filas]
            ka = [r["kstar_all"] for r in filas]
            tb_m, tb_mn = med([r["t_base"] for r in filas])
            celdas = []
            for e in EPSILONS:
                mm, mn = med([r["t_ada"][e] for r in filas])
                celdas.append(f"{mm:>8.2f} {mn:>6.2f}")
            print(f"{a:>6.2f} {dd:>6.1f} | {sum(ks)/len(ks):>5.2f} {sum(ka)/len(ka):>5.2f} | {tb_m:>8.2f} {tb_mn:>6.2f} | "
                  + " ".join(celdas))
        print("-" * 112)

    print()
    print("=" * 112)
    print("RESUMEN por (alpha, eps): latencia media/minima sobre Delta y semillas (medida y suelo)")
    print("=" * 112)
    print(f"{'alpha':>6} | " + " ".join(f"{'eps='+str(e):>17}" for e in EPSILONS)
          + f" | {'baseline med/min':>18} {'suelo base':>11}")
    for a in ALPHAS:
        celdas = []
        for e in EPSILONS:
            vals = [r["t_ada"][e] for r in res if r["alpha"] == a]
            suelos = [r["suelo_ada"][e] for r in res if r["alpha"] == a]
            mm, mn = med(vals)
            celdas.append(f"{mm:>7.2f}/{mn:<5.2f}({sum(suelos)/len(suelos):>5.1f})")
        vals_b = [r["t_base"] for r in res if r["alpha"] == a]
        mb, mnb = med(vals_b)
        print(f"{a:>6.2f} | " + " ".join(f"{c:>17}" for c in celdas)
              + f" | {mb:>8.2f}/{mnb:<7.2f} {3*K_BASE/((1-a)*1.0):>11.1f}")

    print()
    print("=" * 112)
    print("k* por (alpha, Delta): k*_hon (criterio de seguridad) y k*_all (global)")
    print("=" * 112)
    for a in ALPHAS:
        fila = []
        for dd in DELTAS:
            ks = [r["kstar"] for r in res if r["alpha"] == a and r["delta"] == dd]
            ka = [r["kstar_all"] for r in res if r["alpha"] == a and r["delta"] == dd]
            fila.append(f"D={dd:>4}: hon {sum(ks)/len(ks):>4.2f} [{min(ks)},{max(ks)}] all {sum(ka)/len(ka):>4.2f} [{min(ka)},{max(ka)}]")
        print(f"alpha={a:>4.2f} | " + " | ".join(fila))


if __name__ == "__main__":
    main()
