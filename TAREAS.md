# TAREAS — lo que falta para que el SPEC PoST + DAG pase a fase de código

Fecha: 2026-09-12. Derivado de §17 de [SPEC.md](SPEC.md), `ci/consenso-pendiente.txt`, los
límites declarados de los instrumentos de `veritas/consenso/`, [MIGRACION.md](MIGRACION.md) y
la auditoría externa de la comprobación decisiva v1
([AUDITORIA-EXTERNA.md](veritas/consenso/comprobacion-decisiva-v1/AUDITORIA-EXTERNA.md)).

No congela parámetros ni convierte pendientes en decisiones. Los niveles 1 y 2 separan «el SPEC
describe un protocolo» de «el SPEC especifica un protocolo». El nivel 3 separa «se puede
implementar» de «se puede lanzar».

---

## Nivel 1 — Forks latentes: el SPEC no es determinista aquí

Escribir código contra estos puntos produce nodos que discrepan. Son el único bloqueo duro.

### 1.1 · Z0 / semántica de ventana vacía

Dos implementaciones del propio proyecto ya discrepan. Julia (RCE, ARM, comprobación decisiva)
agenda una propuesta `HeldZero` con el rango del sello; el helper Rust legado
(`FeedbackState::close`, `crates/zx-consensus/tests/`) no agenda nada.

Medido el 2026-09-12 sobre `causal_step`, ventanas con `N = [5, 0, 5, 5]`:

| `activation_delay_windows` | Rango final Julia | Rango final Rust | Agenda idéntica |
|---|---:|---:|---|
| 1 | 800 | 800 | no |
| **2** | **200** | **400** | no |
| 3 | 400 | 400 | no |

Con `delay ≥ 2` la propuesta `HeldZero` revierte el rango a un valor de dos ventanas atrás y
**corrompe la entrada del controlador** para la ventana siguiente, así que el error se propaga.
Con `delay = 1` los rangos coinciden pero las agendas no, y la agenda es estado de consenso en
el modelo (`controller_projection` se compara entre nodos). `activation_delay_windows` sigue
siendo «escenario pendiente» en el CONTRATO de RCE-v0.1: no cabe apoyarse en que valdrá 1.

**Análisis:** el CONTRATO usa la misma frase —«el rango se mantiene»— para `MissedUpdate`, que
se implementa **no agendando nada**, y para Z0, que se implementa **agendando `R_j`**. Agendar un
valor con activación diferida no es *mantener*, es *revertir*. La lectura fiel de «mantener» es
la omisión.

**Recomendación del auditor:** adoptar Z0 como no-op explícito (`causal_step` devuelve
`(StepHeldZero, current, 0, false)`, sin slot de activación, para que los seis puntos de llamada
no puedan agendarla), y enmendar el CONTRATO de RCE con la redacción y su motivo.
**Coste:** enmienda de RCE-v0.1 y ARM-v0.1 (contratos firmados el 11-sep), 6 puntos de llamada,
3 suites Julia y el adaptador + test de la frontera Rust. Requiere línea base de `cargo test`
medida antes, porque el workspace tiene un rojo preexistente conocido.

**Estado (2026-09-12):** decisión tomada por Katana (no-op) y enmienda ejecutada por el
ejecutor DeepSeek en `deepseek/z0-no-op-v1/` (RCE-v0.1 revisión 2, ARM-v0.1 revisión 2 y
comprobación decisiva; convergencia Julia–Rust medida en `range_at(40)=200`). **Pendiente de
validación por Claude** antes de migrar a `ZEROX/`. Los párrafos anteriores describen el
diagnóstico original del fork, no la semántica vigente tras la enmienda.

### 1.2 · `rank` no define un orden total

§7.2 fija el desempate entre copias (P1: azul primero, luego `rank`, luego id de bloque), pero
`rank` es hoy una etiqueta abstracta suministrada — CONTRATO de DCM-v0.1: «Rank y color son
etiquetas globales suministradas, no recalculadas». Hay que atarlo al orden concreto del mergeset
(`blue_work`, `solution_distance`, hash) y **demostrar que es total**. Un empate hace el desempate
no determinista, y eso es un fork. Ya declarado como PENDIENTE en §7.2.

### 1.3 · GHOSTDAG no está derivado, y P1 depende de él

El color (azul / `rojo_k` / `rojo_U3`) lo suministra hoy el oráculo del fixture; DCM-v0.1 declara
que «no acredita la coloración ni el orden contextual de GHOSTDAG». Con P1 decidido, el desempate
de §7.2 **no es computable** hasta que la coloración sea determinista y acordada por todos los
nodos. La elegibilidad ya dependía del color por R-FIN-8′, así que P1 no añade una dependencia
nueva, pero la vuelve crítica para el pago.

### 1.4 · La cabecera DAG no existe

Padres múltiples, compromisos, formato y límites de la justificación PoT, y tamaño final: todo
pendiente (§17). Persiste la discrepancia 92/556 con un test rojo conocido
(`el_spec_dice_el_tamano_real_de_la_cabecera`). Y **C-HDR-06 define `rango_esperado(padre)` como
«función pura de la cadena de cabeceras»** — lineal — cuando el destino es un DAG: esa regla hay
que reescribirla, no portarla.

---

## Nivel 2 — Reglas escritas que todavía no se pueden computar

### 2.1 · Verificación conjunta PoAS/PoT (§7.1)
Solución de espacio, testigos KZG, identidad de billete, reto, distancia de solución, sello y
justificación PoT. Pendiente además: formato y validación conjunta, retardo de autoría, puntos de
control, inyección de entropía y dependencias por flujo.

### 2.2 · La identidad del billete está supuesta, no demostrada
Toda §7.2 —dedup, unicidad pagable, peso— se apoya en que el billete identifique de verdad la
oportunidad. En los instrumentos eso es una declaración del fixture. La propiedad real depende de
`veritas/consenso/contrato-billete-v1/` y de C-HDR-03/04 (dos firmas Ed25519 bajo la misma
`public_key`). Es el límite H7 del INFORME; es el cimiento de lo que §7.2 acaba de cerrar.

### 2.3 · Rango: lo que R-FIN-13′ no cierra
Arranque por red, ventana, límites y redondeos, fusiones fuera de ventana y validación de ramas
candidatas con pesos reales. Conservado a propósito en el «Pendiente» de §7.2.

### 2.4 · Orden de ejecución del DAG y conflictos
Cadena seleccionada, peso, `blue_work`, orden de aplicación del mergeset y resolución de
conflictos de transacciones (§17, «DAG»).

### 2.5 · Alturas y calendario derivados del orden DAG
Activaciones, madurez de coinbase, timelocks, expiración de tx y sectores, archivado. MIGRACION:
«El significado de altura, orden de aplicación y madurez en DAG aún debe cerrarse antes de
trasladar esas cuentas a una garantía temporal». No escalar constantes por 120 mecánicamente.

### 2.6 · Estado UTXO con datos de deshacer
`ci/consenso-pendiente.txt` documenta que `zx-consensus::bloque::validar_bloque` no lo alcanza
nadie porque la cadena no mantiene ese conjunto — hay un `TODO(sincronizador)` en
`crates/zx-node/src/cadena.rs`. Sin eso no hay validación completa de bloque.

---

## Nivel 3 — Parámetros sin cerrar (no impiden escribir, impiden lanzar)

| # | Punto | Estado |
|---|---|---|
| 3.1 | **`Δ` sin medir** | MIGRACION: «la primera medición que el diseño necesita». Casi todo lo demás se calibra contra él |
| 3.2 | `F` = 2 h **provisional** | Con obligación declarada de bajarla en producción |
| 3.3 | `I`, `L`, `ρ_max` | Sin cerrar; `ρ_max` entre 3× sin segundo VDF y revelación retardada |
| 3.4 | **P-038** | Abierta |
| 3.5 | Génesis | Parámetros y hashes distintos por red; bootstrap explícito |

---

## Nivel 4 — Decisiones de política que nadie ha tomado

### 4.1 · Recompensa del bloque honesto tardío
Abierta el 2026-09-12 y escrita en §7.2. Medido: un bloque honesto con billete único que nadie
disputa, fusionado tras el cierre de su ventana, **no cobra nunca**. ¿Pérdida definitiva, o
reinclusión como la que modela la cola de RCE-v0.1? Con `Δ` sin medir, no es un caso de borde raro.

### 4.2 · IDs de regla para §7.2
Hoy es prosa, como el resto de §7.2. Darle IDs `C-XXX-NN` obliga a declararlos en
`ci/reglas-sin-codigo.txt` como trabajo futuro, porque `ci/citas-spec.sh` exige que toda regla esté
citada en `crates/` o declarada. Es una decisión de convención del SPEC.

---

## Nivel 5 — Deuda de evidencia (debilita afirmaciones, no bloquea)

- **H2** — la convergencia de dos nodos está probada para **un** par de órdenes de entrega, sin
  barrido de permutaciones.
- **H4** — los «dos nodos» comparten el mismo `EconModel`, incluido el oráculo `context_truth`:
  convergen en parte por construcción.
- **H5** — la capa económica no comprueba `Σsalidas ≤ Σentradas`; en el fixture principal se
  consumen 5500 y se pagan 3000 sin que nadie lo note.
- **H6** — `catch ArgumentError → Invalid` enmascara roturas de invariante interno como veredicto
  de consenso.
- El instrumento promovido no lleva `CONTRATO.md` ni `MODELO.md` como sus hermanos de
  `veritas/consenso/`.

---

## Orden recomendado

1. **Z0 (1.1)** — barato, diagnosticado, y cada línea de nodo que dependa de la agenda encarece
   el cambio.
2. **`Δ` (3.1)** en paralelo desde ya — es medición, no diseño, y desbloquea el nivel 3 entero.
3. **GHOSTDAG + `rank` total (1.3 + 1.2)** juntos — son el mismo problema por dos lados, y
   desbloquean §7.2 completa.
4. **Cabecera DAG (1.4)** — hasta que exista, ningún crate de serialización, red o almacenamiento
   puede cerrarse.
5. El resto por área, siguiendo §17 del SPEC.

---

## Cerrado recientemente (para no reabrirlo)

- **Unicidad pagable (§7.2)**, 2026-09-12. Identidad pagable = el billete; contexto persistente
  con liberación en reorg; copia en fusión posterior o fuera de ventana = inerte por dos reglas;
  desempate **P1 azul primero**, decidido por Katana, separado por escrito del orden de aplicación
  de R-FIN-8′(4); y declarado que **refina R-FIN-8′(1)**, que al pie de la letra pagaría a dos
  copias `RedK` del mismo billete.
  Evidencia: `veritas/consenso/comprobacion-decisiva-v1/`, 449/449 asserts, reproducida de forma
  independiente por el auditor.
