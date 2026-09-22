# Informe — RNG-v0.1 (rango de solución: paridad, dominio y controlador entero)

**Categoría:** `consenso`. La pregunta dominante es de aritmética y reglas de consenso (dominio del
rango, residuo de paridad, forma del controlador); la seguridad aparece como motivación, no como el
tema del directorio. Por eso vive en `consenso` y no en `seguridad`.

## Pregunta

El encargo P-RANGO (§4) pide comprobar, **solo si hacía falta para decidir la redacción**, dos cosas
exactas: (a) qué residuo de paridad queda **con el redondeo que se propone** (rejilla par) frente al
`1/(SR+1)` que `TAREAS.md` §2.3 anota con `SR` impar; y (b) si el dominio de `SR` se desborda
(`SR = 0` da `w = 2^128`, fuera de `u128`, C-GD-01) y con qué anchura entera se sostiene el
controlador sin precondiciones ocultas.

## Método

Aritmética **exacta** `Rational{BigInt}` / `BigInt`, sin `Float64` en ninguna decisión (LINEO §5.3).
Oráculo independiente para `A(SR)` por **enumeración en un círculo pequeño** (`m = 256` y `1024`),
contra la fórmula cerrada de PCO-v0.1. Kernel del controlador en `UInt128` comprobado
(`Base.Checked`) contra una referencia `BigInt` paso a paso. Muestra aleatoria con `StableRNGs` y
semilla fija. Todo reproducible con:

```bash
R=P-ZRX/P-RANGO/propuesta/veritas/consenso/rango-v1
./veritas/julia.sh --project=$R $R/run.jl --seed 592137
./veritas/julia.sh --project=$R $R/test/runtests.jl
./veritas/julia.sh --project=$R $R/bench/benchmarks.jl
./veritas/julia.sh --project=$R $R/bench/perfil.jl
```

Presupuesto declarado: **máximo 4 hilos, 4 GiB de RAM, 1 GiB de disco temporal, 30 min de pared.**
Uso observado: muy por debajo; sin timeout. Entorno en `resultados/ENTORNO.txt` (Julia 1.13.0,
`znver5`, 32 hilos lógicos visibles, 4 hilos de cómputo).

## Resultado

1. **`A(SR)` verificada contra un oráculo independiente.** Enumeración exhaustiva en círculos de
   256 y 1024 puntos: **0 discrepancias** con `2·(SR ÷ 2) + 1` para todos los `SR` del círculo.
2. **El residuo de paridad con la rejilla par es el suelo, no la paridad.** Para todo `SR` par,
   `1 − razón(SR) = (2^128 mod (SR+1))/2^128 < 2^{−64}` (porque `SR+1 ≤ 2^64`). Para `SR` impar el
   déficit es `≥ 1/(SR+1)` y es exactamente `1/2048 = 4,88·10^{−4}` en `SR = 2047`, la cifra que
   anota `TAREAS.md` §2.3. **Forzar `SR` par elimina el residuo de paridad; solo queda el suelo,
   que es 64 bits por debajo del último bit del peso.**
3. **Dominio.** `w(0) = 2^128 > typemax(UInt128)` (demostrado, no supuesto);
   `w(2^64 − 1) = 2^64`, que es el mínimo de C-GD-01. Con `SR ≥ 2` par, `w ≤ 2^127` y cabe en
   `u128`.
4. **Anchura del controlador.** Con tres factores `u64` (`SR_max`, `d`, `N`), el producto es
   `< 2^192`: cabe **siempre** en `u256` (el tipo de `blue_work`, C-GD-02) y **no** siempre en
   `u128`. La precondición de RCE-v0.1 (`SR_max·d·typemax(u64) ≤ typemax(u128)`) es **necesaria**
   en 128 bits y se ha visto **rechazar** (no saturar) una configuración fuera de dominio.
5. **Kernel == referencia** en la rejilla de regresión (94 `SR`, bordes de paridad, potencias de dos,
   extremos de `u64`) y en 2 040 casos (rejilla de regresión + 2 000 aleatorios): 0 discrepancias, 0 salidas
   impares, 0 fuera de dominio. **Z0 es no-op** y la activación diferida reproduce `MissedUpdate`.

**Lo que NO se mide aquí:** estabilidad del retarget, viveza, seguridad PoAS, ni el efecto de una
rama privada. Este instrumento comprueba aritmética de dominio y redondeo, nada más.

## Verificación

| Variante | Tiempo mediano | Asignaciones | Hilos/backend | Resultado frente a referencia |
|---|---:|---:|---|---|
| Oráculo `A(SR)` por enumeración (`m ≤ 1024`) | — | — | 1 CPU | fuente de verdad del conteo |
| Referencia `controlador_ref` (`BigInt`) | 541 ns | 58 allocs | 1 CPU | fuente de verdad exacta |
| Kernel `controlador_fast` (`UInt128` comprobado) | **8,62 ns** | **0 allocs, 0 B** | 1 CPU | idéntico en los 2 040 casos |
| Kernel `peso_fast` (4 096 `SR`) | 22 469 ns (≈ 5,5 ns/`SR`) | **0 allocs, 0 B** | 1 CPU | idéntico a `peso_big` |

`code_warntype` sobre `controlador_fast`: 0 líneas con `::Any`; tipo de retorno inferido
`Tuple{UInt64, Bool}`. JET 0.12.1 `report_opt` sobre `controlador_fast` y `peso_fast`:
**0 diagnósticos** (`resultados/JET.txt`).

## Reproducción

- `resultados/RUN.txt` — comprobaciones y tabla de paridad (semilla `592137`).
- `resultados/TESTS.txt` — 38/38.
- `resultados/BENCH.txt`, `resultados/PERFIL.txt`, `resultados/CODEWARNTYPE.txt`, `resultados/JET.txt`.
- `resultados/ENTORNO.txt` — git, fecha, Julia, CPU, hilos, semilla y presupuesto.
- `Project.toml` + `Manifest.toml` versionados; dependencias usadas: `BenchmarkTools`,
  `StableRNGs`, `JET` (`Test`/`Random` por `[extras]`).
