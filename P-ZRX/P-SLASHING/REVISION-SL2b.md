# REVISIÓN SL-2b — recalibración con 2/8 para quien incluye la evidencia

**Revisor:** Claude (director). **Fecha:** 2026-09-26. **Ejecutor:** DeepSeek (Julia), 18:34–18:44.
Evidencia: `P-ZRX/P-SLASHING/SL2/` (sección «SL-2b» del informe, `DEFINICIONES-FALTANTES-SL2b.md`,
`resultados/*-s2*.csv`). **Veredicto: ACEPTADA.** Pregunta falsable **confirmada**.

## Comprobado por el director

- `HUELLAS.sha256` de la zona en verde. `Pkg.test()` 97/97 (39 de SL-2 + 58 nuevos). Con `s = 0` se
  regeneran los once CSV de SL-2 con **hash idéntico** (el modelo nuevo contiene al anterior).
- **Integridad de la entrada:** `ENTRADA-SL2b.sha256` da 4/5 porque **el director** editó `DECISIONES.md`
  a las 18:40 (registrar DS-L04) con la orden en marcha; el ejecutor lo atribuyó a Katana. Es un error mío
  (editar un archivo congelado durante la ejecución); no toca DS-L03, que es lo que gobierna SL-2b.

## Resultado

- Caso central (reparto real de DS-6), `ε_h ≤ 10⁻³`: el atacante **confabulado** con quien incluye **no gana
  ninguna celda**; las 40 de 11 520 que se pierden son todas sin firmante seguro (`ε_h = 10⁻¹`), `V = 10⁶`,
  `α = 0,40`.
- La autodenuncia nunca es rentable: el infractor pierde `(1 − 2/8)·C + c_r > 0`.
- Censura: si una fracción `c` de la producción censura la evidencia y solo cuenta un productor, el
  horizonte necesario crece con `c` y la región se vacía con `c = 1`; si cualquier productor honesto de la
  ventana puede incluirla, la censura parcial queda neutralizada.
- **Valores para la red dev (no producción):** perfil principal **sin cambios** (`ρ_ret = 0,10`,
  `T_v = 10⁵` slots ≈ 1,2 días, `f = 1`, `R_slots ≥ F_slots`, `q = 20`); el robusto sube de `9·10⁵` a
  `1,2·10⁶` slots (≈ 14 días) con 2/8.
