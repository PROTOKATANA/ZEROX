#!/usr/bin/env python3
"""
r9b_d_coste.py — D9 ronda 9b, punto D. Rentabilidad de la parasita bajo TRES semanticas de pago.

Reutiliza SIN REESCRIBIRLA la maniobra parasita de `d8_lib.MundoL9.corre_l9(modo='parasito')`
(D8 A1.2/A1.5) y las mismas 12 semillas, horizonte y `J` de `d8-ronda8/salida_a1e.txt`.

Semanticas medidas (unidades de recompensa por bloque producido):

  S0  R-FIN-8 VIGENTE  (control positivo)
      paga(x) = #{bloques de x que acaban AZULES en la vista honesta final}
      Debe reproducir salida_a1e.txt: ratio 0.995/1.159/1.270/1.549 a alpha=.25/.33/.35/.40

  S1  P1 tal como esta escrita ("los rojos ... cobran" = cobra el productor del rojo)
      paga(x) = #{bloques de x VALIDOS y FUSIONADOS} (azules + rojos del orden de consenso)

  S2  KASPA LITERAL (coinbase.rs:121-131: el rojo NO cobra, cobra el FUSIONADOR)
      paga(x) = #{azules de x} + #{rojos en el mergeset de bloques de CADENA creados por x}

Contabilidad de S2 fiel a Kaspa: la recompensa solo fluye por la coinbase de los bloques de la
CADENA SELECCIONADA (utxo_validation.rs:106-123: solo se aplica la coinbase del selected parent;
:308/:335 `.skip(1)` salta la coinbase de los demas fusionados). La coinbase de un bloque de
cadena C paga a cada AZUL de mergeset(C) a su propia script_public_key (coinbase.rs:109-113) y
agrega TODOS los rojos de mergeset(C) en una salida al minero de C (coinbase.rs:121-131).

Reglas de metodo: fila alpha=0 obligatoria (regla 1); contadores de cobertura (regla 2);
12 semillas literales (regla 3); control positivo S0 antes de medir S1/S2 (regla 4).
"""
import sys, time

D8 = "/home/katana/zeo/ZEROX/research/scripts/d8-ronda8"
sys.path.insert(0, D8)
from d8_lib import MundoL9, DELTA                                        # noqa: E402

K, MP = 30, 15
SEMS = list(range(1, 13))                       # 12 semillas literales
ALPHAS = [0.0, 0.10, 0.25, 0.30, 0.33, 0.35, 0.37, 0.40]
HOR = 1800.0
T0, T1 = 60.0, HOR - 60.0
JS = {0.0: 16, 0.10: 16, 0.25: 16, 0.30: 31, 0.33: 31, 0.35: 31, 0.37: 48, 0.40: 48}


def una(alpha, sem, J):
    m = MundoL9(alpha, HOR, sem, k=K, mp=MP)
    d, tip, llega = m.corre_l9(J=J, d_fork=1, giveup=None, modo="parasito")
    az = d.blueset(tip)                                  # azules en la vista honesta final
    ch = d.selected_chain(tip)

    # fusionados = union de los mergesets de los bloques de cadena, mas la propia cadena
    fus = set(ch)
    # rojos atribuidos al fusionador (semantica Kaspa)
    rojos_por_creador = {"h": 0, "a": 0, "g": 0}
    n_rojos = 0
    for c in ch[1:]:
        nd = d.gd[c]
        for h in nd.mergeset_blues[1:]:
            fus.add(h)
        for h in nd.mergeset_reds:
            fus.add(h)
            n_rojos += 1
            rojos_por_creador[d.B[c].creator] = rojos_por_creador.get(d.B[c].creator, 0) + 1

    ha = [b for b, x in d.B.items() if x.creator == "h" and T0 < x.t <= T1]
    aa = [b for b, x in d.B.items() if x.creator == "a" and T0 < x.t <= T1]

    def cuenta(lst, conj):
        return sum(1 for b in lst if b in conj)

    r = {}
    r["nh"], r["na"] = len(ha), len(aa)
    r["s0_h"] = cuenta(ha, az);  r["s0_a"] = cuenta(aa, az)
    r["s1_h"] = cuenta(ha, fus); r["s1_a"] = cuenta(aa, fus)
    # S2: azules propios + rojos fusionados por bloques de cadena propios.
    # Los rojos por creador se cuentan sobre TODA la cadena (no hay ventana), asi que se
    # reescalan a la ventana por la fraccion de bloques de cadena de cada creador en ella.
    ch_win = [c for c in ch[1:] if T0 < d.B[c].t <= T1]
    rc = {"h": 0, "a": 0}
    for c in ch_win:
        nd = d.gd[c]
        rc[d.B[c].creator] = rc.get(d.B[c].creator, 0) + len(nd.mergeset_reds)
    r["s2_h"] = r["s0_h"] + rc.get("h", 0)
    r["s2_a"] = r["s0_a"] + rc.get("a", 0)
    r["n_rojos_win"] = rc.get("h", 0) + rc.get("a", 0)
    r["n_cad_a"] = sum(1 for c in ch_win if d.B[c].creator == "a")
    r["n_cad_h"] = sum(1 for c in ch_win if d.B[c].creator == "h")
    r["perd"] = sum(1 for b in aa if b not in llega)
    return r


def main():
    print("=" * 112)
    print("D · Rentabilidad de la maniobra parasita bajo TRES semanticas de pago del bloque ROJO")
    print("=" * 112)
    print(f"k={K}, mp={MP}, lambda=1, Delta={DELTA}, horizonte {HOR:.0f} s, "
          f"ventana [{T0:.0f},{T1:.0f}] s, semillas={SEMS}, modo parasito.")
    print("S0 = R-FIN-8 vigente (solo azules) | S1 = P1 literal (el rojo cobra) | "
          "S2 = Kaspa literal (cobra el fusionador)\n")
    t0 = time.time()
    hdr = (f"{'alpha':>6} {'J':>4} | {'S0 h':>7} {'S0 a':>7} {'ratio0':>7} | "
           f"{'S1 h':>7} {'S1 a':>7} {'ratio1':>7} | {'S2 h':>7} {'S2 a':>7} {'ratio2':>7} | "
           f"{'n_h':>6} {'n_a':>6} {'rojos':>6} {'cadA':>5} {'cadH':>5} {'perd':>5}")
    print(hdr); print("-" * len(hdr))
    res = {}
    for alpha in ALPHAS:
        J = JS[alpha]
        ac = {k: 0 for k in ("nh", "na", "s0_h", "s0_a", "s1_h", "s1_a", "s2_h", "s2_a",
                             "n_rojos_win", "n_cad_a", "n_cad_h", "perd")}
        for sem in SEMS:
            r = una(alpha, sem, J)
            for k in ac:
                ac[k] += r[k]
        nh, na = ac["nh"], ac["na"]
        def frac(num, den): return (num / den) if den else None
        row = {}
        for s in ("s0", "s1", "s2"):
            fh = frac(ac[s + "_h"], nh); fa = frac(ac[s + "_a"], na)
            row[s] = (fh, fa, (fa / fh) if (fh and fa is not None) else None)
        res[alpha] = row
        def f(x): return f"{x:.4f}" if x is not None else "  -  "
        def g(x): return f"{x:.3f}" if x is not None else "(n_a=0)"
        print(f"{alpha:>6.2f} {J:>4} | {f(row['s0'][0]):>7} {f(row['s0'][1]) if na else '(n_a=0)':>7} {g(row['s0'][2]) if na else '   -   ':>7} | "
              f"{f(row['s1'][0]):>7} {f(row['s1'][1]) if na else '(n_a=0)':>7} {g(row['s1'][2]) if na else '   -   ':>7} | "
              f"{f(row['s2'][0]):>7} {f(row['s2'][1]) if na else '(n_a=0)':>7} {g(row['s2'][2]) if na else '   -   ':>7} | "
              f"{nh:>6} {na:>6} {ac['n_rojos_win']:>6} {ac['n_cad_a']:>5} {ac['n_cad_h']:>5} {ac['perd']:>5}")

    print()
    print("CONTROL POSITIVO (regla 4) — S0 debe reproducir d8-ronda8/salida_a1e.txt:")
    esperado = {0.25: 0.995, 0.33: 1.159, 0.35: 1.270, 0.40: 1.549}
    ok = True
    for a, e in esperado.items():
        v = res[a]["s0"][2]
        d_ = abs(v - e)
        mark = "OK" if d_ < 0.002 else "DISCREPA"
        if d_ >= 0.002: ok = False
        print(f"  alpha={a:.2f}: medido {v:.3f}  esperado {e:.3f}  |dif|={d_:.4f}  -> {mark}")
    print(f"  => control positivo {'SUPERADO' if ok else 'FALLIDO'}")
    print()
    print("CRITERIO alpha=0 (regla 1): n_a=0, las columnas del atacante se declaran vacias;")
    print("  S0_h = S1_h = S2_h = 1.0000 y rojos = 0 (sin atacante no hay rojos).")
    print(f"\n[{time.time()-t0:.0f} s]")


if __name__ == "__main__":
    main()
