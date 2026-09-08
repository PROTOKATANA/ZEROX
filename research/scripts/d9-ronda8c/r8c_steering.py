#!/usr/bin/env python3
"""
r8c_steering.py — traduce la `m` MEDIDA en A1 al steering `g`.

Modelo de la ronda 4 (`dag-poas-voto-auditoria.md` L197-199, literal):
    "el valor de elegir el mejor de m es E[max] - media = c_m*sqrt(alpha*lambda*n),
     y frente al ingreso de la epoca alpha*lambda*I la ganancia relativa es
     g = c_m*sqrt(alpha*lambda*n)/(alpha*lambda*I),   c_2 = 0,564, c_4 = 1,029"
La propuesta usa el caso n = I (cota superior): g = c_m / sqrt(alpha*lambda*I).

`c_m` = E[max de m normales estandar] - 0. Se calcula aqui por integracion numerica
(NO de memoria) y se comprueba contra los dos valores publicados: c_2=0,564, c_4=1,029.
"""
import math

LAMBDA = 1.0
I = 2490.0


def c_m(m, pasos=400000, lim=9.0):
    """E[max de m N(0,1)] = INT x * m * phi(x) * Phi(x)^(m-1) dx, por Simpson."""
    if m <= 1:
        return 0.0
    h = 2 * lim / pasos
    tot = 0.0
    for i in range(pasos + 1):
        x = -lim + i * h
        phi = math.exp(-x * x / 2) / math.sqrt(2 * math.pi)
        Phi = 0.5 * (1 + math.erf(x / math.sqrt(2)))
        f = x * m * phi * (Phi ** (m - 1))
        w = 1 if i in (0, pasos) else (4 if i % 2 else 2)
        tot += w * f
    return tot * h / 3


def c_interp(m):
    """m medio no entero -> interpolacion lineal entre los enteros vecinos."""
    lo, hi = math.floor(m), math.ceil(m)
    if lo == hi:
        return c_m(int(m))
    return c_m(lo) + (m - lo) * (c_m(hi) - c_m(lo))


def g(m, alpha):
    return c_interp(m) / math.sqrt(alpha * LAMBDA * I)


if __name__ == "__main__":
    print("Comprobacion de c_m contra los valores publicados (dag-poas-voto-auditoria.md L199):")
    for m, pub in ((2, 0.564), (4, 1.029)):
        print(f"   c_{m} calculado = {c_m(m):.4f}   publicado = {pub}")
    print("\nc_m calculado:")
    print("   " + "  ".join(f"c_{m}={c_m(m):.3f}" for m in (1, 2, 3, 4, 5, 6, 8, 9, 10, 11, 12)))

    # m medidas en r8c_a1_menu.py (posicion 30, 12 semillas, u3_mode='dynamic')
    med = {0.10: (4.50, 5.92, 7.33), 0.25: (5.00, 8.25, 9.50),
           0.33: (5.17, 9.00, 10.50), 0.40: (5.25, 9.17, 10.67)}
    print(f"\nSteering g = c_m/sqrt(alpha*lambda*I) con I = {I:.0f} s, lambda = {LAMBDA}")
    print(f"{'alpha':>6} | {'m=1,3 (principal)':>18} | {'m GRATIS (D9-c)':>16} | "
          f"{'m +retraso':>12} | {'m +retencion':>14}")
    for a, (m1, m2, m3) in med.items():
        print(f"{a:>6.2f} | {100*g(1.3, a):>17.2f}% | {100*g(m1, a):>15.2f}% | "
              f"{100*g(m2, a):>11.2f}% | {100*g(m3, a):>13.2f}%")
    print("\nPara comparar: la propuesta publica g = 3,6 % (con m = 4 asumida) y la solucion")
    print("dice 1,0-2,4 % (con m = 1,3-2,0 medida por el principal).")

    print("\n?Que I haria falta para volver al 3,6 % con la m GRATIS medida?")
    for a, (m1, _, _) in med.items():
        Ineed = (c_interp(m1) / 0.036) ** 2 / (a * LAMBDA)
        print(f"   alpha={a:.2f}: m={m1:.2f} -> I = {Ineed:,.0f} s = {Ineed/3600:.2f} h "
              f"(era {I:.0f} s = {I/3600:.2f} h)")


# ---------------------------------------------------------------------------
# HALLAZGO EXTRA: `c` esta en POSICIONES DE CADENA (R-FIN-1 + solucion §3:
# "c vuelve a contarse en posiciones de cadena: c = I*lambda_chain = 500"), y
# lambda_chain NO es una constante: la infla el atacante. El retarget fija lambda
# (bloques/s), no lambda_chain. Luego la DURACION de la epoca en segundos es
#     I' = c / lambda_chain(alpha)
# y como g va con 1/sqrt(I'), acortar la epoca SUBE el steering.
# lambda_chain medida en r8c_a1b_mecanismo.py (12 semillas, k=30, mp=15, Delta=4).
C_POS = 500.0
LC = {0.00: 0.1988, 0.10: 0.3181, 0.25: 0.4838, 0.33: 0.5631, 0.40: 0.6275}

if __name__ == "__main__":
    print("\n" + "=" * 78)
    print("EXTRA · la epoca dura c/lambda_chain segundos, y lambda_chain la infla el atacante")
    print(f"{'alpha':>6} {'lambda_chain':>13} {'I efectiva (s)':>15} {'I nominal':>11} "
          f"{'g con m GRATIS':>15} {'W/k = 1+I/F':>12}")
    F = 3.2 * 3600
    for a in (0.10, 0.25, 0.33, 0.40):
        lc = LC[a]
        Ief = C_POS / lc
        m1 = med[a][0]
        gg = c_interp(m1) / math.sqrt(a * LAMBDA * Ief)
        print(f"{a:>6.2f} {lc:>13.4f} {Ief:>15.0f} {I:>11.0f} {100*gg:>14.2f}% "
              f"{1 + Ief/F:>12.3f}")
    print("\n  (I nominal 2 490 s sale de lambda_chain = 0,2008, que es el valor a alpha = 0.")
    print("   Con atacante la epoca es 2-3 veces mas corta y el steering sube en sqrt de eso.)")

    print("\nPINZA: para g <= 3,6 % con la m GRATIS medida, y W/k <= 1,22:")
    for a in (0.10, 0.25, 0.33, 0.40):
        m1 = med[a][0]
        Ineed = (c_interp(m1) / 0.036) ** 2 / (a * LAMBDA)     # segundos de epoca necesarios
        cneed = Ineed * LC[a]                                   # en posiciones de cadena
        Fneed = Ineed / 0.22
        print(f"   alpha={a:.2f}: I >= {Ineed:>7,.0f} s ({Ineed/3600:>5.2f} h) -> "
              f"c >= {cneed:>6,.0f} posiciones, y F >= {Fneed/3600:>5.2f} h "
              f"(era F = 3,2 h)")


# ---------------------------------------------------------------------------
# EXTRA 2: la m REACTIVA Y EN LINEA (r8c_a1e_reactivo.py) — la lectura conservadora,
# y la m del CONTROL con atacante retardado (r8c_a1d_control.py).
M_REACT = {0.10: 2.08, 0.25: 2.92, 0.33: 2.50, 0.40: 2.17}
M_CTRL = {0.10: 1.38, 0.25: None, 0.33: None, 0.40: None}   # se rellena al terminar A1d

if __name__ == "__main__":
    print("\n" + "=" * 78)
    print("EXTRA 2 · las tres lecturas de `m`, y su steering (I nominal 2 490 s)")
    print(f"{'alpha':>6} | {'m REACTIVO':>11} {'g':>8} | {'m GRATIS':>9} {'g':>8} | "
          f"{'m +retencion':>13} {'g':>8}")
    for a in (0.10, 0.25, 0.33, 0.40):
        mr = M_REACT[a]; mg, _, mh = med[a]
        print(f"{a:>6.2f} | {mr:>11.2f} {100*g(mr,a):>7.2f}% | {mg:>9.2f} {100*g(mg,a):>7.2f}% "
              f"| {mh:>13.2f} {100*g(mh,a):>7.2f}%")
    print("\n  m REACTIVO = solo bloques del atacante creados DESPUES de que exista el candidato,")
    print("  publicados al instante. Es el suelo: realizable en linea, coste cero.")
