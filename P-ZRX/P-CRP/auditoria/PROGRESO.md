# P-CRP · PROGRESO — bitácora de la auditoría de CRP-v0.2 y CRP-v0.3

Zona de escritura: `P-ZRX/P-CRP/auditoria/` (única). Nada fuera de aquí se ha editado.

## 0 · Declaración previa (obligatoria antes de ejecutar)

- **Interpretación del encargo:** `P-ZRX/P-CRP/PROMPT.md` es el encargo; sus dos únicos ficheros
  (`PROMPT.md`, `ENTRADA.sha256`) no son ejecutables. «Ejecutar los archivos de este directorio»
  se entiende como **ejecutar el encargo**: auditar y reejecutar CRP-v0.2 y CRP-v0.3 y entregar
  `INFORME.md`, `BASELINE.md`, `DEFECTOS.md`, `RECOMENDACION-MIGRACION.md` y este `PROGRESO.md`.
- **Presupuesto declarado (antes de la primera corrida):** máximo **8 hilos** (tope de este encargo;
  hay otros encargos en la misma máquina y el tope conjunto es 24), **≤ 16 GiB de RAM**, **≤ 2 GiB de
  disco** en `P-ZRX/P-CRP/auditoria/` (los 64 MiB del microbenchmark de I/O viven en `/tmp/opencode`,
  fuera del repositorio) y **≤ 4 h de pared** para el conjunto. Ninguna corrida individual supera
  los 10 min. Si se agota: checkpoint e **inconcluso**.
- **Entorno:** Julia 1.13.0 (`veritas/julia.sh` → `env -u LD_LIBRARY_PATH`), AMD Ryzen 9 9950X3D
  (32 hilos lógicos), 123 GiB de RAM visibles. Sin Python en ningún paso.
- **Modificaciones permitidas:** solo la copia de v2 y v3 a `auditoria/copia/` y, **solo en la copia**,
  la sustitución de la ruta relativa de GDR por la absoluta (ver §3).

## 1 · Comprobaciones de entrada (al empezar)

Salida completa en `registros/inicio.txt`. Resumen:

```text
### date
lun 21 sep 2026 16:45:08 CEST
### uptime
 16:45:08  up 13 days 13:14,  0 users,  carga promedio: 2,53, 1,56, 0,68
### sha256sum -c P-ZRX/P-CRP/ENTRADA.sha256
exit=0                        # 94 líneas, 94 «: OK», 0 fallos
### git status --short
 D ZEROX-EN-NUMEROS.md
?? .trash/
?? P-ZRX/
?? veritas/consenso/poda-post-v1/
?? veritas/consenso/prueba-recursiva-v1/
?? veritas/seguridad/
```

- `ENTRADA.sha256` (94 ficheros: este prompt, el encargo 07v2 y su sidecar, y los 91 de v2/v3)
  verifica **94/94 OK** al empezar. La primera comprobación se hizo a las **16:42:09**.
- `D ZEROX-EN-NUMEROS.md` y las entradas `??` **preexisten** a esta auditoría: no son cambios míos.
  `veritas/seguridad/` está sin versionar en git (por eso `coste-rama-privada-v1` no aparece en
  `git log`); `veritas/consenso/ghostdag-rank-v1/` sí está versionado y limpio.
- `P-ZRX/P-CRP1/auditoria/INFORME.md` **no existe** cuando empiezo (solo hay `copia/` y `veritas/`),
  así que no condiciona el análisis; la pregunta de este encargo se contesta igual.

## 2 · GDR-v0.2: ¿ha cambiado desde el 2026-09-18?

```text
$ git log --format='%h %ad %s' --date=iso -- veritas/consenso/ghostdag-rank-v1/
c9dd3c7 2026-09-17 12:13:28 +0200 zx-consensus: GHOSTDAG y rank dejan de ser un instrumento Julia y pasan a ser codigo del nodo
530b6bb 2026-09-16 14:48:02 +0200 spec: GHOSTDAG y rank pasan de descritos a especificados, con doce reglas nuevas
03c08ce 2026-09-14 23:28:17 +0200 coste por salto: validar antes de reenviar cuesta de 1,3 a 9,9 ms y el banco pasa a veritas
a244c6c 2026-09-14 23:26:31 +0200 ghostdag y rank: GDR-v0.2 calcula lo que los fixtures daban a mano y el instrumento pasa a veritas
```

- El **último commit que toca** `veritas/consenso/ghostdag-rank-v1/` es del **2026-09-17 12:13**,
  anterior al 2026-09-18. `git status --short veritas/consenso/ghostdag-rank-v1/` está **vacío**.
- `sha256sum -c veritas/consenso/ghostdag-rank-v1/HUELLAS.sha256` desde la raíz: **todos los ficheros
  del propio GDR coinciden**; solo fallan `TAREAS.md` y `SPEC.md`, que están fuera de GDR y han
  evolucionado después (esperado, y coherente con §2.4 de este encargo).
- **Conclusión:** GDR-v0.2 **no ha cambiado** desde el 2026-09-18. Reejecuto lo mismo.

## 3 · Copia y parche de la ruta de GDR (única modificación permitida)

```bash
cp -a P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2 P-ZRX/P-CRP/auditoria/copia/
cp -a P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3 P-ZRX/P-CRP/auditoria/copia/
```

`diff` exacto tras el parche (idéntico en v2 y v3, solo cambia la marca de tiempo):

```diff
--- P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/src/gdr_wrapper.jl
+++ P-ZRX/P-CRP/auditoria/copia/coste-rama-privada-v2/src/gdr_wrapper.jl
@@ -6,8 +6,7 @@
 #  - `blue_work` real por bloque, recomputado desde los conjuntos azules de GDR;
 #  - separación explícita entre el peso propio de una punta y el acumulador C-GD-08.
 
-const _RUTA_GDR = joinpath(@__DIR__, "..", "..", "..", "..", "..",
-                           "veritas", "consenso", "ghostdag-rank-v1", "src", "GhostdagRank.jl")
+const _RUTA_GDR = "/home/katana/zeo/ZEROX/veritas/consenso/ghostdag-rank-v1/src/GhostdagRank.jl"
 
 if !isdefined(@__MODULE__, :GhostdagRank)
     include(_RUTA_GDR)
```

Ningún otro fichero de la copia se ha tocado. `HUELLAS.sha256` internas de v2 y de v3 verifican
**todas** sus entradas en el original rescatado (excepto, por diseño, las que apuntan a ficheros
externos que ya no están); es decir, el material rescatado es internamente coherente.

## 4 · Reproducibilidad (reejecución)

Comandos exactos, desde cada copia, con `JULIA_NUM_THREADS` indicado:

```bash
env -u LD_LIBRARY_PATH julia --check-bounds=yes --project=. test/runtests.jl
env -u LD_LIBRARY_PATH julia --project=. run.jl --seed 0x5a5a --replicas 64   # v0.2 (METODO.md)
env -u LD_LIBRARY_PATH julia --project=. run.jl --seed 0x5a5a --replicas 24   # v0.3 (METODO.md)
env -u LD_LIBRARY_PATH julia --project=. bench/benchmarks.jl
env -u LD_LIBRARY_PATH julia --project=. bench/io_lectura.jl
```

| Corrida | Resultado | Fichero |
|---|---|---|
| v0.2 tests `--check-bounds=yes` | `131/131` a 7,0 s (original 7,2 s) | `registros/v2-tests.txt` |
| v0.3 tests `--check-bounds=yes` | `76/76` a 4,2 s (original 4,1 s) | `registros/v3-tests.txt` |
| v0.2 `run.jl --replicas 64` | 13,9 s; **todos los artefactos numéricos idénticos** | `registros/v2-run-64.txt` |
| v0.3 `run.jl --replicas 24` | 13,7 s; **todos los artefactos numéricos idénticos** | `registros/v3-run-24.txt` |

El detalle de la comparación fichero a fichero está en `INFORME.md` §2.1.

## 5 · Bitácora

- **16:42** Verificación de entradas (94/94 OK), `date`, `uptime`, `git status`. GDR sin cambios
  desde 2026-09-18. Copia de v2 y v3 y parche de ruta (diff guardado, §3).
- **16:42–16:44** Tests de v2 (131/131) y de v3 (76/76) con `--check-bounds=yes`.
- **16:43–16:44** `run.jl` de v2 (64 réplicas) y de v3 (24 réplicas): todos los resultados
  numéricos reproducen byte a byte; solo cambia `ENTORNO.txt` (fecha e hilos).
- **16:44–16:46** Benchmarks v2/v3 y microbenchmark de I/O (`registros/benches.txt`).
- **16:45** Instantánea de inicio completa en `registros/inicio.txt`.
- **16:46–16:47** Lectura íntegra del encargo 07v2, de `veritas/LINEO.md` (627 líneas) y del código
  de v0.2 y v0.3 (`src/`, `test/`, `run.jl`, `bench/`). Comprobación propia de la derivación de
  semillas: `verificacion/semillas.jl` y `verificacion/diagnostico.jl` (`registros/semillas.txt`).
  **Primer intento con `set_counter!(r, id)` era erróneo** (los flujos se solapan): corregido a
  `set_counter!(r, (0, id))` y documentado como trampa de uso (§2.5 de `INFORME.md`, A2 de
  `DEFECTOS.md`).
- **16:48–16:51** Determinismo con 1, 2, 4 y 8 hilos: hash de `resultados/` idéntico en los dos
  instrumentos (`registros/determinismo-hilos.txt`).
- **16:49–16:53** Certificación exacta de las cotas de la DP con `Rational{BigInt}`
  (`verificacion/dp_exacto.jl`, `registros/dp-exacto.txt`). **Mi primera versión del certificado de
  `α_prob` supuso `P` decreciente en `α` y dio «INCONCLUSO»: el error era mío** (`α` es la tasa del
  adversario, `P` crece). Corregido; certificado.
- **16:50–16:54** Redacción de `INFORME.md`, `BASELINE.md`, `DEFECTOS.md` y
  `RECOMENDACION-MIGRACION.md`. Extracción mecánica de apoyo (a cargo de dos subagentes, con
  verificación línea a línea contra la fuente) en `notas/spec-tareas-matrices.md` (1051 líneas) y
  `notas/revisiones-internas.md` (692 líneas).
- **16:54** Comprobaciones de cierre (`registros/fin.txt`): `sha256sum -c` **94/94 OK**, `git status`
  idéntico al de apertura, `date`, `uptime`. Barrido de ficheros modificados desde las 16:35 en
  `SPEC.md`, `TAREAS.md`, `ci/`, `crates/`, `research/`, `PDF/`, `prototipos/`, `veritas/`,
  `P-ZRX/rescate-deepseek/` y `P-ZRX/P-CRP/{PROMPT.md,ENTRADA.sha256}`: **vacío**. Los únicos
  ficheros ajenos modificados en la máquina pertenecen a otros encargos concurrentes
  (`P-ZRX/P-EQUIVOCACION/`, `P-ZRX/P-PERMANENCIA/`, `P-ZRX/P-CRP1/`).

## 6 · Entregables y artefactos

| Ruta | Qué es |
|---|---|
| `INFORME.md` | Informe; su primera línea es la respuesta. §2.1–§2.5 + veredicto + «Lo que esta auditoría NO resuelve» |
| `BASELINE.md` | Los seis escenarios, la propuesta de redacción para `SPEC.md`/`TAREAS.md` y el punto de partida de `P-ZRX/P-PRESTAMO/` |
| `DEFECTOS.md` | A (aleatoriedad), B (cifras y citas), C (correcciones ausentes), D (límites declarados) |
| `RECOMENDACION-MIGRACION.md` | Qué migrar, con qué correcciones y con qué etiqueta. **No he migrado nada** |
| `PROGRESO.md` | Este fichero |
| `copia/coste-rama-privada-v2/`, `copia/coste-rama-privada-v3/` | Copias con el parche de ruta de GDR (§3) y los `resultados/` reejecutados |
| `verificacion/semillas.jl`, `verificacion/diagnostico.jl`, `verificacion/dp_exacto.jl` | Mis comprobaciones (Julia, 1 hilo, sin dependencias nuevas) |
| `registros/` | Salidas crudas: `inicio.txt`, `fin.txt`, `v2-tests.txt`, `v3-tests.txt`, `v2-run-64.txt`, `v3-run-24.txt`, `benches.txt`, `determinismo-hilos.txt`, `semillas.txt`, `dp-exacto.txt` |
| `notas/` | Extracción mecánica de apoyo (SPEC/TAREAS/matrices y dictámenes internos), verificada línea a línea |

## 7 · Advertencias sobre el método (para quien repita esto)

- Los tres scripts de `verificacion/` se ejecutan con `--project=copia/coste-rama-privada-v3`; no
  añaden dependencias. `semillas.jl` y `diagnostico.jl` tardan ≈ 25 s y ≈ 57 s; `dp_exacto.jl`,
  ≈ 16 s. Todo con 1 hilo.
- **No publiques un contraste con `Random123` sin fijar la segunda palabra del contador.** Con
  `set_counter!(r, id)` las réplicas comparten casi todo el flujo (el flujo `id+1` es el `id`
  desplazado una salida) y la sobredispersión medida sube a 20,11 sin que el RNG tenga la culpa.
- Los tiempos de `BENCH.txt`/`IO.txt` **no** son reproducibles (máquina y carga). Las asignaciones
  sí coinciden.
- Las cifras de `notas/` son extracción, no juicio: el juicio está en `INFORME.md`, `DEFECTOS.md` y
  `BASELINE.md`.

## 8 · Cierre

- `P-ZRX/P-CRP1/auditoria/INFORME.md` **seguía sin existir** a las 16:55 (solo `copia/`, `veritas/`,
  `salidas/`, `julia-local.sh`): el veredicto de ese encargo sobre los diez defectos de CRP-v0.1 no
  ha entrado en este análisis.
- Comprobación de cierre (`registros/fin.txt`): `sha256sum -c P-ZRX/P-CRP/ENTRADA.sha256` → **94/94
  OK**; `git status --short` idéntico al de apertura; ningún fichero de `SPEC.md`, `TAREAS.md`,
  `ci/`, `crates/`, `research/`, `PDF/`, `prototipos/`, `veritas/` ni `P-ZRX/rescate-deepseek/`
  modificado desde las 16:35.
- Todo lo escrito vive en `P-ZRX/P-CRP/auditoria/`. `PROMPT.md` y `ENTRADA.sha256` no se han tocado.
