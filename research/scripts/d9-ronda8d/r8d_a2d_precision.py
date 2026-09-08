#!/usr/bin/env python3
"""
r8d_a2d_precision.py — PRECISION de mi propia afirmacion en A2.1.

Dije «con la cadena seleccionada IDENTICA el ancla se mueve». Mi test comparaba la LISTA DE
BIDS de la cadena. Un bid es el indice del evento, asi que la misma lista de bids = **la
misma sucesion de bloques y por tanto de `seed`** sobre la cadena — que es exactamente lo
que el menu cuenta. Pero NO significa que esos bloques sean identicos: sus PADRES (y por
tanto sus mergesets y sus blue_score) pueden diferir, y de hecho ese es el mecanismo.

Aqui se comprueba las dos cosas a la vez, para que la afirmacion quede exacta:
  (1) entre las ejecuciones de cadena «congelada», ?difieren los PADRES de algun bloque de
      la cadena?  -> si difieren, el mecanismo es «cambiar el mergeset», no «cambiar la cadena».
  (2) ?cuantos `seed` distintos da el ancla BS sobre esas ejecuciones, y cuantos da POS?
      POS tiene que dar exactamente 1 por construccion.

Criterio alpha: alpha = 0 -> 1 en las dos lecturas y 0 diferencias de padres.
"""
from r8d_lib import Mundo
from r8d_a1_menu import K, MP, BANDA, ancla_T


def prueba(alpha, semilla, P=30, T_hor=260.0):
    m = Mundo(alpha, T_hor, semilla, k=K, mp=MP, u3_mode="dynamic")
    d0, tip0 = m.corre({})
    ch0 = d0.selected_chain(tip0)
    if P >= len(ch0):
        return None
    tP = d0.B[ch0[P]].t
    T0 = d0.gd[ch0[P]].blue_score
    Ts = list(range(T0 - BANDA, T0 + BANDA + 1))
    idx = [i for i, (t, q, *_) in enumerate(m.ev) if q == "a" and tP - 30 <= t <= tP + 30]
    ests = [{}]
    for pol in ("sp", ("retro", 1), ("retro", 2), ("retro", 4)):
        ests.append({i: (0.0, pol) for i in idx})
    for i in idx:
        for pol in ("sp", ("retro", 1), ("retro", 3)):
            ests.append({i: (0.0, pol)})
    padres_ref = None
    n_frz = 0
    dif_padres = 0
    seeds_bs = {T: set() for T in Ts}
    seeds_pos = set()
    for e in ests:
        d, tip = m.corre(e)
        ch = d.selected_chain(tip)
        if ch != ch0:
            continue
        n_frz += 1
        pad = [tuple(sorted(d.B[b].parents)) for b in ch[:P + 3]]
        if padres_ref is None:
            padres_ref = pad
        elif pad != padres_ref:
            dif_padres += 1
        seeds_pos.add(d.B[ch[P]].seed)
        perfil = [(d.gd[b].blue_score, d.B[b].seed) for b in ch]
        for T in Ts:
            s = ancla_T(perfil, T)
            if s is not None:
                seeds_bs[T].add(s)
    if n_frz == 0:
        return None
    return (n_frz, dif_padres, len(seeds_pos),
            sum(len(v) for v in seeds_bs.values()) / len(seeds_bs),
            max(len(v) for v in seeds_bs.values()))


if __name__ == "__main__":
    print("=== A2d · precision del hallazgo «cadena congelada» ===")
    print("Ejecuciones cuya cadena seleccionada es la MISMA LISTA DE BIDS que la de referencia.\n")
    print(f"{'alpha':>6} | {'n congeladas':>13} | {'con PADRES distintos':>21} | "
          f"{'menu POS':>9} | {'menu BS medio':>14} {'max':>5}")
    for a in (0.0, 0.10, 0.25, 0.33, 0.40):
        rs = [prueba(a, s) for s in range(1, 13)]
        rs = [r for r in rs if r]
        f = lambda i: sum(r[i] for r in rs) / len(rs)
        print(f"{a:>6.2f} | {f(0):>13.1f} | {f(1):>21.1f} | {f(2):>9.2f} | "
              f"{f(3):>14.2f} {max(r[4] for r in rs):>5}")
