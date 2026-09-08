#!/usr/bin/env python3
"""
r8c_a1_menu.py — LINEA A1. ?Puede el atacante mover el bloque que ocupa la POSICION `c*j` de la
cadena seleccionada, con BILLETES GENUINOS?

Metodo: numeros aleatorios comunes. Un `Mundo` fija el calendario de creaciones (instantes, quien,
sd, ident y `seed`). Solo cambia la ESTRATEGIA del atacante. El menu es el numero de valores
DISTINTOS de `seed` que puede hacer aparecer en la posicion P de la cadena seleccionada de la vista
honesta final. `seed` se fija en la creacion del bloque, asi que renombrar no lo altera.

Criterio alpha: con alpha=0 no hay bloques del atacante y el menu tiene que ser exactamente 1.
"""
import sys
from r8c_sim import Mundo

K = 30
MP = 15


def estrategias(mundo, P, d0, tip0):
    """Familia dirigida: el atacante actua sobre sus bloques de la VENTANA en la que se llena la
    posicion P. No es fuerza bruta; es lo que un atacante racional prueba."""
    ch0 = d0.selected_chain(tip0)
    if P >= len(ch0):
        return None, None
    tP = d0.B[ch0[P]].t                      # instante en que se creo el ocupante honesto de P
    W = 30.0                                  # ventana +-30 s (~6 posiciones de cadena)
    idx = [i for i, (t, q, *_) in enumerate(mundo.ev)
           if q == "a" and tP - W <= t <= tP + W]

    # TIER 1 - GRATIS: publica TODO al instante; solo elige padres. No renuncia a nada.
    g1 = [{}]
    for pol in ("sp", ("retro", 1), ("retro", 2), ("retro", 4)):
        g1.append({i: (0.0, pol) for i in idx})
    for i in idx:
        for pol in ("sp", ("retro", 1), ("retro", 3)):
            g1.append({i: (0.0, pol)})
    # TIER 2 - RETRASO: ademas retrasa la publicacion (coste: riesgo de quedar fuera)
    g2 = []
    for d in (2.0, 6.0, 15.0, 40.0):
        g2.append({i: (d, "tips") for i in idx})
    for pol in ("sp", ("retro", 1), ("retro", 2)):
        g2.append({i: (6.0, pol) for i in idx})
    for i in idx:
        for pol in ("tips", ("retro", 1)):
            for r in (4.0, 12.0):
                g2.append({i: (r, pol)})
    # TIER 3 - RETENCION: retiene bloques para siempre (coste: pierde el ingreso)
    g3 = [{i: (None, "tips") for i in idx}]
    for i in idx:
        for pol in ("tips", "sp", ("retro", 1), ("retro", 3)):
            for r in (0.0, 4.0, 12.0):
                e = {j: (None, "tips") for j in idx}
                e[i] = (r, pol)
                g3.append(e)
    return (g1, g2, g3), idx


def menu(alpha, semilla, P, T=260.0, u3_mode="dynamic", copias=0, verbose=False):
    m = Mundo(alpha, T, semilla, k=K, mp=MP, u3_mode=u3_mode)
    d0, tip0 = m.corre({}, copias=0)
    tiers, idx = estrategias(m, P, d0, tip0)
    if tiers is None:
        return None
    acum, res, nest = set(), [], 0
    for g in tiers:
        for e in g:
            d, tip = m.corre(e, copias=copias)
            s = Mundo.ancla(d, tip, P)
            nest += 1
            if s is not None:
                acum.add(s)
        res.append(len(acum))
    if verbose:
        print(f"      alpha={alpha} semilla={semilla} P={P}: {len(idx)} bloques del atacante "
              f"en ventana, {nest} estrategias -> menus {res}")
    return res       # [gratis, +retraso, +retencion] (acumulativos)


if __name__ == "__main__":
    P = int(sys.argv[1]) if len(sys.argv) > 1 else 30
    print(f"=== A1 · menu de la POSICION {P} de la cadena seleccionada ===")
    print("k=30, mp=15, lambda=1, Delta=4, horizonte 260 s. Menu contado sobre `seed`")
    print("(fijado en la creacion), NUNCA sobre etiquetas.\n")
    semillas = list(range(1, 13))
    for u3 in ("dynamic", "filter"):
        for cop in ((0,) if u3 == "dynamic" else (0, MP - 1)):
            print(f"--- u3_mode={u3}, copias por bloque del atacante = {cop} ---")
            print(f"{'alpha':>6} | {'m GRATIS':>19} | {'m +retraso':>19} | {'m +retencion':>19}")
            print(f"{'':>6} | {'medio':>8}{'max':>6}{'>1':>5} | {'medio':>8}{'max':>6}{'>1':>5} "
                  f"| {'medio':>8}{'max':>6}{'>1':>5}")
            for alpha in (0.0, 0.10, 0.25, 0.33, 0.40):
                rs = [menu(alpha, s, P, u3_mode=u3, copias=cop) for s in semillas]
                rs = [x for x in rs if x is not None]
                if not rs:
                    print(f"{alpha:>6} sin datos"); continue
                fila = f"{alpha:>6.2f} |"
                for t in range(3):
                    col = [r[t] for r in rs]
                    fila += (f"{sum(col)/len(col):>8.2f}{max(col):>6}"
                             f"{sum(1 for x in col if x > 1):>3}/{len(col):<2}|")
                print(fila)
            print()
