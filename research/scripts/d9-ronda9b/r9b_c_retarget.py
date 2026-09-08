#!/usr/bin/env python3
"""
r9b_c_retarget.py — D9 ronda 9b, punto C. La enmienda a R-FIN-13 y la nota de delta-real.

Dos medidas independientes:

C1 · ¿Sigue aplicando `dag-poas-delta-real.md` (`lambda_real = k*lambda_obj/(k - 2D*lambda_obj)`)
     si R-FIN-13 cuenta TODOS los bloques validos en vez de solo los azules?
     El modelo de delta-real parte de `lambda_obs = lambda * k/(k + 2D*lambda)` = lambda*(1-delta),
     es decir: el observador solo ve AZULES. Se mide, sobre la MISMA maniobra parasita de D8,
     que fraccion de los bloques producidos ve cada regla de conteo.

C2 · ¿Es inflable el retarget por COPIAS si cuenta todos los bloques validos?
     Reusa la construccion de `r9b_a_copias.py`.

Reglas: fila alpha=0 (regla 1), contadores de cobertura (regla 2), 12 semillas (regla 3),
control positivo (regla 4: la regla "solo azules" debe reproducir 1-delta de D8 A1b).
"""
import sys, time

sys.path.insert(0, "/home/katana/zeo/ZEROX/research/scripts/d8-ronda8")
sys.path.insert(0, "/home/katana/zeo/ZEROX/research/scripts/d9-ronda9b")
from d8_lib import MundoL9, DELTA                                        # noqa: E402
from r9b_a_copias import construir, contar                               # noqa: E402

K, MP = 30, 15
SEMS = list(range(1, 13))
ALPHAS = [0.0, 0.10, 0.25, 0.30, 0.33, 0.35, 0.37, 0.40]
HOR = 1800.0
T0, T1 = 60.0, HOR - 60.0
JS = {0.0: 16, 0.10: 16, 0.25: 16, 0.30: 31, 0.33: 31, 0.35: 31, 0.37: 48, 0.40: 48}


def c1():
    print("=" * 100)
    print("C1 · Que ve el retarget: solo AZULES (R-FIN-13 vigente) vs TODOS los FUSIONADOS (enmienda P1)")
    print("=" * 100)
    print(f"k={K}, mp={MP}, lambda=1, Delta={DELTA}, horizonte {HOR:.0f} s, ventana [{T0:.0f},{T1:.0f}] s,")
    print(f"semillas={SEMS}, maniobra parasita de D8 A1.2.\n")
    print("  lambda_obs/lambda = N_obs / N_producidos  ->  inflacion = lambda / lambda_obs")
    print("  El modelo de dag-poas-delta-real.md exige lambda_obs/lambda = k/(k+2D*lambda_real).\n")
    hdr = (f"{'alpha':>6} {'J':>4} | {'azul/prod':>10} {'infl_azul':>10} | "
           f"{'fus/prod':>10} {'infl_fus':>10} | {'N_prod':>7} {'N_azul':>7} {'N_fus':>7} {'rojos':>7}")
    print(hdr); print("-" * len(hdr))
    out = {}
    for alpha in ALPHAS:
        J = JS[alpha]
        Np = Na = Nf = Nr = 0
        for sem in SEMS:
            m = MundoL9(alpha, HOR, sem, k=K, mp=MP)
            d, tip, llega = m.corre_l9(J=J, d_fork=1, giveup=None, modo="parasito")
            az = d.blueset(tip)
            ch = d.selected_chain(tip)
            fus = set(ch)
            nr = 0
            for c in ch[1:]:
                nd = d.gd[c]
                for h in nd.mergeset_blues[1:]:
                    fus.add(h)
                for h in nd.mergeset_reds:
                    fus.add(h); nr += 1
            prod = [b for b, x in d.B.items() if x.creator in ("h", "a") and T0 < x.t <= T1]
            Np += len(prod)
            Na += sum(1 for b in prod if b in az)
            Nf += sum(1 for b in prod if b in fus)
            Nr += nr
        fa, ff = Na / Np, Nf / Np
        out[alpha] = (fa, ff)
        print(f"{alpha:>6.2f} {J:>4} | {fa:>10.4f} {1/fa:>10.4f} | {ff:>10.4f} {1/ff:>10.4f} | "
              f"{Np:>7} {Na:>7} {Nf:>7} {Nr:>7}")
    print()
    print("CONTROL POSITIVO (regla 4): la columna azul/prod es 1-delta_global de D8 A1b/A1e.")
    print("  alpha=0.40 -> azul/prod = %.4f ; D8 A1e da ing_h=0.5634, ing_a=0.8727" % out[0.40][0])
    print("  (aqui es el agregado de los dos lados, no cada lado por separado)")
    print()
    print("CRITERIO alpha=0 (regla 1): azul/prod = %.4f, fus/prod = %.4f, rojos = 0"
          % (out[0.0][0], out[0.0][1]))
    print()
    print("LECTURA C1:")
    print("  Contando solo azules, la inflacion medida a alpha=0.40 es x%.3f -- del mismo orden que" % (1/out[0.40][0],))
    print("  el x1.36 (k=30) que dag-poas-delta-real.md deriva del modelo del Lema 9.")
    return out


def c2():
    print()
    print("=" * 100)
    print("C2 · ¿Es inflable el retarget por COPIAS si R-FIN-13 cuenta todos los bloques validos?")
    print("=" * 100)
    hdr = f"{'m':>4} {'n':>4} | {'N_billetes':>11} {'N_azules':>9} {'N_fusionados':>13} {'N_1xident':>10} | {'infl_azul':>10} {'infl_fus':>10} {'infl_1xid':>10}"
    print(hdr); print("-" * len(hdr))
    for (m, n) in [(1, 0), (1, 14), (5, 14), (10, 14), (50, 14)]:
        d, tip, rech, copias, iX = construir(m, n, u2=True, u3="dynamic")
        ch = d.selected_chain(tip)
        naz = nfu = n1x = 0
        vistas = set()                # identidades ya contadas (regla corregida R-FIN-13')
        for c in ch[1:]:
            nd = d.gd[c]
            naz += len(nd.mergeset_blues[1:])
            nfu += len(nd.mergeset_blues[1:]) + len(nd.mergeset_reds)
            # R-FIN-13' : cuenta un bloque por IDENTIDAD (azules + rojos-k, nunca rojos-U3'')
            for h in list(nd.mergeset_blues[1:]) + list(nd.mergeset_reds):
                idh = d.B[h].ident
                if idh not in vistas:
                    vistas.add(idh); n1x += 1
        naz += len(ch) - 1            # los propios bloques de cadena son azules
        nfu += len(ch) - 1
        for c in ch[1:]:
            idh = d.B[c].ident
            if idh not in vistas:
                vistas.add(idh); n1x += 1
        nB = sum(1 for h in d.B if h.startswith("B"))
        nbill = nB + 1 + 1            # B_j (m) + el billete X + H0
        print(f"{m:>4} {n:>4} | {nbill:>11} {naz:>9} {nfu:>13} {n1x:>10} | {naz/nbill:>10.3f} {nfu/nbill:>10.3f} {n1x/nbill:>10.3f}")
    print()
    print("LECTURA C2: la columna infl_fus es el factor por el que el retarget SOBREESTIMA la tasa")
    print("  de bloques si cuenta todos los validos. Tiende a max_block_parents = 15. Es EXACTAMENTE")
    print("  la mitad (a) del ATAQUE 3 de la ronda 1: 'el DAA ve x11 bloques por billete'.")
    print("  La columna infl_azul se queda en ~1: contar azules es inmune por U3'' dinamica.")
    print("  infl_1xid es la REGLA CORREGIDA (R-FIN-13', un bloque por IDENTIDAD): tambien inmune,")
    print("  y ademas -- ver C1 -- cuenta a los rojos-k, que es lo que mata la inflacion del retarget.")


if __name__ == "__main__":
    t0 = time.time()
    c1()
    c2()
    print(f"\n[{time.time()-t0:.0f} s]")
