# INFORME — ANCLA-v0.1 (P-2.1)

**Categoría dominante:** `consenso` (el objeto es la estabilidad de un ancla de consenso).
**Secundaria:** `seguridad` (la pregunta nace del ATAQUE 2 y de `α_mín`).
**Estado:** instrumento de estudio (MS). **No activa nada ni fija constantes.** GHOSTDAG y `rank`
salen de **GDR-v0.2 sin modificar** (`veritas/consenso/ghostdag-rank-v1/`).

Etiquetas: **DEMOSTRADO** (argumento escrito o identidad), **MEDIDO** (simulación con semilla, CI y
modelo declarados), **ESTIMADO** (extrapolación declarada), **NO DEMOSTRADO**, **INCONCLUSO**.

---

## 0 · Día uno: la corrección del modelo del §2 es correcta

Verificado contra R-FIN-14 (`research/dag-poas-ancla-de-orden.md:258-296`) y la ronda 9c
(`research/scripts/d9-ronda9c/informe.md` §E):

- La magnitud del steering es **`n_eval = ρ·W_dec`** (y **0** si `ρ ≤ 1`, hallazgo E1), **no** un
  adelanto `(ρ−1)·D`. **MEDIDO/derivado en el repositorio; aquí no se recalcula esa derivación.**
- La calibración es **`I ≥ ρ_max·W_dec`** con `W_dec ≤ 45 s`, no una cota sobre `D`.
- **DEMOSTRADO** por estructura del texto: `D` es profundidad e `I` es periodo; no compiten
  directamente.

**Por tanto el encargo se ejecuta con el modelo corregido y el resultado principal lo confirma:**
`D_min` es de unos pocos slots, no de horas. (Ver §3.1.)

---

## 1 · La medición central: `P(discrepancia del ancla)(D)` — **MEDIDO**

Red y Δ de DMS-v0.1 (validado: `Δ_99` medio 0,234 s, p99 0,364 s, dentro de 0,26–0,60 s).
`k = 30`, `λ = 1 bloque/s`, 15 padres, `mergeset ≤ 180`, `n = 100`, 100 observadores, cortes cada
1 s, 10 000 réplicas independientes, 600 s por réplica. CI por bootstrap de clúster (2 000).
`D` en slots (`τ = 1 s`).

`P_dis(D)` = probabilidad de que dos observadores honestos con puntas distintas asignen bloques
distintos a la posición `H_ref − D`. `p_dif_ref` = fracción de observadores que difieren de la
vista de latencia cero.

| `D` | `P_dis` | IC 95 % (clúster) | `p_dif_ref` | votos |
|---:|---:|---|---:|---:|
| 0 | **3,078·10⁻³** | [3,052·10⁻³, 3,104·10⁻³] | 5,040·10⁻³ | 5,17·10⁸ |
| 1 | **3,627·10⁻⁴** | [3,537·10⁻⁴, 3,717·10⁻⁴] | 4,614·10⁻⁴ | 5,87·10⁸ |
| 2 | **6,302·10⁻⁶** | [5,208·10⁻⁶, 7,471·10⁻⁶] | 5,906·10⁻⁶ | 5,87·10⁸ |
| 3 | **2,657·10⁻⁸** | [3,373·10⁻⁹, 5,949·10⁻⁸] | 1,363·10⁻⁸ | 5,87·10⁸ |
| ≥4 | 0 eventos | — | — | 5,87·10⁸ |

Datos crudos por réplica: `resultados/curva-grande.csv`; reducción: `resultados/curva-grande.txt`.

**Umbrales (λ = 1, Δ medida):**

| umbral | `D_min` | estado |
|---:|---:|---|
| 10⁻³ | **1 slot** | MEDIDO (3,63·10⁻⁴ < 10⁻³ en `D=1`; `D=0` = 3,08·10⁻³ > 10⁻³) |
| 10⁻⁶ | **3 slots** | MEDIDO (`D=2` = 6,30·10⁻⁶ > 10⁻⁶; `D=3` = 2,66·10⁻⁸ < 10⁻⁶) |
| 10⁻⁹ | **4 slots** | ESTIMADO. `D=4` no observado en 5,87·10⁸ votos; con el cociente de caída mínimo observado (8,5) `D=5` = 3,7·10⁻¹⁰; con el cociente `D=2→3` (237) `D=4` ≤ 1,1·10⁻¹⁰. **No medido.** |

**Contraste bajo carga (`λ = 3`, 800 réplicas, 300 s):** la misma forma se mide hasta `D = 4`.

| `D` | 0 | 1 | 2 | 3 | 4 | ≥5 |
|---|---:|---:|---:|---:|---:|---:|
| `P_dis` | 2,303·10⁻² | 6,644·10⁻³ | 5,008·10⁻⁴ | 2,864·10⁻⁵ | 5,796·10⁻⁷ | 0 |

`D_min` con `λ = 3`: 2 / 4 / 6 (10⁻³/10⁻⁶/10⁻⁹; el último ESTIMADO). `resultados/curva-lambda3.*`.

**Lectura:** con la Δ medida, la posición del ancla queda fijada a profundidades de **pocos slots**.
`D_min(10⁻⁶)` = 3 slots = 3 s, frente a `F` en horas. **La premisa del ATAQUE 1 («hace falta
profundidad ≥ finalidad») es falsa en este modelo**, y por tanto la contradicción que declara **se
disuelve**, no se hereda.

**Alcance estrecho (obligatorio):** esto es coincidencia entre observadores honestos bajo el modelo
ANCLA-v0.1, **sin particiones, sin eclipse y sin adversario**. Una partición de duración `F` puede
inducir reorgs de profundidad ~`λF` que **no** están cubiertas aquí. `P_dis` **no es finalidad.**

---

## 2 · Cota superior: cuánto steering compra un `ρ` físico — **DERIVADO (no medido aquí)**

De R-FIN-14(f) y E1 (no recalculado): `n_eval = ρ·W_dec` con `ρ > 1`; `n_eval = 0` con `ρ ≤ 1`.
`W_dec ≤ 45 s` (9c). Cota física de `ρ`: **~1,5–2,5×** (`research/pot-aes-asic-chacha.md` §3:
«con AES la CPU ya es el ASIC»; un 19× exigiría 25 ps/ronda, no alcanzable). Chia (3,1–3,8×) usa un
ASIC de grupos de clase, operación que ninguna CPU acelera: **no transferible a AES**.

| `ρ` | 1 | 1,5 | 2 | 2,5 | 3 | 4 |
|---|---:|---:|---:|---:|---:|---:|
| `n_eval = ρ·W_dec` | **0** | 67,5 | 90 | 112,5 | 135 | 180 |
| `I_min = ρ_max·W_dec` (s) | 0 | 67,5 | 90 | 112,5 | 135 | 180 |

Rango físico: `ρ ≤ 2,5` ⇒ `n_eval ≤ 112,5` y `I ≥ 112,5 s`. `ρ = 3–4` se tabulan solo como margen.

---

## 3 · Mapa `(ρ, F) → ¿existe D admisible?`

**Supuestos del mapa, a la vista (son míos, no del encargo):**

- `D ∈ [D_min(ε), D_max]` (en slots, `τ = 1 s`).
- La cota superior natural del ancla es que pertenezca a la inyección vigente:
  **`D_max = I`** (slots) con `I ≥ ρ_max·W_dec` (R-FIN-14(f)).
- `F` entra **solo** si el diseño exige que el ancla quede final antes de usarse (`F ≥ I`); entonces
  `D_max = min(I, F)`.

Con `W_dec = 45 s`, `D_min(10⁻⁹) = 4` (λ = 1) y 6 (λ = 3):

| `ρ` (físico salvo margen) | `I_min=ρ·W_dec` | `D_max` si `F≥I` | ventana `[D_min(10⁻⁶), D_max]` | ¿existe? |
|---:|---:|---:|---|---|
| 1 | 45 s | 45 | [3, 45] | **sí, holgura ×15** |
| 1,5 | 67,5 s | 67,5 | [3, 67] | **sí, ×22** |
| 2 | 90 s | 90 | [3, 90] | **sí, ×30** |
| 2,5 | 112,5 s | 112,5 | [3, 112] | **sí, ×37** |
| 3 (margen) | 135 s | 135 | [3, 135] | sí, ×45 |
| 4 (margen) | 180 s | 180 | [3, 180] | sí, ×60 |

**Salida: la ventana existe con holgura en toda la región física.** La frontera, si se impone
`F ≥ I`, es **`F ≥ ρ_max·W_dec`** (⇒ `ρ_max ≤ F/W_dec`):

| `ρ_max` | `F_min` requerido |
|---:|---:|
| 1,5 | 67,5 s |
| 2,5 | 112,5 s |
| 4 | 180 s |

frente a `F = 2 h` (provisional) o a la `F` mayor que se prefiera. **`F` no es la restricción que
el ATAQUE 1 suponía; lo es, si acaso, `I ≥ ρ_max W_dec`, que es una restricción sobre un
**periodo**, no sobre la profundidad del ancla.** Esto convierte los dos pendientes vagos
(`ρ_max`, `F`) en el requisito explícito `F ≥ ρ_max·W_dec` bajo el supuesto de finalidad del ancla.

**NO DEMOSTRADO / abierto:** la interpretación de `D_max` como `I` (y de `F ≥ I`) es mía; el
encargo no la fija. Si la cota superior fuese otra, el mapa cambia de orden pero no el signo del
resultado, porque `D_min` es de pocos slots y `I_min` de decenas a centenares de segundos.

---

## 4 · Opción (h): revelación retardada — **no necesaria**

El §3.3 da ventana amplia, así que (h) **no se necesita** para disolver el ATAQUE 1. Si se
adoptara, su coste es un segundo VDF en la ruta crítica y su compra es dividir el steering por 279
en el rango físico (R-FIN-14, corrección 10a). **No se adopta aquí**; es decisión de Katana.

---

## 5 · Las cinco preguntas de LINEO §1

1. **Complejidad.** Simulación `O(bloques · E)` eventos (`E = n·grado/2`); medición
   `O(réplicas · cortes · observadores · largo_cadena)` más las inserciones de GDR-v0.2.
   El parámetro dominante es `réplicas × observadores × bloques`.
2. **Perfil.** Corrida principal: 10 000 réplicas, `T = 600`, 24 hilos → **1 514 s de pared**;
   las cadenas de observador y las `Dict` de votos son el grueso. Sin inestabilidades de tipo
   conocidas en el camino caliente; el código de GDR-v0.2 ya trae su `WARNTYPE.txt` propio.
   Escalado medido (400 réplicas, `T = 300`, `Dmax = 8`; `resultados/ESCALADO.txt`):

   | hilos | 1 | 2 | 4 | 8 | 16 | 24 |
   |---|---:|---:|---:|---:|---:|---:|
   | pared (s) | 72,7 | 42,7 | 29,2 | 23,8 | 18,0 | 18,2 |

   Gana 24 hilos (16 y 24 casi empatan; no se fuerza más). Microbenchmark
   (`resultados/BENCH.txt`, 1 hilo): `simular_red` 3,1 ms / 1 348 asignaciones;
   `medir_transitorio` (`T=120`, 100 observadores) 27,2 ms / 504 665 asignaciones.
3. **Oráculo.** GHOSTDAG contra GDR-v0.2 (que a su vez tiene oráculo independiente
   `referencia.jl`); el generador se validó con `diagnostico_corte` (0 divergencias con
   `faltantes = pendientes = 0` cuando la vista es completa) y con la reproducción de `Δ`.
4. **Numérico.** `P_dis` es estadística sobre contadores enteros; `sd`/`sr`/`slot` son enteros.
   Sin `Float32` ni `@fastmath` en decisiones. La incertidumbre se da por bootstrap de clúster.
5. **Reproducibilidad.** `julia 1.13.0`, `Manifest.toml` versionado, `git 8dffd1c`, semilla
   `0x5a5a`, 24 hilos, `resultados/ENTORNO.txt`. Cada resultado lleva cabecera con comando y
   semilla.

---

## 6 · Resumen de etiquetas

| Afirmación | Etiqueta |
|---|---|
| `n_eval = ρ·W_dec`, `I ≥ ρ_max W_dec` (R-FIN-14) | DERIVADO (del repositorio, no recalculado) |
| Corrección del modelo del §2 | VERIFICADO contra R-FIN-14 |
| `P_dis(D)` a `D = 0..3` (λ=1) | MEDIDO (MS, ANCLA-v0.1) |
| `D_min(10⁻³) = 1`, `D_min(10⁻⁶) = 3` | MEDIDO |
| `D_min(10⁻⁹) = 4` | ESTIMADO |
| Ventana `D` existe en toda la región física | DERIVADO de lo anterior + supuestos declarados |
| `F ≥ ρ_max W_dec` como frontera | DERIVADO bajo el supuesto `F ≥ I` |
| Estabilidad bajo partición/eclipse | NO DEMOSTRADO (fuera del modelo) |
| Generalidad de la política de 15 puntas | LAGUNA declarada |
