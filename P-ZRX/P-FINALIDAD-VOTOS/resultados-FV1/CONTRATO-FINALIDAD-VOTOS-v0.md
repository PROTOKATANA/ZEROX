# CONTRATO-FINALIDAD-VOTOS-v0 — Capa de finalidad por votos bajo R1–R5

**Orden:** FV-1 (segunda ejecución). **Ejecutor:** subagente Sonnet (diseño y análisis; sin código de
producto). **Fecha:** 2026-09-26. **Estado:** propuesta ratificable, **no normativa** hasta que el
director la apruebe y Katana la ratifique. Convierte la decisión 6 de Katana
(`P-ZRX/P-FINALIDAD-VOTOS/PROGRAMA.md`, `CONTEXTO.md` §3.6, `ORDEN-FV1-DISENO.md` §3) en un contrato
preciso, sin fijar parámetros de producción. Sustituye, para el diseño con sorteo, a las reglas
R-FIN-15…22 de `research/dag-poas-capa-finalidad.md` (2026-09-09, hipótesis sin auditar): esas cifras
se recalculan en `INFORME.md`, no se heredan.

Etiquetas: **[P]** fuente primaria leída en esta ejecución · **[S]** fuente secundaria · **[D]**
derivación propia (con la cuenta hecha en `INFORME.md` o aquí mismo) · **[H]** hipótesis de diseño de
este contrato, no probada.

---

## 0 · Qué no se reabre

Por mandato de `ORDEN-FV1-DISENO.md` §3: R1–R5 son requisitos, no orientaciones; la capa es
superpuesta (no cambia quién produce, quién cobra, GHOSTDAG ni `blue_work`, `SPEC.md` §0 **[P]**);
`C-FIN-01` se queda como red de seguridad; sin quórum se pausa, nunca fuga por inactividad; la única
falta nueva es el doble voto, sin castigo por ausencia y sin castigo correlacionado (`DS-L02` **[P]**,
`P-ZRX/P-SLASHING/DECISIONES.md`); peso = sectores registrados con garantía; sorteo secreto entre
**todos** los registrados, probabilidad = espacio × prima `b` si hay prueba de disponibilidad vigente.

---

## 1 · Fuente del peso y tabla de pesos

**FV-01 · Peso.** El peso de una clave `P` en la instancia `n` es su **espacio registrado con
garantía activa** (`P-ZRX/P-REGISTRO-SECTORES`, capacidad comprometida y auditada bajo la interfaz
`SEC-A` de `P-ZRX/P-TRANSICION/CONTRATO-v0.md` §8 **[P]**), **no** los bloques cobrados en una
ventana (opción A, comparador §5) **ni** la garantía `C-BON` sola (opción C, comparador §5). Motivo:
para que R5 tenga algo que castigar hace falta un objeto que se pueda confiscar y que sea
proporcional al daño potencial (`ORDEN-FV1-DISENO.md` §3.6; `PROGRAMA.md` «Decisiones de Katana»
**[P]**), y el espacio cobrado por bloques no lo es (F3 de Filecoin pondera por QAP, capacidad
comprometida, no por bloques ganados, **[S]** `dag-poas-capa-finalidad.md` §2).

**FV-02 · Retardo (*lookback*) y compromiso de la tabla siguiente.** Para la instancia `n`, sea `A_n`
el bloque de la cadena seleccionada cuyo certificado válido más reciente lo finaliza, tomado con un
retardo `LOOKBACK` de instancias (candidato inicial `LOOKBACK = 10`, como F3 **[S]**
`dag-poas-capa-finalidad.md` §3, R-FIN-15). La **tabla de pesos** de la instancia `n` es la función
`peso: P → capacidad_registrada_con_garantía(P, Estado(past(A_n)))`, calculada **solo** de
`past(A_n)` (§3 del contrato de transición, patrón `C-BON-04` **[P]**). Todo certificado de la
instancia `n` **compromete el hash de la tabla de pesos** que rige la instancia `n+1` (análogo de
`SupplementalData.PowerTable` de F3, R-FIN-21 **[S]**), para que la cadena de certificados se
verifique sola desde génesis sin la cadena de bloques (§4). **Cierre del contraejemplo de la primera
ejecución (histórico):** la tabla de la instancia `n` es la que **comprometió el certificado de
`n − 1`**, nunca la del propio bloque que se está sellando; así ningún atacante puede sesgar con el
bloque que él mismo produce dentro de la ventana que su propio certificado va a usar
(`resultados-FV1-v1/` §FV-01b, comprobado de nuevo en esta ejecución y **conservado**: sigue
aplicando sin cambios con la fuente de peso nueva).

**FV-03 · Sesgo de la tabla por elección de qué bloques publicar (ataque 3).** Como `A_n` sale de la
cadena **ya seleccionada** por GHOSTDAG/`blue_work` (§0, no cambia quién produce), el atacante no
elige la tabla directamente: solo puede intentar que su propia rama sea la seleccionada (lo que exige
ganar el consenso de producción, ajeno a esta capa) o retener/publicar sus propios registros de
sector para entrar o salir de la tabla en el momento que más le convenga. **No se ha encontrado**, en
esta ejecución, un mecanismo por el que retener o publicar *bloques* (a diferencia de *altas o bajas
de sector*, que siguen su propio plazo `P_sec`/`M_sec` de `C-BOT-04` §8) cambie la tabla de pesos sin
pasar por el DAG ya seleccionado: **queda igual de expuesto** que R-FIN-15 lo dejaba (D8 de la
propuesta antigua, sin cerrar) al sesgo del **ancla** (§4.D, `verif_sesgo_sorteo.py`), tratado en
`INFORME.md` y en la tabla de ataques (ataque 14).

---

## 2 · Quién vota (decisión 6)

**FV-04 · Elegibilidad — R1 exacta.** Entran en el sorteo **todos** los registrados con garantía
activa en `past(A_n)`, estén o no encendidos, hayan o no producido nunca un bloque. Nadie queda fuera
por espacio pequeño ni por estar apagado: R1 (entrada abierta) se cumple **sin condición**, a
diferencia del diseño antiguo (R-FIN-16, que restringía el sorteo a quien había ganado un bloque en
`W_VIVO`, y de la variante de §3.5 de `CONTEXTO.md`, que restringía a quien había demostrado
disponibilidad). **[P]** `ORDEN-FV1-DISENO.md` §3 mandato 6.

**FV-05 · Prueba de disponibilidad.** Es una afirmación de **sí o no**, con validez de `T_prueba_slots`
desde su inclusión, verificable en la cadena sin métrica externa (R2):

- **Vía A — compromiso explícito.** Una transacción firmada por `P` que compromete `H_d("ZZKPruebaViva___", slot_actual)`, aplicada en `past(B)`. Cuesta una transacción por vigencia; **[H]** el formato exacto (tamaño, si necesita PoW/tarifa para no ser gratis y así spameable) queda para SL-3/FV-3.
- **Vía B — ganar un bloque.** Producir un bloque `PoAS_PoT_DAG` válido en `past(B)` cuenta como
  prueba, con la **misma** vigencia `T_prueba_slots` que la vía A. **No es la única vía ni da peso
  extra** (`ORDEN-FV1-DISENO.md` §3.6: «si lo fuera, el pequeño quedaría filtrado dos veces por su
  espacio»): un granjero pequeño que rara vez gana bloques puede probar disponibilidad por la vía A
  sin tener que ganar nada primero. **[P]**.

`T_prueba_slots` es un parámetro abierto (§9); debe ser mayor que el intervalo típico entre pruebas de
un granjero doméstico bien configurado y menor que la ventana en la que la ausencia deja de ser
representativa de "está vivo ahora" — ninguno de los dos extremos se fija aquí.

**FV-06 · Sorteo secreto por ronda (AGR1).** Cada registrado calcula en privado, con una VRF
(`VRF_sk(entrada)`) sobre su propia clave, si le ha tocado alguna de las `K` plazas de la ronda de la
instancia `n`. La **entrada** de la VRF es
`entrada_n = H_d("ZZKSorteoFV______", hash(A_n) ‖ n ‖ tabla_pesos_hash(n))`: función exclusiva de
`past(A_n)` (mismo criterio que el resto del contrato de transición, `TRN-*`), **nunca** del propio
candidato a sellar (evita que el productor de un bloque influya en quién lo va a votar). La VRF debe
ser una primitiva auditada: candidato **ECVRF-EDWARDS25519-SHA512-TAI** (RFC 9381 **[S]**, la misma
familia de curva que ya usa ZEROX para Ed25519/ZIP-215, `C-HDR-04`), para no introducir una curva
nueva en la ruta de consenso (línea roja de `AGUJEROS-Y-SOLUCIONES.md` §5 sobre BLS, aplicada aquí a
la VRF). **[H]** la elección concreta de primitiva VRF es una recomendación, no está auditada en esta
ejecución.

**FV-07 · Probabilidad del sorteo.** Para cada una de las `K` plazas (con reemplazo — la misma clave
puede ocupar varias, como R-FIN-16 **[S]**), la probabilidad de que caiga en `P` es proporcional a su
**peso efectivo**:

```text
peso_efectivo(P, n) = peso(P, n) × ( b   si P tiene prueba de disponibilidad vigente en past(A_n)
                                      1   en otro caso )
```

con `b > 1` fijo por perfil de red (§9). La demostración de la plaza al votar es la salida de la VRF
más su prueba, verificable por cualquiera sin recalcular el sorteo de nadie más (Algorand **[S]**).
**No hay tabla de poder derivada de bloques cobrados** (a diferencia de R-FIN-15/16 de la propuesta
antigua): FV-01 ya fija el peso por sectores, así que el «PoAS no registra a nadie» que bloqueó la
propuesta de 2026-09-09 no aplica aquí (`ORDEN-FV1-DISENO.md` §6, «Precedentes»).

**FV-08 · Admisión sin elección — R2.** La probabilidad depende **solo** de `peso(P,n)` (verificado
en la cadena, sectores + garantía) y de un booleano verificable en la cadena (`FV-05`). No entra
ninguna métrica externa, ninguna reputación, ningún voto de terceros. R2 se cumple.

**FV-09 · El pequeño no queda filtrado dos veces por su espacio.** Al entrar **todos** los registrados
(FV-04) y depender la probabilidad **linealmente** de `peso(P,n)` (sin exponente ni umbral mínimo de
espacio para participar en el sorteo), un granjero con poco espacio tiene una probabilidad
proporcionalmente pequeña de salir elegido, pero **nunca cero** y **nunca penalizada dos veces**: no
hace falta ganar un bloque para ser elegible (FV-04) ni para tener la prima (FV-05, vía A). Esto
corrige la advertencia de `ORDEN-FV1-DISENO.md` §3.6 sobre la vía «solo ganar bloques cuenta».

**FV-10 · `K`, plazas por clave y los símbolos `b`, `E`.** Quedan como parámetros de perfil, calibrados
en `INFORME.md` §C con las curvas `(K, b, E)` pedidas por el mandato. `K` se dimensiona por **viveza**
(que el sorteo no sea tan pequeño que la varianza sola pueda darle a un atacante minoritario 1/3 o 2/3
de las plazas) y su coste crece con el tamaño del certificado (§4). `E` es el suelo de representatividad
de FV-15.

---

## 3 · Protocolo de acuerdo

**FV-11 · Candidato: GossiPBFT (F3), con temporizadores en función de `Δ`.** Cada instancia `n` tiene
fases de propuesta/pre-voto/voto sobre el prefijo de la cadena seleccionada visible al iniciar la
instancia, con temporizadores `T_fase = c_fase · Δ` (`c_fase` por fase, símbolo; **[H]** valor no
fijado, `Δ` no medida, IPA B-05). Cada votante sorteado (FV-06) firma **como mucho un valor por
instancia** (Mandamiento I de Casper, `R-ZRX/LEGADO/stake/MAPA.md` §1.3 **[P]**) sobre
`H_d("ZZKVotoFinal____", n ‖ hash(candidato))`.

**FV-12 · Solo sella prefijos, nunca contenido — R4.** El único objeto que un votante puede firmar es
el **hash de un bloque de la cadena ya seleccionada** por GHOSTDAG/`blue_work` en el momento del
sorteo. Un voto no puede proponer contenido, reordenar transacciones ni preferir una rama por ningún
criterio propio: solo puede sellar (afirmar «esto es final») o abstenerse. R4 se cumple por
construcción: la capa nunca decide **qué** se produce, solo **hasta dónde** se considera irreversible
lo ya producido por PoAS+PoT+DAG.

---

## 4 · Certificado

**FV-13 · Contenido.** `Certificado(n) = (n, hash(B_sellado), hash_tabla_pesos(n+1), firmas)`, con
`firmas` el mapa de bits de las plazas firmantes más la firma agregada (§FV-14). Compromete la tabla
de pesos de la instancia **siguiente** (FV-02), de modo que la cadena de certificados se auto-verifica
desde génesis sin recorrer la cadena de bloques (R-FIN-21 **[S]**, cita literal: «Verifying the
finality of a tipset from genesis does not require access to the EC chain» **[P]**,
`dag-poas-capa-finalidad.md` §1).

**FV-14 · Esquema de firma.** **BLS agregada + mapa de bits**, no Ed25519 por plaza. `INFORME.md` §C.3
recalcula el coste (`P-ZRX/T-ZRX/AGUJEROS-Y-SOLUCIONES.md` §2 ya advierte del mismo dilema para el
segundo VDF: BLS es la única forma de que el certificado no cueste varias veces la cadena entera con
`K` en los miles). Con `blst` (Supranational, auditado NCC Group 2021 **[S]**,
`dag-poas-capa-finalidad.md` §5) como candidato, confinado como excepción de FFI igual que `zx-miner`;
`bls12_381` de zkcrypto (Rust puro, sin auditar) solo como contraste diferencial. **[H]** decisión de
Katana pendiente: introducir BLS en la ruta de consenso es la misma bifurcación que la propuesta
antigua dejó sin resolver, y **este contrato no la reabre por su cuenta**: si Katana prefiere no
introducir BLS, la alternativa es un `K` pequeño con Ed25519 (curva de coste en `INFORME.md` §C.3), al
precio de un comité menos representativo (más varianza de sorteo, §4.D antiguo).

**FV-15 · Coste de verificación.** `O(1)` por certificado con BLS agregada (una verificación de
firma agregada + reconstrucción del mapa de bits contra la tabla de pesos comprometida), sin recorrer
el DAG. Cifras en `INFORME.md` §C.3.

**FV-16 · Cadena de certificados desde génesis.** Un nodo nuevo puede verificar la finalidad de
cualquier tipset siguiendo **solo** la cadena `Certificado(0), Certificado(1), …` y las tablas de peso
que cada uno compromete (FV-02, FV-13), sin descargar ni validar la cadena de bloques completa. **En
una línea, sin desarrollar** (mandato §4.A): esto habilitaría un cliente ligero análogo al de
R-FIN-22 de la propuesta antigua, pero **no se diseña aquí**; es un entregable propio si Katana lo
pide.

---

## 5 · Convivencia con `C-FIN-01`

**FV-17 · Regla de selección con certificado.** Un nodo **MUST NOT** reorganizar por debajo del
bloque certificado más profundo que conozca, con la misma semántica de R-FIN-18: manda la finalidad
**más profunda** de las dos (`C-FIN-01` o el certificado). Un certificado solo puede **adelantar** la
finalidad, nunca retrasarla, y en ausencia de certificado válido rige `C-FIN-01` sin cambios
(`d < F_slots`). **[D]** Esto es exactamente la condición (c) de la pregunta falsable, comprobada en
FV-18.

**FV-18 · Demostración de (c) — con la capa pausada, rota o sin activar, ningún nodo queda peor que
con `C-FIN-01` sola.**

*Pausada o sin activar (nunca se emitió certificado, o el último caducó sin sucesor):* la regla de
selección de FV-17 se reduce a "rige `C-FIN-01`", que es exactamente el comportamiento de hoy. Ningún
nodo pierde nada porque **nunca dejó de aplicar** `C-FIN-01`: la capa es aditiva por construcción
(§0, mismo argumento que F3/EIP-3675 **[S]**, «continues operating "normally" if F3 assumptions are
violated», `dag-poas-capa-finalidad.md` §1). **Demostrado.**

*Rota (el mecanismo emitió un certificado válido según sus propias reglas de firma, pero para un
bloque que un tercio del peso total sabe que es falso porque el resto de la red — GHOSTDAG puro — lo
descartó):* aquí la respuesta **no es un "sí" limpio**, y hay que decirlo con el mismo cuidado que el
mandato exige. Un nodo que **ya tiene** el certificado falso queda igual de mal que si `C-FIN-01`
fuera la única regla y un atacante con mayoría de `blue_work` reescribiera su historia por debajo de
`F_slots` (mismo orden de daño: reescritura de lo que creía definitivo). Un nodo que **todavía no
recibió** el certificado falso y sigue viendo GHOSTDAG puro **no está peor que hoy**: sigue
protegido por `C-FIN-01` exactamente igual, porque FV-17 nunca le hace aceptar un certificado que no
ha visto. **La "mentira permanente" (§6.1 de la propuesta antigua) es el caso que sí empeora**: un
certificado, a diferencia de una reorganización de `blue_work`, **no se puede revertir por más
`blue_work` honesto que aparezca después** (es la contrapartida de que sea rápido y determinista, F3
**[S]**). Frente a esto, `C-FIN-01` solo es reversible mientras `d < F_slots`; después, tampoco un
nodo en línea la revierte. **Conclusión exacta:** con la capa rota, un nodo que ya adoptó el
certificado falso **no está peor que con `C-FIN-01` sola frente al mismo `d`**, porque en ambos casos
la reversión exige romper una regla que el nodo trata como absoluta; pero la capa **añade** una vía
de "definitivo falso" que no exige ganar la carrera de `blue_work`, solo reunir 2/3 de las plazas
sorteadas con control de la red (ataque 2, §B). **Esto refuta la lectura optimista de (c) como "nunca
peor en ningún escenario"**: (c) se sostiene para *pausada* y *sin activar* (demostrado), y se
sostiene para *rota, antes de adoptar el certificado* (demostrado); **no** se sostiene sin matiz para
*rota, después de adoptar el certificado falso* — ahí el nodo pierde algo que con `C-FIN-01` sola no
podía perder tan rápido: la posibilidad de que `blue_work` honesto acumulado corrija el error dentro
de `F_slots`. **Contraejemplo concreto:** un atacante con 1/3 del peso total y control de la red
produce, en el slot `s`, dos bloques `B` y `B'` sobre puntas distintas y logra que un tercio de las
plazas sorteadas de la instancia que cubre `s` firme `B` mientras la red honesta seguía construyendo
sobre `B'` con más `blue_work`; un nodo que adoptó `Certificado(B)` antes de que `B'` acumulara más
peso queda con `B` como definitivo aunque `B'` fuera —y siga siendo, para el resto de la red— la
cadena de mayor `blue_work`. Esto exige la ruptura del sello (1/3 del peso, control de la red, deja
firma — ataque 2), no ocurre por accidente ni por una minoría pequeña.

**FV-19 · Consecuencia para el diseño.** El certificado **debe** llevar una ventana de validación
adicional en el productor/relay honesto (no exigida por la letra de F3): un nodo honesto **no debería
adoptar** un certificado que contradiga la cadena de mayor `blue_work` que él mismo observa, aun si el
certificado es criptográficamente válido, y debería propagar la contradicción como evidencia (§7) en
vez de sustituir su vista. **[H]** esta regla no está en F3 (que asume la BFT del comité es siempre
correcta bajo <1/3 bizantino) y es una adición de este contrato para acotar el daño de FV-18; su coste
y su interacción con la viveza (¿qué hace un nodo que ve dos certificados válidos para instancias
incompatibles?) quedan para FV-2/FV-3.

---

## 6 · Pausa y reanudación (R3)

**FV-20 · Pausa.** Si ninguna instancia produce un certificado válido durante `N_pausa` instancias
seguidas, la capa se declara **pausada**: los nodos no esperan un certificado para nada (ni para
aceptar pagos, ni para servir datos), y `C-FIN-01` sigue siendo la única regla de finalidad efectiva
mientras dure. R3 se cumple literalmente: producir bloques nunca depende de los votantes, y su
ausencia **no es falta** (§4.5 de `CONTEXTO.md`: «no firmar no es falta»). No hay temporizador de
"declarar pausa" con efecto de consenso: es una observación local de cada nodo (cuántas instancias
lleva sin ver un certificado nuevo), sin que el estado "pausado" sea en sí mismo un dato que haya que
acordar.

**FV-21 · Reanudación.** En cuanto una instancia posterior reúne 2/3 de sus plazas, su certificado se
adopta con la regla ordinaria de FV-17 (manda el más profundo). No hace falta ningún procedimiento de
"reactivación": la capa vuelve a producir certificados en cuanto vuelve a haber quórum, sin que nadie
tenga que autorizarlo.

**FV-22 · Qué protege durante la pausa.** `C-FIN-01` con su `F_slots` de hoy, sin degradar y sin
mejorar: el mandato (§3, decisión 3) dice que el peor caso, con la capa pausada, es el de hoy. FV-18
ya mostró la única excepción (una vez adoptado un certificado falso antes de la pausa, esa adopción no
se revierte por la pausa posterior).

---

## 7 · Falta y evidencia (R5)

Se define la falta nueva **doble voto**, en la misma familia que `EvidenceTx` (`C-EVP`,
`P-ZRX/P-SLASHING/resultados-SL1/CONTRATO-EVIDENCIA-v0.md`, en adelante «SL-1»), reutilizando su
patrón de verificación en `O(1)`, incidente único, ventana de admisión y confiscación no
correlacionada (`DS-L02` **[P]**).

**FV-EVP-01 · Identidad de oportunidad del voto.** `(public_key, n)` — la clave y el número de
instancia. Dos votos de la misma clave para la **misma** `n` sobre valores `hash(candidato)`
distintos son la falta; el mismo voto repetido (mismo `hash(candidato)`) no lo es (análogo de EV-06).

**FV-EVP-02 · Doble voto: prueba pública.** Hay prueba si existen dos votos `V1`, `V2` con la misma
identidad FV-EVP-01, `hash(candidato)` distintos y sendas firmas VRF/Ed25519 válidas bajo la clave
declarada. **Mandamiento I de Casper, con la maquinaria de SL-1**: no hace falta reconstruir ninguna
rama perdedora ni demostrar validez PoST de ninguno de los dos candidatos (mismo principio que EV-08:
la prueba acredita **dos decisiones de firma**, no que ambos candidatos fueran válidos).

**FV-EVP-03 · `EvidenceVoto` — tipo explícito, misma familia que `EvidenceTx`.** Cuerpo con
exactamente dos votos completos, ordenados canónicamente (mismo criterio que EV-01), sin entradas ni
salidas monetarias, comprometido en `txid`/Merkle/peso. **[D]** reutiliza EV-01…EV-04 de SL-1 con
`(H1, H2)` sustituido por `(V1, V2)`.

**FV-EVP-04 · Incidente único y deduplicación.** `incident_id = H_d(dom_incidente_voto, (public_key,
n))`; la primera `EvidenceVoto` admisible congela y la segunda del mismo incidente se descarta al
fusionar, sin volver a congelar (mismo criterio que EV-10…EV-12).

**FV-EVP-05 · Ventana de admisión frente al retiro (parte de la pregunta falsable, ítem (b)).**
`admisible ⟺ n_falta ≤ n_aplicacion(EvidenceVoto) < n_falta + Plazo_voto_instancias`, con
`Plazo_voto_instancias` expresado en **instancias de esta capa**, no en slots — porque el doble voto
ocurre en el reloj de las instancias, no en el de PoT. La condición de retención hereda **EV-15/EV-15b
de SL-1 sin cambios de forma**, sustituyendo `Plazo_slots` por el equivalente en slots de
`Plazo_voto_instancias` (una instancia dura, en esperanza, lo que tarde en sellar, §C.4 de
`INFORME.md`; la conversión exacta instancia→slots es un parámetro abierto, §9):

```text
R_slots > (duración_instancias(Plazo_voto_instancias)) + M_margen_slots
```

Sin esta desigualdad, un votante puede retirar su garantía antes de que la ventana de su propio doble
voto cierre — el mismo hueco que EV-15 cierra para `EvidenceTx`, y **EV-15b aplica igual** para un
retiro parcial con producción/voto continuados.

**FV-EVP-06 · Qué se confisca y si la garantía crece con el peso — condición explícita de R5.** La
falta congela y confisca una fracción fija `f_voto` (símbolo propio, no necesariamente igual al `f`
de `EvidenceTx`, §9) del **saldo congelable de la clave**, con la misma mecánica de EV-17…EV-22 (toda
sub-cuenta, sin correlación entre claves, `pérdida = 0` si `V = 0`). **Con la fuente de peso elegida
(FV-01, sectores registrados con garantía), la garantía SÍ crece con el peso**: `requisito(B)` de
`C-BON-04` es una función de `past(B)`, y aunque su forma exacta está pendiente (`IPA C-02`), el
peso que cuenta para el sorteo (FV-01) es literalmente el espacio con garantía activa — quien tiene
un tercio del peso de la red tiene, por construcción, un tercio de la garantía agregada de la red
(salvo que el `requisito` por clave tenga un techo, lo que **no** está decidido). **Comparación
declarada:** con la fuente (A) —bloques cobrados en una ventana— R5 **no muerde de la misma forma**:
el peso de voto no correspondería a una garantía proporcional salvo que se diseñara una garantía
atada a los bloques cobrados, que no existe hoy; con la fuente (C) —solo `C-BON`, sin ligar al
sorteo— el peso de voto y la garantía coincidirían por definición, pero entonces el peso de voto **no
sería espacio** y `SPEC.md` §0 cambiaría (mandato §6, último punto). **Decisión de este contrato: con
FV-01, R5 muerde en la medida en que `requisito(B)` no tenga techo por clave** — si Katana decide un
techo (para limitar la concentración de un único operador), la fracción de garantía por unidad de
peso de voto **deja de ser constante** y esta sección debe revisarse.

---

## 8 · Activación tras el corte PoW → PoST

**FV-23 · Puerta de activación, análoga a `Φ` de `C-BOT-04`/`CUT-HWΦ`.** La capa se enciende cuando,
sobre `Estado(past(B))` del bloque candidato: `Σ peso(P) ≥ S_min_voto` (peso total mínimo con
garantía) **y** el número de claves distintas con peso `> 0` es `≥ K_min_voto` (evita que un puñado
de claves controle el sorteo entero desde el primer día, mismo espíritu que `Φ` de `C-BOT-04`: «varias
claves no prueban operadores independientes», pero aquí se usa como **piso de viveza**, no de
seguridad — un `K_min_voto` bajo no protege de un Sybil, solo evita un sorteo degenerado con `K`
efectivo menor que el nominal). Antes de la activación, **no existe finalidad rápida**: rige
`C-FIN-01` en solitario, exactamente como en 0.0.1 hoy. **[H]** valores de `S_min_voto`, `K_min_voto`
no se fijan aquí (símbolos, §9).

**FV-24 · Qué rige antes de activar.** Ningún nodo espera un certificado ni lo exige para nada:
la capa, antes de `FV-23`, se comporta como si no existiera (coherente con `C-BOT-06`: «debe
comprobarse la garantía madura disponible para nuevas claves… antes de aprobar el lanzamiento»).

---

## 9 · Parámetros abiertos

| Símbolo | Qué fija | Restricción estructural ya escrita |
|---|---|---|
| `b` | Prima de disponibilidad | `b > 1`; curvas de viveza/seguridad en `INFORME.md` §C; `b < 2(1−a)/a` para que un atacante de fracción `a` no alcance 2/3 de plazas **en esperanza** ni siquiera censurando todo (FV-hallazgo §C.1(D)); **`a_pausa(b) = 1/(2b+1) < 1/3` para todo `b > 1`**: ningún `b>1` preserva literalmente la parte de pausa de (a) frente a censura total, ver `INFORME.md` |
| `E` | Suelo de representatividad (peso con prueba vigente / peso total) | Si se adopta, `E ∈ (0,1]`; con él, romper el sello exige `a ≥ ...` según `INFORME.md` §C; **no** restaura el umbral de *pausa*, solo convierte un intento de ruptura en una pausa explícita (§C, hallazgo) |
| `K` | Plazas por instancia | Viveza (varianza del sorteo) frente a coste del certificado (§4); `INFORME.md` §C.2 |
| `LOOKBACK` | Instancias de retardo de la tabla de pesos | `≥ 1`; candidato inicial 10 (F3) |
| `T_prueba_slots` | Vigencia de la prueba de disponibilidad | `> 0`; mayor que el intervalo típico de re-prueba honesta |
| `N_pausa` | Instancias sin certificado antes de declarar pausa observable | `≥ 1`; no tiene efecto de consenso (FV-20) |
| `Plazo_voto_instancias`, `f_voto` | Ventana de admisión y fracción confiscada del doble voto | `f_voto ∈ (0,1]`; `R_slots > duración(Plazo_voto_instancias) + M_margen_slots` (FV-EVP-05, no negociable) |
| `S_min_voto`, `K_min_voto` | Piso de activación | Análogos de `Φ`; no fijados |
| `c_fase` (por fase de GossiPBFT) | Duración de cada fase en función de `Δ` | `Δ` no medida (IPA B-05); símbolo |
| Esquema de firma | Ed25519 por plaza vs. BLS agregada | BLS recomendado (FV-14); introduce una dependencia nueva en la ruta de consenso — decisión de Katana |

No numéricos, para el director/Katana: (i) si se adopta BLS o se acepta el coste de Ed25519 con `K`
pequeño (FV-14); (ii) si se adopta el suelo `E` y con qué valor (§9, `INFORME.md` §C); (iii) si
`requisito(B)` lleva techo por clave, lo que cambiaría FV-EVP-06; (iv) la regla FV-19 (no adoptar un
certificado que contradiga la vista de `blue_work` propia) como mitigación de FV-18, con su coste de
viveza sin medir.
