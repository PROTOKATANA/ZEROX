# Plan de la ruta vertical 0.0.1 del ZEROX híbrido

**Fecha:** 2026-09-26. **Firma:** Claude (director, `AUTO-ZRX.md`). **Estado:** plan vivo; se
actualiza tras cada puerta. Autorización de Katana (≈01:10): commits locales, cómputo pesado,
workspace nuevo en la raíz, borrar zonas tras conservar evidencia, decidir con evidencia, SHA3-256
tras interfaz para la red dev, objetivo «hasta 0.0.1 medible».

## 1. Criterio de cierre (de `AUTO-ZRX.md` §8)

0.0.1 está lista para medir cuando: varios nodos independientes producen, validan, propagan,
sincronizan, reinician y revierten con reglas idénticas; el corte PoW → PoAS + PoT + DAG se prueba
con garantía y espacio elegibles; y los verificadores de los mecanismos **activados** aceptan lo
válido y rechazan lo inválido. Se entrega receta reproducible, logs y medidas de latencia,
recursos, tasas de error y conducta bajo ataques y fallos especificados.

## 2. Qué se activa en 0.0.1 y qué no

| Mecanismo | En 0.0.1 | Estado de seguridad que se puede afirmar |
|---|---|---|
| PoW de arranque SHA3-256, dificultad dev | **activo**, tras la interfaz `AlgoritmoPow` | Ninguno: parámetro de desarrollo (A-12 abierto) |
| Emisión PoW, madurez, depósitos, registro de garantía, retiro/liberación | **activo** con parámetros dev | Contabilidad verificada contra el oráculo T01 |
| Corte CUT-HWΦ, selección FC-3, `C-FIN-01` con `F_slots` dev | **activo** | Según T01/T02; FC-3 revisable (D-T03) |
| PoAS (Autonomys `f8842d0`) + PoT AES + sello | **activo** | Verificadores reales; parámetros dev |
| GHOSTDAG (orden, `blue_work`, `C-GD-07`, `C-ORD-03/04`) | **activo** con `k` dev | Oráculo antiguo reproducido; admisión nueva |
| Semilla del corte | **marcador dev** S1 (`H(T)`), etiquetado | Sesgo abierto (A-07); no se reivindica |
| `EvidenceTx`, congelación, `C-SLA` | **no activo** (prototipo aparte) | Ninguno |
| Registro de sectores (Filecoin) | **no activo** (`SEC-0`) | Ninguno |

## 3. Decisiones de arquitectura del plan

| ID | Decisión | Motivo | Se revierte si |
|---|---|---|---|
| D-P01 | Workspace en la raíz del repo con la disposición de crates antigua (`zx-core`, `zx-pot`, `zx-consensus`, `zx-storage`, `zx-p2p`, `zx-node`), `resolver = "3"`, edición 2024, `nightly-2026-05-03` (la exige `ab-proof-of-space`) y licencia declarada **igual que la antigua** (`AGPL-3.0-or-later`; no se cambia la licencia del proyecto por un portado) | Portar con el menor cambio; L01 reprodujo esa unidad | Una dependencia nueva exige otra toolchain |
| D-P02 | Clon de Autonomys en `PDF/autonomys-subspace` (ignorado por git, ya en `.gitignore`), en `f8842d019cdf…`, clonado desde la copia local; `PDF/README.md` y `PDF/repositorio.txt` se restauran de `9681061` | Procedencia idéntica a la antigua | — |
| D-P03 | Portado **sin cambios** primero (fuentes byte a byte + tests) y adaptación después, en órdenes separadas | Distingue «el portado reproduce» de «la adaptación funciona» | — |
| D-P04 | La máquina de estados Rust de la transición se valida **diferencialmente** contra el oráculo Julia T01 mediante vectores exportados | Oráculo independiente (otra implementación, otro lenguaje) | T01 refutado |
| D-P05 | Red dev con génesis, `CONSENSUS_BRANCH_ID` y límites de dificultad propios, marcados `dev` en el código; ningún parámetro dev puede activarse en otra red (bloqueo explícito en tipo o configuración) | `AUTO-ZRX.md` §3.7 | — |
| D-P06 | Ejecutor por defecto DeepSeek; Sonnet para órdenes de integración compleja o revisión independiente de código | Instrucción de Katana (coste) | — |

## 4. Secuencia de órdenes

| Orden | Contenido | Depende de | Puerta |
|---|---|---|---|
| L01 (+C1) | Línea base de `9681061` | — | Suites reproducidas (C1 en curso) |
| T01 | Oráculo Julia de la transición | CONTRATO-v0 | X-01…X-20, I-1…I-7 |
| T02 | Modelo adversarial FC-1/2/3 | CONTRATO-v0 | Veredicto sobre D-T03/D-T04 |
| W01 | Workspace nuevo: `zx-core` y `zx-pot` portados sin cambios, CAVP, lock recortado del antiguo, CI nueva | L01 | Suites iguales a L01 en el árbol nuevo; CI local verde |
| W02 | Formatos híbridos: cabecera PoW v1 (familia, rama, altura), cabecera PoST DAG adaptada, operaciones de garantía en tx (depósito, retiro, liberación), dominios y txid; vectores y parsers negativos | W01, CONTRATO | Códec canónico con vectores y rechazo de no canónicos |
| W03 | Máquina de estados Rust: UTXO + garantía + transición + undo, portando `zx-storage::utxo` | W02, T01 | Diferencial contra vectores de T01 sin discrepancias |
| W04 | Motor PoW dev: verificador SHA3 tras `AlgoritmoPow`, retarget con parámetros dev, selección por trabajo, minero CPU de desarrollo | W02 | Minero y verificador coinciden; rechazo de PoW inválido |
| W05 | PoAS + PoT + sello + GHOSTDAG portados y puerta conjunta de cabecera PoST sobre el estado de W03 | W03, L01-C1 | Primer bloque PoST real tras un terminal dev, validado y rechazos |
| W06 | Nodo: almacén RocksDB, admisión, orden, aplicar/revertir, gossip y sincronización, reinicio | W03–W05 | Dos nodos cruzan el corte y convergen |
| W07 | Arnés multinodo y mediciones (≥ 3 nodos, fallos y ataques especificados) | W06 | Criterio de §1 |

Cada orden sigue la plantilla de `AUTO-ZRX.md` §6, congela su entrada con `sha256sum` y se revisa
según §5.5 (diff, tests, logs, recursos). Las revisiones de código de W03–W06 incluyen un revisor
independiente (subagente Sonnet) además del director.

## 5. Riesgos conocidos del plan

- El formato PoST DAG antiguo (589–1037 B) lleva campo `HEIGHT`; la semántica de altura DAG sigue
  pendiente (IPA B-10). W02 debe resolverla para la red dev o eliminar el campo.
- El almacén GHOSTDAG antiguo estaba en memoria y fuera de la ruta activa: W05/W06 son trabajo
  nuevo, no portado.
- La sincronización antigua era lineal: W06 es trabajo nuevo.
- Las mediciones de W07 no son las de una red pública adversarial (`AUTO-ZRX.md` §7).
