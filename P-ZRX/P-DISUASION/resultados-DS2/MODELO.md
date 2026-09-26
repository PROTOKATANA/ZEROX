# MODELO — DS-2 · especificación cuantitativa para DS-3

**Qué es esto.** El §3.4 del encargo: variables, fórmulas cerradas, parámetros con rango de
escenario (declarados como **hipótesis** cuando no hay medición) y los casos de comprobación que
el Monte Carlo de DS-3 debe reproducir. Todas las fórmulas vienen de los informes leídos para
`INFORME.md`; ninguna se deriva aquí por primera vez. Etiquetas: **hecho** (medido o citado en
fuente primaria), **derivación** (álgebra sobre hechos), **hipótesis** (sin medir, con rango
declarado).

---

## 1 · Variables y símbolos

| Símbolo | Unidad | Significado | Procedencia |
|---|---|---|---|
| `α` | fracción de espacio | espacio propio del atacante, retirado de la pública | P-PRESTAMO §1 |
| `β_d` | fracción de espacio | espacio honesto que farmea doble (sigue publicando) | P-PRESTAMO §1 |
| `β_x` | fracción de espacio | espacio alquilado en exclusiva (abandona la pública) | P-PRESTAMO §1 |
| `η_h`, `η_a` | adimensional | eficiencia de conversión espacio→peso, pública/privada | P-PRESTAMO §1 |
| `F` (`F_slots`) | slots | ventana de finalidad, `C-FIN-01` | SPEC; P-PRESTAMO §2 |
| `ρ_ret` | fracción | fracción de recompensa retenida como garantía confiscable | P-CLAVE, P-PRESTAMO |
| `T_v` | slots | duración de la maduración/retención del crédito | P-CLAVE, P-PRESTAMO |
| `κ` | [0,1] | fracción del doble farmeo que deja evidencia castigable | P-EQUIVOCACION |
| `q` (`q_gana`) | [0,1] | probabilidad de que la evidencia llegue a la historia seleccionada (no censurada) | P-PRESTAMO §4.1 |
| `V` | u.e. | valor del ataque por reclutado (lo que gana con la trampa) | P-PRESTAMO §4 |
| `N_recl` | conteo | número de granjeros reclutados para alcanzar `β` | P-PRESTAMO §3 |
| `f` | fracción de espacio | tamaño de una clave individual | P-CLAVE |
| `θ = λ f T_v` | adimensional | parámetro de forma de la distribución del saldo confiscable | P-CLAVE §1 |
| `λ` | bloques/slot | tasa de producción de bloques de la red | P-CLAVE, P-INTENTO |
| `w` | slots | ventana de adelanto (retos conocidos por adelantado) | P-SEMBRADOR, P-INTENTO, P-REVELACION |
| `ρ` (reloj) | adimensional | ventaja de reloj del atacante (AES más rápido) | ESTADO-RELOJ, P-REVELACION |
| `r` | tablas/s | tasa de generación de tablas PoS del sembrador | P-INTENTO (medido) |
| `t_tabla` | s | coste de una tabla PoS a 1 núcleo | P-INTENTO (medido) |
| `N_h` | piezas | espacio honesto total, en piezas | P-INTENTO |
| `π_DAG` | [0,1] | fracción de soluciones válidas que terminan pagadas | P-SEMBRADOR, P-INTENTO (símbolo, no medido) |
| `B` | unidades | unidades regenerables por el atacante dentro de la ventana, `B = R·(w·τ+D_a)` | P-COBERTURA F4 |
| `N` (cobertura) | unidades | tamaño del lote auditado | P-COBERTURA |
| `k` (auditoría) | aperturas | número de posiciones abiertas por auditoría | P-COBERTURA, P-REGISTRO-SECTORES |
| `t_reg` | s | coste de regenerar un registro completo para responder una auditoría | S02a (medido) |
| `A` | Wh/byte | constante de electricidad de sellado Filecoin | Pankovska et al. 2024, tabla 5 |
| `B_fil` | W/byte | constante de electricidad de almacenamiento Filecoin | ídem |
| `PUE` | adimensional | eficiencia de uso de energía del centro de datos | ídem |
| `precio_TB`, `precio_nucleo`, `precio_token`, `tipo_interes` | moneda | precios de mercado | **hipótesis**, sin medir en este encargo |
| `q` (garantía), `S_min` | u.e. | requisito mínimo de garantía para producir (`M1`) | P-TRANSICION/CONTRATO-v0 §1 (símbolo) |

---

## 2 · Fórmulas cerradas

### 2.1 · Frontera de deriva (espacio prestado, doble farmeo/alquiler)

```
α*(β_d, β_x, η_h, η_a) = (η_h − η_a·β_d − (η_h+η_a)·β_x) / (η_h+η_a)
```

con `η_h=η_a=1`: `α* = (1 − β_d − 2β_x)/2`. Casos exactos: sin espacio prestado `α*=1/2`; solo
`β_d`: `α*=(1−β_d)/2`, cruce `g>0 ⟺ β_d>1−2α`; solo `β_x`: `α*=1/2−β_x`.
**Fuente:** P-PRESTAMO §1 (`Rational{BigInt}`, 12 filas exactas). **Etiqueta:** hecho (identidad
aritmética del modelo, no del protocolo — no confundir con «el umbral de ZEROX»).

### 2.2 · Probabilidad de ganar dentro de la ventana `F` (paseo aleatorio con déficit)

DP exacta sobre `(mínimo, posición)`, absorción en la primera visita a `−1`:

```
P_first_passage(d, T) = DP exacta (P-PRESTAMO §2, 714 celdas certificadas)
d = (μ_p − μ_a)·F        [déficit inicial en unidades de peso]
```

Caso límite (horizonte largo, sin usarlo para `F` finito): `(q_adv/(1−q_adv))^(d+1)`.
**DS-3 debe implementar la DP, no la forma cerrada**, salvo para `d` fuera de rango `Float64`
(usar el límite exacto marcado `limite_ruina` en P-PRESTAMO).

### 2.3 · Saldo confiscable por clave (retención)

```
θ = λ·f·T_v
E[B]   = ρ_ret·I·θ/2
Var[B] = ρ_ret²·I²·θ/3
P(B=0) = e^{−θ}                    [exacto]
```

**Fuente:** P-CLAVE §1 (M3–M6, 68 controles independientes). **Advertencia obligatoria para
DS-3:** la aproximación normal **no sirve** (sobreestima `P(B=0)` en factor ≈2,3 para `θ∈[0,1]` y
la subestima en factor ≈68 para `θ=10`); usar la fórmula exacta o la DP de la CDF por `m`, nunca
`Normal(E[B],√Var[B])`.

### 2.4 · Coste de reclutar `β` por saldo (retención)

```
B(ε) = M(ε/(λT_v))                         [fracción de espacio en claves con saldo < ε]
C(β) = 0                    si β ≤ B(ε)
     = (β − B(ε))·coef      si β > B(ε),   coef = ρ_ret·λ·T_v/2
```

**Fuente:** P-CLAVE §3 (F2). La curva tiene un **escalón** en `B(ε)`, no un codo suave: DS-3 debe
reproducir el escalón, no interpolar.

### 2.5 · Región `(ρ_ret, T_v)` que disuade sin confiscar al honesto

```
Disuasión:  κ·q·(ρ_ret·I·T_v + c_r + I·M) > V/N
Honestidad: ν·ρ_ret·T_v < 1                    [ν = tasa de reorg, reorgs/slot]
Necesaria:  ν < 1/(V/N − c_r − I·M)
```

**Fuente:** P-CLAVE §6, P-PRESTAMO §5. **Caso de prueba obligatorio:** con `V/N=400`, `c_r=10`,
`M=20`, `I=1`, la región es `ρ_ret·T_v ≳ 4.000` **y** `T_v > F`; con `κq→0`, `q→0` o `V` sin cota,
**la región es vacía** (DS-3 debe reproducir la región vacía exactamente en esos límites).

### 2.6 · `κ` por identidad y régimen (equivocación)

Tabla enumerada exacta (universo finito, 32 piezas × 4 `chunk` + escenario `misma-parcela`):
`κ(C-GD-07, flujo común, m≤0.05)=1.000`; `κ(C-GD-07, m=1)=0.455`; `κ(C-GD-07, m=4)=0.000`;
`κ(flujo divergente)=0.000` para todas las identidades salvo `misma-parcela` con IDV-01/CANDIDATA
(`=1.000`). **Fuente:** P-EQUIVOCACION §1.2 (enumeración exacta, no MC). DS-3 debe tratar `κ` como
**función escalonada de `m`** (soluciones ganadoras esperadas del atacante por slot), no como
constante.

### 2.7 · Coste del sembrador (regeneración bajo demanda)

```
N_eq(máquina, w) = r · w · τ                          [piezas honestas equivalentes]
coste/solución    = (1/(r·w·p) + t_M3) / π_DAG          [s de máquina por bloque PAGADO]
w_equilibrio      = N_h / (r·τ)                        [w donde 1 máquina emula la red entera]
```

con `p ≈ λ/N_h` (calibración del controlador), `t_M3 = 22,99 ms` (camino ganador sin regenerar
tabla). **Fuente:** P-INTENTO §11 (58 controles, kernel validado a 256 bits). **Entradas medidas
que DS-3 debe usar como hechos, no reajustar:** `t_tabla = 809,13 ms/núcleo` (1 hilo); `r = 25,03
tablas/s` (24 hilos, forma C, cota **superior** del atacante con el código publicado); GPU **no
medida** (hipótesis 17×, documentación ajena — usar solo como escenario etiquetado, nunca como
`r` por defecto).

### 2.8 · Imposibilidad de cobertura (frontera cuantitativa)

```
almacenamiento_forzado(N, B) = max(0, 1 − B/N)     si k > B;   0 si k ≤ B
B = R · (w·τ + D_a)
```

**Fuente:** P-COBERTURA §5 (F4, combinatoria exacta, hipergeométrica). **Caso de prueba
obligatorio:** con `N=1.048.480` (1 TiB), `w∈[7.175;8.030]` (sin VDF) o `4.830,6` (con VDF,
`ρ=2,5`), `D_a=60 s`, `r=25,03`: `B≈181.092…202.492`; `k≤181.092` ⇒ **no detectable en absoluto**,
independientemente de `k`. DS-3 debe reproducir el «acantilado» en `k=B`, no una curva suave.

### 2.9 · Coste absoluto del atacante que regenera (cobertura + sembrador)

```
núcleos/TiB continuos     = 117,238                [derivado, P-COBERTURA F4]
razón regenerar/almacenar = 1.524×                 [hipótesis de energía: 65 W/núcleo, 5 W/TiB]
w de cruce de sustitución de hardware (núcleo≈TiB en precio) ≈ 848.160 slots (≈9,8 días)
```

**Advertencia que DS-3 debe conservar:** el cruce de `w` es de **sustitución de hardware**
(cuántas máquinas hacen falta para igualar 1 TiB), **no** un cruce energético: regenerar cuesta
siempre ≈1.524× la energía de almacenar, para cualquier `w` (P-COBERTURA §5.4).

### 2.10 · Modelo de energía Filecoin (hecho, fuente externa)

```
P = (A·SR + B_fil·Cap) · PUE
```

`A ∈ [7,86e-9 ; 1,15e-7] Wh/byte` (media ponderada 2,17e-8); `B_fil ∈ [5,21e-13 ; 1,00e-11] W/byte`
(media 4,16e-12); `PUE ∈ [1,2 ; 1,79]` (media 1,426). **Fuente:** Pankovska, Sai, Vranken, Ransil,
*Electricity Consumption of Ethereum and Filecoin* (2024), tabla 5, leído completo en
`deepseek/DS2/filecoin-electricity.pdf`. Red completa (ago. 2023): 9,39–257,9 MW, media 79,09 MW.
Colateral: *consensus pledge* = `0,30 × oferta_circulante × poder_sector / máx(línea_base,
poder_red)`; *storage pledge* ≈ 20 días de recompensa esperada del sector (spec.filecoin.io,
citado en P-ZRX/P-REGISTRO-SECTORES/investigacion/fuentes-filecoin/INFORME.md y en resultados-DS1).

### 2.11 · Cota de Baig–Pietrzak (impposibilidad, caso de comprobación cruzada)

```
ℓ = ⌈ρ²φ²(1+ε)((1+ε)−1/φ)/ε⌉ + ⌈ρφ²((1+ε)−1/φ)/ε⌉ + 2·⌈log φ / log(1+ε)⌉
```

**Fuente:** arXiv:2505.14891, Teorema 1 (leído completo). **Caso de prueba obligatorio para
DS-3:** con `φ=2, ε=0,01, ρ=4` (los parámetros de la Fig. 1 del artículo), la construcción da
≈1.233 pasos de *bootstrap* + ≈140 de *replot* (verificar que el orden de magnitud coincide con
la figura del artículo; no es una cifra de ZEROX, es una comprobación de que DS-3 implementó bien
la fórmula). **Esta cota NO debe usarse para ZEROX sin adaptar**: presupone PoSpace puro sin PoT
de un solo flujo; ver §5.3 de `INFORME.md`.

### 2.12 · Hashrate del PoW de arranque (hecho, medido en esta máquina)

```
CPU 16 núcleos (reposo)  = 73.789.447 H/s
GPU GTX 1070 (régimen)   = 561.084.507 H/s     [8,19× CPU-32 con carga; 7,6× CPU-16 en reposo]
Energía GPU              = 1,94e-7 J/hash       [109,0 W medidos / 561,1 MH/s]
```

**Fuente:** `P-ZRX/P-POW/REVISION-A10-M1.md` (medido, dos rondas independientes, validación
cruzada CPU↔GPU con volcado de 32 MB idéntico). **GTX 1070 es cota INFERIOR** de una GPU actual
(hardware de 2016); no hay ASIC ni hash alquilable medidos.

---

## 3 · Parámetros de escenario (declarados como hipótesis)

| Parámetro | Rango de escenario | Etiqueta | Justificación |
|---|---|---|---|
| `precio_token` | 3 puntos: bajo/medio/alto (p. ej. ×0,1 / ×1 / ×10 de un valor de referencia arbitrario) | **hipótesis** | ZEROX no tiene mercado; no inventar una cifra puntual |
| `q` (garantía mínima M1) | símbolo, 3 escenarios (bajo/medio/alto respecto de la emisión) | **hipótesis** | `P-ZRX/P-TRANSICION/CONTRATO-v0.md` §1: «forma pendiente» |
| `S_min` | símbolo, igual tratamiento que `q` | **hipótesis** | ídem |
| `tipo_interés` (`r` de `C-inmov = r·K·T`) | 0 % / 5 % / 15 % anual | **hipótesis** | sin fuente en el repositorio; usar rango de mercado cripto observado en 2024-2025 (no verificado aquí) |
| `precio_TB` (disco) | usar el disco de 20 TB de P-CLAVE/P-INTENTO como unidad; barrer ×0,5/×1/×2 | **hipótesis** | no hay precio con fecha verificado en este encargo |
| `precio_núcleo` (CPU) | igual, barrer ×0,5/×1/×2 relativo a `precio_TB` | **hipótesis** | ídem; el cruce de P-COBERTURA §5.4 ya lo trata como razón, reutilizar esa tabla |
| `precio_energía` | usar tabla de Filecoin (A, B_fil, PUE) tal cual, sin adaptar a ZEROX | **hecho** (Filecoin) / **hipótesis** (traslado a ZEROX) | ZEROX no tiene sellado; el sembrador de ZEROX ya tiene su propia cifra de energía (§2.9) |
| `w` (ventana de adelanto) | `[7.175 ; 8.030]` sin VDF; `4.830,6` con segundo VDF (`ρ=2,5`) | **hecho** (medido/derivado en P-REVELACION, sin revalidar) | banda, no punto |
| `ρ` (ventaja de reloj) | `1,01 ; 1,5 ; 2,0 ; 2,5` | **hecho** (parámetros ya usados en P-REVELACION) | reutilizar la misma rejilla para comparabilidad |
| `α` (fracción del atacante) | `0,10 ; 0,20 ; 0,25 ; 0,33 ; 0,40` | **hecho** (rejilla ya usada en P-PRESTAMO/P-CLAVE) | reutilizar |
| `T_v`, `ρ_ret` | rejilla de P-CLAVE §6 (`ρ_ret∈{0,10;0,25;0,50;1,00}`, `T_v` de 1.000 a 100.000 slots) | **hecho** (rejilla ya validada) | no inventar una nueva |
| `ν` (tasa de reorg) | `10⁻⁴ ; 3·10⁻⁴ ; 10⁻³` reorgs/slot | **hecho** (rejilla de P-CLAVE §6) | reutilizar |
| Distribución de tamaños de clave (H3) | Pareto truncada `[10⁻⁸,1]`, exponente `α∈{2,05;2,2;2,5;3,0}` | **hipótesis declarada** (P-CLAVE H3) | sin medición real en ZEROX ni Autonomys |

---

## 4 · Casos que el Monte Carlo de DS-3 debe reproducir (regresión obligatoria)

1. **α\* exacto.** `α*(β_d=0,β_x=0)=1/2`; `α*(β_d=0,34,β_x=0,α=0,33)≈0,33` (cruce). Comparar contra
   `Rational{BigInt}` de P-PRESTAMO, no solo `Float64`.
2. **Ventana `F`.** Con `F=1.019, α=0,33, β_d=0`: `P_first_passage = 9,75·10⁻¹⁰⁸` (no `10⁻¹⁷⁷`,
   que es la cota retirada por defectuosa). Con `F=3.600` la probabilidad debe ser **menor**, no
   mayor (la ventana larga perjudica al atacante).
3. **Retención.** `P(B=0)` exacta con `θ=0,36` → `0,69768`; la aproximación normal da `0,3017`
   (razón 0,432): DS-3 debe alertar si alguna ruta usa la normal.
4. **Grieta de F3 (P-CLAVE).** Con `α=0,33, T_v=3.600, ε=0,01`: `B(ε)=0,675 > 1−2α=0,34` ⇒ grieta
   **SÍ** existe (soborno cero cruza la deriva). Con `T_v=100.000` y el criterio heredado
   `(1−2α)/(1−α)=0,5075`: grieta **NO** (`B=0,369<0,5075`) — DS-3 debe reproducir el cambio de
   signo, no un umbral fijo.
5. **Cobertura.** `N=1.048.480, k=1.000, B=181.092` ⇒ `almacenamiento_forzado` es indiferente a
   `k` (no detectable). Con `k=10⁶` sí hay detección parcial (`φ_γ≈81,9 %`).
6. **Sembrador vs disco.** CPU de 24 hilos iguala un disco de 20 TB en `w≈7,6·10⁵`, **no** en
   miles: DS-3 debe fallar visiblemente si alguna ruta usa `w` de miles como «ataque barato».
7. **Baig–Pietrzak, cruce de fórmula.** Reproducir el Teorema 1 con `φ=2,ε=0,01,ρ=4` (§2.11) como
   prueba de que la implementación de la cota es correcta, **sin** usarla como cifra de ZEROX.

---

## 5 · Lo que este modelo NO fija

Ningún parámetro de consenso (`F_slots`, `q`, `S_min`, `ρ_ret`, `T_v`, `κ`, `ν`, `w`, `ρ_max`) se
fija aquí: todos son símbolos con rango de escenario. El puente espacio→tasa (`H-PUENTE`) **no
existe** en el repositorio; toda cifra que dependa de él (F2/F3 de P-PRESTAMO, F2 de P-CLAVE)
queda condicionada y así debe marcarla DS-3. Los precios de mercado (§3) son hipótesis sin fuente
verificada en este encargo — DS-3 debe mantenerlos como parámetro explícito, nunca como constante
oculta.
