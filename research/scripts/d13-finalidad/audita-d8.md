# D8 · Auditoría adversarial de la ronda 13 — los cuatro veredictos de finalidad

**Agente:** D8 · Seguridad / auditoría adversarial · **Fecha:** 2026-09-10
**Encargo:** atacar las conclusiones (no los cálculos; eso es D9) de `f0a-clave-plot.md`,
`f0b-anti-equivocacion.md`, `f1-p040-latencia.md` y `f2-alternativas-latencia.md`.
**Postura:** asumo que cada veredicto es falso hasta que sobrevive al mejor ataque que se me ocurre.
**Restricción:** un solo fichero. No se ha tocado ningún otro fichero del repositorio. No se ha ejecutado git.

**Fuentes primarias usadas (leídas en esta ronda, no de memoria):**

| Fuente | Ruta / versión | Qué se cita |
|---|---|---|
| HotPoW (Keller–Böhme) | `research/fuentes/hotpow.txt` | Def. 1 (`:281-284`), ambigüedad (`:301-304`), voto (`:492-497`) |
| FIP-0086 (F3) | `research/fuentes/fip-0086.md` (1 147 líneas) | época (`:39`), instancia por época (`:54`, `:704`), `+2` (`:183`), umbral (`:65`, `:248`) |
| Lewis-Pye–Roughgarden | `research/fuentes/lewispye-roughgarden-cap.txt` | sized/unsized (`:443-464`), Def. 3.2/3.4 (`:727-741`), Teo. 4.1 (`:759`) |
| Sankagiri et al. CAP | `research/fuentes/cap-adaptividad-finalidad.txt` | híbridos (`:271-285`), doble regla (`:506-545`) |
| DAGKNIGHT | `research/fuentes/dagknight.txt` | confirmación 1,2-12 s (`:182-197`), cota (`:328-352`) |
| Diseño vivo | `research/dag-poas-ancla-de-orden.md` | R-FIN-7 (`:271-273`), R-FIN-11 (`:206-211`), R-FIN-14(f) (`:253`) |
| Capa P-040 | `research/dag-poas-capa-finalidad.md` | R-FIN-15..22 (`:60-133`), números (`:142-258`), lagunas (`:304-319`) |
| Catálogo | `research/dag-poas-catalogo-problemas-ataques.md` | D6 (`:63`), E1 (`:72`) |
| Autonomys | `/home/katana/zeo/fuentes/subspace` @ `f8842d0` | `identity.rs:117-132`, `sectors.rs:54-68` |
| Papers web (consultados hoy) | arXiv:1810.08092 (Prism) · ePrint 2023/463 (Simplex) · arXiv:2310.14821 (Mysticeti) · arXiv:2306.03058 (Shoal) · arXiv:2205.09174 (Cordial Miners) · arXiv:1607.01341 (Algorand) · arXiv:1905.04463 (ataques a Algorand) · ePrint 2017/913 (Thunderella) · docs.sui.io | viabilidad de los mecanismos de §2 |

---

## 0 · Veredictos en una tabla

| # | Veredicto atacado | ¿Sobrevive? | Qué cae y qué queda en pie |
|---|---|---|---|
| 1 | F0a/F0b: «el castigo de espacio no restaura la Def. 1 sin dinero; el quórum está muerto» | **Sí, con alcance recortado** | Sobrevive para el gadget HotPoW (P-043). **Cae si se lee como «ningún quórum sin dinero»**: P-040 es una capa BFT y su argumento de seguridad *sí* tolera equivocadores hasta ⅓. |
| 2 | F1: «~30 s normal, se para bajo ataque, no garantía al 33 %; mínimo 3-7 s con Δ≈1» | **Sí, con una etiqueta corregida** | Los tres ataques de fondo ya están en F1 (69-100 % de parada, fallback 2 h). El «3-7 s DEMOSTRADO» **cae a cota del núcleo BFT**, no de F3: F3 ata instancia y semilla a la época de 30 s (`fip-0086:54, :704`) y arranca a `+2` épocas (`:183`). |
| 3 | F2: «por debajo de 30 s solo hay comités, y todos exigen dinero o conjunto conocido» | **Cae en su forma fuerte** | DAGKNIGHT (1,2-12 s, sin comité, sin dinero) y Prism (latencia ∝ `D`) son sub-minuto **probabilista** sin dinero ni comité; F2 se contradice con su propia fila 3 (`f2:51` vs `f2:314`). Los BFT no «exigen dinero»: exigen un conjunto con peso Sybil-resistente, y el espacio lo da. |
| 4 | Prioridad: «bajar el tiempo de irreversibilidad lo más posible» | **Hay una vía sin ronda** | La más prometedora no explorada: **regla de confirmación adaptativa tipo DAGKNIGHT sobre el DAG de PoAS** (probabilista, sin comité, sin dinero, sin confianza nueva). Coste y alternativas en §5. |

---

## 1 · Los cuatro veredictos, atacados

### 1.1 · F0a/F0b — «castigo de espacio y quórum muerto»

**HALLAZGO:** El veredicto es correcto para el gadget HotPoW de P-043, pero la métrica de equivocación
(`POA` de `1,27e-12` a `0,52`) **no es la métrica de seguridad de un certificado BFT**: el argumento de
intersección de quórums tolera dobles firmas bizantinas mientras el peso del atacante sea `< ⅓`, y ese es
exactamente el umbral que F1 usa (`f1:232-237`, `fip-0086:65, :248`). El informe no separa los dos objetos.
**SEVERIDAD:** menor (documental) / split solo por lectura.
**ESTADO:** SOSPECHA de lectura. El texto de F0b **sí** acota el cierre a P-043 (`f0b:466-468`,
`ENCARGO.md:55-56`) y su §4.2 ya compara con F3 (`f0b:422-440`), de modo que no hay error de texto; lo que
falta es la frase que separa los dos objetos, y sin ella «el quórum está muerto» se lee como «no hay
finalidad rápida sin dinero», que es falso para P-040.
**ESCENARIO:** un lector (o el SPEC) toma «quórum muerto» como «P-040 muerto», cierra las dos y el proyecto
pierde la única vía sin dinero que F1 mide a 25-60 s (`f1:567-570`). El atacante no gana nada; pierde el
proyecto.
**UBICACIÓN:** `f0b:26-35, :463-475`; `ENCARGO.md:55-56`; contraste en `f1:232-237`.
**PRECONDICIÓN:** ninguna (es de encuadre).
**MITIGACIÓN:** añadir una frase al acta: «el `POA` de d12 es la métrica del gadget HotPoW; la seguridad del
certificado BFT de P-040 es la intersección ⅓ y no se ve afectada».

**Los cuatro ataques del encargo, uno a uno:**

- **(a) Castigo sobre la identidad completa, no fragmentable.** Falla. Crear identidad es gratis
  (`identity.rs:117-132`; `f0a:313-315`), plotear escala con bytes y no con claves (`f0a:316-319`), y el
  `SectorId` liga la clave al plot (`sectors.rs:54-68`; `f0a:166-186`), de modo que el atacante racional usa
  una clave por sector y el castigo de un quórum `k` se queda en `k` GiB (`f0a:337-341`). Fragmentar no tiene
  coste criptográfico. **El mejor ataque no tumba el veredicto; solo matiza el «cero»:** abandonar `k` GiB no
  es gratis del todo —reduce el `α` del atacante hasta que replotee, y replotear `k=64` cuesta 74-89 min
  medidos (`f0a:329-331`)—, pero sigue siendo «coste pequeño» y ex-post.
- **(b) Voto ligado al bloque + U2/U3″.** Falla. U2 y U3″ son funciones de `past(B)`
  (`ancla-de-orden.md:206-211`): en una partición cada rama colorea azul su propio billete y **no ve el
  hermano**; la fusión solo decide qué rama pierde. No hay destrucción en ambas ramas. Es el mismo defecto
  que el nullifier (local a la rama, `f0b:181-189`). Y como aportación es profundidad: `λ_v = λ_bloque`
  (`f0b:237-255`), `k` billetes = `k` bloques ≈ `k` segundos; a `α=0,33` el certificado se forja en 194 s
  (`d12-quorum/informe.md:129-153`).
- **(c) Soluciones de plots distintos + nullifier por (solución, instancia).** Falla. Distintos plots no
  impiden reutilizar **las mismas `k` soluciones** en dos valores: la firma es gratis y el valor no entra en
  `verify_solution` (`f0b:369-385`). El nullifier por (solución, instancia) es estado local a la rama: en
  partición cada lado acepta su certificado (`f0b:181-189`). Lewis-Pye Def. 3.4 exige seguridad precisamente
  en el escenario parcialmente síncrono (`lewispye:740-741`).
- **(d) Variante HotPoW «voto = bloque» con más latencia.** Sí recupera `2k` de verdad (`f0b:243-244`),
  pero es exactamente R-FIN-7 con otro nombre: no hay información nueva y la latencia es `k` bloques. No
  rescata el gadget.

**Resultado:** el veredicto **sobrevive** para su alcance; lo que cae es la extensión implícita a P-040.

---

### 1.2 · F1 — «P-040: 30 s, parada bajo ataque, mínimo 3-7 s»

**HALLAZGO:** El «mínimo real 3-7 s» etiquetado DEMOSTRADO (`f1:550`) **no es el mínimo de F3/P-040**:
F3 hace **una sola instancia por época** y saca la semilla del drand de esa época (`fip-0086:54`, `:704`), y
arranca la instancia cuando EC está **`+2` épocas** por delante del último finalizado (`fip-0086:183`). El
propio F1 declara que el arranque en ZEROX «no está definido en R-FIN-15..22» (`f1:376`) y aun así publica
3-7 s como demostrado. Con la regla `+2` y cadencia `c`, el suelo es `2c + T_cons`: 5-9 s a `c=1 s`, 78-84 s
a `c=30 s` (coherente con la fila F3 real de `f1:102`). El número es una **cota inferior del núcleo BFT**
bajo un rediseño no escrito, no una propiedad de la capa.
**SEVERIDAD:** menor (etiqueta) / material si el SPEC escribe 3-7 s como suelo.
**ESTADO:** CONFIRMADO.
**ESCENARIO:** se especifica R-FIN-15..22 «con cadencia 5 s» copiando el `+2` de F3 y la latencia real es
15-25 s, no 5-20 s; la promesa publicada no se cumple.
**UBICACIÓN:** `f1:100-126, :376, :550`; `fip-0086:54, :183, :704`.
**PRECONDICIÓN:** ninguna.
**MITIGACIÓN:** etiquetar el 3-7 s como cota del núcleo BFT **condicionada a** (i) regla de arranque de
instancia, (ii) fuente de aleatoriedad por instancia, (iii) gossip medido (`f1:479-483`). F3 obtiene (ii) de
drand por época (`fip-0086:704`); P-040 la obtiene de la entropía del ancla (R-FIN-16), que cambia por
inyección (`I = 4 200 s`, `ancla-de-orden.md:156`) — la frescura/antigrinding de esa semilla es el ataque
de *steering* de R-FIN-14, no una propiedad gratuita.

**Los cuatro ataques del encargo:**

- **¿El 41 % es peor con la `m` real?** No tumba nada: F1 **ya lo dice** — 32,4 % con `m=1`, 69,2 % con
  `m=2,955`, 100 % con la cota `m=151` (`f1:190-197, :257`), y 340 999 paradas/año a `α=0,33` (`f1:207`).
  F1 es más pesimista que la ficha del catálogo, no menos.
- **¿El fallback de 2 h rompe la promesa justo cuando importa?** F1 ya lo dice: la garantía publicable es
  «2 h hasta que el ataque cese», y con `m=151` «la capa no vuelve» (`f1:219-221, :571-573`). Matiz que falta
  en los cuatro informes: R-FIN-18 (`capa-finalidad:90-97`) hace **permanentes** los prefijos ya
  certificados; lo que se degrada a 2 h son los bloques **nuevos**, no la finalidad ya emitida. Conviene
  decirlo así para no vender un retroceso que la regla no permite.
- **¿Supuesto de sincronía escondido (CAP de Lewis-Pye)?** **Parcialmente sí.** F1 no cita nunca a
  Lewis-Pye (`f1` no contiene «CAP», «Lewis» ni «adaptiv»). El análisis de F1 vive en el **sized setting**
  (`lewispye:443-464`): el `α` es el de la **tabla**, no el de la red viva; espacio nuevo que entra después
  del snapshot `W_POWER = 3 600 s` no está en la tabla y no lo cubre la garantía. Además, el comité de
  R-FIN-16 es **público y determinista** (`capa-finalidad:71-75`): el adversario sabe a quién atacar, cosa
  que F3 no sufre igual porque su comité son actores registrados con PoSt. Y `K_eff ≈ 40` (`f1:334-351`)
  ensancha la cola de viveza muy por encima de la tabla exacta de `f1:299-306`.
- **La parada del 41 %:** cubierta arriba; F1 ya la corrige a peor.

**Resultado:** el veredicto **sobrevive**; cae la etiqueta DEMOSTRADO del mínimo y falta declarar el sized
setting y la targetabilidad del comité.

---

### 1.3 · F2 — «por debajo de 30 s solo hay comités, y todos exigen dinero o conjunto conocido»

**HALLAZGO:** La fila de veredicto «**Sub-minuto sin dinero y sin comité: no existe en la literatura
revisada; el CAP lo impide en una sola regla — REFUTADO**» (`f2:314`) es **falsa tal como está escrita**:
DAGKNIGHT confirma en 1,2-12 s en sus simulaciones sin comité y sin dinero (`f2:51`; `dagknight.txt:182-197`),
y Prism reclama latencia de confirmación proporcional a `D` con error `exp(-CD)` sin comité y sin dinero
(arXiv:1810.08092, abstract). F2 lo sabe y se contradice: `f2:61` dice «la 3 no tiene comité pero está sin
adaptar». Lo correcto es **«no existe sub-minuto *determinista* sin comité y sin dinero»**; probabilista sí.
**SEVERIDAD:** menor (documental), pero decide la pregunta 4: si existe una vía probabilista sin comité, el
«solo P-040» deja de ser el único candidato.
**ESTADO:** CONFIRMADO contra fuente primaria.
**ESCENARIO:** se cierra la ronda de alternativas porque «no existe nada» y no se explora DAGKNIGHT/Prism.
**UBICACIÓN:** `f2:23-25, :51, :61, :256, :287-299, :314`; `dagknight.txt:182-197`; arXiv:1810.08092.
**PRECONDICIÓN:** ninguna.
**MITIGACIÓN:** corregir el veredicto a «determinista» y abrir la ronda de §5.

**HALLAZGO 2:** «todos exigen dinero» (`f2:49, :173-185`) es un **error de categoría**. Los protocolos BFT
no exigen dinero: exigen un **conjunto con peso Sybil-resistente**. Simplex solo asume PKI + líder aleatorio
(ePrint 2023/463, abstract); Algorand BA* se describe «only as a money platform» (arXiv:1607.01341,
abstract), pero el peso puede salir de la tabla de espacio R-FIN-15, que es exactamente lo que P-040 ya
construye (`capa-finalidad:52-65`); Mysticeti (arXiv:2310.14821) y Shoal (arXiv:2306.03058) exigen
validadores conocidos —Sui los tiene con stake, `docs.sui.io`—, no dinero en el protocolo; Cordial Miners
asume un conjunto `Π` de `n` mineros con claves conocidas (arXiv:2205.09174 §2). El «conjunto conocido» que
F2 usa para descartarlos es **lo que P-040 construye**. Lo que ninguno arregla es el ataque a la tabla
(D8 pendiente, `capa-finalidad:323-325`).
**SEVERIDAD:** menor (documental, pero decide qué motores se estudian).
**ESTADO:** CONFIRMADO.
**ESCENARIO:** se descartan Simplex/BA*/Cordial Miners «porque exigen dinero» y P-040 se queda con el motor
GossiPBFT sin comparar; si GossiPBFT no se porta (laguna de la propuesta), no hay plan B de motor.
**UBICACIÓN:** `f2:49, :173-185`.
**PRECONDICIÓN:** ninguna.
**MITIGACIÓN:** reescribir la fila como «exigen un conjunto conocido con peso Sybil-resistente; el peso
puede salir de R-FIN-15», y añadir a la ronda de P-040 la comparación de motores (Simplex vs BA* vs
GossiPBFT).

**Resultado:** el veredicto **cae en su forma fuerte**; sobrevive la parte determinista y la conclusión
«ningún motor elimina el problema de la tabla».

---

### 1.4 · La prioridad (bajar irreversibilidad) — ¿ronda que falta?

Ver §5. Resumen: la vía no explorada más prometedora es la **regla de confirmación adaptativa tipo
DAGKNIGHT sobre el DAG de PoAS**, que ataca el suelo de 100-134 s (`catalogo:63`, D6) sin comité, sin
dinero y sin confianza nueva. F2 la menciona como LAGUNA (`f2:51, :152-153`) pero **no propone ronda**;
ningún informe evalúa su encaje con R-FIN-5 (flujo), R-FIN-6 (k-cluster) ni R-FIN-14 (reto secuencial).

---

## 2 · Mecanismos que F2 no cubrió (o cubrió mal), con viabilidad

| Mecanismo | ¿Exige dinero? | ¿Exige conjunto conocido? | ¿Derivable del espacio? | Latencia | Viabilidad en ZEROX | Fuente |
|---|---|---|---|---|---|---|
| **DAGKNIGHT** | **No** | **No** | Es regla de orden, no comité | 1,2-12 s (simulación `λ=3,75`, `α=0,2`, `D≤2 s`) | **Media**: sustituye R-FIN-6 y hay que re-derivar con `λ=1`, `α=0,33`, `Δ` real y R-FIN-5 | `dagknight.txt:182-197, :328-352`; ya en `f2:51` |
| **Prism** | **No** (PoW) | **No** | Sí, por recurso (PoW→espacio) | ∝ `D`, error `exp(-CD)` | **Baja-media**: exige rediseñar la regla de orden (cadenas proponente/votante); probabilista | arXiv:1810.08092, abstract; F2 lo despacha en `f2:256` |
| **Algorand BA\*** | No en el protocolo; Algorand lo instancia con stake | Sí (PKI + pesos) | **Sí**: peso por tabla R-FIN-15 | 1 bloque / segundos | **Media-alta** como motor de P-040: sortición **secreta por paso** (VRF) ataca la targetabilidad de R-FIN-16; sigue el umbral ⅓; ojo: ataques a Algorand con `<⅓` | arXiv:1607.01341; arXiv:1905.04463 |
| **Mysticeti-C (Sui)** | No en el núcleo; Sui valida con DPoS | Sí (validadores con slot/ronda) | No directo: el DAG de PoAS no tiene rondas por validador | 3 rondas, 0,5 s WAN | **Baja-media**: requiere mapear la tabla a validadores con slot propio | arXiv:2310.14821; `docs.sui.io` |
| **Simplex** | **No** | Sí (PKI) | **Sí**, con la tabla de espacio | 3 rondas (óptimo good-case) | **Media-alta**: más simple que GossiPBFT, misma clase de supuestos | ePrint 2023/463, abstract |
| **Shoal / Shoal++** | No en el protocolo | Sí (Narwhal/Bullshark) | Difícil (DAG por validador) | 4,5 intercambios medios (Shoal++) | **Baja**: exige DAG estilo Narwhal | arXiv:2306.03058; arXiv:2405.20488 |
| **Cordial Miners** | **No** | Sí (`n` mineros conocidos) | Sí, si el peso sale de la tabla | 3 rondas good-case, 4,5 esperadas (ES) | **Media** como motor BFT; sin RB | arXiv:2205.09174, abstract y §2 |
| **Thunderella** | **No** (permisionless con PoW) | No (acelerador elegido de la cadena) | Sí, por recurso | «tan rápido como el retardo real» en el camino optimista | **Baja**: el camino rápido exige **3/4 honestos**; ZEROX publica 67 % honesto (33 % atacante) | ePrint 2017/913, abstract |
| **Comité derivado del espacio sin stake** | **No** | Sí (tabla derivada) | Es P-040 | — | **Alta** (es la propuesta viva) | `capa-finalidad:52-88`; Filecoin F3 usa QAP pero con pledge, `fip-0086:12-16` |

**Lectura adversarial.** Ninguno de los ocho da un mecanismo **nuevo** sin el problema de la tabla; lo que
dan es **motores** para la tabla que P-040 ya tiene, con dos ventajas potenciales reales: (i) Algorand BA\*
sortea comité **secreto por paso** y con «player replaceability», lo que ataca la targetabilidad y la
recuperación de P-040 (una instancia parada no espera 44-97 s: el siguiente paso tiene otro comité); (ii)
Simplex/Cordial Miners tienen latencias good-case de 3 rondas con protocolos más simples de portar y
auditar que GossiPBFT. Y uno —DAGKNIGHT— no necesita tabla.

---

## 3 · Supuestos ocultos que faltan en los informes

**En F0a/F0b**

1. **Los dos «quórums» son objetos distintos.** El de d12/F0 es el gadget HotPoW (votos = soluciones, sin
   rondas BFT); el de P-040 es un certificado BFT (peso = plazas, intersección ⅓). El veredicto no lo dice
   y puede cerrar los dos. (`f0b:26-35, :463-475` vs `f1:232-237`.)
2. **«Coste cero» al abandonar es una exageración.** Abandonar `k` GiB reduce el espacio del atacante
   (y con él su `α`) hasta que replotee; el coste es el reploteo medido o la pérdida de cuota
   (`f0a:337-341`). La conclusión «coste pequeño» aguanta; «cero», no.
3. **El castigo de espacio se evalúa con hardware nuestro, no del atacante** (`f0a:324-334`): la
   extrapolación de GPU 2026 (4,3-9,9 s/GiB) es un rango de 2,3×. No cambia el veredicto.

**En F1**

4. **Instancia y semilla atadas a la época** (`fip-0086:54, :704`) y **arranque `+2`** (`fip-0086:183`):
   no están en el mínimo de 3-7 s ni en la tabla de cadencia (`f1:100-126`). Es el hueco mayor del informe.
5. **Sized setting.** El `α` de la garantía es el de la **tabla** (`W_POWER = 3 600 s`), no el de la red
   viva; el teorema de Lewis-Pye que F2 cita (`lewispye:443-464`) nunca se aplica en F1. Espacio que entra
   después del snapshot queda fuera de la garantía.
6. **Comité público y determinista** (`capa-finalidad:71-75`): R-FIN-16 no oculta la selección; un
   adversario de red puede DoSear a los firmantes de la instancia. F1 no modela DoS dirigido.
7. **`K_eff ≈ 40`** (`f1:334-351`) hace que la tabla exacta de viveza (`f1:299-306`) sea optimista; F1 lo
   etiqueta PLAUSIBLE, pero la tabla de veredicto (`f1:553`) usa los números optimistas.
8. **El fallback no es independiente del ataque:** R-FIN-7 se degrada si `Δ` sube (frontera 38,3 % a 16 s,
   32,4 % a 20 s, `f1:398-406`); con `Δ` alto, ni la capa ni el suelo aguantan el 33 %.
9. **El coste de gossip (3,5 TB/año) es una estimación de orden**, no una medida (`f1:479-483`), y el
   certificado de 724 B no es el coste del protocolo que lo produce. F1 lo dice; el veredicto de cadencia
   (10-30 s) hereda la incertidumbre.
10. **Rogue-key de BLS:** sin BDN/PoP, la firma agregada es forjable; R-FIN-20 es un registro de claves
    (`f1:463-467`). F1 lo declara, pero la propuesta no lo ha incorporado.

**En F2**

11. **«Dinero» vs «resistencia Sybil»**: conflación en la fila 1 (`f2:49`) y en el veredicto (`f2:310`).
12. **Contradicción interna** entre `f2:51/61` (DAGKNIGHT sub-minuto sin comité) y `f2:314` («no existe»).
13. **Prism despachado sin leer su tesis de latencia** (`f2:256` vs arXiv:1810.08092).
14. **Nadie mide la latencia de un motor BFT sobre la tabla de espacio**: los «~30 s» son cadencia
    asumida, no consenso medido (lo dice F1, pero F2 lo usa como si fuera un dato).

**Global a los cuatro**

15. **El usuario no está modelado.** Toda la irreversibilidad se mide desde un nodo que ve la cadena
    honesta; un eclipse del comerciante (Heilman 2015, en `research/fuentes/`) no entra en ninguna tabla.
16. **El atacante de la tabla** (D8 pendiente, `capa-finalidad:323-325`) queda fuera de los cuatro
    informes; sin cerrarlo, ninguna cifra de seguridad de P-040 es publicable.

---

## 4 · El mejor ataque contra cada conclusión (y si derriba algo)

| Conclusión | Mejor ataque | Resultado |
|---|---|---|
| **F0**: «el castigo de espacio no restaura la Def. 1 sin dinero; quórum muerto» | **Alcance**: la equivocación gratis es del gadget HotPoW; el certificado BFT tolera equivocadores hasta ⅓ (`f1:232-237`). Secundario: el castigo sobre identidad es evadible porque fragmentar es gratis (`f0a:313-319`) y U2/U3″ son locales a la rama (`ancla-de-orden.md:206-211`). | **No derriba el veredicto de P-043**; derriba su extensión implícita a P-040. |
| **F1**: «30 s normal, se para bajo ataque, mínimo 3-7 s» | **Acoplamiento estructural**: una instancia por época + semilla drand por época (`fip-0086:54, :704`) + arranque `+2` (`:183`); F1 mismo declara el arranque indefinido (`f1:376`). | **Derriba la etiqueta DEMOSTRADO** del 3-7 s (pasa a cota condicionada del núcleo BFT). El resto del veredicto sobrevive intacto. |
| **F2**: «sub-minuto solo comités; todos con dinero o conjunto conocido» | **DAGKNIGHT y Prism**: sub-minuto probabilista sin comité y sin dinero (`dagknight.txt:182-197`; arXiv:1810.08092). Y los BFT exigen peso Sybil-resistente, no dinero (ePrint 2023/463; arXiv:1607.01341; arXiv:2310.14821; arXiv:2306.03058; arXiv:2205.09174). | **Derriba la forma fuerte del veredicto**; sobrevive «no hay sub-minuto determinista sin comité ni dinero» y «ningún motor elimina la tabla». |
| **Prioridad**: «bajar la irreversibilidad» | **Falta la ronda DAGKNIGHT**: es el único candidato que ataca el suelo de 100-134 s sin comité, sin dinero y sin confianza nueva, y F2 lo deja en LAGUNA sin plan (`f2:152-153`). | **Abre ronda**; §5 con coste. |

---

## 5 · La vía que falta: ronda sobre confirmación adaptativa (DAGKNIGHT) sobre el DAG de PoAS

**Por qué es la más prometedora.** La prioridad es el tiempo. Los tres candidatos sin dinero son:

1. **DAGKNIGHT sobre PoAS.** Reemplaza el `k` fijo de GHOSTDAG (`k = 25`, `ancla-de-orden.md:268-269`)
   por un `k` elegido en cada momento según el DAG, con confirmación `O((ln(1/ε)/λ + D)/(1−2α) + D²λ)`
   (`dagknight.txt:328-352`). En su simulación (`λ = 3,75`, `α = 0,2`, `D ≤ 2 s`, `ε = 0,05`) confirma en
   1,2-12 s (`dagknight.txt:182-197`). Con `λ = 1`, `α = 0,33`, el término `1/(1−2α)` se multiplica ×1,7 y
   `ln(1/ε)/λ` pesa más; una cuenta de orden da **~12-20 s**, aún por debajo de los 30 s de P-040 y sin
   comité, sin dinero y sin confianza en un operador. **Coste:** sustituir la regla de orden R-FIN-6 y
   re-derivar el suelo de 3k (`catalogo:63`, D6), la frontera de flujo único (`catalogo:36`), R-FIN-7/F y
   la interacción con R-FIN-5 (un bloque no referencia otro flujo) y R-FIN-14 (reto secuencial por slot).
   Riesgo: DAGKNIGHT no es responsivo en sentido estricto (se ajusta a la latencia adversarial máxima,
   `f2:143-144`), y su confirmación es **por cliente** (`D` lo fija el cliente, `dagknight.txt:328-352`),
   no un certificado de protocolo. Haría falta: portar la regla, simularla con el instrumento de D9-f,
   medir con `Δ` real (E1, `catalogo:72`) y decidir si convive con R-FIN-7 o lo sustituye.
2. **Algorand BA\* sobre la tabla de espacio.** Cambia GossiPBFT por BA\* con sortición **secreta por
   paso**: ataca la targetabilidad del comité público de R-FIN-16 y la recuperación lenta (cada paso tiene
   comité nuevo). Coste: VRF y análisis de umbral con la tabla; el umbral de seguridad sigue siendo ⅓; hay
   ataques publicados con `<⅓` (`arXiv:1905.04463`). No baja de ~1-3 s por paso, pero puede bajar la
   *recuperación* de 44-97 s a un paso.
3. **Finalidad anclada al PoT/VDF.** Usar las inyecciones de entropía (R-FIN-14) como compromiso
   secuencial: un bloque incluido en el chunk inyectado no se puede reescribir sin repetir el VDF. Es la
   única vía que da finalidad **determinista** sin comité ni dinero, pero (i) exige confiar en el timelord
   (Katana lo opera, pero el diseño no lo usa como autoridad), (ii) su suelo es `I ≥ ρ_max·W_dec`
   (`ancla-de-orden.md:253`), ≈112,5 s con `ρ_max=2,5` y `W_dec=45 s`, peor que P-040; (iii) con `ρ>1` se
   rompe. No la recomiendo para latencia; sí como red de seguridad determinista si el timelord se
   profesionaliza.

**Recomendación (D8, adversarial):** abrir ronda para (1) **antes** de gastar más en P-040, porque (1) no
depende de la tabla y ataca el suelo estructural; (2) como plan B de motor si (1) no encaja con el flujo
PoT; (3) solo si Katana acepta la confianza en el timelord como autoridad de finalidad.

---

## ATAQUES PROBADOS Y DESCARTADOS

- **Fragmentación de identidad gratis:** intenté tumbar F0a con «la identidad no se puede fragmentar
  barata». Falla: `Identity::create` es 32 bytes aleatorios sin registro (`identity.rs:117-132`) y el
  trabajo de ploteo por sector es el mismo (`f0a:313-319`).
- **U2/U3″ destruye el billete en ambas ramas:** falla; U2/U3″ son funciones de `past(B)` y no ven la rama
  hermana (`ancla-de-orden.md:206-211`; `f0b:181-189`).
- **Nullifier por (solución, instancia) con plots distintos:** falla por localidad a la rama; el mismo
  conjunto de `k` soluciones firma ambos valores (`f0b:369-385`).
- **Voto = bloque recupera `2k`:** es cierto pero es profundidad; `λ_v = λ_bloque` (`f0b:237-255`).
- **El 41 % es peor con `m` real:** no derriba F1; F1 ya publica 69-100 % (`f1:190-197`).
- **El fallback 2 h rompe la promesa:** no derriba F1; ya está en `f1:219-221`; solo falta precisar que
  R-FIN-18 mantiene permanente lo ya certificado.
- **Sincronía escondida en F1:** no derriba los números; sí falta declarar el sized setting
  (`lewispye:443-464`) y la targetabilidad del comité público.
- **Prism es solo throughput:** descartado como objeción: su abstract reclama latencia ∝ `D` (arXiv:1810.08092).
- **Thunderella da camino rápido sin dinero:** cierto, pero exige 3/4 honestos (ePrint 2017/913) y ZEROX
  publica 67 %; no encaja al umbral 33 %.

## NO PUDE ANALIZAR

- **Prueba formal del teorema general de imposibilidad con equivocación** (F0b laguna 1): no existe modelo
  local; sigo sin poder elevarlo de PLAUSIBLE a DEMOSTRADO.
- **Ataque concreto de doble finalidad en GossiPBFT con `A ≥ ⅓K`** (F1 laguna, `f1:250-251, :262`): haría
  falta portar GossiPBFT entero; no se ha hecho aquí.
- **Latencia real de DAGKNIGHT a `λ = 1`, `α = 0,33`**: solo tengo la simulación del paper a `λ = 3,75`,
  `α = 0,2` (`dagknight.txt:182-197`); mi ~12-20 s es cuenta de orden, no medida. Es exactamente lo que la
  ronda propuesta en §5 debe medir.
- **¿Exige Sui slashing además de stake para Mysticeti?** Leí `docs.sui.io` (DPoS, slashing de rewards por
  tallying), pero no verifiqué el efecto sobre la seguridad del protocolo; queda como sospecha.
- **Paper de Avalanche**: sigue sin fuente primaria local; F0b y F2 lo dejan en LAGUNA y yo no lo cierro.

## Errores propios y correcciones

1. Empecé a buscar el arXiv de Prism en `1809.09044`, que es de *fraud proofs*; el correcto es
   `1810.08092`. Corregido antes de citarlo.
2. Busqué «Simplex Consensus» y «Cordial Miners» en arXiv con títulos inexactos; las referencias válidas
   son ePrint 2023/463 y arXiv:2205.09174. Anotado para que nadie repita la búsqueda.
3. Casi doy por bueno que Cordial Miners era permissionless con PoW: el §2 del paper asume un conjunto
   `Π` de `n` mineros conocidos. Corregido: es conjunto conocido, no permissionless.
4. Mi primera lectura de F2 fue «exige dinero = exige comité»; el paper de Simplex (PKI + líder aleatorio)
   me obligó a separar **protocolo** de **resistencia Sybil**. Es la corrección que da forma a §2.

## Anexo · Salida de `AUDITA_SCRIPTS.py` sobre `research/scripts/d13-finalidad/`

```
$ python3 research/scripts/AUDITA_SCRIPTS.py research/scripts/d13-finalidad/
Scripts analizados: 1

======================================================================
Sospechas totales: 0
```

*(Único script presente: `verifica_d13.py`, de la ronda; sin marcas. No se crearon scripts nuevos en esta
auditoría: la restricción de entrega es un solo fichero.)*
