# REVISIÓN W06d8 — protocolo productor↔bucle robusto y ningún pánico alcanzable en el productor

**Revisor:** Claude (director). **Fecha:** 2026-09-27 (≈ 14:37). **Ejecutor:** DeepSeek, 12:21–14:35 (presupuesto
superado en ≈ 13 min, declarado). Evidencia: `resultados-W06d8/`; ejecuciones reales en `deepseek/W06d8/run/`.
**Veredicto: SUPERADO. Migrada** por parche (4 archivos de `crates/zx-node/`; base sin cambios desde `2455a55`; 4/4
huellas; `crates/zx-node` idéntico a la zona).

**Motivo:** pánico real hallado por W07b (E-2a, intento 4): «se esperaba Continuar/Parar, llegó Padres»
(`regimen.rs:438`), porque el cambio de terminal en caliente (SL-4b2, paso 0) desincronizaba el protocolo entre el
hilo productor y el bucle.

- **Protocolo numerado:** las peticiones del productor llevan un `id` creciente y las respuestas del bucle lo
  devuelven; una respuesta atrasada se **descarta** (evento `productor_respuesta_descartada`); `Parar` se atiende
  siempre; un `id` futuro es violación de invariante.
- **Sin pánicos alcanzables en `regimen.rs`:** los 15 sitios convertidos en manejo explícito; en `vista.rs` y
  `registro.rs`, tres más; el resto (8 construcciones y 9 indexaciones con su garantía) clasificado como invariante en
  la tabla del informe.
- **Fallo del productor = parada ordenada:** evento crítico `fallo_productor` y salida del proceso con código ≠ 0.
- **Pruebas:** 6 tests del protocolo con un bucle simulado (respuesta atrasada, duplicada, `Parar` en cada espera,
  `id` futuro) y el de parada; **V3 real 5/5** (tres nodos, `SR_dev = u64::MAX`, 214–225 bloques PoST, 0 pánicos);
  evidencia adicional con partición y reunión en caliente: **2 respuestas atrasadas descartadas de verdad** (la carrera
  que antes tumbaba el hilo). `fmt`, `clippy -D warnings`, **860/0/6**, guardianes.
