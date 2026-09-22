# HIPÓTESIS QUE CODIFICAN LA CONCLUSIÓN — permanencia-v1

**Qué es esto.** Las afirmaciones del `INFORME.md` no se sostienen con prosa: se sostienen con un
modelo cuyas predicciones se pueden falsar. Aquí se escriben **antes** de mirar los números las
hipótesis que el instrumento codifica, qué salida las refutaría y qué se midió de verdad.

**Entradas de las que cuelga todo** (ver `mediciones/hardware.tsv`; ninguna es una decisión de
consenso): `t_tabla = 0,809 s/pieza` · `r = 25,03 tablas/s` (16 núcleos, mejor agregado medido) ·
`w = 7.175` y `4.830,6` slots (ventana medida, con y sin segunda línea VDF) · `bytes_pieza =
1.048.672` · `o = 0,5` · `20 TB ≈ 19,07·10⁶ piezas` · escenario GPU `17×` **no medido**.

---

## H1 · E2 (aperturas por muestreo) cae ante la regeneración, y cae *estructuralmente*

**Hipótesis.** El coste de un tramposo en E2 es `c` tablas **por auditoría**, no `c·N`: es
independiente del tamaño del lote `N`. Por tanto el coste por TiB simulado tiende a cero y ningún
`(c, D_a)` fijo lo detiene.

**Predicción falsable.** `cpu_sin_ventana(c, D_a)` no depende de `N`; y con la ventana medida `w`,
`cpu_con_ventana(c, w) = c/(r·w)` es aún menor. **Se refuta** si aparece cualquier dependencia con
`N` en la tabla `E2-plazo.tsv` o si `(c, D_a)` con `c ≤ r·D_a` no cabe.

**Resultado medido con el modelo:** para `c=1000, D_a=60 s` hacen falta **0,666 CPU** (16 núcleos)
sin ventana y **0,0056 CPU** con la ventana medida; para `c=10⁵` con `D_a=600 s`, 6,66 y 0,557.
El honesto con HDD sirve 6.000 aperturas en 60 s (100/s); el tramposo necesita 1/25 de eso por
CPU. **H1 confirmada.**

---

## H2 · La obligación de E3 es *por ventana*: `N/(r·w)` CPU continuas

**Hipótesis.** Producir las parciales de un lote de `N` piezas exige recorrer el lote entero; con
`w` slots de adelanto, el tramposo lo regenera **una vez por ventana** y reparte las respuestas.
Coste continuo = `N/(r·w)` CPU; almacenamiento forzado = `max(0, 1 − r·w/N)`.

**Predicción falsable.** `e3_cpu_por_TiB(w) = (piezas/TiB)/(r·w)` y `e3_almacenamiento_forzado`
crecientes en `N` y decrecientes en `w`; cruce `w* = N/r` para fabricar el lote entero.
**Se refuta** si el cruce no coincide con `N/r` o si el coste no escala como `1/w`.

**Resultado:** `w=7.175` ⇒ **0,1713 TiB** fabricables por CPU ⇒ **5,84 CPU/TiB** y **82,9 %** de
almacenamiento forzado en un lote de 1 TiB. `w=4.830,6` (con VDF) ⇒ 8,67 CPU/TiB y 88,5 %.
Cruce del lote de 1 TiB en `w = 41.889` slots; cruce de un disco de 20 TB en **`w = 837.779`
slots**; cruce de 1 PiB en `w = 4,72·10⁷`. **H2 confirmada.**

---

## H3 · El escenario GPU borra la garantía en lotes pequeños

**Hipótesis.** El factor `17×` de la documentación de Autonomys (nunca medido) reduce el coste a
**0,343 GPU/TiB** a `w=7.175`, de modo que **una sola GPU fabrica 2,91 TiB** por ventana: cualquier
lote ≤ 2,9 TiB es íntegramente fabricable sin almacenar.

**Predicción falsable.** Si `r_gpu = 17·r_cpu`, entonces `e3_TiB_por_cpu(w=7175) ≈ 2,9` y el
almacenamiento forzado de un lote de 1 TiB vale 0. **Se refuta** si el cociente no es 17 o si el
almacenamiento forzado no se anula.

**Resultado:** `E3-ventana.tsv` fila `gpu_17x_documentacion_NO_MEDIDA`, `w=7.175`: 2,9119 TiB por
GPU, 0,3434 GPU/TiB, **forzado de 1 TiB = 0**. **H3 confirmada**, con la etiqueta de que el `17×`
es **documentación ajena nunca medida**, no una entrada medida.

---

## H4 · La agregación en cadena por muestreo NO colapsa la obligación… salvo por la ventana

**Hipótesis.** «Comprometer las `λ` parciales del periodo y abrir `k` al azar» obliga a tener
`(1−γ)^{1/k}` de la mezcla real: con `k=1` ya exige el 99 %, con `k=10` el 99,9 %. **Pero** si las
`k` posiciones se conocen `w` slots antes (el reto sale del PoT, que es público), el tramposo
regenera **solo esas `k`** piezas: coste `k/(r·P)` CPU, **independiente de `N`**.

**Predicción falsable.** `e3_mezcla_necesaria(k,γ) ≥ 0,98` para `k=1`; `e3_pasa_muestreo` cae como
`(m/λ)^k`; y `e3_cpu_agregacion_con_ventana(k,P,w) < 0,01` CPU para `k=10, P=100, w=7.175`.
**Se refuta** si el muestreo exige poca mezcla o si la ventana no abarata la agregación.

**Resultado:** `k=1, γ=10⁻²` ⇒ mezcla necesaria **0,99**; `k=10` ⇒ **0,99899**;
`cpu_agregacion_con_ventana(10; P=100, w=7.175) = 0,0040` CPU y **1.047.427 piezas escaneadas**
(~`N`) sin ventana. **H4 confirmada.** Consecuencia: **la obligación de E3 solo sobrevive si
TODAS las parciales quedan ligadas**, no si se muestrean con posiciones predecibles.

---

## H5 · La estadística de E3 distingue tamaños, con las colas exactas

**Hipótesis.** Con `λ = N·qP` parciales por periodo, el test «rechazar si `X ≤ K`» con
`K = max{k : P(Poisson(λ) ≤ k) ≤ β}` tiene falso fallo `≤ β` para el honesto con disponibilidad
`a=1`, y potencia `≥ 1−γ` contra `Poisson(sλ)`. En lotes pequeños la **Poisson no es la
referencia**: la binomial exacta lo es.

**Predicción falsable.** Potencia monótona en `T`; `P(Poisson)` contenida en el intervalo
riguroso; discrepancia Poisson↔binomial dentro de la cota de Le Cam `2np²`. **Se refuta** si la
potencia no es monótona, si el intervalo no contiene al oráculo exacto o si la discrepancia supera
la cota.

**Resultado:** intervalo vs `Rational{BigInt}` exacto: error relativo máximo **7,1·10⁻⁷⁶**,
contención **sí**; Poisson vs binomial exacta: discrepancia máxima **1,52·10⁻³** con cota de Le Cam
**4,0·10⁻²**, dentro; potencia monótona en `T` = **sí**. Para 1 TiB con `λ=10,48`: `s=0,5` se
distingue en **T=9** periodos y `s=0,9` en **T=268**. **H5 confirmada.**

---

## H6 · El falso fallo del honesto con `a<1` es exigible pero no gratis

**Hipótesis.** Un honesto con disponibilidad `a<1` tiene media `aλ`; el falso fallo por
evaluación es `P(Poisson(aλ) ≤ K) ≤ β` solo si `K` se recalibra a `a`. Con `K` calibrado a `a=1`,
el falso fallo crece con `1−a` y se acumula con los periodos.

**Predicción falsable.** `falso_fallo(a=0,99) > β` en algún régimen; creciente al bajar `a`.
**Se refuta** si el falso fallo no supera `β` para todo `a<1`.

**Resultado:** para 1 TiB y `s=0,9` (T=268), falso fallo del honesto con `a=0,99` = **5,17·10⁻³**
frente a `β=10⁻³`: 5,2× el objetivo. Con `a=0,5` el test no es utilizable sin recalibrar.
**H6 confirmada.**

---

## H7 · E5 mide la ausencia por varianza, no por prueba

**Hipótesis.** Con «farmear y nada más», la desaparición de una parcela se nota cuando el granjero
deja de ganar: `T = −ln(β)/(σλ)` slots. No hay prueba de permanencia, solo inferencia estadística.

**Predicción falsable.** `T` inversamente proporcional a `σ`; con `σ=10⁻⁴` y `λ=1`, `T≈6,9·10⁴`
slots. **Se refuta** si `T` no escala como `1/σ`.

**Resultado:** `σ=10⁻²` ⇒ **691 slots** (11,5 min); `σ=10⁻⁴` ⇒ **69.078 slots** (19,2 h);
`σ=10⁻⁵` ⇒ 690.776 slots (8,0 días). **H7 confirmada.**

---

## H8 · E1 no existe para el formato actual, y el instrumento no puede inventarla

**Hipótesis.** No hay prueba sucinta de cobertura completa del objeto caro (las tablas) en el
formato fijado: el compromiso de sector es KZG sobre la codificación de datos **públicos**, y las
tablas (`blake3(proof)`) no están comprometidas. Por tanto E1 se reduce a E4 (sellado) o a una
prueba de cómputo sobre `N` tablas, cuyo trabajo por TiB es `N·t_tabla`.

**Predicción falsable.** El trabajo de regeneración de 1 TiB es `848.220 s·núcleo = 235,6 h·núcleo`.
**Se refuta** si el compromiso de sector cubre el resultado caro o si existe una prueba sucinta
desplegada para este formato.

**Resultado:** `848.220 s·núcleo/TiB` (medido+derivado); el compromiso verificado es
`record_commitment` KZG contra el compromiso de segmento (código fijado). **H8 confirmada como
«no existe»**, no como «no puede existir»: no se encontró ninguna construcción utilizable.

---

## Lo que el instrumento NO codifica (y por tanto no decide)

- Ningún **precio**: la comparación «más barato que el disco» es en hardware (máquinas frente a
  discos), como en P-INTENTO §12.
- Ningún **parámetro de consenso**: `M`, `D_a`, `c`, el umbral de parciales, el periodo, `ρ_ret`,
  `T_v` y `w` son entradas de línea de comandos.
- Ninguna **medición nueva de hardware**: todas las cifras vienen de P-INTENTO, P-REVELACION y
  `research/coste-ploteo-medido.md`, con su etiqueta.
- Ninguna **garantía criptográfica**: el instrumento solo produce cotas económicas.
