# GHOSTDAG sobre PoAS — el argumento y su auditoría D9 + D8

**Fecha:** 2026-09-06 · Cierra **P-038** con veredicto negativo · Abre **P-039** ·
`subspace @ f8842d0`, `rusty-kaspa @ c338d495`, ePrint 2018/104 (v. 2021-11-10), BDK+19
(arXiv 1910.02218v3), arXiv 2308.06955.

Katana fijó la condición: «viable si el argumento sobrevive a D9 y D8». **No sobrevive.** El
argumento se transcribe íntegro en §1 (tal como se auditó, con su error de premisa incluido), y
los veredictos en §2 y §3. Scripts de D9 en el scratchpad de la sesión
(`d9/{phi_c,kcal,reversal,peso,u3,chain_growth}.py`); reproducibles.

## 0 · Resumen para quien no lea el resto

| Afirmación | Veredicto | Quién |
|---|---|---|
| A1 la prueba de GHOSTDAG solo usa (i)(ii)(iii) | Sobrevive con dos supuestos más: tasa en tiempo de reloj (espacio·vdf) y «pasado ⊂ anteriores» sobre TODOS los padres | D9 |
| A2 el reloj del PoT restaura (i) | Sobrevive solo si el flujo de PoT es único para todo el DAG, cosa que el argumento no garantiza | D9, D8 |
| **A3 el double dipping residual es el de la lineal** | **REFUTADA.** En un DAG los bloques válidos bajo flujos de PoT distintos se pueden referenciar y contar azules: `m` flujos → `m·α·λ`, umbral → 0. Y la inyección ramifica a profundidad 0 (el slot lo fija la punta), no a 100 bloques | D9 (construcción), D8 (Ataques 1 y 2: 10 % de espacio + 10 núcleos = 52,6 %) |
| A4 unicidad U1-U4 | U1 por hash refutada (`reward_address` libre); U2 redundante con slot sobre todos los padres; **U3 refutada** como parte de GHOSTDAG (rompe «cadena seleccionada ⊆ azules», Lema 12); la forma sana es «primera copia en el orden azul, resto rojas» | D9 (contraejemplo ejecutado), D8 |
| A5 conocimiento anticipado | Sobrevive con la regla `slot(B) > slot(p)` para todos los padres, que no existe y choca con «referenciar todas las puntas» | D9, D8 |
| A6 peso Σ 2^128/(SR+1) | Invariancia VERIFICADA (ε ≤ 4,88·10⁻⁴). **Reajuste REFUTADO**: LWMA-1 sobre slots no existe en DAG; para q ≤ 4 no hay λ (la cadena seleccionada crece ≤ 1/D) | D9 |
| A7 reducción a GHOSTDAG-sobre-PoW | **REFUTADA** por A3; además el umbral es en espacio·vdf y el teorema es sobre conteo, no peso | D9 |
| A8 «misma seguridad por segundo» | Primera mitad REFUTADA (es exponencialmente más a igual reloj), pero la cota del paper con k=18 es peor que la lineal a horizontes cortos; q=1 y q=10 no tienen función de calibración detrás (`pieces_to_solution_range` desborda con q=1) | D9, D8 |
| A9 estructura | Nada definido, nada refutable | D9 |

**El fallo es de diseño, no de parámetro.** El PoT de Autonomys inyecta entropía por posición
ordinal en la cadena seleccionada (bloque `50j`, entropía del `50j−100`, aplicada en
`slot(50j)+15`). Un DAG a q pequeño no tiene posición ordinal estable a 15 slots de profundidad
(Kaspa: `MERGE_DEPTH = 3600 s`, `FINALITY = 43 200 s`). Las dos salidas fallan:

- validez del PoT global → dos nodos honestos ven inyectores distintos → **split sin atacante**;
- validez del PoT relativa a la cadena de cada bloque → el atacante abre un flujo por billete
  frontera, audita sus sectores contra `m` desafíos por slot (un SSD de 100k IOPS aguanta ~24) y
  fusiona los `m` flujos → **cuota `mα/(1−α+mα)`**.

La mitigación (inyectar desde profundidad de finalidad, ~12 h) choca con la función anti-VDF-rápido
de la inyección (Baig-Pietrzak): con 12 h de rezago, un timelord 2× conoce las entropías y lleva
12 h de adelanto. **No hay fuente que reconcilie las dos exigencias.** Sería un diseño nuevo de
Proof-of-Time, sin precedente.

## 0.1 · Hallazgos colaterales para la cadena LINEAL ya decidida

1. **`POT_ENTROPY_INJECTION_LOOKBACK_DEPTH = 2` son intervalos, no bloques.**
   `pallet-subspace/src/lib.rs:200-202` («in entropy injection intervals») y `:942-947`
   (`lookback_in_blocks = interval × depth`). La entropía del bloque `50j` sale del `50j−100`.
   DECISIONES §21 heredó las constantes «calibradas» de Autonomys sin pasarlas a tiempo: a 6 s por
   bloque son 10 min de rezago; **a `T = 120 s` son 3,3 h**. Patrón H-005. → **P-039**.
2. **El factor de double dipping de ZEROX tiene número.** D9 implementó la ec. 39 de BDK+19 (de
   donde el greenpaper toma el 1,47): `φ₁₆ = 1,4678`, **`φ₅₀ = 1,2815`** → el atacante necesita
   `1/(1+φ₅₀) = 43,8 %` del recurso espacio·vdf; honesto > 56,2 %. Verificado computacionalmente
   contra la Tabla 3 del paper. Supuesto no demostrado: que el rezago de 100 bloques en el
   contenido no cambie la tasa (BDK no lo analiza).
3. **La inyección depende del slot en que se aplica, no solo de la entropía**
   (`sp-consensus-subspace/src/lib.rs:121-126`, `pot.rs:290-295`): dos ramas con la misma
   entropía y distinto slot de inyección tienen flujos distintos. Relevante para cualquier regla
   futura sobre el PoT en reorgs.
4. **`Δ = 4 s` no es `Dmax`.** Δ es la ventana de autoría; `Dmax` es propagación de bloque con
   cuerpo (dinámico) más verificación de PoT (§24). No está medido. Afecta a cualquier calibración
   futura, DAG o no.
5. **Identidad de una solución.** `Solution` incluye `reward_address` libre
   (`solutions.rs:254-275`) y `SectorId` incluye `history_size` (`subspace-verification/src/lib.rs:225-229`).
   Si alguna vez hace falta identificar un billete (equivocación), la tupla es
   `(public_key, sector_index, history_size, chunk/s_bucket, slot)`, nunca el hash de la solución.

## 0.2 · Lo que rusty-kaspa asume de PoW (D8, `c338d495`)

- Niveles de poda por ceros del hash: `parents_by_level` (`header.rs:141`),
  `calc_level_from_pow` (`consensus/pow/src/lib.rs:72-75`), `pruning_proof/build.rs:145-195`.
  Sin niveles no hay prueba de poda; sin poda, reachability crece sin cota.
- DAA cuenta rojos (`difficulty.rs:27-30`, `window.rs:308`) y la coinbase de los rojos se emite
  al fusionador (`coinbase.rs:117-131`); las txs de rojos se aplican (`utxo_validation.rs:122`).
  Portado tal cual bajo PoST: **un billete → hasta 10 coinbases**. Arreglo: DAA y emisión solo
  sobre azules, y la dirección de recompensa vuelve a la cabecera (deshace C-HDR-08).
- `blue_work` en cabecera es afirmación del minero, comprobable solo por nodo completo
  (`post_pow_validation.rs:47-53`): sin SPV. §26 no sobrevive.
- C-REORG-07 a q=1: una partición honesta de 4-5 min con ≥ 40 % del espacio dispara la parada
  dura (`ReorgDemasiadoProfunda` → `exit`). Kaspa no apaga: ignora puntas fuera de finalidad
  (`processor.rs:298-306`).

## 0.3 · Lo que SÍ sobrevivió (para no repetir la búsqueda)

n-split de Filecoin no aplica bajo merge irrestricto con unicidad (demostrado por D9; pero merge
irrestricto es lo que A3 prohíbe). Griefing por copias: cerrado. `solution_distance` no se muele.
Selfish farming con Δ=4: nada que PoW no tenga. Invariancia del peso por espacio: verificada.
Calibración de k para ZEROX (ec. 1-2 de §4.2): q=10 → k=3/5 (solo Poisson) u 80/800 (ec. 2
completa); q=1 → 15/18 o 793/7 993. El propio paper solo cumple el término de Poisson.

## 0.4 · Lo que habría que demostrar antes de reabrir esto (lista de D9)

1. Regla de validez de PoT en DAG y demostración de que el merge no multiplica billetes.
2. Inyección (contenido **y** slot) desde un prefijo estable, con retraso derivado de la
   convergencia del orden, y su φ resultante.
3. Teorema 4 sobre `blue_work` con retarget por rama y λ variable.
4. Coloreado con unicidad que conserve «cadena seleccionada ⊆ azules».
5. Regla de slot sobre todos los padres compatible con referenciar todas las puntas; umbral en
   espacio·vdf.
6. Retarget para DAG (ventana de azules) y su convergencia.
7. Medición de `Dmax` y recalibración de k.

---

## 1 · El argumento auditado (transcripción literal)

### ARGUMENTO A AUDITAR — GHOSTDAG sobre Proof of Archival Storage (ZEROX)

**Estado: PROPUESTA SIN AUDITAR, escrita por el agente principal el 2026-09-06.** No es SPEC, no es
decisión. Existe para que D9 (matemáticas) y D8 (adversarial) intenten refutarla. Cada afirmación
va numerada para poder citarla al atacarla.

## Contexto fijado (no se discute aquí; es lo que ZEROX ya decidió)

Fuentes: `/home/katana/zeo/ZEROX/SPEC.md` §6.1, §7.5, §11, §12; `/home/katana/zeo/NODOS/ZEROX/DECISIONES.md`
§14, §19-§26; `/home/katana/zeo/ZEROX/research/{fork-choice-poas,proof-of-space-tiempo,dag-consenso-poas}.md`;
clon de Autonomys en `/tmp/claude-1000/-home-katana-zeo/32d96f16-7425-4b44-82ef-7ba7960e327c/scratchpad/pos/subspace`
(commit f8842d0).

- Consenso: Proof of Archival Storage estilo Autonomys. Slot `σ = 1 s`. Hoy `q = 120` (un bloque
  esperado cada 120 slots). Ventana explotable `Δ = 4` slots (`BLOCK_AUTHORING_DELAY = 4`).
- Desafío global por slot: `derive_global_challenge(slot) = blake3(salida_PoT ‖ slot)`
  (`subspace-core-primitives/src/lib.rs:110-112`). El PoT es una cadena única de AES. Se le inyecta
  entropía del hash de un bloque cada `POT_ENTROPY_INJECTION_INTERVAL = 50` bloques, tomado con
  `LOOKBACK_DEPTH = 2` bloques de retraso y aplicado `INJECTION_DELAY = 15` slots después
  (`subspace-runtime/src/lib.rs:151-165`). ZEROX hereda esas tres constantes (DECISIONES §21).
- Una solución es válida si `solution_distance ≤ rango_solucion/2`, y `solution_distance` se calcula
  del desafío y del contenido del sector, NO del padre ni del contenido del bloque.
- Peso por bloque en ZEROX: `peso = floor(2^128 / (rango_solucion + 1))` (P-006 cerrada). Fork choice
  lineal hoy: mayor peso acumulado; desempate propuesto por menor `solution_distance`, luego hash.
- Cabecera de 556 B con un solo `prev_hash`, un `slot`, un `pot_output`, la solución y un sello de 64 B.
- Coste medido: verificar una cabecera sin PoT = 1,32 ms (2 KZG); PoT = 100,20 ms por slot, por slot y
  no por bloque; justificación de PoT = 128 B por slot.
- Reglas que asumen "un bloque por altura": C-HDR-02, C-HDR-05, C-EXP-02/04 (caducidad de sectores
  por `hash_bloque[altura_ploteo]`), C-FORK-*, C-REORG-07 (`MAX_REORG_LENGTH = 99`, parada dura),
  C-CHK-04, LWMA-1 sobre slots (§7.3, DECISIONES §19/§23), archivado a profundidad K.
- Prioridades del proyecto: descentralización > velocidad > escalabilidad (P-036).
- Referencia de código para el DAG: `rusty-kaspa` (github.com/kaspanet/rusty-kaspa), nodo de producción
  de Kaspa en Rust, ISC, 10 bloques/s desde mayo 2025. Su métrica de selección es `blue_work` (suma de
  dificultad de los bloques azules), no el conteo.

## El argumento

**A1 · Qué necesita GHOSTDAG del recurso.** La prueba de seguridad de PHANTOM/GHOSTDAG (ePrint
2018/104, v. 2021-11-10, Lema 9 y Teorema 4) usa tres propiedades: (i) los bloques llegan como un
proceso de Poisson de tasa λ repartida entre honestos y atacante en proporción al recurso, sin
memoria; (ii) un bloque no puede reutilizarse en dos posiciones del DAG; (iii) el adversario puede
retener bloques y elegir sus padres arbitrariamente. Nada más del PoW se usa en la prueba.

**A2 · (i) la restaura el reloj global del PoT, no la estructura de cadena.** Entre dos puntos de
inyección de entropía, todas las ramas del DAG ven el mismo desafío por slot. El número de
soluciones válidas que un granjero obtiene por slot depende solo de su espacio y del rango, y es
idéntico en cualquier rama. Por tanto los "billetes" por slot son un proceso ∝ espacio, igual para
todos, y el atacante no gana billetes construyendo ramas privadas dentro de una época de inyección.

**A3 · El double dipping residual es el de los puntos de inyección, y es el mismo que en la cadena
lineal.** Una rama privada con un bloque de inyección distinto obtiene un flujo de desafíos
independiente a partir de ese punto. Ese es exactamente el ataque que el greenpaper de Chia
(ChiaGreenPaper_20260612.pdf §2.2) acota con "≥16 bloques por desafío" → factor 1,47. ZEROX tiene
50 bloques por época de inyección, así que el factor es menor que 1,47 (SIN CUANTIFICAR). El DAG no
cambia este factor mientras el bloque de inyección se tome de la cadena seleccionada de GHOSTDAG a
profundidad ≥ la de poda/finalidad.

**A4 · (ii) se rompe bajo PoST y se repara con una regla de unicidad.** Como la solución no depende
del padre, un billete puede convertirse en N bloques distintos (padres o contenido distintos) a coste
cero. En un DAG inclusivo eso permite fabricar k+1 bloques en el anticono de un bloque honesto con
un solo billete, y tumba la calibración de k. Regla propuesta (determinista, sin estado extra):

  U1. La identidad de una solución es `(public_key, sector_index, chunk, slot)` (o el hash de la
      solución completa).
  U2. Un bloque cuyo pasado (past(B) en el sentido de GHOSTDAG) ya contiene otro bloque con la misma
      identidad de solución es INVÁLIDO.
  U3. Dos bloques con la misma identidad de solución que están en el anticono uno del otro se
      colorean ROJOS ambos (excluidos del orden y del peso). La regla es simétrica, así que es
      determinista entre nodos.
  U4. Nadie puede forjar la solución de otro (va firmada con el sello), así que U2/U3 solo castigan
      al que equivoca. Con U1-U4, un billete produce a lo sumo un bloque contado, y (ii) vuelve.

**A5 · (iii) ya se le concede al adversario; el conocimiento anticipado no añade poder.** Bajo PoST
el granjero conoce su solución hasta `Δ = 4` slots antes y elige los padres después de conocerla.
El adversario del modelo de GHOSTDAG ya es totalmente adaptativo sobre la estructura. Los honestos
referencian todas las puntas que ven, así que conocer el billete antes no cambia su comportamiento.
Además, el `slot` de un bloque lo fija el billete y no es moldeable (a diferencia del timestamp de
PoW): un bloque retenido lleva un slot antiguo visible, y una regla "bloque cuyo slot es anterior en
más de X slots al de sus padres → rojo" es más fuerte que cualquier anclaje temporal posible en PoW.
(Esto último es OPORTUNIDAD, no parte de la reducción.)

**A6 · Peso.** Sustituir el conteo de bloques azules por `Σ floor(2^128/(rango_solucion+1))` sobre los
bloques azules (la generalización que Kaspa ya hace con `blue_work`). Afirmación: la tasa de
acumulación de peso por unidad de tiempo es ∝ espacio e invariante al reajuste del rango, como en
`fork-choice-poas.md` para la cadena lineal, y el desempate de GHOSTDAG (por hash) debe sustituirse
por `solution_distance` para que no sea molible re-firmando.

**A7 · Reducción.** Con A2 + A3 + A4 + A6, GHOSTDAG sobre PoST hereda la garantía de GHOSTDAG sobre
PoW (umbral 1/2·(1−δ) con k calibrado por la cola de Poisson sobre λ y Δ) multiplicada por el
factor acotado de double dipping de A3, que es el mismo que ya paga la cadena lineal. Es decir: el
DAG no introduce un vector de doble uso del espacio que la cadena lineal no tenga ya.

**A8 · Rendimiento (lo que se compra).** Con `σ = 1 s` el DAG permite bajar el tiempo de bloque
esperado por debajo del suelo `q ≥ 20` de C-SLOT-02 (ese suelo existe por colisiones de slot en una
cadena lineal). A `q = 10`: 12× latencia a inclusión, 1,75 GB/año de cabeceras. A `q = 1`: 120×,
17,5 GB/año de cabeceras. La seguridad por segundo de reloj es la misma que en lineal (misma fracción
de espacio del atacante); lo que mejora es la varianza: el mismo riesgo de reversión se alcanza en
menos tiempo de reloj porque hay más sorteos por segundo.

**A9 · Estructura.** Altura → posición en el orden total de GHOSTDAG. Caducidad de sectores
(C-EXP-02/04) → sobre esa posición, a profundidad > poda, donde el orden es inmutable. Archivado →
sobre la linealización, a profundidad K en tiempo. Constantes en bloques → en tiempo (madurez de
coinbase, MAX_REORG_LENGTH, VIDA_MINIMA, era). Coinbase por bloque → repensar (a q=1 son 31,5 M de
salidas/año).

## Lo que el agente principal ya sabe que NO está demostrado

- A3 sin número. A6 sin demostración (solo razonamiento, igual que en fork-choice-poas.md). A7 es
  una reducción informal, no un teorema. A8 "misma seguridad por segundo" es una intuición.
- No se ha mirado si rusty-kaspa asume PoW en algún sitio que importe (p. ej. en la calibración de
  k por dificultad, en el cálculo de `blue_work`, en la poda, en la validación de timestamps).
- La comparación con Filecoin (n-split, umbral ≈ 20 % con m=5 bloques/ronda, arXiv:2308.06955):
  el agente principal cree que GHOSTDAG no sufre n-split porque los honestos no se dividen (referencian
  todo). Esto NO está verificado.

---

## 2 · Informe D9 (Fable 5.1), íntegro

## Informe D9 — refutación de `dag-poas-argumento.md`

Scripts ejecutados en `/tmp/claude-1000/-home-katana-zeo/0cfccf9e-55ae-4058-bcf4-31f0987f1dbd/scratchpad/d9/` (`phi_c.py`, `kcal.py`, `reversal.py`, `peso.py`, `u3.py`, `chain_growth.py`). Papers extraídos en `.../scratchpad/papers/{bdk19,nsplit}.txt`.

### Dos errores de premisa que contaminan el argumento

1. **`LOOKBACK_DEPTH = 2` no son 2 bloques: son 2 intervalos = 100 bloques.** `pallet-subspace/src/lib.rs:942-947`: `lookback_in_blocks = interval * lookback_depth`; la entropía inyectada en el bloque `50j` viene del bloque `50j−100`. Pero el **momento** de la inyección es `slot(bloque 50j) + 15` (`:965-968`), es decir, lo fija el bloque en la **punta**.
2. **La inyección depende del slot en que se aplica, no solo de la entropía.** `sp-consensus-subspace/src/lib.rs:121-126` mezcla la entropía solo si `parameters_change.slot == next_slot`, y `pot.rs:290-295` hace `seed = blake3(entropy ‖ output_del_slot)`. Dos ramas con la misma entropía pero distinto slot de inyección tienen flujos de PoT distintos. Consecuencia: la ramificación de double dipping se produce en el bloque `50j` (profundidad 0), no a 100 bloques.

---

### A1 · «La prueba solo usa (i), (ii), (iii)» — SOBREVIVE CON SUPUESTOS (dos propiedades omitidas)

La prueba (ePrint 2018/104, App. A) usa además:

- **(iv) Tasa en tiempo de reloj.** §3.2 define α como «probabilidad de crear el siguiente bloque» sobre un único reloj. Bajo PoST la tasa de billetes es `espacio × velocidad_PoT`: un atacante con timelord más rápido consume más slots por segundo en privado. No es un supuesto del modelo; hay que absorberlo en α como hace el greenpaper (§1.1, ec. 2: `space_h·vdf_h > space_a·vdf_a·1.47`). A7 hereda «umbral 1/2·(1−δ)» en espacio; lo correcto es en espacio·vdf.
- **(v) Pasado ⊂ bloques anteriores.** §3.2: *«blocks can only reference blocks created before them»*; el Lema 14 (hourglass) y la cota del anticono de §4.2 lo usan para bloques honestos. Bajo PoST se sostiene solo si «creación» = autoría (`slot_worker.rs:394-405`: el bloque del slot `s` se autoriza cuando el PoT llega a `s+4`) y si hay una regla de slot sobre **todos** los padres (ver A5). Hoy C-HDR-05 (`SPEC.md:838`) es sobre un solo `prev_hash`.

Que el contenido se comprometa antes del puzzle **no** lo usa la prueba: el atacante del modelo ya elige padres y retiene arbitrariamente (App. A, «Assumptions»). La independencia entre bloques sí: es el proceso de Poisson de (i), que bajo PoST se rompe entre épocas de inyección (A3).

### A2 · «(i) la restaura el PoT» — SOBREVIVE CON SUPUESTOS

Dentro de una época, el desafío `blake3(salida_PoT ‖ slot)` es común (`subspace-verification/src/lib.rs:234-236`), y `verify_solution` no lee padres ni contenido (`:236-259`). Verificado. Supuestos no cubiertos: (a) que el flujo de PoT sea **único** para todo el DAG, lo que la propia propuesta no garantiza (A3); (b) que los billetes por slot sean Poisson: en el DAG cuentan **todos** los billetes (varios por slot y por granjero), lo que hace la tasa exactamente ∝ espacio —mejor que la cadena lineal, que descarta el segundo billete del mismo slot—, pero exige que la identidad U1 sea correcta (A4).

### A3 · «El double dipping residual es el de la cadena lineal» — REFUTADA

**Cuantificación (pregunta 2).** El greenpaper (§2.2, p. 18-19) no deriva el 1,47: lo toma de BDK+19 (arXiv 1910.02218v3, §5.4, ec. 39). Implementada la ecuación: `φ_c = −c·θ*/(ln(−θ*) + (c−1)·ln(1−θ*))` con `θ*` la raíz negativa de `−ln(−θ) − (c−1)ln(1−θ) = −1 + (c−1)θ/(1−θ)`. Reproduce la Tabla 3 (c=1..10) y da **φ₁₆ = 1,4678** (el 1,47 de Chia) y **φ₅₀ = 1,2815**, umbral 1/(1+φ₅₀) = 43,8 % del recurso. VERIFICADO COMPUTACIONALMENTE. El mapeo ZEROX→c=50 es exacto en lo que importa: cada elección de bloque frontera (qué billete usar como bloque `50j`) crea un flujo distinto por el punto 2 de arriba; el rezago de 100 bloques en el **contenido** no reduce el número de ramas, solo desplaza su efecto (que la tasa de crecimiento del BRW no cambie con rezago es PLAUSIBLE, NO DEMOSTRADO; BDK no lo analiza).

**Por qué el DAG lo cambia.** φ_c es una cota sobre la **profundidad** de un árbol privado en el que las ramas son excluyentes: en la cadena lineal, los billetes obtenidos bajo el flujo Y no pueden sumarse a la cadena X. En un DAG inclusivo, los bloques válidos bajo Y (su PoT verifica contra la historia de inyección de su propio pasado) pueden ser **referenciados** por bloques de X y contarse azules. El argumento no define ninguna regla que lo prohíba. Construcción: el atacante con fracción α elige `m` billetes distintos como bloque frontera → `m` flujos de PoT independientes → `m` conjuntos de billetes independientes de las mismas parcelas; los bloques de todos los flujos se referencian mutuamente (anticonos pequeños, todos azules) y la puntuación azul de su punta crece a `m·α·λ`. Supera a los honestos en cuanto `m > (1−α)/α` (m=4 para α=0,2); `m` crece en cada frontera. Umbral de seguridad → 0.

Si se añade la regla «un bloque es inválido si su pasado contiene bloques con historia de PoT inconsistente», el DAG deja de merger a través de inyecciones, y entonces la **posición ordinal `50j`** que fija el slot de inyección tiene que ser estable a 15 slots de profundidad. En una cadena lineal a q=120 lo es casi siempre (por eso `const_assert!(DELAY > AUTHORING_DELAY+1)`, `subspace-runtime/src/lib.rs:163-165`); en un DAG a q=1 hay ~8 bloques en ±4 s cuyo orden relativo depende del coloreado futuro. Nodos honestos discreparían del bloque `50j` → inyecciones distintas → bloques mutuamente inválidos → partición honesta sin atacante. La condición de A3 («profundidad ≥ poda») tendría que aplicarse también al **slot** de inyección, y eso no son las constantes heredadas (50, 2, 15): es otro diseño de inyección.

### A4 · U1-U4 restauran «un billete = un bloque contado» — SOBREVIVE PARCIALMENTE; U3 refutada como coloreado GHOSTDAG

**Lo demostrado.** Para cualquier bloque C y cualquier identidad de billete, `BLUE(C)` contiene ≤ 1 bloque con esa identidad: si X, X' ∈ past(C) y uno está en el pasado del otro, el posterior es inválido por U2 y C también (pasado inválido, §3.2); si están en anticono, U3 los pone rojos. DEMOSTRADO, condicionado a que U1 sea una identidad correcta.

**U1 refutada en su variante.** «El hash de la solución completa» no es identidad: `Solution` incluye `reward_address` libre (`subspace-core-primitives/src/solutions.rs:254-275`); cambiarla da un hash distinto a coste cero. La tupla `(public_key, sector_index, chunk, slot)` omite `history_size`, que forma parte del `SectorId` (`subspace-verification/src/lib.rs:225-229`). Laguna: si la tabla PoS admite más de una prueba para el mismo índice, un mismo `chunk` produce `masked_chunk` distintos (`:247-248`) y la identidad debería ser por `s_bucket`, no por `chunk`; no lo he verificado en `proving.rs`.

**U3 refutada como parte de GHOSTDAG.** Contraejemplo ejecutado (`u3.py`, k=3): honestos A, B sobre G; el atacante publica X (hijo de B); H1 referencia {X, A} y **X es su padre seleccionado**. El atacante publica X' (mismo billete, hijo de G); H2 referencia {H1, X'}. Cadena seleccionada de H2 = [H2, H1, **X**, B, G] y U3 exige X rojo. GHOSTDAG define la cadena seleccionada ⊆ azules y hereda `BLUE(sp)`; el Lema 12 (`score(C) ≤ score(B)+k si C ⇒ B`) y el proceso de Markov de la Prop. 8 se apoyan en esa herencia. Con U3 como posproceso, el coloreado sigue siendo función determinista del DAG (no depende del orden de llegada), pero **no es el objeto sobre el que está el teorema**. Además, si el atacante publica X'₁, X'₂ contra dos billetes ya contados, `score(H2) = score(H1) − 1`: decremento a voluntad del atacante, de efecto neto cero respecto a retener, pero fuera del caso peor que acota el Lema 9. No he encontrado forma de volver rojo un bloque honesto con U3 (solo colisionan identidades del mismo firmante, U4 correcto: la firma cubre la solución). La alternativa «pasado con dos identidades iguales → inválido» sí es explotable: X a media red, X' a la otra, nadie puede merger → partición con un billete.

### A5 · «Conocer el billete antes no añade poder» — SOBREVIVE CON SUPUESTOS

El slot no es moldeable: el desafío se deriva de `(PoT, slot)` y cambiarlo exige ganar otro sorteo (`:234-236`). RESPALDADO POR CÓDIGO. Modelo del "banco de billetes": el atacante guarda el billete del slot `s` y elige padres en `s+100`. Con una regla `slot(B) > slot(p) ∀p ∈ padres`, los padres admisibles son los mismos que en PoW con retención (bloques anteriores a `s`), la cuenta de bloques del atacante es idéntica (Poisson αλ) y `score(B)` depende solo de `past(B)`, así que la retrospectiva no cambia la distribución del anticono ni la puntuación. La información extra se limita a bloques honestos con slot < s publicados después de s (≤ 4 slots + D). Lo que **no** concede el modelo: (a) el timelord rápido (A1-iv); (b) esa regla de slot sobre todos los padres no existe y choca con «referenciar todas las puntas» cuando llegan puntas con slot mayor que el billete propio. Sin regla, el banco es ilimitado y (v) cae para bloques del atacante. La regla «slot muy anterior a los padres → rojo» es razonable, PLAUSIBLE, NO DEMOSTRADA.

### A6 · Peso `Σ ⌊2^128/(SR+1)⌋` invariante al reajuste — invariancia VERIFICADA; el reajuste sobre DAG REFUTADO

**Invariancia.** De `pieces_to_solution_range`, soluciones esperadas/slot = `P·SR/2^65`; por `⌊2^128/(SR+1)⌋` da `P·2^63·(1−ε)` con `ε ≤ 1/(SR+1)`. Con `SR_MIN = 2^11` (DECISIONES §23), ε ≤ 4,88·10⁻⁴; con SR ≥ 3·10⁶, ε < 10⁻⁶. Peso máximo 117 bits; 2⁴⁰ bloques caben en U256 (157 bits). VERIFICADO sobre 7 valores de SR incluidos los extremos. En el DAG la esperanza es exacta (cuentan todos los billetes); en la cadena lineal era `P(≥1)` por slot.

**El reajuste no transfiere.** La LWMA-1 de §19 mide slots **monótonos** de la cadena (`slot(H) > slot(H−1)` «por construcción»). En el DAG, los bloques azules en anticono tienen slots no monótonos en el orden, y si se mide solo la cadena seleccionada, ésta crece a ≈ `λ/(1+λD)` de la tasa total (simulado `chain_growth.py`, D=4 s: cociente 0,962 a q=120, 0,712 a q=10, 0,200 a q=1; coincide con la fórmula a ±1 %). Un retarget que exija «un bloque de cadena cada q slots» produce: q=120 → tasa total 1,09× la nominal; q=10 → **1,68×** (c = Dλ pasa de 0,4 a 0,67 y la calibración de k queda corta); q ≤ 4 → **no existe λ** (el crecimiento de cadena está acotado por 1/D = 0,25/s): el rango diverge a `SR_MAX`, la misma degeneración que §21 documenta para q=1 lineal. Kaspa lo evita midiendo `min/max timestamp` de una ventana de bloques azules y promediando targets (`rusty-kaspa/consensus/src/processes/difficulty.rs`, `calculate_difficulty_bits`): es otro retarget, no LWMA-1.

**Ataque P-014 sobre DAG.** Con SR por bloque (como `blue_work`), el atacante que espacia su sub-DAG sube su SR y baja su peso por bloque; la tasa de peso es invariante en esperanza. No infla. Pero el Teorema 4 está probado para `score = |azules|` con λ constante (§3.2, nota 6); con pesos y retarget por rama, ni el paper ni Kaspa aportan demostración. PLAUSIBLE, NO DEMOSTRADO.

### A7 · Reducción — REFUTADA como está escrita

«El DAG no introduce un vector de doble uso que la lineal no tenga» es falso por la construcción de A3 (merge entre flujos de PoT). Además: umbral en espacio·vdf, no en espacio; teorema sobre conteo, no sobre peso; U3 fuera del objeto probado. Lo que sobrevive es una **conjetura** con al menos cuatro hipótesis nuevas.

### A8 · «Misma seguridad por segundo, menor varianza» — REFUTADA (la primera mitad) 

Modelo de carrera en tiempo continuo (déficit Skellam, alcance `(α/(1−α))^{d+1}`, `reversal.py`). Con α = 0,25 y t = 600 s: q=120 → P = 0,140; q=1 → 4,6·10⁻³⁷. No es «la misma seguridad por segundo»: es exponencialmente más a igual reloj, que es lo que dice la segunda frase de A8; la primera se contradice con la segunda. Pero la cota del propio paper (Prop. 8: el atacante arranca con ventaja 3k por freeloading y los honestos crecen a (1−α)(1−δ)) con k=18 da P ≈ 1 a t = 60 s y 1,2·10⁻²⁴ a 600 s: en horizontes cortos la cota del DAG es **peor** que la lineal a q=120, aunque el paper avisa que sus constantes «are far from tight». Cotas: cabeceras a q=1 son 17,5 GB/año solo con un `prev_hash`; cada padre extra añade 32 B, y a λD=4 hay varios padres por bloque: la cifra es cota inferior.

### A9 · Estructura — PLAUSIBLE, NO DEMOSTRADO

Nada refutable porque nada está definido: la posición ordinal es inestable a poca profundidad (afecta a inyección, A3), los rojos ocupan posiciones, C-EXP-04 exige el hash «de la cadena que se valida» (en DAG: del orden de `past(B)`), y `MAX_REORG_LENGTH` como parada dura sobre reordenaciones no tiene definición.

### Pregunta 7 · n-split de Filecoin

El mecanismo (arXiv 2308.06955 §6.1, p. 16) necesita dos cosas: que los honestos **no puedan merger** (en EC un tipset solo agrupa bloques con el mismo conjunto de padres, §3.2) y que las copias equívocas del atacante **sumen peso** a cada cadena (`w(T) = Σ|T_i|`, §3.3). En GHOSTDAG puro ninguna se da: los honestos referencian todas las puntas y cada bloque honesto cuenta en todo pasado que lo contenga si su anticono azul ≤ k; con U3 las copias equívocas valen cero. DEMOSTRADO que la división de peso no existe **bajo merge irrestricto**. Pero merge irrestricto es exactamente lo que A3 necesita prohibir, y con la prohibición el atacante recupera un split en cada frontera de inyección (dos candidatos a bloque `50j` a dos mitades de la red).

### Pregunta 8 · Calibración de k (ecs. 1-2, §4.2)

`c = Dmax·λ`, `f = max{ P(Poisson(2c) > k), 2c/(k+2c) }`:

| q | c | δ | k solo término Poisson | k con ec. (2) completa |
|---|---|---|---|---|
| 10 | 0,4 | 0,01 | 3 | 80 |
| 10 | 0,4 | 0,001 | 5 | 800 |
| 1 | 4 | 0,01 | 15 | 793 |
| 1 | 4 | 0,001 | 18 | 7 993 |

El segundo término de (2) fuerza `k > 2c(1−δ)/δ`. El propio ejemplo del paper (λ=1, 2D=7, k=16, §5) solo cumple el término de Poisson (cola 9,6·10⁻⁴; ratio 0,304), y el paper reconoce que ese término «does not vanish exponentially fast» y queda para trabajo futuro. Cualquier k «de Kaspa» es una calibración con el término de Poisson solo, no con la ecuación publicada. Además, **usar Δ = 4 s como Dmax es una conflación**: Δ es la ventana de autoría, Dmax la cota de propagación de bloque con cuerpo (dinámico por §11) más la latencia de verificar PoT (§24); no está medido.

---

### Resumen

**REFUTADAS:** A3 (merge entre flujos de PoT; inyección a profundidad 0 en el slot), A4-U3 (rompe cadena seleccionada ⊆ azules) y A4-U1 variante hash (reward_address libre), A6 en su parte de reajuste (LWMA-1 sobre slots no existe en DAG; diverge para q ≤ 4), A7, A8 primera mitad.

**NO DEMOSTRADAS:** A1 con (iv) y (v) añadidas; A2 (unicidad del flujo de PoT); A5 (regla de slot sobre todos los padres); A6 invariancia con pesos dentro del teorema; A9; que el rezago no cambie φ_c.

**COTAS CORREGIDAS:** 1,47 → φ₁₆ = 1,4678 y φ₅₀ = 1,2815 (umbral 43,8 %); «LOOKBACK 2 bloques» → 100 bloques y slot de la punta; k a q=1: 15/18 (Poisson) o 793/7 993 (ec. 2); cabeceras a q=1 ≥ 17,5 GB/año, no 17,5.

**Lo que habría que demostrar formalmente antes del SPEC:**
1. Una regla de validez de PoT en DAG (qué flujo verifica cada bloque) y demostración de que el merge no multiplica billetes.
2. Inyección de entropía (contenido **y** slot) desde un prefijo estable, con la constante de retraso derivada de la profundidad de convergencia del orden, y su φ_c resultante.
3. Teorema 4 sobre peso `blue_work` con retarget por rama y λ variable.
4. Un coloreado con unicidad de billete que conserve cadena seleccionada ⊆ azules (o una prueba nueva para U3).
5. Regla de slot sobre todos los padres compatible con «referenciar todas las puntas», y el umbral en espacio·vdf.
6. Un retarget para DAG (ventana de azules, no cadena) y su convergencia para el q elegido.
7. Medición de Dmax real y recalibración de k con el término de Poisson y justificación explícita de ignorar el segundo término de (2).

**Lo que no pude verificar:** multiplicidad de pruebas PoS por índice (identidad U1 exacta) en `proving.rs`; la tasa de crecimiento del BRW con rezago de inyección; si rusty-kaspa asume PoW en poda o validación de timestamps (solo leí `difficulty.rs`).

---

## 3 · Informe D8 (Fable 5.1), íntegro

He reunido toda la evidencia. Redacto el informe.

---

# Auditoría adversarial D8 — GHOSTDAG sobre PoAS (A1-A9, U1-U4)

**Fuentes leídas (no de memoria):** `rusty-kaspa @ c338d495` (clonado 2026-09-06), `subspace @ f8842d0`, SPEC §6.1/§7.5/§11/§12/§12.1/§16, DECISIONES §14-§26, los tres `research/*.md`, arXiv:2308.06955 (26 pp., extraído con pypdf), issue #2078 y PR #3072 vía `gh api`.

## Corrección previa a todo: la constante de inyección está mal leída

`POT_ENTROPY_INJECTION_LOOKBACK_DEPTH = 2` se mide **en intervalos de inyección, no en bloques**: *"Interval, in entropy injection intervals, where to take entropy for injection from"* (`pallet-subspace/src/lib.rs:200-202`) y `lookback_in_blocks = interval × depth` (`:942-947`). La entropía del bloque `N` (múltiplo de 50) sale del bloque **`N − 100`**; el *target slot* es `slot(N) + 15` (`:964-971`). El argumento (§Contexto) y el brief dicen "2 bloques". Efecto colateral sobre la cadena **lineal** ya decidida: a `T = 120 s`, 100 bloques son **3,3 h** de rezago frente a los 10 min de Autonomys a 6 s. §21 heredó "las tres constantes calibradas" sin reescalarlas al tiempo — patrón H-005.

---

## ATAQUE 1 · Bifurcación del PoT entre nodos honestos sin atacante (refuta A2/A3 en DAG)

**Precondiciones:** ninguna. Basta `q ≤ 120` y el DAG.
**Mecanismo:** el `PotParametersChange` (target slot, entropía) es función de *qué bloque ocupa la posición `N`* y *cuál la `N−100`* en la cadena seleccionada. En Autonomys eso es un bloque a 15 slots de profundidad (`:964-971`); en un DAG a `q = 1` la cadena seleccionada a 15-100 s de profundidad **no es estable**: Kaspa fija `MERGE_DEPTH_DURATION = 3600 s` y `FINALITY_DURATION = 43 200 s` (`constants.rs:70,81`) precisamente porque por encima de eso el orden cambia. Dos nodos con puntas distintas ven bloques distintos en la posición `N` → target slots distintos → el timekeeper de cada uno "reorganiza" su cadena de PoT (`sc-proof-of-time/src/source.rs:355-362, 391-396`; `lib.rs:27-30`: *"Can be called more than once in case of reorgs to override old slots"*). A partir de ese slot cada mitad de la red produce bloques con `pot_output` que la otra mitad rechaza (`InvalidProofOfTime`, `block_import.rs:415-421`).
**Coste:** cero. A `q = 1` la posición `N` es ambigua con probabilidad no despreciable en cada época de 50 s.
**Efecto:** **split** recurrente. Y si se define la validez del PoT relativa a la propia cadena del bloque (lo que hace Autonomys: `parent_pot_parameters`, `:400-413`), no hay split pero se abre el Ataque 2.
**Gravedad:** **crítica.** ESTADO: CONFIRMADO como incompatibilidad de diseño (constantes verificadas; el modelo de PoT del DAG no está definido en la propuesta — `dag-consenso-poas.md` §6 ya lo señalaba).
**Mitigación:** tomar entropía **y** target slot de un bloque de cadena a profundidad ≥ finalidad del DAG. Choca con la otra función de la inyección: acotar la ventaja de un VDF rápido (Baig-Pietrzak). Con lookback de 12 h, un atacante con `v = 2` conoce las entropías y puede llevar **12 h de adelanto** a la red. Las dos exigencias (rezago corto para el VDF, rezago largo para el DAG) son contradictorias; no hay fuente que las reconcilie. Laguna.

## ATAQUE 2 · Double dipping multi-stream contado dentro del DAG (refuta A7)

**Precondiciones:** validez del PoT relativa a la cadena seleccionada del bloque (única opción sin split, ver Ataque 1); inyección no final. Espacio `α` pequeño, 1 SSD, `S` núcleos.
**Pasos:** (1) En cada frontera de época el atacante coloca uno de sus billetes reales en una posición ≡ 0 mod 50 de *alguna* cadena eligiendo padres entre las puntas honestas (el `blue_score` se ajusta incluyendo o excluyendo puntas). Cada uno abre un stream de PoT propio con `target_slot = slot + 15`. (2) Corre un AES por stream (1 núcleo cada uno) y audita sus sectores contra los `S` desafíos por slot — límite IOPS: 4 TiB = 4 161 lecturas/slot/stream (§21), un SSD de 100 k IOPS aguanta **~24 streams**. (3) Sus bloques en cada stream son válidos respecto a su propia cadena; los honestos los fusionan como azules (anticono ≤ k) y su peso cuenta; su DAG privado fusiona sus `S` streams.
**Coste:** `S` núcleos + IOPS. Cero espacio adicional.
**Efecto:** cuota efectiva `Sα / (1 − α + Sα)`: con `α = 0,1`, `S = 10` → **52,6 %**. Inflación de peso → reorg/doble gasto.
**Gravedad:** **crítica.** ESTADO: SOSPECHA fuerte — depende de una regla (validez del PoT en DAG) que la propuesta no escribe; cualquiera de las dos opciones falla (split o esto).
**Mitigación:** la de Ataque 1 (un único stream global anclado a finalidad) elimina el vector; el precio es el adelanto del VDF.

## ATAQUE 3 · Copias rojas gratis alimentan el retarget y la emisión si se porta Kaspa

**Precondiciones:** portar `rusty-kaspa` tal cual en tres puntos verificados:
- DAA: `daa_score = sp + mergeset_size − non_daa` con `mergeset_size = blues + reds` (`difficulty.rs:27-30`; `ghostdag.rs:112`), ventana de dificultad con `descending_mergeset` que incluye rojos (`window.rs:308`).
- Coinbase: el subsidio de los rojos **se emite** y se paga al fusionador (`coinbase.rs:117-131`).
- UTXO: las transacciones de los rojos **se aplican** (`utxo_validation.rs:122` usa `consensus_ordered_mergeset`, que mezcla `mergeset_blues` y `mergeset_reds`, `ghostdag.rs:116-130`).

**Pasos:** un billete → hasta `max_block_parents` copias (Kaspa a 1 bps: 10, `bps.rs:57-73`) referenciadas como padres por el siguiente bloque real del atacante. Las copias son rojas por U3 pero (a) entran en el `mergeset_size` → el DAA ve `×11` bloques por billete → el rango se estrecha; ZEROX recupera hacia ancho a 11 %/bloque (§23.6: ÷100 tarda 52 h); (b) con la coinbase **dentro del bloque** (C-HDR-08, `merkle_root`) y las txs de rojos aplicadas, **cada copia acuña su coinbase**.
**Coste:** 1 billete por 10 coinbases.
**Efecto:** **inflación ×10** sobre la cuota del atacante, más congelación progresiva del ritmo de bloques.
**Gravedad:** **inflación / alta.** ESTADO: CONFIRMADO condicional (el código citado hace exactamente eso; la propuesta no dice que se aparte de él).
**Mitigación:** (i) DAA y emisión **solo sobre azules** (bajo PoST el rango no altera cuotas, §19, así que ignorar rojos no distorsiona); (ii) la coinbase de un bloque rojo **no se aplica** — decidible al fusionar, determinista; (iii) consecuencia dura: el modelo "recompensa = salida de la coinbase del propio bloque" (§22, C-HDR-08) es incompatible con que el color se decida *después*; Kaspa lo resuelve con **el fusionador paga** y una `script_public_key` declarada en el bloque fusionado — es decir, `reward_address` **vuelve** a la cabecera. A9 lo llama "repensar"; es rediseño de §22 y C-EMIT.

## ATAQUE 4 · U3 tal como está escrita no es implementable, y su forma sana cambia el argumento

**Hecho:** en GHOSTDAG el color de un bloque lo fija el bloque que lo fusiona, una vez, como función de `past(C)` (`protocol.rs:126-166`); se persiste en `GhostdagData` y `blue_work`/`blue_score` de todos los descendientes dependen de él. "Colorear rojos **ambos**" exigiría recolorear `A1` cuando llega `A2` → o se recomputa todo el futuro de `A1` (los nodos divergen según *cuándo* vieron `A2`: no determinista), o no se hace. La única forma determinista es **U3′: un candidato cuya identidad ya está en el pasado azul del bloque fusionador es rojo; si dos copias caen en el mismo mergeset, la primera en el orden (`sort_blocks`: `blue_work`, hash — `ordering.rs:38-42`) es azul**. Con U3′ la "simetría" de U3 desaparece pero el griefing sigue cerrado (ver lista de descartados).
**U2 es redundante:** si `slot(B) > slot(p)` para *todos* los padres (generalización de C-HDR-05), dos copias comparten slot y ninguna puede estar en el pasado de la otra. No hace falta índice por identidad en consenso; solo para la capa de red.
**Red:** relayar **una** cabecera por identidad (`public_key‖sector_index‖chunk‖slot`, en claro), servir las demás solo bajo petición como padre faltante; cachear `verify_solution` por identidad (entradas idénticas). Coste del atacante: ≤ `max_block_parents` copias procesadas por billete real.
**Gravedad:** media (hueco de especificación). ESTADO: CONFIRMADO.

## ATAQUE 5 · C-REORG-07 a q = 1: apagado por partición de 100 segundos

**Precondiciones:** A8 (`q = 1`) con `MAX_REORG_LENGTH = 99` en bloques. "Profundidad de reorg" en GHOSTDAG = bloques de cadena seleccionada retirados (`chain_path.removed`, `virtual_processor/processor.rs:369-373`).
**Pasos:** partición honesta de ~4-5 min con ≥40 % del espacio en el lado menor (a 1 bloque/s ese lado construye >99 bloques de cadena); al reconectar, la cadena más pesada lo desplaza → `ReorgDemasiadoProfunda` → `exit` (§16). Variante dirigida: eclipse de un nodo (C-NET-20 lo encarece pero no lo impide) y alimentarle un sub-DAG del atacante con 100 billetes reales (`α = 0,1` → ~17 min); las copias no sirven porque una cadena contiene a lo sumo una copia por billete.
**Coste:** partición natural, o 17 min de eclipse con 10 % del espacio.
**Efecto:** **apagado** masivo o dirigido (DECISIONES §24).
**Gravedad:** alta. ESTADO: CONFIRMADO.
**Mitigación:** Kaspa no apaga: ignora puntas que no descienden del punto de finalidad (`processor.rs:298-306`, `sink_search_algorithm :1013-1035`), con finalidad en **tiempo** (12 h). A9 dice "constantes en tiempo"; hay que decirlo también de C-REORG-07 y de su semántica de fallo.

## ATAQUE 6 · A8 propone un q que la calibración no puede representar

`pieces_to_solution_range` **desborda `u64` con `q = 1`** (DECISIONES §23.4) y C-SLOT-02 fija `q ≥ 20` porque LWMA-1 sobre slots no converge por debajo de 6. En un DAG el objetivo del retarget ("un bloque cada q slots") no existe; Kaspa reajusta sobre la duración de una ventana muestreada por `blue_work` (`difficulty.rs:166-198`), con timestamps que bajo PoST se sustituyen por slots. Nada de esto está derivado. `q = 1` y `q = 10` de A8 son hoy números sin función de calibración detrás.
**Gravedad:** media (bloquea A8). ESTADO: CONFIRMADO.

## ATAQUE 7 · La poda y la IBD de rusty-kaspa son PoW

`parents_by_level` en la cabecera (`header.rs:141`), `check_indirect_parents` (`post_pow_validation.rs:55-77`), `level_work` (`difficulty.rs:223-231`) y toda `pruning_proof/` (`build.rs:145-195`) se apoyan en `calc_level_from_pow` = ceros del hash (`consensus/pow/src/lib.rs:72-75`). Sin niveles no hay prueba de poda; sin poda, reachability crece `O(#cabeceras × mergeset_limit)` (`bps.rs:80-81`) sin cota: 31,5 M cabeceras/año a `q = 1`. Existe un análogo natural (`solution_distance ≤ SR/2^L` ocurre con prob. `2^{-(L-1)}`), pero es investigación, no adopción.
**Gravedad:** media. ESTADO: CONFIRMADO (laguna).

## ATAQUE 8 · Cliente ligero (§26): verificar cabeceras no verifica el DAG

Verificar solución + 2 KZG por cabecera (§26 B) no dice qué bloques son azules ni cuál es la cadena seleccionada: el coloreado exige reachability sobre todo el DAG. `blue_work` en la cabecera de Kaspa es una **afirmación del minero** que solo un nodo completo comprueba (`post_pow_validation.rs:47-53`); bajo PoST afirmarla es gratis. Un servidor mentiroso presenta un sub-DAG con `blue_work` inventado y la wallet no puede distinguirlo sin bajar todo: 2,63 M cabeceras/mes = **1,46 GB/mes**, 58 min de CPU (×3 en móvil) por ancla de release de un mes. Kaspa no tiene SPV por esta razón.
**Gravedad:** media (privacidad/confianza; A8 "17,5 GB/año" ya lo admite pero §26 no sobrevive).

## Menor · A5 invierte la dirección

"Bloque cuyo slot es anterior en más de X al de sus padres" no puede ocurrir con slots monótonos. La regla útil es sobre el **fusionador**: candidato con `slot < slot(C) − X` → rojo (o inadmisible, como `check_bounded_merge_depth`, `post_pow_validation.rs:79-101`). Es determinista y sí es más fuerte que en PoW. Nota: Autonomys no tiene regla de equivocación en consenso (`verifier.rs:402` `TODO`; PR #3072, 2024-10-01: *"Remove problematic equivocation"*): U1-U4 son originales, sin precedente desplegado.

---

## ATAQUES PROBADOS Y DESCARTADOS

- **n-split (arXiv:2308.06955 §6.1, pp. 16-17):** funciona porque cada honesto elige *un* tipset padre y las copias con igual peso los dispersan. En GHOSTDAG los honestos referencian todas las puntas; con U3′ la copia extra es roja y no altera el anticono azul; el `blue_work` honesto no se divide. No encontrado — **condicionado a U3′**; sin regla de unicidad, k+1 copias en una capa son todas azules (anticono mutuo = k ≤ k) y un 5 % de espacio se lleva 19× peso: la propuesta lo sabe (A4).
- **Griefing: volver rojo un bloque honesto con copias:** el k-cluster cuenta anticono *azul* (`protocol.rs:194-218`); a lo sumo una copia por pasado es azul; enrojecer exige k+1 billetes distintos, igual que en PoW.
- **Rango ancho en sub-DAG propio para inflar anticonos con bloques baratos:** el padre seleccionado lo impone GHOSTDAG (máximo `blue_work`, `protocol.rs:99-106`), no el autor; si referencia puntas honestas, hereda su rango; si no, sus bloques son rojos por k o inadmisibles por merge depth. Requiere que `rango_esperado` sea función de la cadena seleccionada (o del pasado completo como el DAA de Kaspa), nunca elegible.
- **Moler `solution_distance`:** es función de `global_challenge`, `sector_slot_challenge` y el chunk (`subspace-verification/src/lib.rs:234-259`); no hay grado de libertad. Varios chunks ganadores por s-bucket (`auditing.rs:237-270`) son billetes lineales en espacio. El desempate final por hash sigue siendo molible por coinbase, pero en un DAG solo decide padre seleccionado entre puntas de igual `blue_work` — efecto acotado a orden de txs.
- **Selfish farming con Δ = 4:** los padres deben tener `slot < s`, así que retener no permite referenciar más; el bloque para el slot s se construye en s+4 para todos (`verifier.rs:267`, `block_import.rs:441`). El adversario del modelo (iii) ya retiene y elige padres. No encontrado nada que PoW no tenga, salvo un VDF más rápido, que es el factor de Chia y no es del DAG.
- **Balance attack sin partición:** un bloque tardío sobre la rama ligera no supera el `blue_work` de la punta que ya fusionó ambas. Necesita partición (cubierto por Ataque 5).
- **DoS con millones de identidades:** identidades reales cuestan espacio; falsas cuestan al receptor 1,32 ms (KZG) — el mismo problema que la cadena lineal, no del DAG.
- **Caducidad de sectores por posición (C-EXP-02/04):** el orden dentro del mergeset de un bloque de cadena es fijo; solo cambia con reorg de cadena, que la finalidad acota. A `q = 1`, `VIDA_MINIMA = 65 536` bloques = 18,2 h > 12 h de finalidad de Kaspa: pasa, con poco margen y sin derivar.

## NO PUDE ANALIZAR

- Cuantificar A3 (factor de double dipping con 50 bloques/época) y la validez de la calibración de k (`bps.rs:9-21`, Poisson con `x = 2Dλ`) bajo el proceso por slot de PoST: sin simulación.
- El coste real de reachability sin poda a 31,5 M cabeceras/año.
- El hilo del foro de Autonomys sobre equivocación (`forum.autonomys.xyz/t/3063`) y las discusiones de GitHub: solo issue/PR.
- Comportamiento de `check_equivocation` de `sc-consensus-slots` (ventana de slots): no leído.
- El umbral del 20 % de Filecoin se leyó de §6 y el abstract, no del Teorema 4.

**Ficheros:** `/tmp/claude-1000/-home-katana-zeo/0cfccf9e-55ae-4058-bcf4-31f0987f1dbd/scratchpad/rusty-kaspa`, `/tmp/claude-1000/-home-katana-zeo/0cfccf9e-55ae-4058-bcf4-31f0987f1dbd/scratchpad/nsplit.txt`, `/tmp/claude-1000/-home-katana-zeo/32d96f16-7425-4b44-82ef-7ba7960e327c/scratchpad/pos/subspace`.
