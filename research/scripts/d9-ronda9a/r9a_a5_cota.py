#!/usr/bin/env python3
"""
r9a_a5_cota.py — LINEA 5 (nueva del relanzamiento). Las DOS cotas formales, comprobadas
numericamente, y el reparto optimo bajo la cota PESIMISTA del propio paper.

Motivo: al releer el Lema 9 (`research/fuentes/phantom-ghostdag.txt` L1138-1147) encuentro
que EL PAPER MISMO afirma un evento con R/A > 1:

  «the adversary has managed to replace k + 2D*lambda blue blocks with k + 1 blue blocks»

es decir R = k + 2*D*lambda = 38, A = k+1 = 31, R/A = 1,226 con las constantes del diseno.
De ahi sale el factor k/(k+2D*lambda) = 0,789 y el delta = 0,2105 de las rondas 3-8.
Eso es un CONTRAEJEMPLO declarado a la version literal «uno a uno como maximo».

Se comprueban tres cosas:

  (5.1) LA EQUIVALENCIA CERRADA de la familia de rafagas (auditoria 7 §1.1):
        gana la rafaga  <=>  J < J* = k*alpha/(1-2*alpha)  <=>  R < J = A.
        Si es una equivalencia, «rafaga con mas rojos que azules» = «rafaga que PIERDE»,
        y una rafaga que pierde deja 0 rojos permanentes.

  (5.2) LA REALIZABILIDAD del evento del paper: una rafaga de exactamente J = k+1 bloques
        solo gana si k+1 < J*, o sea alpha > (k+1)/(3k+2). Por debajo de ese alpha el
        evento del Lema 9 NO EXISTE (el atacante no alcanza el score del padre honesto).

  (5.3) EL REPARTO OPTIMO bajo la cota PESIMISTA del paper (la que concede el exceso de
        2*D*lambda rojos por evento, con nu <= alpha_p*lambda/(k+1) eventos/s):
              tasa_Wpub >= (1 - alpha - c*alpha_p)*lambda,  c = 2*D*lambda/(k+1)
              r(alpha_p) = alpha_f / (1 - alpha - c*alpha_p),  alpha_f = alpha - alpha_p
        Si el maximo esta en alpha_p = 0 para todo alpha < 1/2, la tesis del agente
        principal sobrevive INCLUSO concediendo la holgura que el paper reclama.

REGLA 1: fila alpha = 0 en toda tabla. REGLA 6: esto es una cota, no una realidad; lo que
se mide esta en A1/A2/A4.
"""
K = 30
D = 4.0
LAM = 1.0
C_SLACK = 2 * D * LAM / (K + 1)          # exceso de rojos por bloque publicado del atacante

ALPHAS = [0.00, 0.10, 0.20, 0.25, 0.30, 0.33, 0.35, 0.37, 0.40, 0.45, 0.49]


def J_estrella(a, k=K):
    return float("inf") if a >= 0.5 else (k * a / (1 - 2 * a) if a > 0 else 0.0)


def rojos(J, a, k=K):
    """rojos de una rafaga de J bloques: honestos creados tras la saturacion del anticono."""
    if a <= 0:
        return 0.0
    return max(0.0, J * (1 - a) / a - k)


def gana(J, a, k=K):
    """privada = fork + k + J ;  honesta = fork + J*(1-a)/a."""
    if a <= 0:
        return False
    return k + J > J * (1 - a) / a


if __name__ == "__main__":
    print("=== A5 · las dos cotas formales, comprobadas ===")
    print(f"k={K}, D={D}, lambda={LAM}, c = 2*D*lambda/(k+1) = {C_SLACK:.4f}\n")

    # ---------------- 5.1 equivalencia -------------------------------------------------
    print("--- 5.1 · gana(J) <=> R(J) < J ?  Barrido J = 1..1000, alpha en la tabla. ---")
    print("    ERROR PROPIO CORREGIDO (declarado en el informe): la primera version contaba")
    print("    la fila alpha=0 en las discrepancias y salian 400 falsas. A alpha=0 el")
    print("    atacante NO TIENE BLOQUES: no hay rafaga, `gana` es False y R=0<J es cierto")
    print("    de forma vacua. La equivalencia se enuncia para alpha>0; la fila alpha=0 se")
    print("    conserva (regla 1) y se marca `vacua`.")
    print(f"{'alpha':>6} {'J*':>9} | {'#J gana':>8} {'#J R<A':>8} {'#discrep':>9} "
          f"| {'max R/A entre las que GANAN':>29}")
    n_disc_total = 0
    n_cubre_gana = n_cubre_pierde = 0
    for a in ALPHAS:
        ng = nr = nd = 0
        mx = 0.0
        for J in range(1, 1001):
            g = gana(J, a)
            R = rojos(J, a)
            rl = (R < J)
            ng += g
            nr += rl
            if g != rl:
                nd += 1
            if g:
                n_cubre_gana += 1
                mx = max(mx, R / J)
            else:
                n_cubre_pierde += 1
        if a > 0:
            n_disc_total += nd
        js = f"{J_estrella(a):.1f}" if a < 0.5 else "inf"
        marca = "  <- vacua (sin bloques del atacante)" if a == 0 else ""
        print(f"{a:>6.2f} {js:>9} | {ng:>8} {nr:>8} {nd:>9} | {mx:>29.4f}{marca}")
    print(f"\n  cobertura de rama: gana={n_cubre_gana}, pierde={n_cubre_pierde} "
          f"(las dos > 0)")
    print(f"  DISCREPANCIAS TOTALES (alpha > 0): {n_disc_total}  ->  "
          f"{'EQUIVALENCIA CONFIRMADA' if n_disc_total == 0 else 'LA EQUIVALENCIA FALLA'}")
    print("  Lectura: max R/A entre las rafagas que GANAN es < 1 en toda fila; una rafaga")
    print("  con R >= A es exactamente una rafaga que PIERDE, y una que pierde no deja")
    print("  rojos permanentes (la cadena honesta la revierte y los honestos vuelven azules).\n")

    # ---------------- 5.2 realizabilidad del evento del Lema 9 -------------------------
    a_min = (K + 1) / (3 * K + 2)
    print(f"--- 5.2 · el evento del Lema 9 (J = k+1 = {K+1}) exige alpha > (k+1)/(3k+2) = "
          f"{a_min:.4f} ---")
    print(f"{'alpha':>6} | {'J*':>9} {'k+1 < J* ?':>12} {'gana(k+1)':>11} | "
          f"{'R(k+1)':>8} {'R/A':>7}")
    for a in ALPHAS:
        js = J_estrella(a)
        R = rojos(K + 1, a)
        print(f"{a:>6.2f} | {js:>9.1f} {str(K+1 < js):>12} {str(gana(K+1, a)):>11} | "
              f"{R:>8.1f} {(R/(K+1)):>7.4f}")
    print(f"\n  A alpha <= {a_min:.3f} el evento del paper NO es realizable: R/A seria")
    print("  1,2-16 pero la rafaga no alcanza el score del padre honesto y no hay cambio")
    print("  de cadena. Donde SI gana (alpha > 0,34), R/A ya ha bajado por debajo de 1.")
    print("  El «k + 2D*lambda por k+1» del paper NO comprueba la condicion de victoria.\n")

    # ---------------- 5.3 reparto optimo bajo la cota pesimista ------------------------
    print("--- 5.3 · reparto optimo CONCEDIENDO la holgura del paper ---")
    print(f"    tasa_Wpub >= (1 - alpha - c*alpha_p)*lambda con c = {C_SLACK:.4f}")
    print(f"    r(beta) = (1-beta)*alpha / (1 - alpha - c*beta*alpha),  beta = alpha_p/alpha")
    betas = [0.0, 0.25, 0.5, 0.75, 1.0]
    print(f"{'alpha':>6} | " + " ".join(f"{'beta='+('%.2f'%b):>11}" for b in betas)
          + f" | {'argmax':>7} {'r(0)=a/(1-a)':>13}")
    peor = None
    for a in ALPHAS:
        fila, vals = [], []
        for b in betas:
            den = 1 - a - C_SLACK * b * a
            r = ((1 - b) * a / den) if den > 0 else float("inf")
            vals.append(r)
            fila.append(f"{r:>11.4f}")
        am = betas[max(range(len(betas)), key=lambda i: vals[i])]
        if am != 0.0:
            peor = (a, am)
        print(f"{a:>6.2f} | " + " ".join(fila) + f" | {am:>7.2f} "
              f"{(a/(1-a) if a < 1 else float('inf')):>13.4f}")
    print(f"\n  argmax != 0 en alguna fila? {peor if peor else 'NO — beta = 0 en TODAS'}")
    print(f"  Condicion analitica: dr/dbeta|_0 < 0  <=>  -(1-alpha) + c*alpha < 0  <=>  "
          f"alpha < 1/(1+c) = {1/(1+C_SLACK):.4f}.")
    print("  Como 1/(1+c) = 0,795 > 1/2, PARASITAR NUNCA AYUDA AL QUE CORRE, ni siquiera")
    print("  concediendo el exceso de 2*D*lambda rojos por evento que el paper reclama.")
    print("  La base de la carrera es alpha/(1-alpha) para todo alpha < 1/2.")
