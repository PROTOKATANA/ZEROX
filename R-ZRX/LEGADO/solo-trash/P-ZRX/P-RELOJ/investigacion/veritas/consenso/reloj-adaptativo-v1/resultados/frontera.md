# Frontera del presupuesto de verificación — M1
#
# Generado: 2026-09-24T16:29:44.218
# Máquina: AMD Ryzen 9 9950X3D (Zen 5)
# Hardware medido: lat_ronda=7.369e-10 s, lat_bloque=7.739e-10 s, t_bloque_par=9.603e-10 s, K=8, 4.001 ciclos/ronda, 5.428 GHz
#
# TODOS los parámetros de protocolo de este fichero son ENTRADAS de barrido,
# declaradas como tales. Ninguno es un valor decidido para ZEROX.
#
## 1 · La curva `S_max(ε, K) = ε·K`

`ρ_max = ε·K` es la dispersión MÁXIMA de hardware que admite el presupuesto, con
`ρ := t_s/t_f` = cuántas veces más lenta es la máquina más lenta admitida que la más
rápida. **Es la MISMA cantidad que la frontera `S` y es un TECHO, no un suelo.** La
nomenclatura coincide con `ρ_max = v_A,max/v_ref` de `SPEC.md` §7.3. Y
`ε_min = ρ/K` es el presupuesto mínimo que admite una dispersión `ρ`: **crece con `ρ`**.

| ε | K=4 | K=8 | K=16 |
|---:|---:|---:|---:|
| 0.02 | 0.08 | 0.16 | 0.32 |
| 0.03 | 0.12 | 0.24 | 0.48 |
| 0.05 | 0.2 | 0.4 | 0.8 |
| 0.1 | 0.4 | 0.8 | 1.6 |
| 0.125 | 0.5 | 1.0 | 2.0 |
| 0.2 | 0.8 | 1.6 | 3.2 |
| 0.25 | 1.0 | 2.0 | 4.0 |
| 0.5 | 2.0 | 4.0 | 8.0 |

## 1b · `ε_min = ρ/K`, el presupuesto mínimo por dispersión

| ρ | K=8 | K=16 |
|---:|---:|---:|
| 1.0 | 12.5 % | 6.25 % |
| 1.6 | 20.0 % | 10.0 % |
| 2.0 | 25.0 % | 12.5 % |
| 3.0 | 37.5 % | 18.75 % |
| 4.0 | 50.0 % | 25.0 % |
| 12.0 | 150.0 % | 75.0 % |

## 2 · `N_max` con el hardware medido

`N_max = ε·τ/t_v`. Con `t_v` medido (`verif8.c`: 8 carriles) y `t_v/2` para 16
carriles (`verif16.c`), para varios `τ`. `τ` es ENTRADA.

| τ (s) | N_max con K=8 | N_max con K=16 |
|---:|---:|---:|
| 0.1 (ε=0.1) | 1.04134e7 | 2.08268e7 |
| 0.5 (ε=0.1) | 5.20671e7 | 1.04134e8 |
| 1.0 (ε=0.1) | 1.04134e8 | 2.08268e8 |
| 2.0 (ε=0.1) | 2.08268e8 | 4.16536e8 |
| 6.0 (ε=0.1) | 6.24805e8 | 1.24961e9 |
| 10.0 (ε=0.1) | 1.04134e9 | 2.08268e9 |

## 3 · El techo duro del tipo (`C-POT-04`)

- `u32::MAX` = 4294967295
- mayor múltiplo de 16 que cabe = 4294967280
- `N` que satura el tipo con el hardware medido: 3.3239 s de producción
- `N` que satura el tipo a la latencia del 14900KS citada (4,841 ns/bloque): 20.7919 s
