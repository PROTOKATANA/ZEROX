#!/usr/bin/env python3
"""
r9a_a2_split.py — LINEA 2. El atacante con presupuesto REPARTIDO alpha = alpha_p + alpha_f.

alpha_p ejecuta la cadena parasita de D8 (PUBLICA cada rafaga) y alpha_f mantiene un flujo
PRIVADO desde t0 = 60 s que no se publica nunca. Se mide:
   adv_fin  = blue_work(punta privada) - blue_work(punta publica) al final del horizonte
   adv_max  = maximo de esa diferencia a lo largo del horizonte
   deriva   = adv_fin / (HOR - t0)     [bloques/s]
   tasa_Wpub = azules por segundo de la cadena PUBLICA en la ventana
   r_medido = alpha_f / tasa_Wpub      <- la base real de la carrera
frente a las dos predicciones:
   r_disjunto = alpha_f/(1-alpha)            (tesis del agente principal)
   r_D8       = alpha/((1-alpha)(1-delta))   (el doble conteo de las rondas 3-8)

Tres variantes del flujo privado (sub-pregunta (ii) del encargo):
   'puro'      cadena privada pura
   'hereda'    ademas fusiona las puntas PUBLICADAS de la parasita
   'parasito'  ademas fusiona la vista honesta (freeloading; cota 3k del Lema 12)

CONTROLES OBLIGATORIOS:
   alpha_p = 0  ->  debe reproducir la carrera simple: deriva ~ alpha - (1-alpha) = 2alpha-1
   alpha   = 0  ->  no hay bloques del atacante: adv = 0 y ninguna rama se ejecuta
   alpha_f > 0,5 (fila alpha=0,55, frac_f=1) -> el flujo privado debe GANAR (deriva > 0)
COBERTURA (regla 2): n_f, n_p, n_pub, n_raf, n_hereda, n_freeload por fila.
12 semillas literales (regla 3).
"""
import itertools
import sys
import time
from multiprocessing import Pool

sys.path.insert(0, "/home/katana/zeo/ZEROX/research/scripts/d9-ronda9a")
from r9a_lib import MundoSplit, contabilidad, K, DELTA          # noqa: E402

SEMS = list(range(1, 13))
ALPHAS = [0.00, 0.30, 0.35, 0.40, 0.45, 0.55]
FRACS = [1.0, 0.75, 0.5, 0.25, 0.0]          # alpha_f/alpha
JS = [16, 31, 48, 64]
FLUJOS = ["puro", "hereda", "hereda_est", "parasito", "parasito_est"]
HOR = 1800.0
T0 = 60.0


def una(args):
    alpha, sem, frac_f, J, flujo = args
    m = MundoSplit(alpha, HOR, sem, k=K, mp=15)
    d, tip, llega, ftip = m.corre_split(frac_f=frac_f, J=J, t0=T0, flujo=flujo,
                                        semilla_split=sem)
    c = contabilidad(d, tip, llega, T0, HOR - 60.0)
    c.update(n_f=m.n_f, n_p=m.n_p, n_pub=m.n_pub, n_raf=m.n_raf,
             n_hereda=m.n_hereda, n_freeload=m.n_freeload, n_sp_robado=m.n_sp_robado,
             div_prof=m.div_prof, div_seg=m.div_seg,
             adv_fin=(m.adv_fin if ftip else 0.0),
             adv_max=(m.adv_max if ftip else 0.0))
    return (alpha, frac_f, J, flujo, c)


def med(rs, kk):
    return sum(r[kk] for r in rs) / len(rs)


if __name__ == "__main__":
    tareas = [(a, s, f, J, fl) for a in ALPHAS for f in FRACS for J in JS
              for fl in FLUJOS for s in SEMS]
    print("=== A2 · presupuesto repartido: parasita publicada + flujo privado ===")
    print(f"k={K}, lambda=1, Delta={DELTA}, mp=15, u3=dynamic, horizonte {HOR:.0f} s, "
          f"t0={T0:.0f} s, ventana [{T0:.0f},{HOR-60:.0f}] s, {len(SEMS)} semillas, "
          f"{len(tareas)} corridas.")
    t0 = time.time()
    with Pool(24) as p:
        res = p.map(una, tareas, chunksize=4)
    print(f"[{time.time()-t0:.0f} s de simulacion]\n")

    por = {}
    for a, f, J, fl, c in res:
        por.setdefault((a, f, J, fl), []).append(c)

    dur = (HOR - 60.0) - T0
    print("--- por alpha y reparto: se elige el J que MAXIMIZA la ventaja final del flujo ---")
    print(f"{'alpha':>6} {'a_p':>6} {'a_f':>6} {'flujo':>9} {'J':>4} | {'adv_fin':>8} "
          f"{'adv_max':>8} {'deriva':>8} | {'tasa Wpub':>9} {'1-alpha':>8} {'delta':>7} | "
          f"{'r medido':>8} {'r disj':>7} {'r D8':>7} | {'n_f':>5} {'n_pub':>6} {'raf':>4} "
          f"{'her':>4} {'frl':>4} {'sprob':>6} {'divblk':>6} {'div_s':>7}")
    tabla = {}
    for a in ALPHAS:
        for f in FRACS:
            for fl in FLUJOS:
                cands = []
                for J in JS:
                    rs = por[(a, f, J, fl)]
                    cands.append((J, {kk: med(rs, kk) for kk in rs[0]}))
                J, c = max(cands, key=lambda x: x[1]["adv_fin"])
                ap, af = a * (1 - f), a * f
                tw = c["Wpub"] / dur
                rm = (af / tw) if tw > 0 else float("nan")
                rd = (af / (1 - a)) if a < 1 else float("nan")
                r8 = (a / ((1 - a) * (1 - c["delta"]))) if c["delta"] < 1 else float("nan")
                tabla[(a, f, fl)] = (J, c, tw, rm, rd, r8)
                print(f"{a:>6.2f} {ap:>6.3f} {af:>6.3f} {fl:>9} {J:>4} | "
                      f"{c['adv_fin']:>8.1f} {c['adv_max']:>8.1f} {c['adv_fin']/dur:>8.4f} | "
                      f"{tw:>9.4f} {1-a:>8.4f} {c['delta']:>7.4f} | {rm:>8.3f} {rd:>7.3f} "
                      f"{r8:>7.3f} | {c['n_f']:>5.0f} {c['n_pub']:>6.0f} {c['n_raf']:>4.1f} "
                      f"{c['n_hereda']:>4.0f} {c['n_freeload']:>4.0f} {c['n_sp_robado']:>6.0f} "
                      f"{c['div_prof']:>6.0f} {c['div_seg']:>7.0f}")
        print()

    print("--- CONTROLES ---")
    for a in ALPHAS:
        J, c, tw, rm, rd, r8 = tabla[(a, 1.0, "puro")]
        pred = 2 * a - 1
        if a == 0:
            print(f"  alpha_p=0, flujo puro, alpha=0,00: no hay bloques del atacante "
                  f"(n_f=0): la prediccion 2a-1 no aplica, la fila solo comprueba que "
                  f"adv=0 y que ninguna rama se ejecuta")
            continue
        print(f"  alpha_p=0, flujo puro, alpha={a:.2f}: deriva medida "
              f"{c['adv_fin']/dur:+.4f}  vs  2a-1 = {pred:+.4f}  "
              f"(n_f={c['n_f']:.0f}, n_pub={c['n_pub']:.0f}, div_seg={c['div_seg']:.0f} s)")
    J, c, tw, rm, rd, r8 = tabla[(0.0, 1.0, "puro")]
    print(f"  alpha=0: adv_fin={c['adv_fin']:.1f}, n_f={c['n_f']:.0f}, "
          f"n_pub={c['n_pub']:.0f}, raf={c['n_raf']:.1f}  (debe ser todo 0)")
    J, c, tw, rm, rd, r8 = tabla[(0.55, 1.0, "puro")]
    print(f"  alpha=0,55 alpha_f=0,55>0,5: deriva {c['adv_fin']/dur:+.4f} "
          f"(debe ser > 0: el flujo GANA)")

    print("\n--- la pregunta directa: para cada alpha, que reparto maximiza la deriva? ---")
    print("    SOLO variantes que siguen siendo CADENA COMPETIDORA: div_seg >= 0,5*(horizonte).")
    print("    Las variantes 'hereda'/'parasito' no estrictas pierden el padre seleccionado")
    print("    (columna sprob > 0) y su cadena se FUNDE con la publica (div_seg de 8 a 208 s):")
    print("    su deriva ~0 no es una carrera ganada, es que ya no hay carrera.")
    print(f"{'alpha':>6} | " + " ".join(f"{'a_p/a='+('%.0f%%'%(100*(1-f))):>13}" for f in FRACS))
    for a in ALPHAS:
        if a == 0:
            continue
        fila = []
        for f in FRACS:
            cands = [tabla[(a, f, fl)][1] for fl in FLUJOS
                     if tabla[(a, f, fl)][1]["div_seg"] >= 0.5 * dur]
            if not cands:
                fila.append(f"{'—':>13}")
            else:
                fila.append(f"{max(c['adv_fin'] for c in cands)/dur:>13.4f}")
        print(f"{a:>6.2f} | " + " ".join(fila))

    print("\n--- las mismas celdas SIN filtrar (para que se vea el artefacto) ---")
    print(f"{'alpha':>6} | " + " ".join(f"{'a_p/a='+('%.0f%%'%(100*(1-f))):>13}" for f in FRACS))
    for a in ALPHAS:
        if a == 0:
            continue
        fila = []
        for f in FRACS:
            best = max((tabla[(a, f, fl)][1]["adv_fin"] for fl in FLUJOS))
            fila.append(f"{best/dur:>13.4f}")
        print(f"{a:>6.2f} | " + " ".join(fila))

    print("\n--- Wpub/H por reparto (conservacion): debe ser >= 1 en toda celda ---")
    print(f"{'alpha':>6} | " + " ".join(f"{'a_p/a='+('%.0f%%'%(100*(1-f))):>13}" for f in FRACS))
    for a in ALPHAS:
        fila = []
        for f in FRACS:
            c = tabla[(a, f, "puro")][1]
            fila.append(f"{(c['Wpub']/c['H'] if c['H'] else 1.0):>13.4f}")
        print(f"{a:>6.2f} | " + " ".join(fila))
    print("\nLECTURA: si la deriva es MAXIMA en alpha_p = 0 para todo alpha, parasitar nunca "
          "ayuda al que corre,\ny la base de la carrera es alpha/(1-alpha), no "
          "alpha/((1-alpha)(1-delta)).")
