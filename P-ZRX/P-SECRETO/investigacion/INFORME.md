# INFORME — P-SECRETO · ¿Puede exigirse algo que no se pueda cumplir en secreto?

**Primera línea (F1 + F4):** **F1: SÍ, el obstáculo es un teorema.** Ninguna condición de
validez evaluable sobre `past(B)` obliga a un productor a publicar: hasta la atestiguación
por terceros es satisfacible en rama privada si los firmantes firman lo que se les pide
(régimen V1), y la única variante que rompe el secreto (V2, firmar solo lo visto) es
política del firmante —no verificable como condición de validez—. **F4: y la vía está
muerta por viveza antes de llegar ahí.** La ronda de recogida de k firmas **no cabe en el
slot con la Δ medida**: con h ≈ 3 saltos de overlay por tramo, P(cabe) = 0,219 con k = 4 y
Δ = 0,26 s, y 10⁻⁴ con Δ = 0,60 s; aunque cupiera, la abstención la mata gratis: un
atacante con fracción α de espacio corta la producción honesta a (1−α)^k sin dejar
evidencia, y una partición para los dos lados el 94 % de los slots con k = 4.

**Categoría del instrumento:** `consenso`. **Instrumento:**
`P-ZRX/P-SECRETO/investigacion/veritas/consenso/secreto-atestiguacion-v1/` (ficha,
método y reproducción en su `INFORME.md`; hipótesis en
`HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md`; semilla `0x5EC5E70`, Julia 1.13.0, CPU, 4
hilos, minutos, 80 controles con límites activos). **Presupuesto no agotado.**

**Verificación independiente.** Dos especialistas (matemáticas y Julia) atacaron este
trabajo el 2026-09-23; sus hallazgos se incorporaron (tabla de correcciones en la ficha
del instrumento). Los tres hallazgos que cambiaron veredictos: el paro en partición exige
sortear también al productor; la captura de la cadena exige además ganar el reto de cada
slot; la latencia hay que contarla en saltos de overlay, no en un enlace.

---

## F1 · El obstáculo es un teorema — con un matiz que decide

### 1.1 · Formalización

- **Condición de validez**: un predicado φ computable sobre `(B, past(B))`, añadido a los
  requisitos de validez. La línea roja §4.5 se respeta por definición: validez absoluta,
  función de `past(B)` y de nada más (C-FLU-13), sin vista del nodo.
- **Adversario**: fracción α de espacio propia, β reclutable, κ = 0 (solo publica la rama
  ganadora). Construye su DAG privado P desde la bifurcación.
- **Definición**: φ es **falsificable en rama privada** si el atacante puede extender P con
  bloques que cumplen φ usando solo artefactos que él produce (su clave, sus bloques, su
  historial, referencias a lo público). φ es **infalsificable** si exige cooperación
  honesta (firmas bajo claves ajenas).

**Teorema 1 (falsificabilidad), `demostrado`.** Toda φ cuyos requisitos se satisfacen con
artefactos que el atacante produce es satisfacible en P. Prueba por construcción: el
contenido del bloque es libre (compromisos, referencias, conjuntos de padres); las
condiciones de historial se fabrican produciendo bloques a su ritmo; las referencias a
datos públicos se incluyen citando bloques públicos válidos del mismo flujo — **ver lo
público no obliga a publicar**; nada en las entradas del verificador existe fuera de
`(B, past(B))`, y en P todo `past(B)` es del atacante salvo lo que él decida fusionar.

**Teorema 2 (el único artefacto insalvable), `demostrado`.** El único requisito que el
atacante no puede producir es una firma válida bajo una clave honesta (EUF-CMA de
Ed25519, C-HDR-04). La atestiguación por sorteo es la única familia de condiciones que lo
exige. Los **controles de §4.1** se ejecutan en el instrumento (`resultados/F1-control.tsv`):

| Condición | ¿Se satisface con solo entradas del atacante? | Clasificación |
|---|---|---|
| Compromiso previo de intención | sí | falsificable |
| Historial reciente de clave | sí | falsificable |
| Referencia a datos públicos | sí | falsificable |
| Atestiguación sin firmas honestas | **no** | exige cooperación ajena |

### 1.2 · El matiz que decide: V1/V2 (hallazgo de la verificación independiente)

Una firma sobre un hash **no prueba que el firmante vio el bloque**. Por tanto la
condición «B lleva k firmas de los sorteados» tiene dos regímenes:

- **V1 (firma a ciegas)**: el firmante firma el `pre_hash` que le presentan sin ver el
  bloque. El atacante obtiene firmas honestas legítimas para su rama privada: **la
  condición es satisfacible en rama privada y no rompe el secreto** (`derivado`). El
  verificador no puede distinguir una firma V1 de una V2: la condición por sí sola no
  obliga a publicar.
- **V2 (firma solo lo visto)**: el firmante firma solo bloques que ha visto enteros y
  validado. Satisfacer la condición exige revelar el bloque a cada firma honesta: la rama
  sale de la custodia del atacante. **V2 es política del firmante, no condición de
  validez**: no hay prueba verificable de que el firmante vio algo (`derivado`).

**Consecuencia, y es la respuesta a F1.** El obstáculo de §1 es un teorema, y la
atestiguación **no lo contradice**: como condición de validez es falsificable (V1); como
mecanismo que rompe el secreto depende de una conducta (V2) no verificable, sobornable y
cara en viveza (F4). Dicho de otro modo: **ninguna condición de validez puede obligar a
publicar**; lo máximo que puede conseguirse es hacer la rama privada *rehén del silencio
de terceros*, y el precio de ese rehén se paga en producción honesta.

### 1.3 · La forma candidata de §1, afinada

«Una condición es infalsificable solo si depende de información que el atacante no puede
producir por sí mismo», con fuentes (a) otros participantes, (b) cadena externa, (c)
tiempo físico. **Se sostiene, con una precisión**: la (a) no produce condiciones
*infalsificables* —produce condiciones cuya satisfacción exige cooperación ajena—, y la
cooperación ajena no fuerza la publicación (V1). La tricotomía es exhaustiva por
construcción del verificador (sus únicas entradas son `(B, past(B))` y los artefactos del
bloque; lo demás es física o terceros), pero se declara como **propuesta demostrada en sus
dos direcciones centrales, no como teorema de exhaustividad sobre todas las φ
imaginables**: la enumeración de controles es finita (`declarado`, sin privilegio de
premisa).

## F2 · Las tres fuentes: cuáles quedan vivas

| Fuente | Estado | Por qué |
|---|---|---|
| (c) tiempo físico | **Cerrada** (entrada congelada) | `P-ZRX/P-RIVAL/investigacion/INFORME.md` F1/H5: dos núcleos corren dos líneas de VDF y se farmean dos ramas; el tiempo no es rival. |
| (b) cadena externa | **Viva como regla, muerta como condición** | Como *condición de validez*, referenciar datos externos es satisfacible en privado: el atacante ve la misma cadena externa y sus bloques la citan; ver lo público no obliga a publicar. La única condición externa que ligaría sería «B es el bloque que la externa comprometió» — y eso es decidir la canónica (regla de decisión, no de validez), prohibida por la línea roja (`P-ZRX/T-ZRX/AGUJEROS-Y-SOLUCIONES.md` D4: ancla externa = «ayuda al operador, nunca regla de consenso»), además de circular como validez (dependería de compromisos futuros) (`derivado`). |
| (a) otros participantes | **Única candidata** | La atestiguación por sorteo. Rompe el secreto solo bajo V2, y muere por viveza (F4). |

## F3 · La candidata con números: atestiguación por sorteo

**Modelo de muestreo declarado** (S1/S2 en `HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md`):
k plazas por slot, **con reemplazo**, ponderadas por espacio, sorteadas de `salida(f, s)`
(C-POT-02) — función de `past(B)`, del lado correcto de §4.5. Con reemplazo es la cota
alcanzable por el atacante: el teorema de identidad
(`research/dag-poas-balizas-auditoria.md` §2) le permite partir su espacio en claves
gratis y la variante sin reemplazo tiende a α^k desde abajo (`demostrado`, `medido`).

**Captura de un bloque** (`resultados/F3-captura.tsv`, exacto):

| k | α = 0,10 | α = 0,25 | α = 0,33 | α = 0,49 |
|---:|---:|---:|---:|---:|
| 1 | 0,1000 | 0,2500 | 0,3333 | 0,4900 |
| 4 | 1,0·10⁻⁴ | 3,9·10⁻³ | 1,2·10⁻² | 5,8·10⁻² |
| 8 | 1,0·10⁻⁸ | 1,5·10⁻⁵ | 1,5·10⁻⁴ | 3,3·10⁻³ |
| 16 | 1,0·10⁻¹⁶ | 2,3·10⁻¹⁰ | 2,3·10⁻⁸ | 1,1·10⁻⁵ |
| 32 | 1,0·10⁻³² | 5,4·10⁻²⁰ | 5,4·10⁻¹⁶ | 1,2·10⁻¹⁰ |

**La interacción con `F_slots` es lo que decide, y va a favor de la defensa.** El atacante
no necesita un bloque: necesita la cadena entera de d bloques dentro de la ventana
`C-FIN-01` (d < F_slots), y cada bloque exige **ganar el reto** de su slot (factor α^d,
S4 declarado) **y** capturar su sorteo (α^k). Total: α^((k+1)·d)
(`resultados/F3-cadena.tsv`, exacto, α = 1/3):

| k | d = 10 | d = 100 | d = 7200 (F = 2 h) |
|---:|---:|---:|---:|
| 1 | 10⁻⁹·⁵ | 10⁻⁹⁵·⁴ | **10⁻⁶⁸⁷⁰** |
| 4 | 10⁻²³·⁹ | 10⁻²³⁸·⁶ | 10⁻¹⁷¹⁷⁶ |

**Con k = 1 la captura de la cadena ya es imposible a cualquier tolerancia razonable.**
El k necesario para defender la cadena NO es el problema: el problema es que la cadena
**honesta** tiene que cumplir la misma condición en cada slot (F4).

**Efecto sobre α\*: no mueve la identidad; cierra el canal.** La superficie
`α* = (1−β_d−2β_x)/2` es una identidad de tasas (`P-ZRX/P-PRESTAMO/investigacion/INFORME.md`
F1, `demostrado`; reproducida con `g(α*) = 0` exacto en `resultados/F4-alfa.tsv`) y **no
cambia**. Lo que cambia es la *usabilidad secreta* de β: cada bloque de la rama privada
debe llevar firmas de claves honestas. Bajo V2, la probabilidad de que la cadena de d
bloques no filtre nada es (α + (1−α)·p_sil)^(k·d) (`resultados/F4-soborno.tsv`, exacto;
p_sil = prob. de que un firmante honesto calle):

| p_sil | k = 1, d = 100 | k = 4, d = 7200 |
|---:|---:|---:|
| 0,5 | 10⁻¹⁷·⁷ | 10⁻⁵¹⁰² |
| 0,01 | 10⁻⁴⁰·¹ | 10⁻¹³⁶¹⁵ |

**Aun con la mitad de los firmantes dispuestos a callar, la fuga es cierta.** Bajo V2 la
rama privada deja de existir como tal: cada bloque pasa por (1−α)k nodos honestos, y
basta uno que filtre — honesto o arrepentido— para que el bloque sea público y el doble
farmeado deje la evidencia que P-EQUIVOCACION/P-CLAVE necesitan (κ → 1). El coste de
evitar la fuga es sobornar a **todos** los (1−α)kd firmantes honestos: coste lineal en
k·d, independiente de α — un encarecimiento, no una barrera, y con el silencio como
mercancía no verificable (`derivado`). Y bajo V1 no hay fuga ni efecto: el mecanismo es
inerte.

**Coste en cabecera y red** (`resultados/F3-coste.tsv`, λ = 1 bloque/s, Q2 ≈ 1 kB):

| k | Ed25519 (firma por plaza) | fracción de Q2 | GB/año | BLS agregada | GB/año |
|---:|---:|---:|---:|---:|---:|
| 4 | 384 B | 0,375 | 12,1 | 97 B | 3,06 |
| 8 | 768 B | **0,75** | 24,2 | 97 B | 3,06 |
| 16 | 1 536 B | **1,5 (rompe Q2)** | 48,4 | 98 B | 3,09 |

Ed25519 con k ≥ 16 duplica el presupuesto Q2 y con k = 8 dobla el ancho de banda de
cabeceras (24,2 frente a 21,5 GB/año hoy). BLS agregada cabe holgada — pero BLS es
exactamente la dependencia pesada (blst en la ruta de consenso) que la capa de comité
descartada dejó como bifurcación de Katana (`research/dag-poas-capa-finalidad.md` §5). El
coste real de la candidata no es la cabecera: es la viveza.

## F4 · La viveza — y es donde muere

**La primera línea ya lo dijo: no cabe.** Los números, con la lognormal por enlace de
DMS-v0.1 (mediana 80 ms, p99 500 ms) y τ = 1 s, Δ ∈ {0,26…0,60} s
(`resultados/F4-latencia.tsv`; convolución ↔ Monte Carlo con IC 99 %; h = saltos de
overlay por tramo, ida y vuelta):

| k | Δ = 0,26, h = 1 | Δ = 0,26, h = 2 | Δ = 0,26, h = 3 | Δ = 0,60, h = 3 |
|---:|---:|---:|---:|---:|
| 1 | 0,989 | 0,915 | 0,677 | 0,091 |
| 4 | 0,956 | 0,705 | **0,219** | **0,0001** |
| 8 | 0,914 | 0,498 | **0,048** | ~0 |
| 16 | 0,835 | 0,248 | 0,002 | ~0 |

Con la distancia media productor↔firmante en el overlay (h ≈ 2–3, derivado de la
propagación hop-by-hop de DMS-v0.1: ~5,6 saltos extremo a extremo, C-NET-26), un k que
sirva de algo (≥ 4) **pierde entre el 78 % y el 100 % de los slots**. El caso h = 1
(conexión directa) es la cota optimista y ya pierde el 36 % de los slots con k = 4 y
Δ = 0,60. La ronda no cabe, y no es cuestión de optimización: es 2·h·l en el camino
crítico de producción, sobre un presupuesto W = τ − Δ que ya consume la propagación.

**Disponibilidad**: con p < 1 (granjero doméstico apagado — la `p` sin medir que mató la
capa de comité, `research/dag-poas-capa-finalidad.md` §4.C), la producción honesta es
((1−α)p)^k (`resultados/F4-viveza.tsv`): p = 0,9, k = 4, α = 0,10 → **0,43** (57 % de
bloques muertos sin atacante alguno). Allí la capa de comité era **aditiva** (si se para,
F = 2 h como suelo: disponibilidad antes que consistencia, FIP-0086); aquí la condición
es de **validez**: si falla, no hay bloque. El modo de fallo es el opuesto y es letal.

**Abstención (el κ = 0 de los firmantes)**: el atacante **nunca firma bloques honestos**.
Producción: (1−α)^k. α = 0,10, k = 8 → 0,43; α = 0,33, k = 8 → **0,04**. Coste para el
atacante: **cero**. Evidencia: **ninguna** — el silencio no deja prueba, por la misma
razón que κ = 0 mató a los castigos (`P-ZRX/P-CLAVE/investigacion/INFORME.md` F6). La
atestiguación no elimina el problema del secreto: lo reencarna en los firmantes.

**Partición**: el sorteo también elige al productor (el reto, S4). P(ambos lados paran) =
1 − x^(k+1) − (1−x)^(k+1) (`resultados/F4-particion.tsv`): corte 50/50: k = 1 → 0,50;
k = 4 → **0,9375**; k = 8 → 0,996. Contraste con el diseño vigente: una partición más
larga que L es permanente (fallo de seguridad, `P-ZRX/P-2.1/SINTESIS.md` §2) pero **cada
lado sigue produciendo** (C-FLU-13/14); C-FLU-22 cura el nacimiento espontáneo. Con
atestiguación, **cualquier** corte para la producción en ambos lados casi siempre.

**Censura, cuantificada**: para parar la cadena honesta sin espacio, el atacante DoS-ea
los k sorteados del slot (los conoce en el slot s; con ventaja de reloj ρ > 1, antes).
Coste ≈ k × enlace del nodo × ciclo: k = 8 a 100 Mbit/s ≈ **800 Mbit/s sostenidos** —
trivial frente a los 28 discos de 20 TB por PiB del ataque honesto
(`P-ZRX/T-ZRX/AGUJEROS-Y-SOLUCIONES.md` D1), con rotación de prefijos contra C-NET-20.
La censura cuesta **órdenes de magnitud menos que el espacio que hoy haría falta**.

**La variante de dos fases no salva nada, y hay que decirlo explícito.** Si las firmas
llegan como descendientes (activación de peso tras publicar), la latencia desaparece —
pero la validez/peso de B pasa a depender del **futuro** de B: cae del lado equivocado de
§4.5 (C-FLU-13 exige función de `past(B)`), reabre la dependencia de la vista y con ella
la puerta del multistream que Katana descartó (`SPEC.md` C-FLU-13, nota). No existe
reformulación «función de past(B)» que ate la firma al bloque visto: la única firma
derivable del pasado es sobre la salida pública del PoT, y no ata a la rama
(`derivado`). **Ambas encarnaciones mueren, por líneas rojas distintas.**

## F5 · ¿Se sostiene la distinción entre atestiguar y decidir?

**Técnicamente, sí, en sentido estricto.** Un atestiguador no elige cadena (lo hace
C-GD-03), no vota la canónica, no finaliza (lo hace C-FIN-01), no tiene veto sobre el
orden: el sorteo es determinista y la firma ata un bloque, no una preferencia. No es un
«comité de decisión» en el sentido que AGENTS.md prohíbe (`demostrado` por lectura de
reglas; la calificación política es de Katana).

**Pero la distinción no esconde lo que cuesta, y hay tres cargas reales** (`derivado`,
con fuentes):

1. **Veto por silencio.** El conjunto sorteado puede matar **cualquier** bloque
   absteniéndose: poder de bloqueo efectivo sobre la disponibilidad, ejercible gratis y
   sin evidencia. No decide *qué* cadena; decide *si hay* cadena. Es el problema `p` de la
   capa de comité, ahora con consecuencias de validez.
2. **Hereda toda la maquinaria descartada.** El sorteo ponderado por espacio exige la
   tabla de poder derivada (R-FIN-15: contar bloques pagados por clave, W_VIVO) —
   `research/dag-poas-capa-finalidad.md` §3 — porque PoST no registra a nadie. Y esa
   tabla es manipulable: el atacante elige qué bloques publica para moldearla (el D8 de
   aquella propuesta, §4.D, sin cerrar), más el sesgo de clave por reploteo
   (`P-ZRX/P-PUENTE-ESPACIO-TASA/.../INFORME.md` §3, H-5). La atestiguación cae en lo
   mismo que la capa descartada: misma infraestructura, mismos agujeros sin cerrar.
3. **Modo de fallo invertido.** La capa de comité era aditiva y a prueba de fallos
   (se para → F = 2 h). La atestiguación es condición de validez por bloque: falla →
   cadena muerta. Precisamente *porque* no decide, debe cumplirse en cada bloque, para
   siempre, en el camino crítico.

## F6 · Veredicto: qué se puede cerrar de κ = 0, a qué precio

1. **El obstáculo es un teorema (F1).** No existe una condición de validez sobre
   `past(B)` que un productor no pueda satisfacer sin publicar. La pregunta central del
   encargo se responde **no**, con demostración.
2. **La atestiguación no es un contraejemplo al teorema** (V1), y como mecanismo (V2) es
   conducta no verificable. Su efecto real, si se adoptara con firmantes V2: la rama
   privada deja de ser privada — el ataque se vuelve **observable** (κ → 1) o se compra
   con el silencio de (1−α)kd firmantes por cadena. Eso es lo único que se puede cerrar
   de κ = 0: **no impedirlo, hacerlo rehén** de terceros.
3. **El precio del rehén es la viveza (F4), y no hay k que lo arregle**: k = 1 ya
   defiende la captura de cadena (α^((k+1)d)) pero ya paga la abstención (1−α); k ≥ 4 no
   cabe en el slot con la Δ medida; cualquier k hereda la tabla de poder manipulable y el
   modo de fallo letal. **No se presenta como encarecimiento ni con palabras de
   cobertura: la vía está muerta.**
4. **Lo que Katana decide** (en `DECISIONES-PENDIENTES.md`, con el coste de cada rama):
   - D1 · ¿Aceptar atestiguación por bloque a pesar de la viveza? — recomendación **NO**.
   - D2 · ¿Adoptar la tabla de poder derivada (maquinaria de la capa de comité)? —
     recomendación **NO** (reabre lo descartado sin comprar nada).
   - D3 · ¿Revisar la línea roja del ancla externa? — recomendación **NO**, y además no
     ayudaría: como condición de validez es vacía (F2-b); como ayuda al operador ya está
     permitida y no toca κ = 0.
   - D4 · ¿Perseguir el frente de la oferta (pools, alquiler, custodios — el H-7 de
     `P-ZRX/T-ZRX/ESTADO-DOBLE-FARMEO.md` §2)? — recomendación **SÍ**: es el único frente
     con expectativa razonable, y este encargo confirma por qué: **el secreto no se
     rompe por el lado de la validez.**
5. **La consecuencia para el resto del mapa**: con κ = 0 intocable por condiciones de
   validez, la defensa del doble farmeo queda donde ya estaba: la ventana C-FIN-01 (lo
   vuelve inútil más allá de F) y el lado de la oferta de β. Nada de este encargo revoca
   AGENTS.md ni las dos líneas rojas; las cuantifica.

---

## Lo que esta investigación NO resuelve

- **La `p` real de un granjero doméstico** y el `p_sil` real: entradas, no medidas; sin
  ellas las cifras de viveza son funciones de entradas, no predicciones de red
  (lo mismo que declaró la capa de comité descartada).
- **El steering de la tabla de poder derivada** (D8): heredado sin cerrar; se declara la
  cota por analogía (m = 2,955 medida / 151 por construcción), no se re-mide.
- **La correlación reto/sorteo** (S4): ambos derivan de la misma salida del PoT; se
  tratan como independientes y la conclusión cualitativa no depende de ello, pero no está
  demostrado.
- **La distancia de overlay productor↔firmante (h)**: derivada de DMS-v0.1 (≈2–3), no
  medida en la red destino; por eso se publica h ∈ {1, 2, 3}.
- **La criptografía de la atestiguación en sí** (BLS frente a Ed25519, prueba de que el
  firmante «vio» algo): no existe tal prueba — es el punto de F1 — y no se construye
  ninguna primitiva nueva.
- **Los valores de k, α, F, τ, Δ, p, p_sil, β**: símbolos y entradas; no se fija ninguno.
- **La alternativa al ancla externa como regla**: queda descartada por línea roja, sin
  cuantificar su coste de operación como ayuda al operador.
- **El cableado en el nodo**: nada de esto está en `crates/`; es un modelo cuantitativo.
