# INFORME (parcial, primera pasada) — ANCLA-v0.2 · P-2.1 v3

**Fecha:** 2026-09-19 ~04:05 CEST (enmendado ~04:15 tras ADENDA-2) · **Estado:** primera pasada
completada (ADENDA-1 §3): 4.A «de forma». **La sección 4.0 queda RETIRADA — ver §0.**
**4.B, 4.C, 4.D y la cola honda (ε=10⁻⁶/10⁻⁹) quedan para la segunda pasada.** Cada cifra con
etiqueta: `demostrado` / `derivado` / `medido` / `estimado` / `no demostrado` / `inconcluso`.

---

## 0 · La puerta 4.0: RETIRADA, sustituida por PCO-v0.1 (P-PUERTA/)

**RETIRADA** (2026-09-19, ADENDA-2 del validador). Defectos reconocidos: (1) el resultado
central estaba escrito a mano (`deriva_retarget = 0.0`, `t_abs_retarget = Inf` como constantes
literales: hipótesis que codifica la conclusión, sin estar en el archivo de hipótesis);
(2) la hipótesis era la equivocada para ZEROX: el retarget iguala la **tasa de bloques**, pero la
selección es por **`blue_work`** con `w = ⌊2^128/(SR+1)⌋`, peso elegido para que
`bloques/slot × peso/bloque = espacio·2^128/C` — **el SR se cancela y el peso crece ∝ al espacio
que cubre el flujo** (`fork-choice-poas.md:59-71`; mi «contrafactual» era el modelo correcto);
(3) `K=100` y el reparto `s₁=1` sin justificar; (4) «exacto-dp» no era exacto (discretización
dt=0,1 y magnitud distinta de la histórica); (5) `S_max_racional` fijaba UN SSD de 100 k IOPS
para cualquier capacidad (artefacto; la variable es IOPS por TiB).

**Lo que sí se sostiene, con etiqueta estrecha** (`derivado` por primeros principios): bajo
R-FIN-5 + R-FIN-7 **sin adopción**, una partición nacida es permanente **por construcción**, con
o sin cobertura. **Con adopción**, la deriva del peso es `∝ (1−c)(s₁−s₂)`: con cobertura total
(`c→1`) o reparto simétrico es nula y la partición se sostiene; con cobertura parcial y reparto
asimétrico el lado con más espacio gana en tiempo finito. **La pregunta de la puerta pasa a ser
cuánto vale `c` en equilibrio**, y eso sale de `condicion_cobertura` evaluada con costes reales:
territorio de **PCO-v0.1 (`P-PUERTA/`)** — fuera de este instrumento. La medición de 4.A (abajo)
queda intacta y no depende de 4.0.

---

## 1 · 4.A — G(d) = P(W_obs > d) y L_mín (primera pasada, «de forma»)

Instrumento: DAG GHOSTDAG con **GDR-v0.2 sin modificar**; ancla R-FIN-1 con el orden de
evaluación de §3.1 (punto fijo restringido a {slot < t_j}, con L_def como ventana); vistas de
observador cerradas bajo ancestros; V1 con clausura de publicación; unidad = réplica (una
época por réplica en células adversarias; 9 umbrales por réplica en honestas, IC por clúster
de réplica); desempate C-ORD-01 (bw, sd, id); Δ ∈ {nominal DMS sub-segundo, 4, 10, 16 s}
constante uniforme (componente parejas ≡ 0 por construcción en Δ constante — cota inferior
declarada). Semilla maestra 0x5A5A. Detalles en `MODELO.md`.

### 1.1 · Celdas y L_mín(ε) (ε=10⁻³ medido; 10⁻⁶/10⁻⁹ estimado por ajuste exponencial)

| Celda | réplicas | G_medio | L_mín(10⁻³) | L_mín(10⁻⁶) | L_mín(10⁻⁹) | r̂ | r_cal |
|---|---|---|---|---|---|---|---|
| hon-dms | 2000 | 0,0 | 0 `medido` | — | — | — | — |
| hon-4 | 2000 | 39,0 | 119 `medido` | 132 `estimado` | 132 `estimado` | 0,0748 | — |
| hon-10L | 2000 | 440,0 | **1 198 `medido`** | 1 282 `est` | 1 282 `est` | 0,0063 | — |
| hon-16L | 2000 | 663,8 | **1 682 `medido`** | 1 903 `est` | 1 903 `est` | 0,0045 | — |
| v1-a10 | 1000 | 14,1 | 56 `medido` | 81 `est` | 81 `est` | 0,109 | 0,400 |
| v1-a25 | 1000 | 10,3 | 47 | 49 | 49 | 0,142 | 0,134 |
| v1-a33 | 1000 | 7,9 | 39 | 40 | 40 | 0,169 | 0,0596 |
| v1-a40 | 1000 | 6,5 | 27 | 28 | 28 | 0,387 | 0,0202 |
| v1-a45 | 600 | 5,5 | 27 | 27 | 27 | 0,287 | 0,00501 |
| a3-a10 | 600 | 21,2 | 84 | 84 | 84 | 0,097 | 0,400 |
| a3-a25 | 600 | 42,5 | 134 | 134 | 134 | 0,064 | 0,134 |
| a3-a33 | 600 | 52,9 | 173 | 173 | 173 | 0,053 | 0,0596 |
| a3-a40 | 600 | 61,8 | 177 | 177 | 177 | 0,045 | 0,0202 |
| a3-a45 | 600 | 67,6 | **177 `medido`** | 177 | 177 | 0,041 | 0,00501 |
| v2-a25 | 300 | 12,5 | 48 | 48 | 48 | 0,123 | 0,134 |
| v2-a40 | 300 | 16,7 | 48 | 48 | 48 | 0,108 | 0,0202 |
| v3-a40 | 300 | 68,2 | 167 | 167 | 167 | 0,041 | 0,0202 |

(Los cortes de hon-10/hon-16 originales a ventana 600 quedan **superados**: censuraban el 14 % y
el 53 % de las réplicas; las celdas -L de ventana 2000 no censuran y las sustituyen.)

### 1.2 · Hallazgos de la primera pasada

1. **La forma de la cola es exponencial en todas las celdas, sin colas pesadas** (`medido` en el
   rango [1, 10⁻³]; por debajo, `estimado`). Ninguna vía de ataque (V1, V2, V3, A3) vuelve la
   cola pesada. La hipótesis natural del encargo se confirma.
2. **El honesto manda, no el adversario.** A Δ nominal (DMS, sub-segundo) G ≡ 0 en 18 000
   observaciones (cota 3/n al 95 %: G < 1,7·10⁻⁴). A Δ=4 s, L_mín(10⁻³)=119 slots. A Δ=10/16 s,
   **L_mín(10⁻³) = 1 198 / 1 682 slots** — los escalones de estrés deciden L, como anticipaba
   el encargo (el acantilado está en 10-20 s). Si L=1 h (3 600) provisional, cubre Δ=16 a 10⁻³
   con margen 2,1×; para 10⁻⁹ la extrapolación exponencial (r̂=0,0045) da ≈ 4 900 slots
   (~82 min) — `estimado`, no medido.
3. **A3 (entrega selectiva) es la vía más fuerte medida**: L_mín(10⁻³) crece con α hasta 177
   slots (α=0,45). V1 (retención + clausura) es débil en su familia medida — cola MÁS CORTA que
   la honesta a Δ=4 (56→27 slots) y MUY inferior a la tasa calibrada r_cal (r̂ = 0,11-0,39 vs
   0,40-0,005): **el steering por retención no alcanza la cota teórica de la carrera en esta
   familia** (`medido`; la razón no está demostrada: hipótesis — el bloque liberado se recolorea
   al recibirse con el anticono crecido y pierde la ventaja). **Con la etiqueta obligatoria de
   §1.4: tope de 8 candidatos y ventana [T, T+45] heredada ⇒ cota inferior del poder del
   atacante, no un veredicto sobre V1 sin límites.** V2 (cadena privada) ≈ V1; V3 (cadena
   privada + selectiva) ≈ A3 (167 vs 177): **V3 declarada «la más fuerte que encontré, no
   demostrada óptima»; A3 la iguala y es más simple.**
4. **Criterio de aceptación (reimplementado en Julia): SATISFECHO.** G cambia con α en todas
   las vías: baja con α en V1 (14,1→5,5) y sube en A3 (21,2→67,6); el degenerado α=1 (celda
   crit en la suite) da W_obs ≈ ventana completa. No es una tautología.
5. **Control positivo 2 (ronda 11c): la anomalía SE REPRODUCE con instrumento independiente.**
   P(dos honestos leen I_j distinto, entrega selectiva, Δ=4 s): mi instrumento da, en el mismo
   orden que `salida_c14.txt`, la cola MÁS LARGA en α=0 (0,94/0,58/0,25/0,037/0/0/0 en
   d=4/8/16/32/64/128/256) y más corta con adversario (α=0,25: 0,47/0,18/0,009/0; α=0,40:
   0,44/0,15/0,019/0). **La hipótesis del encargo («artefacto del máximo sobre una familia de
   cobertura variable con α») queda REFUTADA: mi instrumento no toma máximo sobre familia y la
   anomalía persiste.** Hipótesis de mecanismo (`no demostrado`): a α>0 los bloques del atacante,
   entregados al instante, actúan de espina compartida que sincroniza las dos vistas; a α=0 las
   dos vistas solo convergen a través de bloques honestos retrasados Δ. Los valores difieren de
   los históricos (~0,5-2×) — diferencias declaradas: R-FIN-1a+shuffle, C-ORD-01, ancla por
   punto fijo restringido, RNG.
6. **Control positivo 1 (ronda 9c, W_steer): mismo orden, diferencias declaradas.** Máx sobre
   12 semillas: −1/−1/45/45/10 (α=0/0,10/0,25/0,33/0,40) frente al histórico −1/10/20/20/45.
   Mi vía i (liberar 1 candidato) da menú 1 SIEMPRE — el candidato liberado no cambia el ancla
   definitiva bajo semántica correcta (recoloreado al recibir); la vía ii (cadena privada)
   cierra en 10-45. La diferencia con el histórico se atribuye a: gd recalculado al recibir (el
   histórico congelaba el gd en la creación — artefacto), ancla restringida vs vista completa, y
   RNG. `medido`, con la etiqueta de discrepancia.
7. **Rezago honesto residual:** G_vacío (observador sin ancla) es 0 salvo los primeros cortes
   (d < Δ) — reportado en `resultados/4a/*/w.csv` (columna wvacio).

### 1.3 · Qué decide esto (material para Katana)

- **L la fija el régimen honesto, no el adversario**: con Δ real simulada sub-segundo, L de
  cientos de slots basta; con Δ=16 s de estrés, L_mín(10⁻³) = 1 682 slots `medido` (≈28 min).
  El provisional L=1 h cubre Δ=16 a 10⁻³ con margen 2,1×; para 10⁻⁹ (extrapolado) harían falta
  ≈ 82 min — `estimado`, la cola honda de la segunda pasada lo afinará.
- **La retención del atacante (V1/V2) no amenaza el acuerdo honesto en la familia medida**
  (tope 8, ventana [T, T+45] — cota inferior del poder, §1.4); la entrega selectiva (A3) sí es
  la vía a diseñar contra, y su cola es exponencial con tasa ≈ 0,04-0,10.
- La ventana de estrés Δ=10/16 es la que discrimina: es el régimen donde el encargo esperaba el
  acantilado y está medido ahora.

### 1.4 · Limitaciones de esta pasada (etiquetas obligatorias)

- **Tope de 8 candidatos en V1 (muestreo uniforme)**: cota INFERIOR del poder del atacante — la
  misma laguna que el tope de 10 de la ronda 9c (`auditoria-8c.md:60`, LAGUNA declarada). El
  atacante real no está limitado a 8 retenciones. Declarado en MODELO.md §5 (ADENDA-2).
- **Ventana [T, T+45] de la familia base V1**: hereda el «45 s» histórico que el encargo pedía
  no heredar (ADENDA-2). No está justificada por S_max (una ancla puede estar hasta 150 slots
  tras T). Segunda pasada: barrido de sensibilidad de la ventana a [T, T+150] y del tope.
- 10⁻⁶/10⁻⁹: extrapolación exponencial `estimado` (ajuste calibrado contra r_cal donde aplica;
  r̂ del honesto no tiene calibración adversaria — es el honesto puro).
- Δ simulada (DMS supone latencias lognormales 80/500 ms); el estrés Δ constante es cota
  inferior para el desacuerdo parejas (vistas idénticas salvo creador) — declarado en MODELO.
- V1/V2/V3/A3: un umbral (T=300) por réplica; el máximo sobre escenarios es por réplica; V3 no
  demostrada óptima. 600 réplicas en A3 ⇒ la resolución en 10⁻³ es ~±5·10⁻³ (CP).
- Prop. 7 dentro del flujo: supuesto (HIPOTESIS-…md) — la convergencia del orden bajo
  U3″+R-FIN-5+R-FIN-8′ sigue siendo la deuda principal del diseño.

## 2 · Qué queda (segunda pasada)

- Barrido de la **ventana V1 a [T, T+150]** y del **tope de candidatos** (ADENDA-2; hoy cota
  inferior del poder del atacante).
- 4.B (precio de la partición, control con fusión, regla de selección con precio, y la
  comprobación explícita —no supuesta— de la cancelación del SR bajo retarget por flujo sobre su
  propio conjunto pagable), 4.C (S ramas), 4.D (mapa ρ, L, I, F), la cola honda
  (ε=10⁻⁶/10⁻⁹ medido donde el presupuesto lo permita) y `PROPUESTA.md`.
- La puerta 4.0 queda en manos de **PCO-v0.1 (`P-PUERTA/`)**: el `c` de equilibrio.
  Nada de esto invalida lo medido en 4.A.
