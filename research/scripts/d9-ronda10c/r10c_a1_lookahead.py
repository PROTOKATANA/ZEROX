#!/usr/bin/env python3
"""
r10c_a1_lookahead.py — PUNTO A. El lookahead REAL bajo R-FIN-14.

Pregunta del encargo: cuantos slots por delante conoce sus retos (a) un granjero honesto
(rho = 1), (b) un atacante con rho in {1,5; 3}, (c) lo mismo bajo la opcion (h) de revelacion
retardada. Y si el argumento del «sembrador» (plotter rapido que conoce los retos con antelacion
I + F) sobrevive.

METODO. Dos instrumentos independientes de la MISMA cinematica:
  · `cinematica`         paso a paso, 1 s de reloj por paso (lento, sin ninguna forma cerrada);
  · `cinematica_rapida`  integrador exacto por ventana de inyeccion (rapido).
A0 valida el segundo contra el primero. Solo despues se contrastan las formas cerradas.

Criterio alpha (regla 4): `W_dec` es funcion de alpha (MEDIDA por 9c C.2), asi que el lookahead
del nucleo cambia con alpha; la fila alpha = 0 esta en la tabla.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import r10c_lib as L  # noqa: E402

RHOS = [0.5, 1.0, 1.001, 1.05, 1.2, 1.5, 3.0, 10.0]
CONFIGS = [("F = 0,34 h (F_carrera d=0)", 1224.0), ("F = 1 h", 3600.0),
           ("F = 2 h (provisional)", 7200.0), ("F = 5,3 h (publicado)", 19080.0)]
IS = [491.0, 602.0, 851.0]     # I de la tabla P3 (rho_max = 1 / 1,5 / 3), auditoria-8c §3
ALPHAS = [0.00, 0.10, 0.25, 0.33, 0.40]


def cerrada_nucleo(rho, L_seg, I_seg, w_dec):
    """Forma cerrada CANDIDATA para el nucleo (a validar): (L - W_dec) + I(1 - 1/rho)."""
    return 0.0 if rho <= 1.0 else (L_seg - 1.0 - w_dec) + I_seg * (1.0 - 1.0 / rho)


def cerrada_h(rho, I_seg):
    """Forma cerrada CANDIDATA para (h) (a validar): I(1 - 1/rho), independiente de F."""
    return 0.0 if rho <= 1.0 else I_seg * (1.0 - 1.0 / rho) - 1.0 + 1.0 / rho


print("=" * 118)
print("A0 · VALIDACION del integrador rapido contra la simulacion paso a paso (1 s por paso)")
print("=" * 118)
print(f"{'rho':>7} {'F':>7} {'I':>5} {'(h)':>4} | {'max lento':>10} {'max rapido':>11} {'dif':>7} | "
      f"{'media lenta':>12} {'media rapida':>13} {'dif':>7}")
peor = 0.0
for rho in (1.05, 1.2, 1.5, 3.0, 10.0):
    for F, I, ret in ((7200.0, 851.0, False), (3600.0, 491.0, False), (7200.0, 851.0, True),
                      (19080.0, 4200.0, False)):
        # horizonte >= 2,5x el bootstrap teorico: si no, la simulacion lenta se mide ANTES
        # de saturar y la comparacion no vale (error propio detectado en la primera pasada).
        cap = (I + F - 1.0 - 20.0) if not ret else (I - 1.0)
        hor = max(300_000.0, 2.5 * cap / (rho - 1.0))
        mxl, mel, _, bol = L.cinematica(rho, F, I, 20.0, ret, hor)
        mxr, mer, bor = L.cinematica_rapida(rho, F, I, 20.0, ret)
        peor = max(peor, abs(mxl - mxr) / max(mxr, 1.0), abs(mel - mer) / max(mer, 1.0))
        print(f"{rho:>7.4g} {F:>7.0f} {I:>5.0f} {str(ret):>4} | {mxl:>10.1f} {mxr:>11.1f} "
              f"{mxl-mxr:>7.2f} | {mel:>12.1f} {mer:>13.1f} {mel-mer:>7.2f}")
print(f"   peor discrepancia RELATIVA = {peor:.3%}  ->  "
      f"{'VALIDADO (< 0,5 %; el resto es la discretizacion dt = 1 s)' if peor < 0.005 else 'NO VALIDADO'}")

print()
print("=" * 118)
print("A1 · LOOKAHEAD DEL ATACANTE, rejilla completa (regimen, tras el bootstrap)")
print("     adelanto = slot al que ha llegado su cadena de PoT  -  slot de la cadena canonica")
print("     L = F (R-FIN-2/R-FIN-7: t_j = slot(I_j) + L, L = profundidad de finalidad)")
print("=" * 118)
for nom, F in CONFIGS:
    for I in IS:
        print(f"\n--- {nom} = {F:.0f} s · I = {I:.0f} s ---")
        print(f"{'alpha':>6} {'W_dec':>6} {'rho':>7} | {'NUCLEO max':>11} {'cerrada':>9} {'media':>9} "
              f"{'bootstrap':>11} | {'(h) max':>9} {'cerrada':>9} {'(h) media':>10}")
        for a in ALPHAS:
            wd = L.w_dec_de(a)
            for rho in RHOS:
                mx, me, bo = L.cinematica_rapida(rho, F, I, wd, False)
                mxh, meh, _ = L.cinematica_rapida(rho, F, I, wd, True)
                cn, ch = cerrada_nucleo(rho, F, I, wd), cerrada_h(rho, I)
                bo_s = "nunca" if math.isnan(bo) else f"{bo/3600:.2f} h"
                mrk = "" if (abs(mx - cn) < 1.5 and abs(mxh - ch) < 1.5) else "  <-- CERRADA DISCREPA"
                print(f"{a:>6.2f} {wd:>6.0f} {rho:>7.4g} | {mx:>11.1f} {cn:>9.1f} {me:>9.1f} "
                      f"{bo_s:>11} | {mxh:>9.1f} {ch:>9.1f} {meh:>10.1f}{mrk}")

print()
print("=" * 118)
print("A1b · GRANJERO HONESTO (rho = 1): cuantos retos futuros conoce")
print("=" * 118)
print("Bajo R-FIN-14 (b) el reto del slot s es blake3(blake3(salida(f,s)) || LE64(s)) y")
print("`salida(f,s) = AES^N(salida(f,s-1))`: para conocer el reto de s hay que HABER CALCULADO s.")
for nom, F in CONFIGS:
    mx, _, _ = L.cinematica_rapida(1.0, F, 851.0, 20.0, False)
    mxh, _, _ = L.cinematica_rapida(1.0, F, 851.0, 20.0, True)
    print(f"   {nom:>28}: nucleo = {mx:.0f} slots · (h) = {mxh:.0f} slots")
print(f"   R-FIN-14 (d) y el D = {L.D_AUT:.0f} s de Autonomys RETRASAN la publicacion; no adelantan el reto.")

print()
print("=" * 118)
print("A1c · EL SEMBRADOR: espacio fabricable y margen frente a A* (ronda 7 §1)")
print("=" * 118)
print(f"t_plot (coste-ploteo-medido.md): {L.T_PLOT}")
print(f"A* h por escenario: {L.A_ESTRELLA_H} · con plotter 10x: {L.A_ESTRELLA_10X_H}")
print(f"alpha de referencia = 0,33 -> W_dec = {L.w_dec_de(0.33):.0f} s")
print()
print(f"{'config':>30} {'rho':>5} | {'nucleo max (s)':>15} {'GiB/GPU':>9} {'margen A*B':>11} "
      f"{'margen 10x':>11} | {'(h) max (s)':>12} {'margen 10x (h)':>15}")
for nom, F in CONFIGS:
    for rho in (1.0, 1.5, 3.0):
        wd = L.w_dec_de(0.33)
        mx, _, _ = L.cinematica_rapida(rho, F, 851.0, wd, False)
        mxh, _, _ = L.cinematica_rapida(rho, F, 851.0, wd, True)
        gib = L.espacio_fabricado_gib(mx, L.T_PLOT["GPU_tope_ALU"])
        m1 = L.margen_sembrador(mx, L.A_ESTRELLA_H["B"])
        m10 = L.margen_sembrador(mx, L.A_ESTRELLA_10X_H["B"])
        m10h = L.margen_sembrador(mxh, L.A_ESTRELLA_10X_H["B"])
        f1 = "inf" if m1 == float("inf") else f"{m1:.1f}x"
        f10 = "inf" if m10 == float("inf") else f"{m10:.2f}x"
        f10h = "inf" if m10h == float("inf") else f"{m10h:.1f}x"
        print(f"{nom:>30} {rho:>5.3g} | {mx:>15.1f} {gib:>9.1f} {f1:>11} {f10:>11} | "
              f"{mxh:>12.1f} {f10h:>15}")

print()
print("=" * 118)
print("A1d · RITMO DE PLOTEO frente a la ventana que le queda (coste-ploteo-medido.md)")
print("=" * 118)
for etq, tp in sorted(L.T_PLOT.items(), key=lambda kv: kv[1]):
    print(f"   {etq:>18}: {tp:>7.3f} s/sector de 1 GiB -> {3600.0/tp:>8.1f} GiB/h por unidad")
print()
print(f"{'ventana del sembrador':>32} | {'sectores probables (GPU tope ALU)':>34} | {'TiB':>9}")
wd33 = L.w_dec_de(0.33)
casos = [("rho <= 1 (nucleo Y (h))", 0.0), ("1 slot: solo el reto actual", 1.0)]
for rho in (1.5, 3.0):
    casos.append((f"(h), rho = {rho:g}, I = 851 s", L.cinematica_rapida(rho, 7200.0, 851.0, wd33, True)[0]))
for F, nf in ((3600.0, "1 h"), (7200.0, "2 h")):
    for rho in (1.5, 3.0):
        casos.append((f"nucleo, rho = {rho:g}, F = {nf}", L.cinematica_rapida(rho, F, 851.0, wd33, False)[0]))
for etq, look in casos:
    n = look / L.T_PLOT["GPU_tope_ALU"]
    print(f"{etq:>32} | {n:>34.1f} | {n/1024:>9.4f}")
