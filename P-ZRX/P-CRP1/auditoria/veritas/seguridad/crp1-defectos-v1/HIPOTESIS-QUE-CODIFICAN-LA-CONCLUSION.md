# HIPÓTESIS QUE CODIFICAN LA CONCLUSIÓN — P-CRP1

Qué supone cada recálculo de `auditoria/veritas/seguridad/crp1-defectos-v1/`, qué está
**demostrado** dentro del modelo y qué quedaría refutado si la hipótesis cayera. Sigue el formato
de `veritas/consenso/puerta-cobertura-v1/HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md`.

Regla de lectura: **una hipótesis sólo cuenta como hipótesis si su falsedad cambiaría una
conclusión publicada.** Las que son definiciones o aritmética exacta se marcan `[no es hipótesis]`.

---

## H-PREDICADO · el predicado de aceptación PoAS

```text
El predicado es: distancia CIRCULAR en Z_{2^64}, acepta si solution_distance ≤ solution_range ÷ 2
(división entera), y por tanto el número de residuos aceptados es A(sr) = 2⌊sr/2⌋ + 1.
```

- **Origen:** leído del código de Autonomys en PCO-v0.1
  (`veritas/consenso/puerta-cobertura-v1/src/peso.jl:39-61`, que cita
  `PDF/autonomys-subspace/crates/subspace-verification/src/lib.rs:150-158` y
  `.../subspace-core-primitives/src/solutions.rs:332-337`). **No lo abrí directamente en esta
  auditoría**: lo tomo de PCO-v0.1 como fuente citada.
- **Qué sostiene:** D4 (el déficit de paridad `1/(sr+1)`), y el valor exacto de `T(sr)`.
- **Estado dentro del modelo:** `A(sr) = 2⌊sr/2⌋+1` está **demostrado por enumeración exhaustiva**
  del círculo para dominios pequeños (`test/runtests.jl` T1: 36 combinaciones, `M ∈ {16,64,129,1024}`,
  coincidencia exacta con la fórmula cerrada).
- **Si cae:** si ZEROX adopta otro predicado, `A(sr)` cambia, el residuo de paridad cambia y la
  cancelación puede dejar de ser cierta. **Afecta a D4 y, por la tasa, a todo lo demás.** La
  frontera `α* = 1/2` de media sobrevive mientras la tasa siga siendo `∝ 1/w(sr)`.

## H-UNIDADES · el déficit en la retícula

```text
`d` está en unidades de trabajo (u.t.); cada bloque pesa 1/g u.t.; en la retícula de paso 1/g
el déficit es z = d·g BLOQUES, no d.
```

- **Origen:** `ENCARGO-07v2` §D2 («si cada bloque pesa `1/g`, representar el déficit como `d·g`»).
- **Qué sostiene:** toda la tabla corregida de D2. Es la diferencia entre `6,6e-2` y `4,4e-5` en
  `g=4`.
- **Estado:** `[no es hipótesis]` — es la corrección que el encargo define, y es consistente con el
  propio modelo de CRP-v0.1 (`MODELO.md:62`, «`g` = bloques por unidad de trabajo»).
- **Si cae** (si `d` estuviera en bloques, no en trabajo): la tabla publicada sería correcta en
  unidades y sólo quedaría el defecto de masa, que sólo muerde en `g=256`. **Es la hipótesis más
  consecuente de toda la auditoría**, y por eso está explícita y citable.

## H-MARTINGALA · `E[z^X] = 1` para el paseo compuesto de Poisson

```text
Con X = H − A, H ~ Poisson(g(1−α)), A ~ Poisson(gα) y z = α/(1−α):
E[z^X] = exp(g·[(1−α)(z−1) + α(z^{-1}−1)]) = 1.
Por tanto P(ever alcanzar el déficit 0 desde m bloques) ≤ z^m = (α/(1−α))^m.
```

- **Origen:** este trabajo. Demostrado algebraicamente (`run.jl`/`referencia.jl`) y **verificado
  numéricamente**: el residuo `|E[z^X] − 1|` es < 1e-76 para `g ∈ {1,4,16,64,256}`
  (`test/runtests.jl` T3), que es el límite de la precisión de 256 bits.
- **Qué sostiene:** el extremo superior del intervalo certificado de D2 y, con él, la **refutación**
  de `3,2e-26` para `g=256` (244 órdenes de magnitud por encima de la cota).
- **Estado:** `[no es hipótesis]`. Es una identidad.
- **Si cae:** no puede caer; es álgebra. Sí puede caer la **dirección de la cota** si la
  definición de «alcanzar» fuese distinta (p. ej. alcanzar estrictamente), pero entonces la cota
  sería `z^{m+1}`, aún más pequeña, y la refutación se mantiene.

## H-COMPUESTO · el paseo por slot es la diferencia de dos Poisson

```text
El trabajo del adversario y el de la honesta son procesos de Poisson compuestos independientes,
con tasa λ(s,sr) = s·λ0·sr/sr0 por slot y salto w(sr) por bloque.
```

- **Origen:** `copia/src/modelo.jl:11-16` y `copia/src/rapido.jl:35-39`.
- **Qué sostiene:** la tabla exacta de D5 y la columna «DP Poisson» de D2.
- **Estado:** **supuesto del modelo auditado**, no mío. Lo conservo para poder comparar con lo
  publicado. La columna «ruina exacta ±1» de D2 no depende de él.
- **Si cae:** la tabla de D5 cambiaría. La refutación de D2 (por la martingala) exige sólo que el
  incremento por bloque tenga peso `w(sr)`, no que el conteo sea Poisson. La identidad
  `E[z^X] = 1` se cumple para **cualquier** conteo con tasa `∝ sr`, porque sale de la
  cancelación `sr·w(sr) ≈ const`.

## H-PESOS-ENTEROS · la comparación de trabajo se hace con enteros exactos

```text
A_a·w(sr_a) > A_h·w(sr0) se evalúa con `BigInt`, no con Float64.
```

- **Motivo:** `w(sr0/K)/w(sr0)` es **exactamente** `K` sólo en el límite. Con `K = 1` los pesos son
  iguales y los empates tienen probabilidad **2,7e-3**, no nula. Clasificarlos con `Float64`
  cambiaría `P(>)` en ese orden.
- **Qué sostiene:** la tabla de D5 y la separación `P(>)` / `P(≥)` / `P(=)`.
- **Estado:** `[no es hipótesis]`; es control de error de redondeo.

## H-INDEPENDENCIA-D1 · la tabla de varianza no depende del DAG

```text
`efecto_varianza_sr` → `simular_raza` → `simular_rama_rapido` no toca GDR ni la estructura del DAG.
```

- **Verificado en fuente:** `copia/src/rapido.jl:77-94`, `:59-70`, `:25-57`.
- **Consecuencia:** el defecto D1 **no** contamina las cifras de D5. Es una conclusión del encargo
  («¿Depende del defecto D1?») y su respuesta es **no**.
- **Estado:** verificado, no supuesto.

## H-SEMILLAS · el esquema de semillas consecutivas sesga el Monte Carlo

```text
`StableRNG(semilla + i)` con i consecutivo produce flujos correlacionados entre réplicas.
```

- **Origen:** `P-ZRX/P-PUERTA/veritas/consenso/puerta-cobertura-v1/src/referencia.jl:291-292` y
  `METODO.md:118` («autocorrelación lag-1 de −0,43»).
- **Reproducido:** **−0,4275** con `n = 20 000` (`run.jl --d5`, `test/runtests.jl` T10).
- **Alcance limitado, y esto importa:** medido en **el estimador de D5**, el efecto sobre la media
  es ≤ 6e-4 y la desviación típica observada (0,00674 con `K=16`) coincide con la binomial
  (0,00663). Atribuir a este sesgo la diferencia de la tabla publicada sería un error: la
  diferencia se explica por ser el valor de cola de una semilla fija.
- **Qué sostiene:** la recomendación de usar semillas no consecutivas en los recálculos (usadas en
  `mc_varianza(..., modo=:hashed)`), y la **cota** a la magnitud del efecto.

## H-CG01 · la fórmula del peso

```text
w(B) = ⌊2^128/(SR+1)⌋  (C-GD-01)
```

- **Origen:** SPEC/C-GD-01, `copia/src/modelo.jl:28-31`. Reimplementado desde la fórmula.
- **Estado:** `[no es hipótesis]` a efectos de esta auditoría; comprobado contra los bordes
  `sr=0` (2^128) y `sr = 2^64−1` (2^64) en `test/runtests.jl` T1.

## H-ROJOS · el modelo de rojos asimétricos es una fracción global

```text
La honesta pierde una fracción f de su trabajo por rojos; el adversario no pierde nada. De ahí
α > (1−f)/(2−f).
```

- **Origen:** `PROCEDENCIA.md:50-62`.
- **Estado: ES UNA HIPÓTESIS FUERTE y no está medida.** D6 exige en su lugar una eficiencia
  `η_x(T) = E[Δ blue_work azul]/E[trabajo bruto elegible]` con ventana, punta/contexto de color y
  prefijo común, y señala que la frontera es normalmente una **raíz implícita**, no una constante
  reutilizable. Nada de eso está implementado en ninguna parte; `f` entra como fracción global.
- **Si cae:** la tabla `0,5000/0,4995/0,4784/0,4166` no es aplicable, y con ella la conclusión de
  `PROCEDENCIA.md` §3.2. La fórmula en sí (aritmética) es correcta; el modelo que la alimenta no
  está validado.

## H-DELTA · la Δ usada

```text
Δ ∈ [0,26; 0,60] s es una Δ de red ZEROX.
```

- **Falso según sus propias fuentes:** `delta-medido-v1/INFORME.md:1-9` («red sintética P2P»;
  `MR` = medida en red ZEROX: **ninguna disponible**) y `P-ZRX/P-2.1/SINTESIS.md:28` («La Δ es
  simulada (DMS-v0.1), no medida en red»).
- **Qué sostiene:** D6. Si la Δ real fuese del orden de 10 s o más, el efecto de rojos asimétricos
  **sí** movería el umbral (la tabla lo muestra: `f = 0,2858` a Δ = 16 s daría `α_min = 0,4166`) y
  habría que medirlo de verdad.
- **Estado:** hipótesis **no verificada**, con la etiqueta corregida a «simulada».

## H-S · la cuota del multistream es aditiva

```text
Con S flujos de PoT independientes, la cuota del adversario es S·α/(1−α+S·α).
```

- **Origen:** definición de CRP-v0.1 (`copia/src/modelo.jl:159`), no derivación.
- **Estado: ES LA HIPÓTESIS CENTRAL DE D7 y no está demostrada.** El test que la respalda compara
  la fórmula consigo misma (`copia/test/runtests.jl:72-76`). D7 enumera lo que faltaría:
  compatibilidad de `past(B)` por slot, prefijos comparados en `slot(X)`, `P(max_i{W_i−d_i} > W_pub)`
  con prefijo común contado una vez, controles de flujos idénticos e iid, y cotas de unión.
- **Si cae** (si el flujo PoT es único y anclado a finalidad): `α_min = 1/(S+1)` desaparece y con él
  «el único vector que baja el umbral» (`INFORME.md:135`).

## H-S24 · `S = 24`

```text
Un adversario puede abrir S ≈ 24 flujos de PoT.
```

- **Origen:** aritmética citada, `⌊100000/4161⌋ = 24`; `PROCEDENCIA.md:79` la llama «el límite de
  IOPS de un SSD de 100 k».
- **Estado: NO MEDIDA.** No existe `S_microbenchmark` ni `S_adversario` en el instrumento.
- **Qué sostiene:** la cifra `0,040` de la tabla multistream **como escenario**, no como capacidad.
  La parte paramétrica `P(α,S)` puede cerrarse condicionada a `S`; la afirmación económica sobre un
  adversario concreto, no.

## H-COSTE · «cero espacio plotteado adicional» ⇒ «ataque gratis»

- **Estado: REFUTADA como enunciado.** El §4 del informe sólo modela el espacio. CPU/PoT/IOPS,
  energía, recompensas y tarifas renunciadas, duración real y capital hundido **no están
  contabilizados** (D10). La conclusión admisible es «cero espacio plotteado adicional bajo los
  supuestos declarados».

## H-CADENA · `construir_rama_gdr` produce un DAG

- **Estado: REFUTADA, medida.** `n_puntas = 1` y `ms_max = 1` en todas las corridas; el control con
  vista local produce `max_puntas ∈ {3,4,8}`. Es un hecho, no una hipótesis.

---

## Lo que NO se supone (y conviene que conste)

- **No se supone que la auditoría tenga razón por venir de otro ejecutor.** Cada cargo se comprobó
  contra el código y cada cifra se recalculó con un método independiente; los falsos positivos y
  las hipótesis no verificadas están declarados.
- **No se supone que `PROCEDENCIA.md` esté equivocada en bloque.** Su corrección de la cuenta del
  encargo (`α > 1` al publicar) es correcta y se conserva; su tabla de rojos asimétricos es
  aritméticamente exacta; su declaración de límites (`PROPUESTA.md` P4, `INFORME.md` §9) es honesta.
- **No se supone que el encargo 07v2 tenga razón.** D6 está a medias (la fórmula y la conclusión se
  sostienen; la etiqueta y el «25×» no), y su §D2 identifica bien la masa pero no menciona el
  defecto de unidades como causa principal de la fila con `g > 1`.
- **No se hereda ningún veredicto** de CRP-v0.2 ni de v0.3, que no se auditan aquí.
