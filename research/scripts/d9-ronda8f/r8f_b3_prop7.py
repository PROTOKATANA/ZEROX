#!/usr/bin/env python3
"""
r8f_b3_prop7.py — PARTE B. ¿Cubre la Prop. 7 el ancla por SLOT?

Cadena de la cobertura, tal como quedo tras D9-c/D9-e:
  Lema A2 (D9-c)  «la cadena cambia en una posicion <= p» se reduce a una INVERSION DE
                  PAREJA de la Def. 2 => Prop. 7, sin cota de la union. Su paso (ii) usa
                  el Lema de monotonia `bw(Q) > bw(W)` para `W <= Q`, que con peso real es
                  el Lema A4b de D9-e (DEMOSTRADO).
  Lema A4 (D9-e)  para el ancla `blue_score`: «el ancla cambia => la cadena difiere en
                  p <= idx(ancla)».

LEMA A4-SLOT (lo que hay que demostrar aqui).
  Sea `Chn` la cadena en t+r y `Chn'` la de s > t+r, `I` = primer bloque de `Chn` con
  `slot >= S`, `I'` el de `Chn'`. Si `I != I'` las dos cadenas difieren en `p <= idx(I)`.

  Prueba. Sea `q = idx(I)`. Si las dos cadenas coincidieran en 0..q, entonces para todo
  `i < q` seria `slot(Chn'[i]) = slot(Chn[i]) < S` y `slot(Chn'[q]) = slot(Chn[q]) >= S`,
  luego el PRIMERO de `Chn'` que cruza `S` es `Chn'[q] = Chn[q] = I`. Contrapositivo. ∎

  **NO NECESITA MONOTONIA NINGUNA.** «El primer indice con la propiedad» esta determinado
  por el PREFIJO 0..q y por nada mas. D9-e apoyo el Lema A4 en la monotonia estricta de
  `blue_score` por la cadena; esa hipotesis es INNECESARIA, y el lema es por tanto MAS
  ROBUSTO de lo que D9-e afirmo — y se transfiere al `slot` aunque R-FIN-1a se relaje.

  Lo que SI necesita monotonia es la forma «MENOR blue_work con slot >= S»: coincide con
  «el primero» porque `blue_work` crece por la cadena (Lema A4b). Por eso `equiv != 0` es
  TEOREMA de A4b, no evidencia independiente: se comprueba como control de A4b, no como
  prueba del ancla.

Se comprueba sobre reorganizaciones REALES, con vistas honestas crecientes:
  (M1)     blue_work estrictamente monotono bajo ancestria       [Lema A4b]
  (M3sl)   slot estrictamente creciente por la cadena            [R-FIN-1a, POR GRANULARIDAD]
  (A2)     los tres puntos del Lema A2
  (A4bs)   el ancla blue_score cambia => cadena difiere en p <= idx
  (A4sl)   el ancla slot cambia       => cadena difiere en p <= idx

Criterio alpha: el numero de reorganizaciones y de cambios de ancla CRECE con alpha.
"""
import sys

from r8f_lib import Mundo, slot_de, K, MP, DELTA


def una(alpha, semilla, gran, T=200.0, pasos=40):
    m = Mundo(alpha, T, semilla, k=K, mp=MP, u3_mode="dynamic")
    d, tip = m.corre({})
    llega = {"G": 0.0}
    for i, (t, q, sd, sde, ident) in enumerate(m.ev):
        if f"b{i}" in d.B:
            llega[f"b{i}"] = t + (DELTA if q == "h" else 0.0)

    m1_ok = m1_no = 0
    for q in d.B:
        for w in d.anc[q]:
            if d.gd[q].blue_work > d.gd[w].blue_work:
                m1_ok += 1
            else:
                m1_no += 1

    ch = d.selected_chain(tip)
    m3_ok = m3_no = 0
    for i in range(1, len(ch)):
        if slot_de(d.B[ch[i]].t, gran) > slot_de(d.B[ch[i - 1]].t, gran):
            m3_ok += 1
        else:
            m3_no += 1

    ts = [T * (j + 1) / pasos for j in range(pasos)]
    vistas = []
    for tt in ts:
        vis = [h for h, ta in llega.items() if ta <= tt]
        if len(vis) < 2:
            continue
        vistas.append(d.selected_chain(d.virtual_sp(vis)))

    bsmax = max(d.gd[b].blue_score for b in ch)
    Ts = list(range(1, bsmax + 1, max(1, bsmax // 40)))
    smax = slot_de(d.B[tip].t, gran)
    Ss = [slot_de(u, gran) for u in range(1, int(T), max(1, int(T) // 40))]

    def primero(cad, val, key):
        for i, b in enumerate(cad):
            if key(b) >= val:
                return i, b
        return None, None

    kbs = lambda b: d.gd[b].blue_score                       # noqa: E731
    ksl = lambda b: slot_de(d.B[b].t, gran)                  # noqa: E731

    a2_tot = a2_sp = a2_ant = a2_inv = 0
    r = dict(bs=[0, 0], sl=[0, 0])
    for a in range(len(vistas) - 1):
        for b in range(a + 1, len(vistas)):
            c1, c2 = vistas[a], vistas[b]
            L = min(len(c1), len(c2))
            p = next((i for i in range(L) if c1[i] != c2[i]), None)
            if p is None or p == 0:
                continue
            W, Wp, D = c1[p], c2[p], c1[p - 1]
            a2_tot += 1
            a2_sp += (d.gd[W].sp == D and d.gd[Wp].sp == D)
            a2_ant += ((not d.is_ancestor(W, Wp)) and (not d.is_ancestor(Wp, W)))
            a2_inv += 1                                       # (iii) se sigue de (i)+(ii)
            for nom, vals, key in (("bs", Ts, kbs), ("sl", Ss, ksl)):
                for v in vals:
                    i1, b1 = primero(c1, v, key)
                    i2, b2 = primero(c2, v, key)
                    if b1 is None or b2 is None or b1 == b2:
                        continue
                    r[nom][0] += 1
                    if p <= i1:
                        r[nom][1] += 1
    return (m1_ok, m1_no, m3_ok, m3_no, a2_tot, a2_sp, a2_ant, a2_inv,
            r["bs"][1], r["bs"][0], r["sl"][1], r["sl"][0])


if __name__ == "__main__":
    print("=== B3 · ¿se transfiere el Lema A2/A4 al ancla SLOT? ===")
    print(f"k={K}, mp={MP}, horizonte 200 s, 40 vistas crecientes, 12 semillas, peso 1.")
    print("(A4x) = «el ancla cambia => la cadena difiere en p <= idx(ancla)»: ok/total.\n")
    print(f"{'gran':>6} {'alpha':>6} | {'M1 bw monot':>18} {'M3 slot crec.':>18} | "
          f"{'A2(i)':>12} {'A2(ii)':>12} | {'A4 blue_score':>16} {'A4 slot':>16}")
    for gran in (1.0, 0.1, 0.02):
        for alpha in (0.0, 0.10, 0.25, 0.40):
            rs = [una(alpha, s, gran) for s in range(1, 13)]
            S = [sum(x[i] for x in rs) for i in range(12)]
            print(f"{gran:>6} {alpha:>6.2f} | {S[0]:>10}/{S[0]+S[1]:<7} "
                  f"{S[2]:>8}/{S[2]+S[3]:<9} | {S[5]:>6}/{S[4]:<5} {S[6]:>6}/{S[4]:<5} | "
                  f"{S[8]:>7}/{S[9]:<8} {S[10]:>7}/{S[11]:<8}")
        print()
