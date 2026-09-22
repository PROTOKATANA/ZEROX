# P-CRP · DEFECTOS — cada defecto con su entrada mínima reproducible

**Alcance:** CRP-v0.2 (`P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/`) y CRP-v0.3
(`…/coste-rama-privada-v3/`), reejecutados desde `P-ZRX/P-CRP/auditoria/copia/` con **una sola**
modificación: la ruta absoluta de GDR en `src/gdr_wrapper.jl` (diff en `PROGRESO.md` §3).

Las rutas `deepseek/…` que aparecen dentro de los instrumentos hoy son `P-ZRX/rescate-deepseek/…`.

**Etiquetas:** `demostrado`, `verificado en fuente`, `reproducido`, `medido`, `derivado`,
`estimado`, `no determinado`.

Comandos de referencia (desde `P-ZRX/P-CRP/auditoria/`), con `J=env -u LD_LIBRARY_PATH
/home/katana/torio/.juliaup/bin/julia`:

```bash
cd copia/coste-rama-privada-v2 && $J --check-bounds=yes --project=. test/runtests.jl
cd copia/coste-rama-privada-v2 && $J --project=. run.jl --seed 0x5a5a --replicas 64
cd copia/coste-rama-privada-v3 && $J --check-bounds=yes --project=. test/runtests.jl
cd copia/coste-rama-privada-v3 && $J --project=. run.jl --seed 0x5a5a --replicas 24
$J --project=copia/coste-rama-privada-v3 verificacion/semillas.jl
$J --project=copia/coste-rama-privada-v3 verificacion/diagnostico.jl
$J --project=copia/coste-rama-privada-v3 verificacion/dp_exacto.jl
```

---

## A · Reproducibilidad y aleatoriedad

### A1 · Las réplicas se derivan con semillas **consecutivas** de `StableRNG`

- **Instrumentos:** v0.2 y v0.3.
- **Ubicación:** `copia/coste-rama-privada-v2/run.jl:136` (`StableRNG(SEMILLA + x)`), `:152`
  (`StableRNG(SEMILLA + 1000r + S + d)`); `copia/coste-rama-privada-v3/run.jl:64`
  (`StableRNG(SEMILLA + UInt64(r))`), `:151`; y los tests con `StableRNG(100 + r)` /
  `StableRNG(2000 + r)`.
- **Qué exige el repositorio:** `P-ZRX/P-PUERTA/veritas/consenso/puerta-cobertura-v1/PROGRESO.md:228-235`
  documenta que `StableRNG(semilla + i)` con `i` consecutivo «**no da flujos independientes**» y
  `…/METODO.md:116-118` prohíbe expresamente «*No usar `StableRNG(semilla + id)`*». `veritas/LINEO.md`
  §5.1 reserva `StableRNGs` para *fixtures* y prefiere `Random123` para réplicas (§5.1, §7).
- **Entrada mínima reproducible:** `verificacion/diagnostico.jl` §1–§2, §4
  (salida en `registros/semillas.txt`).
- **Medido (1 hilo, carga ajena < 3,5):**
  - autocorrelación lag-1 de la secuencia de uniforms entre semillas consecutivas:
    **−0,4276** (1.ª salida) y **+0,7066** (2.ª salida); con contador de Philox **+0,0013 / −0,0017**
    (referencia iid ±0,0095, n = 100 000).
  - control puro Bernoulli(0,5), 200 bloques × 24 réplicas: `Var_obs/Var_binom` = **0,08** con
    correlación por pares entre **−0,040** y **+0,920**; el esquema contracorriente da **1,06** y
    |ρ| ≤ 0,19. Es decir: las 24 «réplicas» **no son 24 muestras independientes**.
- **Qué conclusión toca:** la validez nominal de los intervalos de Wilson publicados
  (`resultados/DAG.txt`, `resultados/SWEEP-DAG.txt`, `resultados/ETA.txt`) y la frase «el barrido de
  réplicas es determinista por semilla de réplica; la reducción es ordenada por ID, de modo que 1..N
  hilos dan el mismo resultado» (`resultados/BENCH.txt` de v0.2): ser determinista no es ser
  independiente.
- **Cuánto mueve:** **no determinado** sobre las cifras publicadas. En la celda publicada
  S=4, α=0,20, T=200, Δ=2, k=30, suma terminal d=0 (la que `SWEEP-DAG.txt` da como 13/24), con
  120 bloques × 24 réplicas: `Var_obs/Var_binom` = **0,87** con las semillas publicadas y **1,18**
  con contracorriente; el mismo bloque con semillas publicadas reproduce **13/24** y con
  contracorriente da **14/24**. Con 120 bloques no se distingue de la binomial: **no se puede
  declarar sesgo demostrado ni inocuidad**. Lo que sí queda demostrado es que el supuesto iid del IC
  es falso.
- **Estado:** defecto de método `medido`; su efecto sobre las cifras `no determinado`.

### A2 · Trampa de la derivación contracorriente (advertencia para la migración)

- **No es un defecto de v0.2/v0.3** (no usan `Random123`): es un error que cometí al escribir la
  comprobación y que conviene dejar escrito, porque `veritas/LINEO.md` §7 recomienda este esquema sin
  dar la derivación correcta.
- **Entrada mínima:** `verificacion/diagnostico.jl` §4. Con `set_counter!(r, id)` —una sola palabra—
  el flujo `id=2` es el `id=1` **desplazado una salida** (`0,797361 0,119669 0,066330…` frente a
  `0,066330 0,949363 0,436354…`); el ratio de sobredispersión del estadístico del simulador sube a
  **20,11**. La forma correcta es `set_counter!(r, (0, id))`.
- **Qué toca:** cualquier migración futura que adopte `Random123` siguiendo LINEO §5.1/§7.
- **Estado:** `medido`.

---

## B · Cifras y citas que no se sostienen

### B1 · v0.2 publica intervalos de Wilson de **40 réplicas** como si fueran los de 64

- **Ubicación:** `copia/coste-rama-privada-v2/INFORME.md:54` («IC95 (0.912, 1.000)») y
  `copia/coste-rama-privada-v2/MATRIZ-VALIDEZ.md:27-28` («IC (0.912,1.0)» y «IC sup 0.088»).
  Los valores de `resultados/DAG.txt` son **0,943–1,000** (k=2) y **0,057** (k=30), con 64 réplicas.
- **Entrada mínima:** Wilson de 64/64 y de 0/64 frente a 40/40 y 0/40
  (`J -e '…'`, salida en `registros/` — recalculado aquí):

  | n | k=n ⇒ límite inf. | k=0 ⇒ límite sup. |
  |---|---|---|
  | 40 | 0,9123754607496077 | 0,08762453925039232 |
  | 64 | 0,9433739770288436 | 0,056626022971156334 |

  Es decir, `0,912` y `0,088` son exactamente los valores de `n = 40`.
- **Qué conclusión toca:** el único recuento de rojos que se cita fuera de `DAG.txt`; y la frase
  «frontera medida».
- **Cuánto mueve:** 0,031 en cada límite. No cambia el signo ni la lectura cualitativa, pero **una
  cifra publicada no se reproduce** con el artefacto que se cita como fuente.
- **Estado:** `reproducido` (el desajuste).

### B2 · La lista de hipótesis de v0.3 es la de v0.2, byte a byte

- **Ubicación:** `copia/coste-rama-privada-v3/HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md`.
- **Entrada mínima:** `diff copia/coste-rama-privada-v2/HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md
  copia/coste-rama-privada-v3/HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md` → **sin diferencias**.
  El fichero de v0.3 se titula «CRP-v0.2» (línea 1) y su columna de tratamiento se llama
  «Tratamiento en v2» (línea 7).
- **Qué conclusión toca:** el entregable que el encargo §6 exige para que ninguna cifra se lea como
  hallazgo. Faltan las tautologías propias de v0.3: `η_a ≡ 1`, semillas consecutivas, `autenticado`
  fijado por el fixture, α como tasa de oportunidad, rojos por unión de contextos.
- **Cuánto mueve:** no cambia ninguna cifra; cambia lo que el instrumento declara de sí mismo.
- **Estado:** `reproducido`.

### B3 · v0.3 cita un fichero que no existe en v0.3

- **Ubicación:** `copia/coste-rama-privada-v3/MATRIZ-AUTORIDAD.md:41` → «Integración: `rfin5.jl`
  (estructural)». `src/rfin5.jl` solo existe en v0.2; en v0.3 el equivalente es `src/flujo.jl`
  (`diff -rq` de los dos `src/` lo confirma).
- **Entrada mínima:** `diff -rq copia/coste-rama-privada-v2/src copia/coste-rama-privada-v3/src`
  → «Sólo en …-v2/src: rfin5.jl».
- **Qué toca:** la fila H2 del revisor Rust («matriz idéntica a v0.2») no se corrigió del todo.
- **Estado:** `verificado en fuente`.

### B4 · «`BW256` en GDR» es falso para el acumulador

- **Ubicación:** `copia/coste-rama-privada-v3/MATRIZ-AUTORIDAD.md:13` (heredado de v0.2:12).
- **Hecho:** GDR acumula `blue_work` en `BigInt`
  (`veritas/consenso/ghostdag-rank-v1/src/referencia.jl:229-232`); `BW256` es solo el peso por
  bloque (`…/modelo.jl:74-83`). Señalado por el revisor Rust (H8 de v0.3) y **sin fila** en
  `REVISION-RESPUESTA.md`.
- **Estado:** `verificado en fuente`.

### B5 · Estados normativos fuera del catálogo

- **Ubicación:** `copia/coste-rama-privada-v3/MATRIZ-AUTORIDAD.md:28` → «ruta activa (PoW lineal)»,
  que no es uno de los siete estados admitidos por el encargo §0 ni por la cabecera del propio
  fichero (líneas 3-4). Heredado; señalado por Rust H8; sin respuesta.
- **Estado:** `verificado en fuente`.

### B6 · Validez trivaluada declarada y cuatrivaluada usada

- **Ubicación:** `copia/coste-rama-privada-v2/MATRIZ-VALIDEZ.md:3` («`Válida`, `Inválida`,
  `Pendiente` **o `Contrafactual`**») y fila 12; `copia/coste-rama-privada-v3/MATRIZ-VALIDEZ.md:8`
  («**Válida estructural**») y fila 9 («**Contrafactual, no regla**»), frente a
  `MATRIZ-AUTORIDAD.md:5-6` de ambos («Validez de traza (trivaluada)»).
- **Lo único corregido** por la fila «Rust5» de la respuesta de v0.2 fue el `@enum Validez`
  (`src/modelo.jl:12`), que ya era trivaluado; los documentos siguen usando cuatro etiquetas.
- **Estado:** `verificado en fuente`.

### B7 · Evidencia mal citada, sin corregir

- **Ubicación:** `copia/coste-rama-privada-v3/INFORME.md:17` cita `SWEEP-DAG.txt` como evidencia de
  «Fusión público+rama divergente»; ese fichero no contiene ningún dato de fusión. La prueba está en
  `test/runtests.jl:91-93`. Señalado por el revisor Julia (H8) y **sin fila** en la respuesta.
- **Estado:** `reproducido` (el contenido de `SWEEP-DAG.txt` no menciona fusiones).

### B8 · «Medido» sin medición: drenaje terminal

- **Ubicación:** `copia/coste-rama-privada-v3/INFORME.md:20` («`Δ=0` real y drenaje terminal |
  **medido**»).
- **Hecho:** `_drenar_todo!` (`src/dag_sim.jl:218-224`) llena `sim.vista`, pero `W_pub`, `W_priv`,
  los recuentos de color y `_decisiones` leen el estado de GDR y `sim.bloques`, no `vista`; el
  drenaje terminal no cambia ninguna cifra publicada (lo dice el propio
  `REVISION-RESPUESTA.md:30-31`). Ningún test lo cubre.
- **Estado:** `verificado en fuente` + `reproducido`.

### B9 · Tabla de escalado sin medición (solo v0.2)

- **Ubicación:** `copia/coste-rama-privada-v2/bench/benchmarks.jl:29-35` imprime
  «Escalado de réplicas independientes (barrido MC) 1..8 hilos» y cuatro líneas de texto, sin ningún
  `@benchmark` con hilos; `resultados/BENCH.txt` lo publica. v0.3 eliminó la sección y declara «el
  simulador es serial y determinista».
- **Hecho relacionado:** ninguno de los dos instrumentos usa `Threads` (grep vacío fuera de
  `run.jl:36-37` / `:20`, que solo imprimen `nthreads`). Mi comprobación: hashes del directorio
  `resultados/` (sin `ENTORNO.txt`) idénticos con 1, 2, 4 y 8 hilos (`registros/determinismo-hilos.txt`).
- **Estado:** `reproducido`.

---

## C · Correcciones del encargo que no están

### C1 · **D4 no implementado**: no existe la derivación PoAS

- **Ubicación:** todo `src/` de v0.2 y v0.3.
- **Entrada mínima:** `grep -rni "chunk\|sector\|distancia\|solution_range\|ganador"
  copia/coste-rama-privada-v{2,3}/src` → **0 líneas**.
- **Qué hay en su lugar:** α entra como **probabilidad de oportunidad por slot**
  (`ConfigSim.p_adversario`, `ConfigSimV3.alpha` → `oportunidades_compartidas`, `src/dag_sim.jl:100-114`
  de v0.3) y el peso es `⌊2^128/(SR+1)⌋` con `sr_constante` (`dag_sim.jl:181,188`).
- **Qué conclusión toca:** todas las α de v0.2 y v0.3 son **tasas por slot**, no fracciones de
  espacio. La pregunta principal del encargo («para una fracción adversaria de **espacio** α») queda
  sin contestar: falta el puente espacio→tasa.
- **Y una afirmación falsa:** `copia/coste-rama-privada-v2/HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md:9`
  (H1) dice «La probabilidad discreta **se deriva** de las reglas PoAS (distancia circular,
  `sd ≤ SR/2`, chunks ganadores)». No hay tal código en ninguno de los dos instrumentos.
- **Estado:** `no corregido`; la afirmación en contrario es `refutada en fuente`.

### C2 · **D5 a medias**: RCE existe aislado, no se integra

- **Lo que sí:** el controlador del SPEC queda `Pendiente` identificando la ventana
  (`resultados/RCE.txt`); `src/controlador_rce.jl` reproduce RCE rev2 (+Z0) y deriva `R` de `N_j`
  con enteros `BigInt`.
- **Lo que no:** `_anadir_bloque!` (`v3/src/dag_sim.jl:156-191`) **no llama** a RCE; cada bloque
  lleva `sr = cfg.sr_constante` (líneas 181, 188); no se ejecuta ninguna admisión de rango antes de
  entregar a GDR; no hay conjunto pagable/`counted`.
- **Qué conclusión toca:** la única «derivación de `SR`» del instrumento es un fixture de test; la
  frase «RCE rev2 (+Z0) **deriva `SR`** en perfil candidato» (`INFORME.md` de v0.2, tabla §0) es
  cierta **solo** dentro del test unitario, no en el DAG.
- **Estado:** `corregido a medias`.

### C3 · §3.2 sin implementar: no hay conjunto pagable

- **Exigía:** separar identidad de solución, identidad U2/U3, coordenada de oportunidad y derecho
  pagable; el controlador debe consumir el conjunto que su contrato declare (R-FIN-13′: azules y
  `rojo_k`, excluyendo `rojo_U3`).
- **Hecho:** `W_pub`/`W_priv` se calculan solo desde `blue_work` (`v3/src/dag_sim.jl:333-354`); no
  existe ningún conjunto pagable en el código.
- **Estado:** `no corregido` (no declarado como límite en `REVISION-RESPUESTA.md`).

### C4 · **H7 real**: `η_a ≡ 1` es tautológico, y sigue siéndolo

- **Ubicación:** `v3/src/dag_sim.jl:240-252` (`_eta_rama`).
- **Demostración (derivada del código):** la rama adversaria es una cadena: cada bloque nuevo toma
  como padres **todas** las puntas vivas de su propia rama (`:307-310` con `_tips_rama`), luego todo
  bloque de la rama es ancestro de su punta; y en GHOSTDAG todo ancestro de una punta está en su
  `blueset`. Por tanto numerador = denominador y `η_a = 1` **exactamente**, para toda réplica.
- **Evidencia reproducible:** `resultados/ETA.txt` (η_a = 1,0000 en las tres α con 0 rojos) y
  `resultados/CORRELACION.txt` (`η_a=[1.0,1.0,1.0,1.0]` en los tres modos de correlación).
- **Lo que se hizo:** `REVISION-RESPUESTA.md:14,29` lo declara «inconcluso sin rojos». **No cambia la
  definición**; el numerador sigue siendo idéntico al denominador por construcción.
- **Qué conclusión toca:** la fila «η_h≈0.99, η_a=1.0» de `INFORME.md:23` no mide eficiencia
  adversaria; mide una identidad.
- **Estado:** `corregido a medias` (etiqueta sí, código no).

### C5 · Los rojos se cuentan como **unión de contextos**

- **Ubicación:** `v3/src/dag_sim.jl:357-365`: `set_r` recorre `sim.dag.est.gd[i].tipos` para **todos**
  los `i` del DAG; un bloque que es azul en la punta elegida y `rojo_k` en otro contexto se cuenta
  igualmente como rojo. Lo mismo para `rojos_h`/`rojos_a`, que además son la entrada de η.
- **Qué exige:** el encargo §0 y D8 piden el color **por contexto** `(punta/fusionador, bloque)`;
  `color_contextual` existe y se usa en los fixtures, pero no en el recuento del barrido.
- **Señalado por** el revisor Julia (H9 de v0.3) y **sin fila** en `REVISION-RESPUESTA.md`.
- **Cuánto mueve:** `no determinado` (no separé los dos recuentos).
- **Estado:** `verificado en fuente`.

### C6 · El «horizonte de justificación» está cableado pero es vacuo

- **Ubicación:** `v3/src/flujo.jl:55-59`. El docstring promete que «todos los eventos del descriptor
  en `(slot_sp, slot_B]` deben ser conocidos»; el cuerpo solo comprueba `fl.autenticado` y
  `slot_B >= slot_sp`, y devuelve `VALIDA`. Se invoca en `dag_sim.jl:169`.
- **Qué conclusión toca:** la fila H3 de Julia («era código muerto») queda cerrada en el cableado,
  no en el contenido: ninguna traza puede ser `INVALIDA` por este camino.
- **Estado:** `corregido a medias`.

### C7 · `η` no excluye el prefijo común

- **Ubicación:** `v3/src/dag_sim.jl:240-252` (denominador = **todos** los bloques válidos del lado).
- **Contra:** D6 exige «excluye el prefijo común». El revisor Julia (H5) midió la diferencia como
  inmaterial (0,994253 vs 0,994186) pero la definición publicada no es la declarada. Sin fila en la
  respuesta.
- **Estado:** `verificado en fuente`; efecto `inmaterial` (`estimado` por el revisor, no verificado
  por mí).

### C8 · No hay *mutation tests*

- **Exigía** (encargo §4): «mutation tests fallan al introducir deliberadamente `≥` por `>`, suma por
  máximo, color global, aceptación post-divergencia incompatible o renormalización de masa truncada».
- **Hecho:** los testsets titulados «mutación» (`v2/test/runtests.jl:178-186`,
  `v3/test/runtests.jl:181-186`) **comparan valores ya calculados** (`prob_empate_dp` vs
  `prob_superar_dp`, `cota_union([0.6,0.7])[2] == 1.0`); no mutan ninguna función. Señalado por
  Julia H10; sin fila en la respuesta.
- **Qué conclusión toca:** el criterio 6 de §5 y la comprobación obligatoria de §4 no están
  satisfechos.
- **Estado:** `no corregido`.

### C9 · La DP puede devolver una corrida **no certificada** sin decirlo

- **Ubicación:** `v2/src/dp.jl:96-99` y `v3/src/dp.jl:96-99`: si `proximo > max_ancho` devuelve `r`
  aunque `r.masa_fuga > tol`, sin marcador de «no certificado». El llamador no puede distinguir una
  corrida dentro de tolerancia de una truncada.
- **Cuánto mueve:** ninguno en la rejilla publicada (`fuga ≤ 1e-17`, `|conserv| ≤ 1,2e-14`; ver §2.2
  del `INFORME.md`); es un borde no ejercitado.
- **Estado:** `no corregido`; sin efecto en lo publicado.

### C10 · El test de «retícula» no prueba invariancia física

- **Ubicación:** `v2/test/runtests.jl:67-76`: compara `prob_superar_dp(Float64, z0, …)` con
  `prob_superar_finita(z0, …)` para el **mismo** `z0 ∈ {4,8,16,32}`. Prueba que la DP numérica
  coincide con la exacta; **no** prueba que «`d` unidades de trabajo ≡ `d·g` de retícula».
- **Ya admitido** por `REVISION-RESPUESTA.md` de v0.2 (límites F4/F5), pero la tabla §0 de
  `INFORME.md` de v0.2 lo etiqueta «**demostrado**».
- **Estado:** etiqueta `sobre-enunciada`; el hecho es `verificado en fuente`.

### C11 · En v0.2, R-FIN-5 es un proxy de rama, no un prefijo de flujo

- **Ubicación:** `v2/src/dag_sim.jl:112-114` (`_flujo_en(rama, slot, t_fork) = slot <= t_fork ? 0 :
  rama`) y `:120-128`. El «flujo» es la identidad de la rama evaluada en el slot del **padre**; los
  `DescriptorFlujo` de `src/rfin5.jl` no se usan en la simulación (solo en tests y en `RFIN5.txt`).
- **Qué toca:** v0.2 no puede afirmar «R-FIN-5 sobre todo `past(B)`»; eso solo lo hace v0.3 con
  descriptores por bloque. La tabla §0 de v0.2 («R-FIN-5 rechaza prefijo incompatible en `slot(X)`»)
  describe el módulo `rfin5.jl`, no el DAG.
- **Estado:** `verificado en fuente`.

### C12 · **D10 desaparece en v0.3** (regresión respecto de v0.2)

- **Ubicación:** v0.3 no tiene ninguna sección de coste. `grep -rni "coste\|gratis\|iops\|energía\|
  espacio adicional"` sobre `coste-rama-privada-v3/*.md` devuelve solo `ENTRADA.md` (copia literal
  del encargo, líneas 380-396) y `PROPUESTA.md:33` (E3, como obligación **futura**).
- **Qué exigía D10:** contabilizar por separado espacio, CPU/PoT/IOPS, energía, recompensa y tarifas
  renunciadas, duración real bifurcación→decisión, y hundido vs marginal; y como máximo «cero
  espacio plotteado adicional bajo los supuestos declarados».
- **Qué hay:** v0.2 sí lo trataba (`copia/coste-rama-privada-v2/INFORME.md:144-149`, §10), aunque
  sin cuantificar. v0.3 lo perdió.
- **Consecuencia:** la tabla de límites de v0.3 (`REVISION-RESPUESTA.md:25-34`) no menciona el coste
  y su `VEREDICTO.txt` no lo lista entre los pendientes, así que un lector de v0.3 puede concluir
  que no hay coste pendiente.
- **Estado:** `no corregido`; regresión `verificado en fuente`.

---

## D · Límites declarados que **no** son defectos (pero acotan lo que se puede decir)

| # | Límite | Dónde se declara |
|---|---|---|
| D-a | `S_adversario` sin medición compatible; I/O de page cache caliente, cola 1 | `v2/METODO.md:66`, `v2/resultados/IO.txt`, `v3/INFORME.md:26` |
| D-b | Controlador del SPEC `Pendiente` (ventana/arranque/redondeos) | `v2/resultados/RCE.txt`, `v3/MATRIZ-AUTORIDAD.md:56` |
| D-c | PoT AES no integrado; `autenticado` es un campo del fixture | `v3/INFORME.md:46-49`, `v3/CONTRATO.md:38` |
| D-d | Los descriptores de flujo **no** se derivan de `past(B)` (C-FLU-11 exige derivarlos y prohibir declararlos) | no declarado como tal: `v3/INFORME.md:43` dice solo «cada bloque lleva…» |
| D-e | 24 réplicas por celda ⇒ una celda 0/24 solo acota `P ≲ 0,25` simultáneo | `v3/REVISION-RESPUESTA.md:27-28` |
| D-f | `s_max = 150` trunca ramas a α bajo; celdas con `rgdr>0` son inconclusas | `v3/resultados/SWEEP-DAG.txt` (nota final), `REVISION-RESPUESTA.md:32` |
| D-g | C-GD-11 con cinco pendientes ⇒ «validez de fusión condicionada» | `v3/MATRIZ-AUTORIDAD.md:22,66-68` |
| D-h | Finalidad `F = 2 h` provisional, `Δ` sin medir en red DAG | `v3/MATRIZ-AUTORIDAD.md:59`, `INFORME.md:26` |
| D-i | La matemática no está certificada con aritmética de bolas | `v2/REVISION-RESPUESTA.md:31` |
