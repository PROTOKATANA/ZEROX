#!/usr/bin/env python3
"""
D8 ronda 10a — libreria comun.

Contiene UNA sola pieza no trivial: `frontera_pot`, la recursion de la FRONTERA de PoT del
atacante (el mayor slot de la cadena de PoT cuya `salida` conoce) frente al tiempo real, con
las barreras de inyeccion de R-FIN-2/14. Todo lo demas son constantes medidas por otras rondas
y utilidades de interpolacion.

La recursion, escrita entera para poder auditarla:

  s_j  = slot(I_j) = T_j + off_j                 (R-FIN-1, off_j in [0, S_max))
  t_j  = s_j + L                                  (R-FIN-2: instante de la inyeccion j)

  El atacante corre `rho` slots de AES por segundo de pared (el timekeeper honesto, 1).
  Para pasar la barrera t_j necesita DOS cosas:
    (1) haber llegado con su cadena comun al slot t_j - 1, y
    (2) tener `entropia_j`.

  Cuando dispone de `entropia_j` depende de DOS decisiones independientes:

    con_h = False   (R-FIN-2 tal cual)  entropia_j = blake3(chunk(I_j) || salida(f, s_j))
                    -> la tiene en cuanto (a) conoce el bloque ancla y (b) su frontera paso s_j.
                       Si el ancla es honesta, el bloque no existe antes de su slot: E >= s_j,
                       y ademas el ancla no esta decidida antes de T_j + W_dec.
    con_h = True    (opcion (h))        entropia_j = VDF(chunk(I_j) || salida(f, s_j), Lrev*iter)
                    -> lo anterior MAS `Lrev / rho` segundos de reloj propio.

    propio_j        si el ancla de la epoca j es un bloque SUYO, no tiene que esperar a que
                    exista: la fabrica en cuanto su frontera pasa s_j (conoce el reto de ese
                    slot antes que nadie). Es la rama que decide todo el punto B.1.

  De ahi:  paso_j = max( llegada_j , E_j )   con   llegada_j = paso_{j-1} + (t_j - t_{j-1})/rho

El instante de decision del ancla de la epoca j es D_j = T_j + W_dec(alpha) (9c §C).
`n_eval` = slots de la rama post-inyeccion que el atacante alcanza a evaluar antes de D_j.
"""
import math
import os
import sys

_D8C = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "d9-ronda8c"))
if _D8C not in sys.path:
    sys.path.insert(0, _D8C)
from r8c_steering import c_interp                          # noqa: E402  (c_m de la ronda 4)

# --- constantes del diseno vigente (research/dag-poas-ancla-de-orden.md §2) ---
S_MAX = 150.0          # R-FIN-1a, segundos
LAM = 1.0              # lambda = 1 bloque/s (rama A'')
LAM_CADENA = 0.2       # bloques de CADENA SELECCIONADA por segundo (D9 ronda 1)
K = 30                 # R-FIN-13
PROVE_S = 1.561        # s/slot medidos, 9950X3D (ancla-de-orden.md, "Coste del PoT, MEDIDO")
VERIFY_S = 0.0961      # s/slot medidos, misma fuente
N_CHECKPOINTS = 8      # subspace-core-primitives/src/pot.rs:332
POT_BYTES_SLOT = 128   # 8 checkpoints x 16 B (pot.rs:328,332 + PotOutput::SIZE = 16)

# W_dec MEDIDA por 9c (r9c_c4_wdec.py / salida_c4.txt): maximo de la union de las dos vias.
# alpha = 0 -> -1 significa "no hay ninguna decision que tomar": no hay steering posible.
W_DEC_MED = {0.00: -1.0, 0.10: 10.0, 0.25: 20.0, 0.33: 20.0, 0.40: 45.0}
# menu m(d = 10 s) medido por 9c, mismo fichero
M_MED = {0.00: 1.00, 0.10: 1.17, 0.25: 1.42, 0.33: 1.58, 0.40: 1.83}

# Contadores de cobertura de rama (regla de metodo 5). Globales al proceso.
COB = {
    "ancla_propia": 0,       # la epoca la ancla un bloque del atacante
    "ancla_honesta": 0,
    "bloqueado_entropia": 0,  # la barrera t_j la impuso E_j, no la llegada
    "bloqueado_llegada": 0,   # la barrera t_j la impuso la velocidad de su cadena comun
    "steer_propio": 0,        # n_eval >= 1 evaluando SU candidato
    "steer_honesto": 0,       # n_eval >= 1 evaluando un candidato honesto
    "sin_steer": 0,
}


def _interp(tabla, x):
    xs = sorted(tabla)
    if x <= xs[0]:
        return tabla[xs[0]]
    for a, b in zip(xs, xs[1:]):
        if x <= b:
            f = (x - a) / (b - a)
            return tabla[a] + f * (tabla[b] - tabla[a])
    return tabla[xs[-1]]


def w_dec(alpha):
    """Ventana de decision del ancla, en segundos, MEDIDA por 9c e interpolada."""
    return _interp(W_DEC_MED, alpha)


def menu(alpha):
    """Tamano del menu de anclas m(alpha) a d = 10 s, MEDIDO por 9c e interpolado."""
    return _interp(M_MED, alpha)


def frontera_pot(L, I, rho, alpha, con_h, semilla, n_ep=600, Lrev=None,
                 p_propia=None, modo_off="geom", cuenta_cobertura=True, boot_obj=None):
    """Simula n_ep epocas de la recursion de arriba.

    Devuelve un dict con, por epoca en regimen (se descarta el primer 20 % de transitorio):
      'frac_propio'  fraccion de epocas en que evalua >= 1 slot de SU candidato
      'frac_honesto' idem con un candidato honesto (necesita `entropia` de un bloque ajeno)
      'nev_propio'   media de n_eval sobre las epocas con ancla propia evaluable
      'nev_honesto'  idem honesto
      'vent_pico'    ventaja maxima (slots de PoT por delante del timekeeper) en regimen
      'boot90'       instante real en que la ventaja alcanza `boot_obj` (por defecto, el 90 %
                     de su tope): es el *bootstrap* que 9c estimo como `tope/(rho-1)`
      'vent_media'   ventaja media al llegar a la barrera

    `Lrev` = longitud en slots del VDF de revelacion (por defecto L; ver A.1: acortarlo a
    L - W_dec es la contramedida barata del punto B.3).
    `p_propia` = probabilidad de que el ancla de la epoca sea un bloque del atacante; por
    defecto `alpha` (el primer bloque de cadena tras T_j es suyo con esa probabilidad).
    """
    import random
    rng = random.Random(semilla)
    W = w_dec(alpha)
    if Lrev is None:
        Lrev = L
    if p_propia is None:
        p_propia = alpha

    # offsets slot(I_j) - T_j
    if modo_off == "cero":
        off = [0.0] * (n_ep + 2)
    elif modo_off == "unif":
        off = [rng.uniform(0.0, S_MAX) for _ in range(n_ep + 2)]
    else:
        off = [min(rng.expovariate(LAM_CADENA), S_MAX - 1e-9) for _ in range(n_ep + 2)]
    propia = [rng.random() < p_propia for _ in range(n_ep + 2)]

    s = [j * I + off[j] for j in range(n_ep + 2)]         # slot(I_j)
    t = [s[j] + L for j in range(n_ep + 2)]               # t_j

    paso = [0.0] * (n_ep + 2)     # instante real en que su frontera pasa la barrera t_j
    paso[0] = t[0]                # arranca alineado con los honestos: ventaja 0
    ini = max(1, n_ep // 5)
    hist_v = []
    res = {"frac_propio": 0.0, "frac_honesto": 0.0, "nev_propio": [], "nev_honesto": [],
           "vent_pico": 0.0, "vent_media": [], "g_medio": [], "boot90": float("nan")}
    n_pro = n_hon = 0
    cm = c_interp(menu(alpha))
    ingreso = alpha * LAM * I

    def frontera_en(slot_obj, j):
        """Instante real en que su cadena comun alcanza `slot_obj` (<= t_j), sabiendo que
        la ultima barrera pasada es la mayor t_i <= slot_obj."""
        i = j
        while i > 0 and t[i] > slot_obj:
            i -= 1
        return paso[i] + (slot_obj - t[i]) / rho

    for j in range(1, n_ep + 1):
        Tj = j * I
        D = Tj + W                                   # instante de decidir el ancla
        f_sj = frontera_en(s[j], j - 1)              # su frontera llega al slot s_j
        # --- disponibilidad de entropia_j en las dos ramas de autoria del ancla ---
        arr_pro = f_sj                               # ancla propia: la fabrica el mismo
        arr_hon = max(s[j], f_sj)                    # ancla honesta: el bloque no existe antes
        # Adversario del paper (regla de metodo 8): especula sobre TODOS los candidatos, no
        # espera a que la red decida el ancla. Sin (h) la entropia es un blake3: la tiene en
        # cuanto existe el bloque y su frontera paso s_j. Con (h), ademas, Lrev/rho de reloj.
        coste_vdf = Lrev / rho if con_h else 0.0
        E_pro = arr_pro + coste_vdf
        E_hon = arr_hon + coste_vdf
        E = E_pro if propia[j] else E_hon
        llegada = paso[j - 1] + (t[j] - t[j - 1]) / rho
        paso[j] = max(llegada, E)
        if cuenta_cobertura:
            COB["ancla_propia" if propia[j] else "ancla_honesta"] += 1
            COB["bloqueado_entropia" if E > llegada else "bloqueado_llegada"] += 1

        # ventaja (lookahead) al llegar a la barrera t_j, antes de que la barrera la recorte
        v = t[j] - llegada
        res["vent_pico"] = max(res["vent_pico"], v)
        res["vent_media"].append(v)
        hist_v.append((llegada, v))
        if j < ini:
            continue
        if W < 0:                       # alpha = 0: no hay ancla que elegir, no hay steering
            continue
        # cadena comun hasta t_j - 1 (no necesita entropia_j)
        C = paso[j - 1] + (t[j] - 1.0 - t[j - 1]) / rho
        # n_eval se topa en I: evaluar mas alla de la epoca no compra nada, porque en T_{j+1}
        # hay ancla nueva (9c §E.3: `rho >= I/W_dec` ya evalua la epoca entera).
        nev_pro = min(I, rho * (D - max(C, E_pro)))
        nev_hon = min(I, rho * (D - max(C, E_hon)))
        res["nev_propio"].append(max(0.0, nev_pro))
        res["nev_honesto"].append(max(0.0, nev_hon))
        # ganancia de steering de ESTA epoca (ronda 4, verificada por 9c §D.1)
        nev = max(0.0, max(nev_pro, nev_hon))
        res["g_medio"].append(cm * math.sqrt(alpha * LAM * nev) / ingreso if ingreso > 0 else 0.0)
        n_pro += 1 if nev_pro >= 1.0 else 0
        n_hon += 1 if nev_hon >= 1.0 else 0
        if cuenta_cobertura:
            if nev_hon >= 1.0:
                COB["steer_honesto"] += 1
            elif nev_pro >= 1.0:
                COB["steer_propio"] += 1
            else:
                COB["sin_steer"] += 1

    if hist_v:
        objetivo = boot_obj if boot_obj is not None else 0.90 * max(v for _, v in hist_v)
        for inst, v in hist_v:
            if v >= objetivo:
                res["boot90"] = inst - paso[0]   # origen: el instante en que arranca con ventaja 0
                break
    n = max(1, len(res["nev_propio"]))
    res["frac_propio"] = n_pro / n
    res["frac_honesto"] = n_hon / n
    for clave in ("nev_propio", "nev_honesto", "vent_media", "g_medio"):
        v = res[clave]
        res[clave] = sum(v) / len(v) if v else 0.0
    return res


# ---- formas cerradas derivadas en el informe (§B.1), para contrastar con la simulacion ----

def rho_cadena_comun(L, I, W, off=0.0, Lrev=None):
    """rho minimo para tener la cadena comun hasta t_j - 1 en T_j + W_dec, CON (h).
    Regimen: la barrera anterior lo bloqueo, luego llega con ventaja (Lrev, I)."""
    if Lrev is None:
        Lrev = L
    den = I + W - off
    return float("inf") if den <= 0 else (Lrev + I) / den


def rho_entropia_propia(L, I, W, off=0.0, Lrev=None):
    """rho minimo para tener `entropia` de SU PROPIO candidato en T_j + W_dec, CON (h).
    q = ceil(L/I) barreras pendientes; su frontera paso s_j hace q*I*(1-1/rho) slots."""
    if Lrev is None:
        Lrev = L
    q = math.ceil(L / I)
    den = q * I + W - off
    return float("inf") if den <= 0 else (Lrev + q * I) / den


def rho_entropia_honesta(L, W, off=0.0, Lrev=None):
    """rho minimo para tener `entropia` de un candidato AJENO en T_j + W_dec, CON (h).
    Es la cota que el encargo cita como `rho >= L/W_dec`."""
    if Lrev is None:
        Lrev = L
    den = W - off
    return float("inf") if den <= 0 else Lrev / den


def ventaja_pico(L, I, rho, W, con_h, off=0.0, Lrev=None):
    """Ventaja maxima en regimen, en slots de PoT (§B.6). `W` queda como parametro por
    simetria con el resto de la libreria: NO entra, y eso es parte del resultado (el atacante
    especula sobre los candidatos, no espera a que la red decida el ancla).
      con (h) y ancla honesta : (Lrev + I)(1 - 1/rho)     -> 0 si rho = 1  [ronda 7]
      sin (h) y ancla honesta : L + I(1 - 1/rho)                            [ronda 7]
    9c escribio la segunda como `L + I - W_dec`: es el limite rho -> inf menos W_dec, porque
    9c suponia que el atacante esperaba a ver el ancla decidida."""
    del W
    if Lrev is None:
        Lrev = L
    if rho <= 0:
        return 0.0
    tope = L - Lrev / rho if con_h else L + off
    return max(0.0, tope) + I * (1.0 - 1.0 / rho)


def n_rachas(L, I, rho, W, off=0.0):
    """Numero MINIMO de epocas consecutivas con ancla del atacante (mas la que se esta
    decidiendo) para que su ventaja alcance el umbral de steering `L - W + off`, CON (h).

      ventaja con r anclas propias seguidas = (L + (r+1)*I)(1 - 1/rho)
      steering  <=>  (L + (r+1)*I)(1 - 1/rho) >= L - W + off

    De ahi `n* = ceil( ((L - W + off)*rho/(rho-1) - L) / I )`: hacen falta `n* - 1` anclas
    propias consecutivas antes de la epoca que se decide. Como cada ancla es del atacante con
    probabilidad `alpha` e independiente, la tasa de epocas con steering es `alpha^(n*-1)`.
    Con `n* <= 1` el steering es de todas las epocas (rho >= rho*)."""
    if rho <= 1.0:
        return float("inf")
    n = ((L - W + off) * rho / (rho - 1.0) - L) / I
    return max(1.0, float(math.ceil(n)))


def tasa_rachas(L, I, rho, alpha, W=None, off=0.0):
    """Fraccion de epocas con steering por rachas de ancla propia. 0 si alpha = 0."""
    if W is None:
        W = w_dec(alpha)
    if W < 0 or alpha <= 0.0:
        return 0.0
    n = n_rachas(L, I, rho, W, off)
    if math.isinf(n):
        return 0.0
    return alpha ** (n - 1.0)
