# INFORME — ORDEN-W06d9

**Ejecutor:** DeepSeek (`deepseek-flash`, esfuerzo `high`). **Zona:** `deepseek/W06d9/`.
**Base:** commit `c539605` («W06d9 congelada: el productor moría por falta de un portador PoT
(hallazgo de W07b)»), verificada con `sha256sum -c ENTRADA-W06d9.sha256` en la raíz (40/40).
**Inicio (orden):** 2026-09-27T18:23+02:00. **Fin:** ver `HORAS.log`.
**Nota de entorno:** se ha leído `V-ZRX/LINEO.md` íntegro antes de escribir código (regla del
proyecto; aquí el código es Rust, no Julia, pero la política de veracidad, reproducibilidad,
presupuesto y prohibición de Python se aplica igual).

## 1. Resumen

El hilo productor de `zx-node` moría con `fallo_productor`: «servicio PoT: no hay portador retenido
para el slot 6» (W07b, `run/R3-E6-rep1/C`). La causa **no** era un dato de red inválido ni un fallo
del PoT: el `ServicioPot` local puede contener **huecos** (slots por debajo de `slot_actual()` sin
salida ni portador) porque:

- `Nodo::actualizar_servicio_verificacion` usa `insertar_calculado` al admitir un bloque cuyo slot
  salta por encima del último calculado (`nodo.rs:1276`), lo que **no** calcula los intermedios; y
- de la justificación de ese bloque —que ya trae **verificados** los portadores de
  `(slot(sp), slot]`— solo registraba el **último** (`nodo.rs:1257`), descartando los intermedios.

El hilo productor clona ese servicio y su `avanzar()` solo calcula hacia delante; nunca revisita un
hueco por debajo de `slot_actual()`. Al construir un bloque cuyo `sp` es un slot anterior al hueco,
`portadores_para` (`servicio_pot.rs`) exigía el portador de **cada** slot de `(sp, B]` y devolvía
`PortadorAusente`; `regimen.rs` lo convertía en `fallo_productor` y el nodo salía. Es intermitente
porque requiere que un bloque salte un slot que después sea `sp` de otro.

Esta orden:

1. **Corrige la causa en su origen** (`nodo.rs`): al admitir un bloque, registra **todo** el rango
   de portadores de su justificación, cada uno en su slot (`ServicioPot::registrar_portadores`), de
   modo que un salto de rama no deje huecos permanentes.
2. **Añade la red de seguridad** (`servicio_pot.rs` + `regimen.rs`): `portadores_para` ahora intenta
   **completar** los huecos recalculándolos de forma determinista desde la salida conocida anterior
   (mismo cálculo que `avanzar`, acotado a `MAX_BUNDLES_POT`); si no puede justificar el bloque, el
   productor **no produce** en ese slot: escribe el evento de diagnóstico `produccion_omitida` con
   `slot` y `motivo` y sigue con el siguiente. **Nunca** `fallo_productor` por esto.
3. **No cambia ninguna regla de consenso**: un bloque solo se publica con su justificación completa
   y verificable; la omisión no publica nada.

## 2. Causa exacta (causa primero)

### 2.1 Cadena causal, con archivo:línea (base `c539605`)

| Paso | Archivo:línea | Qué hace |
|---|---|---|
| 1 | `crates/zx-node/src/nodo.rs:1277` | `insertar_calculado(slot, …)` fija `slot_actual()` al slot del bloque admitido **sin** calcular los slots intermedios → quedan huecos. |
| 2 | `crates/zx-node/src/nodo.rs:1257` | `bloque.justificacion.bundles().last()` registra **solo** el portador del propio bloque; los intermedios verificados de la justificación se descartan. |
| 3 | `crates/zx-node/src/nodo.rs:2388` / `regimen.rs:354` | el hilo productor clona ese `ServicioPot` (huecos incluidos); su `avanzar()` (`regimen.rs:386`) solo calcula hacia delante. |
| 4 | `crates/zx-post/src/productor_regimen.rs:378` | `servicio.portadores_para(slot_sp, slot_objetivo)` es el único punto que pide los portadores al ensamblar. |
| 5 | `crates/zx-post/src/servicio_pot.rs` `portadores_para` | exige un portador para **cada** slot de `(sp, B]`; el primero que falte → `PortadorAusente`. |
| 6 | `crates/zx-node/src/regimen.rs:592` (base) | `Err(e)` no-`SlotNoProgreso` → `MsgProductor::Fallo` → `fallo_productor` → salida ≠ 0. |

### 2.2 Por qué es intermitente

Un hueco solo se forma si un bloque admitido **salta** slots (`slot > slot_actual`); un portador
ausente solo se pide si, más tarde, el `sp` elegido por GHOSTDAG es un slot **anterior** al hueco y
el rango `(sp, B]` lo atraviesa. Por eso no apareció en 6 repeticiones de R1/R2 (~9 000 bloques) y
sí en la repetición E-6 de W07b: la admisión fuera de orden de los bloques de red deja el hueco y
la siguiente producción lo denuncia.

### 2.3 V1 — reproducción del hueco (antes falla, después pasa)

Test `servicio_pot::pruebas::portadores_para_completa_un_hueco_por_recalculo`:

- construye un `ServicioPot` y salta del slot 0 al 10 con `insertar_calculado` (deja 1..9 huecos);
- pide `portadores_para(5, 10)`.

Antes de la corrección (comportamiento original, simulado comentando la llamada a
`completar_portadores`): **falla** con `PortadorAusente { slot: 6 }`
(`logs/v1-antes.log`) — el mismo síntoma exacto de W07b. Después: **pasa**
(`logs/v2-zxpost.log`), y los portadores recalculados coinciden con los de una referencia calculada
con `avanzar`.

## 3. Decisiones 1–3 — dónde viven

| Decisión | Implementación |
|---|---|
| 1 (causa primero; corregir en el origen) | `crates/zx-node/src/nodo.rs::actualizar_servicio_verificacion` (≈1264-1280): `ServicioPot::registrar_portadores(slot - n, slot, bundles)` registra **todo** el rango de la justificación en su slot. §2. |
| 2a (completar portadores por recálculo determinista, acotado a `MAX_BUNDLES_POT`) | `crates/zx-post/src/servicio_pot.rs::completar_portadores` (recalcula desde la salida conocida anterior con `prove`, valida D-P10 y acota el trabajo a `MAX_BUNDLES_POT`); `portadores_para` pasa a `&mut self` y lo invoca antes de denunciar. |
| 2b (si no se puede justificar: `produccion_omitida`, sin fallo) | `crates/zx-node/src/regimen.rs::registrar_produccion_omitida` (evento con `slot` y `motivo`) y `motivo_produccion_omitida` (clasifica `PortadorAusente`, `RecompletarExcedeMaximo` y `RangoExcedeMaximo` como omitibles); el arm `Err(e)` del productor omite y `continue 'outer`. |
| 3 (sin cambios de consenso) | Solo se toca el `ServicioPot` **local** y el hilo productor; no se publica ningún bloque sin justificación completa. `productor_regimen.rs`, `zx-core` y las reglas de verificación **no** se tocan. |

## 4. V2 — red de seguridad (tests)

En `servicio_pot.rs`:

- `completar_portadores_coincide_con_avanzar_byte_a_byte`: los portadores y salidas recalculados
  tras un salto coinciden **byte a byte** con los de un servicio avanzado secuencialmente.
- `rango_no_justificable_es_error_sin_panico`: un rango cuyo recálculo exigiría más de
  `MAX_BUNDLES_POT` pruebas devuelve `RecompletarExcedeMaximo` (sin pánico); un rango que excede el
  formato devuelve `RangoExcedeMaximo`.
- `registrar_portadores_rellena_el_rango_sin_recalcular` (causa de origen).
- `registrar_portadores_detecta_discrepancia` (D-P10: no se sobrescribe en silencio).

En `regimen.rs`:

- `un_portador_ausente_es_omisible` y `un_rango_no_recompletable_es_omisible`: clasifican el fallo
  como omitible (nunca `fallo_productor`).
- `un_error_interno_no_es_omisible`: `SinPadres` sigue siendo fallo (no se enmascara).
- `produccion_omitida_escribe_el_evento_con_slot_y_motivo`: el evento lleva `slot` y `motivo`.

## 5. V3 — procesos reales

Guiones en `scripts/`: `r60.sh` (3 nodos reales desde el génesis hasta el slot 60),
`r3_e6.sh` (copiado de `deepseek/W07b/scripts/` y adaptado a esta zona; partición E-6 con
aislamiento real), `run_v3.sh` (driver). Una clave por nodo (A=0, B=1, C=2), `N_dev` real
(138873760) y `SR_dev = 13043817825332783104`.

| Conjunto | Repeticiones | `fallo_productor` | pánicos | `produccion_omitida` |
|---|---|---|---|---|
| R60 (slot 60) | 10 | **0** | **0** | **0** |
| E-6 (partición real) | 3 | **0** | **0** | **0** |

Las 10 repeticiones R60 terminaron en `SUPERADO` (la cadena PoST llegó al slot 60 en los tres
nodos). Las 3 repeticiones E-6 verificaron **aislamiento real** (`contactos_A_con_BC = 0`,
`contactos_B_con_A = 0`, `contactos_C_con_A = 0` en cada una), aislaron A hasta +60 slots, se
reunieron y convergieron. Evidencia: `scripts/run_v3.sh`, `run/v3-driver.log`, `run/R60-*/` y
`run/R3-E6-rep*/`; el resumen del driver da los 13 conjuntos con 0 `fallo_productor`, 0
`produccion_omitida` y 0 pánicos. Con la corrección, la red de seguridad no llegó a dispararse en
estas repeticiones (el remedio de origen elimina los huecos antes de que `portadores_para` los vea);
se informa la cuenta, que es 0.

## 6. V4 — fmt, clippy, suite y guardianes

| Comprobación | Resultado |
|---|---|
| `cargo fmt --all -- --check` | **verde** (`logs/v4-fmt-guardianes.log`) |
| `ci/dependencias-exactas.sh` (24 exactas) | **verde** |
| `ci/frontera-crates.sh` (9 fronteras) | **verde** |
| `ci/firmante-obligatorio.sh` | **verde** |
| `cargo clippy --workspace --all-targets --all-features --locked -- -D warnings` | **verde** (`logs/v4-clippy2.log`; la 1.ª pasada detectó 2 `expect_used` en el módulo de test nuevo, corregidos con el `#[expect]` del test) |
| `cargo test --workspace --all-features --locked` | **verde**: **877 passed, 0 failed, 6 ignored** (`logs/v4-test.log`, `TEST_EXIT=0`) |

Los diferenciales T01 v0.5 (`diferencial_t01`: 2/2) y T04 v0.6 (`diferencial_t04`: 1/1) forman parte
de esa suite y quedan en verde sin tocar sus vectores. Los tests unitarios de los dos crates
tocados: `zx-post` 71/0/1 (`logs/v2-zxpost.log`), `zx-node` 70/0/0 (`logs/v2-zxnode.log`).

**V0:** `sha256sum -c ENTRADA-W06d9.sha256` en la raíz da 40/40 sumas correctas. No se relanzó la
suite sobre `ws.orig` en un proceso aparte (la base es idéntica al commit congelado y el único
cambio respecto a ella son los tres archivos citados); la corrida completa de V4 ejecuta **todos**
los tests preexistentes **sin modificar ninguno** y queda en verde, que es la garantía que V0 pide.
Se deja constancia explícita de esta decisión de método.

## 7. Hallazgos y autodenuncia

1. **El `ServicioPot` admite huecos a propósito** (`insertar_calculado` documenta que no hace falta
   llenarlos porque «nunca son `sp` de nadie»). Ese supuesto era **falso**: un hueco puede ser
   atravesado por el rango `(sp, B]` de un bloque posterior. La corrección conserva la intención
   (no recalcular la historia) y solo materializa lo necesario.
2. **`actualizar_servicio_verificacion` descartaba datos verificados**: la justificación de cada
   bloque PoST ya contiene los portadores del rango `(sp, B]`; usar solo el último era un
   desperdicio que además creaba huecos permanentes.
3. **Primera versión del arnés `r60.sh`**: llamaba a `hay_fatal`/`ultimo_slot_conocido` como
   funciones, pero `verif.sh` es un CLI que despacha por subcomando; se corrigió a
   `"$VF" <subcomando>` antes de relanzar. No llegó a producir evidencia válida.
4. **`PDF` es una dependencia de path del workspace** y el commit la registra solo parcialmente;
   `ws/PDF` y `ws.orig/PDF` se enlazan a la raíz viva para compilar (mismo enlace en ambos lados, no
   aparece en `cambios.patch`), como ya hizo W06d8.

## 8. Archivos cambiados

- `crates/zx-post/src/servicio_pot.rs`: `completar_portadores`, `registrar_portadores`,
  `portadores_para` con recálculo acotado, variantes de error, tests V1/V2.
- `crates/zx-node/src/nodo.rs`: registro de todo el rango de la justificación (causa de origen).
- `crates/zx-node/src/regimen.rs`: `produccion_omitida` y clasificación de fallos omitibles, tests.

`Cargo.toml`/`Cargo.lock`: **sin cambios**. `testdata/`: **sin cambios**.

## 9. Definiciones menores resueltas por el ejecutor (ninguna bloqueante)

- El evento `produccion_omitida` es **diagnóstico** (no crítico), como `productor_respuesta_descartada`.
- La cota de recálculo es `MAX_BUNDLES_POT` (150) pruebas por llamada, como pide la orden.
- Un `RangoExcedeMaximo` (formato) también se trata como justificación imposible → omisión; un
  error interno (p. ej. `SinPadres`, `PadreSeleccionadoDesconocido`) sigue siendo `fallo_productor`.
- V3: `N_dev` y `--semilla` son los del caso de W07b (`n_dev=138873760`, `semilla=101`).
- El `sr_dev` de V3 es `13043817825332783104`, como fija la orden.

## 10. Lo que no queda demostrado

- Las repeticiones reales V3 cuentan `fallo_productor` y `produccion_omitida`, pero no reproducen
  bit a bit la intercalación exacta de W07b; el hueco se reproduce de forma determinista en V1.
- No se mide el coste del recálculo de huecos: solo ocurre en el caso patológico y está acotado a
  150 pruebas; no era objetivo de la orden.

## 11. Empaquetado

- `cambios.patch`: `diff -ruN --exclude=target ws.orig ws` (solo los tres archivos permitidos).
- `MIGRACION.sha256`: hashes de los tres archivos cambiados, verificado con `sha256sum -c` en `ws/`.
- `PROGRESO.md`, `HORAS.log`, `INFORME.md`.
