# Ronda 11b (D8) — Sensores de eclipse y reglas de red

**Auditor adversarial D8.** Encargo en `ENCARGO.md`; método en `../METODO-AGENTES.md`.
Volcado incremental: cada punto se escribe al cerrarlo y se commitea solo este directorio.

**Constantes del diseño usadas en todo el informe** (fuente, no memoria):
`λ = 1 bloque/s`, `σ = 1 s` (`DECISIONES.md §19`, bloque «σ (duración de slot) = 1 s»),
`Δ = 4 s` nominal (`d9-ronda8c/r8c_sim.py:23`, `DELTA = 4.0`), `S_max = 150 s`
(auditoría 7 §4, decisión de Katana), `k = 30`, `mp = 15`, `msl = 180`.

---

## A · El ataque, cuantificado en nuestro diseño

**Instrumento:** `r11b_lib.MundoVictima`, extensión del simulador de eventos
`d9-ronda8c/r8c_sim.Mundo` (GHOSTDAG fiel a rusty-kaspa @ `c338d495`) y del `MundoEclipse`
de `d8-ronda8/d8_a3_smax.py:82-131`. Adversario del paper: ve todo al instante, no paga `Δ`.
Salidas: `salida_a.txt` (12 semillas, horizonte 900 s) y `salida_a2.txt` (horizonte 2 400 s).

### A.0 · Control positivo (método, regla 4)

Antes de medir nada nuevo se reproduce con el instrumento heredado la fila publicada de D8 A3b
(`d8-ronda8/salida_a3b.txt`, `E = 200 s`, `f = 5 %`, 12 semillas):

| | S=4 | S=20 | S=30 | S=150 |
|---|---:|---:|---:|---:|
| Publicado en `salida_a3b.txt` (α=0) | 0,8218 | 0,6513 | 0,5920 | 0,5460 |
| **Reproducido aquí (α=0, global)** | **0,8218** | **0,6513** | **0,5920** | **0,5460** |

Idéntico a cuatro decimales. **VERIFICADO.**

El «77 % en régimen» de la auditoría 7 §A3b se reproduce como **0,7567** tomando la mitad
final de la *secuencia* de bloques de la víctima (`corre_ecl` no devuelve instantes). La
diferencia con el 0,77 publicado es la definición de «régimen», no el instrumento; con
`MundoVictima`, que sí tiene instantes, y el eclipse arrancando en `t = 300 s`, la ventana
`[600, 900]` da **0,7500** a `E = 200 s / S_max = 150 s`. Los tres números son el mismo
fenómeno; se usa **0,75** como el valor con ventana temporal bien definida.

### A.1 · Variante (i) — el atacante RETIENE el PoT

**Hipótesis declarada:** la víctima no corre timelord propio. Es coherente con el diseño
elegido (`CLAUDE.md`: granjero objetivo = PC con SSD; «Timelord: lo operamos») y con
Autonomys, donde el nodo *verifica* el PoT que llega por gossip
(`subspace/crates/sc-proof-of-time/src/source/gossip.rs:576-600`). Si la víctima corriera un
timelord propio, la variante degenera en (ii) con la salvedad de que su cadena de PoT
divergiría de la de la red — caso no simulado, **LAGUNA** (haría falta modelar dos cadenas de
PoT y su reconciliación).

Medido (`salida_a.txt`, sección «(i) 'pot'»), para todo `α ∈ {0; 0,10; 0,33}` y todo
`f_v ∈ {0,01; 0,05; 0,09; 0,20}`:

| | antes del eclipse | después |
|---|---:|---:|
| bloques de la víctima (12 semillas, `f_v = 0,05`, α=0) | 192 | **0** |
| llegadas a su vista | — | **0** |

**DEMOSTRADO por construcción, no medido:** sin PoT no hay slot que justificar y no hay
bloque. La víctima **no pierde bloques por `S_max`: no llega a fabricarlos.** No hay doble
gasto posible por esta vía —el atacante tampoco puede mostrarle una vista falsa, porque
también necesitaría PoT para sostenerla— pero sí **apagón total del granjero** y, si la
víctima es un comerciante, congelación de su vista: lo que vio confirmado hace una hora sigue
pareciendo confirmado, y ahí está el riesgo.

**Coste para el atacante: cero espacio.** Es un ataque de red puro (α=0 da lo mismo que
α=0,33). El único coste es capturar las conexiones (punto D).

### A.2 · Variante (ii) — el PoT pasa, los bloques honestos se filtran

`paso` = fracción de bloques honestos ajenos que el atacante deja llegar. Régimen
`[600, 900] s`, `f_v = 0,05`, 12 semillas (`salida_a.txt`):

| paso | α | n | inv S=4 | inv S=20 | inv S=30 | inv S=150 | tasa observada | **rojo_V** |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1,00 | 0,00 | 177 | 0,5537 | 0,0000 | 0,0000 | 0,0000 | 0,9833 | **0,0169** |
| 0,33 | 0,00 | 215 | 0,7070 | 0,0047 | 0,0000 | 0,0000 | 0,3128 | **0,0093** |
| 0,10 | 0,00 | 190 | 0,7316 | 0,0579 | 0,0105 | 0,0000 | 0,0983 | **0,0895** |
| **0,00** | **0,00** | 193 | 0,7927 | 0,3109 | 0,1762 | 0,0000 | **0,0000** | **1,0000** |
| 0,00 | 0,10 | 146 | 0,5274 | 0,0822 | 0,0137 | 0,0000 | 0,1108 | 0,0479 |
| 0,00 | 0,33 | 131 | 0,2214 | 0,0000 | 0,0000 | 0,0000 | 0,3381 | 0,0000 |

Forma cerrada (D8 A3b M3 generalizada): un nodo que solo puede encadenar sobre bloques que le
llegan a tasa `μ = f_v·λ + paso·(1−f_v)·λ` tiene huecos `Exp(μ)`, luego
`P(inválido) = e^{−μ·S_max}`. Contra la medida a `paso = 0, α = 0`:

| | S=4 | S=20 | S=30 | S=150 |
|---|---:|---:|---:|---:|
| medido | 0,7927 | 0,3109 | 0,1762 | 0,0000 (n=193) |
| cerrado `e^{−0,05·S}` | 0,8187 | 0,3679 | 0,2231 | 0,00055 |

**VERIFICADO** en el rango muestreable; la medida queda algo por debajo porque el primer
bloque de la víctima tras el eclipse todavía cuelga de un bloque previo al eclipse.

**El hallazgo que importa, y es contraintuitivo:** con `S_max = 150 s` la variante (ii)
**no invalida casi nada** (0,06 % en forma cerrada a `f_v = 0,05`) y sin embargo
**`rojo_V = 1,0000`: el 100 % de los bloques de la víctima quedan fuera del blueset público.**
`S_max` no es el sensor y no es el daño; el daño es que la víctima mina una rama privada que
se descarta entera. **Un granjero eclipsado pierde el 100 % de su recompensa mientras dure el
eclipse, y sus bloques son perfectamente válidos.** El 77 % de la auditoría 7 era el número
de la variante (iii), y es el caso *más suave*, no el más duro.

**Criterio α, y es la lectura clave del punto:** `rojo_V` cae de 1,0000 (α=0) a 0,0479
(α=0,10) y a 0,0000 (α=0,33). **Cuanto más espacio tiene el atacante, MENOS daña a la
víctima por esta vía**, porque los bloques que le enseña son suyos y sí están en el DAG
público. Es decir: el eclipse-filtro puro es el ataque del atacante *sin espacio*, y el
eclipse con doble gasto es el del atacante *con* espacio — son ataques distintos con firmas
distintas, y por eso hacen falta dos sensores.

### A.3 · Variante (iii) — el PoT pasa, todo llega con `E` s de retraso

Régimen `[600, 900] s`, `f_v = 0,05`, 12 semillas (`salida_a.txt`):

| E (s) | α | n | reg S=4 | reg S=20 | reg S=30 | reg S=150 | tasa observada | **rojo_V** |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 0 | 0,00 | 175 | 0,5943 | 0,0000 | 0,0000 | 0,0000 | 0,9728 | 0,0171 |
| 20 | 0,00 | 178 | 0,7753 | 0,7022 | 0,0056 | 0,0000 | 0,9772 | **0,0449** |
| 60 | 0,00 | 175 | 0,7600 | 0,6743 | 0,6743 | 0,0000 | 0,9728 | **1,0000** |
| 200 | 0,00 | 180 | 0,8167 | 0,7500 | 0,7500 | **0,7500** | 0,9600 | **1,0000** |
| 200 | 0,33 | 143 | 0,8881 | 0,8531 | 0,8531 | 0,8531 | 0,9775 | 1,0000 |

Tres cosas, todas nuevas:

1. **Hay una banda ciega entre 60 s y 150 s de retraso**: `rojo_V = 1,0000` —la víctima lo
   pierde todo— y sin embargo **ni un solo bloque suyo es inválido** por `S_max = 150 s`.
   La pérdida total ocurre **antes** de que `S_max` diga nada. Elegir `S_max = 150 s` fue
   correcto por el eje de red (auditoría 7 §4) pero **`S_max` no protege al granjero
   retrasado**: solo cambia si pierde por rojo o por inválido.
2. **La tasa observada es 0,96-0,99 para TODO `E`.** Un retraso uniforme **no cambia la tasa**
   en régimen: solo abre un hueco de duración `E` al empezar. **El sensor E2 es ciego a la
   variante (iii) salvo durante ese transitorio**, y ese es el resultado que fija cómo hay
   que dimensionar `W` en el punto C.
3. `E = 20 s` es benigno (`rojo_V = 0,0449`): el DAG absorbe el retraso. El salto está entre
   20 s y 60 s, es decir alrededor de `2Δλ` frente a `k = 30`.

### A.4 · Qué puede hacerle el atacante — resumen del punto A

| | (i) retiene PoT | (ii) filtra bloques | (iii) retrasa `E` |
|---|---|---|---|
| Bloques de la víctima | **0** | todos, válidos | todos, válidos si `E < S_max` |
| Inválidos por `S_max = 150` | n/a | 0,06 % (cerrado) | 0 % si `E ≤ 60`; **75 %** si `E = 200` |
| **Recompensa perdida** | **100 %** | **100 %** | **100 %** si `E ≥ 60 s`; 4,5 % si `E = 20 s` |
| Tasa que ve la víctima | 0 | `f_v + paso·(1−f_v)` ≈ **0** | **≈ λ** (indistinguible) |
| PoT que ve la víctima | **se congela** | correcto | **`E` s de retraso** |
| Doble gasto contra la víctima | no (el atacante tampoco tiene PoT que enseñar) | **sí, si α > 0**: le enseña solo su flujo | sí, retrasando la rama honesta |
| Espacio que necesita el atacante | 0 | 0 para robar; α > 0 para doble gasto | 0 |
| **Sensor que lo ve** | **E1** (retraso del PoT crece 1 s/s) | **E2** (tasa cae a `α·λ`) | **E1** (retraso del PoT = `E`) |

**Lo decisivo:** las tres variantes son ciegas a un sensor y visibles al otro, y **ninguna es
visible a los dos**. Hacen falta E1 **y** E2; ninguno sobra.

---

## B · Sensor E1 (reloj de PoT contra reloj de pared)

**Script:** `r11b_b_e1.py` · **salida:** `salida_b.txt`.

### B.0 · El modelo, y por qué NO es «una muestra del retardo»

La verificación del PoT es **secuencial**: «el seed del slot n+1 es la salida del slot n»
(`DECISIONES.md` §19, bloque de la aceleración de los 128 B, línea 1851), y Autonomys descarta
por gossip las pruebas de slots viejos y de slots demasiado futuros
(`subspace/crates/sc-proof-of-time/src/source/gossip.rs:576-600`, `MAX_SLOTS_IN_THE_FUTURE = 10`
en `:30`). Luego **la frontera verificada de un nodo avanza solo cuando llega el SIGUIENTE
slot**: un solo slot retrasado la atasca aunque los posteriores ya estén en la red.

Con `D_s` iid el retraso observado es `L_c = max(0, max_{j≥0}(D_{c−j} − j·σ))`, y su cola
tiene forma cerrada exacta: `P(L ≤ x) = ∏_{j≥0} F_D(x + j·σ)`.

**Control positivo** (forma cerrada contra Monte Carlo de 4·10⁶ slots):

| cola | p99 | x | cerrada `P(L>x)` | Monte Carlo |
|---|---:|---:|---:|---:|
| lognormal | 8 | 8,0 | 0,014760 | 0,014831 |
| lognormal | 8 | 12,0 | 0,000172 | 0,000170 |
| lognormal | 16 | 20,0 | 0,016821 | 0,016810 |
| Pareto | 8 | 20,0 | 0,000274 | 0,000231 |

**VERIFICADO.** Y el control de capacidad: `P(D>8) = 0,0100` frente a `P(L>8) = 0,01476` —
la cola de la frontera secuencial es **estrictamente más pesada** que la de una muestra suelta,
que es exactamente lo que el modelo secuencial predice. **Un análisis que hubiera usado el
cuantil de `Δ` a secas habría subestimado `B`.**

**Hipótesis declaradas:** (a) mediana del retardo honesto de entrega del PoT = `Δ` nominal =
4 s; (b) retardos iid entre slots; (c) dos familias de cola, lognormal (la que pide el
encargo) y **Pareto ajustada a la misma mediana y p99**, como control de robustez —
extrapolar seis órdenes de magnitud más allá del p99 es una hipótesis, no un dato.

### B.1 · `B` para menos de 1 falsa alarma al año

`ε` = error del reloj de pared (deriva). Dos contabilidades: **por excursión** (cada excursión
la arranca un único slot con `D_s > B`, luego `excursiones/año = 3,15·10⁷·P(D>B)`; es la cuenta
operativa) y **por slot** (conservadora, cuenta cada segundo en alarma).

| cola | p99 (s) | ε (s) | **B (excursión)** | B (por slot) |
|---|---:|---:|---:|---:|
| lognormal | 8 | 0,1 | **20,14** | 20,70 |
| lognormal | 8 | 1,0 | **21,04** | 21,60 |
| lognormal | 8 | 10,0 | 30,04 | 30,60 |
| lognormal | 16 | 1,0 | **101,43** | 133,20 |
| Pareto | 8 | 1,0 | **76,40** | 138,92 |
| Pareto | 16 | 1,0 | 1 422,41 | 50 691,69 |

**El resultado incómodo, dicho pronto:** `B` es hipersensible a la forma de la cola. Con la
misma mediana y el mismo p99 = 8 s, la lognormal pide `B = 21 s` y la Pareto `B = 76 s`. Con
p99 = 16 s la Pareto pide **1 422 s**, es decir, E1 dejaría de servir para nada. **Fijar `B`
por «1 falsa alarma al año» exige conocer la cola, y la cola no se conoce: LAGUNA.**

### B.2 · La salida: el precio de una falsa alarma es despreciable

Lo anterior deja de ser un problema en cuanto se mide **cuánto cuesta** una falsa alarma. Una
excursión dura `D_s − B` segundos; si el nodo deja de autorizar durante ella, pierde
`f_v·λ·duración` bloques. Medido con 12 semillas × 3·10⁵ slots (`salida_b.txt` B.8), para un
granjero con `f_v = 0,05` (que produce 1,58·10⁶ bloques/año):

| cola | p99 | B | alarmas/año | s/año en alarma | bloques perdidos/año | **% de su producción** |
|---|---:|---:|---:|---:|---:|---:|
| lognormal | 8 | 20 | 1,04 | 0 | 0 | 0 % |
| lognormal | 16 | 30 | 1,14·10⁴ | 6,72·10⁴ | 3 360 | **0,21 %** |
| Pareto | 8 | 20 | 1,79·10³ | 9 900 | 495 | **0,03 %** |
| Pareto | 16 | 30 | 5,35·10⁴ | 8,71·10⁵ | 43 500 | **2,8 %** |
| Pareto | 16 | 100 | 1,79·10³ | 8,98·10⁴ | 4 490 | **0,28 %** |

**Con `B = 30 s`, incluso bajo la cola de potencia más agresiva que ajusta al p99 = 16 s, el
granjero pierde el 2,8 % de sus bloques por falsas alarmas — y bajo la hipótesis nominal,
el 0 %.** Es decir: **la elección de `B` no necesita resolver la LAGUNA de la cola**, porque
el criterio «< 1 falsa alarma/año» era el criterio equivocado para el umbral de *paro*.
DEMOSTRADO por la aritmética de arriba, con los números medidos.

### B.3 · Tiempo de detección

Variante (i), PoT retenido: `L` crece exactamente 1 s/s, luego la detección es casi
determinista (200 corridas):

| cola | p99 | ε | B | mediana | p99 | máx |
|---|---:|---:|---:|---:|---:|---:|
| lognormal | 8 | 1,0 | 21,04 | **16,0 s** | 18,0 s | 18,0 s |
| lognormal | 16 | 1,0 | 101,43 | 94,0 s | 99,0 s | 99,0 s |
| Pareto | 8 | 1,0 | 76,40 | 72,0 s | 72,0 s | 72,0 s |

`t_det ≈ B − L(t_ataque)`, con `L` de mediana ≈ 4-5 s. **La dispersión es de 2 s: E1 no tiene
cola de detección.**

Variante (iii), retraso `E` (mediana / fracción de corridas que detectan, 200 corridas):

| cola | p99 | B | E=20 | E=60 | E=200 |
|---|---:|---:|---|---|---|
| lognormal | 8 | 21,04 | **1,0 s / 100 %** | 1,0 s / 100 % | 1,0 s / 100 % |
| lognormal | 16 | 101,43 | 17 129 s / **0,5 %** | 6 211 s / 68 % | 1,0 s / 100 % |
| Pareto | 8 | 76,40 | **NUNCA** | 3 367 s / 100 % | 1,0 s / 100 % |

**E1 detecta la variante (iii) en 1 segundo si `E > B`, y es ciego si `E < B`.** Con `B = 21 s`
cubre `E ≥ 20 s`; con `B = 101 s` no ve el `E = 60 s` que la sección A.3 mostró que ya cuesta
el 100 % de la recompensa. **Otro argumento para NO subir `B`.**

Variante (ii), filtro de bloques con el PoT intacto: **0 disparos en 200 corridas de 20 000 s.
E1 es ciego a (ii)**, como debía. Control negativo correcto.

### B.4 · La persistencia no compra nada en E1

Exigir que la alarma dure `m` slots equivale **exactamente** a exigir `D_s > B + (m−1)·σ`,
porque `L` decae de forma determinista a 1 s/slot. Comprobado numéricamente (B.6): `B(m)+m−1`
es constante (20,04 para lognormal p99=8; 1 421,41 para Pareto p99=16) y el tiempo de
detección **no se mueve** (16,0 s para todo `m ∈ {1, 3, 10, 30}`). **DEMOSTRADO.** (En E2 sí
comprará: allí el ruido es Poisson y no decae de forma determinista.)

### B.5 · `B` del sensor y `B` de la atadura sello-slot son el MISMO número

La atadura decidida (`DECISIONES.md` línea 1608) es
`|timestamp − (TIEMPO_GENESIS + slot·σ)| ≤ B`. Un nodo honesto pone en `timestamp` su reloj de
pared y en `slot` el último slot de PoT **que ha verificado**: la diferencia es exactamente
`L + ε`. Luego:

- si `B_consenso < B_sensor`, el nodo **emite bloques que la red rechaza sin que suene ninguna
  alarma** — el peor de los mundos;
- si `B_consenso > B_sensor`, la alarma llega antes de perder bloques (margen), pagando más
  espacio de grinding al timestamp (el espacio es `2B`).

**DEMOSTRADO: hay que derivarlos juntos, y `B_sensor ≤ B_consenso`.** Para «1 bloque honesto
rechazado al año» el consenso pide `B = 20,04 s` (lognormal p99=8) y `B = 100,43 s`
(lognormal p99=16). Este acoplamiento **no estaba escrito en ningún sitio** y es la primera
consecuencia de esta ronda sobre una decisión ya tomada.

### B.6 · Qué pasa si el timekeeper cae de verdad

E1 **no distingue** eclipse de caída del timelord, y no puede: las dos se ven igual desde el
nodo. La regla tiene que servir para las dos, y por suerte la respuesta correcta coincide:

1. **MUST NOT autorizar** — sin PoT fresco el bloque es inválido por la atadura sello-slot
   (B.5), así que no se pierde nada al no emitirlo.
2. **MUST alertar** al operador con las dos causas nombradas.
3. **MUST renovar pares** — es lo único que distingue las dos causas: si tras rotar a pares de
   prefijos distintos el PoT sigue sin llegar, es caída de la red; si llega, era eclipse.
   **Esa rotación es el discriminador, y por eso va en la regla.**
4. **MUST NOT puntuar ni banear** a los pares por esto (C-NET-05: lento ≠ malicioso).

### B.7 · Recomendación de `B`

| | valor | por qué |
|---|---|---|
| **`B_paro` (dejar de autorizar, alertar, rotar pares)** | **30 s** | cubre `E ≥ 30 s` de la variante (iii); cuesta ≤ 2,8 % de la producción en el peor modelo de cola y 0 % en el nominal; detección de (i) en **≈ 25 s** |
| **`B_aviso` (un comerciante no confirma)** | **10 s** | 3,3·10⁴ avisos/año bajo la hipótesis nominal, de 1,5 s de media: el comerciante espera dos segundos más, no pierde dinero |
| **`B_consenso` (atadura sello-slot)** | **≥ `B_paro`; propuesta 30 s** | si es menor, se pierden bloques sin alarma (B.5) |

**Etiqueta:** el `B = 30 s` es **PLAUSIBLE**, no VERIFICADO: descansa en la hipótesis
«mediana del retardo del PoT = 4 s» y en una familia de colas elegida, no medida. Lo que sí
está **VERIFICADO** es la forma cerrada, el tiempo de detección dado `B`, la insensibilidad a
la persistencia y el coste de la falsa alarma.

---

## C · Sensor E2 (bloques por ventana)

**Script:** `r11b_c_e2.py` · **salida:** `salida_c.txt`.
**Regla:** alarma si la ventana deslizante `(t−W, t]` contiene **estrictamente menos de
`n_min(W)`** bloques nuevos y válidos; se evalúa cada slot.

### C.0 · Control positivo — ¿es Poisson lo que ve un nodo del DAG?

Sobre el DAG completo (`MundoVictima` con `paso = 1`, sin eclipse, horizonte 3 000 s,
12 semillas, 300 s de calentamiento descartados):

| α | W | media | esperada `λW` | **var/media** | n ventanas |
|---:|---:|---:|---:|---:|---:|
| 0,00 | 30 | 28,41 | 30,0 | **1,011** | 1 080 |
| 0,00 | 60 | 56,83 | 60,0 | **1,046** | 540 |
| 0,00 | 120 | 113,48 | 120,0 | **1,052** | 264 |
| 0,00 | 300 | 284,15 | 300,0 | 0,837 | 108 |
| 0,33 | 60 | 57,89 | 60,0 | 1,027 | 540 |

**VERIFICADO: el índice de dispersión es 1 (Poisson) dentro del error de muestreo.** El DAG
no añade sobredispersión; la fila `W = 300` tiene solo 108 ventanas y su 0,84 es ruido de
muestreo (error estándar de var/media con n=108 es ≈ 0,14).

**Y un hallazgo de implementación que sale del control:** la media es 28,41 y no 30 — un
déficit del 5,3 %, que es **exactamente `f_v = 0,05`**, la fracción de bloques que produce el
propio nodo y que el instrumento no contaba como «llegada». **La regla debe contar los
bloques propios**: si no, un granjero grande se alarma solo. Va en el texto de la regla (§E).

### C.1 · Umbral `n_min(W)` con menos de 1 falsa alarma al año

| W (s) | `s_λ` | **`n_min` (cota por slot)** | `n_min` (disjunta) | `P(N<n_min)` | **α mínima para evadir** |
|---:|---:|---:|---:|---:|---:|
| 30 | 0,00 | **6** | 8 | 2,26·10⁻⁸ | **0,200** |
| 60 | 0,00 | **23** | 28 | 1,60·10⁻⁸ | **0,383** |
| 120 | 0,00 | **66** | 74 | 2,79·10⁻⁸ | **0,550** |
| 300 | 0,00 | **211** | 229 | 2,48·10⁻⁸ | **0,703** |
| 60 | 0,10 | 16 | 21 | 1,99·10⁻⁸ | 0,267 |
| 300 | 0,10 | 125 | 159 | 2,81·10⁻⁸ | 0,417 |
| 300 | **0,20** | **0** | 41 | — | **0** |

`s_λ` = desviación relativa de la tasa real dentro de la ventana (churn de granjeros,
retraso del retarget). **HIPÓTESIS DECLARADA, no medida.**

**El resultado duro:** si la tasa real fluctúa un 20 % (`s_λ = 0,20`), **la ventana deslizante
con menos de 1 falsa alarma al año exige `n_min = 0`: el sensor deja de existir.** E2 vive o
muere según lo estable que sea `λ` en la red real. Con `s_λ ≤ 0,10` sigue siendo utilizable
(α mínima para evadir 0,27-0,42). **LAGUNA: `s_λ` no está medido y solo se mide en red real.**

### C.2 · Falsas alarmas medidas (cruces por año), 12 semillas × 10⁶ s

| W | `s_λ` | `n_min` | cruces/año medidos | cota «por slot» | segundos simulados |
|---:|---:|---:|---:|---:|---:|
| 30 | 0,00 | 6 | **0** | 0,712 | 1,2·10⁷ |
| 30 | 0,00 | 8 *(relajado)* | 2,63 | 16,51 | 1,2·10⁷ |
| 60 | 0,00 | 23 | **0** | 0,504 | 1,2·10⁷ |
| 60 | 0,00 | 27 *(relajado)* | 5,26 | 20,20 | 1,2·10⁷ |
| 120 | 0,00 | 75 *(relajado)* | 31,5 | 133,7 | 1,2·10⁷ |
| 300 | 0,00 | 235 *(relajado)* | 147,2 | 1 376 | 1,2·10⁷ |

Con el `n_min` recomendado el Monte Carlo da **0 cruces en 1,2·10⁷ s por ventana**, que es lo
que debe salir a `P ≈ 2·10⁻⁸`. Los umbrales *relajados* existen para que la comparación sea
medible: la **cota «por slot» es conservadora por un factor 6-9**, VERIFICADO. Es decir, el
`n_min` de C.1 tiene todavía margen de seguridad.

### C.3 · Tiempo de detección, variante (ii) — la tasa cae a `α·λ`

12 semillas × 200 réplicas = 2 400 corridas por celda; la última columna es el rango de la
mediana **entre semillas** (regla 5).

| W | `n_min` | α | mediana | p99 | detecta | rango entre semillas |
|---:|---:|---:|---:|---:|---:|---|
| 30 | 6 | 0,00 | **25,0 s** | 29,0 s | 100 % | 24 – 25 |
| 30 | 6 | 0,10 | 27,0 s | 53,0 s | 100 % | 27 – 28 |
| 30 | 6 | 0,33 | 100,0 s | 583,0 s | 100 % | 76 – 116 |
| 60 | 23 | 0,00 | **38,0 s** | 47,0 s | 100 % | 38 – 38 |
| 60 | 23 | 0,10 | 42,0 s | 53,0 s | 100 % | 41 – 43 |
| 60 | 23 | 0,33 | **56,0 s** | 150,0 s | 100 % | 55 – 57 |
| 120 | 66 | 0,33 | 81,0 s | 107,0 s | 100 % | 80 – 83 |
| 300 | 211 | 0,00 | 90,0 s | 122,0 s | 100 % | 88 – 93 |
| 300 | 211 | 0,33 | 134,0 s | 181,0 s | 100 % | 131 – 137 |

**Detección del 100 % en todas las configuraciones.** Criterio α satisfecho: la mediana sube
monótonamente con α (25 → 27 → 100 a `W = 30`). La cola de `W = 30, α = 0,33` (p99 = 583 s)
es la peor del cuadro: con ventana corta y un atacante que aporta un tercio del tráfico, la
alarma puede tardar diez minutos. **`W = 60` es más rápido en p99 (150 s) que `W = 30`
(583 s) para el atacante que importa**, y ese es el argumento para no elegir la ventana más
corta.

### C.4 · Tiempo de detección, variante (iii) — retraso `E`

| W | `n_min` | E=20 s | E=60 s | E=200 s |
|---:|---:|---|---|---|
| 30 | 6 | 23 s / **23,5 %** | 25 s / 100 % | 25 s / 100 % |
| 60 | 23 | 37 s / **1,5 %** | 38 s / 100 % | 38 s / 100 % |
| 120 | 66 | — / **0,1 %** | 54 s / 97,9 % | 55 s / 100 % |
| 300 | 211 | **NUNCA / 0 %** | 128 s / 15,5 % | 91 s / 100 % |

Confirma lo de A.3: **E2 solo ve la variante (iii) durante el hueco inicial de duración `E`.**
Si el atacante *sube el retraso poco a poco* en vez de de golpe, no hay hueco y **E2 es ciego
del todo** (no simulado; es consecuencia directa de que el régimen tiene tasa λ — **PLAUSIBLE**).
Ese caso lo cubre E1, que mide el retraso y no la tasa.

**Control negativo (C.5):** sin ataque (`paso = 1`), E2 dispara en 0,04 % de 2 400 corridas de
6 000 s a `W = 30` y en **0,00 %** en las otras tres ventanas. Correcto.

### C.5 · El coste del atacante: qué `α` necesita para NO disparar E2

`α` mínima para que el número esperado de alarmas durante un ataque de duración `T` sea < 0,1:

| W | `n_min` | T = 10 min | T = 2 h | T = 24 h |
|---:|---:|---:|---:|---:|
| 30 | 6 | 0,6297 | 0,7374 | 0,8411 |
| 60 | 23 | 0,7377 | 0,8138 | 0,8850 |
| 120 | 66 | 0,8264 | 0,8809 | 0,9308 |
| **300** | **211** | **0,8904** | **0,9249** | **0,9562** |

**Este es el resultado más fuerte de la ronda.** Bajo PoST el atacante que eclipsa **no puede
fabricar tasa**: los bloques que le enseña a la víctima tienen que ser suyos, y suyos significa
respaldados por espacio. Con las cuatro ventanas corriendo a la vez necesita el mayor de los
cuatro valores:

> **Para sostener un eclipse-filtro de 2 horas sin una sola alarma de E2, el atacante necesita
> el 92,5 % del espacio de la red. Para 24 horas, el 95,6 %.**

Compárese con el umbral de seguridad del diseño (33 % operativo, frontera 46,9 %): **E2
convierte el doble gasto por eclipse en un ataque más caro que tomar la cadena entera.**
DEMOSTRADO a partir de la cola de Poisson, con el `n_min` verificado en C.2.

Y la contrapartida honesta: el atacante **no necesita evadir E2 para robarle los bloques** al
granjero (variante ii con α=0 le cuesta el 100 % de la recompensa, A.2). E2 no impide el robo;
lo hace **visible en 25-38 s**, que es lo que se puede pedir de un sensor.

Falsas alarmas de las cuatro ventanas juntas: cota «por slot» sumada = **2,878/año**, y
medido 0 cruces en 1,2·10⁷ s por ventana.

### C.6 · Recomendación de `W` y `n_min`

| | valor | por qué |
|---|---|---|
| **Ventana del nodo (paro de autoría, alerta, rotación)** | **`W = 60 s`, `n_min = 23`** | detección 38 s (α=0) y 56 s (α=0,33) con p99 de 150 s; α para evadir 0,383 |
| **Ventana del comerciante (no confirmar)** | **`W = 300 s`, `n_min = 211`** | la más cara de evadir: 92,5 % del espacio para 2 h |
| **Ventana rápida (aviso, sin paro)** | `W = 30 s`, `n_min = 6` | detección en 25 s; su p99 a α=0,33 es malo, por eso solo avisa |

Si `s_λ` medido en red real supera **0,10**, hay que **recalibrar `n_min` con la tabla de C.1**
o el sensor deja de tener falsas alarmas aceptables; por encima de 0,20 **E2 no es viable** y
habría que sustituirlo por un test relativo (comparar la tasa observada con la que implica la
dificultad vigente) — no analizado aquí, **LAGUNA**.

*(secciones D a F, pendientes)*
