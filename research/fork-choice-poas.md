# Fork choice bajo PoAS — por qué NO se copia la fórmula de Autonomys

**Fecha:** 2026-09-05 · Cierra **P-006** · `subspace @ f8842d0`

## El hallazgo

```rust
// crates/subspace-verification/src/lib.rs:195-206
pub fn calculate_block_fork_weight(solution_range: SolutionRange) -> BlockForkWeight {
    BlockForkWeight::from(SolutionRange::MAX - solution_range)
}
```
```rust
// crates/subspace-core-primitives/src/lib.rs:124-127
/// The narrower the solution range, the heavier the block is.
pub type BlockForkWeight = u128;
```

El comentario dice que un rango más estrecho pesa más. **Es cierto y es irrelevante**, porque
`SR ≪ u64::MAX` siempre. Calculado con su propia `pieces_to_solution_range`
(`solutions.rs:30-40`, `SLOT_PROBABILITY = (1,6)`, `NUM_CHUNKS = 2^15`, `NUM_S_BUCKETS = 2^16`):

| Red | `solution_range` | `SR / u64::MAX` |
|---|---:|---:|
| 1 sector (1 000 piezas) | 6 148 914 691 236 495 | **3,33 × 10⁻⁴** |
| 1 TiB | 5 864 062 014 805 | 3,18 × 10⁻⁷ |
| 1 PiB | 5 726 623 061 | **3,10 × 10⁻¹⁰** |

**El peso por bloque se aparta de una constante en un 0,033 % en el peor caso, y en ~0 % en
cualquier red real.** Su fork choice es, materialmente, **cadena más larga**.

Ellos lo escriben casi con esas palabras (`block_import.rs:705-710`):

> *"This almost always prioritises: - the longest chain (the largest number of solutions), and if
> there is a tie - the strictest solutions"*

Y el desempate está muerto: para que la diferencia de rangos acumulada sobre una era entera
(`ERA_DURATION_IN_BLOCKS = 2016`) supere el peso de **un bloque de más**, haría falta
`ΔSR > u64::MAX/2016 = 9,15 × 10¹⁵`. A 1 PiB el propio `SR` vale 5,7 × 10⁹.

## Por qué eso es un problema para ZEROX y no tanto para ellos

El reajuste de rango es **por rama**: cada rama calcula su `SR` de su propio ritmo de era. Una rama
privada con fracción `f` del espacio produce bloques `1/f` veces más lento, su era mide más slots,
y su `SR` sube hasta que **produce bloques al mismo ritmo que la honesta**. Con el clamp de 4× por
era, para `f = 0,1` son ~2 eras.

A partir de ahí, con peso ≈ constante, **la rama minoritaria acumula peso al mismo ritmo que la
mayoritaria**. El déficit deja de crecer y pasa a ser un paseo aleatorio sin deriva — recurrente, o
sea que alcanza con probabilidad 1 si se le da tiempo. Es exactamente la razón por la que Bitcoin
cuenta trabajo y no bloques.

**Autonomys no está roto por esto porque lo tapa por otro lado:** `verifier.rs:423-437` rechaza
bloques por debajo de `best_number − confirmation_depth_k`, con `K = 100`. Su fork choice descansa
sobre su límite de reorg, no al revés.

## La fórmula que sí mide espacio

```
peso_bloque(h) := floor( 2^128 / (rango_solucion(h) + 1) )
```

Con ella la tasa de acumulación se vuelve **invariante al reajuste**:

```
bloques_por_slot × peso_por_bloque = (espacio · SR / C) × (2^128 / SR) = espacio · 2^128 / C
```

**El `SR` se cancela.** El peso crece proporcional al espacio, y la rama con `f` del espacio acumula
a `f` del ritmo honesto: deriva negativa permanente, Nakamoto clásico. Verificado numéricamente: la
fórmula propuesta varía **1 073 742×** entre 1 sector y 1 PiB donde la suya varía 0,033 %.

El `2^128` no es arbitrario: la magnitud física es `2^64 / SR` (auditorías esperadas por solución,
porque `solution_distance` vive en el espacio `u64` y el umbral es `SR/2`,
`subspace-verification/src/lib.rs:150-158, 255-259`). El `2^64` extra es resolución de coma fija.
Es la misma identidad que nuestro `C-FORK-01` de PoW con `2^256 → 2^128`.

⚠️ **El acumulador MUST ser `U256`.** Con `SR = 1`, `peso_bloque ≤ 2^127`: en `u128` desborda **al
segundo bloque**. `TrabajoAcumulado(U256)` y su `sumar()` de `zx-core/src/target.rs:270-293`
sobreviven sin tocar una línea; solo cambia el nombre y quién produce el sumando.

## El desempate por menor hash se INVIERTE bajo PoAS

Bajo PoW, `P-015` preguntó si un minero molería el nonce buscando un hash bajo para ganar
desempates, y se concluyó «dominado»: cada intento costaba un PoW completo.

Bajo PoAS **el coste desaparece**. En Autonomys el sello es una firma Schnorr sobre el pre-hash
(`verifier.rs:338-348`) y el hash del bloque es el **post-hash**, que incluye el sello
(`block_import.rs:604`). Schnorrkel firma con nonce aleatorio ⟹ **el granjero genera hashes de
bloque distintos para contenido idéntico con solo volver a firmar.** Decenas de miles de intentos
por segundo y núcleo, dentro del slot.

Y los empates de peso son **el caso común**: dos ramas de igual longitud dentro de la misma era
tienen peso exactamente igual.

Resultado: el desempate por hash regalaría **todas las carreras de huérfanos al granjero con más
CPU**, en un consenso elegido precisamente para que la CPU no decida. Y amplifica el *selfish
mining*: el que muele puede retener sabiendo que gana el empate.

**Propuesta:** desempatar primero por **menor `solution_distance`** —se recomputa de la cabecera, es
determinista y **no es molible**: bajarla exige más espacio, que es justo lo que queremos premiar— y
solo después por hash, para garantizar orden total.

⚠️ Esto depende de **nuestro** diseño de cabecera, que está sin decidir. Si la firma acaba dentro de
la parte hasheada, el ataque aplica. Es una restricción sobre el rediseño de `BlockHeader`.

## `MAX_REORG_LENGTH` gana una segunda cota que nadie había escrito

En Autonomys, `confirmation_depth_k = 100` hace **dos** trabajos con una constante:

- límite de reorg (`verifier.rs:423-437`);
- profundidad a la que el archivador archiva (`sc-consensus-subspace/src/archiver.rs:601-603`).

**No es casualidad. Un reorg más profundo que el archivado reescribe historia ya archivada**, y esa
historia es lo que los granjeros tienen ploteado: cambiarla invalida plots de toda la red. Con los
costes medidos (`coste-ploteo-medido.md`), replotear 1 TiB son ~293 bloques con 32 núcleos.

```
MAX_REORG_LENGTH MUST cumplir a la vez:
  (i)  < COINBASE_MATURITY        [finalidad del coinbase — ya existente]
  (ii) <= PROFUNDIDAD_ARCHIVADO   [ningún reorg admisible reescribe historia ploteada]
```

Con `B_RELLENO = 0` (§17) la historia no crece, así que **(ii) está dormida hoy** y despierta con el
tráfico. Escribirla ahora cuesta una línea; descubrirla después cuesta un split.

**El número 99 no se mueve.** Como cota probabilística sigue siendo `(q/p)^99` — el cambio de
consenso no toca esa aritmética. Subirlo rompe (i); bajarlo hace que la parada dura dispare más a
menudo. Lo que hay que cambiar no es el número: es que su fallo sea `exit(0)` (§16).

## No-determinismos de su implementación que ZEROX NO debe heredar

1. **`load_block_weight(...).unwrap_or_default()`** (`block_import.rs:657, 739`) — un nodo sin el
   peso del padre lo trata como **cero**. Con nuestra parada dura eso es letal: un peso 0 espurio
   da una profundidad de reorg arbitraria y **apaga el nodo**. El peso MUST recomputarse desde las
   cabeceras, nunca defaultearse.
2. **`total_weight > last_best_weight`** (`:741`), `>` estricto: el empate lo gana el que llegó
   primero. Es el no-determinismo de Bitcoin que `P-012` ya rechazó.
3. **`#[cfg(feature = "testing")]` dentro de `calculate_block_fork_weight`**
   (`subspace-verification/src/lib.rs:197-203`): **una feature de Cargo cambia la fórmula de
   consenso.** Verificado literal. Prohibido en ZEROX sin excepción.
4. `saturating_mul` + `unwrap_or(u64::MAX)` en el reajuste (`:475-482`): saturación silenciosa
   dentro de una función de consenso. C-ENC-03 exige aritmética comprobada.

## Lo que sobrevive de `fork_choice.rs` (385 líneas)

| Elemento | Veredicto |
|---|---|
| `Preferencia`, `profundidad_reorg`, `ClaveVentana` | **Tal cual.** `ClaveVentana` pasa a importar *más*: bajo PoAS cachea también la era del reajuste, el `history_size` y las consultas de caducidad |
| `preferir()` | Estructura intacta; cambia la magnitud comparada |
| `Tip` | `trabajo` → `peso`; probablemente hay que añadir `distancia: u64` para el desempate |
| `comprobar_profundidad_reorg`, `MAX_REORG_LENGTH` | Sobrevive el valor; cambia su derivación |
| `TrabajoAcumulado(U256)` + `sumar()` | **Sobrevive sin tocar una línea** |
| `trabajo_acumulado(&[U256])`, `trabajo_bloque()` | Mueren; se sustituyen por su equivalente sobre rangos |

## Lagunas

- **Ningún parámetro de reajuste está decidido para ZEROX**: era, clamp, probabilidad de slot,
  rango inicial, profundidad de archivado. Los de Autonomys (2016 / 4× / 1:6 / 100) están
  calibrados para bloques de 6 s y una red de exabytes. **No se toman.** → pregunta nueva.
- El ataque de la rama privada está **cuantificado pero no simulado**. Pendiente D8.
- La invariancia de la tasa de peso bajo el reajuste es razonamiento, no demostración. Pendiente D9.
- No se ha medido el coste de `verify_solution` por bloque. Son **cinco** comprobaciones, dos de
  ellas KZG, donde PoW tenía **una**. `C-NET-03`/`C-NET-04` siguen sin recalibrar.
