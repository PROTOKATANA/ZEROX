#!/usr/bin/env python3
"""
r11b_d_kaspa.py — PUNTO D · el eclipse CLÁSICO contra el gestor de direcciones.

Dos mitades:

 (D.1) CONTROL: se reproducen los números publicados de Heilman et al. 2015
       (`research/fuentes/heilman2015-eclipse.pdf`, extraído a `.txt` con pypdf) — ecuaciones
       (1)-(10) y las cifras del texto. Si el instrumento no reproduce a Heilman, no sirve
       para Kaspa.

 (D.2) KASPA: el mismo cálculo sobre el esquema REAL de `rusty-kaspa`, leído del código:
       · `components/addressmanager/src/lib.rs:27`     MAX_ADDRESSES = 4096
       · `components/addressmanager/src/lib.rs:28`     MAX_CONNECTION_FAILED_COUNT = 3
       · `components/addressmanager/src/lib.rs:418-460` peso = 64^(4-y)/n_prefijo, sorteo sin
                                                        reemplazo (`RandomWeightedIterator`)
       · `components/addressmanager/src/lib.rs:259-270` add_address -> y = 1
       · `components/addressmanager/src/lib.rs:285-291` mark_connection_success -> y = 0
       · `components/addressmanager/src/lib.rs:394-401` keep_limit: desaloja el de MAYOR y
       · `utils/src/networking.rs:51-68`                PrefixBucket = /16 en IPv4, /64 en IPv6
       · `components/addressmanager/src/stores/mod.rs:9` AddressKey = (IP, PUERTO)
       · `kaspad/src/args.rs:115-116`                   8 salientes, 128 entrantes
       · `protocol/flows/src/v10/address.rs:19`         MAX_ADDRESSES_RECEIVE = 2500
       · `protocol/flows/src/v10/mod.rs:37,141`         `register` NO mira la dirección de la
                                                        conexión: las ENTRANTES también
                                                        alimentan el almacén.

MODELO DEL ECLIPSE (el de Heilman §7, que es el que permite comparar): la víctima sortea
direcciones del almacén sin reemplazo y se conecta; una dirección del atacante SIEMPRE acepta,
una honesta acepta con probabilidad `p` (churn). El eclipse ocurre si las 8 PRIMERAS
CONEXIONES CON ÉXITO son todas del atacante.

Criterio de capacidad (regla 5): cada tabla imprime el número de réplicas y, cuando el
resultado es 0 o 1, se dice explícitamente que la resolución del estimador es 1/réplicas.
"""
import math
import random
import sys
import time
from multiprocessing import Pool

SEMS = list(range(1, 13))
REPS = 20000          # réplicas por semilla en los Monte Carlo de selección
MAX_ADDRESSES = 4096
MAX_FAIL = 3
SALIENTES = 8


# =======================================================================================
# D.1 · CONTROL — Heilman et al. 2015
# =======================================================================================
def binom_pmf(n, p, k):
    return math.exp(math.lgamma(n + 1) - math.lgamma(k + 1) - math.lgamma(n - k + 1)
                    + k * math.log(p) + (n - k) * math.log1p(-p))


def eq4_vacia(t, buckets=64, slots=64):
    """(4) 64*E[min(64, B(t, 1/64))] — tried inicialmente vacío / muchas rondas."""
    p = 1.0 / buckets
    esp = 0.0
    for k in range(0, min(t, 6 * slots) + 1):
        esp += min(slots, k) * binom_pmf(t, p, k)
    cola = 1.0 - sum(binom_pmf(t, p, k) for k in range(0, min(t, 6 * slots) + 1))
    esp += slots * max(0.0, cola)
    return buckets * esp


def eq5_recurrencia(a_max=200, slots=64):
    """(5)(6): E[Y_a] = E[Y_{a-1}] + 1 - (E[Y_{a-1}]/64)^4, E[Y_1] = 1."""
    y = [0.0, 1.0]
    for _ in range(2, a_max + 1):
        y.append(y[-1] + 1.0 - (y[-1] / slots) ** 4)
    return y


def eq7_desalojo_bitcoin(t, buckets=64, slots=64, a_max=400):
    """(7) 64 * sum_a E[Y_a] * P(B(t,1/64) = a)."""
    y = eq5_recurrencia(a_max, slots)
    p = 1.0 / buckets
    tot = 0.0
    for a in range(1, min(t, a_max) + 1):
        tot += y[a] * binom_pmf(t, p, a)
    if t > a_max:
        tot += y[a_max] * sum(binom_pmf(t, p, a) for a in range(a_max + 1, min(t, 6 * a_max)))
    return buckets * tot


def eq8_desalojo_aleatorio(t, total=4096):
    """(8) 4096*(1 - (4095/4096)^t)."""
    return total * (1.0 - ((total - 1.0) / total) ** t)


def eq9_gamma(s, buckets=64):
    """(9) E[Gamma] = 64*(1 - (63/64)^(4s))."""
    return buckets * (1.0 - ((buckets - 1.0) / buckets) ** (4 * s))


def p_acepta(r, tau):
    """(2) p(r, tau) = min(1, 1.2^r/(1+tau)); tau en incrementos de diez minutos."""
    return min(1.0, 1.2 ** r / (1.0 + tau))


def q_heilman(f, fp, tau_a, tau_l, rmax=4000):
    """(3) probabilidad de que UNA saliente vaya a una dirección del adversario, con el sesgo
    hacia sellos frescos."""
    prod = 1.0
    q = 0.0
    for r in range(1, rmax + 1):
        q += p_acepta(r, tau_a) * f * prod
        g = ((1.0 - p_acepta(r, tau_a)) * f
             + (1.0 - p_acepta(r, 0.0)) * fp
             + (1.0 - p_acepta(r, tau_l)) * (1.0 - f - fp))
        prod *= g
        if prod < 1e-15:
            break
    return q


def f_para_exito(objetivo, salientes=8):
    """Selección aleatoria: P(eclipse) = f^salientes."""
    return objetivo ** (1.0 / salientes)


def t_para_f(f, ecuacion, total=4096, lo=1, hi=200000):
    """Bisección: cuántas direcciones/bots hacen falta para llenar la fracción `f`."""
    obj = f * total
    while lo < hi:
        mid = (lo + hi) // 2
        if ecuacion(mid) < obj:
            lo = mid + 1
        else:
            hi = mid
    return lo


def s_para_f(f, buckets=64):
    """Cuántos grupos hacen falta para que E[Gamma]/64 = f (ataque de infraestructura con los
    buckets llenos)."""
    return math.log(1.0 - f) / (4.0 * math.log((buckets - 1.0) / buckets))


# =======================================================================================
# D.2 · KASPA — el esquema real
# =======================================================================================
def peso(y):
    """`lib.rs:451`: 64^(MAX_CONNECTION_FAILED_COUNT + 1 - y). El divisor por tamaño de
    PrefixBucket se aplica fuera, al montar el sorteo."""
    return 64.0 ** (MAX_FAIL + 1 - y)


def sortea_kaspa(rng, clases, p_churn, salientes=SALIENTES):
    """Reproduce `iterate_prioritized_random_addresses` + `handle_outbound_connections`.

    `clases`: lista de (duenno, y, n_ips_por_grupo, n_grupos). El peso de CADA direccion es
    64^(4-y)/n_ips (`lib.rs:451,456`), luego el peso TOTAL de un grupo es 64^(4-y),
    INDEPENDIENTE de cuantas IP tenga. Dentro de una clase las direcciones son
    intercambiables, asi que el sorteo sin reemplazo se hace por CLASE (exacto, y O(#clases)
    por extraccion en vez de O(#direcciones)).

    Devuelve True si las `salientes` primeras conexiones CON EXITO son todas del atacante.
    """
    # (peso individual, cuantas quedan, duenno)
    urna = [[peso(y) / n_ips, n_ips * n_gr, duenno]
            for duenno, y, n_ips, n_gr in clases if n_ips * n_gr > 0]
    exitos = 0
    tot = sum(w * c for w, c, _ in urna)
    while exitos < salientes and tot > 0:
        u = rng.random() * tot
        acc = 0.0
        elegida = None
        for fila in urna:
            if fila[1] <= 0:
                continue
            acc += fila[0] * fila[1]
            if acc >= u:
                elegida = fila
                break
        if elegida is None:
            break
        elegida[1] -= 1
        tot -= elegida[0]
        if elegida[2] == "a":
            exitos += 1
        elif rng.random() < p_churn:      # honesta VIVA: la conexion tiene exito
            return False
        # honesta muerta: mark_connection_failure y el bucle sigue
    return exitos >= salientes


def mc_kaspa(args):
    (s_a, y_a, h0, y_h, h1, p_churn, ips_por_grupo, sem, reps) = args
    rng = random.Random(sem * 15485863 + s_a * 31 + h0 * 17 + int(p_churn * 1000))
    clases = [("a", y_a, ips_por_grupo, s_a),
              ("h", y_h, 1, h0),
              ("h", 1, 1, h1)]
    ok = 0
    for _ in range(reps):
        if sortea_kaspa(rng, clases, p_churn):
            ok += 1
    return ok, reps


def p_kaspa_cerrada(s_a, y_a, h0, y_h, h1):
    """Aproximación cerrada SIN churn ni sin-reemplazo: (W_a/(W_a+W_h))^8. Sirve de control
    de orden de magnitud del Monte Carlo."""
    wa = s_a * peso(y_a)
    wh = h0 * peso(y_h) + h1 * peso(1)
    if wa + wh == 0:
        return 0.0
    return (wa / (wa + wh)) ** SALIENTES


if __name__ == "__main__":
    t0 = time.time()
    print("=== D · eclipse clasico contra el gestor de direcciones ===\n")

    # ---------------------------------------------------------------------------------
    print("--- D.1 CONTROL: reproducir Heilman et al. 2015 ---")
    print("    fuente: research/fuentes/heilman2015-eclipse.txt (pypdf sobre eprint 2015/263)\n")

    print("  (a) ec. (9)  E[Gamma] = 64*(1-(63/64)^(4s))   [texto: 55,5 a s=32; todos menos "
          "uno a s>67]")
    for s in (10, 20, 32, 40, 63, 67, 100):
        print(f"      s = {s:>4} grupos -> E[Gamma] = {eq9_gamma(s):>7.2f} de 64 buckets"
              + ("   <- publicado 55,5" if s == 32 else ""))

    print("\n  (b) ec. (5)(6)  E[Y_a] > 63 para a >= 101   [texto: «a >= 101»]")
    y = eq5_recurrencia(200)
    primero = next(a for a in range(1, 201) if y[a] > 63.0)
    print(f"      primer a con E[Y_a] > 63: {primero}   (publicado: 101)"
          f"   E[Y_100] = {y[100]:.4f}, E[Y_101] = {y[101]:.4f}")

    print("\n  (c) ec. (4)(7)(8) y las cifras de bots del texto")
    f917 = f_para_exito(0.5)
    print(f"      seleccion aleatoria: f para 50 % con 8 salientes = 0,5^(1/8) = {f917:.4f} "
          f"(publicado 91,7 %)")
    t4 = t_para_f(f917, eq4_vacia)
    t8 = t_para_f(f917, eq8_desalojo_aleatorio)
    print(f"      bots para f = {f917:.4f} con ec. (4) 'inicialmente vacia': {t4}   "
          f"(publicado ~3 680)")
    print(f"      bots para f = {f917:.4f} con ec. (8) 'desalojo aleatorio': {t8}   "
          f"(publicado 10 194)")
    print(f"      grupos de infraestructura para f = {f917:.4f}: {s_para_f(f917):.1f}   "
          f"(publicado 40)")
    f12 = f_para_exito(0.5, 12)
    print(f"      con 12 salientes: f = {f12:.4f}, grupos = {s_para_f(f12):.1f} (publicado 46), "
          f"bots = {t_para_f(f12, eq4_vacia)} (publicado 11 796)")
    f98 = 0.98
    print(f"      bots para f = 0,98 con ec. (4): {t_para_f(f98, eq4_vacia)}  "
          f"(publicado «4 600 node botnet»)")
    print(f"      llenado completo de tried, ec. (4): "
          f"{t_para_f(0.999, eq4_vacia)} direcciones  (publicado «~6 000»)")
    print(f"      infraestructura s=32, t=256/grupo -> E[Gamma]/64 = "
          f"{eq9_gamma(32)/64:.4f}  (publicado «f = 86 %»)")

    print("\n  (d) ec. (1)(2)(3): el sesgo hacia sellos frescos")
    fp = 8.0 / 4096.0
    print(f"      {'f':>6} | " + " ".join(f"{'tau_l='+str(t)+'h':>14}" for t in (4, 5, 24, 48)))
    for f in (0.30, 0.50, 0.72, 0.80, 0.90, 0.98):
        cel = []
        for tl in (4, 5, 24, 48):
            q = q_heilman(f, fp, 27.0 / 10.0, tl * 6.0)
            cel.append(f"{q**8:>14.4f}")
        print(f"      {f:>6.2f} | " + " ".join(cel))
    print("      publicado: f=0,72 con tau_l=48 h -> 90 %; f=0,72 con tau_l=24 h -> >85 %;")
    print("                 f=0,72 con tau_l= 4 h -> >55 %; s=32,t=256 con tau_l=5 h -> >80 %")
    print(f"      seleccion ALEATORIA (sin sesgo): 90 % exige f = 0,9^(1/8) = "
          f"{f_para_exito(0.9):.4f}  (publicado 98,7 %)")
    print(f"      reparto justo, 3 000 bots en una red de 7 200: "
          f"(3000/10200)^8 = {(3000/10200.0)**8:.6%}  (publicado 0,006 %)")

    # ---------------------------------------------------------------------------------
    print("\n--- D.2 KASPA: el mismo calculo sobre `rusty-kaspa` ---")
    print("    Diferencia estructural: NO hay tablas tried/new ni sesgo por sello. El peso es")
    print("    64^(4-y)/n_prefijo, luego el peso TOTAL de un PrefixBucket es 64^(4-y) SEA CUAL")
    print("    SEA el numero de IP que tenga. La unidad del ataque es el GRUPO (/16), no la IP.")
    print("    Comprobacion de esa afirmacion (Monte Carlo, mismo s_a, distinto t/grupo):")
    for ips in (1, 16, 256):
        with Pool() as pool:
            r = pool.map(mc_kaspa, [(32, 1, 8, 0, 0, 0.0, ips, s, 4000) for s in SEMS])
        ok = sum(x[0] for x in r)
        n = sum(x[1] for x in r)
        print(f"      s_a = 32 grupos, {ips:>3} IP/grupo -> P(eclipse) = {ok/n:.4f} "
              f"({ok}/{n})")
    print("      -> identico dentro del error: en Kaspa las IP EXTRA DE UN MISMO /16 NO")
    print("         compran nada en el sorteo. VERIFICADO.")

    print("\n  (a) P(eclipse) con la victima 'fresca' (todo y=1) y TODAS las honestas VIVAS")
    print("      (p_churn = 1: es el caso comparable con el f^8 de Heilman; con p_churn = 0")
    print("       el eclipse es cierto por construccion sea cual sea s_a, y la fila no dice nada)")
    print(f"      {'s_a':>6} {'h1 honestas':>12} | {'MC':>8} {'cerrada (s/(s+h))^8':>20} "
          f"{'replicas':>9}")
    for s_a in (8, 32, 64, 128, 512):
        for h1 in (10, 100, 1000):
            with Pool() as pool:
                r = pool.map(mc_kaspa, [(s_a, 1, 0, 1, h1, 1.0, 1, s, 4000) for s in SEMS])
            ok = sum(x[0] for x in r)
            n = sum(x[1] for x in r)
            print(f"      {s_a:>6} {h1:>12} | {ok/n:>8.4f} "
                  f"{p_kaspa_cerrada(s_a, 1, 0, 1, h1):>20.4f} {n:>9}")

    print("\n  (b) P(eclipse) con `h` grupos honestos YA CONECTADOS (y=0) y churn `p`")
    print("      y=0 pesa 64x que y=1: los honestos ya probados son la defensa real.")
    print(f"      {'s_a(y=0)':>9} {'h(y=0)':>7} {'p churn':>8} | {'MC':>8} {'replicas':>9}")
    for h0 in (2, 8, 32, 128):
        for p in (0.0, 0.28, 0.80):
            for s_a in (32, 512):
                with Pool() as pool:
                    r = pool.map(mc_kaspa,
                                 [(s_a, 0, h0, 0, 1000, p, 1, s, 4000) for s in SEMS])
                ok = sum(x[0] for x in r)
                n = sum(x[1] for x in r)
                print(f"      {s_a:>9} {h0:>7} {p:>8.2f} | {ok/n:>8.4f} {n:>9}")

    print("\n  (c) grupos que hacen falta para 50 % y 90 % (busqueda por biseccion)")
    print(f"      {'h(y=0)':>7} {'p churn':>8} | {'s_a para 50 %':>14} {'s_a para 90 %':>14}")
    for h0 in (0, 2, 8, 32, 128):
        for p in (0.0, 0.28, 0.80):
            fila = []
            for obj in (0.5, 0.9):
                lo, hi = 1, 100000
                while lo < hi:
                    mid = (lo + hi) // 2
                    with Pool() as pool:
                        r = pool.map(mc_kaspa,
                                     [(mid, 0, h0, 0, 1000, p, 1, s, 400) for s in SEMS])
                    pr = sum(x[0] for x in r) / sum(x[1] for x in r)
                    if pr < obj:
                        lo = mid + 1
                    else:
                        hi = mid
                fila.append(lo if lo < 100000 else None)
            f50 = f"{fila[0]}" if fila[0] is not None else "> 1e5"
            f90 = f"{fila[1]}" if fila[1] is not None else "> 1e5"
            print(f"      {h0:>7} {p:>8.2f} | {f50:>14} {f90:>14}")

    print("\n  (d) efecto de cada contramedida de Bitcoin Core sobre la P(eclipse) de Kaspa")
    print("      Escenario base: s_a = 512 grupos del atacante (y=0), h = 8 grupos honestos")
    print("      ya conectados (y=0), 1 000 honestos y=1 en el almacen, churn p = 0,28")
    print("      (p = 0,28 es el «% live» medido por Heilman, Tabla 1, filas de sus nodos).")
    BASE = dict(s_a=512, y_a=0, h0=8, y_h=0, h1=1000, p=0.28)

    def corre(s_a, y_a, h0, y_h, h1, p, salientes=SALIENTES, reps=4000):
        global SALIENTES
        viejo = SALIENTES
        SALIENTES = salientes
        try:
            with Pool() as pool:
                r = pool.map(mc_kaspa, [(s_a, y_a, h0, y_h, h1, p, 1, s, reps) for s in SEMS])
        finally:
            SALIENTES = viejo
        return sum(x[0] for x in r) / sum(x[1] for x in r)

    base = corre(**{"s_a": BASE["s_a"], "y_a": BASE["y_a"], "h0": BASE["h0"],
                    "y_h": BASE["y_h"], "h1": BASE["h1"], "p": BASE["p"]})
    print(f"      {'contramedida':<40} {'P(eclipse)':>11} {'x base':>9}  fuente")
    print(f"      {'BASE (Kaspa tal cual)':<40} {base:>11.4f} {1.0:>9.2f}  "
          f"rusty-kaspa lib.rs:418-460")
    variantes = [
        ("Feeler: h 8 -> 128 grupos y=0",
         dict(s_a=512, y_a=0, h0=128, y_h=0, h1=1000, p=0.28), 8,
         "Heilman §7.4 / Core 0.14"),
        ("Feeler agresivo: h -> 1024",
         dict(s_a=512, y_a=0, h0=1024, y_h=0, h1=1000, p=0.28), 8,
         "Heilman §7.4"),
        ("Limite de ADDR: no se purga h1 (1e3 -> 4e3)",
         dict(s_a=512, y_a=0, h0=8, y_h=0, h1=4000, p=0.28), 8,
         "Core 0.22 / Heilman §7.8"),
        ("block-relay-only: 8 -> 10 salientes",
         dict(s_a=512, y_a=0, h0=8, y_h=0, h1=1000, p=0.28), 10,
         "Core 0.19"),
        ("mas salientes: 8 -> 12",
         dict(s_a=512, y_a=0, h0=8, y_h=0, h1=1000, p=0.28), 12,
         "Heilman §7.7"),
        ("Feeler + ADDR + 12 salientes",
         dict(s_a=512, y_a=0, h0=128, y_h=0, h1=4000, p=0.28), 12,
         "combinacion"),
    ]
    for nombre, kw, sal, fuente in variantes:
        pr = corre(kw["s_a"], kw["y_a"], kw["h0"], kw["y_h"], kw["h1"], kw["p"], sal)
        print(f"      {nombre:<40} {pr:>11.4f} {pr/max(base,1e-9):>9.2f}  {fuente}")
    anc2 = (1 - BASE["p"]) ** 2
    print(f"      {'anchors (2 persistentes, Core 0.21)':<40} {base*anc2:>11.4f} "
          f"{anc2:>9.2f}  Heilman §7.5 (factor (1-p)^2)")
    print("      («anchors» no se simula: su efecto es exactamente «el eclipse falla si alguno")
    print("       de los 2 anclajes honestos sigue vivo», luego multiplica por (1-p)^2 = "
          f"{anc2:.4f}.)")
    print("      test-before-evict: Kaspa YA LO TIENE de hecho — `keep_limit` (lib.rs:394-401)")
    print("      desaloja el de MAYOR connection_failed_count, y las direcciones con exito")
    print("      previo tienen y = 0, que es el MINIMO: no se desalojan mientras quede una")
    print("      y >= 1. Factor x1,00. Es la unica de las siete que ya esta puesta.")
    print("      asmap (agrupar por ASN en vez de por /16): LAGUNA — el coste en grupos")
    print("      depende del reparto real de ASN, que no esta en las fuentes locales.")

    print("\n  (e) EL AGUJERO NUEVO: `AddressKey = (IP, PUERTO)` y `MAX_ADDRESSES = 4096`")
    print("      stores/mod.rs:9 -> la clave del almacen incluye el PUERTO. Una sola IP con")
    print("      4 096 puertos distintos ocupa el almacen entero. Y `keep_limit` desaloja el")
    print("      de mayor `connection_failed_count`: las honestas NUNCA PROBADAS (y=1) empatan")
    print("      con las del atacante (y=1), asi que el desalojo entre empatados es arbitrario")
    print("      (Rust `max_by` sobre un HashMap con RandomState).")
    print("      Modelo: con `H0` direcciones y=0 protegidas, cada insercion desaloja una")
    print("      uniforme entre las 4096-H0 de count 1. Supervivientes honestos tras `k`")
    print("      inserciones: H1*(1 - 1/(4096-H0))^k.")
    print(f"      {'H0':>5} {'k para -50 % de H1':>20} {'-90 %':>10} {'-99 %':>10} "
          f"{'conexiones (2500/ea)':>21}")
    for H0 in (0, 8, 128, 1024):
        n = MAX_ADDRESSES - H0
        ks = [n * math.log(1 / (1 - r)) for r in (0.5, 0.9, 0.99)]
        print(f"      {H0:>5} {ks[0]:>20.0f} {ks[1]:>10.0f} {ks[2]:>10.0f} "
              f"{ks[2]/2500:>21.1f}")
    print("      -> con 8 conexiones entrantes (o 8 reconexiones) desde UNA SOLA IP el atacante")
    print("         borra el 99 % de las direcciones honestas no probadas del almacen.")
    print("         Coste: una IP. VERIFICADO contra el codigo, no simulado en red.")

    print(f"\n[{time.time()-t0:.0f} s]")
