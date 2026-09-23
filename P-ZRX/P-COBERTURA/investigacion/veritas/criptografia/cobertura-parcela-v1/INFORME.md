# INFORME del instrumento — `cobertura-parcela-v1`

**Categoría:** `criptografia` (dominante: propiedades de un compromiso y de una prueba
de verificación sucinta). Secundarias: `almacenamiento` (regeneración contra auditoría)
y `consenso` (coste del registro). **Fecha:** 2026-09-22.
**Encargo:** `P-ZRX/P-COBERTURA/PROMPT.md`. **Informe principal:** `../../INFORME.md`.

**Presupuesto declarado antes de ejecutar:** máximo **4 hilos** (tope del encargo),
**8 GiB de RAM**, **256 MiB de disco**, **2 h de pared**. **No se agotó** (≈ 90 s de pared
la corrida completa). Julia 1.13.0, CPU `znver5`, `--check-bounds=yes` en el perfil de
referencia.

## 1 · Qué calcula y qué no

Calcula el **juego regeneración contra auditoría** y su frontera exacta:

1. `almacenamiento_forzado(N, B) = max(0, 1 − B/N)` si `k > B`, y `0` si `k ≤ B`
   (`B` = unidades que el adversario regenera dentro de la ventana `w·τ + D_a`).
2. La **cola hipergeométrica exacta** `P(X > B)`, `X ~ Hipergeom(N, M, k)` —sin
   reemplazo, que es el modelo correcto— contra la que se valida todo lo demás.
3. El **encierre riguroso** con redondeo dirigido a 256 bits (ancho relativo ≈ 4·10⁻⁷⁴).
4. Un **oráculo independiente de Monte Carlo** con Philox contracontador.
5. El **coste absoluto** del tramposo por TiB ahorrado y el cruce con el precio del disco.
6. La **reconciliación** de las dos cifras de coste publicadas (§1.3 del encargo).
7. El **coste del registro** (F5): altas, estado y caducidad pseudoaleatoria.

**No** decide el teorema de imposibilidad: eso es argumento del `INFORME.md` principal.
El instrumento comprueba su parte cuantitativa (la frontera) y mide sus números.

## 2 · Estructura (LINEO §1)

| Fichero | Contenido |
|---|---|
| `src/modelo.jl` | símbolos, `Entrada`, `B`, frontera, coste, cruce con disco, coste del registro |
| `src/referencia.jl` | `Rational{BigInt}` exacto, encierre `BigFloat`, cota de acoplamiento, Clopper–Pearson |
| `src/rapido.jl` | kernel `Float64` tipoestable, tabla de log-factoriales, barrido sin asignaciones |
| `src/validacion.jl` | Monte Carlo con Philox, autocorrelación lag-1, contrastes |
| `test/runtests.jl` | 11 833 comprobaciones |
| `bench/benchmarks.jl` | `BenchmarkTools` + `Profile` |
| `run.jl` | CLI reproducible; `--check-bounds=yes` no aplica aquí |
| `resultados/` | artefactos generados (no fuente de verdad) |

## 3 · Elección de la representación

La operación dominante es **evaluar la cola hipergeométrica para muchos `M` con `N` y `k`
fijos** (el barrido en φ). Representación elegida: **una tabla de log-factoriales
`Vector{Float64}` precalculada una vez**, bucle interior escalar sobre `j` y salida
preasignada con una posición exclusiva por celda. Motivo: el pmf hipergeométrico es un
cociente de tres factoriales, así que `log C(n,k)` con diferencias de la tabla es O(1) por
término, `0` asignaciones en el bucle y acceso estrictamente contiguo. Un `Dict` o un
`Vector{Vector}` no tendrían justificación aquí.

## 4 · Validación (lo que hace que las cifras valgan)

| Contraste | Oráculo de naturaleza distinta | Resultado |
|---|---|---|
| Frontera `P(X>B)=0 ⟺ M≤B ó k≤B` | enumeración combinatoria pura | 4 953 casos, 0 fallos |
| Kernel `Float64` | `Rational{BigInt}` exacto | 1 445 casos, error máx < 10⁻¹⁰ |
| Encierre 256 bits | `Rational{BigInt}` | 1 200 casos, **todos contienen el valor exacto** |
| Cota de acoplamiento `k(k−1)/(2N)` | distancia de variación total exacta | 728 casos, la cota nunca se viola |
| Monte Carlo Philox | fórmula exacta, intervalo de Clopper–Pearson | dentro del intervalo en todas las celdas |
| Muestreador sin reemplazo | enumeración de los 15 subconjuntos de `N=6, k=2` | 30 000 réplicas dentro del ±10 % |
| Autocorrelación lag-1 | el test que delata semillas consecutivas | \|a\| < 0,02 (Philox contracontador) |
| Coste | identidades algebraicas `núcleos = máquinas·(r·t)` | 9 comprobaciones |
| NO-CONSTANTE | direcciones de cambio al barrer parámetros | 11 comprobaciones |
| Clopper–Pearson | valores publicados (0,0667–0,6525 para 3/10) | 9 comprobaciones |

**Cuatro defectos propios encontrados y corregidos durante la construcción** (detalle en
`PROGRESO.md`): (1) el término base del encierre estaba mal cuando el soporte no empieza
en 0 —daba 48 fallos—; (2) las dos colas de Clopper–Pearson estaban intercambiadas y el
bisección trataba la CDF binomial como creciente cuando es decreciente; (3) el nombre
`phi_libre` era engañoso: la cantidad es el **almacenamiento forzado**, no la fracción
omitible; (4) la suma en espacio logarítmico podía dar `1,0000000155` y se recorta a 1
con el supuesto documentado.

## 5 · Rendimiento medido

Caso representativo: `N = 1 048 480`, `k = 1 000`, `B = 25`, barrido de 64 celdas en φ.

| Variante | Tiempo mediano | Asignaciones | Memoria | Hilos |
|---|---:|---:|---:|---|
| Oráculo exacto `Rational{BigInt}` | sólo `N ≤ ~2 000` | — | — | 1 |
| Kernel `Float64` (64 celdas) | **0,181 ms** | **0** | **0 B** | 1 |
| Encierre 256 bits (1 celda) | ≈ 1,1 ms | — | — | 1 |

`resultados/BENCH.txt`. El barrido **no escala con hilos** porque es una carga
secuencial de `0,18 ms`: paralelizarla no tiene sentido y no se hizo. `JET.report_package`
analizó las 68 definiciones de nivel superior sin errores (`resultados/JET.txt`);
`Profile` atribuye el tiempo a `rapido.jl:72` y a `exp` (`BENCH.txt`).

## 6 · Artefactos

`resultados/F4-frontera.tsv` · `F4-coste.tsv` · `F4-reconciliacion.tsv` ·
`F3-deteccion.tsv` · `F3-exacto-racional.tsv` · `certificado.tsv` · `F5-registro.tsv` ·
`TEST.txt` · `BENCH.txt` · `JET.txt` · `VALIDACION.txt`.

## 7 · Reproducción

```bash
cd /home/katana/zeo/ZEROX
LC_ALL=C sha256sum -c P-ZRX/P-COBERTURA/ENTRADA.sha256
cd P-ZRX/P-COBERTURA/investigacion/veritas/criptografia/cobertura-parcela-v1
./correr-modelo.sh          # ≈ 90 s con el depósito ya creado; ≈ 2 min la primera vez
```

`correr-modelo.sh` fija `JULIA_DEPOT_PATH` al depósito local `investigacion/.julia-depot`
(con `/home/katana/.julia` como segundo depósito de sólo lectura). Ese depósito es caché de
precompilación (~296 MB) y **no forma parte del entregable**: se retiró para respetar el
presupuesto de disco declarado, y la primera corrida lo recrea automáticamente (verificado:
`using CoberturaParcela` funciona tras borrarlo, en 23 s). `Manifest.toml` fija el árbol
exacto, así que la recreación es determinista.

## 8 · Lo que este instrumento NO calcula

- La decisión del teorema de §2.2 del encargo (es argumento, no cómputo).
- El coste mínimo real del ataque: `r = 25,03` es **cota superior** del código publicado;
  SIMD, GPU y ASIC no están medidos. Ninguna garantía se deriva de `r`.
- El `(c, D_a)` que un granjero doméstico sostiene en el peor caso.
- `π_DAG` y la varianza de pago del DAG de ZEROX.
- Ningún parámetro de consenso: `N`, `k`, `w`, `D_a`, `M`, `κ`, `h`, φ y los precios son
  **entradas**.
