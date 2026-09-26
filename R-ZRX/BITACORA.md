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
