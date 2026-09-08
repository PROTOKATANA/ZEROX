#!/usr/bin/env python3
"""
r8e_a2_sesgo.py — LINEA A2. El SESGO del ancla con el PESO REAL.

D9-d midio (`salida_a2b.txt`, `salida_a2c.txt`) que a `alpha=0,25` el ancla `blue_score`
cae en un bloque del atacante el **59,3 %** de los umbrales aunque solo el 49,3 % de los
bloques de cadena sean suyos, y que ELIGIENDO PADRES sube al **80,6 %**. La causa: sin
retardo el atacante fusiona ~1,5x mas azules por bloque, luego «se lleva» mas umbrales.

Pregunta de esta ronda: con `blue_work = Σ w(SR)`, ¿puede ademas CONCENTRAR PESO en sus
bloques? Dos canales posibles:
   (a) que sus bloques tengan `w` mayor — solo puede lograrlo eligiendo un `past` cuya
       ventana de retarget diera un `SR` mas duro (es la version GHOSTDAG del *difficulty
       grinding*). Se mide `w medio` de sus bloques frente a los honestos.
   (b) que su cuota de PESO en la cadena supere su cuota de CONTEO. Se miden las dos.

Se anade una familia de estrategias que D9-d no tenia y que es la que explota (a):
`('retro', n)` con `n` grande — colgar de un ancestro de cadena lo bastante atras como
para heredar el `SR` de OTRA ventana de dificultad.

Criterio alpha: alpha=0 -> todas las cuotas del atacante = 0 y p_cap = 0.
"""
import sys
from r8e_lib import MundoW, PesoCfg
from r8d_a1_menu import K, MP, BANDA

HOR_CAD = 900.0     # cadena entera, como D9-d A2c
HOR_CAP = 260.0     # captura, como D9-d A2b
RETROS = (1, 2, 4, 8, 16, 32, 64)      # el `n` de ('retro', n): la palanca de peso


def cuotas(alpha, semilla, wcfg):
    """Cuota del atacante en BLOQUES de cadena, en UMBRALES (blue_score) y en PESO."""
    m = MundoW(alpha, HOR_CAD, semilla, k=K, mp=MP, u3_mode="dynamic", wcfg=wcfg)
    d, tip = m.corre({})
    ch = d.selected_chain(tip)
    n_a = n_h = 0
    inc_a = inc_h = 0
    bw_a = bw_h = 0.0
    for i in range(1, len(ch)):
        inc = d.gd[ch[i]].blue_score - d.gd[ch[i - 1]].blue_score
        dbw = d.gd[ch[i]].blue_work - d.gd[ch[i - 1]].blue_work
        if d.B[ch[i]].creator == "a":
            inc_a += inc; n_a += 1; bw_a += dbw
        else:
            inc_h += inc; n_h += 1; bw_h += dbw
    wa = [d.w(b) for b in d.B if d.B[b].creator == "a"]
    wh = [d.w(b) for b in d.B if d.B[b].creator == "h"]
    return (n_a, n_h, inc_a, inc_h, bw_a, bw_h,
            sum(wa) / len(wa) if wa else 0.0, sum(wh) / len(wh) if wh else 0.0,
            d.cobertura())


def perfil_bid(d, tip):
    return [(d.gd[b].blue_score, b, d.B[b].creator) for b in d.selected_chain(tip)]


def cruza(perfil, T):
    for bs, b, cr in perfil:
        if bs >= T:
            return b, cr
    return None, None


def captura(alpha, semilla, wcfg, P=30, retros=RETROS):
    """p_nat / p_cap de D9-d A2b, con la familia de `retro` AMPLIADA (palanca de peso)."""
    m = MundoW(alpha, HOR_CAP, semilla, k=K, mp=MP, u3_mode="dynamic", wcfg=wcfg)
    d0, tip0 = m.corre({})
    ch0 = d0.selected_chain(tip0)
    if P >= len(ch0):
        return None
    tP = d0.B[ch0[P]].t
    T0 = d0.gd[ch0[P]].blue_score
    Ts = list(range(T0 - BANDA, T0 + BANDA + 1))
    idx = [i for i, (t, q, *_) in enumerate(m.ev) if q == "a" and tP - 30 <= t <= tP + 30]
    pols = ["sp"] + [("retro", n) for n in retros]
    ests = [{}]
    for pol in pols:
        ests.append({i: (0.0, pol) for i in idx})
    for i in idx:
        for pol in pols:
            ests.append({i: (0.0, pol)})
    p0 = perfil_bid(d0, tip0)
    nat = sum(1 for T in Ts if cruza(p0, T)[1] == "a")
    cap = set()
    spd = 0
    for e in ests:
        d, tip = m.corre(e)
        spd += d.cobertura()["sp_discrepa"]
        pf = perfil_bid(d, tip)
        for T in Ts:
            if cruza(pf, T)[1] == "a":
                cap.add(T)
    return nat / len(Ts), len(cap) / len(Ts), spd


CFGS = [
    ("peso 1 (D9-d)", PesoCfg(W=None)),
    ("desliz W=3083 g=.25", PesoCfg(W=3083.0, gamma=0.25, modo="desliz")),
    ("desliz W=80 g=.25", PesoCfg(W=80.0, gamma=0.25, modo="desliz")),
    ("desliz W=20 g=1.0", PesoCfg(W=20.0, gamma=1.0, modo="desliz")),
    ("epoca  W=20 g=.25", PesoCfg(W=20.0, gamma=0.25, modo="epoca")),
]

if __name__ == "__main__":
    print("=== A2 · ¿esta MAS sesgado el ancla con el peso real? ===")
    print(f"k={K}, mp={MP}, u3_mode=dynamic. (1) cadena entera, horizonte {HOR_CAD:.0f} s, "
          f"8 semillas; (2) horizonte {HOR_CAP:.0f} s, 12 semillas, P=30.\n")

    print("(1) CUOTAS del atacante en la cadena seleccionada, sin atacar (publica en puntas)")
    print(f"{'configuracion':>21} {'alpha':>6} | {'% BLOQUES':>10} {'% UMBRALES':>11} "
          f"{'% PESO':>8} | {'w medio atac':>13} {'w medio hon':>12} {'razon':>7} "
          f"| {'peso!=1':>8} {'sp!=':>5}")
    for nombre, wcfg in CFGS:
        for a in (0.0, 0.10, 0.25, 0.40):
            rs = [cuotas(a, s, wcfg) for s in range(1, 9)]
            na = sum(r[0] for r in rs); nh = sum(r[1] for r in rs)
            ia = sum(r[2] for r in rs); ih = sum(r[3] for r in rs)
            ba = sum(r[4] for r in rs); bh = sum(r[5] for r in rs)
            wa = sum(r[6] for r in rs) / len(rs); wh = sum(r[7] for r in rs) / len(rs)
            C = [r[8] for r in rs]
            pb = na / (na + nh) if na + nh else 0
            pu = ia / (ia + ih) if ia + ih else 0
            pw = ba / (ba + bh) if ba + bh else 0
            print(f"{nombre:>21} {a:>6.2f} | {pb:>9.1%} {pu:>10.1%} {pw:>7.1%} "
                  f"| {wa:>13.4f} {wh:>12.4f} {(wa/wh if wh else 0):>7.4f} "
                  f"| {sum(c['peso_distinto'] for c in C):>8} "
                  f"{sum(c['sp_discrepa'] for c in C):>5}")
        print()

    print("(2) CAPTURA del ancla (familia `retro` AMPLIADA a n = 1,2,4,8,16,32,64)")
    print(f"{'configuracion':>21} {'alpha':>6} | {'p_nat':>8} {'p_cap':>8} | {'sp!=':>6}")
    for nombre, wcfg in CFGS:
        for a in (0.0, 0.10, 0.25, 0.40):
            rs = [captura(a, s, wcfg) for s in range(1, 13)]
            rs = [r for r in rs if r]
            pn = sum(r[0] for r in rs) / len(rs)
            pc = sum(r[1] for r in rs) / len(rs)
            print(f"{nombre:>21} {a:>6.2f} | {pn:>7.1%} {pc:>7.1%} | "
                  f"{sum(r[2] for r in rs):>6}")
        print()
    print("Referencia D9-d: (1) a=0,25 -> 49,3 % bloques / 59,3 % umbrales; "
          "(2) a=0,25 -> p_nat 65,1 %, p_cap 80,6 % (familia retro solo hasta n=4).")
