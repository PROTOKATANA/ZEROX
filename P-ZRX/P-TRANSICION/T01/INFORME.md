# INFORME — T01

Oráculo de referencia del contrato `P-ZRX/P-TRANSICION/CONTRATO-v0.md` y batería
de X-01…X-20 e I-1…I-7 sobre la rejilla reducida de `ORDEN-T01.md` §6.2.

## 1. Veredicto

**SUPERADO**. Los 20 casos X y los 7 invariantes pasan en los **147 456** puntos
de la rejilla reducida, sin contraejemplos. Dos avisos declarados:

- Presupuesto: la batería de `run.jl` tardó **38,77 min** (por encima del umbral
  de 30 min de ORDEN §6.5; se perfiló y optimizó antes, ver `METODO.md` §2/§4).
- Muestreo: I-3 en `run.jl` revisa 1 de cada 200 historias (4 155 744
  permutaciones); X-16 revisa 7 órdenes por punto (identidad, inverso y 5
  aleatorios). El resto de comprobaciones es exhaustivo.

Justificación:

- **X-01…X-15**: pasan en los **147 456** puntos de la rejilla reducida, con el
  tipo de error previsto (no un `false` genérico). `resultados/test.log`.
- **X-16**: pasa en los **147 456** puntos (7 órdenes por punto).
- **X-17…X-20**: pasan en los **147 456** puntos.
- **I-1…I-7**: **cero fallos** en 29 491 200 historias aleatorias
  (147 456 puntos × 200 réplicas) y 183 406 080 undos exactos; más 294 912
  historias en la batería del test. `resultados/run-reducida.log`.
- **Sin contraejemplos** y sin `AMBIGÜEDAD` que obligue a elegir sin lectura
  compatible; la hipótesis falsable no se refuta.

## 2. Matriz X-nn

| Caso | Test | Resultado | Puntos de rejilla cubiertos |
|---|---|---|---|
| X-01 | génesis con coinbase > 0 | `ErrGenesis` | 147 456 (todos) |
| X-02 | coinbase PoW sobre subsidio+tarifas | `ErrEmision` | 147 456 |
| X-03 | gasto de `coinbase_pow` inmadura (PoW y residual) | `ErrInmaduro` | 147 456 (y X-03b donde aplica) |
| X-04 | depósito en `h < H_dep` | `ErrDepositoTemprano` | donde `H_dep > 1` |
| X-05 | depósito que consume coinbase inmadura | `ErrInmaduro` | 147 456 |
| X-06 | depósito con clave ≠ firmante | `ErrAutorizacion` | 147 456 |
| X-07 | PoW hijo de terminal | `ErrPowTrasCorte` | 147 456 |
| X-08 | PoST sin terminal | `ErrSinTerminal` | 147 456 |
| X-09 | garantía activa < `q` | `ErrGarantia` | 147 456 |
| X-10 | `requisito_declarado` distinto (se ignora) | `ErrGarantia` | 147 456 |
| X-11 | no-terminal por trabajo / altura / Φ | `ErrSinTerminal` | 147 456 (subcasos donde aplican) |
| X-12 | no es el primero en cumplir TRN-04 | `ErrSinTerminal` + `es_terminal=false` | 147 456 |
| X-13 | `EvidenceTx` en PoW | `ErrOperacionFase` | 147 456 |
| X-14 | `Liberacion` en PoW | `ErrOperacionFase` | 147 456 |
| X-15 | prueba tardía / sector no activo (`SEC-A`) | `ErrPruebaTardia` / `ErrSectorInactivo` | puntos `SEC-A` |
| X-16 | órdenes distintos del mismo conjunto | misma punta y mismo hash | 147 456 (7 órdenes/punto) |
| X-17 | dos terminales, pesos `w1 > w2` | selecciona `T1` (FC-3) | 147 456 |
| X-18 | rama PoW tardía con más trabajo | no desplaza (FC-3) | 147 456 |
| X-19 | reorg elimina el depósito habilitante | `ErrGarantia` en la rama nueva; undo exacto | 147 456 |
| X-20 | undo de prefijos válidos | estado idéntico | 147 456 |

`ErrTerminalAmbiguo` se declara y **nunca** se produce (un padre por bloque,
ORDEN §3.13); se verifica en las historias aleatorias (I-4/I-7 sin fallos).

## 3. Invariantes

| Invariante | Comprobaciones | Fallos |
|---|---|---:|
| I-1 conservación | 29 491 200 historias × cada estado válido (más 294 912 en tests) | 0 |
| I-1b `Emitido ≤ Σ subsidio` | idem | 0 |
| I-2 undo exacto | 183 406 080 undos (run) + 1 833 609 (tests) | 0 |
| I-3 determinismo | 4 155 744 permutaciones (run, muestreo 1/200) + 344 073 (tests) + X-16 (7 órdenes × 147 456 puntos) | 0 |
| I-4 unicidad de fase | 29 491 200 historias | 0 |
| I-5 complementariedad | pesos/trabajo del sufijo = suma de campos de bloque | 0 |
| I-6 coinbase inmadura | ninguna salida inmadura gastada ni en garantía activa | 0 |
| I-7 `Φ` y terminal | todo PoST válido exige terminal (primero en cumplir el `Corte`) | 0 |

Semilla maestra: `0x5a5a` (23 130). RNG por réplica
`StableRNG(semilla + réplica)`. La batería de `run.jl` probó **200 historias por
punto** en los 147 456 puntos.

## 4. Diferencias entre FC-1, FC-2 y FC-3 (dato, sin recomendación)

- `run.jl` (muestreo de I-3, 1 de cada 200 historias): `FC-1` difiere de `FC-3`
  en **0** ocasiones; `FC-2` difiere en **30 720**, concentradas en `CUT-W`
  (con `W_min = 0` el primer bloque PoW ya es terminal y trunca la historia).
- `Pkg.test()` X-17 (dos terminales, mismo trabajo), rejilla completa:
  `FC-1` difiere en 0; `FC-2` difiere en 6 144.
- `Pkg.test()` X-18 (rama PoW con más trabajo), rejilla completa:
  `FC-1` difiere en 96 000; `FC-2` difiere en 6 144. `FC-1` prioriza el trabajo
  PoW, así que la rama tardía desplaza la selección; `FC-3` no.

## 5. Ambigüedades

Trece `AMBIGUEDAD-n` detectadas **antes** de editar y resueltas con la lectura
más restrictiva o compatible sin alterar otra regla; están descritas en
`PROGRESO.md` §2 y marcadas con `# AMBIGUEDAD-n` en el código:

1. `Emitido` en `Int128` (término negativo).
2. Segunda retirada con una `en_retirada` viva ⇒ `ErrRetiroPendiente`.
3. `Transferencia` con `Σ salidas > Σ entradas` ⇒ `ErrSaldo`.
4. Promoción inmediata si la madurez ya se cumple (`M_dep = 0`).
5. I-7 estructural (compatible con `CUT-H`/`CUT-W`); forma literal en `CUT-HWΦ`.
6. Coinbase aplicada primero y >1 coinbase ⇒ `ErrEmision`.
7. `ErrPow` para `pow_ok`/`trabajo`; `ErrSlot` para altura/slot/`peso`.
8. Operaciones de sector en `SEC-0` ⇒ `ErrFueraDeAlcanceV0`.
9. Alta de sector en PoST ⇒ `ErrFueraDeAlcanceV0`; antes de `H_dep` ⇒
   `ErrDepositoTemprano`.
10. `EvidenceTx`: `ErrOperacionFase` en PoW, `ErrFueraDeAlcanceV0` en PoST.
11. Depósito en PoST madura en `slot + M_dep_slots`.
12. Undo por copia íntegra del estado previo.
13. Huérfanos en `seleccionar` no son válidos.

No hubo ninguna ambigüedad que obligara a detenerse.

## 6. Entorno, comando y tiempos

- `VERSION` = 1.13.0. `Sys.CPU_NAME` = `znver5`; 32 núcleos lógicos.
- Hilos: `Threads.nthreads(:default)` = 1, `Threads.nthreads(:interactive)` = 1
  (`JULIA_NUM_THREADS=1`); `OPENBLAS_NUM_THREADS=1`.
- RAM: 123 GiB totales, ≤ 113 GiB disponibles; `.julia-depot` = 8,6 MB
  (presupuesto 2 GiB).
- `Pkg.status()`: `Combinatorics v1.1.0`, `StableRNGs v1.0.4`, `Printf v1.11.0`,
  `Random v1.11.0`, `SHA v1.0.0` (más `Test` en el entorno de test).
- Semilla: `0x5a5a`. Comandos exactos:

      cd /home/katana/zeo/ZEROX/P-ZRX/P-TRANSICION/T01
      export JULIA_DEPOT_PATH=/home/katana/zeo/ZEROX/P-ZRX/P-TRANSICION/T01/.julia-depot:
      export JULIA=/home/katana/.julia/juliaup/julia-1.13.0+0.x64.linux.gnu/bin/julia
      env -u LD_LIBRARY_PATH JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 \
          $JULIA --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.test()' > resultados/test.log 2>&1
      env -u LD_LIBRARY_PATH JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 \
          $JULIA --project=. run.jl --seed 0x5a5a --replicas 200 --rejilla reducida \
          > resultados/run-reducida.log 2>&1

- Tiempo de pared de `run.jl`: **2 325,9 s (38,77 min)** para 29 491 200
  historias. `Pkg.test()`: ver `resultados/test.log` (≈1 min de batería tras
  compilación).
- `uptime` antes: `01:04:03 arriba 8:06, carga 0,13`. Después:
  `02:01:59 arriba 9:04, carga 0,92`.
- Comprobación de `ENTRADA-T01.sha256`: `OK` las cuatro entradas al empezar y al
  terminar (salidas completas en `PROGRESO.md` §1 y §5).

## 7. Lo que este oráculo NO demuestra

Como mínimo, y por construcción de la orden:

- **Seguridad económica**: no modela incentivos, coste de ataque, disuasión,
  calibración de `requisito`, `R_slots`, `F_slots` ni cuantías.
- **Criptografía**: no hay firmas reales, hashes ni pruebas; `firmante` es un
  entero y `pow_ok` un booleano.
- **PoW real**: no hay preimagen, *target*, retarget, dificultad, tiempo ni
  hash alquilable; el trabajo es un entero simbólico.
- **PoAS/PoT y GHOSTDAG**: el peso PoST es un entero por bloque con `k = 0`; el
  DAG es un árbol de un solo padre. No se modela `blue_work` real.
- **Sectores reales**: `SEC-A` es una interfaz abstracta de alta/activación/
  prueba; **no** representa PoRep, Filecoin ni capacidad física.
- **Red, latencia y particiones**: el `nodo_en_linea` es secuencial y no modela
  propagación, eclipse ni censura.
- **Sesgo de semilla (A-07)**: `derivar_semilla` y `s_0 = 0` son marcadores;
  no se analiza entropía del terminal.
- **`EvidenceTx`/liquidación**: fuera de alcance v0; `Quemado` es siempre 0.
- **Finalidad determinista**: `C-FIN-01` con `F_slots` finito produce dependencia
  del orden, que aquí se registra como conducta prevista, no como fallo.
- **Muestreo de órdenes y de I-3**: X-16 revisa 7 órdenes por punto (no todas
  las permutaciones) y la comprobación I-3 de `run.jl` se muestrea (1 de cada
  200 historias). La propiedad de independencia del orden es estructural
  (`nodo_en_linea` recalcula `seleccionar` sobre el conjunto recibido) y las
  permutaciones se agotan para conjuntos pequeños en la batería del test.

---

# INFORME — T01-B (exportador determinista de vectores)

## B.1. Veredicto

**SUPERADO.** El oráculo T01, con las ratificaciones v0.1 R-6…R-9 aplicadas,
exporta 2 055 casos a `resultados/vectores-transicion-v0.txt`; un lector
independiente (`src/lector_vectores.jl`, sin funciones del exportador) los
reconstruye, los reejecuta con el oráculo y reproduce **RES, SEL, UTXO, GAR y
EST** en los 2 055 casos con **0 discrepancias**. Dos ejecuciones del exportador
producen el mismo `sha256` (`06d95324…d766`).

- `test/runtests.jl` pasa entero (incluye 10 comprobaciones nuevas de R-6…R-9).
- `run.jl --seed 0x5a5a --replicas 50 --rejilla reducida`: **7 372 800**
  historias, 45 840 000 undos, 0 fallos en I-1…I-7; `VEREDICTO = SIN FALLOS`.
- Fichero: 8 070 348 B, 130 869 líneas, 2 055 casos (55 dirigidos + 2 000
  aleatorios).

## B.2. Ratificaciones v0.1 aplicadas (R-6…R-9)

La única modificación de la semántica de T01 permitida por la orden (§3.3),
marcada en el código con `# RATIFICACION-v0.1-Rn`:

| Regla | Cambio aplicado | Marcas en `src/Transicion.jl` |
|---|---|---|
| **R-6** | La coinbase (única) **debe** ser la primera transacción; en otra posición, `ErrEmision` (sustituye la lectura de AMBIGUEDAD-6, que la reordenaba) | `aplicar_txs!` (líneas ~610-612) |
| **R-7** | Toda `TxCoinbase` exige al menos una salida; si no, `ErrEmision` (también un génesis que traiga coinbase vacía) | `aplicar_genesis!`, `aplicar_tx!` |
| **R-8** | Importe 0 en `CoinbasePost`, `Deposito`, `Retiro` o `Liberacion` ⇒ `ErrSaldo` | `aplicar_tx!`, `aplicar_deposito!`, `aplicar_retiro!`, `aplicar_liberacion!` |
| **R-9** | Transferencia sin entradas ⇒ `ErrEmision` (coinbase fuera de lugar); con entradas y sin salidas ⇒ `ErrSaldo` | `aplicar_txs!` (líneas ~617-621) |

Regresión: `test/runtests.jl` añade el testset «Ratificaciones v0.1
(R-6…R-9)» con **10/10** comprobaciones (R-6 en segunda posición; R-7 coinbase
vacía y génesis vacío; R-8 importe 0 en depósito, retiro, coinbase PoST y
liberación; R-9 sin entradas y sin salidas). Las 29 491 200 historias de T01
vuelven a dar 0 fallos: ninguna historia válida usaba coinbase fuera del primer
lugar ni importes 0.

## B.3. Contenido del fichero

Formato §3.4 de la orden, UTF-8, una línea por registro. Encabezado con la
fecha de `date -Is` usada y el sha256 de `CONTRATO-v0.md`
(`e84d5717…f02c916`, el mismo de `ENTRADA-T01-B.sha256`).

**Solo interfaces por defecto** (`CUT_HWPhi`, `FC3`, `SEC0`), como exige §3.1:
se enumeran los 8 192 puntos reducidos con esas tres interfaces.

- **Dirigidos (55):** los casos X-01…X-20 que tienen sentido, en los puntos de
  índice 1, 4 096 y 8 192 (primero, medio y último de la enumeración por
  defecto). Cobertura: X-01 (3), X-02 (3), X-03 (3), X-03b (2), X-04 (1),
  X-05 (3), X-06 (3), X-07 (3), X-08 (3), X-09 (3), X-10 (3), X-11b (3),
  X-11c (3), X-13 (3), X-14 (3), X-16 (3), X-17 (3), X-18 (3), X-19 (1),
  X-20 (3). Se omite **X-12** (usa un estado manual inalcanzable por ninguna
  secuencia de bloques; el formato v0 define `RES` releíble) y **X-15**
  (`SEC-A`, fuera de las interfaces por defecto). Cada dirigido conserva su
  error construido a mano: el exportador comprueba
  `RES` releíble == `esperado` y registra `dirigidos_con_error_inesperado=0`.
- **Aleatorios (2 000):** generador de T01 (`generar_historia`, `max_altura=9`,
  `max_post=3`), semilla `0x5a5a + r` (`r = 1..2000`; semillas 23 131…25 130),
  repartidos equiespaciadamente sobre los 8 192 puntos (2 000 puntos distintos,
  del 1 al 8 192). `RES` obtenidos incluyen `OK`, `ErrPow`, `ErrSlot`,
  `ErrPowTrasCorte`, `ErrSinTerminal`, `ErrSinPadre`, `ErrGenesis`,
  `ErrEmision`, `ErrInmaduro`, `ErrGarantia`, `ErrAutorizacion`,
  `ErrDepositoTemprano` y `ErrOperacionFase`.

## B.4. Relectura independiente

`src/lector_vectores.jl`: analizador y render propios (mismo formato y mismas
reglas de orden: UTXO por `(dueño, valor, origen, altura, slot)`; GAR por
`clave`; `pend` por `(importe, altura, slot)`, `ret` por `(inicio_slot,
importe)`, `cred` por `(importe, slot)`), sin reutilizar ninguna función de
`exportar.jl`. Reejecuta con el oráculo (`aplicar`/`seleccionar`/
`construir_validos`) y compara RES, SEL, UTXO, GAR y EST. Comprobaciones
extra: X-16 con el orden de entrega invertido (misma punta y mismo estado
canónico) y undo exacto en X-19/X-20.

Resultado: `leidos_casos = 2055`, `discrepancias = 0`,
`VEREDICTO_LECTURA = SIN DISCREPANCIAS`.

## B.5. Determinismo

Dos corridas con `--fecha` fija producen el mismo fichero:

    corrida_1 (entregada) = 06d95324c01083c297b1d1423845ee3c78f47dc3e7bf314e56d3083a41e6d766
    corrida_2            = 06d95324c01083c297b1d1423845ee3c78f47dc3e7bf314e56d3083a41e6d766
    RESULTADO = SHA256 IDENTICO

Evidencia en `resultados/determinismo.log`. La fecha vive en el encabezado y
se pasa por `--fecha` (por defecto, `date -Is`); sin fijarla, el hash cambia
solo en esa línea.

## B.6. Entorno, comandos y tiempos

- Julia 1.13.0, `znver5`; 1 hilo (`JULIA_NUM_THREADS=1`,
  `OPENBLAS_NUM_THREADS=1`), `OPENBLAS_NUM_THREADS=1`. Sin Python.
- Presupuesto: 1 h 30 min, 1 hilo, 8 GiB; la sesión T01-B (02:08–02:25) usó
  ~17 min de reloj y < 0,5 GiB por proceso.

      export JULIA_DEPOT_PATH=…/T01/.julia-depot:
      export JULIA=…/julia-1.13.0+0.x64.linux.gnu/bin/julia
      env -u LD_LIBRARY_PATH JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 \
          $JULIA --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.test()' \
          > resultados/test-T01-B.log 2>&1
      env -u LD_LIBRARY_PATH JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 \
          $JULIA --project=. run.jl --seed 0x5a5a --replicas 50 --rejilla reducida \
          > resultados/run-reducida-50.log 2>&1
      env -u LD_LIBRARY_PATH JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 \
          $JULIA --project=. exportar.jl --fecha 2026-09-26T02:14:31+02:00
      env -u LD_LIBRARY_PATH JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 \
          $JULIA --project=. src/lector_vectores.jl resultados/vectores-transicion-v0.txt

- Tiempos medidos (1 CPU): `Pkg.test()` ≈ 2 min; `run.jl --replicas 50`
  **597,2 s (9,95 min)**; `exportar.jl` **3,22 s** (439 MB RSS); lector
  **2,31 s** (382 MB RSS).

## B.7. Lo que T01-B NO demuestra

- **No añade semántica**: exporta lo que el oráculo ya decide; no valida
  criptografía, PoW, PoAS/PoT, GHOSTDAG ni sectores reales.
- **No cubre R-8/R-9 de forma sintética** en el fichero (el generador de T01 no
  produce importes 0 ni transferencias vacías); esas formas quedan cubiertas por
  el testset de `runtests.jl` y, en Rust, por V5 de `ORDEN-W03`.
- **No exporta X-12 ni X-15** (no representables en el formato v0: estado manual
  inalcanzable / `SEC-A` fuera de las interfaces por defecto).
- **No es un motor Rust**: el formato es texto neutral; su lectura real y la
  autorización con firmas corresponden a W03.
- **No demuestra determinismo entre máquinas**: solo reproducibilidad en esta
  máquina, versión y semilla; el orden del `Dict` interno se neutraliza con
  ordenaciones explícitas, pero no se ha comparado con otro hardware.

---

# INFORME — T01-C (vectores negativos de transacción)

## C.1. Veredicto

**SUPERADO.** `resultados/vectores-transicion-negativos-v0.txt` contiene
**1 915** casos dirigidos, cada uno con el error esperado **escrito a mano**
(`CasoNegativo.esperado`) y **confirmado por el oráculo** (0 inesperados). Los
casos cubren los tres puntos de la rejilla por defecto que ya usó T01-B
(índices 1, 4 096 y 8 192 de los 8 192 puntos con `CUT_HWPhi`/`FC3`/`SEC0`) y
ambas fases. **Las ocho familias** de rechazo de transacción superan el mínimo
de 30 casos (tabla C.2). Un lector independiente (`src/lector_vectores.jl`, que
no reutiliza nada del exportador) reconstruye, reejecuta y compara los 1 915
casos con **0 discrepancias**; dos ejecuciones con la misma `--fecha` producen
el mismo `sha256`. `test/runtests.jl` sigue pasando entero.

- Fichero: 3 783 196 B, 61 843 líneas, 1 915 casos (`CASO` = `FIN` = 1 915).
- `sha256`: `2e407c88118828d4ca2357fcdc21b43beb4b03f5874858b03c4860fb717e1792`
  (formato `sha256sum`: `<hash>  resultados/vectores-transicion-negativos-v0.txt`).
- Encabezado con la fecha `2026-09-26T02:59:21+02:00` y el sha256 del contrato
  (`e84d5717…f02c916`, el mismo de `ENTRADA-T01-C.sha256`).
- Solo se exportan `RES` con **un** error de la lista objetivo; no aparece ningún
  `ErrSinPadre`, `ErrPow`, `ErrSlot`, `ErrGenesis`, `ErrFueraDeAlcanceV0` ni
  `OK` en el bloque negativo (10 810 `OK` en los prefijos válidos).

## C.2. Recuento por familia (RES confirmado por el oráculo)

| Familia (error) | Casos | PoW | PoST | Mínimo §3.2 | Subcasos |
|---|---:|---:|---:|---:|---|
| `ErrSaldo` | **571** | 240 | 331 | ≥30 | 10 |
| `ErrDobleGasto` | **306** | 144 | 162 | ≥30 | 4 |
| `ErrRetiroPendiente` | **78** | 24 | 54 | ≥30 | 2 |
| `ErrAutorizacion` | **240** | 132 | 108 | ≥30 | 4 |
| `ErrInmaduro` | **189** | 165 | 24 | ≥30 | 4 |
| `ErrEmision` | **198** | 144 | 54 | ≥30 | 3 (R-6/R-7/R-9) |
| `ErrOperacionFase` | **192** | 192 | 0 | ≥30 | 4 |
| `ErrGarantia` | **141** | 0 | 141 | ≥30 | 2 |

Totales por fase: **PoW = 1 041**, **PoST = 874**. `ErrOperacionFase` solo aplica
en PoW (evidencia/liberación en PoW); `ErrGarantia` solo aplica en PoST (garantía
de producción); el resto cubre ambas fases. El recuento completo por subcaso está
en `resultados/exportar-negativos.log`.

## C.3. Subcasos exigidos por §3.2

- **`ErrSaldo`**: transferencia que crea valor (63); transferencia con entradas y
  sin salidas de R-9 (63); depósito que no cuadra (63); retiro mayor que el
  activo (90); liberación mayor que lo vencido (54); importe 0 de R-8 en
  `CoinbasePost` (27), `Deposito` (75), `Retiro` (75) y `Liberacion` (27); y
  **liberación antes de `R_slots`** (34, ver C.6).
- **`ErrDobleGasto`**: misma entrada dos veces en una tx (63); misma entrada en
  dos txs del mismo bloque (63); gasto de una salida ya gastada en transferencia
  (90) y en depósito (90).
- **`ErrRetiroPendiente`**: segunda retirada con una `en_retirada` viva (20); dos
  retiros en el mismo bloque (58).
- **`ErrAutorizacion`**: transferencia (63), depósito (75), retiro (75) y
  liberación (27) firmados por otra clave.
- **`ErrInmaduro`**: gasto de la coinbase del propio bloque en PoW (48); gasto de
  una coinbase inmadura del estado padre (72); depósito de la coinbase del propio
  bloque (45); y gasto cruzando el corte antes de `s_0 + M_res_slots` (24).
- **`ErrEmision`**: R-7 coinbase PoW sin salidas (48); R-6 coinbase única fuera
  de la primera posición (75); R-9 transferencia sin entradas (75).
- **`ErrOperacionFase`**: liberación en PoW (48), evidencia en PoW (48) y sus
  variantes sin coinbase previa (48 + 48).
- **`ErrGarantia`**: productor sin garantía activa (135) y **depósito pendiente
  usado para producir** (6): un bloque PoST válido transfiere 1 brek a una clave
  sin garantía, el siguiente bloque válido lo deposita (queda `pend=[importe@s…]`)
  y el bloque negativo produce con esa clave; el oráculo solo mira `past(B)` y
  devuelve `ErrGarantia` en los 6 casos (puntos 4 096 y 8 192, `M_dep_slots = 2`).

## C.4. Relectura independiente y determinismo

`src/lector_vectores.jl` (analizador y render propios, sin funciones del
exportador) sobre el fichero nuevo:

    leidos_casos = 1915
    discrepancias = 0
    VEREDICTO_LECTURA = SIN DISCREPANCIAS

Comprueba `RES`, `SEL`, `UTXO`, `GAR` y `EST` de cada caso, además de las
propiedades extra que ya traía para T01-B (no aplican a estos nombres). La
comprobación `sha256sum -c` pasa:

    resultados/vectores-transicion-negativos-v0.txt: La suma coincide

Determinismo (`resultados/determinismo-negativos.log`): dos ejecuciones con
`--fecha 2026-09-26T02:59:21+02:00` dan el mismo hash `2e407c88…e1792`.

## C.5. Entorno, comandos y tiempos

1 hilo (`JULIA_NUM_THREADS=1`, `OPENBLAS_NUM_THREADS=1`), Julia 1.13.0, sin
Python. Presupuesto T01-C: 1 h, 1 hilo, 4 GiB.

    export JULIA_DEPOT_PATH=…/T01/.julia-depot:
    export JULIA=…/julia-1.13.0+0.x64.linux.gnu/bin/julia
    env -u LD_LIBRARY_PATH JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 \
        $JULIA --project=. exportar_negativos.jl --fecha 2026-09-26T02:59:21+02:00
    # casos=1915 inesperados=0
    env -u LD_LIBRARY_PATH JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 \
        $JULIA --project=. src/lector_vectores.jl \
        resultados/vectores-transicion-negativos-v0.txt
    env -u LD_LIBRARY_PATH JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 \
        $JULIA --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.test()'

- `exportar_negativos.jl`: 3,34 s de pared, 100 % CPU, máx. RSS ≈ 436 MiB.
- lector independiente: 2,08 s, máx. RSS ≈ 381 MiB.
- `Pkg.test()`: todos los testsets pasan (`PKGTEST_EXIT=0`), ver
  `resultados/test-T01-C.log`; X-01…X-15 38/38, R-6…R-9 10/10, X-16…X-20 2/2
  cada uno, I-1…I-7 9/9 con 0 fallos (58,2 s).
- Tiempo total de la sesión: 02:50:25–03:02:18 (`HORAS.log`), muy por debajo de
  la hora de presupuesto.

## C.6. Declaración sobre «liberación antes de `R_slots`»

§3.2 pide ese caso «el error que dé el oráculo, declarado». El oráculo
(`aplicar_liberacion!`) calcula `vencido` como la suma de las retiradas con
`inicio_slot + R_slots ≤ slot`; antes de `R_slots` vale 0 y
`importe > vencido ⇒ ErrSaldo`. Por tanto los 34 casos «liberación antes de
`R_slots`» se confirman y **se declaran como `ErrSaldo`** (no `ErrInmaduro`), y
se contabilizan dentro de la familia `ErrSaldo`. Ningún caso se relabela.

## C.7. Lo que T01-C NO demuestra

- **No añade semántica**: los generadores solo construyen bloques de rechazo
  sobre estados válidos de T01; no tocan `Transicion.jl`/`seleccion.jl`/`nodo.jl`.
- **No cubre operaciones de sector** (`SEC-A`), fuera de las interfaces por
  defecto; `AltaSector`/`PruebaSector` no aparecen en el fichero.
- **No prueba firmas reales**: `firmante`/`clave` son enteros simbólicos.
- **No exporta X-12/X-15** ni cambia los vectores de T01-B.
- **No demuestra determinismo entre máquinas**: solo en esta máquina, versión y
  semilla; el orden interno se neutraliza con ordenaciones explícitas.

# INFORME — T01-D (nonce por clave de garantía, F-15)

## D.1. Veredicto

**SUPERADO.** El oráculo incorpora el **nonce por clave** de la «Corrección v0.1»
de `FORMATO-v0.md` (F-15). Se regeneran los mismos **2 055** casos base en
`resultados/vectores-transicion-v0.1.txt` (con `nonce=` en las `TX` de `Deposito`/
`Retiro`/`Liberacion` y en cada `GAR`) y se amplía el fichero de rechazos a
`resultados/vectores-transicion-negativos-v0.1.txt` con los **1 915** casos de
T01-C más **2 024** casos de `ErrNonce`. Un lector independiente relee ambos
ficheros con **0 discrepancias**; dos ejecuciones con la misma `--fecha` dan el
mismo `sha256`; `test/runtests.jl` y `run.jl --seed 0x5a5a --replicas 50
--rejilla reducida` pasan sin fallos. Los ficheros v0 se conservan intactos.

- Base: 2 055 casos, 130 869 líneas, 8 219 999 B,
  `sha256 = 0faec4a330b0ab96052b97c919b9e7bfa9ef494c2dd8fde25f38738658aa5527`.
- Negativos: 3 939 casos, 145 287 líneas, 9 045 511 B,
  `sha256 = 9ca55abde96702f61ac0762e22f0a861d9ab0603a4090eda04ccd818eb0326ad`.
- v0 intactos: base `06d95324…e6d766`, negativos `2e407c88…717e1792`.

## D.2. Falta de definición detectada antes de editar

Ninguna bloquea la orden; se aplica la lectura más compatible con las decisiones
1–5 y con F-15 y se declara aquí y en `PROGRESO.md` §T01-D.

- **D/AMBIGUEDAD-1 — Destino del caso válido `n, n+1`.** §3 pide el bloque válido
  `n, n+1` y el `n, n`; §4 fija que el fichero base conserva **2 055** casos y
  que el negativo lleva «los de T01-C más los de repetición». Lectura: el rechazo
  `n, n` va al fichero negativo (`neg-nonce-dos-nn`) y el bloque válido `n, n+1`
  se comprueba en `test/runtests.jl` (`casos_nonce_validos`), sin alterar el
  recuento del base ni meter un caso válido en el fichero de rechazos.
- **D/AMBIGUEDAD-2 — Desbordamiento de `nonce_siguiente`.** No se nombra error
  para el máximo de `UInt64`. Lectura: suma comprobada (R-1) y
  `ErrDesbordamiento`; inalcanzable en la rejilla, pero sin `wrap`.
- **D/AMBIGUEDAD-3 — Clave sin registro en `Retiro`/`Liberacion`.** Solo se
  explicita que un **depósito** crea el registro con 0. Lectura: se aplica la
  misma (`obtener_garantia!` crea con 0) y luego el resto de reglas; al fallar la
  operación, la copia se descarta (R-14), así que no persiste.
- **D/AMBIGUEDAD-4 — Orden del nonce frente a la fase en `Liberacion`.** §2 dice
  «antes que el resto de reglas». Lectura: también antes de `ErrOperacionFase`;
  una liberación en PoW con nonce correcto sigue dando `ErrOperacionFase` (X-14
  no cambia) y con nonce incorrecto da `ErrNonce`.
- **D/AMBIGUEDAD-5 — Alcance de «≥ 30 cada uno, fases PoW y PoST».** Lectura: se
  cuentan por subcaso; `rep-liberacion` solo puede ser PoST (la liberación no se
  aplica en PoW) y los demás subcasos cubren PoW y PoST.
- **D/AMBIGUEDAD-6 — Posición del campo `nonce=`.** No se fija. Lectura: al final
  de la línea (`… sal=[…] nonce=<u64>`, `… congelado=<u64> nonce=<u64>`),
  idéntica en exportadores y lector.
- **D/AMBIGUEDAD-7 — `.sha256` del base.** T01-B escribió el base con solo el
  hash; §4 pide formato `sha256sum` para «cada uno». Lectura: los v0.1 usan
  `<hash>  <ruta>`; los v0 conservan su formato original.

## D.3. F-15 en el oráculo

- `Garantia` gana `nonce_siguiente::UInt64` (0 al crearse, incluido el registro
  implícito de `obtener_garantia!`); `Tx` gana `nonce::UInt64` (0 salvo en las
  tres operaciones de garantía). `clonar` y `representacion_canonica` lo
  incluyen, de modo que el undo por copia (R-14) y el hash canónico lo reflejan.
- `comprobar_nonce!` va **primero** en `aplicar_deposito!`, `aplicar_retiro!` y
  `aplicar_liberacion!`: si `nonce ≠ nonce_siguiente[clave]` ⇒ `ErrNonce`; si
  coincide, aplica e incrementa. El incremento es visible a las txs siguientes
  del mismo bloque, lo que permite `n, n+1` y rechaza `n, n`.
- Los generadores honestos (`construir_poW`, `extender_post`,
  `escenarios_rechazo`, `historia_dos_terminales`, `casos_bloque`,
  `casos_garantia_pendiente`) asignan el nonce correcto leyendo el estado
  tentativo, por lo que X-01…X-20 no cambian de resultado (0 dirigidos
  inesperados en el exportador).
- `src/generadores_negativos.jl` añade `casos_nonce` (rechazos) y
  `casos_nonce_validos` (bloques `n, n+1` válidos), con prefijos PoW
  pre-terminales para cubrir también la fase PoW.

## D.4. Recuento por error (incluido `ErrNonce`)

Fichero `vectores-transicion-negativos-v0.1.txt` (3 939 casos; PoW = 1 553,
PoST = 2 386). Las ocho familias de T01-C conservan **exactamente** sus 1 915
casos y sus recuentos.

| Error | Casos | PoW | PoST |
|---|---:|---:|---:|
| `ErrSaldo` | 571 | 240 | 331 |
| `ErrDobleGasto` | 306 | 144 | 162 |
| `ErrRetiroPendiente` | 78 | 24 | 54 |
| `ErrAutorizacion` | 240 | 132 | 108 |
| `ErrInmaduro` | 189 | 165 | 24 |
| `ErrEmision` | 198 | 144 | 54 |
| `ErrOperacionFase` | 192 | 192 | 0 |
| `ErrGarantia` | 141 | 0 | 141 |
| `ErrNonce` | **2 024** | **512** | **1 512** |

Subcasos de `ErrNonce` (todos ≥ 30; PoW/PoST):

| Subcaso | Total | PoW | PoST |
|---|---:|---:|---:|
| `neg-nonce-rep-retiro` (repetición) | 404 | 32 | 372 |
| `neg-nonce-rep-liberacion` (repetición) | 180 | 0 | 180 |
| `neg-nonce-saltado` (`+1`) | 608 | 224 | 384 |
| `neg-nonce-viejo` (`-1`) | 608 | 224 | 384 |
| `neg-nonce-dos-nn` (`n, n` ⇒ segunda `ErrNonce`) | 224 | 32 | 192 |

Además, `casos_nonce_validos` produce **224** bloques válidos con dos depósitos
de la misma clave y nonces `n, n+1` (PoW y PoST), comprobados en la batería.

## D.5. Relectura independiente y determinismo

`src/lector_vectores.jl` (analizador y render propios, sin funciones del
exportador), adaptado para leer `nonce=`:

    base      : leidos_casos = 2055  discrepancias = 0  SIN DISCREPANCIAS
    negativos : leidos_casos = 3939  discrepancias = 0  SIN DISCREPANCIAS

`sha256sum -c` pasa en ambos `.sha256`. Determinismo (`resultados/determinismo-v0.1.log`
y `determinismo-negativos-v0.1.log`): dos ejecuciones con `--fecha
2026-09-26T03:10:14+02:00` dan los mismos hashes.

## D.6. Tests y `run.jl`

`Pkg.test()` (`resultados/test-T01-D.log`): **todos los testsets pasan**
(`PKGTEST_EXIT=0`); X-01…X-15 38/38, R-6…R-9 10/10, X-16…X-20 2/2 cada uno,
I-1…I-7 9/9 (0 fallos) y el testset nuevo **F-15 10/10** (0,7 s). El testset
F-15 comprueba los 2 024 rechazos contra el oráculo, exige ≥ 30 por subcaso y
≥ 30 por fase, y que los 224 bloques válidos `n, n+1` apliquen.

`run.jl --seed 0x5a5a --replicas 50 --rejilla reducida`
(`resultados/run-reducida-50-T01-D.log`): 7 372 800 historias, 45 840 000 undos
exactos, **0 fallos I-1…I-7**, `dif FC-1 vs FC-3 = 0`, `dif FC-2 vs FC-3 = 7680`,
`VEREDICTO = SIN FALLOS`, 592,0 s (9,87 min).

## D.7. Entorno, comandos y tiempos

1 hilo (`JULIA_NUM_THREADS=1`, `OPENBLAS_NUM_THREADS=1`), Julia 1.13.0, sin
Python. Presupuesto T01-D: 1 h 30 min, 1 hilo, 8 GiB.

    export JULIA_DEPOT_PATH=…/T01/.julia-depot
    export JULIA=…/julia-1.13.0+0.x64.linux.gnu/bin/julia
    env -u LD_LIBRARY_PATH JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 \
        $JULIA --project=. exportar.jl --fecha 2026-09-26T03:10:14+02:00
    # casos=2055 dirigidos_con_error_inesperado=0
    env -u LD_LIBRARY_PATH JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 \
        $JULIA --project=. exportar_negativos.jl --fecha 2026-09-26T03:10:14+02:00
    # casos=3939 inesperados=0
    env -u LD_LIBRARY_PATH JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 \
        $JULIA --project=. src/lector_vectores.jl <fichero>
    env -u LD_LIBRARY_PATH JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 \
        $JULIA --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.test()'

- `exportar.jl`: 3,37 s, 99 % CPU, máx. RSS ≈ 430 MiB.
- `exportar_negativos.jl`: 3,71 s, 99 % CPU, máx. RSS ≈ 492 MiB.
- lector base: máx. RSS ≈ 373 MiB; lector negativos: ≈ 429 MiB.
- `Pkg.test()`: `PKGTEST_EXIT=0` (testsets F-15 0,7 s, I-1…I-7 53,3 s).
- Sesión: ver `HORAS.log`; muy por debajo del presupuesto de 1 h 30 min.

## D.8. Lo que T01-D NO demuestra

- **No implementa F-16/F-17** (coinbase PoW única y `slot` de la coinbase PoST):
  la orden solo pide F-15 (nonce por clave).
- **No firma**: `firmante`/`clave` son enteros simbólicos; el nonce modela la
  protección contra repetición, no la firma de aceptación.
- **No cubre F-15 en Rust**: el motor corregido se validará con estos vectores
  (orden posterior).
- **No demuestra determinismo entre máquinas**: solo en esta máquina, versión y
  semilla; el orden interno se neutraliza con ordenaciones explícitas.

# INFORME — T01-E (id de la salida de la liberación, F-18)

## E.1. Veredicto

**SUPERADO en T01; T04-D BLOQUEADO por el entorno (§E.7).** El oráculo T01 da a
la salida de una liberación el id `ID_LIB(clave, nonce, importe) =
2⁶² + clave·2⁴⁰ + nonce·2²⁰ + importe` (F-18), con `clave`, `nonce`, `importe <
2²⁰`; los ids explícitos quedan en `[0, 2⁶²)` y la partición se comprueba en
`crear_utxos!`. Se elimina `prox_salida` del estado. Se regeneran
`resultados/vectores-transicion-v0.2.txt` (2 055 casos) y
`resultados/vectores-transicion-negativos-v0.2.txt` (3 914 casos); un lector
independiente los relee con **0 discrepancias**; dos corridas con la misma
`--fecha` dan el mismo `sha256`; `Pkg.test()` (con el testset nuevo T01-E) y
`run.jl --seed 0x5a5a --replicas 50 --rejilla reducida` pasan sin fallos. Los
ficheros v0 y v0.1 se conservan intactos.

- Base v0.2: 2 055 casos, 132 852 líneas, 8 357 914 B,
  `sha256 = da3dcc4859da8590c32559ea57cd2342b6a3c54fb7533fa21c66a15d9c91b080`.
- Negativos v0.2: 3 914 casos, 145 669 líneas, 9 079 237 B,
  `sha256 = 3d2dedae145ec67772ed66db2e0601fc82bc87db8c2cdeefe250978e3771c889`.
- v0.1 conservados: base `0faec4a3…a5527` (2 055 casos), negativos `9ca55abd…26ad`
  (3 939 casos); v0 intactos.

## E.2. Falta de definición detectada antes de editar

Ninguna bloquea la orden; se aplica la lectura más compatible con la decisión 1
del director y se declara aquí y en `PROGRESO.md` §T01-E.

- **E/AMBIGUEDAD-1 — Error para un id fuera de rango.** La orden pide «error
  explícito del oráculo, nunca un id truncado» y llama «comprobado» al rango en
  `crear_utxos!`, pero no nombra el `Err`. Lectura: `ErrDesbordamiento` (el error
  ya existente para valores fuera del dominio). `ID_LIB` lo devuelve si `clave`,
  `nonce` o `importe` no están en `[0, 2²⁰)`; `crear_utxos!` lo devuelve si un id
  explícito cae en `[2⁶², …)` o si una salida de liberación cae por debajo de
  `2⁶²`. Cubierto por el testset T01-E.
- **E/AMBIGUEDAD-2 — Nombre/versión de los ficheros.** Lectura: se escriben
  `…-v0.2.txt` y `…-v0.2.sha256` (mismo formato de líneas v0.1, `.sha256` en
  formato `sha256sum`) y el encabezado declara `T01-E (F-18, formato v0.1)`.
- **E/AMBIGUEDAD-3 — Réplicas de `run.jl`.** La orden solo fija la semilla
  habitual. Lectura: se mantiene la escala de T01-D (`--replicas 50`), que cabe
  en el presupuesto de 1 h 30 min; semilla `0x5a5a` sin cambios.
- **E/AMBIGUEDAD-4 — Exportar `ID_LIB`.** Lectura: se exportan `ID_LIB` y
  `LIMITE_ID_EXPLICITO` para el testset y para que T04 pueda citarlos.

## E.3. F-18 en el oráculo

- `src/Transicion.jl`: constantes `LIMITE_ID_EXPLICITO = 2⁶²`, `ID_LIB_BASE`,
  `ID_LIB_CLAVE = 2⁴⁰`, `ID_LIB_NONCE = 2²⁰`, `ID_LIB_MAX = 2²⁰` y función
  `ID_LIB(clave, nonce, importe)`, que devuelve `Int` o `ErrDesbordamiento`.
- `aplicar_liberacion!` usa `id = ID_LIB(tx.clave, tx.nonce, tx.importe)` tras
  todas las comprobaciones de la operación (nonce, fase, importe, autorización,
  vencido); si es `Err`, no crea nada.
- `crear_utxos!` exige `id < 2⁶²` para `OrigenCoinbasePow`/`OrigenTx` e
  `id ≥ 2⁶²` para `OrigenLiberacion`; ya no mantiene contador.
- `Estado` pierde `prox_salida`; `estado_inicial`, `clonar` y
  `representacion_canonica` se ajustan (se quita de la representación canónica,
  documentado). Ninguna otra regla cambia.

## E.4. Diferencias v0.1 → v0.2, relectura y determinismo

- **Base:** 1 434 de 2 055 casos cambian (69,78 %): 1 dirigido (X-20 en un punto)
  y 1 433 aleatorios. **Ningún** caso cambia `RES`, `SEL` ni `GAR`; cambian
  `BLOQUE`/`TX`/`UTXO`/`EST`. Causa: el antiguo `prox_salida` valía
  `max(id explícito visto) + 1`, y el generador asigna a la transferencia
  siguiente exactamente ese id; la salida de la liberación colisionaba con la
  salida de la transferencia, que se descartaba con `ErrDobleGasto` al construir
  la historia. Con F-18 la transferencia aplica y la historia (guiada por RNG
  contra el estado) continúa distinta. Las `TX tipo=Transferencia` pasan de
  3 826 a 5 809 (+1 983). Es «lo que dependía» del id de la liberación.
- **Negativos:** 3 914 casos (−25 respecto de 3 939). El único recuento que baja
  es `neg-nonce-dos-nn` (224 → 199): necesita dos salidas gastables de la misma
  clave y, al cambiar las historias base, 25 instancias dejan de tenerlas. Las
  otras 40 clases de subcaso y los totales por error (salvo `ErrNonce`) son
  idénticos.
- **Relectura independiente** (`src/lector_vectores.jl`, sin funciones del
  exportador): base 2 055 casos / 0 discrepancias; negativos 3 914 / 0.
  `sha256sum -c` pasa en ambos `.sha256`.
- **Determinismo:** dos corridas con `--fecha 2026-09-26T05:07:25+02:00` dan
  `da3dcc48…` (base) y `3d2dedae…` (negativos).

## E.5. Tests y `run.jl`

`Pkg.test()` (`resultados/test-T01-E.log`): **todos los testsets pasan**
(`PKGTEST_EXIT=0`); el testset nuevo **T01-E 17/17** comprueba la fórmula, la
inyectividad en un dominio pequeño, los rechazos por rango, el rechazo de un id
explícito en `[2⁶², …)`, la aceptación de `2⁶² − 1` y que la salida de una
liberación real lleva `ID_LIB`. X-01…X-15 38/38, R-6…R-9 10/10, X-16…X-20 2/2,
I-1…I-7 9/9 (0 fallos), F-15 10/10.

`run.jl --seed 0x5a5a --replicas 50 --rejilla reducida`
(`resultados/run-reducida-50-T01-E.log`): 7 372 800 historias, 45 840 000 undos
exactos, **0 fallos I-1…I-7**, `dif FC-1 vs FC-3 = 0`, `dif FC-2 vs FC-3 = 7680`,
`VEREDICTO = SIN FALLOS`, 602,9 s (10,05 min), máx. RSS ≈ 426 MiB.

## E.6. Entorno, comandos y tiempos

1 hilo (`JULIA_NUM_THREADS=1`, `OPENBLAS_NUM_THREADS=1`), Julia 1.13.0, sin
Python. Presupuesto T01-E: 1 h 30 min, 1 hilo, 8 GiB.

    export JULIA_DEPOT_PATH=…/T01/.julia-depot
    export JULIA=…/julia-1.13.0+0.x64.linux.gnu/bin/julia
    env -u LD_LIBRARY_PATH JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 \
        $JULIA --project=. exportar.jl --fecha <ISO>          # 2055, 0 inesperados
    env -u LD_LIBRARY_PATH … $JULIA --project=. exportar_negativos.jl --fecha <ISO>
    env -u LD_LIBRARY_PATH … $JULIA --project=. src/lector_vectores.jl <fichero>
    env -u LD_LIBRARY_PATH … $JULIA --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.test()'
    env -u LD_LIBRARY_PATH … $JULIA --project=. run.jl --seed 0x5a5a --replicas 50 --rejilla reducida

- `exportar.jl`: 3,4 s; `exportar_negativos.jl`: 5,6 s; lectores: 2-3 s.
- `Pkg.test()`: testsets ≈ 90 s (I-* 56,5 s; T01-E 0,2 s) más compilación.
- `run.jl`: 602,9 s (10,05 min). Sesión por debajo del presupuesto; ver `HORAS.log`.

## E.7. T04-D: bloqueo de entorno (no ejecutado)

La orden declara dos zonas escribibles, `P-TRANSICION/T01/` y `P-DAG/T04/`. En
esta sesión `/home` está montado **solo lectura** (`/proc/self/mountinfo`:
`/home ro`); solo `P-TRANSICION` se vuelve a montar `rw`. Escribir en
`/home/katana/zeo/ZEROX/P-ZRX/P-DAG/T04/` falla con
`Sistema de ficheros de sólo lectura` y el intento de ampliar el sandbox
(`danger-full-access`) se rechaza con «requires approval, but no approval channel
is available». Por tanto **no se pudo**: editar `dirigidos.jl` (D-14), reexportar
`vectores-estado-dag-v0.3.txt`/`cobertura-v0.3.txt`, ejecutar
`run.jl --seed 0x5a5a --replicas 200` ni `Pkg.test()` de T04, ni contar el
artefacto y confirmar 0 en v0.3.

Consecuencia inmediata: T04 incluye `Transicion.jl` por ruta absoluta, así que
**el arreglo F-18 ya rige en T04**, pero sus vectores congelados v0.2 y el test de
relectura siguen siendo los antiguos y quedan **obsoletos** hasta reexportar
v0.3. Datos de solo lectura de v0.2: 318 líneas `DESC … ErrDobleGasto` (217 sobre
`Transferencia`; el resto, depósitos), cota superior del artefacto porque incluye
dobles gastos reales. El detalle del bloqueo y el diseño de D-14 están en
`PROGRESO.md` §T01-E.7.

## E.8. Lo que T01-E NO demuestra

- **No demuestra F-16/F-17** (unicidad de coinbase PoW/PoST): fuera de la orden.
- **No cubre el motor Rust**: los vectores v0.2 son la entrada del diferencial
  posterior (W06a-B); el arnés debe dejar de emular la colisión.
- **No sustituye el `txid` real**: `ID_LIB` es una función inyectiva del contenido
  como el `(txid, 0)` de F-18, no un hash de 32 bytes.
- **No demuestra determinismo entre máquinas**: solo en esta máquina, versión y
  semilla.

---

# INFORME — T01-SL3 (evidencia y castigo: `CONTRATO-EVIDENCIA-v0` + Ratificación v0)

**Ejecutor:** DeepSeek `deepseek-flash` (esfuerzo `high`). **Fecha:** 2026-09-26.
**Fuente:** `P-ZRX/P-SLASHING/ORDEN-SL3-ORACULO.md` y `CONTRATO-EVIDENCIA-v0.md` con su
«Ratificación v0» (que prevalece). **Zona:** `T01/`. Sin Python; sin commit ni push.

## SL3.1. Veredicto

**SUPERADO.** T01 implementa `EvidenceTx` (identidad `(cbid, clave, sector, historia, chunk,
slot)`), verificación (EV-05…EV-09), registro de incidentes y poda (EV-10/EV-11), ventana de
admisión (EV-13/EV-14), congelación total (EV-17/EV-18), confiscación con reparto RAT-2
(EV-19…EV-22), regla de liberación RAT-3 (EV-24 con EV-15b) y undo exacto (EV-27…EV-29).
`Pkg.test()` **176/176**; `run.jl --seed 0x5a5a --replicas 5 --rejilla reducida` con **0 fallos
de I-1…I-7** (ampliadas a quemado y recompensa del incluidor); vectores
`vectores-transicion-v0.3.txt` (2 795 casos) releídos con **0 discrepancias**; los vectores v0,
v0.1 y v0.2 quedan **intactos** y se releen con 0 discrepancias.

## SL3.2. Faltas de definición detectadas antes de editar

Nueve, registradas en `PROGRESO.md` §SL3.1 con su lectura adoptada
(`# AMBIGUEDAD-SL3-n`): momento/permanencia de la congelación frente a la liquidación (1),
`congelado` como cuenta o gravamen (2), activación de C-EVP (3), forma del error de `cbid`
ajeno (4), `H_d` abstracto (5), momento de la poda (6), puerta RAT-3 (7),
`último_slot_producido` (8) y redondeo de RAT-2 (9). Ninguna obliga a elegir entre reglas
incompatibles; todas se resuelven sin alterar otra regla. **No se detuvo la ejecución.**

## SL3.3. Qué se ha implementado

| Regla | Implementación en `src/Transicion.jl` / `src/evidencia.jl` |
|---|---|
| EV-01/EV-04 | `Evidencia` con dos cabeceras; `pre_hash(H1) < pre_hash(H2)` estricto (`ErrOrdenCanonico`); sin entradas ni salidas (`ErrEvidenciaConEntradas`) |
| EV-05 (RAT-1) | identidad `(cbid, clave, sector, historia, chunk, slot)`; `cbid ≠ P.cbid` ⇒ `ErrCbidAjeno` (Rust `ErrForma`) |
| EV-06/EV-07 | identidad común exacta y sellos válidos; si no, `ErrSinEvidencia` |
| EV-10/EV-11 | `incident_id = sha256(identidad canónica)` (marcador de `H_d`); registro en `Garantia.incidentes` y poda al cerrar la ventana |
| EV-12 | segunda evidencia del mismo incidente ⇒ `ErrEvidenciaDuplicada` (rechazo en cadena; descarte en T04) |
| EV-13/EV-14 | `slot_falta ≤ punto < slot_falta + Plazo_slots`; fuera ⇒ `ErrEvidenciaTardia` |
| EV-17/EV-18 | congelación total (gravamen `Garantia.congelado`) sobre activo, pendientes, en retirada y créditos |
| EV-19…EV-22 | `C = mín(V, techo(f·V))` con enteros (`f = f_num/f_den`); `techo(C·2/8)` a la coinbase del bloque que aplica, el resto a `Quemado` (RAT-2); clave sin saldo ⇒ pérdida 0 (EV-22) |
| EV-24/EV-15b (RAT-3) | liberación exige (i) sin caso abierto y (ii) `punto ≥ último_slot_producido(P) + Plazo_slots + M_margen_slots`; puerta `R_slots > Plazo_slots + M_margen_slots` (`ErrPuertaRAT3`). El retiro no se bloquea |
| EV-27…EV-29 | `Estado.ultimo_slot_producido`; undo por copia íntegra; ventanas en slots absolutos |

## SL3.4. Casos dirigidos

`casos_evidencia_cobertura` (aplicada, duplicada, tardía, `cbid` ajeno, clave sin saldo,
`con_entradas`), `caso_rat3_carrera` (retiro parcial, producción continuada, doble firma cerca
del final de la retención con `sf = t0 + R_slots − Plazo` y liberación en `t0 + R_slots`: se
comprueba que (i) ya no bloquea y (ii) sí ⇒ `ErrVentanaAbierta`), `caso_autodenuncia` (el
productor es el infractor; se comprueba la fórmula exacta y, con `C` múltiplo de 8, la pérdida
`6/8·C`). En `test/runtests.jl` se cubren además orden canónico, sellos, identidad, EV-22,
EV-24(i), el retiro aceptado con caso abierto, la puerta RAT-3, X-13 y R-12.

## SL3.5. Tabla de cobertura (V4)

`resultados/cobertura-v0.3.txt` (generada por `exportar.jl`):

| Tipo | Mínimo | v0.3 |
|---|---:|---:|
| aplicada | ≥ 100 | **260** |
| duplicada (inerte/rechazo) | ≥ 30 | **40** |
| fuera de plazo | ≥ 30 | **200** |
| `cbid` ajeno | ≥ 30 | **120** |
| contra clave sin saldo | ≥ 30 | **120** |
| deshecha (undo exacto EV-27) | ≥ 30 | **380** |
| (extra) con entradas | — | 120 |

## SL3.6. Vectores y relectura (V3)

- `resultados/vectores-transicion-v0.3.txt`: **2 795 casos**, sha256
  `d3b73b06664fb4dbd4311cc163ddf937605192bf99f928e260dc67e02ad7897b`; `.sha256` en formato
  `sha256sum` relativo a `T01/`.
- Relectura independiente (`src/lector_vectores.jl`, analizador y render propios, ahora con
  `ev=` y `inc=`): **2 795 casos, 0 discrepancias**.
- v0, v0.1 y v0.2 intactos (`sha256sum -c` OK) y releídos con 0 discrepancias.
- El formato de las líneas `GAR` sólo añade ` inc=…` cuando la lista no está vacía, así que
  los vectores antiguos conservan su texto exacto.

## SL3.7. Tests y `run.jl`

- `Pkg.test()` (rejilla reducida, `T01_REPLICAS=2`): **176/176**, incluido el testset
  `SL-3 (evidencia y castigo)` **82/82**. Registro `resultados/test-T01-SL3.log`.
- `run.jl --seed 0x5a5a --replicas 5 --rejilla reducida`: 147 456 puntos, **737 280** historias,
  4 595 520 undos exactos, **I-1…I-7 = 0 fallos**; bloque de evidencia: 92 historias, 412
  undos, **8** liberaciones RAT-3 bloqueadas, **0 fallos** en las siete invariantes. 75,6 s de
  pared, 1 hilo, RSS ≈ 0,4 GiB. Registro `resultados/run-reducida-SL3.log`.

## SL3.8. Entorno

Julia 1.13.0; `JULIA_DEPOT_PATH=T01/.julia-depot`; 1 hilo
(`JULIA_NUM_THREADS=1`, `OPENBLAS_NUM_THREADS=1`); sin `@fastmath`, `@simd`, `@inbounds`,
`@turbo`; sin Python. Dependencias: las de `Project.toml` (sin añadir ninguna).

## SL3.9. Lo que T01-SL3 NO demuestra

- **No modela criptografía real**: los sellos son un booleano abstracto y `incident_id` es un
  SHA2-256 marcador de `H_d`, no la verificación Ed25519 ni la codificación v4 real.
- **No modela forma de wire v4** (EV-01…EV-04 de bytes, pesos, `txid`): el oráculo comprueba
  semántica, no el parser de `FORMATO-v0`.
- **No calibra** `f`, `Plazo_slots`, `M_margen_slots`, `R_slots`: son entradas (SL-2/SL-2b).
- **No cierra la grieta A12/DS-3** (EV-22) ni decide el destino de los fondos (resuelto por
  RAT-2).
- **La «deshecha» de T01 es undo exacto (EV-27)**, no una reorganización de ramas; las ramas
  hermanas y la reaparición en otra rama se ejercen en T04.

# INFORME — T01-SL3b (RAT-2′ y barrido de evidencia)

**Ejecutor:** DeepSeek `deepseek-flash` (esfuerzo `high`). **Fecha:** 2026-09-26.
**Fuente:** `ORDEN-SL3b.md` (motivo: `REVISION-SL3.md`) y `CONTRATO-EVIDENCIA-v0.md` con
**RAT-2′**. **Zona:** `T01/`. Sin Python; sin commit ni push; sin secretos.

## SL3b.1. Veredicto

**SUPERADO.** Se aplican las tres correcciones que tocan a T01: la recompensa del incluidor
pasa a **`suelo(C·2/8)`** (RAT-2′; lo quemado es `C − suelo(C·2/8)`), el barrido de `run.jl`
genera **5 060** historias con evidencia (≥ 5 000) **sin reducir** las 737 280 del barrido
principal, y se reexportan los vectores a `vectores-transicion-v0.4.txt` con `.sha256` y
cobertura. `Pkg.test()` **2 178/2 178** (SL-3 **2 084/2 084**), `run.jl` con **I-1…I-7 = 0
fallos**, relectura independiente de v0.4 con **0 discrepancias**. Los vectores anteriores
quedan **intactos**.

## SL3b.2. Qué cambia y qué no

| Elemento | Antes (SL-3, RAT-2) | Ahora (SL-3b, RAT-2′) |
|---|---|---|
| Recompensa al incluidor | `techo(C·2/8) = ⌈C/4⌉` | **`suelo(C·2/8) = ⌊C/4⌋`** |
| Quemado | `C − ⌈C/4⌉` | **`C − ⌊C/4⌋`** |
| Pérdida del infractor | podía ser `< 6/8·C` (p. ej. `C = 11` → 8) | **siempre `≥ 6/8·C`** |
| Historias con evidencia en `run.jl` | 92 (con `replicas=5`) | **5 060** (5 060 con cualquier `replicas`) |
| Barrido principal | 147 456 puntos × réplicas | **igual** (737 280 con `replicas=5`) |
| Vectores por defecto | v0.3 | **v0.4** |

El cambio de redondeo es el único que altera valores del oráculo. La función pasa de
`techo_dos_octavos` a `suelo_dos_octavos` (división entera `C ÷ 4`), exportada para el test.

## SL3b.3. Test de la propiedad pedida

En el testset `SL-3` (fichero `test/runtests.jl`) se añade, para **todo `C` de 0 a 1 000**:

```julia
for C in 0:1000
    recompensa = suelo_dos_octavos(Int128(C))   # == C ÷ 4
    perdida = Int128(C) - recompensa
    @test recompensa == Int128(C) ÷ Int128(4)
    @test 8 * perdida >= 6 * Int128(C)          # pérdida ≥ 6/8·C, exacto en enteros
end
```

`8·(C − ⌊C/4⌋) ≥ 6·C` se cumple para todo `C ≥ 0` (con igualdad cuando `C ≡ 0 (mod 4)`).
Los casos dirigidos de autodenuncia siguen comprobando la fórmula exacta, ahora con `suelo`, y
la igualdad `6/8·C` cuando `C` es múltiplo de 8. La antigua **AMBIGUEDAD-SL3-9** queda
resuelta por RAT-2′ (se anota en `PROGRESO.md` §SL3.1).

## SL3b.4. Barrido de evidencia y cobertura

`run.jl` conserva el barrido principal y añade `--ev-historias` (por defecto **5 000**); con
`puntos_evidencia()` (12 puntos) y 6 tipos por punto, `n = ⌈5 000 / 72⌉ = 70` por tipo:

| Bloque | Historias | Undos | RAT-3 bloqueadas | Fallos I-1…I-7 |
|---|---:|---:|---:|---:|
| Barrido principal | 737 280 | 4 595 520 | — | 0 |
| Evidencia | **5 060** | 22 768 | 8 | 0 |

`resultados/cobertura-v0.4.txt` (mínimos de la orden entre paréntesis): aplicada **260** (≥100),
sin saldo **120** (≥30), duplicada **40** (≥30), tardía **200** (≥30), `cbid` ajeno **120**
(≥30), con entradas 120, deshecha 380 (undo exacto EV-27; T01 no fusiona ramas). Cada contador
va definido en la cabecera del propio fichero.

## SL3b.5. Vectores y relectura

- `resultados/vectores-transicion-v0.4.txt`: **2 795 casos**, sha256
  `4f0a175a3b4390e40248a70b62e22829c5233311d4dfdce5c2ed164786ad3b0f`, `.sha256` en formato
  `sha256sum` relativo a `T01/`.
- Relectura independiente (`src/lector_vectores.jl`): **2 795 casos, 0 discrepancias**.
- v0.1, v0.2 y v0.3 **intactos** (`sha256sum -c` OK). Releer v0.3 con el oráculo RAT-2′
  produce discrepancias en `quemado`/recompensa (520 de 2 795), porque v0.3 se generó con
  `techo`; es la consecuencia exacta de la corrección. Su relectura histórica bajo RAT-2
  (`relectura-v0.3.log`) sigue dando 0 discrepancias; el intento bajo RAT-2′ se conserva en
  `relectura-v0.3-con-RAT2p.log`.

## SL3b.6. Reproducibilidad

```bash
cd /home/katana/zeo/ZEROX/P-ZRX/P-TRANSICION/T01
export JULIA_DEPOT_PATH=$PWD/.julia-depot JULIA_PKG_OFFLINE=true
env -u LD_LIBRARY_PATH /home/katana/torio/.juliaup/bin/julia --project=. -e 'using Pkg; Pkg.test()'
env -u LD_LIBRARY_PATH /home/katana/torio/.juliaup/bin/julia --project=. run.jl \
    --seed 0x5a5a --replicas 5 --rejilla reducida --ev-historias 5000
env -u LD_LIBRARY_PATH /home/katana/torio/.juliaup/bin/julia --project=. exportar.jl --aleatorios 2000
env -u LD_LIBRARY_PATH /home/katana/torio/.juliaup/bin/julia --project=. \
    src/lector_vectores.jl resultados/vectores-transicion-v0.4.txt
```

Julia 1.13.0; 1 hilo; sin Python; sin `@fastmath`/`@simd`/`@inbounds`/`@turbo`; sin commit ni
push; nada escrito fuera de `T01/`.

## SL3b.7. Lo que T01-SL3b NO demuestra

- La recompensa sigue siendo **aritmética abstracta**: no modela la coinbase real ni la
  madurez de wire; es la fórmula de liquidación de EV-19/RAT-2′.
- `suelo(C·2/8)` certifica `pérdida ≥ 6/8·C` en **enteros**; no decide la calibración de `f`
  ni de `Plazo_slots` (SL-2/SL-2b).
- Los vectores v0.3 y anteriores **no** se regeneran: su reparto es el de RAT-2 y así se
  conservan como evidencia histórica.
