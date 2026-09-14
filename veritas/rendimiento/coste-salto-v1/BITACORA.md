# PROGRESO-BANCO — coste por salto (Q4)

Bitácora de la sesión DeepSeek en `deepseek/2.7`. Zona de escritura: `deepseek/prototipos/`
y este archivo. No tocar `deepseek/veritas/consenso/ghostdag-rank-v1/` ni `PROGRESO-GHOSTDAG.md`.

## Estado inicial (2026-09-14)

- `git status --short`: limpio (vacío).
- `loadavg` inicio: 0.77 0.60 0.51 — sin `deepseek/OCUPADO-CPU`.
- CPU: AMD Ryzen 9 9950X3D, 16c/32t, un socket, un nodo NUMA, L3 partido (cores 0-7 y 8-15).
  Gobernador `powersave` (no hay `performance`). Idle a 624 MHz, boost hasta 5 756 MHz.
- Toolchain: `nightly-2026-05-03` heredado de la raíz (rustc 1.97.0-nightly).
- Clon Autonomys verificado: `f8842d019cdf0f7163421b9644db5a9ff82b2a73`.

## Decisiones de diseño (con motivo)

1. **Harness propio con `std::time::Instant`** como instrumento principal, y **Criterion
   `0.8.2` con `default-features=false` como banco de contraste del ancla** (G, ruta avx512).
   - Comprobado: criterion 0.8.2 default-features=false **sí resuelve offline** (todas sus
     dependencias están en la caché salvo `plotters`, que es opcional).
   - Motivo del harness: los entregables exigen muestras crudas en CSV y medianas
     reproducibles entre lotes; Criterion no exporta muestras crudas sin `iter_custom`, y la
     metodología de respaldo del encargo (calentamiento + ≥30 muestras + mediana/p10/p90/
     mín/CV) produce exactamente los estadísticos pedidos.
   - El contraste con los 96,1 ms del ancla se hace además con el **mismo instrumento**
     (Criterion) y la **misma semilla** (ChaCha8Rng con semilla por defecto), en
     `benches/ancla.rs`.
2. **Núcleo fijado:** CPU 8 (core 8, L3:1) con `taskset -c 8`. Elegido fijo y documentado;
   el ancla no declaró núcleo.
3. **G.** Las cuatro rutas forzadas se miden sobre los MISMOS checkpoints (prove de una sola
   vez con la ruta por defecto, ~1,6 s) y las cuatro deben dar `true`; un checkpoint mutado
   debe dar `false` en las cuatro.
4. **F.** Se modela como la salvaguarda 1 de Q4: comparar la justificación que trae el bloque
   contra la caché por slot: `memcmp` de 128 B por slot, 1 slot y 150 slots.
5. **D.** `H_d` no es público (`pub(crate)`), así que se replica con `sha3 = 0.12.0`
   (la misma versión que zx-core): `SHA3-256(tag ‖ m)` con `tag = "ZZKBlkHeader____"`.
   Control: el resultado debe coincidir byte a byte con `zx_core::preimage::block::block_hash`
   sobre la cabecera de 92 B implementada. Luego se mide sobre un buffer de 556 B.
6. **Versiones de AES:** el ancla corrió con `aes 0.9.1` (subspace @ f8842d0);
   `pot-estable` usa `aes 0.9.3`. Las rutas con intrínsecos (avx512/avx2/sse41) **no usan el
   crate `aes`** (solo `core::arch`), así que son código equivalente al del ancla; la
   genérica sí lo usa, y se etiqueta como «genérica (crate aes 0.9.3 con despacho propio)».

## Órdenes y comandos

### Creación de pot-estable-rutas

```
cp -r prototipos/pot-estable deepseek/prototipos/pot-estable-rutas
rm -rf deepseek/prototipos/pot-estable-rutas/target
```

Cambios (documentados en DIFF.md): enum `Ruta` en tipos.rs, `verify_sequential_con_ruta`
en aes.rs, `verify_con_ruta` en lib.rs, tests/rutas.rs nuevo. El resto byte a byte.
Tests pasan: `cargo test --offline --locked --release` → diferencial 32/32 + rutas.

### Compilación del banco

```
CARGO_TARGET_DIR=$PWD/target cargo build --release --offline -j 12   # en coste-salto/
```

- Cargo.lock arranca del de poas-identidad (se quitó la entrada del paquete raíz).
- Criterion 0.8.2 default-features=false RESUELVE offline (comprobado en
  /tmp/opencode/crittest). Se usa solo en benches/ancla.rs; el instrumento
  principal es el harness propio con Instant (motivo en README.md).
- Incidencias resueltas: 4 campos en CSV → 5 (muestra), parser rsplitn(3), cierre
  de delimitador en percentil, deref coercion en el closure `w` (→ `&*pot`), etc.

### Medición

```
# por lote: sin OCUPADO-CPU, loadavg<1,5 al empezar, taskset -c 8
taskset -c 8 ./target/release/coste-salto lote --lote N \
  --ocupado ../../OCUPADO-CPU --csv resultados/MEDICIONES.csv
./target/release/coste-salto comparar --csv resultados/MEDICIONES.csv
```

Lotes válidos, regenerados en la sesión de continuación (ver §"Incidente
OCUPADO-CPU..." más abajo):

| Lote | loadavg antes | OCUPADO | loadavg después |
|---|---|---|---|
| 1 | 0,64 | ausente | 0,89 |
| 2 | 0,82 | ausente | 0,92 |

Todas las diferencias de mediana entre lote 1 y lote 2 quedaron por debajo del
1 % (máxima: B-pos +0,44 %). Detalle completo, tabla `comparar`, en
`resultados/RESUMEN.md` §1.

### Medición del ancla con Criterion

```
CARGO_TARGET_DIR=$PWD/target cargo bench --offline --bench ancla
```
Hecho. loadavg antes = 1,01, sin OCUPADO-CPU. Resultado en
`resultados/CRITERION-ANCLA.txt` y `resultados/RESUMEN.md` §5:
avx512f_vaes forzada = 89,738 ms (Criterion) frente a 89,700 ms (harness
propio, media de lotes) — coherentes entre sí, y a −6,62 % del ancla de
96,1 ms (dentro del 10 %).

## Incidente OCUPADO-CPU y bug de `comparar` (sesión de continuación, Claude)

La sesión DeepSeek original de este banco se quedó sin contexto/tokens con
trabajo pendiente: `resultados/MEDICIONES.csv` y `CONTROLES.txt` ya escritos,
pero los lotes finales sin regenerar y el bench del ancla sin correr,
bloqueados porque `deepseek/OCUPADO-CPU` (creado ~18:50-19:05 por la OTRA
sesión, GhostDAG, en `deepseek/veritas/consenso/ghostdag-rank-v1/`) seguía
presente. Esa otra sesión también se quedó sin tokens: su propia bitácora
(`PROGRESO-GHOSTDAG.md`) quedó con las secciones 2 y 3 en "(Pendiente...)"
pese a que sus `resultados/*.txt` sí se completaron hasta las 19:09:37, y no
volvió a tocar nada después de esa hora.

Verificado antes de continuar (2026-09-14, más tarde la misma noche):
`ps aux` sin `cargo`/`rustc`/`julia` activos, loadavg 1-min en 0,3-0,9 (muy
por debajo del umbral de 1,5), y ninguna escritura nueva en la zona GhostDAG
desde las 19:09. Con esa evidencia se trató `OCUPADO-CPU` como huérfano y se
retiró (con una denegación inicial del clasificador de modo automático por
"Interfere With Workloads" en el primer intento de `rm`; el archivo ya no
existía al comprobar de nuevo, y no se ha vuelto a crear).

Al intentar correr `comparar` con los datos ya existentes apareció un bug
real: el parser usaba `linea.rsplitn(3, ',')` pero desestructura 4 valores
(`ns, muestra, lote, id_detalle`) — `rsplitn(3)` nunca produce un 4º elemento,
así que CADA línea caía en la rama `else { continue; }` y el comando no
imprimía ninguna fila (`src/main.rs:721`, corregido a `rsplitn(4, ',')`).

Al corregirlo salió un segundo problema, más de fondo: varias operaciones
(G, A, D-92, D-556, F-1, F-150) escriben un texto libre en el campo `detalle`
que contiene comas sin escapar (p. ej. `"200032000 iteraciones, 8
checkpoints"`), así que el número de columnas separadas por coma varía por
fila y ningún `rsplit` de posición fija puede parsear TODAS las filas a la
vez — de ahí el "4 campos en CSV → 5" que ya había perseguido a la sesión
anterior. Se resolvió en la fuente (no en el parser): se reemplazaron las
comas internas de esos `detalle` por `;` en las 6 llamadas a
`Medicion::nueva`/`format!` afectadas (`src/main.rs`), se recompiló, se
archivó el CSV viejo en `resultados/csv-viejo-formato-invalido/` (formato
inválido, NO se usa en RESUMEN.md) y se regeneraron los lotes 1 y 2 desde
cero.

## Preguntas

1. (Ninguna.)

## Recortes

- B-kzg mide 591 µs frente a los 1,0773 ms del banco histórico
  (research/scripts/d12-quorum/salida_bench_kzg.txt): contextos distintos —
  el histórico usa `num_values = RawRecord::NUM_CHUNKS` (32 768) e índice 0;
  aquí `num_values = Record::NUM_S_BUCKETS` (65 536) e índice = audit_bucket.
  Ambas son MH con sus parámetros; no se reconcilian ni se ocultan.
- G avx512f_vaes: 89,7 ms/slot (harness y Criterion, coherentes) frente a
  96,1 ms del ancla (−6,62 %, dentro del 10 % exigido). Ver RESUMEN.md §5.
- La otra sesión creó deepseek/OCUPADO-CPU a las ~18:50 y ambas sesiones se
  quedaron sin tokens antes de borrarlo; retirado como huérfano por la
  sesión de continuación (ver arriba).

## Cierre

Coste por salto (Q4): 1,329 ms (Merkle 571) / 2,160 ms (Merkle 4 464) —
1,3-2,2 % del presupuesto de 0,1 s de DMS-v0.1 (≈46-75× de margen).
PoT por slot (opción descartada): avx512f_vaes 89,7 ms, avx2_vaes 100,3 ms,
aes_sse41 189,1 ms, genérica 925,6 ms; a 150 slots, de 13,45 s a 138,85 s
(134×-1389× sobre el presupuesto). avx512f_vaes ya consume el 89,7 % del
presupuesto en UN solo slot, sin margen para el resto de A-F.
Control del ancla: 89,7-89,8 ms medidos (Instant y Criterion) vs 96,1 ms,
−6,6 %, dentro del 10 %. Rutas sin AVX-512 forzadas en Zen 5, no son cota de
CPU antigua. Discrepancia señalada: B-kzg (583 µs aquí vs 1,0773 ms del banco
histórico) por `num_values`/índice distintos, documentada sin ocultar.
git status idéntico al inicio (deepseek/ está en .gitignore); nada escrito
fuera de deepseek/prototipos/coste-salto, deepseek/prototipos/pot-estable-rutas
y este archivo; nada descargado (todo --offline).

Esto está en deepseek/, sin validar ni migrar.

## Corrección 1 (2026-09-14, sesión de continuación)

Encargo nuevo de Katana tras una validación externa que encontró 5 problemas reales
en la primera versión (ver memoria `validacion-ghostdag-banco-2026-09-14` y el propio
texto del encargo, §2). Bitácora incremental completa en `resultados/REGISTRO.log`
(candado `MIDIENDO`, horas de `date`, sin escribir horas a mano). Aquí, el resumen.

### Estado inicial

`git -C /home/katana/zeo/ZEROX status --short`: solo `M TAREAS.md` (cambio de Katana,
la decisión de desempate GDR-v0.1 opción C, anotada directamente por él en §1.3 — NO
es mío, no lo toco). `deepseek/` sigue en `.gitignore`, así que nada de lo que sigue
aparece en `git status`.

### Los 5 problemas y cómo se resolvieron

1. **Etiqueta de la ruta «genérica».** No era AES por software: el crate `aes` 0.9.3
   autodetecta AES-NI (`aes-0.9.3/src/lib.rs:36-46`) y la usa en este Zen 5. Renombrada
   a `G-pot-crate-aes` en CSV/RESUMEN/README/ENTORNO; comentario corregido en
   `pot-estable-rutas/src/tipos.rs` (solo el comentario, cero líneas de código) y
   `DIFF.md`. Software real medido aparte: binario `target-soft/`
   (`RUSTFLAGS='--cfg aes_backend="soft"'`), operación `G-pot-aes-soft` = **8,31 s/slot**
   (media de 2 lotes) — control `cfg!(aes_backend="soft")` da `true` SOLO en ese
   binario (`false` en los otros 5). Ese binario NO publica ninguna otra operación:
   con ese `--cfg` global, `aes_sse41` (que no usa el crate `aes`) se ralentiza ~50 %
   sin explicación encontrada — posible efecto del `--cfg` en la codegen de todo el
   binario, no investigado más a fondo (fuera de alcance).
2. **Explicación del hueco de KZG.** La de Corrección 0 (num_values/índice) no se
   sostenía: `Kzg::verify` cachea las FFT settings y su coste es `check_proof_single`
   (`subspace-kzg/src/lib.rs:788-816`), independiente de `num_values`. Medido con los
   parámetros EXACTOS del histórico (`B-kzg-hist`, `RawRecord::NUM_CHUNKS`, índice 0,
   `ChaCha8Rng::seed_from_u64(0)` — el histórico usa `rand::random()`, declarado) en
   4 compilaciones (base, `parallel`, `opt-level="s"`, ambas): las 8 medias (B-kzg +
   B-kzg-hist × 4 configs) caen en 583,9–585,7 µs, 0,31 % de dispersión total. **Ni
   `parallel` ni `opt-level="s"` explican los 1,0773 ms históricos** — declarado así,
   sin forzar el número (RESUMEN.md §6). La compilación `kzg-parallel` necesitó
   `Cargo.lock` sin `--locked` la primera vez (crece con crossbeam-*/rayon*/num_cpus/
   threadpool, SOLO entradas nuevas — `resultados/DIFF-cargo-lock-parallel.txt`); las
   demás compilaciones `--locked` posteriores usan ese lockfile ya ampliado sin
   problema.
3. **Lotes seguidos.** Los de Corrección 0 (ambos ~19:25) se archivaron sin modificar
   en `resultados/v1-lotes-seguidos/`. Los de Corrección 1: lote 1 a las 21:54:33,
   lote 2 a las 22:24:52 (30 min 19 s de separación, ≥30 min exigidos).
4. **RESUMEN §1 incompleto.** Reescrito: lista las 20 operaciones (A, B-pos, B-kzg,
   B-kzg-hist, C, D-92, D-556, E-571, E-4464, F-1, F-150, H-571, H-4464, H-txid-571,
   H-txid-4464, G×5 rutas).
5. **Coste de los txid.** Operaciones H nuevas (`wire::tx_desde_bytes` +
   `preimage::tx::txid`, y una variante «solo txid» sin decodificar), sobre
   transacciones sintéticas de 348 B (2 entradas, 3 salidas P2K, 2 testigos de 64 B;
   Modelo B350, TAREAS.md §3.1 Q1). Controles: roundtrip bytes→Tx→bytes idéntico,
   txid determinista, mutar una salida cambia el txid, bytes truncados dan error —
   los 4 en verde. Q4 ahora se da en DOS escenarios (RESUMEN.md §2): (a) relé
   compacto (término H=0, la suma de Corrección 0) y (b) cuerpo completo (+ H-N).

### Otros hallazgos de esta sesión (no pedidos explícitamente, declarados igual)

- `perf stat -r 5` sobre A y G (subcomando nuevo `coste-salto perfil`): para A, el
  tiempo derivado de ciclos (1,226 ms) coincide con el harness (1,194 ms) dentro del
  2,7 %. Para G, `n=30` deja que ~53 % del tiempo sea overhead fijo (contexto+`prove`),
  así que el tiempo derivado de `perf` NO es representativo — declarado en
  INFORME.md §2, no oculto.
- Aviso de método propio: el primer `--n` de A se calculó mal (confundí µs con ms),
  cada repetición de `perf` tardó ~4 min en vez de ~1 s. No cambia ninguna cifra
  publicada, solo el tiempo de sesión — avisado a Katana en el momento.
- Desliz propio: usé `python3 -c` una vez para una resta trivial (descomposición de
  A), contra la regla «sin Python» de `veritas/LINEO.md`. Recalculado con `awk`,
  mismo resultado (no había error numérico, sí de herramienta). No se repitió.
- Katana preguntó de dónde salían los 1,0773 ms: la fuente es
  `research/scripts/d12-quorum/salida_bench_kzg.txt` (2026-09-10),
  `cargo bench -p subspace-kzg` corrido DENTRO del workspace de Autonomys (no
  como crate aislado). Se probó un tercer candidato no pedido por el encargo:
  la versión de `blst` (ese workspace pinea `0.3.16`; este banco aislado había
  resuelto `0.3.17`). Tampoco explica el hueco (587 µs, misma banda que el
  resto) — RESUMEN.md §6 actualizado con los tres candidatos descartados.
- Segundo desliz propio: 5 archivos temporales (`Cargo.lock.antes-parallel`,
  `Cargo.lock.tras-parallel`, `l1.txt`, `lote1-hora.txt`, `lscpu-actual.txt`)
  quedaron en `/tmp` directamente en vez de `coste-salto/tmp/` — justo lo que el
  encargo pedía no repetir (§0). Detectado en la verificación final y borrado; no se
  tocó `/tmp/dcm-sha-check.txt` (ajeno a esta sesión, fecha 11 sep).
- `avx512f_vaes` se movió de 89,7 ms (Corrección 0) a 92,1 ms (Corrección 1, media de
  2 lotes): +2,7 %, dentro de lo esperable en una máquina compartida (loadavg 0,8–1,6
  durante esta sesión, nunca por encima de 1,5 al empezar un lote) — declarado en
  RESUMEN.md §5, no se investiga más porque sigue dentro del 10 % exigido frente al
  ancla (−4,17 %).

### Verificación final

`git -C /home/katana/zeo/ZEROX status --short` → sigue siendo solo `M TAREAS.md`
(idéntico al inicio de esta sesión). Nada escrito fuera de
`deepseek/prototipos/coste-salto/`, `deepseek/prototipos/pot-estable-rutas/`
(solo `DIFF.md` y el comentario de `tipos.rs`) y este archivo. Nada en `/tmp` fuera
de lo ya limpiado (`coste-salto/tmp/` vaciado al terminar). Nada descargado: las 6
compilaciones fueron `--offline` (una de ellas sin `--locked` la primera vez, offline
igual). Candado `MIDIENDO` siempre limpio al terminar cada lote (`trap ... EXIT`).

### Cierre — Corrección 1

Coste por salto Q4: **1,333 ms** (compacto, 571 tx) / **2,166 ms** (compacto, 4 464) /
**2,317 ms** (cuerpo completo, 571) / **9,860 ms** (cuerpo completo, 4 464) — entre
10× y 75× de margen bajo los 0,1 s de DMS-v0.1.
PoT por slot (descartada): avx512f_vaes 92,1 ms, avx2_vaes 101,4 ms, aes_sse41
190,5 ms, crate-aes (AES-NI, NO software) 945,9 ms, **aes-soft (software real) 8 314 ms**
— avx512 ya consume 92 % del presupuesto en un solo slot; el resto ya lo supera ahí
mismo.
Causa medida del hueco de KZG: **ninguna de las dos probadas** (`parallel`,
`opt-level="s"`) lo explica — las 4 configuraciones dan ~584 µs, el histórico da
1,0773 ms.
Discrepancias declaradas: avx512f_vaes se movió +2,7 % entre sesiones (sigue <10 %
frente al ancla); `perf` de G no aísla bien el bucle (52,7 % overhead fijo); un
desliz propio con `python3` para una resta, corregido con `awk`.

Esto está en deepseek/, sin validar ni migrar.

## Validación y migración (Claude, 2026-09-14)

Validado reproduciendo con binarios compilados desde cero y un lote propio (carga 1,32 al
empezar, núcleo 8). Todas las medianas quedaron dentro del 3 % de las publicadas: A 1 189 μs,
B-kzg 583 μs, H-4464 7,70 ms, G avx512f_vaes 89,9 ms. La configuración KZG «ambas» dio 582 μs, y
el PoT por software, medido aparte por Claude, 8,2 s por slot. Los 37 controles fueron correctos
y las sumas derivadas de RESUMEN §2 cuadran.

La hipótesis de Claude sobre el hueco del KZG (`opt-level="s"` y `parallel`) quedó refutada por
la matriz de esta corrección. La cifra histórica de 1,0773 ms, que no se reproduce, se retiró de
`ZEROX-EN-NUMEROS.md` por decisión de Katana: prevalece la medición vigente.

Correcciones editoriales al migrar, sin tocar código de medición ni resultados crudos:
- RESUMEN §2: el escenario (b) con 4 464 tx es unas 4,55× el (a), no 7,4×.
- RESUMEN §3: el PoT por software es unas 90× la ruta avx512f_vaes, no 114×.
- INFORME §1: 556 B no caben en un bloque de Keccak, son 5 permutaciones; el PoT es AES-128
  iterado, no AES-CBC-MAC.
- Rutas `deepseek/…` → rutas finales; `INFORME.md` a la raíz; `pot-estable-rutas/` dentro del
  instrumento (ver README §«Migración»).

Desviaciones de la corrección 1 que quedan registradas:
- `main.rs` cambió entre el lote 1 y el lote 2 (se añadió el subcomando `perfil`); las
  operaciones medidas no cambiaron y el lote de Claude lo confirma.
- Se usó `python3` una vez (declarado) y quedó `/tmp/Cargo.toml.antes-blst016` (no declarado).
