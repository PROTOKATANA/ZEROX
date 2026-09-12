# Bitácora — Comprobación decisiva v1 (etapa A)

Zona de escritura: solo `/home/katana/zeo/ZEROX/deepseek/`.
Formato: entradas fechadas con comando ejecutado, resultado y decisión.

## 2026-09-12 16:10 — Apertura

- **HEAD de git**: `7b783d4` (`7b783d469fbae5722a0ae014b5e212ed6999eb2b`,
  "d16: gate de igual epsilon — la formula adaptativa queda REFUTADA; A se reduce a
  baseline + C", 2026-09-10 17:18:36 +0200). Sin cambios locales aplicados por esta
  tarea; `deepseek/` se crea vacío y sin versionar.
- **Decisiones confirmadas con el usuario**:
  - Frontera estricta: toda escritura dentro de `deepseek/`; fuera, solo lecturas
    (motores DCM-v0.1/RCE-v0.1 por inclusión relativa, SPEC/MIGRACION/LINEO).
  - Sin commits ni push; único efecto lateral externo = caché de precompilación de
    Julia (`~/.julia`).
  - Plan aprobado para ejecutar sus 6 etapas.
- **Comando**: `git rev-parse --short HEAD` + `git log -1` (lectura).
- **Estructura creada**: `deepseek/bitacora/`, `deepseek/comprobacion-decisiva-v1/`
  con `src/ test/ bench/ resultados/`.
- **Rutas verificadas (lectura)**:
  - DCM: `veritas/consenso/disponibilidad-causal-multivista-v1/src/DisponibilidadCausalMultivista.jl`
  - RCE: `veritas/consenso/retarget-causal-endogeno-v1/src/RetargetCausalEndogeno.jl`
  - Patrón de inclusión: `veritas/consenso/admision-retarget-multivista-v1/src/AdmisionRetargetMultivista.jl:3-8`
  - `veritas/julia.sh` (para etapa 5), plantilla LINEO en `veritas/plantilla/`.
- **Escrito**: `deepseek/PLAN.md`.

## 2026-09-12 16:11 — Etapa 2: esqueleto

- **Escrito**: `comprobacion-decisiva-v1/Project.toml` (uuid nuevo
  `93d941db-044d-4193-a933-2e9bae14e3c3`, deps BenchmarkTools 1.8 + JET 0.12,
  julia 1.13, patrón ARM), `julia-version.toml` (1.13.0).
- **Generado por Julia**: `Manifest.toml` con
  `veritas/julia.sh --project=. -e 'using Pkg; Pkg.resolve(); Pkg.instantiate()'`
  (julia 1.13.0, exit 0). Efecto lateral: precompilación en `~/.julia` (declarado).
- Directorios `src/ test/ bench/ resultados/` ya creados, vacíos.

## 2026-09-12 16:20 — Etapas 3 y 4: implementación del modelo

- **Escrito**: `src/ComprobacionDecisiva.jl` (módulo que incluye DCM/RCE por ruta relativa,
  sin editar), `src/modelo.jl` (capa económica entera, peso dedup/naive, dos nodos con
  colas, replay! con publicación conjunta), `src/referencia.jl` (reescaneo + BigInt),
  `src/rapido.jl` (cursor + UInt128), `src/validacion.jl` (fixtures deterministas).
- **Decisiones de diseño**:
  - Billete (`ticket` DCM) = oportunidad; copias comparten billete y difieren en
    `piece_offset`/`variant`; el control naive agrupa por la tupla completa.
  - Doble gasto/entrada desconocida/colisión de salida → `nothing` en el barrido económico
    → `DCM.Invalid` sin publicar. Dinero en `UInt64` con `Base.Checked`, sin Float64.
  - Fixture principal: objetivo H700→H701 (copia RedK 6 del billete 1), respaldo
    independiente H800→H801; Ana retiene el cuerpo de la copia 6, Bruno el del ganador 1.
- **Errores encontrados y corregidos en camino** (declarados):
  1. Test esperaba `available` sin las UTXOs de génesis no consumidas (106..110) — error
     de expectativa, no del modelo; corregido el test.
  2. `fixture_rama` generaba truth solo para bloques propios; DCM exige contextos de
     ancestros bajo la historia aplicante (por eso ARM usaba el producto completo).
     Corregido a producto completo. El bench fallaba en reorg por esto; re-ejecutado.

## 2026-09-12 16:37 — Etapa 5: suite completa registrada

- **Comandos ejecutados** (todos `env JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1
  JULIA_PKG_PRECOMPILE_AUTO=0 timeout 60s veritas/julia.sh --project=.`):
  - `--check-bounds=yes test/runtests.jl --seed 20260912` → exit 0, **280/280 asserts**.
  - `run.jl --seed 20260912` → exit 0, veredicto completo en `resultados/RUN.txt`.
  - `bench/benchmarks.jl --seed 20260912` → exit 0 (depth 8/16/32, ref vs fast).
  - `bench/perfil.jl --seed 20260912` → exit 0 (JET 13 dispatches en deepcopy,
    `code_warntype_any=false`, retorno `Outcome`, 1.44 MB por replay con copia fresca).
- **Artefactos**: `resultados/TESTS.txt`, `RUN.txt`, `BENCH.txt`, `PERFIL.txt`,
  `ENTORNO.txt` con entorno, comando y exit_code.
- **Cifras clave**: convergencia exacta (pagos 6/6, consumos 6/6, totales 3000/5500,
  retarget idéntico 200@20 y 400@30), peso dedup 5 vs naive 6 (rango 200 vs 166), doble
  gasto Invalid sin publicar, reloj local detectado, HeldZero documentado (100@40).
- Efecto lateral declarado: solo caché de precompilación de Julia (`~/.julia`).

## 2026-09-12 16:45 — Etapa 6: informe y cierre

- **Escrito**: `comprobacion-decisiva-v1/INFORME.md` con el veredicto por requisito
  (13 requisitos: todos demostrados en el modelo declarado; límites pendientes listados).
- **Bitácora cerrada.** Sin commits, sin push. Todo el trabajo dentro de
  `/home/katana/zeo/ZEROX/deepseek/`.

## 2026-09-12 18:39 — Tanda 1: cierre de la unicidad pagable (P1 azul primero)

- **HEAD de git**: `7b783d4`, sin cambios. Z0/HeldZero intactos: no se tocó
  `causal_step`, ni `StepHeldZero`, ni `range_at_40 == 100` (fuera de alcance).
- **Escrito**:
  - `comprobacion-decisiva-v1/src/validacion.jl`: `fixture_copias_rojas_sin_azul`,
    `fixture_desempate_color`, `fixture_copia_en_fusion_posterior` (estilo existente:
    nombres en español, UInt64, `test_controller()`, width 10, grace 0).
  - `src/ComprobacionDecisiva.jl`: exportados los tres fixtures.
  - `test/runtests.jl`: `@testset` «unicidad pagable: copias rojas, desempate de color
    y copia en fusión posterior» (93 asserts): cada vector en las 4 combinaciones
    {P0,P1}×{Reference,Fast}; Vector 1 además con orden de entrega invertido
    (proyección idéntica); Vector 2 afirma P0≠P1 y P1 elige el azul; Vector 3 con
    `@test_throws ArgumentError` documentando que DCM.Catalog rechaza
    «ticket changes origin window» (las dos guardas no se pueden aislar).
  - `INFORME.md`: límite H7 en «Límites declarados» + tabla corta nueva «Unicidad
    pagable (§7.2) — vectores añadidos (tanda 1)» con el hallazgo de las dos guardas.
  - `BORRADOR-SPEC-7.2.md`: borrador del párrafo normativo (NO aplicado a SPEC.md).
- **Comandos** (todos `env JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1
  JULIA_PKG_PRECOMPILE_AUTO=0 timeout 60s veritas/julia.sh
  --project=deepseek/comprobacion-decisiva-v1`, semilla 20260912):
  - `--check-bounds=yes test/runtests.jl --seed 20260912` → exit 0, **373/373 asserts**.
  - `run.jl --seed 20260912` → exit 0.
  - `bench/benchmarks.jl --seed 20260912` → exit 0.
  - `bench/perfil.jl --seed 20260912` → exit 0.
  - Captura de ENTORNO → `resultados/ENTORNO.txt` (exit 0).
- **Asserts**: línea base 280/280 (16:37) → **373/373** (18:37), delta **+93**, 0
  regresiones.
- **Discrepancias contra el prompt: NINGUNA.** Todos los valores medidos coincidieron
  con los declarados (observed=2, pagos y totales de los tres vectores, propuestas,
  P0≠P1, `[1,1]`). Valores derivados del Vector 1 calculados y asertados:
  `consumptions=[(700,3,103,1000),(700,2,101,1000)]`,
  `available=[(102,1000),(104,1000),(105,1000),(1002,500),(1003,500)]`,
  `total_consumed=2000`. Ninguna expectativa se ajustó para pasar.
- **Artefactos refrescados**: `resultados/TESTS.txt`, `RUN.txt`, `BENCH.txt`,
  `PERFIL.txt`, `ENTORNO.txt`.
- **Efecto lateral declarado**: solo caché de precompilación de Julia (`~/.julia`).
  Sin commits, sin push; toda escritura dentro de `/home/katana/zeo/ZEROX/deepseek/`.

## 2026-09-12 19:00 — Tanda 1-bis: correcciones del borrador §7.2 + vector de reorg

- **Línea base guardada**: `resultados/TESTS-linea-base-373.txt` (373/373 de la tanda 1).
- **Escrito**:
  - `src/validacion.jl`: `fixture_reorg_libera_billete` (mismo billete 1 en dos ramas
    competidoras; la historia 800 declara `window=700` por la restricción de ventana de
    origen única por billete de DCM.Catalog).
  - `src/ComprobacionDecisiva.jl`: exportado `fixture_reorg_libera_billete`.
  - `test/runtests.jl`: `@testset` «unicidad pagable: reorg libera el billete en la
    rama que prevalece» (76 asserts, 4 combos) + nitpick: el `@test_throws` del vector
    3 ahora fija el mensaje concreto (`@test_throws "ticket changes origin window"`).
  - `INFORME.md`: fila del vector de reorg en la tabla de unicidad pagable y conteo
    280→449 (tanda 1: +93; tanda 1-bis: +76).
  - `BORRADOR-SPEC-7.2.md`: correcciones B1 (sección «Relación con R-FIN-8′»: la regla
    REFINA R-FIN-8′(1), 4 puntos con el orden de las dos reglas), B2 (eliminado
    «y por ventana»; ninguna frase admite cobrar dos veces en ventanas posteriores),
    B3 (reorg respaldado por `fixture_reorg_libera_billete` + consecuencia de
    reconstrucción desde génesis), B4 («retirado como política de consenso de ZEROX»;
    P0 sigue en el instrumento como política de estudio), B5 (conjunto candidato:
    azules y `rojo_k`; `rojo_U3` excluidos — `eligible()` en DCM-v0.1).
- **Comandos** (mismo presupuesto, semilla 20260912, `JULIA_NUM_THREADS=1`,
  `OPENBLAS_NUM_THREADS=1`, timeout 60s, `veritas/julia.sh --project=deepseek/comprobacion-decisiva-v1`):
  - `--check-bounds=yes test/runtests.jl --seed 20260912` → exit 0, **449/449**.
  - `run.jl --seed 20260912` → exit 0; `bench/benchmarks.jl` → exit 0;
    `bench/perfil.jl` → exit 0; captura ENTORNO → exit 0.
- **Asserts**: 373/373 (línea base guardada) → **449/449**, delta **+76**, 0 regresiones.
- **Discrepancias: NINGUNA.** La derivación del auditor del vector de reorg se confirmó
  íntegra al medir: rama A `(700,1,1001,500)`/500/1000; tras reorg
  `(800,20,1020,777)`/777/1000, `available` de 5 UTXOs, `consumed={1}`, `observed=[1]`,
  `proposals=[(800,0,20,200)]`. Ninguna expectativa se ajustó.
- **Nitpick verificado con fallo deliberado**: `@test_throws "ticket changes origin
  window"` pasa por el motivo correcto; con un mensaje esperado distinto el test FALLA
  (`Test.FallbackTestSetException`), igual que sin excepción. Probado en proceso aparte.
- **Artefactos refrescados**: `TESTS.txt`, `RUN.txt`, `BENCH.txt`, `PERFIL.txt`,
  `ENTORNO.txt`; conservada `TESTS-linea-base-373.txt`.
- **Efecto lateral declarado**: solo caché de precompilación de Julia (`~/.julia`).
  Sin commits, sin push; toda escritura dentro de `/home/katana/zeo/ZEROX/deepseek/`.

## 2026-09-12 19:50 — Tanda 2: promoción a veritas/ y actualización del SPEC- **Decisión de usuario (consultada):** la comprobación `grep -rn "deepseek"` se aplica a
  las rutas operativas obsoletas (comandos, referencias cruzadas de INFORME/SPEC/
  research); los documentos de procedencia (esta bitácora, la nota de METODO.md, los
  hechos del auditor) conservan «deepseek» como registro histórico veraz.
- **Movimientos**: `deepseek/comprobacion-decisiva-v1/` →
  `veritas/consenso/comprobacion-decisiva-v1/` (íntegro). `deepseek/bitacora/BITACORA.md`
  → `BITACORA.md` (este fichero, tal cual). `deepseek/PLAN.md` → `METODO.md` (título +
  nota de promoción, resto intacto). `deepseek/INFORME-AUDITORIA.md` →
  `AUDITORIA-EXTERNA.md` (rutas corregidas, nota de estado añadida; hallazgos y cifras
  intactos). `deepseek/BORRADOR-SPEC-7.2.md` → contenido incorporado a SPEC.md §7.2;
  el fichero no se conserva. `deepseek/chat.txt` queda (transcripción de trabajo,
  retirada deliberada del repo según MIGRACION.md).
- **Escrito fuera de deepseek/ (solo lo autorizado)**:
  - `SPEC.md` §7.2: C1 — párrafo de la laguna sustituido por el contenido del borrador
    (sin cabecera de estado; citas a `veritas/consenso/comprobacion-decisiva-v1/`);
    incluye el pendiente nuevo de recompensa del bloque honesto tardío (E1). C2 —
    eliminado «cerrar esa unicidad y,» del párrafo «Pendiente»; «fusiones fuera de
    ventana» intacto. Sin IDs de regla (C3).
  - `research/dag-poas-ancla-de-orden.md`: una línea de cierre en la laguna de
    R-FIN-8′/13′ (cerrada en SPEC §7.2 el 2026-09-12, evidencia en veritas/).
  - `veritas/consenso/comprobacion-decisiva-v1/`: includes corregidos al idioma ARM
    (A1), barrido de rutas en INFORME.md, límite nuevo de recompensa tardía (E2).
- **Comandos** (desde la raíz, semilla 20260912, 1 hilo, BLAS 1, timeout 60s):
  - `--check-bounds=yes test/runtests.jl` → exit 0, **449/449**.
  - `run.jl` → exit 0; `bench/benchmarks.jl` → exit 0; `bench/perfil.jl` → exit 0.
  - `bash ci/citas-spec.sh` → exit 0 (169 reglas OK); `bash ci/alcance-consenso.sh` →
    exit 0 (2 crates OK).
- **Asserts**: 449/449 desde la nueva ubicación, sin cambios por el movimiento.
- **Discrepancias**: ninguna. Ninguna expectativa se ajustó.
- **Artefactos refrescados**: `resultados/{TESTS,RUN,BENCH,PERFIL,ENTORNO}.txt` con la
  nueva ruta (ENTORNO muestra `veritas/consenso/comprobacion-decisiva-v1/Project.toml`).
- **Efecto lateral declarado**: solo caché de precompilación de Julia (`~/.julia`).
  Sin commits, sin push.

## 2026-09-12 22:00 — Enmienda Z0 (HeldZero no-op) aplicada por el ejecutor DeepSeek

- **Qué cambia aquí**: la semántica HeldZero descrita en entradas anteriores (100@40,
  `range_at_40 == 100`, «discrepancia legada documentada») queda **superada** por la
  enmienda Z0 de RCE-v0.1 revisión 2 (decidida por Katana el 2026-09-12 sobre el hallazgo
  H1 de `AUDITORIA-EXTERNA.md`). HeldZero es no-op: sin propuesta, `activation_slot=0`,
  `range_at(40)=200`; convergencia exacta con el helper Rust.
- **Ficheros tocados aquí**: `src/validacion.jl` (`fixture_heldzero` y `verificar_heldzero`),
  `test/runtests.jl` (testset renombrado «ventana vacía con HeldZero: convergencia
  Julia–Rust tras la enmienda Z0»), `run.jl` (campo `heldzero_convergencia`), `INFORME.md`,
  `METODO.md` (nota). Ejecución completa registrada en `deepseek/z0-no-op-v1/`.
- **Asserts**: 449/449 → **451/451** (enmienda Z0: +2), 0 regresiones. Suite verde con
  `--seed 20260912`.
- Las entradas anteriores de esta bitácora son registro histórico fechado de lo que se
  midió entonces; no describen la semántica vigente.

