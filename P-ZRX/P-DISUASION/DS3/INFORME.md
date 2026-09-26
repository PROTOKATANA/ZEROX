# INFORME — DS-3 · Calculadora y Monte Carlo del coste mínimo de los ataques (B0, B1 y candidatos)

**Ejecutor:** DeepSeek (`deepseek-flash`, esfuerzo `high`, Julia). **Fecha:** 2026-09-26.
**Marco:** `P-ZRX/P-DISUASION/MARCO.md`. **Orden:** `ORDEN-DS3-MODELO.md` con su Ratificación.
**Especificación:** `P-ZRX/P-DISUASION/resultados-DS2/MODELO.md`, ratificada en `REVISION-DS2.md`.
**Categoría LINEO declarada:** `seguridad` (dominante); `consenso`, `economía`, `almacenamiento`
(secundarias). **Proyecto:** este directorio (`DS3/`), Julia 1.13.0, CPU; **sin Python**.

**Comprobación de entrada (al empezar y al terminar):**
`sha256sum -c P-ZRX/P-DISUASION/ENTRADA-DS3.sha256` → las seis sumas **coinciden** (MARCO,
ORDEN-DS3, REVISION-DS2, MODELO, INFORME-DS2 y LINEO).

**Falta de definición detectada antes de editar:** está en `DEFINICIONES-FALTANTES.md` (F1–F10).
Ninguna bloquea la ejecución; todas se resuelven con una decisión declarada y, cuando el MODELO no
tiene fórmula, la celda se publica **no cuantificada** en vez de rellenarse con un número supuesto.

---

## 1 · Qué se ha construido y cómo se comprueba

Proyecto Julia aislado con la estructura de LINEO §1:

```text
DS3/
├── Project.toml / Manifest.toml      # dependencias y árbol resuelto
├── julia-version.toml                # 1.13.0, juliaup 1.22.7, znver5
├── escenarios.tsv                    # TODOS los parámetros con etiqueta y procedencia
├── src/{modelo,referencia,rapido,validacion}.jl
├── test/runtests.jl                  # 7 casos de §4 + equivalencia de vías + MC
├── bench/benchmarks.jl               # tabla de rendimiento LINEO §6
├── run.jl                            # CLI reproducible; genera resultados/*.csv
├── resultados/                       # CSV, BENCH.txt, TEST.log, RUN.log
├── DEFINICIONES-FALTANTES.md
└── INFORME.md
```

Método (LINEO y orden §2):

1. **Fórmulas cerradas** del MODELO implementadas en `modelo.jl`, cada una citando su sección.
2. **Cuatro vías independientes** para la primera pasada: DP certificada `(mínimo, posición)`
   (P-PRESTAMO), DP absorbente exacta (`Rational{BigInt}`), enumeración exhaustiva
   (`Rational{BigInt}`) y Monte Carlo con `StableRNGs`. Coinciden en **4.216 celdas** con error
   máximo `1,1·10⁻¹⁵` y en **2.728 celdas** de enumeración con error `2,2·10⁻¹⁶`.
3. **Monte Carlo independiente del mismo modelo**, con semilla derivada por réplica
   `StableRNG(hash64(semilla ⊻ etiqueta, id))` (no consecutiva; la mezcla ya validada en P-CLAVE).
   El MC se usa **solo donde el suceso es alcanzable**; para la cola de `10⁻¹⁰⁸` se usa el oráculo
   exacto y se declara que el MC no aplica.
4. **Parámetros leídos de `escenarios.tsv`**, cada uno con unidad, etiqueta
   (`medido`/`hecho`/`derivación`/`hipótesis`/`condicionado`), procedencia y barrido declarado.
   Ninguna constante oculta: `run.jl` falla si falta una clave obligatoria.
5. `Pkg.test()` en verde y `run.jl` reproducible con un comando.

**Presupuesto declarado antes de ejecutar:** 4 hilos, 8 GiB de RAM, 256 MiB de disco, 2 h
(presupuesto de la orden). **No se agotó** (`run.jl` en 1,4 s tras la optimización validada; MC de
20.000 réplicas).

---

## 2 · Faltas de definición y pregunta falsable por celda

`DEFINICIONES-FALTANTES.md` documenta F1–F10. Las tres que más afectan a la lectura:

- **F1:** DS-2 **no** formula un «multiplica por al menos …» por celda E. DS-3 los construye y los
  marca como suyos.
- **F2:** el MODELO no define una función coste↔probabilidad para A4/A5/A7/A8/A9/A10; DS-3 invierte
  solo donde hay fórmula y marca el resto `no cuantificado`.
- **F7:** la fórmula de Baig–Pietrzak transcrita en el MODELO da **4.253**, no el «≈1.233 + 140» que
  la acompaña; se implementa la fórmula y se publica la discrepancia (el resumen del artículo da
  `φ²ρ/ε = 1.600`).

Preguntas falsables construidas por DS-3 (refutables con la tabla de §4):

| Celda E | Pregunta falsable (construida por DS-3) | Resultado |
|---|---|---|
| A1 · M3+M5 | «Para `P*≥10⁻⁶`, M3+M5 multiplica por ≥2 el coste mínimo de X frente a B0» | **REFUTADA**: coste 0 por la grieta |
| A3 · F1+F2+F4 | «F1+F2+F4 multiplica por ≥100 el coste de regenerar 1 TiB frente a B0» | **CONFIRMADA** en coste (117,2 núcleos/TiB); **REFUTADA** en detección si `k≤B` |
| A4 · M1/F4 | «El requisito fijo multiplica por ≥2 el coste de un atacante que parte su espacio» | **CONFIRMADA** para granja pequeña; **REFUTADA** para el atacante grande (marginal→0) |
| A5 · O4 | «O4 quita el premio del pool de firma ciega **sin** depender de detección» | **CONFIRMADA** (regla; no tokenizable) |
| A7 · F3 | «F3 encarece reescribir un mes de historia de forma exigible» | **NO CUANTIFICADA en ZEROX** (no existe) |
| A8 · O1 | «O1 permite calcular el coste absoluto en energía de reescribir `k` bloques» | **NO CUANTIFICADA**: falta `hash/bloque` y dificultad |

---

## 3 · Los siete casos de comprobación de `MODELO` §4 (regresión de `Pkg.test()`)

| # | Caso | Valor DS-3 | Esperado | Vía | Estado |
|---|---|---|---|---|---|
| 4.1 | `α*(0,0,1,1)`; cruce `β_d=0,34 ⟺ α=0,33` | `1/2`; `g=0` exacto | `1/2`; cruce | `Rational{BigInt}` | ✅ |
| 4.2 | `P_first(F=1.019, α=0,33, β_d=0)` | `9,75216·10⁻¹⁰⁸` (`log10=−107,011`) | `9,75·10⁻¹⁰⁸` | DP exacta | ✅ |
| 4.2 | `F=3.600` menor que `F=1.019` | `P(3.600) < P(1.019)` | menor | DP | ✅ |
| 4.3 | `P(B=0)` con `θ=0,36` | `0,6976763261` | `0,69768` | Poisson exacta | ✅ |
| 4.3 | normal (delator) | `0,3016658861` (razón `0,4324`) | `0,3017` | aproximación | ✅ alerta |
| 4.4 | `B(ε=0,01)`, `T_v=3.600` | `0,675466` > `1−2α=0,34` | `0,675` (grieta SÍ) | derivación H3 | ✅ |
| 4.4 | `B(ε=0,01)`, `T_v=10⁵` | `0,369043` < `0,5075` | `0,369` (grieta NO) | derivación H3 | ✅ |
| 4.5 | cobertura `N=1.048.480, k=10³, B=181.092` | `almacenamiento_forzado = 0` | indiferente a `k` | exacta | ✅ |
| 4.5 | detección certificada `k=10⁶` | `M=189.670→9,8712·10⁻³`; `M=189.671→1,0181·10⁻²` | idem; `φ_γ≈81,9 %` | hipergeométrica | ✅ |
| 4.6 | CPU 24 hilos ≈ disco 20 TB | `w_eq = 761.926` | `≈7,6·10⁵` | `N_h/(rτ)` | ✅ |
| 4.6 | núcleos/TiB a `w=7.175` | `117,238` | `117,238` | derivación | ✅ |
| 4.7 | Baig–Pietrzak `φ=2, ε=0,01, ρ=4` | `3.297 + 816 + 140 = 4.253` | `≈1.233 + 140 [sic]` | fórmula §2.11 | ⚠ reserva F7 |

Salida reproducible: `resultados/comprobaciones.csv`.

---

## 4 · Resultado por ataque (B0 → B1 → candidato)

Convención de coste: **u.e.** = unidades de emisión; la definición de `coste_honesto` es la
declarada en `DEFINICIONES-FALTANTES` F9. `condicionado H-PUENTE` en toda fila de ventana: el puente
espacio→tasa **no existe** (MODELO §5). Detalle completo en `resultados/ataque-*.csv`.

### 4.1 · A1 · doble farmeo (M1, M2, M3, M5, O2, O3)

Coste mínimo de X para alcanzar `P*`, por reclutado, con `F=1.019`, `ρ_ret=0,5`, `T_v=3.600`,
`κ=1`, `q_gana=1` (`resultados/ataque-A1-doble-farmeo.csv`):

| `α` | `P*` | `β_d` mínimo | `P` alcanzada | `N_recl` | **B0** | **B1** | **candidato M3+M5** | honesto | cociente |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 0,20 | 10⁻⁶ | 0,5056 | 1,0·10⁻⁶ | 506 | 0 | 1,62·10⁻³ | **0** | 1,832 | 0 |
| 0,20 | 10⁻³ | 0,5347 | 1,04·10⁻³ | 535 | 0 | 1,62·10⁻³ | **0** | 1,832 | 0 |
| 0,33 | 10⁻⁶ | 0,2522 | 1,11·10⁻⁶ | 253 | 0 | 1,62·10⁻³ | **0** | 1,832 | 0 |
| 0,33 | 10⁻³ | 0,2787 | 1,01·10⁻³ | 279 | 0 | 1,62·10⁻³ | **0** | 1,832 | 0 |
| 0,33 | 0,5 | 0,3248 | 0,502 | 325 | 0 | 1,62·10⁻³ | **0** | 1,832 | 0 |
| 0,40 | 10⁻⁶ | 0,1161 | 1,08·10⁻⁶ | 117 | 0 | 1,62·10⁻³ | **0** | 1,832 | 0 |
| 0,40 | 0,5 | 0,1858 | 0,522 | 186 | 0 | 1,62·10⁻³ | **0** | 1,832 | 0 |

**Lectura.** El candidato M3+M5 **no impone coste alguno** en ningún escenario: el `β_d` necesario
para cualquier `P*` (máximo `0,585`) queda **por debajo** de la fracción de espacio con saldo
confiscable cero, `B(ε=0,01)=0,675`. Es la grieta de P-CLAVE F3, ahora cuantificada en términos de
«coste mínimo para una probabilidad de éxito»: el soborno **nominal** sería
`1830 u.e./reclutado`, pero **se compra a coste 0**. B0 y B1 tampoco encarecen el doble farmeo; B1
solo inmoviliza garantía (`1,6·10⁻³ u.e./reclutado` de coste de oportunidad), y el atacante lo paga
haga lo que haga. **El atacante no necesita trasladar el coste: no existe.**

**Por dimensión del marco (A1, candidato M3+M5, α=0,33, P*=10⁻³):**
`C-riesgo = 0` (la grieta exime); `C-inmov = 1,6·10⁻³ u.e./reclutado` (garantía M1);
`C-adq = 0` (los tokens se compran con el mismo hash del prefijo PoW, acoplamiento A8↔M1);
`C-energía = 0,092–0,190 núcleos·slot/granjero` por el PoT de la rama privada (`≈0,0003 kWh` a 65 W);
`C-hardware = 0,092·F·N_recl ≈ 26,2 núcleos` para `N_recl=279`; `C-tiempo = T_v` (maduración, no se
compra); `P-detección = κ·q_gana = 1` en el escenario nominal, pero inútil sin coste que confiscar.

**O3 (`C-FIN-01`)** cambia el coste en 0 dentro de la ventana: acota el daño (profundidad `d<F`),
no el umbral `α*` (P-PRESTAMO §2). **O2 (PoT)** cierra el *bootstrapping* de Baig–Pietrzak, no la
carrera de rama privada en tiempo real; Δ = 0 para A1.

### 4.1b · A2 · equivocación publicada (M3, κ escalonado)

`resultados/ataque-A2-equivocacion.csv`. `κ` es la **función escalonada de `m`** de MODELO §2.6
(soluciones ganadoras esperadas del atacante por slot), no una constante:

| Identidad | `m` | `κ` | soborno por reclutado (`κ·1830`) | coste de reclutar `β_d=0,34` |
|---|---:|---:|---:|---:|
| `C-GD-07`, `m≤0,05` | 0,05 | **1,000** | 1.830 | **0** (grieta) |
| `C-GD-07`, `m=1` | 1 | **0,455** | 832,7 | **0** |
| `C-GD-07`, `m=4` | 4 | **0,000** | 0 | 0 |
| flujo divergente | — | 0,000 | 0 | 0 |
| `misma-parcela`/IDV-01 | — | 1,000 | 1.830 | 0 |

**Lectura.** A2 es **Ec** (necesita que la evidencia se publique y llegue): para el atacante pequeño
`κ=1` y el soborno nominal es 1.830 u.e./reclutado, pero **la grieta lo compra a coste 0**; para el
atacante grande (`m=4`) `κ=0` y el castigo **no existe**. El mecanismo solo separa al pequeño por el
lado de la detección, nunca por el del coste.

### 4.2 · A3 · sembrador (F1+F2+F4)

`resultados/ataque-A3-sembrador.csv`. Con `N=1.048.480` (1 TiB), `D_a=60 s`, `r=25,03`:

| `w` | `B` | almac. forzado (`k=10⁶`) | núcleos/TiB | máquinas/TiB | kWh regenerar | kWh almacenar | razón | detección |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 7.175 (sin VDF) | 181.092 | **82,73 %** | **117,238** | 5,790 | 15,315 | 0,01005 | **1.524×** | **cero si `k≤181.092`** |
| 8.030 (tope) | 202.492 | 80,69 % | 104,8 | 5,178 | 15,315 | 0,01124 | 1.363× | cero si `k≤202.492` |
| 4.830,6 (VDF ρ=2,5) | 122.411 | 88,32 % | 173,4 | 8,565 | 15,315 | 0,00679 | 2.255× | cero si `k≤122.411` |

**B0 = 0** (no hay registro ni auditoría: regenerar es gratis). **B1 = 0** (B1 no incorpora F).
**Candidato F1+F2+F4:** el coste es **117,2 núcleos/TiB continuos** mientras dura el ataque,
`1.524×` la energía de solo almacenar, y **no depende de `w`**. Es **E exigible** en coste.
La **detección** es **E condicionada a `k>B`**: el acantilado es exacto (no suave). Con `N=1.048.480`,
`B=181.092`, `k=10⁶` (`resultados/cobertura-barrido.csv`): guardar el 83 % → detección **0**
(`M=178.242 < B`); guardar el 82 % → `1,6·10⁻⁴¹`; guardar el 80 % → **1,0**. La frontera práctica
certificada es `M=189.670/189.671` y `φ_γ≈81,91 %`. **HDD doméstico (≈100 lecturas/s) no puede
servir `k>B`** (`181.092/60 ≈ 3.018 lecturas/s`); un SSD sí.

### 4.3 · A4 · Sybil / partición de identidades (M1, F1, F4)

`resultados/ataque-A4-sybil.csv`. Modelo DS-3 declarado (falta F5): coste por identidad `q`,
coste por byte `q/f`.

| `q` (u.e.) | `f=10⁻⁶` (coste/byte) | `f=10⁻³` | `f=10⁻¹` | fracción del ingreso semanal, `f=10⁻³` |
|---:|---:|---:|---:|---:|
| 100 | 10⁸ | 10⁵ | 10³ | 0,165 |
| 1.000 | 10⁹ | 10⁶ | 10⁴ | **1,653** |
| 10.000 | 10¹⁰ | 10⁷ | 10⁵ | **16,53** |

**Lectura.** El requisito **fijo** por identidad es **E exigible** (se paga haga lo que haga) pero
**regresivo**: con `q=1.000` consume el **165 % del ingreso semanal** de una granja de `f=10⁻³` y el
**1,65 %** de una de `f=10⁻¹`. El atacante grande lo traslada agregando espacio en menos
identidades; el marginal por partición tiende a 0. Δ de coste para el honesto pequeño: positivo y
no despreciable; para X grande: ≈0.

### 4.4 · A5 · producir con espacio ajeno (O4)

`O4` (atar la coinbase a `sol.public_key`) es **E sin condición de detección**: quita el premio al
pool que firma a ciegas. **No tiene coste en tokens**: es una regla de consenso, y el MODELO no le
asigna función de coste (falta F6). Δ de coste de X = **no cuantificable en dinero**; Δ de
*resultado* = cierre del incentivo de la arquitectura de firma ciega. No cierra la capacidad de
producir en la rama ajena ni la arquitectura de pool-firma.

### 4.5 · A7 / A8 / A9 / A10 — lo cuantificable y lo que no

- **A7 (largo alcance).** `F3` (sellado lento) **no existe en ZEROX** → **no cuantificado** (sería
  exigible si se adoptase, exige cambiar el objeto ploteado). `O2` encarece fabricar historia en
  tiempo comprimido en proporción a `1−1/ρ` (`ρ∈[1,01;2,5]`), pero el MODELO no da la función de
  coste → cualitativo. `O3` acota el daño (`d<F`, Δ=0 en el umbral).
- **A8 (transición).** `O1` PoW: hechos medidos — CPU 16 núcleos `7,379·10⁷ H/s`, GPU GTX 1070
  `5,611·10⁸ H/s`, `1,94·10⁻⁷ J/hash` (`resultados/ataque-A8-transicion.csv`). No hay `hash/bloque`
  ni dificultad en el MODELO → **no se publica energía absoluta por bloque**, solo `J/hash` y
  `H/s` medidos.
- **A9/A10.** `F4`/`F2`/`F5`: el MODELO no da fórmula de `Fault Fee`, registro ni expiración para
  ZEROX → **no cuantificado**. `M1`/`F4` fijos sí encarecen el alta duplicada (misma tabla A4).

### 4.6 · Tabla por mecanismo (requisito de la Ratificación)

`resultados/por-mecanismo.csv`. Δ = coste absoluto de X frente a B0 en los escenarios del §3.

| Mecanismo | Ataque | Δ coste de X | Coste del honesto | Exigible/Condicionado |
|---|---|---|---|---|
| **M3+M5** | A1/A2 | **0** por la grieta (`β_d=0,279 < B(ε)=0,675`); soborno nominal `1830 u.e./reclutado` | `1,83 u.e./reclutado` (pérdida accidental esperada) | Condicionado a `κ>0` y saldo confiscable |
| **F1+F2+F4** | A3 | **117,238 núcleos/TiB** continuos; `1.524×` energía de almacenar | `0,01005 kWh/TiB/ventana` (almacenar) | **E coste**; Ec detección (`k>B`) |
| **F3** (sellado) | A7 | no cuantificado (no existe en ZEROX) | — | Ee si se adopta |
| **M1** (garantía) | A4 | `1000 u.e./identidad` | `1 u.e./año` (accidental, `ε_h=10⁻³`) | **Ee**, regresivo |
| **F4** (colateral) | A4/A9/A10 | `1000 u.e./sector` | `1 u.e./año` | **Ee**, regresivo |
| **O4** (coinbase) | A5 | regla de consenso: sin coste en tokens | — | **Ee** sin detección |
| **O3** (`C-FIN-01`) | A1/A7 | 0 en el umbral; acota daño | — | Ee estructural |
| **O2** (PoT) | A1/A7 | cierra *bootstrapping*; no la carrera | 0 | Ee parcial |
| **M4** (correlacionado) | A1/A2 | no evaluado (falta definición) | — | candidato propio |
| **F5** (ciclo de vida) | A10 | no cuantificado (falta fórmula) | — | Ee débil |

### 4.7 · Sensibilidad — qué parámetro domina

`resultados/sensibilidad-A1.csv`. Como el candidato M3+M5 queda en la **grieta** (coste 0), la
sensibilidad no se mide sobre un coste nulo sino sobre **el umbral que lo produce**, `B(ε)`:
dominante **`dist_alpha` (la cola de claves pequeñas)**, con cambio relativo `0,637` al pasar de
`2,05` a `3,0`; le sigue `ε_saldo`. Es decir: **el parámetro que decide si M3+M5 muerde no es
`ρ_ret` ni `T_v`, sino la forma de la distribución de tamaños de clave (H3, no medida en ZEROX)**.
Para el soborno nominal, el dominante es `T_v` (entra lineal en `ρ_ret·I·T_v`).

---

## 5 · Monte Carlo independiente

`resultados/monte-carlo.csv` (20.000 réplicas, semilla `0x5a5a`):

| Caso | Exacto | MC | IC 95 % | Resultado |
|---|---:|---:|---|---|
| ventana `p=1/3, d=5, T=400` | `0,015625` | `0,01590` | `[0,01426; 0,01773]` | **DENTRO** |
| retención `P(B=0)`, `θ=0,36` | `0,697676` | `0,69925` | `[0,69286; 0,70557]` | **DENTRO** |
| cola profunda `9,75·10⁻¹⁰⁸` | `9,75·10⁻¹⁰⁸` | — | — | **MC NO APLICA** (`P ≪ 1/nrep`); se usa el oráculo exacto |

El MC serial y el paralelo dan **el mismo resultado** (reducción determinista, una posición de
salida por réplica, RNG por réplica): test de regresión en verde.

---

## 6 · Rendimiento (LINEO §6) y optimización validada

`resultados/BENCH.txt` (1 o 4 hilos; `@benchmark` tras calentar JIT):

| Variante | Tiempo mediano | Asignaciones | Hilos | Frente a la referencia |
|---|---:|---:|---:|---|
| `primera_dp(0,33, 346, 1.019)` (oráculo `(mín,pos)`) | 550,7 ms | 6 | 1 | fuente de verdad |
| `primera_dp_absorbente(0,33, 346, 1.019)` | **0,558 ms** | 6 | 1 | **987× más rápida**, idéntica (<10⁻¹⁵) |
| `primera_dp(0,33, 10, 1.019)` | 15,21 ms | 6 | 1 | idéntica |
| `cola_hiper_rapida(1.048.480, 189.670, 10⁶, 181.092)` | 0,0256 ms | **0** | 1 | idéntica a la exacta |
| `mc_ventana(1/3, 5, 400, 10.000)` serial | 3,782 ms | 1 | 1 | igual al DP |
| `mc_ventana(...)` paralelo | **0,962 ms** | 23 | 4 | mismo resultado (**3,93×**) |
| `beta_minimo_para_p` rápida [por defecto] | **20,17 ms** | 258 | 1 | mismo `β_d` |
| `beta_minimo_para_p` certificada | 5.612,2 ms | 258 | 1 | mismo `β_d` (±10⁻⁹) |

**Optimización aplicada (LINEO §2, paso 0):** la DP absorbente es algebraicamente la misma
probabilidad de primera pasada y se validó contra la certificada en 4.216 celdas. Se usa en los
barridos y en la bisección; el `run.jl` completo pasó de **162 s a 1,4 s** sin cambiar ninguna cifra
publicada. `@code_warntype` de los kernels no muestra `Any`; sin `@fastmath`, sin `@simd`, sin
`Float32`; `@inbounds` con poda exacta justificada (`m > z` inalcanzable).

---

## 7 · Qué NO queda cuantificado (y por qué)

1. **F3 en ZEROX**, **M4**, **O3 con cifra**, **F5**, **O5/ATX**, **A9-A10**: sin fórmula en el
   MODELO ratificado (F6). No se les inventa coste.
2. **A8 en energía absoluta**: falta `hash/bloque` y dificultad (F6).
3. **Precios** (`precio_token`, `precio_TB`, `precio_núcleo`): hipótesis sin fuente verificada;
   salen como parámetro explícito, nunca como constante oculta.
4. **H-PUENTE**: todo resultado de ventana está condicionado; el puente espacio→tasa no existe.
5. **H3**: la distribución de tamaños de clave no está medida en ZEROX ni en Autonomys; es el
   parámetro **dominante** de la grieta de A1 (sensibilidad §4.7).
6. **La cota de Baig–Pietrzak**: implementada y verificada como fórmula, **no** como cifra de ZEROX;
   su discrepancia interna (F7) queda declarada.

---

## 8 · Reproducción

```bash
cd /home/katana/zeo/ZEROX/P-ZRX/P-DISUASION/DS3
export JULIA_DEPOT_PATH="$PWD/.julia-depot:/home/katana/.julia"   # depósito local dentro de la zona
export PATH=/home/katana/torio/.juliaup/bin:$PATH

# 1) Entrada congelada
(cd /home/katana/zeo/ZEROX && sha256sum -c P-ZRX/P-DISUASION/ENTRADA-DS3.sha256)

# 2) Regresión (7 casos de MODELO §4 + equivalencia de vías + MC)
env -u LD_LIBRARY_PATH JULIA_NUM_THREADS=4 OPENBLAS_NUM_THREADS=1 \
  julia --project=. --threads=4,0 test/runtests.jl
# o bien: julia --project=. -e 'using Pkg; Pkg.test()'

# 3) Calculadora completa (B0 → B1 → candidatos, CSV)
env -u LD_LIBRARY_PATH JULIA_NUM_THREADS=4 OPENBLAS_NUM_THREADS=1 \
  julia --project=. --threads=4,0 run.jl --seed 0x5a5a --reps 20000

# 4) Benchmarks
env -u LD_LIBRARY_PATH JULIA_NUM_THREADS=4 OPENBLAS_NUM_THREADS=1 \
  julia --project=. --threads=4,0 bench/benchmarks.jl
```

**Entorno capturado:** Julia 1.13.0, juliaup 1.22.7, CPU `znver5`, 123,4 GiB de RAM,
`Threads.nthreads(:default)=4`, `Threads.nthreads(:interactive)=0`, `Sys.CPU_NAME=znver5`.
Semilla `0x5a5a` (=23130), 20.000 réplicas. `Manifest.toml` versionado.

---

## 9 · Reservas y respuesta a la pregunta falsable

1. **La pregunta de Katana** («¿un mecanismo que no cierra el hueco pero encarece el ataque es una
   mejora real?») se responde con coste absoluto, no con una opinión:
   - **A3 · F1+F2+F4**: mejora real **exigible** en coste — `117,2 núcleos/TiB` continuos,
     `1.524×` la energía de almacenar — con detección **condicionada** a `k>181.092` aperturas/TiB.
   - **A4 · M1/F4**: mejora real **exigible** pero **regresiva**; frente al atacante grande el
     coste marginal por partición tiende a 0.
   - **A5 · O4**: mejora real **exigible sin detección**, no tokenizable (regla de consenso).
   - **A1 · doble farmeo**: **ninguna** celda de PoStake/Filecoin es exigible contra el atacante
     grande. M3+M5 queda **refutado**: el `β_d` que cruza la deriva se compra a coste **0** por la
     grieta `B(ε)=0,675 > β_d`. Coincide con DS-2 y con RFT-01/RFT-09, ahora con cifra.
2. **Reserva H-PUENTE.** Todo A1/A2 está condicionado al puente espacio→tasa, que no existe.
3. **Reserva H3.** El resultado de A1 depende de la cola de tamaños de clave, que no está medida;
   cambiar el exponente de 2,05 a 3,0 mueve el umbral `B(ε)` un 64 %.
4. **Reserva F7.** La cota de Baig–Pietrzak transcrita no cuadra con las cifras que la acompañan;
   se implementó la fórmula y se publicó la discrepancia. No se usa como cifra de ZEROX.
5. **Reserva de precios.** Los cocientes a dinero no se publican: `precio_token`, disco y núcleo
   son hipótesis sin fuente verificada en este encargo.

**Rutas de entrega:** `DS3/INFORME.md` (este documento), `DS3/DEFINICIONES-FALTANTES.md`,
`DS3/resultados/*.csv`, `DS3/resultados/BENCH.txt`, `DS3/src/`, `DS3/test/`, `DS3/run.jl`,
`DS3/escenarios.tsv`, `DS3/Project.toml`, `DS3/Manifest.toml`.
