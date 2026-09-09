#!/usr/bin/env python3
"""
r11c_lib.py — EXTENSION para la ronda 11c (D9). NO reescribe ningun instrumento:

  · GHOSTDAG fiel            -> `r8c_gd.DAG`      (D9-c, rusty-kaspa @ c338d495)
  · calendario y adversario  -> `r8c_sim.Mundo`   (D9-c, paper L1024-1027, SIN retardo)
  · R-FIN-1a + CLAUSURA DE PUBLICACION -> `r9c_lib.MundoR9` (9c)
  · c_m                      -> `r8c_steering.c_interp` (D9-c)
  · familia de estrategias   -> la de `r8f_b1_slot.py` (D9-f), literal, mas retencion

Lo que anade, y SOLO esto:

  1. `MundoR11(MundoR9)` — copia de `MundoR9.corre` (r9c_lib.py:114-186) con UNA
     diferencia marcada `# [11c]`: la politica `'propio'`, que cuelga el bloque del
     ATACANTE de su propio bloque anterior aun retenido. Es la maniobra del punto C.5
     («el atacante es el primer referenciador de sus propios candidatos»). Sin ella la
     hipotesis H3 no se puede atacar. Se guarda `self.llega` para el punto D.
     Ademas `retraso_honesto`: un granjero honesto lento (punto D).

  2. Las SEIS lecturas del ancla sobre la MISMA cadena seleccionada:
        BASE  R-FIN-1 vigente : menor `blue_work` entre los de `slot >= T_j`
        H1    slot exacto     : `slot = s*` (s* = menor slot >= T_j presente), desempate bw
        H2    desempate sd    : menor `solution_distance` entre los de `slot >= T_j`
        H1H2  H1 + desempate por `solution_distance` (la forma del informe, §6c)
        H3    candidatura     : BASE restringido a los publicados antes de `S_ANCLA`
        H1H3  H1 + la misma restriccion
     «publicado» (H3) = `slot` del PRIMER bloque de la cadena seleccionada que lo
     referencia. PROPOSICION (se demuestra en el informe §C.4): para un bloque de la
     cadena ese bloque es SIEMPRE su sucesor de cadena, luego
        pub_slot(Chn[i]) = slot(Chn[i+1])
     y la regla H3 se lee «el salto de slot al sucesor de cadena es < S_ANCLA». El tip no
     tiene sucesor: `pub_slot = +inf` (no candidato). Se cuenta (`sin_sucesor`).

  3. Contadores de cobertura de rama por regla (`COB11`): si la rama que distingue una
     hipotesis del ancla vigente no se ejecuta, la comparacion no dice nada.

Criterio alpha: todo script de la ronda imprime la fila `alpha = 0`.
"""
import math
import os
import sys

_AQUI = os.path.dirname(os.path.abspath(__file__))
_D9C = os.path.normpath(os.path.join(_AQUI, "..", "d9-ronda8c"))
_D9F = os.path.normpath(os.path.join(_AQUI, "..", "d9-ronda8f"))
_D9_9C = os.path.normpath(os.path.join(_AQUI, "..", "d9-ronda9c"))
_D8_8 = os.path.normpath(os.path.join(_AQUI, "..", "d8-ronda8"))
for _p in (_D9C, _D9F, _D9_9C, _D8_8):
    if _p not in sys.path:
        sys.path.insert(0, _p)

from r8c_gd import DAG                                          # noqa: E402
from r8c_sim import LAMBDA, DELTA                               # noqa: E402
from r8c_steering import c_interp                               # noqa: E402
from r9c_lib import MundoR9, COB, slot_de, SEMILLAS             # noqa: E402

K, MP, MSL = 30, 15, 180
S_MAX = 150            # R-FIN-1a, validez
S_ANCLA = 45           # H3: candidatura a ancla (= W_dec medido en 9c)
INF = float("inf")

REGLAS = ("BASE", "H1", "H2", "H1H2", "H3", "H1H3")

# Cobertura de rama (globales al proceso). Un 0 aqui hay que LEERLO, no ignorarlo.
COB11 = {
    "perfiles": 0,           # perfiles de cadena leidos
    "cand_multi": 0,         # veces que el conjunto de candidatos H1 tiene >1 bloque
    "cand_multi_max": 0,     # tamano maximo de ese conjunto
    "ventana_multi": 0,      # veces que el conjunto BASE (slot>=T) tiene >1 bloque
    "h3_muerde": 0,          # veces que H3 descarta al menos un candidato
    "h3_descarta_ancla": 0,  # veces que H3 descarta el ancla que BASE habria elegido
    "sin_sucesor": 0,        # tip sin sucesor de cadena (pub_slot = inf)
    "h3_vacio": 0,           # H3 deja el conjunto de candidatos VACIO
    "propio_ok": 0,          # bloques creados con la politica 'propio'
    "propio_no": 0,          # 'propio' rechazado (R-FIN-1a o sin bloque previo)
    "difiere": {r: 0 for r in REGLAS},   # veces que la regla da un ancla != BASE
    "comparaciones": 0,
}


# =======================================================================================
# 1 · MUNDO — MundoR9 + politica 'propio' + granjero honesto lento
# =======================================================================================
class MundoR11(MundoR9):
    """`MundoR9` (r9c_lib.py) con dos anadidos marcados `# [11c]`."""

    def __init__(self, alpha, T, seed, s_max=S_MAX, retraso_honesto=0.0,
                 frac_lenta=0.0, **kw):
        super().__init__(alpha, T, seed, s_max=s_max, **kw)
        # [11c] granjero honesto lento (punto D): los honestos con indice congruente
        # reciben `retraso_honesto` segundos de retardo EXTRA de publicacion. Su bloque
        # sigue siendo valido (S_max = 150 s) y cobra igual (R-FIN-8'): lo unico que
        # cambia es su `pub_slot`, y por tanto su candidatura bajo H3.
        self.retraso_honesto = retraso_honesto
        self.frac_lenta = frac_lenta
        self.lentos = set()
        self.llega = {}

    def _es_lento(self, i):
        if self.frac_lenta <= 0.0 or self.retraso_honesto <= 0.0:
            return False
        return (i % 1000) < int(round(1000 * self.frac_lenta))

    # Copia de r9c_lib.py:114-186 (`MundoR9.corre`). Delta marcada `# [11c]`.
    def corre(self, estrategia=None, copias=0):
        est = estrategia or {}
        d = DAG(k=self.k, u2=True, u3_mode=self.u3_mode,
                max_parents=self.mp, mergeset_limit=self.msl)
        g = d.genesis()
        llega = {g: 0.0}
        ult_propio = None                                   # [11c]
        for i, (t, quien, sd, sde, ident) in enumerate(self.ev):
            visibles = [h for h, ta in llega.items() if ta <= t]
            if quien == "h":
                padres = self._padres_r1a(d, visibles, t, "h")
                if padres is None:
                    continue
                bid = f"b{i}"
                ok, _ = d.add(bid, padres, t=t, creator="h", ident=ident, sd=sd, seed=sde)
                if ok:
                    ex = self.retraso_honesto if self._es_lento(i) else 0.0   # [11c]
                    if ex:
                        self.lentos.add(bid)                                  # [11c]
                    llega[bid] = t + DELTA + ex
                    COB["bloques_h"] += 1
            else:
                retraso, pol = est.get(i, (0.0, "tips"))
                if retraso is None:
                    COB["retenidos"] += 1
                    continue
                if retraso > 0:
                    COB["liberados"] += 1
                todos = list(llega.keys()) if self.atacante_sin_retardo else visibles
                if pol == "propio":                          # [11c] maniobra C.5
                    if ult_propio is None or ult_propio not in d.B:
                        COB11["propio_no"] += 1
                        continue
                    if not (0 <= slot_de(t) - slot_de(d.B[ult_propio].t) <= self.s_max):
                        COB11["propio_no"] += 1
                        continue
                    padres = [ult_propio]
                    for c in sorted(d.tips(todos), key=lambda h: -d.gd[h].blue_work):
                        if len(padres) >= self.mp:
                            break
                        if c == ult_propio:
                            continue
                        if d._key(c) > d._key(ult_propio):
                            continue      # seria sp y el bloque no colgaria del propio
                        padres.append(c)
                    COB11["propio_ok"] += 1
                elif pol == "tips_pub":
                    padres = self._padres_r1a(d, visibles, t, "a")
                    if padres is None:
                        continue
                    COB["tips_pub"] += 1
                elif pol == "tips":
                    padres = self._padres_r1a(d, todos, t, "a")
                    if padres is None:
                        continue
                elif pol == "sp":
                    p = self._padres_r1a(d, todos, t, "a")
                    if p is None:
                        continue
                    padres = [p[0]]
                elif isinstance(pol, tuple) and pol[0] == "retro":
                    p = self._padres_r1a(d, todos, t, "a")
                    if p is None:
                        continue
                    ch = d.selected_chain(p[0])
                    cand = ch[max(0, len(ch) - 1 - pol[1])]
                    if not (0 <= slot_de(t) - slot_de(d.B[cand].t) <= self.s_max):
                        continue
                    padres = [cand]
                else:
                    raise ValueError(pol)
                bid = f"b{i}"
                ok, _ = d.add(bid, padres, t=t, creator="a", ident=ident, sd=sd, seed=sde)
                if not ok:
                    continue
                ult_propio = bid                              # [11c]
                extra = 0.0 if self.atacante_sin_retardo else DELTA
                llega[bid] = t + retraso + extra
                for _p in d.anc[bid]:            # clausura de publicacion (9c)
                    if llega.get(_p, INF) > llega[bid]:
                        llega[_p] = llega[bid]
                        COB["clausura_publicacion"] += 1
                for c in range(copias):
                    cid = f"b{i}c{c}"
                    okc, _ = d.add(cid, padres, t=t, creator="a", ident=ident,
                                   sd=sd + 1 + c, seed=sde)
                    if okc:
                        llega[cid] = t + retraso + extra
                COB["bloques_a"] += 1
        tip = d.virtual_sp(list(llega))
        self.llega = llega
        return d, tip


# =======================================================================================
# 2 · PERFIL DE CADENA Y LAS SEIS LECTURAS DEL ANCLA
# =======================================================================================
def perfil(d, tip, gran=1.0):
    """[(idx, bid, slot, blue_work, sd, seed, pub_slot)] de genesis al tip.

    pub_slot(Chn[i]) = slot(Chn[i+1]): el sucesor de cadena es SIEMPRE el primer bloque de
    la cadena seleccionada que referencia a Chn[i] (los anteriores no lo tienen en su
    pasado; los posteriores tienen slot >= por R-FIN-1a)."""
    ch = d.selected_chain(tip)
    out = []
    for i, b in enumerate(ch):
        ps = slot_de(d.B[ch[i + 1]].t, gran) if i + 1 < len(ch) else INF
        if i + 1 >= len(ch):
            COB11["sin_sucesor"] += 1
        out.append((i, b, slot_de(d.B[b].t, gran), d.gd[b].blue_work,
                    d.B[b].sd, d.B[b].seed, ps))
    COB11["perfiles"] += 1
    return out


def _cands_base(pf, T):
    return [e for e in pf if e[2] >= T]


def _cands_h1(cands):
    if not cands:
        return cands
    s = min(e[2] for e in cands)
    return [e for e in cands if e[2] == s]


def _filtro_h3(cands, s_ancla=S_ANCLA):
    return [e for e in cands if e[6] - e[2] < s_ancla]


def anclas(pf, T, s_ancla=S_ANCLA, contar=True):
    """Devuelve {regla: (seed, idx)} para las seis reglas, sobre la MISMA cadena."""
    base = _cands_base(pf, T)
    r = {}
    if not base:
        return {k: (None, None) for k in REGLAS}
    if contar:
        if len(base) > 1:
            COB11["ventana_multi"] += 1
    h1 = _cands_h1(base)
    if contar:
        if len(h1) > 1:
            COB11["cand_multi"] += 1
            COB11["cand_multi_max"] = max(COB11["cand_multi_max"], len(h1))
    b3 = _filtro_h3(base, s_ancla)
    if contar and len(b3) < len(base):
        COB11["h3_muerde"] += 1
    h1b3 = _cands_h1(b3)

    def por_bw(c):
        return (None, None) if not c else (lambda e: (e[5], e[0]))(min(c, key=lambda e: (e[3], e[0])))

    def por_sd(c):
        return (None, None) if not c else (lambda e: (e[5], e[0]))(min(c, key=lambda e: (e[4], e[3], e[0])))

    r["BASE"] = por_bw(base)
    r["H1"] = por_bw(h1)
    r["H2"] = por_sd(base)
    r["H1H2"] = por_sd(h1)
    r["H3"] = por_bw(b3)
    r["H1H3"] = por_bw(h1b3)
    if contar:
        if not b3:
            COB11["h3_vacio"] += 1
        elif r["H3"] != r["BASE"]:
            COB11["h3_descarta_ancla"] += 1
        COB11["comparaciones"] += 1
        for k in REGLAS:
            if r[k] != r["BASE"]:
                COB11["difiere"][k] += 1
    return r


# =======================================================================================
# 3 · FAMILIAS DE ESTRATEGIAS
# =======================================================================================
POLS_D9F = ["sp", ("retro", 1), ("retro", 2), ("retro", 4), ("retro", 8), ("retro", 16)]
RETENCIONES = (0.0, 4.0, 12.0, 30.0, 60.0, 100.0, 149.0)   # retencion HASTA S_max


def idx_ventana(mundo, tP, W=30.0):
    return [i for i, (t, q, *_) in enumerate(mundo.ev) if q == "a" and tP - W <= t <= tP + W]


def fam_d9f(mundo, tP, W=30.0, pols=POLS_D9F):
    """La familia LITERAL de `r8f_b1_slot.py` (D9-f): global y bloque a bloque."""
    idx = idx_ventana(mundo, tP, W)
    ests = [{}]
    for pol in pols:
        ests.append({i: (0.0, pol) for i in idx})
    for i in idx:
        for pol in pols:
            ests.append({i: (0.0, pol)})
    return ests, idx


def fam_retencion(mundo, tP, W=30.0, pols=POLS_D9F, retenciones=RETENCIONES):
    """D9-f + retencion hasta S_max: se retiene TODO en la ventana menos un bloque, que se
    libera con retraso `r` y politica `pol`. ANIDADA sobre `fam_d9f` por construccion."""
    ests, idx = fam_d9f(mundo, tP, W, pols)
    ests.append({i: (None, "tips") for i in idx})
    for i in idx:
        for pol in ["tips_pub"] + list(pols):
            for r in retenciones:
                e = {j: (None, "tips") for j in idx}
                e[i] = (r, pol)
                ests.append(e)
    return ests, idx


def fam_propio(mundo, tP, W=30.0, salto_max=6, pubs=(60.0, 100.0), s_ancla=S_ANCLA):
    """MANIOBRA C.5: el atacante retiene DOS bloques suyos, X (candidato a ancla) y un
    sucesor Y con `slot(Y) - slot(X) < S_ANCLA` que cuelga de X ('propio'), y publica los
    dos EN EL MISMO INSTANTE. Si Y acaba en la cadena, `pub_slot(X) = slot(Y)` y X pasa el
    filtro H3 pese a haber estado retenido `T_pub - slot(X)` segundos."""
    idx = idx_ventana(mundo, tP, W)
    ests = []
    tiempos = {i: mundo.ev[i][0] for i in idx}
    for a, i in enumerate(idx):
        for j in idx[a + 1:a + 1 + salto_max]:
            if tiempos[j] - tiempos[i] >= s_ancla:
                continue
            for dpub in pubs:
                T = tiempos[j] + dpub
                e = {q: (None, "tips") for q in idx}
                e[i] = (T - tiempos[i], "tips_pub")
                e[j] = (T - tiempos[j], "propio")
                ests.append(e)
    return ests, idx


# =======================================================================================
# 4 · STEERING — I = c_m * sqrt(n_eval/(alpha*lambda)) / g   (R-FIN-14 (f); 9c r9c_d2)
# =======================================================================================
G_OBJ = 0.036          # techo de steering publicado
N_EVAL = 135.0         # rho_max = 3 x W_dec = 45 s (9c)
A_CAL = 0.10           # alpha de calibracion (el peor: g ~ 1/sqrt(alpha))
WK = 1.22              # W/kappa <= 1,22 (BDK+19 §2)


def I_de(m, n_eval=N_EVAL, g=G_OBJ, alpha=A_CAL, lam=LAMBDA):
    cm = c_interp(m)
    I = cm * math.sqrt(n_eval / (alpha * lam)) / g if m > 1 else 0.0
    return cm, I, (I / (WK - 1.0) if I else 0.0)
