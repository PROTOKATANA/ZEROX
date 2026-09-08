#!/usr/bin/env python3
"""
r8c_a3b_presupuesto.py — LINEA A3, segunda parte: el ataque de PRESUPUESTO de D9-a sigue vivo
bajo U3'-FILTRO. R-FIN-11 no lo cierra.

Construccion (determinista):
  · cadena honesta profunda -> Q, con blue_work alto y past LIBRE DE COPIAS.
  · el atacante cuelga N copias del mismo billete X de un bloque viejo `base`.
  · portadores Y_1..Y_c del atacante, cada uno = [base] + (mp-1) copias  (R-FIN-12 respetada).
    Dentro de cada Y_j el sp ES una copia, asi que el filtro deja 1 azul: los Y_j NO son el
    vector del dano, solo el transporte.
  · un bloque honesto M = [Q] + Y_1..Y_c + puntas honestas.
    sp(M) = Q  =>  past(sp) SIN copias  =>  el filtro NO dispara sobre NINGUNA copia
    =>  las N copias entran en el voraz, son las MAS BARATAS, y agotan el tope k+1.

Metrica: cuantos bloques HONESTOS del mergeset quedan rojos por culpa de las copias.
Es exactamente la refutacion de D9-a (`dag-poas-ancla-de-orden-auditoria.md` §1).
"""
import sys
from r8c_gd import DAG

K = int(sys.argv[1]) if len(sys.argv) > 1 else 30
MP = max(10, min(16, K // 2))
MSL = 180


def ataque(u3_mode, n_portadores, n_puntas_honestas=4, prof=40, retro=20):
    d = DAG(k=K, u2=True, u3_mode=u3_mode, max_parents=MP, mergeset_limit=MSL)
    g = d.genesis()
    prev = g
    for i in range(prof):
        d.add(f"C{i}", [prev], t=1.0 + i, creator="h", ident=("h", f"C{i}"), sd=0)
        prev = f"C{i}"
    base = f"C{prof-1-retro}"     # `retro` = cuantos bloques de cadena atras cuelgan las copias
    Q = prev                      # punta honesta profunda, bw alto, past sin copias

    # puntas honestas contemporaneas (lambda*Delta ~ 4), colgadas de Q
    puntas = []
    for i in range(n_puntas_honestas):
        d.add(f"T{i}", [Q], t=100.0, creator="h", ident=("h", f"T{i}"), sd=10 + i)
        puntas.append(f"T{i}")

    # copias + portadores
    ncop = 0
    portadores = []
    for j in range(n_portadores):
        grupo = []
        for i in range(MP - 1):
            bid = f"X{j}_{i}"
            ok, _ = d.add(bid, [base], t=99.0, creator="a", ident=("a", "X"),
                          sd=900000 + ncop)
            assert ok
            grupo.append(bid); ncop += 1
        ok, why = d.add(f"Y{j}", [base] + grupo, t=99.5, creator="a",
                        ident=("a", f"Y{j}"), sd=800000 + j)
        assert ok, why
        portadores.append(f"Y{j}")

    padres = [Q] + puntas + portadores
    padres = padres[:MP]
    ok, why = d.add("M", padres, t=101.0, creator="h", ident=("h", "M"), sd=0)
    if not ok:
        return dict(err=why, ncop=ncop)
    nd = d.gd["M"]
    cop_ms = [h for h in nd.mergeset_blues + nd.mergeset_reds if d.B[h].ident == ("a", "X")]
    az_cop = [h for h in nd.mergeset_blues if d.B[h].ident == ("a", "X")]
    hon_ms = [h for h in nd.mergeset_blues + nd.mergeset_reds if d.B[h].creator == "h"]
    az_hon = [h for h in nd.mergeset_blues if d.B[h].creator == "h"]
    return dict(err=None, sp=nd.sp, ms=nd.mergeset_size(), copias_ms=len(cop_ms),
                az_cop=len(az_cop), hon_ms=len(hon_ms), az_hon=len(az_hon),
                roj_hon=len(hon_ms) - len(az_hon), azules=len(nd.mergeset_blues), ncop=ncop)


if __name__ == "__main__":
    print(f"=== A3b · presupuesto k-cluster · k={K}, mp={MP}, mergeset_size_limit={MSL} ===")
    print("Referencia SIN atacante: el mergeset honesto son 4 puntas -> 4 azules honestos.\n")
    print(f"{'u3_mode':>9} {'portad.':>8} {'copias':>7} | {'|mergeset|':>10} {'azules':>7} "
          f"{'az.COPIAS':>10} {'hon. en ms':>11} {'az.hon':>7} {'ROJOS hon':>10}")
    print("-" * 96)
    for mode in ("off", "post", "filter", "dynamic"):
        for nc in (0, 2, 6, 10):
            r = ataque(mode, nc)
            if r["err"]:
                print(f"{mode:>9} {nc:>8} {r['ncop']:>7} | INVALIDO: {r['err']}")
                continue
            print(f"{mode:>9} {nc:>8} {r['ncop']:>7} | {r['ms']:>10} {r['azules']:>7} "
                  f"{r['az_cop']:>10} {r['hon_ms']:>11} {r['az_hon']:>7} {r['roj_hon']:>10}")
    print("\nBarrido de `retro` (a que profundidad de cadena cuelgan las copias), 10 portadores:")
    print(f"{'retro':>6} | {'filter az.cop':>14} {'filter ROJOS hon':>17} | "
          f"{'dynamic az.cop':>15} {'dynamic ROJOS hon':>18}")
    for retro in (0, 1, 2, 4, 8, 16, 30):
        rf = ataque("filter", 10, retro=retro)
        rd = ataque("dynamic", 10, retro=retro)
        print(f"{retro:>6} | {rf['az_cop']:>14} {rf['roj_hon']:>17} | "
              f"{rd['az_cop']:>15} {rd['roj_hon']:>18}")
