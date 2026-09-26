# INFORME — FV-1 · Capa de finalidad por votos bajo R1–R5

**Orden:** FV-1. **Ejecutor:** Sonnet, en solitario (sin subagentes, por mandato). **Fecha:** 2026-09-26.
**Contrato que analiza:** `deepseek/FV1/CONTRATO-FINALIDAD-VOTOS-v0.md` (mismo directorio).

**Comprobación de entrada.** `cd /home/katana/zeo/ZEROX && sha256sum -c P-ZRX/P-FINALIDAD-VOTOS/ENTRADA-FV1.sha256`
→ **la suma coincide** en las 10 entradas listadas, comprobado al empezar la orden y repetido al
terminar (ver `HUELLAS.sha256` de esta zona para la comprobación final).

Etiquetas: **[P]** fuente primaria leída íntegra o en su sección relevante en esta orden · **[S]**
fuente secundaria (resumen/cita ya verificada por otra sesión del repositorio, no releída aquí bit a
bit) · **[D]** derivación propia sobre reglas ya fijadas · **[H]** hipótesis de este informe, no
probada. Ninguna cifra sin fuente: todas remiten a `calc/resultados/*.tsv` o a un documento citado.

---

## 1 · Respuesta a la pregunta falsable

> «Existe una capa de finalidad por votos que cumple R1–R5 a la vez y en la que (a) ningún atacante
> cuyo peso, sumado al de los honestos apagados, sea menor que un tercio del peso total puede pausar ni
> romper el sello; (b) romper el sello deja siempre firmas contradictorias de al menos un tercio del
> peso total, castigables con una garantía que crece con el peso; (c) con la capa pausada, rota o sin
> activar, ningún nodo queda peor que con `C-FIN-01` sola; (d) en marcha normal, el tiempo hasta el
> sello es menor que `F_slots` como función de `Δ` y del número de votantes.»

**Respuesta: SÍ existe un diseño que cumple las cuatro condiciones a la vez — pero no el diseño obvio
(el de la propuesta antigua, ni una lectura ingenua de F3), y no con cualquier fuente de peso.** Se
encontraron dos contraejemplos reales durante esta orden; el primero se cierra con una regla nueva de
este contrato (FV-01b), el segundo **no se cierra** y queda como refutación parcial declarada.

### 1.1 · Contraejemplo 1 (encontrado y CERRADO en este contrato): partición de red rompe (c) sin FV-01b

**Refutación.** Con la lectura literal de la propuesta antigua (`research/dag-poas-capa-finalidad.md`
R-FIN-15: la tabla de poder «es función de `past(A_n)` y de nada más, luego todo nodo honesto calcula la
misma») **[S]**, una partición de red pura —sin ninguna clave firmando dos votos— basta para que las dos
mitades certifiquen historias contradictorias: cada mitad recalcula la tabla de poder **desde su propio
`past` local**, que por construcción solo contiene las claves que esa mitad puede ver, y sobre esa tabla
local le basta su propia mayoría honesta interna (posiblemente muy inferior a un tercio del peso real de
toda la red) para reunir `2/3` de **su tabla**. No hay doble firma que atrapar (FV-23 no se dispara) y
sin embargo el sello se rompe: es **peor que `C-FIN-01` sola**, que ante la misma partición no produce
ningún objeto que parezca autoritativo para todo el mundo. Esto refuta (c) —y, dicho con la fuente de
peso (A), también pone en duda (a): la mitad minoritaria «rompe el sello» con mucho menos de un tercio
del peso real—. Detalle completo, con el mecanismo exacto, en `CONTRATO-FINALIDAD-VOTOS-v0.md` FV-01b.

**Por qué no está en la literatura consultada como advertencia explícita, y por qué sí se encuentra
aquí.** `CONTEXTO.md` §4.1 declaraba la hipótesis contraria —«como mucho sella un lado; el otro se
pausa»— **marcada expresamente como «sin comprobar contra el modelo de P-FLUJO»** [D del director]. Esta
orden la comprobó y la encontró **falsa** para el diseño sin blindaje. F3 real, sin embargo, no tiene
este agujero: FIP-0086 dice que la tabla de una instancia sale de «the chain state resulting from the
tipset **finalized by a previous instance**» **[P]** — está encadenada a una instancia YA finalizada,
no recalculada libremente. La propuesta antigua de ZEROX (2026-09-09) tomó la fórmula de F3 pero no
tradujo esta salvaguarda con precisión.

**Cierre.** `FV-01b` (nuevo en este contrato): la tabla de poder de la instancia `n` es la que el
certificado de `n-1` comprometió (por hash, `FV-03`), no una que cada nodo recalcule libremente; solo la
tabla de arranque (antes de que exista ningún certificado) se deriva directamente de `past`. Con esta
regla, ninguna mitad de una partición puede fabricar una tabla más favorable que la última compartida
antes de partirse, y el argumento del contraejemplo deja de aplicar. **Residuo declarado:** la ventana
de arranque (antes del primer certificado, `FV-28/29`) no tiene este blindaje — es la misma ventana que
el ataque 11 (activación prematura) ya señala.

### 1.2 · Contraejemplo 2 (encontrado, NO cerrado): con fuente de peso (A), (b) se refuta

**Refutación.** Con la fuente de peso **(A)** (bloques cobrados en una ventana), el peso de una clave
**no tiene ninguna garantía asociada**: `Garantía[pk]` de `C-BON` puede ser cero para una clave que
cobra mucho. Un atacante que reúna un tercio del peso por esta vía y firme dos votos contradictorios
(FV-23) **deja evidencia verificable** —la primera mitad de (b) se cumple— **pero no hay nada que
confiscarle**: `pérdida = mín(V, techo_exacto(f·V))` con `V = 0` da `pérdida = 0` (mismo mecanismo que
`EV-22`, la «grieta» ya conocida de `P-ZRX/P-CLAVE/`). **(b) exige explícitamente «castigable con una
garantía que crece con el peso»; con la fuente (A) esa garantía no existe, así que (b) es FALSA para
esa fuente.** Con las fuentes **(B)** (si el registro de sectores llega a tener colateral por sector,
hoy no cerrado, `P-REGISTRO-SECTORES/ANALISIS.md` puertas G1-G2) o **(C)** (garantía `C-BON`, que ya
existe), (b) se sostiene: el peso **es** —o está respaldado por— la garantía, y confiscar una fracción de
ella confisca algo proporcional al peso.

**No se cierra en este contrato** porque cerrarlo exigiría o bien atar una garantía a la fuente (A) —lo
que la convierte de facto en una variante de (C)— o bien declarar (A) inadecuada para el voto. Este
informe recomienda la segunda salida (§3), sin imponerla: es la decisión de Katana sobre la fuente del
peso (§7 de `CONTEXTO.md`), que este encargo tiene mandato de **comparar**, no de resolver.

### 1.3 · (a) y (d): SOSTENIDAS, con una precisión sobre el sorteo

**(a) se sostiene de forma más fuerte que en la propuesta antigua, precisamente por quitar el sorteo.**
Con voto directo ponderado (sin plazas, `FV-06`) el quórum es aritmética determinista sobre el peso real,
no una variable de un sorteo: `sin_sorteo_pausa_posible(a) = (a ≥ 1/3)` sin margen de azar
(`calc/resultados/b2-sin-sorteo-determinista.tsv`, reproducido en la tabla de §4). La propuesta antigua,
al sortear `K` plazas, dejaba una probabilidad **positiva** de que un atacante con `a < 1/3` pausara la
finalidad **por pura suerte del sorteo** —cuantificado de nuevo en `calc/resultados/b2-reproduccion-4A.tsv`
(p. ej. `K=1000`, `a=0,30`: `P(≥1/3 del comité) = 0,0109`, no cero— y esa vía **desaparece por completo**
al no haber sorteo. **[D]**, comprobación cruzada en `calc/resultados/b2-reproduccion-4A.tsv` (coincide en
orden de magnitud con `research/dag-poas-capa-finalidad.md` §4.A, ver §4 de este informe).

**(d) se sostiene con un margen grande en el caso normal, y deja de sostenerse bajo censura sostenida.**
`calc/resultados/b4-ventana-doble-farmeo.tsv`: con `Δ_F = 0,60 s` (la más cercana a la `Δ` de red
simulada de ZEROX, DMS-v0.1, p99) y `LOOKBACK = 10`, el tiempo hasta el sello en el caso optimista
(ninguna ronda fallida) es **39,6 s**, frente a `F_slots·τ = 7200 s` (`F = 2 h`): razón **182×**. Incluso
con dos rondas fallidas (`ronda_max=2`, censura moderada) sigue siendo **26×** más rápido. **Deja de
serlo** bajo censura sostenida: con `Δ_F = 0,60 s` y **7 rondas fallidas consecutivas** el tiempo hasta
el sello (10 098 s) ya **supera** `F_slots` (`calc/resultados/b4-censura-rondas.tsv`); con
`Δ_F = 6,0 s` (el valor que usa Filecoin para su propia red) bastan **3 rondas** (5 940 s < 7200 s, pero
la 4.ª ya lo supera: 12 276 s). **(d) es una mejora del caso normal, no una garantía bajo censura
arbitraria** — exactamente la misma advertencia que la propuesta antigua hacía sobre el quórum (§4.C),
trasladada aquí a la latencia. Es el ataque 9 del análisis adversarial (§5).

### 1.4 · Conclusión de esta sección

**No hay incompatibilidad demostrada entre dos de R1–R5.** Hay una **tensión** entre R1 (entrada sin
permiso) y R5 (garantía que crece con el peso): hacer que R5 muerda para *todo* votante exige exigir un
depósito como precondición de voto, que es un coste mecánico y permissionless (mismo estatuto que
`requisito(B) > 0` de `C-BON-04`, ya aceptado en el repositorio como compatible con «sin comités»), no
una violación de R1. Se declara la tensión, no se demuestra una incompatibilidad (mandato §3.1).

---

## 2 · Tabla R1–R5

| Regla | Estado | Motivo / contraejemplo |
|---|---|---|
| **R1** · Entrada abierta | **Se cumple** | `FV-06`: todo el que tenga `peso ≥ q_voto` vota; no hay sorteo ni elección de quién entra (`FV-07` retira explícitamente el filtro `W_VIVO` de la propuesta antigua por violar R1) |
| **R2** · Sin elección, peso = recurso en cadena | **Se cumple con condición** | El peso es función de `past` para las tres fuentes (`FV-01`), pero la propagación de la tabla **debe** encadenarse por certificado (`FV-01b`) y no recalcularse libremente en cada nodo — sin esa condición, R2 se vuelve node-relative bajo partición (contraejemplo 1, §1.1) y deja de ser «el mismo recurso verificado en la cadena» para todos |
| **R3** · Nadie indispensable | **Se cumple** | Patrón *ebb-and-flow* (`§0` del contrato): PoAS+PoT+DAG nunca espera a los votantes; sin quórum, la capa se pausa (`FV-20`), nunca se detiene la producción. `C-FIN-01` sigue de red de seguridad sin cambios |
| **R4** · Sin decidir contenido | **Se cumple** | `FV-10`/`FV-14`: el único valor votable en la instancia `n` es el bloque ya seleccionado por GHOSTDAG en el punto de `lookback`, o `⊥`. No hay campo de contenido libre |
| **R5** · Toda falta deja firma y castigo | **Se cumple con condición, FALLA con la fuente (A)** | La firma doble siempre deja evidencia (`FV-23/24`, verificación `O(1)`), pero la garantía confiscable solo existe con las fuentes (B) —condicional a colateral de sector, hoy no cerrado— o (C) —ya existe—. Con (A), `pérdida = 0` siempre (contraejemplo 2, §1.2): **R5 no muerde con esa fuente**, declarado sin rodeos como exige el mandato §6.7 |

---

## 3 · Comparación de las tres fuentes de peso, y recomendación

| | **(A) bloques cobrados** | **(B) sectores registrados** | **(C) garantía `C-BON`** |
|---|---|---|---|
| **R1** | Cumple; peso nace de producir, sin registro | Cumple; el registro no exige permiso, solo depósito (mismo estatuto que C) | Cumple; depositar no exige permiso |
| **R2** | Cumple, con `FV-01b`; es la fuente **más pura** en el sentido de no depender de ningún estado adicional al DAG mismo | Cumple, con `FV-01b`; depende de un registro que **no existe hoy** (`SEC-0` activo, `SEC-A` abstracta, `P-ZRX/P-TRANSICION/CONTRATO-v0.md` §8) | Cumple, con `FV-01b`; pero el «recurso» pasa a ser moneda, no espacio — cambia el sentido de `SPEC.md` §0 (`C-BON-03/04` ya avisan de esto) |
| **R5** (¿garantía proporcional?) | **NO.** Sin garantía ligada al peso; contraejemplo 2, §1.2 | **Condicional**: solo si el registro añade colateral por sector (F4 de `P-DISUASION/SINTESIS.md`); **hoy no cerrado** (`ANALISIS.md` puertas G1/G2 sin superar) | **SÍ.** El peso es literalmente la garantía; `EV-*` ya calibrado (SL-1/SL-2) |
| **Coste al honesto** | Ruido: varianza alta, un granjero pequeño puede tener peso 0 en una ventana por mala suerte (mismo fenómeno que `H-4` de `ESTADO-DOBLE-FARMEO.md` para `chunk`); sin barrera de entrada monetaria | Barrera de entrada = colateral de sector, regresiva por tamaño (mismo patrón que `M1` en `P-DISUASION/SINTESIS.md`); depende de un sistema que no existe | Barrera de entrada = comprar/mantener stake; ya calibrada por SL-2 (**refutada para el honesto diminuto**, `f_h ≲ 10⁻⁵`, recomienda garantía **por unidad de espacio**, no por identidad) |
| **Qué puede hacer el atacante** | Sesgar la tabla reteniendo/publicando bloques a conveniencia (ataque 3, §5); reunir peso sin arriesgar nada propio más allá del espacio ya usado para producir | Igual que (A) en el sesgo de tabla, pero el registro con edad (si existe) encarece la entrada masiva justo antes de activar (mismo argumento que F1/F4 de `P-DISUASION/SINTESIS.md`) | Comprar peso de voto con dinero, sin tocar el espacio — es la puerta que `SPEC.md` §0 cierra hoy para la producción y que esta fuente reabriría para el voto |
| **Listo para v0** | **Sí**, no depende de nada nuevo | **No**: depende de `P-REGISTRO-SECTORES`, que sigue en G1/G2 (`ANALISIS.md`) y está declarado **fuera de 0.0.1** | **Sí**: `C-BON`/`C-EVP`/`C-SLA` ya especificados (POS2T) y con SL-1/SL-2 ratificados |

### Recomendación del director (Sonnet, esta orden)

**No adoptar (A) para v0**, a pesar de ser la más pura frente a R2 y la más fiel al espíritu de Katana
(«ZEROX sobrevive con sus cultivadores»): **R5 no muerde con ella (contraejemplo 2), y eso no es un
defecto de calibración, es estructural** — no existe ninguna fracción `f` ni ningún `Plazo_voto_slots`
que arregle `pérdida = mín(0, ·) = 0`. Una capa donde romper el sello no cuesta nada al que lo rompe (más
allá de la evidencia pública, que no tiene consecuencia económica) no cumple el mandato de Katana de
«castigable con una garantía que crece con el peso».

**Adoptar (C) para el contrato v0**, como compromiso **declarado y provisional**: es la única fuente que
hoy tiene, a la vez, tabla de poder computable (`Garantía[pk]`, ya en `SPEC.md` §3 de POS2T) y mecanismo
de evidencia/castigo ya calibrado (`SL-1`/`SL-2`). El precio, dicho en voz alta, es exactamente el que
`CONTEXTO.md` §7.1 ya anticipaba: «(C) stake: más simple, pero la finalidad pasa a quien tiene moneda» —
y `SPEC.md` §0 tendría que declarar explícitamente que esa excepción **solo** aplica a la capa de votos,
nunca a la producción ni a `blue_work` (que siguen siendo PoAS+PoT puros, sin cambio).

**Migrar a (B) cuando `P-REGISTRO-SECTORES` cierre G1–G2** es el objetivo de fondo, más fiel a la razón
de Katana para pedir esta capa (mineros y cultivadores, no tenedores de moneda). No se recomienda
esperar a (B) para ratificar el contrato: FV-01…FV-30 están escritas con `FuenteDePeso` como interfaz
sustituible (`FV-01`) precisamente para que ese cambio no exija reabrir el resto del diseño.

**(A) queda descartada para el voto, no para la producción.** Nada de esto toca que PoAS+PoT sigan
siendo la fuente de oportunidades y `blue_work` (mandato §3.2): (A) simplemente no es una buena fuente
de **peso de voto**, con las tres fuentes comparadas bajo el mismo criterio.

---

## 4 · Análisis adversarial

Convenciones de columna: **imposible** = ningún recurso finito conocido lo consigue bajo el contrato;
**caro** = posible con coste absoluto declarado; `a` = fracción del peso total del atacante; `o` =
fracción de honestos apagados; **firmado** = deja `EV-VOTO` verificable.

| # | Ataque | `a` | `o` | Control de red | Qué puede hacer | Coste absoluto | Firmado | Imposible/caro |
|---|---|---|---|---|---|---|---|---|
| **1** | Pausa con `a+o ≥ 1/3` | `≥1/3−o` | variable | No | Ningún certificado nuevo mientras dure; `C-FIN-01` sigue operando (R3) | Con `300 PiB` registrados (ejemplo de `CONTEXTO.md` §4.5): `100 PiB` menos lo apagado; con 10 % apagado, `70 PiB` (fuente A/B) o el `33 %` de la garantía total en circulación (fuente C) | **No** (no votar no es falta, `FV-27`) | Caro de sostener; imposible de castigar por diseño (R3) |
| **2** | Doble sello con un tercio y control de la red | `≥1/3` | — | **Sí** (para censurar al resto y que su `2/3` local parezca el `2/3` real) | Con `FV-01b` cerrado: solo si además consigue que su `1/3` sea contado dos veces en dos tablas distintas heredadas de una bifurcación real anterior a cualquier certificado — no con partición pura (contraejemplo 1 cerrado) | `1/3` del peso total + capacidad de aislar al resto de la red (eclipse, `R-ZRX/LEGADO/eclipse/INFORME.md`: coste en IP/prefijos, **no determinado** porque el gestor de direcciones de ZEROX no existe) | **Sí**, siempre (`FV-23`, dos votos distintos por la misma clave para la misma instancia) | Caro (recursos de Estado) y **firmado** |
| **3** | Sesgo de la tabla de pesos (retener/publicar, elegir ancla) | variable | — | No | Con fuente (A): moldear qué bloques cobra publicando o reteniendo selectivamente, sesgando su propia entrada en la ventana `W_POWER` (mismo `D8` sin cerrar de la propuesta antigua, §7 de `research/dag-poas-capa-finalidad.md`). Con (B)/(C): mucho más caro, porque el registro/depósito no se recalcula desde cero cada ventana | No cuantificado en esta orden (declarado como abierto, igual que lo declaró la propuesta antigua) | No por sí solo | Sin sorteo (`FV-06`), **el «sesgo del sorteo por elección de ancla»** (§4.D de la propuesta antigua) **deja de tener superficie**: no hay plazas que ganar por azar de ancla. Lo que sobrevive es el sesgo de la tabla misma, no del sorteo — declarado abierto |
| **4** | Eclipse de un nodo observador | 0 (capa de red) | — | **Sí** | Aísla a una víctima de la vista de certificados nuevos; la víctima queda con `C-FIN-01` como única defensa, igual que hoy (`R-ZRX/LEGADO/eclipse/INFORME.md` F1: partición de flujo **demostrada** con retención `> F_slots`, coste en espacio **cero**) | Cero espacio; coste en IP/prefijos **no determinado** (gestor de direcciones inexistente); ancho de banda real del ataque ≈ 0 (retiene, no cursa) | No | **No es un ataque a la capa de votos**: es el mismo eclipse ya conocido, y esta capa no lo empeora ni lo cura (`C-FIN-01` sigue igual para el nodo eclipsado) |
| **5** | Partición y flujos de PoT: un certificado cruza flujos | 0 | — | No (basta con la física de la red) | Sin `FV-11`: ninguno, porque `FV-11` prohíbe por construcción que un certificado se refiera a un bloque de otro flujo (`C-FLU-14`). El riesgo real de partición **no** es de flujo, es de tabla de poder (contraejemplo 1, cerrado por `FV-01b`) | — | — | **Imposible** cruzar flujos (`FV-11`, hereda `C-FLU-14`); la partición-sin-cruce-de-flujo está cerrada por `FV-01b` con el residuo de activación declarado |
| **6** | Largo alcance con claves que ya retiraron su garantía | variable | — | No | Reunir claves viejas que ya liberaron su garantía y usarlas para fabricar una historia de votos alternativa antigua | Con fuente (C): bloqueado por `EV-15`/`EV-15b`/`FV-26` (la liberación exige que la ventana de evidencia haya cerrado); con fuente (A): las claves «viejas» no tienen nada que retirar —no hay garantía—, así que el concepto de «ya retiró» no aplica y el ataque se reduce a rehacer historia de peso desde cero, tan caro como rehacer los propios bloques cobrados | **Sí** con (C) si intenta reusar un incidente ya cerrado (`FV-24`); **no aplica** con (A) | Con (C): **imposible** dentro de la ventana de retención; fuera de ella, es el mismo residuo que ya declara `EV-*` para bloques |
| **7** | Delegación del voto y firma a ciegas: voto como servicio | variable (agregado por el servicio) | — | No | **Idéntico al patrón de `P-ZRX/P-POOLS/` (arquitectura 3, firma ciega), trasladado al voto**: un «servicio de voto» compone el voto (`n`, valor) y el cliente del votante lo firma sin validar. El servicio puede votar por dos valores en instancias distintas usando la misma clave del votante repetidamente, y el votante nunca ve qué firmó — exactamente el mismo teorema que `P-ZRX/P-SECRETO/investigacion/INFORME.md` F1 demuestra para bloques: **la firma no prueba que el firmante vio nada** (RFT-11/R-10) | Coste de montar el servicio: bajo (mismo que un pool hoy) | **Sí, pero mal atribuido**: la evidencia (`EV-VOTO`) cae sobre la clave del votante-cliente, no sobre el servicio — mismo defecto que `P-POOLS` §1.2.2 documenta para bloques («al granjero», no al pool) | **No se cierra por diseño de consenso** (mismo veredicto que `P-POOLS` §1.3: «no es expresable como regla de consenso» comprobar que un firmante «vio» lo que firmó). Es un **comité de hecho** contra R1/R2 si se generaliza, y este contrato **no lo impide**: lo declara como riesgo residual, igual que `P-POOLS` declaró el suyo |
| **8** | Censura por un tercio | `≥1/3` | — | **Sí** (para censurar mensajes de GossiPBFT, no bloques) | Fuerza rondas con backoff (`FV-12`) hasta agotar la ventaja de velocidad de la capa (§1.3, `calc/resultados/b4-censura-rondas.tsv`) sin necesitar romper ningún voto | Con `Δ_F=0,60 s`: hacen falta 7 rondas censuradas seguidas para superar `F_slots` (6 rondas: 5 029 s, aún por debajo; 7 rondas: 10 098 s, ya por encima); con `Δ_F=6,0 s`: bastan 4 (3 rondas: 5 940 s, debajo; 4 rondas: 12 276 s, encima) | No (censurar mensajes de red no es una falta de voto) | **Caro** en control de red sostenido, pero **no imposible**; y la consecuencia es solo perder la mejora de velocidad, nunca quedar peor que `C-FIN-01` (FV-18) |
| **9** | Denegación de servicio con certificados inválidos | 0 | — | No | Enviar certificados mal formados o con mapa de bits inconsistente para forzar verificación repetida | Verificación de un certificado inválido es `O(1)` (dos emparejamientos BLS + comprobación de peso, `FV-15`), igual de acotada que `EV-09` para bloques; el coste de DoS es el de propagar bytes, no el de verificarlos | No | **Caro solo en ancho de banda**, acotado por el mismo presupuesto de red que ya protege el resto del protocolo (`C-NET-32.3`/`C-FLU-23`, `P-ZRX/P-FLUJO/propuesta/PROPUESTA-SPEC.md` línea 1116-1122) — no se ha medido un valor nuevo para el certificado; símbolo pendiente |
| **10** | Falsos positivos de R5: la misma clave en dos máquinas y el fallo común del cliente | 0 (accidente) | — | No | Dos instancias del mismo votante firman valores distintos por accidente (reinicio, *harvesters* redundantes) — mismo catálogo `FP1…FP9` de `CONTRATO-EVIDENCIA-v0.md` §10, trasladado a voto | El castigo cae sobre el saldo de la clave igual que con bloques (`FIR-13`); sin firmante seguro extendido a voto, el mismo riesgo que ya existe para bloques | **Sí** (`EV-VOTO` no distingue accidente de ataque, mismo límite que `EV-*`) | **No es un ataque nuevo**: es el mismo residuo ya declarado y sin cerrar para `EvidenceTx` de bloques (`CONTRATO-EVIDENCIA-v0.md` §9, `FIR-13`), heredado sin agravarse ni mejorar |
| **11** | Activación prematura, con poca garantía repartida tras el corte | variable | — | No | Si `S_min_voto`/`K_min_voto` (`FV-28`) se fijan bajos, el `1/3` de un peso total pequeño puede coincidir con muy pocas claves grandes; además, la ventana de arranque no tiene el blindaje de `FV-01b` (residuo declarado en el contraejemplo 1) | No cuantificado (los símbolos no se fijan, mandato) | Depende del ataque concreto | **Caro solo si la calibración de activación es prudente** (`FV-30`, calibrar contra la concentración medida de `DS-6`); con una calibración imprudente, **barato** |
| **12** | Ventana residual del doble farmeo: el atacante grande en la franja aún no sellada | grande, propio | — | No | Reordena o censura lo aún no sellado por certificado, exactamente como hoy con `C-FIN-01` sola, pero en una ventana mucho más corta (§5, residuo) | El mismo de siempre: `RFT-01`/`RFT-02` con `m≥4` soluciones por slot, `κ→0` (`P-ZRX/P-DISUASION/resultados-DS2/INFORME.md` §4.1) | No (`κ=0`, no hay evidencia) | **Imposible de cerrar** (premisa, mandato §3.8); la capa **arrincona** el residuo a la franja sin sellar, no lo elimina |

---

## 5 · Qué mejora frente a `C-FIN-01` sola, qué no, y el residuo del doble farmeo

### 5.1 · Qué mejora

1. **La ventana útil del doble farmeo pasa de `F_slots` (2 h provisional) a decenas/centenas de
   segundos en marcha normal** (`calc/resultados/b4-ventana-doble-farmeo.tsv`: 39,6 s con `Δ_F=0,60 s`,
   `LOOKBACK=10`, sin fallos — razón **182×** frente a `F_slots·τ=7200 s`). Es una reducción real y
   medida (bajo los supuestos declarados de `Δ_F`, §Qué no está medido), no solo cualitativa.
2. **Reescribir lo sellado tiene coste exigible y deja firma** (`FV-19/23/24`), con la fuente de peso
   (C): confisca una fracción de garantía proporcional al peso, algo que `C-FIN-01` sola no ofrece nunca
   (`C-FIN-01` acota profundidad, no cobra nada a quien reescribe dentro de la ventana que permite).
3. **El sesgo de sorteo de la propuesta antigua desaparece** al quitar el sorteo (§1.3, §4 ataque 3):
   una fuente de riesgo entera (que exigía subir `K` de 1000 a 4000 en la propuesta antigua, con su
   coste en certificado) deja de existir.

### 5.2 · Qué no mejora

1. **El doble farmeo sigue sin cierre** (premisa del mandato, RFT-01/RFT-02): con espacio propio
   suficiente y `m≥4` soluciones por slot, el atacante grande sigue sin dejar evidencia (`κ→0`). La
   capa **arrincona** el residuo a la franja sin sellar; no lo alcanza (ataque 12).
2. **Con el modelo de amenaza de Katana no hay imposibilidad frente a un Estado con `1/3` del peso**:
   pausa indefinidamente la finalidad (ataque 1), y ZEROX vuelve exactamente a la situación de hoy
   mientras dure — no peor (FV-18), pero tampoco mejor.
3. **`F_slots` no baja.** La capa añade una finalidad rápida al lado; `C-FIN-01` sigue con su `F`
   igual de atrapada (mandato §4.6.3 de `CONTEXTO.md`, no reabierto por este informe).
4. **Costes para el honesto**, según la fuente de peso elegida (§3): garantía por depósito (C), o
   colateral por sector no construido (B), o ruido de varianza sin barrera (A, pero entonces sin R5).

### 5.3 · El residuo, declarado sin adornos

El atacante grande con espacio propio suficiente, **dentro de la franja aún no sellada**, sigue
intacto. Con `Δ_F` y `LOOKBACK` razonables esa franja pasa de horas a segundos/minutos — pero sigue
existiendo, y dentro de ella el doble farmeo se comporta exactamente igual que hoy: sin evidencia, sin
castigo, solo acotado en el tiempo. Ninguna de las tres piezas de mitigación de `CONTEXTO.md` §2.3 (O4,
castigo con evidencia, esta capa) alcanza a ese atacante.

---

## 6 · Comparador declarado: fuga de inactividad (no adoptada) frente a pausa

Por el mandato §3.4, la fuga de inactividad se evalúa **solo como comparador**, con su precio
documentado, no como mecanismo de esta capa:

- **Qué hace en Ethereum** [P]: «gradually reduces the stakes of validators who are not making
  attestations until... the participating validators control 2/3 of the remaining stake» (eth2book,
  «Inactivity leak»); fórmula cuadrática `t(t+1)B/2α`, con validadores que siguen penalizados incluso
  tras recuperar la finalidad («This is intentional»).
- **Su precio, medido por terceros y citado aquí [P]**: Pavloff, Amoussou-Genou, Tucci-Piergiovanni
  (arXiv:2404.16363) muestran «scenarios where actions by Byzantine validators expedite the
  finalization of two conflicting branches» y que un atacante bizantino puede acabar con «voting power
  exceeding the critical safety threshold of one-third» explotando precisamente el mecanismo de fuga —
  «a probabilistic breach of safety».
- **Por qué esta capa no la adopta**: bajo el modelo de amenaza de Katana (atacante de Estado, dispuesto
  a coordinar durante una partición), un mecanismo que **acelera** la finalización de dos ramas
  contradictorias es lo opuesto de lo que se busca. La pausa (`FV-20`) no tiene ese riesgo: no hace
  avanzar nada, solo espera. Es más lenta en recuperarse tras una caída masiva de honestos, y ese es el
  precio exacto que se paga por no arriesgar (b)/(c).

---

## 7 · Decisiones para Katana

| # | Decisión | Opciones | Coste de cada una | Recomendación |
|---|---|---|---|---|
| **1** | Fuente del peso | (A) bloques cobrados; (B) sectores registrados; (C) garantía `C-BON` | (A): lista ya, pero R5 no muerde (contraejemplo 2, irreversible sin añadir garantía); (B): la más fiel a la razón de Katana, pero depende de `P-REGISTRO-SECTORES` (G1/G2 sin cerrar, fuera de 0.0.1); (C): lista ya y R5 muerde, pero cambia el sentido de `SPEC.md` §0 solo para el voto | **(C) para v0, declarado como compromiso provisional; migrar a (B) cuando cierre G1/G2** |
| **2** | Esquema de firma agregada | `blst` (C+asm, auditado NCC Group) frente a `bls12_381` de zkcrypto (Rust puro, sin auditoría) | `blst`: dependencia C/FFI en la ruta de consenso (lo que se evitó con Chia, aunque con vector de interoperabilidad estándar, no como `chiavdf`); `bls12_381`: cripto no auditada en consenso | **`blst` confinado como excepción de FFI** (mismo patrón que `zx-miner`), con `bls12_381` de contraste en tests diferenciales — igual que ya recomendó `research/dag-poas-capa-finalidad.md` §5, sin cambios |
| **3** | `LOOKBACK` | F3 usa 10; ZEROX podría usar menos (más rápido, tabla más manipulable por ataque 3) o más (más lento, tabla más estable) | Menor `LOOKBACK`: certificado más rápido, más expuesto al sesgo de tabla (ataque 3, no cuantificado); mayor: más lento (`calc/resultados/b4-*.tsv` lo hace lineal en `LOOKBACK`) | No fijar sin medir el sesgo real de la fuente elegida (encargo FV-2) |
| **4** | Ratificar R1–R5 como sustituto de «sin comités» en `SPEC.md` §0 | Sí / no / con matices | Ya lo dice el mandato: la ratificación queda para después de FV-1 | Este informe no lo decide; aporta la evidencia de que el diseño puede cumplirlas con la fuente (C) y con `FV-01b` |
| **5** | Activar `FV-2`/`FV-3`/`FV-4` | Redactarlos ahora (dependen de la fuente de peso, decisión 1) o esperar | Esperar: pierde tiempo; redactar ya con (C) como base: riesgo de rehacer si Katana elige (B) más tarde | Redactar `FV-2` sobre (C), con el `FuenteDePeso` como interfaz (mismo patrón que este contrato), para no bloquear el avance mientras (B) madura |

---

## 8 · Qué no está medido, y cómo se mediría en la red dev

- **`Δ` de red real** (IPA B-05): todo `Δ_F` usado en el bloque 4 de `calc/` es un valor **hipotético**
  o tomado de la simulación DMS-v0.1 (p99 0,26-0,60 s) o del propio valor de Filecoin (6 s), nunca
  medido en una red ZEROX real. **Cómo medirlo**: instrumentar `zx-p2p` para cronometrar el tiempo entre
  que un nodo produce un mensaje de voto y que una muestra de sus pares lo recibe, en la red dev
  multinodo ya prevista por W06d2/W07 (`P-ZRX/P-MEDICION/ESCENARIOS-0.0.1.md`).
- **`p` real de participación honesta** (uptime de un granjero doméstico): el bloque 1 de `calc/` usa
  `pi_uptime` como parámetro barrido, no medido; la distribución de tamaños de clave usa el exponente de
  cola de `P-ZRX/P-CLAVE/investigacion/INFORME.md` (H3, hipótesis) y no una medida de ZEROX. **Cómo
  medirlo**: registrar en la red dev cuántos slots seguidos produce/vota cada clave activa y ajustar la
  distribución de "huecos" de presencia, igual que pide `CONTEXTO.md` §5.
- **El sesgo real de la tabla de pesos** (ataque 3): esta orden no cuantificó cuánto puede sesgar un
  atacante su propia entrada en la ventana `W_POWER` (fuente A) retirando/publicando bloques a
  conveniencia — es el `D8` sin cerrar de la propuesta antigua, heredado sin resolver. **Cómo medirlo**:
  un modelo adversarial dedicado (candidato para `FV-2`), con el mismo criterio `α` que usa el resto del
  repositorio (p. ej. `P-ZRX/P-DISUASION/`).
- **El coste de verificación de un certificado en hardware real**: `calc/resultados/b3-*.tsv` da tamaño
  y ancho de banda, no ciclos de CPU de un emparejamiento BLS en la máquina objetivo. **Cómo medirlo**:
  benchmark de `blst`/`bls12_381` en la red dev, mismo patrón que `A10-M1` para PoW.
- **La concentración real del peso de voto** en una red ZEROX (frente a la del pool de Chia usada como
  proxy en `DS-6`): esta orden reusa esa distribución como la mejor disponible, declarada como proxy, no
  como medida propia de ZEROX (que todavía no existe como red). **Cómo medirlo**: una vez con red dev
  multinodo, medir el reparto real de `peso(pk)` bajo cada fuente candidata.

---

## Entorno de ejecución de `calc/`

Ver `calc/resultados/ENTORNO.txt`: Julia 1.13.0, `Sys.CPU_NAME = znver5`, 123,4 GiB RAM, 4 hilos
(`Threads.nthreads(:default) = 4`), `Threads.nthreads(:interactive) = 0`. Tiempo total de `run.jl`:
321,08 s. Semillas fijas y no consecutivas: `quorum=0x1F3A9C7B5E`, `quorum_cov=0x7E2D0B5911`,
`sorteo_cruz=0x4C81F033A7`, `sesgo_ancla=0x9B60E4127D` (`src/modelo.jl`, constante `SEMILLAS`). Tabla de
cobertura del Monte Carlo del bloque 1 en `calc/resultados/b1-cobertura.tsv` (360 celdas, mínimos por
tipo de caso todos `≥ 1`, cubiertos). `test/runtests.jl`: 19 comprobaciones, todas verdes, incluida la
reproducción cruzada de §4.A de la propuesta antigua (orden de magnitud, `K=1000`) y la reconstrucción
exacta del cierre `(1-a)·p ≥ 2/3` de `CONTEXTO.md` §5.

Línea de ejecución publicada:

```bash
cd deepseek/FV1/calc
JULIA_NUM_THREADS=4 ./julia.sh --project=. --threads=4,0 test/runtests.jl
JULIA_NUM_THREADS=4 ./julia.sh --project=. --threads=4,0 run.jl
```

(`./julia.sh` fija `JULIA_DEPOT_PATH` dentro de la propia zona y ejecuta con
`env -u LD_LIBRARY_PATH`, por el aviso de `V-ZRX/LINEO.md` sobre AOCC/segfault.)
