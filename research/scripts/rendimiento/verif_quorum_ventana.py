#!/usr/bin/env python3
"""
verif_quorum_ventana.py — ¿arregla la equivocacion un umbral de 2/3 contra una VENTANA CERRADA de soluciones?

D12 (informe F.7) modela que CUALQUIER solucion puede votar por los dos valores, y obtiene POA ~0,5.
Pero los honestos no equivocan: solo las soluciones del atacante aparecen en dos certificados.

Regla candidata: un certificado para X en la ventana de slots [s, s+W) es valido si MAS DE 2/3 de las
soluciones de ESA ventana (conjunto fijo, verificable por el PoT, no inflable por Sybil de claves porque
partir el espacio no cambia cuantas soluciones salen) votan X.

Dos certificados en conflicto X e Y exigen:  h_X + a > 2T/3  y  h_Y + a > 2T/3,  con h_X + h_Y <= H, T = H + A
  sumando:  H + 2A >= h_X + h_Y + 2a > 4T/3   =>   A > T/3.
Luego SEGURIDAD <=> el atacante tiene menos de 1/3 de las soluciones de la ventana. Sin castigo: la
interseccion de quorums hace el trabajo que en HotPoW hacia el puzzle.
VIVEZA: si el atacante retiene sus votos, los honestos solos deben pasar 2/3: (1-a) > 2/3  =>  a < 1/3.
"""
from math import comb, exp, log, lgamma
def pmf(n,k,p): return exp(lgamma(n+1)-lgamma(k+1)-lgamma(n-k+1)+k*log(p)+(n-k)*log(1-p))
def sf(n,k,p):  # P[Bin(n,p) >= k]
    return sum(pmf(n,i,p) for i in range(max(0,k),n+1))

print("=== Seguridad: P(el atacante tiene > 1/3 de las soluciones de la ventana) ===")
print("(es la unica forma de que existan dos certificados en conflicto con honestos que no equivocan)")
print(f"{'W (soluciones)':>15}" + "".join(f"{'alpha='+str(a):>14}" for a in (0.10,0.20,0.25,0.30,0.33)))
for W in (64,128,256,512,1024,2048):
    fila=f"{W:>15}"
    for a in (0.10,0.20,0.25,0.30,0.33):
        fila+=f"{sf(W, W//3+1, a):>14.1e}"
    print(fila)

print("\n=== Viveza: P(los honestos solos NO pasan 2/3 si el atacante retiene) ===")
print(f"{'W (soluciones)':>15}" + "".join(f"{'alpha='+str(a):>14}" for a in (0.10,0.20,0.25,0.30,0.33)))
for W in (64,128,256,512,1024,2048):
    fila=f"{W:>15}"
    for a in (0.10,0.20,0.25,0.30,0.33):
        # honestos en la ventana ~ Bin(W, 1-a); falla si honestos <= 2W/3
        fila+=f"{1-sf(W, (2*W)//3+1, 1-a):>14.1e}"
    print(fila)

print("\n=== Comparacion con el modelo de D12 (todas las soluciones equivocan) ===")
def poa_d12(k):  # P[Poisson(k) >= k]
    return sum(exp(-k+i*log(k)-lgamma(i+1)) for i in range(k, 40*k))
for k in (64,256):
    print(f"  k={k}: D12 (todas equivocan) POA = {poa_d12(k):.3f}   |   ventana 2/3, alpha=0,25, W={k}: {sf(k,k//3+1,0.25):.1e}")
print("\nCRITERIO alpha: la probabilidad de conflicto debe crecer con alpha (si no, no mide nada).")
