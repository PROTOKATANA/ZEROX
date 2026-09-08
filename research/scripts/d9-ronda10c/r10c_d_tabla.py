#!/usr/bin/env python3
"""
r10c_d_tabla.py — PUNTO D. Configuracion x termino -> F que impone cada uno, y cual manda.

Los cuatro terminos NO tiran en el mismo sentido, y esa es la respuesta:

  · F_carrera   (MINIMO)  la carrera de bloques dentro de F: union a 10 anos < 1e-10 (C2a).
  · pinza W/k   (MINIMO)  la ventana de prediccion de BDK, con la W corregida de B.3.
  · sembrador   (MAXIMO)  el ploteo dirigido: margen A*_10x / lookahead >= objetivo (A.4).
  · usuario     (ninguno) el riesgo del comerciante NO depende de F (C1). No impone nada.

Manda `max(F_carrera, pinza)` y hay que comprobar que cabe por debajo del maximo del sembrador.
Si no cabe, la configuracion es INVIABLE con ese margen objetivo.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import r10c_lib as L  # noqa: E402

# F_carrera MEDIDA en r10c_c2_frontera.py (salida_c2.txt, C2a): {I: {alpha: (d0, D8)}}
F_CARRERA = {
    491.0: {0.33: (1028.0, 3588.0), 0.35: (1262.0, 6987.0), 0.40: (2490.0, 26674.0)},
    602.0: {0.33: (1025.0, 3573.0), 0.35: (1257.0, 6955.0), 0.40: (2480.0, 26575.0)},
    851.0: {0.33: (1019.0, 3547.0), 0.35: (1249.0, 6900.0), 0.40: (2462.0, 26406.0)},
}
A10 = L.A_ESTRELLA_10X_H["B"] * 3600.0      # 4,1 h en s, escenario B (favorece al atacante)
WD = L.w_dec_de(0.33)                        # 20 s
TOPE_WK = 1.22                               # el tope publicado; se da tambien con 1,00 (BDK literal)

CONFIGS = [("rho_max = 1   (n_eval = 45)", 1.0, 491.0, False),
           ("rho_max = 1,5 (n_eval = 68)", 1.5, 602.0, False),
           ("rho_max = 3   (n_eval = 135)", 3.0, 851.0, False),
           ("rho_max = 3 CON (h)", 3.0, 851.0, True),
           ("rho_max = 10 CON (h)", 10.0, 851.0, True),
           ("(h), I libre = 300 s, rho = 3", 3.0, 300.0, True)]


def f_pinza(rho, I, ret, tope):
    exc = I * (1 - 1 / rho) if rho > 1 else 0.0
    if ret:
        return exc / tope
    exc -= WD
    if exc <= 0:
        return 0.0
    return float("inf") if tope <= 1.0 else exc / (tope - 1.0)


def f_max_sembrador(rho, I, ret, margen):
    """F maxima compatible con `margen` frente a A*_10x (esc. B)."""
    tope_look = A10 / margen
    extra = I * (1 - 1 / rho) if rho > 1 else 0.0
    if ret or rho <= 1:
        return float("inf") if extra <= tope_look else float("-inf")
    return tope_look - extra + WD + 1.0


def fmt(x, h=True):
    if x == float("inf"):
        return "sin limite"
    if x == float("-inf"):
        return "IMPOSIBLE"
    return f"{x:.0f} s ({x/3600:.2f} h)" if h else f"{x:.0f} s"


for alpha_obj in (0.33, 0.35):
    for modelo, idx in (("CORREGIDO delta=0 (9a)", 0), ("PESIMISTA delta D8", 1)):
        print("=" * 122)
        print(f"D · alpha objetivo = {alpha_obj:.2f} · modelo de carrera = {modelo} · "
              f"A*_10x = {A10:.0f} s (esc. B) · W_dec = {WD:.0f} s · tope W/kappa = {TOPE_WK}")
        print("=" * 122)
        print(f"{'configuracion':>32} | {'F_carrera (min)':>17} {'pinza (min)':>17} "
              f"{'usuario':>8} | {'F max sembrador 3x':>19} {'5x':>17} | {'MANDA':>17} {'viable 3x':>10}")
        for nom, rho, I, ret in CONFIGS:
            fc = F_CARRERA.get(I, F_CARRERA[851.0])[alpha_obj][idx]
            fp = f_pinza(rho, I, ret, TOPE_WK)
            fs3 = f_max_sembrador(rho, I, ret, 3.0)
            fs5 = f_max_sembrador(rho, I, ret, 5.0)
            manda = max(fc, fp)
            quien = "F_carrera" if fc >= fp else "pinza"
            viable = "SI" if manda <= fs3 else "NO"
            print(f"{nom:>32} | {fmt(fc):>17} {fmt(fp):>17} {'nada':>8} | "
                  f"{fmt(fs3):>19} {fmt(fs5):>17} | {quien+' '+f'{manda/3600:.2f} h':>17} {viable:>10}")
        print()

print("=" * 122)
print("D2 · La misma tabla con el tope LITERAL de BDK (W/kappa <= 1,00), alpha = 0,33, delta = 0")
print("=" * 122)
print(f"{'configuracion':>32} | {'F_carrera':>17} {'pinza W/k<=1':>17} | {'MANDA':>20}")
for nom, rho, I, ret in CONFIGS:
    fc = F_CARRERA.get(I, F_CARRERA[851.0])[0.33][0]
    fp = f_pinza(rho, I, ret, 1.0)
    manda = max(fc, fp)
    print(f"{nom:>32} | {fmt(fc):>17} {fmt(fp):>17} | "
          f"{('IMPOSIBLE (W>kappa siempre)' if manda == float('inf') else fmt(manda)):>20}")

print()
print("=" * 122)
print("D3 · Sensibilidad del margen del sembrador: que F admite cada margen objetivo")
print("=" * 122)
print(f"{'configuracion':>32} | " + " ".join(f"{m:>13.1f}x" for m in (1.5, 2.0, 3.0, 5.0, 10.0)))
for nom, rho, I, ret in CONFIGS:
    cel = [fmt(f_max_sembrador(rho, I, ret, m)) for m in (1.5, 2.0, 3.0, 5.0, 10.0)]
    print(f"{nom:>32} | " + " ".join(f"{c:>14}" for c in cel))

print()
print("=" * 122)
print("D4 · EL PRECIO DE (h), cuantificado con el coste de PoT MEDIDO (nadie lo habia hecho)")
print("=" * 122)
print("R-FIN-14 (h): `entropia_j = VDF(chunk(I_j) || salida(I_j), L*iter)`, revelada en t_j.")
print("Es un segundo VDF de `L` slots por epoca. Coste MEDIDO por slot en el clon subspace @ f8842d0,")
print("Ryzen 9 9950X3D, ruta verify_sequential_avx512f_vaes, 8 checkpoints, 200 032 000 iteraciones:")
PROVE, VERIFY = 1.561, 0.0961      # s/slot (dag-poas-ancla-de-orden.md, bloque "Coste del PoT, MEDIDO")
print(f"   prove = {PROVE:.3f} s/slot · verify = {VERIFY:.4f} s/slot (razon {PROVE/VERIFY:.1f}x)")
print("La cadena principal de PoT ya cuesta verify/tau = 9,6 % de un nucleo continuo a tau = 1 s.")
print()
print(f"{'F (L slots)':>12} {'I (s)':>7} | {'verificar el VDF de (h)':>24} {'por epoca':>11} "
      f"{'% de un nucleo continuo':>24} {'total con la cadena':>20}")
for F in (1224.0, 2488.0, 3600.0, 7200.0, 19080.0):
    for I in (491.0, 851.0):
        cost = F * VERIFY
        frac = cost / I
        print(f"{F:>12.0f} {I:>7.0f} | {cost:>22.1f} s {'1 por epoca':>11} "
              f"{frac:>23.1%} {frac + VERIFY:>19.1%}")
print()
print("   Lectura: (h) hace que una F LARGA sea cara en CPU de verificacion (crece como F/I).")
print("   A F = 1 h e I = 851 s son 346 s de CPU por epoca = 40,7 % de un nucleo, ADEMAS del 9,6 %")
print("   de la cadena principal. A F = 2 h, 81,3 %. A F = 5,3 h, 215 %: mas de dos nucleos.")
print("   Es una DERIVACION del coste medido por slot, no una medicion de punta a punta: PLAUSIBLE.")
