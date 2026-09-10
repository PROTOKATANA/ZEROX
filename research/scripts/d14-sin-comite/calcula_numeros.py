#!/usr/bin/env python3
"""D14C · numeros del inventario sin comite.

Solo aritmetica y lectura de constantes ya publicadas; no hay simulacion
estocastica (por eso no hay semillas ni parametro alpha de adversario simulado).
Cada numero cita su fuente en el informe.
"""
import math

def prism_c1(beta):
    # Prism, arXiv:1810.08092v4, Theorem 4.8:
    # c1(b) = 5400(1-b) / [(1-2b)^3 * ln((1-b)/b) * ln(50/(1-2b))]
    return 5400.0 * (1 - beta) / ((1 - 2 * beta) ** 3
                                  * math.log((1 - beta) / beta)
                                  * math.log(50 / (1 - 2 * beta)))

def prism_c2(beta):
    # c2(b) = 54000 / [(1-2b)^3 * ln(50/(1-2b))]
    return 54000.0 / ((1 - 2 * beta) ** 3 * math.log(50 / (1 - 2 * beta)))

def suelo_ghostdag(k, alpha, lam):
    # catalogo D6 / d9-ronda10c: 3k/((1-alpha)lam)
    return 3.0 * k / ((1 - alpha) * lam)

print("=" * 78)
print("D14C · numeros del inventario sin comite (ZEROX: lambda = 1 bloque/s, k = 30, D = 4 s)")
print("=" * 78)

print("\n[1] Baseline GHOSTDAG · suelo estructural 3k/((1-alpha)lambda), k=30, lambda=1")
print("    fuente: research/dag-poas-catalogo-problemas-ataques.md:63 (D6)")
for a in (0.10, 0.25, 0.33, 0.40):
    print(f"    alpha={a:.2f} -> {suelo_ghostdag(30, a, 1.0):7.1f} s")

print("\n[2] Finalidad dura de protocolo C-REORG-07 (SPEC.md:1797-1804)")
bloques = 11999
lam = 1.0
print(f"    MAX_REORG_LENGTH = {bloques} bloques a lambda = {lam}/s -> {bloques / lam / 3600:.2f} h")
print("    (COINBASE_MATURITY = 12 000, SPEC.md:1514)")

print("\n[3] Prism (arXiv:1810.08092v4, Theorem 4.8) · cota teorica, D = 4 s")
print("    T_irrev <= max( c1(beta)*D , c2(beta)*(Bv/C)*ln(1/eps) ) segundos")
for b in (0.25, 0.33):
    c1, c2 = prism_c1(b), prism_c2(b)
    print(f"    beta={b:.2f}: c1={c1:9.1f} rondas -> c1*D = {c1 * 4:10.1f} s = {c1 * 4 / 3600:6.2f} h")
    print(f"              c2={c2:9.1f} (multiplica Bv/C * ln(1/eps); Bv/C no fijado en ZEROX)")

print("\n[4] PoST/VDF · umbral de honestidad con double dipping (Chia greenpaper 2026, ec. 2)")
print("    space_h * vdf_h > space_a * vdf_a * 1.47")
for factor in (1.0, 1.47):
    print(f"    factor={factor:.2f} -> espacio honesto minimo = {factor / (1 + factor) * 100:5.1f} %")

print("\n[5] Referencias de latencia de cadenas PoST sin comite")
print("    Autonomys: SLOT_DURATION = 1000 ms, SLOT_PROBABILITY = (1,6) -> 6 s/bloque")
print("      confirmation_depth_k = 100 (archiver) -> 600 s de PROFUNDIDAD DE ARCHIVADO,")
print("      no finalidad de usuario (subspace-runtime-primitives/src/lib.rs:219-225;")
print("      sc-consensus-subspace/src/archiver.rs:601-603)")
print("    Chia: bloque = 28.125-37.5 s de VDF (greenpaper 2026, linea 218)")
print("    Filecoin EC: 900 epocas x 30 s = 7.5 h (FIP-0086, lineas 16 y 21)")

print("\n[6] DAGKNIGHT (ronda 14A, no repetido): medido en ZEROX")
print("    eps=0.05: media 6.10 s (alpha=0.25) a 12.32 s (alpha=0.40); minimo 0.36 s")
print("    eps=1e-12: 15.76 s (alpha=0.10) a 108.69 s (alpha=0.40)")
print("    con ataque de inflacion de k* a Delta>=16 el suelo vuelve a 90-250 s")
print("    fuente: research/scripts/d14-dagknight/informe.md:127-130, 179-183")

print("\n[7] GHOSTDAG/PHANTOM y SPECTRE · ejemplo del paper (lambda=1/s, 2D=7 s, k=16,")
print("    alpha<=0.25, eps=0.1 %)")
print("    GHOSTDAG: ~45 s ; SPECTRE: ~21 s (phantom-ghostdag.txt:824-837)")
print("    Kaspa real: 70,4 % de primeras confirmaciones <=10 s; maximo observado 746 s")
print("    (phantom-ghostdag.txt:884-893)")
