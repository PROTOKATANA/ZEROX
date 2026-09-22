# Qué conclusiones codifican los parámetros y los supuestos del enumerador

Este fichero existe para que un lector hostil pueda **romper** la conclusión cambiando un
supuesto, en vez de discutirla en prosa. Cada fila: supuesto → qué conclusión sostiene → qué
pasaría si fuese falso.

## 1 · Estructura del PoAS (la parte que decide)

| # | Supuesto | Fuente | Conclusión que sostiene | Si fuese falso |
|---|---|---|---|---|
| **E1** | El reto de un slot depende solo de `(flujo, slot)`: `reto(f,s)` | `SPEC.md` §7.1.1 `C-POT-03`; Autonomys `global_challenge = Blake3(Blake3(pot_output) ‖ LE(slot))` (`subspace-verification/src/lib.rs:120-159`) | Dos bloques de la **misma historia** y el mismo slot comparten reto | Habría dos retos por slot dentro de una historia y el `chunk` volvería a ser un grado de libertad real con A |
| **E2** | `s_bucket = primeros 2 bytes de (sector_id XOR global_challenge)` ⇒ **un bucket por (pk, sector, historia, slot, flujo)** | `subspace-core-primitives/src/sectors.rs:33-39` | El bucket **no depende de la pieza** | Si el bucket dependiera de la pieza, dos piezas podrían compartir chunk y A/B se cruzarían sin colisión |
| **E3** | En un bucket, cada pieza aporta **a lo sumo un chunk** (`record_has_s_bucket_chunk -> Option<bool>`, un bit por (pieza,bucket)) | `subspace-farmer-components/src/sector.rs:582-608`, `:521-552`; `auditing.rs:236-271`; `proving.rs:397-410` | **Dentro de un reto, `piece_offset` y `chunk` se determinan mutuamente** (salvo colisión de valor) ⇒ A y B particionan igual *dentro de una historia* | Dos chunks por (pieza, bucket) harían que A fuese estrictamente más fina que B **dentro** de una historia, y todo F2/F3 cambiaría |
| **E4** | El chunk es un escalar de 32 bytes (`ScalarBytes::FULL_BYTES = 32`) | `subspace-core-primitives/src/lib.rs:255-258`; `solutions.rs:250-275` | La colisión «mismo chunk, distinta pieza» es ~2⁻²⁴⁸ ⇒ **A refina a B** | Con chunks de pocos bits, A y B **se cruzarían** y ninguna refinaría a la otra |
| **E5** | La condición de victoria es `is_within_solution_range(global_challenge, chunk, sector_slot_challenge, rango)` | `subspace-verification/src/lib.rs:150-159`, `:239-272` | El juguete modela «gana» como predicado determinista de `(chunk, slot, flujo)` con probabilidad `q` | Si la condición dependiera de la pieza por otra vía, la multiplicidad de ganadores cambiaría de forma |
| **E6** | Un productor reclama **un solo bloque por slot**; las demás soluciones ganadoras se saltan | `sc-consensus-subspace/src/slot_worker.rs:571-592` | La multiplicidad de ganadoras **no** se traduce en varios bloques del mismo productor en un slot | Si ZEROX permite varios bloques por productor y slot, el coste de B en pago (F3) crecería |
| **E7** | Dentro de una historia el flujo de un slot es único (`C-FLU-14` + monotonía de `C-FLU-05`) | `SPEC.md` §7.1.1/§7.1.5 | Dos bloques de la misma historia con el mismo slot **no pueden** tener retos distintos ⇒ no existe el par «misma pieza, `chunk` distinto» dentro de una historia | Sin E7 el caso discriminante aparecería dentro de una historia y U2/U3 sí cambiarían |

**E3 + E7 son la conclusión entera.** Si cualquiera de los dos cae, el resultado principal cae.

## 2 · Supuestos del juguete (declarados en `src/modelo.jl`)

| # | Supuesto | Qué sostiene | Sensibilidad medida |
|---|---|---|---|
| **H1** | Tabla de chunks inyectiva (sin colisiones de valor) | A refina a B; el control C1 da 0 violaciones sobre 256 soluciones | `control_cruce(colision_bits=4)` fuerza colisiones y encuentra 3 pares A-igual/B-distinto: **el cruce existe y es el único modo de que A no refine a B** |
| **H2** | `bucket` función de `(slot, flujo)`, no de la pieza | El caso discriminante exige flujos divergentes | Si el bucket dependiera de la pieza, se rompería E2 |
| **H3** | `PlotBatchId` compromete `(pk, historia)` ⇒ **C ≡ B** en el juguete | Las filas de C son idénticas a las de B | Si el lote **no** determinara `history_size`, C sería estrictamente más gruesa que B (decisión abierta para Katana) |
| **H4** | `pot_output` = f(slot, flujo) | Aísla el efecto de `chunk` en la entropía | — |
| **H5** | SHA3-256 en lugar de `blake3` en `entropia` | Solo se usa la **igualdad** de entradas | Ninguna: lo que se prueba es igualdad o desigualdad de `(chunk, pot_output)` |
| **H6** | `q` y `P` (ganadoras por pieza, piezas por sector) son parámetros libres; μ = P·q | Todas las tasas se dan como función de (P, q) | Las tablas MC-A/MC-B cubren P ∈ {1,4,16,32,1000}; μ = 1 es el caso calibrado por `pieces_to_solution_range` |

## 3 · Los parámetros de la rejilla MC y por qué esos

- `P = pieces_in_sector`: el código fija `MAX_PIECES_IN_SECTOR = 1000` en mainnet
  (`subspace-runtime/src/lib.rs:124-125`) y **32** en el runtime de test. El rango útil es
  1…1000. La rejilla usa 1 (el extremo de `EQUIV-v0.1` «misma-parcela»), 4, 16, 32 y 1000.
- `q`: probabilidad de que una pieza gane en su bucket. `μ = P·q = 1` es el régimen que
  impone `pieces_to_solution_range` (`solutions.rs:26-40`). Con P=1000, q = 0,001.
- `λ`, `Δ`, `k`: λ ∈ {1, 2} bloques/slot (λ_obj = 1 nominal, `SPEC.md` §7.3), Δ ∈ {1, 4} slots
  (símbolo sin valor decidido), `k = 30` (`C-GD-06`) con control a `k = 10`.
- `equivoca`: fracción de oportunidades en que un productor con **dos nodos de vistas
  divergentes** emite una segunda copia en el mismo slot bajo otro flujo. Es el único camino
  por el que un productor honesto puede violar su propia identidad.

## 4 · Lo que el enumerador NO codifica

- No hay criptografía: ni firmas, ni KZG, ni `blake3`. La identidad se modela como una
  codificación **inyectiva** de la tupla (supuesto H1).
- No hay retardo de red real: `Δ` se modela como ventana de padres, no como propagación.
- No hay ancla, ni época, ni `L_slots`: la divergencia de flujo se introduce como parámetro
  (`equivoca`), no se deriva de `C-FLU-10`.
- No hay emisión ni retarget: se cuentan **bloques pagables** (P1), no monedas.
- No se modela el coste de grindear pruebas alternativas para el mismo `(pieza, bucket,
  chunk)` (`IDENTIDAD.md` §4): esa vía no crea billetes nuevos bajo ninguna de las tres
  identidades.
