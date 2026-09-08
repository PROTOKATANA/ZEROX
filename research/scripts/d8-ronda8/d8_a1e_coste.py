#!/usr/bin/env python3
"""
d8_a1e_coste.py — A1 · ¿CUANTO LE CUESTA al atacante la maniobra parasita?

Es la pregunta que decide si el ataque es teorico o alquilable. En la maniobra parasita los
bloques del atacante NO se tiran: se publican y forman la cadena ganadora, luego **cobran su
coinbase**. Si la perdida de ingreso es pequena, un sobornador puede ALQUILAR el `alpha` que
hace falta (A5: los ganadores se conocen `L = F = 5,3 h` antes) en vez de comprarlo, y el
umbral de 35-37 % deja de ser una barrera de capital.

Se mide, con la misma maniobra y las mismas semillas que A1b:
  · `ing_a`  = fraccion de los bloques del ATACANTE que acaban AZULES en la vista honesta
               final (= su ingreso relativo). Sin ataque valdria ~1.
  · `ing_h`  = lo mismo para los honestos (= 1 - delta).
  · `ratio`  = ing_a / ing_h: si es > 1, la maniobra es RENTABLE por si sola (el atacante
               gana cuota de ingreso), no solo dañina.
  · `perdidos` = bloques del atacante retenidos y nunca publicados al terminar.

Criterio alpha (regla 1): fila alpha = 0 -> el atacante no tiene bloques, `n_a = 0`, la fila
se declara vacia. Capacidad (regla 4): `ing_h` debe reproducir `1 - delta` de A1b.
"""
import sys
import time

sys.path.insert(0, "/home/katana/zeo/ZEROX/research/scripts/d8-ronda8")
from d8_lib import MundoL9, DELTA                                        # noqa: E402

K, MP = 30, 15
SEMS = list(range(1, 13))
ALPHAS = [0.0, 0.10, 0.25, 0.30, 0.33, 0.35, 0.37, 0.40]
HOR = 1800.0
T0, T1 = 60.0, HOR - 60.0
JS = {0.0: 16, 0.10: 16, 0.25: 16, 0.30: 31, 0.33: 31, 0.35: 31, 0.37: 48, 0.40: 48}


def una(alpha, sem, J):
    m = MundoL9(alpha, HOR, sem, k=K, mp=MP)
    d, tip, llega = m.corre_l9(J=J, d_fork=1, giveup=None, modo="parasito")
    az = d.blueset(tip)
    ha = [b for b, x in d.B.items() if x.creator == "h" and T0 < x.t <= T1]
    aa = [b for b, x in d.B.items() if x.creator == "a" and T0 < x.t <= T1]
    pub = set(llega)
    ih = sum(1 for b in ha if b in az) / len(ha) if ha else None
    ia = sum(1 for b in aa if b in az) / len(aa) if aa else None
    perd = sum(1 for b in aa if b not in pub)
    return ih, ia, len(ha), len(aa), perd


if __name__ == "__main__":
    print("=== A1e · coste real de la maniobra parasita para el atacante ===")
    print(f"k={K}, mp={MP}, lambda=1, Delta={DELTA}, horizonte {HOR:.0f} s, "
          f"ventana [{T0:.0f}, {T1:.0f}] s, {len(SEMS)} semillas, modo parasito.\n")
    t0 = time.time()
    print(f"{'alpha':>6} {'J':>4} | {'ing_h (=1-delta)':>17} {'ing_a':>8} {'ratio a/h':>10} | "
          f"{'n_h':>6} {'n_a':>6} {'perdidos':>9} {'% perdidos':>11}")
    for alpha in ALPHAS:
        J = JS[alpha]
        ihs, ias, nh, na, pe = [], [], 0, 0, 0
        for sem in SEMS:
            ih, ia, h, a, p = una(alpha, sem, J)
            if ih is not None:
                ihs.append(ih)
            if ia is not None:
                ias.append(ia)
            nh += h; na += a; pe += p
        if not ias:
            print(f"{alpha:>6.2f} {J:>4} | {sum(ihs)/len(ihs):>17.4f} "
                  f"{'(n_a = 0)':>8} {'-':>10} | {nh:>6} {na:>6} {pe:>9} {'-':>11}")
            continue
        ih = sum(ihs) / len(ihs)
        ia = sum(ias) / len(ias)
        print(f"{alpha:>6.2f} {J:>4} | {ih:>17.4f} {ia:>8.4f} {ia/ih:>10.3f} | "
              f"{nh:>6} {na:>6} {pe:>9} {100*pe/max(na,1):>11.2f}")
    print("\n`ratio > 1` = la maniobra AUMENTA la cuota de ingreso del atacante: no hay coste")
    print("de oportunidad que la disuada, y el `alpha` necesario puede ALQUILARSE (A5).")
    print(f"\n[{time.time()-t0:.0f} s]")
