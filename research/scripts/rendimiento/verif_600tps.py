#!/usr/bin/env python3
"""
verif_600tps.py — que le pasa a ZEROX con 600 pagos/s sostenidos en el marketplace.

Reglas implementadas LITERALMENTE del SPEC (fichero:linea):
  SPEC.md:921-925   N_CORTO=100, N_LARGO=262800, ZONA_LIBRE=100000, FACTOR_SURGE=50
  SPEC.md:1002-1009 C-WGT-04  lt_weight = min(max(w, Mlt*10/17), Mlt + Mlt*7/10)
  SPEC.md:1027-1031 C-WGT-05  Mlt = max(ZONA_LIBRE, mediana(lt_weight))
  SPEC.md:1035-1038 C-WGT-06  Mst = mediana(weight)
  SPEC.md:1050      C-WGT-08  M = max(min(max(Mlt,Mst), FACTOR_SURGE*Mlt), ZONA_LIBRE)
  SPEC.md:1074      C-WGT-09  LIMITE = 2*M ; por encima el bloque es INVALIDO
  SPEC.md:1486-1487 C-EMIT-06 subsidio = base*x*(2M-x)/M/M  para M < x <= 2M
  SPEC.md:1452-1454 SOFT_CAP=1e9 ZZK, SHIFT=19, TAIL=32 ZZK/bloque
  SPEC.md:936       "26,3 GB/ano (262 800 bloques/ano x 100 KB)"  <- calibrado a T=120 s

HALLAZGO QUE ESTE SCRIPT DOCUMENTA: `ZONA_LIBRE` esta definida POR BLOQUE y se calibro para
un bloque cada 120 s. A lambda = 1 bloque/s hay DOS lecturas posibles y NINGUNA esta decidida.
"""
BREK = 10**8
ZONA_LIBRE_SPEC = 100_000
N_CORTO, N_LARGO, FACTOR_SURGE = 100, 262_800, 50
TX_B, TX_BLINDADA_B = 350, 820
SEG_ANO = 365 * 24 * 3600
BLOQUES_ANO_120 = 262_800
BLOQUES_ANO_1S = SEG_ANO

def get_mid(a, b): return (a // 2) + (b // 2) + ((a - 2 * (a // 2)) + (b - 2 * (b // 2))) // 2
def mediana(v):
    s = sorted(v); n = len(s)
    return s[n // 2] if n % 2 else get_mid(s[n // 2 - 1], s[n // 2])
def subsidio(base, x, M):
    if x <= M: return base
    if x > 2 * M: return None
    return (base * x * (2 * M - x)) // M // M

print("=" * 86)
print("A) LAS DOS LECTURAS DEL SPEC a lambda = 1 bloque/s. Ninguna esta decidida.")
print("=" * 86)
print(f"  El SPEC fija ZONA_LIBRE = {ZONA_LIBRE_SPEC:,} B POR BLOQUE, y su nota (SPEC.md:936) calcula".replace(",", " "))
print(f"  el crecimiento como 262 800 bloques/ano x 100 KB = 26,3 GB/ano. Eso es a T = 120 s.\n")
for nombre, zl in (("(a) literal: se conserva 100 000 B por bloque", ZONA_LIBRE_SPEC),
                   ("(b) presupuesto: se conserva 26,3 GB/ano", int(26.3e9 / BLOQUES_ANO_1S))):
    tps = zl / TX_B
    print(f"  {nombre}")
    print(f"      zona libre por bloque : {zl:,} B".replace(",", " "))
    print(f"      tx/s libres de penalizacion: {tps:,.1f} transparentes | {zl/TX_BLINDADA_B:,.1f} blindadas".replace(",", " "))
    print(f"      crecimiento de cadena : {zl*BLOQUES_ANO_1S/1e9:,.0f} GB/ano".replace(",", " "))
    print(f"      SSD de 4 TB lleno en  : {4e12/(zl*BLOQUES_ANO_1S):.2f} anos\n")

print("=" * 86)
print("B) Que pide el marketplace: 600 pagos/s")
print("=" * 86)
for nombre, b in (("transparente 350 B", TX_B), ("blindada Orchard 820 B", TX_BLINDADA_B)):
    Bs = 600 * b
    print(f"  600 tx/s {nombre:<24}: {Bs:>8,} B/s  ->  {Bs*SEG_ANO/1e12:>5.2f} TB/ano  ->  SSD 4 TB lleno en {4e12/(Bs*SEG_ANO)*12:>4.1f} meses".replace(",", " "))
print(f"\n  Frente a las paredes medidas del nodo domestico (8 nucleos, 50 Mbps subida, SSD 4 TB):")
print(f"    CPU verificando firmas : 84 211 tx/s   -> 600 no la toca")
print(f"    Red con 8 pares        :  2 232 tx/s   -> 600 cabe, al 27 % de la subida")
print(f"    Almacenamiento         :     72 tx/s   -> 600 la revienta por 8,3x")

print("\n" + "=" * 86)
print("C) Con la lectura (a), cuanto tarda el tamano de bloque en absorber 600 tx/s")
print("=" * 86)
print("  Demanda inelastica: el marketplace paga lo que haga falta y el granjero llena hasta LIMITE.\n")

def simula(demanda_B, zona_libre, horizonte, llenar_a_limite=True):
    w_hist, lt_hist, emitido, backlog, traza = [], [], 0, 0, []
    for h in range(horizonte):
        Mlt = zona_libre if not lt_hist else max(zona_libre, mediana(lt_hist[-N_LARGO:]))
        Mst = zona_libre if not w_hist else mediana(w_hist[-N_CORTO:])
        M = max(min(max(Mlt, Mst), FACTOR_SURGE * Mlt), zona_libre)
        limite = 2 * M
        base = max((10**9 * BREK - emitido) >> 19, 32 * BREK)
        tope = limite if llenar_a_limite else M
        x = int(min(tope, backlog + demanda_B))
        backlog = max(0, backlog + demanda_B - x)
        s = subsidio(base, x, M)
        emitido += s
        w_hist.append(x); lt_hist.append(min(max(x, (Mlt * 10) // 17), Mlt + (Mlt * 7) // 10))
        traza.append((h, Mlt, M, limite, x, s / base, backlog))
    return traza

tr = simula(600 * TX_B, ZONA_LIBRE_SPEC, 3000)
print(f"    {'bloque':>8}{'t':>10}{'Mlt (B)':>12}{'LIMITE (B)':>13}{'x (B)':>12}{'subsidio':>10}{'cola (tx)':>12}")
for h in (0, 5, 20, 50, 100, 300, 1000, 2999):
    _, Mlt, M, lim, x, frac, back = tr[h]
    t = f"{h}s" if h < 120 else f"{h/60:.0f}min"
    print(f"    {h:>8}{t:>10}{Mlt:>12,}{lim:>13,}{x:>12,}{frac:>9.1%}{back/TX_B:>12,.0f}".replace(",", " "))
print(f"\n  La sobrecarga la abre la mediana CORTA (100 bloques = 100 s), no la larga.")
print(f"  Techo instantaneo con Mlt en el suelo: LIMITE <= 2*{FACTOR_SURGE}*{ZONA_LIBRE_SPEC:,} = {2*FACTOR_SURGE*ZONA_LIBRE_SPEC:,} B = {2*FACTOR_SURGE*ZONA_LIBRE_SPEC/TX_B:,.0f} tx/s".replace(",", " "))

print("\n" + "=" * 86)
print("D) El precio: cuanto subsidio pierde el granjero y quien lo paga")
print("=" * 86)
base0 = 190_734_863_281
for mult in (1.0, 1.2, 1.5, 1.8, 2.0):
    M = ZONA_LIBRE_SPEC; x = int(mult * M)
    s = subsidio(base0, x, M)
    perd = (base0 - s) / BREK
    tx_extra = (x - M) / TX_B
    print(f"  bloque a {mult:>4.1f}x M: {x:>9,} B  subsidio {s/base0:>6.1%}  pierde {perd:>9,.2f} ZZK  por {tx_extra:>6,.0f} tx extra  =>  {perd/max(tx_extra,1):>8,.3f} ZZK/tx de tarifa minima".replace(",", " "))
print(f"\n  Con el subsidio SIN recalibrar ({base0/BREK:,.2f} ZZK/bloque a 1 b/s, 120x de mas),".replace(",", " "))
print(f"  la tarifa que compensa es absurda. Con el subsidio recalibrado (/120 = {base0/120/BREK:,.2f} ZZK)".replace(",", " "))
print(f"  la misma penalizacion cuesta 120x menos y el mercado de tarifas vuelve a ser sano.")

print("\n" + "=" * 86)
print("E) CRITERIO: el resultado cambia con la demanda")
print("=" * 86)
for tx_s in (2, 285, 600, 5000, 28571, 40000):
    t = simula(tx_s * TX_B, ZONA_LIBRE_SPEC, 300)
    _, _, _, lim, x, frac, back = t[-1]
    est = "absorbida" if back == 0 else f"cola {back/TX_B:,.0f} tx y creciendo".replace(",", " ")
    print(f"  {tx_s:>6,} tx/s -> bloque {x:>10,} B, subsidio {frac:>6.1%}, {est}".replace(",", " "))
