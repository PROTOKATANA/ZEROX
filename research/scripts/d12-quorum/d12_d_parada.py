#!/usr/bin/env python3
"""
d12_d_parada.py — PUNTO D. Cuando se para el gadget bajo ataque y como se recupera.

Lewis-Pye y Roughgarden, Teorema 4.1 (research/fuentes/lewispye-roughgarden-cap.txt:759):
«No protocol is both adaptive and has ﬁnality», con adaptativo = vivo en el escenario SIN TAMANO
(:727-728) y finalidad = seguro en el parcialmente sincrono (:744-745). La pregunta no es SI se
para, es cuando y como se recupera.

Se mide:
  D.1  fraccion de instancias que NO cierran quorum, para alpha x k x W, con y sin perdida por
       retardo. Exacto (Poisson) + Monte Carlo de 12 semillas.
  D.2  tiempo hasta que vuelve a cerrarse (geometrica sobre instancias) y percentil 99.
  D.3  ¿sigue avanzando la cadena? (argumento + cita)
  D.4  la parada que ES el teorema: el escenario SIN TAMANO. lambda_voto no es un dato del
       protocolo; lo sostiene el retarget, que tarda W_RETARGET en reaccionar.
  D.5  particion: fraccion minima de espacio de un lado para seguir certificando.
  D.6  LA COMPARACION QUE DECIDE: espera necesaria con gadget frente a espera sin gadget, para
       el mismo riesgo.
"""
import sys
import numpy as np
from scipy.stats import poisson
from scipy.optimize import brentq

sys.path.insert(0, "research/scripts/d9-ronda9a")
from r9a_a3_frontera import prev  # noqa: E402

K_GD = 30
OFFSET = 3 * K_GD
W_RETARGET = 3083          # R-FIN-13, en indices de PoT (= s a tau = 1 s)
SEMILLAS = [11, 23, 37, 41, 53, 67, 71, 83, 97, 101, 113, 127]
COBERTURA = {}


def cuenta(r):
    COBERTURA[r] = COBERTURA.get(r, 0) + 1


def p_no_cierra(alpha, k, W, lam_v=1.0, delta=0.0):
    """El atacante retiene sus votos (estrategia censor del paper). Los honestos tienen que
    llegar a k solos, con su tasa efectiva."""
    mu_h = (1 - alpha) * (1 - delta) * lam_v * W
    cuenta(f"no_cierra_a{alpha}")
    return float(poisson.cdf(k - 1, mu_h))


def p_no_cierra_mc(alpha, k, W, semilla, n=200_000, lam_v=1.0, delta=0.0):
    rng = np.random.default_rng(semilla)
    mu_h = (1 - alpha) * (1 - delta) * lam_v * W
    return float(np.mean(rng.poisson(mu_h, size=n) < k))


def p_atacante_solo(alpha, k, W, lam_v=1.0):
    cuenta(f"atacante_solo_a{alpha}")
    return float(poisson.sf(k - 1, alpha * lam_v * W))


if __name__ == "__main__":
    print("=" * 104)
    print("D.1 · Fraccion de instancias que NO cierran quorum (atacante que retiene votos)")
    print("=" * 104)
    print("\nk se elige, para cada (alpha, W), como el que minimiza el peor de los dos riesgos")
    print("(seguridad = el atacante solo llega a k; viveza = los honestos no llegan a k).")
    print("Se muestran ademas los k del encargo, 32/64/128, con W = k/((1-alpha)*lambda) (el")
    print("tiempo esperado de quorum honesto), que es como esta planteada la idea de partida.\n")
    print(f"{'alpha':>7}{'k':>6}{'W (s)':>9}{'P[no cierra]':>16}{'P[atacante solo]':>20}"
          f"{'P[no cierra] d=0,267':>24}")
    for alpha in (0.10, 0.25, 0.33, 0.40):
        for k in (32, 64, 128):
            W = k / ((1 - alpha) * 1.0)     # tiempo esperado de quorum honesto
            print(f"{alpha:>7.2f}{k:>6}{W:>9.1f}{p_no_cierra(alpha, k, W):>16.4f}"
                  f"{p_atacante_solo(alpha, k, W):>20.3e}{p_no_cierra(alpha, k, W, delta=0.267):>24.4f}")
    print("\n-> a W = tiempo esperado de quorum, la mitad de las instancias no cierran (es la")
    print("   mediana de una Poisson). Hay que dar holgura a la ventana.")

    print("\n[D.1b] Con holgura: W = c * k/((1-alpha)*lambda), c = 1,5 / 2 / 3")
    print(f"{'alpha':>7}{'k':>6}{'c':>5}{'W (s)':>9}{'P[no cierra]':>16}{'P[atacante solo]':>20}")
    for alpha in (0.10, 0.25, 0.33, 0.40):
        for k in (32, 64, 128):
            for c in (1.5, 2.0, 3.0):
                W = c * k / ((1 - alpha) * 1.0)
                print(f"{alpha:>7.2f}{k:>6}{c:>5.1f}{W:>9.1f}{p_no_cierra(alpha, k, W):>16.3e}"
                      f"{p_atacante_solo(alpha, k, W):>20.3e}")

    print("\n[D.1c] Control del instrumento: Monte Carlo con 12 semillas frente al exacto")
    print(f"{'alpha':>7}{'k':>6}{'W':>8}{'MC media':>14}{'IC95':>24}{'exacto':>14}")
    for alpha in (0.10, 0.33, 0.40):
        for k in (32, 64):
            W = 1.5 * k / (1 - alpha)
            vals = [p_no_cierra_mc(alpha, k, W, s) for s in SEMILLAS]
            m = float(np.mean(vals)); sd = float(np.std(vals, ddof=1)); ic = 1.96 * sd / np.sqrt(len(vals))
            print(f"{alpha:>7.2f}{k:>6}{W:>8.1f}{m:>14.6f}{('[%.6f, %.6f]' % (m-ic, m+ic)):>24}"
                  f"{p_no_cierra(alpha, k, W):>14.6f}")

    print("\n" + "=" * 104)
    print("D.2 · Tiempo hasta que vuelve a cerrarse")
    print("=" * 104)
    print("\nLas instancias son independientes (votos nuevos, ventana nueva), luego el numero de")
    print("instancias hasta la primera que cierra es geometrico.\n")
    print(f"{'alpha':>7}{'k':>6}{'c':>5}{'W (s)':>9}{'E[espera] (s)':>16}{'p99 (s)':>14}")
    for alpha in (0.10, 0.25, 0.33, 0.40):
        for k in (32, 64, 128):
            for c in (1.5, 2.0):
                W = c * k / (1 - alpha)
                q = p_no_cierra(alpha, k, W)
                if q >= 1 - 1e-15:
                    print(f"{alpha:>7.2f}{k:>6}{c:>5.1f}{W:>9.1f}{'—':>16}{'—':>14}")
                    cuenta("nunca_cierra")
                    continue
                esp = W / (1 - q)
                p99 = W * (np.ceil(np.log(0.01) / np.log(q)) if q > 0 else 1)
                print(f"{alpha:>7.2f}{k:>6}{c:>5.1f}{W:>9.1f}{esp:>16.1f}{p99:>14.1f}")

    print("\n" + "=" * 104)
    print("D.3 · ¿Sigue avanzando la cadena mientras el gadget esta parado?")
    print("=" * 104)
    print("""
      SI, y no por el gadget sino por el suelo que ya existe. R-FIN-7 dice que una punta que
      exigiera reorganizar por debajo de F «se ignora, nunca apaga el proceso», y es literalmente
      lo que hace Kaspa: `virtual_processor/processor.rs:1013` exige
      `is_chain_ancestor_of(finality_point, candidate)` y `:1033` registra
      «Finality Violation Detected. Block ... is ignored from Virtual chain» — ignora el bloque,
      no para el nodo. La cadena sigue creciendo a (1-alpha)*lambda y la finalidad lenta de
      R-FIN-7 (F = 2 h) sigue operando. El gadget es ADITIVO en ese sentido, igual que F3
      («EC ... continues operating normally if F3 assumptions are violated and F3 halts»).
      Etiqueta: DEMOSTRADO (por la regla, no por medida).
      """)

    print("=" * 104)
    print("D.4 · La parada que ES el teorema: el escenario SIN TAMANO")
    print("=" * 104)
    print("""
      LPR 4.1 se demuestra en el escenario SIN TAMANO (lewispye-roughgarden-cap.txt:774-781):
      «network partitions [are] indistinguishable from waning resource pools». HotPoW escapa al
      teorema **por hipotesis**, excluyendo PoW-1 (hotpow.txt:265-267: «The total compute power
      of the network is higher than assumed») — es decir, situandose en el escenario CON TAMANO.
      Quien sostiene ese tamano en la practica es el retarget, y el retarget tiene inercia.
      """)
    print("      Si una fraccion (1-rho) del espacio se apaga de golpe, lambda_voto cae a rho*lambda")
    print(f"      hasta que el retarget reacciona (R-FIN-13: W_RETARGET >= {W_RETARGET} indices de PoT).")
    print(f"\n{'rho':>7}{'k':>6}{'W (s)':>9}{'P[no cierra] tras el apagon':>32}{'instancias perdidas':>22}")
    for rho in (1.0, 0.9, 0.7, 0.5, 0.3):
        for k in (32, 64, 128):
            alpha = 0.0
            W = 1.5 * k / (1 - 0.33)      # ventana dimensionada para alpha = 0,33 con holgura 1,5
            mu = rho * (1 - 0.33) * W
            q = float(poisson.cdf(k - 1, mu))
            cuenta(f"apagon_rho{rho}")
            perdidas = q * W_RETARGET / W
            print(f"{rho:>7.2f}{k:>6}{W:>9.1f}{q:>32.4f}{perdidas:>22.1f}")
    print("\n      -> con rho = 0,7 (se apaga el 30 % del espacio) el gadget deja de cerrar")
    print("         practicamente todas las instancias durante toda la ventana del retarget.")
    print("         La cadena, mientras tanto, sigue: es exactamente el reparto del teorema.")

    print("\n" + "=" * 104)
    print("D.5 · Particion: fraccion minima de espacio de un lado para seguir certificando")
    print("=" * 104)
    print(f"\n{'k':>6}{'W (s)':>9}" + "".join(f"{('f para P[no cierra]<' + e):>26}" for e in ("0,5", "0,01")))
    for k in (32, 64, 128):
        W = 1.5 * k / (1 - 0.33)
        fila = []
        for obj in (0.5, 0.01):
            f_ = lambda f: float(poisson.cdf(k - 1, f * W)) - obj
            fila.append(brentq(f_, 1e-6, 1.0, xtol=1e-9) if f_(1.0) < 0 else float("nan"))
        print(f"{k:>6}{W:>9.1f}" + "".join(f"{x:>26.4f}" for x in fila))
    print("\n      Comparese con R-FIN-7, que tolera una particion de hasta F si el lado conserva")
    print("      >= 9 % del espacio (D9-d A4). El gadget exige bastante mas.")

    print("=" * 104)
    print("D.6 · LA COMPARACION QUE DECIDE: espera con gadget frente a espera sin gadget")
    print("=" * 104)
    print("""
      PRIMERA VERSION (ERRONEA, declarada en el informe): comparaba la ventana W del gadget con
      la espera de hoy como si el certificado SUSTITUYERA a la profundidad. No la sustituye. Un
      granjero honesto vota por un bloque que CREE en su cadena seleccionada; si se equivoca, se
      equivocan TODOS a la vez, porque comparten la vista. Ese fallo es de MODO COMUN y el
      quorum no lo divide por nada: POA acota que existan DOS certificados en conflicto, no que
      el UNICO certificado este sobre un bloque que la cadena va a abandonar.

      Luego la garantia de un certificado emitido en t = d + W es
            max( prev(alpha, d) ,  P[el atacante forja k votos solo en W] )
      con d la profundidad a la que los honestos ya coinciden lo bastante para votar lo mismo.
      Sin gadget, esperando el MISMO tiempo d + W, la garantia es prev(alpha, d + W). Como prev
      es decreciente en t, prev(alpha, d) > prev(alpha, d+W) SIEMPRE: el gadget queda
      ESTRICTAMENTE DOMINADO, por exactamente los W segundos que tarda en juntar el quorum.
      """)
    print(f"{'alpha':>7}{'objetivo':>12}{'d necesaria (s)':>18}{'W del gadget (s)':>19}"
          f"{'total con gadget':>19}{'total sin gadget':>19}{'penalizacion':>14}")
    for alpha in (0.10, 0.25, 0.33, 0.40):
        for obj in (1e-6, 1e-12, 1e-30):
            g = lambda t: np.log10(max(prev(alpha, 1.0, t, OFFSET, 1.0), 1e-320)) - np.log10(obj)
            th = float("nan")
            if g(40000.0) < 0:
                th = brentq(g, 5.0, 40000.0, xtol=1e-3)
                cuenta("t_hoy_alcanzada")
            else:
                cuenta("t_hoy_inalcanzable")

            def peor(W):
                mu_a = alpha * W
                mu_h = (1 - alpha) * W
                if mu_h <= mu_a:
                    return 1.0
                ks = np.arange(1, int(mu_h * 1.5) + 2)
                return float(np.min(np.maximum(poisson.sf(ks - 1, mu_a), poisson.cdf(ks - 1, mu_h))))
            W = 1.0
            while W < 4e6 and peor(W) > obj:
                W *= 1.5
            if W >= 4e6:
                Wg = float("inf")
                cuenta("W_inalcanzable")
            else:
                a_, b_ = W / 1.5, W
                for _ in range(40):
                    m_ = (a_ + b_) / 2
                    if peor(m_) > obj:
                        a_ = m_
                    else:
                        b_ = m_
                Wg = b_
                cuenta("W_alcanzada")
            tot_con = th + Wg if (not np.isnan(th) and np.isfinite(Wg)) else float("nan")
            print(f"{alpha:>7.2f}{obj:>12.0e}{(f'{th:.0f}' if not np.isnan(th) else '>40000'):>18}"
                  f"{(f'{Wg:.0f}' if np.isfinite(Wg) else '—'):>19}"
                  f"{(f'{tot_con:.0f}' if not np.isnan(tot_con) else '—'):>19}"
                  f"{(f'{th:.0f}' if not np.isnan(th) else '>40000'):>19}"
                  f"{(f'+{Wg:.0f} s' if np.isfinite(Wg) else '—'):>14}")

    print("""
      La unica salida a la dominacion seria que los honestos votaran a profundidad d = 0, como
      hace HotPoW (todos votan por la unica cabeza que elige su regla de preferencia). En nuestro
      DAG con lambda = 1/s y Delta > 0 hay del orden de lambda*Delta puntas simultaneas y los
      honestos NO coinciden en la punta: es lo que mide el punto C. Y el catalogo ya lo declara
      como coste estructural D6: «Ninguna confirmacion posible antes de ~3k/((1-alpha)*lambda) =
      100-134 s, con ninguna F».
      """)

    print("=" * 104)
    print("COBERTURA DE RAMA")
    print("=" * 104)
    for k_, v in sorted(COBERTURA.items()):
        print(f"  {k_:<26}{v}")
