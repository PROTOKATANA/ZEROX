# PROGRESO — T01

Bitácora de ejecución. Las horas solo salen de `date -Is` (ver `HORAS.log`).

## 1. Comprobación de la entrada congelada (inicio)

Comando:

    cd /home/katana/zeo/ZEROX && LC_ALL=C sha256sum -c P-ZRX/P-TRANSICION/ENTRADA-T01.sha256

Salida completa:

    P-ZRX/P-TRANSICION/ORDEN-T01.md: OK
    P-ZRX/P-TRANSICION/CONTRATO-v0.md: OK
    V-ZRX/LINEO.md: OK
    D-ZRX/SPEC.md: OK

Lectura íntegra confirmada de `ORDEN-T01.md`, `V-ZRX/LINEO.md`,
`P-ZRX/P-TRANSICION/CONTRATO-v0.md` y de `D-ZRX/SPEC.md` §§3–6 (contexto no normativo).
Plantilla histórica revisada como estilo, sin copiar código.

## 2. Falta de definición detectada antes de editar (obligatorio informar)

Antes de escribir código se registran las reglas que admiten más de una implementación
incompatible. Según la orden §3, se aplica **la lectura más restrictiva** (la que rechaza más)
cuando no altera el significado de otra regla, se marca en el código con `# AMBIGUEDAD-n` y se
reporta aquí y en `INFORME.md`. Ninguna de las lecturas elegidas altera otra regla del contrato,
así que **no procede detenerse**; se documenta cada una.

### AMBIGUEDAD-1 — Tipo de `Emitido` (orden §3.11 vs §4.2)
`§4.2` escribe `emitido::UInt64`; `§3.11` define `Emitido := Σ_B (coinbase_pagada(B) − tarifas(B))`
«en `Int128`» y avisa de que «el término puede ser negativo». Lectura aplicada: `emitido::Int128`
(y `quemado::Int128`), con la aritmética monetaria por salida en `UInt64` comprobado. Regla
afectada: I-1 / TRN-01.

### AMBIGUEDAD-2 — Retirada múltiple por clave
`C-BON-05` dice «a lo sumo hay una retirada pendiente por clave; otra se rechaza o consolida por
una regla única todavía PENDIENTE». La orden `§3.15`/`§4.2` modela `en_retirada` como **lista** y no
fija el caso de una segunda retirada. Lectura aplicada (restrictiva): una segunda `Retiro` con una
`en_retirada` viva se **rechaza** con un error explícito propio `ErrRetiroPendiente` (la orden
permite errores «al menos» los listados). Regla afectada: C-BON-05 / TRN-10.

### AMBIGUEDAD-3 — Transferencia con salidas > entradas (tarifa negativa)
`§3.11` define `tarifas(B) = Σ (entradas − salidas)` pero no prohíbe que sea negativa; con una
transferencia que cree valor, `Emitido` crecería y I-1 seguiría cerrándose (acuñación silenciosa).
Lectura aplicada (restrictiva): en `Transferencia`, `Σ salidas ≤ Σ entradas`, si no `ErrSaldo`.
Regla afectada: C-TX / I-1 / X-02.

### AMBIGUEDAD-4 — Madurez `M_dep = 0` y el orden (b) antes de (d)
La orden `§3.9` promueve pendientes en (b) **antes** de aplicar transacciones (d), pero TRN-03 dice
que un depósito pasa a activo en `h + M_dep`, y la rejilla admite `M_dep = 0`. Lectura aplicada: al
crear un pendiente cuya madurez ya se cumple en el punto del bloque, se acredita **directo a
`activo`** (equivale a promover dentro del mismo bloque). Regla afectada: TRN-03.

### AMBIGUEDAD-5 — I-7 literal frente a `CUT-H` y `CUT-W`
I-7 dice «`Φ` falso ⇒ no hay bloque PoST válido … hasta el primer bloque PoW posterior que haga
verdadero TRN-04». Bajo `CUT-HWΦ` eso es consecuencia de TRN-04+TRN-06, pero `CUT-H`/`CUT-W`
**definen** TRN-04 sin `Φ`, de modo que la lectura literal es incompatible con esas interfaces.
Lectura aplicada (compatible con todas): un bloque PoST válido exige un terminal en su pasado
(TRN-06) y el terminal es el primer bloque de la rama que cumple la interfaz `Corte` elegida; para
`CUT-HWΦ` eso implica literalmente `Φ` verdadero. Se prueba I-7 estructuralmente en toda la rejilla
y la forma literal en los puntos `CUT-HWΦ`. Regla afectada: TRN-04/TRN-06/I-7.

### AMBIGUEDAD-6 — Posición de la coinbase dentro del bloque
`§3.9(d)` dice «coinbase **primera**» pero no fija el error si no lo está, ni el número de coinbases.
Lectura aplicada: se aplica la coinbase antes que el resto (independientemente de su posición en la
lista) y **más de una** coinbase por bloque es `ErrEmision`. Regla afectada: C-EMIT-03.

### AMBIGUEDAD-7 — Errores para violaciones de forma sin error asignado
`§4.4`/§6 listan los errores, pero no asignan uno a: `trabajo < 1` o `pow_ok = false`; `altura` que
no avanza; `peso PoST < 1`; `slot` no creciente. Lectura aplicada: `ErrPow` para `pow_ok`/`trabajo`
y `ErrSlot` para progresión de altura/slot y `peso < 1`. Regla afectada: forma de bloque, TRN-04.

### AMBIGUEDAD-8 — `SEC-0` con operaciones de sector
En `SEC-0` no hay registro de sectores; la orden no fija qué pasa con `AltaSector`/`PruebaSector`.
Lectura aplicada: `ErrFueraDeAlcanceV0`; el campo `sector` de un bloque PoST se ignora en `SEC-0`.
Regla afectada: interfaz `Sectores`.

### AMBIGUEDAD-9 — Alta de sector fuera de plazo/fase
La orden `§3.7` saca de alcance v0 las altas en PoST ⇒ `ErrFueraDeAlcanceV0`. El contrato exige
`H_dep` para el alta en PoW; se usa `ErrDepositoTemprano` antes de esa altura. Regla afectada:
TRN-12 / interfaz `Sectores`.

### AMBIGUEDAD-10 — `EvidenceTx` en PoW y en PoST
La orden `§3.7` la declara fuera de alcance en PoST ⇒ `ErrFueraDeAlcanceV0`; X-13 fija
`ErrOperacionFase` en PoW. Se implementa así. Regla afectada: C-EVP-03.

### AMBIGUEDAD-11 — Madurez de un depósito creado en fase PoST
TRN-03 solo describe depósitos PoW. Lectura aplicada: un depósito en PoST madura en
`slot(B) + M_dep_slots`. Regla afectada: TRN-03.

### AMBIGUEDAD-12 — Naturaleza del `undo`
La orden exige undo exacto y permite «lo que necesites». Lectura aplicada: `aplicar` construye un
estado **nuevo** (copia) y `deshacer` restituye una copia íntegra del estado previo; no hay lógica
delta que pueda desincronizarse. Se declara en `METODO.md`/`INFORME.md`. Regla afectada: I-2.

### AMBIGUEDAD-13 — Bloques huérfanos en `seleccionar`
La orden no fija la validez de un bloque cuyo padre no está en el conjunto. Lectura aplicada
(restrictiva): un huérfano no es válido y sus descendientes tampoco; `nodo_en_linea` sí los
retiene hasta que llegue el padre. Regla afectada: TRN-09.

## 3. Presupuesto y decisión

Presupuesto declarado: 2 h de reloj, 1 hilo, 8 GiB RAM, 2 GiB disco (incluido `.julia-depot`).
Criterio de aceptación fijado antes de ejecutar: SUPERADO si X-01…X-20 e I-1…I-7 pasan en toda la
rejilla reducida sin contraejemplos; REFUTADO ante contraejemplo del contrato; INCONCLUSO si se
agota el presupuesto o hay ambigüedad que obligue a elegir sin lectura compatible.

No hay ambigüedad que obligue a elegir sin lectura compatible: las 13 anteriores se resuelven con
la lectura restrictiva/compatible sin alterar otra regla.

## 4. Ejecución — `Pkg.test()` (rejilla reducida completa)

Comando (ORDEN §6.4), con `JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1` y la
`JULIA_DEPOT_PATH` de la zona:

    $JULIA --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.test()'

Resultado: **todos los testsets pasan** (salida completa en `resultados/test.log`).

- `X-01…X-15 (rechazos)`: 38/38 en 6,8 s sobre los **147 456** puntos de la
  rejilla reducida (cada caso se prueba en todos los puntos donde tiene sentido).
- `X-16 (orden de llegada)`: 2/2 (subconjunto con paso `T01_PASO_XEQ=2000`,
  por el coste combinatorio de permutar; ver `METODO.md` §4).
- `X-17`, `X-18`, `X-19`, `X-20`: 2/2 cada uno.
- `I-1…I-7 (historias aleatorias)`: 9/9. `n_hist = 294 912` historias
  (147 456 puntos × `T01_REPLICAS=2`), `n_undo = 1 833 609`,
  `n_perm = 344 073`; **cero fallos** en I-1, I-1b, I-2, I-3, I-4, I-5, I-6, I-7.

Diferencias registradas (dato, sin juicio): X-17 `difiere FC-1=0`, `FC-2=6`;
X-18 `difiere FC-1=52`, `FC-2=6` (paso `T01_PASO_XEQ=2000`).

Desviación declarada: los casos de igualdad X-16…X-20 se recorren en un
subconjunto de la rejilla (paso 2000), no en los 147 456 puntos, porque cada
uno permuta el conjunto de bloques con `nodo_en_linea`; X-01…X-15 e I-1…I-7 sí
recorren la rejilla completa. Se cuantifica en `INFORME.md`.

## 5. Segunda pasada de `Pkg.test()` (X-17…X-20 en rejilla completa)

Se repitió `Pkg.test()` dejando en subconjunto (paso 2000) solo X-16, por su
coste combinatorio. Resultado: **todos los testsets pasan**.

- `X-17` y `X-18`: 2/2, rejilla completa. Diferencias respecto a FC-3:
  X-17 `FC-1=0`, `FC-2=6144`; X-18 `FC-1=96000`, `FC-2=6144`.
- `X-19`: 2/2 (3,2 s). `X-20`: 2/2 (9,8 s), rejilla completa.
- `I-1…I-7`: 9/9; `n_hist=294912`, `n_undo=1833609`, `n_perm=344073`, cero fallos.
- Comprobación de `ENTRADA-T01.sha256` al terminar:

      P-ZRX/P-TRANSICION/ORDEN-T01.md: OK
      P-ZRX/P-TRANSICION/CONTRATO-v0.md: OK
      V-ZRX/LINEO.md: OK
      D-ZRX/SPEC.md: OK

- `run.jl --replicas 200 --rejilla reducida`: 29 491 200 historias, 183 406 080
  undos, 4 155 744 permutaciones (I-3 muestreado 1/200), **cero fallos** en
  I-1…I-7; 38,77 min de pared. Supera el umbral de 30 min de ORDEN §6.5; se
  perfila y documenta en `METODO.md` §2/§4 y `INFORME.md` §1.

## 6. Cierre de la batería de tests (rejilla completa en los 20 X)

Tercera pasada de `Pkg.test()`: X-16 también sobre los 147 456 puntos,
revisando 7 órdenes por punto (identidad, inverso y 5 aleatorios). Todos los
testsets pasan; X-16 tardó 9,9 s. Con esto los **20 casos X y los 7 invariantes
se comprueban en la rejilla reducida completa** (147 456 puntos). Único
muestreo declarado: I-3 en `run.jl`, 1 de cada 200 historias (4 155 744
permutaciones), por coste. El texto de §4 sobre un subconjunto para X-16 queda
así corregido por esta pasada.

---

# PROGRESO — T01-B

Bitácora de la orden T01-B (exportador de vectores del oráculo). Presupuesto
declarado **antes** de ejecutar: 1 h 30 min de reloj, 1 hilo, 8 GiB de RAM,
2 GiB de disco; prohibido Python. Horas solo de `date -Is` (`HORAS.log`).

## T01-B.1. Comprobación de la entrada congelada (inicio)

Comando (desde `/home/katana/zeo/ZEROX`):

    LC_ALL=C sha256sum -c P-ZRX/P-TRANSICION/ENTRADA-T01-B.sha256

Salida completa:

    P-ZRX/P-TRANSICION/ORDEN-T01-B.md: OK
    P-ZRX/P-TRANSICION/CONTRATO-v0.md: OK
    P-ZRX/P-TRANSICION/ORDEN-T01.md: OK
    V-ZRX/LINEO.md: OK

Lectura íntegra confirmada de `ORDEN-T01-B.md`, `V-ZRX/LINEO.md`,
`CONTRATO-v0.md` (incluido «Ratificaciones v0.1»), `ORDEN-T01.md`, del código
de `T01/` y, como contexto del consumidor, `ORDEN-W03.md`, `FORMATO-v0.md` y
`REVISION-W02.md`.

## T01-B.2. Falta de definición detectada ANTES de editar (obligatorio informar)

Se registran aquí las reglas de `ORDEN-T01-B` que admiten más de una
implementación, o que chocan con otra regla de la misma orden. Se aplica la
lectura más compatible con §3.1 (solo interfaces por defecto) y con la
reproducibilidad exigida en §4, sin alterar la semántica del contrato.

### T01-B/AMBIGÜEDAD-1 — Los 3 puntos dirigidos frente a «solo interfaces por defecto»
§3.2(a) pide los casos X-01…X-20 en 3 puntos «(el primero, el del medio y el
último de la enumeración que ya usa `run.jl`)»; §3.1 exige exportar **solo**
las interfaces por defecto (`CUT_HWPhi`, `FC3`, `SEC0`). La enumeración
completa de `puntos_rejilla(:reducida)` (147 456 puntos) tiene en las
posiciones central (73 728) y final (147 456) puntos con `SEC-A`, `CUT-W` y
`FC-2`, que no se exportan. Lectura aplicada: se enumeran los puntos reducidos
**restringidos a las interfaces por defecto** (8 192 puntos) y se toman sus
índices primero = 1, medio = 4 096 y último = 8 192. Así los tres `PARAM`
exportados usan `CUT_HWPhi`/`FC3`/`SEC0`. Regla afectada: §3.1 vs §3.2(a).

### T01-B/AMBIGÜEDAD-2 — Reparto de las 2 000 historias aleatorias
§3.2(b) pide 2 000 historias «repartidas uniformemente» sobre los puntos por
defecto, con «semilla maestra `0x5a5a`, réplica `r` con `StableRNG(0x5a5a + r)`»,
pero no fija cómo se asigna cada réplica `r` a un punto (2 000 < 8 192, así que
no se cubren todos). Lectura aplicada (determinista y reproducible): `r` recorre
`1:2000`; el punto de la réplica `r` es el índice
`p(r) = 1 + round(Int, (r-1)*(N-1)/(2000-1))` con `N = 8192`, es decir un
reparto equiespaciado que incluye el primero y el último; cada historia usa
`StableRNG(0x5a5a + UInt64(r))` y su `semilla` es `0x5a5a + r` en decimal.
Regla afectada: §3.2(b).

### T01-B/AMBIGÜEDAD-3 — Fecha del encabezado frente a determinismo
§3.4 exige un encabezado con `<fecha de date -Is>` y §4 exige que «dos
ejecuciones del exportador producen el mismo `sha256`». Una marca de tiempo
viva impide ambas cosas a la vez. Lectura aplicada: el exportador acepta
`--fecha <ISO-8601>`; por defecto usa la hora actual con el formato de
`date -Is`. La comprobación de determinismo se hace con la **misma** `--fecha`
en las dos corridas y el fichero entregado registra la fecha usada. Regla
afectada: §3.4 vs §4.

### T01-B/AMBIGÜEDAD-4 — Casos dirigidos no representables como vector releíble
§3.2(a) pide «todos los casos dirigidos X-01…X-20 que tengan sentido».
- **X-12** (terminal que no es el primero) se construye en `escenarios_rechazo`
  sobre un estado manual (`Eman`) al que ninguna secuencia de bloques puede
  llegar: cualquier PoW posterior a un terminal se rechaza con
  `ErrPowTrasCorte`. El formato v0 define `RES` como la validez **releíble** de
  cada bloque sobre el estado de su padre, así que X-12 no es representable;
  queda cubierto por `test/runtests.jl` e I-4/I-7. Se omite del fichero.
- **X-15** (SEC-A: prueba tardía, sector inactivo) no pertenece a las
  interfaces por defecto (`SEC0`); se omite.
Regla afectada: §3.1 vs §3.2(a).

### T01-B/AMBIGÜEDAD-5 — Alcance de R-7 en el génesis
R-7 obliga a que la coinbase PoW tenga al menos una salida («la del génesis,
una de valor 0»), pero el génesis del oráculo T01 (`genesis_bloque()`) no
lleva transacción ninguna y `X-01` asigna `ErrGenesis` a un génesis mal formado.
Lectura aplicada: R-7 se comprueba en **cualquier** `TxCoinbase` presente,
incluido un génesis que la traiga; sin salidas ⇒ `ErrEmision` (nombre literal
de R-7); el génesis por defecto con `ntx=0` sigue siendo válido y el génesis
con salida `> 0` sigue dando `ErrGenesis`. Regla afectada: R-7 vs X-01.

### T01-B/AMBIGÜEDAD-6 — Orden de las sublistas de `GAR`
El formato fija «UTXO por `(dueño, valor, origen, altura, slot)`; GAR por
`clave`» pero no el orden interno de `pend`, `ret` y `cred`. Lectura aplicada
(canónica y compartida por exportador y lector): `pend` por
`(importe, madura_en_altura, madura_en_slot)`; `ret` por
`(inicio_slot, importe)`; `cred` por `(importe, madura_en_slot)`. Regla
afectada: §3.4.

### T01-B/AMBIGÜEDAD-7 — Hash del contrato en el encabezado
`<sha256 del contrato <hash>>` no dice de qué fichero. Lectura aplicada:
`CONTRATO-v0.md` (la ruta por defecto es la absoluta de
`P-ZRX/P-TRANSICION/CONTRATO-v0.md`, parametrizable con `--contrato`).
Regla afectada: §3.4.

No hay ninguna falta de definición que impida exportar o que obligue a
detenerse: todas se resuelven con una lectura determinista y compatible con
§3.1 y §4, y se marcan en el código.

## T01-B.3. Ratificaciones v0.1 aplicadas y tests

Se aplican R-6…R-9 en `src/Transicion.jl`, marcadas con
`# RATIFICACION-v0.1-Rn` (§3.3 de la orden): R-6 coinbase no primera ⇒
`ErrEmision`; R-7 `TxCoinbase` sin salidas ⇒ `ErrEmision`; R-8 importe 0 en
`CoinbasePost`/`Deposito`/`Retiro`/`Liberacion` ⇒ `ErrSaldo`; R-9
transferencia sin entradas ⇒ `ErrEmision` y con entradas y sin salidas ⇒
`ErrSaldo`. Se añade el testset «Ratificaciones v0.1 (R-6…R-9)» con 10
comprobaciones dirigidas. Se amplía `escenarios_rechazo` con el campo
`prefijo` (secuencia de bloques que reproduce el estado `padre`), para poder
exportar los dirigidos como historias releíbles.

Comando y resultado de `Pkg.test()` (salida completa en
`resultados/test-T01-B.log`):

    env -u LD_LIBRARY_PATH JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 \
        $JULIA --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.test()'

    X-01…X-15 (rechazos)           38/38   7,8 s
    Ratificaciones v0.1 (R-6…R-9)  10/10   0,1 s
    X-16 (orden de llegada)         2/2   10,3 s
    X-17 / X-18                     2/2 cada uno
    X-19 / X-20                     2/2 cada uno
    I-1…I-7                         9/9   1 m 17 s
    Testing Transicion tests passed — PKGTEST_EXIT=0

`run.jl --seed 0x5a5a --replicas 50 --rejilla reducida` (salida completa en
`resultados/run-reducida-50.log`):

    puntos=147456  replicas/punto=50  historias=7372800
    con sufijo PoST=5022400  undos exactos=45840000  permutaciones I-3=1090416
    fallos I-1…I-7 = 0
    dif FC-1 vs FC-3 = 0 ; dif FC-2 vs FC-3 = 7680
    tiempo de pared = 597,2 s (9,95 min) ; VEREDICTO = SIN FALLOS ; RUN_EXIT=0

Las cifras de la corrida de 50 réplicas son exactamente 1/4 de las de T01
(7 372 800 = 29 491 200/4; 45 840 000 = 183 406 080/4) y con los mismos 0
fallos: las ratificaciones no alteran ninguna historia aleatoria.

## T01-B.4. Exportación, determinismo y relectura

Comandos (1 hilo, sin Python; tiempos medidos con `/usr/bin/time`):

    env -u LD_LIBRARY_PATH JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 \
        $JULIA --project=. exportar.jl --fecha 2026-09-26T02:14:31+02:00
    # casos=2055  dirigidos_con_error_inesperado=0
    # sha256=06d95324c01083c297b1d1423845ee3c78f47dc3e7bf314e56d3083a41e6d766
    # exportar: wall=3,22 s cpu=100% maxRSS≈439 MB

    env -u LD_LIBRARY_PATH JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 \
        $JULIA --project=. src/lector_vectores.jl resultados/vectores-transicion-v0.txt
    # leidos_casos=2055  discrepancias=0  VEREDICTO_LECTURA = SIN DISCREPANCIAS
    # lector: wall=2,31 s cpu=100% maxRSS≈382 MB

Ficheros: `resultados/vectores-transicion-v0.txt` (8 070 348 B, 130 869
líneas) y `resultados/vectores-transicion-v0.sha256`
(`06d95324…d766`). Determinismo (`resultados/determinismo.log`): la corrida 2,
con la misma `--fecha`, da el mismo sha256; sin fijar la fecha solo cambia la
línea del encabezado. Relectura independiente en `src/lector_vectores.jl`
(analizador y render propios, sin funciones del exportador): 0 discrepancias
sobre RES, SEL, UTXO, GAR y EST, más X-16 con orden invertido y undo exacto en
X-19/X-20.

## T01-B.5. Cierre

Comprobación de `ENTRADA-T01-B.sha256` al terminar (desde
`/home/katana/zeo/ZEROX`):

    P-ZRX/P-TRANSICION/ORDEN-T01-B.md: OK
    P-ZRX/P-TRANSICION/CONTRATO-v0.md: OK
    P-ZRX/P-TRANSICION/ORDEN-T01.md: OK
    V-ZRX/LINEO.md: OK

Nada fuera de `T01/` se modificó; sin commit ni push; sin secretos; sin Python.
Presupuesto (1 h 30 min, 1 hilo, 8 GiB) respetado con holgura: sesión
02:08–02:25 (~17 min de reloj).

---

# PROGRESO — T01-C

Bitácora de la orden T01-C (vectores negativos de transacción). Presupuesto
declarado **antes** de ejecutar: 1 h de reloj, 1 hilo, 4 GiB de RAM; prohibido
Python. Horas solo de `date -Is` (`HORAS.log`): sesión 02:50:25–03:02:18.

## T01-C.1. Comprobación de la entrada congelada (inicio)

Comando (desde `/home/katana/zeo/ZEROX`):

    LC_ALL=C sha256sum -c P-ZRX/P-TRANSICION/ENTRADA-T01-C.sha256

Salida completa:

    P-ZRX/P-TRANSICION/ORDEN-T01-C.md: OK
    P-ZRX/P-TRANSICION/CONTRATO-v0.md: OK
    P-ZRX/P-TRANSICION/ORDEN-T01-B.md: OK
    V-ZRX/LINEO.md: OK

Lectura íntegra confirmada de `ORDEN-T01-C.md`, `V-ZRX/LINEO.md`,
`CONTRATO-v0.md` (con «Ratificaciones v0.1»), `ORDEN-T01-B.md` y todo el código
y documentos de `T01/`.

## T01-C.2. Falta de definición detectada ANTES de editar (obligatorio informar)

Se registran las lecturas que admiten más de una implementación; ninguna
bloquea la orden ni obliga a detenerse. Se aplica la lectura más compatible con
§3 y §4 y se declara aquí y en `INFORME.md` §C.

### T01-C/AMBIGUEDAD-1 — «Liberación antes de `R_slots`»
§3.2 pide el caso «el error que dé el oráculo, declarado». Lectura aplicada: se
genera el caso (retiro y liberación en el mismo bloque PoST) y se **declara** el
error real del oráculo, que es `ErrSaldo` (`vencido = 0`). Se contabiliza en la
familia `ErrSaldo`; no se relabela. Regla afectada: §3.2.

### T01-C/AMBIGUEDAD-2 — Unidad de recuento de «familia»
§1 pide ≥30 casos por «familia»; §3.2 enumera subcasos. Lectura aplicada:
familia = nombre de error (`ErrSaldo`…`ErrGarantia`); se cuenta por `RES`
confirmado por el oráculo y se publica además el desglose por subcaso. Regla
afectada: §1/§3.2.

### T01-C/AMBIGUEDAD-3 — «Varios puntos de la rejilla por defecto»
§3.2 no fija cuántos. Lectura aplicada: los mismos tres puntos que T01-B
(índices 1, 4 096 y 8 192 de los 8 192 puntos por defecto), con lo que el
fichero nuevo es comparable con `vectores-transicion-v0.txt`. Regla afectada:
§3.2.

### T01-C/AMBIGUEDAD-4 — Formato del `.sha256`
§3.3 exige `<hash>  <nombre>` (`sha256sum`). Lectura aplicada: `<nombre>` es la
ruta `resultados/vectores-transicion-negativos-v0.txt`, de modo que
`sha256sum -c` funciona desde `T01/`. Regla afectada: §3.3.

### T01-C/AMBIGUEDAD-5 — «Depósito pendiente usado para producir»
§3.2 lo aparta a `ErrGarantia`. Lectura aplicada: además de productores sin
garantía activa, se construye un prefijo válido de dos bloques PoST (transferencia
a una clave sin garantía y depósito de esa salida) que deja `pend=[1@s…]`, y el
bloque negativo produce con esa clave ⇒ `ErrGarantia`. Solo aplica con
`M_dep_slots ≥ 2`; en el punto 1 (`M_dep_slots = 1`) el pendiente maduraría en el
punto del bloque y no habría caso. Regla afectada: §3.2.

No hay ninguna falta de definición que impida exportar.

## T01-C.3. Código añadido

Sin tocar la semántica de `src/Transicion.jl`/`src/seleccion.jl`/`src/nodo.jl`:

- `src/generadores_negativos.jl` (nuevo): `CasoNegativo` y `casos_negativos(P)`;
  construye los bloques de rechazo sobre cadenas base válidas
  (`construir_poW`/`extender_post`) y fija el error esperado por subcaso. Usa el
  estado **tras la promoción** y el punto del bloque negativo (altura/slot
  propios) para elegir entradas gastables y calcular activos/vencidos, porque
  `aplicar_pow!`/`aplicar_post!` promueven antes de las transacciones.
- `src/Transicion.jl`: `include("generadores_negativos.jl")` y exports.
- `exportar_negativos.jl` (nuevo): exportador determinista con el mismo formato
  de líneas que T01-B, verificación de cada caso contra el oráculo (aborta si
  hay inesperados), `sha256sum` y tablas de recuento.

## T01-C.4. Exportación, recuentos, relectura y determinismo

Comandos (1 hilo, sin Python, con `/usr/bin/time -v`):

    env -u LD_LIBRARY_PATH JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 \
        $JULIA --project=. exportar_negativos.jl --fecha 2026-09-26T02:59:21+02:00
    # casos=1915  inesperados=0
    # sha256=2e407c88118828d4ca2357fcdc21b43beb4b03f5874858b03c4860fb717e1792
    # 3,34 s de pared, 100 % CPU, máx. RSS ≈ 436 MiB

    env -u LD_LIBRARY_PATH JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 \
        $JULIA --project=. src/lector_vectores.jl \
        resultados/vectores-transicion-negativos-v0.txt
    # leidos_casos=1915  discrepancias=0  SIN DISCREPANCIAS
    # 2,08 s, máx. RSS ≈ 381 MiB

    sha256sum -c resultados/vectores-transicion-negativos-v0.sha256
    # resultados/vectores-transicion-negativos-v0.txt: La suma coincide

Recuento por error (RES confirmado por el oráculo), mínimo 30 cada uno:

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

Fichero: `resultados/vectores-transicion-negativos-v0.txt` (3 783 196 B,
61 843 líneas, 1 915 casos) y `resultados/vectores-transicion-negativos-v0.sha256`
(`<hash>  resultados/vectores-transicion-negativos-v0.txt`). Determinismo
(`resultados/determinismo-negativos.log`): dos corridas con la misma `--fecha`
dan `2e407c88…e1792`.

## T01-C.5. Tests y cierre

`Pkg.test()`: **todos los testsets pasan** (`PKGTEST_EXIT=0`,
`resultados/test-T01-C.log`). Las 1 915 historias del fichero no se añaden a la
batería (el exportador ya las confirma una a una); `test/runtests.jl` no se toca.

Comprobación de `ENTRADA-T01-C.sha256` al terminar (desde `/home/katana/zeo/ZEROX`):

    P-ZRX/P-TRANSICION/ORDEN-T01-C.md: OK
    P-ZRX/P-TRANSICION/CONTRATO-v0.md: OK
    P-ZRX/P-TRANSICION/ORDEN-T01-B.md: OK
    V-ZRX/LINEO.md: OK

Nada fuera de `T01/` se modificó; sin commit ni push; sin secretos; sin Python.
Presupuesto (1 h, 1 hilo, 4 GiB) respetado con holgura: sesión de ~12 min de reloj.

# PROGRESO — T01-D

Bitácora de la orden T01-D (nonce por clave de garantía, F-15). Presupuesto
declarado **antes** de ejecutar: 1 h 30 min de reloj, 1 hilo, 8 GiB de RAM;
prohibido Python. Horas solo de `date -Is` (`HORAS.log`).

## T01-D.1. Comprobación de la entrada congelada (inicio)

Comando (desde `/home/katana/zeo/ZEROX`):

    sha256sum -c P-ZRX/P-TRANSICION/ENTRADA-T01-D.sha256

Salida completa:

    P-ZRX/P-TRANSICION/ORDEN-T01-D.md: La suma coincide
    P-ZRX/P-FORMATO/FORMATO-v0.md: La suma coincide
    P-ZRX/P-TRANSICION/CONTRATO-v0.md: La suma coincide
    V-ZRX/LINEO.md: La suma coincide

Lectura íntegra de `ORDEN-T01-D.md`, la «Corrección v0.1» de `FORMATO-v0.md`
(F-15…F-18), `V-ZRX/LINEO.md`, `CONTRATO-v0.md` (con «Ratificaciones v0.1») y
todo el código y documentos de `T01/`.

## T01-D.2. Falta de definición detectada ANTES de editar (obligatorio informar)

Registradas y aplicadas las lecturas de `INFORME.md` §D.2:
T01-D/AMBIGUEDAD-1 (destino del caso válido `n, n+1`), 2 (desbordamiento de
`nonce_siguiente`), 3 (clave sin registro en retiro/liberación), 4 (orden del
nonce frente a la fase en liberación), 5 (alcance de «≥ 30 cada uno, fases PoW y
PoST»), 6 (posición del campo `nonce=`) y 7 (`.sha256` del base). **Ninguna
bloquea la orden**; no hay choque entre el contrato y F-15.

## T01-D.3. Código modificado

- `src/Transicion.jl`: `ErrNonce`; `Garantia.nonce_siguiente`; `Tx.nonce`;
  `nonce_de` y `comprobar_nonce!`; comprobación del nonce **primero** en
  `aplicar_deposito!`/`aplicar_retiro!`/`aplicar_liberacion!`; `clonar` y
  `representacion_canonica` actualizados.
- `src/generadores.jl`: nonces correctos en depósitos, retiros y liberaciones
  honestos (incluidos X-04/X-05/X-06/X-14 e `historia_dos_terminales`).
- `src/generadores_negativos.jl`: nonces correctos en los 1 915 casos de T01-C;
  `casos_nonce`, `casos_nonce_pow` (prefijos PoW pre-terminales) y
  `casos_nonce_validos`.
- `exportar.jl`: `nonce=` en `TX` de las tres operaciones y en `GAR`; salida
  v0.1 y `.sha256` en formato `sha256sum`.
- `exportar_negativos.jl`: ídem; añade `casos_nonce` y el recuento `ErrNonce`.
- `src/lector_vectores.jl`: lee `nonce=` y lo incluye en el render de `GAR`.
- `test/runtests.jl`: nonces en R-8 y testset «F-15 (nonce por clave)».

## T01-D.4. Exportación, recuentos, relectura y determinismo

    exportar.jl --fecha 2026-09-26T03:10:14+02:00
    # casos=2055  dirigidos_con_error_inesperado=0
    # sha256=0faec4a330b0ab96052b97c919b9e7bfa9ef494c2dd8fde25f38738658aa5527
    exportar_negativos.jl --fecha 2026-09-26T03:10:14+02:00
    # casos=3939  inesperados=0
    # sha256=9ca55abde96702f61ac0762e22f0a861d9ab0603a4090eda04ccd818eb0326ad

Recuento por error (`ErrNonce` incluido, 2 024; PoW 512, PoST 1 512) en
`INFORME.md` §D.4. Las ocho familias de T01-C conservan sus recuentos exactos.
Relectura independiente de ambos ficheros: **0 discrepancias**. Determinismo:
dos ejecuciones por fichero con la misma `--fecha` dan el mismo hash. Los
ficheros v0 (`06d95324…`, `2e407c88…`) no se tocaron.

## T01-D.5. Tests, `run.jl` y cierre

`Pkg.test()`: todos los testsets pasan (`PKGTEST_EXIT=0`), F-15 10/10.
`run.jl --seed 0x5a5a --replicas 50 --rejilla reducida`: 7 372 800 historias,
0 fallos I-1…I-7, `VEREDICTO = SIN FALLOS` (`resultados/run-reducida-50-T01-D.log`).

Presupuesto (1 h 30 min, 1 hilo, 8 GiB) respetado; sin Python; sin commit ni
push; sin secretos; nada fuera de `T01/`. Comprobación final de la entrada
congelada: ver §T01-D.6.

## T01-D.6. Comprobación de la entrada congelada (último paso)

Comando (desde `/home/katana/zeo/ZEROX`):

    sha256sum -c P-ZRX/P-TRANSICION/ENTRADA-T01-D.sha256

Salida: las cuatro líneas «La suma coincide» (ORDEN-T01-D, FORMATO-v0,
CONTRATO-v0, LINEO).

# PROGRESO — T01-E

Bitácora de la orden T01E-T04D (id de la salida de la liberación, F-18).
Presupuesto declarado **antes** de ejecutar: 1 h 30 min de reloj, 1 hilo, 8 GiB de
RAM; prohibido Python. Horas solo de `date -Is` (`HORAS.log`).

## T01-E.1. Comprobación de la entrada congelada (inicio)

Comando (desde `/home/katana/zeo/ZEROX`):

    sha256sum -c P-ZRX/P-TRANSICION/ENTRADA-T01E-T04D.sha256

Salida completa: las cinco líneas «La suma coincide» (ORDEN-T01E-T04D,
REVISION-W06a, FORMATO-v0, CONTRATO-ESTADO-DAG-v0, LINEO). Lectura íntegra de la
orden, `REVISION-W06a.md`, `FORMATO-v0.md` (F-15…F-18), `LINEO.md` y todo el
código y documentos de `T01/` y de `P-DAG/T04/`.

## T01-E.2. Falta de definición detectada ANTES de editar (obligatorio informar)

Registradas y aplicadas las lecturas de `INFORME.md` §E.2:
T01-E/AMBIGUEDAD-1 (error para id fuera de rango: `ErrDesbordamiento`),
2 (nombres v0.2 y encabezado «F-18, formato v0.1»), 3 (réplicas de `run.jl`: 50,
la escala de T01-D) y 4 (exportar `ID_LIB`/`LIMITE_ID_EXPLICITO`). **Ninguna
bloquea la orden.**

**Bloqueo de entorno (no es una ambigüedad de la especificación).** La orden pide
escribir también en `P-DAG/T04/`, pero en esta sesión `/home` está montado en solo
lectura y solo `P-TRANSICION` es `rw`; el intento de ampliar el sandbox se rechaza
sin canal de aprobación. Se informa antes de tocar T04 y se ejecuta solo la mitad
T01 (zona escribible). Detalle en §T01-E.7.

## T01-E.3. Código modificado

- `src/Transicion.jl`: `ID_LIB` y constantes de la partición de ids; `crear_utxos!`
  comprueba el rango por origen y deja de actualizar `prox_salida`;
  `aplicar_liberacion!` calcula el id con `ID_LIB`; se elimina `prox_salida` de
  `Estado`, `estado_inicial`, `clonar` y `representacion_canonica`; se exportan
  `ID_LIB` y `LIMITE_ID_EXPLICITO`.
- `exportar.jl` / `exportar_negativos.jl`: salida y `.sha256` v0.2; encabezado
  `T01-E (F-18, formato v0.1)`.
- `test/runtests.jl`: testset nuevo «T01-E (id de liberación F-18)» (17 asserts).

## T01-E.4. Exportación, diferencias, relectura y determinismo

    exportar.jl --fecha 2026-09-26T05:07:25+02:00
    # casos=2055 dirigidos_con_error_inesperado=0 sha256=da3dcc48…b080
    exportar_negativos.jl --fecha 2026-09-26T05:07:25+02:00
    # casos=3914 inesperados=0 sha256=3d2dedae…c889

Base: 1 434/2 055 casos cambian (1 dirigido y 1 433 aleatorios); ningún `RES`,
`SEL` ni `GAR` cambia; `TX Transferencia` 3 826 → 5 809. Negativos: −25
(`neg-nonce-dos-nn` 224 → 199); el resto idéntico. Relectura independiente de
ambos ficheros: **0 discrepancias**; `sha256sum -c` pasa. Determinismo: dos
corridas por fichero con la misma `--fecha` dan el mismo hash. Los ficheros v0 y
v0.1 no se tocaron.

## T01-E.5. Tests, `run.jl` y cierre

`Pkg.test()`: todos los testsets pasan (`PKGTEST_EXIT=0`), T01-E 17/17.
`run.jl --seed 0x5a5a --replicas 50 --rejilla reducida`: 7 372 800 historias,
45 840 000 undos, 0 fallos I-1…I-7, `VEREDICTO = SIN FALLOS`, 602,9 s
(`resultados/run-reducida-50-T01-E.log`).

Presupuesto respetado; sin Python; sin commit ni push; sin secretos; nada fuera de
`T01/`. Comprobación final de la entrada congelada: ver §T01-E.6.

## T01-E.6. Comprobación de la entrada congelada (último paso)

Comando (desde `/home/katana/zeo/ZEROX`):

    sha256sum -c P-ZRX/P-TRANSICION/ENTRADA-T01E-T04D.sha256

Salida: las cinco líneas «La suma coincide».

## T01-E.7. T04-D bloqueado por el entorno (no ejecutado)

- Causa: `/home` montado `ro`; solo `P-TRANSICION` es `rw`; la escritura en
  `P-DAG/T04/` devuelve `Sistema de ficheros de sólo lectura`; la ampliación de
  sandbox se rechaza sin canal de aprobación.
- No ejecutado: D-14 en `dirigidos.jl`, reexportación
  `vectores-estado-dag-v0.3.txt`/`cobertura-v0.3.txt`, `run.jl --seed 0x5a5a
  --replicas 200`, `Pkg.test()` de T04, recuento del artefacto y confirmación de
  0 en v0.3.
- Efecto: T04 ya usa el `Transicion.jl` corregido por `include`, pero sus vectores
  v0.2 y su test de relectura quedan obsoletos hasta reexportar v0.3.
- Datos de solo lectura de v0.2: 318 `DESC … ErrDobleGasto` (217 en
  `Transferencia`), cota superior del artefacto.
- Cambios propuestos para T04-D (para el director):
  1. `exportar.jl`: `SALIDA_DEF`/`COBERTURA_DEF` y encabezado a v0.3.
  2. `run.jl`: `salida` por defecto a `run-estado-dag-v0.3.log` y aserción D-14.
  3. `src/dirigidos.jl`: `caso_dos_liberaciones_hermanas` (D-14) y añadirlo a
     `casos_dirigidos`.
  4. `test/runtests.jl`: relectura del v0.3 y asserts de D-14.
  5. Reexportar v0.3 + cobertura, `run.jl --seed 0x5a5a --replicas 200`,
     `Pkg.test()`, relectura 0 discrepancias y recuento del artefacto (0 en v0.3).

D-14 (diseño): sobre `W` con un retiro (inicio `s`, vencido en `s+R_slots`), ramas
hermanas `Xa` (liberación de importe `a`, `sd` menor) y `Xc` (liberación de
importe `b ≠ a`, mismo nonce `n`), y `Xb` hijo de `Xa` con una transferencia que
gasta `ID_LIB(1, n, a)`; un bloque `B` fusión. Al aplicar: una liberación aplica y
la otra se descarta con `ErrNonce`; la transferencia aplica si su salida existe en
`Estado(past(B))` y, si no, se descarta por entrada ausente (`ErrDobleGasto`),
**nunca** porque `ID_LIB(1, n, a) == ID_LIB(1, n, b)` (son distintos).

---

# SL-3 — Oráculo de evidencia y castigo en T01

**Ejecutor:** DeepSeek `deepseek-flash` (esfuerzo `high`). **Zona escribible:** `T01/`.
**Presupuesto declarado antes de ejecutar (LINEO §7):** 2 h de reloj, 1 hilo, 8 GiB de RAM,
2 GiB de disco. Si se agota: checkpoint y estado **inconcluso**. Prohibido Python.

## SL3.0. Comprobación de la entrada congelada (inicio)

Comando (desde `/home/katana/zeo/ZEROX`):

    LC_ALL=C sha256sum -c P-ZRX/P-SLASHING/ENTRADA-SL3.sha256

Salida: 6/6 `OK` (ORDEN-SL3, CONTRATO-EVIDENCIA-v0, DECISIONES, CONTRATO-v0,
CONTRATO-ESTADO-DAG-v0, LINEO).

Lectura íntegra de `ORDEN-SL3-ORACULO.md`, `CONTRATO-EVIDENCIA-v0.md` (con la
«Ratificación v0»), `DECISIONES.md`, `V-ZRX/LINEO.md`, `CONTRATO-v0.md`,
`CONTRATO-ESTADO-DAG-v0.md`, `ENTRADA-SL3.sha256` y todo el código de `T01/` y `T04/`.

## SL3.1. Falta de definición detectada ANTES de editar (obligatorio informar)

Todas se resuelven con una lectura que no altera ninguna otra regla; se registran
**antes** de tocar código y se aplican marcadas con `# AMBIGUEDAD-SL3-n` / `# EV-n`.

- **AMBIGUEDAD-SL3-1 — momento y permanencia de la congelación frente a la
  liquidación.** EV-17/18 congelan al aplicar la primera prueba admisible; EV-19/20 y
  RAT-2 ligan la confiscación y la recompensa al bloque que **aplica** la `EvidenceTx`
  (luego la liquidación es inmediata); pero EV-24(i) bloquea una liberación mientras
  «hay un incidente admitido y no liquidado». Si la liquidación fuese atómica y borrase
  el caso, (i) sería vacuo y el caso dirigido de EV-24 no sería reproducible. Lectura
  adoptada: la congelación y la confiscación ocurren **en el bloque que aplica**; el
  `incident_id` permanece registrado (caso abierto) hasta que cierra su ventana
  (`punto ≥ slot_falta + Plazo_slots`, EV-11); mientras siga registrado, la
  **liberación** se rechaza con `ErrCasoAbierto` y el remanente congelado queda como
  **gravamen**; el **retiro** no se bloquea (EV-24: mover a `en_retirada` no escapa). No
  altera I-1 ni EV-19/EV-20 (cada nuevo incidente congela el total disponible y debita
  el remanente).
- **AMBIGUEDAD-SL3-2 — `Garantia.congelado` como cuenta o como gravamen.** El oráculo
  v0 tenía `congelado` como bucket y `suma_garantias` lo sumaba. Si la congelación
  total moviera todo a `congelado`, un `Retiro` (que EV-24 declara aceptado) no tendría
  `activo` del que tirar. Lectura adoptada: `congelado` es un **gravamen derivado**
  (`= total de la garantía sujeto a casos abiertos`), no un bucket; `suma_garantias`
  deja de sumarlo (en v0 era siempre 0, así que I-1 no cambia) y las sub-cuentas
  conservan su estado. La confiscación debita las sub-cuentas en orden determinista
  `activo → pendientes → en_retirada → créditos`.
- **AMBIGUEDAD-SL3-3 — activación de C-EVP.** R-12 rechaza `EvidenceTx` con
  `ErrFueraDeAlcanceV0` «mientras C-EVP no esté activo», pero ni el contrato ni la
  orden fijan cómo se activa. Lectura adoptada: campo booleano `Params.evp`
  (por defecto `false`), interfaz de activación; los puntos con evidencia lo ponen a
  `true`. Sin él, las reglas de EV-24 quedan además inertes para `Plazo_slots = 0`
  (la condición (ii) es trivial) y no cambia ningún vector anterior.
- **AMBIGUEDAD-SL3-4 — forma del error de `cbid` ajeno.** RAT-1 dice «`ErrForma`».
  El oráculo plano no tiene `ErrForma`; se adopta `ErrCbidAjeno`, documentado como
  `ErrForma(CbidAjeno)` en Rust.
- **AMBIGUEDAD-SL3-5 — `H_d` en el oráculo abstracto.** El contrato usa `H_d(SHA3)`.
  El oráculo no modela criptografía; como en `hash_canonico` (ya `sha256`), se usa
  SHA2-256 sobre los bytes canónicos de la identidad como marcador de posición
  determinista de `incident_id`.
- **AMBIGUEDAD-SL3-6 — momento de la poda (EV-11).** Se poda al **inicio** de cada
  bloque, antes de aplicar sus transacciones, con la condición estricta
  `punto ≥ slot_falta + Plazo_slots` (coherente con EV-13, que admite
  `slot_falta ≤ punto < slot_falta + Plazo_slots`). Así, una prueba aplicada en el
  mismo bloque que cierra la ventana ya no es admisible.
- **AMBIGUEDAD-SL3-7 — puerta RAT-3.** «La activación del castigo comprueba
  `R_slots > Plazo_slots + M_margen_slots` como puerta». Se comprueba al aplicar
  evidencia; si falla, `ErrPuertaRAT3` (no se congela ni confisca). Los puntos con
  evidencia de la rejilla cumplen la desigualdad.
- **AMBIGUEDAD-SL3-8 — `último_slot_producido(P)`.** La condición (ii) de EV-24 usa el
  mayor slot de un bloque `PoST` aplicado con `sol.public_key = P` **en el pasado** del
  punto de liberación. Se añade `Estado.ultimo_slot_producido::Dict{Int,Int}`; se
  actualiza **después** de aplicar las transacciones de cada bloque PoST (con
  `máx(slot previo, slot(B))`), de modo que la liberación dentro del propio bloque
  producido por `P` evalúa el pasado, no el bloque en curso.
- **AMBIGUEDAD-SL3-9 — redondeo de RAT-2 en cantidades mínimas.** RAT-2 afirma que el
  autodenunciante pierde «al menos `6/8·C`»; con `recompensa = techo(C·2/8)`, para
  `C` no múltiplo de 4 la pérdida neta es `C − techo(C/4) ≥ 6/8·C` solo si `C ≥ 4`
  (p. ej. `C = 1` da recompensa 1 y pérdida 0). Se implementa la letra de RAT-2 y se
  documenta; los casos dirigidos usan `C` múltiplo de 8 para la comprobación exacta
  `6/8·C`. **Resuelta por RAT-2′ (SL-3b):** la recompensa pasa a `suelo(C·2/8) = C ÷ 4`.

**Conclusión:** ninguna ambigüedad obliga a elegir entre reglas incompatibles; no
procede detenerse. Se aplican las lecturas anteriores y se documentan en `INFORME.md`.

## SL3.2. Diario de ejecución

- **18:43** inicio; `date -Is` en `HORAS.log`; entrada congelada 6/6 OK.
- *Lectura íntegra* de la orden, el contrato con RAT, `DECISIONES.md`, `LINEO.md`, los dos
  contratos de oráculo y todo el código de `T01/` y `T04/`.
- *Código T01*: `Params` gana `f_num/f_den/Plazo_slots/M_margen_slots/cbid/evp`;
  `Garantia.incidentes`; `Estado.ultimo_slot_producido`; `Tx.evidencia`; tipos
  `IdentidadEvidencia`/`CabeceraEvidencia`/`Evidencia`; `aplicar_evidencia!` (EV-05…EV-22,
  RAT-1/2), `podar_incidentes!`, `debitar_garantia!`, `techo_fraccion`,
  `techo_dos_octavos`; RAT-3 en `aplicar_liberacion!`; `src/evidencia.jl` con los generadores
  (cobertura, RAT-3 y autodenuncia); `src/lector_vectores.jl` con `ev=`/`inc=`; `exportar.jl`
  a v0.3; `run.jl` con el bloque de evidencia; testset `SL-3` en `test/runtests.jl`.
- *Tests*: `Pkg.test()` **176/176**, SL-3 **82/82**. Registro `resultados/test-T01-SL3.log`.
- *run.jl* `--seed 0x5a5a --replicas 5 --rejilla reducida`: 147 456 puntos, 737 280 historias,
  4 595 520 undos, I-1…I-7 = 0 fallos; evidencia 92 historias, 412 undos, 8 RAT-3 bloqueadas,
  0 fallos; 75,6 s. Registro `resultados/run-reducida-SL3.log`.
- *Vectores*: `exportar.jl` → **2 795 casos**, sha256
  `d3b73b06664fb4dbd4311cc163ddf937605192bf99f928e260dc67e02ad7897b`;
  `cobertura-v0.3.txt` con aplicada 260, duplicada 40, tardía 200, `cbid` 120, sin saldo 120,
  deshecha 380, con entradas 120. Relectura con `src/lector_vectores.jl`: **0 discrepancias**
  (`resultados/relectura-v0.3.log`); v0.2 intacto y releído con 0 discrepancias.
- *Nota de redondeo* (AMBIGUEDAD-SL3-9): `perdida = C − techo(C/4)`; la igualdad `6/8·C` es
  exacta cuando `C ≡ 0 (mod 8)`, y el caso dirigido controlado (depósito previo) lo verifica.
- **Cierre T01: SUPERADO.** Nada escrito fuera de `T01/`; sin commit ni push; sin Python.

# SL-3b — Correcciones del oráculo de evidencia (T01)

**Ejecutor:** DeepSeek `deepseek-flash` (esfuerzo `high`). **Fecha:** 2026-09-26.
**Fuente:** `ORDEN-SL3b.md` (motivo: `REVISION-SL3.md`) y `CONTRATO-EVIDENCIA-v0.md` con
**RAT-2′**. **Zona:** `T01/`. Sin Python; sin commit ni push.

## SL3b.0. Entrada congelada (inicio)

`LC_ALL=C sha256sum -c P-ZRX/P-SLASHING/ENTRADA-SL3b.sha256`: **4/4 OK** (ORDEN-SL3b,
REVISION-SL3, CONTRATO-EVIDENCIA-v0 con RAT-2′, `V-ZRX/LINEO.md`).

## SL3b.1. Falta de definición detectada antes de editar (obligatorio informar)

- **AMBIGUEDAD-SL3b-1 — alcance del «barrido» de evidencia.** La orden pide «al menos
  5 000 historias con evidencia (sin reducir el resto)». Lectura adoptada: el barrido
  principal se conserva **intacto** (147 456 puntos × réplicas) y el bloque de evidencia de
  `run.jl` escala al objetivo (`--ev-historias`, por defecto 5 000; 6 tipos × 12 puntos de
  evidencia). No obliga a elegir entre reglas incompatibles; no se detuvo la ejecución.
- **RAT-2′** no es ambiguo: sustituye `techo(C·2/8)` por `suelo(C·2/8) = C ÷ 4`.

## SL3b.2. Diario de ejecución

- *Código*: `techo_dos_octavos` → `suelo_dos_octavos` (`C ÷ 4`, exportada);
  `aplicar_evidencia!` acredita `suelo(C·2/8)` al productor y quema `C − suelo(C·2/8)`.
  `run.jl` gana `--ev-historias` (por defecto 5 000) con
  `n_ev_tipo = cld(ev_historias, 6 · |puntos_evidencia|)`; el barrido principal no cambia.
  `exportar.jl` a **v0.4** con cabecera SL-3b y definiciones de contadores;
  `src/lector_vectores.jl` por defecto v0.4.
- *Tests*: `Pkg.test()` **2 178/2 178** (testset `SL-3` **2 084/2 084**). Incluye la
  propiedad nueva `∀ C ∈ 0:1000: 8·(C − suelo(C/4)) ≥ 6·C` y `suelo(C/4) = C ÷ 4`
  (2 002 aserciones nuevas). Registro `resultados/test-pkg-SL3b.log`.
- *run.jl* `--seed 0x5a5a --replicas 5 --rejilla reducida`: 147 456 puntos, **737 280**
  historias (sin reducir), 4 595 520 undos, **I-1…I-7 = 0 fallos**; bloque de evidencia
  **5 060** historias (≥ 5 000), 22 768 undos, **8** RAT-3 bloqueadas, 0 fallos; 64,8 s,
  1 hilo. `VEREDICTO = SIN FALLOS`. Registro `resultados/run-reducida-SL3b.log`.
- *Vectores v0.4*: **2 795 casos**, sha256
  `4f0a175a3b4390e40248a70b62e22829c5233311d4dfdce5c2ed164786ad3b0f`; relectura
  independiente (`src/lector_vectores.jl`) **0 discrepancias** (`relectura-v0.4.log`).
  Cobertura `resultados/cobertura-v0.4.txt`: aplicada 260, `cbid` ajeno 120, con entradas
  120, deshecha 380 (undo exacto EV-27), duplicada 40, sin saldo 120, tardía 200.
- *Anteriores intactos*: `sha256sum -c` OK para v0.1, v0.2 y v0.3 (v0 conserva su
  `.sha256` de formato antiguo). **Nota necesaria:** releer v0.3 con el oráculo RAT-2′ da
  discrepancias en `quemado`/recompensa (520 de 2 795), porque v0.3 se generó con RAT-2
  (`techo`); es exactamente el cambio de redondeo que corrige la orden. El fichero v0.3
  queda byte a byte intacto y su relectura histórica bajo RAT-2
  (`relectura-v0.3.log`) sigue siendo 0 discrepancias; el intento bajo RAT-2′ queda
  registrado en `relectura-v0.3-con-RAT2p.log`.
- **Cierre T01-SL3b: SUPERADO.** Nada escrito fuera de `T01/`; sin commit ni push; sin
  Python; sin secretos.
