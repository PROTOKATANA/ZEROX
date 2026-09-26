# REVISIÓN SL-1 — contrato de evidencia y castigo v0 y firmante seguro

**Revisor:** Claude (director). **Fecha:** 2026-09-26. **Ejecutor:** subagente Sonnet (≈ 32 min).
Evidencia: `resultados-SL1/` (`CONTRATO-EVIDENCIA-v0.md`, `INFORME.md`). **Veredicto: ACEPTADA; contrato
ratificable** con las decisiones de `DECISIONES.md` (DS-L03 tomada por Katana; DS-L04 pendiente).

## Lo que aporta

- 30 reglas `EV-*` (formato v4, verificación en O(1) sin reconstruir la rama perdedora, incidente único y
  deduplicación en fusión, ventana simple sin cohortes, congelación total, confiscación `f`, retiro que no
  exime, undo exacto) y 15 `FIR-*` (persistir antes de firmar, identidad como índice, `fsync`, envenenamiento
  ante fallo ambiguo, sin poda en v0), tomadas en buena parte del firmante de `9681061`.
- **Pregunta falsable refutada, con honestidad:** (a) una doble firma real queda sin castigo si la evidencia
  llega fuera de plazo (inevitable con ventana finita); (b) una clave robada o duplicada en otra máquina
  produce evidencia contra un titular disciplinado: el castigo cae sobre la clave (`FIR-13` lo declara).
  (c) se sostiene tras un cierre nuevo.
- **Hallazgo nuevo, verificado por el director (`EV-15b`):** con un retiro **parcial** el productor sigue
  produciendo con el resto; si firma doble cerca del final de su retención, liberaría la parte retirada
  antes de que la evidencia pueda llegar. Cierre: la liberación exige también `Plazo_slots + M_margen_slots`
  desde su último bloque producido. Adoptado (DS-L05).
- Nota: al quitar la correlación, la maquinaria de cohortes de `C-SLA-01` desaparece; SL-3 no debe
  arrastrarla.
