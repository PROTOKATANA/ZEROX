#!/usr/bin/env python3
"""
verif_n_largo.py — implicaciones de cada salida para N_LARGO a lambda = 1 bloque/s.

Lo que N_LARGO protege (SPEC.md:928-934): que la mediana larga Mlt recuerde el ciclo estacional del
marketplace (un ano) y que sea dificil de mover para un atacante (hay que desplazar muchas muestras).
Lo que Mlt controla: el suelo de la mediana efectiva M (C-WGT-08), el limite duro 2M (C-WGT-09), y la
tarifa minima ~ 1/Mlt^2 (SPEC.md:730). Un atacante que INFLE Mlt sube la capacidad sin penalizacion y
abarata la tarifa: es la palanca del big bang attack a largo plazo.

Freno estructural (C-WGT-04): lt_weight <= 1,7 * Mlt, luego Mlt sube como mucho 1,7x cada vez que el
atacante rellena MEDIA ventana (la mediana cruza cuando la mitad de las muestras son suyas).

Coste del atacante: llenar un bloque hasta 1,7*Mlt con Mlt = ZONA_LIBRE = 100 000 B y la tarifa minima
corregida (REF_WEIGHT = 384 000, base recalibrada 14,90 ZZK): tarifa = 54 359 brek/peso.
"""
BREK = 10**8
SEG_ANO = 365 * 24 * 3600
ZL = 100_000
TARIFA = 54_359           # brek/peso, control reproducido en verif_zona_libre.py
BYTES_MUESTRA = 8         # SPEC.md:934: ~2 MB para 262 800 muestras -> ~8 B/muestra
LLENADO = int(1.7 * ZL)   # lo que hay que meter por bloque para mover Mlt al maximo (C-WGT-04)

def fila(nombre, muestras, bloques_por_muestra, bloques_a_llenar_por_muestra, ventana_seg):
    estado_mb = muestras * BYTES_MUESTRA / 1e6
    # para cruzar la mediana hace falta que la mitad de las muestras sean del atacante
    muestras_a_mover = muestras / 2
    tiempo_seg = muestras_a_mover * bloques_por_muestra      # las muestras estan repartidas en el tiempo
    bloques_a_llenar = muestras_a_mover * bloques_a_llenar_por_muestra
    coste_zzk = bloques_a_llenar * LLENADO * TARIFA / BREK
    return nombre, estado_mb, ventana_seg / 86400, tiempo_seg / 86400, bloques_a_llenar, coste_zzk

opciones = [
    # nombre, muestras, bloques por muestra, bloques que hay que llenar por muestra movida, ventana en s
    ("1 · Ano completo, mediana incremental",     SEG_ANO,        1,   1,   SEG_ANO),
    ("2 · Ano muestreado: 1 bloque de cada 120",  SEG_ANO // 120, 120, 1,   SEG_ANO),
    ("3 · Acortar a 30 dias, ventana completa",   30 * 86400,     1,   1,   30 * 86400),
    ("4 · Ano en cubos: mediana de cada 120",     SEG_ANO // 120, 120, 61,  SEG_ANO),
]
print("=" * 100)
print("Cada opcion: memoria de estado, memoria estacional, y cuanto cuesta a un atacante mover Mlt 1,7x")
print("=" * 100)
print(f"{'opcion':<42}{'estado':>9}{'recuerda':>10}{'tiempo min.':>13}{'bloques':>13}{'coste':>16}")
for nombre, muestras, bpm, llenar, ventana in opciones:
    n, est, rec, t, b, c = fila(nombre, muestras, bpm, llenar, ventana)
    print(f"{n:<42}{est:>7.1f} MB{rec:>7.0f} d{t:>11.1f} d{b:>13,.0f}{c:>13,.0f} ZZK".replace(",", " "))
print("""
Lectura:
  - 'tiempo min.' es lo que tarda el atacante aunque pague: las muestras estan repartidas en el tiempo,
    y solo puede mover la mediana cuando la mitad de la ventana sea suya.
  - 'coste' es lo que paga en tarifas para llenar los bloques que cuentan, a la tarifa minima corregida.
  - En la opcion 2 el atacante SABE que bloques se muestrean (altura multiplo de 120) y solo llena esos:
    mismo tiempo que la opcion 1, pero el coste cae 120x. Es la palanca que el muestreo abre.
  - En la opcion 4 cada muestra es la mediana de 120 bloques: para moverla hay que llenar 61 de los 120.
    Mismo estado que la 2, coste solo 2x menor que la 1, mismo tiempo. Estimador distinto (mediana de
    medianas), no identico: necesita su propio analisis.
  - La opcion 3 pierde el ciclo estacional (SPEC.md:928-934) y ademas se mueve 12x mas rapido.
""")
print("Referencia: inflar 1 GB de cadena cuesta 543 590 ZZK; el suministro total son 1 000 000 000 ZZK.")
