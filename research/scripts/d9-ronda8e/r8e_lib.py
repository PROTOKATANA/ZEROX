#!/usr/bin/env python3
"""
r8e_lib.py — EXTENSION de D9-c/D9-d. NO reescribe nada: subclasa.

Cierra la LAGUNA MAYOR de D9-d: el simulador usaba `blue_work = blue_score`
(peso 1 por bloque azul). Kaspa usa

    // consensus/src/processes/ghostdag/protocol.rs:155-161
    let added_blue_work = new_block_data.mergeset_blues.iter()
        .map(|h| calc_work(bits(h)).max(level_work)).sum();
    let blue_work = blue_work(selected_parent) + added_blue_work;
    // consensus/src/processes/difficulty.rs:211-217
    pub fn calc_work(bits) -> 2^256/(target+1)

y `find_selected_parent` (protocol.rs:99-106) es el MAXIMO por `blue_work`, luego el
peso elige la cadena seleccionada ENTERA.

Aqui:
  · `DAGW(DAG)`  — sobrescribe SOLO la cola de `add()`: recalcula `blue_work` con
                   `Σ w(SR(h))` sobre `mergeset_blues`. Es correcto hacerlo DESPUES de
                   `super().add()` porque dentro de `add()` el unico uso de `blue_work`
                   es leer el de bloques YA existentes (`_key`), que ya estan corregidos.
  · retarget R-FIN-13 — `ln SR_{n+1} = ln SR_n − γ(ln N_obs − ln N_obj)`, ventana de
                   `W` segundos de tiempo de cadena. La EPOCA de B la fija el sello de
                   tiempo de su PADRE SELECCIONADO, no el suyo: asi `SR(B)` es funcion de
                   `past(B)` (como `bits` en Kaspa/Bitcoin) y el atacante solo la mueve
                   ELIGIENDO PADRES, que es exactamente la pregunta de A1.
  · `MezclaPeso` — mixin que hace que `Mundo.corre` construya un `DAGW` en vez de un
                   `DAG`, SIN duplicar `corre` (monkeypatch local del simbolo
                   `r8c_sim.DAG`, restaurado en `finally`).

CRITERIO DE COBERTURA DE RAMA (el error que casi firma D9-d): `DAGW` lleva contadores
`n_bloques`, `n_retargets`, `n_peso_distinto`, `spread_lnw`. Todo experimento que compare
«peso 1» con «peso real» DEBE imprimirlos: si `n_peso_distinto == 0`, la rama bajo prueba
NO se ejecuto y las dos columnas son la misma por construccion.

Criterio alpha: aqui no hay adversario; los adversarios viven en `r8e_a*.py`.
"""
import math
import os
import sys

_D9C = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "d9-ronda8c"))
_D9D = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "d9-ronda8d"))
for _p in (_D9C, _D9D):
    if _p not in sys.path:
        sys.path.insert(0, _p)

import r8c_sim                                                   # noqa: E402
from r8c_gd import DAG, K_DEFAULT, MAX_PARENTS, MERGESET_LIMIT   # noqa: E402
from r8c_sim import Mundo, LAMBDA, DELTA                         # noqa: E402
from r8d_lib import bs_chain, ancla_bs, ancla_bs_bid, wH, llega_de  # noqa: E402,F401

# Tope de |ln SR| relativo. Kaspa acota con `max_difficulty_target`
# (difficulty.rs:197: `new_target.min(self.max_difficulty_target)`); aqui es simetrico y
# se CUENTA cada vez que muerde, para que no pase por resultado lo que es un tope.
LNSR_LIM = 3.0


class PesoCfg:
    """Configuracion del peso. `W = None` => peso constante == peso 1 (control exacto)."""

    def __init__(self, W=None, gamma=0.25, lam_obj=0.97, lim=LNSR_LIM, modo="desliz"):
        self.W = W
        self.gamma = gamma
        self.lam_obj = lam_obj
        self.lim = lim
        # 'desliz' = ventana DESLIZANTE recalculada en CADA bloque, como Kaspa
        #            (difficulty.rs:166-198: `calculate_difficulty_bits` corre por bloque
        #            sobre `BlockWindowHeap`, y si la ventana no esta llena hereda los
        #            `bits` del padre seleccionado, :170-178). Es el unico modo en que dos
        #            puntas SIMULTANEAS pueden tener pesos distintos.
        # 'epoca'  = retarget solo al cruzar un multiplo de W (lectura literal de
        #            R-FIN-13 «ventana de W slots»). Mas benigno: dos puntas que comparten
        #            la ultima frontera comparten peso EXACTAMENTE.
        self.modo = modo

    def __repr__(self):
        return (f"PesoCfg(W={self.W}, gamma={self.gamma}, "
                f"lam_obj={self.lam_obj}, modo={self.modo})")


class DAGW(DAG):
    """GHOSTDAG con `blue_work` REAL. Todo lo demas se hereda intacto de `r8c_gd.DAG`."""

    def __init__(self, *a, wcfg=None, **kw):
        super().__init__(*a, **kw)
        self.wcfg = wcfg or PesoCfg()
        self.lnsr = {}          # bid -> ln(SR/SR0)
        self.nobs = {}          # bid -> azules acumulados en su epoca, por su cadena
        # --- contadores de COBERTURA DE RAMA ---
        self.n_bloques = 0
        self.n_retargets = 0        # veces que se aplico el paso del controlador
        self.n_peso_distinto = 0    # bloques cuyo w != 1 (rama bajo prueba)
        self.n_clamp = 0
        self.n_ventana_corta = 0
        self.n_inc_distinto = 0     # bloques cuyo incremento de peso != incremento de conteo
        # --- cobertura FINA: ¿el peso llega a DECIDIR algo distinto del conteo? ---
        self.n_sp_llamadas = 0      # llamadas a find_selected_parent con >1 padre
        self.n_sp_discrepa = 0      #   ... en que el argmax por peso != argmax por conteo
        self.n_sp_pesos_dist = 0    #   ... en que los candidatos NO tienen todos el mismo w
        self.n_sort_llamadas = 0    # llamadas a sort_blocks con >1 elemento
        self.n_sort_discrepa = 0    #   ... cuyo orden difiere del orden por conteo

    # ---------- peso de un bloque ----------
    def w(self, bid):
        return math.exp(-self.lnsr.get(bid, 0.0))

    def genesis(self, bid="G", seed=0):
        g = super().genesis(bid, seed)
        self.lnsr[g] = 0.0
        self.nobs[g] = 0.0
        self.n_bloques += 1
        return g

    # ---------- cobertura fina: peso vs conteo en las DOS decisiones de GHOSTDAG ----------
    def _key_conteo(self, h):
        """La MISMA clave que `_key` pero con peso 1 (blue_score en vez de blue_work)."""
        return (self.gd[h].blue_score, -self.B[h].sd, h)

    def find_selected_parent(self, parents):
        ps = list(parents)
        if len(ps) > 1:
            self.n_sp_llamadas += 1
            if len({round(self.w(p), 12) for p in ps}) > 1:
                self.n_sp_pesos_dist += 1
            if max(ps, key=self._key) != max(ps, key=self._key_conteo):
                self.n_sp_discrepa += 1
        return super().find_selected_parent(ps)

    def sort_blocks(self, hs):
        xs = list(hs)
        if len(xs) > 1:
            self.n_sort_llamadas += 1
            if sorted(xs, key=self._key) != sorted(xs, key=self._key_conteo):
                self.n_sort_discrepa += 1
        return super().sort_blocks(xs)

    # ---------- retarget R-FIN-13 ----------
    def _retarget(self, sp, n_nuevos_azules):
        """Devuelve (lnsr, nobs) del bloque nuevo. La epoca la fija el sello de tiempo del
        PADRE SELECCIONADO (funcion de past(B), como `bits` en Kaspa)."""
        cfg = self.wcfg
        ln_sp = self.lnsr[sp]
        nobs_sp = self.nobs[sp]
        if cfg.W is None:
            return 0.0, 0.0
        if cfg.modo == "desliz":
            return self._retarget_desliz(sp)
        # ---- modo 'epoca' ----
        # epoca del bloque nuevo = la del sello de sp; epoca de sp = la del sello de SU sp
        sp_de_sp = self.gd[sp].sp
        e_new = int(self.B[sp].t // cfg.W)
        e_sp = 0 if sp_de_sp is None else int(self.B[sp_de_sp].t // cfg.W)
        if e_new == e_sp:
            return ln_sp, nobs_sp + n_nuevos_azules
        pasos = e_new - e_sp
        n_obj = cfg.lam_obj * cfg.W
        ln = ln_sp
        n = max(nobs_sp, 0.5)
        for p in range(pasos):
            ln = ln - cfg.gamma * (math.log(n) - math.log(n_obj))
            self.n_retargets += 1
            n = 0.5          # epocas intermedias vacias (solo si pasos > 1)
        if ln > cfg.lim:
            ln = cfg.lim; self.n_clamp += 1
        elif ln < -cfg.lim:
            ln = -cfg.lim; self.n_clamp += 1
        return ln, float(n_nuevos_azules)

    def _retarget_desliz(self, sp):
        """Ventana DESLIZANTE de `W` segundos de tiempo de cadena, recalculada en CADA
        bloque, sobre la CADENA SELECCIONADA de `sp` — la forma de Kaspa
        (difficulty.rs:166-198). R-FIN-13 en su forma literal:

            ln SR(B) = ln SR(A) − γ (ln N_obs − ln(λ_obj·W))

        con `A` = bloque de cadena mas antiguo dentro de la ventana y
        `N_obs = blue_score(sp) − blue_score(A)`.

        Como en Kaspa (:170-178) si la ventana NO esta llena se heredan los `bits` del
        padre seleccionado: sin esto, un horizonte corto produciria una deriva que es
        artefacto del arranque, no del retarget.
        """
        cfg = self.wcfg
        t_sp = self.B[sp].t
        if t_sp < cfg.W:                       # ventana incompleta -> hereda (difficulty.rs:177)
            self.n_ventana_corta += 1
            return self.lnsr[sp], 0.0
        lim_t = t_sp - cfg.W
        a = sp
        while True:
            nxt = self.gd[a].sp
            if nxt is None or self.B[a].t <= lim_t:
                break
            a = nxt
        n_obs = self.gd[sp].blue_score - self.gd[a].blue_score
        n_obj = cfg.lam_obj * cfg.W
        ln = self.lnsr[a] - cfg.gamma * (math.log(max(n_obs, 0.5)) - math.log(n_obj))
        self.n_retargets += 1
        if ln > cfg.lim:
            ln = cfg.lim; self.n_clamp += 1
        elif ln < -cfg.lim:
            ln = -cfg.lim; self.n_clamp += 1
        return ln, 0.0

    # ---------- protocol.rs:155-161 ----------
    def add(self, bid, parents, t=0.0, creator="h", ident=None, sd=0, seed=0, enforce=True):
        ok, motivo = super().add(bid, parents, t=t, creator=creator, ident=ident,
                                 sd=sd, seed=seed, enforce=enforce)
        if not ok:
            return (ok, motivo)
        nd = self.gd[bid]
        sp = nd.sp
        n_azules = len(nd.mergeset_blues)
        ln, nobs = self._retarget(sp, n_azules)
        self.lnsr[bid] = ln
        self.nobs[bid] = nobs
        # blue_work = blue_work(sp) + Σ_{h in mergeset_blues} w(h)      protocol.rs:155-161
        inc_peso = sum(self.w(h) for h in nd.mergeset_blues)
        nd.blue_work = self.gd[sp].blue_work + inc_peso
        self.n_bloques += 1
        if abs(math.exp(-ln) - 1.0) > 1e-12:
            self.n_peso_distinto += 1
        if abs(inc_peso - n_azules) > 1e-12:
            self.n_inc_distinto += 1
        return (ok, motivo)

    # ---------- diagnostico ----------
    def spread_lnw(self):
        """Desviacion tipica de ln w sobre los bloques del DAG: el `epsilon` del empalme
        (`dag-poas-empalme-peso.md` §2-3) MEDIDO, no supuesto."""
        vs = [-self.lnsr[b] for b in self.lnsr]
        if len(vs) < 2:
            return 0.0
        mu = sum(vs) / len(vs)
        return math.sqrt(sum((v - mu) ** 2 for v in vs) / (len(vs) - 1))

    def rango_lnw(self):
        vs = [-self.lnsr[b] for b in self.lnsr]
        return (min(vs), max(vs)) if vs else (0.0, 0.0)

    def cobertura(self):
        lo, hi = self.rango_lnw()
        return dict(bloques=self.n_bloques, retargets=self.n_retargets,
                    peso_distinto=self.n_peso_distinto, inc_distinto=self.n_inc_distinto,
                    clamps=self.n_clamp, ventana_corta=self.n_ventana_corta,
                    spread_lnw=self.spread_lnw(),
                    rango_lnw=(lo, hi),
                    sp_llamadas=self.n_sp_llamadas, sp_discrepa=self.n_sp_discrepa,
                    sp_pesos_dist=self.n_sp_pesos_dist,
                    sort_llamadas=self.n_sort_llamadas, sort_discrepa=self.n_sort_discrepa)

    def blue_work_conteo(self, bid):
        """`blue_work` que HABRIA con peso 1 — para contrastar cadena por cadena."""
        return self.gd[bid].blue_score


class MezclaPeso:
    """Mixin: hace que `Mundo.corre` (r8c_sim.py) construya `DAGW` en vez de `DAG` sin
    duplicar una sola linea de `corre`. Guarda el ultimo DAG creado para leer cobertura."""

    def __init__(self, *a, wcfg=None, **kw):
        super().__init__(*a, **kw)
        self.wcfg = wcfg or PesoCfg()
        self.ultimo = None

    def _fabrica(self, **kw):
        d = DAGW(wcfg=self.wcfg, **kw)
        self.ultimo = d
        return d

    def corre(self, estrategia=None, copias=0):
        viejo = r8c_sim.DAG
        r8c_sim.DAG = self._fabrica
        try:
            d, tip = super().corre(estrategia, copias=copias)
        finally:
            r8c_sim.DAG = viejo
        assert isinstance(d, DAGW), "la fabrica no se aplico: el experimento seria vacio"
        return d, tip


class MundoW(MezclaPeso, Mundo):
    pass


def cadena_peso(d, tip):
    """[(bid, blue_score, blue_work, w)] de la cadena seleccionada."""
    return [(b, d.gd[b].blue_score, d.gd[b].blue_work, d.w(b)) for b in d.selected_chain(tip)]
