# REVISIÓN RI-1b — revisión independiente de PoW dev, `zx-dag` y puerta PoST

**Revisor de la revisión:** Claude (director). **Fecha:** 2026-09-26. **Ejecutor:** subagente Sonnet
(≈ 9 min, 54 llamadas). Evidencia: `resultados-RI-1b/` (informe y test de reproducción, con huellas).

**Veredicto: ACEPTADA.** Sin hallazgos críticos; uno alto confirmado con medida y uno bajo plausible.
Descartó con razón un candidato (padres duplicados: `PadresDag::nuevo` y el parser ya los rechazan).

## Hallazgos y decisión

| # | Hallazgo | Comprobación del director | Decisión |
|---|---|---|---|
| H1 (alta, CONFIRMADO) | Admisión GHOSTDAG con coste por bloque creciente con la profundidad: U2 (`pasado_contiene_ident`) recorre el bitset de pasado completo del padre y `anc` se construye por unión; medido 90 µs → 1,66 ms por inserción de N = 2 000 a N = 16 000 (8× profundidad, 18,5× coste) | El módulo ya lo declaraba como límite (`crates/zx-dag/src/ghostdag.rs:41-45`: «el coste por bloque crece con el DAG. No se inventa una cota»); `blue_idents` también se copia por bloque. La medida es nueva y **cambia la gravedad**: lo dispara una cadena lineal honesta, no hace falta adversario | **No bloquea 0.0.1** (una ejecución dev de 30 min son ≈ 2 000 bloques: ~0,1 ms por admisión), pero **sí limita la duración de las mediciones** y **bloquea cualquier red larga**. Nuevo IPA **B-12** (índice de alcanzabilidad acotado para U2 y el pasado, tipo Kaspa). W07 registrará el tiempo de admisión frente a la profundidad y declarará el límite |
| H2 (baja, PLAUSIBLE) | `ContextoTransicion::nuevo` (`crates/zx-post/src/contexto_transicion.rs:176-181`) se queda en silencio con la primera salida si dos registros validados del mismo slot traen `pot_output` distinto | Leído: `or_insert` sin comprobación; con un solo flujo (D-P10) dos salidas distintas del mismo slot solo pueden venir de un fallo aguas arriba, que así queda oculto | Se añade a `ORDEN-W05b3` (mismo crate): error explícito en vez de `or_insert` |
