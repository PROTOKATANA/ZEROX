# ORDEN-SL3 — Oráculo de evidencia y castigo en la transición (T01) y en el DAG (T04)

## 1. Identidad y contexto

- **ID:** SL-3. **Fecha:** 2026-09-26. **Director:** Claude. **Ejecutor:** DeepSeek (Julia).
- **Zonas escribibles (solo estas dos):** `P-ZRX/P-TRANSICION/T01/` y `P-ZRX/P-DAG/T04/`. Se lanza desde
  `P-ZRX/` porque el sandbox solo deja escribir bajo el directorio de lanzamiento; **no escribas en ningún
  otro directorio de `P-ZRX/`**.
- **Objetivo único:** que los oráculos T01 y T04 implementen `P-ZRX/P-SLASHING/CONTRATO-EVIDENCIA-v0.md`
  **con su «Ratificación v0»** (que prevalece), y exportar vectores que el código Rust de SL-4 tenga que
  reproducir.
- **Pregunta falsable:** «Con evidencia y castigo, las invariantes de T01 (I-1…I-7) y de T04 (IE-1…IE-6)
  siguen sin fallos —con la conservación ampliada a lo quemado y a la recompensa del incluidor—, cada
  incidente se aplica una sola vez en cualquier orden de llegada y tras cualquier reorganización, y ninguna
  liberación escapa a una falta cuya ventana sigue abierta (RAT-3).»

## 2. Decisiones del director

1. **T01 (máquina de estados):** tipo de operación `Evidencia` (dos cabeceras abstractas con identidad
   `(cbid, clave, sector, historia, chunk, slot)`, contenidos distintos y sellos válidos o no); registro de
   incidentes; congelación total (EV-17); confiscación `C = mín(V, techo(f·V))`; `techo(C·2/8)` a la coinbase
   del bloque que aplica y el resto quemado (RAT-2); regla de liberación de RAT-3; clave sin saldo ⇒ pérdida
   cero (EV-22); evidencia fuera de plazo descartada (EV-14); `cbid` distinto ⇒ no admisible (RAT-1).
   Undo exacto por copia íntegra, como hoy.
2. **T04 (DAG):** deduplicación en modo fusión (la segunda evidencia del mismo incidente queda inerte sin
   invalidar su bloque, EV-12); aplicación única tras reorganizaciones (EV-27/EV-28); la evidencia sigue
   el punto de aplicación de RD-4.
3. Ids de salida por contenido, como en T01-E (la recompensa del incluidor va a la coinbase del bloque, no
   crea una salida con contador).
4. **Casos dirigidos:** todos los de la lista del contrato (§ «casos que el oráculo de SL-3 tendrá que
   reproducir») más: la carrera de RAT-3 (retiro parcial, producción continuada y doble firma cerca del final
   de la retención: la liberación **no** se aplica), evidencia con `cbid` ajeno, autodenuncia (el infractor
   pierde `6/8·C`), y dos evidencias del mismo incidente en ramas hermanas.
5. **Generadores aleatorios con evidencia**, y **tabla de cobertura obligatoria** por tipo de evidencia
   (aplicada, inerte por duplicado, fuera de plazo, `cbid` ajeno, contra clave sin saldo, deshecha por
   reorganización) con **mínimos**: ≥ 100 aplicadas, ≥ 30 de cada otro tipo, en los vectores exportados.
6. Parámetros: rejillas pequeñas como las actuales, con `f ∈ {1/2, 1}` y las ventanas en slots.

## 3. Verificación

| Paso | Qué | Criterio |
|---|---|---|
| V1 | `Pkg.test()` de T01 y de T04 | todo en verde |
| V2 | `run.jl` de T01 (rejilla reducida, semilla `0x5a5a`) y de T04 (`--replicas 200`) | 0 fallos de invariantes, con la conservación ampliada |
| V3 | Vectores `vectores-transicion-v0.3.txt` (T01) y `vectores-estado-dag-v0.4.txt` (T04) con `.sha256` | relectura independiente con 0 discrepancias; los anteriores intactos |
| V4 | Tabla de cobertura | mínimos del §2.5 cumplidos |

**Prohibido Python.** Presupuesto: 2 h, 1 hilo, 8 GiB. Secciones «SL-3» en los `INFORME.md` y `PROGRESO.md`
de cada zona; `HORAS.log` con `date -Is` real. DeepSeek `deepseek-flash`, esfuerzo `high`; LINEO; sin commit
ni push; sin secretos. Entrada congelada `P-ZRX/P-SLASHING/ENTRADA-SL3.sha256`.
