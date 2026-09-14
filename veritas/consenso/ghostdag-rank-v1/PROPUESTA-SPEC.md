# PROPUESTA-SPEC — GDR-v0.2

**Esto es una PROPUESTA. No se ha editado `SPEC.md`. Ningún texto de aquí es normativo hasta que
Katana lo traslade formalmente.** La regla C que sustenta la definición de `rank` de esta sección
YA está decidida (TAREAS.md §1.3, 2026-09-14) — lo que sigue pendiente es solo la redacción
normativa en `SPEC.md` §7.2 y §11 (D-4 y D-5 de `DECISIONES-PENDIENTES.md`). Cada afirmación
distingue DEMOSTRADO (prueba matemática) de COMPROBADO (verificación exhaustiva/muestreada) y de
NO DEMOSTRADO (queda explícito).

## Propuesta para §7.2 — definición de `rank`

Texto que reemplazaría el PENDIENTE de SPEC.md:1285-1291:

> **`rank`, definición operativa (regla C, TAREAS.md §1.3).** Dado un bloque `B` con
> `blue_work(B)` ya calculado por GHOSTDAG, `solution_distance(B)` de su prueba PoAS/PoT, y
> `id(B)` de 32 bytes:
>
> `rank(B) := (blue_work(B), solution_distance(B), id(B))`, orden lexicográfico ascendente
> (`blue_work` asc., luego `solution_distance` asc., luego `id` asc. por bytes); gana el menor.

### (i) Totalidad — DEMOSTRADO

`blue_work(B)` es un entero (`blue_work` es un orden total sobre enteros); `solution_distance(B)`
es un entero (u64, orden total); `id(B)` es una secuencia de 32 bytes con orden lexicográfico
(orden total sobre `{0,...,255}^32`). El producto lexicográfico de un número finito de órdenes
totales es un orden total (propiedad estándar de órdenes producto: dados `(a,b) ≠ (a',b')`, o bien
`a≠a'` y el primer componente decide, o `a=a'` y entonces `b≠b'` decide el segundo). Con el
supuesto declarado de que no hay colisión de hash (`src/modelo.jl:8`), dos bloques `A≠B`
distintos tienen `id(A)≠id(B)`, así que sus tuplas `rank` son distintas — el tercer componente
decide si los dos primeros empatan. **No hace falta muestreo para esta parte**: es una
consecuencia directa de que cada componente es un orden total y de la no-colisión de `id`. Q.E.D.

La verificación exhaustiva sobre 10 105 DAGs con n≤6, y sobre todos los pares de bloques (no solo
padre-hijo, `test/runtests.jl`, Corrección 1), es una comprobación adicional de que la
*implementación* de `es_menor_rank`/`cmp_orden` respeta esta propiedad — no sustituye la prueba de
arriba, que es sobre la *definición*, independiente del código.

### (ii) Compatibilidad causal — DEMOSTRADO (con una premisa citada, no reprobada aquí)

**Afirmación**: si `A` es padre de `B`, entonces `rank(A) < rank(B)`.

**Premisas**:
1. `sp(B)` maximiza `blue_work` entre los padres de `B` — es el primer componente de la regla C
   (§0 de `DECISIONES-PENDIENTES.md`): `bw(A) ≤ bw(sp(B))` para todo padre `A` de `B`.
2. `sp(B) ∈ blues(B)` siempre (`protocol.rs:138`; implementado idénticamente en
   `referencia.jl`/`rapido.jl`; comprobado como invariante explícito en el testset «rank:
   totalidad y causalidad», Corrección 1, sobre las 10 105 DAGs exhaustivas y sobre los DAGs
   aleatorios medianos).
3. `w(x) ≥ 2^64 > 0` para todo `SR` de tipo `u64` (el mínimo se alcanza en `SR=2^64−1`, dando
   `w=2^64`; ver `MODELO.md` §2).

**Demostración**: `blue_work(B) = blue_work(sp(B)) + Σ_{x∈blues(B)} w(x)`. Por la premisa 2,
`sp(B)` es uno de los términos de esa suma, así que
`blue_work(B) ≥ blue_work(sp(B)) + w(sp(B))`. Por la premisa 3, `w(sp(B)) > 0`, luego
`blue_work(B) > blue_work(sp(B))`. Dos casos para un padre `A` de `B`:

- **Caso `A = sp(B)`**: `blue_work(B) > blue_work(sp(B)) = blue_work(A)` directamente. El primer
  componente de `rank` ya decide: `rank(A) < rank(B)`, sin necesitar `solution_distance` ni `id`.
- **Caso `A ≠ sp(B)`** (un padre no seleccionado): por la premisa 1, `bw(A) ≤ bw(sp(B))`. Junto con
  `blue_work(B) > blue_work(sp(B)) ≥ bw(A)`, se sigue `blue_work(B) > blue_work(A)`, y de nuevo el
  primer componente decide `rank(A) < rank(B)`.

En ambos casos el argumento se cierra con SOLO el primer componente de `rank` — nunca hace falta
invocar la ancestría general de `A` respecto de `sp(B)` (a diferencia de un padre no seleccionado
que fuese ANCESTRO de `B` por otra vía: aquí basta con que sea padre DIRECTO, y el caso 1 de la
regla C —`sp` maximiza `bw` entre los padres— ya cubre la comparación). Q.E.D.

**Nota**: `rank` es una función GLOBAL de `B` — depende solo de `past(B)` (a través de
`blue_work`, `solution_distance` e `id`, todos ellos datos intrínsecos de `B` y su pasado) — nunca
de la cadena seleccionada ni del observador. El COLOR, en cambio, es contextual: depende de qué
bloque de cadena fusiona a `B` (`MODELO.md` §6, contraejemplo D7′). `rank` y color son propiedades
de naturaleza distinta, aunque P1 las combine.

**Estado de la prueba**: DEMOSTRADO para el caso general (arriba), COMPROBADO además como
invariante por separado (premisa 2, `sp(B)∈blues(B)`) y como propiedad completa
(`es_menor_rank(p,i)` para todo padre `p` de todo bloque `i`) sobre las 10 105 DAGs exhaustivas de
n≤6 y sobre DAGs aleatorios de n∈[120,200) (`test/runtests.jl`).

### (iii) P1 = (color, rank, id): ¿es redundante el id final? — DEMOSTRADO que lo es, bajo esta definición de rank

Por (i), `rank` ya es total y ya termina en `id`. Por tanto, dados dos bloques distintos
cualesquiera `A≠B` con el mismo color, `rank(A)≠rank(B)` (i), así que la clave `(color(A),
rank(A))` y `(color(B), rank(B))` nunca empatan — el `id` que P1 añade al final
(`(color, rank, id)`) nunca puede desempatar nada que `(color, rank)` no haya desempatado ya,
porque `rank` mismo ya incluye `id` como su propio último componente. **Es redundante por
definición**, no solo por evidencia empírica.

**Punto para Katana** (`DECISIONES-PENDIENTES.md`, sección 3): esto no dice si conviene QUITAR el
`id` final de la redacción de P1 en el SPEC. Argumento a favor de quitarlo: más corto, sin
duplicar información. Argumento para conservarlo marcado como redundante: si el día de mañana
`rank` se redefiniera SIN terminar en `id` (por ejemplo, si se cambiara la definición de `rank`
sin pasar por esta demostración), P1 dejaría de ser total silenciosamente — mantener el `id`
explícito en P1 es una red de seguridad textual barata. Comprobado también empíricamente
(testset «P1: desempate por id redundante», 100 DAGs aleatorios n∈[60,120)) como verificación
adicional de que la propiedad se cumple en la implementación, no solo en la definición.

## Propuesta para §11 — dominio y cota de `blue_work`

Texto que completaría el PENDIENTE de SPEC.md:1548-1551:

> **Dominio.** `blue_work` se representa en un entero sin signo de 256 bits.
>
> **Cota — DEMOSTRADO.** Para todo bloque `B` de un DAG con `n` bloques,
> `blue_work(B) < n · 2^128`.
>
> *Demostración*: desplegando la recurrencia `blue_work(B) = blue_work(sp(B)) + Σ_{x∈blues(B)} w(x)`
> a lo largo de la cadena seleccionada, `blue_work(B) = Σ_{x ∈ Azul(B)} w(x)`, donde `Azul(B)` es
> el conjunto azul ACUMULADO de `past(B)`: la unión de los `blues(C)` de los bloques `C` de la
> cadena hasta `B`, sin incluir a `B`. No es el `blues(B)` de un solo bloque. Cada bloque entra en
> esa unión una sola vez, porque se fusiona en un único bloque de cadena, así que no hay doble
> conteo y `Azul(B) ⊆ past(B)`. Por tanto
> `blue_work(B) ≤ |past(B)| · max_x w(x) ≤ (n−1) · 2^128 < n · 2^128`, porque
> `max_x w(x) = w(SR=0) = 2^128` (`MODELO.md` §2) y `|past(B)| ≤ n−1`. No aparece ningún factor
> `(k+1)`: ese factor formaba parte de una cota anterior de este mismo instrumento
> (`run.jl`, antes de Corrección 1) que resultó ser más floja de lo necesario sin ninguna
> justificación — `(k+1)` no aparece en ningún paso de esta suma, porque el límite de azules por
> mergeset (`k+1`, R-FIN-6) acota cuántos bloques se AÑADEN a `blues` en un solo paso, no cuántos
> hay en TOTAL acumulados en `past(B)`, que es lo que `blue_work` realmente suma.
>
> Para `n=10^9`: `n·2^128 < 2^30·2^128 = 2^158`, es decir, **158 bits**, no 163 (la cifra publicada
> hasta Corrección 1, con el factor `(k+1)` de más). El dominio de 256 bits deja más de 90 bits de
> margen sobre esta cota para `n=10^9`.
>
> **Política de desbordamiento — PROPUESTA, decisión de Katana (D-5).** Un desbordamiento de
> `blue_work` en el dominio de 256 bits se trataría como **fallo de consenso explícito**
> (rechazar/detener), nunca como envoltura silenciosa ni truncamiento. El instrumento lo implementa
> así (`BW256`, `OverflowError`), porque LINEO prohíbe el desbordamiento silencioso en sus
> auditorías. Esa prohibición rige el instrumento, no el SPEC: la regla del protocolo sigue abierta.
>
> **NO DEMOSTRADO — pendiente**: la cota de arriba es sobre `n` (número de bloques), no sobre
> tiempo/tasa de emisión. Falta un análisis que traduzca un horizonte temporal y una tasa de
> bloques máxima admitida por el protocolo a un `n` máximo, y de ahí a un margen de seguridad frente
> a un adversario con recursos acotados — este instrumento no lo intentó.

## Lo que esta propuesta NO resuelve

- El dominio numérico exacto de producción y el horizonte temporal que traduce a un `n` máximo
  (D-5) — la cota de arriba es necesaria pero no decide el dominio final.
- Si P1 conserva o quita el desempate final por `id` en su redacción textual (arriba, (iii)) —
  decisión de estilo/robustez de Katana, no una cuestión matemática abierta.
