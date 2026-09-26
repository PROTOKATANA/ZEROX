# ORDEN-SL4a — Evidencia y castigo en formato, motor y cadena (Rust), con diferencial contra SL-3b

**LINEO (`V-ZRX/LINEO.md`) rige este código Rust** (`AUTO-ZRX.md` §52: todo el código del proyecto); aplica
sus reglas pertinentes.

## 1. Identidad y contexto

- **ID:** SL-4a. **Fecha:** 2026-09-26. **Director:** Claude. **Ejecutor:** DeepSeek.
- **Zona (única escribible):** `/home/katana/zeo/ZEROX/deepseek/SL4a/`.
- **Objetivo único:** implementar `P-ZRX/P-SLASHING/CONTRATO-EVIDENCIA-v0.md` **con su «Ratificación v0»**
  (RAT-1, RAT-2′, RAT-3, RAT-4, que prevalecen) en `zx-core` (formato), `zx-consensus::transicion` (reglas,
  modo estricto y fusión) y `zx-cadena` (DAG), y demostrar que coincide con los oráculos de SL-3b.
- **Pregunta falsable:** «El motor y `zx-cadena` reproducen los vectores `vectores-transicion-v0.4.txt` y
  `vectores-estado-dag-v0.5.txt` sin discrepancias, incluidos los casos de evidencia, con la misma tabla de
  cobertura que los oráculos.»
- **Fuera de alcance:** el firmante seguro, la detección y el envío de evidencia en `zx-node` (SL-4b, tras
  W06d4). No toques `crates/zx-node/`.

## 2. Decisiones del director

1. **Formato (`zx-core`):** transacción **v4** `EvidenceTx` según `EV-01…EV-04` (dos cabeceras DAG completas
   en orden canónico, tamaño y peso acotados, `txid` que las compromete); deja de ser `ErrVersionInactiva`
   **solo** cuando el perfil activa la evidencia. Identidad de `RAT-1` con `consensus_branch_id`; la evidencia
   con un `consensus_branch_id` ajeno es de forma inválida. Test: cada red de `zx-core::red` tiene un
   `consensus_branch_id` distinto (RAT-1).
2. **Motor (`zx-consensus::transicion`):** registro de incidentes, congelación, confiscación
   `C = mín(V, techo(f·V))`, recompensa `suelo(C·2/8)` a la coinbase del bloque que aplica y el resto quemado
   (RAT-2′), liberación con las dos condiciones de RAT-3, pérdida cero con saldo cero (EV-22), evidencia fuera
   de plazo descartada (EV-14), undo exacto; en fusión, la segunda evidencia del mismo incidente es un
   **descarte** que no invalida el bloque (EV-12). Parámetros nuevos en el perfil dev: los de
   `REVISION-SL2b.md` (`f = 1`, `ρ_ret = 0,10`, `T_v = 10⁵` slots, `R_slots ≥ F_slots`, `q = 20`) y
   `Plazo_slots`, `M_margen_slots` con la desigualdad de RAT-3 comprobada como **puerta** de activación.
3. **Arneses diferenciales:** extiende `diferencial_t01` (lee T01 v0.4) y `diferencial_t04` (lee T04 v0.5) con
   la traducción de los casos de evidencia a transacciones v4 reales (cabeceras reales firmadas); **sin
   emulación** de nada (lección de W06a-B): si una traducción no es fiel, **para** e informa. Correspondencias
   de error: las vigentes más las de evidencia, declaradas una a una.
4. Tabla de cobertura del arnés **idéntica** a la de los oráculos (`cobertura-v0.4.txt` de T01 si existe y
   `cobertura-v0.5.txt` de T04).

## 3. Verificación

| Paso | Qué | Criterio |
|---|---|---|
| V1–V3 | `fmt --check`, `clippy -D warnings --locked`, `cargo test --workspace --all-features --locked` | limpio; todo lo previo con su nombre |
| V4 | `diferencial_t01` (v0.4) y `diferencial_t04` (v0.5) | **0 discrepancias**, cobertura idéntica |
| V5 | Tests propios: RAT-3 (carrera del retiro parcial), autodenuncia (pierde `≥ 6/8·C`), `cbid` ajeno, evidencia duplicada en hermanos, reorganización que la saca y la vuelve a meter | cada uno con su resultado |
| V6 | `dependencias-exactas.sh`, `frontera-crates.sh`; lock sin cambios de versión | OK |

**Prohibido Python.** Presupuesto: **3 h, 8 hilos, 16 GiB**.

## 4. Entregables y límites

Patrón de las órdenes W (`ws.orig/`, `ws/` solo con lo necesario para compilar y probar, `cambios.patch` y
`MIGRACION.sha256` como **último** paso, `logs/`, `INFORME.md`, `PROGRESO.md`, `HORAS.log`). Cargo desde `ws/`
con `GIT_CEILING_DIRECTORIES`, `CARGO_HOME` y `CARGO_TARGET_DIR` en la zona (caché copiable de
`deepseek/W06d3/`). DeepSeek `deepseek-flash`, esfuerzo `high`; nada fuera de la zona; sin commit ni push; sin
secretos; ningún `Ok` ficticio. Entrada congelada: `P-ZRX/P-SLASHING/ENTRADA-SL4a.sha256`.
