#!/usr/bin/env python3
"""
verif_zona_libre.py — implicaciones reales de ZONA_LIBRE, incluida la que corrige mi recomendacion.

La tarifa minima del SPEC (§5.5) es:
    F = recompensa_base * REF_WEIGHT / Mf / Mf     (dos divisiones enteras, Mf = Mlt propuesto)
    tarifa_por_byte = max(1, F - F/20)
Con Mlt en su suelo, Mf = ZONA_LIBRE, luego  tarifa_por_byte ~ base * REF_WEIGHT / ZONA_LIBRE^2.

CONSECUENCIA que hay que ver: el coste de llenar UN bloque es
    ZONA_LIBRE * tarifa = base * REF_WEIGHT / ZONA_LIBRE
o sea INVERSAMENTE proporcional a ZONA_LIBRE. Y como los bytes anadidos crecen con ZONA_LIBRE,
el coste POR GIGABYTE de inflar la cadena va como 1/ZONA_LIBRE^2.
"""
BREK = 10**8
REF_WEIGHT = 3000
SEG_ANO = 365 * 24 * 3600
TX_B = 350
BASE_120 = 190_734_863_281            # SPEC.md:1467, a T=120 s
BASE_L1 = (10**9 * BREK) >> 26        # recalibrada, SHIFT=26 (propuesta §2)
BLOQUES_120, BLOQUES_L1 = 262_800, SEG_ANO

def tarifa_por_byte(base, mf):
    F = base * REF_WEIGHT // mf // mf
    return max(1, F - F // 20)

print("=" * 92)
print("CONTROL: reproducir la tabla del SPEC (§5.5, Mf = ZONA_LIBRE = 100 000, T = 120 s)")
print("=" * 92)
for reg, base, dice in (("Lanzamiento", BASE_120, "54 359 brek/peso, 0,19 ZZK por tx de 350 B"),
                        ("Cola", 32 * BREK, "912 brek/peso, 0,0032 ZZK")):
    t = tarifa_por_byte(base, 100_000)
    print(f"  {reg:<12} tarifa {t:>8,} brek/peso   tx de 350 B: {t*350/BREK:>8.4f} ZZK   SPEC dice: {dice}".replace(",", " "))

print("\n" + "=" * 92)
print("LA IMPLICACION QUE CORRIGE MI RECOMENDACION")
print("=" * 92)
print(f"  {'ZONA_LIBRE':>12}{'tarifa/peso':>14}{'tx 350 B':>12}{'crece/ano':>13}{'coste del ataque':>18}{'coste por GB':>15}")
print(f"  {'(a lambda=1, emision recalibrada SHIFT=26, base = ' + f'{BASE_L1/BREK:.2f}' + ' ZZK)':>84}")
filas = []
for zl in (100_000, 200_000, 448_000, 833):
    t = tarifa_por_byte(BASE_L1, max(zl, 1))
    bytes_ano = zl * BLOQUES_L1
    coste_ano = bytes_ano * t / BREK           # ZZK que paga el atacante en tarifas
    por_gb = coste_ano / (bytes_ano / 1e9)
    filas.append((zl, t, bytes_ano, coste_ano, por_gb))
    print(f"  {zl:>12,}{t:>14,}{t*TX_B/BREK:>12.5f}{bytes_ano/1e9:>10,.0f} GB{coste_ano:>15,.0f} ZZK{por_gb:>12,.0f} ZZK".replace(",", " "))
print(f"\n  Duplicar ZONA_LIBRE de 100 000 a 200 000:")
z1, z2 = filas[0], filas[1]
print(f"    la tarifa de un usuario cae {z1[1]/z2[1]:.1f}x  (bueno para el marketplace)")
print(f"    los bytes que un atacante mete gratis se duplican")
print(f"    el coste de inflar un GB cae {z1[4]/z2[4]:.1f}x  (malo)")
print(f"  Son la MISMA tarifa: no se puede abaratar al usuario sin abaratar al atacante.")

print("\n" + "=" * 92)
print("Y UN EFECTO EN CASCADA DEL RECALIBRADO DE LA EMISION, que hay que decir")
print("=" * 92)
t120 = tarifa_por_byte(BASE_120, 100_000)
tl1 = tarifa_por_byte(BASE_L1, 100_000)
gb120 = 100_000 * BLOQUES_120 / 1e9
gbl1 = 100_000 * BLOQUES_L1 / 1e9
c120 = 100_000 * BLOQUES_120 * t120 / BREK / gb120
cl1 = 100_000 * BLOQUES_L1 * tl1 / BREK / gbl1
print(f"  La tarifa escala con recompensa_base. Al recalibrar la emision (1 907,35 -> {BASE_L1/BREK:.2f} ZZK)")
print(f"  la tarifa minima cae {t120/tl1:.0f}x y con ella el antispam:")
print(f"    diseno original (T=120 s): {c120:>12,.0f} ZZK por GB de cadena".replace(",", " "))
print(f"    recalibrado  (lambda=1)  : {cl1:>12,.0f} ZZK por GB de cadena  ->  {c120/cl1:.0f}x mas barato".replace(",", " "))
print(f"\n  Para conservar el coste del atacante hay que subir REF_WEIGHT en el mismo factor:")
print(f"    REF_WEIGHT = 3 000  ->  {3000*round(t120/tl1):,}".replace(",", " "))
print(f"  El SPEC ya avisa (SPEC.md:793-795) de que REF_WEIGHT 'requiere un modelo de coste de")
print(f"  atacante explicito' y que no es una constante cerrada. Este es el momento de fijarla.")

print("\n" + "=" * 92)
print("LO QUE PAGA UN USUARIO DEL MARKETPLACE, con REF_WEIGHT ya corregido a 384 000")
print("=" * 92)
RW2 = 384_000
def tarifa2(base, mf):
    F = base * RW2 // mf // mf
    return max(1, F - F // 20)
print(f"  {'ZONA_LIBRE':>12}{'tarifa/peso':>14}{'tx 350 B':>14}{'coste por GB':>16}{'vs diseno original':>20}")
for zl in (100_000, 200_000, 448_000):
    t = tarifa2(BASE_L1, zl)
    por_gb = zl * BLOQUES_L1 * t / BREK / (zl * BLOQUES_L1 / 1e9)
    print(f"  {zl:>12,}{t:>14,}{t*TX_B/BREK:>14.5f}{por_gb:>13,.0f} ZZK{por_gb/c120:>19.2f}x".replace(",", " "))
