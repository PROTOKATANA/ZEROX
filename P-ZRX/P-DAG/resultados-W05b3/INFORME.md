# INFORME — ORDEN-W05b3

**Productor PoST en régimen y servicio PoT local**

**Zona:** `/home/katana/zeo/ZEROX/deepseek/W05b3/` · **Ejecutor:** DeepSeek (`deepseek-flash`,
esfuerzo `high`) · **Director:** Claude · **Fecha:** 2026-09-26 ·
**Base:** raíz tras W02b (`ws.orig/`) · **Entrada congelada:** `ENTRADA-W05b3.sha256`, 7/7 al inicio
(`logs/entrada-inicio.log`) y al cierre (`logs/entrada-final.log`).

## 1. Veredicto

**SUPERADO.** Un DAG de bloques PoST producidos por `producir_en_regimen` —cadena de 8 bloques,
hermanos del mismo slot, fusiones de 2 y 3 ramas y hueco de 150 slots— es **`Comprobada`** por la
puerta conjunta de W05b2 con `ContextoDag` = `AlmacenGhostdag` real, `InstantaneaPot` =
`ServicioPot` real y fuente = `ParcelaDisco` real. Los 10 negativos de §4 V5 se rechazan (o quedan
`Pendiente`) con su motivo exacto, y el `H2` de RI-1b queda cerrado con error explícito. **Ningún
test previo se perdió** (631 → 657 nombres; 0 perdidos, 26 añadidos; 655 pasan, 0 fallan, 2
ignorados).

## 2. Faltas de definición (informadas antes de editar)

`logs/V0-faltas-de-definicion.md`, 8 puntos con la interpretación declarada. Los que más afectan al
diseño:

1. `InstantaneaPot::pasado()` no se deduce del estado PoT ⇒ `ServicioPot::registrar_validado`
   declara el pasado validado (el servicio no inventa hashes).
2. El cuerpo que recibe el productor: transacciones **sin** la coinbase y sus testigos; el
   productor antepone la v3. Una coinbase en la lista es `ErrorCuerpo::CoinbaseEnCuerpo`.
3. «Slot objetivo» = slot **exacto** del bloque; los tests buscan el slot con solución.
4. `N_dev` duplicado ⇒ `ErrorRegimen::NDevDiscrepante` si parámetros y servicio difieren.
5. F-17 se rechaza en `zx-consensus` (`aplicar_coinbase_post`, `aplicar.rs:370-373`), no en la
   puerta conjunta; se demuestra con un test real sobre `aplicar`.
6. `> 15` padres y extras no canónicos se rechazan en el formato de `zx-core`.

## 3. API nueva de `zx-post` (módulos nuevos; `producir` de W05b2 intacto)

### 3.1 `servicio_pot` (`ServicioPot`)

| Elemento | Firma / comportamiento |
|---|---|
| `nuevo(terminal, n_dev, ventana)` | arranca en S1 (`blake3(block_hash(T))[0..16)`), `f_0 = flujo_genesis(T)`, ventana ≥ 1 |
| `avanzar()` | un slot: `prove(semilla_siguiente(salida_anterior, None), N_dev)`; guarda salida (16 B) y portador (128 B) |
| `avanzar_hasta(slot)` | avanza hasta `slot`; si ya se pasó, `ObjetivoAnterior` |
| `salida_de(slot)` / `portador_de(slot)` | lectura; fuera de ventana → `FueraDeVentana` / `PortadorAusente` |
| `registrar_validado(hash, slot)` | declara un bloque ya validado en `pasado()` (no acredita validez); `BloqueDuplicado` / `SlotFuturo` |
| `portadores_para(sp_slot, b_slot)` | portadores de `(sp_slot, b_slot]`; `RangoInvalido`, `RangoExcedeMaximo`, `SlotFuturo` |
| `impl InstantaneaPot` | `flujo_candidato_en = f_0`, `inyecciones = Ninguna`, `iteraciones = N_dev`, `D = 0`, `salida_validada` del estado (o `ContextoAusente`) |

Lógica pura, **sin hilos propios**; memoria acotada por `ventana` (salidas + portadores + pasado;
el ancla S1 del terminal es constante y no ocupa entrada).

### 3.2 `productor_regimen` (`producir_en_regimen`)

```
producir_en_regimen(padres: PadresDag, slot_objetivo: u64, servicio: &mut ServicioPot,
                    fuente: &F, clave: &SigningKey, parametros: &ParametrosProductor,
                    cuerpo: CuerpoProductor) -> Result<BloqueDag, ErrorRegimen<F::Error>>
```

No elige padres ni garantía. Exige `slot_objetivo > slot(sp)` (`SlotNoProgreso`) y
`d ≤ MAX_BUNDLES_POT = 150` (`RangoExcedeMaximo`), avanza el servicio, audita **solo** el slot
objetivo, arma la justificación `(slot(sp), slot(B)]` con `D = 0` (`pot_output = salida(slot(B))`),
la coinbase v3 **con el slot del bloque** (F-17), `height = 0` (F-03), el compromiso del cuerpo y el
sello. Errores: `SinPadres`, `NDevDiscrepante`, `PadreSeleccionadoDesconocido`, `SlotNoProgreso`,
`RangoExcedeMaximo`, `Servicio`, `ClaveDeLaSolucionNoCoincide`, `Fuente`, `SinSolucion`, `Formato`.
`CuerpoProductor` valida descuadre y coinbase.

### 3.3 `H2` de RI-1b

`ContextoTransicion::nuevo` devuelve `ErrorContextoTransicion::SalidaDeSlotDiscrepa { slot, primera,
otra }` si dos registros validados del mismo slot traen `salida` distinta (antes `or_insert` lo
ocultaba). Dos hermanos con la **misma** salida siguen siendo válidos.

## 4. Verificación

| Paso | Qué | Resultado |
|---|---|---|
| V1 | `cargo fmt --all -- --check` | exit 0 (`logs/V1-fmt.log`) |
| V2 | `cargo clippy --workspace --all-targets --all-features --locked -- -D warnings` | exit 0 (`logs/V2-clippy.log`) |
| V3 | `cargo test --workspace --all-features --locked` | **655 pasan, 0 fallan, 2 ignorados**; 631 nombres previos, **0 perdidos**, 26 añadidos (`logs/V3-test.log`, `logs/nombres-*.txt`) |
| V4 | cadena de 8, hermanos + fusión, fusión de 3 ramas, hueco de 150, cuerpo extra | `Comprobada` en los 5 (`logs/regimen-debug.log`) |
| V5 | 10 negativos de §4 | cada uno con su motivo (ver §5) |
| V6 | e2e con `N_dev` real (138 873 760) de 3 bloques, release | `Comprobada`; tiempos por bloque en `logs/V6-medicion-real.log` |
| V7 | `dependencias-exactas.sh`, `frontera-crates.sh`, lock | OK; `Cargo.lock` **idéntico** a `ws.orig` (`logs/V7-*.log`) |

## 5. Escenarios

**V4 (positivos, todos con `AlmacenGhostdag` + `ServicioPot` reales):**
`v4_cadena_de_ocho_bloques_en_regimen`, `v4_hermanos_del_mismo_slot_y_fusion`,
`v4_fusion_de_tres_ramas`, `v4_hueco_de_150_slots`, `v4_cuerpo_con_una_transaccion_extra`.

**V5 (negativos, con su motivo exacto):**

| Ataque | Resultado |
|---|---|
| padre seleccionado que no da GHOSTDAG | `Invalida(Padres(PadreSeleccionadoIncorrecto))` |
| > 15 padres | `EncodingError::DemasiadosPadres` (formato) |
| extras no canónicos | `EncodingError::PadresNoCanonicos` (parser) |
| `slot ≤ slot(sp)` | productor `SlotNoProgreso`; puerta `TransicionSinProgresoDeSlot` |
| hueco de 151 | `RangoExcedeMaximo { d: 151 }` |
| checkpoint alterado | `Invalida(Pot(AesFallido))` |
| `pot_output` alterado | `Invalida(Pot(PotOutputNoCoincide))` |
| solución de otra clave | `Invalida(Poas(_))` |
| sello de otra clave | `Invalida(Sello(_))` |
| coinbase v3 con `slot` ≠ bloque | `ErrorTransicion::ErrEmision` en `zx-consensus` (F-17); la puerta no mira el cuerpo (se documenta) |
| padre desconocido | `Pendiente(Padres(PadreNoValidado))` |

## 6. Medida V6 (`N_dev` real, release, 2026-09-26)

Comando: `cargo test -p zx-post --release --test regimen --all-features --locked -- --ignored
--nocapture v6_` (`logs/V6-medicion-real.log`; carga ajena alta: `uptime` en `logs/V6-inicio.log`).
Preparación (historia génesis + 3 parcelas): 9,41 s.

| Bloque | Producción (incluye el avance PoT del slot) | Verificación |
|---:|---:|---:|
| slot 1 | 1,852 s | 0,066 s |
| slot 2 | 1,434 s | 0,066 s |
| slot 3 | 1,433 s | 0,066 s |

Los 3 bloques: `Comprobada`. (La máquina corre W06a/W06b en paralelo; la carga explica el 1,4 s/slot
frente al `N_dev` de 1 s/slot calibrado a carga baja.)

## 7. Lo que esta orden NO demuestra

Estado y garantía de la clave (motor W03/W06), admisión en el nodo, red, sesgo de la semilla
(A-07), seguridad de los parámetros dev (`N_dev`, `SR_dev`, marcador S1) ni el controlador de rango
(D-P11, sigue la constante dev). `producir_en_regimen` no elige padres ni decide garantía: eso es de
`zx-cadena`. La puerta conjunta **no** inspecciona el cuerpo (lo demuestra el negativo de F-17), y
`Comprobada` no es admisión.

## 8. Entregables

| Fichero | Contenido |
|---|---|
| `ws.orig/`, `ws/` | base congelada y árbol de trabajo (6 ficheros cambiados/añadidos, todos en `zx-post`) |
| `cambios.patch` | `diff -ruN -x target -x .cargo-home -x PDF`; aplica limpio y reconstruye `ws` byte a byte |
| `MIGRACION.sha256` | 158 huellas del árbol `ws`; `sha256sum -c` OK |
| `logs/` | entrada, faltas, línea base, V1–V7, comparación de nombres, medida V6 |
| `INFORME.md`, `PROGRESO.md`, `HORAS.log` | este documento, progreso y marcas de tiempo |

Entorno: `CARGO_HOME=<zona>/.cargo-home`, `CARGO_TARGET_DIR=<zona>/target`,
`CARGO_BUILD_JOBS=8`, `RUST_TEST_THREADS=8`, `GIT_CEILING_DIRECTORIES=<zona>`; toolchain pineado
`nightly-2026-05-03`. Sin secretos, sin commit ni push, nada escrito fuera de la zona. Prohibido
Python: no se usó. Presupuesto 2 h / 8 hilos / 16 GiB no agotado.
