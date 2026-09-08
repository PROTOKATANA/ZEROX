#!/usr/bin/env python3
"""
r8e_a1b_grinding.py — A1, segunda pregunta: ¿puede el atacante MOVER EL PESO?

El Lema E1 (A0c) dice que el peso solo puede invertir una decision si los bloques del
DESACUERDO tienen pesos distintos. Como `SR` es funcion de `past(B)` —de la ventana de
retarget de su padre seleccionado— la unica forma de que el atacante fabrique un bloque
con `w` distinto del de sus contemporaneos es **colgarlo de un ancestro de cadena de otra
ventana de dificultad**: `('retro', n)` con `n` grande. Eso es la version GHOSTDAG del
*difficulty grinding*.

Aqui se mide el CANJE de esa maniobra, que es lo que decide si sirve:
   · lo que GANA: `w(bloque del atacante) / w medio de los honestos contemporaneos`
   · lo que PAGA: `blue_score` que pierde su bloque frente a la punta honesta del momento
   · el resultado: cuota de bloques de cadena que consigue, y `sp!=`.

Para que sirviera haria falta `ganancia_de_peso > perdida_de_conteo` — y la perdida de
conteo crece LINEALMENTE con `n` (cada posicion de cadena hacia atras son ~λ_azul/λ_cadena
azules) mientras que la ganancia de peso esta acotada por `γ·|ln(N_obs/N_obj)|`, que es
O(γ/√N_obj). Se comprueba si eso es asi en el simulador.

Criterio alpha: con alpha=0 no hay bloques del atacante y todas las columnas son NaN/0.
"""
import math
import sys
from r8e_lib import MundoW, PesoCfg
from r8d_a1_menu import K, MP

HOR = 300.0
SEMS = list(range(1, 9))
POLS = [("tips", "tips")] + [(f"retro{n}", ("retro", n)) for n in (1, 2, 4, 8, 16, 32, 64)]


def canje(alpha, semilla, wcfg, pol):
    m = MundoW(alpha, HOR, semilla, k=K, mp=MP, u3_mode="dynamic", wcfg=wcfg)
    est = {i: (0.0, pol) for i, (t, q, *_) in enumerate(m.ev) if q == "a"}
    d, tip = m.corre(est)
    ch = set(d.selected_chain(tip))
    at = [b for b in d.B if d.B[b].creator == "a"]
    ho = [b for b in d.B if d.B[b].creator == "h"]
    if not at:
        return None
    # ganancia de peso: w del bloque del atacante / w medio de los honestos creados en
    # +-10 s de su instante de creacion (sus CONTEMPORANEOS, que es contra quien compite)
    gan, perd = [], []
    for b in at:
        tb = d.B[b].t
        vec = [d.w(h) for h in ho if abs(d.B[h].t - tb) <= 10.0]
        if not vec:
            continue
        gan.append(d.w(b) / (sum(vec) / len(vec)))
        bsv = [d.gd[h].blue_score for h in ho if abs(d.B[h].t - tb) <= 10.0]
        perd.append(d.gd[b].blue_score - sum(bsv) / len(bsv))
    n_a_ch = sum(1 for b in ch if d.B[b].creator == "a")
    c = d.cobertura()
    return (sum(gan) / len(gan) if gan else float("nan"),
            max(gan) if gan else float("nan"),
            sum(perd) / len(perd) if perd else float("nan"),
            n_a_ch / max(len(ch) - 1, 1), c["sp_discrepa"], c["peso_distinto"])


CFGS = [
    ("peso 1", PesoCfg(W=None)),
    ("desliz W=3083 g=.25", PesoCfg(W=3083.0, gamma=0.25, modo="desliz")),
    ("desliz W=80 g=.25", PesoCfg(W=80.0, gamma=0.25, modo="desliz")),
    ("desliz W=20 g=1.0", PesoCfg(W=20.0, gamma=1.0, modo="desliz")),
    ("epoca  W=20 g=1.0", PesoCfg(W=20.0, gamma=1.0, modo="epoca")),
]

if __name__ == "__main__":
    print("=== A1b · ¿puede el atacante MOVER EL PESO? el canje del `difficulty grinding` ===")
    print(f"k={K}, mp={MP}, horizonte {HOR:.0f} s, {len(SEMS)} semillas, u3_mode=dynamic.")
    print("`gan w` = w(bloque atacante) / w medio de honestos a +-10 s (>1 = pesa mas).")
    print("`pierde bs` = blue_score de su bloque menos el de los honestos contemporaneos.\n")
    print(f"{'configuracion':>21} {'politica':>9} {'alpha':>6} | {'gan w med':>10} "
          f"{'gan w MAX':>10} {'pierde bs':>10} | {'% cadena suya':>14} | {'sp!=':>5} "
          f"{'peso!=1':>8}")
    for nombre, wcfg in CFGS:
        for etq, pol in POLS:
            for alpha in (0.0, 0.25, 0.40):
                rs = [canje(alpha, s, wcfg, pol) for s in SEMS]
                rs = [r for r in rs if r]
                if not rs:
                    print(f"{nombre:>21} {etq:>9} {alpha:>6.2f} | "
                          f"{'(sin atacante)':>10}"); continue
                f = lambda i: sum(r[i] for r in rs) / len(rs)
                print(f"{nombre:>21} {etq:>9} {alpha:>6.2f} | {f(0):>10.4f} "
                      f"{max(r[1] for r in rs):>10.4f} {f(2):>10.2f} | {f(3):>13.1%} "
                      f"| {sum(r[4] for r in rs):>5} {sum(r[5] for r in rs):>8}")
        print()
