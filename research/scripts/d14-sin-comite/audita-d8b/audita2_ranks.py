#!/usr/bin/env python3
r"""
audita2_ranks.py — Decisivo: rank del grupo del TIP HONESTO vs rank del ganador.

D14B midió k_view = min sobre subgrupos y un oráculo de honestidad del clúster. Ese
oráculo falla incluso en 'instant' (red pública): a α=0.25, Δ=16 da "sin ganador
honesto" en 6/12 semillas. La pregunta correcta es: el grupo que contiene el tip
honesto, ¿pasa la UMC antes que el grupo del atacante? Si k(att) < k(hon_tip) (o
k(hon_tip) = None), el cliente que sigue la regla selecciona la rama del atacante.

Salida: traza de casos + tabla agregada de `victorias_att` (rank atacante estricta-
mente menor y tip honesto fuera de su pasado) y `congelacion` (k del tip honesto
None hasta k=40).
"""
import math
import multiprocessing as mp
import os
import sys

_DIR = os.path.dirname(os.path.abspath(__file__))
D14K = os.path.normpath(os.path.join(_DIR, "..", "..", "d14-dagknight"))
D9C = os.path.normpath(os.path.join(_DIR, "..", "..", "d9-ronda8c"))
for p in (D14K, D9C):
    if p not in sys.path:
        sys.path.insert(0, p)

import audita1_grupos as A  # noqa: E402

ALPHAS = [0.10, 0.25, 0.40]
DELTAS = [4.0, 16.0, 20.0, 30.0, 60.0]
SEMILLAS = [11, 23, 37, 41, 59, 67, 73, 89, 97, 101, 113, 127]
T = 400.0
KMAX = 40


def _analiza(alpha, delta, seed, nombre, verbose=False):
    import r8c_sim
    from r8c_sim import Mundo
    from d14k_lib import kdag_from_r8c, popcount
    import d14k_ref as R

    r8c_sim.LAMBDA = 1.0
    r8c_sim.DELTA = delta
    m = Mundo(alpha=alpha, T=T, seed=seed)
    d, tip = m.corre(estrategia=A._estrategia(m, nombre))
    kd, idx = kdag_from_r8c(d)
    Hmask = 0
    for i in range(kd.n):
        if kd.creators[i] == "h":
            Hmask |= 1 << i
    tips = [i for i in range(kd.n) if not (kd.future[i] & kd.full)]
    bw = R.global_blue_work(kd)
    kv, grupos, cg = A._rank_grupos(kd, tips, bw)
    h_tips = [t for t in tips if (Hmask >> t) & 1]
    a_tips = [t for t in tips if not ((Hmask >> t) & 1)]
    Htip = max(h_tips, key=lambda i: (bw[i], -i)) if h_tips else None
    Atip = max(a_tips, key=lambda i: (bw[i], -i)) if a_tips else None

    def grupo_de(t):
        if t is None:
            return None
        nca = R.next_after(kd, t, cg)
        for g in grupos:
            if g["nca"] == nca:
                return g
        return None

    gh = grupo_de(Htip)
    ga = grupo_de(Atip)
    k_hon_tip = gh["k"] if gh else None
    k_att_tip = ga["k"] if ga else None

    gan_is_att = 0
    captura = 0
    gan_vsp = None
    if kv is not None:
        wins = [g for g in grupos if g["k"] == kv]
        gsel = A._tie_break_fiel(kd, wins, kv, cg)
        gan_vsp = gsel["vsp"]
        gan_is_att = int(kd.creators[gan_vsp] == "a")
        if gan_is_att and Htip is not None:
            captura = int(not ((kd.past[gan_vsp] >> Htip) & 1))
    victoria = int(gan_is_att and captura and
                   (k_hon_tip is None or (k_att_tip is not None and k_att_tip < k_hon_tip)))
    congelacion = int(k_hon_tip is None)
    if verbose:
        print(f"--- α={alpha} Δ={delta} seed={seed} {nombre} n={kd.n} tips={len(tips)} "
              f"grupos={len(grupos)} k_view={kv} Htip=b{Htip} k_hon_tip={k_hon_tip} "
              f"Atip=b{Atip} k_att_tip={k_att_tip} ganador=b{gan_vsp} "
              f"creador={kd.creators[gan_vsp] if gan_vsp is not None else '-'} "
              f"captura={captura} victoria={victoria}")
        for g in grupos:
            inH = popcount(g["bmask"] & Hmask) / max(1, popcount(g["bmask"]))
            marca = " <-- HON" if g is gh else (" <-- ATT" if g is ga else "")
            print(f"      nca=b{g['nca']}({kd.creators[g['nca']]}) vsp=b{g['vsp']}"
                  f"({kd.creators[g['vsp']]}) k={g['k']} score={g['score']} "
                  f"ntips={len(g['tips'])} hon_cluster={inH:.2f}{marca}")
    return (alpha, delta, seed, nombre, k_hon_tip, k_att_tip, kv, gan_is_att, captura,
            victoria, congelacion)


def _tarea(args):
    return _analiza(*args)


def main():
    verbose_casos = [
        (0.25, 20.0, 11, "retraso20"),
        (0.25, 20.0, 11, "retraso20_sp"),
        (0.25, 20.0, 11, "instant"),
        (0.40, 60.0, 11, "retraso20_sp"),
        (0.25, 16.0, 11, "parasita5"),
    ]
    print("=" * 130)
    print("TRAZA DE CASOS (rank del grupo del tip honesto vs ganador)")
    print("=" * 130)
    for c in verbose_casos:
        _analiza(*c, verbose=True)
    print()
    tareas = [(a, dd, s, e) for a in ALPHAS for dd in DELTAS for s in SEMILLAS
              for e in A.ESTRATEGIAS]
    with mp.Pool(processes=min(16, os.cpu_count() or 4)) as pool:
        res = pool.map(_tarea, tareas, chunksize=1)
    with open(os.path.join(_DIR, "salida2_crudo.txt"), "w") as f:
        f.write("alpha delta seed estrategia k_hon_tip k_att_tip k_view gan_att "
                "captura victoria congelacion\n")
        for r in res:
            f.write(" ".join(str(x) for x in r) + "\n")
    lineas = []
    lineas.append("=" * 122)
    lineas.append("AUDITA-D8B · rank del grupo del tip HONESTO vs rank del ganador")
    lineas.append("victoria = ganador atacante, tip honesto fuera de su pasado, y rank atacante "
                  "< rank honesto (o honesto None).")
    lineas.append("congelacion = el grupo del tip honesto NO pasa la UMC hasta k=40.")
    lineas.append("=" * 122)
    lineas.append(f"{'α':>5} {'Δ':>4} {'estrategia':>19} | {'k_hon_tip':>9} {'k_att_tip':>9} "
                  f"{'k_view':>6} | {'gan_att':>7} {'captura':>7} {'victoria':>8} "
                  f"{'congel':>6}")
    for a in ALPHAS:
        for dd in DELTAS:
            for e in A.ESTRATEGIAS:
                filas = [r for r in res if r[0] == a and r[1] == dd and r[3] == e]
                if not filas:
                    continue
                kh = [r[4] for r in filas if r[4] is not None]
                ka = [r[5] for r in filas if r[5] is not None]
                kv = [r[6] for r in filas if r[6] is not None]
                lineas.append(
                    f"{a:>5.2f} {dd:>4.0f} {e:>19} | {_m(kh):>9.2f} {_m(ka):>9.2f} "
                    f"{_m(kv):>6.2f} | {sum(r[7] for r in filas):>7} "
                    f"{sum(r[8] for r in filas):>7} {sum(r[9] for r in filas):>8} "
                    f"{sum(r[10] for r in filas):>6}")
        lineas.append("-" * 122)
    texto = "\n".join(lineas)
    print(texto)
    with open(os.path.join(_DIR, "salida2_ranks.txt"), "w") as f:
        f.write(texto + "\n")


def _m(v):
    return sum(v) / len(v) if v else float("nan")


if __name__ == "__main__":
    main()
