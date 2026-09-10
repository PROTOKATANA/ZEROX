# D9 · Auditoría del gate de igual ε (ronda d16)

**Rol:** D9 · Matemáticas y validación formal. **Mandato:** refutar, no validar.
**Fecha:** 2026-09-10. **Objeto:** `research/scripts/d16-gate/gate_igual_eps.py`,
`informe.md`, `salida_gate.txt`. **Instrumentos reutilizados:** `prev()` de
`d9-ronda9a/r9a_a3_frontera.py:37-49` (original, sin reescribir), `salida_zerox2_crudo.txt`
(D14B) y `salida_d8b_crudo.txt` (D8b).
**Alcance:** no se modificó ningún fichero del repositorio salvo este informe. La re-ejecución
de `gate_igual_eps.py` reescribe `salida_gate.txt` por diseño del script; se verificó con `diff`
que el contenido es **byte-idéntico** al previo. No se ejecutó `git`. Las sondas propias viven
en `/tmp/opencode/`.

**Postura.** Cada cifra del gate se recalcula con el instrumento original. Si el gate sobrevive
al ataque, se dice; si no, se propone la corrección.

---

## 0 · Resultado en una línea

La tesis central del gate —`M = max(3k, m(α,ε))` es inconsistente con `prev`— **aguanta**, y con
el `k_ref` máximo el error es aún mayor que el publicado. Lo que no aguanta tal cual: la
atribución del `4,3·10⁻¹⁰` (es `α=0,25` con `λ_real`/`δ_real`, no `α=0,30`), el uso de la
**media** de `k_ref` (mide un escenario sin ataque y mezcla `Δ`) en el criterio de muerte, y la
etiqueta «A sobrevive condicionada»: lo que sobrevive es una **variante de A con la espera
fijada por `prev`**, no A. Con el peor `k_ref` medido en la misma ronda, el criterio **NO PASA**
en `α=0,40`.

---

## 1 · Re-ejecución y tabla (pregunta 1)

```
AFIRMACIÓN:   gate_igual_eps.py reproduce salida_gate.txt; los cruces de baseline y adapt P
              (α∈{0,10;0,33;0,40}, ε∈{1e-6,1e-12}) valen 190,5/37,6 · 608,4/199,6 ·
              1320,6/586,1 · 240,6/71,6 · 870,5/425,4 · 2044,3/1252,1 (salida_gate.txt:16-29)
CLASIFICACIÓN: VERIFICADO COMPUTACIONALMENTE
DERIVACIÓN:   (a) `diff` entre la salida re-ejecutada y `salida_gate.txt`: **vacío**.
              (b) Los 6 cruces se recalcularon DOS veces: con la tabla vectorizada del gate y con
              `prev()` original + `brentq` sobre t∈[1,5000]. Discrepancia máxima < 0,15 s en las
              12 cruces. Ejemplos: baseline 1e-6 α=0,33 = 608,39 s (informe 608,4); adapt P media
              = 199,57 s (199,6); baseline 1e-12 α=0,40 = 2044,31 s (2044,3); adapt P media =
              1252,07 s (1252,1).
              (c) Ratios: 608,37/199,57 = 3,048 (informe 3,05); 870,53/425,43 = 2,046 (2,05).
ENTEROS:      `m(α,ε)=⌈ln ε/ln(α/(1−α))⌉` con flotantes; α=0,33 exacto; sin truncamiento crítico.
ADVERSARIO:   La tabla vectorizada trunca la pmf de Skellam en DS=[−400,6000] frente a
              [−400,60000] del original. En el dominio del gate (t≤5000, α≥0,10) la cola
              despreciada es <1e-300; los cruces con el original lo confirman.
IMPACTO:      ninguno; la tabla es reproducible.
CORRECCIÓN:   ninguna.
```

## 2 · Control positivo y el `4,3·10⁻¹⁰` (pregunta 2)

```
AFIRMACIÓN:   informe.md:10-17 — «D.6: 871 s a 1e-12» (9,749e-13, razón 0,975); «hoja: 1 800 s
              a 7,1e-36» (7,071e-36, 0,996); «600 s a α=0,33» (1,516e-6, 1,000); y «el 4,3e-10
              de la hoja a 600 s corresponde a α=0,30 (2,93e-10)».
CLASIFICACIÓN: VERIFICADO COMPUTACIONALMENTE (los tres controles) / **REFUTADO** (la atribución)
DERIVACIÓN:   Con `prev()` original:
              · `prev(0,33,1,871,90,1) = 9,7493e-13` (d12-quorum/informe.md:456,850, D.6).
              · `prev(0,33,1,1800,90,1) = 7,0710e-36` (ZEROX-EN-NUMEROS.md:44-45).
              · `prev(0,33,1,600,90,1) = 1,5159e-06` (ZEROX-EN-NUMEROS.md:44-45).
              · `prev(0,30,1,600,90,1) = 2,9331e-10` ≠ 4,3e-10 (factor 1,47).
              · El 4,3e-10 real: `prev(0,25, λ_real, 600, 3k, 1−δ_real)` del modelo
              autoconsistente del retarget (`dag-poas-delta-real.md:65-74`, `d9-ronda11a/
              informe.md:36,40-43`): k*=29 → λ=1,38095, δ=0,27586, offset 87 →
              **4,3068e-10**; k=30 → λ=1,36364, δ=0,26667, offset 90 → **4,3387e-10**.
ENTEROS:      offset 3k entero (87/90); el 2,93e-10 de α=0,30 no redondea a 4,3e-10.
ADVERSARIO:   La fila de `ZEROX-EN-NUMEROS.md:43` («Skellam, k = 30») no fija α, pero la fuente
              que la originó sí: `dag-poas-delta-real.md` §4 usa α=0,25 con λ_real y δ_real.
              El gate no trazó la fuente y publicó una atribución falsa en su control.
IMPACTO:      documental; no afecta a la tabla del gate, pero contamina el control positivo.
CORRECCIÓN:   «El 4,3e-10 corresponde a α=0,25 con λ_real=1,381/1,364 y δ_real=0,276/0,267
              (k*=29/k=30), no a α=0,30 (2,93e-10).» La hoja mezcla dos modelos distintos:
              α=0,25 con retarget inflado (4,3e-10) y α=0,33 con δ=0 (1,5e-6).
```

## 3 · La premisa del offset `3·k_ref` (pregunta 3)

```
AFIRMACIÓN:   informe.md:31,50-51 — «adapt P = el MISMO modelo con el offset reducido a 3·k_ref»;
              «la comparación honesta ... es adapt P: 3,05× / 2,05×».
CLASIFICACIÓN: PLAUSIBLE, NO DEMOSTRADO (la premisa) — el modelo es coherente, la reducción no
              está establecida.
DERIVACIÓN:   (a) Semántica del offset, verificada en la fuente primaria:
              `phantom-ghostdag.txt:1235-1238` — «adv(t) is bounded by a constant 3k ... we can
              shift the process adv′(t) by 3k and analyze it as a block race». El offset de `prev`
              es la **ventaja del atacante por freeloading (3k)**, no la profundidad de
              confirmación. Por tanto `prev(α,1,t,3k_ref,1)` es el modelo correcto SI la ventaja
              cae con el rank medido. La coherencia interna del gate queda confirmada: el 5,514e-2
              de `adapt G` se reproduce exactamente con offset 3·k_ref=0,66 (`prev(0,33,1,29,85,
              0,66,1)=5,5141e-2`); usar el M=20 del margen como offset sería un error de lectura.
              (b) Lo que NO está establecido: que el `k` del Freeloader Bound sea el **rank medido**
              `k_ref`. El bound es del parámetro de coloración (PHANTOM/GHOSTDAG); `k_ref` es el
              mínimo k que acepta la UMC sobre la **vista visible**. La sustitución no se deriva en
              D14B ni en el gate.
              (c) Evidencia en contra, de la misma ronda: con retención + cadena privada la captura
              es **12/12 a Δ=16** (`salida_visible2.txt`: `retraso20`, α=0,25 y α=0,40, vista real;
              `informe3.md:238`; `audita-d8c.md` D14-2, CONFIRMADO). El rank medido usa **peso
              unitario** (`d14k_ref.py:26-27`) y ZEROX usa `Σ⌊2^128/(SR+1)⌋` variable
              (`dag-poas-ancla-de-orden.md:157`; `audita-d8c.md` H-D14-1).
              (d) Sensibilidad (sonda propia, instrumento del gate): con el `k_ref` de la **peor
              estrategia medida en D8b** (`retro500`, Δ=20: α=0,40 media 7,75 máx 11; α=0,25 media
              4,58 máx 9), los ratios caen a α=0,40: **1,66/1,39** (media) y **1,51/1,31** (máx) —
              por debajo de los umbrales 2 y 1,5. α=0,25: 2,62/2,02 (media) y 2,00/1,69 (máx).
              (e) Break-even del offset (donde el ratio toca el umbral): α=0,40 → **8,0/11,8**;
              α=0,33 → 20,6/29,0; α=0,25 → 27,0/37,7; α=0,10 → 32,9/45,0. Con ventaja real de 90
              (el offset no baja) el ratio es **1,00** exacto y A no compra nada, como el propio
              gate dice (`salida_gate.txt:47-52`).
ENTEROS:      El offset de la media para α=0,40 es 3·0,0667=**0,2 bloques** (<1, no físico). El
              mínimo entero (1) cambia el ratio de 2,25 a 2,23 (1e-6) y de 1,63 a 1,62 (1e-12):
              efecto menor, pero la idealización continua no está declarada.
ADVERSARIO:   El atacante con retención infla el rank visible (D8b: `retro500` lleva el `k_ref`
              de α=0,40 de 0,07 a 7,75 de media) y cruza el break-even. Basta una ventaja real
              >8 bloques (de 90) para matar la fila α=0,40.
IMPACTO:      La columna adapt P **no es publicable como propiedad de A** mientras la reducción
              del offset no se demuestre con pesos reales y con el ataque cerrado. El gate lo
              condiciona en §4; la cifra 3,05×/2,05× no lleva ese condicionante en el titular.
CORRECCIÓN:   Mantener el modelo, pero sustituir el `k_ref` benigno por el de la peor estrategia
              medida (o declarar que el número es una cota superior optimista). Etiquetar la
              reducción del offset como LAGUNA, no como premisa del cálculo.
```

## 4 · Extracción de `k_ref` y dependencia con `Δ` (pregunta 4)

```
AFIRMACIÓN:   gate_igual_eps.py:41-57 — medias/máximos por α desde salida_zerox2_crudo.txt:
              α=0,10 → 1,28/9; 0,25 → 0,45/3; 0,33 → 0,22/2; 0,40 → 0,07/1; y Δ=4/Δ=20 →
              0,67/2,58 · 0,42/0,58 · 0,25/0,25 · 0,08/0,08 (salida_gate.txt:31-35).
CLASIFICACIÓN: VERIFICADO COMPUTACIONALMENTE (extracción) / PLAUSIBLE, NO DEMOSTRADO (uso)
DERIVACIÓN:   Cabecera del crudo: `alpha delta seed k_ref k_mkmc t_base ...`; el script lee
              `c[0]=alpha`, `c[1]=delta`, `c[3]=k_ref`. Recuento: 60 filas por α (12 semillas ×
              5 Δ), sin `None`. Recalculadas media/máx/Δ4/Δ20 desde el fichero: idénticas a las
              4 cifras de `salida_gate.txt:32-35`. La tabla D14B (`informe2.md:104-110`) coincide.
ENTEROS:      `int(c[3])`: los 240 registros son enteros; `None` habría reventado el script (no
              hay ninguno en este fichero).
ADVERSARIO:   Tres problemas de uso, no de extracción:
              (1) La **media mezcla Δ=1..20**. `k_ref` depende de Δ (α=0,10: 0,67 en Δ=4 vs 2,58
              en Δ=20; máx 9 solo en Δ=20). El gate calcula `delta4`/`delta20` pero **no los usa**
              en la tabla ni en el criterio.
              (2) El criterio de muerte usa `r_p` de la **media** (gate:158-162), no de `adapt P
              max` que el propio script imprime. El peor caso real del gate es 2,16/1,60 (máx),
              no 2,25/1,63 (media).
              (3) `salida_zerox2_crudo.txt` mide el escenario **sin ataque** (Mundo por defecto) y
              con peso unitario. El peor `k_ref` de la misma ronda está en `salida_d8b_crudo.txt`.
IMPACTO:      El «PASA» del criterio es más frágil de lo que publica. El margen a 1e-12 con el
              máximo es 1,60 vs umbral 1,5 (6,7 %).
CORRECCIÓN:   Tabla y criterio por Δ (o con el máximo global, declarado), y `k_ref` de la peor
              estrategia (D8b) o declaración explícita de que se usa el escenario benigno.
```

## 5 · Ratios y criterio de muerte (pregunta 5)

```
AFIRMACIÓN:   informe.md:53-60 — «ratio P mínimo a 1e-6 = 2,25 (α=0,40) ≥2 PASA; ratio P mínimo
              a 1e-12 = 1,63 (α=0,40) ≥1,5 PASA».
CLASIFICACIÓN: VERIFICADO COMPUTACIONALMENTE con la media / **REFUTADO** como veredicto robusto
DERIVACIÓN:   Recalculado con el instrumento del gate:
              · media (lo que usa el criterio): mín = 2,25 / 1,63 (α=0,40) → PASA.
              · máximo de `k_ref`: mín = 2,16 / 1,60 (α=0,40) → PASA, margen 6,7 %.
              · Δ=4 por separado: mín = 2,25 / 1,63 → PASA. Δ=20: mín = 2,25 / 1,63 → PASA
                (para α=0,40, k_ref es 0,083 en ambos Δ; en α=0,10 el ratio baja de 5,80/3,61
                a 4,08/2,96, sin cruzar umbrales).
              · peor estrategia D8b (`retro500`, Δ=20): α=0,40 → **1,66/1,39 → NO PASA**;
                α=0,25 → 2,00/1,69 (pasa justo en 1e-6).
              · Los umbrales (2 y 1,5) solo se declaran en el propio gate
                (`gate_igual_eps.py:17`); no tienen derivación ni fuente externa en el repo.
ENTEROS:      `r_p = t_base/t_am` con `t_am>0`; no hay división por cero en el dominio.
ADVERSARIO:   El criterio se evalúa sobre el `k_ref` que más favorece a A. El atacante solo
              necesita una ventaja real >8 bloques (α=0,40) o >20,6 (α=0,33) para cruzar el
              break-even. La retención ya la produce.
IMPACTO:      El «PASA» no es una propiedad del diseño; es una cota superior condicionada a un
              offset que el ataque de retención infla.
CORRECCIÓN:   Publicar el mínimo con el peor `k_ref` medido: **1,66/1,39 (α=0,40) → NO PASA**,
              o redefinir el criterio con el offset adversarial.
```

## 6 · La fórmula `m` y el veredicto (preguntas 3 y 6)

```
AFIRMACIÓN:   informe.md:44-48 — «a los 29,9 s que predice, el riesgo real de reversión es
              5,5 %, no 1e-6: se equivoca por un factor 55 141»; veredicto: «A sobrevive solo
              condicionada; las cifras publicables son ~200 s / ~425 s».
CLASIFICACIÓN: VERIFICADO COMPUTACIONALMENTE (la refutación de la fórmula) / PLAUSIBLE con matiz
              (la etiqueta del veredicto)
DERIVACIÓN:   · `prev(0,33,1,29,85,0,66,1) = 5,5141e-2`; 5,5141e-2/1e-6 = **55 141**: exacto.
              Con el `k_ref` máximo de α=0,33 (3k_ref=6) el riesgo es **0,2564** (razón 2,56e5):
              la refutación del margen `m` es sólida y el gate la **subestima** al usar la media.
              · El 29,85 s es `M/(1−α)` con `M=max(3k_ref, m(1e-6)) = max(0,66;20) = 20`: el
              margen `m` domina a `3k_ref`, como ya decía D14B (`informe2.md:133-135`).
              · `adapt P` no es A: A dispara a los ~29,9 s; 199,6 s es el cruce de riesgo de
              `prev` con el offset reducido, es decir, **otra regla** (esperar hasta `prev≤ε`).
              La frase «A sobrevive» atribuye a A la ganancia de una variante que no es A. La
              tabla del propio informe ya etiqueta la fórmula como REFUTADO; la fila «Decisión»
              debería decir «una regla de riesgo de cliente con offset 3·k_ref sobrevive
              condicionada».
              · La condición de seguridad (§4) es correcta y está declarada: si Δ≥16 y la
              retención sigue abierta, el offset vuelve a ~3k y el ratio es 1. Pero la condición
              no es un trámite: `audita-d8c.md` (D14-2/D14-4) confirma el ataque como el modelo
              del paper, y ninguna mitigación lo cierra sin matar liveness o superar el baseline
              (H-D14-2/H-D14-5).
ENTEROS:      `m = ⌈ln ε/ln(α/(1−α))⌉`; ln de base flotante; sin truncamiento crítico.
ADVERSARIO:   El titular «2–3×» se leerá como ganancia de A; en realidad es una cota superior de
              una regla distinta, condicionada a un ataque abierto y con break-even de 8–12
              bloques (α=0,40) que el peor `k_ref` de la ronda ya supera.
IMPACTO:      Decisión de diseño: publicar «~200 s / ~425 s» como latencia de A es incorrecto;
              son la latencia de la variante `prev` con offset reducido. A, como fórmula, está
              refutada.
CORRECCIÓN:   «La fórmula de A está REFUTADA. Lo que sobrevive, condicionado a cerrar la
              retención y a pesos reales, es una regla de riesgo de cliente con offset 3·k_ref:
              3,05×/2,05× (α=0,33) con `k_ref` benigno; 1,66×/1,39× (α=0,40) con el peor `k_ref`
              medido — NO PASA el criterio.»
```

---

## Tabla de cifras

| # | Afirmación | Valor del informe | Valor recalculado | Etiqueta |
|---|---|---|---|---|
| 1 | Re-ejecución reproduce `salida_gate.txt` | tabla | `diff` vacío; 12 cruces <0,15 s con el original | VERIFICADO COMPUTACIONALMENTE |
| 2 | Control D.6: 871 s → 1e-12 | 9,749e-13 (0,975) | 9,7493e-13 | VERIFICADO COMPUTACIONALMENTE |
| 3 | Control hoja: 1 800 s → 7,1e-36 | 7,071e-36 (0,996) | 7,0710e-36 | VERIFICADO COMPUTACIONALMENTE |
| 4 | Control 600 s α=0,33 | 1,516e-6 (1,000) | 1,5159e-6 | VERIFICADO COMPUTACIONALMENTE |
| 5 | «4,3e-10 corresponde a α=0,30 (2,93e-10)» | 2,93e-10 | α=0,25, λ_real=1,381/1,364, δ_real=0,276/0,267 → 4,307e-10/4,339e-10 | **REFUTADO** |
| 6 | `k_ref` media/máx por α | 1,28/9 · 0,45/3 · 0,22/2 · 0,07/1 | idénticos (240 registros, sin `None`) | VERIFICADO COMPUTACIONALMENTE |
| 7 | `k_ref` Δ=4 / Δ=20 | 0,67/2,58 · 0,42/0,58 · 0,25/0,25 · 0,08/0,08 | idénticos | VERIFICADO COMPUTACIONALMENTE |
| 8 | 6 cruces baseline / adapt P | 190,5/37,6 · 608,4/199,6 · 1320,6/586,1 · 240,6/71,6 · 870,5/425,4 · 2044,3/1252,1 | idénticos | VERIFICADO COMPUTACIONALMENTE |
| 9 | Ratios α=0,33 | 3,05 / 2,05 | 3,048 / 2,046 | VERIFICADO COMPUTACIONALMENTE |
| 10 | Criterio con media | 2,25 / 1,63 → PASA | idéntico | VERIFICADO COMPUTACIONALMENTE |
| 11 | Criterio con máximo de `k_ref` | no usado | **2,16 / 1,60** → PASA (margen 6,7 %) | COTA CORREGIDA |
| 12 | Criterio por Δ=4 y Δ=20 separados | no usado | 2,25 / 1,63 en ambos → PASA | VERIFICADO COMPUTACIONALMENTE |
| 13 | Criterio con peor `k_ref` D8b (`retro500`, Δ=20) | no usado | α=0,40: **1,66 / 1,39 → NO PASA**; α=0,25: 2,00/1,69 | **REFUTADO** (robustez) |
| 14 | Fórmula `m` a 29,9 s (α=0,33) | 5,514e-2, razón 55 141 | 5,5141e-2, razón 55 141 (offset 3k med); con máx: 0,2564, 2,56e5 | VERIFICADO COMPUTACIONALMENTE |
| 15 | Retención captura 12/12 a Δ=16 | 12/12 | `salida_visible2.txt`: `retraso20` α=0,25 y α=0,40 = 12/12 | VERIFICADO COMPUTACIONALMENTE |
| 16 | `k_ref` con peso unitario, no `blue_work` | declarado en §4 | `d14k_ref.py:26-27`; ZEROX `Σ⌊2^128/(SR+1)⌋`; `audita-d8c` H-D14-1 | CONFIRMADO (ya auditado en D9-B) |
| 17 | Veredicto «A sobrevive condicionada, 2–3×» | PLAUSIBLE condicionado | A (fórmula) REFUTADA; 2–3× de una variante `prev`; condición abierta y contradicha a Δ≥16 | **MATIZ** (demasiado generoso en la etiqueta) |
| 18 | Umbrales 2× / 1,5× | criterio de muerte | no documentados en el repo; criterio propio sin derivación | PLAUSIBLE, NO DEMOSTRADO |

## Reproducción

```
# 1. Re-ejecución del gate (reescribe salida_gate.txt con contenido idéntico)
cd research/scripts/d16-gate && python3 gate_igual_eps.py && diff salida_gate.txt <(python3 gate_igual_eps.py)

# 2. Control y cruces con el instrumento original
python3 -c "import sys; sys.path.insert(0,'research/scripts/d9-ronda9a'); \
from r9a_a3_frontera import prev; \
print(prev(0.25,1.38095,600,87,0.72414), prev(0.30,1.0,600,90,1.0), prev(0.33,1.0,871,90,1.0))"

# 3. Peor k_ref de D8b (columnas: alpha delta seed estrategia k_ref ...)
awk 'NR>1{print $1,$2,$4,$5}' research/scripts/d14-dagknight/salida_d8b_crudo.txt | \
  sort | uniq -c | sort -k2,2n -k3,3n
```

## Cierre D9

```
REFUTADAS:
  R1. «El 4,3e-10 a 600 s corresponde a α=0,30 (2,93e-10)» → es α=0,25 con λ_real=1,381/1,364 y
      δ_real=0,276/0,267 (offset 3k): 4,307e-10/4,339e-10. Impacto: control positivo con una
      atribución falsa; la tabla del gate no cambia.
  R2. «El criterio de muerte PASA» como propiedad robusta → con el peor k_ref medido en la misma
      ronda (D8b `retro500`, Δ=20) la fila α=0,40 da 1,66/1,39 y NO PASA. Con el máximo del propio
      fichero del gate, el mínimo es 2,16/1,60 (no 2,25/1,63). Impacto: decisión de diseño; el
      «PASA» solo vale para el escenario benigno y sin retención.
  R3. (Ya refutada en D9-B, heredada) «En ZEROX todos los bloques pesan 1» → ZEROX usa blue_work
      variable; el instrumento del gate mide con conteos. Impacto: k_ref bajo pesos reales NO
      DEMOSTRADO; la columna adapt P no es publicable sin ese port.

NO DEMOSTRADAS:
  N1. Que el `k` del Freeloader Bound (`phantom-ghostdag.txt:1235-1238`) sea el rank medido
      `k_ref` y no el parámetro de coloración del protocolo. La sustitución no está derivada.
  N2. Que la reducción del offset a 3·k_ref sobreviva a retención + cadena privada (12/12 a Δ=16)
      y a pesos `blue_work` reales.
  N3. Que la regla de riesgo de cliente («esperar hasta prev(3k_ref)≤ε») sea implementable sin
      conocer α ni el estado oculto del atacante; el gate la usa como comparación, no la especifica.
  N4. El origen/derivación de los umbrales 2× y 1,5×: solo se declaran en el propio gate, sin
      fuente ni justificación externa en el repo.
  N5. La independencia entre las 12 semillas de D8b/D14B (mismo generador r8c_sim); los «x/12» no
      llevan intervalo.

COTAS CORREGIDAS:
  · Criterio de muerte, peor caso del fichero del gate (k_ref máx): 2,16 / 1,60 (no 2,25 / 1,63).
  · Criterio con la peor estrategia D8b: α=0,40 → 1,66 / 1,39; α=0,25 → 2,00 / 1,69.
  · Break-even del offset: α=0,40 → 8,0 / 11,8; α=0,33 → 20,6 / 29,0; α=0,25 → 27,0 / 37,7;
    α=0,10 → 32,9 / 45,0 (umbrales 2× y 1,5×).
  · Fórmula m a 29,9 s: con k_ref máximo de α=0,33 el riesgo es 0,2564 (razón 2,56e5), no
    5,514e-2 (55 141). El gate subestima el error al usar la media.
  · Offset de α=0,40 en la media: 0,2 bloques (<1, no físico); con el mínimo entero 1 el ratio
    es 2,23 / 1,62 en lugar de 2,25 / 1,63.

LO QUE NO PUDE VERIFICAR:
  · El encargo original de la ronda d16 y el origen de los umbrales 2× / 1,5× (no hay ENCARGO.md
    en d16-gate ni mención en PREGUNTAS/DECISIONES).
  · El impacto cuantitativo del port a blue_work real sobre k_ref (requiere re-medir; coincide con
    N1 de D9-B).
  · La independencia estadística de las 12 semillas y la cola de la distribución de k_ref.
```

**Veredicto de conjunto.** El gate aguanta en su tesis central: la fórmula `M = max(3k, m)` no es
el modelo de riesgo del proyecto, y el error es mayor de lo que publica (con `k_ref` máximo,
2,56e5× en vez de 55 141×). No aguanta en tres cosas: la atribución del `4,3·10⁻¹⁰`, el uso de la
media benigna de `k_ref` en el criterio de muerte (con el peor `k_ref` de la misma ronda la fila
α=0,40 NO PASA), y la etiqueta «A sobrevive»: A, como fórmula, está refutada; lo que sobrevive es
una regla de riesgo de cliente con offset reducido, condicionada a cerrar la retención y a pesos
reales — dos condiciones que la propia ronda d14 dejó abiertas o contradichas.
