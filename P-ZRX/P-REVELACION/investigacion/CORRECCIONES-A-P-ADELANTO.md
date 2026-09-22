# CORRECCIONES A P-ADELANTO (ADL-v1.0)

Lista precisa de qué afirmaciones de
`P-ZRX/P-ADELANTO/investigacion/INFORME.md` quedan **confirmadas**, **corregidas** o **refutadas**,
con la fila de evidencia de cada una. Cada fila cita el texto de ADL tal como está escrito, no una
paráfrasis. La evidencia vive en
`P-ZRX/P-REVELACION/investigacion/veritas/seguridad/revelacion-v1/resultados/`.

Nota de alcance: ADL-v1.0 **reproduce** sus formas cerradas y sus regresiones; lo que se contrasta
aquí no es su aritmética, es **el objeto que sus fórmulas describen**.

## 1 · Lo que cae — y es lo que Katana iba a decidir

| # | Afirmación de ADL (fuente) | Veredicto | Evidencia |
|---|---|---|---|
| A1 | «**`A` no depende de `ρ` en el régimen estacionario**» (`INFORME.md:52`, titular) | **REFUTADA** en su forma exacta | `ADL.txt`: `V_max` simulada toma 7 600,50 (`ρ=2`), 7 742,33 (`ρ=3`), 7 931,44 (`ρ=9`), 8 017,49 (`ρ=100`). **Depende de `ρ`**, y `L+I−W_dec−D = 8 027` **no se alcanza** para ningún `ρ` finito. La afirmación es cierta **sólo como límite `ρ → ∞`** |
| A2 | «**`A_core` subestima `A` para todo `ρ` realista**» (`INFORME.md:58-61`) | **REFUTADA** | `ADL.txt`, columnas `V_max sim (D=0)` y `A_core`: **7 604,50 = 7 604,50** (`ρ=2`), **7 746,33 = 7 746,33** (`ρ=3`), **7 935,44 = 7 935,44** (`ρ=9`), **8 021,49 = 8 021,49** (`ρ=100`). Diferencia **0,00**. `A_core` **no subestima: es el máximo exacto** bajo el adversario que espera la decisión. La brecha de 422,5 slots que ADL veía era la distancia de su propio modelo a la envolvente |
| A3 | «`A_con_h(ρ) = máx(0, (I + W_dec − 1) − (L + I)/ρ)` ⇒ **`A = 0` exactamente para todo `ρ ≤ ρ*`**» (`INFORME.md:299-301`, `modelo.jl:292-301`) | **REFUTADA** (objeto equivocado) | `F2.txt`: con (h) y `Lrev = L`, `V_max = (L+I)(1−1/ρ)` **exactos**: 4 025,5 a `ρ=2`, **4 830,6 a `ρ=2,5`**, 5 367,3 a `ρ=3`. `A_con_h` vale **0,0** en esas mismas tres filas. La expresión de ADL es la **holgura de la carrera de *steering*** `ρ(I+W_dec) − (Lrev+I)`, cuyo cero es `ρ*`; no es la ventana de PoT |
| A4 | «**con (h) y `ρ_max ≤ ρ*` es `sup A = 0`**, de modo que la edad `M` … **colapsa al margen** y el sellado secuencial **deja de ser necesario**» (`INFORME.md:340-343`, `373`) | **REFUTADA** | `F4.txt`: con (h), q99 ∈ [688; 6 352] slots, **nunca 0**. Factores de reducción medidos: 2,07× (`F=1019, ρ_max=1,2`), 1,54× (7 200; 2,5), 1,42× (7 200; 3,0), 4,58× (7 200; 1,2). Y el **sellado secuencial sigue siendo necesario** para las candidatas B/A1 del sembrador porque la ventana no se anula |
| A5 | «**`M > máx(0, (I + W_dec − 1) − (L + I)/ρ_max − D) + margen`**» y las cotas de su tabla §4.2/§4.3 | **CORREGIDA**: la cota debe ser un **cuantil con su tasa de excedencia**, no un `sup`, y la de ADL es insuficiente | `F4.txt`: `F=7 200, ρ_max=2,5` → `q99 = 8 800` **> 8 027**, la cota de ADL sin (h). Las **rachas de ancla propia** hacen que `V` supere el tope de régimen, luego ningún `sup` finito lo cubre |
| A6 | «El **acantilado de `ρ = 1`** es del modelo histórico, no del fenómeno. `A_frontera` es **continuo**» (`INFORME.md:62-65`) | **CONFIRMADA** | `test/runtests.jl` §2 y `F1.txt`: `V_max = V_min = 0` en `ρ = 1` y crecimiento continuo; el salto de `A_core` (0 → 7 179,85 entre `ρ=1` y `1,001`) es de su fórmula, no de la regla |
| A7 | «**`D` resta** en el estacionario (`A = Γ−D−t`)» y «**se cancela** en el transitorio» (`INFORME.md:94-95`) | **CONFIRMADA** en las dos mitades, con el matiz de la fila | `F2.txt`: `V_max(D) − V_max(0) = 4,000` exactos en las diez filas de `ρ` (`D = 4`). `ADL.txt` a `ρ = 1,001`: `V_max(D) = V_max(D=0) = 1 197,40`, es decir **se cancela en el transitorio**, como ADL dijo |
| A8 | «**No suma.** Sumaría si `reto(f,s)` se derivara de `pot_output`… lo prohíben `C-POT-03` y `R-FIN-14(e)`» (`INFORME.md:103-107`) | **CONFIRMADA** (verificado en fuente) | `SPEC.md:1376-1390` y `research/dag-poas-ancla-de-orden.md:272-275`, leídos; el instrumento no tiene ninguna vía de `+D` |
| A9 | «`I ≥ ρ_max·W_dec` **sobrevive tal cual**» (`INFORME.md:137`) | **CONFIRMADA** | Es `R-FIN-14(f)` (`research/dag-poas-ancla-de-orden.md:277-279`), verificado en fuente; `referencia.jl:I_minima` |
| A10 | «`A_core` … **sobreestima el acantilado de `ρ = 1`**» (`INFORME.md:1`) | **CONFIRMADA** | Igual que A6 |
| A11 | «**la realimentación `F ↔ L ↔ ρ*` es real**: `ρ*(F) = (F+I)/(I+W_dec)` cuando `L = F_slots`» (`INFORME.md:247-248`) | **CONFIRMADA en forma cerrada; CORREGIDA en magnitud** | `F3.txt`: con `I` **recalibrado** por (h.6), `ρ*` apenas depende de `F` (1,479 / 1,479 / 1,490 con `ρ_max=1,5`; 2,436 / 2,437 / 2,469 con `ρ_max=2,5`) y la dependencia se traslada a **`I`**: `I*` = 1 978 / 7 034 / 14 340. La tabla de ADL que daba `ρ* = 2,147` **mantenía `I = 851` fijo** mientras bajaba `F`; recalibrando, esa fila da `ρ* = 2,275` con `I* = 646` |
| A12 | «`F = F_carrera` y `L_suelo = 0` ⇒ **o `ρ_max ≤ 2,147` con `A = 0`, o `ρ_max > 2,147` con `A > 0`. No las dos**» (`INFORME.md:281-283`) | **CORREGIDA** | La disyuntiva se mantiene para el **steering** (`ρ*`), pero el primer término es falso: `A > 0` **siempre** con (h) (`F2.txt`). Lo que (h) compra no es `A = 0`, es `A ≪ L` (factor 1,2-4,6 en q99) |
| A13 | «`ρ*_cont = coste_rel · I/(I + W_dec)` … **protección y coste son el mismo número**» (`INFORME.md:187-192`) | **CONFIRMADA** | `F5.txt` y `F3.txt`: `q+1` y `nucleos_nodo = 0,0961·(1+L/I)` siguen la misma palanca `L/I` que `ρ*`; recalibrar `I` por (h.6) abarata las dos a la vez (0,909 → 0,241 núcleos; 10 → 3 líneas) |
| A14 | «El **compromiso** se corre con el conocimiento, pero la **grieta** entre ambos es `s(1−1/ρ)`, **sin `D`**» (`INFORME.md:138`) | **NO DETERMINADO aquí** | Requiere modelar el compromiso de parcela, que este instrumento no toca. `V` mide conocimiento de frontera, no compromiso |
| A15 | «`A_core` … coincide con una transcripción literal del núcleo de SEM-v1 … `maxdiff = 0.0`» (`INFORME.md:140-143`) | **NO DISPUTADA** (es su regresión interna) | Se conserva como está; el encargo §9 advierte que esa regresión compara dos transcripciones. **No se usa como evidencia aquí** |

## 2 · Lo que **no** cae, y conviene decirlo igual

- **La separación de objetos que ADL hace (§2.1-2.2) es correcta**: `n_eval = ρ·W_dec` es otra
  magnitud que la ventana, y `I ≥ ρ_max·W_dec` mide `n_eval`. Eso sobrevive.
- **La regla de que `D` no suma** (A8) es correcta y está verificada en fuente.
- **El aviso sobre `C-FLU-22`** (`INFORME.md:208-228`: (h) encarece la adopción del flujo rival y
  añade una partida a `PRESUP_NODO` que nadie ha derivado) **no se toca** y sigue en pie: este
  informe mide el coste por nodo, no el presupuesto de adopción.
- **La parte de `F1` que el encargo pedía confirmar o refutar**: «sin (h) la ventana es ≈`L` para
  cualquier `ρ > 1` tras el *bootstrap*, de modo que acotar `ρ_max` solo no la reduce» →
  **CONFIRMADA** (`F1.txt`: `V_max` ∈ [`A_core − D`, `A_core − D + I`], es decir ∈ [7 175; 8 030]
  con `L = 7 200` para **todo** `ρ ∈ [1,01; 9]`). Lo que **no** sobrevive es que su tope sea el
  valor (`8027`); es la envolvente.
- **El *bootstrap* de días** (`INFORME.md:488-490`) → **CONFIRMADO y medido** (`F1.txt`: 180 h a
  `ρ=1,01`, 36 h a 1,05, 0,90 h a 3,0).

## 3 · La única discrepancia de copia, y por qué no es un error de nadie

El control C1 publica `bootstrap = 477,06 h` a `ρ = 1,01` (razón 1,000 con `0,9L/(ρ−1)`). Aquí sale
**477,69 h (razón 1,001)** con el cruce de barrera físico y **466,03 h (0,977)** con la convención
de `r10a_lib.py`. La causa está localizada y es de **modelo**: `r10a_lib.py:167` corre hasta la
barrera en `t_j/ρ`, mientras que la física para en `t_j − 1`, espera la entropía y computa `t_j`
después; con `ρ = 1,01` la diferencia acumulada es `j/ρ` slots en la época `j`. El **tope** coincide
en las dos convenciones con razón 1,000000, así que ninguna cifra de nivel se ve afectada. El
instrumento expone las dos (`Config.cruce`) y las publica.

## 4 · Veredicto sobre la lectura del validador (encargo §0)

**CONFIRMADA en lo esencial**, con dos precisiones:

1. **Precisión 1 — falta `−D`.** La fórmula del validador
   `A_core = (L − 1 − W_dec) + I(1 − 1/ρ)` **no lleva `D`**. Con `D-2 = A`, la frontera honesta va `D`
   por delante (`C-POT-05`) y **`D` resta exactamente `D`** (`F2.txt`). El `A_core` histórico no lleva
   `D` porque es anterior a `D-2 = A`, y el propio `P-SEMBRADOR` lo declara pendiente
   (`INFORME.md:90`). La forma exacta es `A_core − D`.
2. **Precisión 2 — la puntualidad incluye `D`.** Con la frontera honesta `D` adelantada, la
   condición del honesto es **`Lrev ≤ L − W_dec − D`** (continua) y `Lrev ≤ L − W_dec − D + off − 1`
   (discreta), **no** `Lrev ≤ L − W_dec`. La recomendación (h.1b) `Lrev = L − S_max` la cumple
   mientras `S_max ≥ W_dec + D + 1`. Sin esa holgura, el honesto se estanca y `V` crece por un
   motivo que no es del atacante; el simulador lo marca (`n_stall_h`) en vez de esconderlo.

Fuera de esas dos precisiones, **el validador describió correctamente el mecanismo**: la cadena de
PoT es secuencial a través de las barreras, `A_core` es exacta, el valor de ADL es la envolvente
`ρ → ∞`, con (h) la ventana es `(L+I)(1 − 1/ρ) > 0` y `ρ*` es *steering*, no ventana.
