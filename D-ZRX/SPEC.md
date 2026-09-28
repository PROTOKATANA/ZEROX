# SPEC-POS2T — Proof of Stake Space Time

**Estado: propuesta de investigación, no normativa.** Este documento propone una
reestructuración de SPEC.md. Ninguna regla entra en consenso por existir aquí. Los
parámetros, la prueba de seguridad y la integración enumerados al final son puertas de
activación, no valores que un implementador pueda completar por intuición.

La instrucción actual del usuario autoriza estudiar e incorporar stake y slashing en
PoST. La restricción de AGENTS.md contra comités de decisión sigue vigente: este
diseño **no** introduce votación de finalidad. Si se ratifica POS2T, AGENTS.md,
SPEC.md y las reglas de activación deberán reflejar la decisión de stake.

## Estado al 2026-09-28 (léase antes que el cuerpo)

*Tabla del director, forma de actualización elegida por Katana el 2026-09-28. **No cambia ninguna regla del cuerpo**:
dice qué parte sigue en pie, cuál quedó superada y dónde está lo vigente. El cuerpo se reescribirá como especificación
única al cerrar 0.0.2.* Lo implementado y medido en la red dev está en `D-ZRX/SPEC-0.0.1.md`, y la hoja de ruta en
`P-ZRX/HOJA-DE-RUTA.md`.

| Sección | Estado | Lo vigente |
|---|---|---|
| Cabecera | **Superada en dos puntos.** (1) Katana **adoptó** la finalidad por votos en principio (FV-D02, 2026-09-26; capa en 0.0.3): la frase «no introduce votación de finalidad» ya no describe el diseño. (2) `AGENTS.md` ya no está en el árbol (se borró en `849cb52`). Stake y castigo están **activos en la red dev**. Sigue sin ser normativa para producción | `P-ZRX/P-FINALIDAD-VOTOS/DECISIONES.md` (FV-D01…FV-D08), `AUTO-ZRX.md`, `SPEC-0.0.1.md` §6 |
| §0 Decisión y límite | **En pie.** PoAS + PoT siguen siendo condición para producir y el stake no da turnos. La ruta de arranque por PoW temporal está **adoptada e implementada** en dev (SHA3-256, sin premine, corte CUT-HWΦ con `K_min = 3`). El objeto castigable es la doble firma de la misma oportunidad C-GD-07, con `consensus_branch_id` (RAT-1). El límite de información se mantiene (RFT-01, RFT-14) | `SPEC-0.0.1.md` §2 y §6; `P-ZRX/P-TRANSICION/CONTRATO-v0.md` |
| §1 Requisitos E, A, R, C | En pie; verificación parcial con procesos reales | `D-ZRX/INFORME-0.0.1.md` |
| §2 Mapa de reestructuración | Pendiente; sustituido en la práctica por la hoja de ruta | `P-ZRX/HOJA-DE-RUTA.md` |
| §3 C-BON colateral | **Implementado en dev con forma propia**: garantía por clave con `q = 10` ZZK, retiro `R_SLOTS = 600`, liberación RAT-3 (`Plazo_slots` 300 + `M_margen_slots` 60 desde el último bloque producido), coinbase PoST acreditada entera a la garantía (D-T08). Pendiente: garantía por unidad de espacio (IPA C-02), retención con la forma del modelo (C-12, SL-2c) y liquidez del productor (C-13) | `P-ZRX/P-RED-DEV/PERFIL-DEV-v0.md`; `SPEC-0.0.1.md` §6 |
| §4 C-EVP evidencia | **Implementado y activo en dev**: `EvidenceTx` v4, EV-01…EV-28, RAT-1…RAT-3; medido con procesos reales (W07b E-8: confiscación en los tres nodos) | `P-ZRX/P-SLASHING/CONTRATO-EVIDENCIA-v0.md` (con su «Ratificación v0»), `DECISIONES.md` (DS-L01…) |
| §5 C-SLA penalización por cohortes | **Superada.** El castigo correlacionado quedó refutado (RFT-15: no disuade al grande y castiga a honestos). Lo vigente es la confiscación por incidente `C = mín(V, techo(f·V))`, con `f = 1` en dev, `suelo(C·2/8)` al incluidor y el resto quemado (DS-L03, RAT-2′). La ausencia de voto tendrá su propia falta (FV-D03…FV-D06) | `CONTRATO-EVIDENCIA-v0.md`; `D-ZRX/RFT-ZRX.md` RFT-15 y RFT-22 |
| §6 C-BOT arranque sin premine | **Ruta B adoptada e implementada** en dev (PoW SHA3-256 tras interfaz; el minero de producción, CPU y GPU AMD, en 0.0.4). La emisión PoST sin garantía queda solo como comparador, como dice el texto | `SPEC-0.0.1.md` §2; `P-ZRX/HOJA-DE-RUTA.md` |
| §7 Qué puede y qué no puede prometer | En pie. Se añade que el doble farmeo no se cierra (RFT-01, RFT-14) y que la finalidad por votos lo arrincona sin cerrarlo (FV-D02) | `S-ZRX/SEGURIDAD-HIBRIDO-2026-09-26.md` (§6 al día) |
| §8 Dependencias | Las de 0.0.1 están implementadas (11 crates). Registro de sectores y Filecoin sin activar (`SEC-0`; 0.0.2) | `SPEC-0.0.1.md`; `D-ZRX/IPA-ZRX.md` D-01…D-05 |
| §9 Puertas | **1 y 2 hechas para dev** en transición, estado y evidencia: oráculos Julia T01 y T04 conforme a LINEO, diferenciales Rust con 0 discrepancias. **3 parcial**: medido en localhost, sin eclipse ni censura (IPA B-07). **4 y 5 no hechas** | `V-ZRX/REGISTRO.md`; `D-ZRX/INFORME-0.0.1.md` |
| §10 Fuentes | Sin cambios | — |

## 0. Decisión y límite verificable

ZEROX conserva PoAS + PoT como condición para producir un bloque y GHOSTDAG con
blue_work derivado del rango PoAS como orden. El stake **no** da turnos, no multiplica
blue_work y no sustituye al espacio. Cada clave que produzca tras la activación debe
haber bloqueado tokens; las firmas públicas contradictorias de esa clave pueden
provocar la pérdida de parte de ellos.

Para una red nueva sin premine, la **ruta de arranque propuesta es PoW temporal**
para emitir los primeros tokens, seguida de PoAS + PoT + DAG con garantía
positiva. PoST sin garantía se conserva como comparador de seguridad, no
como fase de lanzamiento elegida. La preferencia responde al coste de
trabajo y energía que debe volver a pagarse al rehacer historia PoW;
no constituye todavía una prueba de que una red PoW joven resista más
que una red PoST concreta con otros recursos honestos.

El objeto castigable inicial es **doble firma de cabeceras para un mismo billete
C-GD-07**, aunque una cabecera quede en una rama perdedora. Un acto firmado deja
evidencia de la clave que firmó; no identifica necesariamente a la persona que
controlaba la máquina o un pool. Firmar una sola cabecera inválida no es falta.

**Límite de información.** Leer un disco, calcular soluciones, construir o abandonar
una rama privada y no publicar una cabecera no deja una prueba observable. Un atacante
también puede usar billetes diferentes en dos ramas. En esos casos la probabilidad de
obtener esta evidencia es cero. Ningún tamaño de depósito corrige esa ausencia.
POS2T no demuestra por sí mismo menor F_slots ni seguridad de pagos más rápida.

La frase «todo acto deja evidencia» queda precisada así: todo **acto de consenso
publicado y aceptado para procesar** tiene bytes autenticados y archivables. La
conducta privada y la mera ausencia de mensajes no se convierten en faltas. Esta
restricción es parte del contrato, no una excepción opcional.

## 1. Requisitos E, A, R y C

| Condición | Regla propuesta | Alcance y límite |
|---|---|---|
| E, evidencia | Dos cabeceras canónicas, mismo billete, prefirma distinta y sellos válidos | Prueba la doble firma publicada; no prueba doble farmeo oculto ni con otros billetes |
| A, atribución | El billete, el sello, el depósito y la recompensa usan la misma clave P | Atribuye responsabilidad a P; una clave robada o un pool custodial puede perjudicar al titular |
| R, retención | El retiro quita el derecho a producir de inmediato y mantiene el saldo castigable durante R_slots | Solo cubre pruebas observadas e incluidas antes de liberar; una partición/censura sin cota rompe cualquier plazo finito |
| C, correlación | Las faltas del mismo periodo se liquidan con una fracción común creciente | Escala la pérdida; no distingue con certeza fallo colectivo honesto de ataque coordinado |

El criterio económico para una estrategia x es comparar su ganancia incremental
esperada G_x con la pérdida esperada de colateral. La segunda depende de la
probabilidad **conjunta** de que exista prueba, se difunda, se incluya y permanezca
en la historia aceptada antes del retiro. Deben medirse bajo la misma red,
adversario, horizonte y regla de aceptación. Contra un atacante dispuesto a
perder cualquier suma de dinero, el stake no da una garantía absoluta.

    E_perdida(x) = suma_escenarios Pr(escenario | x)
                   × indicador(prueba estable antes de liberación)
                   × fracción_castigada × saldo_castigable

G_x, E_perdida y saldo_castigable se expresan en brek; la fracción y las
probabilidades no tienen unidad. Éste es el contrato de comparación del
modelo POS2T-v0.2, no una cifra medida ni un criterio ya satisfecho.

## 2. Mapa de reestructuración de SPEC.md

| Sección actual | Cambio necesario al ratificar |
|---|---|
| §0.2 y §18 | Registrar nuevas familias y estado de implementación; los identificadores provisionales del borrador anterior C-STK, C-EVI, C-PEN, C-VOT y C-ARR quedan reservados, sin reutilizar |
| §2 y §3–§4 | Codificar saldo de garantía y operaciones nuevas; añadir dominios separados para depósito, retiro, evidencia y liquidación |
| §5 y C-WIRE | Versiones y tipos explícitos de operaciones de garantía/evidencia; sus datos de efecto entran en txid, Merkle, peso, red y disco |
| §6.4 | Exigir garantía activa de sol.public_key en el estado causal validado antes de admitir un bloque |
| §7.1–§7.2 | Mantener PoAS, PoT, rango y la identidad C-GD-07; no atribuir al stake una prueba de espacio |
| §8.2 | Vincular la recompensa del bloque a sol.public_key; definir crédito retenido y su madurez |
| §11 | Mantener GHOSTDAG y blue_work sin ponderación por tokens; aplicar garantía y castigo en el orden C-ORD-03 |
| §12 | Persistir, deshacer y reproducir depósito, retiro, prueba, congelación, quema y exclusión junto con UTXO |
| §14–§15 | Especificar el arranque PoW temporal sin premine, los depósitos previos y el ancla de transición; no usar una altura DAG aún indefinida |
| §16 | Difusión, recuperación histórica y presupuesto de prueba/evidencia |

La vieja propuesta de finalidad por votos C-VOT-01…08 y sus temas de red se
**retira de POS2T**, sin reasignar esos identificadores. C-FIN-01 y la política de
confirmación de pagos conservan sus pendientes propios. Este archivo no modifica
SPEC.md hasta que se cumplan las puertas de §9.

## 3. Colateral de producción — familia nueva C-BON

**C-BON-01 · Registro agregado por clave.** El estado de consenso tiene para cada
clave P un registro de saldo activo, recompensa pendiente de madurez, saldo en
retirada y saldo congelado, más los identificadores de faltas procesadas. Su valor
total se conserva con el UTXO y la emisión. No se crean miles de UTXO de stake
por coinbase: una confiscación parcial debe tener coste acotado por clave y caso.
Los identificadores requieren una regla de poda determinista tras su plazo de
admisión, con undo; todavía no se acredita una cota global de memoria. Todo
campo tiene codificación canónica y aritmética entera comprobada.

**C-BON-02 · Depósito.** Una operación de depósito consume UTXO transparentes
autorizados y acredita exactamente el mismo valor al registro de P, menos una
tarifa explícita si existe. P firma la aceptación de la responsabilidad. El
depósito no crea moneda y solo cuenta como activo tras las reglas de madurez y
orden de aplicación. Una clave no puede retirar garantía que no le pertenece.

**C-BON-03 · Recompensa atribuida.** Desde la activación, la coinbase del bloque B
contiene un importe explícito y comprometido en txid/Merkle para acreditar
sol.public_key, solo cuando B cobra según R-FIN-8′. El importe se comprueba
contra subsidio más tarifas efectivamente aplicadas tras C-ORD-04; no se
acredita el máximo teórico ni tarifas de transacciones descartadas. Es un crédito
pendiente hasta cumplir C-EMIT-05; puede ser castigado desde que se aplica,
pero no cuenta para el mínimo de participación antes de madurar. La coinbase
no puede pagar otra clave, ni pagar una comisión de pool mediante otra salida.
El formato de coinbase y su efecto sobre txid/C-WIRE requieren una versión de
consenso nueva; no se infiere de la cabecera lineal actual.

**C-BON-04 · Entrada positiva.** Para un bloque B posterior a la activación:

    garantia_activa(P, past(B)) >= requisito(B) > 0
    P = sol.public_key

El requisito se deriva solo del pasado DAG validado, no del valor declarado
por B, de la punta local ni del orden de llegada. La función y su cuantía
quedan PENDIENTES de calibración; no se adopta la fórmula del borrador anterior
MINIMO_FRAC × emitido como parámetro por defecto. Si el requisito no cabe en
la oferta distribuida o impide la entrada de nuevos productores, la
activación no es viable. Un único depósito por clave no demuestra que la
pérdida potencial escale con todo su espacio ni con el beneficio de un doble
gasto: esas relaciones son parte de la evaluación económica.

**C-BON-05 · Retiro.** Una operación firmada por P mueve saldo activo a retirada.
Desde su aplicación deja de contar para C-BON-04, pero sigue castigable. A lo
sumo hay una retirada pendiente por clave; otra se rechaza o consolida por
una regla única todavía PENDIENTE. El inicio es slot_aplicacion de la
operación, definido en C-BON-07. La liberación exige
slot_aplicacion(liberación) >= slot_aplicacion(retiro) + R_slots y ningún caso
congelado. R_slots es una **duración en slots PoT**, no un índice, una altura
ni segundos. Debe satisfacer R_slots > Q_corr_slots + T_reporte_slots +
M_estabilidad_slots bajo la hipótesis de red elegida; M_estabilidad_slots
queda PENDIENTE. Ni esta desigualdad ni un R finito cubren censura o
partición sin cota.

**C-BON-06 · Liberación.** Solo P puede convertir saldo liberado en UTXO
PubKey{P}; la transición reduce el registro por la misma cantidad y nunca
acuña moneda. Antes de aplicar una liberación se procesan las liquidaciones
vencidas. El orden exacto frente a coinbase, transacciones y mergeset debe
ser el de C-ORD-03 y debe estar fijado antes de activar.

**C-BON-07 · Slot de aplicación.** Para cualquier operación de garantía o
evidencia, slot_aplicacion es el slot del primer bloque de la cadena
seleccionada que la aplica al fusionarla conforme a C-ORD-03, no el slot
de la cabecera que la transportó. Si esa cadena cambia, sus efectos y
slot_aplicacion se deshacen y recalculan. Un bloque antiguo fusionado
tarde no inicia un retiro ni presenta evidencia retroactivamente.

## 4. Evidencia — familia nueva C-EVP

**C-EVP-01 · Identidad de oportunidad.** Para esta versión la identidad es
consensus_branch_id y los cinco campos de C-GD-07:
(public_key, sector_index, history_size, chunk, slot). Ni el reto, ni la
rama, ni el hash de cabecera se añaden al identificador. Un futuro
identificador por pieza exigiría cambiar conjuntamente C-GD-07 y el pago:
no se sanciona como falta lo que el consenso permite producir.

**C-EVP-02 · Doble firma.** Hay prueba si dos cabeceras DAG canónicas tienen
la misma identidad C-EVP-01, prefirma/pre_hash diferentes y sendos sellos
Ed25519 válidos bajo la clave declarada, según C-HDR-03/04 y ZIP-215.
La prueba acredita **dos decisiones de firma**, aun si una cabecera no llegó
a ser bloque válido por otra razón. Una cabecera sola, dos firmas diferentes
de una misma prefirma, o dos billetes distintos no son esta falta.
El productor debe tratar la firma de un segundo contenido como una acción
castigable, incluso tras reiniciar o reorganizar su nodo.

**C-EVP-03 · Incidente único.** El identificador de la falta es
H_d(dominio_incidente, identidad C-EVP-01), no el hash del par de cabeceras.
Tres cabeceras del mismo billete pueden formar tres pares, pero el incidente
se registra y se castiga una sola vez. La codificación del dominio y de
EvidenceTx queda PENDIENTE. EvidenceTx es un tipo explícito distinto de
coinbase: contiene exactamente dos cabeceras ordenadas por pre_hash,
sin entradas ni salidas monetarias. Su versión, los bytes de ambas
cabeceras y el tipo deben quedar comprometidos en txid, Merkle y peso;
nunca solo en un testigo no comprometido. C-TX-17 gana una excepción
explícita y el nodo no infiere coinbase de la mera ausencia de entradas.
No hay campo de denunciante sin recompensa.
EvidenceTx se deduplica por incidente y se acota por los tamaños de
cabecera y peso de SPEC.md, con presupuesto de CPU y red PENDIENTE.
Si dos ramas aportan pruebas del mismo incidente, solo la primera
aplicada en C-ORD-03 produce efecto; la otra queda inerte como
duplicado contextual al fusionarse, sin invalidar retrospectivamente
su bloque de origen.

**C-EVP-04 · Contexto y admisión.** La falta sancionada es **firmar dos
afirmaciones de producción** bajo el identificador de rama POS2T,
aun si una no era un
bloque PoST válido. Por ello la prueba criptográfica no requiere
reconstruir una rama perdedora ni demostrar garantía histórica en dos
pasados incompatibles. Al aplicarse la evidencia, se consulta el saldo
castigable de P en el estado seleccionado y aplicado: si no hay saldo,
no se inventa una confiscación. La validación PoST de la cabecera
perdedora es una cuestión separada y no se finge mediante dos firmas.
La prueba solo produce efecto al aplicarse en el orden C-ORD-03; su
presencia en mempool o en un bloque que no se aplica no congela fondos.
Esto define responsabilidad de la clave por lo firmado; aún falta
delimitar la responsabilidad económica de firmas hechas antes del
depósito o después de iniciar retiro. La garantía R solo se reivindica
para bloques producidos mientras P tenía garantía activa en su pasado
causal, y su verificación histórica entre ramas es PENDIENTE.

**C-EVP-05 · Plazo y disponibilidad.** La admisión para una falta del periodo e
exige slot_falta <= slot_aplicacion(EvidenceTx) < cierre_e de C-SLA-01.
Una prueba en
un bloque antiguo fusionado después se rechaza como tardía. Los nodos conservan
cabeceras de ramas y pruebas durante una retención mayor que el plazo de
denuncia y ofrecen recuperación histórica bajo presupuesto. Esto **no**
garantiza que una segunda cabecera oculta se publique o que una prueba
difundida entre en una historia aceptada.

**C-EVP-06 · Firmante seguro.** El productor debe conservar duraderamente
identidad de billete → pre_hash antes de firmar y negarse a firmar otra
prefirma para ese billete. Es defensa operativa contra accidentes, no regla
verificable de validez ni protección entre dos máquinas con registros
separados. Pools y firmantes remotos requieren autorización limitada y
análisis propio de responsabilidad.

## 5. Penalización — familia nueva C-SLA

**C-SLA-01 · Cohorte por slot de la falta.** Sea Q_corr_slots > 0 la longitud de un
periodo de correlación, parámetro PENDIENTE. Para una falta en slot s:

    e = piso(s / Q_corr_slots)
    cierre_e = (e + 1) × Q_corr_slots + T_reporte_slots

Solo pruebas aplicadas con slot_aplicacion < cierre_e integran la cohorte.
La cohorte se define por el slot firmado, no por el instante elegido por
el denunciante para publicar. Un bloque que salta slots procesa todos los
cierres cruzados en orden creciente **antes** de aplicar su mergeset,
evidencias, retiros y liberaciones. Una prueba que llega en ese bloque
para una cohorte ya cerrada es tardía. El máximo de casos y cierres
liquidados por bloque, y su coste frente al peso, son PENDIENTES:
S_max_slots no limita el número de pruebas acumuladas.

**C-SLA-02 · Congelación.** La primera prueba admisible de un incidente
congela el saldo castigable de P disponible en ese momento y registra
el incidente. Una segunda prueba del mismo incidente no lo vuelve a
congelar ni cobrar. Los incidentes distintos de P en la misma cohorte
forman un caso (P,e); una clave se cuenta una vez en esa cohorte.
Si P tiene casos de varias cohortes, comparten un único saldo
congelado y se liquidan en orden creciente de e, debitando el saldo
remanente; ninguna unidad se quema dos veces. La admisión de otro
caso no descongela el primero. Mientras haya caso abierto, P no
produce ni libera saldo. Sin saldo, se registra pérdida cero.

**C-SLA-03 · Correlación y liquidación.** Al cerrar e, se calcula sobre el
estado seleccionado y aplicado:

    n_e = número de claves P distintas con caso admisible (P,e)
    f_e = min(1, b + c × max(0, n_e − 1))
    V(P,e) = saldo congelado remanente de P antes de liquidar e
    perdida(P,e) = min(V(P,e), techo_exacto(f_e × V(P,e)))

El dominio elegido es 0 < b <= 1 y c >= 0, ambos racionales de
consenso; sus valores, codificación racional y ancho entero quedan
PENDIENTES. techo_exacto es división entera comprobada que redondea
hacia arriba; con V(P,e)>0 y b>0 la pérdida mínima es una unidad brek.
Si n_e = 0 no hay liquidación. Todos los infractores de la cohorte
reciben la misma fracción f_e, con independencia del orden de
inclusión **dentro de esa cohorte**; el saldo disponible de una clave
con varios casos sí depende de las pérdidas anteriores y se procesa
en orden de e. La liquidación quema la pérdida y devuelve el
remanente a su condición previa, activo o en retirada, solo cuando
P ya no tiene casos abiertos. Se registra undo completo. **Hasta
cerrar codificación y presupuesto de liquidación esta
regla no es implementable.** No hay recompensa al denunciante en
esta versión. La inclusión voluntaria de EvidenceTx y su coste de
red deben medirse; sin incentivo ni obligación verificable no se
presume una probabilidad positiva suficiente.

**C-SLA-04 · Alcance de la correlación.** C solo incrementa el castigo
respecto a una base positiva. No demuestra que muchas firmas dobles
sean maliciosas: un error compartido de software también puede estar
correlacionado. Un atacante puede espaciar faltas, censurar pruebas o
repartir claves. El modelo económico debe comprobar tasa de castigo
honesto, coste de entrada y pérdida mínima frente al beneficio del ataque.
Una clave puede respaldar mucho espacio con una sola garantía y su
pérdida total no puede superar su saldo: no se afirma disuasión de
beneficios arbitrarios ni que se queme un tercio del stake por
analogía con Casper.

## 6. Arranque sin premine — familia nueva C-BOT

**C-BOT-01 · Imposibilidad inicial.** Con génesis de valor cero y sin premine
(C-EMIT-02, C-GEN-03), ninguna clave puede poner tokens positivos antes
del primer bloque. Por tanto «todo productor arriesga tokens desde el
génesis» es incompatible con ambas reglas. No se presenta la futura
recompensa de un bloque aún inexistente como stake ya depositado.

**C-BOT-02 · Comparador: emisión PoST sin garantía.** Una red nueva
podría producir bloques PoST/DAG antes de exigir C-BON-04 y distribuir
así la primera emisión, pero esta ruta no se adopta para el diseño de
lanzamiento POS2T. Durante esta fase POS2T no añade pérdida de
tokens por mala conducta: los riesgos de reescritura, doble farmeo y
captura de la distribución inicial siguen siendo los del PoST/DAG sin
garantía. El coste de ocupar y preparar espacio no equivale a una
confiscación de stake. Se conserva como comparador, sin llamarlo
arranque seguro; necesita un modelo del espacio honesto y
adversario, del PoT y de la red, con riesgo de reversión cuantificado.

**C-BOT-03 · Entrada posterior.** Tras la activación, una clave nueva
necesita obtener tokens por recompensa previa o transferencia y
depositarlos. Esto introduce una barrera de entrada y riesgo de
concentración. No se oculta bajo el nombre de «participación libre».

**C-BOT-04 · Ruta propuesta: emisión PoW temporal.** El génesis conserva
coinbase de valor cero; los bloques posteriores de la fase inicial
emiten mediante PoW. Desde el corte definido de consenso, los
bloques son PoAS + PoT + DAG y exigen garantía activa; PoW deja
de autorizar bloques. Esta opción desplaza el recurso de seguridad
inicial a trabajo y energía gastados continuamente. Rehacer una rama
PoW exige volver a invertir trabajo de hash; la misma parcela PoST
puede consultarse para retos de ramas distintas, aunque
plotear, mantener el disco y calcular PoT tampoco son gratuitos. Ésta
es la razón concreta para preferir PoW durante el arranque. PoW tampoco
confisca tokens por faltas anteriores al corte. Solo mejora el
arranque frente al candidato A si el hash honesto efectivo resiste al
adversario, incluido el hash alquilable, bajo el mismo riesgo y
horizonte. La dificultad nominal no prueba esa condición. La emisión
PoW puede concentrarse entre mineros y no implica distribución justa.
No se han elegido algoritmo, dificultad inicial, reajuste, recompensa,
duración ni criterio de aceptación. Esta opción reintroduce un minero,
un verificador y una rama de sincronización que el nodo actual no
tiene completos; no se considera una simple conmutación de parámetro.

**C-BOT-05 · Preparación y ancla del corte PoW.** Si se elige B, antes
del primer bloque PoST con C-BON-04 debe existir una ventana de emisión,
madurez C-EMIT-05 y depósitos C-BON-02 **admitidos y aplicados bajo las
reglas PoW**. De otro modo la garantía activa es cero y el primer
bloque PoST no puede ser válido. El corte debe fijar qué historial PoW
determina UTXO, garantía, emisión, identificador de rama y semilla/slot
iniciales de PoT. También debe fijar la historia y el conjunto de datos
PoAS que permiten plotear y verificar el primer bloque PoST: C-EXP-01/02
requieren una referencia histórica anterior al bloque productor. Las
coinbases PoW aún inmaduras en el corte necesitan una regla explícita
de madurez posterior. Una altura o un umbral de trabajo por sí solos
pueden tener varios bloques terminales; aceptar dos anclas sin regla de
selección puede partir el DAG y las garantías. Se necesita una regla
explícita para ramas PoW tardías y para la selección entre historias
PoST de anclas distintas, o un hash terminal fijado mediante un
checkpoint de lanzamiento con su supuesto de confianza y procedimiento
de coordinación publicados. Un número finito de confirmaciones PoW
reduce riesgo bajo hipótesis de hash, pero no proporciona finalidad
determinista. El checkpoint C-CHK actual depende del rango PoST y no
resuelve este corte sin rediseñarlo. C-FLU-06 actualmente deriva el
flujo y la semilla desde el génesis DAG: usar un bloque PoW terminal
exige redefinir ese origen, su entropía y la protección frente a
precomputación o sesgo del minero terminal sin circularidad.
Una red existente requeriría además un hard fork y protección de
repetición C-UPG; el significado de altura DAG debe cerrarse primero.

**C-BOT-06 · Puerta de ratificación.** PoW temporal es la ruta de diseño
preferida; PoST sin garantía queda como comparador. Antes de aprobar
el lanzamiento deben separarse el inicio de emisión, el momento en que
se admiten depósitos y la primera obligación positiva; sus reglas de
estado y madurez han de ser
deterministas. Debe comprobarse la garantía madura disponible para
nuevas claves y el espacio PoAS operativo en el corte; varias claves
no demuestran operadores independientes. Si faltan recursos, debe
especificarse de antemano el fallo de activación. La ratificación requiere
comparar probabilidad de reversión, captura de emisión, continuidad del
estado y consumo energético bajo el mismo adversario, red, horizonte y
política de aceptación. La preferencia de diseño no equivale a una
ventaja de seguridad medida: con poco hash honesto, el trabajo absoluto
necesario para reescribir el arranque también puede ser pequeño.

## 7. Lo que esta arquitectura puede y no puede prometer

| Conducta | Prueba de C-EVP | Pérdida posible |
|---|---|---|
| Dos cabeceras públicas del mismo billete y clave | Sí, si llegan e ingresan antes del cierre | Fracción de garantía congelada |
| Dos soluciones/billetes distintos, aun de una parcela | No bajo C-GD-07 actual | Ninguna por C-SLA |
| Rama privada que nunca revela una segunda firma | No | Ninguna por C-SLA |
| Censura, eclipse, retención de bloque, adelanto PoT o borrar datos | No como doble firma | Ninguna por C-SLA |
| Firmas dobles por error o clave comprometida | Sí | También castigables; no se atribuye intención |

La finalidad de C-FIN-01 y el riesgo de reversión deben evaluarse
por separado. Un pago de beneficio G superior a la pérdida esperada
puede seguir siendo rentable. Para un adversario de Estado, el análisis
debe dar escenarios de recursos, tolerancia a pérdidas, red, censura y
objetivo; no se afirma disuasión universal por tener un depósito.

**Ampliaciones de E que requieren otra decisión.** Sancionar dos
cabeceras de la misma clave en un slot, aunque usen billetes distintos,
obligaría a limitar también a **una propuesta por clave y slot**:
de otro modo se castigaría producción que el PoST actual permite.
Sancionar dos soluciones de la misma pieza exigiría modificar a la
vez la identidad y el pago de C-GD-07. Ambas opciones tienen coste
honesto, efecto de división en claves y dependencia del verificador
PoAS que deben medirse antes de formular una regla. Tampoco hacen
observable una rama que jamás se publique.

## 8. Dependencias de implementación

- Tipos, dominios, txid y códec canónico en zx-core; prueba y operación
  de garantía no pueden ser interpretadas como coinbase por carecer de
  entradas.
- Validación contextual de PoST y de la garantía en zx-consensus;
  ninguna ruta pendiente puede aceptar provisionalmente un bloque.
- Registro de garantía, índices por clave/incidente, transición atómica
  y undo en zx-storage, en el orden C-ORD-03. Un mismo pasado debe
  producir exactamente el mismo saldo y resultado de C-SLA.
- zx-node debe integrar la cabecera DAG, el orden y estado UTXO antes
  de usar POS2T en la ruta activa. zx-p2p debe presupuestar y servir
  evidencia histórica.
- Si se adopta C-BOT-04, mantener y verificar ambas familias de bloque
  en la misma historia, con depósitos previos al corte y sincronización
  desde génesis; la cabecera lineal heredada no implementa por sí sola
  el bootstrap PoW propuesto.
- Las primitivas Ed25519/ZIP-215 y PoT existentes se reutilizan, sin
  introducir criptografía nueva por esta propuesta.

## 9. Puertas antes de ratificar o activar

1. Resolver cada PENDIENTE de codificación, estado, calendario,
   redondeo, madurez, reserva, liberación, activación y presupuesto,
   incluida la relación entre firma, depósito y retiro en ramas
   distintas, conservando identificadores estables. No inventar un número.
2. Probar con casos exhaustivos pequeños la unicidad de incidente,
   conservación monetaria, reversión exacta, independencia del orden
   de llegada y rechazo de pruebas sin contexto. Implementar un
   oráculo Julia CPU conforme a veritas/LINEO.md; C++/CUDA solo si un
   perfil demuestra que merece la pena.
3. Definir antes de medir el evento de fallo, clase de adversario,
   versión del modelo, riesgo máximo aceptable y coste máximo
   tolerable para productores honestos. Medir conjuntamente
   publicación, difusión, inclusión y estabilidad
   de la prueba y plazo de retiro bajo red honesta, degradada,
   particiones, eclipse y censura. Una media o p99 no es una cota.
4. Comparar los candidatos A y B durante arranque y transición, y
   luego PoST puro y POS2T, con el mismo adversario, red, horizonte,
   beneficio G y criterio de aceptación. Para B, medir hash honesto y
   alquilable, reversión del prefijo PoW, concentración de recompensas,
   garantía madura en el corte, estados incompatibles entre nodos,
   sesgo de semilla terminal, fallo de activación y coste energético;
   para A, medir espacio efectivo y control de PoT. Publicar
   pérdidas esperadas, liquidez requerida, entradas impedidas,
   confiscaciones honestas, producción perdida durante congelación,
   efecto de errores colectivos y sensibilidad a los parámetros.
5. Solo si la capa demuestra una mejora material bajo supuestos
   explícitos, decidir la modificación de AGENTS.md y SPEC.md,
   implementar la migración PoST/DAG y preparar una activación
   reproducible. Los tests del código lineal no certifican POS2T.

## 10. Fuentes y procedencia

Base normativa aún vigente: SPEC.md §§0, 4–8, 11–16;
README.md; MIGRACION.md. Evidencia local: research/README.md,
P-ZRX/P-EQUIVOCACION/investigacion/INFORME.md,
P-ZRX/P-EQUIVOCACION/investigacion/FALSOS-POSITIVOS.md,
P-ZRX/P-FIRMANTE/informe/INFORME.md,
P-ZRX/P-POOLS/investigacion/DECISIONES-PENDIENTES.md,
P-ZRX/P-STAKE/MAPA.md y veritas/LINEO.md.
Las cifras de esos informes pertenecen a sus modelos y máquinas;
ninguna es un parámetro de consenso de POS2T. Referencias primarias
para evaluar C-BOT-04/05: Bitcoin, *A Peer-to-Peer Electronic Cash
System* (§§4, 11), https://bitcoin.org/bitcoin.pdf; Chia,
*Chia Consensus*, https://www.chia.net/wp-content/uploads/2022/09/Chia-New-Consensus-0.9.pdf;
EIP-3675,
https://eips.ethereum.org/EIPS/eip-3675 (bloque terminal y cambio de
regla de selección); DCP-0012,
https://github.com/decred/dcps/blob/master/dcp-0012/dcp-0012.mediawiki
(la distribución por PoW no resultó necesariamente amplia). Ethereum
dispuso de una cadena de validadores PoS ya activa durante su
transición; ese precedente no prueba el corte de
ZEROX, que no tiene una capa de finalidad equivalente.
