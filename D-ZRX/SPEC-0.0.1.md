# SPEC 0.0.1 — lo implementado y validado en la red dev del ZEROX híbrido

**Estado:** **borrador vivo**, no normativo hasta cerrar W06–W07. **Fecha:** 2026-09-26 (puesta al día
22:20). **Firma:** Claude (director, `AUTO-ZRX.md` §8). **No sustituye** a `D-ZRX/SPEC.md` (documento POS2T
de Katana, sin tocar). Este texto no repite las reglas: **indexa** los contratos que las fijan, dice qué
código las implementa y con qué evidencia, y separa lo propuesto para fases posteriores. **Nada de lo que
sigue es un parámetro de producción** (`P-ZRX/P-RED-DEV/PERFIL-DEV-v0.md`).

**Regla de lectura:** una fila solo dice «validada» si tiene una verificación ejecutada y conservada
contra un oráculo independiente o una prueba de extremo a extremo; «implementada» sin más significa
código con tests propios pero sin contraste independiente.

**Suite de la raíz (commit candidato `27dcfeb`):** 832/0/5 con W07a-R y, tras SL-4b2 y SL-4b3, 82 binarios con 0
fallos (ejecutadas por los ejecutores en sus zonas; la repite E-0 de W07b desde un clon limpio). Oráculos vigentes:
T01 v0.5 (3 179 casos) y T04 v0.6 (2 108 casos), vectores en `testdata/transicion-v0.5` y `testdata/estado-dag-v0.6`.

## 1. Formatos (`P-ZRX/P-FORMATO/FORMATO-v0.md`, con la Corrección v0.1)

| Reglas | Contenido | Código | Evidencia | Estado |
|---|---|---|---|---|
| F-01…F-04 | Cabecera PoW v1 (92/108 B), cabecera PoST DAG (589–1037 B), `height` reservado | `zx-core::preimage::{block,dag}` | W02; revisión independiente RI-1a sin hallazgos | validada (formato) |
| F-05…F-14 | Versiones de transacción v1/v2/v3, forma, testigos, campos inactivos, códec | `zx-core::{tx, forma, wire}` | Oráculo de formato Julia (W02, W02b: 85/85; v1 no-coinbase idénticos a v0) | validada |
| F-15…F-18 | Nonce por clave de garantía; `expiry_height = altura` en la coinbase PoW; `slot` en la v3; salida de la liberación en `(txid, 0)` | `zx-core`, `zx-consensus::transicion`, `zx-post` | W02b: diferencial contra T01-D, 0 discrepancias; T01-E modela la salida de la liberación como F-18 (id por contenido) | validada (modo estricto y modo fusión, W06a-B) |
| EV-01…EV-04 | `EvidenceTx` v4: dos cabeceras DAG en orden canónico, tamaño acotado, `txid` con dominio propio; `consensus_branch_id` de la red local (RAT-1) | `zx-core` (`ExtensionTx::Evidencia`, `validar_forma_tx_v4`) | SL-4a: diferenciales T01 v0.4 y T04 v0.5 con sellos Ed25519 reales, 0 discrepancias; test de `consensus_branch_id` distinto por red | validada; **no activa en el nodo** (SL-4b) |
| Red | `BloqueRed::{Pow, Post}` con familia explícita; el PoST lleva su `JustificacionPot` | `zx-p2p` | W06c; W06d3 (PoST verificable por red) | implementada; probada con procesos reales (W06d4) |

## 2. Transición PoW → PoAS + PoT + DAG (`P-ZRX/P-TRANSICION/CONTRATO-v0.md` v0.1)

| Reglas | Contenido | Código | Evidencia | Estado |
|---|---|---|---|---|
| TRN-01…TRN-03 | Emisión PoW sin premine, madurez, depósitos en fase PoW | `zx-consensus::transicion` | Oráculo T01 (29,5 M historias, 0 fallos); diferencial T01 v0.4, 0 discrepancias | validada |
| TRN-04…TRN-07 | Terminal CUT-HWΦ, fin del PoW, primer bloque PoST (su único padre es `T`), garantía en `past(B)` | ídem | ídem; primer bloque PoST real verificado de extremo a extremo (W05b2); tres nodos reales fijan el mismo terminal (W06d4) | validada |
| TRN-08 | Semilla del corte | `zx-post::contexto_transicion` (S1 = `blake3(hash(T))`) | W05b2 | **marcador dev**; sesgo abierto (IPA A-07): **no** se reivindica |
| TRN-09 | Selección a través del corte FC-3 | `zx-consensus::transicion::seleccion` (motor); en el nodo, `zx-cadena` | T01; T02 (FC-3 se mantiene, RFT-13); W06d3 (bifurcación y reunión **antes** del primer bloque PoST) | validada en el motor contra T01 y, **en el nodo, desde W06d7** (`c8286d3`: un DAG por terminal, selección por `blue_work` con el desempate del motor y `C-FIN-01`; I-3 por propiedades en 200 órdenes; E-6b y V6(b) con procesos reales, 2 repeticiones cada uno). Límites: sin oráculo multiterminal independiente; el productor aún no cambia de terminal en caliente (SL-4b2). **Corrección del director:** la versión anterior de esta fila decía «validada con procesos reales», afirmación excesiva |
| TRN-10, TRN-11 | Retiro que cruza el corte; reorganización PoW antes del corte | `zx-consensus::transicion` | T01; W06d4 (el depósito del nodo se decide sobre la punta seleccionada) | validada |
| TRN-12 | Prueba tardía `SEC-A` | — | — | **no activa** (`SEC-0`) |

## 3. Estado en el DAG (`P-ZRX/P-DAG/CONTRATO-ESTADO-DAG-v0.md`)

| Reglas | Contenido | Código | Evidencia | Estado |
|---|---|---|---|---|
| ED-1…ED-6, RD-1…RD-10 | Aplicación por fusión, descarte silencioso, punto de aplicación, garantía del productor en `past(B)`, virtual | `zx-consensus::transicion::fusion` + `zx-cadena` | Oráculo T04; W06a-B (914 casos v0.3 sin emulación); SL-4a (1 878 casos v0.5), 0 discrepancias | **validada** |
| IE-1…IE-6 | Conservación, aplicación única, independencia del orden, undo, compatibilidad con T01 | ídem | T04 (46 500 bloques, 600 000 órdenes, 0 fallos); el código coincide en los casos del diferencial | validada en el oráculo; en código, por diferencial (no es prueba general) |
| GHOSTDAG | Orden, `blue_work`, `C-GD-05/07`, admisión, hasta 15 padres, identidad real de billete | `zx-dag`, `zx-cadena` | Corpus antiguo reproducido (W05a); T04; W06a-C | validada; **coste de admisión no acotado** (IPA B-12) |

## 4. Producción PoAS + PoT (`P-ZRX/P-DAG/DECISIONES-W05.md`, D-P07…D-P13)

| Reglas | Contenido | Código | Evidencia | Estado |
|---|---|---|---|---|
| D-P09…D-P11 | Contexto PoT inicial, un solo flujo sin inyecciones, `D = 0`, `N_dev`, `SR_dev` constante | `zx-post::{pot, pot_rango, contexto_transicion}` | W05b2; W06d1: con el `N_dev` real el slot dura **1,66 s**, no ~1 s | implementada; `SR_dev` y slot real por medir (W07) |
| D-P12 | Historia génesis dev (un segmento) | `zx-poas`, `zx-farmer` | W05b1 | validada contra el verificador de Autonomys `f8842d0` |
| Puerta conjunta | Sello, PoT, PoAS y padres de la cabecera PoST; la coinbase v3 paga a `sol.public_key` | `zx-post::cabecera_conjunta` | W05b2 (primer bloque); W05b3 (régimen: 5 positivos, 10 negativos) | validada; con `N_dev` real, 1,43 s por bloque producido y 0,066 s por verificación |

## 5. Nodo, persistencia y red (`P-ZRX/P-NODO/PLAN-W06.md`)

| Orden | Qué deja | Evidencia | Estado |
|---|---|---|---|
| W06a, W06a-B, W06a-C | `zx-cadena`: estado DAG, hasta 15 padres, identidad GHOSTDAG real | diferencial T04 sin emulación | migrada |
| W06b | `zx-storage` (RocksDB), D-N03′ (reinicio repitiendo admisiones), integridad de cabecera y cuerpo | tests; Corrección A | migrada; testigos PoW no comprometidos (declarado) |
| W06c | `zx-p2p`: transporte libp2p, límites, mensajes del híbrido | 502 tests; integración en memoria | migrada |
| W06d1 | `zx-node` sin red: cruza el corte, produce en régimen (78 bloques, 0 rechazados), reabre tras 10 `SIGKILL` sin corrupción | V1–V9; prueba de reinicio 5/5 seguidas (W06d3) | migrada |
| W06d2 | Validación diferida, huérfanos acotados, sincronización PoW por localizador, `zx-adversario`; correcciones RI-2a (error de padre no definitivo) y RI-2b (persistir el bloque propio antes de admitirlo; **sustituida en W06d6** por admitir → persistir → difundir, RI-3c) | dos nodos convergen en PoW con procesos reales | migrada (parcial) |
| W06d3 | PoST verificable por red, FC-3 en el nodo, cuatro fallos reales corregidos | suite 721/0/2 | migrada (parcial) |
| W06d4 | Depósito sensible a la rama; hueco del `ServicioPot` corregido | **tres procesos reales cruzan el corte y convergen: 528 bloques PoST, 0 rechazos, 0 fatales**; partición y reunión en fase PoW | migrada (parcial). Ejecución con `N_dev` reducido (69 bloques PoST en ≈ 35 s) |
| W06d5 | Garantía antes de producir, padres extra, rechazos legítimos frente a invariantes, suscripción del adversario | V4 y V6(a) con procesos reales; 736/0/2 | migrada (parcial): nodo tardío y partición PoST sin superar |
| W06d6 | **Sincronización por páginas del registro de admisión** (cursor por par, contrapresión); correcciones RI-3a (tres DoS de red) y **RI-3c** (orden **admitir → persistir → difundir**: un bloque rechazado ya no se persiste, lo que impedía reiniciar); dial con reintento; `--dejar-de-producir-en-slot` (reposo) | **nodo tardío** tras ≥ 500 bloques PoST: alcanza a la red en < 90 s y, tras el reposo, misma punta y `resumen_estado` en los cuatro (2 repeticiones); `zx-adversario` E-7; 814/0/5 | migrada (parcial): la partición destapó el defecto de FC-3 |
| W06d7 | **FC-3 real**: un DAG por terminal con sufijo PoST, selección por `blue_work` con el desempate del motor, `C-FIN-01` en el cambio de terminal, servicio PoT de verificación por terminal | I-3 por propiedades (200 órdenes, empates); **E-6b** (terminales distintos) y **V6(b)** (partición PoST, mismo terminal) con procesos reales, 2 repeticiones cada uno; 829/0/5 | migrada; sin oráculo multiterminal independiente |
| W07a | Registro según `P-ZRX/P-MEDICION/ESQUEMA-REGISTRO-v1.md` (tiempos por etapa, bytes, profundidad, mergeset, pares) | `registro_esquema`; tres nodos reales; 832/0/5 | migrada (vía W07a-R) |
| SL-4b2, SL-4b3 | Productor que sigue al terminal seleccionado en caliente; firmante seguro, detector y envío de evidencia en el nodo (ver §6) | procesos reales (ver §6) | migradas |

Revisión independiente del código de red, nodo y castigo: RI-3a/b/c hechas, hallazgos corregidos (un crítico).
**Pendiente:** las mediciones de W07b (`P-ZRX/P-MEDICION/ORDEN-W07b.md`) sobre el commit candidato `27dcfeb`.

## 6. Evidencia y castigo (`P-ZRX/P-SLASHING/CONTRATO-EVIDENCIA-v0.md` con su «Ratificación v0»)

| Reglas | Contenido | Código | Evidencia | Estado |
|---|---|---|---|---|
| EV-05…EV-09, RAT-1 | Única falta: doble firma de la misma oportunidad; identidad = `consensus_branch_id` + tupla `C-GD-07` (DS-L01, DS-L04) | `zx-core`, `zx-consensus::transicion` | SL-3b (oráculos); SL-4a (0 discrepancias) | validada en motor y cadena |
| EV-10…EV-28, RAT-2′, RAT-3 | Incidentes, congelación, confiscación `C = mín(V, techo(f·V))`, `suelo(C·2/8)` al incluidor y el resto quemado (DS-L03), liberación con `Plazo_slots + M_margen_slots` desde el último bloque producido (DS-L05), undo; en fusión, la evidencia repetida es un descarte | `zx-consensus::transicion`, `zx-cadena` | SL-4a (V5: 8/8, autodenuncia pierde ≥ 6/8·C) | validada en motor y cadena |
| Parámetros dev | `f = 1`, `Plazo_slots = 300`, `M_margen_slots = 60`, `R_SLOTS = 600 = F_SLOTS`, `q = 10` ZZK por clave (`crates/zx-node/src/perfil.rs`) | `ParametrosEvidencia`, perfil dev | SL-2b (`R_slots ≥ F_slots`), SL-4b2 | dev, no producción. **No implementada la retención de recompensas** (`ρ_ret`, `T_v` de SL-2/SL-2b), de la que depende la disuasión calculada allí: en 0.0.1 el castigo confisca solo la garantía; **no se reivindica disuasión**. **Corrección del director:** la versión anterior de esta fila daba `ρ_ret`, `T_v` y `q = 20` como parámetros de 0.0.1 |
| FIR-* | Firmante seguro (registro durable antes de sellar, abstención tras pérdida), detección de doble firma y envío de evidencia por inclusión propia | `zx-post::firmante` (SL-4b1), `zx-node::evidencia` y productor (SL-4b2) | SL-4b1 (durabilidad con proceso abortado 20/20); SL-4b2 con procesos reales: doble firma castigada 3/3, 10 `SIGKILL` honestos sin evidencia, pérdida del registro con abstención exacta | **activo en la red dev** (`Plazo_slots = 300`, `M_margen_slots = 60`, `R_SLOTS = 600`); también el bloque de transición (SL-4b3) y un guardián de CI que impide al nodo usar productores sin firmante |

Sin castigo correlacionado (RFT-15, DS-L02) y sin castigo por ausencia en la producción de bloques.

## 7. No activo en 0.0.1 (se declara, no se reivindica)

Retención de recompensas (`ρ_ret`, `T_v`); registro de sectores Filecoin (`SEC-0`); relevo de transacciones;
controlador de `SR` y de `N`; inyecciones PoT; semilla del corte no sesgable; algoritmo PoW de producción
(A-12: con SHA3-256 una GTX 1070 rinde 7,6× una CPU de 16 núcleos en reposo, `P-ZRX/P-POW/REVISION-A10-M1.md`);
**finalidad por votos** (adoptada en principio por Katana, sin contrato ratificado ni código).

## 8. Propuesto para fases posteriores (no es regla de 0.0.1)

- **Finalidad por votos** (`P-ZRX/P-FINALIDAD-VOTOS/DECISIONES.md` FV-D01…FV-D07): peso = sectores
  registrados con garantía, sorteo VRF por instancia con prima `b = 2`, tabla de poder encadenada por
  certificado (FV-01b), falta «elegido sin voto» con `m_aus` proporcional con mínimo
  (`P-ZRX/P-AUSENCIA-VOTO/resultados-AV1/`), sin premio por votar. Umbrales con censura de las pruebas de
  disponibilidad: pausa con el 20 %, sella a solas con el 50 % (RFT-17, RFT-18). Borradores de contrato en
  `resultados-FV1/` y `resultados-AV1/`; siguen FV-2…FV-4.
- Auditorías de sectores con más de 181 092 aperturas por TiB para detectar al sembrador (RFT-04).
- Garantía por unidad de espacio en vez de por identidad (RFT-23, IPA C-02).
- Semilla S3 retardada (`NOTA-A07-SEMILLA.md`); índice de alcanzabilidad acotado para GHOSTDAG (B-12);
  instantáneas de estado para el reinicio (E-10); cierre de la ventana previa al primer bloque PoST
  (A-05b); el resto del catálogo `D-ZRX/IPA-ZRX.md` familias C, D y X.
