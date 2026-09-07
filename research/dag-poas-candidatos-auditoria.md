# Inyección por candidatos — auditoría D9 + D8 (tercera ronda) y cierre definitivo de P-038

**Fecha:** 2026-09-07 · Audita `dag-poas-inyeccion-por-candidatos.md` · **Cierra P-038** en sus tres
variantes · D9 y D8 en Opus; scripts en el scratchpad de la sesión (`d9/can_*.py`, `d8b/balance.py`).

## 0 · Veredicto

La tercera propuesta cierra lo que mató a las dos anteriores (D8 y D9 coinciden): validez
absoluta y bien fundada por inducción sobre `past(B)`, curación por fusión, épocas que no
colapsan, desempate sin hash, inflación de coinbase cerrada, `c_a = c_h = 50` con la época en
bloques del propio pasado (repara la refutación §3.4 de la segunda ronda: la ramificación de la
frontera **no** añade niveles, BDK Lema 13), lookahead honesto de 11 s, y el ataque de balance
**no funciona** (D8 lo simuló con adversario: no convergencia de 17-24 s frente a épocas de 250).

**Y cae por una razón nueva, de teoría de juegos, sin atacante (D9 §2):**

> Bajo flujos distintos el mismo sector en el mismo slot da chunks distintos: son billetes
> distintos y ambos pueden existir (R-CAN-7). Publicar es gratis y la validez es absoluta.
> El pago de un granjero es `Σ_i P(gana el flujo i)·(sus billetes en i)`: cubrir todos los flujos
> vivos es **estrategia estrictamente dominante**. Entonces cada flujo recibe bloques a tasa λ, la
> diferencia de peso entre dos flujos es un proceso de Skellam de **deriva nula**, recurrente, y
> el líder sigue cambiando indefinidamente. No hay convergencia exponencial: no hay convergencia.

Simulado (60 réplicas por celda, λ = 1 y 0,1, D = 4 s, k calibrado): con cobertura total y **sin
atacante**, el flujo canónico a q = 1 sigue cambiando a los 203,6 s de una época de 205,7 s;
`P(cambia tras 600 s) = 0,82`. Con honestos que siguen solo su cadena, converge en ≤ D. Es decir:
**el acuerdo solo funciona si los granjeros renuncian a ingresos**, y eso no es un supuesto admisible.

Y la trampa es cerrada por los tres lados:

| Si los flujos… | Entonces… |
|---|---|
| se colorean por linaje (rojos los no canónicos) | cobertura racional ⟹ deriva cero ⟹ **no converge**; con linajes, partición permanente sin atacante |
| se colorean por último inyector (R-CAN-3 literal) | los linajes se refunden ⟹ el atacante cobra `m·α` billetes azules ⟹ **umbral 1/(1+m)** (20 % con m = 4) |
| no se colorean (todo azul) | cada candidato privado abre un flujo con `α·λ·I` billetes ⟹ **billetes sin cota** |
| el canónico lo decide una regla determinista por contenido (p. ej. menor faro) | el atacante publica **todas** las alternativas y deja que la regla elija ⟹ optionalidad gratis sobre la entropía |

La única regla que rompe la simetría sin regalar optionalidad es «el primero», y «primero» solo
lo define de forma acordada un VDF que infunda **todos** los bloques, que es el trunk de Chia:
una cadena.

## 1 · Lo demás que encontraron

**D9:** R-CAN-2 y R-CAN-3 son mutuamente contradictorias (el padre seleccionado puede quedar rojo:
rompe «cadena seleccionada ⊆ azules» y con ello los teoremas de GHOSTDAG; corrección: inyector =
ancestro en la posición 50j de la cadena propia, sin campo de cabecera). R-CAN-3 compara el último
inyector y no el linaje (multi-flujo intacto; corrección: `flow_id` acumulativo). Lookahead
adversarial `δ + k/λ`: 33 s a q = 1, **375 s a q = 120** (3× a 34× Autonomys). Umbral publicado de
BDK con Δ = 4 s: `β₅₀ = 0,0141` a q = 1 (la fórmula es de cadena larga; combinarla con el
crecimiento azul de GHOSTDAG es el teorema que falta). **Resultado constructivo:** retarget para
DAG existe (controlador multiplicativo sobre azules), con condición `λ < k/(2D)` y k en el punto
fijo de la realimentación del Lema 9: **k = 24 a q = 1**, no 18. No hay q en el que la propuesta
supere a la cadena lineal: a q = 1 el 95,8 % de las fronteras son ambiguas; a q = 120 el 3,7 %, pero
la época dura 1,74 h y la retención regala 375 s.

**D8:** spam de candidatos: un bloque con `parents = {bloque frontera}` es candidato legal en
cualquier slot de la época ⟹ flujos por época = `α·λ·250`: **1,25 núcleos continuos con α = 0,1,
4,1 con α = 0,33, para siempre e impodable**; mi §4.4 era 4-8× optimista. R-CAN-3 compara por hash
del candidato y no por `(entropía, t)`: dos cabeceras del mismo billete enrojecen media red.
Caso «bloque sin inyector» sin escribir. Prefiltro de relé o evadible o particiona. Recoloreado de
época entera mueve coinbases aplicadas y C-EXP-02. Tx de rojos aplicadas × N copias = espacio de
bloque gratis. Cliente ligero: sin pruebas de peso, un servidor presenta un flujo minoritario como
canónico. Ploteo dirigido: **4× mejor que la ronda 2** (3,6 GiB/GPU medida, 58 extrapolada).

## 2 · Lo que tres rondas dejan demostrado, ya sin parámetros

1. La inyección necesita un evento **acordado a profundidad cero e impredecible** (D9, ronda 2,
   E2; ronda 3, §2). Una cadena lenta lo tiene (bloque 50j único el 94 % de las veces). Un DAG a
   tasa alta no lo tiene (4,32 candidatos de media, 95,8 % de fronteras ambiguas a q = 1).
2. Evitar el desacuerdo cuesta lookahead (ronda 2: ×95) o partición (rondas 1 y 2).
3. Tolerar el desacuerdo y resolverlo después no funciona: por peso no converge (cobertura
   racional), por contenido regala optionalidad, sin color no acota billetes (ronda 3).
4. Chia tiene bloques paralelos por slot **porque su VDF infunde cada bloque** y define «primero»
   de forma acordada. Eso es un trunk lineal. Autonomys no infunde bloques; su PoT es solo reloj.
5. Con descentralización como prioridad uno, las salidas externas (comité tipo drand, acuerdo
   bizantino por época tipo Spacemesh) no valen.

**P-038 queda cerrada.** Lo no lineal que sobrevive es lo que no inyecta, no pesa y no se fusiona:
**espina + fardos** (`dag-nativo-poas-propuesta.md` §3), como actualización post-beta y previa
auditoría.

## 3 · Lo aprovechable para la cadena lineal (sin DAG)

- Retarget: la condición `λ < k/(2D)` y el k en punto fijo son válidos para cualquier estructura
  con anticono; para la lineal no aplican, pero la técnica de D9 (`can_retarget.py`) queda.
- P-039: `c = 50` en bloques (demostrado que en tiempo empeora); `interval × lookback == K`;
  inyección antes del bloque siguiente a T = 120 s; `DELAY` sin derivar.
- Ploteo dirigido cuantificado: 69,363 s/sector medido ⟹ el lookahead de 11 s vale 0,16 GiB por GPU.
  Cualquier cambio futuro al `DELAY` se puede valorar con ese número.

---

## Anexo A · Informe D9 (Opus), íntegro

He leído la propuesta entera, mis dos informes previos, §2 de `dag-nativo-poas-propuesta.md`, BDK+19 §5.4 y §F (texto extraído), y he reutilizado y extendido el simulador GHOSTDAG de D8. Scripts nuevos en `/tmp/claude-1000/-home-katana-zeo/0cfccf9e-55ae-4058-bcf4-31f0987f1dbd/scratchpad/d9/`: `can_candidatos.py`, `can_flujos4.py`, `can_frac.py`, `can_retarget.py`, `can_k_punto_fijo.py`, `can_umbral.py`.

---

# D9 — refutación de `dag-poas-inyeccion-por-candidatos.md`

## 0 · Veredicto

| Regla / afirmación | Veredicto |
|---|---|
| Orden de evaluación bien fundado (E1 cerrada) | **DEMOSTRADO** — la validez absoluta lo repara |
| R-CAN-1 (validez absoluta) | SOBREVIVE, pero **le falta una condición** (`I(B)=I_j(B)`) sin la cual R-CAN-3 es contradictoria |
| R-CAN-2 (inyector canónico por primer declarante) | **REFUTADA** — rompe «cadena seleccionada ⊆ azules»; corrección dada y más simple |
| R-CAN-3 (color por flujo) | **REFUTADA por dos vías**: contradicción con el padre seleccionado, y compara **el último inyector, no el linaje** |
| R-CAN-4 «el fusionador se une al flujo más pesado → convergencia por peso» | **REFUTADA** — bajo cobertura racional de todos los flujos la deriva es **cero** |
| R-CAN-5 (ventana de candidatos) | SOBREVIVE CON SUPUESTOS |
| R-CAN-6 (anticono anclado a slot) | SOBREVIVE, pero **regala lookahead**: 33 s frente a 11 s de Autonomys (q=1) |
| R-CAN-7 (unicidad de billete) | SOBREVIVE — y es exactamente lo que habilita la refutación de R-CAN-4 |
| §3 «Acuerdo eventual por peso» | **REFUTADA** |
| §3 «Lookahead ≈ δ−D, el de Autonomys» | **REFUTADA en el caso adversarial** (3× a q=1, 34× a q=120) |
| §3 «Multi-flujo: peso cero» | **REFUTADA** con R-CAN-3 literal; sobrevive con la corrección de linaje |
| §3 «Épocas colapsadas: no aplica» | **DEMOSTRADA** |
| §4.2 «φ ≈ φ₅₀ si la ramificación no cuenta como nivel» | **DEMOSTRADO que no cuenta** (BDK Lema 13) — repara mi §3.4 anterior |
| §4.1 «~2 % de pérdida honesta» | Orden correcto, pero **no es el coste que importa** |

---

## 1 · Buena fundamentación (pregunta 1)

**Existe un orden bien fundado. DEMOSTRADO.** Sea el orden topológico del DAG (existe: un bloque solo referencia bloques anteriores). Por inducción sobre `|past(X)|` se definen, en este orden y solo con datos de conjuntos estrictamente menores: `blue_work` de cada padre → cadena seleccionada de `past(X)` → `I_j(X)` (R-CAN-2, lee cabeceras de esa cadena) → coloreado del mergeset (R-CAN-3) → `blue_work(X)` → candidatura de `X` (posición en cadena) → validez de `X` (R-CAN-1). **La circularidad E1 desaparece porque la validez ya no depende del fusionador**, solo del inyector *declarado*, que está en `past(B)`. La solución es única: cada paso es una función determinista del prefijo ya evaluado. Este es el hallazgo positivo de la propuesta y es real.

**Candidatura: bien definida y única por cadena. DEMOSTRADO.** Definiendo `pos(X)=pos(sp(X))+1`, «C es candidato de la época j» ⇔ `pos(C)=50j`. En **cada** cadena hay exactamente un bloque en cada posición, luego siempre existe y es único. La afirmación de §3 sobre épocas colapsadas queda **demostrada**. El color de los bloques de la cadena de `past(C)` no interviene en el conteo: la cadena seleccionada es un camino de padres seleccionados, no una selección de azules.

**Pero R-CAN-2 y R-CAN-3 son mutuamente contradictorias. REFUTADAS.** Contraejemplo constructivo (4 bloques):

- `C₁`, `C₂` candidatos de la época j en anticono mutuo.
- `A`: hijo de `C₁`, `slot(A) ≥ t(C₁)`, declara `C₁`. Es el primer declarante de su cadena.
- `Y`: referencia `{A, C₂}`, `sp(Y)=A` (mayor `blue_work`), `slot(Y) ≥ t(C₂)`, declara `C₂`. **Es válido**: R-CAN-1 solo exige que `C₂` sea candidato legal y esté en `past(Y)`; no exige `I(Y)=I_j(Y)`.
- `B`: `sp(B)=Y`. Su cadena es `[…, C₁, A, Y]`; el primer declarante es `A`, luego `I_j(B)=C₁`. Como `Y ∈ mergeset(B)` y `I(Y)=C₂≠C₁`, **R-CAN-3 pone rojo a `sp(B)`**.

GHOSTDAG define `BLUE(B) = {sp(B)} ∪ blues(mergeset)`; el Lema 12 (`score(C) ≤ score(B)+k`) y el proceso de Markov de la Prop. 8 se apoyan en esa herencia. Es el mismo error que ya refuté en U3 (primera auditoría, A4).

**Corrección propuesta, que además simplifica:** eliminar el declarante y el campo de cabecera. `I_j(B) := el ancestro de la cadena seleccionada de B en la posición 50j`. Entonces, para todo B con `pos(sp(B)) ≥ 50j`, `I_j(B)=I_j(sp(B))`: el padre seleccionado **nunca** puede discrepar y la contradicción desaparece por construcción. Se ahorran los 32 B de §4.7, se elimina la carrera por ser «primer declarante» (una palanca de grinding que la propuesta no analiza) y R-CAN-1 recupera una condición verificable: `I(B)=I_j(B)` salvo que `pos(sp(B)) < 50j`.

**Segunda refutación de R-CAN-3, independiente:** colorea comparando **el inyector de la época de `slot(X)`**, es decir, el *último*. El flujo de PoT real es el **linaje completo** `(C₁,…,C_j)`: `S(I)` de §1 nombra una inyección, no una cadena. Contraejemplo: el atacante mantiene el linaje `(…, C'_{j−1}, C_j)` con `C'_{j−1}` propio y `C_j` el canónico. Sus bloques son válidos (R-CAN-1 permite recomputar el PoT desde `t(C_j)` — §4.4 lo presupuesta), declaran el inyector canónico y por R-CAN-3 son **azules**. Su desafío en cada slot proviene de un PoT distinto: es una lotería independiente. Es la construcción A3 de la primera auditoría, intacta. **La fila «Multi-flujo del atacante → peso cero» de §3 es falsa con R-CAN-3 literal.** Corrección: identificador de flujo acumulativo (`flow_id = H(flow_id_padre ‖ I_j)`) y comparar linajes, no inyectores.

---

## 2 · Convergencia entre flujos (pregunta 2) — la refutación central

**El equilibrio racional es que todo granjero publique bajo todos los flujos vivos, y entonces la deriva es cero.**

*Demostración del dominio estricto.* R-CAN-7 lo dice explícitamente: bajo flujos distintos el mismo sector en el mismo slot da chunks distintos, **son billetes distintos y ambos pueden existir**. Publicar es gratis y la validez es absoluta (R-CAN-1). El pago de un granjero es `Σ_i P(gana el flujo i)·(sus billetes en i)`. Añadir un flujo al conjunto publicado **aumenta estrictamente** el pago (todo `P(i)>0`). Coste marginal: las IOPS de §4.5. Con `m=4` y un flujo cada uno con probabilidad ~1/4, el granjero que solo cubre su cadena seleccionada gana **1/m** de lo que gana el que cubre todos. Cobertura total es la estrategia dominante.

*Consecuencia.* Cada flujo recibe bloques a tasa `λ` (todo el espacio, lotería independiente). El bloque bajo el flujo *i* elige como padre seleccionado un bloque del sub-DAG *i* —es la única forma de que valga algo—, luego cada flujo tiene su propia cadena creciendo a `λ`. La diferencia de peso `X(t)=w₁−w₂` es un **proceso de Skellam de deriva nula**, recurrente: `P(hay un cambio de líder después de τ) = 1` para todo τ. Por la ley del arcoseno, `P(sin cambio de líder en [τ,2τ]) = 1/2`. **No hay convergencia exponencial: no hay convergencia.** DEMOSTRADO analíticamente y confirmado en simulación (`can_flujos4.py`, 60 réplicas por celda, λ=1 y 0,1, D=4 s, k calibrado):

| política honesta | q | m | α | último cambio de líder (p50) | P(cambia tras 60 s / 600 s) |
|---|---:|---:|---:|---:|---:|
| solo su cadena | 1 | 4 | 0,00 | 0,0 s | 0,00 |
| solo su cadena | 1 | 2 | 0,33 | 0,0 s | 0,00 |
| mitad cubre todos | 1 | 4 | 0,00 | 2,8 s | 0,00 |
| mitad cubre todos | 10 | 2 | 0,33 | 757 s | **0,70** |
| **cobertura total** | 1 | 4 | 0,00 | **203,6 s** (de 240 s) | **0,82** |
| **cobertura total** | 1 | 2 | 0,00 | 85,0 s | 0,53 |
| **cobertura total** | 10 | 2 | 0,00 | 509 s (de 1 200 s) | 0,63 |

Con cobertura total y **sin atacante** el flujo canónico sigue cambiando al final de la época. Y no se cura en la frontera siguiente: cada linaje engendra sus propios candidatos y ambas cadenas continúan en paralelo. Con la corrección de linaje del §1, eso es una **partición permanente sin atacante**; sin la corrección, los dos linajes se refunden y el atacante cobra `m·α` billetes azules. La propuesta está atrapada entre esas dos ramas.

**Balance attack.** Solo hace falta si los honestos *no* cubren todo. Con la mitad cubriendo todo, α=0,33 y q=10, el líder sigue cambiando a los 757 s (p50) y `P(>600 s)=0,70`. Con honestos que siguen solo su cadena, la convergencia es ≤ D y ni α=0,33 la rompe (máximo observado 38 s a q=1, m=2). Es decir: **la seguridad del acuerdo depende íntegramente de que los granjeros se comporten de forma subóptima.** Eso no es un supuesto admisible.

---

## 3 · Double dipping en la frontera (pregunta 3)

**(a)** Frente al honesto que solo sigue su cadena, el atacante que audita los m flujos obtiene **m×** billetes durante la ventana; promediado sobre la época (`can_candidatos.py`: m=4,32 de media a q=1, ventana ≈ 3,5 s de dispersión de candidatos sobre épocas de 205,7 s) el exceso es ~+6 %. Pero esos billetes extra están en flujos que perderán: **su valor no es el conteo, es la dirección** (elegir qué flujo gana) y la cobertura de la pérdida por división, que el honesto sí sufre.

**(b) φ. DEMOSTRADO que la ramificación de la frontera NO añade niveles, y esto repara mi refutación §3.4 anterior.** BDK+19 §F, Lema 13: la estrategia óptima es **bifurcar solo en los padres de los godfather-blocks**, y `c` cuenta niveles del árbol privado entre godfathers. Contar la época en **bloques de la cadena seleccionada del propio pasado** hace que el árbol privado del atacante tenga también 50 niveles entre fronteras — a diferencia de la época en tiempo, donde `c_a = αλI`. Luego `c_a = c_h = 50`, `φ₅₀ = 1,2815`, y la ramificación de la frontera es exactamente la ramificación en godfather que `φ_c` ya integra. **La segunda propuesta perdía aquí; esta lo gana. Es su mejor resultado.**

Lo que **no** cubre `φ₅₀`: (i) el atacante puede además decidir el inyector de la **cadena pública** (siendo el primer declarante, o —con mi corrección— empujando su rama en la carrera de peso); BDK modela grinding solo en el árbol privado. Su ganancia está acotada por la velocidad del VDF: para comparar m flujos debe precomputar PoT bajo cada uno dentro de la ventana, ~`v·W/m` slots por flujo. **PLAUSIBLE, NO DEMOSTRADO** que sea pequeña. (ii) La fórmula publicada del umbral es de **cadena larga**: `β_c = e^{−λ_hΔ}/(e^{−λ_hΔ}+φ_c)`. Con Δ=4 s: `β₅₀ = 0,0141` a q=1, `0,343` a q=10, `0,430` a q=120 (`can_umbral.py`). El 0,438 que venimos citando es `β` con Δ=0. **Usar φ₅₀ con el crecimiento honesto de GHOSTDAG en vez de `e^{−λΔ}` es un empalme sin demostración**: es exactamente el teorema que falta.

**(c)** No. R-CAN-6 acota la retención del candidato a `k/λ` = 18 s (q=1, k=18), pero la convergencia con cobertura total no ocurre en 9 s ni en 60 s: el orden de magnitud contra el que se compara está mal. Con honestos no-cobertores sí converge en ≤ D y entonces `k/λ` es holgado.

---

## 4 · Lookahead (pregunta 4)

**Honesto: `δ − D`. Correcto — la afirmación de §3 sobrevive para el honesto.** A reloj `w` puede existir un candidato con `slot ∈ (w−D, w]` no visto; su inyección cae en `slot+δ > w−D+δ`. Luego el flujo está garantizado hasta `w+δ−D`. Con δ=15: 11 s, el de Autonomys. Con el mínimo `δ > D+1` (=6): **2 s**.

**Adversarial: REFUTADA.** R-CAN-6 concede explícitamente retención de `k/λ`, y a diferencia de Autonomys **retener no cuesta el inyector**: la candidatura no es exclusiva (hay m candidatos legales simultáneos), así que su candidato retenido sigue siendo legal al publicarlo. Conoce `entropía(C_a)` y `t(C_a)` desde `slot(C_a)`; la red lo sabe `k/λ + D` después. Lookahead garantizado del atacante = `δ + k/λ`:

| q | k | δ=15 | δ=6 | ratio sobre 11 s (Autonomys) |
|---:|---:|---:|---:|---:|
| 1 | 18 | **33 s** | 24 s | 3,0× |
| 1 | 24 (§7) | 39 s | 30 s | 3,5× |
| 10 | 5 | 65 s | 56 s | 5,9× |
| 120 | 3 | **375 s** | 366 s | **34×** |

No es el ×95 de la propuesta anterior, pero **no es «el de Autonomys»**: es 3–34× según q. Con las cifras de ploteo dirigido medidas antes (69,363 s/sector en GTX 1070), 33 s ⇒ 0,48 GiB fabricados por GPU; 375 s ⇒ 5,4 GiB. Pequeño, pero la afirmación literal es falsa.

---

## 5 · Pérdida honesta (pregunta 5)

Medida en `can_flujos4.py` como fracción de bloques honestos cuyo flujo declarado ≠ flujo final:

- honestos que siguen solo su cadena: **0,0 %–0,4 %** de la ventana (α ≤ 0,33). El «~2 %» de §4.1 es **conservador de más**.
- mitad cubriendo todos los flujos: 60 % de la ventana con m=4 → sobre una época de 205,7 s con ventana ~7 s: **2 % de la época**.
- cobertura total: 73,6 % de los bloques publicados son rojos, pero **la pérdida relativa es cero**: el atacante también publica en todos, y en el flujo ganador las tasas siguen siendo `(1−α)λ` y `αλ`.

En el Lema 9 entra como `(1−δ_conv)` sobre el crecimiento honesto: `α* = (1−δ)/(2−δ)`. Con δ=0,02: **α\* = 0,4949**. **Conclusión: la pérdida honesta no es el coste de este diseño.** El coste es la no convergencia. §4.1 mide lo que no duele.

---

## 6 · Multi-flujo del atacante (pregunta 6)

Con la corrección de linaje: obtiene `α` billetes en **cada** uno de los m flujos, pero solo cuenta el que gane, y en ese flujo los honestos también tienen `(1−α)`. **El umbral no cambia por conteo.** Lo que gana es (i) varianza —elige la mejor de m realizaciones—, acotada por la velocidad del VDF; (ii) dirección del flujo; (iii) no sufrir la división que sí sufre el honesto no-cobertor. Es double dipping del tipo que `φ_c` describe en el árbol privado, **más** un grinding público que BDK no modela. Sin la corrección de linaje, obtiene `m·α` billetes **azules** y el umbral se hunde a `α > 1/(1+m)` (m=4 ⇒ 20 %): **REFUTADO el multi-flujo con R-CAN-3 literal**.

---

## 7 · Retarget (pregunta 7) — sí existe una regla, con una condición nueva

Controlador multiplicativo amortiguado sobre azules del flujo canónico en ventana de W slots: `ln SR_{n+1} = ln SR_n − γ(ln N_obs − ln N_obj)`, `0<γ<2`. Contractivo, punto fijo único (ya demostrado en A6). El sesgo del Lema 9 es `b(λ)=2Dλ/(k+2Dλ)`, luego el observador ve `λ_obs = λ·k/(k+2Dλ)`, función **acotada por `k/(2D)`**. Resultado nuevo (`can_retarget.py`, `can_k_punto_fijo.py`):

1. **Condición de existencia: `λ_objetivo < k/(2D)`.** Si no, no hay punto fijo y `SR → SR_MAX`. A q=1 con k=18 el techo es 2,25/s: margen 2,25×.
2. Bajo sesgo máximo sostenido, la tasa real se infla: **×1,80 a q=1 (k=18)**, ×1,19 a q=10 (k=5), ×1,02 a q=120. `c=Dλ` pasa de 4 a 7,2 → **k=18 deja de ser válido**.
3. Punto fijo autoconsistente `k = k_Poisson(D·λ(k))` con δ=10⁻³: **q=1 → k=24, λ_real=1,5/s, c=6** (frente a la calibración ingenua k=18, c=4). q=10 → k=5 sigue siendo consistente.

Es decir: **hay realimentación positiva pero converge**, y la corrección es elegir k en el punto fijo, no en `c=Dλ_objetivo`. Esto es constructivo y aplicable con independencia del resto. DEMOSTRADO bajo el supuesto de que el sesgo del Lema 9 sea sostenible en todo instante (el paper lo da como caso peor; que sea sostenible con α<1/2 es **PLAUSIBLE, NO DEMOSTRADO**).

---

## 8 · Dependencia de q (pregunta 8)

`can_frac.py`, fronteras con m ≥ 2 candidatos (única situación en que existen dos flujos):

| q | m medio (máx) | fronteras con m≥2 | duración de época (50 bloques de cadena) |
|---:|---:|---:|---:|
| 1 | 4,32 (11) | **95,8 %** | 205,7 s |
| 10 | 1,49 (5) | **40,6 %** | 681,7 s |
| 120 | 1,04 (2) | **3,7 %** | 6 263,8 s (1,74 h) |

- **q=1: claramente peor que la cadena lineal.** Casi todas las épocas son ambiguas; con cobertura racional, no converge.
- **q=10: intermedio malo.** 4 de cada 10 épocas ambiguas; el balance attack con α=0,33 mantiene el desacuerdo p50 757 s sobre épocas de 682 s: **desacuerdo permanente**.
- **q=120: el mecanismo no se usa** (96 % de fronteras con un solo candidato) y el DAG no aporta nada. Además la época dura 1,74 h: el rezago de contenido se dispara y R-CAN-6 concede 375 s de retención. Es la cadena lineal con peor lookahead.

**No hay q en el que la propuesta sea mejor que la cadena lineal.**

---

## Cierre

**REFUTADAS.** R-CAN-2 (el padre seleccionado puede quedar rojo → rompe `cadena ⊆ azules`; *impacto: los teoremas de GHOSTDAG dejan de aplicar*) · R-CAN-3 por dos vías independientes (contradicción con sp; y comparar último inyector en vez de linaje → *impacto: `m·α` billetes azules, umbral a 1/(1+m)*) · R-CAN-4 y la fila «Acuerdo eventual por peso» (deriva cero bajo cobertura racional; *impacto: partición permanente sin atacante, o inflación si se refunden los linajes*) · §3 «lookahead el de Autonomys» (3× a q=1, 34× a q=120) · §3 «multi-flujo con peso cero» · §4.1 como estimación del coste dominante.

**DEMOSTRADAS.** Buena fundamentación por inducción sobre `past` (E1 cerrada) · unicidad y existencia del candidato por cadena («épocas colapsadas: no aplica») · `c_a = c_h = 50` con la época en bloques del propio pasado, luego `φ₅₀` (repara mi §3.4 anterior) · la ramificación de la frontera **no** añade niveles (BDK Lema 13).

**COTAS CORREGIDAS.** `m` a q=1: 4,09 → **4,32 media, 11 máx, 95,8 % de las fronteras** · época a q=1: «~300 s» → **205,7 s**; a q=120 → **1,74 h** · lookahead del atacante: `δ−D` → **δ+k/λ** (33 s a q=1, 375 s a q=120) · umbral de BDK con Δ=4 s: 0,438 → **0,0141 a q=1** con la fórmula publicada (de cadena larga) · k a q=1 con la realimentación del retarget: 18 → **24**, con `λ_real = 1,5/s` y `c = 6` · pérdida honesta: 2 % → **0,4 % (no cobertura) / 0 relativa (cobertura total)**.

**NO DEMOSTRADAS.** Que exista un umbral de double dipping para GHOSTDAG (`φ_c` está probado contra la cadena honesta ficticia `e^{−λΔ}`, no contra el crecimiento azul de un DAG) · que el grinding del inyector público esté acotado por la velocidad del VDF · sostenibilidad del sesgo del Lema 9 en todo instante · que la corrección de linaje que propongo no reintroduzca coste de verificación exponencial en el número de linajes vivos (es de D8).

**LO QUE NO PUDE VERIFICAR.** El equilibrio de cobertura con el coste real de IOPS (§4.5 estima +20 %; no está medido, y si el SSD satura la conclusión de la §2 se debilita —es la única salida que le veo a esta propuesta y hay que medirla) · el comportamiento con m>4 linajes encadenados a lo largo de varias épocas (mi simulación es de una frontera) · `Dmax` real, otra vez.

---

### Lo que habría que demostrar antes del SPEC

1. **Un mecanismo de convergencia con deriva positiva que no dependa de que los granjeros renuncien a billetes.** Es el problema, y no lo resuelve ningún parámetro. Candidatos a explorar: hacer que publicar bajo un flujo no canónico *cueste* (p. ej. un solo billete por slot y granjero, con la identidad de R-CAN-7 **sin** el chunk — pero eso es cambiar la lotería) o romper la simetría con una regla determinista de preferencia entre candidatos que no sea el peso.
2. Un teorema de umbral de double dipping **para GHOSTDAG**, no para cadena larga: `φ₅₀` combinado con el crecimiento azul, con constantes.
3. R-CAN-2 reescrita como «ancestro en la posición 50j de la cadena propia» y R-CAN-3 sobre **linaje**, con la demostración de que `sp(B)` nunca queda rojo (que con esa forma es inmediata) y con el coste de verificación acotado.
4. `k` en el punto fijo del retarget (24 a q=1), y la demostración de que el sesgo del Lema 9 es sostenible o no.
5. Medición de las IOPS de la cobertura múltiple: es lo único que puede invalidar la refutación central.

### ¿Más cerca o más lejos que las dos anteriores?

**Más cerca en la mecánica, más lejos en el núcleo.** Cierra de verdad tres cosas que refuté antes: la circularidad E1 (validez absoluta: correcto y limpio), el `c` de BDK (la época en bloques del propio pasado da `c_a=50`, que es el argumento que la segunda propuesta no tenía) y la curación por fusión (recolorear en vez de invalidar). El lookahead pasa de ×95 a ×3. Esas son mejoras reales y son suyas.

Pero desplaza el problema del acuerdo del sitio donde se podía acotar —una carrera de cadenas— a un sitio donde **la teoría de juegos lo destruye**: si dos flujos son dos loterías independientes sobre el mismo espacio y publicar en ambos es gratis, todo el mundo publica en ambos y no hay nada que rompa la simetría. La primera propuesta se partía con un atacante; la segunda se partía con un atacante o con L mal elegido; **esta se parte con cero atacante y granjeros que solo maximizan su ingreso**, en el 95,8 % de las épocas a q=1. Y la corrección obvia —comparar linajes— convierte el empate en una partición permanente en vez de una inflación.

Mi lectura sigue siendo la del cierre anterior: hace falta un evento acordado a profundidad cero, y este diseño lo sustituye por un acuerdo *a posteriori* cuyo mecanismo de desempate es precisamente el que los incentivos anulan. La vía que no toca ese núcleo continúa siendo **espina + fardos** (`dag-nativo-poas-propuesta.md` §3): los fardos no inyectan, no pesan y no se fusionan, y por tanto no hay dos loterías que cubrir.

---

## Anexo B · Informe D8 (Opus), íntegro

He terminado el análisis, con simulación propia extendida. Informe.

---

# D8 · Auditoría adversarial de `dag-poas-inyeccion-por-candidatos.md`

**Fuentes leídas:** la propuesta íntegra, `dag-poas-auditoria.md` §3, `dag-poas-inyeccion-auditoria.md` Anexo B, `dag-nativo-poas-propuesta.md` §2, `SPEC.md` §12/§16/§20, `rusty-kaspa @ c338d495` (verificado: `git log -1` = `c338d495bec29e4dc8b5149f99e8db6fa916ed4a`), `subspace @ f8842d0`. Simulador propio ampliado con adversario de balance: `/tmp/claude-1000/-home-katana-zeo/0cfccf9e-55ae-4058-bcf4-31f0987f1dbd/scratchpad/d8b/balance.py`.

## 0 · Los hallazgos de las dos rondas, uno por uno

| Hallazgo previo | Estado en R-CAN |
|---|---|
| Validez relativa al fusionador (rd. 2, hallazgo 4) | **CERRADO de verdad.** R-CAN-1 es absoluta y bien fundada: `blue_work(p)` de cada padre está fijado en el pasado de `p`, luego la cadena seleccionada de `past(B)` es función de `past(B)` sin punto fijo. Es la mejora real de esta ronda |
| Curación por fusión (rd. 2, hallazgo 3) | **CERRADO en consenso, REABIERTO en política de relé** (hallazgo N4 abajo) |
| Épocas colapsadas (rd. 2, hallazgo 6) | **CERRADO.** Cada bloque avanza la cadena en 1; ninguna frontera `50j` se salta. Verificado sobre la definición |
| Desempate por hash (rd. 2, hallazgo 1) | **CERRADO** por `solution_distance` en R-CAN-4. Queda sin definir el desempate final ante colisión de distancia (menor) |
| Coinbase de rojos (rd. 1 At. 3, rd. 2 hallazgo inflación) | **PARCIAL.** R-CAN-3 dice «salvo la coinbase». Cierra la inflación ×10. **No cierra** las tx de los rojos (N6) ni el recoloreado profundo de una coinbase ya aplicada (N5) |
| C-REORG-07 | **APLAZADO.** §4.6 lo remite a «profundidad de recoloreado», término que la propuesta no define. Ver N5 |
| Poda | **APLAZADO y AGRAVADO**: ahora hay que conservar *m* flujos de PoT, no uno (N2) |
| Cliente ligero | **APLAZADO.** §4.6 afirma que el flujo canónico «se puede acreditar con las mismas pruebas». Esas pruebas no existen (N8) |
| C-EXP-04 | **APLAZADO.** «Altura = posición en la cadena seleccionada» resuelve las copias rojas, pero el recoloreado mueve la cadena (N5) |
| R-INJ-5 / griefing por retraso (rd. 2) | **NO CERRADO.** R-CAN-6 es la misma regla con otro nombre; el griefing por retraso selectivo de `k/λ` sigue vivo, sin mitigación |
| DoS por flujo falso (rd. 2, 60 core-s/77 kB) | **AGRAVADO cualitativamente**: antes el flujo falso se verificaba *para rechazarlo*; ahora es válido y queda en la historia para siempre (N2) |
| Palanca de 4 candidatos (rd. 2, hallazgo 2) | **NO CERRADA, y crece**: el atacante ya no elige entre ~4 candidatos honestos, fabrica los suyos (N2) |

---

## 1 · Hallazgos nuevos

```
HALLAZGO:     R-CAN-3 colorea comparando el HASH del candidato, no el flujo: dos
              candidatos con flujo IDÉNTICO se enrojecen mutuamente
SEVERIDAD:    pérdida-fondos (recompensas honestas) / split
ESTADO:       CONFIRMADO como defecto de la regla escrita
ESCENARIO:    El atacante gana un billete en el slot s justo tras la frontera 50j. Publica
              dos cabeceras C y C' con el MISMO billete y padres distintos (R-CAN-7 lo
              permite: la segunda es roja, pero sigue siendo candidato legal — R-CAN-1 solo
              exige «candidato legal y en past(B)», nunca «azul»). Entrega C a media red y
              C' a la otra media, dentro de D.
              Por §2 hallazgo 6 de `dag-nativo-poas-propuesta.md`, entropía = blake3(chunk ‖
              pot_output) y t = slot+δ son IGUALES para C y C': ambos definen EL MISMO
              flujo de PoT. No hay ninguna divergencia criptográfica.
              Pero R-CAN-3 dice literalmente «un bloque X con I(X) ≠ I_j(B) es rojo», e
              I(X) es «el hash del candidato». Los bloques que declaran C' son rojos bajo
              un fusionador cuyo I_j es C, y viceversa — pese a producir bajo el mismo PoT.
              Resultado: media red honesta enrojecida durante la ventana de convergencia,
              con UN billete, sin ningún flujo alternativo que verificar y sin señal
              observable de ataque.
UBICACIÓN:    propuesta R-CAN-3 y R-CAN-1 («lleva en la cabecera el hash del candidato»)
PRECONDICIÓN: un billete en la ventana de convergencia; control de entrega a dos mitades.
MITIGACIÓN:   comparar por (entropía, t), no por hash de candidato: I(X) declara la pareja
              (blake3(chunk‖pot_output), slot+δ). Es un arreglo barato y cierra el vector 5
              del encargo por completo. Hoy la regla es más estricta de lo necesario y esa
              estrictez es gratis para el atacante.
```

```
HALLAZGO:     Spam de candidatos: el atacante fabrica un flujo por billete apuntando su
              padre seleccionado al bloque frontera; el coste de verificación queda en la
              historia para siempre
SEVERIDAD:    DoS (permanente, sobre todo nodo presente y futuro)
ESTADO:       CONFIRMADO (mecanismo derivado de las reglas; coste por aritmética)
ESCENARIO:    C es candidato si «en past(C) la cadena seleccionada tiene exactamente 50j−1
              bloques por debajo de su padre seleccionado». El atacante construye C con
              parents = {B_50j} ÚNICAMENTE. Entonces sp(C) = B_50j y C es candidato legal,
              con slot(C) arbitrario dentro de la época — NO tiene que estar cerca de la
              frontera. R-CAN-6 solo enrojece candidatos DEMASIADO VIEJOS respecto al
              fusionador; no acota los tardíos. C será rojo por el k-cluster (su anticono
              azul es enorme), pero rojo ≠ ilegal: R-CAN-1 admite un candidato rojo como
              inyector declarado.
              Cada uno de esos C abre un flujo S(C) desde t(C). Cada flujo que aparezca en
              past(B) de cualquier bloque honesto (los honestos referencian todas las
              puntas, y C es una punta) debe verificarse: R-CAN-1 exige «todos los bloques
              de past(B) son válidos».
COSTE:        Época = 50 bloques de cadena; crecimiento de cadena a q=1, D=4 es 0,200/s
              (D9, chain_growth.py) → 250 s. Billetes del atacante por época = α·λ·250:
              α=0,10 → 25 flujos; α=0,33 → 82 flujos. Tramo medio por flujo ≈ 125 slots.
              Verificación 100,2 ms/slot:
                α=0,10 → 25 × 125 × 0,1002 = 313 core-s por 250 s = 1,25 NÚCLEOS continuos
                α=0,33 → 82 × 125 × 0,1002 = 1 031 core-s por 250 s = 4,1 NÚCLEOS continuos
              Flujo canónico solo: 0,1002 core-s por segundo = 0,10 núcleos. Es decir el
              atacante impone 12,5× (α=0,10) a 41× (α=0,33) el coste de PoT de la cadena.
              Nodo que sincroniza un año de historia: 1,25 core-años (α=0,10) o 4,1
              core-años (α=0,33) SOLO en flujos basura, frente a 0,10 core-años del flujo
              canónico. Un nodo con 4 núcleos no alcanza la punta con α=0,33.
              La estimación de §4.4 («α=0,1, W=30 s → ~3 flujos → ~0,3 núcleos») es 4× a 8×
              optimista: asume una ventana de candidatos de 30 s cuando R-CAN-5 la extiende
              a la época entera.
UBICACIÓN:    propuesta §1 (definición de candidato), R-CAN-5, R-CAN-6, §4.4
PRECONDICIÓN: α > 0 y un núcleo por flujo para producir el AES. Cero espacio adicional.
MITIGACIÓN:   exigir que el inyector declarado sea AZUL bajo el fusionador — pero eso
              reintroduce la validez relativa al fusionador, que es justo lo que esta ronda
              cierra. O acotar slot(C) ≤ slot(frontera)+W con W pequeño, lo que devuelve la
              posición ordinal. Sin mitigación conocida que no deshaga R-CAN-1.
```

```
HALLAZGO:     El flujo «sin inyección» es legal y gratuito: un bloque que no ha visto
              ningún candidato produce bajo la continuación no inyectada del PoT
SEVERIDAD:    DoS / split (laguna de especificación)
ESTADO:       CONFIRMADO como laguna
ESCENARIO:    R-CAN-5: «un bloque cuyo I(B) no esté entre los candidatos vistos (en past(B))
              es inválido». Luego un bloque cuyo past(B) no contiene ningún candidato NO
              declara inyector. Es exactamente el caso del candidato del hallazgo anterior:
              su past termina en B_50j, no contiene candidatos, y su slot es posterior a
              todas las t(C). ¿Bajo qué flujo verifica SU solución? Solo puede ser el flujo
              anterior continuado sin inyectar. Ese «flujo nulo» es un flujo más que todo
              verificador debe computar, y no cuesta al atacante ni un candidato.
              La propuesta no lo nombra. Dos implementaciones razonables discrepan: una
              declara inválido todo bloque con slot ≥ t(C) sin inyector declarado (y entonces
              el spam de candidatos del hallazgo anterior es imposible, pero también lo es
              cualquier bloque legítimo producido por un nodo que aún no vio el candidato);
              la otra lo admite. Discrepancia de validez absoluta entre nodos = split.
UBICACIÓN:    propuesta R-CAN-1 («todo bloque B con slot ≥ t(C) para algún candidato C»:
              el cuantificador sobre C no está ligado) y R-CAN-5
PRECONDICIÓN: ninguna; ocurre también sin atacante en cada frontera de época.
MITIGACIÓN:   escribir el caso. Ambas opciones tienen coste; la primera cierra el spam pero
              enrojece o invalida a los honestos rezagados.
```

```
HALLAZGO:     El prefiltro de relé de §4.4 y la propiedad de fusión de §3 son mutuamente
              excluyentes: o se paga el DoS de N2 o se reintroduce la partición de R-INJ-2
SEVERIDAD:    DoS o split, a elegir
ESTADO:       CONFIRMADO
ESCENARIO:    §4.4 propone «no propagar bloques bajo flujos cuyo candidato no esté en mi
              DAG». Es trivialmente evadible: el atacante publica el candidato PRIMERO (es
              un bloque válido bajo el flujo anterior; hay que relayarlo) y después los
              bloques bajo su flujo. El candidato está en el DAG de todos.
              El filtro que sí funcionaría —«no relayar bloques cuyo I(X) ≠ mi I_j»—
              censura los bloques honestos producidos bajo el candidato competidor durante
              la ventana de convergencia, que es precisamente el caso que la propuesta
              quiere tolerar. Un nodo que lo adopte no puede enterarse de que el otro flujo
              pesaba más: se auto-particiona. Y un nodo que sincroniza o sale de una
              partición no tiene I_j asentado con el que comparar (mismo agujero que la
              ronda 2, hallazgo DoS).
              Nota: para saber que un bloque es rojo NO hace falta verificar su PoT (basta
              comparar hashes). Pero R-CAN-1 exige past válido, y los honestos referencian
              todas las puntas. Dejar de referenciarlas es dejar de fusionar.
UBICACIÓN:    propuesta §3 fila «Acuerdo»/«Curación tras partición», §4.4
MITIGACIÓN:   sin mitigación conocida. Es el mismo dilema de la ronda 2 desplazado de
              consenso a red.
```

```
HALLAZGO:     El recoloreado por cambio de flujo es de época entera, no de punta: una
              coinbase aplicada puede dejar de estarlo, y C-EXP-02 cambia bajo los pies
SEVERIDAD:    pérdida-fondos / split
ESTADO:       CONFIRMADO condicional a las definiciones que la propuesta aplaza
ESCENARIO:    Definición que la propuesta debe y no da: **profundidad de recoloreado** =
              número de posiciones de la cadena seleccionada cuyo ocupante o color cambia.
              Cuando el bloque decisor de R-CAN-2 cambia, TODA la época recolorea: los
              azules del flujo perdedor pasan a rojos en bloque. A q=1 son ~50 posiciones de
              cadena y ~250 bloques del DAG. En Kaspa una reorg mueve unas pocas.
              (a) Coinbase: una coinbase azul aplicada al UTXO pasa a roja → no aplicada →
              toda tx que la gastara es inválida. COINBASE_MATURITY = 100 (SPEC.md:1737) en
              posiciones de cadena = 500 s a 0,200/s, mayor que la época de 250 s: cubre el
              caso de una sola época, sin margen derivado y sin cubrir un recoloreado que
              cruce dos fronteras.
              (b) C-EXP-02: `desplazamiento = blake3(sector_id ‖ hash_bloque[altura_ploteo])`
              con `hash_bloque` «de la cadena que se está validando» (SPEC.md:1806, 1819).
              El recoloreado cambia la cadena seleccionada en las últimas ~50 alturas. Un
              sector con `altura_ploteo` reciente cambia de `desplazamiento` y por tanto de
              `caducidad_altura`: caduca para un nodo y no para otro → el mismo bloque es
              válido para uno e inválido para otro. C-EXP-05 (VIDA_MINIMA > MAX_REORG_LENGTH)
              no lo cubre: el problema no es la vida, es el mapeo altura→hash.
              (c) C-REORG-07: 50 posiciones < MAX_REORG_LENGTH = 99, así que un flip de una
              época NO dispara la parada dura. Dos flips consecutivos sí. Y dos
              implementaciones —una que cuente `chain_path.removed` (los bloques no se
              retiran del DAG, solo recolorean) y otra que cuente recoloreados— difieren en
              CUÁNDO se paran: divergencia de liveness.
UBICACIÓN:    propuesta §4.6; SPEC.md:1737, 1804-1832, 1734-1745
PRECONDICIÓN: un cambio de flujo canónico, que ocurre sin atacante (rd. 2: la cadena
              seleccionada difiere de la final el 41 % del tiempo a q=1).
MITIGACIÓN:   exigir `altura_ploteo` a profundidad > profundidad máxima de recoloreado
              (análogo a `history_size` de Autonomys), derivar COINBASE_MATURITY contra la
              época, y definir C-REORG-07 sobre recoloreado. Nada de eso está hecho.
```

```
HALLAZGO:     Un billete → N copias rojas con conjuntos de transacciones distintos, todas
              aplicadas: espacio de bloque gratis y crecimiento de estado gratis
SEVERIDAD:    DoS (crecimiento de estado) — NO inflación
ESTADO:       CONFIRMADO condicional a portar rusty-kaspa
ESCENARIO:    R-CAN-3: «sus transacciones se aplican en el orden (como Kaspa) salvo la
              coinbase». Verificado que Kaspa aplica las tx de los rojos:
              `utxo_validation.rs:122` usa `consensus_ordered_mergeset_without_selected_parent`,
              que mezcla `mergeset_blues` y `mergeset_reds` (`ghostdag.rs:110-135`, c338d495).
              R-CAN-7 admite N copias del mismo billete (rojas salvo la primera). Cada copia
              lleva un cuerpo distinto. Con N = max_block_parents = 10 (`bps.rs:57-73`), un
              billete compra 10 bloques de espacio de transacción. Las tx pueden ser de
              comisión cero: el consenso no exige comisión mínima, y como la coinbase roja
              no se aplica, la comisión ni siquiera se cobra a nadie.
              No hay doble aplicación (gana el primer gasto en el orden) ni reordenación
              arbitraria (el orden es determinista por blue_work), pero sí hay N× de
              inserción de UTXO por billete.
UBICACIÓN:    propuesta R-CAN-3 y R-CAN-7; rusty-kaspa utxo_validation.rs:122
PRECONDICIÓN: 1 billete real.
MITIGACIÓN:   no aplicar las transacciones de los bloques rojos (Kaspa las aplica por
              inclusividad; ZEROX no tiene esa obligación), o contar la masa de los rojos
              contra el límite del fusionador. No está escrito.
```

```
HALLAZGO:     R-CAN-2 no está bien cuantificada, y la retención de un candidato con t(C)
              temprano deja el bloque decisor sin declaración
SEVERIDAD:    split (laguna)
ESTADO:       CONFIRMADO como laguna; el escenario de retención es SOSPECHA
ESCENARIO:    «I_j(B) es el inyector declarado por el primer bloque de la cadena
              seleccionada de past(B) con slot ≥ t(C)»: C no está ligado. Candidatos
              distintos tienen t(C) distintos, luego «el primero con slot ≥ t(C)» designa
              bloques distintos según qué C se tome, y en general un bloque anterior no
              declara nada.
              Explotación: el atacante gana el primer billete tras la frontera (slot s_a,
              el más temprano) y lo RETIENE hasta k/λ = 18 s. Mientras, los honestos
              producen el decisor D declarando el candidato honesto C_h con t(C_h) > t(C_a).
              Al publicar C_a, «el primer bloque de cadena con slot ≥ t(C_a)» pasa a ser un
              bloque anterior a D que no declaró nada. Una implementación lo salta (canónico
              = C_h), otra lo trata como inválido o como «sin inyección». Split.
UBICACIÓN:    propuesta R-CAN-2, R-CAN-1
MITIGACIÓN:   redactar R-CAN-2 como «el primer bloque de la cadena seleccionada de past(B)
              que declara inyector para la época j», y prohibir declarar un candidato cuyo
              t(C) sea anterior al slot del bloque de cadena precedente. Sin redactar.
```

```
HALLAZGO:     Cliente ligero: un servidor mentiroso presenta un flujo no canónico como
              canónico y la wallet de §26 no puede distinguirlo
SEVERIDAD:    pérdida-fondos (para el usuario de wallet ligera)
ESTADO:       CONFIRMADO (heredado y agravado)
ESCENARIO:    El servidor entrega la historia bajo un flujo minoritario (que existe, es
              válido y verifica: R-CAN-1). La wallet verifica cabeceras: soluciones + KZG +
              PoT del flujo que le den. Todo cuadra. Lo único que distinguiría el canónico
              es el PESO, y `blue_work` en la cabecera es una afirmación del productor,
              comprobable solo coloreando todo el DAG (`post_pow_validation.rs:47-53`,
              c338d495); bajo PoAS afirmarla es gratis. §4.6 dice que el flujo canónico «se
              puede acreditar con las mismas pruebas» — esas pruebas de peso no existen ni
              en Kaspa ni en la propuesta.
              La wallet necesitaría: un compromiso acumulativo de peso verificable
              (MMR de cabeceras + prueba de poda con niveles), que §4.6 declara abierto.
UBICACIÓN:    propuesta §4.6; SPEC.md §26
MITIGACIÓN:   sin mitigación conocida. §26 no sobrevive, igual que en las dos rondas
              anteriores.
```

---

## 2 · Ataques probados y descartados

- **Balance attack entre flujos (vector 2) — NO FUNCIONA, medido.** Extendí el simulador (`d8b/balance.py`): dos flujos, honestos siguen el más pesado con retardo D=4 s, atacante con información perfecta, retención y **lotería independiente por flujo** (concesión de R-CAN-7), liberando lo mínimo para invertir el liderazgo. Resultado a q=1, 40 semillas: no-convergencia media **17,3 s (α=0,10)**, **20,9 s (α=0,20)**, **24,4 s (α=0,33)**, máximo 60,6 s. Razón: cuando los honestos convergen, la brecha crece linealmente a (1−α)λ y el atacante solo aporta αλ por flujo. Honestos enrojecidos por época de 250 s, arranque partido, 200 semillas: **1,81 % sin atacante**, 1,61 % (α=0,10), **2,33 % (α=0,33)**, p90 5,7 %, máx 12,2 %. **La estimación de §4.1 (~2 %) es correcta y el atacante la empeora ~0,5 puntos.** No consigue encadenar épocas: 20-25 s de no-convergencia frente a 250 s de época. *Reserva:* mi modelo usa desempate determinista y honestos que siguen al líder; un modelo con vistas heterogéneas podría alargarlo.
- **Equivocación de candidato con el mismo billete (vector 5) — no parte el flujo**, por la misma razón que en la ronda 2: entropía = `blake3(chunk‖pot_output)` y `t = slot+δ` dependen del billete, no del bloque (`subspace-verification/src/lib.rs:442-446` @ f8842d0). Pero abre N1, que es un efecto *distinto* al que el vector preguntaba.
- **Épocas colapsadas — cerrado.** Contar la época en bloques de la cadena garantiza que existe un «primero tras 50j» y que ninguna frontera se salta.
- **Fusión multi-flujo sumando pesos (D9 A3) — cerrado.** Los bloques de flujos no canónicos son rojos, peso cero, y no se pueden sumar. La construcción «m flujos → m·α·λ» no aplica. Lo que sobrevive de ella es coste de verificación (N2), no peso.
- **n-split de Filecoin — no aplica**, por la misma razón que en la ronda 1: los honestos fusionan.
- **Censura por flujo (vector 4) — no rentable.** No referenciar bloques ajenos reduce el propio `past` y por tanto el propio `blue_work`, y el k-cluster se calcula en el pasado del fusionador honesto, que sí los referencia. El atacante pierde. Lo que sí funciona es el **retraso selectivo** contra R-CAN-6 (griefing sin espacio), que es el hallazgo no cerrado de la ronda 2.
- **Ploteo dirigido por lookahead — MEJORA respecto a la ronda 2.** Honesto: `δ − D ≈ 11 s`, el de Autonomys. Bajo su propio candidato el atacante conoce t(C) al crearlo y puede precomputar hasta la siguiente inyección: ~250 s a q=1. Con el ploteo medido (69,363 s/sector, GTX 1070): **3,6 GiB/GPU**; con la extrapolación a GPU tope (4,28 s): **58 GiB/GPU**. Frente a los 15,1 / 261 GiB de la ronda 2, es 4× mejor. **Este es el segundo acierto real de la propuesta.**
- **Desempate gratis — cerrado** por `solution_distance`. Queda sin definir el desempate ante colisión de distancias (menor).
- **Inflación por coinbase de rojos — cerrado** por R-CAN-3, condicionado a que se implemente literalmente «la coinbase no se aplica», no solo «la emisión es sobre azules».

## 3 · No pude analizar

- **φ con la palanca real.** El atacante mina sus propios candidatos, pero solo los anteriores al decisor pueden ganar: ~αλ×15 s = 1,5 (α=0,10) a 5 (α=0,33) suyos más los ~4 honestos. Palanca ≈ 4-9 frente a ~4 en la ronda 2: **no menor, probablemente algo mayor**. El φ resultante es de D9; doy la palanca medida, no el umbral.
- **Retención del candidato propio (vector 3) cuantitativa:** el límite es k/λ = 18 s frente a p50 de convergencia 9 s; el atacante gana lookahead sobre su flujo privado, pero cuántos billetes extra obtiene exige simular la lotería multi-flujo con IOPS, no lo hice. La cota de IOPS honesta sí: §21 da 4 161 lecturas/slot por flujo con 4 TiB; **25 flujos = 104 k IOPS = un SSD entero**, luego el granjero honesto no puede auditar el espectro de flujos y el atacante sí puede auditar los 2-4 que le importan.
- **Coste real de la re-verificación tras recoloreado** con un almacén que cachee color por (bloque, época): no existe ese diseño.
- **`s_bucket` vs `chunk` en la identidad de billete** (`proving.rs`): sigue sin verificar desde la ronda 1.

## 4 · Veredicto

**¿Cierra los hallazgos anteriores?** Cierra cuatro de verdad —validez relativa, épocas colapsadas, desempate por hash, inflación por coinbase de rojos— y **cierra el que mató a la ronda 2**: la validez es absoluta y bien fundada, y la curación por fusión vuelve. Además mejora el lookahead 4× respecto a la ronda 2. Aplaza sin resolver poda, cliente ligero, C-REORG-07, C-EXP-04 y el griefing por retraso.

**¿Qué abre?** Un vector estructural que las dos rondas anteriores no tenían: **la definición de candidato no acota el número de flujos**. Un billete cualquiera de la época, con `parents = {bloque frontera}`, es un candidato legal, abre un flujo legal, y ese flujo queda en la historia como coste de verificación permanente e impodable. 1,25 núcleos continuos con α=0,10; 4,1 con α=0,33; 12,5× a 41× el coste de PoT de la cadena canónica, para siempre y para todo nodo. La estimación de §4.4 es 4-8× optimista, y su prefiltro de relé o es evadible o reintroduce la partición que la propuesta acaba de eliminar. Y R-CAN-3 enrojece por hash de candidato en vez de por flujo, lo que regala un griefing de media red con un solo billete.

**¿Más cerca o más lejos?** **Más cerca que las dos anteriores.** La ronda 1 moría por split honesto e inflación de peso; la ronda 2 moría por validez relativa y pérdida de la fusión — fallos de los que no había salida. Los de esta ronda son de dos clases distintas: N1, N3, N6 y N7 son **redacción** (arreglables sin cambiar el diseño); N5 y N8 son **deuda ya conocida**; y solo N2/N4 —el coste de verificación no acotado por flujos y el dilema relé/fusión— son de diseño. Y N2 tiene una dirección de arreglo que no existía antes: acotar el conjunto de candidatos sin volver a la posición ordinal. No la tengo. Pero es la primera vez en tres rondas que el problema abierto es «acotar un conjunto» y no «reconciliar dos exigencias contradictorias».

**Mi recomendación:** no tocar el SPEC. Antes, en este orden: (1) redactar R-CAN-2 y el caso «sin inyector» sin ambigüedad; (2) cambiar R-CAN-3 a comparación por (entropía, t); (3) encontrar una cota al número de candidatos por época que no sea relativa al fusionador — y si no la hay, decirlo, porque entonces N2 es fatal; (4) φ con la palanca de 4-9 candidatos, que es trabajo de D9.
