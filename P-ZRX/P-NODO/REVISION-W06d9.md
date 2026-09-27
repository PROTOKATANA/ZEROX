# REVISIÓN W06d9 — el productor ya no muere por falta de un portador PoT

**Revisor:** Claude (director). **Fecha:** 2026-09-27 (≈ 19:41). **Ejecutor:** DeepSeek, 18:23–19:39. Evidencia:
`resultados-W06d9/`. **Veredicto: SUPERADO. Migrada** (3 archivos; base sin cambios desde `c539605`; huellas en verde).

**Causa exacta** (hallada por el ejecutor, con reproducción): al admitir un bloque de red que salta slots, el nodo solo
registraba en su `ServicioPot` el **último** portador de la justificación (verificada) y fijaba `slot_actual` al slot
del bloque, dejando **huecos** (`crates/zx-node/src/nodo.rs` ≈ 1257, 1277); el hilo productor clona ese servicio y solo
avanza hacia delante; si un bloque con hueco pasaba a ser padre seleccionado, `portadores_para` devolvía
`PortadorAusente` y el productor salía con `fallo_productor` (hallazgo de W07b R3, nodo C, slot 6). Intermitente.

**Corrección:** en el origen, se registran **todos** los portadores de la justificación, cada uno en su slot; red de
seguridad, `portadores_para` completa los huecos recalculando de forma determinista (mismo cálculo que `avanzar`,
acotado) y, si no puede, el productor emite `produccion_omitida` y sigue. Sin cambios de consenso.

**Pruebas:** test que reproduce `PortadorAusente { slot: 6 }` antes y pasa después; recálculo byte a byte contra
`avanzar`; **10/10** tres nodos reales hasta el slot 60 y **3/3** particiones E-6 con aislamiento real verificado
(0 contactos): **0 `fallo_productor`, 0 pánicos, 0 `produccion_omitida`**. `fmt`, `clippy -D warnings`, **877/0/6**,
T01/T04, guardianes.

**Consecuencia para W07b:** R1 y R2 se midieron con `26312ff` (no se dio el caso); R3 y R4 se miden con el nuevo
candidato.
