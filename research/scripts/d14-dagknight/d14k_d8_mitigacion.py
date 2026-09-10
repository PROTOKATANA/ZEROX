#!/usr/bin/env python3
r"""
d14k_d8_mitigacion.py — D8 propio de la mitigación M2h: ¿puede el atacante derrotarla
subiendo la retención R? Estrategias sp con R ∈ {20, 60, 80, 120, 160} s y cadena privada
infinita, α=0,40, Δ=20 (peor celda del ataque), 12 semillas, ε=1e-6.

Mide, bajo M2h (el ganador debe cubrir la cadena honesta del cliente):
  k_conf, cap_ref (censura real; debe ser 0), congelación (k_conf None), k del subgrupo
  del tip honesto, y latencia = tiempo hasta el M-ésimo honesto tras B*, M=max(3k,m(α,ε)).
Salida: salida_d8_mitigacion.txt.
"""
import math
import multiprocessing as mp
import os
import statistics as st
import sys

_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, _DIR)
sys.path.insert(0, os.path.normpath(os.path.join(_DIR, "..", "d9-ronda8c")))

from d14k_ataque2 import (rank_por_grupo, tie_break_fiel, margen_paseo,  # noqa: E402
                          kdag_visible, llega_por_bloque)

ALPHA = 0.40
DELTA = 20.0
SEMILLAS = [11, 23, 37, 41, 59, 67, 73, 89, 97, 101, 113, 127]
RETENCIONES = [20.0, 60.0, 80.0, 120.0, 160.0, 1000.0]
POLITICAS = ["tips", "sp"]
EPS = 1e-6
T = 400.0
T_TX = 200.0
K_BASE = 30


def _estrategia_sp(m, retraso, politica="sp"):
    at = [(i, e) for i, e in enumerate(m.ev) if e[1] == "a"]
    return {i: (retraso, politica) for i, _ in at}





def _tarea(args):
    seed, retraso, politica = args
    import r8c_sim
    from r8c_sim import Mundo
    from d14k_lib import kdag_from_r8c
    import d14k_ref as R

    r8c_sim.LAMBDA = 1.0
    r8c_sim.DELTA = DELTA
    m = Mundo(alpha=ALPHA, T=T, seed=seed)
    est = _estrategia_sp(m, retraso, politica)
    d, _ = m.corre(estrategia=est)
    kd_full, idx = kdag_from_r8c(d)
    kd = kdag_visible(kd_full, llega_por_bloque(d, idx, m, est, DELTA), T)
    tips = [i for i in range(kd.n) if not (kd.future[i] & kd.full)]
    bw = R.global_blue_work(kd)
    Hmask = sum(1 << i for i in range(kd.n) if kd.creators[i] == "h")
    h_tips = [t for t in tips if (Hmask >> t) & 1]
    Htip = max(h_tips, key=lambda i: (bw[i], -i)) if h_tips else None
    kv, grupos, cg = rank_por_grupo(kd, tips, bw, htip=Htip)
    k_conf = gan_att = cap_ref = None
    k_hon = None
    if Htip is not None:
        gh = next((g for g in grupos if Htip in g["tips"]), None)
        k_hon = gh["k_cadena_hon"] if gh is not None else None
    cands = [(g["k_cadena_hon"], g) for g in grupos if g["k_cadena_hon"] is not None]
    if cands:
        kmin = min(k for k, _ in cands)
        wins = [g for k, g in cands if k == kmin]
        gsel = tie_break_fiel(kd, wins, kmin, cg)
        k_conf = kmin
        gan_att = int(kd.creators[gsel["vsp"]] == "a")
        cap_ref = 0
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

    m_eps = margen_paseo(ALPHA, EPS)
    t_conf = tiempo_a_M(max(3 * (k_conf or 0), m_eps)) if k_conf is not None else None
    return dict(seed=seed, retraso=retraso, politica=politica, k_conf=k_conf,
                k_hon=k_hon, gan_att=gan_att, cap_ref=cap_ref, t_conf=t_conf,
                m_eps=m_eps)


def main():
    tareas = [(s, r, pol) for pol in POLITICAS for r in RETENCIONES for s in SEMILLAS]
    with mp.Pool(processes=min(16, os.cpu_count() or 4)) as pool:
        res = pool.map(_tarea, tareas, chunksize=1)
    with open(os.path.join(_DIR, "salida_d8_mitigacion_crudo.txt"), "w") as f:
        f.write("seed retraso politica k_conf k_hon gan_att cap_ref t_conf m_eps\n")
        for r in res:
            f.write(f"{r['seed']} {r['retraso']} {r['politica']} {r['k_conf']} "
                    f"{r['k_hon']} {r['gan_att']} {r['cap_ref']} {r['t_conf']} "
                    f"{r['m_eps']}\n")
    lineas = []

    def p(s=""):
        lineas.append(s)

    p("=" * 104)
    p("D8 DE LA MITIGACIÓN M2h — α=0,40, Δ=20, ε=1e-6, 12 semillas")
    p("El atacante sube la retención R de su cadena privada (política sp y tips). R≥160 s")
    p("lo vuelve invisible en la ventana; R=1000 s = nunca publica. Vista real (entrega<=T).")
    p("=" * 104)
    for pol in POLITICAS:
        p()
        p(f"--- política de padres: {pol} ---")
        p(f"{'R (s)':>7} | {'k_conf med[min,max]':>20} {'k_hon med[min,max]':>20} | "
          f"{'cong/12':>7} {'gan_att':>7} {'cap_ref':>7} | {'lat med[min,max]':>22}")
        for r in RETENCIONES:
            filas = [x for x in res if x["retraso"] == r and x["politica"] == pol]
            kc = [x["k_conf"] for x in filas if x["k_conf"] is not None]
            kh = [x["k_hon"] for x in filas if x["k_hon"] is not None]
            t = [x["t_conf"] for x in filas if x["t_conf"] is not None]
            cong = sum(1 for x in filas if x["k_conf"] is None)
            gan = sum(1 for x in filas if x["gan_att"] == 1)
            cap = sum(1 for x in filas if x["cap_ref"] == 1)
            kcs = f"{st.mean(kc):.1f}[{min(kc)},{max(kc)}]" if kc else "--"
            khs = f"{st.mean(kh):.1f}[{min(kh)},{max(kh)}]" if kh else "--"
            ts = f"{st.mean(t):.1f}[{min(t):.1f},{max(t):.1f}]" if t else "--"
            p(f"{r:>7.0f} | {kcs:>20} {khs:>20} | {cong:>5}/12 {gan:>5}/12 "
              f"{cap:>5}/12 | {ts:>22}")
    p()
    p(f"baseline k=30: suelo 3·30/((1−α)λ) = {3*K_BASE/((1-ALPHA)):.1f} s; "
      f"m(α,1e-6)={margen_paseo(ALPHA, EPS)}")
    p("VEREDICTO D8: si cap_ref=0 en todas las R y la congelación no crece, el atacante")
    p("no puede derrotar M2h subiendo la retención; solo paga más latencia.")
    texto = "\n".join(lineas)
    print(texto)
    with open(os.path.join(_DIR, "salida_d8_mitigacion.txt"), "w") as f:
        f.write(texto + "\n")


if __name__ == "__main__":
    main()
