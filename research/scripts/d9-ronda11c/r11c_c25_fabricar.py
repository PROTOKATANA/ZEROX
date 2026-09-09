#!/usr/bin/env python3
"""
r11c_c25_fabricar.py — PUNTOS C.2 y C.5 · ¿que magnitud fabrica el atacante a coste cero?

C.2 · EL CONTADOR DE SALTOS DE D9-c. El ancla por posicion de cadena cayo porque `pos` es
      un CONTADOR que el atacante mueve gratis. Aqui se comprueba lo analogo para H1:
      (a) que el `slot` de un bloque del atacante NO depende de su estrategia (es
          `floor(t_creacion)`, y `t_creacion` lo fija el calendario de Poisson = el PoT);
      (b) cuantos SLOTS distintos puede hacer ocupar al ancla (menu de slots), que es la
          unica palanca que H1 le deja: retener a los ocupantes del slot `T_j` para
          empujar `s*` hacia adelante. Es unidireccional por construccion.

C.5 · LA MANIOBRA DEL PRIMER REFERENCIADOR contra H3. `publicado(X)` := `slot` del primer
      bloque de la cadena seleccionada que referencia a X = `slot` del SUCESOR DE CADENA de
      X. El atacante retiene X y un sucesor propio Y con `slot(Y) - slot(X) < 45 s`, cuelga
      Y de X ('propio') y publica los dos EN EL MISMO INSTANTE, `T_pub`. Si Y entra en la
      cadena, H3 lee `publicado(X) = slot(Y)` y X pasa el filtro pese a haber estado
      retenido `T_pub - t_X` segundos.
      Se mide: (i) `m` bajo BASE y bajo H3 con y sin la maniobra en la familia;
               (ii) `falsos`: anclas de H3 con retencion REAL >= 45 s (llega[X] - t_X)
                    que pasan el filtro porque su sucesor es del atacante.
      Si `falsos > 0`, H3 lee una magnitud que el atacante fabrica: la leccion de D9-c.

Criterio alpha: fila alpha = 0.
"""
import multiprocessing as mp
import sys
import time

sys.path.insert(0, "/home/katana/zeo/ZEROX/research/scripts/d9-ronda11c")
from r11c_lib import (MundoR11, perfil, anclas, fam_retencion, fam_propio,   # noqa: E402
                      slot_de, S_MAX, S_ANCLA, COB11)

P, BANDA, HOR, W = 30, 10, 260.0, 30.0
SEMS = list(range(1, 13))
ALPHAS = (0.0, 0.10, 0.25, 0.40)
NPROC = 12


def una(args):
    alpha, semilla, con_maniobra = args
    mundo = MundoR11(alpha, HOR, semilla, s_max=S_MAX)
    d0, tip0 = mundo.corre({}, copias=0)
    ch0 = d0.selected_chain(tip0)
    if P >= len(ch0):
        return None
    tP = d0.B[ch0[P]].t
    Ss = [slot_de(tP + u) for u in range(-BANDA, BANDA + 1)]
    ests, idx = fam_retencion(mundo, tP, W)
    n_man = 0
    if con_maniobra:
        e2, _ = fam_propio(mundo, tP, W)
        ests = ests + e2
        n_man = len(e2)
    slots_ev = {}
    viol_slot = 0
    acB = {S: set() for S in Ss}
    acH3 = {S: set() for S in Ss}
    slots_ancla = {S: set() for S in Ss}
    falsos = 0            # ancla H3 con retencion real >= S_ANCLA
    falsos_att = 0        # ... y ademas con sucesor de cadena del ATACANTE
    h3_anclas = 0
    ret_max_h3 = 0.0
    for e in ests:
        d, tip = mundo.corre(e, copias=0)
        llega = mundo.llega
        # (C.2a) invariancia del slot: el bloque del evento i tiene SIEMPRE el mismo slot
        for i, (t, q, *_) in enumerate(mundo.ev):
            bid = f"b{i}"
            if bid in d.B:
                s = slot_de(d.B[bid].t)
                if bid in slots_ev and slots_ev[bid] != s:
                    viol_slot += 1
                slots_ev[bid] = s
        ch = d.selected_chain(tip)
        pos = {b: i for i, b in enumerate(ch)}
        pf = perfil(d, tip)
        for S in Ss:
            a = anclas(pf, S)
            if a["BASE"][0] is not None:
                acB[S].add(a["BASE"][0])
                slots_ancla[S].add(pf[a["BASE"][1]][2])
            if a["H3"][0] is not None:
                acH3[S].add(a["H3"][0])
                h3_anclas += 1
                i = a["H3"][1]
                X = pf[i][1]
                ret = llega.get(X, 0.0) - d.B[X].t
                if ret >= S_ANCLA:
                    falsos += 1
                    ret_max_h3 = max(ret_max_h3, ret)
                    if i + 1 < len(ch) and d.B[ch[i + 1]].creator == "a":
                        falsos_att += 1
    mB = sum(len(acB[S]) for S in Ss) / len(Ss)
    mH = sum(len(acH3[S]) for S in Ss) / len(Ss)
    msl = sum(len(slots_ancla[S]) for S in Ss) / len(Ss)
    return (mB, mH, msl, viol_slot, len(ests), n_man, falsos, falsos_att,
            h3_anclas, ret_max_h3)


if __name__ == "__main__":
    print("=== C.2 / C.5 · el slot no se fabrica; el «primer referenciador» si ===")
    print(f"k=30, mp=15, lambda=1, Delta=4, horizonte {HOR:.0f} s, P={P}, 21 umbrales,")
    print(f"tau = 1 s, S_max = {S_MAX} s, S_ancla = {S_ANCLA} s, semillas 1..12.\n")
    t0 = time.time()
    print(f"{'maniobra':>9} {'alpha':>6} | {'m BASE':>7} {'m H3':>7} "
          f"{'slots del ancla':>16} | {'viol. slot':>10} {'estrat':>7} {'de ellas man.':>14} "
          f"| {'anclas H3':>10} {'falsos':>7} {'con suc. atac.':>14} {'ret. max':>9}")
    for man in (False, True):
        for alpha in ALPHAS:
            with mp.Pool(NPROC) as pool:
                rs = [r for r in pool.map(una, [(alpha, s, man) for s in SEMS]) if r]
            n = len(rs)
            print(f"{str(man):>9} {alpha:>6.2f} | {sum(r[0] for r in rs)/n:>7.3f} "
                  f"{sum(r[1] for r in rs)/n:>7.3f} {sum(r[2] for r in rs)/n:>16.3f} | "
                  f"{sum(r[3] for r in rs):>10} {sum(r[4] for r in rs)/n:>7.1f} "
                  f"{sum(r[5] for r in rs)/n:>14.1f} | {sum(r[8] for r in rs):>10} "
                  f"{sum(r[6] for r in rs):>7} {sum(r[7] for r in rs):>14} "
                  f"{max(r[9] for r in rs):>9.1f}")
        print()
    print(f"cobertura 'propio': ok={COB11['propio_ok']} rechazados={COB11['propio_no']} "
          "(en el proceso principal; el trabajo va en workers)")
    print(f"[{time.time()-t0:.0f} s]")
