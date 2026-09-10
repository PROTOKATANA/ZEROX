# D14A — DAGKNIGHT sobre el DAG de PoAS: ¿baja el suelo de irreversibilidad de 100-134 s?

**Ronda 14A. Prioridad del proyecto: bajar el tiempo de irreversibilidad lo más posible.**
Sin comité, sin dinero, sin confianza nueva. Directorio propio: `research/scripts/d14-dagknight/`.

**Pregunta.** ¿Puede una regla de confirmación adaptativa tipo DAGKNIGHT (k adaptativo + confirmación
por cliente) sobre el DAG de PoAS de ZEROX bajar el suelo `3k/((1−α)λ) = 100-134 s`
(`research/dag-poas-catalogo-problemas-ataques.md:63`, D6) sin comité, sin dinero y sin confianza
nueva? ¿A qué latencia, con qué `α`, con qué `Δ`, y a qué coste de consenso?

**Respuesta corta.** Sí en red sana y `Δ` bajo-medio: el suelo medido baja de **97-146 s** a
**4-17 s** (media; mínimo **0,36 s**) con `ε=0,05`, y a **16-109 s** con `ε=10⁻¹²`. El k adaptativo
medido sobre el DAG real de ZEROX es **k* = 0-6** (no 30) porque R-FIN-12 ya mantiene el DAG
estrecho. **Pero el atacante puede inflar k\*** con retención o cadena parásita hasta **k\*≈27-50**
a `Δ ≥ 16 s`, y entonces el suelo adaptativo **iguala o supera el baseline** (hasta 250 s a
`α=0,40`, `Δ=20`). La ganancia es real en red sana; **no es a prueba de manipulación** con la regla
ingenua. El control positivo del paper es **PARCIAL** (LAGUNA: el paper no publica su regla de
cliente ni el código de su simulación).

## Fuentes y método

- `research/fuentes/dagknight.txt` — fórmula `:1007`, simulación `:182-197`, cota `:328-352`,
  adversario `:312-327`, confirmación por cliente `:996-999` y `:1040-1048`, caso pesimista
  `:1021-1027`, tabla `:1084-1132`, DAA `:1133-1163`, algoritmo `:610-658` (Alg. 2), `:733-769`
  (Alg. 5), pie 9 `:804-805`, decoupling `:786-822`, tie-breaking `:823-840`.
- `research/dag-poas-ancla-de-orden.md` §2 — R-FIN-1 (`:162`), R-FIN-5 (`:202`), R-FIN-6 (`:268`),
  R-FIN-7 (`:271`), R-FIN-12 (`:177`), R-FIN-8′ (`:314`), R-FIN-13′ (`:228`), R-FIN-14 (`:236`).
  **No se edita.**
- `research/dag-poas-catalogo-problemas-ataques.md` — D6 (`:63`), E1 (`:72`), A1 (`:19`), A2 (`:20`),
  B1 (`:36`), D1 (`:58`).
- `research/fuentes/phantom-ghostdag.txt` — Lema 10 (`:1079-1081`, `:1205-1238`), ventaja `3k`
  (`:1369-1371`), Lema 12 freeloader (`:1172-1173`).
- Instrumentos **importados sin modificar** (patrón `d9-ronda8d/r8d_lib.py:1-30`):
  `d9-ronda8c/r8c_gd.py` (GHOSTDAG fiel a rusty-kaspa @ c338d495) y `d9-ronda8c/r8c_sim.py`
  (eventos y adversario del paper). Reversión: `d9-ronda9a/r9a_a3_frontera.py:37-49` (`prev`).
- Regla del método: `α` entra en todo (control, k*, latencias); ≥12 semillas
  (`[11,23,37,41,59,67,73,89,97,101,113,127]`); media e intervalo.

## Punto 1 · Control positivo — **PARCIAL** (LAGUNA)

Objetivo `dagknight.txt:182-197`: `λ=3,75`, `α=0,2`, `D=0,1/1/2 s`, `ε=0,05` → `k = 0/1/4` y
tiempos **1,2/6/12 s**. Se generó el DAG del paper (cada bloque referencia todas las puntas
visibles, `:907-910`; el atacante ve todo al instante, `:321-327`) y se midió k* con dos
coloraciones: voraz por bitsets (maximización libre, `F_k` del pie 9 `:804-805`) y el replay fiel
GHOSTDAG de `r8c_gd`.

| D | k* bitset (12 sem.) | k* replay | objetivo | cota del paper (:1007) en s | figura | figura/cota |
|---:|---:|---:|---:|---:|---:|---:|
| 2,0 | 3,25 | **6,00** | **4** | 19,66 | 12,0 | 0,61 |
| 1,0 | 1,67 | **2,75** | **1** | 6,75 | 6,0 | 0,89 |
| 0,1 | 0,08 | **0,00** | **0** | 1,54 | 1,2 | 0,78 |

**Lo que sí se reproduce:** la *escala*. k*=0 cuando `Dλ ≪ 1`; crece con `D`; el orden relativo
`0 < 1-2 < 4-6` es el del paper. El bitset da 3,3/1,7/0 (dentro de ±1 del objetivo 4/1/0); el
replay GHOSTDAG da 6,0/2,8/0 (+2 en el peor caso, porque el color de Kaspa es *committed* y
excluye más que el `free_search` del paper). El instrumento detecta el k adaptativo.

**Lo que NO se reproduce:** la tabla exacta `1,2/6/12 s` ni los enteros exactos 4/1/0.
Causas verificadas en el texto: (i) el paper **no publica la regla de confirmación del cliente**
—solo cotas asintóticas (`:996-999`, `:1007`, `:328-352`)— y declara sus cotas «far from tight»
(`:1026-1028`); (ii) el pseudocódigo completo «will appear online» (`:660-663`, `:1064-1065`) no
está en `PDF/` ni se localizó; (iii) la simulación de la figura no describe semillas, política de
padres del atacante ni el instante exacto de «confirmation time». Reglas de cliente probadas
(cruce de cobertura ≥50 %, primer k* estable, `min_n=8`): **0,27-4,10 s**, ninguna da 12/6/1,2.
**Etiqueta: LAGUNA** (haría falta el código de los autores o su regla de cliente explícita).

**Consecuencia para el resto del informe.** Como el control no valida la *tabla de tiempos*, NO se
usan los tiempos del paper como calibración. Sí se valida el instrumento para lo que sostiene la
pregunta de ZEROX: **medir k\* (el k-cluster mínimo mayoritario) sobre un DAG dado** con el
GHOSTDAG importado. Los números de ZEROX se miden directamente, no se extrapolan del paper.

## Punto 2 · Regla adaptativa implementada (y qué simplifica)

**Regla.** Para una vista `G` del cliente:

1. **k\* adaptativo (criterio de seguridad):** el mínimo `k` tal que el k-cluster devuelto por el
   GHOSTDAG de `r8c_gd` (replay sobre la topología fija) es **mayoritariamente honesto** (≥50 % de
   sus bloques) **y cubre ≥50 % de los bloques honestos**. El criterio global ≥50 % a secas es
   *gameable*: a `α≥0,33` la «mayoría» puede ser la cadena del atacante y da `k*_all=0` espurio
   (ver «Errores propios» 1).
2. **Margen de confirmación:** `M = max(3k*, m(α,ε))` bloques, con
   `m(α,ε) = ⌈ln ε / ln(α/(1−α))⌉` (probabilidad de que el atacante alcance alguna vez desde un
   déficit de `m`; ruina del jugador, mismo mecanismo que el `offset` de `prev`,
   `r9a_a3_frontera.py:37-49`). `3k*` es el análogo adaptativo de la ventaja `3k` del Lema 10.
3. **Confirmación por cliente:** el cliente confirma cuando han pasado `M` bloques **honestos**
   posteriores al bloque de la transacción (misma unidad que el suelo publicado
   `3k/((1−α)λ)`), o antes si `M=0`.

**Simplificaciones declaradas.** (a) El colorador es el GHOSTDAG de Kaspa (committed), no el
`K-Colouring` recursivo con `free_search` del paper (`:733-769`): el k* medido es una **cota
superior** del mínimo real. (b) El criterio UMC real (`:600-602`, `:709-719`) se aproxima por
cobertura; la etiqueta honesto/atacante es un **oráculo** del análisis (el cliente no la tiene; el
protocolo usa UMC). (c) El margen `3k*` es una **hipótesis**: el Lema 10 está probado para `k`
fijo (`phantom-ghostdag.txt:1205-1238`). (d) El punto fijo del k (la topología depende de
`blue_work`, que depende del color) se resolvió iterando `k_{n+1}=k*(DAG(k_n))`; **converge en un
paso** (30→k*→k*) en todos los casos medidos. (e) La confirmación es local: no hay certificado.

## Punto 3 · Rejilla ZEROX — k\* medido (VERIFICADO)

`λ=1`, `T=400 s`, 12 semillas, adversario del paper (instantáneo, sin retardo),
DAG de ZEROX con R-FIN-12 (`r8c_sim` + `pick_virtual_parents`).

| `α` | `Δ=1` | `Δ=4` | `Δ=16` | `Δ=20` |
|---:|---:|---:|---:|---:|
| 0,10 | 0,00 [0,0] | 2,25 [2,3] | 5,50 [4,6] | 5,67 [4,7] |
| 0,25 | 0,00 [0,0] | 1,00 [1,1] | 2,00 [2,2] | 2,00 [2,2] |
| 0,33 | 0,00 [0,0] | 1,00 [1,1] | 1,00 [1,1] | 1,00 [1,1] |
| 0,40 | 0,25 [0,1] | 1,25 [1,2] | 1,67 [1,2] | 1,67 [1,2] |

`k*` (media [mín,máx] sobre 12 semillas). Frente a `k=30`: **k\* es 5-30× menor**. Intuición: el
DAG de ZEROX no es el mallado del paper (todas las puntas): `pick_virtual_parents`
(R-FIN-12, `dag-poas-ancla-de-orden.md:177-182`) ya elige un `sp` por `blue_work` y acota a 15
padres, así que el «ancho» real es mucho menor que el peor caso para el que se dimensionó `k=30`.
El k* **decrece con α** porque la tasa honesta `(1−α)λ` baja y el DAG se estrecha.

## Punto 4 · Comparación con el baseline GHOSTDAG k=30 (VERIFICADO)

Suelo publicado: `3k/((1−α)λ) = 90/(1−α) = 100/120/134/150 s` (`catalogo:63`; `auditoria-9c:66`).
Medido en el calendario (hasta el 90.º bloque honesto tras la transacción): media
**97,1/115,9/130,4/145,8 s**; mínimo **67,6/77,7/84,3/106,7 s** — reproduce el suelo publicado.

**Latencia adaptativa** (media `[mín,máx]` sobre `Δ∈{1,4,16,20}` y 12 semillas; entre paréntesis
el suelo teórico `M/((1−α)λ)`):

| `α` | `ε=0,05` | `ε=10⁻³` | `ε=10⁻⁶` | `ε=10⁻¹²` | baseline (suelo) |
|---:|---:|---:|---:|---:|---:|
| 0,10 | **10,82 [0,36;24,50]** (11,7) | 11,54 [1,81;24,50] (12,3) | 12,47 [3,43;24,50] (13,3) | 15,76 [8,67;24,50] (16,6) | 97,1 [67,6;122,6] (100) |
| 0,25 | **6,10 [0,44;14,62]** (6,0) | 9,25 [3,43;15,54] (9,3) | 16,16 [9,69;23,03] (17,3) | 33,89 [17,68;43,33] (34,7) | 115,9 [77,7;145,2] (120) |
| 0,33 | **7,91 [3,29;14,57]** (7,5) | 14,14 [8,67;20,12] (14,9) | 29,62 [15,19;38,68] (29,9) | 55,67 [36,22;68,41] (59,7) | 130,4 [84,3;160,3] (134,3) |
| 0,40 | **12,32 [7,25;20,12]** (13,3) | 29,46 [14,84;41,21] (30,0) | 54,26 [35,94;69,67] (58,3) | 108,69 [71,53;132,4] (115,0) | 145,8 [106,7;173,4] (150) |

**Mejora (media baseline / media adaptativa):** a `ε=0,05`, **9-19×**; a `ε=10⁻¹²`, **1,3-6,2×**.
La latencia mínima absoluta de la rejilla es **0,36 s** (`α=0,10`, `ε=0,05`).

**Cota del paper en ZEROX.** `(ln(1/ε)+Dλ)/((1−2α)λ)+D²λ` (`:1007`, `:328-352`) daría
`Δ=1: 6-144 s`, `Δ=4: 25-174 s`, `Δ=16: 280-474 s`, `Δ=20: 429-638 s`: **la cota es 2,5-40×
peor que lo medido** (el término `(Dλ)²` domina y el paper la declara holgada, `:1026-1028`). No
sirve para decidir ZEROX; sirve el k* medido. La cota **no** acota la latencia mínima: es una
cota superior de tiempo de convergencia, no un suelo de irreversibilidad.

## Punto 5 · Coste de consenso: qué reglas se sustituyen o re-derivan

| Regla | Qué pasa con el k adaptativo | Etiqueta |
|---|---|---|
| **R-FIN-6** (`ancla:268`) «k-cluster GHOSTDAG con k=25» (las constantes usan `k=30`, `:156`) | Se sustituye por «k = k* del mínimo k-cluster mayoritario-honesto». Cambia la clasificación azul/rojo de cada bloque | **Hay que reescribirla** (DEMOSTRADO que `k=30` no es necesario en red sana; REFUTADO que sea óptimo) |
| **Suelo 3k** (D6, `catalogo:63`; `auditoria-9c:16,66`) | Pasa a `M = max(3k*, m(α,ε))`; el suelo es `M/((1−α)λ)`. Medido 4-17 s (`ε=0,05`) | **Sustituido** (VERIFICADO en red sana) |
| **Frontera de flujo único** 46,9 % / 38,3 % (`Δ=16`) / 32,4 % (`Δ=20`); 36,25 % (auditoría 7) (`ancla:156`) | El k* es una palanca nueva: el atacante lo infla (Punto 6) y el k* honesto depende de `α`. La frontera se re-deriva con `k*(α,Δ)` | **LAGUNA** (no re-derivada aquí) |
| **R-FIN-7 / `F`** (`ancla:271-290`) | `F` protege de reorgs; con k adaptativo el riesgo depende de k*. El ataque de inflación exige un mecanismo de recuperación (el tie-breaking del paper, `dagknight:823-840`) antes de bajar `F` | **Re-derivar `F` con el tiempo de recuperación del rank**; no bajar `F` aún |
| **R-FIN-5** (`ancla:202`) flujo único | Ortogonal: el coloreado adaptativo se aplica al DAG de un solo flujo. La comprobación estructural sigue igual | **No cambia** (PLAUSIBLE) |
| **R-FIN-14** (`ancla:236`) reto por slot | Ortogonal al orden: el reto sale del PoT secuencial, no del color | **No cambia** |
| **R-FIN-1** (`ancla:162`) inyector por slot desde la cadena seleccionada | La cadena seleccionada depende del color (`sp` por `blue_work`). Con k variable, el ancla `I_j` puede cambiar. Debe fijarse la regla (usar la cadena del k de protocolo, p. ej. `k=30`, o congelar el color del pasado) | **Re-derivar** (PLAUSIBLE que baste con fijar el color) |
| **R-FIN-12** (`ancla:177`) `max_block_parents=15`, `msl=180` a `k=30`, `pick_virtual_parents` | `blue_work` cambia con k*, luego la selección de padres cambia; los límites están dimensionados a `k=30`. El paper usa *todas* las puntas (`dagknight:909`), incompatible con R-FIN-12 | **Re-derivar límites o fijar el color de padres** (coste real) |
| **R-FIN-8′ / R-FIN-13′** (`ancla:314`, `:228`) pagos y `N_obs` | Quién es azul y quién rojo cambia con k*; pagos y conteo del retarget deben re-derivarse juntos (invariante «cuenta = paga») | **Re-derivar** |
| **R-FIN-11** (`ancla:206`) U3″ dinámica | El orden del mergeset (que decide la copia azul) es `blue_work`, dependiente de k* | **Re-verificar** |

**Cliente (comerciante y exchange).** La confirmación de DAGKNIGHT es **por cliente**, no un
certificado (`dagknight:996-999`: «evaluating the function risk – is done by the client locally,
outside the context of consensus»). El comerciante elige `ε` y confirma localmente: sirve, y no
necesita comité. El exchange también, pero (i) sin SPV (D1, `catalogo:58`) necesita el DAG o las
cabeceras completas; (ii) dos clientes pueden confirmar en instantes distintos (no hay certificado
de red); (iii) con `ε` pequeño el exchange paga la latencia del Punto 4; (iv) contra el ataque de
inflación del Punto 6, un exchange debería usar el *rank* robusto del paper (`dagknight:823-840`),
no el k* crudo.

## Punto 6 · D8 propio — ¿se puede manipular k\*? **SÍ** (REFUTADO el k\* crudo como seguro)

Mismo calendario, estrategias del atacante (12 semillas; `k*_hon` medio [mín,máx]):

| `α`,`Δ` | instant (control) | retraso 20 s | retraso 60 s | burst a 300 s | parásita (retro 5) | desconectada (retro 500) |
|---:|---:|---:|---:|---:|---:|---:|
| 0,10 / 20 | 5,7 [4,7] | 20,4 [18,22] | **24,0 [18,27]** | 16,8 [14,22] | 23,0 [18,26] | 23,0 [18,26] |
| 0,25 / 20 | 2,0 [2,2] | 19,7 [17,21] | 28,2 [21,35] | 13,2 [10,17] | 17,8 [14,20] | 17,8 [14,20] |
| 0,40 / 20 | 1,7 [1,2] | 24,7 [20,28] | **30,7 [20,50]** | 21,5 [14,28] | 13,2 [11,15] | 13,2 [11,15] |
| 0,10 / 4 | 2,2 [2,3] | 3,0 [3,3] | 3,0 [3,3] | 3,0 [3,3] | 3,0 [3,3] | 3,0 [3,3] |

**Sostenible:** `k*_hon` en el prefijo `t≤200` es 16-39 (igual que en el DAG completo): no es un
transitorio. **Suelo bajo la peor estrategia** `3·k*max/((1−α)λ)`:

| `α` | `Δ=4` | `Δ=16` | `Δ=20` | baseline |
|---:|---:|---:|---:|---:|
| 0,10 | 10,0 s | 60,0 s | **90,0 s** | 100 s |
| 0,25 | 16,0 s | 72,0 s | **140,0 s** | 120 s |
| 0,40 | 30,0 s | 125,0 s | **250,0 s** | 150 s |

A `Δ ≥ 16` el atacante puede **igualar o superar el baseline**: congela la confirmación. A `Δ ≤ 4`
la manipulación es débil (k*≤6) y la ganancia sobrevive. El paper reconoce el caso pesimista con
cota exponencial (`:1021-1027`) y mitiga con el tie-breaking que prefiere la punta que usó el rank
excesivo más tarde (`:823-840`); **no se implementó** esa parte. Etiqueta: **REFUTADO** que el k*
crudo sea seguro; **LAGUNA** si el DAGKNIGHT completo (rank + tie-breaking) recupera el k* honesto
—haría falta implementar Alg. 2/4 completas.

## Veredicto

| Punto | Resultado | Etiqueta |
|---|---|---|
| 1 · Control positivo del paper | k* escala (0-6 vs 0/1/4), tabla 1,2/6/12 s NO reproducida (falta regla de cliente y código) | **PARCIAL / LAGUNA** |
| 2 · Regla adaptativa | k* + `max(3k*, m(α,ε))`, confirmación por cliente; 5 simplificaciones declaradas | PLAUSIBLE |
| 3 · k* ZEROX | 0-5,67 (media por `α,Δ`), frente a 30; converge en un paso | **VERIFICADO** |
| 4 · Latencia vs baseline | `ε=0,05`: 6-12 s media (mín 0,36 s) vs 97-146 s; `ε=10⁻¹²`: 16-109 s | **VERIFICADO** (red sana) |
| 4 · Cota del paper | 2,5-40× peor que lo medido; no decide ZEROX | VERIFICADO (cita) |
| 5 · Coste de consenso | R-FIN-6, suelo 3k, R-FIN-1, R-FIN-12, R-FIN-8′/13′ hay que re-derivarlos; R-FIN-5/14 no cambian; `F` no se baja sin recuperación del rank | PLAUSIBLE / LAGUNA |
| 6 · D8 (manipulación de k*) | el atacante infla k* a 27-50 (`Δ≥16`) y el suelo adaptativo supera el baseline | **REFUTADO** el k* crudo |
| Global | Baja el suelo 9-19× (`ε=0,05`) en red sana; **no es seguro bajo ataque de inflación sin el rank del paper** | — |

**Número que responde a la pregunta:** latencia mínima **0,36 s** (`α=0,10`, `ε=0,05`, `Δ=1`),
media **6,10 s** (`α=0,25`, `ε=0,05`) a **12,32 s** (`α=0,40`, `ε=0,05`) sobre la rejilla, frente
a **97-146 s** del baseline; con `ε=10⁻¹²`, **15,76 s** (`α=0,10`) a **108,69 s** (`α=0,40`).
Condición: red sana y `Δ ≲ 4-16 s`; con ataque de inflación a `Δ=20` el suelo vuelve a
100-250 s.

## Errores propios

1. **Criterio de k\* inicial gameable.** La primera rejilla usó «cobertura global ≥50 %» y dio
   `k*_all=0` a `α≥0,33`: el clúster «mayoritario» era la **cadena del atacante**. Corregido a
   «clúster mayoritariamente honesto y que cubre ≥50 % de los honestos» (Punto 3). El error está
   en `salida_kestrella.txt`; la corrección, en `salida_zerox.txt`. Lección: un criterio de
   mayoría que no fija *de quién* es la mayoría no mide seguridad.
2. **Baseline medido en blue_score.** El primer `d14_zerox.py` midió el margen como
   `max blue_score` visible y dio ~88 s a `α=0,40` (en vez de 150 s): el blue_score incluye
   azules del atacante. Corregido a bloques **honestos**, que es la unidad del suelo publicado.
   El primer resultado está en `salida_zerox.txt` (versión 1) y se sustituyó; la versión vigente
   es la del Punto 4.
3. **`construye_paper` con `D=None`** en la exploración 2 (fallo de tipos) y **`m.ev` desempaquetado
   a 2** en el primer `d14_zerox.py` (los eventos de `r8c_sim` son de 5 campos). Corregidos; no
   afectaron a ningún número publicado.
4. **Cota del paper mal leída al principio.** Se intentó reproducir 1,2/6/12 con la fórmula
   `(ln(1/ε)+Dλ)/(1−2α)+(Dλ)²`; la fórmula da 19,66/6,75/1,54, no la tabla. La tabla es de su
   simulación, no de la fórmula. Queda como LAGUNA, no como fallo del instrumento.

## Reproducción

```
cd research/scripts/d14-dagknight
python3 d14_control.py     # control positivo      -> salida_control.txt
python3 d14_zerox.py       # rejilla ZEROX         -> salida_zerox.txt, salida_zerox_crudo.txt
python3 d14_d8.py          # D8 manipulación de k* -> salida_d8.txt, salida_d8_crudo.txt
python3 d14_fp.py          # punto fijo del k      -> salida_fp.txt
python3 d14_explora{,2,3,4}.py   # exploraciones del control
python3 ../AUDITA_SCRIPTS.py .    # auditoría
```

## Auditoría de scripts (AUDITA_SCRIPTS.py)

```
$ python3 research/scripts/AUDITA_SCRIPTS.py research/scripts/d14-dagknight/
Scripts analizados: 10

======================================================================
Sospechas totales: 0
```

Las 10 marcas posibles (T1 parámetro `alpha` muerto, T2 literal que sobrescribe, T3/T3b
tautologías, T4 <12 semillas) están leídas: **0 sospechas**. El criterio complementario se cumple:
todo cambia con `α` (Puntos 3, 4 y 6) y el control reproduce una escala publicada (Punto 1).

**Nota de entrega.** Por instrucción explícita de la ronda («No ejecutes git»), no se hicieron
commits; `METODO-AGENTES.md:6` pide commit por punto y queda como la única desviación del método.
No se modificó ningún fichero fuera de `research/scripts/d14-dagknight/`.
