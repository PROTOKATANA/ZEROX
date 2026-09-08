#!/usr/bin/env python3
"""
r8f_c_constantes.py — el mapa `m -> (I, c, F)` y las constantes que salen de la `m` de D9-f.

Pinza de D9-d (informe.md L297, `r8c_steering.py`), sin cambiar nada:
    g = c_m / sqrt(alpha*lambda*I) <= 3,6 %       (steering, BDK+19 / ronda 4 §5)
    W/kappa = 1 + I/F <= 1,22                     (ventana de prediccion, BDK+19 §2)
  =>  I = (c_m/g)^2 / (alpha*lambda);   F = I/0,22
El peor `alpha` es el mas PEQUENO con menu no trivial, porque g ~ 1/sqrt(alpha).

`m` NO se supone: se lee de `salida_b2_gran1.txt`, ejecutado en esta misma ronda con 12
semillas, 21 umbrales y la familia saturada de A1 (retro <= 16 global y bloque a bloque,
ventana +-30 s). Las dos anclas salen de la MISMA ejecucion.

Criterio alpha: la tabla cambia con alpha en las dos columnas (m y 1/alpha), y alpha=0 da
m=1, c_m=0, I=0: no hay steering sin atacante.
"""
import math
import sys

from r8f_lib import constantes, c_interp, G_TECHO, WK_TECHO

# ------------------------------------------------------------------ DATOS MEDIDOS
# Fuente: salida_b2_gran1.txt (r8f_b2_ataques.py, 12 semillas, gran = 1 s).
# alpha -> (m_BS, m_SLOT) por nivel de coste.
MED = {
    "gratis":     {0.10: (3.655, 2.079), 0.25: (4.766, 2.452),
                   0.33: (4.881, 2.829), 0.40: (4.615, 2.917)},
    "+retraso":   {0.10: (4.286, 2.460), 0.25: (6.508, 3.214),
                   0.33: (7.317, 3.591), 0.40: (7.639, 3.623)},
    "+retencion": {0.10: (4.813, 2.548), 0.25: (8.544, 3.639),
                   0.33: (9.663, 4.175), 0.40: (10.163, 4.504)},
    # Fuente: salida_b1_gran1.txt — familia LITERAL de D9-e (r8e_a1c_copias.py) con
    # 14 COPIAS del mismo billete, que es el regimen del que salio la m = 5,77 de D9-e.
    "gratis+14copias": {0.10: (4.194, 2.238), 0.25: (6.052, 2.540),
                        0.40: (6.167, 3.024)},
}
LAM_AZUL = {0.10: 0.9793, 0.25: 0.9834, 0.33: 0.9862, 0.40: 0.9866}   # salida_b2_gran1.txt

# Cota analitica cruda de A3 (merge_depth_bound), sin hipotesis estadistica ninguna.
M_CRUDA = 1484.0
# Cota analitica de la ventana (A3, con lambda_azul estable).
M_VENTANA = 63.0


def peor(nivel, col):
    """Devuelve (alpha*, m*, c_m, I, F, c) con el alpha que MAXIMIZA I."""
    mejor = None
    for a, par in MED[nivel].items():
        m = par[col]
        cm, I, F, _ = constantes(m, a)
        c = I * LAM_AZUL[a]
        if mejor is None or I > mejor[3]:
            mejor = (a, m, cm, I, F, c)
    return mejor


if __name__ == "__main__":
    print("=== C · las constantes que salen de la `m` de D9-f ===")
    print(f"g <= {G_TECHO:.3f}, W/kappa <= {WK_TECHO}, lambda = 1. `c_m` por integracion "
          f"numerica (c_2={c_interp(2):.4f}, c_4={c_interp(4):.4f}, publicados 0,564 y 1,029).\n")

    print("--- (1) el mapa m -> (I, F), peor alpha = 0,10 ---")
    print(f"{'m':>10} {'c_m':>8} {'I (s)':>10} {'I (h)':>8} {'F (h)':>9} {'F (dias)':>9}")
    for m in (1.5, 2.079, 2.33, 2.548, 3.655, 4, 4.813, 5.77, 10, 30, 63, 100,
              300, 1000, M_CRUDA, 10000):
        cm, I, F, _ = constantes(m, 0.10)
        print(f"{m:>10.3f} {cm:>8.4f} {I:>10.0f} {I/3600:>8.2f} {F/3600:>9.2f} "
              f"{F/86400:>9.2f}")

    print("\n--- (2) constantes por nivel de coste y por ancla (peor alpha) ---")
    print(f"{'nivel':>12} {'ancla':>10} {'alpha*':>7} {'m':>7} {'c_m':>7} "
          f"{'I (s)':>9} {'I (h)':>7} {'F (h)':>7} {'c (azules)':>11} {'c (slots)':>10}")
    for nivel in ("gratis", "gratis+14copias", "+retraso", "+retencion"):
        for col, nom in ((0, "blue_score"), (1, "slot")):
            a, m, cm, I, F, c = peor(nivel, col)
            print(f"{nivel:>12} {nom:>10} {a:>7.2f} {m:>7.3f} {cm:>7.4f} "
                  f"{I:>9.0f} {I/3600:>7.2f} {F/3600:>7.2f} {c:>11.0f} {I:>10.0f}")
        print()

    print("--- (3) lo que cuesta NO tener cota: las cotas superpuestas ---")
    for nom, m in (("medida, saturada, gratis (slot)", 2.079),
                   ("medida, saturada, gratis (blue_score)", 3.655),
                   ("medida, saturada, +retencion (slot)", 2.548),
                   ("medida, saturada, +retencion (blue_score)", 4.813),
                   ("cota de la VENTANA (2k/lambda_azul, PLAUSIBLE)", M_VENTANA),
                   ("cota CRUDA por merge_depth_bound (determinista)", M_CRUDA),
                   ("cota POR CONSTRUCCION del ancla slot: 1+lambda*tau*S_max, tau=1 s",
                    1 + 150.0),
                   ("... con tau = 0,1 s", 1 + 15.0),
                   ("... con tau = 0,02 s", 1 + 3.0)):
        cm, I, F, _ = constantes(m, 0.10)
        print(f"   {nom:>46}  m={m:>8.2f}  I={I/3600:>6.2f} h  F={F/3600:>7.2f} h "
              f"({F/86400:.2f} d)")

    print("\n--- (4) criterio alpha ---")
    for a in (0.0, 0.10, 0.25, 0.40):
        if a == 0.0:
            cm, I, F, _ = constantes(1.0, 0.10)
            print(f"   alpha=0,00: m=1,000 -> c_m={cm:.4f}  I={I:.0f} s  F={F:.0f} s "
                  f"(sin atacante NO hay steering)")
        else:
            m = MED["gratis"][a][1]
            cm, I, F, _ = constantes(m, a)
            print(f"   alpha={a:.2f}: m_SLOT={m:.3f} -> c_m={cm:.4f}  I={I:.0f} s  "
                  f"F={F/3600:.2f} h")


# ---------------------------------------------------------------------------------------
# PUNTO FIJO F = f(m) con m <= lambda*F  — la cota determinista AUTOCONSISTENTE.
#
# R-FIN-7: «un nodo MUST NOT reorganizar su cadena seleccionada por debajo de F segundos de
# slot; una punta que lo exigiera se IGNORA». Luego un bloque creado mas de F despues del
# cruce NO puede llegar a ser bloque de cadena en ese cruce: no es candidato a ancla. El
# menu esta contenido en los bloques creados en una ventana de ~F segundos:
#       m <= 1 + lambda*F
# y a la vez la pinza de steering pide  F >= I/(wk-1) = (c_m/g)^2/(alpha*lambda*(wk-1)).
# La condicion de consistencia  F >= F(m(F))  tiene solucion porque c_m^2 ~ 2 ln m: el lado
# derecho crece como ln F. El MENOR F que la cumple es el punto fijo.
def punto_fijo(alpha, lam=1.0, g=G_TECHO, wk=WK_TECHO, F0=3600.0, it=200):
    F = F0
    for _ in range(it):
        m = 1.0 + lam * F
        cm = c_interp(m)
        Fn = (cm / g) ** 2 / (alpha * lam * (wk - 1.0))
        if abs(Fn - F) < 1e-6:
            break
        F = Fn
    return F, 1.0 + lam * F, c_interp(1.0 + lam * F)


if __name__ == "__main__":
    print("\n--- (5) COTA DETERMINISTA AUTOCONSISTENTE: m <= 1 + lambda*F (R-FIN-7) ---")
    print(f"{'alpha':>7} {'F* (s)':>11} {'F* (h)':>9} {'m <= ':>10} {'c_m':>8} {'I* (h)':>9}")
    for a in (0.05, 0.10, 0.25, 0.33, 0.40):
        F, m, cm = punto_fijo(a)
        print(f"{a:>7.2f} {F:>11.0f} {F/3600:>9.2f} {m:>10.0f} {cm:>8.4f} "
              f"{F*(WK_TECHO-1)/3600:>9.2f}")
    print("   (peor alpha = el mas pequeno; a alpha=0 no hay steering y la cota no aplica)")


# ---------------------------------------------------------------------------------------
# EXTRAPOLACION DE LA UNICA FAMILIA QUE NO SATURA: las COPIAS (A1.3, salida_a1b_copias.txt).
# m crece como log2(C). El techo de C es `mergeset_size_limit = 180` (R-FIN-12, bps.rs:75-80).
COPIAS = {   # alpha=0,10, familia global de 8 estrategias, 12 semillas
    "blue_score": [(6, 3.187), (14, 3.694), (30, 4.278), (60, 4.806)],
    "slot":       [(6, 1.925), (14, 2.155), (30, 2.171), (60, 2.250)],
}


def ajuste_log2(pts):
    xs = [math.log2(c) for c, _ in pts]
    ys = [m for _, m in pts]
    n = len(xs)
    sx, sy = sum(xs), sum(ys)
    sxx = sum(x * x for x in xs)
    sxy = sum(x * y for x, y in zip(xs, ys))
    b = (n * sxy - sx * sy) / (n * sxx - sx * sx)
    return (sy - b * sx) / n, b


if __name__ == "__main__":
    print("\n--- (6) la familia que NO satura: copias. m ~ a + b log2(C), techo C = 180 ---")
    for nom, pts in COPIAS.items():
        a, b = ajuste_log2(pts)
        print(f"  ancla {nom:>10}:  m = {a:.3f} + {b:.3f}*log2(C)")
        for C in (60, 180, 1000, 10000):
            m = a + b * math.log2(C)
            cm, I, F, _ = constantes(m, 0.10)
            print(f"      C={C:>6} -> m={m:>6.3f}  c_m={cm:.4f}  I={I/3600:>5.2f} h  "
                  f"F={F/3600:>6.2f} h")
    print("  (F crece como ln log C: multiplicar las copias por 167 sube F un ~40 %.)")
