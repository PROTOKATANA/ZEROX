# Método reproducible

Instrumento Julia CPU (sin GPU): simulación de eventos discretos. El **oráculo**
(`src/referencia.jl`) selecciona el siguiente evento con escaneo lineal sobre un Vector de
structs; el **kernel** (`src/rapido.jl`) usa un heap binario SoA preasignado (0 asignaciones
en el bucle de eventos). Comparten la semántica pura de `src/modelo.jl`; `validar_equivalencia`
compara las matrices de llegada **bit a bit** en instancias pequeñas, y desde la r2 también las
medias por bloque y por nodo. Casos calculados a mano con fracciones binarias exactas en
`test/runtests.jl` (camino de 4 nodos, estrella, medias, cuotas, ρ). Suite: 25 598 asserts con
`--check-bounds=yes` (25 040 de la r1, 553 de la r2 y 5 de su corrección), salida en
`resultados/TESTS.txt`.

Comandos publicados desde la **raíz del repositorio**:

```bash
# Tests (verde: 25 598 asserts, --check-bounds=yes)
env JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 veritas/julia.sh \
  --project=veritas/finalidad/delta-medido-v1 --check-bounds=yes \
  veritas/finalidad/delta-medido-v1/test/runtests.jl

# r1: barrido principal y sensibilidad (INFORME §4 y §6)
JULIA_NUM_THREADS=24 OPENBLAS_NUM_THREADS=1 env -u LD_LIBRARY_PATH veritas/julia.sh \
  --project=veritas/finalidad/delta-medido-v1 veritas/finalidad/delta-medido-v1/run.jl
JULIA_NUM_THREADS=24 OPENBLAS_NUM_THREADS=1 env -u LD_LIBRARY_PATH veritas/julia.sh \
  --project=veritas/finalidad/delta-medido-v1 veritas/finalidad/delta-medido-v1/run.jl --sensibilidad

# r2: rejilla, concentración, t_proc y control de saturación (INFORME §11)
JULIA_NUM_THREADS=24 OPENBLAS_NUM_THREADS=1 env -u LD_LIBRARY_PATH veritas/julia.sh \
  --project=veritas/finalidad/delta-medido-v1 veritas/finalidad/delta-medido-v1/run.jl --r2 --r2-subtarea rejilla
JULIA_NUM_THREADS=24 OPENBLAS_NUM_THREADS=1 env -u LD_LIBRARY_PATH veritas/julia.sh \
  --project=veritas/finalidad/delta-medido-v1 veritas/finalidad/delta-medido-v1/run.jl --r2 --r2-subtarea concentracion
JULIA_NUM_THREADS=24 OPENBLAS_NUM_THREADS=1 env -u LD_LIBRARY_PATH veritas/julia.sh \
  --project=veritas/finalidad/delta-medido-v1 veritas/finalidad/delta-medido-v1/run.jl --r2 --r2-subtarea tproc
JULIA_NUM_THREADS=24 OPENBLAS_NUM_THREADS=1 env -u LD_LIBRARY_PATH veritas/julia.sh \
  --project=veritas/finalidad/delta-medido-v1 veritas/finalidad/delta-medido-v1/run.jl --r2 --r2-subtarea saturacion

# Benchmark y perfil
JULIA_NUM_THREADS=4 OPENBLAS_NUM_THREADS=1 env -u LD_LIBRARY_PATH veritas/julia.sh \
  --project=veritas/finalidad/delta-medido-v1 veritas/finalidad/delta-medido-v1/bench/benchmarks.jl
```

`veritas/julia.sh` ya elimina `LD_LIBRARY_PATH`; los `env -u` de arriba son redundantes y
defensivos. Tope: 24 hilos de cómputo y 64 GiB de RAM (nunca `--threads=auto` ni
`@fastmath`). Determinismo: misma semilla maestra 0x5a5a, derivación splitmix64 por
(combo, réplica); reducción por orden de réplica; verificado con dos ejecuciones completas
idénticas salvo `segundos_pared`.

Traza en `resultados/`: `corridas.csv`, `resumen.csv` (la r2 añade `rho` y `regimen`),
`medias_bloque-<id>.csv` (media por bloque, %.9f s), `medias_nodo-<id>.csv` (media por nodo
en **µs enteros**, redondeo ≤0,5 µs ≈ 4 órdenes por debajo del ruido de muestreo de ~1 ms;
declarado), `media_bloque_espacio-<id>.csv` (sólo concentración), `ENTORNO.txt`, `RUN.txt`.
Tamaño total de `resultados/` en la enmienda: **47 MB** (< ~50 MB declarado).

**Trazas no versionadas (decisión de Katana, 2026-09-14).** Las 140 trazas `medias_bloque-*`,
`medias_nodo-*` y `media_bloque_espacio-*` no están en el repositorio; con ellas `resultados/`
ocupaba 47 MB, y `veritas/` versionaba 368 kB de resultados en total. Su huella está en
`TRAZAS.sha256`, con rutas relativas a la raíz del repositorio. Para comprobarlas, regenera en
una **copia** del instrumento colocada en `<dir>/veritas/finalidad/delta-medido-v1/`, ejecuta los
comandos r2 dentro de la copia y verifica desde `<dir>` con `sha256sum -c TRAZAS.sha256`. No
regeneres en su sitio: sobrescribe los `corridas.csv` (distintos en `segundos_pared`),
`ENTORNO.txt` y `RUN.txt` versionados. Las trazas son deterministas: Claude las reprodujo byte a
byte con 16 hilos frente a las de 24.

## Fuentes contra las que se validó (sha256 calculado al EMPEZAR la tarea, 2026-09-13)

| Ruta | sha256 |
|---|---|
| `AGENTS.md` | `7379c5e175e69c371587a5d83c71e110f9261790ea64bdaf6b02481cecd08a78` |
| `README.md` | `aa093c1550f018255b0c10506ff3e605c256ed75b6c7f86e6bf14074ce76ac92` |
| `MIGRACION.md` | `169669df9bf4562b12a2a985c500dabd561a26ea7917cb58d728229c6099945b` |
| `SPEC.md` | `1683af53e6c118213ea5ddfa85872a9e3470e72e20eea51ca308296aa4deb92f` |
| `TAREAS.md` | `f4a76faa60c615fe141026454927fbb1c82a08286367850f4ac1640b5936d4d1` |
| `ZEROX-EN-NUMEROS.md` | `d25e2fa6275095f04cb01574722c854845dd123ab2f596295bfcdef098827828` |
| `veritas/LINEO.md` | `0343b83290489fde1b3ba961eb8fdd1f7ccb1bdf1ea1ee7062db993fc48936e1` |
| `veritas/finalidad/baseline-30m/MODELO.md` | `e025e220f1d1ad3ccfdd468802e78976ab4fb3f458f997569d6911e2beeb8990` |
| `research/scripts/d9-ronda11a/informe.md` | `0e7b950673da58b78264f5434cbb0808893b865d1c439368d33a2f151f6519a5` |
| `research/dag-poas-ancla-de-orden.md` | `55e5c8158c9e495c9ba47f97bb834dd23d0b3fff44e46def98ea3d7f952b1a6a` |

Nota: la huella de `SPEC.md` corresponde al árbol de trabajo (la versión contra la que se
ejecutó), igual que en RCE-v0.1 tras su enmienda (véase `ENMIENDA-Z0.md`).

`HUELLAS.sha256` lo generó Claude al migrar (2026-09-14), desde la raíz del repo y con las rutas
finales; es la comprobación vigente. Esta tabla y `FUENTES-R2.sha256` son el **registro
histórico** de lo que DeepSeek leyó al empezar. La huella de `TAREAS.md` ya no coincide porque la
migración lo actualizó.
