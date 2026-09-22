**RESPUESTA (primera línea del informe).** CRP-v0.2 y CRP-v0.3 **son reproducibles dentro de su
alcance**: sus tests (`131/131` y `76/76` con `--check-bounds=yes`) y **todos** sus artefactos
numéricos se reejecutan y coinciden, y GDR-v0.2 no ha cambiado desde el 2026-09-18. **Sustituyen a
CRP-v0.1 solo como evidencia de la etapa siguiente, no como veredicto**: quitaron la cadena por un
DAG con rojos reales, separaron empate de superación, conservaron la masa de la DP con cotas
certificadas, y separaron «máximo de ramas» de «suma aditiva». **Pero no están validadas**: ninguna
de las dos implementa la derivación PoAS que convierte una fracción de **espacio** `α` en una tasa
por slot (`D4`), `η_a ≡ 1` es una tautología, las réplicas usan el esquema de semillas consecutivas
que este repositorio ya documentó como sesgado, y la única frontera con señal positiva es el
**contrafactual aditivo**, que `C-FLU-14` prohíbe. **Hoy no se puede afirmar ningún umbral de una
rama privada bajo el SPEC vigente**: lo único demostrado es `α_drift = 1/2` como **identidad del
baseline** (un evento por paso, tasas simétricas), y el **umbral protocolario sigue inconcluso** por
el controlador `C-HDR-06`, el verificador PoT, los cinco pendientes de `C-GD-11`, la finalidad
`C-FIN-01` y `S_adversario`. La frase de cierre que corresponde es la tercera del encargo:
**«Umbral protocolario inconcluso; el baseline idealizado no sustituye las reglas pendientes»**, no
«frontera medida».

# P-CRP · INFORME — Auditoría con reejecución de CRP-v0.2 y CRP-v0.3

**Zona:** `P-ZRX/P-CRP/auditoria/`. **No** se ha editado `SPEC.md`, `TAREAS.md`, `ci/`, `crates/`,
`prototipos/`, `research/`, `veritas/` ni el resto de `P-ZRX/`, incluido `P-ZRX/rescate-deepseek/`.
Artefactos: este informe, `BASELINE.md`, `DEFECTOS.md`, `RECOMENDACION-MIGRACION.md`, `PROGRESO.md`,
`copia/` (v2 y v3 parcheados), `verificacion/` (mis comprobaciones) y `registros/` (salidas crudas).
**No se ha ejecutado Python en ningún paso.**

---

## 1 · Alcance, entradas y presupuesto

- Entradas de solo lectura, con huellas en `ENTRADA.sha256`: **94/94 OK** al empezar (16:42:09)
  y al terminar. Detalle en `PROGRESO.md` §1 y `registros/inicio.txt`, `registros/fin.txt`.
- Presupuesto declarado antes de ejecutar: **8 hilos**, ≤ 16 GiB de RAM, ≤ 2 GiB de disco en
  `auditoria/`, ≤ 4 h de pared. Ninguna corrida superó los 10 min; la más larga, 57 s.
- Julia 1.13.0 vía `veritas/julia.sh` (`env -u LD_LIBRARY_PATH`). AMD Ryzen 9 9950X3D.
- **Carga ajena:** todos los tiempos de este informe se tomaron con carga promedio ≤ 3,5 y
  `JULIA_NUM_THREADS=1`, es decir **por encima de mis propios hilos**: van etiquetados
  «medido con carga ajena». Las cifras matemáticas no dependen de la carga.
- **`P-ZRX/P-CRP1/auditoria/INFORME.md` no existía** al empezar (16:41) ni durante esta auditoría
  (16:55): no he podido usar su veredicto sobre cuáles de los diez defectos son reales en v0.1.
  Mi pregunta (¿v0.2 y v0.3 hacen lo que el encargo 07v2 exigía?) se contesta igual.

---

## 2 · §2.1 · Reproducibilidad

### 2.1.1 · Comandos ejecutados

Desde `P-ZRX/P-CRP/auditoria/copia/<instrumento>/`, `J = env -u LD_LIBRARY_PATH JULIA_NUM_THREADS=N
/home/katana/torio/.juliaup/bin/julia`:

```bash
$J --check-bounds=yes --project=. test/runtests.jl          # N=8
$J --project=. run.jl --seed 0x5a5a --replicas 64           # v0.2, N=4 (y 1,2,4,8 para determinismo)
$J --project=. run.jl --seed 0x5a5a --replicas 24           # v0.3, N=4 (y 1,2,4,8)
$J --project=. bench/benchmarks.jl                          # N=1
$J --project=. bench/io_lectura.jl                          # N=1
```

### 2.1.2 · Comparación con `resultados/`, ignorando fecha, ruta y entorno

| Artefacto | v0.2 | v0.3 |
|---|---|---|
| `TESTS.txt` | **131/131** a 7,0 s (original 7,2 s) | **76/76** a 4,2 s (original 4,1 s) |
| `TEORIA`, `CORTO`, `RCE`, `RFIN5`, `DAG`, `CONTROL`, `MC`, `VEREDICTO` (v0.2) | **idénticos byte a byte** | — |
| `EVENTOS`, `SWEEP-TOY`, `SWEEP-DAG`, `VARIOS`, `CORRELACION`, `U2U3`, `ETA`, `VEREDICTO` (v0.3) | — | **idénticos byte a byte** |
| `ENTORNO.txt` | difiere solo en `fecha_utc` y `hilos_default` | ídem |
| `BENCH.txt` | regenerado; tiempos distintos, mismas magnitudes | ídem |
| `IO.txt` | regenerado; 1923,8 MiB/s (original 2284,1) — **medido con carga ajena** | 1842,8 MiB/s (original 1839,1) |

`BENCH.txt` regenerado (v0.2): DP `d=6 T=2000` 6508 µs (original 6305), exacta `Rational` 33921 µs
(34748), DAG 4 nodos/400 slots 3436 µs (3679). v0.3: DP 6804 µs (6490), eventos 173 µs (181), DAG
S=4 1633 µs (1666). Los **tiempos no son reproducibles** (dependen de la máquina y de la carga); el
resto sí. Las asignaciones publicadas (`109`, `687992`, `49036`, `60588`, `72`) **coinciden**.

**Ninguna cifra numérica no reproducible.** No hay hallazgo de reproducibilidad en el sentido del
encargo: todos los artefactos numéricos de v0.2 y v0.3 se reproducen byte a byte.

### 2.1.3 · Determinismo con 1, 2, 4 y 8 hilos

Los dos instrumentos son **seriales**: no hay `@threads`, `Threads.@spawn` ni RNG compartido (grep
vacío en `src/` y `run.jl`, salvo las dos líneas que solo *imprimen* `nthreads`). Medido: el hash
del directorio `resultados/` sin `ENTORNO.txt` es **idéntico** con 1, 2, 4 y 8 hilos para los dos
instrumentos (`registros/determinismo-hilos.txt`). Es decir, la afirmación de `BENCH.txt` de v0.2
(«1..N hilos dan el mismo resultado») es **cierta** — pero era una afirmación sin medición y esa
sección del banco **no mide ningún escalado** (`DEFECTOS.md` B9).

---

## 3 · §2.2 · Los diez defectos de CRP-v0.1, uno a uno

Veredicto: **corregido** / **corregido a medias** / **no corregido** / **no aplicable**. La
evidencia es código reejecutado + artefacto.

| # | Exigía | Dónde está (v0.2 / v0.3) | Qué test lo ejercita | Veredicto |
|---|---|---|---|---|
| **D1** | DAG por eventos/vistas locales; puntas, anticonos y `rojo_k` reales; reutilizar GDR; fixtures de rojo conocido y de cero rojos; escenario estadístico calibrado | `v2/src/dag_sim.jl` (`Simulador`, `_elegir_padres`, `_programar_entrega!`, `_procesar_entregas!`, `simular!`); `v3/src/dag_sim.jl` (`SimuladorV3`, `_drenar!`, `_drenar_todo!`, `simular_v3!`) | `v2/test:137-147,188-202`; `v3/test:118-131,188-197` | **corregido** |
| **D2** | Una unidad; `z=g·d`; soporte adaptativo; masa cruda; separar kernel/fuga/éxito; `[P_L,P_U]` acumulada; error ≤ `1e-12` solo si compatible; truncación infinita aparte; referencia independiente | `v2|v3 src/dp.jl` (`dp_acotada`, `dp_adaptativa`, `prob_*_dp`, `invertir_monotona`), `src/referencia.jl` | `v2/test:42-76`; `v3/test:153-170` | **corregido** (certificado por mí, §3.1) |
| **D3** | Empate `(q/p)^d` ≠ superar `(q/p)^(d+1)`; `d=0`; saltos compuestos; orden de sucesos simultáneos; regresión `1/2⁻` | `src/referencia.jl:17-34,95-101`; dos absorciones en `dp.jl`; `v3/src/eventos.jl` | `v2/test:14-40`; `v3/test:154-169` | **corregido** |
| **D4** | Derivar la probabilidad discreta de las reglas PoAS (distancia circular, `sd ≤ SR/2`, chunks ganadores, extremos); separar chunks auditados / ganadores / admitidos / azules | **no está en ningún fichero** | ninguno | **no corregido** |
| **D5** | Controlador del SPEC `Pendiente` con el primer dato ausente; RCE/ARM aparte; `SR` derivado por bloque; admisión de rango antes de GDR | `src/controlador_rce.jl`; `v3/src/dag_sim.jl:156-191` | `v2/test:78-111`; `v3/test:57-68` | **corregido a medias** |
| **D6** | `η_x(T)` post-fork, sin prefijo común, por contexto; `c_x^∞`, `η_x^∞`; máximo ≠ suma; red conjunta (DMS) | `v3/src/dag_sim.jl:240-252`, `run.jl:143-160`; `v2` no lo mide | `v3/test:133-139` | **corregido a medias** |
| **D7** | Descriptor con `PotOrigin`/eventos/`N`; prefijos en `slot(X)`; máx vs suma; controles de correlación; cotas de unión | `v3/src/flujo.jl`, `v3/src/dag_sim.jl:100-114,394-405`, `src/validacion.jl` (v0.2 y v0.3) | `v3/test:70-116`; `v2/test:113-135,213-220` | **corregido a medias** |
| **D8** | Color por contexto `(punta, bloque)`; los cinco casos U2/U3; orden explícito flujo→validez→U2→U3″ | `v3/src/flujo.jl:107-141`, `v3/src/dag_sim.jl:156-191`, `src/gdr_wrapper.jl:48-55` | `v3/test:141-151` | **corregido** |
| **D9** | `S_escenario` / `S_microbenchmark` / `S_adversario` separados; I/O de solo lectura acotado; `S_adversario` pendiente sin 100 k IOPS | `v2/bench/io_lectura.jl`; `v3/METODO.md:43`; `v3/INFORME.md:26` | `v2/test:222-228` | **corregido** |
| **D10** | Desglose de espacio / CPU-PoT-IOPS / energía / recompensa renunciada / duración / hundido vs marginal; máximo «cero espacio plotteado adicional» | `v2/INFORME.md` §10 (líneas 144-149); **v0.3 no lo trata en ningún sitio** | ninguno (texto) | **v0.2: a medias · v0.3: no corregido** |

**Notas por defecto (evidencia concreta):**

- **D1 · corregido.** Reproducido: `v2/resultados/DAG.txt` con `k=2`, Δ=4, n=8, 64 réplicas da
  **tasa de bloques rojos 0,6044** y **fracción de réplicas con ≥1 rojo 1,000** (IC95 0,943–1,000);
  con `k=30`, 0 rojos (cota sup. 0,057). Fixtures: `k=1,2,5` → `rojo_k`; `k=3,30` → cero rojos.
  **Matiz:** el recuento de rojos del barrido es una **unión de contextos**
  (`v3/src/dag_sim.jl:357-365`), no el color por contexto que D8/§0 piden (`DEFECTOS.md` C5), y el
  «drenaje terminal» que el informe llama «medido» no cambia ninguna cifra (`B8`).
- **D2 · corregido, y certificado.** Mi comprobación con aritmética exacta
  (`verificacion/dp_exacto.jl`) sobre las 18 celdas de `resultados/CORTO.txt`: `P_L ≤ exacto ≤ P_U`
  con peor `P_U − exacto = 5,7e-16` y peor `|conservación| = 1,2e-14` → **error ≤ `1e-12`
  certificado**. **Dos matices:** (i) `dp_adaptativa` puede devolver una corrida **no certificada**
  al toparse con `max_ancho` sin marcarla (`DEFECTOS.md` C9); (ii) el test de «retícula» compara DP
  y exacta con el **mismo** `z0`, así que **no** prueba `d ≡ d·g` (`C10`) — la tabla §0 de v0.2 lo
  etiqueta «demostrado».
- **D3 · corregido.** `referencia.jl:17-34` y los tests exactos dan `(q/p)^d` y `(q/p)^(d+1)`; el
  borde `d=0` está cubierto (`prob_empate_eventual(0,…) == 1`, `prob_superar_eventual(0,…) == q/p`);
  `corrimiento_alpha_prob` regresiona el acercamiento a `1/2` **desde abajo** (`TEORIA.txt`).
  La **DP numérica** confirma el orden `P_terminal ≤ P_paso ≤ P_eventual` con exactitud
  (`registros/dp-exacto.txt` §4). **Matiz:** los pasos son secuenciales, luego «el orden de sucesos
  simultáneos» no es un caso que la DP tenga que fijar; `METODO.md:31-34` lo declara por índice de
  creación.
- **D4 · no corregido.** `grep -rni "chunk|sector|distancia|solution_range|ganador"` en `src/` de
  v0.2 y v0.3 → **0 ocurrencias**. `α` entra como probabilidad de oportunidad por slot
  (`v3/src/dag_sim.jl:100-114`) y el peso es `⌊2^128/(SR+1)⌋` con `sr_constante`. La fila H1 de
  `HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md:9` afirma que «la probabilidad discreta se deriva de las
  reglas PoAS»: **es falso para este código**. Consecuencia: **la pregunta del encargo (fracción de
  espacio `α`) no está contestada**; el puente espacio→tasa es pendiente. Es el defecto de mayor
  alcance de los diez.
- **D5 · a medias.** El controlador del SPEC queda `Pendiente` con la ventana como primer dato
  ausente (`resultados/RCE.txt`) y RCE rev2 (+Z0) está implementado con `BigInt` y probado. Pero
  `_anadir_bloque!` **no llama** al controlador, cada bloque lleva `sr = sr_constante`, no hay
  admisión de rango antes de GDR ni conjunto pagable (`DEFECTOS.md` C2, C3).
- **D6 · a medias.** v0.3 mide `η_h ≈ 0,99` y `η_a` **por separado** (`ETA.txt`), y separa máximo de
  suma; pero `η_a ≡ 1` **exactamente** por construcción (la rama adversaria es una cadena y todo
  ancestro es azul en su contexto) — tautología que la respuesta solo etiqueta, no corrige
  (`C4`) —, el denominador incluye el prefijo común (`C7`), no hay `c_x^∞` ni IC, y la red es Δ fija
  en slots (no DMS). v0.2 no mide `η` en absoluto y lo declara pendiente.
- **D7 · a medias.** Lo bueno: descriptores con `PotOrigin`, eventos y `N`; prefijos comparados en
  `slot(X)`; **todo** `past(B)`; máximo y suma separados; `S` flujos desde oportunidades
  compartidas; contraste **independiente** `mc_max_S` vs `identidad_iid_S` y controles de
  correlación (`:perfecta` recupera ramas idénticas; `:iid` varía). Lo que falta: (i)
  `ramas_aditivas` **sigue siendo** `S·α/(1−α+S·α)` y dos tests comparan la fórmula consigo misma
  (`toy_S_deriva(1/(S+1),S) ≈ 0`, `control_escalar_S(1/(S+1),S).raiz ≈ 1/(S+1)`) — el defecto
  original de v0.1 reaparece, aunque **acotado al toy** y no como validación del DAG; (ii) `N(s)` es
  constante y `autenticado = true` lo fija el fixture; (iii) el descriptor **no se deriva** de
  `past(B)`.
- **D8 · corregido.** `fixture_u2_u3` (mismo billete en ramas disjuntas → una copia `rojo_U3`),
  `fixture_u2_misma_rama` (U2 invalida), flujo divergente rechazado **antes** de colorear, color por
  contexto con `color_contextual`, y **no hay ningún `es_ancestro(x,x)`** (grep vacío). Orden
  explícito en `_anadir_bloque!`: R-FIN-5 → horizonte → U2 → GDR. **Matiz:** el caso de prefijos
  divergentes se comprueba como llamada a `compatible_rfin5`, no como intento de fusión dentro del
  simulador, y las dos ramas disjuntas son un fixture estático.
- **D9 · corregido.** `S` es escenario (`{1,2,4,8,16,24}`), el único microbenchmark es I/O de solo
  lectura sobre 64 MiB en `/tmp/opencode` con page cache caliente y cola 1, y `S_adversario` queda
  **pendiente** sin derivarse de 100 k IOPS. **Matiz:** el dataset se **crea** si falta (escritura
  de 64 MiB, no solo lectura) y `BENCH.txt` de v0.2 publica una sección de escalado sin medición
  (`B9`).
- **D10 · v0.2 a medias; v0.3 no lo trata.** v0.2 retira el enunciado «ataque gratis» y enumera los
  costes (espacio, CPU/PoT/IOPS, energía, recompensa renunciada, duración, hundido vs marginal), con
  la conclusión máxima «cero espacio plotteado adicional bajo los supuestos declarados»; **no
  cuantifica ninguno**. **v0.3 (el sucesor) no tiene sección de coste**: `grep -i "coste|gratis|
  iops|energía|espacio adicional"` sobre sus `*.md` solo encuentra `ENTRADA.md` (copia del encargo) y
  `PROPUESTA.md:33` (E3, como obligación futura). Es una **regresión** respecto de v0.2.

### 3.1 · Certificación exacta de la DP (comprobación propia)

`verificacion/dp_exacto.jl`, oráculo `prob_superar_finita` (`Rational{BigInt}`), 1 hilo:

- 18 celdas de `CORTO.txt`: peor error por arriba `5,662e-16`, peor `|conservación| = 1,155e-14`
  → **CERTIFICADO** `≤ 1e-12`.
- `α_prob` publicado `(0,39466261863708496, 0,39466267824172974)`: con `α' = ceil(a·2^40)/2^40`,
  `P(α') = 4,999994e-2 < p0`; con `α'' = floor(b·2^40)/2^40`, `P(α'') = 5,000002e-2 ≥ p0`. Como
  `P(superar)` es **creciente** en `α`, el cruce exacto `α* ∈ (α_inf, α_sup]`:
  **CERTIFICADO**.
- Orden exacto de los tres eventos para `z0=4, α=1/5, T=10,20`: `terminal ≤ paso ≤ eventual` **OK**.

*(Nota de método: mi primer intento de este certificado supuso `P` decreciente en `α` y salió
«INCONCLUSO». El error era mío, no del instrumento: `α` es la tasa del adversario, luego `P`
crece. Queda escrito porque es exactamente el tipo de comprobación que el encargo pide hacer.)*

---

## 4 · §2.3 · Los quince hallazgos de las revisiones internas

`REVISION-RESPUESTA.md` de v0.3 tiene **15 filas**. Los tres dictámenes de v0.3 contienen **28
hallazgos** (`REVISION-MATEMATICA.md` H1–H8 = 8; `REVISION-RUST.md` H1–H8 = 8;
`REVISION-JULIA.md` H1–H12 = 12). **Siete hallazgos no tienen fila de respuesta**: Rust H7 y H8;
Julia H5, H7, H8, H10 y H12. Comprobación hecha en el código y en el resultado citado, no en la
tabla:

| Fila | Revisor | Corrección declarada | ¿Verificado? | Veredicto |
|---|---|---|---|---|
| H1 | matemática | `W_pub`/`W_priv` post-fork respecto de `raiz_comun` | `dag_sim.jl:299-301,333-354`; `SWEEP-DAG.txt` 13/24 (y mi reejecución independiente da 13/24) | **corregido** |
| H2 | matemática | `:solo_inferior`/`:solo_superior`/`:indefinida`; nunca cruce con `0/n` | `eventos.jl:66-87`; `v3/test:30-42` | **corregido** |
| H3 | matemática | `α_prob` por `S` | `run.jl:80-96`; `SWEEP-DAG.txt` una línea `α_prob` por `S` | **corregido** |
| H4/H5 | matemática, Julia | texto corregido; no se llama frontera a `0/24` | `INFORME.md` §6-§7; `REVISION-RESPUESTA.md:27-28` | **corregido (texto)** |
| H6 | matemática, Rust | atajo por `flujo_id` → identidad de objeto **y** autenticación mutua | `flujo.jl:41` `flujo_B === flujo_X`; **es sólido**: para un `struct` inmutable `===` exige el mismo array `eventos`, luego el prefijo coincidiría igual | **corregido** |
| H7 | matemática | `η_a = 1,0` declarado inconcluso sin rojos | `ETA.txt` + `INFORME.md` §8, **pero `_eta_rama` no cambió** | **corregido solo en la etiqueta** |
| H8 | matemática | la semilla no depende de `d`; test escalar conservado | `run.jl:64` (la semilla no incluye `d`); `v3/test:44-55` | **corregido** |
| H1 | Julia | `s_max=150` deja de ser invisible: contador `rechazos[:gdr]` (`rgdr`) | `dag_sim.jl:183`; `run.jl:70`; `SWEEP-DAG.txt` `rgdr>0` en S=16 α=0,01 y S=24 α=0,04 | **corregido** |
| H3 | Julia | `horizonte_justificacion_ok` se aplica en `_anadir_bloque!` | `dag_sim.jl:169`; **pero la función es vacua** (`flujo.jl:55-59`) | **corregido a medias** |
| H1 | Rust | `C-NET-31/32` citadas como §2.7 → §16 | `MATRIZ-AUTORIDAD.md:46` (`SPEC.md` §16) | **corregido** |
| H2 | Rust | matriz no idéntica a v0.2 | cabecera corregida, **pero `:41` sigue citando `rfin5.jl`, que no existe en v0.3** | **corregido a medias** |
| H3 | Rust | `R-FIN-13′` como `SPEC vigente (acoplamiento)` | `MATRIZ-AUTORIDAD.md:43` | **corregido** |
| H4 | Rust | atajo semántico R-FIN-5 | remite a H6; ver arriba | **corregido** |
| H5 | Rust | aviso «autenticado no es cripto» | `INFORME.md:46-49`, `CONTRATO.md:38` | **corregido (aviso)** |
| H6 | Rust | escenario 3 reclasificado `Pendiente por C-GD-11` | `MATRIZ-VALIDEZ.md:7` (v3) | **corregido** |

**Los dos que el encargo señalaba, en concreto:**

- **El atajo por `flujo_id` (H6) está bien cerrado.** El código ya no compara identificadores:
  `flujo.jl:41` exige `flujo_B.autenticado && flujo_X.autenticado && flujo_B === flujo_X`. Para un
  `struct` inmutable, `===` es igualdad campo a campo con el vector `eventos` comparado por
  identidad de objeto: si se cumple, ambos descriptores comparten literalmente el mismo array, luego
  los prefijos coinciden para todo slot y el atajo **nunca** puede devolver `VALIDA` donde la
  comparación completa daría `INVALIDA`. Es redundante, no una relajación.
- **«`η_a = 1,0` tautológico» (H7) no se corrigió: se etiquetó.** `_eta_rama`
  (`v3/src/dag_sim.jl:240-252`) no cambió. La rama adversaria es una cadena —cada bloque nuevo toma
  como padres **todas** las puntas de su rama (`:307-310`)—, todo bloque es ancestro de su punta y
  todo ancestro es azul en ese contexto, así que numerador = denominador y `η_a = 1` **exacto**.
  `ETA.txt` (1,0000 en las tres α) y `CORRELACION.txt` (`[1.0,1.0,1.0,1.0]` en los tres modos) lo
  confirman, y el propio revisor Julia (H9) lo había demostrado. La respuesta de v0.3 lo declara
  «inconcluso sin rojos», que es honesto, pero **la magnitud publicada sigue siendo una identidad**.

**Los siete sin fila de respuesta** (comprobados por mí, siguen vigentes): Rust H7 (la matriz no
cita nunca `ci/reglas-sin-cablear.txt` ni `ci/consenso-pendiente.txt`) · Rust H8 («`BW256` en GDR»
es impreciso, `:13`; estado no admitido, `:28`) · Julia H5 (`η` con prefijo común) · Julia H7
(objeto `:solo_cota_superior`; **el código actual ya no tiene el no-op** que describe, la
reescritura de H2 lo eliminó) · Julia H8 (evidencia mal citada: `INFORME.md:17` sigue citando
`SWEEP-DAG.txt` para la fusión) · Julia H10 (**no hay mutation tests**) · Julia H12 (el
`HIPOTESIS…` de v0.3 es el de v0.2). Detalle en `DEFECTOS.md` B3–B8, C5–C8.

---

## 5 · §2.4 · Lo que ha cambiado en el SPEC desde el 2026-09-18

`C-FLU-13` (validez absoluta) y `C-FLU-14` (pasado consistente de flujo) están **redactadas** en
`SPEC.md` §7.1.5, líneas **1699-1731**, por decisión de Katana del 2026-09-19/20; su nota en
§7.1.5 dice explícitamente que con validez absoluta «el multistream queda cerrado». El texto
literal está en `notas/spec-tareas-matrices.md` (PARTE A).

### 5.1 · ¿Es `src/flujo.jl` de v0.3 fiel a `C-FLU-14`?

**Coincide en:**

1. **El predicado.** `compatible_rfin5(flujo_B, flujo_X, slot_X)` compara
   `prefijo_flujo(B, slot_X)` con `prefijo_flujo(X, slot_X)` → exactamente
   `flujo(X, slot(X)) == flujo(B, slot(X))` evaluado en el slot de `X` (`flujo.jl:39-48`).
2. **La cobertura.** `_anadir_bloque!` recorre **todo** `past(B)`, no solo los padres
   (`dag_sim.jl:158-166`), y una divergencia **posterior** no invalida el pasado común (test:
   compatible en slot 5, incompatible en 15).
3. **El orden.** R-FIN-5 va **antes** de U2 y de colorear (`dag_sim.jl:159-185`), como pide «el paso
   1b de `C-POT-08`».
4. **El estado intermedio.** Un descriptor no autenticado da `PENDIENTE`, nunca `true`
   (`flujo.jl:46`), y `PENDIENTE` no se mezcla con `INVALIDA`.

**NO coincide en:**

1. **`flujo(B, ·)` no se deriva de `past(B)`.** En el SPEC, `flujo` es el identificador de 32 bytes
   derivado del pasado y `C-FLU-11` prohíbe declararlo. En v0.3 es un `DescriptorFlujo` que viaja en
   el bloque y que el productor construye: `construir_flujo` fija `pot_origin="ZEROX-PoAS"`,
   `dominio="ZEROX-v0"` y **`autenticado=true`** (`flujo.jl:66-80`). El instrumento reproduce la
   **forma** de la comprobación, no la regla. Su propio `INFORME.md:43-49` lo dice.
2. **La condición de `Pendiente` es otra.** `C-FLU-14` dice «si el nodo no tiene todo `past(B)`»;
   v0.3 devuelve `PENDIENTE` cuando el **descriptor** no está autenticado. El simulador nunca
   modela «falta pasado»: siempre tiene lo que referencia.
3. **`N(s)` es constante.** `construir_flujo` pone `N = N0` en todos los eventos (`flujo.jl:72`), así
   que la parte de `C-FLU-14`/D7 que depende de `N_efectivo` variable no se ejercita.
4. **El horizonte de justificación es vacuo** (`flujo.jl:55-59`): devuelve `VALIDA` con solo
   «autenticado» y `slot_B ≥ slot_sp`; no comprueba que los eventos de `(slot_sp, slot_B]` sean
   conocidos, como promete su docstring.
5. **No hay PoT AES**: la parte (1) y (2) de `C-FLU-13` (solución PoAS bajo `reto(flujo(B,slot(B)))`
   y justificación de PoT bajo el mismo flujo) no se ejecuta en absoluto.

En una frase: **el esqueleto lógico es el de `C-FLU-14`; la semántica de `flujo` no.** El
instrumento puede decir «compatibilidad estructural de flujo», no «`C-FLU-14` verificada».

### 5.2 · Qué filas de las matrices cambiarían con el SPEC de hoy

**No las he editado.** Tabla de cambios (v0.3; entre paréntesis, la fila equivalente de v0.2):

| Fichero:línea | Dice hoy | Debería decir | Motivo |
|---|---|---|---|
| `MATRIZ-AUTORIDAD.md:39` | R-FIN-2/3 **candidata** | **`SPEC vigente`** (C-FLU-10/11/12) | §7.1.2-§7.1.4 escritas |
| `MATRIZ-AUTORIDAD.md:40` | R-FIN-4 validez absoluta **candidata** | **`SPEC vigente`** (C-FLU-13), con la nota de que el instrumento **no** la puede acreditar | `SPEC.md:1701-1716` |
| `MATRIZ-AUTORIDAD.md:41` | R-FIN-5 **candidata** | **`SPEC vigente`** (C-FLU-14); integración `flujo.jl`, **no** `rfin5.jl` | `SPEC.md:1718-1731`; `rfin5.jl` no existe en v0.3 |
| `MATRIZ-AUTORIDAD.md:44` | R-FIN-14 reto por slot **candidata** | **`SPEC vigente`** (C-POT-01/02, C-FLU-07/12/16) | §7.1.1-§7.1.3 |
| `MATRIZ-AUTORIDAD.md:45` (v0.3) / `:45` (v0.2) | R-FIN-7 finalidad **candidata** / `F` provisional | **`SPEC vigente`** como `C-FIN-01` (§12); valores `I/F/L_suelo/ρ_max` **pendientes** | `SPEC.md:2532-2570` |
| `MATRIZ-AUTORIDAD.md:43` (v0.2) | R-FIN-13′ **candidata** | ya corregida en v0.3 a `SPEC vigente (acoplamiento)` | v0.2 sigue desactualizada |
| `MATRIZ-AUTORIDAD.md` (A/B) | **no aparece ninguna** regla `C-POT-*`, `C-FLU-*`, `C-FIN-01`, `C-NET-33` | añadir las **31 reglas** nuevas con estado e integración («sin código») | `TAREAS.md:143-156` |
| `MATRIZ-VALIDEZ.md:8` (v3) / `:11` (v2, texto distinto) | escenario «candidato R-FIN-5» = **«Válida estructural»** | **`Pendiente`**: flujo **declarado**, no derivado (C-FLU-10/11), y PoT AES no integrado (C-FLU-13(1)(2)) | `SPEC.md:1701-1731` |
| `MATRIZ-VALIDEZ.md:12` (v2) / `:9` (v3) | contrafactual aditivo | igual, **más**: «excluido como regla por C-FLU-14» | `SPEC.md:1709-1716` |
| `MATRIZ-VALIDEZ.md:13` (v2) / `:10` (v3, fila «Observador veterano») | régimen largo / veterano **Pendiente** | igual, con el motivo actualizado: **`C-FIN-01` escrita, valores sin elegir y Δ sin medir** | `SPEC.md:2532-2570` |

**No cambian** (siguen como están): todas las filas `SPEC vigente` de GHOSTDAG y orden
(C-GD-01…10, C-ORD-01…04); `C-GD-11` («SPEC vigente, 5 pendientes»); `C-HDR-05/06/07`; R-FIN-1a;
R-FIN-11; `C-NET-31/32` («valores pendientes»); `ghostdag.rs` («implementada sin cablear»);
`fork_choice.rs`; GDR-v0.2 («oráculo abstracto»); DAV/CBE/DA0/DCM/DMS («oráculo abstracto»); el
controlador del SPEC («pendiente»: la ventana sigue sin escribirse); RCE/ARM; `F = 2 h`; poda/IBD
sucinto; y **todos** los estados de v0.2 que v0.3 ya había corregido.

### 5.3 · ¿Cambia alguna conclusión de v0.3, o solo su etiqueta?

**Solo su etiqueta, y una conclusión se debilita.**

- **Ninguna cifra cambia.** `C-FLU-13/14` no tocan la aritmética ni el simulador. La frontera
  medida (que en realidad no existe para R-FIN-5), los eventos, los barridos y las eficiencias se
  quedan igual.
- **Cambia la etiqueta de R-FIN-5**: de «candidata» a **regla vigente**. Con eso, el escenario que
  v0.3 llama «Válida estructural» pasa a ser **`Pendiente`**, porque la regla vigente exige además
  que `flujo(B,·)` se derive del pasado y que el PoT verifique bajo ese flujo, y el instrumento no
  hace ninguna de las dos cosas.
- **Se debilita el contrafactual aditivo**: `C-FLU-13` cierra el multistream **por decisión del
  protocolo**, no por una medición. El titular «`α = 1/(S+1)` = 0,040 con `S=24`» deja de describir
  una opción del diseño vigente y pasa a describir un modelo escalar que **ninguna regla autoriza**.
  Es exactamente el cambio que el encargo pide recoger en `BASELINE.md`.
- **El veredicto global no cambia**: el controlador `C-HDR-06`, el verificador PoT, los cinco
  pendientes de `C-GD-11`, la elección de `I/F/L_suelo/ρ_max` y `S_adversario` siguen abiertos; el
  umbral protocolario sigue **inconcluso**.

---

## 6 · §2.5 · Trampas que este repositorio ya ha pisado

| Trampa | ¿La pisaron v0.2/v0.3? | Evidencia |
|---|---|---|
| **Semillas consecutivas de `StableRNG` sesgan el Monte Carlo** (hallazgo de `P-ZRX/P-PUERTA/`) | **Sí, las dos.** `StableRNG(SEMILLA + r)` en `v2/run.jl:136,152` y `v3/run.jl:64,151` | Medido: autocorrelación lag-1 **−0,4276** (1.ª salida) y **+0,7066** (2.ª) frente a ≈0 con contracorriente; control Bernoulli(0,5) con `Var_obs/Var_binom = 0,08` y correlación por pares hasta **+0,920**. Efecto sobre las cifras publicadas: **no determinado** (ratio 0,87 vs 1,18 en 120 bloques). `DEFECTOS.md` A1-A2 |
| **Celdas `0/n` presentadas como frontera** | v0.3 lo evita (`alpha_prob_simultaneo` devuelve `:solo_superior`/`:indefinida`, y se dice). v0.2 **a medias**: publica las celdas con su cota superior, pero titula «**Frontera MEDIDA** por escenario» mientras **las 9 celdas R-FIN-5 son 0/64** | `v2/INFORME.md:28-30,98`; `v2/resultados/DAG.txt`; `v3/resultados/SWEEP-DAG.txt` |
| **Cotas de búsqueda finita como cotas sobre todas las estrategias** | **No.** Los dos declaran «no optimalidad» y «no hay demostración de exhaustividad» | `v2/INFORME.md:96`; `v3/CONTRATO.md:36-40` |
| **«Autenticado» usado para algo que no es criptografía** | **Sí, nombrado pero no eliminado.** El campo `autenticado::Bool` lo fija el fixture (`flujo.jl:19,79`), y el DAG lo pone a `true` siempre | `v3/INFORME.md:46-49` lo declara; `DEFECTOS.md` D-c |
| **Rejillas gruesas de `α` invertidas sin comprobar monotonía** | **No.** v0.2 `invertir_monotona` comprueba monotonía y devuelve `nothing`; v0.3 devuelve `:indefinida`. **Matiz:** la tolerancia `d < -1e-12` deja pasar ondulaciones menores | `dp.jl:131-156` / `:184-215`; `v3/resultados/SWEEP-DAG.txt` (todas las filas `:indefinida`/`:solo_superior`) |
| **Comparar una fórmula consigo misma** (el defecto original de D7) | **Sí, en el toy.** `toy_S_deriva(1/(S+1),S) ≈ 0` y `control_escalar_S(1/(S+1),S).raiz ≈ 1/(S+1)` comparan la identidad lineal con su propia solución; v0.2 `REVISION-RESPUESTA.md:26-27` ya lo admite como límite. **No** en el DAG: allí el máximo y la suma se **miden** | `v2/test:151-155,172-176`; `v3/test:173-175` |
| **«Medido» para algo no medido** | **Sí, en dos sitios.** El «escalado 1..8 hilos» de `v2/BENCH.txt` (sin medición) y el «drenaje terminal» de `v3/INFORME.md:20` | `DEFECTOS.md` B8, B9 |

---

## 7 · Veredicto por escenario

| Escenario | Estado | Frase de cierre admisible |
|---|---|---|
| Baseline analítico | **demostrado** | `α_drift = 1/2` es identidad del baseline; DP certificada con error ≤ `1e-12` |
| SPEC actualmente escrito | **inconcluso** | controlador (ventana), PoT, C-GD-11 y finalidad pendientes; 31 reglas sin código |
| DAG con red | **medido** para rojos/anticones; **inconcluso** para la frontera y `η` | rojos reales (0,943–1,000 a `k=2`); celdas R-FIN-5 `0/n`; `η_a` tautológico |
| Filtro de flujo hoy `C-FLU-14` | **SPEC vigente**; el instrumento da **compatibilidad estructural**, `Pendiente` como acreditación | coincide el predicado y el orden; no la derivación de `flujo` ni el PoT |
| Contrafactual aditivo | **contrafactual, no regla**; única señal positiva | excluido como regla por `C-FLU-14` |
| Regímenes corto y largo | corto **demostrado/medido**; largo **inconcluso** | falta `c_x^∞`, `η_x^∞`, `F` y Δ de red |
| **Global** | **inconcluso** | «Umbral protocolario inconcluso; el baseline idealizado no sustituye las reglas pendientes» |

---

## 8 · Lo que esta auditoría NO resuelve

1. **No valida v0.2 ni v0.3 como instrumentos**: los audita. No he migrado ni corregido nada.
2. **No decide la pregunta de `P-ZRX/P-CRP1/`** (si los diez defectos son reales en el código de
   CRP-v0.1 y cuánto mueven sus cifras): su `INFORME.md` no existía.
3. **No mide el efecto de las semillas consecutivas sobre las cifras publicadas.** Demuestro que el
   defecto existe y que el supuesto iid es falso; el sesgo de los recuentos publicados queda
   `no determinado`.
4. **No re-deriva los barridos con un RNG contracorriente** (solo una celda, S=4, α=0,20).
5. **No mide `η_h`/`η_a` con muestra de rojos** ni con la definición de D6 (post-fork, por
   contexto). La diferencia «prefijo común sí/no» la cita el revisor Julia (0,994253 vs 0,994186),
   no la he reproducido.
6. **No mide `S_adversario`** ni ningún componente de hardware (I/O con colas, PoAS/KZG, PoT por
   slot). El microbenchmark que reejecuté es de page cache caliente y cola 1.
7. **No verifica las fuentes upstream** (`PDF/`, `auditing.rs`, `proving.rs`, el reloj PoT) ni el
   Rust de `crates/zx-consensus/src/ghostdag.rs`: solo compruebo lo que los instrumentos **dicen** de
   ellas en sus matrices.
8. **No audita los contratos candidatos** (`retarget-causal-endogeno-v1`,
   `admision-retarget-multivista-v1`, `dominio-autorizacion-v1`, `contrato-billete-v1`,
   `delta-medido-v1`): acepto o rechazo las filas de las matrices según el SPEC, sin abrir cada
   contrato.
9. **No certifica el simulador DAG** con aritmética exacta (solo la DP). Los recuentos de rojos y
   las diferencias de `blue_work` son enteros exactos, pero la topología y el calendario no tienen
   oráculo independiente más allá de GDR.
10. **No decide si `C-FLU-13/14` son la decisión correcta.** Solo compruebo qué se sigue de ellas
    para estos instrumentos.
11. **No he leído íntegros `README.md`, `MIGRACION.md`, `research/*` ni las §7.2-§7.3 y §11 del
    SPEC**: he leído `AGENTS.md`, `veritas/LINEO.md` (íntegro), las secciones citadas del SPEC
    (§6.1, §7.1, §12, §17), `TAREAS.md` §2.1 y §2.9 (e), el encargo 07v2 íntegro y el código de los
    dos instrumentos. Donde he citado una línea, la he abierto.
12. **No fijo ningún parámetro de consenso** ni propongo números para el SPEC.
