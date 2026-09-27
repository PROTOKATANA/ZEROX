# ORDEN-W07b — Mediciones reales de 0.0.1: receta desde un clon limpio y escenarios E-1…E-9

**LINEO (`V-ZRX/LINEO.md`) rige todo el código de esta orden** (scripts del arnés incluidos: son
instrumentos de medición); léelo íntegro antes de escribir nada y aplica sus reglas de reproducibilidad,
semillas, presupuesto, conservación de datos crudos y separación entre medición y simulación.

## 1. Identidad y contexto

- **ID:** W07b. **Fecha:** 2026-09-26 (borrador ≈ 23:05, puesta al día 2026-09-27; congelada y lanzada ≈ 10:44 sobre el commit candidato).
  **Director:** Claude. **Ejecutor:** subagente **Sonnet**, único (orquestación larga de procesos reales;
  `P-ZRX/PLAN-0.0.1.md` D-P06).
- **Zona (única escribible):** `/home/katana/zeo/ZEROX/deepseek/W07b/`.
- **Objetivo único:** ejecutar, con el binario candidato a 0.0.1 y procesos reales en `127.0.0.1`, la receta
  desde un clon limpio y los escenarios de `P-ZRX/P-MEDICION/ESCENARIOS-0.0.1.md` §3, conservando los
  registros crudos (esquema v1) y los CSV de recursos, y analizarlos con el instrumento de W07c.
- **Pregunta falsable:** «Desde un clon limpio del commit candidato, la CI local pasa y tres nodos
  independientes cruzan el corte, producen, propagan, validan, sincronizan (también un nodo tardío),
  reinician tras `SIGKILL`, se reorganizan tras una partición y convergen al mismo estado; cada entrada
  inválida de E-7 se rechaza con su motivo; y la doble firma de E-8 se castiga según RAT-2′.» Cada escenario
  que falle se informa como fallo, con su causa si se identifica; no se ajusta el criterio a posteriori.
- **Desbloquea:** el cierre de 0.0.1 (`AUTO-ZRX.md` §8) y las entradas de `V-ZRX/REGISTRO.md`.

## 2. Entradas (congeladas en `P-ZRX/P-MEDICION/ENTRADA-W07b.sha256`)

`ESCENARIOS-0.0.1.md`, `ESQUEMA-REGISTRO-v1.md` (con §1 bis), `P-ZRX/P-RED-DEV/PERFIL-DEV-v0.md`, las revisiones
W06d4…W06d7, W07a, SL-4b2 y W07c, y el instrumento **`P-ZRX/P-MEDICION/analisis-registro-v1/`** (versionado; cópialo a
tu zona). Los guiones de ejecución de `deepseek/W06d6/`, `deepseek/W06d7/` y `deepseek/SL4b2/` se pueden **leer**
como punto de partida; ninguna otra zona. Código: el commit candidato que indique la entrada.

## 3. Decisiones del director

1. **E-0, receta desde un clon limpio:** `git clone --no-hardlinks /home/katana/zeo/ZEROX <zona>/clon` y
   `git -C <zona>/clon checkout <commit>`; el clon de Autonomys como en el paso «Clonar Autonomys» de
   `.github/workflows/zerox-ci.yml`, pero desde la copia local `/home/katana/zeo/ZEROX/PDF/autonomys-subspace`
   (fijado en `f8842d0`); después, **todos** los pasos de ese flujo (fmt, clippy, build, test,
   `ci/dependencias-exactas.sh`, `ci/frontera-crates.sh`) y `cargo build --release --locked -p zx-node`. Los
   binarios de las mediciones son **los de este clon** (anota su `sha256`). La receta de un comando queda en
   `RECETA.md`.
2. **Parámetros:** `N_dev` **real** del perfil (138 873 760) en todos los escenarios; `SR_dev` calibrado en
   E-2a (abajo); `--semilla` y puertos fijados por repetición y anotados. Ningún parámetro de consenso se
   cambia.
3. **E-2a, calibración de `SR_dev`:** tres nodos tras el corte, 200 slots por punto, búsqueda por bisección
   en escala logarítmica sobre `SR_dev` hasta que los **bloques por slot** medidos (bloques PoST distintos
   admitidos / slots transcurridos) queden en `[0,8; 1,2]`; como mucho 6 puntos. Se publica la tabla punto a
   punto y el valor elegido; si no se alcanza el intervalo en 6 puntos, se elige el más cercano y se declara.
4. **Tres repeticiones por escenario**, semillas distintas registradas, **una a la vez** (nunca dos redes a la
   vez: se mide CPU). Agrupación permitida para ahorrar tiempo, con ventanas de tiempo de pared anotadas en
   `EJECUCION.txt`:
   - **R1** = E-1 → E-2 (30 min de régimen) → E-4 (`SIGKILL` a A, rearranque) → E-3 (convergencia medida tras
     cada suceso).
   - **R2** = E-5 (nodo D desde el génesis cuando la red lleva ≥ 500 bloques).
   - **R3** = E-6 (partición `{A}` / `{B, C}` de 60 slots en fase PoST y reunión, con la técnica de W06d7 V5 —aislar A reiniciándolo sin pares— o la del nodo puente de W06d4,
     declarada) y E-6b (partición en fase PoW cerca del corte).
   - **R4** = E-7 (`zx-adversario`, todas las entradas de E-7), E-8 (`zx-adversario doble-firma`, **con
     castigo activo**: se exige lo de SL-4b2 V4) y E-9 (retención del terminal: descriptivo).
5. **Recursos:** muestreo de `/proc/<pid>/{stat,status,io}` cada 1 s y del tamaño del directorio de datos cada
   10 s, en **bash** (sin Python), con el formato del §2 del esquema; `EJECUCION.txt` con commit, `sha256` de
   los binarios, parámetros, semillas, `getconf CLK_TCK`, `getconf PAGESIZE`, `uname -a`, CPU, carga media al
   empezar y al terminar, y los procesos ajenos que consumían CPU (`ps` al empezar).
6. **Reposo y comparación de estado (E-3 y todo «mismo estado»):** todos los nodos con el mismo
   `--dejar-de-producir-en-slot <S>`; se espera al evento `dejar_de_producir` en todos y a que no haya
   `cambio_punta` durante 30 s; entonces se compara el último `punta` y `resumen_estado` de cada nodo.
7. **E-6b con producción en marcha** durante la reunión (tras el paso 0 de SL-4b2); E-8 **con castigo activo**
   (se exige lo de SL-4b2 V4).
8. **Julia para el análisis:** `env -u LD_LIBRARY_PATH JULIA_DEPOT_PATH=<zona>/.julia-depot:/home/katana/.julia
   /home/katana/.julia/juliaup/julia-1.13.0+0.x64.linux.gnu/bin/julia --project=. run.jl …` (`REVISION-W07c.md`, nº 11).
9. **Análisis:** el instrumento de W07c (`run.jl`) sobre cada repetición; tabla por escenario y repetición
   (no solo la media). Si el instrumento falla con datos reales, **para** e informa: no lo corrijas tú.

## 4. Criterios por escenario (fijados antes de medir)

| Escenario | Superado si |
|---|---|
| E-0 | Todos los pasos de la CI local en verde desde el clon; binarios construidos |
| E-1 | Los tres nodos fijan el mismo terminal `T` y los tres producen bloques PoST válidos |
| E-2 | 0 rechazos de bloques honestos en 30 min; métricas del esquema §3 publicadas |
| E-3 | Mismo `SEL` y mismo `resumen_estado` en los tres al final de cada ventana |
| E-4 | El nodo reabre sin corrupción, repite, se pone al día y termina con el estado de los pares; 0 evidencias contra su clave |
| E-5 | D sincroniza desde el génesis al mismo `resumen_estado` que A, B, C |
| E-6 / E-6b | Tras reunir, un único `SEL` y estado; en E-6b un único `T` según FC-3; descartes con motivo |
| E-7 | Cada entrada inválida rechazada con su motivo, sin cambio de estado; el par penalizado según los límites |
| E-8 | Evidencia detectada, incluida y aplicada en los tres; confiscación según RAT-2′; mismo estado final |
| E-9 | Descriptivo: qué `T` fijan los nodos y cuándo (A-07 abierto) |

## 5. Entregables y límites

En la zona: `clon/`, `RECETA.md`, `scripts/` (arnés en bash), `run/<escenario>/<rep>/…` (registros y CSV
crudos, con `sha256` en `HUELLAS.sha256`), `analisis/` (salidas del instrumento), `INFORME.md` (tabla
escenario × repetición con superado/no superado y métricas; lo que **no** se mide, `ESCENARIOS-0.0.1.md` §4;
fallos sin ocultar), `PROGRESO.md` (procesos largos con PID y log **antes** de esperarlos; al retomar tras un
corte, léelo primero), `HORAS.log` con `date -Is` real.

**Un solo ejecutor: prohibido lanzar subagentes o forks.** Prohibido Python. No modifiques código del
producto: si un escenario falla por un defecto del nodo, **para ese escenario**, deja los registros y sigue
con los demás. Presupuesto: **8 h de reloj, hasta 20 hilos** (la red de tres nodos usa ≈ 15), 32 GiB, 50 GiB
de disco. Sin procesos huérfanos al terminar. Nada fuera de la zona; sin git en el repositorio (el clon de tu
zona sí); sin secretos.
