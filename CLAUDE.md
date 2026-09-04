# ZEROX — workspace de código

**Este directorio contiene solo el código.** La documentación del proyecto vive en el vault de
Obsidian, en un árbol separado.

## Fuente de verdad — leer ANTES de tocar nada

| Archivo | Qué contiene |
|---|---|
| `SPEC.md` (aquí) | **Las 118 reglas de consenso numeradas.** Es el contrato. Nada se implementa sin su regla `C-XXX` |
| `/home/katana/zeo/NODOS/ZEROX/CLAUDE.md` | **Las reglas de trabajo completas.** Regla de investigación previa, arquitectura de agentes, política de modelos |
| `/home/katana/zeo/NODOS/ZEROX/DECISIONES.md` | Decisiones de arquitectura con su porqué, y los hallazgos de auditoría (H-001..H-004) |
| `/home/katana/zeo/NODOS/ZEROX/PREGUNTAS-PARA-KATANA.md` | Decisiones abiertas y cerradas, P-001..P-020 |
| `/home/katana/zeo/NODOS/ZEROX/PROGRESO.md` | Bitácora cronológica |
| `/home/katana/zeo/NODOS/ZEROX/CARACTERISTICAS.md` | Hoja de características y de dónde viene cada una |
| `research/` (aquí) | 13 informes con fuente primaria verificada. **La memoria de los agentes** |

⚠️ `ZEROX.md` y `Sin título.md` del vault son notas en crudo de Katana. **NO SE MODIFICAN.**
`Sin título.md` está **obsoleta** (describe un diseño v1 descartado: modelo de cuentas, sin pool dual).

## Lo no negociable, resumido

1. **Investigar antes de implementar.** Fuente primaria: spec oficial > estándar numerado > código de
   referencia > paper. **Nunca de memoria.** Si no se encuentra, se declara laguna, no se supone.
2. **No inventar reglas ni números de consenso.** Si falta una decisión, va a
   `PREGUNTAS-PARA-KATANA.md` y se continúa con lo que no dependa de ella.
3. **Sin commits ni `git push`** sin pedirlo.
4. Si el SPEC es ambiguo o incorrecto:
   `DETENER → INVESTIGAR → PROPONER CAMBIO → ACTUALIZAR SPEC → CONTINUAR`.
5. **Adoptar cripto auditada sin modificar.** Jamás reimplementar una primitiva.
6. Todo código de consenso **cita su regla `C-XXX`** en un comentario.

## Código antiguo — está AQUÍ, rastreado, no en la papelera

Este repositorio (`git@github.com:PROTOKATANA/ZEROX.git`) ya contenía el trabajo original de Katana
antes del rediseño, y sigue rastreado en `main`:

- **`caliza/`** — minero C++/HIP. `src/titanio/sha3.h` es el origen de **H-001**: no implementa
  SHA3-256 ni Keccak-256, sino `KECCAK-p[1600,24]` crudo sin padding ni separación de dominio.
  **0 de 237 vectores CAVP pasan.** Se consulta para **no repetir el error** y para portar la
  estructura del minero, **nunca para copiar el kernel**.
- **`silicio/`** — lado CPU en Rust. `src/minero.rs:19,157` frente a `caliza/src/excavadora.cc:73`
  es la divergencia de preimagen CPU↔GPU documentada en `research/sha3-kernel-audit.md`.

Ambos serán sustituidos: `caliza` por `crates/zx-miner` (Fase 8) y `silicio` por el nodo Rust.
Hasta entonces se quedan como referencia viva.

`/home/katana/zeo/.trash/ZEROX/` es una **copia de respaldo** del repositorio en el mismo commit
(`ee7d443`), no la fuente. Si alguna ruta de este documento no resuelve, mira aquí primero, no allí.

## Estado

Fase 0 completa. `SPEC.md` v0 en revisión. Empezando `zx-core`.
Bajo control de versiones: `git@github.com:PROTOKATANA/ZEROX.git`, rama `main`.
El workspace nuevo (`crates/`, `SPEC.md`, `research/`, `testdata/`) está **sin commitear todavía**.
