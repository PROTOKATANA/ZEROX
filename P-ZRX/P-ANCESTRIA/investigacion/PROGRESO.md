# PROGRESO — P-ANCESTRIA / ANR-v0.1

Bitácora del encargo `P-ZRX/P-ANCESTRIA/PROMPT.md`. Zona de escritura:
`P-ZRX/P-ANCESTRIA/investigacion/` (solo). Instrumento:
`veritas/consenso/ancestria-reto-v1/`.

---

## 1 · Lo que me parece equivocado del encargo, dicho ANTES de empezar

El encargo ordena (§8) declarar esto en la primera respuesta y aquí. Son tres cosas, y la primera
es la que decide el resultado.

**(A) La premisa «`d = ∞` = el flujo de hoy ⇒ transferibilidad sin límite» no se sigue de las
reglas escritas.** El encargo (§2.2) presenta los extremos como «`d = 0`: el padre; `d = ∞`: solo el
flujo, que es lo de hoy» y atribuye al segundo «cero grinding» y «dos ramas del mismo flujo
comparten reto». Leídas `C-FLU-03`, `C-FLU-04`, `C-FLU-10`, `C-FLU-12` y `C-FLU-21`, el flujo **sí**
separa ramas, y lo hace a una profundidad finita: `V_j(B)` corta en `T_j + L_slots`, así que toda
divergencia anterior a ese corte cambia `I_j`, cambia `entropía_j` y cambia el flujo. El diseño de
hoy **no está en el extremo `d = ∞`: está en un punto interior**, con profundidad de anclaje medida
en *slots* y acotada por `I_slots + L_slots`. Esto se demuestra en el `INFORME.md` (§F5) y es el
hallazgo principal del encargo. Consecuencia: la dicotomía del §2.2 es incompleta y F4 se responde
de otra forma que la que el encargo insinúa.

**(B) «Para moler el reto el atacante tiene que rehacer `d` bloques de ancestría» es correcto como
*coste*, pero no fija por sí solo `umbral(d)`.** El coste de obtener un ancla distinta es rehacer
`d` bloques; la ganancia del atacante no es ese coste, es la tasa de crecimiento de su árbol privado,
que es lo que mide `φ_c` (BDK+19, Anexo F). La identificación `d ⟷ c = d + 1` es una **hipótesis
declarada** (H1 en `HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md`), derivada del lema de ventana y no un
teorema de las fuentes. Se etiqueta como tal en todo el informe.

**(C) `veritas/consenso/poda-post-v1/INFORME.md:144-147` afirma que un reto ligado a la ancestría
obligaría a reabrir §6.1 (la cabecera está cerrada).** Para el anclaje a profundidad `d` que aquí se
analiza, **no hace falta ningún campo nuevo**: `anc_d(B)` es una cantidad derivada de `past(B)`
—`C-GD-09` fija que los datos GHOSTDAG son función exclusiva de `past(B)`— y `C-HDR-06` ya deriva el
rango esperado de `past(B)` y del flujo. Lo que sí cambia son las entradas de `C-HDR-06` y del
retarget, no el layout. Discrepo de esa consecuencia concreta y lo dejo escrito.

Ninguna de las tres invalida el encargo: la primera lo **mejora** (da una respuesta más fuerte a F5);
la segunda acota lo que se puede afirmar; la tercera evita reabrir una sección por una razón falsa.

---

## 2 · Comprobaciones de ENTRADA (desde la raíz `/home/katana/zeo/ZEROX`)

```bash
$ LC_ALL=C sha256sum -c P-ZRX/P-ANCESTRIA/ENTRADA.sha256
P-ZRX/P-ANCESTRIA/PROMPT.md: OK

$ git -C /home/katana/zeo/ZEROX status --short
 M MIGRACION.md
 M P-ZRX/PROPUESTAS-VIABLES.md
 M SPEC.md
 M TAREAS.md
 M ci/consenso-pendiente.txt
 M ci/reglas-sin-cablear.txt
 M ci/reglas-sin-codigo.txt
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

$ date
mar 22 sep 2026 22:58:31 CEST

$ uptime
 22:58:31  up 14 days 19:27,  0 users,  carga promedio: 1,56, 1,41, 1,21
```

`P-ZRX/P-ANCESTRIA/` figura como no rastreado (`??`) en la entrada y en la salida: el encargo no
toca ningún fichero rastreado. Las modificaciones `M` son **preexistentes**, ajenas a este encargo.

Entorno: `julia 1.13.0` vía `./veritas/julia.sh`; `AMD Ryzen 9 9950X3D`, 16 núcleos / 32 hilos
lógicos, `znver5`; 123 GiB visibles.

---

## 3 · Presupuesto declarado (antes de ejecutar)

| Recurso | Tope declarado | Consumido |
|---|---|---|
| Tiempo de cómputo | ≤ 45 min en total, corridas ≤ 10 min | **≈ 6 min** (suite completa 2,9 s; `--todo` < 60 s; benchmarks < 3 min) |
| Hilos | **4** (el encargo baja el tope de 24 de LINEO §7 a 4) | **1** en todas las corridas publicadas (`Threads.nthreads() = 1`, sin BLAS) |
| RAM | ≤ 8 GiB | < 200 MiB (pico: `BigFloat` a 512 bits, 25 053 allocs / 1,33 MB por `umbral_c_medio`) |
| Disco temporal | ≤ 1 GiB | < 1 MiB (`resultados/`, `Manifest.toml` 8 118 B) |

No se agotó ningún tope; no hay estado **inconcluso** por presupuesto. `uptime` se anotó antes de
cada benchmark (§BENCH.txt y §7).

Si se hubiera agotado: checkpoint y estado inconcluso, nunca un «no» por timeout.

---

## 4 · Método

1. Lectura **entera** de las fuentes de §6 del encargo (no de líneas citadas): `veritas/LINEO.md`,
   `veritas/consenso/poda-post-v1/INFORME.md` y `PROCEDENCIA.md`, `research/dag-poas-balizas-auditoria.md`,
   `research/dag-poas-ancla-de-finalidad.md`, `SPEC.md` §6.1-6.2 / §7.1 / §11 / §16.2,
   `P-ZRX/P-2.1/SINTESIS.md`, `research/dag-nativo-poas-propuesta.md` §3, `research/README.md`.
2. Para `φ_c`: **fuente primaria**, `research/fuentes/bdk19.txt` (arXiv 1910.02218v3), §5.4, ec. (39)
   y Anexo F, leídos íntegros, más la Tabla 3 del propio paper.
3. Aritmética **exacta/certificada** para los umbrales: `BigFloat` con redondeo dirigido y recinto
   de anchura `2^-(prec-40)`, con **signo certificado** por comparación contra cota de error MPFR.
   `Rational{BigInt}` en las identidades algebraicas. Nada de `@fastmath`; nada de `Float64` en un
   veredicto.
4. Validación con **cuatro comprobaciones independientes** (ninguna es la fórmula contra sí misma):
   O1 maximización directa de `Λ_c(t)/t`; O2 identidades algebraicas exactas; O3 control simbólico
   `φ₁ = e`; O4 lema de ventana y clases de reto por enumeración exhaustiva. Detalle y etiquetas en
   `HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md`.
5. Categoría declarada (`LINEO.md` §1): **`consenso`** (dominante) — el objeto es una regla de
   anclaje del reto de consenso; **`seguridad`** (secundaria), por el umbral bajo grinding.

---

## 5 · Estado

- [x] F1 · P4 formalizada y contraejemplo demostrado violarla
- [x] F2 · `umbral(d)` con el control `d = 0` → 26,8941 % = `1/(1+e)`
- [x] F3 · `cobertura(d)` por comportamiento, exacta
- [x] F4 · respuesta con demostración (primera línea de `INFORME.md`)
- [x] F5 · vía del flujo, con cita de regla y demostración
- [x] F6 · coste en reglas, disco y relé
- [x] Instrumento con `Project.toml`, `Manifest.toml`, `src/`, `test/`, `bench/`, `run.jl`,
      `resultados/`, `HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md`
- [x] `--check-bounds=yes`: **53/53**; `run.jl --todo`: **TODO OK** (12 artefactos)
- [ ] Comprobaciones de SALIDA (abajo, al cerrar)

---

## 6 · Comandos exactos (reproducir)

```bash
cd /home/katana/zeo/ZEROX
D=P-ZRX/P-ANCESTRIA/investigacion/veritas/consenso/ancestria-reto-v1

# suite completa (referencia, 1 hilo, límites activos)
./veritas/julia.sh --project=$D --check-bounds=yes $D/test/runtests.jl

# todos los artefactos publicados
JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 \
  ./veritas/julia.sh --project=$D $D/run.jl --todo

# rendimiento
JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 \
  ./veritas/julia.sh --project=$D $D/bench/benchmarks.jl
```

Semilla maestra `0x5a5a5a5a`; RNG por réplica derivado por splitmix64 (semillas **no
consecutivas**, hallazgo de `P-ZRX/P-PUERTA/`).

---

## 7 · Benchmarks (LINEO §6)

`uptime` antes de medir: `23:06:23  up 14 days 19:35, carga 2,01 1,70 1,39`.
`julia 1.13.0`, 1 hilo, `znver5`, sin BLAS. Artefacto: `resultados/BENCH.txt`.

| Variante | Tiempo mediano | Asignaciones | Memoria | Hilos |
|---|---:|---:|---:|---|
| `phi_c_f64` (kernel de barrido) | 4,4 µs | **0** | **0 B** | 1 CPU |
| `umbral_c_medio` (referencia `BigFloat` certificada, 384 bits) | 2 973 µs | 25 053 | 1,33 MB | 1 CPU |
| `phi_por_maximo` (oráculo O1, ruta independiente) | 7 438 µs | 30 744 | — | 1 CPU |
| `brw_minimo` (simulación, c=2, k=5, haz=200) | 2,68 ms | — | — | 1 CPU |
| `c_para_umbral(0.45)` (inversión) | 10,1 ms | — | — | 1 CPU |

La ruta certificada no se paraleliza: el cuello es el bucle de bisección en `BigFloat`, y la
paralelización **no se justifica** con el perfil (tablas completas en < 60 s). No se conserva
ninguna «aceleración»: el kernel `Float64` existe sólo para tablas y su equivalencia con la
referencia está medida (peor discrepancia relativa **5,0·10⁻¹⁵** en 26 valores de `c`).

---

## 8 · Comprobaciones de SALIDA (desde la raíz `/home/katana/zeo/ZEROX`)

```bash
$ LC_ALL=C sha256sum -c P-ZRX/P-ANCESTRIA/ENTRADA.sha256
P-ZRX/P-ANCESTRIA/PROMPT.md: OK          # PROMPT.md NO se tocó

$ git -C /home/katana/zeo/ZEROX status --short
 M MIGRACION.md
 M P-ZRX/PROPUESTAS-VIABLES.md
 M SPEC.md
 M TAREAS.md
 M ci/consenso-pendiente.txt
 M ci/reglas-sin-cablear.txt
 M ci/reglas-sin-codigo.txt
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

$ date
mar 22 sep 2026 23:09:20 CEST

$ uptime
 23:09:20  up 14 days 19:38,  0 users,  carga promedio: 1,97, 1,89, 1,52
```

**La salida de `git status --short` es idéntica a la de entrada, línea por línea.** Nada fuera de
`P-ZRX/P-ANCESTRIA/` se ha tocado: ni `SPEC.md`, ni `TAREAS.md`, ni `ci/`, ni `crates/`, ni
`prototipos/`, ni `research/`, ni `veritas/`, ni el resto de `P-ZRX/`. `ENTRADA.sha256` sigue
verificando.

### 8.1 · Dos notas de procedencia

- `Manifest.toml` es el árbol resuelto de `veritas/consenso/poda-post-v1/Manifest.toml` (8 118 B),
  copiado porque el recorte de dependencias de esa auditoría es exactamente el que este instrumento
  necesita (`BenchmarkTools` + `StableRNGs` + stdlib) y `Pkg` no debe resolver en red. No se editó.
- Las dos comprobaciones de aritmética previas al instrumento se hicieron en `/tmp/chk_phi.jl` y
  `/tmp/chk_phi2.jl`, fuera del repositorio. No forman parte de la entrega y no se citan como
  evidencia; sirvieron para detectar un error de signo propio (tres transcripciones de `φ_c`, de las
  que sólo la del paper es correcta) antes de escribir `src/modelo.jl`.

### 8.2 · Entregables

```text
P-ZRX/P-ANCESTRIA/investigacion/
├── INFORME.md                (primera línea = respuesta a F4; F1-F6; límites)
├── DECISIONES-PENDIENTES.md  (D-A … D-F para Katana)
├── PROGRESO.md               (este fichero)
└── veritas/consenso/ancestria-reto-v1/
    ├── HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md  (H1 … H7)
    ├── Project.toml · Manifest.toml · run.jl
    ├── src/{ANR,modelo,rapido,referencia,validacion}.jl
    ├── test/runtests.jl        (53/53 con --check-bounds=yes)
    ├── bench/benchmarks.jl
    └── resultados/             (12 artefactos + BENCH.txt)
```

