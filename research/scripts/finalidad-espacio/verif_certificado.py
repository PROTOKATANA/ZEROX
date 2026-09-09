#!/usr/bin/env python3
"""
Coste de la capa de finalidad en ZEROX: tamano del comite y del certificado.
ZEROX firma con Ed25519 (C-ENC-07, C-HDR-04): NO agrega.
Filecoin F3 usa BLS agregada (FIP-0086: 'always a BLS key').
"""
import math

LAMBDA = 1.0        # bloques/s
ED_SIG, ED_PK = 64, 32
BLS_SIG_AGG = 96    # firma agregada BLS12-381 (G2 comprimido)
CERT_META = 128     # cabecera del certificado: instancia, tipset, cid tabla, etc.

def cert_bytes(K, esquema, idx_bytes=2):
    if esquema == "ed25519":
        # una firma por miembro + indice en la tabla de poder
        return CERT_META + K * (ED_SIG + idx_bytes)
    if esquema == "bls":
        # firma agregada + bitmap de firmantes
        return CERT_META + BLS_SIG_AGG + math.ceil(K / 8)
    raise ValueError

print("=" * 76)
print("A) Tamano del certificado y coste anual, por periodo de finalizacion")
print("=" * 76)
print(f"{'K':>6} {'esquema':>9} {'cert':>10} {'cada 30s':>12} {'cada 10s':>12}")
for K in [100, 400, 1000, 3600]:
    for esq in ["ed25519", "bls"]:
        b = cert_bytes(K, esq)
        gb30 = b * (365 * 86400 / 30) / 1e9
        gb10 = b * (365 * 86400 / 10) / 1e9
        print(f"{K:>6} {esq:>9} {b:>8} B {gb30:>9.2f} GB {gb10:>9.2f} GB")

print()
print("=" * 76)
print("B) Comparacion con lo que ya cuesta la cadena (rama A'': 1 bloque/s)")
print("=" * 76)
# cabecera de 492 B (C-HDR-03) + PoT 128 B/slot
hdr = 492
gb_hdr = hdr * 365 * 86400 * LAMBDA / 1e9
gb_pot = 128 * 365 * 86400 / 1e9
print(f"  cabeceras a 1 bloque/s, 492 B: {gb_hdr:6.2f} GB/ano")
print(f"  PoT 128 B/slot, 1 slot/s:      {gb_pot:6.2f} GB/ano")
print(f"  (bitacora: 21,5 GB/ano de cabeceras; 4,0 GB/ano de PoT en A'')")

print()
print("=" * 76)
print("C) Verificacion por nodo")
print("=" * 76)
ED_VERIFY_US = 50      # us por firma Ed25519, orden de magnitud
BLS_VERIFY_MS = 2.0    # ms por firma agregada + agregacion de K claves
for K in [400, 1000]:
    ed_ms = K * ED_VERIFY_US / 1000
    for periodo in [10, 30]:
        print(f"  K={K:5d} ed25519: {ed_ms:6.1f} ms/cert -> {100*ed_ms/1000/periodo:6.3f} % de un nucleo (cada {periodo}s)")
        print(f"  K={K:5d} bls     : {BLS_VERIFY_MS:6.1f} ms/cert -> {100*BLS_VERIFY_MS/1000/periodo:6.3f} % de un nucleo (cada {periodo}s)")

print()
print("=" * 76)
print("D) Cuanto espacio cubre un comite de los K mayores")
print("=" * 76)
print("  Si el espacio se reparte segun Zipf (s=1) entre G granjeros,")
print("  fraccion del espacio cubierta por los K mayores:")
for G in [1000, 10000, 100000]:
    H_G = sum(1.0 / i for i in range(1, G + 1))
    for K in [100, 400, 1000]:
        if K > G:
            continue
        H_K = sum(1.0 / i for i in range(1, K + 1))
        print(f"    G={G:6d} granjeros, K={K:5d} miembros -> {100*H_K/H_G:5.1f} % del espacio")
