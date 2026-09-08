#!/usr/bin/env python3
"""
r9c_d1_steering.py — punto D: el steering con EVALUACION ACOTADA.

Afirmacion a auditar: si el reto de cada slot sale del PoT secuencial, el atacante solo
puede evaluar `n_eval = rho * W_dec` slots de cada candidato, y la ganancia pasa de
`c_m*sqrt(alpha*lambda*I)` a `c_m*sqrt(alpha*lambda*n_eval)`.

D.1 · Comprobacion del modelo por simulacion de la LOTERIA (no es una identidad: hay que
      medirla). El atacante ve `m` corrientes independientes; de cada una observa los
      `n_eval` primeros slots; elige la de mas victorias observadas; su ingreso de la epoca
      es `W_{j*}(n_eval) + R_{j*}` con `R` las victorias de los `I - n_eval` slots restantes.
      Se mide: (a) la ganancia total sobre la media `alpha*lambda*I`;
               (b) que `E[R_{j*}] = (I-n_eval)*alpha*lambda`, es decir que el resto NO
                   se contamina por la seleccion (si se contaminase, el modelo mentiria);
               (c) la formula `c_m*sqrt(alpha*lambda*n_eval)`.
      Fila `alpha = 0` obligatoria: sin espacio no hay victorias y la ganancia es 0.

D.2 · Recalculo de `g`, `alpha_ef` y la tabla (g, I, F, lookahead) de P3.
"""
import sys, os, math, random
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from r9c_lib import c_interp

LAM = 1.0
SEMILLAS = [11, 23, 37, 41, 59, 67, 73, 89, 97, 101, 113, 127]
REPS = 40000          # epocas simuladas por (alpha, m, n_eval) y semilla


def lot(alpha, m, n_eval, I, semilla, reps=REPS):
    """Devuelve (ganancia_media, media_resto, media_obs_elegida, media_obs).
    Poisson EXACTO (numpy), no aproximacion normal: el modelo de la ronda 4 es Poisson."""
    rng = np.random.default_rng(semilla)
    mu_n = alpha * LAM * n_eval
    mu_r = alpha * LAM * max(0, I - n_eval)
    obs = rng.poisson(mu_n, size=(reps, m))        # m corrientes independientes
    j = obs.argmax(axis=1)
    sel = obs[np.arange(reps), j]
    resto = rng.poisson(mu_r, size=reps)           # independiente de la seleccion
    tot = sel + resto
    return (float(tot.mean() - (mu_n + mu_r)), float(resto.mean()),
            float(sel.mean()), float(obs.mean()))


if __name__ == "__main__":
    print("=" * 104)
    print("D.1 · la loteria: ganancia medida vs c_m*sqrt(alpha*lambda*n_eval)   "
          f"({len(SEMILLAS)} semillas x {REPS} epocas)")
    I = 4200
    print(f"{'alpha':>6} {'m':>3} {'n_eval':>7} | {'ganancia medida':>17} | "
          f"{'c_m*sqrt(a*L*n)':>16} | {'razon':>7} | {'E[resto] medido':>16} | "
          f"{'(I-n)*a*L teorico':>18}")
    for alpha in (0.0, 0.10, 0.25, 0.33, 0.40):
        for m, n_eval in ((3, 150), (3, 4200), (23, 150), (151, 150)):
            gs, rs = [], []
            for s in SEMILLAS:
                g_, r_, _, _ = lot(alpha, m, n_eval, I, s)
                gs.append(g_); rs.append(r_)
            gm = sum(gs) / len(gs); rm = sum(rs) / len(rs)
            teo = c_interp(m) * math.sqrt(alpha * LAM * n_eval)
            razon = (gm / teo) if teo > 0 else float("nan")
            print(f"{alpha:>6.2f} {m:>3} {n_eval:>7} | {gm:>17.3f} | {teo:>16.3f} | "
                  f"{razon:>7.3f} | {rm:>16.2f} | {alpha*LAM*max(0,I-n_eval):>18.2f}")

    print()
    print("=" * 104)
    print("D.2 · steering `g` con evaluacion acotada")
    print("  Calibracion (la de la propuesta): `I` sale del `m` de DISENO y del `g` objetivo")
    print("  a alpha = 0,10; luego se evalua el steering que un atacante del 33 % obtiene")
    print("  COMPRANDO `m` (soborno, D8 A5: m = b+1).  alpha_ef = alpha(1+g(1-alpha)).")
    print("  LIBRE   : g = c_m/sqrt(a*L*I)                    I = (c_m/g)^2/(a*L)")
    print("  ACOTADA : g = c_m*sqrt(a*L*n_eval)/(a*L*I)       I = c_m*sqrt(n_eval/(a*L))/g")
    print()

    def calibra(m_dis, gobj, n_eval, a_cal=0.10):
        if n_eval is None:                                   # lectura LIBRE
            return (c_interp(m_dis) / gobj) ** 2 / (a_cal * LAM)
        return c_interp(m_dis) * math.sqrt(n_eval / (a_cal * LAM)) / gobj

    def steering(m, alpha, I, n_eval):
        ne = I if n_eval is None else min(n_eval, I)
        return c_interp(m) * math.sqrt(alpha * LAM * ne) / (alpha * LAM * I)

    A_ESTR = 4.1   # A* escenario B con plotter 10x, ancla-de-finalidad.md L64-66 (6,3/4,1/6,9 h)
    # --- control: reproducir los numeros publicados (D8 / P3) ---
    print("CONTROL · reproduccion de la tabla P3 publicada (lectura LIBRE, m_dis = 2,822):")
    for gobj in (0.036, 0.05, 0.07, 0.10):
        I_ = calibra(2.822, gobj, None)
        F_ = I_ / 0.22
        aef28 = 0.33 * (1 + steering(2.822, 0.33, I_, None) * 0.67)
        aef151 = 0.33 * (1 + steering(151, 0.33, I_, None) * 0.67)
        print(f"   g={100*gobj:>4.1f}%  I={I_:>7.0f} s  F={F_/3600:>5.2f} h  I+F={(I_+F_)/3600:>5.2f} h"
              f"  alpha_ef(m=2,8)={100*aef28:>5.1f}%  alpha_ef(m=151)={100*aef151:>5.1f}%"
              f"  margen_B10x={A_ESTR*3600/(I_+F_):>5.2f}x")
    print("   (publicado en dag-poas-tras-d8-palancas.md §2 P3: 4 890 s / 6,17 h / 0,54x")
    print("    y alpha_ef 33,5 / 34,5 % a g=3,6 %; 33,9 / 35,8 % a g=7 %)")

    for m_dis in (2.955, 2.822):
        for etiq, n_eval in (("LIBRE (n_eval = I)", None), ("W_dec=45  rho=1", 45.0),
                             ("W_dec=150 rho=1", 150.0), ("W_dec=150 rho=1,5", 225.0),
                             ("W_dec=150 rho=3", 450.0), ("W_dec=300 rho=1", 300.0),
                             ("W_dec=300 rho=3", 900.0)):
            print()
            print(f"### m_diseno = {m_dis}   ·   {etiq}"
                  + (f"   n_eval = {n_eval:.0f} slots" if n_eval else ""))
            print(f"{'g obj':>6} | {'I (s)':>9} {'F (h)':>7} {'I+F (h)':>8} | "
                  f"{'g(33%,m_dis)':>13} {'a_ef':>6} | {'g(33%,m=23)':>12} {'a_ef':>6} | "
                  f"{'g(33%,m=151)':>13} {'a_ef':>6} | {'margen B10x':>11}")
            for gobj in (0.036, 0.05, 0.07, 0.10):
                I_ = calibra(m_dis, gobj, n_eval)
                F_ = I_ / 0.22
                cols = []
                for mb in (m_dis, 23, 151):
                    gg = steering(mb, 0.33, I_, n_eval)
                    cols.append((gg, 0.33 * (1 + gg * 0.67)))
                print(f"{100*gobj:>5.1f}% | {I_:>9.0f} {F_/3600:>7.2f} {(I_+F_)/3600:>8.2f} | "
                      f"{100*cols[0][0]:>12.2f}% {100*cols[0][1]:>5.2f}% | "
                      f"{100*cols[1][0]:>11.2f}% {100*cols[1][1]:>5.2f}% | "
                      f"{100*cols[2][0]:>12.2f}% {100*cols[2][1]:>5.2f}% | "
                      f"{A_ESTR*3600/(I_+F_):>10.2f}x"                      + ("   [!] n_eval >= I: la cota no muerde, es la LIBRE" if (n_eval and n_eval >= I_) else ""))

    print()
    print("=" * 104)
    print("D.3 · c_m usados (integracion numerica, r8c_steering.c_m):")
    print("   " + "  ".join(f"c_{m}={c_interp(m):.4f}" for m in (2, 2.822, 2.955, 3, 4, 23, 151)))
    print()
    print("D.4 · rho necesario para evaluar la EPOCA ENTERA dentro de W_dec:  rho >= I/W_dec")
    for I_ in (900, 1300, 2500, 4200, 4890):
        fila = "  ".join(f"W={w}s: rho>={I_/w:>6.1f}" for w in (45, 150, 225, 300))
        print(f"   I = {I_:>5} s   {fila}")
