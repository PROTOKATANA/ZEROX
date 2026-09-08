#!/usr/bin/env python3
"""
r8e_a1c_copias.py — A1, tercera pregunta. A3 encontro el UNICO regimen en que el peso real
llega a decidir distinto que el conteo (`sp_discrepa > 0`): la INUNDACION CON COPIAS del
mismo billete (R-FIN-11), que es el contraejemplo con el que D9-c rompio U3'-filtro. Bajo
esa inundacion hay cientos de puntas simultaneas con pasados distintos, luego con VENTANAS
DE RETARGET distintas, luego con pesos distintos: el Lema E1 deja de aplicar.

La pregunta que importa: en ESE regimen, ¿cambia el menu `m` del ancla `blue_score`?

Familia de estrategias reducida (para que quepa con 14 copias por bloque): el tier GRATIS
de D9-d ampliado con las profundidades `retro` que A1b identifico como la palanca de peso.

Criterio alpha: alpha=0 -> m = 1 y sp_discrepa = 0 en todas las configuraciones.
"""
import sys
from r8e_lib import MundoW, PesoCfg
from r8d_a1_menu import lee, ancla_T, BANDA, K, MP

HOR = 260.0
SEMS = list(range(1, 9))
POLS = ["sp", ("retro", 1), ("retro", 2), ("retro", 4), ("retro", 8), ("retro", 16)]


def menu(alpha, semilla, wcfg, copias, P=30):
    m = MundoW(alpha, HOR, semilla, k=K, mp=MP, u3_mode="dynamic", wcfg=wcfg)
    d0, tip0 = m.corre({}, copias=copias)
    ch0 = d0.selected_chain(tip0)
    if P >= len(ch0):
        return None
    tP = d0.B[ch0[P]].t
    T0 = d0.gd[ch0[P]].blue_score
    Ts = list(range(T0 - BANDA, T0 + BANDA + 1))
    idx = [i for i, (t, q, *_) in enumerate(m.ev) if q == "a" and tP - 30 <= t <= tP + 30]
    ests = [{}]
    for pol in POLS:
        ests.append({i: (0.0, pol) for i in idx})
    for i in idx:
        for pol in POLS:
            ests.append({i: (0.0, pol)})
    acum = {T: set() for T in Ts}
    spd = pd = 0
    for e in ests:
        d, tip = m.corre(e, copias=copias)
        c = d.cobertura()
        spd += c["sp_discrepa"]; pd += c["peso_distinto"]
        perfil = lee(d, tip)
        for T in Ts:
            s = ancla_T(perfil, T)
            if s is not None:
                acum[T].add(s)
    tam = [len(acum[T]) for T in Ts]
    return sum(tam) / len(tam), max(tam), spd, pd, len(ests)


CFGS = [
    ("peso 1", PesoCfg(W=None)),
    ("desliz W=3083 g=.25", PesoCfg(W=3083.0, gamma=0.25, modo="desliz")),
    ("desliz W=200 g=.25", PesoCfg(W=200.0, gamma=0.25, modo="desliz")),
    ("desliz W=20 g=1.0", PesoCfg(W=20.0, gamma=1.0, modo="desliz")),
]

if __name__ == "__main__":
    print("=== A1c · el menu en el UNICO regimen donde el peso decide: inundacion con copias ===")
    print(f"k={K}, mp={MP}, horizonte {HOR:.0f} s, {len(SEMS)} semillas, u3_mode=dynamic, "
          f"P=30, T0+-{BANDA}.")
    print("Familia GRATIS: sp, retro 1/2/4/8/16, global y bloque a bloque.\n")
    print(f"{'configuracion':>21} {'copias':>7} {'alpha':>6} | {'m_BS medio':>11} "
          f"{'m_BS max':>9} | {'sp!=':>7} {'peso!=1':>9} {'estrategias':>12}")
    for nombre, wcfg in CFGS:
        for cop in (0, 6, 14):
            for alpha in (0.0, 0.25, 0.40):
                rs = [menu(alpha, s, wcfg, cop) for s in SEMS]
                rs = [r for r in rs if r]
                if not rs:
                    print(f"{nombre:>21} {cop:>7} {alpha:>6.2f} | sin datos"); continue
                print(f"{nombre:>21} {cop:>7} {alpha:>6.2f} | "
                      f"{sum(r[0] for r in rs)/len(rs):>11.2f} "
                      f"{max(r[1] for r in rs):>9} | {sum(r[2] for r in rs):>7} "
                      f"{sum(r[3] for r in rs):>9} {sum(r[4] for r in rs)/len(rs):>12.1f}")
        print()
