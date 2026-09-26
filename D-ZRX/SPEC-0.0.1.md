# SPEC 0.0.1 — lo implementado y validado en la red dev del ZEROX híbrido

**Estado:** **borrador vivo**, no normativo hasta cerrar W06–W07. **Fecha:** 2026-09-26. **Firma:**
Claude (director, `AUTO-ZRX.md` §8). **No sustituye** a `D-ZRX/SPEC.md` (documento POS2T de Katana,
sin tocar). Este texto no repite las reglas: **indexa** los contratos que las fijan, dice qué código
las implementa y con qué evidencia, y separa lo propuesto para fases posteriores. **Nada de lo que
sigue es un parámetro de producción** (`P-ZRX/P-RED-DEV/PERFIL-DEV-v0.md`).

**Regla de lectura:** una fila solo dice «validada» si tiene una verificación ejecutada y conservada
contra un oráculo independiente o una prueba de extremo a extremo; «implementada» sin más significa
código con tests propios pero sin contraste independiente.

## 1. Formatos (`P-ZRX/P-FORMATO/FORMATO-v0.md`, con la Corrección v0.1)

| Reglas | Contenido | Código | Evidencia | Estado |
|---|---|---|---|---|
| F-01…F-04 | Cabecera PoW v1 (92/108 B), cabecera PoST DAG (589–1037 B), `height` reservado | `zx-core::preimage::{block,dag}` | W02; revisión independiente RI-1a sin hallazgos | validada (formato) |
| F-05…F-14 | Versiones de transacción v1/v2/v3, forma, testigos, campos inactivos, códec | `zx-core::{tx, forma, wire}` | Oráculo de formato Julia (W02, W02b: 85/85; v1 no-coinbase idénticos a v0) | validada |
| F-15…F-18 | Nonce por clave de garantía; `expiry_height = altura` en la coinbase PoW; `slot` en la v3; salida de la liberación en `(txid, 0)` | `zx-core`, `zx-consensus::transicion`, `zx-post` | W02b: diferencial contra T01-D, 0 discrepancias en 2 055 casos y 3 939 negativos; T01-E modela la salida de la liberación como F-18 (id por contenido) | validada (modo estricto); modo fusión: validada (W06a-B) |

## 2. Transición PoW → PoAS + PoT + DAG (`P-ZRX/P-TRANSICION/CONTRATO-v0.md` v0.1)

| Reglas | Contenido | Código | Evidencia | Estado |
|---|---|---|---|---|
| TRN-01…TRN-03 | Emisión PoW sin premine, madurez, depósitos en fase PoW | `zx-consensus::transicion` | Oráculo T01 (29,5 M historias, 0 fallos); diferencial W03/W02b 0 discrepancias | validada |
| TRN-04…TRN-07 | Terminal CUT-HWΦ, fin del PoW, primer bloque PoST, garantía en `past(B)` | ídem | ídem; primer bloque PoST real verificado de extremo a extremo (W05b2) | validada |
| TRN-08 | Semilla del corte | `zx-post::contexto_transicion` (S1 = `blake3(hash(T))`) | W05b2 | **marcador dev**; sesgo abierto (IPA A-07): **no** se reivindica |
| TRN-09 | Selección a través del corte FC-3 | `zx-consensus::transicion::seleccion` | T01; T02 (FC-3 se mantiene, RFT-13) | validada en el oráculo; revisable (D-T03) |
| TRN-10, TRN-11 | Retiro que cruza el corte; reorganización PoW antes del corte | `zx-consensus::transicion` | T01 | validada |
| TRN-12 | Prueba tardía `SEC-A` | — | — | **no activa** (`SEC-0`) |

## 3. Estado en el DAG (`P-ZRX/P-DAG/CONTRATO-ESTADO-DAG-v0.md`)

| Reglas | Contenido | Código | Evidencia | Estado |
|---|---|---|---|---|
| ED-1…ED-6, RD-1…RD-10 | Aplicación por fusión, descarte silencioso, punto de aplicación, garantía del productor en `past(B)`, virtual | `zx-consensus::transicion::fusion` + `zx-cadena` | Oráculo T04 (v0.3, T04-D); RI-1a (`slot`/`peso_sufijo` en fusión) corregido en W06a; diferencial W06a 913/913 **con emulación de ids** (`REVISION-W06a`) | **validada**: W06a-B, 0 discrepancias en 914 casos v0.3 sin emulación |
| IE-1…IE-6 | Conservación, aplicación única, independencia del orden, undo, compatibilidad con T01 | ídem | T04 (46 500 bloques, 600 000 órdenes, 0 fallos) | validada en el oráculo; código pendiente de W06a |
| GHOSTDAG | Orden, `blue_work`, `C-GD-05/07`, admisión | `zx-dag` | Corpus antiguo reproducido (W05a); T04 revalida 2 290 + 84 bloques | validada; **coste de admisión no acotado** (IPA B-12) |

## 4. Producción PoAS + PoT (`P-ZRX/P-DAG/DECISIONES-W05.md`, D-P07…D-P13)

| Reglas | Contenido | Código | Evidencia | Estado |
|---|---|---|---|---|
| D-P09…D-P11 | Contexto PoT inicial, un solo flujo sin inyecciones, `D = 0`, `N_dev`, `SR_dev` constante | `zx-post::{pot, pot_rango, contexto_transicion}` | W05b2 | implementada; `SR_dev` por medir (W07) |
| D-P12 | Historia génesis dev (un segmento) | `zx-poas`, `zx-farmer` | W05b1 | validada contra el verificador de Autonomys `f8842d0` |
| Puerta conjunta | Sello, PoT, PoAS y padres de la cabecera PoST | `zx-post::cabecera_conjunta` | W05b2 (primer bloque); W05b3 (bloques en régimen) | primer bloque y régimen validados con contextos reales (W05b3: 5 positivos, 10 negativos); con `N_dev` real, 1,43 s por bloque producido y 0,066 s por verificación |

## 5. Nodo, persistencia y red (`P-ZRX/P-NODO/PLAN-W06.md`)

Migradas: W06a (`zx-cadena`, diferencial provisional), W06b (`zx-storage`, D-N03′, integridad de cabecera y cuerpo; testigos PoW no comprometidos), W06c (`zx-p2p`, mensajes y
transporte), W06d1 (nodo sin red, en curso), W06d2 (red), W06e (integración), W07 (mediciones, `P-ZRX/P-MEDICION/ESCENARIOS-0.0.1.md`).

## 6. No activo en 0.0.1 (se declara, no se reivindica)

`EvidenceTx`, congelación y `C-SLA` (IPA C-04, C-05); registro de sectores Filecoin (`SEC-0`); relevo
de transacciones; controlador de `SR` y de `N`; inyecciones PoT; semilla del corte no sesgable;
algoritmo PoW de producción (A-12: con SHA3-256 una GTX 1070 rinde 7,6× una CPU de 16 núcleos en reposo,
`P-ZRX/P-POW/REVISION-A10-M1.md`).

## 7. Propuesto para fases posteriores (no es regla de 0.0.1)

Semilla S3 retardada (`NOTA-A07-SEMILLA.md`); índice de alcanzabilidad acotado para GHOSTDAG
(B-12); instantáneas de estado para el reinicio (E-10); cierre de la ventana previa al primer bloque
PoST (A-05b); todo el catálogo `D-ZRX/IPA-ZRX.md` familias C, D y X.
