#!/usr/bin/env python3
"""
verif_600tps_maduro.py — 600 pagos/s sobre una cadena MADURA (el caso realista del marketplace).

En cadena madura la ventana larga (N_LARGO = 262 800 bloques = 3,04 dias a lambda=1) esta llena
de bloques a la zona libre, asi que Mlt se queda clavada en ZONA_LIBRE durante toda la
transicion: mover su mediana exige llenar media ventana, 1,52 dias. Se fija Mlt = ZONA_LIBRE
constante (HIPOTESIS explicita, valida los primeros 131 400 bloques) y se simula Mst, que es la
que abre la sobrecarga.

Reglas: SPEC.md C-WGT-04/05/06/08/09 y C-EMIT-06. Citas por linea en verif_600tps.py.
"""
from collections import deque
BREK = 10**8
ZL, N_CORTO, N_LARGO, SURGE, TX_B = 100_000, 100, 262_800, 50, 350
BASE0 = 190_734_863_281  # SPEC.md:1467, recompensa inicial en brek

def get_mid(a, b): return (a // 2) + (b // 2) + ((a - 2 * (a // 2)) + (b - 2 * (b // 2))) // 2
def med(v):
    s = sorted(v); n = len(s)
    return s[n // 2] if n % 2 else get_mid(s[n // 2 - 1], s[n // 2])
def subs(base, x, M):
    if x <= M: return base
    if x > 2 * M: return None
    return (base * x * (2 * M - x)) // M // M

def transicion(tx_s, horizonte=600):
    dem = tx_s * TX_B
    w = deque([ZL] * N_CORTO, maxlen=N_CORTO)
    back, traza, perdido = 0, [], 0
    for h in range(1, horizonte + 1):
        Mlt = ZL
        Mst = med(w)
        M = max(min(max(Mlt, Mst), SURGE * Mlt), ZL)
        lim = 2 * M
        x = int(min(lim, back + dem))
        back = max(0, back + dem - x)
        s = subs(BASE0, x, M)
        perdido += BASE0 - s
        w.append(x)
        traza.append((h, Mst, M, lim, x, s / BASE0, back))
    return traza, perdido

print("=" * 90)
print("600 pagos/s transparentes sobre cadena MADURA — 210 000 B por bloque de demanda")
print("=" * 90)
tr, perdido = transicion(600)
print(f"{'bloque':>8}{'Mst (B)':>12}{'M (B)':>12}{'LIMITE (B)':>13}{'x (B)':>12}{'subsidio':>10}{'cola (tx)':>12}")
for h in (1, 2, 10, 40, 50, 51, 60, 100, 150, 300, 600):
    _, Mst, M, lim, x, frac, back = tr[h - 1]
    print(f"{h:>8}{Mst:>12,}{M:>12,}{lim:>13,}{x:>12,}{frac:>9.1%}{back/TX_B:>12,.0f}".replace(",", " "))
est = next((h for h, _, _, _, _, f, b in tr if f == 1.0 and b == 0), None)
print(f"\n  Absorbida por completo en el bloque {est} = {est} segundos." if est else "\n  NO se absorbe.")
print(f"  Subsidio perdido durante la transicion: {perdido/BREK:,.0f} ZZK".replace(",", " "))
print(f"  Estado estable: bloques de 210 000 B, SIN penalizacion (Mst sube hasta la demanda).")

print("\n" + "=" * 90)
print("Hasta donde llega: la sobrecarga tiene tope FACTOR_SURGE sobre la mediana LARGA")
print("=" * 90)
print(f"  {'demanda':>10}{'estable en':>13}{'subsidio perdido':>20}{'bloque final':>15}{'  veredicto'}")
for tx_s in (285, 600, 2_000, 10_000, 28_571, 40_000):
    tr2, perd = transicion(tx_s, 1200)
    ok = next((h for h, _, _, _, _, f, b in tr2 if f == 1.0 and b == 0), None)
    _, _, _, _, x, _, back = tr2[-1]
    ver = f"absorbida" if ok else f"COLA CRECIENDO ({back/TX_B:,.0f} tx a los 20 min)".replace(",", " ")
    print(f"  {tx_s:>10,}{(str(ok)+' s') if ok else '—':>13}{perd/BREK:>20,.0f}{x:>15,}  {ver}".replace(",", " "))
print(f"\n  Techo estructural con Mlt en el suelo: LIMITE <= 2 x {SURGE} x {ZL:,} = {2*SURGE*ZL:,} B".replace(",", " "))
print(f"  = {2*SURGE*ZL/TX_B:,.0f} tx/s instantaneas. Por encima, la cola no se vacia nunca.".replace(",", " "))

print("\n" + "=" * 90)
print("El coste que NO desaparece: disco")
print("=" * 90)
SEG_ANO = 365 * 24 * 3600
for tx_s in (2.4, 285, 600, 28_571):
    B = tx_s * TX_B
    meses = 4e12 / (B * SEG_ANO) * 12
    m = f"{meses:.1f} meses" if meses < 24 else f"{meses/12:.1f} anos"
    print(f"  {tx_s:>8,.1f} tx/s -> {B*SEG_ANO/1e12:>8.2f} TB/ano -> SSD de 4 TB lleno en {m:>12}".replace(",", " "))
