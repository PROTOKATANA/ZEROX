#!/usr/bin/env python3
"""
r11b_lib.py — EXTENSION para la ronda 11b (D8, sensores de eclipse).

NO modifica ningun fichero de otras rondas: importa por `sys.path` el GHOSTDAG fiel
(`d9-ronda8c/r8c_gd.py`, rusty-kaspa @ c338d495), el simulador de eventos
(`d9-ronda8c/r8c_sim.py`, adversario del paper sin retardo) y el `MundoEclipse` de
`d8-ronda8/d8_a3_smax.py`, que es el instrumento del que salio el 77 % de la auditoria 7.

Lo que anade:

  · `MundoVictima` — una victima `V` con fraccion `f_v` del espacio, sometida a UNA de las
    tres variantes de eclipse del encargo:
        'pot'     el atacante RETIENE el PoT: `V` deja de tener slots y no puede autorizar.
        'filtro'  el PoT pasa; de los bloques honestos solo llega una fraccion `paso`;
                  los bloques del ATACANTE (fraccion `alpha` del espacio) le llegan todos.
        'retraso' el PoT pasa; todo le llega con `E` segundos de retraso EXTRA (la variante
                  de D8 A3b, `MundoEclipse`).
    Instrumenta, para la victima:
        `gaps_V`   slot(B) - slot(sp(B)) de cada bloque suyo (R-FIN-1a / S_max),
        `t_V`      instante de creacion de cada bloque suyo,
        `llegadas` instantes en que un bloque ENTRA en la vista de `V` (el sensor E2),
        `n_V`      cuantos bloques hizo,
        `huerfanos_V` cuantos de sus bloques NO estan en el blueset de la vista publica final.

  · Sensores, como funciones puras sobre series temporales:
        `e1_alarma(...)`  reloj: retraso del PoT recibido frente al reloj de pared.
        `e2_alarma(...)`  tasa: bloques en la ventana deslizante `W`.
        `n_min_poisson(W, lam, fa_ano)` umbral de E2 por cola exacta de Poisson.

CRITERIO ALPHA (metodo, regla 4): todo experimento imprime la fila `alpha = 0` y la fila
`paso = 0` / `E = 0`, que son los controles negativos, y un control positivo antes de medir.
COBERTURA: cada tabla imprime `n_V` (bloques de la victima); si `n_V = 0` la fila no dice nada.
"""
import math
import os
import random
import sys

_AQUI = os.path.dirname(os.path.abspath(__file__))
_D8 = os.path.normpath(os.path.join(_AQUI, "..", "d8-ronda8"))
_D9C = os.path.normpath(os.path.join(_AQUI, "..", "d9-ronda8c"))
_D9F = os.path.normpath(os.path.join(_AQUI, "..", "d9-ronda8f"))
for _p in (_D9F, _D9C, _D8):
    if _p not in sys.path:
        sys.path.insert(0, _p)

from r8c_gd import DAG                                   # noqa: E402
from r8c_sim import Mundo, LAMBDA, DELTA                 # noqa: E402

K, MP, MSL = 30, 15, 180
SIGMA = 1.0          # duracion de slot, s (DECISIONES.md §19: sigma = 1 s)
S_MAX = 150.0        # R-FIN-1a, la eleccion de Katana (auditoria 7 §4)
SEG_ANO = 31_536_000.0


# =======================================================================================
# EL MUNDO CON VICTIMA
# =======================================================================================
class MundoVictima(Mundo):
    """Un honesto `V` con fraccion `f_v` del espacio honesto al que el atacante eclipsa.

    `modo`:
      'pot'     — el PoT deja de llegarle en `t_ecl`. Bajo PoST un bloque debe justificar su
                  slot con la salida del PoT (Autonomys: `sc-proof-of-time`), asi que `V`
                  **no puede crear ningun bloque** a partir de ahi. Se modela literalmente:
                  sus eventos de creacion se descartan. HIPOTESIS DECLARADA: `V` no corre un
                  timelord propio (el granjero objetivo es un PC con SSD; el timelord lo
                  opera el proyecto). Si lo corriera, la variante degenera en 'filtro'.
      'filtro'  — cada bloque honesto ajeno le llega con probabilidad `paso`; los bloques
                  del atacante le llegan siempre (el atacante ES su unico vecino).
      'retraso' — todo le llega con `E` s de retraso extra.

    En los tres, los bloques de `V` SI llegan a la red honesta (con `DELTA`): es el caso mas
    favorable al atacante que sigue siendo coherente, porque los bloques invalidos de `V` se
    propagan y se rechazan (mismo criterio que `MundoEclipse` de D8 A3b).
    """

    def corre_victima(self, modo, f_v=0.05, paso=1.0, E=0.0, t_ecl=0.0, sem=0,
                      pol="tips", retraso_a=0.0):
        rng = random.Random(f"{sem}|{self.T}|{self.alpha}|{modo}|{f_v}|{paso}|{E}|{t_ecl}")
        d = DAG(k=self.k, u2=True, u3_mode=self.u3_mode,
                max_parents=self.mp, mergeset_limit=self.msl)
        g = d.genesis()
        llega = {g: 0.0}          # vista de la red honesta: bid -> instante en que lo ve
        llegaV = {g: 0.0}         # vista de la victima
        self.gaps_V, self.t_V, self.llegadas_V, self.ids_V = [], [], [], []
        self.n_V = 0
        self.n_bloqueados = 0     # bloques honestos que el filtro NO deja pasar
        self.n_pasados = 0        # bloques ajenos que SI entran en la vista de V

        for i, (t, quien, sd, sde, ident) in enumerate(self.ev):
            visibles = [h for h, ta in llega.items() if ta <= t]
            visV = [h for h, ta in llegaV.items() if ta <= t]
            eclipsado = t >= t_ecl

            if quien == "h" and rng.random() < f_v:
                # ---- un bloque de la VICTIMA ----
                if modo == "pot" and eclipsado:
                    continue                                   # sin PoT no hay bloque
                padres = self._padres(d, visV)
                bid = f"v{i}"
                ok, _ = d.add(bid, padres, t=t, creator="h", ident=ident, sd=sd, seed=sde)
                if not ok:
                    continue
                sp = d.gd[bid].sp
                self.gaps_V.append(math.floor(t / SIGMA) - math.floor(d.B[sp].t / SIGMA))
                self.t_V.append(t)
                self.ids_V.append(bid)
                self.n_V += 1
                llega[bid] = t + DELTA
                llegaV[bid] = t
                continue

            if quien == "h":
                # ---- un honesto que NO es la victima ----
                padres = self._padres(d, visibles)
                bid = f"b{i}"
                ok, _ = d.add(bid, padres, t=t, creator="h", ident=ident, sd=sd, seed=sde)
                if not ok:
                    continue
                llega[bid] = t + DELTA
                if not eclipsado:
                    llegaV[bid] = t + DELTA
                    self.llegadas_V.append(t + DELTA)
                    self.n_pasados += 1
                elif modo == "filtro":
                    if rng.random() < paso:
                        llegaV[bid] = t + DELTA
                        self.llegadas_V.append(t + DELTA)
                        self.n_pasados += 1
                    else:
                        self.n_bloqueados += 1
                elif modo == "retraso":
                    llegaV[bid] = t + DELTA + E
                    self.llegadas_V.append(t + DELTA + E)
                    self.n_pasados += 1
                else:                                          # 'pot': no ve nada
                    self.n_bloqueados += 1
                continue

            # ---- un bloque del ATACANTE ----
            todos = list(llega.keys()) if self.atacante_sin_retardo else visibles
            if pol == "tips":
                padres = self._padres(d, todos)
            elif pol == "sp":
                padres = [d.virtual_sp(todos)]
            else:
                tip = d.virtual_sp(todos)
                ch = d.selected_chain(tip)
                padres = [ch[max(0, len(ch) - 1 - pol[1])]]
            bid = f"a{i}"
            ok, _ = d.add(bid, padres, t=t, creator="a", ident=ident, sd=sd, seed=sde)
            if not ok:
                continue
            llega[bid] = t + retraso_a
            if modo == "pot" and eclipsado:
                self.n_bloqueados += 1
            elif modo == "retraso" and eclipsado:
                llegaV[bid] = t + retraso_a + E
                self.llegadas_V.append(t + retraso_a + E)
                self.n_pasados += 1
            else:
                # el atacante SIEMPRE se entrega a si mismo al instante: es el vecino de V
                llegaV[bid] = t + retraso_a
                self.llegadas_V.append(t + retraso_a)
                self.n_pasados += 1

        tip = d.virtual_sp([h for h in llega])
        azules = d.gd[tip].blues if hasattr(d.gd[tip], "blues") else None
        return d, tip, azules

    # -------- lecturas ---------------------------------------------------------------
    def invalidos_V(self, s_max=S_MAX, t0=None, t1=None):
        """Fraccion de bloques de `V` que R-FIN-1a invalida, en la ventana [t0, t1]."""
        par = [(t, gp) for t, gp in zip(self.t_V, self.gaps_V)
               if (t0 is None or t >= t0) and (t1 is None or t <= t1)]
        if not par:
            return None, 0
        mal = sum(1 for _, gp in par if gp > s_max)
        return mal / len(par), len(par)


# =======================================================================================
# SENSOR E2 · TASA
# =======================================================================================
def _log_poisson_cdf(n, mu):
    """log P(N <= n) con N ~ Poisson(mu), sumado en escala logaritmica (estable a mu=300)."""
    if n < 0:
        return -math.inf
    lp = -mu                       # log P(N = 0)
    acc = lp
    for kk in range(1, n + 1):
        lp += math.log(mu) - math.log(kk)
        # acc = log(exp(acc) + exp(lp))
        m = max(acc, lp)
        acc = m + math.log(math.exp(acc - m) + math.exp(lp - m))
    return acc


def n_min_poisson(W, lam=LAMBDA, fa_ano=1.0, solapadas=True):
    """Umbral `n_min` tal que la alarma «menos de n_min bloques en W s» tiene < `fa_ano`
    falsas alarmas al ano con trafico honesto Poisson(lam).

    `solapadas=True`: la ventana se evalua cada slot (sigma = 1 s) -> SEG_ANO/sigma pruebas
    al ano. Es la cota conservadora (ignora la correlacion entre ventanas solapadas, que solo
    puede reducir el numero de excursiones independientes).
    `solapadas=False`: ventanas disjuntas -> SEG_ANO/W pruebas al ano.
    """
    mu = lam * W
    pruebas = (SEG_ANO / SIGMA) if solapadas else (SEG_ANO / W)
    objetivo = math.log(fa_ano / pruebas)
    n = 0
    while n <= int(mu) + 1:
        # alarma si N <= n-1, es decir N < n
        if _log_poisson_cdf(n - 1, mu) > objetivo:
            return n - 1 if n >= 1 else 0, math.exp(_log_poisson_cdf(n - 2, mu)) if n >= 2 else 0.0
        n += 1
    return int(mu), 1.0


def e2_alarma(llegadas, W, n_min, t_ini, t_fin, paso_muestreo=SIGMA):
    """Primer instante en [t_ini, t_fin] en que la ventana deslizante (t-W, t] contiene
    ESTRICTAMENTE menos de `n_min` llegadas. Devuelve None si nunca."""
    ll = sorted(llegadas)
    import bisect
    t = t_ini
    while t <= t_fin:
        hi = bisect.bisect_right(ll, t)
        lo = bisect.bisect_right(ll, t - W)
        if hi - lo < n_min:
            return t
        t += paso_muestreo
    return None


# =======================================================================================
# SENSOR E1 · RELOJ
# =======================================================================================
def lognormal_params(mediana, p99):
    """Parametros (mu, sigma) de una lognormal con esa mediana y ese percentil 99.
    HIPOTESIS DECLARADA: el retardo honesto de entrega del PoT es lognormal."""
    z99 = 2.3263478740408408                 # Phi^-1(0.99)
    mu = math.log(mediana)
    sig = (math.log(p99) - mu) / z99
    return mu, sig


def cuantil_lognormal(mu, sig, p):
    """Cuantil p de la lognormal (mu, sig), con Phi^-1 por biseccion sobre erf."""
    z = _probit(p)
    return math.exp(mu + sig * z)


def _probit(p):
    """Phi^-1(p) por biseccion sobre math.erf. Exacto a 1e-12 en [1e-15, 1-1e-15]."""
    lo, hi = -40.0, 40.0
    for _ in range(200):
        mid = (lo + hi) / 2.0
        cdf = 0.5 * (1.0 + math.erf(mid / math.sqrt(2.0)))
        if cdf < p:
            lo = mid
        else:
            hi = mid
    return (lo + hi) / 2.0


def e1_B(mediana, p99, eps, fa_ano=1.0, muestras_ano=None):
    """`B` (en segundos) tal que la alarma «el PoT recibido va mas de B por detras del reloj
    de pared» tiene < `fa_ano` falsas alarmas al ano.

    Retardo honesto ~ lognormal(mediana, p99); deriva de reloj +-`eps` s (peor caso, se suma).
    `muestras_ano`: numero de pruebas independientes al ano (por defecto, una por slot).
    """
    if muestras_ano is None:
        muestras_ano = SEG_ANO / SIGMA
    p = 1.0 - fa_ano / muestras_ano
    mu, sig = lognormal_params(mediana, p99)
    return cuantil_lognormal(mu, sig, p) + eps, (mu, sig)
