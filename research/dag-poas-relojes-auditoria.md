# Relojes efímeros — auditoría D9+D8 (sexta ronda) y cierre

**Fecha:** 2026-09-08 · Audita `dag-poas-relojes-efimeros.md` · D9 y D8 en Sonnet 5, ambos
completos. Scripts en el scratchpad de la sesión (`d9/relojes_*.py`).

## 0 · Veredicto

**No viable, pero es la ronda con el hallazgo más interesante de las seis: por primera vez la
viabilidad no cae de un análisis único, sino que depende de un parámetro de diseño que nadie fijó
— y en la rama buena de ese parámetro, el mecanismo funciona parcialmente por primera vez sin
depender de la velocidad del VDF del atacante.**

**Lo que cierra de verdad (D8 y D9 coinciden).** La validez vuelve a ser absoluta y bien fundada
por inducción sobre `past(b)`, sin relatividad al fusionador: cierra de raíz el fallo que mató las
rondas 2 y 4. Y como cada reloj vive `I` slots y no se pliega, la justificación de un reloj muerto
no encadena con el resto de la historia y se puede descartar tras ese tiempo: cierra el "4 GB/año
impodable" que abrió la ronda 2.

**El hallazgo nuevo de D9: la cota de fusión a profundidad `k` es un segundo mecanismo temporal
que la propia propuesta no vio.** Para que los bloques retenidos en privado cuenten, el atacante
tiene que fusionarlos dentro de `k` de la punta real, y eso da un presupuesto de tiempo real
`T_budget = k / ((1−α)λ)`. Si `k` es el mismo que este proyecto ya calibró en las cinco rondas
anteriores (18 a 793 según la ecuación de BDK), ese presupuesto son de 20 segundos a 20 minutos, y
**compite directamente con el tiempo del VDF**: la ceguera vuelve a depender de la velocidad del
atacante, exactamente como en las rondas 2 y 4. Si en cambio `k` se fija como una poda real al
estilo Kaspa, del orden de un día de bloques, el presupuesto es enorme y la ceguera es real: el
grinding pasa a depender solo de cuántos bloques propios tiene el atacante en la ventana, no de su
velocidad de VDF, y da un umbral que va de 0,31 con un solo bloque propio a 0,45 con cien. **La
propuesta usa "como Kaspa" para las dos cosas a la vez sin distinguirlas, y esa es la decisión de
diseño que falta.**

**Y aunque se elija bien esa rama, D8 encontró un segundo camino de grinding que no depende de
nada de esto.** El mínimo del conjunto se calcula sobre los bloques azules del pasado del propio
bloque, y ese pasado lo elige el autor **al escoger qué padres pone**, entre tips honestos ya
públicos. No hace falta retener nada propio ni esperar ningún VDF: basta probar en privado, antes
de publicar, distintos subconjuntos de padres públicos y quedarse con el que da el mejor resultado.
Es gratis, no depende de si hay o no plazo, y no está cerrado por ninguna de las dos ramas de D9.

**Lo demás que D8 encontró, también sin depender del parámetro `k`:**
- Ningún reparto de la recompensa entre los bloques azules de un slot evita el incentivo a inflar
  el propio recuento; uno de los tres esquemas razonables reabre además el desempate gratuito por
  hash que ya se había cerrado en la primera ronda.
- El coste de verificar los relojes ajenos no tiene cota: es el mismo espionaje de flujos de la
  tercera ronda con otro generador.
- El filtro de auditoría que debía igualar el coste entre honesto y atacante hace lo contrario: el
  atacante conoce sus relojes de antemano y audita solo los suyos; el honesto tiene que cubrir
  todos los que ve, inflados por el atacante.
- El cliente ligero queda **peor** que en las cinco rondas anteriores: al no existir ningún reloj
  privilegiado, no hay nada que una wallet pueda preguntar para distinguir un servidor honesto de
  uno que sirve un sub-DAG entero, autoconsistente y formalmente válido.
- La caducidad de sectores se puede mover con bloques que cuentan de verdad como azules, no solo
  con basura roja descartada, lo que agrava el problema de C-EXP-02/04 que ninguna ronda ha cerrado.

## 1 · Por qué esto no cambia el cierre de P-038

Aunque el mecanismo de acuerdo sobre la ventana es sólido (D9 lo reprodujo con el mismo lema exacto
de la ronda 5: retardo acotado implica acuerdo perfecto con margen igual al retardo máximo), y
aunque existe una rama de parámetros en la que la ceguera temporal es real, el diseño completo cae
por razones que no dependen de esa elección: el reparto de recompensa, el coste de verificación sin
cota, la ruptura de paridad del filtro, el cliente ligero sin nada que verificar, y sobre todo el
grinding gratuito por elección de padres, que es estructural y no un parámetro que se pueda ajustar.

**El patrón de las seis rondas se mantiene y se afina.** Las cinco primeras mostraban que hace
falta un evento acordado a profundidad cero e impredecible, y que cualquier forma de fabricarlo
paga con lookahead, partición o deriva cero. Esta sexta ronda, al eliminar la necesidad de elegir
entre relojes, evita esas tres consecuencias concretas — y a cambio abre una cuarta, que ninguna
ronda anterior tenía: cuando todo bloque de todo reloj cuenta, la cantidad de relojes que un
participante puede sostener se convierte directamente en cuota de recompensa y en coste que puede
imponer a los demás. No es una variación del mismo problema: es un problema distinto, con la misma
raíz de fondo, que el propio autor de la propuesta señaló sin cerrar en su §3 y que D8 confirmó sin
mitigación conocida.

## 2 · Lo aprovechable

- El lema de acuerdo con retardo acotado (`Λ ≥ D` basta) es ya el segundo uso limpio del mismo
  resultado (ronda 5 y esta), y queda como herramienta general para cualquier evento raro que se
  necesite acordar dentro de una estructura, DAG o no.
- La distinción entre "profundidad de anticono para color" y "profundidad de poda real" que D9
  fuerza a hacer explícita es útil más allá de esta propuesta: en la cadena lineal ya decidida no
  aplica, pero si algún día se recupera cualquier estructura con anticono, es una trampa a evitar
  desde el principio.
- Que cada reloj se pueda descartar tras `I` slots sin encadenar con el resto de la historia es una
  idea reutilizable si alguna vez se necesita acotar el crecimiento de justificaciones de PoT.

---

## Anexo A · Informe D9 (Sonnet 5), íntegro

# Informe D9 — refutación de `dag-poas-relojes-efimeros.md` (sexta ronda)

Leída la propuesta íntegra y los cinco informes previos (`dag-poas-auditoria.md` Anexo A, `dag-poas-inyeccion-auditoria.md` Anexo A, `dag-poas-candidatos-auditoria.md` Anexo A, `dag-poas-voto-auditoria.md` Anexo A, `dag-poas-balizas-auditoria.md` Anexo A) y `dag-nativo-poas-propuesta.md §2`. Scripts en `/tmp/claude-1000/-home-katana-zeo/0cfccf9e-55ae-4058-bcf4-31f0987f1dbd/scratchpad/d9/relojes_phi_j.py`, `relojes_fusion_deadline.py`, `relojes_acuerdo.py`.

**El teorema de cierre de la ronda 5 no aplica aquí, y hay que decirlo explícitamente**: ese teorema (identidad gratis en PoAS derrota cualquier mecanismo de exclusividad *entre relojes*) presupone que hay algo que elegir entre relojes. Esta propuesta elimina precisamente eso: todo bloque válido bajo cualquier flujo es azul y cobra, no hay "reloj ganador" que partir por Sybil. Lo que sí se traslada, en forma distinta, es la lógica de fondo: sigue habiendo una **unidad de discreción subdivisible a coste marginal bajo** — aquí no es la identidad, es la elección de qué prefijo de los propios bloques ganados incluir en la ventana. Esa discreción es exactamente el objeto que BDK+19 cuantifica como *grinding*/double-dipping, no Sybil de identidad. Son dos vulnerabilidades distintas; la de esta ronda es la segunda.

---

## AFIRMACIÓN A — no forcing function explícita

AFIRMACIÓN: "Nada en el diseño (§1) obliga a revelar la elección de bloques de la ventana antes de terminar de evaluar las j+1 ramas; la cota de fusión a profundidad k limita cuán viejo puede ser un padre, no cuándo hay que publicar" (§4 de la propuesta).
CLASIFICACIÓN: DEMOSTRADO
DERIVACIÓN: Lectura exhaustiva de §1. Las únicas reglas temporales explícitas son: (i) `W_k` cierra en `kI − D_v − Δ_rojo` (fija qué bloques *pueden* entrar en la ventana, no cuándo hay que declarar la elección); (ii) la cota de fusión acota antigüedad de padres, no momento de publicación; (iii) nada relaciona "reloj de b" con "reloj del pasado de b". No hay ninguna cuarta regla. El atacante puede computar `semilla_k` para cada uno de los `j+1` prefijos de sus `j` bloques propios, evaluar `VDF(semilla,D_v)` para cada uno —secuencial (`D_v(j+1)`) o en paralelo con `j+1` timekeepers (`D_v`)— y decidir después. Confirmado.
ENTEROS: no aplica.
ADVERSARIO: el atacante no necesita explotar nada aquí; simplemente usa la ausencia de regla. Lo consigue.
IMPACTO: si nada más lo corrige, cualquier grinding queda sin coste temporal, sólo con el coste combinatorio de BDK.

## AFIRMACIÓN B — la hipótesis fuerte ("anulada, no degradada"), sin condiciones

AFIRMACIÓN: "La ceguera por retardo de VDF queda anulada por completo, no degradada, porque no hay ninguna carrera que perder" (§4, hipótesis del agente principal).
CLASIFICACIÓN: REFUTADA — como enunciado *incondicional*.
DERIVACIÓN: la cota de fusión a profundidad `k`, leída como límite de **antigüedad real** de un padre (no como límite estructural bajo control del propio atacante), sí introduce un plazo de reloj indirecto. Si el atacante retiene sus `j` bloques y tarda un tiempo real `T` en decidir (computando VDFs), la cadena honesta avanza `≈(1−α)λT` bloques mientras tanto. Cuando finalmente publica —fusionando sus bloques retenidos con las puntas honestas actuales, que es la única forma de que pesen— la validez exige que sus bloques no queden a más de `k` de profundidad de esa fusión. Eso da un presupuesto real:

`T_budget(k,α,λ) = k / ((1−α)λ)`

Verificado (`relojes_fusion_deadline.py`, q=1, λ=1): con el `k` que **todas las rondas anteriores de este proyecto han calibrado** (18 con solo el término de Poisson de BDK ec.2, 793–7 993 con la ecuación completa), el presupuesto es de **20–27 s a k=18** y de **880–1 190 s a k=793**, para α∈{0,10; 0,25; 1/3}. Con `D_v` de "decenas de segundos" (necesario para que el VDF sea lento de verdad — 30–60 s en los ejemplos), **ya el mero D_v de UNA evaluación paralela excede el presupuesto a k=18** (30 s > 24 s a α=0,25). A k=793 el presupuesto sobra con holgura para D_v secuencial hasta j≈10.

La propuesta dice "como Kaspa" sin dar el número de `k`, y admite explícitamente en §3.2 que está "acotado por la banda de frontera, pero sin número". Si se elige un `k` a escala de poda real de Kaspa (orden de un día de bloques, ~86 400 a q=1), el presupuesto es de horas y no compite con nada: la hipótesis fuerte se sostiene sin matices. Si se hereda el `k` que este proyecto ya usa en todas sus rondas anteriores (18–793, que es GHOSTDAG-k, no poda), el plazo reaparece y compite directamente con `D_v`.
ENTEROS: `k`, `j`, `α·λ·T` truncados a enteros de bloques; no cambia el orden de magnitud del hallazgo.
ADVERSARIO: puede evitar el plazo eligiendo evaluación paralela (coste fijo `D_v`, no `D_v(j+1)`) y escogiendo `j` moderado; pero si `k` es pequeño, ni siquiera eso basta.
IMPACTO: si se ignora, el proyecto adoptaría "no hay ceguera" como verdad general cuando depende de un parámetro sin fijar; si se fija mal (k pequeño con D_v grande), el mecanismo de fusión rechaza silenciosamente los bloques del atacante — un efecto protector *no diseñado a propósito*, y por tanto no controlable ni calibrado.
CORRECCIÓN: la propuesta necesita fijar y **derivar** `k` de la cota de fusión (no reusar sin más el `k` de GHOSTDAG de rondas anteriores, que es un objeto distinto: anticono para color azul, no antigüedad de padre) y declarar si su intención es "poda al estilo Kaspa real" (grande, no interfiere) o "límite estrecho" (interfiere y por tanto es la defensa real, con su propio coste sobre reorgs honestas).

## AFIRMACIÓN C — ganancia de "elegir el mejor de j+1", condicionada a que B se confirme sin plazo

AFIRMACIÓN: si no hay plazo (k grande, poda real), la ganancia de evaluar `j+1` semillas privadas y publicar la mejor es la de BDK+19 ec. 39 con `c=j+1` niveles, y es **independiente de v** (velocidad del VDF del atacante), a diferencia de todas las rondas anteriores.
CLASIFICACIÓN: VERIFICADO COMPUTACIONALMENTE (dominio: `c∈{1,...,101}`, fórmula re-verificada contra los valores publicados φ₁₆=1,4678 y φ₅₀=1,2815, coincidencia exacta a 4 decimales).
DERIVACIÓN: `relojes_phi_j.py`. Tabla directa (umbral equivalente `1/(1+φ_c)` con `c=j+1`):

| j | 0 | 1 | 2 | 4 | 8 | 15 | 30 | 50 | 100 |
|---|---|---|---|---|---|---|---|---|---|
| φ_c | 1,00 | 2,23 | 2,01 | 1,80 | 1,61 | 1,47 | 1,35 | 1,28 | 1,21 |
| umbral | 0,50 | 0,31 | 0,33 | 0,36 | 0,38 | 0,41 | 0,43 | 0,44 | 0,45 |

Es continua y **sin umbral en v**: no aparece `v` en la fórmula porque, sin plazo, el atacante siempre completa las `j+1` evaluaciones (a la velocidad que sea) antes de decidir. Esto es cualitativamente distinto de las rondas 2 y 4 (lookahead ∝ `I(1−1/v)`, siempre creciente con v y nulo si v=1): aquí la ganancia existe incluso con `v=1` exacto, porque el juego no es "adelantarse en tiempo real", es "muestrear más veces y quedarse con la mejor".
ENTEROS: la fórmula es continua; no hay truncamiento relevante.
ADVERSARIO: consigue el máximo de ganancia disponible en el diseño, condicionado a A/B.
IMPACTO: si B se confirma sin plazo, el umbral de seguridad del diseño no es 1/2 sino el punto fijo de la tabla — y **empeora con `j` pequeño**, no con `j` grande: `j=1` ya da umbral 0,31, peor que cualquier α* de las cinco rondas anteriores salvo el semilla-anclada de la ronda 4 (α≈0). Un atacante no necesita muchos bloques propios en la ventana para grindear con fuerza.

## AFIRMACIÓN D — hipótesis débil del autor (degradación, no anulación), con ec. 39 y `c_a=j` libre

AFIRMACIÓN: "el umbral se degrada pero queda por debajo de la mitad" (§3.1 de la propuesta).
CLASIFICACIÓN: VERIFICADO COMPUTACIONALMENTE, con una laguna explícita.
DERIVACIÓN: la propuesta nunca fija la **duración** de la ventana `W_k` (solo su instante de cierre), así que `j` no tiene una expresión cerrada en `α`. Punto fijo autoconsistente `α* = 1/(1+φ(α*λW))` para `W` como parámetro libre (λ=1, q=1):

| W (s) | 10 | 24 | 40 | 100 | 200 | 372 | 600 | 1200 |
|---|---|---|---|---|---|---|---|---|
| α* | 0,339 | 0,385 | 0,406 | 0,435 | 0,451 | 0,462 | 0,469 | 0,477 |

Para α∈{0,10; 0,25; 1/3}: con cualquier `W≥24 s` el punto fijo **ya supera 0,10 y 0,25** en el sentido de que un atacante con esa fracción de espacio SUPERA el punto fijo de seguridad (α*<α exige que α real esté por debajo de la tabla para estar seguro); a α=1/3, con `W≥40 s` el punto fijo cae por debajo de 0,4057, y el atacante con α=1/3 excede el umbral solo si W≳400s aproximadamente lo iguala. El resultado es DEGRADACIÓN, nunca anulación total (todos los α* < 0,5), coherente con la hipótesis débil del autor — **pero solo bajo el supuesto no escrito de que `W_k` tiene una duración concreta**, que la propuesta no fija.
ENTEROS: `j` es Poisson entero; el punto fijo usa su media, no su cola — no cubre varianza (laguna adicional, no cerrada aquí).
ADVERSARIO: gana más cuanto mayor es `W` (más bloques propios para grindear); el diseñador tiene incentivo a hacer `W` pequeña, lo que en las rondas 2 y 4 chocó siempre con otros requisitos (acuerdo, madurez).
IMPACTO: sin fijar `W`, este umbral no es una cifra del SPEC, es una familia de cifras.
CORRECCIÓN: fijar `W_k` (duración de la ventana, no solo su cierre) es un prerrequisito, no un detalle.

## Preguntas cortas

**Acuerdo sobre el conjunto de la ventana (`Λ=D_v+Δ_rojo` vs. retardo `U(0,D)`)**: reproducido (`relojes_acuerdo.py`, 200 000 réplicas): `P(discrepancia honesta)=0` exacto para `Λ≥D`, igual que `baliza_acuerdo.py` de la ronda 5. Es el mismo lema general (retardo acotado ⟹ `Λ≥D` basta), reaplicado a un objeto distinto. Con `D_v` de decenas de segundos, la condición `Λ=D_v+Δ_rojo≥D` (D≈unos segundos de propagación) queda sobradamente satisfecha — de hecho más cómoda que en la ronda 5, porque aquí `Λ` es grande *por otra razón* (que el VDF sea lento), no hay que forzarla artificialmente. CLASIFICACIÓN: DEMOSTRADO (reutilización directa de un teorema ya cerrado), compatible sin tensión.

**Reintroducir temporización sin reloj canónico**: explorado, no resuelto. Una opción es exigir que `b` publique un *compromiso* (hash) de su elección de prefijo de ventana antes de poder usar el resultado de la evaluación — pero verificar que el compromiso llegó "antes" exige de nuevo una referencia temporal objetiva y verificable, que es justo lo que el diseño evita al no tener reloj canónico entre relojes. Usar el propio VDF como prueba de "no pudiste haber evaluado ya" es circular: reintroduce la estructura de carrera de primer llegar que el diseño quiere evitar. La otra vía —la que de hecho usa Chia y BDK— no es forzar revelado temprano sino **subir el número de compromisos independientes por unidad de tiempo** para que la ganancia marginal de cualquier elección tienda a cero (φ_c→1 cuando c→∞); eso es exactamente lo que hace `c=50` en Autonomys. Aplicado aquí: cuantas más "sub-ventanas" o puntos de compromiso obligatorios haya dentro de `W_k`, menor el `j` efectivo por punto y menor la ganancia — pero eso no anula el mecanismo, solo lo diluye, con coste de más verificación (hueco de D8). PLAUSIBLE, NO DEMOSTRADO como reparación; abierta.

---

## Cierre

**REFUTADAS:** hipótesis fuerte incondicional ("anulada, no degradada", §4) — depende del valor no fijado de `k` en la cota de fusión; si `k` es GHOSTDAG-k heredado (18–793) reaparece un plazo real que compite con `D_v` y reintroduce dependencia de `v`. *Impacto: el SPEC no puede afirmar "sin ceguera" sin fijar `k` primero.*

**NO DEMOSTRADAS:** duración de `W_k` (no está en la propuesta, y todo el umbral D depende de ella) · si `k` de fusión debe leerse como GHOSTDAG-k o como poda-Kaspa (la propuesta usa "como Kaspa" para ambos sentidos sin distinguir) · varianza de `j` alrededor de su media en el punto fijo · robustez del resultado de acuerdo cuando `D_v` mismo se vuelve el reloj implícito de facto.

**COTAS CORREGIDAS:** umbral bajo grinding: 0,31 (j=1) a 0,45 (j=100), no "por debajo de la mitad" sin más — a `j` pequeño está muy por debajo, no cerca de 0,5 · presupuesto de plazo por fusión: 20–27 s (k=18) a 880–1190 s (k=793) a α∈[0,10;1/3], no "sin límite" como asume el texto literal de §4.

**LO QUE NO PUDE VERIFICAR:** el valor numérico real de `k` (no está en ninguna fuente citada, ni en la propuesta) · si "chunk_min" admite grinding adicional sobre qué chunk exacto usar dentro de un mismo bloque (otra palanca no cubierta por φ_c, análoga a la de la ronda 2 §3.4) · coste de verificar `m` relojes vivos (delegado a D8 explícitamente en §7 de la propuesta).

## VEREDICTO CLARO

**DEGRADADA CON NÚMERO, condicionalmente ANULADA.** La hipótesis fuerte del agente principal es correcta como lectura literal de §1 (no hay regla de reveal temprano) pero **incorrecta como conclusión incondicional**: la propuesta tiene, sin saberlo, un segundo mecanismo temporal —la cota de fusión a profundidad `k`— que sí puede actuar como plazo real, y si se hereda el `k` que el propio proyecto ya calibró en cinco rondas anteriores (18–793), la ceguera reaparece y vuelve a depender de `v`. Si en cambio `k` se fija a escala de poda real (órdenes de magnitud mayor, sin relación con GHOSTDAG-k), la anulación es real y el umbral resultante es el de BDK ec. 39 con `c=j+1`, **independiente de v** — la primera vez en seis rondas que aparece un mecanismo cualitativamente distinto de todos los anteriores. Ambas ramas son matemáticamente sólidas; cuál aplica es una decisión de diseño no tomada, no un resultado.

**Lo que habría que demostrar antes del SPEC:** (1) fijar y derivar el `k` de la cota de fusión, distinguiendo explícitamente si es el `k` de GHOSTDAG (anticono, azul) o una poda distinta (antigüedad de parentesco), con su valor numérico; (2) fijar la duración de `W_k`, no solo su cierre; (3) demostrar si el presupuesto `T_budget(k,α,λ)` compite o no con `D_v` bajo los valores elegidos, y si compite, rehacer el análisis de lookahead con `v` como en las rondas 2 y 4; (4) el reparto de coinbase por slot (§4 hueco menor, delegado a D8); (5) verificación de relojes ajenos con número, no solo "acotado".

**Comparación con las cinco rondas anteriores:** más cerca de viable que las rondas 1, 2 y 4 (que quedaban con partición honesta sin atacante o con lookahead de decenas de minutos), aproximadamente al mismo nivel que la ronda 5 (un resultado limpio y demostrado —aquí el acuerdo Λ≥D; allí también— y un núcleo que sigue sin resolverse), y algo mejor que la ronda 3 en el sentido de que evita el error de fondo que compartían las cinco (elegir entre relojes). Pero su viabilidad depende entera de una decisión de parámetro (`k` de fusión) que nadie ha tomado todavía, y esa decisión determina si el diseño tiene o no tiene ceguera — no es un detalle de calibración fina, es la pregunta central sin cerrar.

---

## Anexo B · Informe D8 (Sonnet 5), íntegro

# D8 · Auditoría adversarial de "relojes efímeros" (sexta propuesta)

**Fuentes:** `/home/katana/zeo/ZEROX/research/dag-poas-relojes-efimeros.md` íntegro; las cinco auditorías previas (`dag-poas-auditoria.md` §3, `dag-poas-inyeccion-auditoria.md` Anexo B, `dag-poas-candidatos-auditoria.md` Anexo B, `dag-poas-voto-auditoria.md` §3, `dag-poas-balizas-auditoria.md` Anexo B); `dag-nativo-poas-propuesta.md` §2; `rusty-kaspa@c338d495`; `subspace@f8842d0`; `SPEC.md` §12/§16/§20 (líneas ya citadas en rondas previas: 1734-1745 C-REORG-07, 1737 COINBASE_MATURITY, 1804-1832 C-EXP-02/04).

## 0 · Checklist — qué hereda esta ronda de las cinco anteriores

| Hallazgo previo | Ronda | En "relojes efímeros" |
|---|---|---|
| Split honesto sin atacante | 1,2 | Aplazado: se fusiona una discrepancia transitoria, pero no cubre el grinding privado que el propio autor admite en §3.1 |
| **`m` flujos → `m·α·λ`, umbral → 0** (D9, A3) | 1 | **Reabierto y ACEPTADO COMO DISEÑO.** §2: "las dos loterías existen y todo el mundo juega las dos... el peso cuenta bloques azules del DAG, vengan del reloj que vengan". Es literalmente la construcción que tumbó la Ronda 1, ahora sin la palabra "bug" |
| Cobertura racional → deriva cero (D9, R3) | 3 | No aplica en la forma de R3 (no hay "elegir seguir un flujo"), pero migra a captura de recompensa (H1/H3 abajo) |
| Validez relativa al fusionador / semilla anclada (R2, R4) | 2,4 | **Cerrado de verdad**: `semilla_k(b)` es función absoluta y bien fundada de `past(b)`. Es la mejora real de esta ronda |
| Coinbase de rojos ×10 (R1 At.3) | 1 | No tratado |
| Spam de flujos/candidatos, 1,25-4,1 núcleos (R3 N2) | 3 | Reabierto y agravado (H2) |
| C-EXP-02/04 | 2,3,5 | Sin tratar; §3.5 lo admite explícitamente ("sin especificar cómo, heredado") |
| Cliente ligero §26 | 1-5 | No mencionado |
| C-REORG-07 | 1 | No mencionado |
| Filtro τ / varianza del granjero pequeño | 5 (balizas) | Admitido por el autor, sin resolver |

La ganancia real de esta ronda es haber cerrado la validez relativa al fusionador. El precio es que, al aceptar la multiplicidad de relojes como diseño en vez de prohibirla, reintroduce el fallo que mató a la Ronda 1 por otra puerta, y la abre exactamente donde el propio autor y el agente principal ya señalaron el hueco (§3, §4).

## HALLAZGO 1 · Ningún reparto de coinbase por slot evita el incentivo a inundar

**Precondiciones:** ninguna; basta que existan ≥2 bloques azules en el mismo slot, lo que el diseño no solo permite sino que fomenta (auditoría contra `m` relojes vivos).
**Pasos:** comparo los tres esquemas razonables.

- *Igual entre azules del slot*: cada solución real que el atacante consiga convertir en un bloque **adicional** de ese slot (vía H2/H6: más relojes o más candidatos de padres) le da una fracción más de un pastel `C` fijo, a costa de los demás. La unicidad de billete (no escrita en esta propuesta: §0 dice explícitamente "esta propuesta no toca exclusividad de identidad") no impide esto porque cada reloj es un desafío distinto: el mismo chunk físico puede ganar en el reloj A y en el reloj B como dos "billetes" formalmente distintos. El atacante no fabrica espacio, pero multiplica *tickets* con el mismo espacio, y cada ticket adicional es un bloque adicional que dividende el mismo `C`.
- *Ponderado por peso*: `peso = ⌊2^128/(SR+1)⌋` es función de `SR` (parámetro de consenso), no de la distancia de la solución concreta (A6 de la Ronda 1, verificado). Es una constante para todos los bloques de la época: **matemáticamente idéntico al reparto igual**. No cambia nada.
- *Ponderado por orden de llegada*: "orden" solo puede ser un orden acordado (posición en el mergeset por `(blue_work, hash)`, `rusty-kaspa/ordering.rs:38-42`), y ese desempate por hash es gratis bajo PoAS (Ataque 1 de la Ronda 1: `reward_address` libre). Reintroduce, para decidir quién es "primero" dentro del slot, exactamente el agujero que la Ronda 1 ya encontró gratuito. Además "llegada" no es una medida consensuada sin ese desempate: dos nodos pueden ver órdenes de llegada de red distintos.

**Coste:** cero espacio extra; CPU para los relojes/candidatos extra (H2/H6).
**Efecto:** reparto igual/ponderado por peso = incentivo directo a maximizar el propio recuento de bloques por slot vía multiplicidad de relojes; reparto por orden = grinding gratis del desempate.
**GRAVEDAD:** pérdida-fondos (redistribución desde honestos hacia el atacante, sin inflación total del emisión pero con captura desproporcionada de lo emitido).
**ESTADO:** CONFIRMADO (los tres esquemas se derivan por álgebra directa de reglas ya escritas o de precedentes ya auditados; no necesito simulación nueva).
**MITIGACIÓN:** ninguna encontrada mientras el reparto dependa solo de "cuántos bloques azules hay en el slot" y esa cantidad sea manipulable vía H2/H6 sin coste de espacio.

## HALLAZGO 2 · Verificar relojes ajenos: coste sin cota, atacado desde el propio hueco admitido en §3.2

**Precondiciones:** cota de fusión a profundidad `k` (≈18-24, calibración heredada de las Rondas 1 y 3); un billete real.
**Pasos:** el propio §3.1 admite que el grinding privado da "`j+1` sorteos... compone entre intervalos". Con `j` acotado por cuántos bloques propios entran en la ventana de fusión de profundidad `k`, el atacante sostiene hasta `k+1 ≈ 19-25` relojes vivos simultáneos por época, de forma persistente (no un pico puntual: cada época repite el proceso). Cada uno de esos relojes es un flujo VDF de `D_v` segundos que **todo nodo honesto debe computar** para validar cualquier bloque que lo referencie, porque "los granjeros auditan contra todos los relojes que definan los tips a profundidad `k` en su vista" (§1) — no es opcional.
**Coste:** análogo al ya medido en la Ronda 3 (N2): `α·λ` billetes por época abren `α·λ·(ventana)` flujos; ahí dio 1,25 núcleos continuos con `α=0,10` y 4,1 con `α=0,33`, 12,5×-41× el coste del flujo canónico solo. Aquí el mecanismo generador es distinto (relojes en vez de candidatos-inyector) pero la aritmética de "un billete abre un flujo persistente que todo el mundo debe verificar" es la misma construcción.
**Efecto:** DoS de verificación permanente e impodable (el propio autor ya lo señala sin número: "acotado por la banda de frontera, pero sin número", §3.2).
**GRAVEDAD:** DoS.
**ESTADO:** SOSPECHA fuerte con mecanismo confirmado por precedente cuantificado (Ronda 3 N2) y por admisión propia del autor (§3.1, §3.2); el número exacto depende de `D_v`, que la propuesta no fija — no invento la cifra final.
**MITIGACIÓN:** ninguna dentro del esquema tal como está escrito; acotar el número de relojes exigiría exactamente la regla de exclusividad que §0 dice que la propuesta no toca.

## HALLAZGO 3 · El filtro τ rompe la paridad honesto/atacante, no la mantiene

**Precondiciones:** `m` relojes vivos (H2), τ fijo por protocolo.
**Pasos:** la afirmación "τ=1/2 → dos relojes cuestan lo mismo que uno" solo es cierta si **todos los participantes auditan el mismo `m`**. Pero `m` es atacante-inflable (H2) y el atacante, al ser quien crea sus propios relojes vía grinding, sabe de antemano (los computó en privado antes de publicar) qué chunks de su espacio real pasan el filtro contra sus propios relojes: no necesita auditar el espectro completo de `m` relojes con IOPS aleatorios, solo el subconjunto que él mismo controla. El honesto, en cambio, para no perder ingreso, debe auditar "todos los que definen los tips" — es decir, el `m` completo, inflado por el atacante.
**Coste:** el atacante paga IOPS proporcionales a su propio subconjunto de relojes (pequeño, elegido); el honesto paga IOPS proporcionales al `m` total (grande, no elegido). Esto es asimétrico por construcción.
**Efecto:** rompe la paridad de coste que τ pretende garantizar; además el propio autor ya admite (§3.4) que τ sube la varianza del granjero pequeño incluso sin atacante, lo que va contra la prioridad de descentralización (P-036).
**GRAVEDAD:** DoS / menor (según se lea como coste o como varianza).
**ESTADO:** CONFIRMADO como mecanismo (se deduce directamente de quién controla `m` y quién debe cubrirlo); SOSPECHA en la magnitud exacta.
**MITIGACIÓN:** ninguna sin acotar `m` primero (H2), y la propuesta no lo acota.

## HALLAZGO 4 · C-EXP-02/04: "altura" se mueve con copias BLUE gratis, no solo rojas

**Precondiciones:** múltiples relojes vivos y fusionados como azules (§2: "un bloque bajo otro reloj no es inválido ni rojo por serlo: es un bloque").
**Pasos:** en las Rondas 2 y 3, mover `hash_bloque[altura_ploteo]` exigía copias ROJAS gratis (baratas pero descontadas del peso). Aquí, los bloques de un reloj forjado por el atacante que se fusionan normalmente con las puntas honestas **son azules** (el propio §2 lo dice como ventaja del diseño: "honestos ven esos bloques en los tips y los juegan también"). Eso significa que la posición en el orden topológico (`blue_score`) que define "altura" para C-EXP-02 se desplaza con bloques que SÍ cuentan, no solo con basura roja. Un nodo que aún no ha visto el reloj forjado calcula un `blue_score`/`altura` distinto del que ya lo fusionó → `desplazamiento = blake3(sector_id ‖ hash_bloque[altura_ploteo])` diverge → un sector caduca para un nodo y no para otro.
**Coste:** el mismo que H2 (crear relojes es CPU, no espacio).
**Efecto:** el mismo bloque válido para un nodo e inválido para otro (split de validación), agravado respecto a las rondas 2/3 porque la fuente de la perturbación es azul, no roja, y azul es exactamente lo que este diseño fomenta como normal.
**GRAVEDAD:** split.
**ESTADO:** SOSPECHA (depende de una definición de "altura" que la propuesta no da, §3.5 lo admite explícitamente como hueco heredado sin cerrar).
**MITIGACIÓN:** ninguna sin fijar `altura_ploteo` a profundidad mayor que la máxima perturbación por relojes vivos — no derivado.

## HALLAZGO 5 · Cliente ligero (§26): peor que en las cuatro rondas anteriores, no igual

**Precondiciones:** ninguna, solo la existencia del diseño.
**Pasos:** en las rondas 2-4 había, aunque frágil, la noción de UN inyector/candidato canónico que una wallet podría intentar contrastar entre varios pares. Aquí, por diseño, "no hay fork choice entre relojes: nunca" — no existe ningún reloj privilegiado que preguntar. Un servidor deshonesto sirve un sub-DAG bajo un reloj **enteramente autoconsistente y legítimamente válido** (§2 lo garantiza: cualquier bloque bajo cualquier reloj "es un bloque"), sin necesitar imitar ningún estado canónico porque no existe. La única señal que distinguiría el reloj "real" (el que de hecho tiene más peso agregado en la red) del inventado es `blue_work` acumulado, que —como en Kaspa— es una afirmación del productor comprobable solo coloreando todo el DAG (`post_pow_validation.rs:47-53`).
**Coste:** crear un reloj alternativo entero es CPU (H2), estrictamente más barato que forjar un inyector plausible en las rondas 2-4 (que exigía al menos anclarse a la cadena seleccionada real).
**Efecto:** una wallet ligera no tiene NADA que preguntar que la distinga de un servidor honesto, porque el diseño elimina la pregunta misma ("¿cuál es el canónico?") en vez de responderla.
**GRAVEDAD:** pérdida-fondos (usuario de wallet ligera).
**ESTADO:** CONFIRMADO como regresión relativa a las cuatro rondas previas.
**MITIGACIÓN:** ninguna conocida; §26 no sobrevive, y aquí sobrevive peor que antes.

## HALLAZGO 6 · Grinding privado, segunda vía: `chunk_min` se manipula elegit padres, sin retener nada propio

**Precondiciones:** un billete real en el espacio del atacante; capacidad de correr `S` VDFs de `D_v` segundos en paralelo (núcleos, no espacio).
**Pasos:** `chunk_min(azules de past(b) en W_k)` es función del **conjunto de bloques azules que caen en el pasado de `b` dentro de la ventana**, y ese conjunto lo determina el atacante al elegir **qué padres pone en `b`** — no necesita ninguna cadena privada retenida (a diferencia de §3.1). Todos los bloques candidatos a incluir/excluir son públicos y honestos: el atacante simplemente prueba localmente, antes de publicar nada, distintos subconjuntos de padres entre los tips visibles, calcula el `chunk_min` resultante para cada combinación, deriva `semilla_k` con una VDF de `D_v` segundos **por candidato** (en paralelo, sin dependencia secuencial entre candidatos distintos), y **publica solo `b` con el subconjunto de padres cuyo `semilla_k` resultante favorece más a su espacio real ya plantado**. No hay bifurcación visible: `b` parece un bloque normal referenciando un subconjunto de tips, indistinguible de un bloque honesto perezoso.
**Coste:** `S` núcleos × `D_v` segundos, cero espacio adicional. El número de subconjuntos de padres disponibles crece con el tamaño de la ventana `W_k`, así que el atacante no está limitado a "un bit" (publicar/retener) sino a cuántos núcleos puede pagar.
**Efecto:** amplificación de las oportunidades de auditoría del espacio real del atacante sin invertir en más espacio, **independiente de si D9 encuentra o no una función de temporización que fuerce el compromiso temprano** (este vector no necesita revelación tardía: opera antes de publicar nada, sobre datos ya públicos).
**GRAVEDAD:** inflación de participación efectiva (no de moneda, de cuota de sorteo) → alimenta H1 y H2.
**ESTADO:** CONFIRMADO como mecanismo estructural (se deriva directamente de la definición de `chunk_min` sobre `past(b)` elegible por el propio autor del bloque); SOSPECHA en la magnitud (`D_v`, tamaño de `W_k` y `S` no están fijados en la propuesta).
**MITIGACIÓN:** ninguna sin fijar `chunk_min` sobre un conjunto NO elegible por el autor de `b` (p. ej. todo `past(b)` completo, no un subconjunto vía padres) — cambio de diseño, no parámetro.

## Nota rápida · C-REORG-07, poda, propagación

**C-REORG-07** (Ataque 5, Ronda 1) no lo toca esta propuesta en absoluto: sigue siendo un problema del mecanismo de cadena seleccionada de GHOSTDAG, independiente de relojes. **Sigue abierto, sin mención.** **Poda**: aquí hay una mejora genuina no presente en la Ronda 2 — como cada reloj vive `I` slots y se resetea (no se pliega), la justificación PoT de un reloj muerto no encadena con el resto de la historia y puede descartarse tras `I` slots (no reproduce el "4 GB/año impodable" de R-INJ-2). **Propagación**: el ancho de banda para propagar `m` flujos vivos simultáneos escala con `m` (128 B/slot × relojes vivos), y como `m` es atacante-inflable (H2), esto amplifica el vector de H2 también en bytes, no solo en núcleos.

## ATAQUES PROBADOS Y DESCARTADOS

- **Cobertura racional de flujos → deriva cero (Ronda 3):** no reproduce en esta forma porque no hay "elegir seguir un flujo": todo se fusiona. El problema se traslada íntegro a captura de recompensa (H1) y coste de verificación (H2), no desaparece.
- **Validez relativa al fusionador (Rondas 2 y 4):** cerrado de verdad; `semilla_k(b)` es absoluta y bien fundada por inducción sobre `past(b)`. No encontré forma de reabrirlo.
- **Poda impodable como en R-INJ-2:** no reproduce en la forma original; los relojes ephemeral SÍ se pueden descartar tras `I` slots.
- **n-split de Filecoin puro:** no aplica, como en las cinco rondas anteriores (los honestos fusionan todas las puntas).

## NO PUDE ANALIZAR

- La magnitud exacta de H2/H3/H6 porque `D_v`, `Δ_rojo` y el tamaño de `W_k` no están fijados en la propuesta (el propio autor los deja "sin número").
- El acuerdo honesto sobre el conjunto de la ventana con retardo acotado (§6.3 de la propuesta, tarea explícita de D9, requiere simulación tipo `baliza_acuerdo.py`).
- La pregunta central del §4 (si existe una función de temporización que fuerce el compromiso temprano): es tarea de D9; mi Hallazgo 6 es deliberadamente independiente de esa respuesta.

## Veredicto final

**¿Cierra los hallazgos de las rondas anteriores?** Cierra uno de verdad y de forma sólida: la validez relativa al fusionador (Rondas 2 y 4). No cierra ninguno de los demás; el más grave —`m` flujos → `m·α·λ`, la construcción que mató la Ronda 1— lo **reabre explícitamente y lo presenta como característica del diseño**, no como fallo.

**¿Qué abre?** Traslada el problema de "qué reloj es canónico" (rondas 1-5) a "cuántos relojes puede sostener el atacante y cómo capitaliza esa cantidad": captura de recompensa vía reparto de coinbase (H1), DoS de verificación sin cota (H2), rotura de la paridad de coste que el propio filtro τ promete (H3), una vía de grinding sin coste de espacio adicional que no depende de retener nada (H6), y un cliente ligero estrictamente peor que en las cuatro rondas previas (H5) porque el diseño elimina la pregunta de canonicidad en vez de responderla.

**¿Más cerca o más lejos de viable que las cinco anteriores?** **Más lejos.** Las rondas 2-4 morían por una vía estructural pero acotable (lookahead, definición circular, deriva cero) que al menos generaba un intercambio cuantificable (parámetro contra seguridad). Esta ronda muere por aceptar como diseño la construcción que la Ronda 1 demostró fatal (`m` flujos → umbral 0) y no ofrece ningún parámetro que la acote: el propio documento admite en §3.2 que el número de relojes vivos está "sin número", y esa ausencia de número es exactamente donde entran H1, H2, H3 y H6. El núcleo de las cinco rondas anteriores —"hace falta un evento acordado a profundidad cero e impredecible, y el reloj no lo da"— sigue intacto aquí: lo que cambia es que esta ronda ya no lo busca, lo declara innecesario, y esa declaración es la laguna.
