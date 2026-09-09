#!/usr/bin/env python3
"""
verif_emision_lambda.py — la curva de emision del SPEC (C-EMIT-01) simulada a los dos ritmos.

Constantes LEIDAS del SPEC (no inventadas):
  SPEC.md:1452  SOFT_CAP      = 1_000_000_000 ZZK = 1e17 brek
  SPEC.md:1453  SHIFT         = 19
  SPEC.md:1454  TAIL_EMISSION = 32 ZZK/bloque = 3_200_000_000 brek
  SPEC.md:1455  COINBASE_MATURITY = 100 bloques
  SPEC.md:922   N_LARGO       = 262_800 bloques  ("1 ano exacto a 120 s")
  SPEC.md:1461  recompensa_base(H) = max((SOFT_CAP_brek - emitido(H)) >> SHIFT, TAIL_EMISSION)

Afirmaciones del SPEC que se comprueban a T = 120 s:
  - recompensa inicial 190_734_863_281 brek ~ 1_907,35 ZZK
  - cae por debajo del tail hacia el ano 8,16
  - el suministro cruza 1000 M hacia el ano 10,15
  - inflacion perpetua 0,84 %/ano
Y se repite todo a lambda = 1 bloque/s (la rama A'' del DAG), sin tocar constantes.
"""
BREK = 10**8
SOFT_CAP_BREK = 1_000_000_000 * BREK
SHIFT = 19
TAIL_BREK = 32 * BREK
N_LARGO = 262_800
COINBASE_MATURITY = 100

def simula(bloques_por_ano, anos_max=40.0, etiqueta=""):
    emitido = 0
    h = 0
    cruce_tail = None
    cruce_cap = None
    limite = int(bloques_por_ano * anos_max)
    inicial = None
    while h < limite:
        base = max((SOFT_CAP_BREK - emitido) >> SHIFT, TAIL_BREK)
        if inicial is None:
            inicial = base
        if cruce_tail is None and base <= TAIL_BREK:
            cruce_tail = h / bloques_por_ano
        emitido += base
        h += 1
        if cruce_cap is None and emitido >= SOFT_CAP_BREK:
            cruce_cap = h / bloques_por_ano
            if cruce_tail is not None:
                break
    infl = TAIL_BREK * bloques_por_ano / SOFT_CAP_BREK * 100
    return dict(etiqueta=etiqueta, bpa=bloques_por_ano, inicial=inicial,
                cruce_tail=cruce_tail, cruce_cap=cruce_cap, infl=infl,
                tail_ano=TAIL_BREK * bloques_por_ano / BREK)

if __name__ == "__main__":
    print("=" * 78)
    print("A) La curva del SPEC a los dos ritmos, con las MISMAS constantes")
    print("=" * 78)
    filas = [simula(262_800, etiqueta="T = 120 s (para el que se calibro)"),
             simula(365 * 24 * 3600, etiqueta="lambda = 1 b/s (rama A'' del DAG)")]
    for f in filas:
        print(f"\n--- {f['etiqueta']} · {f['bpa']:,} bloques/ano ---".replace(",", " "))
        print(f"  recompensa inicial      : {f['inicial']:,} brek = {f['inicial']/BREK:,.2f} ZZK".replace(",", " "))
        ct = f["cruce_tail"]; cc = f["cruce_cap"]
        print(f"  cae al tail en el ano   : {ct:.4f}" + (f"  = {ct*365:.1f} dias" if ct and ct < 1 else ""))
        print(f"  cruza 1000 M en el ano  : {cc:.4f}" + (f"  = {cc*365:.1f} dias" if cc and cc < 1 else ""))
        print(f"  emision de cola         : {f['tail_ano']:,.0f} ZZK/ano".replace(",", " "))
        print(f"  inflacion perpetua      : {f['infl']:.2f} %/ano")
    print("\n  SPEC.md:1467-1471 dice, para T = 120 s: inicial 1 907,35 ZZK; tail hacia el ano 8,16;")
    print("  cruce de 1000 M hacia el ano 10,15; inflacion 0,84 %/ano; tail 8 409 600 ZZK/ano.")
    print("\n" + "=" * 78)
    print("B) Las ventanas contadas en BLOQUES, a los dos ritmos")
    print("=" * 78)
    print(f"{'ventana':<34}{'a 120 s':>18}{'a 1 bloque/s':>20}")
    for nombre, n in (("N_LARGO (tamano de bloque)", N_LARGO), ("COINBASE_MATURITY", COINBASE_MATURITY),
                      ("MAX_REORG_LENGTH (= MAT-1)", COINBASE_MATURITY - 1)):
        a120 = n * 120; a1 = n * 1
        def fmt(s):
            if s >= 86400: return f"{s/86400:.2f} dias"
            if s >= 3600: return f"{s/3600:.2f} h"
            if s >= 60: return f"{s/60:.1f} min"
            return f"{s:.0f} s"
        print(f"{nombre:<34}{fmt(a120):>18}{fmt(a1):>20}")
    print("\n  SPEC.md:922 dice literalmente: N_LARGO = 262 800 bloques — '1 ano exacto a 120 s'.")
    print("\n" + "=" * 78)
    print("C) CRITERIO: el resultado debe cambiar con el ritmo (si no, no mide nada)")
    print("=" * 78)
    r = filas[1]["infl"] / filas[0]["infl"]
    print(f"  razon de inflacion perpetua entre los dos ritmos: {r:.1f}x  (esperado 120x)")
    print(f"  razon de cruce de 1000 M: {filas[0]['cruce_cap']/filas[1]['cruce_cap']:.1f}x  (esperado ~120x)")
