# DECISIONES PENDIENTES — P-REVELACION

Las bifurcaciones reales para Katana, en orden de dependencia. Ninguna la toma este informe:
`F`, `L_suelo_slots`, `I_slots`, `Lrev`, `D`, `S_max`, `W_dec`, `ρ_max` y `α` siguen siendo
símbolos (encargo §9), y **ningún resultado de aquí es una constante escrita a mano**.

---

## D1 · `ρ_max` — la primera, y ahora con una consecuencia distinta de la que ADL anunciaba

**Qué se decide.** La cota admitida para la velocidad AES de un atacante frente al timekeeper.
Es estimación, no medida: el techo físico es **1,5-2,5×** (`research/pot-aes-asic-chacha.md:40-42`,
sin paper; el estudio de Supranational sigue sin localizar).

**Qué gana cada opción.** Nada de la ventana `V` sin (h): para cualquier `ρ > 1` la ventana es
`≈ L` tras el *bootstrap* (`F1.txt`, medido en `[7 175; 8 030]` con `L = 7 200`). Lo que `ρ_max`
gobierna es **cuánto `A` cae por debajo de la envolvente `L+I`**: `I/ρ` slots
(851 slots a `ρ = 1`, 425 a `ρ = 2`, 284 a `ρ = 3`, 85 a `ρ = 10`).

**Qué paga.** Acotar `ρ_max` **no cuesta nada hoy**, porque sin (h) `A` no baja de `L + I − W_dec − D`
por ningún `ρ`. Su único efecto real es **cuánto `I` hay que comprar si se adopta (h)**: la
calibración (h.6) exige `I ≤ (L − ρ_max·W_dec)/(ρ_max − 1)`, y eso crece al bajar `ρ_max`
(`F3.txt`: `I* = 4 767` a `ρ_max=2,5` frente a `35 880` a `ρ_max=1,2` con `F = 7 200`).

**Qué cierra.** Fijar `ρ_max` cierra el capítulo de la aritmética del adelanto que `TAREAS.md` §2.9(c)
punto 11 dejó abierto («ninguna cifra de adelanto debe darse por válida hasta que se rehaga»).
Este informe la rehace para `ρ_max` simbólico; **la elección del número sigue siendo de Katana** y
depende de una medición que no existe.

**Recomendación de proceso (no de valor).** Tratar `ρ_max` como **entrada declarada** en el SPEC
(como `W_dec`), no como constante derivada, y ligar a ella la calibración de `I` si (h) se adopta.

## D2 · ¿Se adopta (h)? — qué compra y qué paga, en números

| | sin (h) | con (h), `Lrev = L − S_max` |
|---|---|---|
| ventana `V` (régimen, `ρ=2,5`) | 7 685,6 slots (banda `[7 175; 7 690]`) | **4 865,6 slots** (banda; `α=0,33`, `ρ ∈ [1,3]`: q99 = 3 648) |
| edad exigida `q99` (`F=7 200, ρ_max=2,5`) | **8 800** | **5 712** (factor **1,54×**) |
| coste por nodo | 0,0961 núcleos | 0,241 núcleos + **3 líneas** (con `I` recalibrada a 4 767) |
| líneas de AES por timekeeper | 1 | `q+1 = 3` (calibrado) / 10 (sin recalibrar) |
| instantes `t_j`/hora | los mismos | **0,76** con `I = 4 725` |
| vector nuevo | — | un lado de partición con `< q+1` líneas **deja de farmear** |
| regla del SPEC que cambia | — | **`C-FLU-12`** (`SPEC.md:1673-1677`): la entropía pasa de `blake3(chunk ‖ pot_output)` a un VDF de esa semilla; `t_j`, `flujo` y validez **no** cambian |

**Lo que (h) compra de verdad, en factor:** baja la edad exigida por **1,2× a 4,6×** según `F` y
`ρ_max` (`F4.txt`); el factor es grande cuando `F` es de horas y `ρ_max` bajo, y pequeño cuando `F`
es de carrera. **Lo que NO compra:** no anula `V` (falla la premisa con la que se iba a decidir),
no elimina el ataque del sembrador (sólo encarece la adaptación), y no elimina la necesidad del
sellado secuencial ni de A1+C1 salvo que se acepte `M > q99` como cota.

**Qué cierra cada camino.**
- **Adoptar (h) con `I` recalibrada a `ρ_max`:** cierra la pregunta del adelanto para `ρ ≤ ρ_max`,
  paga 0,24 núcleos/nodo y 3 líneas, y **abre** `PRESUP_NODO` (ADL §3.3: la partida de adopción de
  `C-FLU-22` no está derivada). Si `ρ_max` resulta ser 1,5, la calibración exige `I = 14 340` y una
  inyección cada 3,3 h (`F3.txt`).
- **No adoptarla:** la ventana queda en `≈ L` para todo `ρ > 1` y el sembrador sigue necesitando
  A1+C1 con una edad `> q99 ≈ L`. Es la opción que **no** cambia el SPEC.

## D3 · `L_suelo_slots` — la palanca que decide si (h) sirve para acortar `F`

Sigue **símbolo** (`SPEC.md:1538`). Lo que este informe añade: con `L_suelo_slots = 0` y
`F ≤ S_max+1`, `C-FLU-01` colapsa `L` a `S_max+1`, y entonces `ρ*` queda atado a `F` (`F3.txt`);
con `L_suelo = 3 600`, `ρ*` deja de depender de `F` y la contradicción de ADL desaparece. **La
decisión no es de alcance informático**: el criterio escrito exige una cota de `Δ` **medida en red
real** (`TAREAS.md` §2.9(a) 6), que no existe.

## D4 · La forma de la cota de edad `M` — cuantil, no `sup`

`P-SEMBRADOR` condiciona A1+C1 a `M > sup A`. **Con rachas de ancla propia `V` no está acotada**
(`F2.txt`: máximo observado 13 358 con `α = 0,40`, por encima del q99,9 = 8 032), luego
**ningún `sup` finito sirve** y la cota debe escribirse como
`M > cuantil_q(V | ρ ∈ [1, ρ_max]) + margen`, con `q` y la tasa de excedencia **explícitos en el
SPEC**. Es un cambio de redacción, no de protocolo, y este informe entrega las tablas.

## D5 · `α` — deja de ser un detalle de simulación

La probabilidad de que el ancla de una época sea del atacante fija **la cola** de `V` (q99 pasa de
5 536 con `α = 0,10` a 6 656 con `α = 0,40`, y la tasa de excedencia 40×). **No está medida en
red.** Mientras lo esté, cualquier cota de edad debería publicarse como **familia** en `α`, no como
número.

## D6 · El techo de `ρ_max` lo pone `C-FLU-09`, no (h.6) — decidir si se acepta

A `F = F_carrera` (`L = 1 019`, `S_max = 150`, `W_dec = 20`) la condición `I* > S_max` da
**`ρ_max < 6,84`**, igual que midió ADL; por encima, `I` tendría que ser menor que `S_max` y
`C-FLU-09` lo prohíbe. **Decisión:** aceptar ese techo como propiedad del perfil o admitir
`S_max < I` con otro reparto. No cambia con (h).

## Lo que **no** es una bifurcación (y conviene no reabrirlo)

- **`D` resta en el estacionario y se cancela en el transitorio**: medido, coincide con ADL. No hay
  nada que decidir, salvo ratificar `C-POT-05` como está.
- **`I ≥ ρ_max·W_dec`** (`R-FIN-14(f)`): sobrevive.
- **La primitiva** (AES-128 + `blake3`, D-1 = A): `(h)` no la cambia; añade una cadena con la misma
  primitiva.
- **`C-FLU-13/14` (validez absoluta y pasado consistente):** no se reabren. `(h)` no introduce
  ninguna rama de validez condicionada a la vista (la entropía **se calcula**, no se publica).
