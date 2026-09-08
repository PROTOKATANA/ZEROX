#!/usr/bin/env python3
"""
r8d_a5_deriva.py — LINEA A5. Rederivar `I`, `c` y `F` con la `m` del ancla BLUE_SCORE.

Pinza del diseno:
   steering        g = c_m / sqrt(alpha*lambda*I)   <= 3,6 %   (quiere I GRANDE)
   ventana BDK+19  W/kappa = 1 + I/F                <= 1,22    (quiere I PEQUENA, F GRANDE)

Con el ancla POS (D9-c A1.4) habia ademas un tercer efecto: `c` se contaba en POSICIONES
y el atacante inflaba lambda_chain (0,199 -> 0,484 a alpha=0,25), acortando la epoca real
I' = c/lambda_chain a menos de la mitad y subiendo g. **Con el ancla BLUE_SCORE, `c` se
cuenta en AZULES y lambda_blue la mide el propio retarget**: aqui se comprueba cuanto puede
moverla el atacante, porque de eso depende que I' = c/lambda_blue siga siendo I.

`c_m` se importa de `r8c_steering.py` de D9-c (integracion numerica, contrastada con los
valores publicados c_2 = 0,564 y c_4 = 1,029). `m` se MIDE aqui, nivel GRATIS (tier 1:
publica todo al instante, solo elige padres), sobre una rejilla fina de alpha.

Criterio alpha: la fila alpha = 0 debe dar m = 1 y g = 0.
"""
import math, sys
from r8d_lib import Mundo, wH, llega_de, LAMBDA
from r8d_a1_menu import K, MP, BANDA, lee, ancla_T
from r8c_steering import c_interp

TECHO_G = 0.036          # el 3,6 % con el que la ronda 8 derivo I = 2 490 s
TECHO_WK = 1.22          # el W/kappa que la ronda 8 declaro aceptable


def menu_gratis(alpha, semilla, P=30, T=260.0):
    """Solo TIER 1 de la familia dirigida de D9-c: publicacion inmediata, eleccion de
    padres. Ni retraso ni retencion: el atacante no renuncia a nada."""
    m = Mundo(alpha, T, semilla, k=K, mp=MP, u3_mode="dynamic")
    d0, tip0 = m.corre({})
    ch0 = d0.selected_chain(tip0)
    if P >= len(ch0):
        return None
    tP = d0.B[ch0[P]].t
    T0 = d0.gd[ch0[P]].blue_score
    Ts = list(range(T0 - BANDA, T0 + BANDA + 1))
    idx = [i for i, (t, q, *_) in enumerate(m.ev) if q == "a" and tP - 30 <= t <= tP + 30]
    ests = [{}]
    for pol in ("sp", ("retro", 1), ("retro", 2), ("retro", 4)):
        ests.append({i: (0.0, pol) for i in idx})
    for i in idx:
        for pol in ("sp", ("retro", 1), ("retro", 3)):
            ests.append({i: (0.0, pol)})
    vp, vb = set(), {T: set() for T in Ts}
    for e in ests:
        d, tip = m.corre(e)
        perfil = lee(d, tip)
        if P < len(perfil):
            vp.add(perfil[P][1])
        for T in Ts:
            s = ancla_T(perfil, T)
            if s is not None:
                vb[T].add(s)
    return len(vp), sum(len(v) for v in vb.values()) / len(vb)


def lambda_blue(alpha, semilla, T=600.0, u3_mode="dynamic", copias=0, pol="tips"):
    m = Mundo(alpha, T, semilla, k=K, mp=MP, u3_mode=u3_mode)
    est = {i: (0.0, pol) for i, (t, q, *_) in enumerate(m.ev) if q == "a"}
    d, tip = m.corre(est, copias=copias)
    ll = llega_de(m, d, est, copias)
    t1, t2 = 0.2 * T, 0.9 * T
    w1 = wH(d, [h for h, ta in ll.items() if ta <= t1], m)
    w2 = wH(d, [h for h, ta in ll.items() if ta <= t2], m)
    ch = d.selected_chain(tip)
    lc = (len(ch) - 1) / d.B[ch[-1]].t
    return (w2 - w1) / (t2 - t1), lc


if __name__ == "__main__":
    alphas = (0.0, 0.05, 0.10, 0.15, 0.25, 0.33, 0.40)
    sems = list(range(1, 13))
    print("=== A5 · rederivacion de I, c y F con el ancla BLUE_SCORE ===\n")
    print("(1) `m` GRATIS medida (tier 1), rejilla fina de alpha, 12 semillas")
    print(f"{'alpha':>6} | {'m_POS':>7} | {'m_BS':>7} | {'c_m(BS)':>8}")
    M = {}
    for a in alphas:
        rs = [menu_gratis(a, s) for s in sems]
        rs = [r for r in rs if r]
        mp_ = sum(r[0] for r in rs) / len(rs)
        mb = sum(r[1] for r in rs) / len(rs)
        M[a] = mb
        print(f"{a:>6.2f} | {mp_:>7.2f} | {mb:>7.2f} | {c_interp(mb):>8.4f}")

    print("\n(2) lambda_blue: ?puede el atacante mover la DURACION de la epoca?")
    print("    (con el ancla POS, lambda_chain iba de 0,199 a 0,628: la epoca se acortaba x3,2)")
    print(f"{'alpha':>6} | {'lam_blue':>9} {'Ip/I':>7} | {'lam_chain':>10} {'Ip/I (POS)':>12}")
    for a in alphas:
        rs = [lambda_blue(a, s) for s in range(1, 7)]
        lb = sum(r[0] for r in rs) / len(rs)
        lc = sum(r[1] for r in rs) / len(rs)
        print(f"{a:>6.2f} | {lb:>9.4f} {1/lb if lb else 0:>7.3f} | {lc:>10.4f} "
              f"{0.1988/lc if lc else 0:>12.3f}")

    print("\n(3) LA PINZA: ?existe (I, F) con g <= 3,6 % y W/kappa <= 1,22?")
    print(f"{'alpha':>6} | {'m':>6} {'c_m':>7} | {'I minima (g<=3,6%)':>19} | "
          f"{'F minima (W/k<=1,22)':>21}")
    Imax = 0.0
    for a in alphas:
        if a == 0:
            print(f"{a:>6.2f} | {M[a]:>6.2f} {0.0:>7.4f} | {'0 (no hay ataque)':>19} | "
                  f"{'-':>21}")
            continue
        cm = c_interp(M[a])
        Ineed = (cm / TECHO_G) ** 2 / (a * LAMBDA)
        Fneed = Ineed / (TECHO_WK - 1)
        Imax = max(Imax, Ineed)
        print(f"{a:>6.2f} | {M[a]:>6.2f} {cm:>7.4f} | {Ineed:>13,.0f} s "
              f"({Ineed/3600:>4.2f} h) | {Fneed:>13,.0f} s ({Fneed/3600:>5.2f} h)")
    Fmax = Imax / (TECHO_WK - 1)
    print(f"\n  DIMENSIONANDO POR EL PEOR alpha:  I = {Imax:,.0f} s = {Imax/3600:.2f} h,"
          f"  F = {Fmax:,.0f} s = {Fmax/3600:.2f} h,  c = I*lambda_blue = {Imax*0.993:,.0f} azules")
    print(f"  Comparacion:  ronda 8 publicaba I = 2 490 s (0,69 h), F = 3,2 h")
    print(f"                D9-c con el ancla POS pedia I = 9 272 s (2,58 h), F = 11,7 h")

    print("\n(4) Sensibilidad del techo: que (I, F) salen con otros techos de g y W/kappa")
    print(f"{'techo g':>8} | " + " ".join(f"{'W/k<=' + f'{w:.2f}':>18}" for w in (1.10, 1.22, 1.50)))
    for tg in (0.020, 0.036, 0.050):
        fila = f"{tg*100:>7.1f}% |"
        In = max((c_interp(M[a]) / tg) ** 2 / (a * LAMBDA) for a in alphas if a > 0)
        for w in (1.10, 1.22, 1.50):
            fila += f"  I={In/3600:>5.2f} h F={In/(w-1)/3600:>6.2f} h"
        print(fila)
