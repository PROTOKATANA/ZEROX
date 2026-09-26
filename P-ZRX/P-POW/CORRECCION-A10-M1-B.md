# CORRECCIÓN A10-M1-B — repetir la escala CPU en reposo

**Fecha:** 2026-09-26. **Director:** Claude. **Ejecutor:** DeepSeek (la parte CPU no necesita GPU).
**Zona:** `/home/katana/zeo/ZEROX/deepseek/A10M1/` (la de la orden original).

**Qué falló:** las cifras CPU de `REVISION-A10-M1.md` se midieron con carga ajena (carga media de ~5 a
~26 durante el tramo): son provisionales.

**Qué hacer:** con el binario ya compilado `cargo-target/release/examples/bench_pow` (no recompiles) y
el mismo método de `correr_cpu_bench.sh` (hilos 1, 2, 4, 8, 16, 32; `taskset`; 5 repeticiones de 10 s),
escribe `correr_cpu_bench_reposo.sh` y su salida `cpu_bench_reposo.log`. **Antes de cada serie de
hilos** lee `/proc/loadavg`: si la carga de 1 minuto es ≥ 1,0, espera en pasos de 30 s (máximo
20 min por serie) y registra cada espera; si no baja, marca la serie «con carga» y sigue. Registra
`uptime` y los 10 procesos con más CPU antes y después de cada serie. Ejecuta el script en segundo
plano (tus llamadas de shell duran como mucho 60 s) y espera a que termine.

**Entrega:** sección «Ronda 3 (CPU en reposo)» al final de `INFORME.md`, con la tabla por repetición,
la media por número de hilos, qué series quedaron «con carga», y la comparación con la ronda 1.
Prohibido Python; nada fuera de la zona; sin git; sin secretos. Presupuesto: 40 min.
