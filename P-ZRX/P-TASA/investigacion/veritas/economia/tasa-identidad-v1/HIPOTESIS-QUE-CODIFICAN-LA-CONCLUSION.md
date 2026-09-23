# HIPÓTESIS QUE CODIFICAN LA CONCLUSIÓN — P-TASA · tasa-identidad-v1

> Toda cifra de este trabajo es **condicional** a estas hipótesis. Se declaran
> antes de usarlas, se dice **cómo se falsan** y **qué cambia si son falsas**.
> Las que gobiernan el signo del resultado están marcadas **[GOVERNING]**.

---

## H1 · Distribución de tamaños de granja **[GOVERNING]**

**Enunciado.** La fracción de **espacio** por granja sigue una Pareto truncada en
`[10⁻⁸, 1]` con exponente de cola `a`, y se publica la familia
`a ∈ {2,05; 2,2; 2,5; 3,0}` más dos familias discretas declaradas
(`Iguales(10⁶)`, `DosNiveles(0,34; 0,34; 10⁶)`).

**Origen.** Es la **H3 de `P-ZRX/P-CLAVE/investigacion/INFORME.md`** (`a = 2,2`
truncada en `[10⁻⁸, 1]`). **No hay medición** de la distribución real de tamaños
en ZEROX ni en Autonomys: heredarla es una decisión de continuidad, no un dato.

**Cómo se falsa.** Midiendo la distribución real de `f` (fracción de espacio por
clave/granja) en la red. El instrumento la acepta como entrada (`--`distribución).

**Qué cambia si es falsa.** **Nada del teorema** (la dicotomía de F4 no usa la
distribución) y **todo de las cifras**:
- con `a` mayor (cola más ligera) el espacio se concentra más en las granjas
  pequeñas ⇒ `f*` baja ⇒ `τ_min` baja ⇒ **la regresividad numérica cambia**;
- con dispersión extrema (`DosNiveles(0,34; …)`) `f*` salta a `0,34` y `τ_min` es
  del orden del **ingreso de la granja industrial**, mientras la granja pequeña
  paga `f*/f ≈ 5·10⁵` veces su ingreso;
- con **dispersión nula** (`Iguales`) no hay regresividad posible y la tasa que
  funciona resulta **proporcional al espacio**, es decir la variante `(a)`.

**Estado:** `hipótesis declarada`. Es el supuesto que más mueve las cifras.

---

## H2 · La ganancia de cofarmar es lineal en el espacio **[GOVERNING]**

**Enunciado.** `G(f) = f·λ·I·P_win·T_h`. Una granja con fracción de espacio `f`
que farmea en dos ramas obtiene, en el horizonte `T_h`, un ingreso extra
proporcional a su espacio.

**Por qué.** Es la premisa del **propio teorema de exclusividad**
(`research/dag-poas-balizas-auditoria.md` §2, D9: el ploteo y la recompensa son
lineales en bytes e independientes del número de identidades).

**Cómo se falsa.** Encontrando un mecanismo donde la recompensa por cofarmar no
sea lineal en el espacio (p. ej. un reparto con economías de escala, o un
`P_win` que dependa de `f` en sentido decreciente).

**Qué cambia si es falsa.** Es el paso que hace que **un coste fijo no pueda
dominar la evasión para todo tamaño**: si `G` fuera sublineal, una tasa fija
podría dominarla para todo `f`. **Sin H2, el hallazgo R2 (τ_min ∝ f*) cae** y con
él la conclusión de que la tasa fija es necesariamente regresiva. H2 es la
hipótesis que sostiene el resultado central.

**Estado:** `derivado` de la linealidad declarada en el teorema; `P_win` es un
símbolo (entra por CLI) y el resultado es invariante en `P_win > 0`.

---

## H3 · El granjero elige la evasión más barata **[GOVERNING]**

**Enunciado.** Ante una regla «una identidad, una rama», el granjero que quiere
cofarmar elige el mínimo entre quedarse con **una** identidad (coste esperado
`κ·q·L_p`) y **partir** en identidades extra (coste `n_extra·τ + c_b·f`).

**Cómo se falsa.** Mostrando que las dos vías no son sustitutivas (p. ej. que la
evidencia de la vía de una identidad se produce siempre, o que partir exige algo
más que bytes y tasa).

**Qué cambia si es falsa.** De aquí sale
`f_det = min(κq·L_p, n_extra·τ + c_b·f)/(λ·I·P_win·T_h)` y, sobre todo, que
**`f_det = 0` cuando `κq = 0` o cuando `τ = 0` con `c_b = 0`**: la tasa es
**inerte** sin la vía del castigo. Si las vías no fueran sustitutivas, la tasa
podría tener efecto sin `κ`.

**Estado:** `derivado`. La parte «`f_det = 0` si `κq = 0`» es **exacta** y está
en los tests.

---

## H4 · El precio de `β_x` es el ingreso honesto renunciado

**Enunciado.** Para que un granjero ponga su espacio **en exclusiva** en la rama
privada hay que compensarle **al menos** el ingreso público que deja de percibir:
`c_x = λ·I` por unidad de espacio y unidad de tiempo.

**Origen.** Es la lectura económica del reparto de `P-PRESTAMO`: `β_d` no pierde
nada (sigue publicando); `β_x` **abandona** la pública.

**Cómo se falsa.** Con un granjero que ponga su espacio en exclusiva **sin**
compensación (p. ej. si su ingreso público esperado fuera cero por otra razón).

**Qué cambia si es falsa.** Es lo único que **crea un precio** donde la
enfermedad no lo tenía. Si `c_x = 0`, entonces la regla de exclusividad no solo
no cierra: **empeora** el umbral (βx vale el doble) sin cobrar nada. Si `c_x > 0`,
la comparación a igual coste favorece al remedio.

**Estado:** `derivado`; el instrumento publica la comparación **a igual espacio y
a igual coste** precisamente porque el signo depende de cuál se elija.

---

## H5 · La identidad nueva no exige reploteo para el entrante nuevo

**Enunciado.** Un granjero que **planifica** su capacidad decide desde el principio
repartir sus bytes entre `N` claves, y paga el mismo ploteo total; el único coste
extra de identidad es la tasa.

**Origen.** `P-ZRX/P-CLAVE/investigacion/INFORME.md` §F4
(`verificado en fuente` vía el teorema de identidad).

**Cómo se falsa.** Con un formato donde el ploteo dependa del número de
identidades (p. ej. si hubiera que replotear al añadir una clave, que es el caso
de la capacidad **ya plantada**, no del entrante).

**Qué cambia si es falsa.** Si partir costara bytes de forma no lineal, el
teorema de exclusividad ya estaría satisfecho por bytes y la tasa sería
redundante. Para la capacidad **ya plantada** el coste de bytes existe y el
instrumento lo lleva como símbolo `c_b`.

**Estado:** `verificado en fuente` (teorema de identidad) + `c_b` es símbolo.

---

## H6 · El horario de cuota no depende de la historia **[GOVERNING]**

**Enunciado.** `φ` depende sólo del espacio que representa la identidad, no de su
antigüedad, de su identidad previa ni de un registro. Es la consecuencia de que
**no existe registro** (`P-ZRX/P-COBERTURA/`, `demostrado`: la preexistencia no es
acreditable sobre el formato fijado).

**Cómo se falsa.** Si existiera un registro de identidades con edad acreditable,
`φ` podría depender de la edad y la dicotomía de F4 no aplicaría tal cual.

**Qué cambia si es falsa.** La dicotomía «partir cuesta ⟺ regresiva» se demostró
para `φ(f)`; con `φ` dependiente de la historia habría que rehacerla. **Ésta es la
hipótesis que conecta este encargo con `P-COBERTURA`**: sin registro, la tasa no
puede discriminar por edad.

**Estado:** `derivado` de `P-COBERTURA` F2 (`demostrado`).

---

## H7 · El atacante quiere cruzar la deriva

**Enunciado.** El objetivo del adversario es `g > 0` (`α* > α`), no maximizar
ingresos. Es el modelo de amenaza de Katana, y por eso el informe da **coste
absoluto** además del relativo.

**Cómo se falsa.** Con un adversario cuyo objetivo sea otro (p. ej. censura o
griefing), que este informe no cuantifica.

**Qué cambia si es falsa.** Los umbrales `α*` dejan de ser el criterio; el
análisis de la tasa (que es un coste) seguiría siendo válido, pero el objetivo a
comparar no.

**Estado:** `elegido` (modelo de amenaza obligatorio del encargo).

---

## H8 · La unidad de la tasa es moneda o cómputo

**Enunciado.** La tasa se paga (i) en moneda, con el consiguiente problema de
arranque, o (ii) en un trabajo fijo por identidad, que no exige moneda previa.

**Cómo se falsa.** Con una tercera unidad (p. ej. tiempo de maduración, ya
estudiada en `P-ZRX/P-CLAVE`), o con una combinación.

**Qué cambia si es falsa.** Las conclusiones sobre el arranque (F5) son
específicas de cada unidad; la regresividad y la dicotomía **no** dependen de la
unidad, sólo de que el coste sea fijo por identidad.

**Estado:** `elegido` (es la pregunta §2.5 del encargo).

---

## H9 · El horizonte de disuasión es explícito

**Enunciado.** `τ_min` se mide contra el ingreso de la granja **en el mismo
horizonte `T_h`**. La carga adimensional es `φ(f)/(f·λ·I·T_h)`, independiente de
`T_h` salvo por `c_b`.

**Cómo se falsa.** Si `T_h` se eligiera distinto para el coste y para el ingreso,
la comparación sería dimensionalmente inválida.

**Estado:** `elegido`; es una convención declarada, no una medición.

---

## H10 · Ninguna de estas cifras es una decisión de consenso

**Enunciado.** `τ`, `N`, `T_rot`, el tope por identidad, `λ`, `I`, `P_win`,
`T_h`, `c_b`, `κq`, `L_p`, `ρ_ret`, `T_v`, `c_r`, `M`, `S_max` y la distribución
de tamaños son **entradas**; el informe no fija ninguna.

**Cómo se falsa.** Encontrando una cifra del informe que se presente como valor
de consenso. No existe: `run.jl` las imprime como columna.

**Estado:** `elegido` (regla de validez del encargo §8).

---

## Lo que estas hipótesis **no** cubren

- El **puente espacio → tasa** (`H-PUENTE`, `P-ZRX/P-CRP/auditoria/DEFECTOS.md` C1)
  sigue sin existir: `α`, `β` y `f` son fracciones de **espacio**.
- El coste mínimo real del ploteo y de un ASIC de identidades: **no medidos**.
- La distribución real de tamaños: **no medida** (H1).
- El valor de `κ`, `q` y `V`: **símbolos** (`P-CLAVE` F6 y `P-PRESTAMO` F5).
