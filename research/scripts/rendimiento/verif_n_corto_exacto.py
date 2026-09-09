#!/usr/bin/env python3
"""
verif_n_corto_exacto.py — tiempo de reaccion EXACTO de la mediana corta, bloque a bloque, sin atajos.

Escenario: cadena madura (Mlt = ZONA_LIBRE), de golpe llega una demanda sostenida de 1 280 tx/s
(448 000 B/bloque). Tres momentos:
  1. primer salto: la mediana corta cruza y LIMITE se dobla por primera vez  (~N/2 + 1 bloques)
  2. capacidad: LIMITE >= demanda, la cola deja de crecer                     (k saltos de N/2)
  3. absorbida: cola = 0 y subsidio entero                                    (+ vaciado)
Reglas C-WGT-04/05/06/08/09 y C-EMIT-06 (citas en verif_600tps.py). lambda = 1 bloque/s.
"""
from collections import deque
BREK=10**8; ZL=100_000; SURGE=50; TX_B=350; BASE=(10**9*BREK)>>26
def get_mid(a,b): return (a//2)+(b//2)+((a-2*(a//2))+(b-2*(b//2)))//2
def med(v):
    s=sorted(v); n=len(s); return s[n//2] if n%2 else get_mid(s[n//2-1],s[n//2])
def subs(base,x,M):
    if x<=M: return base
    return (base*x*(2*M-x))//M//M if x<=2*M else None
def reaccion(tx_s, n, horizonte=20000):
    dem=tx_s*TX_B; w=deque([ZL]*n,maxlen=n); back=0
    salto=cap=absor=None; lim0=2*ZL
    for h in range(1,horizonte+1):
        Mst=med(w); M=max(min(max(ZL,Mst),SURGE*ZL),ZL); lim=2*M
        if salto is None and lim>lim0: salto=h
        if cap is None and lim>=dem: cap=h
        x=int(min(lim,back+dem)); back=max(0,back+dem-x)
        s=subs(BASE,x,M); w.append(x)
        if absor is None and s==BASE and back==0: absor=h; break
    return salto,cap,absor
if __name__=="__main__":
    print(f"{'N_CORTO':>8}{'1er salto':>11}{'capacidad':>11}{'absorbida':>11}{'= min:seg':>11}")
    for n in (990,995,998,999,1000,1001,1002,1005,1010,1020):
        s,c,a=reaccion(1280,n)
        print(f"{n:>8}{s:>9} s{c:>9} s{a:>9} s{a//60:>8}:{a%60:02d}")
    print("\nCon N_CORTO = 1 000, otros tamanos de rafaga:")
    print(f"{'demanda':>9}{'1er salto':>11}{'capacidad':>11}{'absorbida':>11}{'= min:seg':>11}")
    for tx in (300,600,1280,2500,5000):
        s,c,a=reaccion(tx,1000)
        print(f"{tx:>9}{s:>9} s{c:>9} s{a:>9} s{a//60:>8}:{a%60:02d}")
