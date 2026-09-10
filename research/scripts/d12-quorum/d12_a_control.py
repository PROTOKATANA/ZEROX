#!/usr/bin/env python3
"""
d12_a_control.py — PUNTO A. Control positivo con el instrumento del paper, y auditoria del
calculo de partida `research/scripts/rendimiento/verif_quorum_soluciones.py`.

Fuente: Keller y Bohme, HotPoW (research/fuentes/hotpow.txt).
  - Lema 1 (L318-323):  poa_{P_lambda,k}(t) = 1 - e^{-lambda t} * sum_{i=0}^{2k-1} (lambda t)^i / i!
  - Corolario 1 (L351): t_barra_{lambda,k} = k / lambda
  - Corolario 2 (L379): poa(t_barra) = 1 - e^{-k} sum_{i=0}^{2k-1} k^i/i!   <- independiente de lambda
  - Remark, validacion Bitcoin (L392-401): k=1, lambda=0,1 -> p = 0,2642 (empirico 0,2606)
  - Tabla A.1 (L1835-1843): k=1 -> 0,2642 ; 2 -> 0,1429 ; 16 -> 0,0003 ; 64 -> 1,2e-12 ; 256 -> 4e-45
    y cabecera de 72 / 112 / 672 / 2,6 k / 10 k bytes
  - Teorema 1 / Ec. (14) (L1690): f(k) = O(e^k / (4^k sqrt(k)))  -> tasa asintotica ln(e/4) = -0,3863

Tres instrumentos independientes para el mismo numero:
  (1) forma cerrada en precision arbitraria (mpmath, 60 digitos)
  (2) scipy.stats.poisson.sf
  (3) Monte Carlo del proceso de Poisson (>= 12 semillas), que es el proceso de la Def. 1
"""
import sys
import numpy as np
from mpmath import mp, mpf, exp as mexp, gammainc
from scipy.stats import poisson

mp.dps = 400


# ----------------------------------------------------------------------------- instrumento (1)
def poa_cerrada(k, lam, t):
    """Lema 1 del paper, en precision arbitraria. poa = P[Poisson(lam*t) >= 2k].

    Se evalua por la gamma incompleta regularizada, que es la forma que el propio paper usa en
    la demostracion del Teorema 1 (Ec. 5-6, L1660-1668: f(k) = P(2k,k) = gamma(2k,k)/(2k-1)!),
    y que no sufre la cancelacion catastrofica de la suma alterna para k grande.
    """
    x = mpf(lam) * mpf(t)
    return gammainc(2 * k, 0, x, regularized=True)


def poa_suma(k, lam, t):
    """La MISMA cantidad por la suma literal del Lema 1, para contrastar las dos vias."""
    x = mpf(lam) * mpf(t)
    s = mp.mpf(0)
    term = mp.mpf(1)  # x^0/0!
    for i in range(0, 2 * k):
        if i > 0:
            term = term * x / i
        s += term
    return 1 - mexp(-x) * s


def poa_corolario2(k):
    """Corolario 2: poa en el tiempo esperado de quorum, t = k/lambda."""
    return poa_cerrada(k, 1.0, k)


# ----------------------------------------------------------------------------- instrumento (3)
def poa_montecarlo(k, lam, semilla, n_trials):
    """Simula el proceso de Poisson de la Def. 1 y mide P[P(t_barra) >= 2k].

    No usa ninguna formula cerrada: genera tiempos entre ATV exponenciales y cuenta.
    Depende de k y de lam por construccion (criterio alpha: cambiar k cambia el resultado).
    """
    rng = np.random.default_rng(semilla)
    t_barra = k / lam
    # N(t) ~ contar cuantos ATV caen antes de t_barra: se generan 2k llegadas y se mira
    # si la 2k-esima cae antes de t_barra (equivalente: N(t_barra) >= 2k <=> T_{2k} <= t_barra)
    gaps = rng.exponential(1.0 / lam, size=(n_trials, 2 * k))
    t_2k = gaps.sum(axis=1)
    return float(np.mean(t_2k <= t_barra))


# ----------------------------------------------------------------------------- auditoria
sys.path.insert(0, "research/scripts/rendimiento")


def poisson_sf_de_katana(lam, n):
    """COPIA LITERAL de verif_quorum_soluciones.py:22-34, para auditarla sin importarla
    (el modulo original imprime al importarse)."""
    from math import exp, log, lgamma
    tot = 0.0
    k = n
    while True:
        lp = -lam + k * log(lam) - lgamma(k + 1)
        term = exp(lp)
        tot += term
        if k > lam and term < tot * 1e-17 and k > n + 10:
            break
        k += 1
        if k > lam * 40 + 2000:
            break
    return tot


def main():
    print("=" * 78)
    print("A.1 · CONTROL POSITIVO — reproducir numeros publicados de HotPoW")
    print("=" * 78)

    print("\n[A.1a] Validacion Bitcoin del paper (L392-397): k=1, lambda=0,1/min, t=k/lambda=10 min")
    v = poa_cerrada(1, 0.1, 10.0)
    print(f"      poa_cerrada(k=1, lam=0,1, t=10) = {float(v):.4f}   (paper: 0,2642)  "
          f"{'OK' if abs(float(v) - 0.2642) < 5e-5 else 'FALLA'}")
    v2 = poa_corolario2(1)
    print(f"      Corolario 2, k=1               = {float(v2):.4f}   (mismo numero)  "
          f"{'OK' if abs(float(v2) - float(v)) < 1e-14 else 'FALLA'}")
    vs_ = poa_suma(1, 0.1, 10.0)
    print(f"      contraste suma literal L1 vs gamma inc.: err rel = "
          f"{float(abs(vs_ - v) / v):.2e}  {'OK' if abs(float((vs_ - v) / v)) < 1e-12 else 'FALLA'}")

    print("\n[A.1b] Tabla A.1 del paper (L1835-1843) — POA en tiempo esperado de quorum")
    esperado = {1: "0.2642", 2: "0.1429", 16: "0.0003", 64: "1.2e-12", 256: "4e-45"}
    print(f"      {'k':>5} {'calculado':>16} {'paper':>12}  veredicto")
    for k in (1, 2, 16, 64, 256):
        c = poa_corolario2(k)
        # comparacion al numero de cifras que publica el paper
        if k in (1, 2):
            ok = f"{float(c):.4f}" == esperado[k]
        elif k == 16:
            ok = f"{float(c):.4f}" == esperado[k]
        elif k == 64:
            ok = abs(float(c) / 1.2e-12 - 1) < 0.11   # el paper trunca a 1,2
        else:
            ok = abs(float(c) / 4e-45 - 1) < 0.2
        print(f"      {k:>5} {float(c):>16.4e} {esperado[k]:>12}  {'OK' if ok else 'FALLA'}")

    print("\n[A.1c] Corolario 2: independencia de lambda. poa(k/lambda) para lambda muy distintos.")
    print(f"      {'k':>5} " + "".join(f"{('lam=' + str(l)):>22}" for l in (0.01, 0.1, 1.0, 10.0, 1000.0)))
    for k in (1, 16, 64):
        fila = []
        for lam in (0.01, 0.1, 1.0, 10.0, 1000.0):
            fila.append(float(poa_cerrada(k, lam, k / lam)))
        disp = (max(fila) - min(fila)) / max(fila)
        print(f"      {k:>5} " + "".join(f"{x:>22.12e}" for x in fila))
        print(f"            dispersion relativa max-min = {disp:.3e}  "
              f"{'OK (independiente de lambda)' if disp < 1e-12 else 'REVISAR'}")

    print("\n[A.1d] Tercer instrumento: Monte Carlo del proceso de Poisson (Def. 1), 12 semillas.")
    SEMILLAS = [11, 22, 33, 44, 55, 66, 77, 88, 99, 111, 222, 333]
    N_TRIALS = 400_000
    print(f"      {N_TRIALS} realizaciones por semilla, {len(SEMILLAS)} semillas.")
    print(f"      {'k':>4}{'lambda':>9}{'MC media':>14}{'MC IC95':>22}{'cerrada':>14}  veredicto")
    for k, lam in ((1, 0.1), (1, 1.0), (2, 1.0), (4, 1.0), (8, 1.0), (16, 1.0), (16, 0.1)):
        vals = [poa_montecarlo(k, lam, s, N_TRIALS) for s in SEMILLAS]
        m = float(np.mean(vals))
        sd = float(np.std(vals, ddof=1))
        ic = 1.96 * sd / np.sqrt(len(vals))
        c = float(poa_corolario2(k))
        ok = abs(m - c) <= max(ic, 3e-5) * 1.5 + 1e-6
        print(f"      {k:>4}{lam:>9.2f}{m:>14.6f}{('[%.6f, %.6f]' % (m - ic, m + ic)):>22}"
              f"{c:>14.6f}  {'OK' if ok else 'REVISAR'}")

    print("\n[A.1e] Criterio alpha del metodo: el resultado DEBE cambiar al cambiar k.")
    ks = [1, 2, 4, 8, 16, 32, 64]
    vs = [float(poa_corolario2(k)) for k in ks]
    print("      " + "  ".join(f"k={k}:{v:.3e}" for k, v in zip(ks, vs)))
    print(f"      monotono decreciente y no constante: "
          f"{'OK' if all(vs[i] > vs[i+1] for i in range(len(vs) - 1)) else 'FALLA'}")

    print("\n[A.1f] Tasa de decaimiento frente a la Ec. (14) del paper, ln(e/4) = -0,38629")
    import math
    print(f"      {'k':>6}{'ln poa(k)/k':>16}")
    for k in (16, 64, 256, 1024, 4096):
        lp = mp.log(poa_corolario2(k))
        print(f"      {k:>6}{float(mp.re(lp) / k):>16.5f}")
    print(f"      limite teorico ln(e/4) = {math.log(math.e / 4):.5f}  -> converge por arriba")

    print("\n" + "=" * 78)
    print("A.2 · AUDITORIA DE verif_quorum_soluciones.py")
    print("=" * 78)

    print("\n[A.2a] ¿Es correcta la lectura POA(k) = P[Poisson(k) >= 2k]?")
    print("      Lema 1 da poa(t) = 1 - e^{-lam t} sum_{i<2k} (lam t)^i/i! = P[Poisson(lam t) >= 2k].")
    print("      Corolario 1 da t_barra = k/lam, luego lam*t_barra = k. Sustituyendo: P[Poisson(k) >= 2k].")
    print("      -> LECTURA CORRECTA. Y es exactamente el Corolario 2 del paper (L379-382).")

    print("\n[A.2b] ¿Es correcta su rutina `poisson_sf`? Contraste con mpmath y scipy.")
    print(f"      {'k':>6}{'katana':>16}{'scipy.sf':>16}{'mpmath':>16}{'err rel katana':>17}")
    peor = 0.0
    for k in (16, 32, 64, 96, 128, 192, 256):
        a = poisson_sf_de_katana(float(k), 2 * k)
        b = float(poisson.sf(2 * k - 1, k))
        c = float(poa_corolario2(k))
        er = abs(a - c) / c if c > 0 else float("nan")
        peor = max(peor, er)
        print(f"      {k:>6}{a:>16.6e}{b:>16.6e}{c:>16.6e}{er:>17.2e}")
    print(f"      peor error relativo = {peor:.2e}  -> {'OK' if peor < 1e-9 else 'REVISAR'}")

    print("\n[A.2c] ¿Es correcta la extrapolacion a nuestro lambda = 1 solucion/s?")
    print("      Corolario 2 no depende de lambda, luego POA(k) es el mismo. CORRECTO.")
    print("      Lo que SI depende de lambda es el TIEMPO: t_barra = k/lambda = k segundos a lambda=1/s.")
    print("      La linea 'un k-quorum tarda ~k segundos' es correcta SOLO si la tasa de VOTOS es")
    print("      lambda_voto = 1/s. En HotPoW la tasa de votos es k*lambda_bloque (Sec. 2, L200-208:")
    print("      'HotPoW asks for k easier puzzles each expected to take 10/k minutes'), de modo que")
    print("      el quorum tarda UN intervalo de bloque, no k. Con lambda_voto = lambda_bloque = 1/s")
    print("      el quorum tarda k segundos Y CONSUME k BLOQUES. Es el punto B.")

    print("\n[A.2d] Bytes del certificado: `bls = 48 + (k+7)//8` (mapa de bits) — AUDITORIA")
    print("      Un mapa de bits solo comprime si existe un REGISTRO ordenado de firmantes contra el")
    print("      que indexar (en F3, la tabla de poder). HotPoW no tiene registro: sus votos son")
    print("      autoportantes y la clave publica del votante va DENTRO del voto. El propio paper lo")
    print("      tarifa asi (Tabla A.1): 72 B con k=1 y 112 B con k=2 -> 40 B POR VOTO ADICIONAL")
    print("      (32 B de clave publica + 8 B de solucion), sobre 32 B de referencia comun.")
    print(f"      {'k':>6}{'paper (B)':>12}{'32+40k':>12}")
    for k, b in ((1, 72), (2, 112), (16, 672), (64, 2600), (256, 10000)):
        print(f"      {k:>6}{b:>12}{32 + 40 * k:>12}")
    print("      -> el modelo 32+40k reproduce la tabla del paper. El mapa de bits NO es aplicable")
    print("         sin registro: es un ERROR del calculo de partida. Detalle y numeros en el punto F.")

    print("\n[A.2e] La afirmacion 'cae ~e^(-0,386k)' del script")
    print(f"      ln(e/4) = {math.log(math.e/4):.5f}. Es exactamente la tasa de la Ec. (14) del paper.")
    print("      -> CORRECTA (es cota asintotica; para k finito el decaimiento es algo mas rapido,")
    print("         ver A.1f: -0,428 a k=64).")


if __name__ == "__main__":
    main()
