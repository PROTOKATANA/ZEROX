#!/usr/bin/env python3
"""
Lo que la capa de finalidad le hace al CLIENTE LIGERO.
El diseno vivo lo daba por perdido: 'SPV sin confianza no existe en GHOSTDAG
y no lo arregla ningun parametro' (dag-poas-ancla-de-orden.md:441).
F3: 'Verifying the finality of a tipset from genesis does not require access
to the EC chain' (FIP-0086), porque cada certificado lleva el CID de la tabla
de poder que valida la SIGUIENTE instancia (SupplementalData.PowerTable).
"""
import math

ANNO = 365 * 86400
CERT_META, BLS_SIG, CID = 128, 96, 32

def cert(K):
    return CERT_META + BLS_SIG + math.ceil(K / 8) + CID  # + compromiso de la tabla siguiente

print("=" * 72)
print("A) Lo que un cliente ligero debe descargar por ano")
print("=" * 72)
print(f"{'modelo':<44} {'GB/ano':>10}")
print(f"{'-'*44} {'-'*10}")
print(f"{'HOY: nodo completo, cabeceras a 1 bloque/s':<44} {21.5:>10.2f}")
K = 4000
for per, etiq in [(10, "cada 10 s"), (30, "cada 30 s"), (300, "cada 5 min"), (3600, "cada 1 h")]:
    gb = cert(K) * (ANNO / per) / 1e9
    print(f"{'certificados K=4000, ' + etiq:<44} {gb:>10.4f}")

print()
print("=" * 72)
print("B) Coste de ponerse al dia tras N dias desconectado")
print("=" * 72)
print(f"{'dias':>6} {'cabeceras (MB)':>16} {'certs 30 s (MB)':>17} {'certs 1 h (MB)':>16}")
for d in [1, 7, 30, 365]:
    seg = d * 86400
    hdr = 492 * seg / 1e6
    c30 = cert(K) * (seg / 30) / 1e6
    c3600 = cert(K) * (seg / 3600) / 1e6
    print(f"{d:>6} {hdr:>16.1f} {c30:>17.1f} {c3600:>16.2f}")

print()
print("=" * 72)
print("C) Comparacion con Bitcoin SPV (el listor del diseno vivo)")
print("=" * 72)
print("  Bitcoin, SPV en un movil, cadena entera: 71 MB, sin confiar en nadie")
for per, etiq in [(30, "30 s"), (3600, "1 h")]:
    mb = cert(K) * (ANNO / per) / 1e6
    print(f"  ZEROX, certificados cada {etiq:>4}, UN ano: {mb:8.1f} MB")
    print(f"     -> anos de cadena que caben en los 71 MB de Bitcoin: {71/mb:6.2f}")

print()
print("=" * 72)
print("D) Lo que ADEMAS necesita el cliente para su propia transaccion")
print("=" * 72)
print("  Prueba de Merkle de inclusion en el bloque certificado:")
for n in [1000, 10000]:
    print(f"    bloque de {n:6d} tx -> {32*math.ceil(math.log2(n)):4d} B de camino")
print("  Es el modelo SPV de Bitcoin, recuperado. No existe hoy en el DAG.")
