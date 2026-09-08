#!/usr/bin/env python3
"""
D8 ronda 10a · C — coste de la revelacion retardada (h), con numero.

Tabla pedida por el encargo: `(I, F)` -> VDF en vuelo, nucleos del timekeeper, fraccion de nucleo
de verificacion por nodo, bytes por epoca en justificacion, latencia anadida.

Los dos costes unitarios se leen del artefacto de Criterion de esta maquina (mismo control C0 que
en B.2): `prove` y `verify` de `subspace-proof-of-time`. El tamano del checkpoint sale del tipo:
`PotCheckpoints` son `NUM_CHECKPOINTS = 8` (`subspace-core-primitives/src/pot.rs:332`) por
`PotOutput::SIZE = 16` bytes (`pot.rs:274`) = 128 B por slot.

Dos vias de publicacion, y hay que elegir una (es una decision de diseno, no un detalle):
  (P1) TODO en la justificacion del primer bloque con `slot >= t_j`: L*128 B de una vez.
  (P2) por GOSSIP segun se calcula, como el PoT ordinario (`sc-proof-of-time/src/source/gossip.rs:72`),
       y en el bloque solo el compromiso de 16 B. El caudal se reparte entre los L segundos.

Criterio alpha: la unica columna que depende de alpha es la del menu `m(alpha)` de la disciplina
especulativa; se da la fila alpha = 0 (m = 1) y la fila alpha = 0,40 (m = 1,83).
"""
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from r10a_lib import LAM, POT_BYTES_SLOT, S_MAX, menu   # noqa: E402

CRIT = "/home/katana/zeo/fuentes/subspace/target/criterion"
NUCLEOS = os.cpu_count() or 1
# (I, F) del encargo mas las dos filas de referencia del diseno vigente
CONF = [(851.0, 7200.0), (300.0, 7200.0), (851.0, 3600.0), (300.0, 3600.0),
        (4200.0, 19080.0), (851.0, 1019.0)]
ENLACES = {"1 Mbit/s": 1e6, "10 Mbit/s": 1e7, "100 Mbit/s": 1e8, "1 Gbit/s": 1e9}


def lee_criterion(nombre):
    with open(os.path.join(CRIT, nombre, "new", "estimates.json")) as f:
        return json.load(f)["mean"]["point_estimate"] / 1e9


def calibracion(prove, verify):
    """C.5 — la identidad que decide el punto D: proteccion y coste son el MISMO numero.

      rho* = (L + I)/(I + W_dec)      (B.1, verificado con 14 semillas)
      coste de verificacion = 1 + L/I  (B.2, medido)
      => rho* = (1 + L/I) * I/(I + W_dec)   con W_dec << I, rho* ~= el multiplicador de coste.

    Luego, dado un `rho_max` que se quiera tolerar, la `I` MINIMA que hace falta es
      I <= (L - rho_max*W_dec)/(rho_max - 1)
    y el coste queda clavado en ~rho_max. Pagar mas coste que `rho_max` es tirar CPU."""
    print("=" * 132)
    print("C.5 — CALIBRACION: la proteccion de (h) y su coste son el mismo numero")
    print("      I* = (L - rho_max*W_dec)/(rho_max - 1) es la I que iguala rho* a rho_max exactamente")
    print(f"{'rho_max':>8} {'L (h)':>7} {'W_dec':>6} | {'I* (s)':>9} {'I* (h)':>7} {'q':>3} | "
          f"{'rho* comprobado':>16} {'coste 1+L/I':>12} {'nucleos/nodo':>13} | {'I+F (h)':>8}")
    for rmax in (1.5, 2.0, 2.5, 3.0):
        for L, W in ((7200.0, 45.0), (3600.0, 45.0), (7200.0, 20.0)):
            I = (L - rmax * W) / (rmax - 1.0)
            print(f"{rmax:>8.1f} {L/3600:>7.2f} {W:>6.0f} | {I:>9.0f} {I/3600:>7.2f} "
                  f"{math.ceil(L/I):>3d} | {(L+I)/(I+W):>16.2f} {1+L/I:>12.2f} "
                  f"{L*verify/I:>13.3f} | {(I+L)/3600:>8.2f}")
    print("  Comparacion con la calibracion vigente (I = 851 s, F = 2 h): rho* = 9,24 (mucho mas de lo")
    print("  que hace falta: el techo fisico estimado es 1,5-2,5x) y coste 9,46x / 0,813 nucleos.")
    print("  Con rho_max = 2,5 basta I = 4 725 s: mismo techo util, coste 2,52x / 0,147 nucleos (5,5x menos).")
    print("  Lo que se paga a cambio: I+F pasa de 0,93 h a 3,31 h (lookahead del plotter, 9c §D).")


def main():
    prove = lee_criterion("prove")
    verify = lee_criterion("verify")
    ancho = "=" * 132

    print(ancho)
    print("CONTROL C0 — costes unitarios leidos del artefacto de Criterion de esta maquina")
    print(f"  prove = {prove:.6f} s/slot · verify = {verify:.6f} s/slot · asimetria {prove/verify:.2f}x")
    print(f"  128 B/slot de PotCheckpoints (8 x 16 B) · {NUCLEOS} hilos en esta maquina")

    print(ancho)
    print("C.1 — TABLA DE COSTE de (h), por pareja (I, F=L)")
    print(f"{'I':>5} {'F=L (h)':>8} {'q=L/I':>7} | {'VDF en vuelo (i)':>17} {'(ii) m=1,83':>12} | "
          f"{'nucleos timekeeper':>19} | {'nucleo/nodo verif.':>19} {'x sin (h)':>10} | "
          f"{'justif. P1':>11} {'gossip P2':>11}")
    for I, L in CONF:
        q = math.ceil(L / I)
        n_ii = math.ceil(menu(0.40) * q)
        nucleo_verif = L * verify / I                  # continuo, ademas del 9,61 % de la principal
        p1 = L * POT_BYTES_SLOT
        p2 = q * POT_BYTES_SLOT                        # B/s: q cadenas a 128 B por slot
        print(f"{I:>5.0f} {L/3600:>8.2f} {q:>7d} | {q:>17d} {n_ii:>12d} | {q+1:>19d} | "
              f"{nucleo_verif:>19.3f} {1 + L/I:>10.2f} | {p1/1024:>8.0f} kB {p2:>8.0f} B/s")
    print(f"  Referencia sin (h): 1 linea en el timekeeper, {verify:.4f} s/slot = {verify*100:.2f} % de")
    print(f"  un nucleo por nodo, {S_MAX*POT_BYTES_SLOT/1024:.1f} kB de justificacion por bloque (R-FIN-14 (d)).")

    print(ancho)
    print("C.2 — LATENCIA ANADIDA. (P1) mete L*128 B en UN bloque por epoca; (P2) no mete nada.")
    print("      `Delta` es la variable de la que depende la frontera (46,9 % a 4 s, 32,4 % a 20 s, 9a),")
    print("      asi que un blob por epoca no es gratis: se mide contra Delta = 4 s.")
    print(f"{'I':>5} {'F=L (h)':>8} | " + " ".join(f"{e:>13}" for e in ENLACES) +
          f" | {'% de Delta=4 s (10 Mbit/s)':>27}")
    for I, L in CONF:
        p1 = L * POT_BYTES_SLOT * 8.0
        ts = [p1 / v for v in ENLACES.values()]
        print(f"{I:>5.0f} {L/3600:>8.2f} | " + " ".join(f"{t:>11.3f} s" for t in ts) +
              f" | {p1/1e7/4.0:>26.1%}")
    print("  (P2) reparte esos mismos bytes entre L segundos y por q cadenas: el caudal esta en C.1,")
    print("  y a 1 Gbit/s son microsegundos. La latencia anadida de (P2) es CERO: la revelacion")
    print("  esta en la red desde antes de `t_j`, y el bloque solo lleva 16 B de compromiso.")

    print(ancho)
    print("C.3 — PRESUPUESTO DE UN NODO COMPLETO a tau = 1 s, en nucleos continuos")
    print(f"{'I':>5} {'F=L (h)':>8} | {'cadena principal':>17} {'revelacion (h)':>15} {'total':>8} "
          f"{'% de un 9950X3D (32 hilos)':>27}")
    for I, L in CONF:
        base = verify / 1.0
        rev = L * verify / I
        print(f"{I:>5.0f} {L/3600:>8.2f} | {base:>17.4f} {rev:>15.3f} {base+rev:>8.3f} "
              f"{(base+rev)/NUCLEOS:>26.2%}")

    print(ancho)
    print("C.4 — PRESUPUESTO DEL TIMEKEEPER, en nucleos, y que maquina hace falta")
    print(f"{'I':>5} {'F=L (h)':>8} {'q+1':>5} | {'disciplina (i)':>15} {'disciplina (ii) m=1,83':>23} "
          f"{'(ii) m maximo = 1+lam*S_max':>28}")
    for I, L in CONF:
        q = math.ceil(L / I)
        print(f"{I:>5.0f} {L/3600:>8.2f} {q+1:>5d} | {q+1:>15d} {math.ceil(menu(0.40)*q)+1:>23d} "
              f"{math.ceil((1+LAM*S_MAX)*q)+1:>28d}")
    print("  La disciplina (ii) con el `m` maximo NO es una maquina: es un centro de datos.")
    print("  La regla (h.1) tiene que acotar `m` por politica, o la disciplina (i) con Lrev < L.")

    calibracion(prove, verify)


if __name__ == "__main__":
    main()
