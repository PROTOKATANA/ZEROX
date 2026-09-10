#!/usr/bin/env python3
r"""
d14k_fixture_test.py — control positivo del instrumento contra el vector REAL de la
implementación de referencia (corrección A3 de audita-d9b.md).

Carga `ref_umc_fixture.json` (idéntico byte a byte a
`rusty-kaspa@dagknight:consensus/umc_fixture.json`, md5 41cf6d88eafa4079112bbc824bcf823f)
y exige, por la ruta de `d14k_ref`:
  · la zona del fixture (tips [11, 17], subgroup [11], CG=1, k=0) da virtual_score=4 y
    rojos 12..17, con el gris 8 excluido de la votación;
  · el rank de la cadena pura 1..11 es 0;
  · el pipeline completo `rank_view` da rank 0 con dos subgrupos aceptados.
Salida: salida_fixture_test.txt.
"""
import json
import os
import sys

_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, _DIR)
sys.path.insert(0, os.path.normpath(os.path.join(_DIR, "..", "d9-ronda8c")))

from d14k_lib import KDag  # noqa: E402
import d14k_ref as R  # noqa: E402


def main():
    with open(os.path.join(_DIR, "ref_umc_fixture.json")) as f:
        fx = json.load(f)
    bloques = fx["blocks"]
    idx = {b["id"]: i for i, b in enumerate(bloques)}
    parents = [tuple(idx[p] for p in b["parents"]) for b in bloques]
    kd = KDag(parents, [0.0] * len(bloques), ["h"] * len(bloques))
    cp = [None if b["sp"] == 0 else idx[b["sp"]] for b in bloques]
    kd.set_chain(cp)
    bw = [b["blue_work"] for b in bloques]

    lineas = []

    def p(s=""):
        lineas.append(s)

    p("=" * 96)
    p("CONTROL POSITIVO DEL INSTRUMENTO — fixture de rusty-kaspa@dagknight")
    p("fixture: genesis=1, k=0, subgroup=[11], virtual sp=11, blues=[11], reds=12..17")
    p("=" * 96)

    # 1 · zona directa: la cadena 1..11 como subgrupo, tips [11, 17]
    tips = [idx[11], idx[17]]
    kv, grupos = R.rank_view(kd, tips, bw, kmax=10)
    p()
    p(f"1 · rank_view(tips=[11,17]) = {kv}   (esperado 0)")
    for (nca, gtips, vsp, blues, reds, score) in grupos:
        p(f"    subgrupo NCA=b{bloques[nca]['id']} vsp=b{bloques[vsp]['id']} "
          f"blues={[bloques[i]['id'] for i in blues]} "
          f"rojos={[bloques[i]['id'] for i in reds]} score={score}")
    ok_rank = kv == 0
    p(f"    rank 0: {'OK' if ok_rank else 'FALLO'}")

    # 2 · votación exacta de la zona del fixture (NCA real = next_after(11, CG=1) = 2)
    zd, zone = R.committed_coloring(kd, [idx[11]], idx[2], idx[1], 0)
    vnd = R.virtual_coloring(kd, zd, tips, idx[11], idx[1], 0, bw)
    ok, score, blues, reds = R.umc_voting(kd, zd, idx[1], idx[2], vnd, 0, bw)
    ids_blues = sorted(bloques[i]["id"] for i in blues)
    ids_reds = sorted(bloques[i]["id"] for i in reds)
    p()
    p(f"2 · umc_voting(zona [11], NCA=2, CG=1, k=0): aceptado={ok} score={score} "
      f"(esperado True/4)")
    p(f"    azules={ids_blues}")
    p(f"    rojos={ids_reds}  (esperado 12..17)")
    p(f"    gris 8 excluido: {8 not in ids_reds and 8 not in ids_blues}")
    ok_score = ok and score == 4
    ok_reds = ids_reds == list(range(12, 18))
    p(f"    score=4: {'OK' if ok_score else 'FALLO'}; rojos 12..17: "
      f"{'OK' if ok_reds else 'FALLO'}")

    # 3 · la cadena pura 1..11 (sub-DAG) tiene rank 0
    n11 = idx[11] + 1
    kd11 = KDag([tuple(pp for pp in parents[i] if pp < n11) for i in range(n11)])
    kd11.set_chain([None if cp[i] is None else cp[i] for i in range(n11)])
    kv11, _ = R.rank_view(kd11, [idx[11]], bw[:n11], kmax=10)
    p()
    p(f"3 · rank de la cadena pura 1..11 = {kv11}   (esperado 0)")
    ok_cadena = kv11 == 0

    todo = ok_rank and ok_score and ok_reds and ok_cadena
    p()
    p(f"VEREDICTO: {'PASA' if todo else 'FALLA'} — instrumento anclado al vector de la "
      f"implementación de referencia")
    texto = "\n".join(lineas)
    print(texto)
    with open(os.path.join(_DIR, "salida_fixture_test.txt"), "w") as f:
        f.write(texto + "\n")
    return 0 if todo else 1


if __name__ == "__main__":
    sys.exit(main())
