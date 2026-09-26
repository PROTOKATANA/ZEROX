# INFORME AV-1 — Sorteo verificable después y falta «elegido sin voto»

**Orden:** AV-1. **Ejecutor:** subagente Sonnet, único, sin subagentes ni forks (regla cumplida:
todo el trabajo de investigación, diseño y cálculo de esta entrega se hizo directamente).
**Fecha:** 2026-09-26. **Zona:** `deepseek/AV1/`.

**Comprobación de entrada** (`P-ZRX/P-AUSENCIA-VOTO/ENTRADA-AV1.sha256`): coincide al empezar
(18/18 archivos) y se repite en §8, al final de esta entrega.

Etiquetas: **[P]** primaria leída en esta ejecución · **[S]** secundaria · **[D]** derivación propia
(cuenta hecha aquí o en `CONTRATO-AUSENCIA-v0.md`) · **[H]** hipótesis de diseño.

---

## 1 · Respuesta a la pregunta falsable

> «Existe un esquema en el que se cumplen a la vez (a) secreto durante la ronda; (b) demostrable
> después con datos públicos; (c) defensa del honesto censurado; (d) coste en datos declarado;
> (e) coste absoluto de la pausa que crece con la magnitud, y pérdida del honesto acotada.»

**Se sostiene en (a), (c) y (d); se sostiene en (b) solo con un mecanismo económico, no puramente
criptográfico (matiz necesario, no una refutación); se REFUTA en (e) para `m_aus` fijo y se
sostiene para `m_aus` proporcional a la garantía.** El contraejemplo de (e) es el resultado central
de esta ejecución, análogo en función al de FV-1 para su condición (a).

### (a) — Se sostiene, por construcción de la VRF

Con el diseño de `CONTRATO-AUSENCIA-v0.md` AV-08 (entradas VRF independientes por instancia dentro
de una ventana, compromiso Merkle de las hojas), nadie salvo el propio granjero puede calcular
`output_i` sin su `sk` (unicidad de la VRF, RFC 9381 §3.1 **[P]**), y revelar la hoja de una
instancia **no** revela nada sobre otras instancias de la misma ventana (pseudoaleatoriedad completa
de la VRF, RFC 9381 §3.4 **[P]**, cita literal en AV-05). El esquema 2 de la orden («una VRF por
ventana, revelada al final», en su forma literal de una sola evaluación compartida) **rompe (a)** en
cuanto el granjero vota una vez dentro de la ventana: revela el calendario completo restante. Esto
es un hallazgo de esta ejecución, no señalado con esta precisión por la orden.

### (b) — Se sostiene, pero no por criptografía sola: el mecanismo es económico

**Hallazgo AV-01/AV-02 (`CONTRATO-AUSENCIA-v0.md` §1.1):** ninguna primitiva criptográfica hace que
un granjero racional que salió elegido y no votó esté obligado a publicar la prueba que lo delata;
solo él puede calcularla, y nadie puede obligarlo a revelarla por medios puramente criptográficos.
Un compromiso Merkle con auditoría aleatoria (esquema 3 literal de la orden) **no cierra esto**: el
granjero puede comprometerse honestamente y luego, selectivamente, no responder a la auditoría de
las hojas que lo delatan — con auditoría de fracción `p_aud`, una ausencia suelta se detecta solo con
probabilidad `p_aud` (§2 de `CONTRATO-AUSENCIA-v0.md`, AV-06). **La solución adoptada (AV-03/AV-08/AV-09)
hace (b) determinista mediante una regla de consenso, no de criptografía:** revelación total
obligatoria de la ventana antes de un plazo, con suspensión mecánica (sin confiscación) de toda
clave que no la complete. Esto **sí** cumple (b) literalmente («cualquiera puede demostrar con datos
públicos») porque, o la clave revela todo (y entonces la demostración es pública y trivial), o queda
excluida del sorteo indefinidamente — no hay una tercera vía racional. **Matiz declarado:** esto es
distinto de decir que (a) y (b) son compatibles «gratis»: tienen un coste de diseño (una capa de
suspensión mecánica adicional a la de FV-05) que la orden no anticipaba con este nivel de detalle.

### (c) — Se sostiene, con el mismo límite que ya declaraba FV-1

El honesto que votó a tiempo pero fue censurado dispone de un plazo de gracia `G_slots` para incluir
su propio voto firmado (AV-11), y la misma defensa se extiende a la revelación de la ventana. Con
`G_slots` comparable a `F_slots` (1019, precedente de SL-2b **[S]**), la probabilidad de censura
total es `c^{1019}`, despreciable para todo `c<1` (`calc/resultados/C4-fp-censura.csv`: `1,37·10⁻⁷`
a `c=0,9`; `3,57·10⁻⁵` a `c=0,99`). **Límite declarado, no cerrado:** si el atacante controla el
100 % de la producción de bloques durante todo `G_slots` (no solo censura selectiva), la defensa
falla — es el mismo supuesto de ruptura que FV-1 ya exige para su propio umbral de 2/3.

### (d) — Se sostiene, condicionado a `Δ`/`T_instancia` no medida (mismo límite que FV-1, IPA B-05)

Con el diseño AV-08 (compromiso por ventana + revelación en bloque), el coste por granjero y día es
`(32 B + 20 B)/N_ventana + (20 B + N_ventana × 80 B)/N_ventana ≈ 80 B` por instancia en el límite de
`N_ventana` grande, frente a `100 B` por instancia del esquema 1 continuo (`calc/resultados/C1-datos-por-dia.csv`).
**Presupuesto declarado en este informe:** ≤ 1 MiB/granjero/día. Se cumple con margen amplio para
`T_instancia ≥ 10 s` (a `T_instancia=30 s`: 230,6 KB/día con `N_ventana=1000`, tabla `C1`); **no** se
cumple con margen si `T_instancia` fuera de 1 s (6,9–13 MB/día) — un caso extremo, ya que FV-1 cita a
F3 de Filecoin bajando la finalidad a «decenas de segundos» como referencia de la familia de diseño
(`CONTEXTO.md` §4.1 **[S]**). **No medido:** `Δ` real de ZEROX (IPA B-05, heredado de FV-1).

### (e) — REFUTADA para `m_aus` fijo; se sostiene para `m_aus` proporcional a la garantía

**Contraejemplo, con la cuenta en `calc/resultados/C2-costo-pausa-hora.csv` y `C6-concentracion-vs-fragmentacion.csv`
[D].** Bajo el alcance (i) (todo elegido paga), un atacante que sostiene una pausa por
autoabstención y **concentra** su peso `a` en una sola clave (`m_split=1`) sufre, por instancia, como
mucho **un** incidente de ausencia (identidad de oportunidad `(public_key,n)`, AV-12), con
probabilidad `1-(1-a)^K → 1` para `a ≫ 1/K` (con `K=1000` [H], ya a `a=0,10`: `(1-0,10)^1000 ≈
1,7·10⁻⁴⁶`, indistinguible de certeza). Con `m_aus` **fijo** (independiente del peso de la clave), el
coste por hora tiende a `m_aus / T_instancia`, **una constante**: verificado numéricamente,
`costo_hora_m_aus_fijo` vale `36 000` (unidades simbólicas/hora, `m_aus=10`, `T_instancia=1 s`) para
**todo** `a ∈ {0,10; 0,20; 0,25; 0,30; 0,40}` (tabla `C2`, columna `costo_hora_m_aus_fijo`,
`m_split=1`; diferencia `<0,001 %`). **Un atacante con el 40 % del peso total paga exactamente lo
mismo por hora de pausa que uno con el 10 %.** Esto viola la parte de (e) que exige que el coste
absoluto crezca con la **magnitud** del ataque, no solo con su duración (que sí crece linealmente,
trivialmente, con `m_aus` fijo). **Con `m_aus` proporcional a la garantía** (`m_aus(P) = f_aus ×
garantía(P)`), el coste por hora **sí** crece linealmente con `a` (tabla `C2`, columna
`costo_hora_m_aus_proporcional`: de `1,8·10⁷` a `a=0,10` a `7,2·10⁷` a `a=0,40`, proporción exacta
4×) y es **invariante** a cómo el atacante reparte su peso entre claves (`RFT-05`, el peso se suma;
verificado en `test/runtests.jl`: `costo_split1 ≈ costo_split50` con `rtol=0,05`). **Conclusión: (e)
solo se sostiene con `m_aus` proporcional a la garantía; con `m_aus` fijo, (e) queda refutada por un
contraejemplo cuantificado, no por intuición.**

**Hallazgo adicional, no pedido explícitamente pero relevante para D.1/D.3 (análisis adversarial):**
con `m_aus` fijo, **fragmentar el peso en muchas claves multiplica el número de incidentes** (de 1 a
221 con `m_split` de 1 a 1000, `a_eff=0,25`, `K=1000`, tabla `C6`) — el atacante que quiere
**minimizar** su exposición a `m_aus` fijo debe **concentrar**, no fragmentar, contradiciendo la
intuición habitual de que partir en muchas claves diluye el castigo (cierta para castigos por
identidad como en `P-CLAVE`, falsa aquí porque la falta de ausencia es «como mucho una vez por
instancia por clave», así que menos claves con más peso cada una dan menos incidentes).

---

## 2 · Los cuatro esquemas y el recomendado

| | **1. Publicación completa** | **2. VRF por ventana (literal)** | **3. Merkle + auditoría aleatoria (literal)** | **Recomendado: 3 con entradas independientes + revelación total obligatoria** |
|---|---|---|---|---|
| (a) secreto durante la ronda | Sí, hasta que se publica tras el cierre de esa instancia | **No** tras el primer voto de la ventana (revela el resto) | Sí, mientras no se abra la hoja | Sí (AV-05, VRFs independientes) |
| (b) demostrable después | No por sí solo (nada obliga a publicar) | No (mismo problema) | Solo probabilístico si la auditoría es parcial | **Sí, determinista** (AV-03/AV-09: revelar o quedar suspendido) |
| Datos/día (ilustrativo, `T_instancia=30 s`, `N_ventana=1000`) | 288,0 KB | ≈ 288,0 KB (1 prueba/ventana, mucho menor, pero se descarta por (a)) | ≈ 230,6 KB | **230,6 KB** (calc `C1`) |
| Coste marginal de votar | Ninguno adicional | Ninguno adicional | ≈ 0 (la hoja se abre con el voto) | ≈ 0 |
| Qué pasa si no publica | Nada lo obliga (no cierra (b)) | Nada lo obliga | Detección parcial, probabilística | **Suspensión mecánica** (AV-09), sin confiscación |
| Literatura relacionada | — | Algorand (VRF, pero sin garantía que forzar) | — | SSLE **descartado** (resuelve el problema opuesto, AV-07) |

**Esquema recomendado:** el de la última columna (`CONTRATO-AUSENCIA-v0.md` AV-08), por ser el único
que cumple (a) y (b) a la vez sin depender de la buena fe del granjero.

---

## 3 · Análisis adversarial

Convenciones: `a` = fracción del peso total del atacante; `K=1000` [H] (parámetro ilustrativo, sin
fijar, mismo orden que usa SL-2b); `m_aus` fijo o proporcional según se indique; `T_instancia` no
medida (IPA B-05), cifras a `T_instancia=1 s` como cota superior de frecuencia salvo que se indique
otra.

| # | Ataque | Coste absoluto | Daño | ¿Firmado/evidenciado? | Imposible / caro |
|---|---|---|---|---|---|
| 1 | **Pausa sostenida por autoabstención bajo (i), con y sin censura de la prima honesta** | **`m_aus` fijo:** `≈ m_aus/T_instancia` por hora, **independiente de `a`** para `a≳1/K` (36 000 u.e./h ilustrativas, `m_aus=10`, `T_instancia=1 s`; tabla `C2`). **`m_aus` proporcional:** `≈ f_aus·a·Garantía_total/T_instancia`, creciente en `a` (de `1,8·10⁷` a `7,2·10⁷` u.e./h de `a=0,10` a `0,40`, tabla `C2`). La censura de la prima honesta (FV-1 ataque 13) no cambia esta cuenta: solo desplaza QUIÉN gana las plazas, no CUÁNTOS incidentes propios genera el atacante al autoabstenerse | Bajo (i): pausa cuesta lo mismo que bajo (ii) porque toda clave, con prima o no, paga; bajo (ii) el atacante deja caducar la prima y paga solo a peso ×1 — mismo `m_aus` por incidente, pero MENOS incidentes esperados (peso efectivo menor, `q_a(a,1)<q_a(a,b)`) | Sí, `EvidenceAusencia` de cada incidente (AV-13) | **Caro** con `m_aus` proporcional; **barato, cota fija** con `m_aus` fijo (AV-19) — hallazgo central de (e) |
| 2 | **Hacer perder a honestos: bloquear/retrasar votos, eclipsar, censurar durante el plazo de gracia** | Necesita censura de **todas** las oportunidades de inclusión durante `G_slots` (no una): probabilidad de éxito `c^{G_slots}` (`c^{1019}`, tabla `C4`: `1,37·10⁻⁷` a `c=0,9`) | Si tiene éxito: castiga a un honesto, un falso positivo genuino que el mandato prohíbe aceptar sin defensa (`AUTO-ZRX.md` §91) | La `EvidenceAusencia` resultante sería técnicamente válida (no hay voto admitido), pero el honesto SÍ tenía uno firmado fuera de la ventana admitida — **límite declarado, no cerrado**: si la censura logra el 100 % durante `G_slots`, no hay defensa dentro de este contrato | **Caro** (necesita control total de red durante toda la ventana de gracia, mismo supuesto que el umbral de ruptura de FV-1); **no imposible** |
| 3 | **Repartirse en muchas claves o votar a ratos para conservar la prima** | Con `m_aus` fijo, fragmentar **multiplica** el número de incidentes esperados por instancia (de 1 a 221 con `m_split` de 1 a 1000, `a_eff=0,25`, `K=1000`, tabla `C6`): fragmentar es **peor**, no mejor, para el atacante bajo este diseño. «Votar a ratos» (alternar qué clave está activa) no reduce la exposición: cada `(clave,instancia)` es un incidente independiente, evidenciado igual sea cual sea el patrón de rotación | Ninguno: el peso agregado no cambia (`RFT-05`), y bajo `m_aus` fijo el atacante ya está en su óptimo concentrando en pocas claves, no fragmentando | Sí, cada incidente por separado | **Imposible** evadir por partición (RFT-05); la intuición de que fragmentar «diluye» el castigo es **falsa** para esta falta concreta |
| 4 | **Ausencias honestas correlacionadas (apagón regional, fallo común del cliente)** | Sin castigo correlacionado (AV-21, extensión de `DS-L02`/`EV-21`): cada clave afectada paga su `m_aus` individual, sin amplificación. Pérdida agregada = `n_afectadas × m_aus` (o `× f_aus × garantía` si proporcional), lineal en el número de afectadas, no cuadrática ni creciente en la fracción | No compromete la viveza de la capa de finalidad: R3 ya prevé que faltar quórum solo pausa (FV-20); un fallo común de muchos honestos simplemente hace más probable la pausa (mecanismo ya modelado por FV-1, no por AV-1), pero no añade una amplificación de la CONFISCACIÓN | Sí, cada `EvidenceAusencia` es independiente | **Aceptado por diseño** (mismo principio que DS-5): el fallo compartido cuesta, pero no se amplifica |
| 5 | **Manipular el sorteo verificable (entropía de la ventana, momento del compromiso)** | `seed_W` depende de `past(A)` del bloque de apertura de la ventana (AV-08), nunca del propio productor de ese bloque (mismo criterio anti-sesgo de FV-02): el productor no puede elegir `seed_W` a su favor sin ganar primero el consenso de producción (ajeno a esta capa, mismo argumento que el ataque 3/14 de FV-1 sobre sesgo del ancla) | El sesgo residual (elegir el MEJOR ancla entre los que ya gana el productor) es de segundo orden, heredado sin remedir de FV-1 (`INFORME.md` FV-1, ataque 14: despreciable a `b=1`, ya no importa a `b≥2` porque otros efectos dominan) | — | **Imposible** ganar `seed_W` sin ganar antes GHOSTDAG (mismo argumento que FV-03) |
| 6 | **Abuso de las pruebas de ausencia (spam, duplicados, reorganizaciones)** | Incidente único (`incident_id`, AV-13) y deduplicación en fusión, mismo patrón de `EV-10…EV-12`: una segunda `EvidenceAusencia` del mismo incidente se descarta sin volver a confiscar. Coste de verificación `O(1)`/`O(N_ventana)` (AV-15), acotado por el tamaño de la transacción de revelación | Denegación de servicio con evidencias mal formadas: bajo para el atacante, rechazo `O(1)` (mismo argumento que ataque 9 de FV-1) | — | **Mitigable** con las mismas cuotas de presupuesto de red que el resto del protocolo, no diseñadas en detalle aquí (línea futura, AV-3) |
| 7 | **El granjero doméstico honesto: ¿le sale más a cuenta no registrarse?** | Perfil «siempre encendido»: exposición CERO a AV-1 (`incidentes_apagado_anio=0`, `test/runtests.jl`) — registrarse no tiene coste de ausencia. Perfil «16 h/día»: exposición `≈ 1,05·10⁵` u.e./año (`f_h=10⁻⁶`, `m_aus=10`, `T_instancia=1 s` ilustrativo; escala como `1/T_instancia`, tabla `C3`) — a `T_instancia=30 s`, `≈ 3500` u.e./año. Perfil «un apagón de 6 h al mes»: `≈ 2,5·10⁴` u.e./año a `T_instancia=1 s` (`≈ 830` a `30 s`) | No cuantificado en esta orden: el valor de producir bloques/votar (fuera de alcance de AV-1) probablemente domina este coste pequeño y acotado, pero **no se cierra numéricamente aquí** porque compararlo exige el ingreso esperado de producción, que no es un símbolo de AV-1 | — | **No medido**: la respuesta depende de un dato fuera de esta orden (ingreso esperado de producción); lo que AV-1 sí demuestra es que el coste de ausencia, con `m_aus` bien elegido, es **pequeño y acotado**, no catastrófico, para un perfil doméstico razonable |

---

## 4 · Redacción propuesta de R5

**Texto vigente (`P-ZRX/P-FINALIDAD-VOTOS/PROGRAMA.md`):** «R5. Toda falta deja firma: votar dos
cosas contradictorias es prueba y castigo.»

**Redacción propuesta (para que Katana la ratifique):**

> **R5 (ampliada).** Toda falta castigada deja prueba pública verificable: votar dos cosas
> contradictorias (doble voto, `FV-EVP`), o **salir elegido en el sorteo y no tener un voto admitido,
> una vez revelado el sorteo de la ventana** (ausencia, `AV-*`). Ninguna falta se castiga sin esa
> prueba; **la revelación misma no es un acto firmado que compruebe "vi el sorteo"**: es una
> obligación de cara a la elegibilidad futura (suspensión mecánica, AV-09), distinta del castigo con
> evidencia (confiscación, AV-13/AV-18).

**Qué rompe o qué no rompe de R1–R4 (comprobado en esta ejecución):**

- **R1 (entrada abierta):** no se rompe. La suspensión mecánica de AV-09 no es una condición de
  ENTRADA al sorteo (que sigue siendo universal, FV-04): es una consecuencia de no revelar, aplicada
  DESPUÉS de haber entrado. Una clave suspendida sigue registrada; solo tiene peso efectivo cero
  hasta que revela.
- **R2 (sin elección):** no se rompe. La suspensión depende de un hecho verificable en la cadena (no
  reveló a tiempo), no de una métrica externa ni de un juicio de terceros.
- **R3 (nadie indispensable):** no se rompe. La producción de bloques y el sello de finalidad siguen
  sin depender de que una clave concreta vote o revele; una clave suspendida simplemente deja de
  contar en el sorteo, exactamente como si no estuviera registrada, sin bloquear a nadie más.
- **R4 (sin decidir contenido):** no aplica a esta ampliación (es una regla sobre qué puede sellar un
  voto, y AV-1 no introduce ningún voto nuevo con contenido).

---

## 5 · Enmiendas a textos vigentes

1. **`P-ZRX/P-FINALIDAD-VOTOS/resultados-FV1/CONTRATO-FINALIDAD-VOTOS-v0.md`, FV-20:** el texto
   «su ausencia no es falta» pasa a leerse «su ausencia no es falta **salvo que, tras revelar el
   sorteo de su ventana (AV-08), resulte elegida sin voto admitido (AV-12)**». R3 sigue intacta:
   sigue sin haber espera a los votantes; lo que cambia es que la ausencia, una vez demostrada, tiene
   una consecuencia distinta de la pausa misma.
2. **Orden FV-1, decisión 5** (citada en `PROGRAMA.md` de `P-AUSENCIA-VOTO` como «no se castiga
   ninguna ausencia»): sustituida, para la capa de votos, por AV-1 en su totalidad, como ya
   anticipaba `FV-D03`.
3. **`P-ZRX/P-SLASHING/DECISIONES.md`, `DS-L01`** («única falta castigable en v0: la doble firma;
   ninguna ausencia»): se enmienda para la capa de votos exclusivamente — se añade «`AV-1`, una vez
   ratificada, introduce la falta de ausencia de voto, con su propia semántica y tasa de falsos
   positivos (`AUTO-ZRX.md` §91/§102), sin reabrir `DS-L01` para ninguna otra ausencia (auditorías de
   almacenamiento, bloques no producidos, etc., que siguen sin castigo automático)».

---

## 6 · Decisiones para Katana

| # | Decisión | Opciones | Coste de cada una | Recomendación |
|---|---|---|---|---|
| D1 | `m_aus`: fijo o proporcional a la garantía | **Fijo** (cantidad pequeña única, como pidió Katana literalmente): coste de pausa por hora es una CONSTANTE independiente de `a` para `a≳1/K` (AV-19) — un atacante con el 40 % paga lo mismo que uno con el 10 %; **Proporcional** (`m_aus(P)=f_aus×garantía(P)`, con un piso mínimo absoluto para que una clave de saldo bajo no escape con pérdida cero, heredando el límite de `EV-22`): coste crece linealmente con `a`, cumple (e) | Explicado en §1(e). El proporcional necesita que `requisito(B)` (garantía por clave) siga sin techo fijo, igual que `FV-EVP-06` ya señaló para el doble voto | **Proporcional, con piso mínimo.** Es la única forma de que el coste de pausar escale con la magnitud del atacante, que es exactamente lo que pide el modelo de amenaza de Katana (Estado, coste absoluto, no "no compensa"). Mantener el símbolo `m_aus` para el piso y añadir `f_aus` para la parte proporcional |
| D2 | Duración `D_prima` de la pérdida de la prima | Corta (unas pocas ventanas): coste bajo para el honesto que se equivoca una vez, disuasión débil para un atacante que ya no valora la prima si no hay premio al voto; larga (muchas ventanas/días): disuasión mayor SI hay premio al voto (lucro cesante, `calc/C3`), coste mayor para el honesto que se apaga por accidente y luego queda "castigado" con peso ×1 durante ese tiempo aunque vuelva a estar disponible | `calc/resultados/C3-perdida-honesto-perfil.csv` da el lucro cesante en función de `D_prima` y del premio (columna `premio_voto`) | **Sin recomendación de valor cerrado**: depende directamente de D3 (premio al voto). Si D3 es "no" (premio cero), `D_prima` tiene un efecto casi puramente estratégico (menos probabilidad futura de ser sorteado), y una duración moderada (p. ej. del orden de una ventana `N_ventana`) es razonable sin más análisis; si D3 es "sí", conviene calibrar `D_prima` junto con el premio en un encargo posterior (AV-2) |
| D3 | Premio al voto (recompensa por voto incluido en un certificado) | Cero (statu quo de FV-1/FV-D03, pendiente): `D_prima` es solo estratégico, sin lucro cesante monetario; positivo: refuerza AV-19 (la prima perdida SÍ escala con el peso, aunque `m_aus` fijo no lo haga) y da a `D_prima` un coste monetario real para el atacante, pero exige diseñar de dónde sale ese premio (¿de la coinbase? ¿del mismo fondo que `RAT-2′` de SL-1?) y si compite con "sin decidir contenido" (R4) — no debería, porque premiar VOTAR no es premiar CONTENIDO | `calc/C3`, columna `premio_voto` | **No se decide aquí** (fuera del alcance literal de AV-1, que solo debía calcular el balance con y sin premio). Se señala que un premio positivo, aunque pequeño, mejora la robustez de (e) sin depender de que `m_aus` sea proporcional — son mecanismos complementarios, no sustitutos |

---

## 7 · Qué no está medido

- **`Δ`/`T_instancia` real** (IPA B-05, heredado de FV-1): sin ella, los datos por día (§1(d)) y el
  coste absoluto por hora (§1(e)) quedan simbólicos salvo por la cota ilustrativa a `T_instancia=1 s`
  (la más exigente) y la sensibilidad a 5/30/300 s en `calc/resultados/C1-datos-por-dia.csv`.
- **El valor económico de producir/votar** (necesario para cerrar el ataque 7, «¿compensa
  registrarse?», y para dar D3 —premio al voto— un número, no solo una fórmula).
- **La interacción exacta de `N_ventana`, `W_reveal` y `G_slots` con la latencia real de la red**: se
  proponen relaciones estructurales (`G_slots ≤ W_reveal`, `Plazo_aus_slots` con la desigualdad de
  `EV-15`), no valores numéricos.
- **El coste de verificación agregado de una revelación en bloque a escala de red** (`AV-15` da
  `O(N_ventana)` por clave; no se ha medido el efecto sobre el tamaño de bloque cuando muchas claves
  revelan en la misma ventana de cierre — riesgo de una "hora punta" de revelaciones si `W_reveal` es
  corto y muchas ventanas cierran a la vez).
- **PDF completos de Algorand (SOSP 2017) y de SSLE (IACR ePrint 2020/025):** se leyeron resúmenes,
  citas literales de la sección de sortición (Algorand, vía motor de búsqueda) y la definición del
  problema (SSLE, página del ePrint); no se pudo descargar el PDF completo de ninguno de los dos
  desde esta zona en el tiempo de esta ejecución. Las citas usadas están verificadas como literales
  de las páginas consultadas, pero un tercero debería confirmar contra el PDF completo antes de
  ratificar cualquier detalle fino de la sortición de Algorand que no esté ya cubierto por FV-06.

---

## 8 · Comprobación de entrada (repetida al final)

```
$ cd /home/katana/zeo/ZEROX && sha256sum -c P-ZRX/P-AUSENCIA-VOTO/ENTRADA-AV1.sha256
```

Resultado: **coincide** (18/18), igual que al empezar esta ejecución (ver primer comando de esta
sesión). Ningún archivo de entrada se modificó durante el encargo; la única zona escrita fue
`deepseek/AV1/`.

---

## 9 · Entregables

- `deepseek/AV1/CONTRATO-AUSENCIA-v0.md` (reglas `AV-01…AV-22`, cada una con su justificación y un
  caso).
- `deepseek/AV1/INFORME.md` (este documento).
- `deepseek/AV1/calc/` — `Project.toml`, `Manifest.toml`, `julia-version.toml`, `src/modelo.jl`,
  `src/referencia.jl`, `run.jl`, `test/runtests.jl`, `resultados/C1…C6*.csv`, `resultados/RESUMEN.txt`.
- `deepseek/AV1/HUELLAS.sha256`.
