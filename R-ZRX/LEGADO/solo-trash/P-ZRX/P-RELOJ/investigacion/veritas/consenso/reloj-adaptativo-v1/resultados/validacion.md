# Validación — equivalencia de rutas, invariantes y bordes
#
# Generado: 2026-09-24T16:29:44.466
# Máquina: AMD Ryzen 9 9950X3D (Zen 5)
# Hardware medido: lat_ronda=7.369e-10 s, lat_bloque=7.739e-10 s, t_bloque_par=9.603e-10 s, K=8, 4.001 ciclos/ronda, 5.428 GHz
#
# TODOS los parámetros de protocolo de este fichero son ENTRADAS de barrido,
# declaradas como tales. Ninguno es un valor decidido para ZEROX.
#
## Tabla de casos

La columna `independiente` separa las rutas que calculan por caminos
GENUINAMENTE distintos de las que sólo comprueban una identidad algebraica
(§4.5 del encargo).

| Caso | Vías comparadas | independiente | resultado | detalle |
|---|---|:---:|:---:|---|
| V2 bordes de C-POT-04 | predicado vs tabla del oráculo | sí | OK | 10 casos de borde coinciden |
| V2 techo duro del tipo | N_MAX_TIPO y N_MAX_TIPO+16 | sí | OK | 4 294 967 280 sí, 4 294 967 296 no |
| V2 redondeo a múltiplo de 16 | N_desde_objetivo | sí | OK | N=128700128, (N+16) ya pasa de τ |
| V1 frontera tp=1//1 tv=1//1 K=3 ε=1//3 | Rational{BigInt} vs Float64 | no | OK | mismo veredicto |
| V1 frontera tp=1//1 tv=1//1 K=3 ε=999997//3000000 | Rational{BigInt} vs Float64 | no | OK | mismo veredicto |
| V1 frontera tp=1//1 tv=1//1 K=3 ε=1000003//3000000 | Rational{BigInt} vs Float64 | no | OK | mismo veredicto |
| V1 frontera tp=7//1 tv=3//1 K=8 ε=3//56 | Rational{BigInt} vs Float64 | no | OK | mismo veredicto |
| V1 frontera tp=7//1 tv=3//1 K=8 ε=374999993//7000000000 | Rational{BigInt} vs Float64 | no | OK | mismo veredicto |
| V1 frontera tp=1//1 tv=1//1 K=16 ε=1//16 | Rational{BigInt} vs Float64 | no | OK | mismo veredicto |
| V1 ε_min no depende de τ | frontera con τ = 1, 10⁹, 10⁻⁹ | sí | OK | ε_min idéntico en los tres |
| V1 N_max escala lineal con τ | N_max_exacto | sí | OK | N_max(2τ) = 2·N_max(τ) |
| V3 adaptador g=0.5 retardo=1 escalón | simular! Float64 vs simular_exacto Rational{BigInt} | no | OK | ajustes con signo distinto: 0; discrepancia máxima de N: 16 (se compone en la recurrencia) |
| V3 adaptador g=0.5 retardo=5 escalón con retardo | simular! Float64 vs simular_exacto Rational{BigInt} | no | OK | ajustes con signo distinto: 0; discrepancia máxima de N: 0 (se compone en la recurrencia) |
| V3 adaptador g=0.25 retardo=3 alternante | simular! Float64 vs simular_exacto Rational{BigInt} | no | OK | ajustes con signo distinto: 0; discrepancia máxima de N: 0 (se compone en la recurrencia) |
| V3 adaptador g=0.1 retardo=10 alternante lento | simular! Float64 vs simular_exacto Rational{BigInt} | no | OK | ajustes con signo distinto: 0; discrepancia máxima de N: 80 (se compone en la recurrencia) |
| V4 invariantes trinquete=false caducidad=0 g=0.3 | I1..I5 sobre la traza | no | OK | los cinco invariantes se cumplen |
| V4 invariantes trinquete=true caducidad=0 g=0.3 | I1..I5 sobre la traza | no | OK | los cinco invariantes se cumplen |
| V4 invariantes trinquete=false caducidad=5 g=0.3 | I1..I5 sobre la traza | no | OK | los cinco invariantes se cumplen |
| V4 invariantes trinquete=false caducidad=0 g=0.0 | I1..I5 sobre la traza | no | OK | los cinco invariantes se cumplen |
| V5 cota vs oráculo DP (174 combinaciones) | sesgo_mediana_adversario vs sesgo_mediana_dp | sí | OK | cota inferior respetada; discrepancias contadas: 96 |
| V5 la cota no es exacta | discrepancias > 0 | sí | OK | se declara que es cota inferior, no igualdad |
| V6 frontera_exacta_1_3 | frontera_rapida vs vector | sí | OK | coincide |
| V6 borde_1_3_prevfloat | frontera_rapida vs vector | sí | OK | coincide |
| V6 borde_1_3_nextfloat | frontera_rapida vs vector | sí | OK | coincide |
| V6 frontera_exacta_3_56_K8 | frontera_rapida vs vector | sí | OK | coincide |
| V6 borde_3_56_prevfloat | frontera_rapida vs vector | sí | OK | coincide |
| V6 borde_3_56_nextfloat | frontera_rapida vs vector | sí | OK | coincide |
| V6 frontera_exacta_1_16_K16 | frontera_rapida vs vector | sí | OK | coincide |
| V6 borde_1_16_prevfloat | frontera_rapida vs vector | sí | OK | coincide |
| V6 presupuesto_10_K8 | frontera_rapida vs vector | sí | OK | coincide |
| V6 presupuesto_10_K16 | frontera_rapida vs vector | sí | OK | coincide |
| V6 presupuesto_3_K8 | frontera_rapida vs vector | sí | OK | coincide |
| V6 presupuesto_3_K16 | frontera_rapida vs vector | sí | OK | coincide |
| V6 presupuesto_12p5_K8 | frontera_rapida vs vector | sí | OK | coincide |
| V6 presupuesto_12p5_K16 | frontera_rapida vs vector | sí | OK | coincide |
| V6 dispersion_2x_K8_eps_20 | frontera_rapida vs vector | sí | OK | coincide |
| V6 dispersion_4x_K8_eps_20 | frontera_rapida vs vector | sí | OK | coincide |
| V6 dispersion_4x_K16_eps_25 | frontera_rapida vs vector | sí | OK | coincide |
| V6 dispersion_8x_K8_eps_50 | frontera_rapida vs vector | sí | OK | coincide |

**Total: 39 · OK: 39 · fallos: 0 · de ellos con rutas independientes: 25.**

El recuento sale de ESTE artefacto: es el fichero que se entrega.
