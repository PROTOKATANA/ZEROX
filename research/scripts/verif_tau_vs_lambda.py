#!/usr/bin/env python3
"""
La bifurcación que deja D9-f B0 con las constantes de Autonomys (subspace-runtime/src/lib.rs:145-165):
Autonomys: SLOT_DURATION = 1 s, SLOT_PROBABILITY = 1/6  =>  6 slots de PoT por bloque.
ZEROX a lambda = 1 bloque/s con tau = 1 s  =>  1 slot por bloque: R-FIN-1a estricta invalida 24-29 % de la cadena.
Dos salidas: (A) tau ~ 0,1 s manteniendo lambda = 1/s   (B) lambda = 1/6 manteniendo tau = 1 s.
"""
import math, numpy as np
from scipy.stats import skellam, poisson
D=4.0
def prev(a,lam,t,offset,hf):
    mh=(1-a)*lam*t*hf; ma=a*lam*t; r=a/((1-a)*hf)
    ds=np.arange(-400,20000); p=skellam.pmf(ds,mh,ma); d=ds-offset
    with np.errstate(over="ignore"): catch=np.where(d>=0,np.power(r,np.minimum(d+1.0,700)),1.0)
    return float(np.sum(p*catch))
def kopt(lam):
    best=None
    for k in range(6,80):
        lr=k*lam/(k-2*D*lam) if k>2*D*lam else None
        if lr is None: continue
        dr=2*D*lr/(k+2*D*lr); p=prev(0.25,lr,600,3*k,1-dr)
        if best is None or p<best[1]: best=(k,p,dr,lr)
    return best
print(f"{'rama':>22} {'lambda':>7} {'tau':>6} {'slots/bloque':>12} {'k*':>4} {'delta_real':>10} {'rev 600s':>10} {'cabeceras/año':>14} {'latencia':>9} {'slots PoT/s':>11}")
print("-"*116)
for nom,lam,tau in [("(A) tau=0,1 s",1.0,0.1),("(A') tau=1/6 s",1.0,1/6),("(B) lambda=1/6",1/6,1.0),("Autonomys",1/6,1.0)]:
    k,p,dr,lr=kopt(lam)
    cab=365*86400*lam*683/1e9
    print(f"{nom:>22} {lam:7.3f} {tau:6.3f} {1/(lam*tau):12.1f} {k:4d} {dr:10.3f} {p:10.2e} {cab:11.1f} GB {1/lam:7.1f} s {1/tau:11.0f}")
print("""
Lectura:
 (A) conserva todo lo derivado (k=30, delta, 21,5 GB/año, 1 s de latencia) y multiplica por 10 los slots
     de PoT por segundo: la justificación de PoT por bloque (128 B/slot) y la verificación crecen x10,
     y el DoS de S_max (D9-d A4.3) se mide en slots de PoT, no en bloques. Es la proporción de Autonomys.
 (B) cambia TODAS las constantes: lambda=1/6 => k* menor, delta menor, cabeceras /6 (3,6 GB/año: el
     cliente ligero pasa de 5 100x Bitcoin a 850x), latencia 6 s, y hay que rehacer I, F, m con lambda=1/6.
     Pierde 6x en granularidad de recompensa (varianza del granjero pequeño) y en 'sin huérfanos' relativo.
 Es una bifurcación de Katana. Ninguna de las dos está elegida.""")
