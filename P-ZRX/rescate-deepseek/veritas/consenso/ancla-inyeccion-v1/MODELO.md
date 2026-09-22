# MODELO — ANCLA-v0.1

## 0 · Verificación previa del §2 del encargo (día uno)

El encargo pide comprobar, antes de nada, si la corrección del modelo del §2 es correcta. **Lo es,
y coincide con R-FIN-14 del repositorio:**

- R-FIN-14(f): la calibración es **`I ≥ ρ_max · W_dec`**, con `W_dec ≤ 45 s` medida (ronda 9c).
- R-FIN-14, alcance 9c: **`n_eval = ρ·W_dec`** tras un *bootstrap* de días, y **0 para `ρ ≤ 1`**;
  el ataque es **steering por elección de ancla**, no un adelanto temporal de `(ρ−1)·D`.
- El adelanto `(ρ−1)·D` del modelo anterior y su «lookback de 12 h ⇒ 12 h por delante» **no**
  aparecen en ninguna regla vigente. `D` es una profundidad y `I` es un periodo.

Consecuencia que este instrumento pone a prueba: las dos exigencias del ATAQUE 1 pueden no ser
contradictorias porque `D` (estabilidad del ancla) e `I` (periodo entre inyecciones) son
magnitudes distintas. **La medición del §3.1 confirma que `D_min` es de unos pocos slots, muy por
debajo de `F`; la lectura contraria no se sostiene bajo este modelo.**

## 1 · Red y propagación (tomadas de DMS-v0.1, MS)

- Grafo `G(n, p)`, `p = grado/(n−1)`, re-muestreado hasta conexión. Por defecto `n = 100`,
  `grado = 8`. Latencia por enlace **lognormal** con mediana 80 ms y p99 500 ms
  (`μ = log 0,08`, `σ = 0,7879`), una muestra fija por corrida.
- Producción Poisson de intensidad `λ` (por defecto `1 bloque/s`), creador uniforme.
- Propagación por **inundación hop-by-hop**: cada nodo reenvía el bloque una vez a todos sus
  vecinos, con **cola serial** (`t_tx = 65 µs`, 812 B a 100 Mbit/s). `Δ_q` = instante en que
  `⌈q·n/100⌉` nodos lo tienen, menos la creación.
- **Validación de Δ:** en la corrida de referencia, `Δ_99` medio = 0,234 s y `Δ_99` p99 = 0,364 s,
  dentro del rango medido en `veritas/finalidad/delta-medido-v1/` (0,26–0,60 s). El modelo de red
  reproduce la Δ que el encargo manda usar.

Sesgos declarados (los mismos de DMS-v0.1, no corregidos aquí): el modelo reenvía el objeto
completo, valida en 0 s y no modela el relé compacto ni la validación por salto.

## 2 · Bloques y selección de padres (lo único que añade ANCLA-v0.1)

- `slot = ⌊t_creación⌋` con `τ = 1 s/slot`.
- `sd` uniforme aleatorio y `sr = 1000` constante (peso `w = ⌊2^128/(sr+1)⌋` igual para todos; es
  el régimen de espacio uniforme). `ident = 0` (sin billete).
- Al crear, el nodo referencia **hasta 15 puntas de su propia vista** (bloques conocidos sin hijo
  conocido); si hay más de 15, las de `slot` mayor (empate por id). Si su vista está vacía,
  referencia el génesis. Es una **política de producción declarada del modelo**, no una regla de
  consenso; ningún documento del repositorio la fija todavía.
- Los `id` son únicos por construcción; GDR decide `sp`, color y cadena. **No hay adversario.**

## 3 · Observadores

Un observador honesto `u` en el corte `t` tiene por vista el mayor sub-DAG cerrado por padres con
`llega[b,u] ≤ t`. La **referencia** es el observador de latencia cero: todo bloque con
`t_crea ≤ t`. A cada vista se le aplica GDR-v0.2 con `Params()` por defecto
(`k = 30`, `max_parents = 15`, `mergeset_limit = 180`, `s_max = 150`, U3 dinámica, regla C).

## 4 · Estimador `P(discrepancia)(D)`

En cada corte se toma la altura `H_ref` de la referencia y, para cada `D`, la posición absoluta
`N = H_ref − D`. Votan todos los observadores cuya cadena alcanza `N`; `h_D(b)` es el número de
votos al bloque `b`. Se define

```
P(discrepancia)(D) = 1 − Σ_b (h_D(b) / n_D)²        (n_D = votos)
```

que es la probabilidad de que dos observadores elegidos al azar asignen bloques distintos a la
posición `N`. Se acumula **dentro de cada réplica** y se reduce sobre réplicas con **bootstrap de
clúster** (unidad = réplica, 2 000 remuestreos), porque los votos de una misma réplica están
correlacionados y el conteo bruto no es el tamaño de muestra efectivo.

`D` se mide en **slots** (`τ = 1 s`); con `λ = 1` un slot ≈ un bloque de separación.

**Advertencia de alcance:** esto es **estabilidad del ancla**, no finalidad. Un `P` pequeño no dice
que el bloque sea irreversible: dice que los observadores honestos, al mismo tiempo y con la Δ
medida, coinciden en él.

## 5 · Extrapolación a 10⁻⁹

La corrida principal observa `D = 0,1,2,3` y **0 eventos** en `D ≥ 4` sobre 5,87·10⁸ votos
(correlacionados). Estimar 10⁻⁹ por Monte Carlo directo exigiría ~10⁹ unidades independientes: **no
es alcanzable con este presupuesto**. Para `D = 4` se reporta **estimación**, no medida, a partir
del cociente de caída observado (los cocientes `P(D)/P(D+1)` medidos son 8,5 / 57,6 / 237, y crecen),
y se etiqueta como no demostrada. Bajo carga `λ = 3` la caída se mide hasta `D = 4` (5,8·10⁻⁷) y
`sirve de contraste` de que la forma funcional se conserva.

## 6 · Procedencia y defectos corregidos durante la construcción

- **Reutilización, no reimplementación:** `src/AnclaInyeccion.jl` incluye sin modificar
  `modelo.jl`, `referencia.jl`, `rapido.jl` y `validacion.jl` de GDR-v0.2. Las huellas de esos
  archivos están en `HUELLAS.sha256`.
- **Defecto 1 (corregido):** la primera versión comparaba cadenas en **espacios de índices
  distintos** (índices locales del observador contra índices globales de la referencia), lo que
  producía divergencias espurias a profundidades arbitrarias. Se corrigió con el mapeo inverso
  `local→global` (`EstadoObs.gid`) y un diagnóstico dedicado (`diagnostico_corte`). Los resultados
  publicados son posteriores a la corrección.
- **Defecto 2 (corregido):** `maxB` se dimensionaba con el valor medio de Poisson y desbordaba en
  colas raras; ahora se dimensiona con el número exacto de creaciones ya muestreado.
- Los diagnósticos `diagnostico_corte`/`diagnostico_detalle` se conservan en `src/medicion.jl`
  porque fueron los que localizaron el defecto 1.

## 7 · Qué podría invalidar el resultado

- Que la política real de selección de puntas difiera de «hasta 15 puntas de la vista» y produzca
  bifurcaciones más persistentes (no cubierto; LAGUNA declarada).
- Particiones, eclipse o un adversario de red: **fuera del modelo**. Una partición de duración `F`
  puede inducir reorgs de profundidad ~`λF`, que este instrumento no mide.
- Cambios de régimen que aumenten mucho `λΔ` (la sensibilidad `λ = 3` ya mueve `D_min` de
  `(1,3,4)` a `(2,4,6)`).
