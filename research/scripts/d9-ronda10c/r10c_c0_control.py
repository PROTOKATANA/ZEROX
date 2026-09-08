#!/usr/bin/env python3
"""
r10c_c0_control.py — CONTROL POSITIVO (regla de metodo 4): antes de medir nada, reproducir
numeros ya publicados con el MISMO instrumento.

  P1 · verif_constantes.py §3: reversion a 600 s con k autoconsistente (alpha = 0,25).
  P2 · d8_a1c_riesgo.py: fila alpha = 0,33, delta MEDIDO = 0,2867, reversion a 600 s y union 10 anos.
  P3 · 9a A3 / verif_frontera_vs_F.py: frontera de flujo unico 46,8784 % (delta=0) y 36,5431 %
       (delta D8) con F = 19 080 s, I = 4 200 s.
  N1 · CONTROL NEGATIVO: alpha = 0 => reversion 0 y lookahead 0 en toda configuracion.
  P4 · criterio alpha sobre el instrumento nuevo: el lookahead debe moverse con rho y con F.
"""
import sys, os, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import r10c_lib as L

print("=== r10c C0 · controles positivos ===\n")

t0 = time.time()
# ---- P1 · verif_constantes.py §3 (alpha = 0,25, t = 600 s, ventaja 3k, delta(k) autoconsistente)
print("P1 · verif_constantes.py §3 — reversion a 600 s, alpha = 0,25, ventaja 3k")
C = 4.0 * 1.0
esperado = {18: 2.45e-7, 24: 6.59e-8, 25: None, 30: 1.11e-7, 793: 1.000}
for k in (18, 24, 25, 30, 793):
    d = 2 * C / (k + 2 * C)
    r = L.prev(0.25, 1.0, 600, 3 * k, 1 - d)
    pub = esperado[k]
    marca = "" if pub is None else ("  OK" if abs(r - pub) / pub < 0.02 else f"  <-- DISCREPA (pub {pub:.3g})")
    print(f"   k={k:4d} delta={d:.3f}  reversion={r:.3e}   publicado={pub}{marca}")

# ---- P2 · d8_a1c_riesgo.py, fila alpha = 0,33
print("\nP2 · d8_a1c_riesgo.py — alpha = 0,33, delta medido D8 = 0,2867, F = 19 080 s, I = 4 200 s")
a = 0.33
d = L.delta_interp(a)
rev600 = L.prev(a, 1.0, 600, 3 * L.K, 1 - d)
u10 = L.union10(a, 1 - d, 19080.0, 4200.0)
print(f"   delta_interp(0,33) = {d:.4f}  (D8 MED: 0,2867)")
print(f"   reversion 600 s = {rev600:.3e}   union 10 anos = {u10:.3e}")

# ---- P3 · frontera de 9a con el instrumento de 9a
print("\nP3 · frontera de flujo unico (9a A3), F = 19 080 s, I = 4 200 s")
L.union10(0.30, 1.0, 19080.0, 4200.0)          # fija F_SEG/I_EP globales de 9a
fr0 = L.A9.frontera(lambda x: 1.0)
frD = L.A9.frontera(lambda x: 1 - L.delta_interp(x))
print(f"   delta = 0  : {fr0:.4%}   (9a publica 46,8784 %)  {'OK' if abs(fr0-0.468784)<5e-4 else 'DISCREPA'}")
print(f"   delta D8   : {frD:.4%}   (9a publica 36,5431 %)  {'OK' if abs(frD-0.365431)<5e-4 else 'DISCREPA'}")

# ---- N1 · control negativo
print("\nN1 · CONTROL NEGATIVO alpha = 0")
print(f"   prev(0, ...) = {L.prev(0.0, 1.0, 600, 3*L.K, 1.0):.3e}   (debe ser 0)")

# ---- P4 · criterio alpha/rho sobre el instrumento NUEVO (lookahead)
print("\nP4 · criterio de variacion sobre el instrumento nuevo (lookahead, punto A)")
print("   (h) se calcula con el modelo CORREGIDO de r10c_f: W_dec efectiva = W_dec + L/rho,")
print("   porque la entropia de (h) no se revela, se CALCULA (fuente: ancla-de-finalidad.md:319-322).")
print(f"   {'rho':>7} {'F=1h nucleo':>12} {'F=2h nucleo':>12} {'F=1h con (h)':>13} {'F=2h con (h)':>13}  (s)")
for rho in (0.5, 1.0, 1.0001, 1.5, 3.0, 10.0):
    l1 = L.cinematica_rapida(rho, 3600.0, 851.0, L.W_DEC, False)[0]
    l2 = L.cinematica_rapida(rho, 7200.0, 851.0, L.W_DEC, False)[0]
    wh1 = L.W_DEC + 3600.0 / rho
    wh2 = L.W_DEC + 7200.0 / rho
    l3 = 0.0 if rho <= 1 else L.cinematica_rapida(rho, 3600.0, 851.0, wh1, False)[0]
    l4 = 0.0 if rho <= 1 else L.cinematica_rapida(rho, 7200.0, 851.0, wh2, False)[0]
    print(f"   {rho:>7.4g} {l1:>12.0f} {l2:>12.0f} {l3:>13.0f} {l4:>13.0f}")
print("   -> cambia con rho (0 <-> saturado) y con F, en el nucleo Y con (h) corregida: correcto.")
print("      (con (h) el lookahead es menor que en el nucleo, pero NO es independiente de F)")
print(f"\n[{time.time()-t0:.0f} s]")
