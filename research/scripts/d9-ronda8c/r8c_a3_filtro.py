#!/usr/bin/env python3
"""
r8c_a3_filtro.py — LINEA A3. Contraejemplo DETERMINISTA a U3'-filtro tal como esta escrita
en R-FIN-11:

  "de varias copias con la misma identidad, solo es candidata a azul la que no tenga su identidad
   YA AZUL EN past(sp); las demas se marcan rojas ANTES del voraz k-cluster"

La condicion mira SOLO `past(sp)`. Basta con que el atacante RETENGA el original y publique las
copias en el ANTICONO del padre seleccionado: entonces ninguna copia tiene su identidad azul en
past(sp), TODAS pasan el filtro, y el voraz k-cluster las colorea a todas de azul porque son
mutuamente vecinas de un anticono pequeno.

Un bloque puede referenciar `max_block_parents` padres (R-FIN-12): sp + (mp-1) copias.
=> UN billete produce (mp-1) bloques AZULES en el coloreado de un solo bloque.
   k=30 -> mp=15 -> 14 azules por billete.   k=25 -> mp=12 -> 11 azules por billete.

Y como blue_work suma sobre los AZULES (protocol.rs:155-163), esas copias COMPRAN blue_work:
el bloque que las fusiona gana la carrera de padre seleccionado. Eso es el puente a la linea A1.

Verifica ademas:
 - U2 (R-FIN-11) SI cierra el caso "original publicado": las copias son invalidas.
 - u3_mode='dynamic' (mi reparacion) cierra el caso "original retenido".
"""
import sys
from r8c_gd import DAG

K = int(sys.argv[1]) if len(sys.argv) > 1 else 30
MP = max(10, min(16, K // 2))


def caso(u3_mode, n_copias, retener_original=True, prof_honesta=6):
    """Cadena honesta G..P..Q (para que bw(Q) sea el mayor y Q sea el sp), y un bloque
    fusionador M = [Q] + copias. Devuelve el coloreado de M."""
    d = DAG(k=K, u2=True, u3_mode=u3_mode, max_parents=MP)
    g = d.genesis()
    prev = g
    for i in range(prof_honesta):
        d.add(f"C{i}", [prev], t=1.0 + i, creator="h", ident=("h", f"C{i}"), sd=0)
        prev = f"C{i}"
    base = prev                       # bloque del que cuelgan las copias
    d.add("Q", [base], t=10.0, creator="h", ident=("h", "Q"), sd=0)   # sp copy-free, bw maximo

    copias, invalidas = [], 0
    if not retener_original:
        d.add("X0", [base], t=9.0, creator="a", ident=("a", "X"), sd=5)
        # el original se publica: cualquier copia que lo tenga en su past es invalida por U2.
        # El atacante lo evita colgando las copias del mismo `base`; U2 solo mira el past.
    for i in range(n_copias):
        bid = f"X{i+1}"
        ok, why = d.add(bid, [base], t=11.0, creator="a", ident=("a", "X"), sd=900000 + i)
        if ok:
            copias.append(bid)
        else:
            invalidas += 1

    padres = ["Q"] + copias[:MP - 1]
    ok, why = d.add("M", padres, t=12.0, creator="h", ident=("h", "M"), sd=0)
    if not ok:
        return dict(err=why)
    nd = d.gd["M"]
    az_cop = [h for h in nd.mergeset_blues if d.B[h].ident == ("a", "X")]
    ro_cop = [h for h in nd.mergeset_reds if d.B[h].ident == ("a", "X")]
    return dict(sp=nd.sp, azules=len(nd.mergeset_blues), az_copias=len(az_cop),
                rojas=len(ro_cop), bw_M=nd.blue_work, bw_Q=d.gd["Q"].blue_work,
                invalidas=invalidas, en_mergeset=len(copias[:MP - 1]))


def compite(u3_mode):
    """El puente a A1: Z (atacante) = [Q] + 14 copias  vs  H (honesto) = [Q] + 4 tips honestos.
    Quien gana la carrera de blue_work y por tanto la posicion de cadena?"""
    d = DAG(k=K, u2=True, u3_mode=u3_mode, max_parents=MP)
    g = d.genesis()
    prev = g
    for i in range(6):
        d.add(f"C{i}", [prev], t=1.0 + i, creator="h", ident=("h", f"C{i}"), sd=0)
        prev = f"C{i}"
    base = prev
    d.add("Q", [base], t=10.0, creator="h", ident=("h", "Q"), sd=0)
    tips_h = []
    for i in range(4):                                  # lambda*Delta ~ 4 puntas honestas
        d.add(f"T{i}", [base], t=10.1, creator="h", ident=("h", f"T{i}"), sd=100 + i)
        tips_h.append(f"T{i}")
    cop = []
    for i in range(MP - 1):
        d.add(f"X{i+1}", [base], t=11.0, creator="a", ident=("a", "X"), sd=900000 + i)
        cop.append(f"X{i+1}")
    d.add("H", ["Q"] + tips_h, t=12.0, creator="h", ident=("h", "H"), sd=1)      # honesto
    d.add("Z", ["Q"] + cop, t=12.0, creator="a", ident=("a", "Z"), sd=2)        # atacante
    bwH, bwZ = d.gd["H"].blue_work, d.gd["Z"].blue_work
    gan = d.find_selected_parent(["H", "Z"])
    return dict(bwH=bwH, bwZ=bwZ, gana=gan,
                billetes_Z=1 + 1, billetes_H=1 + 4)     # Z: su propio billete + 1 copiado


if __name__ == "__main__":
    print(f"=== A3 · k={K}, max_block_parents={MP}, mergeset_size_limit=180 (R-FIN-12 activa) ===\n")
    print("(1) Un solo billete, copias en el ANTICONO del padre seleccionado.")
    print(f"{'u3_mode':>9} {'original':>10} {'copias':>7} | {'en mergeset':>12} "
          f"{'AZULES(copia)':>14} {'rojas':>6} {'invalidas U2':>13}")
    print("-" * 84)
    for ret in (True, False):
        for mode in ("off", "post", "filter", "dynamic"):
            r = caso(mode, n_copias=40, retener_original=ret)
            print(f"{mode:>9} {'RETENIDO' if ret else 'publicado':>10} {40:>7} | "
                  f"{r['en_mergeset']:>12} {r['az_copias']:>14} {r['rojas']:>6} {r['invalidas']:>13}")

    print("\n(2) Barrido: cuantas copias caben (tope = max_block_parents - 1).")
    print(f"{'copias ofrecidas':>17} {'AZULES filter':>14} {'AZULES dynamic':>15}")
    for n in (1, 3, 7, MP - 1, MP, 30, 60):
        rf = caso("filter", n_copias=n)
        rd = caso("dynamic", n_copias=n)
        print(f"{n:>17} {rf['az_copias']:>14} {rd['az_copias']:>15}")

    print("\n(3) PUENTE A A1: las copias COMPRAN blue_work y con el la posicion de cadena.")
    print(f"{'u3_mode':>9} {'bw(H) honesto':>14} {'bw(Z) atacante':>15} {'gana sp':>9}")
    for mode in ("off", "filter", "dynamic"):
        r = compite(mode)
        print(f"{mode:>9} {r['bwH']:>14} {r['bwZ']:>15} {r['gana']:>9}")
    print(f"\n   Z gasta 1 billete propio + 1 billete copiado {MP-1} veces;")
    print(f"   H representa {4+1} billetes honestos distintos.")
