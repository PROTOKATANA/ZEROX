# PROGRESO — P-COBERTURA

Bitácora del encargo `P-ZRX/P-COBERTURA/PROMPT.md`. Ejecutado el **2026-09-22**, de
23:32 a 23:53 CEST. Zona de escritura: **solo `P-ZRX/P-COBERTURA/investigacion/`**.

---

## §0 · Objeciones al encargo, declaradas antes de ejecutar el instrumento

Formuladas al leer `PROMPT.md` y antes de escribir o correr el instrumento (el
reconocimiento del repositorio empezó a las 23:32 y la primera línea de código se escribió
después de leer `LINEO.md`, `P-PERMANENCIA`, `P-SEMBRADOR`, `P-CLAVE`, `P-REVELACION`,
`P-ADELANTO`, `T-ZRX` y el código del formato). **No cambian ninguna respuesta; ordenan la
lectura de F2.**

- **O1 · «Salvo que (i)-(iv)» hace casi todo el trabajo y el encargo no lo dice.** (i), (ii) y
  (iii) son condiciones **cuantitativas sobre hardware y ventana**, no propiedades que la
  prueba pueda imponer. Con el modelo de amenaza obligatorio, no cierran por principio: sólo
  encarecen. Sólo (iv) rompe la hipótesis estructural. → `INFORME.md` §0.1 y §3.2 (Corolario 3).
- **O2 · «Para el formato fijado y sin cambiarlo» debe leerse en las dos direcciones.** Si F2
  es «no puede existir», la pregunta útil pasa a ser «¿qué es lo máximo comprometible?» (F6).
  Subrayado para que F2 no se lea como «seguir buscando».
- **O3 · La vía (iii) no está respaldada por el PDF que el encargo manda abrir.**
  `T·S² ∈ Ω(ε²N²)` es una cota de **trabajo agregado**, no de latencia, y el modelo no postula
  no-paralelizabilidad ni obliga a materializar `N` a la vez. Y la generalización a `k` tablas
  está «anunciada, no probada» (`research/time-memory-tradeoff.md:63-77`). → `INFORME.md` §4.3.
- **O4 · Una entrada de §1.3 tiene la etiqueta imprecisa.** `t_tabla` es **s/tabla**, no
  «s/pieza»; coincide numéricamente porque hay una tabla-objeto por pieza. Y `r = 25,03` viene
  de la ruta **paralela**, mientras la no paralela tiene un SIGSEGV reproducible
  (`P-ZRX/P-INTENTO/investigacion/mediciones/fallo-semilla.md:14-17,78-87`). No se re-mide;
  se declara. → `INFORME.md` §1.1 y `HIPOTESIS-...md` H5.

**Tarea de consistencia obligatoria del encargo §1.3 — RESUELTA.** `235,6 h·núcleo/TiB` es
**trabajo** (`N·t_tabla`); `5,84 «CPU»/TiB` es una **tasa de máquinas** (`N/(r·w)`). El factor
exacto es **`r·t = 20,249270`**; el cociente ingenuo `40,357920` mezcla unidades; **no entra
ningún factor 7 ni `NUM_CHUNKS = 2¹⁵`**. Ninguna de las dos cifras es errónea: son etiquetas
(«16 núcleos» → piscina de 24 hilos; «CPU» = máquina completa). Reproducido en
`resultados/F4-reconciliacion.tsv`. → `INFORME.md` §1.1.

---

## §1 · Comprobaciones de ENTRADA (desde la raíz `/home/katana/zeo/ZEROX`)

```text
$ LC_ALL=C sha256sum -c P-ZRX/P-COBERTURA/ENTRADA.sha256
P-ZRX/P-COBERTURA/PROMPT.md: OK
```

```text
$ git -C /home/katana/zeo/ZEROX status --short
 M Cargo.lock
 M Cargo.toml
 M MIGRACION.md
 M P-ZRX/PROPUESTAS-VIABLES.md
 M SPEC.md
 M TAREAS.md
 M ci/consenso-pendiente.txt
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
?? crates/zx-pot/
```

```text
$ date && uptime
mar 22 sep 2026 23:32:20 CEST
 23:32:20  up 14 days 20:01,  0 users,  carga promedio: 1,60, 1,21, 1,22
```

Ninguna de las modificaciones listadas es de este encargo: **al empezar no existía ni un
fichero dentro de `P-ZRX/P-COBERTURA/` salvo `PROMPT.md` y `ENTRADA.sha256`.**

## §2 · `uptime` antes de cada benchmark

Exigido por el encargo. Ninguna corrida compite con carga apreciable; la máquina tiene 32
hilos lógicos y el encargo impone **4**.

| Hora | Carga (1/5/15 min) | Qué se midió |
|---|---|---|
| 23:32:20 | 1,60 / 1,21 / 1,22 | comprobación de entrada |
| 23:44:03 | 1,72 / 1,82 / 1,56 | primer `run.jl` (barridos) |
| 23:45:52 | 1,65 / 1,81 / 1,59 | `correr-modelo.sh` (tests + barridos + bench) |
| 23:47:17 | 2,01 / 1,91 / 1,65 | resumen de validación |
| 23:49:04 | 2,15 / 1,98 / 1,70 | corrida final |
| 23:53:15 | 1,27 / 1,70 / 1,66 | comprobación de salida |

## §3 · Bitácora

**23:32–23:36 · Reconocimiento y lecturas.** `LINEO.md` entero; `P-PERMANENCIA` entero
(INFORME, CANDIDATA §1, instrumento); `P-SEMBRADOR`; `P-CLAVE`; `P-INTENTO`; `P-REVELACION`;
`P-ADELANTO`; `T-ZRX/SOLUCION-CANDIDATA-REUTILIZACION.md`; `research/README.md`;
`research/time-memory-tradeoff.md`; `research/chia-parcelas-comprimidas.md`. Verificación de
los hechos de §1.1 del encargo **abriendo los ficheros citados uno a uno** en
`PDF/autonomys-subspace/` (11 hechos; confirmados, con dos correcciones de ruta:
`solutions.rs` está en `crates/subspace-core-primitives/src/`, y `K = 20` está en
`crates/subspace-core-primitives/src/pos.rs:103`, no en `shared/ab-proof-of-space`).
Esquemas externos: Filecoin PoRep/PoSt (especificación), Spacemesh ATX/ni-post, Chia
(clon local + greenpaper), y `PDF/time-memory-tre-off-proof-space.pdf` extraído a texto.

**23:36–23:40 · Análisis previo al código.** Modelo del juego regeneración↔auditoría;
derivación de la frontera `P(X>B)=0 ⟺ M≤B ó k≤B`; identificación de la simulación como
núcleo del teorema de F2; detección de que `φ_libre` estaba mal nombrado (es el
**almacenamiento forzado**).

**23:40–23:44 · Instrumento.** `cobertura-parcela-v1`: `Project.toml` + `Manifest.toml`
(instanciado en 1 m 15 s), `modelo.jl`, `referencia.jl`, `rapido.jl`, `validacion.jl`,
`test/runtests.jl`, `bench/benchmarks.jl`, `run.jl`, `correr-modelo.sh`,
`mediciones/hardware.tsv`.

**23:44–23:53 · Corridas.** Tests: **11 833 comprobaciones, 0 fallos, 0 errores** (perfil de
referencia con `--check-bounds=yes`, 4 hilos, 2,6 s). Barridos: 6 `.tsv` (luego 7 con
`F5-registro.tsv`). Benchmarks: `0,181 ms` y **0 asignaciones** por barrido de 64 celdas;
`Profile` atribuye el tiempo a `rapido.jl:72` y `exp`. JET: 68/68 definiciones de nivel
superior analizadas, sin errores. Corrida completa: **≈ 90 s** de pared, muy por debajo del
presupuesto declarado (2 h).

**23:53 · Cierre.** `sha256sum -c` (OK), `git status --short`, `date`, documentación.

**Nota de presupuesto de disco, declarada.** El presupuesto declarado era **256 MiB**. Los
artefactos de cálculo ocupan **240 KB** (`resultados/` + fuentes + `Manifest.toml`). La
instanciación del entorno creó además un depósito de paquetes de Julia en
`investigacion/.julia-depot` de **298 MB**, casi todo caché de precompilación: **supera el
presupuesto declarado**. Se ha **retirado del entregable** y se ha **verificado** que
`correr-modelo.sh` lo recrea y que `using CoberturaParcela` funciona tras borrarlo (23 s). La
primera corrida tarda ≈ 2 min en vez de ≈ 90 s. No es un agotamiento del presupuesto de
cálculo: el encargo no se quedó sin tiempo ni sin memoria en ningún momento.

## §4 · Defectos propios encontrados y corregidos

Documentarlos es parte del encargo. Los cuatro primeros se descubrieron **porque los tests
fallaron**, no por inspección.

1. **Término base del encierre con redondeo dirigido.** Cuando el soporte de la
   hipergeométrica no empieza en 0 (`j0 = k − (N − M) > 0`), la fórmula de `P(X = j0)` que
   había escrito omitía el factor `C(k, j0)`. Daba **48 fallos** en el testset «el encierre
   contiene la referencia exacta». Corregido factorizando `C(k,j0)` como producto de
   racionales positivos. Verificado: 1 200 casos con el encierro conteniendo el valor exacto.
2. **Clopper–Pearson invertido y bisección con el sentido equivocado.** Las dos colas estaban
   intercambiadas y `_biseccion_cdf` trataba la CDF binomial como creciente cuando es
   **decreciente** en `p`. Síntoma: `CP(3,10) = (1,0000, 3,8·10⁻³⁷)`. Corregido y validado
   contra cuatro valores publicados (`0,0667–0,6525` para 3/10; `0–0,3085` para 0/10;
   `0,6915–1` para 10/10; `0,0126–0,9874` para 1/2).
3. **Nombre engañoso `phi_libre`.** La cantidad `1 − B/N` es la fracción que **hay que
   almacenar**, no la que se puede omitir. Renombrada a `almacenamiento_forzado`, y
   `ahorro_maximo = min(1, B/N)` para la otra. Un nombre que invierte el significado de un
   resultado es un defecto, no un detalle.
4. **Artefacto del espacio logarítmico.** El kernel `Float64` podía dar `1,0000000155 > 1` al
   sumar `exp(log pmf)`. Recortado a 1 con el supuesto documentado y añadido un test de
   invariante `0 ≤ p ≤ 1` sobre una rejilla de 1 000 celdas. El recorte **no puede** cambiar
   un veredicto (no convierte 0 en positivo).
5. **Firma de tipo demasiado estrecha.** `T_para_beta_exacta(::Rational{BigInt}, ::Rational{BigInt})`
   rechazaba `1//1000` (que es `Rational{Int}`). Relajada a `::Rational` con conversión
   interna. Síntoma: 4 errores en el testset de bordes.
6. **Expectativas de tres tests mal fijadas por mí** (no del instrumento): el valor de
   `almacenamiento_forzado` con `B` entero en vez de fraccionario; la dirección de la
   dependencia con `N`; y el cruce con `factor_gpu` (que no es lineal en `w` cuando `D_a > 0`).

**Dos defectos de las fuentes heredadas, no re-midieron y no se corrigieron** (se declaran):
la etiqueta `s/pieza` y «16 núcleos físicos» de `P-PERMANENCIA/.../mediciones/hardware.tsv`,
y el `w_cruce_PiB_slots` inflado ×1,0995 (`run.jl:255` de P-PERMANENCIA), más filas duplicadas
en `E3-ventana.tsv`.

## §5 · Comprobaciones de SALIDA (desde la raíz)

```text
$ LC_ALL=C sha256sum -c P-ZRX/P-COBERTURA/ENTRADA.sha256
P-ZRX/P-COBERTURA/PROMPT.md: OK
```

```text
$ git -C /home/katana/zeo/ZEROX status --short -- P-ZRX/P-COBERTURA
?? P-ZRX/P-COBERTURA/
```

```text
$ git -C /home/katana/zeo/ZEROX status --short   # (todo el repositorio)
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
?? crates/zx-consensus/src/pot.rs
?? crates/zx-consensus/tests/pot_slot.rs
?? crates/zx-pot/
```

```text
$ date && uptime
mar 22 sep 2026 23:53:15 CEST
 23:53:15  up 14 days 20:22,  0 users,  carga promedio: 1,27, 1,70, 1,66
```

**Diferencia entre la entrada y la salida, declarada:** entre las 23:32 y las 23:53 aparecieron
` M README.md`, ` M ci/frontera-crates.sh`, `?? crates/zx-consensus/src/pot.rs` y
`?? crates/zx-consensus/tests/pot_slot.rs`, que **no existían al empezar**. **No son de este
encargo**: todo lo escrito aquí está bajo `P-ZRX/P-COBERTURA/investigacion/` y se comprueba
con `git status --short -- P-ZRX/P-COBERTURA`, que sólo muestra el directorio como no
rastreado. Hay **actividad concurrente** en el repositorio, fuera de la zona de escritura de
este encargo.

## §6 · Entregables

```text
P-ZRX/P-COBERTURA/investigacion/
├── INFORME.md                     (primera línea = respuesta a F2; F1-F6 en orden)
├── DECISIONES-PENDIENTES.md
├── PROGRESO.md
└── veritas/criptografia/cobertura-parcela-v1/
    ├── INFORME.md · HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md
    ├── Project.toml · Manifest.toml · julia-version.toml
    ├── src/{CoberturaParcela,modelo,referencia,rapido,validacion}.jl
    ├── test/runtests.jl · bench/benchmarks.jl · run.jl · correr-modelo.sh
    ├── mediciones/hardware.tsv
    └── resultados/{F4-frontera,F4-coste,F4-reconciliacion,F3-deteccion,
                    F3-exacto-racional,certificado,F5-registro}.tsv
                   + VALIDACION.txt · BENCH.txt · JET.txt · TEST.txt · RUN.txt
```

## §7 · Estado

**Completo.** No queda ninguna parte del encargo sin responder; lo que no se ha podido
determinar está en «Lo que esta investigación NO resuelve» con su etiqueta. El presupuesto no
se agotó y no hubo ningún fallo reproducible pendiente.
