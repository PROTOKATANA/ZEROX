#!/usr/bin/env python3
"""
r8d_a4_smax.py — LINEA A4. La cota `S_max` de R-FIN-1a.

R-FIN-1a exige slot(sp(B)) < slot(B) y, tras D9-c A4, slot(B) - slot(sp(B)) <= S_max,
con S_max POR FIJAR. Aqui se acota por los dos lados y se enseña que **se cruzan**.

SUELO (vivacidad):  un bloque honesto legitimo nunca debe violarla.
   (a) operacion normal: distribucion medida del salto de slot en la cadena seleccionada.
   (b) particion de duracion P < F: un lado con fraccion `f` del espacio produce bloques
       a tasa f*lambda; el mayor hueco entre bloques de ese lado es el maximo de
       ~f*lambda*P exponenciales de media 1/(f*lambda). Si ese maximo supera S_max, el
       primer bloque tras el hueco es INVALIDO y el lado minoritario **no puede seguir
       la cadena**: la tolerancia a particiones deja de ser F (R-FIN-7) y pasa a ser una
       condicion sobre `f`.

TECHO (DoS de verificacion): `CLAUDE.md` — la verificacion del PoT de Autonomys **no es
sucinta**: recomputa una cadena AES, coste lineal en slots. En regimen la red verifica
1 slot/s. Un atacante con fraccion `alpha` del espacio y `n_cop` bloques por billete
fuerza  alpha*lambda*n_cop*S_max  slots/s  =>  AMPLIFICACION sobre el presupuesto.

Criterio alpha: (a) se mide con el simulador y cambia con alpha; el techo es explicito
en alpha; el suelo (b) es analitico y no depende de alpha (es un fallo de vivacidad, no
un ataque) — se declara como tal.
"""
import math, sys
from r8d_lib import Mundo

K, MP = 30, 15
LAM = 1.0
F_H = 3.2                      # R-FIN-7, propuesta actual
BYTES_SLOT = 128               # justificacion de PoT, dag-poas-inyeccion-auditoria.md L425


def saltos(alpha, semilla, T=900.0, u3_mode="dynamic"):
    m = Mundo(alpha, T, semilla, k=K, mp=MP, u3_mode=u3_mode)
    d, tip = m.corre({})
    ch = d.selected_chain(tip)
    return [d.B[ch[i]].t - d.B[ch[i - 1]].t for i in range(2, len(ch))]


def max_hueco_esperado(f, P, lam=LAM):
    """E[max de N huecos Exp(f*lam)] con N = f*lam*P; aprox. clasica H_N/(f*lam)."""
    N = f * lam * P
    if N < 1:
        return P
    H = math.log(N) + 0.5772156649
    return H / (f * lam)


def p_hueco_supera(f, P, S, lam=LAM):
    """P(algun hueco > S en una particion de duracion P) = 1 - exp(-f*lam*P*e^{-f*lam*S})."""
    N = f * lam * P
    return 1 - math.exp(-N * math.exp(-f * lam * S))


if __name__ == "__main__":
    T = float(sys.argv[1]) if len(sys.argv) > 1 else 900.0
    print("=== A4 · S_max: suelo de vivacidad frente a techo de DoS ===\n")
    print("(a) SUELO en operacion normal — salto de slot en la cadena seleccionada (medido)")
    print(f"{'alpha':>6} | {'medio':>7} {'p50':>5} {'p90':>5} {'p99':>6} {'max':>6} | "
          f"{'P(salto>30 s)':>14} {'P(salto>60 s)':>14}")
    for alpha in (0.0, 0.10, 0.25, 0.33, 0.40):
        s = [x for sem in range(1, 13) for x in saltos(alpha, sem, T)]
        s.sort()
        n = len(s)
        q = lambda p: s[min(n - 1, int(p * n))]
        print(f"{alpha:>6.2f} | {sum(s)/n:>7.2f} {q(.5):>5.1f} {q(.9):>5.1f} {q(.99):>6.1f} "
              f"{s[-1]:>6.1f} | {sum(1 for x in s if x > 30)/n:>14.4f} "
              f"{sum(1 for x in s if x > 60)/n:>14.4f}")
    print("\n   Cola geometrica: P(salto > S) ~ e^{-lambda_chain*S}. Para 10 anos a "
          "lambda_chain=0,199 (alpha=0) hacen falta")
    for objetivo in (1e-6, 1e-9, 1e-12):
        S = -math.log(objetivo) / 0.199
        print(f"      P(salto > S) < {objetivo:.0e}  ->  S_max >= {S:>7.0f} slots")

    print("\n(b) SUELO por PARTICION — R-FIN-7 tolera particiones de hasta F = "
          f"{F_H} h = {F_H*3600:.0f} s")
    print(f"{'f (espacio del lado)':>21} | {'mayor hueco esperado':>21} | "
          f"{'S_max necesario (P<1%)':>23}")
    for f in (0.02, 0.05, 0.10, 0.20, 0.33, 0.50):
        P = F_H * 3600
        mh = max_hueco_esperado(f, P)
        S = 1
        while p_hueco_supera(f, P, S) > 0.01 and S < 10 ** 7:
            S = int(S * 1.05) + 1
        print(f"{f:>21.2f} | {mh:>21.0f} s | {S:>21} s")

    print("\n(c) TECHO por DoS de verificacion de PoT (no sucinta: coste lineal en slots)")
    print("    presupuesto en regimen = 1 slot de PoT por segundo (lambda = 1, 1 slot/s)")
    print(f"{'S_max':>8} | " + " ".join(f"{'x' + f'{a:.2f}':>10}" for a in (0.10, 0.25, 0.40))
          + " | " + " ".join(f"{'x' + f'{a:.2f}' + ',14cop':>13}" for a in (0.25, 0.40))
          + f" | {'B/s que envia':>14}")
    for S in (10, 30, 60, 300, 3600, 11520):
        amp = [a * LAM * S for a in (0.10, 0.25, 0.40)]
        ampc = [a * LAM * 14 * S for a in (0.25, 0.40)]
        print(f"{S:>8} | " + " ".join(f"{x:>10.0f}" for x in amp) + " | "
              + " ".join(f"{x:>13.0f}" for x in ampc)
              + f" | {0.40*LAM*14*S*BYTES_SLOT/1e6:>11.2f} MB")

    print("\n(d) LA PINZA")
    for f in (0.10, 0.33):
        P = F_H * 3600
        S = 1
        while p_hueco_supera(f, P, S) > 0.01 and S < 10 ** 7:
            S = int(S * 1.05) + 1
        amp = 0.40 * LAM * S
        print(f"   lado con f={f:.2f} del espacio sobrevive una particion de {F_H} h "
              f"si S_max >= {S} s  ->  amplificacion de DoS a alpha=0,40: x{amp:.0f}")
