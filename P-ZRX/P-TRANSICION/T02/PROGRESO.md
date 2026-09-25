# PROGRESO — T02 (modelo adversarial de la selección a través del corte)

**Estado:** **completada** la ejecución bajo `ORDEN-T02.md` con las definiciones de
`CORRECCION-T02-A.md`. Entregables en la zona `T02/`. No hay commit ni push. No se leyó código de
`T01/`.

**Presupuesto declarado:** 2 h de reloj, 4 hilos (tope), 16 GiB de RAM, 2 GiB de disco. **Consumo
real:** ~11 s de pared y 457 MiB en la corrida completa (`--escenario todos`, 10⁵ réplicas), 2,4 s de
tests. No se agotó.

## 0. Comprobación de la entrada congelada (inicio y fin)

`ORDEN-T02.md` §2 y `CORRECCION-T02-A.md` («Añade a `ENTRADA` la comprobación de
`ENTRADA-T02-A.sha256`»).

**Inicio (2026-09-26T01:14:18+02:00, de la sesión anterior):**

    $ cd /home/katana/zeo/ZEROX && LC_ALL=C sha256sum -c P-ZRX/P-TRANSICION/ENTRADA-T02.sha256
    P-ZRX/P-TRANSICION/ORDEN-T02.md: OK
    P-ZRX/P-TRANSICION/CONTRATO-v0.md: OK
    V-ZRX/LINEO.md: OK

**Inicio de la corrección A (2026-09-26T01:2x):**

    $ cd /home/katana/zeo/ZEROX && LC_ALL=C sha256sum -c P-ZRX/P-TRANSICION/ENTRADA-T02-A.sha256
    P-ZRX/P-TRANSICION/CORRECCION-T02-A.md: OK
    P-ZRX/P-TRANSICION/ORDEN-T02.md: OK
    P-ZRX/P-TRANSICION/CONTRATO-v0.md: OK
    V-ZRX/LINEO.md: OK

**Fin (2026-09-26T01:34:05+02:00):**

    $ cd /home/katana/zeo/ZEROX && LC_ALL=C sha256sum -c P-ZRX/P-TRANSICION/ENTRADA-T02.sha256
    P-ZRX/P-TRANSICION/ORDEN-T02.md: OK
    P-ZRX/P-TRANSICION/CONTRATO-v0.md: OK
    V-ZRX/LINEO.md: OK

    $ cd /home/katana/zeo/ZEROX && LC_ALL=C sha256sum -c P-ZRX/P-TRANSICION/ENTRADA-T02-A.sha256
    P-ZRX/P-TRANSICION/CORRECCION-T02-A.md: OK
    P-ZRX/P-TRANSICION/ORDEN-T02.md: OK
    P-ZRX/P-TRANSICION/CONTRATO-v0.md: OK
    V-ZRX/LINEO.md: OK

Los cuatro ficheros coinciden con la entrada congelada.

## 1. Ambigüedades de la orden anterior

La corrección cierra las cuatro que bloqueaban:

- **AMBIGÜEDAD-2 (E1):** se elimina `k`; E1 es Nakamoto §11 con la fórmula dada. **Cerrada.**
- **AMBIGÜEDAD-3 (E2):** cada rama arranca su PoST cuando existe su terminal; terminal a la misma
  altura `H*`; empate a favor del adversario (`≥`, más la estricta `>`). **Cerrada.**
- **AMBIGÜEDAD-4 (E3):** abstracción de trabajo `1+δ` por bloque a tasa `h/(1+δ)`, sin PoST.
  **Cerrada.**
- **AMBIGÜEDAD-5 (E4):** `Φ` con un depósito maduro, `S_min=q`, `K_min=1`, `SEC-0`; proceso de
  depósito/madurez y estrategia definidos; horizonte `10⁴·T_pow`. **Cerrada.**

Quedan **ratificadas** AMBIGÜEDAD-1 (`slot(PoW)=0`, `d = slot de la punta honesta`) y AMBIGÜEDAD-6
(`FC-1` compara historias válidas). Se implementaron así.

## 2. Falta de definición restante que cambia un resultado (declarada, no bloqueante)

Se declaran aquí, antes de dar por buenos los números, las lecturas adoptadas donde la corrección no
llega al detalle y que podrían mover un resultado. No se paró la ejecución porque la corrección ya
fija el proceso y estas lecturas se reportan con su sensibilidad.

1. **E4 · línea base de «retraso del corte».** La corrección no fija el origen. Se reporta el
   instante del corte desde `t=0` (media y p99) **y** el exceso sobre el corte sin adversario
   (`1+M_dep`). Ver `resultados/E4.csv` columna `t_corte_media` y `INFORME.md` §5.
2. **E4 · empate en la publicación.** La corrección dice «publica cuando su rama privada es más
   larga»; se implementa **estrictamente** más larga (favorable al honesto). Si el adversario
   publicara en empate, la censura crecería; por eso la discrepancia del §5 del informe respecto a
   la expectativa «h>1/2 ⇒ censurado ~1» debe leerse con este matiz.
3. **E3 · `FC-1` sin sufijo PoST vs AMBIGUEDAD-6.** La corrección define E3 con «gana en cuanto
   publica su terminal (más trabajo), sin peso PoST», lo que prima sobre la lectura general de que
   `FC-1` solo ordena historias válidas. Se implementó la definición explícita de E3 y se declara la
   tensión en `HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md` (H-5).
4. **E2 · «slots hasta el éxito».** Se miden desde `t_H`; si el éxito ocurre antes de `t_H`
   (`t_A ≤ t_H`) se reporta 0 (no negativo).
5. **E2 · rejilla.** El producto cartesiano completo (3456 puntos) es inviable en el presupuesto;
   se corre una sensibilidad + interacciones (35 puntos, 10⁵ réplicas). El resto queda
   **inconcluso por presupuesto** (ver `METODO.md` §8).

## 3. Resultados principales

- **Pregunta falsable: REFUTADA dentro del modelo.** `h=0,9`, `a=0,4`, `k=6`, `r=0,1`, `p=0,9`,
  `F_slots=1000` → éxito del nodo nuevo y del en línea **0,99982** (IC 99,9 %
  [0,99962; 0,99992]). 32/35 puntos de E2 con `a<1/2` superan el umbral `10⁻³`. Mecanismo: con `h`
  alta el terminal adversario existe antes que el honesto (`t_A≤t_H`), el empate `W_A=W_H=0`
  favorece al adversario y `d=0` (sin protección de `C-FIN-01`). `a` no es el recurso que decide.
- **E1:** fórmula vs tabla publicada, error máximo `4,83·10⁻⁸`; simulador 24/24 dentro del IC.
- **E3:** `FC-1` (nodo nuevo) gana siempre; `FC-3` alcanza 0,8647 (global) y 0,8394 con `a<1/2`
  (slots largos `r=1`, `k` pequeño). `FC-3` es peor que `FC-1` en línea en 6832/6912 puntos.
- **E4:** retraso finito para todos los puntos del grid; censura dominante solo a `h=0,9`,
  `M_dep=6` (0,810) y `M_dep=12` (0,9998). Para `h→1` la censura tiende a 1.
- **Tests:** `Pkg.test()` **69/69**; E3 MC 0/128 fuera del IC.

## 4. Entregables en `T02/`

`Project.toml`, `Manifest.toml`, `julia-version.toml`, `src/{modelo,referencia,rapido,validacion,T02}.jl`,
`test/runtests.jl`, `run.jl`, `resultados/{E1,E1_tabla_nakamoto,E2,E3,E3_validacion_mc,E4,resumen}.csv`
y `resultados/{test,run}.log`, `INFORME.md`, `METODO.md`, `MODELO.md`,
`HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md`, `PROGRESO.md`, `HORAS.log`. Nada fuera de la zona.

## 5. Límites

Sin latencia, sin retarget, sin GHOSTDAG real, sin sesgo de semilla (A-07), sin precios de hash
(A-10), sin doble farmeo. Producto cartesiano de E2 inconcluso por presupuesto. `E5` cualitativo.
