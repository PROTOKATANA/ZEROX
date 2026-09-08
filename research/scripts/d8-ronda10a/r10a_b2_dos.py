#!/usr/bin/env python3
"""
D8 ronda 10a · B.2 — DoS de verificacion de la revelacion retardada (h).

Pregunta del encargo: «el atacante publica revelaciones falsas para candidatos; coste honesto
`L x 96,1 ms` (paralelizable por checkpoints) frente a coste del atacante `L x prove`.
Cuantifica con L in {1 h, 2 h} y di si la asimetria 16x basta o hace falta regla».

Fuente primaria de los dos numeros: NO se recitan, se leen del artefacto de Criterion que dejo
el bench `cargo bench -p subspace-proof-of-time` en esta misma maquina (9950X3D):
  target/criterion/{prove,verify}/new/estimates.json   ->  control positivo C0.

Lo que se lee del codigo y cambia el analisis (verificado en el clon @ f8842d0):
  · `verify_sequential` NO tiene salida temprana DENTRO de un slot: procesa los 8 checkpoints
    en paralelo con SIMD y en encuentro-por-el-medio (cifra desde la entrada, descifra desde la
    salida, `checkpoint_iterations/2` cada mitad) y compara AL FINAL
    (`subspace-proof-of-time/src/aes/x86_64.rs:75-107`). El grano minimo de verificacion es
    por tanto UN SLOT = 96,1 ms, no un checkpoint.
  · Entre slots si hay salida temprana y paralelismo total: la semilla del slot i es la salida
    del slot i-1, que viaja publicada en los `PotCheckpoints`
    (`subspace-core-primitives/src/pot.rs:328,332`; `sp-consensus-subspace/src/lib.rs:105-135`).
    Luego los L slots de una revelacion se pueden verificar en CUALQUIER ORDEN y en paralelo.

Criterio alpha: el numero de semillas de revelacion que el atacante puede reclamar legitimamente
en una epoca es `alpha * lambda * S_max` (sus bloques en la banda del ancla). La fila alpha = 0
tiene que dar 0 revelaciones falsas admisibles a verificacion.
"""
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from r10a_lib import LAM, N_CHECKPOINTS, POT_BYTES_SLOT, S_MAX, w_dec   # noqa: E402

CRIT = "/home/katana/zeo/fuentes/subspace/target/criterion"
NUCLEOS = os.cpu_count() or 1
SEMILLAS = [11, 23, 37, 41, 53, 67, 71, 83, 97, 101, 113, 127]   # 12, para el orden aleatorio
REPS = 20000        # busquedas por semilla en B.2.b


def coste_orden_aleatorio(L, n_malos, semilla, reps=REPS):
    """Slots que verifica un nodo que comprueba los L slots en ORDEN ALEATORIO hasta dar con
    uno malo. Se mide, no se recita: el cerrado (L+1)/(n_malos+1) es el que hay que reproducir."""
    import numpy as np
    rng = np.random.default_rng(semilla)
    n = int(L)
    k = max(1, int(n_malos))
    # en una permutacion uniforme de los n slots la posicion de cada slot malo es uniforme en
    # 1..n; el verificador para en la MENOR de ellas
    pos = rng.integers(1, n + 1, size=(reps, k))
    return float(pos.min(axis=1).mean())


def lee_criterion(nombre):
    with open(os.path.join(CRIT, nombre, "new", "estimates.json")) as f:
        d = json.load(f)
    return d["mean"]["point_estimate"] / 1e9, d["std_dev"]["point_estimate"] / 1e9


def main():
    ancho = "=" * 112
    print(ancho)
    print("CONTROL C0 — los dos costes, leidos del artefacto de Criterion de ESTA maquina")
    prove, sd_p = lee_criterion("prove")
    verify, sd_v = lee_criterion("verify")
    print(f"  prove  = {prove:.6f} s/slot  (sd {sd_p:.6f})   [ancla-de-orden.md publica 1,561 s]")
    print(f"  verify = {verify:.6f} s/slot  (sd {sd_v:.6f})   [ancla-de-orden.md publica 96,1 ms]")
    print(f"  asimetria prove/verify = {prove/verify:.2f}x    [ancla-de-orden.md publica ~16x]")
    ok = abs(prove - 1.561) < 5e-3 and abs(verify - 0.0961) < 5e-4
    print(f"  [{'IDENTICO' if ok else 'DISCREPA'}]  nucleos de esta maquina: {NUCLEOS}")

    print(ancho)
    print("B.2.a — COSTE HONESTO EN REGIMEN de verificar UNA revelacion por epoca (regla (h.2c))")
    print("        el multiplicador de la verificacion de PoT de CADA nodo es 1 + L/I")
    print(f"{'L (h)':>6} {'I':>5} | {'L (slots)':>10} {'CPU/epoca (s)':>14} {'nucleos continuos':>18} "
          f"{'x la cadena principal':>22} | {'pared con 32 nucleos':>21}")
    for L in (3600.0, 7200.0):
        for I in (300.0, 851.0):
            cpu = L * verify
            nuc = cpu / I
            print(f"{L/3600:>6.2f} {I:>5.0f} | {L:>10.0f} {cpu:>14.1f} {nuc:>18.3f} "
                  f"{L/I:>22.2f} | {cpu/NUCLEOS:>18.1f} s")
    print(f"  cadena principal sola: {verify:.4f} s/slot a tau = 1 s = {verify*100:.2f} % de un nucleo")

    print(ancho)
    print("B.2.b — REVELACION FALSA: que le cuesta al verificador y que le cuesta al atacante")
    print("        lo que NO calcula sale mal: con prefijo `p` correcto quedan L-p slots malos")
    print(f"{'L (h)':>6} {'p/L':>6} {'malos':>7} | {'en orden: verif (s)':>21} {'atacante (s)':>13} "
          f"{'razon':>8} | {'ALEATORIO: verif (s)':>20} {'razon':>10} {'cerrado (L+1)/(j+1)':>19}")
    for L in (3600.0, 7200.0):
        for frac in (0.0, 0.25, 0.50, 0.90, 0.99, 1.0):
            p = frac * L
            malos = max(1, int(round(L - p)))      # lo que no calculo, no le sale bien
            c_ver_sec = (p + 1.0) * verify         # en orden, para en el primer slot malo
            c_att = p * prove                      # tuvo que calcular de verdad el prefijo
            med = [coste_orden_aleatorio(L, malos, sm) for sm in SEMILLAS]
            c_ver_ale = (sum(med) / len(med)) * verify
            cerr_ale = (L + 1.0) / (malos + 1.0) * verify
            r1 = c_att / c_ver_sec if c_ver_sec > 0 else float("inf")
            r2 = c_att / c_ver_ale if c_ver_ale > 0 else float("inf")
            print(f"{L/3600:>6.2f} {frac:>6.2f} {malos:>7d} | {c_ver_sec:>21.2f} {c_att:>13.1f} "
                  f"{r1:>8.2f} | {c_ver_ale:>20.2f} {r2:>10.2f} {cerr_ale:>19.2f}")
    print("  Sin prefijo correcto (p = 0, L slots malos) el verificador paga UN slot = "
          f"{verify*1000:.1f} ms: no hay grano mas fino (x86_64.rs:75-107, sin salida temprana).")
    print("  El optimo del atacante es UN solo slot malo (fila p/L = 0,99..1,00 con malos = 1):")
    print("  maximiza el coste absoluto del verificador, y aun asi paga 16x (en orden) o 32x")
    print("  (en orden aleatorio) mas que el. Verificar en orden aleatorio es GRATIS y anula el")
    print("  ataque por prefijo largo: con L-p slots malos el verificador para en (L+1)/(L-p+1).")

    print(ancho)
    print("B.2.c — CUANTAS revelaciones falsas puede meter a verificar por epoca (regla (h.2))")
    print("        solo se verifica la de una semilla que el nodo tenga por candidato:")
    print("        candidatos suyos por epoca = alpha * lambda * S_max")
    print(f"{'alpha':>6} {'W_dec':>6} | {'candidatos propios':>19} {'coste verif. sin regla (s/epoca)':>33} "
          f"{'con (h.2c): 1 sola':>19}")
    for alpha in (0.00, 0.10, 0.25, 0.33, 0.40):
        cand = alpha * LAM * S_MAX
        sin_regla = cand * verify        # cada falsa cuesta un slot antes de caer
        print(f"{alpha:>6.2f} {w_dec(alpha):>6.0f} | {cand:>19.1f} {sin_regla:>33.3f} "
              f"{verify:>19.4f}")
    print("  El limite duro no es la regla, es el espacio: para reclamar una semilla hace falta")
    print("  un bloque valido en [T_j, T_j + S_max), y eso cuesta espacio, no CPU.")

    print(ancho)
    print("B.2.d — EL COSTE DE PUBLICARLA: bytes de la justificacion (R-FIN-14 (d) y (h.2b))")
    print(f"{'L (h)':>6} {'I':>5} | {'checkpoints completos (L*128 B)':>32} {'solo salida final (16 B)':>25} | "
          f"{'verif. en paralelo':>19} {'verif. forzosamente serie':>26}")
    for L in (3600.0, 7200.0):
        for I in (300.0, 851.0):
            comp = L * POT_BYTES_SLOT
            print(f"{L/3600:>6.2f} {I:>5.0f} | {comp/1024:>27.1f} kB {16:>22d} B | "
                  f"{L*verify/NUCLEOS:>16.1f} s {L*verify:>23.1f} s")
    print(f"  R-FIN-14 (d) para un bloque normal: S_max = {S_MAX:.0f} slots x {POT_BYTES_SLOT} B = "
          f"{S_MAX*POT_BYTES_SLOT/1024:.1f} kB. La revelacion con L = 2 h es "
          f"{7200*POT_BYTES_SLOT/(S_MAX*POT_BYTES_SLOT):.0f}x eso.")
    print(f"  Y {N_CHECKPOINTS} checkpoints por slot es el formato de Autonomys (pot.rs:332); "
          "publicar menos rompe `verify`.")

    print(ancho)
    print("B.2.e — EL ATAQUE QUE SI ESCALA: forzar RE-verificacion por reorganizacion")
    print("        con (h.2c) el nodo verifica la revelacion del ancla de SU cadena; una reorg")
    print("        que cambie el ancla de las ultimas F/I epocas obliga a verificar de nuevo")
    print(f"{'L (h)':>6} {'I':>5} {'F (h)':>6} | {'epocas en F':>12} {'CPU por reorg (s)':>18} "
          f"{'pared 32 nucleos':>17} {'coste del atacante (s)':>23}")
    for L, I, F in ((7200.0, 851.0, 7200.0), (7200.0, 300.0, 7200.0), (3600.0, 851.0, 3600.0),
                    (3600.0, 851.0, 7200.0)):
        n = F / I
        cpu = n * L * verify
        att = n * L * prove
        print(f"{L/3600:>6.2f} {I:>5.0f} {F/3600:>6.2f} | {n:>12.1f} {cpu:>18.1f} "
              f"{cpu/NUCLEOS:>14.1f} s {att:>23.0f}")
    print("  R-FIN-7 acota la reorg a F, luego el numero de epocas re-verificadas esta acotado;")
    print("  y el atacante paga `prove` por cada una que quiera hacer valida: la asimetria se mantiene.")


if __name__ == "__main__":
    main()
