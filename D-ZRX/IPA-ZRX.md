# IPA-ZRX — inventario priorizado de problemas abiertos

**Abierto:** 2026-09-26. **Mantiene:** Claude (director técnico, `AUTO-ZRX.md`). **Decide:** Katana
en lo que el mandato reserva a Katana; el resto lo decide el director con evidencia.

**Para qué sirve.** Determina por dónde empezar. Cada fila tiene dependencia, riesgo, siguiente
encargo y la puerta que desbloquea. Se actualiza tras cada puerta (`AUTO-ZRX.md` §5.6).

**Prioridad.** **P0** bloquea la ruta vertical 0.0.1 (`AUTO-ZRX.md` §5.8, §8). **P1** debe cerrarse
antes de activar el mecanismo al que pertenece. **P2** investigación que no bloquea 0.0.1 pero sí
la ratificación. Un mecanismo P1/P2 sin cerrar puede vivir en un prototipo aislado, **nunca** como
parte de la seguridad de 0.0.1 (`AUTO-ZRX.md` §8).

**Estados.** `abierto` · `en encargo` (orden redactada) · `bloqueado` (dependencia externa) ·
`decidido provisional` (decisión con condición de reversión) · `cerrado`.

**Referencias cortas.** `CONTRATO` = `P-ZRX/P-TRANSICION/CONTRATO-v0.md`; `SPEC` =
`D-ZRX/SPEC.md` (POS2T, no normativo); `SPEC-v` = `SPEC.md` antiguo de `9681061`; `RFT-nn` =
`D-ZRX/RFT-ZRX.md`; `archivo` = `/home/katana/zeo/.trash/zerox/`.

---

## Camino crítico hacia 0.0.1

```text
E-04 (credencial DeepSeek) ──► E-01 línea base ──► E-02 workspace nuevo ──► B-01/B-02/B-03 portados
                         └──► A-01 oráculo de transición (ORDEN-T01) ──► A-13 red dev PoW real
A-01 + C-01 + B-03 ──► B-08 ruta activa del nodo ──► A-09 sincronización/reinicio ──► 0.0.1 medible
```

**Estado (02:08):** línea base, W01, W02, W04 y oráculos T01/T02 cerrados; en ejecución T01-B (vectores) y W05a (`zx-dag`); preparadas W03, W05b1 y S02a. Plan: `P-ZRX/PLAN-0.0.1.md`.

---

## A · Transición PoW → PoAS + PoT + DAG

| ID | Problema | Estado | Prio | Depende de | Riesgo si se ignora | Siguiente encargo | Puerta que desbloquea |
|---|---|---|---|---|---|---|---|
| A-01 | Familias de bloque, fin del PoW, inicio del PoST, estado y rechazos de la transición | **oráculo SUPERADO** (T01: 29,5 M historias, 0 fallos; contrato v0.1); falta motor Rust (W03) | P0 | CONTRATO | Historia con dos terminales, PoW tras el corte o bloque PoST sin garantía aceptados | `P-ZRX/P-TRANSICION/ORDEN-T01.md` | Oráculo pasa X-01…X-20 e I-1…I-7 en la rejilla pequeña |
| A-02 | Emisión PoW (`subsidio_pow`), madurez `M_cb` y madurez residual al cruzar el corte | abierto | P1 | A-10, A-12 | Recompensa inmadura usada como garantía; emisión concentrada. **No heredar** `SHIFT=26`, `COINBASE_MATURITY=12 000` (`PLAN-ARRANQUE-HIBRIDO.md` §3) | Derivación de `M_cb` desde horizonte de reorg PoW, tras A-10 | Desigualdades de madurez publicadas y comprobadas por el oráculo |
| A-03 | Depósitos bajo PoW (`H_dep`, `M_dep`), retiros que cruzan el corte | decidido provisional (TRN-03, TRN-10) | P0 simbólico / P1 valores | A-01 | Garantía que no existe al corte o que se libera sin retención | cubierto por `ORDEN-T01` | I-1, I-6, X-04…X-06 |
| A-04 | Predicado de corte (CUT-HWΦ) y valores `H_corte_min`, `W_min`, `S_min`, `K_min` | decidido provisional (D-T04) | P0 forma / P1 valores | A-05, A-08, A-10 | Activación con garantía nula o sin espacio; varios terminales sin regla | `ORDEN-T01` (forma) + modelo adversarial A-05 (valores) | Rechazos X-11/X-12; valores con coste absoluto |
| A-05 | Selección a través del corte (FC-3): terminal tardío, rama PoW pesada tras el corte, ataque «espacio + terminal», nodo que sincroniza desde cero | **decidido provisional con límite medido** (T02-A: FC-3 se mantiene; RFT-13: la ventana previa al primer bloque PoST es una carrera PoW de Nakamoto; `P-ZRX/P-TRANSICION/REVISION-T02.md`) | P1 | A-01 | Mayoría de hash borra historia PoST (FC-1) o PoW que no protege la distribución (FC-2) | `ORDEN-T02` (modelo adversarial Julia; por redactar tras T01) | Comparación FC-1/2/3/4 bajo el mismo adversario con coste absoluto |
| A-05b | Reducir lo que está en juego en la ventana previa al primer bloque PoST (p. ej. cerrar la admisión de depósitos `K` bloques antes del corte) | abierto | P1 | A-05 | Depósitos y pagos de los últimos bloques con seguridad solo PoW (RFT-13) | Variante del oráculo T01 + modelo T02 | Coste de la variante frente a la reducción del riesgo |
| A-06 | Historia PoAS al corte: segmento génesis rellenado (D-T05), `history_size`, archivado de bloques PoW, caducidad de sectores sin alturas lineales (`C-EXP-*` de SPEC-v dependen de altura) | abierto | P1 | E-01, B-01 | Primer bloque PoST imposible de plotear o verificar | Orden de formato (Rust) tras `ORDEN-L01` | Parcela real ploteada sobre la historia de la red dev y verificada en el primer bloque PoST |
| A-07 | Semilla PoT del corte y sesgo del minero del terminal (elegir o callar el bloque) | abierto; derivación inicial en `P-ZRX/P-TRANSICION/NOTA-A07-SEMILLA.md` (candidato S3, semilla retardada `D` slots con `D·τ/ρ_max ≫ T_pow/(1−h)`, sin instrumento) | P1 | A-01, B-02 | Un minero —o un Estado con hash— elige los primeros retos. Lectura **no validada** del archivo: «una pata de PoW pequeña la domina un Estado y entonces controla la entropía del ancla» (`archivo/P-ZRX/T-ZRX/AGUJEROS-Y-SOLUCIONES.md` §«PoW en lugar del VDF») | `ORDEN-T03` (modelo de sesgo; por redactar) | Sesgo máximo cuantificado para cada candidato de `derivar_semilla` (CONTRATO §8) |
| A-08 | Fallo de activación: `Φ` nunca verdadero; censura de depósitos por mayoría de hash que prolonga la emisión PoW | abierto; **riesgo confirmado** por T02-A E4: con `h ≤ 1/2` retraso finito (p. ej. `h = 0,4`, `M_dep = 12`: media 25 `T_pow`), con `h = 0,9` y `M_dep ≥ 6` la censura domina (81–99,98 % sin corte en `10⁴ T_pow`) | P1 | A-04 | Fase PoW indefinida y emisión capturada | Incluido en `ORDEN-T02` | Regla de fallo elegida con coste del ataque de censura |
| A-09 | Sincronización desde cero de ambas familias, nodo que llega tarde, reinicio en la frontera | abierto | P0 | B-08, A-01 | Nodos con estados distintos tras el corte | Orden de integración (fase 4 del PLAN) | Varios nodos reinician y sincronizan cruzando el corte |
| A-10 | Coste absoluto del ataque al prefijo PoW: hashrate CPU/GPU medido, hash alquilable, concentración de recompensas | abierto — **el archivo no tiene ninguna medida** de PoW de arranque (catálogo de refutaciones, 2026-09-26) | P1 | A-12 | Arranque reescribible con poco dinero; la energía gastada no prueba distribución | Benchmark por candidato de A-12 | Tabla recurso → coste de reescribir `k` bloques, con fuente y fecha |
| A-11 | `caliza` (kernel HIP/CUDA) y `silicio` (bucle Rust) como mineros | abierto; divergencias ya **verificadas por lectura**: caliza aplica Keccak-f crudo sin relleno ni dominio (`archivo/crates/zx-core/tests/cavp_sha3_256.rs:3-5` documenta que falla 237 vectores), nonce en bytes 48–55 (`caliza/src/excavadora.cc:73`) frente a 96 (`zx-core/src/preimage/block.rs:76`), criterio de bytes cero (`caliza/src/titanio/sha3.h:115`) frente a `hash < target` U256 (`target.rs:239-241`); `silicio` no compila `minero.rs` y no compara target | P2 | E-01, A-12 | Declarar minero compatible por compartir SHA3 | `ORDEN-L02` (prueba diferencial, por redactar) | Veredicto por pieza: fuente de ideas / portar con cambios / descartar |
| A-12 | Algoritmo PoW: SHA3-256 heredado (verificador y vectores CAVP existen) frente a alternativas (p. ej. memoria-dura) | abierto; fuentes revisadas en `P-ZRX/P-POW/NOTA-A12-ALGORITMO.md` (ECIP-1049: hash alquilado en ETC; RandomX: CPU, 4 auditorías 2019) | P1 | — | Elegir por facilidad; ASIC o GPU alquilada dominan el arranque | Investigación de fuentes + medición (por redactar) | Comparación accesibilidad doméstica / coste adversario / auditoría de la primitiva. **Probable pregunta a Katana** con datos (prioridad de accesibilidad frente a resistencia) |
| A-13 | Red dev separada: génesis, identificador de rama y límites de dificultad explícitos; PoW real de dificultad de desarrollo | abierto | P0 | E-02, A-01 | Parámetros dev filtrados a producción | Orden de integración | Primer hito de `PLAN-ARRANQUE-HIBRIDO.md` §5 |

---

## B · Producción PoAS + PoT y orden DAG

| ID | Problema | Estado | Prio | Depende de | Riesgo | Siguiente encargo | Puerta |
|---|---|---|---|---|---|---|---|
| B-01 | Verificador y plotter PoAS (Autonomys `f8842d0`, `nightly-2026-05-03`, `ab-proof-of-space`) | en encargo (`ORDEN-L01`) | P0 | E-04 | Portar sin reproducir; copiar un crate sin su lock | `ORDEN-L01` | Suites acotadas reproducidas con salida conservada |
| B-02 | Primitiva PoT (`zx-pot`, 32 vectores) y parámetros `N(s)`, `ρ_max`, segundo VDF | primitiva en encargo (`ORDEN-L01`); parámetros abiertos | P0 / P1 | E-04 | RFT-12: adelanto no anulado | `ORDEN-L01`; parámetros después | Vectores reproducidos; `ρ_max` medido por hardware objetivo |
| B-03 | GHOSTDAG, admisión contextual, `C-GD-07`, almacén causal (en el archivo, en memoria y fuera de la ruta activa) | abierto | P0 | E-01 | Oráculo GHOSTDAG ≠ ruta de red (`AUTO-ZRX.md` §4) | `ORDEN-L01` (línea base) y portado posterior | Admisión y orden deterministas en el nodo nuevo |
| B-04 | Doble farmeo en rama privada | cerrado como **no evitable** (RFT-01); magnitud **no medible** hasta cablear el nodo (`archivo/P-ZRX/T-ZRX/ESTADO-DOBLE-FARMEO.md` §5) | P2 | B-08 | Vender el híbrido como solución | Medición tras 0.0.1 | Umbral medido en la red dev |
| B-05 | `C-FIN-01`, `F_slots`, `Δ` real | abierto | P1 | B-08 | Finalidad lenta; `F` tiene signo opuesto en doble farmeo y eclipse | Medición multinodo | `Δ_p99` medida y `F_slots` derivado |
| B-06 | Pools con espacio ajeno; firma a ciegas (RFT-11) | parcialmente cubierto por `C-BON-03` (coinbase a `sol.public_key` quita el premio, no la capacidad) | P1 | C-01 | Operador de pool produce en la rama que elige | Diseño de arquitectura granjero-valida-contexto | Regla y prueba de que la coinbase no paga otra clave |
| B-07 | Eclipse y partición mayor que `F` (se paga en IP, no en espacio) | abierto; archivo sin gestor de direcciones (`R-ZRX/LEGADO/eclipse/INFORME.md`) | P2 | B-08 | Partición permanente de un nodo | Orden de red (por redactar) | Renovación de pares y medida |
| B-08 | **Ruta activa del nodo**: admisión, orden, estado seleccionado, UTXO, rollback, propagación, sincronización y reinicio (el nodo antiguo seguía lineal) | abierto | P0 | B-01…B-03, C-01, A-01 | Declarar 0.0.1 con bibliotecas sueltas | Serie de órdenes de integración (fase 4 del PLAN) | Criterio de cierre de `AUTO-ZRX.md` §8 |
| B-09 | Sesgo eligiendo la clave (`public_key → sector_id → bucket`); ocupación bimodal de s-buckets | abierto, sin medir | P2 | B-01 | El stake no lo corrige: se muelen claves antes de depositar | Medición con plotter real | Ventaja de molienda cuantificada |
| B-11 | **Semántica de estado en el DAG**: aplicación al fusionar (`C-ORD-03`), descarte silencioso (`C-ORD-04`), cobro de azules y `rojo_k` (`R-FIN-8′`) combinados con garantía, coinbase atribuida y corte | contrato redactado (`P-ZRX/P-DAG/CONTRATO-ESTADO-DAG-v0.md`); falta oráculo T04 | P0 | W03, W05a | Nodo que inventa la semántica de fusión o que invalida bloques por conflictos de tx | T04 (oráculo) y W06a | Diferencial Rust ↔ T04 |
| B-10 | Semántica de altura/slot en el DAG (`C-HDR-02` pendiente en SPEC-v); reglas que dependían de altura lineal (`C-EMIT`, `C-EXP`, `C-CHK`, `C-UPG`, `C-REORG-07`) | abierto | P1 | A-01 | Mezclar bloques y slots sin `λ` | Parte de los contratos de integración | Cada regla con unidad única |

---

## C · Mecanismos de PoStake (garantía, evidencia, slashing)

| ID | Problema | Estado | Prio | Depende de | Riesgo | Siguiente encargo | Puerta |
|---|---|---|---|---|---|---|---|
| C-01 | Registro de garantía por clave (`C-BON-01`): codificación canónica, estados, poda de incidentes, undo | contabilidad en encargo (`ORDEN-T01`); codificación abierta | P0 | A-01 | Garantía creada o perdida por un reorg | `ORDEN-T01`, luego orden Rust | I-1/I-2 en oráculo y en código |
| C-02 | `requisito(B)`: forma (fija, por capacidad, por oferta) y cuantía | abierto | P1 | A-10, D-03 | RFT-05: un coste fijo por clave solo domina por debajo de un tamaño. `P-CLAVE` (claves de saldo cero, soborno cero) queda **condicional**: `C-BON-04` exige `requisito > 0`, lo que retira la premisa «claves gratis» pero no R-5 | Modelo económico (por redactar) | Barrera de entrada y pérdida posible cuantificadas bajo el mismo adversario |
| C-03 | Retiro, `R_slots`, `M_estabilidad_slots`, liberación | abierto | P1 | C-04, B-05 | Retirar antes de que llegue la evidencia | Tras C-04 | Desigualdad `R_slots > Q_corr + T_reporte + M_estab` con valores medidos |
| C-04 | `EvidenceTx`: codificación, deduplicación por incidente, plazo, disponibilidad, reorg | abierto | P1 | C-01 | Evidencia censurada o aplicada dos veces | Orden de formato (por redactar) | Oráculo de incidentes + casos adversariales |
| C-05 | `C-SLA`: correlación `b`, `c`, `Q_corr`; falsos positivos honestos | abierto — SPEC lo declara «no implementable» hasta cerrar codificación y presupuesto | P2 | C-04 | Castigo catastrófico por error compartido | Tras C-04 | Tasa de castigo honesto medida |
| C-06 | Complementariedad: más stake no aumenta oportunidades ni `blue_work` | I-5 **superado en el oráculo** (T01); falta en código (W03) | P0 | A-01 | Stake convertido en peso por la puerta de atrás | `ORDEN-T01`, luego test Rust | I-5 en oráculo y en el nodo |
| C-07 | Exclusión de quien aporta espacio sin tokens (`C-BOT-03`) | abierto | P1 | C-02 | Barrera de entrada y concentración | Modelo económico | Fracción de espacio honesto excluida, por escenario |
| C-08 | Responsabilidad de firmas antes del depósito, tras el retiro y entre ramas (`C-EVP-04` pendiente) | abierto | P2 | C-04 | Castigo sin garantía en el pasado causal | Tras C-04 | Regla y casos |
| C-09 | Firmante seguro ligado a la identidad final (`archivo/crates/zx-consensus/src/firmante/`) | abierto | P1 | B-08 | Doble firma accidental castigable | Portado tras E-01 | Tests de persistencia antes de firmar en el árbol nuevo |

---

## D · Mecanismos de Filecoin (`P-ZRX/P-REGISTRO-SECTORES/`)

Los encargos 01–05 existentes se escribieron antes de `AUTO-ZRX.md`; para lanzarlos hay que
reescribirlos en la plantilla §6 (ENTRADA congelada, LINEO, límites de sesión) — fila E-09.

| ID | Problema | Estado | Prio | Depende de | Límite ya conocido | Siguiente encargo | Puerta |
|---|---|---|---|---|---|---|---|
| D-01 | Compromiso y alta de un sector real (encargo 01, G1) | **G1 superada** en su alcance (S01: pertenencia de la pieza al objeto comprometido; R2 32 B, apertura ~630 B, ~4,6 µs; `investigacion/01-formato-alta/REVISION.md`) | P1 | B-01 | RFT-03: R1/R2 no fechan | Encargo 01 en plantilla §6 | G1 |
| D-02 | Auditorías, regeneración y fallos honestos (encargo 02, G2) | abierto | P1 | D-01 | RFT-04: sobre el formato actual solo encarecen | Encargo 02 en plantilla §6 | G2 |
| D-03 | Ciclo de vida del sector en el DAG y vínculo con garantía (encargo 03, G3) | abierto | P1 | D-01, D-02, C-01 | No solapar con `C-EVP`/`C-SLA` sin prioridad | Encargo 03 | G3 |
| D-04 | Formato alternativo / PoRep (encargo 04, G4) | abierto; revisión de fuentes puede empezar ya | P2 | — (fuentes); D-01/D-02 (decisión) | RFT-06: ningún sellado separa ramas | Revisión de fuentes primarias Filecoin | G4 |
| D-05 | Sistema precompromiso + PoRep + auditorías (encargo 05, G5) | abierto | P2 | D-01…D-04, A-06 | Ninguno resuelve el doble farmeo privado | Encargo 05 | G5 |

---

## E · Infraestructura, rescate y proceso

| ID | Problema | Estado | Prio | Siguiente acción |
|---|---|---|---|---|
| E-01 | Línea base reproducible de primitivas candidatas desde `9681061` | **cerrado** 01:17: REPRODUCIDA (`P-ZRX/P-LINEA-BASE/REVISION.md`) | P0 | — |
| E-02 | El árbol nuevo no tiene workspace Rust ni proyecto Julia | en encargo (`P-ZRX/P-WORKSPACE/ORDEN-W01.md`, lanzada 01:15) | P0 | Migrar a la raíz tras revisar |
| E-03 | `.github/workflows/zerox-ci.yml` sigue en el árbol y llama a `Cargo`, `ci/alcance-consenso.sh`, `ci/citas-spec.sh`, etc., que ya no existen: cualquier ejecución de CI falla | abierto | P1 | Orden de CI nueva tras E-02. **No hacer push.** |
| E-04 | **B-HARNESS-01**: `MISSING_CREDENTIAL` en el lanzamiento headless | **cerrado** 01:03 (`R-ZRX/HARNESS.md`) | P0 | — |
| E-05 | `V-ZRX/LINEO.md` cita `veritas/plantilla/`, `veritas/julia.sh` y `veritas/nueva-auditoria.sh`, que no existen en el árbol nuevo (sí en el archivo) | abierto | P0 para órdenes Julia | Cada orden Julia crea su proyecto aislado en su zona; la plantilla se porta a `V-ZRX/` solo tras validarse |
| E-06 | `AGENTS.md` y `CLAUDE.md` del proyecto se borraron; `D-ZRX/SPEC.md` §0 aún invoca «la restricción de AGENTS.md contra comités» | abierto | P2 | Katana decide si hay instrucciones de repositorio nuevas; mientras, rige `AUTO-ZRX.md` |
| E-07 | Solo en `.trash` (no en git) quedan 95 archivos, entre ellos P-RELOJ, P-ECLIPSE, P-STAKE, P-VIVEZA y `T-ZRX/ESTADO-RELOJ.md` | parcialmente mitigado: las tres fuentes citadas por `RFT`/`IPA`/`SPEC` están copiadas con huellas en `R-ZRX/LEGADO/` | P1 | Katana decide si asegura el resto; vaciar `.trash` los perdería |
| E-08 | Hay otras sesiones (2 de Codex, 2 de Claude) con directorio de trabajo en este mismo repositorio (`ps`, 2026-09-26 00:31) | abierto | P1 | Comprobar mtime antes de escribir documentos compartidos; zonas de ejecución separadas por orden |
| E-09 | Encargos 01–05 de sectores no siguen la plantilla §6 del mandato | abierto | P1 | Reescritura como órdenes |

---

## X · Adversario compuesto y comparadores

| ID | Problema | Estado | Prio | Depende de |
|---|---|---|---|---|
| X-01 | Ensayar juntas las cuatro familias: sesgo del ancla, alta tardía, stake inmaduro, reorg que deshace una prueba, auditoría censurada, capacidad duplicada, rama privada | abierto | P2 | A-05, A-07, C-04, D-03 |
| X-02 | Comparador «candidato A»: PoST sin garantía en el arranque (`C-BOT-02`) y arranque sin PoW con requisito proporcional a la oferta (`R-ZRX/LEGADO/stake/MAPA.md` §4), bajo el mismo adversario, red y horizonte | abierto | P2 | A-05, A-10 |

---

## Bitácora de cambios

| Fecha | Cambio |
|---|---|
| 2026-09-26 | Alta inicial: familias A–E y X, camino crítico y bloqueo E-04 |
