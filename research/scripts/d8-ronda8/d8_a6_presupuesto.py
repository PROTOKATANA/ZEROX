#!/usr/bin/env python3
"""
d8_a6_presupuesto.py — A6 · EL MARGEN ECONOMICO DEL LOOKAHEAD, RECALCULADO.

El diseno (`dag-poas-ancla-de-orden.md` §4.2) escribe:
    «Lookahead 3,89 h, margen 10,6x frente a A* (41,1 h ...) y 1,05x frente a un plotter
     hipotetico 10x mejor que la extrapolacion. Ese 1,05x es el numero delgado del diseno.»
Esos 3,89 h son `I + F` con las constantes VIEJAS (I = 2 490 s, F = 3,2 h). Las constantes
NUEVAS son `I = 4 200 s`, `F = 5,3 h` (D9-f). El lookahead es la suma: R-FIN-2 fija
`entropia_j` en `slot(I_j)` y la aplica desde `t_j = slot(I_j) + L` hasta `t_{j+1}`, luego el
granjero conoce su desafio entre `L` y `L + I` por adelantado.  **Lookahead = F + I.**

`A*` (punto de equilibrio del ploteo dirigido) de `dag-poas-ancla-de-finalidad.md` §1, tabla
de tres escenarios de precios SUPUESTOS. Se recalcula el margen para:
  (a) las constantes MEDIDAS del diseno (m = 2,548);
  (b) las constantes GARANTIZADAS por construccion (`m <= 1 + lambda*S_max[s]`), que es lo
      que queda si la medida de `m` resulta optimista — el unico respaldo del diseno.
Y se invierte: que `m` (y por tanto que `S_max`) admite el presupuesto.

Sin `alpha` no hay steering, luego `alpha` entra por `I = (c_m/g)^2/(alpha*lambda)`: el peor
caso es el `alpha` mas pequeno (epocas mas largas). Se usa `alpha = 0,10`, el mismo que D9-f.
"""
import math
import sys

sys.path.insert(0, "/home/katana/zeo/ZEROX/research/scripts/d9-ronda8c")
from r8c_steering import c_m                                             # noqa: E402

G = 0.036
WK = 1.22
LAM = 1.0
ALPHA = 0.10

CM = {m: c_m(m) for m in (2, 3, 4, 5, 6, 8, 11, 16, 21, 31, 51, 101, 151, 201)}


def c_interp_r(m):
    lo, hi = math.floor(m), math.ceil(m)
    if lo == hi:
        return CM[int(m)] if int(m) in CM else c_m(int(m))
    a = CM[lo] if lo in CM else c_m(lo)
    b = CM[hi] if hi in CM else c_m(hi)
    return a + (m - lo) * (b - a)


def m_de_cm(objetivo):
    lo, hi = 1.0, 20000.0
    for _ in range(60):
        mid = (lo + hi) / 2
        if c_interp_r(mid) < objetivo:
            lo = mid
        else:
            hi = mid
    return lo


def consts(m, alpha=ALPHA):
    cm = c_interp_r(m)
    I = (cm / G) ** 2 / (alpha * LAM)
    F = I / (WK - 1.0)
    return cm, I, F, (I + F) / 3600.0


AST = [("A · GPU 2 000 $/2 a/300 W · SSD 100 $/TiB/5 a", 63.0, 6.3),
       ("B · GPU 1 000 $/3 a/250 W · SSD 60 $/TiB/5 a (FAVORECE AL ATACANTE)", 41.0, 4.1),
       ("C · GPU 3 000 $/2 a/400 W · SSD 120 $/TiB/4 a", 69.0, 6.9)]

CASOS = [("m MEDIDA, gratis (D9-f slot)", 2.079),
         ("m MEDIDA, +retencion — LA DEL DISENO", 2.548),
         ("GARANTIA por construccion, S_max = 20 s  (m <= 21)", 21.0),
         ("GARANTIA por construccion, S_max = 30 s  (m <= 31)", 31.0),
         ("GARANTIA por construccion, S_max = 150 s (m <= 151)", 151.0)]

if __name__ == "__main__":
    print("=== A6 · margen economico del lookahead con las constantes NUEVAS ===")
    print(f"g <= {G}, W/kappa <= {WK}, lambda = {LAM}, alpha = {ALPHA} (el peor: epocas mas "
          f"largas). Lookahead = I + F.\n")
    print(f"{'caso':<52}{'m':>8}{'c_m':>8}{'I (h)':>8}{'F (h)':>8}{'look (h)':>10}")
    res = []
    for nom, m in CASOS:
        cm, I, F, L = consts(m)
        res.append((nom, m, L))
        print(f"{nom:<52}{m:>8.3f}{cm:>8.4f}{I/3600:>8.2f}{F/3600:>8.2f}{L:>10.2f}")

    print(f"\nComprobacion del numero del diseno (I = 2 490 s, F = 3,2 h): "
          f"lookahead = {(2490+3.2*3600)/3600:.2f} h ; 41,1/3,89 = {41.1/3.89:.2f}x ; "
          f"4,1/3,89 = {4.1/3.89:.3f}x  -> reproduce el «10,6x y 1,05x» de §4.2.")

    print("\n--- MARGEN = A* / lookahead.  < 1 = plotear dirigido con GPU sale MAS BARATO "
          "que comprar SSD ---")
    cab = f"{'caso':<52}" + "".join(f"{n.split(' ')[0]+' hoy':>9}{n.split(' ')[0]+' 10x':>9}"
                                    for n, _, _ in AST)
    print(cab)
    print("-" * len(cab))
    for nom, m, L in res:
        fila = "".join(f"{hoy/L:>9.2f}{dx/L:>9.2f}" for _, hoy, dx in AST)
        print(f"{nom:<52}{fila}")

    print("\n--- inversion: que lookahead admite el presupuesto, y que `m` (y `S_max`) lo da ---")
    print(f"{'exigencia':<44}{'look max (h)':>13}{'I (s)':>9}{'F (h)':>8}{'c_m max':>9}"
          f"{'m max':>9}{'S_max max (s)':>14}")
    for nom, hoy, dx in AST:
        for etiq, A in ((f"margen 1x frente a {nom.split(' ')[0]} HOY", hoy),
                        (f"margen 1x frente a {nom.split(' ')[0]} 10x", dx)):
            Lm = A * 3600.0
            I = Lm / (1 + 1 / (WK - 1))
            cm = G * math.sqrt(I * ALPHA * LAM)
            m = m_de_cm(cm)
            smax = (m - 1) / LAM
            print(f"{etiq:<44}{A:>13.2f}{I:>9.0f}{I/(WK-1)/3600:>8.2f}{cm:>9.4f}"
                  f"{m:>9.2f}{smax:>14.1f}")
    print("\n  `S_max max` sale de la propia garantia del diseno `m <= 1 + lambda*S_max[s]`:\n"
          "  es el S_max mas grande cuya GARANTIA cabe en el presupuesto economico.\n"
          "  R-FIN-1a exige S_max in [20, 150] s y R-FIN-7 pide 150 s para tolerar "
          "particiones con f >= 0,09.")
