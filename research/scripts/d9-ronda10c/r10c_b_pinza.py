#!/usr/bin/env python3
"""
r10c_b_pinza.py — PUNTO B. La pinza `F >= I/(W/kappa - 1)`: origen, contenido y validez.

BDK+19, Def. 6 (`research/fuentes/bdk19.txt:2299-2312`): un protocolo es `W`-predecible si un
minero puede YA producir, en el instante `t`, un bloque valido para una cadena que aun no existe
y que se extendera `W - 1` bloques. `W` se mide EN BLOQUES. El ataque encubierto de §D.3
(`bdk19.txt:2315-2340`) exige `W > kappa` con `kappa` la profundidad de confirmacion.

La identidad publicada `W/kappa = 1 + I/F` sale de suponer `W = (L + I)*lambda` con `L = F`
(metaauditoria de la ronda 7, `dag-poas-ancla-de-finalidad-metaauditoria.md:215-222`). Eso
presupone que quien conoce `entropia_j` puede evaluar toda la epoca por delante. **R-FIN-14 (e)
lo PROHIBE**: el reto de cada slot sale de una cadena AES secuencial. Aqui se recalcula `W` con
el lookahead MEDIDO en A y se compara.

Criterio de variacion: `W/kappa` debe cambiar con `rho`, con `I`, con `F` y con la opcion (h).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import r10c_lib as L  # noqa: E402

WK = 1.22            # el "tope" que el diseno publica (dag-poas-ancla-de-orden.md §1.3, §4.3)
IS = [491.0, 602.0, 851.0]
FS = [(1224.0, "0,34 h"), (3600.0, "1 h"), (7200.0, "2 h"), (19080.0, "5,3 h")]

print("=" * 112)
print("B1 · LA IDENTIDAD PUBLICADA, reproducida (control): W/kappa = 1 + I/F  con W = (F + I)*lambda")
print("=" * 112)
print(f"{'F':>10} {'I (s)':>7} | {'W (bloques)':>12} {'kappa':>8} {'W/kappa':>9} | "
      f"{'F para W/kappa<=1,22':>21}")
for F, nom in FS:
    for I in (2490.0, 4200.0, 851.0):
        W = (F + I) * L.LAM
        kap = F * L.LAM
        print(f"{nom:>10} {I:>7.0f} | {W:>12.0f} {kap:>8.0f} {W/kap:>9.4f} | {I/(WK-1):>19.0f} s")
print()
print("   Control contra lo publicado: F = 3,2 h (11 520 s) e I = 2 490 s dan "
      f"W/kappa = {(11520+2490)/11520:.4f}  (ancla-de-orden.md §1.3 publica 1,22)")
print(f"   Y F = 3 600 s, I = 2 490 s dan {(3600+2490)/3600:.4f} (publica 1,69); "
      f"F = 1 000 s: {(1000+2490)/1000:.4f} (publica 3,49)")
print()
print("   OBSERVACION 1 (aritmetica, DEMOSTRADA): W/kappa = 1 + I/F > 1 para toda I > 0. La")
print("   condicion de BDK (W <= kappa) es INSATISFACIBLE bajo esta lectura de W, para cualquier F.")
print("   El 1,22 no es un umbral del paper: es el VALOR que salio a F = 3,2 h, adoptado despues")
print("   como tope. BDK marca 1,0.")

print()
print("=" * 112)
print("B2 · W RECALCULADA con R-FIN-14: W = lookahead_max * lambda (el de A1, medido)")
print("=" * 112)
print("   Quien fija W no es la epoca: es quien tenga el reloj de PoT mas rapido Y comparta su")
print("   cadena con los sobornados. Con rho <= 1 en toda la red, W = 1 + lambda*D bloques.")
print()
print(f"{'config':>26} {'rho':>6} {'I':>5} {'F':>8} | {'lookahead (s)':>14} {'W':>8} {'kappa':>7} "
      f"{'W/kappa':>9} {'>1?':>5}")
wd = L.w_dec_de(0.33)
for etq, ret in (("NUCLEO", False), ("(h) retardada", True)):
    for rho in (1.0, 1.0241, 1.05, 1.5, 3.0, 10.0):
        for I in (851.0,):
            for F, nomF in FS:
                lk = L.cinematica_rapida(rho, F, I, wd, ret)[0]
                if rho <= 1.0:
                    lk = 1.0 + L.LAM * L.D_AUT      # granjero honesto: solo el retardo de autoria
                W, kap = lk * L.LAM, F * L.LAM
                print(f"{etq:>26} {rho:>6.4g} {I:>5.0f} {nomF:>8} | {lk:>14.1f} {W:>8.1f} "
                      f"{kap:>7.0f} {W/kap:>9.4f} {'SI' if W > kap else 'no':>5}")

print()
print("=" * 112)
print("B3 · LA PINZA CORREGIDA: F minima que impone la ventana de prediccion")
print("=" * 112)
print("   NUCLEO:  W/kappa = 1 + (I(1-1/rho) - W_dec)/F   =>  F >= (I(1-1/rho) - W_dec)/(tope - 1)")
print("            y si I(1-1/rho) <= W_dec la pinza NO EXISTE (W <= kappa para toda F).")
print("   (h):     W/kappa = I(1-1/rho)/F                 =>  F >= I(1-1/rho)/tope")
print()
print(f"{'tope W/kappa':>13} {'I':>5} {'rho':>6} | {'F pinza NUCLEO (s)':>19} {'(h)':>7} | "
      f"{'F pinza (h) opcion (h)':>23} {'(h)':>7} | {'publicada I/(WK-1)':>19}")
for tope in (1.0, 1.22):
    for I in IS:
        for rho in (1.0, 1.0241, 1.5, 3.0, 10.0):
            look_n = L.cinematica_rapida(rho, 10000.0, I, wd, False)[0]
            exc = I * (1 - 1 / rho) - wd if rho > 1 else -1.0     # exceso de W sobre kappa, en s
            if exc <= 0:
                fn, sn = 0.0, "no existe"
            else:
                fn = exc / (tope - 1.0) if tope > 1.0 else float("inf")
                sn = "inf" if fn == float("inf") else f"{fn:.0f}"
            fh = (I * (1 - 1 / rho) / tope) if rho > 1 else 0.0
            hn = "-" if fn in (0.0, float("inf")) else f"{fn/3600:.2f}"
            print(f"{tope:>13.2f} {I:>5.0f} {rho:>6.4g} | {sn:>19} {hn:>7} | "
                  f"{fh:>23.0f} {fh/3600:>7.2f} | {I/(tope-1) if tope>1 else float('inf'):>17.0f} s")

print()
print("=" * 112)
print("B4 · SENSIBILIDAD: y si W se contara en bloques del DAG y kappa en bloques de cadena")
print("=" * 112)
print("   En una cadena lineal (BDK) no hay diferencia. En el DAG, si se tomara W en bloques del")
print("   DAG (lambda = 1/s) y kappa en bloques de la cadena seleccionada (lambda_chain = 0,200/s,")
print("   ronda 1 `chain_growth.py`), la razon se multiplicaria por 5. Se declara como residuo.")
LAMC = 0.200
for rho in (1.5, 3.0):
    for F in (3600.0, 7200.0):
        lk = L.cinematica_rapida(rho, F, 851.0, wd, False)[0]
        print(f"   rho={rho:.1f} F={F:.0f}s: W/kappa mismo lambda = {lk/F:.4f} · "
              f"lambda vs lambda_chain = {(lk*L.LAM)/(F*LAMC):.4f}")

print()
print("=" * 112)
print("B5 · QUE W/kappa PERMITE QUE F, con I in {300, 851} s (pregunta literal del encargo)")
print("=" * 112)
print("   La pinza en su forma corregida:  F >= (I(1-1/rho) - W_dec)/(tope - 1)   [nucleo]")
print("                                    F >=  I(1-1/rho)/tope                  [(h)]")
print("   Y la PUBLICADA, para comparar:   F >=  I/(tope - 1)")
for I in (300.0, 851.0):
    print(f"\n--- I = {I:.0f} s ---")
    print(f"{'tope W/kappa':>12} | {'PUBLICADA I/(t-1)':>18} | "
          f"{'nucleo rho=1':>13} {'rho=1,5':>10} {'rho=3':>10} {'rho=10':>10} | "
          f"{'(h) rho=3':>10} {'(h) rho=10':>11}")
    for tope in (1.00, 1.05, 1.10, 1.22, 1.50, 2.00, 2.50, 3.50):
        pub = float("inf") if tope <= 1.0 else I / (tope - 1.0)
        cel = []
        for rho in (1.0, 1.5, 3.0, 10.0):
            exc = (I * (1 - 1 / rho) - wd) if rho > 1 else -1.0
            if exc <= 0:
                cel.append("no existe")
            elif tope <= 1.0:
                cel.append("imposible")
            else:
                cel.append(f"{exc/(tope-1.0):.0f} s")
        celh = [f"{I*(1-1/r)/tope:.0f} s" for r in (3.0, 10.0)]
        sp = "inf" if pub == float("inf") else f"{pub:.0f} s"
        print(f"{tope:>12.2f} | {sp:>18} | {cel[0]:>13} {cel[1]:>10} {cel[2]:>10} {cel[3]:>10} | "
              f"{celh[0]:>10} {celh[1]:>11}")
print()
print("   Nota de procedencia del tope: BDK marca 1,00 (`W > kappa` habilita el soborno encubierto).")
print("   El 1,22 del diseno es el VALOR que salio a F = 3,2 h e I = 2 490 s en la ronda 7, adoptado")
print("   despues como tope; la propuesta lo etiqueta «una eleccion, no una derivacion» (§4.3), y")
print("   compara «un 22 % en vez de un 250 %» — ese 250 % es el W/kappa = 3,49-3,50 de los dos")
print("   puntos de ejemplo de la ronda 7 (metaauditoria L215-222), que la propia metaauditoria")
print("   declaro «soborno encubierto posible». Ni 1,22 ni 2,5 son umbrales del paper.")
