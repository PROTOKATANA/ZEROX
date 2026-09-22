# Revisión independiente de Julia y numerismo — CRP-v0.2

**Revisor:** agente independiente (revisión en contexto independiente; **no** es firma de tercero).
**Fecha:** 2026-09-18. **Ámbito:** `deepseek/veritas/seguridad/coste-rama-privada-v2/`.
**Norma:** `veritas/LINEO.md`. **Encargo:** `deepseek/ENCARGO-07v2-coste-rama-privada.md`.

> Esta revisión la realiza un agente en contexto independiente. No es un dictamen firmado por una
> persona ni por un tercero externo; se entrega como evidencia de revisión, no como certificación.

---

## 1 · Alcance

Se revisó exclusivamente el instrumento Julia `CRP-v0.2` (no el `SPEC`, `TAREAS`, el encargo ni el
código del nodo, que no se tocaron). Objetivos:

1. Higiene `LINEO` (tipos, globals, `@fastmath`, aritmética entera, RNG por réplica,
   reproducibilidad a 1 hilo).
2. Reproducción de la suite y de `run.jl` con los comandos del encargo.
3. Detección de bugs de rendimiento, asignaciones, inestabilidad de tipos, errores de borde y
   verificación explícita de D1 (“producir contra la vista local antes de recibir en tránsito”;
   ¿puede un hijo referenciar un padre no añadido aún a GDR?).
4. Contraste de `resultados/` con lo declarado en `INFORME.md`.

Fuera de alcance: auditoría de GHOSTDAG/GDR-v0.2 (se usó como oráculo), contraste de cifras contra
`SPEC.md`/`TAREAS.md`/Rust, y certificación con aritmética de bolas o intervalos.

## 2 · Método

- Lectura íntegra de `src/`, `test/runtests.jl`, `run.jl`, `bench/` y `INFORME.md`, y de las partes
  relevantes de GDR-v0.2 (`veritas/consenso/ghostdag-rank-v1/src/`).
- Ejecución desde el directorio v2:
  - `env -u LD_LIBRARY_PATH julia --check-bounds=yes --project=. test/runtests.jl` → **128/128 en
    verde, 7.3 s**.
  - `env -u LD_LIBRARY_PATH julia --project=. run.jl --seed 0x5a5a --replicas 64` → terminó en
    ~4.8 s de pared, 416 MiB RSS.
- Contraste de la salida reproducida con el respaldo previo de `resultados/`: **idéntica byte a
  byte** en todos los archivos salvo `ENTORNO.txt` (solo cambia la marca de fecha UTC, esperado).
  `resultados/` se restauró a su estado original tras la prueba.
- Reproducción de `bench/io_lectura.jl`.
- Instrumentación de diagnóstico en una **copia temporal** en `/tmp/opencode/ZEROX/…` (el original
  no se modificó) para verificar D1 en varios escenarios (`delta` 0/1/2/4/8, `S` 1/2/3/24,
  con y sin adversario): se contó (a) padres con índice ≥ id (no añadidos aún a GDR),
  (b) padres con `slot ≥ slot_hijo`, (c) padres honestos con `slot + Δ > slot_hijo` (en tránsito).
- Comprobación de la huella de entrada: `sha256sum -c deepseek/ENCARGO-07v2-coste-rama-privada.sha256`
  → **OK**.

## 3 · Hallazgos

Severidad: **A** = afecta a una conclusión publicada; **M** = exactitud/robustez documental o de
borde; **B** = rendimiento/higiene. No se halló ningún defecto que invierta la conclusión global.

### D1 · Vista local antes de recibir en tránsito — **correcto (verificado)**

- `simular!` procesa entregas del slot y **después** produce contra la vista local
  (`src/dag_sim.jl:133-164`). Los bloques hermanos del mismo slot no se ven entre sí; el adversario
  no se entrega a los honestos.
- Instrumentación en copia: para `Δ ≥ 1`, **0** violaciones de “padre ≥ id” (nunca un padre sin
  añadir a GDR) y **0** casos de padre honesto en tránsito. Este era el punto central de D1 y se
  cumple.
- El único caso que falla es `Δ = 0` (ver **M1**).

### M1 · `Δ = 0` pierde todas las entregas honestas y luego aborta — **bug de borde real**

`_programar_entrega!` agenda la entrega en `slot_produccion + Δ` (`src/dag_sim.jl:113-118`) y
`_procesar_entregas!` solo la incorpora si `llegada == slot` (`src/dag_sim.jl:120-125`), sin
eliminar ni comparar por umbral. Con `Δ = 0` la entrega se agenda para el mismo slot en que
`_procesar_entregas!` ya se ejecutó (la producción ocurre después), por lo que **nunca** se
procesa: las vistas quedan solo con génesis. Al producirse un bloque en `slot > s_max = 150`
(constante fija en `src/dag_sim.jl:65`), GDR lo rechaza con `salto_mayor_smax` y `simular!` aborta
con `error(...)` (`src/dag_sim.jl:140`). Reproducido: `ConfigSim(n_honestos=4, p_honesto=0.5,
delta=0, S=2, T=200, p_adversario=0.2)` → `GDR rechazó un bloque honesto: salto_mayor_smax`.

- Impacto en lo publicado: **nulo**, porque todas las corridas de `run.jl`, tests y `DAG.txt` usan
  `Δ ≥ 1`. Pero `ConfigSim` admite `Δ = 0` sin validarlo, y el `s_max = 150` fijo no se declara en
  `MODELO.md`; cualquier configuración con vistas estancadas > 150 slots aborta en vez de degradar.
- Recomendación: rechazar explícitamente `Δ ≤ 0` en `ConfigSim`, o cambiar `_procesar_entregas!` a
  `llegada <= slot` con purga, y declarar `s_max` como parámetro.

### M2 · Señal de la deriva invertida en `INFORME.md` §1

`INFORME.md:40` publica `g_E(α) = (1−α) − α = 1 − 2α`, pero la definición del propio informe y del
encargo es `g_E = lim E[W_priv − W_pub]/T`, cuya tasa en el baseline es
`α − (1−α) = 2α − 1`. El código es correcto y consistente:
`toy_S_deriva(α,S) = S·α − (1−α)` (`src/validacion.jl:53`) y
`control_escalar_S` (`src/rfin5.jl:88`). Es un error de signo en el texto, no en el cálculo (la
raíz `α_drift = 1/2` no cambia).

### M3 · Valor numérico erróneo en `INFORME.md` §2: `(q/p)^7`

`INFORME.md:62` afirma para `d=6, α=0.4`: `(q/p)^7 = 0.0343` frente a la DP finita `T=200 = 0.0584`.
El valor correcto es `(0.4/0.6)^7 = 128/2187 = 0.0585277`. La DP finita (`resultados/CORTO.txt:13`,
`5.839257e-02`) coincide con el eventual (`≈0.05853`); por tanto la fila que los presenta como
“objetos distintos” con una brecha del 40 % es incorrecta: **coinciden casi exactamente**, que es lo
esperable a `T=200`. No afecta a la validez de la fórmula `(q/p)^(d+1)` ni a los tests, pero sí a la
tabla publicada.

### M4 · Cifras del microbenchmark de I/O no concuerdan con `INFORME.md`

`INFORME.md:124` publica `p99=0.006 ms` y `~1743 MiB/s`. `resultados/IO.txt:4-5` registra
`p99=0.003 ms`, `max=0.086`, `2230.0 MiB/s`. Una ejecución fresca de `bench/io_lectura.jl` dio
`p99=0.003 ms`, `max=0.084`, `2075 MiB/s`. El `p99` y el rendimiento del informe no se reproducen ni
coinciden con el artefacto archivado. Es una inconsistencia de documentación (no cambia que
`S_adversario` queda `Pendiente`, que es la conclusión correcta).

### M5 · `--replicas` es inerte

`run.jl` parsea `--replicas` y lo imprime en `ENTORNO.txt` (`run.jl:19,40`), pero **ninguna**
computación lo usa: `tasa_rojos_calibrada` fija `nrep=40`, `mc_superar` usa `20000`, etc. La línea
documentada y el informe sugieren 64 réplicas que no intervienen. Viola la exigencia `LINEO` §1 de
que los argumentos de la línea publicada sean significativos y reproducibles.

### M6 · `MODELO.md`/`MATRIZ-VALIDEZ.md` sobre-integran R-FIN-5 respecto al código

`MODELO.md:39-40` afirma que R-FIN-5 se comprueba “antes de colorear”, y `MATRIZ-VALIDEZ.md:11`
declara el escenario candidato como “Válida estructural”. Sin embargo `src/dag_sim.jl` **nunca** llama
a `compatible_rfin5`/`puede_incorporar_pasado`: R-FIN-5 solo existe como módulo aislado
(`src/rfin5.jl`) ejercitado por tests unitarios. `INFORME.md` §4 es más honesto (lo etiqueta
`Pendiente`), pero existe un escenario declarado que no se ejecuta. Debe rebajarse la redacción o
cablear la capa estructural.

### P1 · Asignaciones en el camino caliente del simulador — **B**

`simular!` asigna ~8.8 MB (`n=8, T=300`) y ~15.9 MB (`n=4, T=400`) por réplica. Causas:
`_puntas_vista` asigna `falses(length(sim.bloques))` en cada llamada (`src/dag_sim.jl:74`);
`_elegir_padres` ordena con clave `blue_work_bigint` (BigInt por comparación) y luego `shuffle!`
(`src/dag_sim.jl:92-95`); `_procesar_entregas!` recorre la **lista completa** de entregas en cada
slot, `O(T·E)` (`src/dag_sim.jl:120-125`); y las mediciones reconstruyen vectores con comprensiones
(`src/dag_sim.jl:156,176`). `LINEO` §3.2 pide preasignar y evitar `Dict`/temporales en bucles
masivos. Con los tamaños publicados no compromete el resultado, pero el simulador no escala.

### P2 · Campo `rng::Any` en `Simulador` — **B**

`src/dag_sim.jl:61` declara `rng::Any`, lo que provoca despacho dinámico en
`shuffle!(sim.rng, …)` (`src/dag_sim.jl:95`) y contradice la regla de tipos concretos. El tipo de
retorno de `simular!` sigue siendo concreto (`ResultadoSim`, verificado con `@code_warntype`), así
que el impacto es de rendimiento, no de corrección. Parametrizar `Simulador{R<:AbstractRNG}`.

### P3 · `exito::Function` en la DP — **B (sin acción necesaria)**

`dp_acotada` recibe `exito::Function` (`src/dp.jl:34`). Verificado con `@code_warntype`: el cuerpo
infiere `Body::ResultadoDP{Float64}`, de modo que la anotación abstracta **no** desestabiliza en este
punto de llamada. Se deja constancia para que no se confunda con una inestabilidad real.

### P4 · Escalado de hilos no medido — **B**

`resultados/BENCH.txt:7-12` imprime etiquetas de 1..8 hilos sin ninguna medición, y no hay
paralelización en el código. La reproducibilidad a 1 hilo sí se verificó. El encargo lo permite si se
declara, pero `LINEO` §7 pide medir el escalado.

### P5 · Tests de mutación solo parciales — **M (metodológico)**

`METODO.md:42` y `test/runtests.jl:169-177` afirman detectar mutaciones, pero no existe un arnés de
mutación: el testset “mutación” comprueba propiedades (`empate > superar`, cota de unión). No hay
prueba directa para “color global”, “renormalización de masa truncada” ni “aceptación
post-divergencia incompatible”, que el encargo §4 exige como regresiones obligatorias.

## 4 · Higiene LINEO — resumen

- **Tipos concretos:** correcto salvo `rng::Any` (P2). El resto de structs usan campos concretos.
- **Globals calientes:** no hay; solo `const` inmutables (`SEMILLA`, `_RUTA_GDR`).
- **`@fastmath`/`@simd`/`@inbounds`/`@threads`:** ausentes (grep sobre `*.jl`).
- **Aritmética entera para consenso:** correcto; pesos `⌊2^128/(SR+1)⌋` en `BigInt`/`BW256` exacto y
  DP sobre enteros.
- **RNG con semilla por réplica:** correcto; fábrica `r -> StableRNG(semilla + r)` en la calibración
  y semilla de CLI obligatoria. `Random123` está declarado en `Project.toml` pero no se usa.
- **Reproducibilidad 1 hilo:** verificada (suite 128/128; `run.jl` reproduce `resultados/` byte a
  byte salvo la fecha de `ENTORNO.txt`).

## 5 · Contraste `resultados/` ↔ `INFORME.md`

Coinciden: `DAG.txt` con §8 (tasa `0.5599`, IC `(0.912,1.000)`, `k=30` sin rojos, IC sup `0.088`);
`CORTO.txt` con §2 (`α_prob ≈ 0.394663`; empate `0.0876`, superar `0.0584`); `CONTROL.txt` con §6;
`RCE.txt` y `RFIN5.txt` con §4/§7; cota de unión `(0.2, 0.35)`; `VEREDICTO.txt` con la frase final.
Discrepan: §1 (signo, M2), §2 (`(q/p)^7`, M3), §9 (I/O, M4).

## 6 · Qué no verifiqué

- El coloreo de GDR-v0.2 (`ghostdag-rank-v1`): se usó como oráculo, no se auditó su corrección.
- Los números de `INFORME.md` contra `SPEC.md`, `TAREAS.md`, Rust o los contratos RCE/ARM fuente.
- La validez normativa de las reglas (`SPEC vigente` vs `candidata`); solo se comprobó que el código
  no las promueve a `Válida` cuando están ausentes.
- Cotas numéricas certificadas (no se usó `Arblib`/`IntervalArithmetic`): el intervalo de `α_prob` es
  de bisección en `Float64` y no está certificado ni se propagaron IC al cruce.
- La integración inexistente R-FIN-5 + DAG (no hay código que ejecutar).
- Ejecución multi-hilo (el código no paraleliza) y `bench/benchmarks.jl` completo.
- El entorno de hardware más allá de `ENTORNO.txt` (`znver5`, 1 hilo por defecto).

## 7 · Veredicto

**Instrumento apto de forma condicionada.** La suite pasa, el `run.jl` se reproduce de forma
determinista, la huella de entrada es válida y **D1 se cumple** (producir contra la vista local; no
hay hijos que referencien padres ausentes de GDR) para `Δ ≥ 1`. La conclusión declarada —“frontera
medida para los escenarios ensayados; umbral protocolario inconcluso”— es coherente con los
artefactos y no se ve afectada por los defectos hallados.

Antes de promover el instrumento conviene: (M1) validar/arreglar `Δ = 0` y declarar `s_max`;
(M2–M4) corregir las cifras del `INFORME.md` (signo de la deriva, `(q/p)^7`, I/O); (M5) hacer
efectivo o retirar `--replicas`; (M6) alinear `MODELO`/`MATRIZ-VALIDEZ` con el código; (P1–P2)
reducir asignaciones y parametrizar el RNG. Los hallazgos M2–M4 son de documentación/numerismo, no
alteran la dirección del resultado, pero el encargo exige que cada cifra sea verificable y aquí tres
no lo son.

**Frontera medida para los escenarios ensayados; umbral protocolario inconcluso.**
