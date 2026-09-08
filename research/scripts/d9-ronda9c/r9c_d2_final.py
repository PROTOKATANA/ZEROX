#!/usr/bin/env python3
"""
r9c_d2_final.py — la tabla P3 con la `W_dec` MEDIDA en C (r9c_c4_wdec.py):
W_dec <= 20 s para alpha <= 0,33 y <= 45 s a alpha = 0,40 (12 semillas, S_max in {20,150}).
n_eval = rho * W_dec.  Fila alpha = 0 en la tabla de C, no aqui (aqui no hay adversario
simulado: es aritmetica sobre `c_m`).
"""
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from r9c_lib import c_interp

LAM, A_CAL, A_EV, WK = 1.0, 0.10, 0.33, 1.22
A_ESTR = 4.1     # A* esc. B con plotter 10x (ancla-de-finalidad.md L64-66)


def tabla(m_dis, n_eval, etiq):
    print()
    print(f"### m_diseno = {m_dis}   ·   {etiq}")
    print(f"{'g obj':>6} | {'I (s)':>8} {'F (h)':>7} {'I+F (h)':>8} | "
          f"{'g(33%)':>8} {'a_ef':>7} | {'m=23: g':>9} {'a_ef':>7} | "
          f"{'m=151: g':>9} {'a_ef':>7} | {'margen':>8} | aviso")
    for g in (0.036, 0.05, 0.07, 0.10):
        if n_eval is None:
            I = (c_interp(m_dis) / g) ** 2 / (A_CAL * LAM)
            ne = I
        else:
            I = c_interp(m_dis) * math.sqrt(n_eval / (A_CAL * LAM)) / g
            ne = min(n_eval, I)
        F = I / (WK - 1)
        cols = []
        for mb in (m_dis, 23, 151):
            gg = c_interp(mb) * math.sqrt(A_EV * LAM * ne) / (A_EV * LAM * I)
            cols.append((gg, A_EV * (1 + gg * (1 - A_EV))))
        av = ""
        if n_eval is not None and n_eval >= I:
            av = "[!] n_eval>=I: la cota NO muerde"
        elif n_eval is not None and I < 1.5 * n_eval / 1.0:
            av = "[!] I < rho_max*W_dec*? revisar R-FIN-14(f)"
        print(f"{100*g:>5.1f}% | {I:>8.0f} {F/3600:>7.2f} {(I+F)/3600:>8.2f} | "
              f"{100*cols[0][0]:>7.2f}% {100*cols[0][1]:>6.2f}% | "
              f"{100*cols[1][0]:>8.2f}% {100*cols[1][1]:>6.2f}% | "
              f"{100*cols[2][0]:>8.2f}% {100*cols[2][1]:>6.2f}% | "
              f"{A_ESTR*3600/(I+F):>7.2f}x | {av}")


if __name__ == "__main__":
    print("=" * 118)
    print("TABLA P3 con la W_dec MEDIDA.  I = c_m*sqrt(n_eval/(a*L))/g ;  F = I/(W/k - 1) ;")
    print("alpha_ef = a(1+g(1-a)) a a=0,33 ;  margen = A*(4,1 h) / (I+F)")
    tabla(2.955, None, "LIBRE (lo publicado hoy): n_eval = I")
    for W in (20, 45):
        for rho in (1.0, 1.5, 3.0):
            tabla(2.955, rho * W, f"W_dec = {W} s (medida) · rho = {rho} -> n_eval = {rho*W:.0f}")
    print()
    print("=" * 118)
    print("Nota rho<=1: E1 demuestra que con rho <= 1 el atacante NUNCA construye la ventaja")
    print("de L slots que necesita para evaluar NADA -> n_eval = 0 -> g = 0 por esta via.")
    print("La fila rho = 1,0 de arriba es por tanto una COTA SUPERIOR generosa.")
