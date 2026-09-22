# CRP-v0.3 · REVISIÓN-JULIA

> **Revisión independiente, en contexto nuevo.** Efectuada por un revisor que no participó en la
> redacción del instrumento y que no leyó los demás dictámenes antes de concluir. No se modificó
> código fuente, `SPEC.md`, `TAREAS.md` ni `ENTRADA.md`. Alcance: Julia y numerismo. Fecha:
> 2026-09-18. Julia 1.13.0, CPU `znver5`.

---

## 1 · Alcance

Revisión de `deepseek/veritas/seguridad/coste-rama-privada-v3/` contra `veritas/LINEO.md` y las
correcciones del encargo v0.3, con foco en:

1. Red: autor-inmediato, `Δ=0` real, drenaje terminal simétrico y ausencia de rojos por latencia de
   un único productor (`src/dag_sim.jl`). ¿Referencia algún hijo a un padre no añadido a GDR?
2. R-FIN-5 sobre **todo** `past(B)` en `_anadir_bloque!`; uso de `PotOrigin`/prefijo en `slot(X)`.
3. Oportunidades compartidas y controles de correlación (`:perfecta`/`:iid`/`:derivada`).
4. `η_h`/`η_a` medidos por separado; honestidad de la salida con cero rojos.
5. Higiene LINEO: tipos, asignaciones, determinismo, sin `@fastmath`. Reproducción de los dos
   comandos exigidos.
6. Contraste de `resultados/` con `INFORME.md`.

**Fuera de alcance:** la matemática de probabilidad de `P_terminal`/`P_first_passage`/`α_prob`
(revisión matemática separada), el coloreo GHOSTDAG/GDR y la semántica Rust (revisión Rust), el
cierre del umbral protocolario y la idoneidad normativa de R-FIN-5.

**Hasches (SHA-256) del material revisado**

```
src/dag_sim.jl      c06f93599b3372a2272810f7e64540c5dfa5ba2e8488e71872dcbcdd00aef8c2
src/flujo.jl        e1c342276faf6c9525209ba17499773adc904b807f6a54c50c662be7597df785
src/eventos.jl      6beecb1204ac5e881512d52566dd7fbb4ff407ed6db66d44b026b5b678dfce9f
src/dp.jl           02a8bda35860f97db3d356fbf07bcf3bd296ca4f93c3c524e55043d5523d6431
src/validacion.jl   c468089317c1abbbd906d11be3ffa8f613d7c1ff5ec0958adfc17ec07e09f33a
src/CosteRamaPrivadaV3.jl ddd50632ccb24ce4dc2a95b93aa5292d1d94571a3f41b75f2120f276fbf42ecf
test/runtests.jl    92240c671ab79c6c7e0546bcb7076ccf5b750334f8595123cb918d1310562d6e
run.jl              c6c98d58807fe030f96e293defa62216f1d6baac5d7d4d0cbab8a88365c1fa63
ENTRADA.md          a8912ba5d8d48ae71685b3ea471d7166df74bebc4f17bd609c4182c1e8795c45
```

---

## 2 · Método

1. Lectura íntegra de `veritas/LINEO.md`, `ENTRADA.md`, `CONTRATO.md`, `MODELO.md`, `METODO.md`,
   `MATRIZ-AUTORIDAD.md`, `MATRIZ-VALIDEZ.md`, `INFORME.md` y todo `src/`, `test/`, `run.jl`,
   `bench/`.
2. Comprobación de la entrada congelada: `sha256sum` de `ENTRADA.md` y del encargo; `cmp`
   byte a byte ⇒ **IDÉNTICOS**. `ENCARGO.sha256` coincide.
3. Reproducción de los comandos exigidos:

   ```bash
   env -u LD_LIBRARY_PATH julia --check-bounds=yes --project=. test/runtests.jl
   env -u LD_LIBRARY_PATH julia --project=. run.jl --seed 0x5a5a --replicas 24
   ```

4. Reproducción adicional con `--threads=4` para comprobar determinismo bajo hilos.
5. Verificación de artefactos por `diff` byte a byte contra una copia previa de `resultados/`
   (salvo `ENTORNO.txt`, que incluye fecha/hilos).
6. Sondas Julia en `/tmp/opencode` (sin tocar el proyecto) para confirmar casos límite:
   rechazo R-FIN-5, conteo de motivos de rechazo GDR, ramas muertas, efecto de incluir génesis en
   `η`. Se restauró `resultados/` a su estado original tras las corridas.

**Resultado de la reproducción**

- Suites: **76/76**, 4.4 s, con `--check-bounds=yes`. Coincide con `resultados/TESTS.txt`.
- `run.jl` regenera `EVENTOS`, `SWEEP-TOY`, `SWEEP-DAG`, `VARIOS`, `CORRELACION`, `U2U3`, `ETA`,
  `VEREDICTO` **byte a byte idénticos** a los originales; solo difiere `ENTORNO.txt` (fecha).
- Con `--threads=4` los mismos ficheros salen idénticos ⇒ determinismo 1 hilo ≡ 4 hilos.
- Sonda R-FIN-5: bloque adversario sobre ancestro común ⇒ `:valido`; sobre público ya divergido ⇒
  `(0, :invalido_rfin5)`. Correcto.

---

## 3 · Hallazgos

Severidad: **Alta** (bloquea), **Media** (sesgo/corrección de afirmación), **Baja** (precisión),
**Info**.

### H1 · Media — `s_max=150` trunca ramas adversarias en α bajo y el rechazo no se registra

`SimboloDAG(; k=k, s_max=150, …)` (`src/dag_sim.jl:79`). GDR rechaza un bloque si
`slot - slots[sp] > s_max` (GDR `referencia.jl:180-183`). La rama adversaria se ancla en
`raices[s]`, congelada en `t_fork` (`src/dag_sim.jl:284-287`), y solo produce en oportunidades.
Si su **primera** oportunidad cae en `slot > 150`, la rama no nace; `_anadir_bloque!` devuelve
`(0, :gdr)` (`src/dag_sim.jl:171`) y el llamador **ignora el estado**, de modo que el rechazo no
se cuenta ni se reporta.

Medición propia (24 réplicas, S=16, α=0.01, T=200, k=30, `:derivada`): 80/384 ramas con
`W_priv_terminal = 0`; 48 son de "cero oportunidades" (física) y ~32 por `salto_mayor_smax`
(49 rechazos contados). Es decir, a α=0.01 el instrumento descarta ~10 % de las ramas con
oportunidad por una regla de red no declarada.

Efecto: subestima `W_priv` del adversario (dirección conservadora para una conclusión de
seguridad), pero **sesga las celdas de α bajo** del barrido y no está documentado en `INFORME.md`
ni en `MODELO.md`. Recomendación: contar y publicar los rechazos GDR, y justificar `s_max` o
limitar el horizonte para que no trunque.

### H2 · Media — "R-FIN-5 (máximo) da ~0 para α<1/2" no lo sostienen los datos del propio informe

`INFORME.md:22` y `INFORME.md:74` afirman `~0` para `α<1/2`. `resultados/SWEEP-DAG.txt` muestra lo
contrario en el borde:

| S | α | terminal | primera pasada |
|---:|---:|---:|---:|
| 1 | 0.48 | 9/24 | 23/24 |
| 2 | 0.45 | 2/24 | 24/24 |
| 4 | 0.45 | 4/24 | 24/24 |

Con R-FIN-5 = máximo, el umbral de **deriva** de una rama es `α = 1/2` (no `1/(S+1)`), pero la
probabilidad de **primera pasada en horizonte finito** es muy apreciable cerca de `1/2`. La frase
correcta es "la deriva media por rama es negativa para `α<1/2`, y el máximo no suma ramas"; no
"probabilidad ~0". Es una imprecisión de la conclusión ejecutiva, no un defecto del código.

### H3 · Media-baja — falta la comprobación separada del horizonte futuro de la prueba

El encargo §3.3/D7 pide registrar "slot **y horizonte** de la justificación" y una comprobación
**separada** del horizonte futuro, aparte del prefijo en `slot(X)`. `DescriptorFlujo`
(`src/flujo.jl:12-21`) no lleva slot/horizonte de justificación y `compatible_rfin5`
(`src/flujo.jl:39-45`) solo compara el prefijo hasta `slot_X`. `proxima_inyeccion`
(`src/flujo.jl:69`) y `primera_divergencia` (`src/flujo.jl:78`) están definidas pero **nunca se
usan** (código muerto). `INFORME.md` no declara esta ausencia como pendiente; `CONTRATO.md` §2.2
solo promete "R-FIN-5 sobre todo `past(B)`". No invalida lo entregado, pero es un requisito del
encargo no cubierto.

### H4 · Baja — el atajo `flujo_id` igual ⇒ `VALIDA` salta prefijo y `N(s)`

`src/flujo.jl:40`: `flujo_id` igual y autenticado devuelve `VALIDA` sin comparar prefijos. Si dos
descriptores compartieran `flujo_id` pero difirieran en `PotOrigin`/`N_efectivo` (reconfiguración
de `N(s)`), se aceptarían. En este instrumento `N` es constante y `flujo_id` es único por rama, así
que no se dispara; es una brecha latente frente al requisito D7 de ordenar `(slot, entropía,
N_efectivo)`.

### H5 · Baja — `η` incluye génesis y bloques pre-fork

`_eta_rama` (`src/dag_sim.jl:226-238`) usa como denominador **todos** los bloques válidos del lado,
sin excluir el prefijo común. El encargo D6 pide "excluye el prefijo común" y "post-fork". Medido
en una corrida S=4 α=0.2 T=200: incluir génesis da `η_h = 0.994253`; excluirlo más el pre-fork da
`0.994186`. Diferencia inmaterial, pero la definición no es la declarada.

### H6 · Baja — "drenaje terminal simétrico" implementado, pero sin efecto observado

`_drenar_todo!` (`src/dag_sim.jl:204-210`) llena `sim.vista`, pero `W_pub`, `W_priv`, conteo de
rojos y `_decisiones` leen el estado de GDR y `sim.bloques`, no `vista`. El drenaje terminal no
cambia ninguna cifra publicada y **ningún test lo cubre**. `INFORME.md:20` lo cita como "medido"
junto con Δ=0; la cobertura real de los tests es autor-inmediato, Δ=0 y único productor.

### H7 · Baja — `alpha_prob_simultaneo`, cota superior siempre `= maximum(alphas)`

`src/eventos.jl:84-87`: en el caso `:solo_cota_superior`, `b = a_low + (maximum(alphas) - a_low)`
salvo cuando `a_low == -Inf`, donde `b = maximum(alphas)`. En ambos casos `b == maximum(alphas)`.
No es un error de corrección (la celda 0/n no se llama frontera), pero la fórmula es un no-op.

### H8 · Baja — citas de evidencia desalineadas en `INFORME.md`

- Fila "Fusión público+rama divergente" cita `SWEEP-DAG.txt` (`INFORME.md:17`); ese fichero no
  contiene información de fusión; la prueba está en `test/runtests.jl:91-93`.
- Fila "`iid` … reproduce `1−E[F^S]`" cita `CORRELACION.txt` (`INFORME.md:18`); ese fichero solo
  muestra nº de `W_priv` distintos y `η`; la identidad se comprueba en `test/runtests.jl:111-115`.
- Fila "`Δ=0` real y drenaje terminal" cita tests (`INFORME.md:20`); ver H6.

### H9 · Info — `η_a ≡ 1` por construcción; la curva con rojos no es solo "sin muestra"

La rama adversaria es una cadena que construye sobre todas sus puntas
(`src/dag_sim.jl:289-303`), de modo que **ningún bloque adversario es rojo en su propio contexto**;
`η_a = 1.0` en todas las réplicas (`ETA.txt`, `CORRELACION.txt`). El `INFORME.md` lo declara
"inconcluso" con honestidad, pero conviene explicitar que el diseño no genera rojos adversarios en
su propia rama. Además, `rojos` se cuenta como **unión de contextos** (`src/dag_sim.jl:343-351`),
no por contexto, así que un bloque azul en la punta elegida y rojo en otra se cuenta como rojo.

### H10 · Baja — mutation testing solicitado no implementado

El encargo §4 exige mutation tests que fallen al cambiar `>` por `≥`, suma por máximo, color
global, aceptación post-divergencia incompatible o renormalización de masa truncada. El testset
"mutación: > vs ≥ y máximo vs suma" (`test/runtests.jl:181-186`) solo compara dos valores y
`cota_union`; no muta código. Queda sin verificar esa parte.

### H11 · Baja — `α_prob` simultáneo agrupa celdas de distinto `S`

`run.jl:79-96` acumula `alphaS`/`exmax` de todos los `S` con `α` duplicados y `exitos` distintos;
el resultado es `:indefinida` (`SWEEP-DAG.txt:51`). Se declara honestamente, pero `α_prob` debería
calcularse por escenario `S` fijo.

### H12 · Info — residuos de "v0.2" y entregables de revisión

`MATRIZ-AUTORIDAD.md` e `HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md` conservan encabezado "CRP-v0.2"
y su tratamiento "en v2". `REVISION-RUST.md` apareció en paralelo durante esta revisión;
`REVISION-MATEMATICA.md` no existía al cerrarla. Fuera del alcance Julia.

---

## 4 · Respuestas directas a lo preguntado

1. **Red.** Autor-inmediato: correcto (`src/dag_sim.jl:277`). `Δ=0` real: correcto
   (`src/dag_sim.jl:304-306`, drena en el mismo slot tras producir, de modo que la concurrencia
   intra-slot se conserva y la entrega se completa al cerrar el slot). Único productor: al autor
   como máximo un bloque por slot y construir sobre sus propias puntas, la cadena no tiene
   anticonos ⇒ 0 rojos para `Δ∈{0,1,5}`; confirmado por tests y por razonamiento. **¿Hijo referencia
   padre no añadido a GDR? No.** Un bloque solo entra en `sim.bloques`/vistas tras `agregar!`
   correcto; las entregas transportan solo ids aceptados y los padres se eligen de
   `sim.bloques`/`vista`. No hubo `BoundsError` con `--check-bounds=yes` ni motivos de padre
   inexistente. El único rechazo GDR observado fue `:salto_mayor_smax` (H1).
2. **R-FIN-5.** Se aplica en `_anadir_bloque!` sobre **todo** el pasado estricto y **antes** de GDR
   (`src/dag_sim.jl:157-164`), con prefijo comparado en `slot(X)` (`src/flujo.jl:30-45`). El uso de
   `PotOrigin` es coherente: se comparte antes del fork y diverge en la entropía posterior
   (`src/flujo.jl:52-66`). Verificado con sonda. Reservas H3 y H4.
3. **`S` flujos.** Los tres modos hacen lo que dicen (`src/dag_sim.jl:99-113`): `:perfecta` idéntico
   por slot, `:iid` independiente, `:derivada` base común desplazada. La generación es conjunta
   (una sola matriz `oportunidades`) y reproducible con semilla fija; `run.jl` la reproduce byte a
   byte con 1 y 4 hilos.
4. **`η_h`/`η_a`.** Se miden por separado (`src/dag_sim.jl:226-238`, `353-354`). Con 0 rojos el
   informe es honesto: declara la curva con rojos **inconclusa** y no supone `η_h=η_a`. Reservas
   H5 y H9.
5. **Higiene LINEO.** Sin `@fastmath`, `@simd`, `@inbounds`, `@turbo`, `Any` ni `@threads`. Tipos
   concretos y sin globales mutables. Tests y `run.jl` reproducen exactamente. Reservas: sin
   perfilado/JET/`@allocated` en esta pasada, sin escalado (no hay paralelismo).
6. **Contraste `resultados/`/`INFORME.md`.** Coinciden en las cifras clave (EVENTOS, SWEEP-DAG,
   CORRELACION, ETA, U2U3, VEREDICTO). Discrepancias: H2 (frase "~0") y H8 (citas de evidencia).

---

## 5 · No verificado

- `bench/benchmarks.jl` y `bench/io_lectura.jl`: no se reran en esta pasada; sus cifras
  (`BENCH.txt`, `IO.txt`) no se validaron aquí.
- Perfilado (`@code_warntype`, JET, `@allocated`) y escalado `1…24`: no ejecutados (instrumento
  serial, sin paralelismo).
- Matemática de `P_terminal`/`P_first_passage`/`α_prob` y de la DP: fuera de alcance (revisión
  matemática independiente).
- Coloreo GHOSTDAG/GDR y semántica Rust/upstream: fuera de alcance (revisión Rust).
- Cierre del umbral protocolario y reglas pendientes (controlador C-HDR-06, R-FIN-7/`F`, C-GD-11,
  PoT AES, `S_adversario`): no se cierran; el propio INFORME los deja pendientes.

---

## 6 · Veredicto

**Apto con observaciones (no bloqueante).** La implementación codifica fielmente las correcciones
de red, R-FIN-5 sobre todo `past(B)`, oportunidades compartidas, separación de `η` e higiene
LINEO; las suites pasan 76/76 y todo `resultados/` se reproduce byte a byte de forma determinista
(1 y 4 hilos). No se halló defecto de corrección Julia/numerismo que invalide las cifras.

Deben corregirse antes de dar el instrumento por cerrado:
- **H1 (Media):** declarar y contabilizar la truncación por `s_max` (sesga α bajo).
- **H2 (Media):** reescribir la frase "R-FIN-5 da ~0 para α<1/2" (la deriva es negativa, la
  probabilidad finita no es ~0).
- **H3 (Media-baja):** declarar como pendiente el horizonte futuro de la prueba si no se implementa.

El veredicto global del informe —**"Frontera medida para los escenarios ensayados; umbral
protocolario inconcluso"**— es coherente con `resultados/` y con las reglas pendientes. Esta
revisión no lo promociona ni lo cierra.
