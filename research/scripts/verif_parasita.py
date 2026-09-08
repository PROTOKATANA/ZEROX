#!/usr/bin/env python3
"""
verif_parasita.py — modelo cerrado (mio, agente principal) de la «cadena parasita» de D8-A1,
para contrastar con lo que D8 midio (d8-ronda8/salida_a1b.txt).

Mecanismo, leido de la regla k-cluster de GHOSTDAG (protocol.rs:250, check_blue_candidate):
  - El atacante encadena en privado A_1 -> A_2 -> ... ; cada A_j fusiona la vista honesta.
  - A_1 es bloque de cadena (azul). Su anticono azul solo admite k bloques honestos: los honestos
    creados tras t_1 - Delta son azules en la vista privada hasta que se llenan los k; despues,
    TODO honesto nuevo es rojo en esa vista (empujaria el anticono azul de A_1 por encima de k).
  - Ventaja del atacante al publicar J bloques (duracion T = J/(alpha*lam)):
        privada = bw(fork) + k + J           honesta = bw(fork) + (1-alpha)*lam*T = J*(1-alpha)/alpha
    esta por delante  <=>  k + J > J(1-alpha)/alpha  <=>  J < J* = k*alpha/(1-2*alpha)
  - Rojos por rafaga: honestos creados tras la saturacion: (1-alpha)*lam*T - k = J(1-alpha)/alpha - k
        delta_rafaga(J) = 1 - k*alpha/(J*(1-alpha))
Prediccion: J* medido por D8 deberia estar cerca de k*alpha/(1-2*alpha) (en su rejilla {16,31,48,64,96}),
y delta medido <= delta_rafaga(J*) (D8 mide sobre todo el horizonte, con rafagas fallidas y esperas).
"""
k = 30
rejilla = [16, 31, 48, 64, 96]
D8 = {  # alpha: (J*, delta medido) de d8-ronda8/salida_a1b.txt
    0.25: (16, 0.1544), 0.30: (31, 0.2079), 0.33: (31, 0.2867), 0.35: (31, 0.3065),
    0.37: (48, 0.3448), 0.40: (48, 0.4366), 0.45: (64, 0.5834)}
print(f"{'alpha':>6} {'J* teorico':>11} {'J* rejilla':>11} {'J* D8':>6} | {'delta_rafaga(J*)':>17} {'delta D8':>9} {'ratio':>6}")
for a, (Jd8, dd8) in D8.items():
    Jt = k * a / (1 - 2 * a)
    Jr = min(rejilla, key=lambda J: abs(J - Jt))
    # el atacante solo puede usar J <= J*: toma el mayor de la rejilla que no lo supere (o el minimo)
    Jle = max([J for J in rejilla if J <= Jt] or [rejilla[0]])
    dr = 1 - k * a / (Jd8 * (1 - a))
    print(f"{a:>6.2f} {Jt:>11.1f} {Jle:>11d} {Jd8:>6d} | {dr:>17.3f} {dd8:>9.4f} {dd8/dr if dr>0 else float('nan'):>6.2f}")
print("\nLectura: si J* de D8 coincide con el mayor punto de la rejilla <= k*alpha/(1-2alpha), y delta_D8 < delta_rafaga,")
print("el mecanismo medido es el del modelo (ventaja inicial k por la regla k-cluster + carrera alpha vs 1-alpha).")
print("Umbral de existencia: J* -> infinito cuando alpha -> 1/2 (Nakamoto); el Lema 9 del paper solo cuenta 2*D*lam rojos porque")
print("supone un evento unico de k+1 bloques, no una cadena que crece mientras esta por delante.")
