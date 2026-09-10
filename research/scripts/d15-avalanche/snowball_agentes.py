#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
snowball_agentes.py — Simulación por agentes de Snowball (arXiv:1906.08936 Figs. 5/6
y regla isAccepted de la Fig. 10) con adversario que responde siempre rojo.

- n_total votantes (la ventana de soluciones); alpha = fracción adversaria.
- Cada ronda, cada honesto vivo muestrea k votantes sin reemplazo (hypergeométrico
  vectorizado) y aplica:
    confianza: d[color]++ por cada chit; cambia de color si d[nuevo] > d[actual].
    decision: acepta el color cuando d[color] >= beta_conf (Fig. 10, camino rapido)
              o cuando el contador consecutivo >= beta_cons (Fig. 5/6, si beta_cons>0).
- Retardo de vista L rondas (proxy de Δ; L = ceil(Δ / T_ronda)).
- Control positivo (criterio α): los resultados cambian con alpha; con k=10 q=6
  (alpha=⌊k/2⌋+1 del paper) converge rápido; con q=8 y alpha>=0,25 la viveza
  del paper se rompe (f < (k-q)/k = 0,20).

Métricas: rondas a 50/90/100 % decidido, semillas con decisión mixta (fallo de
seguridad), semillas con algún honesto rojo.
"""
import numpy as np

SEEDS = list(range(12001, 12021))  # 20 semillas >= 12


def simula(n_total=3000, alpha=0.33, k=50, q=30, beta_conf=11, beta_cons=0,
           L=0, p0=1.0, max_rondas=5000, seed=0, damping=True):
    rng = np.random.default_rng(seed)
    n_a = int(round(alpha * n_total))
    n_h = n_total - n_a
    col = np.zeros(n_h, dtype=np.int8)
    n_ini = int(round(p0 * n_h))
    col[n_ini:] = 1
    lastcol = col.copy()
    cnt = np.zeros(n_h, dtype=np.int32)
    d = np.zeros((2, n_h), dtype=np.int32)
    decidido = np.zeros(n_h, dtype=bool)
    dec_col = np.full(n_h, -1, dtype=np.int8)
    r_dec = np.full(n_h, -1, dtype=np.int32)
    hist_blue = [int((col == 0).sum())] * (L + 1)
    for r in range(1, max_rondas + 1):
        blue_tot = hist_blue[-1 - L] if L > 0 else int((col == 0).sum())
        az = rng.hypergeometric(blue_tot, n_total - blue_tot, k, size=n_h)
        ro = k - az
        chit_b = az >= q
        chit_r = ro >= q
        vivos = ~decidido
        d[0, vivos] += chit_b[vivos]
        d[1, vivos] += chit_r[vivos]
        if damping:  # Snowball: el color cambia solo si la confianza nueva supera la vieja
            col[vivos & (d[1] > d[0]) & (col == 0)] = 1
            col[vivos & (d[0] > d[1]) & (col == 1)] = 0
        else:        # Slush/Snowflake: cambia de color con cualquier chit mayoritario
            col[vivos & chit_r] = 1
            col[vivos & chit_b] = 0
        for cchit, cval in ((chit_b, 0), (chit_r, 1)):
            m = vivos & cchit
            igual = m & (lastcol == cval)
            cnt[igual] += 1
            cnt[m & ~igual] = 1
            lastcol[m & ~igual] = cval
            if beta_cons > 0:
                nuevo = igual & (cnt >= beta_cons)
                decidido[nuevo] = True
                dec_col[nuevo] = cval
                r_dec[nuevo] = r
        cnt[vivos & ~(chit_b | chit_r)] = 0
        nuevo = vivos & (d[0] >= beta_conf) & (d[1] < beta_conf)
        decidido[nuevo] = True
        dec_col[nuevo] = 0
        r_dec[nuevo] = r
        nuevo = vivos & (d[1] >= beta_conf) & (d[0] < beta_conf)
        decidido[nuevo] = True
        dec_col[nuevo] = 1
        r_dec[nuevo] = r
        hist_blue.append(int((col == 0).sum()))
        if decidido.all():
            break
    r90 = int(np.percentile(r_dec[decidido], 90)) if decidido.any() else r
    return dict(rondas=r, r90=r90,
                decididos=int(decidido.sum()), frac_dec=float(decidido.mean()),
                dec_azul=int((dec_col[decidido] == 0).sum()),
                dec_rojo=int((dec_col[decidido] == 1).sum()),
                rojo_final=int((col == 1).sum()))


def corre_config(alpha, k, q, beta_conf=11, beta_cons=0, L=0, p0=1.0,
                 n_total=3000, max_rondas=5000, damping=True):
    rs, r90s, mixtos, rojos, dec = [], [], [], [], []
    for s in SEEDS:
        r = simula(n_total=n_total, alpha=alpha, k=k, q=q, beta_conf=beta_conf,
                   beta_cons=beta_cons, L=L, p0=p0, max_rondas=max_rondas, seed=s,
                   damping=damping)
        rs.append(r["rondas"])
        r90s.append(r["r90"])
        mixtos.append(1 if (r["dec_azul"] > 0 and r["dec_rojo"] > 0) else 0)
        rojos.append(1 if r["dec_rojo"] > 0 else 0)
        dec.append(r["frac_dec"])
    return dict(rondas_med=float(np.mean(rs)), rondas_min=int(np.min(rs)),
                rondas_max=int(np.max(rs)), r90_med=float(np.mean(r90s)),
                mixtos=int(sum(mixtos)), rojos=int(sum(rojos)),
                dec_med=float(np.mean(dec)))


def main():
    out = []

    def p(s):
        out.append(s)
        print(s)

    p("=" * 106)
    p("Snowball por agentes · n=3000 · 20 semillas · adversario siempre rojo")
    p("Decision: confianza d[color]>=beta_conf (Fig. 10) o consecutivo>=beta_cons (si >0).")
    p("Control positivo: k=10 q=6 (alpha=⌊k/2⌋+1 del paper) converge rápido; con k=10 q=8,")
    p("la viveza del paper exige f < (k-q)/k = 0,20 (:598-599).")
    p("=" * 106)
    p("")
    p("--- CONTROL k=10, q=6 y q=8, beta_conf=11, beta_cons=0, p0=1 ---")
    p(f"{'alpha':>6} {'q':>3} {'rondas_med':>10} {'r90_med':>8} {'rondas_max':>10} "
      f"{'mixtas':>7} {'con_rojo':>9} {'dec_med':>8}")
    for q in (6, 8):
        for a in (0.0, 0.10, 0.20, 0.25, 0.33, 0.40):
            r = corre_config(a, 10, q)
            p(f"{a:6.2f} {q:3d} {r['rondas_med']:10.1f} {r['r90_med']:8.1f} "
              f"{r['rondas_max']:10d} {r['mixtos']:7d} {r['rojos']:9d} {r['dec_med']:8.3f}")
    p("")
    p("--- REJILLA ZEROX: alpha=0,33, p0=1, beta_conf variable ---")
    p(f"{'k':>4} {'q':>4} {'q/k':>6} {'bconf':>6} {'rondas_med':>10} {'r90_med':>8} "
      f"{'rondas_max':>10} {'mixtas':>7} {'con_rojo':>9} {'dec_med':>8}")
    for k, q in ((10, 7), (20, 12), (20, 13), (50, 30), (50, 32), (100, 60), (100, 65)):
        for bc in (5, 11, 20):
            r = corre_config(0.33, k, q, beta_conf=bc)
            p(f"{k:4d} {q:4d} {q/k:6.2f} {bc:6d} {r['rondas_med']:10.1f} {r['r90_med']:8.1f} "
              f"{r['rondas_max']:10d} {r['mixtos']:7d} {r['rojos']:9d} {r['dec_med']:8.3f}")
    p("")
    p("--- ESTADO INICIAL PARTIDO (p0) con k=50, q=30, beta_conf=11, alpha=0,33 ---")
    p(f"{'p0':>5} {'rondas_med':>10} {'r90_med':>8} {'rondas_max':>10} {'mixtas':>7} "
      f"{'con_rojo':>9} {'dec_med':>8}")
    for p0 in (1.0, 0.9, 0.8, 0.7, 0.6, 0.5):
        r = corre_config(0.33, 50, 30, beta_conf=11, p0=p0)
        p(f"{p0:5.2f} {r['rondas_med']:10.1f} {r['r90_med']:8.1f} {r['rondas_max']:10d} "
          f"{r['mixtos']:7d} {r['rojos']:9d} {r['dec_med']:8.3f}")
    p("")
    p("--- SENSIBILIDAD AL RETARDO L (proxy de Δ) con k=50, q=30, beta_conf=11, alpha=0,33 ---")
    for p0 in (1.0, 0.7):
        p(f"p0={p0}:")
        p(f"{'L':>4} {'rondas_med':>10} {'r90_med':>8} {'rondas_max':>10} {'mixtas':>7} "
          f"{'con_rojo':>9} {'dec_med':>8}")
        for L in (0, 1, 2, 4, 8, 16, 20):
            r = corre_config(0.33, 50, 30, beta_conf=11, L=L, p0=p0)
            p(f"{L:4d} {r['rondas_med']:10.1f} {r['r90_med']:8.1f} {r['rondas_max']:10d} "
              f"{r['mixtos']:7d} {r['rojos']:9d} {r['dec_med']:8.3f}")
    p("")
    p("--- SENSIBILIDAD A alpha con k=50, q=30, beta_conf=11, p0=1 ---")
    p(f"{'alpha':>6} {'rondas_med':>10} {'r90_med':>8} {'rondas_max':>10} {'mixtas':>7} "
      f"{'con_rojo':>9} {'dec_med':>8}")
    for a in (0.0, 0.10, 0.20, 0.25, 0.30, 0.33, 0.36, 0.40, 0.45, 0.49):
        r = corre_config(a, 50, 30, beta_conf=11)
        p(f"{a:6.2f} {r['rondas_med']:10.1f} {r['r90_med']:8.1f} {r['rondas_max']:10d} "
          f"{r['mixtos']:7d} {r['rojos']:9d} {r['dec_med']:8.3f}")
    p("")
    p("--- SLUSH/SNOWFLAKE (sin amortiguamiento de confianza) vs SNOWBALL, alpha=0,33 ---")
    p(f"{'alpha':>6} {'modo':>10} {'k':>4} {'q':>4} {'rondas_med':>10} {'r90_med':>8} "
      f"{'mixtas':>7} {'con_rojo':>9} {'dec_med':>8}")
    for a in (0.20, 0.33):
        for k, q in ((10, 8), (50, 30)):
            for modo, damp in (("slush", False), ("snowball", True)):
                r = corre_config(a, k, q, beta_conf=11, damping=damp)
                p(f"{a:6.2f} {modo:>10} {k:4d} {q:4d} {r['rondas_med']:10.1f} "
                  f"{r['r90_med']:8.1f} {r['mixtos']:7d} {r['rojos']:9d} {r['dec_med']:8.3f}")
    p("")
    p("--- CONSECUTIVO + CONFIANZA (beta_cons=150 como el paper) con alpha=0,33 ---")
    for k, q in ((10, 6), (20, 12), (50, 30)):
        r = corre_config(0.33, k, q, beta_conf=11, beta_cons=150)
        p(f"k={k:3d} q={q:3d}: rondas_med={r['rondas_med']:.1f} r90={r['r90_med']:.1f} "
          f"mixtas={r['mixtos']}/20 con_rojo={r['rojos']}/20")
    p("")
    with open("salida_agentes.txt", "w") as fh:
        fh.write("\n".join(out) + "\n")


if __name__ == "__main__":
    main()
