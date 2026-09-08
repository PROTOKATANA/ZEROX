#!/usr/bin/env python3
"""
r8e_a3_lema9.py — LINEA A3. El LEMA 9 con el peso real, y la suposicion del EMPALME.

El Lema 9 (`phantom-ghostdag.txt` L1074-1077 y su prueba L1100-1160) esta enunciado sobre
`score` = CONTEO de azules; su prueba es un argumento de conteo literal («the adversary has
managed to replace `k + 2Dλ` blue blocks with `k + 1` blue blocks»). Kaspa compara PESO.
`dag-poas-empalme-peso.md` reduce la brecha a una restriccion `(γ, W)` **suponiendo `N_obs`
Poisson SIN atacante** — y lo declara LAGUNA 1. Aqui se mide.

(1) `delta_ef` en PESO frente a `delta_ef` en CONTEO, mismos escenarios que D9-d A3g
    (`salida_a3g.txt`, peor caso 0,1293 con U3'' dinamica y `pick_virtual_parents`
    completo). Con peso:

      delta_peso = 1 − (peso de los honestos de la ventana que acaban AZULES)
                       / (peso de los honestos creados en la ventana)

    Si el atacante puede tirar honestos PESADOS y dejar los ligeros, `delta_peso` supera a
    `delta_conteo` y el Lema 9 en peso NO esta acotado por el Lema 9 en conteo.

(2) La suposicion del empalme: bajo ATAQUE, ¿deriva el retarget mas de lo que la nota
    acota? Se mide `E[ln w]` y su desviacion por alpha y por estrategia, y se compara con
    la prediccion de la nota, `s = γ·√(F/(W²·λ_azul))`. Se separa:
      · deriva COMUN   (mueve a los dos bandos por igual; se cancela en `find_selected_parent`)
      · deriva DIFERENCIAL (peso medio de los bloques del atacante / de los honestos)
    porque son dos cosas distintas y la nota las confunde en un solo `epsilon`.

Criterio alpha: alpha=0 -> delta_peso = delta_conteo = 0 y deriva diferencial = 1,0000.
"""
import math
import sys
from r8e_lib import MezclaPeso, MundoW, PesoCfg
from r8d_a3f_shuffle import MundoShuffle
from r8d_a1_menu import K, MP

T1, T2 = 80.0, 300.0
HOR = 400.0
DELTA_NOM, DELTA_REAL = 8 / 38, 0.267
LAM_AZUL = 0.97


class MundoWShuffle(MezclaPeso, MundoShuffle):
    """`pick_virtual_parents` COMPLETO (presupuesto + sustitucion + shuffle, D9-d A3f)
    con `blue_work` REAL."""
    pass


def delta_pareja(alpha, semilla, wcfg, u3_mode, copias, pol, retraso=0.0, T=HOR):
    """Devuelve (delta_conteo, delta_peso, w_medio_hon_azul, w_medio_hon_rojo, cobertura)."""
    m = MundoWShuffle(alpha, T, semilla, k=K, mp=MP, u3_mode=u3_mode, wcfg=wcfg)
    est = {i: (retraso, pol) for i, (t, q, *_) in enumerate(m.ev) if q == "a"}
    d, tip = m.corre(est, copias=copias)
    az = d.blueset(tip)
    hon = [h for h in d.B if d.B[h].creator == "h" and T1 < d.B[h].t <= T2]
    if not hon:
        return None
    n_az = sum(1 for h in hon if h in az)
    p_tot = sum(d.w(h) for h in hon)
    p_az = sum(d.w(h) for h in hon if h in az)
    wa = [d.w(h) for h in hon if h in az]
    wr = [d.w(h) for h in hon if h not in az]
    return (1 - n_az / len(hon),
            1 - p_az / p_tot if p_tot > 0 else float("nan"),
            sum(wa) / len(wa) if wa else float("nan"),
            sum(wr) / len(wr) if wr else float("nan"),
            d.cobertura())


def deriva(alpha, semilla, wcfg, pol="tips", retraso=0.0, T=HOR):
    """E[ln w] global, y peso medio de los bloques del ATACANTE frente a los HONESTOS."""
    m = MundoWShuffle(alpha, T, semilla, k=K, mp=MP, u3_mode="dynamic", wcfg=wcfg)
    est = {i: (retraso, pol) for i, (t, q, *_) in enumerate(m.ev) if q == "a"}
    d, tip = m.corre(est)
    lw = [-d.lnsr[b] for b in d.lnsr]
    mu = sum(lw) / len(lw)
    sd = math.sqrt(sum((x - mu) ** 2 for x in lw) / max(len(lw) - 1, 1))
    wa = [d.w(b) for b in d.B if d.B[b].creator == "a"]
    wh = [d.w(b) for b in d.B if d.B[b].creator == "h"]
    ch = d.selected_chain(tip)
    lw_ch = [-d.lnsr[b] for b in ch]
    return (mu, sd, sum(wa) / len(wa) if wa else float("nan"),
            sum(wh) / len(wh) if wh else float("nan"),
            lw_ch[-1] - lw_ch[0], d.cobertura())


CFGS = [
    ("peso 1 (D9-d)", PesoCfg(W=None)),
    ("desliz W=200 g=.25", PesoCfg(W=200.0, gamma=0.25, modo="desliz")),
    ("desliz W=80 g=.25", PesoCfg(W=80.0, gamma=0.25, modo="desliz")),
    ("desliz W=20 g=1.0", PesoCfg(W=20.0, gamma=1.0, modo="desliz")),
]

ESCEN = [("dynamic", 0, "tips", 0.0),
         ("dynamic", 14, ("retro", 1), 0.0),
         ("dynamic", 14, ("retro", 8), 0.0),
         ("dynamic", 14, ("retro", 1), 12.0),
         ("filter", 14, ("retro", 1), 0.0)]

if __name__ == "__main__":
    sems = list(range(1, 9))
    print("=== A3 · Lema 9 en PESO, y la suposicion del empalme ===")
    print(f"k={K}, mp={MP}, ventana [{T1:.0f},{T2:.0f}] s, horizonte {HOR:.0f} s, "
          f"{len(sems)} semillas, `pick_virtual_parents` completo (MundoShuffle de D9-d).")
    print(f"Cotas: delta nominal {DELTA_NOM:.4f} · delta_real {DELTA_REAL}\n")

    print("(1) delta_ef en CONTEO vs en PESO")
    print(f"{'configuracion':>20} {'u3':>8} {'cop':>4} {'pol':>11} {'ret':>4} {'alpha':>6} "
          f"| {'d_conteo':>9} {'d_PESO':>9} {'d_P-d_C':>9} | {'w azul':>8} {'w rojo':>8} "
          f"| {'peso!=1':>8} {'sp!=':>5}")
    peor = {}
    for nombre, wcfg in CFGS:
        for u3, cop, pol, ret in ESCEN:
            for a in (0.0, 0.10, 0.25, 0.40):
                rs = [delta_pareja(a, s, wcfg, u3, cop, pol, ret) for s in sems]
                rs = [r for r in rs if r]
                dc = sum(r[0] for r in rs) / len(rs)
                dp = sum(r[1] for r in rs) / len(rs)
                waz = [r[2] for r in rs if r[2] == r[2]]
                wro = [r[3] for r in rs if r[3] == r[3]]
                C = [r[4] for r in rs]
                if u3 == "dynamic":
                    k2 = peor.get(nombre, (0, 0, None))
                    if dp > k2[1]:
                        peor[nombre] = (dc, dp, (cop, pol, ret, a))
                print(f"{nombre:>20} {u3:>8} {cop:>4} {str(pol):>11} {ret:>4.0f} {a:>6.2f} "
                      f"| {dc:>9.4f} {dp:>9.4f} {dp - dc:>+9.4f} "
                      f"| {(sum(waz)/len(waz) if waz else float('nan')):>8.4f} "
                      f"{(sum(wro)/len(wro) if wro else float('nan')):>8.4f} "
                      f"| {sum(c['peso_distinto'] for c in C):>8} "
                      f"{sum(c['sp_discrepa'] for c in C):>5}")
        print()
    print("PEOR delta con U3'' dinamica, por configuracion:")
    for n, v in peor.items():
        print(f"   {n:>20}: conteo {v[0]:.4f} · PESO {v[1]:.4f}  {v[2]}  "
              f"-> {'SUPERA' if v[1] > DELTA_REAL else 'no supera'} delta_real {DELTA_REAL}")
    print()

    print("(2) DERIVA del retarget: ¿es Poisson sin atacante, como supone el empalme?")
    print("    `s_nota` = γ·√(H/(W²·λ_azul)) sobre el horizonte simulado H (la formula de")
    print("    dag-poas-empalme-peso.md §2). `sd(ln w)` es lo MEDIDO.")
    print(f"{'configuracion':>20} {'pol':>11} {'ret':>4} {'alpha':>6} | {'E[ln w]':>9} "
          f"{'sd(ln w)':>9} {'s_nota':>8} | {'w atac':>8} {'w hon':>8} {'razon a/h':>10} "
          f"| {'deriva cadena':>13}")
    for nombre, wcfg in CFGS:
        s_nota = (wcfg.gamma * math.sqrt(HOR / (wcfg.W ** 2 * LAM_AZUL))
                  if wcfg.W else 0.0)
        for pol, ret in (("tips", 0.0), (("retro", 8), 0.0), ("tips", 40.0)):
            for a in (0.0, 0.10, 0.25, 0.40):
                rs = [deriva(a, s, wcfg, pol, ret) for s in sems]
                mu = sum(r[0] for r in rs) / len(rs)
                sd = sum(r[1] for r in rs) / len(rs)
                wa = sum(r[2] for r in rs) / len(rs)
                wh = sum(r[3] for r in rs) / len(rs)
                dv = sum(r[4] for r in rs) / len(rs)
                print(f"{nombre:>20} {str(pol):>11} {ret:>4.0f} {a:>6.2f} | {mu:>+9.4f} "
                      f"{sd:>9.4f} {s_nota:>8.4f} | {wa:>8.4f} {wh:>8.4f} "
                      f"{(wa/wh if wh else float('nan')):>10.4f} | {dv:>+13.4f}")
        print()
