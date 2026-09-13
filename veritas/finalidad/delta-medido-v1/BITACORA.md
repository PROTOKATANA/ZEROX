# PROGRESO — bitácora del encargo «Δ medido» (TAREAS.md 3.1)

> **Nota de migración (Claude, 2026-09-14).** Bitácora del ejecutor, migrada desde
> `deepseek/PROGRESO.md` al validar y migrar el instrumento. Las rutas `deepseek/` y los avisos
> «sin validar ni migrar» que siguen son históricos; el estado vigente está en
> `ENMIENDA-R2.md` §7 y en `TAREAS.md` §3.1.

**Ejecutor:** DeepSeek (zona aislada `deepseek/`). **Fecha:** 2026-09-13.

> ⚠ **Esto está en `deepseek/`, sin validar ni migrar. Pendiente de revisión por Claude
> antes de tocar `veritas/` real.**

## Qué hice, en orden

1. Leí la documentación obligatoria: `TAREAS.md` §3.1 y «Orden recomendado», `MIGRACION.md`
   (fila `Delta`), `veritas/finalidad/baseline-30m/MODELO.md` completo (etiquetas de
   procedencia, fila Δ del §3.2, nota «D_aut no es Δ»), `research/scripts/d9-ronda11a/informe.md`
   y `d8-ronda8/d8_lib.py` (semántica histórica `llega[bid] = t + DELTA`),
   `veritas/LINEO.md` íntegro, la plantilla y las auditorías existentes como convención.
2. Copié `veritas/plantilla/` a `deepseek/veritas/finalidad/delta-medido-v1/`, recorté
   `Project.toml` a las 4 dependencias usadas (BenchmarkTools, DataStructures, Distributions,
   StableRNGs) e instancié con `veritas/julia.sh` (nunca llamé a `julia` directo, siempre con
   `env -u LD_LIBRARY_PATH` vía el wrapper).
3. Implementé `modelo.jl` (GrafoCSR, ParametrosRed/Red, generadores de topología regular por
   conmutación y G(n,p) exacto por salto geométrico con re-muestreo de conectividad,
   latencias lognormales por arista, calendario Poisson, métricas Δ_q con rango entero
   `⌈q·n/100⌉`), `referencia.jl` (oráculo con escaneo lineal, structs, distinto al kernel),
   `rapido.jl` (heap SoA preasignado, 0 asignaciones), `validacion.jl`, tests, bench, perfil
   y `run.jl` (CLI con modos barrido/sensibilidad/escalado/caso).
4. Depuré contra tests y casos a mano (4 bugs míos encontrados y corregidos: offsets CSR,
   aristas de cierre de ciclo en el grafo regular base, tipos Int32/Int64, y un cálculo a
   mano equivocado en un test — el código tenía razón). Suite final: **25040 asserts en verde**.
5. Ejecuté: barrido principal (6 combos × 12 réplicas), sensibilidad (11 combos × 12),
   extras (128 kB y 1 MB con T=300 como control de divergencia), escalado de hilos 1→24,
   benchmark y perfil. Determinismo verificado con dos ejecuciones idénticas.
6. Escribí `INFORME.md` (10 secciones obligatorias) y este `PROGRESO.md`.

## Supuestos de red elegidos y por qué (etiquetas MODELO.md §2)

- **Topología** (H): aleatoria d-regular d=8 y G(n,p) con p=8/(n−1), re-muestreadas hasta
  conexión. d=8 ≈ número de pares típico de nodos P2P; regular = grado acotado realista,
  ER = grado con cola (para ver el efecto sobre Δ_100). Justificación del generador en
  `modelo.jl`; el muestreo regular no es exactamente uniforme (declarado).
- **Latencia por enlace** (H): lognormal mediana 80 ms / p99 500 ms, una muestra por arista,
  fija por corrida. Precedente en el repo: cola lognormal en `d8-ronda11b/r11b_lib.py:240`.
- **Ancho de banda** (H): 10 Mbit/s base (residencial típico), barrido 2/10/50 Mbit/s
  (50 = equipo supuesto del modelo B350, `ZEROX-EN-NUMEROS.md` L156).
- **Tamaño de bloque** (D/E/P): 683 B base (ancla §6 L478: ~4 padres × 32 B; la cabecera DAG
  final está pendiente, TAREAS 1.4); barrido hasta 1 MB; 128 kB = la estimación histórica
  del repo (informe-52 L42).
- **Propagación** (H): inundación hop-by-hop, cada nodo reenvía una vez a todos sus vecinos,
  cola de transmisión **serial por nodo** (store-and-forward; sesgo declarado en INFORME §8).
- **Procesado por salto** (H con MH de fondo): 0 base; 0,1 s en sensibilidad ≈ la verificación
  PoT medida del ancla (96,1 ms/slot).
- **λ=1/s** (E, nominal A″). **100 % honestos** (H; fracción que no reenvía = trabajo futuro).
- **Sin MR disponible** para Δ — todo lo medido es MS; dicho en el INFORME tal cual.

## Resultados en una línea

Con bloques de cabecera (683 B): Δ_100 mediano ≈ **0,24–0,44 s** (regular) y **0,26–0,79 s**
(ER) — muy por debajo del mínimo histórico de 4 s. Con 128 kB @ 10 Mbit/s: **Δ_100 med ≈ 5,1 s**
(la banda histórica 4–8 s). 1 MB satura (ρ>1, divergente). Detalle: `INFORME.md` §4–§6.

## Qué NO hice y por qué (recortes, con números)

- N máximo 10000: el paso a 100000 habría costado ≈10× (eventos ~ N·d·H: 48 M → 480 M por
  corrida, ~40 s/1 hilo cada una, ~25 min de CPU el barrido completo) sin cambiar el orden
  de magnitud (Δ escala con el diámetro ~log N). El barrido principal completo costó **13,9 s**
  de pared con 24 hilos.
- 2 topologías (no small-world): el encargo pedía ≥2; regular y ER cubren los extremos
  grado fijo/variable. Un barrido «3 topologías × 4 N × 24 réplicas» habría costado ≈4×
  (~1 h de CPU) sin nueva conclusión.
- 12 réplicas por combo (el mínimo histórico del repo, p. ej. d9-ronda11a).
- No se modeló: paquetes perdidos, churn, retardo adversarial, fracción no honesta,
  colas de recepción, slots/PoT, ni el protocolo de red ZEROX (no existe).

## Preguntas abiertas para Katana

1. ¿Qué ancho de banda mínimo de subida es aceptable para un operador ZEROX? (política)
2. ¿Tamaño realista del bloque DAG definitivo (683 B vs ~100 kB vs más)? (TAREAS 1.4)
3. ¿Qué percentil de Δ gobierna el diseño (Δ_50 med vs Δ_100 p99)? (tolerancia)
4. ¿Incluir coste de validación por salto en Δ operativo? (depende de la regla
   «verificar PoT por slot por gossip», informe-52 §1a-ii)
5. ¿Siguiente iteración con adversario de red y nodos que no reenvían?

## Verificaciones finales pendientes para Claude

- `git -C /home/katana/zeo/ZEROX status --short` no muestra cambios fuera de `deepseek/`
  (sólo el `TAREAS.md` modificado que ya estaba así al empezar).
- `cargo test --workspace`, `cargo fmt --check`, `cargo clippy`: no los ejecuté (no toqué
  ningún crate); deben dar el mismo resultado que antes del encargo.
- `julia --project=deepseek/veritas/finalidad/delta-medido-v1 test/runtests.jl`: verde
  (25040 asserts).

---

# Revisión 2 (enmienda del 2026-09-13, encargo de Katana)

## Qué hice, en orden

1. Leí las lecturas obligatorias del encargo: TAREAS.md (decisiones Q1–Q5), el instrumento
   completo, LINEO.md, el hermano migrado `retarget-causal-endogeno-v1/` (ENMIENDA-Z0,
   METODO, MODELO, CONTRATO, HUELLAS, julia-version, TESTS.txt), SPEC.md:2160-2519,
   baseline-30m/MODELO.md, d9-ronda11a/informe.md y dag-poas-ancla-de-orden.md.
2. `git status --short` al empezar = ` M TAREAS.md` (esperado). Calculé los sha256 de las 10
   fuentes del METODO al empezar (quedan en `FUENTES-R2.sha256` del instrumento).
3. **Reparación de procedencia:** copié `resultados/barrido-principal/` y
   `resultados/sensibilidad/` a `resultados/r1-reproduccion-claude-8hilos/` con `LEEME.txt`,
   y regeneré ambas carpetas con 24 hilos y el código r1 sin modificar.
4. **Derivaciones a mano ANTES de ejecutar** en `ENMIENDA-R2.md` §2 (D1–D8), con fecha y
   hora (2026-09-13 22:59 CEST).
5. Añadí código NUEVO: funciones de objetos/ρ/cuotas/medias en `modelo.jl`; testsets nuevos
   en `test/runtests.jl`; modo `--r2` (subtareas rejilla/concentracion/tproc/saturacion) en
   `run.jl`. Nada de la r1 cambió.
6. Ejecuté la suite con `--check-bounds=yes`: 25 593 asserts en verde (1 fallo propio en la
   primera pasada: comparación `==` con NaN; corregido el test a `isequal`, escrito en la
   enmienda). Salida en `resultados/TESTS.txt`.
7. Ejecuté la r2 completa DOS veces (reproducibilidad): rejilla 132 s/24 hilos, más
   concentración, tproc y saturación. Idénticas salvo `segundos_pared`.
8. Re-ejecuté la r1 (barrido y sensibilidad) al final: `resumen.csv` byte a byte con el
   paso 3; `corridas.csv` sólo difiere en `segundos_pared`.
9. Escribí INFORME.md revisión 2, MODELO.md, CONTRATO.md (DMS-v0.1), METODO.md (con las
   fuentes y sus sha256), ENMIENDA-R2.md y julia-version.toml. **No generé HUELLAS.sha256**
   (lo genera Claude al migrar).

## Comandos EXACTOS ejecutados (todos con `veritas/julia.sh`, JULIA_NUM_THREADS ≤ 24)

```bash
# tests
env JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 /home/katana/zeo/ZEROX/veritas/julia.sh \
  --project=/home/katana/zeo/ZEROX/deepseek/veritas/finalidad/delta-medido-v1 --check-bounds=yes \
  /home/katana/zeo/ZEROX/deepseek/veritas/finalidad/delta-medido-v1/test/runtests.jl \
  > .../resultados/TESTS.txt

# r1 (reparación de procedencia y control final)
JULIA_NUM_THREADS=24 OPENBLAS_NUM_THREADS=1 env -u LD_LIBRARY_PATH \
  /home/katana/zeo/ZEROX/veritas/julia.sh --project=.../delta-medido-v1 .../run.jl            # 13,78 s
JULIA_NUM_THREADS=24 OPENBLAS_NUM_THREADS=1 env -u LD_LIBRARY_PATH \
  /home/katana/zeo/ZEROX/veritas/julia.sh --project=.../delta-medido-v1 .../run.jl --sensibilidad

# r2 (cuatro subtareas, dos pasadas cada una)
JULIA_NUM_THREADS=24 OPENBLAS_NUM_THREADS=1 env -u LD_LIBRARY_PATH \
  /home/katana/zeo/ZEROX/veritas/julia.sh --project=.../delta-medido-v1 .../run.jl --r2 --r2-subtarea rejilla
# ... concentracion / tproc / saturacion (misma forma)
```

## Recortes (con números)

- **No apliqué el recorte opcional** (quitar N=10000 del objeto de 716 B): la rejilla
  completa (720 corridas) costó 132,1 s de pared con 24 hilos, dentro del presupuesto
  declarado de ≤5 min. Coste estimado en ENMIENDA-R2 D7: ≈1 105 hilo-s → 46 s ideales;
  real 132 s (overhead de cola de trabajos y n=10000).
- Precisión de trazas: `medias_nodo` en µs enteros para caber en disco; `resultados/`
  total = **47 MB** (< ~50 MB orientativo).

## Diferencias encontradas con TAREAS.md

- Ninguna en las decisiones Q1–Q5: las usé tal cual (100 y 59,67 Mbit/s; objetos Q2; Δ_99
  p99 provisional; media por bloque/nodo; hipótesis de concentración).
- La subtarea `sensibilidad/` de la r1 NO la había sobrescrito la reproducción de Claude
  (su ENTORNO conservaba 24 hilos y 5,26 s): aun así la copié y re-ejecuté; comparación
  byte a byte OK. Dicho en ENMIENDA-R2 §5.

## Preguntas para Claude o Katana

1. **Redacción truncada del encargo §5.6**: «con la base r2 (1008 y 27 596 B)». Lo
   interpreté como «100 Mbit/s, objetos de 812 B y 27 596 B»; publiqué Δ_99 p99 de TODA la
   rejilla (5 objetos × 2 anchos × 2 topologías × 3 N) y designé la base 812 B @ 100 Mbit/s.
   Si la base debía ser otra (p. ej. el objeto de 716 B), es un cambio de una línea en
   INFORME §11.3.
2. **Δ̄ espacio ≈ Δ̄ uniforme** (diferencias ≤0,5 %): la hipótesis de concentración sintética
   (por ID de nodo, sin correlación con la topología) no mueve la media. ¿Katana quiere
   alguna otra forma de concentración (p. ej. correlacionada con la posición/centralidad en
   el grafo) antes de migrar, o se deja para la portada de δ₀?
3. **`HUELLAS.sha256` y `TESTS.txt` en `resultados/`**: el TESTS.txt de la r2 está en la
   raíz de `resultados/` del instrumento (como pide el encargo), no en una subcarpeta por
   modo. El hermano RCE lo tiene en `resultados/TESTS.txt` igual; confirmado por convención.
4. El `resumen.csv` de concentración guarda Δ̄ de espacio por pool; los cuantiles de Δ se
   guardan igual (son estables, ρ<1). Confirmo que es correcto publicarlos: en §11.4 solo
   uso Δ̄ y la fracción de creadores.

> **Esto está en `deepseek/`, sin validar ni migrar.**

---

# Revisión 2 · corrección (tras la validación de Claude, 2026-09-13)

## Qué corregí y en qué orden

1. Copié `resultados/` → `deepseek/resultados-pre-correccion/` (base de comparación del
   criterio 3).
2. Escribí ANTES de ejecutar la derivación T1 del test nuevo en `ENMIENDA-R2.md` §6
   (2026-09-13 23:43 CEST): sorteo ∝ cuota → 5/4 = 1,25; sorteo uniforme → 1,25; la regla
   doble → 11/10 = 1,1.
3. Corregí el error de método (la cuota se contaba dos veces): `delta_barra_espacio` →
   `delta_barra_sorteo_por_cuota` (regla i, media simple) y `delta_barra_peso_por_creador`
   (regla ii, solo con sorteo uniforme); `run.jl` acumula `num += mb; den += 1`. Actualicé
   exports, el test D4 (caso simétrico, sigue dando 2,0) y añadí el testset T1.
4. Re-ejecuté en orden: suite con `--check-bounds=yes` → TESTS.txt; r1 barrido (14,2 s) y
   sensibilidad (6,16 s); r2 rejilla (134,6 s), concentracion (1,18 s), tproc (0,69 s) y
   saturacion (0,85 s), todo con 24 hilos.
5. Actualicé INFORME §10 (25 598 asserts), §11.3 (añadida la línea de 4 238 B) y §11.4
   (tabla corregida + explicación de simetría + v2b), MODELO.md y CONTRATO.md (regla i), y
   ENMIENDA-R2 (discrepancia 2 de D8, §3 marcado como corregido, §6 nueva).

## Comandos exactos

```bash
cp -a deepseek/veritas/finalidad/delta-medido-v1/resultados deepseek/resultados-pre-correccion
env JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 veritas/julia.sh \
  --project=deepseek/veritas/finalidad/delta-medido-v1 --check-bounds=yes \
  deepseek/veritas/finalidad/delta-medido-v1/test/runtests.jl > .../resultados/TESTS.txt
JULIA_NUM_THREADS=24 OPENBLAS_NUM_THREADS=1 env -u LD_LIBRARY_PATH veritas/julia.sh \
  --project=deepseek/veritas/finalidad/delta-medido-v1 deepseek/veritas/finalidad/delta-medido-v1/run.jl
JULIA_NUM_THREADS=24 OPENBLAS_NUM_THREADS=1 env -u LD_LIBRARY_PATH veritas/julia.sh \
  --project=deepseek/veritas/finalidad/delta-medido-v1 deepseek/veritas/finalidad/delta-medido-v1/run.jl --sensibilidad
# y --r2 --r2-subtarea {rejilla, concentracion, tproc, saturacion}, misma forma
```

## Resultado de las comparaciones (criterio 3)

- `resumen.csv` idénticos byte a byte con `resultados-pre-correccion/` en: barrido-principal,
  sensibilidad, r2-rejilla, r2-tproc, r2-saturacion. El de r2-concentracion difiere SOLO en
  la columna `delta_barra_espacio_s` (columnas 1–18 y 20+ idénticas).
- Todas las trazas `medias_bloque-*`, `medias_nodo-*` y `media_bloque_espacio-*` idénticas
  byte a byte (incluida la de concentración).
- `corridas.csv`: solo difieren en `segundos_pared`; el de concentración además en
  `delta_barra_espacio_s`.
- Valores corregidos de Δ̄ espacio (control de Claude, ≥5 decimales): 1101 → **0,21937**,
  1102 → **0,21457**, 1103 → **0,25767**, 1104 → **0,25657** — coinciden.
- Suite: **25 598 asserts** en verde (5 nuevos de T1, exactamente lo derivado).

## Respuestas a mis preguntas de la r2 (anotadas)

- **P1** («base r2 1008…»): el texto del encargo decía «objetos de 812, 4 238 y 27 596 B»;
  añadida la línea de 4 238 B a INFORME §11.3.
- **P2** (concentración correlacionada con centralidad): NO se implementa; queda como
  hipótesis para el v2b. §11.4 lo dice.
- **P3 y P4** (TESTS.txt en resultados/, cuantiles de concentración en resumen.csv):
  correcto como está; sin cambios.

> **Esto está en `deepseek/`, sin validar ni migrar.**
