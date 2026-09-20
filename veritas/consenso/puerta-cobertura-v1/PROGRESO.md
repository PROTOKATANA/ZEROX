# PROGRESO — PCO-v0.1

> **Nota de migración (Claude, 2026-09-20, `P-CIERRE`).** Bitácora del ejecutor, migrada desde
> `P-PUERTA/veritas/consenso/puerta-cobertura-v1/` al validar y trasladar el trabajo a `veritas/consenso/puerta-cobertura-v1/`. **Las rutas
> `P-PUERTA/veritas/consenso/puerta-cobertura-v1/` que aparecen más abajo son históricas** y no se han reescrito: son el
> testimonio de dónde se ejecutó. El estado vigente está en `PROCEDENCIA.md` y, para reproducir,
> en `METODO.md`. El original queda intacto en su sitio.

## Apertura

```
$ date
sáb 19 sep 2026 00:43:26 CEST
$ LC_ALL=C sha256sum -c P-PUERTA/ENTRADA.sha256
P-PUERTA/PROMPT.md: OK
$ git -C /home/katana/zeo/ZEROX status --short
 M SPEC.md
 M TAREAS.md
 M ci/reglas-sin-cablear.txt
 M ci/reglas-sin-codigo.txt
?? P-2.1/
?? P-POT/
?? P-PUERTA/
?? problemas/
?? veritas/consenso/poda-post-v1/
?? veritas/consenso/prueba-recursiva-v1/
?? veritas/seguridad/
$ git -C /home/katana/zeo/ZEROX rev-parse HEAD
8dffd1c1a2487ca571cab9a7358c4b7ffb0a21af
```

## Objeciones al encargo, declaradas ANTES de ejecutar (exigido por `PROMPT.md`)

**O1 · El punto 1 no tiene respuesta hasta fijar el predicado de aceptación, y el encargo no lo
fija.** Leído el código fuente conservado en el repositorio:
`PDF/autonomys-subspace/crates/subspace-verification/src/lib.rs:150-158`
(`is_within_solution_range`: `solution_distance <= solution_range / 2`) y
`PDF/autonomys-subspace/crates/subspace-core-primitives/src/solutions.rs:332-337`
(`bidirectional_distance` = mínimo de las dos direcciones con `wrapping_sub`, es decir distancia
sobre un círculo de `2^64`). El número de valores aceptados es por tanto `2⌊SR/2⌋+1`:
**`SR+1` si `SR` es par, `SR` si es impar**. Con `w = ⌊2^128/(SR+1)⌋` (`SPEC.md:1669`, `C-GD-01`),
la cancelación es **exacta para `SR` par** (salvo el suelo, ≤ `2⁻⁶⁴` relativo) y deja un
**déficit exacto de `1/(SR+1)` para `SR` impar**. No es cuestión de régimen ni de transitorio:
es **paridad**. Se entregan las dos ramas.

**O2 · La pregunta del punto 1 está mal planteada: en la media no hay transitorio de retarget.**
`SR` entra como `(SR+1)` en la tasa de bloques y como `1/(SR+1)` en el peso, así que **se cancela
idénticamente en todo instante**, haya convergido el retarget o no, con clamp o sin él. Lo que
**no** se cancela es la **fracción azul** `β`: `blue_work` suma solo azules. El enunciado correcto
es `R_i = β(ν_i·Δ)·W_i·2^64`, y `∝ W_i` vale **si y solo si `β₁ = β₂`**. Con R-FIN-13′ (retarget y
emisión sobre el mismo conjunto pagable, `SPEC.md:1289-1291`) el retarget fija la misma `ν` en
ambos flujos ⟹ `β₁=β₂` ⟹ `∝ W_i` **exacto en régimen**; en el transitorio `ν_i` difiere y `β`
favorece al flujo **minoritario**. Se entrega ese enunciado, no el del encargo.

**O3 · «La dinámica de la diferencia de peso» son dos procesos, no uno.** Con el retarget
convergido, ambos flujos emiten a la **misma tasa** con **pesos distintos** (`w_i ∝ W_i`); antes de
converger, a **tasas distintas** con el **mismo peso** (Skellam verdadero). La deriva coincide
—`∝ (1−c)(s₁−s₂)`— pero **la varianza y el retículo no**, así que las probabilidades de cambio de
signo y la magnitud de arcoseno difieren. Se entregan los dos.

**O4 · `P(dos nodos bloqueados en flujos distintos al alcanzar F)` no está bien planteada sin
regla de bloqueo.** Sin atacante y sin asimetría de red, todos los honestos ven el mismo DAG y el
mismo líder: solo pueden diferir si **bloquearon en instantes distintos**. Se define absorción por
la regla que la causa (adopción + R-FIN-7): *`sign(D)` constante en una ventana de longitud `F`*,
y de ahí sale la cota `P(divergencia) ≤ L(F)`.

**O5 · El `1 517 730×` no sostiene «cubrir es gratis».** Cubrir un flujo más cuesta **cero
espacio**, pero un pase de auditoría completo (lineal en el espacio) **más un coste fijo por flujo
abierto**: verificación del PoT (~0,1 núcleo) y la **producción** del PoT
(`prove = 1,561 s/slot`, `research/dag-poas-ancla-de-orden.md:342`). Ese término fijo no escala con
la granja, luego **`c → 1` no es genérico**: existe un tamaño mínimo de granja por debajo del cual
cubrir no es racional. Eso contradice la fila 1 de `research/dag-poas-candidatos-auditoria.md:33`.

**Adenda 2 de P-2.1 registrada** (exigido por `P-2.1/ADENDA-2.md`): leída antes de escribir código.
Los cinco defectos que señala no se repiten aquí — sin constantes literales como resultado, sin
barrera `K` arbitraria, sin `min(1.0,·)`, sin `S_max(capacidad)` con un SSD fijo, y comparando la
magnitud de arcoseno y no «al menos un cambio». No se ha leído `P-2.1/veritas/…/src/puerta.jl`.

## Entorno

- `julia 1.13.0` vía `veritas/julia.sh`; proyecto aislado con `Manifest.toml` versionado.
- Dependencias: `Arblib`, `SpecialFunctions`, `StableRNGs`, `BenchmarkTools`, `Printf`, `Random`.

## Bitácora

**00:31–00:43.** Lecturas: `veritas/LINEO.md` entero; `P-2.1/ENCARGO.md` §1 y §4.0;
`P-2.1/ADENDA-2.md` entero; `research/fork-choice-poas.md:19-71`;
`research/dag-poas-candidatos-auditoria.md:1-50`; `research/dag-poas-recursion-flujos.md` entero;
`research/dag-poas-ancla-de-finalidad-metaauditoria.md:125-165`; `research/README.md`.
Además, para poder responder al punto 1 sin suponer nada: `SPEC.md` §7.2 y §11 (`C-GD-01`…`C-ORD-01`),
`research/dag-poas-ancla-de-orden.md` (R-FIN-3/4/5/7 y la medición de PoT de `:342`),
`research/coste-ploteo-medido.md:82-91`, `research/dag-nativo-poas-propuesta.md:1360`, y el código
fuente conservado en `PDF/autonomys-subspace/` (`solutions.rs`, `subspace-verification/src/lib.rs`,
`pieces.rs`, `sectors.rs`). **No se ha abierto `P-2.1/veritas/…/src/puerta.jl`.**

**00:43.** Objeciones declaradas (arriba) antes de escribir una línea de código.

**00:40–01:05.** Zona creada, entorno instanciado (`Arblib`, `SpecialFunctions`, `StableRNGs`,
`BenchmarkTools`), `src/peso.jl` y `src/proceso.jl`.

**01:05.** Punto 1 cerrado en enteros exactos. El déficit por paridad sale `−1/(SR+1)` en todo el
barrido y el vecino par sale `< 2⁻⁶⁴`: es la respuesta, y no era la pregunta que el encargo hacía.

**01:12–01:20.** `L(t)`, `t(ε)`, oráculos y Monte Carlo. Primera discrepancia real: la fórmula daba
`0,798` y el Monte Carlo `0,750`, fuera del intervalo de Clopper–Pearson. **No era ruido: era que
fórmula y simulación usaban definiciones distintas del líder en el empate `D = 0`.** Unificadas
(H-EMPATE) y publicada `prob_empate` como cota de sensibilidad. Tras unificar, las seis celdas
comprobadas caen dentro del intervalo.

### Dos defectos propios, encontrados durante la ejecución

**D1 · La ventana de Poisson estaba centrada donde no está el resultado.** `L(t)` decae como
`e^{−I t}` y la contribución dominante a `P(D(t) ≤ 0)` viene de un `n₁` muy por debajo de la media.
Con una ventana de `±10σ` fijada por una tolerancia constante (`10⁻¹⁸`), esa región quedaba fuera:
la suma devolvía `~10⁻³²` —que no era `L(t)` sino el residuo de los términos que sí entraron— y la
cota de truncación, correcta, valía `10⁻¹⁸`. **El encierre seguía siendo válido y era inservible.**
Corregido con `objetivo_automatico`: la tolerancia se fija en `10⁻⁴` de la cota de Chernoff del
propio resultado, así que la ventana se ensancha justo hasta donde vive el valor.

**D2 · La aritmética de bolas se degradaba en la cola.** Dos causas, las dos medidas:
(i) la raíz de Lundberg con radio `10⁻¹³` entraba en `exp(±R)` multiplicando medias de Poisson de
orden `10²`, y la evaluación por intervalos de la gamma incompleta amplificaba el radio ~4 000×:
`L(t)` salía con radio `10⁻⁸`, inútil para hablar de `ε = 10⁻⁹`. Corregido biseccionando la raíz
**en bolas** hasta `10⁻⁴⁰`. (ii) `Arblib.hypgeom_gamma_lower` regularizada, con `μ = 600` y
`m = 844`, devuelve `[± 8,8·10¹¹¹]` a 160 bits —y con `m = 617` ya arruina el resultado—, y esa bola
se propagaba entera: `L(600)` salía con radio `10¹³⁰`. Corregido tabulando la Poisson por
recurrencia y acumulando **sin una sola resta** (`tabla_poisson_arb`), y acotando las colas con
Chernoff. Efecto medido: las bolas pasan de radio `10¹³⁰` a coincidir con el encierre del kernel, y
de 100 s a 0,0 s por evaluación.

**D3 · La variante realimentada no comprobaba la divergencia en la última racha.** Daba `0,5505`
donde la versión base daba `0,681` para la misma celda. Corregido; con `ρ = 0` las dos coinciden
ahora en `0,681`, que es la comprobación que lo detectó.

**Un defecto heredado, no propio:** `research/dag-poas-auditoria.md:269` escribe
«soluciones esperadas/slot = `P·SR/2^65`». Con la distancia **bidireccional** de
`solutions.rs:332-337` el conteo es `P·(2⌊SR/2⌋+1)/2^64`, un **factor 2 mayor**. Su `ε ≤ 1/(SR+1)`
coincide con el valor correcto de la rama impar, pero por otra razón. No se ha tocado ese archivo;
queda anotado.

**01:25–02:15.** Barridos, certificación, tests (212, todos pasan en los dos perfiles), benchmark y
redacción.

## Sobre las horas

Los tiempos de esta bitácora son los de `date` y los `mtime` de los archivos, no una estimación.
El barrido completo (`run.jl --todo`) mide **106 s** de pared y está en `resultados/`; los tiempos
por orden están en `METODO.md` §6.

## Cierre

```
$ date
sáb 19 sep 2026 01:48:15 CEST
$ LC_ALL=C sha256sum -c P-PUERTA/ENTRADA.sha256
P-PUERTA/PROMPT.md: OK
$ git -C /home/katana/zeo/ZEROX status --short
 M SPEC.md
 M TAREAS.md
 M ci/reglas-sin-cablear.txt
 M ci/reglas-sin-codigo.txt
?? P-2.1/
?? P-POT/
?? P-PUERTA/
?? problemas/
?? veritas/consenso/poda-post-v1/
?? veritas/consenso/prueba-recursiva-v1/
?? veritas/seguridad/
$ git -C /home/katana/zeo/ZEROX rev-parse HEAD
8dffd1c1a2487ca571cab9a7358c4b7ffb0a21af
```

### Reejecución final tras limpiar código muerto

Se retiraron de `src/certificado.jl` tres funciones que dejaron de usarse al tabular la
Poisson (`en_cero_uno`, `p_poisson_ge`, `p_poisson_le`) y `texto_bola`, y el `min(1.0, ·)`
residual de `run.jl` (era un recorte de dominio de la ley de arcoseno, ya resuelto dentro de
`arcoseno_continua`). Reejecutado todo: **212/212 tests** en los dos perfiles y el barrido
completo en **102,8 s**, con las cifras clave idénticas.

```
$ date
sáb 19 sep 2026 01:52:31 CEST
$ LC_ALL=C sha256sum -c P-PUERTA/ENTRADA.sha256
P-PUERTA/PROMPT.md: OK
$ git -C /home/katana/zeo/ZEROX status --short
 M SPEC.md
 M TAREAS.md
 M ci/reglas-sin-cablear.txt
 M ci/reglas-sin-codigo.txt
?? P-2.1/
?? P-POT/
?? P-PUERTA/
?? problemas/
?? veritas/consenso/poda-post-v1/
?? veritas/consenso/prueba-recursiva-v1/
?? veritas/seguridad/
```

## Objeción del validador a la regla de absorción — ACEPTADA, y corregida

**Recibida el 2026-09-19, después de entregar.** La regla que yo había escrito —«un nodo se bloquea
cuando el signo del líder se mantiene `F` **desde que ese nodo adoptó**»— **no es lo que dice
R-FIN-7**. Su letra (`research/dag-poas-ancla-de-orden.md:301-303`, releída):

> *Un nodo **MUST NOT** reorganizar su cadena seleccionada **por debajo de `F` segundos de slot***

es una cota a la **profundidad** de la reorganización. Y la profundidad que exige cambiar de flujo
no depende de cuándo adoptó el nodo: con **R-FIN-3** (linaje acumulativo) los dos linajes no vuelven
a coincidir nunca, y con **R-FIN-5** todo bloque del flujo rival tiene su pasado entero en el flujo
rival, así que la bifurcación se queda clavada en `t_j` y su profundidad vale `t − t_j`. **Todos los
nodos se congelan a la vez en `t_j + F`.** La objeción es correcta en los tres pasos y no encuentro
ninguna lectura de la letra que salve mi regla: la mía sería la de una finalidad *desde la
adopción*, que R-FIN-7 no es.

**Qué cambia.** Con vista común, `P(bloqueo divergente) = 0` y la partición **se resuelve a la
fuerza** en `F`. La divergencia pasa a tener dos canales, los dos nuevos:

1. **Desfase de vista** en ese único instante: `P(sign D(F−τ) ≠ sign D(F))`, que en el límite sin
   deriva vale `arcsin(√(τ/F))/π`. Es permanente porque ocurre justo cuando la puerta se cierra.
2. **Los que llegan después**: su bifurcación también está a profundidad `> F`, así que toman el
   líder del momento y ya no pueden cambiar. Su probabilidad de discrepar es `L(F)`, la función que
   ya estaba entregada, y con deriva nula vale **1**.

**El `0,6828` se retira como «dos nodos bloqueados en flujos distintos».** Lo que esa cifra medía es
`P(∃ dos rachas disjuntas de longitud ≥ F con signos opuestos)` dentro de un horizonte de 24 000
slots. Bajo la regla corregida es una **cota inferior estricta** de la divergencia
veterano/recién-llegado —exige una racha completa de longitud `F` del signo contrario cuando al
recién llegado le basta un instante— y el valor correcto de esa magnitud es `L(F)`. Se conserva en
`resultados/absorcion.csv` etiquetada como la regla superada, no se borra.

### Dos defectos más, encontrados al corregir

**D4 · El Monte Carlo estaba sesgado por el generador.** `StableRNG(semilla + i)` con `i`
consecutivo **no da flujos independientes**: las segundas salidas de semillas consecutivas forman
una progresión aritmética (`0,5767 · 0,6283 · 0,6798 · 0,7314 · 0,7830 · 0,8345`) y la
autocorrelación lag-1 de la primera salida sobre 20 000 réplicas es **−0,43**. Se detectó porque la
fórmula nueva y su Monte Carlo discrepaban fuera del intervalo de Clopper–Pearson en dos celdas; un
oráculo de fuerza bruta en `BigFloat` dio la razón a la fórmula al sexto decimal. **LINEO §5.1 ya
decía lo que había que usar** —*«Random123.jl: RNG contracontador/Philox para réplicas paralelas
reproducibles»*— y yo usé `StableRNGs`, que es para fixtures. Migrado todo a Philox: la
autocorrelación baja a **−0,0006** y las 16 celdas de contraste vuelven a caer dentro del intervalo.
Hay test de regresión (`autocorrelacion_replicas`), y **falla** si alguien vuelve al esquema viejo.
Sesgo medido en las cifras afectadas: la media del arcoseno pasa de `0,4958` a su valor exacto.

**D5 · La forma cerrada del congelamiento estaba mal por un factor 2 exacto.** Escribí
`(2/π)·arcsin(√(τ/F))`, que es `P(hay un cero en (F−τ,F))`; la magnitud correcta es
`P(el signo cambia)`, y un paseo puede cruzar el cero y volver al mismo lado. El valor correcto es
`arcsin(√(τ/F))/π`, que sale de la probabilidad de cuadrantes opuestos de una normal bivariante de
correlación `√((F−τ)/F)`. Lo delató el contraste contra el cálculo exacto (factor 2,03 sistemático
en las cuatro celdas sin deriva). Hay test que lo fija.

## Cierre v2 — tras la objeción del validador

Reejecutado todo con el generador corregido y la regla nueva: **239/239 tests** en los dos
perfiles (`--threads=1 --check-bounds=yes` y `--threads=2`), barrido completo en **≈ 400 s**,
48/48 puntos de Arb solapando, y **185 de 188** celdas de Monte Carlo del congelamiento
conteniendo la fórmula (con intervalos al 95 % se esperaban ~9 fallos y hubo 3).

```
$ date
sáb 19 sep 2026 07:47:25 CEST
$ LC_ALL=C sha256sum -c P-PUERTA/ENTRADA.sha256
P-PUERTA/PROMPT.md: OK
$ git -C /home/katana/zeo/ZEROX status --short
 M SPEC.md
 M TAREAS.md
 M ci/reglas-sin-cablear.txt
 M ci/reglas-sin-codigo.txt
?? P-2.1/
?? P-POT/
?? P-PUERTA/
?? problemas/
?? veritas/consenso/poda-post-v1/
?? veritas/consenso/prueba-recursiva-v1/
?? veritas/seguridad/
```
