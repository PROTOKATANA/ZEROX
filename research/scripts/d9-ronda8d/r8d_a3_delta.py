#!/usr/bin/env python3
"""
r8d_a3_delta.py — LINEA A3. ?Sobrevive el LEMA 9 a U3'' dinamica?

Lema 9 (phantom-ghostdag.txt L1074-1077): «The expected value of wH(t+r) - wH(t) is at
least (1-alpha)(1-delta) r lambda», con delta = 2Dlambda/(k+2Dlambda) = 8/38 = 0,2105
a k=30. `dag-poas-delta-real.md` corrige a delta_real = 0,267 por el sesgo del retarget.

Se mide delta_ef de DOS formas sobre la misma ejecucion:

  delta_hon  = 1 - (bloques HONESTOS que acaban AZULES en la ventana) / ((1-alpha) lambda r)
               Es el dano directo del Lema 9: honestos que el atacante convierte en rojos.
  delta_wH   = 1 - (wH(t2) - wH(t1)) / ((1-alpha) lambda r)
               La magnitud literal del enunciado (wH = score del bloque virtual honesto,
               L1035-1037). Incluye los AZULES DEL ATACANTE, luego puede salir negativa:
               el atacante «regala» score. Se da por fidelidad al enunciado.

Estrategias de copia, las tres refutaciones anteriores:
  none      sin copias (referencia)
  antic-N   D9-c A3: `copias` copias del MISMO billete colgando del ANTICONO del sp
            (politica ('retro', N)) — el contraejemplo que rompio U3'-filtro.
  genuino   billetes genuinos, un bloque por victoria, publicacion inmediata.

Criterio alpha: con alpha=0 no hay atacante y delta_hon debe ser ~0 (huerfanos honestos).
"""
import sys
from r8d_lib import Mundo, wH, llega_de, LAMBDA, DELTA

K, MP = 30, 15
DELTA_NOM, DELTA_REAL = 8 / 38, 0.267


def corrida(alpha, semilla, T, u3_mode, copias, pol, retraso=0.0):
    m = Mundo(alpha, T, semilla, k=K, mp=MP, u3_mode=u3_mode)
    est = {i: (retraso, pol) for i, (t, q, *_) in enumerate(m.ev) if q == "a"}
    d, tip = m.corre(est, copias=copias)
    ll = llega_de(m, d, est, copias)
    t1, t2 = 0.20 * T, 0.95 * T
    r = t2 - t1
    vis1 = [h for h, ta in ll.items() if ta <= t1]
    vis2 = [h for h, ta in ll.items() if ta <= t2]
    w1, w2 = wH(d, vis1, m), wH(d, vis2, m)
    # honestos creados en la ventana que acaban AZULES en la vista honesta final
    azules = d.blueset(tip)
    hon_win = [h for h in d.B if d.B[h].creator == "h" and t1 < d.B[h].t <= t2]
    hon_azul = sum(1 for h in hon_win if h in azules)
    esperados = (1 - alpha) * LAMBDA * r
    d_hon = 1 - hon_azul / esperados if esperados > 0 else float("nan")
    d_wH = 1 - (w2 - w1) / esperados if esperados > 0 else float("nan")
    lam_blue = (w2 - w1) / r
    ch = d.selected_chain(tip)
    lam_chain = (len(ch) - 1) / d.B[ch[-1]].t if d.B[ch[-1]].t > 0 else 0
    return d_hon, d_wH, lam_blue, lam_chain, len(hon_win)


def barrido(escenarios, T=900.0, semillas=range(1, 9)):
    print(f"{'escenario':>26} | {'alpha':>5} | {'delta_hon':>10} {'delta_wH':>9} "
          f"| {'lam_blue':>9} {'lam_chain':>9} | veredicto vs 0,2105 / 0,267")
    for nombre, u3, cop, pol, ret in escenarios:
        for alpha in (0.0, 0.10, 0.25, 0.33, 0.40):
            rs = [corrida(alpha, s, T, u3, cop, pol, ret) for s in semillas]
            dh = sum(r[0] for r in rs) / len(rs)
            dw = sum(r[1] for r in rs) / len(rs)
            lb = sum(r[2] for r in rs) / len(rs)
            lc = sum(r[3] for r in rs) / len(rs)
            v = ("SUPERA 0,267" if dh > DELTA_REAL else
                 "supera 0,2105" if dh > DELTA_NOM else "dentro")
            print(f"{nombre:>26} | {alpha:>5.2f} | {dh:>10.4f} {dw:>9.4f} "
                  f"| {lb:>9.4f} {lc:>9.4f} | {v}")
        print()


if __name__ == "__main__":
    T = float(sys.argv[1]) if len(sys.argv) > 1 else 900.0
    print("=== A3 · delta efectivo del Lema 9, en SIMULACION DE EVENTOS ===")
    print(f"k={K}, mp={MP}, lambda=1, Delta=4, horizonte {T:.0f} s, 8 semillas.")
    print(f"Cota del paper: delta = 2D*lambda/(k+2D*lambda) = {DELTA_NOM:.4f}; "
          f"delta_real (sesgo del retarget) = {DELTA_REAL}\n")
    esc = [
        ("dynamic · sin copias",      "dynamic", 0,  "tips",        0.0),
        ("dynamic · 14 cop. retro1",  "dynamic", 14, ("retro", 1),  0.0),
        ("dynamic · 14 cop. retro4",  "dynamic", 14, ("retro", 4),  0.0),
        ("filter  · 14 cop. retro1",  "filter",  14, ("retro", 1),  0.0),
        ("off     · 14 cop. retro1",  "off",     14, ("retro", 1),  0.0),
        ("dynamic · retencion 12 s",  "dynamic", 0,  "tips",        12.0),
    ]
    barrido(esc, T=T)
