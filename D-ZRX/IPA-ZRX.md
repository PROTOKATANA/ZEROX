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

## Camino crítico

```text
0.0.1 CERRADA (2026-09-28, c107163): W06d5…W06d10-B, SL-4b, RI-3, W07a…W07d, E-0 final.
0.0.2 (orden de Katana, P-ZRX/HOJA-DE-RUTA.md):
  (1) investigación, puerta de viabilidad: B-04 medición del doble farmeo · X-04 FV-2/FV-3 ·
      B-02 ρ_max → segundo VDF y N dinámico (ENCARGO-ND1) · B-07 eclipse · B-13 timestamps PoST
  (2) A-14 relevo de tx + B-07 prevención del eclipse
  (3) C-12 SL-2c (lista) · C-02 garantía por espacio · C-13 liquidez
  (4) B-12 coste de admisión GHOSTDAG (+ B-14)
  (5) D-01…D-05 Filecoin
0.0.3: X-04 FV-4 en el nodo + recuperación del eclipse · 0.0.4: A-11/A-12 minero SHA3 CPU/GPU
```

**Estado (2026-09-28 02:13):** 0.0.1 **cerrada** en `c107163`: veredicto en `D-ZRX/INFORME-0.0.1.md` §1, reglas en
`D-ZRX/SPEC-0.0.1.md`, mediciones en `V-ZRX/REGISTRO.md` §3, traspaso en `R-ZRX/TRASPASO-2026-09-28.md`. Lo de abajo
es el estado del 26 y se conserva como historia.

**Estado (2026-09-26 22:20):** en la raíz, 11 crates: `zx-core` (FORMATO v0.1 + `EvidenceTx` v4), `zx-pot`,
`zx-consensus` (PoW dev, motor de transición, fusión, evidencia y castigo), `zx-dag`, `zx-poas`, `zx-farmer`,
`zx-post`, `zx-cadena`, `zx-storage`, `zx-p2p`, `zx-node`. Diferenciales contra T01 v0.4 (2 795 casos) y T04
v0.5 (1 878): **0 discrepancias**. **Hito W06d4:** tres procesos `zx-node` reales cruzan el corte PoW → PoST
y convergen (528 bloques PoST, 0 rechazos). **En ejecución:** W06d5 (suite conjunta W06d4 + SL-4a, V5, V6b,
V7). **Siguen:** SL-4b, W07 (`P-ZRX/P-MEDICION/ESCENARIOS-0.0.1.md`), SPEC-0.0.1 e informe final. Traspaso:
`R-ZRX/TRASPASO-2026-09-26.md`. Plan: `P-ZRX/PLAN-0.0.1.md`.

---

## A · Transición PoW → PoAS + PoT + DAG

| ID | Problema | Estado | Prio | Depende de | Riesgo si se ignora | Siguiente encargo | Puerta que desbloquea |
|---|---|---|---|---|---|---|---|
| A-01 | Familias de bloque, fin del PoW, inicio del PoST, estado y rechazos de la transición | **cerrado**: oráculo T01 (29,5 M historias, 0 fallos; contrato v0.1) y motor Rust (W03, W02b); diferencial T01 v0.4 con 0 discrepancias (SL-4a) | P0 | CONTRATO | Historia con dos terminales, PoW tras el corte o bloque PoST sin garantía aceptados | `P-ZRX/P-TRANSICION/ORDEN-T01.md` | Oráculo pasa X-01…X-20 e I-1…I-7 en la rejilla pequeña |
| A-02 | Emisión PoW (`subsidio_pow`), madurez `M_cb` y madurez residual al cruzar el corte | abierto | P1 | A-10, A-12 | Recompensa inmadura usada como garantía; emisión concentrada. **No heredar** `SHIFT=26`, `COINBASE_MATURITY=12 000` (`PLAN-ARRANQUE-HIBRIDO.md` §3) | Derivación de `M_cb` desde horizonte de reorg PoW, tras A-10 | Desigualdades de madurez publicadas y comprobadas por el oráculo |
| A-03 | Depósitos bajo PoW (`H_dep`, `M_dep`), retiros que cruzan el corte | decidido provisional (TRN-03, TRN-10) | P0 simbólico / P1 valores | A-01 | Garantía que no existe al corte o que se libera sin retención | cubierto por `ORDEN-T01` | I-1, I-6, X-04…X-06 |
| A-04 | Predicado de corte (CUT-HWΦ) y valores `H_corte_min`, `W_min`, `S_min`, `K_min` | decidido provisional (D-T04) | P0 forma / P1 valores | A-05, A-08, A-10 | Activación con garantía nula o sin espacio; varios terminales sin regla | `ORDEN-T01` (forma) + modelo adversarial A-05 (valores) | Rechazos X-11/X-12; valores con coste absoluto |
| A-05 | Selección a través del corte (FC-3): terminal tardío, rama PoW pesada tras el corte, ataque «espacio + terminal», nodo que sincroniza desde cero | **decidido provisional con límite medido; en el nodo, conforme desde W06d7** (antes congelaba el terminal al primer PoST: hallazgo de W06d6); E-6b y V6(b) reales superados; falta el cambio de terminal del productor en caliente (SL-4b2) y un oráculo multiterminal (T04-E) (T02-A: FC-3 se mantiene; RFT-13: la ventana previa al primer bloque PoST es una carrera PoW de Nakamoto; `P-ZRX/P-TRANSICION/REVISION-T02.md`) | P1 | A-01 | Mayoría de hash borra historia PoST (FC-1) o PoW que no protege la distribución (FC-2) | `ORDEN-T02` (modelo adversarial Julia; por redactar tras T01) | Comparación FC-1/2/3/4 bajo el mismo adversario con coste absoluto |
| A-05b | Reducir lo que está en juego en la ventana previa al primer bloque PoST (p. ej. cerrar la admisión de depósitos `K` bloques antes del corte) | abierto | P1 | A-05 | Depósitos y pagos de los últimos bloques con seguridad solo PoW (RFT-13) | Variante del oráculo T01 + modelo T02 | Coste de la variante frente a la reducción del riesgo |
| A-06 | Historia PoAS al corte: segmento génesis rellenado (D-T05), `history_size`, archivado de bloques PoW, caducidad de sectores sin alturas lineales (`C-EXP-*` de SPEC-v dependen de altura) | abierto | P1 | E-01, B-01 | Primer bloque PoST imposible de plotear o verificar | Orden de formato (Rust) tras `ORDEN-L01` | Parcela real ploteada sobre la historia de la red dev y verificada en el primer bloque PoST |
| A-07 | Semilla PoT del corte y sesgo del minero del terminal (elegir o callar el bloque) | abierto; derivación inicial en `P-ZRX/P-TRANSICION/NOTA-A07-SEMILLA.md` (candidato S3, semilla retardada `D` slots con `D·τ/ρ_max ≫ T_pow/(1−h)`, sin instrumento) | P1 | A-01, B-02 | Un minero —o un Estado con hash— elige los primeros retos. Lectura **no validada** del archivo: «una pata de PoW pequeña la domina un Estado y entonces controla la entropía del ancla» (`archivo/P-ZRX/T-ZRX/AGUJEROS-Y-SOLUCIONES.md` §«PoW en lugar del VDF») | `ORDEN-T03` (modelo de sesgo; por redactar) | Sesgo máximo cuantificado para cada candidato de `derivar_semilla` (CONTRATO §8) |
| A-08 | Fallo de activación: `Φ` nunca verdadero; censura de depósitos por mayoría de hash que prolonga la emisión PoW | abierto; **riesgo confirmado** por T02-A E4: con `h ≤ 1/2` retraso finito (p. ej. `h = 0,4`, `M_dep = 12`: media 25 `T_pow`), con `h = 0,9` y `M_dep ≥ 6` la censura domina (81–99,98 % sin corte en `10⁴ T_pow`) | P1 | A-04 | Fase PoW indefinida y emisión capturada | Incluido en `ORDEN-T02` | Regla de fallo elegida con coste del ataque de censura |
| A-09 | Sincronización desde cero de ambas familias, nodo que llega tarde, reinicio en la frontera | **cerrado para la red dev (2026-09-28):** nodo tardío (W06d6; W07b E-5 3/3, al día en ≈ 60–64 s), reinicio tras `SIGKILL` (W07b E-4 3/3) y reunión tras partición con el mismo terminal y con terminales distintos (W07b E-6 y E-6b 3/3, aislamiento verificado), todo con el mismo estado por el método W07d. Queda fuera: redes de más de 4 nodos y WAN | P0 | B-08, A-01 | Nodos con estados distintos tras el corte | Orden de integración (fase 4 del PLAN) | Varios nodos reinician y sincronizan cruzando el corte |
| A-10 | Coste absoluto del ataque al prefijo PoW: hashrate CPU/GPU medido, hash alquilable, concentración de recompensas | **parcial**: hashrate medido (A10-M1): CPU 73,8 MH/s en reposo (16 hilos; SMT no aporta), GTX 1070 561 MH/s = 7,6×, 1,94·10⁻⁷ J/hash (`P-ZRX/P-POW/REVISION-A10-M1.md`); faltan GPU actual, ASIC, alquiler y precios — antes: **el archivo no tenía ninguna medida** de PoW de arranque (catálogo de refutaciones, 2026-09-26) | P1 | A-12 | Arranque reescribible con poco dinero; la energía gastada no prueba distribución | Benchmark por candidato de A-12 | Tabla recurso → coste de reescribir `k` bloques, con fuente y fecha |
| A-11 | `caliza` (kernel HIP/CUDA) y `silicio` (bucle Rust) como mineros | **Katana 2026-09-27: se corrigen y reutilizan en 0.0.4** (minero Rust CPU + HIP GPU AMD, `P-ZRX/PLAN-0.0.2.md`); antes: divergencias ya **verificadas por lectura**: caliza aplica Keccak-f crudo sin relleno ni dominio (`archivo/crates/zx-core/tests/cavp_sha3_256.rs:3-5` documenta que falla 237 vectores), nonce en bytes 48–55 (`caliza/src/excavadora.cc:73`) frente a 96 (`zx-core/src/preimage/block.rs:76`), criterio de bytes cero (`caliza/src/titanio/sha3.h:115`) frente a `hash < target` U256 (`target.rs:239-241`); `silicio` no compila `minero.rs` y no compara target | P2 | E-01, A-12 | Declarar minero compatible por compartir SHA3 | `ORDEN-L02` (prueba diferencial, por redactar) | Veredicto por pieza: fuente de ideas / portar con cambios / descartar |
| A-12 | Algoritmo PoW: SHA3-256 heredado (verificador y vectores CAVP existen) frente a alternativas (p. ej. memoria-dura) | **decidido por Katana (2026-09-27): SHA3-256, minable en CPU y GPU** (accesibilidad; no se reivindica resistencia a hash alquilado ni a ASIC); antes: fuentes revisadas en `P-ZRX/P-POW/NOTA-A12-ALGORITMO.md` (ECIP-1049: hash alquilado en ETC; RandomX: CPU, 4 auditorías 2019) | P1 | — | Elegir por facilidad; ASIC o GPU alquilada dominan el arranque | Investigación de fuentes + medición (por redactar) | Comparación accesibilidad doméstica / coste adversario / auditoría de la primitiva. **Probable pregunta a Katana** con datos (prioridad de accesibilidad frente a resistencia) |
| A-13 | Red dev separada: génesis, identificador de rama y límites de dificultad explícitos; PoW real de dificultad de desarrollo | **hecho para dev**: PoW dev real (W04), `consensus_branch_id` distinto por red (test de RAT-1, SL-4a), perfil `P-ZRX/P-RED-DEV/PERFIL-DEV-v0.md`; tres nodos minan y cruzan el corte (W06d4) | P0 | E-02, A-01 | Parámetros dev filtrados a producción | Orden de integración | Primer hito de `PLAN-ARRANQUE-HIBRIDO.md` §5 |
| A-14 | **Entrada de productores tras el corte**: en 0.0.1 un nodo que llega al corte sin garantía `≥ q` **no puede obtenerla nunca** (no hay relevo de transacciones: un nodo solo incluye sus depósitos en sus propios bloques, y sin garantía no produce). Con varias claves por nodo, `K_min` puede cumplirlo un solo operador y el corte deja fuera a los demás | abierto (hallazgo en W07b E-2a, 2026-09-27, verificado por el director en los registros: B minó 26 de ≈ 31 bloques PoW con tres claves, A y C sin garantía, 0 bloques PoST) | P1 | A-04, C-02 | Red cerrada a los que no minaron en la fase PoW; contra la accesibilidad de entrada y la descentralización | Relevo de transacciones (mempool, gossip de tx con límites C-NET) para que cualquier productor incluya depósitos ajenos; `K_min` por operador es inverificable | Un nodo sin garantía al corte deposita y produce |

---

## B · Producción PoAS + PoT y orden DAG

| ID | Problema | Estado | Prio | Depende de | Riesgo | Siguiente encargo | Puerta |
|---|---|---|---|---|---|---|---|
| B-01 | Verificador y plotter PoAS (Autonomys `f8842d0`, `nightly-2026-05-03`, `ab-proof-of-space`) | **cerrado**: L01 reproducida; `zx-poas`/`zx-farmer` validados contra el verificador de Autonomys `f8842d0` (W05b1) | P0 | E-04 | Portar sin reproducir; copiar un crate sin su lock | `ORDEN-L01` | Suites acotadas reproducidas con salida conservada |
| B-02 | Primitiva PoT (`zx-pot`, 32 vectores) y parámetros `N(s)`, `ρ_max`, segundo VDF | **0.0.2, paso 1 (Katana, 2026-09-27): medir `ρ_max` y, con ese dato, decidir el segundo VDF y `N(s)` (fijo o dinámico con techo; la ley de adaptación no existe, `R-ZRX/LEGADO/reloj/ESTADO-RELOJ.md`)**; primitiva **cerrada** (`zx-pot`, L01); parámetros `ρ_max`, segundo VDF y `SR` abiertos (W07 mide el slot real: 1,66 s por slot con `N_dev`, W06d1) | P0 / P1 | E-04 | RFT-12: adelanto no anulado | `ORDEN-L01`; parámetros después | Vectores reproducidos; `ρ_max` medido por hardware objetivo |
| B-03 | GHOSTDAG, admisión contextual, `C-GD-07`, almacén causal (en el archivo, en memoria y fuera de la ruta activa) | **cerrado para 0.0.1**: GHOSTDAG portado (W05a) y admisión contextual en `zx-cadena` con hasta 15 padres e identidad real (W06a-C); coste de admisión en B-12 | P0 | E-01 | Oráculo GHOSTDAG ≠ ruta de red (`AUTO-ZRX.md` §4) | `ORDEN-L01` (línea base) y portado posterior | Admisión y orden deterministas en el nodo nuevo |
| B-04 | Doble farmeo en rama privada | **0.0.2 (Katana, 2026-09-27): medir su magnitud en la red dev**, primer paso de la versión; cerrado como **no evitable** (RFT-01, RFT-14: ningún mecanismo de PoStake ni de Filecoin lo encarece de forma exigible frente al atacante autosuficiente); **mitigación adoptada en principio**: finalidad por votos (X-04); magnitud **no medible** hasta cablear el nodo (`archivo/P-ZRX/T-ZRX/ESTADO-DOBLE-FARMEO.md` §5) | P2 | B-08 | Vender el híbrido como solución | Medición tras 0.0.1 | Umbral medido en la red dev |
| B-05 | `C-FIN-01`, `F_slots`, `Δ` real | abierto; W07b midió en localhost propagación p50 ≈ 170 ms, p95 ≈ 0,4 s, máx. ≈ 1,2 s, y slot real 1,28 s (W06d1 dio 1,66 s en la misma máquina, sin explicar); `Δ_p99` sin calcular y sin red WAN; `F_SLOTS = 600` en dev (≈ 13 min) | P1 | B-08 | Finalidad lenta; `F` tiene signo opuesto en doble farmeo y eclipse | Medición multinodo | `Δ_p99` medida y `F_slots` derivado |
| B-06 | Pools con espacio ajeno; firma a ciegas (RFT-11) | coinbase v3 atada a `sol.public_key` en la puerta conjunta (`crates/zx-post/src/cabecera_conjunta.rs:98`; O4 de P-DISUASION: exigible, sin detección); quita el premio, no la capacidad de firmar a ciegas (RFT-11) | P1 | C-01 | Operador de pool produce en la rama que elige | Diseño de arquitectura granjero-valida-contexto | Regla y prueba de que la coinbase no paga otra clave |
| B-07 | Eclipse y partición mayor que `F` (se paga en IP, no en espacio) | abierto; hay descubrimiento por Kademlia pero **sin gestor de direcciones** (diversidad por prefijo, anclas, renovación); en 0.0.1 la exposición es el corte: `C-FIN-01` entre terminales deja para siempre en el terminal del atacante a un nodo eclipsado más de `F_SLOTS = 600` slots (≈ 13 min a 1,28 s por slot); tras el corte, las particiones del mismo terminal se fusionan (E-6). P-ECLIPSE (`R-ZRX/LEGADO/eclipse/INFORME.md`) derivó la partición permanente con las reglas viejas de flujos. **Katana, 2026-09-27: investigación en 0.0.2 paso 1, prevención en 0.0.2 con el relevo de tx, recuperación con los votos en 0.0.3** | **P1** | B-08 | Partición permanente de un nodo | Orden de red (por redactar) | Renovación de pares y medida |
| B-08 | **Ruta activa del nodo**: admisión, orden, estado seleccionado, UTXO, rollback, propagación, sincronización y reinicio (el nodo antiguo seguía lineal) | **cerrado para 0.0.1 (2026-09-28, `c107163`):** W06d1…W06d10-B migradas y medidas con procesos reales en W07b; E-0 final desde un clon limpio (891/0/6). Límites en B-13, B-14, B-07 y E-10 | P0 | B-01…B-03, C-01, A-01 | Declarar 0.0.1 con bibliotecas sueltas | Serie de órdenes de integración (fase 4 del PLAN) | Criterio de cierre de `AUTO-ZRX.md` §8 |
| B-09 | Sesgo eligiendo la clave (`public_key → sector_id → bucket`); ocupación bimodal de s-buckets | abierto, sin medir | P2 | B-01 | El stake no lo corrige: se muelen claves antes de depositar | Medición con plotter real | Ventaja de molienda cuantificada |
| B-11 | **Semántica de estado en el DAG**: aplicación al fusionar (`C-ORD-03`), descarte silencioso (`C-ORD-04`), cobro de azules y `rojo_k` (`R-FIN-8′`) combinados con garantía, coinbase atribuida y corte | **cerrado**: oráculo T04 (v0.5) y `zx-cadena`; diferencial 0 discrepancias sin emulación (W06a-B, SL-4a) | P0 | W03, W05a | Nodo que inventa la semántica de fusión o que invalida bloques por conflictos de tx | T04 (oráculo) y W06a | Diferencial Rust ↔ T04 |
| B-10 | Semántica de altura/slot en el DAG (`C-HDR-02` pendiente en SPEC-v); reglas que dependían de altura lineal (`C-EMIT`, `C-EXP`, `C-CHK`, `C-UPG`, `C-REORG-07`) | abierto | P1 | A-01 | Mezclar bloques y slots sin `λ` | Parte de los contratos de integración | Cada regla con unidad única |
| B-12 | **Coste de admisión GHOSTDAG no acotado** (**objetivo 0.0.2**, Katana 2026-09-27): U2 (`pasado_contiene_ident`) y la unión de `anc` recorren el pasado entero del padre; `blue_idents` se copia por bloque. Medido por RI-1b: 90 µs → 1,66 ms por inserción de N = 2 000 a 16 000 en una **cadena lineal honesta** | abierto; **no** bloquea 0.0.1 dev (≈ 2 000 bloques en 30 min), **sí** cualquier red larga | P1 | B-11 | Degradación del validador con el tiempo, sin coste para el atacante; memoria O(N²) | Índice de alcanzabilidad acotado (intervalos, tipo Kaspa) + índice de identidades por pasado | Coste por admisión constante (o logarítmico) medido hasta 10⁶ bloques |
| B-13 | **Timestamp de la cabecera PoST sin regla** (hallazgo del director, 2026-09-27): el productor lo escribe (`zx-post::productor`, `productor_regimen`) y **nadie lo valida** (ni monotonía ni FTL; el PoW sí, `zx-consensus::timestamps`). Es la entrada que necesitaría un `N` dinámico | abierto; **no** bloquea 0.0.1 (ninguna regla lo consume: `N` y `SR` son constantes) | P1 | — | Si una regla futura lo consume sin validarlo, el reloj queda en manos del productor; posible grano libre en el hash de la cabecera | `P-ZRX/P-N-DINAMICO/ENCARGO-ND1.md` (N1) | Monotonía respecto al pasado, FTL y relación timestamp–slot redactadas y atacadas |
| B-14 | **Rechazo por tope de terminales cacheado para siempre** (W06d10-B, límite aceptado): `Cadena::admitir` guarda todo rechazo y no hay API para olvidarlo; un bloque rechazado por `ErrLimiteTerminales` (tope local de 8 terminales con DAG) ya no penaliza, pero **no se reevalúa** si la vista local cambia | abierto; solo importa con más de 8 terminales compitiendo en el corte | P2 | B-08 | Un nodo puede quedarse sin ver un terminal que después sería el seleccionado | Orden corta en `zx-cadena` (0.0.2): `Cadena::olvidar` o no cachear `ErrLimiteTerminales` | Test: noveno terminal rechazado y admitido tras desalojar a uno de los ocho |

---

## C · Mecanismos de PoStake (garantía, evidencia, slashing)

| ID | Problema | Estado | Prio | Depende de | Riesgo | Siguiente encargo | Puerta |
|---|---|---|---|---|---|---|---|
| C-01 | Registro de garantía por clave (`C-BON-01`): codificación canónica, estados, poda de incidentes, undo | **cerrado** en el oráculo (T01) y en el motor (W03); codificación canónica en FORMATO v0.1 | P0 | A-01 | Garantía creada o perdida por un reorg | `ORDEN-T01`, luego orden Rust | I-1/I-2 en oráculo y en código |
| C-02 | `requisito(B)`: forma (fija, por capacidad, por oferta) y cuantía | abierto; SL-2: garantía **por identidad** regresiva para `f_h ≲ 10⁻⁵` (RFT-23) → recomendación **por unidad de espacio**; dev `q = 20` por clave | P1 | A-10, D-03 | RFT-05: un coste fijo por clave solo domina por debajo de un tamaño. `P-CLAVE` (claves de saldo cero, soborno cero) queda **condicional**: `C-BON-04` exige `requisito > 0`, lo que retira la premisa «claves gratis» pero no R-5 | Modelo económico (por redactar) | Barrera de entrada y pérdida posible cuantificadas bajo el mismo adversario |
| C-03 | Retiro, `R_slots`, `M_estabilidad_slots`, liberación | **decidido provisional (dev)**: `R_slots ≥ F_slots`, `T_v = 10⁵` slots, `ρ_ret = 0,10` (`REVISION-SL2b.md`); liberación con la puerta de RAT-3 implementada (SL-4a) | P1 | C-04, B-05 | Retirar antes de que llegue la evidencia | Tras C-04 | Desigualdad `R_slots > Q_corr + T_reporte + M_estab` con valores medidos |
| C-04 | `EvidenceTx`: codificación, deduplicación por incidente, plazo, disponibilidad, reorg | **implementado en formato, motor y cadena** (SL-1 contrato ratificado; SL-3b oráculos; SL-4a Rust, 0 discrepancias); RI-3b halló `cbid` y orden canónico tratados como semánticos (contra el contrato): oráculos (SL-4c-O, T01 v0.5, T04 v0.6) y Rust (SL-4c, migrada `ec9c6b9`: forma, decodificación de red de la v4, 0 discrepancias) corregidos; falta el nodo (SL-4b2) | P1 | C-01 | Evidencia censurada o aplicada dos veces | Orden de formato (por redactar) | Oráculo de incidentes + casos adversariales |
| C-05 | `C-SLA`: correlación `b`, `c`, `Q_corr`; falsos positivos honestos | **cerrado: descartado** (RFT-15, DS-5; `DS-L02`: pérdida no correlacionada con fracción fija) | P2 | C-04 | Castigo catastrófico por error compartido | Tras C-04 | Tasa de castigo honesto medida |
| C-06 | Complementariedad: más stake no aumenta oportunidades ni `blue_work` | I-5 **superado en el oráculo** (T01) y recorrido por el diferencial T01; sin test Rust propio de I-5 (búsqueda en `crates/`, 22:20) | P0 | A-01 | Stake convertido en peso por la puerta de atrás | `ORDEN-T01`, luego test Rust | I-5 en oráculo y en el nodo |
| C-07 | Exclusión de quien aporta espacio sin tokens (`C-BOT-03`) | abierto | P1 | C-02 | Barrera de entrada y concentración | Modelo económico | Fracción de espacio honesto excluida, por escenario |
| C-08 | Responsabilidad de firmas antes del depósito, tras el retiro y entre ramas (`C-EVP-04` pendiente) | abierto | P2 | C-04 | Castigo sin garantía en el pasado causal | Tras C-04 | Regla y casos |
| C-10 | **Repetición de operaciones de garantía y unicidad de `txid`** (defecto de FORMATO-v0) | **cerrado**: nonce por clave en formato (F-15), oráculos T01-D y T04-C, motor y productor (W02b); rechazo de repeticiones en los diferenciales | P0 | W03-R, W05b2 | Retiro forzado de la garantía ajena; colisión de salidas | Orden de formato+motor y ampliación de T01/T04 | Diferencial con nonce y rechazo de repeticiones |
| C-09 | Firmante seguro ligado a la identidad final (`archivo/crates/zx-consensus/src/firmante/`) | **portado** (SL-4b1, migrada `de26376`: `zx-post/src/firmante/`, identidad RAT-1); integración en el nodo en SL-4b2 (redactada); `FIR-*` en `P-ZRX/P-SLASHING/CONTRATO-EVIDENCIA-v0.md`; extender al voto cuando exista la capa (FV-1, D4) | P1 | B-08 | Doble firma accidental castigable | Portado tras E-01 | Tests de persistencia antes de firmar en el árbol nuevo |
| C-11 | **Activar evidencia y castigo** (Katana, 2026-09-26): contrato de `EvidenceTx` v4, firmante seguro, calibración contra falsos positivos, oráculo e implementación | **activo en la red dev** (SL-4b2, `fbab3b7`): doble firma castigada de extremo a extremo 3/3; SL-4b3 (transición con firmante, guardián de CI, tests de inclusión) hecha | P1 | C-04, C-05, C-09 | Castigar a honestos; evidencia censurada; retirar antes de la evidencia | `P-ZRX/P-SLASHING/PROGRAMA.md` | Contrato ratificado; región de parámetros no vacía; diferencial SL-3/SL-4 |
| C-12 | **Retención de recompensas** (`ρ_ret`, `T_v`): el modelo de disuasión (DS-2, DS-3, SL-2, SL-2b) supone retener una fracción de cada recompensa durante `T_v`; **ninguna regla la implementa** (SL-1 no la pidió; SL-4a la puso como parámetro sin regla: errores del director, diagnóstico de la sesión zerox-e7 verificado en el código). **Pero** D-T08 acredita el **100 %** de la coinbase PoST a la garantía (`creditar_post`, madura en `M_REC_SLOTS = 30`), EV-17 congela y confisca la garantía **total** con `f = 1`, y RAT-3 impide liberar mientras se produce (`último producido + 360` slots) y exige `R_SLOTS = 600` tras el retiro: las recompensas no retiradas ya son confiscables, con otra forma que la del modelo | abierto | P1 | C-11 | Reivindicar una disuasión no comprobada, o añadir una regla innecesaria | **SL-2c** (DeepSeek, Julia, tras W07b para no perturbar sus mediciones): ¿D-T08 + EV-17 + RAT-3 con los valores del nodo dan la región de SL-2b? (cuidando la reserva F5 de unidades). Solo si no, contrato + oráculo + Rust de una regla de retención | Región de disuasión comprobada con las reglas que existen |
| C-13 | **Liquidez del productor honesto**: con D-T08 (la coinbase PoST va a la garantía) y RAT-3 (liberar exige `slot ≥ último_slot_producido + Plazo_slots + M_margen_slots`), un productor que produce sin parar con una clave **no puede disponer nunca** de sus recompensas PoST sin dejar de producir con ella ≥ 360 slots más `R_SLOTS` (o rotar claves) | abierto (derivación del director, 2026-09-27, al redactar SL-2c; sin medir) | P1 | C-03, C-12 | Hacer inviable al granjero doméstico que vive de sus recompensas; empujar a rotar claves | SL-2c cuantifica el coste; decisión de diseño después (p. ej. liberar la parte madura anterior a `último producido − Plazo − M`) | Coste de liquidez medido y regla elegida |

---

## D · Mecanismos de Filecoin (`P-ZRX/P-REGISTRO-SECTORES/`)

Los encargos 01–05 existentes se escribieron antes de `AUTO-ZRX.md`; para lanzarlos hay que
reescribirlos en la plantilla §6 (ENTRADA congelada, LINEO, límites de sesión) — fila E-09.

**Katana, 2026-09-27: los mecanismos de Filecoin (D-01…D-05) son el objetivo de la versión 0.0.2** (con el relevo de transacciones y el PoStake pendiente; 0.0.3 finalidad, 0.0.4 minero: `P-ZRX/HOJA-DE-RUTA.md`) (`P-ZRX/PLAN-0.0.2.md`); en 0.0.1 quedan fuera (`SEC-0`).

| ID | Problema | Estado | Prio | Depende de | Límite ya conocido | Siguiente encargo | Puerta |
|---|---|---|---|---|---|---|---|
| D-01 | Compromiso y alta de un sector real (encargo 01, G1) | **G1 superada** en su alcance (S01: pertenencia de la pieza al objeto comprometido; R2 32 B, apertura ~630 B, ~4,6 µs; `investigacion/01-formato-alta/REVISION.md`) | P1 | B-01 | RFT-03: R1/R2 no fechan | Encargo 01 en plantilla §6 | G1 |
| D-02 | Auditorías, regeneración y fallos honestos (encargo 02, G2) | parte a hecha: **encarece, no impide** (`t_reg` ≈ 0,9 s·núcleo por registro; **GPU medida (DS-4): 0,0545 s por registro en GTX 1070 (tabla v2), ≈ 7,1 GPU y 677 W por TiB para farmear regenerando**; apertura sin sector 10^6–10^7× más cara; `investigacion/02-auditorias/REVISION.md`); falta S02b (plazos, falsos positivos) | P1 | D-01 | RFT-04: sobre el formato actual solo encarecen | Encargo 02 en plantilla §6 | G2 |
| D-03 | Ciclo de vida del sector en el DAG y vínculo con garantía (encargo 03, G3) | abierto | P1 | D-01, D-02, C-01 | No solapar con `C-EVP`/`C-SLA` sin prioridad | Encargo 03 | G3 |
| D-04 | Formato alternativo / PoRep (encargo 04, G4) | abierto; revisión de fuentes puede empezar ya | P2 | — (fuentes); D-01/D-02 (decisión) | RFT-06: ningún sellado separa ramas | Revisión de fuentes primarias Filecoin | G4 |
| D-05 | Sistema precompromiso + PoRep + auditorías (encargo 05, G5) | abierto | P2 | D-01…D-04, A-06 | Ninguno resuelve el doble farmeo privado | Encargo 05 | G5 |

---

## E · Infraestructura, rescate y proceso

| ID | Problema | Estado | Prio | Siguiente acción |
|---|---|---|---|---|
| E-01 | Línea base reproducible de primitivas candidatas desde `9681061` | **cerrado** 01:17: REPRODUCIDA (`P-ZRX/P-LINEA-BASE/REVISION.md`) | P0 | — |
| E-02 | El árbol nuevo no tiene workspace Rust ni proyecto Julia | **cerrado**: W01 migrada (`29b6bd6`) | P0 | Migrar a la raíz tras revisar |
| E-03 | `.github/workflows/zerox-ci.yml` sigue en el árbol y llama a `Cargo`, `ci/alcance-consenso.sh`, `ci/citas-spec.sh`, etc., que ya no existen: cualquier ejecución de CI falla | **corregido en el flujo** (W06d1): paso de clonado fijado de Autonomys `f8842d0`; **no ejecutado en remoto** (sin push) |
| E-04 | **B-HARNESS-01**: `MISSING_CREDENTIAL` en el lanzamiento headless | **cerrado** 01:03 (`R-ZRX/HARNESS.md`) | P0 | — |
| E-05 | `V-ZRX/LINEO.md` cita `veritas/plantilla/`, `veritas/julia.sh` y `veritas/nueva-auditoria.sh`, que no existen en el árbol nuevo (sí en el archivo) | abierto | P0 para órdenes Julia | Cada orden Julia crea su proyecto aislado en su zona; la plantilla se porta a `V-ZRX/` solo tras validarse |
| E-06 | `AGENTS.md` y `CLAUDE.md` del proyecto se borraron; `D-ZRX/SPEC.md` §0 aún invoca «la restricción de AGENTS.md contra comités» | abierto | P2 | Katana decide si hay instrucciones de repositorio nuevas; mientras, rige `AUTO-ZRX.md` |
| E-07 | Solo en `.trash` (no en git) quedan 95 archivos, entre ellos P-RELOJ, P-ECLIPSE, P-STAKE, P-VIVEZA y `T-ZRX/ESTADO-RELOJ.md` | **cerrado** (PK-02, Katana: sí): los 90 cuyo contenido no estaba en git, en `R-ZRX/LEGADO/solo-trash/` con huellas de origen. Antes, parcialmente mitigado: las tres fuentes citadas por `RFT`/`IPA`/`SPEC` están copiadas con huellas en `R-ZRX/LEGADO/` | P1 | Katana decide si asegura el resto; vaciar `.trash` los perdería |
| E-08 | Hay otras sesiones (2 de Codex, 2 de Claude) con directorio de trabajo en este mismo repositorio (`ps`, 2026-09-26 00:31) | abierto; por la tarde otra sesión de Claude preparó con Katana `P-FINALIDAD-VOTOS/` y `P-AUSENCIA-VOTO/` sin commitear, y se duplicó un número de decisión (FV-D03, renumerado en `6bf026d`): comprobar `git status` antes de escribir allí | P1 | Comprobar mtime antes de escribir documentos compartidos; zonas de ejecución separadas por orden |
| E-09 | Encargos 01–05 de sectores no siguen la plantilla §6 del mandato | abierto | P1 | Reescritura como órdenes |
| E-10 | **Reinicio sin instantáneas** (D-N03′): el nodo 0.0.1 reconstruye el estado repitiendo todas las admisiones; lineal en la historia | abierto; aceptado para la red dev | P2 | Tras 0.0.1: instantánea de estado con compromiso verificable y su undo; W07 mide el coste del reinicio |
| E-11 | **Revisión independiente de código omitida** en W02–W05b2 pese a `PLAN-0.0.1` §4 (error del director) | RI-1a/b (W02–W05b2) y RI-2a/b (W05b3–W06d1) **hechas**, hallazgos corregidos; **RI-3 hecha** (a: tres DoS de red; b: forma de la evidencia; c: **crítico**, persistir antes de admitir impedía reiniciar): correcciones en W06d6 (a, c) y SL-4c-O/SL-4c (b) | P0 | Verificar las correcciones en W06d6 y SL-4c |

---

## X · Adversario compuesto y comparadores

| ID | Problema | Estado | Prio | Depende de |
|---|---|---|---|---|
| X-01 | Ensayar juntas las cuatro familias: sesgo del ancla, alta tardía, stake inmaduro, reorg que deshace una prueba, auditoría censurada, capacidad duplicada, rama privada | abierto | P2 | A-05, A-07, C-04, D-03 |
| X-02 | Comparador «candidato A»: PoST sin garantía en el arranque (`C-BOT-02`) y arranque sin PoW con requisito proporcional a la oferta (`R-ZRX/LEGADO/stake/MAPA.md` §4), bajo el mismo adversario, red y horizonte | abierto | P2 | A-05, A-10 |
| X-03 | **Disuasión por coste** (Katana, 2026-09-26): qué problemas resuelven o encarecen PoStake y Filecoin frente a B0 (PoST puro de `9681061`) y a B1 (0.0.1), con coste absoluto de X por dimensión (riesgo, inmovilización, adquisición, energía, hardware, tiempo) | **cerrado con resultados** (`P-ZRX/P-DISUASION/SINTESIS.md`, DS-1…DS-6): ningún mecanismo encarece el doble farmeo de forma exigible frente al atacante grande (RFT-14, RFT-15); el castigo con evidencia sí encarece al que recluta con el reparto real de un pool (DS-6); mejoras exigibles contra espacio ajeno (O4), sembrador (sectores y auditorías), Sybil (garantía) y largo alcance (sellado, PoT, finalidad) | P1 | A-10, C-02, D-02 |
| X-04 | **Finalidad por votos bajo R1–R5** (mitigación del doble farmeo): adoptada en principio por Katana (FV-D02) | **diseño hecho, sin contrato ratificado**: FV-1 (dos ejecuciones) y AV-1 revisados; Katana fija FV-D01…FV-D07 (peso = sectores registrados, VRF con `b = 2`, falta «elegido sin voto» con `m_aus` proporcional con mínimo, sin premio). Refutaciones: RFT-17…RFT-21. Siguiente: FV-2 (modelo cuantitativo), FV-3 (oráculo), FV-4 (Rust). **desbloqueado** (FV-D08, Katana 2026-09-27): garantía como peso **solo en dev** tras una interfaz por sector; FV-2, FV-3 y FV-4 tras cerrar 0.0.1 | P1 | B-05 (Δ), D-01…D-03 (registro de sectores) |

---

## Bitácora de cambios

| Fecha | Cambio |
|---|---|
| 2026-09-26 | Alta inicial: familias A–E y X, camino crítico y bloqueo E-04 |
| 2026-09-26 03:55 | C-10 en encargo; E-02 cerrado; E-03 reabierto (la CI remota no materializa el clon); E-10 (reinicio sin instantáneas) y E-11 (revisión independiente omitida) nuevos; A-10 en encargo |
| 2026-09-26 03:57 | B-12 nuevo (RI-1b H1, coste de admisión GHOSTDAG con la profundidad) |
| 2026-09-26 04:09 | A-10 parcial: hashrate CPU\/GPU medido (A10-M1) |
| 2026-09-26 08:30 | X-03 nuevo: programa P-DISUASION (DS-1…DS-4) a petición de Katana |
| 2026-09-26 19:49 | X-04 nuevo: capa de finalidad por votos adoptada en principio por Katana |
| 2026-09-26 22:20 | Puesta al día: A-01, B-01, B-03, B-11, C-01, C-05 (descartado), C-10 y X-03 cerrados; A-13 hecho para dev; A-09, B-08 y C-11 en curso (W06d5, SL-4b); C-03 provisional; E-11 pide RI-3; X-04 con diseño hecho y bloqueo de la fuente de peso; camino crítico redibujado |
| 2026-09-26 23:02 | Sesión nueva: RI-3a/b lanzadas (E-11); SL-4b partida en SL-4b1 (lanzada, C-09) y SL-4b2 (redactada); W07 partida en W07a (redactada), W07b (por redactar) y W07c (lanzada); X-04 `bloqueado (Katana)` para FV-4 (PK-01) |
| 2026-09-27 | A-05 conforme desde W06d7; C-09 y C-11 activos (SL-4b1…SL-4b3); E-07 cerrado (PK-02); X-04 desbloqueado (FV-D08); A-14, C-13 nuevos; B-04, B-12 y la familia D pasan a objetivo 0.0.2 (hoja de ruta de Katana); B-02 con `ρ_max`, segundo VDF y `N` dinámico en 0.0.2 paso 1; B-07 a P1 (eclipse: investigación y prevención en 0.0.2, recuperación en 0.0.3); B-13 nuevo (timestamp PoST sin validar) |
| 2026-09-28 02:13 | **0.0.1 cerrada** (`c107163`): A-09 y B-08 cerrados para dev; B-05 con las cifras de W07b; B-14 nuevo (tope de terminales cacheado, W06d10-B); camino crítico reescrito para 0.0.2 |
