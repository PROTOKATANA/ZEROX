#!/usr/bin/env python3
"""
d12_b_composicion.py — PUNTO B. La composicion con GHOSTDAG y el ancla, que el paper NO hace.

B.2 es la pregunta que decide: si el voto es el propio bloque, ¿en que se diferencia esto de la
profundidad de confirmacion que ya tenemos?

Tres mediciones:
  B.a  POA(k) frente al riesgo REAL de reversion del diseno vivo, a igualdad de espera.
       Criterio alpha: POA no depende de alpha. Se mide explicitamente.
  B.b  El atacante que ACUMULA votos para una referencia vieja. Tiempo hasta que puede forjar un
       certificado el solo: k/(alpha*lambda_v).
  B.c  El modelo correcto del gadget compuesto: ventana de voto W. Seguridad = P[el atacante solo
       llega a k]; viveza = P[los honestos llegan a k]. La region factible en (k, W) y lo que
       revela: hace falta conocer lambda y acotar alpha, o sea la tabla de poder implicita.

Fuentes: hotpow.txt (Lema 1, Cor. 1/2, §4.2.9, §5.2.1), dag-poas-ancla-de-orden.md (R-FIN-1..14),
rusty-kaspa @ c338d495 (virtual_processor/processor.rs:1013,1033).
"""
import sys
import numpy as np
from mpmath import mp, mpf, gammainc
from scipy.stats import poisson

mp.dps = 200
sys.path.insert(0, "research/scripts/d9-ronda9a")
from r9a_a3_frontera import prev  # noqa: E402  (Skellam del Lema 10, D8 d8_a1c_riesgo.py:29-40)

K_GD = 30           # k de GHOSTDAG
LAM = 1.0           # bloques/s (rama A'')
OFFSET = 3 * K_GD   # ventaja inicial 3k del Lema 10

COBERTURA = {}


def cuenta(rama):
    COBERTURA[rama] = COBERTURA.get(rama, 0) + 1


def poa(k):
    """POA en el tiempo esperado de quorum (Corolario 2). NO depende de alpha ni de lambda."""
    return float(gammainc(2 * k, 0, mpf(k), regularized=True))


def poa_en_t(k, lam_v, t):
    """POA(t) del Lema 1: P[Poisson(lam_v * t) >= 2k]. Crece con t."""
    return float(gammainc(2 * k, 0, mpf(lam_v) * mpf(t), regularized=True))


# ---------------------------------------------------------------------------------------- B.a
def bloque_a():
    print("=" * 96)
    print("B.a · POA frente al riesgo REAL, a igualdad de espera. ¿Anade informacion el gadget?")
    print("=" * 96)
    print("\nVariante 1 (voto = bloque): lambda_voto = lambda_bloque = 1/s, luego en t segundos hay")
    print("t votos y el mayor quorum posible es k = t. Se compara con prev() del diseno vivo.\n")
    print(f"{'espera t':>10}{'k = t':>8}" + "".join(f"{('riesgo alpha=' + f'{a:.2f}'):>22}" for a in (0.10, 0.25, 0.33, 0.40))
          + f"{'POA(k=t)':>14}")
    for t in (30, 60, 120, 300, 600, 1200, 1800, 3600):
        fila = []
        for a in (0.10, 0.25, 0.33, 0.40):
            fila.append(prev(a, LAM, float(t), OFFSET, 1.0))
            cuenta(f"prev_alpha_{a}")
        p = poa(int(t))
        cuenta("poa")
        print(f"{t:>10}{t:>8}" + "".join(f"{x:>22.3e}" for x in fila) + f"{p:>14.3e}")

    print("\n[B.a.1] CRITERIO ALPHA sobre POA — el resultado NO debe ser el mismo para todo alpha.")
    print("        POA(k) se evalua con alpha = 0,00 / 0,25 / 0,33 / 0,49 y k = 64:")
    for a in (0.00, 0.25, 0.33, 0.49):
        print(f"          alpha = {a:.2f} -> POA(64) = {poa(64):.6e}   (la funcion no recibe alpha)")
    print("        -> POA FALLA el criterio alpha del metodo. No es una cota de seguridad frente a")
    print("           un adversario: es P[mala realizacion] CONDICIONADA a excluir PoW-1 (lambda")
    print("           conocida) y PoW-2 (alpha acotada) por hipotesis (hotpow.txt:265-272).")

    print("\n[B.a.2] Y POA crece con el tiempo (Lema 1, Fig. 5 del paper): un certificado no es")
    print("        unico 'para siempre'. POA(k=64, t) con lambda_voto = 1/s:")
    print(f"        {'t (s)':>10}{'POA':>16}")
    for t in (64, 128, 256, 512, 1024, 2048, 4096):
        print(f"        {t:>10}{poa_en_t(64, 1.0, float(t)):>16.3e}")
    print("        A t = 4*t_barra la ambiguedad ya es practicamente 1. El paper evalua en t_barra")
    print("        'in order to isolate the effect of k' (hotpow.txt:374-377), NO como cota del")
    print("        protocolo desplegado.")


# ---------------------------------------------------------------------------------------- B.b
def bloque_b():
    print("\n" + "=" * 96)
    print("B.b · El atacante que ACUMULA votos para una referencia vieja")
    print("=" * 96)
    print("\nUn voto en HotPoW es (r, p, s) con H(r,p,s) <= t_v (hotpow.txt:437-441). Nada impide")
    print("seguir buscando soluciones para una r vieja: el atacante con fraccion alpha del espacio")
    print("produce votos para r a tasa alpha*lambda_v POR SIEMPRE. Tiempo hasta k votos propios:\n")
    print(f"{'k':>6}" + "".join(f"{('alpha=' + f'{a:.2f}'):>16}" for a in (0.10, 0.25, 0.33, 0.40))
          + "   (lambda_voto = 1/s)")
    for k in (16, 32, 64, 128, 256):
        fila = []
        for a in (0.10, 0.25, 0.33, 0.40):
            fila.append(k / (a * LAM))
            cuenta(f"acumula_alpha_{a}")
        print(f"{k:>6}" + "".join(f"{x:>16.0f} s" for x in fila))
    print("\n-> A alpha = 0,33 y k = 64 le bastan 194 s para tener un certificado propio, valido,")
    print("   para un valor en conflicto con el certificado honesto de la misma referencia.")
    print("   La unicidad del quorum NO la da la teoria de quorums: la da la regla de cabeza de")
    print("   HotPoW, que se niega a cambiar de estado ya comprometido (Listing 4.6, linea 41:")
    print("   'if H.parent.parent.parent.block = R.parent.parent.parent.block then head <- r').")
    print("   Es decir: HotPoW finaliza por PROFUNDIDAD + prohibicion de reorganizar, exactamente")
    print("   como R-FIN-7 (y como Kaspa: processor.rs:1013 'is_chain_ancestor_of(finality_point,")
    print("   candidate)' y :1033 'Finality Violation Detected ... is ignored from Virtual chain').")
    print("   El quorum aporta VARIANZA BAJA del tiempo de bloque, no seguridad extra.")


# ---------------------------------------------------------------------------------------- B.c
def bloque_c(delta_perdida=0.0):
    """Modelo correcto del gadget compuesto: ventana de voto finita.

    Un voto solo es valido para la referencia r si su slot cae en [slot(r), slot(r)+W). Entonces:
      - SEGURIDAD: el atacante solo no llega a k:      P[Poisson(alpha*lam_v*W) >= k] pequena
      - VIVEZA:    los honestos llegan a k:            P[Poisson((1-alpha)(1-d)*lam_v*W) >= k] alta
    Depende de alpha en los DOS sitios: criterio alpha cumplido por construccion.
    """
    print("\n" + "=" * 96)
    print(f"B.c · El modelo correcto: ventana de voto W. (perdida honesta por retardo d = {delta_perdida:.2f})")
    print("=" * 96)
    print("\nPara que un certificado sea unico hay que impedir la acumulacion de B.b: el voto lleva")
    print("slot y solo vale dentro de una ventana W (R-FIN-14 da el reto por slot). Entonces k tiene")
    print("que caber entre lo que el atacante puede producir y lo que los honestos producen:\n")
    print("     alpha*lam_v*W   <   k   <   (1-alpha)(1-d)*lam_v*W")
    print("\nque es una TABLA DE PODER IMPLICITA: hay que conocer lam_v (la da el retarget) y acotar")
    print("alpha (hipotesis PoW-2). La ventaja anunciada 'sin tabla de poder' NO existe.\n")

    print(f"{'alpha':>7}{'lam_v':>8}{'W (s)':>8}{'k':>7}{'P[atacante solo >= k]':>24}{'P[honestos < k]':>20}")
    filas = []
    for a in (0.10, 0.25, 0.33, 0.40):
        for lam_v in (1.0, 8.0, 64.0):
            for W in (30.0, 60.0, 300.0, 1800.0, 3600.0):
                mu_a = a * lam_v * W
                mu_h = (1 - a) * (1 - delta_perdida) * lam_v * W
                if mu_h <= mu_a:
                    cuenta("region_vacia")
                    continue
                # k optimo: el que iguala los dos riesgos en escala logaritmica
                mejor = None
                for k in range(1, int(mu_h * 1.5) + 2):
                    ps = float(poisson.sf(k - 1, mu_a))       # atacante llega a k
                    pl = float(poisson.cdf(k - 1, mu_h))      # honestos NO llegan a k
                    peor = max(ps, pl)
                    if mejor is None or peor < mejor[0]:
                        mejor = (peor, k, ps, pl)
                if mejor is None:
                    cuenta("sin_k")
                    continue
                cuenta("region_valida")
                _, k, ps, pl = mejor
                filas.append((a, lam_v, W, k, ps, pl))
                print(f"{a:>7.2f}{lam_v:>8.0f}{W:>8.0f}{k:>7}{ps:>24.3e}{pl:>20.3e}")
    return filas


def bloque_c_frontera(delta_perdida=0.0):
    """¿Cuanta ventana hace falta para que AMBOS riesgos bajen de un objetivo?"""
    print("\n[B.c.2] Ventana minima W para que max(P[atacante solo], P[honestos no llegan]) <= objetivo")
    print("        (lambda_voto = 1/s, es decir el voto es el bloque; y lambda_voto = 8/s y 64/s)")
    print(f"        {'alpha':>7}{'lam_v':>8}" + "".join(f"{('obj=' + o):>16}" for o in ("1e-6", "1e-12", "1e-30")))
    for a in (0.10, 0.25, 0.33, 0.40, 0.45):
        for lam_v in (1.0, 8.0, 64.0):
            fila = []
            for obj in (1e-6, 1e-12, 1e-30):
                Wmin = None
                lo, hi = 1.0, 4_000_000.0
                # busqueda por duplicacion + biseccion sobre W
                def peor(W):
                    mu_a = a * lam_v * W
                    mu_h = (1 - a) * (1 - delta_perdida) * lam_v * W
                    if mu_h <= mu_a:
                        return 1.0
                    m = 1.0
                    for k in range(1, int(mu_h * 1.5) + 2):
                        v = max(float(poisson.sf(k - 1, mu_a)), float(poisson.cdf(k - 1, mu_h)))
                        m = min(m, v)
                    return m
                W = 1.0
                while W < hi and peor(W) > obj:
                    W *= 1.6
                if W >= hi:
                    fila.append(float("inf"))
                    cuenta("W_no_alcanzable")
                else:
                    a_, b_ = W / 1.6, W
                    for _ in range(30):
                        m_ = (a_ + b_) / 2
                        if peor(m_) > obj:
                            a_ = m_
                        else:
                            b_ = m_
                    fila.append(b_)
                    cuenta("W_alcanzable")
            print(f"        {a:>7.2f}{lam_v:>8.0f}" + "".join(
                (f"{x:>14.0f} s" if np.isfinite(x) else f"{'—':>16}") for x in fila))


if __name__ == "__main__":
    bloque_a()
    bloque_b()
    bloque_c(0.0)
    bloque_c_frontera(0.0)
    print("\n[B.c.3] Lo mismo con perdida honesta por retardo d = 0,267 (delta_real del diseno, R-FIN-7)")
    bloque_c_frontera(0.267)
    print("\n" + "=" * 96)
    print("COBERTURA DE RAMA")
    print("=" * 96)
    for k_, v in sorted(COBERTURA.items()):
        print(f"  {k_:<28} {v}")
