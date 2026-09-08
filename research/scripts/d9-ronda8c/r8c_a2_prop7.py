#!/usr/bin/env python3
"""
r8c_a2_prop7.py — LINEA A2: ?cubre la Prop. 7 la POSICION de la cadena seleccionada?

El principal argumenta (solucion §0): "el orden se construye a lo largo de la cadena, luego
orden estable => cadena estable". Ese paso NO es lo que dice la Prop. 7. La Prop. 7
(phantom-ghostdag.txt L1053-1056) es un enunciado POR PAREJAS:

  "the probability that the ORDERING OF TWO BLOCKS PUBLISHED BEFORE TIME t will change after
   time t+r is O(e^-cr)"

y la Def. 2 (L523-534) mide Risk_u(B,t,r) = Pr[ exists s>t+r, exists C: B<C en t+r y C<B en s ].
"El orden a profundidad d" no es una pareja, y "el orden cambia" no implica por si mismo que se
INVIERTA ninguna pareja: el orden es una SECUENCIA, y se puede reescribir insertando bloques
nuevos sin invertir a los viejos (eso es justo lo que hacen las copias contra el INDICE).

Aqui doy la demostracion correcta y la compruebo en el simulador.

LEMA A2. Sea `Chn` la cadena seleccionada del virtual honesto en t+r y `Chn'` la de un s > t+r.
Si difieren, sea p la MENOR posicion en que difieren, W = Chn[p], W' = Chn'[p]. Entonces
  (i)   sp(W) = sp(W') = Chn[p-1] =: D                       [def. de cadena y minimalidad de p]
  (ii)  W y W' estan en ANTICONO MUTUO
        [si W in past(W'): W in future(D) y W in past(W') => W in mergeset(W'); luego W' tiene un
         padre Q con W <= Q, y por el LEMA de monotonia bw(Q) >= bw(W) > bw(D); pero
         find_selected_parent es el MAXIMO (protocol.rs:99-106), asi que sp(W') != D. Contradiccion]
  (iii) W < W' en t+r  y  W' < W en s
        [en t+r W esta en la cadena en la posicion p y W' esta en su anticono, luego W' solo puede
         aparecer en el mergeset de un bloque de cadena de posicion > p (no puede estar en past(D)
         porque sp(W')=D) o no estar aun en G (Def. 2: "B<C when B in G but C not in G"); en ambos
         casos W < W'. En s, simetrico]
Por tanto  Pr[la cadena cambia en la posicion <= p despues de t+r] <= Risk_u(W, t, r) = O(e^-cr).

=> **La Prop. 7 SI cubre la posicion de cadena, y con una reduccion MAS LIMPIA que la del indice
   del orden**: el evento se mete entero dentro del `exists C` que la Def. 2 ya tiene DENTRO de la
   probabilidad. No hace falta la cota de la union que D9-a dejo como LAGUNA (a).

Este script comprueba (i), (ii) y (iii) sobre reorganizaciones REALES del simulador.
"""
import random
from r8c_sim import Mundo
from r8c_gd import DAG


def comprueba(alpha, semilla, T=200.0, pasos=40):
    """Reconstruye la vista honesta en instantes crecientes y busca cambios de cadena."""
    m = Mundo(alpha, T, semilla, k=30, mp=15, u3_mode="dynamic")
    d, tip_final = m.corre({})
    # instantes de "llegada" reconstruidos: honesto t+Delta, atacante t
    llega = {"G": 0.0}
    for i, (t, q, sd, sde, ident) in enumerate(m.ev):
        if f"b{i}" in d.B:
            llega[f"b{i}"] = t + (4.0 if q == "h" else 0.0)
    ts = [T * (j + 1) / pasos for j in range(pasos)]
    cadenas = []
    for tt in ts:
        vis = [h for h, ta in llega.items() if ta <= tt]
        if len(vis) < 2:
            continue
        cadenas.append((tt, d.selected_chain(d.virtual_sp(vis)), set(vis)))
    casos = []
    for a in range(len(cadenas) - 1):
        for b in range(a + 1, len(cadenas)):
            t1, c1, v1 = cadenas[a]
            t2, c2, v2 = cadenas[b]
            L = min(len(c1), len(c2))
            p = next((i for i in range(L) if c1[i] != c2[i]), None)
            if p is None:
                continue
            W, Wp = c1[p], c2[p]
            D = c1[p - 1]
            i_sp = (d.gd[W].sp == D and d.gd[Wp].sp == D)
            i_ant = (not d.is_ancestor(W, Wp)) and (not d.is_ancestor(Wp, W))
            # (iii): orden relativo en cada vista
            o1 = d.total_order(d.virtual_sp(list(v1)))
            o2 = d.total_order(d.virtual_sp(list(v2)))
            def rel(o, x, y):
                ix = o.index(x) if x in o else None
                iy = o.index(y) if y in o else None
                if ix is None:
                    return None
                if iy is None:
                    return "<"          # Def. 2: B<C cuando B in G y C not in G
                return "<" if ix < iy else ">"
            r1, r2 = rel(o1, W, Wp), rel(o2, Wp, W)
            i_inv = (r1 == "<" and r2 == "<")
            casos.append((t1, t2, p, i_sp, i_ant, i_inv))
            break
    return casos


if __name__ == "__main__":
    print("=== A2 · comprobacion empirica del LEMA A2 sobre reorganizaciones reales ===\n")
    tot = ok_sp = ok_ant = ok_inv = 0
    prof = []
    for alpha in (0.0, 0.10, 0.25, 0.40):
        c_a = 0
        for s in range(1, 9):
            for (t1, t2, p, a1, a2, a3) in comprueba(alpha, s):
                tot += 1; c_a += 1
                ok_sp += a1; ok_ant += a2; ok_inv += a3
                prof.append(p)
        print(f"  alpha={alpha:<5} reorganizaciones detectadas: {c_a}")
    print(f"\n  TOTAL {tot} cambios de cadena")
    print(f"   (i)   sp(W) = sp(W') = Chn[p-1] .............. {ok_sp}/{tot}")
    print(f"   (ii)  W y W' en anticono mutuo ............... {ok_ant}/{tot}")
    print(f"   (iii) W<W' antes y W'<W despues (inversion) .. {ok_inv}/{tot}")
    if prof:
        prof.sort()
        print(f"\n  profundidad del cambio: min={prof[0]} mediana={prof[len(prof)//2]} max={prof[-1]}")
