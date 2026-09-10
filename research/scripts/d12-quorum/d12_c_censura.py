#!/usr/bin/env python3
"""
d12_c_censura.py — PUNTO C. El ataque de censura por retencion de votos, en nuestro regimen.

C.1  CONTROL POSITIVO: reproducir la Figura 11 de HotPoW con SU PROPIO modelo (Apendice B,
     hotpow.txt:1856-1927): cadena de Markov absorbente del censor. El paper reporta que con
     alpha = 1/3 el atacante se lleva ~42 % de los bloques y con alpha = 1/2, 64 %.
     Aqui se resuelve la cadena EXACTAMENTE por programacion dinamica (mejor que sus 10^6
     realizaciones) y ademas se cruza con Monte Carlo de 12 semillas.

C.2  El mismo ataque CON RETARDO DE RED, que el paper no modela en su MC (su Fig. 11 es sin
     retardo; el retardo solo aparece en la simulacion de red, Fig. 8). Se anade Delta y se
     mide la fraccion de certificados que controla el atacante en nuestro regimen:
     lambda = 1 bloque/s, Delta en {0, 4, 8, 16} s, y las dos variantes de tasa de voto:
        - variante 1: lambda_voto = lambda_bloque = 1/s   (el voto ES el bloque)
        - variante 2: lambda_voto = k * lambda_bloque      (la de HotPoW: k puzzles por bloque)

Adversario del paper, sin retardo: el atacante ve todo al instante y no paga Delta; los honestos si.
"""
import sys
from concurrent.futures import ProcessPoolExecutor

import numpy as np

SEMILLAS = [101, 202, 303, 404, 505, 606, 707, 808, 909, 1010, 1111, 1212]
N_NODOS_HONESTOS = 1000          # como el paper (hotpow.txt:830: "network of 1000 nodes")
COBERTURA = {}


# =============================================================================== C.1 · DP exacta
def censor_dp(alpha, k, nmax_factor=400, tol=1e-15):
    """Resuelve EXACTAMENTE la cadena de Markov del Apendice B de HotPoW.

    Estado (a, d, l). Todas las transiciones incrementan a+d en 1, asi que se puede barrer por
    niveles n = a+d. En el nivel n todos los estados tienen a+d = n, luego:
        - l = T (atacante tiene el voto menor)  ->  SUCCESS en cuanto n >= k
        - l = F                                  ->  FAIL en cuanto d >= k
    Se indexa por d (a = n - d).

    Transiciones (hotpow.txt:1899-1913), con n = a+d:
      de T[d]: -> T[d]   con alpha              (a+1)
               -> F[d+1] con (1-alpha)/(n+1)    (el defensor obtiene el liderazgo)
               -> T[d+1] con (1-alpha)*n/(n+1)
      de F[d]: -> F[d+1] con 1-alpha            (el defensor amplia)
               -> T[d]   con alpha/(n+1)        (el atacante obtiene el liderazgo)
               -> F[d]   con alpha*n/(n+1)      (a+1, sigue detras)
    """
    T = np.zeros(k + 2)
    F = np.zeros(k + 2)
    # estado inicial (hotpow.txt:1897-1898): (1,0,T) con prob alpha, (0,1,F) con prob 1-alpha
    exito = 0.0
    fallo = 0.0
    n = 1
    if n >= k:
        exito += alpha            # (1,0,T): a+d = 1 >= k
    else:
        T[0] = alpha
    if 1 >= k:
        fallo += 1 - alpha        # (0,1,F): d = 1 >= k
    else:
        F[1] = 1 - alpha

    nmax = int(nmax_factor * k / max(1e-9, 1 - alpha)) + 2000
    while n < nmax:
        masa = T.sum() + F.sum()
        if masa < tol:
            COBERTURA["dp_corte_por_masa"] = COBERTURA.get("dp_corte_por_masa", 0) + 1
            break
        nT = np.zeros(k + 2)
        nF = np.zeros(k + 2)
        # de T
        nT[: k + 1] += alpha * T[: k + 1]                                # (a+1, d, T)
        nF[1: k + 2] += ((1 - alpha) / (n + 1)) * T[0: k + 1]            # (a, d+1, F)
        nT[1: k + 2] += ((1 - alpha) * n / (n + 1)) * T[0: k + 1]        # (a, d+1, T)
        # de F
        nF[1: k + 2] += (1 - alpha) * F[0: k + 1]                        # (a, d+1, F)
        nT[: k + 1] += (alpha / (n + 1)) * F[: k + 1]                    # (a+1, d, T)
        nF[: k + 1] += (alpha * n / (n + 1)) * F[: k + 1]                # (a+1, d, F)
        n += 1
        # absorciones en el nivel n
        if n >= k:
            exito += nT.sum()
            nT[:] = 0.0
        fallo += nF[k:].sum()
        nF[k:] = 0.0
        T, F = nT, nF
    resto = T.sum() + F.sum()
    COBERTURA["dp_resuelta"] = COBERTURA.get("dp_resuelta", 0) + 1
    return exito, fallo, resto


# ================================================================= C.1b / C.2 · simulacion con Delta
def _ronda(rng, alpha, k, lam_v, delta, n_nodos):
    """Una formacion de quorum. Devuelve True si el atacante lidera (SUCCESS).

    Adversario del paper: ve todos los votos al instante y retiene los suyos.
    Honestos: un voto emitido en t es visible para los DEMAS honestos en t + delta; para su
    propio emisor, al instante.
    """
    # se generan votos en tandas hasta que la ronda termina
    t = 0.0
    tiempos, magn, es_att, duenos = [], [], [], []
    t_att = np.inf
    min_mag = np.inf
    min_es_att = False
    n_tot = 0
    # honestos visibles
    t_hon = np.inf
    while True:
        # tanda
        m = max(4 * k, 64)
        gaps = rng.exponential(1.0 / lam_v, size=m)
        ts = t + np.cumsum(gaps)
        t = ts[-1]
        us = rng.random(m)
        att = rng.random(m) < alpha
        dueno = rng.integers(0, n_nodos, size=m)
        for i in range(m):
            tiempos.append(ts[i]); magn.append(us[i]); es_att.append(att[i]); duenos.append(dueno[i])
            n_tot += 1
            if us[i] < min_mag:
                min_mag = us[i]
                min_es_att = bool(att[i])
            # ¿puede el atacante proponer? l ^ (a+d >= k)
            if t_att == np.inf and min_es_att and n_tot >= k:
                t_att = ts[i]
        # ¿cuando cierran los honestos?
        ta = np.array(tiempos); ma = np.array(es_att); du = np.array(duenos)
        hon_t = ta[~ma]
        hon_d = du[~ma]
        if len(hon_t) >= k:
            t_hon = _cierre_honesto(hon_t, hon_d, k, delta)
        if t_hon < np.inf or t_att < np.inf:
            # los dos candidatos ya estan acotados si la tanda cubre lo suficiente
            if t_hon < np.inf and t_att < np.inf:
                break
            if t_hon < np.inf and t > t_hon:
                break
            if t_att < np.inf and t > t_att + delta + 10.0 / lam_v and len(hon_t) >= k:
                break
        if n_tot > 400 * k + 10000:
            COBERTURA["ronda_truncada"] = COBERTURA.get("ronda_truncada", 0) + 1
            break
    if t_att <= t_hon:
        COBERTURA["exito_atacante"] = COBERTURA.get("exito_atacante", 0) + 1
        return True
    COBERTURA["exito_honesto"] = COBERTURA.get("exito_honesto", 0) + 1
    return False


def _cierre_honesto(hon_t, hon_d, k, delta):
    """Primer instante en que ALGUN honesto ve k votos honestos.

    Nodo j ve en t: los honestos emitidos <= t-delta, mas los SUYOS emitidos en (t-delta, t].
    """
    if delta <= 0:
        return hon_t[k - 1]
    n = len(hon_t)
    # candidatos: los instantes de emision (un nodo puede cerrar con su propio voto recien emitido)
    # y los instantes t_i + delta (cuando un voto ajeno se hace visible para todos).
    mejor = np.inf
    # (a) cierre por votos ya visibles para todos: H(t-delta) >= k  ->  t = hon_t[k-1] + delta
    mejor = min(mejor, hon_t[k - 1] + delta)
    # (b) cierre por un nodo que aporta sus propios votos recientes
    for i in range(n):
        t = hon_t[i]
        base = np.searchsorted(hon_t, t - delta, side="right")   # H(t-delta)
        if base >= k:
            mejor = min(mejor, t)
            break
        # votos propios en (t-delta, t] del dueno de i
        ini = base
        ventana_d = hon_d[ini: i + 1]
        if len(ventana_d) == 0:
            continue
        propios = np.count_nonzero(ventana_d == hon_d[i])
        if base + propios >= k:
            mejor = min(mejor, t)
            break
    return mejor


def _tarea(args):
    alpha, k, lam_v, delta, semilla, n_rondas = args
    rng = np.random.default_rng(semilla)
    COBERTURA.clear()
    exitos = sum(_ronda(rng, alpha, k, lam_v, delta, N_NODOS_HONESTOS) for _ in range(n_rondas))
    return exitos / n_rondas, dict(COBERTURA)


def barrido(configs, n_rondas):
    tareas = [(a, k, lv, d, s, n_rondas) for (a, k, lv, d) in configs for s in SEMILLAS]
    with ProcessPoolExecutor(max_workers=30) as ex:
        res = list(ex.map(_tarea, tareas))
    salida = {}
    cob = {}
    for (a, k, lv, d), i in zip([c for c in configs for _ in SEMILLAS], range(len(res))):
        salida.setdefault((a, k, lv, d), []).append(res[i][0])
        for kk, vv in res[i][1].items():
            cob[kk] = cob.get(kk, 0) + vv
    return salida, cob


if __name__ == "__main__":
    print("=" * 100)
    print("C.1 · CONTROL POSITIVO — Figura 11 de HotPoW (censor por retencion de votos), sin retardo")
    print("=" * 100)
    print("Modelo: Apendice B del paper (hotpow.txt:1856-1927), resuelto EXACTO por programacion")
    print("dinamica. El paper: alpha=1/3 -> ~42 % de los bloques; alpha=1/2 -> 64 % (hotpow.txt:963-967).\n")
    alphas = [1 / 50, 1 / 10, 1 / 5, 1 / 3, 1 / 2]
    ks = [1, 2, 4, 8, 16, 32, 64, 128, 256]
    print(f"{'k':>6}" + "".join(f"{('a=' + f'{a:.3f}'):>12}" for a in alphas) + f"{'masa sin absorber (peor)':>26}")
    for k in ks:
        fila, restos = [], []
        for a in alphas:
            e, f, r = censor_dp(a, k)
            fila.append(e / (e + f) if (e + f) > 0 else float("nan"))
            restos.append(r)
        print(f"{k:>6}" + "".join(f"{x:>12.4f}" for x in fila) + f"{max(restos):>26.2e}")
    print("\n-> comparese la columna a=0,333 con el 42 % del paper y la a=0,500 con el 64 %.")

    print("\n[C.1b] Cruce con Monte Carlo de la MISMA cadena, 12 semillas (control del control).")
    N_MC = 30_000
    cfgs = [(1 / 3, k, 1.0, 0.0) for k in (8, 32, 64, 128)] + [(1 / 2, 64, 1.0, 0.0), (1 / 10, 64, 1.0, 0.0)]
    sal, cob = barrido(cfgs, N_MC)
    print(f"      {'alpha':>7}{'k':>6}{'MC media':>12}{'IC95':>22}{'DP exacta':>12}")
    for (a, k, lv, d), vals in sorted(sal.items()):
        m = float(np.mean(vals)); sd = float(np.std(vals, ddof=1)); ic = 1.96 * sd / np.sqrt(len(vals))
        e, f, r = censor_dp(a, k)
        print(f"      {a:>7.3f}{k:>6}{m:>12.4f}{('[%.4f, %.4f]' % (m - ic, m + ic)):>22}{e/(e+f):>12.4f}")
    print(f"      cobertura de rama MC: {cob}")

    print("\n" + "=" * 100)
    print("C.2 · EL MISMO ATAQUE CON RETARDO DE RED, en nuestro regimen (lambda = 1 bloque/s)")
    print("=" * 100)
    print("Variante 1: lambda_voto = 1/s (el voto ES el bloque). Variante 2: lambda_voto = k/s (HotPoW).\n")
    N_MC2 = 20_000
    cfgs2 = []
    for a in (0.10, 0.25, 0.33, 0.40):
        for k in (32, 64, 128):
            for d in (0.0, 4.0, 8.0, 16.0):
                cfgs2.append((a, k, 1.0, d))          # variante 1
                cfgs2.append((a, k, float(k), d))     # variante 2
    sal2, cob2 = barrido(cfgs2, N_MC2)
    print(f"{'alpha':>7}{'k':>6}{'variante':>12}{'Delta':>7}{'cuota del atacante':>22}{'IC95':>22}")
    for (a, k, lv, d) in cfgs2:
        vals = sal2[(a, k, lv, d)]
        m = float(np.mean(vals)); sd = float(np.std(vals, ddof=1)); ic = 1.96 * sd / np.sqrt(len(vals))
        var = "1 (voto=bloq)" if lv == 1.0 else "2 (k*lambda)"
        print(f"{a:>7.2f}{k:>6}{var:>12}{d:>7.0f}{m:>22.4f}{('[%.4f, %.4f]' % (m - ic, m + ic)):>22}")
    print(f"\ncobertura de rama: {cob2}")
