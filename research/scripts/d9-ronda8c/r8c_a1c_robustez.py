#!/usr/bin/env python3
"""
r8c_a1c_robustez.py — autocritica de la medida de A1.

(a) ?Depende `m` de la POSICION elegida?  (P = 15, 25, 35, 45)
(b) ?Depende `m` del NUMERO de estrategias que enumero? Si al doblar la familia `m` sigue
    creciendo, mi numero es una COTA INFERIOR y hay que decirlo. Curva de saturacion.
(c) CONTROL: un adversario que solo puede cambiar cosas que NO afectan al DAG (aqui: el orden en
    que se le presentan sus propias opciones) tiene que dar menu 1. Si no, hay artefacto.
"""
import statistics
from r8c_sim import Mundo
from r8c_a1_menu import estrategias, K, MP


def m_en(alpha, semilla, P, tope=None, T=260.0):
    m = Mundo(alpha, T, semilla, k=K, mp=MP, u3_mode="dynamic")
    d0, tip0 = m.corre({})
    tiers, idx = estrategias(m, P, d0, tip0)
    if tiers is None:
        return None
    todas = [e for g in tiers for e in g]
    if tope is not None:
        todas = todas[:tope]
    vis = set()
    for e in todas:
        d, tip = m.corre(e)
        s = Mundo.ancla(d, tip, P)
        if s is not None:
            vis.add(s)
    return len(vis), len(todas)


def control(alpha, semilla, P, T=260.0):
    """(c) el mismo conjunto de estrategias, pero presentado en 5 ordenes distintos.
    El menu tiene que ser IDENTICO: el DAG no depende del orden de enumeracion."""
    import random
    m = Mundo(alpha, T, semilla, k=K, mp=MP, u3_mode="dynamic")
    d0, tip0 = m.corre({})
    tiers, idx = estrategias(m, P, d0, tip0)
    if tiers is None:
        return None
    todas = [e for g in tiers for e in g]
    res = []
    for r in range(5):
        random.Random(r).shuffle(todas)
        vis = set()
        for e in todas:
            d, tip = m.corre(e)
            s = Mundo.ancla(d, tip, P)
            if s is not None:
                vis.add(s)
        res.append(len(vis))
    return res


if __name__ == "__main__":
    print("=== A1c · robustez de la medida de `m` ===\n")
    print("(a) `m` GRATIS+retraso+retencion frente a la posicion P (8 semillas)")
    print(f"{'alpha':>6} " + "".join(f"{'P='+str(p):>9}" for p in (15, 25, 35, 45)))
    for a in (0.0, 0.10, 0.25, 0.40):
        fila = f"{a:>6.2f} "
        for P in (15, 25, 35, 45):
            vals = [m_en(a, s, P) for s in range(1, 9)]
            vals = [v[0] for v in vals if v]
            fila += f"{statistics.mean(vals):>9.2f}" if vals else f"{'-':>9}"
        print(fila)

    print("\n(b) saturacion: `m` frente al numero de estrategias enumeradas (P=30, 8 semillas)")
    print(f"{'alpha':>6} " + "".join(f"{'n='+str(n):>9}" for n in (10, 25, 50, 100, 200, 400)))
    for a in (0.10, 0.25, 0.40):
        fila = f"{a:>6.2f} "
        for n in (10, 25, 50, 100, 200, 400):
            vals = [m_en(a, s, 30, tope=n) for s in range(1, 9)]
            vals = [v[0] for v in vals if v]
            fila += f"{statistics.mean(vals):>9.2f}" if vals else f"{'-':>9}"
        print(fila)

    print("\n(c) CONTROL: mismo conjunto de estrategias en 5 ordenes distintos (tiene que ser fijo)")
    for a in (0.10, 0.25):
        for s in (1, 4):
            print(f"    alpha={a} semilla={s}: {control(a, s, 30)}")
