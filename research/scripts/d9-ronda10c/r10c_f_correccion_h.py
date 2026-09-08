#!/usr/bin/env python3
"""
r10c_f_correccion_h.py — CORRECCION DE MI PROPIO PUNTO A/B/D/E EN SUS COLUMNAS «(h)».

Mi modelo de la opcion (h) heredaba la premisa de 9c §E.5: «`entropia_j` NO se conoce hasta `t_j`».
Es FALSA. `entropia_j = VDF(chunk(I_j) || salida(I_j), L*iter)` (R-FIN-14 (h)) es una funcion de
DOS ENTRADAS PUBLICAS en `slot(I_j)`: nadie la revela, cada cual la CALCULA. Un VDF retrasa por
trabajo secuencial, no por secreto — y quien calcula mas rapido la tiene antes.

  · FUENTE PRIMARIA EN EL REPOSITORIO, que ya lo decia: `research/dag-poas-ancla-de-finalidad.md`
    L319-322 (ronda 7, seccion «Considerado y descartado»): la revelacion retardada «reduce el
    lookahead de `L + I(1-1/v)` a `(L + I)(1-1/v)` para `v` finito, sin cambiar la cota con
    `v -> infinito`». Es decir: con `v = rho > 1` el lookahead NO es `I(1-1/rho)`; es (L+I)(1-1/rho).
  · Concurrentemente, D8 ronda 10a llega a lo mismo por su cuenta (`research/scripts/d8-ronda10a/`,
    commit 34157a2: «la revelacion NO se publica, se calcula»). Adopto la correccion por la fuente
    primaria, no por su informe, y lo cito como convergencia.

MODELO CORREGIDO. El atacante necesita (i) saber QUE bloque es el ancla — instante `T_j + W_dec` —
y (ii) completar `L` slots de VDF a velocidad `rho`, en paralelo con su cadena principal de PoT
(son dos lineas de AES independientes). Luego conoce `entropia_j` en `T_j + W_dec + L/rho`, no en
`t_j = T_j + L`. Eso es exactamente el modelo del NUCLEO con `W_dec` sustituida por

        W_dec_efectiva = W_dec + L/rho

y por tanto se resuelve con el MISMO integrador ya validado en A0 (no se anade ningun modelo).
Forma cerrada resultante:  lookahead_max = (L + I)(1 - 1/rho) - W_dec - 1.

Criterio de variacion: cambia con rho, con L (= F si estan atados) y con I; es 0 si rho <= 1.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import r10c_lib as L  # noqa: E402

A10 = L.A_ESTRELLA_10X_H["B"] * 3600.0
WD = L.w_dec_de(0.33)
RHOS = [1.0, 1.05, 1.2, 1.5, 3.0, 10.0]


def look_h_vdf(rho, Lseg, I, w_dec, Lrev=None):
    """(h) con la entropia CALCULABLE: W_dec efectiva = w_dec + Lrev/rho."""
    if rho <= 1.0:
        return 0.0
    Lrev = Lseg if Lrev is None else Lrev
    return L.cinematica_rapida(rho, Lseg, I, w_dec + Lrev / rho, False)[0]


def cerrada(rho, Lseg, I, w_dec, Lrev=None):
    if rho <= 1.0:
        return 0.0
    Lrev = Lseg if Lrev is None else Lrev
    return Lseg - 1.0 - w_dec - Lrev / rho + I * (1.0 - 1.0 / rho)


print("=" * 120)
print("F1 · (h) RECALCULADA: la entropia se CALCULA, no se revela.  I = 851 s, alpha = 0,33 (W_dec = 20 s)")
print("=" * 120)
print(f"{'L = F':>8} {'rho':>6} | {'(h) MI MODELO VIEJO':>20} {'(h) CORREGIDA':>15} {'cerrada':>10} "
      f"{'ronda 7 (L+I)(1-1/rho)':>23} | {'NUCLEO':>9} | {'(h)/nucleo':>11}")
for Lseg in (1224.0, 3600.0, 7200.0, 19080.0):
    for rho in RHOS:
        viejo = L.cinematica_rapida(rho, Lseg, 851.0, WD, True)[0]
        nuevo = look_h_vdf(rho, Lseg, 851.0, WD)
        cer = cerrada(rho, Lseg, 851.0, WD)
        r7 = 0.0 if rho <= 1 else (Lseg + 851.0) * (1 - 1 / rho)
        nuc = L.cinematica_rapida(rho, Lseg, 851.0, WD, False)[0]
        mrk = "" if abs(nuevo - cer) < 1.5 else "  <-- CERRADA DISCREPA"
        raz = (nuevo / nuc) if nuc > 0 else float("nan")
        print(f"{Lseg:>8.0f} {rho:>6.4g} | {viejo:>20.1f} {nuevo:>15.1f} {cer:>10.1f} {r7:>23.1f} | "
              f"{nuc:>9.1f} | {raz:>10.2%}{mrk}")

print()
print("=" * 120)
print("F2 · QUE CAMBIA EN EL MARGEN DEL SEMBRADOR Y EN W/kappa (A*_10x = 14 760 s, esc. B)")
print("=" * 120)
print(f"{'L = F':>8} {'rho':>6} | {'margen (h) VIEJO':>17} {'margen (h) CORREGIDO':>21} "
      f"{'margen NUCLEO':>14} | {'W/kappa (h) corregida':>22} {'BDK 1,00?':>10}")
for Lseg in (3600.0, 7200.0):
    for rho in (1.5, 3.0, 10.0):
        viejo = L.cinematica_rapida(rho, Lseg, 851.0, WD, True)[0]
        nuevo = look_h_vdf(rho, Lseg, 851.0, WD)
        nuc = L.cinematica_rapida(rho, Lseg, 851.0, WD, False)[0]
        wk = nuevo / Lseg
        print(f"{Lseg:>8.0f} {rho:>6.3g} | {A10/viejo:>16.1f}x {A10/nuevo:>20.1f}x "
              f"{A10/nuc:>13.1f}x | {wk:>22.4f} {'SI' if wk <= 1.0 else 'no':>10}")

print()
print("=" * 120)
print("F3 · (h) DESATADA: L de la inyeccion = 1 h, F = 2 h (la configuracion de mi §E) — con (h) encima")
print("=" * 120)
print(f"{'L':>7} {'F':>7} {'rho':>6} | {'nucleo':>9} {'(h) corregida':>14} | {'margen nucleo':>14} "
      f"{'margen (h)':>11} | {'W/k nucleo':>11} {'W/k (h)':>9}")
for Lseg, Fv in ((3600.0, 7200.0), (3547.0, 7200.0), (3600.0, 19080.0)):
    for rho in (1.5, 3.0):
        nuc = L.cinematica_rapida(rho, Lseg, 851.0, WD, False)[0]
        nue = look_h_vdf(rho, Lseg, 851.0, WD)
        print(f"{Lseg:>7.0f} {Fv:>7.0f} {rho:>6.3g} | {nuc:>9.0f} {nue:>14.0f} | "
              f"{A10/nuc:>13.1f}x {A10/nue:>10.1f}x | {nuc/Fv:>11.4f} {nue/Fv:>9.4f}")

print()
print("=" * 120)
print("F4 · CONTROL NEGATIVO Y CRITERIO DE VARIACION")
print("=" * 120)
print(f"   rho = 1,0 : (h) corregida = {look_h_vdf(1.0, 7200.0, 851.0, WD):.1f} s  "
      f"(debe ser 0: sin reloj mas rapido no adelanta el VDF ni la cadena)")
print(f"   rho = 0,5 : {look_h_vdf(0.5, 7200.0, 851.0, WD):.1f} s")
print("   Depende de L: " + " ".join(f"L={x:.0f}->{look_h_vdf(3.0, x, 851.0, WD):.0f} s"
                                     for x in (1224.0, 3600.0, 7200.0)))
print("   Depende de I: " + " ".join(f"I={x:.0f}->{look_h_vdf(3.0, 7200.0, x, WD):.0f} s"
                                     for x in (300.0, 851.0, 4200.0)))
print()
print("   Palanca que D8-10a propone y que aqui NO se explora (queda anotada): `Lrev = L - S_max`")
print("   (acortar el VDF de revelacion). Con S_max = 150 s y L = 7 200 s mueve el resultado")
print(f"   de {look_h_vdf(3.0, 7200.0, 851.0, WD):.0f} s a "
      f"{look_h_vdf(3.0, 7200.0, 851.0, WD, Lrev=7200.0-150.0):.0f} s: "
      f"{(look_h_vdf(3.0,7200.0,851.0,WD,Lrev=7050.0)/look_h_vdf(3.0,7200.0,851.0,WD)-1):+.2%}.")

print()
print("=" * 120)
print("F5 · LA PINZA W/kappa CON (h) CORREGIDA (sustituye a la fila «(h)» de mi §B.3)")
print("=" * 120)
print("   Con L = F (atados):  W/kappa = [(F+I)(1-1/rho) - W_dec]/F  <= tope")
print("      =>  F >= (I(1-1/rho) - W_dec) / (tope - 1 + 1/rho)      [inf si el denominador <= 0]")
print("   Con L desatada:      F >= [(L+I)(1-1/rho) - W_dec]/tope")
print()
print(f"{'tope':>6} {'I':>6} {'rho':>6} | {'F pinza (h) ATADA':>19} {'(h)':>7} | "
      f"{'mi §B.3 (h) VIEJA':>19} | {'F pinza NUCLEO':>16}")
for tope in (1.00, 1.22):
    for I in (491.0, 851.0):
        for rho in (1.5, 3.0, 10.0):
            den = tope - 1.0 + 1.0 / rho
            num = I * (1 - 1 / rho) - WD
            fh = float("inf") if den <= 0 or num <= 0 else num / den
            if num <= 0:
                fh = 0.0
            viejo = I * (1 - 1 / rho) / tope
            excn = I * (1 - 1 / rho) - WD
            fn = (float("inf") if tope <= 1.0 else excn / (tope - 1.0)) if excn > 0 else 0.0
            sh = "no existe" if fh == 0.0 else ("inf" if fh == float("inf") else f"{fh:.0f} s")
            sn = "no existe" if fn == 0.0 else ("inf" if fn == float("inf") else f"{fn:.0f} s")
            hh = "-" if fh in (0.0, float("inf")) else f"{fh/3600:.2f}"
            print(f"{tope:>6.2f} {I:>6.0f} {rho:>6.3g} | {sh:>19} {hh:>7} | {viejo:>17.0f} s | {sn:>16}")

print()
print("=" * 120)
print("F6 · LA TABLA D REHECHA EN SUS FILAS «(h)» (alpha = 0,33; F_carrera de C2a)")
print("=" * 120)
FC = {0.33: {"d0": 1019.0, "D8": 3547.0}, 0.35: {"d0": 1249.0, "D8": 6900.0}}
print(f"{'config':>34} {'modelo':>7} | {'F_carrera':>11} {'pinza (h)':>11} {'MANDA':>10} | "
      f"{'F max sembrador 3x':>19} {'5x':>10} | {'viable 3x':>10}")
for rho in (1.5, 3.0):
    for mod in ("d0", "D8"):
        fc = FC[0.33][mod]
        den = 1.22 - 1.0 + 1.0 / rho
        num = 851.0 * (1 - 1 / rho) - WD
        fp = 0.0 if num <= 0 else num / den
        # F max del sembrador con (h) atada: (F+I)(1-1/rho) - W_dec <= A10/margen
        cel = []
        for m in (3.0, 5.0):
            fmax = (A10 / m + WD) / (1 - 1 / rho) - 851.0
            cel.append(fmax)
        manda = max(fc, fp)
        print(f"{'(h) ATADA rho=' + f'{rho:g}':>34} {mod:>7} | {fc:>9.0f} s {fp:>9.0f} s "
              f"{manda:>8.0f} s | {cel[0]:>17.0f} s {cel[1]:>8.0f} s | "
              f"{'SI' if manda <= cel[0] else 'NO':>10}")
