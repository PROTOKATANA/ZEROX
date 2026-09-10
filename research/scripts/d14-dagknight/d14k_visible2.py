#!/usr/bin/env python3
r"""
d14k_visible2.py — Punto 2/3 (D14C): el ataque y la mitigación M2h medidos sobre la
VISTA REAL del cliente en T (bloques con entrega <= T), no sobre "todo lo creado".

Motivo: `Mundo.corre` devuelve el DAG completo, incluidos bloques del atacante que aún
no se habían publicado en T. La auditoría D8b y el ataque 2 los cuentan; aquí se separa:
  · vista completa = todos los bloques creados hasta T (modelo D8b: revelación total);
  · vista real     = bloques con llega <= T (lo que ve un cliente honesto en T).
Medidas:
  · M0: captura D8b y captura_ref (censura real) en ambas vistas;
  · M2h: cap_ref, congelación y k_conf en la vista real;
  · latencia α=0,33 con k_conf de la vista real, M=max(3k,m(α,ε)), ε=1e-6/1e-12.
Salida: salida_visible2.txt y salida_visible2_crudo.txt.
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
                          kdag_visible, llega_por_bloque, margen_paseo)

ALPHAS_CAP = [0.25, 0.40]
ALPHA_LAT = 0.33
DELTAS = [16.0, 20.0]
SEMILLAS = [11, 23, 37, 41, 59, 67, 73, 89, 97, 101, 113, 127]
ESTRATEGIAS = ["instant", "retraso20", "retraso20_sp", "retraso60_sp"]
EPSILONS = [1e-6, 1e-12]
T = 400.0
T_TX = 200.0
K_BASE = 30


def _analiza(kd):
    tips = [i for i in range(kd.n) if not (kd.future[i] & kd.full)]
    import d14k_ref as R
    bw = R.global_blue_work(kd)
    Hmask = sum(1 << i for i in range(kd.n) if kd.creators[i] == "h")
    h_tips = [t for t in tips if (Hmask >> t) & 1]
    Htip = max(h_tips, key=lambda i: (bw[i], -i)) if h_tips else None
    kv, grupos, cg = rank_por_grupo(kd, tips, bw, htip=Htip)
    out = dict(kv=kv, cap0=0, capb0=0, k_conf=None, cap_ref=0, k_hon=None)
    if kv is not None:
        wins = [g for g in grupos if g["k"] == kv]
        gsel = tie_break_fiel(kd, wins, kv, cg)
        if kd.creators[gsel["vsp"]] == "a" and Htip is not None:
            en_pasado = (kd.past[gsel["vsp"]] >> Htip) & 1
            k_azul = gsel["k_htip"]
            en_azules = k_azul is not None and k_azul <= kv
            out["cap0"] = int(not en_pasado)
            out["capb0"] = int(not en_pasado and not en_azules)
    cands = [(g["k_cadena_hon"], g) for g in grupos if g["k_cadena_hon"] is not None]
    if cands:
        kmin = min(k for k, _ in cands)
        wins = [g for k, g in cands if k == kmin]
        gsel = tie_break_fiel(kd, wins, kmin, cg)
        out["k_conf"] = kmin
        if kd.creators[gsel["vsp"]] == "a" and Htip is not None:
            en_pasado = (kd.past[gsel["vsp"]] >> Htip) & 1
            k_azul = gsel["k_htip"]
            en_azules = k_azul is not None and k_azul <= kmin
            out["cap_ref"] = int(not en_pasado and not en_azules)
    if Htip is not None:
        gh = next((g for g in grupos if Htip in g["tips"]), None)
        out["k_hon"] = gh["k_cadena_hon"] if gh is not None else None
    return out


def _tarea(args):
    alpha, delta, seed, nombre, visible = args
    import r8c_sim
    from r8c_sim import Mundo
    from d14k_lib import kdag_from_r8c

    r8c_sim.LAMBDA = 1.0
    r8c_sim.DELTA = delta
    m = Mundo(alpha=alpha, T=T, seed=seed)
    est = estrategia(m, nombre)
    d, _ = m.corre(estrategia=est)
    kd_full, idx = kdag_from_r8c(d)
    if visible:
        kd = kdag_visible(kd_full, llega_por_bloque(d, idx, m, est, delta), T)
    else:
        kd = kd_full
    res = _analiza(kd)
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

    res.update(alpha=alpha, delta=delta, seed=seed, estrategia=nombre,
               visible=int(visible), n=kd.n)
    for e in EPSILONS:
        res[f"t_conf_{e}"] = (tiempo_a_M(max(3 * (res["k_conf"] or 0),
                                              margen_paseo(alpha, e)))
                              if res["k_conf"] is not None else None)
    return res


def _m(v):
    v = list(v)
    return st.mean(v) if v else float("nan")


def main():
    tareas = []
    for a in ALPHAS_CAP:
        for dd in DELTAS:
            for s in SEMILLAS:
                for e in ESTRATEGIAS:
                    tareas.append((a, dd, s, e, False))
                    tareas.append((a, dd, s, e, True))
    for dd in DELTAS:
        for s in SEMILLAS:
            for e in ESTRATEGIAS:
                tareas.append((ALPHA_LAT, dd, s, e, True))
    with mp.Pool(processes=min(16, os.cpu_count() or 4)) as pool:
        res = pool.map(_tarea, tareas, chunksize=1)

    with open(os.path.join(_DIR, "salida_visible2_crudo.txt"), "w") as f:
        f.write("alpha delta seed estrategia visible n kv cap0 capb0 k_conf cap_ref "
                "k_hon t_conf_1e-06 t_conf_1e-12\n")
        for r in res:
            f.write(f"{r['alpha']} {r['delta']} {r['seed']} {r['estrategia']} "
                    f"{r['visible']} {r['n']} {r['kv']} {r['cap0']} {r['capb0']} "
                    f"{r['k_conf']} {r['cap_ref']} {r['k_hon']} "
                    f"{r['t_conf_1e-06']} {r['t_conf_1e-12']}\n")

    lineas = []

    def p(s=""):
        lineas.append(s)

    p("=" * 122)
    p("VISTA COMPLETA vs VISTA REAL DEL CLIENTE EN T — ataque retención + cadena privada")
    p("vista completa = todo lo creado (modelo D8b); vista real = bloques con entrega <= T.")
    p("cap0 = captura D8b; capb0 = captura_ref (ni pasado ni azul); 12 semillas.")
    p("=" * 122)
    for a in ALPHAS_CAP:
        for dd in DELTAS:
            p()
            p(f"α={a:.2f} Δ={dd:.0f} — M0: captura D8b | captura_ref (12 semillas)")
            p(f"{'estrategia':>13} | {'vista completa':>16} | {'vista real':>16}")
            for e in ESTRATEGIAS:
                celdas = []
                for vis in (False, True):
                    filas = [r for r in res if r["alpha"] == a and r["delta"] == dd
                             and r["estrategia"] == e and bool(r["visible"]) == vis]
                    cap = sum(r["cap0"] for r in filas)
                    capb = sum(r["capb0"] for r in filas)
                    celdas.append(f"{cap:>4}|{capb:>4}")
                p(f"{e:>13} | {celdas[0]:>16} | {celdas[1]:>16}")
    p()
    p("=" * 122)
    p("M2h SOBRE LA VISTA REAL — k_conf, congelación, cap_ref y latencia (α=0,33)")
    p("=" * 122)
    p(f"{'α':>5} {'Δ':>4} {'estrategia':>13} | {'k_conf med[min,max]':>20} | "
      f"{'cong':>5} {'cap_ref':>7} | {'lat ε=1e-6 med[min,max]':>24} | "
      f"{'lat ε=1e-12 med[min,max]':>24}")
    for a in [ALPHA_LAT]:
        for dd in DELTAS:
            for e in ESTRATEGIAS:
                filas = [r for r in res if r["alpha"] == a and r["delta"] == dd
                         and r["estrategia"] == e and r["visible"] == 1]
                kc = [r["k_conf"] for r in filas if r["k_conf"] is not None]
                kcs = f"{st.mean(kc):.1f}[{min(kc)},{max(kc)}]" if kc else "--"
                cong = sum(1 for r in filas if r["k_conf"] is None)
                capr = sum(r["cap_ref"] for r in filas)
                celdas = []
                for eps in EPSILONS:
                    t = [r[f"t_conf_{eps}"] for r in filas
                         if r[f"t_conf_{eps}"] is not None]
                    celdas.append(f"{st.mean(t):.1f}[{min(t):.1f},{max(t):.1f}]"
                                  if t else "--")
                p(f"{a:>5.2f} {dd:>4.0f} {e:>13} | {kcs:>20} | {cong:>3}/12 "
                  f"{capr:>5}/12 | {celdas[0]:>24} | {celdas[1]:>24}")
    p()
    p(f"baseline α=0,33: k=30 -> suelo 3·30/((1−α)λ) = {3*K_BASE/(1-ALPHA_LAT):.1f} s; "
      f"m(1e-6)={margen_paseo(ALPHA_LAT, 1e-6)}, m(1e-12)={margen_paseo(ALPHA_LAT, 1e-12)}")
    p("(la latencia usa el mismo calendario y la misma fórmula que informe2/d14k_zerox2.py)")
    texto = "\n".join(lineas)
    print(texto)
    with open(os.path.join(_DIR, "salida_visible2.txt"), "w") as f:
        f.write(texto + "\n")


if __name__ == "__main__":
    main()
