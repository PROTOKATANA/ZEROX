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
