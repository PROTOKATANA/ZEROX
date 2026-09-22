# PROGRESO — P-INTENTO

Bitácora del encargo. Cada entrada lleva `date`. Las cifras llevan etiqueta
`medido` / `derivado` / `estimado` / `no determinado`.

---

## Entrada — 2026-09-21 11:57 CEST

### Comprobaciones de entrada (§5 del encargo)

Desde la raíz del repositorio, `LC_ALL=C sha256sum -c P-ZRX/P-INTENTO/ENTRADA.sha256`:

```
P-ZRX/P-INTENTO/PROMPT.md: OK
```

`git -C /home/katana/zeo/ZEROX status --short`:

```
 D ZEROX-EN-NUMEROS.md
?? .trash/
?? P-ZRX/
?? veritas/consenso/poda-post-v1/
?? veritas/consenso/prueba-recursiva-v1/
?? veritas/seguridad/
```

(Preexistente; no lo introduce esta tarea. `ZEROX-EN-NUMEROS.md` aparece borrado y
`P-ZRX/` sin seguimiento ya antes de empezar.)

`date`: `lun 21 sep 2026 11:57:33 CEST`

### Comprobaciones del clon fijado (§4 del encargo)

```
$ git -C /home/katana/zeo/fuentes/subspace rev-parse --short HEAD
f8842d0
$ git -C /home/katana/zeo/fuentes/subspace status --short
(sin salida — árbol limpio)
```

Coincide con el commit exigido. El clon se trata como **solo lectura**: todo `cargo` se
ejecuta con `CARGO_TARGET_DIR` fuera del clon y con `--locked`.

### Perfil de la máquina

| Recurso | Valor |
|---|---|
| CPU | AMD Ryzen 9 9950X3D, 16 núcleos físicos / 32 hilos lógicos, 1 nodo NUMA |
| RAM | 123 GiB visibles (102 GiB disponibles al arrancar) |
| Gobernador de CPU | `powersave` (no modificable sin root) |
| Disco | `/home` en `/dev/mapper/cr_root`, 1,7 TiB libres |
| GPU | NVIDIA GTX 1070 (GP104) **presente en PCI** (`01:00.0`), módulos `nvidia*` cargados, pero `/dev/nvidia*` **no existe** y `nvidia-smi` falla |
| CUDA | `nvcc` 13.1 en `/usr/local/cuda`; también `/usr/local/cuda-12.9`. Irrelevante mientras no haya nodo de dispositivo |
| RAPL | `/sys/class/powercap/intel-rapl:0/energy_uj` existe pero es `0400 nobody` → ilegible |
| Privilegios | sin `sudo` (flag `no new privileges`); no se pueden crear nodos de dispositivo ni leer RAPL |

`rustc 1.97.0-nightly (20de910db 2026-05-02)` / `cargo 1.97.0-nightly (4f9b52075 2026-05-01)`,
toolchain activa `nightly-2026-05-03` por `rust-toolchain.toml` del clon.
Julia `1.13.0` vía `/home/katana/zeo/ZEROX/veritas/julia.sh`.

### Presupuesto declarado ANTES de ejecutar (LINEO §7 y §11)

| Recurso | Tope declarado |
|---|---|
| Hilos de cómputo | **24** (de 32 lógicos) |
| RAM | **64 GiB** |
| Disco temporal (`investigacion/target/`) | **40 GiB**, se borra al terminar |
| Tiempo de pared total | **12 h** |

Reparto: compilación Rust ≤ 3 h · M1+M2 ≤ 3 h · M3+M4 ≤ 2 h · control de 83,6 s ≤ 1 h ·
M5 GPU ≤ 1 h (tope fijado por el encargo) · M6 ≤ 15 min · Julia ≤ 1 h · redacción ≤ 1 h.
Si se agota: checkpoint y estado **inconcluso**; nunca se convierte un timeout en falsedad.

---

## Crítica previa del encargo (§8: «dilo ANTES de empezar»)

Comprobado abriendo el código fijado, no por lectura de los informes previos.

### Lo que confirmo del §1

- **[Verificado en fuente]** La tabla solo depende de la semilla; el reto solo elige el
  *s-bucket*. `ChiaV2TableGenerator::generate` → `Tables::<K>::create_proofs(seed)`
  (`crates/subspace-proof-of-space/src/chia_v2.rs:28-36`) y `find_proof(challenge_index)` →
  `proofs.for_s_bucket(SBucket::from(challenge_index as u16))`
  (`crates/subspace-proof-of-space/src/chia_v2.rs:64-68`).
- **[Verificado en fuente]** El `s_bucket` sale de los dos primeros bytes LE del reto
  `SectorSlotChallenge = SectorId ⊕ global_challenge`
  (`crates/subspace-core-primitives/src/sectors.rs:32-39,117-123`); como
  `Record::NUM_S_BUCKETS == 2^16`, es un `u16` exacto
  (`crates/subspace-core-primitives/src/pieces.rs:561-567`).
- **[Verificado en fuente]** La unidad es la pieza, no el sector: el verificador solo abre
  una prueba PoS, un chunk y su testigo KZG
  (`crates/subspace-verification/src/lib.rs:228-270`).
- **[Verificado en fuente]** El camino ganador regenera la tabla desde la semilla
  (`crates/subspace-farmer-components/src/proving.rs:243-248`).

### Corrección 1 — «la tabla» que el atacante conserva es un objeto compacto de 5 MiB, no las 7 tablas

`ChiaV2Table` almacena `proofs: Box<Proofs<K>>` (`chia_v2.rs:56-58`), y `Proofs<K>` es
(`shared/ab-proof-of-space/src/chiapos.rs:46-65`):

- `found_proofs: [u8; NUM_S_BUCKETS/8]` = **8.192 B** (mapa de bits de qué *s-buckets* tienen prueba),
- `proofs: [[u8; 2^6·20/8]; NUM_CHUNKS]` = `[ [u8;160]; 32768 ]` = **5.242.880 B**.

Las siete tablas se construyen y **se destruyen** dentro de `create_proofs`
(`chiapos.rs:195-268`): `create` sí las devuelve (`chiapos.rs:174-193`), pero el camino que usa
el banco y el *record encoder* no. Consecuencias que el §1 no dice y que cambian M1 y M2:

- **RAM por «tabla viva» es 5,01 MiB**, no varios GiB (el conjunto de 7 tablas sí sería de
  orden GiB). M1 debe reportar la primera cifra, que es la que limita cuántas caben a la vez.
- **M2 no es un recorrido de tabla**: es un *rank/select* sobre un mapa de bits de 8 KiB
  (`shared/ab-proof-of-space/src/lib.rs:63-84`). El coste por reto está dominado por el
  `popcount` lineal sobre los bytes anteriores al byte del bucket, es decir `O(s_bucket/64)`.

### Corrección 2 — el test de «gana» no es gratis en piezas: la distancia se calcula sobre el chunk CRUDO

`is_within_solution_range` no depende de la prueba PoS. La verificación hace
`masked_chunk = solution.chunk XOR proof.hash()` y evalúa
`calculate_solution_distance(global_challenge, chunk, sector_slot_challenge)`
(`crates/subspace-verification/src/lib.rs:245-254,118-146`), y el plotter guarda
`encoded = raw_chunk XOR blake3(proof)` y **cero** donde no hay prueba
(`crates/subspace-farmer-components/src/plotting.rs:646-655`).

Es decir: dado un *bucket*, saber si hay candidato y con qué distancia **solo necesita el
mapa de bits de presencia y el chunk crudo de la pieza** — no el testigo. El testigo se
necesita para desenmascarar/montar la solución, es decir, **solo si gana**. Esto *refuerza*
la tesis del §1 (el ganador paga M3 y el resto no) y a la vez precisa M2: por cada reto hay
un acierto de bucket con probabilidad ≈ 1/2 (INFORME §«Probabilidad e intentos», `o ≈ 1/2`),
y cada acierto necesita una lectura de 32 B del histórico archivado y un `blake3` con clave.

### Corrección 3 — `N_eq` es dimensionalmente correcto, pero `r·w` NO es lineal

`N_eq = r·w·τ` con `r` [tablas/s], `w` [retos] y `τ` [s/slot] da tablas·retos por slot.
Un granjero con `N` piezas gana `N·p` candidatos por slot; el sembrador, `r·τ·w·p`; igualando,
`N_eq = r·w·τ`. **La métrica se sostiene** y se conserva.

La objeción es al uso implícito de `r·w` como producto: el §2 pregunta expresamente si cruzar
una tabla con `w` buckets escala como `w·t_reto`. Si la respuesta es que existe una forma en
lote `O(NUM_S_BUCKETS/64)` independiente de `w`, entonces el coste *marginal* por reto
adicional tiende a cero y la fórmula debe escribirse con el `w` efectivo medido, no con el
nominal. Se medirá y se reportará como `r_eff(w)`, no como constante.

### Lo que NO me parece equivocado

- La unidad de un intento es una pieza (**verificado**).
- Las identidades candidatas son gratis y desechables (**verificado**).
- Que `π_DAG = 1` favorece al atacante (**de acuerdo**, y así se etiqueta).
- Que las cifras históricas de `research/` no son heredables (**de acuerdo**; se miden de nuevo).

### Riesgos declarados de ejecución

1. **GPU**: sin `/dev/nvidia*` y sin root, la ruta wgpu/Vulkan no puede abrir dispositivo.
   Se intentará dentro del presupuesto de 1 h y, si no hay dispositivo, el resultado será
   **«GPU no medida»**, nunca el «<5 s» de la documentación.
2. **Energía**: RAPL ilegible sin root → M6 será **«no medida»**.
3. **Gobernador `powersave`**: no modificable. Se registra; afecta a comparaciones con otras
   máquinas, no a la validez interna del barrido.

---

## Bitácora de ejecución

- **11:57** — comprobaciones de entrada (§5) y del clon (§4). OK.
- **11:58** — creado `investigacion/{mediciones,banco-rust,veritas/seguridad/intento-v1}`.
- **11:58** — `cargo bench -p subspace-proof-of-space --features alloc,parallel --no-run --locked`
  → OK en 7,15 s, `CARGO_TARGET_DIR=investigacion/target`.
- **11:59** — lanzada compilación de `subspace-farmer-components` + `subspace-kzg` → OK en 45,71 s.
- **12:00** — calibración con el banco `pos` del clon: `table/single/1x` = 721,79 ms,
  `table/parallel/1x` = 99,13 ms. Fija la escala de M1.
- **12:03** — crate `banco-rust` escrito y compilado. Requiere `#![feature(generic_const_exprs)]`
  para nombrar `Proofs<20>`, la misma feature que usa `ab-proof-of-space`.
- **12:04** — `distribucion`: **hallazgo** — `create_proofs` deja siempre 32768 pruebas y deja
  vacíos los buckets > ≈58.410. Media `o = 0,5` exacta.
- **12:09** — primera suite. **Falla**: `ls deps | head -1` cogió binarios obsoletos de `m2_reto`,
  y el «caso peor» de `rank/select` medía un bucket vacío (retorno temprano). Se sustituye por
  `cargo bench --bench X` y por sondas representativas (bajo/medio/alto).
- **12:12** — segunda suite. **Aborta** con corrupción de heap en `escalado` a 4 hilos.
- **12:20-12:50** — investigación del fallo. Reproductor mínimo `banco-rust/src/bin/estres.rs`:
  **una sola llamada, un solo hilo, SIGSEGV** para la semilla
  `fc5317b05613ed8f1296ebca4c01b008e56a6dcc1d8c9619a4ddd741b285bcbc`; la ruta **paralela** no
  falla. Documentado en `mediciones/fallo-semilla.md`. El banco pasa a ciclar sobre un conjunto de
  semillas verificado (`POOL_SEGURO`).
- **12:53** — **defecto propio detectado**: en el bucle de `por_bucket`, LLVM eliminaba el
  `popcount` porque el índice era un valor muerto; se medía solo el test de bit. Corregido
  acumulando el índice: la cifra sube **1.400×**. Se documenta en el informe en vez de borrarlo.
- **13:00** — tercera suite (M1, M2, M3, M4, RAM, escalado) → completa, sin abortos.
- **13:07** — `exportar_modelo`: el extractor no manejaba el formato de una línea de Criterion; el
  modelo **se negó a inventar** la cifra ausente. Corregido el parser.
- **13:08** — instrumento Julia: `Pkg.instantiate` falla porque el registro de Julia está fuera de
  la zona de escritura. Se usa un depósito en capas (`investigacion/.julia-depot`, 175 MB).
- **13:10** — tests Julia en verde (58 comprobaciones) y `benchmark`: kernel de 100.000 filas en
  581,6 µs, **0 bytes, 0 asignaciones**; error máximo frente al oráculo de 256 bits **2,74·10⁻¹⁶**.
- **13:11** — cuatro barridos del modelo (`N_h` = 10⁶, 10⁸, 10⁹ y 10⁹ con `π_DAG = 0,5`).
- **13:11** — lanzado el **control obligatorio** contra los 83,6 s históricos (bancos del clon).
- **13:12-13:40** — **CONTROL** contra la evidencia histórica (§4). `plotting/in-memory` del clon =
  **90,575 s** (88,537–92,849) con 24 hilos, frente a los **83,608 s** con 32 hilos de
  `research/coste-ploteo-medido.md:20`. Razón **1,083×**: coherente. Se ejecutaron además `proving`,
  `auditing`, `kzg` y `pos` del clon.
- **13:41** — los cruces del banco `pos` del clon confirman M1 y M2: `table/parallel/1x` = 98,205 ms
  y `proof/for-record` = 33,314 ms (≈ 0,60 µs por bucket, frente a los 0,488 µs medidos aquí).
  **Hallazgo**: el `proof/present` del propio banco del clon mide 2,55 ns porque usa el índice 3 —el
  mejor caso de un recorrido lineal— y **subestima el coste representativo en ~500×**.
- **13:42** — medida la **tercera forma** de paralelismo (varias llamadas concurrentes a
  `generate_parallel` sobre una piscina de 24), que es la que usa el granjero real. **Gana con
  8 concurrentes: 25,03 tablas/s** (1,43× la forma de tablas independientes y 2,96× la paralela
  secuencial). El instrumento pasa a usar la ganadora.
- **13:44** — modelo re-ejecutado con la configuración ganadora: cuatro barridos.
- **13:45** — **M5 GPU**: la sonda compila (35,81 s) y wgpu enumera **un solo adaptador**,
  `llvmpipe` de tipo `Cpu` (rasterizador software). **GPU no medida**, con menos de 5 min de la hora
  asignada. Detalle en `mediciones/gpu.txt`.
- **13:46** — `mediciones/criterion-crudo/` conserva las salidas crudas de Criterion (1,2 MB).
  Borrado `target/` (**1,9 GiB**, regenerable). La zona queda en **178 MiB**, de los que 175 MiB son
  el depósito de Julia en capas (`.julia-depot`), necesario para re-ejecutar el modelo porque el
  registro de Julia está fuera de la zona de escritura.

### Comprobaciones de SALIDA (§4 y §5 del encargo) — 2026-09-21 13:46 CEST

```
$ LC_ALL=C sha256sum -c P-ZRX/P-INTENTO/ENTRADA.sha256
P-ZRX/P-INTENTO/PROMPT.md: OK

$ git -C /home/katana/zeo/ZEROX status --short
 D ZEROX-EN-NUMEROS.md
?? .trash/
?? P-ZRX/
?? veritas/consenso/poda-post-v1/
?? veritas/consenso/prueba-recursiva-v1/
?? veritas/seguridad/

$ git -C /home/katana/zeo/fuentes/subspace rev-parse --short HEAD
f8842d0

$ git -C /home/katana/zeo/fuentes/subspace status --short
(sin salida — árbol limpio)
```

Idénticas a las de entrada: `PROMPT.md` intacto, el `status` de ZEROX sin cambios, el clon en
`f8842d0` y limpio. **No se modificó ni una línea de Autonomys.**

`target/` borrado: 1,9 GiB. Las salidas crudas de Criterion se conservan en
`mediciones/criterion-crudo/`.
