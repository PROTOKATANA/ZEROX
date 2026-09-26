# Contrato de estado en el DAG PoST (v0)

**Estado:** propuesta del director, **no normativa**; rige la red dev de 0.0.1 y su oráculo.
**Fecha:** 2026-09-26. **Firma:** Claude. Complementa `P-ZRX/P-TRANSICION/CONTRATO-v0.md` (v0.1).

## 0. El hueco que cierra

El contrato de transición y su oráculo T01 modelan la fase PoST como una **cadena** (`k = 0`): cada
bloque se aplica sobre el estado de su padre. En el DAG real, según el orden antiguo `C-ORD-03`
(y `R-FIN-8′`, `research/dag-poas-ancla-de-orden.md` de `9681061`): un bloque PoST se **aplica
cuando lo fusiona** el primer bloque de la cadena seleccionada que lo incluye; una transacción que
no valida en ese orden **se descarta en silencio** sin invalidar el bloque (`C-ORD-04`); los azules
y los `rojo_k` cobran, los `rojo_U3` son inertes. Falta decir cómo interactúan con la garantía, la
coinbase atribuida y el corte. Sin esto, W06 tendría que inventarlo. **IPA B-11.**

## 1. Definiciones

- `sp(B)`, `mergeset(B)`, azul, `rojo_k`, `rojo_U3`, `blue_work`: los de `zx-dag` (W05a, GHOSTDAG con
  raíz en el terminal `T`, D-P07), con el mergeset en el orden `C-GD-05` (ascendente por
  `(blue_work, solution_distance, id)`).
- **Aplicar un bloque X** = aplicar su coinbase y sus transacciones con las reglas del contrato de
  transición (UTXO, garantías, madurez), **en modo fusión** (§3).
- **Punto de aplicación** de X = el slot del bloque de cadena `C` que lo fusiona (`C-BON-07`), no el
  slot de X. Madureces, retiros y créditos de X cuentan desde ese punto.

## 2. Estado de un bloque

**ED-1 · Estado de la fase PoW.** Igual que en el contrato de transición: cada bloque PoW se aplica
sobre su padre, en su propia altura. `Estado(T)` es el estado tras aplicar el terminal.

**ED-2 · Estado del pasado de un bloque PoST B.** `Estado(past(B))` se obtiene partiendo de
`Estado(past(sp(B)))` si `sp(B)` es PoST, o de `Estado(T)` si `sp(B) = T`; aplicando `sp(B)` si es
PoST; y aplicando después, en orden `C-GD-05`, cada bloque de `mergeset(B) \ {sp(B)}` que no sea
`rojo_U3`, todos en modo fusión con punto de aplicación `slot(B)`. (Es el «UTXO del pasado» de
Kaspa.) **B no se aplica en su propio estado.**

**ED-3 · Cadena seleccionada y estado virtual.** El estado de la red en un nodo es
`Estado(past(V))` del bloque virtual `V` cuyos padres son las puntas; la cadena seleccionada es la
de `sp` desde `V`. Una reorganización cambia la cadena y **recalcula** los estados afectados con
undo exacto (`C-REORG`), con la cota `C-FIN-01` en slots.

## 3. Qué invalida un bloque y qué solo se descarta

| Comprobación | Resultado si falla | Cuándo se evalúa |
|---|---|---|
| Forma de cabecera y de transacciones (FORMATO-v0 F-03…F-10) | **bloque inválido** | admisión |
| Padres (D-P08), PoT, sello, PoAS (puerta conjunta) | **bloque inválido** (o pendiente, si falta contexto) | admisión |
| Coinbase: primera transacción, única, v3, `clave = productor` (F-09, R-6) | **bloque inválido** | admisión |
| Garantía del productor `activo ≥ q` en `Estado(past(B))` al slot de B (`C-BON-04`, TRN-07) | **bloque inválido** | admisión (necesita `Estado(past(B))`) |
| Transacción que no valida al aplicarla en modo fusión (UTXO inexistente o gastado, inmadura, firma, saldo de garantía, liberación prematura, conflicto con otra ya aplicada) | **se descarta** la transacción; el bloque sigue siendo válido (`C-ORD-04`) | al fusionar |
| Importe de la coinbase PoST | se acredita `mín(importe declarado, subsidio_post(slot(B)) + tarifas aceptadas de B)`; el resto **no existe** (no se emite) | al fusionar |
| Bloque `rojo_U3` | inerte: ni coinbase ni transacciones | al fusionar |

**ED-4.** Una transacción descartada no cuenta para las tarifas de su bloque (`C-ORD-04`).
**ED-5.** Las transacciones de un mismo bloque se aplican en su orden; si una depende de otra
descartada, también se descarta.
**ED-6.** Las operaciones de garantía (depósito, retiro, liberación) siguen las reglas del contrato de
transición en el punto de aplicación; si fallan (p. ej. `ErrRetiroPendiente`, `ErrSaldo`), se
**descartan**, no invalidan el bloque.

## 4. Invariantes que el oráculo DAG debe demostrar

- **IE-1** Conservación (I-1 del contrato de transición) en todo `Estado(past(B))` y en el virtual.
- **IE-2** Cada bloque se aplica **una sola vez** en la historia de la cadena seleccionada.
- **IE-3** Determinismo: `Estado(past(B))` depende solo del conjunto de bloques de `past(B)`, no del
  orden de llegada.
- **IE-4** Undo exacto al reorganizar la cadena seleccionada.
- **IE-5** Con `k = 0` y sin fusiones, el resultado coincide con el oráculo T01 (compatibilidad).
- **IE-6** Complementariedad: los saldos de garantía no cambian `blue_work` ni la cadena seleccionada.

## 5. Pendiente y límites

- `merge_depth` y kosherización (`R-FIN-12`) no se fijan en v0: la red dev no fusiona bloques más
  profundos que `F_slots` (se rechazan como inválidos) — **decisión provisional dev**.
- La conversión del orden a «altura» no existe (IPA B-10).
- No se modela latencia ni red: eso es W07.

## 6. Órdenes que derivan

- **T04** (oráculo Julia del estado DAG): GHOSTDAG pequeño (reutilizando las reglas de `zx-dag` como
  especificación, o los vectores GDR para el orden) + ED-1…ED-6 + IE-1…IE-6, con vectores exportables.
- **W06a** (Rust): orquestación del estado DAG en `zx-consensus`/`zx-node` sobre el motor de W03 en
  «modo fusión», con diferencial contra T04.

---

## Ratificaciones v0.1 (2026-09-26, tras T04)

El oráculo T04 documentó diez ambigüedades antes de escribir código. El director las ratifica:

| ID | Regla ratificada | Origen |
|---|---|---|
| RD-1 | El importe máximo de la coinbase de un bloque fusionado usa `subsidio_post(slot(X))` (slot del propio bloque); madurez del crédito, inicio de retiros y vencimientos usan el punto de aplicación | T04 A-1 |
| RD-2 | La coinbase es **opcional** en un bloque PoST (el productor renuncia a ella); si existe, única y primera (R-6) | T04 A-2; compatible con T01 |
| RD-3 | Importe 0 en la coinbase PoST invalida el bloque (R-8); el recorte se aplica a todo importe positivo | T04 A-3 |
| RD-4 | **Punto de aplicación:** un bloque de la cadena seleccionada se aplica en **su propio slot**; un bloque fusionado de lado (mergeset sin el padre seleccionado), en el slot del bloque de cadena que lo fusiona. **Corrige** la letra de ED-2, que aplicaba también `sp(B)` en `slot(B)` y contradecía IE-5. Desviación declarada respecto a la letra de `C-BON-07` (que usa siempre el slot del fusionador): adelanta en un bloque la madurez de los bloques de cadena | T04 A-4 |
| RD-5 | `merge_depth` dev: B es inválido si fusiona un bloque no `rojo_U3` con `slot(B) − slot(X) > F_slots` | T04 A-5 |
| RD-6 | `slot(V) = máx(slot(puntas válidas))` | T04 A-6 |
| RD-7 | Dentro de un bloque se aplican primero las transacciones no-coinbase y después se materializa el crédito recortado de la coinbase (la posición en la lista sigue siendo la primera) | T04 A-7 |
| RD-8 | Las reglas estructurales heredadas del GHOSTDAG antiguo (`slot(sp) ≤ slot(B)`, máximo de padres, U2, U3″ dinámica) invalidan el bloque; en el oráculo, `max_parents = 3`; en la red dev, 15 | T04 A-8 |
| RD-9 | La garantía del productor se evalúa sobre `Estado(past(B))` tras promover en `slot(B)` | T04 A-9; TRN-07 |
| RD-10 | La garantía es comprobación de **admisión** de cada bloque en su propio pasado; no se vuelve a comprobar al fusionarlo | T04 A-10 |
