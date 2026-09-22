# DECISIONES-PENDIENTES — P-ADELANTO

Bifurcaciones **reales** para Katana, con lo que gana, lo que paga y lo que cierra cada opción.
**No he decidido ninguna.** Todas las cifras salen de
`investigacion/veritas/seguridad/adelanto-v1/` (`run.jl`, `resultados/`) y son funciones de sus
símbolos: al barrer un parámetro cambian.

Contexto que vale para todas: `A` (ventana de retos futuros que el atacante conoce por delante) vale
**`L + I − W_dec − D`** en el régimen estacionario y **no depende de `ρ`**; `+D` **resta**; y `(h)`
baja la ventana de `L + I` a `≈ I`, es decir por el factor `ρ*`.

---

## D-ADL-1 · `ρ_max`: cuánta ventaja de reloj admite ZEROX

**Es la primera, y las otras dos dependen de ella.**

| Opción | `A` sobre `[1, ρ_max]` | Edad `M` exigida | Coste por nodo | Qué cierra |
|---|---|---|---|---|
| **A · `ρ_max = 3` sin (h)** | `8 027` slots con `F = 2 h`; **no baja con `ρ`** | `M > ~F_slots` (**horas**) | 0,0961 núcleos, 1 línea | nada del adelanto; solo acota `n_eval` |
| **B · `ρ_max = 2,5` con (h)** | **`0`** si `ρ_max ≤ ρ*` | `M > margen` | **0,2425** núcleos (0,1464 de revelación + 0,0961 de cadena), 3 líneas (`I* = 4 725 s` con `W_dec = 45`) | el adelanto entero dentro de la región |
| **C · `ρ_max = 9` con (h)** | `0` | `M > margen` | **0,911** núcleos (0,815 + 0,096), 10 líneas (`I* = 849 s`) | igual, pagando 3,8× más CPU |

*(Todos con `F = 7 200` y `W_dec = 45`. Con `W_dec = 20` los costes son 0,2413 y 0,8846: la
diferencia es el factor `I/(I+W_dec)`.)*

**Lo que decide.** El techo físico estimado del reloj AES es **1,5–2,5×** (`research/pot-aes-asic-chacha.md:40-42`,
**estimación**; el estudio de Supranational sigue sin localizar). **Con `ρ_max = 2,5` se cubre el techo
estimado con 0,2425 núcleos y 3 líneas; `ρ_max = 3` sin (h) no compra nada del adelanto, porque sin (h)
`A` no baja de `L + I − W_dec − D` para ningún `ρ`.** El argumento histórico de «`3×` sin segundo VDF»
queda así **cuantificado en contra**: no es una alternativa más barata a (h), es una alternativa que
**no ataca el vector**.

**Lo que queda sin determinar.** `ρ` real medido por plataforma (§7.2 del `INFORME.md`). Sin esa
medición, `ρ_max` se elige contra una estimación.

---

## D-ADL-2 · `L_suelo_slots`: la palanca que decide si `(h)` sirve para acortar `F`

Hallazgo del encargo §4.4, y **es el resultado principal de la Fase 2**.

```text
si L_slots = F_slots       ⇒ ρ*(F) = (F + I)/(I + W_dec)          realimentación ACTIVA
si manda L_suelo_slots     ⇒ ρ* NO depende de F                   realimentación CERO
```

| Opción | Efecto | Consecuencia |
|---|---|---|
| **A · `L_suelo_slots = 0`** (dejar `L` atado a `F`) | bajar `F` a `F_carrera = 1 019 s` baja `ρ*` de 9,24 a **2,147** | `(h)` **deja de cegar a `ρ > 2,147`**, que está **dentro del techo físico estimado (1,5–2,5×)**. Se puede calibrar hasta `ρ_max ≈ 6,84` (tope por `I > S_max`), pero con `A > 0`: `ρ_max = 2,5` ⇒ `A = 118`; `ρ_max = 5` ⇒ `A = 492` |
| **B · fijar `L_suelo_slots = 3 600 s`** | con `F = 1 019` o `F = 1 800`, `L = 3 600` y **`ρ* = 5,11` idéntico** | `(h)` cega hasta `ρ = 5,11` con `F = 0,28 h`; **la bajada de `F` sale gratis en protección**, y se paga 0,503 núcleos y 6 líneas |
| **C · no decidir** | `L_suelo_slots` sigue `<<PENDIENTE>>` | `(h)` queda sin calibrar: `ρ*` dependiente de `F`, y la protección real puede quedar por debajo del techo estimado del reloj (1,5–2,5×) |

**Lo que gana B.** Separa las dos magnitudes que `C-FLU-01` dice que son distintas: `F` responde a la
finalidad y `L` a la cola de desacuerdo frente a `Δ`. Es lo que el propio SPEC ya escribe
(`SPEC.md:1530-1532`) y lo que aquí se ve **cuantificado**: sin suelo, (h) **no** permite bajar `F` sin
perder protección.

**Lo que paga B.** El coste por nodo de (h) queda con suelo `0,0961·(1 + L_suelo/I)`:
**0,503 núcleos y 6 líneas** con `L_suelo = 3 600`, `I = 851`. Es 2,4× el coste de la opción A con
`F = F_carrera`.

**Lo que cierra.** El criterio de `TAREAS.md` §3.1 para fijar `L_suelo_slots` exige **`Δ` medida en red
real**, que sigue **simulada** (`veritas/finalidad/delta-medido-v1/`, DMS-v0.1). **No se puede fijar
hoy sin violar ese criterio**; lo que se puede decidir hoy es si **se acepta que (h) no comprará la
bajada de `F`** mientras `L_suelo_slots` no esté fijado.

---

## D-ADL-3 · La cota de la edad `M` de `P-SEMBRADOR` (A1+C1)

| Opción | Cota | Con `F = 2 h` | Con `F = 0,28 h` |
|---|---|---|---|
| **A · sin (h)** | `M > L + I − W_dec − D + margen` | **> 2,23 h** | > 0,51 h |
| **B · con (h), `ρ_max ≤ ρ*`** | `M > margen` | **> margen** | > margen |
| **C · con (h), `ρ_max > ρ*`** | `M > (I + W_dec − 1) − (L+I)/ρ_max − D + margen` | p. ej. `ρ_max = 12` ⇒ **> 195 s** | `ρ_max = 20` ⇒ 118 s |

**Lo que gana B.** A1+C1 pasa de exigir una **edad de horas** a exigir una **edad de margen**: es la
diferencia entre «registrar la parcela y esperar dos horas y media» y «registrar la parcela y esperar
la propagación». Es la única opción que hace a A1+C1 compatible con granjeros pequeños.

**Lo que paga B.** El coste por nodo de (h) en cada nodo de la red, permanentemente, más `q+1` líneas
en el timekeeper (§4.1 del `INFORME.md`).

**Lo que queda sin determinar.** `margen` (red + finalidad) no lo fijo yo: es símbolo. Y el **coste
medido del intento dirigido** del sembrador sigue sin existir, así que la cota es **temporal**, no
económica.

---

## D-ADL-4 · El tiempo de sellado secuencial adversarial

| Opción | Cota | Con `F = 2 h` | ¿Granja doméstica? |
|---|---|---|---|
| **A · sellado como candidata aislada** | `T_seal,adv > L + I − W_dec − D` | **> 2,23 h por sector** | **No**: el honesto paga lo mismo |
| **B · sellado con `F` corta** | igual, pero con `L = F` | **> 0,51 h por sector** con `F = 0,28 h` | **Sí**, como coste de alta único |
| **C · sellado con (h) adoptada** | `T_seal,adv > 0` | 0 | la candidata deja de ser necesaria para este vector |

**Lectura.** El sellado secuencial **no es una alternativa a (h): es una alternativa a `F` larga**. Su
viabilidad está acoplada a `D-ADL-2` por la misma realimentación. **Se cae sola si `F` es de horas.**

---

## D-ADL-5 · La prohibición de `C-POT-03` (derivar el reto de `pot_output`)

**No es una bifurcación abierta, es una cuantificación.** Si se levantara la prohibición
(`SPEC.md:1383-1386`; `R-FIN-14(e)`), el adelanto **ganaría exactamente `+D` slots**: `A_add = A_core + D`
(columna medida en `resultados/BARRIDO-D.tsv`). Con `D = 4` son 4 slots; con `D` creciendo a `45` o
`150`, la ventana crece en la misma proporción **y el acantilado de `ρ = 1` empeora**. Lo que cierra el
caso: `C-POT-03` y `R-FIN-14(e)` ya lo prohíben, y este informe pone número a lo que la prohibición
vale. **No requiere decisión; requiere que la prohibición no se relaje.**

---

## Lo que **no** es una bifurcación, aunque lo parezca

- **«¿Restar o cancelar `D`?»** No es una elección de política: es una **premisa de implementación**
  (§2.2 y premisa 6 del `INFORME.md`). La decisión real es **escribir la disciplina del timekeeper en
  el SPEC o medirla en `prototipos/pot-estable`**. Mientras no se haga, la cifra de `M` de `D-ADL-3`
  arrastra esa incertidumbre y hay que decirlo.
- **`K = 30` y las constantes de `R-FIN-13`**: fuera del alcance de este encargo.
- **La primitiva `blake3` + AES-128**: decidida (`D-1 = A`, `P-ZRX/P-POT/propuesta/DECISIONES-PENDIENTES.md:11-14`)
  y `research/pot-aes-asic-chacha.md` ya cerró que sustituirla empeora el hueco CPU↔ASIC. No se reabre.
