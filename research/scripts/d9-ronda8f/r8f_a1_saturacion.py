#!/usr/bin/env python3
"""
r8f_a1_saturacion.py — PARTE A. ¿Satura `m`, o crece con el parametro?

`m` medida por D9-c/d/e es  |U_{e in F} {seed(ancla(T,e))}|  sobre una FAMILIA F de
estrategias. Es MONOTONA NO DECRECIENTE en F: ampliar la familia solo puede subirla.
Por eso subio 5,0 -> 3,03 -> 5,77 (familias distintas), y por eso "m sin cota superior"
no es todavia un resultado: hay que preguntar si la SUCESION converge.

Aqui se construyen familias ANIDADAS en un parametro y se mide `m` en cada nivel:

   D  profundidad maxima de `retro`      1,2,4,...,256   (D9-d llego a 4; D9-e a 16/64)
   W  semiancho de la ventana de eventos del atacante sobre la que actua la estrategia
   C  numero de COPIAS del mismo billete (R-FIN-11) que acompanan a cada bloque

CRITERIO DE COBERTURA DE RAMA (la leccion de D9-d): cada nivel declara
   `nuevas` = estrategias que ese nivel ANADE (si es 0, el nivel no corrio y su fila
              es la anterior por construccion: NO dice nada)
   `aporta` = umbrales en los que ese nivel aporto al menos un `seed` NUEVO
Un nivel con `nuevas > 0` y `aporta = 0` es SATURACION medida. Un nivel con `nuevas = 0`
es un experimento vacio y se marca como tal.

Criterio alpha: la fila alpha=0 debe dar m=1 en TODOS los niveles y en los tres barridos.
"""
import sys
import time

from r8f_lib import Mundo, perfil, ancla_bs_T, banda_bs, pols_hasta, idx_ventana, \
    K, MP, BANDA

P = 30
HOR = 260.0
SEMS = list(range(1, 13))

# DEGENERACION DECLARADA (hallazgo de A2, corregido por mi): `retro d` del simulador es
# `ch[max(0, len(ch)-1-d)]` (r8c_sim.py), luego para `d >= len(cadena en tP)` TODOS los
# niveles apuntan a GENESIS y son la MISMA estrategia. Un nivel D por encima de la longitud
# de cadena en tP NO aporta informacion: se marca `DEGEN` y no cuenta como saturacion.


def _base(mundo):
    d0, tip0 = mundo.corre({}, copias=0)
    ch0 = d0.selected_chain(tip0)
    if P >= len(ch0):
        return None
    return d0.B[ch0[P]].t, d0.gd[ch0[P]].blue_score


def barrido(alpha, semilla, niveles, hazfam, u3_mode="dynamic"):
    """`hazfam(mundo, tP, nivel)` -> (lista de (estrategia, copias)). Debe ser ANIDADA:
    hazfam(n+1) ⊇ hazfam(n). Devuelve por nivel (m_medio, m_max, nuevas, aporta, viol_banda)."""
    mundo = Mundo(alpha, HOR, semilla, k=K, mp=MP, u3_mode=u3_mode)
    b = _base(mundo)
    if b is None:
        return None
    tP, T0 = b
    d0b, tip0b = mundo.corre({}, copias=0)
    ch0b = d0b.selected_chain(tip0b)
    lcad_tP = sum(1 for x in ch0b if d0b.B[x].t <= tP)   # longitud de cadena EN tP
    Ts = list(range(T0 - BANDA, T0 + BANDA + 1))
    acum = {T: set() for T in Ts}
    vistas = set()          # clave de estrategia ya ejecutada, para no repetir
    out = []
    viol = 0
    nb = 0
    for niv in niveles:
        pares = hazfam(mundo, tP, niv)
        nuevas = 0
        aporta = 0
        antes = {T: len(acum[T]) for T in Ts}
        for est, cop in pares:
            clave = (tuple(sorted(est.items())), cop)
            if clave in vistas:
                continue
            vistas.add(clave)
            nuevas += 1
            d, tip = mundo.corre(est, copias=cop)
            pf = perfil(d, tip)
            for T in Ts:
                s, _ = ancla_bs_T(pf, T)
                if s is not None:
                    acum[T].add(s)
                    db = banda_bs(d, tip, T)
                    nb += 1
                    if db is None or not (0 <= db <= K):
                        viol += 1
        aporta = sum(1 for T in Ts if len(acum[T]) > antes[T])
        tam = [len(acum[T]) for T in Ts]
        out.append((sum(tam) / len(tam), max(tam), nuevas, aporta))
    return out, viol, nb, lcad_tP


# ---------------- barrido D: profundidad de `retro` ----------------
DS = [0, 1, 2, 4, 8, 16, 32, 64, 128, 256]


def fam_D(mundo, tP, D, W=30.0):
    idx = idx_ventana(mundo, tP, W)
    pols = pols_hasta(D)
    pares = [({}, 0)]
    for pol in pols:
        pares.append(({i: (0.0, pol) for i in idx}, 0))
        for i in idx:
            pares.append(({i: (0.0, pol)}, 0))
    return pares


# ---------------- barrido W: ventana de la estrategia ----------------
WS = [5.0, 10.0, 30.0, 60.0, 120.0, 260.0]


def fam_W(mundo, tP, W, D=16):
    return fam_D(mundo, tP, D, W=W)


# ---------------- barrido C: copias del mismo billete ----------------
CS = [0, 6, 14, 30]


def fam_C(mundo, tP, C, D=32, W=30.0):
    idx = idx_ventana(mundo, tP, W)
    pols = pols_hasta(D)
    pares = []
    for cop in [c for c in CS if c <= C]:
        pares.append(({}, cop))
        for pol in pols:
            pares.append(({i: (0.0, pol) for i in idx}, cop))
        for pol in ("sp", ("retro", 1), ("retro", 4)):
            for i in idx:
                pares.append(({i: (0.0, pol)}, cop))
    return pares


def tabla(nombre, niveles, hazfam, alphas, sems, etiqueta):
    print(f"\n=== {nombre} ===")
    print(f"{'nivel':>7} {'alpha':>6} | {'m medio':>9} {'m max':>6} | "
          f"{'nuevas':>7} {'aporta/21':>10} | {'viol.banda':>10} {'|cad(tP)|':>8} {'nota':>6}")
    for alpha in alphas:
        res = [barrido(alpha, s, niveles, hazfam) for s in sems]
        res = [r for r in res if r is not None]
        if not res:
            print(f"{'':>7} {alpha:>6.2f} sin datos"); continue
        for j, niv in enumerate(niveles):
            mm = [r[0][j][0] for r in res]
            mx = max(r[0][j][1] for r in res)
            nu = sum(r[0][j][2] for r in res)
            ap = sum(r[0][j][3] for r in res) / len(res)
            vi = sum(r[1] for r in res) if j == len(niveles) - 1 else ""
            lc = sum(r[3] for r in res) / len(res)
            deg = "DEGEN" if (etiqueta == "D" and isinstance(niv, int) and niv >= lc) else ""
            print(f"{str(niv):>7} {alpha:>6.2f} | {sum(mm)/len(mm):>9.3f} {mx:>6} | "
                  f"{nu:>7} {ap:>10.2f} | {str(vi):>10} {lc:>8.1f} {deg:>6}")
        print()


if __name__ == "__main__":
    cual = sys.argv[1] if len(sys.argv) > 1 else "D"
    alphas = [float(x) for x in sys.argv[2].split(",")] if len(sys.argv) > 2 \
        else [0.0, 0.10, 0.25, 0.40]
    if len(sys.argv) > 3:
        P = int(sys.argv[3])
    if len(sys.argv) > 4:
        HOR = float(sys.argv[4])
    print("=== A1 · SATURACION del menu `m` del ancla blue_score ===")
    print(f"k={K}, mp={MP}, lambda=1, Delta=4, horizonte {HOR:.0f} s, u3_mode=dynamic, "
          f"P={P}, T0+-{BANDA} (21 umbrales), semillas {SEMS[0]}..{SEMS[-1]}.")
    print("Peso 1 (D9-e reprodujo a D9-d cifra a cifra con peso real: +-3 %). Adversario del")
    print("paper (sin retardo). Menu contado sobre `seed`, fijado en la creacion.")
    print("`viol.banda` = veces que blue_score(ancla)-T salio FUERA de [0,k] (Lema B1).")
    t0 = time.time()
    if cual == "D":
        tabla("Barrido D · profundidad maxima de `retro` (W=30 s, sin copias)",
              DS, fam_D, alphas, SEMS, "D")
    elif cual == "W":
        tabla("Barrido W · semiancho de la ventana de eventos (D=16, sin copias)",
              WS, fam_W, alphas, SEMS, "W")
    elif cual == "C":
        tabla("Barrido C · copias del mismo billete (D=32 SATURADA, W=30 s)",
              CS, fam_C, alphas, SEMS, "C")
    print(f"\n[{time.time()-t0:.0f} s]")
