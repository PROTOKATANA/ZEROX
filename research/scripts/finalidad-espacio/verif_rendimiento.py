#!/usr/bin/env python3
"""
Techo de rendimiento de ZEROX = PoST + DAG + capa de finalidad.
Todo con constantes YA FIJADAS del proyecto, no inventadas:
  ZONA_LIBRE = 100 000 B/bloque, FACTOR_SURGE = 50, LIMITE = 2*M   (DECISIONES §11)
  tx transparente ~350 B (2-in-2-out), accion Orchard ~820 B       (SPEC §6.5, §9)
  lambda = 1 bloque/s (rama A''), T original = 120 s
  PoT verify = 96,1 ms/slot MEDIDO; Ed25519 verify = 47,5 us MEDIDO hoy
"""
TX_B, ACC_B = 350, 820
ZONA_LIBRE, T_ORIG, SURGE = 100_000, 120, 50
LAMBDA = 1.0
POT_MS, ED_US = 96.1, 47.5
ANNO = 365 * 86400

print("=" * 74)
print("A) El TPS lo fija el PRESUPUESTO DE BYTES, ya decidido. El DAG no lo toca.")
print("=" * 74)
bps_libre = ZONA_LIBRE / T_ORIG          # bytes/s de la zona libre
print(f"  zona libre: {ZONA_LIBRE:,} B por bloque de {T_ORIG} s = {bps_libre:,.0f} B/s")
print(f"  crecimiento: {bps_libre*ANNO/1e9:.1f} GB/ano   (DECISIONES dice 26,3)")
print()
print(f"{'regimen':<34} {'B/s':>10} {'tx/s':>9} {'GB/ano':>9}")
for etiq, b in [("zona libre (sin penalizacion)", bps_libre),
                ("pico con FACTOR_SURGE = 50", bps_libre * SURGE)]:
    print(f"{etiq:<34} {b:>10,.0f} {b/TX_B:>9.1f} {b*ANNO/1e9:>9.1f}")
print()
print("  MISMO numero con T=120 s y con lambda=1 b/s: el DAG reparte los mismos")
print("  bytes en 120 bloques pequenos en vez de 1 grande.")

print()
print("=" * 74)
print("B) Que compra cada capa, entonces")
print("=" * 74)
print(f"{'magnitud':<28} {'antes':>16} {'despues':>16} {'quien':>10}")
print(f"{'tx/s sostenidas':<28} {'2,4':>16} {'2,4':>16} {'nadie':>10}")
print(f"{'latencia a inclusion':<28} {'120 s':>16} {'1 s':>16} {'DAG':>10}")
print(f"{'finalidad':<28} {'2 h':>16} {'~30 s':>16} {'capa':>10}")
print(f"{'cliente ligero (GB/ano)':<28} {'21,5 o nada':>16} {'0,0066':>16} {'capa':>10}")

print()
print("=" * 74)
print("C) Si se quisiera SUBIR el TPS, que se rompe primero (nodo domestico)")
print("=" * 74)
nucleos, sub_mbps, ssd_tb = 8, 50, 4
print(f"  Supuesto de nodo domestico: {nucleos} nucleos, {sub_mbps} Mbps de SUBIDA, SSD {ssd_tb} TB")
print()
print(f"{'recurso':<30} {'tope tx/s':>12} {'nota':<28}")
# 1) CPU firmas: 2 verificaciones por tx
tps_cpu = (nucleos * 1e6 / ED_US) / 2
print(f"{'CPU, firmas Ed25519':<30} {tps_cpu:>12,.0f} {'cota alta: 47,5 us medido':<28}")
# 2) CPU PoT: constante, no escala con tx
print(f"{'CPU, PoT (96,1 ms/slot)':<30} {'n/a':>12} {'9,6 % de UN nucleo, fijo':<28}")
# 3) subida: cada nodo retransmite a ~8 pares
pares = 8
tps_net = (sub_mbps * 1e6 / 8) / (TX_B * pares)
print(f"{'Red, subida con {} pares'.format(pares):<30} {tps_net:>12,.0f} {'el gossip multiplica':<28}")
# 4) almacenamiento
for anos in [5, 10]:
    tps_ssd = (ssd_tb * 1e12 / anos / ANNO) / TX_B
    print(f"{'SSD lleno en ' + str(anos) + ' anos':<30} {tps_ssd:>12,.0f} {'solo cadena, sin indices':<28}")
print()
print("  El que manda es la RED, no la CPU. Y por debajo de todos ellos manda")
print("  la decision de presupuesto: 26,3 GB/ano = 2,4 tx/s.")

print()
print("=" * 74)
print("D) Coste de la capa de finalidad en CPU (K=4000, cert cada 30 s)")
print("=" * 74)
print("  BLS agregada: ~2 ms por certificado -> 0,007 % de un nucleo")
print("  Frente al PoT, que es 9,6 %. La capa es ruido.")
