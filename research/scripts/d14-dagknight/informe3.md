# D14C — Cerrar o matar DAGKNIGHT sobre el DAG de PoAS

**Ronda 14C, tercera pasada.** Cierra los dos agujeros que dejó la auditoría D9b/D8b sobre
`informe2.md` (D14B):

1. **La regla de cliente del paper no se encontró en ninguna parte** (ni en el paper ni en la rama
   `dagknight` de `rusty-kaspa`). El control positivo 1,2/6/12 s sigue en **LAGUNA**.
2. **El ataque de retención + cadena privada** se reproduce (8-12/12 en el modelo D8b; **12/12** en
   la vista real del cliente con política `tips`) y se prueban las seis mitigaciones del enunciado
   más variantes derivadas. **Ninguna del enunciado lo cierra sin matar la ganancia o la liveness.**

**Resultado en una línea:** DAGKNIGHT queda **REFUTADO como vía publicable sin comité**; la
confirmación adaptativa sobrevive solo como **variante propia M2h** (no publicada por el paper),
que cierra la censura real con **30,5-51,7 s de media a ε=1e-6** (Δ=16-20, α=0,33) frente a
**130,41 s** del baseline, pero deja la métrica de captura del ataque en 3-9/12 y no está
certificada por ningún vector del paper.

---

## Fuentes y método

| Fuente | Uso |
|---|---|
| `research/fuentes/dagknight.txt` (latin-1) | Búsqueda de la regla de cliente en texto, apéndices, pseudocódigo y definiciones |
| `rusty-kaspa`, rama `origin/dagknight`, tip `3353678ae69703b5fb603a335e7466a3c0604794` (2026-09-07) | Árbol completo: `git ls-tree -r`, `git log --all`, `git grep` (solo lectura; **ninguna escritura de git**, ningún comando git en ZEROX) |
| `ref_umc_fixture.json` (md5 `41cf6d88…`, idéntico al de la rama) | Control positivo del instrumento (`d14k_fixture_test.py`) |
| `r8c_sim.py` + `r8c_gd.py` (d9-ronda8c) | Simulador de eventos y GHOSTDAG |
| `d14k_ref.py` | Rank fiel (Alg. 3/5/6 + UMC base + grises) validado contra el fixture |

**Corrección de método propia (vista real vs vista completa).** `Mundo.corre` devuelve todos los
bloques creados hasta T, incluidos los del atacante **aún no publicados** (`llega > T`). D8b y el
primer ataque de esta ronda los contaban. Aquí se separa:

- **vista completa** = todo lo creado hasta T (modelo D8b: revelación total al final);
- **vista real** = bloques con entrega ≤ T, **cerrada bajo ancestros**
  (`recv(b) = max(llega(b), max recv(padres))`): lo que un cliente honesto puede validar en T.

Todas las conclusiones de mitigación y latencia usan la **vista real**; la vista completa se
conserva para comparar con la auditoría. `d14k_visible2.py` mide ambas.

---

## Punto 1 · Regla de cliente fiel — **LAGUNA**

### 1.1 El paper no la publica (RESPALDADO POR FUENTE)

`dagknight.txt` (100 387 B, 1703 líneas) contiene los Algoritmos 1-6 (ordenación, rank,
tie-breaking, k-colouring, UMC-voting) y nada más. La regla de confirmación del cliente aparece
solo como descripción verbal:

| Línea | Texto |
|---|---|
| `:34-35` | «we require that the client specifies locally an upper bound over the maximum adversarial recent latency» |
| `:347-351` | «the parameter D too is set by the client—an underestimation … premature acceptance … an overestimation … wait more time» |
| `:996-999` | «the procedure for determining the robustness of the ordering – i.e., evaluating the function **risk** – is done by the client locally, **outside the context of consensus**» |
| `:1007` | cota optimista: `O((ln(1/ε)+Dλ)/(1−2α)+(Dλ)²)` — cota, no regla |
| `:1021-1027` | cota pesimista exponencial, «far from tight» |
| `:1064-1065` | «An implementation of Algorithm 2 and its subprocedures **will be made available online**» |

No hay «Algorithm 7», no hay pseudocódigo de `risk`, no hay definición de la función. La palabra
«risk» no aparece ni una vez en el texto (0 hits). **LAGUNA confirmada en el paper.**

### 1.2 La rama de referencia tampoco la tiene (VERIFICADO)

Búsqueda sobre el árbol completo (1381 ficheros) y **todas** las ramas, no solo el tip:

| Búsqueda | Resultado |
|---|---|
| `git ls-tree -r origin/dagknight` | 1381 ficheros; 15 con `dagknight`/`umc` en el nombre: todos en `consensus/` (protocol, manager, rank_search, tie_breaking, umc_*, stores, benches, fixture) |
| `git grep -i 'client'` en `consensus/src/processes/dagknight/` | **1 hit**: un comentario en `protocol.rs:73` («blue score … also for client confirmation counting») |
| `git grep -i 'risk'` en todo el árbol | 2 hits, ambos ajenos (pruning proof, `notify/`) |
| `git grep -i 'confirmation'` en todo el árbol | solo la confirmación estándar de Kaspa por blue score: `rpc/service/src/service.rs:430` (`confirmation_count = sink_blue_score − blue_score`), `min_confirmation_count` en RPC/wallet, docs de Toccata. **Nada de la función `risk` del paper** |
| `git log --all -- 'consensus/src/processes/dagknight'` | 60+ commits: coloración, UMC (baseline y cascade), tie-breaking, persistencia, wiring. Ninguno de cliente/confirmación |
| Tests y benches | `appendable_segment_tree`, `k_colouring`, `czm_lkt`, `tie_breaking`, `cascade`, `dag_from_json`, `monotonicity`, `parent_ordering`… ninguno mide tiempos de confirmación |

**Conclusión:** la implementación real cubre el **consenso** (rank + UMC + tie-breaking), no el
**cliente**. La frase del paper («will appear online») se cumple para el consenso; la función `risk`
y la simulación de la figura 3 no existen públicamente. **LAGUNA**, con esta búsqueda como prueba.

### 1.3 Lo que sí se pudo anclar: el fixture (VERIFICADO)

Se implementó `d14k_fixture_test.py` (corrección A3 de `audita-d9b.md`): carga el vector real de la
rama y exige, por la ruta de `d14k_ref`:

```
1 · rank_view(tips=[11,17]) = 0   (esperado 0)
    subgrupo NCA=b2  vsp=b11 blues=[11,10,9,7,6,5,4,3,2,1] rojos=[12..17] score=4
    subgrupo NCA=b12 vsp=b17 blues=[17,16,15,14,13,12,1]   rojos=[7,8,9,10,11] score=2
2 · umc_voting(zona [11], NCA=2, CG=1, k=0): aceptado=True score=4
    rojos=[12..17]  gris 8 excluido: True
3 · rank de la cadena pura 1..11 = 0
VEREDICTO: PASA
```

**Etiqueta: VERIFICADO** contra el vector publicado. Esto no cierra el control positivo del paper
(los tiempos 1,2/6/12 s siguen sin reproducirse: **LAGUNA**), pero ancla el instrumento.

---

## Punto 2 · Ataque de retención + cadena privada

### 2.1 Reproducción (DEMOSTRADO)

Ataque: el atacante ve todo al instante y publica con retraso R > Δ (política `tips` o `sp`), de
modo que los honestos de la ventana de retención quedan fuera de su pasado. `captura` = el ganador
del tie-breaking es de creador atacante y el tip honesto no está en su pasado; `captura_ref` =
además el tip honesto no está entre los azules del ganador (censura real). 12 semillas.

**Vista completa (modelo D8b) — `salida_ataque2.txt`:**

| α / Δ | instant | retraso20 (tips) | retraso20_sp | retraso60_sp |
|---:|---:|---:|---:|---:|
| 0,25 / 16 | 0\|0 | 8\|8 | 6\|5 | 8\|7 |
| 0,25 / 20 | 0\|0 | 8\|8 | 6\|6 | 5\|5 |
| 0,40 / 16 | 0\|0 | 5\|5 | 9\|9 | **12\|12** |
| 0,40 / 20 | 0\|0 | 5\|5 | **11\|9** | 7\|5 |

**Vista real del cliente (entrega ≤ T) — `salida_visible2.txt`:**

| α / Δ | instant | retraso20 (tips) | retraso20_sp | retraso60_sp |
|---:|---:|---:|---:|---:|
| 0,25 / 16 | 0\|0 | **12\|12** | 7\|6 | 0\|0 |
| 0,25 / 20 | 1\|1 | 8\|8 | 8\|8 | 0\|0 |
| 0,40 / 16 | 0\|0 | **12\|12** | 3\|2 | 0\|0 |
| 0,40 / 20 | 0\|0 | 7\|7 | 9\|8 | 0\|0 |

- El ataque de la auditoría (`sp` con retraso) se reproduce en la vista completa (5-12/12); en la
  vista real, `retraso20_sp` captura **3-9/12**; con política `tips` (`retraso20`) la vista real
  captura **12/12** a Δ=16.
- `retraso60_sp` cae a 0/12 en la vista real: a T=400 sus bloques de los últimos 60 s no están
  publicados, así que no pueden capturar la vista del cliente. La vista completa lo sobreestimaba.
- `instant` (red sana) no captura (0/12; el 1/12 de α=0,25 Δ=20 es ruido de frontera).

**Etiqueta: DEMOSTRADO** para `retraso20` (12/12) y **VERIFICADO** para la reproducción D8b.

### 2.2 Las seis mitigaciones del enunciado (VERIFICADO)

Rejilla sobre la vista real, α∈{0,25;0,40}, Δ∈{16,20}, 12 semillas (`salida_mitigaciones_vis.txt`).
Celda = `captura D8b | captura_ref (congelación)`; se resume la peor celda de ataque:

| # | Mitigación | Peor captura (D8b \| ref) | Congelación | ¿Cierra? |
|---|---|---|---|---|
| (a) | M2: cubrir la **cadena global** (todos los tips) | **0\|0** | **hasta 12/12** en ataque (1-9/12 en red sana) | Cierra, **mata liveness** |
| (b) | M3: cierre de ancestros (sin huecos) | 12\|12 (retraso20) | 0-7/12 | **No** |
| (c) | UMC/grises tal como el paper | — | — | Ya es la regla base; el ataque la atraviesa |
| (d) | M1: tope de k (K=4/8/16) | 12\|12 (retraso20, K=8/16); 8\|7 (K=4, retraso20_sp) | 0-6/12 | **No** |
| (e) | M4: mayoría honesta en el clúster | 7\|6 (retraso20_sp) | 0-8/12 | **No** |
| (f) | M5: rank del tip honesto ≠ None | 12\|12 (= M0) | 0-9/12 | **No cambia la selección** |

Ninguna de las seis cierra el ataque sin coste. Las combinaciones M2∧M3, M2∧M4, M2∧M3∧M4 cierran
la captura pero heredan la congelación de M2 (hasta 12/12). M3∧M4 y cap8∧M4 tampoco cierran.

**Etiqueta: VERIFICADO** (comparación completa en `salida_mitigaciones_vis.txt`).

### 2.3 Variantes derivadas que sí cierran (una parte)

| Regla | Qué exige | Captura D8b \| ref | Congelación (ataque / sana) |
|---|---|---|---|
| **R1** | el pasado del VSP ganador contiene el tip honesto | **0\|0** | **12/12 / 12/12** |
| **R1b** | el tip honesto está en el pasado **o en los azules** del ganador | 0-2\|0 | 0-9/12 / 1-9/12 |
| **M2h** | los azules del ganador cubren la **cadena honesta** (tip→CG) | 3-9\|**0** | 0-2/12 / **0/12** |

- **R1** cierra la métrica de la auditoría pero congela siempre: mata la liveness.
- **R1b** cierra la métrica D8b en 0-2/12, pero congela hasta 9/12 incluso en red sana (`instant`).
- **M2h** cierra la **censura real** (0/12 en las 16 celdas de ataque y en red sana), con
  congelación ≤2/12, pero deja la métrica D8b en 3-9/12: son los casos en que el tip honesto es
  azul del ganador (está incluido en el orden) pero la cadena seleccionada del atacante no
  desciende de él. Es la diferencia entre **inclusión** (M2h la garantiza) y **precedencia en la
  cadena** (solo R1 la garantiza, y congela).

**Etiqueta: PLAUSIBLE** que M2h sea suficiente para un comerciante (la transacción entra en el
orden); **REFUTADO** que baste para el criterio de la auditoría (precedencia en la cadena
seleccionada) sin pagar liveness.

### 2.4 D8 propio de la mitigación: el atacante sube la retención (VERIFICADO)

`d14k_d8_mitigacion.py`: α=0,40, Δ=20, R∈{20,60,80,120,160,1000} s, 12 semillas, vista real.
M2h: `cap_ref = 0/12` en **todas** las R y ambas políticas; congelación 0-2/12. El atacante solo
consigue subir `k_conf` y la latencia:

| Política | R=20 | R=60 | R=80 | R=120 | R=160 |
|---|---:|---:|---:|---:|---:|
| tips: k_conf medio | 4,4 | 14,9 | 14,2 | 11,0 | 12,0 |
| tips: latencia media [máx] | 55,6 [70,4] | 78,7 [148,2] | 83,0 [129,5] | 64,7 [99,7] | 66,6 [114,6] |
| sp: k_conf medio | 12,7 | 8,9 | 7,5 | 10,2 | 10,1 |
| sp: latencia media [máx] | 72,9 [158,2] | 60,7 [90,9] | 58,5 [81,9] | 61,3 [83,9] | 61,7 [83,9] |

El atacante **no puede derrotar M2h** subiendo la retención: no captura ni congela; paga latencia.
(baseline α=0,40: 150,0 s de suelo.)

---

## Punto 3 · Latencia publicable en el peor caso de red

**Mitigación:** M2h (el k-clúster confirmado cubre la cadena honesta del cliente), que es la única
que cierra la censura real (0/12) sin congelar en red sana (0/12). α=0,33, λ=1, T=400 s, 12
semillas, vista real, M = max(3k, m(α,ε)) con `m = ⌈ln ε / ln(α/(1−α))⌉` (misma convención que
`informe2.md`/`d14k_zerox2.py`). `salida_visible2.txt` y `salida_latencia2.txt`:

| Δ | estrategia | ε=1e-6 media [mín,máx] | ε=1e-12 media [mín,máx] | cap_ref | cong |
|---:|---|---:|---:|---:|---:|
| 16 | instant | 30,5 [15,2; 40,9] | 55,7 [36,2; 68,4] | 0/12 | 0/12 |
| 16 | retraso20 | 34,4 [15,2; 60,7] | 55,7 [36,2; 68,4] | 0/12 | 0/12 |
| 16 | retraso20_sp | 41,7 [17,1; 69,5] | 56,7 [36,2; 69,5] | 0/12 | 0/12 |
| 16 | retraso60_sp | 37,9 [17,1; 94,2] | 58,8 [36,2; 94,2] | 0/12 | 0/12 |
| 20 | instant | 32,1 [15,2; 50,5] | 55,7 [36,2; 68,4] | 0/12 | 0/12 |
| 20 | retraso20 | 33,5 [15,2; 60,7] | 55,7 [36,2; 68,4] | 0/12 | 0/12 |
| 20 | retraso20_sp | 47,7 [23,7; 78,9] | 59,4 [36,2; 78,9] | 0/12 | 0/12 |
| 20 | retraso60_sp | 51,7 [19,8; 93,7] | 61,7 [36,2; 93,7] | 0/12 | 0/12 |

**Comparación con el baseline:** `130,41 s` medido a α=0,33 (suelo 3·30/((1−α)λ) = 134,3 s). La
mitigación baja la media a **30,5-51,7 s (ε=1e-6)** y **55,7-61,7 s (ε=1e-12)**: **2,5-4,3×** y
**2,1-2,3×**. Mínima global: **15,19 s**. Máxima: **94,25 s** (por debajo del baseline en todas
las semillas medidas). Suelo teórico de M2h: 30,3-64,1 s.

**Cotas de contraste:** la cota optimista del paper (`:1007`) a Δ=16-20 da **343,7-540,1 s** (peor
que el baseline); la cota de la auditoría para M3 (mayoría honesta) era 123-170 s. M2h es la única
medida que queda por debajo del baseline con garantía de no-censura.

**Condiciones (sin las cuales el número no es publicable):**
1. **La regla M2h es nuestra, no del paper.** El paper no publica su regla de cliente (LAGUNA).
2. **Pesos uniformes.** `d14k_ref` usa conteos; ZEROX usa `blue_work` variable
   (`dag-poas-ancla-de-orden.md:157`). La medida bajo pesos reales **no está demostrada** (auditoría
   R4/N1). Un atacante que concentre `SR` bajo puede alterar pesos y votos.
3. **Vista real**, no la vista completa del simulador; la latencia no incluye el tiempo de
   propagación del propio mensaje de confirmación.
4. La métrica de la auditoría (precedencia en la cadena) sigue en 3-9/12 bajo M2h; solo R1 la
   cierra, y R1 congela 12/12.

---

## Veredicto

| Punto | Resultado | Etiqueta |
|---|---|---|
| 1 · Regla de cliente del paper | No existe en el paper ni en la rama (1381 ficheros, todas las ramas); solo cotas y «will appear online». Control 1,2/6/12 s no reproducible | **LAGUNA** |
| 1 · Instrumento vs fixture de la rama | `virtual_score=4`, rojos 12..17, rank 0, cadena pura rank 0; `d14k_fixture_test.py` PASA | **VERIFICADO** |
| 2 · Ataque retención+cadena privada | Vista completa (D8b): 5-12/12. Vista real: `retraso20` **12/12** (Δ=16), `retraso20_sp` 3-9/12, `retraso60_sp` 0/12; `instant` 0/12 | **DEMOSTRADO** |
| 2 · Mitigaciones (a)-(f) del enunciado | Ninguna cierra sin matar ganancia/liveness: (a) congela 12/12; (b) no; (c) ya está; (d) no; (e) parcial; (f) sin efecto | **VERIFICADO** |
| 2 · Variantes derivadas | R1 cierra pero congela 12/12; R1b cierra D8b 0-2/12 pero congela hasta 9/12 en red sana; M2h cierra censura real 0/12 con cong ≤2/12 | **PLAUSIBLE** (M2h) / **REFUTADO** (suficiencia estricta) |
| 2 · D8 de M2h (retención creciente) | `cap_ref=0` y cong ≤2/12 para R=20…160 s, tips y sp; el atacante solo paga latencia | **VERIFICADO** |
| 3 · Latencia α=0,33, Δ=16-20 | M2h: **30,5-51,7 s media** (ε=1e-6), **55,7-61,7 s** (ε=1e-12), mín 15,19 s, máx 94,25 s; baseline **130,41 s** | **PLAUSIBLE con condiciones** (regla propia + pesos uniformes) |
| 4 · DAGKNIGHT como vía publicable sin comité | La regla publicada es capturada; la regla de cliente no existe; la única mitigación que cierra la métrica estricta mata la liveness | **REFUTADO** |

**Número que responde a la misión.** El ataque captura **12/12** semillas (retención + política
`tips`, α=0,40, Δ=16, vista real) y **9/12** con la variante `sp` de la auditoría (α=0,40, Δ=20).
La única mitigación que cierra la censura real sin congelar da **30,5-51,7 s de media** a α=0,33,
ε=1e-6, Δ=16-20 (**55,7-61,7 s** a ε=1e-12), frente a **130,41 s** del baseline: una ganancia de
**2,5-4,3×**, pero **no es DAGKNIGHT** (la regla es propia) y **no cierra la métrica de precedencia
de la auditoría** (3-9/12). Con la regla que sí la cierra (R1) el cliente no confirma nunca
(12/12 congelado). Por eso: **REFUTADO**.

---

## Errores propios

1. **Medí el ataque y la mitigación sobre la «vista completa» del simulador**, que incluye bloques
   del atacante aún no publicados en T. La auditoría D8b lo hacía igual y yo lo heredé en la
   primera pasada de esta ronda. Corregido con la vista real cerrada bajo ancestros
   (`d14k_visible2.py`): cambia el ataque (`retraso60_sp` pasa de 5-12/12 a 0/12) y mejora la
   latencia de M2h (de 70-87 s a 30-52 s). El error estaba en mi instrumento, no en el paper.
2. **Casi declaro que M2h tenía un DoS de liveness (cong 6/12 con R=80-160)** antes de corregir la
   vista: el `cong` era un artefacto de contar bloques no publicados. Con la vista real, `cong` es
   0-2/12. Lo dejo escrito porque la primera medición era falsa.
3. **Definí `captura` de dos formas y las mezclé al principio.** La métrica de la auditoría
   (tip honesto fuera del pasado del ganador) y la que llamo `captura_ref` (además, no azul) no son
   equivalentes: en 3-9/12 de las celdas el atacante gana la métrica D8b con el tip honesto azul
   (incluido en el orden). Reporto ambas; la conclusión de REFUTADO usa la de la auditoría.
4. **La mitigación M2 «cadena global» de D8b no es aplicable con multi-tip**: exige cubrir ramas
   del atacante que el clúster honesto nunca puede alcanzar, por eso congela 12/12. La variante
   correcta es M2h (cadena honesta sobre CG), que es la que mido.
5. **El primer D8 de M2h usaba solo política `sp`.** La política `tips` es la que más captura en
   la vista real (12/12). Rehecho con ambas.
6. **Cita heredada errónea:** `d14k_control2.py` etiqueta «M_kMC fiel (Alg. 1…)»; Alg. 1 es
   Order-DAG naïve y M_kMC es el recuadro `dagknight.txt:114-119` (ya corregido por la auditoría;
   no lo repito en este informe).
7. **`k_hon` con `None` cuenta como congelación solo desde la corrección de esta ronda.** Antes el
   script devolvía `k_hon=None` con `cong=0` (incoherente). Corregido; afecta a M5 (f), no a las
   conclusiones.

---

## Reproducción

```
cd research/scripts/d14-dagknight
python3 d14k_fixture_test.py        # control del instrumento vs fixture  -> salida_fixture_test.txt
python3 d14k_ataque2.py             # ataque D8b, vista completa          -> salida_ataque2.txt
python3 d14k_visible2.py            # ataque + M2h, vista real            -> salida_visible2.txt
python3 d14k_mitigaciones_vis.py    # rejilla de mitigaciones, vista real -> salida_mitigaciones_vis.txt
python3 d14k_latencia2.py           # latencia α=0,33, vista real         -> salida_latencia2.txt
python3 d14k_d8_mitigacion.py       # D8 de M2h (R creciente)             -> salida_d8_mitigacion.txt
python3 ../AUDITA_SCRIPTS.py .      # auditoría                           -> salida_audita3.txt
```

Evidencia de la búsqueda de la regla de cliente: `busqueda_regla_cliente.txt`.
Los scripts `d14k_sondeo.py` y `d14k_explora_cierre.py` son exploratorios y no generan tablas.

## Auditoría de scripts (AUDITA_SCRIPTS.py)

```
$ python3 research/scripts/AUDITA_SCRIPTS.py research/scripts/d14-dagknight/
Scripts analizados: 24

======================================================================
Sospechas totales: 0
```

Marcas T1-T4 leídas: 0 sospechas. Todo cambia con α y Δ en las tablas de esta ronda (Puntos 2-3),
≥12 semillas por celda, y el control del fixture valida el instrumento contra el vector de la
implementación de referencia.
