# CIFRAS — CRP-v0.1 · una fila por cifra publicada

**Alcance.** Todas las cifras de `veritas/seguridad/coste-rama-privada-v1/INFORME.md`,
`PROPUESTA.md` y `PROCEDENCIA.md`. La columna «estado» usa el vocabulario del encargo:
**se sostiene / cambia / cae / no determinable**. Los recálculos son de
`auditoria/veritas/seguridad/crp1-defectos-v1/` (Julia CPU); la reproducción de lo publicado es de
`auditoria/copia/`.

**Defectos:** D1 cadena por DAG · D2 masa y unidades de la DP · D3 empate vs superación ·
D4 `λ ∝ SR` supuesto · D5 controlador real · D6 rojos asimétricos · D7 multistream tautológico ·
D8 fixture U2/U3″ · D9 `S=24` · D10 «ataque gratis» · D11 tabla GDR sin incertidumbre ·
D12 las dos medidas de trabajo difieren · D13 tope silencioso · D14 tolerancia de validación.

---

## A · `INFORME.md`

| # | cifra publicada | valor publicado | defectos | valor recalculado (con error) | estado | método del recálculo |
|---|---|---|---|---|---|---|
| A1 | `α_mínimo` medio, PoW lineal / GHOSTDAG-PoW / PoST-DAG, dos regímenes | `1/2` «exacto» | D4, D5, D6 | `1/2` como **frontera de deriva del modelo contable de media**; rodeada por un residuo de paridad ≤ 4,9e-4 (`SR ≥ 2^11`) y por la varianza de D5 | **se sostiene** (cambia la etiqueta «exacto/demostrado») | contabilidad exacta `α(1+sirv)=1−α`; contraste PCO-v0.1 |
| A2 | invariancia `(sr/sr0)·(w(sr)/w(sr0))`, `error_rel` máx | `1,33e-14` | D4 | `1,33e-14` es el residuo del **suelo**; el **déficit de paridad** `1/(sr+1)` (hasta 4,878e-4 con `SR=2049`; 1/2 con `SR=1`) **no estaba contado** | **cambia** | `Rational{BigInt}` exacto `T(sr)=2⌊sr/2⌋+1)/2^64·⌊2^128/(sr+1)⌋` |
| A3 | trabajo exacto `s=3/10`, `sr ∈ {sr0/8…8·sr0}`, `max/min` | `1,000000000000007` | D4 | mismo valor (es el mismo cociente de suelos); **no cubre** la paridad | **se sostiene** | `Rational{BigInt}`, `copia/src/referencia.jl:35-39` reproducido |
| A4 | work/slot con GDR, `s ∈ {0,1;0,3;0,5}`, `sr ∈ {sr0,4sr0}` | «≈ `s`» (0,0700 / 0,1013 / 0,3350 / 0,2675 / 0,4800 / 0,4850) | D1, D11 | el objeto medido es una **cadena** (`n_puntas=1`, `ms_max=1`), no un DAG; los errores relativos llegan a **−30,0 %** con `n=14` bloques y **ningún IC** | **cae** | `gdr-d1-d8.jl` (a) con GDR-v0.2; recuento de puntas y mergesets |
| A5 | tabla `α_mínimo(d, ε=0,10)`, `d = 3, 6, 12, 24, 50` | `0,317 / 0,405 / 0,452 / 0,476 / 0,489` | D3 | `0,359935 / 0,418498 / 0,455835 / 0,476990 / 0,488715` (evento **estricto**) | **cambia** | `α_min = 1/(1+ε^(−1/(d+1)))`, exacto; `run.jl --d3` |
| A6 | límite `α_mínimo(d,ε) → 1/2⁺` | `1/2⁺` | D3 | converge a `1/2` **desde abajo**: `0,488489 (d=50) < 0,494244 (d=100) < 0,499424 (d=10³) < 0,499942 (d=10⁴)` | **cae** (la etiqueta) | sucesión exacta; `run-corto.txt:49` dice además «por arriba» |
| A7 | tabla `P(alcance)` por granularidad, `α=0,4`, `d=6`, `g = 1,4,16,64,256` | `8,0e-2 / 6,6e-2 / 4,2e-2 / 1,3e-2 / 3,2e-26` | D2 | ruina exacta ±1: **`8,779e-2 / 5,940e-5 / 1,245e-17 / 2,404e-68 / 3,341e-271`**; DP Poisson con masa conservada: **`8,0089e-2 / 4,4340e-5 / 5,9667e-18 / 4,9863e-69 / 1,9548e-272`**; cota rigurosa superior = ruina exacta | **cae** en `g=4,16,64,256` | `Rational{BigInt}` + DP de masa conservada + martingala; `run.jl --d2` |
| A8 | masa retenida por el corte 0…60 de la pmf | **no publicada** | D2 | `1,000000 (g=1,4,16)`; `0,999537 (g=64)`; **`2,312e-23 (g=256)`** | **cae** (por omisión: la masa cruda no se publicó) | `pmf_cambio_neto` del propio instrumento, reproducida |
| A9 | régimen LARGO: «no hay descuento long-range», `α > 1/2` | `α > 1/2` | D4 | mismo valor bajo los supuestos de `MODELO.md` (flujo PoT único, un reto por slot) | **se sostiene** condicionado | contabilidad de medias; el supuesto del flujo lo ataca el multistream |
| A10 | comparación de protocolos, columna `α_min(d=6, ε=0,1)` | `0,405` en las tres filas | D3 | **`0,418`** | **cambia** | `α_min = 1/(1+ε^(−1/7))`; `run.jl --d3` |
| A11 | E[trabajo_adv] en la tabla de varianza | `179,9 / 179,7 / 180,9 / 178,0` | D5 | **`180,0` en los cuatro `K`** (exacto: `μ_a·w(sr_a)/w(sr0) = α·T`) | **se sostiene** | convolución exacta; `run.jl --d5` |
| A12 | `P(adv > hon)`, `α=0,45`, `T=400`, `K = 1,4,16,64` | `0,022 / 0,097 / 0,244 / 0,308` | D5 | **`0,021302 / 0,095029 / 0,227470 / 0,314998`**; IC 99,9 % Hoeffding de una corrida de 4000 réplicas: ±0,052; sd de una corrida: 0,0022 / 0,0037 / 0,0067 / 0,0069 | **cambia** (dentro de ≤ 2,4σ; `K=16` es el valor de cola de la semilla fija) | convolución exacta de dos Poisson compuestos, pesos enteros; validada contra MC (40 000 réplicas, semillas no consecutivas) |
| A13 | «coste marginal de recurso del ataque = 0» / «el ataque es gratis» | `0` / «gratis» | D10 | sólo se sostiene **«cero espacio plotteado adicional»**; CPU/PoT/IOPS, energía, recompensas y tarifas renunciadas, duración y capital hundido **no están contabilizados** | **cae** | `run.jl --d10`, contabilidad por término |
| A14 | `coste_op(PoST)/coste_op(PoW) → T_retención/T_a` | `→ 0` (reorg corta), `= 1` (long-range) | D6, D10 | `T_retención ≈ Δ·conf` no está derivado y `Δ` es simulada; sin datos de red no se puede cerrar | **no determinable** | lectura de `INFORME.md:110-120` y `run.jl:259-269` |
| A15 | multiplicidad `m` (D6 del encargo 07): `α*` independiente de `m` | `α* = 1/2` | — | exacto: `m·α` contra `m·(1−α)` ⇒ `α* = 1/2` | **se sostiene** | contabilidad exacta; `run.jl --teoria` reproducido |
| A16 | tabla multistream `α_min`, `S = 2,4,8,16,24` | `0,333 / 0,200 / 0,111 / 0,059 / 0,040` | D7, D9 | la aritmética `1/(S+1)` es exacta y la cuota aditiva se anula en `α=1/2`; **no** hay ninguna medición de que `S` flujos se sumen | **se sostiene** como identidad **condicional** | `S·α/(1−α+S·α)=1/2 ⟺ α=1/(S+1)` |
| A17 | misma tabla, etiqueta «el único vector **medido** que baja el umbral» | «medido» | D7 | no se midió ningún flujo: se evaluó una fórmula | **cae** (la etiqueta) | lectura de `test/runtests.jl:72-76`; el test compara la fórmula consigo misma |
| A18 | U2/U3″: mismo billete dos veces **dentro** de una rama | «válidas, pero 1 azul y 1 `rojo_U3`» | D8 | `copia/src/rapido.jl:342-354` mide `azules_ident7 = 1` y `rojo_U3 = 1` con GDR-v0.2 | **se sostiene** | reproducido con GDR-v0.2 (`gdr-d1-d8.jl`) |
| A19 | U2 rechaza el mismo billete en el pasado | «rechazado (`:u2`)» | D8 | `copia/src/rapido.jl:357-361`, motivo `:u2` | **se sostiene** | reproducido con GDR-v0.2 |
| A20 | mismo billete en **dos ramas disjuntas**: «ambas válidas y **azules en su propia rama**» | ambas azules | D8 | la **validez** se mide; el **color** se acredita con `es_ancestro_rapido(est3, x, x)`, que es `true` por el `\|\|` (`GDR src/rapido.jl:43`) | **cae** (la parte de color) | `gdr-d1-d8.jl` D8(a) |
| A21 | un fusionador ve una azul y la otra `rojo_U3` | «true» | D8 | `az_X ⊻ az_Y` y `tipos == 0x02` se miden de verdad | **se sostiene** | `copia/src/rapido.jl:371-378` |
| A22 | suite `--check-bounds=yes` | **45/45** | — | **45/45** con Julia 1.13.0 desde la copia | **se sostiene** (reproducido) | `salidas/repro-tests.txt` |
| A23 | `HUELLAS.sha256` desde la raíz | exit 0 | — | exit 0 (55/57 contra GDR; los 2 fallos son `SPEC.md`/`TAREAS.md`, fuera del instrumento) | **se sostiene** | `PROGRESO.md` |
| A24 | kernel `simular_rama_rapido` (1000 slots) | 896 B / 26 allocs | D13 | no reejecutado; mi propia medición equivalente está en `resultados/BENCH.txt` | **no determinable** | no reproducido en el entorno original |
| A25 | `barrido_alpha` (3 α, 200 rep, 300 slots) | 0,61 ms / 1,1 MB / 8 hilos | — | no reejecutado | **no determinable** | idem |
| A26 | escalado `barrido_alpha` 1→24 hilos | `0,272 → 0,051 s` (×5,3), resultados **idénticos** | — | verificado en `ESCALADO.txt`: `0,2722 → 0,0513 s`, resultados idénticos en los siete puntos | **se sostiene** (reproducido de artefacto) | lectura de `resultados/ESCALADO.txt` |
| A27 | `@code_warntype` sin `Any` en el kernel | «sin Any» | — | no reejecutado | **no determinable** | `resultados/WARNTYPE.txt` sólo inspeccionado |
| A28 | Δ de red | `Δ_50` sub-segundo; `Δ_100 ≤ ~2,2 s` en ER grandes | D6 | coherente con `delta-medido-v1/INFORME.md:111-123`; **es una simulación** (`MR` = ninguna disponible), no una medida de red | **se sostiene** como cita; **cambia** la etiqueta si se llama «medida» | lectura de `delta-medido-v1/INFORME.md` |
| A29 | veredicto final: «ZEROX está **en la liga de PoW**» | «en la liga de PoW» | D4, D5, D6, D7 | prohibido por `ENCARGO-07v2:145` mientras quede una hipótesis necesaria pendiente; quedan al menos cuatro | **cae** | regla del encargo vigente |

---

## B · `PROPUESTA.md`

| # | cifra publicada | valor publicado | defectos | valor recalculado | estado | método |
|---|---|---|---|---|---|---|
| B1 | P1: amplificación de trabajo con `sr_val ≠ sr_peso` | `16×` para `sr_val/sr_peso = 16` | D4 | exacto: `s·(sr_val/sr_peso)`; con `s=0,3` y `16` da `4,8` | **se sostiene** | aritmética exacta; `run.jl --controladores` reproducido |
| B2 | P2: «`P(adv>hon)` sube de `2,2 %` (`sr=sr0`) a `30,8 %` (`sr=sr0/64`)» | `2,2 % → 30,8 %` | D5 | **`2,130 % → 31,500 %`** (exacto) | **cambia** | convolución exacta; `run.jl --d5` |
| B3 | P4/P5: `α_mínimo = 1/2` (media, ambos regímenes) | `1/2` | D4 | mismo valor como frontera de deriva de media | **se sostiene** (etiqueta corregida) | contabilidad exacta |
| B4 | P5: multistream `α_min = 1/(S+1)` | `1/(S+1)` | D7 | identidad correcta **condicionada** a que la cuota sea aditiva | **se sostiene** condicionado | despeje exacto |
| B5 | P5: «el problema de la poda/IBD es de ingeniería, no de umbral» | «ingeniería» | D4, D5, D6, D7 | no determinable: depende de cuatro hipótesis pendientes | **no determinable** | — |

---

## C · `PROCEDENCIA.md`

| # | cifra publicada | valor publicado | defectos | valor recalculado | estado | método |
|---|---|---|---|---|---|---|
| C1 | §1 suite `--check-bounds=yes` | 45/45 ✓ | — | 45/45 | **se sostiene** (reproducido) | `salidas/repro-tests.txt` |
| C2 | §1 `HUELLAS.sha256` desde la raíz | exit 0 ✓ | D15 | exit 0; el fichero incluye rutas fuera del directorio, así que sólo verifica desde la raíz (lo advierte el propio fichero) | **se sostiene** con matiz | `PROGRESO.md` |
| C3 | §1 `α_min = 1/(S+1)`, `S = 2…24` | «exacta» ✓ | D7 | exacta como identidad; no demuestra sumabilidad de flujos | **se sostiene** condicionado | `run.jl --d7` |
| C4 | §1 curva `α_mín(d,ε) = 1/(1+ε^{−1/d})`, `d = 3…50` | «exacta» ✓ | D3 | exacta **para el evento de empate**; el contrato pide el estricto | **cambia** | `run.jl --d3` |
| C5 | §1 cancelación `SR`: tasa `∝ SR`, peso `∝ 1/SR`, «verificada» | ✓ | D4 | la cancelación se sostiene en el orden dominante; la «verificación» es circular y omite la paridad | **cambia** (la etiqueta) | contraste con PCO-v0.1 + predicado exacto |
| C6 | §1 `Project.toml` 9 dependencias, sólo las usadas | ✓ | — | `src/` usa `StableRNGs`; `bench/` usa `BenchmarkTools`, `InteractiveUtils`, `Profile`; `test/` usa `Test`. Todas usadas | **se sostiene** | inspección de `Project.toml` y de los `using` |
| C7 | §3.1 `α_mínimo = 1/2` exacto, «identidad no estadística» | `1/2` | D4 | `1/2` de media, sí; «identidad» sólo bajo el supuesto `λ ∝ sr` (D4) | **se sostiene** (etiqueta corregida) | contabilidad exacta |
| C8 | §3.1 «`P(adv>hon)` sube de 0,022 a 0,308 con `K=64`» | `0,022 → 0,308` | D5 | `0,021302 → 0,314998` | **cambia** | convolución exacta |
| C9 | §3.2 frontera `α > (1−f)/(2−f)` | fórmula | D6 | exacta; verificada término a término | **se sostiene** | álgebra exacta; `run.jl --d6` |
| C10 | §3.2 tabla rojos asimétricos | `0,5000 / 0,4995 / 0,4784 / 0,4166` | D6 | `0,500000 / 0,499498 / 0,478384 / 0,416590` | **se sostiene** | `(1−f)/(2−f)` exacto |
| C11 | §3.2 «La Δ **medida** … es 0,26–0,60 s» | «medida» | D6 | el valor está en `delta-medido-v1/INFORME.md:413`; su etiqueta es **medida en simulación** (`MR` = ninguna disponible); `P-2.1/SINTESIS.md:28`: «La Δ es simulada (DMS-v0.1), no medida en red» | **cae** (la etiqueta) | lectura de las tres fuentes |
| C12 | §3.2 «unas **25 veces** por debajo del primer escalón» | `25×` | D6 | con los números citados: `4/0,60 = 6,7×` y `4/0,26 = 15,4×`. Para 25× hay que usar el **último** escalón (16 s) | **cae** | aritmética sobre las cifras de la propia frase |
| C13 | §3.2 tabla de fracciones rojas `0,0000 / 0,0020 / 0,0828 / 0,2858` @ Δ=4/8/12/16 s | «ronda 11a» | D6 | están en `research/scripts/d9-ronda9a/r9a_a6_frontera_delta.py:31` (`DELTA0_MEDIDO`) y las reproduce `d9-ronda11a`; son simulaciones históricas con Δ fijada a mano | **se sostiene** como cita de simulación; **cambia** el origen (ronda 9a, no 11a) | `grep` en `research/scripts/d9-ronda9a/` y `d9-ronda11a/` |
| C14 | §3.3 tabla multistream | `0,333 / 0,200 / 0,111 / 0,059 / 0,040` | D7 | identidad `1/(S+1)` | **se sostiene** condicionado | despeje exacto |
| C15 | §3.3 «`S ≈ 24` es el límite de IOPS de un SSD de 100 k» | `24` | D9 | `⌊100000/4161⌋ = 24`: una **cota aritmética citada**; `4161,0` = «lecturas_4TiB» en `ancla-inyeccion-v2/src/puerta.jl:62` y `puerta-cobertura-v1/src/cobertura.jl:40`. El v1 **no mide** IOPS | **cae** | rastreo del origen; `test/runtests.jl` T11 |
| C16 | §3.3 «Coste: `S` núcleos más IOPS, cero espacio adicional» | «cero espacio adicional» | D10 | sólo el espacio está modelado; CPU/PoT/IOPS, energía, recompensas, duración y capital hundido no | **cae** (parcialmente) | `run.jl --d10` |
| C17 | §4.1 corrección de la cuenta: publicar exige `α > 1`, no `0,5` | `α > 1` | — | correcto: con publicación la honesta acumula `1` y el adversario `α` | **se sostiene** | `umbral_medio(; publica=true)` reproducido |
| C18 | §5 «R-FIN-13′ no está especificado; curva corta inconclusa» | «inconclusa» | D5 | correcto y conservado | **se sostiene** | lectura de `PROPUESTA.md` P4 |
| C19 | §5 «`F = 2 h` no se usa en ninguna cifra» | — | — | comprobado por `grep`: `F = 2h` no aparece en `src/`, `run.jl`, `INFORME.md`, `MODELO.md` | **se sostiene** | `grep` |
| C20 | §3.1 encabezado «El umbral es `1/2`, igual que PoW» | — | D4, D5, D6, D7 | prohibido por `ENCARGO-07v2:145` mientras quede una hipótesis pendiente | **cae** | regla del encargo |
| C21 | §0 «el único cuyo veredicto principal sobrevive a la validación sin recortes» | «sin recortes» | D1–D11 | sobrevive **una** frase (`α*=1/2` de media); el paquete de cifras y etiquetas no | **cae** | este informe |

---

## D · Defectos adicionales (cifras nuevas)

| # | cifra | valor | defecto | estado | método |
|---|---|---|---|---|---|
| D-1 | error relativo de la tabla GDR «work/slot ≈ s» | hasta **−30,0 %** con `n=14` bloques | D11 | **cae** la presentación sin incertidumbre | `run-gdr.txt` reproducido |
| D-2 | diferencia entre `medir_rama` y `medir_rama_normalizada` | exactamente `w(v)` | D12 | nueva | lectura de `GDR src/rapido.jl:183-188` y `GDR src/modelo.jl:249` |
| D-3 | tope de bloques por slot en `construir_rama_gdr` | `min(k, 200)`, no declarado | D13 | nueva | `copia/src/rapido.jl:211` |
| D-4 | tolerancia de validación DP vs ruina exacta | factor **20** (`0.05 < dp/ex < 50`) | D14 | nueva | `copia/test/runtests.jl:43` |
| D-5 | ruta citada en `--fuentes` que ya no existe | `deepseek/veritas/consenso/prueba-recursiva-v1/INFORME.md` — **FALTA** | D15 | nueva | comprobación desde la raíz |
| D-6 | autocorrelación lag-1 de `StableRNG(semilla+i)` | **−0,4275** (P-PUERTA: «≈ −0,43») | — | **confirmado**; su efecto en el estimador de D5 es **< 6e-4**, por debajo del ruido | `run.jl --d5` |
| D-7 | sesgo de MC del esquema consecutivo en la tabla de varianza | ≤ 6e-4 (media de 60 semillas × 4000 réplicas frente al exacto) | — | **medido, no significativo** | `salidas/` y `auditoria/copia` `efecto_varianza_sr` |

---

## E · Cifras de esta auditoría (para trazabilidad)

| magnitud | valor | unidad | definición | fuente | adversario | criterio de aceptación | estado |
|---|---|---|---|---|---|---|---|
| `T(sr)` | `(2⌊sr/2⌋+1)/2^64·⌊2^128/(sr+1)⌋` | trabajo/ensayo / 2^64 | predicado PoAS circular + C-GD-01 | `PDF/autonomys-subspace` vía PCO-v0.1 | — | idéntico a enumeración exhaustiva en dominios pequeños | **demostrado** |
| déficit de paridad | `1/(sr+1)` si `sr` impar | relativo | `A(sr)=sr` vs divisor `sr+1` del peso | PCO-v0.1 `MODELO.md:41-62` | adversario elige paridad | `Rational{BigInt}` exacto | **demostrado** |
| cota de martingala | `(α/(1−α))^{d·g}` | probabilidad | `E[z^X]=1` con `z=α/(1−α)` | este trabajo | paseo compuesto de Poisson | residuo `\|E[z^X]−1\| < 1e-76` | **demostrado** |
| `P(alcance)` corregida | ver A7 | probabilidad | DP de masa conservada, retícula `1/g` | este trabajo | `α=0,4`, `d=6` u.t. | estable a 15 dígitos al ×6 la ventana; bajo la martingala | **recalculado** |
| `P(adv>hon)` | ver A12 | probabilidad | convolución exacta de dos Poisson compuestos | este trabajo | `α=0,45`, `T=400` | dentro del IC 99,9 % de un MC de 40 000 réplicas con semillas no consecutivas | **recalculado** |
| `α_min` estricto | ver A5 | fracción | `(q/p)^(d+1)=ε` | este trabajo | — | sistema racional + enumeración independientes | **demostrado** |
| `S_adversario` | **no determinado** | flujos | capacidad de abrir flujos PoT | — | adversario con hardware real | requeriría perfil de I/O | **no determinado** |
| `Δ` | 0,26–0,60 | s | Δ_99 p99 en red **sintética** | `delta-medido-v1/INFORME.md:413` | red honesta simulada | `MR` (medida en red ZEROX): ninguna disponible | **medido en simulación** |
| coste del ataque | **no determinado** | — | modelo económico completo | — | adversario con capital hundido | D10 exige seis términos; sólo uno está modelado | **no determinado** |
