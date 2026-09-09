#!/usr/bin/env python3
"""
D · Lo que CUESTA cada `k`. Cinco costes, cada uno con su fuente:

 1. `max_block_parents` y `mergeset_size_limit` de R-FIN-12. FUENTE PRIMARIA, leida hoy:
    `/home/katana/zeo/fuentes/rusty-kaspa/consensus/core/src/config/bps.rs`
      :56-72  max_block_parents  = k/2 (division entera), suelo 10, TECHO 16
      :74-85  mergeset_size_limit = 2*k, SUELO 180, techo 512
    CORRECCION AL ENCARGO: el encargo dice `mergeset_size_limit = 6k` y `max_block_parents = k/2`.
    `6k` solo es cierto EN k = 30 (6*30 = 180 = el SUELO); la formula del codigo es `2k` con suelo
    180, asi que el limite NO se mueve hasta k = 90. Y `k/2` esta TOPADO en 16 desde k = 32.
 2. Bytes de cabecera y GB/ano, con el numero de padres **medido** en C.1 (no supuesto):
    cabecera = 555 B + 32 B por padre (`dag-poas-ancla-de-orden.md`:424 -> 683 B con 4 padres).
 3. `F_carrera` con `delta = 0` (modelo (i) de 10b B.2): `k` entra solo por la ventaja 3k del
    Lema 10 (`phantom-ghostdag.txt` L1200-1206), y la ALARGA.
 4. Coste de coloreado por bloque. Cota con fuente + medida:
    cota  — `check_blue_candidate` (protocol.rs:246-283) evalua a lo sumo `mergeset_size_limit`
            candidatos, y por candidato `check_blue_candidate_with_chain_block`
            (protocol.rs:169-225) llama a `blue_anticone_size` una vez por peer que cuenta y
            devuelve Red en cuanto `candidate_blue_anticone_size > k` (:205-213): a lo sumo
            `k+1` llamadas por candidato. Cota superior: **L*(k+1) con L = mergeset_size_limit**,
            es decir O(k^2) solo si L crece con k — y aqui L esta clavado en 180 hasta k = 90,
            luego el crecimiento es LINEAL en k en todo el rango util.
    medida — contadores de `r11a_lib.DAGContado` (C.1): llamadas reales por bloque.
 5. Reversion a 600 s y tiempo de confirmacion a 1e-10, con `delta = 0` y con `delta_real(k)`
    (`dag-poas-delta-real.md` §1). `k` grande = mas ventaja inicial 3k = peor.

CRITERIO ALPHA: las tablas 3 y 5 barren alpha; alpha = 0 da 0 / sin riesgo.
"""
import json
import os
import sys
import time

import numpy as np
from scipy.optimize import brentq

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import r11a_lib as R                                            # noqa: E402
import r10b_lib as L                                            # noqa: E402
import r9a_a3_frontera as A                                     # noqa: E402

AQUI = os.path.dirname(os.path.abspath(__file__))
SEG_ANO = 365 * 24 * 3600
D_DIS = 4.0


def delta_real(k, D=D_DIS, lam=1.0):
    """dag-poas-delta-real.md §1: lambda_real = k*lam/(k-2*D*lam), delta = 2D*lr/(k+2D*lr)."""
    lr = k * lam / (k - 2 * D * lam)
    return 2 * D * lr / (k + 2 * D * lr), lr


def t_confirmacion(alpha, k, d0, lam=1.0, obj=1e-10):
    """Tiempo (s) tras el cual la reversion de UNA transaccion cae por debajo de `obj`,
    con la ventaja inicial 3k del Lema 10. NO es la union por epocas: es una transaccion."""
    g = lambda t: np.log10(max(A.prev(alpha, lam, t, 3 * k, 1 - d0), 1e-320)) - np.log10(obj)
    if g(2e5) > 0:
        return float("nan")
    if g(10.0) < 0:
        return 10.0
    return brentq(g, 10.0, 2e5, xtol=1.0)


if __name__ == "__main__":
    t0 = time.time()
    dat = json.load(open(os.path.join(AQUI, "c1_delta0.json")))
    coste = dat["coste"]
    KS = dat["ks"]
    print("=== D · lo que cuesta cada k ===\n")

    print("--- D.1 · R-FIN-12 con la formula del codigo (bps.rs:56-85), no con `6k` ---")
    print(f"{'k':>5} {'k/2':>5} {'max_block_parents':>18} {'2k':>5} {'mergeset_size_limit':>20} "
          f"{'6k (el del encargo)':>20}")
    for k in KS + [90, 100, 256, 300]:
        print(f"{k:>5} {k//2:>5} {R.max_block_parents(k):>18} {2*k:>5} "
              f"{R.mergeset_size_limit(k):>20} {6*k:>20}")
    print("   -> desde k = 32 el tope de padres esta SATURADO en 16, y el de mergeset en su")
    print("      SUELO de 180 hasta k = 90. Subir k de 30 a 60 cuesta +1 padre y 0 de mergeset.\n")

    print("--- D.2 · bytes de cabecera y GB/ano, con los padres MEDIDOS en C.1 ---")
    print("    cabecera = 555 B + 32 B/padre (ancla-de-orden.md:424: 683 B con 4 padres)")
    print(f"{'lambda':>7} {'Delta':>6} {'k':>4} {'padres medidos':>15} {'cabecera (B)':>13} "
          f"{'GB/ano':>9} {'vs k=30':>9}")
    for lam in (1.0, 0.5):
        for D in (4.0, 8.0, 16.0, 20.0):
            base = None
            for k in KS:
                pa = coste[f"{lam}|{k}|{D}"]["padres"]
                B = R.BYTES_BASE + R.BYTES_PADRE * pa
                gb = SEG_ANO * lam * B / 1e9
                if base is None:
                    base = gb
                print(f"{lam:>7.2f} {D:>6.0f} {k:>4} {pa:>15.2f} {B:>13.1f} {gb:>9.2f} "
                      f"{gb/base-1:>+8.2%}")
            print()

    print("--- D.3 · F_carrera con delta = 0 (modelo (i) de 10b B.2): k la ALARGA ---")
    print(f"    I = {R.I_DIS:.0f} s (diseno) y I = 851 s (la de 10b, para comparar filas)")
    print(f"{'k':>5} {'3k':>5} | " + " ".join(f"{'a=%.2f' % a:>10}" for a in
                                             (0.10, 0.25, 0.33, 0.35, 0.40)) +
          f" | {'33 % I=851':>11}")
    for k in KS:
        fila = [R.f_carrera_con(0.0, k, alpha=a, I=R.I_DIS) for a in (0.10, 0.25, 0.33, 0.35, 0.40)]
        L.set_ventaja(3 * k)
        f851 = L.f_carrera(0.33, 1.0, lam=1.0, I=851.0)
        print(f"{k:>5} {3*k:>5} | " + " ".join(f"{v:>10.0f}" for v in fila) +
              f" | {f851:>11.0f}")
    print("    (alpha = 0: F_carrera = 0 s por construccion — no hay carrera)\n")

    print("--- D.4 · coste de coloreado por bloque: cota (bps.rs + protocol.rs) y MEDIDA ---")
    print(f"{'Delta':>6} {'k':>4} | {'cota L*(k+1)':>13} | {'cand/blq':>9} {'cadena/blq':>11} "
          f"{'blue_ant/blq':>13} {'vs k=30':>9} {'mergeset':>9}")
    for D in (4.0, 12.0, 16.0, 20.0, 32.0):
        base = None
        for k in KS:
            c = coste[f"1.0|{k}|{D}"]
            bas = c["n_bas"] / c["n_blk"]
            if base is None:
                base = bas
            print(f"{D:>6.0f} {k:>4} | {R.mergeset_size_limit(k)*(k+1):>13} | "
                  f"{c['n_cand']/c['n_blk']:>9.2f} {c['n_chain']/c['n_blk']:>11.2f} "
                  f"{bas:>13.2f} {bas/base-1:>+8.2%} {c['mergeset']:>9.2f}")
        print()
    print("    La cota crece como k^2 SOLO si L = mergeset_size_limit crece con k; con el suelo")
    print("    de 180 de bps.rs:77-79, L es constante hasta k = 90 y la cota es LINEAL en k.")
    print("    Lo medido crece menos que la cota y solo donde hay anticono que colorear.\n")

    print("--- D.5 · reversion a 600 s y tiempo de confirmacion a 1e-10 (alpha = 0,33) ---")
    print(f"{'k':>5} {'delta_real(k)':>14} {'lam_real':>9} | {'rev 600 s (d=0)':>16} "
          f"{'rev 600 s (d_real)':>19} | {'t_conf d=0':>12} {'t_conf d_real':>14}")
    for k in KS:
        dr, lr = delta_real(k)
        p0 = A.prev(0.25, 1.0, 600, 3 * k, 1.0)
        pr = A.prev(0.25, lr, 600, 3 * k, 1 - dr)
        t0c = t_confirmacion(0.33, k, 0.0)
        trc = t_confirmacion(0.33, k, dr, lam=lr)
        print(f"{k:>5} {dr:>14.4f} {lr:>9.3f} | {p0:>16.3e} {pr:>19.3e} | "
              f"{t0c:>10.0f} s {trc:>12.0f} s")
    print("\n--- CRITERIO ALPHA en D.5 (delta = 0, k = 30 vs k = 60) ---")
    print(f"{'alpha':>6} | {'rev 600 s k=30':>15} {'rev 600 s k=60':>15} | "
          f"{'t_conf k=30':>12} {'t_conf k=60':>12}")
    for a in (0.0, 0.10, 0.25, 0.33, 0.40):
        p30 = A.prev(a, 1.0, 600, 90, 1.0)
        p60 = A.prev(a, 1.0, 600, 180, 1.0)
        t30 = t_confirmacion(a, 30, 0.0) if a > 0 else 0.0
        t60 = t_confirmacion(a, 60, 0.0) if a > 0 else 0.0
        print(f"{a:>6.2f} | {p30:>15.3e} {p60:>15.3e} | {t30:>10.0f} s {t60:>10.0f} s")
    print(f"\n[{time.time()-t0:.0f} s]")
