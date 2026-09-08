#!/usr/bin/env python3
"""
r8d_a1_menu.py — LINEA A1. ?Es GRINDABLE el ancla `blue_score`?

R-FIN-1 (tercer ancla): I_j(B) = PRIMER bloque de la cadena seleccionada con
blue_score >= c*j. Aqui c*j = T, un umbral ENTERO Y FIJO del protocolo.

Metodo: identico al de D9-c (numeros aleatorios comunes, familia dirigida de
estrategias) para que la comparacion sea manzana con manzana. La UNICA diferencia
es la LECTURA: en la misma ejecucion se leen las dos anclas.

   ancla POS  (D9-c, refutada): seed del bloque en la posicion P de la cadena.
   ancla BS   (esta ronda)    : seed del primer bloque con blue_score >= T.

Un solo `corre()` alimenta las dos y ademas TODOS los umbrales T de una banda, asi
que el barrido de T es gratis. El menu se cuenta SIEMPRE sobre `seed` (fijado en la
creacion del bloque), nunca sobre etiquetas.

Criterio alpha: con alpha=0 los dos menus deben valer exactamente 1.
"""
import sys
from r8d_lib import Mundo

K, MP = 30, 15
BANDA = 10          # T recorre [T0-BANDA, T0+BANDA]


def estrategias(mundo, tP):
    """Familia dirigida de D9-c (r8c_a1_menu.py), copiada sin cambios de contenido:
    actua sobre los bloques del atacante creados en +-30 s del instante tP."""
    W = 30.0
    idx = [i for i, (t, q, *_) in enumerate(mundo.ev) if q == "a" and tP - W <= t <= tP + W]
    g1 = [{}]
    for pol in ("sp", ("retro", 1), ("retro", 2), ("retro", 4)):
        g1.append({i: (0.0, pol) for i in idx})
    for i in idx:
        for pol in ("sp", ("retro", 1), ("retro", 3)):
            g1.append({i: (0.0, pol)})
    g2 = []
    for d in (2.0, 6.0, 15.0, 40.0):
        g2.append({i: (d, "tips") for i in idx})
    for pol in ("sp", ("retro", 1), ("retro", 2)):
        g2.append({i: (6.0, pol) for i in idx})
    for i in idx:
        for pol in ("tips", ("retro", 1)):
            for r in (4.0, 12.0):
                g2.append({i: (r, pol)})
    g3 = [{i: (None, "tips") for i in idx}]
    for i in idx:
        for pol in ("tips", "sp", ("retro", 1), ("retro", 3)):
            for r in (0.0, 4.0, 12.0):
                e = {j: (None, "tips") for j in idx}
                e[i] = (r, pol)
                g3.append(e)
    return (g1, g2, g3), idx


def lee(d, tip):
    """Cadena seleccionada como [(blue_score, seed)] — una sola pasada sirve para
    todos los umbrales y para todas las posiciones."""
    return [(d.gd[b].blue_score, d.B[b].seed) for b in d.selected_chain(tip)]


def ancla_T(perfil, T):
    for bs, s in perfil:
        if bs >= T:
            return s
    return None


def menus(alpha, semilla, P, T_horizonte=260.0, u3_mode="dynamic", copias=0):
    m = Mundo(alpha, T_horizonte, semilla, k=K, mp=MP, u3_mode=u3_mode)
    d0, tip0 = m.corre({}, copias=0)
    ch0 = d0.selected_chain(tip0)
    if P >= len(ch0):
        return None
    tP = d0.B[ch0[P]].t
    T0 = d0.gd[ch0[P]].blue_score
    Ts = list(range(T0 - BANDA, T0 + BANDA + 1))
    tiers, idx = estrategias(m, tP)

    acum_pos = set()
    acum_bs = {T: set() for T in Ts}
    res_pos, res_bs_med, res_bs_max = [], [], []
    for g in tiers:
        for e in g:
            d, tip = m.corre(e, copias=copias)
            perfil = lee(d, tip)
            if P < len(perfil):
                acum_pos.add(perfil[P][1])
            for T in Ts:
                s = ancla_T(perfil, T)
                if s is not None:
                    acum_bs[T].add(s)
        res_pos.append(len(acum_pos))
        tam = [len(acum_bs[T]) for T in Ts]
        res_bs_med.append(sum(tam) / len(tam))
        res_bs_max.append(max(tam))
    return res_pos, res_bs_med, res_bs_max, len(idx)


if __name__ == "__main__":
    P = int(sys.argv[1]) if len(sys.argv) > 1 else 30
    u3 = sys.argv[2] if len(sys.argv) > 2 else "dynamic"
    cop = int(sys.argv[3]) if len(sys.argv) > 3 else 0
    semillas = list(range(1, 13))
    print(f"=== A1 · menu del ancla BLUE_SCORE frente al ancla POS (D9-c) ===")
    print(f"k={K}, mp={MP}, lambda=1, Delta=4, horizonte 260 s, u3_mode={u3}, copias={cop}")
    print(f"P={P}; T0 = blue_score del ocupante honesto de P; T recorre T0+-{BANDA} ({2*BANDA+1} umbrales)")
    print("Menu contado sobre `seed`, fijado en la creacion. Adversario del paper (sin retardo).\n")
    cab = f"{'alpha':>6} |"
    for et in ("GRATIS", "+retraso", "+retencion"):
        cab += f" {'m_POS ' + et:>16} {'m_BS ' + et:>16} |"
    print(cab)
    print(f"{'':>6} |" + "".join([f" {'(D9-c)':>16} {'medio  max':>16} |" for _ in range(3)]))
    for alpha in (0.0, 0.10, 0.25, 0.33, 0.40):
        filas = [menus(alpha, s, P, u3_mode=u3, copias=cop) for s in semillas]
        filas = [f for f in filas if f is not None]
        if not filas:
            print(f"{alpha:>6} sin datos"); continue
        linea = f"{alpha:>6.2f} |"
        for t in range(3):
            cp = [f[0][t] for f in filas]
            cbm = [f[1][t] for f in filas]
            cbx = [f[2][t] for f in filas]
            linea += (f" {sum(cp)/len(cp):>16.2f}"
                      f" {sum(cbm)/len(cbm):>9.2f}{max(cbx):>7} |")
        print(linea)
