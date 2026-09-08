#!/usr/bin/env python3
"""
r8d_a3b_optim.py — LINEA A3 (2). ?Se puede EMPUJAR delta_ef por encima de la cota con
U3'' DINAMICA? Barrido de la estrategia de copia y correccion de una ventana sesgada.

CORRECCION DE MI PROPIO ERROR: en `r8d_a3_delta.py` la ventana era [0,20T ; 0,95T] y el
azul se leia en la punta final (T). Un honesto creado en 0,94T puede no estar fusionado
todavia en T y contaba como ROJO sin serlo. Aqui la ventana es [0,20T ; 0,75T], con
0,25T de margen (>60 Delta), y se mide ademas cuantos honestos de la ventana NO estan
en el DAG alcanzable, para verlo.

Barrido: copias en {2,6,14}, profundidad `retro` en {1,2,4,8}, retraso en {0,4,12} s.
Criterio alpha: alpha=0 -> ninguna copia existe -> delta_hon = huerfanos honestos ~0.
"""
import sys
from r8d_lib import Mundo, llega_de, LAMBDA

K, MP = 30, 15
DELTA_NOM, DELTA_REAL = 8 / 38, 0.267


def delta_hon(alpha, semilla, T, u3_mode, copias, pol, retraso):
    m = Mundo(alpha, T, semilla, k=K, mp=MP, u3_mode=u3_mode)
    est = {i: (retraso, pol) for i, (t, q, *_) in enumerate(m.ev) if q == "a"}
    d, tip = m.corre(est, copias=copias)
    t1, t2 = 0.20 * T, 0.75 * T
    azules = d.blueset(tip)
    hon = [h for h in d.B if d.B[h].creator == "h" and t1 < d.B[h].t <= t2]
    hon_azul = sum(1 for h in hon if h in azules)
    esperados = (1 - alpha) * LAMBDA * (t2 - t1)
    # cuantos honestos de la ventana ni siquiera son ANCESTROS de la punta (no fusionados)
    no_fus = sum(1 for h in hon if h != tip and h not in d.anc[tip])
    return 1 - hon_azul / esperados, len(hon), no_fus


if __name__ == "__main__":
    T = float(sys.argv[1]) if len(sys.argv) > 1 else 900.0
    sems = list(range(1, 6))
    print("=== A3(2) · ?se puede superar delta con U3'' DINAMICA? ===")
    print(f"k={K}, mp={MP}, horizonte {T:.0f} s, ventana [0,20T ; 0,75T], 5 semillas.")
    print(f"cota nominal {DELTA_NOM:.4f} · cota real {DELTA_REAL}\n")
    print("(a) referencia: sin copias, y las dos formas de U3 con 14 copias retro1")
    print(f"{'u3':>9} {'cop':>4} {'pol':>10} {'ret':>4} | {'alpha':>5} | {'delta_hon':>10} | {'no fusionados':>14}")
    for u3, cop, pol, ret in (("dynamic", 0, "tips", 0.0), ("dynamic", 14, ("retro", 1), 0.0),
                              ("filter", 14, ("retro", 1), 0.0)):
        for alpha in (0.0, 0.25, 0.40):
            rs = [delta_hon(alpha, s, T, u3, cop, pol, ret) for s in sems]
            dh = sum(r[0] for r in rs) / len(rs)
            nf = sum(r[2] for r in rs) / len(rs)
            print(f"{u3:>9} {cop:>4} {str(pol):>10} {ret:>4.0f} | {alpha:>5.2f} | {dh:>10.4f} | {nf:>14.1f}")
    print()
    print("(b) BARRIDO sobre U3'' dinamica — buscando el maximo de delta_hon")
    print(f"{'cop':>4} {'retro':>6} {'ret':>4} | " +
          " ".join(f"{'a=' + f'{a:.2f}':>9}" for a in (0.10, 0.25, 0.33, 0.40)))
    mejor = (0, None)
    for cop in (2, 6, 14):
        for rt in (1, 2, 8):
            for ret in (0.0, 12.0):
                fila = f"{cop:>4} {rt:>6} {ret:>4.0f} |"
                for alpha in (0.10, 0.25, 0.33, 0.40):
                    rs = [delta_hon(alpha, s, T, "dynamic", cop, ("retro", rt), ret) for s in sems]
                    dh = sum(r[0] for r in rs) / len(rs)
                    fila += f" {dh:>9.4f}"
                    if dh > mejor[0]:
                        mejor = (dh, (cop, rt, ret, alpha))
                print(fila)
    print(f"\nMAXIMO delta_hon con U3'' dinamica: {mejor[0]:.4f} en "
          f"copias={mejor[1][0]}, retro={mejor[1][1]}, retraso={mejor[1][2]}, alpha={mejor[1][3]}")
    print(f"  vs cota nominal {DELTA_NOM:.4f}: "
          f"{'SUPERA' if mejor[0] > DELTA_NOM else 'no la supera'}")
    print(f"  vs cota real    {DELTA_REAL}: "
          f"{'SUPERA' if mejor[0] > DELTA_REAL else 'no la supera'}")
