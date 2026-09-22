# HIPÓTESIS QUE CODIFICAN LA CONCLUSIÓN — espacio-prestado-v1

Toda cifra de este instrumento depende de las hipótesis de abajo. Ninguna es un hecho
demostrado por el propio instrumento: si una cae, la cifra que la usa **no se sostiene**.
Formato: qué afirma · por qué es necesaria · qué la refutaría · estado.

---

## H1 · El puente espacio → tasa es proporcional y sin saturación

**Afirma.** `μ_a/μ_p = (α+β_d+β_x)·η_a / ((1−α−β_x)·η_h)`, donde `μ_x` es el trabajo (peso) por
unidad de tiempo de cada rama. Es decir: `α`, `β_d`, `β_x` son **fracciones de espacio** y el peso
producido es proporcional al espacio, sin rendimientos decrecientes, sin saturación de retardo ni
de IOPS, y sin cambio de régimen.

**Por qué es necesaria.** Es la única hipótesis que convierte «una parcela» en «una tasa de
bloques». **Toda la F2 (ventana) y toda la F3 (juego) dependen de ella.** Sin H1 no hay `p`, no
hay paseo y no hay números de ventana; sólo hay la superficie de deriva (F1), que sí es exacta.

**Qué la refutaría.** `P-ZRX/P-CRP/auditoria/DEFECTOS.md` C1: el puente `espacio → tasa`
(distancia circular, `sd ≤ SR/2`, chunks ganadores) **no está implementado en ningún instrumento
del repositorio**; el defecto D4 sigue abierto. Además `BASELINE.md` §B.1 prohíbe dar por sentado
que `α` sea una fracción de espacio en v0.2/v0.3. Un retardo de verificación que crezca con el
número de ramas, un suelo de IOPS o un límite de CPU por slot la rompen.

**Estado.** `condicionado` y declarado en la primera página del informe y en cada tabla de F2.
**No es una medición de este trabajo**: es una hipótesis de trabajo etiquetada como tal.

---

## H2 · La deriva es la diferencia de medias, y el atacante gana si `g > 0`

**Afirma.** `g = η_a·(α+β_d+β_x) − η_h·(1−α−β_x)`, y la frontera de deriva es su raíz:
`α* = (η_h − η_a·β_d − (η_h+η_a)·β_x)/(η_h+η_a)`.

**Por qué es necesaria.** Es la F1 entera y el término de media del juego.

**Qué la refutaría.** Nada en el alcance de este trabajo: es **aritmética exacta** sobre un modelo
contable de medias, y se comprueba en `Rational{BigInt}` (`g(α*) = 0` exacto en toda la rejilla,
`tests` F1). Lo que sí puede cambiar es que la media no sea el objeto relevante —de eso se ocupan
H3 y H4— y que `η_h`, `η_a` no sean constantes, sino funciones de `(α, β_d, β_x)`
(`BASELINE.md` §B.2: si esos productos cambian con `α`, hay que resolver y publicar todas las
raíces, no sólo la primera).

**Estado.** `demostrado` dentro del modelo contable declarado; `condicionado` a que `η` no dependa
de `α` ni de `β`.

---

## H3 · El paso del paseo es un bloque ±1, con tasas simétricas

**Afirma.** (a) En cada paso ocurre exactamente **uno** de los dos: el atacante produce un bloque
(baja el déficit) con probabilidad `p`, o la pública produce uno (sube) con probabilidad `q = 1−p`;
(b) el peso por bloque es **uniforme** (peso `1`), de modo que el déficit se mide en bloques;
(c) «superar» es **estricto**: el atacante gana cuando el déficit visita `−1` por primera vez.

**Por qué es necesaria.** Es el modelo de F2 (`P_terminal`, `P_first_passage`, `P_eventual`).
Sin (a) y (b) no hay paseo ±1 y los números de ventana no aplican.

**Qué la refutaría.** (a) Si la pública produce varios bloques por paso (DAG con `k` grande) o el
PoT es un reloj propio; (b) si los pesos son heterogéneos —el **poder de compra de varianza** de
`CIFRAS.md` A12/B2 compra cola con `sr` bajo, y el paseo compuesto de Poisson no es ±1—; (c) si
«superar» se define como `≥` y no como `>` (el PROMPT §2 exige el estricto y la diferencia es
`(q/p)^d` frente a `(q/p)^(d+1)`).

**Estado.** `condicionado`. La separación de los tres eventos y el «superar estricto» son
`demostrado`; el paso ±1 con peso uniforme es una **idealización declarada** (`BASELINE.md`
escenario 0 es exactamente ese modelo).

---

## H4 · La ventana `F` es el horizonte, y la carrera es de una sola rama

**Afirma.** (a) El horizonte de la carrera es `F = F_slots` (un símbolo, no una constante): pasado
`F`, `C-FIN-01` prohíbe al nodo con cadena seleccionada reorganizar por debajo, así que la carrera
«que importa» dura como mucho `F`; (b) no hay recompensas, tarifas ni efectos económicos dentro de
la ventana que cambien la comparación de trabajo; (c) el déficit inicial `d` es determinista y vale
`d·g` (la ventaja de la pública al final de la ventana), no una variable aleatoria.

**Por qué es necesaria.** Fija `T` en la DP y convierte `g` en un déficit.

**Qué la refutaría.** Que `C-FIN-01` no esté fijada (`BASELINE.md` §B: `I/F/L_suelo/ρ_max` sin
elegir y `F = 2 h` provisional); que la carrera empiece en un punto distinto (retención selectiva,
rama divergente anterior a la bifurcación) o que `d` sea aleatorio —el PROMPT §2 pide `d` en un
rango declarado, que es lo que se barre—.

**Estado.** `condicionado`. `F` se usa como **símbolo con valores de ejemplo**
(`1.019; 3.547; 3.600; 7.200`), exactamente como manda el PROMPT §3 F2.

---

## H5 · `β_d` es un parámetro libre (régimen `C-GD-07`), no una variable ligada

**Afirma.** Un granjero con `β_d` de espacio puede producir bloques **distintos** en las dos ramas
en el mismo slot, de modo que el espacio prestado es peso **neto** en la privada sin quitarlo de la
pública.

**Por qué es necesaria.** Es lo que hace que `β_d` baje la frontera de deriva.

**Qué la refutaría.** `P-ZRX/P-EQUIVOCACION/investigacion/PROPOSICIONES.md` P7/P8 y
`CANDIDATA.md` §A.3: bajo una identidad de billete basada en la **pieza** (`IDV-01`,
`CANDIDATA.md` §3), dos soluciones de la misma pieza comparten `TicketId` y usarlas en dos ramas
**es la infracción estrecha**; entonces farmear doble obliga a **repartir** el espacio y
`β_d` **no aporta peso neto**: la frontera vuelve a `α* = 1/2`. Bajo `C-GD-07` vigente (con
`chunk`) sí hay soluciones distintas y H5 vale.

**Estado.** `verificado en fuente` para los dos regímenes: **H5 se sostiene con `C-GD-07`** y
**cae con `IDV-01`/`CANDIDATA`**. El informe publica los dos escenarios por separado y nunca mezcla
sus cifras. Ésta es la bifurcación de diseño que decide si el castigo es imprescindible.

---

## H6 · El castigo es prospectivo, estrecho y con inclusión incierta

**Afirma.** El castigo de `CANDIDATA.md` §5/§6: (a) sólo alcanza el doble farmeo **publicado**
(`κ` es la fracción cubierta); (b) cuando la evidencia entra en la historia seleccionada se
pierden las recompensas retenidas, el lote queda inhabilitado y hay que replotear y volver a
madurar; (c) los pagos ya finalizados no se revierten; (d) la probabilidad de que la evidencia
entre es `q_gana` si la privada gana y `q_pierde` si pierde.

**Por qué es necesaria.** Es el término `κ·q·pérdida` del juego y toda la F5.

**Qué la refutaría.** `P-EQUIVOCACION` D14: quien publica **sólo la rama ganadora** no deja par de
bloques y **ninguna identidad de billete lo alcanza** ⇒ `κ = 0` para esa estrategia, que el modelo
trata aparte; `C-GD-07` deja escapar dos soluciones de la misma pieza con `chunk` distinto
(`κ` cae de 1 a 0 en ese escenario); `P5`/`P6` de `PROPOSICIONES.md`: la asimetría de la carrera
del ancla hace que `κ` **no** sea independiente de `α`, sino `κ(α, δ, L)`.

**Estado.** `condicionado`. `κ` se barre como símbolo **por identidad y por valor**, y se declara
que con la estrategia de «sólo la rama ganadora» **no hay `(ρ_ret, T_v)` que disuada** mientras
esa publicación siga siendo rentable.

---

## H7 · El granjero reclutado es racional y su pérdida es la del §2

**Afirma.** `pérdida = ρ_ret·ingreso·T_v + c_r + ingreso·M`, y acepta el soborno `b` si
`b > κ·q·pérdida − ganancia_extra`. El ingreso del granjero es proporcional a su espacio y se mide
en unidades de emisión.

**Por qué es necesaria.** Es el lado derecho del juego (F3, F4, F5, F6).

**Qué la refutaría.** `P-PERMANENCIA` (ADENDA-1 §D): el muestreo de piezas **no demuestra
almacenamiento** y las pruebas parciales **no añaden coste sobre farmear**, sólo lo hacen
observable; un granjero que borra la parcela y regenera dentro de la ventana paga
`c/(r·w)` CPU, no `c_r`. Además `c_r` tiene sólo una medición **histórica** (83,6 s/GiB en 32
hilos, `research/coste-ploteo-medido.md`) que `AGENTS.md` prohíbe heredar como cifra. Y el
granjero puede no ser racional, ni estar solo, ni compartir la misma información.

**Estado.** `condicionado`; `c_r` y `M` son símbolos barridos, y el esquema de permanencia
supuesto se declara en cada fila de F5/F6.

---

## H8 · Las réplicas Monte Carlo son independientes y el RNG está bien derivado

**Afirma.** Cada réplica usa un flujo propio derivado con
`Philox4x((semilla, semilla ⊻ φ))` + `set_counter!(r, (0,0,0,id))`.

**Por qué es necesaria.** Sólo afecta al control de Monte Carlo, no a la DP exacta.

**Qué la refutaría.** `DEFECTOS.md` A1/A2: `StableRNG(semilla + i)` con `i` consecutivo **no da
flujos independientes** (autocorrelación lag-1 medida `−0,43` / `+0,71`), y
`set_counter!(r, id)` con **una sola palabra** desplaza una salida y correlaciona. Ambas cosas se
evitan aquí; el paquete `Random123` **no exporta `Philox4x64`**, sólo `Philox4x` (D7 de
`PROGRESO.md` §3).

**Estado.** `medido` en los tests: la MC cae dentro del IC de Wilson del valor exacto en toda la
rejilla probada.

---

## Lo que NO es una hipótesis de este instrumento

- **La identidad de la deriva** (F1) es aritmética, no una hipótesis.
- **Que la fórmula de `BASELINE.md` escenario 0 se reproduzca** es `demostrado` (su
  `(q/p)^(d+1)` con `p` = tasa del honesto y `q` = tasa del adversario coincide con la DP en las
  celdas probadas; §2.4 del informe), no una hipótesis. La acusación de que estaba invertida fue
  un error de lectura propio y está retirada.
- **Que el consenso base aguante o no el doble farmeo barato** no es una hipótesis: es la pregunta
  F3, y su respuesta depende de H5 y H6.
