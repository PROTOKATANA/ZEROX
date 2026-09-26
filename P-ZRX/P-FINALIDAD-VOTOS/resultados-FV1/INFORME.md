# INFORME FV-1 — Capa de finalidad por votos bajo R1–R5 (segunda ejecución)

**Orden:** FV-1 (segunda ejecución, sobre `ORDEN-FV1-DISENO.md` con la decisión 6 de Katana ya
incorporada: sorteo secreto entre todos los registrados con prima `b`). **Ejecutor:** subagente
Sonnet, único, sin subagentes. **Fecha:** 2026-09-26. **Zona:** `deepseek/FV1/`.
**Comprobación de entrada** (`P-ZRX/P-FINALIDAD-VOTOS/ENTRADA-FV1.sha256`): coincide al empezar
(10/10 archivos) y se repite al final de este informe.

Etiquetas: **[P]** primaria leída · **[S]** secundaria · **[D]** derivación propia (con la cuenta
hecha aquí o en `CONTRATO-FINALIDAD-VOTOS-v0.md`) · **[H]** hipótesis de diseño.

---

## 1 · Respuesta a la pregunta falsable

> «Existe una capa de finalidad por votos que cumple R1–R5 a la vez y en la que (a)…(e)»

**Refutada en (a); sostenida con condición en (b) y (d); sostenida con una excepción explícita en
(c); sin respuesta limpia en (e).** El contraejemplo de (a) es el resultado central de esta
ejecución.

### (a) — REFUTADA

*Enunciado:* «ningún atacante cuyo peso, sumado al de los honestos apagados, sea menor que un tercio
del peso total puede pausar ni romper el sello».

**Contraejemplo, con la cuenta en `calc/resultados/C1-umbral-pausa-rompe.csv` [D].** Con el sorteo de
la decisión 6 (probabilidad ∝ espacio × prima `b` si hay prueba de disponibilidad vigente), la
fracción **esperada** de plazas del atacante bajo censura total de las pruebas honestas es
`q_a(a,b) = a·b / (a·b + 1 − a)` (cifra que el propio director ya había anotado como techo de
seguridad, `ORDEN-FV1-DISENO.md` §3.6). Lo que no estaba resuelto es el umbral de **peso `a`** al que
ese techo cruza 1/3 (pausa) o 2/3 (ruptura), y ese umbral **no es 1/3 constante**: es

```text
a_pausa(b) = 1 / (2b + 1)         a_rompe(b) = 2 / (b + 2)
```

(deducción algebraica de `q_a(a,b) = 1/3` y `= 2/3`; verificado por test exacto en
`calc/test/runtests.jl` y numéricamente en `calc/resultados/C1-umbral-pausa-rompe.csv`). Para `b = 1`
(sin prima) ambos coinciden con 1/3 y 2/3: (a) se sostiene exactamente igual que en el diseño «votan
todos, 2/3 del total». **Para todo `b > 1`, `a_pausa(b) < 1/3`.** A la prima que `CONTEXTO.md` §3.6
llama «moderada» (`b = 4`): `a_pausa(4) = 1/9 ≈ 11,1 %`. Es decir: **un atacante con solo el 11 % del
peso total registrado**, si además puede **censurar la red** para que ninguna prueba de
disponibilidad honesta llegue a tiempo (columna «control de la red» de la tabla de ataques, §3,
ataque 13), **pausa el sello** — muy por debajo del tercio que (a) promete. El umbral de **ruptura**
(`a_rompe(4) = 1/3`) sí coincide, por coincidencia numérica, con el tercio esperado a `b = 4`; para
`b > 4` también cae por debajo de 1/3 (`a_rompe(6) = 1/4`, `a_rompe(10) = 1/6`).

**Por qué es un contraejemplo genuino y no una curiosidad de la varianza.** La cuenta anterior es la
**esperanza** del sorteo, no una cola de probabilidad rara: con `K` finito la probabilidad de que la
realización concreta se acerque a esa esperanza es alta y **crece con `K`**
(`calc/resultados/C1-p-al-menos-tercio-censura.csv`: con `b = 2`, `K = 1000`, la probabilidad de que
el atacante tome ≥ 1/3 de las plazas ya es `1,00` — no hace falta varianza, el umbral **ya está
desplazado**). Subir `K` no arregla nada aquí: protege de una excursión de varianza alrededor de un
umbral seguro, no de un umbral que la propia prima movió.

**Lo que NO cambia (b) no basta como defensa contra (a).** El umbral de RUPTURA (2/3, condición (b))
se mantiene razonablemente cerca de 1/3 mientras `b ≤ 4`. El problema es específicamente el umbral de
**pausa**, que se degrada mucho más rápido (`1/(2b+1)` decrece más deprisa que `2/(b+2)`). El suelo de
representatividad `E` (§4) **no lo repara**: convierte un intento de romper el sello en una pausa
explícita (mejora (b)), pero la pausa **sigue ocurriendo** con `a` muy por debajo de 1/3, solo que
ahora es una pausa «declarada» en vez de una posible ruptura silenciosa.

**Qué haría falta para restaurar (a) literalmente:** `b = 1` (sin prima), que es exactamente el
diseño de referencia «votan todos, 2/3 del total» — y entonces se pierde la ganancia de viveza que es
la razón de ser de la prima (necesita el 88,9 % de honestos encendidos con `a = 0,25`, frente al
77,8 % con `b = 4`). **No hay valor de `b > 1` que preserve literalmente (a) frente a un atacante con
control de la red.** Esto no es una falla de cálculo de la decisión 6: es la contrapartida exacta que
el propio mandato pedía cuantificar («el atacante siempre cobra la prima», `PROGRAMA.md`).

### (b) — Se sostiene, con la condición ya declarada por el mandato

Romper el sello (2/3 de las plazas) deja siempre `EvidenceVoto` de las claves firmantes: la firma es
pública e irrevocable una vez emitida (§3 del contrato, FV-EVP-02). Con `f_voto` fijo (§9), la pérdida
es proporcional a la garantía de cada clave firmante, y la garantía **sí** crece con el peso porque el
peso de voto es literalmente el espacio registrado con garantía (FV-EVP-06). **Condición no
negociable, ya en SL-1 y heredada aquí sin cambios de forma:** `R_slots > duración(Plazo_voto_
instancias) + M_margen_slots` (FV-EVP-05); sin ella, el atacante retira antes de que la ventana de su
propio doble voto cierre. **Límite declarado, no defecto de esta pieza:** si el atacante reparte su
peso en muchas claves nuevas de saldo bajo (la grieta de `P-CLAVE`, §2 de `PROGRAMA.md`), la garantía
expuesta por incidente es la de esas claves, que puede ser pequeña — el mismo residuo que
`P-ZRX/P-DISUASION/SINTESIS.md` ya declaraba para `EvidenceTx` (DS-3/DS-6): aquí no se cierra ni se
reabre, se hereda.

### (c) — Se sostiene con una excepción explícita, demostrada en `CONTRATO-FINALIDAD-VOTOS-v0.md` §5

Pausada o sin activar: **demostrado**, aditividad estricta (idéntico argumento que F3/EIP-3675).
Rota, **antes** de que un nodo adopte el certificado falso: **demostrado**, `C-FIN-01` sigue
protegiendo exactamente igual. Rota, **después** de adoptar el certificado falso: **no se sostiene
sin matiz** — un certificado, a diferencia de una reorganización por `blue_work`, no es reversible por
más trabajo honesto posterior (es la contrapartida de ser rápido y determinista). Contraejemplo
concreto en el contrato, FV-18. Esto no es una regresión inventada por esta capa: es el precio
conocido de toda finalidad determinista (Casper, F3) frente a una regla probabilística (GHOSTDAG
puro), y el mandato ya lo anticipaba en `CONTEXTO.md` §4.1 («engañar a un nodo eclipsado… no, salvo
2/3 de las firmas»). Mitigación propuesta (FV-19, no probada): un nodo no debería adoptar un
certificado que contradiga su propia vista de `blue_work` mayor.

### (d) — Se sostiene, condicionado a `Δ` no medida

En marcha normal (sin ataque, `p` real por encima de `p_necesaria(a,b)`), el tiempo hasta el sello es
`T_sello = rondas_esperadas(a,b,p,K) × c_fase × Δ`, con `rondas_esperadas` finito y pequeño —
`calc/resultados/C4-ventana-doble-farmeo.csv`: con `b = 4`, `p = 0,8`, `a ∈ {0,20; 0,25}`, entre 1,0 y
1,1 rondas en esperanza. Con `Δ` sin medir (IPA B-05) no se puede dar el número en segundos, pero
**la forma funcional es menor que `F_slots`** siempre que `rondas_esperadas` sea finito, lo que ocurre
exactamente cuando `p ≥ p_necesaria(a,b)` (fórmula cerrada, `p_necesaria(a,b) =
2(ab+1−a)/((1−a)(b+2))`, verificada contra los dos extremos citados por el mandato: `b=1` da la cifra
del «votan todos» 88,9 % y `b→∞` da la del «solo los encendidos» 66,7 %, ambas con `a=0,25`). Cuando
`p < p_necesaria(a,b)` (por ejemplo `a = 0,30` con `b = 4` y `p = 0,8`), `rondas_esperadas` es
astronómico (`2,8 × 10⁷` en la tabla) y la capa **no** cumple (d): se comporta como si estuviera
pausada, y `C-FIN-01` gobierna el tiempo hasta la finalidad, sin mejora.

### (e) — Sin respuesta limpia; hay que decirlo, no maquillarlo

*Primera condición* («sella con menos participación honesta que el 88,9 % de referencia»): **se
cumple con cualquier `b > 1`** (`p_necesaria(a,b)` es estrictamente decreciente en `b`, verificado
algebraicamente y por tabla). *Segunda condición* (el atacante no reúne 2/3 de las plazas ni
censurando todo): **se cumple para `a = 0,25` mientras `b < 6`** (cifra ya dada por el director,
reconfirmada: `a_rompe(6) = 1/4 < 0,25`, es decir a `b = 6` el atacante de 0,25 YA rompe; el límite
exacto es `b < 2(1−a)/a = 6` para `a = 0,25`). **Ambas condiciones juntas** dan una ventana real:
`1 < b < 6` para `a = 0,25`. **Pero la pregunta (e), tal como está escrita, no pide nada sobre la
pausa** — y ahí está el problema que (a) ya destapó: **dentro de esa misma ventana `(1,6)`, el umbral
de PAUSA cae muy por debajo de 1/3 para casi todo el rango** (`a_pausa(2) = 0,20`; `a_pausa(4) =
0,111`; solo cerca de `b → 1⁺` se acerca a 1/3). **No existe ningún `b > 1` que a la vez (i) mejore la
viveza de forma apreciable, (ii) mantenga al atacante de referencia (20–25 %) sin poder romper el
sello, y (iii) preserve el umbral de pausa en 1/3.** Es un trilema, no una elección con solución
limpia. La recomendación de este informe (§6) es aceptar (i) y (ii) con un `b` moderado (`b ∈ [2,4]`)
y renunciar explícitamente a (iii), documentando el umbral de pausa real como parte del contrato
(ya hecho en `CONTRATO-FINALIDAD-VOTOS-v0.md` §9), en vez de heredar la promesa de 1/3 sin
comprobarla.

---

## 2 · Tabla R1–R5

| Regla | Estado | Por qué |
|---|---|---|
| **R1** (entrada abierta) | **Se cumple** | Todos los registrados con garantía activa entran en el sorteo (FV-04); la probabilidad depende solo de `peso(P,n)` y de un booleano en la cadena (FV-05/07/08); nadie queda fuera por espacio pequeño ni por estar apagado (FV-09). Corrige exactamente el punto que la propuesta antigua (R-FIN-16, «solo quien ganó un bloque en 30 min») y la primera mezcla de Katana (§3.5 de `CONTEXTO.md`) dejaban abierto. |
| **R2** (sin elección) | **Se cumple** | El peso es el espacio registrado con garantía, verificado en la cadena (FV-01); la prima depende de un booleano verificable, no de una puntuación ni de un tercero que mida (FV-05, FV-08). Ningún voto de terceros ni métrica externa entra en la probabilidad. |
| **R3** (nadie indispensable) | **Se cumple con condición** | Producir bloques nunca depende de los votantes (§0/FV-24: antes de activar, la capa no existe); sin quórum, se pausa (FV-20), sin castigo por ausencia. **Condición:** la pausa puede ser inducida con un `a` muy por debajo de 1/3 si el atacante controla la red (§1(a)); R3 no distingue "pausa cara" de "pausa barata" — el mandato solo exige que sea **posible** pausar sin castigar, y eso se cumple; no exige que pausar sea **caro**, y ahí es donde (a) se refuta. |
| **R4** (sin decidir contenido) | **Se cumple** | Un voto solo puede sellar el hash de un bloque ya seleccionado por GHOSTDAG/`blue_work` (FV-12); no hay forma de proponer contenido ni de preferir una rama por un criterio propio del votante. Por construcción, no por vigilancia. |
| **R5** (toda falta deja firma) | **Se cumple con condición** | El doble voto (FV-EVP-01…06) reutiliza el patrón de `EvidenceTx`/SL-1: verificación `O(1)`, incidente único, ventana de admisión, confiscación no correlacionada. **Condición, heredada y no cerrada por esta capa:** con claves de saldo bajo (la grieta de `P-CLAVE`), la garantía expuesta puede ser pequeña; y la falta de un `requisito(B)` con techo por clave (`IPA C-02`, abierto) es lo que hace que "la garantía crece con el peso" sea cierto **hoy**, pero frágil a una decisión futura sobre `requisito`. |

**Comprobación de incompatibilidad entre reglas (mandato §3.1):** no se ha encontrado ninguna pareja
de R1–R5 mutuamente incompatible bajo este diseño. La tensión real no es entre dos reglas del mandato,
sino **dentro de R3**: el mandato exige que la pausa sea posible sin castigo (se cumple) pero el
director esperaba, sin que estuviera escrito como regla, que pausar costara «al menos un tercio»
(expectativa de `PROGRAMA.md`, no una R de Katana) — y esa expectativa es la que (a) refuta.

---

## 3 · Análisis adversarial

Convenciones: `a` = fracción del peso total del atacante; `o` = fracción de honestos genuinamente
apagados (máquina realmente sin encender, distinto de «censurado»); **control de red** = capacidad de
suprimir selectivamente mensajes de otros (gossip de pruebas de disponibilidad, votos, o aislar a un
par), evaluada aparte del peso porque, con el gestor de direcciones inexistente
(`R-ZRX/LEGADO/eclipse/INFORME.md` §3, «el gestor de direcciones de ZEROX NO EXISTE»), esa capacidad
**no cuesta espacio ni ancho de banda apreciable** hoy [P].

| # | Ataque | `a` | `o` | Control de red | Qué puede hacer | Coste absoluto | ¿Firmado? | Imposible / caro |
|---|---|---|---|---|---|---|---|---|
| 1 | Pausa con `a+o ≥ 1/3` (diseño de referencia, `b=1`) | ≥ 1/3 | — | No | Impide el quórum de 2/3 total; no rompe nada | 1/3 del peso total registrado (TiB + garantía madura) | No (no firmar no es falta) | **Caro** en el sentido pretendido: exige poseer/controlar de verdad un tercio del registro |
| 2 | Doble sello con un tercio y control de la red | ≥ `a_rompe(b)` (1/3 a `b=1`; **1/4 a `b=6`**; **1/6 a `b=10`**) | — | **Sí** | Firma dos certificados contradictorios (FV-18); «mentira permanente» para quien ya lo adoptó | Peso decreciente en `b` (fórmula `2/(b+2)`) **más** control de red para censurar la prima de los honestos | **Sí**, `EvidenceVoto` de cada firmante (FV-EVP-02) | **Caro** a `b≤4` (≈1/3); **cada vez más barato** a `b>4` |
| 3 | Sesgo de la tabla de pesos (retener/publicar bloques, elegir ancla) | variable | — | No (elección de ancla no exige censura) | Intentar que su rama sea `A_n`; solo lo consigue si ya gana el consenso de producción (ajeno a esta capa, FV-03) | El de ganar `blue_work`, no adicional | — | **Imposible** ganar la tabla sin ganar antes GHOSTDAG; el sesgo residual es el de elegir el **mejor** ancla entre las que ya gana (§4.D antiguo, ataque 14) |
| 4 | Eclipse de un nodo observador | 0 | — | **Sí** (de UN nodo) | Le oculta certificados reales; el nodo cae a `C-FIN-01` en solitario (pierde la mejora de viveza, no la seguridad — caso «pausada» de FV-18) | **≈ 0 espacio, ancho de banda ≈ 0** (`R-ZRX/LEGADO/eclipse/INFORME.md` §F4, medido para el eclipse de red general; se hereda sin remedir aquí) | No | **Barato** degradar la viveza de un nodo; **imposible** romper el sello global con solo esto (no aporta peso) |
| 5 | Partición y flujos de PoT: certificado que cruza flujos | variable | variable | (implícito en la partición) | Sellar en un lado, contradiciendo al otro | Necesita ≥2/3 del peso TOTAL de un lado, no solo de los presentes en su flujo (FV-06 usa la tabla derivada del pasado, no de la vista local) | Sí, si rompe (ataque 2) | El requisito de 2/3 del **total**, no de los presentes, hace que una partición equilibrada **pause ambos lados** en vez de sellar dos historias contradictorias — mejora frente a `C-FLU-15` («partición sin cura en el protocolo»), pero solo si ningún lado por sí solo alcanza 2/3 |
| 6 | Largo alcance con claves que ya retiraron su garantía | histórico (peso que **tuvo**, no el actual) | — | No necesario para el nodo completo | Fabricar una cadena de certificados alternativa desde una instancia antigua, firmada con claves ya sin nada en juego | **Gratis** en capital (las claves retiradas no arriesgan nada, DS-L05/FV-EVP-05 ya cerró la ventana de evidencia hace tiempo) | No (fuera de `Plazo_voto_instancias`) | **Imposible contra un nodo completo** (sigue el `blue_work` real desde génesis, FV-17 solo ata a quien ya tiene una cadena que reorganizar); **abierto y sin cerrar contra el cliente ligero de FV-16**, que esta ejecución deja explícitamente sin diseñar — es el mismo dilema de subjetividad débil que `D4` (ancla externa) prohíbe resolver con un punto de control |
| 7 | Delegación del voto y firma a ciegas | cualquiera | — | No | Un «servicio de disponibilidad» agrega muchas claves delegadas y vota por ellas: comité de hecho contra R1/R2 en la práctica, aunque no en la letra | Barato montar el servicio; el granjero que delega arriesga **toda** su garantía si el servicio se equivoca o es hostil (mismo griefing que P-POOLS) | El castigo cae sobre la clave delegante, no sobre el servicio (mismo límite que FIR-13 de SL-1) | **No se puede impedir por regla de consenso** (mismo veredicto que P-POOLS §1.3); mitigación de arquitectura: sub-clave de voto separada de la clave de garantía (no incluida en el contrato v0, recomendado en §6) |
| 8 | Censura por un tercio | 1/3 real | — | Implícito (necesita alcance de red proporcional a su peso) | Impide el quórum absteniéndose/censurando; degenerado con el ataque 1 | 1/3 del peso real | No | **Aceptado por diseño** (R3): es exactamente lo que la pausa permite, sin necesitar prima ni censura fina |
| 9 | Denegación de servicio con certificados inválidos | 0 | — | No necesariamente | Inunda la red con certificados mal formados o mal firmados | Bajo para el atacante (mensajes pequeños); verificación de rechazo es `O(1)` (FV-15) | No | **Mitigable** con las mismas cuotas de presupuesto de red que el resto del protocolo (`C-NET-33`-style); no diseñado en detalle aquí (FV-4) |
| 10 | Falsos positivos de R5: misma clave en dos máquinas; fallo común del cliente | 0 (honesto) | — | No | Doble voto accidental | El castigo cae sobre el saldo de la clave, no sobre "quién la usó" (mismo límite que FIR-13/SL-1); **hallazgo de esta ejecución:** votar es más frecuente que producir bloques, así que el "firmante seguro" (`FIR-01…13` de SL-1) debe extenderse explícitamente al flujo de voto, no solo al de producción — no estaba cubierto por SL-1 y esta ejecución lo señala como pendiente para FV-3 | — | Sin castigo correlacionado (DS-L02), un fallo compartido de cliente no se amplifica; sigue siendo un coste real para el honesto individual |
| 11 | Activación prematura, poca garantía tras el corte | variable, potencialmente alto sobre una base pequeña | — | No necesario | Una clave que deposita temprano domina la tabla inicial | Depende enteramente de `S_min_voto`/`K_min_voto` (FV-23), no calibrados aquí | — | **Caro si los pisos se fijan con margen** (no cuantificado); **barato si se activa demasiado pronto** — mismo patrón que A8 de `P-DISUASION` (captura de la transición) |
| 12 | Ventana residual del doble farmeo | grande (atacante «grande» de RFT-01/RFT-09) | — | Puede necesitar (para mantener `p` bajo `p_necesaria`) | Mientras `p` real se mantenga bajo `p_necesaria(a,b)` (§1(d)), el sello no llega y la ventana del doble farmeo permanece en `F_slots` | El de sostener `a` grande **y** mantener la participación honesta con prueba por debajo del umbral | — | **No se cierra** (RFT-01 es premisa, `ORDEN-FV1-DISENO.md` §3.8); esta capa lo arrincona **condicionalmente**, no siempre |
| 13 | Quitar la prima a los honestos (censurar sus pruebas de disponibilidad) | tan bajo como `a_pausa(b)` | — | **Sí, imprescindible** | Pausa el sello con mucho menos de 1/3 (§1(a)) | El de censurar la red, hoy barato (gestor de direcciones inexistente) | No | **Barato** a `b ≥ 2`; es el hallazgo central de esta ejecución |
| 14 | Sesgar el sorteo: entropía/ancla, repartir en muchas claves | variable | — | No para repartir; sí (parcial) para el ancla | El sesgo por elección de ancla (`m=2,955` medido / `m=151` cota) es de **segundo orden** frente al desplazamiento por `b` (`calc/resultados/C2-sesgo-ancla.csv`: a `b=1` sigue siendo despreciable con `K=4000`; a `b≥2` ya no importa, porque el umbral **ya** está roto en esperanza). Repartir en muchas claves **no cambia el peso agregado** (RFT-05); la garantía expuesta por incidente es aproximadamente invariante a la partición, solo cambia el número de incidentes necesarios | — | Cada clave que vota expone su propio saldo (FV-EVP) | **Imposible** evadir la suma de pesos partiendo claves (RFT-05); el sesgo de ancla es **caro** de explotar solo (necesita `K` bajo) |
| 15 | Atacar a un votante tras revelarse | 0 (no necesita peso) | — | Sí, localizado | Intentar tumbar/sobornar a un votante ya conocido para esa ronda | El voto ya es público e inmutable una vez emitido: atacar después no cambia esa ronda, **salvo** que el atacante logre suprimir el mensaje ANTES de que se propague lo suficiente (mismo problema del ataque 4, aplicado a un mensaje concreto en vez de a un nodo) | No aplica (nada que castigar si no llegó a votar) | **Imposible** cambiar un voto ya propagado; **posible y barato** suprimir un voto que aún no salió del entorno inmediato del votante (ventana de carrera con `Δ`, no medida) |

**Contraste con `LIBRO-DE-RESTRICCIONES.md` (mandato §4.B, previo a cada pieza):**

- **R-4/R-5** (exclusividad por identidad se evade partiendo el espacio; coste fijo no basta):
  aplicado en el ataque 14 — el peso de voto se suma, no se puede evadir partiendo claves, y el
  contrato no propone ninguna exclusividad por identidad que R-4/R-5 pudieran refutar.
- **R-6** (ninguna condición de validez sobre `past(B)` obliga a publicar): la entrada de la VRF
  (FV-06) es función de `past(A_n)`, no de la vista del nodo, así que no reabre R-6 ni pretende
  cerrar la rama privada — la capa nunca finge cerrar el doble farmeo por esta vía (§1(d)/ataque 12).
- **R-10** (una firma no prueba que el firmante vio nada): aplica directo al ataque 7 (delegación) —
  el voto es una firma más, y «firmar solo lo votado por uno mismo» es conducta, no regla de consenso,
  exactamente como con la producción de bloques.
- **R-9** («partir cuesta» ⟺ «es regresivo»): no aplica a la fuente de peso elegida (FV-01 no impone
  una cuota por identidad), pero **sí** aplicaría si `requisito(B)` terminara con un techo fijo por
  clave (nota de FV-EVP-06): un techo fijo sería regresivo con el granjero pequeño, exactamente por
  R-9.
- Ninguna otra restricción del libro (R-1, R-2, R-3, R-7, R-8, R-11, R-12) es directamente aplicable:
  no son de identidad, de tiempo-VDF ni de PoW; la capa no propone plotear ni sortear el reto de
  producción.

---

## 4 · El diseño elegido frente a los tres comparadores del mandato

| | **Elegido**: sectores registrados + sorteo secreto entre todos, prima `b` | **(A)** bloques cobrados en ventana | **(C)** solo `C-BON` (stake puro) | **b→∞** «solo los encendidos» | «Votan todos, 2/3 del total» |
|---|---|---|---|---|---|
| R1 | Exacta (todos entran) | No: filtra por haber producido, penaliza dos veces al pequeño (`ORDEN-FV1-DISENO.md` §3.6) | Exacta si todo el que deposita entra | No (filtra por estar encendido) | Exacta |
| R2 | Exacta | Exacta (deriva de bloques cobrados, verificable) | Exacta | Exacta | Exacta |
| Umbral de pausa | **`1/(2b+1)`, cae con `b`** | No modelado en este contrato (comparador declarado, no diseñado) | Igual que «votan todos» si el stake fuera la única fuente | `2a/(1-a)` en participación, no en peso — distinto eje | `1/3` (referencia) |
| Umbral de ruptura | `2/(b+2)`, cae con `b` para `b>4` | No modelado | `2/3` si el stake es la fuente | Depende de qué fracción está encendida | `2/3` |
| Viveza (participación honesta necesaria) | `p_necesaria(a,b)` decreciente en `b`; **77,8 %** a `b=4,a=0,25` | No modelada | Análoga a «votan todos» sin sorteo | La mejor (66,7 % a `a=0,25`) | La peor (88,9 %) |
| R5 (garantía crece con el peso) | **Sí**, por construcción (mismo objeto para peso y garantía) | No, salvo diseñar una garantía nueva atada a bloques cobrados (no existe) | Sí, por construcción, pero entonces el peso **no es espacio** y `SPEC.md` §0 cambia (mandato §6) | Igual que el elegido, con `p` reinterpretada | Igual que el elegido con `b=1` |
| Coste del certificado | Depende de `K` (§C.3); necesita BLS a `K` grande | Igual | Igual | Igual (mismo mecanismo de sorteo, solo cambia el filtro) | Sin sorteo: `K` = todos los registrados, certificado potencialmente enorme salvo BLS |

**Veredicto:** el diseño elegido domina a (A) en R1 y es equivalente a (C) salvo por la decisión de
que el peso sea espacio y no stake (que es la decisión de fondo de Katana, no de este informe). Frente
a los dos extremos del propio dial (`b=1` y `b→∞`), el diseño con `b` moderado (2–4) mejora la viveza
de `b=1` sin llegar a exponerse tanto como `b→∞` — pero, como muestra §1(a), **ya a partir de `b>1`
pierde el margen de seguridad de pausa que `b=1` (votan todos) sí tenía**. No hay un punto en el dial
que domine estrictamente a los dos extremos en las tres dimensiones (viveza, seguridad de ruptura,
seguridad de pausa) a la vez.

---

## 5 · Qué mejora frente a `C-FIN-01` sola, y qué no

**Mejora, condicionado:**
1. La ventana útil del doble farmeo pasa de `F_slots` a `T_sello` (§1(d)), **mientras** la
   participación honesta con prueba se mantenga sobre `p_necesaria(a,b)`. Cuantificado por primera
   vez con números concretos (no solo la forma funcional que tenía `PROGRAMA.md`):
   `calc/resultados/C4-ventana-doble-farmeo.csv`.
2. Reescribir lo sellado exige firmas públicas de al menos `a_rompe(b)` del peso total **con control
   de la red** — un coste exigible y con evidencia, aunque el umbral sea menor que 1/3 para `b>4`.
3. Una partición equilibrada de flujo (`C-FLU-15`, «sin cura en el protocolo») **no produce dos
   historias contradictoriamente selladas**: el requisito de 2/3 del peso TOTAL (no de los presentes)
   hace que, si ningún lado tiene una mayoría real, **ambos** se queden sin sellar en vez de sellar
   cada uno el suyo (ataque 5). Es una mejora estructural que la propuesta antigua no señalaba con
   esta claridad.

**No mejora, o empeora:**
1. **El doble farmeo sigue sin cerrarse** (RFT-01, premisa). Con `a` grande y control de red para
   mantener `p` bajo, la ventana vuelve a `F_slots` (ataque 12).
2. **La pausa deja de costar 1/3** en cuanto `b>1` y hay control de red (ataque 13, §1(a)) — el precio
   de la mejora de viveza es exactamente esta degradación, no un efecto secundario evitable.
3. **Introduce la "mentira permanente"** (FV-18): un certificado adoptado no se revierte por más
   `blue_work` honesto, a diferencia de una reorganización bajo `C-FIN-01` sola.
4. **Costes nuevos para el honesto:** registro con garantía (ya contado en `C-BOT-03`), mantener una
   prueba de disponibilidad vigente (coste de transacción o de ganar bloques), y el riesgo de doble
   voto accidental si el firmante seguro no se extiende al flujo de voto (ataque 10, hallazgo nuevo).

---

## 6 · Decisiones para Katana

| # | Decisión | Opciones | Coste de cada una | Recomendación |
|---|---|---|---|---|
| D1 | Valor de `b` | `b=1` (preserva (a) literalmente, pierde viveza: 88,9 % de honestos encendidos); `b∈[2,4]` (viveza real, `a_pausa` entre 20 % y 11 %); `b≥6` (rompe también el umbral de ruptura a `a=0,25`) | Explicado arriba | **`b=4`**: mantiene `a_rompe(4)=1/3` para el atacante de referencia y reduce la participación necesaria a 77,8 %; aceptar explícitamente que `a_pausa(4)=11,1 %` bajo censura de red, y tratarlo como un riesgo declarado (no oculto) |
| D2 | Suelo `E` | Sin `E` (una ruptura fallida por baja `p` puede intentarse igualmente); con `E` (una ruptura con `p` bajo se convierte en pausa explícita, no en certificado dudoso) | `E` no repara el umbral de pausa (§1(a)); solo mejora (b) | **Adoptar `E`** como defensa de (b), documentando que no repara (a) |
| D3 | Esquema de firma del certificado | BLS agregada (certificado pequeño, introduce `blst` en consenso) vs. Ed25519 por plaza (sin dependencia nueva, certificado que a `K=4000` cuesta ≈ 264 kB, ≈ 278 GB/año a 30 s — supera la cadena entera) | Ver `calc/resultados/C3-certificado.csv` | **BLS**, con la misma condición que ya declaró `AGUJEROS-Y-SOLUCIONES.md` §5 para el segundo VDF: es una bifurcación de Katana, no una recomendación técnica que se pueda dar por descontada |
| D4 | Extender el firmante seguro (FIR-*) al flujo de voto | Sí (coste de implementación, ya con precedente en SL-1) / No (deja el ataque 10 sin mitigar) | Bajo, mismo patrón ya validado en SL-1 | **Sí** — es un hallazgo de esta ejecución, no estaba en el alcance de SL-1 |
| D5 | Sub-clave de voto separada de la clave de producción/garantía | Sí (acota el griefing de la delegación, ataque 7) / No (mantiene una sola clave, más simple) | Complejidad de gestión de claves nueva | Recomendado como línea de diseño para FV-2/FV-3, no decidido aquí |
| D6 | Cliente ligero de FV-16 | Diseñarlo ahora (hereda el problema de largo alcance, ataque 6, y choca con D4 de `AGUJEROS-Y-SOLUCIONES.md` — sin ancla externa) / dejarlo fuera de alcance | Diseñarlo exige resolver subjetividad débil sin violar la línea roja | **Dejarlo fuera** hasta que Katana decida si acepta algún supuesto de confianza de arranque para clientes ligeros (afecta a más que esta capa) |

---

## 7 · Qué no está medido, y cómo medirlo en la red dev

- **`Δ` real** (IPA B-05): sin ella, `T_sello` en segundos y `c_fase` de GossiPBFT quedan simbólicos.
  Medir con `P-ZRX/P-MEDICION/ESCENARIOS-0.0.1.md` en cuanto W06d2 tenga red real.
- **`p` real** (fracción de honestos con prueba de disponibilidad vigente, sin censura): no medible
  sin nodos corriendo; es la misma incógnita que mató la viveza de la propuesta de 2026-09-09 (§4.C).
- **Coste real de censurar la red** (ataque 13): condicionado a que se cablee un gestor de direcciones
  (hoy inexistente, `R-ZRX/LEGADO/eclipse/INFORME.md`); mientras no exista, cualquier cifra de "coste
  de censura" es una cota superior optimista, no una medida.
- **El sesgo de la tabla de pesos por retención/publicación de bloques** (ataque 3, FV-03): declarado
  como no encontrado en esta ejecución, no como cerrado; sigue siendo D8 del catálogo antiguo.
- **La interacción de esta capa con `P-FLUJO`** (ataque 5): la conclusión de §3 es una derivación
  algebraica sobre las reglas ya escritas, **no** una simulación con dos vistas y dos flujos
  divergentes (el mismo límite que `R-ZRX/LEGADO/eclipse/INFORME.md` declara para su propio F1).

---

## 8 · Comprobación de entrada (repetida al final)

```
$ cd /home/katana/zeo/ZEROX && sha256sum -c P-ZRX/P-FINALIDAD-VOTOS/ENTRADA-FV1.sha256
```
Resultado: **coincide** (10/10), igual que al empezar esta ejecución. Ningún archivo de entrada se
modificó durante el encargo (zona de escritura única: `deepseek/FV1/`).

---

## 9 · Entregables

- `deepseek/FV1/CONTRATO-FINALIDAD-VOTOS-v0.md`
- `deepseek/FV1/INFORME.md` (este documento)
- `deepseek/FV1/calc/` — `Project.toml`, `Manifest.toml`, `julia-version.toml`, `src/modelo.jl`,
  `src/referencia.jl`, `run.jl`, `test/runtests.jl`, `resultados/*.csv`, `resultados/salida-run.txt`
- `deepseek/FV1/HUELLAS.sha256`
