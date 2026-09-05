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
| `PDF/` (aquí) | **Fuentes primarias de Chia, en local — con la salvedad de abajo.** Se leen **antes** que la web: están ancladas a una versión y la web no |

### ⚠️ Estado real de cada fichero de `PDF/` — comprobado el 2026-09-05

| Fichero | Estado |
|---|---|
| `ChiaGreenPaper.pdf` | **ES EL DOCUMENTO EQUIVOCADO.** Precursor de jul. 2019, diseño **nunca implementado**. De aquí salió el 61,5 %. El vigente (12 jun 2026) **no está en local**: se descarga de `docs.chia.net/files/ChiaGreenPaper_20260612.pdf` |
| `chia-blockchain/` v2.7.4 | Leído. Informe en `research/chia-parcelas-comprimidas.md` |
| `time-memory-tre-off-proof-space.pdf` | Informe en `research/time-memory-tradeoff.md` |
| `Chia-Business-Whitepaper-2022-02-02-v2.0.pdf` | **Sin leer.** Documento de negocio; no se ha necesitado para consenso |

**La versión es parte de la cita.** Y con el código, la lección equivalente: comprobar que la rama
está **activa**. `HARD_FORK2_HEIGHT = 0xFFFFFFFA` significa que Proof of Space 2.0 existe en el
repositorio y **no corre en ningún nodo**.

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

## ⚠️ Cambio de consenso DECIDIDO — PoW → Proof of Space and Time (Autonomys)

**2026-09-05.** Fuera Proof of Work. Dentro **Proof of Space and Time**, variante **Autonomys**
(antes Subspace), no Chia. Decidido con los cinco informes delante; el detalle y el porqué están en
`DECISIONES.md §14` y en `research/proof-of-space-tiempo.md`.

| | Elegido |
|---|---|
| Familia | **Autonomys / Proof of Archival Storage** — Rust puro, sin C++ ni GMP |
| Granjero objetivo | **PC dedicado con disco** |
| Timelord | **Lo operamos, con diseño abierto** |
| Pool blindado | **Sí, después de la beta** — sin cambios |

Lo decisivo fue el Proof-of-Time: el de Autonomys es Rust puro (`aes`, `no_std`, 0BSD); el de Chia
obliga a C++ y GMP en la ruta de consenso de **todos** los nodos, y no existe ningún vector de
interoperabilidad entre implementaciones de VDF de grupos de clases — H-001 otra vez.

**Lo que se paga:** su verificación **no es sucinta**, recomputa una cadena AES en paralelo. Todo el
anti-DoS (`C-NET-03`, `C-NET-04`) se calibró asumiendo que validar cuesta un SHA3. Hay que medirlo.

**El hueco nuevo:** PoAS ata el espacio a la historia archivada de la cadena, y una cadena nueva no
tiene historia. Cómo arranca en el bloque 1 es la primera pregunta de diseño.

Agentes: **`zx-autonomys`** para la implementación de referencia, **`zx-chia`** para la teoría y el
algoritmo de pruebas de espacio que Autonomys reimplementa.

### El contexto de por qué NO Chia, que sigue siendo válido

### ⚠️ El PDF de `PDF/ChiaGreenPaper.pdf` describe un diseño que Chia NUNCA implementó

Verificado en la web oficial de Chia: ese documento se publica allí como
**`Precursor-ChiaGreenPaper.pdf`**, y el greenpaper vigente dice de él, textualmente, *"a precursor
consensus **which was never implemented**"*. Es de julio de 2019. **El greenpaper vigente es del 12
de junio de 2026.**

De ahí sale el 61,5 %, y por eso no es el número que protege a Chia:

| | Atacante | Honesto |
|---|---|---|
| Precursor 2019, sin contramedida | 26,9 % | 73,1 % |
| Precursor 2019, con `κ=3` | 38,5 % | **61,5 %** ← el número citado |
| **Desplegado** | ver abajo — **no es un porcentaje** | |

### La condición de seguridad REAL, del greenpaper vigente

```
Chia is provably secure if:  space_h · vdf_h  >  space_a · vdf_a · 1.47
```

**No es una fracción de espacio: es un producto de espacio POR velocidad de VDF.** El espacio
honesto necesario depende de lo rápido que sea el timelord del atacante:

| VDF del atacante | Espacio honesto necesario |
|---|---|
| igual que el honesto | 59,5 % |
| 2× más rápido | **74,6 %** |
| 3× más rápido | **81,5 %** |
| 10× más rápido | 93,6 % |

Bitcoin necesita >50 % y **no depende de ningún reloj**.

**Lo bueno:** el factor 1,47 sale del *double dipping* y es **ajustable**. Cita literal: *"there's
nothing special about the constant 1.47, it can be lowered to 1+ε for any ε>0 by increasing the
number of blocks that depend on the same challenge (in Chia this is set to at least 16)"*.

**Y un teorema de imposibilidad:** sin componente temporal, **ningún** protocolo de cadena-más-larga
basado solo en pruebas de espacio puede ser seguro bajo disponibilidad dinámica (Baig y Pietrzak,
FC 2025). La VDF no es una elección de diseño, es obligatoria.

### Lo que la práctica rompió

El análisis idealiza que las pruebas de espacio **no admiten ningún compromiso tiempo-memoria**
(§1.6.iii). Falso en producción: los plots comprimidos lograron ~50 % de reducción, y Chia Network
lo reconoce — *"GPUs could rapidly generate and discard plots, effectively farming without
storage"*. Su respuesta es **Proof of Space 2.0**, un formato nuevo que ya está en el código
(`PLOT_SIZE_V2 = 28`) pero **sin altura de activación** (`HARD_FORK2_HEIGHT = 0xFFFFFFFA`).

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
