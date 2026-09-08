#!/usr/bin/env python3
"""
r9a_a7_frontera_rapida.py — CONTRASTE INDEPENDIENTE de A3/A6.

A3 tarda ~20 min porque `prev()` evalua la pmf de Skellam sobre 60 400 puntos por llamada,
cuando la masa esta en `mh-ma +- 15*sigma`. Aqui se calcula la MISMA integral restringiendo
el soporte, y se comprueba punto a punto contra `prev()` LITERAL de d8_a1c_riesgo.py:29-40.
Si las dos coinciden a 1e-12 relativo, la version rapida vale para barrer la rejilla fina.

Sirve de control cruzado de A3/A6: la frontera de 36,5 % del modelo (a) es un numero ya
publicado en la auditoria 7, asi que reproducirlo valida toda la cadena de calculo.

REGLA 1: fila alpha = 0.  REGLA 4: control positivo (el 36,5 % conocido) ANTES de medir.
"""
import numpy as np
from scipy.optimize import brentq
from scipy.stats import skellam

K = 30
I_EP = 4200.0
F_SEG = 5.3 * 3600
EP_ANO = 365 * 24 * 3600 / I_EP
ANOS = 10.0
MED = {0.00: 0.0000, 0.25: 0.1544, 0.30: 0.2079, 0.33: 0.2867, 0.35: 0.3065,
       0.37: 0.3448, 0.40: 0.4366, 0.45: 0.5834}
DELTA0 = {4.0: 0.0000, 8.0: 0.0020, 12.0: 0.0828, 16.0: 0.2858, 20.0: 0.4428}


def prev_lento(a, lam, t, offset, hf):
    """LITERAL de d8_a1c_riesgo.py:29-40 (no se toca)."""
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


def prev_rapido(a, lam, t, offset, hf, nsig=16.0):
    """MISMA integral, soporte restringido a mh-ma +- nsig*sigma (interseccion con
    [-400, 60000) para que sea la misma suma, no otra)."""
    if a <= 0:
        return 0.0
    mh = (1 - a) * lam * t * hf
    ma = a * lam * t
    r = a / ((1 - a) * hf)
    mu, sg = mh - ma, np.sqrt(mh + ma)
    # ERROR PROPIO CORREGIDO (declarado en el informe): la primera version ponia
    #   lo = mu - nsig*sigma  y  cola_izq = skellam.cdf(lo-1),
    # es decir, sumaba TODA la cola izquierda con catch = 1. Falso: catch vale 1 solo
    # para ds < offset; entre offset y lo vale r^(ds-offset+1), que es ~0. El sesgo era
    # de 1e-58 (irrelevante frente al umbral 1,3e-15 de la frontera, y por eso las
    # fronteras no cambiaron), pero la comprobacion `prev_rapido == prev_lento` fallaba.
    # Arreglo: se baja `lo` hasta `offset`, de modo que TODO lo que queda por debajo
    # tiene catch = 1 exactamente y `cola_izq = skellam.cdf(lo-1)` es correcto.
    lo = max(-400, min(int(mu - nsig * sg) - 2, int(offset)))
    hi = min(60000, int(mu + nsig * sg) + 2)
    if hi <= lo:
        return 0.0
    ds = np.arange(lo, hi)
    p = skellam.pmf(ds, mh, ma)
    d = ds - offset
    with np.errstate(over="ignore"):
        catch = np.where(d >= 0, np.power(r, np.minimum(d + 1.0, 700)), 1.0)
    cola_izq = float(skellam.cdf(lo - 1, mh, ma)) if lo > -400 else 0.0
    return float(np.sum(p * catch)) + cola_izq


def union10(a, hf, f=prev_rapido):
    return min(1.0, f(a, 1.0, F_SEG, 3 * K, hf) * EP_ANO * ANOS)


def frontera(hf_de_alpha, lo=0.05, hi=0.499, paso=0.001):
    g = lambda a: np.log10(max(union10(a, hf_de_alpha(a)), 1e-320)) + 10.0
    ant = None
    for a in np.arange(lo, hi + 1e-9, paso):
        v = g(a)
        if ant is not None and ant[1] < 0 <= v:
            return brentq(g, ant[0], a, xtol=1e-7)
        ant = (a, v)
    return hi if g(hi) >= 0 else float("nan")


def r1(hf, lo=0.05, hi=0.4999):
    f = lambda a: a / ((1 - a) * hf(a)) - 1.0
    return brentq(f, lo, hi, xtol=1e-7) if f(hi) >= 0 else None


def d_interp(a):
    xs = sorted(MED)
    if a <= xs[0]:
        return MED[xs[0]]
    if a >= xs[-1]:
        return MED[xs[-1]]
    for i in range(len(xs) - 1):
        if xs[i] <= a <= xs[i + 1]:
            w = (a - xs[i]) / (xs[i + 1] - xs[i])
            return MED[xs[i]] + w * (MED[xs[i + 1]] - MED[xs[i]])


if __name__ == "__main__":
    print("=== A7 · frontera, version rapida CONTRASTADA contra el prev() de D8 ===\n")
    print("--- control 0: prev_rapido == prev_lento? (el prev_lento es literal de D8) ---")
    print(f"{'alpha':>7} {'hf':>7} | {'prev lento':>14} {'prev rapido':>14} {'err rel':>11}")
    peor = 0.0
    for a in (0.0, 0.10, 0.25, 0.33, 0.35, 0.40, 0.45, 0.469, 0.49):
        for hf in (1.0, 0.7, 1 - 0.2105):
            pl = prev_lento(a, 1.0, F_SEG, 3 * K, hf)
            pr = prev_rapido(a, 1.0, F_SEG, 3 * K, hf)
            er = abs(pr - pl) / pl if pl > 0 else abs(pr - pl)
            peor = max(peor, er)
            if hf == 1.0:
                print(f"{a:>7.3f} {hf:>7.3f} | {pl:>14.6e} {pr:>14.6e} {er:>11.2e}")
    print(f"  peor error relativo sobre las 27 combinaciones: {peor:.3e}  ->  "
          f"{'VALE' if peor < 1e-9 else 'NO VALE'}")
    print("  (rejilla del barrido: 0,001 + brentq; la frontera la refina brentq, la\n"
          "   rejilla solo tiene que ACOTAR el primer cruce)\n")

    print("--- control 1 (positivo): reproducir los numeros YA PUBLICADOS ---")
    fa = frontera(lambda a: 1 - d_interp(a))
    fb = frontera(lambda a: 1 - 0.2105)
    print(f"  modelo (a) delta de D8, mismo alpha en los dos sitios : {fa:.4%}  "
          f"(auditoria 7 publica ~36,5 %)")
    print(f"  modelo (b) Lema 9 como tasa, delta = 0,2105           : {fb:.4%}  "
          f"(rondas 3-8 publican ~40,8 %)")
    print("  Si estos dos salen, la cadena de calculo esta validada y lo de abajo es fiable.\n")

    print("--- LA FRONTERA, los modelos que decide esta ronda ---")
    print(f"{'modelo':>52} | {'frontera 1e-10':>15} | {'r = 1':>8} | {'vs 33 %':>8}")
    for nom, hf in [
        ("(a) delta de D8, mismo alpha en los dos sitios", lambda a: 1 - d_interp(a)),
        ("(b) Lema 9 como tasa, delta = 0,2105", lambda a: 1 - 0.2105),
        ("(b') delta_real = 0,267 (el que el diseno publica)", lambda a: 1 - 0.267),
        ("(c) ATACANTE UNICO, delta = 0  <- la tesis", lambda a: 1.0),
    ]:
        fr, p1 = frontera(hf), r1(hf)
        print(f"{nom:>52} | {fr:>14.4%} | {(('%.4f' % p1) if p1 else ' >0,50'):>8} | "
              f"{fr-0.33:>+7.2%}")

    print(f"\n--- (e) delta que compra un atacante de RED subiendo Delta (delta_0 de L2b) ---")
    print(f"{'Delta (s)':>10} {'delta_0 (alpha=0)':>18} | {'frontera':>10} | {'r=1':>8} "
          f"| {'vs 33 %':>8}")
    for D in sorted(DELTA0):
        d0 = DELTA0[D]
        hf = lambda a, d0=d0: 1 - d0
        fr, p1 = frontera(hf), r1(hf)
        marca = "  <- DISENO" if D == 4 else ("  <- LAGUNA de D8" if D == 8 else "")
        print(f"{D:>10.0f} {d0:>18.4f} | {fr:>9.4%} | {(('%.4f' % p1) if p1 else ' >0,50'):>8} "
              f"| {fr-0.33:>+7.2%}{marca}")

    print("\n--- (d) parasito racional AJENO de cuota alpha_p, con delta = 0 ---")
    print(f"{'alpha_p':>8} | {'frontera del atacante':>22} | {'suma af+ap':>11} | {'r=1':>8} "
          f"| {'vs 33 %':>8}")
    for ap in (0.0, 0.10, 0.20, 0.33):
        hf = lambda a, ap=ap: max(1e-9, (1 - a - ap) / (1 - a))
        fr = frontera(hf, hi=min(0.499, 0.99 - ap))
        p1 = r1(hf, hi=min(0.4999, 0.99 - ap))
        print(f"{ap:>8.0%} | {fr:>21.4%} | {fr+ap:>10.2%} | "
              f"{(('%.4f' % p1) if p1 else ' >0,50'):>8} | {fr-0.33:>+7.2%}")
