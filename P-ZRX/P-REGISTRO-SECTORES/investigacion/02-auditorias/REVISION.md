# Revisión del director — S02a / encargo 02 de sectores, parte a (2026-09-26)

**Veredicto: aceptado.** La hipótesis esperada por RFT-04 se confirma con medición real: **auditar
aperturas sobre R2 encarece mucho no guardar el sector, pero no lo impide** (DeepSeek, 02:10–02:50).

- Regeneración real (tabla PoS por la ruta paralela + erasure coding + enmascarado), cotejada byte a
  byte con el sector (0 discrepancias) y 1 080/1 080 aperturas medidas verificadas contra R2.
- `t_reg` (tabla + codificación de un registro): **~0,90 s con 1 hilo, ~0,16 s con 16** (eficiencia
  36 %: cuello de memoria). Concuerda con el orden de magnitud antiguo de P-INTENTO (~0,8 s por
  intento, otra fecha y carga).
- Latencia por apertura (16 hilos): leer del disco 0,2–0,3 µs; sin el sector 0,17–4,1 s según
  estrategia y tamaño: **8,8·10⁵ a 1,35·10⁷ veces** más. Guardar solo niveles altos del árbol ahorra
  ~0,8 % del sector y ya paga `≥ t_reg`: la curva es un acantilado, no un compromiso gradual.
- **Coste absoluto para el adversario (derivación del director):** contestar `m` aperturas por
  auditoría de un sector de `p` registros sin guardarlo cuesta del orden de `m · c · 0,9` segundos-núcleo
  (`c ≤ p` registros distintos), paralelizable entre núcleos. Con un plazo de respuesta de varios
  segundos y núcleos suficientes, **se puede contestar a tiempo**: es un precio, no una barrera.

**Límites:** carga ajena durante las series de 16 hilos (carga 5–14; medianas estables, p99 con
cautela); GPU/ASIC sin medir (`ab-proof-of-space-gpu` existe); descarga de piezas gratuita por
supuesto; tamaños de fixture (2–16 registros). Plazos y falsos positivos → S02b.
