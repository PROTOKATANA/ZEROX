# PROGRESO — T04 (oráculo de estado en el DAG PoST)

**Ejecutor:** DeepSeek `deepseek-flash` (esfuerzo `high`). **Zona única escribible:** `T04/`.
**Presupuesto declarado antes de ejecutar (LINEO §7):** 3 h de reloj, 1 hilo (hasta 4 solo si el
perfil lo justifica), 8 GiB de RAM, 2 GiB de disco. Si se agota: checkpoint y **inconcluso**.

## 0. Comprobación de la entrada congelada

`cd /home/katana/zeo/ZEROX && LC_ALL=C sha256sum -c P-ZRX/P-DAG/ENTRADA-T04.sha256` — **al empezar**:

```
P-ZRX/P-DAG/ORDEN-T04.md: OK
P-ZRX/P-DAG/CONTRATO-ESTADO-DAG-v0.md: OK
P-ZRX/P-TRANSICION/CONTRATO-v0.md: OK
P-ZRX/P-DAG/DECISIONES-W05.md: OK
V-ZRX/LINEO.md: OK
```

## 1. Falta de definición detectada antes de editar código (`ORDEN-T04` §3)

Las siguientes reglas admiten dos lecturas. Se registran **antes** de escribir código. En todas se
aplica la lectura **restrictiva o forzada por otra regla**, y ninguna altera otra regla del contrato;
por tanto **no se para**. La justificación completa va a `METODO.md`.

- **AMBIGUEDAD-1 — base del subsidio de la coinbase PoST al fusionar.** §3 del contrato escribe
  `subsidio_post(slot(B))` para el importe, mientras §1 dice que el punto de aplicación es el slot del
  bloque de cadena `C` que fusiona, «no el slot de X», y que «madureces, retiros y créditos de X
  cuentan desde ese punto». Lectura adoptada: **el importe usa `slot(X)` (el propio bloque); la
  madurez del crédito, el inicio de retiro y el vencimiento de liberación usan `punto` (slot de C)**.
  Motivo: la lista de §1 no incluye el importe del subsidio y la recompensa es propiedad de X;
  si el subsidio usara `punto`, el estado de la cadena dejaría de coincidir con T01 en IE-5.
- **AMBIGUEDAD-2 — coinbase ausente en un bloque PoST.** §3 exige posición/unicidad/clave; T01
  (`aplicar_txs!`) admite `ncb = 0`. Lectura adoptada: **se admite un bloque PoST sin coinbase**
  (`ncb = 0`), con `Emitido += -tarifas` como en T01; si hay coinbase, debe ser única
  (`ncb ≤ 1`) y la primera. Motivo: máxima compatibilidad con T01 (IE-5); la regla de recorte es
  vacua sin coinbase.
- **AMBIGUEDAD-3 — importe 0 en `CoinbasePost`.** R-8 lo declara `ErrSaldo` (forma), mientras §3
  solo dice que el importe se recorta. Lectura adoptada: **`importe == 0` invalida el bloque**
  (`ErrSaldo`, forma, admisión); el recorte `mín(declarado, subsidio + tarifas aceptadas)` se aplica
  solo a `declarado > 0`. Motivo: R-8 es ratificación v0.1 del contrato; el recorte sigue vigente
  para todo importe positivo. `subsidio_post ≥ 3 > 0`, así que el recorte nunca da crédito 0.
- **AMBIGUEDAD-4 — punto de aplicación de `sp(B)` en ED-2.** La frase «aplicando `sp(B)` … y …
  cada bloque del mergeset …, todos … con punto de aplicación `slot(B)`» puede leerse como que
  `sp(B)` también se aplica en `slot(B)`. Lectura adoptada: **`sp(B)` se aplica en su propio slot
  (cadena) y solo el mergeset en `slot(B)`**. Motivo: aplicar `sp(B)` en `slot(B)` contradice ED-1 y
  ED-3 y **rompe IE-5** (la cadena dejaría de coincidir con T01, que aplica cada bloque en su slot);
  es la única lectura compatible.
- **AMBIGUEDAD-5 — definición de `merge_depth` (decisión 5).** §5 no fija la unidad. Lectura
  adoptada: `B` es **inválido** si algún bloque no-`rojo_U3` de `mergeset(B)` cumple
  `slot(B) - slot(X) > F_slots` (profundidad en slots, la única unidad disponible: IPA B-10). Solo
  invalida; no altera ninguna otra regla.
- **AMBIGUEDAD-6 — `slot(V)` del bloque virtual (ED-3).** No está definido. Lectura adoptada:
  `slot(V) = max(slot(puntas válidas))` (sin avanzar el reloj artificialmente). Afecta solo la
  promoción/creación de las puntas no seleccionadas en `Estado(past(V))`; no contradice otra regla.
- **AMBIGUEDAD-7 — orden de materialización de la coinbase frente a ED-5.** La coinbase es la primera
  transacción, pero su crédito recortado depende de las tarifas aceptadas, que se conocen al final.
  Lectura adoptada: se aplican las transacciones no-coinbase en orden y después se materializa el
  crédito recortado. Con `M_rec_slots ≥ 1` el crédito queda pendiente y el orden es irrelevante; la
  rejilla de T04 **fija `M_rec_slots ≥ 1`**, de modo que no hay divergencia. No altera otra regla.
- **AMBIGUEDAD-8 — comprobaciones estructurales heredadas de GDR-v0.2.** El contrato no enumera
  `slot(sp) ≤ slot(B)`, `max_parents`, U2 ni `s_max`. Lectura adoptada: **son reglas de forma/padres
  y su fallo invalida el bloque**; se fija `max_parents = 3`, `u2 = true`, `u3_mode = U3_DYNAMIC`,
  `s_max = typemax` (no se añade una cota de salto no pedida). El límite real de padres de la orden
  es `≤ 3`.
- **AMBIGUEDAD-9 — garantía del productor.** `requisito(B)` es la constante simbólica `q` (interfaz
  por defecto) y se comprueba sobre `Estado(past(B))` **tras promover** en `slot(B)` (TRN-07/R-4: un
  pendiente que madura exactamente en `slot(B)` cuenta). No altera otra regla.
- **AMBIGUEDAD-10 — garantía de bloques fusionados.** La garantía es comprobación de **admisión** en
  `Estado(past(X))` de cada bloque, no se re-comprueba al fusionarlo. §3 la sitúa en «admisión».
  No altera otra regla; evita dobles cobros y dobles rechazos.

**Conclusión de la fase de lectura:** ninguna ambigüedad obliga a elegir entre reglas incompatibles;
se aplican las lecturas anteriores y se continúa. Las 10 quedan documentadas aquí y en `METODO.md`.

## 2. Diario de ejecución

- *Lectura íntegra* de ORDEN-T04, LINEO, CONTRATO-ESTADO-DAG-v0, CONTRATO-v0 (+ratificaciones v0.1),
  DECISIONES-W05, oráculo T01 (Transicion.jl, selección, nodo, generadores, exportador, lector) y
  oráculo GDR-v0.2 (modelo, referencia, validación, contrato, modelo, run, volcar_corpus).
- *Entrada* verificada al empezar (5/5 OK).
- *Proyecto* montado en `T04/` con depot local copiado de T01 (`JULIA_DEPOT_PATH=T04/.julia-depot`,
  `JULIA_PKG_OFFLINE=true`); `Manifest.toml` resuelto sin red. T01 se incluye como submódulo de solo
  lectura (`include`), declarado en `METODO.md` §1.
- *GDR-v0.2 copiado* (`src/modelo.jl`, `src/referencia.jl`, sha256 idénticos a `9681061`) y
  **revalidado exacto**: corpus 28 DAGs / 2290 bloques y kaspa 84 bloques, 0 discrepancias.
- *Oráculo* implementado: `Admision`, `aplicar_bloque_fusion!`, `estado_past!` (ED-2),
  `estado_virtual`/`aplicar_historia` (ED-3, con el mergeset completo de V), undo exacto.
- *Casos dirigidos* D-1…D-8 construidos a mano y verificados (doble gasto, recorte, depósito,
  garantía en rama, `rojo_U3`, una sola aplicación, reorg, hermanos de transición).
- *Propiedades* IE-1…IE-6 implementadas y pasadas.
- *Vectores*: 908 casos exportados y releídos de forma independiente (0 discrepancias).
- *Batería completa* `run.jl --replicas 200`: 3000 historias, 25380 bloques, 15858 válidos,
  1977 descartes, 1374 `rojo_U3`, 673650 órdenes IE-3, **0 fallos**, 50,1 s. Estado **SUPERADO**.
- *Tests* `test/runtests.jl` con 5 réplicas/punto: **361/361 OK** (`resultados/test.log`).
- *Cierre*: `INFORME.md`, `METODO.md`, `HORAS.log`; entrada congelada verificada de nuevo al terminar.

## 3. Estado final

**SUPERADO.** Entregables completos en `T04/`. Nada escrito fuera de `T04/`; sin commit ni push;
sin Python; sin `Ok` ficticio. Las 10 ambigüedades quedan documentadas con su lectura adoptada.

---

# T04-B — Nonce por clave (F-15) en el oráculo del estado DAG y reexportación

**Ejecutor:** DeepSeek `deepseek-flash` (esfuerzo `high`). **Zona única escribible:** `T04/`.
**Presupuesto declarado antes de ejecutar (LINEO §7):** 1 h 30 min, 1 hilo, 8 GiB de RAM.
Si se agota: checkpoint y estado **inconcluso**.

## B.0. Comprobación de la entrada congelada

`cd /home/katana/zeo/ZEROX && LC_ALL=C sha256sum -c P-ZRX/P-DAG/ENTRADA-T04-B.sha256` — **al
empezar**: 4/4 `OK` (ORDEN-T04-B, FORMATO-v0, CONTRATO-ESTADO-DAG-v0, LINEO). Verificado.

## B.1. Falta de definición detectada antes de editar código

Ninguna de las siguientes impide continuar: en todas se adopta la lectura forzada por una regla
superior (FORMATO v0.1 F-15, contrato DAG §3) o la convención ya fijada por T01-D. Se registran
**antes** de tocar código.

- **AMBIGUEDAD-B1 — posición del campo `nonce=` en las líneas `TX` de T04.** La orden no fija dónde
  va. Lectura adoptada: **al final de la línea** (`… sal=[…] nonce=<u64>`), siguiendo T01-D
  (D/AMBIGUEDAD-6). No altera ninguna regla.
- **AMBIGUEDAD-B2 — contenido y posición del `nonce=` en las líneas `GAR`.** La orden solo dice «en
  `GAR`». Lectura adoptada: **`nonce=<nonce_siguiente[clave]>` al final de la línea** (tras
  `congelado=`), que es el estado que hace única cada operación de la clave (F-15) y lo que el
  undo debe restaurar. No altera ninguna regla.
- **AMBIGUEDAD-B3 — número de casos de `vectores-estado-dag-v0.1.txt`.** No se fija. Lectura
  adoptada: **conservar el muestreo de v0 (900 aleatorios) más los 11 dirigidos** (los 8 de T04 y
  los 3 nuevos), = 911 casos, para que la diferencia con v0 sea exactamente el formato `nonce=` y
  los casos nuevos. Se documenta el recuento.
- **AMBIGUEDAD-B4 — ¿cambia el código de fusión?** F-15 exige descartar con `ErrNonce` en modo
  fusión. La tabla §3 del contrato ya manda descartar toda transacción que no valida, y
  `comprobar_nonce!` de T01-D va **primero** en depósito/retiro/liberación. Lectura adoptada: **el
  modo fusión genérico ya cumple F-15; no se toca `aplicar_bloque_fusion!`** (solo se añaden casos
  dirigidos, exportación y relectura). Motivo: cambiar la semántica de T04 iría contra la decisión 1
  de la orden.
- **AMBIGUEDAD-B5 — escenario exacto de «repetición tras una reorganización».** No se fija.
  Lectura adoptada: **el mismo retiro firmado (mismo `txid`, mismo nonce `n`) en dos ramas
  hermanas**; se reorganiza a la rama que lo contiene, se comprueba que el efecto aparece **una sola
  vez** y que `nonce_siguiente` avanza **una sola vez** (undo exacto por copia restaura el nonce), y
  se reorganiza de vuelta. No altera ninguna regla.

**Conclusión:** ninguna ambigüedad obliga a elegir entre reglas incompatibles; se aplican las
lecturas anteriores y se continúa.

## B.2. Diario de ejecución

- *Lectura íntegra* de `ORDEN-T04-B`, la «Corrección v0.1» de `FORMATO-v0` (F-15…F-18),
  `CONTRATO-ESTADO-DAG-v0` (+ ratificaciones v0.1), `LINEO` y el oráculo T01-D
  (`Transicion.jl`, `nonce_de`, `comprobar_nonce!`, extensión v2 con `nonce u64`).
- *Entrada congelada* verificada al empezar (4/4 OK).
- *Sin cambios de semántica:* `aplicar_bloque_fusion!` ya descarta con `ErrNonce` porque T01-D
  comprueba el nonce antes del resto y el modo fusión descarta cualquier `Err` sin tocar el estado
  (AMBIGUEDAD-B4). No se editó nada de T01.
- *Casos dirigidos D-9…D-11* añadidos en `src/dirigidos.jl` y probados (`test/runtests.jl` y
  `run.jl`).
- *Exportador v0.1:* `tx_str` añade `nonce=` al final en depósito/retiro/liberación; `gar_str` añade
  `nonce=<nonce_siguiente>`; salida por defecto `vectores-estado-dag-v0.1.txt`; `.sha256` en formato
  `sha256sum` (`<hash>  <ruta>`). Los ficheros v0 quedan intactos.
- *Lector independiente* actualizado para releer `nonce=` y `GAR … nonce=`; salida por defecto v0.1.
- *Vectores:* 911 casos exportados (`--dirigidos 1 --aleatorios 900`) y releídos de forma
  independiente: **0 discrepancias**. 737 descartes `ErrNonce` en los vectores.
- *Batería completa* `run.jl --seed 0x5a5a --replicas 200`: 3000 historias, 25380 bloques, 16020
  válidos, 3721 descartes, 1393 `rojo_U3`, 673650 órdenes IE-3, **0 fallos** (11 dirigidos, D-1…D-11),
  46,7 s. Estado **SUPERADO**. Registro en `resultados/run-estado-dag-v0.1.log`; el
  `resultados/run-estado-dag.log` por defecto quedó con esta corrida (los **vectores** v0 sí se
  conservan intactos).
- *Tests* `Pkg.test()`: **377/377 OK** (8,3 s), incluida la relectura de v0.1 (911 casos, 0
  discrepancias).
- *Cierre*: `INFORME.md` §T04-B, `HORAS.log`; entrada congelada re-verificada al terminar.

## B.3. Estado final T04-B

**SUPERADO.** Entregables completos en `T04/`. `vectores-estado-dag-v0.1.txt` (911 casos) +
`.sha256` en formato `sha256sum`; relectura independiente con 0 discrepancias; `run.jl --replicas
200` y `Pkg.test()` en verde. Nada escrito fuera de `T04/`; sin commit ni push; sin Python; sin
secretos. Las 5 ambigüedades de T04-B quedan documentadas con su lectura adoptada.

---

# T04-C — Generador con nonce correcto, retiros y liberaciones; vectores v0.2

**Ejecutor:** DeepSeek `deepseek-flash` (esfuerzo `high`). **Zona única escribible:** `T04/`.
**Presupuesto declarado antes de ejecutar (LINEO §7):** 1 h 30 min, 1 hilo, 8 GiB de RAM.
Si se agota: checkpoint y estado **inconcluso**.

## C.0. Comprobación de la entrada congelada

`cd /home/katana/zeo/ZEROX && LC_ALL=C sha256sum -c P-ZRX/P-DAG/ENTRADA-T04-C.sha256` — **al
empezar**: 5/5 `OK` (ORDEN-T04-C, REVISION-T04-B, CONTRATO-ESTADO-DAG-v0, FORMATO-v0, LINEO).

## C.1. Falta de definición detectada antes de editar código

Ninguna impide continuar: todas se resuelven con RD-4 del contrato o con una lectura que no altera
ninguna regla. Se registran **antes** de tocar código.

- **AMBIGUEDAD-C1 — alcance de «construidas» en la tabla de cobertura.** La orden pide, por tipo,
  «construidas, aplicadas en `Estado` de la punta seleccionada final y descartadas por motivo».
  Lectura adoptada: se publican **dos** cifras de construcción — `generadas` (todas las operaciones
  en bloques PoST, salida bruta del generador) y `construidas` (las que llegan al orden de
  aplicación seleccionado final, de modo que `construidas = aplicadas + descartadas`). El tope del
  25 % de `ErrNonce` usa `construidas` (denominador estricto: solo lo evaluado en el estado final).
  Se publican ambas para que la lectura sea inequívoca. No altera ninguna regla.
- **AMBIGUEDAD-C2 — clave elegida en retiro y liberación.** La orden no la fija. Lectura adoptada:
  **uniforme entre las claves factibles** (retiro: `activo > 0` y `en_retirada` vacío; liberación:
  `vencido > 0` calculado en el `slot` del bloque nuevo con la regla de `aplicar_liberacion!`). El
  depósito sigue usando el dueño de la salida gastada. No altera ninguna regla.
- **AMBIGUEDAD-C3 — número de operaciones por bloque.** La orden habla de «tipo elegido» (singular)
  entre los factibles. Lectura adoptada: **una operación opcional por bloque** (como en T04-B), más
  la coinbase. Palancas para los mínimos: `npost ≤ 16` y los pesos de partida. No altera ninguna
  regla.
- **AMBIGUEDAD-C4 — «reorganizaciones que deshacen al menos una operación de garantía aplicada».**
  No está definida operativamente. Lectura adoptada: se **reprocesan** los bloques generados en
  orden de `id` (que es el orden de generación, topológico por construcción) sobre una `Admision`
  nueva; tras cada bloque se calcula la punta seleccionada (`mejor_punta`) y el conjunto de
  operaciones de garantía aplicadas en su `Estado` (`aplicar_historia`); se cuenta **una**
  reorganización cuando cambia la punta y alguna operación antes aplicada deja de estarlo. No altera
  ninguna regla.
- **AMBIGUEDAD-C5 — D-13 y el punto de aplicación.** La orden pide documentar las dos vistas y
  parar si el contrato admite dos lecturas. Análisis: RD-4 fija unívocamente que un bloque de lado
  fusionado se aplica en el slot del fusionador y un bloque de cadena en su propio slot; por tanto
  **no hay dos lecturas**: en `Estado(past(X))` (vista de X, slot `s`) la liberación inmadura se
  descarta (`ErrSaldo`) y en `Estado(past(Y))` (punto `slot(Y) ≥ inicio + R_slots`) se aplica. Se
  documenta el resultado exacto y se continúa (no se para).
- **AMBIGUEDAD-C6 — escritor del fichero de cobertura.** La orden exige un único
  `resultados/cobertura-v0.2.txt` con dos apartados. Lectura adoptada: `exportar.jl` escribe el
  fichero completo (apartado vectores con los casos que él mismo genera, apartado `run.jl`
  recalculado con la semilla y réplicas por defecto de `run.jl`), y `run.jl` acumula y registra su
  propia cobertura en su log. No altera ninguna regla.
- **AMBIGUEDAD-C7 — muestreo de `npost` en los vectores y en `run.jl`.** La orden permite subir
  `npost` hasta 16. Lectura adoptada: se parte del muestreo vigente y solo se sube si un mínimo no se
  alcanza; el valor finalmente usado queda declarado en `INFORME.md`. No altera ninguna regla.

**Conclusión:** ninguna ambigüedad obliga a elegir entre reglas incompatibles; se aplican las
lecturas anteriores y se continúa.


## C.2. Diario de ejecución

- *Lectura íntegra* de `ORDEN-T04-C`, `REVISION-T04-B`, `CONTRATO-ESTADO-DAG-v0` (RD-1…RD-10),
  `FORMATO-v0` (F-15…F-18), `LINEO` y el oráculo T01 (`Transicion.jl`: `tx_retiro`,
  `tx_liberacion`, `nonce_de`, `comprobar_nonce!`, `aplicar_liberacion!`, `gastable`).
- *Entrada congelada* verificada al empezar (5/5 `OK`, `ENTRADA-T04-C.sha256`).
- *Semántica intacta:* no se tocó T01 ni la lógica de `src/EstadoDAG.jl`; solo `src/generadores.jl`,
  `src/dirigidos.jl`, `exportar.jl`, `run.jl`, `src/lector_vectores.jl` y `test/`.
- *Generador corregido* (`src/generadores.jl`): el tipo se elige entre los **factibles** en
  `S = A.post[pv]` (transferencia/depósito con salida gastable; retiro con `activo > 0` y sin
  retirada en curso; liberación con `vencido > 0` en el `slot` del bloque nuevo), el importe es
  uniforme (depósito = valor de la salida; retiro `1:activo`; liberación `1:vencido`) y el nonce es
  `nonce_de(S, clave)` con un 10 % de error deliberado. El prefijo PoW ya deposita para las claves
  1 y 2, de modo que el bug de `nonce = 0` queda eliminado.
- *Pesos:* los de partida (0,35/0,30/0,20/0,15) daban 99 liberaciones aplicadas en los 900 casos
  (una por debajo del mínimo). Se ajustaron a **0,12/0,18/0,22/0,48** y `npost ∈ {15,16}`
  (`npost_t04c(r) = 15 + r % 2`), con lo que todos los mínimos se superan con holgura. El generador
  sigue eligiendo **solo entre los tipos factibles** (el sesgo no inventa factibilidad).
- *Cobertura* (`EstadoDAG.AcumuladorCobertura`, `acumular_caso!`, `reorgs_que_deshacen_garantia`,
  `escribir_cobertura`): una operación es `construida` si el generador la produjo; `aplicada`/
  `descartada` se miden en `Estado` de la punta seleccionada final (`aplicar_historia`); una
  reorganización que deshace garantía se cuenta reprocesando los bloques en orden de `id` y
  comparando, tras cada punta nueva, las operaciones de garantía aplicadas.
- *Casos dirigidos nuevos* D-12 (retiro + liberación + transferencia bajo reorganización y vuelta) y
  D-13 (liberación inmadura en su slot que madura en el de su fusionador, RD-4), con `descX` =
  `ErrSaldo` y la salida creada en `creado_en_slot = slot(Y)`.
- *Vectores v0.2:* `resultados/vectores-estado-dag-v0.2.txt` = **913 casos** (13 dirigidos + 900
  aleatorios), 4,87 MB; `.sha256` en formato `sha256sum` (ruta relativa a `T04/`), hash
  `ee783b524c7fcac929fdd3859803205e046c3bab678efed69c5e603d2a94dd73`. Relectura independiente
  (`src/lector_vectores.jl`): **913 casos, 0 discrepancias**. v0 y v0.1 quedan intactos (hashes
  verificados).
- *Cobertura v0.2* (`resultados/cobertura-v0.2.txt`, generada por `exportar.jl`): apartado vectores
  con 900 casos y apartado `run.jl` con 3000; **todos los mínimos de §3 se cumplen**:
  depósitos aplicados 349, retiros 808, liberaciones 115, `ErrNonce` 853 = 18,29 % de las garantías
  construidas, `ErrDobleGasto` 316, reorganizaciones que deshacen garantía 312.
- *Batería completa* `run.jl --seed 0x5a5a --replicas 200`: 13 dirigidos sin fallos, 3000 historias,
  46 500 bloques, 25 192 válidos, 4 536 descartes, 2 078 `rojo_U3`, 600 000 órdenes IE-3,
  **0 fallos**, 58,8 s. Registro en `resultados/run-estado-dag-v0.2.log`; los logs v0 y v0.1 no se
  sobrescriben.
- *Tests* `Pkg.test()`: **372/372 OK** (9,0 s), incluida la relectura de v0.2 (913 casos, 0
  discrepancias) y la cobertura mínima del generador. Registro en
  `resultados/test-pkg-v0.2.log`.

## C.3. Estado final T04-C

**SUPERADO.** El generador construye depósitos, retiros y liberaciones con el nonce del estado
contra el que construye (y un 10 % de nonce erróneo controlado); los vectores v0.2 superan todos los
mínimos de cobertura de §3; IE-1…IE-6 siguen sin fallos en 3000 historias; D-12 y D-13 documentan
la reorg con undo de garantía y el punto de aplicación de RD-4. Nada escrito fuera de `T04/`; sin
commit ni push; sin Python; sin secretos. Las 7 ambigüedades de T04-C quedan documentadas con su
lectura adoptada.

---

# T04-D — Id de la salida de la liberación como en F-18; vectores v0.3 y caso D-14

**Ejecutor:** DeepSeek `deepseek-flash` (esfuerzo `high`). **Zona única escribible:** `T04/`.
**Presupuesto declarado antes de ejecutar (LINEO §7):** 1 h 30 min, 1 hilo, 8 GiB de RAM.
Si se agota: checkpoint y estado **inconcluso**. Prohibido Python. La parte T01-E ya está hecha y
revisada (`P-ZRX/P-TRANSICION/REVISION-T01-E.md`); esta corrida ejecuta solo T04-D.

## D.0. Comprobación de la entrada congelada (inicio)

`cd /home/katana/zeo/ZEROX && LC_ALL=C sha256sum -c P-ZRX/P-TRANSICION/ENTRADA-T01E-T04D.sha256` —
**al empezar**: 5/5 `OK` (ORDEN-T01E-T04D, REVISION-W06a, FORMATO-v0, CONTRATO-ESTADO-DAG-v0,
LINEO).

## D.1. Falta de definición detectada ANTES de editar

Ninguna impide continuar; todas se resuelven con una lectura que no altera ninguna regla. Se
registran **antes** de tocar código y se aplican.

- **AMBIGUEDAD-D1 — alcance del enunciado de D-14.** La orden dice «una transferencia que gasta la
  salida de una de ellas» y, a la vez, «la transferencia se aplica o se descarta según exista su
  salida». Lectura adoptada: se construyen **dos** hijos, uno por rama (`Xb` hijo de `Xa` gasta
  `ID_LIB(1,n,a)`; `Xd` hijo de `Xc` gasta `ID_LIB(1,n,b)`), de modo que el caso documenta las dos
  ramas del enunciado (aplica / se descarta). No altera ninguna regla.
- **AMBIGUEDAD-D2 — método de recuento del artefacto en los vectores v0.2.** La orden no lo fija.
  Lectura adoptada: relectura con un oráculo **instrumentado** que cuenta las colisiones de una
  salida de transferencia con una entrada ya existente de origen `OrigenLiberacion`; se usa una
  copia de solo lectura del T01 con `prox_salida` (el que exportó v0.2) y una del T01 actual, ambas
  en `analisis-artefacto/`. El recuento queda validado porque la copia vieja reproduce el `DESC` de
  v0.2 con **0 discrepancias**. No altera ninguna regla ni ningún fichero de T01.
- **AMBIGUEDAD-D3 — ¿v0.3 debe ser idéntico a v0.2 salvo los ids?** La orden no lo exige. El
  generador consulta `S.utxo` (orden de iteración de `Dict`) al elegir la salida gastada, así que el
  cambio de ids puede variar unas pocas historias aleatorias. Se acepta: los mínimos de §3 se
  recalcularon sobre v0.3 y se cumplen. No altera ninguna regla.

**Conclusión:** ninguna ambigüedad obliga a elegir entre reglas incompatibles; se aplican las
lecturas anteriores y se continúa.

## D.2. Diario de ejecución

- *Lectura íntegra* de `ORDEN-T01E-T04D`, `REVISION-W06a`, `REVISION-T01-E`, la sección T01-E.7 de
  `P-TRANSICION/T01/PROGRESO.md`, `LINEO`, `FORMATO-v0` (F-18), `CONTRATO-ESTADO-DAG-v0` y todo el
  código de `T04/`.
- *Semántica intacta:* no se tocó `P-ZRX/P-TRANSICION/T01/` ni la lógica de `src/EstadoDAG.jl`; el
  generador no cambia (la decisión 1 ya se aplicó en T01). Solo se editaron `src/dirigidos.jl`
  (D-14), `src/lector_vectores.jl` (ruta v0.3), un docstring de `src/generadores.jl`, `exportar.jl`,
  `run.jl` y `test/runtests.jl`.
- *D-14* (`caso_dos_liberaciones_hermanas`): `W` retira 3 de la clave 1 en el slot 2; `Xa` (sd=0) y
  `Xc` (sd=1) liberan importes `a=1` y `b=2` con el mismo nonce `n1=2`; `Xb` (hijo de `Xa`) gasta
  `ID_LIB(1,n1,1)=4611687117941112833` y `Xd` (hijo de `Xc`) gasta `ID_LIB(1,n1,2)=4611687117941112834`;
  `B` (slot 4) fusiona `[Xb,Xd]`. Medido en `Estado(past(B))`: `Xc` se descarta con `ErrNonce`
  (`e14[1]=(7,2,ErrNonce)`), `Xd` se descarta con `ErrDobleGasto` por entrada ausente
  (`g14[1]=(9,2,ErrDobleGasto)`), la salida 9701 de `Xb` existe, la 9702 no, `nonce_siguiente=3` y
  `B` válido. Nunca hay colisión de ids: los dos `ID_LIB` son distintos.
- *Vectores v0.3:* `resultados/vectores-estado-dag-v0.3.txt` = **914 casos** (14 dirigidos + 900
  aleatorios), 4 872 956 bytes; `.sha256` en formato `sha256sum` (ruta relativa a `T04/`), hash
  `016ad975cddea854349ef57241acbeb2f6b84f45d1035c765f245d54c9c748e1`. Relectura independiente
  (`src/lector_vectores.jl`): **914 casos, 0 discrepancias**. v0, v0.1 y v0.2 quedan intactos
  (hashes verificados).
- *Artefacto de ids (decisión 3):* recuento instrumentado (`analisis-artefacto/`, log
  `resultados/artefacto-v0.2-v0.3.log`). En **v0.2**: **16** transferencias descartadas por colisión
  de su salida con una liberación, de **219** `ErrDobleGasto` en transferencia (el resto, genuinos).
  En **v0.3**: **0** colisiones, con **207** `ErrDobleGasto` en transferencia (todos genuinos). La
  relectura del oráculo viejo reproduce el `DESC` de v0.2 con 0 discrepancias y la del actual el de
  v0.3 con 0 discrepancias.
- *Cobertura v0.3* (`resultados/cobertura-v0.3.txt`): **todos los mínimos de §3 se cumplen**:
  depósitos aplicados 347 (≥150), retiros 808 (≥100), liberaciones 115 (≥100), `ErrNonce` 853 =
  18,29 % de las garantías construidas (≥30 y ≤25 %), `ErrDobleGasto` 305 (≥200) y
  reorganizaciones que deshacen garantía 312 (≥20).
- *Batería completa* `run.jl --seed 0x5a5a --replicas 200`: 14 dirigidos sin fallos (D-1…D-14),
  3000 historias, 46 500 bloques, 25 192 válidos, 4 497 descartes, 2 078 `rojo_U3`, 600 000 órdenes
  IE-3, **0 fallos**, 58,0 s. Registro en `resultados/run-estado-dag-v0.3.log`; los logs v0, v0.1 y
  v0.2 no se sobrescriben.
- *Tests* `Pkg.test()`: **386/386 OK** (9,1 s), incluida la relectura de v0.3 (914 casos, 0
  discrepancias) y los 14 asserts de D-14. Registro en `resultados/test-pkg-v0.3.log`.

## D.3. Estado final T04-D

**SUPERADO.** La salida de la liberación recibe un id inyectivo del contenido (T01-E); los vectores
v0.3 (914 casos) se releen sin discrepancias y cumplen los mínimos de T04-C; los 16 descartes de
v0.2 por colisión de ids son 0 en v0.3; D-14 documenta que, al fusionar dos liberaciones hermanas
con el mismo nonce, una cae por `ErrNonce` y la transferencia de la otra rama cae por entrada
ausente, nunca por colisión. Nada escrito fuera de `T04/`; sin commit ni push; sin Python; sin
secretos. Las 3 ambigüedades de T04-D quedan documentadas con su lectura adoptada.

---

# SL-3 — Evidencia y castigo en el DAG (T04)

**Ejecutor:** DeepSeek `deepseek-flash` (esfuerzo `high`). **Zona escribible:** `T04/`.
**Presupuesto declarado antes de ejecutar (LINEO §7):** se comparte el de la orden SL-3
(2 h de reloj, 1 hilo, 8 GiB). Prohibido Python.

## SL3.0. Comprobación de la entrada congelada (inicio)

`cd /home/katana/zeo/ZEROX && LC_ALL=C sha256sum -c P-ZRX/P-SLASHING/ENTRADA-SL3.sha256` —
**al empezar**: 6/6 `OK`.

## SL3.1. Falta de definición detectada ANTES de editar

Además de las de T01 (`P-TRANSICION/T01/PROGRESO.md` §SL3.1, que se heredan), las propias
de T04:

- **AMBIGUEDAD-SL3-D1 — deduplicación en modo fusión (EV-12).** En T01 una evidencia
  duplicada es un `Err` que invalida el bloque (cadena). En T04, por ED-6/C-ORD-04, una
  transacción que no valida al fusionarse **se descarta** sin invalidar el bloque.
  Lectura adoptada: `aplicar_bloque_fusion!` ya captura el `Err` de `aplicar_tx!` y lo
  añade a `descartes`; una segunda `EvidenceTx` del mismo incidente devuelve
  `ErrEvidenciaDuplicada` y queda registrada como descarte, sin congelar ni confiscar y
  sin invalidar el bloque.
- **AMBIGUEDAD-SL3-D2 — efecto de la evidencia según el punto de aplicación (RD-4).**
  El contrato exige que la evidencia siga el punto de aplicación. Lectura adoptada: la
  ventana de admisión y la madurez del crédito de la recompensa usan el `punto` de
  fusión que recibe `aplicar_tx!` (slot del bloque de cadena que fusiona, RD-4); el
  registro en `incidentes_procesados` y el gravamen viven en el `Estado` y por tanto el
  undo exacto por copia íntegra (EV-27) los revierte con el bloque.
- **AMBIGUEDAD-SL3-D3 — dos evidencias hermanas del mismo incidente.** El caso dirigido
  lo exige. Lectura adoptada: cada rama se evalúa en su `Estado(past)`, de modo que la
  primera que se aplique en la cadena seleccionada registra el incidente y la otra, al
  fusionarse, devuelve `ErrEvidenciaDuplicada` (descarte).
- **AMBIGUEDAD-SL3-D4 — `cbid` de la red local en el DAG.** El `cbid` es un campo de
  `Params` (compartido por todos los bloques del oráculo); se fija el mismo en toda la
  rejilla T04 y la evidencia con `cbid` ajeno se descarta con `ErrCbidAjeno`.

**Conclusión:** ninguna ambigüedad obliga a elegir entre reglas incompatibles.

## SL3.2. Diario de ejecución

- **19:0x** inicio; entrada congelada 6/6 OK; `HORAS.log` con `date -Is`.
- *Código T04*: `aplicar_bloque_fusion!` poda incidentes (EV-11) y actualiza
  `ultimo_slot_producido` (EV-24(ii)); `PARAMS_DAG_EV` (8 puntos con `cbid=7`, `evp=true`,
  `f ∈ {1/2,1}`, `Plazo ∈ {2,3}`); `evidencia_aleatoria` y duplicados en
  `generar_dag_aleatorio`; dirigidos D-15…D-18 en `src/dirigidos.jl`; `exportar.jl` a v0.4 con
  cobertura de evidencia; `src/lector_vectores.jl` con `ev=`/`inc=`; `run.jl` con la rejilla
  C-EVP y las assertions D-15…D-18; testset «SL-3 evidencia (T04)».
- *Tests*: `Pkg.test()` **421/421**, incluida la relectura de v0.4 (1 878 casos, 0
  discrepancias). Registro `resultados/test-pkg-v0.4.log`.
- *run.jl* `--seed 0x5a5a --replicas 200`: 3 000 historias base (46 500 bloques, 600 000
  órdenes IE-3) + 1 600 con C-EVP (13 181 válidos, 3 181 descartes, 60 duplicadas, 466
  tardías, 216 `cbid` ajeno), **0 fallos**, 70,8 s, `ESTADO = SUPERADO`. Registro
  `resultados/run-estado-dag-v0.4.log`.
- *Vectores v0.4*: **1 878 casos**, sha256
  `37c04f1250775f25ea4a2cab355f9201c7454b4ba06fa6d892d3b83fe924ebff`; relectura independiente
  **0 discrepancias**; v0.3 intacto y releído con 0 discrepancias. Cobertura de evidencia:
  aplicada 307, duplicada 30, tardía 297, `cbid` 137, deshecha 771.
- **Cierre T04: SUPERADO.** Nada escrito fuera de `T04/`; sin commit ni push; sin Python.
