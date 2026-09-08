#!/usr/bin/env python3
"""
r8d_a3e_diag.py — DIAGNOSTICO. En A3(4) los dos algoritmos de seleccion de padres dieron
resultados IDENTICOS hasta la cuarta cifra. Eso es exactamente lo que mi propio criterio
llama sospechoso: puede ser que la rama de SUSTITUCION nunca dispare. Se cuenta.

Y se busca la causa real de que 14-20 bloques HONESTOS queden fuera del DAG:
  (i)  presupuesto de mergeset agotado (`mergeset_size_limit`)
  (ii) tope de padres (`max_block_parents`) con demasiadas puntas
  (iii) el honesto sigue siendo PUNTA al final (nadie lo ha fusionado todavia)
"""
import collections
from r8d_lib import Mundo
from r8d_a3d_kaspa import MundoKaspa
from r8d_a1_menu import K, MP

CNT = collections.Counter()


class MundoInstr(MundoKaspa):
    def _padres(self, d, visibles):
        cands = sorted(d.tips(visibles), key=lambda h: -d.gd[h].blue_work)
        CNT["llamadas"] += 1
        CNT["puntas"] += len(cands)
        CNT["max_puntas"] = max(CNT["max_puntas"], len(cands))
        sp = cands[0]
        cola = list(cands[1:])
        padres = [sp]
        ms = 1
        while cola:
            if ms >= self.msl:
                CNT["corta_por_msl"] += 1
                break
            if len(padres) >= self.mp:
                CNT["corta_por_mp"] += 1
                break
            c = cola.pop(0)
            estado, val = self._mergeset_increase(d, padres, c, self.msl - ms)
            if estado == "accepted":
                ms += val
                padres.append(c)
            else:
                CNT["sustituciones"] += 1
                nuevo = val
                if any(d.is_ancestor(h, nuevo) for h in cola):
                    continue
                cola = [h for h in cola if not d.is_ancestor(nuevo, h)]
                cola.append(nuevo)
        CNT["ms_final"] += ms
        return padres


if __name__ == "__main__":
    print("=== A3(5) · diagnostico de la seleccion de padres bajo inundacion de copias ===\n")
    for a in (0.0, 0.25, 0.40):
        for cop, pol in ((0, "tips"), (14, ("retro", 1))):
            CNT.clear(); CNT["max_puntas"] = 0
            m = MundoInstr(a, 400.0, 3, k=K, mp=MP, u3_mode="dynamic")
            est = {i: (0.0, pol) for i, (t, q, *_) in enumerate(m.ev) if q == "a"}
            d, tip = m.corre(est, copias=cop)
            az = d.blueset(tip)
            hon = [h for h in d.B if d.B[h].creator == "h" and 80 < d.B[h].t <= 300]
            nofus = [h for h in hon if h != tip and h not in d.anc[tip]]
            tips_fin = set(d.tips(list(d.B)))
            sigue_punta = sum(1 for h in nofus if h in tips_fin)
            print(f"alpha={a:.2f} copias={cop:>2} pol={str(pol):<12} | bloques={len(d.B):>5} "
                  f"puntas medias={CNT['puntas']/max(1,CNT['llamadas']):>7.1f} "
                  f"max={CNT['max_puntas']:>5}")
            print(f"   corta_por_mp={CNT['corta_por_mp']:>5}  corta_por_msl={CNT['corta_por_msl']:>4}  "
                  f"SUSTITUCIONES={CNT['sustituciones']:>4}  mergeset medio={CNT['ms_final']/max(1,CNT['llamadas']):>6.1f}")
            print(f"   honestos en ventana={len(hon):>4}  no fusionados={len(nofus):>3}  "
                  f"de ellos SIGUEN SIENDO PUNTA al final={sigue_punta:>3}  "
                  f"rojos-pero-fusionados={sum(1 for h in hon if h in d.anc[tip] and h not in az):>3}")
