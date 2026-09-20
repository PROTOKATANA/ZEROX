# PROPUESTA — PCO-v0.1

**Es una propuesta, no un SPEC.** Nada de esto está medido como diseño vigente y nada de esto entra
en `SPEC.md` por esta vía. Cada palanca lleva **qué reabre**, porque en este repositorio todas las
salidas de este problema han reabierto algo.

El resultado que las motiva (ver `INFORME.md`, corregido el 2026-09-19): bajo la letra de R-FIN-7
**todos los nodos se congelan a la vez en `t_j + F`**, así que entre los que ya estaban la partición
**se resuelve a la fuerza**. Lo que queda son dos rendijas permanentes:

1. el **desfase de vista** en ese único instante, `arcsin(√(τ/F))/π` — **2,6 %** con `F = 600 s`,
   `τ = 4 s`, y sólo baja a `0,58 %` con `F = 3,2 h`, porque va como `√(τ/F)`;
2. **todo el que sincronice después de `t_j+F`**, que toma el líder del momento y ya no puede
   cambiar: probabilidad `L(F)`, que con deriva nula vale **1**.

Y la variable que mueve las dos sigue siendo `(1−c)·(s₁−s₂)`, un producto de dos factores del que
basta que **uno** se anule. Con `s₁ = s₂` la deriva es cero **para cualquier `c`**, y entonces `c` no
toca ninguna de las dos rendijas: las tres primeras filas de la tabla de §2.3 son idénticas para
`c = 0` y para `c = 1`.

## P1 · Corregir la paridad del rango — barata, exacta, no reabre nada

**Qué.** Que el retarget devuelva siempre un `SR` **par**, o —equivalente y más limpio— que
`C-GD-01` divida por el número de valores aceptados y no por `SR+1`:

```
w(B) = ⌊ 2^128 / (2·(SR ÷ 2) + 1) ⌋            en vez de   ⌊ 2^128 / (SR+1) ⌋
```

**Por qué.** `SPEC.md:1669` divide por `SR+1`, pero el predicado de aceptación
(`is_within_solution_range`, `solution_distance ≤ SR/2` con distancia **bidireccional**) acepta
`2⌊SR/2⌋+1` valores: `SR+1` si `SR` es par y `SR` si es impar. Con `SR` impar queda un déficit de
tasa de peso de exactamente `1/(SR+1)`, que crece al crecer la red: `1,6·10⁻¹⁰` a `10^9` piezas,
`1,6·10⁻⁷` a `10^12`, y **`4,88·10⁻⁴` con el `SR_MIN = 2^11`** que el repositorio ha barajado. Y,
peor, es **elegible**: `A(2m) = A(2m+1)`, así que para la misma tasa de bloques hay dos `SR` con
pesos distintos, y cuál se usa depende hoy de un redondeo sin justificación de consenso.

**Qué reabre.** Nada. Es una corrección de coherencia entre el predicado y el peso, verificable en
enteros y sin efecto en ninguna otra regla. `resultados/peso.csv` la cuantifica en todo el dominio.

**Coste.** Una línea de `C-GD-01` y un test de vectores.

---

## P2 · Coste fijo explícito por flujo abierto — media palanca, y hay que decir que es media

**Qué.** Hacer que abrir o seguir un flujo cueste algo fijo y verificable: por ejemplo, exigir que
todo bloque justifique el PoT de su flujo desde la inyección (no solo desde `sp(B)`), o cobrar una
fianza por flujo.

**Por qué.** Baja `c`: sube el tamaño mínimo de granja `x* = ρ_fij/(p−ρ_var)` por encima del cual
cubrir un segundo flujo es racional, y `c` en equilibrio es la fracción del espacio en granjas por
encima de `x*`.

**Por qué es media palanca.** La deriva es `∝ (1−c)(s₁−s₂)`. Bajar `c` multiplica la deriva por un
factor mayor que 1, pero **no toca `s₁−s₂`**, y con reparto simétrico la deriva es **exactamente
cero para cualquier `c`**, incluido `c = 0`. Medido: con `s₁ = s₂`, `P_div(600 s, 4 s) = 0,02560` y
`L(600) = 1` **para `c = 0`, `0,25`, `0,5`, `0,75`, `0,9` y `1` por igual**. **Una palanca que solo
mueve `c` no cierra el problema.**

**Qué reabre.** (i) Centralización: el coste fijo por flujo pesa proporcionalmente más en la granja
pequeña, y es exactamente el mecanismo que expulsa a los pequeños. (ii) El coste fijo ya existe sin
declararlo —verificar el PoT de un flujo cuesta ~0,1 núcleo, `research/dag-poas-ancla-de-orden.md:342`—
así que subirlo es subir el suelo de hardware de un nodo honesto. (iii) Si el coste se cobra en
fianza, aparece un parámetro económico nuevo entre viveza y seguridad.

---

## P3 · Exigir productor de PoT por flujo — la palanca más barata, y la más asimétrica

**Qué.** Que un flujo solo sea válido si alguien está **produciendo** su cadena de PoT, y que
producirla sea atribuible y remunerada.

**Por qué.** Producir el PoT cuesta `prove = 1,561 s/slot` en un 9950X3D
(`research/dag-poas-ancla-de-orden.md:342`), **16 veces** lo que cuesta verificarlo, y no escala con
la granja: es un coste fijo puro. El tamaño mínimo de granja para el que **producir** el PoT de un
segundo flujo es racional es ~16× el de solo cubrirlo (`resultados/cobertura.csv`, columna
`x_min_productor_TiB`). **Un flujo sin productor de PoT no genera retos y muere solo, sin que nadie
tenga que reorganizar nada.** Es el único mecanismo de este informe que mata una partición
**simétrica**, porque no depende de `s₁−s₂`.

**Qué reabre.** (i) Es un timelord con otro nombre, y `research/timelord-redundancia-informe.md`
documenta la dependencia operativa que eso crea. (ii) Si producir el PoT se remunera, el atacante
puede pagarla y **sostener** su flujo: convierte la permanencia de la partición en una cuestión de
presupuesto, que es la pregunta B de `P-2.1` y no está cerrada. (iii) El propio repositorio mide que
la máquina de referencia **no llega a 1 s/slot**: el parámetro `τ` queda atado a la latencia AES del
productor más rápido.

---

## P4 · Reset del flujo en vez de linaje acumulativo — la única que cura, y la más cara

**Qué.** Sustituir `R-FIN-3` (linaje acumulativo, `flujo(B,s) = H(flujo anterior ‖ entropía_j ‖ t_j)`)
por un reset: el identificador de flujo depende **solo** de la última inyección, de modo que dos
flujos divergentes vuelven a coincidir en la ventana siguiente
(`research/dag-poas-relojes-efimeros.md:44-46`, abierto y verificado: *«dos nodos que discrepan en
el mínimo producen bloques con dos relojes, ambos referenciables y azules. Cuando sus conos
coinciden en la ventana siguiente, sus semillas coinciden y los relojes colapsan en uno. La
divergencia permanente exige partición de red real, no un desacuerdo»*).

> **Nota de procedencia.** `P-2.1/ENCARGO.md` §4.0(4) cita esto como `relojes-efimeros.md:18-19`.
> Ese archivo no existe con ese nombre y la frase no está en esas líneas: es
> `research/dag-poas-relojes-efimeros.md:44-46`. Lo mismo con `relojes-auditoria.md:56-61`, que es
> `research/dag-poas-relojes-auditoria.md:54-61`. Las dos citas se han abierto antes de usarlas.

**Por qué.** Es **el único mecanismo de recuperación que funcionó en todo el repositorio**, y ataca
la causa y no el síntoma: con reset la partición deja de ser permanente y `L(t)` deja de ser la
pregunta. Nada de lo que mide este instrumento seguiría aplicando, que es justo lo que se quiere.

**Qué reabre.** Lo que R-FIN-3 estaba conteniendo, y está escrito:
`research/dag-poas-candidatos-auditoria.md:33`, fila «se colorean por último inyector»: *«los linajes
se refunden ⟹ el atacante cobra `m·α` billetes azules ⟹ **umbral `1/(1+m)`** (20 % con m = 4)»*, y
`research/dag-poas-candidatos-auditoria.md:210` dice que el linaje acumulativo **es** la corrección
que lo evita. Es decir: el reset cambia «la partición no se cura» por «el umbral baja a `1/(1+m)`»,
que es exactamente el régimen aditivo que `P-2.1/ENCARGO.md` §1 identifica como el origen del «4 %».
Y fue descartado por motivos **ajenos** a la recuperación
(`research/dag-poas-relojes-auditoria.md:54-61`, abiertos: reparto de recompensa, coste de
verificación sin cota, ruptura de paridad del filtro, cliente ligero sin nada que verificar, y
«sobre todo el grinding gratuito por elección de padres, que es estructural y no un parámetro que se
pueda ajustar»), así que reabrirlo exige releer esos motivos, no solo este informe.

**No recomendada sin medir antes P5.**

---

## P5 · Cerrar el hueco de arranque de R-FIN-7 — la más barata de las nuevas

**Qué.** Decir qué hace un nodo **sin cadena previa**. R-FIN-7 prohíbe *reorganizar* por debajo de
`F`, pero no dice nada de la **primera** selección; si lo prohibiera, un nodo nuevo no podría elegir
nada. Tal como está, quien sincroniza después de `t_j + F` se pega al líder del instante en que
llegue y **queda atrapado ahí para siempre**.

**Por qué.** Es el canal que **domina** el resultado: `L(F)` es uno o dos órdenes de magnitud mayor
que la rendija del desfase de vista, y con deriva nula vale **1**. Cerrarlo —por ejemplo exigiendo
que un nodo nuevo no fije hasta que un flujo lleve `F` liderando, o atándolo a un ancla de
arranque— deja el problema reducido a la primera rendija, que es cien veces menor.

**Qué reabre.** El arranque sin confianza. `SPEC.md:3032` ya dice que lo que falta no es el IBD sin
confianza sino el **IBD sucinto desde estado podado sin ancla externa**; una regla de arranque que
mire «quién lleva `F` liderando» obliga a un nodo nuevo a observar la red durante `F` antes de
poder operar, y una que use un ancla es subjetividad débil declarada. **Pero es redacción de la
regla, no cálculo**, y hoy el hueco está abierto sin que nadie lo haya declarado.

---

## P6 · Subir `F` — funciona contra una rendija, y mal

**Qué.** Alargar `F`.

**Por qué.** `P_div` va como `√(τ/F)`: cuadruplicar `F` la divide por dos. Y `L(F)` sí decae rápido,
pero **sólo si hay deriva**: con `s₁ = s₂` vale 1 para cualquier `F`.

**Qué reabre.** Tres cosas, y están escritas. (i) La propia R-FIN-7 dice que *«tolera cualquier
partición < F» es falso con `S_max` finita: la letra exigiría `S_max ≥ F = 11 520` (DoS ×4 608)*
(`research/dag-poas-ancla-de-orden.md:305-307`). (ii) `F` es el retardo de finalidad: subirlo es
empeorar la propiedad que la regla existe para dar. (iii) De `600 s` a `11 520 s` —diecinueve veces
más— la rendija sólo baja de `2,6 %` a `0,58 %`. **Es la palanca con peor relación coste/efecto de
las seis.**

---

## P7 · Lo que hay que medir antes de elegir ninguna de las anteriores

**`s₁`.** Todo el resultado de este instrumento cuelga del reparto del espacio exclusivo entre los
dos flujos en el instante en que nace la partición, y **no hay en el repositorio ni una medición ni
un modelo de esa distribución**. Si `s₁` se concentra cerca de `1/2` —lo esperable si la partición
nace de que dos mitades de la red leyeron anclas distintas—, entonces:

- la deriva es cero **para cualquier `c`**;
- la rendija del desfase de vista se queda en su peor valor, `arcsin(√(τ/F))/π`, y la de los
  recién llegados en **1**;
- y **ninguna** palanca que mueva `c` cambia eso: sólo P3 (por muerte del flujo sin productor),
  P4 (por reset) y P5 (que cierra el canal dominante sin depender de la deriva).

Esa medición es la continuación natural de la pregunta A de `P-2.1` (`G(d)` y `L_mín`): la misma
simulación que dice **con qué probabilidad** nace una partición puede decir, sin coste adicional,
**con qué reparto** nace. Es, de lejos, lo más barato que queda por hacer aquí.
