# P-POT — Propuesta de reglas para el PoT como primitiva y contrato del verificador

**Ejecutor:** agente DeepSeek independiente. **Zona de trabajo: `P-POT/propuesta/`.**
**Diseñado por:** Claude, 2026-09-18, por decisión de Katana.
**Tipo de trabajo:** redacción de una **propuesta de SPEC**, con citas a fuente. **No es una auditoría
de cálculo**: no hay simulaciones ni Julia. **No escribes código del nodo.**
**Entregable principal:** `P-POT/propuesta/PROPUESTA-SPEC.md`.

## 0 · Por qué existe este encargo

`TAREAS.md` §2.1 (verificación conjunta PoAS/PoT) es la prioridad. Su parte de **regla de flujo**
(quién es el inyector, cuándo se activa la entropía, qué pasa con flujos rivales) está **bloqueada**
por una auditoría en curso (`P-2.1/`) y **queda fuera de este encargo**. Pero hay un bloque que hace
falta **salga lo que salga** de esa auditoría, porque todas las soluciones candidatas usan el mismo
PoT AES secuencial: **las reglas del PoT como primitiva, el contrato del verificador, la clave de la
caché y el orden de validación.** Sin ese bloque el verificador no puede existir: hoy
`zx-core::wire_dag::verificar_justificacion_pot` devuelve siempre `IntegracionPotPendiente`, y
`prototipos/pot-estable` no puede entrar como crate porque el repositorio es *spec-first*: el código
entra cuando tiene reglas `C-XXX-NN` que citar.

**Hay otro agente trabajando a la vez en `P-2.1/` con 24 hilos. No lances cómputo pesado y no toques
su zona.**

## 1 · Lecturas obligatorias (pocas, y en este orden)

1. `AGENTS.md` y `SPEC.md` §0 (convenciones normativas, MUST/MUST NOT).
2. `SPEC.md` §6.1–§6.2 (l. 820-978): cabecera DAG, **C-HDR-05, C-HDR-06, C-HDR-07**, C-HDR-09.
3. `SPEC.md` §7.1 y §7.3 (l. 1278-1473): lo que el SPEC ya dice y lo que declara pendiente.
4. `SPEC.md` **C-NET-31 y C-NET-32** (l. 2976-3010).
5. `research/dag-poas-ancla-de-orden.md` l. 258-296 (**R-FIN-14** con su corrección y su alcance del
   2026-09-10) y l. 377-381 (**R-FIN-9**). Es **evidencia histórica** (`research/README.md`): da el
   diseño candidato, no texto normativo.
6. `crates/zx-core/src/wire_dag.rs` l. 280-390: comprobación estructural de slots, `IntegracionPotPendiente`,
   trait `ContextoVerificacionPot`, `verificar_justificacion_pot`.
7. `prototipos/pot-estable/LEEME.md`, `src/lib.rs`, `src/tipos.rs`.
8. `veritas/consenso/ghostdag-rank-v1/PROPUESTA-SPEC.md`: **es tu plantilla de forma.**
9. `TAREAS.md` §2.1 (incluido el orden de red «Q4») y §4.2 (convención de IDs de regla).

## 2 · Datos ya verificados por el diseñador el 2026-09-18 — compruébalos tú antes de citarlos

**Fuente de Autonomys** (`PDF/autonomys-subspace/`, la copia fijada **dentro del repo**, commit `f8842d0` según `PDF/README.md`; las rutas de la tabla son relativas a ella):

| Derivación | Definición exacta | Dónde |
|---|---|---|
| semilla sin inyección | `seed = PotSeed(output)` (los mismos 16 bytes) | `crates/subspace-core-primitives/src/pot.rs:284-286` |
| semilla con inyección | `blake3(entropía ‖ output)[0..16)` — **entropía primero** | `pot.rs:290-295` |
| aleatoriedad del slot | `blake3(output)` | `pot.rs:278-280` |
| reto global del slot | `blake3(aleatoriedad ‖ LE64(slot))` | `crates/subspace-core-primitives/src/lib.rs:110-112` |
| entropía de un bloque | `blake3(chunk ‖ pot_output)` | `crates/subspace-verification/src/lib.rs:444-446` |
| clave AES | `blake3(seed)[0..16)` | `prototipos/pot-estable/src/tipos.rs` (`PotSeed::key`) |
| retardo de autoría | el bloque del slot `s` justifica hasta `s + D`; los checkpoints cubren `(slot_padre + D, s + D]` | `crates/sc-consensus-subspace/src/slot_worker.rs:391-479` |

Coinciden con R-FIN-14(a)(b)(d). **`pot-estable` hoy no implementa** `seed()`, `seed_with_entropy` ni
la aleatoriedad/reto: solo `prove`, `verify`, los cuatro tipos y `PotSeed::key`.

**`pot-estable`:** `prove(seed: PotSeed, iterations: NonZeroU32) -> Result<PotCheckpoints, PotError>` y
`verify(seed, iterations, &PotCheckpoints) -> Result<bool, PotError>` (`src/lib.rs:31`, `:52`).
`iterations` **MUST** ser múltiplo de `8 × 2 = 16`, o devuelve `NotMultipleOfCheckpoints`.
`PotCheckpoints` = 8 × `PotOutput` de 16 B = 128 B; `output()` es el último. 32/32 vectores
diferenciales contra el crate original. **No** está en `members` del workspace, a propósito.

**El nodo:** el trait `ContextoVerificacionPot` pide `flujo(slot) -> [u8;32]`, `semilla(slot) -> [u8;16]`,
`retardo_autoria() -> u64`, `iteraciones(slot) -> u64`. **Desajuste concreto:** `u64` frente al
`NonZeroU32` múltiplo de 16 que exige la primitiva.

**El SPEC:** la cabecera lleva `slot: u64` en `[80,88)` y **un solo** `pot_output: [u8;16]` en
`[88,104)`. C-HDR-07: `0 ≤ pot_bundle_count ≤ 150`, y para no génesis
`pot_bundle_count == slot(B) − slot(sp(B))`; la justificación **no** entra en `block_hash`; mientras no
haya verificador, estado explícito `IntegracionPotPendiente`, «nunca un booleano verdadero provisional».
C-HDR-06 ya usa `flow(B, slot(B))` sin definirlo. `H_d(tag, m) := SHA3-256(tag ‖ m)` con etiquetas de
16 bytes `ZZK…`, lista cerrada en C-HASH-06. **No existe ninguna familia `C-POT`** (cero apariciones).

**Coste medido** (no lo recalcules): verificar un slot cuesta 92 ms (AVX-512/VAES), 101 ms (AVX2/VAES),
190 ms (AES-NI), 8,3 s (AES por software) — `veritas/rendimiento/coste-salto-v1/`; producirlo, 1,561 s
en un 9950X3D con 200 032 000 iteraciones.

## 3 · Lo que tienes que proponer

Redacta reglas con **IDs nuevos y estables** (familia propuesta `C-POT-NN`; §4.2 de TAREAS prohíbe
reutilizar IDs retirados), en el estilo normativo del SPEC, cada una con su justificación y su cita.

### 3.1 · El PoT como primitiva
Encadenado de semilla slot a slot; semilla en un slot de inyección, **tomando la entropía y el slot de
activación como ENTRADAS que aporta el contexto** (no definas de dónde salen); aleatoriedad y reto por
slot; verificación de un slot a partir de `(semilla, N, PotCheckpoints)`; dominio de `N(s)` (no cero,
múltiplo de 16, rango); qué pasa en el génesis. **Prohibición de R-FIN-14(e):** ningún reto derivable
saltándose slots.

**Pregunta abierta que debes resolver o elevar, no esconder:** Autonomys lleva en el pre-digest **dos**
salidas (`proof_of_time` del slot y `future_proof_of_time` del slot `+D`); la cabecera de ZEROX tiene
**un solo** `pot_output`. ¿Cuál es, y cómo cuadra con `pot_bundle_count == slot(B) − slot(sp(B))` y con
R-FIN-14(d)? Si el SPEC no lo determina, dilo y pon las opciones con su coste.

### 3.2 · El contrato del verificador
Qué recibe, qué devuelve y qué **no** puede hacer. Mínimo: resultado de **tres estados** (`Válido`,
`Inválido`, `Pendiente`) con la semántica de C-HDR-07 («distinguir datos pendientes de pruebas
verificadas como inválidas»); **nada `Pendiente` pasa a válido por defecto**; tipo y validación de `N(s)`
(resuelve el desajuste `u64`/`NonZeroU32`); qué aporta el contexto y por qué el verificador **MUST NOT**
aceptar del propio candidato lo que debe venir del pasado validado (mismo principio que C-HDR-06: la
circularidad **imposible**, no desaconsejada). El identificador de flujo es aquí un **valor opaco de 32
bytes que aporta el contexto**.

### 3.3 · La clave de la caché de PoT
C-NET-31/32 cachean por `slot` a secas, y C-NET-32.1 declara **inválido** el bloque cuya salida no
coincida con la cacheada (`SPEC.md:3001-3002`). Con más de un flujo candidato, `salida(f₁,s) ≠ salida(f₂,s)`
y la validez pasaría a depender **de lo que llegó primero**, contra el principio de que la validez es
función del pasado del bloque y de nada más. Es el mismo defecto que la ronda 10a tuvo que retirar
(`research/dag-poas-ancla-de-orden-auditoria-9a.md:19,50-52`). Propón la corrección: clave que incluya el
contexto (como mínimo prefijo de flujo, slot, semilla e iteraciones); **discrepar con una entrada de otra
clave no prueba invalidez**; con la **misma** clave, sí (el PoT es determinista). Y separa **validez** de
**política de recursos**: agotar un presupuesto de CPU produce `Pendiente`, nunca `Inválido`. Señala
también `C-TIMELORD-01` (`research/timelord-redundancia-informe.md` §3.3), nunca llevada al SPEC, que
formula la validez «sobre el flujo derivado de **su** cadena seleccionada». Con un único flujo tu
corrección debe ser **inocua**: demuéstralo.

### 3.4 · El orden de validación
Parte del orden de red ya decidido (Q4, `TAREAS.md` §2.1) y propón el orden completo de validación de un
bloque en lo que toca al PoT: qué comprobaciones **estructurales y baratas** van antes de gastar AES, y
cuáles después. Cada paso con su estado de salida.

### 3.5 · Vectores de prueba — segunda prioridad, opcional
Lista qué vectores harían falta para fijar 3.1 (encadenado, inyección, aleatoriedad, reto). Si puedes
generarlos con un crate mínimo **dentro de tu zona** que dependa de `pot-estable` por ruta, hazlo y di
con qué comando; si no, deja la lista. **No ejecutes nada pesado.**

## 4 · Fuera de alcance — si lo tocas, se rechaza

Quién es el inyector (R-FIN-1), cuándo se activa (R-FIN-2, `L`), cómo se deriva el flujo (R-FIN-3), la no
fusión (R-FIN-5), la selección entre flujos rivales, la revelación retardada (h), y los valores de `I`,
`L`, `F`, `ρ_max`, `D` y `N(s)` (van como **símbolos**). Tampoco la autoridad que actualiza `N(s)`
(R-FIN-9 lo declara pendiente). Todo eso depende de `P-2.1/`.

## 5 · Una decisión que NO te toca tomar: preséntala con su coste

Las derivaciones de Autonomys usan `blake3` sin etiqueta de dominio; la convención de ZEROX es
`H_d = SHA3-256(tag ‖ m)`. **Opción A:** conservar `blake3` byte a byte (los 32 vectores diferenciales y
la comparación con la fuente siguen valiendo; rompe la convención de C-HASH-06). **Opción B:** pasar a
`H_d` con etiquetas nuevas (coherente con el SPEC; invalida la equivalencia con Autonomys y obliga a
vectores propios). Escribe las dos en `DECISIONES-PENDIENTES.md` con lo que gana, lo que paga y lo que
cierra cada una, y tu recomendación marcada como tal. **Decide Katana.** Añade ahí cualquier otra
bifurcación real que encuentres.

## 6 · Reglas de trabajo

1. **Escribes solo dentro de `P-POT/propuesta/`.** No edites `SPEC.md`, `TAREAS.md`, `ci/`, `crates/`,
   `prototipos/`, `P-2.1/` ni `deepseek/`. **No muevas ni reorganices archivos ajenos.**
2. `P-POT/ENCARGO.md`, `PROMPT.md` y `ENTRADA.sha256` son de **solo lectura**. Al empezar y al terminar,
   desde la raíz: `LC_ALL=C sha256sum -c P-POT/ENTRADA.sha256` y `git status --short`, con su salida en
   `PROGRESO.md` junto a la de `date`. `P-POT/` saldrá como `?? P-POT/`; el resto debe quedar idéntico.
3. **Nada de Python.** Si compilas algo, Rust, dentro de tu zona, y ligero.
4. **No cites un archivo o una línea sin abrirlo.** Rutas desde la raíz del repo.
5. **Etiqueta cada afirmación:** `verificado en fuente` (con cita), `propuesto`, `no determinado por el
   SPEC`. Un «no lo sé» explícito vale más que una regla que haya que retirar. El patrón que este
   repositorio lleva repitiendo es el resultado de alcance estrecho con etiqueta ancha: no lo repitas.
6. Cierra `PROPUESTA-SPEC.md` con una sección **«Lo que esta propuesta NO resuelve»**.

## 7 · Entregables (`P-POT/propuesta/`)

`PROPUESTA-SPEC.md` · `DECISIONES-PENDIENTES.md` · `PROGRESO.md` · opcional `vectores/`.

**Si algo de este encargo te parece equivocado, dilo ANTES de redactar**, en tu primera respuesta.
Después Claude valida leyendo tus citas contra la fuente, Katana decide lo pendiente, y solo entonces
algo de esto pasa al SPEC.
