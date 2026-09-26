# P-TRANSICION · Contrato de transición PoW → PoAS + PoT + DAG, v0

**ID:** P-TRANSICION/CONTRATO-v0 (revisión v0.1: apartado «Ratificaciones v0.1» al final). **Estado:** propuesta de investigación, **no normativa**.
**Fecha:** 2026-09-26. **Firma:** Claude, director técnico bajo `AUTO-ZRX.md` (el mandato
nombra a «Codex»; Katana lo encargó a esta sesión).
**Desbloquea:** `ORDEN-T01` (oráculo mínimo de la transición) y las filas A-* de
`D-ZRX/IPA-ZRX.md`.

Este contrato cumple el paso (c) de `AUTO-ZRX.md` §5 y la etapa 0 de
`P-ZRX/PLAN-ARRANQUE-HIBRIDO.md` §5: fija **familias de bloque, estado, reglas y casos de
rechazo** con **parámetros simbólicos**, para que un oráculo pequeño compruebe contabilidad,
orden y rechazos. **No** fija un solo número, no valida criptografía de sector ni seguridad
económica, y no modifica `D-ZRX/SPEC.md`.

Etiquetas de evidencia (`AUTO-ZRX.md` §7): **[fuente]** fuente primaria comprobada;
**[derivación]**; **[hipótesis]**; **[decisión provisional]** (elección de diseño con condición
de reversión); **[pendiente]**.

---

## 0. Qué queda decidido aquí y por qué

Cada decisión es provisional, está aislada detrás de una interfaz (§8) y declara la evidencia
que la revertiría (`AUTO-ZRX.md` §3.4).

| ID | Decisión provisional | Motivo | Se revierte si |
|---|---|---|---|
| **D-T01** | La fase PoW es una **cadena lineal** con selección por **mayor trabajo acumulado** y desempate por menor hash (contrato de `fork_choice.rs:78-91` del archivo, a re-derivar). | Es una fase temporal de emisión; el análisis de Nakamoto (Bitcoin §§4, 11 **[fuente]**) y el verificador existente (`zx-core/src/target.rs`, `preimage/block.rs`) son lineales; un DAG PoW añade orden y superficie sin mejorar la seguridad de la emisión. | La tasa de huérfanos medida con el intervalo PoW elegido y la latencia de red objetivo concentra la emisión por encima del criterio que se fije antes de medir (IPA A-10). |
| **D-T02** | **Una sola historia y un solo génesis `G`.** La fase PoW empieza en `G` (coinbase de valor cero, `C-EMIT-02`, `C-GEN-03`); la fase PoST continúa **la misma** historia a partir del bloque terminal. No hay un «génesis DAG» separado. | Conserva UTXO, depósitos y emisión sin traspaso por checkpoint; evita la circularidad `C-FLU-06`/`C-HDR-09` detectada en C3 del 0.0.1 antiguo (`PIEZAS-DE-CODIGO/HOJA-DE-RUTA.md`, entrada C3). | Una prueba muestra que la semántica de altura/slot no puede cerrarse sin separar historias. |
| **D-T03** | **Selección a través del corte = «umbral PoW + peso PoST» (FC-3, §5.6).** Una historia completa es válida si su prefijo PoW es válido y su terminal cumple `Corte` (§5.3); entre historias válidas decide **solo el peso PoST** (GHOSTDAG `blue_work` del sufijo, contrato heredado de `C-GD`), con `C-FIN-01` acotando la profundidad para nodos en línea. El trabajo PoW del prefijo **no** se compara después del corte. | Separa lo que protege cada recurso: el hash protege la **distribución** anterior al corte (reescribirla exige `W_min` de trabajo **y** superar el peso PoST honesto); tras el corte, el hash deja de otorgar poder. FC-1 (comparar trabajo PoW primero) permitiría a una mayoría de hash borrar toda la historia PoST en cualquier momento; FC-4 (hash terminal fijado a mano) introduce un supuesto de confianza de lanzamiento. Precedente: EIP-3675 permite reorganizar entre terminales hasta la finalidad **[fuente]**; ZEROX no tiene capa de finalidad y usa `C-FIN-01`. | El modelo adversario (IPA A-05) muestra una historia válida en la que FC-3 no converge, o que el ataque «terminal tardío + espacio» es más barato que el comparador bajo el mismo adversario. |
| **D-T04** | **Corte condicionado, no por fecha fija (CUT-HWΦ, §5.3).** El terminal es el primer bloque PoW de su rama con altura `≥ H_corte_min`, trabajo acumulado `≥ W_min` y predicado de activación `Φ` verdadero sobre el estado del propio bloque. Si `Φ` es falso, la fase PoW **continúa**: la activación no falla en seco ni arranca sin garantía. | `C-BOT-05/06` exigen garantía **madura** y fallo de activación especificado de antemano; un corte por altura sola arranca PoST con garantía posiblemente nula; un corte por trabajo solo no garantiza depósitos. | Se demuestra que la prolongación puede sostenerse indefinidamente por censura de depósitos a bajo coste (ataque A-08) y la alternativa (tope `H_corte_max` con otra consecuencia) resulta preferible. |
| **D-T05** | **Las parcelas no dependen del terminal.** El reto de cada slot sale del flujo PoT, cuya semilla deriva del prefijo PoW (§5.5); la historia que se plotea parte del segmento génesis rellenado (patrón de Autonomys `f8842d0`, `crates/sc-consensus-subspace/src/archiver.rs:524-541` **[fuente]**: el génesis se rellena hasta `RecordedHistorySegment::SIZE` para que el primer segmento exista de inmediato). Así un granjero puede plotear durante la fase PoW. | Resuelve la contradicción de `PLAN-ARRANQUE-HIBRIDO.md` §4.4: una parcela que dependiera del terminal no podría estar lista en el terminal. | El formato elegido por `P-REGISTRO-SECTORES` (encargos 04/05) exige aleatoriedad posterior al terminal en la codificación; entonces se añade una espera de activación (§8, interfaz `Sectores`). |
| **D-T06** | **El stake no da oportunidades.** Oportunidades y `blue_work` salen solo de PoAS + PoT; el saldo solo habilita (`C-BON-04`) y responde (`C-EVP`, `C-SLA`). Toda función del oráculo que calcule peso u oportunidad **no recibe** saldos como argumento. | `AUTO-ZRX.md` §4 «Complementariedad»; `D-ZRX/SPEC.md` §0. | Decisión de arquitectura explícita posterior (no por este contrato). |
| **D-T07** | **Sectores detrás de una interfaz.** El oráculo implementa dos variantes: `SEC-0` (sin registro; línea base R0) y `SEC-A` (registro abstracto con alta, activación tras `M_sec` y plazo de prueba `P_sec`), **etiquetada como abstracta**. Ninguna afirma cobertura ni PoRep. | `P-REGISTRO-SECTORES` no ha decidido; `PLAN-ARRANQUE-HIBRIDO.md` §5 permite la interfaz abstracta. | Cierre de encargos 01–05. |

| **D-T08** | La coinbase PoST (`C-BON-03`) acredita a `sol.public_key` un **crédito pendiente** en `Garantía[P]`; al cumplir `M_rec_slots` pasa a `activo` (cuenta para `requisito`). No crea UTXO directamente; para gastarlo, `P` retira y libera (`C-BON-05/06`). | Lectura literal de `C-BON-03`: «crédito pendiente hasta cumplir C-EMIT-05; … no cuenta para el mínimo de participación antes de madurar». Convierte lo farmeado en garantía sin compra (`R-ZRX/LEGADO/stake/MAPA.md` §4). | Katana o el modelo económico (C-02/C-07) prefieren pagar en UTXO y exigir depósito explícito. |

**No se decide aquí** (queda en §8 y en `IPA-ZRX`): algoritmo PoW, intervalo, dificultad inicial,
retarget, curva y duración de emisión, cuantía y forma de `requisito`, derivación exacta de la
semilla del corte, `F_slots`, y si se activa algún mecanismo de sectores.

---

## 1. Símbolos

Unidades: `bloques_pow` (altura en la fase PoW), `slots` (índices de slot PoT, `C-FLU-01`),
`brek` (unidad monetaria mínima, `C-ENC`), `trabajo` (suma de `2^256/(target+1)` o la métrica
que defina el algoritmo PoW elegido). **Nunca** se convierten bloques en slots dentro de una regla:
esa conversión exige `λ`, que no es constante de consenso (`SPEC.md` antiguo, nota de `C-FIN-01`).

| Símbolo | Unidad | Significado | Restricción conocida |
|---|---|---|---|
| `H_dep` | bloques_pow | Primera altura PoW que admite depósitos (`C-BON-02`) | `H_dep ≥ 1` |
| `M_cb` | bloques_pow | Madurez de coinbase PoW (análogo de `C-EMIT-05`) | `M_cb ≥ 1` [pendiente: derivar de horizonte de reorg PoW] |
| `M_dep` | bloques_pow | Madurez de un depósito aplicado en fase PoW | `M_dep ≥ 0` |
| `H_corte_min` | bloques_pow | Altura mínima del terminal | `H_corte_min ≥ máx(H_dep, 1 + M_cb) + M_dep` (sin esto, `Φ` es falso por construcción) **[derivación]** |
| `W_min` | trabajo | Trabajo acumulado mínimo del terminal | `> 0`; [pendiente: A-05, A-10] |
| `Φ` | predicado | Activación: garantía activa total `≥ S_min`, claves con garantía activa `≥ K_min`, y en `SEC-A` capacidad activa `≥ C_min` | Varias claves **no** prueban operadores independientes (`C-BOT-06`) |
| `requisito(B)` | brek | Garantía activa mínima de `sol.public_key` para producir `B` | `> 0`, función **solo** de `past(B)` (`C-BON-04`); forma pendiente |
| `M_res_slots` | slots | Madurez residual de coinbases PoW no maduras en el terminal | pendiente |
| `M_rec_slots` | slots | Madurez del crédito de coinbase PoST (D-T08) | pendiente |
| `M_dep_slots` | slots | Madurez de depósitos aplicados tras el corte o no maduros en el terminal | pendiente |
| `R_slots` | slots | Retención tras retiro (`C-BON-05`) | `R_slots > Q_corr_slots + T_reporte_slots + M_estabilidad_slots` |
| `F_slots` | slots | Profundidad máxima de sustitución (`C-FIN-01`) | pendiente |
| `M_sec`, `P_sec` | slots | Solo `SEC-A`: espera de activación y plazo de prueba de alta | abstractos |
| `s_0` | slot | Slot de referencia del corte: lo ocupa virtualmente el terminal; todo bloque PoST tiene `slot > s_0`. Las madureces «desde `s_0`» se cuentan desde aquí | derivado del terminal (TRN-08); en el oráculo v0, `s_0 = 0` |

---

## 2. Familias de bloque

| Familia | Dónde es válida | Qué la autoriza | Qué contiene |
|---|---|---|---|
| `Génesis` | solo altura 0 | construcción constante (`C-GEN-01`) | coinbase de valor 0 inconectable (`C-GEN-03`); compromiso del relleno del segmento génesis (D-T05) |
| `PoW_arranque` | alturas `1 … altura(terminal)` de su rama | `hash(preimagen) < target(retarget)` | coinbase PoW, transacciones, depósitos, retiros |
| `PoAS_PoT_DAG` | solo en `desc(T)` para un terminal `T` válido | PoAS + PoT + sello (`C-HDR-03/04`) + `C-BON-04` | coinbase atribuida (`C-BON-03`), transacciones, depósitos, retiros, `EvidenceTx` |

El **bloque de transición** es el primer `PoAS_PoT_DAG` de una historia: su único padre es el
terminal `T` (en el sentido de EIP-3675 **[fuente]**: «TRANSITION_BLOCK … MUST be a child of a
terminal PoW block»).

---

## 3. Estado de consenso

`Estado(h)` tras aplicar un bloque o, en la fase PoST, tras aplicar el orden `C-ORD-03` hasta un
bloque de cadena seleccionada:

1. `UTXO`: salidas transparentes con `(valor, dueño, origen ∈ {coinbase_pow, coinbase_post, tx},
   creado_en)`; `creado_en` es altura PoW **o** slot de aplicación, nunca ambos.
2. `Garantía[P]` (`C-BON-01`): `activo`, `pendiente` (con su madurez), `en_retirada` (con su inicio),
   `congelado`, `incidentes_procesados`.
3. `Emitido`: suma de subsidios efectivos; `Quemado`: suma de pérdidas por `C-SLA`.
4. `Fase ∈ {PoW, PoST}` y, en PoST, `T` (hash del terminal) y `s_0`.
5. Solo `SEC-A`: registro de sectores `{id → (P, estado, alta_en, activa_en, plazo)}`.

**Invariante de conservación (I-1):**
`Σ UTXO.valor + Σ_P (activo + pendiente + en_retirada + congelado) = Emitido − Quemado`.

---

## 4. Transacciones y operaciones por fase

| Operación | Fase PoW | Fase PoST | Regla de origen |
|---|---|---|---|
| Coinbase | PoW: `Σ salidas ≤ subsidio_pow(h) + tarifas`, sin atribución de clave | PoST: importe explícito a `sol.public_key`, pendiente hasta madurar | `C-EMIT-03`, `C-BON-03` |
| Transferencia | sí | sí | `C-TX` |
| Depósito | desde `H_dep` | sí | `C-BON-02` |
| Retiro | sí | sí | `C-BON-05` |
| Liberación | sí, tras `R_slots` **no es expresable en PoW** → **[decisión provisional]**: en fase PoW no hay liberación; el retiro iniciado en PoW cuenta `R_slots` desde `s_0` | sí | `C-BON-06` |
| `EvidenceTx` | **rechazada** (no hay cabeceras PoST que firmar) | sí | `C-EVP-03` |
| Alta de sector (`SEC-A`) | sí, desde `H_dep` | sí | interfaz §8 |

---

## 5. Reglas de la transición

Identificadores `TRN-*` de trabajo, **no** reservados en el SPEC. Al promoverse, se renumeran
dentro de `C-BOT`.

**TRN-01 · Emisión PoW desde cero.** `G` no emite (`C-EMIT-02`, `C-GEN-03`). Cada bloque PoW de
altura `h ≥ 1` puede emitir `subsidio_pow(h)` (función pendiente). La suma emitida hasta el
terminal es `Emitido(T)`.

**TRN-02 · Madurez PoW.** Una salida `coinbase_pow` creada en `h` se puede gastar en un bloque PoW
de altura `h' ≥ h + M_cb`. Si `h + M_cb > altura(T)`, se puede gastar en la fase PoST desde el slot
de aplicación `≥ s_0 + M_res_slots` (**TRN-02b**, madurez residual). Nunca antes.

**TRN-03 · Depósito en fase PoW.** Un depósito aplicado en `h ≥ H_dep`, que consume solo salidas
gastables en `h`, pasa a `pendiente` y a `activo` en `h + M_dep` si `h + M_dep ≤ altura(T)`; si no,
en el slot de aplicación `≥ s_0 + M_dep_slots`. Una salida `coinbase_pow` inmadura **no** puede
depositarse (evita que una recompensa futura cuente como garantía, `C-BOT-01`).

**TRN-04 · Terminal.** Un bloque PoW `T` de una rama es **terminal** si y solo si:
`altura(T) ≥ H_corte_min` **y** `trabajo_acum(T) ≥ W_min` **y** `Φ(Estado(T))` **y** ningún
ancestro PoW suyo cumple las tres condiciones. (Definición por «primer bloque que cumple», como el
terminal de EIP-3675 **[fuente]**; puede haber varios terminales en ramas distintas.)

**TRN-05 · Fin del PoW.** Un bloque `PoW_arranque` cuyo padre es terminal o descendiente de un
terminal es **inválido** (EIP-3675: «PoW blocks that are descendants of any terminal PoW block MUST
NOT be imported» **[fuente]**).

**TRN-06 · Inicio del PoST.** Un bloque `PoAS_PoT_DAG` es inválido si su pasado no contiene
exactamente un terminal o si alguno de sus padres es un bloque PoW distinto de ese terminal.
El bloque de transición tiene como único padre a `T`.

**TRN-07 · Garantía en el primer bloque y siguientes.** Todo `PoAS_PoT_DAG` exige
`garantia_activa(sol.public_key, past(B)) ≥ requisito(B) > 0` (`C-BON-04`), con `requisito`
calculado solo de `past(B)`. Para el bloque de transición, `past(B) = historia hasta T`. Las
madureces se evalúan en el punto de aplicación de `B` (su altura o su slot, campos de su
cabecera): un pendiente que madura exactamente en `slot(B)` cuenta para `B`. **[decisión
provisional]**; se revierte si una regla de retención exige excluir el propio slot.

**TRN-08 · Semilla y slot de referencia.** `s_0` y la semilla del flujo PoT son función determinista
`derivar_semilla(historia hasta T)` (interfaz §8). Sustituye el origen de `C-FLU-06` (que hoy
parte del génesis DAG). Candidatos y ataque de sesgo en IPA A-07.

**TRN-09 · Selección a través del corte (FC-3).** Sea `𝓗` el conjunto de historias válidas conocidas.
Antes de que exista una historia con bloque de transición: se selecciona por mayor trabajo PoW
acumulado (D-T01). En cuanto existe al menos una historia con sufijo PoST válido: se selecciona la
de mayor peso PoST del sufijo (`blue_work` del virtual, contrato `C-GD`); a igualdad, menor
`block_hash(T)`, y después la regla de desempate de `C-GD`. Un nodo en línea **MUST NOT** sustituir
su selección por una candidata con `d ≥ F_slots` (`C-FIN-01`). El resultado debe ser **independiente
del orden de llegada** de los bloques.

**TRN-10 · Retiro que cruza el corte.** Un retiro aplicado en fase PoW deja de contar en el acto
(`C-BON-05`) y cuenta `R_slots` desde `s_0` (§4).

**TRN-11 · Reorganización PoW antes del corte.** Revertir bloques PoW revierte UTXO, depósitos,
retiros, altas de sector y `Emitido`, con undo exacto; las madureces se recalculan contra la nueva
rama. Si la reorganización elimina el terminal seleccionado, se deshace también todo el sufijo PoST
que colgaba de él.

**TRN-12 · Prueba tardía (`SEC-A`).** Una prueba de alta de sector aplicada después de `alta_en +
P_sec` se rechaza y el alta caduca sin activar. Un sector no activo no habilita producción ni
cuenta en `Φ`.

---

## 6. Casos de rechazo que el oráculo debe cubrir

Cada caso se expresa sobre parámetros simbólicos y se prueba en **todas** las combinaciones de la
rejilla pequeña de `ORDEN-T01`. El error esperado es explícito (nunca un `false` genérico).

| ID | Historia | Resultado esperado |
|---|---|---|
| X-01 | Génesis con coinbase `> 0` o cuyas salidas entran en el UTXO | `ErrGenesis` |
| X-02 | Coinbase PoW `> subsidio_pow(h) + tarifas` | `ErrEmision` |
| X-03 | Gasto de `coinbase_pow` antes de `h + M_cb` (y de `s_0 + M_res_slots` si cruza el corte) | `ErrInmaduro` |
| X-04 | Depósito en `h < H_dep` | `ErrDepositoTemprano` |
| X-05 | Depósito que consume una `coinbase_pow` inmadura | `ErrInmaduro` |
| X-06 | Depósito que acredita a una clave distinta de la que firma la aceptación | `ErrAutorizacion` |
| X-07 | Bloque PoW hijo de un terminal (o descendiente) | `ErrPowTrasCorte` |
| X-08 | Bloque PoST sin terminal en su pasado, o con dos terminales, o con un padre PoW no terminal | `ErrSinTerminal` / `ErrTerminalAmbiguo` |
| X-09 | Bloque PoST de una clave con garantía activa `< requisito(B)` en `past(B)` (incluido depósito aún `pendiente`) | `ErrGarantia` |
| X-10 | Bloque PoST que declara un `requisito` distinto del calculado desde `past(B)` | `ErrGarantia` (el valor declarado se ignora; se recalcula) |
| X-11 | Terminal con `trabajo_acum < W_min`, o `altura < H_corte_min`, o `Φ` falso | no es terminal ⇒ X-08 para su hijo PoST |
| X-12 | «Terminal» que no es el **primero** de su rama en cumplir TRN-04 | no es terminal ⇒ X-08 |
| X-13 | `EvidenceTx` en un bloque PoW | `ErrOperacionFase` |
| X-14 | Liberación de garantía en fase PoW | `ErrOperacionFase` |
| X-15 | `SEC-A`: prueba de alta tras `P_sec`; producción con sector no activo | `ErrPruebaTardia` / `ErrSectorInactivo` |
| X-16 | Mismo conjunto de bloques entregado en órdenes distintos | misma historia seleccionada y mismo `Estado` (hash canónico) |
| X-17 | Dos terminales `T1`, `T2` con sufijos PoST de pesos `w1 > w2` | se selecciona `T1` salvo `d ≥ F_slots` para un nodo en línea |
| X-18 | Rama PoW tardía con más trabajo que la del terminal seleccionado y sin sufijo PoST | no desplaza la selección (TRN-09) |
| X-19 | Reorganización PoW que elimina el depósito que habilitaba al productor del bloque de transición | el bloque de transición queda sin garantía en la nueva rama ⇒ inválido allí; undo exacto |
| X-20 | Aplicar y deshacer cualquier prefijo válido | `Estado` idéntico byte a byte al previo (I-2) |

---

## 7. Invariantes que el oráculo debe verificar en toda traza

- **I-1** Conservación (§3), tras cada bloque y cada undo.
- **I-2** Undo exacto: `deshacer(aplicar(E, B)) = E`.
- **I-3** Determinismo: el `Estado` seleccionado depende solo del conjunto de bloques válidos
  conocidos, no del orden de llegada.
- **I-4** Unicidad de fase: toda historia válida tiene como mucho un terminal; ningún bloque PoW
  es descendiente de él.
- **I-5** Complementariedad (D-T06): la función de peso/oportunidad recibe solo datos PoAS/PoT; se
  comprueba que variar saldos con PoAS/PoT fijos **no** cambia pesos ni selección, salvo por
  invalidez del bloque (X-09).
- **I-6** Ninguna salida `coinbase_pow` inmadura figura como garantía activa ni se gasta.
- **I-7** `Φ` falso ⇒ no hay bloque PoST válido en esa rama hasta el primer bloque PoW posterior
  que haga verdadero TRN-04.

---

## 8. Interfaces sustituibles (cada una con sus candidatos)

| Interfaz | Candidato del oráculo v0 | Alternativas que el oráculo debe poder enchufar | Dónde se decide |
|---|---|---|---|
| `Corte` | CUT-HWΦ (TRN-04) | CUT-H (solo altura), CUT-W (solo trabajo, tipo TTD), CUT-HASH (hash fijado; supuesto de confianza) | IPA A-04 |
| `SeleccionTransversal` | FC-3 (TRN-09) | FC-1 (trabajo PoW primero), FC-2 (solo peso PoST, sin `W_min`) | IPA A-05 |
| `derivar_semilla` | `H_d("ZZKCutSeed______", block_hash(T))` como **marcador de posición** | ancla anterior `T − K_semilla`; retardo VDF de `D_semilla` slots; entropía externa (`C-FLU-06`) | IPA A-07 |
| `requisito(B)` | constante simbólica `q > 0` | por capacidad acreditada (`SEC-A`), proporcional a oferta, mixto | IPA C-02 |
| `Sectores` | `SEC-0` | `SEC-A` (abstracta) | `P-REGISTRO-SECTORES` |
| `Madurez_residual` | TRN-02b / TRN-03 con `M_res_slots`, `M_dep_slots` | ventana de depósito que cierra antes del corte | IPA A-02/A-03 |
| `Fallo_activacion` | prolongar PoW (D-T04) | tope `H_corte_max` con parada o activación degradada | IPA A-08 |

---

## 9. Lo que este contrato NO demuestra

- Que el PoW de arranque resista a un adversario con hash alquilable, ni que distribuya la emisión
  de forma justa (DCP-0012 de Decred muestra concentración **[fuente, vía `P-STAKE/MAPA.md`]**).
- Que `requisito` sea asumible por un granjero doméstico ni que la garantía escale con el daño
  posible (R-5 del libro de restricciones antiguo: un coste fijo por identidad solo domina por
  debajo de un tamaño).
- Que exista evidencia de doble farmeo en rama privada: no la hay (`D-ZRX/SPEC.md` §0; R-1, R-6).
- Que `SEC-A` represente ningún mecanismo real de Filecoin.
- Seguridad de red, latencia, particiones o eclipse: fuera del oráculo; van a otras órdenes.

---

## 10. Fuentes

- `AUTO-ZRX.md` §§3–5; `D-ZRX/SPEC.md` §§0, 3–6, 9; `P-ZRX/PLAN-ARRANQUE-HIBRIDO.md` §§4–5.
- EIP-3675 (Final), https://eips.ethereum.org/EIPS/eip-3675 — definiciones de
  `TERMINAL_TOTAL_DIFFICULTY`, terminal, `TRANSITION_BLOCK`, reorganización entre terminales hasta
  `FIRST_FINALIZED_BLOCK` y prohibición de importar descendientes PoW del terminal. Consultada
  2026-09-26.
- Autonomys `f8842d019cdf0f7163421b9644db5a9ff82b2a73`, `crates/sc-consensus-subspace/src/archiver.rs:470-541`
  (segmento génesis rellenado); `crates/subspace-core-primitives/src/segments.rs:513,521` y
  `pieces.rs:404,406` (`RecordedHistorySegment::SIZE = 128 × 31 × 2^15 B` **[derivación]** =
  130 023 424 B). Clon local: `/home/katana/zeo/.trash/zerox/PDF/autonomys-subspace/`.
- Archivo `9681061` (= `.trash/zerox/`): `SPEC.md` `C-EMIT-02/03/05`, `C-GEN-01…07`, `C-GD-07`,
  `C-ORD-03/04`, `C-FIN-01`, `C-FLU-06`, `C-REORG-01…07` (sha256 de `SPEC.md`:
  `b59905c5…d4e0ae`); `P-ZRX/T-ZRX/LIBRO-DE-RESTRICCIONES.md` (sha256 `1592ecb8…71f8de`).

---

## Ratificaciones v0.1 (2026-09-26, tras T01)

El oráculo T01 (`P-ZRX/P-TRANSICION/T01/`) documentó trece ambigüedades del contrato y de su orden
antes de escribir código y aplicó siempre la lectura restrictiva o compatible. El director las
**ratifica** como parte del contrato (identificadores `R-n` estables), y añade las reglas de forma que
ya impone el formato v0 (`P-ZRX/P-FORMATO/FORMATO-v0.md`) para que oráculo y motor Rust coincidan.

| ID | Regla ratificada | Origen |
|---|---|---|
| R-1 | `Emitido` y `Quemado` son enteros con signo de 128 bits; las salidas y garantías, `u64` comprobado | T01 AMBIGÜEDAD-1; ORDEN-T01 §3.11 |
| R-2 | A lo sumo una retirada pendiente por clave; un segundo `Retiro` con otra viva se rechaza con `ErrRetiroPendiente` (lectura restrictiva de `C-BON-05`) | AMBIGÜEDAD-2 |
| R-3 | Una transferencia no crea valor: `Σ salidas ≤ Σ entradas`, si no `ErrSaldo` | AMBIGÜEDAD-3 |
| R-4 | Un pendiente cuya madurez ya se cumple en el punto del bloque que lo crea pasa directamente a `activo` (p. ej. `M_dep = 0`) | AMBIGÜEDAD-4 |
| R-5 | I-7 se lee estructuralmente: un bloque PoST exige un terminal en su pasado, y el terminal es el primer bloque de su rama que cumple la interfaz `Corte`; con CUT-HWΦ eso implica `Φ` verdadero | AMBIGÜEDAD-5 |
| R-6 | La coinbase **debe** ser la primera transacción del bloque; en otra posición, o más de una, ⇒ `ErrEmision` (sustituye la lectura de AMBIGÜEDAD-6, que aplicaba la coinbase primero estuviera donde estuviera) | AMBIGÜEDAD-6, `C-BLK-07` antiguo, FORMATO-v0 |
| R-7 | La coinbase PoW tiene al menos una salida (la del génesis, una de valor 0); si no, `ErrEmision` | REVISION-W02 |
| R-8 | Importe 0 en `CoinbasePost`, `Deposito`, `Retiro` o `Liberacion` ⇒ `ErrSaldo` (en Rust: `ErrForma(ImporteCero)`) | FORMATO-v0 F-07, F-09 |
| R-9 | Una transferencia sin entradas es una coinbase fuera de lugar (`ErrEmision`); con entradas y sin salidas, `ErrSaldo` (en Rust: `ErrForma(TransferenciaSinSalidas)`) | `C-TX-17`, FORMATO-v0 |
| R-10 | Errores de forma sin nombre propio: `pow_ok` falso o `trabajo < 1` ⇒ `ErrPow`; altura o slot que no progresa y `peso < 1` ⇒ `ErrSlot` | AMBIGÜEDAD-7 |
| R-11 | En `SEC-0` las operaciones de sector se rechazan con `ErrFueraDeAlcanceV0`; en `SEC-A`, un alta antes de `H_dep` con `ErrDepositoTemprano` y en PoST con `ErrFueraDeAlcanceV0` | AMBIGÜEDADES 8 y 9 |
| R-12 | `EvidenceTx`: en PoW `ErrOperacionFase`; en PoST `ErrFueraDeAlcanceV0` mientras `C-EVP` no esté activo (en Rust, la versión 4 es `VersionInactiva`) | AMBIGÜEDAD-10 |
| R-13 | Un depósito aplicado en la fase PoST madura en `slot(B) + M_dep_slots` | AMBIGÜEDAD-11 |
| R-14 | El undo debe restituir el estado exacto; la técnica (copia en el oráculo, delta en Rust) es libre | AMBIGÜEDAD-12 |
| R-15 | Un bloque cuyo padre no es válido o no se conoce no es válido en `seleccionar` (`ErrSinPadre` en los vectores); un nodo en línea lo retiene como huérfano hasta que llega el padre | AMBIGÜEDAD-13 |
