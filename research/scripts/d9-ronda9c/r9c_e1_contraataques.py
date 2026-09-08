#!/usr/bin/env python3
"""
r9c_e1_contraataques.py — punto E: los contraataques a P4, con aritmetica explicita.

E1 · ¿PUEDE PRECOMPUTAR? El candidato `X` solo cambia la cadena de PoT en `t_j = slot(X)+L`,
     y la semilla de ahi es `blake3(entropia_X ‖ pot_output(t_j - 1))`
     (Autonomys: `PotOutput::seed_with_entropy`, pot.rs:288-294; aplicado en
     sp-consensus-subspace/src/lib.rs:118-129 SOLO si `parameters_change.slot == next_slot`).
     Luego para evaluar UN slot de un candidato hay que estar YA en el slot `t_j - 1` de la
     cadena comun. Eso es una CARRERA DE VDF contra el timekeeper.

     Cota de conocimiento: en el instante `t` el atacante conoce todas las entropias de
     inyecciones hasta `t_{j+1}` exclusive, donde `j` es la ultima epoca con ancla cerrada
     (`T_j + W_dec <= t`). Luego su POSICION MAXIMA POSIBLE es
         P_max(t) = slot(I_{j+1}) + L - 1  ~  t + (I - W_dec) + L
     -> VENTAJA MAXIMA sobre el timekeeper = L + I - W_dec  slots.

     Cota de velocidad: avanza `rho` slots por segundo (rho = AES del atacante / del
     timekeeper). La cota de conocimiento AVANZA a 1 slot/s en media (salta `I` slots cada
     `I` s). Luego:
        rho <= 1  ->  la ventaja NUNCA crece: si empieza en 0, se queda en 0  ->  n_eval = 0
        rho >  1  ->  la ventaja crece a (rho-1) slots/s hasta el tope: bootstrap
                      = (L + I - W_dec)/(rho-1) segundos; despues n_eval = rho*W_dec
                      por candidato SI tiene `m` unidades AES en paralelo (las cadenas
                      post-inyeccion de candidatos distintos son independientes).

E2 · Mantener varios candidatos abiertos MAS ALLA de W_dec sin reorganizar. Se mide en C
     (via i, retencion): W_dec ES por definicion el ultimo instante en que la accion cambia
     el ancla. Aqui solo se recuerda la cota estructural de R-FIN-1a.

E3 · ¿Que rho haria falta para evaluar la EPOCA ENTERA dentro de W_dec?  rho >= I/W_dec.

E4 · ¿Compensa acortar S_max solo por esto? Se responde con la medida de C
     (W_dec(20) vs W_dec(150)) y el coste de D8 A3 (71-75 % de bloques invalidos con 20 s
     de retraso de granjero).
"""
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

LAM = 1.0
# Constantes con fuente
L_F = 5.3 * 3600            # L = F medido, dag-poas-ancla-de-orden.md:141 y :162
I_EPOCA = 4200.0            # dag-poas-ancla-de-orden.md:156
PROVE = 1.561               # s/slot MEDIDO, ancla-de-orden.md (cargo bench, Ryzen 9 9950X3D)
VERIFY = 0.0961             # s/slot MEDIDO
ITERS = 206_557_520         # mainnet, subspace-node/src/chain_spec.rs:128-130

print("=" * 100)
print("E1 · la carrera de VDF: ventaja maxima, bootstrap y n_eval")
print(f"   L = {L_F:.0f} s  ·  I = {I_EPOCA:.0f} s  ·  tau = 1 s/slot")
print(f"{'W_dec':>7} {'ventaja tope (slots)':>21} | " +
      "  ".join(f"{'bootstrap rho='+f'{r}':>22}" for r in (1.0, 1.01, 1.05, 1.15, 1.5, 3.0)))
for W in (0, 45, 150, 225, 300):
    tope = L_F + I_EPOCA - W
    cols = []
    for r in (1.0, 1.01, 1.05, 1.15, 1.5, 3.0):
        if r <= 1.0:
            cols.append(f"{'INFINITO (n_eval=0)':>22}")
        else:
            b = tope / (r - 1.0)
            cols.append(f"{b/3600:>16.1f} h{'':>4}")
    print(f"{W:>7} {tope:>21.0f} | " + "  ".join(cols))

print()
print("   n_eval por candidato, una vez alcanzado el tope (m unidades AES en paralelo):")
print(f"{'W_dec':>7} | " + "  ".join(f"{'rho='+f'{r}':>10}" for r in (1.0, 1.01, 1.05, 1.15, 1.5, 3.0)))
for W in (0, 45, 150, 225, 300):
    print(f"{W:>7} | " + "  ".join(
        f"{(0 if r <= 1.0 else r*W):>10.0f}" for r in (1.0, 1.01, 1.05, 1.15, 1.5, 3.0)))

print()
print("=" * 100)
print("E3 · rho para evaluar la EPOCA ENTERA dentro de W_dec (rho >= I/W_dec)")
for I_ in (461, 856, 1293, 2500, 4200, 4890):
    print(f"   I = {I_:>5} s  " + "  ".join(
        f"W={w:>3}s: rho>={I_/w:>6.1f}" for w in (45, 150, 225, 300)))
print("   Cota fisica de rho: la cadena de PoT es AES-128 SECUENCIAL; rho = reloj_atacante /")
print("   reloj_referencia. Autonomys calibra `pot_slot_iterations` para ~1 s en el 14900KS a")
print("   6,2 GHz (subspace-node/src/chain_spec.rs:128-130), que es el TOPE del mercado:")
print("   rho realista ~1,0-1,2. rho >= 6 exigiria un reloj 6x el mejor del mercado.")

print()
print("=" * 100)
print("E5 · coste del atacante que mantiene la ventaja (m unidades + 1 comun), MEDIDO")
print(f"   prove = {PROVE:.3f} s/slot en el Ryzen 9 9950X3D (no llega a tau=1 s: rho_esa_maquina"
      f" = {1/PROVE:.3f} < 1)")
print(f"   verify = {VERIFY*1000:.1f} ms/slot  ·  asimetria prove/verify = {PROVE/VERIFY:.1f}x")
print(f"   iteraciones/slot mainnet = {ITERS:,}")
for m in (2.955, 23, 151):
    print(f"   m = {m:>7.3f}  ->  {math.ceil(m)+1:>4} nucleos dedicados solo a la evaluacion")
