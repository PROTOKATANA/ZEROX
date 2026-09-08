#!/usr/bin/env python3
"""
d8_lib.py — EXTENSION de D9-c/d/e/f. No reescribe el GHOSTDAG ni el simulador: importa
`r8c_gd.DAG` (fiel a rusty-kaspa @ c338d495) y `r8c_sim.Mundo` (adversario del paper,
L1024-1027, sin retardo) y anade SOLO lo que D8 necesita:

  · `MundoL9`   — el atacante que ejecuta LITERALMENTE la maniobra del Lema 9
                  (phantom-ghostdag.txt L1131-1141): retener bloques hasta tener `J` en el
                  ANTICONO del padre seleccionado honesto, con el ultimo alcanzando score
                  >= el del padre seleccionado, y soltarlos de golpe. Ninguna estrategia de
                  D9-c/d/e/f la implementa: todas son politicas POR BLOQUE ('tips', 'sp',
                  ('retro',n)) con publicacion inmediata o con un retraso fijo. La maniobra
                  del Lema 9 es ADAPTATIVA (la condicion de publicacion depende del estado
                  del DAG), asi que exige sobrescribir `corre`; se reutiliza `_padres`
                  (pick_virtual_parents) sin tocarlo.

  · `MundoDosVistas` — DOS nodos honestos H_A y H_B con retardo Delta ENTRE ELLOS, y el
                  atacante del paper sin retardo, capaz de entregar a UNO y no al otro.
                  Todo D9 hasta hoy uso una sola vista honesta (el defecto `d8b_b3`).

CRITERIO ALPHA (regla 1): todo experimento imprime la fila alpha=0.
COBERTURA DE RAMA (regla 2): `MundoL9` lleva contadores `n_rafagas`, `n_abandonos`,
`n_intentos`, `n_bloques_priv`; si `n_rafagas == 0` la maniobra NO se ejecuto y la fila no
dice nada. `MundoDosVistas` lleva `n_divergencias_tip`.
"""
import os
import sys

_D9C = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "d9-ronda8c"))
_D9D = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "d9-ronda8d"))
_D9E = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "d9-ronda8e"))
_D9F = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "d9-ronda8f"))
for _p in (_D9F, _D9E, _D9D, _D9C):
    if _p not in sys.path:
        sys.path.insert(0, _p)

from r8c_gd import DAG                                    # noqa: E402
from r8c_sim import Mundo, LAMBDA, DELTA                  # noqa: E402

K, MP, MSL = 30, 15, 180


# =======================================================================================
# A1 — LA MANIOBRA DEL LEMA 9, LITERAL
# =======================================================================================
class MundoL9(Mundo):
    """Atacante que ejecuta la maniobra del caso peor del Lema 9.

    Cita literal (phantom-ghostdag.txt L1131-1141):
      «the adversary gains the most by publishing k + 1 blocks in the anticone of the
       selected parent such that the most recent published block has score at least as
       large as that of the selected parent. This will cause the honest network to switch
       a chain, such that all the blocks in the anticone of the old selected parent,
       except the k + 1 blocks published by the adversary, will be considered red (as they
       are all in the anticone of the published k + 1 blocks, which are blue). On average,
       there are at most 2Dlambda such blocks, so that the adversary has managed to
       replace k + 2Dlambda blue blocks with k + 1 blue blocks.»

    Traduccion operativa, con los parametros que el paper deja libres:
      J        cuantos bloques lleva la rafaga (el paper: k+1).
      d_fork   a que profundidad de la cadena seleccionada honesta se bifurca (>=1, si
               fuera 0 el ultimo bloque tendria a B en su pasado y no habria maniobra).
      giveup   si el honesto le saca mas de `giveup` de blue_work, abandona la rafaga
               (los bloques retenidos se pierden) y vuelve a bifurcar desde la punta.
               None = no abandona nunca.
      modo     'cadena' : los J bloques forman una cadena privada (el ultimo tiene
                          score = score(ancla) + J).
               'abanico': J-1 en paralelo desde el ancla + 1 de cierre que los fusiona
                          (mismo score, pero anticono mas ancho).

    Condicion de publicacion: `_key(tip_privado) > _key(sp_honesto)` — estricta, para que
    `find_selected_parent` (protocol.rs:99-106) cambie de verdad de cadena. Se CUENTA.
    """

    def __init__(self, *a, **kw):
        super().__init__(*a, **kw)
        self.n_rafagas = 0
        self.n_abandonos = 0
        self.n_intentos = 0
        self.n_bloques_priv = 0
        self.n_bloques_perdidos = 0
        self.n_score_ok = 0
        self.n_rechazados = 0
        self.motivos = {}
        self.tam_rafagas = []

    def corre_l9(self, J=31, d_fork=1, giveup=None, modo="cadena", vista_sp="honesta"):
        """`vista_sp`: 'honesta' = el sp que el nodo honesto USA en t (solo lo ya entregado)
        — es contra ese contra el que hay que ganar para que la red cambie de cadena.
        'paper'   = la vista omnisciente del atacante, INCLUIDO lo que aun viaja. Es lo que
        hacia el codigo heredado; sobreestima al honesto y RETRASA la publicacion.
        D8 corrige a 'honesta' por defecto y mide las dos (defecto declarado, informe §0.3)."""
        d = DAG(k=self.k, u2=True, u3_mode=self.u3_mode,
                max_parents=self.mp, mergeset_limit=self.msl)
        g = d.genesis()
        llega = {g: 0.0}          # bid -> instante en que lo ve el honesto
        priv = []                 # bloques retenidos de la rafaga en curso, en orden
        ancla = None
        self.n_rafagas = self.n_abandonos = self.n_intentos = 0
        self.n_bloques_priv = self.n_bloques_perdidos = 0
        self.n_score_ok = 0
        self.n_rechazados = 0
        self.motivos = {}
        self.tam_rafagas = []

        for i, (t, quien, sd, sde, ident) in enumerate(self.ev):
            visibles = [h for h, ta in llega.items() if ta <= t]
            if quien == "h":
                padres = self._padres(d, visibles)
                bid = f"b{i}"
                ok, _ = d.add(bid, padres, t=t, creator="h", ident=ident, sd=sd, seed=sde)
                if ok:
                    llega[bid] = t + DELTA
                continue

            # ---- atacante: ve TODO lo entregado al instante (paper L1024-1027) ----
            pub = [h for h in llega]                       # vista omnisciente (paper L1024-1027)
            sp_h = d.virtual_sp(pub if vista_sp == "paper" else visibles)

            if not priv:                                   # abrir rafaga nueva
                ch = d.selected_chain(sp_h)
                ancla = ch[max(0, len(ch) - 1 - d_fork)]
                self.n_intentos += 1

            # ---- crear el bloque privado ----
            if modo == "cadena":
                padres = [priv[-1]] if priv else [ancla]
            elif modo == "abanico":
                if len(priv) < J - 1:
                    padres = [ancla]
                else:
                    padres = list(priv[-(self.mp):])       # cierre: fusiona los ultimos
            elif modo == "parasito":
                # NUEVO EN D8. Cadena privada PARASITA: cada bloque fusiona la vista HONESTA
                # del instante (todo lo ya entregado, con retardo Delta) MAS la punta privada.
                # Asi el atacante hereda el blue_work honesto y su ventaja crece a ritmo alpha,
                # sin carrera. Ninguna estrategia de D9-c/d/e/f hace esto: todas publican
                # inmediatamente o con retraso fijo, nunca acumulan una cadena que fusione.
                ph = self._padres(d, visibles)
                if priv:
                    padres = [priv[-1]] + [x for x in ph if x != priv[-1]][:self.mp - 1]
                else:
                    padres = ph[:self.mp]
            else:
                raise ValueError(modo)
            bid = f"a{i}"
            ok, motivo = d.add(bid, padres, t=t, creator="a", ident=ident, sd=sd, seed=sde)
            if not ok:
                self.n_rechazados += 1
                self.motivos[motivo] = self.motivos.get(motivo, 0) + 1
                continue
            priv.append(bid)
            self.n_bloques_priv += 1

            # ---- condicion de publicacion del Lema 9 ----
            tip_p = max(priv, key=d._key)
            if d._key(tip_p) > d._key(sp_h):
                self.n_score_ok += 1
            if len(priv) >= J and d._key(tip_p) > d._key(sp_h):
                for b in priv:
                    llega[b] = t                            # entrega instantanea (paper)
                self.n_rafagas += 1
                self.tam_rafagas.append(len(priv))
                priv = []
                continue

            # ---- abandono ----
            if giveup is not None and \
               d.gd[sp_h].blue_work - d.gd[tip_p].blue_work > giveup:
                self.n_abandonos += 1
                self.n_bloques_perdidos += len(priv)
                priv = []                                   # nunca se entregan

        tip = d.virtual_sp([h for h in llega])
        return d, tip, llega


def delta_hon(d, tip, t1, t2):
    """`delta` del Lema 9 MEDIDO: fraccion de bloques honestos creados en (t1, t2] que NO
    acaban en el blue set de la vista honesta final. Normalizado por los honestos REALMENTE
    creados (la correccion que D9-d se hizo a si mismo en r8d_a3g_final.py)."""
    az = d.blueset(tip)
    hon = [h for h in d.B if d.B[h].creator == "h" and t1 < d.B[h].t <= t2]
    if not hon:
        return None, 0
    return 1 - sum(1 for h in hon if h in az) / len(hon), len(hon)


# =======================================================================================
# A2 — DOS VISTAS HONESTAS DISTINTAS
# =======================================================================================
class MundoDosVistas(Mundo):
    """Dos nodos honestos H_A y H_B separados por `Delta` segundos; el atacante ve todo al
    instante y puede entregar a UNO SOLO (`sesgo`), que es la unica forma de crear vistas
    genuinamente distintas — con entrega simetrica las dos vistas difieren solo por el
    retardo de propagacion honesta.

    Modelo de retardo (el del paper generalizado a dos nodos):
      · bloque creado por H_A en t  -> visible en A en t, en B en t+Delta
      · bloque creado por H_B en t  -> visible en B en t, en A en t+Delta
      · bloque del atacante         -> visible en el destino elegido en t (+Delta en el otro
                                       si `sesgo` es 'ambos'; nunca, si es 'A' o 'B')
    El atacante se reparte 50/50 los bloques honestos entre A y B (moneda del calendario),
    asi que con alpha=0 las dos vistas difieren solo por Delta: el criterio alpha vale.
    """

    def __init__(self, *a, **kw):
        super().__init__(*a, **kw)
        self.sem = a[2] if len(a) > 2 else kw.get("seed", 0)
        self.n_div_tip = 0
        self.n_muestras = 0
        self.n_sesgados = 0
        self.n_ambos = 0

    @staticmethod
    def _entrega(d, llega, bid, t):
        """Entregar un bloque implica entregar TODO su pasado: un nodo no puede validar
        `bid` sin sus ancestros (headers-first). Es la correccion de D8 al modelo heredado,
        y limita el poder de retencion: en cuanto un honesto construye sobre un bloque
        sesgado, el OTRO nodo lo recibe al pedir los ancestros."""
        if bid in llega and llega[bid] <= t:
            return
        llega[bid] = min(llega.get(bid, float("inf")), t)
        for a in d.anc[bid]:
            if a not in llega or llega[a] > t:
                llega[a] = t

    def corre_2v(self, sesgo="A", pol="tips", frac_sesgada=1.0):
        """`sesgo`: 'ambos' (control), 'A' (todo al nodo A), 'B', 'alterna'.
        `frac_sesgada`: fraccion de bloques del atacante que se sesgan; el resto va a los dos.
        Devuelve (d, llegaA, llegaB)."""
        import random
        rng = random.Random(hash((self.alpha, self.T, sesgo, self.sem)) & 0xFFFFFF)
        self.n_sesgados = self.n_ambos = 0
        d = DAG(k=self.k, u2=True, u3_mode=self.u3_mode,
                max_parents=self.mp, mergeset_limit=self.msl)
        g = d.genesis()
        llegaA = {g: 0.0}
        llegaB = {g: 0.0}
        for i, (t, quien, sd, sde, ident) in enumerate(self.ev):
            if quien == "h":
                # el bloque honesto lo crea A o B (moneda estructural del indice)
                nodo = "A" if (i % 2 == 0) else "B"
                vis = [h for h, ta in (llegaA if nodo == "A" else llegaB).items() if ta <= t]
                padres = self._padres(d, vis)
                bid = f"b{i}"
                ok, _ = d.add(bid, padres, t=t, creator="h", ident=ident, sd=sd, seed=sde)
                if not ok:
                    continue
                if nodo == "A":
                    self._entrega(d, llegaA, bid, t)
                    self._entrega(d, llegaB, bid, t + DELTA)
                else:
                    self._entrega(d, llegaB, bid, t)
                    self._entrega(d, llegaA, bid, t + DELTA)
            else:
                # atacante: vista completa de LO ENTREGADO A CUALQUIERA (sin retardo)
                todos = list(set(llegaA) | set(llegaB))
                if pol == "tips":
                    padres = self._padres(d, todos)
                elif pol == "sp":
                    padres = [d.virtual_sp(todos)]
                elif isinstance(pol, tuple) and pol[0] == "retro":
                    tip = d.virtual_sp(todos)
                    ch = d.selected_chain(tip)
                    padres = [ch[max(0, len(ch) - 1 - pol[1])]]
                else:
                    raise ValueError(pol)
                bid = f"a{i}"
                ok, _ = d.add(bid, padres, t=t, creator="a", ident=ident, sd=sd, seed=sde)
                if not ok:
                    continue
                sesgar = rng.random() < frac_sesgada
                dest = sesgo
                if sesgo == "alterna":
                    dest = "A" if rng.random() < 0.5 else "B"
                if not sesgar or sesgo == "ambos":
                    self._entrega(d, llegaA, bid, t)
                    self._entrega(d, llegaB, bid, t)
                    self.n_ambos += 1
                elif dest == "A":
                    self._entrega(d, llegaA, bid, t)   # B solo por cierre de ancestros
                    self.n_sesgados += 1
                else:
                    self._entrega(d, llegaB, bid, t)
                    self.n_sesgados += 1
        return d, llegaA, llegaB


def vista_en(d, llega, t):
    """Bloques visibles para un nodo en el instante `t`, y su padre seleccionado virtual."""
    vis = [h for h, ta in llega.items() if ta <= t]
    return vis, d.virtual_sp(vis)
