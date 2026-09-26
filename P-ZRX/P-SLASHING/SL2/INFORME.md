# INFORME — SL-2 · Calibración del castigo: disuadir al que recluta sin castigar al honesto

> Incluye **SL-2b**: recalibración con la recompensa de 2/8 a quien incluye la evidencia (§9).

**ID:** SL-2 (y SL-2b). **Fecha:** 2026-09-26. **Director:** Claude. **Ejecutor:** DeepSeek (Julia).
**Zona:** `P-ZRX/P-SLASHING/SL2/`. **Entradas congeladas:** `ENTRADA-SL2.sha256` (8/8) y
`ENTRADA-SL2b.sha256` (5 entradas). **Nota de integridad:** al arrancar, SL-2b verificó 5/5; durante
la ejecución, Katana actualizó `DECISIONES.md` (18:40:32) llenando **DS-L04** (pasó de `Pendiente`
a la opción C, identidad con `consensus_branch_id`). **DS-L03 — base de SL-2b — no cambió**; el
cambio no afecta a ningún número de este informe y está fuera de la zona escribible.
**Base:** modelo ratificado de DS-3 (`resultados-DS2/MODELO.md`, `DS3/src/`) con la corrección de
`REVISION-DS3.md` (la región de retención es `ρ_ret·T_v > V/N − c_r − I·M`), sin castigo
correlacionado (`REVISION-DS5.md`), y reparto de espacio de DS-6 (`farmers-raw.csv`, corrección A de
convención) como caso central y la Pareto de H3 como pesimista.
**Faltas de definición:** `DEFINICIONES-FALTANTES.md` (F1–F10) y
`DEFINICIONES-FALTANTES-SL2b.md` (G1–G6), escritas **antes** de tocar código.

---

## 1 · Pregunta falsable y veredicto

> «Para una tasa de doble firma accidental del honesto `ε_h ≤ 10⁻³` por año (con firmante seguro),
> ¿existe una región de parámetros no vacía en la que el reclutamiento para `α_atacante ∈ [0.20,0.40]`
> no compensa y la pérdida esperada del honesto es ≤ 1 % de su ingreso anual?»

**Veredicto: SÍ, con dos precisiones que lo acotan.**

| Caso de reparto del espacio | ¿Región no vacía? | `T_v` mínimo que disuade (peor punto `α=0.40`, `V=10⁵`) | Cierre del borde inferior |
|---|---|---|---|
| **Empírico DS-6** (pool real, `B_emp≈1,8·10⁻⁴`) | **SÍ**, en todas las celdas con `ε_h ≤ 10⁻³` | `2,6·10³` slots | `A` (disuasión) o viabilidad `T_v>F` |
| Pareto H3 `α_dens=2,05` | SÍ | `6,7·10⁴` slots | `A` |
| Pareto H3 `α_dens=2,2` | SÍ | `4,7·10⁵` slots | `A` |
| Pareto H3 `α_dens=2,5` | SÍ (`ε_h≤10⁻³`); **NO** con `ε_h≥10⁻²` | `7,4·10⁵` slots | `A` |
| Pareto H3 `α_dens=3,0` | SÍ (`ε_h≤10⁻³`); **NO** con `ε_h≥10⁻²` | `8,6·10⁵` slots | `A` |

- **Caso central (el único dato real de reparto, DS-6):** la grieta de reclutamiento gratuito está
  cerrada para los cuatro `α` (el `B` empírico es `≈10⁻⁴`, dos órdenes por debajo del umbral
  `1−2α`), y la región es no vacía con márgenes grandes incluso con `f=0,25`. **La pregunta queda
  confirmada.**
- **Caso pesimista (Pareto H3, sin respaldo según DS-6):** a `T_v=3600` la grieta **sigue abierta**
  (`B≈0,25–1,0 ≥ β_d`), así que el castigo no muerde; la región solo se abre con retención **larga**
  (`T_v≈5·10⁴` a `9·10⁵` slots, `1,2 h` a `10,4 días`). **La pregunta también se confirma**, pero
  condicionada a un `T_v` grande; sin él, se refuta.
- **Se refuta** cuando el honesto es una clave **muy pequeña** (`f_h ≲ 10⁻⁵`): la garantía M1 `q_g`
  por identidad (no por espacio) hace que `ε_h·L` supere el 1 % de un ingreso anual minúsculo. Es la
  regresividad de M1 ya señalada en DS-3 A4, ahora cuantificada.

**Qué restricción cierra cada borde** (fórmulas cerradas en `region_tv`, `src/modelo.jl`):

- **Borde inferior — disuasión `A`:** `N_paid · κ · q_ev · L > V`, con
  `N_paid = max(0, β_d − B(ε_eff))/f_media` y `L = f·(ρ_ret·I·T_v^eff + q_g) + c_r`. Si ya se cumple
  en `T_v=F`, el borde lo cierra la **viabilidad de contrato `T_v>F`**.
- **Borde superior — honestidad `B`:** `ε_h·L ≤ frac_max·ingreso_anual(f_h)`.
- La **grieta** es el caso extremo del borde inferior: si `B(ε_eff) ≥ β_d` en todo el intervalo
  permitido por `B`, `A` nunca se cumple y la región es vacía.

---

## 2 · Método

1. **Modelo.** Se reutiliza el modelo ratificado de DS-3 sin reabrirlo: `α*`, DP de primera pasada,
   retención `θ=λfT_v`, `B(ε)=M(ε/(λT_v))`, coste de reclutamiento por escalón y región de disuasión.
   Se incorporan `f` (fracción confiscada), `R_slots` y la condición de honestidad de la orden
   (resolución F1–F4). La corrección de `REVISION-DS3` fija la región de retención en
   `ρ_ret·T_v > V/N − c_r − I·M` (no «≳ 4.000»).
2. **Fórmulas cerradas y Monte Carlo independiente.** La región se resuelve con las expresiones
   anteriores y un `T_v` por búsqueda monótona; el Monte Carlo (`StableRNGs`, semillas derivadas no
   consecutivas) comprueba el paseo, la retención, el `B` empírico (bootstrap), el `B` de la Pareto
   (muestreo directo) y la pérdida anual del honesto (Poisson). Coinciden (tabla §5).
3. **Barrido.** `α ∈ {0,20;0,25;0,33;0,40}`, `P* ∈ {10⁻⁶;10⁻³;0,5}`, `V ∈ {10²…10⁶}`,
   `f ∈ {0,25;0,5;1}`, `ρ_ret ∈ {0,10;0,25;0,50;1,00}`, `q_g ∈ {20;100;1000;10⁴}`,
   `ε_h ∈ {10⁻⁴…10⁻¹}`, `f_h ∈ {10⁻⁶;10⁻³;10⁻¹}`, `R_slots ∈ {0;F;2F}`, y los cinco repartos.
   Todo parámetro sale de `escenarios.tsv` con su etiqueta (hecho/derivado/hipótesis/condicionado).
4. **Rendimiento.** Kernel tipado, sin `@fastmath`/`@simd`/`Float32`, `B` empírico por búsqueda
   binaria (0 B asignados) y memoización de `β_d(α,P*)`. Benchmark y escalado en la §6.

**Prohibido Python:** todo el cálculo es Julia 1.13.0 (juliaup 1.22.7) con
`JULIA_DEPOT_PATH` dentro de la zona.

---

## 3 · Resultados de la región

### 3.1 · Caso central — empírico de DS-6

- `B(ε=0,01; T_v=3600) = 1,78·10⁻⁴` `[1,49·10⁻⁴; 2,08·10⁻⁴]` (bootstrap 5000), idéntico a
  `CORRECCION-DS6-A` (§A.3). Con `T_v=10⁵` cae a `5,8·10⁻⁷`.
- Para `ε_h ≤ 10⁻³`: **2880/2880** celdas con región no vacía en la rejilla principal
  (`region.csv`), para todo `V ≤ 10⁶`, `f`, `q_g` y `P*`. El borde inferior es `F` (viabilidad) en
  la mayoría de celdas suaves y `A` cuando `ρ_ret` es pequeño o `V` grande; el superior es siempre
  `honesto`.
- Únicas celdas vacías del caso central: `ε_h=10⁻¹` **y** `q_g=10⁴` (480 celdas, cerradas por
  honestidad), más 40 celdas de `V=10⁶` con `ρ_ret` alto. Es decir, **sin firmante seguro y con
  garantía alta, la honestidad es el límite**; con firmante seguro, no.

### 3.2 · Caso pesimista — Pareto H3

- La grieta depende del exponente: con `α_dens=2,05` está cerrada a `T_v=3600` para `α≤0,33` y
  abierta solo para `α=0,40`; con `α_dens≥2,2` está abierta a `T_v=3600` para todo `α`, y con
  `α_dens≥2,5` también a `T_v=10⁵` (`grieta.csv`).
- Por eso la región se abre solo a `T_v` grande. `T_v_min` en el peor punto (`α=0,40`, `P*=10⁻³`,
  `V=10⁵`, `f=1`, `q_g=20`, `ε_h=10⁻³`): `6,7·10⁴ / 4,7·10⁵ / 7,4·10⁵ / 8,6·10⁵` slots para
  `α_dens = 2,05 / 2,2 / 2,5 / 3,0`.
- El `T_v` admisible por honestidad es enorme (`≈3·10⁶` slots con `ε_h=10⁻³`, `ρ_ret=0,1`), así que
  la región es no vacía incluso en el caso pesimista; pero con `ε_h=10⁻²` o `10⁻¹` y `α_dens≥2,5`
  el tope de honestidad cae por debajo del `T_v` necesario y la región se vacía.
- **Sensibilidad `P2` (corrección de unidades F5):** el veredicto no cambia (región no vacía),
  pero la cota de honestidad es mucho más laxa (el saldo retenido por clave es pequeño), de modo
  que `T_v` puede llegar a `≈10⁷`. La ambigüedad de unidades **no** invierte el signo.

### 3.3 · Regresividad y otras sensibilidades

- `f_h=10⁻⁶` → región **vacía en todos los casos**: la garantía por identidad domina el ingreso de
  una clave diminuta (`sensibilidad-fh.csv`). `f_h=10⁻³` y `f_h=10⁻¹` dan región no vacía salvo
  `ε_h=10⁻¹` con `q_g=10⁴`. Es un aviso para SL-1: una garantía **por identidad** es regresiva; una
  **por unidad de espacio** eliminaría esta celda.
- `R_slots>0` baja `T_v_min` (el saldo sigue expuesto) y apenas baja `T_v_max`: solo refuerza la
  disuasión, nunca abre la región (`sensibilidad-R.csv`).
- `f=0,25` multiplica por ~4 el `T_v_min` respecto de `f=1` (porque `L` cae con `f`), pero sigue
  habiendo región.

---

## 4 · Recomendación de valores de desarrollo (NO son parámetros de producción)

Etiquetada como tal en `recomendacion-dev.csv`. Punto más duro calibrado: `α=0,40`, `P*=10⁻³`,
`V=10⁵`, `f=1`, `q_g=20`, `ε_h=10⁻³`, `f_h=10⁻³`.

| Perfil | `f` | `ρ_ret` | `T_v` | `R_slots` | `q_g` | Cubre |
|---|---:|---:|---:|---:|---:|---|
| **Primario** (reparto medido DS-6) | 1,0 | **0,10** | **100 000** slots (≈1,16 d) | `≥F=1019` | 20 u.e. | `α∈[0,20;0,40]`, `V≤10⁶`, `P*≤10⁻³`, `ε_h≤10⁻³` |
| **Robusto** (seguro contra H3) | 1,0 | **0,25** | **900 000** slots (≈10,4 d) | `≥F` | 20 u.e. | los cinco repartos, mismo punto duro |

Notas obligatorias: son valores **de desarrollo**, no de producción; `T_v` se mide en slots de 1 s
(`SLOT_DURATION=1000 ms`); el perfil robusto es un **seguro** contra H3, que DS-6 dejó **sin
respaldo**; y **el firmante seguro es lo que hace posible el perfil primario** — sin él
(`ε_h=10⁻¹`) con `q_g=10⁴` la región se vacía por honestidad.

---

## 5 · Validación y Monte Carlo

`Pkg.test()` en verde: **97/97** (`test/runtests.jl`; 39 de SL-2 + 58 de SL-2b, §9.5). `run.jl`
revalida lo mismo en `RESUMEN.txt`.

| Comprobación | Resultado | Error / IC |
|---|---|---|
| DP `(mínimo,posición)` vs DP absorbente exacta vs enumeración (`816` celdas) | coinciden | `≤9,99·10⁻¹⁶` |
| `paso + interior = 1` | invariante | `≤1·10⁻¹⁵` |
| `α*` exacto (12 filas) | `g(α*)=0` | `1,1·10⁻¹⁶` |
| Checkpoint DS-3 `B(0,01;3600;α=2,2)` | `0,675466` | exacto |
| `B` cerrada vs cuadratura numérica (`α=2,05/2,5/3,0`) | coinciden | `<1,1·10⁻⁵` |
| `B` empírico directo vs bootstrap (5000) | contiene | `1,78·10⁻⁴` en `[1,49;2,08]·10⁻⁴` |
| MC paseo (20000) vs DP | DENTRO | — |
| MC retención vs `e^{−θ}` | DENTRO | — |
| MC `B` Pareto (`α=2,05` y `3,0`) | DENTRO | — |
| MC honesto (20000) vs `ε_h·L` | DENTRO (3 EE) | — |

---

## 6 · Rendimiento y reproducibilidad (LINEO §6, §7)

| Variante | Tiempo | Asignaciones | Hilos | Resultado frente a referencia |
|---|---:|---:|---|---|
| Oráculo DP `(mínimo,posición)` | 579,7 ms | 6 / 7,6 MB | 1 | fuente de verdad |
| Kernel DP absorbente | 0,470 ms | 6 / 22 kB | 1 | igual (816 celdas) |
| `β_d` por bisección (40 it.) | 16,4 ms | 258 / 759 kB | 1 | validado vs DP certificada |
| `B` empírico (binaria, 2453) | 0,007 µs | 0 | 1 | igual al directo |
| `region_tv` (celda) | 0,048 µs | 0 | 1 | fórmulas cerradas |
| MC ventana 2·10⁵ reps | 19,55 ms | 23 | 4 | DENTRO del IC; 3,86× (96,6 %) vs 1 hilo |
| `run.jl` completo (57 600+ filas) | **2,39 s** | — | 4 | reproducible, semilla `0x5a5a` |

Mejora medida: `run.jl` pasó de **66,0 s a 2,39 s** al memoizar `β_d(α,P*)` (12 pares recalculados
miles de veces) — LINEO §2: eliminar trabajo redundante antes de paralelizar. `OPENBLAS_NUM_THREADS=1`
(un solo dueño de los núcleos). Sin `@fastmath`, `@simd` ni `Float32` que decidan un veredicto.

**Comando reproducible:**

```bash
export PATH=/home/katana/torio/.juliaup/bin:$PATH
export JULIA_DEPOT_PATH="$PWD/.julia-depot:/home/katana/.julia"
cd /home/katana/zeo/ZEROX/P-ZRX/P-SLASHING/SL2
JULIA_NUM_THREADS=4 OPENBLAS_NUM_THREADS=1 \
  env -u LD_LIBRARY_PATH julia --project=. --threads=4,0 run.jl --seed 0x5a5a --reps 20000
JULIA_NUM_THREADS=4 OPENBLAS_NUM_THREADS=1 \
  env -u LD_LIBRARY_PATH julia --project=. --threads=4,0 test/runtests.jl
```

---

## 7 · Alcance, reservas y lo que SL-2 no decide

1. **El empírico de DS-6 es un pool, no la red** (sesgo declarado en DS-6 A.5): solo cuenta el
   espacio pequeño observado dentro del pool; es cota inferior de `B(ε)`. Aun así, para abrir la
   grieta haría falta que el espacio pequeño fuera del pool superara en >10³ veces al del pool.
2. **H3 (Pareto) no tiene respaldo** (DS-6): el exponente medido (`α_dens≈1,11–1,86`) cae fuera del
   rango `[2,05;3,0]`. Por eso el caso central manda y el pesimista es seguro.
3. **Ambigüedad de unidades F5** (¿`ρ_ret·I·T_v` por clave o por unidad de espacio?): se publican
   `P1` (fiel a DS-3) y `P2`; el veredicto no cambia, cambia la escala de `T_v`.
4. **`f` no está definida en el modelo** (F1): se adopta `f` escalando saldo+garantía y se barre; la
   región existe para `f≥0,25`.
5. **`R_slots` no está en el modelo** (F3): se adopta `T_v^eff=T_v+R_slots`; es monótono.
6. **Precios y `V`:** no hay mercado; `V` es parámetro explícito y el cociente de honestidad es
   adimensional, así que no depende de un precio.
7. **No decide** la forma del contrato (`EvidenceTx`, plazos, deduplicación), ni el destino de los
   fondos, ni la viabilidad de SL-1 `R_slots>F+margen`. Eso es de SL-1.

---

## 8 · Artefactos de la zona

```
SL2/
├── DEFINICIONES-FALTANTES.md       F1–F10 (antes de código)
├── DEFINICIONES-FALTANTES-SL2b.md  G1–G6 (antes de editar SL-2b)
├── INFORME.md                      este documento
├── Project.toml Manifest.toml      entorno congelado (Julia 1.13.0)
├── escenarios.tsv                  parámetros con etiqueta y barrido
├── datos/farmers-raw.csv           copia congelada de DS-6 (sha256 a18b7738…fdd18)
├── src/{SL2,modelo,referencia,rapido,validacion}.jl
├── test/runtests.jl                Pkg.test() 97/97
├── bench/benchmarks.jl
└── resultados/
    ├── comprobaciones.csv beta-d.csv Beps-escenarios.csv grieta.csv
    ├── region.csv (57 600 filas) frontera-central.csv
    ├── sensibilidad-P2.csv sensibilidad-R.csv sensibilidad-fh.csv
    ├── monte-carlo.csv recomendacion-dev.csv
    ├── region-s2.csv (230 400 filas; P1 y P2) resumen-s2b.csv celdas-perdidas-s2b.csv
    ├── frontera-central-s2.csv recomendacion-dev-s2.csv
    ├── censura-s2b.csv comprobaciones-s2b.csv
    ├── BENCH.txt RESUMEN.txt
    └── HUELLAS.sha256
```

Presupuesto declarado (LINEO §7): 4 hilos, 8 GiB de RAM, 256 MiB de disco; usado ≈2,4 s de pared y
<1 GiB. Estado: **completo** (no inconcluso).

---

# 9 · SL-2b · Recompensa al incluidor (`s = 2/8`): recalibración con DS-L03

**Orden:** `ORDEN-SL2b-RECOMPENSA.md`. **Faltas de definición:** `DEFINICIONES-FALTANTES-SL2b.md`
(G1–G6), escritas antes de tocar código. **Decisión:** `DECISIONES.md` DS-L03 — **2/8** de lo
confiscado a la coinbase del bloque que aplica la `EvidenceTx`, 6/8 quemado (Katana fijó 3/8 y lo
corrigió a 2/8 el mismo día; 3/8 se publica **solo como sensibilidad**).

## 9.1 · Qué cambia en el modelo

- **Símbolo.** El `f·V` de la orden es la **parte confiscable** `C = f·(retenido + q_g)` del modelo
  SL-2 (EV-19 de SL-1), **no** el `V` de SL-2 (valor del ataque): la colisión se resuelve llamando a
  la base `parte_confiscable` (G1). El premio al incluidor es `s·C`; se quema `(1−s)·C`.
- **Dos atacantes (G3).** *No confabulado*: pérdida por reclutado `L_no = C + c_r`, idéntica a SL-2
  (no depende de `s`). *Confabulado*: recupera `s` de `C` vía la coinbase de quien incluye,
  `L_conf = (1−s)·C + c_r`, y su umbral de saldo «gratis» pasa a `x = ε/((1−s)·f·λ·T_v^eff)`. El
  **borde superior de honestidad no cambia**: el honesto accidental no es confabulado y usa `L_no`.
- **Autodenuncia (orden §1).** Comprobada en `comprobaciones-s2b.csv`: el infractor que incluye su
  propia prueba pierde `C − s·C + c_r = (1−s)·C + c_r > 0`; con `C = f·V > 0` y `s < 1` nunca es
  rentable (con `s=2/8`, `c_r=10`, `C=1820`: pierde `1375 > (1−s)·C = 1365`). `Pkg.test()` lo cubre.
- **Inclusión y censura (G4).** `q_ev(c) = 1 − c^n`: `c=0` ⇒ inclusión segura (hipótesis de la
  orden), `c=1` ⇒ censura total, `n=1` (lectura conservadora) y `n=F_slots=1019` (ventana).

## 9.2 · La región y las celdas que se pierden

Con `s=2/8`, el atacante **no confabulado reproduce exactamente la región de SL-2** (mismos
artefactos) en las dos lecturas de unidades P1/P2. El confabulado pierde celdas en las esquinas
duras (borde inferior `A`, que ahora exige más `T_v`):

| Reparto | Vía | Celdas con región (de 11 520) | Celdas perdidas |
|---|---|---:|---:|
| **Empírico DS-6** | P1 | 10 960 (vs 11 000) | **40** |
| **Empírico DS-6** | P2 | 10 960 (vs 11 000) | **40** |
| Pareto 2,05 | P1 | 9 731 (vs 9 893) | 162 |
| Pareto 2,05 | P2 | 10 760 (vs 10 840) | 80 |
| Pareto 2,2 | P1 | 6 671 (vs 6 991) | 320 |
| Pareto 2,2 | P2 | 10 760 (vs 10 840) | 80 |
| Pareto 2,5 | P1 | 4 952 (vs 5 318) | 366 |
| Pareto 2,5 | P2 | 10 759 (vs 10 840) | 81 |
| Pareto 3,0 | P1 | 4 432 (vs 4 680) | 248 |
| Pareto 3,0 | P2 | 10 759 (vs 10 840) | 81 |

- **Las 40 celdas empíricas perdidas** tienen todas `ε_h = 10⁻¹` (sin firmante seguro), `V = 10⁶`,
  `α = 0,40`, `f ∈ {0,25;0,5;1}` y las cuatro `ρ_ret`, en P1 y P2 por igual. **Con firmante seguro
  (`ε_h ≤ 10⁻³`) el caso central no pierde ninguna celda** (el borde inferior sube un factor ≈1,36,
  muy por debajo del `T_v` disponible). Detalle en `celdas-perdidas-s2b.csv`.
- El Pareto pierde más celdas en P1 porque su grieta es mayor y `A` necesita `L` completo; en P2 la
  parte confiscable está dominada por `q_g` (constante), el rebote `s` pesa menos en proporción y
  caen menos celdas. En ninguna lectura se invierte el signo: la región sobrevive.

## 9.3 · Valores recomendados para la red dev (NO producción)

Punto duro `α=0,40`, `P*=10⁻³`, `V=10⁵`, `f=1`, `q_g=20`, `ε_h=10⁻³`, `f_h=10⁻³`, cubriendo los
cinco repartos y cada lectura de unidades:

| `s` | Vía | Atacante | `ρ_ret` | `T_v` (peor caso) | `T_v` redondeado |
|---|---:|---|---:|---:|---:|
| 0 (control = SL-2) | P1 | no confabulado | 0,25 | 858 856 | **900 000** |
| 2/8 | P1 | no confabulado | 0,25 | 858 856 | **900 000** |
| **2/8 (ratificado)** | **P1** | **confabulado** | **0,25** | **1 145 140** | **1 200 000** (≈13,9 d) |
| 3/8 (descartado) | P1 | confabulado | 0,10 | 1 375 290 | **1 400 000** (≈16,2 d) |
| 0 | P2 | ambos | 1,00 | 1 352 340 | **1 400 000** |
| **2/8** | **P2** | **confabulado** | **1,00** | **1 816 450** | **1 900 000** (≈22,0 d) |
| 3/8 (descartado) | P2 | confabulado | 1,00 | 2 187 740 | **2 200 000** (≈25,5 d) |

- **El perfil primario de SL-2 no cambia** para el caso central medido en P1: `ρ_ret=0,10`,
  `T_v=10⁵` cubre al confabulado con `T_v^min = 3 512` slots (vs `2 584` sin connivencia; ×1,36).
- **Con la lectura P2 (saldo por clave, más pequeña)** el `T_v` robusto es mayor en todas las
  variantes (`ρ_ret=1,0`, `1,4·10⁶` sin `s` y `1,9·10⁶` con `s=2/8`), pero el veredicto no cambia:
  la región existe. **El perfil robusto P1 sube de 900 000 a 1 200 000 slots** con `s=2/8`, y a
  1 400 000 con `s=3/8`: es el coste de mantener la disuasión cuando el infractor comparte `s`.

## 9.4 · Censura de la evidencia (barrido de `c`)

`censura-s2b.csv` (punto duro, `ρ_ret=0,25`, `s=2/8`):

- Con `n=1` (una sola oportunidad), `q_ev = 1−c` y el `T_v^min` del confabulado crece con `c`
  (empírico: 1 414 → 15 226 slots de `c=0` a `c=0,9`); a `c=1` la región se vacía (`q_ev=0`).
- Con `n=F_slots=1019` (ventana de admisión), `q_ev ≈ 1` para todo `c<1` y el barrido es
  **idéntico** al caso sin censura: **cualquier productor honesto dentro de la ventana derrota a un
  censor minoritario**. La censura solo mordería con ventana de una sola oportunidad o `c→1`.
- Límite declarado (G4): se asume que el premio `s·C` basta para que el honesto incluya; con saldos
  diminutos `C` puede no cubrir el coste fijo de la transacción.

## 9.5 · Validación, rendimiento y reproducción

- `Pkg.test()`: **97/97** (39 de SL-2 + 58 de SL-2b). `run.jl` completo en **≈5,3 s** de pared con
  4 hilos (SL-2 era 2,39 s); el barrido nuevo `region-s2.csv` (230 400 filas, P1 y P2) domina el
  extra. Sin `@fastmath`/`@simd`/`Float32`; memoización de `β_d` intacta; `region_tv` sigue con 0
  asignaciones.
- **Reproducción de SL-2 comprobada:** los once CSV de SL-2 regenerados por `run.jl` tienen
  **hash idéntico** a `resultados/HUELLAS.sha256` de SL-2 (`s=0`, control); solo `RESUMEN.txt` cambia
  (añade el bloque SL-2b). `region.csv` (57 600 filas) y `frontera-central.csv` son byte a byte los
  de SL-2.
- `RESUMEN.txt` publica `s2b = (coincide_s0=true, cotas_ok=true, autodenuncia_ok=true,
  perdida_menor=true, err=0.0)`.
- Artefactos nuevos: `region-s2.csv`, `resumen-s2b.csv`, `celdas-perdidas-s2b.csv`,
  `frontera-central-s2.csv`, `recomendacion-dev-s2.csv`, `censura-s2b.csv`,
  `comprobaciones-s2b.csv`.

## 9.6 · Veredicto de la pregunta falsable de SL-2b

> «Con la recompensa de 2/8, ¿la región del caso central (reparto empírico de DS-6) sigue siendo no
> vacía para `α_atacante ∈ [0,20;0,40]` y `ε_h ≤ 10⁻³`, incluso contra un atacante confabulado con
> quien incluye su evidencia?»

**SÍ.** En el caso central (reparto empírico DS-6) la región del atacante **confabulado** sigue
siendo no vacía en todas las celdas con `ε_h ≤ 10⁻³`; las 40 celdas que se pierden son todas de
`ε_h = 10⁻¹` (sin firmante seguro), `V = 10⁶` y `α = 0,40`, es decir, celdas que la honestidad o la
grieta ya tenían al límite. En el caso pesimista (Pareto H3) la región también sobrevive, a costa de
un `T_v` mayor. El precio de la recompensa es acotado y explícito: el perfil robusto pasa de
`9·10⁵` a `1,2·10⁶` slots (`s=2/8`) y a `1,4·10⁶` (`s=3/8`, descartado); el perfil primario del
caso medido no cambia.

Presupuesto SL-2b (LINEO §7): 4 hilos, 8 GiB de RAM, 256 MiB de disco; usado ≈5,3 s de pared y
<1 GiB (los nuevos CSV ocupan ≈40 MiB). Estado: **completo** (no inconcluso).
