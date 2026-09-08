#!/usr/bin/env python3
"""
r9b_a_copias.py — D9 ronda 9b, punto A.

Pregunta: bajo R-FIN-11 (U2 + U3'' dinamica) y R-FIN-12 (max_block_parents=15,
mergeset_size_limit=180), ¿cuantos bloques VALIDOS y FUSIONADOS produce UN solo billete?

Motivo original 1 (ronda 1, ataque 3, `research/dag-poas-auditoria.md:365-372`):
    1 billete -> max_block_parents copias rojas, todas con coinbase aplicada -> inflacion x10.
Motivo original 3 (ronda 3, `research/dag-poas-candidatos-auditoria.md:459-472`):
    1 billete -> N copias rojas con cuerpos DISTINTOS, todas aplicadas -> espacio de bloque gratis.

La afirmacion de P1 (`research/dag-poas-tras-d8-palancas.md:31-33`) es que con U2+U3''
"cada billete paga una vez". Este script la pone a prueba de forma CONSTRUCTIVA
(no estadistica): construye el DAG explicitamente y cuenta.

Control positivo (regla 4): con u3_mode='off' (GHOSTDAG puro) las copias tambien deben
aparecer; y con u2=True el intento ILEGAL (copia colgada de un bloque que ya tiene su
identidad en el pasado) debe ser RECHAZADO -> el instrumento si detecta ilegalidad.
"""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "d9-ronda8c"))
from r8c_gd import DAG

MAXP = 15
K = 25

def construir(m_bloques, n_copias, u2=True, u3="dynamic", k=K, maxp=MAXP):
    """
    H0            : bloque honesto ancla (billete propio h0)
    c_{j,1..n}    : copias del MISMO billete X, todas colgadas de H0
    B_1..B_m      : bloques del atacante, cada uno con billete propio distinto,
                    padres = (B_{j-1} o H0) + n copias frescas.
    Devuelve (dag, tip, contadores).
    """
    d = DAG(k=k, u2=u2, u3_mode=u3, max_parents=maxp)
    g = d.genesis("G")
    ok, _ = d.add("H0", [g], t=0.0, creator="h", ident=("h0", 0), sd=0)
    assert ok
    ident_X = ("X", 0)          # el UNICO billete reutilizado
    rech = {"U2": 0, "TooManyParents": 0, "MergeSetTooBig": 0, "otros": 0}
    copias = []
    prev = "H0"
    for j in range(1, m_bloques + 1):
        pads = [prev]
        for i in range(n_copias):
            cid = f"c{j}_{i}"
            ok, mot = d.add(cid, ["H0"], t=1.0, creator="a", ident=ident_X, sd=i)
            if ok:
                pads.append(cid); copias.append(cid)
            else:
                rech[mot] = rech.get(mot, 0) + 1
        bid = f"B{j}"
        ok, mot = d.add(bid, pads, t=2.0 + j, creator="a", ident=(f"a{j}", 0), sd=0)
        if not ok:
            rech[mot] = rech.get(mot, 0) + 1
            break
        prev = bid
    return d, prev, rech, copias, ident_X

def contar(d, tip, ident_X):
    """Cuenta, sobre el ORDEN DE CONSENSO de la cadena seleccionada que acaba en `tip`,
    cuantos bloques con identidad ident_X quedan FUSIONADOS (= en el mergeset de algun
    bloque de cadena), y de esos cuantos azules y cuantos rojos."""
    ch = d.selected_chain(tip)
    az = ro = 0
    for c in ch[1:]:
        nd = d.gd[c]
        for h in nd.mergeset_blues[1:]:
            if d.B[h].ident == ident_X: az += 1
        for h in nd.mergeset_reds:
            if d.B[h].ident == ident_X: ro += 1
    # el propio tip / bloques de cadena con esa identidad
    for c in ch:
        if d.B[c].ident == ident_X: az += 1
    return az, ro, len(ch)

def main():
    print("=" * 78)
    print("A · ¿Cuantos bloques VALIDOS y FUSIONADOS da UN billete bajo U2+U3'' dinamica?")
    print("=" * 78)
    print(f"  R-FIN-12: max_block_parents = {MAXP}, mergeset_size_limit = 180, k = {K}")
    print()
    print("  m = bloques del atacante (1 billete propio cada uno)")
    print("  n = copias del billete X colgadas como padres extra de cada B_j")
    print()
    hdr = f"{'u3':>8} {'m':>4} {'n':>4} | {'azules_X':>8} {'rojos_X':>8} {'total_X':>8} | {'bill_real':>9} {'pagados':>8} {'x/billete':>9} | rechazos"
    print(hdr); print("-" * len(hdr))
    filas = []
    for u3 in ("dynamic", "off"):
        for (m, n) in [(1, 14), (1, 1), (2, 14), (5, 14), (10, 14), (50, 14), (1, 15), (1, 20)]:
            d, tip, rech, copias, iX = construir(m, n, u2=True, u3=u3)
            az, ro, lch = contar(d, tip, iX)
            # billetes reales gastados = m (uno por B_j) + 1 (el billete X)
            nB = sum(1 for h in d.B if h.startswith("B"))
            bill_real = nB + 1
            pagados = nB + az + ro      # bloques que cobrarian bajo P1 literal
            ratio = pagados / bill_real if bill_real else 0.0
            rs = ",".join(f"{k}={v}" for k, v in rech.items() if v)
            print(f"{u3:>8} {m:>4} {n:>4} | {az:>8} {ro:>8} {az+ro:>8} | {bill_real:>9} {pagados:>8} {ratio:>9.3f} | {rs or '-'}")
            filas.append((u3, m, n, az, ro, bill_real, pagados, ratio))
    print()
    print("CONTROL POSITIVO (regla 4) — el instrumento SI rechaza cuando debe:")
    # copia colgada de un bloque que ya contiene su identidad en el pasado -> U2
    d = DAG(k=K, u2=True, u3_mode="dynamic", max_parents=MAXP)
    g = d.genesis("G")
    d.add("H0", [g], ident=("h0", 0))
    okA, _ = d.add("cA", ["H0"], ident=("X", 0), sd=0)
    okB, motB = d.add("cB", ["cA"], ident=("X", 0), sd=1)   # ilegal: X en past
    print(f"  copia legal (hermana de H0)            -> ok={okA}")
    print(f"  copia ILEGAL (descendiente de otra X)  -> ok={okB} motivo={motB}   [debe ser U2]")
    # exceso de padres
    d2 = DAG(k=K, u2=True, u3_mode="dynamic", max_parents=MAXP)
    g2 = d2.genesis("G"); d2.add("H0", [g2], ident=("h0", 0))
    for i in range(20):
        d2.add(f"z{i}", ["H0"], ident=("X", 0), sd=i)
    okP, motP = d2.add("BB", ["H0"] + [f"z{i}" for i in range(20)], ident=("a", 0))
    print(f"  bloque con 21 padres                   -> ok={okP} motivo={motP}   [debe ser TooManyParents]")
    print()
    print("CONTROL alfa=0 (regla 1): sin atacante (m=0 copias) el DAG no tiene copias.")
    d3, tip3, r3, cop3, iX3 = construir(3, 0, u2=True, u3="dynamic")
    az3, ro3, _ = contar(d3, tip3, iX3)
    print(f"  m=3 n=0 -> azules_X={az3} rojos_X={ro3} total_X={az3+ro3}   [debe ser 0 0 0]")
    print()
    print("LECTURA:")
    print("  * columna rojos_X > 0  =>  hay N-1 copias del MISMO billete VALIDAS y FUSIONADAS.")
    print("    Bajo R-FIN-8 vigente NO cobran y sus tx NO se aplican: los dos motivos estan cerrados.")
    print("    Bajo P1 literal ('los rojos con billete valido dentro de merge_depth cobran')")
    print("    SI cobran y SI se aplican  =>  los dos motivos VUELVEN A ESTAR ABIERTOS.")
    print("  * x/billete es el factor de inflacion: tiende a 1+n = %d con m grande." % (1 + 14))

if __name__ == "__main__":
    main()
