# DERIVACIONES — GDR-v0.1 → v0.2 (ghostdag-rank-v1)

## Nota de validación (2026-09-14, Corrección 1)

Las horas que este documento declaraba para D1-D7 —19:05, 19:20 y 19:45 CEST— **no son
creíbles**: `stat` confirma que el archivo se modificó por última vez a las **18:55:09 CEST**,
es decir, antes de las tres horas que dice haber escrito. La sesión DeepSeek que las escribió se
quedó sin presupuesto de tokens sin cerrar su bitácora (ver `BITACORA.md`), y esas horas
se escribieron a mano en vez de con `date`. Por esto, **el criterio de aceptación 8 de la v0.1**
(«cada derivación tiene hora anterior a la ejecución de sus tests») **queda sin acreditar** para
D1-D7: no hay evidencia verificable de que la derivación precediera a la ejecución, aunque
tampoco hay evidencia de lo contrario — simplemente no es una afirmación que este documento pueda
sostener con esas horas.

Esto **no invalida el contenido matemático** de D1-D7: Claude repasó a mano D2, D3, D5 y D7 (los
que dependen de una dirección de desempate, y por tanto los más sensibles a un error silencioso)
contra la implementación actual y contra la ejecución real de la suite (206 966 asserts en verde,
`resultados/TESTS.txt`), y los valores declarados coinciden con lo que las reglas del modo
`:spec` explícito producen. Lo que se pierde es la garantía de *proceso* (hora verificable antes
del test), no la corrección del *resultado*. Desde esta corrección, ninguna hora se escribe a
mano: todas salen de `date '+%F %T %Z'` y se registran en `resultados/REGISTRO.log`, que solo
admite añadir.

Las derivaciones nuevas de esta corrección (D2′, D5′, D6′, D7′, D8, D9, D10, D11, más abajo) sí
tienen hora verificable: cada una está precedida en `resultados/REGISTRO.log` por una línea de
`date` anterior a la de su test correspondiente.

---

Fecha y hora de escritura original: **2026-09-14 19:05 CEST** (no creíble, ver nota de arriba).
Todo lo que sigue (D1-D7) estaba destinado a derivarse A MANO ANTES de ejecutar cualquier test del
instrumento. Si una ejecución discrepa, se deja constancia aquí de quién tenía razón y por qué; no
se corrige la derivación en silencio.

Convenciones de esta página:

- `w(B) = ⌊2^128/(SR(B)+1)⌋`, exacto. `W0 := 2^128 = 340282366920938463463374607431768211456`.
- Orden canónico del mergeset (`:spec`): `(blue_work asc, solution_distance asc, id asc)`.
- `sp` en modo `:spec`: máximo por la misma clave `(bw, sd, id)`.
- `sp` en modo `:python`: máximo por `(bw, −sd, id)` (gana la MENOR sd en empate de bw).
- Modo `:kaspa`: clave `(bw, id)` (sin sd).
- U2 y U3″ dinámica activas salvo que se diga otra cosa; k indicado en cada derivación.
- `id` = 32 bytes; la comparación de bytes es lexicográfica (los ids textuales cortos se
  rellenan con ceros a la derecha, como `string_to_hash` de rusty-kaspa).
- blues de un bloque = `[sp] ++ azules del mergeset` en orden de coloreado;
  `blue_work(B) = blue_work(sp(B)) + Σ_{x ∈ blues(B)} w(x)`; `blue_score(B) = blue_score(sp(B)) + |blues(B)|`.

---

## D1 — Cadena pura (k=4; prueba de pesos heterogéneos y fronteras de w)

| Bloque | padres | slot | sd | SR | w | bw esperado |
|---|---|---|---|---|---|---|
| G | ∅ | 0 | 0 | 0 | W0 | 0 |
| C1 | [G] | 1 | 0 | 1 | 2^127 | W0 |
| C2 | [C1] | 2 | 0 | 3 | 2^126 | 2^128+2^127 = 510423550381407695195061911147652317184 |
| C3 | [C2] | 3 | 0 | 7 | 2^125 | +2^126 = 595494142111642311060905563005594370048 |
| C4 | [C3] | 4 | 0 | 2^64−2 | 2^64+1 | +2^125 = 638029437976759618993827388934565396480 |
| C5 | [C4] | 5 | 0 | 2^64−1 | 2^64 | +2^64+1 = 638029437976759619012274133008274948097 |
| C6 | [C5] | 6 | 0 | 0 | W0 | +2^64 = 638029437976759619030720877081984499713 |

Esperado: sp(Ci) = C_{i−1}; blues = [sp] en todos; sin rojos; `blue_score(Ci) = i`.
Orden de aplicación desde C6: `[G, C1, C2, C3, C4, C5, C6]`.

Fronteras que comprueba: `w(SR=0) = 2^128` (no cabe en u128; sí en nuestro dominio de 256 bits),
`w(SR=2^64−1) = 2^64`, `w(SR=2^64−2) = 2^64+1` (mínimo peso del dominio u64), potencias de 2.

## D2 — Diamante: empate de blue_work entre padres; fork de `sp` según modo (k=2)

| Bloque | padres | slot | sd | SR |
|---|---|---|---|---|
| G | ∅ | 0 | 0 | 0 |
| A | [G] | 1 | 5 | 0 |
| B | [G] | 1 | 3 | 0 |
| D | [A, B] | 2 | 1 | 0 |

`bw(A) = bw(B) = W0` (empate). `bw(D) = 3·W0 = 1361129467683753853853498429727072845824`.

- **:spec** → `sp(D) = A` (sd 5 > 3); `ms(D) = {B}`; B azul (cand_size 1 ≤ 2, sin pbas = k);
  blues = [A, B]; orden: `[G, A, B, D]`.
- **:python** → `sp(D) = B` (menor sd); `ms(D) = {A}`; A azul; blues = [B, A];
  orden: `[G, B, A, D]`.
- Colores y bw iguales en ambos modos; difieren `sp`, orden de coloreado y orden de aplicación.

## D3 — Anticono mayor que k (k=2): tope k+1 de azules

G (SR 0); S1..S7 con padres [G], slot 1, sd 1..7, SR 0; M con padres [S1..S7], slot 2, SR 0.
Todos los Si tienen `bw = W0` → `sp(M) = S7` (mayor sd). `ms(M) = {S1..S6}` coloreados en
orden de sd ascendente: S1, S2, S3, S4, S5, S6.

- S1: azul (tamaño de anticono 1). S2: azul (tamaño 2).
- S3: `|blues| = 3 = k+1` → ROJO por el tope (y también su cand_size llegaría a 3 > 2).
- S4, S5, S6: ROJOS por el mismo tope.
- blues(M) = [S7, S1, S2]; reds = [S3, S4, S5, S6]; `bw(M) = W0 + 3·W0 = 4·W0 =
  1361129467683753853853498429727072845824`; `blue_score(M) = blue_score(S7) + |blues| =
  1 + 3 = 4` (enmienda 2026-09-14 19:45 CEST, tras la primera ejecución: la expectativa del
  test decía 3, olvidando que el sp ya tenía score 1; gana la ejecución — y la definición de
  Kaspa, protocol.rs:153 — porque el mergeset_blues incluye al sp).
- Orden desde M: `[G, S7, S1, S2, S3, S4, S5, S6, M]`.

## D4 — Copias del mismo billete: U3′-filtro vs U3″ dinámica (k=30, contraejemplo R-FIN-11)

| Bloque | padres | slot | sd | SR | billete |
|---|---|---|---|---|---|
| G | ∅ | 0 | 0 | 0 | T0 |
| A | [G] | 1 | 50 | 0 | T1 |
| X | [G] | 1 | 0 | 0 | T2 |
| Y | [X] | 2 | 0 | 0 | T3 |
| Z | [Y] | 3 | 0 | 0 | T4 |
| Z2 | [Z] | 4 | 0 | 0 | T5 |
| A1 | [G] | 1 | 1 | 0 | T1 |
| A2 | [G] | 1 | 2 | 0 | T1 |
| A3 | [G] | 1 | 3 | 0 | T1 |
| A4 | [G] | 1 | 4 | 0 | T1 |
| M | [A, A1, A2, A3, A4, Z2] | 5 | 0 | 0 | — |

`bw(Z2) = 4·W0` (cadena G,X,Y,Z,Z2: bw acumula w(G)+w(X)+w(Y)+w(Z), sin el peso del propio
Z2 — enmienda de auto-revisión de las 19:20 CEST, ANTES de ejecutar nada: blue_work(B) = Σ w
sobre blues(B) = [sp]++mergeset azul, y el propio B no está en su blues). Domina igualmente:
`sp(M) = Z2`. `blue_idents(sp) = {T0,T2,T3,T4,T5}`
(no contiene T1). `ms(M) = {A, A1, A2, A3, A4}` en orden: A1 (sd 1), A2 (2), A3 (3), A4 (4), A (50).
U2 no invalida nada: las copias están en anticono mutuo, no en ancestría.

- **U3′-filtro** (solo `past(sp)`): ninguno de los T1 está en `blue_idents(sp)` → todos pasan
  el filtro; con k=30 todos son azules → **5 azules con el billete T1**.
  blues(M) = [Z2, A1, A2, A3, A4, A]; `bw(M) = 4·W0 + W0 + 5·W0 = 10·W0 =
  3402823669209384634633746074317682114560`.
- **U3″ dinámica**: A1 azul → T1 entra en las identidades azules del mergeset; A2, A3, A4 y A
  → `rojo_U3` (sin comprobar el k-cluster). → **1 azul con el billete T1**.
  blues(M) = [Z2, A1]; reds = [A2, A3, A4, A] (los cuatro `rojo_U3`);
  `bw(M) = 4·W0 + W0 + W0 = 6·W0 = 2041694101525630780780247644590609268736`.
  Nota: el «original» A pierde contra la copia A1 por el orden del mergeset, no por antigüedad.

## D5 — Empate de blue_work resuelto por solution_distance: cambia sp Y el bloque rojo (k=2)

| Bloque | padres | slot | sd | SR |
|---|---|---|---|---|
| G | ∅ | 0 | 0 | 0 |
| P | [G] | 1 | 10 | 0 |
| Q | [G] | 1 | 1 | 0 |
| R | [G] | 1 | 5 | 0 |
| S | [G] | 1 | 3 | 0 |
| M | [P, Q, R, S] | 2 | 0 | 0 |

Los cuatro padres empatan en `bw = W0`. `bw(M) = 4·W0 = 1361129467683753853853498429727072845824`.

- **:spec** → `sp(M) = P` (mayor sd). ms = {Q, S, R} en orden Q (sd 1), S (3), R (5).
  Q azul; S azul (cand_size 2 = k, pbas de Q = 1 ≠ k); R rojo (cand_size 3 > k).
  blues = [P, Q, S]; reds = [R]. Orden: `[G, P, Q, S, R, M]`.
- **:python** → `sp(M) = Q` (menor sd). ms = {P, S, R} en orden **P (sd 10), R (5), S (3)**
  (enmienda 2026-09-14 19:45 CEST tras la primera ejecución: la derivación anterior ponía
  R, S, P; gana la ejecución — la clave es `(bw, −sd, id)` ASCENDENTE, y −sd ascendente es
  sd DESCENDENTE). P azul; R azul (cand_size 2 = k); S rojo (cand_size 3 > k).
  blues = [Q, P, R]; reds = [S]. Orden: `[G, Q, P, R, S, M]`.

Los dos modos producen DISTINTO padre seleccionado (P vs Q), DISTINTO bloque rojo (R vs S) y
distinto orden de aplicación. Es el contraejemplo central del punto de decisión sobre la
dirección del desempate por solution_distance.

## D6 — Empate de bw y sd resuelto por id (k=2)

| Bloque | padres | slot | sd | SR |
|---|---|---|---|---|
| G | ∅ | 0 | 0 | 0 |
| P | [G] | 1 | 7 | 0 |
| Q | [G] | 1 | 7 | 0 |
| M | [P, Q] | 2 | 0 | 0 |

`bw(P) = bw(Q) = W0` y `sd(P) = sd(Q) = 7` → el desempate lo resuelve el id:
bytes de "P" = `0x50,0,...` < bytes de "Q" = `0x51,0,...`.
→ `sp(M) = Q` (máximo id); ms = {P}; P azul; blues = [Q, P]; `bw(M) = 3·W0 =
1020847100762815390390123822295304634368`. Orden: `[G, Q, P, M]`.
Demuestra que el id, como último componente, hace el orden TOTAL: dos bloques distintos nunca
empatan (supuesto de colisión de hash declarado).

## D7 — El color es contextual: un reorg cambia el color de W (k=1)

| Bloque | padres | slot | sd | SR | billete |
|---|---|---|---|---|---|
| G | ∅ | 0 | 0 | 0 | T0 |
| W | [G] | 1 | 9 | 0 | TW |
| U | [G] | 1 | 1 | 0 | TU |
| C1 | [W, U] | 2 | 5 | 0 | TC1 |
| V | [U] | 2 | 1 | 0 | TV |
| C2 | [V, W] | 3 | 1 | 0 | TC2 |
| T1 | [C1] | 4 | 0 | 0 | TT1 |
| T2 | [C2] | 4 | 0 | 0 | TT2 |

- `sp(C1) = W` (sd 9 > 1). ms(C1) = {U}: U azul (cand_size 1 ≤ k=1, pbas(W)=0, ms(W)={G} ⊆ past(U)).
  blues(C1) = [W, U]; `bw(C1) = W0 + W0 + W0 = 3·W0`.
- `sp(V) = U`; `bw(V) = 2·W0`.
- `sp(C2) = V` (bw 2·W0 > W0). ms(C2) = {W}: W ROJO: peer V cuenta 1; luego U ∈ ms(V) con
  U ∉ past(W) → cand_size 2 > k=1. blues(C2) = [V]; reds = [W] (rojo_k).
  `bw(C2) = bw(V) + w(V) = 3·W0`.
- Desde la punta **T1**: cadena G→W→C1→T1; W es bloque de cadena (azul, es el sp de C1);
  orden: `[G, W, U, C1, T1]`.
- Desde la punta **T2**: cadena G→U→V→C2→T2; W es fusionado por C2 como **rojo_k**;
  orden: `[G, U, V, W, C2, T2]` (rojo_k no se salta; solo rojo_U3 se salta).

Mismo DAG, dos puntas: el color de W es azul en una cadena y rojo_k en la otra. El dato GHOSTDAG
almacenado de W (`sp(W)=G`, azul) es el mismo; el COLOR que recibe W al ser fusionado depende de
la cadena seleccionada. Esto es lo que la SPEC quiere decir con «el color es el que recibe en el
bloque de cadena que lo fusiona».

---

---

## Derivaciones bajo la regla C (Corrección 1, 2026-09-14 22:00 CEST)

Regla C — DECIDIDO POR KATANA, TAREAS.md §1.3: mergeset (colorear y aplicar) en
`(bw, sd, id)` ascendente — **sin cambios respecto a `:spec`/`MERGE_SPEC`**, porque esa ya era
la dirección correcta. Lo que cambia es el padre seleccionado/punta virtual: máximo `bw`;
empate → MENOR `sd`; empate → MENOR `id` (dirección MIXTA, `SP_ZEROX`). `rank` = la misma tupla
ascendente (sin cambios, ya era `cmp_orden`/`es_menor_rank`).

Como el orden del mergeset no cambia, **D2′, D5′ y D6′ solo difieren de D2/D5/D6 en la elección
de `sp`** (y, por tanto, en qué queda dentro/fuera del mergeset) — no en cómo se ordena una vez
fijado. Derivado a mano, antes de escribir el test (ver `resultados/REGISTRO.log`).

### D2′ — Diamante bajo C (mismo DAG que D2)

`A` sd=5, `B` sd=3; `bw(A)=bw(B)=W0` (empate). Regla C: MENOR sd gana → `sp(D) = B`.
`ms(D) = {A}` (un solo candidato, orden trivial). `A` azul (k=2, cand_size 1).
`blues(D) = [B, A]`. `bw(D) = 3·W0`. Orden: `[G, B, A, D]`.

Coincide numéricamente con el antiguo `:python` (que también premiaba la menor sd para `sp`),
pero por una razón distinta: aquí es la regla C, no el patrón de `r8c_gd.py`.

### D5′ — Empate de bw bajo C (mismo DAG que D5: P sd=10, Q sd=1, R sd=5, S sd=3, k=2)

Regla C: MENOR sd entre los 4 empatados en bw → `sp(M) = Q` (sd=1).
`ms(M) = {P, R, S}`, orden ascendente por sd (sin cambios respecto a `:spec`): `S(3), R(5), P(10)`.
k-cluster (k=2): `S` azul (anticono {Q}, tam 1≤2); `R` azul (anticono {Q,S}, tam 2≤2, y
tam[Q]+1=2≤2, tam[S]+1=2≤2); `P` — anticono {Q,S,R}, tam 3>2 → **rojo_k**.
`blues(M) = [Q, S, R]`; `reds(M) = [P]`. `bw(M) = 4·W0` (mismo total que D5, distinta composición).
Orden: `[G, Q, S, R, P, M]`.

### D6′ — Empate total bajo C (mismo DAG que D6: P sd=7, Q sd=7, k=2)

Empate de bw Y sd → decide el id. Regla C: MENOR id gana (al contrario que `:spec`, que
premiaba el mayor). Bytes de "P" < bytes de "Q" → `sp(M) = P` (se invierte respecto a D6,
donde ganaba Q). `ms(M) = {Q}`; `Q` azul. `blues(M) = [P, Q]`. `bw(M) = 3·W0`.
Orden: `[G, P, Q, M]`.

Esta es la ilustración mínima de por qué ningún modo anterior era C: `:spec` maximizaba
`(bw,sd,id)` — mayor id gana —; C exige menor id en el padre seleccionado.

### D7′ — Color contextual bajo C (mismo DAG que D7: W sd=9, U sd=1, k=1)

`bw(W)=bw(U)=W0` (empate). Regla C: MENOR sd gana → `sp(C1) = U` (se invierte respecto a D7,
donde ganaba W). `ms(C1) = {W}`; anticono de W en contexto `{G,U}` = `{U}`, tam 1≤k=1 → `W` azul.
`blues(C1) = [U, W]`; `bw(C1) = 3·W0`.
`sp(V) = U` (único padre); `bw(V) = 2·W0`.
`sp(C2) = V` (bw 2·W0 > W0 de W, sin empate). `ms(C2) = {W}`; anticono de W en contexto
`blueset(V)={G,U,V}` = `{U,V}`, tam 2 > k=1 → `W` **rojo_k**. `blues(C2) = [V]`; `reds(C2) = [W]`.
`bw(C2) = 3·W0`.
Cadena desde **T1**: `G→U→C1→T1` (antes pasaba por W; ahora por U, porque U gana el empate).
Cadena desde **T2**: `G→U→V→C2→T2` — **ambas cadenas comparten a U** como ancestro común (a
diferencia de D7, donde divergían en G).
Orden(T1) = `[G, U, W, C1, T1]`. Orden(T2) = `[G, U, V, W, C2, T2]`.

**El fenómeno persiste bajo C**: W es azul cuando lo fusiona C1 (bloque de cadena de T1) y
`rojo_k` cuando lo fusiona C2 (bloque de cadena de T2) — mismo bloque, mismo dato GHOSTDAG
propio, color distinto según qué cadena lo fusiona. No hizo falta construir otro DAG: la regla
C cambia QUIÉN gana el empate de `sp`, pero no elimina la contextualidad del color.

### D8 — Tres hermanos en dos contextos: ¿altera el contexto el orden entre ellos? (k=30)

`P` sd=5, `Q` sd=9, `R` sd=1, SR distintos: `SR(P)=0` (`w=W0`), `SR(Q)=1` (`w=2^127`),
`SR(R)=3` (`w=2^126`). Los tres son hijos únicos de G ⇒ `bw(P)=bw(Q)=bw(R)=W0` (su propio SR
no afecta a su propio bw, solo al peso que APORTAN si otro bloque los incluye en su `blues`).

**Caso (a): P, Q, R son los tres padres de M.**
Regla C, empate de bw → MENOR sd gana → `sp(M) = R` (sd=1).
`ms(M) = {P, Q}`, orden ascendente por sd: `P(5)` antes que `Q(9)` → `[P, Q]`. Ambos azules
(k=30, anticono ≤2). `blues(M) = [R, P, Q]`.
`bw(M) = bw(R) + w(R) + w(P) + w(Q) = W0 + 2^126 + W0 + 2^127 = 2·W0 + 2^127 + 2^126`.
Orden: `[G, R, P, Q, M]`. Orden relativo entre P y Q (los dos que NO ganan sp): **P antes que Q**.

**Caso (b): P, Q, R entran en el mergeset de N, cuyo `sp` es la cadena más pesada
`G→Z1→Z2→Z3`** (`SR(Z1)=SR(Z2)=SR(Z3)=0`; `bw(Z1)=W0`, `bw(Z2)=2·W0`, `bw(Z3)=3·W0` — ver
enmienda más abajo, la primera versión de esta línea decía `4·W0` y estaba mal).
`N` con padres `[P,Q,R,Z3]`. `sp(N) = Z3` (3·W0 domina sin empate). `ms(N) = {P,Q,R}` (ninguno es
ancestro de Z3). Orden ascendente por sd: `R(1), P(5), Q(9)` → `[R, P, Q]`.
k-cluster (k=30, contexto = blueset(Z3) = {G,Z1,Z2,Z3}, todos ancestro-relacionados entre sí,
ninguno anticono con P/Q/R): los tres pasan holgadamente. `blues(N) = [Z3, R, P, Q]`.
`bw(N) = 3·W0 + W0 + 2^126 + W0 + 2^127 = 5·W0 + 2^127 + 2^126`.
Orden: `[G, Z1, Z2, Z3, R, P, Q, N]`. Orden relativo entre P y Q: **sigue siendo P antes que Q.**

> **Enmienda (2026-09-14, tras la primera ejecución del test D8):** la versión original de este
> párrafo decía `bw(Z3) = 4·W0` y `bw(N) = 6·W0 + 2^127 + 2^126`. El test dio
> `1956623609795396164914403992732667215872 = 5·W0+2^127+2^126`, no `6·W0+2^127+2^126`. Causa:
> confundí `w(Z2)` (el peso que Z2 APORTA, que depende solo de `SR(Z2)=0` y vale `W0`) con
> `bw(Z2)` (el blue_work acumulado de Z2, que vale `2·W0`) al calcular
> `bw(Z3) = bw(Z2) + w(Z2)`. La fórmula correcta usa `w(Z2)=W0`, no `bw(Z2)=2·W0`, dando
> `bw(Z3) = 2·W0 + W0 = 3·W0`. Verificado con aritmética independiente
> (`python3`, ver `resultados/REGISTRO.log`). **Ganó la ejecución**; el párrafo de arriba ya
> queda con el valor corregido, y este recuadro documenta el error, no lo oculta.

**Comparación.** El orden relativo entre P y Q (ambos presentes en el mergeset en los dos casos)
NO cambia entre (a) y (b): el orden del mergeset es una relación fija, independiente de con
quién más compita. Lo que SÍ cambia es el PAPEL de R: en (a) gana la competencia por `sp` (su
sd=1 es la menor de las tres); en (b) ni siquiera compite por `sp` — ese puesto lo ocupa Z3 por
pura diferencia de `bw` — así que R simplemente entra al mergeset como cualquier otro, y ahí sí
queda primero (por su sd), junto a P y Q. La dirección MIXTA de la regla C (máximo bw, mínimo
sd/id) solo se activa entre bloques que EMPATAN en bw y compiten por `sp`; una vez que alguien
gana por bw sin empate, los demás se ordenan con la regla del mergeset (ascendente simple),
sea cual sea su papel.

### D9 — Dos copias del mismo billete, mismo sd y mismo SR: ¿cuál queda sin colorear? (k=30)

`X`, `Y`: hermanas (mismos padres `[G]`), mismo billete `T`, mismo `sd=4`, mismo `SR=0` ⇒
`bw(X)=bw(Y)=W0`, empatadas en TODO salvo el id. Bytes: "X"=0x58 < "Y"=0x59 → X gana cualquier
desempate por id.

**Caso (a): X, Y son los dos padres de M.**
Empate total (bw, sd) → MENOR id gana → `sp(M) = X`. `ms(M) = {Y}`.
`blue_idents(X) = {T}` (X es la propia sp y ya lleva el billete) ⇒ al procesar Y,
`filtrado = (T ∈ sp_bi)` ya es **cierto** — Y queda `rojo_U3` sin llegar a comprobar el
k-cluster. `blues(M) = [X]`; `reds(M) = [Y]` (rojo_U3). **Y es la que queda sin colorear.**

**Caso (b): X, Y entran en el mergeset de N junto a la cadena pesada `G→Z1→Z2→Z3`** (igual que
D8b). `sp(N)=Z3`; `ms(N) = {X,Y}`, orden ascendente por id: `[X, Y]` (bw y sd empatados, decide
el id). `blue_idents(Z3) = ∅` (la cadena Z no lleva billete) ⇒ X NO es filtrada por `sp_bi`; pasa
el k-cluster (holgado) → **X azul**, y su identidad `T` entra en `vistos`. Al procesar Y:
`filtrado = (T ∈ vistos)` — cierto → **Y rojo_U3**.

**Misma respuesta en los dos casos (Y queda sin colorear), por DOS mecanismos distintos**: en
(a), el filtro simple contra `blue_idents(sp)` ya basta (X es sp Y lleva el billete); en (b),
ningún candidato es sp (gana Z3), así que el filtro dinámico (`vistos`, acumulado dentro del
propio mergeset) es el que decide — y decide con el mismo criterio de orden: quien va primero
en el mergeset (X, por id menor) se queda con la identidad.

### D10 — Tres copias del mismo billete, sd distintos: ¿sobrevive más de una? (k=30)

`U` sd=3, `V` sd=1, `W` sd=2, mismo billete `T2`, mismo `SR=0`, hermanas de G ⇒ las tres con
`bw=W0`.

**Caso (a): U, V, W son los tres padres de M.**
Regla C, empate de bw → menor sd gana → `sp(M) = V` (sd=1). `ms(M) = {W, U}`, orden ascendente
por sd: `W(2)` antes que `U(3)` → `[W, U]`. `blue_idents(V) = {T2}` (V es sp y lleva el billete)
⇒ TANTO W como U quedan filtrados por `sp_bi` de inmediato (ninguno llega al k-cluster).
`blues(M) = [V]`; `reds(M) = [W, U]` (ambos rojo_U3, en ese orden).

**Caso (b): U, V, W entran en el mergeset de N junto a la cadena pesada `G→Z1→Z2→Z3`.**
`sp(N)=Z3`; `ms(N) = {U,V,W}`, orden ascendente por sd: `V(1), W(2), U(3)` → `[V, W, U]`.
`blue_idents(Z3)=∅` ⇒ V no es filtrada por `sp_bi`; pasa el k-cluster → **V azul**, `T2` entra
en `vistos`. W: `filtrado = T2 ∈ vistos` → cierto → **rojo_U3**. U: mismo motivo → **rojo_U3**.
`blues(N)` incluye a `V`; `reds` incluye a `W` y `U` (ambos rojo_U3, en ese orden).

**Conclusión, con 3 copias en vez de 2**: exactamente UNA sobrevive azul en ambos casos —
la que ordena primero en `(bw,sd,id)` —, y TODAS las demás quedan `rojo_U3`, no solo la
siguiente. El mecanismo de D9 no es específico de 2 copias: escala a cualquier número de copias
del mismo billete dentro de un mismo mergeset.

### D11 — Contraejemplo histórico de R-FIN-11: 14 azules (U3_FILTER) vs 1 (U3_DYNAMIC), k=30

Reconstrucción del contraejemplo citado en `research/dag-poas-ancla-de-orden.md:227-239` y
`research/scripts/d9-ronda8c/r8c_a3_filtro.py:16` («k=30 → mp=15 → 14 azules por billete»).

Cadena honesta corta (sin billete): `G→H1→H2` (`SR=0` en ambos) ⇒ `bw(H1)=W0`, `bw(H2)=2·W0`.
Catorce copias del mismo billete `T3`, hermanas de G (mismos padres `[G]`), `sd = 1..14`
respectivamente (`C1..C14`), `SR=0` ⇒ `bw(Ci)=W0` para las 14, empatadas entre sí y por debajo
de `bw(H2)=2·W0`.

`M` con **15 padres**: `[H2, C1, ..., C14]` (el máximo permitido, R-FIN-12).
`sp(M) = H2` (bw 2·W0 domina sin empate a las 14 copias). `ms(M) = {C1,...,C14}` (H1 queda
excluido por ser ancestro de H2=sp). Orden ascendente por sd: `[C1, C2, ..., C14]` (ya vienen
ordenados 1..14).

**U3_FILTER**: `blue_idents(H2) = ∅` (la cadena honesta no lleva billete) ⇒ para las 14 copias,
`filtrado = (T3 ∈ sp_bi=∅) = false` SIEMPRE (el modo filtro NO acumula `vistos` dentro del
mergeset). Las 14 pasan al k-cluster: anticono máximo alcanzado = 13 (para C14, frente a las 13
anteriores ya en contexto) ≤ k=30 → **las 14 son azules**.

> **Corrección editorial al migrar (Claude, 2026-09-14):** el anticono azul máximo de C14 es
> **15**, no 13: además de las 13 copias anteriores contiene a H1 y H2, que no son ancestros ni
> descendientes de ninguna copia. Como 15 ≤ k = 30, la conclusión no cambia: las 14 son azules.

**U3_DYNAMIC**: `sp_bi=∅` igual, pero ahora sí se acumula `vistos`. `C1` no está filtrada (T3 no
en sp_bi ni en vistos aún) → pasa el k-cluster → **azul**, `T3` entra en `vistos`. `C2..C14`:
`filtrado = T3 ∈ vistos` → cierto para las 13 restantes → **rojo_U3** todas.

**Resultado: 14 azules bajo U3_FILTER, 1 azul bajo U3_DYNAMIC — coincide exactamente con la cifra
histórica citada en el encargo.** La diferencia es mecánica, no numérica: FILTER solo mira
`past(sp)`, nunca lo que ya se coloreó DENTRO del propio mergeset que se está procesando; DYNAMIC
sí, y por eso el orden del mergeset (que copia se procesa primero) es lo único que decide cuál
de las 14 sobrevive.

## Registro de discrepancias entre derivación y ejecución

**Corrección (2026-09-14): esta sección decía «Ninguna», y eso era falso.** Hubo dos, ambas ya
visibles como enmienda en el cuerpo de D3 y D5, pero nunca resumidas aquí:

1. **D3** (línea ~68-70): la derivación original ponía `blue_score(M) = 3`; la ejecución dio `4`.
   Causa: la derivación olvidó que `blue_score(sp)` ya valía 1 antes de sumar los 3 azules del
   mergeset (`mergeset_blues` incluye al `sp`, `protocol.rs:153`). Ganó la ejecución.
2. **D5** (línea ~122-125): la derivación original, para el modo `:python`, ordenaba el mergeset
   como `R, S, P`; la ejecución dio `P, R, S`. Causa: la clave es `(bw, −sd, id)` **ascendente**, y
   `−sd` ascendente es `sd` **descendente** — la derivación original invirtió el signo. Ganó la
   ejecución.

Ambas enmiendas están fechadas 19:45 CEST en el cuerpo del documento — hora que la nota de
validación de arriba ya marca como no creíble (posterior a la última escritura real del archivo,
18:55:09). El *contenido* de la corrección (3→4 en D3; el orden P,R,S en D5) es correcto y está
confirmado por la ejecución actual; lo que no se puede sostener es que se escribiera a las 19:45.

3. **D8, caso (b)** (Corrección 1, 2026-09-14, hora real en `resultados/REGISTRO.log`): la
   derivación decía `bw(Z3)=4·W0` y `bw(N)=6·W0+2^127+2^126`; la ejecución dio
   `5·W0+2^127+2^126`. Causa: confundí `w(Z2)` (peso aportado, `=W0`) con `bw(Z2)`
   (blue_work acumulado, `=2·W0`). Ganó la ejecución; ver la enmienda in-line en D8. A
   diferencia de las dos de arriba, esta SÍ tiene hora verificable tanto de la derivación
   original como de la enmienda (ambas en `resultados/REGISTRO.log`, con `date` real).
