# P-SLASHING — Programa para activar evidencia y castigo en ZEROX

**Fecha:** 2026-09-26. **Director:** Claude. **Origen:** Katana, 2026-09-26: crear y lanzar el encargo que
diseñe la transacción de evidencia, el firmante seguro y la calibración contra falsos positivos, para
activar el *slashing*.

## Por qué (`P-ZRX/P-DISUASION/SINTESIS.md`)

El castigo con evidencia más retención (M3 + M5) es una **mejora real, condicionada**: encarece el ataque
del atacante pequeño y del que necesita reclutar espacio ajeno (con el espacio concentrado como en un pool
real de Chia, DS-6). No alcanza al atacante grande autosuficiente, que no deja evidencia. El castigo
**correlacionado** (M4, `C-SLA-03`) queda **descartado**: no añade disuasión y castiga a honestos con fallos
comunes (DS-5). Hoy nada de esto está implementado (IPA C-04, C-05, C-08, C-09); `EvidenceTx` es la
versión 4 reservada e inactiva de `FORMATO-v0.md`.

## Límites que fija el mandato (`AUTO-ZRX.md` §90–91, §102)

Solo se castiga lo **demostrable con evidencia pública**: la doble firma (`C-EVP-02`). **Ninguna ausencia**
(auditoría fallida, bloque no producido) activa castigo automático sin semántica y tasa de falsos
positivos demostradas. Suspensión de elegibilidad y confiscación son consecuencias distintas. No se
importan porcentajes de otro PoS.

## Encargos

| ID | Qué | Ejecutor | Depende de |
|---|---|---|---|
| SL-1 | Contrato de evidencia y castigo v0 (formato de `EvidenceTx`, verificación, incidente único, plazo, reorganización, congelación, confiscación, destino de fondos, retiro) y especificación del firmante seguro | Sonnet | — |
| SL-2 | Calibración: región de parámetros que disuade al que recluta y acota la pérdida esperada del honesto, con y sin firmante seguro | DeepSeek (Julia) | — (usa DS-3 y DS-6) |
| SL-3 | Oráculo Julia de evidencia en el DAG (extiende T04) y vectores | DeepSeek | SL-1 ratificado |
| SL-4 | Implementación Rust: `EvidenceTx` (v4) en `zx-core`, reglas en el motor, firmante seguro y detección/envío de evidencia en `zx-node`; diferencial contra SL-3 | Sonnet | SL-1, SL-3 |

SL-3 y SL-4 se redactan cuando SL-1 esté ratificado: el contrato puede cambiar su alcance.
