#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
snowball_ctmc.py — Cadena de nacimiento-muerte de Snowflake/Slush con adversario,
según arXiv:1906.08936 Apéndice A.2/A.3.

Estados i = número de nodos honestos que prefieren azul. Población n = c + f.
Los adversarios responden SIEMPRE rojo (estrategia del paper, A.3). Tasas:
    mu_i  = i      * H(n, c-i+f, k, q)     (azul -> rojo)
    lam_i = (c-i)  * H(n, i,     k, q)     (rojo -> azul)
con H(N,x,k,q) = P(Hypergeom(N,x,k) >= q).

CON f>0 EL ESTADO i=c NO ES ABSORBENTE: mu_c = c*H(n,f,k,q) > 0. Por eso:
  - "frontera" = último i donde mu_i >= lam_i (frontera del valle).
  - MTTF(i->0) = tiempo medio hasta que TODOS los honestos caen a rojo,
    con 0 absorbente y c reflectante. Recurrencia estable hacia atrás:
        d_c = 1/mu_c ;  d_i = (lam_i*d_{i+1} + 1)/mu_i ;  MTTF = sum d_i.
  - Con la aproximación de Poisson, P(fallo en horizonte T) ~ T/MTTF.
  - p_adv^beta = cota de que UN nodo encadene beta chits rojos.

Control positivo: f=0,20, k=10, q=8 (parámetros desplegados del paper, :1022)
debe dar MTTF >> 10^24 años (el paper declara MTTF ~10^24 años, :1023).
"""
import numpy as np
from scipy.stats import hypergeom
import mpmath as mp

mp.mp.dps = 60
N_DEFAULT = 10000


def H(n, x, k, q):
    if q <= 0:
        return 1.0
    if x < q:
        return 0.0
    if x >= n:
        return 1.0 if k >= q else 0.0
    return float(hypergeom.sf(q - 1, n, x, k))


def cadena(n, f, k, q):
    c = n - f
    i = np.arange(c + 1)
    mu = np.array([H(n, c - ii + f, k, q) for ii in i]) * i
    lam = np.array([H(n, ii, k, q) for ii in i]) * (c - i)
    mu[0] = 0.0
    lam[c] = 0.0
    ratio = np.divide(mu[1:c], lam[1:c], out=np.full(c - 1, np.inf), where=lam[1:c] > 0)
    idx = np.where(ratio >= 1.0)[0]
    frontera = (idx[-1] + 1) / c if len(idx) else 0.0
    return dict(c=c, mu=mu, lam=lam, frontera=frontera,
                p_adv=H(n, f, k, q), p_hon=H(n, c, k, q))


def mttf_log10(r, i0):
    """log10 del tiempo medio (rondas) hasta i=0 partiendo de i0, 0 absorbente, c reflectante."""
    c, mu, lam = r["c"], r["mu"], r["lam"]
    d = mp.mpf(1) / mp.mpf(mu[c])
    total = d
    for i in range(c - 1, 0, -1):
        d = (mp.mpf(lam[i]) * d + 1) / mp.mpf(mu[i])
        total += d
    # fracción de la suma hasta i0 no es trivial: recalculamos sumando d_i para i<=i0
    d = mp.mpf(1) / mp.mpf(mu[c])
    total_i0 = d if i0 == c else mp.mpf(0)
    for i in range(c - 1, 0, -1):
        d = (mp.mpf(lam[i]) * d + 1) / mp.mpf(mu[i])
        if i <= i0:
            total_i0 += d
    return float(mp.log10(total_i0)), float(mp.log10(total))


def fila(n, f, k, q):
    r = cadena(n, f, k, q)
    c = r["c"]
    l10_c, _ = mttf_log10(r, c)
    l10_90, _ = mttf_log10(r, int(0.90 * c))
    l10_80, _ = mttf_log10(r, int(0.80 * c))
    return dict(n=n, f=f, k=k, q=q, qk=q / k, c=c,
                p_adv=r["p_adv"], p_hon=r["p_hon"], frontera=r["frontera"],
                l10_c=l10_c, l10_90=l10_90, l10_80=l10_80)


def main():
    n = N_DEFAULT
    out = []

    def p(s):
        out.append(s)
        print(s)

    p("=" * 108)
    p(f"CTMC Snowflake/Slush con adversario · n={n} · arXiv:1906.08936 A.2/A.3")
    p("i = honestos azules; adversarios siempre rojo. MTTF = rondas medias hasta que TODOS caen a rojo.")
    p("log10(MTTF en rondas). 1 año ~ 3,15e7 rondas/s a 1 ronda/s. 10^24 años ~ 10^31,5 rondas.")
    p("=" * 108)
    p("")
    p("--- CONTROL POSITIVO: parametros desplegados del paper (k=10, q=8) ---")
    p(f"{'f':>6} {'frontera_i/c':>12} {'p_adv':>12} {'p_hon':>12} {'log10 MTTF_c':>14} "
      f"{'log10 MTTF_c (años)':>20} {'log10 MTTF_90':>14}")
    for f in (0.10, 0.20, 0.25, 0.30, 0.33):
        r = fila(n, int(f * n), 10, 8)
        p(f"{f:6.2f} {r['frontera']:12.4f} {r['p_adv']:12.3e} {r['p_hon']:12.3e} "
          f"{r['l10_c']:14.1f} {r['l10_c'] - 7.5:20.1f} {r['l10_90']:14.1f}")
    p("")
    p("--- REJILLA ZEROX: f=0,33, q/k en (0,5; 0,67) ---")
    p(f"{'k':>4} {'q':>4} {'q/k':>6} {'frontera_i/c':>12} {'p_adv':>12} {'p_hon':>12} "
      f"{'log10 MTTF_c':>14} {'log10 MTTF_c (años)':>20} {'log10 MTTF_90':>14}")
    for k, q in ((10, 7), (20, 12), (20, 13), (50, 30), (50, 32), (100, 60), (100, 65)):
        r = fila(n, int(0.33 * n), k, q)
        p(f"{k:4d} {q:4d} {r['qk']:6.2f} {r['frontera']:12.4f} {r['p_adv']:12.3e} "
          f"{r['p_hon']:12.3e} {r['l10_c']:14.1f} {r['l10_c'] - 7.5:20.1f} "
          f"{r['l10_90']:14.1f}")
    p("")
    p("--- SENSIBILIDAD A f con k=50, q=30 (q/k=0,60) ---")
    p(f"{'f':>6} {'frontera_i/c':>12} {'p_adv':>12} {'p_hon':>12} "
      f"{'log10 MTTF_c':>14} {'log10 MTTF_90':>14}")
    for f in (0.10, 0.20, 0.25, 0.30, 0.33, 0.36, 0.40):
        r = fila(n, int(f * n), 50, 30)
        p(f"{f:6.2f} {r['frontera']:12.4f} {r['p_adv']:12.3e} {r['p_hon']:12.3e} "
          f"{r['l10_c']:14.1f} {r['l10_90']:14.1f}")
    p("")
    p("--- SENSIBILIDAD A n con f=0,33, k=50, q=30 (n = tamano de la ventana) ---")
    p(f"{'n':>8} {'frontera_i/c':>12} {'p_adv':>12} {'log10 MTTF_c':>14} {'log10 MTTF_90':>14}")
    for nn in (500, 1000, 2000, 5000, 10000, 50000):
        r = fila(nn, int(0.33 * nn), 50, 30)
        p(f"{nn:8d} {r['frontera']:12.4f} {r['p_adv']:12.3e} {r['l10_c']:14.1f} {r['l10_90']:14.1f}")
    p("")
    p("--- P(fallo en horizonte T) ~ T/MTTF, con f=0,33, k=50, q=30, 1 ronda/s ---")
    r = fila(n, int(0.33 * n), 50, 30)
    p(f"frontera = {r['frontera']:.4f} de los honestos; p_adv = {r['p_adv']:.3e}")
    p(f"{'T (s)':>8} {'log10 P_fallo_c':>16} {'log10 P_fallo_90':>16}")
    for T in (30, 60, 130.41, 300, 600, 1800, 3600):
        p(f"{T:8.1f} {np.log10(T) - r['l10_c']:16.1f} {np.log10(T) - r['l10_90']:16.1f}")
    p("")
    p("--- FRACCION HONESTA ONLINE NECESARIA (sesgo de respuesta) ---")
    p("Si solo responde una fraccion p_h de los honestos y el adversario responde siempre,")
    p("la fraccion adversaria entre RESPONDEDORES es a/(a+(1-a)p_h); debe quedar < 1-q/k.")
    p(f"{'alpha':>6} {'q/k=0,55':>10} {'q/k=0,60':>10} {'q/k=0,65':>10}")
    for a in (0.10, 0.20, 0.25, 0.30, 0.33, 0.40):
        vals = []
        for qk in (0.55, 0.60, 0.65):
            ph = a * (1 - qk) / (qk * (1 - a)) if a < qk else 1.0
            vals.append(min(1.0, ph))
        p(f"{a:6.2f} {vals[0]:10.3f} {vals[1]:10.3f} {vals[2]:10.3f}")
    p("")
    with open("salida_ctmc.txt", "w") as fh:
        fh.write("\n".join(out) + "\n")


if __name__ == "__main__":
    main()
