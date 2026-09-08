#!/usr/bin/env python3
"""r8c_test_gd.py — pruebas del simulador contra hechos verificables del paper y del clon."""
import sys
from r8c_gd import DAG


def t1_cadena():
    """Cadena pura: todos azules, blue_score = altura, pos = altura."""
    d = DAG(k=3, u2=False, u3_mode="off")
    g = d.genesis()
    prev = g
    for i in range(1, 8):
        ok, _ = d.add(f"C{i}", [prev], t=i)
        assert ok
        prev = f"C{i}"
    assert d.gd["C7"].blue_score == 7, d.gd["C7"].blue_score
    assert d.gd["C7"].pos == 7
    assert len(d.blueset("C7")) == 8
    return "t1 cadena pura OK"


def t2_kcluster():
    """k+1 hermanos en anticono mutuo son todos azules; el k+2 es rojo.
    protocol.rs:249-251 -> tope mergeset_blues == k+1 (incluye el sp)."""
    for k in (2, 3, 5, 25):
        d = DAG(k=k, u2=False, u3_mode="off", max_parents=10**6)
        g = d.genesis()
        sibs = []
        for i in range(k + 5):
            bid = f"S{i}"
            d.add(bid, [g], t=1 + i * 0.001, sd=i)
            sibs.append(bid)
        d.add("M", sibs, t=10, sd=0)
        nb = len(d.gd["M"].mergeset_blues)
        assert nb == k + 1, (k, nb)
    return "t2 tope k+1 en mergeset_blues OK (k=2,3,5,25)"


def t3_bw_monotona():
    """LEMA propio: B in past(C)  =>  blue_work(B) < blue_work(C).
    Base: todo padre tiene bw <= bw(sp) < bw(C) (mergeset_blues siempre contiene al sp)."""
    import random
    rng = random.Random(7)
    d = DAG(k=4, u2=False, u3_mode="off")
    g = d.genesis()
    all_b = [g]
    for i in range(120):
        ps = rng.sample(all_b, min(len(all_b), rng.randint(1, 4)))
        bid = f"B{i}"
        ok, _ = d.add(bid, ps, t=i, sd=rng.randint(0, 10**6))
        if ok:
            all_b.append(bid)
    viol = 0
    for h in all_b:
        for a in d.anc[h]:
            if d.gd[a].blue_work >= d.gd[h].blue_work:
                viol += 1
    assert viol == 0, viol
    return f"t3 blue_work estrictamente creciente sobre el past: 0 violaciones en {len(all_b)} bloques"


def t4_orden_topologico():
    """El orden total es topologico y contiene TODOS los bloques del past del tip."""
    import random
    rng = random.Random(11)
    d = DAG(k=4, u2=False, u3_mode="off")
    g = d.genesis()
    all_b = [g]
    for i in range(150):
        ps = rng.sample(all_b, min(len(all_b), rng.randint(1, 5)))
        bid = f"B{i}"
        ok, _ = d.add(bid, ps, t=i, sd=rng.randint(0, 10**6))
        if ok:
            all_b.append(bid)
    tip = d.virtual_sp()
    order = d.total_order(tip)
    idx = {h: i for i, h in enumerate(order)}
    esperado = d.anc[tip] | {tip}
    assert set(order) == esperado, (len(order), len(esperado))
    assert len(order) == len(set(order))
    for h in order:
        for a in d.anc[h]:
            assert idx[a] < idx[h], (a, h)
    # el bloque de cadena va DESPUES de su mergeset (ghostdag.rs:83-91 / paper L297-300)
    ch = d.selected_chain(tip)
    for c in ch[1:]:
        for m in list(d.gd[c].mergeset_blues[1:]) + list(d.gd[c].mergeset_reds):
            assert idx[m] < idx[c], (m, c)
    return f"t4 orden topologico, {len(order)} bloques, cadena de {len(ch)}: el bloque va tras su mergeset OK"


def t5_cadena_subset_azules():
    """La cadena seleccionada es subconjunto del blue set (sin U3'/U2)."""
    import random
    rng = random.Random(3)
    d = DAG(k=6, u2=False, u3_mode="off")
    g = d.genesis()
    all_b = [g]
    for i in range(200):
        ps = rng.sample(all_b, min(len(all_b), rng.randint(1, 6)))
        ok, _ = d.add(f"B{i}", ps, t=i, sd=rng.randint(0, 10**6))
        if ok:
            all_b.append(f"B{i}")
    tip = d.virtual_sp()
    bs = d.blueset(tip)
    ch = set(d.selected_chain(tip))
    assert ch <= bs, ch - bs
    return "t5 cadena seleccionada subset de azules OK"


def t6_limites_kaspa():
    """R-FIN-12: >12 padres y mergeset>180 -> bloque invalido."""
    d = DAG(k=25, u2=False, u3_mode="off")
    g = d.genesis()
    sibs = []
    for i in range(200):
        d.add(f"S{i}", [g], t=1 + i * 1e-4, sd=i)
        sibs.append(f"S{i}")
    ok, why = d.add("P13", sibs[:13], t=5)
    assert (not ok) and why == "TooManyParents", (ok, why)
    # 12 padres pero mergeset gigante: cadenitas para inflar el mergeset
    ok, why = d.add("M", sibs[:12], t=5)
    assert ok
    # construimos un portador con mergeset > 180 usando 12 padres que cubran 200 hermanos
    d2 = DAG(k=25, u2=False, u3_mode="off")
    g2 = d2.genesis()
    sib2 = []
    for i in range(200):
        d2.add(f"S{i}", [g2], t=1 + i * 1e-4, sd=i)
        sib2.append(f"S{i}")
    caps = []
    for j in range(12):
        grupo = sib2[j * 16:(j + 1) * 16] or [g2]
        d2.add(f"K{j}", grupo[:12] if len(grupo) > 12 else grupo, t=5 + j * 1e-3, sd=1000 + j)
        caps.append(f"K{j}")
    ok, why = d2.add("BIG", caps, t=9)
    return f"t6 R-FIN-12: 13 padres -> TooManyParents OK; portador de 12 caps -> ok={ok} ({why})"


if __name__ == "__main__":
    for f in (t1_cadena, t2_kcluster, t3_bw_monotona, t4_orden_topologico,
              t5_cadena_subset_azules, t6_limites_kaspa):
        try:
            print("  ", f())
        except AssertionError as e:
            print("   FALLO", f.__name__, e)
            sys.exit(1)
    print("Todas las pruebas del simulador pasan.")
