#!/usr/bin/env python3
"""
d14_control.py — Punto 1: CONTROL POSITIVO con el paper.

Objetivo (dagknight.txt:182-197): lambda=3,75, alpha=0,2, D=0,1/1/2 s, eps=0,05
  -> k = 0/1/4  y  tiempos de confirmacion 1,2/6/12 s.

El paper NO publica ni el pseudocodigo completo de su simulacion (dice que saldra online,
:660-663 y :1064-1065) ni la regla exacta de confirmacion del cliente (seccion 4 solo da
cotas asintoticas, :1007 y :328-352). Aqui se reproduce lo reproducible:

  A · k* sobre el DAG solo-honesto de tasa (1-alpha)*lambda, medido con
      (a) el colorador voraz por bitsets (cota de maximizacion libre, F_k)
      (b) el replay fiel de r8c_gd (GHOSTDAG de rusty-kaspa)
  B · la cota asintotica del paper en segundos: (ln(1/eps)+D*l)/((1-2a)*l) + D^2*l
  C · la regla de cliente "confirmar cuando el k-cluster cubre >= 50 % de mi vista"
      y "confirmar cuando el k* en curso alcanza el k* final" -> tiempos medidos

Salida: salida_control.txt (y salida_control_crudo.txt)
"""
import os
import sys

_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, _DIR)

from d14_lib import (genera_eventos, construye_paper, k_estrella_bitset,
                     k_estrella_replay, cobertura_replay)

LAM = 3.75
ALPHA = 0.2
EPS = 0.05
SEMILLAS = list(range(1, 13))
OBJ = {2.0: (4, 12.0), 1.0: (1, 6.0), 0.1: (0, 1.2)}
MU = (1 - ALPHA) * LAM


def cota_paper(D, eps=EPS, lam=LAM, alpha=ALPHA):
    import math
    return (math.log(1 / eps) + D * lam) / ((1 - 2 * alpha) * lam) + D * D * lam


def primer_cruce_k(bloques, k, frac=0.5, min_n=0):
    """Primer instante en que el prefijo tiene cobertura >= frac con el k dado."""
    pref = [bloques[0]]
    for b in bloques[1:]:
        pref.append(b)
        if len(pref) - 1 < max(2, min_n):
            continue
        if cobertura_replay(pref, k) >= frac:
            return b[2]
    return None


def primer_k_estable(bloques, k_final, kmax=15):
    """Primer instante en que el k* del prefijo (min k con cob >= 50 %) es <= k_final."""
    pref = [bloques[0]]
    for b in bloques[1:]:
        pref.append(b)
        k = None
        for kk in range(kmax + 1):
            if cobertura_replay(pref, kk) >= 0.5:
                k = kk
                break
        if k is not None and k <= k_final:
            return b[2]
    return None


def main():
    lineas = []
    p = lineas.append
    p("=" * 100)
    p("CONTROL POSITIVO — dagknight.txt:182-197")
    p(f"lambda={LAM}, alpha={ALPHA}, eps={EPS}, tasa honesta mu=(1-a)l={MU}")
    p("=" * 100)
    p("")
    p("A · k* sobre el DAG SOLO-HONESTO (12 semillas)")
    p(f"{'D':>5} {'T':>6} | {'bitset k* (semillas)':<40} {'media':>6} | {'replay k*':<40} {'media':>6}")
    for D, (k_obj, t_obj) in OBJ.items():
        for T in (t_obj, 24.0, 60.0):
            vb, vr = [], []
            for s in SEMILLAS:
                ev = genera_eventos(MU, 0.0, T, s)
                bl = construye_paper(ev, D, "oculto")
                kb, _ = k_estrella_bitset(bl, k_max=25)
                kr, _ = k_estrella_replay(bl, k_max=25)
                vb.append(kb)
                vr.append(kr)
            vb2 = [(-1 if x is None else x) for x in vb]
            vr2 = [(-1 if x is None else x) for x in vr]
            p(f"{D:>5} {T:>6} | {str(vb2):<40} {sum(vb2)/len(vb2):>6.2f} | "
              f"{str(vr2):<40} {sum(vr2)/len(vr2):>6.2f}")
        p(f"      objetivo del paper para D={D}: k={k_obj}  (y tiempo {t_obj} s)")
        p("")
    p("B · cota asintotica del paper (:1007, :328-352) en segundos vs figura")
    p(f"{'D':>5} {'cota paper':>11} {'figura':>8} {'figura/cota':>12}")
    for D, (k_obj, t_obj) in OBJ.items():
        c = cota_paper(D)
        p(f"{D:>5} {c:>11.2f} {t_obj:>8.1f} {t_obj/c:>12.2f}")
    p("  (la cota es superior y el paper la declara holgada, :1026-1028; no puede reproducir")
    p("   la tabla exacta: la tabla es de su simulacion, no de la formula)")
    p("")
    p("C · reglas de cliente probadas sobre el DAG solo-honesto (media de 12 semillas)")
    p(f"{'D':>5} | {'k target':>8} | {'1er cruce cob>=50%':>18} {'min_n=8':>9} | {'1er k*<=k_final':>16} | objetivo")
    for D, (k_obj, t_obj) in OBJ.items():
        c1, c2, c3 = [], [], []
        for s in SEMILLAS:
            ev = genera_eventos(MU, 0.0, 60.0, s)
            bl = construye_paper(ev, D, "oculto")
            t1 = primer_cruce_k(bl, k_obj)
            t2 = primer_cruce_k(bl, k_obj, min_n=8)
            t3 = primer_k_estable(bl, k_obj)
            if t1 is not None:
                c1.append(t1)
            if t2 is not None:
                c2.append(t2)
            if t3 is not None:
                c3.append(t3)
        m = lambda v: (sum(v) / len(v)) if v else float("nan")
        p(f"{D:>5} | {k_obj:>8} | {m(c1):>18.2f} {m(c2):>9.2f} | {m(c3):>16.2f} | {t_obj:.1f} s")
    p("")
    p("VEREDICTO DEL CONTROL: PARCIAL. k* escala como el paper (0 con Dl<<1, crece con Dl;")
    p("valores 3-5 / 1-2 / 0 frente a 4 / 1 / 0, dentro de +-1-2), pero la tabla exacta")
    p("1,2/6/12 s NO se reproduce: el paper no publica la regla de cliente ni el codigo de la")
    p("simulacion. LAGUNA declarada; ver informe.md.")
    texto = "\n".join(lineas)
    print(texto)
    with open(os.path.join(_DIR, "salida_control.txt"), "w") as f:
        f.write(texto + "\n")


if __name__ == "__main__":
    main()
