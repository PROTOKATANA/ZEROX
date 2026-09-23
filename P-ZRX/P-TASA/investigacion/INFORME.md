# INFORME — P-TASA · La tasa fija por identidad: ¿cierra algo, o sólo mueve el problema?

**La respuesta a F2, en la primera línea:** la tasa fija por identidad **no toca el doble farmeo** —el
doble farmeo es **una sola** identidad produciendo en dos ramas, y por tanto **no paga tasa alguna**—;
sólo **habilita** una regla de exclusividad, y como esa regla sólo se hace cumplir con **evidencia**,
la tasa **hereda la dependencia de `κ`** que el encargo le atribuía evitada: sin castigo (`κ·q = 0`) la
fracción de espacio disuadida es **exactamente 0 para todo `τ`** (`demostrado` en el instrumento). La
segunda objeción —«el remedio es peor que la enfermedad» por `β_d → β_x`— está **mal calibrada a igual
`β`**: ahí `β_x` sí es peor y con `β = 0,2` el umbral baja de `0,40` a `0,30` (`demostrado`), pero a
**igual coste** el remedio es mejor, porque la enfermedad es **gratis** (`P-PRESTAMO` F3) y el remedio
tiene un precio. **Hay, sin embargo, un sentido en que el remedio es peor y el encargo no lo apunta:**
`τ_min = f*·(λ·I·P_win·T_h − c_b)` es **proporcional al tamaño de la granja marginal**, así que la tasa
que protege el umbral cuesta **más del 100 % del ingreso** de toda granja menor que la marginal y
**exime exactamente a la grande** — el adversario del modelo de amenaza. Y el modo de fallo es
estructural, no un defecto de calibración: **«partir cuesta» y «ser regresiva» son la *misma*
condición** (`demostrado`), de modo que la única cuota que no es regresiva es la proporcional al
espacio, es decir **la variante (a) que `AGENTS.md` prohíbe**. **Veredicto: la vía (11) no merece
existir como defensa del umbral.**

**Categoría:** `economía` (dominante); `seguridad` y `consenso` (secundarias). El tema dominante es el
coste y el reparto de un precio (a quién disuade y a quién cobra), y por eso
`veritas/economia/tasa-identidad-v1/`.

**Instrumento:** `P-ZRX/P-TASA/investigacion/veritas/economia/tasa-identidad-v1/` — Julia 1.13.0, CPU,
`veritas/julia.sh`, **sin Python**. Aritmética exacta (`Rational{BigInt}`) en toda la frontera de
umbral y en la dicotomía; `Float64` sólo en las rejillas, con certificado de intervalo para la
distribución continua. **Semilla:** `0x54415341` («TASA»). **Fecha:** 2026-09-23.

**Presupuesto declarado antes de ejecutar:** **4 hilos**, 4 GiB de RAM, 256 MiB de artefactos en disco
(el depósito de precompilación de Julia se declara aparte y es caché regenerable), minutos por tarea,
techo de 2 h de pared. **No se agotó.** `uptime` antes y después en `PROGRESO.md`; carga media al
empezar `1,83`.

**Advertencia que gobierna todo el informe.** `α`, `β_d`, `β_x` y `f` son **fracciones de ESPACIO**,
como en `P-ZRX/P-PRESTAMO/`. El **puente espacio → tasa no existe** en ningún instrumento del
repositorio (`P-ZRX/P-CRP/auditoria/DEFECTOS.md` C1). Ninguna cifra de este informe es una decisión de
consenso: `τ`, `N`, `T_rot`, el tope por identidad, `λ`, `I`, `P_win`, `T_h`, `c_b`, `κq`, `L_p`,
`ρ_ret`, `T_v`, `c_r`, `M` y la distribución de tamaños **entran por CLI y salen como columna**
(`HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md` H10).

**Objeción al encargo, declarada antes de ejecutar y confirmada después.** El encargo presenta la
independencia de `κ` de la variante (c) como su propiedad interesante. Es cierta **como recibo** y
**vacía como defensa**: la tasa no depende de `κ`, pero **todo lo que la tasa puede hacer depende de
`κ`**. El instrumento lo demuestra con una igualdad, no con un argumento (§2.2). Está en `PROGRESO.md`
§0 y en `DECISIONES-PENDIENTES.md`.

---

## 0 · Respuestas cortas a las seis preguntas

| # | Pregunta | Respuesta | Etiqueta |
|---|---|---|---|
| **F1** | Las tres variantes formalizadas; cuál no depende de `κ` | **(a)** stake ∝ espacio (`σ·f`): no depende de `κ` pero es **proporcional al espacio** y no satisface el teorema; **es PoS, descartada**. **(b)** depósito fijo confiscable (`D·κ·q`): **sí depende de `κ`**. **(c)** tasa fija no recuperable (`τ`): **no depende de `κ`** y **sí** satisface el criterio «coste por byte no constante» del teorema. **Pero la única variante que no depende de `κ` es también la única que no puede hacer nada por sí sola** (`f_det = 0` si `κq = 0`) | `demostrado` + `verificado en fuente` |
| **F2** | ¿Toca la tasa el doble farmeo, o sólo habilita exclusividad? ¿El remedio es peor? | **No lo toca**: cofarmar usa **una** identidad. **Sólo habilita** exclusividad, y con `τ` a secas la partición sigue siendo gratis para el atacante. **A igual `β` el remedio es peor** (`α*`: `0,40 → 0,30` con `β = 0,2`); **a igual coste es mejor** (la enfermedad es gratis); **pero el remedio es peor en el margen que importa**: `τ_min ∝ f*`, luego **castiga a la granja pequeña y exime a la grande** | `demostrado` |
| **F3** | Contra qué evasiones actúa, con el `τ` mínimo; ¿revive alguna defensa? | Actúa contra **una**: la partición de identidades para evadir una regla de exclusividad, y **sólo si `κq > 0`**. `τ_min = f*·(λIPTh − c_b)` con `f* = Φ⁻¹(1−2α)`; con `α = 1/3` y H3 (`Pareto(2,2)`), `τ_min = 2,50·10⁻⁸`. La **rotación** sigue siendo barata para el grande (la tasa es fija, el ploteo proporcional). **No revive durablemente ninguna defensa descartada por la gratuidad de las identidades**: la única que revive (exclusividad por identidad) depende de `κ`, es regresiva y vale el doble en contra | `derivado` + `hipótesis H1` |
| **F4** | La regresividad, y si existe un diseño donde partir cueste y acumular no | **Sí existe, y es exactamente el mismo que es regresivo**: `N·φ(f/N) > φ(f) ⟺ φ(f)/f` decreciente. La regresividad **no es un efecto secundario**: es la condición de «partir cuesta». La cuota no regresiva es la proporcional (`:A`). El **tope por identidad** convierte la tasa en `τ·⌈f/S_max⌉ ≈ (τ/S_max)·f`, es decir en **(a) disfrazada**, y además **rompe** la propiedad de partición en los saltos | `demostrado` |
| **F5** | Unidad, recurrencia y arranque, incluida la variante pagada en cómputo | En **moneda**: exige moneda previa, incompatible con `C-EMIT-02` (sin premine) salvo esperar emisión o endeudarse (lo que la convierte en (b), dependiente de `κ`). En **cómputo**: cumple la letra del teorema y **evita el arranque**, pero reintroduce **minería PoW** (retirada según `MIGRACION.md`) y es **ASIC-able**: bajo el modelo de amenaza de Katana es la unidad **más favorable al atacante**. **Una sola vez** se amortiza (disuasión ∝ `1/T_plot`); **recurrente** es impuesto permanente al honesto | `derivado` |
| **F6** | ¿Dentro o fuera de la línea roja? | **(a) dentro** (es staking). **(b) y (c) fuera de la letra** —no escalan con el disco y (c) no es confiscable—, pero **ninguna cierra el umbral**: (b) depende de `κ`, (c) es regresiva e inerte sin exclusividad. **La vía (11) no merece existir como defensa.** La lectura de la línea roja la decide Katana; el coste de cada rama está en la tabla de §6 | `derivado` + `propuesto` |

---

## 1 · El modelo, los símbolos y las tres variantes (F1)

### 1.1 Reparto y deriva

El reparto es el del **texto** de `P-ZRX/P-PRESTAMO/investigacion/INFORME.md` §1, que es el del
encargo: espacio total = 1; `α` = espacio propio del atacante (retirado de la pública); `β_d` = espacio
honesto que farmea **doble** (sigue publicando y además alimenta la privada); `β_x` = espacio alquilado
en exclusiva que **abandona** la pública. Entonces

```text
g = η_a·(α + β_d + β_x) − η_h·((1 − α) − β_x)
α* = (η_h − η_a·β_d − (η_h + η_a)·β_x) / (η_h + η_a)      [η = 1: (1 − β_d − 2β_x)/2]
```

`β_d` no aparece en la pública porque el doble granjero **sigue publicando**; `β_x` quita 1 a la pública
**y** suma 1 a la privada. **Esa es toda la asimetría**, y es la razón de que la segunda objeción del
encargo tenga contenido. El instrumento comprueba con `Rational{BigInt}` que `g(α*) = 0` **exacto** y
que el signo es estricto a los dos lados de `α*`, en 180 combinaciones de `(β_d, β_x, η_h, η_a)`
(`test/runtests.jl`, testset «umbral exacto»). Casos que el encargo pide comprobar:
`α*(0,0) = 1/2`; `α*(β_d,0) = (1−β_d)/2` con frontera `β_d > 1−2α`; `α*(0,β_x) = 1/2 − β_x`;
`β_x` vale **el doble** que `β_d` en la deriva.

> **Nota de reconciliación, y es necesaria.** `P-ZRX/P-CLAVE/investigacion/INFORME.md` §1 y
> `PROGRESO.md` O7 documentan una inconsistencia de `P-PRESTAMO`: su texto define `g` con `β_d`
> **sin** abandonar la pública (frontera `β_d > 1 − 2α`, la del `PROMPT.md` §2.2) mientras su tabla de
> §2.3 publica `(1−2α)/(1−α)`, que **no** anula esa `g`. Este informe usa **el reparto del texto** y
> publica `1 − 2α` como frontera, igual que `P-CLAVE`. **No se modificó ningún fichero de
> `P-ZRX/P-PRESTAMO/`.**

### 1.2 Las tres variantes, separadas como pide §2.1

| id | variante | coste por identidad | coste por byte (`s_id` = bytes que representa) | ¿depende de `κ`? | ¿satisface «no proporcional al espacio»? |
|---|---|---|---|---|---|
| **:A** | stake proporcional al espacio | `σ·f` | `σ` (constante) | no | **no** (y es PoS) |
| **:B** | depósito fijo **confiscable** | `D·κ·q` | `D·κ·q / s_id → ∞` | **sí** | sí |
| **:C** | tasa fija **no recuperable** | `τ` | `τ / s_id → ∞` | **no** | sí |

El teorema de exclusividad (`research/dag-poas-balizas-auditoria.md:30-39,66-78`) exige que crear una
identidad cueste **algo que no sea proporcional al espacio que representa**: es decir, coste por byte
que **no** tienda a una constante cuando la identidad se hace pequeña. `:A` no lo cumple; `:B` y `:C`
sí. La respuesta a **F1** es, por tanto: **(c) es la única que no depende de `κ` *y* satisface el
criterio del teorema**; `:A` tampoco depende de `κ` pero falla el criterio y es la variante prohibida.
Artefacto: `resultados/F1-variantes.tsv`.

**Lo que el encargo no separa y este informe sí.** «No depender de `κ`» es una propiedad **del
recibo**. Que la variante sea **útil** es otra cosa, y se decide en §2.2: su único uso posible es
habilitar exclusividad, y la exclusividad necesita evidencia. De ahí que (c) acabe **igual de atada a
`κ`** que (b), sólo que por otra puerta.

---

## 2 · F2 · La objeción que decide

### 2.1 La tasa no toca el doble farmeo: es habilitante, no defensa

**Afirmación (`demostrado`, aritmética del modelo).** El doble farmeo es **una** identidad publicando
el mismo ploteo en dos ramas. `derive_sector_slot_challenge` toma el reto global como parámetro
externo y el `SectorId` depende de la clave, no del reloj (`P-ZRX/P-CLAVE` §4, citando
`subspace-core-primitives/src/sectors.rs`). Por tanto, en la contabilidad de costes:

```text
coste de identidad de la estrategia β_d  =  0 · τ        (no crea ninguna identidad)
coste de identidad de la estrategia β_x  =  0 · τ        (usa la que ya tiene, en una sola rama)
coste de identidad de la evasión (partir) =  n_extra · τ  (una identidad por rama)
```

**La tasa cobra por *crear*, no por *reusar*.** Aplicada al doble farmeo, su efecto directo es
**cero**.

**Entonces, ¿qué hace?** Habilita una regla «una identidad, una rama». Sin tasa, esa regla se evade
partiendo el espacio: el atacante pone una identidad por rama y no paga nada, porque las identidades
son gratis (`P-CLAVE` F4, `verificado en fuente`; teorema de exclusividad). Con tasa, partir cuesta
`n_extra·τ`. **Pero la regla necesita además que la infracción se pruebe.** El granjero compara las dos
evasiones y elige la más barata:

```text
f_detenida = min( κ·q·L_p , n_extra·τ + c_b·f ) / (λ·I·P_win·T_h)
             └── una identidad, dos ramas    └── partir en identidades extra
```

y de aquí el **resultado que refuta el encuadre de F1**:

```text
κ·q = 0   ⟹   f_detenida = 0   para todo τ      [demostrado, exacto]
τ = 0 y c_b = 0  ⟹   f_detenida = 0   para todo κq
```

**Hacen falta las dos cosas a la vez**, y la tasa no sustituye a ninguna. Ésa es la respuesta a F2 en
su primera mitad: **la tasa no es una defensa, es un habilitante; y el habilitante no funciona sin el
mecanismo cuya ausencia motivó el encargo.** El instrumento lo comprueba con 5 valores de `τ` y
`κq = 0` (todos dan `f_det = 0` exacto) y con la equivalencia completa
`Φ(f_det) ≤ 1−2α ⟺ κq ≥ κ_min ∧ τ ≥ τ_min` en 48 celdas (`test/runtests.jl`).

### 2.2 La segunda objeción: las dos comparaciones, y la que el encargo no hace

**A igual `β` — el remedio es peor (`demostrado`).** `resultados/F2a-igual-espacio.tsv`:

| `β` | `α*` con `β_d = β` | `α*` con `β_x = β` | diferencia |
|---:|---:|---:|---:|
| `1/20` | `19/40` (0,475) | `9/20` (0,450) | `−1/40` |
| `1/5` | `2/5` (0,400) | `3/10` (0,300) | `−1/10` |
| `2/5` | `3/10` (0,300) | `1/10` (0,100) | `−1/5` |
| `1/2` | `1/4` (0,250) | `0` | `−1/4` |

Con `β = 0,2` el umbral pasa de `0,40` a `0,30`, exactamente como el encargo sospechaba. **Pero esa
comparación es infactible**: `β_d` no está acotado a `0,2`. Sin la regla, `β_d` sube hasta `1 − α` **a
coste cero** (`P-PRESTAMO` F3: `b* = 0`, farmear doble es estrictamente dominante), y entonces
`g = 2α + (1−α) − 1 = α > 0` para **todo** `α > 0`: **el umbral se pierde por completo.** Comparar a
igual `β` es comparar un punto que la enfermedad nunca respeta.

**A igual coste — el remedio es mejor, y ésa es la comparación correcta** (`AGENTS.md`: «comparar
alternativas bajo el mismo riesgo y escenario»). En `resultados/F2d-coste-vias.tsv`, con la familia
declarada de dispersión extrema (`DosNiveles(0,34; 0,34; 10⁶)`) y `τ = 10⁻²`:

| vía | espacio capturado | coste | `α*` resultante |
|---|---:|---:|---:|
| `β_d` (cofarmeando) | 0,34 | **0** | 0,33 |
| `β_x` (alquiler exclusivo) | 0,34 | 0,34 | 0,16 |

A coste 0 el atacante consigue `β_d = 0,34`; a coste 0 el remedio no le da nada. **La enfermedad es
gratis y el remedio tiene precio, y el precio lo crea la regla de exclusividad** (el granjero que
abandona la pública exige compensación por el ingreso renunciado, `c_x = λ·I` por unidad de espacio y
tiempo), no la tasa. Ése es el único valor real que la vía tiene, y es **delegado**: quien cobra es la
economía de castigo, que `P-CLAVE` F6 ya midió como **inexistente** frente a `κ = 0`, censura total,
claves nuevas y `V` sin cota.

**Y hay un tercer sentido, que es el que decide y el encargo no apunta.** La tasa no es un impuesto
plano sobre el ataque: **es un filtro por tamaño**. `τ_min ∝ f*` (§2.3), así que la tasa que hace
falta para que partir deje de compensar a la granja grande **arruina** a la pequeña. En la familia de
dispersión extrema, con `f* = 0,34`, la granja pequeña (`f = 6,6·10⁻⁷`) paga `f*/f ≈ 5,15·10⁵` veces
su ingreso, mientras la industrial paga `1`. **El remedio no es peor que la enfermedad: es peor que
nada, porque selecciona exactamente al adversario que el modelo de amenaza de Katana describe.**

### 2.3 `τ_min` es proporcional al tamaño de la granja marginal

Ésta es la pieza que el encargo pide explícitamente («el `τ` mínimo … en función de lo que el atacante
gana partiendo — que no es una constante y hay que modelarlo»).

**La ganancia de partir es lineal en el espacio.** Cofarmar rinde `G(f) = f·λ·I·P_win·T_h`: la
recompensa por espacio es lineal —la premisa del propio teorema—. Por tanto, para disuadir a una
granja de tamaño `f` hace falta `n_extra·τ ≥ f·(λIPTh − c_b)`, es decir

```text
τ_min(f) = f · (λ·I·P_win·T_h − c_b) / n_extra
```

**`f` no es libre: lo fija el atacante, que recluta primero a las grandes.** El espacio está
disponible para `β_d` en las granjas no disuadidas, `Φ(f_det)`; para que el atacante no cruce la
deriva hay que impedirle juntar `1 − 2α`, luego hace falta `Φ(f_det) < 1 − 2α`, esto es
`f_det > f* := Φ⁻¹(1 − 2α)`. De ahí:

```text
τ_min = f* · (λ·I·P_win·T_h − c_b) / n_extra          [demostrado dentro del modelo]
κq_min = f* · λ·I·P_win·T_h / L_p                     [la condición que la tasa NO sustituye]
Φ(f_det) ≤ 1−2α  ⟺  κq ≥ κq_min  y  τ ≥ τ_min         [equivalencia exacta, 48 celdas]
```

`f*` es el **tamaño de la granja marginal**: la que suministra el top `1 − 2α` del espacio. Es un
número de la **distribución**, no del protocolo. Y la consecuencia —el hallazgo **R2**— es que **la
tasa que protege el umbral crece con el tamaño del mayor granjero que el atacante pueda reclutar**:
existe siempre un tamaño por encima del cual la tasa se absorbe. **Un coste fijo no puede dominar un
beneficio lineal.** La condición del teorema («coste no proporcional al espacio») es **necesaria y no
suficiente**, y el encargo la da por suficiente.

`resultados/F2c-tau-minimo.tsv` (35 filas: 4 Pareto × 5 valores de `α` + 3 discretas × 5):

| distribución | `α` | `f*` | `τ_min` (`n = 1`) | `κq_min` | carga de la marginal | carga de una 10³× menor |
|---|---:|---:|---:|---:|---:|---:|
| `Pareto(2,2)` (H3 `P-CLAVE`) | `1/3` | `2,498·10⁻⁸` | `2,498·10⁻⁸` | `1,365·10⁻¹¹` | `1,0` | `1000` |
| `Pareto(2,05)` | `1/3` | `2,847·10⁻⁸` | `2,847·10⁻⁸` | `1,556·10⁻¹¹` | `1,0` | `1000` |
| `Iguales(10⁶)` | `1/3` | `1,0·10⁻⁶` | `1,0·10⁻⁶` | `5,46·10⁻¹⁰` | `1,0` | `1000` |
| `DosNiveles(0,34; 0,34; 10⁶)` | `1/3` | `0,34` | `0,34` | `1,858·10⁻⁴` | `1,0` | `1000` |

(Los símbolos usados: `λ = 1`, `I = 1`, `P_win = 1`, `T_h = 1`, `c_b = 0`, `ρ_ret = 0,5`, `T_v = 3600`,
`c_r = 10`, `M = 20` ⇒ `L_p = 1830`. Son **entradas**, no recomendaciones.)

Léase la tabla con cuidado, porque **la cifra depende de la hipótesis H1 y el teorema no**:
- Con la distribución de `P-CLAVE` (`Pareto(2,2)`) `τ_min = 2,5·10⁻⁸`, un valor minúsculo; **la
  regresividad existe (la mediana paga `1,8×` su ingreso y la mínima `2,5×`) pero es numéricamente
  suave.**
- Con una cola baja más gruesa o dispersión extrema, `τ_min` salta al orden del **ingreso de la granja
  industrial** (`0,34`) y la granja pequeña paga `~5·10⁵` veces su ingreso. **El signo es el mismo; la
  magnitud la fija la distribución.**
- La columna `brecha_Φ_menos_p` del artefacto expone que en las distribuciones **discretas** el umbral
  `Φ(f*) = p` no se alcanza por igualdad: el `τ_min` tabulado es un **ínfimo no alcanzado** y hay que
  superarlo estrictamente. Declarado, no escondido.

---

## 3 · F3 · Evasiones y defensas

### 3.1 Partición de identidades

Es la única evasión contra la que la tasa actúa, y **sólo con `κq > 0`** (§2.1). `resultados/F3a-particion.tsv`
(504 filas): con `κq = 0` **ninguna** de las 168 filas correspondientes es «segura» para ningún `τ`
(incluido `τ = 0,5`); con `κq > 0` y `τ > 0` lo son 193 de 504. Ejemplos representativos de
`Pareto(2,2)` con `α = 1/3` (umbral a cubrir `0,333`):

| `κq` | `τ` | `f_detenida` | espacio no disuadido | ¿seguro? |
|---:|---:|---:|---:|:--:|
| `0` | `0,5` | `0` | `1` | **no** |
| `10⁻⁴` | `0,5` | `0,183` | `1,68·10⁻⁹` | sí |
| `10⁻²` | `0,5` | `0,5` | `3,26·10⁻¹⁰` | sí |
| `10⁻⁴` | `0` | `0` | `1` | **no** |
| `10⁻⁴` | `10⁻⁶` | `10⁻⁶` | `7,94·10⁻³` | sí |

**La tasa sola no compra nada**: la fila `κq = 0`, `τ = 0,5` es un «no» con una tasa 500 000 veces
mayor que la que basta cuando `κq = 10⁻⁴`.

### 3.2 Rotación de claves

`P-CLAVE` §F4 midió que mantener `β` con rotaciones cada `T_rot` exige `1 + T_v/T_rot` veces el ploteo
(**×11** con `T_v = 3600`, `T_rot = 360`) y concluyó que **la rotación sale barata porque es precio de
bytes, no de saldo**. Con la tasa dentro (`resultados/F3b-rotacion.tsv`): el coste de bytes **no
cambia** (sigue siendo `β·(1+T_v/T_rot)`, ×11) y la tasa añade `τ` **por rotación**, un coste **fijo e
independiente de `β`**. Por tanto:

- el cociente `coste_tasa/coste_bytes` **cae como `1/β`**: para el grande, la tasa sigue siendo
  despreciable;
- **la conclusión de `P-CLAVE` no cambia**: la rotación sigue siendo la vía barata para el atacante
  grande, y ahora además la tasa es un impuesto que paga igual el honesto que rota una clave por
  mantenimiento.

### 3.3 ¿Revive alguna defensa hoy descartada sólo por la gratuidad de las identidades?

Ésta es la pregunta que el encargo marca como «el resultado más valioso que puede dar». La respuesta
es **no**, con un matiz que hay que nombrar (`resultados/F3c-revive.tsv`):

| defensa | por qué se descartó | ¿la tasa la revive? | coste de la revivencia |
|---|---|:--:|---|
| **D1** exclusividad de reloj por identidad | teorema de partición: identidades gratis | **sí, condicionalmente** | **necesita `κq > 0` además de `τ > 0`; es regresiva; y `β_x` vale el doble** |
| **D2** cuota/tope de espacio por identidad | no había coste de identidad | sí, trivialmente | `τ·⌈f/S_max⌉ ≈ (τ/S_max)·f`: **es (a) disfrazada** |
| **D3** detección estadística / cuota por identidad | Sybil gratis | **no** | el coste fijo por identidad lo absorbe la granja grande |
| **D4** atribución de pool | `P-POOLS`: el operador hostil firma por el granjero | **no** | la tasa no toca la firma |
| **D5** castigo por clave | `P-CLAVE` F4/F6: claves pobres y nuevas, soborno 0 | **no** | encarecer identidades **no crea la evidencia** que falta |

**La única defensa que revive es la que el propio teorema nombraba, y revive en la peor de sus
formas**: condicionada a `κ`, regresiva y con la eficacia del espacio capturado duplicada. **No hay
ninguna defensa que hoy esté descartada *sólo* por la gratuidad de las identidades y que la tasa
devuelva entera.** Ése es el resultado, y es un «no» argumentado.

---

## 4 · F4 · Regresividad, y la dicotomía que la hace inevitable

### 4.1 El teorema de la dicotomía (`demostrado`)

Sea `φ(f)` la cuota que paga una identidad que representa la fracción de espacio `f`, con `φ ≥ 0` y
`φ(0) = 0`. Entonces:

```text
(a)  N · φ(f/N) > φ(f)  para todo N ≥ 2      ⟺  φ estrictamente subaditiva
(b)  φ(f)/f es estrictamente decreciente     ⟺  φ estrictamente subaditiva
(c)  φ(f)/f es estrictamente decreciente     ⟺  la carga φ(f)/(λ·I·f·T_h) es decreciente
```

**(a) es «partir cuesta»; (b) es «es regresiva». Son la misma condición.** No hay ninguna tensión de
diseño que resolver: **son la misma función vista dos veces**, y la única familia que no la cumple es
la lineal — `φ(f) = σ·f`, **la variante (a)** — que es neutral bajo partición y por tanto **no impide
la evasión** que la tasa existía para impedir.

Comprobado con aritmética exacta en una rejilla de 7 tamaños × 4 particiones × 4 horarios
(`resultados/F4b-dicotomia.tsv`, 32 filas; `test/runtests.jl`, testset de dicotomía): para `Lineal`,
`parte_mas_caro = no` y `carga_decrece = no`; para `Fija` y `FijaLineal`, **ambas `si` siempre**. La
equivalencia se comprueba con expresiones **distintas** (`N·φ(f/N)` frente a `φ(f)/f` y frente a
`φ(a+b) < φ(a)+φ(b)`), no comparando una fórmula consigo misma.

### 4.2 La cuantificación, y por qué la distribución es una hipótesis

La carga de la tasa mínima sobre una granja de tamaño `f` es exactamente

```text
carga(f) = τ_min / (f·λ·I·T_h) = (f*/f) · (1 − c_b/(λ·I·P_win·T_h))
```

**inversamente proporcional al tamaño, y con `f*` fijado por la distribución.** `resultados/F4a-regresividad.tsv`
(49 filas) publica la curva para cada familia. Con `Pareto(2,2)` y `α = 1/3`, `τ_min = 2,498·10⁻⁸`:

| granja | `f` | carga (múltiplo de su ingreso en `T_h`) |
|---|---:|---:|
| marginal | `2,498·10⁻⁸` | `1,0` |
| 10× menor | `2,498·10⁻⁹` | `10` |
| 10³× menor | `2,498·10⁻¹¹` | `1000` |
| 10⁶× menor | `2,498·10⁻¹⁴` | `10⁶` |

**Toda granja por debajo de la marginal paga más del 100 % de su ingreso**, y el exceso crece sin cota
al reducir el tamaño. Con `Pareto(2,2)` el menor tamaño declarado es `10⁻⁸`, así que la carga máxima
es `f*/f_min = 2,5`; **con dispersión extrema la misma fórmula da `5,15·10⁵`**. El teorema no depende
de la distribución; **la magnitud sí, y por eso H1 es una hipótesis declarada y no un dato.**

### 4.3 ¿Existe un diseño donde partir cueste y acumular no?

**Sí, y es exactamente el conjunto de los regresivos.** Por 4.1, cualquier horario que haga costosa la
partición **es** regresivo, y recíprocamente. La pregunta del encargo §2.3 tiene por tanto una
respuesta cerrada: **no es una disyuntiva de diseño, es una identidad matemática.** Los dos candidatos
que el encargo nombra:

- **tope de espacio por identidad.** `φ(f) = τ·⌈f/S_max⌉`. `resultados/F4c-tope.tsv` (24 filas): la
  tasa efectiva por byte tiende a `τ/S_max`, **constante** —es decir, el tope convierte la tasa en un
  coste **proporcional al espacio**, la variante (a) con un escalón—. Y algo peor: **la escalera no es
  continua, y por eso rompe la propia propiedad que se buscaba.** En `F4b-dicotomia.tsv` hay filas del
  `Tope` donde `parte_mas_caro = no` y `carga_decrece = si` simultáneamente (p. ej. `f1 = 1/10`,
  `f2 = 1/4`), lo que es imposible para un `φ` continuo y subaditivo. **El tope destruye la propiedad
  de partición justo en sus saltos.**
- **tasa decreciente con el tamaño.** Cae en la misma identidad: hacerla decreciente *es* hacerla
  regresiva.

**Conclusión de F4.** El teorema de exclusividad pide un coste no proporcional al espacio; la
condición para que ese coste **además** haga costosa la partición es que sea estrictamente subaditivo;
y eso es exactamente lo que lo hace regresivo. **El teorema es satisfacible, pero sólo por un
mecanismo cuya carga cae sobre las granjas pequeñas en proporción inversa a su tamaño.** No es un
defecto de la propuesta concreta: es la geometría del problema.

---

## 5 · F5 · Unidad, recurrencia y arranque

### 5.1 ¿En qué se paga? Moneda: el arranque es circular y choca con `C-EMIT-02`

`SPEC.md` §8 · **C-EMIT-02** (`verificado en fuente`): «No hay premine, ni founder reward, ni dev tax.
El génesis tiene coinbase de valor cero.» Si la tasa se paga en moneda:

1. **En el génesis no hay moneda distribuida**, luego las primeras identidades no pueden pagarla. La
   regla se viola al arrancar **o** hay que asignar moneda en el génesis, lo que **contradice
   C-EMIT-02**.
2. Alternativa: **pagar con el primer ingreso**, es decir endeudarse. Pero entonces el coste deja de
   ser no recuperable —se convierte en un depósito contra el ingreso futuro— y **vuelve a ser la
   variante (b), dependiente de `κ`**. La propiedad que el encargo valoraba en (c) se pierde en el
   arranque.
3. Alternativa: **barrera de entrada**. Una granja nueva con `f` necesita `τ/(f·λ·I)` slots de su
   propio ingreso para pagar la tasa (`resultados/F5a-unidad.tsv`). Con H3 y `τ = τ_min`, la marginal
   necesita `1,0` slots de ingreso, la mediana `1,82` y la mínima `2,50`: **más del 100 % de un
   horizonte de ingreso para toda granja menor que la marginal.** Que eso sea una barrera en términos
   absolutos depende del valor de un slot, que el instrumento **no fija**; lo que sí fija es que es
   **regresiva** (§4.2).

### 5.2 La variante pagada en cómputo: cumple la letra y es la peor para el modelo de amenaza

Un trabajo fijo `W` por identidad (`resultados/F5b-computo.tsv`):

| propiedad | valor | comentario |
|---|---|---|
| ¿exige moneda previa? | **no** | resuelve el arranque |
| ¿escala con el disco? | **no** | cumple la letra del teorema |
| regresividad | **idéntica** | `carga = W/(f·λ·I)`, ∝ `1/f` |
| ASIC | **ventaja** | `W` es fijo: se especializa y se alquila a escala |
| compatibilidad con el proyecto | **no** | reintroduce **minería PoW**, que `MIGRACION.md` y `research/README.md` registran como retirada |

**El cómputo es la unidad más favorable al atacante precisamente por el modelo de amenaza de Katana**
(«un ente con mucha capacidad atacará»): un coste fijo comprado al por mayor es lo que mejor escala
con capacidad, mientras el granjero doméstico lo paga a precio unitario. Y **no cierra nada que la
moneda no cerrara**, salvo el arranque.

### 5.3 ¿Recurrente o de una vez?

- **De una vez**: se amortiza. La disuasión efectiva por slot es `τ/T_plot` (`resultados/F5c-recurrencia.tsv`),
  que **decae como `1/T_plot`**: en cuanto el plot vive más que el horizonte con el que se fijó `τ`, el
  atacante espera y la tasa deja de disuadir. **No es un parámetro de seguridad, es un amortiguador
  temporal.**
- **Recurrente**: `τ` por identidad y época, `resultados/F5c-recurrencia.tsv`: con `T_rot = 360` slots,
  `τ = 0,1` son `8760` u.e./año por identidad. **Lo paga igual el honesto de una sola identidad**, que
  no tiene ninguna evasión que financiar: es **impuesto permanente al honesto**, exactamente el riesgo
  que el encargo §2.5 señala. Y sigue siendo **fijo**, luego sigue siendo regresivo.

**Qué analiza este informe y por qué:** las dos, porque **ninguna es una defensa**: la de una vez
decae y la recurrente sólo redistribuye la carga hacia el honesto. Se publican ambas como funciones de
sus símbolos, sin fijar ninguna.

---

## 6 · F6 · Veredicto

### 6.1 ¿Dentro o fuera de la línea roja de `AGENTS.md`?

La línea roja es `AGENTS.md:6`: «**No hay staking** ni comités de decisión». *Staking* es un
depósito **proporcional al recurso** y **confiscable** por mal comportamiento. Con ese criterio:

| rama | ¿es staking? | ¿cae dentro de la línea roja? | argumento |
|---|---|:--:|---|
| **(a)** stake ∝ espacio | **sí** | **dentro** | el depósito escala con el disco y se confiscaliza: es la definición |
| **(b)** depósito fijo **confiscable** | no (no escala con el disco) | **fuera de la letra** | es una **fianza** contra Sybil, no un stake; pero **necesita evidencia ⇒ depende de `κ`** y arrastra el arranque monetario |
| **(c)** tasa fija **no recuperable** | no (no hay depósito ni confiscación) | **fuera de la letra** | se paga por existir; **no depende de `κ` como coste**… y por eso mismo **no puede usar la evidencia para nada**: sólo habilita exclusividad, que sí la necesita |
| **(c')** tasa pagada en cómputo | no | fuera de la línea roja del *staking* | pero **dentro de otra línea**: reintroduce PoW, retirada según `MIGRACION.md` |

**Determinación, con el argumento que el encargo pide:** una tasa fija por identidad **no es staking**
—no escala con el disco, así que no convierte el capital en poder de consenso, y el granjero doméstico
podría entrar—. Ésa era la sospecha del encargo y **se confirma como lectura**: (b) y (c) quedan
**fuera de la letra** de la prohibición. **La decisión es de Katana.** Lo que este trabajo añade es que
**la lectura favorable no salva la vía**: fuera de la línea roja, (b) y (c) siguen sin cerrar el
umbral, por las razones de §2–§5.

### 6.2 Tabla de decisión, con el coste de cada rama

`resultados/F6-veredicto.tsv`:

| rama | qué cierra | coste | quién paga | etiqueta |
|---|---|---|---|---|
| **(a)** stake ∝ espacio | nada nuevo: el coste por byte es neutral (teorema) | convierte el consenso en subasta de capital | el granjero sin capital | `verificado en fuente` |
| **(b)** depósito fijo confiscable | nada sin `κq > 0`; con `κq > 0` hereda la pared de `P-CLAVE` | depende de una economía de castigo ya refutada contra claves pobres y nuevas | el honesto con dos nodos (falsos positivos) | `derivado` |
| **(c)** tasa fija en moneda | habilita exclusividad; **no toca el doble farmeo** | **regresiva** (carga `f*/f`) y exige moneda previa | la granja pequeña | `derivado` |
| **(c')** tasa fija en cómputo | cumple la letra y evita el arranque | reintroduce PoW, ASIC-able, regresiva igual | el granjero doméstico frente al que compra cómputo | `derivado` |
| **rechazar (11)** | nada: deja el hueco que la motivaba | ninguno; conserva el tablero honesto | — | `propuesto` |

**Lo que este trabajo recomienda `[propuesto]`, y no decide:** **rechazar la vía (11) como defensa del
umbral** y, si Katana quiere conservar algo, conservarlo **como tarifa** —una tasa de identidad para
otras funciones, p. ej. financiar el registro de `P-COBERTURA` D2 o tarifar spam—, **declarándola como
lo que es y no como una defensa**. Lo que **no** se puede es presentarla como cierre: **`κ = 0` no lo
cierra nada de lo que hay aquí, y esta vía tampoco.**

---

## 7 · Verificación y rendimiento

### 7.1 Controles de corrección

`resultados/TEST.log`: **863 controles, 0 fallos** (1 hilo, `--check-bounds=yes`). Las vías son
independientes entre sí; **ningún test compara una fórmula consigo misma**:

| vía | qué es | contra qué se contrasta |
|---|---|---|
| álgebra del umbral | `g(α*) = 0` exacto en `Rational{BigInt}` y signo estricto a ambos lados | 180 combinaciones de `(β_d, β_x, η_h, η_a)` |
| las tres variantes | coste por byte, dependencia de `κ`, neutralidad de partición | definición del teorema |
| dicotomía | `N·φ(f/N) > φ(f)` frente a `φ(f)/f` decreciente y a `φ(a+b) < φ(a)+φ(b)` | expresiones **distintas**; 7×4×4 celdas con `Rational{BigInt}` |
| `Φ` de la Pareto | primitiva cerrada | **suma de Riemann** por monotonía (cota inferior y superior) |
| Monte Carlo | estimador de proporción con muestreo de la medida de espacio | primitiva cerrada, con **IC de Wilson** y **IC t** entre réplicas |
| reclutamiento | avaricioso (cota) | **fuerza bruta** (201 instancias) y **exacto de dos niveles** |
| reglas | `@fastmath`, `@turbo`, `Float32` fuera de comentarios | barrido del propio código fuente |

### 7.2 Defectos propios detectados y corregidos

1. **El MC muestreaba la medida de conteo.** Insensato en la cola:
   `P_conteo(f ≥ 10⁻⁴) = 1,6·10⁻⁹`, así que `2·10⁴` réplicas daban **cero aciertos** y el estimador
   valía `0` con desviación nula. Corregido a la **medida sesgada por tamaño**, con la que el
   estimador es una proporción y el IC de Wilson es aplicable.
2. **El IC de Wilson no cubre una `p` diminuta con pocos eventos.** Es una propiedad de frecuencia, no
   de la muestra: con `Φ(10⁻²) = 6,28·10⁻⁸` y 1,6·10⁶ réplicas se esperan `0,1` aciertos. El
   instrumento **declara el resultado no aplicable** por debajo de 20 aciertos esperados en lugar de
   publicar un «falso» (`resultados/V2-mc-exacto.tsv`, columna `aplicable`).
3. **Un contraejemplo mal construido.** La primera instancia «de coste fijo» no refutaba al
   avaricioso: las dos granjas pequeñas juntas sí alcanzaban `β`. Sustituida por
   `(1, 9/10), (3/5, 1/2), (3/5, 1/2), β = 1`, donde el avaricioso paga `1` y el óptimo `9/10`.
4. **`escribir` tomaba la cabecera de la primera fila.** Con filas de campos distintos, las columnas
   sobrantes se perdían **en silencio** (le pasó a `V3`). Ahora **falla con error**.
5. **Identificador inválido** `1_menos_2α` (no puede empezar por dígito) y varias decenas de
   desajustes `Rational{BigInt}`/`Rational{Int64}` que sólo aparecen con `--check-bounds=yes`.
6. **`$f()` dentro de una función** en los benchmarks: BenchmarkTools lo rechaza; reescrito con
   llamadas literales.
7. **El verificador de macros se delataba a sí mismo** (los literales `@fastmath`/`Float32` de su
   propio código). Ahora salta las líneas con `occursin(` y las que llevan backticks.

Los siete tienen su vector de regresión en `test/runtests.jl`.

### 7.3 Tabla de rendimiento (LINEO §6)

`resultados/BENCH.txt` y `resultados/BENCH-tabla.tsv`. `uptime` anotado antes del bloque: carga `1,88`
con 4 hilos declarados ⇒ **medido con carga ajena**. Hardware: AMD Ryzen 9 9950X3D (`znver5`), 32
hilos lógicos, 123 GiB, Julia 1.13.0.

| Variante | Tiempo mediano | Asignaciones | Hilos | Frente a la referencia |
|---|---:|---:|---:|---|
| `Φ` Pareto cerrada, 1 punto | `3,10·10⁻⁵ ms` | 0 B | 4 | `= Phi_espacio` |
| `Φ` Pareto cerrada, rejilla 10⁴ | 0,153 ms | **0 B** | 4 | igual en toda la rejilla |
| `Φ` Riemann `K = 20 000` (**oráculo**) | 1,185 ms | 0 B | 4 | **acota** la cerrada |
| MC 1 réplica `M = 10⁴` | 0,167 ms | **0 B** | 4 | coincide con la cerrada (IC Wilson) |
| MC 4 réplicas `M = 10⁴`, 1 hilo | 0,658 ms | 1 744 B | 1 | — |
| MC 4 réplicas `M = 10⁴`, 4 hilos | 0,176 ms | 3 504 B | 4 | **idéntico al serial**, ×3,75 |
| `f_detenida` (kernel) | `1,71·10⁻⁶ ms` | **0 B** | 4 | — |
| `τ_min` (kernel) | `1,31·10⁻⁶ ms` | **0 B** | 4 | — |
| barrido de tasa, 200 puntos | 0,0062 ms | 3 328 B | 4 | monótono (test) |
| reclutamiento avaricioso `n = 10³` | 0,0012 ms | 16 144 B | 4 | **cota superior, no óptimo** |
| reclutamiento exacto, 2 niveles `K = 10⁶` | 0,686 ms | **0 B** | 4 | `=` fuerza bruta en `K` pequeño |

`@allocated`: `phi_pareto!(10⁴) = 0 B`, `f_detenida = 0 B`, `mc_phi_replica = 0 B`, `barrido_tasa = 3328 B`
(los dos vectores de salida). `@code_warntype` de `f_detenida` y `tau_minimo_fee` devuelve
`Body::Float64` sin `Any`. **JET 0.12.1: 0 diagnósticos** en `f_detenida`, `tau_minimo_fee`,
`ganancia_cofarmacion`, `Phi_espacio` y `mc_phi_replica`. Sin `@fastmath`, sin `@turbo`, sin `Float32`.

### 7.4 Escalado (tope del encargo: 4 hilos)

`resultados/ESCALADO.tsv`, MC del kernel con `M = 2·10⁵`, `R = 64`:

| hilos | tiempo | *speedup* | eficiencia | ¿idéntico al serial? |
|---:|---:|---:|---:|:--:|
| 1 | 0,2157 s | ×1,00 | — | sí |
| 2 | 0,1124 s | ×1,92 | 96 % | **sí** |
| 4 | 0,0613 s | ×3,52 | 88 % | **sí** |

**Se conserva 4 hilos**, que es la configuración que gana y el máximo que el encargo permite
(LINEO §7: el tope es un techo, no un objetivo). La reducción es **bit a bit idéntica** entre 1, 2 y 4
hilos: RNG derivado por `hash64(maestra, id)` con **semillas no consecutivas** (mezcla `splitmix64`,
requisito del PROMPT §4) y reducción en orden de id.

---

## 8 · Reproducción

```bash
cd /home/katana/zeo/ZEROX
LC_ALL=C sha256sum -c P-ZRX/P-TASA/ENTRADA.sha256
cd P-ZRX/P-TASA/investigacion/veritas/economia/tasa-identidad-v1
export JULIA_DEPOT_PATH="/home/katana/zeo/ZEROX/P-ZRX/P-TASA/.julia-depot:/home/katana/.julia"

# Perfil de referencia (1 hilo, límites activos): 863 controles
JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 \
  /home/katana/zeo/ZEROX/veritas/julia.sh --project=. --check-bounds=yes test/runtests.jl

# Artefactos publicados (F1..F6, V1..V3)
JULIA_NUM_THREADS=4 OPENBLAS_NUM_THREADS=1 \
  /home/katana/zeo/ZEROX/veritas/julia.sh --project=. run.jl --seed 0x54415341

# Benchmarks y escalado
JULIA_NUM_THREADS=4 OPENBLAS_NUM_THREADS=1 \
  /home/katana/zeo/ZEROX/veritas/julia.sh --project=. bench/benchmarks.jl
# o todo de una vez:
./correr-todo.sh
```

**Artefactos.** `F1-variantes.tsv`, `F2a-igual-espacio.tsv`, `F2c-tau-minimo.tsv`, `F2d-coste-vias.tsv`,
`F3a-particion.tsv`, `F3b-rotacion.tsv`, `F3c-revive.tsv`, `F4a-regresividad.tsv`, `F4b-dicotomia.tsv`,
`F4c-tope.tsv`, `F5a-unidad.tsv`, `F5b-computo.tsv`, `F5c-recurrencia.tsv`, `F6-veredicto.tsv`,
`V1-pareto-riemann.tsv`, `V2-mc-exacto.tsv`, `V3-reclutamiento.tsv`, `TEST.log`, `CORRIDA.log`,
`BENCH.txt`, `BENCH-tabla.tsv`, `ESCALADO.tsv`. **Hipótesis falsables:**
`HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md`. **Bifurcaciones para Katana:** `DECISIONES-PENDIENTES.md`.
**Bitácora y huellas:** `PROGRESO.md`.

---

## Lo que esta investigación NO resuelve

- **La distribución real de tamaños de granja.** No existe medición en ZEROX ni en Autonomys. Todo el
  análisis de regresividad y de `τ_min` está **condicionado a H1**; el teorema de la dicotomía no.
- **El puente espacio → tasa** sigue sin existir (`DEFECTOS.md` C1). Aquí no se usa, pero no se cierra.
- **Los valores de `τ`, `N`, `T_rot`, del tope por identidad, de `λ`, `I`, `P_win`, `T_h`, `c_b`,
  `κq`, `L_p`, `ρ_ret`, `T_v`, `c_r`, `M`.** Son símbolos: el informe da funciones y regiones de
  ellos, no constantes.
- **`κ` como función de `α`** (`P-EQUIVOCACION` P5/P6): se barre como símbolo. La conclusión
  cualitativa —`κq = 0 ⇒ f_det = 0`— **no** depende de eso.
- **La capacidad real de censura `q` y el soborno condicionado al éxito.** No se miden.
- **La identidad de billete (`IDV-01` vs `C-GD-07`).** No la decide este informe; sus cifras tampoco
  dependen de ella, porque aquí el castigo se supone efectivo (`κq` como símbolo).
- **El coste real de un ASIC de identidades** y el rendimiento mínimo de un minero de identidad: **no
  medidos**. La evaluación de la variante en cómputo (§5.2) es **cualitativa en ese punto**.
- **La integración en el nodo.** Nada de esto está en `crates/`: es un modelo cuantitativo.
- **Los precedentes externos** (colateral de Filecoin, mecanismos anti-Sybil con coste de identidad)
  **no se abrieron**: quedan `no verificado` y no se citan. No se inventan citas.
- **`κ = 0`.** No lo cierra nada de lo que hay aquí, ni la tasa. **No se insinúa lo contrario.**
