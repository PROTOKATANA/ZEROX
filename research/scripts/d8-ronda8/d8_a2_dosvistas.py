#!/usr/bin/env python3
"""
d8_a2_dosvistas.py — A2 · ACUERDO HONESTO CON DOS VISTAS DISTINTAS DE VERDAD.

La objecion (D9-a §4c, «Risk = 1», nunca cerrada). Toda medida de las rondas 8c..8f usa
UN DAG GLOBAL: se calcula el ancla sobre `d.virtual_sp(todo lo entregado)`. Pero R-FIN-1
la lee CADA NODO en SU vista, y R-FIN-2 la aplica en `t_j = slot(I_j) + L`. Si dos honestos
leen `I_j` distinto en `t_j`, R-FIN-3 les da FLUJOS distintos y R-FIN-5 les prohibe
referenciarse: **particion permanente**. La cota que el diseno invoca es `p_F` por epoca
(`dag-poas-recursion-flujos.md` §3), calculada como una carrera de Nakamoto — nunca medida.

Aqui hay DOS honestos, H_A y H_B, separados por `Delta`, cada uno con su `llega`, y el
atacante del paper (sin retardo, L1024-1027) que puede entregar a UNO SOLO.

Correccion de D8 al modelo heredado: **entregar un bloque entrega todo su pasado** (un nodo
no valida sin ancestros). Eso LIMITA la retencion —en cuanto un honesto construye sobre un
bloque sesgado, el otro lo recibe— y es lo realista; sin ese cierre el poder del atacante
estaria sobreestimado.

MEDIDA: para cada umbral de PoT `S` y cada profundidad de evaluacion `D_ev`, se lee el ancla
por `slot` en la vista de A y en la de B en `t = S + D_ev`, y se comparan por `seed`
(ESTRUCTURAL, fijado en la creacion; renombrar no lo altera).
   P(desacuerdo) = #(A != B) / #comparaciones.

CAPACIDAD (regla 4): se imprime `div_sp` = fraccion de instantes en que los DOS nodos tienen
padre seleccionado virtual DISTINTO. Si `div_sp = 0` las dos vistas serian la misma y la
medida no diria nada. Y `alpha = 0` es el valor neutro (regla 1): las vistas siguen
difiriendo por `Delta`, asi que `div_sp > 0` incluso ahi — es el suelo de la medida.
"""
import math
import sys
import time
from collections import defaultdict

sys.path.insert(0, "/home/katana/zeo/ZEROX/research/scripts/d8-ronda8")
from d8_lib import MundoDosVistas, vista_en                          # noqa: E402

K = 30
HOR = 900.0
SEMS = list(range(1, 13))                     # 12 semillas (regla 3)
ALPHAS = [0.0, 0.10, 0.25, 0.33, 0.40]
SS = list(range(100, 301, 20))                # 11 umbrales de PoT (1 slot = 1 s, gran=1)
DEVS = [4, 8, 16, 32, 64, 128, 256, 512]      # profundidad de evaluacion, en segundos
POLS = ["tips", "sp", ("retro", 2), ("retro", 8)]
SESGOS = ["ambos", "A", "alterna"]
FRACS = [1.0, 0.5]


def ancla_slot(d, sp, S):
    """R-FIN-1 con ancla por `slot`: el bloque de la cadena seleccionada con MENOR blue_work
    entre los de slot >= S. `slot` = indice de PoT = floor(t) con gran = 1 s."""
    mejor = None
    for b in d.selected_chain(sp):
        if math.floor(d.B[b].t) >= S:
            bw = d.gd[b].blue_work
            if mejor is None or bw < mejor[0]:
                mejor = (bw, d.B[b].seed)
    return None if mejor is None else mejor[1]


def una(alpha, sem, pol, sesgo, frac):
    m = MundoDosVistas(alpha, HOR, sem, k=K, mp=15)
    d, lA, lB = m.corre_2v(sesgo=sesgo, pol=pol, frac_sesgada=frac)
    des = defaultdict(lambda: [0, 0])      # D_ev -> [desacuerdos, comparaciones]
    divsp = [0, 0]
    for S in SS:
        for Dv in DEVS:
            t = S + Dv
            if t > HOR:
                continue
            _, spA = vista_en(d, lA, t)
            _, spB = vista_en(d, lB, t)
            divsp[1] += 1
            if spA != spB:
                divsp[0] += 1
            a = ancla_slot(d, spA, S)
            b = ancla_slot(d, spB, S)
            if a is None or b is None:
                continue
            des[Dv][1] += 1
            if a != b:
                des[Dv][0] += 1
    return des, divsp, m.n_sesgados


if __name__ == "__main__":
    print("=== A2 · P(dos honestos leen I_j distinto) con DOS vistas separadas por Delta ===")
    print(f"k={K}, lambda=1, Delta=4, mp=15, u3=dynamic, horizonte {HOR:.0f} s, "
          f"{len(SEMS)} semillas, {len(SS)} umbrales de PoT, ancla por `slot` (gran = 1 s).")
    print("Familia del atacante: pol in {tips, sp, retro2, retro8} x sesgo in "
          "{ambos, A, alterna} x frac in {1,0, 0,5}. Se reporta el MAXIMO sobre la familia.")
    print("Referencia: `p_F` por epoca de dag-poas-recursion-flujos.md §3 "
          "(carrera de Nakamoto, base r = alpha/((1-alpha)(1-delta))).\n")
    t_ini = time.time()

    cab = f"{'alpha':>6} | " + " ".join(f"{'D='+str(d):>10}" for d in DEVS) + \
          f" | {'div_sp':>7} {'sesgados':>9}"
    print("--- MAXIMO sobre la familia del atacante (la fila que cuenta) ---")
    print(cab); print("-" * len(cab))
    guarda = {}
    for alpha in ALPHAS:
        acc = {Dv: [0, 0] for Dv in DEVS}
        accmax = {Dv: 0.0 for Dv in DEVS}
        dsp = [0, 0]; nses = 0
        for pol in POLS:
            for sesgo in SESGOS:
                for frac in FRACS:
                    sub = {Dv: [0, 0] for Dv in DEVS}
                    for sem in SEMS:
                        des, divsp, ns = una(alpha, sem, pol, sesgo, frac)
                        for Dv, (x, y) in des.items():
                            sub[Dv][0] += x; sub[Dv][1] += y
                            acc[Dv][0] += x; acc[Dv][1] += y
                        dsp[0] += divsp[0]; dsp[1] += divsp[1]; nses += ns
                    for Dv in DEVS:
                        if sub[Dv][1]:
                            accmax[Dv] = max(accmax[Dv], sub[Dv][0] / sub[Dv][1])
        guarda[alpha] = (accmax, acc, dsp, nses)
        fila = " ".join(f"{accmax[Dv]:>10.5f}" for Dv in DEVS)
        print(f"{alpha:>6.2f} | {fila} | {dsp[0]/max(dsp[1],1):>7.3f} {nses:>9}")

    print("\n--- media sobre toda la familia (no el maximo) ---")
    print(cab)
    for alpha in ALPHAS:
        accmax, acc, dsp, nses = guarda[alpha]
        fila = " ".join(f"{acc[Dv][0]/max(acc[Dv][1],1):>10.5f}" for Dv in DEVS)
        print(f"{alpha:>6.2f} | {fila} | {dsp[0]/max(dsp[1],1):>7.3f}")
    print(f"\n[{time.time()-t_ini:.0f} s]")
