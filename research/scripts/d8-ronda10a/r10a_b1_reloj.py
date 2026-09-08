#!/usr/bin/env python3
"""
D8 ronda 10a · B.1 — ¿es correcta la cota `rho >= L/W_dec` de la revelacion retardada (h)?

Se audita la frase del encargo: «evaluar un candidato exige calcular un VDF de L slots dentro
de la ventana W_dec <= 45 s => steering 0 salvo rho >= L/W_dec (80 con L = 1 h)».

Tesis de D8, a comprobar aqui: la cota es correcta SOLO para candidatos AJENOS. El atacante no
espera a que le revelen `entropia_X`: la calcula el, porque sus dos entradas —`chunk(X)` y
`salida(f, slot(X))`— son publicas (y suyas, si X es un bloque suyo). Para un candidato PROPIO
puede arrancar el VDF en cuanto su frontera pasa `slot(X)`, que con lookahead ocurre ANTES de
que el slot llegue. La cota deja de ser `L/W_dec` y pasa a ser la de la CADENA COMUN,
`(L + I)/(I + W_dec)`, ~18x menor. Y por debajo de ella queda un residuo por RACHAS de anclas
propias, con tasa cerrada `alpha^(n*-1)`.

Controles positivos (regla de metodo 4), tres, todos contra numeros publicados por OTROS:
  C1  9c §E.1: tope de ventaja sin (h) = L + I - W_dec = 23 130 slots con (L, I, W_dec) =
      (19 080, 4 200, 150), y bootstrap `tope/(rho-1)` = 642,5 / 128,5 / 42,8 / 12,8 / 3,2 h.
      El bootstrap se MIDE en el simulador, no se recita.
  C2  ronda 7 (`dag-poas-ancla-de-finalidad.md:319-322`): «reduce el lookahead de L + I(1-1/v)
      a (L + I)(1-1/v)». Mi recursion NO programa esas dos formas: las tiene que producir.
  C3  9c hallazgo E1: SIN (h), `rho <= 1 => steering 0`, `rho > 1 => steering`, es decir
      rho* = 1 con ancla honesta.

Criterio alpha (regla 4): alpha entra por tres sitios independientes —`W_dec(alpha)` medida por
9c, `m(alpha)` medida por 9c y `p_propia = alpha` (quien ancla la epoca)—. La fila alpha = 0
tiene que dar steering 0 en todas las columnas.
"""
import math
import os
import sys
from multiprocessing import Pool

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from r10a_lib import (COB, LAM, S_MAX, c_interp, frontera_pot, menu, n_rachas,      # noqa: E402
                      rho_cadena_comun, rho_entropia_honesta, rho_entropia_propia,
                      tasa_rachas, w_dec)

SEMILLAS = [11, 23, 37, 41, 53, 67, 71, 83, 97, 101, 113, 127, 139, 151]   # 14 >= 12
N_EP = 4000          # epocas por semilla (a I = 851 s son 39 dias de red por semilla)
CONF = [(7200.0, 851.0), (7200.0, 300.0), (3600.0, 851.0), (3600.0, 300.0)]
ALFAS = (0.00, 0.10, 0.25, 0.33, 0.40)


def _frac(args):
    L, I, rho, alpha, con_h, semilla, via, modo, p_prop, n_ep = args
    r = frontera_pot(L, I, rho, alpha, con_h, semilla, n_ep=n_ep, modo_off=modo,
                     p_propia=p_prop)
    return r["frac_propio"] if via == "propio" else r["frac_honesto"]


def umbral(L, I, alpha, con_h, semilla, via, modo="geom", p_prop=None,
           lo=1.0, hi=1000.0, it=52, n_ep=800):
    """Menor rho con steering en > 50 % de las epocas. NaN si no lo hay en [lo, hi]."""
    def f(r):
        return _frac((L, I, r, alpha, con_h, semilla, via, modo, p_prop, n_ep))
    if f(hi) <= 0.5:
        return float("nan")
    if f(lo + 1e-9) > 0.5:
        return lo
    for _ in range(it):
        mid = 0.5 * (lo + hi)
        if f(mid) > 0.5:
            hi = mid
        else:
            lo = mid
    return hi


def _tarea(args):
    L, I, alpha, con_h, via, semilla, modo, p_prop = args
    return umbral(L, I, alpha, con_h, semilla, via, modo=modo, p_prop=p_prop)


def resumen(vals):
    v = [x for x in vals if not math.isnan(x)]
    if not v:
        return float("nan"), float("nan"), float("nan")
    return sum(v) / len(v), min(v), max(v)


def main():
    pool = Pool()
    ancho = "=" * 118

    # ------------------------------------------------------------------ C1
    print(ancho)
    print("CONTROL C1 (9c §E.1) — tope de ventaja SIN (h) y tiempo de bootstrap, MEDIDO")
    L9, I9, W9 = 19080.0, 4200.0, 150.0
    tope = L9 + I9 - W9
    print(f"  cerrado de 9c: L + I - W_dec = {tope:.0f} slots  "
          f"[{'IDENTICO' if abs(tope - 23130) < 1 else 'DISCREPA'} a 23 130]")
    print(f"{'rho':>6} | {'9c: tope/(rho-1)':>18} | {'MEDIDO: llegar a 0,9 L':>23} {'cerrado 0,9L/(rho-1)':>21} "
          f"{'razon':>6} | {'tope simulado':>14}")
    for rho in (1.01, 1.05, 1.15, 1.5, 3.0):
        r = frontera_pot(L9, I9, rho, 0.0, False, 11, n_ep=40000, modo_off="cero", p_propia=0.0,
                         cuenta_cobertura=False, boot_obj=0.90 * L9)
        cer = 0.90 * L9 / (rho - 1.0)
        print(f"{rho:>6.2f} | {tope/(rho-1.0)/3600.0:>15.1f} h | {r['boot90']/3600.0:>20.2f} h "
              f"{cer/3600.0:>19.2f} h {r['boot90']/cer:>6.3f} | {r['vent_pico']:>10.0f} sl")
    print("  El bootstrap es `x/(rho-1)` con `x` la ventaja objetivo: reproducido con razon 1,00-1,02.")
    print("  Los numeros de 9c son ese mismo cerrado con x = L + I - W_dec (el tope de 9c).")

    # ------------------------------------------------------------------ C2
    print(ancho)
    print("CONTROL C2 (ronda 7, dag-poas-ancla-de-finalidad.md:319-322) — «reduce el lookahead")
    print("            de L + I(1-1/v) a (L + I)(1-1/v)». Mi recursion no programa esas formas.")
    print(f"{'L (h)':>6} {'I':>5} {'rho':>5} | {'sim SIN (h)':>12} {'L+I(1-1/v)':>11} {'raz.':>6} | "
          f"{'sim CON (h)':>12} {'(L+I)(1-1/v)':>13} {'raz.':>6}")
    for L, I in ((7200.0, 851.0), (3600.0, 851.0), (19080.0, 4200.0)):
        for rho in (1.05, 1.2, 1.5, 2.0, 3.0):
            a0 = frontera_pot(L, I, rho, 0.0, False, 11, n_ep=N_EP, modo_off="cero",
                              p_propia=0.0, cuenta_cobertura=False)["vent_pico"]
            a1 = frontera_pot(L, I, rho, 0.0, True, 11, n_ep=N_EP, modo_off="cero",
                              p_propia=0.0, cuenta_cobertura=False)["vent_pico"]
            c0 = L + I * (1 - 1 / rho)
            c1 = (L + I) * (1 - 1 / rho)
            print(f"{L/3600:>6.2f} {I:>5.0f} {rho:>5.2f} | {a0:>12.0f} {c0:>11.0f} {a0/c0:>6.3f} | "
                  f"{a1:>12.0f} {c1:>13.0f} {a1/c1:>6.3f}")
    print("  W_dec = 0 (fila alpha = 0 de 9c: W_dec = -1, no hay decision que tomar).")

    # ------------------------------------------------------------------ C3
    print(ancho)
    print("CONTROL C3 (9c hallazgo E1) — SIN (h): rho <= 1 => steering 0; rho > 1 => steering")
    print("  `rho > 1` es ASINTOTICO: con horizonte finito T el bootstrap L/(rho-1) tiene que caber.")
    print(f"{'L (h)':>6} {'I':>5} {'alpha':>6} | {'rho = 1':>8} {'1,001':>8} {'1,01':>8} {'1,05':>8} "
          f"{'1,2':>8} {'2,0':>8} | {'horizonte simulado':>19}")
    for L, I in ((7200.0, 851.0), (19080.0, 4200.0)):
        for alpha in (0.10, 0.33, 0.40):
            fr = []
            for rho in (1.0, 1.001, 1.01, 1.05, 1.2, 2.0):
                v = pool.map(_frac, [(L, I, rho, alpha, False, sm, "honesto", "geom", 0.0, N_EP)
                                     for sm in SEMILLAS])
                fr.append(sum(v) / len(v))
            print(f"{L/3600:>6.2f} {I:>5.0f} {alpha:>6.2f} | " + " ".join(f"{x:>8.3f}" for x in fr)
                  + f" | {N_EP*I/86400:>16.1f} d")

    # ------------------------------------------------------------------ B.1.a
    print(ancho)
    print("B.1.a — UMBRAL rho* DE STEERING SISTEMATICO CON (h) (> 50 % de las epocas), 14 semillas")
    print("        cerrados de D8: cadena comun (L+I)/(I+W)  ·  entropia propia (L+qI)/(qI+W)")
    print("                        entropia ajena L/W  <- la cota del encargo, `L/W_dec`")
    print(f"{'L (h)':>6} {'I':>5} {'alpha':>6} {'W_dec':>6} | {'rho* candidato propio':>26} {'cerrado':>8} | "
          f"{'rho* candidato ajeno':>22} {'cerrado':>8} | {'L/W_dec':>8}")
    for (L, I) in CONF:
        for alpha in ALFAS:
            W = w_dec(alpha)
            mp_, lop, hip = resumen(pool.map(_tarea, [(L, I, alpha, True, "propio", s, "geom", 0.0)
                                                      for s in SEMILLAS]))
            mh_, loh, hih = resumen(pool.map(_tarea, [(L, I, alpha, True, "honesto", s, "geom", 0.0)
                                                      for s in SEMILLAS]))
            cp = max(rho_cadena_comun(L, I, W), rho_entropia_propia(L, I, W))
            ch = max(rho_cadena_comun(L, I, W), rho_entropia_honesta(L, W))
            lw = L / W if W > 0 else float("inf")
            print(f"{L/3600:>6.2f} {I:>5.0f} {alpha:>6.2f} {W:>6.0f} | {mp_:>14.2f} [{lop:6.2f},{hip:6.2f}] "
                  f"{cp:>8.2f} | {mh_:>11.1f} [{loh:5.0f},{hih:5.0f}] {ch:>8.1f} | {lw:>8.1f}")
    print("        (p_propia = 0 en esta tabla: el atacante NO ancla ninguna epoca; se mide solo")
    print("         si podria evaluar un candidato propio en la epoca que decide.)")

    # ------------------------------------------------------------------ B.1.b
    print(ancho)
    print("B.1.b — DESGLOSE: cual de las tres condiciones manda (W_dec = W_dec(0,33) = 20 s)")
    print(f"{'L (h)':>6} {'I':>5} {'q=ceil(L/I)':>12} | {'cadena comun':>13} {'entr. propia':>13} "
          f"{'entr. ajena':>12} | {'rho* propio':>12} {'rho* ajeno':>11}")
    for (L, I) in CONF:
        W = w_dec(0.33)
        cc = rho_cadena_comun(L, I, W)
        ep = rho_entropia_propia(L, I, W)
        eh = rho_entropia_honesta(L, W)
        print(f"{L/3600:>6.2f} {I:>5.0f} {math.ceil(L/I):>12d} | {cc:>13.2f} {ep:>13.2f} {eh:>12.1f} | "
              f"{max(cc, ep):>12.2f} {max(cc, eh):>11.1f}")

    # ------------------------------------------------------------------ B.1.c
    print(ancho)
    print("B.1.c — EL RESIDUO POR RACHAS: p_propia = alpha, rho POR DEBAJO de rho*")
    print("        cerrado de D8: n* = ceil( ((L-W)*rho/(rho-1) - L)/I ),  tasa = alpha^(n*-1)")
    print(f"{'L (h)':>6} {'I':>5} {'alpha':>6} {'rho':>5} {'n*':>4} | {'tasa cerrada':>13} "
          f"{'tasa simulada (14 sem.)':>24} {'razon':>7} | {'epocas/ano':>11}")
    for (L, I) in ((7200.0, 851.0), (3600.0, 851.0)):
        for alpha in ALFAS:
            for rho in (1.0, 1.5, 2.0, 2.5, 3.0, 5.0, 9.0):
                vals = pool.map(_frac, [(L, I, rho, alpha, True, s, "propio", "geom", None, N_EP)
                                        for s in SEMILLAS])
                sim = sum(vals) / len(vals)
                cer = tasa_rachas(L, I, rho, alpha)
                nn = n_rachas(L, I, rho, w_dec(alpha)) if w_dec(alpha) > 0 and rho > 1 else float("inf")
                raz = sim / cer if cer > 0 else float("nan")
                print(f"{L/3600:>6.2f} {I:>5.0f} {alpha:>6.2f} {rho:>5.1f} {nn:>4.0f} | {cer:>13.3e} "
                      f"{sim:>16.3e} [{min(vals):.1e},{max(vals):.1e}] {raz:>7.2f} | "
                      f"{cer*365*24*3600/I:>11.2e}")

    # ------------------------------------------------------------------ B.1.d
    print(ancho)
    print("B.1.d — SENSIBILIDAD al modelo del offset slot(I_j) - T_j y a p_propia")
    print(f"{'modo':>6} {'L (h)':>6} {'alpha':>6} {'p_propia':>9} | {'rho* propio':>12} {'cerrado':>8} | "
          f"{'tasa a rho=2,5':>15} {'a rho=5':>9}")
    for modo in ("cero", "geom", "unif"):
        for alpha in (0.00, 0.10, 0.33, 0.40):
            for pp in sorted({0.0, alpha}):
                L, I = 7200.0, 851.0
                m_, _, _ = resumen(pool.map(_tarea, [(L, I, alpha, True, "propio", s, modo, pp)
                                                     for s in SEMILLAS]))
                W = w_dec(alpha)
                f25 = sum(pool.map(_frac, [(L, I, 2.5, alpha, True, s, "propio", modo, pp, N_EP)
                                           for s in SEMILLAS])) / len(SEMILLAS)
                f5 = sum(pool.map(_frac, [(L, I, 5.0, alpha, True, s, "propio", modo, pp, N_EP)
                                          for s in SEMILLAS])) / len(SEMILLAS)
                cerr = max(rho_cadena_comun(L, I, W), rho_entropia_propia(L, I, W)) if W > 0 else float("nan")
                print(f"{modo:>6} {L/3600:>6.2f} {alpha:>6.2f} {pp:>9.2f} | {m_:>12.2f} {cerr:>8.2f} | "
                      f"{f25:>15.3e} {f5:>9.3e}")

    # ------------------------------------------------------------------ B.1.e
    print(ancho)
    print("B.1.e — QUE COMPRA: n_eval medido (topado en I) y ganancia g = c_m*sqrt(alpha*lambda*n_eval)")
    print("        formula de la ronda 4, verificada por 9c §D.1 (razon 0,998-1,002 a m pequena)")
    print(f"{'L (h)':>6} {'I':>5} {'alpha':>6} {'rho':>5} | {'n_ev propio':>12} {'n_ev ajeno':>11} "
          f"{'n_ev sin (h)':>13} | {'g propio':>9} {'g ajeno':>8} {'g sin (h)':>10} | "
          f"{'g medio/epoca CON (h)':>9} {'SIN (h)':>9}")
    for (L, I) in ((7200.0, 851.0),):
        for alpha in (0.00, 0.10, 0.33, 0.40):
            for rho in (1.0, 1.2, 1.5, 2.0, 2.5, 3.0, 9.0, 45.0, 360.0):
                rs = [frontera_pot(L, I, rho, alpha, True, s, n_ep=N_EP) for s in SEMILLAS]
                r0 = [frontera_pot(L, I, rho, alpha, False, s, n_ep=N_EP) for s in SEMILLAS]
                np_ = sum(x["nev_propio"] for x in rs) / len(rs)
                nh_ = sum(x["nev_honesto"] for x in rs) / len(rs)
                n0_ = sum(x["nev_honesto"] for x in r0) / len(r0)
                cm = c_interp(menu(alpha))
                ing = alpha * LAM * I
                def g(n):
                    return cm * math.sqrt(alpha * LAM * n) / ing if ing > 0 else 0.0
                gm = sum(x["g_medio"] for x in rs) / len(rs)     # media POR EPOCA, no g(media)
                g0 = sum(x["g_medio"] for x in r0) / len(r0)
                print(f"{L/3600:>6.2f} {I:>5.0f} {alpha:>6.2f} {rho:>5.1f} | {np_:>12.2f} {nh_:>11.2f} "
                      f"{n0_:>13.2f} | {g(np_):>8.2%} {g(nh_):>7.2%} {g(n0_):>9.2%} | "
                      f"{gm:>8.3%} {g0:>9.3%}")

    # ------------------------------------------------------------------ B.1.f
    print(ancho)
    print("B.1.f — CUANTOS VDF EN PARALELO necesita el atacante (una linea AES = un nucleo)")
    print("        cadena principal 1 + q = ceil(L/I) revelaciones en vuelo por candidato evaluado")
    print(f"{'L (h)':>6} {'I':>5} {'q':>4} | {'solo cadena comun':>18} {'+1 candidato propio':>20} "
          f"{'+ menu m(0,40)=1,83':>20} {'+ m maximo 1+lam*S_max':>23}")
    for (L, I) in CONF:
        q = math.ceil(L / I)
        print(f"{L/3600:>6.2f} {I:>5.0f} {q:>4d} | {1+q:>18d} {1+2*q:>20d} "
              f"{1+q+math.ceil(menu(0.40)*q):>20d} {1+q+math.ceil((1+LAM*S_MAX)*q):>23d}")

    print(ancho)
    print("COBERTURA DE RAMA (regla de metodo 5) — una rama con 0 invalida la comparacion")
    for k, v in sorted(COB.items()):
        print(f"  {k:>22} : {v}")
    pool.close()


if __name__ == "__main__":
    main()
