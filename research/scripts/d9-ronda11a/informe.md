# Ronda 11a (D9) — `k` con margen frente a `Δ`: cuánto compra y cuánto cuesta

**Fecha:** 2026-09-09 · **Agente:** D9 (auditor matemático) · **Directorio:** `research/scripts/d9-ronda11a/`
**Método:** `research/scripts/METODO-AGENTES.md` (sin presupuesto de tiempo; resultado completo).

**Encargo:** `ENCARGO.md` en este directorio. Pregunta única: **¿cuánta tolerancia a `Δ` compra subir `k`
(o bajar `λ`), y a qué precio?**

**Fuentes leídas antes de tocar nada.** `research/dag-poas-mitigaciones-cuatro-riesgos.md` §1 (M2, M3);
`research/scripts/d9-ronda9a/informe.md` §5.5 y `r9a_a1b_control.py`, `r9a_a3_frontera.py`,
`r9a_a6_frontera_delta.py`, `r9a_lib.py`; `research/scripts/verif_tau_vs_lambda.py`;
`research/dag-poas-delta-real.md` §1-3; `research/scripts/d9-ronda10b/` (`informe`, `r10b_lib.py`,
`r10b_b2_k.py`, `r10b_b5_delta_red.py`, `salida_b2.txt`, `salida_b5.txt`); `research/scripts/verif_frontera_vs_F.py`;
`research/dag-poas-ancla-de-orden.md` §1.1, R-FIN-12 (L177-181), L156, L424 (**no editado**);
`research/fuentes/phantom-ghostdag.txt` L1015-1050 y L1125-1155 (Lema 9 y la ec. de `δ`);
`research/fuentes/dagknight.txt` L92-120 (§1.1: «*the parameter k of PHANTOM represents an upper bound
on the network's latency*»); `/home/katana/zeo/fuentes/rusty-kaspa` @ `c338d495`
(`consensus/core/src/config/bps.rs:1-85`, `consensus/src/processes/ghostdag/protocol.rs:169-283`).

**Instrumentos reutilizados sin reescribir** (regla 11 del método): `r9a_a3_frontera.prev/union10`
(= `d8_a1c_riesgo.py:29-40` = `verif_constantes.py:44-50`), `r10b_lib.{set_F_I,set_ventaja,union_lam,
f_carrera,frontera_gruesa,r_base}`, `r9a_lib.{MundoL9,contabilidad}` y el patrón de medida de
`r9a_a1b_control.py`. Lo único **copiado** (no importado) es `kopt`, de `verif_tau_vs_lambda.py:16-30`,
con `D` y el techo del barrido como parámetros — el original los tenía cableados (`D = 4.0`,
`range(6,80)`) y con `Δ ≥ 20 s` el punto fijo cae fuera de 80. La copia se controla contra el original
en A.1.

---

## B · `k*(Δ)` — el punto fijo del retarget · **VERIFICADO, y con un límite duro que nadie había visto**

**Script:** `r11a_b_kestrella.py` → `salida_b.txt` (75 s). `τ = 1 s`, objetivo del punto fijo:
minimizar la reversión a 600 s con `λ_real` y `δ_real` autoconsistentes.

| `Δ` (s) | `2Δλ` | **`k*` (λ=1)** | `2Δλ/k*` | `λ_real` | `δ_real` | reversión 600 s | padres | `msl` | cabeceras/año |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| **4** | 8 | **29** | 0,276 | 1,381 | 0,2759 | **4,31·10⁻¹⁰** | 15→14 | 180 | 21,5 GB |
| 8 | 16 | 45 | 0,356 | 1,552 | 0,3556 | 8,54·10⁻⁴ | 16 | 180 | 21,5 GB |
| 12 | 24 | 61 | 0,393 | 1,649 | 0,3934 | 2,37·10⁻¹ | 16 | 180 | 21,5 GB |
| 16 | 32 | 78 | 0,410 | 1,696 | 0,4103 | 9,29·10⁻¹ | 16 | 180 | 21,5 GB |
| 20 | 40 | 96 | 0,417 | 1,714 | 0,4167 | **1,00** | 16 | 192 | 21,5 GB |
| 24 | 48 | 113 | 0,425 | 1,738 | 0,4248 | **1,00** | 16 | 226 | 21,5 GB |
| 32 | 64 | 235 | 0,272 | 1,374 | 0,2723 | **1,00** | 16 | 470 | 21,5 GB |

Con `λ = 1/2` (un bloque cada 2 s), `τ = 1 s`:

| `Δ` (s) | `2Δλ` | **`k*` (λ=1/2)** | `λ_real` | `δ_real` | reversión 600 s | padres | cabeceras/año |
|---:|---:|---:|---:|---:|---:|---:|---:|
| **4** | 4 | **15** | 0,682 | 0,2667 | 7,83·10⁻⁶ | 10 | **10,8 GB** |
| 8 | 8 | 24 | 0,750 | 0,3333 | 1,46·10⁻² | 12 | 10,8 GB |
| 12 | 12 | 34 | 0,773 | 0,3529 | 3,63·10⁻¹ | 16 | 10,8 GB |
| 16 | 16 | 43 | 0,796 | 0,3721 | 9,02·10⁻¹ | 16 | 10,8 GB |
| 20 | 20 | 52 | 0,812 | 0,3846 | 9,98·10⁻¹ | 16 | 10,8 GB |
| 24 | 24 | 61 | 0,824 | 0,3934 | 1,00 | 16 | 10,8 GB |
| 32 | 32 | 78 | 0,848 | 0,4103 | 1,00 | 16 | 10,8 GB |

**Lo que dice la tabla, en tres frases.**

1. **`k*(Δ)` es casi lineal en `Δ`:** `k* ≈ 2Δλ/0,41` para `Δ ≥ 8 s`, es decir `k* ≈ 4,9·Δλ`. La comparación a `2Δλ` igual es instructiva y **no** da igualdad en todo el rango: `2Δλ = 24` → 61 y 61, `2Δλ = 32` → 78 y 78 (**iguales**); pero `2Δλ = 8` → 29 frente a 24 y `2Δλ = 16` → 45 frente a 43 (**distintos**). El motivo es que las dos restricciones (`λ_real ≤ 2λ` y el punto fijo de Poisson) sí dependen solo de `2Δλ`, mientras que el objetivo —la reversión en una ventana **de 600 s**— no es invariante de escala: con `λ = 1/2` caben la mitad de bloques en esa ventana. Donde el objetivo satura (`Δ` grande) manda `2Δλ` y las columnas coinciden; donde el objetivo discrimina (`Δ` pequeño), `λ = 1/2` pide **menos** `k` porque su `δ_real` es menor.
2. **El punto fijo se rompe antes que el colchón.** A partir de `Δ ≈ 16 s` con `λ = 1` (y `Δ ≈ 12 s` con `λ = 1/2`) **la reversión a 600 s vale ≈ 1 para el `k*` que el propio criterio elige**, y a `Δ ≥ 20 s` vale exactamente 1 **para todo `k` admisible**. La razón es mecánica y está en el Lema 10 (`phantom-ghostdag.txt` L1200-1206): la ventaja de *freeloading* es **`3k`**, y con `k* = 96` son **288 bloques azules** que la red honesta tendría que remontar en 600 s, cuando su deriva neta en esa ventana es de ~193. **Subir `k` compra tolerancia a `Δ` y se la quita a la confirmación rápida.** La fila `Δ = 32 s`, `k* = 235` es un artefacto de ese empate: todos los `k` admisibles dan reversión 1,00 y `kopt` se queda con el primero que no la supera. **No es un `k` recomendable; es la marca de que ahí el criterio ya no discrimina.** Etiqueta: **REFUTADO** que el punto fijo de `verif_tau_vs_lambda.py` siga siendo un criterio de diseño útil por encima de `Δ ≈ 16 s`.
3. **`k*` de esta tabla NO es el `k` que hay que publicar.** `δ_real` es la **cota del Lema 9** (caso peor del paper, bajo sesgo sostenido del retarget), no una medida. Lo medido a `α = 0` es `δ₀`, y es **mucho menor** (regla 6: cota ≠ realidad). El `k` operativo sale de C, no de B.

**El coste que B sí acota y conviene retener:** `mergeset_size_limit` solo se despega de su suelo de 180 cuando `k > 90` (`bps.rs:75-85`), y `max_block_parents` está **topado en 16** desde `k = 32` (`bps.rs:57-72`). Por eso la columna «cabeceras/año» **no se mueve con `k`**: son 21,5 GB/año a `λ = 1` y 10,8 GB/año a `λ = 1/2`, y lo que las cambia es `λ`, no `k`.

---

## Nota de método — qué se mide y qué se acota

Tres magnitudes distintas que las rondas anteriores han llegado a mezclar, y que aquí se mantienen separadas:

| Magnitud | Qué es | De dónde sale | Etiqueta |
|---|---|---|---|
| `P(Poisson(2Δλ) > k)` | cola de la ec. (1)/(2) del paper | `bps.rs:5-21` (`calculate_ghostdag_k`) | **cota, y floja**: a `Δ=16 s`, `k=30` da 0,594 |
| `δ_real(k)` | merma del Lema 9 bajo sesgo sostenido del retarget | `dag-poas-delta-real.md` §1 | **cota** (caso peor del paper) |
| **`δ₀(Δ, k, λ)`** | fracción de bloques honestos que acaban rojos **con `α = 0`** | **medido**, instrumento de 9a | **VERIFICADO** |

A `Δ = 16 s`, `k = 30`: la cola de Poisson dice 0,594; `δ_real` dice 0,267; **lo medido es 0,286**.
Todo lo operativo de esta ronda (C, E, F) usa **lo medido**.

---

## C.1 · `δ₀(Δ, k, λ)` **medido** — la tabla que faltaba · **VERIFICADO**

**Script:** `r11a_c1_delta0.py` → `salida_c1.txt` + `c1_delta0.json` (3 216 corridas: 18 `Δ` × 7 `k` × 2 `λ`
× 12 semillas, más el control de `α`; 305 s con 30 procesos). Instrumento: el de `r9a_a1b_control.py`
(`MundoL9`, maniobra parásita `J=31`, `u3=dynamic`, ventana `(60, T−60]`), con `k`, `λ` y `Δ` como
parámetros y **con los `max_block_parents` / `mergeset_size_limit` que R-FIN-12 le corresponden a cada
`k`** — subir `k` sin subir el tope de padres sería medir otra cosa.

**Control (A.2):** la columna `k = 30`, `λ = 1` reproduce **cifra a cifra** la tabla de 9a §5.5:
0,0020 / 0,0828 / 0,2858 / 0,4428 / 0,5401 / 0,6526 a `Δ` = 8/12/16/20/24/32 s.

### `δ₀` a `λ = 1` (α = 0, 12 semillas, `ΣR/ΣH`)

| `Δ` (s) | `2Δλ` | `k=30` | `k=35` | `k=40` | `k=45` | `k=50` | `k=55` | `k=60` |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 4 | 8 | 0,0000 | 0,0000 | 0,0000 | 0,0000 | 0,0000 | 0,0000 | 0,0000 |
| 8 | 16 | 0,0020 | 0,0001 | 0,0000 | 0,0000 | 0,0000 | 0,0000 | 0,0000 |
| 10 | 20 | 0,0219 | 0,0041 | 0,0005 | 0,0002 | 0,0000 | 0,0000 | 0,0000 |
| 12 | 24 | 0,0828 | 0,0296 | 0,0084 | 0,0020 | 0,0002 | 0,0000 | 0,0000 |
| 14 | 28 | 0,1873 | 0,0967 | 0,0446 | 0,0152 | 0,0036 | 0,0011 | 0,0003 |
| **16** | 32 | **0,2858** | 0,1905 | 0,1157 | 0,0603 | 0,0248 | 0,0088 | **0,0033** |
| 18 | 36 | 0,3725 | 0,2851 | 0,2060 | 0,1384 | 0,0838 | 0,0416 | 0,0212 |
| **20** | 40 | **0,4428** | 0,3587 | 0,2910 | 0,2219 | 0,1617 | 0,1085 | **0,0684** |
| 24 | 48 | 0,5401 | 0,4803 | 0,4290 | 0,3698 | 0,3128 | 0,2639 | 0,2199 |
| 28 | 56 | 0,6063 | 0,5637 | 0,5194 | 0,4766 | 0,4269 | 0,3875 | 0,3476 |
| 32 | 64 | 0,6526 | 0,6137 | 0,5802 | 0,5478 | 0,5101 | 0,4727 | 0,4441 |
| 40 | 80 | 0,7106 | 0,6834 | 0,6599 | 0,6345 | 0,6101 | 0,5836 | 0,5617 |

**Lo que compra `k`, en una línea:** a `Δ = 20 s`, pasar de `k = 30` a `k = 60` baja `δ₀` de **0,443 a
0,068** — un factor **6,5**. A `Δ = 16 s`, de 0,286 a 0,0033: factor **87**. Pero a `Δ = 32 s` solo baja
de 0,653 a 0,444 (factor 1,5): **`k` compra mucho mientras `2Δλ ≲ 2k`, y deja de comprar en cuanto
`2Δλ` supera a `k`.** El mecanismo es el del `k`-clúster: por encima de `2Δλ ≈ k` el anticono honesto
desborda el presupuesto para cualquier `k` alcanzable.

### `λ = 1/2`: es la misma palanca, no una nueva

La tabla de `λ = 1/2` es la de `λ = 1` **desplazada exactamente un factor 2 en `Δ`**:
`δ₀(Δ=40, λ=½, k=30) = 0,4443` frente a `δ₀(Δ=20, λ=1, k=30) = 0,4428`;
`δ₀(Δ=32, λ=½, k=30) = 0,2869` frente a `δ₀(Δ=16, λ=1, k=30) = 0,2858`. Diferencia máxima **0,0016**
sobre 24 pares (E.1). **`δ₀` depende de `Δ` y `λ` solo por el producto `2Δλ`.** Etiqueta: **VERIFICADO**.
Consecuencia: **bajar `λ` a la mitad tolera exactamente el doble de `Δ`, ni más ni menos** — y por eso
`λ` no es una palanca *adicional* a `k`, es la misma con otro precio (E).

### Cobertura y coste de coloreado (contadores de `r11a_lib.DAGContado`)

Llamadas reales a `blue_anticone_size` (`protocol.rs:229-244`) por bloque, `λ = 1`:

| `Δ` (s) | `k=30` | `k=40` | `k=50` | `k=60` | factor 30→60 |
|---:|---:|---:|---:|---:|---:|
| 4 | 19,5 | 19,5 | 19,5 | 19,5 | **×1,00** |
| 12 | 139,0 | 153,3 | 155,1 | 155,1 | ×1,12 |
| 20 | 240,5 | 309,9 | 392,2 | 455,6 | **×1,89** |
| 32 | 303,0 | 415,6 | 520,8 | ~590 | ×1,95 |

**Donde no hay anticono que colorear (`Δ = 4 s`), subir `k` cuesta exactamente cero.** El coste aparece
solo cuando `Δ` es grande — y ahí ya se está pagando por otro motivo.
