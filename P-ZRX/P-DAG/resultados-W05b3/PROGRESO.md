# PROGRESO — ORDEN-W05b3

**Zona:** `/home/katana/zeo/ZEROX/deepseek/W05b3/`. **Ejecutor:** DeepSeek. **Fecha:** 2026-09-26.
**Presupuesto:** 2 h, 8 hilos, 16 GiB, 40 GiB de disco. Prohibido Python.

## 0. Pregunta falsable

«Un DAG de bloques PoST producidos por el productor en régimen (cadenas, hermanos del mismo slot y
bloques de fusión con varios padres) es aceptado íntegro por la puerta conjunta de W05b2 con
contextos reales derivados de `zx-dag` y del servicio PoT; y cada alteración de la lista negativa
§4 V5 es rechazada o queda pendiente con el motivo exacto.»

## 1. Entradas leídas íntegras

`ORDEN-W05b3.md`; `V-ZRX/LINEO.md`; `P-ZRX/P-DAG/DECISIONES-W05.md` (D-P07…D-P13);
`P-ZRX/P-RED-DEV/PERFIL-DEV-v0.md`; `P-ZRX/P-FORMATO/FORMATO-v0.md` (con v0.1);
`P-ZRX/P-DAG/REVISION-W05b2.md`; `P-ZRX/P-REVISION-CODIGO/REVISION-RI-1b.md`; y el código de
`crates/zx-post/` y `crates/zx-dag/` de la raíz.

`ENTRADA-W05b3.sha256`: `sha256sum -c` 7/7 al inicio (`logs/entrada-inicio.log`).

## 2. Faltas de definición (informadas antes de editar)

En `logs/V0-faltas-de-definicion.md`, con la interpretación declarada de cada una: (1)
`InstantaneaPot::pasado()` no se deduce del estado PoT → `registrar_validado`; (2) composición del
cuerpo que recibe el productor; (3) semántica exacta de «slot objetivo»; (4) `N_dev` duplicado en
parámetros y servicio; (5) dónde se rechaza F-17 (fuera de `zx-post`); (6) dónde se rechazan >15
padres y no canónicos (formato `zx-core`); (7) `ContextoRangoDag` sigue siendo la constante dev;
(8) la frontera de `zx-post` ya estaba en `ci/frontera-crates.sh`.

## 3. Base y línea de partida

- Base: raíz tras W02b (8 crates: `zx-core`, `zx-pot`, `zx-consensus`, `zx-dag`, `zx-poas`,
  `zx-farmer`, `zx-post`, `zx-p2p`), copiada a `ws.orig/`; `ws/` = copia de trabajo; enlace
  `ws/PDF` a la raíz.
- Caché: `.cargo-home` y `target` copiados de `deepseek/W05b2R`; `CARGO_BUILD_JOBS=8`,
  `RUST_TEST_THREADS=8`, `GIT_CEILING_DIRECTORIES` en la zona (`env.sh`).
- Línea base `cargo test --list` en `ws.orig`: **631 tests** (`logs/raiz-test-list.log`).

## 4. Trabajo realizado

1. **H2 de RI-1b.** `ContextoTransicion::nuevo` devuelve
   `ErrorContextoTransicion::SalidaDeSlotDiscrepa { slot, primera, otra }` cuando dos registros
   validados del mismo slot traen `salida` distinta (antes `or_insert` lo ocultaba). Test
   `salidas_distintas_del_mismo_slot_se_rechazan` (incluye el ancla del terminal y los hermanos
   con la misma salida).
2. **`servicio_pot.rs`.** `ServicioPot`: arranca de S1 en el terminal, avanza un slot por llamada
   con `N_dev` (flujo único, sin inyecciones, `D = 0`), guarda salidas y portadores de una ventana
   acotada y configurable (error explícito fuera de ella), registra el pasado validado con
   `registrar_validado` e implementa `InstantaneaPot`. Lógica pura, sin hilos propios. Tests
   internos (parámetros inválidos, cadena contra `zx_pot::prove`, ventana, portadores, registro,
   instantánea).
3. **`productor_regimen.rs`.** `producir_en_regimen(padres, slot_objetivo, servicio, fuente, clave,
   parametros, cuerpo)`: exige `slot > slot(sp)` y `d ≤ 150`, avanza el servicio, audita la fuente
   en el slot exacto, arma la justificación `(slot(sp), slot(B)]`, la coinbase v3 con el slot del
   bloque (F-17), el compromiso del cuerpo y el sello. `CuerpoProductor` (sin coinbase) con
   validación de descuadre y coinbase. Tests internos.
4. **`tests/regimen.rs`.** V4.1 cadena de 8; V4.2 hermanos + fusión; V4.3 fusión de 3 ramas;
   V4.4 hueco de 150; V4.5 cuerpo con tx extra; V5.1–V5.10 negativos; V6 (ignorado) con `N_dev`
   real. `ContextoDag` = `AlmacenGhostdag` real; `InstantaneaPot` = `ServicioPot`; fuente =
   `ParcelaDisco` real. Los tests **buscan** el slot con solución (la densidad no es 1 por slot),
   sin mocks: la solución usada es la que verifica la puerta.

## 5. Verificación (cerrada)

| Paso | Resultado |
|---|---|
| V1 `fmt --check` | exit 0 (`logs/V1-fmt.log`) |
| V2 `clippy -D warnings --locked` (workspace, all-targets) | exit 0 (`logs/V2-clippy.log`) |
| V3 `cargo test --workspace --all-features --locked` | **655 pasan, 0 fallan, 2 ignorados**; 631 nombres previos, **0 perdidos**, 26 añadidos (`logs/V3-test.log`, `logs/nombres-*.txt`) |
| V4 escenarios positivos | 5/5 `Comprobada` (`logs/regimen-debug.log`) |
| V5 negativos | 10/10 con su motivo (`logs/regimen-debug.log`) |
| V6 `N_dev` real en release | 3/3 `Comprobada`; producción 1,852/1,434/1,433 s; verificación 0,066 s/bloque (`logs/V6-medicion-real.log`) |
| V7 `dependencias-exactas.sh`, `frontera-crates.sh`, lock | OK; lock **idéntico** a `ws.orig` (`logs/V7-*.log`) |

Detalle de la 2.ª pasada de V3 (árbol final): `logs/V3-fin.log` = 2026-09-26T04:50:27+02:00, exit 0.
La primera pasada de V6 medía la producción sin el avance PoT (el slot se buscaba antes del
temporizador); se corrigió y la medida publicada es la segunda (`logs/V6-medicion-real.log`).

## 6. Límites declarados

Lo que esta orden **no** demuestra: estado, garantía de la clave, admisión en el nodo, red, sesgo
de la semilla (A-07), seguridad de los parámetros dev (`N_dev`, `SR_dev`, S1), ni el controlador
de rango (D-P11). `producir_en_regimen` no elige padres ni decide garantía: eso es del nodo.
