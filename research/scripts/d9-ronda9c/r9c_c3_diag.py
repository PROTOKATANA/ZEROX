#!/usr/bin/env python3
"""
r9c_c3_diag.py — diagnostico de la COLA LARGA de W_dec(i): ¿por que sigue cambiando el
ancla 600 s despues de T_j, si un bloque retenido mas de S_max ya no puede ser extendido?

Hipotesis H1: el bloque liberado NO entra en la cadena seleccionada (no puede, R-FIN-1a),
              pero PERTURBA el DAG (entra como rojo/azul en el mergeset de bloques honestos
              posteriores) y eso mueve `blue_work` lo justo para que la cadena seleccionada
              se decante por otra rama -> otro «primero con slot >= T_j».
Hipotesis H2: el bloque liberado SI entra en la cadena seleccionada (bug o hueco de la regla).

Se distingue mirando, para cada ancla del menu, el CREADOR y el SLOT, y comprobando si el
bloque liberado esta en la cadena seleccionada final.
"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from r9c_lib import MundoR9, SEMILLAS, eventos_atacante, slot_de

TJ, HOR, D = 200.0, 1200.0, 600.0
print(f"# TJ={TJ} HOR={HOR} d={D}  (liberacion en T_j+d = {TJ+D})")
for a in (0.0, 0.25, 0.40):
    for s in SEMILLAS[:6]:
        mu = MundoR9(a, HOR, s, s_max=150)
        todos = eventos_atacante(mu, TJ, TJ + D)
        paso = max(1, len(todos) // 15)
        lote = todos[::paso][:15]
        ret = {i: (None, "tips") for i in todos}   # retencion COMPLETA (consistencia)
        filas = []
        d0, t0 = mu.corre(ret)
        sd0, tt0 = mu.ancla(d0, t0, TJ)
        filas.append(("nada", sd0, tt0, None, None))
        for X in lote:
            e = dict(ret); e[X] = (TJ + D - mu.ev[X][0], "tips")
            dd, tt = mu.corre(e)
            sd, t = mu.ancla(dd, tt, TJ)
            ch = set(dd.selected_chain(tt))
            en_cadena = f"b{X}" in ch
            filas.append((f"b{X}@{mu.ev[X][0]:.1f}", sd, t, en_cadena, slot_de(mu.ev[X][0])))
        anclas = {f[1] for f in filas}
        if len(anclas) < 2:
            print(f"a={a:.2f} s={s}: menu = 1  (el ancla NO cambia)")
            continue
        print(f"a={a:.2f} s={s}: menu = {len(anclas)}  <-- COLA LARGA")
        for et, sd, t, ec, sl in filas:
            marca = "" if sd == sd0 else "   *** ANCLA DISTINTA"
            print(f"     libera {et:>16}  slot_lib={sl}  en_cadena_final={ec}  "
                  f"ancla_t={t if t is None else round(t,2)}{marca}")
