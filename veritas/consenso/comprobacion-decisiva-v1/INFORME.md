# INFORME — Comprobación decisiva v1 (etapa A)

Fecha: 2026-09-12 · Semilla-etiqueta: 20260912 · Zona de escritura original: `deepseek/`
(promovido el 2026-09-12 a `veritas/consenso/comprobacion-decisiva-v1/`).
Categoría dominante: **consenso** (secundarias: economía, finalidad).

## Veredicto por requisito del objetivo

| # | Requisito del objetivo | Estado | Evidencia |
|---:|---|---|---|
| 1 | Dos nodos con el mismo conjunto de bloques en distinto orden convergen sobre una historia | **Demostrado** | `runtests.jl` "convergencia…" (208 asserts, 4 combinaciones política×redondeo, vistas Reference y Fast); `RUN.txt` `node_convergence=true` |
| 2 | Igualdad exacta de pagos al converger | **Demostrado** | proyección económica idéntica: 6 pagos `(contexto,bloque,utxo,importe)`, `total_paid=3000`, comparados tupla a tupla |
| 3 | Igualdad exacta de transacciones/consumos | **Demostrado** | 6 consumos idénticos, `total_consumed=5500`, conjunto disponible final idéntico (10 UTXOs) |
| 4 | Igualdad exacta de retarget | **Demostrado** | `retarget_equal=true`; propuestas `200@20, 400@30`, agenda, activaciones y `range_at` idénticos |
| 5 | Candidatos independientes completos siguen avanzando | **Demostrado** | Ana adopta la rama B con 2 sellos antes del objetivo; Bruno adopta B mientras el objetivo está Pending |
| 6 | Cuerpo tardío reproduce la historia retenida (no inerte) | **Demostrado** | Bruno: objetivo Pending (cuerpo 1 retenido) → adopta B → llega el cuerpo → objetivo Applied y publica |
| 7 | Peso azul con deduplicación: las copias no multiplican | **Demostrado** | peso dedup = 5, peso naive agrupando por (billete, piece_offset, variant) = 6; el estado usa 5 |
| 8 | Control negativo de multiplicación detectado | **Demostrado** | `naive_detected=true`; rango dedup 200 ≠ rango naive 166 |
| 9 | Doble gasto → Invalid sin publicar | **Demostrado** | entre ventanas y en la misma ventana: `DCM.Invalid`, proyección pública intacta, `pending=0` |
| 10 | Control negativo del reloj local | **Demostrado** | misma evidencia, recepción 9 → rango 200; recepción 21 → 100; el camino causal da 200 |
| 11 | Ventana vacía con HeldZero | **Demostrado (convergencia Julia–Rust, enmienda Z0 2026-09-12)** | HeldZero es no-op: sin propuesta agendada, `activation_slot=0`; `range_at(39)=200`, `range_at(40)=200` en Julia (Reference y Fast) y en Rust |
| 12 | Referencia BigInt == kernel UInt128 | **Demostrado** | tests de equivalencia sobre los 4 vectores; benchmark sin divergencia |
| 13 | Pending e Invalid no publican parcialmente | **Demostrado** | proyección pública idéntica antes/después en todos los controles |

**Conclusión:** el objetivo queda **demostrado** en el modelo declarado. Ningún requisito
queda refutado ni pendiente dentro del alcance. Timeout no aplicó (suite en segundos).

## Unicidad pagable (§7.2) — vectores añadidos (tanda 1)

Suite ampliada de 280 a 451 asserts (tanda 2026-09-12: +93; tanda 1-bis 2026-09-12:
+76; enmienda Z0 2026-09-12: +2; 0 regresiones). Cuatro fixtures nuevos cubren la laguna de §7.2. Política
decidida por Katana: **P1 — azul primero, luego (rank, id)** como orden de SELECCIÓN
entre copias del mismo billete (no de aplicación del mergeset; ver SPEC.md §7.2).

| Vector | Requisito del §7.2 | Estado | Evidencia |
|---|---|---|---|
| `fixture_copias_rojas_sin_azul` | Un billete paga y cuenta exactamente una vez, también sin copia azul | **Demostrado** | 4 combos {P0,P1}×{Reference,Fast} idénticos: `observed=2` (billete 1 dedupado a un ganador + billete 3), pagos `[(700,3,1003,500),(700,2,1002,500)]`, `total_paid=1000`; gana el bloque 2 (rank 2 < rank 3); el bloque 1 no cobra ni cuenta (`consumed={1,3}`, no aparece en `counted`). Derivados: `consumptions=[(700,3,103,1000),(700,2,101,1000)]`, `available=[(102,1000),(104,1000),(105,1000),(1002,500),(1003,500)]`, `total_consumed=2000`. Orden de entrega invertido: proyección idéntica |
| `fixture_desempate_color` | Desempate entre copias: P1 azul primero | **Demostrado (P1 decidido)** | Único vector que distingue políticas: P0 → `[(700,8,1008,800)]`, `total_paid=800`; P1 → `[(700,7,1007,700)]`, `total_paid=700` (el azul gana pese a rank 5 > 2). El test afirma que P0 y P1 dan resultados DISTINTOS: la decisión de Katana es material |
| `fixture_copia_en_fusion_posterior` | Copia en fusión posterior: inerte, ni cobra ni cuenta | **Demostrado** | P0 y P1 idénticos: `current=701`, 2 pagos `total_paid=1000`, la copia 9 no aparece en `payments`, `observed` por ventana `[1,1]` (no infla el retarget) |
| `fixture_reorg_libera_billete` | Reorg libera el billete: se paga en la rama que prevalece, nunca dos veces | **Demostrado** | El mismo billete 1 gana en dos ramas competidoras (bloque 1 en H700, bloque 20 en H800 con `window=700` por restricción del catálogo). Tras reorg a H800: `payments=[(800,20,1020,777)]`, `consumed={1}`, el pago de la rama abandonada no aparece, y la proyección pública no conserva nada de la rama A (journal, counted, applied_blocks). Derivados confirmados: rama A `total_paid=500`, `total_consumed=1000`, `consumptions=[(700,1,101,1000)]`; rama B `total_paid=777`, `total_consumed=1000`, `consumptions=[(800,20,102,1000)]`, `available=[(101,1000),(103,1000),(104,1000),(105,1000),(1020,777)]`, `observed=[1]`, `proposals=[(800,0,20,200)]`. 4 combos {P0,P1}×{Reference,Fast} idénticos |

**Hallazgo (documentado en `test/runtests.jl` con `@test_throws ArgumentError`):** en la
copia en fusión posterior disparan DOS guardas independientes a la vez — (a) el billete 1
ya está en `consumed`, y (b) la ventana de origen del bloque 9 (700) no es la ventana de
la historia H701. No se pueden aislar en vectores distintos porque `DCM.Catalog` rechaza
con `ArgumentError("ticket changes origin window")` cualquier copia que declare otra
ventana de origen para el mismo billete. La copia en fusión posterior es inerte por dos
reglas, no por una.

## Modelo (nuevo respecto a ARM-v0.1)

1. **Capa económica mínima entera.** `TxSpec` por bloque: entradas (IDs de UTXO enteros) y
   salidas (pagos con importe `UInt64`). Sin criptografía (declarado). Prohibido Float64
   para dinero: totales con `Base.Checked` (LINEO §9). Doble gasto o entrada desconocida →
   Invalid, sin publicación. Las copias perdedoras nunca aplican sus transacciones.
2. **Peso azul deducplicado.** El billete (`ticket`) identifica la oportunidad; las copias
   comparten billete y difieren en `piece_offset`/`variant`. La selección DCM agrupa por
   billete: una copia no multiplica el peso (observed=5 con 6 bloques en ventana). El
   control negativo agrupa por (billete, piece_offset, variant) → peso 6 → retarget
   distinto, detectado y no usado.
3. **Dos nodos, no dos vistas.** `Nodo` con cola de entregas propia (mismo multiconjunto de
   eventos, distinto orden) y preferencia objetivo/respaldo. Ana retiene el cuerpo de la
   copia 6 (no requerida); Bruno retiene el cuerpo del ganador 1 (requerida).
4. **Progreso de candidatos independientes.** Tras cada entrega el nodo intenta el objetivo;
   si no es Applied, intenta la rama independiente completa. Observado: Ana progresa sobre
   B antes del objetivo; Bruno progresa sobre B mientras el objetivo está Pending; al
   llegar el cuerpo tardío, el objetivo se valida y reproduce.

## Método

- Julia 1.13.0 CPU, 1 hilo, BLAS 1, `--check-bounds=yes`, sin RNG (`rng=none`), semilla
  obligatoria 20260912 como etiqueta (no se usa para aleatoriedad).
- Motores DCM-v0.1 y RCE-v0.1 **revisión 2** (enmienda Z0, 2026-09-12) incluidos por ruta
  relativa (`src/ComprobacionDecisiva.jl`), patrón de `AdmisionRetargetMultivista.jl:3-8`.
- Dos velocidades: referencia que reescanea el catálogo, reconstruye DCM desde génesis y
  usa BigInt (`reference=true`); kernel con `replay_fast!`, cursor de propuestas y UInt128
  comprobado (`reference=false`). Ambas comparten la validación económica y de snapshots.
- Comandos (desde la raíz del repo):

```bash
env JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 JULIA_PKG_PRECOMPILE_AUTO=0 timeout 60s veritas/julia.sh --project=veritas/consenso/comprobacion-decisiva-v1 --check-bounds=yes veritas/consenso/comprobacion-decisiva-v1/test/runtests.jl --seed 20260912
env JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 JULIA_PKG_PRECOMPILE_AUTO=0 timeout 60s veritas/julia.sh --project=veritas/consenso/comprobacion-decisiva-v1 veritas/consenso/comprobacion-decisiva-v1/run.jl --seed 20260912
env JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 JULIA_PKG_PRECOMPILE_AUTO=0 timeout 60s veritas/julia.sh --project=veritas/consenso/comprobacion-decisiva-v1 veritas/consenso/comprobacion-decisiva-v1/bench/benchmarks.jl --seed 20260912
env JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 JULIA_PKG_PRECOMPILE_AUTO=0 timeout 60s veritas/julia.sh --project=veritas/consenso/comprobacion-decisiva-v1 veritas/consenso/comprobacion-decisiva-v1/bench/perfil.jl --seed 20260912
```

- Presupuesto declarado y cumplido: ≤1 hilo, BLAS 1, ≤8 GiB RAM, ≤30 min/suite, 60 s por
  comando. Suite: ~5 s tests + ~2 s run + ~30 s bench + ~8 s perfil. Sin timeout.
- Entorno completo en `resultados/ENTORNO.txt` (git `7b783d4`, julia 1.13.0, znver5,
  AMD Ryzen 9 9950X3D, 32 hilos, 123 GiB).

## Coste del workload (solo coste, no un nodo)

| Variante | depth 8 | depth 16 | depth 32 | Asignaciones (d32) |
|---|---:|---:|---:|---:|
| from_genesis BigInt_reference | 42 µs | 124 µs | 379 µs | 16 915 |
| from_genesis UInt128_replay | 56 µs | 147 µs | 378 µs | 17 247 |
| reorg BigInt_reference | 71 µs | 184 µs | 598 µs | 21 814 |
| reorg UInt128_replay | 98 µs | 264 µs | 906 µs | 26 859 |

Ambas vías coinciden exactamente en todos los vectores. En estas profundidades el coste
dominante es el patrón heredado de ARM (deepcopy de la vista DCM + snapshots + validación
de estructura), no la aritmética del controlador: por eso el kernel UInt128 no gana a la
referencia BigInt a depth ≤32 (mismo patrón que ARM-v0.1, cuyos números son del mismo
orden). No se optimizó más: el coste se mide y se declara.

Perfil (`resultados/PERFIL.txt`): `code_warntype_any=false`, tipo de retorno `Outcome`,
13 diagnósticos JET todos de despacho dinámico dentro de `deepcopy` (patrón reset-copia)
y 2 fallos de optimización por recursión en `deepcopy_internal`; ninguno en la aritmética
del controlador ni en la validación económica.

## Controles negativos

- **Reloj local** (heredado de ARM): misma evidencia, `local_seal=max(corte,recepción)`;
  recepción 9 agenda 200, recepción 21 es MissedUpdate → rango 100. El camino causal usa
  `causal_seal_slot` y da 200 en ambos.
- **Copias multiplicando peso**: agrupar por (billete, piece_offset, variant) cuenta 6 en
  vez de 5 y produce retarget 166 en vez de 200; detectado y rechazado.
- **Doble gasto**: entre ventanas (bloque 10 gasta la UTXO ya consumida por el bloque 1) y
  en la misma ventana (bloques 1 y 2 comparten entrada): Invalid, nada publicado.
- **Ventana vacía con HeldZero**: la enmienda Z0 (2026-09-12) hace de HeldZero un no-op
  — sin propuesta agendada, `activation_slot=0` — alineando Julia con el helper Rust
  histórico (`FeedbackState.close`, evidencia ARM-v0.1 `MODELO.md`/`CONTROLES-RUST.txt`).
  El rango queda en 200 en el slot 40 en ambas implementaciones: el hallazgo **H1** de
  `AUDITORIA-EXTERNA.md` queda **cerrado**. Antes de la enmienda, Julia agendaba `100@40`
  y `100@50` y el rango caía a 100; ese comportamiento era el fork documentado, no la regla.

## Límites declarados (no los cierra esta comprobación)

- Derivación GHOSTDAG real; validación PoAS contra el rango del pasado causal
  (`range_validation=Pending`).
- Firmas/criptografía (la capa económica es de IDs abstractos, sin firmas).
- **H7 — el billete es el único ancla.** Toda la seguridad del peso dedupado y de la
  unicidad pagable se reduce a que el billete identifique de verdad la oportunidad de
  pago. En este instrumento eso es una declaración del fixture (la copia se declara con
  el mismo `ticket` que el ganador), no un resultado del modelo. La propiedad real
  depende de `veritas/consenso/contrato-billete-v1/` y de C-HDR-03/04 del SPEC (dos
  firmas Ed25519 bajo la misma `public_key`, R-FIN-8′). Si un atacante pudiera acuñar
  un billete distinto para la misma prueba de espacio, el dedup no lo detendría y esta
  comprobación no lo cubre.
- Red libp2p, particiones/eclipse, cola de servicio de red (`network=Pending`).
- **Recompensa del bloque honesto tardío.** La inercia por ventana de origen fuera de la
  historia alcanza también a un bloque honesto con billete único que nadie disputa,
  fusionado después del cierre de su ventana: no cobra nunca (medido por el auditor: el
  billete 99 sin copia rival no aparece en `payments` ni cuenta en `observed`). El
  comportamiento es correcto y deliberado (es el «tardío contextual e Inert» del CONTRATO
  de DCM-v0.1), pero el destino de esa recompensa —pérdida definitiva, o reinclusión como
  la cola que modela RCE-v0.1— NO está decidido, y la regla de inercia no debe leerse
  como que ya lo está. Con Δ sin medir en DAG, no es un caso de borde raro.
- Durabilidad y atomicidad de un almacén real; finalidad Cortex (`cortex_finality=Pending`).
- Comportamiento bajo retención indefinida; política económica óptima. HeldZero es la
  política Z0 (no-op, sin agenda) desde la enmienda Z0 del 2026-09-12: un resultado del
  modelo y una decisión de Katana, no una recomendación de política económica general.
- Coste: los números de benchmark son del instrumento con fixtures sintéticos; no son un
  benchmark del nodo ni de DA0/DA1.

Esta comprobación decide la arquitectura de la etapa A (convergencia económica de dos
nodos con entregas adversariales); no es el nodo.
