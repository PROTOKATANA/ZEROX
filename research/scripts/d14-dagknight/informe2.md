# D14B — DAGKNIGHT sobre el DAG de PoAS: regla FIEL, control positivo y re-medición

**Ronda 14B, segunda pasada.** Corrige y amplía `informe.md` (D14A). Katana descartó toda
opción con comité: la confirmación adaptativa sobre el DAG de PoAS es la única vía viva para
bajar la irreversibilidad. Este informe responde a los tres problemas que dejó la 1.ª pasada:

1. **El control positivo del paper no se reprodujo.** Aquí se implementa la regla tal como la
   define el paper y, además, se localiza su **implementación de referencia** y se valida
   contra su vector de test. El control sigue sin dar la tabla 1,2/6/12 s: LAGUNA con lo que
   falta, dicho con precisión.
2. **D8 refutó el `k*` crudo** (cobertura global ≥ 50 %). Aquí se re-mide con la regla fiel,
   se busca el umbral de `Δ` y se prueban cuatro mitigaciones.
3. **La latencia de la 1.ª pasada (8-56 s a α=0,33) no valía como DAGKNIGHT.** Como el control
   positivo no cierra, todo número ZEROX de este informe queda etiquetado como
   **«adaptación propia sobre GHOSTDAG / rank fiel»**, nunca como latencia DAGKNIGHT
   demostrada.

## Fuentes nuevas de esta pasada (verificadas)

| Fuente | Qué aporta |
|---|---|
| `research/fuentes/dagknight.txt` y `dagknight.pdf` (eprint 2022/1494, rev. 2023-02-24; el PDF local es idéntico al publicado: md5 `3cbb829c…`) | Alg. 1-6, definiciones, cota `:1007`, figura 3 |
| **`kaspanet/rusty-kaspa`, rama `dagknight`** (leída por API el 2026-09-10) | Implementación real: `protocol.rs` (`select_parent_from_k_colouring`, `rank`), `manager.rs` (`fill_zone_data`, `k_colouring`), `umc_baseline.rs` (Alg. 6 ponderado), `tie_breaking.rs`, y el vector `consensus/umc_fixture.json` |
| `coderofstuff/dk-wiki` (wiki de un dev de Kaspa, cap. 03/05/06/07/08) | Confirma el mecanismo de **bloques grises** (equivalente práctico de los representantes de Alg. 3) |

**Hallazgo.** El paper decía que su implementación «aparecería online» (`:1064-1065`); existe:
la rama `dagknight` de `rusty-kaspa`. Eso convierte el rank en algo reproducible contra una
implementación real, no solo contra el texto. El **cliente** (la regla de confirmación) sigue
sin publicarse ni en el paper ni en la rama.

## Punto 1 · La regla fiel implementada

`d14k_ref.py` reproduce el pipeline de la rama `dagknight`:

1. **Zona de conflicto**: `CG` = LCA de cadena de los tips; subgrupos = tips agrupados por su
   *next chain ancestor* (NCA) por encima de `CG`.
2. **Coloreado comprometido** (`fill_zone_data`, `manager.rs:440-580`): GHOSTDAG(`k`) sobre la
   zona (descendientes de cadena del NCA), con el padre seleccionado forzado a padres que
   acuerdan.
3. **Bloque virtual**: `parents` = todos los tips, `sp` = VSP del subgrupo (máximo blue work);
   su mergeset se colorea con GHOSTDAG(`k`).
4. **UMC-Voting base** (`umc_baseline.rs`): votos azules en cascada,
   `vote(B) = sign(Σ votos azules en future(B) − |rojos∩future(B)| + g(k))`,
   `g(k)=⌊√k⌋`; `virtual_score = Σ votos + g(k) − |rojos|`; acepta si ≥ 0.
   **Grises** = rojos que descienden del NCA (no votan), equivalente práctico de los
   representantes de Alg. 3.
5. **rank(vista)** = mínimo `k` con algún subgrupo aceptado (`RankSearcher`).

**Validación contra el vector de la implementación de referencia** (`ref_umc_fixture.json`,
zona con gris `8`, `k=0`): `virtual_score = 4` y rojos `12..17` — **idénticos** al oráculo
`expected_score()` de `umc_voting.rs:274-277`. El rank de una cadena pura es 0. Esto es
VERIFICADO contra código de referencia, no contra el texto.

## Punto 2 · Control positivo — **PARCIAL / LAGUNA**

Objetivo (`dagknight.txt:182-197`): λ=3,75, α=0,2, D=0,1/1/2 s, ε=0,05 → `k=0/1/4` y tiempos
**1,2/6/12 s**. Vista honesta μ=(1−α)λ=3; atacante invisible (revelado al final). 12 semillas.

**A · M_kMC fiel** (Alg. 1: mínimo `k` con el mayor `k`-cluster cubriendo ≥50 %), media de 12
semillas [rango]:

| D | T=1,2 s | T=6 s | T=12 s | T=24 s | figura |
|---:|---:|---:|---:|---:|---:|
| 0,1 | 0,00 [0] | 0,00 [0] | 0,00 [0] | 0,00 [0] | **0** |
| 1,0 | 0,75 [0-2] | 1,58 [1-2] | 1,75 [1-2] | 1,83 [1-2] | **1** |
| 2,0 | 0,83 [0-2] | 2,42 [1-3] | 2,92 [2-4] | 2,92 [2-4] | **4** |

**B · M_kMC fiel sobre el DAG completo** (atacante invisible revelado al final):

| D | T=1,2 s | T=6 s | T=12 s | T=24 s | figura |
|---:|---:|---:|---:|---:|---:|
| 0,1 | 0,17 [0-1] | 0,00 [0] | 0,08 [0-1] | 0,08 [0-1] | **0** |
| 1,0 | 0,75 [0-2] | 1,92 [1-2] | 2,17 [2-3] | 2,00 [2] | **1** |
| 2,0 | 0,75 [0-2] | 2,50 [2-3] | **3,33 [2-4]** | 3,50 [3-4] | **4** |

El rango publicado (0/1/4) está contenido en la distribución (D=1 tiene semillas con 1; D=2
tiene semillas con 4), pero la media no es el entero de la figura: la figura muestra **una
realización**, no la media. El `k` del paper es el del problema de optimización (cobertura
≥50 %), no el rank del protocolo.

**C · rank del protocolo** (regla fiel, `d14k_ref`): medias 0,08-0,92 (honesta) y 0,08-1,00
(completa). Es **mucho menor** que el `k` de la figura porque los grises neutralizan el
paralelismo honesto: el rank mide solo la divergencia adversarial, no el ancho total.

**D · reglas de cliente candidatas** (vista honesta, basadas en el rank): «1.er rank == final»
da 0,36/0,69/0,87 s para D=0,1/1/2 — **no** 1,2/6/12. La cota optimista del paper
(`:1007`) da 1,54/6,75/19,66 s, que se acerca a 1,2/6 para D≤1 y se va a 19,66 para D=2.

**Lo que falta exactamente (LAGUNA).** El paper publica el algoritmo de consenso y las cotas
asintóticas, pero **no** publica (i) la regla de riesgo/confirmación del cliente —solo dice que
es local, `:996-999`—, (ii) el código de la simulación de la figura —`will appear online`
(`:1064-1065`) no está en el PDF ni en la rama `dagknight`—, ni (iii) los detalles del
experimento (semillas, instante de la transacción, definición exacta de «confirmation time»).
Sin (i)-(iii), la tabla 1,2/6/12 s no es reproducible. **Etiqueta: PARCIAL para `k`; LAGUNA
para los tiempos.**

## Punto 3 · Rejilla ZEROX con la regla fiel — **VERIFICADO como medida, adaptación como latencia**

λ=1, T=400 s, 12 semillas, `r8c_sim` (topología ZEROX R-FIN-12), DAG visible (atacante
público). `k_ref` = rank fiel; `k_mkmc` = M_kMC fiel. Media [mín,máx]:

| α | Δ=1 | Δ=4 | Δ=8 | Δ=16 | Δ=20 |
|---:|---:|---:|---:|---:|---:|
| 0,10 k_ref | 0,17 [0-1] | 0,67 [0-2] | 1,50 [0-4] | 1,50 [0-4] | 2,58 [0-9] |
| 0,10 k_mkmc | 0,00 [0] | 1,58 [1-2] | 2,42 [2-3] | 3,67 [3-4] | 3,75 [3-4] |
| 0,25 k_ref | 0,08 [0-1] | 0,42 [0-2] | 0,58 [0-3] | 0,58 [0-3] | 0,58 [0-3] |
| 0,25 k_mkmc | 0,00 [0] | 0,17 [0-1] | 1,00 [1] | 1,00 [1] | 1,00 [1] |
| 0,33 k_ref | 0,08 [0-1] | 0,25 [0-2] | 0,25 [0-2] | 0,25 [0-2] | 0,25 [0-2] |
| 0,33 k_mkmc | 0,00 [0] | 0,00 [0] | 0,00 [0] | 0,00 [0] | 0,00 [0] |
| 0,40 k_ref | 0,00 [0] | 0,08 [0-1] | 0,08 [0-1] | 0,08 [0-1] | 0,08 [0-1] |
| 0,40 k_mkmc | 0,00 [0] | 0,00 [0] | 0,00 [0] | 0,00 [0] | 0,00 [0] |

El `k` fiel es **0-2,6** de media (frente a `k=30` del baseline): el DAG de ZEROX es estrecho
(R-FIN-12 ya elige `sp` por blue_work y acota a 15 padres). `k` **decrece con α** porque la
tasa honesta baja.

**Latencia (adaptación declarada).** Margen `M = max(3k, m(α,ε))`, con
`m = ⌈ln ε / ln(α/(1−α))⌉` (ruina del jugador, misma fórmula que la 1.ª pasada); tiempo de
calendario hasta el M-ésimo honesto tras B*. Baseline k=30: **97,1/115,9/130,4/145,8 s**
(α=0,10/0,25/0,33/0,40), reproduce el suelo publicado.

**α=0,33 (el caso de la 1.ª pasada), media [mín,máx] con `k_ref`:**

| ε | k_ref medio | latencia media | mínima | suelo M/((1−α)λ) |
|---|---:|---:|---:|---:|
| 0,05 | 0,22 | **7,92 s** | **3,29 s** | 7,6 s |
| 10⁻³ | 0,22 | **14,14 s** | 8,67 s | 14,9 s |
| 10⁻⁶ | 0,22 | **29,62 s** | 15,19 s | 29,9 s |
| 10⁻¹² | 0,22 | **55,67 s** | 36,22 s | 59,7 s |

Resumen por α (media/mínima sobre Δ y semillas, `k_ref`): α=0,10 → 4,80/0,36 s (ε=0,05) y
14,46/8,67 s (10⁻¹²); α=0,25 → 4,47/0,44 y 33,89/17,68; α=0,40 → 12,32/7,25 y 108,69/71,53.
**Mejora 9-19× a ε=0,05.** El número no cambia apenas frente a la 1.ª pasada porque `m(α,ε)`
domina a `3k_ref`; el mérito de la regla fiel está en que **no se infla** (Punto 4), no en
bajar la mediana.

**Etiqueta:** la *medida de `k_ref`* es VERIFICADA (implementación de referencia validada); la
*latencia* es **adaptación propia** (la regla de cliente del paper no está publicada; el
control positivo no cierra).

## Punto 4 · D8 propio con la regla fiel: manipulación, umbral y mitigaciones

Estrategias del atacante sobre el mismo calendario, α∈{0,10;0,25;0,40}, Δ∈{1,4,8,16,20},
12 semillas. `k_ref` medio [mín,máx] (extracto; tabla completa en `salida_d8b.txt`):

| α / Δ | instant | retraso20 | retraso60 | burst300 | parásita5 | retro500 |
|---:|---:|---:|---:|---:|---:|---:|
| 0,10 / 16 | 1,5 [0-4] | 2,2 [0-7] | 1,2 [0-4] | 1,5 [0-4] | 2,1 [0-7] | 0,4 [0-5] |
| 0,10 / 20 | 2,6 [0-9] | 1,9 [0-7] | 2,6 [0-8] | 2,6 [0-9] | 0,2 [0-3] | 0,8 [0-2] |
| 0,25 / 16 | 0,6 [0-3] | 0,6 [0-4] | 0,0 [0] | 0,6 [0-3] | 1,6 [0-8] | 0,3 [0-1] |
| 0,25 / 20 | 0,6 [0-3] | 0,3 [0-4] | 1,1 [0-10] | 0,6 [0-3] | 0,8 [0-9] | **4,6 [1-9]** |
| 0,40 / 16 | 0,1 [0-1] | 0,0 [0] | 0,0 [0] | 0,1 [0-1] | 0,3 [0-4] | 1,4 [0-3] |
| 0,40 / 20 | 0,1 [0-1] | 0,0 [0] | 0,0 [0] | 0,1 [0-1] | 0,7 [0-3] | **7,8 [3-11]** |

**Suelo bajo la peor estrategia** `3·max k_ref/((1−α)λ)`: α=0,10 → 3,3/6,7/13,3/23,3/30,0 s
(Δ=1/4/8/16/20); α=0,25 → 4,0/8,0/12,0/32,0/40,0 s; α=0,40 → 5,0/5,0/10,0/20,0/55,0 s.
**Todos por debajo del baseline (100/120/150 s) incluso a Δ=20.** El `k_mkmc` fiel también
se mantiene (suelo ≤55 s); la inflación a 27-50 que refutó al `k*` crudo **no reaparece** con
la regla fiel: los grises y la UMC absorben la retención. **Umbral de Δ con `k_ref`: no se
alcanza dentro de Δ≤20** (la ganancia sobrevive a todo lo probado). La 1.ª pasada inflaba
porque exigía cobertura de *honestos* con el colorador GHOSTDAG crudo; la regla fiel mide otra
cosa.

**Pero la inflación no era el único riesgo: la *selección del subgrupo*.** Medido en
`salida_d8c.txt` (12 semillas): con `parásita5`/`retro500` hay un ganador mayoritariamente
honesto en 12/12 y el tie-breaking tipo Alg. 4 lo elige en 12/12. Con **`retraso20`/
`retraso60`, Δ≥16, α≥0,25, no hay ningún ganador honesto en 0-3/12**: el subgrupo del
atacante pasa la UMC con `k` bajo (los honestos que descienden de su NCA quedan grises). El
rank bajo **no garantiza** que el ganador sea honesto; hace falta el tie-breaking y, en ese
régimen, ninguno de los ganadores lo es.

**Mitigaciones probadas** (`salida_d8b.txt`, Δ≥16):

| Mitigación | Qué hace | Resultado |
|---|---|---|
| **M1 tope de `k`** (`min(k_ref,K)`, K=4/8/16) | acota el margen | **No hace falta**: `k_ref` ya es 0-8; el tope casi no cambia el suelo y **no arregla** la selección |
| **M2 exigir cubrir la cadena seleccionada** | sube `k` hasta que la cadena GHOSTDAG esté en los azules | Seguro pero caro: `k_chain` sube a 5-38; suelo hasta ~120 s (α=0,10) y ~165 s (α=0,40) a Δ=20 → **mata la ganancia en α=0,10/0,40** |
| **M3 exigir mayoría honesta + cobertura ≥50 % honestos** (criterio 1.ª pasada) | sube `k` hasta un cluster honesto | `k_hon` 12-27 (máx 34); suelo medio 123/144/127 s a Δ=20 (α=0,10/0,25/0,40) → **el umbral de Δ baja a 16**; **no es mitigación, es el defecto que refutó D8** |
| **M4 tie-breaking del paper (Alg. 4, proxy)** | elige entre ganadores de igual rank | **Funciona cuando existe ganador honesto** (12/12 en parásita/retro); **impotente** con retraso20/60 a Δ≥16 (no hay ganador honesto que elegir) |

**Qué funciona.** (a) La regla fiel (grises + UMC) elimina la inflación de `k` que refutó al
`k*` crudo: el suelo adaptativo se queda en 3-55 s contra 100-150 s del baseline, sin umbral
de Δ dentro de lo probado. (b) El tie-breaking es necesario y suficiente **para seleccionar**
al ganador honesto cuando este pasa la UMC. (c) Ninguna de M1-M3 mejora eso; M2/M3 pagan la
seguridad con la latencia (M3 devuelve el problema de D8 a Δ=20). (d) Queda un ataque abierto
(retraso de publicación con Δ≥16 y α≥0,25) que el rank solo no cubre; sin Order-DAG completo
no se puede cerrar aquí.

## Veredicto

| Punto | Resultado | Etiqueta |
|---|---|---|
| 0 · Regla fiel implementada | Alg. 3/5/6 + zona comprometida + grises + UMC base; `virtual_score=4` idéntico al vector de `rusty-kaspa@dagknight` | **VERIFICADO** |
| 1 · Control positivo | `k` M_kMC fiel en rango 0/1-2/3-4 (figura 0/1/4); rank del protocolo 0,1-1,0; **tiempos 1,2/6/12 s NO reproducidos**; falta la regla de cliente y el código de simulación | **PARCIAL / LAGUNA** |
| 2 · Rejilla ZEROX con rank fiel | `k_ref` 0-2,6 de media (máx 9); `k_mkmc` ≤3,75; `k` decrece con α | **VERIFICADO** (medida) |
| 3 · Latencia α=0,33 | ε=0,05: **7,92 s** media (mín 3,29); 10⁻³: 14,14; 10⁻⁶: 29,62; 10⁻¹²: 55,67 s; baseline 130,4 s | **adaptación propia** (no DAGKNIGHT) |
| 4 · D8 con regla fiel | el atacante **no infla** `k_ref`: suelo ≤55 s vs baseline 100-150 s; umbral de Δ **no alcanzado** (≥20) | **REFUTADA** la extrapolación de D8 al rank fiel; **VERIFICADO** el suelo |
| 4 · Selección de subgrupo | retraso20/60, Δ≥16, α≥0,25: 0-3/12 con ganador honesto; parásita/retro: 12/12 | **REFUTADO** que el rank solo baste; **LAGUNA** sin Order-DAG |
| 4 · Mitigaciones | M1 innecesaria; M2/M3 matan la ganancia a Δ=20; M4 funciona cuando hay ganador honesto | **VERIFICADO** (comparación) |
| Global | La regla fiel arregla la inflación de la 1.ª pasada y mantiene la ganancia 9-19× a ε=0,05, pero (i) no es DAGKNIGHT certificado (control sin cerrar) y (ii) tiene un ataque de selección abierto a Δ≥16 | — |

**Número que responde a la pregunta:** latencia mínima **3,29 s** y media **7,92 s** a α=0,33,
ε=0,05, sobre la rejilla ZEROX con `k_ref` (adaptación), frente a **130,4 s** del baseline.
Con ε=10⁻¹², 36,22/55,67 s. Condición: red visible y Δ ≤ 20 en lo medido; el ataque de
retraso a Δ≥16 deja un hueco de seguridad que el rank solo no cierra.

## Errores propios

1. **La 1.ª pasada midió el `k*` equivocado.** Usó «cobertura global ≥50 %» con GHOSTDAG
   crudo, no la UMC de Alg. 6 ni los grises de la implementación real. El `k*` inflado a
   27-50 bajo retención era un artefacto del criterio, no del protocolo. Corregido aquí.
2. **La 1.ª pasada declaró LAGUNA sobre el algoritmo.** Falso: la implementación existe
   (`rusty-kaspa@dagknight`). No se buscó fuera de `PDF/`. La lección de la casa («fuente
   primaria antes que memoria») se aplica también a *código de referencia*: el paper dice que
   publicará la implementación; había que buscarla.
3. **`d14k_lib.py` original tenía el rank UMC mal interpretado** (contexto `G\future(r)`
   incluyendo a `r`, sin grises). Daba ranks absurdos (2-18 en el control). Corregido con la
   semántica de la rama `dagknight`; el vector de test lo valida.
4. **`agrees` mal leído al principio.** Se implementó como «una sola cadena» (Def. 3); la
   lectura correcta es «mismo *next chain ancestor* tras el conflict genesis». Cambia el
   coloreado; corregido en `d14k_ref.py`.
5. **La medida de honestidad inicial usaba `winners[0]`**, que puede ser un subgrupo atacante;
   la pregunta correcta es si existe *algún* ganador honesto (`salida_d8c.txt`). Corregido.
6. **Tres sospechas de auditoría corregidas** (T2 `cg`, T3 `r[6]==r[6]`, T3b duplicados);
   `AUDITA_SCRIPTS.py` da 0 sospechas (abajo).

## Reproducción

```
cd research/scripts/d14-dagknight
python3 d14k_control2.py    # control positivo        -> salida_control2.txt
python3 d14k_zerox2.py      # rejilla ZEROX          -> salida_zerox2.txt (+_crudo)
python3 d14k_d8b.py         # manipulación/umbral    -> salida_d8b.txt (+_crudo)
python3 d14k_d8c.py         # selección de subgrupo  -> salida_d8c.txt (+_crudo)
python3 ../AUDITA_SCRIPTS.py .   # auditoría
```

Los scripts de la 1.ª pasada (`d14_*.py`) se conservan sin borrar; este informe los corrige.

## Auditoría de scripts (AUDITA_SCRIPTS.py)

```
$ python3 research/scripts/AUDITA_SCRIPTS.py research/scripts/d14-dagknight/
Scripts analizados: 16

======================================================================
Sospechas totales: 0
```

Las marcas T1 (α muerto), T2 (literal que sobrescribe), T3/T3b (tautologías) y T4 (<12
semillas) están leídas: **0 sospechas**. El criterio complementario se cumple: todo cambia con
`α` (Puntos 3 y 4) y el control valida el instrumento contra el vector de la implementación de
referencia.
