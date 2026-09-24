# ORDEN D2 · PoT secuencial del génesis dev hasta una solución de disco

**Modelo ejecutor:** `deepseek-v4.1-flash`, esfuerzo `high`, mediante DeepSeek Harness. **Alcance:** preparación de D2/A2/F4; no cierra ninguna de esas piezas.

## Objetivo acotado

Agregar un test de integración que, desde el `pot_output(G)` del génesis DAG dev congelado, ejecute una cadena PoT AES real, audite la parcela real de D1 con cada salida de slot, convierta candidatos mediante la API D2 existente y encuentre al menos una solución que A1 valide. Este test establece el primer puente reproducible entre el ancla C3, PoT, disco y A1. **No crea ni admite un bloque** y no configura una red.

## Archivos permitidos

- `crates/zx-node/tests/farmer_disco.rs`: un test adicional y los `use`/constantes locales necesarios. Reutilizar `fondo()`, `instalar_par`, `params_pieza_fixture`, `RANGO_PRUEBA` y `DirTemporal`; no duplicar el ploteo.
- `crates/zx-node/Cargo.toml`: añadir únicamente `zx-pot = { path = "../zx-pot" }` bajo `[dev-dependencies]`, pues `zx-node` no depende hoy de `zx-pot` y solo este test necesita crear portadores.
- `Cargo.lock`: **excepción acotada tras la primera ejecución interrumpida**. Cargo exigió registrar la nueva arista directa `"zx-pot"` en la lista de dependencias del paquete `zx-node`; el diff inspeccionado contiene exactamente esa línea, sin versiones nuevas. Se permite conservar **solo esa línea**. Si hace falta cualquier otro cambio del lock, detente y explica.

No tocar `SPEC.md`, `PDF/`, `ci/`, código de producción, `AGENTS.md` ni archivos concurrentes. No hacer commit ni push.

## Contrato del test

1. Activado solo por `feature = "farmer"`, llamar `zx_node::bootstrap_dag_dev::iniciar_bootstrap_dag_dev()` y tomar `ancla_pot_slot_0_dev()`; comprobar `retardo_pot_dev() == 0`. Esta salida es el ancla confiada del slot 0 según C3-ARRANQUE; **no** se acredita por AES desde `semilla(f_0,0)`.
2. El único `N` del test será `NonZeroU32::new(16)` (mínimo válido para ocho checkpoints, C-POT-02/04). Decláralo `N_SMOKE` o nombre igualmente explícito en el test. **No** crear `N_dev` ni afirmar que `16` es cadencia o parámetro de consenso; no usar este tiempo como medición de red.
3. Recorrer secuencialmente los slots `1..=64`. Para cada slot, derivar `semilla_siguiente(salida_anterior, None)` (C-POT-01; el fixture no declara inyecciones), ejecutar `zx_pot::prove(PotSeed::from(semilla), N_SMOKE)`, convertir mediante `zx_consensus::pot::checkpoints_a_wire` y verificar **por la API distinta** `zx_consensus::pot::verificar_slot_aes(semilla, 16, &wire)` (C-POT-02). Actualizar `salida_anterior` exclusivamente con el último checkpoint verificado de ese slot. Comprobar que la salida del slot 1 difiere del ancla. No calcular reto directamente desde `(f_0,slot)` ni saltar slots.
4. En cada slot, llamar `convertir_candidatos_locales(&parcela, salida_slot, slot, RANGO_PRUEBA, &params, &kzg, &erasure_coding)`. `RANGO_PRUEBA = u64::MAX` ya existe y sigue siendo un rango **de prueba**, no `SR_DEV` de red. Antes de aceptar cualquier hallazgo, verificar de nuevo todas las soluciones devueltas con `verificar_solucion_poas` y comparar su distancia con la informada. Exigir al menos una solución antes del límite y que se haya ejecutado una cadena no vacía de PoT.
5. Negativo PoT no tautológico: copiar el portador del slot 1, alterar un byte de un checkpoint del wire y exigir `Ok(false)` de `verificar_slot_aes` con la semilla original. Negativo PoAS: alterar `proof_of_space` de una solución encontrada y exigir error de A1. No aceptar simplemente que una colección vacía sea éxito. Informar en `eprintln!` el slot hallado y el contador de slots atravesados, etiquetados como fixture local.
6. Mantener el test determinista y acotado. Si la parcela no da ninguna solución en 64 slots, no inventar salida ni ampliar el rango en silencio: informa el resultado y la causa probable para que el líder decida el siguiente experimento.

## Reglas y límites

- C-POT-01, C-POT-02, C-POT-03, C-POT-04, C-POT-05 y C-POT-08 paso 5: cita solo las reglas que realmente ejerza el test y di expresamente que no acredita procedencia causal ni admisión.
- `C-POT-05` distingue la salida auditada del slot y el `pot_output` futuro de la cabecera; aquí `D=0` únicamente en el bootstrap dev y no se construye cabecera.
- Conservar en producción `IntegracionPotPendiente` donde aún corresponda. No usar `Ok(())` para suplir contexto ni modificar el SPEC.

## Entrega y comprobación

Ejecutar `cargo test -p zx-node --features farmer --test farmer_disco --locked -- convierte_pot_dev_y_solucion_disco --nocapture` (nombre exacto ajustable si se documenta), `cargo fmt --all -- --check`, `cargo clippy -p zx-node --features farmer --test farmer_disco --locked -- -D warnings` y `git diff --check`. Si el test tarda demasiado por ploteo, medirlo y reportar el coste; no ocultar ni desactivar el test. Entregar el diff exacto, resultados y límites. El líder inspeccionará código y repetirá pruebas antes de conservarlo.
