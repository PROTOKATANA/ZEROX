# Verificación matemática de Orchard con parámetros de ZEROX · D9 en Opus, 2026-09-04

> Verificado contra `zcash/zips@main protocol/protocol.tex` (fuente LaTeX descargada) y
> `zcash/orchard@main` (`value.rs`, `nullifier.rs`, `spec.rs`, `keys.rs`). Script de verificación
> numérica en `/tmp/.../scratchpad/verify.py`. Responde a las lagunas dejadas por D1 en
> `orchard-bundle.md` §6 y "Lagunas".

## Tarea 1 · No-overflow de la binding signature — SE SOSTIENE (174 bits de margen)

**Hallazgo clave: el acotamiento NO depende de `MAX_MONEY` ni del tamaño de bloque.** Sale de que
el circuito hace range-check a **64 bits** (`ℓ_value = 64`, constante del circuito Halo2, no un
parámetro de ZEROX) y de `nActionsOrchard < 2^16`. Con eso:

```
v* ∈ [ −n·(2^64−1) − 2^63 + 1 ,  n·(2^64−1) + 2^63 ]     con n < 2^16
|v*|max = 2^79 bits   vs   (r_P−1)/2 = 2^253 bits   →  174 bits de holgura
```

Verificado numéricamente: `n` podría llegar hasta **~2^189** sin wraparound — incluso un
`CompactSize` de 64 bits sin ninguna regla de consenso (`n < 2^64`) queda 126 bits por debajo
del límite. El `MAX_MONEY`/soft cap de ZEROX (21M ZZK, igual que Zcash en unidades atómicas) es
**8 784× menor** que el rango que el circuito admite por acción — el circuito nunca se acerca al
límite pase lo que pase con la economía de ZEROX.

> **Nota 2026-09-04:** el soft cap pasó a **1000 M ZZK** (P-002). El factor de holgura citado baja
> de 8 784× a **184×**, pero **la cota no cambia**: depende de `n < 2¹⁶` y del rango `u64` por
> valor, no del soft cap. Los 174 bits de holgura se mantienen intactos.

**3 reglas que deben entrar al SPEC de la Fase 6 para que el argumento se sostenga:**
1. `nActionsOrchard < 2^16`, verificado en el parser **antes** de verificar prueba y binding sig, con **rechazo** (no saturar, no panic). En Zcash es "técnicamente redundante" por su límite de 2 MB de bloque; **en ZEROX, mientras no exista un límite de tamaño de bloque, esta regla es la ÚNICA que cierra el argumento — deja de ser redundante, pasa a ser load-bearing.**
2. La suma `Σv_net_i` y la negación de `valueBalance` en **i128** (o `checked_*` en i64) — `-(-2^63)` desborda en i64 puro. El crate `orchard` ya lo hace bien (`ValueSum(i128)`); el código propio de ZEROX que reimplemente el turnstile transparente↔blindado, no necesariamente.
3. El acumulador del **turnstile de cadena** (agregado sobre toda la historia, no por-tx) necesita su **propia** derivación de no-overflow — la binding sig solo acota por transacción. Zcash lo cubre con *"Orchard chain value pool balance MUST NOT become negative"*. **Encargo aparte pendiente**, no cubierto por esta verificación.

### ⚠️ Dos huecos reales nuevos, confirmados por grep en DECISIONES.md

**L-1 · ZEROX no tiene límite de tamaño de bloque.** No bloquea esta propiedad matemática (se sostiene igual), pero **sí bloquea** la política anti-DoS, la regla de fee, el presupuesto de bloque, y la tasa de huérfanos (que depende de `t_propagación/t_bloque`, y el tamaño de bloque determina la propagación). Sin límite, con solo `n<2^16`, **una tx legal puede pesar 207 MB** (65535 acciones × 3156 B). → **Nueva pregunta P-009.**

**L-2 · ZEROX no tiene `MAX_MONEY` — y estructuralmente no puede tener uno fijo.** La tail emission (§7) hace el suministro **no acotado** (simulado: a 701.000 años del inicio de la cola, el suministro seguiría creciendo por debajo de `i64::MAX`). Zcash usa `MAX_MONEY` en dos reglas que ZEROX no puede copiar literalmente: `valueBalance ∈ [−MAX_MONEY, MAX_MONEY]` y `suministro total MUST NOT exceder MAX_MONEY`. **ZEROX necesita una constante `ZX_VALUE_SANITY_LIMIT` desacoplada de la emisión** (p.ej. `2^62` brek, con margen de sobra). → **Nueva pregunta P-010.**

**L-3 (menor, ya corregido)**: `DECISIONES.md §7` decía que el tail "arranca hacia el año ~10–11". La simulación da dos eventos distintos: la fórmula cae por debajo del tail en el **año 8,74** (h=2.298.154); el suministro **cruza los 21M** en el año **10,73**. Corregido en `DECISIONES.md`.

## Tarea 2 · Nullifier — SE SOSTIENE, con una respuesta importante

**Respuesta directa a la pregunta abierta de D1**: la unicidad del nullifier **NO viene de un valor
aleatorio fresco — viene de un encadenamiento determinista**: `ρ_new = nf_old` (el nullifier de la
nota gastada en la misma acción). Cita del spec: *"esto asegura, sin ningún supuesto criptográfico,
que todos los valores ρ de las notas añadidas al árbol son únicos"*. La aleatoriedad (`ψ`) es
defensa en profundidad, no la fuente primaria de unicidad.

**Único punto genuinamente probabilístico**: el `ρ` de una nota *dummy* gastada se muestrea al
azar (no hay nota padre). Colisión despreciable (`P < 3×10⁻⁵⁸` incluso con 4.300 millones de
nullifiers) — pero **depende de la calidad del RNG del wallet emisor**, no está reducido a ningún
problema criptográfico.

**Hallazgo más importante para la disciplina "adoptar, no reescribir":** el spec dice literalmente
que la **canonicidad de la descomposición del escalar dentro del circuito** *"MUST be checked to
avoid a potential double-spend vulnerability"* — es decir, **reimplementar mal ese detalle del
gadget es exactamente cómo se produce un doble gasto real.** Con `orchard = "=0.15.5"` sin tocar,
sale gratis. Confirma con la máxima concreción posible por qué el crate no se toca.

**2 huecos para el SPEC de la Fase 6:**
1. Falta la regla explícita: *"un nullifier Orchard MUST NOT repetirse NI DENTRO DE UNA TRANSACCIÓN
   ni entre transacciones de una cadena válida"* — hoy `DECISIONES.md §3.3` solo implica la parte
   "entre transacciones" (vía "nullifier set"). Sin la parte "dentro de la tx", la cadena de
   razonamiento que garantiza ρ únicos se rompe.
2. Dos supuestos criptográficos nuevos sin declarar: PRF-idad y resistencia a colisiones de
   `PoseidonHash` (P128Pow5T3) sobre el campo base de Pallas — la inyectividad respecto a la clave
   de gasto (`nk`) descansa enteramente en esto.

## Conclusión general

Ninguno de los dos hallazgos de D9 invalida ninguna decisión ya tomada. Ambas propiedades se
sostienen con margen amplio. Lo que aportan son: (a) dos parámetros que faltan y bloquean cerrar
partes del SPEC más adelante (tamaño de bloque, sanity limit de valor) — **no bloquean la Fase 0**,
y (b) reglas de consenso concretas y ya redactadas, listas para pegar en el SPEC de la Fase 6.
