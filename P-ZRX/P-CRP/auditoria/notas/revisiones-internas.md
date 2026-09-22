# Revisiones internas de los instrumentos Julia `coste-rama-privada` (v0.2 y v0.3)

**Tipo de documento:** extracción mecánica, sin juicio ni valoración, de los dictámenes internos
de dos instrumentos Julia rescatados. No se interpreta, no se pondera y no se corrige ningún
hallazgo; solo se copia y se localiza.

**Raíz del repositorio:** `/home/katana/zeo/ZEROX`. Todas las referencias `ruta:línea` de este
documento usan la **ruta completa desde la raíz del repositorio** (ruta relativa a
`/home/katana/zeo/ZEROX`).

**Ficheros leídos íntegros (8 dictámenes + 2 respuestas que se citan por exigencia de la tarea):**

- `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-MATEMATICA.md`
- `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-RUST.md`
- `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-JULIA.md`
- `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-RESPUESTA.md`
- `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-MATEMATICA.md`
- `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-RUST.md`
- `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-JULIA.md`
- `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-RESPUESTA.md`

**Nota de extracción:** cuando un dictamen señala un fichero externo (`INFORME.md`, `dp.jl`,
`SPEC.md`, etc.), se copia la referencia **tal como la escribe el dictamen**; no se abrió ese
fichero externo para verificarlo. Cada cita literal indica el `fichero:línea` **del dictamen**
desde donde se copió.

**Convención:** `R2` = `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/`,
`R3` = `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/`. Al pie de cada cita se
da la ruta completa.

---

# PARTE A · INSTRUMENTO v0.2 (`coste-rama-privada-v2`)

## A.1 · Revisor de matemática — `REVISION-MATEMATICA.md`

### F1 — revisor: matemática

- **Cita literal:** “`INFORME.md:62` afirma para `d=6, α=0.4`: … La fórmula `(q/p)^7 = (0.4/0.6)^7 = 0.05852766346593507`, **no** `0.0343`. Además el valor publicado `0.0343` es **menor** que el DP finito `0.0584`, lo que es imposible porque `P_eventual ≥ P_finita(T)` para todo `T`.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-MATEMATICA.md:77,81-83`
- **Culpable señalado:** `INFORME.md:62`; sin función. Cita literal de la referencia: “Error aritmético/de trazabilidad en el informe, no en el código.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-MATEMATICA.md:85`
- **Fila en `REVISION-RESPUESTA.md` (v0.2):** fila literal “| F1/M3 `P_eventual` mal (`0.0343`) | matemática, Julia | corregido a `0.0585277`; `P_eventual ≥ P_finita` | `INFORME.md` §2 |” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-RESPUESTA.md:10`. **Corrección:** “corregido a `0.0585277`; `P_eventual ≥ P_finita`”. **Verificación:** “`INFORME.md` §2”.
- **¿«Límite declarado»?** No. Aparece en la tabla de correcciones.

### F2 — revisor: matemática

- **Cita literal:** “`INFORME.md:124` publica `p99=0.006 ms` y `~1743 MiB/s`. `resultados/IO.txt` registra `p99=0.003 ms`, `max=0.086 ms` y `2230.0 MiB/s`. El informe no es reproducible desde sus propios resultados.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-MATEMATICA.md:89-91`
- **Culpable señalado:** `INFORME.md:124` frente a `resultados/IO.txt`; sin función.
- **Fila en `REVISION-RESPUESTA.md` (v0.2):** fila literal “| F2/M4 cifras I/O no coincidentes | matemática, Julia | se publica rango y se cita `resultados/IO.txt` | `resultados/IO.txt` |” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-RESPUESTA.md:11`. **Corrección:** “se publica rango y se cita `resultados/IO.txt`”. **Verificación:** “`resultados/IO.txt`”.
- **¿«Límite declarado»?** No.

### F3 — revisor: matemática

- **Cita literal:** “`dp_adaptativa` arranca en `ancho=64` con `lo=z0−64` (`dp.jl:83-85`). `prob_superar_dp` fija `direccion=:arriba` (`dp.jl:110`), de modo que `dir_lo=0` (`dp.jl:86`): **nunca** baja `lo`. Como la absorción de superación es `z ≤ −1` (`dp.jl:109`), si `z0 = g·d ≥ 65` la frontera absorbente queda **fuera del soporte** y toda la masa de éxito se contabiliza solo como fuga.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-MATEMATICA.md:95-99`
- **Culpable señalado:** funciones `dp_adaptativa` y `prob_superar_dp` de `src/dp.jl` (el dictamen cita `dp.jl:83-85`, `dp.jl:110`, `dp.jl:86`, `dp.jl:109`).
- **Fila en `REVISION-RESPUESTA.md` (v0.2):** fila literal “| F3 soporte inferior fijo alejado de −1 | matemática | `prob_superar_dp` fija `lo=−1` (`lo_inicial`) | test `z0 grande: frontera z≤−1 alcanzable` |” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-RESPUESTA.md:12`. **Corrección:** “`prob_superar_dp` fija `lo=−1` (`lo_inicial`)”. **Verificación:** “test `z0 grande: frontera z≤−1 alcanzable`”.
- **¿«Límite declarado»?** No.

### F4 — revisor: matemática

- **Cita literal:** “`test/runtests.jl:58-67` (`"D2 · la retícula NO cambia la probabilidad (unidades)"`) recorre `g ∈ {1,2,4,8}` con `z0=d·g` y compara `prob_superar_dp(z0)` con `prob_superar_finita(z0)`, es decir **DP truncada vs DP exacta sobre el mismo paseo**. Es un buen chequeo de truncación, pero **no** compara probabilidades entre distintas `g` para una misma `d` física, y por tanto no demuestra ninguna "invariancia".” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-MATEMATICA.md:119-124`
- **Culpable señalado:** `test/runtests.jl:58-67`; sobreafirmación en `INFORME.md:17` (“La tabla del informe (`INFORME.md:17`) etiqueta esto como "demostrado"; es una sobreafirmación.” — `…REVISION-MATEMATICA.md:123-124`).
- **Fila en `REVISION-RESPUESTA.md` (v0.2):** **sin fila propia en la tabla**; aparece en la sección de límites: “**F4/F5/F6/F7/F8 (baja):** el test de «invariancia de retícula» verifica corrección del DP a varios `z0`, no invariancia física; la cobertura de mutación es parcial; el intervalo de `α_prob` es estrecho por bisceción; `q≥p` no cortocircuita; algunos tests toy son tautológicos (declarados en `HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md`).” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-RESPUESTA.md:24-27`. **Corrección:** sin columna «Corrección». **Verificación:** sin columna «Verificación».
- **¿«Límite declarado»?** Sí, bajo el epígrafe “## Límites que se conservan (no se corrigen, se declaran)” (`…REVISION-RESPUESTA.md:22`).

### F5 — revisor: matemática

- **Cita literal:** “El encargo §4 exige que los mutation tests fallen al introducir `≥` por `>`, **suma por máximo**, **color global**, **aceptación post-divergencia incompatible** y **renormalización de masa truncada**. La suite solo ejercita `>` vs `≥` (`runtests.jl:169-177`) y, para "suma vs máximo", comprueba la desigualdad de la cota de unión (`min(1,Σ) ≥ max`), que es una identidad, no una mutación del simulador. No hay mutación de color global, de aceptación post-divergencia ni de renormalización de masa truncada.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-MATEMATICA.md:128-133`
- **Culpable señalado:** `test/runtests.jl:169-177`.
- **Fila en `REVISION-RESPUESTA.md` (v0.2):** sin fila propia; cubierto por el bloque de límites F4/F5/F6/F7/F8 (`…REVISION-RESPUESTA.md:24-27`), que dice literalmente “la cobertura de mutación es parcial”.
- **¿«Límite declarado»?** Sí (`…REVISION-RESPUESTA.md:22,24-27`).

### F6 — revisor: matemática

- **Cita literal:** “`resultados/CORTO.txt` da el intervalo `(0.39466261863708496, 0.39466267824172974)` (ancho ~6e-8), pero `INFORME.md:61` lo publica como `(0.394663, 0.394663)`, que se lee como un punto. El dato fuente es un intervalo; el redondeo lo destruye. Además, la inversión usa `p_exito_lower` (`run.jl:78`), de modo que el cruce obtenido acota `α_prob` solo por el lado de la cota inferior; con fuga ~0 aquí da igual, pero no se propaga formalmente `[P_L,P_U]` al intervalo de `α`.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-MATEMATICA.md:137-141`
- **Culpable señalado:** `resultados/CORTO.txt`, `INFORME.md:61`, `run.jl:78` (`p_exito_lower`); sin función nombrada.
- **Fila en `REVISION-RESPUESTA.md` (v0.2):** sin fila propia; cubierto por el bloque de límites (“el intervalo de `α_prob` es estrecho por bisceción”). **Corrección:** sin columna. **Verificación:** sin columna.
- **¿«Límite declarado»?** Sí (`…REVISION-RESPUESTA.md:24-27`).

### F7 — revisor: matemática

- **Cita literal:** “Para `q≥p` el evento eventual vale 1 (`referencia.jl:32`), pero `prob_superar_dp` no lo cortocircuita y devuelve `[0,1]` tras expandir `hi` hasta el tope (`p=0.1,q=0.9,z0=100,T=200` → `[0, 1.0000…]`, `hi=1 437 057`, 0.46 s). No es incorrecto (la cota superior es válida) pero es inútil y costoso. Relacionado: `dp_acotada` no valida `p+q=1`; `prob_superar_eventual` no valida `p,q>0` como sí hace `prob_empate_eventual` (`referencia.jl:19` vs `29`).” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-MATEMATICA.md:145-149`
- **Culpable señalado:** `prob_superar_dp` y `dp_acotada`; `referencia.jl:32`, `referencia.jl:19` vs `29`.
- **Fila en `REVISION-RESPUESTA.md` (v0.2):** sin fila propia; bloque de límites (“`q≥p` no cortocircuita”).
- **¿«Límite declarado»?** Sí (`…REVISION-RESPUESTA.md:24-27`).

### F8 — revisor: matemática

- **Cita literal:** “`control_escalar_S` calcula `raiz` con la misma forma cerrada (`rfin5.jl:89`) que el test compara (`runtests.jl:145`, `164`) y `toy_S_deriva` es una identidad algebraica (`validacion.jl:53`). El "control escalar recupera `1/(S+1)` por DP" (`runtests.jl:153-160`) solo verifica `alto.P_U > bajo.P_U` a `±0.03` de la frontera; **no** resuelve una raíz de la DP estocástica ni comprueba deriva nula.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-MATEMATICA.md:153-157`
- **Culpable señalado:** `rfin5.jl:89` (`control_escalar_S`), `runtests.jl:145,153-160,164`, `validacion.jl:53` (`toy_S_deriva`), `HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md`.
- **Fila en `REVISION-RESPUESTA.md` (v0.2):** sin fila propia; bloque de límites (“algunos tests toy son tautológicos (declarados en `HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md`)”).
- **¿«Límite declarado»?** Sí (`…REVISION-RESPUESTA.md:24-27`).

---

## A.2 · Revisor de Rust — `REVISION-RUST.md`

### H1 — revisor: Rust

- **Cita literal:** “`MATRIZ-AUTORIDAD.md:35` marca `C-HDR-06` con integración **«sin código»**. El código existe: `ContextoRangoDag` y `comprobar_rango_contextual` están en `crates/zx-consensus/src/bloque_dag.rs:105-135` y se exportan en `crates/zx-consensus/src/lib.rs:27`.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-RUST.md:138-140`
- **Culpable señalado:** `MATRIZ-AUTORIDAD.md:35`; referencia literal “Lo que falta es el **algoritmo del controlador** y su cableado” (`…REVISION-RUST.md:140-141`).
- **Fila en `REVISION-RESPUESTA.md` (v0.2):** fila literal “| Rust1 C-HDR-06 «sin código» | Rust | reclasificado «interfaz implementada sin cablear» | `MATRIZ-AUTORIDAD.md` |” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-RESPUESTA.md:17`. **Corrección:** “reclasificado «interfaz implementada sin cablear»”. **Verificación:** “`MATRIZ-AUTORIDAD.md`”.
- **¿«Límite declarado»?** No.

### H2 — revisor: Rust

- **Cita literal:** “`MATRIZ-AUTORIDAD.md:37` etiqueta `R-FIN-1a` como `candidata`. Pero el SPEC lo ha adoptado: `C-HDR-05` dice literalmente `slot(sp(B)) ≤ slot(B)` **«(R-FIN-1a)»** (`SPEC.md:879-881`), y `ci/reglas-sin-cablear.txt:21-23,32` lista `C-HDR-05` como implementada-sin-cablear. El instrumento **no tiene fila para `C-HDR-05`**: sustituye una regla vigente por la regla de investigación de la que nació.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-RUST.md:147-152`
- **Culpable señalado:** `MATRIZ-AUTORIDAD.md:37`; `SPEC.md:879-881`; `ci/reglas-sin-cablear.txt:21-23,32`.
- **Fila en `REVISION-RESPUESTA.md` (v0.2):** fila literal “| Rust2/3 R-FIN-1a/R-FIN-11 «candidata» | Rust | reclasificados SPEC vigente (C-HDR-05 / C-GD-07) | `MATRIZ-AUTORIDAD.md` |” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-RESPUESTA.md:18`. **Corrección:** “reclasificados SPEC vigente (C-HDR-05 / C-GD-07)”. **Verificación:** “`MATRIZ-AUTORIDAD.md`”.
- **¿«Límite declarado»?** No.

### H3 — revisor: Rust

- **Cita literal:** “`MATRIZ-AUTORIDAD.md:41` etiqueta `R-FIN-11 (U2/U3″)` como `candidata`, mientras la línea 18 del mismo archivo marca `C-GD-07` como **SPEC vigente**. Son la misma regla: `C-GD-07` está redactado como «Unicidad de billete (U2 y U3″ dinámica) … `(R-FIN-11)`» (`SPEC.md:1701-1707`), y la definición de `R-FIN-11` en `research/dag-poas-ancla-de-orden.md:227-237` coincide término a término. No puede ser candidata y vigente a la vez.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-RUST.md:156-160`
- **Culpable señalado:** `MATRIZ-AUTORIDAD.md:41`; `SPEC.md:1701-1707`; `research/dag-poas-ancla-de-orden.md:227-237`.
- **Fila en `REVISION-RESPUESTA.md` (v0.2):** la fila “Rust2/3 R-FIN-1a/R-FIN-11 «candidata»” (`…REVISION-RESPUESTA.md:18`), con **Corrección:** “reclasificados SPEC vigente (C-HDR-05 / C-GD-07)”, **Verificación:** “`MATRIZ-AUTORIDAD.md`”.
- **¿«Límite declarado»?** No.

### H4 — revisor: Rust

- **Cita literal:** “`grep` de `compatible_rfin5|puede_incorporar_pasado|prefijo_flujo|DescriptorFlujo` en `src/`, `test/` y `run.jl` muestra que solo se usan en `rfin5.jl`, en `run.jl` y en tests. `dag_sim.jl` **no llama** a R-FIN-5 antes de colorear (grep vacío salvo un comentario).” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-RUST.md:164-166`
- **Culpable señalado:** `dag_sim.jl` (y su línea 42: “`dag_sim.jl:42` etiqueta el **máximo** de ramas (`maximum(res.W_priv)`) como «R-FIN-5», cuando no hay ningún filtro de flujo: es solo el máximo de ramas incompatibles.” — `…REVISION-RUST.md:169-170`); `MATRIZ-VALIDEZ.md:11`.
- **Fila en `REVISION-RESPUESTA.md` (v0.2):** fila literal “| M6/Rust4 «R-FIN-5 aplicado antes de colorear» pero no invocado | Julia, Rust | `dag_sim.jl` aplica R-FIN-5 estructural (`_flujo_en`) antes de GDR | `src/dag_sim.jl` |” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-RESPUESTA.md:16`. **Corrección:** “`dag_sim.jl` aplica R-FIN-5 estructural (`_flujo_en`) antes de GDR”. **Verificación:** “`src/dag_sim.jl`”.
- **¿«Límite declarado»?** No.

### H5 — revisor: Rust

- **Cita literal:** “El encargo §0 exige validez **trivaluada** (`Válida`, `Inválida`, `Pendiente`), y así lo dice `MATRIZ-AUTORIDAD.md:5`. Pero `src/modelo.jl:12` añade `CONTRAFACTUAL` al enum de validez y `MATRIZ-VALIDEZ.md:3` lo presenta como cuarta clase de validez.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-RUST.md:179-181`
- **Culpable señalado:** `src/modelo.jl:12`; `MATRIZ-VALIDEZ.md:3`; `MATRIZ-AUTORIDAD.md:5`.
- **Fila en `REVISION-RESPUESTA.md` (v0.2):** fila literal “| Rust5 validez cuatrivaluada | Rust | eliminado `CONTRAFACTUAL`; validez es trivaluada | `src/modelo.jl` |” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-RESPUESTA.md:19`. **Corrección:** “eliminado `CONTRAFACTUAL`; validez es trivaluada”. **Verificación:** “`src/modelo.jl`”.
- **¿«Límite declarado»?** No.

### H6 — revisor: Rust

- **Cita literal:** “`MATRIZ-VALIDEZ.md:10` clasifica el escenario 3 como `Válida (medido condicionado)` y anota «sin `C-GD-11`». `C-GD-11` **decide validez de la fusión** y sigue con cinco pendientes (`SPEC.md:1779-1797`), y GDR no lo implementa. El encargo §3.1 ordena clasificar `Pendiente` la traza que necesite una decisión de `C-GD-11`.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-RUST.md:187-190`
- **Culpable señalado:** `MATRIZ-VALIDEZ.md:10`; `SPEC.md:1779-1797`; también “El propio `MATRIZ-AUTORIDAD.md:22` ya dice «validez de fusión condicionada», lo que refuerza la incoherencia.” (`…REVISION-RUST.md:192-193`).
- **Fila en `REVISION-RESPUESTA.md` (v0.2):** **sin fila correspondiente** en la tabla de la respuesta v0.2.
- **¿«Límite declarado»?** No aparece como límite declarado en la respuesta v0.2.

### H7 — revisor: Rust

- **Cita literal:** “En `src/validacion.jl:67-72`, el denominador suma `res.azules_publicos` (= `blue_score` de la punta, azules distintos en el pasado de la punta, `dag_sim.jl:186`) con `res.rojos_publicos` (= bloque honesto rojo en **cualquier** contexto, `dag_sim.jl:187-197`). Son conjuntos distintos: rojos globales frente a azules del pasado de la punta.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-RUST.md:197-200`
- **Culpable señalado:** `src/validacion.jl:67-72`; `dag_sim.jl:186`, `dag_sim.jl:187-197`; cifra en `resultados/DAG.txt` e `INFORME.md:115`.
- **Fila en `REVISION-RESPUESTA.md` (v0.2):** fila literal “| Rust5 métrica de rojos mezclada | Rust | `tasa_rojos_calibrada` usa rojos/bloques totales | `src/validacion.jl` |” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-RESPUESTA.md:20`. **Corrección:** “`tasa_rojos_calibrada` usa rojos/bloques totales”. **Verificación:** “`src/validacion.jl`”.
- **¿«Límite declarado»?** No.

### H8 — revisor: Rust

- **Cita literal:** “### H8 · Imprecisiones menores. - `MATRIZ-AUTORIDAD.md:13` dice «`BW256` en GDR / `checked_add` Rust». En Rust es correcto (`ghostdag.rs:274-284`), pero GDR acumula `blue_work` en `BigInt` (`referencia.jl:229-232`), no en `BW256` (que solo es el peso por bloque, `modelo.jl:74-83`).” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-RUST.md:204,206-208`
- **Culpable señalado:** `MATRIZ-AUTORIDAD.md:13`; además `MATRIZ-AUTORIDAD.md:45` (valores pendientes `C-NET-31/32`, `SPEC.md:3007`), `MATRIZ-AUTORIDAD.md:14` (dependencia `C-GD-03`→`C-GD-10`) y `MATRIZ-AUTORIDAD.md:28` (estado «ruta activa (PoW lineal)»), según `…REVISION-RUST.md:209-217`.
- **Fila en `REVISION-RESPUESTA.md` (v0.2):** **sin fila correspondiente**.
- **¿«Límite declarado»?** No aparece como límite declarado en la respuesta v0.2.

### H9 — revisor: Rust

- **Cita literal:** “`PROCEDENCIA.md:40` afirma que se generó `HUELLAS.sha256`. En el momento de esta revisión **no existe** `HUELLAS.sha256` en el directorio (ni `REVISION-MATEMATICA.md`/`REVISION-JULIA.md`), que el encargo §6 exige. Los `REVISION-*` pueden estar en curso; la huella final no lo está.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-RUST.md:221-223`
- **Culpable señalado:** `PROCEDENCIA.md:40` y el directorio del instrumento.
- **Fila en `REVISION-RESPUESTA.md` (v0.2):** **sin fila correspondiente**.
- **¿«Límite declarado»?** No aparece como límite declarado en la respuesta v0.2.

---

## A.3 · Revisor de Julia — `REVISION-JULIA.md`

### D1 — revisor: Julia (**no es defecto: control positivo**)

- **Cita literal:** “`simular!` procesa entregas del slot y **después** produce contra la vista local (`src/dag_sim.jl:133-164`). Los bloques hermanos del mismo slot no se ven entre sí; el adversario no se entrega a los honestos. … para `Δ ≥ 1`, **0** violaciones de “padre ≥ id” (nunca un padre sin añadir a GDR) y **0** casos de padre honesto en tránsito. Este era el punto central de D1 y se cumple.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-JULIA.md:55-60`
- **Culpable señalado:** ninguno; función verificada `simular!` (`src/dag_sim.jl:133-164`).
- **Fila en `REVISION-RESPUESTA.md` (v0.2):** sin fila (D1 está marcado “**correcto (verificado)**”, `…REVISION-JULIA.md:53`).
- **¿«Límite declarado»?** No.

### M1 — revisor: Julia

- **Cita literal:** “`_programar_entrega!` agenda la entrega en `slot_produccion + Δ` (`src/dag_sim.jl:113-118`) y `_procesar_entregas!` solo la incorpora si `llegada == slot` (`src/dag_sim.jl:120-125`), sin eliminar ni comparar por umbral. Con `Δ = 0` la entrega se agenda para el mismo slot en que `_procesar_entregas!` ya se ejecutó (la producción ocurre después), por lo que **nunca** se procesa: las vistas quedan solo con génesis.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-JULIA.md:65-69`
- **Culpable señalado:** `_programar_entrega!` (`src/dag_sim.jl:113-118`), `_procesar_entregas!` (`src/dag_sim.jl:120-125`), `simular!` (`src/dag_sim.jl:140`), `s_max = 150` (`src/dag_sim.jl:65`).
- **Fila en `REVISION-RESPUESTA.md` (v0.2):** fila literal “| M1 `Δ=0` pierde entregas | Julia | `_procesar_entregas!` usa `≤` y consume; rechazos GDR se omiten | suite 131/131 |” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-RESPUESTA.md:13`. **Corrección:** “`_procesar_entregas!` usa `≤` y consume; rechazos GDR se omiten”. **Verificación:** “suite 131/131”.
- **¿«Límite declarado»?** No.

### M2 — revisor: Julia

- **Cita literal:** “`INFORME.md:40` publica `g_E(α) = (1−α) − α = 1 − 2α`, pero la definición del propio informe y del encargo es `g_E = lim E[W_priv − W_pub]/T`, cuya tasa en el baseline es `α − (1−α) = 2α − 1`. El código es correcto y consistente: `toy_S_deriva(α,S) = S·α − (1−α)` (`src/validacion.jl:53`) y `control_escalar_S` (`src/rfin5.jl:88`). Es un error de signo en el texto, no en el cálculo (la raíz `α_drift = 1/2` no cambia).” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-JULIA.md:82-87`
- **Culpable señalado:** `INFORME.md:40` (texto); código correcto en `src/validacion.jl:53` (`toy_S_deriva`) y `src/rfin5.jl:88` (`control_escalar_S`).
- **Fila en `REVISION-RESPUESTA.md` (v0.2):** fila literal “| M2 signo de `g_E` en el informe | Julia | corregido a `α−(1−α)` | `INFORME.md` §1 |” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-RESPUESTA.md:14`. **Corrección:** “corregido a `α−(1−α)`”. **Verificación:** “`INFORME.md` §1”.
- **¿«Límite declarado»?** No.

### M3 — revisor: Julia

- **Cita literal:** “`INFORME.md:62` afirma para `d=6, α=0.4`: `(q/p)^7 = 0.0343` frente a la DP finita `T=200 = 0.0584`. El valor correcto es `(0.4/0.6)^7 = 128/2187 = 0.0585277`. La DP finita (`resultados/CORTO.txt:13`, `5.839257e-02`) coincide con el eventual (`≈0.05853`); por tanto la fila que los presenta como “objetos distintos” con una brecha del 40 % es incorrecta.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-JULIA.md:91-95`
- **Culpable señalado:** `INFORME.md:62`; `resultados/CORTO.txt:13`; “No afecta a la validez de la fórmula `(q/p)^(d+1)` ni a los tests, pero sí a la tabla publicada.” (`…REVISION-JULIA.md:95-96`).
- **Fila en `REVISION-RESPUESTA.md` (v0.2):** fila “F1/M3 `P_eventual` mal (`0.0343`)” (`…REVISION-RESPUESTA.md:10`), **Corrección:** “corregido a `0.0585277`; `P_eventual ≥ P_finita`”, **Verificación:** “`INFORME.md` §2”.
- **¿«Límite declarado»?** No.

### M4 — revisor: Julia

- **Cita literal:** “`INFORME.md:124` publica `p99=0.006 ms` y `~1743 MiB/s`. `resultados/IO.txt:4-5` registra `p99=0.003 ms`, `max=0.086`, `2230.0 MiB/s`. Una ejecución fresca de `bench/io_lectura.jl` dio `p99=0.003 ms`, `max=0.084`, `2075 MiB/s`. El `p99` y el rendimiento del informe no se reproducen ni coinciden con el artefacto archivado.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-JULIA.md:100-103`
- **Culpable señalado:** `INFORME.md:124`; `resultados/IO.txt:4-5`; `bench/io_lectura.jl`.
- **Fila en `REVISION-RESPUESTA.md` (v0.2):** fila “F2/M4 cifras I/O no coincidentes” (`…REVISION-RESPUESTA.md:11`), **Corrección:** “se publica rango y se cita `resultados/IO.txt`”, **Verificación:** “`resultados/IO.txt`”.
- **¿«Límite declarado»?** No.

### M5 — revisor: Julia

- **Cita literal:** “`run.jl` parsea `--replicas` y lo imprime en `ENTORNO.txt` (`run.jl:19,40`), pero **ninguna** computación lo usa: `tasa_rojos_calibrada` fija `nrep=40`, `mc_superar` usa `20000`, etc. La línea documentada y el informe sugieren 64 réplicas que no intervienen.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-JULIA.md:108-110`
- **Culpable señalado:** `run.jl:19,40`; `tasa_rojos_calibrada` (nrep=40); `mc_superar` (20000).
- **Fila en `REVISION-RESPUESTA.md` (v0.2):** fila literal “| M5 `--replicas` sin uso | Julia | alimenta la frontera medida y la calibración | `DAG.txt` |” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-RESPUESTA.md:15`. **Corrección:** “alimenta la frontera medida y la calibración”. **Verificación:** “`DAG.txt`”.
- **¿«Límite declarado»?** No.

### M6 — revisor: Julia

- **Cita literal:** “`MODELO.md:39-40` afirma que R-FIN-5 se comprueba “antes de colorear”, y `MATRIZ-VALIDEZ.md:11` declara el escenario candidato como “Válida estructural”. Sin embargo `src/dag_sim.jl` **nunca** llama a `compatible_rfin5`/`puede_incorporar_pasado`: R-FIN-5 solo existe como módulo aislado (`src/rfin5.jl`) ejercitado por tests unitarios.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-JULIA.md:115-118`
- **Culpable señalado:** `src/dag_sim.jl`, `src/rfin5.jl`; `MODELO.md:39-40`; `MATRIZ-VALIDEZ.md:11`.
- **Fila en `REVISION-RESPUESTA.md` (v0.2):** fila “M6/Rust4 «R-FIN-5 aplicado antes de colorear» pero no invocado” (`…REVISION-RESPUESTA.md:16`), **Corrección:** “`dag_sim.jl` aplica R-FIN-5 estructural (`_flujo_en`) antes de GDR”, **Verificación:** “`src/dag_sim.jl`”.
- **¿«Límite declarado»?** No.

### P1 — revisor: Julia

- **Cita literal:** “`simular!` asigna ~8.8 MB (`n=8, T=300`) y ~15.9 MB (`n=4, T=400`) por réplica. Causas: `_puntas_vista` asigna `falses(length(sim.bloques))` en cada llamada (`src/dag_sim.jl:74`); `_elegir_padres` ordena con clave `blue_work_bigint` (BigInt por comparación) y luego `shuffle!` (`src/dag_sim.jl:92-95`); `_procesar_entregas!` recorre la **lista completa** de entregas en cada slot, `O(T·E)` (`src/dag_sim.jl:120-125`); y las mediciones reconstruyen vectores con comprensiones (`src/dag_sim.jl:156,176`).” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-JULIA.md:124-129`
- **Culpable señalado:** `simular!`; `_puntas_vista` (`src/dag_sim.jl:74`); `_elegir_padres` (`src/dag_sim.jl:92-95`); `_procesar_entregas!` (`src/dag_sim.jl:120-125`); `src/dag_sim.jl:156,176`.
- **Fila en `REVISION-RESPUESTA.md` (v0.2):** sin fila; bloque de límites “**P1/P2 (Julia):** el simulador asigna MB por réplica y `_procesar_entregas!` es `O(T·E)`; se tipó el RNG (`Simulador{R}`) pero no se optimizó el resto. No afecta al veredicto; es coste.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-RESPUESTA.md:28-29`.
- **¿«Límite declarado»?** Sí (`…REVISION-RESPUESTA.md:22,28-29`).

### P2 — revisor: Julia

- **Cita literal:** “`src/dag_sim.jl:61` declara `rng::Any`, lo que provoca despacho dinámico en `shuffle!(sim.rng, …)` (`src/dag_sim.jl:95`) y contradice la regla de tipos concretos. El tipo de retorno de `simular!` sigue siendo concreto (`ResultadoSim`, verificado con `@code_warntype`), así que el impacto es de rendimiento, no de corrección. Parametrizar `Simulador{R<:AbstractRNG}`.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-JULIA.md:134-137`
- **Culpable señalado:** `src/dag_sim.jl:61` (`rng::Any`), `src/dag_sim.jl:95` (`shuffle!`).
- **Fila en `REVISION-RESPUESTA.md` (v0.2):** bloque de límites “se tipó el RNG (`Simulador{R}`) pero no se optimizó el resto” (`…REVISION-RESPUESTA.md:28-29`).
- **¿«Límite declarado»?** Sí (`…REVISION-RESPUESTA.md:22,28-29`).

### P3 — revisor: Julia

- **Cita literal:** “`dp_acotada` recibe `exito::Function` (`src/dp.jl:34`). Verificado con `@code_warntype`: el cuerpo infiere `Body::ResultadoDP{Float64}`, de modo que la anotación abstracta **no** desestabiliza en este punto de llamada. Se deja constancia para que no se confunda con una inestabilidad real.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-JULIA.md:141-143`
- **Culpable señalado:** `dp_acotada` (`src/dp.jl:34`); marcado “**B (sin acción necesaria)**” (`…REVISION-JULIA.md:139`).
- **Fila en `REVISION-RESPUESTA.md` (v0.2):** sin fila.
- **¿«Límite declarado»?** No.

### P4 — revisor: Julia

- **Cita literal:** “`resultados/BENCH.txt:7-12` imprime etiquetas de 1..8 hilos sin ninguna medición, y no hay paralelización en el código. La reproducibilidad a 1 hilo sí se verificó. El encargo lo permite si se declara, pero `LINEO` §7 pide medir el escalado.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-JULIA.md:147-149`
- **Culpable señalado:** `resultados/BENCH.txt:7-12`.
- **Fila en `REVISION-RESPUESTA.md` (v0.2):** sin fila.
- **¿«Límite declarado»?** No.

### P5 — revisor: Julia

- **Cita literal:** “`METODO.md:42` y `test/runtests.jl:169-177` afirman detectar mutaciones, pero no existe un arnés de mutación: el testset “mutación” comprueba propiedades (`empate > superar`, cota de unión). No hay prueba directa para “color global”, “renormalización de masa truncada” ni “aceptación post-divergencia incompatible”, que el encargo §4 exige como regresiones obligatorias.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-JULIA.md:153-156`
- **Culpable señalado:** `METODO.md:42`; `test/runtests.jl:169-177`.
- **Fila en `REVISION-RESPUESTA.md` (v0.2):** sin fila propia; bloque de límites que menciona “la cobertura de mutación es parcial” (`…REVISION-RESPUESTA.md:24-27`).
- **¿«Límite declarado»?** Sí (`…REVISION-RESPUESTA.md:22,24-27`).

---

# PARTE B · INSTRUMENTO v0.3 (`coste-rama-privada-v3`)

## B.1 · Revisor de matemática — `REVISION-MATEMATICA.md`

### H1 — revisor: matemática

- **Cita literal:** “`run.jl:61` fija `d = d_bloques * W` (`W = ⌊2^128/(SR+1)⌋`, correcto) y `run.jl:64` usa una semilla independiente de `d` (correcto). Pero `dag_sim.jl:323` y `dag_sim.jl:335` miden `W_pub = bw(punta_pub) − bw(génesis)` y `W_priv[s] = bw(tip_s) − bw(génesis)` con `fork_ref = 1` (génesis), **no** el ancestro común real.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-MATEMATICA.md:47-50`
- **Culpable señalado:** `run.jl:66-69` (`celda_dag`), `dag_sim.jl:323`, `dag_sim.jl:335`, `dag_sim.jl:286` (`raices[s]`); cita literal “`celda_dag` (`run.jl:66-69`) usa esa suma cruda como `esum`” (`…REVISION-MATEMATICA.md:58-59`).
- **Fila en `REVISION-RESPUESTA.md` (v0.3):** fila literal “| H1 aditivo contaba el prefijo común S veces | matemática | `W_pub` y `W_priv` ahora son **post-fork** respecto de `raiz_comun` | `SWEEP-DAG.txt`: S=4 α=0.20 17/24→13/24 |” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-RESPUESTA.md:9`. **Corrección:** “`W_pub` y `W_priv` ahora son **post-fork** respecto de `raiz_comun`”. **Verificación:** “`SWEEP-DAG.txt`: S=4 α=0.20 17/24→13/24”.
- **¿«Límite declarado»?** No.

### H2 — revisor: matemática

- **Cita literal:** “`b` colapsa a `maximum(alphas)` en ambos casos. Si ninguna celda supera `p0`, la lectura correcta (bajo monotonía) es `α_prob > a_low`: la única cota disponible es **inferior**, no superior.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-MATEMATICA.md:92-94`
- **Culpable señalado:** `eventos.jl:84-87` (rama “sin celdas por encima”); `eventos.jl:6-7,63` (metadata). Cita literal “`eventos.jl:84-87`:” (`…REVISION-MATEMATICA.md:83`).
- **Fila en `REVISION-RESPUESTA.md` (v0.3):** fila literal “| H2 `alpha_prob_simultaneo` concluía al revés con 0/n | matemática | tipos `:solo_inferior` / `:solo_superior` / `:indefinida`; nunca cruce sin celdas decisivas | test + `SWEEP-DAG.txt` |” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-RESPUESTA.md:10`. **Corrección:** “tipos `:solo_inferior` / `:solo_superior` / `:indefinida`; nunca cruce sin celdas decisivas”. **Verificación:** “test + `SWEEP-DAG.txt`”.
- **¿«Límite declarado»?** No.

### H3 — revisor: matemática

- **Cita literal:** “`run.jl:96` llama `alpha_prob_simultaneo(alphaS, exmax, REPS, 0.05)` con `alphaS`/`exmax` acumulados de **todos** los S (`run.jl:89-91`). En `SWEEP-DAG.txt:51` el resultado trae `celdas = 22`: `0.45` aparece 6 veces (una por S) y hay α de escenarios incompatibles. … El `tipo=:indefinida` es seguro, pero la etiqueta "alpha_prob (evento terminal, regla R-FIN-5=max)" y el `m=22` (con duplicados) no son interpretables.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-MATEMATICA.md:110-116`
- **Culpable señalado:** `run.jl:96`, `run.jl:89-91`; `SWEEP-DAG.txt:51`.
- **Fila en `REVISION-RESPUESTA.md` (v0.3):** fila literal “| H3 se mezclaban S en un `alpha_prob` | matemática | `alpha_prob` por S | `SWEEP-DAG.txt` |” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-RESPUESTA.md:11`. **Corrección:** “`alpha_prob` por S”. **Verificación:** “`SWEEP-DAG.txt`”.
- **¿«Límite declarado»?** No.

### H4 — revisor: matemática

- **Cita literal:** “En `SWEEP-DAG.txt:47`, S=24 α=0.45 (que es <1/2) da `max_terminal = 6/24 = 25 %` (S=16 y S=8: 6/24 y 5/24). Lo sostenible es "el máximo no cambia la frontera de deriva (promedio), pero su probabilidad finita cerca de α=0.45 no es despreciable". El `INFORME.md:22,74` lo resume como "~0 para α<1/2", que la propia tabla contradice. Además, con 24 réplicas un `0/24` **no** acota P≈0: CP simultáneo (m=22) da cota superior ≈0.246; a lo sumo acota P≲0.25.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-MATEMATICA.md:120-125`
- **Culpable señalado:** `SWEEP-DAG.txt:47`; `INFORME.md:22,74`.
- **Fila en `REVISION-RESPUESTA.md` (v0.3):** fila literal “| H4/H5 “R-FIN-5 ~0 para α<1/2” sobre-enunciado; rejilla gruesa | matemática, Julia | texto corregido; no se llama frontera a 0/24 | `INFORME.md` §6 |” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-RESPUESTA.md:12`. **Corrección:** “texto corregido; no se llama frontera a 0/24”. **Verificación:** “`INFORME.md` §6”.
- **¿«Límite declarado»?** No.

### H5 — revisor: matemática

- **Cita literal:** “Con 24 réplicas y rejilla α de ancho 0.05: - `INFORME.md:21` y `MATRIZ-VALIDEZ.md:28` etiquetan el cruce como `medido`. Lo medido es, a lo sumo, un **intervalo de rejilla** (p. ej. S=4: entre 0.15 y 0.20). No hay IC del punto de cruce ni estimación interpolada con error. … `INFORME.md:79` atribuye el `:indefinida` a "ruido y no monotonicidad"; en realidad el código (`eventos.jl:88-90`) lo emite porque `a_low == -Inf`, es decir, **ninguna** celda quedó confiadamente por debajo de `p0` tras Bonferroni.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-MATEMATICA.md:129-137`
- **Culpable señalado:** `INFORME.md:21`, `MATRIZ-VALIDEZ.md:28`, `INFORME.md:79`, `eventos.jl:88-90`.
- **Fila en `REVISION-RESPUESTA.md` (v0.3):** fila “H4/H5 “R-FIN-5 ~0 para α<1/2” sobre-enunciado; rejilla gruesa” (`…REVISION-RESPUESTA.md:12`), **Corrección:** “texto corregido; no se llama frontera a 0/24”, **Verificación:** “`INFORME.md` §6”.
- **¿«Límite declarado»?** No.

### H6 — revisor: matemática

- **Cita literal:** “`flujo.jl:39-40` hace cortocircuito `flujo_B.flujo_id == flujo_X.flujo_id && flujo_B.autenticado ⇒ VALIDA`, **sin comprobar `X.autenticado`**. Comprobado: … `compatible_rfin5(auth(id=3), no-auth(id=3), 7) = VALIDA`. Contradice la invariante declarada en `flujo.jl:3-4` ("un descriptor no autenticado produce PENDIENTE, nunca `true`").” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-MATEMATICA.md:143-151`
- **Culpable señalado:** `flujo.jl:39-40`; `flujo.jl:3-4`; `construir_flujo`.
- **Fila en `REVISION-RESPUESTA.md` (v0.3):** fila literal “| H6 atajo por `flujo_id` relajaba R-FIN-5 | matemática, Rust | atajo reemplazado por identidad de objeto **y** autenticación mutua | `src/flujo.jl`, tests |” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-RESPUESTA.md:13`. **Corrección:** “atajo reemplazado por identidad de objeto **y** autenticación mutua”. **Verificación:** “`src/flujo.jl`, tests”.
- **¿«Límite declarado»?** No.

### H7 — revisor: matemática

- **Cita literal:** “`dag_sim.jl:226` (`_eta_rama`) colorea el trabajo adversario en la **punta de su propia rama**, donde sus bloques son azules por construcción. Por eso `η_a = 1.0` y `rojos_a = 0` no son una medición de eficiencia bajo la vista pública, sino una identidad del contexto elegido. El `INFORME.md:23` lo marca "inconcluso" para la curva con rojos (correcto), pero conviene decir explícitamente que `η_a` es 1 por construcción, no "medido".” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-MATEMATICA.md:157-161`
- **Culpable señalado:** `dag_sim.jl:226` (`_eta_rama`); `INFORME.md:23`.
- **Fila en `REVISION-RESPUESTA.md` (v0.3):** fila literal “| H7 `η_a=1.0` tautológico | matemática | declarado inconcluso sin rojos | `ETA.txt`, `INFORME` §8 |” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-RESPUESTA.md:14`. **Corrección:** “declarado inconcluso sin rojos”. **Verificación:** “`ETA.txt`, `INFORME` §8”. Además, límite conservado “**`η_a=1.0`** con 0 rojos: la curva con rojos queda **inconclusa**.” (`…REVISION-RESPUESTA.md:29`).
- **¿«Límite declarado»?** Sí, además de la fila de corrección (`…REVISION-RESPUESTA.md:25,29`).

### H8 — revisor: matemática

- **Cita literal:** “`test/runtests.jl:44-55` comprueba que un paseo de juguete con el mismo `StableRNG` y distinto `D₀` conserva los incrementos: es una identidad aritmética del RNG, no del simulador. La propiedad real (semilla independiente de `d`) se cumple por inspección (`run.jl:64`; `d` sólo entra en el umbral `run.jl:61,67-69`), pero no tiene test de integración.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-MATEMATICA.md:165-168`
- **Culpable señalado:** `test/runtests.jl:44-55`; `run.jl:64`, `run.jl:61,67-69`.
- **Fila en `REVISION-RESPUESTA.md` (v0.3):** fila literal “| H8 test del punto 7 no tocaba el simulador | matemática | la semilla no depende de `d` en `run.jl`; se conserva test escalar | `run.jl` |” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-RESPUESTA.md:15`. **Corrección:** “la semilla no depende de `d` en `run.jl`; se conserva test escalar”. **Verificación:** “`run.jl`”.
- **¿«Límite declarado»?** No.

---

## B.2 · Revisor de Rust — `REVISION-RUST.md`

### H1 — revisor: Rust

- **Cita literal:** “`MATRIZ-AUTORIDAD.md:46` cita `SPEC.md` **§2.7** para `C-NET-31/32`. Esa sección **no existe** (`grep` de `2.7` en `SPEC.md`: sin resultados); las reglas están en **§16.6** (`SPEC.md:2971-3005`, `C-NET-31` en `:2976` y `C-NET-32` en `:2997`).” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-RUST.md:73-75`
- **Culpable señalado:** `MATRIZ-AUTORIDAD.md:46`; `SPEC.md`; `ci/reglas-sin-codigo.txt:128-131`.
- **Fila en `REVISION-RESPUESTA.md` (v0.3):** fila literal “| H1 `C-NET-31/32` citadas como §2.7 | Rust | corregido a `SPEC §16` | `MATRIZ-AUTORIDAD.md` |” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-RESPUESTA.md:18`. **Corrección:** “corregido a `SPEC §16`”. **Verificación:** “`MATRIZ-AUTORIDAD.md`”.
- **¿«Límite declarado»?** No.

### H2 — revisor: Rust

- **Cita literal:** “`diff` de `coste-rama-privada-v2/MATRIZ-AUTORIDAD.md` contra `coste-rama-privada-v3/MATRIZ-AUTORIDAD.md` da **cero diferencias**. `MODELO.md:54` afirma que va «copiada de v0.2, **con las correcciones de estado normativo**»: no hay ninguna corrección.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-RUST.md:81-84`
- **Culpable señalado:** `MODELO.md:54`; `MATRIZ-AUTORIDAD.md` (v2 y v3).
- **Fila en `REVISION-RESPUESTA.md` (v0.3):** fila literal “| H2 matriz idéntica a v0.2 pese a declarar correcciones | Rust | cabecera y filas corregidas en v3 | `MATRIZ-AUTORIDAD.md` |” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-RESPUESTA.md:19`. **Corrección:** “cabecera y filas corregidas en v3”. **Verificación:** “`MATRIZ-AUTORIDAD.md`”.
- **¿«Límite declarado»?** No.

### H3 — revisor: Rust

- **Cita literal:** “`MATRIZ-AUTORIDAD.md:43` marca `R-FIN-13′` como `candidata`, integración `no`, dependencia `ventana`. Pero `SPEC.md:1363-1365` dice literalmente: «El acoplamiento R-FIN-13′ —retarget y emisión contabilizan el mismo conjunto pagable— **sigue vigente** y no depende de esta regla» (véase también `SPEC.md:1289-1290`).” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-RUST.md:90-93`
- **Culpable señalado:** `MATRIZ-AUTORIDAD.md:43`; `SPEC.md:1363-1365`; `TAREAS.md:186-187`.
- **Fila en `REVISION-RESPUESTA.md` (v0.3):** fila literal “| H3 `R-FIN-13′` como candidata | Rust | reclasificada `SPEC vigente (acoplamiento)` | `MATRIZ-AUTORIDAD.md` |” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-RESPUESTA.md:20`. **Corrección:** “reclasificada `SPEC vigente (acoplamiento)`”. **Verificación:** “`MATRIZ-AUTORIDAD.md`”.
- **¿«Límite declarado»?** No.

### H4 — revisor: Rust

- **Cita literal:** “`src/flujo.jl:40` devuelve `VALIDA` en cuanto `flujo_B.flujo_id == flujo_X.flujo_id` y `flujo_B.autenticado`, **sin comparar prefijos ni autenticar `pot_origin`/`N(s)`**. R-FIN-5 es comparación de prefijo en `slot(X)` de **todo** `past(B)` (`research/dag-poas-ancla-de-orden.md:223`). Un descriptor que declare el `flujo_id` del flujo público saltaría el filtro.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-RUST.md:100-104`
- **Culpable señalado:** `src/flujo.jl:40`; `flujo.jl:52-65` (`construir_flujo`); `research/dag-poas-ancla-de-orden.md:223`.
- **Fila en `REVISION-RESPUESTA.md` (v0.3):** fila literal “| H4 atajo semántico R-FIN-5 | Rust | ver fila H6 de matemática | `src/flujo.jl` |” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-RESPUESTA.md:21`. **Corrección:** “ver fila H6 de matemática”. **Verificación:** “`src/flujo.jl`”.
- **¿«Límite declarado»?** No.

### H5 — revisor: Rust

- **Cita literal:** “No aparece la cadena «PoT verificado» en el instrumento (`grep` vacío) y `CONTRATO.md:38`, `MATRIZ-AUTORIDAD.md:41` y `MATRIZ-VALIDEZ.md:7` lo etiquetan «estructural». **Riesgo contenido.** Pero hay un resquicio de redacción: `INFORME.md:16` usa como condición «descriptor **autenticado**» y `MODELO.md:28-32` repite «autenticado». `DescriptorFlujo.autenticado` es un `Bool` que fija el propio instrumento (`flujo.jl:19,53-65`); no hay autenticación criptográfica.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-RUST.md:110-115`
- **Culpable señalado:** `INFORME.md:16`, `MODELO.md:28-32`, `flujo.jl:19,53-65`, `test/runtests.jl:78-82`.
- **Fila en `REVISION-RESPUESTA.md` (v0.3):** fila literal “| H5 “autenticado” no es cripto | Rust | aviso explícito en `INFORME.md` §2 y `CONTRATO.md` | — |” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-RESPUESTA.md:22`. **Corrección:** “aviso explícito en `INFORME.md` §2 y `CONTRATO.md`”. **Verificación:** “—”.
- **¿«Límite declarado»?** No. Además, en límites conservados: “**Revisión criptográfica PoT real:** fuera de alcance; el descriptor es estructural.” (`…REVISION-RESPUESTA.md:34`).

### H6 — revisor: Rust

- **Cita literal:** “La fila «DAG con red» es `Válida estructural / Pendiente cripto`. `C-GD-11` decide **validez de la fusión** y sigue con cinco pendientes (`SPEC.md:1779-1797`), y GDR no lo implementa (`ci/reglas-sin-codigo.txt:182-188`). El encargo §0 ordena que una decisión ausente —incluido `C-GD-11`— «nunca se resuelve localmente para obtener `Válida`».” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-RUST.md:120-124`
- **Culpable señalado:** `MATRIZ-VALIDEZ.md:7`; `SPEC.md:1779-1797`; `ci/reglas-sin-codigo.txt:182-188`; `MATRIZ-AUTORIDAD.md:22`.
- **Fila en `REVISION-RESPUESTA.md` (v0.3):** fila literal “| H6 escenario 3 `Válida` con C-GD-11 ausente | Rust | reclasificado `Pendiente por C-GD-11` | `MATRIZ-VALIDEZ.md` |” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-RESPUESTA.md:23`. **Corrección:** “reclasificado `Pendiente por C-GD-11`”. **Verificación:** “`MATRIZ-VALIDEZ.md`”.
- **¿«Límite declarado»?** No.

### H7 — revisor: Rust

- **Cita literal:** “`MATRIZ-AUTORIDAD.md` cita `ci/reglas-sin-codigo.txt` tres veces (`:21,:26,:46`) pero **no cita nunca** `ci/reglas-sin-cablear.txt` ni `ci/consenso-pendiente.txt`, pese a que el encargo los lista como fuentes (`ENTRADA.md:61`) y a que en ellos vive la prueba de «implementada sin cablear».” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-RUST.md:129-132`
- **Culpable señalado:** `MATRIZ-AUTORIDAD.md:21,26,46`; `ENTRADA.md:61`.
- **Fila en `REVISION-RESPUESTA.md` (v0.3):** **sin fila correspondiente**.
- **¿«Límite declarado»?** No aparece como límite declarado en la respuesta v0.3.

### H8 — revisor: Rust

- **Cita literal:** “### H8 · Imprecisiones menores de filas (heredadas). - `MATRIZ-AUTORIDAD.md:13`: «`BW256` en GDR / `checked_add` Rust». En Rust es correcto (`ghostdag.rs:274-284`); pero el oráculo acumula `blue_work` en `BigInt` (`referencia.jl:229-232`) y `BW256` es solo el peso por bloque (`modelo.jl:74-83`).” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-RUST.md:134,136-139`
- **Culpable señalado:** `MATRIZ-AUTORIDAD.md:13`; además `MATRIZ-AUTORIDAD.md:14` (`C-GD-03` depende de `C-GD-10`), `MATRIZ-AUTORIDAD.md:28` (estado normativo no admitido) y `MATRIZ-AUTORIDAD.md:46` (`C-NET-31/32`), según `…REVISION-RUST.md:140-146`.
- **Fila en `REVISION-RESPUESTA.md` (v0.3):** **sin fila correspondiente**.
- **¿«Límite declarado»?** No aparece como límite declarado en la respuesta v0.3.

---

## B.3 · Revisor de Julia — `REVISION-JULIA.md`

### H1 — revisor: Julia

- **Cita literal:** “`SimboloDAG(; k=k, s_max=150, …)` (`src/dag_sim.jl:79`). GDR rechaza un bloque si `slot - slots[sp] > s_max` (GDR `referencia.jl:180-183`). La rama adversaria se ancla en `raices[s]`, congelada en `t_fork` (`src/dag_sim.jl:284-287`), y solo produce en oportunidades. Si su **primera** oportunidad cae en `slot > 150`, la rama no nace; `_anadir_bloque!` devuelve `(0, :gdr)` (`src/dag_sim.jl:171`) y el llamador **ignora el estado**, de modo que el rechazo no se cuenta ni se reporta.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-JULIA.md:83-88`
- **Culpable señalado:** `SimboloDAG` (`src/dag_sim.jl:79`, `s_max=150`); `_anadir_bloque!` (`src/dag_sim.jl:171`); `raices[s]` (`src/dag_sim.jl:284-287`); GDR `referencia.jl:180-183`.
- **Fila en `REVISION-RESPUESTA.md` (v0.3):** fila literal “| H1 `s_max=150` trunca ramas a α bajo sin registrarlo | Julia | contador `rechazos[:gdr]` expuesto (`rgdr`); celdas marcadas inconclusas | `SWEEP-DAG.txt` |” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-RESPUESTA.md:16`. **Corrección:** “contador `rechazos[:gdr]` expuesto (`rgdr`); celdas marcadas inconclusas”. **Verificación:** “`SWEEP-DAG.txt`”. Además, límite conservado “**`s_max`**: las celdas con `rgdr>0` son inconclusas, no evidencia.” (`…REVISION-RESPUESTA.md:32`).
- **¿«Límite declarado»?** Sí, además de la fila de corrección (`…REVISION-RESPUESTA.md:25,32`).

### H2 — revisor: Julia

- **Cita literal:** “`INFORME.md:22` y `INFORME.md:74` afirman `~0` para `α<1/2`. `resultados/SWEEP-DAG.txt` muestra lo contrario en el borde: … Con R-FIN-5 = máximo, el umbral de **deriva** de una rama es `α = 1/2` (no `1/(S+1)`), pero la probabilidad de **primera pasada en horizonte finito** es muy apreciable cerca de `1/2`. La frase correcta es "la deriva media por rama es negativa para `α<1/2`, y el máximo no suma ramas"; no "probabilidad ~0".” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-JULIA.md:102-114`
- **Culpable señalado:** `INFORME.md:22`, `INFORME.md:74`; `resultados/SWEEP-DAG.txt`.
- **Fila en `REVISION-RESPUESTA.md` (v0.3):** fila “H4/H5 “R-FIN-5 ~0 para α<1/2” sobre-enunciado; rejilla gruesa | matemática, Julia” (`…REVISION-RESPUESTA.md:12`), **Corrección:** “texto corregido; no se llama frontera a 0/24”, **Verificación:** “`INFORME.md` §6”.
- **¿«Límite declarado»?** No.

### H3 — revisor: Julia

- **Cita literal:** “El encargo §3.3/D7 pide registrar "slot **y horizonte** de la justificación" y una comprobación **separada** del horizonte futuro, aparte del prefijo en `slot(X)`. `DescriptorFlujo` (`src/flujo.jl:12-21`) no lleva slot/horizonte de justificación y `compatible_rfin5` (`src/flujo.jl:39-45`) solo compara el prefijo hasta `slot_X`. `proxima_inyeccion` (`src/flujo.jl:69`) y `primera_divergencia` (`src/flujo.jl:78`) están definidas pero **nunca se usan** (código muerto).” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-JULIA.md:118-123`
- **Culpable señalado:** `DescriptorFlujo` (`src/flujo.jl:12-21`); `compatible_rfin5` (`src/flujo.jl:39-45`); `proxima_inyeccion` (`src/flujo.jl:69`); `primera_divergencia` (`src/flujo.jl:78`); `CONTRATO.md` §2.2.
- **Fila en `REVISION-RESPUESTA.md` (v0.3):** fila literal “| H3 horizonte de justificación era código muerto | Julia | `horizonte_justificacion_ok` se aplica en `_anadir_bloque!` | `src/flujo.jl`, `dag_sim.jl` |” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-RESPUESTA.md:17`. **Corrección:** “`horizonte_justificacion_ok` se aplica en `_anadir_bloque!`”. **Verificación:** “`src/flujo.jl`, `dag_sim.jl`”.
- **¿«Límite declarado»?** No.

### H4 — revisor: Julia

- **Cita literal:** “`src/flujo.jl:40`: `flujo_id` igual y autenticado devuelve `VALIDA` sin comparar prefijos. Si dos descriptores compartieran `flujo_id` pero difirieran en `PotOrigin`/`N_efectivo` (reconfiguración de `N(s)`), se aceptarían. En este instrumento `N` es constante y `flujo_id` es único por rama, así que no se dispara; es una brecha latente frente al requisito D7 de ordenar `(slot, entropía, N_efectivo)`.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-JULIA.md:129-133`
- **Culpable señalado:** `src/flujo.jl:40`.
- **Fila en `REVISION-RESPUESTA.md` (v0.3):** filas que tratan el mismo atajo: “| H6 atajo por `flujo_id` relajaba R-FIN-5 | matemática, Rust | atajo reemplazado por identidad de objeto **y** autenticación mutua | `src/flujo.jl`, tests |” (`…REVISION-RESPUESTA.md:13`) y “| H4 atajo semántico R-FIN-5 | Rust | ver fila H6 de matemática | `src/flujo.jl` |” (`…REVISION-RESPUESTA.md:21`).
- **¿«Límite declarado»?** No.

### H5 — revisor: Julia

- **Cita literal:** “`_eta_rama` (`src/dag_sim.jl:226-238`) usa como denominador **todos** los bloques válidos del lado, sin excluir el prefijo común. El encargo D6 pide "excluye el prefijo común" y "post-fork". Medido en una corrida S=4 α=0.2 T=200: incluir génesis da `η_h = 0.994253`; excluirlo más el pre-fork da `0.994186`. Diferencia inmaterial, pero la definición no es la declarada.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-JULIA.md:137-140`
- **Culpable señalado:** `_eta_rama` (`src/dag_sim.jl:226-238`).
- **Fila en `REVISION-RESPUESTA.md` (v0.3):** **sin fila correspondiente**.
- **¿«Límite declarado»?** No aparece como límite declarado en la respuesta v0.3.

### H6 — revisor: Julia

- **Cita literal:** “`_drenar_todo!` (`src/dag_sim.jl:204-210`) llena `sim.vista`, pero `W_pub`, `W_priv`, conteo de rojos y `_decisiones` leen el estado de GDR y `sim.bloques`, no `vista`. El drenaje terminal no cambia ninguna cifra publicada y **ningún test lo cubre**. `INFORME.md:20` lo cita como "medido" junto con Δ=0; la cobertura real de los tests es autor-inmediato, Δ=0 y único productor.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-JULIA.md:144-147`
- **Culpable señalado:** `_drenar_todo!` (`src/dag_sim.jl:204-210`); `INFORME.md:20`.
- **Fila en `REVISION-RESPUESTA.md` (v0.3):** **sin fila propia**; límite conservado “**`drenaje terminal`**: implementado y ejercitado por la construcción (Δ=0 y final), sin efecto observable separado en la métrica plana; declarado.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-RESPUESTA.md:30-31`.
- **¿«Límite declarado»?** Sí (`…REVISION-RESPUESTA.md:25,30-31`).

### H7 — revisor: Julia

- **Cita literal:** “`src/eventos.jl:84-87`: en el caso `:solo_cota_superior`, `b = a_low + (maximum(alphas) - a_low)` salvo cuando `a_low == -Inf`, donde `b = maximum(alphas)`. En ambos casos `b == maximum(alphas)`. No es un error de corrección (la celda 0/n no se llama frontera), pero la fórmula es un no-op.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-JULIA.md:151-153`
- **Culpable señalado:** `src/eventos.jl:84-87`.
- **Fila en `REVISION-RESPUESTA.md` (v0.3):** **sin fila propia**; la fila “H2 `alpha_prob_simultaneo` concluía al revés con 0/n” (`…REVISION-RESPUESTA.md:10`) trata la misma rama.
- **¿«Límite declarado»?** No.

### H8 — revisor: Julia

- **Cita literal:** “- Fila "Fusión público+rama divergente" cita `SWEEP-DAG.txt` (`INFORME.md:17`); ese fichero no contiene información de fusión; la prueba está en `test/runtests.jl:91-93`. - Fila "`iid` … reproduce `1−E[F^S]`" cita `CORRELACION.txt` (`INFORME.md:18`); ese fichero solo muestra nº de `W_priv` distintos y `η`; la identidad se comprueba en `test/runtests.jl:111-115`.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-JULIA.md:157-161`
- **Culpable señalado:** `INFORME.md:17`, `test/runtests.jl:91-93`, `INFORME.md:18`, `test/runtests.jl:111-115`, `INFORME.md:20`.
- **Fila en `REVISION-RESPUESTA.md` (v0.3):** **sin fila correspondiente**.
- **¿«Límite declarado»?** No aparece como límite declarado en la respuesta v0.3.

### H9 — revisor: Julia

- **Cita literal:** “La rama adversaria es una cadena que construye sobre todas sus puntas (`src/dag_sim.jl:289-303`), de modo que **ningún bloque adversario es rojo en su propio contexto**; `η_a = 1.0` en todas las réplicas (`ETA.txt`, `CORRELACION.txt`). … Además, `rojos` se cuenta como **unión de contextos** (`src/dag_sim.jl:343-351`), no por contexto, así que un bloque azul en la punta elegida y rojo en otra se cuenta como rojo.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-JULIA.md:165-170`
- **Culpable señalado:** `src/dag_sim.jl:289-303`; `src/dag_sim.jl:343-351`; `ETA.txt`, `CORRELACION.txt`.
- **Fila en `REVISION-RESPUESTA.md` (v0.3):** fila “H7 `η_a=1.0` tautológico | matemática | declarado inconcluso sin rojos | `ETA.txt`, `INFORME` §8” (`…REVISION-RESPUESTA.md:14`) y límite “**`η_a=1.0`** con 0 rojos: la curva con rojos queda **inconclusa**.” (`…REVISION-RESPUESTA.md:29`).
- **¿«Límite declarado»?** Sí (`…REVISION-RESPUESTA.md:25,29`).

### H10 — revisor: Julia

- **Cita literal:** “El encargo §4 exige mutation tests que fallen al cambiar `>` por `≥`, suma por máximo, color global, aceptación post-divergencia incompatible o renormalización de masa truncada. El testset "mutación: > vs ≥ y máximo vs suma" (`test/runtests.jl:181-186`) solo compara dos valores y `cota_union`; no muta código. Queda sin verificar esa parte.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-JULIA.md:174-177`
- **Culpable señalado:** `test/runtests.jl:181-186`.
- **Fila en `REVISION-RESPUESTA.md` (v0.3):** **sin fila correspondiente**.
- **¿«Límite declarado»?** No aparece como límite declarado en la respuesta v0.3.

### H11 — revisor: Julia

- **Cita literal:** “`run.jl:79-96` acumula `alphaS`/`exmax` de todos los `S` con `α` duplicados y `exitos` distintos; el resultado es `:indefinida` (`SWEEP-DAG.txt:51`). Se declara honestamente, pero `α_prob` debería calcularse por escenario `S` fijo.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-JULIA.md:181-183`
- **Culpable señalado:** `run.jl:79-96`; `SWEEP-DAG.txt:51`.
- **Fila en `REVISION-RESPUESTA.md` (v0.3):** fila “H3 se mezclaban S en un `alpha_prob` | matemática | `alpha_prob` por S | `SWEEP-DAG.txt`” (`…REVISION-RESPUESTA.md:11`).
- **¿«Límite declarado»?** No.

### H12 — revisor: Julia

- **Cita literal:** “`MATRIZ-AUTORIDAD.md` e `HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md` conservan encabezado "CRP-v0.2" y su tratamiento "en v2". `REVISION-RUST.md` apareció en paralelo durante esta revisión; `REVISION-MATEMATICA.md` no existía al cerrarla. Fuera del alcance Julia.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-JULIA.md:187-189`
- **Culpable señalado:** `MATRIZ-AUTORIDAD.md`, `HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md`.
- **Fila en `REVISION-RESPUESTA.md` (v0.3):** **sin fila correspondiente**.
- **¿«Límite declarado»?** No aparece como límite declarado en la respuesta v0.3.

---

# PARTE C · Listas completas y ordenadas de identificadores, con recuento

## C.1 · v0.2 (`coste-rama-privada-v2`)

- **Matemática** (`REVISION-MATEMATICA.md`): `F1`, `F2`, `F3`, `F4`, `F5`, `F6`, `F7`, `F8` → **8** hallazgos.
- **Rust** (`REVISION-RUST.md`): `H1`, `H2`, `H3`, `H4`, `H5`, `H6`, `H7`, `H8`, `H9` → **9** hallazgos.
- **Julia** (`REVISION-JULIA.md`), identificadores literales en el orden en que aparecen: `D1`, `M1`, `M2`, `M3`, `M4`, `M5`, `M6`, `P1`, `P2`, `P3`, `P4`, `P5` → **12** identificadores. De ellos, `D1` está rotulado “**correcto (verificado)**” (control positivo, no defecto, `…REVISION-JULIA.md:53`); `P3` está rotulado “**B (sin acción necesaria)**” (`…REVISION-JULIA.md:139`).
- **Total de identificadores v0.2:** 8 + 9 + 12 = **29** (con `D1` incluido como identificador rotulado; 28 si se excluye el control positivo `D1`).

**Nota de colisión de identificadores en v0.2:** el prefijo `H` lo usa Rust (`H1`–`H9`); Julia usa `D1`, `M1`–`M6`, `P1`–`P5`; matemática usa `F1`–`F8`. En `REVISION-RESPUESTA.md` (v0.2) los hallazgos de Rust se renombran `` `Rust1` ``, `` `Rust2/3` ``, `` `Rust4` ``, `` `Rust5` `` (dos filas distintas rotuladas `Rust5`), lo que no coincide fila a fila con los identificadores `H1`–`H9` del dictamen Rust.

## C.2 · v0.3 (`coste-rama-privada-v3`)

- **Matemática** (`REVISION-MATEMATICA.md`): `H1`, `H2`, `H3`, `H4`, `H5`, `H6`, `H7`, `H8` → **8** hallazgos.
- **Rust** (`REVISION-RUST.md`): `H1`, `H2`, `H3`, `H4`, `H5`, `H6`, `H7`, `H8` → **8** hallazgos.
- **Julia** (`REVISION-JULIA.md`): `H1`, `H2`, `H3`, `H4`, `H5`, `H6`, `H7`, `H8`, `H9`, `H10`, `H11`, `H12` → **12** hallazgos.
- **Total de identificadores v0.3:** 8 + 8 + 12 = **28**.

**Nota de colisión de identificadores en v0.3:** los tres revisores vuelven a usar el prefijo `H` (`H1`–`H8` matemática, `H1`–`H8` Rust, `H1`–`H12` Julia). Las filas de `REVISION-RESPUESTA.md` (v0.3) se rotulan también `H1`–`H8` sin prefijo de revisor, salvo la columna «Revisor», lo que produce identificadores repetidos entre revisores.

---

# PARTE D · Afirmaciones literales sobre semillas, RNG, autocorrelación, sesgo de Monte Carlo, masa de la DP, empate vs superación, η, s_max/GDR, R-FIN-5 y flujo

> Extracción literal, agrupada por tema y por instrumento. Cada entrada lleva `ruta_completa:línea`.
> No se localizó ninguna ocurrencia literal de «autocorrelación» ni de «sesgo de Monte Carlo»
> (ni «Monte Carlo») en ninguno de los 8 dictámenes; se hace constar esa ausencia al final del
> apartado.

## D.1 · v0.2

### Semillas / RNG

- “Reproducción independiente de las cifras DAG de `resultados/DAG.txt` con la misma semilla `0x5a5a` (coinciden dígito a dígito).” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-MATEMATICA.md:40-41`
- “Higiene `LINEO` (tipos, globals, `@fastmath`, aritmética entera, RNG por réplica, reproducibilidad a 1 hilo).” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-JULIA.md:17-18`
- “`env -u LD_LIBRARY_PATH julia --project=. run.jl --seed 0x5a5a --replicas 64` → terminó en ~4.8 s de pared, 416 MiB RSS.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-JULIA.md:35-36`
- “**RNG con semilla por réplica:** correcto; fábrica `r -> StableRNG(semilla + r)` en la calibración y semilla de CLI obligatoria. `Random123` está declarado en `Project.toml` pero no se usa.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-JULIA.md:165-166`
- “se tipó el RNG (`Simulador{R}`) pero no se optimizó el resto.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-RESPUESTA.md:28-29`

### Masa de la DP

- “| Conservación de masa y publicar masa cruda | **Correcto** | `dp.jl:68`; `CORTO.txt` conserv ≤ `1.2e-14`, tolerancia `1e-12` |” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-MATEMATICA.md:63`
- “| No renormalización | **Correcto** | No hay división por la masa en `dp.jl` |” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-MATEMATICA.md:64`
- “toda la masa de éxito se contabiliza solo como fuga.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-MATEMATICA.md:98`
- “**renormalización de masa truncada**. La suite solo ejercita `>` vs `≥` (`runtests.jl:169-177`) y, para "suma vs máximo", comprueba la desigualdad de la cota de unión (`min(1,Σ) ≥ max`), que es una identidad, no una mutación del simulador. No hay mutación de color global, de aceptación post-divergencia ni de renormalización de masa truncada.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-MATEMATICA.md:129-133`
- “No hay prueba directa para “color global”, “renormalización de masa truncada” ni “aceptación post-divergencia incompatible”, que el encargo §4 exige como regresiones obligatorias.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-JULIA.md:154-156`

### Empate vs superación

- “Differential testing propio (Julia, sin Python): DP acotada/adaptativa contra la DP exacta `Rational{BigInt}` en `p ∈ {0.50,0.60,0.70,0.80,0.90,0.95,0.99}`, `d ∈ {0,…,10}`, `T ∈ {1,2,5,20,50}`, para empate y superación. **Error absoluto máximo = 1.11e-16.**” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-MATEMATICA.md:33-35`
- “| `P(empate eventual)=(q/p)^d`, `P(superar estricto)=(q/p)^(d+1)` para `q<p` | **Correcto** | `referencia.jl:17-34`; verificado contra DP exacta al crecer `T` (p.ej. `d=6, α=0.4`: exacta `0.0585276634659`, DP `T=1000` `0.05852766346`) |” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-MATEMATICA.md:58`
- “| DPs separadas de empate (`z=0`) y superación (`z≤−1`) | **Correcto** | `referencia.jl:76-85`, `dp.jl:107-118`; absorciones distintas, verificado |” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-MATEMATICA.md:60`
- “| Borde `d=0` sin `0^0` ni convención implícita | **Correcto** | `referencia.jl:21`; empate `n=0` cuenta (`=1`), superar exige evento posterior (`q/p`) |” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-MATEMATICA.md:61`
- “`CORTO.txt` con §2 (`α_prob ≈ 0.394663`; empate `0.0876`, superar `0.0584`)” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-JULIA.md:173`
- “el testset “mutación” comprueba propiedades (`empate > superar`, cota de unión)” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-JULIA.md:154`

### s_max / GDR

- “Al producirse un bloque en `slot > s_max = 150` (constante fija en `src/dag_sim.jl:65`), GDR lo rechaza con `salto_mayor_smax` y `simular!` aborta con `error(...)` (`src/dag_sim.jl:140`).” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-JULIA.md:69-70`
- “Pero `ConfigSim` admite `Δ = 0` sin validarlo, y el `s_max = 150` fijo no se declara en `MODELO.md`; cualquier configuración con vistas estancadas > 150 slots aborta en vez de degradar.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-JULIA.md:75-76`
- “Recomendación: rechazar explícitamente `Δ ≤ 0` en `ConfigSim`, o cambiar `_procesar_entregas!` a `llegada <= slot` con purga, y declarar `s_max` como parámetro.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-JULIA.md:77-78`
- “| `Params(; k, s_max, …)` | `modelo.jl:125-141` | constructor keyword válido |” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-RUST.md:119`

### R-FIN-5 / flujo

- “`grep` de `compatible_rfin5|puede_incorporar_pasado|prefijo_flujo|DescriptorFlujo` en `src/`, `test/` y `run.jl` muestra que solo se usan en `rfin5.jl`, en `run.jl` y en tests. `dag_sim.jl` **no llama** a R-FIN-5 antes de colorear (grep vacío salvo un comentario).” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-RUST.md:164-166`
- “El encargo exige que, en el escenario candidato, «flujo/R-FIN-5 se evalúa antes de GHOSTDAG» (§5.3; §3.3; D7). En este instrumento R-FIN-5 y GDR **nunca se combinan**: el predicado es una unidad estructural aislada y el simulador DAG colorea sin filtro.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-RUST.md:172-175`
- “`MODELO.md:39-40` afirma que R-FIN-5 se comprueba “antes de colorear”, y `MATRIZ-VALIDEZ.md:11` declara el escenario candidato como “Válida estructural”. Sin embargo `src/dag_sim.jl` **nunca** llama a `compatible_rfin5`/`puede_incorporar_pasado`: R-FIN-5 solo existe como módulo aislado (`src/rfin5.jl`) ejercitado por tests unitarios.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-JULIA.md:115-118`
- “La integración inexistente R-FIN-5 + DAG (no hay código que ejecutar).” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-JULIA.md:185`
- “`dag_sim.jl` aplica R-FIN-5 estructural (`_flujo_en`) antes de GDR” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-RESPUESTA.md:16`
- “pendientes (`C-HDR-06`, R-FIN-5 no integrada, PoT AES, `C-GD-11`, R-FIN-7/F).” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-RUST.md:235`

## D.2 · v0.3

### Semillas / RNG

- “4. Punto 7: déficit en unidades de `blue_work` y semilla independiente de `d`.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-MATEMATICA.md:21`
- “→ **76/76 pass, 4.3 s** (Julia 1.13.0, `znver5`, `hilos=1/1`, `semilla=23130`, 24 réplicas).” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-MATEMATICA.md:31`
- “`run.jl:61` fija `d = d_bloques * W` (`W = ⌊2^128/(SR+1)⌋`, correcto) y `run.jl:64` usa una semilla independiente de `d` (correcto).” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-MATEMATICA.md:47-48`
- “Recuento con prefijo contado una vez (mismo RNG, misma rejilla α exacta):” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-MATEMATICA.md:61`
- “propiedad real (semilla independiente de `d`) se cumple por inspección (`run.jl:64`; `d` sólo entra en el umbral `run.jl:61,67-69`), pero no tiene test de integración.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-MATEMATICA.md:167-168`
- “`env -u LD_LIBRARY_PATH julia --project=. run.jl --seed 0x5a5a --replicas 24`” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-JULIA.md:55`
- “La generación es conjunta (una sola matriz `oportunidades`) y reproducible con semilla fija; `run.jl` la reproduce byte a byte con 1 y 4 hilos.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-JULIA.md:209-211`
- “la semilla no depende de `d` en `run.jl`; se conserva test escalar” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-RESPUESTA.md:15`

### Sesgo de Monte Carlo / potencia estadística (afirmaciones más próximas)

- “Además, con 24 réplicas un `0/24` **no** acota P≈0: CP simultáneo (m=22) da cota superior ≈0.246; a lo sumo acota P≲0.25.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-MATEMATICA.md:124-125`
- “Con 24 réplicas y rejilla α de ancho 0.05: - `INFORME.md:21` y `MATRIZ-VALIDEZ.md:28` etiquetan el cruce como `medido`. Lo medido es, a lo sumo, un **intervalo de rejilla** (p. ej. S=4: entre 0.15 y 0.20). No hay IC del punto de cruce ni estimación interpolada con error.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-MATEMATICA.md:129-132`
- “Las celdas `0/24` que sostienen el lado bajo tienen cota superior simultánea ≈0.25, luego son compatibles con efectos no pequeños.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-MATEMATICA.md:133-134`
- “Etiqueta defendible: "acotado en la rejilla (ancho 0.05, n=24); frontera no estimada".” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-MATEMATICA.md:139`
- “**Rejilla y réplicas:** con `24` réplicas y rejilla `0.05`, una celda `0/24` solo acota `P≲0.25` simultáneo; **no** se publica como frontera.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-RESPUESTA.md:27-28`

### Masa de la DP

- (v0.3) No se localizaron afirmaciones específicas sobre «masa de la DP» en `REVISION-MATEMATICA.md`, `REVISION-RUST.md` ni `REVISION-JULIA.md` de v0.3. Sí aparece «renormalización de masa truncada» dentro de la exigencia de mutation testing: “El encargo §4 exige mutation tests que fallen al cambiar `>` por `≥`, suma por máximo, color global, aceptación post-divergencia incompatible o renormalización de masa truncada.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-JULIA.md:174-175`

### Empate vs superación

- (v0.3) No se localizaron las palabras «empate»/«superación» en los dictámenes v0.3. Sí aparece `prob_superar_finita`: “`P_first_passage` racional vía `prob_superar_finita`.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-MATEMATICA.md:34`; y “comparada contra `prob_superar_finita` racional en todo el barrido” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-MATEMATICA.md:177-178`.

### η

- “`dag_sim.jl:226` (`_eta_rama`) colorea el trabajo adversario en la **punta de su propia rama**, donde sus bloques son azules por construcción. Por eso `η_a = 1.0` y `rojos_a = 0` no son una medición de eficiencia bajo la vista pública, sino una identidad del contexto elegido.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-MATEMATICA.md:157-160`
- “`_eta_rama` (`src/dag_sim.jl:226-238`) usa como denominador **todos** los bloques válidos del lado, sin excluir el prefijo común. El encargo D6 pide "excluye el prefijo común" y "post-fork". Medido en una corrida S=4 α=0.2 T=200: incluir génesis da `η_h = 0.994253`; excluirlo más el pre-fork da `0.994186`.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-JULIA.md:137-140`
- “La rama adversaria es una cadena que construye sobre todas sus puntas (`src/dag_sim.jl:289-303`), de modo que **ningún bloque adversario es rojo en su propio contexto**; `η_a = 1.0` en todas las réplicas (`ETA.txt`, `CORRELACION.txt`).” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-JULIA.md:165-167`
- “`η_h`/`η_a` medidos por separado; honestidad de la salida con cero rojos.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-JULIA.md:19`
- “**`η_a=1.0`** con 0 rojos: la curva con rojos queda **inconclusa**.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-RESPUESTA.md:29`

### s_max / GDR

- “`SimboloDAG(; k=k, s_max=150, …)` (`src/dag_sim.jl:79`). GDR rechaza un bloque si `slot - slots[sp] > s_max` (GDR `referencia.jl:180-183`).” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-JULIA.md:83-84`
- “Efecto: subestima `W_priv` del adversario (dirección conservadora para una conclusión de seguridad), pero **sesga las celdas de α bajo** del barrido y no está documentado en `INFORME.md` ni en `MODELO.md`. Recomendación: contar y publicar los rechazos GDR, y justificar `s_max` o limitar el horizonte para que no trunque.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-JULIA.md:95-98`
- “El único rechazo GDR observado fue `:salto_mayor_smax` (H1).” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-JULIA.md:203`
- “| `Params(; k, s_max)` | `modelo.jl:125-141` | keyword válido; `u2=true`, `u3_mode=U3_DYNAMIC` por defecto |” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-RUST.md:167`
- “**`s_max`**: las celdas con `rgdr>0` son inconclusas, no evidencia.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-RESPUESTA.md:32`

### R-FIN-5 / flujo

- “`run.jl:96` llama `alpha_prob_simultaneo(alphaS, exmax, REPS, 0.05)` con `alphaS`/`exmax` acumulados de **todos** los S (`run.jl:89-91`). … la etiqueta "alpha_prob (evento terminal, regla R-FIN-5=max)" y el `m=22` (con duplicados) no son interpretables.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-MATEMATICA.md:110-116`
- “### H4 · "R-FIN-5 (máximo) da ~0 para α<1/2" está sobre-enunciado — **severidad MEDIA**” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-MATEMATICA.md:118`
- “`flujo.jl:39-40` hace cortocircuito `flujo_B.flujo_id == flujo_X.flujo_id && flujo_B.autenticado ⇒ VALIDA`, **sin comprobar `X.autenticado`**.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-MATEMATICA.md:143-144`
- “Contradice la invariante declarada en `flujo.jl:3-4` ("un descriptor no autenticado produce PENDIENTE, nunca `true`").” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-MATEMATICA.md:150-151`
- “- **U2/U3, R-FIN-5 estructural, flujo→validez→U2→color, único productor sin rojos, Δ=0**: los tests y fixtures reproducen lo declarado.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-MATEMATICA.md:197-198`
- “### H2 · Media — "R-FIN-5 (máximo) da ~0 para α<1/2" no lo sostienen los datos del propio informe” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-JULIA.md:100`
- “Con R-FIN-5 = máximo, el umbral de **deriva** de una rama es `α = 1/2` (no `1/(S+1)`), pero la probabilidad de **primera pasada en horizonte finito** es muy apreciable cerca de `1/2`.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-JULIA.md:111-113`
- “2. **R-FIN-5.** Se aplica en `_anadir_bloque!` sobre **todo** el pasado estricto y **antes** de GDR (`src/dag_sim.jl:157-164`), con prefijo comparado en `slot(X)` (`src/flujo.jl:30-45`).” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-JULIA.md:204-206`
- “### H4 · Ruta corta por `flujo_id` en `compatible_rfin5` relaja R-FIN-5” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-RUST.md:98`
- “R-FIN-5 es comparación de prefijo en `slot(X)` de **todo** `past(B)` (`research/dag-poas-ancla-de-orden.md:223`).” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-RUST.md:101-103`
- “4. Riesgo de que la compatibilidad **estructural** de flujo (`src/flujo.jl`) se presente como «PoT verificado».” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-RUST.md:24-25`
- “las filas "Aditivo cruza en `1/(S+1)`" y "R-FIN-5 (máximo) no suma ramas" deberían rebajarse a *"contrafactual medido con procedimiento corregido por revisión / acotado en rejilla, n=24"*” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-MATEMATICA.md:228-230`

### Ausencia literal constatada

- **«autocorrelación»:** ninguna ocurrencia literal en los 8 dictámenes.
- **«Monte Carlo»:** ninguna ocurrencia literal en los 8 dictámenes.
- **«sesgo de Monte Carlo»:** ninguna ocurrencia literal en los 8 dictámenes. La única aparición de «sesgo/sesga» es: “Severidad: **Alta** (bloquea), **Media** (sesgo/corrección de afirmación), **Baja** (precisión), **Info**.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-JULIA.md:78`, y “**sesga las celdas de α bajo** del barrido” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-JULIA.md:96`.

---

# PARTE E · Frases donde un dictamen dice que algo no se pudo comprobar, quedó pendiente o no se certificó

> Extracción literal. Cada entrada con `ruta_completa:línea`.

## E.1 · v0.2 — `REVISION-MATEMATICA.md`

- “## 4 · Lo que NO he podido verificar” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-MATEMATICA.md:172`
- “1. **La conversión física `d·g`** contra un modelo independiente (continuo o de bloques con peso real). Solo he verificado que el mapa `z0=g·d` se aplica una vez y que la DP coincide con el paseo `±1` resultante; no existe una referencia externa que fije la semántica física de `g`.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-MATEMATICA.md:174-176`
- “3. **La cota de error de la identidad iid** `1−E[F(W_pub)^S]`: solo la vi pasar el test a 4000 réplicas con `atol=0.05`; no la acoté analíticamente.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-MATEMATICA.md:179-180`
- “4. **Las afirmaciones económicas y de `S_adversario`** (D9/D10): fuera de alcance; el informe ya las declara pendientes.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-MATEMATICA.md:181-182`
- “6. **El error de truncación a horizonte infinito** más allá de la comparación con la forma cerrada para `q<p`; para `q≈p` y `d` grande no dispongo de una referencia exacta tratable.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-MATEMATICA.md:184-185`
- “7. Que el fallo F3 sea o no alcanzable por algún escenario futuro previsto: con los parámetros publicados no lo es, pero no puedo descartarlo para `d` grande.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-MATEMATICA.md:186-187`
- “**No obstante, la revisión no puede cerrarse favorablemente tal cual**” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-MATEMATICA.md:198`

## E.2 · v0.2 — `REVISION-RUST.md`

- “## 6 · Qué NO verifiqué” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-RUST.md:239`
- “- La corrección matemática y numérica de `dp.jl`, `referencia.jl`, `controlador_rce.jl` y el tratamiento de cotas; es del revisor de matemáticas/Julia. Solo confirmé que la suite pasa.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-RUST.md:241-242`
- “- La criptografía PoT (no hay verificador que auditar) y la semántica upstream de Autonomys más allá de lo citado.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-RUST.md:243-244`
- “- No regeneré `resultados/` con `run.jl` ni ejecuté `bench/`. Reproduje únicamente la suite de tests.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-RUST.md:245`
- “- No audité una por una todas las reglas del SPEC, solo las citadas por el instrumento y las necesarias para el inventario `ci/`.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-RUST.md:246-247`
- “- No verifiqué los números de `INFORME.md` (α_prob, P_eventual, W_pub/W_priv, ICs); eso es del revisor de matemáticas.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-RUST.md:248-249`

## E.3 · v0.2 — `REVISION-JULIA.md`

- “## 6 · Qué no verifiqué” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-JULIA.md:177`
- “- El coloreo de GDR-v0.2 (`ghostdag-rank-v1`): se usó como oráculo, no se auditó su corrección.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-JULIA.md:179`
- “- Cotas numéricas certificadas (no se usó `Arblib`/`IntervalArithmetic`): el intervalo de `α_prob` es de bisección en `Float64` y no está certificado ni se propagaron IC al cruce.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-JULIA.md:183-184`
- “- La integración inexistente R-FIN-5 + DAG (no hay código que ejecutar).” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-JULIA.md:185`
- “- El entorno de hardware más allá de `ENTORNO.txt` (`znver5`, 1 hilo por defecto).” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-JULIA.md:187`

## E.4 · v0.2 — `REVISION-RESPUESTA.md`

- “## Límites que se conservan (no se corrigen, se declaran)” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-RESPUESTA.md:22`
- “- Revisión de la **asociación DAG→cohorte RCE** y **`S_adversario`** siguen pendientes.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-RESPUESTA.md:30`
- “- Las revisiones no certifican la matemática con aritmética de bolas; el margen no se certifica.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/REVISION-RESPUESTA.md:31`

## E.5 · v0.3 — `REVISION-MATEMATICA.md`

- “## 5 · Lo no verificado” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-MATEMATICA.md:200`
- “- No re-derivé GHOSTDAG/GDR-v0.2; lo traté como oráculo de color y `blue_work`.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-MATEMATICA.md:202`
- “- No ejecuté `run.jl` completo (para no sobrescribir `resultados/`); reproduje celdas sueltas con los mismos parámetros. La corrección H1 la hice con una réplica manual que **reproduce exactamente** `esum` del código actual.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-MATEMATICA.md:203-205`
- “- No audité `BENCH.txt`/`IO.txt` ni la parte económica (`S_adversario`, `η·c`), fuera del foco.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-MATEMATICA.md:206`
- “- No verifiqué la correspondencia entre las reglas del instrumento y el SPEC vigente.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-MATEMATICA.md:207`
- “- `alpha_prob_determinista` se probó para `d=4`; no barrí todos los `(d,p0,T)`.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-MATEMATICA.md:208`
- “**Pero hay un defecto material (H1) que invalida las cifras concretas que el `INFORME.md` presenta como "medidas" del contrafactual aditivo:**” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-MATEMATICA.md:217-218`

## E.6 · v0.3 — `REVISION-RUST.md`

- “## 5 · No verificado” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-RUST.md:186`
- “- La criptografía PoT (no hay verificador que auditar; `wire_dag.rs:375-383` siempre devuelve `IntegracionPotPendiente`) y la semántica upstream de Autonomys más allá de lo citado.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-RUST.md:191-192`
- “- No regeneré `resultados/` con `run.jl` ni ejecuté `bench/`; no audité cifra a cifra el `INFORME.md`.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-RUST.md:193`
- “- No audité todas las reglas del SPEC, solo las citadas por el instrumento y las del inventario `ci/`.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-RUST.md:194`
- “- `HUELLAS.sha256` y las revisiones `REVISION-MATEMATICA.md`/`REVISION-JULIA.md` **no existían** al escribir esta (entregables del encargo §6 en curso; esta es una de las tres).” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-RUST.md:195-196`
- “- No verifiqué que `MATRIZ-AUTORIDAD.md` describa correctamente reglas fuera del alcance de Rust (p. ej. R-FIN-2/3/14, DAV/DCM/CBE/DMS).” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-RUST.md:197-198`

## E.7 · v0.3 — `REVISION-JULIA.md`

- “## 5 · No verificado” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-JULIA.md:223`
- “- `bench/benchmarks.jl` y `bench/io_lectura.jl`: no se reran en esta pasada; sus cifras (`BENCH.txt`, `IO.txt`) no se validaron aquí.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-JULIA.md:225-226`
- “- Perfilado (`@code_warntype`, JET, `@allocated`) y escalado `1…24`: no ejecutados (instrumento serial, sin paralelismo).” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-JULIA.md:227-228`
- “- Cierre del umbral protocolario y reglas pendientes (controlador C-HDR-06, R-FIN-7/`F`, C-GD-11, PoT AES, `S_adversario`): no se cierran; el propio INFORME los deja pendientes.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-JULIA.md:232-233`
- “Queda sin verificar esa parte.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-JULIA.md:177`
- “INFORME.md` no declara esta ausencia como pendiente; `CONTRATO.md` §2.2 solo promete "R-FIN-5 sobre todo `past(B)`". No invalida lo entregado, pero es un requisito del encargo no cubierto.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-JULIA.md:123-125`

## E.8 · v0.3 — `REVISION-RESPUESTA.md`

- “## Límites conservados (no se corrigen, se declaran)” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-RESPUESTA.md:25`
- “- **Rejilla y réplicas:** con `24` réplicas y rejilla `0.05`, una celda `0/24` solo acota `P≲0.25` simultáneo; **no** se publica como frontera.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-RESPUESTA.md:27-28`
- “- **`η_a=1.0`** con 0 rojos: la curva con rojos queda **inconclusa**.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-RESPUESTA.md:29`
- “- **`drenaje terminal`**: implementado y ejercitado por la construcción (Δ=0 y final), sin efecto observable separado en la métrica plana; declarado.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-RESPUESTA.md:30-31`
- “- **`s_max`**: las celdas con `rgdr>0` son inconclusas, no evidencia.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-RESPUESTA.md:32`
- “- **Posible `BoundsError`/rendimiento:** el simulador es serial; no se optimizó.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-RESPUESTA.md:33`
- “- **Revisión criptográfica PoT real:** fuera de alcance; el descriptor es estructural.” — `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/REVISION-RESPUESTA.md:34`

---

# PARTE F · Observaciones de extracción (sin valoración)

1. En v0.2, `REVISION-RESPUESTA.md` no incluye filas para `H6`, `H8` ni `H9` del dictamen Rust,
   ni para `P3` ni `P4` del dictamen Julia, ni para `D1` (que es un control positivo).
2. En v0.3, `REVISION-RESPUESTA.md` no incluye filas para `H7` ni `H8` del dictamen Rust,
   ni para `H5`, `H7`, `H8`, `H10` ni `H12` del dictamen Julia.
3. Los identificadores se reutilizan entre revisores dentro del mismo instrumento (v0.2: Rust
   `H1`–`H9`; v0.3: `H1`–`H8` en matemática, `H1`–`H8` en Rust y `H1`–`H12` en Julia), y
   `REVISION-RESPUESTA.md` de v0.2 renombra los hallazgos Rust a `Rust1`–`Rust5` con dos filas
   rotuladas `Rust5`.
4. Donde la respuesta rotula una fila con un identificador que no coincide exactamente con el
   identificador del dictamen (p. ej. la fila v0.2 “Rust5 métrica de rojos mezclada” frente al
   hallazgo Rust `H7`), se ha copiado la etiqueta literal de la respuesta y se ha dejado el
   hallazgo bajo su identificador original.
5. No se localizaron las palabras «autocorrelación» ni «Monte Carlo» en ninguno de los 8
   dictámenes (véase D.2, «Ausencia literal constatada»).
