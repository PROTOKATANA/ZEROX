# Respuestas esperadas de los casos sintéticos (cálculo a mano)

Cada caso se escribió a mano en `test/datos/<caso>/`; aquí está la respuesta calculada a mano que
`test/runtests.jl` exige. Los tiempos son enteros de ns; los percentiles son nearest-rank
(`rango = ceil(p·n/100)`). El caso (a) es v1; el (f) es v0.

## (a) `caso-a` — 3 nodos P,Q,R; 5 bloques

Producciones: P→h1@1000, h4@4000; Q→h2@2000, h5@5000; R→h3@3000.
Admisiones: h1 Q@1100 R@1200; h2 P@2050 R@2100; h3 P@3100 Q@3200; h4 Q@4300 R@4400; h5 P@5500 R@5600.

| Par | muestras | p50 | p95 | máx |
|---|---|---:|---:|---:|
| P→Q | 100, 300 | 100 | 300 | 300 |
| P→R | 200, 400 | 200 | 400 | 400 |
| Q→P | 50, 500 | 50 | 500 | 500 |
| Q→R | 100, 600 | 100 | 600 | 600 |
| R→P | 100 | 100 | 100 | 100 |
| R→Q | 200 | 200 | 200 | 200 |
| total | 10 valores | 200 | 600 | 600 |

Derivadas: `t_admision_ns` n=10 todos 100; `padres_por_bloque` n=15 todos 1;
`bloques_por_slot` n=5 (slots 1..5, 3 eventos cada uno) todos 3; `fraccion_rojos` =
15 rojos / (30 azules + 15 rojos) = 1/3; `estado_final_igual` no medido (sin `cambio_punta`).

## (b) `caso-b` — bloque no admitido

P produce hA@1000 y hB@2000; Q admite hA@1100; R admite hA@1150 y hB@2200.

- P→Q: producidos=2, admitidos=1, no_admitidos=1, n=1, p50=p95=máx=100.
- P→R: n=2, muestras 150 y 200, p50=150, p95=máx=200.
- Q→* y R→*: sin producciones propias, n=0.

## (c) `caso-c` — latencia negativa

P produce hX@5000; Q lo "admite" @4900. P→Q: n=1, negativos=1, p50=p95=máx=−100. Entra en los
percentiles (no se descarta).

## (d) `caso-d` — divergencia de duración conocida

P: A@0, B@100, C@500, `parada`@1200. Q: A@0, B@300, C@800, D@1000, `parada`@1100.
Intervalo común [0, 1100). Divergencia: [100,300) = 200 ns y [500,800) = 300 ns; desde 1000 hasta 1100
sin reconverger = 100 ns (truncada). Total 600/1100. Episodios: `(100,200,no)`, `(500,300,no)`,
`(1000,100,sí)`. Estado final: ambos terminan en el resumen `…f` ⇒ igual.

## (e) `caso-e1` (última línea truncada) y `caso-e2` (truncada en medio)

- e1: la tercera línea de P está cortada; se tolera ⇒ `lineas=3`, `truncadas=1`; latencia P→Q = 1100−1000
  = 100.
- e2: la segunda línea de P está cortada y hay una tercera válida; debe abortar con `ErrorRegistro`
  en la **línea 2**.

## (f) `caso-f` — v0 sin `version_esquema`

P: `arranque inicio`@0, `cambio_punta` A@0, `arranque limpio`@500, `cambio_punta` B@100,
`bloque_minado` h0@600, `parada`@1000.
Q: `arranque inicio`@0, `cambio_punta` A@0, `arranque limpio`@400, `bloque_red_admitido` h0@700,
`cambio_punta` B@200, `parada`@900.

- v0 (ningún `arranque` trae `version_esquema`).
- Latencia P→Q = 700−600 = 100.
- Divergencia: intervalo [0, 900); divergen [100,200) ⇒ 100/900. Episodio `(100,100,no)`.
- `arranque_ns`: P 500, Q 400 ⇒ n=2, p50=400, p95=máx=500.
- `t_admision_ns`: n=0, ausentes=1 (campo v1 ausente).

## (g) `caso-g` — cobertura v1 (tramos, rechazos, reorg, reinicio)

Un nodo P: 4 `bloque_red_admitido` con `n_bloques_dag` 499/500/999/1000 y `t_admision_ns` 10/20/30/40;
2 `bloque_red_rechazado` (etapa `cabecera`, motivo `m1`, coste 100 y 300) y 1 (etapa `admision`,
motivo `m2`, sin coste); `cambio_punta` con `profundidad_reorg=1`; `reorganizacion_pow` con
`profundidad=3`; `reinicio_completo` con `duracion_ns=1234`.

- Tramos: `[0,499]` n=1 v=10; `[500,999]` n=2 p50=20 p95=máx=30; `[1000,1499]` n=1 v=40.
- Etapas: `t_cabecera`, `t_persistencia`, `t_total` n=4.
- Rechazos: `("cabecera","m1")` n=2 p50=100 p95=máx=300; `("admision","m2")` n=1, percentiles missing.
- `profundidad_reorg`: {1,3} ⇒ n=2 p50=1 p95=máx=3.
- `duracion_reinicio_ns`: n=1, 1234.
- `bloques_por_slot`: slots 1..4, uno cada uno ⇒ n=4 p50=máx=1. `fraccion_rojos` = 0/(4+0) = 0.
- Un solo nodo: `latencias` vacío y `estado_final_igual` no medido.

## `caso-recursos` — CPU/RSS/E-S/disco

`EJECUCION.txt` con `CLK_TCK=100`. CSV de P (cabecera + 3 filas): ticks (10,5), (30,10), (60,20);
rss 1000, 2000, 1500; read 0, 100, 300; write 0, 50, 150; disco 4096, 8192, 8192.

- `cpu_util` (Δtics/CLK_TCK/Δt): (40−15)/100 = **0.25** y (80−40)/100 = **0.40** ⇒ n=2, p50=0.25,
  p95=máx=0.40.
- `rss_kib`: {1000,1500,2000} ⇒ n=3, p50=1500, p95=máx=2000.
- `read_bytes_intervalo`: {100,200} ⇒ n=2, p50=100, p95=máx=200.
- `write_bytes_intervalo`: {50,100} ⇒ n=2, p50=50, p95=máx=100.
- `disco_datos_bytes`: último = 8192.
