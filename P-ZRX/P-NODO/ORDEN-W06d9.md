# ORDEN-W06d9 — El productor no muere por falta de un portador PoT («no hay portador retenido para el slot N»)

**LINEO (`V-ZRX/LINEO.md`) rige este código Rust**; léelo íntegro antes de escribir código.

## 1. Identidad y contexto

- **ID:** W06d9. **Fecha:** 2026-09-27 (≈ 18:23). **Director:** Claude. **Ejecutor:** DeepSeek
  (`deepseek-flash`, esfuerzo `high`).
- **Zona (única escribible):** `/home/katana/zeo/ZEROX/deepseek/W06d9/`. **Base:** la raíz en el commit de
  `ENTRADA-W06d9.sha256`; **no modifiques `ws.orig/`**; puedes **leer** `deepseek/W07b/run/R3-E6-rep1/` (el fallo) y
  `deepseek/W07b/scripts/` (guiones de red real); ninguna otra zona.
- **Motivo (hallazgo de W07b, candidato `26312ff`):** justo tras el corte (slot ≈ 6), con tres nodos, el nodo C salió con
  `fallo_productor`: «producir_en_regimen_con_firmante falló: servicio PoT: no hay portador retenido para el slot 6»
  (`run/R3-E6-rep1/C/{stderr.log,registro.jsonl}`). `ServicioPot::portadores_para(sp_slot, b_slot)`
  (`crates/zx-post/src/servicio_pot.rs` ≈ 442) exige el portador de **cada** slot de `(sp_slot, b_slot]`; el hilo
  productor trabaja con una **copia** del servicio de verificación (`crates/zx-node/src/regimen.rs` ≈ 350) que puede
  tener **huecos** (slots con salida conocida y sin portador), en especial tras reconstruirse por cambio de terminal en
  caliente (SL-4b2, decisión 0; W06d7). No apareció en 6 repeticiones de R1/R2 (≈ 9 000 bloques): es intermitente.
- **Pregunta falsable:** «Tras la corrección, ningún hueco de portadores tira el nodo, el productor produce siempre que
  pueda justificar su bloque, y en ≥ 10 cruces del corte con tres nodos reales (más la partición E-6 con aislamiento
  real) no aparece ningún `fallo_productor`.»

## 2. Decisiones del director

1. **Causa primero:** reproduce el fallo (unitario o de integración) y escribe en el informe la **causa exacta** (qué
   secuencia deja el hueco: copia del servicio, cambio de terminal, bloques de red que traen la salida sin el portador,
   poda de la ventana…), con archivo:línea. Corrige esa causa en su origen.
2. **Red de seguridad, además:** un portador ausente **no** es una violación de invariante del productor. El productor
   (a) intenta **completar** los portadores que faltan recalculándolos de forma determinista desde la salida anterior
   conocida (el PoT es un flujo único y determinista; mismo cálculo que `avanzar`), acotado a `MAX_BUNDLES_POT`; y (b) si
   aun así no puede justificar el bloque con esos padres, **no produce en ese slot** (evento de diagnóstico
   `produccion_omitida` con `slot` y `motivo`) y sigue con el siguiente. Nunca `fallo_productor` por esto.
3. Ninguna regla de consenso cambia: un bloque solo se publica con su justificación completa y verificable.

## 3. Contrato

Archivos permitidos: `crates/zx-post/src/servicio_pot.rs`, `crates/zx-node/src/{regimen.rs, nodo.rs}` y tests. Vedado
el resto; `Cargo.lock` sin cambios.

## 4. Verificación

| Paso | Qué | Criterio |
|---|---|---|
| V0 | `sha256sum -c` de la entrada; suite completa sin cambios | verde |
| V1 | Test que reproduce el hueco **antes** de la corrección (guarda la salida) y pasa después | antes falla, después pasa |
| V2 | Tests de la red de seguridad: portadores recalculados coinciden **byte a byte** con los del servicio de verificación; rango no justificable → `produccion_omitida`, sin fallo | todos |
| V3 | **Procesos reales:** 10 repeticiones de tres nodos (una clave por nodo, `SR_dev = 13043817825332783104`, `N_dev` real) que cruzan el corte y llegan al slot 60; y 3 repeticiones de la partición E-6 con **aislamiento real** (guion `deepseek/W07b/scripts/r3_e6.sh`, copiado a tu zona) | **0 `fallo_productor`**, 0 pánicos; cuenta de `produccion_omitida` informada |
| V4 | `fmt --check`, `clippy --workspace --all-targets --all-features --locked -- -D warnings`, `cargo test --workspace --all-features --locked`, los tres guardianes; T01/T04 en verde | limpio |

**Prohibido Python** (también para editar texto). Presupuesto: **2 h 30 min, 8 hilos**, `nice -n 5` (W07b hace
verificaciones de un nodo a la vez en la máquina). Patrón de las órdenes W (`ws.orig/`, `ws/`, `cambios.patch`,
`MIGRACION.sha256` como último paso), `INFORME.md`, `PROGRESO.md`, `HORAS.log` (`date -Is` real), nombre de modelo. Nada
fuera de la zona; sin git en el repositorio; sin secretos; ningún `Ok` ficticio. Si falta una definición, infórmala
**antes de editar**.
