# MÉTODO — PCO-v0.1

Todos los comandos se ejecutan **desde la raíz del repositorio** (`/home/katana/zeo/ZEROX`), con
`veritas/julia.sh` (que quita `LD_LIBRARY_PATH`, LINEO §1) y
`--project=P-PUERTA/veritas/consenso/puerta-cobertura-v1`.

```
PRO=P-PUERTA/veritas/consenso/puerta-cobertura-v1
```

## 0 · Huellas de entrada y estado del repositorio

Al empezar y al terminar, y con su salida copiada en `PROGRESO.md`:

```bash
date
LC_ALL=C sha256sum -c P-PUERTA/ENTRADA.sha256
git -C /home/katana/zeo/ZEROX status --short
git -C /home/katana/zeo/ZEROX rev-parse HEAD
```

## 1 · Entorno

```bash
veritas/julia.sh --project=$PRO -e 'using Pkg; Pkg.instantiate(); Pkg.status()'
veritas/julia.sh --project=$PRO --threads=2 $PRO/run.jl --entorno
```

`julia-version.toml` fija `1.13.0`; `Manifest.toml` está versionado.

## 2 · Tests

Dos perfiles, como pide LINEO §7 («referencia» y «rendimiento»). El de referencia lleva las
comprobaciones de límites activas:

```bash
# perfil de referencia: un hilo, comprobacion de limites activa
veritas/julia.sh --check-bounds=yes --project=$PRO --threads=1 $PRO/test/runtests.jl

# perfil de rendimiento: los 2 hilos del presupuesto
veritas/julia.sh --project=$PRO --threads=2 $PRO/test/runtests.jl
```

## 3 · Los cuatro entregables

**Punto 1 — el modelo de peso** (enteros exactos, instantáneo):

```bash
veritas/julia.sh --project=$PRO --threads=2 $PRO/run.jl --peso
# -> resultados/peso.csv, peso-sesgo.csv, peso-beta.csv
```

**Punto 2 — la dinámica, `L(t)` y `t(ε)`**:

```bash
veritas/julia.sh --project=$PRO --threads=2 $PRO/run.jl --dinamica --lambda 1
# -> resultados/dinamica.csv, curva-L.csv
```

**Punto 2c — congelamiento simultáneo, la regla de R-FIN-7 por profundidad** (lo que sustituye a la
regla de absorción de la primera versión):

```bash
veritas/julia.sh --project=$PRO --threads=2 $PRO/run.jl --congelamiento \
  --replicas 6000 --seed 0x5A5A
# -> resultados/congelamiento.csv, congelamiento-realimentado.csv
```

**Punto 2b — regla superada, conservada para el registro** (Monte Carlo):

```bash
veritas/julia.sh --project=$PRO --threads=2 $PRO/run.jl --absorcion \
  --replicas 6000 --seed 0x5A5A --tope-eventos 3e8
# -> resultados/absorcion.csv, realimentacion.csv
```

**Punto 3 — cobertura y `S_max`** (analítico, instantáneo):

```bash
veritas/julia.sh --project=$PRO --threads=2 $PRO/run.jl --cobertura
# -> resultados/smax.csv, cobertura.csv
```

**Punto 4 — la magnitud de arcoseno**:

```bash
veritas/julia.sh --project=$PRO --threads=2 $PRO/run.jl --arcoseno \
  --replicas 6000 --seed 0x5A5A
# -> resultados/arcoseno-exacto.csv, arcoseno-mc.csv
```

**Certificación con aritmética de bolas**:

```bash
veritas/julia.sh --project=$PRO --threads=2 $PRO/run.jl --certificado
# -> resultados/certificado.csv
```

**Todo de una vez** (es lo que produjo los CSV del informe):

```bash
veritas/julia.sh --project=$PRO --threads=2 $PRO/run.jl --todo \
  --lambda 1 --replicas 6000 --seed 0x5A5A --tope-eventos 3e8
```

## 4 · Benchmark

```bash
veritas/julia.sh --project=$PRO --threads=2 $PRO/bench/benchmarks.jl
# -> resultados/bench.txt
```

## 5 · Semilla, unidades y parámetros

- **Semilla maestra**: `0x5A5A`. Cada réplica usa `rng_replica(semilla, id)` = **Philox
  contracontador** (`Random123`), con el id como **clave**, no como semilla consecutiva. La
  reducción recorre el vector en orden de id, así que el resultado **no depende del número de
  hilos**. *No usar `StableRNG(semilla + id)`*: da autocorrelación lag-1 de `−0,43` entre réplicas
  y sesga el Monte Carlo (`PROGRESO.md`, defecto D4). Hay test de regresión.
- **Unidad de tiempo**: el slot. `λ = 1` significa «un bloque azul por slot y por flujo». `L`
  depende de `λ` y `t` **solo a través de `λ·t`** (lo comprueba `test/runtests.jl`), así que
  `t(ε)` en otra `λ` se obtiene dividiendo. **No se fija la duración del slot en segundos.**
- **Nada de `F`, `L`, `I`, `ρ_max`, `Δ`, `k` fijado**: `F` se barre en
  `{600, 3600, 7200, 11520, 19080}` s, `Δ ∈ {1,4,16}` s, `k ∈ {18,30}`, `c ∈ [0,1]`,
  `s₁ ∈ [1/2,1]`. Cada tabla lleva sus valores en las columnas.

## 6 · Presupuesto real frente al declarado

Medido en la corrida final (`--lambda 1 --replicas 6000 --seed 0x5A5A --tope-eventos 3e8`,
2 hilos, `OPENBLAS_NUM_THREADS=1`):

| Orden | Tiempo de pared medido | Tope declarado |
|---|---:|---|
| `--entorno` | 0,1 s | — |
| `--peso` | 0,0 s | — |
| `--dinamica` (incluye `curva-L.csv`) | 2,3 s | — |
| `--congelamiento` (analítico + Monte Carlo) | 275,0 s | — |
| `--cobertura` | 0,0 s | — |
| `--arcoseno` | 14,5 s | — |
| `--absorcion` (Monte Carlo, regla superada) | 108,0 s | — |
| `--certificado` (48 puntos con `Arblib`) | 0,1 s | — |
| **Total** | **≈ 400 s** | 3 h |
| Hilos | 2 | 2 |
| RAM | < 1 GiB | 4 GiB |

El `--certificado` tardaba **302 s** antes de tabular la Poisson por recurrencia en vez de llamar a
`hypgeom_gamma_*` término a término (`PROGRESO.md`, defecto D2): la corrección lo bajó a 0,1 s y
además estrechó las bolas de radio `10¹³⁰` a la anchura del kernel.

Ninguna corrida se acercó al presupuesto. Nada quedó **inconcluso** por agotarlo; lo que sí queda
acotado por diseño es `tiempo_hasta`, que devuelve `NaN` cuando la media de Poisson necesaria
supera `2·10^8` y entonces solo se publica la cota superior certificada `tiempo_suficiente`.

## 7 · Huellas de salida

```bash
cd /home/katana/zeo/ZEROX && LC_ALL=C sha256sum -c $PRO/HUELLAS.sha256
```
