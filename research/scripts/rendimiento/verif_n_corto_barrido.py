#!/usr/bin/env python3
"""
verif_n_corto_barrido.py — N_CORTO entre 100 y 1 000: captura por azar del atacante al 33 % (binomial
exacta) y tiempo de absorcion de una rafaga de 1 280 tx/s (mismo instrumento que verif_n_corto.py).
Cota del inflado gratis por evento: la ventana entera (N bloques) a 5 MB con subsidio entero, que es lo
que permite una mediana corta capturada en 50*Mlt (C-WGT-08).
"""
from math import comb
from collections import deque
def p_mayoria(n,a): return sum(comb(n,k)*a**k*(1-a)**(n-k) for k in range((n//2)+1,n+1))
BREK=10**8; ZL=100_000; SURGE=50; TX_B=350; BASE=(10**9*BREK)>>26
def get_mid(a,b): return (a//2)+(b//2)+((a-2*(a//2))+(b-2*(b//2)))//2
def med(v):
    s=sorted(v); n=len(s); return s[n//2] if n%2 else get_mid(s[n//2-1],s[n//2])
def subs(base,x,M):
    if x<=M: return base
    return (base*x*(2*M-x))//M//M if x<=2*M else None
def absorcion(tx_s,n):
    dem=tx_s*TX_B; w=deque([ZL]*n,maxlen=n); back=0; cola_max=0
    for h in range(1,20001):
        Mst=med(w); M=max(min(max(ZL,Mst),SURGE*ZL),ZL); lim=2*M
        x=int(min(lim,back+dem)); back=max(0,back+dem-x); cola_max=max(cola_max,back)
        s=subs(BASE,x,M); w.append(x)
        if s==BASE and back==0: return h, cola_max/TX_B
    return None, cola_max/TX_B
if __name__=="__main__":
    print(f"{'N_CORTO':>8}{'P(mayoria, 33 %)':>18}{'un evento cada':>16}{'GB gratis/anio':>16}{'1280 tx/s en':>14}{'cola max (tx)':>15}")
    for n in (100,200,300,500,1000):
        p=p_mayoria(n,0.33); ev_dia=p*86400/n
        cada = f"{1/ev_dia:,.0f} dias" if ev_dia>1e-9 else "nunca"
        gb=ev_dia*365*(n*5e6)/1e9
        t,cola=absorcion(1280,n)
        print(f"{n:>8}{p:>18.2e}{cada:>16}{gb:>16.1f}{(str(t)+' s'):>14}{cola:>15,.0f}".replace(",", " "))
