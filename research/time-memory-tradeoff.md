# Beyond Hellman's Time-Memory Trade-Offs — el paper que nunca se había abierto

**2026-09-05.** `PDF/time-memory-tre-off-proof-space.pdf` (Abusalah, Alwen, Cohen, Khilko, Pietrzak,
Reyzin), extraído con `pypdf` a texto plano, 23 páginas. Metadata del PDF: `CreationDate
D:20170907191025+02'00'` — **7 de septiembre de 2017**. Publicado en ASIACRYPT 2017
(Springer, DOI `10.1007/978-3-319-70697-9_13`, verificado por búsqueda web) y en IACR ePrint
2017/893. Encargo: comprobar si sostiene o socava `DECISIONES.md §17` (`B_RELLENO = 0`).

## Veredicto, primero y en grande

**No socava §17. Lo sostiene, con una base mucho más fuerte que la que §17 citó, y añade un
hallazgo que nadie había verificado: el primitivo que ZEROX va a usar de verdad —el
`ChiaV2Table` que `subspace-farmer-components` usa como *record encoder*, medido en
`research/coste-ploteo-medido.md`— es una instancia real de la construcción que este paper
analiza.** D9 citó el greenpaper de Chia (`PoSpace.init(N,pk)` no toma datos) para argumentar que
la seguridad está en el coste de reconstrucción, no en la entropía del dato. Este paper dice
exactamente eso, en 2017, con teorema y prueba, y **es la fuente primaria de la que Chia dice
explícitamente haber tomado su diseño** — cosa que el greenpaper (precursor de 2019, nunca
implementado) no era.

Dicho esto, el paper trae **tres matices que §17 no tenía y que hay que declarar** (desarrollados
abajo): (a) el teorema con prueba completa es para **dos tablas**, no para las siete de chiapos —
la generalización a *k* tablas se anuncia pero **no se demuestra** en este documento; (b) el modelo
cuenta **consultas al oráculo**, no tiempo de reloj ni paralelismo — un adversario con GPU no
rompe el teorema, pero sí abarata su traducción a coste real; (c) el ataque de *grinding* de
identificador de parcela que preocupa a CHIP-0048 está **fuera** del juego de seguridad que este
paper define, por una razón estructural, no por descuido.

---

## 1 · El teorema central, con su notación y su modelo

**Modelo.** Oráculo aleatorio doble: `f : [N] → [N]` una permutación verdaderamente aleatoria,
`g : [N] × [N] → [N]` una función verdaderamente aleatoria, ambas accesibles solo por consulta
(nadie, ni el prover ni el adversario, las evalúa "de memoria"). Se define

```
gf(x) = g(x, x')   donde   f(x) = f(x')          (página 14, §4)
```

(`x'` es el "compañero" de `x` bajo una involución sin puntos fijos; en la instancia concreta,
voltear todos los bits). La función `gf` **no se puede evaluar eficientemente hacia delante** —hay
que invertir `f` primero—, y esa es la propiedad que rompe el ataque clásico de Hellman.

**Teorema 2** (página 14, cita literal de la fórmula):

```
Fija ε > 0 y un algoritmo A con oráculo que hace a lo sumo
    T ≤ (N/4e)^(2/3)                                          (8)
consultas y usa una cadena de aviso aux de longitud S. Si para todo f,g
    Pr_{y←[N]} [ gf(A(y)) = y ] ≥ ε                            (9)
entonces
    T · S² ∈ Ω(ε² N²)                                          (10)
```

Comparar con la cota que Hellman/Fiat-Naor dan para invertir una función aleatoria **sin** esta
construcción: `S²·T ∈ Ω̃(N²)` ya es alcanzable por el atacante (página 7, ecuación 2) — es decir,
para una función aleatoria corriente, `S=T≈N^(2/3)` **basta** para invertir. La construcción `gf`
empuja esa misma forma de cota (`T·S²`) a ser una cota **inferior sobre el adversario**, no un
ataque que funcione. Es la diferencia entre "esto es lo mejor que se sabe atacar" y "esto es lo
peor que le puede pasar a cualquier atacante", y es exactamente el giro que hace el paper.

**Generalización a *k* niveles** (anidando: se sustituye la `f` interna por otra `gf`), enunciada en
la introducción pero **no demostrada en este documento**:

> *"In this paper we won't give a proof for the general construction, as the proof for the general
> construction doesn't require any new ideas, but just gets more technical."* — página 4-5, §1.1

La forma que se anuncia (Fig. 1, página 4, franja "purple"): con `k−1` niveles de anidamiento,

```
S^k · T ∈ Ω(N^k)     (asintóticamente S = T ≈ N^(k/(k+1)))
```

**Esto importa para Q4** (más abajo): chiapos usa **siete tablas**, no dos. La cota con prueba
completa en este paper es para `k=2` (la construcción base `gf`); la de `k=7` que protege el plot
real de Chia es una extrapolación **anunciada, no probada aquí**.

**El hueco declarado por los propios autores** (página 5, §1.1):

> *"A caveat of our lower bound is that it only applies if T ≤ N^(2/3). We don't see how to break
> our lower bound if T > N^(2/3)..."*

No es una grieta explotada — es un límite de la técnica de prueba, sin ataque conocido que la
rompa ahí. Y hay un ataque que sí complica el cuadro para la construcción base (`k=2`), citado por
los mismos autores como aceptable solo "para N extremadamente grande" (página 5, nota 12):

> *"Although for gf there exists a time-memory trade-off S⁴T ∈ O(N⁴)... achieved by 'nesting'
> Hellman's attack"*

O sea: el teorema garantiza `T·S² ∈ Ω(N²)` de mínimo; se conoce un ataque que llega a
`S⁴T ∈ O(N⁴)`. Entre esas dos curvas hay una zona sin resolver — el paper es honesto al respecto,
no la esconde.

## 2 · ¿Sostiene la afirmación de D9? Sí, literalmente, y con más autoridad que el greenpaper

La definición de seguridad de una prueba de espacio, tal cual la enuncia el paper (página 5, §1.2),
es exactamente el argumento de D9:

> *"The security requirement states that a cheating prover P̃ who only stores a file F′ of size
> significantly smaller than N either fails to make V accept, or **must invest a significant amount
> of computation**, ideally close to P's cost during initialization."*

No hay mención a que `F` deba ser incompresible como dato — la propiedad exigida es sobre el
**coste de reconstrucción**, no sobre la entropía del contenido. Y el motivo estructural es el
mismo que citó D9 para Chia: la función que hay que invertir se especifica con una semilla corta,
no con datos:

> *"f must have a short description... the prover would specify f by, for example, a short random
> salt s for a cryptographic hash function H, and set f(x) = H(s,x)"* — página 2, nota 5.

Es el mismo mecanismo que `plot_seed` en chiapos y que `PoSpace.init(N, pk)` en el greenpaper de
Chia: **el contenido de la tabla no es un secreto que haya que ocultar por su entropía — es la
salida determinista de una semilla corta, y lo único caro es construir la tabla entera una vez.**

**Matiz que el paper añade y que D9 no tenía:** la palabra "incompresible" sí aparece en el paper
(página 9, §1.7, formalizado como `Fact 1` en página 11), pero en un sentido distinto y hay que no confundirlo. Es un **recurso de la
prueba**: se asume que una permutación verdaderamente aleatoria no se puede describir en menos de
`log(N!)` bits, y esa incompresibilidad *de la descripción combinatoria de f* es lo que permite el
argumento de compresión-y-contradicción del teorema. **No es una afirmación sobre el dato
farmeado.** El dato farmeado (la tabla de valores) es siempre reconstruible a partir de una semilla
corta — eso es justo lo que D9 dijo. La incompresibilidad que sí exige el paper es sobre la
*función* (para que el argumento de conteo funcione), no sobre el archivo que el prover almacena.
Distinguir esto evita releer el paper y pensar que contradice a D9: no lo hace, habla de dos cosas
distintas con la misma palabra.

**Conclusión de esta sección:** el paper **sostiene** a D9, con más fuerza —es un teorema con
prueba, no una observación de diseño— y corrige la fuente: D9 debería citar este paper como
respaldo formal antes que el greenpaper de Chia para este argumento concreto.

## 3 · Guardar una fracción y recomputar el resto — la cota exacta que pide §17

Esta es la pregunta que más directamente ataca el fundamento de `B_RELLENO = 0`, y el teorema **es
literalmente esa cota**: `S` es el espacio que el adversario guarda, `T` es cuánto tiene que
computar por desafío para seguir acertando en una fracción `ε` de los casos. No hace falta
extrapolar — el juego ya está planteado como "guardo `S`, pago `T`, acierto `ε`".

**La estrategia trivial de referencia.** Guardar una fracción `φ` de la tabla completa (que ocupa
`N log N` bits, Observación 2 / *Remark 2*, página 7) y responder por consulta directa, sin
recomputar nada: `S_trivial ≈ φ·N·logN`, `T ≈ 1`, `ε = φ`. Es exactamente el modelo con el que D8
trabajó para `derive_piece_index` (guardar una fracción `f` del sector, acertar con probabilidad
`f` por desafío).

**Lo que dice el teorema sobre intentar guardar menos que eso.** Si el adversario reduce el
almacenamiento a `S = S_trivial / r` (guarda `r` veces menos que la estrategia trivial) y quiere
mantener la misma tasa de éxito `ε`, el teorema exige

```
T ≥ c · ε²N² / S² = c · r² / log²N          (despejando de T·S² ∈ Ω(ε²N²))
```

**El coste de comprimir crece con el cuadrado de la razón de compresión**, para la construcción
base de dos tablas. Con `k` niveles de anidamiento (si se acepta la generalización no probada de
§1), la potencia sube a `r^k`: cuantas más tablas, más caro se vuelve cada bit que no se guarda.
Es la razón formal, y no solo intuitiva, de por qué chiapos usa siete tablas y no dos —cada tabla
extra endurece exactamente este exponente— y de por qué D9 tiene razón en que "guardar una
fracción y recomputar" no es gratis: el coste no crece linealmente con lo que te ahorras, crece
polinómicamente (cuadrático como mínimo, potencialmente peor).

**Esto no es lo mismo que el modelo `f^1000` de D8.** El `f^1000` de `derive_piece_index`
(`DECISIONES.md §14/§17`, `PREGUNTAS-PARA-KATANA.md`) modela la probabilidad de tener **todas** las
piezas necesarias para 1000 desafíos independientes dado que se guarda una fracción `f` del
sector — es un argumento de muestreo (binomial), no de inversión de función. El teorema de este
paper modela algo distinto y complementario: cuánto cuesta **fabricar** las piezas que no se
guardaron. Ambos apuntan en la misma dirección (guardar menos sale caro, de una forma u otra), pero
son dos mecanismos distintos y no hay que fusionarlos como si fueran el mismo cálculo. **Esto es
extrapolación mía, no está en el paper.**

## 4 · ¿Es este el diseño que Chia implementó? Sí — y aquí no hay precursor abandonado

A diferencia de `PDF/ChiaGreenPaper.pdf` (el precursor de 2019 nunca implementado, documentado en
`research/proof-of-space-tiempo.md`), **este paper es la fuente primaria que Chia dice
explícitamente haber usado**, verificado en la documentación oficial de construcción de pruebas de
espacio (`chia.net/wp-content/uploads/2023/01/proof_of_space.pdf`, descargado y extraído con
`pypdf` el 2026-09-05):

> *"This document describes a practical construction of Proofs of Space, based on **Beyond
> Hellman's Time-Memory Trade-Offs with Applications to Proofs of Space [1]**. We use the
> techniques laid out in that paper, **extend it from 2 to 7 tables**, and tweak it to make it
> efficient and secure, for use in the Chia Blockchain."* — página 1
>
> *"[1] Hamza Abusalah, Joel Alwen, Bram Cohen, Danylo Khilko, Krzysztof Pietrzak, Leonid Reyzin:
> Beyond Hellman's Time-Memory Trade-Offs with Applications to Proofs of Space (2017)"* — referencias,
> página 22 del documento de Chia

Y confirma exactamente el mecanismo de la construcción base descrito arriba, con la misma notación
(`f`, `g`, `M` de "matching"), extendida a `m = 7`. El código que consume esto en `chia-blockchain`
v2.7.4 es `from chiapos import Verifier` (`chia/types/blockchain_format/proof_of_space.py:9`) — la
construcción de tablas vive en el repositorio C++ `chiapos`, **no clonado en `PDF/`**, así que no
pude leer el código fuente de las siete tablas directamente; esto se apoya en el documento oficial
de diseño de Chia, no en el código.

**Confirmado: es PoS v1, el que corre en mainnet.** `HARD_FORK2_HEIGHT = 0xFFFFFFFA`
(`research/chia-parcelas-comprimidas.md`) significa que PoS 2.0 no está activo — el algoritmo de
siete tablas de este paper **es el que produce cada prueba de espacio válida en Chia hoy**, no un
diseño de reemplazo. Aquí no se repite el error de `ChiaGreenPaper.pdf`.

**El hallazgo que no estaba pedido y que conecta todo con ZEROX.** `research/coste-ploteo-medido.md`
(zx-autonomys, 2026-09-05) midió el coste de ploteo de Autonomys con
`cargo bench -p subspace-farmer-components --bench plotting`, y el banco usa
**`CpuRecordsEncoder` y `ChiaV2Table`** (`subspace @ f8842d0`). Es decir: **el "record encoder" que
convierte una pieza archivada en algo farmeable, el mismo cuyo coste de 83,6 s/sector sostiene toda
la razón de 9 millones de `§17`, es una reimplementación en Rust del algoritmo de tablas de
chiapos** — el algoritmo que este paper fundamenta. No lo verifiqué yo directamente contra el
código fuente de `subspace` (no está clonado en este entorno; es dominio de `zx-autonomys`), así
que lo doy como **hallazgo por cruce de fuentes locales, con una laguna declarada**: no confirmé
cuántas tablas usa `ChiaV2Table` (si son 7 como Chia o un número distinto elegido por Subspace). Es
la pregunta que cierra el círculo, y queda para `zx-autonomys`.

Esto cambia el estatus de este paper para ZEROX: **no es una curiosidad sobre un mecanismo que
descartamos (chiapos), es la base teórica del componente que sí vamos a ejecutar.**

## 5 · Parcelas comprimidas y *grinding*: dentro del modelo unas, fuera del modelo otra

`research/chia-parcelas-comprimidas.md` ya distinguió dos ataques con nombres distintos. Con el
paper delante, se puede decir **cuál está dentro del juego de seguridad que demuestra el teorema y
cuál no**:

| Ataque | ¿Dentro del modelo del paper? | Por qué |
|---|---|---|
| **Compresión oficial C0–C9** (~25,8 %): no guardar la Tabla 1, tirar bits de los *line points* | **Dentro.** Es el mismo juego S/T del Teorema 2 | El documento de diseño de Chia lo describe con el vocabulario exacto del paper: *"By increasing this number to [3], the storage required to Hellman attack f₁... is much larger... ensuring that performing time space tradeoffs is much more expensive than honest storage"* (`proof_of_space.pdf`, sección *Hellman Attacks*, verificado). Es Chia **calibrando a propósito** el punto de la curva `S^k·T` que tolera |
| ***Grinding* con GPU tipo DrPlotter** (~50 %, GPU al 99 % durante el farming) | **Dentro, con un supuesto del modelo que se rompe.** | El Teorema 2 cuenta **consultas al oráculo** `T`, no tiempo de reloj. AES (la primitiva concreta que el propio paper propone, nota 9, página 3) es masivamente paralelizable en GPU. El mismo `T` que Chia calibró para que fuera caro en CPU se vuelve barato en tiempo real con hardware paralelo — el teorema sigue siendo cierto en número de consultas, pero **su traducción a "esto cuesta caro de verdad" asumía un precio por consulta que la GPU rompe**. Esto es **extrapolación mía**, no está enunciado en el paper: el paper nunca dice nada sobre paralelismo, ni lo prohíbe ni lo acota |
| ***Plot ID grinding*** (CHIP-0048: *"up to 3.5× leverage"*, probar muchos identificadores de parcela baratos antes de comprometerse a plotear ninguno) | **Fuera del modelo.** | El Teorema 2 fija **una sola** instancia de `(f,g)` (una sola semilla, un solo plot) y mide el coste de invertir *esa* instancia. No dice nada sobre un adversario que evalúa barato **muchas instancias distintas** (muchos `plot_seed` candidatos) y descarta casi todas antes de comprometerse a construir la tabla de ninguna. Es un grado de libertad —elegir entre muchas semillas gratis— que el juego de seguridad del paper simplemente no le da al adversario ni se lo quita: **no está definido en el juego**, ni a favor ni en contra |

**Por qué esto no es un matiz menor.** El propio greenpaper de Chia (idealización §1.6, citada en
`CLAUDE.md`) supone que las pruebas de espacio no admiten ningún compromiso tiempo-memoria. Este
paper demuestra que sí lo admiten, pero **acotado** (fila 1 y 2 de la tabla). El *plot ID grinding*
(fila 3) es un tercer fenómeno que ni el greenpaper idealiza ni este paper modela — necesitaría su
propia definición de seguridad ("resistencia a *grinding* de instancias"), y **no la encontré en
ningún documento local**. Es una laguna real, no solo mía: es un hueco en la literatura que ambos
documentos comparten.

## Lo que NO se transfiere de este paper a ZEROX tal cual

- **La construcción de siete tablas en sí.** ZEROX no usa chiapos (`DECISIONES.md §14`); usa
  Autonomys. La relevancia de este paper para ZEROX pasa por `ChiaV2Table` dentro de Subspace, no
  por adoptar el formato de parcela de Chia.
- **El parámetro de anidamiento `k=7`.** Es una elección de ingeniería de Chia (proof size crece
  exponencialmente con `k`, verificación también — `proof_of_space.pdf`, sección *7 Tables*), no
  una constante que el paper derive. Si `ChiaV2Table` usa un `k` distinto, la curva `S^k·T` cambia,
  y **eso no se ha comprobado**.
- **La cota `T ≤ (N/4e)^(2/3)`.** Es un límite de la técnica de prueba de *este* paper concreto, no
  una propiedad universal de todas las construcciones basadas en `gf`. No se debe citar como si
  fuera una propiedad de seguridad garantizada más allá de ese rango.

## Al final, siempre

```
YA EN RUST:   `ChiaV2Table` y `CpuRecordsEncoder` en `subspace-farmer-components` (medido en
              coste-ploteo-medido.md) son ya la instancia Rust de esta construcción que ZEROX
              ejecutaría vía Autonomys. No hay nada de este paper que ZEROX deba reimplementar
              desde cero: si se adopta Autonomys, se hereda esto.

LASTRE:       El parámetro k=7 y el resto de heurísticas de "7 Tables" (colación de inputs,
              ataque de ciclos, alineación de parques) son ingeniería específica de chiapos para
              optimizar tamaño de prueba y velocidad de disco de Chia. Si ChiaV2Table las heredó
              tal cual, son decisiones de Chia, no de ZEROX, y no está verificado que apliquen
              igual de bien a sectores de Autonomys (dominio de zx-autonomys, no de este informe).

CHOCA CON:    Nada de `DECISIONES.md`. Refuerza §17 en vez de chocar con ella. El único punto de
              fricción es de encuadre, no de decisión: §17 citó el greenpaper de Chia para el
              argumento "PoSpace.init no toma datos"; la fuente más fuerte y más antigua para ese
              argumento era este paper, que además resulta ser la base real de lo que ZEROX
              ejecuta por debajo (ChiaV2Table), y eso no se sabía cuando se escribió §17.

LAGUNAS:      (1) Cuántas tablas / qué nivel de anidamiento k usa ChiaV2Table en subspace —no
              clonado en este entorno, dominio de zx-autonomys. (2) La generalización S^k·T ∈
              Ω(N^k) para k>2 no está demostrada en este documento, solo anunciada (páginas 4-5);
              no encontré la prueba completa en ningún otro sitio local. (3) Ningún documento
              local define un juego de seguridad formal para el "plot ID grinding" (elegir entre
              muchas instancias baratas antes de comprometerse) — es un hueco de la literatura,
              no solo mío. (4) No verifiqué si `chiapos` (el repo C++ real, no clonado) implementa
              la construcción exactamente como la describe proof_of_space.pdf o con más
              heurísticas no documentadas ahí.
```
