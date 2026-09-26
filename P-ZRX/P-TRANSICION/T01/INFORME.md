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
