#!/usr/bin/env python3
"""
r9a_lib.py — EXTENSION de d8-ronda8/d8_lib.py y de d9-ronda8c/{r8c_gd,r8c_sim}.
NO modifica ningun fichero de esos directorios: los importa por `sys.path` (regla 11).

Lo que anade, y por que:

  · `contabilidad(d, tip, t1, t2)` — la CONTABILIDAD DE INTERCAMBIO que ninguna ronda hizo:
    para la ventana (t1,t2] devuelve
        H       bloques honestos creados,
        R       de esos, cuantos NO estan en el blueset publico final (= rojos honestos),
        Apub    bloques del atacante creados y ENTREGADOS (publicados),
        Ablue   de esos, cuantos SI estan en el blueset publico final,
        Wpub    = (H - R) + Ablue  = azules creados en la ventana en la vista publica final.
    El `delta` de D8 es R/H. Lo que decide la carrera es Wpub/T, no (H-R)/T.

  · `MundoSplit` — atacante con PRESUPUESTO REPARTIDO  alpha = alpha_p + alpha_f:
        alpha_p  ejecuta la cadena parasita de D8 (modo 'parasito' de MundoL9) y PUBLICA,
        alpha_f  mantiene un flujo PRIVADO desde t0 y no lo publica nunca.
    El reparto usa numeros aleatorios comunes: cada evento del atacante lleva un uniforme
    u_i fijado por la semilla, y es del flujo si u_i < alpha_f/alpha. Cambiar alpha_p
    RECLASIFICA eventos, no cambia el calendario (regla: comparabilidad entre filas).

    `flujo`:
        'puro'     el flujo privado solo se encadena a si mismo (carrera de Nakamoto).
        'hereda'   ademas fusiona las puntas PUBLICADAS de la parasita  -> maniobra (ii)
                   del encargo: "puede el flujo privado bifurcar por debajo de bloques
                   parasitos publicados y heredarlos?"
        'parasito' el flujo privado fusiona la vista honesta (freeloading, cota 3k del
                   Lema 12) -> control superior: es lo mas que wA puede crecer.

  · `MundoDosParasitas` — dos cadenas parasitas ALTERNAS del mismo atacante (maniobra (i)).

CRITERIO ALPHA (regla 1): todo experimento imprime alpha=0.
COBERTURA (regla 2): n_raf, n_pub, n_priv, n_f, n_intentos; si n_raf==0 la fila no dice nada.
"""
import os
import random
import sys

_AQUI = os.path.dirname(os.path.abspath(__file__))
_D8 = os.path.normpath(os.path.join(_AQUI, "..", "d8-ronda8"))
_D9C = os.path.normpath(os.path.join(_AQUI, "..", "d9-ronda8c"))
for _p in (_D8, _D9C):
    if _p not in sys.path:
        sys.path.insert(0, _p)

from r8c_gd import DAG                                    # noqa: E402
from r8c_sim import Mundo, LAMBDA, DELTA                  # noqa: E402
from d8_lib import MundoL9, delta_hon                     # noqa: E402  (se reusa tal cual)

K = 30


# =======================================================================================
# LA CONTABILIDAD QUE FALTABA
# =======================================================================================
def contabilidad(d, tip, llega, t1, t2):
    """Balance de azules creados en (t1,t2] segun la vista publica final `tip`.

    Devuelve dict con H, R, Apub, Ablue, Wpub, delta=R/H, y las tasas por segundo.
    `llega` decide que bloques del atacante estan PUBLICADOS: los que nunca se entregan
    (flujo privado) no cuentan ni como Apub ni como Ablue.
    """
    az = d.blueset(tip)
    H = R = Apub = Ablue = 0
    for h, b in d.B.items():
        if not (t1 < b.t <= t2):
            continue
        if b.creator == "h":
            H += 1
            if h not in az:
                R += 1
        elif b.creator == "a":
            if h in llega:                 # publicado
                Apub += 1
                if h in az:
                    Ablue += 1
    dur = t2 - t1
    return {
        "H": H, "R": R, "Apub": Apub, "Ablue": Ablue,
        "Wpub": (H - R) + Ablue,
        "delta": (R / H) if H else 0.0,
        "R_por_Apub": (R / Apub) if Apub else 0.0,
        "R_por_Ablue": (R / Ablue) if Ablue else 0.0,
        "tasa_Wpub": ((H - R) + Ablue) / dur,
        "tasa_H": H / dur,
        "tasa_hon_azul": (H - R) / dur,
    }


# =======================================================================================
# ATACANTE CON PRESUPUESTO REPARTIDO
# =======================================================================================
class MundoSplit(MundoL9):
    """alpha = alpha_p + alpha_f. Reutiliza `_padres` (pick_virtual_parents) sin tocarlo."""

    def __init__(self, *a, **kw):
        super().__init__(*a, **kw)
        self.n_f = 0
        self.n_p = 0
        self.n_pub = 0
        self.n_raf = 0
        self.n_intentos = 0
        self.n_rech_f = 0
        self.n_rech_p = 0
        self.adv_max = None
        self.adv_fin = None
        self.adv_traza = []
        self.n_hereda = 0          # cobertura de la rama 'hereda'
        self.n_freeload = 0        # cobertura de la rama 'parasito' del flujo
        self.n_sp_robado = 0       # veces que el sp del bloque del flujo NO fue la punta privada

    def corre_split(self, frac_f=1.0, J=31, t0=60.0, flujo="puro", d_fork=1, semilla_split=0):
        """frac_f = alpha_f/alpha. frac_f=1 -> carrera simple (control). frac_f=0 -> solo parasita."""
        d = DAG(k=self.k, u2=True, u3_mode=self.u3_mode,
                max_parents=self.mp, mergeset_limit=self.msl)
        g = d.genesis()
        llega = {g: 0.0}
        rng = random.Random(f"split-{semilla_split}-{self.T}-1234567")
        priv_p = []          # rafaga parasita en curso (no entregada)
        ancla_p = None
        flujo_tip = None     # punta del flujo privado
        self.n_f = self.n_p = self.n_pub = self.n_raf = self.n_intentos = 0
        self.n_rech_f = self.n_rech_p = self.n_hereda = self.n_freeload = 0
        self.n_sp_robado = 0
        self.adv_traza = []

        for i, (t, quien, sd, sde, ident) in enumerate(self.ev):
            visibles = [h for h, ta in llega.items() if ta <= t]
            if quien == "h":
                padres = self._padres(d, visibles)
                bid = f"b{i}"
                ok, _ = d.add(bid, padres, t=t, creator="h", ident=ident, sd=sd, seed=sde)
                if ok:
                    llega[bid] = t + DELTA
                continue

            # ---------- atacante: reparto con numeros aleatorios comunes ----------
            u = rng.random()
            es_flujo = (u < frac_f) and (t >= t0)

            if es_flujo:
                # ---- flujo PRIVADO: nunca se entrega ----
                if flujo_tip is None:
                    padres = [d.virtual_sp(visibles)]          # bifurca de la punta publica en t0
                else:
                    padres = [flujo_tip]
                    if flujo in ("hereda", "hereda_est"):
                        # maniobra (ii): fusionar las puntas PUBLICADAS de la parasita
                        pubs = [h for h in llega
                                if d.B[h].creator == "a" and llega[h] <= t
                                and not d.is_ancestor(h, flujo_tip) and h != flujo_tip]
                        if flujo == "hereda_est":
                            # ESTRICTO: solo lo que NO le robe el padre seleccionado. Si un
                            # padre tiene mas blue_work que la punta del flujo,
                            # find_selected_parent (protocol.rs:99-106) lo elige a EL y el
                            # flujo deja de ser una cadena competidora: se funde con la publica.
                            pubs = [h for h in pubs if d._key(h) < d._key(flujo_tip)]
                        pubs.sort(key=lambda h: -d.gd[h].blue_work)
                        extra = [h for h in pubs[:self.mp - 1]]
                        if extra:
                            self.n_hereda += 1
                        padres = padres + extra
                    elif flujo in ("parasito", "parasito_est"):
                        ph = self._padres(d, visibles)
                        extra = [x for x in ph if x != flujo_tip]
                        if flujo == "parasito_est":
                            extra = [x for x in extra if d._key(x) < d._key(flujo_tip)]
                        extra = extra[:self.mp - 1]
                        if extra:
                            self.n_freeload += 1
                        padres = padres + extra
                bid = f"f{i}"
                ok, motivo = d.add(bid, padres, t=t, creator="a", ident=ident, sd=sd, seed=sde)
                if not ok:
                    self.n_rech_f += 1
                    continue
                flujo_tip = bid          # cadena privada: la punta es siempre el ultimo
                if d.gd[bid].sp != (padres[0] if padres else None):
                    self.n_sp_robado += 1   # el padre seleccionado NO fue la punta del flujo
                self.n_f += 1
            else:
                # ---- parasita: publica en rafagas (modo 'parasito' de MundoL9) ----
                sp_h = d.virtual_sp(visibles)
                if not priv_p:
                    ch = d.selected_chain(sp_h)
                    ancla_p = ch[max(0, len(ch) - 1 - d_fork)]
                    self.n_intentos += 1
                ph = self._padres(d, visibles)
                if priv_p:
                    padres = [priv_p[-1]] + [x for x in ph if x != priv_p[-1]][:self.mp - 1]
                else:
                    padres = ph[:self.mp]
                bid = f"p{i}"
                ok, motivo = d.add(bid, padres, t=t, creator="a", ident=ident, sd=sd, seed=sde)
                if not ok:
                    self.n_rech_p += 1
                    continue
                priv_p.append(bid)
                self.n_p += 1
                tip_p = max(priv_p, key=d._key)
                if len(priv_p) >= J and d._key(tip_p) > d._key(sp_h):
                    for b in priv_p:
                        llega[b] = t
                    self.n_pub += len(priv_p)
                    self.n_raf += 1
                    priv_p = []

            # ---- traza de la ventaja del flujo privado ----
            if flujo_tip is not None:
                pub_sp = d.virtual_sp([h for h, ta in llega.items() if ta <= t])
                adv = d.gd[flujo_tip].blue_work - d.gd[pub_sp].blue_work
                self.adv_traza.append((t, adv))

        tip = d.virtual_sp([h for h in llega])
        self.div_prof = 0
        self.div_seg = 0.0
        if flujo_tip is not None:
            self.adv_fin = d.gd[flujo_tip].blue_work - d.gd[tip].blue_work
            self.adv_max = max(a for _, a in self.adv_traza)
            # PROFUNDIDAD DE DIVERGENCIA: bloques de la cadena seleccionada del flujo que NO
            # estan en la cadena seleccionada publica. Si es ~0 el 'flujo' no es una cadena
            # competidora: se ha fundido con la publica y no puede reorganizar nada.
            pub_ch = set(d.selected_chain(tip))
            f_ch = d.selected_chain(flujo_tip)
            excl = [b for b in f_ch if b not in pub_ch]
            self.div_prof = len(excl)
            if excl:
                self.div_seg = d.B[flujo_tip].t - min(d.B[b].t for b in excl)
        return d, tip, llega, flujo_tip


# =======================================================================================
# MANIOBRA (i): DOS CADENAS PARASITAS ALTERNAS
# =======================================================================================
class MundoDosParasitas(MundoL9):
    """El atacante mantiene DOS cadenas parasitas simultaneas y alterna sus bloques entre
    ellas; publica la que primero supere al sp honesto. Prueba de la sub-pregunta (i):
    "dos cadenas parasitas alternas"."""

    def corre_2p(self, J=31, d_fork=1):
        d = DAG(k=self.k, u2=True, u3_mode=self.u3_mode,
                max_parents=self.mp, mergeset_limit=self.msl)
        g = d.genesis()
        llega = {g: 0.0}
        cad = [[], []]
        self.n_rafagas = self.n_intentos = self.n_bloques_priv = 0
        self.n_rechazados = 0
        self.n_bloques_perdidos = 0
        self.tam_rafagas = []
        turno = 0
        for i, (t, quien, sd, sde, ident) in enumerate(self.ev):
            visibles = [h for h, ta in llega.items() if ta <= t]
            if quien == "h":
                padres = self._padres(d, visibles)
                bid = f"b{i}"
                ok, _ = d.add(bid, padres, t=t, creator="h", ident=ident, sd=sd, seed=sde)
                if ok:
                    llega[bid] = t + DELTA
                continue
            sp_h = d.virtual_sp(visibles)
            c = cad[turno]
            turno ^= 1
            if not c:
                self.n_intentos += 1
            ph = self._padres(d, visibles)
            padres = ([c[-1]] + [x for x in ph if x != c[-1]][:self.mp - 1]) if c else ph[:self.mp]
            bid = f"a{i}"
            ok, motivo = d.add(bid, padres, t=t, creator="a", ident=ident, sd=sd, seed=sde)
            if not ok:
                self.n_rechazados += 1
                continue
            c.append(bid)
            self.n_bloques_priv += 1
            tip_c = max(c, key=d._key)
            if len(c) >= J and d._key(tip_c) > d._key(sp_h):
                for b in c:
                    llega[b] = t
                self.n_rafagas += 1
                self.tam_rafagas.append(len(c))
                c.clear()
        tip = d.virtual_sp([h for h in llega])
        return d, tip, llega


# =======================================================================================
# MANIOBRA (i) bis: PARASITA CON COPIAS DEL MISMO BILLETE (R-FIN-11 / U3'' dinamica)
# =======================================================================================
class MundoParasitaCopias(MundoL9):
    """Cadena parasita en la que cada bloque va acompanado de `copias` copias del MISMO
    billete colgadas del mismo padre (r8c_sim.Mundo.corre las genera asi). Sirve para
    responder a "copias con U3'' dinamica" de la sub-pregunta (i): las copias ensanchan el
    anticono de los honestos SIN gastar billetes nuevos. U2 las invalida si comparten
    `past`; U3''-dynamic las deja rojas si comparten identidad en el mismo mergeset."""

    def corre_cop(self, J=31, copias=3, d_fork=1):
        d = DAG(k=self.k, u2=True, u3_mode=self.u3_mode,
                max_parents=self.mp, mergeset_limit=self.msl)
        g = d.genesis()
        llega = {g: 0.0}
        priv = []
        self.n_rafagas = self.n_intentos = self.n_bloques_priv = self.n_rechazados = 0
        self.n_bloques_perdidos = 0
        self.tam_rafagas = []
        self.n_copias_ok = 0
        for i, (t, quien, sd, sde, ident) in enumerate(self.ev):
            visibles = [h for h, ta in llega.items() if ta <= t]
            if quien == "h":
                padres = self._padres(d, visibles)
                bid = f"b{i}"
                ok, _ = d.add(bid, padres, t=t, creator="h", ident=ident, sd=sd, seed=sde)
                if ok:
                    llega[bid] = t + DELTA
                continue
            sp_h = d.virtual_sp(visibles)
            if not priv:
                ch = d.selected_chain(sp_h)
                _ = ch[max(0, len(ch) - 1 - d_fork)]
                self.n_intentos += 1
            ph = self._padres(d, visibles)
            padres = ([priv[-1]] + [x for x in ph if x != priv[-1]][:self.mp - 1]) if priv \
                else ph[:self.mp]
            bid = f"a{i}"
            ok, motivo = d.add(bid, padres, t=t, creator="a", ident=ident, sd=sd, seed=sde)
            if not ok:
                self.n_rechazados += 1
                continue
            priv.append(bid)
            self.n_bloques_priv += 1
            cops = []
            for c in range(copias):
                cid = f"a{i}c{c}"
                okc, _ = d.add(cid, padres, t=t, creator="a", ident=ident,
                               sd=sd + 1 + c, seed=sde)
                if okc:
                    cops.append(cid)
                    self.n_copias_ok += 1
            tip_p = max(priv, key=d._key)
            if len(priv) >= J and d._key(tip_p) > d._key(sp_h):
                for b in priv:
                    llega[b] = t
                for b in cops:
                    llega[b] = t
                self.n_rafagas += 1
                self.tam_rafagas.append(len(priv))
                priv = []
        tip = d.virtual_sp([h for h in llega])
        return d, tip, llega


# =======================================================================================
# MANIOBRA (ii)-b: PUBLICAR SOLO UNA PARTE DE LA CADENA PRIVADA
# =======================================================================================
class MundoParcial(MundoL9):
    """Sub-pregunta (ii) del encargo, literal: "puede el atacante publicar parte de la cadena
    privada para enrojecer y seguir con el resto en privado SIN perder la ventaja?"

    Una sola cadena privada parasita (cada bloque fusiona la vista honesta). Cuando
    `len(priv) >= J` y la punta privada supera al sp honesto, se publican los `frac_pub` mas
    VIEJOS y se conserva el resto en privado, encadenando sobre el ultimo privado.
    `frac_pub = 1.0` reproduce la parasita de D8 (control).

    Se mide, ademas de la contabilidad: la ventaja retenida `adv` (blue_work de la punta
    privada menos la de la punta publica) y su maximo, y `div_prof` (bloques de la cadena
    seleccionada privada que no estan en la publica) — si la publicacion parcial NO hace
    cambiar de cadena a la red, no hay rojos y la maniobra no existe: `n_cambios` lo cuenta.
    """

    def corre_parcial(self, J=31, frac_pub=0.5):
        d = DAG(k=self.k, u2=True, u3_mode=self.u3_mode,
                max_parents=self.mp, mergeset_limit=self.msl)
        g = d.genesis()
        llega = {g: 0.0}
        priv = []
        self.n_rafagas = self.n_intentos = self.n_bloques_priv = self.n_rechazados = 0
        self.n_publicados = 0
        self.n_cambios = 0          # veces que la publicacion parcial SI gano al sp honesto
        self.adv_traza = []
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
            sp_h = d.virtual_sp(visibles)
            if not priv:
                self.n_intentos += 1
            ph = self._padres(d, visibles)
            padres = ([priv[-1]] + [x for x in ph if x != priv[-1]][:self.mp - 1]) if priv \
                else ph[:self.mp]
            bid = f"a{i}"
            ok, motivo = d.add(bid, padres, t=t, creator="a", ident=ident, sd=sd, seed=sde)
            if not ok:
                self.n_rechazados += 1
                continue
            priv.append(bid)
            self.n_bloques_priv += 1
            self.adv_traza.append((t, d.gd[priv[-1]].blue_work - d.gd[sp_h].blue_work))
            tip_p = max(priv, key=d._key)
            if len(priv) >= J and d._key(tip_p) > d._key(sp_h):
                n_pub = max(1, int(round(frac_pub * len(priv))))
                soltar, quedan = priv[:n_pub], priv[n_pub:]
                for b in soltar:
                    llega[b] = t
                self.n_publicados += len(soltar)
                self.n_rafagas += 1
                self.tam_rafagas.append(len(soltar))
                # se la red cambia de cadena? el ultimo publicado debe ganar al sp honesto
                if d._key(soltar[-1]) > d._key(sp_h):
                    self.n_cambios += 1
                priv = quedan
        tip = d.virtual_sp([h for h in llega])
        self.adv_max = max((a for _, a in self.adv_traza), default=0)
        self.adv_fin = (d.gd[priv[-1]].blue_work - d.gd[tip].blue_work) if priv else 0
        return d, tip, llega
