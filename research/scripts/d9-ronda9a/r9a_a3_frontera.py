#!/usr/bin/env python3
"""
r9a_a3_frontera.py — LINEA 3. La frontera de flujo unico recalculada.

Reutiliza SIN REESCRIBIR el `prev()` de D8 (d8-ronda8/d8_a1c_riesgo.py:29-40, que a su vez
es literalmente research/scripts/verif_constantes.py:44-50): carrera de Skellam del Lema 10
con ventaja inicial 3k, I = 4 200 s, F = 5,3 h = 19 080 s, 7 509 epocas/ano.

Se calcula la frontera (union a 10 anos < 1e-10) en cuatro modelos:
  (a) delta de D8 con el MISMO alpha en los dos sitios (lo publicado en la auditoria 7)
  (b) Lema 9 como tasa, delta = 0,2105 (rondas 3-8)
  (c) delta = 0 (atacante unico, presupuestos disjuntos)  <- la tesis a auditar
  (d) delta = 0 + parasito AJENO de alpha_p in {10, 20, 33} %
Y el punto r = 1 en cada uno.

Ademas: (e) el `delta` que el atacante puede imponer GRATIS = delta_0 = P(anticono honesto
> k) con anticono ~ Poisson(2*Dmax*lambda) — no cuesta bloques del atacante porque no los usa.
"""
import sys

import numpy as np
from scipy.optimize import brentq
from scipy.stats import poisson, skellam

K = 30
C = 4.0 * 1.0
I_EP = 4200.0
F_SEG = 5.3 * 3600
EP_ANO = 365 * 24 * 3600 / I_EP
ANOS = 10.0

# delta MEDIDO por D8 (salida_a1b.txt) — el que la auditoria 7 propago
MED = {0.00: 0.0000, 0.25: 0.1544, 0.30: 0.2079, 0.33: 0.2867, 0.35: 0.3065,
       0.37: 0.3448, 0.40: 0.4366, 0.45: 0.5834}


def prev(a, lam, t, offset, hf):
    """IDENTICA a d8_a1c_riesgo.py:29-40 / verif_constantes.py:44-50."""
    if a <= 0:
        return 0.0
    mh = (1 - a) * lam * t * hf
    ma = a * lam * t
    r = a / ((1 - a) * hf)
    ds = np.arange(-400, 60000)
    p = skellam.pmf(ds, mh, ma)
    d = ds - offset
    with np.errstate(over="ignore"):
        catch = np.where(d >= 0, np.power(r, np.minimum(d + 1.0, 700)), 1.0)
    return float(np.sum(p * catch))


def delta_interp(a):
    """delta(alpha) de D8, interpolado linealmente (lo que hizo la auditoria 7)."""
    xs = sorted(MED)
    if a <= xs[0]:
        return MED[xs[0]]
    if a >= xs[-1]:
        return MED[xs[-1]]
    for i in range(len(xs) - 1):
        if xs[i] <= a <= xs[i + 1]:
            w = (a - xs[i]) / (xs[i + 1] - xs[i])
            return MED[xs[i]] + w * (MED[xs[i + 1]] - MED[xs[i]])


def union10(a, hf):
    pf = prev(a, 1.0, F_SEG, 3 * K, hf)
    return min(1.0, pf * EP_ANO * ANOS)


def frontera(hf_de_alpha, lo=0.05, hi=0.499):
    """alpha del PRIMER cruce union10 = 1e-10, barriendo en rejilla fina.

    ERROR PROPIO CORREGIDO (declarado en el informe): la primera version usaba brentq sobre
    [lo,hi] y devolvia `hi` cuando f(hi)<0. Con delta>0 la funcion NO es monotona: por encima
    del punto r=1 `prev()` se vuelve vacua y devuelve ~0 (el artefacto del recorte a r^700 que
    D8 declaro), asi que brentq daba 49,9 % en vez de 36,5 %. Se busca el PRIMER cruce."""
    f = lambda a: np.log10(max(union10(a, hf_de_alpha(a)), 1e-320)) + 10.0
    rej = np.arange(lo, hi + 1e-9, 0.0005)
    ant = None
    for a in rej:
        v = f(a)
        if ant is not None and ant[1] < 0 <= v:
            return brentq(f, ant[0], a, xtol=1e-6)
        ant = (a, v)
    return hi if f(hi) >= 0 else float("nan")


def punto_r1(hf_de_alpha, lo=0.05, hi=0.4999):
    f = lambda a: a / ((1 - a) * hf_de_alpha(a)) - 1.0
    if f(hi) < 0:
        return None
    return brentq(f, lo, hi, xtol=1e-6)


if __name__ == "__main__":
    print("=== A3 · frontera de flujo unico, cuatro modelos ===")
    print(f"prev() = d8_a1c_riesgo.py:29-40 (Skellam, ventaja 3k={3*K}), F={F_SEG:.0f} s, "
          f"I={I_EP:.0f} s, {EP_ANO:.0f} epocas/ano, {ANOS:.0f} anos, umbral union < 1e-10.\n")

    d0 = float(poisson.sf(K, 2 * C))
    print(f"(e) delta GRATIS (sin gastar un bloque del atacante): delta_0 = "
          f"P(anticono honesto > k) = P(Poisson(2*D*lam={2*C:.0f}) > {K}) = {d0:.3e}")
    print(f"    -> a efectos de la carrera es CERO (mueve la frontera menos de 1e-6 puntos).\n")

    modelos = [
        ("(a) delta de D8, mismo alpha en los dos sitios", lambda a: 1 - delta_interp(a)),
        ("(b) Lema 9 como tasa, delta = 0,2105", lambda a: 1 - 0.2105),
        ("(b') delta_real = 0,267 (el del diseno)", lambda a: 1 - 0.267),
        ("(c) atacante unico, delta = 0", lambda a: 1.0),
        ("(e) delta = delta_0 natural", lambda a: 1 - d0),
    ]
    print(f"{'modelo':>48} | {'frontera 1e-10':>14} | {'r = 1':>8}")
    for nom, hf in modelos:
        fr = frontera(hf)
        r1 = punto_r1(hf)
        print(f"{nom:>48} | {fr:>13.4%} | {('%.4f' % r1) if r1 else '  >0,50':>8}")

    print("\n--- (d) delta = 0 + PARASITO AJENO alpha_p: la tasa publica baja a 1-alpha_f-alpha_p ---")
    print("    r = alpha_f/(1-alpha_f-alpha_p);  en prev() se implementa con "
          "hf = (1-alpha_f-alpha_p)/(1-alpha_f)")
    print(f"{'alpha_p':>8} | {'frontera para el atacante':>25} | {'suma alpha_f+alpha_p':>21} "
          f"| {'r = 1 en':>9}")
    for ap in (0.0, 0.10, 0.20, 0.33):
        hf = lambda a, ap=ap: (1 - a - ap) / (1 - a) if (1 - a - ap) > 0 else 1e-9
        fr = frontera(hf, hi=min(0.499, 0.999 - ap))
        r1 = punto_r1(hf, hi=min(0.4999, 0.999 - ap))
        print(f"{ap:>8.0%} | {fr:>24.4%} | {fr+ap:>20.4%} | "
              f"{(('%.4f' % r1) if r1 else '  >0,50'):>9}")

    print("\n--- union a 10 anos en los alphas de operacion, con delta = 0 ---")
    print(f"{'alpha':>6} | {'p_F por epoca':>15} {'union 10 anos':>15} {'r':>7} "
          f"| {'union con delta_D8':>18}")
    for a in (0.0, 0.10, 0.25, 0.33, 0.35, 0.37, 0.40, 0.45, 0.469):
        if a == 0:
            print(f"{a:>6.2f} | {0.0:>15.3e} {0.0:>15.3e} {0.0:>7.3f} | {0.0:>18.3e}")
            continue
        pf = prev(a, 1.0, F_SEG, 3 * K, 1.0)
        hfd = 1 - delta_interp(a)
        print(f"{a:>6.3f} | {pf:>15.3e} {min(1.0,pf*EP_ANO*ANOS):>15.3e} "
              f"{a/(1-a):>7.3f} | {min(1.0, prev(a,1.0,F_SEG,3*K,hfd)*EP_ANO*ANOS):>18.3e}")
