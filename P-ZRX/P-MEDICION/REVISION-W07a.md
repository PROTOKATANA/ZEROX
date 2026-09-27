# REVISIÓN W07a — instrumentación del registro según el esquema v1

**Revisor:** Claude (director). **Fecha:** 2026-09-27 (≈ 06:36). **Ejecutor:** DeepSeek, 04:43–06:37.
Evidencia: `resultados-W07a/`. **Veredicto: SUPERADO CON CORRECCIÓN PENDIENTE. Migración** por la orden de
rebase W07a-R, tras W06d7 (las dos tocan `nodo.rs` y `zx-cadena`).

## Comprobado

- Entrada 47/47; 12 faltas de definición informadas antes de editar (lecturas mínimas, ratificadas).
- Eventos y campos del §1 (salvo los de SL-4b2); accesos de lectura nuevos y aislados en `zx-cadena` con test;
  `registro_esquema` 1/1 (83 líneas, todas del esquema); V3 con tres nodos: 91 bloques PoST, entradas
  inválidas rechazadas con `etapa`; `fmt`, `clippy`, guardianes; `Cargo.lock` sin cambios.
- V1: 818 pasan y 1 falla (`reinicio.rs`, causa propia: el evento de producción del bloque de transición);
  corregido y verificado **solo aislado** (2/2). **La suite completa tras la corrección no se ejecutó**: la
  ejecuta W07a-R.

## Decisiones

1. **Coste del registro (V4: 1,89 % > 1 %).** Se mide contra `t_admision_ns` (solo `zx-cadena`, mediana
   231 µs); frente al coste total de un bloque PoST (verificación PoT/PoAS ≈ 66 ms, W05b3) son ≈ 4,4 µs, el
   0,007 %. Se **acepta** y se mantiene el `flush` por evento: el registro tiene que sobrevivir a un `SIGKILL`
   en E-4. El criterio del 1 % estaba mal elegido (error del director: denominador demasiado pequeño).
2. **Eventos retirados (no pedido):** la entrega quitó seis eventos existentes (`dejar_de_producir`,
   `bloque_red_pendiente`, `bloque_red_ignorado_sin_penalizar`, `bloque_post_gossip_descartado_sincronizando`,
   `bloque_propio_rechazado_legitimo`, `bloque_post_de_red_sin_terminal`), en contra de «solo observación»; el
   diagnóstico de W06d6 se apoyó en `bloque_red_pendiente` y el reposo de W07b en `dejar_de_producir`. **Se
   restauran en W07a-R** (esquema §1 bis).
3. `par` de los bloques de gossip omitido («no computable»): se acepta por ahora; la latencia no lo necesita.
