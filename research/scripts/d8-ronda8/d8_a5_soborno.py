#!/usr/bin/env python3
"""
d8_a5_soborno.py — A5 · EL ATAQUE DE SOBORNO DE BDK+19 §2, PORTADO A PoAS.

Lo que dice el paper (`research/fuentes/bdk19.txt` L284-296, literal):
  «If the prediction window W is greater than the confirmation-depth kappa, then the
   following covert (undetectable) attack becomes possible ... If the adversary gets more
   than kappa+1 miners to respond to this request ... (5) create a longer chain downstream
   of a block including the double-spend using the kappa+1 certificates ... it only
   requires kappa+1 out of the next 2*kappa miners each holding a potentially infinitesimal
   fraction of stake.»

**Por que la aritmetica NO porta a PoAS (y esto es la mitad del resultado).** En Ouroboros
cada slot tiene UN lider: con kappa+1 de los proximos 2*kappa+1 slots, la cadena honesta solo
puede tener kappa bloques y la bifurcacion sobornada es MAS LARGA por construccion. En PoAS
ganar es un proceso de Poisson sobre el espacio: sobornar una fraccion `beta` da tasa
`beta*lambda` y los NO sobornados siguen produciendo a `(1-beta)*lambda`. No hay calendario
exclusivo que vaciar. Para superar la cadena honesta hace falta `beta` por encima del umbral
del sistema (35-40 %), no `kappa+1` granjeros infinitesimales.

**Lo que SI compra la ventana de prediccion: el ANCLA.** R-FIN-1 lee `I_j` = el bloque de
cadena con menor `blue_work` entre los de `slot >= T_j`. Los ganadores se conocen `L = F` por
adelantado (R-FIN-2), asi que el sobornador sabe, con 5,3 h de antelacion, QUE granjeros van
a producir los pocos bloques del cruce, y puede pagarles por RETENER (no por equivocar: no hay
doble firma, la negabilidad de BDK se conserva intacta). Cada retencion mueve el ancla al
siguiente candidato.

MEDIDA: `m_soborno(b)` = anclas distintas alcanzables sobornando hasta `b` bloques HONESTOS
del cruce, frente a la `m = 2,54` que D9-f midio con el atacante produciendo sus propios
bloques. Y el balance economico:
    valor del steering  =  c_m * sqrt(alpha*lambda*I)   bloques de recompensa por epoca
                           (dag-poas-voto-auditoria.md L197-199, el modelo del propio diseno)
    coste del soborno   >= b bloques de recompensa (lo que pierde cada sobornado)

CRITERIO ALPHA (regla 1): `alpha` entra por el valor del steering Y porque el sobornador
tambien puede usar sus propios bloques; se imprime la fila alpha=0 (sobornador SIN espacio
propio: `m_soborno` sigue siendo > 1 — ese es justamente el resultado).
CAPACIDAD (regla 4): `b=0` debe dar `m=1` (sin soborno no hay menu). Si no, el instrumento
esta contando ruido.
"""
import math
import sys
import time

sys.path.insert(0, "/home/katana/zeo/ZEROX/research/scripts/d9-ronda8f")
from r8f_lib import Mundo, perfil, ancla_slot_T, slot_de, K, MP           # noqa: E402
from r8c_gd import DAG                                                    # noqa: E402
from r8c_sim import DELTA                                                 # noqa: E402
from r8c_steering import c_interp                                         # noqa: E402

SEMS = list(range(1, 13))
ALPHAS = [0.0, 0.10, 0.25, 0.33, 0.40]
BS = [0, 1, 2, 3, 5, 8]
HOR = 400.0
P = 30
BANDA = 10
I_EPOCA = 4200.0          # constante del diseno
LAM = 1.0


class MundoSoborno(Mundo):
    """Igual que `Mundo`, pero la estrategia puede retener bloques HONESTOS: son los
    granjeros sobornados. Un sobornado NO equivoca (no publica dos bloques con el mismo
    billete): simplemente no publica. Es exactamente la negabilidad de BDK+19 L299-301."""

    def corre_sob(self, sobornados=frozenset(), copias=0):
        d = DAG(k=self.k, u2=True, u3_mode=self.u3_mode,
                max_parents=self.mp, mergeset_limit=self.msl)
        g = d.genesis()
        llega = {g: 0.0}
        n_sob = 0
        for i, (t, quien, sd, sde, ident) in enumerate(self.ev):
            visibles = [h for h, ta in llega.items() if ta <= t]
            if i in sobornados:
                n_sob += 1
                continue                          # el granjero sobornado NO publica
            padres = self._padres(d, visibles)
            bid = f"b{i}"
            ok, _ = d.add(bid, padres, t=t, creator=quien, ident=ident, sd=sd, seed=sde)
            if ok:
                llega[bid] = t + (DELTA if quien == "h" else 0.0)
        tip = d.virtual_sp([h for h in llega])
        return d, tip, n_sob


def menu_soborno(alpha, sem, b):
    """Anclas distintas alcanzables sobornando hasta `b` bloques. El sobornador elige el
    subconjunto: se explora RETENIENDO los `j` primeros candidatos del cruce, j = 0..b
    (es la eleccion optima: para mover el ancla hay que retirar a los que van delante)."""
    mundo = MundoSoborno(alpha, HOR, sem, k=K, mp=MP, u3_mode="dynamic")
    d0, tip0, _ = mundo.corre_sob()
    ch0 = d0.selected_chain(tip0)
    if P >= len(ch0):
        return None
    tP = d0.B[ch0[P]].t
    Ss = [slot_de(tP + u, 1.0) for u in range(-BANDA, BANDA + 1)]
    ac = {S: set() for S in Ss}
    coste = {S: 0 for S in Ss}
    for S in Ss:
        sob = set()
        for j in range(b + 1):
            d, tip, ns = mundo.corre_sob(frozenset(sob))
            pf = perfil(d, tip, gran=1.0)
            s, idx = ancla_slot_T(pf, S)
            if s is None:
                break
            ac[S].add(s)
            coste[S] = j
            # sobornar al granjero de ESE bloque: se busca su indice de evento
            bid = pf[idx][3]
            try:
                sob.add(int(bid[1:].split("c")[0]))
            except ValueError:
                break
    ms = [len(ac[S]) for S in Ss]
    return sum(ms) / len(ms), max(ms)


if __name__ == "__main__":
    print("=== A5 · soborno BDK+19 §2 portado a PoAS: que compra la ventana de prediccion ===")
    print(f"k={K}, mp={MP}, lambda=1, Delta=4, u3=dynamic, horizonte {HOR:.0f} s, "
          f"{len(SEMS)} semillas, 21 umbrales, ancla por `slot`.")
    print("Un granjero sobornado RETIENE su bloque (no equivoca): negabilidad de BDK intacta.")
    print("Referencia: D9-f midio m_SLOT = 2,540 con el atacante produciendo SUS bloques "
          "(alpha=0,25, copias=14).\n")
    t0 = time.time()
    print(f"{'alpha':>6} | " + " ".join(f"{'b='+str(b):>9}" for b in BS))
    print("-" * (9 + 10 * len(BS)))
    tabla = {}
    for alpha in ALPHAS:
        fila = []
        for b in BS:
            rs = [menu_soborno(alpha, s, b) for s in SEMS]
            rs = [r for r in rs if r]
            v = sum(r[0] for r in rs) / max(len(rs), 1)
            fila.append(v)
        tabla[alpha] = fila
        print(f"{alpha:>6.2f} | " + " ".join(f"{v:>9.3f}" for v in fila))

    print("\n--- balance economico del steering sobornado, por epoca (I = 4 200 s) ---")
    print("valor = c_m * sqrt(alpha*lambda*I) bloques   (dag-poas-voto-auditoria.md L197-199)")
    print("coste >= b bloques (lo que pierde cada granjero sobornado)")
    print(f"{'alpha':>6} {'b':>4} {'m':>8} {'c_m':>8} {'valor (bloques)':>16} "
          f"{'coste':>7} {'valor/coste':>12}")
    for alpha in ALPHAS:
        if alpha == 0:
            print(f"{alpha:>6.2f}    - {'':>8} {'':>8} {'0 (sin espacio propio no hay '
                  'ingreso que optimizar; el soborno solo compra CENSURA)':>16}")
            continue
        for b, m in zip(BS, tabla[alpha]):
            if b == 0:
                continue
            cm = c_interp(m)
            val = cm * math.sqrt(alpha * LAM * I_EPOCA)
            print(f"{alpha:>6.2f} {b:>4} {m:>8.3f} {cm:>8.4f} {val:>16.1f} "
                  f"{b:>7} {val/b:>12.1f}")
    print(f"\n[{time.time()-t0:.0f} s]")
