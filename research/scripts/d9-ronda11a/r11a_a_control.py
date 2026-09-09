#!/usr/bin/env python3
"""
A · CONTROL POSITIVO (regla 4: reproducir un numero publicado antes de medir nada).

Tres controles, cada uno sobre un instrumento que esta ronda va a usar:

 A.1  `k* = 29` a `D = 4 s`, `lambda = 1`, del punto fijo de `verif_tau_vs_lambda.py`.
      Se comprueba DOS veces: con `kopt` del original (importado) y con la copia
      parametrizada de `r11a_lib.kopt` — si difirieran, la copia estaria mal.
 A.2  la tabla `delta_0(Delta)` de `d9-ronda9a/informe.md` §5.5 (0,0000 / 0,0020 / 0,0828 /
      0,2858 / 0,4428 / 0,5401 / 0,6526 para Delta = 4/8/12/16/20/24/32 s), medida con
      `r11a_lib.mide` (= el instrumento de `r9a_a1b_control.py` con k y lambda parametrizados)
      a k = 30, lambda = 1, alpha = 0, 12 semillas. Controla ademas la subclase `DAGContado`:
      si contar cambiara el resultado, la subclase estaria rota.
 A.3  la tabla de fronteras de 9a §5.5 (46,8784 / 46,8268 / 44,6542 / 38,3337 / 32,3788 %)
      con `r11a_lib.frontera_con` (= `r9a_a3_frontera.prev/union10` con F = 19 080 s,
      I = 4 200 s, ventaja 3k = 90).
"""
import contextlib
import io
import os
import sys
import time
from multiprocessing import Pool

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import r11a_lib as R                                            # noqa: E402

SEMS = list(range(1, 13))
DELTAS = [4.0, 8.0, 12.0, 16.0, 20.0, 24.0, 32.0]
PUB_D0 = {4.0: 0.0000, 8.0: 0.0020, 12.0: 0.0828, 16.0: 0.2858,
          20.0: 0.4428, 24.0: 0.5401, 32.0: 0.6526}      # 9a informe.md §5.5
PUB_FR = {4.0: 0.468784, 8.0: 0.468268, 12.0: 0.446542,
          16.0: 0.383337, 20.0: 0.323788}                # 9a informe.md §5.5

def _frontera_9a(D):
    """La frontera de 9a §5.5 a `Delta = D`: F = 19 080 s, I = 4 200 s, ventaja 3k = 90."""
    return R.frontera_con(PUB_D0[D], 30, F=19080.0, I=4200.0)


if __name__ == "__main__":
    t0 = time.time()
    print("=== A · control positivo ===\n")

    print("--- A.1 · k* del punto fijo a D = 4 s, lambda = 1 ---")
    with contextlib.redirect_stdout(io.StringIO()):
        import verif_tau_vs_lambda as V
    k_o, p_o, d_o, l_o = V.kopt(1.0)
    k_c, p_c, d_c, l_c = R.kopt(1.0, 4.0, 80)
    print(f"   original verif_tau_vs_lambda.kopt(1,0) : k* = {k_o}, delta_real = {d_o:.4f}, "
          f"lambda_real = {l_o:.4f}, reversion 600 s = {p_o:.3e}")
    print(f"   copia    r11a_lib.kopt(1,0, D=4, 80)   : k* = {k_c}, delta_real = {d_c:.4f}, "
          f"lambda_real = {l_c:.4f}, reversion 600 s = {p_c:.3e}")
    ok1 = (k_o == k_c == 29) and abs(p_o - p_c) < 1e-18
    print(f"   esperado k* = 29 (encargo)  ->  {'OK' if ok1 else 'DIFIERE'}")
    pk = {k: V.prev(0.25, k/(k-8.0), 600, 3*k, 1 - 8.0*(k/(k-8.0))/(k + 8.0*(k/(k-8.0))))
          for k in (28, 29, 30, 31)}
    print("   el diseno publica k = 30, no 29. La reversion a 600 s en el entorno del optimo:")
    print("   " + "  ".join(f"k={k}: {v:.4e}" for k, v in pk.items()))
    print(f"   k=30 es {pk[30]/pk[29]-1:+.2%} peor que k=29, y las dos redondean a 4,3e-10, que")
    print("   es la cifra que publica `dag-poas-delta-real.md` L30-33 (dos cifras). El optimo")
    print("   es PLANO: no es un error, es el mismo punto fijo con otro redondeo.\n")

    print("--- A.2 · delta_0(Delta) de 9a §5.5, con el instrumento parametrizado ---")
    tareas = [(D, 30, 1.0, 0.0, s) for D in DELTAS for s in SEMS]
    with Pool(28) as p:
        res = p.map(R.mide, tareas, chunksize=2)
    por = {}
    for r in res:
        por.setdefault(r["delta_red"], []).append(r)
    ok2 = True
    print(f"{'Delta':>6} | {'delta_0 medido':>15} {'publicado 9a':>13} {'|dif|':>8} "
          f"{'H':>7} {'padres':>7}")
    med = {}
    for D in DELTAS:
        v = por[D]
        H = sum(x["H"] for x in v) / len(v)
        # cociente de medias, como r9a_a1b_control.py:78-84 (g['R']/g['H'])
        d0 = (sum(x["R"] for x in v) / len(v)) / H
        pa = sum(x["padres"] for x in v) / len(v)
        med[D] = d0
        dif = abs(d0 - PUB_D0[D])
        ok2 &= dif < 5e-4
        print(f"{D:>6.0f} | {d0:>15.4f} {PUB_D0[D]:>13.4f} {dif:>8.4f} {H:>7.0f} {pa:>7.2f}")
    print(f"   -> {'7/7 OK' if ok2 else 'HAY DIFERENCIAS'}\n")

    print("--- A.3 · fronteras de 9a §5.5 (F = 19 080 s, I = 4 200 s, ventaja 3k = 90) ---")
    ok3 = True
    print(f"{'Delta':>6} {'delta_0':>9} | {'frontera':>10} {'publicada':>10} {'|dif|':>8}")
    with Pool(len(PUB_FR)) as p:
        frs = dict(zip(sorted(PUB_FR), p.map(_frontera_9a, sorted(PUB_FR))))
    for D in sorted(PUB_FR):
        fr = frs[D]
        dif = abs(fr - PUB_FR[D])
        ok3 &= dif < 1e-5
        print(f"{D:>6.0f} {PUB_D0[D]:>9.4f} | {fr:>9.4%} {PUB_FR[D]:>9.4%} {dif:>8.2e}")
    print(f"   -> {'5/5 OK' if ok3 else 'HAY DIFERENCIAS'}")

    print(f"\nCONTROL A: {'LOS TRES PASAN' if (ok1 and ok2 and ok3) else 'REVISAR'}  "
          f"[{time.time()-t0:.0f} s]")
