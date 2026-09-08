"""Frontera de flujo unico en funcion de F. Instrumento de 9a sin tocar (prev/union10/delta_interp);
solo el barrido es mas grueso (0,005) con brentq entre los dos puntos que encierran el cruce."""
import sys, time
sys.path.insert(0, "/home/katana/zeo/ZEROX/research/scripts/d9-ronda9a")
import r9a_a3_frontera as A
from scipy.optimize import brentq
import numpy as np

def set_F_I(F, I):
    A.F_SEG = float(F); A.I_EP = float(I); A.EP_ANO = 365*24*3600/A.I_EP

def frontera_gruesa(hf, lo=0.20, hi=0.499, paso=0.005):
    f = lambda a: np.log10(max(A.union10(a, hf(a)), 1e-320)) + 10.0
    ant = None
    for a in np.arange(lo, hi + 1e-9, paso):
        v = f(a)
        if ant is not None and ant[1] < 0 <= v:
            return brentq(f, ant[0], a, xtol=1e-5)
        ant = (a, v)
    return float("nan")

hf0 = lambda a: 1.0                         # (c) delta = 0, el modelo verificado de 9a
hfD8 = lambda a: 1 - A.delta_interp(a)      # (a) delta pesimista de D8

# control: reproducir el 46,88 % de 9a con F=19080, I=4200
set_F_I(19080, 4200); t=time.time()
print(f"CONTROL F=19080 I=4200: frontera δ=0 = {frontera_gruesa(hf0):.4%} (9a: 46,8784 %), δ D8 = {frontera_gruesa(hfD8):.4%} (9a: 36,5431 %)  [{time.time()-t:.0f} s]", flush=True)

print(f"\n{'F (s)':>7} {'F (h)':>6} {'I':>5} | {'frontera δ=0':>13} {'frontera δ D8':>14} | {'union10 α=0,33 δ=0':>19} {'α=0,35 δ=0':>12} {'α=0,33 δ D8':>12}", flush=True)
for F, I in ((7200, 851), (3852, 851), (1224, 851), (7200, 4200)):
    set_F_I(F, I); t=time.time()
    fr0 = frontera_gruesa(hf0); frD = frontera_gruesa(hfD8)
    u33 = A.union10(0.33, 1.0); u35 = A.union10(0.35, 1.0); u33D = A.union10(0.33, hfD8(0.33))
    print(f"{F:>7} {F/3600:>6.2f} {I:>5} | {fr0:>13.2%} {frD:>14.2%} | {u33:>19.2e} {u35:>12.2e} {u33D:>12.2e}   [{time.time()-t:.0f} s]", flush=True)

print("\nF_carrera = F minima con union10(alpha) = 1e-10, I = 851 s", flush=True)
for a, hf, nom in ((0.33, hf0, "δ=0"), (0.35, hf0, "δ=0"), (0.33, hfD8, "δ D8"), (0.35, hfD8, "δ D8")):
    def g(F, a=a, hf=hf):
        set_F_I(F, 851); return np.log10(max(A.union10(a, hf(a)), 1e-320)) + 10
    try:
        Fmin = brentq(g, 60, 60000, xtol=1)
        print(f"  alpha={a:.2f} {nom:>5}: F_carrera = {Fmin:7.0f} s = {Fmin/3600:.2f} h", flush=True)
    except ValueError as e:
        print(f"  alpha={a:.2f} {nom:>5}: sin cruce en [60, 60000] s", flush=True)
