#!/usr/bin/env python3
"""
verif_quorum_soluciones.py — que daria un gadget de finalidad por QUORUM DE SOLUCIONES en ZEROX.

Teoria: Keller y Bohme, "HotPoW: Finality from Proof-of-Work Quorums" (research/fuentes/hotpow.txt).
  - cada solucion del recurso escaso (alli trabajo, aqui espacio) da UNA capacidad de voto (ATV)
  - k votos por el MISMO valor = k-quorum
  - dos quorums en conflicto exigen >= 2k ATVs asignados, luego
        POA(k, t) = P[ Poisson(lambda*t) >= 2k ]
    y en el tiempo esperado de quorum (t = k/lambda):
        POA(k) = P[ Poisson(k) >= 2k ]     <- independiente de lambda (Corolario 2 del paper)
  - "Sibyl attacks are mitigated by the scarcity of votes": no hace falta registro ni dinero.

Aqui se evalua como GADGET sobre el DAG, no como sustituto del consenso.
lambda = 1 solucion/s (rama A''), luego un k-quorum tarda ~k segundos.
"""
from math import comb, exp, log, lgamma
def poisson_sf(lam, n):
    """P[Poisson(lam) >= n], estable para lam grande."""
    # suma de la cola en logaritmos
    tot = 0.0
    k = n
    while True:
        lp = -lam + k*log(lam) - lgamma(k+1)
        term = exp(lp)
        tot += term
        if k > lam and term < tot*1e-17 and k > n+10: break
        k += 1
        if k > lam*40 + 2000: break
    return tot
LAM = 1.0
print("=== Gadget de finalidad por quorum de soluciones, sobre el DAG ===")
print(f"lambda = {LAM:.0f} solucion/s. Un k-quorum tarda ~k segundos.\n")
print(f"{'k':>6}{'tiempo del quorum':>20}{'P(dos quorums en conflicto)':>30}{'bytes del certificado':>23}")
for k in (16,32,64,96,128,192,256):
    poa = poisson_sf(k, 2*k)
    # certificado: k firmas Ed25519 (64 B) + k claves (32 B); con agregacion BLS, 48 B + mapa
    ed = k*96
    bls = 48 + (k+7)//8
    print(f"{k:>6}{k:>17} s{poa:>30.2e}{ed:>15,} B / {bls} B".replace(",", " "))
print("\n  La probabilidad cae ~e^(-0,386k): es el parametro de seguridad, como el tamano de clave.")
print("  Comparacion: Bitcoin con k = 1 tiene POA = 0,264, y el paper lo valida con datos historicos.")
print("\n=== Frente a lo que tenemos hoy ===")
import sys; sys.path.insert(0,'research/scripts/d9-ronda9a')
from r9a_a3_frontera import prev
print(f"{'espera':>12}{'riesgo hoy (alpha=33 %)':>26}{'quorum equivalente':>22}")
for t in (60,120,300,600):
    p = prev(0.33,1.0,float(t),90,1.0)
    # que k da la misma garantia
    kk = next((k for k in range(8,400) if poisson_sf(k,2*k) <= max(p,1e-30)), None)
    print(f"{t:>10} s{p:>26.1e}{('k = '+str(kk)) if kk else '—':>22}")
