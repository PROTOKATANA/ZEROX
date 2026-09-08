#!/usr/bin/env python3
"""
Recursión R-FIN-5/R-FIN-7 contra la Propiedad 1 (D9-b, A4): cerrar la LAGUNA «la constante c de
Prop. 7 no está calculada» con lo que el paper SÍ da. Lema 10 (phantom-ghostdag.txt L1226-1236):
la distribución estacionaria de la ventaja tiene exponente de base alpha/((1-alpha)(1-delta)) y el
proceso se desplaza 3k (Freeloader Bound). Es exactamente la carrera de bloques de
verif_constantes.py §3. Con ella: P(desacuerdo sobre I_j a profundidad F) por época, y la cota de
la unión sobre las épocas de vida del sistema.
"""
import math, numpy as np
from scipy.stats import skellam
def prev(a, lam, t, offset, hf):
    mh=(1-a)*lam*t*hf; ma=a*lam*t; r=a/((1-a)*hf)
    ds=np.arange(-400,20000); p=skellam.pmf(ds,mh,ma); d=ds-offset
    with np.errstate(over="ignore"):
        catch=np.where(d>=0, np.power(r, np.minimum(d+1.0,700)), 1.0)
    return float(np.sum(p*catch))
K, C = 25, 4.0; DELTA = 2*C/(K+2*C); F = 3.2*3600; I = 2490.0
EPOCAS_ANO = 365*86400/I
print(f"k={K} delta={DELTA:.4f}  F={F:.0f}s  I={I:.0f}s  épocas/año={EPOCAS_ANO:,.0f}\n")
print(f"{'alpha':>6} {'base r':>8} {'P(reorg>F) por época':>22} {'unión 1 año':>12} {'unión 10 años':>14}")
print("-"*68)
for a in (0.10, 0.25, 0.33, 0.40, 0.45):
    r = a/((1-a)*(1-DELTA))
    p = prev(a, 1.0, F, 3*K, 1-DELTA)
    print(f"{a:6.2f} {r:8.4f} {p:22.2e} {min(1,p*EPOCAS_ANO):12.2e} {min(1,p*EPOCAS_ANO*10):14.2e}")
print("\nUmbral donde la base r cruza 1 (la deriva deja de favorecer al honesto):")
a_star = (1-DELTA)/(1+(1-DELTA)); print(f"   r=1  <=>  alpha = (1-delta)/(2-delta) = {a_star:.4f}  ({a_star:.1%})")
print("   Coincide con el 37,5 % que D9-a midió con delta_ef; con el delta del paper es 43,1 %.")
