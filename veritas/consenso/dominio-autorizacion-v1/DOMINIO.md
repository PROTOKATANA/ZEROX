# DAV: dominio económico estable y compatibilidad de contextos

Fecha: 2026-09-11. Categoría: consenso; derivación documental por especialista en matemáticas/Julia.
Se han releído AGENTS, README, MIGRACION, LINEO íntegro, SPEC §7, las reglas de flujo aplicables y
el informe final IDV. **No se ejecutan cálculos, simulaciones ni tests en esta subtarea.** No se
modifica la evidencia anterior ni se activa consenso. Las pruebas propuestas son contratos
semánticos para el instrumento Rust, no un sustituto de un verificador PoT integrado.

## 1. Decisión candidata recomendada

**DAV-D1. Un dominio económico por red, estable a través de bifurcaciones, inyecciones y upgrades.**
Usar un identificador de red configurado por el protocolo y anclado a su génesis definitivo,
no elegido por el productor. No se fija aquí su valor, hash o serialización de producción.
No añadir una era que se reinicie con un ancla, un flujo, el rango o una nueva versión del software.
La versión de codificación puede cambiar sin cambiar el derecho; la migración debe preservar la
igualdad y el estado de consumo de las identidades anteriores.

**DAV-D2. Un derecho por coordenada de plot y slot en cada historia aplicada.**

```text
EconomicKey = (NetworkDomain, slot, public_key, sector_index, history_size, piece_offset)
```

Dos declaraciones verificadas de esta misma coordenada consumen el mismo derecho aunque usen
retos, raíces archivadas, rangos, pruebas, sellos, cuerpos o padres diferentes. No se fusionan
por ello sus evidencias criptográficas ni se declara válida una representación por validar otra.
La igualdad económica es una **regla candidata explícita de adjudicación**, no la afirmación de
que todo ese trabajo criptográfico o almacenamiento sea físicamente idéntico.

**DAV-D3. Estado por historia, no una lista mundial de pagos vistos.** En una historia candidata
admisible, se aplica el registro reversible de CBE: primera representación elegible canónica,
una adjudicación y un cuerpo ejecutable por EconomicKey, incluso con subsidio cero. Al cambiar
de rama se desconecta hasta el prefijo común y se reproduce la nueva historia. No se suman ni
unen los ledgers finales de ambas ramas. Dos candidatos excluyentes pueden tener adjudicaciones
alternativas del mismo derecho; eso no prueba un doble pago en una única historia convergida.

Esta recomendación cierra la **semántica candidata de igualdad entre contextos** sin fijar un
calendario. No cierra todavía cuáles de esos contextos son admisibles, el recurso necesario para
servirlos, el orden resistente a grinding ni el riesgo de que historias incompatibles persistan.
Fuentes: IDV [contrato](../identidad-disponibilidad-v1/CONTRATO-VALIDACION.md), líneas 18–37,
57–66; CBE [contrato](../contrato-billete-v1/CONTRATO.md), líneas 126–145 y 177–196.

## 2. Tres relaciones que no deben confundirse

Para una declaración s con contexto C y otra s' con contexto C':

| Relación | Definición candidata | Consecuencia |
|---|---|---|
| Equivalencia económica | EconomicKey(s)=EconomicKey(s') | A lo sumo una adjudicación en la misma historia aplicada. |
| Compatibilidad histórica del reloj | Los prefijos PoT efectivos coinciden en cada slot histórico que exige la relación de pasado. | Permite continuar las demás comprobaciones; no prueba cuerpos ni raíces ni PoAS. |
| Reutilización de evidencia | Coinciden declaración/pruebas y contexto completo relevante, o existe una prueba explícita de equivalencia de esos parámetros. | Permite reutilizar sólo la comprobación que acredita esa evidencia. |

La primera relación es igualdad de una proyección, por lo que es reflexiva, simétrica y
transitiva. Las otras no se deducen de ella. La compatibilidad de un bloque con una historia
se comprueba en los slots correspondientes; no es igualdad de las etiquetas actuales del flujo.

En particular, cambiar sólo el rango conserva EconomicKey, pero puede cambiar el resultado PoAS.
Cambiar una prueba conserva EconomicKey, pero puede cambiar la distancia. El informe IDV final
ya contiene un caso real del segundo hecho, bajo contexto criptográfico sintético explícito:
[INFORME.md](../identidad-disponibilidad-v1/INFORME.md), líneas 35–60. No se reejecuta ni extrapola.

## 3. Compatibilidad correcta: prefijo histórico, incluyendo N(s)

R-FIN-5 dice, para cada X del pasado de B:

```text
flujo(X, slot(X)) = flujo(B, slot(X))
```

No compara `flujo(X, punta_actual)` con `flujo(B, punta_actual)`. Dos ramas que divergen a partir
de t pueden conservar bloques anteriores a t como pasado común. Inyecciones futuras diferentes
tampoco hacen diferentes los retos ya producidos. En cambio, incorporar un bloque que se produjo
después de una divergencia real bajo el otro prefijo incumple la regla, si los prefijos difieren
en el slot de ese bloque. Fuente: `research/dag-poas-ancla-de-orden.md:212`, `:216`, `:219`, `:223`.

### 3.1 Refinamiento necesario de la descripción del flujo

R-FIN-3 describe el flujo mediante parejas `(entropía_j, t_j)`; R-FIN-14 calcula la salida con
`N(s)`, y R-FIN-9 deja pendiente la regla que determina/autentica N y su valor inicial.
Si se permite que dos contextos tengan la misma etiqueta R-FIN-3 y diferente N efectivo,
la etiqueta no basta para identificar la secuencia de PoT ni sus retos. No se puede asumir,
sin demostrarlo, que N sea función única de las parejas que la etiqueta ya compromete.
Fuentes: `research/dag-poas-ancla-de-orden.md:216`, `:258`, `:375`; `SPEC.md:1250`.

Recomiendo comparar un **descriptor semántico de prefijo** que incluya:

```text
PotOrigin       = (NetworkDomain, origen de índices, semilla inicial autenticada,
                   N inicial autenticado, semántica de transición PoT)
PotEvent        = (slot de activación, entropía inyectada, N efectivo desde ese slot)
PotPrefix(H, s) = (PotOrigin, secuencia canónica de PotEvent con activación <= s)
```

Los valores/origen y la procedencia de eventos siguen siendo entradas que el protocolo debe
resolver desde ancestros autenticados, no campos libres para legitimar una cadena recibida.
La secuencia representa las transiciones efectivas; no introduce eventos ficticios para renovar
identidades. Si hay dos anuncios del mismo evento, se requiere una representación canónica,
no duplicar su aplicación. Un cambio de N comparte el evento de inyección según la propuesta
R-FIN-9/14; este documento no autoriza otro calendario ni resuelve anuncios en conflicto.

La compatibilidad candidata refinada es:

```text
CompatiblePast(B) si para todo X en past(B):
    PotPrefix(H_X, slot(X)) = PotPrefix(H_B, slot(X))
```

El descriptor no contiene el rango de solución ni las raíces archivadas: éstos pertenecen a
otras comprobaciones del contexto. Un hash puede resumirlo después de fijar codificación y
resistencia a colisiones; en el test semántico conviene comparar los campos exactos. No se
prescribe una nueva etiqueta de hash de producción ni se modifica R-FIN-3 en esta etapa.

**Lema condicional de suficiencia para el reloj:** con origen y secuencia efectiva iguales hasta
s, misma transición determinista y verificación completa de los pasos, las salidas coinciden
hasta s por inducción en los slots: misma entrada y N producen la misma salida; cada inyección
combina la misma entropía con la misma salida anterior. Por R-FIN-14(b), el reto del mismo slot
también coincide. Esto no prueba autenticidad del origen/eventos, que el trabajo se ejecutó en
un tiempo físico dado, igualdad de todos los contextos PoAS ni finalidad.

Comparar únicamente salida final es más débil que este contrato estructural: no demuestra
que se haya autenticado el mismo origen y calendario. Comparar sólo entropías/slots omitiendo
N también es insuficiente salvo prueba adicional de derivación única de N.

### 3.2 Horizonte y datos faltantes

El borde de activación es inclusivo: el evento con `t=s` pertenece al prefijo en s; si `t>s`,
no pertenece todavía. Es la convención explícita `t_j <= s` de R-FIN-3/14, no una elección nueva.

R-FIN-1a exige monotonicidad de slots únicamente en la arista del padre seleccionado. No deducir
`slot(X)<=slot(B)` para todos los otros padres/ancestros. La consulta anterior debe poder resolver
el descriptor en el slot que realmente pide cada X. Si faltan los eventos o la procedencia
necesarios, devuelve **pendiente**, no una igualdad inventada ni rechazo automático por
«slot mayor». Cualquier otra restricción causal/temporal aplicable se verifica por separado.

R-FIN-14(d) menciona pruebas hasta slots con retardo de autoría D; ese horizonte puede exceder
el slot de la solución. **Compatibilidad a slot(X) no acredita automáticamente esas pruebas.**
Su contexto y horizonte exactos deben validarse aparte. No se rechaza pasado común sólo porque
los descriptores tengan sufijos futuros diferentes; tampoco se reutiliza una prueba que depende
de ese sufijo sin comprobarlo. R-FIN-4 y la composición del horizonte requieren integración,
sin fijar aquí D, L, I, N inicial ni un reloj global (`SPEC.md:1201`, `:1237`, `:1250`).

## 4. ¿Qué ocurre en una fusión y qué puede perder un honesto?

### A. Reto realmente divergente después de la separación

Sean A y B declaraciones de la misma EconomicKey, con `slot(A)=slot(B)=s`, cuyos prefijos PoT
difieren efectivamente en s. Una historia que intente incorporar ambas no pasa el contrato
CompatiblePast derivado de R-FIN-5. No debe llegar a «sumar dos cobros y deduplicarlos después».
Cada declaración puede ser válida en su propia rama; elegir/cambiar rama usa fork choice y undo,
no unión de estados. Es un argumento condicionado a las reglas de compatibilidad, no una
demostración de que nunca surjan dos redes incompatibles ni una regla para curar su partición.

### B. Bloques anteriores a divergencias futuras

Si los prefijos coinciden en s, los sufijos futuros diferentes no impiden por sí solos incorporar
el bloque histórico. La identidad tampoco cambia. Los demás requisitos de admisión y el horizonte
real de cada prueba continúan siendo necesarios. Un test que rechazase estos bloques por
comparar el flow_id de las puntas actuales estaría ensayando otra regla.

### C. Contextos archivados o rangos diferentes con reloj compatible

R-FIN-5, por sí solo, no garantiza igualdad de raíces archivadas o rangos. Si la integración
admite dos declaraciones de la misma coordenada/slot contra esos contextos dentro de una historia,
DAV-D2 les asigna **un solo derecho**, aunque sus chunks difieran. Antes deben verificarse ambas
bajo el contexto que realmente les corresponde; EconomicKey no autoriza validar la segunda
contra la raíz de la primera. Si la integración las excluye, el test no debe inventar su
alcanzabilidad: puede probar sólo la decisión económica con contextos suministrados como oráculo.

### Coste de esta política

Un productor honesto puede trabajar sobre una rama que se abandona; no se le garantiza conservar
su adjudicación en la historia elegida. Si ha servido dos archivos/contextos distintos con la
misma coordenada y slot que llegan a una fusión admisible, esta política tampoco promete dos
pagos por ambos trabajos. **Es una restricción económica deliberada**, no una prueba de que esos
trabajos fueran gratis o maliciosos. La misma advertencia impide afirmar «sólo perjudica al que
equivoca» o «ningún honesto pierde recompensa».

La alternativa de añadir `flow_id`, raíz o rango a EconomicKey puede dar más derechos por
variación de contexto y exigir una recalibración completamente distinta. Se recomienda no hacerlo
en este candidato. Conservar `piece_offset` evita el colapso ya demostrado de declaraciones
distintas por offset, pero no demuestra una correspondencia uno-a-uno con bytes físicos.

## 5. Un cobro no limita el número de ensayos

Para una EconomicKey e, sea A(e) el conjunto de contextos admitidos que el adversario puede
evaluar y P(e,C) sus representaciones PoS válidas. El evento que debe modelarse después es:

```text
existe C en A(e), existe p en P(e,C):
    PoAS(e,p,C) pasa el rango contextual
    y la representación satisface las demás condiciones de admisión a tiempo
```

El registro limita adjudicaciones por e; no limita la cardinalidad de esos conjuntos, su coste
ni su dependencia. La alternativa de flujo puede ser exclusiva para una historia, pero aun así
ser un ensayo entre el que el productor elige antes de publicar. Tampoco son ensayos gratuitos
por definición: cuentan espacio efectivo, reconstrucción, velocidad PoT, retención y transporte.
No se supone independencia, una tasa Poisson ni un factor de ventaja nuevo.

Cambiar pk/sector/history/offset cambia coordenadas y semillas, pero esta derivación no acredita
el recurso adicional necesario. Esa relación sigue pendiente antes de transferir alpha o una
tasa de billetes al modelo de finalidad. Es una obligación distinta de la semántica ya propuesta
para fusionar o reorganizar pagos.

## 6. Fronteras tipadas para el instrumento Rust

Se proponen nombres semánticos, no wire ni tipos de producción adoptados:

| Tipo | Contenido/garantía del constructor |
|---|---|
| `NetworkDomain` | Identificador esperado por la red; no leído como nueva autoridad del bloque. |
| `EconomicKey` | Dominio y coordenadas/slot exactos, tipos enteros comprobados; pk en la representación admitida que usa la derivación del sector. |
| `PotPrefixDescriptor` | Origen y eventos efectivos normalizados; describir no implica verificar procedencia. |
| `ResolvedPotPrefix` | Descriptor cuya procedencia está resuelta por el llamante; el harness debe etiquetar el resolver como oráculo si es sintético. |
| `VerifiedPotEvidence` | Relación exacta de semilla, N, horizonte y checkpoints comprobados; no nace de comparar descriptores. |
| `PoasValidationKey` | Bytes de solución y contexto exactos: reloj, slot, rango, parámetros, raíces, caducidad y versión del verificador. |
| `ValidatedClaim` | Evidencia exigible de PoAS, reloj, envoltorio/autorización y contexto vinculada al candidato; no construible sólo con EconomicKey. |
| `TicketUse` | Derecho, representante, historia y evento contable reversible; no se comparte como consumo entre ramas alternativas. |

Antes de tocar el ledger deben estar resueltas las comprobaciones exigibles de compromiso,
autorización y contexto. La entrega malformada o una prueba auxiliar errónea no consume el derecho
ni invalida otras representaciones. Un positivo de caché tampoco equivale a cuerpo disponible.
El perfil DA0 conserva la obligación sobre cuerpos perdedores. El compromiso de autorización y
la conservación monotónica de evidencia verificada se componen en el contrato principal de esta
etapa; aquí no se inventan sus primitivas (`IDV CONTRATO:80`, `:119`, `:138`).

## 7. Invariantes y vectores de regresión propuestos

Ninguno de estos tests se ha ejecutado en esta subtarea. Los que usen un resolver artificial
demuestran sólo el contrato discreto, no una traza criptográfica DAG alcanzable.

1. **Dominio estable:** bifurcación, inyección, cambio de rango y upgrade de codificación no
   alteran EconomicKey para las mismas coordenadas. Un dominio de otra red no se admite en la
   historia local; no basta tratarlo como otro ticket local pagable.
2. **Equivalencia y conservación de offset:** reflexividad/simetría/transitividad; variar
   prueba/chunk/contexto conserva la clave según D2; variar offset o slot la distingue. No
   transformar la igualdad de claves en validación automática de los bytes mutados.
3. **Prefijo común:** eventos iguales hasta s y diferentes después de s dan compatibilidad en s;
   un evento diferente que activa exactamente en s impide esa igualdad. Permutar anuncios sin
   alterar la secuencia canónica no debe alterar el resultado.
4. **N omitido:** misma etiqueta antigua `(entropía,t)` pero N distinto efectivo en s produce
   descriptores diferentes. Un cambio de N sólo después de s no los distingue en s. Esta prueba
   detecta la insuficiencia de la etiqueta; no genera ni acredita PoT válido por sí sola.
5. **Pasado postdivergencia:** una incorporación que necesita ambos prefijos divergentes en el
   mismo slot queda incompatible antes de adjudicar; pasado predivergencia sigue admisible por
   ese criterio. No comparar etiquetas actuales indiscriminadamente.
6. **Padre no seleccionado adelantado:** el comprobador pregunta por su slot real, sin aplicar
   a todas las aristas la desigualdad de SP. Descriptor no resuelto devuelve pendiente; el test
   no afirma validez integral de ese DAG ni impone un reloj físico nuevo.
7. **Fusión compatible duplicada:** dos claims ya validados de igual EconomicKey, en un lote o
   en fusiones sucesivas, producen un TicketUse y un evento; el segundo no renace con otro
   `PoasValidationKey`. Subsidio cero no libera el derecho.
8. **Cambio de rama:** A cobra e en rama 1; undo restaura el prefijo y rama 2 adjudica e a B.
   El estado final coincide con reproducción limpia de rama 2, no con unión de pagos. Si la
   preparación de rama 2 falla/queda pendiente, no se publica medio cambio.
9. **Evidencia no contagiosa:** una prueba mala de e no bloquea para siempre otra válida; un
   positivo para `(e,C,p)` no valida `(e,C',p')`. Raíz, rango, N o checkpoint distintos deben
   invalidar la reutilización salvo equivalencia expresamente probada.
10. **Coste honesto explícito:** fixture con dos claims de igual coordenada y contextos distintos
    suministrados como admisibles: un solo pago, aun si ambos se etiquetan honestos. Así el test
    impide convertir la política de límite en la afirmación falsa de pagar todo trabajo honesto.

## 8. Cierre documental y pendientes precisos

Queda propuesto de forma accionable: dominio fijo de red; igualdad económica independiente de
reto/raíz/rango; consumo por historia reversible; compatibilidad por prefijo histórico incluyendo
N; separación entre descriptor, verificación y caché; tests que conservan los costes de exclusión.

No se fija calendario, origen de slots, N inicial, actualización de N, I/L/D/F, rango, ventana ni
hash de producción. Para integrar se necesita el resolver causal/autenticado de esos datos y de
la historia archivada, la composición completa de validadores y el orden DAG. Para una garantía
económica/finalidad se necesita además analizar ensayos y recursos, disponibilidad, progreso y
riesgo de historias incompatibles. La igualdad propuesta no sustituye ninguna de esas pruebas.
