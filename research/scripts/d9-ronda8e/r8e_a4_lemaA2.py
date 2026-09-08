#!/usr/bin/env python3
"""
r8e_a4_lemaA2.py — LINEA A4. ¿Se TRANSFIERE el Lema A2 de D9-c al ancla `blue_score`,
con el peso real?

El Lema A2 (D9-c, `d9-ronda8c/informe.md` §A2) reduce «la cadena seleccionada cambia en una
posicion ≤ p» a una INVERSION DE PAREJA de la Def. 2, y por tanto a la Prop. 7. Para el
ancla `blue_score` hace falta un eslabon mas, porque el ancla no es una POSICION sino un
CRUCE:  I_j = primer bloque de la cadena con `blue_score ≥ T`.

LEMA A4 (lo que hay que demostrar).
  Sea `Chn` la cadena en t+r y `Chn'` la de s > t+r, y sea `I = I_T(Chn)`, `I' = I_T(Chn')`.
  Si `I ≠ I'` entonces las dos cadenas difieren en alguna posicion `p ≤ idx(I)`.

  Prueba. `blue_score` es ESTRICTAMENTE CRECIENTE a lo largo de la cadena seleccionada:
  `blue_score(C_i) = blue_score(C_{i-1}) + |mergeset_blues(C_i)|` (protocol.rs:153) y
  `mergeset_blues` contiene SIEMPRE al padre seleccionado (ghostdag.rs:115-120), luego el
  incremento es ≥ 1. Ademas `blue_score(B)` es funcion de `past(B)` y no cambia nunca.
  Sea `q = idx(I)`. Si las dos cadenas coincidieran en todas las posiciones `0..q`, los
  `blue_score` de esos `q+1` bloques serian los mismos, y por monotonia estricta el PRIMERO
  con `blue_score ≥ T` seria el mismo en las dos: `I' = I`. Contrapositivo: `I ≠ I'` obliga
  a `p ≤ q`. Encadenando con el Lema A2, el evento cae dentro del `∃C` de la Def. 2. ∎

  Lo que este lema NECESITA y `pos` no necesitaba: la MONOTONIA ESTRICTA de `blue_score`
  a lo largo de la cadena. Se comprueba.

  Lo que el Lema A2 NECESITA y con peso real hay que volver a comprobar: su paso (ii) usa
  el «Lema de monotonia» `bw(Q) ≥ bw(W)` cuando `W ≤ Q`. Con peso real:

  LEMA A4b (monotonia del peso). Si `W ∈ past(Q)` entonces `blue_work(Q) > blue_work(W)`,
  siempre que `w(b) > 0` para todo `b`.
    Prueba. Basta un paso de arista. Sea `P` padre de `Q` con `W ≤ P`. Entonces
    `blue_work(Q) = blue_work(sp(Q)) + Σ_{h∈mergeset_blues(Q)} w(h) ≥ blue_work(sp(Q)) + w(sp(Q))`
    (porque `sp(Q) ∈ mergeset_blues(Q)`) `> blue_work(sp(Q)) ≥ blue_work(P)`, donde la
    ultima desigualdad es `find_selected_parent = max por blue_work` (protocol.rs:99-106).
    Induccion sobre la longitud del camino. ∎
    OJO: el argumento funciona porque la MAGNITUD QUE SE ACUMULA ES LA MISMA QUE ELIGE EL
    PADRE. `blue_score` NO tiene esa propiedad con peso real: `sp` es el maximo por PESO,
    no por conteo, luego `blue_score(sp(Q)) ≥ blue_score(P)` NO se sigue. Se comprueba si
    aparecen contraejemplos.

Este script comprueba, sobre reorganizaciones REALES:
  (M1) `blue_work` estrictamente monotono bajo ancestria      [Lema A4b]
  (M2) `blue_score` estrictamente monotono bajo ancestria     [se espera que FALLE con peso]
  (M3) `blue_score` estrictamente creciente por la cadena     [lo que el Lema A4 necesita]
  (A2) los tres puntos del Lema A2 sobre los cambios de cadena
  (A4) si el ancla cambia => la cadena difiere en p ≤ idx(ancla)

Criterio alpha: el numero de reorganizaciones y de cambios de ancla crece con alpha.
"""
import sys
from r8e_lib import MundoW, PesoCfg
from r8d_a1_menu import K, MP

DELTA = 4.0


def una(alpha, semilla, wcfg, T=200.0, pasos=40, Ts=None):
    m = MundoW(alpha, T, semilla, k=K, mp=MP, u3_mode="dynamic", wcfg=wcfg)
    d, tip_final = m.corre({})
    llega = {"G": 0.0}
    for i, (t, q, sd, sde, ident) in enumerate(m.ev):
        if f"b{i}" in d.B:
            llega[f"b{i}"] = t + (DELTA if q == "h" else 0.0)

    # ---- (M1)(M2) monotonia bajo ancestria, sobre TODAS las parejas ancestro-descendiente
    m1_ok = m1_no = m2_ok = m2_no = 0
    for q in d.B:
        for w in d.anc[q]:
            if d.gd[q].blue_work > d.gd[w].blue_work:
                m1_ok += 1
            else:
                m1_no += 1
            if d.gd[q].blue_score > d.gd[w].blue_score:
                m2_ok += 1
            else:
                m2_no += 1

    # ---- (M3) blue_score estrictamente creciente por la cadena seleccionada
    m3_ok = m3_no = 0
    ch = d.selected_chain(tip_final)
    for i in range(1, len(ch)):
        if d.gd[ch[i]].blue_score > d.gd[ch[i - 1]].blue_score:
            m3_ok += 1
        else:
            m3_no += 1

    # ---- vistas crecientes
    ts = [T * (j + 1) / pasos for j in range(pasos)]
    vistas = []
    for tt in ts:
        vis = [h for h, ta in llega.items() if ta <= tt]
        if len(vis) < 2:
            continue
        vistas.append((tt, d.selected_chain(d.virtual_sp(vis)), set(vis)))

    if Ts is None:
        bsmax = max(d.gd[b].blue_score for b in ch)
        Ts = list(range(1, bsmax + 1, max(1, bsmax // 40)))

    def ancla(cad, T_):
        for i, b in enumerate(cad):
            if d.gd[b].blue_score >= T_:
                return i, b
        return None, None

    a2_tot = a2_sp = a2_ant = a2_inv = 0
    a4_tot = a4_ok = 0
    for a in range(len(vistas) - 1):
        for b in range(a + 1, len(vistas)):
            t1, c1, v1 = vistas[a]
            t2, c2, v2 = vistas[b]
            L = min(len(c1), len(c2))
            p = next((i for i in range(L) if c1[i] != c2[i]), None)
            if p is None:
                continue
            W, Wp, D = c1[p], c2[p], c1[p - 1]
            a2_tot += 1
            a2_sp += (d.gd[W].sp == D and d.gd[Wp].sp == D)
            a2_ant += ((not d.is_ancestor(W, Wp)) and (not d.is_ancestor(Wp, W)))
            o1 = d.total_order(d.virtual_sp(list(v1)))
            o2 = d.total_order(d.virtual_sp(list(v2)))

            def rel(o, x, y):
                ix = o.index(x) if x in o else None
                iy = o.index(y) if y in o else None
                if ix is None:
                    return None
                if iy is None:
                    return "<"
                return "<" if ix < iy else ">"
            a2_inv += (rel(o1, W, Wp) == "<" and rel(o2, Wp, W) == "<")

            # ---- (A4) el ancla: si cambia, la cadena difiere en p <= idx(ancla)
            for T_ in Ts:
                i1, b1 = ancla(c1, T_)
                i2, b2 = ancla(c2, T_)
                if b1 is None or b2 is None:
                    continue
                if b1 != b2:
                    a4_tot += 1
                    if p <= i1:
                        a4_ok += 1
            break
    return dict(m1_ok=m1_ok, m1_no=m1_no, m2_ok=m2_ok, m2_no=m2_no,
                m3_ok=m3_ok, m3_no=m3_no, a2_tot=a2_tot, a2_sp=a2_sp,
                a2_ant=a2_ant, a2_inv=a2_inv, a4_tot=a4_tot, a4_ok=a4_ok,
                cob=d.cobertura())


CFGS = [
    ("peso 1 (D9-d)", PesoCfg(W=None)),
    ("desliz W=3083 g=.25", PesoCfg(W=3083.0, gamma=0.25, modo="desliz")),
    ("desliz W=20 g=.25", PesoCfg(W=20.0, gamma=0.25, modo="desliz")),
    ("desliz W=10 g=1.0", PesoCfg(W=10.0, gamma=1.0, modo="desliz")),
    ("epoca  W=20 g=1.0", PesoCfg(W=20.0, gamma=1.0, modo="epoca")),
]

if __name__ == "__main__":
    print("=== A4 · ¿se transfiere el Lema A2 al ancla `blue_score` con peso real? ===")
    print(f"k={K}, mp={MP}, u3_mode=dynamic, horizonte 200 s, 8 semillas, 40 vistas.\n")
    print(f"{'configuracion':>21} {'alpha':>6} | {'M1 bw monot':>17} {'M2 bs monot':>17} "
          f"{'M3 bs cadena':>14} | {'cambios cad':>11} {'(i)':>6} {'(ii)':>6} {'(iii)':>6} "
          f"| {'cambios ancla':>13} {'A4 ok':>7} | {'peso!=1':>8}")
    for nombre, wcfg in CFGS:
        for alpha in (0.0, 0.10, 0.25, 0.40):
            rs = [una(alpha, s, wcfg) for s in range(1, 9)]
            S = lambda k: sum(r[k] for r in rs)
            c1 = "%d/%d" % (S("m1_ok"), S("m1_ok") + S("m1_no"))
            c2 = "%d/%d" % (S("m2_ok"), S("m2_ok") + S("m2_no"))
            c3 = "%d/%d" % (S("m3_ok"), S("m3_ok") + S("m3_no"))
            print(f"{nombre:>21} {alpha:>6.2f} | {c1:>17} {c2:>17} {c3:>14} | "
                  f"{S('a2_tot'):>11} {S('a2_sp'):>6} {S('a2_ant'):>6} {S('a2_inv'):>6} "
                  f"| {S('a4_tot'):>13} {S('a4_ok'):>7} "
                  f"| {sum(r['cob']['peso_distinto'] for r in rs):>8}")
        print()
    print("M1 = parejas (ancestro W, descendiente Q) con blue_work(Q) > blue_work(W)  [Lema A4b]")
    print("M2 = las mismas parejas con blue_score(Q) > blue_score(W)   [NO se sigue con peso real]")
    print("M3 = pasos de la cadena seleccionada con blue_score estrictamente creciente [Lema A4]")
    print("A4 ok = cambios de ancla en que la cadena YA difiere en una posicion p <= idx(ancla)")
