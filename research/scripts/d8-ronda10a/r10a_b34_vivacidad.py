#!/usr/bin/env python3
"""
D8 ronda 10a · B.3 (vivacidad del timekeeper) y B.4 (particion y S_max).

B.3 · «El timekeeper debe sostener L/I cadenas de L*iter mas la principal. Con
      (I, F) in {(851 s, 2 h), (300 s, 2 h), (851 s, 1 h)}: cadenas en vuelo, nucleos de clase
      14900KS necesarios, y que ocurre si el timekeeper real va a 1,56 s/slot (esta maquina).
      Relacion con autonomys/subspace#2141: ¿empeora?»

      Lo que NO se puede responder de memoria: si `q + 1` cadenas de AES simultaneas corren a la
      misma velocidad que una sola. El bench de Autonomys `pot-compare-cpu-cores.rs` fija la
      afinidad a un nucleo CADA VEZ y mide de uno en uno (leido en el fuente), luego no lo dice.
      Aqui se MIDE con `r10a_b3_lineas.c`, que replica literalmente el nucleo de
      `subspace-proof-of-time/src/aes/x86_64.rs:22-33`.

      Control positivo: con 1 hilo el microbench tiene que reproducir el `prove` medido por
      Criterion en esta maquina (1,561 s/slot a 200 032 000 iteraciones), salvo la contabilidad
      de checkpoints.

B.4 · «Dos lados, dos flujos, dos VDF; al reunirse, R-FIN-5/7. ¿Introduce (h) un vector nuevo?»
      Se cuantifica: (i) cuanto se retrasa un lado con `c < q+1` nucleos; (ii) la palanca
      `Lrev < L`, que compra holgura al timekeeper al precio exacto
      `rho* = (Lrev + I)/(I + W_dec)`.

Este script NO es estocastico: es un banco de hardware. En vez de semillas usa REPETICIONES
(5 por punto, 9 en el control) y se queda con la MEJOR, porque la pregunta es de capacidad de la
maquina y hay otros agentes corriendo encima. La peor corrida se reporta al lado.
"""
import json
import math
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from r10a_lib import LAM, PROVE_S, S_MAX, VERIFY_S, menu, rho_cadena_comun, w_dec   # noqa: E402

CRIT = "/home/katana/zeo/fuentes/subspace/target/criterion"
SLOT_IT = 200032000          # iteraciones por slot del bench de Autonomys (pot.rs / bench)
NUCLEOS = os.cpu_count() or 1
BIN = os.environ.get("R10A_BIN", "/tmp/claude-1000/-home-katana-zeo-ZEROX/"
                                 "cbd8fc88-d59f-4aec-9776-6e8e65a4e650/scratchpad/r10a_b3_lineas")
CONF = [(851.0, 7200.0), (300.0, 7200.0), (851.0, 3600.0)]       # (I, F=L) del encargo


def lee_criterion(nombre):
    with open(os.path.join(CRIT, nombre, "new", "estimates.json")) as f:
        return json.load(f)["mean"]["point_estimate"] / 1e9


def mide_lineas(hilos, iters=120000000, reps=5):
    """Corre el microbench `reps` veces y devuelve el MEJOR (s/slot medio, s/slot del mas lento).

    Se toma el mejor y no la media a proposito: la pregunta de B.3 es de CAPACIDAD de la maquina
    ("¿caben q+1 lineas?"), y esta maquina tiene otros agentes corriendo encima. El mejor de `reps`
    es la corrida menos contaminada; el control de 1 hilo contra el `prove` de Criterion dice si
    queda contaminacion residual. Se reporta tambien la peor corrida para que se vea la dispersion."""
    mejor = (float("inf"), float("inf"))
    peor_m = 0.0
    for _ in range(reps):
        out = subprocess.run([BIN, str(hilos), str(iters)], capture_output=True, text=True,
                             check=True).stdout
        trozos = out.split("s/slot a 200 032 000 it:")[1].split("|")[0].split()
        m, peor = float(trozos[0]), float(trozos[2])
        peor_m = max(peor_m, m)
        if m < mejor[0]:
            mejor = (m, peor)
    return mejor[0], mejor[1], peor_m


def main():
    ancho = "=" * 118
    prove = lee_criterion("prove")

    print(ancho)
    print("CONTROL — el microbench de una linea contra el `prove` de Criterion en esta maquina")
    if not os.path.exists(BIN):
        print(f"  BINARIO NO COMPILADO en {BIN}: compila con")
        print("  gcc -O3 -maes -mavx2 -pthread -o <bin> r10a_b3_lineas.c")
        return
    uno, _, uno_peor = mide_lineas(1, reps=9)
    print(f"  1 hilo: mejor {uno:.3f} s/slot · peor de 9 corridas {uno_peor:.3f} s/slot")
    print(f"  Criterion `prove` en esta maquina: {prove:.3f} s/slot   razon {uno/prove:.3f}")
    print("  (el microbench no guarda checkpoints ni pasa por Criterion; la razon esperada es <= 1)")

    print(ancho)
    print("B.3.a — ¿CUANTAS LINEAS DE AES SIMULTANEAS aguanta esta maquina sin perder velocidad?")
    print(f"        {NUCLEOS} hilos logicos (9950X3D: 16 nucleos fisicos, SMT x2)")
    print(f"{'hilos':>6} | {'s/slot medio':>13} {'s/slot el mas lento':>20} {'degradacion':>12} | "
          f"{'agregado (slots/s)':>19} {'peor corrida':>14}")
    filas = []
    for n in (1, 2, 4, 6, 8, 10, 12, 13, 16, 18, 20, 24, 25, 32, 40, 45, 48):
        m, peor, pm = mide_lineas(n)
        filas.append((n, m, peor))
        print(f"{n:>6d} | {m:>13.3f} {peor:>20.3f} {m/uno:>12.3f} | {n/m:>19.2f} {pm:>14.3f}")
    lento = {n: peor for n, m, peor in filas}

    print(ancho)
    print("B.3.b — CADENAS EN VUELO Y NUCLEOS, por disciplina (§A.1)")
    print("        (i) esperar al ancla: q = ceil(L/I) cadenas · (ii) especular: m*q cadenas")
    print(f"{'I':>5} {'F=L (h)':>8} {'q':>4} | {'(i) lineas':>11} {'(ii) m=2,54':>12} "
          f"{'(ii) m maximo':>14} | {'s/slot a (i) lineas':>20} {'¿llega a tiempo?':>17}")
    for I, L in CONF:
        q = math.ceil(L / I)
        m254 = menu(0.40)
        mmax = 1 + LAM * S_MAX
        n_i = q + 1
        n_ii = math.ceil(m254 * q) + 1
        n_max = math.ceil(mmax * q) + 1
        sslot = lento.get(min(n_i, 48), float("nan"))
        # con Lrev = L la disciplina (i) arranca W_dec tarde y NO llega; con Lrev = L - S_max si
        deficit = w_dec(0.40) / L
        print(f"{I:>5.0f} {L/3600:>8.2f} {q:>4d} | {n_i:>11d} {n_ii:>12d} {n_max:>14d} | "
              f"{sslot:>20.3f} {'NO, falta %.2f %%' % (deficit*100):>17}")
    print("  La condicion de puntualidad NO es absoluta: `t_j` es un INDICE de slot, no un")
    print("  instante de pared. Un timekeeper 1,56x mas lento hace el slot 1,56x mas largo y la")
    print("  revelacion tambien: la carrera es contra SU PROPIA cadena principal, no contra el reloj.")
    print("  Lo que si es absoluto es que la linea de revelacion necesita un NUCLEO propio.")

    print(ancho)
    print("B.3.c — LA PALANCA Lrev: acortar el VDF de revelacion compra holgura y cuesta rho*")
    print(f"{'I':>5} {'L (h)':>7} {'Lrev/L':>7} {'Lrev (h)':>9} | {'holgura del timekeeper':>23} | "
          f"{'rho* = (Lrev+I)/(I+W)':>22} {'a W=45 s':>10}")
    for I, L in CONF:
        for r in (1.0, 0.99, 0.90, 0.75, 0.50, 0.25):
            Lr = r * L
            hol = L / Lr
            print(f"{I:>5.0f} {L/3600:>7.2f} {r:>7.2f} {Lr/3600:>9.2f} | {hol:>22.3f}x | "
                  f"{rho_cadena_comun(L, I, w_dec(0.33), Lrev=Lr):>22.2f} "
                  f"{rho_cadena_comun(L, I, 45.0, Lrev=Lr):>10.2f}")
    print("  Con Lrev = L la disciplina (i) NO llega: le faltan W_dec/L = "
          f"{45/7200:.2%} a L = 2 h. Con Lrev = 0,99 L sobra, y rho* cae solo un 1 %.")

    print(ancho)
    print("B.3.d — RELACION CON autonomys/subspace#2141 (timekeeper mas rapido deja obsoletos")
    print("        a los demas). ¿Empeora (h)?  Se separa en dos efectos y se cuantifica cada uno.")
    print(f"{'I':>5} {'L (h)':>7} | {'nucleos hoy (sin h)':>20} {'nucleos con (h), disc. (i)':>27} "
          f"{'factor de barrera':>18} | {'ventaja de un reloj rho':>24}")
    for I, L in CONF:
        q = math.ceil(L / I)
        print(f"{I:>5.0f} {L/3600:>7.2f} | {1:>20d} {q+1:>27d} {q+1:>18d} | "
              f"{'igual: rho no cambia':>24}")
    print("  Efecto 1 (velocidad): NINGUNO. La carrera de #2141 es por publicar antes el mismo")
    print("  slot; (h) no la toca, porque la revelacion es determinista y tambien la gana el mas")
    print("  rapido, sin dar nada mas. Efecto 2 (barrera de entrada): la multiplica por q+1")
    print("  (10 nucleos a I = 851 s y F = 2 h, 25 a I = 300 s). Menos timekeepers, mas #2141.")

    print(ancho)
    print("B.4.a — PARTICION: un lado con `c` nucleos y las `q+1` lineas que necesita.")
    print("        Con (h.3\u2032) los bloques del otro lado son VALIDOS, pero este lado no puede")
    print("        calcular `entropia_j` a tiempo y por tanto NO SABE cual es el reto: deja de")
    print("        farmear aunque conserve todo su espacio.")
    print(f"{'I':>5} {'L (h)':>7} {'q+1':>5} {'c':>4} | {'reparto (slots/s por linea)':>28} "
          f"{'retraso de la revelacion (s)':>29} {'d/I':>8}")
    for I, L in CONF:
        q = math.ceil(L / I)
        for c in (1, 2, 4, q + 1, 2 * (q + 1)):
            # con c nucleos y q+1 lineas, cada linea corre a min(1, c/(q+1)) de su velocidad
            v = min(1.0, c / (q + 1.0))
            d = max(0.0, L / v - L)          # segundos de retraso de la revelacion
            print(f"{I:>5.0f} {L/3600:>7.2f} {q+1:>5d} {c:>4d} | {v:>28.3f} {d:>29.0f} {d/I:>8.1f}")
    print("  Un lado con 1 nucleo y q+1 = 10 lineas entrega cada revelacion 9L = 18 h tarde, y")
    print("  F = 2 h: el lado queda 9 veces por detras de su propia finalidad. Esta muerto.")
    print("  Sin (h) le bastaba UNA linea. Ese es el vector nuevo que introduce (h).")

    print(ancho)
    print("B.4.b — COSTE DE VERIFICACION DEL LADO, para comparar con el de produccion")
    print(f"{'I':>5} {'L (h)':>7} | {'producir q+1 lineas (nucleos)':>30} "
          f"{'verificar 1 revelacion/epoca (nucleos)':>39}")
    for I, L in CONF:
        q = math.ceil(L / I)
        print(f"{I:>5.0f} {L/3600:>7.2f} | {q+1:>30d} {L*VERIFY_S/I:>39.3f}")
    print(f"  prove = {PROVE_S:.3f} s/slot, verify = {VERIFY_S:.4f} s/slot (Criterion, esta maquina)")


if __name__ == "__main__":
    main()
