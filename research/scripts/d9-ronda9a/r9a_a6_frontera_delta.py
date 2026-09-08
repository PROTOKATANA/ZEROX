#!/usr/bin/env python3
"""
r9a_a6_frontera_delta.py — LINEA 6 (nueva del relanzamiento). La frontera de flujo unico bajo
la LAGUNA que L2b abre: `delta` no lo impone el atacante con espacio, lo impone `Delta`.

A3 (r9a_a3_frontera.py) calcula la frontera con delta = 0 y con los delta de D8. Falta el
regimen que L2b encontro: un atacante de RED (eclipse parcial, inundacion — la linea A3 de D8)
que suba el retardo honesto<->honesto efectivo compra `delta` SIN GASTAR ESPACIO. Aqui se
recalcula la frontera con el `delta_0` MEDIDO en L2b (`salida_a1b.txt`), no con la cola de
Poisson: la cola P(Poisson(2*Delta*lambda) > k) SOBREESTIMA (a Delta=16 da 0,59 y lo medido es
0,286), porque el anticono honesto real no es Poisson(2*Delta*lambda) exacto.

Reusa `prev()` de d8_a1c_riesgo.py:29-40 SIN REESCRIBIRLO (misma formula, mismos parametros).
Frontera = primer cruce de union(10 anos) = 1e-10 (rejilla 0,005 + brentq, no brentq directo:
la funcion NO es monotona, error propio que el D9 anterior ya declaro en A3).

REGLA 1: fila alpha = 0 / delta = 0 en toda tabla.  REGLA 6: cota != realidad.
"""
import numpy as np
from scipy.optimize import brentq
from scipy.stats import skellam

K = 30
I_EP = 4200.0
F_SEG = 5.3 * 3600
EP_ANO = 365 * 24 * 3600 / I_EP
ANOS = 10.0

# delta_0 MEDIDO en L2b (r9a_a1b_control.py -> salida_a1b.txt), a alpha = 0: sin que el
# atacante gaste UN SOLO BLOQUE. Es el `delta` que compra un atacante de RED, no de espacio.
DELTA0_MEDIDO = {4.0: 0.0000, 8.0: 0.0020, 12.0: 0.0828, 16.0: 0.2858,
                 20.0: 0.4428, 24.0: 0.5401, 32.0: 0.6526}


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


def union10(a, hf):
    return min(1.0, prev(a, 1.0, F_SEG, 3 * K, hf) * EP_ANO * ANOS)


def frontera(hf_de_alpha, lo=0.05, hi=0.499, paso=0.005):
    f = lambda a: np.log10(max(union10(a, hf_de_alpha(a)), 1e-320)) + 10.0
    rej = np.arange(lo, hi + 1e-9, paso)
    ant = None
    for a in rej:
        v = f(a)
        if ant is not None and ant[1] < 0 <= v:
            return brentq(f, ant[0], a, xtol=1e-6)
        ant = (a, v)
    return hi if f(hi) >= 0 else float("nan")


def r1(hf_de_alpha, lo=0.05, hi=0.4999):
    f = lambda a: a / ((1 - a) * hf_de_alpha(a)) - 1.0
    return brentq(f, lo, hi, xtol=1e-6) if f(hi) >= 0 else None


if __name__ == "__main__":
    print("=== A6 · la frontera bajo la LAGUNA de Delta (delta que NO cuesta espacio) ===")
    print(f"prev() = d8_a1c_riesgo.py:29-40 (Skellam, ventaja 3k={3*K}), F={F_SEG:.0f} s, "
          f"{EP_ANO:.0f} epocas/ano, 10 anos, umbral 1e-10.")
    print("delta_0 MEDIDO en L2b a alpha=0 (no la cola de Poisson, que sobreestima).\n")

    print(f"{'Delta (s)':>10} {'delta_0 medido':>15} | {'frontera 1e-10':>15} {'r = 1':>9} "
          f"| {'colchon sobre 33 %':>19}")
    for D in sorted(DELTA0_MEDIDO):
        d0 = DELTA0_MEDIDO[D]
        hf = lambda a, d0=d0: 1 - d0
        fr = frontera(hf)
        p1 = r1(hf)
        marca = "  <- DISENO" if D == 4.0 else ("  <- LAGUNA de D8" if D == 8.0 else "")
        print(f"{D:>10.0f} {d0:>15.4f} | {fr:>14.4%} "
              f"{(('%.4f' % p1) if p1 else '  >0,50'):>9} | {fr-0.33:>+18.2%}{marca}")

    print("\n--- control delta = 0 exacto (la tesis del agente principal) ---")
    fr0 = frontera(lambda a: 1.0)
    print(f"{'delta = 0':>10} {0.0:>15.4f} | {fr0:>14.4%} {'0.5000':>9} | {fr0-0.33:>+18.2%}")

    print("\n--- (d) parasito racional AJENO de cuota alpha_p, con delta = 0 ---")
    print("    la tasa publica baja a (1 - alpha_f - alpha_p): hf = (1-af-ap)/(1-af)")
    print(f"{'alpha_p':>8} | {'frontera del atacante':>22} | {'suma af+ap':>11} | "
          f"{'r = 1 en':>9} | {'vs 33 %':>9}")
    for ap in (0.0, 0.10, 0.20, 0.33):
        hf = lambda a, ap=ap: max(1e-9, (1 - a - ap) / (1 - a))
        hi = min(0.499, 0.995 - ap)
        fr = frontera(hf, hi=hi)
        p1 = r1(hf, hi=min(0.4999, 0.995 - ap))
        print(f"{ap:>8.0%} | {fr:>21.4%} | {fr+ap:>10.2%} | "
              f"{(('%.4f' % p1) if p1 else '  >0,50'):>9} | {fr-0.33:>+8.2%}")

    print("\nLECTURA: el atacante de ESPACIO no mueve la frontera de 46,9 % (L1-bis: parasitar")
    print("le quita espacio a la carrera). Quien la mueve es (i) un atacante de RED que suba")
    print("Delta y (ii) un parasito racional AJENO, que es espacio que no es del atacante.")
