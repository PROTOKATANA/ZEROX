# Audita-D8B — ataque adversarial a D14B (`informe2.md`) y D14C (`informe.md`)

**Ronda:** auditoría D8 de la 2.ª pasada de DAGKNIGHT (14B) y del inventario sin comité (14C).
**Fecha:** 2026-09-10. **Directorio propio:** `research/scripts/d14-sin-comite/audita-d8b/`.
**Rol:** D8 adversarial — el objetivo es tumbar, no confirmar. Nada se da por bueno sin atacarlo.
**Restricción de la ronda:** no modificar ficheros ajenos, no ejecutar git. Solo se creó este
directorio y este informe.

**Scripts y salidas propias** (reproducen todo lo que sigue):

| Script | Qué mide | Salida |
|---|---|---|
| `audita1_grupos.py` | rank por subgrupo, oráculo D8c, captura real (tip honesto en el pasado del ganador), 12 estrategias × α × Δ × 12 semillas | `salida1_grupos.txt`, `salida1_crudo.txt`, `log1.txt` |
| `audita2_ranks.py` | rank del grupo del **tip honesto** vs rank del ganador; victoria/captura/congelación | `salida2_ranks.txt`, `salida2_crudo.txt`, `log2.txt` |
| `audita3_reps.py` | representantes tips-only (S3 de D14B) vs Def. 4 completa (`dagknight.txt:589-594`) | `salida3_reps.txt` |
| `audita4_tiebreak.py` | tie-breaking con dos cadenas honestas de igual rank + atacante | consola |

Reutiliza sin modificar `d14k_lib.py`, `d14k_ref.py`, `r8c_sim.py`, `r8c_gd.py`. Los scripts de
D14B/D14C no se tocaron.

---

## 0 · Resumen para Katana

1. **Lo que cae:** el «hueco de selección» que D14B declara abierto está medido con un **oráculo
   inválido** (la fracción honesta del clúster ganador). Ese oráculo dispara en la red **sana**
   (`instant`) en 1-7/12 semillas y no distingue `instant` de `retraso20` a α=0,40 (ambos 7/12).
   D14B etiqueta como REFUTADO/LAGUNA algo que su instrumento no puede ver.
2. **Lo que sobrevive:** la conclusión central de D14B («el rank de la vista no se infla con la
   regla fiel») es cierta **como medida**, pero es una propiedad vacía: `k_view` es el mínimo
   sobre subgrupos, y el atacante puede tener el mínimo mientras la rama honesta tiene un rank
   alto o inexistente. El ataque no desaparece: **cambia de inflación a selección**.
3. **Lo que empeora:** combinando **retención + cadena privada** (`sp` con retraso, que D14B no
   probó) la captura sube a **8-12/12** semillas y el rank del tip honesto a 12-21 (o `None`),
   con el del atacante en 0. Es el ataque que el propio paper describe en `dagknight.txt:853-876`
   («aumentar el rank de los bloques honestos gastando hashrate»). Etiqueta: **SOSPECHA**
   (pasa por los proxies S1-S5 y la regla de cliente no publicada), no CONFIRMADO.
4. **El 4-17 s no es publicable** como latencia DAGKNIGHT: 14C cita los números de 14A
   (`informe.md:127-130`), ya reetiquetados por 14B como «adaptación propia»; el control positivo
   del paper sigue LAGUNA; `Δ` no está medido; y la fórmula usada (`max(3k_ref, m(α,ε))`) es
   independiente de `Δ`, justo lo contrario de la propiedad que el paper vende
   (`dagknight.txt:204-232`).
5. **CAP:** la cita es literal y exacta, pero el «sin comité» **no está en el teorema**. El
   teorema es *adaptativo + finalidad con UNA regla* (`lewispye-roughgarden-cap.txt:759`), y el
   propio paper de Sankagiri dice que las reglas duales **no caen bajo su alcance**
   (`cap-adaptividad-finalidad.txt:97-98`). 14C lo cita bien y lo glosa de más.
6. **Avalanche:** la exclusión práctica se sostiene, pero los motivos citados son débiles. El
   paper dice explícitamente que **cualquier** mecanismo Sybil vale (`avalanche-1906.08936.txt:271-272`)
   y el muestreo es un sondeo abierto, no un comité (`:318-319`). El bloqueo real es Sybil/peso,
   no «comité» ni los 2 000 AVAX (parámetro de despliegue).
7. **Mecanismo no cubierto por 14C:** **Parallel Chains** (Fitzi et al., ePrint 2018/1119),
   líderless, sin comité, con cadena de sincronización; ya está documentado en el proyecto
   (`research/dag-nativo-poas-propuesta.md:1108,1231,1258`) y no aparece en la tabla de 14C.
   No mejora la irreversibilidad (`d13-finalidad/f2-alternativas-latencia.md:256`), pero el
   inventario tiene un hueco.

---

## 1 · Punto 1 — «la regla fiel resiste manipulación»

### 1.1 · La conclusión «el atacante no infla k_ref» (D14B §Punto 4) — **sobrevive como medida, no como seguridad**

D14B mide `k_ref` = rank de la vista y concluye «el atacante no infla `k_ref`: suelo ≤55 s vs
baseline 100-150 s» (`informe2.md:181-184,197`). Reproducido: `k_view` se mantiene 0-2,6 de media
en estrategias de retención/parásita (`salida1_grupos.txt`), y solo sube con `parasita5`/`retro500`
a Δ=60 (hasta 35). **La medida es reproducible.**

**El ataque a la conclusión:** `k_view` es `min` sobre subgrupos (`d14k_ref.py:182-193`). Un
mínimo bajo no dice nada de la rama honesta. Lo que importa es `k` del subgrupo que contiene el
tip honesto (`k_hon_tip`) frente al del atacante (`k_att_tip`). Con la regla fiel:

| α, Δ, estrategia | k_hon_tip (media) | k_att_tip (media) | k_view | semillas con rank honesto `None` |
|---|---:|---:|---:|---:|
| 0,25 Δ=16 `retraso20` | 4,38 | 0,58 | 0,58 | 4/12 |
| 0,25 Δ=20 `retraso20` | 3,75 | 0,33 | 0,33 | 4/12 |
| 0,40 Δ=16 `retraso60` | 16,60 | 0,00 | 0,00 | 7/12 |
| 0,25 Δ=16 `retraso20_sp` | 3,17 | 4,00 | 2,67 | 0/12 |
| 0,40 Δ=20 `retraso20_sp` | 5,83 | 2,25 | 1,58 | 0/12 |

Fuente: `salida2_ranks.txt`. El atacante **no infla su propio rank** (0-5), y ese es el mérito real
de la regla fiel. Pero la rama honesta paga 3-21, o no tiene rank en 4-7/12 semillas. La
conclusión correcta no es «no hay ataque» sino «el ataque se movió de inflar `k` a **elegir el
subgrupo**», que es lo que D14B dice a continuación (`informe2.md:164-170`) pero mide mal.

**Etiqueta:** `k_view` VERIFICADO como medida; la lectura «la regla fiel resiste la manipulación»
**REFUTADA**; el hueco de selección, SOSPECHA (ver 1.2).

### 1.2 · El «hueco declarado» de D14B (retraso20/60, Δ≥16, α≥0,25) — **la evidencia es un oráculo inválido**

D14B/D8c concluyen: «no hay ningún ganador honesto en 0-3/12» y «el rank bajo no garantiza que
el ganador sea honesto» (`informe2.md:164-170,198`). Ese resultado se apoya en `hon_max` =
fracción honesta del clúster ganador (`d14k_d8c.py:60-67`) y en el criterio M3
(`d14k_d8b.py:101-116`).

**Ataque 1 — el oráculo falla en la red sana.** Con `instant` (sin estrategia de ataque), el mismo
oráculo da «sin ganador honesto» (`congel` = 1) en **1/12** semillas a α=0,10, **4/12** a α=0,25
y **7/12** a α=0,40 (`log2.txt`, filas `instant`). A α=0,40 Δ=16, `instant` y `retraso20` dan
**idéntico 7/12**: el oráculo no distingue ataque de red sana. La causa: en un DAG conectado de un
solo tip, el atacante público que ve todo al instante (`r8c_sim.py:89-90`) domina la frontera y
el clúster seleccionado, pero sus bloques están **en la misma cadena** que los honestos; no hay
contienda de subgrupos. Fracción honesta baja ≠ captura.

**Ataque 2 — no hay tips honestos.** En muchas semillas de `instant` y `retraso`, el único tip es
un bloque del atacante (`tips=1`, `Htip=bNone`, traza de `audita2_ranks.py`). El «tip honesto» no
existe; todos los honestos son ancestros del tip del atacante. `k_hon_tip=None` no es
congelación: es ausencia de candidato.

**Ataque 3 — S3 no está justificado en la dirección que se usa.** D14B usa como representantes
solo los tips (`d14k_lib.py:25-27`), mientras el paper usa
`reps_G(X) = {x ∈ past(X) \ past(tips(G)\X) : x agrees with X}` (`dagknight.txt:589-594`).
Implementé la Def. 4 completa (`audita3_reps.py`): en los casos medidos `k_tips == k_reps`
(ej. seed 23: 6 vs 6 con 2 vs 18 representantes; seed 41: 5 vs 5 con 3 vs 13), así que S3 no
explica por sí sola los `None`. Pero un `None` con un subconjunto de representantes **no prueba**
que el rank sea `None`: es un fallo de búsqueda, y D14B lo usa como prueba de «no hay ganador
honesto». Etiqueta: **SOSPECHA, no REFUTADO**.

**Ataque 4 — la captura real.** Defino captura como «el ganador de Alg. 4 es de creador atacante
Y el tip honesto no está en su pasado» (`audita1_grupos.py`). Resultado:

| Estrategia | `instant` | `retraso20` (tips) | `retraso20_sp` | `retraso60_sp` |
|---|---:|---:|---:|---:|
| captura máx. (de 12) | **0** | 8-9 | **12** | **12** |
| α, Δ donde ocurre | — | 0,25-0,40 / Δ≥16 | 0,40 / Δ=60 | 0,25-0,40 / Δ=60 |

Fuente: `log1.txt`, `salida1_grupos.txt`. La combinación **retención + cadena privada** (`sp` con
retraso, que D14B **no probó**: sus estrategias con retención usan política `tips`, que referencia
todas las puntas y por eso no crea una rama privada) es la que captura. El atacante construye
una cadena de un solo padre (`r8c_sim.py:93-94`) que los honestos no ven durante el retraso; los
bloques honestos que quedan fuera del pasado del ganador son exactamente los de la ventana de
retención. Es el mecanismo que el paper reconoce en `dagknight.txt:853-876`.

**El mecanismo de los grises, explícito.** En el subgrupo del atacante, los bloques honestos que
descienden de su NCA quedan **grises** (`umc_baseline`: no votan, `informe2.md:40-47`) y no
cuentan contra él; en el subgrupo honesto, los bloques privados del atacante son **rojos** y sí
cuentan. Con α≥0,25 y retención > Δ, el atacante acumula suficientes rojos para tumbar el UMC del
grupo honesto (`k_hon_tip` 12-21 o `None`) mientras el suyo pasa con `k=0`. Es exactamente el
ataque de `dagknight.txt:853-876` («minar bloques que acuerdan con los honestos pero no
pertenecen a su k-cluster»), y la regla fiel no lo neutraliza porque el rank de la vista toma el
mínimo de los dos subgrupos.

**Pero es SOSPECHA, no CONFIRMADO**, por tres razones que D14B declara y yo confirmo que importan:
(i) S1/S2 usan la cadena de GHOSTDAG, no la de Order-DAG (`d14k_lib.py:18-24`);
(ii) S3 (representantes = tips);
(iii) la regla de cliente no está publicada (`dagknight.txt:996-999`), así que «seleccionar el tip»
no equivale a «confirmar la transacción»: el riesgo real depende de la función `risk` local que
nadie conoce. Además el vsp se elige por `blue_work` (`d14k_ref.py:186`), no por el coloreado del
paper; el atacante omnisciente gana ahí por construcción.

### 1.3 · Tie-breaking con dos cadenas de igual score — **manipulable en el proxy, no certificado**

Test sintético (`audita4_tiebreak.py`): dos cadenas honestas A y B idénticas (rank 0 cada una) y
bloques del atacante colgando de A sin referenciar B.

```
n_atac=0  → grupos A k=0, B k=0      → Alg.4 (proxy) elige b3 (h)
n_atac=1  → A k=0, B k=1             → elige b7 (a)   ← 1 solo bloque del atacante
n_atac=2  → A k=0, B k=1             → elige b7 (a)
```

Un único bloque del atacante **rompe la simetría**: envenena la UMC de B (rojo que cuenta contra
el clúster honesto) y deja A en k=0. El ganador pasa de honesto a atacante sin ganar el rank, con
coste 1 bloque. Es el «rank inflation» de `dagknight.txt:853-876` aplicado a una partición, y
refuta la idea de que el tie-breaking solo importa «cuando existe ganador honesto»
(`informe2.md:179`). Con dos cadenas iguales, **no hay ganador honesto que elegir**: hay una
elección que el atacante decide.

**Límite:** mi Alg. 4 es un proxy (F = clúster libre del virtual, cadena por `KColouring.cluster`,
hash = id de creación, S4). La rama `rusty-kaspa@dagknight` sí trae `tie_breaking.rs`
(`informe2.md:23`), pero D14B **no lo portó**: usó el proxy de `d14k_d8c.py:66-98`
(`informe2.md:179,198`). Etiqueta: **SOSPECHA**.

### 1.4 · ¿Se puede forzar un k alto legítimo y congelar la confirmación? — **no demostrado**

Bajo `retraso20`/`retraso60` el rank del tip honesto llega a 12-21 (`salida2_ranks.txt`) y a
`None` en 4-7/12 semillas. Si `None` fuera real, la rama honesta **nunca** sería seleccionable por
la regla (congelación). Pero por 1.2 (tips honestos ausentes + S3 + regla de cliente no
publicada) **no se puede afirmar**. Lo que sí es seguro: el atacante puede mantener su rank en
0 mientras el honesto sube; eso es el ataque de la §2.6.6 del paper, no una congelación
demostrada. Etiqueta: **LAGUNA**.

### 1.5 · HALLAZGOS (formato D8)

```
HALLAZGO:     El "hueco de selección" de D14B se mide con un oráculo que dispara en la red sana
SEVERIDAD:    split (la conclusión puede llevar a adoptar o descartar DAGKNIGHT por una señal falsa)
ESTADO:       CONFIRMADO (el oráculo falla); SOSPECHA (el ataque real)
ESCENARIO:    α=0,40, Δ=16, estrategia instant (sin ataque): 7/12 semillas dan "sin ganador
              honesto" con el criterio de d14k_d8c.py:60-67; retraso20 da el mismo 7/12. El
              criterio no separa ataque de red sana.
UBICACIÓN:    research/scripts/d14-dagknight/d14k_d8c.py:60-67; informe2.md:164-170
PRECONDICIÓN: ninguna (es un fallo del instrumento)
MITIGACIÓN:   usar como oráculo el rank del grupo del tip honesto y la captura (tip honesto en
              el pasado del ganador), no la fracción honesta del clúster; y etiquetar S1-S5
              como límite de todo el resultado
```

```
HALLAZGO:     Retención + cadena privada captura la selección con 8-12/12 semillas
SEVERIDAD:    split / censura
ESTADO:       SOSPECHA (proxies S1-S5; regla de cliente no publicada)
ESCENARIO:    α=0,40, Δ=60, retraso20_sp (cadena de un solo padre, publicada con 20 s de retraso):
              12/12 semillas con ganador de creador atacante y tip honesto fuera de su pasado;
              k_att_tip=0, k_hon_tip hasta 21 o None. α=0,25 Δ=16: 8/12 en retraso20 (tips).
UBICACIÓN:    research/scripts/d14-sin-comite/audita-d8b/salida2_ranks.txt; salida1_grupos.txt
PRECONDICIÓN: α≥0,25 y retraso del atacante > Δ (20-60 s); el atacante ve todo al instante
              (r8c_sim.py:89-90, modelo del paper)
MITIGACIÓN:   implementar Alg. 2/3/4 completas con la regla de cliente publicada y re-medir;
              no adoptar DAGKNIGHT sobre la base de D14B
```

---

## 2 · Punto 2 — «¿El 4-17 s es publicable?»

**La conclusión atacada:** 14C presenta «DAGKNIGHT … 4-17 s media a ε=0,05; mínimo 0,36 s»
(`informe.md:50-53,90,133`) y lo usa para recomendar DAGKNIGHT (`informe.md:367-371`).

**Ataque 1 — el número es de 14A y 14B ya lo desautorizó.** 14C cita `d14-dagknight/informe.md`
(14A), no `informe2.md` (14B), en sus fuentes (`informe.md:430-431`). 14B dice literalmente que
«la latencia es **adaptación propia** (la regla de cliente del paper no está publicada; el control
positivo no cierra)» (`informe2.md:137-139`) y que los números «quedan etiquetados como
"adaptación propia sobre GHOSTDAG / rank fiel", **nunca** como latencia DAGKNIGHT demostrada»
(`informe2.md:13-16`). 14C ignora esa etiqueta y vuelve a vender 4-17 s como DAGKNIGHT.

**Ataque 2 — la fórmula no es la del paper.** La latencia de 14A/14B es
`M = max(3k_ref, m(α,ε))` con `m = ⌈ln ε / ln(α/(1−α))⌉` (`informe2.md:117-120`), una ruina del
jugador de la 1.ª pasada. La regla de cliente de DAGKNIGHT es local y no publicada
(`dagknight.txt:996-999`); su cota optimista es `O((ln(1/ε)+Dλ)/(1−2α)+(Dλ)²)`
(`dagknight.txt:1007`), que 14A midió en ZEROX como **2,5-40× peor** que lo que ellos mismos
reportan (`informe.md:135-139`). Es decir: el 4-17 s no es la regla del paper ni su cota.

**Ataque 3 — el número no responde a `Δ`, que es justo lo que el paper vende.** `m(α,ε)` no
depende de `Δ`; `k_ref` apenas cambia con `Δ` a α=0,33 (0,08-0,25 en `informe2.md:108-109`).
En cambio, la propiedad central de DAGKNIGHT es la **responsividad a la latencia real**
(`dagknight.txt:204-232`, fig. 4: si la red empeora, confirma más lento pero seguro). La
adaptación da prácticamente el mismo número con Δ=1 que con Δ=20, así que **subestima** la
latencia real cuando Δ crece. Con Δ=16-20 s en producción:
- el término `(Dλ)²` de la cota del paper da 256-400 s, peor que el baseline (100-150 s);
- el ataque de retención solo necesita un retraso > Δ (20-60 s): la ventana se abre justo en la
  peor condición de red (`salida1_grupos.txt`, `salida2_ranks.txt`);
- `Δ` real **no está medido** (E1 pendiente, `research/dag-poas-catalogo-problemas-ataques.md:72`).

**Ataque 4 — el control positivo sigue sin cerrar.** El propio D14B: «la tabla 1,2/6/12 s no es
reproducible» (`informe2.md:89-95`). Sin control, el número de ZEROX es un ajuste, no una
validación. 14C lo cita como si el control no existiera (`informe.md:90`).

**Veredicto:** **no publicable como latencia DAGKNIGHT**. Publicable, con su etiqueta completa,
como «adaptación propia en red sana, Δ≤20 no medido, regla de cliente LAGUNA, riesgo de selección
abierto». La afirmación de 14C «VERIFICADO en ZEROX sano» (`informe.md:90`) es exactamente la
etiqueta que 14B retiró.

---

## 3 · Punto 3 — «Sin comité ⇒ no hay finalidad determinista rápida»: ¿es el CAP tal cual?

**La conclusión atacada:** 14C §1.1 y §4: «no es una carencia de ingeniería: es un teorema.
Lewis-Pye y Roughgarden: "No protocol is both adaptive and has finality"»
(`informe.md:44-49,293-305`).

**Lo que el teorema dice de verdad.**
- «Adaptive» = vivo en el escenario *unsized* (participación variable): definición 3.2,
  `lewispye-roughgarden-cap.txt:727-728`.
- «Finality» = seguro en el escenario **parcialmente síncrono**: definición 3.4,
  `lewispye-roughgarden-cap.txt:740-741`.
- El teorema es sobre un protocolo con **una** regla de confirmación: el marco es
  `Π = (I, O, C)` (`cap-adaptividad-finalidad.txt:429-434`).
- La prueba usa dos usuarios honestos y **ningún otro** recurso (`:782-802`): la imposibilidad
  nace de confundir partición con caída de participación.

**El ataque:** el «sin comité» **no está en el teorema**. El teorema no menciona comités: dice
*adaptativo + finalista a la vez*, con una regla. Un protocolo **no adaptativo** sin comité puede
tener finalidad determinista — y 14C lo lista acto seguido: `C-REORG-07` (freno duro a 11 999
bloques, `SPEC.md:1797-1804`), que es finalidad determinista **sin comité**. Por tanto:
1. «Sin comité no existe finalidad determinista» es **falso** tal cual: existe (C-REORG-07).
2. «Sin comité no existe finalidad determinista **rápida**» es una lectura plausible, pero el
   motivo no es el CAP de L-P/R: es que toda regla de finalidad debe ser **no adaptativa** (se
   para con poca participación), y el teorema correcto para «sin conjunto conocido no hay acuerdo
   determinista» es el de DLS/PBFT (n>3f con conjunto fijo), **que 14C no cita**.
3. Sankagiri et al. demuestran que el compromiso se puede resolver **por usuario** con dos reglas,
   y dicen explícitamente que los diseños duales «do not fall under the purview of the CAP theorem
   of [16]» (`cap-adaptividad-finalidad.txt:97-98`). 14C lo menciona (`informe.md:302-305`) pero
   solo para descartar *esa* instancia (su C1 es Algorand BA), sin extraer la consecuencia: **el
   teorema no prohíbe una regla dual**, prohíbe una regla única que sea adaptativa y finalista.
   ZEROX ya es dual (k-deep probabilista + `C-REORG-07` determinista).

**Veredicto:** la conclusión práctica de 14C («la finalidad determinista rápida exige comité o
regla dura») sobrevive; la **atribución al teorema es una lectura forzada** y la frase «no existe»
es incorrecta sin el calificador «adaptativa». Etiqueta: **REFUTADA** la formulación literal;
**VERIFICADA** la conclusión operativa.

---

## 4 · Punto 4 — Mecanismos sin comité que faltan en la tabla de 14C

Revisión de la tabla (`informe.md:83-95`) y de los excluidos (`:278-289`). Mecanismos que no
aparecen:

| Mecanismo | Fuente | ¿Comité? | ¿Mejora irreversibilidad? | Por qué falta importa |
|---|---|---|---|---|
| **Parallel Chains** (Fitzi–Gaži–Kiayias–Russell, ePrint 2018/1119) | `research/dag-nativo-poas-propuesta.md:1108,1231,1258`; citado por el propio proyecto | No (PoW; la variante PoS usa stake) | No: confirmación por profundidad en cada cadena + estabilización en C1 (`:1231`) | Es el precedente líderless sin comité más directo para un DAG; 14C no lo menciona. `d13-finalidad/f2-alternativas-latencia.md:256` ya lo descartó como «throughput/orden, no finalidad» |
| **OHIE** (Fitzi et al.) | `research/dag-nativo-poas-propuesta.md:14,1239` | No | No | Misma familia; tampoco aparece |
| **Regla dual general** (Sankagiri et al.; Ebb-and-Flow de Neu et al., `cap-adaptividad-finalidad.txt:357-377`) | `cap-adaptividad-finalidad.txt:78-83` | La instancia sí (BA); la **forma** no | Permite elegir por usuario entre adaptividad y finalidad | 14C solo lo mete como «CAP dual rule» excluida (`informe.md:289`); no explora la forma sin comité ni reconoce que `C-REORG-07` ya es la regla dual de ZEROX |
| **«Everything is a Race and Nakamoto Always Wins»** (Dembo et al., arXiv:2005.10484) | no está en local; verificado en arXiv (2026-09-10) | No aplica (resultado negativo) | **Cierra** la búsqueda de «variantes de Nakamoto con confirmación mejorada»: prueba que el doble gasto privado es el peor ataque para Nakamoto PoW, PoS de Ouroboros/SnowWhite y **Chia Proof-of-Space** | 14C pide «variantes de Nakamoto con confirmación mejorada» y no cita el resultado que dice que, en ese modelo, la carrera de la cadena más larga es óptima. Es directamente relevante para PoAS (cubre Chia) |
| **Afgjort / GRANDPA / Gasper** (finality gadgets) | `cap-adaptividad-finalidad.txt:325-356,647` | Sí (validadores) | Sí, pero con conjunto registrado | No están en la tabla; su ausencia no cambia el veredicto, pero el inventario queda incompleto |

**«Colored».** Búsqueda web (2026-09-10): no existe un protocolo líderless de consenso llamado
«Colored»; lo más cercano es «Color Prism» (Color Platform), que es PBFT con comité, y los
*coloured Petri nets* (herramienta de modelado). La nota de 14C (`informe.md:392-394`) es correcta:
si la intención era el coloreado de GHOSTDAG, ya está cubierto como baseline.

**«GhostDAG con finalidad por peso».** Está cubierto implícitamente: GHOSTDAG **es** la finalidad
por peso (k-cluster + `blue_work`, `research/fuentes/phantom-ghostdag.txt:635-659`), y su
finalidad es probabilista por profundidad. No hay variante determinista sin comité en las fuentes
locales.

**Veredicto:** el hueco existe (Parallel Chains/OHIE + el resultado de optimalidad de Nakamoto),
pero **ninguno mejora la irreversibilidad**; la recomendación de 14C no cambia.

---

## 5 · Punto 5 — ¿Avalanche cae bajo la prohibición?

**La conclusión atacada:** 14C: «la muestra aleatoria de `k` nodos **es** el subconjunto que
decide … REFUTADO» y añade «el despliegue real exige 2 000 AVAX» (`informe.md:54-58,154-187`).

**Lo que dice el paper.**
- El protocolo muestrea de los nodos conocidos: `K := sample(N\u, k)`
  (`avalanche-1906.08936.txt:318-319`). Cada nodo actualiza **su propia** preferencia; no hay un
  voto vinculante de un subconjunto. Es un protocolo de gossip metastable, no un comité: el
  paper lo llama «leaderless BFT … via network subsampling» y tolera «discrepancies in knowledge
  of membership» (`:82-85,288-291`).
- Sybil es un módulo aparte: «The consensus protocols presented in this paper **can adopt any
  Sybil control mechanism**, although proof-of-stake is most aligned» (`:271-273`). El 2 000 AVAX
  es una decisión de **despliegue** de Avalanche, no del protocolo Snow.
- La seguridad es **probabilística ε**, no determinista (`:121-131`).
- El arranque asume «a safe bootstrapping mechanism … statistically unbiased view» y **no** PKI
  (`:288-294`).

**El ataque a 14C:** la lectura «muestra que decide ⇒ comité» es **forzada**. Si toda agregación
de opiniones de una muestra aleatoria es un comité, entonces también lo es GossipSub. La
exclusión correcta de Avalanche para ZEROX es otra: (a) **Sybil**: sin registro, las identidades
son gratis y el sondeo no está ponderado por espacio; (b) ponderar por espacio exige una fuente
de peso verificable, y la única disponible en PoAS es el propio DAG, que el atacante controla en
parte (sesgo de ancla, ya visto en rondas anteriores); (c) no hay análisis de Snow con peso de
espacio; (d) su finalidad es ε-probabilística, no determinista. Con esas premisas, «REFUTADO» se
sostiene; con la motivación «comité/2 000 AVAX», **no**.

**Respuesta a la pregunta directa:** sí se puede concebir un sondeo abierto sin comité fijo con
peso de espacio, pero (i) sería una muestra ponderada, que bajo la definición amplia de 14C es un
comité, y (ii) no tiene análisis de seguridad. Es una **decisión de alcance de la restricción**
(pregunta para Katana), no un resultado técnico.

---

## 6 · Supuestos ocultos (comunes a D14B, 14C y a mis propias medidas)

1. **El atacante ve todo al instante** (`r8c_sim.py:89-90`): gana el vsp por `blue_work` en
   cuanto hay varios tips. Parte de la «captura» de §1.4 nace de ahí, no del rank.
2. **`Δ` es una cota fija, no medida** (E1 pendiente). Todo el grid es Δ∈{1..60} sintético.
3. **La regla de cliente de DAGKNIGHT no está publicada** (`dagknight.txt:996-999`): ninguna
   latencia ni confirmación de transacción está simulada; se mide `k`.
4. **S1-S5**: cadena de GHOSTDAG en vez de Order-DAG, `rank_G=+inf` sin `free_search`,
   representantes = tips, hash = id, Order-DAG no ejecutado (`d14k_lib.py:18-29`). Todo el
   resultado de D14B —y el mío— hereda estos proxies.
5. **Oráculo de honestidad por creador**: el cliente real no distingue `creator="a"`; los
   criterios `hon_frac`/M3 son de análisis, no de protocolo.
6. **Bloques de peso 1, λ=1**: no hay trabajo variable ni retarget en la simulación.
7. **La «confianza» de 14C en la fila DAGKNIGHT es de 14A**, no de 14B: los dos informes de la
   misma fecha no se citan entre sí (`informe.md:430-431`).
8. **«Comité» en 14C incluye cualquier subconjunto muestreado que decida** (`informe.md:23-28`),
   lo que excluye Avalanche por definición. La restricción de Katana («sin comités de decisión»)
   no especifica si una muestra aleatoria ponderada cuenta; es una decisión abierta.
9. **El teorema CAP se usa como cota de latencia**: el teorema habla de seguridad bajo partición,
   no de segundos. 14C salta de «no hay finalidad determinista» a «no hay finalidad determinista
   rápida» sin fuente para «rápida».
10. **Δ y el ataque se acoplan**: el retraso del atacante solo necesita superar Δ. A mayor Δ
    (peor red), más fácil atacar. Los números «sanos» se miden precisamente donde el ataque es
    más barato.

---

## 7 · Ataques probados y descartados / no pude analizar

**Probados y descartados (no funcionan o no concluyen):**

- *Inflar el propio rank del atacante*: no sirve; el atacante que infla su rank pierde contra el
  honesto de rank menor. El objetivo correcto es bajar el suyo y subir el honesto (por eso
  `parasita5`/`retro500` suben `k_view` a 35 y aun así el ganador suele ser honesto,
  `salida1_grupos.txt`).
- *Tie-break con dos cadenas honestas iguales y ganador honesto presente*: no se pudo forzar el
  fallo del Alg. 4 proxy cuando el honesto existe (coincide con D8c 12/12 en parásita/retro).
  El fallo aparece cuando **no** hay ganador honesto (§1.3).
- *S3 (representantes = tips) como causa de los `None`*: descartado en los casos medidos
  (`k_tips == k_reps`, `audita3_reps.py`); los `None` vienen sobre todo de la ausencia de tips
  honestos y del criterio de subgrupo.
- *Avalanche como comité fijo*: descartado como lectura correcta del paper (`:318-319`,
  `:271-273`); la exclusión se sostiene por Sybil/peso, no por comité.
- *Dual-rule del paper CAP como vía sin comité*: descartado para finalidad **rápida**; su regla
  finalista es un BA y CP0 exige seguridad bajo partición (`cap-adaptividad-finalidad.txt:176-183,543-545`).

**No pude analizar:**

- La regla de cliente real de DAGKNIGHT: no está publicada; sin ella no hay confirmación que
  simular, solo ranks.
- Order-DAG (Alg. 2) completo y el Alg. 4 real: no implementados en el proyecto ni usados en mi
  auditoría; mis resultados de tie-break son proxies.
- El coste computacional del rank con λ=1 y Δ real en ZEROX: fuera de alcance.
- El análisis de Snow/Avalanche con peso de espacio: no existe en la literatura local.
- La verificación del stake de 2 000 AVAX: citado por 14C a `docs.avax.network`; no lo verifiqué
  de nuevo (es un dato de despliegue, no del paper).

---

## 8 · Reproducción

```
cd research/scripts/d14-sin-comite/audita-d8b
python3 audita1_grupos.py     # -> salida1_grupos.txt, salida1_crudo.txt
python3 audita2_ranks.py      # -> salida2_ranks.txt, salida2_crudo.txt
python3 audita3_reps.py       # -> salida3_reps.txt
python3 audita4_tiebreak.py   # -> consola
```

No se modificó ningún fichero fuera de `research/scripts/d14-sin-comite/audita-d8b/` ni de este
informe. No se ejecutó git.

## Fuentes citadas

- D14B: `research/scripts/d14-dagknight/informe2.md` · D14A: `.../informe.md` · D14C:
  `research/scripts/d14-sin-comite/informe.md`.
- Paper DAGKNIGHT: `research/fuentes/dagknight.txt` (Def. 4 `:589-594`; Alg. 4 `:680-703`;
  tie-break `:823-840`; rank inflation `:853-876`; regla de cliente y cota `:995-1007`;
  caso pesimista `:1021-1038`).
- CAP: `research/fuentes/lewispye-roughgarden-cap.txt:727,740,759,782-802`;
  `research/fuentes/cap-adaptividad-finalidad.txt:78-83,97-98,176-183,429-447,543-545`.
- Avalanche: `research/scripts/d14-sin-comite/fuentes/avalanche-1906.08936.txt:63-90,121-131,
  255-278,288-297,318-319`.
- Autonomys/Parallel Chains: `research/dag-nativo-poas-propuesta.md:14,1108,1231,1258`.
- Otros: `research/scripts/d13-finalidad/f2-alternativas-latencia.md:256`;
  `research/fuentes/phantom-ghostdag.txt:635-659`; `SPEC.md:1797-1804`.
- Externo verificado 2026-09-10: Dembo et al., arXiv:2005.10484 (abstract); búsqueda de
  «Colored consensus» (sin protocolo líderless con ese nombre).
