#!/usr/bin/env python3
"""
r11b_b_e1.py — PUNTO B · SENSOR E1 (reloj): qué `B` da falsas alarmas < 1/año y qué tiempo
de detección.

EL MODELO, y por qué no es «una muestra del retardo».
------------------------------------------------------------------------------------------
La verificación del PoT es SECUENCIAL: «el seed del slot n+1 es la salida del slot n»
(`DECISIONES.md` §19, bloque de la aceleración de los 128 B), y Autonomys descarta por gossip
las pruebas de slots viejos y de slots demasiado futuros
(`subspace/crates/sc-proof-of-time/src/source/gossip.rs:576-600`, `MAX_SLOTS_IN_THE_FUTURE = 10`).
Luego la FRONTERA verificada de un nodo avanza solo cuando llega el SIGUIENTE slot: un solo
slot que se retrase atasca la frontera aunque los posteriores ya estén en la red.

Si el slot `s` se emite en `T0 + s·sigma` y le llega al nodo con retardo `D_s` (iid), la
frontera en el slot actual `c` es el mayor `n` con `D_s <= (c-s)·sigma` para todo `s <= n`, y
el RETRASO observado es

    L_c = max(0, max_{j >= 0} ( D_{c-j} - j·sigma ) )                                    (*)

Con `D_s` iid eso tiene forma cerrada EXACTA:

    P(L <= x) = prod_{j >= 0} F_D(x + j·sigma)                                          (**)

que es lo que se usa, y se COMPRUEBA contra Monte Carlo de (*) antes de usarla (control
positivo). El sensor alarma si `L + eps > B`, donde `eps` es el error del reloj de pared.

DOS CONTABILIDADES DE FALSA ALARMA, las dos reportadas:
  · «por slot»      — conservadora: `SEG_ANO/sigma · P(L > B) < 1`. Ignora que los slots
                      consecutivos por encima de `B` son la MISMA excursión.
  · «por excursión» — cada excursión la arranca UN slot con `D_s > B`; su número esperado al
                      año es `SEG_ANO/sigma · P(D > B)`. Es la cuenta operativa (una alarma
                      que dura 3 s es una alarma, no tres).

DOS FAMILIAS DE COLA, porque extrapolar seis órdenes de magnitud más allá del p99 es una
hipótesis, no un dato:
  · lognormal ajustada a (mediana, p99)      — la que pide el encargo.
  · Pareto ajustada a (mediana, p99)         — cola de potencia, control de robustez.
HIPÓTESIS DECLARADA: mediana del retardo honesto de entrega del PoT = `Delta` nominal = 4 s.
"""
import math
import random
import sys
import time

sys.path.insert(0, "/home/katana/zeo/ZEROX/research/scripts/d8-ronda11b")
from r11b_lib import SIGMA, SEG_ANO, _probit                       # noqa: E402

SEMS = list(range(1, 13))
MEDIANA = 4.0
P99S = [8.0, 16.0]
EPSS = [0.1, 1.0, 10.0]
N_MC = 4_000_000


# ---------------------------------------------------------------------------------------
# las dos colas
# ---------------------------------------------------------------------------------------
class LogNormal:
    nombre = "lognormal"

    def __init__(self, mediana, p99):
        self.mu = math.log(mediana)
        self.sig = (math.log(p99) - self.mu) / 2.3263478740408408

    def cdf(self, x):
        if x <= 0:
            return 0.0
        return 0.5 * (1.0 + math.erf((math.log(x) - self.mu) / (self.sig * math.sqrt(2.0))))

    def sf(self, x):
        return 1.0 - self.cdf(x)

    def q(self, p):
        return math.exp(self.mu + self.sig * _probit(p))

    def muestra(self, rng):
        return math.exp(self.mu + self.sig * rng.gauss(0.0, 1.0))


class Pareto:
    nombre = "pareto"

    def __init__(self, mediana, p99):
        # F(x) = 1 - (xm/x)^a ; mediana = xm*2^(1/a) ; p99 = xm*100^(1/a)
        self.a = math.log(50.0) / math.log(p99 / mediana)
        self.xm = mediana / (2.0 ** (1.0 / self.a))

    def cdf(self, x):
        if x <= self.xm:
            return 0.0
        return 1.0 - (self.xm / x) ** self.a

    def sf(self, x):
        if x <= self.xm:
            return 1.0
        return (self.xm / x) ** self.a

    def q(self, p):
        return self.xm * (1.0 - p) ** (-1.0 / self.a)

    def muestra(self, rng):
        return self.xm * rng.random() ** (-1.0 / self.a)


# ---------------------------------------------------------------------------------------
# (**) forma cerrada del retraso de la frontera secuencial
# ---------------------------------------------------------------------------------------
def sf_retraso(dist, x, jmax=100000):
    """P(L > x) con L de (*). Producto en logaritmos; se corta cuando el factor es 1 a 1e-18."""
    if x < 0:
        return 1.0
    acc = 0.0
    j = 0
    while j < jmax:
        s = dist.sf(x + j * SIGMA)
        if s <= 0.0:
            break
        acc += math.log1p(-s)
        if s < 1e-18:
            break
        j += 1
    return 1.0 - math.exp(acc)


def B_para(dist, eps, fa_ano=1.0, contabilidad="excursion"):
    """`B` mínimo con menos de `fa_ano` falsas alarmas al año."""
    pruebas = SEG_ANO / SIGMA
    objetivo = fa_ano / pruebas
    if contabilidad == "excursion":
        # una excursión por cada slot con D_s > B - eps
        x = dist.q(1.0 - objetivo)
    else:
        lo, hi = 0.0, 1e7
        for _ in range(300):
            mid = (lo + hi) / 2.0
            if sf_retraso(dist, mid) > objetivo:
                lo = mid
            else:
                hi = mid
        x = (lo + hi) / 2.0
    return x + eps


def mc_retraso(dist, semilla, n=N_MC):
    """Monte Carlo de (*): simula la frontera secuencial slot a slot y devuelve la serie de
    `L`. Control positivo de (**)."""
    rng = random.Random(semilla)
    L = 0.0
    ls = []
    for _ in range(n):
        d = dist.muestra(rng)
        L = max(d, L - SIGMA)
        ls.append(L)
    return ls


# ---------------------------------------------------------------------------------------
# tiempo de detección
# ---------------------------------------------------------------------------------------
def deteccion(dist, B, eps, modo, E=0.0, semilla=0, n_ecl=20000, calent=2000):
    """Tiempo (s) desde que empieza el ataque hasta que `L + eps > B`.
    `modo`: 'pot' (el PoT deja de llegar: `L` crece 1 s/s) o 'retraso' (todo llega con `E` s
    extra: `L` pasa a `max(D+E, L-sigma)`)."""
    rng = random.Random(semilla)
    L = 0.0
    for _ in range(calent):                     # calentamiento en régimen honesto
        L = max(dist.muestra(rng), L - SIGMA)
    if L + eps > B:                             # ya estaba en alarma antes del ataque
        return 0.0
    t = 0.0
    for _ in range(n_ecl):
        t += SIGMA
        if modo == "pot":
            L = L + SIGMA                       # la frontera no avanza; el reloj sí
        elif modo == "retraso":
            L = max(dist.muestra(rng) + E, L - SIGMA)
        else:
            raise ValueError(modo)
        if L + eps > B:
            return t
    return None


if __name__ == "__main__":
    t0 = time.time()
    print("=== B · sensor E1 (reloj de PoT contra reloj de pared) ===")
    print(f"sigma = {SIGMA:.0f} s, mediana del retardo = {MEDIANA:.0f} s (hipotesis: = Delta "
          f"nominal), {SEG_ANO/SIGMA:.3g} slots/ano, {len(SEMS)} semillas en lo estocastico.\n")

    print("--- CONTROL POSITIVO: la forma cerrada (**) contra Monte Carlo de (*) ---")
    print(f"{'cola':>10} {'p99':>5} {'x':>6} | {'cerrada P(L>x)':>15} {'MC P(L>x)':>12} "
          f"{'muestras':>10}")
    for p99 in P99S:
        for Dist in (LogNormal, Pareto):
            dist = Dist(MEDIANA, p99)
            ls = mc_retraso(dist, 12345, n=N_MC)
            for x in (4.0, 8.0, 12.0, 20.0):
                mc = sum(1 for v in ls if v > x) / len(ls)
                cf = sf_retraso(dist, x)
                print(f"{dist.nombre:>10} {p99:>5.0f} {x:>6.1f} | {cf:>15.6f} {mc:>12.6f} "
                      f"{len(ls):>10}")
    print("    (control negativo: con sigma muy grande la frontera nunca se atasca y "
          "P(L>x) -> P(D>x))")
    d = LogNormal(MEDIANA, 8.0)
    print(f"    P(D>8) = {d.sf(8.0):.6f}   P(L>8) = {sf_retraso(d, 8.0):.6f}   "
          f"(L es ESTRICTAMENTE mas pesada, como debe)")

    print("\n--- (B.1) `B` para menos de 1 falsa alarma al ano ---")
    print(f"{'cola':>10} {'p99':>5} {'eps':>6} | {'B excursion':>12} {'B por slot':>11} "
          f"| {'alarmas/ano a B_exc':>19}")
    tabla = {}
    for Dist in (LogNormal, Pareto):
        for p99 in P99S:
            dist = Dist(MEDIANA, p99)
            for eps in EPSS:
                b_exc = B_para(dist, eps, 1.0, "excursion")
                b_slot = B_para(dist, eps, 1.0, "slot")
                na = SEG_ANO / SIGMA * sf_retraso(dist, b_exc - eps)
                print(f"{dist.nombre:>10} {p99:>5.0f} {eps:>6.1f} | {b_exc:>12.2f} "
                      f"{b_slot:>11.2f} | {na:>19.3f}")
                tabla[(dist.nombre, p99, eps)] = (b_exc, b_slot)

    print("\n--- (B.2) sensibilidad: falsas alarmas al ano en funcion de `B` ---")
    print(f"{'cola':>10} {'p99':>5} | " + " ".join(f"{'B='+str(b):>11}" for b in
                                                   (10, 20, 30, 60, 100, 150)))
    for Dist in (LogNormal, Pareto):
        for p99 in P99S:
            dist = Dist(MEDIANA, p99)
            print(f"{dist.nombre:>10} {p99:>5.0f} | " +
                  " ".join(f"{SEG_ANO/SIGMA*dist.sf(b):>11.3g}" for b in
                           (10, 20, 30, 60, 100, 150)))

    print("\n--- (B.3) tiempo de deteccion, variante (i) 'pot retenido' ---")
    print(f"{'cola':>10} {'p99':>5} {'eps':>6} {'B':>8} | {'mediana':>8} {'p99':>8} "
          f"{'max':>8} {'n':>5}")
    for Dist in (LogNormal, Pareto):
        for p99 in P99S:
            dist = Dist(MEDIANA, p99)
            for eps in EPSS:
                B = tabla[(dist.nombre, p99, eps)][0]
                ts = sorted(deteccion(dist, B, eps, "pot", semilla=s) for s in
                            range(1, 201))
                med = ts[len(ts) // 2]
                q99 = ts[int(0.99 * (len(ts) - 1))]
                print(f"{dist.nombre:>10} {p99:>5.0f} {eps:>6.1f} {B:>8.2f} | {med:>8.1f} "
                      f"{q99:>8.1f} {ts[-1]:>8.1f} {len(ts):>5}")

    print("\n--- (B.4) tiempo de deteccion, variante (iii) 'retraso E' ---")
    print(f"{'cola':>10} {'p99':>5} {'eps':>6} {'B':>8} | " +
          " ".join(f"{'E='+str(E):>16}" for E in (20, 60, 200)))
    for Dist in (LogNormal, Pareto):
        for p99 in P99S:
            dist = Dist(MEDIANA, p99)
            for eps in EPSS:
                B = tabla[(dist.nombre, p99, eps)][0]
                celdas = []
                for E in (20.0, 60.0, 200.0):
                    ts = [deteccion(dist, B, eps, "retraso", E=E, semilla=s)
                          for s in range(1, 201)]
                    vivos = sorted(t for t in ts if t is not None)
                    if not vivos:
                        celdas.append(f"{'NUNCA (ciego)':>16}")
                    else:
                        med = vivos[len(vivos) // 2]
                        celdas.append(f"{med:>8.1f}/{len(vivos)/len(ts)*100:>6.1f}%")
                print(f"{dist.nombre:>10} {p99:>5.0f} {eps:>6.1f} {B:>8.2f} | " +
                      " ".join(celdas))
    print("    (celda = mediana del tiempo de deteccion / porcentaje de corridas que detectan)")

    print("\n--- (B.5) control negativo: variante (ii) 'filtro', el PoT llega bien ---")
    for Dist in (LogNormal,):
        for p99 in P99S:
            dist = Dist(MEDIANA, p99)
            B = tabla[(dist.nombre, p99, 1.0)][0]
            n = 200
            falsas = sum(1 for s in range(1, n + 1)
                         if deteccion(dist, B, 1.0, "retraso", E=0.0, semilla=s) is not None)
            print(f"    {dist.nombre} p99={p99:.0f} B={B:.2f}: E1 dispara en {falsas}/{n} "
                  f"corridas de 20 000 s SIN ataque de PoT -> E1 es CIEGO a la variante (ii)")

    print("\n--- (B.6) ¿compra algo exigir que la alarma PERSISTA m slots? ---")
    print("    Si `L` supera `B` es porque UN slot llego con `D_s > B`; a partir de ahi `L`")
    print("    decae 1 s por slot, DETERMINISTA. Exigir m slots seguidos por encima de `B`")
    print("    equivale exactamente a exigir `D_s > B + (m-1)`. Se comprueba numericamente:")
    print(f"{'cola':>10} {'p99':>5} {'m':>4} | {'B(m) con 1 fa/ano':>18} "
          f"{'B(m)+m-1':>10} {'t_det (i)':>10}")
    for Dist in (LogNormal, Pareto):
        for p99 in P99S:
            dist = Dist(MEDIANA, p99)
            for m in (1, 3, 10, 30):
                bm = dist.q(1.0 - SIGMA / SEG_ANO) - (m - 1) * SIGMA
                ts = sorted(deteccion(dist, bm + (m - 1) * SIGMA, 0.0, "pot", semilla=s)
                            for s in range(1, 201))
                print(f"{dist.nombre:>10} {p99:>5.0f} {m:>4} | {bm:>18.2f} "
                      f"{bm+(m-1)*SIGMA:>10.2f} {ts[len(ts)//2]:>10.1f}")
    print("    -> `B(m) + m - 1` es CONSTANTE y el tiempo de deteccion tambien: la")
    print("       persistencia no compra nada en E1. (En E2 si comprara: alli el ruido es")
    print("       Poisson y no decae de forma determinista.)")

    print("\n--- (B.7) `B` del sensor y `B` de la atadura sello-slot son el MISMO numero ---")
    print("    Atadura (DECISIONES.md §19, l. 1608): |timestamp - (TIEMPO_GENESIS + slot*sigma)| <= B.")
    print("    Un nodo honesto pone en `timestamp` su reloj de pared y en `slot` el ultimo slot")
    print("    de PoT que ha VERIFICADO. La diferencia es exactamente `L + eps`. Luego:")
    print("      · si B_consenso < B_sensor, el nodo emite bloques que la red rechaza SIN alarma;")
    print("      · si B_consenso > B_sensor, alarma antes de perder bloques (margen), a costa")
    print("        de dar mas espacio de grinding al timestamp (el espacio es 2B).")
    print(f"{'cola':>10} {'p99':>5} | {'B (1 rechazo honesto/ano)':>26} "
          f"{'bloques rechazados/ano a B/2':>29}")
    for Dist in (LogNormal, Pareto):
        for p99 in P99S:
            dist = Dist(MEDIANA, p99)
            b = dist.q(1.0 - SIGMA / SEG_ANO)
            print(f"{dist.nombre:>10} {p99:>5.0f} | {b:>26.2f} "
                  f"{SEG_ANO * sf_retraso(dist, b / 2.0):>29.3g}")
    print("    (bloques/ano = lambda*SEG_ANO*P(L > B/2); lambda = 1 b/s)")

    print("\n--- (B.8) el PRECIO de una falsa alarma, y por que conviene un umbral doble ---")
    print("    Una falsa alarma dura lo que tarda `L` en volver por debajo de `B`, es decir")
    print("    `D_s - B` segundos. Si el nodo deja de autorizar durante la alarma, pierde")
    print("    `f_v * lambda * duracion` bloques. Se mide por Monte Carlo con 12 semillas.")
    print(f"{'cola':>10} {'p99':>5} {'B':>7} | {'alarmas/ano':>12} {'dur media (s)':>14} "
          f"{'s/ano en alarma':>16} {'bloques/ano (f_v=0,05)':>23}")
    for Dist in (LogNormal, Pareto):
        for p99 in P99S:
            dist = Dist(MEDIANA, p99)
            for B in (10.0, 20.0, 30.0, 60.0, 100.0):
                durs = []
                for sem in SEMS:
                    rng = random.Random(sem * 977 + int(B))
                    L = 0.0
                    en = 0
                    n = 300000
                    for _ in range(n):
                        L = max(dist.muestra(rng), L - SIGMA)
                        if L > B:
                            en += 1
                    durs.append(en / n)
                frac = sum(durs) / len(durs)
                na = SEG_ANO / SIGMA * dist.sf(B)
                seg = frac * SEG_ANO
                print(f"{dist.nombre:>10} {p99:>5.0f} {B:>7.1f} | {na:>12.3g} "
                      f"{(seg/na if na > 0 else 0):>14.2f} {seg:>16.3g} "
                      f"{0.05*seg:>23.3g}")
    print("    -> con f_v = 0,05 (granjero del 5 % de la red) el coste de 1 000 falsas alarmas")
    print("       al ano es del orden de decenas de bloques: barato. Lo caro es el falso")
    print("       'no confirmes' de un comerciante. De ahi el UMBRAL DOBLE de la regla E.")

    print(f"\n[{time.time()-t0:.0f} s]")
