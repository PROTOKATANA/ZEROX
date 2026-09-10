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

NOTA DE RENDIMIENTO: las rondas se simulan VECTORIZADAS con numpy (nada de bucles por voto).
La version anterior, con bucle Python por voto, daba los mismos numeros y tardaba ~50x mas;
se comprueba en C.1b que la vectorizada reproduce la DP exacta.
"""
import sys
from concurrent.futures import ProcessPoolExecutor

import numpy as np

SEMILLAS = [101, 202, 303, 404, 505, 606, 707, 808, 909, 1010, 1111, 1212]
N_NODOS_HONESTOS = 1000          # como el paper (hotpow.txt:830: "network of 1000 nodes")
N_MC_CONTROL = 30_000
N_MC_DELTA = 20_000
COBERTURA = {}


def _c(r, n=1):
    COBERTURA[r] = COBERTURA.get(r, 0) + n


# =============================================================================== C.1 · DP exacta
def censor_dp(alpha, k, nmax_factor=400, tol=1e-15):
    """Resuelve EXACTAMENTE la cadena de Markov del Apendice B de HotPoW.

    Estado (a, d, l). Todas las transiciones incrementan a+d en 1, asi que se barre por niveles
    n = a+d. En el nivel n todos los estados tienen a+d = n, luego:
        - l = T (el atacante tiene el voto menor)  ->  SUCCESS en cuanto n >= k
        - l = F                                     ->  FAIL en cuanto d >= k
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
    exito = 0.0
    fallo = 0.0
    n = 1
    # estado inicial (hotpow.txt:1897-1898): (1,0,T) con prob alpha, (0,1,F) con prob 1-alpha
    if n >= k:
        exito += alpha
    else:
        T[0] = alpha
    if 1 >= k:
        fallo += 1 - alpha
    else:
        F[1] = 1 - alpha

    nmax = int(nmax_factor * k / max(1e-9, 1 - alpha)) + 2000
    while n < nmax:
        if T.sum() + F.sum() < tol:
            _c("dp_corte_por_masa")
            break
        nT = np.zeros(k + 2)
        nF = np.zeros(k + 2)
        nT[: k + 1] += alpha * T[: k + 1]
        nF[1: k + 2] += ((1 - alpha) / (n + 1)) * T[0: k + 1]
        nT[1: k + 2] += ((1 - alpha) * n / (n + 1)) * T[0: k + 1]
        nF[1: k + 2] += (1 - alpha) * F[0: k + 1]
        nT[: k + 1] += (alpha / (n + 1)) * F[: k + 1]
        nF[: k + 1] += (alpha * n / (n + 1)) * F[: k + 1]
        n += 1
        if n >= k:
            exito += nT.sum()
            nT[:] = 0.0
        fallo += nF[k:].sum()
        nF[k:] = 0.0
        T, F = nT, nF
    _c("dp_resuelta")
    return exito, fallo, T.sum() + F.sum()


# ============================================ C.1b / C.2 · simulacion vectorizada con retardo
def _rondas_vectorizadas(rng, alpha, k, lam_v, delta, n_nodos, n_rondas):
    """Simula n_rondas formaciones de quorum SIN bucles por voto. Devuelve la cuota del atacante.

    Adversario del paper: ve todos los votos al instante y retiene los suyos.
    Honestos: un voto emitido en t es visible para los DEMAS honestos en t + delta; para su
    propio emisor, al instante.

    Criterio de exito (identico al Apendice B del paper): el atacante gana si llega antes el
    instante en que TIENE EL VOTO MENOR y hay >= k votos en total, que el instante en que ALGUN
    honesto ve k votos honestos.
    """
    exitos = 0
    # la ventana debe cubrir el cierre honesto (k votos honestos) MAS delta, o la ronda se
    # rechazaria y se volveria a sortear, lo que condicionaria la muestra. Se dimensiona de
    # entrada; el contador `ronda_ampliada` comprueba que casi nunca hace falta ampliar.
    M0 = max(int(3 * k / max(0.05, 1 - alpha) + 2.0 * delta * lam_v) + 32, 128)
    idxM = None
    for _ in range(n_rondas):
        M = M0
        while True:
            t = np.cumsum(rng.exponential(1.0 / lam_v, size=M))
            u = rng.random(M)
            att = rng.random(M) < alpha
            dueno = rng.integers(0, n_nodos, size=M)
            if idxM is None or len(idxM) != M:
                idxM = np.arange(M)

            hon = ~att
            h = t[hon]
            hd = dueno[hon]
            if len(h) < k:
                _c("ronda_ampliada")
                M *= 2
                continue

            # --- instante honesto
            if delta <= 0:
                t_hon = h[k - 1]
            else:
                if t[-1] < h[k - 1] + delta:      # la ventana debe cubrir el cierre honesto
                    _c("ronda_ampliada")
                    M *= 2
                    continue
                t_hon = h[k - 1] + delta
                nh = len(h)
                base = np.searchsorted(h, h - delta, side="right")     # H(t-delta) en t = h_j
                orden = np.argsort(hd, kind="stable")                  # (dueno, tiempo) creciente
                hd_ord = hd[orden]
                h_ord = h[orden]
                ini_dueno = np.searchsorted(hd_ord, hd_ord, side="left")
                pos_en_dueno = np.arange(nh) - ini_dueno
                # cuantos votos del MISMO dueno son <= h_j - delta, con una sola busqueda global:
                # clave = dueno*BIG + tiempo es globalmente creciente, luego searchsorted sobre
                # ella restringe la busqueda al bloque del dueno sin bucles.
                BIG = float(h_ord[-1] + delta + 1.0)
                clave = hd_ord * BIG + h_ord
                consulta = hd_ord * BIG + (h_ord - delta)
                cnt_ant = np.searchsorted(clave, consulta, side="right") - ini_dueno
                propios_ord = pos_en_dueno - cnt_ant + 1
                propios = np.empty(nh, dtype=np.int64)
                propios[orden] = propios_ord
                cand = np.flatnonzero(base + propios >= k)
                if len(cand):
                    t_hon = min(t_hon, h[cand[0]])

            # --- instante del atacante: primer i con (el minimo vigente es suyo) y (i+1 >= k)
            corr = np.minimum.accumulate(u)
            idx_rec = np.where(u <= corr, idxM, -1)
            ult_rec = np.maximum.accumulate(idx_rec)   # indice del minimo vigente
            ok_att = att[ult_rec] & (idxM + 1 >= k)
            i_att = int(np.argmax(ok_att)) if ok_att.any() else -1
            t_att = t[i_att] if i_att >= 0 else np.inf

            if t_att <= t_hon:
                exitos += 1
                _c("exito_atacante")
            else:
                _c("exito_honesto")
            break
    return exitos / n_rondas


def _tarea(args):
    alpha, k, lam_v, delta, semilla, n_rondas = args
    COBERTURA.clear()
    rng = np.random.default_rng(semilla)
    v = _rondas_vectorizadas(rng, alpha, k, lam_v, delta, N_NODOS_HONESTOS, n_rondas)
    return v, dict(COBERTURA)


def barrido(configs, n_rondas, workers=30):
    tareas = [(a, k, lv, d, s, n_rondas) for (a, k, lv, d) in configs for s in SEMILLAS]
    with ProcessPoolExecutor(max_workers=workers) as ex:
        res = list(ex.map(_tarea, tareas))
    salida, cob = {}, {}
    for (cfg, r) in zip([c for c in configs for _ in SEMILLAS], res):
        salida.setdefault(cfg, []).append(r[0])
        for kk, vv in r[1].items():
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
    print(f"{'k':>6}" + "".join(f"{('a=' + f'{a:.3f}'):>12}" for a in alphas) + f"{'masa sin absorber':>20}")
    for k in ks:
        fila, restos = [], []
        for a in alphas:
            e, f, r = censor_dp(a, k)
            fila.append(e / (e + f) if (e + f) > 0 else float("nan"))
            restos.append(r)
        print(f"{k:>6}" + "".join(f"{x:>12.4f}" for x in fila) + f"{max(restos):>20.2e}")
    print("\n-> comparese la columna a=0,333 con el 42 % del paper y la a=0,500 con el 64 %.")

    print("\n[C.1b] Cruce con Monte Carlo VECTORIZADO de la misma cadena, 12 semillas "
          f"x {N_MC_CONTROL} rondas (control del control).")
    cfgs = [(1 / 3, k, 1.0, 0.0) for k in (8, 32, 64, 128)] + [(1 / 2, 64, 1.0, 0.0), (1 / 10, 64, 1.0, 0.0)]
    sal, cob = barrido(cfgs, N_MC_CONTROL)
    print(f"      {'alpha':>7}{'k':>6}{'MC media':>12}{'IC95':>22}{'DP exacta':>12}{'|dif|/IC':>10}")
    for cfg in cfgs:
        a, k, lv, d = cfg
        vals = sal[cfg]
        m = float(np.mean(vals)); sd = float(np.std(vals, ddof=1)); ic = 1.96 * sd / np.sqrt(len(vals))
        e, f, r = censor_dp(a, k)
        ex = e / (e + f)
        print(f"      {a:>7.3f}{k:>6}{m:>12.4f}{('[%.4f, %.4f]' % (m - ic, m + ic)):>22}{ex:>12.4f}"
              f"{abs(m - ex) / ic:>10.2f}")
    print(f"      cobertura de rama MC: {cob}")

    print("\n" + "=" * 100)
    print("C.2 · EL MISMO ATAQUE CON RETARDO DE RED, en nuestro regimen (lambda = 1 bloque/s)")
    print("=" * 100)
    print(f"Variante 1: lambda_voto = 1/s (el voto ES el bloque). Variante 2: lambda_voto = k/s (HotPoW).")
    print(f"{N_MC_DELTA} rondas x 12 semillas por configuracion.\n")
    cfgs2 = []
    for a in (0.10, 0.25, 0.33, 0.40):
        for k in (32, 64, 128):
            for d in (0.0, 4.0, 8.0, 16.0):
                cfgs2.append((a, k, 1.0, d))
                cfgs2.append((a, k, float(k), d))
    sal2, cob2 = barrido(cfgs2, N_MC_DELTA)
    print(f"{'alpha':>7}{'k':>6}{'variante':>14}{'Delta':>7}{'cuota del atacante':>22}{'IC95':>22}")
    for cfg in cfgs2:
        a, k, lv, d = cfg
        vals = sal2[cfg]
        m = float(np.mean(vals)); sd = float(np.std(vals, ddof=1)); ic = 1.96 * sd / np.sqrt(len(vals))
        var = "1 (voto=bloq)" if lv == 1.0 else "2 (k*lambda)"
        print(f"{a:>7.2f}{k:>6}{var:>14}{d:>7.0f}{m:>22.4f}{('[%.4f, %.4f]' % (m - ic, m + ic)):>22}")
    print(f"\ncobertura de rama: {cob2}")
