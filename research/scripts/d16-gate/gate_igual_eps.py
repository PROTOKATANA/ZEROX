#!/usr/bin/env python3
"""
gate_igual_eps.py — Gate de igual ε para A (confirmación adaptativa sobre el DAG).

Pregunta: ¿la regla adaptativa baja la latencia del baseline A IGUAL RIESGO ε?

Modelo: el del proyecto, `prev()` de research/scripts/d9-ronda9a/r9a_a3_frontera.py:37-49
(carrera de Skellam con ventaja inicial `offset` en bloques). Se compara, a la MISMA eps:

  baseline   P: prev(alpha, 1, t, 3*30, 1) = eps      -> t_base
  adaptativa P: prev(alpha, 1, t, 3*k_ref, 1) = eps   -> t_adapt   (mismo modelo, offset menor)
  adaptativa G: M = max(3*k_ref, ceil(ln eps / ln(alpha/(1-alpha)))); t = M/((1-alpha))

`k_ref` medido en research/scripts/d14-dagknight/salida_zerox2_crudo.txt (rank fiel sobre la
vista visible; D8b demostró que la retención infla el offset real y captura 12/12 a Δ≥16).

Criterio de muerte (2026-09-10): si t_base/t_adapt < 2 a eps=1e-6 o < 1,5 a 1e-12, A no
compra nada. Control positivo antes de medir: reproducir los números publicados.
"""
import math
import os
import statistics as st
import sys

import numpy as np
from scipy.stats import skellam

_DIR = os.path.dirname(os.path.abspath(__file__))
_R9A = os.path.normpath(os.path.join(_DIR, "..", "d9-ronda9a"))
_D14K = os.path.join(_DIR, "..", "d14-dagknight")
sys.path.insert(0, _R9A)
from r9a_a3_frontera import prev as prev_original  # noqa: E402

ALPHAS = [0.10, 0.25, 0.33, 0.40]
EPSILONS = [0.05, 1e-3, 1e-6, 1e-12]
K_BASE = 30
DS = np.arange(-400, 6001, dtype=float)
T_GRID = np.unique(np.concatenate([np.linspace(1, 200, 200), np.linspace(200, 5000, 300)]))


def carga_kref():
    ruta = os.path.join(_D14K, "salida_zerox2_crudo.txt")
    g = {}
    for linea in open(ruta):
        if linea.startswith("alpha"):
            continue
        c = linea.split()
        g.setdefault(float(c[0]), []).append((float(c[1]), int(c[3])))
    return {
        a: {
            "media": st.mean(k for _, k in f),
            "max": max(k for _, k in f),
            "delta4": st.mean(k for d, k in f if d == 4.0),
            "delta20": st.mean(k for d, k in f if d == 20.0),
        }
        for a, f in g.items()
    }


def tabla_prev(alpha, offsets):
    """prev(alpha,1,t,offset,1) para cada t de T_GRID y cada offset, vectorizado.

    La pmf de Skellam depende de (alpha,t) y se reutiliza para todos los offsets.
    """
    mh = (1 - alpha) * T_GRID          # (T,)
    ma = alpha * T_GRID
    pmf = skellam.pmf(DS[:, None], mh[None, :], ma[None, :])   # (DS, T)
    r = alpha / (1 - alpha)
    tablas = {}
    for off in offsets:
        d = DS - off
        with np.errstate(over="ignore"):
            catch = np.where(d >= 0, np.power(r, np.minimum(d + 1.0, 700)), 1.0)
        tablas[off] = pmf.T @ catch       # (T,)
    return tablas


def cruce(t_grid, vals, eps):
    """Primer t con vals <= eps, por interpolación en log10. vals decreciente."""
    lv = np.log10(np.clip(vals, 1e-320, 1.0))
    le = math.log10(eps)
    idx = np.where(lv <= le)[0]
    if len(idx) == 0:
        return float("inf")
    i = idx[0]
    if i == 0:
        return float(t_grid[0])
    t0, t1 = t_grid[i - 1], t_grid[i]
    v0, v1 = lv[i - 1], lv[i]
    if v0 == v1:
        return float(t1)
    w = (le - v0) / (v1 - v0)
    return float(t0 + w * (t1 - t0))


def m_paseo(alpha, eps):
    if alpha <= 0:
        return 0
    return int(math.ceil(math.log(eps) / math.log(alpha / (1 - alpha))))


def main():
    kref = carga_kref()
    lineas = []
    p = lambda s="": lineas.append(s)  # noqa: E731

    p("=" * 100)
    p("CONTROL POSITIVO — instrumento original prev() vs versión vectorizada")
    p("=" * 100)
    for (a, t, off, esperado, nombre) in [
        (0.33, 871, 90, 1e-12, "D.6: 871 s a 1e-12"),
        (0.33, 1800, 90, 7.1e-36, "hoja: 1800 s a 7,1e-36"),
        (0.33, 600, 90, 1.516e-06, "600 s a alpha=0,33"),
    ]:
        v_orig = prev_original(a, 1.0, t, off, 1.0)
        p(f"  {nombre}: original {v_orig:.3e} vs publicado {esperado:.1e} "
          f"(razón {v_orig/esperado:.3f})")
    p("  (el 4,3e-10 de la hoja a 600 s corresponde a alpha=0,30: "
      f"{prev_original(0.30,1.0,600,90,1.0):.2e}; la fila de la hoja no fija alpha.)")

    p()
    p("=" * 100)
    p("TABLA DEL GATE — misma eps en todas las columnas")
    p("=" * 100)
    cab = f"{'alpha':>5} {'eps':>7} | {'baseline P':>11} {'adapt P med':>11} {'adapt P max':>11} " \
          f"{'adapt G':>9} | {'ratio P':>8} {'ratio G':>8}"
    p(cab)
    p("-" * len(cab))

    filas = []
    for a in ALPHAS:
        kr = kref.get(a, {"media": 0.0, "max": 0, "delta4": 0.0, "delta20": 0.0})
        offs = sorted({3 * K_BASE, 3 * kr["media"], 3 * kr["max"]})
        tablas = tabla_prev(a, offs)
        for eps in EPSILONS:
            t_base = cruce(T_GRID, tablas[3 * K_BASE], eps)
            t_am = cruce(T_GRID, tablas[3 * kr["media"]], eps)
            t_ax = cruce(T_GRID, tablas[3 * kr["max"]], eps)
            M = max(3 * kr["media"], m_paseo(a, eps))
            t_g = M / ((1 - a) * 1.0)
            r_p = t_base / t_am if t_am > 0 else float("inf")
            r_g = t_base / t_g if t_g > 0 else float("inf")
            filas.append((a, eps, t_base, t_am, t_ax, t_g, r_p, r_g))
            p(f"{a:>5.2f} {eps:>7.0e} | {t_base:>11.1f} {t_am:>11.1f} {t_ax:>11.1f} | "
              f"{t_g:>9.1f} | {r_p:>8.2f} {r_g:>8.2f}")

    p()
    p("k_ref usado (salida_zerox2_crudo.txt):")
    for a in ALPHAS:
        kr = kref[a]
        p(f"  alpha={a:.2f}: media={kr['media']:.2f} max={kr['max']} "
          f"(delta=4: {kr['delta4']:.2f}; delta=20: {kr['delta20']:.2f})")

    p()
    p("=" * 100)
    p("CRITERIO DE MUERTE")
    p("=" * 100)
    peor_1e6 = min(r[6] for r in filas if r[1] == 1e-6)
    peor_1e12 = min(r[6] for r in filas if r[1] == 1e-12)
    ok_1e6, ok_1e12 = peor_1e6 >= 2.0, peor_1e12 >= 1.5
    p(f"  ratio P mínimo a 1e-6: {peor_1e6:.2f}  -> {'PASA' if ok_1e6 else 'NO PASA'} (>=2)")
    p(f"  ratio P mínimo a 1e-12: {peor_1e12:.2f} -> {'PASA' if ok_1e12 else 'NO PASA'} (>=1,5)")
    p("  Aritmética: " + ("PASA" if (ok_1e6 and ok_1e12) else "NO PASA"))

    p()
    p("=" * 100)
    p("CONDICIÓN DE SEGURIDAD (lo que la aritmética NO decide)")
    p("=" * 100)
    p("  Reducir el offset de 3k=90 a 3*k_ref solo es legítimo si k_ref captura la cadena")
    p("  oculta del atacante. D8b demostró que NO: con retención + cadena privada captura")
    p("  12/12 a Δ=16 (informe3, audita-d8c). A Δ<=4 la manipulación es débil.")
    p("  El gate PASA CONDICIONADO a: (a) cerrar el ataque de retención; (b) medir Δ y que")
    p("  su percentil normativo quede donde k_ref es seguro. Si Δ>=16 y el ataque sigue")
    p("  abierto, el offset vuelve a ~3k y A no compra nada.")

    with open(os.path.join(_DIR, "salida_gate.txt"), "w") as f:
        f.write("\n".join(lineas) + "\n")
    print("\n".join(lineas))


if __name__ == "__main__":
    main()
