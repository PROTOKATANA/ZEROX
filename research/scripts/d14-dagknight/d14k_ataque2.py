#!/usr/bin/env python3
r"""
d14k_ataque2.py — Punto 2 (D14C): cerrar el ataque de retención + cadena privada.

Ataque (D8b, audita-d8b): el atacante ve todo al instante y publica con retraso R > Δ
una cadena de un solo padre (`sp`), de modo que los honestos de la ventana de retención
quedan fuera de su pasado. El subgrupo del atacante pasa la UMC con k bajo (sus rojos
son grises para él) mientras el subgrupo del tip honesto acumula esos bloques como rojos.

Medidas por (α, Δ, semilla, estrategia):
  · M0 fiel        : rank puro + tie-breaking (línea base del ataque).
  · M1 capK        : solo aceptar el subgrupo si k ≤ K (K=4/8/16).
  · M2 cadena      : exigir que el clúster aceptado cubra la cadena GHOSTDAG global
                     (todos los ancestros de cadena de todos los tips); k efectivo = k_cadena.
  · M3 cierre      : exigir cierre de ancestros en la zona (sin huecos); k efectivo = k_cierre.
  · M4 mayoría     : exigir clúster ≥50 % honesto (ORÁCULO); k efectivo = k_mayor.
  · M5 rank honesto: exigir que el subgrupo del tip honesto pase la UMC (ORÁCULO);
                     si no, el cliente no confirma (congelación).
  · R1 mi tip      : exigir que el pasado del VSP ganador contenga el tip honesto
                     (implementable por un cliente que conoce sus propios bloques).
  · Combinaciones  : M2∧M3, M2∧M4, M2∧M5, M3∧M4, R1∧M4, R1∧M5, M2∧M3∧M4, cap8∧M5.

captura = el ganador de la regla es de creador atacante y el tip honesto NO está en su
pasado. congelación = la rama del tip honesto no es aceptable por la regla (no confirma).

Salidas: salida_ataque2.txt y salida_ataque2_crudo.txt.
"""
import math
import multiprocessing as mp
import os
import statistics as st
import sys

_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, _DIR)
sys.path.insert(0, os.path.normpath(os.path.join(_DIR, "..", "d9-ronda8c")))

ALPHAS = [0.25, 0.40]
DELTAS = [16.0, 20.0]
SEMILLAS = [11, 23, 37, 41, 59, 67, 73, 89, 97, 101, 113, 127]
ESTRATEGIAS = ["instant", "retraso20", "retraso20_sp", "retraso60_sp"]
T = 400.0
KMAX = 40
CAPS = [4, 8, 16]
EPS = 1e-6


def estrategia(m, nombre):
    at = [(i, e) for i, e in enumerate(m.ev) if e[1] == "a"]
    if nombre == "instant":
        return {}
    if nombre == "retraso20":
        return {i: (20.0, "tips") for i, _ in at}
    if nombre == "retraso20_sp":
        return {i: (20.0, "sp") for i, _ in at}
    if nombre == "retraso60_sp":
        return {i: (60.0, "sp") for i, _ in at}
    raise ValueError(nombre)


def margen_paseo(alpha, eps):
    if alpha <= 0 or alpha >= 1:
        return 0
    return int(math.ceil(math.log(eps) / math.log(alpha / (1 - alpha))))


def llega_por_bloque(d, idx, m, estrategia_dict, delta):
    """Tiempo de primera entrega de cada bloque: honesto t+Δ, atacante t+retraso."""
    llega = [0.0] * len(idx)
    for bid, i in idx.items():
        if bid == "G":
            continue
        j = int(bid[1:])
        t, quien = m.ev[j][0], m.ev[j][1]
        if quien == "h":
            llega[i] = t + delta
        else:
            retraso, _ = estrategia_dict.get(j, (0.0, "tips"))
            llega[i] = t + retraso
    return llega


def kdag_visible(kd_full, llega, t_max):
    """Sub-DAG de los bloques recibidos en t_max, cerrado bajo ancestros: un bloque solo
    se puede validar si sus padres ya llegaron (recv = max(llega propia, recv de padres)).
    Corrige el artefacto de 'vista final' que incluye bloques aún no publicados."""
    from d14k_lib import KDag
    recv = [0.0] * kd_full.n
    for i in range(kd_full.n):
        r = llega[i]
        for p in kd_full.parents[i]:
            if recv[p] > r:
                r = recv[p]
        recv[i] = r
    vis = [i for i in range(kd_full.n) if recv[i] <= t_max]
    remap = {old: new for new, old in enumerate(vis)}
    parents = [tuple(remap[p] for p in kd_full.parents[i]) for i in vis]
    times = [kd_full.times[i] for i in vis]
    creators = [kd_full.creators[i] for i in vis]
    kd = KDag(parents, times, creators)
    cp = [None if kd_full.chain_parent[i] is None else remap[kd_full.chain_parent[i]]
          for i in vis]
    kd.set_chain(cp)
    return kd


def rank_por_grupo(kd, tips, bw, kmax=KMAX, htip=None):
    """Rank fiel por subgrupo + métricas de mitigación. Réplica de `_rank_grupos`
    (audita-d8b/audita1_grupos.py), ampliada con k_cadena/k_cadena_hon/k_cierre/k_mayor."""
    import d14k_ref as R
    from d14k_lib import popcount

    if not tips:
        return 0, [], 0
    if len(tips) == 1:
        cg = 0
    else:
        cg = tips[0]
        for t in tips[1:]:
            cg = kd.chain_lca(cg, t)
    groups = {}
    for t in tips:
        nca = R.next_after(kd, t, cg)
        groups.setdefault(nca, []).append(t)

    chain = set()
    for t in tips:
        cur = t
        while cur is not None:
            chain.add(cur)
            cur = kd.chain_parent[cur]

    cadena_hon = set()
    if htip is not None:
        cur = htip
        while cur is not None:
            cadena_hon.add(cur)
            if cur == cg:
                break
            cur = kd.chain_parent[cur]

    Hmask = 0
    for i in range(kd.n):
        if kd.creators[i] == "h":
            Hmask |= 1 << i

    out = []
    for nca, gts in groups.items():
        vsp = max(gts, key=lambda t: (bw[t], -t))
        zone = R.zone_of(kd, gts, nca)
        rec = dict(nca=nca, tips=gts, vsp=vsp, zone=zone, k=None, score=None,
                   blues=[], reds=[], k_cadena=None, k_cadena_hon=None,
                   k_cierre=None, k_mayor=None, k_htip=None,
                   falta_cadena=None, falta_cadena_hon=None, huecos=None,
                   hon_frac=float("nan"), cubre_cadena=None, cubre_cadena_hon=None,
                   cerrado=None, mayoria=None, htip_azul=None)
        for k in range(kmax + 1):
            zd, z = R.committed_coloring(kd, gts, nca, cg, k)
            vnd = R.virtual_coloring(kd, zd, tips, vsp, cg, k, bw)
            ok, score, blues, reds = R.umc_voting(kd, zd, cg, nca, vnd, k, bw)
            bmask = 0
            for b in blues:
                bmask |= 1 << b
            falta = [c for c in chain if c != 0 and not ((bmask >> c) & 1)]
            falta_h = [c for c in cadena_hon if c != 0 and not ((bmask >> c) & 1)]
            huecos = 0
            for b in blues:
                for p in kd.parents[b]:
                    if ((z >> p) & 1) and not ((bmask >> p) & 1):
                        huecos += 1
            hon = popcount(bmask & Hmask) / max(1, popcount(bmask))
            if ok and rec["k"] is None:
                rec.update(k=k, score=score, blues=blues, reds=reds,
                           falta_cadena=len(falta), falta_cadena_hon=len(falta_h),
                           huecos=huecos, hon_frac=hon,
                           cubre_cadena=(len(falta) == 0),
                           cubre_cadena_hon=(len(falta_h) == 0),
                           cerrado=(huecos == 0), mayoria=(hon >= 0.5),
                           htip_azul=(htip is not None and ((bmask >> htip) & 1)))
            if rec["k"] is not None:
                if rec["k_cadena"] is None and len(falta) == 0:
                    rec["k_cadena"] = k
                if rec["k_cadena_hon"] is None and len(falta_h) == 0:
                    rec["k_cadena_hon"] = k
                if rec["k_cierre"] is None and huecos == 0:
                    rec["k_cierre"] = k
                if rec["k_mayor"] is None and hon >= 0.5:
                    rec["k_mayor"] = k
                if rec["k_htip"] is None and htip is not None and ((bmask >> htip) & 1):
                    rec["k_htip"] = k
                if (rec["k_cadena"] is not None and rec["k_cadena_hon"] is not None
                        and rec["k_cierre"] is not None and rec["k_mayor"] is not None
                        and (htip is None or rec["k_htip"] is not None)):
                    break
        out.append(rec)
    kv = min((g["k"] for g in out if g["k"] is not None), default=None)
    return kv, out, cg


def tie_break_fiel(kd, winners, k, cg):
    """Tie-breaking Alg. 4 (audita-d8b/audita1_grupos.py:111-129)."""
    from d14k_lib import KColouring, VirtualColouring, popcount, iter_bits
    if len(winners) == 1:
        return winners[0]
    F, _ = VirtualColouring(kd).cluster_virtual(max(0, math.isqrt(k)), True, kd.full)
    kc = KColouring(kd)
    mejor = None
    for w in winners:
        vsp, zone = w["vsp"], w["zone"]
        C = 0
        for kp in range(k // 2, k + 1):
            _, ch = kc.cluster(vsp, kp, False, kd.past[vsp] & zone, cg)
            cnt = sum(1 for B in iter_bits(F) if popcount(kd.anticone(B, kd.full) & ch) > kp)
            if cnt > C:
                C = cnt
        clave = (C, vsp)
        if mejor is None or clave < mejor[0]:
            mejor = (clave, w)
    return mejor[1]


def _candidatos(grupos, campo, k_efectivo=None):
    """Subgrupos aceptables por la regla: campo no-None. Devuelve [(k_ef, g)]."""
    res = []
    for g in grupos:
        if campo == "k":
            if g["k"] is not None:
                res.append((g["k"], g))
        elif campo == "cap":
            if g["k"] is not None and g["k"] <= k_efectivo:
                res.append((g["k"], g))
        elif campo == "cadena":
            if g["k_cadena"] is not None:
                res.append((g["k_cadena"], g))
        elif campo == "cadena_hon":
            if g["k_cadena_hon"] is not None:
                res.append((g["k_cadena_hon"], g))
        elif campo == "cadena_hon_cierre":
            if g["k_cadena_hon"] is not None and g["k_cierre"] is not None:
                res.append((max(g["k_cadena_hon"], g["k_cierre"]), g))
        elif campo == "cadena_hon_mayoria":
            if g["k_cadena_hon"] is not None and g["k_mayor"] is not None:
                res.append((max(g["k_cadena_hon"], g["k_mayor"]), g))
        elif campo == "cadena_hon_cierre_mayoria":
            if (g["k_cadena_hon"] is not None and g["k_cierre"] is not None
                    and g["k_mayor"] is not None):
                res.append((max(g["k_cadena_hon"], g["k_cierre"], g["k_mayor"]), g))
        elif campo == "cierre":
            if g["k_cierre"] is not None:
                res.append((g["k_cierre"], g))
        elif campo == "mayoria":
            if g["k_mayor"] is not None:
                res.append((g["k_mayor"], g))
        elif campo == "mi_tip":
            if g["k"] is not None and g["_cubre_htip"]:
                res.append((g["k"], g))
        elif campo == "cluster_tip":
            if g["k"] is not None and g["_incluye_htip"]:
                res.append((g["k"], g))
        elif campo == "cluster_tip_mayoria":
            if g["k"] is not None and g["_incluye_htip"] and g["k_mayor"] is not None:
                res.append((max(g["k"], g["k_mayor"]), g))
        elif campo == "cadena_cierre":
            if g["k_cadena"] is not None and g["k_cierre"] is not None:
                res.append((max(g["k_cadena"], g["k_cierre"]), g))
        elif campo == "cadena_mayoria":
            if g["k_cadena"] is not None and g["k_mayor"] is not None:
                res.append((max(g["k_cadena"], g["k_mayor"]), g))
        elif campo == "cadena_mi_tip":
            if g["k_cadena"] is not None and g["_cubre_htip"]:
                res.append((g["k_cadena"], g))
        elif campo == "cierre_mayoria":
            if g["k_cierre"] is not None and g["k_mayor"] is not None:
                res.append((max(g["k_cierre"], g["k_mayor"]), g))
        elif campo == "mi_tip_mayoria":
            if g["k"] is not None and g["_cubre_htip"] and g["k_mayor"] is not None:
                res.append((max(g["k"], g["k_mayor"]), g))
        elif campo == "cadena_cierre_mayoria":
            if (g["k_cadena"] is not None and g["k_cierre"] is not None
                    and g["k_mayor"] is not None):
                res.append((max(g["k_cadena"], g["k_cierre"], g["k_mayor"]), g))
        elif campo == "cap_mayoria":
            if (g["k"] is not None and g["k"] <= k_efectivo and g["k_mayor"] is not None):
                res.append((max(g["k"], g["k_mayor"]), g))
        else:
            raise ValueError(campo)
    return res


def _evalua_regla(kd, grupos, kv, cg, Htip, campo, k_efectivo=None, exige_hon_rank=False):
    """Aplica una regla. Devuelve (ganador, k_efectivo, captura, captura_ref, congelado, k_hon).
    captura = ganador atacante y tip honesto fuera de su pasado (métrica D8b).
    captura_ref = además el tip honesto no está entre los azules del ganador (censura real).
    k_hon = k efectivo del subgrupo del tip honesto (None si no aceptable/congelado)."""
    grupo_hon = next((g for g in grupos if Htip in g["tips"]), None) \
        if Htip is not None else None
    if exige_hon_rank and (grupo_hon is None or grupo_hon["k"] is None):
        return None, None, 0, 0, 1, None
    cands = _candidatos(grupos, campo, k_efectivo)
    if not cands:
        return None, None, 0, 0, 1, None
    kmin = min(k for k, _ in cands)
    wins = [g for k, g in cands if k == kmin]
    gsel = tie_break_fiel(kd, wins, kmin, cg)
    gan_is_att = int(kd.creators[gsel["vsp"]] == "a")
    captura = captura_ref = 0
    if gan_is_att and Htip is not None:
        en_pasado = (kd.past[gsel["vsp"]] >> Htip) & 1
        k_azul = gsel["k_htip"]
        en_azules = k_azul is not None and k_azul <= kmin
        captura = int(not en_pasado)
        captura_ref = int(not en_pasado and not en_azules)
    k_hon = None
    if grupo_hon is not None:
        k_hon = _k_efectivo_de(grupo_hon, campo, k_efectivo)
    return gsel, kmin, captura, captura_ref, 0, k_hon


def _k_efectivo_de(g, campo, k_efectivo):
    if campo == "k":
        return g["k"]
    if campo == "mi_tip":
        return g["k"] if g["_cubre_htip"] else None
    if campo == "cluster_tip":
        return g["k"] if g["_incluye_htip"] else None
    if campo == "cluster_tip_mayoria":
        return (max(g["k"], g["k_mayor"])
                if g["k"] is not None and g["_incluye_htip"] and g["k_mayor"] is not None
                else None)
    if campo == "cap":
        return g["k"] if (g["k"] is not None and g["k"] <= k_efectivo) else None
    if campo == "cadena":
        return g["k_cadena"]
    if campo == "cadena_hon":
        return g["k_cadena_hon"]
    if campo == "cadena_hon_cierre":
        return (max(g["k_cadena_hon"], g["k_cierre"])
                if g["k_cadena_hon"] is not None and g["k_cierre"] is not None else None)
    if campo == "cadena_hon_mayoria":
        return (max(g["k_cadena_hon"], g["k_mayor"])
                if g["k_cadena_hon"] is not None and g["k_mayor"] is not None else None)
    if campo == "cadena_hon_cierre_mayoria":
        if (g["k_cadena_hon"] is not None and g["k_cierre"] is not None
                and g["k_mayor"] is not None):
            return max(g["k_cadena_hon"], g["k_cierre"], g["k_mayor"])
        return None
    if campo == "cierre":
        return g["k_cierre"]
    if campo == "mayoria":
        return g["k_mayor"]
    if campo == "cadena_cierre":
        return (max(g["k_cadena"], g["k_cierre"])
                if g["k_cadena"] is not None and g["k_cierre"] is not None else None)
    if campo == "cadena_mayoria":
        return (max(g["k_cadena"], g["k_mayor"])
                if g["k_cadena"] is not None and g["k_mayor"] is not None else None)
    if campo == "cadena_mi_tip":
        return g["k_cadena"] if (g["k_cadena"] is not None and g["_cubre_htip"]) else None
    if campo == "cierre_mayoria":
        return (max(g["k_cierre"], g["k_mayor"])
                if g["k_cierre"] is not None and g["k_mayor"] is not None else None)
    if campo == "mi_tip_mayoria":
        return (max(g["k"], g["k_mayor"])
                if g["k"] is not None and g["_cubre_htip"] and g["k_mayor"] is not None else None)
    if campo == "cadena_cierre_mayoria":
        if (g["k_cadena"] is not None and g["k_cierre"] is not None
                and g["k_mayor"] is not None):
            return max(g["k_cadena"], g["k_cierre"], g["k_mayor"])
        return None
    if campo == "cap_mayoria":
        if g["k"] is not None and g["k"] <= k_efectivo and g["k_mayor"] is not None:
            return max(g["k"], g["k_mayor"])
        return None
    raise ValueError(campo)


REGLAS = [
    ("M0_fiel", "k", None, False),
    ("M1_cap4", "cap", 4, False),
    ("M1_cap8", "cap", 8, False),
    ("M1_cap16", "cap", 16, False),
    ("M2_cadena", "cadena", None, False),
    ("M2h_cad_hon", "cadena_hon", None, False),
    ("M3_cierre", "cierre", None, False),
    ("M4_mayoria", "mayoria", None, False),
    ("M5_rank_hon", "k", None, True),
    ("R1_mi_tip", "mi_tip", None, False),
    ("R1b_cluster", "cluster_tip", None, False),
    ("R1bM4", "cluster_tip_mayoria", None, False),
    ("M2M3", "cadena_cierre", None, False),
    ("M2M4", "cadena_mayoria", None, False),
    ("M2hM3", "cadena_hon_cierre", None, False),
    ("M2hM4", "cadena_hon_mayoria", None, False),
    ("M2hM3M4", "cadena_hon_cierre_mayoria", None, False),
    ("M3M4", "cierre_mayoria", None, False),
    ("R1M4", "mi_tip_mayoria", None, False),
    ("M2M3M4", "cadena_cierre_mayoria", None, False),
    ("cap8_M4", "cap_mayoria", 8, False),
]


def _tarea(args):
    alpha, delta, seed, nombre = args
    import r8c_sim
    from r8c_sim import Mundo
    from d14k_lib import kdag_from_r8c, popcount

    r8c_sim.LAMBDA = 1.0
    r8c_sim.DELTA = delta
    m = Mundo(alpha=alpha, T=T, seed=seed)
    d, _ = m.corre(estrategia=estrategia(m, nombre))
    kd, _ = kdag_from_r8c(d)
    tips = list(range(kd.n))
    tips = [i for i in tips if not (kd.future[i] & kd.full)]
    import d14k_ref as R
    bw = R.global_blue_work(kd)
    Hmask = 0
    for i in range(kd.n):
        if kd.creators[i] == "h":
            Hmask |= 1 << i
    h_tips = [t for t in tips if (Hmask >> t) & 1]
    Htip = max(h_tips, key=lambda i: (bw[i], -i)) if h_tips else None
    kv, grupos, cg = rank_por_grupo(kd, tips, bw, htip=Htip)
    for g in grupos:
        en_pasado = (Htip is not None and ((kd.past[g["vsp"]] >> Htip) & 1))
        g["_cubre_htip"] = bool(en_pasado)
        g["_incluye_htip"] = bool(en_pasado or g["htip_azul"])

    fila = dict(alpha=alpha, delta=delta, seed=seed, estrategia=nombre, n=kd.n,
                tips=len(tips), grupos=len(grupos), kv=kv,
                k_hon_tip=next((g["k"] for g in grupos if Htip in g["tips"]), None)
                if Htip is not None else None)
    for nombre_regla, campo, kcap, exige in REGLAS:
        _, k_ef, cap, capb, congel, k_hon = _evalua_regla(kd, grupos, kv, cg, Htip,
                                                          campo, kcap, exige)
        fila[f"cap_{nombre_regla}"] = cap
        fila[f"capb_{nombre_regla}"] = capb
        fila[f"cong_{nombre_regla}"] = congel
        fila[f"khon_{nombre_regla}"] = k_hon
    fila["k_att_tip"] = next((g["k"] for g in grupos
                              if g["vsp"] is not None and kd.creators[g["vsp"]] == "a"
                              and Htip not in g["tips"]), None)
    return fila


def main():
    tareas = [(a, dd, s, e) for a in ALPHAS for dd in DELTAS for s in SEMILLAS
              for e in ESTRATEGIAS]
    with mp.Pool(processes=min(16, os.cpu_count() or 4)) as pool:
        res = pool.map(_tarea, tareas, chunksize=1)

    with open(os.path.join(_DIR, "salida_ataque2_crudo.txt"), "w") as f:
        f.write("alpha delta seed estrategia n tips grupos kv k_hon_tip k_att_tip " +
                " ".join(f"cap_{r} capb_{r} cong_{r} khon_{r}" for r, _, _, _ in REGLAS)
                + "\n")
        for r in res:
            f.write(f"{r['alpha']} {r['delta']} {r['seed']} {r['estrategia']} {r['n']} "
                    f"{r['tips']} {r['grupos']} {r['kv']} {r['k_hon_tip']} {r['k_att_tip']} ")
            for nombre, _, _, _ in REGLAS:
                f.write(f"{r['cap_'+nombre]} {r['capb_'+nombre]} "
                        f"{r['cong_'+nombre]} {r['khon_'+nombre]} ")
            f.write("\n")

    lineas = []

    def p(s=""):
        lineas.append(s)

    p("=" * 128)
    p("ATAQUE 2 — retención + cadena privada (sp con retraso). Regla FIEL vs mitigaciones.")
    p("captura = ganador atacante y tip honesto fuera de su pasado; cong = rama honesta no")
    p("aceptable por la regla (no confirma). 12 semillas por celda. Δ=16/20 s, α=0,25/0,40.")
    p("=" * 128)

    for a in ALPHAS:
        for dd in DELTAS:
            p()
            p(f"α={a:.2f} Δ={dd:.0f} — captura D8b | captura_ref (cong)/12 por estrategia y regla")
            p("captura_ref = el ganador atacante ni contiene el tip honesto en su pasado ni lo")
            p("colorea azul (censura real). cong = la rama honesta no es aceptable por la regla.")
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
    p()
    p("=" * 128)
    p("k efectivo del subgrupo del tip honesto (media[mín,máx] sobre 12 semillas; None = congelación)")
    p("=" * 128)
    for a in ALPHAS:
        for dd in DELTAS:
            p()
            p(f"α={a:.2f} Δ={dd:.0f}")
            p(f"{'regla':>16} | " + " | ".join(f"{e:>17}" for e in ESTRATEGIAS))
            for nombre, _, _, _ in REGLAS:
                celdas = []
                for e in ESTRATEGIAS:
                    filas = [r for r in res if r["alpha"] == a and r["delta"] == dd
                             and r["estrategia"] == e]
                    v = [r["khon_" + nombre] for r in filas
                         if r["khon_" + nombre] is not None]
                    if v:
                        celdas.append(f"{st.mean(v):>5.1f}[{min(v)},{max(v)}]")
                    else:
                        celdas.append(f"{'--':>17}")
                p(f"{nombre:>16} | " + " | ".join(celdas))

    p()
    p("=" * 128)
    p("SUELO de latencia 3·k/((1−α)λ) del k efectivo del subgrupo del tip honesto, ε=1e-6")
    p("(m(α,ε) para α=0,25/0,40 = 30/11) — media sobre 12 semillas, Δ=16/20")
    p("=" * 128)
    for a in ALPHAS:
        m_eps = margen_paseo(a, EPS)
        base = 3 * 30 / ((1 - a) * 1.0)
        p(f"\nα={a:.2f}: baseline k=30 -> {base:.1f} s; m(α,1e-6)={m_eps}")
        p(f"{'regla':>16} | " + " | ".join(f"{e:>17}" for e in ESTRATEGIAS))
        for nombre, _, _, _ in REGLAS:
            celdas = []
            for e in ESTRATEGIAS:
                filas = [r for r in res if r["alpha"] == a and r["estrategia"] == e]
                suelos = []
                for r in filas:
                    kh = r["khon_" + nombre]
                    if kh is not None:
                        suelos.append(max(3 * kh, m_eps) / ((1 - a) * 1.0))
                if suelos:
                    celdas.append(f"{st.mean(suelos):>8.1f}[{min(suelos):>5.1f}]")
                else:
                    celdas.append(f"{'--':>17}")
            p(f"{nombre:>16} | " + " | ".join(celdas))

    texto = "\n".join(lineas)
    print(texto)
    with open(os.path.join(_DIR, "salida_ataque2.txt"), "w") as f:
        f.write(texto + "\n")


if __name__ == "__main__":
    main()
