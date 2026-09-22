# DERIVACIONES — PPP-v0.1

Se numeran D1–D10. Cada derivación precede a su comprobación en `test/runtests.jl` o en
`resultados/`. Los valores numéricos citados salen de `resultados/run-*.txt`.

## D1. Probabilidad exacta del nivel con `C` sorteos

Sea `d_1,…,d_C` iid uniformes en `{0,…,M−1}`, `M = 2^63`, `D = min_i d_i` (el bloque usa el chunk
ganador de menor distancia; `auditing.rs:236-270`). Entonces `P(d_i > x) = (M−1−x)/M` y

```
F(x) := P(D ≤ x) = 1 − ((M−1−x)/M)^C,        0 ≤ x ≤ M−1.
```

Con umbral entero `T_L = SR >> L` (división entera, como `solution_range / 2` en
`subspace-verification/src/lib.rs:158`),

```
P(nivel ≥ L | válida) = F(T_L) / F(T_1).
```

**Comprobación.** `oraculo_exhaustivo` enumera las `M^C` tuplas para `M ∈ {4,6,8}`,
`C ∈ {1,2,3}` y compara `p_exhaustiva_ge` con `formula_escalada`: **0 discrepancias**
(`resultados/run-anclaje.txt`). Además, `monte_carlo_niveles` (24 réplicas, semilla fija) coincide
con la exacta dentro de 4σ (`resultados/run-mc.txt`).

## D2. La hipótesis `2^{−(L−1)}` es el límite `SR/M → 0`, con dos correcciones

Para `C = 1`, `P(nivel ≥ L | válida) = (T_L+1)/(T_1+1)`, es decir

```
2^{−(L−1)} · (1 + O(2^L/SR)).
```

Para `C > 1`, la concavidad de `F` da `F(λT_1) ≥ λF(T_1)` con `λ = 2^{−(L−1)}`, o sea
`exacta/hipótesis ≥ 1`, y crece con `C` y con `SR/M`. En régimen `SR ≪ M` la corrección es
despreciable (`SR=2^45, C=1`: `1 + 5·10⁻⁸`); si `SR` es comparable a `M` la corrección es grande
(`SR=2^63−1, C=64, L=8`: ×28). **La hipótesis no es falsa de por sí; es un enunciado asintótico, y
las constantes que la separan de la realidad dependen de `SR`, que es variable.** Ver
`resultados/run-niveles.txt` y `run-multiples.txt`.

## D3. El nivel es escala-invariante respecto de `SR` (si se ancla al bloque)

Con umbral `SR ÷ 2^L` y validez `SR ÷ 2`, multiplicar `SR` por una constante no cambia la razón
`F(SR÷2^L)/F(SR÷2)` salvo por los redondeos `+1`. Por eso `--niveles` da razón 1,000000 para todo
`L`. La escala **no** es el problema; el problema es que el `SR` es **endógeno**.

## D4. El nivel es independiente de los padres (hecho estructural)

La solución se calcula de `(global_challenge(slot), sector, chunk)`, sin leer `padres`.
Formalmente: para un slot `s` y una solución `σ` con distancia `d`, y para **cualesquiera** dos
conjuntos de padres `P, P'` con `max(slot(p)) ≤ s`, los bloques `(σ, P)` y `(σ, P')` tienen el
mismo `d` y por tanto el mismo nivel.

**Comprobación.** `valida_anclaje_independiente` construye 200–500 pares con `SR` y distancia
aleatorios: **0 discrepancias**. `dos_historias_misma_solucion` devuelve certificados idénticos con
padres distintos. Esto no es estadística: es identidad del proceso.

## D5. Teorema del anclaje: no existe un nivel que sea (P1), (P2) y (P3) a la vez

Sea `ℓ(B)` un predicado de nivel usado en una prueba de poda. Se pide:

- **(P1)** un tercero lo comprueba sin el DAG completo (si no, no hay poda);
- **(P2)** producirlo cuesta recurso ≈ `2^L` (si no, no acota nada);
- **(P3)** depende de la ancestría de `B` (si no, no acredita una historia).

**Demostración.** Casos por el dato del que puede depender `ℓ`, exhaustivos por construcción
(todo dato público es: auditoría de espacio, hash de cabecera, salida/reloj de PoT, o una relación
entre campos que el autor elige):

- **Caso A — `ℓ` depende de la auditoría** (distancia/solución) y/o del `slot` y `SR`. Por D4 es
  independiente de `padres(B)`. Falla **(P3)**: el mismo nivel se pega a cualquier ancestría con
  `slot(padre) ≤ slot`.
- **Caso B — `ℓ` depende del hash de cabecera** (que sí incluye `padres`), no de la auditoría.
  Falla **(P2)**: el hash incluye el sello Ed25519, cuya **no unicidad está reconocida en
  C-HDR-04** (nota de la regresión `ed25519_no_unicidad.rs`), y el `merkle_root` depende de la
  coinbase. El autor muele ceros iniciales a coste CPU y espacio ≈ 0. Cuantificado: nivel 40 con
  `2^40` hashes ≈ 1,1·10⁶ s a 10⁶ h/s (`run-anclaje.txt`), sin gastar un byte de disco.
- **Caso C — `ℓ` depende del PoT** (salida por slot, ceros de la cadena PoT, tiempo transcurrido).
  Falla **(P2) como medida de espacio**: el PoT es una función del reloj y de la cadena PoT, no de
  los sectores; mediría trabajo de VDF, no espacio archivado, y un VDF más rápido lo estira
  (ATAQUE 1–2 de `research/dag-poas-auditoria.md`). Además falla **(P3)**: el flujo de PoT puede
  ramificarse en los puntos de inyección, así que no liga a una única ancestría del DAG.
- **Caso D — `ℓ` depende de una relación con los padres que el autor elige** (p. ej. el hueco
  `slot(B) − slot(sp(B))`). Falla **(P2)**: el autor escoge `sp` y puede fabricar el hueco a coste
  cero con un billete viejo; no mide recurso.
- **Caso E — combinación de los anteriores** (p. ej. `exigir auditoría ∧ ceros del hash`, o
  `auditoría ∧ PoT`). Para (P3) hace falta un término ligado a la ancestría (B o C); ese término
  no aporta cota de espacio/PoT. Para (P2) hace falta el término de auditoría (A), que no liga a
  la ancestría. La conjunción **no crea** una propiedad que ninguno de los sumandos tiene: el
  adversario satisface la condición de auditoría con una solución encontrada para **cualquier**
  ancestría y satisface la del hash moliendo (o la del PoT con un VDF más rápido), de forma
  independiente. La cota de espacio resultante es la del término de auditoría, que es
  independiente de la historia.

Luego no existe `ℓ` que cumpla (P1)+(P2)+(P3). **Éste es el resultado «no existe» del encargo.**
Su consecuencia directa: añadir `parents_by_level` a la cabecera **no** cambia ninguno de los casos
y no rescata la prueba de poda. Ver `INFORME.md` §4.

## D6. Múltiples soluciones por s-bucket: efecto real (punto 3)

`map_winning_chunks` no se queda con un chunk: devuelve **todos** los ganadores, ordenados. La
identidad de billete de R-FIN-11 es `(public_key, sector_index, history_size, chunk, slot)`, que
**incluye `chunk`**: dos chunks ganadores distintos del mismo s-bucket en el mismo slot son dos
billetes distintos y pueden ser dos bloques.

- Sobre la **probabilidad de nivel**: no hay ventaja diferencial; la razón exacta/hipótesis es la
  misma para todos los `C` (D2), y honestos y adversario tienen el mismo `C`.
- Sobre el **certificado**: `N` bloques de nivel `L` dejan de interpretarse como `N·2^L` unidades
  de espacio-tiempo **ligadas a una historia**. Con `m` ganadores medios por sector-slot, el
  adversario satisface el certificado con `≈ N/m` sector-slots, y puede repartir los `m` billetes
  entre historias distintas (una copia por historia), que es el vector de doble uso ya señalado en
  A3/ATAQUE 2 de `research/dag-poas-auditoria.md`.

Cuantificado en `run-multiples.txt`: con `SR` grande la multiplicidad infla la cola de nivel
(`C=64` frente a `C=1`: ×28 en `L=8`, `SR=2^63−1`). No es un ataque nuevo, pero **rompe la
lectura ingenua del certificado como cota de recurso por historia**.

## D7. Retención: optatividad, no recursos (punto 4)

Un bloque de nivel `L` cuesta `≈ 2^{L−1}` soluciones válidas, con o sin retención. Para fracción
de espacio `α` y tasa `λ` bloques/slot, el espaciamiento medio es

```
T(L) = 2^{L−1} / (α·λ)   slots.
```

`run-retencion.txt` (α=0,10, λ=1): `L=8 → 1280 slots ≈ 21 min`, 67,5 bloques nivel-8/día;
`L=16 → 3,3·10⁵ slots ≈ 3,8 días` por bloque. La retención **no** reduce el gasto; lo que compra
es elegir la ancestría **después** de tener el billete. Esa optatividad es exactamente la
propiedad que un certificado no puede comprobar (D4), y no requiere más del 50 % del espacio: no
es un ataque de mayoría, es un fallo de **soundness** del certificado.

## D8. `blue_work` no se recomputa desde el certificado (punto 7, ATAQUE 8)

`blue_work(B) = blue_work(sp(B)) + Σ_{x∈blues(B)} w(x)` (§11, C-GD-08). Para recomputarlo hace
falta el mergeset, el coloreo k-cluster y `SR` de cada azul; nada de eso está en un certificado de
niveles. Comprobación con GDR-v0.2: dos DAG con idénticos `(slot, sd, SR)` por bloque,
`B5←{B3,B4}` frente a `B5←{B3}`:

```
mergeset: blue_score = 4, blue_work = 340282366920938463574055071874025521152
lineal  : blue_score = 3, blue_work = 340282366920938463537161583726606417920
```

El certificado de niveles es el mismo. Y como `blue_work` declarado en cabecera es gratis bajo
PoST (ATAQUE 8), un cliente ligero no puede verificar la afirmación sin bajar el DAG. Por tanto
el certificado no sustituye a la verificación de `blue_work`.

## D9. Crecimiento sin poda (A″)

A 1 bloque/s (`C-SLOT-01`), `365·24·3600 = 31 536 000` cabeceras/año. Con la cabecera típica de
748 B (TAREAS §1.4): **23,59 GB/año**; 589 B → 18,57; 1 037 B → 32,70. Reachability
`O(#cabeceras × mergeset_limit)`, `mergeset_limit = 180` (C-GD-04): hasta `5,68·10⁹` entradas/año.
Ver `run-cabeceras.txt`. Ésta es la laguna que motiva el encargo; sin poda no tiene cota.

## D10. Compromiso verificable del estado (punto 8)

Qué objeto compromete el estado podado: una **raíz del conjunto UTXO** (Merkle/Patricia) o un
**acumulador** (p. ej. Utreexo). Coste: una prueba de inclusión por entrada/salida en el testigo;
producción por bloque una vez existe el conjunto (TAREAS §2.6: hoy **no existe** en ZEROX). Este
objeto permite a un nodo que ya validó conservar el estado sin las hojas (ayuda a (1)), y permite
a un archival node demostrar el estado de una altura (ayuda a (3)). **No** da soundness sobre la
historia: comprometer el estado no dice que ese estado provenga de una historia válida ni cuál es
la canónica; eso exige el DAG y GHOSTDAG. Es necesario para poda local, insuficiente para (2).
