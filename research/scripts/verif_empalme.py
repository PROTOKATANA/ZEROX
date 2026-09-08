#!/usr/bin/env python3
"""
Empalme phi_c (CONTEO, BDK+19) con blue_work (PESO, GHOSTDAG). Reducción:
  Kaspa: blue_work = blue_work(sp) + sum_{azules del mergeset} calc_work(bits)   (protocol.rs:155-161)
         calc_work = 2^256/(target+1)                                              (difficulty.rs:211-217)
  => el peso de un azul es w(SR) de SU propio bloque. Si SR es constante en la ventana de la carrera,
     peso = conteo x w y phi_c aplica EXACTAMENTE. La brecha es la variacion relativa de w a lo largo
     del horizonte de la carrera (profundidad F), gobernada por el retarget de la ronda 3:
     ln SR_{n+1} = ln SR_n - gamma (ln N_obs - ln N_obj), ventana W slots, 0<gamma<2.
  Con N_obs ~ Poisson(N_obj): cada paso mueve ln SR ~ gamma/sqrt(N_obj); en F/W pasos la desviacion
  tipica de ln w es  s = gamma * sqrt(F / (W^2 * lambda_blue)).  Un sesgo de peso relativo eps entre
  bloques del atacante y honestos equivale a alpha_ef = alpha (1+eps) en la carrera.
"""
import math
F, LAM_BLUE = 3.2*3600, 1.0*(1-8/33)          # horizonte (s) y tasa azul a q=1, delta=0,2424
print(f"F={F:.0f}s  lambda_blue={LAM_BLUE:.3f}/s\n")
print(f"{'W (slots)':>10} {'N_obj':>7} | " + " | ".join(f"gamma={g:<4}" for g in (0.25,0.5,1.0,1.5)))
print("-"*62)
for W in (60, 300, 900, 3600, 11520):
    N = LAM_BLUE*W
    fila = [math.exp(g*math.sqrt(F/(W*W*LAM_BLUE)))-1 for g in (0.25,0.5,1.0,1.5)]
    print(f"{W:10d} {N:7.0f} | " + " | ".join(f"{e:9.2%}" for e in fila))
print("\nLectura: desviacion tipica RELATIVA del peso de un bloque a lo largo del horizonte F.")
print("Efecto sobre el umbral: alpha_ef = alpha(1+eps). Con alpha=0,35 y eps=5 %: alpha_ef=0,3675;")
print("con eps=1 %: 0,3535. El empalme es exacto salvo eps, y eps lo fija (gamma, W).")
print("\nCondicion para eps <= 1 % :  gamma * sqrt(F/(W^2 lambda_blue)) <= 0,01")
for g in (0.25,0.5,1.0):
    Wmin = g*math.sqrt(F/LAM_BLUE)/0.01
    print(f"   gamma={g:<4} -> W >= {Wmin:8.0f} slots = {Wmin/3600:5.2f} h")
