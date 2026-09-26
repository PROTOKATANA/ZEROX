# Revisión del director — W05b1 (2026-09-26)

**Veredicto: SUPERADO y migrado a la raíz** (02:32). DeepSeek, 02:10–02:31.

Crates `zx-poas` (verificador PoAS = `poas.rs` antiguo byte a byte; historia génesis D-P12;
protocolo dev; reto puro) y `zx-farmer` (plotter/auditor y conversión de candidatos antiguos). De
extremo a extremo: génesis dev → historia de un segmento → sector ploteado con una clave dev → 3/3
soluciones aceptadas por `verify_solution` real; 10/10 negativos rechazados con su error.
`COMPROMISO_HISTORIA_GENESIS_DEV = 8126fdbe…29f24af9` congelado y recalculado por dos caminos.
415 tests; lock: +88 pares, todos con la versión del lock de `9681061`.

Decisión del ejecutor aceptada: la función pura `reto_desde_salida` (blake3 de salida PoT y slot)
se porta a `zx-poas::reto` para no cruzar la frontera de crates. **W05b2 debe usar esa misma función**
(no duplicarla en el módulo PoT).

Migración: base idéntica a la raíz; el enlace `ws/PDF` (al clon real de la raíz) se excluyó de la
copia; `MIGRACION.sha256` (103 archivos) verificado en la raíz.

**No demuestra:** PoT, cabecera conjunta, sello, admisión, historia de más de un segmento,
parámetros de red.
