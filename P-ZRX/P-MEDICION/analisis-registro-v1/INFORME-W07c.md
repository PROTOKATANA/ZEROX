# INFORME — W07c: analizador de los registros del nodo (Julia, CPU)

**Orden:** `P-ZRX/P-MEDICION/ORDEN-W07c.md` (2026-09-26). **Ejecutor:** DeepSeek Harness, modelo
`deepseek-flash`, esfuerzo `high` (ver §12). **Zona única:** `/home/katana/zeo/ZEROX/deepseek/W07c/`.
**Regla madre:** `V-ZRX/LINEO.md`, leído íntegro antes de escribir código. **Sin Python**, **sin git**,
sin tocar `deepseek/W06d4/` ni `deepseek/W06d5/` (sólo lectura/copia).

**Pregunta falsable (ORDEN §1):** sobre registros construidos a mano con respuestas conocidas, el
analizador devuelve exactamente esas respuestas; sobre los registros v0 reales de W06d4 calcula lo que v0
permite y declara **no medidas** las demás.

**Veredicto:** *sí* en ambos extremos.
- Sobre 8 conjuntos sintéticos (a–g + recursos) con la respuesta calculada a mano, **todos exactos**
  (V1, 70 aserciones), los percentiles nearest-rank son exactos (V2, 36), y 402 comprobaciones de
  propiedades con semilla fija pasan (V3).
- Sobre los tres registros v0 reales de W06d4 (`sha256` idénticos a la entrada congelada) se calculan
  latencias, divergencia, estado final, profundidad de reorganización parcial, rechazos por motivo,
  arranque; y se declaran **no medidas** las 8 métricas que exigen campos v1 + recursos (V4).

---

## 1. Entorno, presupuesto y reproducibilidad

| Dato | Valor |
|---|---|
| Julia | **1.13.0** (`/home/katana/.julia/juliaup/julia-1.13.0+0.x64.linux.gnu/bin/julia`) |
| Depósito | `JULIA_DEPOT_PATH=/home/katana/zeo/ZEROX/deepseek/W07c/.julia-depot:/home/katana/.julia` |
| `LD_LIBRARY_PATH` | siempre eliminado con `env -u LD_LIBRARY_PATH` (LINEO §1) |
| CPU | `Sys.CPU_NAME = znver5` (AMD Ryzen 9 9950X3D, 16 físicos / 32 lógicos) |
| RAM | 123 GiB visibles |
| Proyecto | `analisis-registro-v1/` aislado, `Project.toml` + `Manifest.toml` |
| `sha256(Manifest.toml)` | `22327796a9e8100ca2696726aae43f4bf263b14243cb9b646cbf2d2b8ac1a3c3` |
| Hilos | comandos con `--threads=4`; el análisis es **serial** (no hay eje independiente salvo por nodo) |
| Presupuesto declarado | **2 h, 4 hilos, 8 GiB** (ORDEN §4); no se superó |
| Pico de RSS observado (10⁶ eventos) | **826 MiB** (`logs/v5-pico-rss.log`), muy por debajo de 8 GiB |

**Desviación de entorno documentada.** La orden fija `JULIA_DEPOT_PATH=<zona>/.julia-depot:` con el
depósito de `/home/katana/.julia` como respaldo. En esta máquina una entrada final vacía resuelve a los
depósitos de la instalación de juliaup, **no** a `/home/katana/.julia` (comprobado: `DEPOT_PATH` no
incluía el segundo). Se usó el camino explícito `<zona>/.julia-depot:/home/katana/.julia`, que carga
`JSON3`, `StableRNGs` y `BenchmarkTools` ya presentes. Todo se resolvió **offline**
(`JULIA_PKG_OFFLINE=true`); no hubo descargas.

### Dependencias y motivo

`JSON3` (parseo del contrato), `StableRNGs` (V3, semilla fija reproducible entre versiones),
`BenchmarkTools` (V5) y las stdlib `Test`, `Statistics`, `Printf`, `Dates`, `Random`, `SHA` (procedencia).
No se añadió ninguna otra: la orden lo exige y `CSV.jl` se evitó leyendo el CSV del §2 con `split`.

### Comandos exactos

```bash
cd /home/katana/zeo/ZEROX/deepseek/W07c/analisis-registro-v1
export JULIA_DEPOT_PATH="/home/katana/zeo/ZEROX/deepseek/W07c/.julia-depot:/home/katana/.julia"

# Proyecto (ya resuelto; repetible offline)
JULIA_PKG_OFFLINE=true env -u LD_LIBRARY_PATH \
  /home/katana/.julia/juliaup/julia-1.13.0+0.x64.linux.gnu/bin/julia --project=. \
  -e 'using Pkg; Pkg.instantiate()'

# V1 + V2 + V3
env -u LD_LIBRARY_PATH /home/katana/.julia/juliaup/julia-1.13.0+0.x64.linux.gnu/bin/julia \
  --project=. --threads=4 test/runtests.jl

# V4 (datos reales v0 de W06d4, copiados a la zona)
env -u LD_LIBRARY_PATH /home/katana/.julia/juliaup/julia-1.13.0+0.x64.linux.gnu/bin/julia \
  --project=. --threads=4 run.jl \
  --ejecucion /home/katana/zeo/ZEROX/deepseek/W07c/datos/W06d4-real --nodos A,B,C \
  --salida /home/katana/zeo/ZEROX/deepseek/W07c/analisis-registro-v1/resultados/v0-W06d4

# V5
env -u LD_LIBRARY_PATH /home/katana/.julia/juliaup/julia-1.13.0+0.x64.linux.gnu/bin/julia \
  --project=. --threads=4 bench/benchmarks.jl
env -u LD_LIBRARY_PATH /home/katana/.julia/juliaup/julia-1.13.0+0.x64.linux.gnu/bin/julia \
  --project=. --threads=1 bench/perfil.jl
```

Los registros v0 reales se copiaron a `datos/W06d4-real/{A,B,C}/registro.jsonl`; sus `sha256`
coinciden con `ENTRADA-W07c.sha256`.

---

## 2. V1 — referencia a mano (datos en `test/datos/`, respuesta en `test/datos/RESPUESTAS.md`)

Todos los valores son **enteros exactos de ns** salvo la fracción de divergencia.

| Caso | Qué fija | Resultado exigido (a mano) | ¿Exacto? |
|---|---|---|---|
| (a) `caso-a` | 3 nodos P,Q,R; 5 bloques | P→Q `[100,300]` p50=100/p95=max=300; P→R `[200,400]`; Q→P `[50,500]`; Q→R `[100,600]`; R→P `[100]`; R→Q `[200]`; total n=10 p50=200 p95=max=600; t_admisión n=10=100; padres n=15=1; bloques/slot n=5=3; rojos 1/3 | sí |
| (b) `caso-b` | un bloque que un nodo no admite | P→Q producidos=2 admitidos=1 no_admitidos=1; P→R n=2 p50=150 p95=max=200 | sí |
| (c) `caso-c` | latencia negativa | P→Q n=1 negativos=1 p50=p95=max=**−100** | sí |
| (d) `caso-d` | divergencia con dos cambios de punta | fracción **600/1100**; episodios `(100,200,·)`, `(500,300,·)`, `(1000,100,truncada)`; estado final igual | sí |
| (e) `caso-e1` / `caso-e2` | última línea truncada / truncada en medio | e1: `truncadas=1`, latencia 100; e2: aborta en **línea 2** (`ErrorRegistro`) | sí |
| (f) `caso-f` | registro v0 sin `version_esquema` | v0; latencia P→Q=100; divergencia **100/900**; `arranque_ns` `[400,500]`; tiempos de etapa n=0 | sí |
| (g) `caso-g` | cobertura v1: tramos 500, rechazos, reorg, reinicio | tramos `[0,499] n=1 v=10`, `[500,999] n=2 p50=20 p95=30`, `[1000,1499] n=1 v=40`; rechazos `m1 n=2 p50=100 p95=300`, `m2 n=1`; `profundidad_reorg` `[1,3]`; `duracion_reinicio=1234`; rojos 0 | sí |
| `caso-recursos` | CPU/RSS/E-S/disco con CSV sintético | cpu `[0.25,0.40]`; rss `[1500,2000]` p95; read `[100,200]`; write `[50,100]`; disco 8192; `CLK_TCK=100` | sí |

Además, cada caso pequeño se contrasta con el **oráculo O(E²)** de `referencia.jl`
(`comparar_latencias`, `comparar_divergencia`), que usa un camino independiente.

---

## 3. V2 — percentiles nearest-rank

`p ∈ {50, 95, 100}`, `n ∈ {1, 2, 3, 100, 101}` sobre `v = 1:n`: rango `ceil(p·n/100)` calculado como
`div(p*n+99,100)` (sin `Float64`). 36 aserciones exactas, incluidos `n=0 ⇒ missing` y `p ∉ (0,100] ⇒
error`. Ejemplo: `n=2, p=50 ⇒ 1` (no interpola), `n=100, p=95 ⇒ 95`, `n=101, p=95 ⇒ 96`.

---

## 4. V3 — propiedades con semilla fija (`StableRNG(0x5a5a)`)

- **200 casos**: permutar las líneas de cada nodo (sin `cambio_punta` en el escenario) no cambia
  ninguna latencia (por par: producidos, admitidos, no admitidos, negativos, n, p50, p95, máx) y el
  resultado coincide con el oráculo O(E²). **200/200.**
- **200 casos**: duplicar un nodo idéntico (mismos `cambio_punta` con tiempos y puntas aleatorios) da
  **divergencia 0** sin episodios y coincide con el oráculo. **200/200.**

`test/runtests.jl` termina con **`runtests.jl: OK`**: V1 70/70, V2 36/36, V3 402/402.

---

## 5. V4 — registros v0 reales de W06d4 (`run/A,B,C`, ejecución V4)

Procedencia (idéntica a la entrada congelada): A `d6fc0957…da24` (2857 líneas), B `1b8c942b…639f`
(1071), C `65663503…c2c63` (1428); 0 truncadas; los tres **v0**. No hay `recursos-*.csv` ni
`EJECUCION.txt` en la ejecución, así que `CLK_TCK=100` es el valor por defecto (declarado).

### Latencias de propagación (ns)

| A→B | producidos | admitidos | no admitidos | negativos | n | p50 | p95 | máx |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| A→B | 306 | 181 | 125 | 0 | 181 | 79 230 504 | 847 291 665 | 1 927 966 794 |
| A→C | 306 | 306 | 0 | 0 | 306 | 38 717 694 | 94 607 731 | 1 134 122 264 |
| B→A | 218 | 186 | 32 | 0 | 186 | 86 362 058 | 3 160 966 638 | 75 939 138 275 |
| B→C | 218 | 218 | 0 | 0 | 218 | 45 060 053 | 202 399 463 | 330 536 638 |
| C→A | 304 | 144 | 160 | 0 | 144 | 39 316 872 | 10 962 763 233 | 61 415 635 735 |
| C→B | 304 | 188 | 116 | 0 | 188 | 45 028 404 | 126 780 659 | 936 001 039 |
| **total** | — | — | — | 0 | **1223** | **51 113 328** | **282 175 398** | **75 939 138 275** |

### Otras métricas v0

- **Divergencia:** fracción **0.348235** del intervalo común; **372 episodios**, 1 de ellos sin
  reconverger antes del fin (`truncada=1`).
- **Estado final:** A `ffcb4fb9…2ee2`, B `9cba0a1c…eb14`, C `0a15a00d…bdca8`; **no** coinciden.
- **Profundidad de reorganización:** n=25 (sólo `reorganizacion_pow.profundidad`; los 566+470+585
  `cambio_punta` v0 la omiten) p50=1, p95=5, máx=5.
- **Rechazos:** 15, todos en A, `etapa` ausente (v0) y `motivo` exacto con el hash embebido; la clase
  es `pendiente: Pot(PasadoIncompleto)`; sin `t_hasta_rechazo_ns`.
- **Arranque (puesta al día):** `pared(fase=limpio) − pared(fase=inicio)`; n=3, p50=6.9637 s,
  p95=7.0664 s, máx=7.0664 s.

### Métricas **no medidas** en v0 (declaradas, no imputadas)

`t_cabecera_ns`, `t_admision_ns`, `t_persistencia_ns`, `t_total_ns` (n=0, ausentes=1227);
`admision-vs-profundidad.tsv` vacío; `bloques_por_slot` y `padres_por_bloque` (n=0, ausentes=2007);
`fraccion_rojos` (n=0); `duracion_reinicio_ns` (v0 no trae `reinicio_completo`); CPU/RSS/E-S/disco (no
hay CSV ni `EJECUCION.txt`). La **profundidad de reorganización** es sólo **parcial** y los
**rechazos** sólo por **motivo** (sin etapa ni coste), exactamente como marca el §3 del esquema.

---

## 6. V5 — coste y perfil

| Variante | Entrada | Tiempo mediano | Asignado | Asignaciones | Pico RSS |
|---|---|---:|---:|---:|---:|
| Real W06d4 | 3 nodos, 5 356 líneas, 73 KB | **15.696 ms** (`BenchmarkTools`, 20 muestras) | 20.9 MiB | 114 261 | — |
| Sintético | 1 000 006 líneas (~101 MiB en 3 archivos) | **3.730 s** (`BenchmarkTools`, 3 muestras) | 4 467 MiB | 24 779 431 | **826 MiB** |

Muy por debajo del umbral de 60 s de la orden, así que no se lanzó una ronda de optimización. Aun así
LINEO §6 exige nombrar el cuello: el **perfil de 1 hilo** (3 888 muestras, 100 % utilización) muestra
que el coste está dominado por el **parseo JSON3** (`read`/`parse`: ~1900/3888 muestras) y por el
**`sha256` de procedencia** (~909), no por las métricas (que son un porcentaje menor); dentro del
parseo pesan la creación de `String`/`GenericMemory`, `internar!` y `_entero`/`_texto`. Reducir el
coste exigiría un parser especializado del contrato (menos general que JSON3) o paralelizar por nodo;
dado que el caso real tarda 15.7 ms y el de 10⁶ eventos 3.7 s dentro de presupuesto, no se justificó
(Camino 2/3 de LINEO). El análisis es **serial**: no hay eje independiente suficiente con 3 nodos y el
coste no lo pide.

---

## 7. Tabla de cobertura (§3 del esquema; ≥1 test por métrica)

| Métrica §3 | Eventos | Test que la cubre | v1 | v0 real |
|---|---|---|---|---|
| Latencia A→B (p50, p95, máx; por par y total) | `bloque_producido`/`bloque_minado` + `bloque_red_admitido` | V1(a,b,c,e1,f), V3(1), V4 | ✔ | ✔ (parcial: sólo bloques admitidos) |
| Tiempo por etapa (`t_cabecera`, `t_admision`, `t_persistencia`, `t_total`) | `bloque_red_admitido` | V1(a), V1(g) | ✔ | no medida |
| Admisión vs `n_bloques_dag` en tramos de 500 | `bloque_red_admitido` | V1(a) (tramo 0), V1(g) (tramos 0,1,2) | ✔ | no medida |
| Bloques por slot | `bloque_producido`/`bloque_red_admitido` | V1(a), V1(g) | ✔ | no medida |
| Padres por bloque | `n_padres` | V1(a), V1(g) | ✔ | no medida |
| Fracción de rojos | `azules_mergeset`/`rojos_mergeset` | V1(a) (1/3), V1(g) (0) | ✔ | no medida |
| Rechazos por etapa y motivo; coste | `bloque_red_rechazado` | V1(g) (etapa+coste), V4 (motivo real) | ✔ | parcial (sin etapa ni coste) |
| Divergencia: fracción y tiempo hasta converger | `cambio_punta` | V1(d), V1(f), V3(2), V4 | ✔ | ✔ |
| Estado final igual | último `resumen_estado` | V1(d) (igual), V1(g) (no medido), V4 (distinto) | ✔ | ✔ |
| Profundidad de reorganización | `profundidad_reorg` + `reorganizacion_pow` | V1(g) (ambas fuentes), V4 (parcial) | ✔ | parcial |
| CPU, RSS, E/S y disco por nodo | CSV §2 | V1(recursos) (CSV sintético) | ✔ | no medida |
| Duración de reinicio y puesta al día | `reinicio_completo` + `arranque` | V1(f) (`arranque`), V1(g) (`reinicio_completo`), V4 | ✔ | parcial (`arranque`) |

La columna de `ausentes` de `metricas.tsv` cuenta, por métrica, los eventos candidatos con el campo
requerido ausente (falta 4); no se imputa ningún valor.

---

## 8. Decisiones de definición

Todas las lagunas y la lectura determinista adoptada están en `FALTAS-DE-DEFINICION.md` (13 puntos),
informadas antes de editar. En resumen: producción/admisión **más tempranas** por hash con recuento de
duplicados; percentiles **nearest-rank** en enteros; negativos incluidos y contados; `metricas.tsv` con
columnas `metrica, ambito, n, ausentes, p50, p95, max, unidad`; divergencia **no medida** si no hay ≥2
nodos con `cambio_punta` y episodios no reconvergidos marcados; tramos `[500k, 500k+499]`; recursos con
`CLK_TCK` de `EJECUCION.txt` o 100; `rechazos.tsv` por (etapa tal cual, motivo exacto) sin normalizar.

---

## 9. Qué **no** queda demostrado

- **No hay registros v1 reales.** Todo lo v1 se validó con datos sintéticos escritos a mano; el
  analizador no se ha confrontado con un productor v1 real (W07a/W07b aún no existen).
- **Recursos sólo con CSV sintético.** En W06d4 no hay `recursos-<nodo>.csv` ni `EJECUCION.txt`; por
  tanto `cpu_util`, `rss_kib`, E/S y disco no están medidos sobre datos reales y `CLK_TCK=100` es un
  supuesto declarado.
- **El oráculo es interno** (`referencia.jl`, O(E²)); no se contrastó con una implementación externa
  independiente.
- **Sesgo por corte en W06d4.** 125+32+160+116 bloques producidos no fueron admitidos por el par; las
  latencias por par se calculan sólo sobre los admitidos y no son una distribución de propagación
  completa. Los porcentajes no se extrapolan.
- **No se validan los relojes.** Una latencia negativa se cuenta e informa, pero el analizador no
  decide si el registro está mal; tampoco se comprueba monotonicidad global.
- **No hay escalado en hilos.** El análisis es serial; no se midió 1/2/4/8… hilos porque el coste real
  es 15.7 ms y el eje por nodo es de sólo 3. El tope de 4 hilos no se superó.
- **`version_esquema` mixto.** En un registro con unos nodos v1 y otros v0 no se probó la mezcla; la
  regla es por nodo (v1 ⇔ algún `arranque` con `version_esquema`), pero ningún caso la ejercita.
- **No se ejecutó `Pkg.test()`** (el proyecto no es un paquete con `[targets]`); los tests corren con el
  comando documentado `julia --project=. test/runtests.jl`.
- **No se publica una cifra de hashrate ni de producción**: no es el objeto de W07c.

---

## 10. Límites cumplidos

- Sólo se escribió bajo `deepseek/W07c/`; `W06d4` se leyó/copió sin modificar; `W06d5` no se tocó.
- **Cero Python**: la generación del sintético de V5, los datos de `test/datos/` y las comprobaciones
  son Julia/bash (jq/awk sólo para inspección).
- Ninguna métrica o definición distinta de la orden y el esquema; las lagunas se informaron y se
  resolvieron con el detalle determinista mínimo.
- Sin resultados ficticios: `HUELLAS.sha256` cubre lo entregado salvo el depósito `.julia-depot/`.

---

## 11. Entregables

`analisis-registro-v1/` (código, tests, datos, bench, `resultados/`), `logs/`, `PROGRESO.md`,
`HORAS.log`, `FALTAS-DE-DEFINICION.md`, `INFORME.md` (este) y `HUELLAS.sha256`. Las tablas de la
ejecución real están en `analisis-registro-v1/resultados/v0-W06d4/` (`metricas.tsv`, `latencias.tsv`,
`admision-vs-profundidad.tsv`, `rechazos.tsv`, `convergencia.tsv`, `RESUMEN.md`).

---

## 12. Modelo que devuelve la API

- **Modelo de la sesión:** `deepseek-flash`, esfuerzo `high` (el declarado por el arranque de la orden,
  `--profile headless`).
- **No se verificó por una llamada a la API** (p. ej. `/v1/models`) porque la credencial/base viven en
  `/home/katana/torio/deepseek-harness/.env` y `~/.dsh`, que la orden prohíbe leer. Esta sección es,
  por tanto, la única afirmación del informe no comprobada de forma independiente.
