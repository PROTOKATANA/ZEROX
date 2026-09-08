# Auditoría D9 — Ronda 8, línea 1: ¿sobrevive Prop. 7 a U3′ + R-FIN-5 + R-FIN-8?

**Propuesta:** `dag-poas-ancla-de-orden.md` (commit `e2574d3`, con `q=1` en `ec6117d`)
**Fecha:** 2026-09-08 · **Agente:** D9 en **Opus 5** (política `NODOS/ZEROX/CLAUDE.md:217`, autorizada
por Katana) · **Alcance:** solo la línea 1 de §7, la que decide.
**Informe completo del agente:** `.../scratchpad/d9-ronda8/informe.md` (40 KB, volcado incremental).

**VEREDICTO: Prop. 7 NO sobrevive.** Por **dos vías independientes**. Cada una se cierra con **una
línea**, y las dos líneas ya estaban escritas en la ronda 1.

---

## 0 · Verificación independiente hecha por el agente principal

No transcribo veredictos sin comprobarlos — es la lección de la meta-auditoría de la ronda 7. Lo que
he ejecutado y leído yo:

| Comprobación | Resultado |
|---|---|
| **Criterio α** sobre el contraejemplo principal (`r8_lema9e.py`) | **PASA.** `δ_ef` = 0,000 / 0,106 / 0,250 / 0,366 / 0,424 para α = 0 / 0,10 / 0,25 / 0,33 / 0,40. El resultado **cambia con α** |
| `AUDITA_SCRIPTS.py` sobre `d9-ronda8/` | **0 marcas.** Las 11 restantes están en `/scratchpad/d8b` y `/OHIE`, de rondas anteriores |
| **El hecho de código decisivo**, leído por mí en el clon | **CONFIRMADO** (abajo) |
| Contraejemplo de U2 (`r8_u2.py`) | **CONFIRMADO.** Ejecutado: `¿B, que es la PUNTA de su propia cadena seleccionada, es azul? False` |

### El hecho de código, verificado en `rusty-kaspa` a mano

`consensus/src/processes/ghostdag/ordering.rs`:
```rust
impl Ord for SortableBlock {
    fn cmp(&self, other: &Self) -> Ordering {
        self.blue_work.cmp(&other.blue_work).then_with(|| self.hash.cmp(&other.hash))
    }
}
pub fn sort_blocks(...) -> Vec<Hash> { ...sorted_blocks.sort_by_cached_key(...SortableBlock...) }
```
`mergeset.rs`: `ordered_mergeset_without_selected_parent(...) = self.sort_blocks(...)`
`protocol.rs:140-142`:
```rust
let ordered_mergeset = self.ordered_mergeset_without_selected_parent(selected_parent, parents);
for blue_candidate in ordered_mergeset.iter().cloned() {
```

**El voraz k-cluster recorre el mergeset de MENOR a MAYOR `blue_work`.** Colorea lo barato primero.

---

## 1 · Vía A · El Lema 9 cae — U3′ como **posproceso**

**El mecanismo no es el que apuntaba la pista de la ronda 1** (el decremento de score). Es otro, y
es peor.

**La demostración del Lema 9 supone `1 billete = 1 bloque`** (`k+1 blocks`, línea 1135 del paper).
**U3′ como posproceso rompe ese acoplamiento**: un billete produce `m` copias válidas con **una sola
justificación de PoT**. Las copias entran en el voraz, y como son **baratas** (padres viejos, poco
`blue_work`) se colorean **primero** y **agotan el presupuesto de `k`**. Los bloques honestos
recientes, de más peso, se evalúan **después** y quedan fuera. Solo *entonces* U3′ las degrada — y
ya han hecho el daño.

**Medido** (`r8_lema9e.py`, un billete = una identidad estricto):

| α | 0,00 | 0,10 | **0,25** | **0,33** | **0,40** |
|---|---:|---:|---:|---:|---:|
| `δ_ef` con U3′ **posproceso** | 0,000 | 0,106 | **0,250** | **0,366** | **0,424** |
| `δ_ef` con U3′ **filtro** | 0,000 | 0,000 | **0,000** | **0,000** | **0,000** |
| `δ_ef` GHOSTDAG puro | 0,000 | 0,000 | 0,000 | 0,000 | 0,000 |

Cota del paper con `k=25`: **`δ = 0,2424`**. A α = 0,33 y 0,40 la medición la **supera**.
Multiplicador de copias medido: **4 599 bloques con 171 billetes = 27×**.

**Etiqueta: REFUTADO** (contraejemplo constructivo, ejecutable, α-dependiente).

---

## 2 · Vía B · Falta **U2** — hallazgo extra, no pedido

La octava propuesta enuncia U3′ pero **no U2**. Sin ella se rompe «cadena seleccionada ⊆ azules» —
la misma refutación que la ronda 1 hizo contra U3, resucitada contra U3′.

Contraejemplo de **7 bloques**, ejecutado (`r8_u2.py`):

```
slot(sp(B)) = 4 < slot(B) = 5        -> R-FIN-1a: CUMPLIDA
ident(X) = ident(B) = ('T', 5)       -> misma identidad, X en past(B)
orden total: [G, C1, C2, C3, A, X, B]
BlueSet' tras U3' (primera copia de cada identidad): [A, C1, C2, C3, G, X]

¿B, que es la PUNTA de su propia cadena seleccionada, es azul?  False
```

**El bloque fusionador queda rojo en su propio coloreado.** R-FIN-1a **no** lo repara: solo mira el
slot del padre seleccionado, no las identidades del pasado.

**Etiqueta: REFUTADO.**

---

## 3 · Lema 10 · El `3k` **no** es lo que se rompe

D9 demostró que la cota de conteo del Lema 12 **sobrevive** a U3′ (`score′ ≤ score`, argumento
conjuntista), y midió que es **holgadísima**: máximo real **26 ≈ k**, frente a `3k = 75`.

Lo que falla es la **hipótesis de deriva**: la base de la cota es `α/((1−α)(1−δ))`, y con el `δ_ef`
medido **cruza 1 en α ≈ 0,375** — por debajo del **40,7 %** que la propuesta publica. Son ~3 puntos,
no un derrumbe, pero **la cifra publicada deja de estar cubierta**.

**Etiqueta: DEMOSTRADO** (que el `3k` aguanta) **+ REFUTADO** (que el umbral publicado esté cubierto).

---

## 4 · El índice · Mixto, y con una circularidad

**(a)** La implicación *Def. 2 ⇒ índice estable* es **correcta**, y más fuerte de lo que la
propuesta creía: el `∃C` está **dentro** de la probabilidad. Pero le falta la dirección inversa: una
cota de la unión que multiplica la constante por `1/(1−e^{−c/λ})`, **divergente** cuando el margen se
estrecha. **LAGUNA sin acotar.**

**(b)** Bajo U3′-posproceso el índice se queda sin teorema (consecuencia de §1).

**(c) R-FIN-5 + R-FIN-7 rompen la Propiedad 1 de frente.** Def. 2 dice *«If `B ∉ G^u_t` … `Risk_u =
1`»* y `Risk` es el **máximo sobre honestos**: un desacuerdo de flujo da **`Risk = 1` permanente**. Y
la probabilidad de ese desacuerdo solo la acota Prop. 7 — **circularidad**.

---

## 5 · El arreglo: dos líneas, las dos ya escritas en la ronda 1

1. **U3′ como filtro de candidatura**, no posproceso: rojo **antes** del k-cluster. Es lo que la
   ronda 1 escribió en su línea 376 y la ronda 8 reescribió mal.
2. **Reponer U2**: *«X, B con la misma identidad y X ∈ past(B) ⇒ B INVÁLIDO»*. **No puede ser un
   filtro de retransmisión**: divergiría el coloreado entre nodos. Es consenso.

Medido: con U3′-filtro, `δ_ef = 0,000` en **todas** las α probadas (0 a 0,40).

---

## 6 · La contrapartida, que el propio D9 declara

> **«No demostré que el protocolo falle.** Mi carrera de bloques con presupuesto repartido no
> consiguió que el atacante superara al crecimiento honesto a α ≤ 0,40. **Cae el teorema, no la
> demo.»**

Es la distinción correcta y hay que respetarla: **se pierde la garantía**, no está probado que se
pierda la cadena.

---

## 7 · Errores propios que D9 declaró y corrigió

Los anoto porque es exactamente lo que la ronda 7 no hizo:

- Su `total_order` ponía el bloque **antes** de su mergeset; Kaspa lo pone **después**
  (`ghostdag.rs:175-180`, test en `:558`). Corregido — y **solo entonces** apareció el contraejemplo
  de U2.
- Su primer portador daba al atacante **dos identidades por billete**. Corregido: `δ_ef` bajó de
  0,289 a 0,250 en α=0,25. Las tablas usan las corregidas.
- **Retiró entera** la tabla de `r8_indice.py`: daba 0,000 en las 16 filas, con α=0 y α=0,40 por
  igual — **tautología**. El guion lleva un aviso en cabecera.

---

## 8 · Estado de la ronda 8

| | |
|---|---|
| Línea 1 de §7 | **REFUTADA**, por dos vías |
| ¿Cae la propuesta? | **No**: las dos vías se cierran con dos líneas ya conocidas |
| ¿Cae la demo? | **No**: D9 no consiguió romper la cadena a α ≤ 0,40 |
| ¿Cae el umbral publicado? | **Sí**: 40,7 % no está cubierto; la deriva cruza en α ≈ 0,375 |
| Siguiente | Aplicar las dos líneas y **re-auditar la línea 1**; luego 2 a 7 |
| Nuevo abierto | La laguna de la cota de unión en el índice (§4a) y la circularidad (§4c) |

**Scripts:** `r8_lib.py`, `r8_lema9e.py` (principal), `r8_u2.py`, `r8_lema9{,b,c,d}.py`,
`r8_peso.py`, `r8_freeload.py`, `r8_umbral.py`, `r8_indice.py` (retirado, con aviso), todos en
`.../scratchpad/d9-ronda8/`. `AUDITA_SCRIPTS.py`: **0 marcas** sobre ese directorio.
