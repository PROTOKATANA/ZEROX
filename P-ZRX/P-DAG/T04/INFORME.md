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
