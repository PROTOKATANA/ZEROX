# MIGRACIÓN — P-CIERRE fase 1 · §1.1

**2026-09-20.** Se **copian** cuatro directorios a `veritas/consenso/`. **Los cuatro originales
quedan intactos** y se comprueba que lo están. Ningún `resultados/` migrado se regenera salvo el
control de identidad de la celda `hon-4`.

| Origen | Destino | Ficheros |
|---|---|---|
| `P-2.1/veritas/consenso/ancla-inyeccion-v2/` | `veritas/consenso/ancla-inyeccion-v2/` | 87 → 93 |
| `P-PUERTA/veritas/consenso/puerta-cobertura-v1/` | `veritas/consenso/puerta-cobertura-v1/` | 39 → 42 |
| `P-POT/propuesta/` | `veritas/consenso/pot-primitiva-v1/` | 9 (sin `target/`) → 15 |
| `P-FLUJO/propuesta/` | `veritas/consenso/regla-flujo-v1/` | 3 → 12 |

El crecimiento es `ENTRADA/` (con su `ENTRADA.sha256`) + `PROCEDENCIA.md` + (en las dos
propuestas) `LEEME.md` + (en las dos propuestas) `HUELLAS.sha256`, que no tenían.
**`P-POT/propuesta/vectores/target/` NO se copia:** son artefactos de compilación regenerables,
ya excluidos por `.gitignore:1` (`target/`), y `MIGRACION.md` del repositorio registra que esa
caché se retiró en la limpieza por el mismo motivo.

**No se migran,** por §1.1 del encargo: `deepseek/`, `P-SEMBRADOR/` y `P-ZRX/`.

---

## 1 · Lo que hay en cada destino

### (a) `ENTRADA/` — la copia congelada de lo que gobernó cada trabajo

| Destino | Contenido de `ENTRADA/` |
|---|---|
| `ancla-inyeccion-v2` | `ENCARGO.md` (P-2.1 v3), `PROMPT.md`, `ADENDA-1.md`, `ADENDA-2.md` |
| `puerta-cobertura-v1` | `PROMPT.md` — **P-PUERTA no tuvo `ENCARGO.md` ni adendas**; su `P-PUERTA/ENTRADA.sha256` firma un solo archivo, y eso es lo que hay |
| `pot-primitiva-v1` | `ENCARGO.md`, `PROMPT.md` — P-POT no tuvo adendas |
| `regla-flujo-v1` | `ENCARGO.md`, `PROMPT.md`, `ADENDA-1.md`, `ADENDA-2.md`, `ADENDA-3.md` |

Cada carpeta lleva su `ENTRADA.sha256` con rutas desde la raíz. **Los doce archivos copiados
tienen el mismo `sha256` que sus originales**, comprobado uno a uno contra los `ENTRADA.sha256` y
`ADENDAS.sha256` de cada zona `P-*/`:

```
ancla-inyeccion-v2/ENTRADA/ENTRADA.sha256:   4/4 OK
puerta-cobertura-v1/ENTRADA/ENTRADA.sha256:  1/1 OK
pot-primitiva-v1/ENTRADA/ENTRADA.sha256:     2/2 OK
regla-flujo-v1/ENTRADA/ENTRADA.sha256:       5/5 OK
```

### (b) `PROCEDENCIA.md` — copiado LITERAL, sin editar

Los cuatro tienen el `sha256` exacto del archivo de `P-CIERRE/procedencia/`:

```
ancla-inyeccion-v2   bf45a43c67cc5996b3d8f330c0069a181bc25035884bd20228db2394eb2bdbc7
pot-primitiva-v1     7bde851c943a0b11007cb46b0cbcb4400e6bd6266fb097e2e17dfd69f5ac54f0
puerta-cobertura-v1  8912a934f5476750b57b18d8ff4a29c321425acdce0316d7e1e219d817de3105
regla-flujo-v1       b40ff691339346f8e15f3a870f25299f66241e98ff69a53af6bc77c20148aefa
```

### (c) `HUELLAS.sha256` regenerado con rutas desde la raíz

```
$ cd /home/katana/zeo/ZEROX && LC_ALL=C sha256sum -c veritas/consenso/<x>/HUELLAS.sha256
ancla-inyeccion-v2    92/92 OK   exit 0
puerta-cobertura-v1   63/63 OK   exit 0
pot-primitiva-v1      14/14 OK   exit 0
regla-flujo-v1        11/11 OK   exit 0
```

**Tres decisiones de forma, dichas en voz alta:**

1. **Ya no se autoincluyen.** La `HUELLAS.sha256` original de `ancla-inyeccion-v2` firmaba su
   propio hash; eso **no puede verificar nunca**, y de hecho el original falla hoy por esa línea y
   solo por ella (86/87 OK). Se retira en el destino.
2. **`pot-primitiva-v1` y `regla-flujo-v1` no tenían `HUELLAS.sha256`.** Son propuestas, no
   instrumentos: las suyas son nuevas.
3. **`puerta-cobertura-v1` conserva VERBATIM sus 22 líneas de entrada** (`SPEC.md`, `veritas/LINEO.md`,
   `research/*`, `PDF/autonomys-subspace/*`, `P-PUERTA/PROMPT.md`, `P-2.1/ENCARGO.md`,
   `P-2.1/ADENDA-2.md`) con el hash del 2026-09-19. **Son el registro de qué documento firmó el
   instrumento, no una comprobación de vigencia.** La línea de `SPEC.md`
   (`673d867970006036051c3eb9de0dbd6c07a8004bdc8419dd49ffd1ba78c6bc58`) **fallará en cuanto la fase
   2 edite el SPEC**, y eso es correcto: el encargo lo prevé («se documenta, no se arregla»). Está
   escrito dentro del propio archivo.

### (d) Rutas de `METODO.md` y de los `LEEME` actualizadas

- `ancla-inyeccion-v2/METODO.md`: las 11 apariciones de `P-2.1/veritas/consenso/ancla-inyeccion-v2`
  pasan a `veritas/consenso/ancla-inyeccion-v2`.
- `puerta-cobertura-v1/METODO.md`: `PRO=` y `--project=` pasan al destino; la comprobación de
  entrada pasa de `P-PUERTA/ENTRADA.sha256` a
  `veritas/consenso/puerta-cobertura-v1/ENTRADA/ENTRADA.sha256`.
- `pot-primitiva-v1/vectores/LEEME.md`: los comandos de regeneración pasan al destino.
- **`LEEME.md` nuevos** en `pot-primitiva-v1/` y `regla-flujo-v1/`: esas dos carpetas **no son
  instrumentos** —no tienen `Project.toml`, `run.jl` ni `resultados/`, y por tanto no siguen la
  estructura de `veritas/LINEO.md` §1—, así que se explica qué son, qué hay dentro y cómo se
  comprueban. Sin eso, un lector futuro las tomaría por instrumentos rotos.
- **Las cuatro `PROGRESO.md`** (bitácoras de ejecutor) llevan una **nota de migración** en cabecera
  que declara históricas las rutas de dentro y **no se reescriben**. Es el precedente exacto de
  `veritas/finalidad/delta-medido-v1/BITACORA.md:3-6`. El nombre `PROGRESO.md` **no se cambia** a
  `BITACORA.md`: el encargo no lo pide y renombrar rompería referencias internas.

---

## 2 · Los dos cambios de ruta — el único código tocado

### 2.1 · `ancla-inyeccion-v2/src/AnclaInyeccion.jl`

```diff
-# Ruta a GDR-v0.2 desde la raíz del repo (src/../../../../../veritas/consenso/...)
-include(joinpath(@__DIR__, "..", "..", "..", "..", "..",
-                 "veritas", "consenso", "ghostdag-rank-v1", "src", "GhostdagRank.jl"))
+# Ruta a GDR-v0.2 desde el destino migrado (src/../../ghostdag-rank-v1/src/...).
+# Migrado desde P-2.1/veritas/consenso/ancla-inyeccion-v2/ el 2026-09-20: eran cinco niveles.
+include(joinpath(@__DIR__, "..", "..",
+                 "ghostdag-rank-v1", "src", "GhostdagRank.jl"))
```

**GDR-v0.2 se sigue incluyendo SIN MODIFICAR**, que es la condición que el instrumento declara en
su primera línea.

### 2.2 · `pot-primitiva-v1/vectores/Cargo.toml`

```diff
-pot-estable = { path = "../../../prototipos/pot-estable" }
+pot-estable = { path = "../../../../prototipos/pot-estable" }
```

Un nivel más, porque `veritas/consenso/pot-primitiva-v1/vectores/` está un nivel más hondo que
`P-POT/propuesta/vectores/`. **`prototipos/pot-estable` no se toca** (zona prohibida por el
encargo §Reglas 2); solo cambia quién apunta a ella.

**No hay ningún otro cambio de código en la migración.**

---

## 3 · Pruebas de que la migración no cambió nada

### 3.1 · Suite de `ancla-inyeccion-v2`, con `--check-bounds=yes`

```bash
JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 ./veritas/julia.sh \
  --project=veritas/consenso/ancla-inyeccion-v2 --check-bounds=yes \
  veritas/consenso/ancla-inyeccion-v2/test/runtests.jl
```

```
  criterio α: G(0) medio=15.18 < G(0,45) medio=60.4
Test Summary: | Pass  Total   Time
ANCLA-v0.2    | 2763   2763  40.3s
exit=0
```

**2 763/2 763.** Es la prueba de que el `include` arreglado resuelve: sin él el módulo no carga.

### 3.2 · Suite de `puerta-cobertura-v1`, perfil de referencia

```bash
./veritas/julia.sh --check-bounds=yes --project=veritas/consenso/puerta-cobertura-v1 \
  --threads=1 veritas/consenso/puerta-cobertura-v1/test/runtests.jl
```

```
Test Summary: | Pass  Total   Time
PCO-v0.1      |  239    239  11.8s
exit=0
```

**239/239**, el mismo número que `PROCEDENCIA.md` §1 declara.

### 3.3 · `cargo test` de los vectores

```bash
CARGO_TARGET_DIR=<scratch> cargo test --release --offline -j 2 \
  --manifest-path veritas/consenso/pot-primitiva-v1/vectores/Cargo.toml
```

```
   Compiling pot-estable v0.1.0 (/home/katana/zeo/ZEROX/prototipos/pot-estable)
   Compiling ppot-vectores v0.1.0 (/home/katana/zeo/ZEROX/veritas/consenso/pot-primitiva-v1/vectores)
running 4 tests
test v1_encadenado_sin_inyeccion ... ok
test v3_v4_aleatoriedad_reto ... ok
test v2_inyeccion ... ok
test v5_dominio_de_n ... ok
test result: ok. 4 passed; 0 failed; 0 ignored
exit=0
```

**4/4**, el mismo número que `PROCEDENCIA-pot-primitiva-v1.md` declara. La línea `Compiling
pot-estable … (/home/katana/zeo/ZEROX/prototipos/pot-estable)` es la prueba de que la ruta
arreglada apunta al sitio correcto.

**Control adicional, no pedido:** regenerar `vectores.txt` desde el destino da un cuerpo
**idéntico** al original (las dos primeras líneas del archivo son una cabecera añadida a mano, no
la produce el binario). `sha256` del archivo migrado = del original =
`7eaed4b9304b59738566e8c9f3228cc2134d0d28ba74257add9a4c2832e2e876`.

### 3.4 · Control de identidad: la celda `hon-4` reejecutada desde el destino

```bash
JULIA_NUM_THREADS=24 OPENBLAS_NUM_THREADS=1 ./veritas/julia.sh \
  --project=veritas/consenso/ancla-inyeccion-v2 --threads=24 \
  veritas/consenso/ancla-inyeccion-v2/run.jl 4a --celda hon-4 --replicas 2000 --chunk 100
```

Inicio `2026-09-20 23:11:00`, fin `23:15:07` — **4 min 07 s**, 20 chunks de 100 réplicas, 24 hilos,
≈1 900 % de CPU. Resumen producido:

```
hon-4,2000,1.0,39.02,119:medido,132:medido,132:medido,0.0748,1.847,20,131
```

**Resultado del control:**

| Archivo | `sha256` del original | `sha256` de la reejecución | |
|---|---|---|---|
| `w.csv` | `a35d55ad…05d0db67` | `a35d55ad…05d0db67` | **IDÉNTICO** |
| `g.csv` | `0a8ee29c…18ba9f3e` | `0a8ee29c…18ba9f3e` | **IDÉNTICO** |
| `resumen.csv` | `6080fef3…c99c529f9` | `6080fef3…c99c529f9` | **IDÉNTICO** |

`diff` byte a byte de los tres: sin diferencias. La salida de la reejecución se conserva en
`P-CIERRE/ejecucion/control-hon-4/`, con su `HUELLAS.sha256`.

> **⚠️ Error mío, corregido antes de darlo por bueno.** Mi primera comparación fue **inválida**:
> comparé `veritas/consenso/ancla-inyeccion-v2/resultados/4a/hon-4/w.csv` contra el original, y
> los dos eran **la misma copia** —la reejecución no había escrito ahí—. Lo detecté en el
> `git status`, que mostró un `?? resultados/` nuevo **en la raíz del repositorio**. La tabla de
> arriba es la comparación buena, contra la salida que la reejecución escribió de verdad.

---

## 4 · Defecto encontrado en el instrumento, no corregido

**`run.jl` de `ancla-inyeccion-v2` escribe en `resultados/` relativo al DIRECTORIO DE TRABAJO,
no al del instrumento**: `dir = joinpath("resultados", "4a", nombre)`
(`veritas/consenso/ancla-inyeccion-v2/run.jl:49`, y lo mismo en `:81, :121, :150, :169`). Como
`METODO.md` manda ejecutar **desde la raíz del repositorio**, seguir el método al pie de la letra
crea `resultados/` **en la raíz**, no dentro de la carpeta del instrumento — que es donde el propio
`METODO.md` dice que están las salidas.

- **Es un defecto del original, no de la migración.** El `METODO.md` de `P-2.1/` decía ya lo mismo.
- **No se corrige:** el único cambio de código autorizado (§1.1 del encargo) fue el `include` de
  GDR. Cambiar dónde escribe `run.jl` es un cambio de comportamiento, y no me toca.
- **Sí se documenta**, con un aviso en `veritas/consenso/ancla-inyeccion-v2/METODO.md` que dice
  cómo reproducir en su sitio (`cd` al instrumento, o mover la salida después).
- La raíz del repositorio quedó limpia: el `resultados/` que creó el control se movió a
  `P-CIERRE/ejecucion/control-hon-4/` y se borraron los tres directorios vacíos. `git status` no
  muestra ningún `?? resultados/`.

---

## 5 · Los originales siguen intactos

```
$ LC_ALL=C sha256sum -c P-PUERTA/veritas/consenso/puerta-cobertura-v1/HUELLAS.sha256
(60/60 OK, exit 0 — esta original NO se autoincluye)

$ LC_ALL=C sha256sum -c P-2.1/veritas/consenso/ancla-inyeccion-v2/HUELLAS.sha256
P-2.1/veritas/consenso/ancla-inyeccion-v2/HUELLAS.sha256: FAILED
sha256sum: WARNING: 1 computed checksum did NOT match
(86/87 OK)
```

El único fallo es **la línea en que el archivo se firma a sí mismo**, que no puede verificar nunca
y que ya fallaba antes de tocar nada. Es exactamente el defecto que el destino retira. Ningún
fichero de contenido cambió en ninguna de las dos zonas de origen.

`P-POT/propuesta/` y `P-FLUJO/propuesta/` no tenían `HUELLAS.sha256`; sus archivos se comprobaron
uno a uno contra las copias y coinciden.

---

## 6 · Cuentas finales

| | ancla | puerta | pot | flujo |
|---|---:|---:|---:|---:|
| Ficheros en el destino | 93 | 42 | 15 | 12 |
| Líneas de hash en `HUELLAS.sha256` | 92 | 63 | 14 | 11 |
| — de ellas, propias | 92 | 41 | 14 | 11 |
| — de ellas, entrada verbatim | 0 | 22 | 0 | 0 |
| Verificación `sha256sum -c` | 92/92 | 63/63 | 14/14 | 11/11 |
| Ficheros de `ENTRADA/` (con su `.sha256`) | 5 | 2 | 3 | 6 |
| Tests que pasan | 2 763 | 239 | 4 (`cargo`) | — |

**`SPEC.md`, `TAREAS.md` y `ci/` no se han tocado en la fase 1**, que era la condición. Su estado
en `git status --short` es idéntico al del inicio de la fase.
