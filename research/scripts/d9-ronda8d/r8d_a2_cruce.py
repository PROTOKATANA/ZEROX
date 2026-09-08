#!/usr/bin/env python3
"""
r8d_a2_cruce.py — LINEA A2. El CRUCE DEL UMBRAL.

Pregunta: «primer bloque con blue_score >= c*j». ?Cuanto del menu se debe SOLO a
mover DONDE se cruza el umbral, sin cambiar la cadena seleccionada?

Tres medidas, sobre los mismos mundos y las mismas estrategias que A1:

 (1) GRANULARIDAD: distribucion del incremento de blue_score entre bloques de cadena
     consecutivos. Si el incremento medio es E, un desplazamiento de +-1 unidad mueve
     el ancla con probabilidad ~1/E: esa es la unica proteccion que blue_score aporta
     frente a `pos` (donde el incremento es SIEMPRE 1 y la probabilidad es 1).

 (2) MENU DE CADENA CONGELADA: menu acumulado contando SOLO las estrategias cuya
     cadena seleccionada final es IDENTICA (misma lista de bids) a la de referencia.
     Ahi la cadena no ha cambiado en absoluto: todo lo que se mueva es el cruce.

 (3) DESPLAZAMIENTO del blue_score en el bloque de referencia: cuantas unidades
     distintas de blue_score puede el atacante darle al MISMO bloque de cadena.

Criterio alpha: con alpha=0 las tres medidas deben dar el valor neutro (menu 1,
desplazamiento {0}).
"""
import sys, collections
from r8d_lib import Mundo
from r8d_a1_menu import estrategias, lee, ancla_T, BANDA, K, MP


def experimento(alpha, semilla, P, T_horizonte=260.0, u3_mode="dynamic"):
    m = Mundo(alpha, T_horizonte, semilla, k=K, mp=MP, u3_mode=u3_mode)
    d0, tip0 = m.corre({})
    ch0 = d0.selected_chain(tip0)
    if P >= len(ch0):
        return None
    ref = ch0[P]
    tP = d0.B[ref].t
    T0 = d0.gd[ref].blue_score
    Ts = list(range(T0 - BANDA, T0 + BANDA + 1))
    incrementos = [d0.gd[ch0[i]].blue_score - d0.gd[ch0[i - 1]].blue_score
                   for i in range(1, len(ch0))]

    tiers, _ = estrategias(m, tP)
    # dos acumuladores INDEPENDIENTES (se inicializan por separado a proposito: el
    # detector T3b de AUDITA_SCRIPTS.py marca dos variables con el mismo RHS largo).
    acum_all = dict((T, set()) for T in Ts)      # todas las estrategias
    acum_frz = {}                                # solo las de cadena congelada
    for T in Ts:
        acum_frz[T] = set()
    bs_ref = set()            # blue_scores distintos que puede tener el MISMO bloque ref
    n_frz = 0
    for g in tiers:
        for e in g:
            d, tip = m.corre(e)
            ch = d.selected_chain(tip)
            perfil = lee(d, tip)
            congelada = (ch == ch0)
            if congelada:
                n_frz += 1
            if ref in d.gd:
                # el bloque de referencia sigue existiendo: ?con que blue_score?
                if ref in ch:
                    bs_ref.add(d.gd[ref].blue_score - T0)
            for T in Ts:
                s = ancla_T(perfil, T)
                if s is not None:
                    acum_all[T].add(s)
                    if congelada:
                        acum_frz[T].add(s)
    med = lambda dd: sum(len(v) for v in dd.values()) / len(dd)
    mx = lambda dd: max(len(v) for v in dd.values())
    return dict(inc=incrementos, m_all=med(acum_all), m_all_max=mx(acum_all),
                m_frz=med(acum_frz), m_frz_max=mx(acum_frz), n_frz=n_frz,
                desp=sorted(bs_ref))


if __name__ == "__main__":
    P = int(sys.argv[1]) if len(sys.argv) > 1 else 30
    semillas = list(range(1, 13))
    print("=== A2 · el cruce del umbral ===")
    print(f"k={K}, mp={MP}, u3_mode=dynamic, P={P}, T0+-{BANDA}. Adversario del paper.\n")
    print("(1) GRANULARIDAD del blue_score en la cadena seleccionada")
    print(f"{'alpha':>6} | {'incr. medio':>12} {'mediana':>8} {'min':>4} {'max':>4} | {'P(incr=1)':>10}")
    guardado = {}
    for alpha in (0.0, 0.10, 0.25, 0.33, 0.40):
        rs = [experimento(alpha, s, P) for s in semillas]
        rs = [r for r in rs if r]
        guardado[alpha] = rs
        inc = [x for r in rs for x in r["inc"]]
        inc_s = sorted(inc)
        print(f"{alpha:>6.2f} | {sum(inc)/len(inc):>12.2f} {inc_s[len(inc_s)//2]:>8} "
              f"{min(inc):>4} {max(inc):>4} | {sum(1 for x in inc if x == 1)/len(inc):>10.3f}")
    print()
    print("(2) MENU con la cadena CONGELADA (identica a la de referencia) frente al menu total")
    print(f"{'alpha':>6} | {'m TOTAL':>9}{'max':>5} | {'m CADENA CONGELADA':>20}{'max':>5} | {'estrategias congeladas':>24}")
    for alpha, rs in guardado.items():
        a = sum(r["m_all"] for r in rs) / len(rs)
        ax = max(r["m_all_max"] for r in rs)
        f = sum(r["m_frz"] for r in rs) / len(rs)
        fx = max(r["m_frz_max"] for r in rs)
        nf = sum(r["n_frz"] for r in rs) / len(rs)
        print(f"{alpha:>6.2f} | {a:>9.2f}{ax:>5} | {f:>20.2f}{fx:>5} | {nf:>24.1f}")
    print()
    print("(3) DESPLAZAMIENTO del blue_score del MISMO bloque de referencia (unidades)")
    print(f"{'alpha':>6} | {'valores distintos':>18} | {'rango':>14}")
    for alpha, rs in guardado.items():
        nd = sum(len(r["desp"]) for r in rs) / len(rs)
        lo = min((r["desp"][0] for r in rs if r["desp"]), default=0)
        hi = max((r["desp"][-1] for r in rs if r["desp"]), default=0)
        print(f"{alpha:>6.2f} | {nd:>18.2f} | {f'[{lo} … {hi}]':>14}")
