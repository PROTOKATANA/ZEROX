# Auditoría D9-b — Ronda 8, segunda pasada: ¿aguanta R-FIN-11?

**Propuesta:** `dag-poas-ancla-de-orden.md` con R-FIN-11 (commit `639007e`)
**Fecha:** 2026-09-08 · **Agente:** D9-b en **Opus 5**, **fresco y distinto de D9-a** — el arreglo lo
propuso D9-a, y un auditor no debe auditar su propio parche.
**Informe del agente:** `.../scratchpad/d9-ronda8b/informe.md` (38 KB, 13 secciones).

> **VEREDICTO: R-FIN-11 no aguanta. Arregla el Lema 9 y, con la misma regla, rompe R-FIN-1.**

---

## 0 · Verificación independiente del agente principal

| Comprobación | Resultado |
|---|---|
| **El hecho de código decisivo**, leído por mí en el clon | **CONFIRMADO** (abajo) |
| Contraejemplo `r8b_a3_micro.py` (determinista) | **Ejecutado por mí.** Reproduce |
| **Criterio α** sobre `r8b_a3.py` | **PASA.** Menú = 1,0 / 29,7 / 40,0 / 40,0 / 38,0 a α = 0 / 0,10 / 0,25 / 0,33 / 0,40 |
| `AUDITA_SCRIPTS.py` sobre `d9-ronda8b/` | **0 marcas.** Las 11 restantes son de `/scratchpad/d8b`, ajenas |

### El hecho de código, verificado a mano en `rusty-kaspa`

`consensus/src/model/stores/ghostdag.rs:115-135`:
```rust
/// Returns an iterator to the mergeset in ascending blue work order (tie-breaking by hash)
pub fn ascending_mergeset_without_selected_parent<'a>(...) -> impl Iterator<Item = SortableBlock> {
    self.mergeset_blues.iter().skip(1)...
        .merge_join_by(
            self.mergeset_reds.iter()...,     // ← LOS ROJOS ENTRAN EN EL ORDEN
            |a, b| a.cmp(b),
        )
```
y `mergeset_size() = mergeset_blues.len() + mergeset_reds.len()`.

**El orden total consensuado de GHOSTDAG cuenta los rojos.** No es un detalle de implementación: es
la función que produce el orden del que R-FIN-1 lee el inyector.

---

## 1 · A3 · La refutación — el filtro deja las copias **rojas pero vivas**

R-FIN-11 marca las copias rojas **antes** del voraz. Eso les quita el peso (arregla el Lema 9) pero
**no las saca del DAG**, y por tanto **no las saca del orden**. R-FIN-1 lee el índice `c·j` de ese
orden. **Un billete ya gastado compra posiciones de índice sin límite.**

`r8b_a3_micro.py`, determinista, ejecutado:

| plan de copias | \|orden\| | rojas | azules | `score(V)` | identidad en idx 49 |
|---|---:|---:|---:|---:|---|
| `[]` | 56 | 0 | 0 | 56 | `('h','p2')` |
| `['T1']` | 58 | 1 | **0** | **57** | `('h','p0')` |
| `['T1','T2']` | 59 | 2 | **0** | **57** | `('a','Zfresco')` |
| `['T1','T2','T3']` | 60 | 3 | **0** | **57** | `('a','T3')` |
| `['T1'] × 200` | **257** | 200 | **0** | **57** | `('a','T1')` |

**Las 200 copias son rojas y `score(V)` no se mueve** —el filtro cumple exactamente lo que promete
para el Lema 9— **y aun así el índice se desplaza de 56 a 257.** Con 0-3 copias el atacante dispone
de un **menú de 8 bloques** para el índice objetivo, y con él elige la entropía de R-FIN-2.

**Etiqueta: REFUTADO.**

### Qué falsifica, en concreto

**Falsifica §5.4 de la propuesta** («desplazamiento de índice por rojos, acotado por `α·λ`») — que era
justamente lo que yo había marcado como «lo primero que hay que atacar». No está acotado por `α·λ`:
está acotado por **cuántas copias quiera publicar el atacante de un billete que ya gastó**.

**Y desderiva `I = 2 490 s`.** Medido con DAG completo (`r8b_a3.py`, solo con `j ≤ 40` copias en **un
único instante**, o sea cota inferior):

| α | menú de entropías | `g` con `I=2 490 s` | `I` para `g = 3,6 %` |
|---:|---:|---:|---:|
| 0,00 | 1,0 | 0,00 % | — |
| 0,10 | 29,7 | **12,90 %** | 31 975 s |
| 0,25 | 40,0 | **8,64 %** | 14 351 s |
| 0,33 | 40,0 | **7,52 %** | 10 872 s |
| 0,40 | 38,0 | **6,77 %** | 8 801 s |

La propuesta asumía `m = 4` candidatos y `g = 3,6 %`.

### Y con eso, el punto de diseño se cae

| α | `I` necesaria | `W/κ` con `F = 3,2 h` | `F` para `W/κ = 1,22` |
|---:|---:|---:|---:|
| 0,10 | 31 975 s | 3,78 | **40,4 h** |
| 0,25 | 14 351 s | 2,25 | **18,1 h** |
| 0,40 | 8 801 s | 1,76 | **11,1 h** |

**Haría falta `F` de 11 a 40 horas.** La cadena lineal confirma en 3,3 h.

---

## 2 · La contradicción es estructural, no un fallo de redacción

| Para arreglar… | Hace falta… | Y eso… |
|---|---|---|
| **El Lema 9** | que las copias **no pesen** → rojas | ✅ resuelto por R-FIN-11 |
| **R-FIN-1** | que las copias **no cuenten en el índice** → ausentes | ❌ rojo ≠ ausente |

Las dos exigencias tiran en sentidos opuestos sobre la misma regla. **No es que R-FIN-11 esté mal
escrita: es que «rojo» no es lo bastante fuerte para lo que R-FIN-1 necesita.**

---

## 3 · A1 · No hay circularidad — buena noticia, con dos lagunas

**DEMOSTRADO que U3′-filtro está bien definido.** Verificado en código: `sort_blocks` ordena por
`get_blue_work(*block)` **leído del store** de cada candidato (`ordering.rs:45-50`), antes del voraz
(`mergeset.rs:44` → `protocol.rs:140-142`). El orden del mergeset lo fija dato ya asentado, no el
coloreado en curso. Localidad `f(past(B))`: **3 000 reconstrucciones, 0 fallos**.

**Dos LAGUNAS que deja abiertas:**
- **(a)** El texto «la primera en el orden de GHOSTDAG» y la única lectura implementable
  («identidad ya azul») **dan DAGs distintos** — contraejemplo ejecutable, que además **refuta el
  “invariante DEMOSTRADO” de D9-a §5.4**.
- **(b)** El filtro y U2 exigen **retrolectura sin cota**, y chocan con la poda.

---

## 4 · A2 · El filtro sí arregla el Lema 9 — con un aviso sobre el instrumento

**PLAUSIBLE.** D9-b **reproduce el `δ_ef = 0,000`** de D9-a con **dos motores GHOSTDAG
independientes**, 40 filas idénticas. El filtro restituye «1 billete = 1 bloque»: **3 120/3 120
bloques con ≤1 azul por identidad**.

**Pero avisa de algo importante:** ese `0,000` es **el suelo del instrumento** — sale igual sin
ataque y con α=0. Probó cinco estrategias con billetes genuinos hasta α=0,45: **peor caso 0,0759
frente a la cota 0,2424**. No lo rompió, pero tampoco lo demostró.

---

## 5 · A4 y A5 · Los dos abiertos de D9-a, revisados

**A4 · El vehículo de D9-a era INVÁLIDO.** Su lectura de «`B ∉ G^u_t` ⇒ `Risk=1`» **prueba
demasiado**: mataría la Propiedad 1 en GHOSTDAG puro por simple retardo. Y el paper **declara ese
hueco él mismo** (líneas 564-572: *«We leave the task of bridging this gap to a later version»*). La
circularidad de fondo es **real pero no viciosa** — es una recursión por épocas que nadie ha escrito.
**LAGUNA.**

**A5 · La suma de D9-a SOBRA.** El orden es topológico y `past(B)` inmutable, luego
`idx(B) = |past(B)| + #{C ∈ anticono(B) : C ≺ B}` (identidad exacta en el 100 % de bloques, 7
corridas). La unión corre sobre el **anticono**, no sobre el pasado: **sin divergencia**. Pero el
anticono **tampoco está acotado** bajo R-FIN-11: media de **5,98 → 183,00** con 200 copias.

> **A3 y A5 son la misma herida.**

---

## 6 · Errores propios que D9-b declaró

Seis, en su §12. Los dos que importan:
- Su primer ataque era **más débil que el de D9-a** (0,0875 frente a 0,250) por dar visibilidad
  instantánea al atacante. **Reconoce que la medición de D9-a es la buena.**
- Su parche del guardián de importación **rompió `r8b_a2_invar.py` en silencio**; lo detectó
  revisando el registro, no la última línea.

---

## 7 · Estado y camino

| | |
|---|---|
| Línea 1 corregida | **REFUTADA otra vez**, por otra vía |
| ¿Es un fallo de redacción? | **No.** Es estructural: «rojo» ≠ «ausente del orden» |
| ¿Cae la demo? | No demostrado. A2 no rompió el Lema 9 con billetes genuinos |
| Lo que cae | `§5.4`, `I = 2 490 s`, y con ello `F = 3,2 h` y `W/κ = 1,22` |
| Lo que se salva | **No hay circularidad** en U3′-filtro (A1) · el filtro sí restituye 1 billete = 1 bloque (A2) |

**La dirección que D9-b señala para una novena ronda:** anclar en **una magnitud que el filtro
proteja** —el recuento de **identidades azules**— en vez del índice del orden total, que cuenta
rojos.

**El problema de esa dirección, y hay que decirlo:** el teorema (Def. 2 + Prop. 7) es sobre **el
orden**. El recuento de azules es *blue score*, y es exactamente lo que el paper declara **no
monótono** (*«In GHOSTDAG this no longer holds… the blue score of the virtual node actually
decreases»*). Es decir: **se vuelve a la pinza de siempre** —el objeto con teorema es grindable, el
objeto protegido no tiene teorema— solo que ahora se sabe **por qué**, con contraejemplo ejecutable.

Reabre, según el propio D9-b: **§0, §1.2, §1.3, §1.4 y R-FIN-10**. Las alternativas que evaluó
(ventana de slot, `mergeset_size_limit`) **acotan pero no cierran**, y la segunda abre una vía de
vivacidad.
