# Dinámica del adaptador — M3
#
# Generado: 2026-09-24T16:29:44.292
# Máquina: AMD Ryzen 9 9950X3D (Zen 5)
# Hardware medido: lat_ronda=7.369e-10 s, lat_bloque=7.739e-10 s, t_bloque_par=9.603e-10 s, K=8, 4.001 ciclos/ronda, 5.428 GHz
#
# TODOS los parámetros de protocolo de este fichero son ENTRADAS de barrido,
# declaradas como tales. Ninguno es un valor decidido para ZEROX.
#
## 1 · Caso conectar/desconectar (hardware alternante)

`N₀ = 200000000`, `τ = 0.1548 s`, hardware 1,6× alternante con
periodo 200 slots y `duty = 0,5`. Rango de `N`: `[1e6, 8e8]`.

| ganancia g | retardo (slots) | trinquete | amplitud ΔN | ΔN/N_max | amplitud analítica | coste verif. máx (s) |
|---:|---:|:---:|---:|---:|---:|---:|
| 0.05 | 1 | no | 74558736 | 0.3728 | 7.45587e7 | 0.1921 |
| 0.05 | 1 | sí | 0 | 0.0 | 0.0 | 0.1921 |
| 0.05 | 5 | no | 74893312 | 0.3745 | 7.48933e7 | 0.1921 |
| 0.05 | 5 | sí | 0 | 0.0 | 0.0 | 0.1921 |
| 0.05 | 50 | no | 771205728 | 0.964 | 7.71206e8 | 0.7682 |
| 0.05 | 50 | sí | 0 | 0.0 | 0.0 | 0.1921 |
| 0.1 | 1 | no | 74998064 | 0.375 | 7.49981e7 | 0.1921 |
| 0.1 | 1 | sí | 0 | 0.0 | 0.0 | 0.1921 |
| 0.1 | 5 | no | 80086032 | 0.391 | 8.0086e7 | 0.1967 |
| 0.1 | 5 | sí | 0 | 0.0 | 0.0 | 0.1921 |
| 0.1 | 50 | no | 796891328 | 0.9961 | 7.96891e8 | 0.7682 |
| 0.1 | 50 | sí | 0 | 0.0 | 0.0 | 0.1921 |
| 0.25 | 1 | no | 75000000 | 0.375 | 7.5e7 | 0.1921 |
| 0.25 | 1 | sí | 0 | 0.0 | 0.0 | 0.1921 |
| 0.25 | 5 | no | 193778848 | 0.6598 | 1.93779e8 | 0.282 |
| 0.25 | 5 | sí | 0 | 0.0 | 0.0 | 0.1921 |
| 0.25 | 50 | no | 799000000 | 0.9988 | 7.99e8 | 0.7682 |
| 0.25 | 50 | sí | 0 | 0.0 | 0.0 | 0.1921 |
| 0.5 | 1 | no | 75000000 | 0.375 | 7.5e7 | 0.1921 |
| 0.5 | 1 | sí | 0 | 0.0 | 0.0 | 0.1921 |
| 0.5 | 5 | no | 778051312 | 0.9726 | 7.78051e8 | 0.7682 |
| 0.5 | 5 | sí | 0 | 0.0 | 0.0 | 0.1921 |
| 0.5 | 50 | no | 799000000 | 0.9988 | 7.99e8 | 0.7682 |
| 0.5 | 50 | sí | 0 | 0.0 | 0.0 | 0.1921 |

## 2 · Escalado del coste cuando el hardware rápido desaparece

La amplitud NO la fija la ganancia sola: la fija `N_max·(1 − (1−g)^k)` con `k`
el número de slots hasta saturar. La fórmula cerrada y la simulación coinciden.
