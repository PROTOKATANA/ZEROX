#!/usr/bin/env python3
"""
Propaga el delta REAL bajo sesgo sostenido del retarget (verif_retarget_sesgo.py: a k=25,
lambda_real=1,47/s, delta_real=0,320 frente al nominal 0,2424) a los tres números que dependen de él:
 (a) umbral de ORDEN  alpha* = (1-delta)/(phi_c + 1 - delta)  con phi_500 = 1,1023
 (b) umbral de FLUJO ÚNICO: base r = alpha/((1-alpha)(1-delta)) y la unión a 10 años (F=3,2 h)
 (c) el óptimo de k con (lambda_real(k), delta_real(k)) autoconsistentes.
"""
import math, numpy as np
from scipy.stats import skellam
D, LOBJ, PHI500, F, I = 4.0, 1.0, 1.1023, 3.2*3600, 2490.0
EP10 = 10*365*86400/I
def prev(a, lam, t, offset, hf):
    mh=(1-a)*lam*t*hf; ma=a*lam*t; r=a/((1-a)*hf)
    ds=np.arange(-400,20000); p=skellam.pmf(ds,mh,ma); d=ds-offset
    with np.errstate(over="ignore"):
        catch=np.where(d>=0, np.power(r, np.minimum(d+1.0,700)), 1.0)
    return float(np.sum(p*catch))
def lreal(k): return k*LOBJ/(k-2*D*LOBJ)
def dreal(k): l=lreal(k); return 2*D*l/(k+2*D*l)
K=25; dn=2*D*LOBJ/(K+2*D*LOBJ); dr=dreal(K); lr=lreal(K)
print(f"k={K}: delta nominal={dn:.4f} (sin ataque)   delta real={dr:.4f}, lambda_real={lr:.3f}/s (sesgo sostenido)\n")
print("(a) umbral de ORDEN, phi_500:")
for nom,d in (("nominal",dn),("real",dr)):
    print(f"    delta {nom:7s}: alpha* = {(1-d)/(PHI500+1-d):.1%}")
print("\n(b) umbral de FLUJO ÚNICO (unión a 10 años, F=3,2 h):")
print(f"    {'alpha':>6} | {'r nominal':>10} {'P10a nominal':>13} | {'r real':>8} {'P10a real':>11}")
for a in (0.25,0.30,0.33,0.35,0.38,0.40):
    rn=a/((1-a)*(1-dn)); rr=a/((1-a)*(1-dr))
    pn=min(1,prev(a,LOBJ,F,3*K,1-dn)*EP10); pr=min(1,prev(a,lr,F,3*K,1-dr)*EP10)
    print(f"    {a:6.2f} | {rn:10.3f} {pn:13.2e} | {rr:8.3f} {pr:11.2e}")
print(f"    r=1 en alpha = (1-delta)/(2-delta):  nominal {(1-dn)/(2-dn):.1%}   real {(1-dr)/(2-dr):.1%}")
print("\n(c) óptimo de k con (lambda_real(k), delta_real(k)) autoconsistentes, alpha=0,25, t=600 s:")
best=None
for k in (20,22,24,25,26,28,30,35,40):
    l=lreal(k); d=dreal(k); p=prev(0.25,l,600,3*k,1-d)
    best = (k,p) if best is None or p<best[1] else best
    print(f"    k={k:3d} lambda_real={l:.3f} delta_real={d:.3f} reversión(600 s)={p:.2e}")
print(f"    óptimo: k = {best[0]}")
