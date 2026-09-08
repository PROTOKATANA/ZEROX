#!/usr/bin/env python3
"""
d8_a1c_riesgo.py — A1 (tercera parte). El `delta` medido en A1/A1b, propagado a los DOS
numeros que el diseno publica, con el MISMO modelo que el diseno usa
(`research/scripts/verif_constantes.py` §3, carrera de Nakamoto de Skellam con ventaja
inicial 3k, Lema 10; y `dag-poas-recursion-flujos.md` §3 para `p_F` por epoca).

Entrada: `delta(alpha)` MEDIDO por d8_a1b_umbral.py (maniobra parasita, 12 semillas,
horizonte 1800 s). Se compara, fila a fila, con `delta` = 0,2105 (nominal del Lema 9) y
0,267 (`delta_real`, el que el diseno usa para publicar 40,0 % y ~35 %).

No hay `alpha` libre que valga: cada fila ES un alpha, y la fila alpha=0 da riesgo 0.
"""
import numpy as np
from scipy.stats import skellam

K = 30
C = 4.0 * 1.0                       # Dmax * lambda
I_EP = 4200.0
F_SEG = 5.3 * 3600                  # 19 080 s
EP_ANO = 365 * 24 * 3600 / I_EP

# delta MEDIDO (d8_a1b_umbral.py, salida_a1b.txt, horizonte 1800 s, 12 semillas)
MED = {0.00: 0.0000, 0.25: 0.1544, 0.30: 0.2079, 0.33: 0.2867, 0.35: 0.3065,
       0.37: 0.3448, 0.40: 0.4366, 0.45: 0.5834}


def prev(a, lam, t, offset, hf):
    """Idéntica a verif_constantes.py:44-50 (no se reescribe el modelo, se reusa)."""
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


if __name__ == "__main__":
    print("=== A1c · el `delta` medido propagado al riesgo publicado ===")
    print(f"k={K}, lambda=1, Dmax=4, ventaja inicial 3k={3*K} (Lema 10), "
          f"I={I_EP:.0f} s, F={F_SEG:.0f} s ({F_SEG/3600:.1f} h), "
          f"{EP_ANO:.0f} epocas/ano.\n")
    print(f"{'alpha':>6} {'delta':>8} {'fuente':>10} | {'rev. 600 s':>12} "
          f"{'p_F por epoca':>15} {'union 10 anos':>15} {'r':>7}")
    for a in sorted(MED):
        for d, et in ((MED[a], "MEDIDO"), (0.2105, "Lema 9"), (0.267, "delta_real")):
            hf = 1 - d
            r = a / ((1 - a) * hf) if a > 0 else 0.0
            rev = prev(a, 1.0, 600, 3 * K, hf)
            pf = prev(a, 1.0, F_SEG, 3 * K, hf)
            print(f"{a:>6.2f} {d:>8.4f} {et:>10} | {rev:>12.3e} {pf:>15.3e} "
                  f"{min(1.0, pf*EP_ANO*10):>15.3e} {r:>7.3f}")
        print()
