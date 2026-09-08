#!/usr/bin/env python3
"""
d8_a4b_horizonte.py — A4 (1), version barata y dirigida: ¿CRECE `m` con el horizonte?

`I = 4 200 s` y `F = 5,3 h` salen de `m = 2,548`, medida por D9-f con horizonte 260 s y el
ancla a profundidad P = 30. En regimen el ancla vive a profundidad `F` y las epocas duran
`I`. Como `I ∝ c_m^2` y `F ∝ c_m^2`, si `m` creciera con el horizonte las dos constantes
estarian infradimensionadas. Se mide con la MISMA familia (la literal de D9-f, sin retencion)
a cuatro horizontes, con la profundidad P escalada para que el ancla este en la misma
posicion relativa.

alpha = 0 da m = 1 (valor neutro). Se declara `estrat` (tamano de la familia) para que se vea
que no cambia con el horizonte: si cambiara, la comparacion no seria valida.
"""
import sys
import time

sys.path.insert(0, "/home/katana/zeo/ZEROX/research/scripts/d9-ronda8f")
from r8f_lib import Mundo, perfil, ancla_slot_T, ancla_slot_minbw, slot_de, \
    idx_ventana, K, MP                                                    # noqa: E402

SEMS = list(range(1, 13))
POLS = ["sp", ("retro", 1), ("retro", 2), ("retro", 4), ("retro", 8), ("retro", 16)]
BANDA = 10


def mide(alpha, sem, HOR, P, W=30.0):
    mundo = Mundo(alpha, HOR, sem, k=K, mp=MP, u3_mode="dynamic")
    d0, tip0 = mundo.corre({}, copias=0)
    ch0 = d0.selected_chain(tip0)
    if P >= len(ch0):
        return None
    tP = d0.B[ch0[P]].t
    Ss = [slot_de(tP + u, 1.0) for u in range(-BANDA, BANDA + 1)]
    idx = idx_ventana(mundo, tP, W)
    ests = [{}]
    for pol in POLS:
        ests.append({i: (0.0, pol) for i in idx})
    for i in idx:
        for pol in POLS:
            ests.append({i: (0.0, pol)})
    ac = {S: set() for S in Ss}
    mal = 0
    for e in ests:
        d, tip = mundo.corre(e, copias=14)
        pf = perfil(d, tip, gran=1.0)
        for S in Ss:
            s, i = ancla_slot_T(pf, S)
            s2, i2 = ancla_slot_minbw(pf, S)
            if s is None:
                continue
            if (s, i) != (s2, i2):
                mal += 1
            ac[S].add(s)
    ms = [len(ac[S]) for S in Ss]
    return sum(ms) / len(ms), max(ms), len(ests), mal


if __name__ == "__main__":
    print("=== A4b · ¿crece `m` con el horizonte? (familia FIJA, la literal de D9-f) ===")
    print(f"k={K}, mp={MP}, lambda=1, Delta=4, u3=dynamic, copias=14, {len(SEMS)} semillas, "
          f"21 umbrales, ancla `slot` (gran = 1 s).")
    print("Referencia D9-f (HOR=260, P=30): m = 2,238 / 2,540 / 3,024 a alpha = 0,10/0,25/0,40.\n")
    t0 = time.time()
    print(f"{'HOR':>6} {'P':>5} {'alpha':>6} | {'m medio':>8} {'m max':>6} {'estrat':>7} "
          f"{'equiv!=':>8}")
    for HOR, P in ((260.0, 30), (500.0, 60), (900.0, 110), (1500.0, 190), (2400.0, 300)):
        for alpha in (0.0, 0.25):
            rs = [mide(alpha, s, HOR, P) for s in SEMS]
            rs = [r for r in rs if r]
            if not rs:
                print(f"{HOR:>6.0f} {P:>5} {alpha:>6.2f} | sin datos"); continue
            n = len(rs)
            print(f"{HOR:>6.0f} {P:>5} {alpha:>6.2f} | {sum(x[0] for x in rs)/n:>8.3f} "
                  f"{max(x[1] for x in rs):>6} {sum(x[2] for x in rs)/n:>7.0f} "
                  f"{sum(x[3] for x in rs):>8}")
        print(f"   [{time.time()-t0:.0f} s]")
