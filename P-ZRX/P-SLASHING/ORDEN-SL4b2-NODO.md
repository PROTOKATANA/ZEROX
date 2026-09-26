# ORDEN-SL4b2 — Castigo activo en la red dev: firmante seguro, detección de doble firma y envío de `EvidenceTx` en el nodo

**LINEO (`V-ZRX/LINEO.md`) rige este código Rust** (`AUTO-ZRX.md` §52: todo el código del proyecto, tests y
arneses incluidos); léelo íntegro antes de escribir código y aplica sus reglas pertinentes.

## 1. Identidad y contexto

- **ID:** SL-4b2. **Fecha:** 2026-09-26 (redactada ≈ 23:00; se congela y lanza tras migrar W06d5, SL-4b1 y
  W07a). **Director:** Claude. **Ejecutor:** subagente **Sonnet**, único (integración en el nodo con procesos
  reales, como W06d1…W06d5; `P-ZRX/PLAN-0.0.1.md` D-P06).
- **Zona (única escribible):** `/home/katana/zeo/ZEROX/deepseek/SL4b2/`.
- **Objetivo único:** que la red dev **castigue** la doble firma de extremo a extremo con las reglas ya
  implementadas en el motor y en `zx-cadena` (SL-4a), y que el productor honesto no firme dos veces
  (firmante seguro de SL-4b1).
- **Pregunta falsable:** «Con tres nodos reales tras el corte, si un tercero que posee la clave dev 0 publica
  una segunda cabecera con la misma identidad RAT-1 que un bloque de esa clave, en menos de `Plazo_slots`
  los tres nodos aplican una `EvidenceTx` que confisca la garantía de la clave 0 según RAT-2′ y convergen al
  mismo estado; y sin ese tercero, ni diez `SIGKILL` al productor ni la pérdida de su registro provocan una
  sola doble firma.»
- **Desbloquea:** IPA C-09 y C-11; W07b (escenario E-8 con castigo).

## 2. Autoridad y entradas (congeladas en `P-ZRX/P-SLASHING/ENTRADA-SL4b2.sha256`)

`P-ZRX/P-SLASHING/CONTRATO-EVIDENCIA-v0.md` (§2–§9 y **«Ratificación v0», que prevalece**),
`P-ZRX/P-SLASHING/DECISIONES.md`, `P-ZRX/P-SLASHING/REVISION-SL2b.md`, `REVISION-SL4a.md`,
`REVISION-SL4b1.md` (la escribe el director al migrar SL-4b1), `P-ZRX/P-MEDICION/ESQUEMA-REGISTRO-v1.md`
(eventos `evidencia_*`, `firmante_abstenido`), `P-ZRX/P-RED-DEV/PERFIL-DEV-v0.md`, `P-ZRX/P-NODO/PLAN-W06.md`
y las órdenes y revisiones W06d1…W06d5 y W07a. Código: la raíz en el commit que indique la entrada.

## 3. Decisiones del director (no las cambies; si una no se puede cumplir, para e informa)

1. **Activación en el perfil dev** (`crates/zx-node/src/perfil.rs`): `ParametrosEvidencia { f = 1/1,
   plazo_slots = 300, m_margen_slots = 60, cbid = CBID_RED_DEV, evp = true }` y **`R_SLOTS = 600`** (antes
   60; `= F_SLOTS`, recomendación de SL-2b «`R_slots ≥ F_slots`»; puerta RAT-3: `600 > 300 + 60`). El nodo
   usa `Cadena::nueva_con_evidencia` y **se niega a arrancar** si la puerta RAT-3 no se cumple (test con un
   perfil de prueba que la incumple). `q` sigue en 10 ZZK (el `q = 20` de SL-2b es una unidad del modelo, no
   ZZK; la red dev no reivindica disuasión). Busca y enumera en el informe los tests que dependían de
   `R_SLOTS = 60`. Motivo de `Plazo_slots = 300`: en `localhost` la segunda cabecera llega en menos de un slot,
   pero un nodo que reinicia (E-4) o llega tarde (E-5) tiene que poder incluirla todavía; 300 slots son de 2,5
   a 8 minutos según `N_dev`.
2. **Firmante seguro en el productor:** el nodo produce **solo** con las funciones `_con_firmante` de
   SL-4b1; las funciones antiguas que firman sin registro dejan de ser alcanzables desde `zx-node` (quítalas
   de la API pública de `zx-post` o márcalas `#[cfg(test)]`, lo que menos código toque). Registro único por
   nodo en `<datos>/firmante.registro`. **`Registro::nueva` solo en el arranque limpio** (directorio de datos
   creado por este proceso); en todo reinicio, `Registro::abrir(ruta, slot_actual, 150)` con
   `slot_actual = máx(slot más alto de los bloques del almacén, slot PoT reconstruido)` y `S_max_slots = 150`
   (`zx-core/src/wire_dag.rs`). Registro corrupto (FIR-08) o envenenado (FIR-07): el nodo **no produce**
   (evento `firmante_abstenido`, motivo en texto) pero sigue validando y propagando. Cada abstención escribe
   `firmante_abstenido` (esquema v1).
3. **Detector de doble firma** (módulo nuevo `crates/zx-node/src/evidencia.rs`): indexa por identidad RAT-1
   la **primera** cabecera PoST vista cuya puerta conjunta (sello, PoT, PoAS, padres) pasó, **con
   independencia** de que la admisión posterior (GHOSTDAG, estado) la acepte o la rechace, incluidos los
   bloques propios y los huérfanos una vez resueltos. Una segunda cabecera con la misma identidad y otro
   `pre_hash` produce una `EvidenceTx` v4 en orden canónico, un evento `evidencia_detectada` y una entrada en
   la lista de pendientes (clave: `incident_id`). Poda: entradas con `slot < slot_actual − plazo_slots`.
   Tope explícito `MAX_IDENTIDADES_DETECTOR = 65 536` (desalojo por slot más antiguo, evento
   `limite_alcanzado`). **No** se indexan cabeceras cuya puerta conjunta falla: la evidencia de consenso no lo
   exige (EV-08), pero el detector solo guarda lo que costó una prueba PoAS real (evita que un par llene la
   memoria con sellos de su propia clave sobre cabeceras inventadas).
4. **Envío:** sin relevo de transacciones en 0.0.1, cada nodo **incluye sus propias** evidencias: al producir
   un bloque PoST, mete hasta `MAX_EVIDENCIAS_POR_BLOQUE = 4` pendientes cuyo incidente no esté procesado en
   el estado sobre el que construye y cuya ventana esté abierta en el slot del bloque
   (`slot_falta ≤ slot < slot_falta + plazo_slots`); evento `evidencia_incluida`. Una pendiente sale de la
   lista cuando el incidente aparece procesado en el estado virtual o cuando su ventana cierra; si el bloque
   que la llevaba sale de la cadena seleccionada, vuelve a ser elegible. Evidencia contra una clave propia:
   se trata igual y además se registra `evidencia_detectada` con `propia: true` (sería FP6, clave compartida).
5. **`zx-adversario doble-firma`** (subcomando nuevo del binario de pruebas existente, **no** un modo del
   nodo): se conecta a un nodo, espera un bloque PoST producido por la clave dev de índice `--clave-indice`
   (la deriva con la misma función que `zx-node/src/claves.rs`), construye una segunda cabecera **idéntica
   salvo `timestamp + 1`**, la vuelve a sellar con esa clave, verifica localmente que la identidad RAT-1
   coincide y el `pre_hash` no, y publica el bloque. Con `--repetir` publica además una tercera cabecera
   (`timestamp + 2`) del mismo billete, para probar la deduplicación (EV-12).

## 4. Contrato de implementación

- **Archivos que puedes crear o modificar** (en `ws/`): `crates/zx-node/**`, `crates/zx-post/src/{lib.rs,
  productor.rs, productor_regimen.rs}` (solo para retirar del alcance del nodo las funciones sin firmante),
  tests nuevos. **Vedado:** `zx-core`, `zx-consensus`, `zx-cadena`, `zx-dag`, `zx-storage`, `zx-p2p` (si
  necesitas una API de lectura nueva en `zx-cadena` —p. ej. «¿está procesado este incidente en el estado de
  esta punta?»— **para** y pídela con su firma exacta), `Cargo.lock` sin versiones nuevas.
- Ningún `unwrap` fuera de tests; errores explícitos; el nodo no entra en pánico por nada que llegue de un par.

## 5. Modelo de amenaza

Cubre: doble firma de una clave usada en dos sitios (FP1, FP6: dos máquinas, clave compartida o robada),
publicada en la red; reinicios y pérdida del registro del productor honesto. **No** cubre (se declara):
doble firma en una rama privada que nunca se publica (RFT-01, B-04); evidencia censurada por todos los
productores de la ventana (SL-2b: la región se vacía con `c = 1`); cabeceras con PoAS inválida (no se
indexan, decisión 3); dos máquinas con la misma clave y sin tercero que publique (se detecta en cuanto las
dos se publican). El castigo de la red dev **no** es una afirmación de disuasión (parámetros dev).

## 6. Plan de verificación

| Paso | Qué | Criterio |
|---|---|---|
| V0 | `sha256sum -c` de la entrada; suite completa de la raíz sin cambios | verde; si no, para |
| V1 | Tests unitarios del detector: misma identidad y otro `pre_hash` → una evidencia en orden canónico que pasa `validar_forma_tx_v4`; misma cabecera dos veces → nada; cada uno de los seis campos de RAT-1 distinto → nada; poda por ventana; tope y desalojo; tercera cabecera → ninguna evidencia nueva del mismo incidente | cada caso con su aserción |
| V2 | Inclusión: pendiente con ventana abierta → incluida; ya procesada en el estado base → no; ventana cerrada → no y sale de la lista; bloque portador reorganizado fuera → vuelve a ser elegible | cada caso |
| V3 | Puerta RAT-3 en el arranque (perfil que la incumple → el nodo no arranca, con mensaje) y `R_SLOTS = 600` | test |
| V4 | **Extremo a extremo con procesos reales** (`127.0.0.1`, tres nodos A, B, C con claves 0, 1, 2, `N_dev` reducido declarado): tras ≥ 20 bloques PoST, `zx-adversario doble-firma --clave-indice 0 --repetir`. Se exige, con los registros conservados: `evidencia_detectada` en B y C; una `EvidenceTx` incluida y aplicada antes de `slot_falta + 300`; la garantía de la clave 0 confiscada entera (`f = 1`: `C = V`), `suelo(C·2/8)` a la coinbase del incluidor y el resto quemado, leído del estado de **los tres** nodos; mismo `resumen_estado` final en los tres; la segunda evidencia del mismo incidente descartada sin invalidar su bloque; A no produce mientras su garantía activa sea menor que `q` (decisión 1 de W06d5; si el nodo vuelve a depositar, se registra cuándo) y B y C siguen produciendo | todo, en 3 repeticiones con semillas distintas |
| V5 | **Honesto sin castigo:** tres nodos en régimen; 10 `SIGKILL` a A en momentos aleatorios (semilla registrada) con reinicio inmediato; al final, **0** eventos `evidencia_detectada` en B y C y 0 pares de bloques de la clave 0 con el mismo slot en el DAG | 0 y 0 |
| V6 | **Pérdida del registro:** con A parado, borra `firmante.registro` (conserva el almacén) y rearranca: `firmante_abstenido` con motivo de pérdida durante exactamente 150 slots desde `slot_actual`, luego produce; 0 evidencias en B y C | exacto y 0 |
| V7 | `fmt --check`, `clippy --workspace --all-targets --all-features --locked -- -D warnings`, `cargo test --workspace --all-features --locked` (todo lo previo con su nombre + lo nuevo), `ci/dependencias-exactas.sh`, `ci/frontera-crates.sh`; y **regresión con procesos reales** de V4, V5, V6b y V7 de W06d5 con la evidencia activa | limpio; mismas conclusiones que W06d5 |

**Tabla de cobertura** (lección de método 1) en el informe: por tipo de evento y resultado del detector y del
firmante (`evidencia_detectada`, `evidencia_incluida`, descarte por repetición, ventana cerrada,
`firmante_abstenido` por conflicto y por pérdida, `Reemitido`), **mínimo 1** por fila en las pruebas con
procesos reales o en los unitarios, indicando cuál.

**Prohibido Python.** Presupuesto: **4 h, 8 hilos, 16 GiB**. Si se agota, entrega lo hecho y lo que falta.

## 7. Entregables y límites

Patrón de las órdenes W (`ws.orig/`, `ws/` con `Cargo.toml`, `Cargo.lock`, `rust-toolchain.toml`,
`crates/`, `testdata/`, `ci/`, `.github/` y el enlace `ws/PDF`; `cambios.patch` y `MIGRACION.sha256` como
**último** paso con `sha256sum -c` en verde; `logs/`, `run/`, `INFORME.md`, `PROGRESO.md`, `HORAS.log` con
`date -Is` real). **Un solo ejecutor: prohibido lanzar subagentes o forks.** Procesos largos en segundo plano
con su PID y su log anotados en `PROGRESO.md` **antes** de esperarlos; al retomar tras un corte, lee primero
`PROGRESO.md`. Sin procesos huérfanos al terminar. Nada fuera de la zona; sin git; sin secretos; ningún `Ok`
ficticio ni test ignorado sin motivo. Si una prueba falla, se informa sin ocultarla.
