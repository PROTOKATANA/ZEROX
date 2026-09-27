# ORDEN-W06d7 — FC-3 de verdad en el nodo: varios terminales con sufijo PoST, selección por peso PoST, sin congelar

**LINEO (`V-ZRX/LINEO.md`) rige este código Rust** (`AUTO-ZRX.md` §52: todo el código, tests y arneses
incluidos); léelo íntegro antes de escribir código.

## 1. Identidad y contexto

- **ID:** W06d7. **Fecha:** 2026-09-27 (redactada ≈ 04:31). **Director:** Claude. **Ejecutor:** subagente
  **Sonnet**, único (cambio de consenso en `zx-cadena` y del nodo, con procesos reales).
- **Zona (única escribible):** `/home/katana/zeo/ZEROX/deepseek/W06d7/`. **Tu base es la raíz en el commit de
  `ENTRADA-W06d7.sha256`**; no leas ni uses otras zonas de `deepseek/` salvo las que cita esta orden.
- **Motivo (hallazgo de W06d6, verificado por el director en el código):** `zx-cadena` **congela el terminal**
  al admitir el primer bloque PoST (`crates/zx-cadena/src/cadena.rs`, `recalcular_terminal`: «solo se llama
  mientras `self.dag.is_none()`… una vez congelado, el terminal ya no se toca») y mantiene **un único** DAG con
  ese terminal como raíz (`inicializar_dag`); el nodo, además, solo construye el servicio PoT de verificación
  para ese terminal (`crates/zx-node/src/nodo.rs`, condición `contexto_dag().is_none()`). Eso **no** es FC-3
  (`P-ZRX/P-TRANSICION/CONTRATO-v0.md` TRN-09, decisión D-T03): «en cuanto existe al menos una historia con
  sufijo PoST válido: se selecciona la de mayor peso PoST del sufijo (`blue_work`)… el resultado debe ser
  **independiente del orden de llegada**», y rompe el invariante **I-3**. Consecuencia observada: dos lados de
  una partición que cruzan el corte con terminales distintos **no convergen nunca** (bloques de la otra rama en
  `Pendiente` para siempre). Un minero que retiene el terminal (E-9) puede provocarlo a propósito.
- **Pregunta falsable:** «Con varios terminales candidatos, cada uno con su DAG, y la selección FC-3 por
  `blue_work` de la virtual de cada uno (con `C-FIN-01`), el terminal y el estado seleccionados no dependen del
  orden de llegada, y tres nodos que cruzan el corte con terminales distintos convergen al mismo terminal, la
  misma punta y el mismo `resumen_estado` tras reunirse.»
- **Desbloquea:** E-6b y E-9 de W07b; el criterio de cierre de 0.0.1 (reglas idénticas ⇒ convergencia).

## 2. Entradas (congeladas en `P-ZRX/P-NODO/ENTRADA-W06d7.sha256`)

`CONTRATO-v0.md` (TRN-04…TRN-11, D-T03, I-3, I-4, `C-FIN-01`), `P-ZRX/P-DAG/CONTRATO-ESTADO-DAG-v0.md`,
`REVISION-W06d6.md` (y `deepseek/W06d6/DEFINICIONES-FALTANTES.md`, solo lectura), `REVISION-T02.md`,
`crates/zx-consensus/src/transicion/seleccion.rs` (FC-3 del motor, validado contra T01: `comparar_fc3`,
`comparar_terminal`, `nodo_en_linea`).

## 3. Decisiones del director

1. **Un DAG por terminal candidato** en `zx-cadena`: cada terminal que cumple el corte (TRN-04) y tiene al
   menos un bloque PoST válido que cuelga de él lleva su propio almacén GHOSTDAG (raíz = ese terminal), sus
   estados y su virtual. Un bloque PoST pertenece al DAG del terminal de su pasado; un bloque cuyos padres
   vienen de terminales distintos es **inválido** (I-4: una historia tiene como mucho un terminal), con motivo
   propio.
2. **Selección (FC-3):** si ningún terminal tiene sufijo PoST, gana el mayor trabajo PoW (como hoy); si alguno
   lo tiene, entre los que lo tienen gana el de mayor `blue_work` de su virtual; empate: la regla de
   `comparar_terminal` de `seleccion.rs` y después la de `C-GD`. Se **reutiliza** la lógica de desempate del
   motor (no una segunda implementación divergente); si no es reutilizable tal cual, se extrae a una función
   común con test.
3. **`C-FIN-01` en el cambio de terminal:** un nodo en línea no cambia de terminal si su sufijo PoST
   seleccionado ya abarca `≥ F_slots` slots desde el corte (el punto común de dos terminales distintos es
   anterior al corte). Mismo tratamiento en la repetición del reinicio que en vivo (el reinicio repite en el
   orden del registro: debe acabar con la misma selección).
4. **Tope:** como mucho `MAX_TERMINALES_CON_DAG = 8`; un noveno candidato con sufijo PoST se ignora si su trabajo
   PoW es menor que el del peor de los ocho (se registra `limite_alcanzado`). Declarar el coste de memoria.
5. **Nodo:** un servicio PoT de **verificación** por terminal con DAG (no uno solo); el productor produce sobre
   el terminal **seleccionado** y, si cambia, reconstruye su servicio PoT para el nuevo (y el firmante, cuando
   exista en el nodo, no se ve afectado: la identidad RAT-1 incluye el slot, no el terminal).
6. **API de `zx-cadena` que usan el nodo y los arneses** (`terminal()`, `contexto_dag()`, `estado_virtual()`,
   `cadena_virtual()`, `mejor_punta()`…) devuelve lo del terminal **seleccionado**; si hace falta, añade accesos
   por terminal. Los diferenciales T01 v0.5 y T04 v0.6 (un solo terminal con sufijo) **deben seguir con 0
   discrepancias** sin tocar los vectores.

## 4. Contrato de implementación

Puedes modificar `crates/zx-cadena/**`, `crates/zx-node/**` y `crates/zx-post/src/servicio_pot.rs` (solo si el
servicio por terminal lo exige), con sus tests. **Vedado:** `zx-core`, `zx-consensus` (salvo extraer una función
común de desempate a un módulo público sin cambiar su comportamiento, con los diferenciales en verde),
`zx-dag`, `zx-p2p`, `zx-storage`, `Cargo.lock` sin versiones nuevas.

## 5. Plan de verificación

| Paso | Qué | Criterio |
|---|---|---|
| V0 | `sha256sum -c` de la entrada; suite completa sin cambios | verde; si no, para |
| V1 | **I-3 por propiedades** en `zx-cadena`: historias con dos o tres terminales, cada uno con sufijo PoST de tamaños distintos (y un empate exacto de `blue_work`), llegando en ≥ 200 órdenes aleatorios (semilla fija): mismo terminal, misma punta y mismo estado virtual en todos los órdenes | 0 fallos |
| V2 | Casos dirigidos: sufijo PoST más pesado en el terminal con **menos** trabajo PoW (gana el PoST); bloque con padres de dos terminales (inválido); cambio de terminal bloqueado por `C-FIN-01`; noveno terminal ignorado; reinicio que repite el registro y acaba con la misma selección | cada uno con su aserción |
| V3 | Diferenciales T01 v0.5 y T04 v0.6 | **0 discrepancias** |
| V4 | **E-6b con procesos reales:** A aislado y {B, C} desde el génesis (terminales distintos), cada lado ≥ 20 slots PoST (dentro de `F_SLOTS`), reunión; todos convergen al terminal que FC-3 elige (se calcula y se escribe **antes** de reunir, con los pesos de cada lado leídos de los registros); tras reposo (`--dejar-de-producir-en-slot`), misma punta y `resumen_estado` en los tres | superado en 2 repeticiones |
| V5 | **V6(b) de verdad** (lo que W06d6 no llegó a probar): los tres cruzan el corte **juntos** (mismo terminal), producen ≥ 20 bloques PoST, se aísla A (reinicio sin pares) durante ≥ 20 slots mientras {B, C} siguen, reunión; tras reposo, misma punta y `resumen_estado` | superado en 2 repeticiones |
| V6 | Regresión con procesos reales: V4 (tres nodos) y el nodo tardío de W06d6 | superados |
| V7 | `fmt --check`, `clippy --workspace --all-targets --all-features --locked -- -D warnings`, `cargo test --workspace --all-features --locked`, `ci/dependencias-exactas.sh`, `ci/frontera-crates.sh` | limpio |

**Tabla de cobertura** en el informe: número de casos por situación (0/1/2/3 terminales con sufijo, empate,
bloqueo por `C-FIN-01`, tope, mezcla de terminales), mínimo 1 por fila. **Límite declarado de antemano:** no hay
oráculo independiente del caso multiterminal en DAG (T04 tiene un solo terminal); la evidencia es I-3 por
propiedades + reutilización del desempate validado + procesos reales. El oráculo T04-E queda en el IPA.

**Prohibido Python.** Presupuesto: **5 h, 8 hilos, 24 GiB.** Si se agota, entrega lo hecho y lo que falta.

## 6. Entregables y límites

Patrón de las órdenes W (`ws.orig/`, `ws/` con `Cargo.toml`, `Cargo.lock`, `rust-toolchain.toml`, `crates/`,
`testdata/`, `ci/`, `.github/` y el enlace `ws/PDF`; `cambios.patch` —**incluido `testdata/` si cambia**— y
`MIGRACION.sha256` como **último** paso con `sha256sum -c` en verde; `logs/`, `run/`, `INFORME.md`,
`PROGRESO.md`, `HORAS.log` con `date -Is` real). **Un solo ejecutor: prohibido lanzar subagentes o forks.**
Procesos largos en segundo plano con PID y log en `PROGRESO.md` **antes** de esperarlos. Sin procesos huérfanos
al terminar. Nada fuera de la zona; sin git; sin secretos; ningún `Ok` ficticio; si una prueba falla, se informa.
**Un criterio de superación mira el resultado exigido, no un síntoma parecido**, y **cada escenario se ejecuta
como está escrito** (en W06d6 la partición PoST se hizo desde el génesis y probó otro escenario).
