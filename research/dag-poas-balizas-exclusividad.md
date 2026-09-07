# Balizas raras + exclusividad de reloj por clave — quinta propuesta para un DAG sobre PoAS

**Fecha:** 2026-09-08 · **PROPUESTA SIN AUDITAR** del agente principal, a petición de Katana
(«crear, no buscar: nadie ha planteado este problema»). Rondas anteriores y sus refutaciones:
`dag-poas-auditoria.md`, `dag-poas-inyeccion-auditoria.md`, `dag-poas-candidatos-auditoria.md`,
`dag-poas-voto-auditoria.md`. Debe pasar por D9 y D8 (en Sonnet 5, según la política vigente).

## 0 · El replanteamiento

Las cuatro rondas asumieron que **la linealidad** de la cadena es lo que produce acuerdo sobre el
inyector. Es falso. Lo que produce acuerdo es la **rareza**: en la cadena lineal de ZEROX el bloque
`50j` es único el 94 % de las veces (D8, ronda 2) porque los bloques llegan cada `T = 120 s`, no
porque estén en fila. Un DAG a `λ = 1 b/s` pierde el acuerdo **por rápido**, no por DAG: en el
borde hay 4,32 candidatos de media (D8, ronda 3).

**La rareza se puede recrear dentro de un DAG rápido sin frenarlo.** Ese es el primer arreglo. El
segundo ataca lo que mató la ronda 3 (cobertura racional de flujos ⟹ deriva cero) con la única
palanca que ninguna ronda usó bien: **exclusividad por clave**, no por sector.

Los dos arreglos son **independientes** y se componen: el primero hace el desacuerdo raro, el
segundo lo hace inviable cuando ocurre.

## 1 · Arreglo (i) · Balizas: rareza dentro del DAG

**Definición.** Un bloque es **baliza** si `solution_distance ≤ rango_solucion / 2^j`. Es un
predicado sobre un campo que la cabecera ya lleva: coste cero, sin prueba extra, sin clase nueva de
objeto. Las balizas son bloques normales: llevan transacciones, pesan, cobran. Con `j = 8` y
`λ = 1 b/s`, la tasa de balizas es `λ/256 ≈ 1 cada 256 s`.

**Solo las balizas inyectan.** El inyector del intervalo `k` es **la baliza de menor slot** con
`slot ∈ [t_k, t_k + I_b)`. Determinista dado el conjunto: los slots van en la cabecera y no son
moldeables (establecido en rondas anteriores). Sin recuento, sin peso, sin cadena seleccionada.

**Por qué esto devuelve el acuerdo de una cadena lenta.** Un nodo en el instante `t` conoce todas
las balizas honestas con `slot ≤ t − D`. Dos balizas honestas en el mismo intervalo no crean
ambigüedad: el criterio es el **slot**, no el orden de llegada, así que ambos nodos coinciden en
cuál es la primera en cuanto las han visto las dos, y eso ocurre `D` después de la segunda. La
ambigüedad real solo la crea una **baliza retenida**, exactamente como en la cadena lineal.

**Elegibilidad.** Una baliza es elegible solo si está enterrada bajo `κ` bloques azules en
`past(b)` en el momento del corte. Una baliza honesta acumula `≈ λ·Λ` descendientes; una liberada
en el corte, cero. Esta regla **sigue siendo dependiente del cono** —y por tanto anclable— y ese
es justo el punto donde entra el arreglo (ii).

**Efecto sobre φ.** La palanca del atacante es la misma que en la lineal: cuando le toca la baliza
de menor slot del intervalo (probabilidad `α`), publica o retiene. Un bit. Y el número de niveles
del árbol privado entre inyecciones sube a `c_a = α·λ·I_b` (con `α = 1/3`, `I_b = 300 s`: ~100),
frente a `c = 50` de la lineal ⟹ **φ menor, umbral mejor** (D9 midió `φ₅₀ = 1,2815`, y φ es
decreciente en c). Es el primer diseño de las cinco que mejora φ en vez de empeorarlo.

**Lo que NO se paga:** el DAG sigue a `λ = 1 b/s` completo. Todos los bloques llevan transacciones,
pesan y cobran. No hay espina, no hay clase de segunda. La rareza es un predicado, no una
estructura.

## 2 · Arreglo (ii) · Exclusividad de reloj por clave

**El fallo que ataca.** D9, ronda 3: dos relojes son dos loterías independientes; publicar bajo
ambos es gratis y estrictamente dominante; ambos crecen a `λ`; la diferencia de peso es una
Skellam de deriva nula; **no converge**. Ninguna regla de desempate lo arregla porque el problema
no es el desempate, es que el peso honesto se reparte.

**Por qué la exclusividad por sector no muerde** (análisis del agente principal, ya aceptado): un
sector gana ~2·10⁻⁴ veces por época bajo cada reloj; `P(gana bajo los dos)` ≈ 4·10⁻⁸. La regla
casi nunca se aplica y la cobertura la hacen sectores distintos.

**La unidad correcta es la clave.** Regla:

> **X-1.** Una clave pública publica bajo **un solo reloj** por época.
> **X-2.** Prueba de infracción: dos cabeceras firmadas por la misma clave, misma época, `reloj_id`
> distinto, **con al menos una alternancia de vuelta** (A, luego B, luego A). Dos bloques A→B son
> un cambio legal; A→B→A es straddling.
> **X-3.** Verificación: dos o tres firmas y comparación de campos. **No hay que verificar ningún
> reloj**, ni PoT, ni solución. Es el punto que hace la regla barata y no-relativa.
> **X-4.** Castigo: se queman las recompensas de esa clave en esa época y la clave queda
> inhabilitada `P` épocas. Madurez de coinbase ≥ `P` épocas.

**Por qué esto sí restaura la deriva.** Bajo X-1 un granjero racional publica bajo un solo reloj.
¿Cuál? Con el arreglo (i) hay un **punto focal determinista**: la baliza de menor slot que ha
visto, que todos los honestos ven igual en `D`. Luego el peso honesto **no se reparte**: crece
íntegro `(1−α)λ` en el reloj focal, y el atacante sostiene el suyo a `αλ`. Deriva positiva,
carrera de Nakamoto, `α > 1/2`. **Es exactamente la condición que la cadena lineal tiene.**

**La objeción obvia, y su respuesta.** El slashing no detiene a un atacante que no busca beneficio.
Cierto, y no hace falta: lo que mató a la ronda 3 no fue el atacante, fueron **los granjeros
honestos racionales cubriendo ambos relojes**. X-1 los saca de esa estrategia. El atacante solo
sostiene su reloj con su propio `α`, y eso es la carrera de siempre.

**El ataque de anclaje de la ronda 4, revisado.** El atacante ancla un cono legal donde su baliza
gana. Antes, eso bastaba porque los honestos cubrían ambos relojes y la deriva era cero. Con X-1 no
puede reclutar a nadie: su rama crece a `αλ` contra `(1−α)λ`. El handicap deja de ser el obstáculo
y pasa a serlo la deriva. **Este es el cambio cualitativo de la propuesta.**

**El coste que sí tiene, dicho sin rodeos.** Un atacante que libera una baliza retenida justo en el
corte parte a los honestos por lo que cada uno vio, y con X-1 no pueden cubrirse: los del lado
minoritario pierden los bloques de esa época. La cláusula de una alternancia (X-2) limita el daño a
esos bloques, no a la clave. Es la lección de Spacemesh (identidades descalificadas en mainnet por
nodos duplicados sin malicia): **el castigo va al straddling, no al cambio**.

## 3 · Palanca complementaria · Madurez de sector (para el lookahead)

Independiente de (i) y (ii). Lo que hizo fatales los rezagos largos en las rondas 2 y 4 fue el
**ploteo dirigido**: espacio efectivo `= tasa_de_ploteo × lookahead` (D9: 5,7-12,5 GiB/GPU medidos,
98-217 extrapolados con lookahead de cientos de segundos).

**Idea.** Un sector no es utilizable hasta `M` de madurez. Si `M > lookahead`, cuando el atacante
plotea no puede saber si su sector ganará al madurar, y el ataque de plotear-y-descartar se vuelve
ciego: para descartar tiene que haber almacenado `M − W`, que es casi el coste honesto.

**El fallo, que declaro yo mismo.** `history_size` es una afirmación sobre *qué* historia
codificaste, no sobre *cuándo* ploteaste: se puede codificar historia vieja hoy y usar el sector de
inmediato. La regla `history_size + M ≤ altura` no fuerza tiempo transcurrido.

**El arreglo, más caro.** Un compromiso on-chain al **contenido** del conjunto de sectores (raíz de
Merkle por clave, publicada a la altura `h`, utilizable desde `h + M`). Plotear-y-descartar exigiría
comprometerse a los sectores fabricados `M` antes de conocer los desafíos. Es el ATX de Spacemesh
sin PoET, y su coste es una transacción por clave cada vez que cambia el conjunto de sectores.
Queda como **palanca opcional**, no como parte del núcleo: con el arreglo (i) el rezago necesario
baja mucho y puede que no haga falta.

## 4 · El diseño, junto

```
λ = 1 b/s (DAG completo, GHOSTDAG, todos los bloques con tx, peso y recompensa)
Baliza:      solution_distance ≤ SR / 2^j          (j ≈ 8 ⟹ 1 baliza / 256 s)
Inyector k:  baliza de menor slot en [t_k, t_k+I_b), enterrada bajo κ azules al corte
Corte:       t_k + I_b + Λ, con Λ ≫ D
Entropía:    blake3(chunk ‖ pot_output) del inyector          (Autonomys, no moldeable)
Aplicación:  t_k + I_b + Λ                                     (rezago compartido: ronda 4)
Exclusividad: X-1..X-4, por clave, con una alternancia permitida
Color/peso:  GHOSTDAG con U3', desempate por solution_distance, peso Σ 2^128/(SR+1),
             k en el punto fijo del retarget (D9, ronda 3: 24 a λ=1)
```

## 5 · Lo que hereda resuelto de las cuatro rondas

Validez absoluta y bien fundada por inducción sobre `past(B)` (ronda 3, D9). Herencia del ganador
para conservar «cadena seleccionada ⊆ azules» (ronda 4, D9). Rezago compartido = una sola lotería
mientras dura (ronda 4, verificado en `sp-consensus-subspace/src/lib.rs:118-126`). Coinbase de rojos
no aplicada; DAA y emisión solo sobre azules. Épocas en bloques para φ.

## 6 · Lo que NO resuelve y sigue abierto

Cliente ligero (§26) sin pruebas de peso. Poda sin niveles de PoW. C-REORG-07 en tiempo y sin
`exit`. C-EXP-04 con altura por cadena seleccionada. `Dmax` sin medir. Coste de verificación de
sub-DAGs de reloj minoritario (el DoS de D8, rondas 2 y 3). Y **P-039**, que va delante de todo esto.

## 7 · Lo que D9 tiene que intentar refutar

1. **La afirmación central**: con X-1 y punto focal determinista, ¿es la deriva `(1−2α)λ` y la
   condición `α > 1/2`? ¿O queda un equilibrio mixto en el que a algunos granjeros les compensa
   arriesgarse al reloj minoritario (por ejemplo si sospechan que ganará)?
2. `P(dos balizas honestas creen conjuntos distintos al corte)` con `j = 8`, `λ = 1`, `D = 4`, y el
   `Λ` necesario para `10⁻⁹` por intervalo. Comparar con los 372-847 slots de la ronda 4.
3. φ con inyector = baliza de menor slot y `c_a = αλI_b`: ¿mejora de verdad sobre `φ₅₀`?
4. La elegibilidad por `κ` sigue siendo dependiente del cono: ¿basta la deriva positiva de X-1 para
   que el anclaje no sea viable, o hace falta además profundidad?
5. Lookahead resultante y ploteo dirigido; si `M` (madurez) hace falta o no.

## 8 · Lo que D8 tiene que intentar romper

1. **Baliza retenida liberada en el corte** con X-1 activo: cuántos honestos quedan en el lado
   minoritario y cuánto pierden; ¿es un ataque de griefing rentable (coste `α`, daño `≫`)?
2. **Straddling encubierto**: publicar bajo dos relojes con **dos claves** (Sybil de claves). La
   exclusividad por clave no lo impide. ¿Cuánto cuesta partir el espacio entre dos claves y qué se
   pierde (¿nada?)? **Este es el ataque que más me preocupa y no lo tengo cerrado.**
3. Alternancia permitida: ¿se puede usar para cubrir ambos relojes de facto (A→B→A con las
   alternancias justo por debajo del umbral, o con varias épocas encadenadas)?
4. Grinding de la baliza: `j` grande hace las balizas raras; ¿puede el atacante concentrar espacio
   en obtener balizas (no: la distancia no es moldeable) o manipular `SR` para cambiar la tasa?
5. Todo lo del §6, más la interacción de X-4 (quema y madurez) con C-EMIT y el pool blindado.
