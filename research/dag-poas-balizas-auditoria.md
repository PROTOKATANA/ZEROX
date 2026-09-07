# Balizas + exclusividad por clave — auditoría D9+D8 (quinta ronda) y cierre definitivo

**Fecha:** 2026-09-08 · Audita `dag-poas-balizas-exclusividad.md` · D9 y D8 en Sonnet 5, ambos
completos · Scripts en el scratchpad de la sesión (`d9/{sybil_dominancia,deriva_x1,
baliza_acuerdo,phi_baliza}.py`, `d8b/*`).

## 0 · Veredicto

**El arreglo (i), las balizas, es el primer resultado limpio de las cinco rondas.** D9 lo demostró
exacto, no aproximado: con retardo de red acotado `U(0,D)`, `Λ = D` basta para que el acuerdo
honesto sobre el inyector sea perfecto (0 discrepancias en 200 000 réplicas). Recrea dentro de un
DAG rápido la rareza que hace única al bloque 50j de la cadena lineal, sin frenar el DAG.

**El arreglo (ii), la exclusividad por clave, cae, y con él la propuesta entera.** D8 encontró que
cae por dos vías, la propia y una más barata:

1. **Sybil de claves (la que el propio autor señaló sin cerrar).** D9 verificó en el código de
   Autonomys que el contenido de un sector SÍ está ligado a la clave (`SectorId` es un hash con
   clave), así que partir el espacio entre dos claves cuesta ploteo. Pero ese coste **no protege
   nada**: el ploteo escala con bytes totales, no con número de identidades. Plotear `S` bytes bajo
   una clave o repartirlos en `N` claves de `S/N` es el mismo trabajo total, y el pago esperado de
   cubrir `N` relojes con `N` claves es `N` veces el de cubrir uno solo: dominancia estricta,
   verificada algebraicamente. D8 dio el número: replotear la mitad de 1 PiB cuesta entre 26 y 507
   días según hardware, un coste **de una sola vez, amortizable, no infinito**, que compra cobertura
   perpetua de los dos relojes.
2. **Alternancia entre épocas (más barata, sin Sybil).** D8 encontró que una lectura literal de la
   regla de castigo (X-2, «misma época, reloj distinto») nunca se dispara si una sola clave alterna
   de reloj en épocas sucesivas: A en la época k, B en la k+1, A en la k+2. Coste cero, sin
   replotear nada. Es un fallo de redacción, pero deja la puerta abierta igual de ancha.

**D9 fue más allá de auditar el mecanismo: demostró por qué NINGUNA variante de exclusividad puede
funcionar dentro de las reglas que PoAS ya fija.** Cualquier regla «una identidad-X publica bajo un
solo reloj» —sea X la clave, el sector, o cualquier otra unidad— es derrotable partiendo el espacio
entre tantas identidades-X como relojes existan, **mientras crear una identidad-X nueva cueste lo
mismo por byte que no crearla**. Es cierto por linealidad del ploteo más gratuidad de identidad, y
se sostiene para cualquier partición. Para que la exclusividad funcionara haría falta que crear una
identidad costara algo no proporcional al espacio que representa —un depósito, una tasa fija por
clave— y eso ya no es «exclusividad por espacio»: es importar un recurso ajeno al espacio, que es
justo lo que el proyecto rechazó al elegir PoST en vez de PoS.

**Consecuencia:** sin la exclusividad, la deriva vuelve a ser cero (D9 lo verificó algebraicamente,
misma estructura que la ronda 3) y el anclaje de la ronda 4 vuelve a costar los mismos 372-847
slots de siempre. El arreglo (ii) no cierra nada; solo desplaza el problema.

## 1 · Lo demás que encontraron

**D8:** una baliza retenida hasta el borde exacto del corte divide a los honestos según su retardo
de red, `P(a tiempo) = ε/D` controlable por el atacante: split activable cada ~15 minutos con coste
cero. Con la tasa de una baliza por intervalo, `P(0 balizas) = 31 %` (D9 confirmó el número y lo
subió a 75 % con j = 10): un tercio de los intervalos no tiene inyector y la propuesta no dice qué
pasa. El compromiso de madurez de sector (§3) es una laguna auto-referencial: si se compromete al
identificador, es trivial de satisfacer sin plotear nada; si se compromete al contenido real, ya
cuesta lo mismo que plotear, y no añade nada sobre exigir tiempo transcurrido sin más. Griefing del
castigo por nodos duplicados (el caso real de Spacemesh), sin mitigación.

**D9:** φ mejora sobre φ₅₀ solo para α ≥ 0,25, y es falso para α = 0,10 — el mismo patrón de la
ronda 2 (cierto por casualidad a un α, falso a otro). `c_a = α·λ·I_b`, no `λ·I_b`: la refutación de
la época en tiempo de la ronda 2 aplica aquí igual. El `Λ ≫ D` del diseño confunde dos magnitudes:
`Λ = D` basta para el acuerdo honesto sobre la baliza, pero el anclaje adversarial necesita los
372-847 slots de la ronda 4, y el diseño no lo distingue.

**Reconocido a favor de la propuesta (D8 y D9 coinciden):** la rareza de las balizas acota el spam
de candidatos que mató a la tercera ronda en unas 256 veces, y el lookahead de ploteo dirigido
mejora frente a las rondas 2 y 4.

## 2 · Lo que cinco rondas dejan demostrado, ya como teorema y no como intuición

**El núcleo no es "hace falta un evento acordado a profundidad cero e impredecible" en abstracto.
Es más preciso: cualquier mecanismo de exclusividad entre relojes en PoAS permisionless es
derrotable por partición de identidad, porque el coste de producir espacio es lineal en bytes e
independiente de cuántas identidades lo reclamen, y las identidades son gratis por diseño.** Es la
razón por la que PoW nunca tuvo este problema: un hash no se puede subdividir en dos intentos que
cuenten para dos loterías distintas al mismo coste marginal. Un sector plotado sí, mientras nada
ate el sector a un reloj concreto en el momento de crearlo — y atarlo exige que el reloj exista
*antes* de plotear, que es circular con el problema que se quiere resolver.

**P-038 sigue cerrada, ahora con un teorema en vez de cinco refutaciones sueltas.** La única vía no
lineal que escapa a este límite sigue siendo **espina + fardos**: los fardos no pesan, así que no
hay ningún incentivo a partir identidades para cubrirlos, y sin peso en juego el argumento de
dominancia estricta de D9 nunca se activa.

## 3 · Lo aprovechable, con independencia del DAG

- El resultado de balizas (`Λ = D` basta para el acuerdo bajo retardo acotado) es limpio y
  reutilizable si algún día el proyecto necesita un evento raro y acordado dentro de cualquier
  estructura, DAG o no.
- El argumento de D9 sobre linealidad del ploteo más gratuidad de identidad es una herramienta para
  evaluar cualquier propuesta futura de "exclusividad" en PoAS antes de escribirla: si la unidad de
  exclusividad es subdivisible a coste marginal proporcional, está descartada de raíz.

---

## Anexo A · Informe D9 (Sonnet 5), íntegro

# Informe D9 — refutación de `dag-poas-balizas-exclusividad.md`

He leído la propuesta entera, mis cuatro informes previos (`dag-poas-auditoria.md` §2, `dag-poas-inyeccion-auditoria.md` Anexo A, `dag-poas-candidatos-auditoria.md` Anexo A §2, `dag-poas-voto-auditoria.md` Anexo A §2), `dag-nativo-poas-propuesta.md` §2, y el código de Autonomys (`f8842d0`, `subspace-core-primitives/src/sectors.rs`, `subspace-verification/src/lib.rs:225-260`). Scripts nuevos en `.../scratchpad/d9/`: `sybil_dominancia.py`, `deriva_x1.py`, `baliza_acuerdo.py`, `phi_baliza.py`.

## Pregunta 1 — Sybil de claves (LA QUE DECIDE TODO LO DEMÁS)

**(a) ¿Obliga `SectorId` a replotear al cambiar de clave? Sí, y está en el código.**

`subspace-core-primitives/src/sectors.rs:56-68`:
```rust
Self(blake3_hash_list_with_key(&public_key_hash, &[&sector_index.to_le_bytes(), &history_size.get().to_le_bytes()]))
```
`public_key_hash` es la **clave** de un hash con clave (keyed hash), no un dato más concatenado: cambia el `sector_id` de forma no correlacionada con el anterior. Y `derive_piece_index` (líneas 86-113) usa `self.as_ref()` (el `sector_id`, ya keyed por clave) como clave de un segundo hash para decidir **qué piezas de la historia archivada** entran en cada posición del sector; `derive_evaluation_seed` (líneas 126-130) —la semilla con la que se calcula la tabla de espacio (`is_proof_valid`, `subspace-verification/src/lib.rs:240-246`)— también deriva de `sector_id`. **Conclusión: el contenido físico de un sector plotado para K1 no sirve para K2.** Relabelear es imposible; hace falta replotear. La afirmación implícita del ataque («la clave es gratis, luego partir el espacio es gratis») es **literalmente falsa a nivel de bytes**. Cito código: `sectors.rs:56-68,86-130`; `subspace-verification/src/lib.rs:225-232,240-246`.

**(b) ¿Vuelve la deriva cero pese a (a)? SÍ — el coste de replotear no es una barrera económica.**

El error está en confundir «cuesta replotear» con «cuesta más». `sybil_dominancia.py` lo hace explícito: el ploteo escala con **bytes totales**, no con número de identidades. Plotear `S` bytes bajo 1 clave o repartir esos mismos `S` bytes entre `N` claves de `S/N` cada una es el **mismo trabajo total** (son `N` ploteos independientes de `S/N`, cuya suma es idéntica al ploteo de `S`). Un granjero que **arranca** repartiendo su espacio entre `N` claves nunca paga nada extra. Y un granjero que ya tiene `S` plotado bajo K1 y quiere migrar una fracción a K2 sí paga un coste de conversión, pero es **de una sola vez** y se amortiza en el reploteo que Subspace **ya exige** por expiración de sector (`derive_expiration_history_size`, `sectors.rs:135-164`: todo sector caduca y se replotea periódicamente como parte del mantenimiento normal). Por linealidad de la recompensa en el espacio (el propio §2 lo admite: «un sector gana ~2·10⁻⁴ veces por época»), el pago esperado de cubrir `N` relojes con `N` claves de `S/N` es exactamente `N·(S/N)/S_total·λ = S/S_total·λ` **por reloj**, cobrando en los `N` relojes: dominancia estricta, verificada algebraicamente en el script (factor `×N` exacto, sin aproximación). Es la **misma estructura** que refuté en ronda 3 (`can_candidatos.py`, cobertura racional de flujos), ahora mediada por identidades en vez de por publicar el mismo billete dos veces —que X-1 sí bloquea, pero no es lo que hace falta bloquear.

**(c) ¿Existe una variante de X-1 atada al espacio, no a la clave? Declaro imposible, con derivación.**

El propio §2 ya mostró por qué la exclusividad por **sector** no muerde: `P(el mismo sector gana bajo los dos relojes) ≈ 4·10⁻⁸`, así que un granjero cubre ambos relojes con sectores **distintos** sin que la regla se dispare nunca. Eso no es una carencia de esa variante concreta: es una consecuencia de que **la unidad de recompensa (sector) es infinitamente subdivisible sin coste marginal más allá del ploteo, que ya se paga por byte con independencia de cuántas identidades lo etiqueten**. Cualquier regla «una identidad-X publica bajo un solo reloj» —sea `X` = clave, sea `X` = sector, sea `X` = lo que sea— es derrotable partiendo el espacio total entre tantas identidades-X como relojes existan, **mientras crear una identidad-X nueva cueste lo mismo por byte que no crearla**. Eso es cierto por construcción en un sistema donde (i) las claves son gratis y (ii) el ploteo es lineal en bytes e independiente del número de claves. Para que una regla de exclusividad funcione haría falta que **crear una identidad cueste algo que no sea proporcional al espacio que representa** —un depósito, un bono, una tasa fija por clave independiente del tamaño— es decir, importar un recurso ajeno al espacio. Eso ya no es «exclusividad por espacio»: es un recurso nuevo. **Declaro la variante puramente-por-espacio imposible dentro de PoAS permisionless**, no por falta de ingenio sino por un argumento de linealidad + gratuidad de identidad que se sostiene para cualquier partición.

| Afirmación | VEREDICTO |
|---|---|
| Partir el espacio en dos claves cuesta ploteo (X-1 tiene precio) | **DEMOSTRADO** a nivel de bytes (código citado), pero **REFUTADO** a nivel económico |
| «Con X-1 el peso honesto no se reparte» (§2, línea 79-81) | **REFUTADA** — vuelve la deriva cero de la ronda 3, mediada por Sybil de claves |
| El atacante del §8.2 que el autor no cierra | **CONFIRMADO ROTO.** Es el resultado central de este informe |

## Pregunta 2 — deriva con X-1 «si la Sybil no funcionara»

Bajo la hipótesis contrafactual (Sybil bloqueada), y con la exclusividad de un único switch (X-2): `deriva_x1.py` confirma que si todos los granjeros son **conservadores** (solo cambian de reloj cuando ya observan a `B` claramente por delante), la deriva es exactamente `(1−2α)λT` más el handicap inicial `h0` — la fórmula del §2 **SOBREVIVE**. Pero si una fracción `f` de granjeros es «nerviosa» (cambia de reloj **antes** de que haya evidencia, por creencia privada), la deriva se degrada linealmente en `f`, y con `h0=0` (el caso crítico de la ronda 4: al inicio de un anclaje el handicap es cero) y `f≈0,5` se observa **cascada completa hacia el reloj del atacante**, con probabilidad de ganar independiente de `α`. Es un equilibrio de información en cascada, no una degradación suave. **VEREDICTO: SOBREVIVE CON SUPUESTOS** (racionalidad estrictamente reactiva a evidencia), **PLAUSIBLE NO DEMOSTRADO** que ese supuesto se sostenga con creencias heterogéneas sobre quién ganará. **Y es un resultado enteramente secundario**: con Q1 la premisa (Sybil bloqueada) es falsa, así que esta sección no importa en la práctica —cubrir ambos relojes con dos claves domina estrictamente a cualquier estrategia de switch único.

## Pregunta 3 — acuerdo sobre balizas

`baliza_acuerdo.py`, Poisson(λ/2⁸) sobre `I_b=300s`, retardo **heterogéneo** `U(0,4)` por (baliza,nodo), 200 000 réplicas: `P(discrepancia honesta)` cae **a exactamente 0** en `Λ=D=4s` (0 discrepancias en 200 000 réplicas; a `Λ=3,9s` quedan `1,5·10⁻⁵`). Esto es un resultado **matemático exacto bajo el modelo**, no asintótico: con retardo **acotado** `U(0,D)`, toda baliza de slot `s<I_b` llega a cada nodo en `≤s+D`, así que `Λ≥D` implica agreement con probabilidad 1. **DEMOSTRADO** para el mecanismo de balizas en sí.

Pero comparar esto con los 372-847 slots de la ronda 4 es comparar magnitudes distintas: los 372-847 acotan `P(anclaje viable de un atacante)` (Skellam creciente sin cota mientras dure la ambigüedad), no la discrepancia honesta por propagación. El §4 fija «`Λ≫D`» sin más — si se interpreta como unas decenas de segundos (que es lo que «`≫D`» sugiere), es **el mismo error de subdimensionamiento que cacé en rondas 2-4** (`X<L` sin ligar `X` a `L`; `L≈600-900s` frente a los `372-847` reales): el `Λ` que cierra el mecanismo de balizas (`≈4s`) **no es** el `Λ` que cierra la elegibilidad `κ` frente a un atacante que ancla (pregunta 5, abajo). **VEREDICTO: la afirmación del §1 sobre acuerdo de balizas es DEMOSTRADA; el `Λ≫D` del §4 es insuficiente frente al anclaje y hereda la laguna sin corregirla.**

## Pregunta 4 — φ con inyector-baliza

`phi_baliza.py`, ecuación 39 de BDK con `c_a=αλI_b`, `I_b=300s`: **la afirmación «φ menor que φ₅₀» es cierta solo para `α≥0,25`** (`φ(75)=1,235<φ₅₀=1,282` a `α=0,25`; `φ(100)=1,207` a `α=1/3`), y **falsa a `α=0,10`** (`φ(30)=1,353>φ₅₀`, umbral `0,425<0,438`). Es el **mismo patrón exacto** que refuté en ronda 2 (`inyector_phi.py`, «cierto por casualidad» a un `α` y falso a otro). Además `c_a` **no depende de `j`** en la fórmula que da la propia propuesta — `j` solo determina cuántas balizas caen en `I_b` (`n̄=λI_b/2^j`): con `j=8,I_b=300s`, `n̄=1,17` y `P(0 balizas en el intervalo)=0,31`; con `j=10`, `P(0)=0,75`. **Un tercio (o tres cuartos) de los intervalos no tienen inyector**, y la propuesta no especifica qué pasa entonces (§4 no lo cubre). Sobre la época en tiempo (`I_b`), aplica **íntegramente** la refutación de mi ronda 2: `c_a=αλI_b`, no `λI_b`. **VEREDICTO: REFUTADA como afirmación universal; SOBREVIVE CON SUPUESTOS solo para `α≳0,2`; laguna nueva: intervalos sin inyector, no cubierta.**

## Pregunta 5 — elegibilidad por κ y anclaje

El §2 afirma que con X-1 el atacante «no puede reclutar a nadie: su rama crece a `αλ`». Con Q1 refutado, **eso es falso**: por Sybil de claves los granjeros racionales (incluidos los honestos) cubren el reloj anclado con una clave sobrante al mismo coste marginal cero, así que la rama anclada crece a algo cercano a `λ` completo, no a `αλ`. El argumento «deriva positiva ⟹ anclaje inviable» **se cae en su premisa**. La elegibilidad por `κ` sigue dependiendo del cono (el propio §1 lo admite: «sigue siendo dependiente del cono ⟹ anclable»), y sin la deriva prometida el coste del anclaje vuelve a ser exactamente el de la ronda 4: `h=max(0,H−Aa)` Skellam, `V` necesaria para `P≤10⁻⁹` es **372-847 slots**, no cerrado por X-1. **VEREDICTO: REFUTADA la afirmación «el cambio cualitativo de la propuesta» — hace falta profundidad, y es la misma profundidad de antes.**

## Pregunta 6 — lookahead, ploteo dirigido y madurez M

Como la deriva no se cierra, el lookahead relevante sigue siendo el de rondas 2-4 (33s-393s+ según el modelo), y el ataque de ploteo dirigido persiste con la misma severidad medida entonces (5,7-98 GiB/GPU). El fallo que el autor mismo declara (`history_size` no fuerza tiempo transcurrido) **sí necesita el arreglo de compromiso Merkle**, y su coste es una transacción por clave cada vez que cambia el conjunto de sectores — **coste asintótico lineal en el número de claves activas**, que con Sybil libre (Q1) puede crecer sin límite. El compromiso-por-clave sí introduce un **retraso de una vez** de `M` por clave nueva (no puede evitarse), pero no impide la partición: solo la pospone `M`. **VEREDICTO: `M` SOBREVIVE como palanca necesaria (no opcional, contra lo que dice §3), pero no cierra Sybil, solo la retrasa.**

## Pregunta 7 — ¿algún λ o j gana en umbral y lookahead a la vez?

No. La cadena causal es: X-1 falla en su premisa (Q1) ⟹ deriva cero ⟹ anclaje viable a la misma profundidad de siempre (Q5) ⟹ lookahead sin mejora estructural (Q6). Ningún `j` cambia esto (`j` solo entra en el mecanismo de balizas, que es la parte que sí funciona) y ningún `λ` cambia la linealidad del ploteo que hace la Sybil gratis. **Igual que en la ronda 3: no hay parámetro que rescate el núcleo.**

## Tabla de reglas

| Regla | VEREDICTO |
|---|---|
| Balizas: rareza dentro del DAG, acuerdo sobre inyector | **DEMOSTRADO** (Λ=D exacto, modelo acotado) |
| φ mejor que φ₅₀ (§1) | **REFUTADA como universal**; sobrevive solo `α≳0,2` |
| X-1 (exclusividad por clave) | **REFUTADA económicamente** — código confirma el precio en bytes, la economía lo anula |
| X-2 (una alternancia) | SOBREVIVE si Sybil estuviera bloqueada (no lo está); irrelevante en la práctica |
| X-3 (verificación barata) | **SOBREVIVE** — es cierto y barato, pero verifica una condición que no protege nada |
| X-4 (quema + inhabilitación) | **SOBREVIVE** como castigo del straddling, pero no toca el ataque de Q1 (no hay straddling) |
| «Deriva positiva ⟹ anclaje inviable» | **REFUTADA**, depende de X-1 |
| Madurez M | necesaria, no cierra Sybil |

## Cierre

**REFUTADAS:** X-1 y toda la cadena que depende de ella (deriva positiva, anclaje inviable, «cambio cualitativo de la propuesta») — impacto: **partición/deriva cero, idéntica a la de la ronda 3**, ahora vía Sybil de claves en vez de multi-flujo. §1 «φ menor que φ₅₀» como afirmación universal — impacto: umbral sobreestimado a `α` bajo.

**NO DEMOSTRADAS:** el equilibrio mixto de Q2 con creencias heterogéneas (irrelevante dado Q1) · sostenibilidad de `Λ≫D` frente al anclaje (nunca se deriva un número) · comportamiento con intervalos sin inyector (`P(0 balizas)` hasta 0,75 a `j=10`).

**COTAS CORREGIDAS:** «X-1 restaura deriva `(1−2α)λ`» → **deriva cero** (Sybil gratis, demostrado algebraicamente) · «φ menor que φ₅₀» → cierto solo para `α≥0,25`, falso a `α=0,10` · «acuerdo de balizas necesita Λ grande, comparable a los 372-847 de la ronda 4» → **Λ=D=4s basta para el acuerdo honesto**, pero el anclaje adversarial sigue necesitando los 372-847 slots (magnitudes distintas que la propuesta confunde).

**LO QUE NO PUDE VERIFICAR:** coste real de IOPS/almacenamiento de metadatos para gestionar N claves por granjero (D8) · si un umbral mínimo de espacio por clave activa mitigaría parcialmente sin resolver (no lo deriva la teoría, es un parámetro económico) · comportamiento exacto de la cascada de Q2 con distribuciones de creencia realistas.

### ¿Responde a las refutaciones de las rondas 3 y 4?

**No.** El arreglo (i) — balizas — responde de verdad y de forma limpia a un problema real (agreement sobre el inyector, D9 lo demuestra exacto). Pero el arreglo (ii) — exclusividad por clave —, que es el que existe específicamente para cerrar «cobertura racional de flujos ⟹ deriva cero» (ronda 3) y «semilla divergente anclada» (ronda 4), **no las cierra**: el código de Autonomys que el propio diseño usa como referencia (`SectorId` keyed por clave) demuestra que partir el espacio en identidades tiene un coste en *bytes* pero no en *economía*, porque el ploteo es lineal en espacio e independiente del número de identidades. El propio autor señaló este ataque como el que «más me preocupa y no tengo cerrado» (§8.2): la auditoría lo confirma roto, con cita de código.

### ¿Más cerca o más lejos que las cuatro anteriores?

**Más cerca en una mitad, exactamente en el mismo sitio en la otra.** El mecanismo de balizas es el primer resultado limpio y verificado computacionalmente de las cinco rondas para el problema de agreement sobre el inyector (Λ=D basta, exacto, no aproximado). Pero el núcleo — impedir que el peso honesto se reparta entre relojes — sigue sin resolverse, por la misma razón estructural de siempre: en PoAS permisionless, cualquier unidad de exclusividad (flujo, sector, clave) es subdivisible a coste marginal cero mientras el ploteo sea lineal en bytes e independiente de identidades, y las identidades sean gratis. Esta ronda no encontró el mecanismo que faltaba; encontró **por qué no puede existir uno** dentro de las reglas que PoAS ya fija (Q1c). Mi lectura de cierre sigue siendo la misma que en la ronda 3: la vía que no choca contra este límite es **espina + fardos** (`dag-nativo-poas-propuesta.md` §3), porque ahí no hay dos loterías (relojes/flujos) que cubrir — solo un anillo de segunda clase sin peso, y por tanto sin incentivo a partir identidades.

**Archivos:** `/home/katana/zeo/ZEROX/research/dag-poas-balizas-exclusividad.md`, `/tmp/claude-1000/-home-katana-zeo/0cfccf9e-55ae-4058-bcf4-31f0987f1dbd/scratchpad/d9/{sybil_dominancia,deriva_x1,baliza_acuerdo,phi_baliza}.py`, código citado en `/tmp/claude-1000/-home-katana-zeo/32d96f16-7425-4b44-82ef-7ba7960e327c/scratchpad/pos/subspace/crates/subspace-core-primitives/src/sectors.rs:56-164` y `subspace-verification/src/lib.rs:225-260`.

---

## Anexo B · Informe D8 (Sonnet 5), íntegro

# Auditoría D8 — quinta propuesta: balizas raras + exclusividad de reloj por clave

**Fuentes verificadas en código:** `subspace @ f8842d019cdf0f7163421b9644db5a9ff82b2a73` (`crates/subspace-core-primitives/src/sectors.rs:52-66`, `crates/subspace-verification/src/lib.rs:225-259`), `research/coste-ploteo-medido.md`, `research/dag-poas-auditoria.md` §3, `research/dag-poas-inyeccion-auditoria.md` Anexo B, `research/dag-poas-candidatos-auditoria.md` Anexo B, `research/dag-poas-voto-auditoria.md` §3, `research/dag-nativo-poas-propuesta.md` §2, `d8b/ghostdag_sim.py`.

## VECTOR 1 · Sybil de claves — SÍ FUNCIONA, y no hace falta ni siquiera replotear

`SectorId::new(public_key_hash, sector_index, history_size)` = `blake3_hash_list_with_key(&public_key_hash, [sector_index, history_size])` (`sectors.rs:52-66`). De ahí cuelgan `derive_evaluation_seed` (semilla de la tabla PoS) y `derive_piece_index`: **el contenido del sector sí está ligado a la clave**, así que crear un segundo sector para una segunda clave exige recodificar esa fracción de disco. Pero `derive_sector_slot_challenge` toma el `global_challenge` como parámetro externo (`sectors.rs:118-124`) — **el sector no está ligado a qué "reloj" lo audita**: el mismo sector plantado puede auditarse contra el desafío de A o el de B sin recodificar nada. Lo único que cambia entre usar clave K o K' es qué firma envuelve la cabecera ganadora.

**Coste de partir 1 TiB / 1 PiB en dos claves** (replotear la mitad, con las medidas de `coste-ploteo-medido.md`, sector ≈ 1 GiB):

| | 1 TiB (512 sectores a replotear) | 1 PiB (524 288 sectores) |
|---|---:|---:|
| CPU 32 hilos, 83,608 s/sector | 11,9 h | 507,3 días (un host) |
| GPU GTX 1070, 69,363 s/sector | 9,87 h | 420,9 días (una GPU) |
| GPU tope 2026 extrapolada, 4,28 s/sector | 36,5 min | 26,0 días (una GPU) |

Y para nuevas incorporaciones el coste es **cero**: un granjero que planea su capacidad decide desde el minuto uno plotear el 50 % bajo K y el 50 % bajo K'; no paga nada extra respecto de plotear 100 % bajo una sola clave. Para capacidad ya plantada, el replot es una inversión **única** que usa el mismo parque de hardware que ya tenía el granjero (si plantó 1 PiB, tiene el hardware para replotear la mitad en tiempo proporcional), y el beneficio (cobertura de ambos relojes) es **perpetuo**. X-4 no castiga esto: la prueba de infracción exige "la misma clave"; con dos claves no hay straddling que probar.

**Efecto:** reabre exactamente lo que mató a la ronda 3 — cobertura racional de flujos, deriva cero — con un coste acotado y amortizable, no infinito. El propio autor lo marca como el vector que más le preocupa; queda **confirmado**.

**GRAVEDAD:** split (estructural, mata la afirmación central de §2).
**MITIGACIÓN:** ninguna dentro del esquema; haría falta ligar el reloj auditable al sector en el momento del ploteo (p. ej. incluir `reloj_id` en `SectorId`), lo que exige plotear por separado para cada reloj **de verdad** — y aun así no impide tener dos claves, solo encarece cubrir ambas con el mismo espacio total (que es justo lo que ya cuesta el replot medido arriba).

## VECTOR 3 (recolocado primero por ser más barato) · Alternancia entre épocas — coste CERO, ni siquiera Sybil

X-2 define la infracción como "dos cabeceras... **misma época**, reloj_id distinto, con alternancia de vuelta (A, B, A)". Una clave que publica bajo A en la época k, bajo B en k+1, bajo A en k+2... nunca produce dos cabeceras de reloj distinto **en la misma época**: no hay prueba de infracción posible, sin importar cuántas veces alterne entre fronteras de época. Es una lectura literal de la regla escrita, no una interpretación forzada.

**Coste:** cero. Es la misma clave, los mismos sectores (el reloj no está ligado al sector, ver Vector 1). No hace falta replotear nada.

**Y peor:** nada en X-1..X-4 obliga a comprometerse pronto dentro de la época. Un granjero puede retener sus soluciones y, al final de la época, publicar bajo el reloj que vaya ganando (respetando "un solo reloj por época" literalmente). Responde a la pregunta que el propio §8.3 hace: gana ventaja estrictamente no negativa apostando siempre al ganador, sin arriesgar nunca el castigo de X-4.

**Efecto:** el "punto focal determinista" que sostiene la deriva positiva de §2 deja de ser algo a lo que los granjeros se comprometen ex-ante; se convierte en algo a lo que apuestan ex-post. Esto es más barato que el Vector 1 y logra el mismo objetivo estructural (recurso disponible en ambos relojes con el tiempo).

**GRAVEDAD:** split.
**ESTADO:** CONFIRMADO por lectura literal de X-2.
**MITIGACIÓN:** ninguna sin reescribir X-2 para que la ventana de infracción abarque varias épocas (lo que reintroduce la pregunta de cuántas, y con qué prueba se demuestra sin recuento centralizado).

## VECTOR 2 · Baliza retenida, liberada en el borde del corte — split del reloj focal, sin atacante económico

El corte es un slot **absoluto** (`t_k+I_b+Λ`), no relativo a cuándo cada nodo vio el evento. Con retardo heterogéneo por par nodo-nodo `~U(0,D)` (el mismo modelo que usan `voto_sim.py`/`ghostdag_sim.py` del proyecto), si el atacante libera su baliza (ganada con probabilidad α por ser la de menor slot) más su entierro κ ya construido en privado (coste: `κ/(αλ) ≈ 24/α` s — 72 s a α=1/3, trivial frente a `I_b+Λ` que son cientos de segundos) en `t_corte − ε`, un nodo la ve a tiempo solo si su retardo `≤ ε`. Con `ε = D/2`, el **50 % en expectativa** de los honestos la ve a tiempo (la considera enterrada y elegible) y el otro 50 % no (usa otra baliza, o ninguna, como inyector). No hace falta simular más allá del modelo analítico ya usado por el proyecto: es un resultado de teoría de colas cerrado, `P(a tiempo)=ε/D`, controlable por el atacante.

**Coste:** cero adicional — es exactamente el "1 bit" (publicar/retener) que la propia propuesta ya concede al atacante, más control de temporización de software, sin gasto de espacio extra. **Frecuencia:** el atacante gana la baliza de menor slot con probabilidad α por intervalo (α=1/3, I_b=300 s ⟹ un intervalo explotable cada ~900 s).

**Efecto:** exactamente el "split sin atacante" que mató a la ronda 1, ahora **activable a voluntad** cada ~15 minutos. Los honestos del lado minoritario, que respetaron X-1 y publicaron bajo el reloj que a ellos les pareció focal, pierden esos bloques cuando la red reconverge sobre el reloj más pesado (pérdida total, sin compensación: no hay mecanismo de recuperación descrito).

**GRAVEDAD:** split / pérdida-fondos. **ESTADO:** CONFIRMADO el mecanismo (modelo analítico, no simulación numérica completa por límite de tiempo — declarado como tal).
**MITIGACIÓN:** sin mitigación conocida distinta de exigir `Λ` mayor que cualquier ventana de retardo con margen de varios órdenes, lo que ya es la promesa de "Λ ≫ D" — pero el ataque solo necesita `ε < D`, no `Λ < D`; el margen grande no protege del borde exacto.

## VECTOR 5 · Intervalos sin baliza — 31 % de las épocas, laguna real

Con `j=8`, `λ=1`, `I_b=300 s`: media de balizas por intervalo `=300/256≈1,172`, **P(0 balizas)=e^-1,172≈31,0 %**. La propuesta no dice qué hace un fusionador cuando no hay ningún candidato: ¿la época no inyecta (el reloj "focal" queda indefinido), o se propaga el flujo previo sin cambio? Ninguna de las dos está escrita, y el §6 ("lo que NO resuelve") no la menciona — es una laguna **nueva**, no heredada. A esa frecuencia no es un caso raro: recrea el problema de las cuatro rondas (acuerdo sobre un evento) en **uno de cada tres intervalos**, sin necesidad de atacante.

**GRAVEDAD:** split. **ESTADO:** CONFIRMADO como laguna de especificación.
**MITIGACIÓN:** definir el caso explícitamente; ninguna opción es gratis (saltar la época castiga a los rezagados honestos igual que en N3 de la ronda 3).

## VECTOR 6 · Elegibilidad "en past(b)" reabre el anclaje de la ronda 4

"Enterrada bajo κ azules en past(b) en el momento del corte" es validez **relativa al fusionador**, la misma categoría de fallo que mató la ronda 2 y que la ronda 4 explotó con la "semilla divergente anclada" (D9, `dag-poas-voto-auditoria.md` §3, demostrado): un `b*` con padre seleccionado en un bloque honesto de slot `s*` y el resto de padres en la cadena privada del atacante tiene `past(b*)` legal (cierre hacia abajo) y dentro de él solo cuentan los azules del atacante. Con κ enterrable en 24–72 s (según α), el atacante ancla un cono donde SU baliza está enterrada y la honesta no. Esto es justo lo que §2 dice que X-1 neutraliza — pero solo si X-1 realmente concentra el peso honesto, cosa que los vectores 1 y 3 refutan.

**GRAVEDAD:** split. **ESTADO:** SOSPECHA fuerte (mecanismo idéntico al ya demostrado en ronda 4, no reejecutado numéricamente aquí por límite de tiempo).
**MITIGACIÓN:** validez absoluta de elegibilidad (a costa de reabrir el spam de candidatos de la ronda 3 — aunque, nota a favor de la propuesta, la rareza de balizas (~0,39 balizas del atacante por época a α=1/3) **sí acota ese spam** en ~256× respecto a la ronda 3: mejora real, cierre parcial reconocido.

## VECTOR 4 · Griefing del slashing — straddling accidental o inducido

X-2 evalúa "dos cabeceras... misma época" sobre cabeceras que existen, no sobre la cadena canónica: un granjero con dos instancias (el caso real de Spacemesh, que el propio documento cita) o eclipsado en el borde de una época puede terminar firmando A y luego B y luego A de vuelta sin intención, quemando su época y quedando inhabilitado P épocas. El documento reconoce la lección de Spacemesh pero no cierra cómo evitar la variante inducida (eclipsar al objetivo justo en el corte para forzarle a ver relojes distintos con sus dos instancias).

**GRAVEDAD:** pérdida-fondos / DoS dirigido. **ESTADO:** SOSPECHA (mecanismo verosímil, sin coste de espacio, requiere eclipse — C-NET-20 lo encarece, no lo impide).
**MITIGACIÓN:** ninguna citada; sin mitigación conocida.

Interacción con C-EMIT/pool blindado: si la ventana de prueba de X-4 no caduca con la madurez `P`, el ataque puede surgir después de que la coinbase ya se blindó, y quemar valor que ya entró al pool Orchard rompe el turnstile (no hay mecanismo de reversión de nullifiers). Si caduca con `P`, entonces la estrategia limpia del Vector 3 (nunca produce la tercera cabecera) escapa siempre — X-4 nunca se dispara contra el ataque más barato. **Laguna sin resolver en cualquiera de los dos casos.**

## VECTOR 7 · Compromiso de madurez de sector — vacío tal como está descrito

El §3 dice "raíz de Merkle por clave" del "conjunto de sectores" sin especificar a qué se compromete. Si es al `SectorId` (clave+índice+`history_size`, un blake3 barato, sin relación con haber plantado la tabla PoS), el compromiso es trivial de satisfacer sin plotear nada: comprometerse a IDs "fantasma" en `h`, esperar `M`, y plotear solo los que resulten ganadores una vez visibles los desafíos — exactamente el ataque que se quería cerrar. Si el compromiso fuera al contenido real de la tabla PoS, calcularlo YA cuesta los mismos 69-83 s/sector del ploteo, así que el granjero tiene que haber plantado honestamente de todos modos — lo cual no añade nada sobre simplemente exigir tiempo transcurrido, que es el propio fallo que el autor declara sin resolver. Es una laguna auto-referencial: la propuesta no puede cerrarse sin especificar el objeto del compromiso, y ninguna especificación posible del objeto evita el dilema.

**GRAVEDAD:** DoS / pérdida-fondos (según el auditor confíe en la madurez que no protege). **ESTADO:** CONFIRMADO como laguna de diseño, marcada como opcional por el propio autor.
**MITIGACIÓN:** sin mitigación conocida sin especificar el objeto del compromiso.

## VECTOR 8 · Heredado sin cambio

Cliente ligero (§26), poda de niveles PoW-específica, C-REORG-07 en bloques no en tiempo, C-EXP-04 con altura indefinida bajo recoloreado, coinbase de bloques rojos aplicándose si se porta `rusty-kaspa` tal cual: todo esto ya está confirmado en `dag-poas-auditoria.md` §3 (Ataques 3, 5, 7, 8) y `dag-poas-candidatos-auditoria.md` (N5, N6, N7 de Anexo B) y la propuesta lo admite explícitamente en su §6 sin resolverlo. No cambia con balizas ni con X-1..X-4 porque el mecanismo de mergeset/rojos de GHOSTDAG queda intacto. Sin novedad; confirmo aplicabilidad, no reejecuto.

## ATAQUES PROBADOS Y DESCARTADOS

- **Grinding de `solution_distance`:** descartado, verificado en código (`lib.rs:246-251`): función de `global_challenge`+`chunk`, sin grado de libertad, como en rondas previas.
- **Spam de flujos/candidatos como en la ronda 3 (N2, 12,5-41×):** la rareza de balizas (1/256) acota naturalmente el número de flujos por época a `αλI_b/256` (≈0,39 a α=1/3) — mejora real, cierre parcial, reconocido a favor de la propuesta.
- **Desempate por hash gratis:** cerrado, `solution_distance` como desempate sigue vigente sin regresión.
- **n-split de Filecoin puro:** no aplica, igual que en las cuatro rondas (los honestos fusionan; no hay dispersión de peso por copias).

## NO PUDE ANALIZAR

Simulación numérica completa del Vector 2 con `ghostdag_sim.py` extendido con balizas reales (usé el modelo analítico de retardo `U(0,D)` que el propio proyecto ya emplea en `voto_sim.py`, no construí el simulador nuevo por límite de tiempo/esfuerzo). Interacción cuantitativa de X-4 con `COINBASE_MATURITY` bajo reorgs profundos. Coste exacto de eclipsar dos instancias del mismo granjero (Vector 4) — sin cifra de C-NET-20 a mano.

## VEREDICTO

**El Vector 1 sí funciona**, pero **no es el más barato**: el Vector 3 (alternancia entre épocas, lectura literal de X-2) logra el mismo efecto de cobertura de ambos relojes **a coste cero**, sin Sybil, sin replotear nada — es más grave que lo que el propio autor temía. **La propuesta NO cierra el hallazgo que la mata** (ronda 3: "cobertura racional de flujos ⟹ deriva cero"): lo aplaza con una regla (X-1/X-2) que una lectura literal deja abierta por dos vías distintas y gratuitas. Tampoco cierra el anclaje de la ronda 4 (Vector 6, mismo mecanismo, validez relativa al fusionador en la elegibilidad por κ) ni evita el "split sin atacante" de la ronda 1 (Vector 2, reencarnado en el borde del corte, y Vector 5, en el 31 % de intervalos sin baliza). Cierra parcialmente el DoS de spam de candidatos de la ronda 3 (mejora real por rareza de balizas) y mejora el lookahead de ploteo dirigido respecto de rondas 2-4 (mérito genuino, no evaluado en detalle aquí por estar fuera del alcance adversarial pedido). **Más lejos de viable que las cuatro rondas anteriores en lo esencial**: cada una de ellas moría por UNA vía sin salida; esta muere por al menos dos vías independientes y gratuitas (Vectores 1 y 3) que atacan directamente la afirmación que se suponía que arreglaba lo que las cuatro rondas previas no pudieron.
