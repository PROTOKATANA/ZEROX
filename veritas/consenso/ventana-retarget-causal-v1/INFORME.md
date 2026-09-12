# VRC-v0.1 — informe

## Resultado

El contrato estructural queda implementado y reproducido en Julia 1.13.0 y en un modelo Rust
aislado de test. Los siete fixtures compartidos producen 85 comprobaciones en referencia y
kernel; la suite Julia suma además 129 tests explícitos. El test Rust compartido y las 14
regresiones CBE pasan; Clippy estricto, rustfmt y `git diff --check` también pasan. `run.jl`
informa `structural_contract_ok`.

El resultado material es el contraejemplo L0: igualdad de conjunto pagable/contado no puede
mantenerse causalmente por slot original si un pago L0 se incorpora después del cierre. La
condición entera suficiente `G>=W_adm` evita ese caso para cohortes completas. LG lo evita por
construcción con `incorporation_slot < cutoff`. No se concluye que LG sea globalmente superior.

## Ejecución y rendimiento

Entorno observado: HEAD `7b783d469fbae5722a0ae014b5e212ed6999eb2b` con worktree previo
preservado; Julia 1.13.0, CPU `znver5` (16 núcleos/32 hilos), 1 hilo Julia, OpenBLAS ILP64
con 1 hilo y RAM visible 132497408000 bytes. `Project.toml` declara BenchmarkTools 1.8.0 y
JET 0.12.1; `Manifest.toml` fija sus dependencias. La consulta remota inicial del registro falló
por DNS, pero la resolución local y las ejecuciones finalizaron con código cero.

Carga sintética: 180 bloques, ciclo de 70 tickets, P0+LG. Son fixtures, no parámetros de red.

| Variante | Mediana | Bytes | Asignaciones | Equivalencia |
|---|---:|---:|---:|---|
| Referencia clara | 54.849 ns | 119.384 | 282 | fuente de verdad pequeña |
| Kernel incremental | 14.784,5 ns | 95.952 | 110 | coincide |

Son 100 muestras tras calentamiento. No son rendimiento de nodo ni espera de Cortex.

JET no detectó diagnósticos de optimización en `apply_fast`; `code_warntype` no mostró `Any` y
el retorno inferido fue `ApplyResult`. El pase final perfilado de 20.000 lotes produjo 7.201 entradas
de muestreo; una invocación calentada asignó 96.000 bytes. Estos datos localizan trabajo futuro,
no demuestran que el kernel ya sea óptimo ni justifican C++/CUDA.

La revisión independiente de sistemas no encontró otro bloqueante interno para VRC como contrato
aislado. Sí señaló que el benchmark no mide cierres y que su escaneo del journal puede acumular
`O(K*E)` para `K` ventanas y `E` eventos. Antes de trazas largas hará falta indexación incremental;
la carga irregular de DAG, ramas y colas mantiene C++/CUDA injustificado en esta etapa.

## Límites

No hay fórmula de retarget, rango inicial, `W/W_adm/G`, redondeos económicos, PoAS/PoT,
GHOSTDAG real, UTXO/Orchard, persistencia o red. `unresolved` en fixtures representa un lote DA0
con estado `PendingData`; acredita la transición del modelo, no disponibilidad de red. El journal
y el índice económico permiten detectar divergencia por EventId, pero no prueban que la producción
observada sea insesgada respecto de oportunidades retenidas.

Tampoco se midieron aún colas/bytes por etapa, espera censurada, periodos sin progreso, exclusión
honesta, reinclusión, pagos nunca aceptados, reversión tras aceptación ni divergencia entre
observadores. Esas métricas pertenecen a la siguiente simulación endógena, no a VRC-v0.1.
