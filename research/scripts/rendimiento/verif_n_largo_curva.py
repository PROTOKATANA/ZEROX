#!/usr/bin/env python3
"""
verif_n_largo_curva.py — N_LARGO: coste de estado y coste del atacante en funcion de la ventana.

Que hace Mlt (C-WGT-05, C-WGT-08, SPEC.md:730): es el SUELO de la mediana efectiva y el ancla de la
tarifa minima (~1/Mlt^2). Inflarla sube la capacidad sin penalizacion y abarata la tarifa.
Freno estructural (C-WGT-04): lt_weight <= 1,7*Mlt, luego para subirla 1,7x hay que conseguir que la
MITAD de las muestras de la ventana sean del atacante.
Coste por bloque llenado: 1,7*ZONA_LIBRE bytes a la tarifa minima corregida (REF_WEIGHT = 384 000).
"""
BREK=10**8; ZL=100_000; TARIFA=54_359   # brek/peso, control en verif_zona_libre.py
LLENADO=int(1.7*ZL)
def fila(dias):
    W=int(dias*86400)                      # bloques = segundos a lambda = 1
    cruda=8*W                              # anillo de u64: obligatorio, hay que saber que sale
    con_orden=cruda+16*W                   # + multiconjunto ordenado compacto
    naive=cruda+32*W                       # + arbol con overhead de nodos
    tiempo=W/2/86400                       # dias: la mitad de la ventana, repartida en el tiempo
    coste=(W/2)*LLENADO*TARIFA/BREK        # ZZK en tarifas
    arranque=W*1e-6                        # s, a 1 us por bloque (secuencial por C-REORG-06)
    return W,cruda,con_orden,naive,tiempo,coste,arranque
print(f"{'ventana':>12}{'bloques':>13}{'anillo':>9}{'+orden':>9}{'naive':>9}{'mover Mlt':>12}{'coste':>16}{'% suministro':>13}{'arranque':>10}")
for nombre,dias in (("30 dias",30),("90 dias",90),("180 dias",180),("1 ano",365),("2 anos",730)):
    W,c,o,n,t,co,a=fila(dias)
    print(f"{nombre:>12}{W:>13,}{c/1e6:>7.0f} MB{o/1e6:>7.0f} MB{n/1e6:>7.0f} MB{t:>9.0f} d{co:>13,.0f} ZZK{co/1e9*100:>12.0f}%{a:>9.0f} s".replace(",", " "))
print("\n  'mover Mlt': tiempo minimo para subirla 1,7x aunque pague; la mitad de la ventana repartida en el tiempo.")
print("  'coste': tarifas de llenar esos bloques a 1,7*ZONA_LIBRE. Suministro total: 1 000 000 000 ZZK.")
print("  'arranque': recorrer la ventana calculando lt_weight al sincronizar (secuencial, C-REORG-06).")
print("\n  Opcion 4 (cubos de 120, mediana de medianas): 2,1 MB de estado con cualquier ventana,")
print("  pero cambia el estimador de C-WGT-05 y exige demostrar que no abre otra palanca.")
