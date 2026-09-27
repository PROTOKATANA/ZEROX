# ORDEN-W07d — Registro del estado final: resumen tras la repetición y bloque de transición

**LINEO (`V-ZRX/LINEO.md`) rige este código Rust**; léelo íntegro antes de escribir código.

- **ID:** W07d. **Fecha:** 2026-09-27 (≈ 16:46). **Director:** Claude. **Ejecutor:** DeepSeek
  (`deepseek-flash`, esfuerzo `high`). **Zona (única escribible):** `/home/katana/zeo/ZEROX/deepseek/W07d/`.
  **Base:** la raíz en el commit de `ENTRADA-W07d.sha256`; **no modifiques `ws.orig/`**; ninguna otra zona.
  **Prioridad mínima (`nice -n 19`), 4 hilos:** W07b está midiendo con procesos reales en la máquina.
- **Motivo (hallazgo del director al revisar W07b R1 rep2):** comparar el estado final de varios nodos no es fiable
  con el registro actual. `resumen_estado` solo se escribe en `cambio_punta`, y `registrar_cambio_de_punta`
  (`crates/zx-node/src/nodo.rs` ≈ 1241) no escribe nada si la punta seleccionada no cambia. Los bloques laterales que
  llegan después del último cambio de punta cambian el estado virtual sin dejar rastro, y `reinicio_completo` no lleva
  ningún resumen. Además, el bloque de transición propio no se registra como producido (W07a-R).
- **Solo registro:** ningún cambio de reglas, de orden de la tubería ni de decisiones del nodo.

## Qué hacer

1. **`reinicio_completo`** lleva además `punta` (la seleccionada tras la repetición), `resumen_estado` (del estado
   virtual **después** de repetir todo el almacén, con la misma función `resumen_estado` que usa `cambio_punta`),
   `n_bloques_dag` y `compendio_bloques`: SHA3-256 (`zx_core::sha3_256_publico`) de la concatenación de los hashes de
   **todos** los bloques admitidos (PoW y PoST), ordenados por bytes. Evento crítico (`sync`).
2. **Parada ordenada con `SIGTERM`/`SIGINT`:** el nodo escribe `parada` (crítico) con `motivo`, `punta`,
   `resumen_estado`, `n_bloques_dag` y `compendio_bloques` calculados en ese momento, y sale con código 0. Si hoy no
   maneja esas señales, añade el manejo mínimo.
3. **Bloque de transición propio:** evento de diagnóstico `bloque_transicion_producido` (`hash`, `slot`), distinto de
   `bloque_producido` para no alterar lo que prueba `reinicio.rs` (W07a-R).
4. **No edites** `P-ZRX/P-MEDICION/ESQUEMA-REGISTRO-v1.md` ni ningún documento del
   director: describe los campos nuevos en tu informe y el director los incorpora.
5. Tests: `reinicio_completo` con resumen igual al del estado virtual que calcula el propio nodo tras reabrir; dos nodos
   con el mismo conjunto de bloques admitidos en órdenes distintos dan el mismo `compendio_bloques` y `resumen_estado`;
   `parada` por `SIGTERM` en un proceso real.

## Verificación

`fmt --check`, `clippy --workspace --all-targets --all-features --locked -- -D warnings`, `cargo test --workspace
--all-features --locked`, los tres guardianes de `ci/`; diferenciales T01/T04 sin cambios. `cambios.patch` y
`MIGRACION.sha256` como último paso. **Prohibido Python** (también para editar texto). Presupuesto 1 h 30 min.
`INFORME.md`, `PROGRESO.md`, `HORAS.log` (`date -Is` real), nombre de modelo. Nada fuera de la zona; sin git en el
repositorio; sin secretos; ningún `Ok` ficticio. Si falta una definición, infórmala **antes de editar**.
