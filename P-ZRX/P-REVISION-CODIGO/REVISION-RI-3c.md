# REVISIÓN RI-3c — revisión independiente de la lógica del nodo (tras W06d5)

**Revisor de la revisión:** Claude (director). **Fecha:** 2026-09-27 (≈ 01:00). **Ejecutor:** subagente Sonnet,
00:40–00:57, sobre `de26376`. Evidencia: `resultados-RI-3c/` (informe y diff del test de reproducción).
**Veredicto: ACEPTADA.** Un hallazgo **crítico** confirmado, uno medio plausible. Puerta de garantía, padres
extra y doble firma tras reinicio o reorganización: sin hallazgos.

| # | Hallazgo | Comprobación del director | Decisión |
|---|---|---|---|
| H1 (crítica, CONFIRMADO) | `admitir_pow_interno` (`crates/zx-node/src/nodo.rs:493-506`) y `admitir_post_interno` (`:746-758`) **persisten** el bloque y **después** llaman a `cadena.admitir`; si este lo rechaza (motivo legítimo: `ErrGarantia`, `ErrMergeDepth`, `ErrU2`, `ErrEmision`…), la entrada queda en el almacén, la repetición del reinicio la vuelve a admitir, falla, y **el nodo no vuelve a arrancar**. Afecta a bloques propios y de red: un solo bloque verificable pero inadmisible, de un par honesto por una carrera o de uno hostil, deja al nodo sin reinicio. Reproducido: un PoW real con coinbase mayor que el subsidio persiste (registro de 1 a 2) y el segundo `arrancar` falla | Leído: el orden es el descrito y no hay deshacer. **El orden lo introdujo la corrección de RI-2b** (dirigida por el director), que buscaba evitar la doble firma tras reinicio: el remedio era correcto en su objetivo y equivocado en su forma. Lo que RI-2b temía era **difundir** antes de persistir, no admitir antes de persistir | **Corregir en W06d6 (paso previo):** orden **admitir en `zx-cadena` → persistir → difundir**, en bloques propios y de red y en las dos familias; un bloque rechazado **nunca** se persiste. Si el proceso muere entre admitir y persistir, el bloque no salió del nodo: una segunda firma de ese slot no es observable (y, con SL-4b2, el firmante seguro la impide). El test de RI-3c pasa a regresión, más un punto de inyección de fallo entre admitir y persistir que compruebe que nada se difunde |
| H2 (media, PLAUSIBLE) | `clasificar_cabecera_pendiente` (`crates/zx-node/src/rechazo.rs:113-118`) trata `PruebaPotIncoherente` y `RangoSinAtadura` como `Pendiente` (reintento indefinido), aunque `zx-post` las documenta como imposibles por construcción: no son falta de contexto local | Leído | **Corregir en W06d6:** bloque de red → rechazo **sin** penalizar al par (puede ser un fallo nuestro); bloque propio → `Interno` (fatal) |

**Lección de método:** una corrección que cambia el orden de dos efectos (memoria y disco) necesita su propio
revisor y un test de la rama de fallo de **cada** efecto; RI-2b se corrigió dentro de W06d2 sin eso.
