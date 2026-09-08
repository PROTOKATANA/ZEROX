#!/usr/bin/env python3
"""
r9c_lib.py — EXTENSION de D9-c/D9-f para la ronda 9c (palanca P4).

No reescribe nada: importa el GHOSTDAG fiel (`r8c_gd.py`, rusty-kaspa @ c338d495), el
simulador de eventos (`r8c_sim.py`, adversario del paper `phantom-ghostdag.txt`
L1024-1027: SIN retardo interno ni hacia/desde los honestos) y `c_interp`
(`r8c_steering.py`). Anade SOLO lo que 9c necesita:

  · `MundoR9`     subclase de `Mundo` que APLICA R-FIN-1a como regla de VALIDEZ:
                  `0 <= slot(B) - slot(sp(B)) <= S_max`. Un bloque cuyo unico padre
                  seleccionable la viole NO SE CREA (el granjero honesto elige otro sp;
                  el atacante pierde el bloque). Contadores de cobertura de rama.
  · `ancla`       R-FIN-1 literal: MENOR `blue_work` entre los de `slot >= T` en la
                  cadena seleccionada. Se lee la `seed` ESTRUCTURAL (fijada en la
                  creacion), nunca la etiqueta.
  · `menu_en(d)`  el MENU del atacante si su decision se toma en `T_j + d`.

Criterio alpha: toda tabla de los scripts `r9c_*.py` lleva la fila `alpha = 0`.
"""
import math
import os
import sys

_D9C = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "d9-ronda8c"))
_D9F = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "d9-ronda8f"))
for _p in (_D9C, _D9F):
    if _p not in sys.path:
        sys.path.insert(0, _p)

from r8c_gd import DAG                                   # noqa: E402
from r8c_sim import Mundo, LAMBDA, DELTA                 # noqa: E402
from r8c_steering import c_interp, c_m                   # noqa: E402

K, MP, MSL = 30, 15, 180
GRAN = 1.0          # tau = 1 s (rama A''): slot = floor(t)

# Contadores de cobertura de rama, GLOBALES al proceso. Una rama con 0 no dice nada.
COB = {
    "sp_filtrado_h": 0,     # honesto: el sp de mayor blue_work violaba S_max, se tomo otro
    "sin_sp_h": 0,          # honesto: NINGUN candidato valido -> no crea bloque
    "sp_filtrado_a": 0,     # atacante: idem
    "sin_sp_a": 0,
    "bloques_h": 0,
    "bloques_a": 0,
    "retenidos": 0,
    "liberados": 0,
    "rfin1a_ok": 0,
    "clausura_publicacion": 0,
    "tips_pub": 0,         # aristas de cadena comprobadas y validas
}


def slot_de(t, gran=GRAN):
    return t if gran <= 0 else math.floor(t / gran)


class MundoR9(Mundo):
    """Mundo con R-FIN-1a aplicada (S_max en segundos de slot).

    `estrategia` = {indice_de_evento -> (retraso, politica)} igual que `Mundo.corre`;
    `retraso = None` = retenido para siempre.
    """

    def __init__(self, alpha, T, seed, s_max=150, **kw):
        super().__init__(alpha, T, seed, k=K, mp=MP, msl=MSL, u3_mode="dynamic", **kw)
        self.s_max = s_max

    # ---- seleccion de padres con R-FIN-1a ----
    def _padres_r1a(self, d, visibles, t_nuevo, quien):
        """Candidatos = puntas en orden descendente de blue_work (pick_virtual_parents,
        virtual_processor/processor.rs:1092-1118). El sp DEBE cumplir
        `0 <= slot(t_nuevo) - slot(sp) <= s_max`. Los demas padres se anaden solo si NO
        superan al sp en blue_work (si lo superasen, `find_selected_parent` los haria sp
        y el bloque seria invalido)."""
        s_new = slot_de(t_nuevo)
        cands = sorted(d.tips(visibles), key=lambda h: -d.gd[h].blue_work)
        sp = None
        for c in cands:
            sc = slot_de(d.B[c].t)
            if 0 <= s_new - sc <= self.s_max:
                sp = c
                break
        if sp is None:
            COB["sin_sp_h" if quien == "h" else "sin_sp_a"] += 1
            return None
        if cands and sp is not cands[0]:
            COB["sp_filtrado_h" if quien == "h" else "sp_filtrado_a"] += 1
        padres = [sp]
        ms = 1
        for c in cands:
            if c == sp:
                continue
            if ms >= self.msl or len(padres) >= self.mp:
                break
            if d._key_gt(c, sp) if hasattr(d, "_key_gt") else (d._key(c) > d._key(sp)):
                continue                     # seria sp y violaria R-FIN-1a
            inc = len(d.unordered_mergeset(sp, padres + [c])) + 1 - ms
            if ms + inc <= self.msl:
                padres.append(c)
                ms += inc
        return padres

    def corre(self, estrategia=None, copias=0):
        est = estrategia or {}
        d = DAG(k=self.k, u2=True, u3_mode=self.u3_mode,
                max_parents=self.mp, mergeset_limit=self.msl)
        g = d.genesis()
        llega = {g: 0.0}
        for i, (t, quien, sd, sde, ident) in enumerate(self.ev):
            visibles = [h for h, ta in llega.items() if ta <= t]
            if quien == "h":
                padres = self._padres_r1a(d, visibles, t, "h")
                if padres is None:
                    continue
                bid = f"b{i}"
                ok, _ = d.add(bid, padres, t=t, creator="h", ident=ident, sd=sd, seed=sde)
                if ok:
                    llega[bid] = t + DELTA
                    COB["bloques_h"] += 1
            else:
                retraso, pol = est.get(i, (0.0, "tips"))
                if retraso is None:
                    COB["retenidos"] += 1
                    continue
                if retraso > 0:
                    COB["liberados"] += 1
                todos = list(llega.keys()) if self.atacante_sin_retardo else visibles
                if pol == "tips_pub":
                    # El atacante ve todo (paper L1024-1027) pero ELIGE no colgar de sus
                    # bloques aun no publicados, para no delatarlos por clausura. Es lo que
                    # hace consistente una estrategia de retencion de UN candidato.
                    COB["tips_pub"] += 1
                    padres = self._padres_r1a(d, visibles, t, "a")
                    if padres is None:
                        continue
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
                        continue            # R-FIN-1a: el retro-salto es invalido
                    padres = [cand]
                else:
                    raise ValueError(pol)
                bid = f"b{i}"
                ok, _ = d.add(bid, padres, t=t, creator="a", ident=ident, sd=sd, seed=sde)
                if not ok:
                    continue
                extra = 0.0 if self.atacante_sin_retardo else DELTA
                llega[bid] = t + retraso + extra
                # CLAUSURA DE PUBLICACION (corregida en la ronda 9c): publicar un bloque
                # PUBLICA TAMBIEN todos sus ancestros — un nodo no puede validar `bid` sin
                # ellos. Sin esto el atacante «retiene» un bloque y a la vez publica un hijo
                # suyo, imposible en la red real. Es el artefacto que inflaba `W_dec` a 600 s.
                for _p in d.anc[bid]:
                    if llega.get(_p, float("inf")) > llega[bid]:
                        llega[_p] = llega[bid]
                        COB["clausura_publicacion"] += 1
                COB["bloques_a"] += 1
        tip = d.virtual_sp(list(llega))
        return d, tip

    # ---- lectura del ancla, R-FIN-1 literal ----
    def ancla(self, d, tip, T):
        """MENOR blue_work entre los de slot >= T en la cadena seleccionada.
        Devuelve (seed_estructural, t_creacion) o (None, None)."""
        mejor = None
        for b in d.selected_chain(tip):
            if slot_de(d.B[b].t) >= T:
                bw = d.gd[b].blue_work
                if mejor is None or bw < mejor[0]:
                    mejor = (bw, d.B[b].seed, d.B[b].t)
        return (None, None) if mejor is None else (mejor[1], mejor[2])

    def chequea_rfin1a(self, d, tip):
        """Control: TODA arista de la cadena seleccionada cumple R-FIN-1a."""
        mal = 0
        for b in d.selected_chain(tip):
            sp = d.gd[b].sp
            if sp is None:
                continue
            j = slot_de(d.B[b].t) - slot_de(d.B[sp].t)
            COB["rfin1a_ok"] += 1
            if not (0 <= j <= self.s_max):
                mal += 1
        return mal


def eventos_atacante(mundo, t0, t1):
    return [i for i, (t, q, *_) in enumerate(mundo.ev) if q == "a" and t0 <= t <= t1]


SEMILLAS = [11, 23, 37, 41, 59, 67, 73, 89, 97, 101, 113, 127]   # 12, literales
