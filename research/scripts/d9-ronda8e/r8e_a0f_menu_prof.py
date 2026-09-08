#!/usr/bin/env python3
"""
r8e_a0f_menu_prof.py — parte (2) de A0e, separada para poder paralelizarla por `alpha`.

Menú del ancla `blue_score` leído en una posición de la cadena seleccionada POSTERIOR a
`t = 3 500 s`, con `W = 3 083 s`: la ventana del retarget ya está LLENA y el controlador
lleva miles de pasos. Es la única medida de esta ronda que toca el punto de diseño de
R-FIN-13 en régimen.

Familia GLOBAL reducida (5 estrategias). El `m` absoluto NO es comparable con el de A1;
solo lo son las dos filas entre sí, que es lo que se pregunta.

Uso: r8e_a0f_menu_prof.py <alpha>
Criterio alpha: alpha=0 -> m = 1 en las dos configuraciones.
"""
import sys
from r8e_lib import MundoW, PesoCfg
from r8d_a1_menu import lee, ancla_T, BANDA, K, MP

HOR = 6000.0
T_LEER = 3500.0
CFGS = [("peso 1", PesoCfg(W=None)),
        ("desliz W=3083 g=.25", PesoCfg(W=3083.0, gamma=0.25, modo="desliz"))]


def menu_profundo(alpha, semilla, wcfg):
    m = MundoW(alpha, HOR, semilla, k=K, mp=MP, u3_mode="dynamic", wcfg=wcfg)
    d0, tip0 = m.corre({})
    ch0 = d0.selected_chain(tip0)
    P = next((i for i, b in enumerate(ch0) if d0.B[b].t >= T_LEER), None)
    if P is None:
        return None
    tP = d0.B[ch0[P]].t
    T0 = d0.gd[ch0[P]].blue_score
    Ts = list(range(T0 - BANDA, T0 + BANDA + 1))
    idx = [i for i, (t, q, *_) in enumerate(m.ev) if q == "a" and tP - 30 <= t <= tP + 30]
    ests = [{}]
    for pol in ("sp", ("retro", 1), ("retro", 2), ("retro", 4)):
        ests.append({i: (0.0, pol) for i in idx})
    acum = {T: set() for T in Ts}
    spd = pd = sortd = 0
    for e in ests:
        d, tip = m.corre(e)
        c = d.cobertura()
        spd += c["sp_discrepa"]; pd += c["peso_distinto"]; sortd += c["sort_discrepa"]
        perfil = lee(d, tip)
        for T in Ts:
            s = ancla_T(perfil, T)
            if s is not None:
                acum[T].add(s)
    tam = [len(acum[T]) for T in Ts]
    return sum(tam) / len(tam), max(tam), spd, pd, sortd, P, len(idx)


if __name__ == "__main__":
    alpha = float(sys.argv[1])
    sems = [int(x) for x in (sys.argv[2].split(",") if len(sys.argv) > 2 else ["1", "2", "3"])]
    for nombre, wcfg in CFGS:
        rs = [menu_profundo(alpha, s, wcfg) for s in sems]
        rs = [r for r in rs if r]
        if not rs:
            print(f"{nombre:>21} {alpha:>6.2f} | sin datos", flush=True); continue
        print(f"{nombre:>21} {alpha:>6.2f} | "
              f"m_BS medio {sum(r[0] for r in rs)/len(rs):>7.2f}  max {max(r[1] for r in rs):>3} "
              f"| sp!= {sum(r[2] for r in rs):>5}  sort!= {sum(r[4] for r in rs):>5}  "
              f"peso!=1 {sum(r[3] for r in rs):>7} | P medio {sum(r[5] for r in rs)/len(rs):>7.0f}"
              f"  bloques del atacante en la banda {sum(r[6] for r in rs)/len(rs):>5.1f}",
              flush=True)
