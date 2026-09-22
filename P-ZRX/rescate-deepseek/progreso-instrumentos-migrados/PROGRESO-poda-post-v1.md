# PROGRESO — PPP-v0.1 (ENCARGO-05-poda-post)

Bitácora de la sesión. Fechas y horas tomadas de `date`, no estimadas. Se migrará como
`BITACORA.md`. Todo ocurre dentro de `deepseek/`; `veritas/` sólo se leyó.

## Estado inicial (obligatorio, §5.6 del encargo)

```
$ date -Is
2026-09-17T16:01:53+02:00
$ git -C /home/katana/zeo/ZEROX status --short
 M SPEC.md
 M TAREAS.md
 M ci/reglas-sin-cablear.txt
 M ci/reglas-sin-codigo.txt
$ git -C /home/katana/zeo/ZEROX rev-parse HEAD
8dffd1c1a2487ca571cab9a7358c4b7ffb0a21af
```

Las cuatro modificaciones (`SPEC.md`, `TAREAS.md`, `ci/…`) **ya existían antes** de esta
sesión: son trabajo de Katana/Claude, no de este ejecutor. No se han tocado ni se tocarán.

`deepseek/` estaba vacío salvo `ENCARGO-05-poda-post.md`; no había `deepseek/MIDIENDO` ni
`deepseek/OCUPADO-CPU`, así que no hay convivencia de CPU que respetar.

## Conclusión con más consecuencias, escrita el mismo día que se determinó (§4)

**Una prueba de poda verificable NO exige `parents_by_level` en la cabecera, y añadirlo no la
haría funcionar.** El motivo es estructural, no de formato: un nivel basado en la solución PoAS
es independiente de los padres (la solución se encuentra antes de elegirlos), y un nivel basado
en el hash de cabecera —que sí liga a los padres— se muele con CPU y deja de medir
espacio-tiempo. Ninguno de los dos satisface a la vez «medible sin el DAG», «anclado a la
ancestría» y «proporcional a espacio-tiempo». Por tanto **§6.1–§6.2 no se reabren por poda** en
esta auditoría. Ver `INFORME.md` §4 para la demostración. Esta es la conclusión que hay que
poder leer sin seguir: no hay trabajo de cableado bloqueado por ella.

## Cronología

| hora (date) | paso | artefacto |
|---|---|---|
| 16:01 | `git status` inicial y HEAD; lectura de `veritas/LINEO.md` íntegro, `research/dag-poas-auditoria.md` (ATAQUE 7, §0.2), `SPEC.md` §6.1-§6.2/§7/§11/§17, `TAREAS.md` §2.4, GDR-v0.2 | — |
| 16:03 | copia de `veritas/plantilla` a `deepseek/veritas/consenso/poda-post-v1`; `Pkg.instantiate()` (0,7 s) | `Project.toml`, `Manifest.toml` |
| 16:04-16:06 | `src/modelo.jl`, `referencia.jl`, `rapido.jl`, `validacion.jl`, `PodaPost.jl`; `run.jl`, `test/runtests.jl`, `bench/` | `src/`, `run.jl` |
| 16:06 | primera suite: 3 fallos (una línea `f(x)=a; return b` mal parseada; comparar nivel exacto vs acumulado; ventana del verificador) | corregidos |
| 16:07 | `--entorno`, `--niveles`, `--multiples`, `--sranclaje`, `--cabeceras`, `--anclaje`, `--certificado` | `resultados/run-*.txt` |
| 16:08 | `--bluework` falla por *world age* al cargar GDR en caliente; se resuelve con `Base.invokelatest` | `resultados/run-bluework.txt` |
| 16:09 | `--retencion`; `--mc` con fórmula acumulada corregida; `--resumen`; `bench/benchmarks.jl`; escalado 1→24 hilos | `resultados/run-*.txt`, `resultados/BENCH.txt` |
| 16:10 | suite final en verde (85/85) con `--check-bounds=yes` | `resultados/TESTS.txt` |
| 16:11 | `INFORME.md`, `MODELO.md`, `CONTRATO.md`, `METODO.md`, `DERIVACIONES.md`, `PROPUESTA.md`, `HUELLAS.sha256` | este directorio |

## Fallos y correcciones (para que no se repitan)

1. **`hipotesis_nivel(L) = (L >= 1) || error(...); return ...`** — la forma de una línea con `;`
   deja el `return` fuera de la función y `L` queda indefinido. Corregido con `function`.
2. **Exhaustiva vs fórmula** — comparaba `P(nivel = L)` con `P(nivel ≥ L)`. La definición
   `solution_distance ≤ SR/2^L` es acumulada; se añadió `p_exhaustiva_ge`. Corregido.
3. **Verificador de ventana** — el bucle de ventana empezaba en `i`, de modo que no veía el hueco
   anterior. Se cuenta sobre todos los bloques en `[slot_i, slot_i+ventana]`. Corregido.
4. **`p_mc`** — devolvía nivel exacto; debe ser acumulado para comparar con la exacta. Corregido.
5. **MC con `SR=2^40`** — esperaba 0,6 bloques válidos en toda la corrida: el MC no medía nada.
   Se usa `SR=2^62` (validación del álgebra, no de un régimen físico). Documentado.
6. **World age con GDR** — `incluir_ghostdag()` crea el módulo en tiempo de ejecución; sus métodos
   no están en el mundo del llamador. Resuelto con `Base.invokelatest`.

Ninguno de los fallos cambió una conclusión; todos se registran como exige LINEO.

## Estado final (obligatorio, §5.6 del encargo)

```
$ date -Is
2026-09-17T16:13:17+02:00
$ git -C /home/katana/zeo/ZEROX status --short
 M SPEC.md
 M TAREAS.md
 M ci/reglas-sin-cablear.txt
 M ci/reglas-sin-codigo.txt
```

**Idéntico al inicial.** Las cuatro modificaciones siguen siendo las preexistentes; `deepseek/`
está en `.gitignore` (`.gitignore:18`), así que el instrumento no aparece como `??` y no ha
tocado nada versionado. No se modificó `crates/`, `SPEC.md`, `TAREAS.md`, `veritas/` ni `.git`.

Artefactos finales: `src/` (5 archivos), `test/runtests.jl` (85/85 en verde), `run.jl` (11 modos),
`bench/` (4 scripts), `resultados/` (16 archivos, incluidos `TESTS.txt`, `BENCH.txt`, `WARNTYPE.txt`
—0 coincidencias `::Any`—, `MEMORIA.txt` —0 B asignados—, `PERFIL.txt` —50 % en el kernel—) y los
7 documentos. `HUELLAS.sha256` cubre instrumento y fuentes leídas.

## Cierre

Veredictos: (1) poda local **sí, condicionada**; (2) prueba de poda e IBD sin confianza **no**,
por D5; (3) disponibilidad histórica **fuera del consenso**. §6.1 **no** se reabre. Ver `INFORME.md`.
