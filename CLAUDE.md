# ZEROX — workspace de código

**Este directorio contiene solo el código.** La documentación del proyecto vive en el vault de
Obsidian, en un árbol separado.

## Fuente de verdad — leer ANTES de tocar nada

| Archivo | Qué contiene |
|---|---|
| `SPEC.md` (aquí) | **Las 166 reglas de consenso numeradas.** Es el contrato. Nada se implementa sin su regla `C-XXX` |
| `/home/katana/zeo/NODOS/ZEROX/CLAUDE.md` | **Las reglas de trabajo completas.** Regla de investigación previa, arquitectura de agentes, política de modelos |
| `/home/katana/zeo/NODOS/ZEROX/DECISIONES.md` | Decisiones de arquitectura con su porqué, y los hallazgos de auditoría **H-001..H-007** |
| `/home/katana/zeo/NODOS/ZEROX/PREGUNTAS-PARA-KATANA.md` | Decisiones abiertas y cerradas, **P-001..P-031** |
| `/home/katana/zeo/NODOS/ZEROX/PROGRESO.md` | Bitácora cronológica |
| `/home/katana/zeo/NODOS/ZEROX/CARACTERISTICAS.md` | Hoja de características y de dónde viene cada una |
| `/home/katana/zeo/NODOS/ZEROX/PLAN-CRATES.md` | **El plan de ejecución crate a crate** hasta la beta, con la definición de terminado y el orden de dependencia |
| `research/` (aquí) | 17 informes con fuente primaria verificada. **La memoria de los agentes** |
| `PDF/` (aquí) | **Las fuentes primarias de Chia, en local.** Greenpaper, paper de compromisos tiempo-memoria, whitepaper de negocio, y el repositorio `chia-blockchain` **v2.7.4** clonado entero. Se leen **antes** que buscar en la web: están anclados a una versión concreta y la web no |

⚠️ `ZEROX.md` y `Sin título.md` del vault son notas en crudo de Katana. **NO SE MODIFICAN.**
`Sin título.md` está **obsoleta** (describe un diseño v1 descartado: modelo de cuentas, sin pool dual).

## Lo no negociable, resumido

1. **Investigar antes de implementar.** Fuente primaria: spec oficial > estándar numerado > código de
   referencia > paper. **Nunca de memoria.** Si no se encuentra, se declara laguna, no se supone.
2. **No inventar reglas ni números de consenso.** Si falta una decisión, va a
   `PREGUNTAS-PARA-KATANA.md` y se continúa con lo que no dependa de ella.
3. **Commits sí; `git push` no** sin pedirlo.
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

## ⚠️ Cambio de consenso en evaluación — PoW → Proof of Space and Time

**2026-09-05.** Katana ha decidido cambiar el consenso de Proof of Work (SHA3-256) a **Proof of
Space and Time**, al estilo Chia. Está en fase de investigación con fuente primaria; nada
implementado todavía.

Lo verificado hasta ahora, leyendo `PDF/ChiaGreenPaper.pdf` directamente:

- El umbral es **≈61,5 %** de espacio honesto, **peor que el >50 % de Bitcoin**. La causa es el
  *double dipping*: el espacio se puede reutilizar para probar varias cadenas a la vez, y el
  trabajo no.
- Ese 61,5 % **no sale solo del diseño**: sin la contramedida haría falta **73,1 %**. Baja a 61,5 %
  porque los granjeros honestos también hacen *double dipping*, sobre los `κ = 3` mejores caminos.
- Y `κ` **no es parte de la especificación**: es una *convención social* entre granjeros. Cita
  literal del paper, Remark 1.
- El análisis idealiza cuatro cosas que en producción son falsas, y una es crítica: supone que las
  pruebas de espacio **no admiten ningún compromiso tiempo-memoria**.

**Consecuencia inmediata:** H-001 deja de estar en el camino crítico. El kernel SHA3 en GPU ya no
es el minero.

**Qué sobrevive:** `zx-storage` entero —el UTXO set no sabe qué consenso hay encima—, `zx-p2p`,
`zx-mempool`, el modelo de transacciones y direcciones. Lo que cambia es el núcleo de consenso.

Agente dedicado: **`zx-chia`**, que lee el clon local y traduce Python y C++ a decisiones.

## Estado — 2026-09-05

Rama `rediseno/v1-spec-first`, **59 commits**, sin publicar. `git@github.com:PROTOKATANA/ZEROX.git`.

```
449 tests + 36 con rocksdb · fmt · clippy -D warnings limpio · 166 reglas C-XXX
```

| Crate | Estado |
|---|---|
| `zx-core`, `zx-consensus` | completos para el pool transparente |
| `zx-p2p` | falta el resto de BIP 152 y el peer scoring |
| `zx-node` | valida cabeceras a fondo y descarga cuerpos; **no valida transacciones todavía** |
| `zx-storage` | **B1 terminado**: UTXO set persistente, escritura atómica, test de `kill -9` |
| `zx-mempool` | completo y sin cablear |
| `zx-rpc`, `zx-wallet`, `zx-miner`, `zx-lightwalletd`, `zx-scanner` | vacíos |

**Dos guardianes de CI** que hay que respetar, porque encuentran cosas:
`ci/alcance-consenso.sh` (código que nadie ejecuta) y `ci/citas-spec.sh` (reglas que nadie cita).

**Cero preguntas bloqueadas.** El siguiente paso planificado era B2 —que el nodo valide dinero—,
ahora en revisión por el cambio de consenso.
