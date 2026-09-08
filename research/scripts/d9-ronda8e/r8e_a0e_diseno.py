#!/usr/bin/env python3
"""
r8e_a0e_diseno.py — el PUNTO DE DISEÑO de verdad, con la ventana LLENA.

Defecto de A0/A0b/A1/A2 que declaro yo mismo: con `W = 3 083 s` y horizonte 260-900 s la
ventana de retarget NUNCA se llena, así que Kaspa (`difficulty.rs:170-178`) hereda los
`bits` del padre y `w ≡ 1`. Esa fila NO mide el punto de diseño: mide que en 260 s no hay
retarget. Aquí se corre con horizonte **6 000 s**, casi el doble de la ventana, para que el
retarget lleve ~2 900 pasos reales antes de leer nada.

(1) Cobertura y `epsilon` reales en el punto de diseño, con adversario.
(2) Menú del ancla en una posición de cadena POSTERIOR a `t = 3 500 s`, es decir con la
    ventana llena y el retarget en régimen, familia GRATIS.

Criterio alpha: alpha=0 -> menú 1 y sin bloques del atacante.
"""
import math
import sys
from r8e_lib import MundoW, PesoCfg
from r8d_a1_menu import lee, ancla_T, BANDA, K, MP

HOR = 6000.0
T_LEER = 3500.0          # > W: la ventana ya esta llena
LAM_AZUL = 0.97


class MundoMar(MundoW):
    """Añade la medida del margen y de la `epsilon` DIFERENCIAL (como A0c)."""
    pass


def cobertura(alpha, semilla, wcfg, pol, retraso, copias):
    m = MundoW(alpha, HOR, semilla, k=K, mp=MP, u3_mode="dynamic", wcfg=wcfg)
    est = {i: (retraso, pol) for i, (t, q, *_) in enumerate(m.ev) if q == "a"}
    d, tip = m.corre(est, copias=copias)
    c = d.cobertura()
    wa = [d.w(b) for b in d.B if d.B[b].creator == "a"]
    wh = [d.w(b) for b in d.B if d.B[b].creator == "h"]
    c["razon"] = (sum(wa) / len(wa)) / (sum(wh) / len(wh)) if wa and wh else float("nan")
    c["n"] = len(d.B)
    return c


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
    # familia GLOBAL reducida (el horizonte de 6 000 s no admite la familia completa):
    # 5 estrategias. El `m` de aqui NO es comparable con el de A1; solo las columnas entre si.
    ests = [{}]
    for pol in ("sp", ("retro", 1), ("retro", 2), ("retro", 4)):
        ests.append({i: (0.0, pol) for i in idx})
    acum = {T: set() for T in Ts}
    spd = pd = 0
    for e in ests:
        d, tip = m.corre(e)
        c = d.cobertura()
        spd += c["sp_discrepa"]; pd += c["peso_distinto"]
        perfil = lee(d, tip)
        for T in Ts:
            s = ancla_T(perfil, T)
            if s is not None:
                acum[T].add(s)
    tam = [len(acum[T]) for T in Ts]
    return sum(tam) / len(tam), max(tam), spd, pd, len(ests), P


CFGS = [("peso 1", PesoCfg(W=None)),
        ("desliz W=3083 g=.25", PesoCfg(W=3083.0, gamma=0.25, modo="desliz"))]

if __name__ == "__main__":
    sems = list(range(1, 5))
    s_nota = 0.25 * math.sqrt(HOR / (3083.0 ** 2 * LAM_AZUL))
    print("=== A0e · el PUNTO DE DISEÑO con la ventana LLENA (horizonte 6 000 s) ===")
    print(f"k={K}, mp={MP}, W=3083 s, gamma=0,25, u3_mode=dynamic, {len(sems)} semillas.")
    print(f"Prediccion de dag-poas-empalme-peso.md §2 sobre este horizonte: "
          f"s_nota = {s_nota:.5f}\n")

    print("(1) COBERTURA y epsilon REALES en el punto de diseño, con adversario")
    print(f"{'pol':>12} {'ret':>4} {'cop':>4} {'alpha':>6} | {'n bloq':>7} {'retarg':>7} "
          f"{'peso!=1':>8} {'w!=':>7} {'sp!=':>6} {'sort!=':>7} | {'sd(ln w)':>9} "
          f"{'rango ln w':>18} | {'w at/w hon':>11}")
    # `retro 64` y `copias=14` con horizonte 6 000 s son inviables (el paseo por la cadena
    # es O(longitud de cadena) por bloque del atacante, ~3 000 pasos). Se sustituyen por
    # `retro 32` (misma palanca, la mitad de coste) y `copias=2`. DECLARADO.
    for pol, ret, cop in (("tips", 0.0, 0), (("retro", 8), 0.0, 0),
                          ("tips", 40.0, 0), (("retro", 1), 0.0, 2)):
        for alpha in (0.0, 0.25, 0.40):
            cs = [cobertura(alpha, s, CFGS[1][1], pol, ret, cop) for s in sems]
            lo = min(c["rango_lnw"][0] for c in cs)
            hi = max(c["rango_lnw"][1] for c in cs)
            raz = [c["razon"] for c in cs if c["razon"] == c["razon"]]
            print(f"{str(pol):>12} {ret:>4.0f} {cop:>4} {alpha:>6.2f} | "
                  f"{sum(c['n'] for c in cs)//len(cs):>7} "
                  f"{sum(c['retargets'] for c in cs):>7} "
                  f"{sum(c['peso_distinto'] for c in cs):>8} "
                  f"{sum(c['sp_pesos_dist'] for c in cs):>7} "
                  f"{sum(c['sp_discrepa'] for c in cs):>6} "
                  f"{sum(c['sort_discrepa'] for c in cs):>7} | "
                  f"{sum(c['spread_lnw'] for c in cs)/len(cs):>9.5f} "
                  f"{f'[{lo:+.4f}, {hi:+.4f}]':>18} | "
                  f"{(sum(raz)/len(raz) if raz else float('nan')):>11.5f}")
    print()

    print(f"(2) MENU del ancla en una posicion de cadena con t >= {T_LEER:.0f} s "
          f"(ventana LLENA), familia GRATIS")
    print(f"{'configuracion':>21} {'alpha':>6} | {'m_BS medio':>11} {'m_BS max':>9} "
          f"| {'sp!=':>6} {'peso!=1':>9} {'P (posicion)':>13}")
    for nombre, wcfg in CFGS:
        for alpha in (0.0, 0.25, 0.40):
            rs = [menu_profundo(alpha, s, wcfg) for s in range(1, 4)]
            rs = [r for r in rs if r]
            if not rs:
                print(f"{nombre:>21} {alpha:>6.2f} | sin datos"); continue
            print(f"{nombre:>21} {alpha:>6.2f} | "
                  f"{sum(r[0] for r in rs)/len(rs):>11.2f} {max(r[1] for r in rs):>9} "
                  f"| {sum(r[2] for r in rs):>6} {sum(r[3] for r in rs):>9} "
                  f"{sum(r[5] for r in rs)/len(rs):>13.0f}")
        print()
