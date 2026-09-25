# ORDEN-T01 — Oráculo de referencia del contrato de transición PoW → PoAS + PoT + DAG

## 1. Identidad y contexto

- **ID:** T01. **Estado:** redactada 2026-09-26, **pendiente de lanzar** (bloqueo B-HARNESS-01 de
  `R-ZRX/HARNESS.md`). **Director:** Claude (rol de `AUTO-ZRX.md`).
- **Proyecto:** `/home/katana/zeo/ZEROX`.
- **Zona de ejecución (única escribible):** `/home/katana/zeo/ZEROX/P-ZRX/P-TRANSICION/T01/`.
  La sesión se lanza con ese `cwd`.
- **Objetivo único:** implementar en Julia (CPU) un **oráculo de referencia pequeño y
  transparente** del contrato `P-ZRX/P-TRANSICION/CONTRATO-v0.md` y una batería de pruebas que
  cubra sus casos de rechazo X-01…X-20 y sus invariantes I-1…I-7 sobre una rejilla de parámetros
  simbólicos.
- **Pregunta falsable:** «Las reglas TRN-01…TRN-12 del contrato, con las interfaces por defecto
  (CUT-HWΦ, FC-3, `SEC-0` y `SEC-A`), producen para toda historia de la rejilla un estado que
  conserva el valor, se deshace exactamente, no depende del orden de llegada y rechaza cada
  historia X-01…X-15 con el error previsto.» Se refuta con **un** contraejemplo reproducible, o con
  una contradicción interna del contrato que impida implementarlo sin elegir.
- **Desbloquea:** `D-ZRX/IPA-ZRX.md` A-01, A-03, A-04 (forma), C-01 (contabilidad) y C-06.

## 2. Autoridad y entradas

Lee **íntegros**, antes de escribir código:

1. Este archivo.
2. `/home/katana/zeo/ZEROX/V-ZRX/LINEO.md` — **obligatorio y vinculante** para todo el código.
3. `/home/katana/zeo/ZEROX/P-ZRX/P-TRANSICION/CONTRATO-v0.md` — **especificación que implementas**.
   Si esta orden y el contrato discrepan, **para** e infórmalo; no elijas.
4. `/home/katana/zeo/ZEROX/D-ZRX/SPEC.md` §§3–6 (familias `C-BON`, `C-EVP`, `C-SLA`, `C-BOT`),
   como contexto. **Es una propuesta no normativa.**

Material histórico, solo lectura, **no normativo** (no copies su código; puedes leer su estilo):

- Plantilla de auditoría Julia del proyecto antiguo:
  `/home/katana/zeo/.trash/zerox/veritas/plantilla/` (estructura de `Project.toml`, `run.jl`,
  `test/runtests.jl`). En el árbol nuevo no existe todavía (`IPA-ZRX` E-05).
- Nada del código Rust antiguo es necesario para esta orden.

Entrada congelada: `/home/katana/zeo/ZEROX/P-ZRX/P-TRANSICION/ENTRADA-T01.sha256`. Compruébala
**al empezar y al terminar**:

    cd /home/katana/zeo/ZEROX && LC_ALL=C sha256sum -c P-ZRX/P-TRANSICION/ENTRADA-T01.sha256

y copia ambas salidas completas en `PROGRESO.md`. Nada fuera de tu zona se mueve ni se modifica.

## 3. Decisiones ya tomadas por el director (no las cambies)

Todas las del contrato §0 (D-T01…D-T08) y además, **solo para este oráculo v0**:

1. **Abstracción de bloques.** No hay criptografía, ni PoW real, ni PoAS, ni PoT, ni GHOSTDAG. Un
   bloque es un registro con los campos de §4.2. El identificador entero del bloque hace de
   `block_hash` para desempates (menor id gana).
2. **Fase PoST como árbol de cadenas.** Cada bloque PoST tiene **un** padre. El «peso PoST del
   sufijo» de una punta es la suma de los pesos `w ≥ 1` de los bloques PoST de su cadena. Es la
   abstracción de `blue_work` con `k = 0`; GHOSTDAG queda **fuera de alcance** de v0.
3. **Slots.** El terminal ocupa el slot virtual `s_0 = 0`; todo bloque PoST tiene `slot ≥ 1`, y a lo
   largo de una cadena el slot es estrictamente creciente. Los bloques PoW no tienen slot; para
   `C-FIN-01` su slot se toma como 0.
4. **Trabajo PoW.** Cada bloque PoW trae un entero `trabajo ≥ 1` y un indicador `pow_ok::Bool`. No
   se modela retarget ni tiempo.
5. **Aritmética.** Valores monetarios `UInt64` con operaciones comprobadas
   (`Base.Checked.checked_add`, `checked_sub`); el invariante I-1 se evalúa en `Int128`. Ningún
   `Float64` en reglas. Un desbordamiento es error explícito (`ErrDesbordamiento`), nunca silencioso.
6. **Subsidio.** `subsidio_pow(h)` y `subsidio_post(slot)` son funciones recibidas como parámetro;
   en la rejilla usa las funciones de prueba de §6. **No son parámetros propuestos.**
7. **Fuera de alcance v0 (rechazo explícito `ErrFueraDeAlcanceV0`):** `EvidenceTx` en fase PoST
   (liquidación `C-EVP`/`C-SLA` no se modela); altas de sector en fase PoST.
8. **`SEC-A` v0:** alta y prueba de sector solo en fase PoW; plazos `M_sec` y `P_sec` en
   bloques_pow. Un sector está activo si su prueba se aplicó en `h_prueba ≤ h_alta + P_sec` y
   `h_alta + M_sec ≤ h` actual (o cualquier punto de la fase PoST si ya lo estaba en `T`). Una
   `PruebaSector` aplicada con `h > h_alta + P_sec` ⇒ `ErrPruebaTardia`; un id de sector repetido
   ⇒ `ErrDobleGasto`; un bloque PoST cuyo `sector` no es de su `productor` ⇒ `ErrAutorizacion`, y
   si no está activo ⇒ `ErrSectorInactivo`. Etiqueta
   visible en código e informe: «interfaz abstracta; no representa PoRep ni Filecoin».

9. **Orden de aplicación de un bloque** (altura `h` en PoW, slot `s` en PoST), en este orden
   exacto: (a) validar forma y familia; (b) **promover** a `activo` todo pendiente con madurez
   `≤ h` (o `≤ s`), incluidos créditos D-T08; (c) en PoST, comprobar la garantía del productor
   (`activo ≥ q`) y, en `SEC-A`, que su sector esté activo; (d) aplicar las transacciones en el
   orden del bloque, con la coinbase **primera**; (e) en PoW, evaluar si el bloque es terminal.
   Así la garantía de `B` depende solo de `past(B)` y de `slot(B)`, un campo de su cabecera.
10. **Coinbase por fase.** PoW: `Coinbase(salidas)` con salidas UTXO sin atribución. PoST:
    variante `CoinbasePost(importe)` que acredita a `productor` un crédito pendiente con madurez
    `M_rec_slots` (D-T08). Una variante en la fase equivocada ⇒ `ErrOperacionFase`. Límite:
    `coinbase_pagada ≤ subsidio(punto) + tarifas(B)`.
11. **Tarifas y emisión.** `tarifas(B) = Σ (entradas − salidas)` de sus transferencias. Los
    depósitos v0 **no** tienen tarifa ni cambio: `Σ entradas == importe` exactamente, si no
    `ErrSaldo`. Se define, en `Int128`, `Emitido := Σ_B (coinbase_pagada(B) − tarifas(B))`
    (una coinbase que no reclama todas las tarifas las destruye; el término puede ser negativo).
    **I-1** es `Σ UTXO + Σ garantías (activo + pendientes + en_retirada + congelado + créditos) ==
    Emitido − Quemado`; comprueba además **I-1b**: `Emitido ≤ Σ_B subsidio(B)`.
12. **`requisito_declarado`.** Los bloques PoST llevan un campo `requisito_declarado::Int` que el
    oráculo **ignora** para decidir (X-10): la validez usa siempre `q`.
13. **`ErrTerminalAmbiguo`** no es alcanzable con un padre por bloque; decláralo y prueba, en las
    historias aleatorias, que nunca se produce.
14. **X-16 y `C-FIN-01`.** X-16 e I-3 se evalúan con `seleccionar` y con `nodo_en_linea` a
    `F_slots = typemax(Int)`. Con `F_slots` finito, la dependencia del orden de llegada es la
    conducta prevista de `C-FIN-01` y no cuenta como fallo; se registra cuántas veces ocurre.
15. **Retiro y liberación.** `Retiro` exige `importe ≤ activo` (si no, `ErrSaldo`) y crea una
    entrada `en_retirada` con `inicio_slot = s_0 = 0` en fase PoW o `slot(B)` en PoST.
    `Liberacion` solo en PoST, con `slot(B) ≥ inicio_slot + R_slots` e importe ≤ lo vencido; crea
    una salida `liberacion` del dueño, gastable de inmediato.

No elijas nada más. Si encuentras una regla del contrato que admite dos implementaciones
incompatibles, **antes de editar** descríbela en `PROGRESO.md` como `AMBIGÜEDAD-n`, implementa la
lectura más **restrictiva** (la que rechaza más) solo si no altera el significado de otra regla,
márcala en el código con `# AMBIGÜEDAD-n` y repórtala en el informe; si altera otra regla,
detente.

## 4. Contrato de implementación

### 4.1 Estructura (LINEO §1, adaptada a la zona)

    T01/
    ├── Project.toml, Manifest.toml, julia-version.toml
    ├── src/Transicion.jl        módulo; tipos, estado, reglas
    ├── src/seleccion.jl         SeleccionTransversal (FC-3, FC-1, FC-2) y Corte (HWΦ, H, W)
    ├── src/nodo.jl              nodo en línea con huérfanos y C-FIN-01
    ├── src/generadores.jl       historias aleatorias y escenarios X-nn
    ├── test/runtests.jl         batería completa (X-01…X-20, I-1…I-7)
    ├── run.jl                   CLI reproducible: --seed, --replicas, --rejilla {reducida,completa}
    ├── resultados/              salidas crudas
    ├── INFORME.md, METODO.md, PROGRESO.md, HORAS.log

Dependencias permitidas: stdlib (`Test`, `Random`, `SHA`, `Printf`, `Dates`), `StableRNGs.jl`,
`Combinatorics.jl`. Ninguna otra sin parar y justificarlo.

### 4.2 Tipos (nombres orientativos; la semántica es obligatoria)

- `Familia = Genesis | PoW | PoST`.
- `Bloque`: `id::Int`, `familia`, `padre::Int` (0 para génesis), `altura::Int` (PoW/génesis),
  `trabajo::Int`, `pow_ok::Bool`, `slot::Int` (PoST), `productor::Int` (clave; PoST),
  `sector::Int` (PoST; 0 si `SEC-0`), `peso::Int` (PoST), `requisito_declarado::Int` (PoST),
  `txs::Vector{Tx}`.
- `Tx` (variantes): `Coinbase(salidas)`, `CoinbasePost(importe)`,
  `Transferencia(entradas, salidas, firmante)`,
  `Deposito(entradas, clave, importe, firmante)`, `Retiro(clave, importe, firmante)`,
  `Liberacion(clave, importe, firmante)`, `Evidencia(clave)`, `AltaSector(id, clave, firmante)`,
  `PruebaSector(id, firmante)`. Las firmas son el entero `firmante`; «autorizado» significa
  `firmante` = dueño de cada entrada consumida, o `firmante = clave` en operaciones de garantía.
- `Salida`: `id`, `valor::UInt64`, `dueño::Int`, `origen ∈ {coinbase_pow, tx, liberacion}`,
  `creada_en_altura::Int` o `creada_en_slot::Int` (exactamente uno ≥ 0).
- `Garantia` por clave: `activo`, lista de `pendientes` (importe, madura_en_altura o
  madura_en_slot), lista de `en_retirada` (importe, inicio_slot), `congelado` (siempre 0 en v0),
  `creditos_pendientes` (D-T08).
- `Estado`: UTXO, garantías, `emitido::UInt64`, `quemado::UInt64` (siempre 0 en v0), fase,
  terminal, registro de sectores, más lo que necesites para undo exacto.

### 4.3 Funciones obligatorias

- `aplicar(E, B, P) -> Union{Estado, Err}` y `deshacer(E′, undo) -> E` con undo exacto.
- `es_terminal(historia_hasta_B, P)` según TRN-04 con la interfaz `Corte` elegida.
- `requisito(past, P)` = constante simbólica `q` (interfaz; no la derives de nada más).
- `phi(E, P)`: `Σ activo ≥ S_min`, `#{claves con activo ≥ q} ≥ K_min`, y en `SEC-A`,
  `#{sectores activos} ≥ C_min`.
- `seleccionar(conjunto_de_bloques, P) -> punta`: **función pura** que valida contextualmente
  (un bloque es válido solo si su padre lo es y su aplicación sobre el estado del padre no da
  error), descarta inválidos y descendientes, y aplica `SeleccionTransversal`:
  - **FC-3** (defecto): si existe algún bloque PoST válido, máxima suma de pesos PoST del sufijo;
    desempate por menor id del terminal y luego menor id de la punta. Si no, máximo trabajo PoW
    acumulado; desempate por menor id de la punta.
  - **FC-1**: primero máximo trabajo acumulado del prefijo PoW (hasta el terminal, o hasta la punta
    si no hay terminal); después peso PoST; mismos desempates.
  - **FC-2**: como FC-3 pero con la interfaz `Corte` evaluada con `W_min = 0`.
- `nodo_en_linea(secuencia, P) -> punta`: recibe bloques en un orden arbitrario (huérfanos en
  espera hasta llegar su padre), mantiene su selección y **no** sustituye su punta por una
  candidata si `d = slot(punta actual) − slot(ancestro común) ≥ F_slots` (`C-FIN-01`).
- Errores explícitos, al menos: `ErrGenesis`, `ErrPow`, `ErrEmision`, `ErrInmaduro`,
  `ErrDepositoTemprano`, `ErrAutorizacion`, `ErrSaldo`, `ErrDobleGasto`, `ErrPowTrasCorte`,
  `ErrSinTerminal`, `ErrTerminalAmbiguo`, `ErrGarantia`, `ErrOperacionFase`, `ErrPruebaTardia`,
  `ErrSectorInactivo`, `ErrSlot`, `ErrDesbordamiento`, `ErrFueraDeAlcanceV0`.

### 4.4 Conducta válida e inválida

La define el contrato (§§4–7). En particular: la coinbase PoW no tiene atribución de clave; la
PoST acredita a `productor` un crédito pendiente (D-T08) por `≤ subsidio_post(slot) + tarifas`; un
depósito PoW tardío madura en `M_dep_slots` desde `s_0`; una `coinbase_pow` con
`h + M_cb > altura(T)` se gasta desde `slot ≥ s_0 + M_res_slots`; un retiro en fase PoW cuenta
`R_slots` desde `s_0`; la liberación crea una salida `liberacion` del dueño.

## 5. Modelo de amenaza

No es un modelo económico ni de red. El «adversario» del oráculo es **cualquier historia bien
formada**, incluidas: dos terminales en ramas distintas; rama PoW tardía con más trabajo; bloques
entregados fuera de orden o repetidos; depósitos revertidos por reorganización; productor que se
queda sin garantía en la nueva rama; bloques PoST que declaran datos de otra rama. El oráculo debe
resistirlas sin error interno (una excepción no prevista es un fallo del oráculo).

## 6. Plan de verificación

### 6.1 Casos dirigidos

Un `@testset` por caso X-01…X-20 del contrato §6, con el nombre `X-nn`, construido a mano sobre
parámetros simbólicos y ejecutado en **todas** las combinaciones de la rejilla reducida donde el
caso tiene sentido. Cada rechazo comprueba **el tipo de error**, no solo que falle. X-16…X-20
comprueban igualdad de estado. Para X-17 y X-18, ejecuta también FC-1 y FC-2 y **registra** (sin
juzgar) en qué casos su selección difiere de FC-3: es un dato para el director.

### 6.2 Propiedades con historias aleatorias

Generador: árboles de ≤ 12 bloques (génesis + PoW + PoST), con transferencias, depósitos, retiros,
liberaciones y (en `SEC-A`) altas y pruebas de sector, construidos de forma que aproximadamente la
mitad sean válidos. RNG `StableRNG(semilla_maestra + replica)` por réplica (LINEO §7). Para cada
historia comprueba I-1…I-7 del contrato:

- **I-1** tras cada `aplicar` y cada `deshacer`.
- **I-2** `deshacer(aplicar(E,B)) == E` para todo bloque válido.
- **I-3** `seleccionar` sobre el conjunto; `nodo_en_linea` con `F_slots = typemax(Int)` sobre
  **todas** las permutaciones si el conjunto tiene ≤ 7 bloques (Combinatorics), y 200 permutaciones
  aleatorias si tiene más; todas deben dar la misma punta y el mismo `Estado`.
- **I-4**…**I-7** tal como están en el contrato. Para I-5: genera parejas de historias idénticas
  salvo en importes depositados (manteniendo la validez) y comprueba que pesos, conjunto de
  oportunidades y selección coinciden.

Rejilla **reducida** (valores de prueba, no propuestas):
`H_dep ∈ {1,2}`, `M_cb ∈ {1,3}`, `M_dep ∈ {0,2}`, `H_corte_min = máx(H_dep, 1+M_cb) + M_dep` y ese
valor `+1`, `W_min ∈ {1, 4}`, `S_min ∈ {1, 10}`, `K_min ∈ {1, 2}`, `q ∈ {1, 5}`,
`M_res_slots ∈ {1, 3}`, `M_dep_slots ∈ {1, 2}`, `M_rec_slots ∈ {1, 2}`, `R_slots ∈ {1, 3}`,
`F_slots ∈ {2, typemax(Int)}`, `SEC ∈ {SEC-0, SEC-A}` (con `M_sec = 1`, `P_sec = 2`, `C_min = 1`),
`Corte ∈ {HWΦ, H, W}`, `Selección ∈ {FC-3, FC-1, FC-2}`.
Funciones de prueba: `subsidio_pow(h) = 10`, `subsidio_post(s) = 3`.

Para cada punto de la rejilla reducida: **≥ 200 réplicas**. Semilla maestra por defecto
`0x5a5a` (argumento obligatorio de `run.jl`). Declara el número total de historias probadas.

### 6.3 Contraejemplos

Cualquier historia que viole una propiedad se **reduce** a una mínima, se guarda en
`resultados/contraejemplos/` (semilla, parámetros, bloques en texto legible) y se convierte en
un test de regresión **marcado como fallo esperado solo si el fallo es del contrato**, nunca del
oráculo. No corrijas el contrato: repórtalo.

### 6.4 Comandos exactos

    cd /home/katana/zeo/ZEROX/P-ZRX/P-TRANSICION/T01
    export JULIA_DEPOT_PATH=/home/katana/zeo/ZEROX/P-ZRX/P-TRANSICION/T01/.julia-depot:
    export JULIA=/home/katana/.julia/juliaup/julia-1.13.0+0.x64.linux.gnu/bin/julia
    date -Is >> HORAS.log
    env -u LD_LIBRARY_PATH JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 \
        $JULIA --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.test()'  > resultados/test.log 2>&1
    env -u LD_LIBRARY_PATH JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 \
        $JULIA --project=. run.jl --seed 0x5a5a --replicas 200 --rejilla reducida \
        > resultados/run-reducida.log 2>&1
    date -Is >> HORAS.log

(`env -u LD_LIBRARY_PATH` por el fallo documentado en LINEO §1. No uses el lanzador `juliaup`: el
sandbox no le deja escribir su estado.) Añade a `.julia-depot/` nada más que lo que Pkg necesite;
no lo edites a mano.

### 6.5 LINEO aplicable

Obligatorio: §3.1 (tipos concretos, sin globals mutables ni `Any` en el núcleo), §5.3 (enteros
comprobados; nada de `Float64` para decidir reglas), §7 (RNG por réplica, semilla en CLI y en el
informe), §9 (antipatrones), §10 (criterio de terminación **adaptado**: aquí solo hay referencia,
no kernel rápido). **No optimices.** Si la batería reducida tarda más de 30 min de pared, detente,
perfila con `Profile` y reporta el cuello antes de cambiar nada. Hilos: 1 (el oráculo es la
referencia; la paralelización no es objetivo de esta orden). **Prohibido Python.**

## 7. Medición

No hay medición de rendimiento. Registra el tiempo de pared de la batería como dato operativo,
no como resultado. Presupuesto: **2 h de reloj, 1 hilo de cómputo, 8 GiB de RAM, 2 GiB de disco**
(incluido `.julia-depot`). Si se agota: checkpoint, estado **inconcluso**.

Criterio de aceptación fijado **antes** de ejecutar:

- **SUPERADO:** los 20 casos X y los 7 invariantes pasan en todos los puntos de la rejilla reducida,
  sin contraejemplos, y el informe declara el número de historias probadas por punto.
- **REFUTADO:** al menos un contraejemplo reproducible atribuible al **contrato** (con la regla
  TRN-nn implicada).
- **DEFECTO DEL ORÁCULO:** un contraejemplo atribuible a la implementación; se corrige dentro de la
  orden y se conserva como regresión.
- **INCONCLUSO:** presupuesto agotado o ambigüedad que obligaría a elegir.

## 8. Entregables

En `/home/katana/zeo/ZEROX/P-ZRX/P-TRANSICION/T01/`: el proyecto de §4.1, `resultados/` con
`test.log`, `run-reducida.log` y contraejemplos, `INFORME.md`, `METODO.md`, `PROGRESO.md`,
`HORAS.log` (horas **solo** de `date -Is`; no escribas horas a mano en otros archivos).

`INFORME.md` debe contener:

1. Veredicto (SUPERADO / REFUTADO / INCONCLUSO) y su justificación.
2. Matriz `X-nn → test → resultado → puntos de rejilla cubiertos`.
3. Tabla de invariantes con número de historias y permutaciones comprobadas.
4. Diferencias observadas entre FC-1, FC-2 y FC-3 (datos, sin recomendación).
5. Lista de `AMBIGÜEDAD-n` con la lectura aplicada y la regla afectada.
6. Versión de Julia (`VERSION`), `Pkg.status()`, `Sys.CPU_NAME`, núcleos, RAM, hilos
   (`Threads.nthreads(:default)`, `Threads.nthreads(:interactive)`), semilla, comando exacto,
   tiempo de pared, `uptime` antes y después.
7. Sección **«Lo que este oráculo NO demuestra»**: como mínimo, seguridad económica, criptografía,
   PoW real, PoAS/PoT, GHOSTDAG, red, latencia, particiones, sesgo de semilla (A-07) y cualquier
   mecanismo de sectores real.

Resumen final (tu última respuesta, en español, ≤ 40 líneas): veredicto, contraejemplos,
ambigüedades, archivos creados, comandos y comprobaciones de `ENTRADA-T01.sha256`.

## 9. Límites de la sesión

- Modelo `deepseek-v4.1-flash` (id de catálogo `deepseek-flash`, «DeepSeek-V41-Flash»), esfuerzo
  `high`, solo DeepSeek Harness.
- Lee íntegro `V-ZRX/LINEO.md` y aplícalo **antes** de escribir o ejecutar código.
- Ningún código Python, ni de auditoría, ni de pruebas, ni auxiliar.
- No elijas arquitectura, parámetros ni criterios; los valores de la rejilla son de prueba.
- No modifiques nada fuera de tu zona; no muevas ni reorganices archivos ajenos.
- Ningún `Ok` ficticio, ningún test que se autoconfirme (comparar una función consigo misma no es
  prueba); cada test compara contra un valor esperado construido a mano o contra una propiedad.
- No hagas commit ni push. No leas ni expongas secretos (`.env`, `~/.dsh/`, credenciales).
- Si una prueba falla, repórtala con su salida literal.

## Lanzamiento (lo ejecuta el director cuando B-HARNESS-01 se resuelva)

    mkdir -p /home/katana/zeo/ZEROX/P-ZRX/P-TRANSICION/T01 && \
    cd /home/katana/zeo/ZEROX/P-ZRX/P-TRANSICION/T01 && \
    node /home/katana/torio/deepseek-harness/apps/cli/lib/bin.js --profile headless \
      "Orden T01. Lee íntegro /home/katana/zeo/ZEROX/P-ZRX/P-TRANSICION/ORDEN-T01.md y cúmplelo. Antes de escribir o ejecutar código, lee íntegros /home/katana/zeo/ZEROX/V-ZRX/LINEO.md y /home/katana/zeo/ZEROX/P-ZRX/P-TRANSICION/CONTRATO-v0.md. Si detectas una falta de definición, infórmala antes de editar." \
      > ../T01-dsh.stdout 2> ../T01-dsh.stderr

Nota: `../T01-dsh.*` queda fuera de la zona escribible de la sesión pero la redirección la hace el
shell del director, no DeepSeek. La referencia de sesión se anota en
`P-ZRX/P-TRANSICION/SESION-T01.md`.
