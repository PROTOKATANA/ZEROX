# INFORME — identidad-billete-v1 (IB-v0.1)

**Categoría:** `consenso` (dominante). Secundarias: `seguridad` (doble farmeo y ramas disjuntas) y
`economía` (conjunto pagable y P1). Motivo: el objeto del cálculo es qué partición de billetes induce
cada definición de identidad sobre el DAG, y de ahí cuelgan la unicidad pagable y la validez.

**Qué es:** enumerador pequeño y exacto sobre DAGs de juguete con **GDR-v0.2 sin modificar** como oráculo.
Responde a `P-ZRX/P-IDENTIDAD/PROMPT.md`. El informe con las conclusiones F1–F6 y la respuesta está en
`../../INFORME.md` (primera línea = la respuesta); el inventario, en `../../INVENTARIO.md`; las
bifurcaciones, en `../../DECISIONES-PENDIENTES.md`; los supuestos y su sensibilidad, en
`HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md`.

## Presupuesto declarado (LINEO §5.7 / §8.11)

Esta auditoría puede usar como máximo **4 hilos**, **8 GiB de RAM** y **1 GiB de disco temporal**. Si se
agota, checkpoint y estado **inconcluso**. Consumo real de la corrida publicada: **8,8 s de pared,
421 MiB de RSS máximo**. No se agotó ningún recurso. El encargo fija 4 hilos (muy por debajo del tope de
24 de la máquina de referencia).

## Comando exacto

```bash
cd P-ZRX/P-IDENTIDAD/investigacion/veritas/consenso/identidad-billete-v1
export JULIA_DEPOT_PATH="$PWD/../../../../.julia-depot:$HOME/.julia"
export JULIA_NUM_THREADS=4 OPENBLAS_NUM_THREADS=1
../../../../../../veritas/julia.sh --project=. --threads=4,0 run.jl --seed 0x5a5a --replicas 400 todo
```

Julia 1.13.0, `Project.toml` + `Manifest.toml` versionados en este directorio. Dependencia de oráculo:
`GhostdagRank` (GDR-v0.2) por ruta, sin modificar (`veritas/consenso/ghostdag-rank-v1/`).

## Validación (LINEO §5.1)

`test/runtests.jl`, **259 controles en verde** con `--check-bounds=yes`. Ninguno compara una fórmula
consigo misma:

| Control | Qué compara | Resultado |
|---|---|---|
| C1 | ¿A-igual ⇒ B-igual? sobre **todo** el subuniverso (256 soluciones, pares O(n²)) | 0 violaciones |
| C2 | Cruce A/B con el dominio de `chunk` reducido a 4 bits | 3 pares A-igual/B-distinto y 6 B-igual/A-distinto: el cruce existe |
| C3 | **Oráculo GDR** (`EstadoReferencia`) vs kernel (`EstadoRapido`), 27 casos fixture×modo | idénticos |
| C4 | Capa pagable por cadena vs **tercera vía por conjuntos**, 27 casos | idénticos |
| C5 | Invariante de no-equivocación de `C-FLU-12`, copia a copia | se cumple salvo en el caso discriminante (documentado) |
| — | Coherencia de flujo (`C-FLU-14`) de los 9 fixtures | ∅ incoherencias |
| — | Determinismo (misma entrada dos veces) | idéntico |

**Defecto propio detectado y corregido durante la validación** (queda como comentario y como vector de
regresión): `D1` en `src/rapido.jl` — la lista enlazada de copias nacía con `siguiente[x] = x`, un
autociclo infinito, detectado porque la primera corrida no terminaba y el perfil la mostró dentro de
`_seleccionar_indexado`.

## Rendimiento (LINEO §6)

| Variante | Tiempo mínimo | Asignaciones | Hilos/backend | Resultado frente a la referencia |
|---|---:|---:|---|---|
| Oráculo GDR (`EstadoReferencia`) | 0,848 ms | 31 999 | 1 CPU | fuente de verdad |
| Kernel GDR + capa pagable indexada | 0,500 ms | 12 029 | 1 CPU | idéntico en los 27 casos fixture×modo |
| Kernel GDR + capa pagable por conjuntos | 0,344 ms | 9 434 | 1 CPU | idéntico en los 27 casos fixture×modo |

Caso representativo: DAG determinista de 199 bloques. `@benchmark` con calentamiento previo (LINEO
§5.1). Escalado del Monte Carlo (400 réplicas × 120 bloques, reducción entera determinista):
0,104 s (1 hilo) → 0,071 s (2) → 0,040 s (4); **2,6× a 4 hilos**. Se conserva **4 hilos**, que es el
tope del encargo y la configuración que gana.

**Hilos y backend:** `Threads.nthreads(:default) = 4`, `:interactive = 0`, `OPENBLAS_NUM_THREADS = 1`
(no hay BLAS en el camino caliente). Sin `@fastmath`, sin `@inbounds`, sin `@simd`, sin `Float32`, sin
GPU. `uptime` anotado antes de cada benchmark (ver `resultados/BENCH.txt` y `resultados/ESCALADO.txt`).

## Artefactos

| Fichero | Qué contiene |
|---|---|
| `resultados/RUN.txt` | fixtures, controles, invariante de entropía y Monte Carlo (la corrida publicada) |
| `resultados/TESTS.txt` | salida completa de la suite (259 controles, 0 fallos) |
| `resultados/BENCH.txt` | tabla de rendimiento de arriba |
| `resultados/ESCALADO.txt` | escalado 1/2/4 hilos con reducción idéntica |
| `resultados/RUN.err` | salida de error de la corrida publicada (vacía) |
| `HUELLAS.sha256` | huellas de los 19 artefactos, verificadas |

## Límites declarados de la evidencia

1. **No hay criptografía.** La identidad es una codificación inyectiva de la tupla; no se ejecutan
   firmas, KZG ni `blake3`. Una colisión real **agrupa más**, y esa dirección no está medida.
2. **No hay red.** `Δ` es una ventana de padres, no propagación; no hay ancla, época ni `L_slots`.
3. **No hay economía.** Se cuentan bloques pagables (P1), no monedas.
4. **El caso discriminante se inyecta, no se deriva.** La divergencia de flujo entra como parámetro
   (`equivoca`); su probabilidad real es `no determinada` (`P-EQUIVOCACION` P4/P5).
5. **E3 (un chunk por (pieza, bucket)) se lee del código fijado**, no se verifica sobre un plot real.
   Si E3 fuese falso, el resultado principal cae: véase `HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md` §1.
6. **Una enumeración finita no es una demostración.** Los recuentos son exactos **sobre la rejilla
   declarada**; lo que se generaliza se marca `derivado`.
