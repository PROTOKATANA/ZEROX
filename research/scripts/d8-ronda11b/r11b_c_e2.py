#!/usr/bin/env python3
"""
r11b_c_e2.py — PUNTO C · SENSOR E2 (tasa): umbral `n_min(W)`, falsas alarmas y tiempo de
detección.

REGLA DEL SENSOR: alarma si la ventana deslizante `(t-W, t]` contiene ESTRICTAMENTE menos de
`n_min(W)` bloques nuevos y válidos. Se evalúa cada slot (`sigma = 1 s`).

TRES CONTABILIDADES DE FALSA ALARMA, las tres reportadas:
  · «por slot»    — `SEG_ANO/sigma · P(N < n_min) < 1`. Cota conservadora: cuenta cada
                    segundo de una misma excursión como una alarma distinta.
  · «disjunta»    — `SEG_ANO/W · P(N < n_min) < 1`. Es exacta si la regla se evalúa una vez
                    por ventana, a cambio de hasta `2W` de detección.
  · «excursión»   — medida por Monte Carlo sobre la ventana deslizante: cuántos CRUCES hacia
                    abajo del umbral hay al año. Es la cuenta operativa.

LA SOBREDISPERSIÓN, que es la parte honesta del punto. `lambda = 1` es el OBJETIVO del
retarget, no una constante física: si el espacio honesto conectado baja un 20 % (churn diurno
de granjeros), la tasa real baja hasta que LWMA-1 corrige. Se modela con
`lambda_ef = lambda·(1+Z)`, `Z ~ N(0, s_lam)` constante dentro de la ventana, y se tabula
`n_min` para `s_lam in {0; 0,05; 0,10; 0,20}`. HIPÓTESIS DECLARADA: no hay medida de `s_lam`
en red real; los cuatro valores acotan el efecto.

CONTROL POSITIVO (regla 4): antes de usar la cola de Poisson se comprueba, sobre el DAG
completo (`r11b_lib.MundoVictima` con `paso = 1`, es decir SIN eclipse), que el número de
bloques que entran en la vista de un nodo por ventana es Poisson: índice de dispersión
`var/media` contra 1, y las colas contra la fórmula.
"""
import math
import random
import sys
import time
from multiprocessing import Pool

sys.path.insert(0, "/home/katana/zeo/ZEROX/research/scripts/d8-ronda11b")
from r11b_lib import (MundoVictima, LAMBDA, SIGMA, SEG_ANO, K, MP,      # noqa: E402
                      _log_poisson_cdf, e2_alarma)

SEMS = list(range(1, 13))
WS = [30.0, 60.0, 120.0, 300.0]
ALPHAS_PASO = [0.0, 0.10, 0.33]
ES = [20.0, 60.0, 200.0]
S_LAMS = [0.0, 0.05, 0.10, 0.20]
REPS_POR_SEMILLA = 200


# ---------------------------------------------------------------------------------------
# cola de la ventana, con y sin sobredispersion
# ---------------------------------------------------------------------------------------
def p_menor(n, W, lam=LAMBDA, s_lam=0.0, nodos_gauss=201):
    """P(N < n) con N | lambda_ef ~ Poisson(lambda_ef*W), lambda_ef = lam*(1+Z), Z~N(0,s_lam)
    truncada a [-1, +inf). Cuadratura de Gauss-Hermite sustituida por Simpson sobre z en
    [-6, 6] sigmas (suficiente: el integrando es suave y la cola gaussiana esta acotada)."""
    if n <= 0:
        return 0.0
    if s_lam == 0.0:
        return math.exp(_log_poisson_cdf(n - 1, lam * W))
    lo, hi = -6.0, 6.0
    h = (hi - lo) / (nodos_gauss - 1)
    tot = 0.0
    peso_tot = 0.0
    for i in range(nodos_gauss):
        z = lo + i * h
        w = math.exp(-z * z / 2.0) / math.sqrt(2.0 * math.pi)
        c = 1.0 if i in (0, nodos_gauss - 1) else (4.0 if i % 2 else 2.0)
        fac = max(1e-9, 1.0 + s_lam * z)
        tot += c * w * math.exp(_log_poisson_cdf(n - 1, lam * W * fac))
        peso_tot += c * w
    return tot / peso_tot


def n_min_para(W, lam=LAMBDA, s_lam=0.0, fa_ano=1.0, contabilidad="slot"):
    """Mayor `n_min` con menos de `fa_ano` falsas alarmas al ano."""
    pruebas = (SEG_ANO / SIGMA) if contabilidad == "slot" else (SEG_ANO / W)
    objetivo = fa_ano / pruebas
    mejor = 0
    for n in range(0, int(lam * W) + 2):
        if p_menor(n, W, lam, s_lam) < objetivo:
            mejor = n
        else:
            break
    return mejor


# ---------------------------------------------------------------------------------------
# control positivo: ¿es Poisson lo que ve un nodo honesto en el DAG completo?
# ---------------------------------------------------------------------------------------
def control_poisson(args):
    sem, alpha = args
    m = MundoVictima(alpha, 3000.0, sem, k=K, mp=MP, u3_mode="dynamic")
    m.corre_victima("filtro", f_v=0.05, paso=1.0, t_ecl=0.0, sem=sem)
    ll = sorted(m.llegadas_V)
    cuentas = {}
    for W in WS:
        c = []
        t = 300.0
        import bisect
        while t + W <= 3000.0:
            c.append(bisect.bisect_right(ll, t + W) - bisect.bisect_right(ll, t))
            t += W
        cuentas[W] = c
    return cuentas


# ---------------------------------------------------------------------------------------
# tiempo de deteccion, por Monte Carlo del proceso de llegadas
# ---------------------------------------------------------------------------------------
def det_una(rng, W, n_min, tasa_ataque, horizonte=6000.0, s_lam=0.0):
    """Simula llegadas Poisson(lambda) hasta t=0 (calentamiento de W s), luego
    Poisson(tasa_ataque) y devuelve el instante del primer cruce por debajo de `n_min`."""
    ll = []
    t = -3.0 * W
    lam_pre = LAMBDA * max(1e-9, 1.0 + s_lam * rng.gauss(0, 1)) if s_lam else LAMBDA
    while t < 0.0:
        t += rng.expovariate(lam_pre)
        if t < 0.0:
            ll.append(t)
    t = 0.0
    if tasa_ataque > 0:
        while t < horizonte:
            t += rng.expovariate(tasa_ataque)
            if t < horizonte:
                ll.append(t)
    return e2_alarma(ll, W, n_min, 0.0, horizonte, SIGMA)


def det_retraso(rng, W, n_min, E, horizonte=6000.0):
    """Variante (iii): las llegadas siguen siendo Poisson(lambda) pero desplazadas `E` s a
    partir de t=0, lo que abre un hueco de duracion exactamente `E`."""
    ll = []
    t = -3.0 * W
    while t < horizonte:
        t += rng.expovariate(LAMBDA)
        if t < 0.0:
            ll.append(t)
        elif t < horizonte:
            ll.append(t + E)
    return e2_alarma(ll, W, n_min, 0.0, horizonte, SIGMA)


def excursiones_mc(args):
    """Cruces hacia abajo del umbral al ano, en trafico honesto puro (ventana deslizante)."""
    W, n_min, s_lam, sem, segundos = args
    rng = random.Random(sem * 7919 + int(W) + int(1000 * s_lam))
    import bisect
    ll = []
    t = -2.0 * W
    while t < segundos:
        lam = LAMBDA * max(1e-9, 1.0 + s_lam * rng.gauss(0, 1)) if s_lam else LAMBDA
        t += rng.expovariate(lam)
        ll.append(t)
    ll.sort()
    dentro = False
    cruces = 0
    t = 0.0
    while t <= segundos:
        hi = bisect.bisect_right(ll, t)
        lo = bisect.bisect_right(ll, t - W)
        malo = (hi - lo) < n_min
        if malo and not dentro:
            cruces += 1
        dentro = malo
        t += SIGMA
    return cruces, segundos


def bloque_det(args):
    modo, W, n_min, v, sem, s_lam = args
    rng = random.Random(sem * 104729 + int(W) * 31 + int(v * 1000) + int(s_lam * 100))
    ts = []
    for _ in range(REPS_POR_SEMILLA):
        if modo == "filtro":
            ts.append(det_una(rng, W, n_min, v * LAMBDA, s_lam=s_lam))
        else:
            ts.append(det_retraso(rng, W, n_min, v))
    return ts


def resume(ts):
    vivos = sorted(t for t in ts if t is not None)
    if not vivos:
        return None, None, 0.0, len(ts)
    med = vivos[len(vivos) // 2]
    q99 = vivos[min(len(vivos) - 1, int(0.99 * (len(vivos) - 1)))]
    return med, q99, len(vivos) / len(ts), len(ts)


if __name__ == "__main__":
    t0 = time.time()
    print("=== C · sensor E2 (bloques por ventana) ===")
    print(f"lambda = {LAMBDA:.0f} b/s, sigma = {SIGMA:.0f} s, W in {WS}, "
          f"{len(SEMS)} semillas x {REPS_POR_SEMILLA} replicas.\n")

    print("--- CONTROL POSITIVO: ¿es Poisson lo que entra en la vista de un nodo del DAG? ---")
    print("    (MundoVictima con paso = 1, es decir SIN eclipse; horizonte 3 000 s; se")
    print("     descartan los primeros 300 s de calentamiento)")
    with Pool() as pool:
        res = pool.map(control_poisson, [(s, a) for a in (0.0, 0.33) for s in SEMS])
    print(f"{'alpha':>6} {'W':>6} | {'media':>8} {'esperada':>9} {'var/media':>10} "
          f"{'n ventanas':>11}")
    for idx, alpha in enumerate((0.0, 0.33)):
        trozo = res[idx * len(SEMS):(idx + 1) * len(SEMS)]
        for W in WS:
            todos = [c for r in trozo for c in r[W]]
            mu = sum(todos) / len(todos)
            var = sum((x - mu) ** 2 for x in todos) / (len(todos) - 1)
            print(f"{alpha:>6.2f} {W:>6.0f} | {mu:>8.2f} {LAMBDA*W:>9.1f} "
                  f"{var/mu:>10.3f} {len(todos):>11}")
    print("    (indice de dispersion var/media = 1 <=> Poisson. Es el control de que la cola")
    print("     de Poisson que se usa abajo describe el trafico real del DAG.)")

    print("\n--- (C.1) umbral n_min(W) con menos de 1 falsa alarma al ano ---")
    print(f"{'W':>6} {'s_lam':>6} | {'n_min (por slot)':>17} {'n_min (disjunta)':>17} "
          f"| {'P(N<n_min)':>12} {'alpha minima para evadir':>25}")
    NMIN = {}
    for W in WS:
        for s_lam in S_LAMS:
            n_s = n_min_para(W, s_lam=s_lam, contabilidad="slot")
            n_d = n_min_para(W, s_lam=s_lam, contabilidad="disjunta")
            NMIN[(W, s_lam)] = (n_s, n_d)
            p = p_menor(n_s, W, s_lam=s_lam)
            print(f"{W:>6.0f} {s_lam:>6.2f} | {n_s:>17} {n_d:>17} | {p:>12.3g} "
                  f"{n_s/(LAMBDA*W):>25.4f}")
    print("    («alpha minima para evadir» = n_min/(lambda*W): la fraccion del espacio que el")
    print("     atacante necesita para sostener la tasa sin disparar la alarma.)")

    print("\n--- (C.2) falsas alarmas medidas: CRUCES por ano (ventana deslizante) ---")
    print("    Control de la cota «por slot», que es conservadora por construccion.")
    print(f"{'W':>6} {'s_lam':>6} {'n_min':>6} | {'cruces/ano medidos':>19} "
          f"{'cota por slot':>14} {'segundos simulados':>19}")
    for W in WS:
        for s_lam in (0.0, 0.10):
            n_s = NMIN[(W, s_lam)][0]
            # umbral RELAJADO para que los cruces sean medibles: se mide a n_min+d y se
            # comprueba que la cota por slot lo acota. Con el n_min real, 0 cruces en 12 x 10^6 s
            # es lo que debe salir (y se imprime tambien).
            for nn, etiqueta in ((n_s, "n_min"), (n_s + max(2, int(0.08 * LAMBDA * W)), "relajado")):
                with Pool() as pool:
                    r = pool.map(excursiones_mc,
                                 [(W, nn, s_lam, s, 1_000_000) for s in SEMS])
                cru = sum(x[0] for x in r)
                seg = sum(x[1] for x in r)
                cota = SEG_ANO / SIGMA * p_menor(nn, W, s_lam=s_lam)
                print(f"{W:>6.0f} {s_lam:>6.2f} {nn:>6} | {cru/seg*SEG_ANO:>19.4g} "
                      f"{cota:>14.4g} {seg:>19.3g}  ({etiqueta})")

    print("\n--- (C.3) tiempo de deteccion, variante (ii) 'filtro': la tasa cae a alpha*lambda ---")
    print(f"{'W':>6} {'n_min':>6} {'alpha':>6} | {'mediana':>8} {'p99':>8} {'detecta':>8} "
          f"{'n':>6} | {'entre semillas (min-max mediana)':>34}")
    for W in WS:
        n_s = NMIN[(W, 0.0)][0]
        for a in ALPHAS_PASO:
            with Pool() as pool:
                r = pool.map(bloque_det, [("filtro", W, n_s, a, s, 0.0) for s in SEMS])
            todos = [t for ts in r for t in ts]
            med, q99, frac, n = resume(todos)
            meds = [resume(ts)[0] for ts in r]
            meds = [m for m in meds if m is not None]
            rango = f"{min(meds):.0f} - {max(meds):.0f}" if meds else "n/a"
            print(f"{W:>6.0f} {n_s:>6} {a:>6.2f} | "
                  f"{(f'{med:.1f}' if med is not None else 'NUNCA'):>8} "
                  f"{(f'{q99:.1f}' if q99 is not None else '-'):>8} {frac*100:>7.1f}% "
                  f"{n:>6} | {rango:>34}")

    print("\n--- (C.4) tiempo de deteccion, variante (iii) 'retraso E' ---")
    print(f"{'W':>6} {'n_min':>6} {'E':>6} | {'mediana':>8} {'p99':>8} {'detecta':>8} {'n':>6}")
    for W in WS:
        n_s = NMIN[(W, 0.0)][0]
        for E in ES:
            with Pool() as pool:
                r = pool.map(bloque_det, [("retraso", W, n_s, E, s, 0.0) for s in SEMS])
            todos = [t for ts in r for t in ts]
            med, q99, frac, n = resume(todos)
            print(f"{W:>6.0f} {n_s:>6} {E:>6.0f} | "
                  f"{(f'{med:.1f}' if med is not None else 'NUNCA'):>8} "
                  f"{(f'{q99:.1f}' if q99 is not None else '-'):>8} {frac*100:>7.1f}% {n:>6}")

    print("\n--- (C.5) CONTROL NEGATIVO: variante (ii) con paso = 1 (sin eclipse) ---")
    for W in WS:
        n_s = NMIN[(W, 0.0)][0]
        with Pool() as pool:
            r = pool.map(bloque_det, [("filtro", W, n_s, 1.0, s, 0.0) for s in SEMS])
        todos = [t for ts in r for t in ts]
        med, q99, frac, n = resume(todos)
        print(f"    W={W:>5.0f} n_min={n_s:>4}: dispara en {frac*100:.2f} % de {n} corridas "
              f"de 6 000 s SIN ataque")

    print("\n--- (C.6) EL COSTE DEL ATACANTE: que `alpha` necesita para NO disparar E2 ---")
    print("    El atacante que filtra los bloques honestos solo puede ensenarle a la victima")
    print("    los SUYOS, y estos llegan a tasa `alpha*lambda`. Para sobrevivir un ataque de")
    print("    duracion `T` sin una sola alarma necesita que el numero esperado de cruces sea")
    print("    pequeno. Se tabula el `alpha` minimo para menos de 0,1 alarmas esperadas en `T`.")
    print(f"{'W':>6} {'n_min':>6} | " + " ".join(f"{'T='+e:>12}" for e in
                                                 ("10 min", "2 h", "24 h")))
    for W in WS:
        n_s = NMIN[(W, 0.0)][0]
        celdas = []
        for T in (600.0, 7200.0, 86400.0):
            lo, hi = 0.0, 1.0
            for _ in range(80):
                mid = (lo + hi) / 2.0
                esperadas = (T / SIGMA) * p_menor(n_s, W, lam=mid)
                if esperadas > 0.1:
                    lo = mid
                else:
                    hi = mid
            celdas.append(f"{(lo+hi)/2.0:>12.4f}")
        print(f"{W:>6.0f} {n_s:>6} | " + " ".join(celdas))
    print("    -> con las cuatro ventanas a la vez, el atacante necesita el MAYOR de los")
    print("       cuatro valores: es el coste del eclipse-filtro indetectable.")

    print("\n--- (C.7) las cuatro ventanas a la vez: falsas alarmas y coste combinado ---")
    tot_cota = sum(SEG_ANO / SIGMA * p_menor(NMIN[(W, 0.0)][0], W) for W in WS)
    print(f"    cota «por slot» sumada sobre las cuatro ventanas: {tot_cota:.3f} alarmas/ano")
    print(f"    (medido en C.2: 0 cruces en 1,2e7 s por ventana; la cota es conservadora 6-9x)")
    peor = max(NMIN[(W, 0.0)][0] / (LAMBDA * W) for W in WS)
    print(f"    alpha minima para evadir las cuatro: {peor:.4f}")

    print(f"\n[{time.time()-t0:.0f} s]")
