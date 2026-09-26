# ORDEN-SL4b1 — Firmante seguro (`C-EVP-06`, FIR-01…FIR-10) portado a `zx-post`, con productores que lo usan

**LINEO (`V-ZRX/LINEO.md`) rige este código Rust** (`AUTO-ZRX.md` §52: todo el código del proyecto, tests
incluidos); léelo íntegro antes de escribir código y aplica sus reglas pertinentes (oráculo o referencia,
casos límite, reproducibilidad, recursos, trazas).

## 1. Identidad y contexto

- **ID:** SL-4b1. **Fecha:** 2026-09-26. **Director:** Claude. **Ejecutor:** DeepSeek (`deepseek-flash`,
  esfuerzo `high`, DeepSeek Harness).
- **Zona (única escribible):** `/home/katana/zeo/ZEROX/deepseek/SL4b1/`.
- **Objetivo único:** portar el firmante seguro del código antiguo al árbol nuevo, adaptado a la identidad de
  RAT-1, y ofrecer variantes de los dos productores PoST que **solo** firman a través de él. La integración en
  el nodo (detección, envío de evidencia, activación, prueba de extremo a extremo) es **SL-4b2**, otra orden.
- **Pregunta falsable:** «Ningún camino de los productores `_con_firmante` escribe el sello antes de que el
  registro haya persistido `(identidad, slot) → pre_hash` con `fsync`; un segundo candidato con la misma
  identidad y otro `pre_hash` nunca se firma, tampoco tras matar el proceso entre la reserva y la firma; y la
  identidad del firmante coincide con la de la evidencia de consenso (RAT-1).»
- **Dependencia que desbloquea:** SL-4b2 (IPA C-09, C-11).

## 2. Autoridad y entradas (congeladas en `P-ZRX/P-SLASHING/ENTRADA-SL4b1.sha256`)

- **Contrato:** `P-ZRX/P-SLASHING/CONTRATO-EVIDENCIA-v0.md` §9 (FIR-01…FIR-15) y su **«Ratificación v0»**
  (RAT-1 prevalece sobre EV-05: la identidad lleva `consensus_branch_id`).
- **Código antiguo (histórico, no normativo; es la fuente del portado):**
  `git -C /home/katana/zeo/ZEROX show 9681061:crates/zx-consensus/src/firmante/{mod,identidad,registro}.rs`
  y sus tests `9681061:crates/zx-consensus/tests/firmante_local.rs` más los `#[test]` de `registro.rs`.
  **No** se porta `alta.rs` ni `tests/alta_firmante_local.rs` (ver §3.5).
- **Prototipo (evidencia de coste y de la prueba de durabilidad con aborto):**
  `/home/katana/zeo/.trash/zerox/P-ZRX/P-FIRMANTE/{prototipo/,informe/INFORME.md,ESPECIFICACION.md}`.
  Clasificación de transferencia: `registro.rs` v3 y `mod.rs` → **adaptar** (identidad RAT-1, ubicación);
  `identidad.rs` → **adaptar** (campo nuevo); `alta.rs` → **no se porta en 0.0.1** (claves dev deterministas);
  prototipo → **fuente de ideas** (prueba de aborto), no se copia.
- **Código nuevo:** raíz en el commit `7810f51` (o el que indique `ENTRADA-SL4b1.sha256`):
  `crates/zx-post/src/{productor.rs, productor_regimen.rs, lib.rs}`, `crates/zx-core/src/preimage/dag.rs`
  (`pre_hash`, `verificar_sello`), `crates/zx-core/src/hash.rs` (`sha3_256_publico`), y la identidad de la
  evidencia en `zx-core` (busca la que usa `EvidenceTx` v4 para EV-06/EV-10: `validar_forma_tx_v4` y el
  identificador de incidente).

## 3. Decisiones del director (no las cambies; si una no se puede cumplir, para e informa)

1. **Ubicación:** módulo `crates/zx-post/src/firmante/` (`mod.rs`, `identidad.rs`, `registro.rs`),
   exportado como `zx_post::firmante`. Motivo: el firmante es política **local de producción** (FIR-15), y
   `zx-post` es el crate del productor; en el árbol nuevo `zx-consensus` es validación. Sin dependencias
   externas nuevas; `ed25519-zebra` ya es dependencia de `zx-post`. Lock sin cambios.
2. **Identidad (RAT-1):** `IdentidadTicket` = `(consensus_branch_id, public_key, sector_index, history_size,
   chunk, slot)`, derivada **dentro** del firmante desde la cabecera (nunca declarada por el llamante). Huella
   `sha3_256_publico(dominio ‖ versión ‖ campos de anchura fija)` con dominio nuevo
   `b"ZXRFIRM/ticket-rat1/cbid-c-gd-07"` y `VERSION_ESQUEMA = 2` (la v1 antigua no llevaba red, FP8).
3. **Registro:** formato **v3** del código antiguo (FIR-06: cabecera inmutable con comprobación; FIR-07
   envenenamiento ante fallo ambiguo; FIR-08 recuperación que **falla cerrada** también ante una cola a
   ceros; FIR-09 sin poda in situ). `fsync` real (`sync_all`) antes de devolver `Ok` (FIR-03); **no**
   `fdatasync`. `S_max_slots` entra como argumento (FIR-10), no como constante del módulo; el perfil dev lo
   fijará en SL-4b2 a `150` (`zx-core/src/wire_dag.rs`, `S_max_slots = 150`).
4. **Firmante (FIR-01, FIR-04, FIR-05):** comprueba que la clave corresponde a `sol.public_key` antes de
   tocar el registro; reserva con `fsync`; firma; verifica el sello construido sobre una copia antes de
   escribirlo en la cabecera. Resultados `Sellado`, `Reemitido`, `AbstenidoPorConflicto`, y la abstención por
   pérdida del registro (FIR-10) como resultado distinto de un error de E/S.
5. **Registro nuevo frente a registro perdido (sustituye a `alta.rs` en 0.0.1):** el módulo expone dos
   aperturas explícitas y distintas: `Registro::nueva(ruta)` (falla si el archivo ya existe; sin abstención;
   para un directorio de datos recién creado) y `Registro::abrir(ruta, slot_actual, s_max_slots)` (recupera
   si existe; si no existe, crea **en abstención** hasta `slot_actual + s_max_slots`). Quién elige cuál es el
   nodo (SL-4b2), no este módulo. Motivo: las claves dev se derivan de un índice (`zx-node/src/claves.rs`);
   la generación aleatoria de `alta.rs` no se usa en 0.0.1.
6. **Productores:** añade, **sin cambiar ni borrar** las funciones existentes (el nodo aún las usa y otra
   orden lo está modificando), `producir_en_regimen_con_firmante` en `productor_regimen.rs` y la variante
   equivalente del primer bloque PoST en `productor.rs`. Construyen la cabecera exactamente igual que las
   actuales (factoriza el código común en una función privada; no dupliques la construcción) y la sellan
   **solo** mediante `&mut Firmante`. Devuelven un resultado que distingue `Bloque(BloqueDag)` de
   `Abstenido { motivo }` (conflicto o abstención por pérdida); los fallos de E/S del registro son error.
   Las funciones antiguas pasan a documentar que **no** protegen contra la doble firma y que SL-4b2 las
   retirará del nodo.

## 4. Contrato de implementación

- **Archivos que puedes crear o modificar** (dentro de `ws/`): `crates/zx-post/src/firmante/**`,
  `crates/zx-post/src/{lib.rs, productor.rs, productor_regimen.rs}`, `crates/zx-post/tests/firmante*.rs`
  (nuevos), `crates/zx-post/Cargo.toml` **solo** si un test necesita una `dev-dependency` que ya esté en el
  workspace (`tempfile` u otra ya presente en `Cargo.lock`; si no está, para). **Vedado:** todo lo demás,
  en particular `crates/zx-node/`, `crates/zx-consensus/`, `crates/zx-core/`, `Cargo.lock` (salvo que una
  `dev-dependency` ya presente añada una arista; ninguna versión nueva).
- **Errores explícitos:** `ClaveNoCoincide`, `SelloInvalido`, `Envenenado`, `CabeceraCorrupta`,
  `ColaParcial`, `Corrupto`, E/S; ningún `unwrap` en la ruta no-test.
- **Concurrencia:** un registro lo abre un único proceso; documenta y comprueba (cerrojo de archivo si el
  código antiguo lo tenía; si no, decláralo como límite).

## 5. Modelo de amenaza (qué cubre y qué no)

Cubre **accidentes honestos**: reinicio tras `SIGKILL` o corte de energía entre reservar y firmar, doble
llamada del productor con dos candidatos del mismo billete, registro truncado o corrompido. **No** cubre (y
el informe lo dice, FIR-13): dos máquinas con registros distintos, clave robada o compartida, un atacante que
borra el registro, `fsync` que miente (NFS). No es un mecanismo de seguridad ni de consenso (FIR-15).

## 6. Plan de verificación

| Paso | Qué | Criterio |
|---|---|---|
| V0 | Antes de tocar nada: `sha256sum -c` de la entrada; suite de `zx-post` sin cambios | verde; si no, para |
| V1 | Tests portados del código antiguo (`firmante_local.rs` y los de `registro.rs`), adaptados a RAT-1 | todos pasan; lista uno a uno de portados, adaptados (qué cambió) y no portados (por qué) |
| V2 | **Durabilidad con proceso real:** un test lanza un proceso hijo (el propio binario de test re-ejecutado con una variable de entorno) que reserva `(identidad, slot) → pre_hash_1` y se mata con `SIGKILL`/`abort` **después** de que `resolver` devuelva `Ok` y **antes** de firmar; el padre reabre y comprueba que `pre_hash_2 ≠ pre_hash_1` se niega (`AbstenidoPorConflicto`) y que `pre_hash_1` se reemite. Repetido ≥ 20 veces | 20/20 |
| V3 | Cola a ceros y bit cambiado en la cabecera del registro | falla cerrado (`ColaParcial` / `CabeceraCorrupta`), sin truncar |
| V4 | Abstención exacta (FIR-10): `abrir` sin archivo con `slot_actual = s`, `S_max = m`: niega `s … s+m−1`, firma en `s+m` | exacto en los bordes |
| V5 | **Identidad = identidad de la evidencia (RAT-1):** (a) para cabeceras reales firmadas, «misma identidad del firmante» ⟺ «mismo `zx_core::preimage::tx::incident_id_evidencia`» calculado de cada cabecera; (b) con dos cabeceras de la misma identidad y distinto `pre_hash`, la `EvidenceTx` v4 pasa `zx_core::validar_forma_tx_v4` y **se aplica** en el motor (modelo: `crates/zx-consensus/tests/evidencia.rs`, `zx-consensus` ya es `dev-dependency` de `zx-post`); (c) cambiando **uno** de los seis campos de la identidad (uno por test, incluido `consensus_branch_id`), el firmante las trata como oportunidades distintas **y** el motor rechaza la evidencia (`ErrSinEvidencia`, o `ErrCbidAjeno` para el `cbid`); (d) cambiar un campo que no es de la identidad (padres, cuerpo, `timestamp`) no cambia la identidad del firmante | tabla campo → resultado, 6 + 3 filas |
| V6 | Productores `_con_firmante`: (a) mismo slot y padres, segunda llamada → `Reemitido` y bloque idéntico byte a byte; (b) mismos billete y slot con otros padres o cuerpo → `Abstenido`, sello **no** calculado; (c) el bloque de (a) pasa la puerta conjunta de `zx-post` igual que el de la función antigua con los mismos datos | cada caso con su aserción |
| V7 | `fmt --check`, `clippy --workspace --all-targets --all-features --locked -- -D warnings`, `cargo test --workspace --all-features --locked` (todo lo previo con su nombre + lo nuevo), `ci/dependencias-exactas.sh`, `ci/frontera-crates.sh` | limpio; lock idéntico o con la sola arista declarada |
| V8 | Coste: mediana y p99 de `firmar` con `fsync` en esta máquina (≥ 2 000 muestras, disco de la zona), comparado con FIR-14 (0,81 ms de mediana en el prototipo) | medido y declarado; no es criterio de aceptación |

**Tabla de cobertura** (lección de método 1): en el informe, número de casos por resultado del firmante
(`Sellado`, `Reemitido`, `AbstenidoPorConflicto`, abstención por pérdida, cada error) con **mínimo 1** por
fila; una fila a cero es un fallo de la orden.

**Prohibido Python** (ni para auditar ni para probar). Presupuesto: **2 h de reloj, 4 hilos**
(`CARGO_BUILD_JOBS=4`, `RUST_TEST_THREADS=4`: otra orden usa la máquina con procesos que dependen del reloj),
8 GiB.

## 7. Entregables y límites

Patrón de las órdenes W (`P-ZRX/P-FORMATO/ORDEN-W02.md` §4): `ws.orig/` y `ws/` con **solo** `Cargo.toml`,
`Cargo.lock`, `rust-toolchain.toml`, `crates/`, `testdata/`, `ci/`, `.github/` copiados de la raíz, y el
enlace `ws/PDF → /home/katana/zeo/ZEROX/PDF`; `cambios.patch` (`diff -ruN ws.orig ws`, sin `target` ni
cachés) y `MIGRACION.sha256` como **último** paso con `sha256sum -c` en verde; `logs/`, `INFORME.md`,
`PROGRESO.md` (procesos largos con PID y log **antes** de esperarlos), `HORAS.log` con `date -Is` real.
Entorno: `env.sh` como el de `deepseek/SL4a/env.sh` con tu zona, `CARGO_BUILD_JOBS=4`,
`RUST_TEST_THREADS=4`, `CARGO_NET_OFFLINE=true`; caché copiable de `deepseek/SL4a/.cargo-home`.

**Informe final** (`INFORME.md`): archivos cambiados, comandos y resultados de V0…V8, tabla de cobertura,
lista de tests portados/adaptados/no portados, fallos (sin ocultarlos), riesgos y lo que **no** queda
demostrado; el nombre de modelo que devuelve la API en tu sesión.

**Límites de la sesión:** `deepseek-flash`, esfuerzo `high`, solo DeepSeek Harness; LINEO leído antes de
escribir código; ningún código Python; no eliges arquitectura ni números (si falta una decisión, para e
informa **antes de editar**); nada fuera de tu zona (en particular **no** toques `deepseek/W06d5/` ni sus
procesos); ningún `Ok` ficticio ni test que se salte con `#[ignore]` sin motivo; sin commit ni push; no leas
ni muestres secretos (`.env`, `~/.dsh`, tokens).

## Lanzamiento

    mkdir -p /home/katana/zeo/ZEROX/deepseek/SL4b1 && cd /home/katana/zeo/ZEROX/deepseek/SL4b1 && \
    ( set -a; . /home/katana/torio/deepseek-harness/.env >/dev/null 2>&1; set +a; \
      node /home/katana/torio/deepseek-harness/apps/cli/lib/bin.js --profile headless \
      "Orden SL-4b1. Lee íntegro /home/katana/zeo/ZEROX/P-ZRX/P-SLASHING/ORDEN-SL4b1-FIRMANTE.md y cúmplelo. Antes de escribir código, lee íntegro /home/katana/zeo/ZEROX/V-ZRX/LINEO.md. Si detectas una falta de definición, infórmala antes de editar." )
