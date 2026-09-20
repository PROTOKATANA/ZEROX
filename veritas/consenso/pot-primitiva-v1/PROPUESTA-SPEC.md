# PROPUESTA-SPEC — P-POT: el PoT como primitiva y el contrato del verificador

**Esto es una PROPUESTA. No se ha editado `SPEC.md`. Ningún texto de aquí es normativo hasta que
Katana lo traslade formalmente.** Redactada el 2026-09-19 por el agente DeepSeek del encargo
`P-POT/ENCARGO.md` (solo lectura). Forma: plantilla de
`veritas/consenso/ghostdag-rank-v1/PROPUESTA-SPEC.md`.

**Etiquetas de afirmación, por regla del encargo §6.5:**
- **Verificado en fuente** — el dato se leyó en el archivo citado (ruta desde la raíz del repo),
  en el commit fijado (`PDF/autonomys-subspace` @ `f8842d0`, confirmado con `git rev-parse`).
- **Propuesto** — texto nuevo que esta propuesta introduce.
- **No determinado por el SPEC** — el SPEC actual no lo fija; se dice explícitamente.

**Decisiones de Katana del 2026-09-19 incorporadas:** D-1 = opción A (conservar `blake3` byte
a byte) y D-2 = opción A (`pot_output = salida(f, slot(B) + D)`, la salida futura). El
registro completo de ambas está en `DECISIONES-PENDIENTES.md`.

**Alcance:** reglas del PoT como primitiva (§3.1 del encargo), contrato del verificador (§3.2),
clave de la caché (§3.3) y orden de validación (§3.4). **Fuera de alcance y sin tocar** (§4):
inyector, activación de entropía, derivación del flujo, no fusión, selección entre flujos,
revelación retardada, y los valores de `I`, `L`, `F`, `ρ_max`, `D` y `N(s)` (símbolos). Todo lo
de `P-2.1/` queda intacto.

---

## 1 · El PoT como primitiva (§3.1)

### C-POT-01 · Encadenado de semilla slot a slot — propuesto

Dado un flujo `f` (identificador opaco de 32 bytes que aporta el contexto, §4) y una semilla
inicial `semilla(f, 0)` aportada por el contexto:

```text
semilla(f, s) = salida(f, s−1)                                  (caso general)
semilla(f, s) = blake3(entropía(f, s) ‖ salida(f, s−1))[0..16)  (si el contexto declara inyección en s)
```

- **Verificado en fuente:** el encadenado y el orden de la inyección son los de Autonomys.
  `PotOutput::seed()` devuelve los mismos 16 bytes
  (`PDF/autonomys-subspace/crates/subspace-core-primitives/src/pot.rs:284-286`);
  `PotOutput::seed_with_entropy()` concatena **la entropía primero** y trunca a 16 bytes
  (`pot.rs:290-295`); el cambio de semilla se aplica exactamente en el slot de inyección
  (`PDF/autonomys-subspace/crates/sp-consensus-subspace/src/lib.rs:100-138`,
  `PotNextSlotInput::derive`).
- **Verificado en fuente (evidencia histórica):** coincide con R-FIN-14(a)
  (`research/dag-poas-ancla-de-orden.md:261-265`); `research/README.md:7-10` declara ese
  documento evidencia histórica: da el diseño candidato, no texto normativo.
- **Propuesto:** la entropía y el slot de activación son **ENTRADAS que aporta el contexto**;
  esta propuesta no define quién las produce ni cuándo (depende de `P-2.1/`, encargo §4). Lo
  único que fija es la forma de la derivación, que es la que `pot-estable` ya puede ejecutar
  con blake3.
- **Propuesto:** a lo sumo una inyección por slot (R-FIN-14(a)). Si el contexto declarara más
  de una, el estado es `Pendiente` por error de contexto (C-POT-06), nunca una decisión local.
- **Génesis (propuesto):** `semilla(f, 0)` la aporta el contexto; el bloque génesis no lleva
  justificación (`pot_bundle_count = 0`, **verificado en fuente** `SPEC.md:923` y
  `crates/zx-core/src/wire_dag.rs:112-116`). La salida del slot 0 se evalúa desde esa semilla
  y su reto se deriva como el de cualquier slot (C-POT-03). De dónde sale `semilla(f, 0)` es
  parte del bootstrap del flujo y **queda fuera de este alcance** (R-FIN-2, `P-2.1/`).
  Evidencia del diseño candidato, no normativa: Autonomys la deriva de
  `blake3(genesis_block_hash ‖ external_entropy)[..16)` (`pot.rs:176-187`).

### C-POT-02 · Salida, checkpoints y verificación de un slot — propuesto

```text
salida(f, s) = AES128_chain^{N(s)}(semilla(f, s))
```

evaluada en 8 tramos uniformes: un `PotCheckpoints` de `8 × 16 = 128 B`, siendo la salida el
**último** de los ocho (`output()`).

- **Verificado en fuente:** `prove(seed: PotSeed, iterations: NonZeroU32) ->
  Result<PotCheckpoints, PotError>` y `verify(seed, iterations, &PotCheckpoints) ->
  Result<bool, PotError>` en `prototipos/pot-estable/src/lib.rs:31-71`;
  `PotCheckpoints` = `[PotOutput; 8]` con `output() = self.0[7]` en
  `prototipos/pot-estable/src/tipos.rs:37-44`. El port reproduce 32/32 vectores diferenciales
  byte a byte del original (`prototipos/pot-estable/LEEME.md:26-37`).
- **Verificado en fuente:** la verificación exige que `iterations` sea múltiplo de
  `8 × 2 = 16` y devuelve `NotMultipleOfCheckpoints` en otro caso (`lib.rs:14-26, 32-40`).
- **Propuesto:** la verificación de un slot es una función **determinista** de la terna
  `(semilla, N, PotCheckpoints)`: misma terna, mismo resultado, en cualquier nodo y en
  cualquier orden de llegada. Es la propiedad en la que se apoya C-POT-07 (la caché).
- **Verificado en fuente:** la clave AES del tramo es `blake3(seed)[0..16)`
  (`pot.rs:189-195`; idéntico en `prototipos/pot-estable/src/tipos.rs:22-29`).
  **D-1 decidida por Katana el 2026-09-19 (opción A):** se conserva `blake3` byte a byte;
  los 32 vectores diferenciales y la equivalencia con Autonomys siguen siendo la validación
  externa del port.

### C-POT-03 · Aleatoriedad y reto por slot, sin atajos — propuesto

```text
aleatoriedad(f, s) = blake3(salida(f, s))
reto(f, s)        = blake3(aleatoriedad(f, s) ‖ LE64(s))
```

- **Verificado en fuente:** `derive_global_randomness` = `blake3(output)` (`pot.rs:276-280`);
  `derive_global_challenge` = `blake3(aleatoriedad ‖ LE64(slot))`
  (`PDF/autonomys-subspace/crates/subspace-core-primitives/src/lib.rs:104-112`).
- **Propuesto — prohibición de R-FIN-14(e) elevada a regla:** ningún reto de un slot puede
  derivarse de una función que permita saltarse slots. En particular **MUST NOT** existir
  `reto(f, s) = H(flujo(f) ‖ s)` ni ninguna PRF de `s` a partir de un valor fijo de época: el
  reto de `s` solo es derivable después de evaluar la cadena secuencial hasta `s`. La
  secuencialidad es lo único que impide evaluar de antemano la época entera de un candidato a
  ancla (**verificado en fuente, evidencia histórica:** `research/dag-poas-ancla-de-orden.md:272-275`).
- **Verificado en fuente:** la entropía que el contexto entrega en una inyección tiene, en el
  diseño candidato, la forma `blake3(chunk ‖ pot_output)`
  (`PDF/autonomys-subspace/crates/subspace-verification/src/lib.rs:442-446`); esta propuesta
  la trata como entrada opaca del contexto y no fija su derivación (encargo §3.1).

### C-POT-04 · Dominio de N(s) y proyección u64 → NonZeroU32 — propuesto

- **Verificado en fuente — desajuste concreto:** la primitiva exige `NonZeroU32` múltiplo de
  16 (`prototipos/pot-estable/src/lib.rs:31-40`); el trait del nodo lo entrega como
  `u64` (`crates/zx-core/src/wire_dag.rs:363`, `fn iteraciones(&self, slot: u64) -> u64`).
- **Propuesto:** el contexto sigue expresando `N(s)` en `u64` (dominio de slots e iteraciones
  del resto del nodo; R-FIN-9 deja la autoridad de actualización pendiente). El **verificador**
  hace la proyección con `try_from` y comprobaciones, **sin panic ni envoltura silenciosa**
  (los lints del workspace prohíben el panic en código de consenso,
  `Cargo.toml:86-92`). Si `N(s) == 0`, `N(s) > u32::MAX` o `N(s) % 16 ≠ 0`, el estado es
  **`Pendiente` con diagnóstico de contexto, nunca `Inválido`**: el fallo está en el pasado
  validado del nodo o en su implementación, no en el candidato. Un bloque no se invalida por
  un defecto del verificador (misma lógica que C-POT-07: validez ≠ recursos/estado interno).
- **Propuesto:** `N(s)` es función del pasado validado y lo aporta el contexto; el candidato
  **MUST NOT** poder declararlo. Su valor y su autoridad de actualización quedan como símbolo
  pendiente (**verificado en fuente:** `SPEC.md:1455-1458`; R-FIN-9 en
  `research/dag-poas-ancla-de-orden.md:377-381`).

### C-POT-05 · Qué es el `pot_output` de la cabecera y qué cubre la justificación — propuesto, con D-2 decidida

La cabecera DAG lleva **un solo** `pot_output` de 16 B en `[88,104)`
(**verificado en fuente:** `SPEC.md:834`). Autonomys lleva **dos** salidas en el pre-digest:
`proof_of_time` (slot `s`) y `future_proof_of_time` (slot `s + D`)
(**verificado en fuente:**
`PDF/autonomys-subspace/crates/sp-consensus-subspace/src/digests.rs:56-86`). **No determinado
por el SPEC** cuál de las dos es el campo único de ZEROX; **decidido por Katana el
2026-09-19 (D-2, opción A)**: la salida futura. La regla se redacta según esa opción; el
registro de las tres opciones con su coste está en `DECISIONES-PENDIENTES.md`.

**Regla propuesta (D-2-A):**

```text
pot_output(B) = salida(f, slot(B) + D)      (la salida «future», anclada en la cabecera)
```

- La justificación de `B` lleva `d = slot(B) − slot(sp(B))` portadores, `0 ≤ d ≤ 150`
  (**verificado en fuente:** C-HDR-07, `SPEC.md:907-928`). El portador `i` cubre el slot
  `slot(sp(B)) + D + i`; el **último checkpoint del último portador MUST ser igual a
  `pot_output`** (**verificado en fuente, patrón de Autonomys:** «Last checkpoint must be our
  future proof of time», `PDF/autonomys-subspace/crates/sc-consensus-subspace/src/verifier.rs:259-262`;
  el rango de checkpoints producidos cubre `(slot_padre + D, s + D]`,
  `PDF/autonomys-subspace/crates/sc-consensus-subspace/src/slot_worker.rs:390-479`).
- Con esto cuadran C-HDR-07 y R-FIN-14(d): `pot_bundle_count == slot(B) − slot(sp(B))` es
  exactamente el número de slots del rango `(slot(sp(B)) + D, slot(B) + D]`, y el último
  checkpoint ancla la cadena en la salida firmada en la cabecera. La semilla del primer slot
  del rango la deriva el contexto del pasado validado (con D-2-A es la salida del slot
  `slot(sp(B)) + D`, ya anclada en un bloque anterior), nunca del candidato (C-POT-06).
- **Coste de la opción A, dicho en voz alta:** el reto del slot `s` (C-POT-03) usa la salida
  del slot `s`, que **no** está en la cabecera ni en la justificación de `B` (el rango
  empieza en `s−d+D`... puede no contener el slot `s`). La salida del slot `s` la aporta la
  caché por slot (C-NET-31) o la verificación del slot `s` por gossip; en el camino **bajo
  demanda** (C-NET-32) la justificación de `B` no basta para derivar el reto del slot `s` y
  hay que verificar el slot `s` aparte o retener. Detalle en D-2. **Observación de Katana al
  decidir (2026-09-19):** como el PoT se verifica una vez por slot y se cachea de todos modos
  (C-NET-31), este coste casi desaparece; queda solo el residuo del camino bajo demanda.

---

## 2 · El contrato del verificador (§3.2)

### C-POT-06 · Entradas, salida de tres estados y prohibición de circularidad — propuesto

**Entradas.**

1. **Del candidato** (lo único que viaja en el wire): cabecera DAG (con `slot` y
   `pot_output`) y la justificación `JustificacionPot` (**verificado en fuente:** C-HDR-07,
   `SPEC.md:907-928`; `crates/zx-core/src/wire_dag.rs:1-21, 103-107`).
2. **Del contexto, derivado exclusivamente del pasado DAG validado:** el identificador de
   flujo `f` como **valor opaco de 32 bytes** (`wire_dag.rs:356-357`), la semilla del primer
   slot del rango y las inyecciones/`N(s)` por slot dentro de él, el retardo de autoría `D`
   (`wire_dag.rs:358-363`), y la caché de slots del propio nodo (C-POT-07). La implementación
   actual del trait es `ContextoVerificacionPot` (`wire_dag.rs:351-364`); esta propuesta fija
   su contrato, no su código.

**Salida.** Un estado de **tres valores** (sustituye al booleano de `verify`):

```text
PotValido                    — cadena completa verificada y anclada (pasos 1-4 de C-POT-08)
PotInvalido(razón)           — defecto del candidato, verificable y final
PotPendiente(razón)          — sin prueba de invalidez, pero tampoco validez
```

- **Nada `Pendiente` pasa a `Válido` por defecto.** La única transición
  `Pendiente → Válido` es una verificación posterior **exitosa** con las mismas entradas de
  contexto; `Pendiente → Inválido`, si se completa la verificación. Mientras no haya
  verificador integrado, el estado es `IntegracionPotPendiente` y **nunca** un `Ok(())`
  provisional (**verificado en fuente:** `SPEC.md:926-928`; `wire_dag.rs:343-349, 366-383`).
- **Semántica de los estados — propuesto:**
  - `Inválido`: `slot(B) < slot(sp(B))` o descuadre/desborde de portadores (C-HDR-05/C-HDR-07;
    `ErrorDiferenciaSlots`, `wire_dag.rs:317-341`);   `verify == false` para alguna terna con la
    semilla y `N(s)` del contexto; último checkpoint del último portador ≠ `pot_output`
    (C-POT-05); discrepancia con la caché **bajo la misma clave** (C-POT-07).
  - `Pendiente`: `N(s)` fuera del dominio C-POT-04; salida del slot no disponible y slot por
    delante del reloj PoT del nodo (C-NET-32.2, `SPEC.md:3003-3004`); presupuesto de CPU
    agotado (C-POT-07, **nunca** `Inválido`); fallo interno del contexto (inyección
    ambigua, semilla ausente).
  - `Válido`: solo con la verificación AES completa del rango y el ancla comprobada.

**Prohibición de circularidad — propuesto, con el mismo principio que C-HDR-06:**

- El verificador **MUST NOT** aceptar del propio candidato lo que debe venir del pasado
  validado: el flujo, la semilla del rango, las inyecciones y `N(s)` **MUST** aportarlos el
  contexto. El candidato solo aporta los checkpoints (evidencia reemplazable, **verificado en
  fuente:** C-HDR-07, `SPEC.md:924-925`) y el `pot_output` anclado (redundancia comprobada,
  nunca fuente de verdad). Ninguna implementación **MUST** ofrecer una vía que acepte el
  valor declarado por el candidato como si fuese el esperado: la circularidad **MUST** ser
  imposible, no desaconsejada. El principio es el de C-HDR-06 sobre `rango_solucion`
  (**verificado en fuente:** `SPEC.md:891-898`).
- El identificador de flujo es **opaco** para el verificador: se usa para indexar el contexto
  y en la clave de la caché (C-POT-07); **MUST NOT** interpretarse como estructura, derivarse
  de él o validarlo. Su derivación es R-FIN-3/P-2.1 (fuera de alcance).

---

## 3 · La clave de la caché de PoT (§3.3)

### C-POT-07 · Caché indexada por contexto, validez separada de política de recursos — propuesto

**Defecto actual — verificado en fuente:** C-NET-31 cachea «el resultado» **por slot a secas**
(`SPEC.md:2976-2980`) y C-NET-32.1 declara **inválido** el bloque cuya salida no coincida con
la cacheada (`SPEC.md:3001-3002`). Con más de un flujo candidato, `salida(f₁,s) ≠ salida(f₂,s)`
y la validez dependería de **lo que llegó primero** a la caché del nodo, contra el principio
de que la validez es función del pasado del bloque y de nada más. Es el mismo defecto que la
ronda 10a tuvo que retirar: la regla (h.3) «continuidad por defecto» hacía `flujo` depender
de cuándo llega un mensaje y **rompía R-FIN-5**; sustituida por (h.3′) validez incondicional
(**verificado en fuente:** `research/dag-poas-ancla-de-orden-auditoria-9a.md:18-21, 50-52`).

**Corrección propuesta.**

```text
clave_caché = (f, s, semilla(f, s), N(s))     — los cuatro del contexto, no del candidato
valor       = salida(f, s)
```

- **Propuesto:** la caché **MUST** indexarse por la clave contextual completa — como mínimo
  flujo, slot, semilla e iteraciones (encargo §3.3). Una entrada cacheada pertenece a un
  contexto; discrepar con una entrada de **otra** clave no prueba nada (son cadenas de PoT
  distintas, ambas legítimas). Con la **misma** clave el PoT es determinista (C-POT-02):
  discrepancia ⇒ `Inválido`, sin gastar AES en la cadena (comparación de 128 B; coste medido
  del orden de una `memcmp`, **verificado en fuente:**
  `veritas/rendimiento/coste-salto-v1/README.md:20,175-177`).
- **Propuesto — validez ≠ política de recursos:** agotar el presupuesto de CPU por par e
  intervalo (C-NET-32.3, `SPEC.md:3005-3009`) produce `Pendiente`, **nunca** `Inválido`: un
  nodo sin recursos no declara falsa una prueba que no ha verificado. Lo mismo para retención
  por reloj (C-NET-32.2).
- **Verificado en fuente — antecedente no llevado al SPEC:** C-TIMELORD-01 formula la validez
  «sobre el flujo derivado de **su** cadena seleccionada»
  (`research/timelord-redundancia-informe.md:118`); el encargo señala que nunca se incorporó.
  La clave contextual de arriba es la forma operativa de ese principio.

**Inocuidad con un único flujo — DEMOSTRADA (por construcción).** Hipótesis: el contexto
deriva un único flujo `f` para todos los bloques (flujo único por cadena seleccionada,
R-FIN-3; no fusión, R-FIN-5 — evidencia histórica, `research/dag-poas-ancla-de-orden.md:258-296`).
Bajo esa hipótesis:

1. `f` es constante, y `semilla(f, s)` y `N(s)` son funciones del slot (el encadenado de
   C-POT-01 es determinista y las inyecciones son, si existen, las del contexto único). Luego
   `clave_caché` es **función de `s`**: el índice por clave coincide con el índice por slot
   actual de C-NET-31/32.
2. «Discrepar con otra clave» es **inalcanzable**: no existe una segunda clave para el mismo
   slot. La cláusula nueva nunca se dispara.
3. «Con la misma clave, discrepancia ⇒ Inválido» es exactamente la salvaguarda 1 de C-NET-32
   actual.

Por tanto, con un único flujo la corrección es **inocua**: el comportamiento observable es
idéntico al texto vigente. Solo cambia cuando existen dos o más flujos candidatos en juego,
que es precisamente el régimen donde el texto vigente es incorrecto. Q.E.D.

---

## 4 · Orden de validación en lo que toca al PoT (§3.4)

### C-POT-08 · Estructural y barato antes que AES; cada paso con su estado — propuesto

El marco ya está decidido (Q4, **verificado en fuente:** `TAREAS.md:165-169`; C-NET-06,
`SPEC.md:2519-2525`): antes de reenviar se comprueban cabecera, prueba de espacio, 2 KZG,
sello, justificación PoT (desde la caché) y compromiso Merkle; el PoT se verifica una vez por
slot y se cachea (C-NET-31). Esta propuesta fija el orden **interno** de la parte PoT, sin
contradecir C-NET-06:

| Paso | Comprobación | Coste | Estado de salida si falla |
|---|---|---|---|
| 1 | **Estructural, sin AES.** Decode acotando antes de reservar (C-WIRE-04/05; `wire_dag.rs:239-244`); `slot(B) ≥ slot(sp(B))` (C-HDR-05); `pot_bundle_count == slot(B) − slot(sp(B))`, `≤ 150`, sin underflow (C-HDR-07) | O(1) + lectura del wire | `Inválido` (`ErrorDiferenciaSlots`) |
| 2 | Cabecera y sello (C-HDR-03/04) — fuera del PoT, ya en Q4 | µs | `Inválido` |
| 3 | **Caché por clave** (C-POT-07): comparar la salida anclada contra la entrada de la clave del contexto. Misma clave + discrepancia → fin **sin gastar AES**. Slot ausente y por delante del reloj → retención | ~memcmp 128 B | `Inválido` / `Pendiente` (retención) |
| 4 | **AES secuencial del rango** (solo si el paso 3 no zanjó): por cada portador `i`, `verify(semilla_i, N(s_i), checkpoints_i)`; encadenar semilla; último checkpoint == `pot_output` | 92 ms/slot de media en AVX-512/VAES | `Inválido` si `verify == false`; `Pendiente` si presupuesto agotado |
| 5 | Solo con `Válido` de PoT: derivar `aleatoriedad`/`reto` del slot `s` (C-POT-03) y verificar la solución PoAS contra ese reto (verificación conjunta, §7.1) | — | según §7.1 |

- **Verificado en fuente — costes:** 92 ms (AVX-512/VAES), 101 ms (AVX2/VAES), 190 ms
  (AES-NI/SSE4.1), 8,3 s (AES por software)
  (`veritas/rendimiento/coste-salto-v1/resultados/RESUMEN.md:66-68` y salidas de lotes
  `salida-lote1-completa.txt:39-42,99`; `SPEC.md:2987-2991`); producir, 1,561 s en un
  9950X3D con 200 032 000 iteraciones (`research/dag-poas-ancla-de-orden.md:342`). No se
  recalculan (encargo §2).
- **Propuesto:** el paso 3 garantiza que el camino normal (gossip de PoT, C-NET-31) no paga
  AES por bloque: el coste por salto queda acotado por construcción, que es el criterio
  declarado de C-NET-06 (**verificado en fuente:** `SPEC.md:2530-2531`). El paso 4 es el
  respaldo bajo demanda (C-NET-32), con presupuesto (paso 3 de C-NET-32,
  `SPEC.md:3005-3009`).
- **Propuesto:** un `Pendiente` en el paso 4 por presupuesto agotado **no** invalida el
  bloque (C-POT-07): el nodo retiene y completa cuando pueda, y el bloque no se adopta ni se
  declara válido hasta entonces (C-HDR-07).

---

## 5 · Vectores de prueba (§3.5) — segunda prioridad, incluidos

Lista de vectores para fijar §1 (todos con `blake3`, conforme a D-1 decidida, opción A):

| Vector | Fija | Entrada | Salida esperada |
|---|---|---|---|
| V1 | encadenado sin inyección (C-POT-01) | `semilla(f,0)` fija, `N=16`, 4 slots | `salida(f,0..3)`, semillas encadenadas |
| V2 | inyección (C-POT-01) | entropía fija 32 B + `salida(f,s−1)` | `semilla = blake3(entropía ‖ salida)[0..16)` y la cadena posterior |
| V3 | aleatoriedad (C-POT-03) | `salida` fija | `blake3(salida)` (32 B) |
| V4 | reto (C-POT-03) | `aleatoriedad` fija, `slot` fijo | `blake3(aleatoriedad ‖ LE64(slot))` (32 B) |
| V5 | dominio de N (C-POT-04) | `N ∈ {0, 7, 15, 2^32, u32::MAX}` | `NotMultipleOfCheckpoints` / rechazo → `Pendiente` |
| V6 | caché (C-POT-07) | misma clave, salida distinta; otra clave | `Inválido` / no prueba nada |

**Estado:** generados con un crate mínimo dentro de esta zona
(`P-POT/propuesta/vectores/`, véase su `LEEME.md`), que depende de `pot-estable` por ruta y
ejecuta solo `N=16` iteraciones (coste trivial; nada pesado, encargo §6.3). Comando de
regeneración:

```bash
cargo test --manifest-path P-POT/propuesta/vectores/Cargo.toml --release --offline -j 2
```

Los valores fijados están en `P-POT/propuesta/vectores/vectores.txt`. **Límite declarado:**
V1/V2 solo cubren la forma del encadenado y de la inyección con `N` mínimo; los 32 vectores
diferenciales de `pot-estable` (N grande, byte a byte con Autonomys) siguen siendo la
validación externa del AES, y estos vectores no la sustituyen.

---

## Lo que esta propuesta NO resuelve

- **Quién es el inyector, cuándo se activa la entropía, cómo se deriva el flujo, la no
  fusión, la selección entre flujos rivales, la revelación retardada (h), y los valores de
  `I`, `L`, `F`, `ρ_max`, `D` y `N(s)`.** Van como símbolos (encargo §4); dependen de
  `P-2.1/`, cuya zona no se ha tocado.
- **La verificación conjunta PoAS/PoT completa** (§7.1): el paso 5 de C-POT-08 supone el reto
  del slot; la solución de espacio, los testigos KZG y la distancia de solución siguen
  pendientes de redacción conjunta (`SPEC.md:1278-1285`).
- **D-1 y D-2 ya no son pendientes:** Katana las decidió el 2026-09-19 (A y A); registro
  completo en `DECISIONES-PENDIENTES.md`.
- **La interfaz Rust definitiva del contexto** (tipos exactos del trait): esta propuesta fija
  el contrato semántico; el código del nodo queda fuera del alcance del encargo.
- **La procedencia de `semilla(f, 0)`** (bootstrap del flujo): declarada entrada del contexto,
  sin definir su origen.
- **C-CHK-05** (omitir verificación por debajo de la altura del checkpoint): se cita como
  compatible con C-NET-31; no se toca ni se calibra.
