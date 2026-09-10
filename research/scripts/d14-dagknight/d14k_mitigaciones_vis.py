#!/usr/bin/env python3
r"""
d14k_mitigaciones_vis.py — Punto 2 (D14C) sobre la VISTA REAL del cliente en T:
rejilla completa de mitigaciones (a)-(f) + variantes, una a una y combinadas.

α ∈ {0,25; 0,40}, Δ ∈ {16,20}, estrategias instant / retraso20 (tips) / retraso20_sp /
retraso60_sp, 12 semillas. Para cada regla: captura D8b | captura_ref (congelación)/12.
captura_ref = el ganador atacante ni contiene el tip honesto en su pasado ni lo colorea
azul (censura real). cong = la rama honesta no es aceptable por la regla.
Salida: salida_mitigaciones_vis.txt y salida_mitigaciones_vis_crudo.txt.
"""
import multiprocessing as mp
import os
import sys

_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, _DIR)
sys.path.insert(0, os.path.normpath(os.path.join(_DIR, "..", "d9-ronda8c")))

from d14k_ataque2 import (estrategia, rank_por_grupo, _evalua_regla,  # noqa: E402
                          REGLAS, kdag_visible, llega_por_bloque)

ALPHAS = [0.25, 0.40]
DELTAS = [16.0, 20.0]
SEMILLAS = [11, 23, 37, 41, 59, 67, 73, 89, 97, 101, 113, 127]
ESTRATEGIAS = ["instant", "retraso20", "retraso20_sp", "retraso60_sp"]
T = 400.0


def _tarea(args):
    alpha, delta, seed, nombre = args
    import r8c_sim
    from r8c_sim import Mundo
    from d14k_lib import kdag_from_r8c

    r8c_sim.LAMBDA = 1.0
    r8c_sim.DELTA = delta
    m = Mundo(alpha=alpha, T=T, seed=seed)
    est = estrategia(m, nombre)
    d, _ = m.corre(estrategia=est)
    kd_full, idx = kdag_from_r8c(d)
    kd = kdag_visible(kd_full, llega_por_bloque(d, idx, m, est, delta), T)
    tips = [i for i in range(kd.n) if not (kd.future[i] & kd.full)]
    import d14k_ref as R
    bw = R.global_blue_work(kd)
    Hmask = sum(1 << i for i in range(kd.n) if kd.creators[i] == "h")
    h_tips = [t for t in tips if (Hmask >> t) & 1]
    Htip = max(h_tips, key=lambda i: (bw[i], -i)) if h_tips else None
    kv, grupos, cg = rank_por_grupo(kd, tips, bw, htip=Htip)
    for g in grupos:
        en_pasado = Htip is not None and bool((kd.past[g["vsp"]] >> Htip) & 1)
        g["_cubre_htip"] = en_pasado
        g["_incluye_htip"] = bool(en_pasado or (g["htip_azul"] and Htip is not None))
    fila = dict(alpha=alpha, delta=delta, seed=seed, estrategia=nombre, n=kd.n)
    for nombre_regla, campo, kcap, exige in REGLAS:
        _, _, cap, capb, congel, khon = _evalua_regla(kd, grupos, kv, cg, Htip,
                                                      campo, kcap, exige)
        fila[f"cap_{nombre_regla}"] = cap
        fila[f"capb_{nombre_regla}"] = capb
        fila[f"cong_{nombre_regla}"] = congel
        fila[f"khon_{nombre_regla}"] = khon
    return fila


def main():
    tareas = [(a, dd, s, e) for a in ALPHAS for dd in DELTAS for s in SEMILLAS
              for e in ESTRATEGIAS]
    with mp.Pool(processes=min(16, os.cpu_count() or 4)) as pool:
        res = pool.map(_tarea, tareas, chunksize=1)

    with open(os.path.join(_DIR, "salida_mitigaciones_vis_crudo.txt"), "w") as f:
        f.write("alpha delta seed estrategia n " +
                " ".join(f"cap_{r} capb_{r} cong_{r} khon_{r}" for r, _, _, _ in REGLAS)
                + "\n")
        for r in res:
            f.write(f"{r['alpha']} {r['delta']} {r['seed']} {r['estrategia']} {r['n']} ")
            for nombre, _, _, _ in REGLAS:
                f.write(f"{r['cap_'+nombre]} {r['capb_'+nombre]} "
                        f"{r['cong_'+nombre]} {r['khon_'+nombre]} ")
            f.write("\n")

    lineas = []

    def p(s=""):
        lineas.append(s)

    p("=" * 128)
    p("MITIGACIONES SOBRE LA VISTA REAL DEL CLIENTE (entrega <= T) — 12 semillas")
    p("celda = captura D8b | captura_ref (congelación). captura_ref = censura real.")
    p("=" * 128)
    for a in ALPHAS:
        for dd in DELTAS:
            p()
            p(f"α={a:.2f} Δ={dd:.0f}")
            p(f"{'regla':>16} | " + " | ".join(f"{e:>19}" for e in ESTRATEGIAS))
            for nombre, _, _, _ in REGLAS:
                celdas = []
                for e in ESTRATEGIAS:
                    filas = [r for r in res if r["alpha"] == a and r["delta"] == dd
                             and r["estrategia"] == e]
                    cap = sum(r["cap_" + nombre] for r in filas)
                    capb = sum(r["capb_" + nombre] for r in filas)
                    cong = sum(r["cong_" + nombre] for r in filas)
                    celdas.append(f"{cap:>4}|{capb:>4} ({cong:>2})")
                p(f"{nombre:>16} | " + " | ".join(celdas))
    texto = "\n".join(lineas)
    print(texto)
    with open(os.path.join(_DIR, "salida_mitigaciones_vis.txt"), "w") as f:
        f.write(texto + "\n")


if __name__ == "__main__":
    main()
