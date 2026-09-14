# MODELO — GDR-v0.2

## 1. Bloque

Un bloque `B` es la tupla `(id, padres, slot, sd, SR, ident)`:

- `id::NTuple{32,UInt8}` — 32 bytes, comparación **lexicográfica** (igual que `Ord` derivado sobre
  `[u8;32]` en `kaspa_hashes::Hash`, `crypto/hashes/src/lib.rs:38-46`). Un id textual corto se
  rellena con ceros a la derecha, como `string_to_hash` en
  `testing/integration/src/consensus_integration_tests.rs:343-347`.
- `padres::Vector{Int}` — índices a otros bloques ya conocidos; ∅ para el génesis.
- `slot::UInt64` — orden temporal declarado por el propio bloque.
- `sd::UInt64` (`solution_distance`) — dato de PoAS/PoT, entrada del modelo, no derivado aquí.
- `SR::UInt64` — rango de espacio; determina el peso `w(B) = ⌊2^128/(SR+1)⌋`.
- `ident::UInt64` — identidad de billete comprimida (`0` = sin billete asociado); representa
  `(public_key, sector_index, history_size, chunk, slot)` de R-FIN-11 tras un hash/empaquetado que
  el instrumento no audita (entra ya resuelta).

**Supuesto declarado**: no hay colisión de `id` entre bloques distintos (modelo.jl:8). Bajo ese
supuesto, la comparación por `id` hace **total** cualquier orden que lo use como último criterio.

## 2. Peso y `blue_work`

`w(B) = ⌊2^128 / (SR(B)+1)⌋`, exacto, calculado dos veces por caminos independientes:

- oráculo: `peso_big(sr) = fld(BigInt(2)^128, BigInt(sr)+1)` — sin límite de dominio;
- kernel: `peso(sr)::BW256` — aritmética exacta de 128+128 bits partida en `hi`/`lo`, con el caso
  especial `SR=0 ⇒ w=2^128` representado como la constante `BW256(1,0)`.

`blue_work(B) = blue_work(sp(B)) + Σ_{x ∈ blues(B)} w(x)`, donde `blues(B) = [sp(B)] ++` los
bloques del mergeset que resultan azules, en el orden en que se colorean. El propio `B` **no**
aporta su peso a su propio `blue_work` — solo lo hereda cuando otro bloque lo incluye en su
`blues`. `blue_score(B) = blue_score(sp(B)) + |blues(B)|`.

Tipo `BW256 = (hi::UInt128, lo::UInt128)`, dominio declarado `[0, 2^256−1]`; suma/resta detectan
desbordamiento y lanzan `OverflowError` (ver `DECISIONES-PENDIENTES.md` D-5 sobre la política de
desbordamiento, PENDIENTE en SPEC.md §11).

## 3. Padre seleccionado, mergeset y comparadores

**Regla C (DECIDIDO POR KATANA, 2026-09-14, TAREAS.md §1.3), la que usa `Params()` por defecto
(`SP_ZEROX` + `MERGE_SPEC`):**

- **Orden del mergeset** (para colorear Y para el orden de aplicación, misma clave):
  `(bw, sd, id)` ascendente — `cmp_orden`, sin cambios respecto al antiguo modo `:spec`.
- **Padre seleccionado y punta virtual**: MAYOR `bw`; en empate, el que iría PRIMERO en ese orden
  — MENOR `sd`, luego MENOR `id`. Dirección **mixta** (máximo en `bw`, mínimo en `sd`/`id`),
  implementada aparte (`mejor_sp_zerox`, no una reutilización de `cmp_orden` con `argmax`, porque
  el máximo de una tupla ascendente completa daría MAYOR `sd`/`id` en empate, que es justo el
  error de los modos históricos de abajo).
- **`rank`**: la misma tupla `(bw,sd,id)` ascendente que el mergeset — `cmp_orden`/`es_menor_rank`,
  sin cambios. Ver `PROPUESTA-SPEC.md` §7.2 para las demostraciones de totalidad y compatibilidad
  causal.

**Tres comparadores históricos**, conservados como comparación/regresión (ver
`DECISIONES-PENDIENTES.md` §1 para por qué ninguno era C):

```
cmp_orden(a,b)  = (bw(a), sd(a), id(a)) vs (bw(b), sd(b), id(b))      -- :spec,   todo ascendente
cmp_python(a,b) = (bw(a), −sd(a), id(a)) vs (bw(b), −sd(b), id(b))    -- :python, sd invertida
cmp_kaspa(a,b)  = (bw(a), id(a)) vs (bw(b), id(b))                    -- :kaspa,  sin sd
```

Para `:spec`/`:python`/`:kaspa`, el padre seleccionado es el **máximo** de la misma tupla que
ordena el mergeset (`argmax` sobre `cmp_orden`/`cmp_python`/`cmp_kaspa`) — esa asimetría entre
"máximo" (sp) y "orden ascendente" (mergeset) sobre una única relación reproduce el patrón de
Kaspa real (`SortableBlock::cmp`, usada con `.max()` en `find_selected_parent` y con `sort`
ascendente en `sort_blocks`, `ordering.rs:38-50`/`protocol.rs:99-106`/`mergeset.rs:43-45`): el
mayor hash gana la selección de padre mientras el mergeset se ordena por menor hash primero. La
regla C **no** sigue este patrón para `sd`/`id` — por eso necesita su propio comparador en vez de
reutilizar `argmax(cmp_orden)`.

Desde Corrección 1, el ORÁCULO (`referencia.jl`) implementa estas claves de forma independiente
del kernel (`seleccionar_sp_ref`, `orden_merge_ref`, `virtual_sp_ref`, `orden_aplicacion_ref`),
sin llamar a `cmp_orden`/`cmp_python`/`cmp_kaspa`/`mejor_sp`/`seleccionar_sp`/`orden_aplicacion`
del kernel — así la equivalencia oráculo/kernel puede detectar un error de dirección en vez de
que ambos compartan el mismo posible error (ver `DECISIONES-PENDIENTES.md`, motivación de
Corrección 1, tarea 3.2(c)).

## 4. Coloreo — k-cluster

Un candidato `cand` del mergeset ordenado es **azul** si, comprobado contra el `blueset` heredado
del `sp` más los azules ya aceptados en este mergeset:

1. `|anticone(cand) ∩ blueset_actual| ≤ k`, y
2. para todo `b ∈ blueset_actual ∩ anticone(cand)`: `tam_anticono_azul(b) + 1 ≤ k`.

El oráculo (`referencia.jl`) implementa esta definición directamente sobre el `blueset` completo de
`past(B)`. El kernel (`rapido.jl`) implementa el algoritmo incremental de
`protocol.rs:168-283` (`check_blue_candidate_with_chain_block` + `check_blue_candidate`),
manteniendo `blues_anticone_sizes` por nodo de la cadena en vez de recomputar el anticono contra el
blue set completo. La equivalencia entre ambos caminos no se da por supuesta: es lo que acreditan
los tests de equivalencia oráculo/kernel (`INFORME.md` §3).

Un candidato que falla el k-cluster es `rojo_k`.

## 5. Unicidad de billete — U2 y U3″ dinámica (R-FIN-11)

- **U2** (estructural, invalida el bloque): si `ident(B) ≠ 0` y esa identidad ya aparece en algún
  padre de `B` o en el pasado estricto de algún padre, `B` es inválido. No compara `B` contra sí
  mismo, solo contra `padres(B) ∪ past(padres(B))`.
- **U3″ dinámica** (afecta solo el color, no la validez): un candidato del mergeset con identidad
  `cid ≠ 0` se marca `rojo_U3` —sin pasar por el k-cluster— si `cid` ya es azul en `past(sp(B))`, o
  si `cid` ya fue coloreada azul por un candidato **anterior en el orden del mergeset de este mismo
  bloque**. La segunda condición es la parte "dinámica": depende del orden en que se procesa el
  mergeset, es decir, hereda directamente la dirección de la regla C decidida (D-1/D-6,
  `DECISIONES-PENDIENTES.md`, ya no abiertos).

## 6. Cadena seleccionada, orden de aplicación y color contextual

La cadena seleccionada desde una punta se construye siguiendo `sp` hacia atrás hasta el génesis. El
orden de aplicación de R-FIN-8′(4) recorre esa cadena desde el génesis y, por cada bloque de
cadena `C`, emite `[sp(C)] ++ mergeset_ordenado(C)`, saltando los `rojo_U3`.

El **color** de un bloque no es un atributo fijo del bloque: es el color que recibe en el bloque de
cadena que lo fusiona. El mismo bloque puede ser azul visto desde una punta y `rojo_k` visto desde
otra, si un reorg cambia qué bloque de cadena lo fusiona primero (contraejemplo D7,
`DERIVACIONES.md:148-176`). El dato GHOSTDAG almacenado de un bloque (su propio `sp`, su propio
mergeset) es invariante; lo contextual es el papel que juega al ser fusionado por otra cadena.

## 7. `rank` (regla C decidida; redacción normativa aún PROPUESTA — ver `PROPUESTA-SPEC.md` §7.2)

`rank(B) := (blue_work(B), solution_distance(B), id(B))`, orden lexicográfico total bajo el
supuesto de no colisión de `id` (§1). `es_menor_rank(a,b) = cmp_orden(a,b) < 0` — la dirección ya
no es una entre tres opciones (D-1 está decidido): es la que fija la regla C. Ver
`PROPUESTA-SPEC.md` §7.2 para las demostraciones escritas de totalidad ((i), por producto de
órdenes totales) y compatibilidad causal ((ii), `blue_work` estrictamente creciente bajo `sp`, más
transitividad), y su verificación exhaustiva/muestreada.
