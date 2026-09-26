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

