#!/usr/bin/env python3
"""
r10c_lib.py — instrumento compartido de la ronda 10c (D9).

NO se reescribe ningun modelo: `prev`, `delta_interp` y `union10` se IMPORTAN del instrumento
de 9a (`research/scripts/d9-ronda9a/r9a_a3_frontera.py`), que a su vez reusa literalmente
`research/scripts/verif_constantes.py:44-50` y `d8-ronda8/d8_a1c_riesgo.py:29-40`.

Lo unico nuevo aqui es (i) la cinematica del frente de conocimiento del PoT bajo R-FIN-14
(punto A) y (ii) la aritmetica de la ventana de prediccion (punto B).
"""
import sys, os

RAIZ = "/home/katana/zeo/ZEROX"
sys.path.insert(0, os.path.join(RAIZ, "research/scripts/d9-ronda9a"))
import r9a_a3_frontera as A9  # noqa: E402  (prev, delta_interp, union10, frontera, K, C)

prev = A9.prev
delta_interp = A9.delta_interp

# ---------------------------------------------------------------- constantes del diseno vigente
K = A9.K                      # 30, GHOSTDAG
LAM = 1.0                     # bloques/s (variante A'', q = 1)
VENTAJA = 3 * K               # cota 3k del Lema 10 (freeloading)
W_DEC = 45.0                  # s, ventana de decision del ancla MEDIDA (9c C.2, peor alpha = 0,40)
W_DEC_33 = 20.0               # s, la medida para alpha <= 0,33
D_AUT = 4.0                   # s, retardo de autoria (BLOCK_AUTHORING_DELAY de Autonomys)
T_PLOT = {"GTX1070_medido": 69.363, "GPU_tope_ALU": 4.28, "GPU_tope_BW": 9.92, "CPU32": 83.608}
A_ESTRELLA_H = {"A": 63.0, "B": 41.0, "C": 69.0}          # h, punto de equilibrio del ploteo dirigido
A_ESTRELLA_10X_H = {k: v / 10.0 for k, v in A_ESTRELLA_H.items()}   # con plotter 10x sobre el extrapolado


def union10(alpha, hf, F_seg, I_seg):
    """Union a 10 anos con el `prev` de 9a, parametrizada en F e I (9a los tiene globales)."""
    A9.F_SEG = float(F_seg)
    A9.I_EP = float(I_seg)
    A9.EP_ANO = 365 * 24 * 3600 / A9.I_EP
    return A9.union10(alpha, hf)


def hf_delta0(alpha):
    """Modelo corregido de 9a: delta = 0 (atacante unico, presupuestos disjuntos)."""
    return 1.0


def hf_d8(alpha):
    """Modelo pesimista: delta(alpha) MEDIDO por D8, interpolado (auditoria 7)."""
    return 1.0 - delta_interp(alpha)


# ------------------------------------------------- A · frente de conocimiento del PoT (R-FIN-14)
def tope_conocimiento(F_seg, I_seg, w_dec, retardada):
    """Cota SUPERIOR del lookahead en slots, en el peor instante del diente de sierra.

    Nucleo (R-FIN-14 a-g): en el instante u el atacante conoce `entropia_j` de toda epoca cuya
    ancla este cerrada (T_j + w_dec <= u); esa inyeccion surte efecto en t_j ~ T_j + F, luego la
    ultima que conoce cumple t_j <= u + F - w_dec, y puede encadenar AES hasta t_{j+1} - 1.
    Opcion (h) (revelacion retardada): `entropia_j` no existe hasta t_j, luego t_j <= u.
    """
    base = 0.0 if retardada else (F_seg - w_dec)
    return base + I_seg          # peor instante del diente de sierra


def tope_conocimiento_medio(F_seg, I_seg, w_dec, retardada):
    """Media del diente de sierra: la cota cae linealmente de tope a tope - I entre inyecciones."""
    return tope_conocimiento(F_seg, I_seg, w_dec, retardada) - I_seg / 2.0


def lookahead(rho, F_seg, I_seg, w_dec, retardada, t_desde_inicio=None):
    """Lookahead REAL = min(tope de conocimiento, ventaja de computo acumulada).

    La cadena de PoT es AES-128 secuencial: el atacante avanza `rho` slots por segundo y la
    cadena canonica 1 slot/s, luego gana (rho - 1) slots por segundo. Con rho <= 1 no gana
    ninguno y su lookahead se queda donde estaba (0 si empieza en 0).
    """
    tope = tope_conocimiento(F_seg, I_seg, w_dec, retardada)
    if rho <= 1.0:
        return 0.0
    if t_desde_inicio is None:
        return tope
    return min(tope, (rho - 1.0) * t_desde_inicio)


def bootstrap(rho, F_seg, I_seg, w_dec, retardada):
    """Segundos de reloj hasta saturar el tope. Infinito si rho <= 1."""
    if rho <= 1.0:
        return float("inf")
    return tope_conocimiento(F_seg, I_seg, w_dec, retardada) / (rho - 1.0)


# ------------------------------------------------------------------- B · ventana de prediccion
def w_sobre_kappa(look_seg, F_seg):
    """BDK Def. 6: W y kappa en BLOQUES. kappa = F * lambda; W = lookahead * lambda."""
    return (look_seg * LAM) / (F_seg * LAM)


def F_de_la_pinza(I_seg, w_dec, tope_wk, retardada):
    """F minima que impone la pinza si se exige W/kappa <= tope_wk con el lookahead del nucleo.

    Nucleo: W/kappa = (F + I - w_dec)/F = 1 + (I - w_dec)/F  =>  F >= (I - w_dec)/(tope_wk - 1).
    (h): W = I, independiente de F  =>  F >= I/tope_wk.
    """
    if retardada:
        return I_seg / tope_wk
    if tope_wk <= 1.0:
        return float("inf")
    return max(0.0, (I_seg - w_dec)) / (tope_wk - 1.0)


# =============================================================================================
# AMPLIACION (ronda 10c, tras releer 9c E1 y R-FIN-14 (a)-(h)).
#
# CORRECCION DE MI PROPIO ESBOZO (declarada en el informe, seccion "Errores propios"):
# `tope_conocimiento(..., retardada=True)` devolvia `I` con independencia de `rho`. Es una cota
# superior valida (rho -> infinito) pero NO es la cota. Bajo (h) la cadena de PoT del atacante se
# BLOQUEA en cada inyeccion hasta `t_j` (la entropia no existe antes), luego reencaja desde cero
# cada epoca y su adelanto maximo es `I*(1 - 1/rho)`, no `I`. La forma correcta esta abajo
# (`cinematica`), y es la que usan A, B y D.
# =============================================================================================

# `W_dec` MEDIDA por 9c (r9c_c4_wdec.py, salida_c4.txt; 12 semillas, union de las dos vias, MAXIMO).
# Es funcion de alpha: el criterio alpha entra en el punto A por aqui.
W_DEC_MED = {0.00: -1.0, 0.10: 10.0, 0.25: 20.0, 0.33: 20.0, 0.40: 45.0}


def w_dec_de(alpha):
    """W_dec(alpha) medida por 9c, interpolada linealmente (peor caso = maximo de las dos vias)."""
    xs = sorted(W_DEC_MED)
    if alpha <= xs[0]:
        return W_DEC_MED[xs[0]]
    if alpha >= xs[-1]:
        return W_DEC_MED[xs[-1]]
    for i in range(len(xs) - 1):
        if xs[i] <= alpha <= xs[i + 1]:
            w = (alpha - xs[i]) / (xs[i + 1] - xs[i])
            return W_DEC_MED[xs[i]] + w * (W_DEC_MED[xs[i + 1]] - W_DEC_MED[xs[i]])


def cinematica(rho, L_seg, I_seg, w_dec, retardada, horizonte_s, dt=1.0, delta_ancla=0.0):
    """Simula la posicion de la cadena de PoT del atacante slot a slot. NO usa forma cerrada.

    Modelo, literal de R-FIN-14:
      · el atacante calcula AES a `rho` slots por segundo de reloj; la cadena canonica, a 1.
      · para pasar del slot `t_j` necesita `entropia_j`; sin ella su cadena se para en `t_j - 1`.
      · NUCLEO: conoce `entropia_j` en el instante `T_j + w_dec` (ancla cerrada, 9c C.0), y esa
        entropia se aplica en `t_j = slot(I_j) + L = T_j + delta_ancla + L`.
      · (h) REVELACION RETARDADA: `entropia_j` no existe hasta `t_j`; la conoce en `t_j`.
    Devuelve (max, media, p50, bootstrap_s) del adelanto = posicion_PoT - reloj, en regimen.
    """
    import numpy as _np
    pos = 0.0                      # slot al que ha llegado su cadena de PoT
    us = _np.arange(0.0, horizonte_s, dt)
    ad = _np.empty(len(us))
    boot = float("nan")
    for i, u in enumerate(us):
        # ultima inyeccion cuya entropia conoce en el instante u
        if retardada:
            # t_j = T_j + delta_ancla + L ; la conoce en t_j
            j = math.floor((u - delta_ancla - L_seg) / I_seg)
        else:
            j = math.floor((u - w_dec) / I_seg)
        if j < 0:
            frontera = float("inf")          # antes de la primera inyeccion nada le para
        else:
            t_next = (j + 1) * I_seg + delta_ancla + L_seg
            frontera = t_next - 1.0          # puede llegar como mucho a t_{j+1} - 1
        pos = min(pos + rho * dt, frontera)
        pos = max(pos, u)                     # nunca por detras de la cadena canonica (la ve publicada)
        ad[i] = pos - u
        if math.isnan(boot) and i > 0 and ad[i] <= ad[i - 1] and ad[i] > 1.0:
            boot = u                          # primer instante en que deja de crecer: saturo
    n0 = len(us) // 2                          # regimen: segunda mitad del horizonte
    reg = ad[n0:]
    return float(reg.max()), float(reg.mean()), float(_np.median(reg)), boot


def espacio_fabricado_gib(look_seg, t_plot_s):
    """Sectores de 1 GiB que una GPU puede fabricar Y PROBAR contra los retos que conoce."""
    return look_seg / t_plot_s


def margen_sembrador(look_seg, a_estrella_h):
    """Margen frente al punto de equilibrio del ploteo dirigido A* (ronda 7 §1)."""
    if look_seg <= 0:
        return float("inf")
    return a_estrella_h * 3600.0 / look_seg


import math  # noqa: E402  (usado por cinematica/w_dec_de)


def cinematica_rapida(rho, L_seg, I_seg, w_dec, retardada, n_epocas=None, delta_ancla=0.0):
    """Integrador EXACTO por epocas de la misma cinematica que `cinematica`.

    Dentro de una ventana de inyeccion la dinamica es lineal a trozos, asi que no hace falta
    recorrer segundo a segundo: basta resolver el corte entre la recta del atacante (pendiente
    rho - 1) y la del tope de conocimiento (pendiente -1, porque el tope es un slot fijo y el
    reloj avanza). Se valida contra `cinematica` en r10c_a1 (error < 1 slot).

    Ventana del NUCLEO: empieza en u = T_j + w_dec (instante en que conoce `entropia_j`) y el
    tope es t_{j+1} - 1 = T_j + I + delta_ancla + L - 1, luego el adelanto del tope al empezar la
    ventana es `cap = I + delta_ancla + L - 1 - w_dec` y decae 1/s durante I s.
    Ventana de (h): empieza en u = t_j y el tope es t_{j+1} - 1, luego `cap = I - 1`.
    """
    cap = (I_seg + delta_ancla + L_seg - 1.0 - w_dec) if not retardada else (I_seg - 1.0)
    if rho <= 1.0:
        # no gana un solo slot sobre la cadena canonica; parte de 0 y ahi se queda
        return 0.0, 0.0, float("nan")
    if n_epocas is None:
        # epocas suficientes para SATURAR con holgura x3 (si no, se mide el transitorio y la
        # forma cerrada parece fallar: error propio detectado en la primera pasada de A1)
        n_epocas = int(3.0 * cap / max(1e-12, (rho - 1.0) * I_seg)) + 400
        n_epocas = min(n_epocas, 4_000_000)
    a = 0.0
    boot = float("nan")
    ult = []
    for e in range(n_epocas):
        if a >= cap:                      # ya pinchado en el tope: decae con el reloj
            mx = cap
            med = cap - I_seg / 2.0
            a = max(0.0, cap - I_seg)
        else:
            tcorte = (cap - a) / rho      # (rho-1)*t + a == cap - t  =>  t = (cap-a)/rho
            if tcorte >= I_seg:
                mx = a + (rho - 1.0) * I_seg
                med = a + (rho - 1.0) * I_seg / 2.0
                a = mx                    # no llego al tope; sigue creciendo
            else:
                mx = a + (rho - 1.0) * tcorte
                # media temporal exacta de la ventana: rampa hasta t*, luego el tope decayendo
                ar = a * tcorte + (rho - 1.0) * tcorte * tcorte / 2.0
                ad = cap * (I_seg - tcorte) - (I_seg * I_seg - tcorte * tcorte) / 2.0
                med = (ar + ad) / I_seg
                a = max(0.0, cap - I_seg)
                if math.isnan(boot):
                    boot = (e + tcorte / I_seg) * I_seg
        ult.append((mx, med))
    reg = ult[len(ult) // 2:]
    return max(x[0] for x in reg), sum(x[1] for x in reg) / len(reg), boot
