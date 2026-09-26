# ORDEN-W07c — Analizador de los registros del nodo (Julia, CPU) para las mediciones de 0.0.1

**LINEO (`V-ZRX/LINEO.md`) rige este código** (Julia en CPU; proyecto aislado; referencia antes que
optimización; tests con resultados exactos; reproducibilidad). Léelo íntegro antes de escribir código.

## 1. Identidad y contexto

- **ID:** W07c. **Fecha:** 2026-09-26. **Director:** Claude. **Ejecutor:** DeepSeek (`deepseek-flash`,
  esfuerzo `high`, DeepSeek Harness).
- **Zona (única escribible):** `/home/katana/zeo/ZEROX/deepseek/W07c/`.
- **Objetivo único:** un instrumento que, a partir de los registros JSONL de varios nodos y de los CSV de
  recursos de una ejecución, calcule las métricas del §3 de `P-ZRX/P-MEDICION/ESQUEMA-REGISTRO-v1.md` y las
  escriba en tablas reproducibles. **No** ejecuta nodos (eso es W07b) ni toca código Rust.
- **Pregunta falsable:** «Sobre registros construidos a mano con respuestas conocidas, el analizador
  devuelve exactamente esas respuestas (enteros exactos; percentiles con la definición fijada abajo); sobre
  los registros v0 reales de W06d4 calcula las métricas que v0 permite y declara no medidas las demás.»
- **Desbloquea:** W07b (el informe de mediciones de 0.0.1) y el registro de mediciones en `V-ZRX/`.

## 2. Entradas (congeladas en `P-ZRX/P-MEDICION/ENTRADA-W07c.sha256`)

- `P-ZRX/P-MEDICION/ESQUEMA-REGISTRO-v1.md` (**contrato**: eventos, campos, reglas de ausencia, métricas) y
  `P-ZRX/P-MEDICION/ESCENARIOS-0.0.1.md` (qué se mide en cada escenario).
- Registros v0 reales, solo lectura: `/home/katana/zeo/ZEROX/deepseek/W06d4/run/{A,B,C}/registro.jsonl`
  (ejecución V4 de W06d4: tres nodos cruzan el corte). Cópialos a tu zona antes de usarlos.

## 3. Decisiones del director

1. **Proyecto Julia aislado** en `deepseek/W07c/analisis-registro-v1/` con la estructura de LINEO §1
   (`Project.toml`, `Manifest.toml`, `src/`, `test/runtests.jl`, `run.jl`, `INFORME.md`), Julia **1.13.0**
   (`/home/katana/.julia/juliaup/julia-1.13.0+0.x64.linux.gnu/bin/julia`, siempre con
   `env -u LD_LIBRARY_PATH`), `JULIA_DEPOT_PATH=<zona>/.julia-depot:` (el depósito de `/home/katana/.julia`
   queda de respaldo de solo lectura; `JSON3` y `BenchmarkTools` ya están allí). Dependencias mínimas:
   `JSON3`, `Test`, `Statistics`, `Printf`, `Dates`; ninguna otra sin motivo escrito en el informe.
2. **Lectura tolerante y explícita:** una línea que no es JSON válido solo se tolera si es la **última** del
   archivo (escritura cortada por `SIGKILL`); cualquier otra aborta con el número de línea. Campos ausentes
   según el §0 del esquema: se cuentan por métrica y se informan; nunca se imputan.
3. **Percentiles:** definición **nearest-rank** sobre la muestra ordenada (`p` en `(0,100]`: el elemento de
   rango `ceil(p/100·n)`), en enteros de ns; nada de interpolación ni de `Float64` para decidir un umbral.
   Medias solo como dato adicional, en `Float64`, nunca como criterio.
4. **Latencia de propagación:** para cada `hash` producido (`bloque_producido` o `bloque_minado`) en un nodo
   A, y cada otro nodo B con `bloque_red_admitido` del mismo `hash`: `pared(B) − pared(A)`. Un valor negativo
   no se descarta en silencio: se cuenta y se informa (indicaría un reloj o un evento mal colocado). Bloques
   que B nunca admite: se cuentan por par.
5. **Divergencia:** con los `cambio_punta` de todos los nodos se construye, en tiempo de pared, la punta de
   cada nodo en cada instante (escalón; el inicio de un nodo es su **primer** `cambio_punta` y su fin, su último
evento de cualquier tipo). Fracción del intervalo `[máx(inicio de cada nodo), mín(fin)]` en que
   no todas coinciden; y, para cada instante de divergencia que empieza, el tiempo hasta la siguiente
   coincidencia. Se calcula con los eventos ordenados (coste `O(E log E)` con `E` eventos), no muestreando.
6. **Salida:** `run.jl --ejecucion <dir> --nodos A,B,C[,D] --salida <dir>` lee
   `<dir>/<nodo>/registro.jsonl` y, si existen, `<dir>/recursos-<nodo>.csv`; escribe `metricas.tsv` (una fila
   por métrica, con `n`, `ausentes`, `p50`, `p95`, `max`, unidad), `latencias.tsv` (por par de nodos),
   `admision-vs-profundidad.tsv` (tramos de 500), `rechazos.tsv` (por etapa y motivo), `convergencia.tsv` y
   `RESUMEN.md` con la procedencia (rutas y `sha256` de cada archivo leído, versión de Julia, hash del
   `Manifest.toml`).

## 4. Plan de verificación

| Paso | Qué | Criterio |
|---|---|---|
| V1 | **Referencia a mano:** al menos 6 conjuntos de registros sintéticos escritos a mano (en `test/datos/`), cada uno con la respuesta esperada calculada a mano en un comentario: (a) 3 nodos, 5 bloques, latencias conocidas; (b) un bloque que un nodo no admite; (c) latencia negativa; (d) divergencia de duración conocida con dos cambios de punta; (e) última línea truncada, y otra truncada en medio (debe abortar); (f) registro v0 sin `version_esquema` | todos exactos |
| V2 | Percentiles nearest-rank: `n = 1, 2, 3, 100, 101` con valores conocidos, y `p ∈ {50, 95, 100}` | exactos |
| V3 | Propiedades con semilla fija (`StableRNGs`): permutar las líneas de un nodo (salvo el orden de sus propios `cambio_punta`) no cambia las latencias; duplicar un nodo idéntico da divergencia 0 | se cumplen en ≥ 200 casos |
| V4 | **Datos reales v0:** `run.jl` sobre los tres registros de W06d4 | tabla de métricas v0 (latencias, divergencia, estado final igual o no, rechazos por motivo) y lista de métricas no medidas por ser v0 |
| V5 | Coste: tiempo y asignaciones del análisis de W06d4 (`BenchmarkTools`, tras calentar) y un registro sintético de 10⁶ eventos | medido; si pasa de 60 s, perfil y cuello identificado |

**Tabla de cobertura** en el informe: casos de test por métrica del §3 del esquema, **mínimo 1** por
métrica (incluida CPU/RSS con un CSV sintético). **Prohibido Python** (ni para generar datos, ni para
comprobar). Presupuesto: **2 h, 4 hilos, 8 GiB** (otra orden usa la máquina con procesos que dependen del
reloj).

## 5. Entregables y límites

En tu zona: el proyecto, `logs/`, `INFORME.md` (comandos, resultados de V1…V5, tabla de cobertura, qué **no**
queda demostrado, el nombre de modelo que devuelve la API), `PROGRESO.md`, `HORAS.log` con `date -Is` real, y
`HUELLAS.sha256` (último paso, `sha256sum -c` en verde) de todo lo entregado salvo el depósito de Julia.

**Límites de la sesión:** `deepseek-flash`, esfuerzo `high`, solo DeepSeek Harness; LINEO leído antes de
escribir código; ningún código Python; no eliges métricas ni definiciones distintas de las de esta orden y el
esquema (si falta una, para e informa **antes de editar**); nada fuera de tu zona (en particular **no** toques
`deepseek/W06d5/` ni sus procesos, ni `deepseek/W06d4/`: solo léelos); ningún resultado ficticio; sin git;
no leas ni muestres secretos (`.env`, `~/.dsh`, tokens).

## Lanzamiento

    mkdir -p /home/katana/zeo/ZEROX/deepseek/W07c && cd /home/katana/zeo/ZEROX/deepseek/W07c && \
    ( set -a; . /home/katana/torio/deepseek-harness/.env >/dev/null 2>&1; set +a; \
      node /home/katana/torio/deepseek-harness/apps/cli/lib/bin.js --profile headless \
      "Orden W07c. Lee íntegro /home/katana/zeo/ZEROX/P-ZRX/P-MEDICION/ORDEN-W07c.md y cúmplelo. Antes de escribir código, lee íntegro /home/katana/zeo/ZEROX/V-ZRX/LINEO.md. Si detectas una falta de definición, infórmala antes de editar." )
