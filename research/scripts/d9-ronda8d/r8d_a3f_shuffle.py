#!/usr/bin/env python3
"""
r8d_a3f_shuffle.py — cierra la LAGUNA 1 de D9-c: el `shuffle` de `pick_virtual_parents`.

A3(5) encontro el mecanismo real del dano: NO es el presupuesto de mergeset (0 cortes por
`msl`, 0 sustituciones) sino el TOPE DE PADRES. Inundando con copias, las puntas pasan de
~2 a **240-548**, el honesto solo puede apuntar a `max_block_parents = 15`, las elige por
`blue_work` descendente, y las copias frescas —que bajo U3'' son ROJAS al colorear pero
conservan su PROPIO `blue_work` como candidatas a padre— desplazan a las puntas honestas,
que quedan **fuera del DAG para siempre**.

Kaspa tiene una contramedida exacta para esto y R-FIN-12 no la nombra
(processor.rs:1069-1089, comentario literal: *"Prioritize half the blocks with highest blue
work and pick the rest randomly to ensure diversity between nodes"*):

    max_candidates = max_block_parents * 3            (:975-980, = 45 con mp=15)
    si len(cands) > max_candidates:
        se conservan cands[:mp//2] (= 7) y para i en [7, 45) se intercambia con un j
        aleatorio en [i, len); luego se trunca a 45.
    elif len(cands) > mp//2:  shuffle de cands[7:]

Aqui se implementa literal y se vuelve a medir delta_hon.

Criterio alpha: alpha = 0 -> no hay copias, no hay inundacion, delta_hon identico.
"""
import random
from r8d_lib import Mundo, LAMBDA
from r8d_a3d_kaspa import MundoKaspa
from r8d_a1_menu import K, MP

T1, T2 = 80.0, 300.0


class MundoShuffle(MundoKaspa):
    """MundoKaspa (presupuesto + sustitucion) + el shuffle de :1069-1089."""

    def __init__(self, *a, **kw):
        super().__init__(*a, **kw)
        self.rng = random.Random(12345)

    def _padres(self, d, visibles):
        cands = sorted(d.tips(visibles), key=lambda h: -d.gd[h].blue_work)
        sp = cands[0]
        resto = cands[1:]
        maxc = self.mp * 3
        mitad = self.mp // 2
        if len(resto) > maxc:
            for i in range(mitad, maxc):
                j = self.rng.randrange(i, len(resto))
                resto[i], resto[j] = resto[j], resto[i]
            resto = resto[:maxc]
        elif len(resto) > mitad:
            cola = resto[mitad:]
            self.rng.shuffle(cola)
            resto = resto[:mitad] + cola
        cola = list(resto)
        padres = [sp]
        ms = 1
        while cola:
            if ms >= self.msl or len(padres) >= self.mp:
                break
            c = cola.pop(0)
            estado, val = self._mergeset_increase(d, padres, c, self.msl - ms)
            if estado == "accepted":
                ms += val
                padres.append(c)
            else:
                nuevo = val
                if any(d.is_ancestor(h, nuevo) for h in cola):
                    continue
                cola = [h for h in cola if not d.is_ancestor(nuevo, h)]
                cola.append(nuevo)
        return padres


def medida(cls, alpha, semilla, T, u3_mode, copias, pol):
    m = cls(alpha, T, semilla, k=K, mp=MP, u3_mode=u3_mode)
    est = {i: (0.0, pol) for i, (t, q, *_) in enumerate(m.ev) if q == "a"}
    d, tip = m.corre(est, copias=copias)
    az = d.blueset(tip)
    hon = [h for h in d.B if d.B[h].creator == "h" and T1 < d.B[h].t <= T2]
    ha = sum(1 for h in hon if h in az)
    nf = sum(1 for h in hon if h != tip and h not in d.anc[tip])
    return 1 - ha / ((1 - alpha) * LAMBDA * (T2 - T1)), nf


if __name__ == "__main__":
    print("=== A3(6) · el SHUFFLE de pick_virtual_parents frente a la inundacion de copias ===")
    print("ventana [80, 300] s, horizonte 400 s, 5 semillas. delta nominal 0,2105 / real 0,267\n")
    print(f"{'u3':>8} {'cop':>4} {'pol':>10} | {'alpha':>5} | {'SIN shuffle':>22} | {'CON shuffle (Kaspa)':>24}")
    for u3, cop, pol in (("dynamic", 0, "tips"), ("dynamic", 14, ("retro", 1)),
                         ("filter", 14, ("retro", 1))):
        for a in (0.0, 0.10, 0.25, 0.40):
            r0 = [medida(MundoKaspa, a, s, 400.0, u3, cop, pol) for s in range(1, 6)]
            r1 = [medida(MundoShuffle, a, s, 400.0, u3, cop, pol) for s in range(1, 6)]
            f = lambda rs, i: sum(x[i] for x in rs) / len(rs)
            print(f"{u3:>8} {cop:>4} {str(pol):>10} | {a:>5.2f} | "
                  f"d={f(r0,0):>7.4f} nofus={f(r0,1):>5.1f} | "
                  f"d={f(r1,0):>7.4f} nofus={f(r1,1):>5.1f}")
        print()
