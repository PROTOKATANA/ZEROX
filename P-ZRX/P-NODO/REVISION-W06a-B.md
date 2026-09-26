# REVISIÓN W06a-B — diferenciales sin emulación contra T01-E y T04-D

**Revisor:** Claude (director). **Fecha:** 2026-09-26. **Ejecutor:** DeepSeek, 05:30–06:16.
Evidencia: `resultados-W06a-B/`. **Veredicto: SUPERADO. Migrada** (base idéntica a la raíz;
`MIGRACION.sha256`, 190 archivos, verificado; lock idéntico). **Levanta la reserva de
`REVISION-W06a`**: el estado del DAG en Rust queda validado contra el oráculo T04.

## Comprobado por el director

- `ENTRADA-W06a-B.sha256` 9/9. `grep` de `forzad`, `colision` y `prox_salida` en los dos arneses de la
  raíz tras migrar: 0 apariciones.
- Informe: V0 = suite de la raíz sin cambios, 680/0/2; V3 igual con los arneses nuevos;
  `diferencial_t01` 0 discrepancias en 2 055 + 3 914 casos (v0.2); `diferencial_t04` 0 en 914 (v0.3);
  cobertura del arnés idéntica a `cobertura-v0.3.txt`.

## Hallazgo del ejecutor, ratificado

Otra no inyectividad del modelo abstracto: dos transferencias con las **mismas entradas y las mismas
salidas en valor y dueño** pero ids abstractos de salida distintos son, en el formato real, **la misma
transacción** (mismo `txid`, mismo `OutPoint`), mientras el oráculo las trata como distintas. Sin
corregir, 2 de 914 casos divergían (304 y 567). El arnés fija `sequence` de las entradas al id
abstracto de la primera salida: las transacciones reales pasan a ser distintas, como en el oráculo,
sin inventar entradas y sin tocar el motor (`sequence` está en el `txid` y el motor no lo interpreta).
Es una traducción fiel de «dos transacciones distintas», no una emulación de un resultado.
**Consecuencia para el diseño (derivación):** en la red real, dos transacciones idénticas publicadas
en ramas hermanas **son una sola** y su salida existe en ambas; el oráculo no lo modela porque su
generador no produce contenido idéntico a propósito. No afecta a la seguridad de 0.0.1.
