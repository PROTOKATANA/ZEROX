#!/usr/bin/env python3
r"""
audita1_grupos.py — D8 adversarial sobre la regla FIEL de D14B (informe2.md).

Preguntas atacadas:
  (1) ¿El "hueco de selección" de D14B/D8c es real o un artefacto del oráculo?
      El oráculo de D8c = fracción honesta del clúster ganador. En un DAG conectado de
      UN solo tip (lo normal con política 'tips': el atacante referencia TODAS las
      puntas) no hay contienda de subgrupos: la cadena honesta es ancestro del tip.
      Un clúster 43 % honesto con el atacante público NO es captura.
      Métrica de captura real: el ganador es de creador atacante Y el tip honesto
      (bloque honesto de mayor blue_work) NO está en su pasado.
  (2) ¿Se puede forzar un k honesto alto con una bifurcación privada (sp/retro) o
      retención combinada? Se añaden estrategias privadas (sp con retraso, retro con
      retención) que D14B no probó.

Mide por (α, Δ, semilla, estrategia):
  n_tips, n_grupos, k_view (min k sobre subgrupos), k_hon_grp (min k con clúster
  ≥50 % honesto), k_att_grp (min k con clúster <50 % honesto), creador del ganador
  por Alg. 4 fiel, y `captura` = ganador atacante & tip honesto fuera de su pasado.
12 semillas. No modifica nada fuera de este directorio.
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

ALPHAS = [0.10, 0.25, 0.40]
DELTAS = [4.0, 16.0, 20.0, 30.0, 60.0]
SEMILLAS = [11, 23, 37, 41, 59, 67, 73, 89, 97, 101, 113, 127]
T = 400.0
KMAX = 40
ESTRATEGIAS = ["instant", "retraso20", "retraso60", "retraso20_parasita5",
               "retraso60_parasita5", "parasita5", "sp", "retraso20_sp",
               "retraso60_sp", "privada_inf", "hook20", "retro500"]


def _estrategia(m, nombre):
    at = [(i, e) for i, e in enumerate(m.ev) if e[1] == "a"]
    if nombre == "instant":
        return {}
    if nombre == "retraso20":
        return {i: (20.0, "tips") for i, _ in at}
    if nombre == "retraso60":
        return {i: (60.0, "tips") for i, _ in at}
    if nombre == "retraso20_parasita5":
        return {i: (20.0, ("retro", 5)) for i, _ in at}
    if nombre == "retraso60_parasita5":
        return {i: (60.0, ("retro", 5)) for i, _ in at}
    if nombre == "parasita5":
        return {i: (0.0, ("retro", 5)) for i, _ in at}
    if nombre == "retro500":
        return {i: (0.0, ("retro", 500)) for i, _ in at}
    if nombre == "sp":
        return {i: (0.0, "sp") for i, _ in at}
    if nombre == "retraso20_sp":
        return {i: (20.0, "sp") for i, _ in at}
    if nombre == "retraso60_sp":
        return {i: (60.0, "sp") for i, _ in at}
    if nombre == "privada_inf":
        # bifurcación privada: cadena de un solo padre, publicada al final
        return {i: (1000.0, "sp") for i, _ in at}
    if nombre == "hook20":
        return {i: (0.0 if j % 5 == 0 else 20.0, "tips") for j, (i, _) in enumerate(at)}
    raise ValueError(nombre)


def _rank_grupos(kd, tips, bw, kmax=KMAX):
    import d14k_ref as R
    if not tips:
        return 0, [], 0
    if len(tips) == 1:
        cg = 0
    else:
        cg = tips[0]
        for t in tips[1:]:
            cg = kd.chain_lca(cg, t)
    groups = {}
    for t in tips:
        nca = R.next_after(kd, t, cg)
        groups.setdefault(nca, []).append(t)
    out = []
    for nca, gts in groups.items():
        vsp = max(gts, key=lambda t: (bw[t], -t))
        rec = None
        for k in range(kmax + 1):
            zd, _ = R.committed_coloring(kd, gts, nca, cg, k)
            vnd = R.virtual_coloring(kd, zd, tips, vsp, cg, k, bw)
            ok, score, blues, reds = R.umc_voting(kd, zd, cg, nca, vnd, k, bw)
            if ok:
                rec = (k, score, blues, reds)
                break
        bmask = 0
        for b in (rec[2] if rec else []):
            bmask |= 1 << b
        out.append(dict(nca=nca, tips=gts, vsp=vsp, zone=R.zone_of(kd, gts, nca),
                        k=rec[0] if rec else None, score=rec[1] if rec else None,
                        blues=rec[2] if rec else [], reds=rec[3] if rec else [],
                        bmask=bmask))
    kv = min((g["k"] for g in out if g["k"] is not None), default=None)
    return kv, out, cg


def _tie_break_fiel(kd, winners, k, cg):
    from d14k_lib import KColouring, VirtualColouring, popcount, iter_bits
    if len(winners) == 1:
        return winners[0]
    F, _ = VirtualColouring(kd).cluster_virtual(max(0, math.isqrt(k)), True, kd.full)
    kc = KColouring(kd)
    mejor = None
    for w in winners:
        vsp, zone = w["vsp"], w["zone"]
        C = 0
        for kp in range(k // 2, k + 1):
            _, chain = kc.cluster(vsp, kp, False, kd.past[vsp] & zone, cg)
            cnt = sum(1 for B in iter_bits(F) if popcount(kd.anticone(B, kd.full) & chain) > kp)
            if cnt > C:
                C = cnt
        clave = (C, vsp)
        if mejor is None or clave < mejor[0]:
            mejor = (clave, w)
    return mejor[1]


def _tarea(args):
    alpha, delta, seed, nombre = args
    import r8c_sim
    from r8c_sim import Mundo
    from d14k_lib import kdag_from_r8c, popcount
    import d14k_ref as R

    r8c_sim.LAMBDA = 1.0
    r8c_sim.DELTA = delta
    m = Mundo(alpha=alpha, T=T, seed=seed)
    d, tip = m.corre(estrategia=_estrategia(m, nombre))
    kd, idx = kdag_from_r8c(d)
    Hmask = 0
    for i in range(kd.n):
        if kd.creators[i] == "h":
            Hmask |= 1 << i
    tips = [i for i in range(kd.n) if not (kd.future[i] & kd.full)]
    bw = R.global_blue_work(kd)
    kv, grupos, cg = _rank_grupos(kd, tips, bw)

    def frac_hon(bmask):
        if bmask == 0:
            return float("nan")
        return popcount(bmask & Hmask) / popcount(bmask)

    for g in grupos:
        g["hon"] = frac_hon(g["bmask"])
    hon = [g for g in grupos if g["k"] is not None and g["hon"] >= 0.5]
    att = [g for g in grupos if g["k"] is not None and g["hon"] < 0.5]
    k_hon = min((g["k"] for g in hon), default=None)
    k_att = min((g["k"] for g in att), default=None)
    gan_is_att = 0
    gan_hon = float("nan")
    captura = 0
    if kv is not None:
        wins = [g for g in grupos if g["k"] == kv]
        gsel = _tie_break_fiel(kd, wins, kv, cg)
        gan_hon = gsel["hon"]
        gan_is_att = int(kd.creators[gsel["vsp"]] == "a")
        if kd.creators[gsel["vsp"]] == "a":
            Htip = max([i for i in range(kd.n) if (Hmask >> i) & 1],
                       key=lambda i: (bw[i], -i))
            hon_tip_en_gan = (kd.past[gsel["vsp"]] >> Htip) & 1
            captura = int(not hon_tip_en_gan)
    return (alpha, delta, seed, nombre, kd.n, len(tips), len(grupos), kv,
            k_hon, k_att, int(k_hon is None), gan_is_att, gan_hon, captura)


def main():
    tareas = [(a, dd, s, e) for a in ALPHAS for dd in DELTAS for s in SEMILLAS
              for e in ESTRATEGIAS]
    with mp.Pool(processes=min(16, os.cpu_count() or 4)) as pool:
        res = pool.map(_tarea, tareas, chunksize=1)
    with open(os.path.join(_DIR, "salida1_crudo.txt"), "w") as f:
        f.write("alpha delta seed estrategia n n_tips n_grupos k_view k_hon k_att "
                "sin_hon gan_att gan_frac captura\n")
        for r in res:
            f.write(" ".join(str(x) for x in r) + "\n")

    lineas = []

    def p(s=""):
        lineas.append(s)

    p("=" * 130)
    p("AUDITA-D8B · rank por subgrupo (regla FIEL). k_view = min k sobre subgrupos;")
    p("k_hon = min k de clúster ≥50 % honesto; k_att = min k de clúster <50 % honesto.")
    p("captura = el ganador de Alg.4 es de creador atacante Y el tip honesto NO está en su pasado.")
    p("sin_hon = semillas sin subgrupo honesto aceptado hasta k=40 (oráculo de D8c).")
    p("=" * 130)
    p(f"{'α':>5} {'Δ':>4} {'estrategia':>19} | {'tips':>4} {'gr':>3} {'k_view':>6} "
      f"{'k_hon':>6} {'k_att':>6} | {'sin_hon':>7} {'gan_att':>7} {'gan_frac':>8} {'captura':>7}")
    for a in ALPHAS:
        for dd in DELTAS:
            for e in ESTRATEGIAS:
                filas = [r for r in res if r[0] == a and r[1] == dd and r[3] == e]
                if not filas:
                    continue
                kv = [r[7] for r in filas if r[7] is not None]
                kh = [r[8] for r in filas if r[8] is not None]
                ka = [r[9] for r in filas if r[9] is not None]
                sinhon = sum(r[10] for r in filas)
                ganatt = sum(r[11] for r in filas)
                gfrac = [r[12] for r in filas if not math.isnan(r[12])]
                cap = sum(r[13] for r in filas)
                p(f"{a:>5.2f} {dd:>4.0f} {e:>19} | "
                  f"{_mean([r[5] for r in filas]):>4.1f} {_mean([r[6] for r in filas]):>3.1f} "
                  f"{_mean(kv):>6.2f} {_mean(kh):>6.2f} {_mean(ka):>6.2f} | "
                  f"{sinhon:>7} {ganatt:>7} {_mean(gfrac):>8.2f} {cap:>7}")
            p("-" * 130)
    texto = "\n".join(lineas)
    print(texto)
    with open(os.path.join(_DIR, "salida1_grupos.txt"), "w") as f:
        f.write(texto + "\n")


def _mean(v):
    v = list(v)
    return sum(v) / len(v) if v else float("nan")


if __name__ == "__main__":
    main()
