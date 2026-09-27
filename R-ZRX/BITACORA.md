# Bitácora de dirección — ZEROX híbrido

Memoria de investigación: qué se hizo, por qué se decidió cada cosa y qué quedó pendiente.
Horas de `date -Is` (zona +02:00). Firma: Claude, en el rol de director técnico de `AUTO-ZRX.md`.

## 2026-09-26 — arranque del mandato `AUTO-ZRX.md`

### Lectura de autoridad (00:30–00:40)

Leídos íntegros: `AUTO-ZRX.md`, `D-ZRX/RDM-ZRX.md`, `D-ZRX/SPEC.md`,
`P-ZRX/PLAN-ARRANQUE-HIBRIDO.md`, los siete documentos de `P-ZRX/P-REGISTRO-SECTORES/` y
`V-ZRX/LINEO.md`. Del archivo antiguo, leídos directamente: `AGENTS.md`,
`P-ZRX/PIEZAS-DE-CODIGO/HOJA-DE-RUTA.md`, `P-ZRX/T-ZRX/ESTADO-DOBLE-FARMEO.md`,
`P-ZRX/T-ZRX/LIBRO-DE-RESTRICCIONES.md`, `P-ZRX/P-STAKE/MAPA.md`.

Tres inventarios de **solo lectura** del archivo se delegaron a subagentes de Claude (no a
DeepSeek: no escriben ni ejecutan código del proyecto): código por pieza, catálogo de refutaciones
y reglas del SPEC antiguo. Sus afirmaciones que entran en documentos se comprobaron en la fuente
(offset del nonce, comparación de target, LWMA, caliza, citas de P-EQUIVOCACION, P-COBERTURA,
P-SELLO, P-CLAVE, P-POOLS, AGUJEROS, ESTADO-RELOJ, P-REVELACION, P-SEGUNDO-VDF, CAVP).

### Estado de la máquina y del repositorio

- `uptime` 00:31: carga 0,18. Procesos con `cwd` en este repositorio: 2 de Codex, 2 de Claude además
  de esta sesión (IPA E-08). `D-ZRX/IPA-ZRX.md` y `RFT-ZRX.md` tenían 1 byte (mtime 2026-09-25
  21:21 y 20:56) antes de escribirlos.
- Árbol: 4 659 rutas borradas sin commit; nada nuevo commiteado. No se ha hecho ningún commit en
  esta sesión.

### Harness (00:31–00:36) → `R-ZRX/HARNESS.md`

Ruta verificada (`deepseek-flash` = «DeepSeek-V41-Flash», esfuerzo `high`, sandbox de escritura
solo en `cwd`). **Bloqueo B-HARNESS-01:** `MISSING_CREDENTIAL`. No se investigan credenciales; se
comunicó a Katana en la conversación.

### Decisiones tomadas y por qué

| Decisión | Dónde | Motivo corto | Revisión |
|---|---|---|---|
| D-T01 PoW lineal por mayor trabajo | `P-ZRX/P-TRANSICION/CONTRATO-v0.md` §0 | Fase temporal; análisis conocido; verificador existente | IPA A-10 |
| D-T02 Un solo génesis, una historia | ídem | Evita traspaso por checkpoint y la circularidad C3 antigua | — |
| D-T03 Selección FC-3 (umbral PoW + peso PoST) | ídem | Tras el corte, el hash no debe dar poder; antes, protege la distribución. FC-1 permitiría borrar la historia PoST con hash; FC-4 añade confianza | IPA A-05 |
| D-T04 Corte condicionado CUT-HWΦ | ídem | `C-BOT-05/06`: garantía madura obligatoria y fallo de activación definido | IPA A-08 |
| D-T05 Parcelas independientes del terminal (segmento génesis rellenado) | ídem | Autonomys `archiver.rs:524-541`; resuelve PLAN §4.4 | Encargos 04/05 |
| D-T06 El stake no entra en peso ni oportunidad | ídem | `AUTO-ZRX.md` §4 | — |
| D-T07 Sectores tras interfaz (`SEC-0`/`SEC-A`) | ídem | Encargos de sectores sin cerrar | D-01…D-05 |
| D-T08 Coinbase PoST como crédito pendiente → activo | ídem | Lectura de `C-BON-03` | C-02/C-07 |
| Madurez evaluada en el slot/altura de `B` | ídem, TRN-07 | Determinista desde la cabecera | Regla de retención |
| Ejecución de DeepSeek: zona = `cwd` de la sesión | `ORDEN-L01`, `ORDEN-T01` | El sandbox solo deja escribir ahí: protege órdenes y entradas | — |
| Línea base desde `git archive 9681061`, clon de Autonomys clonado a la zona | `ORDEN-L01` | Procedencia verificable; reproduce el diseño de rutas original sin enlaces simbólicos | — |

### Productos de la sesión

- `R-ZRX/HARNESS.md`, `R-ZRX/MAPA-RESCATE.md`, `R-ZRX/LEGADO/` (3 copias con huellas).
- `D-ZRX/RFT-ZRX.md` (RFT-01…12), `D-ZRX/IPA-ZRX.md` (familias A–E, X).
- `P-ZRX/P-TRANSICION/CONTRATO-v0.md`, `ORDEN-T01.md`, `ENTRADA-T01.sha256`.
- `P-ZRX/P-LINEA-BASE/ORDEN-L01.md`, `ENTRADA.sha256`.

### Investigación sin ejecución (hasta 00:58)

- `P-ZRX/P-POW/NOTA-A12-ALGORITMO.md`: fuentes sobre el algoritmo PoW (ECIP-1049, RandomX). No
  pude verificar el catálogo de NiceHash (página generada por JavaScript): queda como indicio.
- `P-ZRX/P-TRANSICION/NOTA-A07-SEMILLA.md`: derivación del sesgo del minero del terminal; candidato
  S3 (semilla retardada por PoT) con la desigualdad (A07-1). Sin instrumento.

### Pendiente inmediato

1. Resolver B-HARNESS-01 (Katana) y lanzar L01 y T01 (pueden correr a la vez: zonas y recursos
   disjuntos; L01 usa 16 hilos, T01 uno).
2. Revisar sus entregas según `AUTO-ZRX.md` §5.5.

### Ejecución (desde 01:03)

- 01:03 Katana: «deepseek ya funciona»; autoriza agentes propios en paralelo, **sin Fable ni
  Opus**. Luego: Sonnet también puede escribir y ejecutar código; DeepSeek preferido por coste,
  Sonnet para encargos que necesiten un plus. Nota: el esfuerzo de un subagente no se fija desde la
  llamada.
- 01:03:27 prueba de ruta DeepSeek OK (`R-ZRX/HARNESS.md`, B-HARNESS-01 resuelto).
- 01:03:56 lanzadas **L01** (`deepseek/L01`) y **T01** (`P-ZRX/P-TRANSICION/T01`), DeepSeek.
  Motivo del ejecutor: ambas son ejecución acotada y bien especificada; no requieren el plus.
- Lanzados dos subagentes **Sonnet** de investigación de fuentes (sin código): fuentes primarias de
  Filecoin (`P-ZRX/P-REGISTRO-SECTORES/investigacion/fuentes-filecoin/`) y coste de hash para A-10
  (`P-ZRX/P-POW/fuentes-coste/`).

### Autorizaciones de Katana (≈01:10, antes de ausentarse)

Respuesta literal a las cuatro preguntas: **commits locales, cómputo pesado, workspace nuevo y
borrar zonas** autorizados («tienes autonomía y libertad total, tu objetivo es el ya mencionado»);
decisiones provisionales: **decide tú con evidencia**; PoW de la red dev de 0.0.1: **SHA3-256 tras
interfaz** (parámetro de desarrollo, no decisión de producción); alcance: **hasta 0.0.1 medible**.
Nunca push.

### L01 — revisión (01:09–01:11)

- Entrega en 5 min (01:03:56 → 01:09:22). Verificado por el director: logs crudos coinciden con
  `RESULTADOS.tsv`; integridad del checkout (`diff` vacío) y clon en `f8842d0` sin cambios,
  **repetidos por el director**; `ENTRADA.sha256` OK.
- **REPRODUCIDO:** `zx-core` 156/156 (incluye 4 tests CAVP NIST y oráculo Julia de cabecera DAG),
  `zx-pot` 5/5 (32 vectores), `zx-storage` 36/36 sin `rocksdb`, `farmer_disco` 13/13 (plotter y
  auditor PoAS reales).
- **FALLA por error de la orden (del director):** `zx-consensus` no compila un test que incluye
  `SPEC.md`, que la orden no extraía. Corrección L01-C1 lanzada (añade `SPEC.md` y S3b con
  `rocksdb`, que la orden daba por cubierto sin estarlo).
- Desviación menor del ejecutor: comprobó `ENTRADA` al final antes de terminar S5; se le pide
  hacerla la última en C1.

### T02 lanzada (01:11)

Modelo adversarial FC-1/FC-2/FC-3 (DeepSeek, 4 hilos). Entrada congelada sin `RFT-ZRX.md` ni la
nota A-07 para poder actualizarlas durante la ejecución.

### 01:12–01:23

- Revisados los informes Sonnet de fuentes (Filecoin; coste PoW) con citas comprobadas por el
  director; una corrección al de Filecoin (motivo del bloque finalizado). `REVISION.md` en cada uno.
- **L01-C1**: `zx-consensus` 421/0/4 y `zx-storage`+`rocksdb` 60/0/0 → **línea base REPRODUCIDA**
  (`P-ZRX/P-LINEA-BASE/REVISION.md`).
- **T02** se detuvo con cuatro ambigüedades reales (la más seria: sin retarget, FC-1 ≡ FC-3 en E3);
  corrección **T02-A** lanzada 01:16.
- **W01** superada y **migrada a la raíz** (workspace con `zx-core` y `zx-pot`); commit local
  `29b6bd6` (solo archivos propios y revisados, sin borrados ni documentos de Katana).
- Diseño **FORMATO-v0** (`P-ZRX/P-FORMATO/`): v1 intacta; v2 garantía, v3 coinbase PoST, v4
  evidencia inactiva; campos de altura inactivos; `Red::Dev`. **W02** lanzada 01:23.
- Nota de proceso: por dos veces lancé `python3 -c 1`/`--version` como sonda inútil; no ejecuta
  código de auditoría, pero sobra: no se repetirá.

### 01:35–02:08

- **S01** (sectores, encargo 01): G1 superada en su alcance; volcados binarios no versionados
  (regenerables, con hash). Commit `b2a7f04`.
- **T02-A** revisada: refuta la pregunta mal planteada; FC-3 se mantiene; RFT-13 y A-05b. `49e4434`.
- **W02** y **W04** migradas (`f827b3c`, `492ac18`); W04 añade `zx-consensus` nuevo (PoW dev).
- Mapa de adaptación del DAG/PoT/PoAS antiguo (subagente Sonnet, afirmaciones clave comprobadas) →
  decisiones D-P07…D-P13 (`P-ZRX/P-DAG/DECISIONES-W05.md`). W05a lanzada 01:56.
- Clon de Autonomys preparado en `PDF/autonomys-subspace` (`f8842d0`, desde la copia local);
  `PDF/README.md` y `repositorio.txt` restaurados de `HEAD`.
- **T01 SUPERADO** (29,5 M historias, 0 fallos). Contrato v0.1 con R-1…R-15 (R-6 sustituye la
  lectura de la coinbase en cualquier posición). T01-B lanzada 02:08.
- **S02a** (medición de regeneración) retenida hasta que la máquina esté libre: es una medida de
  tiempo y no debe correr con compilaciones concurrentes.

### 02:57 — Error de diseño del director en FORMATO-v0 (encontrado por el diferencial de W03)

La coinbase PoW perdió su `txid` único al desactivar `expiry_height` (F-10), y los retiros y
liberaciones de garantía sin entradas eran **repetibles por cualquiera** (ataque de repetición: forzar
el retiro de la garantía de otra clave). Los oráculos no podían verlo porque abstraen la identidad de
las transacciones; lo destapó el diferencial con transacciones reales. Corrección v0.1: nonce por
clave (F-15), altura en la coinbase PoW (F-16), slot en la coinbase PoST (F-17), salida `(txid, 0)` de
la liberación (F-18). Alternativa descartada: exigir una entrada UTXO en retiros y liberaciones, porque
bloquearía para siempre a un productor cuyas recompensas son garantía (D-T08) y no tiene UTXO.

### 03:00–03:50

- **T01-D** superada: nonce por clave en el oráculo de transición, vectores v0.1 (5 994 casos,
  0 discrepancias). `7c24b98`.
- **W03-R** (rebase del motor de transición) y **W05b2-R** (rebase de `zx-post`) migradas a la raíz
  con `MIGRACION.sha256` verificado y 0 borrados (`5453407`, `83e71a1`). La raíz produce y verifica un
  bloque PoST real hijo de un terminal dev (620 tests).
- **W02b** (FORMATO v0.1 en `zx-core`, motor y productor) lanzada 03:38 con entrada congelada `3ce3112`.
- **T04-B revisada: cumple la letra, regresión de cobertura.** El generador aleatorio del oráculo DAG
  construye los depósitos PoST con `nonce = 0`: casi todos se descartan con `ErrNonce` (737 de 969
  descartes; `run.jl` pasa de 1 977 a 3 721 descartes con los mismos bloques). Además, **error mío
  anterior**: el generador de T04 nunca produjo retiros ni liberaciones y `REVISION-T04` no lo vio; y
  `ORDEN-T04-B` no exigió nonces correctos en el generador ni un criterio de cobertura. Orden
  **T04-C** lanzada (nonce correcto, retiros y liberaciones, D-12/D-13, mínimos de cobertura, vectores
  v0.2); W06a pasa a depender de v0.2 y a comparar su tabla de cobertura con la del oráculo.
- Regla de método nueva para toda orden con generadores: tabla de cobertura por tipo de operación
  (construidas, aplicadas, descartadas por motivo) con mínimos exigidos.
- Proceso: volví a lanzar una sonda `python3 --version` sin necesidad (sin código, sin salida). Tercera
  vez; queda anotado.

### 03:50–04:05

- **T04-C superada** (`9da8c70`): generador con nonce correcto, retiros y liberaciones; vectores v0.2
  con tabla de cobertura (mínimos cumplidos). W06a usará v0.2 y comparará su cobertura.
- **Revisión independiente RI-1** (Sonnet, `P-ZRX/P-REVISION-CODIGO/`): RI-1b sin críticos, coste de
  admisión GHOSTDAG no acotado confirmado (IPA B-12); **RI-1a encontró un defecto crítico** que mi
  revisión de W03 no vio: `fusion_post` no actualiza `slot` ni `peso_sufijo`, y `fusion_pow` no exige
  progresión de altura. Ambos pasan a correcciones obligatorias de W06a.
- **A10-M1**: CPU medida con carga ajena (1 hilo 4,85 MH/s; 32 hilos 68,5 MH/s, provisional); GPU sin
  medir por incompatibilidad `nvcc` 12.9 / gcc 15. Segunda ronda por NVRTC + API del driver con
  anfitrión en C (`CORRECCION-A10-M1-A`).
- Órdenes nuevas: W05b3 (productor PoST en régimen: `producir` solo hacía el primer bloque), W06b
  (almacén, D-N03′), escenarios de medición W07.

### 04:05–05:10

- **A10-M1** (Sonnet, 2 rondas): GPU medida por NVRTC + API del driver (anfitrión en C; `nvcc` 12.9
  no acepta gcc 15). Validación completa (136 CAVP, 10⁶ digests idénticos, mismo nonce). GTX 1070:
  561 MH/s sostenidos, 109 W, 1,94·10⁻⁷ J/hash; **8,2×** la CPU de 32 hilos (con carga ajena): refuta
  «≥ 10×». IPA A-10 parcial.
- **W02b migrada** (`ccf4b6d`): FORMATO v0.1 en formato, motor y productor; diferencial con 0
  discrepancias en 2 055 casos y **3 939 negativos, que W03 nunca había consumido** (tercer caso de
  verificación aceptada sin mirar qué recorre; queda en `REVISION-W02b`).
- **W05b3 migrada** (`2092e0b`): productor PoST en régimen y `ServicioPot`; con `N_dev` real, 1,43 s
  por bloque producido y 0,066 s por verificación.
- **W06a migrada con reserva** (`0313682`): `zx-cadena` + correcciones RI-1a. El diferencial contra
  T04 (913/913) **emula** colisiones de ids que solo existen en el modelo abstracto del oráculo
  (salida de la liberación por contador). Causa de modelado: se corrige en los oráculos
  (T01E-T04D, en curso) y el arnés se rehace sin emulación (W06a-B, preparada).
- **W06b** superada tras mi **Corrección A** (la integridad solo miraba la cabecera: error de mi orden);
  rebase W06b-R en curso. Límite: testigos PoW no comprometidos → prueba obligatoria en W06d1.
- `SPEC-0.0.1.md` en borrador: índice de lo implementado y validado, con estado por regla.

### 05:10–05:30

- **T01-E superado** (`b924ad0`): el oráculo T01 identifica la salida de la liberación por su contenido
  (como F-18). Revela que el artefacto de ids ya afectaba a T01: 1 434 de 2 055 casos base cambian
  (transferencias que se descartaban al construir la historia). **Error de lanzamiento mío** en la
  parte T04-D (lanzada desde `P-TRANSICION`, sin escritura en `P-DAG`); relanzada desde su zona.
- **W06b migrada** (rebase W06b-R, `83d03ee`): la suite completa de la raíz con W05b3 + W06a + W06b da
  680 pasan, 0 fallan.
- **Decisión:** `HEAD` no era reproducible (34 tests antiguos en `crates/` solo borrados en la copia de
  trabajo). Registro en git los 98 borrados de archivos de `9681061` bajo `crates/`, `ci/` y `.github/`
  que ningún commit posterior tocó (`cb77c55`). El resto del árbol antiguo (documentos) no se toca.
- **W06d1** (nodo sin red, Sonnet) lanzada con entrada congelada.

### 05:30–05:46 — incidente en W06d1

- **T04-D superado** (`007e106`): vectores DAG v0.3; el artefacto de ids cuantificado (16 descartes en
  v0.2 → 0). **W06a-B** lanzada (arneses sin emulación).
- **W06d1, primer intento, detenido.** El ejecutor Sonnet informó de «otro proceso `claude`» (la
  sesión `zerox-3b`, PID 39717) escribiendo en su zona. **Falso en la atribución:** la transcripción de
  esa sesión no cambia desde las 05:12, antes de que existiera la zona. El segundo escritor era un
  **fork que el propio ejecutor lanzó** («Investigar API de zx-cadena y zx-storage»), que heredó su
  contexto y escribió `PROGRESO.md` y `zx-node/Cargo.toml`. Lo detuve (`TaskStop`). El ejecutor
  además leyó mal el alcance de LINEO (lo creyó solo Julia/C++; `AUTO-ZRX.md` §52 lo extiende a todo el
  código). Zona archivada como `deepseek/W06d1-intento1/`; orden ampliada («Relanzamiento»: un solo
  escritor, sin forks; padre seleccionado real con GHOSTDAG; sin doble firma tras reiniciar) y
  relanzada con un ejecutor nuevo.
- Lección: en las órdenes a subagentes, prohibir expresamente lanzar subagentes o forks.
- Nota de exactitud: la sección «Relanzamiento» de `ORDEN-W06d1.md` dice «05:50»; se escribió a las 05:45 (no se corrige el archivo porque está congelado con la orden en curso). Desde ahora las horas se toman de `date` al escribir.

### 08:30 — programa P-DISUASION (petición de Katana)

- Katana pide determinar qué resuelven PoStake y Filecoin en ZEROX y si encarecen o disuaden a un
  atacante X; criterio: un mecanismo que no cierra un hueco pero encarece el ataque es una mejora real
  frente al protocolo antiguo sin stake. Marco común (`P-ZRX/P-DISUASION/MARCO.md`: 12 ataques, 16
  mecanismos, 7 dimensiones de coste, veredicto I/E-exigible/E-condicionado/N/W) y cuatro encargos:
  DS-1 fuentes (Sonnet, web) y DS-4 GPU del sembrador por Vulkan (Sonnet) lanzados; DS-2 matriz y
  DS-3 modelo cuantitativo preparados. W06d1 sigue en curso.

### 08:30–09:51

- **P-DISUASION** (petición de Katana): DS-1 (fuentes), DS-2 (matriz), DS-3 (modelo en Julia), DS-4 (GPU
  del sembrador por Vulkan), DS-5 (castigo correlacionado) y DS-6 (reparto del espacio entre claves)
  hechos y revisados; síntesis en `P-ZRX/P-DISUASION/SINTESIS.md`. Verificado por el director en las
  fuentes: la imposibilidad de Baig y Pietrzak (FC 2025) y sus dos salidas (VDF como Chia; BFT + registro
  como Filecoin); las cifras del sembrador de P-COBERTURA. **Dos errores cazados en revisión:** la región
  de retención «≳ 4.000» (era 370; la incoherencia venía de P-PRESTAMO y la ratifiqué sin rehacer la
  cuenta) y la convención del exponente de Pareto en DS-6 (cola frente a densidad; corregido, la
  conclusión se sostiene con margen menor y el cálculo empírico la confirma).
- **W06d1 migrada** (`60498ea`): el nodo sin red cruza el corte, produce en régimen y sobrevive a
  `SIGKILL`. El agente dejó de informar a las 08:14 esperando su suite; el parche estaba desfasado
  respecto a su último cambio y se regeneró. Migración por parche (su `ws/` contenía los documentos).
- **W06a-C** lanzada: máximo de padres parametrizable e identidad GHOSTDAG real en `zx-cadena`.

### 09:51–14:10

- **W06a-C migrada** (`4042821`): `zx-cadena` acepta hasta 15 padres e identidad GHOSTDAG real. La primera
  ejecución conjunta de la raíz destapó que la prueba de reinicio del nodo es intermitente.
- **RI-2** (revisión independiente, Sonnet): RI-2a, `zx-cadena` guardaba para siempre el error «falta el
  padre» (alta, confirmado); RI-2b, el nodo admitía sus bloques PoST antes de persistirlos (alta, plausible;
  doble firma tras reinicio con red). Ambas corregidas dentro de W06d2 por avisos del director.
- **W06d2 migrada, parcial** (`2b6a467`): validación diferida, huérfanos, sincronización PoW, herramienta
  adversarial; 715 tests. **Dos errores del director**: el formato de red de W06c no llevaba la
  justificación PoT de los bloques PoST (sin ella no se pueden verificar por red) y la revisión de W06d1 no
  vio que el nodo no sigue bifurcaciones PoW. **W06d3** (Sonnet) lanzada para cerrarlos y demostrar tres
  nodos de extremo a extremo.
- Error menor: congelé la entrada de W06d3 antes de editar el plan; recongelada antes de lanzar.

### 14:10–22:10 — cierre de la sesión

- Castigo: SL-1 (contrato, ratificado con RAT-1…RAT-4 y RAT-2′), SL-2/SL-2b (calibración), SL-3/SL-3b
  (oráculos), **SL-4a migrada** (evidencia y castigo en Rust, 0 discrepancias). Decisiones de Katana:
  2/8 al incluidor, identidad con `consensus_branch_id`.
- Finalidad por votos: FV-1 (dos ejecuciones) y AV-1 revisados; Katana adopta la capa en principio y fija
  `b = 2`, multa proporcional con mínimo y sin premio por votar.
- Red: W06d2, W06d3, **W06d4 migrada** (tres nodos reales cruzan el corte); W06d5 en curso.
- Revisión independiente RI-2 (a y b) con correcciones integradas.
- **Traspaso para la próxima sesión: `R-ZRX/TRASPASO-2026-09-26.md`.**

### 22:15–22:26 — documentación al día (petición de Katana)

- Katana pide revisar que SPEC, P, V, R, S, RFT e IPA no queden desactualizados. Hecho: `RFT-ZRX` (RFT-14…RFT-23,
  notas en RFT-01 y RFT-04), `IPA-ZRX` (estado, camino crítico y 22 filas), `SPEC-0.0.1` (nodo W06a…W06d5,
  evidencia y castigo, finalidad como propuesta), `V-ZRX/REGISTRO.md` nuevo (registro, no copia: mover rompería
  las entradas congeladas), `S-ZRX/` (índice y síntesis de seguridad del híbrido), `MAPA-RESCATE` y el
  traspaso con la sección «Katana ausente». Hallazgo al hacerlo: el código de W06d2…W06d5 y SL-4a no ha tenido
  revisor independiente (IPA E-11 → RI-3).
- W06d5: suite conjunta (intento 4) en marcha, 461 tests pasados y 0 fallos a las 22:22.

### 22:46–23:01 — sesión nueva (AUTO-ZRX relanzado; Katana ausente)

- Arranque desde `R-ZRX/TRASPASO-2026-09-26.md`. W06d5 sigue en la otra sesión (procesos `zx-node` vivos en
  `deepseek/W06d5/`): no se toca; no se migra nada a `crates/` hasta su commit de revisión.
- **RI-3** (`P-REVISION-CODIGO/ORDEN-RI-3.md`, entrada congelada): RI-3a (red: `zx-p2p`, `zx-node/src/red/`) y
  RI-3b (castigo de SL-4a) lanzadas con Sonnet; RI-3c (lógica del nodo) espera a W06d5.
- **SL-4b partido en dos.** SL-4b1 (DeepSeek, lanzada 22:54): portar el firmante seguro de `9681061` a
  **`zx-post/src/firmante/`** (decisión: es política local de producción, FIR-15; en el árbol nuevo
  `zx-consensus` es validación) con identidad RAT-1 (lleva `consensus_branch_id`, esquema v2), sin `alta.rs`
  (claves dev deterministas), y variantes **aditivas** `_con_firmante` de los productores para no chocar con
  W06d5. SL-4b2 (Sonnet, redactada, sin congelar): activación en el perfil dev (`Plazo_slots = 300`,
  `M_margen_slots = 60`, **`R_SLOTS` 60 → 600** por SL-2b), detector de doble firma que solo indexa cabeceras
  con puerta conjunta superada (evita llenar memoria con sellos sobre cabeceras inventadas), envío por
  inclusión propia (no hay relevo de tx), `zx-adversario doble-firma` (re-sella con la clave dev 0 cambiando
  solo `timestamp`) y prueba de extremo a extremo. Se revierte si RI-3 o SL-4b1 lo desaconsejan.
- **W07 partido en tres.** Esquema de registro v1 (`P-MEDICION/ESQUEMA-REGISTRO-v1.md`, contrato común): el
  nodo actual no registra slot, bytes, par ni tiempos por etapa. W07a (instrumentación, DeepSeek; redactada,
  tras W06d5), W07b (ejecuciones E-1…E-9, Sonnet; por redactar tras leer W06d5) y **W07c** (analizador Julia
  de los registros, DeepSeek, lanzada 22:58 con los registros v0 de W06d4 como datos reales).
- `D-ZRX/PREGUNTAS-KATANA.md` abierto: PK-01 (fuente de peso provisional de la capa de votos; recomendación:
  garantía como peso **solo en la red dev**, tras interfaz, con sectores cuando exista el registro) y PK-02
  (asegurar los 95 archivos que solo están en `.trash`; recomendación: copiarlos a `R-ZRX/LEGADO/`).
- **Incidente de carga (22:57):** carga 65 en 32 hilos con mis cuatro trabajos y los cuatro `zx-node` de
  W06d5 (≈ 5 núcleos cada uno). Para no falsear sus pruebas de reloj, bajé a `nice 19` los 69 procesos de mis
  trabajos (sin pararlos). Lección: con W06d5 vivo, lanzar como mucho dos compilaciones a la vez.

### 23:06–23:18 — RI-3a, RI-3b y W07c revisadas

- **RI-3a aceptada:** tres hallazgos altos de disponibilidad confirmados (petición con hashes repetidos que
  clona 157 MB; reserva de 32 MiB antes de leer un byte; cola sin tope hacia el hilo de consenso). Se corrigen
  en la **parte A de W07a** (mismos archivos que la instrumentación de red).
- **RI-3b aceptada:** `cbid` ajeno y orden no canónico de la `EvidenceTx` son **forma** según el contrato y el
  motor y los oráculos los tratan como semánticos (bloque aceptado con la transacción descartada). **Error del
  director:** la revisión de SL-3b no vio que los oráculos se desviaban del contrato. **Decisión:** corregir
  código y oráculos al contrato (no enmendarlo): son comprobaciones sin contexto y el orden canónico hace única
  la codificación; coste para el honesto, ninguno. **SL-4c-O** (oráculos T01/T04, dos sesiones DeepSeek de un
  hilo) lanzada 23:11; **SL-4c** (Rust, y decodificación de red de la v4, la brecha FD-5 que habría bloqueado
  SL-4b2) redactada.
- **W07c superada** y migrada a `P-ZRX/P-MEDICION/analisis-registro-v1/`; recuento de pares comprobado a mano
  (1 223, exacto). Dos errores míos que destapa: llamé «V4» a registros de V6/V7, y comparar el estado final
  exige un reposo → parámetro `--dejar-de-producir-en-slot` añadido a W07a.

### 23:10–23:52 — oráculos alineados con el contrato de evidencia (SL-4c-O, -B, -C)

- Tres rondas cortas de DeepSeek (dos sesiones de un hilo cada una): en T01 y T04, **entradas/salidas, `cbid`
  ajeno y orden no canónico** de la `EvidenceTx` son errores de **forma** que invalidan el bloque (EV-04,
  RAT-1, contrato de estado DAG), con precedencia por transacción. Vectores T01 v0.5 (3 179) y T04 v0.6
  (2 108), 0 cambios sin defecto. Dos rondas extra por errores míos al redactar (alcance de la precedencia sin
  fijar; «estructura vigente» intocable que dejaba EV-04 a medias). Límite: los oráculos no modelan testigos.
- **SL-4c** (Rust: forma, motor, arneses y decodificación de red de la v4) congelada y lanzada 23:51.
- 23:54 **SL-4c, primer lanzamiento:** el ejecutor informó dos faltas de definición antes de editar (bien); una
  venía de haber leído la zona de **otra orden** (`deepseek/SL4b1/ws`) como si fuera su base. Aclaración escrita
  (`ACLARACION-SL4c.md`: base = raíz; `cbid` local = `ParametrosEvidencia::cbid`) y relanzada 23:55.
  **Lección:** toda orden dice «tu base es la raíz en el commit de la entrada; no leas otras zonas de
  `deepseek/`». La compatibilidad entre SL-4b1 (test nuevo que llama a `validar_forma_tx_v4`) y SL-4c se
  resuelve en la migración.

### 00:38–00:45 — W06d5 migrada (parcial) por la otra sesión; reorganización

- `e2eee98`: W06d5 **parcial**. V4 y V6(a) superados; **V5 (nodo tardío) y V6(b) (partición PoST) no**: el nodo
  resuelve huérfanos PoST de uno en uno y la producción lo adelanta. Es un hueco de 0.0.1 («sincronizar»).
- **SL-4b1 migrada** (`de26376`, 10 rutas en `zx-post`, 10/10 huellas).
- **RI-3c** lanzada (Sonnet) sobre `de26376`.
- **W06d6 redactada** (Sonnet): sincronización por **páginas del registro de admisión** con cursor por par (el
  orden de admisión es topológico y solo crece: servirlo cuesta O(1); ordenar por slot no basta porque la regla
  es `slot(p) ≤ slot(B)`, no estricta), dial con reintento, V7, correcciones de RI-3a (se mueven aquí desde
  W07a: mismos archivos), tests pendientes de W06d5 y el parámetro de reposo. W07a queda solo como
  instrumentación, tras W06d6.

### 00:57–01:00 — RI-3c y W06d6

- **RI-3c** (crítico, confirmado): el nodo persistía antes de admitir y no deshacía la escritura si la admisión
  rechazaba el bloque: un bloque verificable pero inadmisible dejaba al nodo **sin poder reiniciar**. Lo
  introdujo la corrección de RI-2b que dirigí yo (objetivo correcto, forma equivocada: lo peligroso era
  difundir antes de persistir). Decisión: admitir → persistir → difundir.
- **W06d6 congelada y lanzada** (Sonnet, `394cb6e`): paso previo RI-3c, sincronización por registro de
  admisión, dial con reintento, V7, RI-3a, tests pendientes de W06d5 y parámetro de reposo.

### 02:13–03:50 — SL-4c migrada; hallazgo FC-3 en el nodo

- **SL-4c-R superada y SL-4c migrada** (`ec9c6b9`): primera suite conjunta W06d5 + SL-4b1 + SL-4c, 797/0/5;
  diferenciales T01 v0.5 y T04 v0.6 con 0 discrepancias. V-ZRX registra los vectores vigentes.
- **W06d6** (informe provisional, suite final en curso): nodo tardío **superado** (dos repeticiones, misma punta y
  mismo `resumen_estado` tras el reposo); `zx-adversario` **superado**; la «partición PoST» se hizo aislando A
  **desde el génesis** (otro escenario: E-6b) y destapó que **`zx-cadena` congela el terminal al primer bloque
  PoST** y guarda un solo DAG: no es FC-3 (TRN-09, D-T03) y rompe I-3; dos terminales con sufijo PoST no
  convergen nunca. **Error del director:** `SPEC-0.0.1` presentaba TRN-09 como validada con procesos reales
  (W06d3 solo probó la bifurcación **antes** del primer PoST); corregido. **W06d7 redactada** (varios DAG, uno por
  terminal; selección por `blue_work` con el desempate del motor; `C-FIN-01`; V6(b) de verdad). Límite
  declarado de antemano: sin oráculo del caso multiterminal en DAG (T04-E al IPA).

### 04:43–04:58 — W06d6 migrada (parcial); W06d7 y W07a lanzadas

- **W06d6 migrada** (`b9210ec`, 28 archivos copiados tras comprobar base y alcance; su `ws.orig` llevaba los tests
  de reproducción y el parche no aplicaba). Nodo tardío **superado** (cierra V5 de W06d5); RI-3a y RI-3c
  corregidos con pruebas antes/después; adversario superado; 814/0/5. Incumplimiento declarado por el ejecutor:
  `python3` para tres sustituciones de texto. `Cargo.lock` añade `tracing-subscriber` (lo pedí yo: contradicción
  en mi orden).
- **W06d7** (Sonnet, `39519aa`) y **W07a** (DeepSeek, `cf9cd2a`) lanzadas en paralelo: instrucción a W07a de hacer
  cambios aditivos y aislados para que el rebase sea mecánico; SL-4b2 espera a ambas (dos redes de procesos reales
  a la vez falsearían las pruebas de reloj). Lección: a los ejecutores, «no modifiques `ws.orig/`».

### 06:37–06:57 — W07a revisada, W06d7 migrada, W07a-R lanzada

- **W07a** superada con corrección pendiente: retiró seis eventos de diagnóstico sin que se pidiera (se
  restauran; esquema §1 bis) y no repitió la suite completa tras su última corrección. El criterio «registro
  < 1 % de la admisión» estaba mal elegido (denominador sin la verificación PoT/PoAS): 0,007 % del coste real.
- **W06d7 migrada** (`c8286d3`): FC-3 real en el nodo; I-3 por propiedades; E-6b y V6(b) con procesos reales
  superados; 829/0/5. Límite: el productor no cambia de terminal en caliente → paso 0 de SL-4b2.
- **W07a-R** (rebase de la instrumentación sobre W06d7, eventos restaurados, suite completa) lanzada 06:56.
- Lección repetida: tomar la hora de `date` antes de escribirla (dos correcciones esta noche).

### 07:05–07:58 — decisiones de Katana; W07a migrada; SL-4b2 lanzada

- Katana respondió: **PK-02 sí** (90 archivos por contenido copiados a `R-ZRX/LEGADO/solo-trash/`, `f2fb5b0`;
  mi primer recuento falló por rutas relativas con `git -C`, detectado y repetido) y **PK-01 opción 2**
  (FV-D08: garantía como peso de voto solo en dev, tras una interfaz por sector; tras 0.0.1). Sin preguntas
  pendientes.
- **W07a migrada** vía W07a-R (`10516d6`): suite completa 832/0/5.
- **SL-4b2** congelada (`bb648fb`) y lanzada (Sonnet): paso 0 (productor sigue al terminal seleccionado), firmante
  seguro en el nodo, detector y envío de evidencia, activación dev, doble firma de extremo a extremo.

### 07:58–09:52 — SL-4b2 migrada; SL-4b3 lanzada

- **SL-4b2 migrada** (`fbab3b7`): el castigo está **activo en la red dev**. Doble firma real (tercero con la clave
  dev 0) detectada, incluida y castigada en los tres nodos 3/3; productor honesto con 10 `SIGKILL` sin ninguna
  evidencia; pérdida del registro con abstención exacta (borde inclusivo); el productor sigue al terminal ganador
  en caliente (paso 0). **Defectos:** el bloque de transición se produce **sin** firmante (contra la decisión 2) y
  faltan los unitarios de inclusión → **SL-4b3** (DeepSeek) lanzada ≈ 09:49, con un guardián de CI nuevo que
  impide que el nodo llame a productores sin firmante. Reserva: registros crudos de la prueba del paso 0 borrados
  por el ejecutor; W07b la repite.

### 10:43–10:50 — SL-4b3 migrada; W07b lanzada

- **SL-4b3 migrada** (`de7ae26`): transición con firmante, guardián `ci/firmante-obligatorio.sh`, tests de inclusión.
- **Commit candidato de 0.0.1: `27dcfeb`.** **W07b** (Sonnet) congelada y lanzada: E-0 desde un clon limpio y E-1…E-9
  con procesos reales, `N_dev` real, tres repeticiones. Mientras mide, nada pesado en la máquina.
- 10:5x **Hallazgo al poner al día `SPEC-0.0.1`:** la retención de recompensas (`ρ_ret`, `T_v`), de la que depende la
  disuasión calculada en SL-2/SL-2b, **no está implementada**; `SPEC-0.0.1` la daba como parámetro de 0.0.1 junto con
  `q = 20` (el nodo usa `q = 10`). Corregido; en 0.0.1 el castigo confisca solo la garantía y **no se reivindica
  disuasión**. IPA C-12 nuevo. Es la segunda afirmación excesiva mía en `SPEC-0.0.1` (la primera, TRN-09).
- 11:03 **W07b**, primera parada de turno dentro de E-0 (fmt, clippy y build en verde; tests en marcha sin fallos). El
  ejecutor había leído el hallazgo de W06d6 como vigente y preparado E-6b esquivando el cambio de terminal; se le
  corrigió por mensaje (está resuelto en `27dcfeb`: W06d7 + paso 0 de SL-4b2) y se le reanudó.
- 11:1x Mensaje de la sesión **zerox-e7** (con el visto bueno de Katana) sobre C-12, **verificado en el código**: la
  retención del modelo nunca se escribió como regla (SL-1 no la pidió; SL-4a la puso como parámetro sin regla), pero
  D-T08 acredita la coinbase PoST entera a la garantía y EV-17 + RAT-3 la dejan confiscable hasta retirarla y
  liberarla. C-12, `SPEC-0.0.1` e informe matizados; análisis **SL-2c** (Julia) programado para después de W07b.
  `PERFIL-DEV-v0.md` estaba desactualizado (`R_slots = 60`): corregido.
- 12:2x **Hallazgo de W07b E-2a** (verificado por el director en los registros): el arnés daba tres claves a cada nodo; B
  minó 26 de ≈ 31 bloques PoW y cumplió `K_min = 3` solo; A y C llegaron al corte sin garantía y no produjeron nunca.
  Límite real del producto: **sin relevo de transacciones, quien no tiene garantía al corte queda excluido para
  siempre** (IPA A-14, informe). Arnés corregido a una clave por nodo (como el perfil dev y W06d4…SL-4b2).
- 12:3x **Panic real del nodo** (W07b E-2a, intento 4; verificado en el código): el protocolo productor↔bucle pierde el
  paso cuando un cambio de terminal interrumpe la espera (lo introdujo el paso 0 de SL-4b2) y una respuesta `Padres`
  atrasada provoca `panic!`. **W06d8** (DeepSeek): peticiones numeradas, ningún pánico alcanzable, fallo del
  productor = parada ordenada. W07b termina la calibración y espera el nuevo candidato para R1…R4 (repite E-0).

### 12:35–14:40 — W06d8 migrada; calibración de `SR_dev`; nuevo candidato

- **W06d8 migrada** (`26312ff`): protocolo productor↔bucle numerado, sin pánicos alcanzables en el productor, parada
  ordenada; 5/5 repeticiones reales sin pánico y dos respuestas atrasadas descartadas de verdad en una partición;
  860/0/6. **Nuevo candidato de 0.0.1: `26312ff`** (sustituye a `27dcfeb`).
- **Calibración E-2a** (W07b, `27dcfeb`, una clave por nodo): τ = 1,2816 s por slot; bloques por slot 0,23 (2^60),
  0,65 (2^62), 0,78 (2^63), **0,99 (2^63,5) → `SR_dev = 13 043 817 825 332 783 104`**. La curva no escala linealmente
  con el rango (dato para el informe). Mi estimación para 2^63 (≈ 1,3) era errónea.
- W07b retomada: repite E-0 sobre `26312ff` y sigue con R1…R4.

### 15:20–16:45 — R1 rep1 y rep2; analizador corregido; método de E-3

- **R1 rep1** (candidato `26312ff`): E-1, E-2 (0 rechazos, ≈ 0,95 bloques distintos por slot), E-4 (reinicio y puesta
  al día ≈ 118 s) y E-3 (misma punta y estado) superados.
- **W07c-B** (analizador): contaba cada bloque una vez por nodo; corregido (`6a7292c`). Error mío en el esquema.
- **R1 rep2: DIVERGEN en E-3** (misma punta, `resumen_estado` distinto en C). Diagnóstico leyendo los registros: el
  resumen solo se escribe en `cambio_punta` y los bloques laterales llegados después no lo actualizan (A y B
  registraron antes de los últimos bloques, C después); los bloques que parecían faltar son los de **transición**, que
  el registro no marca como producidos. **Nuevo método de E-3** (sin tocar el nodo): tras el reposo, reinicio aislado y
  sin producir de cada nodo y comparación del resumen tras repetir todo su almacén; se aplica también a rep1 y rep2.
  Si entonces difieren, es una divergencia real.

### 16:46–17:50 — W07d migrada; R1 completa; R2 en marcha

- **W07d migrada** (`22940aa`): `reinicio_completo` y `parada` llevan el estado final (resumen del virtual y compendio
  de bloques); parada ordenada por señal. **Commit final de código de 0.0.1: `22940aa`** (solo registro respecto al
  medido `26312ff`). El «mismo estado» de cada repetición se verificará reabriendo cada nodo aislado con este binario.
- **R1 completa** (3 repeticiones): E-1, E-2 (0 rechazos) y E-4 superados en las tres; E-3 pendiente de la verificación
  final. **R2 rep1**: nodo tardío sincronizado desde el génesis en ≈ 64 s.
- 18:0x **Katana: 0.0.2 añadirá los mecanismos de Filecoin** (registro de sectores, PoRep, auditorías, ciclo de vida).
  `P-ZRX/PLAN-0.0.2.md` creado; IPA (familia D) e informe final anotados.
- 18:2x **Katana: 0.0.2 cambia el minero PoW** (SHA3-256; Rust CPU + HIP GPU AMD; corregir y reutilizar `caliza` y `silicio`). A-12 decidido, A-11 pasa a portar; límite: no hay GPU AMD en la máquina de referencia. `PLAN-0.0.2.md` e IPA anotados.
- 18:3x **Particiones que no lo eran.** W07b E-6 rep1: A «aislado» (relanzado en el mismo puerto, sin `--red-marcar`)
  tuvo 2 conexiones y recibió 261 bloques de B y C durante la «partición». La misma técnica en **W06d7 V5 (V6(b))**:
  su punta «aislada» coincidía con la de B/C → **no fue una partición real**; revisión de W06d7 y `SPEC-0.0.1`
  corregidas (V6(b) no demostrada). W06d7 V4 (E-6b) sí fue real. W07b parada y corregida: puerto nuevo para el aislado y
  criterio obligatorio de 0 conexiones y 0 bloques del otro lado en la ventana.
- 18:23 **Fallo fatal del nodo** en W07b R3 (E-6 rep1 relanzada): `fallo_productor` «no hay portador retenido para el slot 6» justo tras el corte. Intermitente (no apareció en R1/R2). **W06d9** (DeepSeek): causa exacta + red de seguridad (recalcular portadores o no producir ese slot, nunca morir). R3/R4 en pausa hasta el nuevo candidato; W07b adelanta la verificación del estado final de R1/R2 con el binario de `22940aa`.
