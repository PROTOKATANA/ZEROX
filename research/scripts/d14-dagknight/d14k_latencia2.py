#!/usr/bin/env python3
r"""
d14k_latencia2.py — Punto 3 (D14C): latencia publicable en el peor caso de red con la
mitigación M2h (exigir que el k-clúster confirmado cubra la cadena honesta del cliente).

α=0,33, λ=1, T=400 s, 12 semillas, Δ=16/20 s, estrategias instant (red sana),
retraso20_sp y retraso60_sp (retención + cadena privada). ε=1e-6 y 1e-12.
La medida usa la VISTA REAL del cliente en T (bloques con entrega <= T), no la vista
completa del simulador; ver d14k_visible2.py y la sección de errores propios.
Medidas por semilla:
  · k_conf  = k del ganador de M2h (primer subgrupo que cubre la cadena honesta);
  · k_hon   = k del subgrupo del tip honesto bajo M2h (si el cliente exigiera ganador
              honesto); None = congelación;
  · k_fiel  = rank fiel M0 del subgrupo del tip honesto (referencia de informe2);
  · latencia = tiempo de calendario hasta el M-ésimo honesto tras B*, M = max(3k, m(α,ε))
              (misma convención que informe2/d14k_zerox2.py);
  · baseline k=30: M=90 sobre el mismo calendario.
Cota del paper (:1007): (ln(1/ε)+Dλ)/((1−2α)λ)+D²λ.
Salida: salida_latencia2.txt.
"""
import math
import multiprocessing as mp
import os
import statistics as st
import sys

_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, _DIR)
sys.path.insert(0, os.path.normpath(os.path.join(_DIR, "..", "d9-ronda8c")))

from d14k_ataque2 import (estrategia, rank_por_grupo, tie_break_fiel,  # noqa: E402
                          margen_paseo, kdag_visible, llega_por_bloque)

ALPHA = 0.33
DELTAS = [16.0, 20.0]
SEMILLAS = [11, 23, 37, 41, 59, 67, 73, 89, 97, 101, 113, 127]
ESTRATEGIAS = ["instant", "retraso20_sp", "retraso60_sp"]
EPSILONS = [1e-6, 1e-12]
T = 400.0
T_TX = 200.0
K_BASE = 30


def _tarea(args):
    delta, seed, nombre = args
    import r8c_sim
    from r8c_sim import Mundo
    from d14k_lib import kdag_from_r8c
    import d14k_ref as R

    r8c_sim.LAMBDA = 1.0
    r8c_sim.DELTA = delta
    m = Mundo(alpha=ALPHA, T=T, seed=seed)
    est = estrategia(m, nombre)
    d, _ = m.corre(estrategia=est)
    kd_full, idx = kdag_from_r8c(d)
    kd = kdag_visible(kd_full, llega_por_bloque(d, idx, m, est, delta), T)
    tips = [i for i in range(kd.n) if not (kd.future[i] & kd.full)]
    bw = R.global_blue_work(kd)
    Hmask = sum(1 << i for i in range(kd.n) if kd.creators[i] == "h")
    h_tips = [t for t in tips if (Hmask >> t) & 1]
    Htip = max(h_tips, key=lambda i: (bw[i], -i)) if h_tips else None
    kv, grupos, cg = rank_por_grupo(kd, tips, bw, htip=Htip)
    if Htip is not None:
        for g in grupos:
            g["_incluye_htip"] = bool(((kd.past[g["vsp"]] >> Htip) & 1) or g["htip_azul"])
            g["_cubre_htip"] = bool((kd.past[g["vsp"]] >> Htip) & 1)
        gh = next((g for g in grupos if Htip in g["tips"]), None)
        k_hon = gh["k_cadena_hon"] if gh is not None else None
        k_fiel = gh["k"] if gh is not None else None
    else:
        k_hon = k_fiel = None
    # M2h: ganador = min k_cadena_hon entre los que cubren la cadena honesta
    cands = [(g["k_cadena_hon"], g) for g in grupos if g["k_cadena_hon"] is not None]
    k_conf = None
    gan_att = None
    cap_ref = 0
    if cands:
        kmin = min(k for k, _ in cands)
        wins = [g for k, g in cands if k == kmin]
        gsel = tie_break_fiel(kd, wins, kmin, cg)
        k_conf = kmin
        gan_att = int(kd.creators[gsel["vsp"]] == "a")
        if gan_att and Htip is not None:
            en_pasado = (kd.past[gsel["vsp"]] >> Htip) & 1
            k_azul = gsel["k_htip"]
            en_azules = k_azul is not None and k_azul <= kmin
            cap_ref = int(not en_pasado and not en_azules)

    honestos = [e[0] for e in m.ev if e[1] == "h"]
    idx_tx = next((i for i, t in enumerate(honestos) if t >= T_TX), 0)
    t_tx = honestos[idx_tx]

    def tiempo_a_M(M):
        if M is None or M <= 0:
            return 0.0
        j = idx_tx + M
        if j >= len(honestos):
            return None
        return honestos[j] - t_tx

    t_base = tiempo_a_M(3 * K_BASE)
    out = dict(delta=delta, seed=seed, estrategia=nombre, k_conf=k_conf,
               k_hon=k_hon, k_fiel=k_fiel, gan_att=gan_att, cap_ref=cap_ref,
               t_base=t_base)
    for e in EPSILONS:
        m_eps = margen_paseo(ALPHA, e)
        out[f"m_{e}"] = m_eps
        out[f"t_conf_{e}"] = tiempo_a_M(max(3 * (k_conf or 0), m_eps)) if k_conf is not None else None
        out[f"t_hon_{e}"] = tiempo_a_M(max(3 * (k_hon or 0), m_eps)) if k_hon is not None else None
        out[f"t_fiel_{e}"] = tiempo_a_M(max(3 * (k_fiel or 0), m_eps)) if k_fiel is not None else None
        out[f"suelo_conf_{e}"] = (max(3 * k_conf, m_eps) / ((1 - ALPHA) * 1.0)
                                  if k_conf is not None else None)
        out[f"suelo_hon_{e}"] = (max(3 * k_hon, m_eps) / ((1 - ALPHA) * 1.0)
                                 if k_hon is not None else None)
    return out


def _m(v):
    v = list(v)
    return st.mean(v) if v else float("nan")


def main():
    tareas = [(dd, s, e) for dd in DELTAS for s in SEMILLAS for e in ESTRATEGIAS]
    with mp.Pool(processes=min(16, os.cpu_count() or 4)) as pool:
        res = pool.map(_tarea, tareas, chunksize=1)

    with open(os.path.join(_DIR, "salida_latencia2_crudo.txt"), "w") as f:
        f.write("delta seed estrategia k_conf k_hon k_fiel gan_att cap_ref t_base " +
                " ".join(f"m{e} t_conf{e} t_hon{e} t_fiel{e} suelo_conf{e} suelo_hon{e}"
                         for e in EPSILONS) + "\n")
        for r in res:
            f.write(f"{r['delta']} {r['seed']} {r['estrategia']} {r['k_conf']} "
                    f"{r['k_hon']} {r['k_fiel']} {r['gan_att']} {r['cap_ref']} {r['t_base']} ")
            for e in EPSILONS:
                f.write(f"{r['m_'+str(e)]} {r['t_conf_'+str(e)]} {r['t_hon_'+str(e)]} "
                        f"{r['t_fiel_'+str(e)]} {r['suelo_conf_'+str(e)]} "
                        f"{r['suelo_hon_'+str(e)]} ")
            f.write("\n")

    lineas = []

    def p(s=""):
        lineas.append(s)

    p("=" * 122)
    p("LATENCIA α=0,33 — mitigación M2h (el k-clúster confirmado cubre la cadena honesta)")
    p("λ=1, T=400 s, 12 semillas. k_conf = k del ganador M2h; k_hon = k del subgrupo del")
    p("tip honesto bajo M2h (None = congelación); k_fiel = rank fiel M0 de referencia.")
    p("Latencia = tiempo hasta el M-ésimo honesto tras B*, M = max(3k, m(α,ε)).")
    p("=" * 122)

    p()
    p("A · baseline k=30 (M=90) y cota del paper (:1007) por Δ")
    for dd in DELTAS:
        v = [r["t_base"] for r in res if r["delta"] == dd and r["t_base"] is not None]
        p(f"   Δ={dd:.0f}: baseline medido {_m(v):.2f} s "
          f"(suelo 3·30/((1−α)λ) = {3*K_BASE/((1-ALPHA)):.1f} s)")
        for e in EPSILONS:
            c = (math.log(1 / e) + dd * 1.0) / ((1 - 2 * ALPHA) * 1.0) + dd * dd * 1.0
            p(f"      cota paper ε={e}: {c:.1f} s")

    p()
    p("B · M2h por (Δ, estrategia): k_conf / k_hon / k_fiel (media[mín,máx]); congelación")
    p("cong_conf = el ganador M2h no existe (cliente no confirma); cong_hon = el subgrupo")
    p("del tip honesto no cubre su cadena. cap_ref = censura real residual (debe ser 0).")
    p(f"{'Δ':>4} {'estrategia':>13} | {'k_conf':>12} {'k_hon':>14} {'k_fiel':>12} | "
      f"{'cong_c':>6} {'cong_h':>6} {'gan_att':>7} {'cap_ref':>7}")
    for dd in DELTAS:
        for e in ESTRATEGIAS:
            filas = [r for r in res if r["delta"] == dd and r["estrategia"] == e]
            def mm(campo):
                v = [r[campo] for r in filas if r[campo] is not None]
                return f"{st.mean(v):.1f}[{min(v)},{max(v)}]" if v else "--"
            cong_c = sum(1 for r in filas if r["k_conf"] is None)
            cong_h = sum(1 for r in filas if r["k_hon"] is None)
            gan = sum(1 for r in filas if r["gan_att"] == 1)
            capr = sum(1 for r in filas if r["cap_ref"] == 1)
            p(f"{dd:>4.0f} {e:>13} | {mm('k_conf'):>12} {mm('k_hon'):>14} "
              f"{mm('k_fiel'):>12} | {cong_c:>4}/12 {cong_h:>4}/12 {gan:>5}/12 "
              f"{capr:>5}/12")

    p()
    p("C · latencia M2h (s) por (Δ, ε): con k_conf y con k_hon; media[mín,máx]")
    p(f"{'Δ':>4} {'estrategia':>13} | " + " | ".join(
        f"{'ε='+str(e)+' conf':>22}" for e in EPSILONS) + " | " +
      " | ".join(f"{'ε='+str(e)+' hon':>22}" for e in EPSILONS))
    for dd in DELTAS:
        for e in ESTRATEGIAS:
            filas = [r for r in res if r["delta"] == dd and r["estrategia"] == e]
            celdas = []
            for eps in EPSILONS:
                v = [r[f"t_conf_{eps}"] for r in filas if r[f"t_conf_{eps}"] is not None]
                celdas.append(f"{st.mean(v):>9.2f}[{min(v):>6.2f},{max(v):>6.2f}]"
                              if v else f"{'--':>22}")
            for eps in EPSILONS:
                v = [r[f"t_hon_{eps}"] for r in filas if r[f"t_hon_{eps}"] is not None]
                celdas.append(f"{st.mean(v):>9.2f}[{min(v):>6.2f},{max(v):>6.2f}]"
                              if v else f"{'--':>22}")
            p(f"{dd:>4.0f} {e:>13} | " + " | ".join(celdas))

    p()
    p("D · suelo teórico M2h max(3k,m)/((1−α)λ) (s) por (Δ, ε): media con k_conf / k_hon")
    for dd in DELTAS:
        for e in ESTRATEGIAS:
            filas = [r for r in res if r["delta"] == dd and r["estrategia"] == e]
            celdas = []
            for eps in EPSILONS:
                v = [r[f"suelo_conf_{eps}"] for r in filas
                     if r[f"suelo_conf_{eps}"] is not None]
                h = [r[f"suelo_hon_{eps}"] for r in filas
                     if r[f"suelo_hon_{eps}"] is not None]
                celdas.append(f"c={st.mean(v):>6.1f} h={st.mean(h):>6.1f}"
                              if v else f"{'--':>17}")
            p(f"   Δ={dd:>4.0f} {e:>13}: " + " | ".join(celdas))

    texto = "\n".join(lineas)
    print(texto)
    with open(os.path.join(_DIR, "salida_latencia2.txt"), "w") as f:
        f.write(texto + "\n")


if __name__ == "__main__":
    main()
