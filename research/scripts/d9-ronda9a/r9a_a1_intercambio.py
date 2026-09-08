#!/usr/bin/env python3
"""
r9a_a1_intercambio.py — LINEA 1. La cota de intercambio, medida.

PREGUNTA: existe alguna maniobra del atacante con MAS DE UN bloque honesto vuelto rojo por
bloque del atacante publicado (o por bloque del atacante que acaba AZUL)? Si la respuesta es
no, el blue_work de la cadena publica crece a >= (1-alpha)*lambda para toda estrategia, y el
`delta` del Lema 9 NO se resta del denominador de la carrera.

Magnitudes (ventana [60, HOR-60], contabilidad de r9a_lib.contabilidad):
    H      honestos creados          R      de esos, ROJOS en la vista publica final
    Apub   bloques del atacante PUBLICADOS   Ablue  de esos, AZULES en la vista final
    Wpub = (H-R)+Ablue               tasa_Wpub / tasa_H  -> si es >= 1 la conservacion se cumple

Familia barrida (todas PUBLICAN; alpha_f = 0, todo el presupuesto a enrojecer):
    modo 'parasito' | 'cadena' | 'abanico'  x  J in {16,31,48,64,96}  x  d_fork in {1,2}
    + dos cadenas parasitas alternas (MundoDosParasitas)
    + parasita con 3 copias del mismo billete (MundoParasitaCopias, U3''-dynamic)

REGLA 1 (criterio alpha): fila alpha = 0.
REGLA 2 (cobertura): n_raf > 0 en toda fila con alpha > 0, si no la fila no dice nada.
REGLA 4 (control positivo): alpha = 0,55 y 0,70 — ahi la cadena privada pura SI gana y
    R/Ablue debe DISPARARSE por encima de 1: demuestra que el instrumento ve lo que busca.
REGLA 3: 12 semillas literales.
"""
import itertools
import sys
import time
from multiprocessing import Pool

sys.path.insert(0, "/home/katana/zeo/ZEROX/research/scripts/d9-ronda9a")
from r9a_lib import (MundoL9, MundoDosParasitas, MundoParasitaCopias,  # noqa: E402
                     contabilidad, K, DELTA)

SEMS = list(range(1, 13))
ALPHAS = [0.00, 0.10, 0.25, 0.33, 0.35, 0.40, 0.45, 0.55, 0.70]
JS = [16, 31, 48, 64, 96]
HOR = 1800.0


def una(args):
    alpha, sem, fam = args
    tipo = fam[0]
    if tipo == "l9":
        _, modo, J, d_fork = fam
        m = MundoL9(alpha, HOR, sem, k=K, mp=15)
        d, tip, llega = m.corre_l9(J=J, d_fork=d_fork, giveup=None, modo=modo)
        raf = m.n_rafagas
    elif tipo == "2p":
        _, J = fam
        m = MundoDosParasitas(alpha, HOR, sem, k=K, mp=15)
        d, tip, llega = m.corre_2p(J=J)
        raf = m.n_rafagas
    elif tipo == "cop":
        _, J, cop = fam
        m = MundoParasitaCopias(alpha, HOR, sem, k=K, mp=15)
        d, tip, llega = m.corre_cop(J=J, copias=cop)
        raf = m.n_rafagas
    c = contabilidad(d, tip, llega, 60.0, HOR - 60.0)
    c["raf"] = raf
    return (alpha, fam, c)


def agrega(rs):
    n = len(rs)
    out = {}
    for kk in ("H", "R", "Apub", "Ablue", "Wpub", "raf"):
        out[kk] = sum(r[kk] for r in rs) / n
    out["delta"] = out["R"] / out["H"] if out["H"] else 0.0
    out["R_por_Apub"] = out["R"] / out["Apub"] if out["Apub"] else 0.0
    out["R_por_Ablue"] = out["R"] / out["Ablue"] if out["Ablue"] else 0.0
    out["Wpub_sobre_H"] = out["Wpub"] / out["H"] if out["H"] else 0.0
    return out


if __name__ == "__main__":
    fams = []
    for modo, J, df in itertools.product(("parasito", "cadena", "abanico"), JS, (1, 2)):
        fams.append(("l9", modo, J, df))
    for J in JS:
        fams.append(("2p", J))
    for J in (31, 48):
        fams.append(("cop", J, 3))

    tareas = [(a, s, f) for a in ALPHAS for f in fams for s in SEMS]
    print(f"=== A1 · cota de intercambio: rojos honestos por bloque del atacante ===")
    print(f"k={K}, lambda=1, Delta={DELTA}, mp=15, u3=dynamic, horizonte {HOR:.0f} s, "
          f"ventana [60,{HOR-60:.0f}] s, {len(SEMS)} semillas, {len(fams)} maniobras, "
          f"{len(tareas)} corridas.")
    t0 = time.time()
    with Pool(24) as p:
        res = p.map(una, tareas, chunksize=4)
    print(f"[{time.time()-t0:.0f} s de simulacion]\n")

    por = {}
    for a, f, c in res:
        por.setdefault((a, f), []).append(c)
    ag = {kf: agrega(v) for kf, v in por.items()}

    print("--- MAXIMO sobre la familia, por alpha (el atacante elige su mejor maniobra) ---")
    print(f"{'alpha':>6} | {'max R/Apub':>10} {'maniobra':>26} | {'max R/Ablue':>11} "
          f"{'maniobra':>26} | {'min Wpub/H':>10} {'maniobra':>26} | {'raf tot':>8}")
    resumen = {}
    for a in ALPHAS:
        cand = [(f, ag[(a, f)]) for f in fams]
        conraf = [(f, c) for f, c in cand if c["raf"] > 0] or cand
        b1 = max(conraf, key=lambda x: x[1]["R_por_Apub"])
        b2 = max(conraf, key=lambda x: x[1]["R_por_Ablue"])
        b3 = min(conraf, key=lambda x: x[1]["Wpub_sobre_H"])
        raft = sum(c["raf"] for _, c in cand)
        resumen[a] = (b1, b2, b3)
        print(f"{a:>6.2f} | {b1[1]['R_por_Apub']:>10.3f} {str(b1[0]):>26} | "
              f"{b2[1]['R_por_Ablue']:>11.3f} {str(b2[0]):>26} | "
              f"{b3[1]['Wpub_sobre_H']:>10.4f} {str(b3[0]):>26} | {raft:>8.0f}")

    print("\n--- detalle de la mejor maniobra por alpha (la que maximiza R/Ablue) ---")
    print(f"{'alpha':>6} {'maniobra':>26} | {'H':>7} {'R':>7} {'Apub':>7} {'Ablue':>7} "
          f"{'Wpub':>7} | {'delta':>7} {'R/Apub':>7} {'R/Ablue':>8} {'Wpub/H':>7} {'raf':>5}")
    for a in ALPHAS:
        f, c = resumen[a][1]
        print(f"{a:>6.2f} {str(f):>26} | {c['H']:>7.0f} {c['R']:>7.0f} {c['Apub']:>7.0f} "
              f"{c['Ablue']:>7.0f} {c['Wpub']:>7.0f} | {c['delta']:>7.4f} "
              f"{c['R_por_Apub']:>7.3f} {c['R_por_Ablue']:>8.3f} {c['Wpub_sobre_H']:>7.4f} "
              f"{c['raf']:>5.1f}")

    print("\n--- la maniobra parasita de D8 (modo=parasito, d_fork=1), fila a fila ---")
    print(f"{'alpha':>6} {'J':>4} | {'delta (D8)':>10} {'R/Apub':>7} {'R/Ablue':>8} "
          f"{'tasa Wpub':>10} {'(1-a)lam':>9} {'Wpub/H':>7} {'raf':>5}")
    for a in ALPHAS:
        cand = [(J, ag[(a, ("l9", "parasito", J, 1))]) for J in JS]
        conraf = [(J, c) for J, c in cand if c["raf"] > 0] or cand
        J, c = max(conraf, key=lambda x: x[1]["delta"])
        print(f"{a:>6.2f} {J:>4} | {c['delta']:>10.4f} {c['R_por_Apub']:>7.3f} "
              f"{c['R_por_Ablue']:>8.3f} {c['Wpub']/(HOR-120):>10.4f} {1-a:>9.4f} "
              f"{c['Wpub_sobre_H']:>7.4f} {c['raf']:>5.1f}")

    print("\nLECTURA: si max R/Ablue <= 1 y min Wpub/H >= 1 para todo alpha < 0,5, la "
          "conservacion se cumple\ny el denominador de la carrera es (1-alpha)*lambda, no "
          "(1-alpha)(1-delta)*lambda.")
