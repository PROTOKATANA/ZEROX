# INFORME — P-RIVAL / TR-v0.1 · ¿Cuánto trabajo rival hace falta, y queda ZEROX en pie con esa cantidad?

**La respuesta a F6, en la primera línea: depende de la composición, y en la que analizo como
principal no existe punto intermedio.** En la composición **aditiva** —elegida como principal porque
en ella `θ` es literalmente la fracción de peso del trabajo rival— la ventaja de umbral del doble
farmeo es `V = (β_d/2 + β_x)·[1 + θc/(1−θ)] ≥ β_d/2 + β_x`: **no baja nunca con `θ`**, y el cierre
por imposibilidad (`α* > 1`) exige `θ > (1+β_d+2β_x)/(2−ρ+β_d+2β_x) ≥ 1/2`. En la composición de
**umbral** (PoW como condición de validez, fuera del peso) la ventaja es exactamente `β_d/2 + β_x`,
invariante. **En la multiplicativa, en cambio, sí hay un `θ < 1/2` que diluye la ventaja**, con
`V = [β_d + β_x(1+k)]/(1+k)` y `k = (ρ_pub/ρ_priv)^{θ/(1−θ)}`: con una ventaja de trabajo honesta de
10× (`ρ_priv/ρ_pub = 1/10`), `θ = 1/4` sube `α*` de `0,45` a `0,68` y `θ = 1/2` a `0,90`,
reduciendo `V` un 82 %; pero (i) `V > 0` para **todo** `θ` finito —el doble farmeo nunca deja de
pagar del todo—, (ii) el recurso que diluye es la **mayoría de trabajo del honesto**, y el modelo de
amenaza de Katana asume que el atacante puede comprarla: es una **carrera de hash**, no un cierre de
composición, y (iii) en `θ → 1` el espacio deja de pesar. **Conclusión: en la aditiva y en la de
umbral no existe el punto intermedio; en la multiplicativa existe, pero su moneda es la tasa de
hash.** La cifra que lo sostiene: `α* = [1 − β_d − 2β_x − θ(ρ−1)/(1−θ)]/2` en `Rational{BigInt}`,
con control `θ = 0` igual a `(1 − β_d − 2β_x)/2` exacto en las 1.121 comprobaciones del instrumento.

**Categoría:** `consenso` (dominante); `seguridad` y `economía` (secundarias). El objeto es una regla
de peso de consenso y su efecto sobre el umbral; por eso `veritas/consenso/trabajo-rival-v1/`.

**Instrumento:** `P-ZRX/P-RIVAL/investigacion/veritas/consenso/trabajo-rival-v1/` — Julia 1.13.0,
CPU, `veritas/julia.sh`, **sin Python**. Aritmética exacta (`Rational{BigInt}`) en **toda** frontera;
`Float64` sólo en rejillas y benchmarks. **Semilla:** `0x524956414c` («RIVAL»). **Fecha:** 2026-09-23.

**Presupuesto declarado antes de ejecutar:** **4 hilos**, 4 GiB de RAM, 256 MiB de artefactos en
disco (el depósito de precompilación de Julia se declara aparte y es caché regenerable), minutos por
tarea, techo de 2 h de pared. **No se agotó.** `uptime` antes y después en `PROGRESO.md`; carga
media al empezar `1,48` (1 min).

**Advertencia que gobierna todo el informe.** `α`, `β_d`, `β_x` son **fracciones de ESPACIO**, como
en `P-ZRX/P-PRESTAMO/`. El **puente espacio → tasa no existe** en ningún instrumento del repositorio
(`P-ZRX/P-CRP/auditoria/DEFECTOS.md` C1, que lo documenta para los instrumentos v0.2/v0.3). Las cifras de F1–F4 y F6 son aritmética exacta del modelo
de espacio y **no** dependen de ese puente; las de F5 son **coste** y van aparte, con sus supuestos
etiquetados. **No se fija** `θ`, `β_d`, `β_x`, `α`, `ρ`, `c` ni la dificultad: entran por CLI o como
columna.

---

## 0 · Objeción previa al encargo (declarada antes de ejecutar)

El encargo §8 pide decir **antes** lo que parezca equivocado. Tres cosas, y las tres se confirmaron
después con números:

1. **«Rival» no se puede definir por «el coste crece con el número de ramas».** Un VDF por rama
   también hace crecer el coste con las ramas. La propiedad que decide es **P4** de
   `P-ZRX/P-ANCESTRIA/investigacion/INFORME.md` F1: *el recurso se paga de nuevo por cada ancestría*
   (superaditividad sobre historias disjuntas). El VDF por rama es un **peaje por rama** que no
   escala con el peso duplicado, y por eso lo absorbe una granja grande
   (`P-ZRX/P-TASA/investigacion/INFORME.md` §2.3, hallazgo R2). Lo formalizo así en F1.
2. **La premisa de que la pata «cierra» el doble farmeo no tiene privilegio, y en la composición
   principal no se sostiene.** Con la composición aditiva, el trabajo gastado en la segunda copia
   **también pesa a favor de la rama privada**, y la ventaja **no baja nunca** (F3). Con la
   multiplicativa, en cambio, **sí baja** cuando el honesto tiene mayoría de trabajo; pero el
   recurso que la baja es esa mayoría, que el modelo de amenaza permite al atacante comprar. La
   conclusión de F3–F6 es por tanto **dependiente de la composición**, y así se enuncia en la
   primera línea.
3. **El descarte del 26,8941 % de «trunks» no aplica a una pata de PoW**, y mi lectura coincide con
   la del encargo, pero por una razón que hay que escribir con precisión: aquel umbral es una cota de
   **grinding con re-muestreo gratis** (`c = 1`, `φ₁ = e`), y un PoW **no re-muestrea gratis** —cada
   reintento cuesta hashes del mismo presupuesto rival—. Lo desarrollo en F1 con la condición exacta
   bajo la que **sí** aplicaría.

Nada de esto se convierte en recomendación: **no se recomienda adoptar ni retirar PoW**. Se da la
cifra y su consecuencia, y decide Katana (`PROMPT.md` §8).

---

## 1 · F1 · «Rival» formalizado, y el alcance real del 26,8941 %

### 1.1 Definición

Sea `coste(A, H)` el recurso esperado que consume un algoritmo `A` para emitir un certificado válido
para la ancestría `H`, y `R* := inf_H coste(·, H)`. Un recurso es **rival entre historias** si

```text
coste( ∪_{i=1..k} {H_i} )  ≥  Σ_i coste({H_i}) · (1 − o(1))     para ancestrías H_i dos a dos distintas,
```

y es **reutilizable** si existe una estrategia con `coste(∪{H_i}) ≤ (1+o(1))·max_i coste({H_i})`.
La primera es la propiedad **P4** de `P-ANCESTRIA` §F1; la segunda es la **transferibilidad** de
§F1.4. Es una definición **comprobable**: se dirime mirando si la misma unidad de trabajo puede
contarse en dos historias.

**Corolario operativo (la distinción que el encargo pide).** Un recurso rival hace que el coste
escale con **los intentos**; un peaje por rama hace que escale con **las ramas**. Sólo el primero
hace costoso convertir la *misma* lectura de disco en peso para dos ramas, porque sólo el primero
obliga a gastar de nuevo por unidad de peso producido. Ésa es la diferencia entre el VDF por rama
(absorbible) y el PoW por rama (proporcional al beneficio).

**Matiz necesario, porque la definición sola no basta.** Un VDF por rama **también** es
superaditivo: dos ramas, dos líneas de VDF, coste doble. Por P4 sería «rival». Lo que lo descalifica
es la **proporcionalidad**: su coste es un **peaje fijo por rama** que **no crece con el peso que se
duplica**, así que una granja grande lo absorbe (es exactamente el hallazgo R2 de
`P-ZRX/P-TASA/investigacion/INFORME.md` §2.3: un coste que no domina el beneficio lineal no cierra nada). Por
eso separo las dos propiedades y llamo «rival», en el sentido que este encargo necesita, a
**superaditivo *y* proporcional al peso producido por el recurso duplicado**. Bajo esa definición el
VDF por rama queda fuera —como dice el encargo— y el PoW por rama entra. La definición es
**comprobable** en los dos ejes: (i) ¿se paga de nuevo por ancestría? (P4, oráculo aleatorio);
(ii) ¿el coste escala con los intentos o con las ramas?

### 1.2 Qué es rival y qué no

`resultados/F1-rival.tsv`. Resumen:

| recurso | ¿rival? | ley de coste | por qué | etiqueta |
|---|---|---|---|---|
| **PoW por bloque** (reto ligado a los padres) | **sí** | superaditiva | el intento `(nonce, padres)` sirve a **una** historia (oráculo aleatorio: `P-ANCESTRIA` F1.2) | `demostrado` |
| **lectura de disco con reto independiente de la ancestría** | **no** | reutilizable | una lectura vale para toda la clase de transferencia (`P-ANCESTRIA` F1.4) | `demostrado` |
| **VDF por rama** | **no** (peaje) | ∝ nº de ramas, no de intentos | el trabajo no escala con el peso duplicado; lo absorbe la granja grande (`P-TASA` §2.3 R2) | `derivado` |
| **pata de trabajo rival ligada a los padres** | **sí** | ∝ intentos = peso producido | cada bloque de la segunda rama exige intentos nuevos | `propuesto` (la propuesta del encargo) |

Y la consecuencia que el repositorio ya tenía escrita, que es la razón por la que **el doble farmeo
no tiene defensa viva**: «un hash no se puede subdividir en dos intentos que cuenten para dos loterías
distintas al mismo coste marginal. Un sector plotado sí, mientras nada ate el sector a un reloj
concreto en el momento de crearlo» (`research/dag-poas-balizas-auditoria.md:72-74`,
`verificado en fuente`).

### 1.3 ¿Aplica el descarte del 26,8941 % a la pata de PoW? — **No**

El 26,8941 % es `1/(1+φ₁)` con `φ₁ = e`, el valor de la ecuación (39) de BDK+19 con `c = 1`
(`P-ZRX/P-ANCESTRIA/investigacion/INFORME.md` F2.1–F2.3, `verificado en fuente`); `c` es *el número
de niveles del árbol privado entre actualizaciones de la aleatoriedad que decide el ganador*
(`P-ZRX/P-ANCESTRIA/investigacion/INFORME.md` F2.1; `research/dag-poas-ancla-de-finalidad.md:315-318`
da los hechos: trunks, `c = 1`, `φ₁ = e`, 27 %). El descarte es una cota
sobre la **fracción adversarial tolerada cuando el re-muestreo de esa aleatoriedad es gratis**: el
atacante re-elige el ancla en cada nivel y multiplica por `e` su crecimiento.

**Un PoW ligado a los padres no cumple esa hipótesis.** Cambiar el conjunto de padres cambia el reto,
pero cada candidato hay que **buscarlo con hashes nuevos**, del mismo presupuesto que se reparte
entre ramas. No hay multiplicador gratis; el crecimiento del árbol privado es la fracción de hash,
no `e` veces la fracción de hash. La propiedad que sí tiene el PoW es P4 (`P-ANCESTRIA` F1.2,
`demostrado`). Por eso el descarte **no se traslada**. Etiqueta: `derivado`, **condicionado a H5**.

**Condición exacta bajo la que sí aplicaría** (y es el vector a vigilar, F5): si el peso de la pata
pudiera **aumentarse eligiendo entre retos candidatos a coste marginal nulo** —un boleto de lotería
gratis, como el que da un VDF desde el padre seleccionado, donde «cada punta es una lotería»—,
entonces el atacante recupera el re-muestreo gratis, `c = 1`, y el umbral del 26,8941 % vuelve a
morder. **Ésa es la comprobación que hay que exigir a cualquier implementación concreta**: que elegir
padres cueste hashes, no que sea gratis.

---

## 2 · F2 · El modelo de peso híbrido elegido, y el control `θ = 0`

### 2.1 Las tres composiciones

El encargo enumera tres. Las implemento las tres; **analizo como principal la aditiva** y digo qué
cambia con las otras.

| composición | peso de un bloque | `θ` es… | reduce al control con `θ=0` |
|---|---|---|---|
| **aditiva** (principal) | `(1−θ)·w_esp + θ·w_pow` | la fracción literal de peso del trabajo rival | sí, exacto |
| multiplicativa | `w_esp^(1−θ)·w_pow^θ` | la elasticidad (Cobb–Douglas) | sí, exacto (bisección) |
| de umbral | `w_esp`; el PoW es condición de validez | **no es una fracción de peso** | sí, trivialmente |

**Por qué la aditiva como principal.** Es la única en la que «`θ` = fracción del peso que aporta el
trabajo rival» es literal, y es la que permite aislar el efecto de la pata sobre la pendiente en `β`
sin confundirlo con un cambio de unidades. La multiplicativa se analiza como variante (y sirve de
control: con `ρ` iguales **no cambia la frontera**); la de umbral se trata aparte porque `θ` no está
definido como fracción de peso y su efecto es distinto (un peaje, no un peso).

### 2.2 El modelo, exacto

Espacio normalizado a `1`; trabajo rival honesto de referencia, a `1`. El reparto es **el del texto**
de `P-ZRX/P-PRESTAMO/investigacion/INFORME.md` §1:

```text
σ_pub  = 1 − α − β_x          σ_priv = α + β_d + β_x          σ_pub + σ_priv = 1 + β_d
```

El exceso `β_d` **es** la no-rivalidad del espacio. Con `W_b = (1−θ)·σ_b + θ·ρ_b`:

```text
g(α,β_d,β_x;θ,ρ) = (1−θ)·(2α + β_d + 2β_x − 1) + θ·(ρ − 1)
α*(β_d,β_x;θ,ρ)  = [ 1 − β_d − 2β_x − θ(ρ−1)/(1−θ) ] / 2          (θ < 1)
```

`θ = 1` es degenerado (el espacio no entra en el peso) y el instrumento lo rechaza ruidosamente en
vez de devolver un número. `resultados/F2-composiciones.tsv` publica la superficie completa.

### 2.3 Control obligatorio: `θ = 0`

```text
α*(β_d,β_x;0,ρ) = (1 − β_d − 2β_x)/2 = control
```

Comprobado en **todas** las celdas de la rejilla con `Rational{BigInt}` (`g(α*) = 0` exacto y signo
estricto a los dos lados), y **contra una ruta independiente**: la bisección exacta de `g` sobre el
intervalo `[0,1]`, que no usa la forma cerrada (`src/referencia.jl` O2). El control pasa también
explícitamente en `resultados/TEST.log` y en la salida de `run.jl --control`:

```text
β_d=1/10 β_x=0/1  α*=9/20   (1−β_d−2β_x)/2=9/20   g(α*)=0/1  OK
β_d=1/4  β_x=1/10 α*=11/40  (1−β_d−2β_x)/2=11/40  g(α*)=0/1  OK
β_d=1/2  β_x=1/5  α*=1/20   (1−β_d−2β_x)/2=1/20   g(α*)=0/1  OK
CONTROL: θ=0 reproduce α* = (1 − β_d − 2β_x)/2  -> OK
```

---

## 3 · F3 · `θ*(β_d)`: la pata **no** cierra el doble farmeo en la composición principal

### 3.1 La identidad que lo decide (composición aditiva)

La **ventaja de umbral** de un reparto es cuánto baja el umbral por usarlo. En la composición
aditiva **sin compuerta**:

```text
V(β_d,β_x;θ,ρ) := α*(0,0;θ,ρ) − α*(β_d,β_x;θ,ρ) = β_d/2 + β_x
```

**`V` no depende de `θ` ni de `ρ`.** El término `θ(ρ−1)/(1−θ)` es una **constante en `β`**: la pata
desplaza el nivel de la carrera (`desplazamiento = −θ(ρ−1)/(2(1−θ))`), pero **no toca la pendiente**,
que es lo único que hace que el doble farmeo sea una ventaja. Dicho sin fórmulas: **la pata añade una
carrera de hash encima de la carrera de espacio; no cambia cuánto ayuda cada unidad de espacio
duplicada.** Comprobado exacto en la rejilla completa (`resultados/F3-theta-estrella.tsv`).

Con **compuerta** cuyo trabajo **sí entra en el peso** (Modelo A) —el protocolo exige `c` de trabajo
rival por unidad de espacio para que ese espacio pese, el doble granjero **compra** ese trabajo para
la segunda copia y el de la pública no cambia; para `β_x` el trabajo **acompaña** al espacio—:

```text
V(β_d,β_x;θ,c) = (β_d/2 + β_x)·[1 + θc/(1−θ)]   ≥   β_d/2 + β_x = V(β_d,β_x;0,c)
∂V/∂β_x = 1 + θc/(1−θ) = 2·∂V/∂β_d
```

Es decir: **la compuerta no reduce la ventaja, la amplifica**, porque el trabajo de la segunda copia
también suma peso a la rama privada, y el efecto de `β_x` sigue siendo **el doble** que el de `β_d`
comprado. Con el trabajo de `β_d` **reasignado** desde la pública el factor de `β_d` es aún mayor,
`[1 + 2θc/(1−θ)]/2`. **En todos los casos `V(θ) ≥ V(0)` en la composición aditiva.** Si la compuerta
es una **condición de validez cuyo trabajo NO entra en el peso** (composición de umbral), el factor
`[1+θc/(1−θ)]` desaparece y `V = β_d/2 + β_x` exactamente (Modelo B), también invariante.

> **Supuesto declarado (Modelo A).** Que el trabajo de la segunda copia entre en el peso es lo que
> hace que `θ` sea una fracción de peso. Si en su lugar el trabajo de la pública quedase intacto y
> sólo la privada ganase `cβ_x` (sin que el de la pública ceda), el factor de `β_x` sería la mitad;
> el signo de `V(θ) ≥ V(0)` no cambia. La variante no se analiza en detalle porque el diseño natural
> es que el trabajo **acompañe** al espacio que lo exige.

### 3.2 Las tres lecturas de «deja de dar ventaja», y las tres dan lo mismo

`resultados/F3-theta-estrella.tsv`. Como «deja de dar ventaja» es ambiguo, publico las tres lecturas
rigurosas:

| lectura | definición | `θ*(β_d)` | ¿hay `θ < 1/2`? |
|---|---|---|---|
| **(a) marginal** | `∂g/∂β_d ≤ 0` (ventaja de **peso** marginal) | **no existe en `[0,1)`** para `c ≥ 0` (`1 − θ + θc > 0`); y `∂V/∂β_d = [1+θc/(1−θ)]/2 > 0` siempre | **no** |
| **(b) imposibilidad** | `α*(β_d,β_x) > 1` (el atacante no puede reunir ese espacio) | `(1+β_d+2β_x)/(2−ρ+β_d+2β_x) ≥ 1/2` | **no** (igualdad sólo en `β=0, ρ=0`) |
| **(c) económica** | el granjero no gana con duplicar: `(1−θ) ≤ c(p_v−θ)` | con `p_v = 1`: `c ≥ 1` cierra para **todo** `θ`; `c < 1` exige `θ = 1` | **no** |

Las tres coinciden **en la composición aditiva**: el cierre exige que el trabajo rival domine, no una
fracción `θ < 1/2`. (En la composición multiplicativa la lectura (a) cambia; ver §3.4.) Detalles que
importan:

- **(b)** no existe cuando el atacante tiene mayoría de trabajo (`ρ ≥ 1`): entonces el
  desplazamiento de nivel es **negativo** y la pata **baja** el umbral. El honesto tiene que ganar
  además la carrera de hash para que la pata ayude. Dominio: `ρ ≥ 0`; con `ρ < 0` (trabajo negativo,
  no físico) la cota `θ_imp ≥ 1/2` deja de valer. La cota es `θ ≥ θ_imp` (en la igualdad `α* = 1`,
  empate exacto); el cierre estricto (`α* > 1`) pide `θ > θ_imp`.
- **(c)** con `p_v = 1` (paridad de precio trabajo/peso) el cierre exige `c ≥ 1`, es decir que el
  peaje por unidad de espacio valga al menos el peso que ese espacio aporta: **el espacio ya es
  decorativo en el punto en que el peaje lo cierra.** Es la misma dicotomía por otra puerta.

### 3.3 Por qué no puede depender de `β_d`

`V` es **lineal** en `β_d` con coeficiente que no depende de `β_d`. Por tanto cualquier `θ*` definido
por una condición marginal sobre `β_d` es **constante** en `β_d` (o no existe). La intuición de que
«cuanto más espacio duplique, más pata hace falta» es falsa en el modelo aditivo: como la ventaja es
lineal en el espacio y el coste de la pata también, la proporción no cambia. (Lo que sí depende de
`β_d` es el `θ` de **imposibilidad** `(b)`, y **crece** con `β_d`: `5/9 ≈ 0,556` con `β_d = 1/4,
β_x = ρ = 0`; `0,6` con `β_d = 1/2`; `0,655` con `β_d = 9/10`. Siempre por encima de `1/2`.)

### 3.4 La composición multiplicativa **sí** mueve la ventaja (corrección de una afirmación propia)

**Ésta es la corrección más importante del informe, y salió de la verificación matemática
independiente, no de mis tests.** Con `W_b = σ_b^(1−θ)·ρ_b^θ`, el umbral se resuelve en forma cerrada:

```text
k := (ρ_pub/ρ_priv)^{θ/(1−θ)}          α* = [k(1−β_x) − β_d − β_x]/(1+k)
V  = α*(0,0) − α*(β_d,β_x) = [β_d + β_x(1+k)]/(1+k)
```

- Si `ρ_pub > ρ_priv` (**el honesto tiene más trabajo**), `k` **crece** con `θ` y `V` **decrece**
  estrictamente, tendiendo a `β_x` (y a `0` si `β_x = 0`) cuando `θ → 1`.
- Si `ρ_pub = ρ_priv`, `k = 1` y `V = β_d/2 + β_x` constante: es el único caso que el instrumento
  comprobaba antes, y por eso la afirmación universal «`V` nunca baja» pasó los tests.
- Si `ρ_pub < ρ_priv` (**el atacante tiene más trabajo**), `V` **crece** con `θ`: la pata ayuda al
  atacante.

**Contraejemplo exacto de la verificación** (`ρ_priv = 1/2`, `ρ_pub = 1`, `β_d = β_x = 1/10`):
`V = 0,1500 / 0,1481 / 0,1442 / 0,1333 / 0,1111 / 0,1002` para `θ = 0, 1/10, 1/4, 1/2, 3/4, 9/10`.
Y con `ρ_priv = 1/10`, `β_x = 0`: `V = 0,0500 / 0,0436 / 0,0317 / 0,0091 / 0,0001 / 0,0000` y
`α* = 0,45 → 0,52 → 0,65 → 0,90 → 0,999 → 1,00` (`resultados/F3b-multiplicativa.tsv`). **Con una
ventaja de trabajo honesta de 10×, `θ = 1/2` recorta `V` un 82 % y sube el umbral de `0,45` a
`0,90`.** No es un efecto despreciable y **no se puede enunciar el «no existe `θ` útil» sin esta
salvedad**.

Lo que **sí** sigue en pie, y acota la salvedad:

1. `V > 0` para **todo** `θ < 1` finito: el doble farmeo nunca deja de pagar del todo; se diluye.
2. La moneda de la dilución es la **mayoría de trabajo del honesto**. El modelo de amenaza de Katana
   («un ente con mucha capacidad atacará») permite al atacante **comprar** esa mayoría; si la compra,
   `ρ_pub ≤ ρ_priv` y la pata deja de diluir o **empeora** el umbral. La dilución es una **carrera de
   hash**, no una propiedad de la composición.
3. En `θ → 1` el exponente del espacio tiende a `0`: el espacio deja de pesar. Para `θ = 1/2` exacto,
   el peso del espacio y el del trabajo son iguales (reparto Cobb–Douglas), que es justo el límite
   «espacio dominante» del encargo.

---

## 4 · F4 · `α*(θ)` y el efecto perverso `β_d → β_x`

### 4.1 Cómo se mueve el umbral con `θ`

```text
α*(θ) = (1 − β_d − 2β_x)/2  −  θ(ρ−1) / (2(1−θ))
```

`resultados/F4-alpha-theta.tsv`. Lo que cambia con `θ` es **sólo el desplazamiento de nivel**:

- `ρ < 1` (el honesto tiene mayoría de trabajo): el desplazamiento es **positivo** y sube el umbral.
  Pero `α*` puede superar `1`, y entonces el atacante no tiene espacio suficiente: eso es el cierre
  de **F3(b)**, y exige `θ > 1/(2−ρ)` en el límite `β → 0`, es decir **`θ > 1/2`**.
- `ρ = 1`: la pata es **exactamente neutra** en el nivel; `α*(θ) = (1−β_d−2β_x)/2` para todo `θ`.
- `ρ > 1` (el atacante tiene mayoría de trabajo): el desplazamiento es **negativo** y **baja** el
  umbral. La pata **ayuda al atacante**. Es la trampa simétrica de la que el encargo avisa.

### 4.2 El efecto perverso está, y la pata lo **crea**

El encargo pregunta si encarecer `β_d` empuja al atacante a `β_x`, que baja el umbral **el doble**.
La respuesta es **sí, y la pata lo empeora estructuralmente**. Con compuerta de `c` por unidad de
espacio:

```text
ventaja de umbral por unidad de β_d (trabajo comprado)   = [1 + θc/(1−θ)]/2
ventaja de umbral por unidad de β_d (trabajo reasignado) = [1 + 2θc/(1−θ)]/2
ventaja de umbral por unidad de β_x                      =  1 + θc/(1−θ)   = 2 × (β_d comprado)
```

`β_x` **abandona** la pública: el trabajo que ya gastaba en la pública **se reasigna** a la privada,
así que su **coste rival de desembolso es cero**; el de `β_d` no. Además el efecto de espacio de
`β_x` es **doble** (quita 1 a la pública y suma 1 a la privada; `∂α*/∂β_x = −1` frente a
`∂α*/∂β_d = −1/2`). Resultado: **para cualquier `θ` y `c`, `β_x` da exactamente el doble de ventaja
por unidad de espacio que `β_d` comprado, y su coste rival de desembolso es menor** (cero frente a
`c`); incluso frente a `β_d` con trabajo **reasignado** (desembolso cero) la ventaja de `β_x` sigue
siendo mayor. **`β_x` domina estrictamente.** Encarecer `β_d` no sólo no cierra el doble farmeo:
**desplaza al atacante a la evasión que baja el umbral el doble y que no paga la pata.** Es
exactamente la trampa que `P-TASA` §2.2 declara infactible (`P-ZRX/P-TASA/investigacion/INFORME.md`:
comparar `β_d` y `β_x` a igual `β` es comparar un punto que la enfermedad nunca respeta), agravada por
la pata.

**Cuantificación.** Fijado `θ` y `c`, el atacante que puede elegir entre `β_d` y `β_x` pone `β_d = 0`
y todo en `β_x`; el umbral resultante es `α* = [1 − 2β_x − θ(ρ−1)/(1−θ)]/2`, que con `ρ ≤ 1` es
**menor** que el de cualquier reparto con `β_x = 0`, para el mismo gasto de espacio. **La pata no
sólo no cierra: empeora el reparto óptimo del atacante.**

---

## 5 · F5 · El precio

### 5.1 Energía y hardware

El instrumento calcula la tasa de hash que la red necesita para que la pata aporte `θ` del peso.
La normalización está **sostenida en fuente**: `w(B) = ⌊2^128/(SR+1)⌋` (`SPEC.md` C-GD-01) y la tasa
de peso por slot por pieza es `razón(SR) ≈ 1` para `SR` grande (`1 − O(2⁻⁶⁴)` con `SR` par y
`SR/(SR+1) − O(2⁻⁶⁴)` con `SR` impar)
(`P-ZRX/P-RANGO/propuesta/PROPUESTA-SPEC.md:81-92`, `verificado en fuente`), de modo que el peso de
espacio por bloque es del orden del **número total de piezas de la red** `N·C`, con `C` piezas por
GiB (≈1000 según `research/coste-ploteo-medido.md:15`). Entonces

```text
D (hashes esperados por bloque) = θ/(1−θ) · N·C          H (hash/s de red) = λ·D
```

`resultados/F5-coste.tsv`, con `N = 1 PiB`, `C = 1000`, `λ = 1`, `e_hash = 8,2·10⁻⁷ J/hash`
(derivado de `(500 blake3 + distancia) / 27,5 µs`, medido en el repositorio y citado en
`research/coste-ploteo-medido.md:92`, y de **15 W por hilo**, supuesto declarado), y el espacio
amortizado con `83,608 s/GiB` de ploteo (medido, histórico) y `T_vida = 1 año`, `P_plot = 100 W`
(supuestos):

| `θ` | hash/s de red | vatios PoW | vatios espacio (amortizado) | razón | núcleos para 100 TiB |
|---:|---:|---:|---:|---:|---:|
| 0,01 | 1,06·10⁷ | 8,7 | 278 | 0,031 | 0,06 |
| 0,10 | 1,17·10⁸ | 96 | 278 | **0,34** | 0,63 |
| 0,25 | 3,50·10⁸ | 287 | 278 | **1,03** | 1,88 |
| 0,50 | 1,05·10⁹ | 860 | 278 | **3,10** | 5,63 |
| 0,75 | 3,15·10⁹ | 2 579 | 278 | 9,29 | 16,9 |
| 0,90 | 9,44·10⁹ | 7 738 | 278 | 27,9 | 50,6 |
| 0,99 | 1,04·10¹¹ | 85 120 | 278 | 306 | 557 |

**Lectura.** El **orden de magnitud** del punto de equilibrio entre la energía de la pata y la del
ploteo amortizado está en **`θ ≈ 0,25`**: por debajo, la pata es una fracción menor del coste; por
encima, domina. Con `e_hash` de ASIC (4 órdenes menos, `resultados/F5b-sensibilidad-ehash.tsv`) el
PoW se vuelve energéticamente trivial **para quien tenga el ASIC** — que es justo el problema de
§5.3. La comparación con **almacenar** el mismo peso (`resultados/F5c-disco.tsv`, potencias de disco
**supuestas**: SSD 0,1 W/TiB, HDD 5 W/TB) da: con SSD (≈102 W para 1 PiB), la pata a `θ = 0,5`
(860 W) es ≈8× el almacenamiento y a `θ = 0,1` (96 W) es ≈0,94×; con HDD (≈5,1 kW) el
almacenamiento domina y la pata es 0,17× a `θ = 0,5`. **El orden de magnitud depende del medio y de
`e_hash`; lo que no depende de nada es que para `θ` grande la pata es el coste dominante.**

> **Etiquetas.** `medido`: ploteo (83,608 s/GiB, 32 hilos) y throughput de hash
> (`(500 blake3 + distancia) / 27,5 µs`, medido por D9).
> `verificado en fuente`: `w = ⌊2^128/(SR+1)⌋` y `tasa_peso ≈ piezas`. `estimado`: `e_hash`,
> `P_plot`, `T_vida`, las potencias de disco y `C`. La conclusión de F3–F4 y F6 **no** usa F5.

### 5.2 El granjero doméstico

De la última columna: un agricultor de **100 TiB** necesita, para conservar su fracción de peso,
**≈0,6 núcleos** a `θ = 0,1`, **≈5,6** a `θ = 0,5` y **≈51** a `θ = 0,9` (a `1,82·10⁷ hash/s` por
núcleo, medido). Conclusión honesta: **un `θ` pequeño no obliga a comprar GPU** —se mina con la CPU
que ya tiene el granjero—; **un `θ` grande sí**. Y como `θ` pequeño **no cierra nada** (F3), la
pregunta del encargo se responde sola: **el `θ` que haría falta es precisamente el que cambia el
proyecto y obliga a hardware de hash.**

### 5.3 ASIC y centralización

Aquí la pata es **más vulnerable que el reloj PoT**, y por una razón física que el propio repositorio
ya documentó al revés: el PoT de AES está protegido por una **latencia encadenada** —10 instrucciones
dependientes por iteración, `research/pot-aes-asic-chacha.md:15-17`—, y por eso
`research/pot-aes-asic-chacha.md:36-52` concluye que un ASIC no
da un salto de escala. Una función de hash de PoW es **throughput**, no latencia: no tiene ese suelo
físico, se paraleliza y se pipelinea, y la brecha CPU↔ASIC es de **órdenes de magnitud** en J/hash
(la tabla de sensibilidad barre 4 órdenes y el `θ` de equilibrio se mueve con ella). Un PoW pequeño
es el más expuesto porque **el mercado no lo justifica para nadie honesto pero sí para un atacante
dedicado**: no hay suministro de ASIC, pero sí un comprador con motivo. Etiqueta: `derivado` de la
física de la primitiva + `estimado` en la magnitud.

### 5.4 Interacción con el DAG: el grinding de padres (la objeción más seria)

Atacada de frente, y tiene tres partes:

1. **El descarte del 26,8941 % no reaparece por elegir padres** (§1.3): el reintento cuesta hashes.
2. **Para que la pata sea rival, el reto TIENE que comprometer la ancestría.** El reto de PoAS de hoy
   es `reto(f,s) = blake3(aleatoriedad(f,s) ‖ LE64(s))`, función del par `(f,s)`, con `f` derivado de
   `past(B)` (`SPEC.md` C-POT-03; `P-ANCESTRIA` §F1.4). Si la pata se ancla **sólo al flujo**, hereda
   la **misma ventana de transferencia** y una misma prueba sirve a dos ancestrías dentro de ella:
   **la pata no sería rival y no cerraría nada.** Ligarla a los padres es **requisito**, no opción.
3. **¿Contra qué se mina, y qué cambia?** Las tres opciones y su efecto:
   - **Contra el padre seleccionado `sp(B)`**: el reto cambia si cambia `sp(B)`, que a su vez depende
     de `blue_work` (`C-GD-03`). El atacante puede, en principio, producir bloques que compitan por
     ser `sp` de un descendiente; pero cada candidato cuesta hashes, y `sp` es **función de
     `past(B)`** (`C-GD-03`/`C-GD-09`), no una etiqueta libre.
   - **Contra el mergeset/hash del pasado**: cualquier cambio de padres re-rola el reto. Mismo coste
     por reintento; el productor debe fijar **todos** los padres antes de buscar el nonce, con
     `C-GD-10` obligándole a incluir la punta virtual y a barajar la cola.
   - **Contra nada ancestral** (sólo flujo/slot, como `C-POT-03` hoy): **no es rival** (§5.4.2) y no
     cierra nada. Descartada por el propio fin.

   En las dos primeras, **la palanca existe pero no reproduce el 26,8941 %**: obliga a fijar los
   padres **antes** de buscar el nonce (`padres → reto → hash → bloque`), lo que **serializa el
   pipeline del productor** —el mismo cambio de orden que `P-ANCESTRIA` §F6.2 encontró para el ancla
   de profundidad `d`— y da al atacante la elección de **qué bloques entran en el mergeset y con qué
   color**, que es la superficie estándar de GHOSTDAG (`C-GD-05`/`C-GD-06`), **no una nueva**. Las
   mitigaciones vigentes son el barajado obligatorio de `C-GD-10` y el `merge_depth` de `C-GD-11`
   —cuyos cinco `<<PENDIENTE>>` siguen abiertos—. Etiqueta: `derivado de las reglas vigentes`;
   **no medido** en una red.

### 5.5 Identidad del proyecto — lectura

`MIGRACION.md:84-101` y `research/README.md:78-80` registran el **PoW como retirado**: «La limpieza
retiró los mineros antiguos…» y «se abandona la minería PoW». Con eso:

- **`θ = 0`**: PoST puro; es el diseño vigente.
- **`0 < θ < 1/2`**: el peso sigue siendo mayoritariamente espacio. En la composición aditiva la pata
  **no cierra** el doble farmeo (F3); en la multiplicativa **sí lo diluye**, pero sólo mientras el
  honesto gane la carrera de hash. En ambos casos todo granjero honesto debe **hashear** (o ceder
  peso) y entra el diferencial ASIC de una función de throughput.
- **`θ ≥ 1/2`**: el peso lo decide el trabajo. ZEROX es una cadena de PoW con dificultad modulada por
  el espacio.
- **Lectura (`propuesto`):** ZEROX deja de ser PoST en cualquier sentido defendible **en cuanto
  `θ > 0` hace que el peso (o la producción de bloque) dependa del hash**, porque el recurso que
  asegura el consenso deja de ser el disco; el umbral «de mayoría» es `θ = 1/2`. La decisión es de
  Katana. Lo que este trabajo aporta: en la composición aditiva el `θ` que haría falta para cerrar el
  doble farmeo está **por encima** de `1/2`; en la multiplicativa hay dilución con `θ < 1/2`, pero su
  moneda es la carrera de hash. En ningún caso el cierre es gratis.

---

## 6 · F6 · La dicotomía

**La respuesta es dependiente de la composición, y ése es el resultado.** Cerrada por casos:

```text
ADITIVA (principal):      V(θ,c) = (β_d/2 + β_x)·[1 + θc/(1−θ)]   ≥ β_d/2 + β_x   (nunca baja)
                          θ_cierre_imposible = (1+β_d+2β_x)/(2−ρ+β_d+2β_x) ≥ 1/2  (ρ<1; no existe si ρ≥1)
                          cierre económico ⟺ (1−θ) ≤ c(p_v−θ); con p_v=1 ⟺ c ≥ 1 (indep. de θ)
UMBRAL (trabajo fuera del peso): V = β_d/2 + β_x exactamente; el grifo no mueve la frontera.
MULTIPLICATIVA:           V(θ) = [β_d + β_x(1+k)]/(1+k),  k = (ρ_pub/ρ_priv)^{θ/(1−θ)}
                          ρ_pub>ρ_priv ⇒ V decrece hacia β_x (o 0 si β_x=0); ρ_pub<ρ_priv ⇒ V crece.
```

En la **aditiva** las tres lecturas dicen lo mismo: **la pata sólo cierra cuando el trabajo rival
domina**, y entonces el espacio ya no es el recurso que decide. No es un defecto de calibración; es la
geometría del problema: o la pata entra en el peso y no reduce la ventaja (la deja igual con `c = 0`,
la amplifica con `c > 0`), o no entra en el peso y no cambia la frontera de espacio. El `θ` que haría
falta es **`θ > 1/2`, siempre**.

En la **multiplicativa** hay una salvedad real que no se puede omitir: **`θ < 1/2` sí diluye la
ventaja** cuando el honesto tiene mayoría de trabajo (`ρ_pub > ρ_priv`), y la dilución puede ser
grande (con `ρ_priv/ρ_pub = 1/10`, `θ = 1/2` la recorta un 82 %). Pero `V > 0` para todo `θ` finito,
la moneda de la dilución es la mayoría de trabajo del honesto, y el modelo de amenaza de Katana
asume que el atacante puede **comprarla**; si la compra, `ρ_pub ≤ ρ_priv` y la pata deja de diluir o
**empeora** el umbral. Es una **carrera de hash**, y el propio encargo la describe como la rama
«grande» de la dicotomía: el trabajo se convierte en el consenso.

**Formulación final de F6.** No existe un `θ < 1/2` que cierre el doble farmeo **en la composición
aditiva ni en la de umbral**: ahí la ventaja es invariante o creciente y el cierre exige `θ > 1/2`.
En la multiplicativa **sí existe dilución con `θ < 1/2`**, pero (i) no cierra del todo (`V > 0`),
(ii) exige que el honesto gane la carrera de hash y (iii) el atacante puede comprar hash. **El punto
intermedio existe sólo como carrera de presupuesto, no como propiedad de la composición.**

`resultados/F6-dicotomia.tsv` publica la tabla; `resultados/F3-theta-estrella.tsv`, las tres lecturas
de `θ*` en la rejilla.

**Consecuencia, sin recomendación.** La pata **no cierra nada** en el rango en que el espacio manda,
y en el rango en que cierra **ya no es una pata: es el consenso**. Es el resultado del encargo, y se
enuncia como tal; **no se recomienda adoptar ni retirar PoW**.

---

## 7 · Verificación y rendimiento

### 7.1 Controles de corrección

`resultados/TEST.log`: **1.121 controles, 0 fallos** (1 hilo, `--check-bounds=yes`). Las rutas
**genuinamente independientes** y las que **no lo son** se separan aquí, porque la verificación
matemática independiente lo revisó y tenía razón en dos objeciones de método:

| vía | ¿independiente? | contra qué se contrasta |
|---|---|---|
| control `θ=0` vs `α_control_prestamo` | **sí** (la forma cerrada viene de `P-PRESTAMO` §1, otra fuente) | la especialización analítica |
| bisección exacta de `g` en `[0,1]` | **sí** (algoritmo distinto) | la forma cerrada de `α*` |
| enumeración entera de la compuerta (`h÷D`) | **sí** (conteos enteros) | el criterio de tasas `min(s,h/D)` |
| `α*(θ_imp) = 1` exacto | **sí** | la definición de cierre por imposibilidad |
| **multiplicativa cerrada vs bisección exacta** | **sí** (añadida tras la verificación) | la forma cerrada de `k` contra la bisección |
| deriva «desde las tasas» (`g_aditivo_desde_tasas`) | **no**: es la **misma identidad sin expandir** | la expresión factorizada (sólo caza erratas de expansión) |
| diferencia finita de `g` en `β` | **débil**: `g` es **afín**, así que recupera el coeficiente por construcción | la derivada simbólica (guarda, no prueba) |
| `V(θ) ≥ V(0)` con las funciones cerradas | **débil**: fórmula contra sí misma | se refuerza con la bisección exacta en §3.4 |

Cobertura: rejillas de `(β_d, β_x, θ, ρ, c)` con `Rational{BigInt}`; el control `θ=0` en **todas** las
celdas; identidad `g(α*) = 0` exacta y signo estricto a los dos lados; `V(θ) ≥ V(0)` (aditiva) en toda
la rejilla; `θ_imp ≥ 1/2` con igualdad sólo en el origen; **signo de `V` en la multiplicativa**
(decrece/constante/crece) contra la bisección exacta.

### 7.2 Defectos propios detectados y corregidos

Seis, cada uno con su vector de regresión en `test/runtests.jl`:

1. **Un bucle roto en el primitivo de compuerta** (`control_umbral`) referenciaba una función
   inexistente; se eliminó y se sustituyó por dos propiedades enunciadas.
2. **Borde `σ_priv = 0` en la composición multiplicativa**: la bisección lanzaba error en `α = 0`.
   Ahora los factores nulos deciden el signo sin ambigüedad (vector de regresión).
3. **La bisección aditiva con `g(0) ≥ 0`** lanzaba error; ahora devuelve `0` (el atacante gana sin
   espacio propio), que es el valor correcto.
4. **`β_x` no era `2×β_d` con compuerta.** El test inicial suponía que `β_x` vale el doble en la
   derivada; es falso si la compuerta exige trabajo por espacio y `β_d` lo **compra**. La corrección
   distingue **trabajo comprado** de **trabajo reasignado**: con reasignación (el caso de `β_x`) sí
   es el doble, y la diferencia es justamente el efecto perverso de §4.2. El test y el modelo se
   corrigieron juntos; el hallazgo de F4 nació de ahí.
5. **`ventaja_beta_x` estaba fijada a `1`** mientras la derivada `marginal_beta_x` daba
   `2(1−θ)+2θc = 2·[(1−θ)+θc]`; y `§3.1` omitía el factor de compuerta en el término de `β_x`,
   contradiciendo a `§4.2`. Corregido a `V = (β_d/2+β_x)·[1+θc/(1−θ)]` con el **Modelo A** declarado
   (el trabajo de la compuerta entra en el peso), y el test ata `ventaja_beta_x == 2·ventaja_beta_d`.
   Detectado por la **verificación de citas** (observación adicional), no por mis tests.
6. **La afirmación universal «`V` nunca baja con `θ`» era FALSA.** Sólo vale para la composición
   aditiva. En la **multiplicativa**, con `ρ_pub > ρ_priv`, `V` **decrece** con `θ` hasta `β_x` (o
   `0` si `β_x = 0`): el contraejemplo (`ρ_priv=1/2, ρ_pub=1, β_d=β_x=1/10`) da
   `0,1500 → 0,1481 → 0,1442 → 0,1333 → 0,1111 → 0,1002`. **Detectado por la verificación
   matemática independiente**, no por mis tests, precisamente porque sólo probaba el caso
   `ρ_priv = ρ_pub`. Corregido con la forma cerrada `V = [β_d+β_x(1+k)]/(1+k)`, el artefacto
   `F3b-multiplicativa.tsv`, el test del contraejemplo y la reescritura de F6. **Es el hallazgo que
   cambia la conclusión de «no existe `θ`» a «depende de la composición».**

### 7.3 Tabla de rendimiento (LINEO §6)

`resultados/BENCH.txt`. `uptime` anotado antes del bloque. Hardware: AMD Ryzen 9 9950X3D (`znver5`),
32 hilos lógicos, 123 GiB, Julia 1.13.0. **No se usa `@fastmath`, ni `@simd`, ni `@turbo`, ni
`Float32`** en ninguna frontera.

| Variante | Tiempo mediano | Asignaciones | Hilos | Resultado frente a la referencia |
|---|---:|---:|---:|---|
| `α*` exacto `Rational{BigInt}` | 0,752 µs | 78 | serial | fuente de verdad exacta |
| `α*` por bisección (512 it., oráculo) | 966,5 µs | 70 027 | serial | = forma cerrada |
| ventaja marginal (diferencia finita) | 2,854 µs | 285 | serial | = derivada simbólica |
| `α*` multiplicativo (bisección exacta) | 1 214,1 µs | 76 351 | serial | = control |
| rejilla `Float64` 10⁴ puntos | 0,6 µs | **0 B** | serial | sin fronteras decididas |

La corrida es de **minutos** y **no agotó** el presupuesto de 4 hilos / 4 GiB / 256 MiB. Los cinco
kernels son **seriales** (`Threads.nthreads(:default) = 4` declarado, no usado); no se paraleliza un
problema `O(1)`. `@code_warntype` de `alpha_aditivo_f64` devuelve `Body::Float64` **sin `Any`**;
`@allocated` de la rejilla de 10⁴ puntos es **0 B**.

---

## 8 · Reproducción

```bash
cd /home/katana/zeo/ZEROX
LC_ALL=C sha256sum -c P-ZRX/P-RIVAL/ENTRADA.sha256
cd P-ZRX/P-RIVAL/investigacion/veritas/consenso/trabajo-rival-v1
export JULIA_DEPOT_PATH="$PWD/.julia-depot:/home/katana/.julia"

# Perfil de referencia (1 hilo, límites activos): 1.121 controles
JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 \
  /home/katana/zeo/ZEROX/veritas/julia.sh --project=. --check-bounds=yes test/runtests.jl

# Control obligatorio θ = 0 y artefactos publicados
JULIA_NUM_THREADS=4 OPENBLAS_NUM_THREADS=1 \
  /home/katana/zeo/ZEROX/veritas/julia.sh --project=. run.jl --control --seed 0x524956414c

# Benchmarks
JULIA_NUM_THREADS=4 OPENBLAS_NUM_THREADS=1 \
  /home/katana/zeo/ZEROX/veritas/julia.sh --project=. bench/benchmarks.jl
```

**Artefactos.** `resultados/F1-rival.tsv`, `F2-composiciones.tsv`, `F3-theta-estrella.tsv`,
`F3b-multiplicativa.tsv`, `F4-alpha-theta.tsv`, `F5-coste.tsv`, `F5b-sensibilidad-ehash.tsv`,
`F5c-disco.tsv`, `F6-dicotomia.tsv`, `TEST.log`, `CORRIDA.log`, `BENCH.txt`. **Hipótesis falsables:**
`HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md`. **Ficha del instrumento:** `INFORME.md` del propio
directorio. **Bifurcaciones para Katana:** `../../DECISIONES-PENDIENTES.md`. **Bitácora y huellas:**
`../../PROGRESO.md`.

---

## Lo que esta investigación NO resuelve

- **No mide** ninguna red ni granja: el instrumento es un **modelo exacto** sobre umbrales, no una
  simulación de DAG con red, retardo ni mergesets reales. No hay `blue_work` ejecutándose aquí.
- **No decide** si la pata «no cierra nada» o si conviene adoptarla: da la cifra y su consecuencia.
  **No recomienda adoptar ni retirar PoW.**
- **No cuantifica el grinding de padres del DAG** en una implementación concreta: §5.4 es lectura de
  reglas y una condición a exigir (que el reintento cueste hashes), no una medición. `C-GD-11` sigue
  con cinco `<<PENDIENTE>>` y es el pendiente que más puede mover esto.
- **No cierra el puente espacio → tasa** (`P-ZRX/P-CRP/auditoria/DEFECTOS.md` C1, ausencia
  documentada para v0.2/v0.3): `α`, `β_d`, `β_x`
  son fracciones de espacio, y el coste de F5 es aparte.
- **No mide `e_hash`, `P_plot`, `T_vida` ni las potencias de disco**: son supuestos declarados; el
  orden de magnitud de F5 depende de ellos y se publica la sensibilidad.
- **No mide ASICs de blake3**: §5.3 es un argumento físico (throughput frente a latencia) y un barrido
  de 4 órdenes en `e_hash`, no una medición de silicio.
- **No fija** `θ`, `β_d`, `β_x`, `α`, `ρ`, `c`, la dificultad ni ningún parámetro del SPEC.
- **No decide la identidad de billete** (`C-GD-07` frente a `IDV-01`): la conclusión de F3–F6 está
  **condicionada a H1**; con `IDV-01` el doble farmeo deja evidencia y `β_d` no baja el umbral, y el
  problema que este encargo ataca no existiría como tal.
- **No valida** precedentes externos (PoW híbrido, SpaceMint, etc.): no se abrió ninguno; quedan
  `no verificados` y no se citan.
