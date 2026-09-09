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

*(secciones B a F, pendientes)*
