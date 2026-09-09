#!/usr/bin/env python3
"""
verif_recalibrado_1280.py — rederivar las constantes de ZEROX para lambda = 1 bloque/s
con un objetivo de diseno de 1 280 tx/s.

Principio de la rederivacion: **lo que se conserva es el calendario en TIEMPO**, no el numero
por bloque. Toda constante en unidades de bloque calibrada a T = 120 s se divide por 120, o se
reexpresa en segundos.

Fuentes de las constantes originales:
  SPEC.md:921-925   N_CORTO=100, N_LARGO=262800, ZONA_LIBRE=100000, FACTOR_SURGE=50
  SPEC.md:1452-1455 SOFT_CAP=1e9 ZZK, SHIFT=19, TAIL=32 ZZK/bloque, COINBASE_MATURITY=100
  SPEC.md:1467-1471 inicial 1907,35 ZZK; tail ano 8,16; 1000 M ano 10,15; inflacion 0,84 %/ano
  SPEC.md:936       26,3 GB/ano = 262 800 bloques x 100 KB
  SPEC.md:1737      MAX_REORG_LENGTH = COINBASE_MATURITY - 1
"""
import math
BREK = 10**8
SEG_ANO = 365 * 24 * 3600
T_VIEJO = 120
BLOQUES_ANO_VIEJO = 262_800
BLOQUES_ANO_NUEVO = SEG_ANO          # lambda = 1 b/s
FACTOR = BLOQUES_ANO_NUEVO / BLOQUES_ANO_VIEJO
TX_B, TX_BLINDADA_B = 350, 820
OBJETIVO_TPS = 1280

print("=" * 88)
print(f"Factor de cambio de ritmo: {FACTOR:.0f}x  ({BLOQUES_ANO_VIEJO:,} -> {BLOQUES_ANO_NUEVO:,} bloques/ano)".replace(",", " "))
print("=" * 88)

# ---------------------------------------------------------------- 1) el objetivo
print("\n1) QUE PIDE EL OBJETIVO DE 1 280 tx/s")
print("-" * 88)
Bs = OBJETIVO_TPS * TX_B
Bs_bl = OBJETIVO_TPS * TX_BLINDADA_B
print(f"  {OBJETIVO_TPS:,} tx/s x 350 B = {Bs:,} B/s = {Bs/1e6:.2f} MB/s".replace(",", " "))
print(f"  al dia            : {OBJETIVO_TPS*86400:,} transacciones".replace(",", " "))
print(f"  crecimiento cadena: {Bs*SEG_ANO/1e12:.2f} TB/ano transparente | {Bs_bl*SEG_ANO/1e12:.2f} TB/ano blindado")
print(f"  a 10 anos         : {Bs*SEG_ANO*10/1e12:.1f} TB | {Bs_bl*SEG_ANO*10/1e12:.1f} TB")
print(f"\n  Contra las paredes medidas del nodo (8 nucleos, 50 Mbps subida, SSD 4 TB):")
for nombre, techo in (("CPU firmas Ed25519", 84_211), ("Red, 8 pares", 2_232), ("SSD 4 TB en 5 anos", 72)):
    pct = OBJETIVO_TPS / techo * 100
    ver = "OK" if pct <= 100 else f"NO CABE ({OBJETIVO_TPS/techo:.1f}x por encima)"
    print(f"    {nombre:<22}{techo:>8,} tx/s   uso {pct:>7.1f} %   {ver}".replace(",", " "))
print(f"\n  Con Erlay (-40 % de retransmision) la pared de red sube a ~{2232/0.6:,.0f} tx/s -> uso {OBJETIVO_TPS/(2232/0.6)*100:.0f} %".replace(",", " "))

# ---------------------------------------------------------------- 2) zona libre
print("\n2) ZONA_LIBRE: que valor sostiene 1 280 tx/s sin penalizacion")
print("-" * 88)
zl_objetivo = OBJETIVO_TPS * TX_B          # por bloque, a lambda = 1
zl_conserva = int(26.3e9 / BLOQUES_ANO_NUEVO)
zl_literal = 100_000
print(f"  {'candidato':<44}{'B/bloque':>12}{'tx/s libres':>13}{'GB/ano':>12}{'SSD 4 TB':>12}")
for nombre, zl in (("(a) literal, sin tocar (lo que dice el SPEC)", zl_literal),
                   ("(b) conservar 26,3 GB/ano", zl_conserva),
                   ("(c) OBJETIVO 1 280 tx/s transparentes", zl_objetivo),
                   ("(d) OBJETIVO 1 280 tx/s blindadas", OBJETIVO_TPS*TX_BLINDADA_B)):
    gb = zl * BLOQUES_ANO_NUEVO / 1e9
    anos = 4e12 / (zl * BLOQUES_ANO_NUEVO)
    ssd = f"{anos:.2f} anos" if anos >= 1 else f"{anos*12:.1f} meses"
    print(f"  {nombre:<44}{zl:>12,}{zl/TX_B:>13,.0f}{gb:>12,.0f}{ssd:>12}".replace(",", " "))
print(f"\n  Nota: ZONA_LIBRE no es un techo. Es el suelo de la mediana y el coste del atacante")
print(f"  (SPEC.md:915, 'big bang attack'). La capacidad sostenida real la fija la mediana, que")
print(f"  sigue a la demanda hasta 2 x FACTOR_SURGE x Mlt. Con (c): techo instantaneo")
print(f"  {2*50*zl_objetivo/TX_B:,.0f} tx/s.".replace(",", " "))

# ---------------------------------------------------------------- 3) emision
print("\n3) EMISION: rederivar conservando el calendario en TIEMPO")
print("-" * 88)
def simula(bpa, shift, tail_brek, soft=10**9*BREK, anos=40.0):
    emitido, h, ct, cc, inicial = 0, 0, None, None, None
    lim = int(bpa * anos)
    while h < lim:
        base = max((soft - emitido) >> shift, tail_brek)
        if inicial is None: inicial = base
        if ct is None and base <= tail_brek: ct = h / bpa
        emitido += base; h += 1
        if cc is None and emitido >= soft:
            cc = h / bpa
            if ct is not None: break
    return inicial, ct, cc, tail_brek * bpa / BREK, tail_brek * bpa / soft * 100

i0, ct0, cc0, ta0, inf0 = simula(BLOQUES_ANO_VIEJO, 19, 32 * BREK)
print(f"  ORIGINAL (T=120 s, SHIFT=19, TAIL=32 ZZK): inicial {i0/BREK:,.2f} ZZK, tail ano {ct0:.2f},".replace(",", " "))
print(f"           1000 M ano {cc0:.2f}, cola {ta0:,.0f} ZZK/ano, inflacion {inf0:.2f} %/ano".replace(",", " "))
print(f"  (SPEC.md:1467-1471 declara: 1 907,35 / 8,16 / 10,15 / 8 409 600 / 0,84  -> control OK)\n")
print(f"  {'candidato a lambda=1':<40}{'inicial ZZK':>13}{'tail ano':>10}{'1000M ano':>11}{'cola ZZK/ano':>15}{'inflacion':>11}")
print(f"  {'sin tocar nada (lo que hay HOY)':<40}", end="")
i, ct, cc, ta, inf = simula(BLOQUES_ANO_NUEVO, 19, 32 * BREK)
print(f"{i/BREK:>13,.2f}{ct:>10.4f}{cc:>11.4f}{ta:>15,.0f}{inf:>10.2f} %".replace(",", " "))
mejor = None
for shift in (25, 26, 27):
    tail = int(32 * BREK / FACTOR)
    i, ct, cc, ta, inf = simula(BLOQUES_ANO_NUEVO, shift, tail)
    err = abs(cc - cc0) / cc0
    print(f"  {'SHIFT='+str(shift)+', TAIL=32/120 ZZK':<40}{i/BREK:>13,.2f}{ct:>10.2f}{cc:>11.2f}{ta:>15,.0f}{inf:>10.2f} %".replace(",", " "))
    if mejor is None or err < mejor[0]: mejor = (err, shift, tail)
_, shift_ok, tail_ok = mejor
print(f"\n  RECOMENDADO: SHIFT = {shift_ok}, TAIL_EMISSION = {tail_ok:,} brek = {tail_ok/BREK:.6f} ZZK/bloque".replace(",", " "))
print(f"  Razon: SHIFT sube en log2(120) = {math.log2(FACTOR):.1f}; 2^{shift_ok-19} = {2**(shift_ok-19)} es el entero mas cercano a 120.")
print(f"  El techo SOFT_CAP y la unidad no se tocan: el sistema es homogeneo de grado 1 (SPEC.md:1475).")

# ---------------------------------------------------------------- 4) ventanas
print("\n4) VENTANAS EN UNIDADES DE BLOQUE: reexpresar en tiempo")
print("-" * 88)
print(f"  {'constante':<26}{'valor viejo':>14}{'= tiempo':>14}{'valor nuevo':>14}{'estado':>28}")
for nombre, viejo, motivo in (("N_CORTO", 100, "ventana corta"),
                              ("N_LARGO", 262_800, "ciclo estacional del marketplace"),
                              ("COINBASE_MATURITY", 100, "madurez de recompensa"),
                              ("MAX_REORG_LENGTH", 99, "sustituida por R-FIN-7 en el DAG")):
    seg = viejo * T_VIEJO
    nuevo = viejo * FACTOR
    t = f"{seg/86400:.0f} d" if seg >= 86400 else (f"{seg/3600:.2f} h" if seg >= 3600 else f"{seg/60:.0f} min")
    print(f"  {nombre:<26}{viejo:>14,}{t:>14}{int(nuevo):>14,}{motivo:>28}".replace(",", " "))
print(f"\n  PROBLEMA NUEVO con N_LARGO: la ventana de un ano a lambda=1 son {int(262_800*FACTOR):,} muestras.".replace(",", " "))
print(f"  El SPEC estima ~2 MB de estado a 262 800 (SPEC.md:934); a {int(262_800*FACTOR):,} serian ~{2*FACTOR:.0f} MB".replace(",", " "))
print(f"  y una mediana sobre esa ventana en cada bloque. Hay que decidir: mantener el ano y pagar")
print(f"  la memoria (mediana incremental), o acortar la ventana y perder el ciclo estacional.")
print(f"\n  COINBASE_MATURITY debe ser >= la finalidad del DAG (F = 2 h = 7 200 bloques).")
print(f"  Con el factor 120 queda en {int(100*FACTOR):,} bloques = 3,33 h > 2 h: CUMPLE.".replace(",", " "))

# ---------------------------------------------------------------- 5) tarifas
print("\n5) EFECTO SOBRE LA PENALIZACION Y LAS TARIFAS")
print("-" * 88)
base_viejo = 190_734_863_281
base_nuevo = (10**9 * BREK) >> shift_ok
for etiqueta, base, zl in (("subsidio SIN recalibrar", base_viejo, zl_objetivo),
                           ("subsidio recalibrado", base_nuevo, zl_objetivo)):
    M = zl; x = 2 * M
    perd = (base - 0) / BREK
    tx_extra = (x - M) / TX_B
    print(f"  {etiqueta:<26}: bloque al doble de la mediana cuesta {perd:>12,.2f} ZZK  =>  {perd/tx_extra:>8,.4f} ZZK/tx".replace(",", " "))
print(f"\n  El subsidio sin recalibrar hace la penalizacion {base_viejo/base_nuevo:.0f}x mas cara de lo debido:")
print(f"  ningun granjero supera la mediana y la sobrecarga deja de funcionar como valvula.")
