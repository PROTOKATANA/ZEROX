# ORDEN-DS6 — Cómo se reparte el espacio entre claves en redes reales de espacio

- **ID:** DS-6. **Fecha:** 2026-09-26. **Director:** Claude. **Ejecutor:** subagente Sonnet (web y
  datos públicos; aritmética en Julia si hace falta, nunca Python). **Marco:** `MARCO.md`.
- **Zona (única escribible):** `/home/katana/zeo/ZEROX/deepseek/DS6/`.
- **Motivo:** DS-3 §4.7: el parámetro que decide si el castigo con evidencia llega a morder al atacante
  de A1 es la **forma de la distribución de tamaños de clave** (`dist_alpha`, la cola de claves
  pequeñas: cambio relativo 0,637 de `B(ε)` entre 2,05 y 3,0), y es una hipótesis (H3) sin medir.
- **Pregunta falsable:** «En al menos una red pública de prueba de espacio (Chia, Autonomys u otra),
  los datos disponibles permiten estimar la cola de la distribución de espacio por clave o por granjero
  con un intervalo que caiga dentro o fuera del rango 2,05–3,0 usado por DS-3.»

## Qué hacer

1. Buscar datos públicos con fecha: exploradores, estadísticas de pools, estudios académicos o de la
   propia red sobre espacio por granjero o por clave (Chia: *plot NFTs*, pools, *netspace*; Autonomys:
   operadores y granjeros). Declarar qué mide cada fuente (clave, granjero, pool) y sus sesgos.
2. Si hay datos suficientes, ajustar la cola (p. ej. ley de potencias por máxima verosimilitud, con
   intervalo) en Julia **dentro de la zona**; si no, decir exactamente qué falta.
3. Traducir el resultado a la sensibilidad de DS-3 (`resultados-DS3`… `DS3/resultados/sensibilidad-A1.csv`):
   ¿con la cola observada, el castigo muerde o sigue en la grieta?

Entregable `deepseek/DS6/INFORME.md` con fuentes (URL, fecha, etiqueta), datos crudos guardados en la
zona con `sha256`, método y resultado. Solo lectura fuera de la zona; **sin subagentes ni forks**; sin
git; sin Python; sin credenciales. Presupuesto: 2 h.
