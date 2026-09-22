# DECISIONES-PENDIENTES — P-CLAVE · retención por clave

Las bifurcaciones **reales** para Katana. Cada fila: qué decide, qué gana con cada opción, qué paga
y qué cierra. Ninguna fila es una regla propuesta. Rutas completas desde `/home/katana/zeo/ZEROX`.

Las **tres primeras cambian la conclusión**; las siguientes la acotan. La primera es la que decide
si este paquete sirve para algo.

---

## D1 · ¿Se adopta la retención **por clave** sabiendo que no defiende el caso que importa?

**Es la decisión que decide si el paquete entero tiene sentido.**

| opción | qué gana | qué paga | qué cierra |
|---|---|---|---|
| **Adoptar la retención por clave** (desbloquea el paquete: no exige probar el lote entero) | disuade al granjero **con saldo acumulado** y eleva el coste del soborno en el tramo `β > B(ε)` | **no defiende** el caso `B(ε) ≥ 1 − 2α`, que con `α = 0,33` y `T_v ≤ 10⁵` es **todo el barrido**; no disuade a claves nuevas; cuesta `ν·ρ_ret·T_v` al honesto | nada del doble farmeo barato |
| **No adoptarla** (seguir bloqueado por la prueba de cobertura completa) | no se introduce un mecanismo que no protege | el paquete sigue **bloqueado** (`P-SEMBRADOR` C1: la prueba no existe) | — |
| **Adoptarla declarándola como mitigación parcial** | desbloquea, y es honesto sobre su alcance | hay que escribirlo así en `SPEC`/`CANDIDATA.md` y no venderla como defensa del umbral | el malentendido |

**Lo que este trabajo aporta.** Los números: la grieta existe y es **grande** (`B(0,01) = 0,675`
frente a `1−2α = 0,34`). La opción «adoptar declarando el alcance» es la única coherente con
`CANDIDATA.md` §A.2 C1, que ya dice que «el consenso base debe seguir siendo seguro suponiendo que el
doble farming es barato». **Lo que este informe añade es que con retención por clave, el doble farmeo
NO es sólo barato: es gratis para el atacante que necesita la mayor parte del espacio.**

**Quién decide:** Katana (economía + consenso).

---

## D2 · El umbral de «saldo casi cero» `ε`, y con él el tamaño de la grieta

**Qué falta:** qué saldo se considera «cero» a efectos de reclutamiento. **No es una constante
física:** `ε` es un **umbral de indiferencia** del atacante, y depende de `V/N` (el valor del ataque
por reclutado): un granjero acepta el soborno si `B_i < V/N` (más el coste de contacto). O sea,
**`ε` no se elige: se mide en unidades de `V/N`**.

**Reformulación operativa.** `ε = V/N` es la definición correcta. Con `V/N = 400` y `coef = ρλT_v/2`,
`f* = ε/(λT_v) = 400/T_v` y `B = M(400/T_v)`. Con `T_v = 3.600`: `f* = 0,111`, `B = 0,871` — **la
grieta es aún mayor** que con `ε = 0,01`. Con `T_v = 10⁵`: `f* = 4·10⁻³`, `B = 0,841`.

**Qué cierra cada opción.** Fijar `ε = V/N` y publicarlo convierte F3 en una afirmación
**condicionada a `V`** (que ya es símbolo). Cualquier `ε` menor hace la grieta más pequeña
**artificialmente**, y eso hay que declararlo.

**Quién decide:** Katana (modelo de amenaza: cuánto vale `V`).

---

## D3 · `T_v`: ¿se acepta que la ventana de retención tenga que ser corta, o se acepta el coste honesto?

**Qué falta:** `T_v` es la palanca que sube `ρ_ret·T_v` (disuasión) y **a la vez** el término que
cobra al honesto (`ν·ρ_ret·T_v`). **No son independientes.**

**Opciones.** (a) `T_v` largo (≳ 10⁵): cierra la grieta con el criterio heredado, pero exige
`ν < 10⁻⁵` reorgs/slot y castiga más al honesto. (b) `T_v` corto (≤ 10⁴): la grieta está abierta,
pero el coste honesto es menor. (c) **No hay tercera**: no existe `T_v` que cierre la grieta **y**
mantenga el coste honesto bajo con `ν` realista.

**Qué cierra cada opción.** Medir `ν` (la tasa real de reorg en el DAG) es lo que decide. `ν` **no
está medida** (`P-PRESTAMO` D5/D7 dejan `F`, `Δ` y `C-GD-11` pendientes).

**Quién decide:** Katana (consenso) + medición de `ν` en red/DAG.

---

## D4 · La identidad de billete (`C-GD-07` vs `IDV-01`): ¿cambia algo para la retención por clave?

**Estado en `P-PRESTAMO`:** D1, abierta. **Lo que este informe aporta:** las cifras de F1–F6 **no
dependen de ella**, porque aquí el castigo se supone efectivo (`κ` símbolo) y lo que se mide es **a
quién alcanza** el castigo, no qué fracción del doble farmeo deja evidencia. Pero **`κ` sí importa**
en la condición de disuasión: con `κ = 0` no hay región (F6).

**Qué cierra cada opción.** Si `IDV-01` convierte el doble uso de una misma oportunidad en
infracción demostrable, `κ → 1` y la condición de disuasión se refuerza; la grieta de los pequeños
**no se cierra**, porque las claves de saldo cero siguen existiendo y siguen siendo reclutables.

**Quién decide:** Katana (consenso). **Bloqueante:** `IDV-01` está «condicionada»
(`veritas/consenso/identidad-disponibilidad-v1/CONTRATO-VALIDACION.md` §1).

---

## D5 · ¿Se prohíbe o se tasa el **mercado secundario** de recompensas retenidas?

**Qué falta:** H6. Si un granjero puede vender o pignorar su saldo retenido (con descuento) antes de
`T_v`, **el saldo confiscable deja de ser suyo** y el mecanismo se esquiva con un descuento del
mercado. **No se modela.**

**Qué cierra cada opción.** Prohibirlo exige reglas de transferibilidad (y hacerlas cumplir);
tolerarlo convierte la retención en un activo con descuento y la pérdida efectiva en
`ρ_ret·I·T_v·(1 − descuento)`.

**Quién decide:** Katana (diseño económico).

---

## D6 · El coste honesto del firmante seguro: ¿se compensa?

**Qué falta:** `FALSOS-POSITIVOS.md` FP7 dice que el firmante seguro **causa** la pérdida del slot
tras un reorg, y §3.4 lo declara «el precio, y es una decisión de diseño». Este informe lo cuantifica
como `ν·ρ_ret·T_v` (independiente de `f`).

**Opciones.** (a) No compensar (el honesto paga). (b) Compensar con una fracción de las recompensas
retenidas de los castigados — pero eso reduce el disuasivo exactamente en lo que se compensa. (c)
Diseñar el firmante para que **no** pierda el slot (reusar el billete de la historia abandonada con
una regla que no sea la infracción), lo que reabre D4.

**Quién decide:** Katana (producción + consenso).

---

## D7 · ¿Se cuantifica la «compra de varianza» (`R-FIN-13′`)?

**Qué falta:** `P-PRESTAMO` §5.3 dejó ese escenario etiquetado y **no cuantificado**. Aquí se declara
(INFORME §10) que la hipótesis H1 es Poisson. Si el atacante puede **elegir `sr`** para comprar cola,
la cola de F1 se ensancha y **la grieta de F3 empeora**.

**Qué cierra cada opción.** Especificar `R-FIN-13′` y volver a medir. Sin eso, la cifra de la grieta
es una **cota inferior** de su tamaño.

**Quién decide:** Katana (consenso) + instrumento.

---

## D8 · ¿Se adopta el `α` de la ley de potencias como hipótesis de trabajo, y con qué valor?

**Qué falta:** H3. No hay medición de la distribución real de tamaños de clave. `α = 2,2` es una
elección razonada (leyes de potencias de riqueza/tamaño de empresa), **no una medición de ZEROX**.

**Opciones.** (a) Adoptar `α = 2,2` como hipótesis declarada y publicar sensibilidades (lo que hace
este informe). (b) **Medirla**: contar claves y espacio por clave en la red (requiere instrumentación
de red, hoy inexistente). (c) Adoptar el peor caso (`α` grande) y proteger contra él.

**Qué cierra cada opción.** (b) convierte la cifra en medida; (a) la deja condicionada pero **no
bloquea la decisión**, porque la conclusión cualitativa se sostiene en todo el barrido.

**Quién decide:** Katana (prioridad) + instrumentación de red.

---

## D9 · El coste de rotación de claves: ¿se modela como escritura o como estado?

**Qué falta:** F4 estima la rotación como `1 + T_v/T_rot` **veces el ploteo**. Pero el atacante que
rota **no replotea**: el contenido de un sector está ligado a la clave
(`SectorId = blake3_hash_list_with_key(public_key_hash, …)`, `research/dag-poas-balizas-auditoria.md`
Anexo A, `verificado en fuente`), así que **sí hay que replotear**… o mantener el espacio en **dos
claves a la vez**. Cuál de las dos cosas domina (`T_v/T_rot` de ploteo extra, o `β` de espacio extra)
**no se mide aquí**.

**Qué cierra cada opción.** Medir el coste real de re-clavar un sector ya plotado (¿hay
recodificación parcial?) y el coste de mantener dos claves vivas. Sin eso, el factor de rotación de
F4 es una **cota inferior** del coste del atacante.

**Quién decide:** Katana + instrumento (`P-INTENTO` tiene medidas parciales).

---

## Lo que este encargo **no** deja pendiente

- La **distribución del saldo confiscable** por clave: (M3)–(M6) son **exactas** en H1–H2 y están
  verificadas por integración numérica independiente.
- La **frontera de deriva** `β_d > 1 − 2α` con `η = 1`: **demostrada** y comprobada
  (`deriva(α, 1−2α, 0, 1, 1) = 0`).
- La **curva de coste** `C(β) = max(0, β − B(ε))·coef`: **exacta** en el modelo (el tope `b` no se
  alcanza).
- La **región `(ρ_ret, T_v)`**: existe sólo si `ν < 1/(V/N − c_r − I·M)`, y su frontera es
  `ρ_ret·T_v > V/N − c_r − I·M` con `T_v < 1/(ν·ρ_ret)`. **Derivada, no pendiente.**
- La **respuesta a «¿se puede encarecer la creación de claves nuevas sin registro ni moneda
  previa?»**: **no**. Es `verificado en fuente` y **no deja nada pendiente**.
- La **lista de adversarios frente a los que no hay región**: `κ=0`, `q=0`, `V` sin cota, claves
  nuevas, `V > pérdida`, y la grieta de los pequeños. **Derivada.**
