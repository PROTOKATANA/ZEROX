# CONTRATO-AUSENCIA-v0 — Sorteo verificable después y falta «elegido sin voto»

**Orden:** AV-1. **Ejecutor:** subagente Sonnet (diseño y análisis; sin código de producto; cálculos
en Julia). **Fecha:** 2026-09-26. **Estado:** propuesta ratificable, **no normativa** hasta que el
director la apruebe y Katana la ratifique. Extiende `resultados-FV1/CONTRATO-FINALIDAD-VOTOS-v0.md`
(en adelante «FV-1») y reutiliza el patrón de `P-ZRX/P-SLASHING/CONTRATO-EVIDENCIA-v0.md` (en
adelante «SL-1») para la falta y su evidencia. Convierte la decisión de Katana de
`P-ZRX/P-AUSENCIA-VOTO/PROGRAMA.md` («Decisiones de Katana») en reglas precisas, sin fijar
parámetros de producción.

Etiquetas: **[P]** fuente primaria leída en esta ejecución · **[S]** fuente secundaria ·
**[D]** derivación propia (con la cuenta hecha en `INFORME.md` o aquí mismo) · **[H]** hipótesis de
diseño de este contrato, no probada.

---

## 0 · Qué no se reabre

Por mandato de `ORDEN-AV1-DISENO.md` §3 y de las decisiones FV-D03/FV-D04/FV-D05 de
`P-ZRX/P-FINALIDAD-VOTOS/DECISIONES.md` **[P]**:

- Quien sale elegido y no vota **pierde la prima `b` durante un tiempo** y **se le confisca una
  cantidad `m_aus`**. Los fallos propios (apagón, corte de red, PC apagado) se pagan: es un coste
  aceptado conscientemente. Los falsos positivos provocados por el atacante **no** se aceptan y
  necesitan defensa (condición (c) de la pregunta falsable, §2 de la orden).
- **Alcance (i), decidido por Katana:** paga **todo** elegido que no vota, tenga prima o no. **No hay
  retirada del sorteo:** todos los registrados con garantía activa están siempre en él (FV-04); la
  única salida es dejar de estar registrado, lo que también quita el derecho a producir.
- **`b = 2`** (FV-D05). **Cantidad fija por incidente, sin castigo correlacionado** (DS-5, `DS-L02`,
  extendido aquí a la falta de ausencia, AV-08). **R3 no cambia:** la cadena nunca espera a los
  votantes; sin quórum, la finalidad solo se pausa (FV-20). El mandato (`AUTO-ZRX.md` §91/§102) exige
  semántica y tasa de falsos positivos demostradas antes de activar cualquier castigo por ausencia;
  este contrato las entrega, la activación sigue necesitando la ratificación de Katana.

---

## 1 · Sorteo secreto y verificable después

### 1.1 · El problema exacto, antes de evaluar esquemas

**AV-01 · Por qué (a) y (b) no son gratis a la vez — la tensión real.** El sorteo de FV-06 usa una
VRF: `output_n, proof_n = VRF_prove_sk(entrada_n)`, con `entrada_n` **pública** (función de
`past(A_n)`, FV-06 **[P]**). La secrecía de (a) («nadie salvo el granjero sabe si ha salido
elegido») no viene de ningún compromiso: viene, simplemente, de que **solo quien tiene `sk` puede
calcular `proof_n`**. Para que cualquiera pueda verificar después (condición (b)), el propio
granjero tiene que **publicar** `proof_n` en algún momento. Un granjero racional que salió elegido
y no votó tiene un incentivo directo a **no publicar nunca** ese `proof_n` concreto, y nadie más
puede calcularlo por él. **Consecuencia: ninguna primitiva puramente criptográfica hace (b)
determinista contra un granjero que se niega a publicar; hace falta una regla de consenso que
vuelva la no publicación estrictamente peor que publicar** (exactamente lo que pide el mandato §4.A
de la orden: «no publicar nunca puede salirle mejor que publicar»). **[D]**, derivación de la
propiedad de unicidad de la VRF (RFC 9381 §3.1 **[P]**: «uniqueness means that... it is infeasible
to find proofs for more than one VRF output beta» — nadie más puede fabricar un `proof_n` distinto
que verifique, y nadie más puede calcular el legítimo sin `sk`).

**AV-02 · Por qué un compromiso Merkle por sí solo tampoco basta.** El esquema C de la orden
(«el granjero compromete con una raíz de Merkle sus salidas VRF de la ventana; al votar abre solo la
hoja de esa ronda; después se auditan hojas pasadas al azar») **no cierra AV-01**: comprometerse a
una raíz fija los *valores*, pero no obliga a *abrirlos*. Un granjero puede comprometerse
honestamente y luego, para las hojas que le delatan, simplemente no responder a la auditoría. Con
auditoría **aleatoria** (no total), la detección de una ausencia suelta es **probabilística**, no
la demostración «cualquiera puede demostrar» que pide (b) literalmente. **Esto es un hallazgo de
esta ejecución**, no estaba señalado en la orden con esta precisión (la orden pide «dar la
probabilidad de detectar ausencias sistemáticas frente a ausencias sueltas», asumiendo que la
auditoría aleatoria es la vía; este contrato muestra que esa vía, sola, deja (b) incompleta y
propone una vía distinta, sin descartar la auditoría como capa adicional de detección temprana).
**[D]**.

**AV-03 · La solución: revelación total obligatoria, forzada económicamente, no criptográficamente.**
Se separa el problema en dos capas independientes, análogas a la distinción del mandato «suspensión
de elegibilidad» vs. «confiscación» (`AUTO-ZRX.md` §91 **[P]**):

- **Capa 1 (mecánica, sin juicio de valor, verificable con datos públicos):** cada clave registrada
  se compromete, al empezar una ventana `W` (símbolo, distinta de la ventana de FV-05), con una raíz
  de Merkle de `N_ventana` hojas, una por instancia de la ventana (AV-05). Debe **revelar las
  `N_ventana` hojas completas** (no solo las que le convienen) antes de un plazo `W_reveal` tras el
  cierre de la ventana. Si no lo hace, queda **suspendida** (excluida del sorteo, AV-06) hasta que lo
  haga — consecuencia **sin confiscación**, puramente mecánica, análoga a `ErrCasoAbierto` de SL-1
  (EV-24). Esto resuelve AV-01/AV-02: no revelar deja de ser «gratis», porque cuesta la elegibilidad
  futura completa (peso × 0 mientras dure la suspensión), no solo la prima.
- **Capa 2 (la falta de Katana, con evidencia pública, análoga a SL-1):** una vez reveladas las
  `N_ventana` hojas (voluntariamente o forzado por la suspensión de la capa 1), se comparan contra
  los votos efectivamente registrados en la cadena para esas instancias (FV-11). Si una hoja indica
  «elegido» y no hay voto válido de esa clave para esa instancia (ni siquiera por la vía de gracia de
  AV-11), se activa la falta AV-1: pérdida de la prima `b` durante `D_prima` y confiscación de
  `m_aus` (§3). **[D]**, siguiendo el patrón de `AUTO-ZRX.md` §91: «mantén la suspensión de
  elegibilidad y la confiscación como consecuencias distintas».

**Por qué esto sí cumple (b) literalmente y sin depender de la buena fe del granjero:** la
revelación de la capa 1 es una condición **de todo o nada, mecánica**: o revela las `N_ventana`
hojas completas (y entonces la capa 2 puede aplicarse con evidencia pública, exactamente igual que
un `EvidenceTx` de SL-1), o queda suspendido indefinidamente hasta hacerlo, lo cual es
estrictamente peor que revelar y aceptar el peor caso de la capa 2 (una confiscación fija y pequeña,
frente a la pérdida de TODA la elegibilidad futura). **No hay una tercera opción racional.**

### 1.2 · Los cuatro esquemas de la orden, evaluados

**AV-04 · Esquema 1 — publicación completa continua.** El granjero publica, tras el cierre de la
votación de cada instancia, la prueba VRF de esa instancia (elegido o no), en una transacción propia.

- Datos: 1 prueba ECVRF (80 B, RFC 9381 §5.1 **[P]**, ver AV-14) + cabecera mínima de transacción
  por instancia. Coste por granjero y día: `instancias_día × (80 B + overhead_tx)` (calc `C1`).
- Secreto: se pierde por instancia, justo después de que su ventana de voto cierra — cumple (a)
  literalmente para *esa* instancia, pero exige una transacción en cadena por cada instancia de vida
  del granjero, incluidas las no elegidas: **coste innecesariamente alto** si `T_instancia` es corta.
- Qué pasa si no publica: nada lo obliga; sin una capa de suspensión-por-omisión externa (como AV-03),
  este esquema por sí solo **no** cierra AV-01. **Se adopta solo como building block** (la prueba en
  sí), no como mecanismo de forzado.

**AV-05 · Esquema 2 — VRF por ventana, revelada al final. DESCARTADO en su forma literal, adoptado
en una variante con entradas independientes.**

- **Forma literal (una sola evaluación VRF por ventana, subdividida por expansión de hash pública en
  `N_ventana` decisiones):** esto **filtra el calendario de la ventana en cuanto el granjero vota una
  sola vez dentro de ella**. Si `entrada_ventana` es el único insumo VRF de toda la ventana y las
  `N_ventana` decisiones se derivan de `output_ventana` por una función pública (`H(output_ventana,
  i)`), entonces **revelar `proof_ventana` para votar en la instancia `i` revela `output_ventana`
  entero**, y con él, **todas** las decisiones futuras de esa misma ventana para esa clave — exponiendo
  al granjero a censura selectiva instantánea del resto de su calendario (el propio atacante que
  observa el voto sabe, a partir de ese momento, en qué instancias futuras de la ventana volverá a
  salir elegido, y puede censurarlo con precisión). **Esto es peor que el statu quo** (sin esta capa,
  nadie sabe el calendario futuro de nadie) y se **descarta**. **[D]**, no señalado por la orden con
  esta precisión: la orden solo pedía «decir cuánto secreto se pierde al votar»; la respuesta es
  «todo el resto de la ventana, con una sola VRF compartida».
- **Variante independiente (adoptada, se convierte en la base del esquema 3):** si en vez de una VRF
  por ventana se usan `N_ventana` VRF **independientes**, una por instancia, con entrada
  `entrada_ventana_i = H_d("ZZKSorteoAvI____", seed_ventana ‖ i)` (donde `seed_ventana` es pública y
  fija al empezar la ventana, p. ej. `hash_tabla_pesos` del bloque de apertura), revelar `proof_i`
  para votar en la instancia `i` **no** revela nada sobre `output_j` de otra instancia `j` de la
  misma ventana. **[P]**, por la propiedad de «pseudoaleatoriedad completa» de una VRF, RFC 9381 §3.4:
  «the "full pseudorandomness" security property holds even against an adversary who is allowed to
  choose the target VRF input... even after it observes VRF outputs β′ and proofs π′ on a variety of
  chosen inputs α′» — exactamente la garantía que hace falta: ver `(entrada_i, output_i, proof_i)` no
  ayuda a predecir `output_j` para `j ≠ i`. Este es el diseño que AV-1 recomienda (§1.3).

**AV-06 · Esquema 3 — compromiso Merkle con auditoría aleatoria. Adoptado con una modificación: la
auditoría aleatoria se sustituye por revelación total obligatoria (AV-03), y se conserva como capa
de detección temprana opcional, no como mecanismo de cierre de (b).**

- El granjero publica, al abrir la ventana, la raíz de Merkle de las `N_ventana` hojas
  `H(output_i)` (con las entradas independientes de AV-05). Al votar en la instancia `i`, abre esa
  hoja junto con su voto (coste marginal ≈ 0: la prueba ya viaja con el voto, FV-06). Al cerrar la
  ventana, revela **todas** las hojas no abiertas todavía (AV-03), no solo una muestra.
- **Probabilidad de detectar ausencias sistemáticas frente a sueltas, con auditoría aleatoria de
  fracción `p_aud` (si se usa como capa adicional, no como único mecanismo):** para un granjero que
  fue elegido y silencioso en exactamente `j` de las `N_ventana` instancias, la probabilidad de que
  la auditoría no capture **ninguna** de esas `j` es `(1-p_aud)^j` (muestreo sin reemplazo aproximado
  por binomial para `N_ventana` grande). Una ausencia **sistemática** (`j` grande, un patrón de
  desconexión repetida) se detecta con probabilidad `1-(1-p_aud)^j → 1` incluso con `p_aud` pequeño;
  una ausencia **suelta** (`j=1`) se detecta solo con probabilidad `p_aud` — con `p_aud=0,05` (1 de
  cada 20 hojas auditadas), una ausencia suelta pasa desapercibida el 95 % de las veces **si la
  auditoría aleatoria fuera el único mecanismo**. Con la revelación total obligatoria de AV-03, este
  problema no existe: `p_aud` deja de ser el mecanismo de cierre y pasa a ser, como mucho, una señal
  de alerta temprana (detectar antes de que la ventana cierre) — se recomienda mantenerla con ese
  papel reducido. **[D]**, cálculo en `calc/` no requerido para esta fórmula cerrada (verificada
  algebraicamente; es el mismo principio de muestreo que SL-2b usa para `q_ev`).
- Datos: 1 raíz (32 B) + overhead de compromiso por ventana; revelación marginal ≈ 0 mientras se
  vota con normalidad (la prueba ya acompaña al voto); revelación en bloque de las hojas no abiertas
  al cerrar la ventana. Coste por granjero y día en `calc/resultados/C1-datos-por-dia.csv`.

**AV-07 · Esquema 4 — lo que aporta la literatura de elección secreta de líder (SSLE) y de
Algorand. Descartado como solución directa; Algorand aporta la primitiva VRF, no el mecanismo de
forzado.**

- **SSLE (Boneh, Eskandarian, Hanzlik, Greco, 2020, IACR ePrint 2020/025 **[P]**, leído el resumen y
  la definición del problema) resuelve el problema OPUESTO al de AV-1.** Su objetivo declarado es
  que «the elected leader should be able to publicly reveal her identity and prove that she has won
  the election» — **una revelación voluntaria del ganador**, diseñada precisamente para que **nadie
  más pueda saber quién ganó si el ganador no revela**. Eso es exactamente (a) sin (b): SSLE
  **optimiza en contra** de la condición (b) de AV-1 (nadie puede demostrar después que alguien
  concreto ganó, salvo que ese alguien coopere). No se ha encontrado, en el resumen y la definición
  del problema consultados, ninguna variante de SSLE que permita a un tercero demostrar que una
  clave conocida fue elegida sin la cooperación de esa clave. **Se descarta como solución directa**;
  se cita como advertencia de diseño (cualquier primitiva de la familia SSLE, incluida su variante
  usada por Ethereum, Whisk/Curdleproofs, tira en la dirección opuesta a lo que necesita AV-1).
- **Algorand (Gilad et al., SOSP 2017 **[P]**, resumen y cita de la sección de sortición leídos vía
  buscador — el PDF completo no se pudo descargar en esta ejecución, ver §9) aporta la primitiva, no
  la solución del problema de AV-1.** La sortición criptográfica de Algorand usa VRFs exactamente
  como FV-06 ya adoptó («on any input string, VRFs return... a hash [that] is uniquely determined by
  the inputs but is indistinguishable from random... The proof enables anyone that knows the public
  key to check that the hash indeed corresponds to the inputs» **[P]**, cita literal). **Algorand no
  necesita resolver AV-01** porque no tiene garantía en juego que confiscar por ausencia: un comité
  que no vota en Algorand simplemente hace que esa fase de BA* necesite más pasos (viveza degradada,
  no falta castigable). La documentación de claves de participación (`dev.algorand.co`, consultada
  vía buscador) confirma que el estado online/offline y la ventana de validez (`first`/`last valid
  round`) de la clave de participación son públicos y se registran en una transacción de alta, pero
  **no** describe ningún mecanismo de prueba retroactiva de selección — no hace falta, porque
  Algorand no lo necesita. **No se ha encontrado, en las fuentes consultadas, ningún sistema con
  garantía en juego que resuelva exactamente el problema de AV-1** (sorteo secreto + prueba
  retroactiva obligatoria de ausencia con garantía confiscable); esto se declara como comprobado
  por búsqueda en esta ejecución, no como axioma. **[P]**/**[D]**.

### 1.3 · Diseño recomendado

**AV-08 · Diseño elegido: esquema 3 con entradas VRF independientes (AV-05) + revelación total
obligatoria con suspensión mecánica (AV-03), auditoría aleatoria opcional como alerta temprana.**

Resumen operativo:

1. Al abrir la ventana `W` (símbolo, `N_ventana` instancias), cada clave registrada con garantía
   activa publica `raiz_W = MerkleRoot(H(entrada_1)‖…‖H(entrada_{N_ventana}))`, donde
   `entrada_i = H_d("ZZKSorteoAvI____", seed_W ‖ i)` y `seed_W` es una función pública de
   `past(A)` del bloque de apertura de `W` (análoga a `hash(A_n)` de FV-06). El compromiso **no**
   revela ningún `output_i` (es un hash de valores no publicados todavía).
2. Al votar en la instancia `i` (si salió elegido), el voto de FV-11 se acompaña de `(proof_i,
   camino_Merkle_i)`: la hoja se abre en el mismo acto de votar, coste marginal despreciable.
3. Al cerrar `W` (tras `N_ventana` instancias), toda clave que tenga hojas sin abrir dispone de un
   plazo `W_reveal` (símbolo, §4) para publicar, en una única transacción de revelación en bloque,
   `(proof_i)` para **todas** las hojas no abiertas de `W` (sin necesidad de camino Merkle individual:
   basta con recomputar la raíz a partir de la lista completa y compararla con `raiz_W`, como hace
   SL-2b con sus CSV, más barato que `N_ventana` pruebas de camino Merkle independientes).
4. Si al cierre de `W_reveal` quedan hojas sin abrir, la clave queda **suspendida** (AV-09): excluida
   del sorteo de instancias futuras hasta que revele el resto. La suspensión **no** confisca nada
   (`AUTO-ZRX.md` §91).
5. Para cada hoja revelada (voluntariamente o al forzar la revelación en bloque) que indique
   «elegido» y no tenga un voto válido asociado (ni por la vía de gracia de AV-11), se activa la
   falta AV-1 (§2): pérdida de prima + confiscación de `m_aus`.

**AV-09 · Suspensión mecánica — regla, justificación y caso.** Regla: una clave con garantía activa
y una ventana `W` sin revelar completamente tras `W_reveal` queda con `peso_efectivo(P) = 0` en el
sorteo de toda instancia posterior hasta que revele el resto de `W` (y de cualquier ventana anterior
pendiente). Justificación: cierra AV-01/AV-02 sin depender de la voluntad del granjero — no revelar
pasa a ser estrictamente dominado por revelar. Caso: un granjero que se apagó toda la ventana `W`
(sin producir ni votar) y, además, no publica ninguna hoja al cerrar `W_reveal`, queda fuera del
sorteo desde ese momento; si vuelve a conectarse y revela `W` completa (incluidas las instancias
donde hubiera salido elegido y no votó), recupera su elegibilidad y, por AV-1, paga la confiscación
de las hojas que resulten «elegido sin voto» — pero no una confiscación mayor por haber tardado en
revelar: la suspensión es el único coste de la demora, no una segunda confiscación (evita un castigo
compuesto no declarado). **[D]**.

**AV-10 · Coherencia con la garantía y con SL-1: no se puede retirar sin rendir cuentas.** Análogo a
`EV-24`/`EV-15b` de SL-1: una **liberación** de garantía (`C-BON-06`) se rechaza mientras la clave
tenga alguna ventana `W` sin revelar completamente (`ErrVentanaSinRevelar`, mismo tratamiento que
`ErrCasoAbierto`: se descarta, no invalida el bloque). Esto cierra el caso del granjero que nunca
tiene intención de retirarse durante mucho tiempo: mientras sigue produciendo/participando, la
suspensión mecánica (AV-09) ya le cuesta elegibilidad en tiempo real; si además intenta retirarse sin
haber revelado, la liberación se bloquea igual que un caso de evidencia abierto. **[D]**, mismo
patrón que EV-24.

**AV-11 · Defensa ante censura — plazo de gracia para el voto Y para la revelación.** Un honesto que
salió elegido y votó a tiempo, pero cuyo voto no entró en el certificado (censura, partición,
reorganización), puede incluir su **propio voto firmado** en la cadena durante un plazo de gracia
`G_slots` posterior a la instancia (análogo a como SL-1 admite `EvidenceTx` dentro de
`Plazo_slots`). Un atacante que controle la producción de bloques necesita censurar **todas** las
oportunidades de inclusión durante `G_slots`, no solo una: con `G_slots` comparable a `F_slots`
(1019, SL-2b **[S]**), la probabilidad de censura total es `c^{F_slots}`, despreciable para
cualquier `c<1` (calc `C4`, mismo patrón que `q_ev` de SL-2b). La misma defensa se extiende a la
**revelación** de AV-08 paso 3: si la transacción de revelación en bloque es censurada, la clave
dispone de `G_slots` adicionales dentro de cualquier bloque productor honesto para reintentarla antes
de que se active la suspensión de AV-09. **Límite declarado, no cerrado aquí:** si el atacante logra
control de **toda** la producción de bloques durante `G_slots` (no solo censura selectiva), la
defensa falla igual que fallaría cualquier inclusión en cadena bajo ese mismo supuesto — es el mismo
límite que FV-1 ya declara para su propio umbral de ruptura (necesita control de red, no solo peso).

---

## 2 · La falta y su prueba

**AV-12 · Definición exacta de «elegido sin voto admitido» en la instancia `n`.** Existe la falta
`(public_key P, n)` si:

1. La hoja revelada de `P` para la instancia `n` de su ventana `W` (AV-08) contiene `(entrada_n,
   output_n, proof_n)` tal que `VRF_verify(pk_P, entrada_n, proof_n) = output_n` **[hecho, se
   verifica igual que FV-06]** y `output_n` indica «elegido» según el umbral vigente de FV-07 (al
   menos una de las `K` plazas); **y**
2. no existe, en la cadena seleccionada y aplicada, un voto de `P` para la instancia `n`
   (`H_d("ZZKVotoFinal____", n ‖ hash(candidato))`, firmado bajo `pk_P`, FV-11) admitido dentro del
   plazo ordinario **ni** dentro del plazo de gracia de AV-11.

Identidad de oportunidad: `(public_key, n)` — análoga a `FV-EVP-01` (doble voto), pero es la falta
**opuesta**: en vez de dos firmas sobre valores distintos, es **cero firmas** donde el sorteo exigía
una. **[D]**.

**AV-13 · Formato de la prueba de ausencia — `EvidenceAusencia`, misma familia que `EvidenceTx` y
`EvidenceVoto`.** Cuerpo: `(P, n, entrada_n, proof_n, camino_o_lista_de_revelacion_W)` — suficiente
para que cualquiera repita la verificación de AV-12(1) — más una prueba negativa de AV-12(2), que en
este diseño **no** requiere reconstruir nada: basta con que el verificador consulte la ausencia de un
voto de `P` para `n` en el registro de certificados de la instancia (dato ya público por FV-11/FV-13).
Sin entradas ni salidas monetarias (mismo patrón que `EV-01`/`FV-EVP-03`). **Incidente único:**
`incident_id = H_d("ZZKEvpAusencia__", (public_key, n))` — la primera `EvidenceAusencia` admisible
de ese incidente congela y confisca; una segunda del mismo incidente se descarta al fusionar, mismo
criterio que `EV-10`/`EV-12`. **Ventana de admisión:** `slot_falta ≤ slot_aplicacion <
slot_falta + Plazo_aus_slots`, con la misma desigualdad de retención que `EV-15`/`EV-15b`
(`R_slots > Plazo_aus_slots + M_margen_slots`, y la segunda condición de `EV-15b` para retiros
parciales) — **no** se puede liberar garantía sin que la ventana de admisión de sus últimas
instancias producidas/sorteadas haya cerrado. **Reorganización y undo:** exactamente `EV-27`/`EV-28`
(undo exacto al deshacerse el bloque que aplicó la prueba; reaparición en otra rama se trata como
primera aplicación). **[D]**, reutiliza EV-01…EV-29 con `(H1,H2)` sustituido por `(entrada_n,
proof_n)` y la comprobación semántica invertida (prueba de ausencia de voto, no de doble firma).

**AV-14 · Primitiva.** VRF: **ECVRF-EDWARDS25519-SHA512-TAI** (RFC 9381 §5.5 **[P]**), misma familia
de curva que Ed25519/ZIP-215 ya usada en ZEROX (`C-HDR-04`), consistente con la recomendación de
FV-06. Tamaño de prueba: `ptLen+cLen+qLen = 32+16+32 = 80` bytes (RFC 9381 §5.1 **[P]**). RFC 9381 es
un documento informacional del IRTF: no hay declaración de auditoría formal en el propio RFC, que
remite a las pruebas de seguridad de [PWHVNRG17] **[P]** — se recomienda como ZEROX ya recomienda
para FV-06, no como primitiva auditada de forma independiente por esta ejecución. **Precaución de
secreto declarada en la fuente:** «the VRF proof π is not designed to provide secrecy and, in
general, may reveal the VRF input α... [permitiendo] an offline dictionary attack to search for α»
(RFC 9381 §7.6 **[P]**) — no aplica aquí porque `entrada_i` ya es pública por construcción (deriva de
`seed_W` y `i`, ambos públicos): no hay `α` secreto que proteger, así que esta advertencia de la
fuente no introduce un límite nuevo en este diseño.

**AV-15 · Coste de verificación.** `O(1)` por hoja: una verificación ECVRF (RFC 9381 §5.3 **[P]**,
sin recorrer el pasado del DAG) más una consulta de presencia/ausencia de voto en el registro de
certificados de la instancia (ya indexado por FV-13). Verificar una `EvidenceAusencia` completa de
una ventana con `N_ventana` hojas sin abrir es `O(N_ventana)`, acotado por el tamaño de la
transacción de revelación en bloque (AV-08 paso 3). **[D]**.

**AV-16 · Coherencia con la prueba de doble voto (FV-EVP) — no se castiga dos veces el mismo hecho.**
`EvidenceAusencia` y `EvidenceVoto` (doble voto, FV-EVP) son **mutuamente excluyentes por
construcción** para la misma `(public_key, n)`: la primera exige **cero** votos admitidos; la
segunda exige **dos** votos admitidos con contenido distinto. Un voto único y válido no activa
ninguna de las dos. **[D]**, trivial por la definición de AV-12(2) y FV-EVP-01.

---

## 3 · La consecuencia

**AV-17 · Pérdida de la prima — duración y recuperación.** Al aplicarse `EvidenceAusencia`, la clave
pierde el multiplicador `b` (vuelve a peso efectivo ×1 en el sorteo) durante `D_prima` instancias
desde el momento de aplicación, con independencia de que vuelva a publicar pruebas de disponibilidad
de FV-05 durante ese periodo (una prueba de disponibilidad publicada durante la penalización **no**
la levanta antes: sería, si no, una forma de anular el castigo con el mismo mecanismo que lo prueba
inútil). Al cumplirse `D_prima`, la prima se recupera automáticamente si la clave tiene una prueba de
disponibilidad vigente en ese momento (FV-05 ordinario), sin procedimiento adicional — mismo
principio de reanudación sin autorización que FV-21. **Interacción con FV-05:** la vigencia de una
prueba de disponibilidad publicada ANTES del incidente y todavía formalmente vigente (`T_prueba_slots`
sin agotar) **no** protege de la pérdida de prima: `D_prima` es una suspensión explícita del
multiplicador, no una caducidad de la prueba misma. **[D]**.

**AV-18 · Confiscación `m_aus` — de qué saldo sale, saldo insuficiente, destino.** Sigue
literalmente el patrón de `EV-17…EV-22` de SL-1: se congela **todo** el saldo castigable de `P`
disponible al aplicarse la primera `EvidenceAusencia` del incidente (activo, pendiente, en retirada,
crédito de coinbase no maduro — `EV-17`); si `V(P,incidente) = 0`, `pérdida = 0` y el incidente se
registra igual (`EV-22`, cierra la grieta de `P-CLAVE` de la misma forma que SL-1: **no se cierra
aquí, se hereda como límite declarado**). **Destino de los fondos:** por defecto, el mismo reparto
que `RAT-2′` de SL-1 (2/8 a la coinbase de quien incluye la `EvidenceAusencia`, 6/8 quemado),
**salvo que el informe recomiende otro** (§ decisiones para Katana) — se recomienda mantener el
mismo reparto por consistencia y porque SL-2b ya demostró que la autodenuncia sigue sin ser rentable
con ese reparto (`(1−2/8)·C + c_r > 0`). **[D]**.

**AV-19 · El hallazgo cuantitativo central de esta orden — `m_aus` FIJO no cumple la condición (e).**
Calc `C2`/`C6` (`resultados/`): si `m_aus` es una cantidad **fija por incidente** (independiente del
peso de la clave), un atacante que **concentra** todo su peso `a` en una sola clave (`m_split=1`)
sufre, por instancia sostenida de pausa, **como mucho un incidente** (`EV-06`-símil: firma como
mucho un valor por instancia, y aquí, ausencia como mucho una vez por instancia por clave), con
probabilidad `1-(1-a)^K → 1` para `a ≫ 1/K` — es decir, el coste por hora de sostener la pausa
mediante autoabstención tiende a `m_aus / T_instancia`, **una constante independiente de `a`**
(verificado: `costo_hora_m_aus_fijo` con `a∈{0,20;0,40}`, `m_split=1`, difiere menos del 1 %,
`test/runtests.jl`). **Esto viola la condición (e) de la pregunta falsable** («el coste absoluto…
crece con la duración de la pausa» se cumple linealmente en el tiempo, pero no con la **magnitud**
del atacante, que es lo que un modelo de amenaza de Estado exige: un atacante con el 40 % del peso
paga lo mismo por hora de pausa que uno con el 20 %, mientras ambos superen `1/K`). Con `m_aus`
**proporcional** a la garantía de la clave (`m_aus(P) = f_aus × garantía(P)`), el coste por hora
crece linealmente con `a` (verificado en `C2`, columna `costo_hora_m_aus_proporcional`) y es
**invariante** a cómo el atacante reparte su peso entre claves (`m_split`), porque la garantía
agregada del atacante no cambia al partir sus claves (`RFT-05`). **Recomendación de este contrato:
`m_aus` debe ser proporcional a la garantía de la clave, con un piso mínimo absoluto** (para que una
clave con saldo insuficiente no escape con pérdida cero por el mismo mecanismo que `EV-22` ya
acepta como límite declarado, no cerrado). Ver decisión D1 en `INFORME.md`.

**AV-20 · Alcance (i) — sin excepciones, con el coste declarado por Katana.** Todo elegido paga,
tenga prima o no (FV-D04). Los comparadores (ii)/(iii)/(iv) **no se diseñan** (ya descartados por
Katana): se calculan sus costes en `INFORME.md`/`calc/` para dejar constancia cuantitativa de por
qué (i) es la elección correcta con este diseño.

**AV-21 · Sin castigo correlacionado (extensión de `DS-L02`/`EV-21` a la falta de ausencia).** La
fracción o cantidad de `m_aus` de un incidente de `P` **no** depende de cuántas otras claves tengan
incidentes de ausencia en la misma ventana o instancia. Un fallo compartido de cliente (ataque
adversarial 4, `INFORME.md` §D) que deja a muchas claves honestas sin votar a la vez **no** se
amplifica: cada una paga su `m_aus` individual, ni más ni menos — mismo argumento de `DS-5`/`REVISION-DS5.md`
(el castigo correlacionado no encarece al atacante grande y sí castiga a honestos con fallo común).
**[D]**.

**AV-22 · Premio al voto — pendiente de Katana, calculado sin decidir.** `calc/C3` calcula el
balance esperado del honesto con `premio_voto=0` y `premio_voto=1` (unidad simbólica): con premio
positivo, la pérdida de la prima (`D_prima`) deja de ser solo un coste estratégico y adquiere lucro
cesante monetario (`lucro_cesante_prima` en `src/modelo.jl`), lo cual **refuerza** el hallazgo AV-19
(la prima perdida sí escala con el peso de la clave, aunque `m_aus` no lo haga) — un argumento
adicional, no decisivo por sí solo, a favor de adoptar algún premio positivo. No se decide aquí.

---

## 4 · Parámetros abiertos

| Símbolo | Qué fija | Restricción estructural ya escrita |
|---|---|---|
| `m_aus` / `f_aus` | Confiscación por incidente de ausencia | Recomendado proporcional a la garantía (AV-19), no fijo; con piso mínimo. Región candidata en `calc/resultados/C5-region-m_aus.csv` (ilustrativa, no de producción) |
| `D_prima` | Duración de la pérdida de la prima, en instancias | `> 0`; interactúa con `T_prueba_slots` de FV-05 (AV-17); no fijado aquí |
| `N_ventana` | Instancias por ventana de compromiso Merkle (AV-08) | `≥ 1`; coste de datos decreciente en `N_ventana` hasta el límite `80 B`/instancia (calc `C1`); compromiso entre coste y latencia de detección |
| `W_reveal` | Plazo tras el cierre de `W` para revelar hojas pendientes | `> 0`; debe ser `≥ G_slots` (AV-11) para que la defensa de censura tenga margen dentro de él |
| `G_slots` | Plazo de gracia para voto y para revelación | `> 0`; candidato inicial `F_slots` (1019, SL-2b), por la misma razón que allí: censura parcial queda neutralizada (calc `C4`) |
| `Plazo_aus_slots`, `M_margen_slots` | Ventana de admisión de `EvidenceAusencia` y margen de retención | Misma desigualdad no negociable de `EV-15`/`EV-15b`, con `Plazo_aus_slots` en el lugar de `Plazo_slots` |
| `seed_W` | Fuente pública del compromiso por ventana | Debe ser función de `past(A)` del bloque de apertura de `W`, nunca del propio productor del bloque que la fija (mismo criterio anti-sesgo que FV-02) |
| Destino de `m_aus` | Reparto entre quema e incluidor | Recomendado: heredar `RAT-2′` de SL-1 (2/8 al incluidor, 6/8 quemado), salvo decisión distinta |
| `p_aud` | Fracción de auditoría aleatoria temprana (opcional, AV-06) | No es el mecanismo de cierre de (b) (eso lo hace AV-03/AV-09); si se adopta, es solo alerta temprana |

No numéricos, para el director/Katana (detalle con opciones y coste en `INFORME.md` §Decisiones):
(i) `m_aus` fijo vs. proporcional a la garantía (AV-19, recomendación clara: proporcional);
(ii) duración de `D_prima`; (iii) si se premia votar (AV-22).
