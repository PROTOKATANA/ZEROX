# PROCEDENCIA — propuesta `C-POT-01…08`

Redactada por **DeepSeek** en `P-POT/propuesta/` según `P-POT/ENCARGO.md` (copia congelada en `ENTRADA/`).
**Validada por Claude el 2026-09-20.** Comprobado: entrada íntegra; 45 citas con ruta existen y caen dentro
de su archivo; abiertas por el validador las de Autonomys (`pot.rs:278-295`, `lib.rs:110-112`,
`subspace-verification/src/lib.rs:444-446`, `verifier.rs:259-262`, `digests.rs:63-65`) y `SPEC.md:2552`;
vectores V1–V5 reproducidos (**4/4**). **Decidido por Katana:** D-1 = A (conservar `blake3` byte a byte),
D-2 = A (`pot_output` = salida futura). **Corrección pendiente al pasar al SPEC:** en C-POT-05, «la
justificación de `B` no basta» es demasiado pesimista: como los padres se validan antes que el hijo, la
salida del slot sale siempre del pasado validado (de la justificación de `B` si `d > D`, o de un ancestro).
