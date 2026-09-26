# METODO — T04 (oráculo de referencia del estado en el DAG PoST)

Método del oráculo Julia (CPU) del contrato `P-ZRX/P-DAG/CONTRATO-ESTADO-DAG-v0.md`, según
`ORDEN-T04.md`, aplicando `V-ZRX/LINEO.md`. Un hilo. Sin Python.

## 1. Qué se implementa

Un módulo Julia `EstadoDAG` (`src/EstadoDAG.jl`) que compone:

- **Fase PoW (ED-1):** el oráculo T01 (`P-ZRX/P-TRANSICION/T01/src/Transicion.jl`), usado como
  **dependencia de solo lectura vía `include`** (declaración exigida por la orden §3.2). No se
  modifica ningún fichero de T01; el submódulo se llama `EstadoDAG.Transicion`.
- **Orden GHOSTDAG (raíz = terminal, D-P07):** el oráculo antiguo GDR-v0.2, copiado **sin cambios de
  lógica** a `src/modelo.jl` y `src/referencia.jl` (sha256 en §7), envuelto en `src/GDR.jl`. El nodo 1
  de GDR es el terminal `T`; los bloques PoST son nodos ≥ 2. `Params`: `k ∈ {0,1,3}`,
  `max_parents = 3`, `mergeset_limit = 180`, `s_max = typemax`, `u2 = true`, `U3_DYNAMIC`,
  `SP_ZEROX` (regla C), `MERGE_SPEC`.
- **Reglas por bloque (`src/EstadoDAG.jl`):** `aplicar_fusion` con la tabla de §3 del contrato y
  `estado_past!` con ED-2; `Estado(past(B))`, `Estado(past(B)∪{B})`, virtual (`ED-3`) y undo exacto.

### Tipos

`BloquePost{id, padres, slot, sr, sd, ident, productor, peso, txs}`; `Admision` guarda el `Estado`
PoW `estado_T`, el `EstadoReferencia` de GDR, y por bloque: validez, motivo, `past`, `post`,
descartes. Los estados son `Transicion.Estado` (tipos concretos de T01).

## 2. Reglas implementadas (ED-1…ED-6, §3)

1. **Admisión / forma.** Padres: ≥1; el terminal `T` solo como padre único (D-P08); padres existentes
   y válidos (si no, `ErrSinPadre`); `slot ≥ 1`; coinbase única, primera y `CoinbasePost` (R-6),
   `importe > 0` (R-8). GDR valida U2 y la monotonía de slot.
2. **`Estado(past(B))` (ED-2).** Parte de `post[sp(B)]` (o `Estado(T)` si `sp(B)=T`) y aplica en
   orden C-GD-05 cada bloque de `mergeset(B)\{sp(B)}` no `rojo_U3`, en **modo fusión** con punto
   `slot(B)`. `B` no se aplica en su propio estado. `sp(B)` se aplica en **su propio** slot.
3. **Garantía del productor.** Sobre `Estado(past(B))` promovido en `slot(B)` (TRN-07/R-4):
   `activo ≥ q`; si no, **bloque inválido** (`ErrGarantia`). Es comprobación de admisión, no se
   re-comprueba al fusionar (AMBIGUEDAD-10).
4. **Modo fusión (§3, ED-4…ED-6).** Cada transacción no-coinbase se aplica sobre una copia del
   estado y, si falla, se **descarta** (no invalida el bloque) dejando el estado intacto; una
   transacción que depende de otra descartada también se descarta (al no existir su salida).
   `rojo_U3`: inerte (ni coinbase ni transacciones). `merge_depth`: `B` inválido si un bloque no-U3
   de su mergeset cumple `slot(B) − slot(X) > F_slots` (AMBIGUEDAD-5).
5. **Coinbase PoST.** Acredita `mín(declarado, subsidio_post(slot(X)) + tarifas aceptadas)`
   (AMBIGUEDAD-1) como **crédito pendiente** en `Garantía[productor]` (D-T08), con madurez
   `punto + M_rec_slots`; el resto no existe. `Emitido += crédito − tarifas`;
   `subsidio_acum += subsidio_post(slot(X))`. Con `ncb = 0` (AMBIGUEDAD-2), `Emitido += −tarifas`.
6. **Punto de aplicación (§1).** Madureces, inicio de retiro, vencimiento de liberación y madurez
   del crédito usan el punto de aplicación `punto` (slot del bloque de cadena que fusiona), no
   `slot(X)`. El importe del subsidio usa `slot(X)`.
7. **Virtual (ED-3).** V tiene por padres las puntas válidas; GDR colorea su mergeset completo
   (clonando el estado GDR y añadiendo un nodo virtual), y `Estado(past(V))` aplica el mergeset de V
   en orden C-GD-05, saltando `rojo_U3`, con `slot(V) = max slot(puntas)` (AMBIGUEDAD-6).
8. **Undo (IE-4).** Por copia íntegra (como T01, AMBIGUEDAD-12): `aplicar_fusion_con_undo` devuelve
   `(E′, E)` y `deshacer(E′, E) = E`.

## 3. Ambigüedades (registradas antes de editar; `PROGRESO.md` §1)

AMBIGUEDAD-1…10, con la lectura adoptada. Ninguna altera otra regla; no fue necesario parar.
Resumen: subsidio por `slot(X)` y resto por `punto`; coinbase ausente admitida; `importe 0` invalida
(R-8); `sp(B)` en su slot; `merge_depth = Δslot > F_slots`; `slot(V) = max slot(puntas)`; la
coinbase se materializa tras las demás transacciones (rejilla con `M_rec_slots ≥ 1`); las
comprobaciones de GDR son forma/padres; `requisito = q`; la garantía de un bloque fusionado no se
re-comprueba.

## 4. Rejilla declarada (ORDEN §3.4)

Subconjunto pequeño de la rejilla de T01 (`src/EstadoDAG.jl`, `PARAMS_DAG_BASE`): 5 puntos ×
`k ∈ {0,1,3}` = 15 puntos. Todos con `SEC0`, `CUT_HWPhi`, `FC3` y `M_rec_slots ≥ 1`. Los cinco
puntos varían `H_dep`, `M_cb`, `M_dep`, `H_corte_min`, `W_min`, `S_min`, `K_min`, `q`, `M_res_slots`,
`M_dep_slots`, `M_rec_slots`, `R_slots` y `F_slots ∈ {2, ∞}` (valores de prueba, no propuestos).

## 5. Revalidación de GDR-v0.2 (paso previo obligatorio)

`src/revalidacion_gdr.jl` reproduce, con `modelo.jl`+`referencia.jl` copiados y un lector propio:

- `testdata/ghostdag-rank-v1/corpus-rust.txt`: **28 DAGs, 2290 bloques, 0 discrepancias**
  (`sp`, `score`, `bw`, `ms`, `blues`, `reds`, `colores`, `rank` exactos).
- `testdata/kaspa/dag0..dag5.json` (fixtures extraídos de `9681061`): **84 bloques, 0 discrepancias**
  (`SP_KASPA`/`MERGE_KASPA`, `u2=false`, `U3_OFF`).

Como el corpus se reprodujo, se continuó (la orden obliga a parar solo si no se reproduce).

## 6. Casos dirigidos y propiedades

- **Dirigidos** (`src/dirigidos.jl`): D-1 doble gasto entre bloques fusionados (gana el primero en
  C-GD-05, el otro `ErrDobleGasto`); D-2 coinbase PoST recortada al descartar una tarifa (acredita
  `3+1=4`); D-3 depósito fusionado que habilita al productor 3 (`Z` válido, `W` `ErrGarantia`);
  D-4 garantía solo en rama no fusionada (`ErrGarantia`); D-5 `rojo_U3` inerte; D-6 bloque aplicado
  una sola vez alcanzado por dos cadenas; D-7 reorganización que cambia la punta seleccionada
  (`A2 → B3`) y recomputa el estado; D-8 dos hermanos PoST en el mismo slot.
- **IE-1/IE-2/IE-4** en `past`, `post` y virtual; **IE-3** reprocesando en órdenes de llegada
  arbitrarios; **IE-5** comparando cadenas sin fusiones con T01 (representación canónica idéntica);
  **IE-6** comparando la proyección GHOSTDAG de la misma estructura con y sin transacciones.

## 7. RNG, reproducibilidad y entradas

- Semilla maestra `0x5a5a` (argumento de `run.jl` y `exportar.jl`), `StableRNG(seed + id)` por
  réplica (LINEO §7). Sin RNG compartido.
- Huellas: `src/modelo.jl` = `7769415b…3a71b3`; `src/referencia.jl` = `51e39615…7c7080c`;
  `P-TRANSICION/T01/src/Transicion.jl` = `1206548c…aaef`; corpus = `dff05e21…f0a8`;
  `kaspa-rust.txt` = `1ab0a081…6922`; git HEAD = `8dbbd64a…d5f3`.
- Comandos exactos en `INFORME.md`. Sin commit ni push; nada escrito fuera de `T04/`.

## 8. Presupuesto y criterio

3 h de reloj, 1 hilo, 8 GiB de RAM, 2 GiB de disco. Estado **SUPERADO** si la revalidación GDR es
exacta, los dirigidos coinciden con lo construido a mano y no hay fallos en IE-1…IE-6; **REFUTADO**
si aparece un contraejemplo reproducible; **INCONCLUSO** si se agota el presupuesto o una ambigüedad
obliga a elegir entre reglas incompatibles (no ocurrió).

## 9. Límites declarados

El muestreo de IE-3 y el número de réplicas se declaran en `INFORME.md`. No se modelan criptografía,
PoT/PoAS, sello, red, latencia, ni PoW real.
