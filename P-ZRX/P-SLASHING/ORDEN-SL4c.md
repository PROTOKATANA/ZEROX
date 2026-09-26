# ORDEN-SL4c — `EvidenceTx`: `cbid` y orden canónico como forma, y decodificación de red de la v4 (Rust)

**LINEO (`V-ZRX/LINEO.md`) rige este código Rust** (`AUTO-ZRX.md` §52); léelo íntegro antes de escribir
código y aplica sus reglas pertinentes.

## 1. Identidad y contexto

- **ID:** SL-4c. **Fecha:** 2026-09-26 (redactada ≈ 23:16; congelada y lanzada ≈ 23:51).
  **Director:** Claude. **Ejecutor:** DeepSeek (`deepseek-flash`, esfuerzo `high`, DeepSeek Harness).
- **Zona (única escribible):** `/home/katana/zeo/ZEROX/deepseek/SL4c/`.
- **Motivo:** `P-ZRX/P-REVISION-CODIGO/REVISION-RI-3b.md`: (H1) el `cbid` ajeno (RAT-1) y el orden no canónico
  (EV-04) son errores de **forma** según el contrato, y hoy el motor los trata como semánticos; (FD-5)
  `tx_desde_bytes` rechaza toda v4, así que con la evidencia activa un bloque que la lleve no se puede recibir
  por red.
- **Pregunta falsable:** «El motor y `zx-cadena` reproducen los vectores T01 v0.5 y T04 v0.6 (SL-4c-O) sin
  discrepancias y con su cobertura; toda `EvidenceTx` v4 bien formada sobrevive a `tx_a_bytes` →
  `tx_desde_bytes` byte a byte, y toda codificación no canónica o truncada se rechaza.»
- **Desbloquea:** SL-4b2 (la evidencia viaja dentro de bloques por la red).

## 2. Entradas (congeladas en `P-ZRX/P-SLASHING/ENTRADA-SL4c.sha256`)

`CONTRATO-EVIDENCIA-v0.md` (§2 y «Ratificación v0»), `REVISION-RI-3b.md`, `ORDEN-SL4c-O.md`, `-O-B.md`,
`-O-C.md` y `REVISION-SL4c-O.md` (la regla de precedencia definitiva), los vectores nuevos
`P-ZRX/P-TRANSICION/T01/resultados/{vectores-transicion-v0.5.txt, .sha256, cobertura-v0.5.txt}` y
`P-ZRX/P-DAG/T04/resultados/{vectores-estado-dag-v0.6.txt, .sha256, cobertura-v0.6.txt}`, y los informes de
diferencias `P-ZRX/P-TRANSICION/T01/DIFERENCIAS-v0.4-v0.5.md` y `P-ZRX/P-DAG/T04/resultados/DIFERENCIAS-v0.5-v0.6.md`, `P-ZRX/P-FORMATO/FORMATO-v0.md` (F-04, F-05, F-14). Código: la raíz en
el commit que indique la entrada.

## 3. Decisiones del director

1. **Forma:** `validar_forma_tx_v4` comprueba además, **en este orden** y tras lo que ya comprueba: `cbid` de
   ambas cabeceras igual al de la red local (el llamante lo pasa: nuevo parámetro `cbid_local: u32`) →
   `ErrorFormaTx::EvidenciaCbidAjeno` (variante nueva); orden canónico estricto por `pre_hash` →
   `ErrorFormaTx::OrdenCanonicoInvalido` (ya existe y hoy nunca se construye). Todo llamante pasa el `cbid`
   de su red; ningún valor por defecto.
2. **Precedencia (`ORDEN-SL4c-O-B.md` y `-C`):** las transacciones de un bloque se comprueban en su orden; para cada una, entradas/salidas/testigos → `cbid` → orden canónico; la primera defectuosa fija el motivo. En fusión, **todo** error de forma de la v4 (los tres) hace inválido el bloque; si hoy `zx-cadena` o `aplicar_fusion` no invocan la forma de la v4, se invoca.
3. **Motor:** desaparecen `ErrCbidAjeno`, `ErrOrdenCanonico` y `ErrEvidenciaConEntradas` como errores semánticos (el camino queda
   cubierto por la forma, que se comprueba antes); en fusión, un error de forma de una transacción hace
   **inválido el bloque** (como cualquier otra forma de transacción, `CONTRATO-ESTADO-DAG-v0.md`). Nada más
   cambia en la verificación semántica.
4. **Red (FD-5):** `tx_desde_bytes` decodifica la v4 (dos cabeceras `PoAS_PoT_DAG` completas, sin bytes
   sobrantes, F-14) en vez de devolver `VersionInactiva`; la **activación** la sigue decidiendo el motor
   (v4 con la evidencia inactiva → el error que hoy devuelve el motor para una versión inactiva). El parser
   rechaza, no adivina: cabecera truncada, sobrante, tamaño fuera de `[589, 1037]` B → error de codificación.
5. **Arneses:** `diferencial_t01` lee T01 v0.5 y `diferencial_t04` lee T04 v0.6, con las correspondencias de
   error nuevas declaradas una a una; los vectores van a `testdata/transicion-v0.5/` y
   `testdata/estado-dag-v0.6/` (copiados byte a byte de los resultados de los oráculos, con sus `.sha256`).
   Los directorios v0.4/v0.5 de `testdata/` se quedan (históricos) pero ningún test los lee.

## 4. Contrato de implementación

Archivos que puedes modificar (en `ws/`): `crates/zx-core/src/{forma.rs, wire.rs, error.rs}` y sus tests,
`crates/zx-consensus/src/transicion/{aplicar.rs, error.rs, fusion.rs}` y tests,
`crates/zx-consensus/tests/diferencial_t01.rs`, `crates/zx-cadena/tests/diferencial_t04.rs`, `testdata/`
(solo añadir). Los llamantes de `validar_forma_tx_v4` fuera de estos archivos (si los hay) se adaptan con el
cambio mínimo y se enumeran. **Vedado:** `crates/zx-node/`, `crates/zx-post/`, `crates/zx-p2p/`, `Cargo.lock`.

## 5. Plan de verificación

| Paso | Qué | Criterio |
|---|---|---|
| V0 | `sha256sum -c` de la entrada; suite completa sin cambios | verde; si no, para |
| V1 | Diferenciales contra T01 v0.5 y T04 v0.6 | **0 discrepancias**, cobertura idéntica a la de los oráculos (incluidos ≥ 30 casos de cada error nuevo y los bloques con transacciones válidas que quedan inválidos) |
| V2 | Ida y vuelta de la v4: ≥ 200 `EvidenceTx` generadas con semilla fija (cabeceras reales firmadas) → bytes → tx idéntica; y rechazos: truncada en cada frontera de campo, sobrante de 1 byte, cabecera de 588 y de 1 038 B, `version = 4` con extensión de otra versión | todos |
| V3 | `fmt --check`, `clippy --workspace --all-targets --all-features --locked -- -D warnings`, `cargo test --workspace --all-features --locked` (todo lo previo con su nombre + lo nuevo), `ci/dependencias-exactas.sh`, `ci/frontera-crates.sh` | limpio |

**Tabla de cobertura** en el informe (lección de método 1): casos por error de forma de la v4 y por
resultado del diferencial, mínimo 1 por fila. **Prohibido Python.** Presupuesto: **2 h, 4 hilos**, 8 GiB.

## 6. Entregables y límites

Patrón de las órdenes W (`P-ZRX/P-FORMATO/ORDEN-W02.md` §4): `ws.orig/`, `ws/` (solo `Cargo.toml`,
`Cargo.lock`, `rust-toolchain.toml`, `crates/`, `testdata/`, `ci/`, `.github/` y el enlace `ws/PDF`),
`cambios.patch` y `MIGRACION.sha256` como **último** paso con `sha256sum -c` en verde, `logs/`, `INFORME.md`
(archivos cambiados, comandos, resultados, tabla de cobertura, lo no demostrado, nombre de modelo de la API),
`PROGRESO.md`, `HORAS.log` con `date -Is` real. Entorno como `deepseek/SL4a/env.sh` con tu zona y 4 hilos;
caché copiable de `deepseek/SL4a/.cargo-home`. `deepseek-flash`, esfuerzo `high`; LINEO antes del código;
ningún código Python; no eliges reglas (si falta una definición, para e informa **antes de editar**); nada
fuera de tu zona; ningún `Ok` ficticio; sin commit ni push; sin secretos.

## Lanzamiento

    mkdir -p /home/katana/zeo/ZEROX/deepseek/SL4c && cd /home/katana/zeo/ZEROX/deepseek/SL4c && \
    ( set -a; . /home/katana/torio/deepseek-harness/.env >/dev/null 2>&1; set +a; \
      node /home/katana/torio/deepseek-harness/apps/cli/lib/bin.js --profile headless \
      "Orden SL-4c. Lee íntegro /home/katana/zeo/ZEROX/P-ZRX/P-SLASHING/ORDEN-SL4c.md y cúmplelo. Antes de escribir código, lee íntegro /home/katana/zeo/ZEROX/V-ZRX/LINEO.md. Si detectas una falta de definición, infórmala antes de editar." )
