# MODELO — PPP-v0.1

## 1. Proceso de solución PoAS (entrada del modelo)

Fuente: `subspace @ f8842d0`, verificado en
`PDF/autonomys-subspace/crates/subspace-verification/src/lib.rs:120-158` y
`crates/subspace-farmer-components/src/auditing.rs:236-270`.

```
global_challenge      = derive_global_challenge(slot)
sector_slot_challenge = sector_id.derive_sector_slot_challenge(global_challenge)
s_bucket              = sector_slot_challenge.s_bucket_audit_index()
audit_chunk(k)        = blake3_keyed(sector_slot_challenge, chunk_k)
solution_distance(k)  = bidirectional_distance(global_challenge, audit_chunk(k))
válida(k)             ⇔ solution_distance(k) ≤ SR / 2
```

`bidirectional_distance` (`subspace-core-primitives/src/solutions.rs:332-337`) es la distancia
circular sobre `u64`. Con `global_challenge` fijo y `chunk_k` uniforme, cada
`solution_distance(k)` es uniforme en `{0,…,2^63−1}`. `map_winning_chunks` recorre **todos** los
chunks del s-bucket auditado y los ordena; el bloque usa el de menor distancia. Por tanto la
distancia de un bloque es `D = min(d_1,…,d_C)`, mínimo de `C` sorteos iid, con `C` = chunks del
s-bucket (parámetro). `Rust` divide enteros: el umbral es `SR >> L`.

**No entran en el modelo**: el contenido del bloque, los padres, la firma, el PoT, la red y el
estado. La solución se produce **antes** de elegir padres (ventana de autoría `Δ`), y eso es una
propiedad del diseño actual (§7.2, C-HDR-05/R-FIN-1a), no un supuesto del instrumento.

## 2. Definición de nivel

**Nivel `L` (L ≥ 1): `D ≤ SR ÷ 2^L`.** Nivel 1 = solución válida. La hipótesis del encargo es

```
P(nivel ≥ L | válida) = 2^{−(L−1)}.
```

El instrumento **no la adopta**: la deriva exacta y la mide. La probabilidad exacta con `C`
sorteos es (M = 2^63 valores)

```
F(x) = P(min ≤ x) = 1 − ((M−1−x)/M)^C
P(nivel ≥ L | válida) = F(SR ÷ 2^L) / F(SR ÷ 2),
```

y la hipótesis es el límite `SR/M → 0`. La corrección es `O(2^L/SR + C·SR/M)`; se cuantifica en
`resultados/run-multiples.txt`. Nótese que la razón es **escala-invariante**: multiplicar `SR` por
una constante no la cambia (con umbral = `SR` del bloque). El número de niveles *resolubles* es
`≈ log₂(SR) − log₂(M)` en la práctica: por debajo de `2^L ≳ SR` el umbral se satura en 0 y el
nivel degenera (se documenta, no se oculta).

## 3. Anclaje de `SR` (punto 1 del §3)

`SR` no es constante: lo mueve el controlador R-FIN-13′. Tres anclas y su efecto:

| ancla del umbral | `P(nivel ≥ L | válida)` | problema |
|---|---|---|
| `SR` del bloque (contextual, C-HDR-06) | `F(SR÷2^L)/F(SR÷2)` | escala-invariante, pero el `SR` es **endógeno**: lo fija el pasado de la propia rama |
| `SR₀` de referencia (constante) | `F(SR₀÷2^L)/F(SR÷2)` | estable entre bloques, pero escala `≈ SR₀/SR` y **manipulable por la razón** |
| `SR` de ventana | intermedio | sigue siendo endógeno a la rama |

`factor_anclaje` entrega la segunda fila; `resultados/run-sranclaje.txt` muestra que la tasa de
nivel escala `≈ SR₀/SR`. **Ninguna ancla es a la vez estable y no manipulable.**

## 4. Adversario

Adversario de recursos: fracción `α` del espacio total, sin límite de cómputo ni de almacenamiento
auxiliar, adaptativo, que **puede**:

1. **Retener** cualquier bloque/billete y publicarlo cuando quiera (punto 4).
2. **Construir ramas privadas** y elegir la ancestría de cada bloque con `slot(padre) ≤ slot`
   (punto 5). Puede además elegir cuál de varios chunks ganadores usar (multiplicidad, punto 3).
3. **Influir en `SR`** a través del pasado que presenta (puntos 1–2).
4. Declarar cualquier `blue_work` en una cabecera (ATAQUE 8).

No se le conceden: romper blake3, la firma Ed25519, ni el orden secuencial del PoT. El análisis
del PoT (flujos, inyección, VDF rápido) está fuera: vive en `research/dag-poas-auditoria.md`
(ATAQUE 1–2) y no se repite.

## 5. Piezas del certificado (objeto bajo auditoría)

Un **certificado de niveles** es una lista de bloques con `(slot, nivel)` —lo máximo que un
tercero puede comprobar sin el DAG y sin recomputar `blue_work`—. El verificador
`verifica_certificado_niveles` exige slots no decrecientes, niveles ≥ 1 y una cuota de bloques de
nivel ≥ `Lreq` en cada ventana de `ventana` slots. Se implementa el verificador **más fuerte
posible** que sólo mira niveles; no se debilita para que el ataque pase.

## 6. Objeto de comparación: el nivel de PoW

En Kaspa (`research/dag-poas-auditoria.md` §0.2 y ATAQUE 7; `rusty-kaspa @ c338d495`) el nivel es
`calc_level_from_pow(hash)` = ceros iniciales del hash; el hash **incluye los padres**, y
`parents_by_level`, `level_work` y `pruning_proof/` cuelgan de él. Sus tres propiedades:

- **(P1) medible sin el resto**: sí, del hash;
- **(P2) ligado al recurso**: 2^L hashes esperados, atados a la ancestría por el propio hash;
- **(P3) ligado a la ancestría**: sí, porque el hash compromete los padres.

El instrumento compara cualquier candidato PoST contra (P1)+(P2)+(P3).

## 7. Supuestos declarados

1. `solution_distance` uniforme e independiente entre chunks y slots (se sigue del código; el
   instrumento no lo re-deriva criptográficamente).
2. Identidad de billete con unicidad suficiente para que dos bloques del mismo billete no cuenten
   dos veces **dentro de una misma historia** (R-FIN-11, C-GD-07). El instrumento **no** audita
   U2/U3″; los toma del SPEC.
3. `SR` es una función del pasado de la rama (C-HDR-06); el controlador exacto queda como
   parámetro `ρ = SR_branch/SR_ref`.
4. El PoT es un reloj global único dentro de una época (supuesto del que dependen A2/A3 de la
   auditoría previa; **no** lo garantiza el diseño DAG, según ATAQUE 1–2).
