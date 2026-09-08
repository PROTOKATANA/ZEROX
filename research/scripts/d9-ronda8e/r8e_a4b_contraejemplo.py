#!/usr/bin/env python3
"""
r8e_a4b_contraejemplo.py — A4 (segunda parte). El simulador dice `M2 = 141967/141967`:
`blue_score` sale monotono bajo ancestria en TODAS las parejas y en TODAS las
configuraciones de peso. Eso NO lo convierte en teorema — sale monotono porque en el
simulador el peso nunca llego a invertir una decision (`sp_discrepa = 0` en todo A0b).

Aqui se construye a mano el DAG que lo rompe, para dejar claro que:

  · `blue_work` monotono bajo ancestria es un TEOREMA (Lema A4b): la magnitud que se
    acumula es la misma que elige el padre seleccionado.
  · `blue_score` monotono bajo ancestria NO lo es: `sp` es el maximo por PESO, y en cuanto
    el peso y el conteo discrepan, un descendiente puede tener MENOS `blue_score` que un
    ancestro.

Construccion (k = 1, para que el k-cluster deje rojos a los bloques de la rama larga):
    G -> A0 -> A1 -> A2 -> A3        cuatro bloques LIGEROS  (w = e^-2)
    G -> B0 -> B1                    dos bloques PESADOS     (w = e^+2)
    Q  con padres [B1, A3]           sp(Q) = B1 por PESO (bw(B1) > bw(A3))
Con k = 1 los A quedan ROJOS en el mergeset de Q (su anticono azul es {B0,B1}, de tamaño
2 > k), asi que `blue_score(Q) = blue_score(B1) + 1 = 3 < 4 = blue_score(A3)`, y A3 ES
ANCESTRO de Q.

Consecuencia para ZEROX: R-FIN-10 define `altura := idx` sobre el orden y R-FIN-7 exige
monotonia; si algun dia el peso y el conteo discrepan (ventana de retarget corta, o un
ataque que lo fuerce), `blue_score` deja de ser una «altura» monotona. El ancla `blue_score`
NO depende de esto — solo necesita monotonia POR LA CADENA (M3), que es por construccion —
pero cualquier regla que use `blue_score` como altura, si.

Criterio alpha: no aplica (construccion determinista, sin adversario aleatorio); el papel
del adversario lo hace la eleccion explicita de pesos, y se comprueba que SIN esa eleccion
(peso 1) el contraejemplo desaparece.
"""
from r8e_lib import DAGW, PesoCfg


def construye(k, pesos):
    """`pesos`: dict bid -> ln SR. Devuelve el DAG ya con `blue_work` recalculado."""
    d = DAGW(k=k, u2=False, u3_mode="off", max_parents=15, mergeset_limit=10_000,
             wcfg=PesoCfg(W=None))
    g = d.genesis()

    def pon(bid, padres, t):
        ok, mot = d.add(bid, padres, t=t, creator="h", ident=(bid, 0), sd=0)
        assert ok, (bid, mot)
        d.lnsr[bid] = pesos.get(bid, 0.0)
        nd = d.gd[bid]
        nd.blue_work = d.gd[nd.sp].blue_work + sum(d.w(h) for h in nd.mergeset_blues)

    prev = g
    for i in range(4):
        pon(f"A{i}", [prev], 1.0 + i); prev = f"A{i}"
    prev = g
    for i in range(2):
        pon(f"B{i}", [prev], 1.0 + i); prev = f"B{i}"
    pon("Q", ["B1", "A3"], 10.0)
    return d


def informa(nombre, d):
    print(f"\n--- {nombre} ---")
    for b in ("A3", "B1", "Q"):
        print(f"   {b:>3}: blue_score={d.gd[b].blue_score:>2}  "
              f"blue_work={d.gd[b].blue_work:>8.4f}  w={d.w(b):.4f}  sp={d.gd[b].sp}")
    print(f"   mergeset_blues(Q) = {d.gd['Q'].mergeset_blues}")
    print(f"   mergeset_reds(Q)  = {d.gd['Q'].mergeset_reds}")
    viol_bs = [(w, q) for q in d.B for w in d.anc[q]
               if d.gd[q].blue_score <= d.gd[w].blue_score]
    viol_bw = [(w, q) for q in d.B for w in d.anc[q]
               if d.gd[q].blue_work <= d.gd[w].blue_work]
    print(f"   parejas (ancestro, descendiente) que ROMPEN blue_score monotono: {viol_bs}")
    print(f"   parejas que ROMPEN blue_work monotono (Lema A4b): {viol_bw}")
    return viol_bs, viol_bw


if __name__ == "__main__":
    print("=== A4b · contraejemplo a «blue_score es monotono bajo ancestria» ===")
    print("Rama A: 4 bloques LIGEROS. Rama B: 2 bloques PESADOS. Q = hijo de ambas, k=1.")

    d1 = construye(k=1, pesos={f"A{i}": 2.0 for i in range(4)} |
                             {f"B{i}": -2.0 for i in range(2)})
    v1, w1 = informa("PESO REAL (A ligeros e^-2, B pesados e^+2)", d1)

    d0 = construye(k=1, pesos={})
    v0, w0 = informa("PESO 1 (control: el mismo DAG, todos los pesos = 1)", d0)

    print("\nVEREDICTO")
    print(f"  con peso real: blue_score NO monotono ({len(v1)} parejas rotas) · "
          f"blue_work monotono ({len(w1)} parejas rotas)")
    print(f"  con peso 1   : blue_score {'NO ' if v0 else ''}monotono ({len(v0)} rotas) · "
          f"blue_work {'NO ' if w0 else ''}monotono ({len(w0)} rotas)")
    print(f"\n  => «blue_score monotono bajo ancestria» "
          f"{'REFUTADO como teorema' if v1 and not v0 else 'NO refutado aqui'}; "
          f"«blue_work monotono» (Lema A4b) {'se sostiene' if not w1 and not w0 else 'ROTO'}.")
