#!/usr/bin/env python3
"""
r8f_a2_mecanismo.py — PARTE A. POR QUE satura `m`, y la COTA ANALITICA.

A1 mide que `m` deja de crecer en la profundidad de `retro` (D>=32) y en la ventana
(W>=60 s) con cientos de estrategias NUEVAS ejecutandose y APORTANDO CERO. Aqui se
comprueba el mecanismo que lo explica y se contrasta con la cota analitica.

MECANISMO PROPUESTO — "inercia por profundidad":
  Un bloque `B` con `sp(B) = C_{h-d}` tiene en su anticono TODOS los azules que la cadena
  acumulo en esas `d` posiciones. `check_blue_candidate` (protocol.rs:246-283) lo tine de
  ROJO en cuanto `blue_anticone_size(B) > k`. Y "cadena seleccionada ⊆ azules": un rojo
  NO puede ser bloque de cadena, luego NO puede ser ancla. Por tanto la profundidad util
  esta acotada por
        blue_score(C_h) − blue_score(C_{h−d})  >  k = 30      =>  B inerte
  y con incremento medio E[inc] = lambda_azul/lambda_cadena, D* ≈ k/E[inc].

COTA ANALITICA DEL MENU (Lema B1 + inercia):
  (i)  Lema B1: blue_score(ancla) ∈ [T, T+k]   (DEMOSTRADO, ver informe)
  (ii) todo candidato es azul en la cadena final => su blue_score dista <= k del de la
       cadena en el momento en que se fusiona
  (iii) con lambda_azul estabilizada por el retarget, los candidatos se crean en una
       ventana de tiempo real de ancho <= 2k/lambda_azul
  => m <= 1 + lambda * 2k/lambda_azul.  Con lambda=1, k=30, lambda_azul medida: ~62.
  Aqui se MIDE la ventana temporal real del menu para contrastar (iii).

Criterio alpha: alpha=0 => menu 1, ventana 0, y ningun bloque del atacante (no los hay).
"""
import sys
import time

from r8f_lib import Mundo, perfil, ancla_bs_T, pols_hasta, idx_ventana, K, MP, BANDA, HOR

P = 30
SEMS = list(range(1, 13))


# ---------------------------------------------------------------------------------
# (1) INERCIA POR PROFUNDIDAD
# ---------------------------------------------------------------------------------
def inercia(alpha, semilla, D, W=30.0):
    """Aplica `retro D` a TODOS los bloques del atacante de la ventana y clasifica su
    destino en la vista honesta final."""
    mundo = Mundo(alpha, HOR, semilla, k=K, mp=MP, u3_mode="dynamic")
    d0, tip0 = mundo.corre({}, copias=0)
    ch0 = d0.selected_chain(tip0)
    if P >= len(ch0):
        return None
    tP = d0.B[ch0[P]].t
    idx = idx_ventana(mundo, tP, W)
    if not idx:
        return None
    pol = "sp" if D == 0 else ("retro", D)
    d, tip = mundo.corre({i: (0.0, pol) for i in idx}, copias=0)
    cad = set(d.selected_chain(tip))
    azules = d.blueset(tip)
    n = ncad = naz = 0
    gap = 0.0
    for i in idx:
        bid = f"b{i}"
        if bid not in d.gd:
            continue
        n += 1
        if bid in cad:
            ncad += 1
        if bid in azules:
            naz += 1
        # salto de blue_score que su sp deja atras respecto de la punta del momento
        sp = d.gd[bid].sp
        gap += d.gd[tip].blue_score - d.gd[sp].blue_score
    if n == 0:
        return None
    return n, ncad / n, naz / n, gap / n


# ---------------------------------------------------------------------------------
# (2) VENTANA TEMPORAL DEL MENU + calidad de la cota
# ---------------------------------------------------------------------------------
def ventana_menu(alpha, semilla, D=32, W=60.0):
    """Familia SATURADA (D=32, W=60, sin copias). Para cada umbral T recoge los BLOQUES
    candidatos a ancla y devuelve: |menu|, ancho temporal, exceso blue_score(ancla)-T,
    y el numero de bloques del DAG que caen en la ventana analitica."""
    mundo = Mundo(alpha, HOR, semilla, k=K, mp=MP, u3_mode="dynamic")
    d0, tip0 = mundo.corre({}, copias=0)
    ch0 = d0.selected_chain(tip0)
    if P >= len(ch0):
        return None
    tP = d0.B[ch0[P]].t
    T0 = d0.gd[ch0[P]].blue_score
    Ts = list(range(T0 - BANDA, T0 + BANDA + 1))
    idx = idx_ventana(mundo, tP, W)
    pols = pols_hasta(D)
    ests = [{}]
    for pol in pols:
        ests.append({i: (0.0, pol) for i in idx})
        for i in idx:
            ests.append({i: (0.0, pol)})
    cand = {T: {} for T in Ts}      # T -> {seed: (t_creacion, exceso)}
    for e in ests:
        d, tip = mundo.corre(e, copias=0)
        for b in d.selected_chain(tip):
            bs = d.gd[b].blue_score
            for T in Ts:
                if T not in cand:
                    continue
            # solo el primero que cruza cada T
        pf = perfil(d, tip)
        for T in Ts:
            for bs, sl, sd, b, bw in pf:
                if bs >= T:
                    cand[T].setdefault(sd, (d.B[b].t, bs - T))
                    break
    ms, anchos, excesos = [], [], []
    for T in Ts:
        c = cand[T]
        if not c:
            continue
        ms.append(len(c))
        ts = [v[0] for v in c.values()]
        anchos.append(max(ts) - min(ts))
        excesos.append(max(v[1] for v in c.values()))
    # cota analitica: bloques del DAG base creados en una ventana de 2k/lambda_azul
    lam_azul = d0.gd[tip0].blue_score / max(d0.B[tip0].t, 1e-9)
    ancho_cota = 2.0 * K / lam_azul
    nblo = sum(1 for b in d0.B if abs(d0.B[b].t - tP) <= ancho_cota / 2)
    return (sum(ms) / len(ms), max(ms), sum(anchos) / len(anchos), max(anchos),
            max(excesos), lam_azul, ancho_cota, nblo)


if __name__ == "__main__":
    cual = sys.argv[1] if len(sys.argv) > 1 else "inercia"
    t0 = time.time()
    if cual == "inercia":
        print("=== A2(1) · INERCIA POR PROFUNDIDAD: destino de los bloques `retro d` ===")
        print(f"k={K}, mp={MP}, horizonte {HOR:.0f} s, 12 semillas, W=30 s, u3_mode=dynamic.")
        print("`retro d` aplicado a TODOS los bloques del atacante de la ventana.")
        print("Prediccion: el bloque es ROJO —y por tanto NO puede ser ancla— en cuanto")
        print("el salto de blue_score que deja atras supera k=30.\n")
        print(f"{'d':>5} {'alpha':>6} | {'n':>5} {'%en cadena':>11} {'%azul':>8} "
              f"{'salto medio de blue_score':>26} {'>k?':>5}")
        for alpha in (0.0, 0.10, 0.25, 0.40):
            for D in (0, 1, 2, 4, 8, 16, 32, 64, 128):
                rs = [inercia(alpha, s, D) for s in SEMS]
                rs = [r for r in rs if r]
                if not rs:
                    print(f"{D:>5} {alpha:>6.2f} | sin datos"); continue
                n = sum(r[0] for r in rs)
                pc = sum(r[1] for r in rs) / len(rs)
                pa = sum(r[2] for r in rs) / len(rs)
                gp = sum(r[3] for r in rs) / len(rs)
                print(f"{D:>5} {alpha:>6.2f} | {n:>5} {100*pc:>10.1f}% {100*pa:>7.1f}% "
                      f"{gp:>26.1f} {'SI' if gp > K else 'no':>5}")
            print()
    else:
        print("=== A2(2) · VENTANA TEMPORAL DEL MENU y calidad de la cota analitica ===")
        print(f"Familia SATURADA (D=32, W=60 s, sin copias), 12 semillas, 21 umbrales.\n")
        print(f"{'alpha':>6} | {'m medio':>8} {'m max':>6} | {'ancho medio (s)':>16} "
              f"{'ancho max (s)':>14} | {'max bs(ancla)-T':>16} | {'lam_azul':>9} "
              f"{'cota 2k/l_az':>13} {'#bloques':>9}")
        for alpha in (0.0, 0.10, 0.25, 0.40):
            rs = [ventana_menu(alpha, s) for s in SEMS]
            rs = [r for r in rs if r]
            if not rs:
                print(f"{alpha:>6.2f} sin datos"); continue
            print(f"{alpha:>6.2f} | {sum(r[0] for r in rs)/len(rs):>8.3f} "
                  f"{max(r[1] for r in rs):>6} | {sum(r[2] for r in rs)/len(rs):>16.2f} "
                  f"{max(r[3] for r in rs):>14.2f} | {max(r[4] for r in rs):>16} | "
                  f"{sum(r[5] for r in rs)/len(rs):>9.4f} "
                  f"{sum(r[6] for r in rs)/len(rs):>13.1f} "
                  f"{sum(r[7] for r in rs)/len(rs):>9.1f}")
    print(f"\n[{time.time()-t0:.0f} s]")
