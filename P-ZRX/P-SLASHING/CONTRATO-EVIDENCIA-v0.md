# CONTRATO-EVIDENCIA-v0 — `EvidenceTx`, verificación, incidente, plazo, confiscación y firmante seguro

**Orden:** SL-1. **Ejecutor:** subagente Sonnet (diseño y análisis, sin código de producto).
**Fecha:** 2026-09-26. **Estado:** propuesta ratificable, **no normativa** hasta que el director la
apruebe. Convierte las reglas propuestas `C-EVP-01…06` y `C-SLA-01…04` de `D-ZRX/SPEC.md` §5 en un
contrato preciso para el híbrido actual, sin fijar parámetros numéricos (los calibra SL-2).

Etiquetas: **[hecho]** verificado abriendo la fuente citada; **[derivación]** consecuencia lógica de
reglas ya fijadas; **[hipótesis]** elección de diseño de este contrato, no probada, sujeta a
ratificación o a SL-2/SL-3.

---

## 0 · Decisiones del director que no se reabren (orden §3, literal)

1. Única falta castigable en v0: la doble firma de `C-EVP-02`. Nada de ausencias.
2. Sin castigo correlacionado: `C-SLA-03` se sustituye por una pérdida **no correlacionada**
   (fracción fija de la garantía expuesta, parámetro para SL-2).
3. La evidencia es una transacción **v4** comprometida en `txid`, Merkle o `body_commitment` y peso,
   sin entradas ni salidas monetarias.
4. Congelación y confiscación son consecuencias **distintas**; suspender la elegibilidad no es
   confiscar.

**Consecuencia de la decisión 2, declarada aquí porque cambia la forma de las reglas heredadas.**
Al eliminar la correlación entre claves, toda la maquinaria de cohortes de `C-SLA-01`
(`Q_corr_slots`, `e = piso(s/Q_corr_slots)`, `n_e`, `f_e` creciente con el número de infractores)
pierde su función: existía solo para calcular la fracción **compartida** de un periodo. Con `f`
fija por incidente, cada incidente se liquida **de forma independiente**, sin agrupar por periodo.
Este contrato la sustituye por una ventana de admisión simple, `Plazo_slots`, contada desde
`slot_falta` (§4). **[derivación]** de la decisión 2.

---

## 1 · Símbolos nuevos de este contrato

| Símbolo | Unidad | Significado | Restricción / procedencia |
|---|---|---|---|
| `f` | fracción | Fracción fija de la garantía expuesta que se confisca por incidente | `0 < f ≤ 1`, racional de consenso; **[pendiente, SL-2]** — sustituye a `b`, `c` de `C-SLA-03` |
| `Plazo_slots` | slots | Ventana de admisión de `EvidenceTx` desde `slot_falta` | `> 0`; **[pendiente, SL-2]** — sustituye a `Q_corr_slots + T_reporte_slots` |
| `M_margen_slots` | slots | Margen de inclusión/propagación exigido a `R_slots` sobre `Plazo_slots` | `≥ 0`; **[pendiente, SL-2]** — análogo de `M_estabilidad_slots` de `C-BON-05` |
| `incident_id` | 32 B | Identificador de la falta, `H_d(dom_incidente, identidad C-EVP-01)` | ya definido en `C-EVP-03`, aquí solo se fija el dominio |
| `dom_incidente` | 16 B | Etiqueta de dominio para `incident_id` | `"ZZKEvpIncidente_"`, tabla `TAGS_FIJAS` (`FORMATO-v0.md` F-06) |
| `dom_txid_evp` | 16 B | Etiqueta de dominio del `extension_digest` de v4 | `"ZZKTxIdEvidencia"`, misma tabla |

La desigualdad heredada de `C-BON-05` se reescribe con los símbolos de este contrato (regla EV-15).

---

## 2 · Formato de `EvidenceTx` (v4)

**EV-01 · Cuerpo.** Una `EvidenceTx` v4 contiene **exactamente dos** cabeceras `PoAS_PoT_DAG`
completas (`FORMATO-v0.md` F-02, 589–1 037 B cada una, con su sello), **sin** entradas, salidas ni
testigos de transacción — el sello va dentro de cada cabecera, no en la lista de testigos de la
transacción. Se llaman `H1` y `H2` en **orden canónico**: `pre_hash(H1) <_lex pre_hash(H2)` (bytes,
orden lexicográfico estricto). El orden fija a la vez la posición de escritura y que `pre_hash(H1) ≠
pre_hash(H2)`: no hace falta una comprobación de desigualdad aparte. **[hecho]** el orden por
`pre_hash` ya está en `SPEC.md` §5 C-EVP-03 («EvidenceTx… contiene exactamente dos cabeceras
ordenadas por pre_hash»); **[derivación]** la mecánica de parser.

**EV-02 · Tamaño.** `1 178 … 2 074 B` de cabeceras, más la cabecera mínima de wire de la transacción
(`version, lock_time=0, expiry_height=0, n_in=0, n_out=0, n_wit=0`, `FORMATO-v0.md` F-14). El peso
(`C-WGT-02`, cuando se porte) **debe** contar los bytes completos de `H1` y `H2`: es la única forma
de que el coste de incluir evidencia esté acotado por el mismo mecanismo que acota cualquier otro
byte de bloque. **[derivación]** de F-02 y del principio de F-14 («la propiedad "longitud
serializada = peso" se mantiene»).

**EV-03 · `txid`.** Sigue el patrón de F-06 con una extensión propia:

```text
txid(v4) = H_d(raíz(CBID), header_digest ‖ inputs_digest(∅) ‖ outputs_digest(∅) ‖ extension_digest)
extension_digest = H_d(dom_txid_evp, dag_header_a_bytes(H1) ‖ dag_header_a_bytes(H2))
```

`extension_digest` se calcula sobre la **codificación canónica completa** de ambas cabeceras (no
solo sus `pre_hash`), para que el `txid` comprometa exactamente los bytes transportados —lo que
exige `C-EVP-03` («los bytes de ambas cabeceras… deben quedar comprometidos en txid»)— y no solo un
resumen que un implementador pudiera calcular de otra forma. **[derivación]** de F-06 + C-EVP-03.

**EV-04 · Rechazo de forma.** El parser rechaza, con el error indicado, sin llegar a la
verificación semántica (§3):

| Caso | Error |
|---|---|
| `n_in ≠ 0` o `n_out ≠ 0` o `n_wit ≠ 0` | `ErrForma(EvidenciaConEntradasOSalidas)` |
| No hay exactamente dos cabeceras, o alguna mide fuera de `[589, 1037]` B, o no decodifica como cabecera `PoAS_PoT_DAG` válida por F-02/F-04 | `ErrFormato` (reutiliza el parser de cabecera existente) |
| `pre_hash(H1) ≥_lex pre_hash(H2)` (orden no estrictamente ascendente, incluido `H1 = H2`) | `ErrForma(OrdenCanonicoInvalido)` |
| Bytes sobrantes tras `H2` dentro del cuerpo | `ErrFormato` (mismo criterio que F-14: nada puede sobrar) |
| `lock_time ≠ 0` o `expiry_height ≠ 0` | `ErrCampoInactivo` (F-10) |
| `version ≠ 4` | rechazada por el dispatcher de versión, `ErrVersionInactiva`/`ErrTxVersion` según corresponda (F-05); deja de aplicar cuando `C-EVP` se active |

**[derivación]** de F-04, F-05, F-10, F-14 y del principio general «el parser rechaza, no adivina».

---

## 3 · Verificación

**EV-05 · Identidad de oportunidad.** La identidad usada para comparar `H1` y `H2` es la de
`C-EVP-01`: `(public_key, sector_index, history_size, chunk, slot)`, tomada de `sol.*` y `slot` de
cada cabecera. Es la **vigente por defecto**; el motor debe dejarla como punto de extensión (mismo
criterio que `FIR-02`), porque Katana no ha decidido entre ella e IDV-01 (`DEFINICION-PROPUESTA.md`
§3) y las dos identidades **no** son intercambiables sin cambiar también el pago (`C-EVP-01`,
último párrafo). **[hecho]** C-GD-07/C-EVP-01; **[hipótesis]** que el motor deba mantener el punto de
extensión en vez de fijar la vigente a secas — recomendado por consistencia con FIR-02, ver
`INFORME.md` §Decisión-1.

**EV-06 · Identidad común.** `identidad(H1) = identidad(H2)` exactamente (los cinco campos, no un
resumen). Si difieren, no hay falta: `ErrSinEvidencia` (rechazo semántico, no de forma — la
transacción es bien formada pero no prueba nada; se descarta como cualquier operación que no valida
al aplicarse, `C-ORD-04`).

**EV-07 · Sellos.** `verificar_sello(H1)` y `verificar_sello(H2)` bajo la **misma**
`sol.public_key` (ZIP-215, `C-HDR-04`), cada uno sobre su propio `pre_hash`. Si cualquiera no
verifica: `ErrSinEvidencia`.

**EV-08 · Lo que la verificación NO exige.** No se comprueba la validez PoAS/PoT/padres de `H1` ni
de `H2` en su contexto (cláusula «(e)» de `DEFINICION-PROPUESTA.md` §1.2, dejada **fuera** a
propósito): basta EV-06 + EV-07. Consecuencias explícitas, ya en `C-EVP-04`: no hace falta
reconstruir la rama perdedora ni demostrar garantía histórica en dos pasados incompatibles; la
prueba acredita **dos decisiones de firma**, no que ambas fueran bloques válidos. **[hecho]**
C-EVP-04, línea «la prueba criptográfica no requiere reconstruir una rama perdedora».

**EV-09 · Coste acotado.** El coste de EV-06+EV-07 es `O(1)` por `EvidenceTx`: dos `SHA3-256` (los
`pre_hash`, ya calculados al parsear) y dos verificaciones Ed25519, sin recorrer el pasado del DAG,
sin necesitar la rama perdedora y sin depender del tamaño de la historia. No hereda el coste de
`DEFINICION-PROPUESTA.md` §4.2 para la cláusula (e) (que sí exige recomputar cadena y flujo ajenos)
precisamente porque EV-08 la deja fuera. **[derivación]** de EV-06…EV-08.

---

## 4 · Incidente único y deduplicación (también en el DAG)

**EV-10 · `incident_id`.** `incident_id = H_d(dom_incidente, bytes_canónicos(identidad(H1)))` — el
mismo para `H1` y `H2` por EV-06. No es el hash del par de cabeceras (`C-EVP-03`): dos pares
distintos de la misma identidad (p. ej. tres cabeceras del mismo billete, tres pares posibles)
producen el **mismo** `incident_id`.

**EV-11 · Registro y poda.** `incident_id` se añade a `Garantía[P].incidentes_procesados`
(`C-BON-01`, `P = public_key` de la identidad) en el momento en que se aplica la **primera**
`EvidenceTx` admisible de ese incidente. Se poda de `incidentes_procesados` en cuanto su ventana de
admisión cierra (`slot_actual ≥ slot_falta + Plazo_slots`, EV-13): pasado ese punto ninguna prueba
nueva del mismo incidente puede llegar a aplicarse, así que conservar el identificador no añade
nada — mismo criterio de poda que usa el firmante seguro para su propio registro (FIR-10).
**[derivación]** de C-EVP-03 + C-BON-01 («regla de poda determinista tras su plazo de admisión»).

**EV-12 · Deduplicación en modo fusión.** Si `incident_id` ya está en `incidentes_procesados[P]`
cuando se intenta aplicar una segunda `EvidenceTx` del mismo incidente (aun de otra rama o con otro
par de cabeceras), esa segunda transacción **se descarta** al fusionarla: no invalida su bloque de
origen (`C-ORD-04`, patrón ED-6 del contrato de estado en el DAG) y no vuelve a congelar ni
confiscar. **[hecho]** C-EVP-03, último párrafo.

---

## 5 · Plazo y disponibilidad

**EV-13 · Ventana de admisión.** Sin cohortes de correlación (§0), la regla se simplifica a una
ventana directa:

```text
admisible(EvidenceTx) ⟺ slot_falta ≤ slot_aplicacion(EvidenceTx) < slot_falta + Plazo_slots
```

donde `slot_falta = slot(H1) = slot(H2)` (parte de la identidad común, EV-06) y
`slot_aplicacion` es el de `C-BON-07` (el del bloque de cadena que la fusiona, no el de su propia
cabecera). **[derivación]** de C-EVP-05, simplificada al quitar `Q_corr_slots`/`T_reporte_slots`.

**EV-14 · Evidencia tardía.** Si `slot_aplicacion(EvidenceTx) ≥ slot_falta + Plazo_slots`, se
**descarta** al fusionarla (no invalida el bloque, mismo tratamiento que EV-12): `ErrEvidenciaTardia`.
No congela ni confisca nada. Es una pérdida **declarada**, no oculta: una doble firma real,
publicada, pero admitida tarde (por censura de la prueba, partición, o simplemente porque la
segunda cabecera de una rama privada solo se reveló después) **no se castiga en v0**. Esto es
consecuencia directa de exigir una ventana finita (EV-15/EV-16) y **es la respuesta a la parte (a)
de la pregunta falsable** — ver `INFORME.md` §1. **[hecho]** C-EVP-05, «una prueba en un bloque
antiguo fusionado después se rechaza como tardía».

**EV-15 · Desigualdad de retención, con los símbolos de este contrato.**

```text
R_slots > Plazo_slots + M_margen_slots
```

Es la reescritura de `R_slots > Q_corr_slots + T_reporte_slots + M_estabilidad_slots` (`C-BON-05`)
tras quitar la correlación. `M_margen_slots` cubre el tiempo de inclusión/propagación de la prueba
una vez publicada (análogo de `M_estabilidad_slots`), y queda simbólico para SL-2. Esta desigualdad
**no es opcional para ratificar**: si `R_slots ≤ Plazo_slots + M_margen_slots`, un infractor puede
completar una liberación (EV-26) antes de que la ventana de admisión de su propia falta cierre, y
entonces la garantía ya no existe para confiscar. Es la condición estructural de la parte (c) de la
pregunta falsable (`INFORME.md` §1). **[derivación]** de C-BON-05 + EV-13/EV-24…EV-26.

**EV-15b · La desigualdad EV-15 no basta con retiro parcial y producción continuada — cierre
adicional.** `EV-15` cierra el caso «falta antes del retiro, retiro después para escapar»
(`slot_falta < slot_aplicacion(retiro) = t0`): entonces `slot_falta + Plazo_slots + M_margen_slots <
t0 + Plazo_slots + M_margen_slots < t0 + R_slots`, y la liberación llega después de que la ventana de
la falta cierre. **No cierra el caso opuesto.** Un retiro (`C-BON-05`) puede ser **parcial**
(`FORMATO-v0.md` F-07, tipo 2 lleva `importe`): si el saldo activo restante sigue cumpliendo
`requisito(B)`, `P` **puede seguir produciendo** mientras su retirada está pendiente
(`t0 ≤ slot < t0 + R_slots`). Un atacante racional que ya tiene una retirada en curso puede esperar a
`sf → (t0 + R_slots)⁻` para cometer la doble firma: su ventana de admisión cierra en
`sf + Plazo_slots + M_margen_slots`, que **supera** `t0 + R_slots` en cuanto `sf` está a menos de
`Plazo_slots + M_margen_slots` del final de la retención. La liberación se aplicaría entonces sin que
ningún caso esté todavía admitido (EV-24 solo bloquea casos **ya** registrados), y el saldo saldría
de `Garantía[P]` antes de que la evidencia pudiera llegar. **Este hueco no está señalado en ninguna
de las fuentes leídas** (ni `CONTRATO-v0.md` C-BON-05, ni `P-PRESTAMO`/`P-CLAVE`, ni la síntesis de
`P-DISUASION`): es un hallazgo de esta orden, no una repetición.

**Cierre propuesto.** Añadir a `C-BON-06`/EV-24 una segunda condición, independiente de la primera:

```text
liberación(P) admisible ⟺ slot_aplicacion(liberación) ≥ slot_aplicacion(retiro) + R_slots
                          Y
                          slot_aplicacion(liberación) ≥ último_slot_producido(P) + Plazo_slots + M_margen_slots
```

`último_slot_producido(P)` es el mayor `slot(B)` de cualquier bloque `PoAS_PoT_DAG` aplicado con
`sol.public_key = P` en `past` del punto de liberación (dato ya disponible: es el mismo que exige
`C-BON-04` para admitir cada bloque de `P`). Con esta segunda condición, toda producción de `P`
—no solo la que motivó el retiro— tiene su ventana `Plazo_slots + M_margen_slots` completa para que
llegue evidencia antes de que **cualquier** liberación de `P` se complete. **[hipótesis]** propuesta
de este contrato, no probada por ningún oráculo todavía: candidata explícita para el catálogo de
casos de SL-3 (§11, fila nueva) y para el análisis de SL-2 (¿cuánto alarga la retención en la
práctica, con qué tasa de producción?). Ver `INFORME.md` §1 para la relación con la parte (c) de la
pregunta falsable.

**EV-16 · Retención de cabeceras y relación con `F_slots`/`C-FIN-01`.** Los nodos conservan
cabeceras de ramas y pruebas durante una retención **mayor que `Plazo_slots`** (no solo mientras la
rama está activa), para que un nodo que sincroniza tarde o recupera historia pueda todavía construir
`EvidenceTx` para incidentes dentro de la ventana. Esto **no** garantiza que una segunda cabecera
oculta se publique ni que llegue a tiempo: es capacidad de servicio, no una promesa de detección
(`C-EVP-05`, último párrafo). La cota `F_slots` de `C-FIN-01` es independiente: acota la profundidad
de reorganización que un nodo en línea acepta, no la ventana de evidencia; ambas cotas deben
convivir sin que ninguna dependa de la otra para su corrección (no se decide aquí una relación
numérica entre `F_slots` y `Plazo_slots`, queda para SL-2/calibración conjunta con B-05).

---

## 6 · Consecuencias: congelación y confiscación

**EV-17 · Qué se congela.** La primera `EvidenceTx` admisible de un incidente congela **toda** la
garantía castigable de `P` disponible en el momento de aplicarse: saldo **activo**, saldo
**pendiente** (crédito de coinbase o depósito aún no maduro), saldo **en retirada** (con
independencia de cuánto falte para `R_slots`) y **crédito de coinbase no maduro** (`C-BON-03`, antes
de cumplir `M_rec_slots`). Ninguna sub-cuenta escapa por estar en un estado transitorio: si solo se
congelara el saldo `activo`, un productor podría mantener su garantía siempre en `pendiente` o
iniciar un retiro por adelantado para quedar fuera de alcance, lo que vaciaría la regla. **[hecho]**
el enunciado «qué partes: activo, pendiente, en retirada, créditos de coinbase no maduros» viene
literal de la orden §4.5; **[derivación]** la razón económica de incluir todas.

**EV-18 · Cuándo se congela.** Al aplicar la primera prueba admisible (EV-11). Una segunda prueba
del mismo incidente (EV-12) no vuelve a congelar ni a extender la congelación. **[hecho]** C-SLA-02.

**EV-19 · Confiscación.** Al liquidar el incidente (ver EV-20 para el momento exacto con varios
incidentes de la misma clave):

```text
V(P, incidente) = saldo congelado remanente de P inmediatamente antes de liquidar este incidente
pérdida(P, incidente) = mín(V(P, incidente), techo_exacto(f × V(P, incidente)))
```

`techo_exacto` es división entera comprobada que redondea hacia arriba (mismo criterio que
`C-SLA-03`); con `V > 0` y `f > 0` la pérdida mínima es una unidad `brek`. `f` es **fija** por
incidente (decisión §0.2): no depende del número de infractores del periodo ni de cuántos otros
casos tenga la red en ese momento. **[hecho]** fórmula heredada de C-SLA-03 con `f` en el lugar de
`f_e`; **[derivación]** de la decisión de eliminar la correlación.

**EV-20 · Varios incidentes de la misma clave.** Si `P` tiene más de un incidente admitido (dos
billetes distintos, o el mismo billete con evidencias que llegaron por incidentes técnicamente
distintos — no debería ocurrir por EV-10, pero dos identidades **distintas** de la misma clave, p. ej.
dos `chunk`, sí generan dos incidentes), se liquidan **en orden creciente de `slot_aplicacion` de la
prueba que los admitió**, debitando el saldo remanente de cada liquidación anterior. Ninguna unidad
se confisca dos veces (mismo principio que `C-SLA-02`, sin el agrupamiento por cohorte `e`, que ya no
existe). **[derivación]** de C-SLA-02, adaptada a la ausencia de cohortes.

**EV-21 · Sin correlación entre claves distintas.** La `f` de un incidente de `P` no depende de
cuántas otras claves tengan incidentes en el mismo entorno temporal: deroga expresamente
`C-SLA-03`/`C-SLA-04` tal como estaban redactadas (con `f_e` creciente en `n_e`). Es la forma
literal de la decisión §0.2 del director. `DS-5` (`P-ZRX/P-DISUASION/REVISION-DS5.md`) ya mostró que
la versión correlacionada no encarece el ataque grande y sí castiga a honestos con un fallo común;
esta regla adopta esa conclusión.

**EV-22 · Clave sin saldo (la «grieta», A12/DS-3).** Si `V(P, incidente) = 0` en el momento de
liquidar (la clave nunca tuvo depósito, o ya lo perdió todo en un incidente anterior), `pérdida = 0`.
El incidente **se registra igual** en `incidentes_procesados[P]` (EV-11): eso no confisca nada, pero
sí impide que una prueba futura del **mismo** incidente vuelva a intentarlo si `P` deposita más
tarde. Este contrato **no cierra** la grieta de `DS-3`/`P-CLAVE` (el atacante que recluta claves de
saldo cero cruza la deriva a coste de soborno cero, `P-ZRX/P-CLAVE/investigacion/INFORME.md` §0): es
un límite conocido y declarado, no un defecto de esta regla. **[hecho]** C-EVP-04, «si no hay saldo,
no se inventa una confiscación»; **[hecho]** la grieta, medida en DS-3/P-CLAVE.

**EV-23 · Destino de los fondos confiscados.** **Decisión abierta para el director** — no se fija
aquí; ver `INFORME.md` §2, Decisión-2, con opciones (quemar / recompensar a quien incluye la
`EvidenceTx` / mezcla), su análisis de incentivos (inclusión, censura de evidencia, denuncia
repetida, autodenuncia) y la recomendación de este informe. La estructura de este contrato es
compatible con cualquiera de las tres sin cambiar EV-01…EV-22: el destino se resuelve en el punto de
aplicación (`C-ORD-03`), como una regla más de la liquidación (EV-19), y no exige un campo de
denunciante (`C-EVP-03` ya lo prohíbe: «no hay campo de denunciante sin recompensa» — una
recompensa al **incluidor** del bloque no es un campo de denunciante, es la coinbase de quien ya
firma ese bloque).

---

## 7 · Retiro

**EV-24 · Caso abierto bloquea liberación, y la ventana de producción también.** Una operación de
**liberación** (`C-BON-06`) de `P` se rechaza al aplicarse (`ErrCasoAbierto`/`ErrVentanaAbierta`,
descartada, no invalida el bloque que la contiene, mismo tratamiento que EV-12) si **cualquiera** de
estas dos condiciones falla:

```text
(i)  P no tiene ningún incidente admitido y no liquidado
(ii) slot_aplicacion(liberación) ≥ último_slot_producido(P) + Plazo_slots + M_margen_slots
```

(ii) es EV-15b: cierra el hueco de un retiro parcial con producción continuada, que (i) por sí solo
no cubre (EV-15b explica por qué). Un **retiro** (mover de `activo` a `en_retirada`) no se bloquea
por ninguna de las dos: mover a `en_retirada` no saca el saldo del alcance de la congelación
(EV-17), así que no hay razón económica para impedirlo, y bloquearlo además convertiría el retiro en
una señal pública de que hay un caso abierto contra `P`. **[derivación]** de C-SLA-02 («mientras
haya caso abierto, P no produce ni libera saldo») + EV-15b, separando retiro de liberación porque
EV-17 ya cubre el retiro.

**EV-25 · El retiro no exime.** Si `slot_falta` de un incidente es anterior a la aplicación del
retiro de `P`, el saldo retirado sigue congelable y confiscable (EV-17 ya lo incluye
explícitamente). No importa si el retiro se aplicó antes o después de que la evidencia llegara: lo
que importa es si la falta **ocurrió** mientras ese saldo era garantía de `P`. **[hecho]** viene
enunciado literal en la orden §4.6 («una retirada no escapa al castigo si la falta es anterior»).

**EV-26 · Pagos ya finalizados no se revierten.** Una **liberación** ya aplicada (saldo convertido
en UTXO gastable, `C-BON-06`) con `slot_aplicacion(liberación) < slot_falta` es legítima y no se
revierte: la falta todavía no existía cuando el saldo dejó de ser garantía. Si la liberación se
aplicó **después** de `slot_falta`, la condición (ii) de EV-24 (EV-15b) es la que garantiza que no
pudo aplicarse antes de que la ventana de esa falta cerrara — **no** basta con EV-15 sola, que solo
cubre faltas anteriores al propio retiro (EV-15b explica el hueco y por qué hace falta la segunda
condición). Si la evidencia no llegó a tiempo pese a esas dos condiciones (evidencia tardía, EV-14,
p. ej. por censura o una rama nunca revelada), la liberación queda firme por el mismo motivo que la
evidencia no se admite. No hay una regla adicional de reversión de UTXO ya emitidos: sería
inconsistente con la conservación monetaria (`I-1`) y con que ningún reorg posterior al punto de
aplicación pueda deshacer una liberación cuyo bloque ya está fuera del alcance de `F_slots`.
**[derivación]** de C-BON-06 + I-1 + EV-15/EV-15b/EV-24.

---

## 8 · Reorganización y undo

**EV-27 · Undo exacto.** Los efectos de una `EvidenceTx` (registro en `incidentes_procesados`,
congelación, confiscación) se aplican en el punto de aplicación de su bloque fusionador (`C-BON-07`)
y se deshacen exactamente si ese bloque deja de estar en la cadena seleccionada (`I-2`/`IE-4`), igual
que cualquier otra operación de garantía. No hay estado adicional a mantener: el `incident_id` en
`incidentes_procesados[P]` se retira con el undo, tal cual se añadió.

**EV-28 · Reaparición en otra rama.** Si el bloque que aplicó la primera `EvidenceTx` de un
incidente se deshace por una reorganización, y la cadena que prevalece **no** contiene ninguna
aplicación de ese incidente, el incidente vuelve a estar sin registrar: una `EvidenceTx` del mismo
incidente (con el mismo par de cabeceras, o con un tercer par si existía una tercera cabecera,
EV-10) que se aplique en la nueva cadena seleccionada se trata como **primera aplicación**
(EV-11...EV-19), no como duplicado. Esto es consistente con que la deduplicación (EV-12) es sobre
**la historia seleccionada aplicada**, no sobre todo lo que alguna vez existió en cualquier rama —
mismo principio que `C-EVP-03` aplica al incidente en general y que `C-ORD-03` aplica a cualquier
operación de garantía. **[derivación]** de I-2/IE-4 + C-EVP-03.

**EV-29 · Ventanas en slots absolutos.** `slot_falta`, `Plazo_slots` y `R_slots` se miden en slots
PoT globales, no en profundidad de rama ni en altura: una reorganización no desplaza estas ventanas,
solo puede cambiar **qué** bloque aplica la evidencia y **si** llega a aplicarse a tiempo en la
cadena que finalmente se selecciona. No se necesita una regla especial de «ventana que se reabre
tras un reorg»: la ventana siempre estuvo definida sobre `slot_falta`, fijo desde que se firmaron
`H1`/`H2`.

---

## 9 · Firmante seguro (`C-EVP-06`)

Especificación de requisito de **producción** (no de consenso: ningún verificador la ejecuta ni la
exige, `FIR-15`). Fuente primaria: prototipo validado con tests en
`.trash/zerox/P-ZRX/P-FIRMANTE/prototipo/` (informe en `.trash/zerox/P-ZRX/P-FIRMANTE/informe/`) y
código antiguo más maduro en `git show 9681061:crates/zx-consensus/src/firmante/{mod,alta,identidad,registro}.rs`.
Este contrato **prefiere el código antiguo** donde los dos difieren (justificado regla por regla) y
toma del prototipo la evidencia de coste medido, que el código antiguo no incluye.

**FIR-01 · La regla, literal.** Antes de emitir el sello de un candidato `B`:

```text
1. Calcular su identidad de oportunidad TicketId(B) (EV-05, vigente por defecto).
2. Consultar el registro persistente por (TicketId(B), slot(B)).
3. Si NO hay entrada: escribir (TicketId, slot) -> pre_hash(B) de forma ATÓMICA y DURADERA
   (fsync/commit) y SOLO ENTONCES firmar.
4. Si hay entrada con el MISMO pre_hash: firmar (reemisión; caso 4).
5. Si hay entrada con OTRO pre_hash: NO firmar. Descartar el candidato (caso 5).
```

El punto 3 es el contrato entero: persistir **antes** de firmar, no después de publicar. **[hecho]**
demostrado por test en el prototipo (`caso_5_con_entrada_previa_y_otro_pre_hash_no_firma`,
`caso_4_reemitir_el_mismo_bloque_funciona`, y el test de durabilidad con `SIGABRT`, §3.3 del
informe).

**FIR-02 · Identidad como índice, no `pre_hash`/`block_hash`.** El registro se indexa por la huella
de la identidad de oportunidad (EV-05) y el slot, nunca por `pre_hash` o `block_hash`: los dos
`pre_hash` de un accidente honesto son **distintos por construcción**, así que indexar por ellos no
protegería nada. La identidad es un **punto de extensión** con la vigente (`C-GD-07`) como
implementación por defecto, para no atar el trabajo a una decisión de Katana todavía abierta.
**[hecho]** demostrado por test (`el_punto_de_extension_funciona_con_dos_implementaciones`,
prototipo); **[hecho]** `ESPECIFICACION.md` §3.4.5.

**FIR-03 · Durabilidad.** `resolver`/escribir hace `fsync`(o equivalente) **antes** de devolver
`Ok`; si el `fsync` falla, el índice en memoria no cambia y no se firma. **[hecho]** medido: coste de
mediana ≈ 0,81 ms por bloque en NVMe/btrfs, el 0,099 % del slot de 1 s en el p99 (prototipo,
`informe/INFORME.md` §4) — no significativo a 1 bloque/s, así que no hay motivo para relajar la
durabilidad a cambio de velocidad (§4.1 del mismo informe descarta `fdatasync` por esa razón, y este
contrato adopta esa recomendación: **no** cambiar a `fdatasync` por defecto).

**FIR-04 · Verificación de la clave antes de reservar.** Tomado del código antiguo, mejora sobre el
prototipo: el firmante comprueba que la clave del firmador corresponde a `header.sol.public_key`
**antes** de tocar el registro. Una clave que no corresponde devuelve error sin ocupar la
oportunidad ni mutar `header.sello`. El prototipo no lo comprobaba (confiaba en que el llamante
pasara la clave correcta); en un nodo real, donde la clave puede venir de un monedero o HSM
separado, esta comprobación evita que un error de cableado consuma una oportunidad real con una
firma que de todos modos no sería válida. **[hecho]** `git show 9681061:…/mod.rs`,
`FirmanteError::ClaveNoCoincide`.

**FIR-05 · Verificación del sello construido.** Tomado del código antiguo: tras firmar, se
comprueba el sello resultante con `verificar_sello` (`C-HDR-04`) sobre una copia de la cabecera,
antes de escribirlo en la cabecera real. Si no verificara (fallo interno), la cabecera de entrada
queda intacta y no se publica nada. Es defensa en profundidad, no un caso que se espere disparar; el
prototipo no lo hacía. **[hecho]** `git show 9681061:…/mod.rs`, `FirmanteError::SelloInvalido`.

**FIR-06 · Formato del registro: cabecera inmutable.** Se adopta el formato v3 del código antiguo,
**no** el v1 del prototipo. Diferencia decisiva: la cabecera del fichero (`slot_perdida`,
`abstener_hasta`, la bandera de abstención) se escribe **una sola vez**, al crear el registro, y
nunca se reescribe. El prototipo (v1) reescribe `max_slot` en la cabecera cada vez que crece
(`OFFSET_MAX_SLOT`), lo que abre una ventana de corrupción de esa cabecera en cada bloque; el código
antiguo deriva `max_slot` en memoria a partir de `slot_perdida` y las entradas ya validadas, así que
la cabecera no tiene que volver a tocarse. Además, la cabecera del v3 lleva su propio checksum
SHA3-256 (16 B): un bit cambiado en la bandera de abstención falla cerrado (`CabeceraCorrupta`), en
vez de perder la abstención en silencio como podía ocurrir con el v2 heredado (documentado en el
propio código antiguo). **[hecho]** comentario de cabecera de `registro.rs` en `9681061`
(«la versión 2 guardaba la abstención… sin integridad»); **[hipótesis]** que esta mejora vale el
coste de mantenerla — recomendado en `INFORME.md`.

**FIR-07 · Envenenamiento ante fallo ambiguo.** Tomado del código antiguo, ausente en el prototipo:
si una escritura o una sincronización falla de forma que no se puede saber con certeza si la entrada
llegó a disco, la instancia del registro queda **envenenada**: toda llamada posterior a `resolver`
devuelve error hasta cerrar y reabrir (momento en que la recuperación relee el log entero y lo
vuelve a sincronizar). El prototipo, ante un fallo de `fsync`, simplemente no actualiza el índice en
memoria y devuelve error para **esa** llamada, pero deja la instancia operativa para la siguiente —
lo que asume que el fallo fue transitorio y que el estado del fichero en disco es exactamente el que
el índice en memoria cree, algo que un fallo de E/S ambiguo no garantiza. **[hecho]**
`RegistroError::Envenenado`, `git show 9681061:…/registro.rs`.

**FIR-08 · Recuperación que falla cerrada sin excepciones.** Tomado del código antiguo: ante
**cualquier** entrada incompleta o corrupta al final del fichero —incluida una cola de bytes a
cero—, la recuperación falla cerrada (`ColaParcial`/`Corrupto`) en vez de truncar. El prototipo
distingue una «cola a ceros» (la trunca, asumiendo que es una escritura interrumpida) de «bytes
alterados en medio» (falla cerrado); este contrato **abandona esa distinción**: una cola a ceros
podría ser también el resultado de una corrupción que por azar o por ataque produce ceros, y el
criterio de la propia especificación es «si dudas, no firmes» (`ESPECIFICACION.md` §3, nota al punto
3). Fallar cerrado ante una cola a ceros solo cuesta una abstención de `S_max_slots` de más en el
caso raro de una escritura real interrumpida — que de todos modos ya estaba cubierto por la
abstención general tras pérdida de estado (FIR-10) — y a cambio no depende de que «todo cero»
siga siendo, en el futuro, una señal fiable de escritura incompleta. **[hecho]** comparación directa
de `recuperar()` en prototipo (`registro.rs`, trunca colas a cero) contra `9681061` (`ColaParcial`
sin excepción); **[hipótesis]** que el coste de la abstención adicional es aceptable — cuantificado
en `INFORME.md` §3.

**FIR-09 · Sin poda in situ en v0.** Tomado del código antiguo: el registro **no** poda durante esta
fase; el log solo crece (2,59 GiB/año sin podar, medido en el prototipo, `informe/INFORME.md` §4.2).
El prototipo sí poda, reescribiendo el fichero completo con `seek(0)` + `write_all` + `set_len` +
`sync_all` bajo el mismo cerrojo: esa secuencia **no** es atómica frente a un corte de energía a
mitad de la reescritura (deja el fichero con una mezcla de contenido viejo y nuevo, sin ninguna
marca que distinga dónde se cortó). El código antiguo documenta la razón para no portarla:
«reescribir en sitio podía dejar un log válido pero incompleto tras un corte». Este contrato adopta
esa decisión para v0 y difiere la poda a una implementación posterior que escriba a un fichero
**nuevo** y lo sustituya por `rename` atómico (no evaluado aquí). **[hecho]** comentario de
`registro.rs` en `9681061`; **[derivación]** del análisis de atomicidad de la poda del prototipo.

**FIR-10 · Abstención exacta.** Tras perder el registro (fichero ausente, o `Registro::abrir` sobre
un fichero nuevo con `slot_actual` declarado), el firmante se abstiene durante exactamente
`S_max_slots`: `abstención_hasta = slot_perdida + S_max_slots`. Es suficiente y exacto porque, pasado
ese punto, ningún bloque nuevo puede reclamar un slot anterior (`C-GD-04`, `C-HDR-07`). **[hecho]**
demostrado por test (`la_abstencion_tras_perder_el_registro_dura_exactamente_s_max_slots`,
prototipo). `S_max_slots` **no** es una constante de este contrato: es el parámetro del perfil
vigente (nominal 150, `SPEC.md` §7.3), y entra como argumento a `Registro::abrir`/`Firmante::nuevo`.

**FIR-11 · Restauración de copia de seguridad.** No demostrado por ningún test existente y no
cubierto por el código antiguo ni por el prototipo: se declara aquí como requisito explícito.
Restaurar una copia de seguridad del registro **debe** tratarse siempre como pérdida de estado
(abrir con `Registro::abrir`, no con `Registro::nueva`/una ruta que asuma continuidad), salvo que el
operador pueda demostrar que la copia es **al menos tan reciente** como el `max_slot` que el nodo
recuerda haber alcanzado por otra vía (por ejemplo, un log de aplicación separado). Sin esa prueba,
una copia antigua reintroduce exactamente FP2 (`FALSOS-POSITIVOS.md`): el registro «recuerda» menos
de lo que el productor realmente firmó, y sin la abstención volvería a firmar un slot ya usado.
**[derivación]** de FP2 + FP7; **[hipótesis]** el requisito en sí, no probado por test — candidato
para SL-3/SL-4.

**FIR-12 · Alta atómica de clave y registro nuevos.** Tomado del código antiguo (`alta.rs`, ausente
en el prototipo): generar una clave nueva y un registro limpio en una sola operación resuelve un
bloqueo práctico que el prototipo no trata. `Registro::abrir` sobre un fichero inexistente nace en
abstención (correcto para una clave que **ya existía** y perdió su registro), pero para una
identidad genuinamente **nueva** esa abstención es espuria: no hay nada que perder porque nunca
firmó nada. Bajar `S_max_slots` para evitarlo no es una opción (abriría la ventana real de doble
firma tras una pérdida de verdad). La solución del código antiguo es atar la generación de la clave
a la creación de un registro **sin historia** (`Registro::nueva`), bajo un cerrojo de
aprovisionamiento (`alta.lock`) que impide una carrera entre dos procesos de alta concurrentes.
**[hecho]** `git show 9681061:…/alta.rs`, comentario de módulo y `ALTA-FIRMANTE-DAG-DEV`.

**FIR-13 · Lo que este mecanismo NO cubre — sin suavizar.**

| Límite | Por qué no lo cubre | Consecuencia declarada |
|---|---|---|
| Dos máquinas sin registro común (FP1, FP6) | El registro es local; nada coordina dos ficheros distintos | Dos nodos redundantes sobre la misma parcela siguen produciendo la evidencia de FP1 |
| Clave robada o compartida (FP6) | La identidad es `public_key`; el firmante no distingue quién controla la máquina | El castigo (EV-17…EV-22) cae sobre el **saldo de la clave**, no sobre «quién usó el firmante»: es la refutación de la parte (b) de la pregunta falsable, ver `INFORME.md` §1 |
| Un atacante decidido | El registro es un fichero local sin protección criptográfica contra su borrado | Quien quiera doble-firmar borra el registro o usa otro binario; **no es un mecanismo de seguridad** |
| Pérdida honesta del slot tras reorg (FP3/FP7) | El firmante se niega a reusar un billete que `SPEC.md` §7.2 libera tras un reorg | Es el **precio** del mecanismo, no un fallo: decisión de diseño, no se corrige aquí |
| Identidad mal elegida | Solo las dos implementaciones existentes (vigente e IDV-01) están probadas | Una tercera definición que, por ejemplo, omitiera el slot, rompería la garantía sin que el firmante pueda detectarlo |
| Registro en red (NFS y similares) | Un `fsync` de red puede no garantizar durabilidad, o mentir | No medido; un registro compartido que mienta al sincronizar anula la garantía entera |

**FIR-14 · Coste, medido.** ≈ 0,81 ms de mediana por bloque (NVMe/btrfs), 0,099 % del slot de 1 s en
el p99, 0,29 % en el peor caso de 2 000 muestras (prototipo, `informe/INFORME.md` §4). No
significativo a 1 bloque/s. `fdatasync` bajaría el coste a la mitad pero **no se adopta por
defecto**: el ahorro no compensa el riesgo de debilitar la durabilidad (§4.1 del informe, FIR-03).

**FIR-15 · Frontera: no es consenso.** Ningún verificador ejecuta ni exige el firmante seguro; no
entra en ningún `pre_hash`, no viaja por la red y no altera `C-HASH-05`. Es política **local** de
producción. **[hecho]** declarado en ambos códigos fuente (prototipo y `9681061`) y en la orden.

---

## 10 · Catálogo de falsos positivos (entrada de SL-2)

Tabla heredada de `FALSOS-POSITIVOS.md` §2, con la columna de qué evita el firmante seguro **de
este contrato** (FIR-01…FIR-13):

| Caso | ¿Posible? | ¿Regla de consenso lo evita? | ¿El firmante seguro (FIR) lo evita? |
|---|---|---|---|
| FP1 *harvesters* redundantes | sí | no (barajado deliberado de `C-GD-10`) | sí, **si** comparten registro (FIR-13, no cubierto entre máquinas) |
| FP2 reinicio con pérdida de estado | sí | no | sí, si el registro sobrevive (FIR-03/FIR-10) |
| FP3 producción en slot pasado tras adopción de rama | sí | no | sí, con el coste declarado de FP7 |
| FP4 reempaquetado con otro cuerpo | sí | no | sí (indexa por identidad de oportunidad, no por `pre_hash`) |
| FP5 punta cambiada antes de firmar | sí | no | sí |
| FP6 clave compartida o robada | sí | no | solo si el registro es común; el castigo cae sobre el saldo (EV-22, FIR-13) |
| FP7 reuso del billete liberado por reorg | sí (`SPEC.md` §7.2 lo permite) | — | sí, pero con pérdida honesta declarada (el precio del mecanismo) |
| FP8 dos redes con la misma clave y sector | sí, con la identidad vigente (sin dominio) | no | solo con la variante `TicketConRed`/IDV-01 (EV-05, decisión abierta) |
| FP9 época saltada / herencia de ancla | no produce la evidencia | — | — |

Ninguna fila de esta tabla la cierra el consenso: la columna «firmante seguro» es siempre
condicional (registro compartido, o una decisión de identidad todavía abierta). Es exactamente la
entrada que la orden pide para SL-2 (calibrar `f`, `Plazo_slots`, `M_margen_slots` contra la tasa de
falsos positivos residual, principalmente FP1/FP2/FP5 con `n ≥ 2` nodos honestos o reinicios
frecuentes).

---

## 11 · Casos para el oráculo de SL-3

| Categoría | Caso | Resultado esperado |
|---|---|---|
| Positivo | `H1`, `H2`: misma identidad, `pre_hash` distintos, sellos válidos, dentro de `Plazo_slots` | Congela y confisca (EV-17…EV-19) |
| Positivo | Tres cabeceras del mismo billete (tres pares posibles) | Un único `incident_id`; solo la primera prueba aplicada produce efecto (EV-10, EV-12) |
| Positivo | Segunda evidencia del mismo incidente llega tras una reorganización que deshizo la primera | Se aplica como primera (EV-28) |
| Negativo | Misma cabecera retransmitida (no una segunda firma) | No hay `EvidenceTx` que formar: un solo `pre_hash` |
| Negativo | Dos sellos Ed25519 distintos sobre el **mismo** `pre_hash` (no unicidad del sello, `C-HDR-04`) | `ErrForma(OrdenCanonicoInvalido)` en la forma (mismo `pre_hash` ⇒ `H1 = H2` en el orden canónico) o `ErrSinEvidencia` en semántica: no hay dos `pre_hash` distintos |
| Negativo | Identidades distintas (`public_key`, `chunk`, `sector_index`, `history_size` o `slot` distintos) | `ErrSinEvidencia` (EV-06) |
| Adversarial | Evidencia duplicada del mismo incidente, misma rama, dos bloques | La segunda se descarta al fusionar (EV-12) |
| Adversarial | Evidencia con cabeceras de identidad vigente que colisionan por falta de dominio de red (FP8) | Se admite igual (es exactamente el límite EV-05/FP8 declarado, no un error de forma) |
| Adversarial | Evidencia tardía (`slot_aplicacion ≥ slot_falta + Plazo_slots`) | `ErrEvidenciaTardia`, descartada (EV-14) |
| Adversarial | Evidencia contra una clave sin saldo | `pérdida = 0`, incidente registrado igual (EV-22) |
| Adversarial | `H1 = H2` (cabeceras idénticas) | `ErrForma(OrdenCanonicoInvalido)` (EV-04) |
| Adversarial | Firma inválida en `H1` o `H2` | `ErrSinEvidencia` (EV-07) |
| Adversarial | Reorganización que saca la aplicación de la evidencia de la cadena seleccionada | Undo exacto; incidente vuelve a estar sin registrar (EV-27/EV-28) |
| Adversarial | `EvidenceTx` con entradas o salidas monetarias | `ErrForma(EvidenciaConEntradasOSalidas)` (EV-04) |
| Adversarial | Retiro/liberación de `P` mientras tiene un incidente abierto | Liberación descartada (`ErrCasoAbierto`, EV-24); retiro se acepta (EV-24) |
| Adversarial | Retiro parcial en `t0`; `P` sigue produciendo con el saldo activo restante; doble firma en `sf`, con `t0 < sf < t0 + R_slots` y `sf` cercano a `t0 + R_slots`; liberación intentada en `t0 + R_slots` | Liberación descartada por la condición (ii) de EV-24/EV-15b (`slot_aplicacion(liberación) < último_slot_producido(P) + Plazo_slots + M_margen_slots`), aunque la condición (i) sola no la habría bloqueado |

---

## 12 · Parámetros abiertos (calibra SL-2)

| Símbolo | Qué fija | Restricción estructural ya escrita aquí |
|---|---|---|
| `f` | Fracción confiscada por incidente | `0 < f ≤ 1` |
| `Plazo_slots` | Ventana de admisión desde `slot_falta` | `> 0` |
| `M_margen_slots` | Margen de inclusión sobre `Plazo_slots` | `≥ 0`; junto con `R_slots`: `R_slots > Plazo_slots + M_margen_slots` (EV-15, no negociable) **y** toda liberación debe respetar además `slot_aplicacion(liberación) ≥ último_slot_producido(P) + Plazo_slots + M_margen_slots` (EV-15b, cierre del hueco de retiro parcial) |
| Relación `Plazo_slots` ↔ `F_slots` | Cuánta ventana de evidencia hay dentro de la profundidad de reorganización aceptada | No fijada aquí (EV-16); afecta a B-05 |
| `S_max_slots` (firmante) | Horizonte de abstención tras pérdida de registro | Ya tiene valor nominal de perfil (150); no lo fija esta orden |

No numéricos, para el director (`INFORME.md` §2): identidad de oportunidad vigente vs. con dominio
de red (EV-05/FP8); destino de los fondos confiscados (EV-23).

---

## Ratificación v0 (2026-09-26) — prevalece sobre lo anterior

**Firma:** Claude (director), con las decisiones de Katana de `P-ZRX/P-SLASHING/DECISIONES.md`. Este texto
es copia de la entrega de SL-1 (`resultados-SL1/CONTRATO-EVIDENCIA-v0.md`, huella en su `HUELLAS.sha256`)
más estas ratificaciones, que **sustituyen** a lo que contradigan.

- **RAT-1 (EV-05, DS-L04, Katana):** la identidad de oportunidad es
  `(consensus_branch_id, public_key, sector_index, history_size, chunk, slot)`. Una `EvidenceTx` solo es
  admisible si **ambas** cabeceras llevan el `consensus_branch_id` de la red local; si no, `ErrForma`
  (no es evidencia de esta red). Se elimina el punto de extensión a IDV-01. **Límite declarado:** en una
  actualización de protocolo que parta la red, firmar el mismo slot en la rama vieja y en la nueva no es
  doble firma. **Regla nueva:** cada red tiene un `consensus_branch_id` distinto (`zx-core::red`), con test.
- **RAT-2 (EV-23, DS-L03, Katana):** de la cantidad confiscada `C = mín(V, techo_exacto(f·V))`,
  `techo_exacto(C·2/8)` se acredita a la coinbase del bloque que **aplica** la `EvidenceTx` (con la madurez de
  la coinbase PoST de ese bloque) y el resto se **quema** (`Quemado += C − recompensa`). Si el bloque se
  reorganiza fuera, se deshace todo con él (EV-27/EV-28). La autodenuncia nunca es rentable: el infractor
  pierde al menos `6/8·C`.
- **RAT-3 (EV-15b / EV-24(ii), DS-L05):** se adopta: una liberación exige
  `slot ≥ slot_retiro + R_slots` **y** `slot ≥ último_slot_producido(P) + Plazo_slots + M_margen_slots`. La
  activación del castigo comprueba `R_slots > Plazo_slots + M_margen_slots` como **puerta** (como `Φ`).
- **RAT-4:** sin castigo correlacionado (DS-L02): las cohortes de `C-SLA-01` no existen en v0.
- Parámetros (`f`, `ρ_ret`, `T_v`, `R_slots`, `Plazo_slots`, `M_margen_slots`, `q`): los calibra SL-2/SL-2b;
  en la red dev, los que ratifique `REVISION-SL2b.md`.
