# PROGRESO — PRV-v0.1 (ENCARGO-06-prueba-recursiva)

Bitácora. Horas de `date`, no estimadas. Todo ocurre dentro de `deepseek/`; `veritas/` sólo se
leyó (el encargo 05 migrado). Se migrará como `BITACORA.md`.

## Postura sobre el §2, dicha antes de ejecutar

**La trampa es real y es la pregunta correcta.** Una prueba recursiva acredita validez de una
historia; la cadena canónica de GHOSTDAG es una propiedad del **conjunto** de ramas (máximo
`blue_work` entre todas las puntas, §11). Ninguna prueba que sólo valide una historia puede
decidir una propiedad que depende de las demás. Confirmo el planteamiento del encargo; no tengo
objeciones que plantear antes de ejecutarlo.

## Estado inicial (§6 del encargo)

```
$ date -Is
2026-09-17T23:51:44+02:00
$ git -C /home/katana/zeo/ZEROX status --short
 M SPEC.md
 M TAREAS.md
 M ci/reglas-sin-cablear.txt
 M ci/reglas-sin-codigo.txt
?? veritas/consenso/poda-post-v1/
$ git rev-parse HEAD
8dffd1c1a2487ca571cab9a7358c4b7ffb0a21af
```

Las cuatro modificaciones y el directorio sin seguimiento de `poda-post-v1` **ya existían**:
son la migración del encargo 05 por Claude, no de esta sesión. No se tocan.

## Cronología

| hora | paso | artefacto |
|---|---|---|
| 23:51 | lectura de `ENCARGO-06`, `volumen veritas/consenso/poda-post-v1/` (D5, INFORME §1.2/§4, PROPUESTA P3, PROCEDENCIA §2-3.2), SPEC §9/§11/§12.1, TAREAS §2.4/§2.6, `research/orchard-*.md` | — |
| 23:52 | fuentes externas comprobadas: `halo2_poseidon` P128Pow5T3 (R_F=8, R_P=56, ancho 3, x^5) y `halo2` Book «Proving system» | INFORME §3.2 |
| 23:54 | `Project.toml` recortado (9 dependencias), `Pkg.resolve()` + `instantiate()`; `Manifest.toml` nuevo | `Project.toml`, `Manifest.toml` |
| 23:55-23:58 | `src/` (modelo, referencia, rápido, validación, módulo), `run.jl`, `test/`, `bench/` | `src/`, `run.jl` |
| 23:56 | primer fallo: `StableRNG` no importado en `run.jl` y en el script de depuración; corregido | — |
| 23:56 | oráculo independiente del conteo: `tam` del GDR excluye el propio `x`; `anticono_en` corregido (diferencia de 1) | `referencia.jl` |
| 23:57 | suite en verde (20/20) con `--check-bounds=yes` | `resultados/TESTS.txt` |
| 23:58 | `--seleccion`, `--coste`, `--barrido`, `--lineal`, `--orchard`, `--fuentes`, `--entorno` | `resultados/run-*.txt` |
| 23:59 | `bench/benchmarks.jl` y `bench/escalado.jl` (1→24 hilos) | `resultados/BENCH.txt` |
| 00:0x | `INFORME.md`, `MODELO.md`, `CONTRATO.md`, `PROPUESTA.md`, `METODO.md`, `HUELLAS.sha256` | este directorio |

## Decisiones de método

1. **El oráculo de GHOSTDAG es GDR-v0.2, reutilizado** (`incluir_ghostdag`), no reimplementado. El
   conteo rápido lee sus campos (`gd[i].ms_ordenado`, `gd[sp].blueset`, `gd[i].tam`, `est.idents`).
2. **Referencia independiente** del conteo: `mergeset_referencia` recalcula por conjuntos y
   `anticono_en` por ancestría desde la definición del SPEC. La validación compara ambos.
3. **La cota de coste excluye** firmas, KZG, PoT y UTXO: es una cota **inferior**. La tasa de
   operaciones de campo es **declarada** con tres valores; el informe da la tasa de cierre para
   los tres.
4. **No se fija `W`** (profundidad de fusión, C-GD-11): el coste y la ventana crítica van como
   función de `W`.

## Fallos y correcciones

1. `run.jl` usaba `StableRNG` sin `using StableRNGs`; añadido.
2. El oráculo GDR calcula `tam[x]` **sin** contar `x` a sí mismo; mi referencia lo contaba. Corregido
   en `anticono_en` (`b == x && continue`). Era el único fallo de equivalencia.
3. Advertencia de *world-age* de Julia 1.12+ al leer el módulo anidado de GDR; resuelta con
   `Base.invokelatest(getfield, m, :GhostdagRank)`.

## Estado final (§6 del encargo)

```
$ date -Is
2026-09-18T00:03:37+02:00
$ git -C /home/katana/zeo/ZEROX status --short
 M SPEC.md
 M TAREAS.md
 M ci/reglas-sin-cablear.txt
 M ci/reglas-sin-codigo.txt
?? veritas/consenso/poda-post-v1/
```

**Idéntico al inicial.** `deepseek/` está en `.gitignore` (`.gitignore:18`), así que el instrumento
no aparece como `??` y no se tocó nada versionado. No se modificaron `crates/`, `SPEC.md`,
`TAREAS.md`, `veritas/` ni `.git`.

## Cierre

- **Selección: NO**, demostrado (Proposición §1 del INFORME) e instanciado con GDR-v0.2.
- **Coste: no cierra a 1 bloque/s** con Halo2 realista para ventanas de escala finalidad; `W*` y
  las tasas, en el INFORME §2.
- Suite **20/20**; huellas en `HUELLAS.sha256`, verificables con `sha256sum -c` desde la raíz.
- `Project.toml` con **9 dependencias** (ninguna superflua).
