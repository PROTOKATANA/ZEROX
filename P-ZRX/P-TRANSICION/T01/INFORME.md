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
