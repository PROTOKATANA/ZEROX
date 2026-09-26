# INFORME — T04 · Oráculo de referencia del estado en el DAG PoST

**Veredicto: SUPERADO.** El oráculo Julia (CPU, 1 hilo) reproduce el contrato
`P-ZRX/P-DAG/CONTRATO-ESTADO-DAG-v0.md` en la rejilla declarada y no encuentra ningún
contraejemplo a ED-1…ED-6 ni a IE-1…IE-6. Presupuesto consumido: 50,1 s de pared del `run.jl`
completo (tope 3 h), 1 hilo, < 200 MiB de RAM, < 100 MiB de disco.

## 1. Qué se ha construido

- `src/EstadoDAG.jl`: módulo del oráculo. Dependencia de **solo lectura** de T01 vía `include`
  (no se toca T01) y de GDR-v0.2 (copias literales `src/modelo.jl` y `src/referencia.jl`, envueltas
  en `src/GDR.jl`, con la raíz interpretada como terminal, D-P07).
- `aplicar_fusion` (§3): descarte silencioso de transacciones, `rojo_U3` inerte, recorte de la
  coinbase PoST a `mín(declarado, subsidio_post(slot(X)) + tarifas aceptadas)`, punto de aplicación
  para madureces/retiros/créditos, `merge_depth > F_slots` invalida.
- `Estado(past(B))` (ED-2), `Estado(past(B)∪{B})`, virtual `Estado(past(V))` (ED-3) con el mergeset
  completo de V, cadena seleccionada, reorg y undo exacto.
- `src/dirigidos.jl`, `src/propiedades.jl`, `run.jl`, `exportar.jl`, `src/lector_vectores.jl`.
- `resultados/vectores-estado-dag-v0.txt` (908 casos) + `.sha256`; `resultados/run-estado-dag.log`,
  `resultados/test.log`, `resultados/relectura.log`, `resultados/entorno.log`.

## 2. Revalidación de GDR-v0.2 (paso previo obligatorio)

| Vector | Bloques/DAGs | Discrepancias |
|---|---:|---:|
| `testdata/ghostdag-rank-v1/corpus-rust.txt` | 2290 bloques / 28 DAGs | **0** |
| `testdata/kaspa/dag0..dag5.json` (fixtures `9681061`) | 84 bloques | **0** |

Campos exactos: `sp`, `blue_score`, `blue_work`, `ms_ordenado`, `blues`, `reds`, `colores`, `rank`
(corpus) y `sp`/`blues`/`reds`/`blue_score` (kaspa). Los bloques de identidad y los `rojo_U3`
dinámicos quedan por tanto revalidados antes de usarse.

## 3. Casos dirigidos (resultado construido a mano)

| Caso | Historia | Resultado obtenido |
|---|---|---|
| D-1 | Doble gasto entre dos bloques fusionados | Gana el primero en C-GD-05; el segundo se descarta con `ErrDobleGasto` |
| D-2 | Coinbase declarada `3+1+5` con una tarifa descartada | Se acreditan `4` (`3` subsidio + `1` tarifa aceptada); el resto no existe |
| D-3 | Depósito fusionado que habilita al productor 3 | `Z` válido; `W` (mismo productor sin el depósito en su pasado) `ErrGarantia` |
| D-4 | Garantía solo en rama no fusionada | Bloque `B` inválido, `ErrGarantia` |
| D-5 | `rojo_U3` inerte | `X2` (billete repetido) es `U3`; no aparece en el orden de aplicación |
| D-6 | Bloque alcanzado por dos cadenas | `X` aparece exactamente una vez en `orden_aplicacion_virtual` |
| D-7 | Reorganización | Punta `A2` → `B3` al sumar peso la otra rama; estado recomputado |
| D-8 | Dos hermanos PoST en el mismo slot | Ambos válidos |

## 4. Invariantes IE-1…IE-6

| Invariante | Comprobación | Resultado |
|---|---|---|
| IE-1 | Conservación en `past(B)`, `post(B)` y virtual | 0 fallos |
| IE-2 | Cada bloque no-`rojo_U3` aplicado una sola vez | 0 fallos |
| IE-3 | Orden de llegada irrelevante (estados por id) | 673 650 órdenes, 0 fallos |
| IE-4 | Undo exacto y `post` recomputado | 0 fallos |
| IE-5 | Cadenas sin fusiones = T01 (representación canónica) | 0 fallos |
| IE-6 | GHOSTDAG y cadena no dependen de saldos de garantía | 0 fallos |

`run.jl --seed 0x5a5a --replicas 200`: **3000 historias, 25 380 bloques PoST, 15 858 válidos,
1977 descartes, 1374 `rojo_U3`**, 15 puntos (`5` rejilla × `k∈{0,1,3}`), 50,1 s, estado SUPERADO.
Muestreo declarado: IE-3 agota **todas** las permutaciones de llegada en 5 historias con ≤ 7 bloques
por punto y usa 200 aleatorias en el resto (coste acotado, LINEO §7); IE-5 se comprueba cada 10
réplicas.

## 5. Ambigüedades

Se registraron **AMBIGUEDAD-1…10** en `PROGRESO.md` **antes** de escribir código (resumen en
`METODO.md` §3). Todas se resolvieron con la lectura restrictiva o forzada por otra regla
(p. ej. `sp(B)` se aplica en su propio slot para no romper IE-5); ninguna obligó a parar. La más
delicada, la base del subsidio (AMBIGUEDAD-1), se resuelve con `slot(X)` para el importe y el punto
de aplicación para madurez/retiros/créditos.

## 6. Vectores y relectura independiente

- `resultados/vectores-estado-dag-v0.txt`: **908 casos** (8 dirigidos + 900 aleatorios), 3,1 MB,
  formato de T01-B ampliado con `padres=[…]` y `DESC bloque= tx= motivo=`.
- `sha256`: `29096f747ae3eefc0dfbf85d5e640eeb750c6a5481771aeb517dc14ee274af84`.
- `src/lector_vectores.jl` (analizador y render propios, sin reutilizar `exportar.jl`):
  **908 casos, 0 discrepancias**, con `RES`, `DESC`, `SEL`, `UTXO`, `GAR`, `EST`, I-1 y undo.

## 7. Reproducibilidad

```
cd /home/katana/zeo/ZEROX/P-ZRX/P-DAG/T04
export PATH=/home/katana/torio/.juliaup/bin:$PATH
export JULIA_DEPOT_PATH=$PWD/.julia-depot JULIA_PKG_OFFLINE=true
env -u LD_LIBRARY_PATH julia --project=. run.jl --seed 0x5a5a --replicas 200
env -u LD_LIBRARY_PATH julia --project=. exportar.jl --dirigidos 1 --aleatorios 900
env -u LD_LIBRARY_PATH julia --project=. src/lector_vectores.jl resultados/vectores-estado-dag-v0.txt
env -u LD_LIBRARY_PATH julia --project=. test/runtests.jl
```

Julia 1.13.0; CPU AMD Ryzen 9 9950X3D; 1 hilo (`Threads.nthreads(:default) = 1`). Sin Python, sin
commit/push, sin secretos. Git HEAD `8dbbd64a66fa09bdd8286989d0bf1f380c70d5f3`. Huellas de las
copias GDR: `src/modelo.jl` `7769415b…3a71b3`, `src/referencia.jl` `51e39615…7c7080c`.

Coste medido (`bench/benchmarks.jl` → `resultados/BENCH.txt`, 1 hilo, tras calentar JIT):
`generar_dag_aleatorio(npost=8)` 0,022 ms; `estado_virtual` 0,013 ms; `aplicar_historia` 0,013 ms;
`verificar_ie1_ie2_ie4` 0,107 ms; `verificar_ie3` (20 órdenes) 1,271 ms; `revalidar_corpus`
(28 DAGs) 48,3 ms; 27 KiB asignados por `estado_virtual`. No hay kernel optimizado: es un oráculo de
referencia y la batería completa cabe en 50 s.

## 8. Lo que este oráculo NO demuestra

- **Criptografía:** no valida firmas, hashes, compromisos ni PoW real; `pow_ok`, hashes e identidades
  entran ya resueltos.
- **PoT/PoAS/sello:** `slot`, `sr`, `sd` e `ident` son datos de entrada; no se modelan retos,
  flujos, rangos validados ni puertas conjuntas.
- **Red y latencia:** no hay propagación, eclipse, particiones ni ventanas de entrega; el orden de
  llegada solo se usa para admission.
- **Parámetros:** la rejilla son valores de prueba; `q`, subsidios, `F_slots`, madureces y la
  semilla del corte siguen siendo simbólicos.
- **Seguridad económica:** no se demuestra nada sobre stake, farmeo en rama privada ni la forma de
  `requisito`.
- **k=0 con `M_rec_slots = 0`:** la coinbase se materializa tras las demás transacciones
  (AMBIGUEDAD-7); la rejilla usa `M_rec_slots ≥ 1`, de modo que el orden es irrelevante. No se
  reclama equivalencia con un orden estrictamente intra-bloque si la madurez del crédito fuese 0.
- **`SEC-A`/PoT/`CUT-H`/`FC-1`/`FC-2`:** fuera del alcance de T04 (solo interfaces por defecto
  `SEC0`, `CUT-HWPhi`, `FC3`).

## Resumen final

1. Oráculo Julia de referencia del estado DAG PoST implementado en `T04/`, sin Python.
2. Dependencias de solo lectura: T01 (`include`) y GDR-v0.2 (`modelo.jl`+`referencia.jl` copiados).
3. GDR-v0.2 revalidado exacto: 28 DAGs / 2290 bloques del corpus y 84 bloques kaspa, 0 discrepancias.
4. `aplicar_fusion` implementa §3: descarte silencioso, `rojo_U3` inerte y recorte de coinbase.
5. ED-1 (PoW de T01), ED-2 (`Estado(past(B))`), ED-3 (virtual con reorg y undo) implementados.
6. Casos dirigidos D-1…D-8 coinciden con el resultado construido a mano.
7. IE-1…IE-6 sin fallos en 3000 historias aleatorias (25380 bloques PoST, 1977 descartes, 1374 U3).
8. IE-3: 673650 órdenes de llegada comprobados (todas las permutaciones en 5 historias ≤7/punto).
9. IE-5: cadenas sin fusiones idénticas a T01 en representación canónica.
10. 908 vectores exportados con formato T01-B ampliado (`padres=[…]`, `DESC`).
11. `sha256` de vectores: `29096f747ae3eefc0dfbf85d5e640eeb750c6a5481771aeb517dc14ee274af84`.
12. Relectura independiente: 908 casos, 0 discrepancias.
13. Diez ambigüedades registradas antes de editar; lecturas restrictivas sin contradicción.
14. Presupuesto: 50,1 s de batería completa, 1 hilo, ≪ memoria y disco declarados.
15. Nada escrito fuera de `T04/`; sin commit, sin push, sin secretos, sin `Ok` ficticio.
16. Límites: sin criptografía, PoT/PoAS, red, latencia ni parámetros reales.
17. La pregunta falsable de la orden no se refuta: ED-1…ED-6 conservan el valor, aplican una vez,
    no dependen del orden, se deshacen y coinciden con T01 con `k=0` sin fusiones.
18. Veredicto: **SUPERADO**.

---

# T04-B — Nonce por clave (F-15) en el estado DAG y reexportación

**Veredicto: SUPERADO.** Sobre `ORDEN-T04-B` y la «Corrección v0.1» de `FORMATO-v0.md` (F-15), el
oráculo conserva ED-1…ED-6 e IE-1…IE-6, descarta la operación de garantía repetida con `ErrNonce`
en modo fusión, y los vectores reexportados se releen sin discrepancias. Presupuesto consumido:
46,7 s de `run.jl` (tope 1 h 30 min), 1 hilo, 8 GiB declarados.

## B.1. Qué cambia y qué no

- **Semántica sin cambios.** F-15 no obliga a tocar `aplicar_bloque_fusion!`: la tabla §3 del
  contrato ya ordena **descartar** toda transacción que no valida, y en T01-D `comprobar_nonce!` va
  **primero** en depósito, retiro y liberación. Una operación con `nonce ≠ nonce_siguiente[P]`
  produce `ErrNonce`, que el modo fusión descarta dejando el estado intacto (no consume entradas).
  No se modificó ningún fichero de T01 ni la lógica de T04 (AMBIGUEDAD-B4).
- **Casos dirigidos nuevos** (`src/dirigidos.jl`), construidos a mano:
  - **D-9** — el mismo retiro (mismo `txid`, nonce `n`) en dos bloques hermanos fusionados: se aplica
    la primera en `C-GD-05`, la segunda se descarta con `ErrNonce`; ambos bloques válidos.
  - **D-10** — dos depósitos de la misma clave con nonces `n` y `n+1` en hermanos, en orden inverso a
    `C-GD-05`: el de `n+1` (que va primero) se descarta; el de `n` se aplica. El UTXO compartido no
    se quema con el descarte (la comprobación de nonce precede al consumo).
  - **D-11** — repetición tras reorganización: el mismo retiro firmado en dos ramas hermanas; al
    reorganizar hacia la rama que lo contiene, el efecto aparece **una sola vez** y
    `nonce_siguiente` avanza una sola vez; al reorganizar de vuelta, sigue una sola vez.
- **Vectores v0.1.** `resultados/vectores-estado-dag-v0.1.txt` con el formato de T04 más `nonce=` al
  final de las líneas `TX` de depósito, retiro y liberación y `nonce=<nonce_siguiente>` en `GAR`.
  Se conservan intactos `vectores-estado-dag-v0.txt` y su `.sha256`.

## B.2. Resultados

| Comprobación | Resultado |
|---|---|
| Entrada congelada `ENTRADA-T04-B.sha256` | 4/4 `OK` |
| Casos dirigidos D-1…D-11 | 11/11 sin fallos |
| D-9 repetición fusionada | 1 `ErrNonce` (segundo en `C-GD-05`), 1 retiro aplicado |
| D-10 nonces `n`/`n+1` invertidos | 1 `ErrNonce` (el de `n+1`), depósito de `n` aplicado, UTXO consumido |
| D-11 reorg con replay | 1 retiro y `nonce_siguiente = n+1` en ambas selecciones |
| Vectores v0.1 | **911 casos** (11 dirigidos + 900 aleatorios), 737 descartes `ErrNonce` |
| `sha256` v0.1 | `e8f7a6dcce5bcb2cfdb50dd49f59205d9a045dc492be71eca93a788ccf74b51f` |
| Relectura independiente (`src/lector_vectores.jl`) | 911 casos, **0 discrepancias** |
| `run.jl --seed 0x5a5a --replicas 200` | 3000 historias, 25380 bloques, 16020 válidos, 3721 descartes, 1393 `rojo_U3`, 673650 órdenes IE-3, **0 fallos**, 46,7 s |
| `Pkg.test()` | **377/377 OK**, 8,3 s (incluye relectura v0.1) |

Pregunta falsable de la orden: con F-15, IE-1…IE-6 siguen sin fallos, la operación repetida en dos
bloques fusionados se aplica una sola vez (la segunda se descarta con `ErrNonce`) y los vectores
reexportados se releen sin discrepancias. **No se refuta.**

## B.3. Falta de definición (registrada antes de editar, `PROGRESO.md` §B.1)

AMBIGUEDAD-B1 (posición de `nonce=` en `TX`: al final, como T01-D), B2 (`GAR`: `nonce_siguiente` al
final), B3 (911 casos: 900 aleatorios como v0 + 11 dirigidos), B4 (no se cambia el modo fusión: el
descarte genérico ya cumple F-15), B5 (repetición tras reorg: mismo retiro en dos ramas, reorg y
vuelta). Ninguna obligó a elegir entre reglas incompatibles.

## B.4. Reproducibilidad

```
cd /home/katana/zeo/ZEROX/P-ZRX/P-DAG/T04
export PATH=/home/katana/torio/.juliaup/bin:$PATH
export JULIA_DEPOT_PATH=$PWD/.julia-depot JULIA_PKG_OFFLINE=true
env -u LD_LIBRARY_PATH julia --project=. run.jl --seed 0x5a5a --replicas 200
env -u LD_LIBRARY_PATH julia --project=. exportar.jl --dirigidos 1 --aleatorios 900
env -u LD_LIBRARY_PATH julia --project=. src/lector_vectores.jl resultados/vectores-estado-dag-v0.1.txt
env -u LD_LIBRARY_PATH julia --project=. -e 'using Pkg; Pkg.test()'
```

Julia 1.13.0; 1 hilo; sin Python; sin commit ni push; sin secretos; nada escrito fuera de `T04/`.

---

# T04-C — Generador del oráculo DAG con nonce correcto, retiros y liberaciones; vectores v0.2

**Veredicto: SUPERADO.** Sobre `ORDEN-T04-C` y `REVISION-T04-B`, el generador aleatorio construye
depósitos, retiros y liberaciones con el nonce del estado contra el que los construye (con un 10 %
de nonce erróneo deliberado), IE-1…IE-6 siguen sin fallos en 3000 historias y los vectores v0.2
superan todos los mínimos de cobertura de §3. Presupuesto consumido: 58,8 s de `run.jl` y 9,0 s de
`Pkg.test()` (tope 1 h 30 min), 1 hilo, 8 GiB declarados.

## C.1. Qué cambia y qué no

- **Semántica intacta.** No se tocó `P-ZRX/P-TRANSICION/T01/` ni la lógica de `src/EstadoDAG.jl`.
  Solo cambiaron `src/generadores.jl`, `src/dirigidos.jl`, `exportar.jl`, `run.jl`,
  `src/lector_vectores.jl` y `test/`.
- **Generador** (`generar_dag_aleatorio`, `src/generadores.jl`). Las transacciones se siguen
  construyendo contra `S = A.post[pv]`, pero el tipo se elige **entre los factibles en `S` y en el
  `slot` del bloque nuevo** con pesos (ajustados) 0,12/0,18/0,22/0,48:
  - transferencia: hay salida gastable (`valor ≥ 2`); salida con `valor − 1` (como antes);
  - depósito: hay salida gastable; importe = valor de la salida, a su dueño;
  - retiro: `activo > 0` y `en_retirada` vacío; importe uniforme en `1:activo`;
  - liberación: `vencido > 0` calculado en el `slot` del bloque nuevo con la regla de
    `aplicar_liberacion!`; importe uniforme en `1:vencido`;
  - `nonce = nonce_de(S, clave)`, con probabilidad 0,10 un nonce erróneo (`n+1`, o `n−1` si
    `n > 0`, al 50 %).
  El bug de `nonce = 0` de T04-B queda eliminado; el prefijo PoW ya deposita para las claves 1 y 2.
  Los pesos de partida (0,35/0,30/0,20/0,15) daban 99 liberaciones aplicadas (una por debajo del
  mínimo); se ajustaron y `npost` pasó a 15…16 (`npost_t04c(r) = 15 + r % 2`). El generador sigue
  eligiendo solo entre los tipos factibles: el sesgo no inventa factibilidad.
- **Casos dirigidos nuevos** D-12 y D-13 (abajo).
- **Vectores v0.2.** `resultados/vectores-estado-dag-v0.2.txt` con el formato v0.1 (cabecera
  `vectores-estado-dag-v0.2`), `.sha256` en formato `sha256sum` con ruta relativa a `T04/`. Se
  conservan **intactos** `vectores-estado-dag-v0.txt` y `vectores-estado-dag-v0.1.txt` (hashes
  verificados).
- **`run.jl`** escribe `resultados/run-estado-dag-v0.2.log` sin sobrescribir los logs v0 y v0.1.

## C.2. Tabla de cobertura (`resultados/cobertura-v0.2.txt`, generada por código Julia)

Lectura de las cifras (AMBIGUEDAD-C1): `construidas` = operaciones que el generador produjo en
cualquier bloque PoST; `aplicadas`/`descartadas` se miden en `Estado` de la punta seleccionada final
(`aplicar_historia`); `evaluadas = aplicadas + descartadas`; la diferencia son operaciones en ramas
no seleccionadas. El tope del 25 % de `ErrNonce` usa `garantia_construidas` (lectura literal de
§3).

```
SECCION vectores-v0.2 (casos aleatorios)
casos = 900
TIPO Transferencia construidas=1112 aplicadas=351 descartadas=217 evaluadas=568 en_ramas_no_seleccionadas=544 ErrNonce=0 ErrDobleGasto=217 ErrSaldo=0 ErrRetiroPendiente=0 ErrAutorizacion=0 ErrInmaduro=0 ErrOperacionFase=0 ErrEmision=0 otros=0
TIPO Deposito construidas=1626 aplicadas=349 descartadas=394 evaluadas=743 en_ramas_no_seleccionadas=883 ErrNonce=295 ErrDobleGasto=99 ErrSaldo=0 ErrRetiroPendiente=0 ErrAutorizacion=0 ErrInmaduro=0 ErrOperacionFase=0 ErrEmision=0 otros=0
TIPO Retiro construidas=2579 aplicadas=808 descartadas=510 evaluadas=1318 en_ramas_no_seleccionadas=1261 ErrNonce=474 ErrDobleGasto=0 ErrSaldo=11 ErrRetiroPendiente=25 ErrAutorizacion=0 ErrInmaduro=0 ErrOperacionFase=0 ErrEmision=0 otros=0
TIPO Liberacion construidas=458 aplicadas=115 descartadas=104 evaluadas=219 en_ramas_no_seleccionadas=239 ErrNonce=84 ErrDobleGasto=0 ErrSaldo=20 ErrRetiroPendiente=0 ErrAutorizacion=0 ErrInmaduro=0 ErrOperacionFase=0 ErrEmision=0 otros=0
garantia_construidas = 4663
garantia_evaluadas = 2280
garantia_errnonce = 853
garantia_errnonce_pct_construidas = 18.29
garantia_errnonce_pct_evaluadas = 37.41
err_doble_gasto_total = 316
reorganizaciones_que_deshacen_garantia = 312
```

El apartado `run.jl` de la misma tabla (3000 historias, `seed 0x5a5a`, `replicas 200`) da:
transferencias 1151 aplicadas, depósitos 1290, retiros 2865, liberaciones 501, `ErrNonce` 3255
(20,52 % de 15 860 garantías construidas), `ErrDobleGasto` 1110 y 1105 reorganizaciones que
deshacen garantía. El log de `run.jl` reproduce exactamente esas cifras.

## C.3. Mínimos exigidos en los vectores v0.2 (§3)

| Medida | Mínimo | Vectores v0.2 | ¿Cumple? |
|---|---:|---:|---|
| Depósitos PoST aplicados | ≥ 150 | **349** | Sí |
| Retiros aplicados | ≥ 100 | **808** | Sí |
| Liberaciones aplicadas | ≥ 100 | **115** | Sí |
| `ErrNonce` | ≥ 30 y ≤ 25 % de garantía construida | **853** (18,29 %) | Sí |
| `ErrDobleGasto` | ≥ 200 | **316** | Sí |
| Reorganizaciones que deshacen una operación de garantía | ≥ 20 | **312** | Sí |

`run.jl` cumple también los seis mínimos (1290 / 2865 / 501 / 3255 = 20,52 % / 1110 / 1105).

## C.4. Casos dirigidos nuevos

- **D-12** (`caso_retiro_liberacion_reorg`). Rama A: retiro (slot 2) → liberación (slot 3) →
  transferencia que gasta la salida de la liberación (slot 4). Rama B con los mismos slots y `sd`
  menor: al pasar A a bloque de lado (aplicada en `slot(V)`), la liberación deja de estar vencida,
  la salida de la liberación desaparece, el retiro queda en `en_retirada` (estado previo) y la
  transferencia no existe; al volver a A, reaparecen. Medido: `libA=1`; con A seleccionada
  `out=1, ret=0, nonce=n0+2`; con B seleccionada `lib=0, out=0, ret=1, nonce=n0+1`; de vuelta a A
  `out=1, ret=0, nonce=n0+2`. Es una reorganización que **deshace** la liberación (operación de
  garantía) y con ella la transferencia que dependía de su salida.
- **D-13** (`caso_liberacion_punto_aplicacion`). Retiro en W (slot 2, `inicio=2`); liberación en X
  (slot 2, `2 + R_slots > 2` ⇒ inmadura) y fusión de X por Y (slot 3, `3 ≥ inicio + R_slots`).
  RD-4 fija el punto de aplicación: en `Estado(past(X))` (vista de X) la liberación se descarta con
  `ErrSaldo` (`libX=0`, `descX=(2, ErrSaldo)`, `nonce=n0+1`); en `Estado(past(Y))` X se aplica en
  `slot(Y)=3` y la liberación se aplica (`libY=1`, `creado_en_slot=3`, `nonce=n0+2`). **No hay dos
  lecturas**: RD-4 resuelve el punto de aplicación y las dos vistas son la semántica buscada.

## C.5. Vectores, relectura y batería

| Comprobación | Resultado |
|---|---|
| Entrada congelada `ENTRADA-T04-C.sha256` | 5/5 `OK` |
| Casos dirigidos | 13/13 sin fallos (D-1…D-13) |
| Vectores v0.2 | **913 casos** (13 dirigidos + 900 aleatorios), 4,87 MB |
| `sha256` v0.2 | `ee783b524c7fcac929fdd3859803205e046c3bab678efed69c5e603d2a94dd73` |
| Relectura independiente (`src/lector_vectores.jl`) | 913 casos, **0 discrepancias** |
| `run.jl --seed 0x5a5a --replicas 200` | 3000 historias, 46 500 bloques, 25 192 válidos, 4 536 descartes, 2 078 `rojo_U3`, 600 000 órdenes IE-3, **0 fallos**, 58,8 s |
| `Pkg.test()` | **372/372 OK**, 9,0 s |
| v0 y v0.1 | intactos (hashes verificados) |

Pregunta falsable de la orden: con el generador corregido (nonce del estado, 10 % de error),
IE-1…IE-6 siguen sin fallos y los vectores v0.2 cumplen los mínimos de §3. **No se refuta.**

## C.6. Falta de definición (registrada antes de editar, `PROGRESO.md` §C.1)

AMBIGUEDAD-C1 (alcance de «construidas»: se publican `construidas` y `evaluadas`, y el tope del
25 % usa las construidas), C2 (clave uniforme entre las factibles para retiro/liberación), C3 (una
operación por bloque), C4 (definición operativa de «reorganización que deshace garantía»), C5
(D-13: RD-4 fija una única lectura, no se para), C6 (`exportar.jl` escribe el fichero de cobertura
completo), C7 (`npost` 15…16 tras comprobar que los pesos de partida no bastaban). Ninguna obligó a
elegir entre reglas incompatibles.

## C.7. Reproducibilidad

```
cd /home/katana/zeo/ZEROX/P-ZRX/P-DAG/T04
export PATH=/home/katana/torio/.juliaup/bin:$PATH
export JULIA_DEPOT_PATH=$PWD/.julia-depot JULIA_PKG_OFFLINE=true
env -u LD_LIBRARY_PATH julia --project=. run.jl --seed 0x5a5a --replicas 200
env -u LD_LIBRARY_PATH julia --project=. exportar.jl --dirigidos 1 --aleatorios 900
env -u LD_LIBRARY_PATH julia --project=. src/lector_vectores.jl resultados/vectores-estado-dag-v0.2.txt
env -u LD_LIBRARY_PATH julia --project=. -e 'using Pkg; Pkg.test()'
```

Julia 1.13.0; 1 hilo; sin Python; sin commit ni push; sin secretos; nada escrito fuera de `T04/`.

---

# T04-D — Id de la salida de la liberación como en F-18 (T01-E); vectores v0.3 y caso D-14

**Veredicto: SUPERADO.** Sobre `ORDEN-T01E-T04D` (parte T04; la parte T01-E ya está revisada en
`REVISION-T01-E.md`), T04 usa el id inyectivo de la salida de la liberación, reexporta
`vectores-estado-dag-v0.3.txt` con los mismos mínimos de T04-C, lo relee con 0 discrepancias y
confirma que el artefacto de colisión de ids pasa de 16 a 0. El caso dirigido D-14 documenta la
fusión de dos liberaciones hermanas. Presupuesto consumido: 58,0 s de `run.jl` y 9,1 s de
`Pkg.test()` (tope 1 h 30 min), 1 hilo, 8 GiB declarados.

## D.1. Qué cambia y qué no

- **Semántica intacta.** No se tocó `P-ZRX/P-TRANSICION/T01/` ni la lógica de `src/EstadoDAG.jl`; el
  generador tampoco cambia (la decisión 1 de la orden ya se aplicó en T01-E). T04 obtiene el id de
  la liberación por `include` de `Transicion.jl` (F-18).
- **`src/dirigidos.jl`** — caso dirigido nuevo D-14 (abajo).
- **`exportar.jl`** — `SALIDA_DEF`/`COBERTURA_DEF` a v0.3 y cabeceras `vectores-estado-dag-v0.3` /
  `cobertura T04-D v0.3`; el resto del código de exportación no cambia.
- **`src/lector_vectores.jl`** — `RUTA_DEF` a v0.3 (el analizador independiente no cambia).
- **`run.jl`** — salida por defecto a `resultados/run-estado-dag-v0.3.log` y aserción semántica de
  D-14.
- **`test/runtests.jl`** — relectura de v0.3 y 14 asserts de D-14.
- **`analisis-artefacto/`** — instrumento de recuento del artefacto (copias de solo lectura de T01
  viejo/actual con `COLISION_LIB_TX`); no forma parte del oráculo ni lo toca.

## D.2. Caso dirigido D-14 (`caso_dos_liberaciones_hermanas`)

Sobre `W` (retiro de 3 de la clave 1 en el slot 2), dos liberaciones **hermanas** de la misma clave
con el **mismo nonce** `n1 = 2` e importes distintos `a = 1`, `b = 2`: `Xa` (sd 0) y `Xc` (sd 1).
`Xb` (hijo de `Xa`) gasta `ID_LIB(1, n1, 1)` y `Xd` (hijo de `Xc`) gasta `ID_LIB(1, n1, 2)`. Un
bloque `B` (slot 4) fusiona `[Xb, Xd]`.

Medido en `Estado(past(B))`:

- una liberación aplica y la otra se descarta con `ErrNonce` (`(Xc, 2, ErrNonce)`);
- `Xb` aplica (su salida 9701 existe) porque `ID_LIB(1, n1, 1)` está en el estado;
- `Xd` se descarta con `ErrDobleGasto` (`(Xd, 2, ErrDobleGasto)`) porque `ID_LIB(1, n1, 2)` no
  existe (su liberación cayó por nonce), **no** por colisión de ids;
- `ID_LIB(1, n1, 1) = 4611687117941112833 ≠ ID_LIB(1, n1, 2) = 4611687117941112834`;
- `nonce_siguiente = 3`, `B` válido y sin fallos IE-1/IE-2/IE-4.

## D.3. Artefacto de ids: 16 descartes en v0.2, 0 en v0.3

La causa de la reserva de W06a (un id de liberación igual a un id de transferencia) se mide con un
oráculo instrumentado que cuenta, en `crear_utxos!`, las colisiones de una salida de transferencia
con una entrada ya existente de origen `OrigenLiberacion` (log
`resultados/artefacto-v0.2-v0.3.log`):

| Vectores | Casos | Colisiones (artefacto) | `ErrDobleGasto` en transferencia (total) |
|---|---:|---:|---:|
| v0.2 con T01 viejo (`prox_salida`) | 913 | **16** | 219 |
| v0.3 con T01 actual (F-18) | 914 | **0** | 207 |

Los 16 descartes de v0.2 son el artefacto (cota superior publicada en T01-E.7: 217); los 207 de v0.3
son dobles gastos genuinos (entrada ausente), imposibles de confundir con una colisión porque los
ids explícitos son `< 2⁶²` y los de liberación `≥ 2⁶²`. La copia vieja del oráculo reproduce el
`DESC` de v0.2 con 0 discrepancias y la actual el de v0.3 con 0 discrepancias, lo que valida el
recuento.

## D.4. Cobertura v0.3 y mínimos de T04-C (§3)

`resultados/cobertura-v0.3.txt` (generada por `exportar.jl`); apartado vectores (900 casos):

| Medida | Mínimo | Vectores v0.3 | ¿Cumple? |
|---|---:|---:|---|
| Depósitos PoST aplicados | ≥ 150 | **347** | Sí |
| Retiros aplicados | ≥ 100 | **808** | Sí |
| Liberaciones aplicadas | ≥ 100 | **115** | Sí |
| `ErrNonce` | ≥ 30 y ≤ 25 % de garantía construida | **853** (18,29 %) | Sí |
| `ErrDobleGasto` | ≥ 200 | **305** | Sí |
| Reorganizaciones que deshacen garantía | ≥ 20 | **312** | Sí |

El apartado `run.jl` (3000 historias, `seed 0x5a5a`, `replicas 200`) da: transferencias 1192
aplicadas, depósitos 1288, retiros 2865, liberaciones 501, `ErrNonce` 3258 (20,54 % de 15 860
garantías construidas), `ErrDobleGasto` total 1074 y 1108 reorganizaciones que deshacen garantía;
también cumple los seis mínimos.

## D.5. Vectores, relectura y batería

| Comprobación | Resultado |
|---|---|
| Entrada congelada `ENTRADA-T01E-T04D.sha256` | 5/5 `OK` |
| Casos dirigidos | 14/14 sin fallos (D-1…D-14) |
| Vectores v0.3 | **914 casos** (14 dirigidos + 900 aleatorios), 4,87 MB |
| `sha256` v0.3 | `016ad975cddea854349ef57241acbeb2f6b84f45d1035c765f245d54c9c748e1` |
| Relectura independiente (`src/lector_vectores.jl`) | 914 casos, **0 discrepancias** |
| `run.jl --seed 0x5a5a --replicas 200` | 3000 historias, 46 500 bloques, 25 192 válidos, 4 497 descartes, 2 078 `rojo_U3`, 600 000 órdenes IE-3, **0 fallos**, 58,0 s |
| `Pkg.test()` | **386/386 OK**, 9,1 s |
| v0, v0.1 y v0.2 | intactos (hashes verificados) |

Pregunta falsable de la orden: con el id de la salida de la liberación inyectivo (F-18), T04 sigue
cumpliendo sus propiedades, los vectores reexportados se releen sin discrepancias y ninguna
transacción se descarta ya por coincidencia de ids entre una liberación y otra salida. **No se
refuta** (0 colisiones en v0.3; IE-1…IE-6 sin fallos en 3000 historias).

## D.6. Falta de definición (registrada antes de editar, `PROGRESO.md` §D.1)

AMBIGUEDAD-D1 (D-14: el enunciado admite una o dos transferencias; se construyen dos, una por
rama), D2 (método de recuento del artefacto: oráculo instrumentado validado contra el `DESC` de
v0.2), D3 (no se exige que v0.3 sea idéntico a v0.2 salvo los ids; el orden de iteración del `Dict`
del UTXO puede variar unas pocas historias). Ninguna obligó a elegir entre reglas incompatibles.

## D.7. Reproducibilidad

```
cd /home/katana/zeo/ZEROX/P-ZRX/P-DAG/T04
export PATH=/home/katana/torio/.juliaup/bin:$PATH
export JULIA_DEPOT_PATH=$PWD/.julia-depot JULIA_PKG_OFFLINE=true
env -u LD_LIBRARY_PATH julia --project=. run.jl --seed 0x5a5a --replicas 200
env -u LD_LIBRARY_PATH julia --project=. exportar.jl --dirigidos 1 --aleatorios 900
env -u LD_LIBRARY_PATH julia --project=. src/lector_vectores.jl resultados/vectores-estado-dag-v0.3.txt
env -u LD_LIBRARY_PATH julia --project=. analisis-artefacto/contar_artefacto.jl
env -u LD_LIBRARY_PATH julia --project=. -e 'using Pkg; Pkg.test()'
```

Julia 1.13.0; 1 hilo; sin Python; sin commit ni push; sin secretos; nada escrito fuera de `T04/`.

---

# T04-SL3 — Evidencia y castigo en el DAG (EV-12/EV-27/EV-28)

**Ejecutor:** DeepSeek `deepseek-flash` (esfuerzo `high`). **Fecha:** 2026-09-26.
**Fuente:** `ORDEN-SL3-ORACULO.md` y `CONTRATO-EVIDENCIA-v0.md` con su «Ratificación v0».
**Zona:** `T04/`. Sin Python; sin commit ni push.

## SL3.1. Veredicto

**SUPERADO.** La `EvidenceTx` de T01 se aplica en **modo fusión** (ED-6/C-ORD-04): una
transacción de evidencia que no valida **se descarta** sin invalidar su bloque; la segunda
evidencia del mismo incidente queda inerte (`ErrEvidenciaDuplicada`, EV-12); el registro, el
gravamen y la confiscación viven en el `Estado` y el undo es exacto (EV-27); el incidente es
propio de la historia seleccionada, así que en el pasado de una rama hermana no está y allí una
evidencia del mismo incidente vuelve a ser «primera» (EV-28). La ventana de admisión y la
madurez del crédito de la recompensa usan el **punto de aplicación** de RD-4.

- `Pkg.test()`: **421/421**.
- `run.jl --seed 0x5a5a --replicas 200`: **ESTADO = SUPERADO**; 3 000 historias base (46 500
  bloques, 600 000 órdenes IE-3) y 1 600 historias con C-EVP (13 181 bloques válidos, 3 181
  descartes, 60 duplicadas, 466 tardías, 216 `cbid` ajeno), **0 fallos** de IE-1…IE-6. 70,8 s.
- `vectores-estado-dag-v0.4.txt`: **1 878 casos** (14 dirigidos + 900 aleatorios + 8×120
  evidencia), sha256 `37c04f1250775f25ea4a2cab355f9201c7454b4ba06fa6d892d3b83fe924ebff`;
  relectura independiente **0 discrepancias**. v0…v0.3 intactos; v0.3 se relee con 0
  discrepancias.

## SL3.2. Faltas de definición detectadas antes de editar

Además de las nueve de T01 (`PROGRESO.md` §SL3.1), cuatro propias
(`PROGRESO.md` §SL3.1-D1…D4): deduplicación como descarte y no como bloque inválido (D1),
efecto según el punto de aplicación de RD-4 (D2), evidencias hermanas (D3) y `cbid` de la red
local (D4). Ninguna obliga a elegir entre reglas incompatibles.

## SL3.3. Casos dirigidos nuevos

- **D-15** evidencia aplicada en fusión: congela, confisca (RAT-2), registra el incidente, I-1.
- **D-16** dos evidencias del mismo incidente en ramas hermanas: la primera en orden C-GD-05
  aplica y la segunda se descarta (`ErrEvidenciaDuplicada`), sin invalidar los bloques.
- **D-17** EV-27/EV-28: `past(Xc)` sin el incidente, `post(Ye)` con él aplicado como primera,
  undo exacto del bloque que aplicó.
- **D-18** descartes por `cbid` ajeno y por tardía, y evidencia contra clave sin saldo
  (aplicada con pérdida cero), todo en un mergeset.

## SL3.4. Cobertura (V4)

`resultados/cobertura-v0.4.txt`, sección «evidencia SL-3»: aplicada **307** (≥100),
duplicada **30** (≥30), tardía **297** (≥30), `cbid` ajeno **137** (≥30) y deshecha
**771** (≥30). Los mínimos de T04-C siguen cumpliéndose en v0.4: depósitos aplicados 347,
retiros 808, liberaciones 115, `ErrNonce` 853 = 18,29 % (≤25 %), `ErrDobleGasto` 305 y
reorganizaciones que deshacen garantía 312.

## SL3.5. Reproducibilidad

```
cd /home/katana/zeo/ZEROX/P-ZRX/P-DAG/T04
export PATH=/home/katana/torio/.juliaup/bin:$PATH
export JULIA_DEPOT_PATH=$PWD/.julia-depot JULIA_PKG_OFFLINE=true
env -u LD_LIBRARY_PATH julia --project=. exportar.jl --dirigidos 1 --aleatorios 900 --ev-replicas 120
env -u LD_LIBRARY_PATH julia --project=. src/lector_vectores.jl resultados/vectores-estado-dag-v0.4.txt
env -u LD_LIBRARY_PATH julia --project=. run.jl --seed 0x5a5a --replicas 200
env -u LD_LIBRARY_PATH julia --project=. -e 'using Pkg; Pkg.test()'
```

Julia 1.13.0; 1 hilo; sin Python; sin commit ni push; sin secretos; nada escrito fuera de `T04/`.

## SL3.6. Lo que T04-SL3 NO demuestra

- **No modela la forma de wire v4** ni criptografía real (igual que T01).
- **No calibra parámetros** (`f`, `Plazo_slots`, `M_margen_slots`): son entradas.
- La evidencia se **descarta** cuando no valida al fusionarse; el oráculo no decide si el
  motor Rust debe además penalizar la propagación de evidencia inválida (fuera de la orden).

# T04-SL3b — Cobertura de evidencia corregida (`sin_saldo` y `deshecha` por reorg)

**Ejecutor:** DeepSeek `deepseek-flash` (esfuerzo `high`). **Fecha:** 2026-09-26.
**Fuente:** `ORDEN-SL3b.md` (motivo: `REVISION-SL3.md`) y `CONTRATO-EVIDENCIA-v0.md` con
**RAT-2′**. **Zona:** `T04/`. Sin Python; sin commit ni push; sin secretos.

## SL3b.1. Veredicto

**SUPERADO.** Se cierran las dos lagunas de cobertura señaladas en `REVISION-SL3.md` §2: el
generador aleatorio produce evidencia **contra clave sin saldo** (`sin_saldo = 80 ≥ 30`) y el
contador **`deshecha`** pasa a medir «aplicada en algún estado y luego deshecha por una
reorganización» (`deshecha = 115 ≥ 30`), no el undo exacto trivial que daba
`deshecha = construida = 771`. Se documentan las definiciones de cada contador en
`cobertura-v0.5.txt`. `Pkg.test()` **422/422**; `run.jl` **ESTADO = SUPERADO**; vectores
`vectores-estado-dag-v0.5.txt` (1 878 casos) con relectura **0 discrepancias**; v0…v0.4
**intactos**.

## SL3b.2. Definición de cada contador de evidencia

| Contador | Definición | v0.5 |
|---|---|---:|
| `construida` | `EvidenceTx` presente en la historia de aplicación seleccionada | 770 |
| `aplicada` | se aplica sin descarte al aplicarse su bloque | 227 |
| `sin_saldo` | aplicada con `V = 0` en su clave (EV-22): pérdida 0, incidente registrado | **80** |
| `duplicada` | descartada por `ErrEvidenciaDuplicada` (EV-12) | 30 |
| `tardia` | descartada por `ErrEvidenciaTardia` (EV-14) | 296 |
| `cbid_ajeno` | descartada por `ErrCbidAjeno` (RAT-1) | 137 |
| `con_entradas` | descartada por `ErrEvidenciaConEntradas` (EV-04) | 0 |
| `deshecha` | aplicada en la historia seleccionada en algún momento y luego retirada por una reorganización (EV-27/EV-28) | **115** |

`sin_saldo` se mide contra `A.past[bid]` (como en T01). `deshecha` se mide con
`evidencias_deshechas_por_reorg(A)`: reprocesa la historia en orden de `id` sobre una
`Admision` nueva y, tras cada cambio de punta, cuenta las evidencias que estaban aplicadas en
la historia anterior y ya no lo están; **no** cuenta el undo exacto de un bloque que sigue en
la cadena seleccionada.

## SL3b.3. Qué se ha implementado

- `src/generadores.jl`: `evidencias_aplicadas(A)` (conjunto aplicado en la historia
  seleccionada) y `evidencias_deshechas_por_reorg(A)` (medición por replay + cambio de punta),
  con salida temprana si la historia no tiene `EvidenceTx` (deja barato el apartado `run.jl`).
- `exportar.jl`: reclasifica `aplicada`/`sin_saldo`, sustituye el contador `deshecha`,
  escribe las definiciones en la cabecera de `cobertura-v0.5.txt` y pasa el defecto a **v0.5**.
- `test/runtests.jl`: relee v0.5 y comprueba que D-17 produce al menos una evidencia deshecha
  por reorganización (regresión de la definición nueva).
- `run.jl`: el registro por defecto pasa a `run-estado-dag-v0.5.log`.

## SL3b.4. Vectores y relectura

- `resultados/vectores-estado-dag-v0.5.txt`: **1 878 casos** (4 dirigidos de evidencia + 900
  aleatorios + 8×120 de evidencia), sha256
  `c7de88de1fa8755ff1742f7c7b556994a9a27296609173030e990058dade77a5`; `.sha256` relativo a
  `T04/`.
- Relectura independiente (`src/lector_vectores.jl`): **1 878 casos, 0 discrepancias**.
- v0.1…v0.4 **intactos** (`sha256sum -c` OK). Releer v0.4 con el oráculo RAT-2′ da
  discrepancias en `quemado`/recompensa, porque v0.4 se generó con RAT-2 (`techo`); el fichero
  queda byte a byte intacto y el intento bajo RAT-2′ se conserva en
  `relectura-v0.4-con-RAT2p.log`. La calibración de operaciones de garantía no cambia
  (depósitos 347, retiros 808, liberaciones 115, `ErrNonce` 853 = 18,29 %, `ErrDobleGasto`
  305, reorgs de garantía 312).

## SL3b.5. Reproducibilidad

```bash
cd /home/katana/zeo/ZEROX/P-ZRX/P-DAG/T04
export JULIA_DEPOT_PATH=$PWD/.julia-depot JULIA_PKG_OFFLINE=true
env -u LD_LIBRARY_PATH /home/katana/torio/.juliaup/bin/julia --project=. exportar.jl \
    --dirigidos 1 --aleatorios 900 --ev-replicas 120
env -u LD_LIBRARY_PATH /home/katana/torio/.juliaup/bin/julia --project=. \
    src/lector_vectores.jl resultados/vectores-estado-dag-v0.5.txt
env -u LD_LIBRARY_PATH /home/katana/torio/.juliaup/bin/julia --project=. run.jl \
    --seed 0x5a5a --replicas 200
env -u LD_LIBRARY_PATH /home/katana/torio/.juliaup/bin/julia --project=. -e 'using Pkg; Pkg.test()'
```

Julia 1.13.0; 1 hilo; sin Python; sin commit ni push; sin secretos; nada escrito fuera de
`T04/`.

## SL3b.6. Lo que T04-SL3b NO demuestra

- `deshecha` mide la historia **seleccionada** de la `Admision` generada; no es una garantía
  sobre la tasa de reorganizaciones de una red real (el generador las produce con `npost` y
  padres aleatorios).
- `sin_saldo` verifica que la evidencia se aplica con `V = 0`; **no** cierra la grieta
  A12/DS-3 (declarada en EV-22).
- La definición de `deshecha` no cubre reorgs que deshacen una evidencia y la reaplican
  después en la misma punta: eso cuenta como aplicación, no como deshecho, en cada cambio de
  punta.

---

# T04-SL4c-O — `cbid` ajeno y orden no canónico son errores de **forma** (bloque inválido)

**Ejecutor:** DeepSeek `deepseek-flash` (nombre que devuelve la API: `deepseek-flash`,
DeepSeek-V4.1-Flash; esfuerzo `high`). **Fecha:** 2026-09-26 (≈ 23:10–23:20).
**Fuente:** `ORDEN-SL4c-O.md` parte O2 (motivo: `REVISION-RI-3b.md` H1) y
`CONTRATO-EVIDENCIA-v0.md` (RAT-1, EV-04). **Zona:** `T04/`. Sin Python; sin commit ni push;
sin secretos. Entrada congelada `ENTRADA-SL4c-O.sha256`: **7/7 OK**.

## SL4cO.1. Veredicto

**SUPERADO.** En el oráculo DAG, una `EvidenceTx` con `consensus_branch_id` ajeno (RAT-1) o con
las dos cabeceras fuera del orden canónico estricto `pre_hash(H1) < pre_hash(H2)` (EV-04) pasa a
ser un error de **forma**: el bloque que la contiene es **inválido en la admisión**, no un
descarte. T04 comprueba la forma v4 por sí mismo (no depende del `Err` de T01, que O1 cambia en
paralelo) con la precedencia fija del contrato — estructura ya vigente → `cbid` → orden canónico
— y **global al bloque** (primero todos los `cbid`, después todos los órdenes), de modo que
«gana `cbid`» se cumple aunque los dos defectos estén en transacciones distintas. El resto de la
verificación semántica (EV-06 identidad, EV-07 sellos, RAT-3, ventana, deduplicación) no cambia
de orden ni de resultado.

## SL4cO.2. Falta de definición informada antes de editar

1. **Representación Julia de `ErrForma(...)`.** La orden fija los nombres
   `ErrForma(EvidenciaCbidAjeno)` y `ErrForma(OrdenCanonicoInvalido)`, pero T04 no tiene un tipo
   `ErrForma`: los motivos de bloque son `Symbol` en `A.motivos` y se vuelcan con `string(...)`.
   Lectura adoptada: `Symbol("ErrForma(EvidenciaCbidAjeno)")` y
   `Symbol("ErrForma(OrdenCanonicoInvalido)")`, que `string` rinde exactamente como el contrato en
   `RES` y en el lector independiente, sin depender del enum de T01 que O1 modifica.
2. **Base del informe de diferencias.** v0.6 se genera con un generador ampliado (modo `:orden`),
   así que sus casos aleatorios no son los de v0.5. Lectura adoptada: `DIFERENCIAS-v0.5-v0.6.md`
   reproduce las **entradas congeladas de v0.5** con el oráculo corregido y las compara con la
   salida registrada en v0.5 (comparación caso a caso exacta); los casos nuevos de v0.6 se listan
   aparte como añadidos.
3. **Alcance de la precedencia.** Aplicada global al bloque, no por transacción (ver SL4cO.3).

## SL4cO.3. Qué se ha implementado

- `src/EstadoDAG.jl`: `chequear_forma_evidencia(A, b)` y los motivos `MOTIVO_FORMA_CBID` /
  `MOTIVO_FORMA_ORDEN`; se llama al final de `chequear_forma` (después de la estructura de
  padres/slot/coinbase). Una `EvidenceTx` sin cabeceras sigue siendo semántica
  (`ErrSinEvidencia`); la estructura de entradas/salidas/testigos no se toca (fuera del alcance).
- Coherencia con O1 (comprobada): el `T01` final de O1 (`src/Transicion.jl`, mtime
  2026-09-26 23:15:46) tipa los formales como `ErrForma(clase)` y rinde exactamente
  `ErrForma(EvidenciaCbidAjeno)` / `ErrForma(OrdenCanonicoInvalido)`; T04 reproduce esos mismos
  textos con `Symbol` sin acoplarse a su tipo. Toda la batería final (exportar, relectura, diff,
  tests y `run.jl`) se ejecutó con ese `T01`.
- `src/generadores.jl`: `evidencia_aleatoria` gana los modos `:orden` (`H1 = H2`) y `:ambos`
  (`cbid` ajeno + orden), y el generador aleatorio los inyecta.
- `src/dirigidos.jl`: `caso_forma_evidencia` (D-19) construye un bloque con coinbase, una
  transferencia válida y una evidencia defectuosa, su hijo inválido y un gemelo canónico válido;
  `casos_forma_cobertura` da 36 `cbid` + 36 orden + 8 ambos con tx válida. D-18 deja de incluir
  `cbid` (ya no es un descarte) y conserva tardía + sin saldo.
- `exportar.jl`: pasa a **v0.6**, añade `contar_forma_evidencia` y los 80 casos dedicados, y
  **falla** si no se alcanzan los mínimos de la orden. `run.jl` y `test/runtests.jl` pasan a v0.6
  y añaden las comprobaciones de forma. `src/diferencias.jl` genera el informe de diferencias.

## SL4cO.4. Cobertura (v0.6)

| Contador | Definición | v0.6 | Mínimo |
|---|---|---:|---:|
| `bloque_cbid` | bloque inválido `ErrForma(EvidenciaCbidAjeno)` | **279** | ≥ 30 |
| `bloque_orden` | bloque inválido `ErrForma(OrdenCanonicoInvalido)` | **125** | ≥ 30 |
| `ev_cbid` | `EvidenceTx` con `cbid` ajeno en esos bloques | **279** | — |
| `ev_orden` | `EvidenceTx` con orden no canónico en esos bloques | **125** | — |
| `con_tx_cbid` | bloque `cbid` con además una tx monetaria | **166** | ≥ 10 |
| `con_tx_orden` | bloque orden con además una tx monetaria | **78** | ≥ 10 |
| `ambos_cbid` | bloque con los dos defectos (gana `cbid`) | **127** | ≥ 5 |

La sección semántica de evidencia se mantiene por encima de los mínimos de SL-3b: `sin_saldo`
**46** (≥ 30) y `deshecha` **67** (≥ 30); `aplicada` 263, `duplicada` 21, `tardia` 197,
`construida` 527. La tabla de operaciones de garantía no cambia (depósitos 347, retiros 808,
liberaciones 115, `ErrNonce` 853 = 18,29 %, `ErrDobleGasto` 305, reorgs 312).

## SL4cO.5. Vectores, relectura y diferencias

- `resultados/vectores-estado-dag-v0.6.txt`: **1 961 casos** (21 dirigidos + 900 aleatorios +
  8×120 de evidencia + 80 de forma), sha256
  `c383abab132892ee40bf1b941e0c647903d3ffc71d905b834459d53083e395bc`; `.sha256` relativo a
  `T04/`. Formato de línea idéntico a v0.5.
- Relectura independiente (`src/lector_vectores.jl`): **1 961 casos, 0 discrepancias**
  (`resultados/relectura-v0.6.log`).
- `resultados/DIFERENCIAS-v0.5-v0.6.md`: las 1 878 entradas de v0.5 reproducidas con el oráculo
  corregido; **181** casos con defecto de forma, **135** cambian de resultado y **0** cambian sin
  defecto (`VEREDICTO = SIN CAMBIOS INJUSTIFICADOS`). v0.5 no contenía ningún caso de orden no
  canónico, así que todos los cambios observados son de `cbid` ajeno: el bloque pasa a
  `ErrForma(EvidenciaCbidAjeno)`, sus descendientes a `ErrSinPadre` y desaparecen sus
  `DESC`/créditos/incidentes.
- v0.4 y v0.5 **intactos** (`sha256sum -c ENTRADA-SL4c-O.sha256`, 7/7 OK).

## SL4cO.6. Reproducibilidad

```bash
cd /home/katana/zeo/ZEROX/P-ZRX/P-DAG/T04
export JULIA_DEPOT_PATH=$PWD/.julia-depot JULIA_PKG_OFFLINE=true
env -u LD_LIBRARY_PATH /home/katana/torio/.juliaup/bin/julia --project=. exportar.jl \
    --dirigidos 1 --aleatorios 900 --ev-replicas 120
env -u LD_LIBRARY_PATH /home/katana/torio/.juliaup/bin/julia --project=. \
    src/lector_vectores.jl resultados/vectores-estado-dag-v0.6.txt
env -u LD_LIBRARY_PATH /home/katana/torio/.juliaup/bin/julia --project=. \
    src/diferencias.jl resultados/vectores-estado-dag-v0.5.txt
env -u LD_LIBRARY_PATH /home/katana/torio/.juliaup/bin/julia --project=. run.jl \
    --seed 0x5a5a --replicas 200
env -u LD_LIBRARY_PATH /home/katana/torio/.juliaup/bin/julia --project=. -e 'using Pkg; Pkg.test()'
```

`Pkg.test()` **447/447** (422 previas; D-18 pierde su aserción de `cbid` y se añaden 26 nuevas
de forma v4; registro `resultados/test-pkg-v0.6.log`).
`run.jl --seed 0x5a5a --replicas 200`: **ESTADO = SUPERADO**, 0 fallos, 76,7 s; 1 600 historias
con C-EVP (11 530 válidos, 2 349 descartes, 34 duplicadas, 305 tardías, **339** bloques
`forma_cbid` y **177** `forma_orden`), 3 000 historias base, 600 000 órdenes IE-3
(`resultados/run-estado-dag-v0.6.log`). Julia 1.13.0; 1 hilo; sin Python; sin commit ni push;
nada escrito fuera de `T04/`.

## SL4cO.7. Lo que T04-SL4c-O NO demuestra

- No toca T01 (O1) ni Rust (SL-4c): solo corrige el oráculo DAG. La coherencia con T01 depende de
  que O1 aplique la misma precedencia en el modo estricto.
- La comprobación usa las cabeceras ya decodificadas del oráculo; no ejerce el parser de bytes
  (`n_in`/`n_out`/`n_wit`, longitudes, campos inactivos), que sigue fuera de T04.
- `DIFERENCIAS-v0.5-v0.6.md` compara las entradas de v0.5; no es un diff de los casos aleatorios
  nuevos de v0.6 (el generador cambió para cubrir `:orden`/`:ambos`).

---

# T04-SL4c-O-B — Precedencia por transacción y los dos tipos de orden no canónico

**Ejecutor:** DeepSeek `deepseek-flash` (nombre que devuelve la API: `deepseek-flash`,
DeepSeek-V4.1-Flash; esfuerzo `high`). **Fecha:** 2026-09-26 (≈ 23:24–23:35).
**Fuente:** `ORDEN-SL4c-O-B.md`, revisión del director de SL-4c-O. **Zona:** `T04/`.
Sin Python; sin commit ni push; sin secretos.

## SL4cOB.0. Entrada congelada (inicio)

`sha256sum -c P-ZRX/P-SLASHING/ENTRADA-SL4c-O-B.sha256` (desde `ZEROX/`): **3/3 OK**
(`ORDEN-SL4c-O-B.md`, `ORDEN-SL4c-O.md`, `V-ZRX/LINEO.md`); registro
`resultados/entrada-SL4c-O-B.log`.

## SL4cOB.1. Falta de definición detectada antes de editar

Ninguna bloqueante; tres lecturas informadas antes de tocar código:

- **«Estructura vigente» en T04.** La regla manda, por transacción, «estructura vigente → `cbid`
  → orden canónico». En T04 el único chequeo estructural de la evidencia
  (`ErrEvidenciaConEntradas`, `n_in/n_out/n_wit`) es un **descarte semántico** al fusionar, no
  parte de `chequear_forma`; moverlo cambiaría casos **sin** los dos defectos, que SL-4c-O
  prohíbe. El bucle por transacción de T04 aplica por tanto solo `cbid → orden`; la estructura
  queda donde estaba (ya declarado en SL4cO.7).
- **Reparto de mínimos.** Se conservan los mínimos de SL-4c-O (`bloque_cbid≥30`, `bloque_orden≥30`,
  `con_tx_cbid/con_tx_orden≥10`, `ambos_cbid≥5`) y se añaden `bloque_orden_desc≥10` y
  `bloque_orden_igual≥10`.
- **Versionado.** Los vectores v0.6 se **regeneran** sobrescribiendo los de SL-4c-O (aún no los
  consume nadie), conservando el nombre `vectores-estado-dag-v0.6.txt`.

## SL4cOB.2. Cambio aplicado

- `src/EstadoDAG.jl`: `chequear_forma_evidencia` deja de ser global al bloque (todos los `cbid`
  antes que todos los órdenes) y pasa a **por transacción**: recorre `b.txs` en su orden y, para
  cada `EvidenceTx`, comprueba `cbid` → orden canónico; la primera defectuosa fija el motivo.
  Nuevo helper **`primer_defecto_forma`** (exportado) que devuelve `:cbid`, `:orden_igual`,
  `:orden_desc` o `nothing`, usado por el oráculo, el exportador, `run.jl` y las pruebas.
- `src/generadores.jl`: `evidencia_aleatoria` distingue `:orden_igual` (`H1 = H2`) y `:orden_desc`
  (`H1 > H2`), más `:ambos_desc`; el generador aleatorio usa los dos tipos de orden.
- `src/dirigidos.jl`: `_evidencia_forma` gana `:orden_igual`; `casos_forma_cobertura` pasa a 36
  `cbid` + 36 igualdad + 36 descenso + 8 ambos; nuevos **D-20/D-21**
  (`caso_forma_dos_evidencias`) con `[orden, cbid]` y `[cbid, orden]`.
- `exportar.jl`: cobertura desglosada (`bloque_orden_igual/desc`, `ev_orden_igual/desc`) y mínimos
  nuevos; cabecera v0.6 rotulada SL-4c-O-B.
- `run.jl` y `test/runtests.jl`: aserciones de los dos tipos de orden y de la precedencia.
- `src/diferencias.jl`: prosa actualizada; la precedencia por transacción no altera el diff de
  v0.5 (todos sus defectos son `cbid`).

## SL4cOB.3. Resultados

| Comprobación | Resultado |
|---|---|
| `Pkg.test()` | **472/472** (`resultados/test-pkg-v0.6.log`) |
| `run.jl --seed 0x5a5a --replicas 200` | **ESTADO = SUPERADO**, 0 fallos, 129,7 s (`resultados/run-estado-dag-v0.6.log`) |
| Relectura independiente de v0.6 | **2 000 casos, 0 discrepancias** (`resultados/relectura-v0.6.log`) |
| `DIFERENCIAS-v0.5-v0.6.md` | 1 878 entradas; **181** con defecto, **135** cambian, **0** sin defecto |
| Cobertura de forma | `bloque_cbid=283`, `bloque_orden=243` (igual **115**, desc **128**), `ambos_cbid=161`, `con_tx_cbid=166`, `con_tx_orden=152` (`minimos_SL4cO=OK`) |
| Entrada congelada | **3/3 OK** |

`run.jl`: 3 000 historias base + 1 600 con C-EVP (11 254 válidos, 2 208 descartes, 37 duplicadas,
224 tardías), `forma_cbid` **410**, `forma_orden` **286** (igualdad **142**, descenso **144**),
600 000 órdenes IE-3. La cobertura semántica de evidencia se mantiene sobre mínimos:
`aplicada` 245, `sin_saldo` 42 (≥30), `deshecha` 59 (≥30), `duplicada` 20, `tardia` 145,
`construida` 452.

## SL4cOB.4. Vectores, relectura y diferencias

- `resultados/vectores-estado-dag-v0.6.txt`: **2 000 casos** (24 dirigidos + 900 aleatorios +
  8×120 de evidencia + 116 de forma), sha256
  `b1710e4cd0e99a7602555595f23ef050fe174ef9389768b56481927b0d79a331`; `.sha256` relativo a
  `T04/`. Formato de línea idéntico a v0.5.
- Relectura independiente: **2 000 casos, 0 discrepancias**.
- `DIFERENCIAS-v0.5-v0.6.md`: **135** cambios, todos con defecto (`cbid` ajeno; v0.5 no tenía
  orden no canónico); `VEREDICTO = SIN CAMBIOS INJUSTIFICADOS`. La precedencia por transacción no
  cambia ningún resultado de v0.5.
- v0.4 y v0.5 **intactos**.

## SL4cOB.5. Reproducibilidad

```bash
cd /home/katana/zeo/ZEROX/P-ZRX/P-DAG/T04
export JULIA_DEPOT_PATH=$PWD/.julia-depot JULIA_PKG_OFFLINE=true
env -u LD_LIBRARY_PATH /home/katana/torio/.juliaup/bin/julia --project=. exportar.jl \
    --dirigidos 1 --aleatorios 900 --ev-replicas 120
env -u LD_LIBRARY_PATH /home/katana/torio/.juliaup/bin/julia --project=. \
    src/lector_vectores.jl resultados/vectores-estado-dag-v0.6.txt
env -u LD_LIBRARY_PATH /home/katana/torio/.juliaup/bin/julia --project=. \
    src/diferencias.jl resultados/vectores-estado-dag-v0.5.txt
env -u LD_LIBRARY_PATH /home/katana/torio/.juliaup/bin/julia --project=. run.jl \
    --seed 0x5a5a --replicas 200
env -u LD_LIBRARY_PATH /home/katana/torio/.juliaup/bin/julia --project=. -e 'using Pkg; Pkg.test()'
```

Julia 1.13.0; 1 hilo; sin Python; sin commit ni push; nada escrito fuera de `T04/`. El sha256 de
los vectores incluye la fecha real de generación en su cabecera (misma convención que v0…v0.5).

## SL4cOB.6. Lo que T04-SL4c-O-B NO demuestra

- Sigue sin mover la comprobación estructural de la evidencia (`ErrEvidenciaConEntradas`) a la
  forma: en T04 es descarte semántico; la precedencia por transacción solo cubre `cbid` y orden.
- Los casos de dos evidencias defectuosas son dirigidos (D-20/D-21); el generador aleatorio
  produce cada defecto en transacciones separadas con baja probabilidad, así que la precedencia
  entre defectos de transacciones distintas se demuestra con esos dos casos, no con estadística.
- La coherencia con T01 (O1) depende de que O1 mantenga la precedencia por transacción; T04
  incluye `Transicion.jl` de T01 como dependencia de solo lectura.

---

# SL-4c-O-C (T04) — La evidencia con entradas/salidas también es forma (EV-04)

**Ejecutor:** DeepSeek `deepseek-flash` (nombre que devuelve la API: `deepseek-flash`,
DeepSeek-V4.1-Flash; esfuerzo `high`). **Fecha:** 2026-09-26 (≈ 23:37–23:50).
**Fuente:** `ORDEN-SL4c-O-C.md`, revisión del director de SL-4c-O-B. **Zona:** `T04/`.
Sin Python; sin commit ni push; sin secretos; 1 hilo.

## SL4cOC.0. Entrada congelada (inicio)

`cd /home/katana/zeo/ZEROX && LC_ALL=C sha256sum -c P-ZRX/P-SLASHING/ENTRADA-SL4c-O-C.sha256`
— **4/4 OK** (`ORDEN-SL4c-O-C.md`, `ORDEN-SL4c-O-B.md`, `ORDEN-SL4c-O.md`, `V-ZRX/LINEO.md`);
registro `resultados/entrada-SL4c-O-C.log` (2026-09-26T23:43:46+02:00).

## SL4cOC.1. Falta de definición informada antes de editar

**FD-SL4cOC-1 · `testigos`/`n_wit` no existe en el modelo tipado (no bloqueante, declarada).**
La orden incluye la estructura de EV-04 como «entradas, salidas o testigos» y exige «≥5 con los tres
defectos a la vez (gana entradas)». El contrato EV-04 sí incluye `n_wit ≠ 0`, pero el modelo `Tx` de
T01 (que T04 `include`a como dependencia de solo lectura) solo tiene `entradas` (`n_in`) y `salidas`
(`n_out`); no hay campo de testigos y el códec de wire de la v4 está declarado fuera de alcance
(FD-5 de SL4a). Añadirlo exigiría modificar `Tx` (zona de O1) y el formato de línea de los vectores
(que la orden fija como «el mismo»). Decisión declarada: se implementan las dos subclases
representables (`entradas`, `salidas`, y ambas) y, para cubrir la precedencia «gana entradas» y la
lectura «los tres defectos de la precedencia», se añaden además casos con estructura + `cbid` ajeno +
orden no canónico. No se toca T01 ni el formato. Se declara en §SL4cOC.6 y en la cobertura.

**FD-SL4cOC-2 · `ErrEvidenciaConEntradas` deja de ser semántico.** Igual que SL-4c-O hizo con
`ErrCbidAjeno`/`ErrOrdenCanonico`, O1 lo retira de `ErrSemantico` y de los `export` y lo deja como
constante interna `ErrForma(EvidenciaConEntradasOSalidas)`, de modo que T04 siga cargando hasta su
O2. T04 retira su única referencia (`exportar.jl`) y no depende de él. No bloqueante.

**FD-SL4cOC-3 · Versionado.** v0.6 se regenera en el mismo fichero (aún sin consumidor), como en
SL-4c-O-B; v0.5 no se toca y sigue siendo la referencia del diff.

## SL4cOC.2. Cambio aplicado

- `src/EstadoDAG.jl`: nuevo `MOTIVO_FORMA_ESTRUCTURA = ErrForma(EvidenciaConEntradasOSalidas)` y
  `defecto_estructura_evidencia` (`:entradas`, `:salidas`, `:entradas_salidas`); `primer_defecto_forma`
  comprueba, por transacción y en su orden, `estructura → cbid → orden`; `chequear_forma_evidencia`
  mapea la estructura a `MOTIVO_FORMA_ESTRUCTURA` y el bloque queda **inválido en la admisión** (no
  descarte). El camino de fusión (`aplicar_bloque_fusion!`) ya no ve estas evidencias.
- `src/dirigidos.jl`: `_evidencia_forma` y `_tx_evidencia_forma` (entradas/salidas/ambas y sus
  combinaciones con `cbid`/orden); `caso_forma_evidencia` acepta los modos de estructura (D-19); la
  cobertura pasa a 220 casos (36 `cbid` + 36 igualdad + 36 descenso + 8 ambos + 36 entradas +
  36 salidas + 8 entradas+salidas + 8 entradas+cbid + 8 entradas+orden + 8 entradas+cbid+orden).
- `exportar.jl`: cobertura de estructura (`bloque_estructura`, `_entradas`, `_salidas`, `_ambos`,
  `_cbid_orden`, `ev_estructura`, `con_tx_estructura`) y mínimos nuevos; se retira de
  `contar_evidencia` la rama `ErrEvidenciaConEntradas` (ya inalcanzable) y se actualiza la cabecera a
  `T04-SL4c-O-C`.
- `run.jl`, `test/runtests.jl` y `src/diferencias.jl`: aserciones, contadores y detección de la
  estructura; `METODO.md` actualizado.

## SL4cOC.3. Resultados

| Comprobación | Resultado |
|---|---|
| `Pkg.test()` | **507/507** (`resultados/test-pkg-v0.6.log`) |
| `run.jl --seed 0x5a5a --replicas 200` | **ESTADO = SUPERADO**, 0 fallos, 94,1 s (`resultados/run-estado-dag-v0.6.log`) |
| Relectura independiente de v0.6 | **2 108 casos, 0 discrepancias** (`resultados/relectura-v0.6-SL4c-OC.log`) |
| `DIFERENCIAS-v0.5-v0.6.md` | 1 878 entradas; **181** con defecto, **135** cambian, **0** sin defecto |
| Cobertura de forma | `bloque_estructura=108` (entradas **62**, salidas **37**, ambos **9**, `cbid_orden` **9**), `con_tx_estructura=108`; `bloque_cbid=283`, `bloque_orden=243` (igual **115**, desc **128**), `ambos_cbid=161`, `con_tx_cbid=166`, `con_tx_orden=152` (`minimos_SL4cO=OK`) |
| `mtime` de `Transicion.jl` (T01) | `2026-09-26 23:39:41.298582413 +0200` (epoch `1790458781`, md5 `30ef7ec9…`) |
| Entrada congelada | **4/4 OK** |

`run.jl`: 3 000 historias base (46 500 bloques, 25 192 válidos, 4 497 descartes, 2 078 `rojo_U3`,
600 000 órdenes IE-3) + 1 600 con C-EVP (11 254 válidos, 2 208 descartes, 37 duplicadas, 224 tardías,
`forma_cbid` **410**, `forma_orden` **286**: igualdad **142**, descenso **144**). La estructura
`forma_estructura` es **0** en los casos aleatorios (el generador no produce evidencias con
entradas/salidas): la cobertura estructural exigida es **determinista**, vía los 220 casos dirigidos
`forma-*` de `exportar.jl`. Evidencia semántica: `aplicada` 353, `sin_saldo` 42 (≥30), `deshecha` 59
(≥30), `duplicada` 20, `tardía` 145, `construida` 560.

## SL4cOC.4. Vectores, relectura y diferencias

- `resultados/vectores-estado-dag-v0.6.txt`: **2 108 casos** (28 dirigidos + 900 aleatorios +
  960 de evidencia + 220 de forma), sha256
  `86348a48e32491c9cb3675fa1c2d7e06f4c20f94518f35b227778d28d4a90c19`; `.sha256` relativo a `T04/`.
  Formato de línea idéntico a v0.5 (sin campos nuevos).
- Relectura independiente: **2 108 casos, 0 discrepancias**.
- `DIFERENCIAS-v0.5-v0.6.md`: **135** cambios, todos con defecto (`cbid` ajeno); v0.5 no tenía orden
  no canónico ni estructura defectuosa, así que la adición de entradas/salidas **no cambia ningún
  resultado** del diff (`VEREDICTO = SIN CAMBIOS INJUSTIFICADOS`, 0 cambios sin defecto).
- v0.4 y v0.5 **intactos** (`ENTRADA-SL4c-O.sha256`: 7/7 OK).

## SL4cOC.5. Reproducibilidad

```bash
cd /home/katana/zeo/ZEROX/P-ZRX/P-DAG/T04
export JULIA_DEPOT_PATH=$PWD/.julia-depot JULIA_PKG_OFFLINE=true
env -u LD_LIBRARY_PATH /home/katana/torio/.juliaup/bin/julia --project=. exportar.jl \
    --dirigidos 1 --aleatorios 900 --ev-replicas 120
env -u LD_LIBRARY_PATH /home/katana/torio/.juliaup/bin/julia --project=. \
    src/lector_vectores.jl resultados/vectores-estado-dag-v0.6.txt
env -u LD_LIBRARY_PATH /home/katana/torio/.juliaup/bin/julia --project=. \
    src/diferencias.jl resultados/vectores-estado-dag-v0.5.txt
env -u LD_LIBRARY_PATH /home/katana/torio/.juliaup/bin/julia --project=. run.jl \
    --seed 0x5a5a --replicas 200
env -u LD_LIBRARY_PATH /home/katana/torio/.juliaup/bin/julia --project=. -e 'using Pkg; Pkg.test()'
```

Julia 1.13.0; 1 hilo; sin Python; sin commit ni push; nada escrito fuera de `T04/`. El sha256 de los
vectores incluye la fecha real de generación en su cabecera (misma convención que v0…v0.5).

## SL4cOC.6. Lo que T04-SL4c-O-C NO demuestra

- **`testigos`/`n_wit` no está en el modelo `Tx` de T01.** EV-04 solo se ejerce aquí por
  `entradas`/`salidas`; el caso `n_wit ≠ 0` del contrato queda pendiente del códec de wire de la v4
  (FD-5 de SL4a). La orden pedía «≥5 con los tres defectos a la vez (gana entradas)»: se entregan
  **9** casos con los dos sub-defectos representables a la vez (`bloque_estructura_ambos`) y **9** con
  los tres defectos de la **precedencia** (`entradas` + `cbid` ajeno + orden, `bloque_estructura_cbid_orden`),
  ambos por encima del mínimo de 5; el tercer sub-defecto de EV-04 (testigos) no es representable sin
  tocar el modelo o el formato.
- Los casos de estructura son **dirigidos** (D-19 con modos nuevos); el generador aleatorio no produce
  evidencias con entradas/salidas, así que la cobertura es determinista, no estadística.
- La coherencia con T01 (O1) se apoya en el `mtime` final registrado arriba; la batería final de T04
  (`exportar.jl`, relectura, diferencias, `Pkg.test()`, `run.jl`) se ejecutó con ese `Transicion.jl`.

