# Inyección por candidatos resuelta por color — tercera propuesta para un DAG sobre PoAS

**Fecha:** 2026-09-07 · **PROPUESTA SIN AUDITAR** del agente principal, a petición de Katana
(«diseña un algoritmo que solucione de dónde sale la aleatoriedad del reloj y quién la acuerda»).
Tercera iteración. Las dos anteriores y sus refutaciones: `dag-poas-auditoria.md` (GHOSTDAG puro)
y `dag-poas-inyeccion-auditoria.md` (inyección anclada). Este diseño parte de lo que esas dos
auditorías dejaron demostrado y ataca el núcleo por otro lado. Debe pasar por D9 y D8.

## 0 · El núcleo, dicho con precisión

La inyección de entropía al PoT necesita tres cosas a la vez:

1. **Momento no simulable**: el instante en que se aplica debe depender de un bloque real, porque
   un bloque solo existe cuando un granjero gana en tiempo real y ningún VDF puede adelantarlo.
   Es lo que da a Autonomys un lookahead de `DELAY − D = 11 s` (D9, segunda auditoría, E2).
2. **Valor no moldeable**: `blake3(chunk ‖ pot_output)` del bloque, no su hash (Autonomys,
   `subspace-verification/src/lib.rs:444-446`).
3. **Acuerdo**: todos los honestos aplican la misma entropía en el mismo slot.

En una cadena lenta (1) y (3) se cumplen a la vez porque el bloque es único casi siempre (94 % de
las épocas a q = 120, D8). En un DAG rápido, en el borde de cada época hay ~4 bloques
incomparables durante ~10-60 s (D8: media 4,09, p99 57 s). Las dos propuestas anteriores
intentaron **evitar** ese desacuerdo: por posición ordinal (split honesto) o por profundidad L
(lookahead ×95, y con no-fusión: validez relativa y sin curación).

**Esta propuesta no evita el desacuerdo: lo hace barato.** Durante la ventana de convergencia
pueden coexistir varios flujos de PoT candidatos; los bloques bajo cualquiera de ellos son
**válidos** y se **fusionan**; la elección entre flujos la hace el **peso**, y los bloques del
flujo perdedor se vuelven **rojos** (sin peso, sin recompensa), no inválidos. Es lo que GHOSTDAG
ya hace con los bloques tardíos: el color es relativo al fusionador; la validez es absoluta.

## 1 · Definiciones

- **Flujo** `S(I)`: la cadena de PoT que resulta de inyectar `entropía(I) = blake3(chunk(I) ‖ pot_output(I))`
  en el slot `t(I) = slot(I) + δ`, con `δ` pequeño (Autonomys: 15 slots; ZEROX: a derivar en
  P-039, `δ > BLOCK_AUTHORING_DELAY + 1`).
- **Época**: se mide **en bloques de la cadena seleccionada**, `c = 50` (φ₅₀ = 1,2815; D9 demostró
  que definirla en tiempo cambia la seguridad). Cada bloque B sabe, por su propio pasado, cuál es
  la posición de su padre seleccionado en la cadena seleccionada de past(B) (es el `blue_score`
  restringido a la cadena, determinista).
- **Candidato a inyector de la época j**: un bloque C es candidato si en past(C) la cadena
  seleccionada tiene exactamente `50j − 1` bloques por debajo de su padre seleccionado, es decir,
  C es «el primer bloque tras la frontera 50j» **según su propio pasado**. Es una propiedad
  verificable de C sin ninguna referencia externa. Dos bloques con pasados distintos pueden ser
  ambos candidatos de la misma época: ese es el desacuerdo que se tolera.
- **Inyector declarado** `I(B)`: todo bloque B con slot ≥ t(C) para algún candidato C de la época
  vigente lleva en la cabecera el hash del candidato bajo cuyo flujo se produjo. `I(B)` **MUST**
  estar en past(B) y ser candidato de la época que corresponde a slot(B).

## 2 · Reglas

**R-CAN-1 · Validez absoluta.** B es válido si: su solución verifica bajo `S(I(B))` en slot(B);
su justificación de PoT cubre los slots desde el slot futuro de su padre seleccionado hasta el
suyo, calculada bajo `S(I(B))`; `I(B)` es candidato legal y está en past(B); y todos los bloques
de past(B) son válidos. **La validez no depende de quién fusiona.** Dos bloques bajo flujos
distintos pueden estar en el mismo pasado.

**R-CAN-2 · Inyector canónico del fusionador.** Para un bloque B (o el virtual), `I_j(B)` es el
inyector declarado por el **primer bloque de la cadena seleccionada de past(B) con slot ≥ t(C)**
para la época j. (La cadena seleccionada se calcula como en GHOSTDAG: padre seleccionado = padre
de mayor `blue_work`; cada bloque tiene su propio `blue_work`, calculado en su propio pasado.)

**R-CAN-3 · Color por flujo.** Al colorear el mergeset de B, un bloque X con `I(X) ≠ I_j(B)` para
la época de slot(X) es **rojo**, además de las condiciones del k-cluster. Rojo = sin peso, sin
recompensa, sin voz en el reajuste. Sus transacciones se aplican en el orden (como Kaspa) **salvo
la coinbase**, que no se aplica.

**R-CAN-4 · Peso y fork choice.** `blue_work(B) = Σ ⌊2^128/(SR+1)⌋` sobre los azules de past(B).
Padre seleccionado = mayor `blue_work`; empate por menor `solution_distance` (no por hash, que es
gratis bajo PoAS: D8). Como el peso compara **entre flujos**, el fusionador se une al flujo más
pesado: convergencia por peso, no por identidad.

**R-CAN-5 · Ventana de candidatos.** Un candidato C solo puede ser inyector declarado de bloques
B con `t(C) ≤ slot(B) < t(C′)` para todo candidato C′ de la época siguiente presente en past(B). Y un bloque cuyo `I(B)` no esté entre los candidatos
**vistos** (en past(B)) es inválido por R-CAN-1. El número de flujos por época está acotado por el
número de candidatos, y cada candidato cuesta un billete real bajo el flujo anterior.

**R-CAN-6 · Anticono anclado a slot.** Candidato X con `slot(X) < slot(B) − k/λ_est` es rojo (D8,
forma correcta de A5), con `X < k/λ` derivado junto con k.

**R-CAN-7 · Unicidad de billete.** Identidad `(public_key, sector_index, history_size, chunk, slot)`;
primera copia en el orden azul, resto rojas (U3′). Nótese que bajo flujos distintos el mismo
sector en el mismo slot produce **chunks distintos** (desafíos distintos): son billetes distintos
y ambos pueden existir; solo uno acaba azul porque solo un flujo es canónico.

## 3 · Por qué esto puede escapar del dilema

| Exigencia | Cómo se cumple |
|---|---|
| Momento no simulable | `t(C) = slot(C) + δ`: C es un bloque real. Lookahead ≈ `δ − D`, **el de Autonomys**, no L |
| Valor no moldeable | `blake3(chunk ‖ pot_output)` del candidato |
| Acuerdo | **Eventual, por peso.** Durante ~60 s coexisten flujos; el más pesado gana; los demás quedan rojos. No hay partición porque todo se fusiona |
| Multi-flujo del atacante (D9 A3, D8 At. 2) | Sus flujos privados se fusionan pero son **rojos** bajo el canónico: peso cero. Para que ganen deben superar en peso al honesto: Nakamoto |
| Validez relativa (D8 hallazgo 4) | No existe: validez absoluta (R-CAN-1); solo el color es relativo, como ya lo es en GHOSTDAG |
| Curación tras partición (D8 hallazgo 3) | Se conserva: al reconectar se fusiona; el lado ligero se vuelve rojo, no inválido |
| Épocas colapsadas (D8 hallazgo 6) | No aplica: la época se cuenta en bloques de cadena, siempre hay un «primero tras 50j» |
| Desempate gratis (D8 hallazgo 1) | `solution_distance` en vez de hash |

## 4 · Lo que cuesta, y lo que hay que atacar

1. **Pérdida honesta en la convergencia.** Los bloques honestos producidos bajo el candidato que
   pierde se vuelven rojos. Estimación: convergencia media ~12 s por época de ~300 s a q = 1, la
   mitad en el lado perdedor → ~2 % del peso honesto. Entra en el factor `(1−δ)` del Lema 9. **A medir.**
2. **Double dipping en la frontera.** Un atacante audita sus sectores bajo **todos** los candidatos
   (lotería independiente por flujo) y publica bajo el que gane; los honestos también pueden. La
   asimetría: el atacante retiene hasta saber quién gana; el k-cluster lo acota a ~k/λ (18 s a
   q = 1) frente a una convergencia p50 de 9 s. Factor de ramificación por época ≈ candidatos (~4),
   solo durante la ventana. Bajo BDK con `c = 50` bloques de la cadena del atacante entre
   ramificaciones, φ ≈ φ₅₀ **si** la ramificación extra de la ventana no cuenta como nivel; si
   cuenta, φ sube. **Es la primera pregunta para D9.**
3. **Ataque de balance entre flujos.** El atacante intenta mantener dos candidatos con peso
   parejo para que los honestos sigan divididos. Sus bloques bajo el flujo ligero solo pesan si ese
   flujo gana; para sostener la paridad necesita producir a ritmo ≥ la diferencia honesta, con α.
   Análisis clásico de balance, **sin hacer**. D9 y D8.
4. **Coste de verificación por flujo.** Un bloque bajo un flujo nuevo exige verificar el PoT desde
   `t(C)`: 100,2 ms por slot. Cota: flujos por época ≤ candidatos ≤ `λ·W` con billete real cada
   uno; el atacante aporta ≤ `α·λ·W`. A q = 1, α = 0,1, W = 30 s: ~3 flujos extra → ~0,3 núcleos
   continuos. Prefiltro de relé: no propagar bloques bajo flujos cuyo candidato no esté en el
   propio DAG. **D8: amplificación y nodo que sincroniza.**
5. **IOPS del granjero honesto** durante la ventana: auditar 4 flujos → 4× lecturas durante ~60 s
   de cada 300 → +~20 % medio; el granjero de 20 TiB de §21 se acerca al límite del SSD. Puede
   optar por auditar solo el flujo de su cadena seleccionada (pierde ~2 % de billetes).
6. **Lo heredado de D8 que sigue abierto**: cliente ligero (necesita pruebas de peso; ahora además
   debe saber el flujo canónico, que es el más pesado y se puede acreditar con las mismas pruebas);
   poda sin niveles de PoW; C-REORG-07 en tiempo y sin `exit` (aquí un «reorg» es un recoloreado,
   no una invalidación, así que la parada dura puede definirse sobre profundidad de recoloreado);
   retarget sobre azules del flujo canónico con el sesgo del Lema 9; C-EXP-04 con altura =
   posición en la cadena seleccionada, constantes en tiempo; `Dmax` y `k`.
7. **Cabeceras**: +32 B por el inyector declarado (556 → 588 B).

## 5 · Qué se modifica

- **PoT**: nada del VDF. La fuente del inyector pasa de «bloque 50j de la cadena» a «candidato
  autodeclarado, primero tras la frontera 50j según su propio pasado». El momento sigue siendo
  `slot + δ`. Se admite más de un flujo vivo por época.
- **DAG**: fusión libre (como GHOSTDAG); color por flujo (R-CAN-3); inyector declarado en
  cabecera; desempate por distancia; U3′.

## 6 · Lo que D9 tiene que intentar refutar

(1) φ con ramificación en la frontera acotada por el k-cluster; (2) ataque de balance entre
flujos: ¿converge el peso a un flujo con probabilidad exponencial en el tiempo, con qué
constante?; (3) la pérdida honesta del punto 4.1 dentro del Lema 9; (4) que R-CAN-2 esté bien
fundada (el inyector canónico se lee de la cadena seleccionada de past(B), cuyos bloques ya
tienen color definido en sus propios pasados: inducción sobre slots); (5) lookahead exacto con
retención del candidato propio hasta k/λ; (6) retarget.

## 7 · Lo que D8 tiene que intentar romper

(1) Spam de candidatos y flujos: coste por flujo al verificador, prefiltro de relé, nodo en
sincronización; (2) balance attack con α = 0,1-0,33; (3) retener el candidato propio para ganar
lookahead o para elegir época; (4) censura: producir bajo el flujo canónico pero no referenciar
bloques del otro flujo; (5) equivocación de candidato (mismo billete, dos cabeceras candidatas):
misma entropía y mismo `t`, luego mismo flujo, ¿queda algo?; (6) todo lo del punto 4.6.
