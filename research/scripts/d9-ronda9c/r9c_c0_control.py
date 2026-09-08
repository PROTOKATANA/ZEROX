#!/usr/bin/env python3
"""
r9c_c0_control.py — CONTROL POSITIVO Y NEGATIVO antes de medir nada (regla de metodo 4).

C1 (positivo, teoria)  `c_m` reproduce los valores publicados c_2=0,564 y c_4=1,029
                       (`dag-poas-voto-auditoria.md` L199).
C2 (negativo)          con alpha = 0 el atacante NO EXISTE: el menu del ancla es 1 para
                       cualquier instante de decision. Si saliera > 1 el instrumento miente.
C3 (positivo)          con alpha > 0 y decision LIBRE (d = -inf, el atacante manipula desde
                       el principio) el ancla SI cambia. Si no cambiara nunca, el
                       instrumento seria ciego y toda la medida de C valdria cero.
C4 (control de regla)  R-FIN-1a se cumple en TODA arista de cadena de TODAS las corridas;
                       y las ramas de filtrado por S_max se EJERCITAN (contador > 0) al
                       menos con S_max = 20 o con retencion larga.
C5 (control de lectura) el ancla `menor blue_work con slot >= T` coincide con `el primero
                       de la cadena con slot >= T` (equivalencia de D9-f), y si no, se dice.
"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from r9c_lib import MundoR9, COB, SEMILLAS, slot_de, c_m, eventos_atacante

TJ = 200.0
HOR = 600.0
ALPHAS = [0.0, 0.10, 0.25, 0.33, 0.40]

print("=" * 92)
print("C1 · c_m contra los valores publicados (dag-poas-voto-auditoria.md L199)")
for m, pub in ((2, 0.564), (4, 1.029)):
    v = c_m(m)
    print(f"   c_{m} = {v:.4f}   publicado = {pub}   {'OK' if abs(v-pub) < 5e-4 else 'DISCREPA'}")

print()
print("=" * 92)
print("C2/C3 · el instrumento ve (o no ve) el cambio de ancla.  TJ = %.0f s, horizonte %.0f s" % (TJ, HOR))
print(f"{'alpha':>6} {'S_max':>6} | {'C2 menu(alpha=0)':>17} | {'C3 mundos con ancla cambiada':>29} | {'anclas distintas (max)':>22}")
tot_mal = 0
for smax in (150, 20):
    for a in ALPHAS:
        camb = 0
        maxmenu = 1
        for s in SEMILLAS:
            mu = MundoR9(a, HOR, s, s_max=smax)
            d0, tip0 = mu.corre()
            tot_mal += mu.chequea_rfin1a(d0, tip0)
            base, _ = mu.ancla(d0, tip0, TJ)
            vistos = {base}
            # decision LIBRE: manipula TODOS sus bloques desde el inicio
            idx = eventos_atacante(mu, 0.0, HOR)
            fam = [{}, {i: (0.0, "sp") for i in idx}, {i: (None, "tips") for i in idx},
                   {i: (30.0, "tips") for i in idx}, {i: (0.0, ("retro", 2)) for i in idx}]
            for i in idx[:20]:
                fam.append({i: (None, "tips")})
            for est in fam:
                d1, tip1 = mu.corre(est)
                tot_mal += mu.chequea_rfin1a(d1, tip1)
                sd, _ = mu.ancla(d1, tip1, TJ)
                if sd is not None:
                    vistos.add(sd)
            if len(vistos) > 1:
                camb += 1
            maxmenu = max(maxmenu, len(vistos))
        etiq = "menu=1 OK" if (a == 0.0 and maxmenu == 1) else ("MENU>1 !!" if a == 0.0 else "-")
        print(f"{a:>6.2f} {smax:>6} | {etiq:>17} | {camb:>8}/{len(SEMILLAS)} mundos{'':>10} | {maxmenu:>22}")

print()
print("C4 · violaciones de R-FIN-1a en TODAS las corridas:", tot_mal, "(debe ser 0)")
print("C4 · cobertura de rama:")
for kk, vv in COB.items():
    print(f"      {kk:>16} = {vv}")
print()
print("C5 · equivalencia 'menor blue_work' vs 'primero de la cadena' con slot >= T")
n = disc = 0
for a in ALPHAS:
    for s in SEMILLAS[:6]:
        mu = MundoR9(a, HOR, s, s_max=150)
        d, tip = mu.corre()
        ch = d.selected_chain(tip)
        for T in range(50, 500, 25):
            prim = next((b for b in ch if slot_de(d.B[b].t) >= T), None)
            cands = [(d.gd[b].blue_work, b) for b in ch if slot_de(d.B[b].t) >= T]
            if not cands:
                continue
            n += 1
            if min(cands)[1] != prim:
                disc += 1
print(f"      comprobaciones = {n}   discrepancias = {disc}")
