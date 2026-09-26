# ORDEN-DS5 — Castigo correlacionado (M4) contra el doble farmeo y la equivocación

- **ID:** DS-5. **Fecha:** 2026-09-26. **Director:** Claude. **Ejecutor:** subagente Sonnet (análisis;
  aritmética de comprobación en Julia si hace falta, nunca Python). **Marco:** `MARCO.md`.
- **Zona (única escribible):** `/home/katana/zeo/ZEROX/deepseek/DS5/`.
- **Motivo:** `SINTESIS.md` §4: M4 es la única vía de PoStake contra A1 que nunca se ha examinado
  (celdas «no evaluado» de DS-2 y DS-3).
- **Pregunta falsable:** «Existe una forma de castigo correlacionado (la sanción crece con la fracción
  de garantía que comete la misma falta en la misma ventana) que encarece de forma **exigible** A1 o
  A2 frente al atacante grande de DS-3, sin elevar el castigo esperado de un honesto con fallos
  correlacionados (misma versión de software, mismo proveedor) por encima de su ingreso.»

## Qué hacer

1. Fuentes: la penalización correlacionada de Ethereum (fórmula, ventana, casos reales) y cualquier
   propuesta análoga en sistemas de espacio (DS-1 como punto de partida); cita y fecha.
2. **Antes de nada**, responde por escrito si M4 elimina la premisa de RFT-01 y de la «grieta» de DS-3
   (el atacante que no publica no deja evidencia; el que rota claves pequeñas no tiene saldo). Si no la
   elimina, dilo y acota qué parte del ataque sí alcanza.
3. Modelo: con los símbolos de `resultados-DS2/MODELO.md` y los escenarios de `DS3/escenarios.tsv`,
   coste de X y coste del honesto correlacionado (C-05) para al menos dos formas de M4; celda por celda
   con los veredictos del marco.
4. Efectos adversos: castigo a honestos correlacionados (fallo de software común), denuncias falsas,
   incentivos a la concentración.

Entregable `deepseek/DS5/INFORME.md`. Solo lectura fuera de la zona; **sin subagentes ni forks**; sin
git; sin Python; sin credenciales. Presupuesto: 2 h.
