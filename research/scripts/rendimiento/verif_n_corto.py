#!/usr/bin/env python3
"""
verif_n_corto.py — N_CORTO decide cuanto tarda la sobrecarga en abrirse.

N_CORTO = 100 bloques = 200 min a T=120 s (SPEC.md:921). A lambda=1 hay dos lecturas:
  - en bloques (100): la mediana corta reacciona en ~50 s
  - en tiempo (12 000): reacciona en ~6 000 s = 1,7 h
Mientras no reacciona, LIMITE = 2*Mlt = 200 000 B y el granjero que lo llena cobra subsidio 0.
Reglas: C-WGT-04/05/06/08/09, C-EMIT-06 (citas en verif_600tps.py). Cadena madura, Mlt = ZONA_LIBRE.
"""
from collections import deque
BREK = 10**8; ZL = 100_000; SURGE = 50; TX_B = 350; BASE = (10**9 * BREK) >> 26
def get_mid(a, b): return (a//2)+(b//2)+((a-2*(a//2))+(b-2*(b//2)))//2
def med(v):
    s = sorted(v); n = len(s); return s[n//2] if n % 2 else get_mid(s[n//2-1], s[n//2])
def subs(base, x, M):
    if x <= M: return base
    return (base*x*(2*M-x))//M//M if x <= 2*M else None
def transicion(tx_s, n_corto, horizonte):
    dem = tx_s*TX_B; w = deque([ZL]*n_corto, maxlen=n_corto); back = 0; perd = 0; est = None; cola_max = 0; Mst_c = ZL
    for h in range(1, horizonte+1):
        Mst = med(w) if h % 50 == 0 or n_corto <= 100 else Mst_c  # mediana cada 50 bloques para acelerar
        Mst_c = Mst
        M = max(min(max(ZL, Mst), SURGE*ZL), ZL); lim = 2*M
        x = int(min(lim, back+dem)); back = max(0, back+dem-x); cola_max = max(cola_max, back)
        s = subs(BASE, x, M); perd += BASE - s; w.append(x)
        if est is None and s == BASE and back == 0: est = h
    return est, perd/BREK, cola_max/TX_B
print(f"{'demanda':>8}{'N_CORTO':>9}{'reacciona en':>14}{'subsidio perdido':>18}{'cola maxima':>14}")
for tx in (600, 1280):
    for nc in (100, 1000, 12000):
        est, perd, cola = transicion(tx, nc, 20000)
        e = f"{est} s" if est else "> 20 000 s"
        print(f"{tx:>8}{nc:>9}{e:>14}{perd:>14,.0f} ZZK{cola:>11,.0f} tx".replace(",", " "))
