#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ataque_muestreo.py — Ataques al muestreo por espacio de D15A.

1. Ventana por PUBLICACIÓN vs por SLOT: fracción adversaria efectiva con retención T.
2. Fracción honesta online necesaria para que el sesgo de respuesta no cruce 1-q/k.
3. Supresión dirigida: ¿puede el atacante fabricar q respuestas rojas sin Sybil?
4. Varianza del peso por ventana (Poisson): cuántas soluciones honestas/adversarias.

Fuentes: arXiv:1906.08936 :242-254 (adversario), :288-294 (bootstrapping),
:598-599 (viveza), :1022 (parámetros). R-FIN-11 y R-FIN-13 del proyecto.
"""
import numpy as np
from scipy.stats import hypergeom, poisson

OUT = []


def p(s):
    OUT.append(s)
    print(s)


def main():
    p("=" * 100)
    p("D15A · ataques al muestreo por espacio")
    p("=" * 100)
    p("")
    p("--- 1 · VENTANA POR PUBLICACION vs POR SLOT (retencion T, ventana W) ---")
    p("Publicacion: el atacante retiene T y publica en rafaga; el honesto publica normal.")
    p("  f_eff = f*T / ((1-f)*W + f*T)   [el atacante no publica nada mas dentro de W]")
    p("Slot: cada solucion cuenta una sola vez en su slot; f_eff = f (invariante).")
    p(f"{'W (s)':>8} {'T/W':>6} {'f_eff publicacion':>18} {'f_eff slot':>12}")
    for W in (60, 600, 3600, 14400):
        for ratio in (0.5, 1, 2, 4, 8):
            T = ratio * W
            f_eff_pub = 0.33 * T / (0.67 * W + 0.33 * T)
            p(f"{W:8d} {ratio:6.1f} {f_eff_pub:18.3f} {0.33:12.3f}")
    p("")
    p("  Umbral de T/W para cruzar 0,5 en publicacion, f=0,33:")
    # f*T = 0.5*(1-f)W + 0.5*f*T  ->  T*(f - 0.5f) = 0.5(1-f)W  -> T = (1-f)W/(f)
    p(f"    T/W = (1-f)/f = {(1-0.33)/0.33:.3f}. Con T>=2W el atacante ya cruza 0,5.")
    p("")
    p("--- 2 · FRACCION HONESTA ONLINE NECESARIA (sesgo de respuesta) ---")
    p("Si responde una fraccion p_h de los honestos y el adversario siempre responde,")
    p("la fraccion adversaria entre respondedores es f/(f+(1-f)p_h); debe ser < 1-q/k.")
    p(f"{'f':>6} {'q/k=0,55':>10} {'q/k=0,60':>10} {'q/k=0,65':>10}")
    for f in (0.10, 0.20, 0.25, 0.30, 0.33, 0.40):
        vals = []
        for qk in (0.55, 0.60, 0.65):
            ph = f * (1 - qk) / (qk * (1 - f)) if f < qk else 1.0
            vals.append(min(1.0, ph))
        p(f"{f:6.2f} {vals[0]:10.3f} {vals[1]:10.3f} {vals[2]:10.3f}")
    p("  Lectura: a f=0,33 y q/k=0,60 hace falta que responda el 32,8 % de los honestos")
    p("  muestreados. Un granjero apagado es perdida de viveza, no falsificacion.")
    p("")
    p("--- 3 · SUPRESION DIRIGIDA: respuestas absolutas vs normalizadas ---")
    p("Muestra de k con f=0,33: adversarios esperados = f*k. Para que rojo alcance q")
    p("sin Sybil hace falta f*k >= q. Con q/k=0,60, f*k = 0,33k < 0,60k SIEMPRE.")
    p(f"{'k':>4} {'q':>4} {'adv_esp':>9} {'necesita_q':>11} {'puede_flip?':>12}")
    for k, q in ((10, 6), (20, 12), (50, 30), (100, 60), (100, 65)):
        p(f"{k:4d} {q:4d} {0.33*k:9.1f} {q:11d} {'NO' if 0.33*k < q else 'SI':>12}")
    p("  Si el sampler normaliza por respuestas (q/k de los que responden), suprimir")
    p("  honestos SI sube la fraccion adversaria. Diseno: contar respuestas ABSOLUTAS,")
    p("  q de k identidades muestreadas; la abstencion estanca, no voltea.")
    p("")
    p("--- 4 · VARIANZA DEL PESO POR VENTANA (Poisson) ---")
    p("Soluciones por clave en ventana W: lambda_clave = peso/W. P(peso=0) = e^-lambda.")
    p("Con W=3600 y una clave con 1 bloque/hora: P(0 en la ventana) = 1/e = 36,8 %.")
    p(f"{'soluciones esperadas':>20} {'P(0)':>10} {'P(>=1)':>10}")
    for lam in (0.1, 0.5, 1.0, 2.0, 5.0, 10.0):
        p(f"{lam:20.1f} {poisson.pmf(0, lam):10.4f} {1-poisson.pmf(0, lam):10.4f}")
    p("  Una ventana corta con claves de peso bajo tiene muchos ceros: la muestra")
    p("  efectiva es menor que k si el sampler exige respuesta. Ventana >= 3600 s.")
    p("")
    p("--- 5 · VOTO EMBEBIDO EN BLOQUE vs MUESTREO: por que el muestreo es de seguridad ---")
    p("Voto embebido (Snowman-like, un voto por bloque): el chit rojo ocurre con")
    p("probabilidad f=0,33 por bloque. El nodo decide cuando un color llega a beta.")
    p("Ruina del jugador, P(rojo llega a +beta antes que azul a -beta) ~ (f/(1-f))^beta.")
    p("Muestreo (k votantes, q/k=0,60, f=0,33): el chit rojo exige >=q rojos en la")
    p("muestra; su probabilidad es p_adv=7,8e-5 (CTMC). P ~ (p_adv/p_hon)^beta.")
    p(f"{'beta':>5} {'voto embebido (0,33)':>22} {'muestreo (p_adv=7,8e-5)':>26}")
    for beta in (5, 11, 20, 30, 50):
        p_emb = (0.33 / 0.67) ** beta
        p_mue = (7.8e-5 / 0.885) ** beta
        p(f"{beta:5d} {p_emb:22.2e} {p_mue:26.2e}")
    p("  La diferencia es ~40 ordenes de magnitud a igual beta: el muestreo convierte")
    p("  la fraccion adversaria f en la cola hipergeometrica P(H(n,fn,k)>=q), que es")
    p("  mucho menor que f. El voto por bloque NO tiene esa proteccion: es peso de")
    p("  cadena con otro nombre. Conclusion: el muestreo es carga estructural.")
    p("")
    p("--- 6 · ECLIPSE ---")
    p("El paper asume bootstrapping seguro y que el adversario NO puede programar ni")
    p("modificar la comunicacion entre honestos (:242-254, :288-294). En Internet eso")
    p("es falso (Heilman et al., research/fuentes/heilman2015-eclipse.txt). La eclipse")
    p("del sampler queda FUERA del modelo del paper: LAGUNA de transporte.")
    p("")
    with open("salida_muestreo.txt", "w") as fh:
        fh.write("\n".join(OUT) + "\n")


if __name__ == "__main__":
    main()
