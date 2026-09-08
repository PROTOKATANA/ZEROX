#!/usr/bin/env python3
"""
D8 ronda 10a · B.5 (carrera de bloques) y B.6 (el adelanto L(1-1/rho)).

B.5 · «Demuestra o refuta que (h) no cambia la frontera de flujo unico.»
      Instrumento: `research/scripts/verif_frontera_vs_F.py`, que reutiliza sin tocar el
      `prev()` de `d9-ronda9a/r9a_a3_frontera.py` (a su vez el de D8 y el de verif_constantes).
      `prev(alpha, lam, t, offset, hf)` tiene CINCO argumentos y ninguno es el reto del slot, ni
      `rho`, ni la entropia: (h) solo puede entrar por (i) `offset` —la ventaja inicial, `3k` en
      el Lema 10— y (ii) las constantes `(I, F)` admisibles. (i) es justamente B.6.

B.6 · «Con rho > 1 el atacante conoce los retos antes que los honestos aunque no pueda hacer
      steering: ¿que compra? Rafagas planificadas, retencion selectiva. Es la LAGUNA "rafagas"
      de 9c; acotala.»
      Modelo: con una ventaja de `V` slots el atacante conoce SUS PROPIAS victorias futuras
      durante `V` segundos (no las ajenas: no tiene los plots de nadie mas). Deslizando esa
      ventana mientras espera `T_esp`, elige el instante de arrancar su cadena privada donde su
      cosecha sea mayor. El exceso sobre la media es una ventaja inicial ADICIONAL a `3k`.
      Se MIDE con 12 semillas y se compara con el cerrado `sqrt(2 ln(T_esp/V)) * sqrt(alpha*lam*V)`.
      Luego se recalcula la frontera con `offset = 3k + exceso`.

Control positivo (regla 4): reproducir 46,8784 % / 36,5432 % con (F, I) = (19 080, 4 200), que
es lo que publica `verif_frontera_vs_F.salida.txt`.
"""
import math
import os
import sys

import numpy as np
from scipy.optimize import brentq

sys.path.insert(0, "/home/katana/zeo/ZEROX/research/scripts/d9-ronda9a")
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import r9a_a3_frontera as A                                   # noqa: E402
from r10a_lib import K, LAM, ventaja_pico, w_dec              # noqa: E402

SEMILLAS = [11, 23, 37, 41, 53, 67, 71, 83, 97, 101, 113, 127, 139, 151]   # 14 >= 12
T_ESP = {"1 dia": 86400.0, "1 semana": 604800.0, "1 mes": 2629800.0}


def set_F_I(F, I):
    A.F_SEG = float(F)
    A.I_EP = float(I)
    A.EP_ANO = 365 * 24 * 3600 / A.I_EP


def frontera(hf, offset, lo=0.20, hi=0.499, paso=0.005):
    """Frontera (union a 10 anos = 1e-10) con una ventaja inicial `offset` cualquiera.
    Copia literal del barrido de verif_frontera_vs_F.py, con `offset` como parametro."""
    def f(a):
        pf = A.prev(a, 1.0, A.F_SEG, offset, hf(a))
        return math.log10(max(min(1.0, pf * A.EP_ANO * A.ANOS), 1e-320)) + 10.0
    ant = None
    for a in np.arange(lo, hi + 1e-9, paso):
        v = f(a)
        if ant is not None and ant[1] < 0 <= v:
            return brentq(f, ant[0], a, xtol=1e-5)
        ant = (a, v)
    return float("nan")


def exceso_rafaga(alpha, V, t_esp, semilla, reps=200):
    """Exceso medio de victorias PROPIAS en la mejor ventana de `V` s dentro de `t_esp` s.
    Devuelve (exceso medio en bloques, cerrado sqrt(2 ln n)*sqrt(alpha*lam*V)).
    Con alpha = 0 tiene que dar 0: no hay victorias que cosechar."""
    rng = np.random.default_rng(semilla)
    mu = alpha * LAM * V
    n = max(1, int(t_esp / V))          # ventanas disjuntas dentro de la espera
    if mu <= 0:
        return 0.0, 0.0
    picos = rng.poisson(mu, size=(reps, n)).max(axis=1)
    cerrado = math.sqrt(2.0 * math.log(n)) * math.sqrt(mu) if n > 1 else 0.0
    return float(picos.mean() - mu), cerrado


def main():
    ancho = "=" * 122

    print(ancho)
    print("CONTROL — reproducir verif_frontera_vs_F.salida.txt con offset = 3k = 90")
    set_F_I(19080, 4200)
    hf0 = lambda a: 1.0                       # noqa: E731  (delta = 0, el modelo de 9a)
    hfD = lambda a: 1 - A.delta_interp(a)     # noqa: E731  (delta pesimista de D8)
    f0 = frontera(hf0, 3 * K)
    fD = frontera(hfD, 3 * K)
    print(f"  F = 19 080, I = 4 200: delta=0 -> {f0:.4%} (publicado 46,8784 %) · "
          f"delta D8 -> {fD:.4%} (publicado 36,5432 %)")
    ok = abs(f0 - 0.468784) < 1e-5 and abs(fD - 0.365432) < 1e-5
    print(f"  [{'IDENTICO' if ok else 'DISCREPA'}]   k = {K}, 3k = {3*K}")

    print(ancho)
    print("B.5 — (h) NO entra en el modelo de la carrera: `prev(alpha, lam, t, offset, hf)`.")
    print("      Lo unico que (h) puede mover son `offset` (B.6) y las `(I, F)` admisibles.")
    print("      Aqui: la frontera para las (I, F) que (h) hace posibles, con offset = 3k.")
    print(f"{'F (h)':>6} {'I':>5} | {'frontera delta=0':>17} {'frontera delta D8':>18} | "
          f"{'union10 a 33 %, delta=0':>24} {'delta D8':>11}")
    for F, I in ((19080, 4200), (7200, 851), (7200, 300), (3852, 851), (3600, 851), (1224, 851),
                 (1019, 851)):
        set_F_I(F, I)
        print(f"{F/3600:>6.2f} {I:>5} | {frontera(hf0, 3*K):>17.4%} {frontera(hfD, 3*K):>18.4%} | "
              f"{A.union10(0.33, 1.0):>24.3e} {A.union10(0.33, hfD(0.33)):>11.3e}")

    print(ancho)
    print("B.6.a — LA VENTANA QUE VE EL ATACANTE: ventaja de PoT en regimen, con (h) y sin (h)")
    print(f"{'L (h)':>6} {'I':>5} {'rho':>5} | {'sin (h) L+I(1-1/r)':>19} {'con (h) (L+I)(1-1/r)':>21} "
          f"{'cociente':>9}")
    for L, I in ((7200.0, 851.0), (3600.0, 851.0)):
        for rho in (1.0, 1.2, 1.5, 2.0, 2.5, 3.0):
            v0 = ventaja_pico(L, I, rho, w_dec(0.33), False)
            v1 = ventaja_pico(L, I, rho, w_dec(0.33), True)
            print(f"{L/3600:>6.2f} {I:>5.0f} {rho:>5.2f} | {v0:>19.0f} {v1:>21.0f} "
                  f"{(v0/v1 if v1 > 0 else float('inf')):>9.1f}")

    print(ancho)
    print("B.6.b — QUE COMPRA ESA VENTANA: exceso de victorias propias en la mejor ventana")
    print("        (14 semillas x 200 realizaciones; cerrado sqrt(2 ln n)*sqrt(alpha*lambda*V))")
    print(f"{'alpha':>6} {'V (s)':>7} {'espera':>9} {'n ventanas':>11} | {'exceso medido (bloques)':>24} "
          f"{'cerrado':>9} {'razon':>7} | {'% de 3k':>8}")
    filas_v = []
    for L, I in ((7200.0, 851.0),):
        for rho in (1.2, 1.5, 2.0, 3.0):
            filas_v.append(("sin (h)", ventaja_pico(L, I, rho, w_dec(0.33), False), rho))
            filas_v.append(("con (h)", ventaja_pico(L, I, rho, w_dec(0.33), True), rho))
    vistos = set()
    for alpha in (0.00, 0.10, 0.25, 0.33, 0.40):
        for etiq, V, rho in filas_v:
            if V < 1.0 or (alpha, round(V)) in vistos:
                continue
            vistos.add((alpha, round(V)))
            for nombre, te in T_ESP.items():
                med = [exceso_rafaga(alpha, V, te, s) for s in SEMILLAS]
                ex = sum(x for x, _ in med) / len(med)
                ce = med[0][1]
                n = max(1, int(te / V))
                print(f"{alpha:>6.2f} {V:>7.0f} {nombre:>9} {n:>11d} | {ex:>24.2f} {ce:>9.2f} "
                      f"{(ex/ce if ce > 0 else float('nan')):>7.3f} | {ex/(3*K):>7.1%}")
        vistos = {(a, v) for (a, v) in vistos if a != alpha} | vistos

    print(ancho)
    print("B.6.c — EFECTO SOBRE LA FRONTERA: offset = 3k + exceso, con la espera de 1 mes")
    print(f"{'F (h)':>6} {'I':>5} {'rho':>5} {'reg.':>8} {'V (s)':>7} | {'exceso a la frontera':>21} "
          f"{'offset':>8} | {'frontera delta=0':>17} {'vs 3k':>8} | {'frontera delta D8':>18} {'vs 3k':>8}")
    for F, I, L in ((7200, 851, 7200.0), (3600, 851, 3600.0)):
        set_F_I(F, I)
        base0 = frontera(hf0, 3 * K)
        baseD = frontera(hfD, 3 * K)
        for rho in (1.2, 1.5, 2.0, 2.5, 3.0):
            for etiq, con_h in (("sin (h)", False), ("con (h)", True)):
                V = ventaja_pico(L, I, rho, w_dec(0.33), con_h)
                if V < 1.0:
                    continue
                # el exceso se evalua EN la frontera, que es donde se decide: punto fijo simple
                a = base0
                for _ in range(6):
                    ex = sum(exceso_rafaga(a, V, T_ESP["1 mes"], s)[0] for s in SEMILLAS) / len(SEMILLAS)
                    a = frontera(hf0, 3 * K + ex)
                    if math.isnan(a):
                        break
                exD = sum(exceso_rafaga(baseD, V, T_ESP["1 mes"], s)[0] for s in SEMILLAS) / len(SEMILLAS)
                aD = frontera(hfD, 3 * K + exD)
                print(f"{F/3600:>6.2f} {I:>5} {rho:>5.2f} {etiq:>8} {V:>7.0f} | {ex:>21.2f} "
                      f"{3*K+ex:>8.1f} | {a:>17.4%} {a-base0:>+8.4%} | {aD:>18.4%} {aD-baseD:>+8.4%}")

    print(ancho)
    print("B.6.d — CRITERIO alpha: sin espacio no hay rafaga que planificar")
    print(f"{'alpha':>6} {'V = 4026 s (rho=2, con h)':>26} {'V = 7626 s (rho=2, sin h)':>26}")
    for alpha in (0.00, 0.05, 0.10, 0.25, 0.33, 0.40):
        e1 = sum(exceso_rafaga(alpha, 4026.0, T_ESP["1 mes"], s)[0] for s in SEMILLAS) / len(SEMILLAS)
        e2 = sum(exceso_rafaga(alpha, 7626.0, T_ESP["1 mes"], s)[0] for s in SEMILLAS) / len(SEMILLAS)
        print(f"{alpha:>6.2f} {e1:>26.3f} {e2:>26.3f}")


if __name__ == "__main__":
    main()
