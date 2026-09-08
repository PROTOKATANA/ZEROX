#!/usr/bin/env python3
"""
r8d_a5b_niveles.py — la pinza (I, F) en los TRES niveles de coste del atacante.

`m` viene MEDIDA en esta ronda:
  reactivo  r8d_a1b_reactivo.py (en linea, gratis, sin mirar al futuro)  -> salida_a1b.txt
  gratis    r8d_a1_menu.py / r8d_a5_deriva.py (tier 1, ex post)          -> salida_a1_menu.txt
  retencion r8d_a1_menu.py (tier 3, retiene bloques para siempre)        -> salida_a1_menu.txt

Techos del diseno: g <= 3,6 % (con el que la ronda 8 derivo I = 2 490 s) y
W/kappa = 1 + I/F <= 1,22 (BDK+19 §2). lambda_blue = 0,975 medida (r8d_a5_deriva.py §2).

Criterio alpha: la columna alpha = 0 no existe (m = 1 -> c_m = 0 -> no hay restriccion);
se marca explicitamente.
"""
from r8d_lib import Mundo  # solo para dejar el sys.path de D9-c en su sitio
from r8c_steering import c_interp

LAM, LAM_BLUE, TG, TWK = 1.0, 0.975, 0.036, 1.22

# m_BS medidas en esta ronda (12 semillas, P=30, banda de 21 umbrales, u3_mode='dynamic')
M = {
    "reactivo (en linea)": {0.05: 1.23, 0.10: 1.77, 0.15: 1.70, 0.25: 2.12, 0.33: 2.02, 0.40: 2.02},
    "gratis (ex post)":    {0.05: 1.47, 0.10: 2.33, 0.15: 2.49, 0.25: 3.03, 0.33: 3.17, 0.40: 3.25},
    "+retraso":            {0.10: 3.38, 0.25: 4.29, 0.33: 4.32, 0.40: 4.34},
    "+retencion":          {0.10: 4.35, 0.25: 7.53, 0.33: 8.24, 0.40: 8.17},
}

print("=== A5b · la pinza (I, F) por nivel de coste del atacante ===")
print(f"g = c_m/sqrt(alpha*lambda*I) <= {TG:.1%};  W/kappa = 1 + I/F <= {TWK}\n")
print(f"{'nivel':>22} | {'peor alpha':>10} | {'m':>5} {'c_m':>7} | {'I':>16} | {'F':>16} | {'c (azules)':>11}")
for nom, dd in M.items():
    peor, Imax = None, 0.0
    for a, m in dd.items():
        I = (c_interp(m) / TG) ** 2 / (a * LAM)
        if I > Imax:
            Imax, peor = I, a
    F = Imax / (TWK - 1)
    print(f"{nom:>22} | {peor:>10.2f} | {dd[peor]:>5.2f} {c_interp(dd[peor]):>7.4f} "
          f"| {Imax:>8,.0f} s ({Imax/3600:>4.2f} h) | {F:>8,.0f} s ({F/3600:>5.2f} h) "
          f"| {Imax*LAM_BLUE:>11,.0f}")
print()
print("Referencias:")
print("  ronda 8 publica            I = 2 490 s (0,69 h), F = 3,20 h,  c = 2 490")
print("  D9-c con el ancla POS pide I = 9 272 s (2,58 h), F = 11,70 h")
print()
print("Y con el ancla POS, la epoca REAL se acortaba (D9-c A1.4: I' = c/lambda_chain, x0,30 a")
print("alpha=0,40). Con blue_score NO: lambda_blue medida 0,971-0,978 para todo alpha, I'/I = 1,03.")
