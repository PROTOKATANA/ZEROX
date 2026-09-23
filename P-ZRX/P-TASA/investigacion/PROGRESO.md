# PROGRESO — P-TASA · tasa-identidad-v1

> Bitácora con `date`, `uptime` y las comprobaciones de entrada y salida del encargo
> `P-ZRX/P-TASA/PROMPT.md`. **Se escribe SOLO en `P-ZRX/P-TASA/investigacion/`** (PROMPT §5).

---

## 0 · Objeciones al encargo, declaradas ANTES de empezar (PROMPT §8)

El encargo pide que, si algo parece equivocado, se diga antes de empezar. Cuatro cosas. Ninguna impide
ejecutarlo; tres cambian el encuadre de la respuesta y una la condiciona. **Las cuatro se confirmaron
al ejecutar**; se indica dónde.

**O1 · La propiedad «(c) no depende de `κ`» es cierta y vacía.** Una tasa no recuperable, como *coste
de crear una identidad*, no depende de `κ`: se paga antes de actuar y nadie la confisca. Pero su
**único uso posible** —habilitar una regla de exclusividad— **sí** depende de `κ`, porque una regla
«una identidad, una rama» sólo se hace cumplir con evidencia, y la evidencia exige que el atacante
**publique** la rama perdedora (`P-CLAVE` F6: `κ = 0` y censura total no tienen región). El encargo
presenta la independencia de `κ` como *la* propiedad interesante de (c). **CONFIRMADA y cuantificada:**
`f_detenida = min(κq·L_p, n_extra·τ + c_b·f)/(λ·I·P_win·T_h)`, de donde **`f_detenida = 0` para todo
`τ` si `κq = 0`**, y **`f_detenida = 0` para todo `κq` si `τ = 0` y `c_b = 0`**. El instrumento lo
comprueba con igualdad exacta (`test/runtests.jl`, testsets «la tasa es inerte sin prueba» y
«equivalencia»). Está en `INFORME.md` §2.1 y en `DECISIONES-PENDIENTES.md`.

**O2 · «Coste no proporcional al espacio» no basta, y el encargo lo da por bueno sin probarlo.**
**CONFIRMADA y demostrada.** El **beneficio de evadir** es **lineal en el espacio**
(`G(f) = f·λ·I·P_win·T_h`, que es la premisa del propio teorema), así que un coste **fijo** sólo domina
por debajo de un tamaño: `τ_min = f*·(λIPTh − c_b)` con `f* = Φ⁻¹(1−2α)`. **Existe siempre un tamaño
de granja por encima del cual la tasa se absorbe.** La condición del teorema es **necesaria y no
suficiente**. `INFORME.md` §2.3.

**O3 · La comparación «`β_d → β_x`, ¿el remedio es peor?» está mal calibrada si se hace a igual `β`.**
**CONFIRMADA y publicada en las dos direcciones.** A igual `β` el remedio es peor (`α*`: `0,40 → 0,30`
con `β = 0,2`, exacto); a **igual coste** el remedio es mejor, porque la enfermedad es **gratis**
(`P-PRESTAMO` F3) y el remedio tiene un precio. Arriesgar «el remedio es peor» a partir de la
comparación a igual `β` habría sido un error. **Y hay un tercer sentido, que el encargo no apunta y
que sí da la razón a la sospecha:** la tasa es un **filtro por tamaño** (`τ_min ∝ f*`), luego castiga a
la pequeña y exime a la grande. `INFORME.md` §2.2.

**O4 · La distribución de tamaños decide el signo de F3 y F4 y no existe dato.** **CONFIRMADA.** H3
(«Pareto truncada `[10⁻⁸, 1]`, exponente 2,2») es **hipótesis declarada de `P-CLAVE`**, no medición. El
**teorema de la dicotomía no depende de ella**; `τ_min` y la **magnitud** de la regresividad sí
(`Pareto(2,2)`: carga máxima `2,5×`; dispersión extrema: `5,15·10⁵×`). Publico una familia declarada y
separa teorema de cifra. `INFORME.md` §2.3, §4.2; `HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md` H1.

**Nota de alcance que el encargo no pide.** La tercera vía de §2.5 (pagar la tasa **en cómputo**) no
choca con la línea roja del *staking*; choca con la **otra** dirección declarada del proyecto
(`MIGRACION.md:84-90`, `research/README.md:78`: retirada de la minería PoW). Se trata como lo que es:
una decisión distinta, con su coste (`INFORME.md` §5.2).

---

## 1 · Entrada (PROMPT §5)

Comprobaciones ejecutadas **desde la raíz** `/home/katana/zeo/ZEROX` antes de escribir nada:

```text
$ LC_ALL=C sha256sum -c P-ZRX/P-TASA/ENTRADA.sha256
P-ZRX/P-TASA/PROMPT.md: OK

$ git -C /home/katana/zeo/ZEROX status --short
 M Cargo.lock
 M Cargo.toml
 M MIGRACION.md
 M P-ZRX/PROPUESTAS-VIABLES.md
 M README.md
 M SPEC.md
 M TAREAS.md
 M ci/consenso-pendiente.txt
 M ci/frontera-crates.sh
 M ci/reglas-sin-cablear.txt
 M ci/reglas-sin-codigo.txt
 M crates/zx-consensus/Cargo.toml
 M crates/zx-consensus/src/bloque_dag.rs
 M crates/zx-consensus/src/error.rs
 M crates/zx-consensus/src/ghostdag.rs
 M crates/zx-consensus/src/lib.rs
 M crates/zx-consensus/tests/ghostdag_bench.rs
 M crates/zx-consensus/tests/ghostdag_oraculo.rs
 M crates/zx-consensus/tests/ghostdag_prop.rs
 M crates/zx-consensus/tests/ghostdag_rust.rs
?? P-ZRX/P-ANCESTRIA/
?? P-ZRX/P-COBERTURA/
?? P-ZRX/P-LATENCIA/
?? P-ZRX/P-TASA/
?? crates/zx-consensus/src/pot.rs
?? crates/zx-consensus/tests/pot_slot.rs
?? crates/zx-pot/

$ date
mié 23 sep 2026 17:38:14 CEST
$ uptime
 17:38:14  up 15 days 14:07,  0 users,  carga promedio: 1,00, 1,03, 1,06
```

**Ficheros ya marcados `M` que NO son míos** (PROMPT §5). Hay otro encargo trabajando a la vez:
`Cargo.toml`, `Cargo.lock`, `MIGRACION.md`, `README.md`, `SPEC.md`, `TAREAS.md`,
`P-ZRX/PROPUESTAS-VIABLES.md`, `ci/consenso-pendiente.txt`, `ci/frontera-crates.sh`,
`ci/reglas-sin-cablear.txt`, `ci/reglas-sin-codigo.txt`, `crates/zx-consensus/*` y los `??`
`P-ZRX/P-ANCESTRIA/`, `P-ZRX/P-COBERTURA/`, `P-ZRX/P-LATENCIA/`, `crates/zx-consensus/src/pot.rs`,
`crates/zx-consensus/tests/pot_slot.rs`, `crates/zx-pot/`. **Se registran y no se tocan.** (A lo largo
de la sesión el otro encargo añadió además `crates/zx-consensus/tests/pot_derivaciones.rs`; tampoco es
mío.) Este trabajo escribe **exclusivamente** bajo `P-ZRX/P-TASA/investigacion/`.

**Presupuesto declarado antes de ejecutar** (PROMPT §8.11, LINEO §7): **4 hilos**, **4 GiB de RAM**,
**256 MiB de artefactos en disco** (el depósito de precompilación de Julia, `P-ZRX/P-TASA/.julia-depot`,
es caché regenerable y se declara aparte: **139 MiB** medidos al terminar), **minutos por tarea** y un
techo de **2 h de pared** para el conjunto de corridas. Arranca por debajo del tope de LINEO (24 hilos)
porque el encargo lo fija en 4. **No se agotó**: el conjunto completo (`./correr-todo.sh`) tarda ~65 s;
ninguna corrida pasó de ~30 s. Los artefactos ocupan **132 KiB** y el encargo entero (sin el depósito de
Julia) **400 KiB**. Si se hubiera agotado el presupuesto: checkpoint y **inconcluso**; no se convierte
un timeout en falsedad.

---

## 2 · Qué se construyó

`veritas/economia/tasa-identidad-v1/` con la estructura de LINEO §1:

```text
Project.toml · Manifest.toml (plantilla compartida veritas/plantilla/)
src/modelo.jl        deriva, α*, las tres variantes, f_detenida, τ_min, distribuciones, horarios φ, dicotomía
src/referencia.jl    Φ por Riemann con cotas, fuerza bruta y exacto de reclutamiento, barrido de dicotomía
src/rapido.jl        kernels Float64, barrido de tasa, MC Philox por réplica, Wilson, t, cargas de F5
src/validacion.jl    rutinas de validación que cuentan controles y devuelven los fallos
test/runtests.jl     perfil de referencia (1 hilo, --check-bounds=yes)
bench/benchmarks.jl  tabla LINEO §6, @allocated, @code_warntype, JET
bench/escalado.jl    escalado 1/2/4 hilos con referencia serial en el mismo proceso
run.jl               CLI reproducible: --seed, --tarea f1..f6, v1..v3
correr-todo.sh       las cuatro etapas con uptime/date
resultados/          artefactos generados (no fuente de verdad)
INFORME.md           ficha técnica del instrumento
HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md   H1..H10, falsables
```

**Representación elegida.** La operación dominante es evaluar `Φ(x)` y compararla con `1−2α` en
rejillas: estructura escalar y contigua, sin grafos ni diccionarios; las familias discretas van
**comprimidas** (`Iguales`, `DosNiveles` son funciones escalón, no vectores de 10⁶ racionales). El
reclutamiento del atacante es un problema de **selección con coste fijo por granja**, así que el
avaricioso es sólo cota y hacen falta un exacto y una fuerza bruta.

---

## 3 · Bitácora de ejecución (`date` / `uptime`)

| Hito | `date` | `uptime` (carga) |
|---|---|---|
| entrada verificada | `mié 23 sep 2026 17:38:14 CEST` | `1,00` |
| andamiaje creado | `17:41:14` | `1,57` |
| primer `test/runtests.jl` (falla: tipos) | `17:47` | — |
| tests en verde, 633 controles | `17:50` | — |
| tests en verde, **863 controles** (con la equivalencia estricta) | `17:52` | — |
| primera corrida de artefactos F1..F6, V1..V3 | `17:51` | — |
| pipeline 1/4 y 2/4 OK; benchmarks fallan (`$f()`) | `17:54` | `1,86` |
| benchmarks OK (JET: 0 diagnósticos) | `17:55:31` | `1,88` |
| escalado 1/2/4 hilos | `17:56:20` | `2,09` |
| reproducción completa `./correr-todo.sh` **exit 0** | `17:59:07` | `2,55` |
| salida verificada | `17:59:34` | `2,01` |

Anotación honesta: la carga media de la máquina estuvo entre `1,5` y `2,5` durante los benchmarks
(hay otro encargo trabajando), así que **los tiempos están medidos con carga ajena**; el escalado es
por eso especialmente relevante, y sale `×1,92` y `×3,52` con resultado **bit a bit idéntico**.

---

## 4 · Defectos propios detectados y corregidos

Siete, todos con vector de regresión en `test/runtests.jl`:

| # | defecto | cómo se detectó | corrección |
|---|---|---|---|
| **O1** | el Monte Carlo muestreaba la **medida de conteo**: en la cola, `P_conteo(f ≥ 10⁻⁴) = 1,6·10⁻⁹`, así que `2·10⁴` réplicas daban **cero aciertos** y el estimador valía `0` con desviación nula | `validar_mc` falló con «el IC no contiene el valor cerrado» y «desviación nula» | muestrear la **medida sesgada por tamaño**: el estimador pasa a ser una **proporción** y el IC de Wilson es aplicable |
| **O2** | el IC de Wilson no cubre una `p` diminuta con pocos eventos (propiedad de frecuencia, no de la muestra): `Φ(10⁻²) = 6,28·10⁻⁸` ⇒ `0,1` aciertos esperados | `validar_mc` falló con `1,1·10⁻⁷ ≤ 6,3·10⁻⁸ ≤ 3,5·10⁻⁶` | por debajo de **20 aciertos esperados** el resultado se **declara no aplicable** y certifica la cota de Riemann (`V2`, columna `aplicable`) |
| **O3** | el «contraejemplo» del avaricioso **no refutaba nada**: las dos granjas pequeñas juntas sí alcanzaban `β` | `validar_reclutamiento` falló con «el exacto no elige la grande» | instancia correcta `(1, 9/10), (3/5, 1/2), (3/5, 1/2), β = 1`: avaricioso `1`, óptimo `9/10`; en el barrido aleatorio, **48 de 200** instancias tienen avaricioso no óptimo (49 de las 201 filas contando el contraejemplo construido) |
| **O4** | `escribir` tomaba la cabecera de **la primera fila**: con filas de campos distintos las columnas sobrantes se perdían **en silencio** (le pasó a `V3`, que perdió `factible`) | el `awk` de recuento no encontraba la columna esperada | ahora **falla con error** si las claves de una fila difieren de la cabecera |
| **O5** | identificador inválido `1_menos_2α` (no puede empezar por dígito) y decenas de desajustes `Rational{BigInt}`/`Rational{Int64}` | el propio compilador, sólo con `--check-bounds=yes` | renombrado y promoción explícita |
| **O6** | `@benchmark $f()` dentro de una función: BenchmarkTools lo rechaza (`invalid assignment location`) | `bench/benchmarks.jl` no arrancaba | llamadas literales con los **datos** interpolados y el `Trial` en variable aparte |
| **O7** | el verificador de macros se delataba a sí mismo (los literales `@fastmath`/`Float32` de su propio código) | testset «macros y tipos prohibidos» | salta las líneas con `occursin(` y las que llevan backticks |

Además, se corrigió una **inconsistencia heredada de `P-PRESTAMO`** al leerla (su texto define `g` con
`β_d` sin abandonar la pública, su tabla de §2.3 publica otra frontera), ya documentada por `P-CLAVE`
O7. Este informe usa la del **texto** (`β_d > 1 − 2α`), que es la del `PROMPT.md` §2.2, y **no
modificó ningún fichero de `P-ZRX/P-PRESTAMO/`**.

---

## 5 · Resultados

**Verificación.** `resultados/TEST.log`: **863 controles, 0 fallos** con 1 hilo y `--check-bounds=yes`.
Ninguna vía se contrasta consigo misma: la primitiva cerrada de `Φ` contra sumas de Riemann con cotas
por monotonía; el MC contra `Φ` con IC de Wilson y t; el avaricioso de reclutamiento contra fuerza
bruta (201 filas: 48 aleatorias no óptimas + el contraejemplo construido) y contra el exacto de dos niveles; la dicotomía con dos expresiones distintas.

**Artefactos** (17 TSV + 5 bitácoras) en `resultados/`: `F1-variantes`, `F2a-igual-espacio`,
`F2c-tau-minimo`, `F2d-coste-vias`, `F3a-particion` (504 filas), `F3b-rotacion`, `F3c-revive`,
`F4a-regresividad`, `F4b-dicotomia`, `F4c-tope`, `F5a-unidad`, `F5b-computo`, `F5c-recurrencia`,
`F6-veredicto`, `V1-pareto-riemann`, `V2-mc-exacto`, `V3-reclutamiento`, más `TEST.log`,
`CORRIDA.log`, `BENCH.txt`, `BENCH-tabla.tsv`, `ESCALADO.tsv`.

**Hallazgos centrales** (todos en `INFORME.md`, con etiqueta):

1. **La tasa no toca el doble farmeo** (una identidad, dos ramas, coste de identidad 0) y **es inerte
   sin `κ`**: `f_detenida = 0` para todo `τ` si `κq = 0`. `demostrado`, exacto.
2. **`τ_min ∝ f*`**: la tasa que protege el umbral es proporcional al tamaño de la granja marginal;
   con dispersión extrema la granja pequeña paga `5,15·10⁵` veces su ingreso y la industrial `1`.
3. **Dicotomía exacta: «partir cuesta» ⟺ «es regresiva».** No es una disyuntiva de diseño, es una
   identidad; la única cuota no regresiva es proporcional al espacio (la variante (a), prohibida).
4. **El tope por identidad convierte la tasa en (a) disfrazada** (`τ·⌈f/S_max⌉ ≈ (τ/S_max)·f`) y
   **rompe** la propiedad de partición en los saltos (filas de `F4b-dicotomia.tsv` donde
   `parte_mas_caro = no` y `carga_decrece = si` a la vez, imposible para un `φ` continuo).
5. **`κ = 0` no lo cierra nada de lo que hay aquí, ni la tasa.**

**Rendimiento.** Régimen `Float64` tipoestable: `0 B` de asignación en los kernels calientes, `Φ`
cerrada en la rejilla de 10⁴ a `0,153 ms`, oráculo de Riemann a `1,185 ms`, MC ×3,75 a 4 hilos con
resultado **bit a bit idéntico**. `@code_warntype`: `Body::Float64` sin `Any`. **JET 0.12.1: 0
diagnósticos** en los cinco kernels. Sin `@fastmath`, sin `@turbo`, sin `Float32`. **Configuración
conservada: 4 hilos** (tope del encargo; el escalado `1 → 2 → 4` da `×1,92` y `×3,52`).

---

## 6 · Salida (PROMPT §5)

```text
$ LC_ALL=C sha256sum -c P-ZRX/P-TASA/ENTRADA.sha256
P-ZRX/P-TASA/PROMPT.md: OK

$ git -C /home/katana/zeo/ZEROX status --short
 M Cargo.lock
 M Cargo.toml
 M MIGRACION.md
 M P-ZRX/PROPUESTAS-VIABLES.md
 M README.md
 M SPEC.md
 M TAREAS.md
 M ci/consenso-pendiente.txt
 M ci/frontera-crates.sh
 M ci/reglas-sin-cablear.txt
 M ci/reglas-sin-codigo.txt
 M crates/zx-consensus/Cargo.toml
 M crates/zx-consensus/src/bloque_dag.rs
 M crates/zx-consensus/src/error.rs
 M crates/zx-consensus/src/ghostdag.rs
 M crates/zx-consensus/src/lib.rs
 M crates/zx-consensus/tests/ghostdag_bench.rs
 M crates/zx-consensus/tests/ghostdag_oraculo.rs
 M crates/zx-consensus/tests/ghostdag_prop.rs
 M crates/zx-consensus/tests/ghostdag_rust.rs
?? P-ZRX/P-ANCESTRIA/
?? P-ZRX/P-COBERTURA/
?? P-ZRX/P-LATENCIA/
?? P-ZRX/P-TASA/
?? crates/zx-consensus/src/pot.rs
?? crates/zx-consensus/tests/pot_derivaciones.rs
?? crates/zx-consensus/tests/pot_slot.rs
?? crates/zx-pot/

$ date
mié 23 sep 2026 17:59:34 CEST
$ uptime
 17:59:34  up 15 days 14:28,  0 users,  carga promedio: 2,01, 1,95, 1,60
```

**Comparación con la entrada:** `PROMPT.md` sigue `OK` (no se tocó). Los `M` y `??` que aparecen son
**los mismos de la entrada** más `crates/zx-consensus/tests/pot_derivaciones.rs`, **añadido por el otro
encargo durante la sesión**. La única línea nueva atribuible a este trabajo es `?? P-ZRX/P-TASA/`.
**No se editó ni se movió nada** de `SPEC.md`, `TAREAS.md`, `ci/`, `crates/`, `prototipos/`,
`research/`, `veritas/`, `PDF/` ni del resto de `P-ZRX/`. `PROMPT.md` y `ENTRADA.sha256` quedaron
intactos.

---

## 7 · Qué queda abierto (para que nadie lo redescubra)

- **La distribución real de tamaños de granja** (H1). Es lo único que cambiaría la **magnitud** de la
  regresividad; no cambia el teorema.
- **Una fuente de `κq > 0`** contra claves pobres y nuevas: sin ella, la exclusividad no existe y la
  tasa no tiene nada que habilitar. Es el bloqueo que `P-CLAVE` F6 dejó y **este encargo no mueve**.
- **`κ = 0`** (publicar sólo la rama ganadora). **No lo cierra nada de lo que hay aquí.**
- **El coste real de un ASIC de identidades** (variante en cómputo): no medido; la evaluación de §5.2
  es cualitativa en ese punto.
- **Los precedentes externos** (colateral de Filecoin, mecanismos anti-Sybil con coste de identidad):
  **no abiertos**, etiquetados `no verificado`. No se inventan citas.
