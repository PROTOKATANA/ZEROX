#!/usr/bin/env python3
"""
d8_a4_cruce.py — A4 · EL CRUCE DEL ANCLA `slot` EN REGIMEN.

Tres preguntas, tres medidas:

 (1) ¿SUBE `m` con el horizonte?  D9-f midio `m_SLOT = 2,54` con horizonte 260 s y el ancla
     a profundidad P=30. Las constantes en regimen son `I = 4 200 s` y `F = 5,3 h`. Si `m`
     creciera con el horizonte, `I` y `F` (que van como `ln m`) estarian infradimensionadas.
     Se mide `m` con horizonte 260 / 500 / 900 / 1 500 s y profundidad proporcional.

 (2) ¿PUEDE RETENER? El atacante fabrica un bloque con `slot >= T_j` y lo suelta con retraso
     `r`. R-FIN-1a le pone el techo `slot(B) - slot(sp(B)) <= S_max`; se barre `r` hasta
     `S_max = 150 s` y se cuenta cuantas ANCLAS DISTINTAS aparecen (`m`) y cuantas son SUYAS.

 (3) ¿CUANTAS EPOCAS SEGUIDAS CAPTURA? Se recorren umbrales `T_j` consecutivos y se mide la
     racha maxima de epocas en las que el ancla es un bloque del atacante (`creator == 'a'`).
     El steering `g = c_m/sqrt(alpha*lambda*I)` supone epocas INDEPENDIENTES; una racha larga
     no es lo mismo que `m` capturas sueltas.

CAPACIDAD (regla 4): `nA` = anclas que son del atacante. Si con `alpha = 0,40` fuese 0 el
instrumento no podria ver capturas y las rachas no dirian nada. CRITERIO ALPHA: fila alpha=0.
"""
import sys
import time

sys.path.insert(0, "/home/katana/zeo/ZEROX/research/scripts/d9-ronda8f")
from r8f_lib import Mundo, perfil, ancla_slot_T, ancla_slot_minbw, slot_de, \
    idx_ventana, K, MP                                                      # noqa: E402

SEMS = list(range(1, 13))
ALPHAS = [0.0, 0.10, 0.25, 0.33, 0.40]
POLS = ["sp", ("retro", 1), ("retro", 2), ("retro", 4), ("retro", 8), ("retro", 16)]
S_MAX = 150.0
RETRASOS = [0.0, 4.0, 12.0, 40.0, 150.0]           # hasta S_max (R-FIN-1a)


def familia(mundo, tP, W, con_retraso, con_retencion):
    idx = idx_ventana(mundo, tP, W)
    ests = [{}]
    for pol in POLS:
        ests.append({i: (0.0, pol) for i in idx})
    for i in idx:
        for pol in POLS:
            ests.append({i: (0.0, pol)})
    if con_retraso:
        for r in RETRASOS:
            for pol in POLS:
                ests.append({i: (r, pol) for i in idx})
    if con_retencion:
        ests.append({i: (None, "tips") for i in idx})
        for i in idx:
            for pol in POLS:
                for r in (0.0, 12.0, S_MAX):
                    e = {j: (None, "tips") for j in idx}
                    e[i] = (r, pol)
                    ests.append(e)
    return ests, idx


def mide(alpha, sem, HOR, P, banda=10, W=30.0, con_retraso=True, con_retencion=True,
         copias=14):
    mundo = Mundo(alpha, HOR, sem, k=K, mp=MP, u3_mode="dynamic")
    d0, tip0 = mundo.corre({}, copias=0)
    ch0 = d0.selected_chain(tip0)
    if P >= len(ch0):
        return None
    tP = d0.B[ch0[P]].t
    Ss = [slot_de(tP + u, 1.0) for u in range(-banda, banda + 1)]
    ests, idx = familia(mundo, tP, W, con_retraso, con_retencion)
    ac = {S: set() for S in Ss}
    nA = {S: 0 for S in Ss}
    equiv_mal = 0
    for e in ests:
        d, tip = mundo.corre(e, copias=copias)
        pf = perfil(d, tip, gran=1.0)
        for S in Ss:
            s, i = ancla_slot_T(pf, S)
            s2, i2 = ancla_slot_minbw(pf, S)
            if s is None:
                continue
            if (s, i) != (s2, i2):
                equiv_mal += 1
            ac[S].add(s)
            if d.B[pf[i][3]].creator == "a":
                nA[S] += 1
    ms = [len(ac[S]) for S in Ss]
    return sum(ms) / len(ms), max(ms), sum(nA.values()), len(ests), equiv_mal


def racha(alpha, sem, HOR, paso=25, banda_ini=40):
    """(3) Epocas consecutivas: umbrales T_j separados `paso` s. Para cada uno, ¿el ancla de
    la ejecucion SIN ataque es del atacante? Y con la mejor estrategia de la familia corta,
    ¿puede hacerla suya? Devuelve (racha_max_sin, racha_max_con, n_epocas)."""
    mundo = Mundo(alpha, HOR, sem, k=K, mp=MP, u3_mode="dynamic")
    d0, tip0 = mundo.corre({}, copias=0)
    pf0 = perfil(d0, tip0, gran=1.0)
    if len(pf0) < banda_ini + 5:
        return None
    Ss = list(range(banda_ini, int(HOR) - 30, paso))
    # sin ataque dirigido (el atacante emite con 'tips')
    cap0, n = [], 0
    for S in Ss:
        s, i = ancla_slot_T(pf0, S)
        if s is None:
            continue
        n += 1
        cap0.append(d0.B[pf0[i][3]].creator == "a")
    # con ataque dirigido: una estrategia GLOBAL por politica (barata), se toma el max
    mejor = list(cap0)
    for pol in POLS:
        idx = [i for i, (t, q, *_) in enumerate(mundo.ev) if q == "a"]
        d, tip = mundo.corre({i: (0.0, pol) for i in idx}, copias=14)
        pf = perfil(d, tip, gran=1.0)
        cap = []
        for S in Ss:
            s, i = ancla_slot_T(pf, S)
            if s is None:
                continue
            cap.append(d.B[pf[i][3]].creator == "a")
        if len(cap) == len(mejor):
            mejor = [a or b for a, b in zip(mejor, cap)]

    def rmax(v):
        r = m = 0
        for x in v:
            r = r + 1 if x else 0
            m = max(m, r)
        return m
    return rmax(cap0), rmax(mejor), n, sum(cap0), sum(mejor)


if __name__ == "__main__":
    print("=== A4 · el cruce del ancla `slot` en regimen ===")
    print(f"k={K}, mp={MP}, lambda=1, Delta=4, u3=dynamic, copias=14, {len(SEMS)} semillas, "
          f"S_max={S_MAX:.0f} s (R-FIN-1a).\n")
    t0 = time.time()

    print("--- (1) `m` frente al HORIZONTE, familia FIJA (la literal de D9-f, sin "
          "retencion): si `m` no crece con el horizonte, I y F no estan infradimensionadas ---")
    print(f"{'HOR':>6} {'P':>4} {'alpha':>6} | {'m medio':>8} {'m max':>6} {'nA':>6} "
          f"{'estrat':>7} {'equiv!=':>8}")
    for HOR, P in ((260.0, 30), (500.0, 60), (900.0, 110), (1500.0, 190)):
        for alpha in ALPHAS:
            rs = [mide(alpha, s, HOR, P, con_retraso=False, con_retencion=False)
                  for s in SEMS]
            rs = [r for r in rs if r]
            if not rs:
                print(f"{HOR:>6.0f} {P:>4} {alpha:>6.2f} | sin datos"); continue
            n = len(rs)
            print(f"{HOR:>6.0f} {P:>4} {alpha:>6.2f} | {sum(x[0] for x in rs)/n:>8.3f} "
                  f"{max(x[1] for x in rs):>6} {sum(x[2] for x in rs):>6} "
                  f"{sum(x[3] for x in rs)/n:>7.0f} {sum(x[4] for x in rs):>8}")
        print()

    print("--- (2) RETENCION hasta S_max = 150 s: familia completa, horizonte 260 y 500 s ---")
    print(f"{'HOR':>6} {'P':>4} {'alpha':>6} | {'m medio':>8} {'m max':>6} {'nA':>6} "
          f"{'estrat':>7} {'equiv!=':>8}")
    for HOR, P in ((260.0, 30), (500.0, 60)):
        for alpha in ALPHAS:
            rs = [mide(alpha, s, HOR, P) for s in SEMS]
            rs = [r for r in rs if r]
            if not rs:
                print(f"{HOR:>6.0f} {P:>4} {alpha:>6.2f} | sin datos"); continue
            n = len(rs)
            print(f"{HOR:>6.0f} {P:>4} {alpha:>6.2f} | {sum(x[0] for x in rs)/n:>8.3f} "
                  f"{max(x[1] for x in rs):>6} {sum(x[2] for x in rs):>6} "
                  f"{sum(x[3] for x in rs)/n:>7.0f} {sum(x[4] for x in rs):>8}")
        print()

    print("--- (3) rachas de epocas consecutivas capturadas por el atacante ---")
    print(f"{'alpha':>6} | {'racha max sin dirigir':>21} {'racha max dirigida':>19} "
          f"{'capturas/epocas':>16}")
    for alpha in ALPHAS:
        rs = [racha(alpha, s, 1500.0) for s in SEMS]
        rs = [r for r in rs if r]
        if not rs:
            print(f"{alpha:>6.2f} | sin datos"); continue
        print(f"{alpha:>6.2f} | {max(r[0] for r in rs):>21} {max(r[1] for r in rs):>19} "
              f"{sum(r[4] for r in rs):>7}/{sum(r[2] for r in rs):<8}")
    print(f"\n[{time.time()-t0:.0f} s]")
