# Auditoría D9-f — Ronda 8f: ¿tiene `m` cota superior? — y el cuarto ancla, por `slot`

**Pregunta:** tras D9-e, `m` (el menú de inyectores del atacante) subía con cada familia de estrategias
(5,0 → 3,03 → 5,77) y yo escribí «`I`, `c`, `F` sin dimensionar». **¿Admite `m` una cota por argumento, o
hace falta un ancla con `m` acotado por construcción?** · **Fecha:** 2026-09-08, madrugada, modo autónomo
· **Agente:** D9-f en **Opus 5**, fresco · **Informe (756 líneas), 8 scripts, 15 salidas (commit
`0598413`, solo su directorio):** `research/scripts/d9-ronda8f/`.

> **VEREDICTO: `m` tiene cota superior — y la pregunta estaba mal planteada.** `c_m ≃ √(2 ln m)`, luego
> **`I ∝ 2 ln m` y `F ∝ ln m`**: «`m` sin cota» **nunca** implicó «constantes sin dimensionar»; incluso
> `m = 10⁴` da `F = 143 h`, no infinito. Lo que hay que declarar es **contra qué cota se dimensiona**.
> Y hay un ancla con cota **por construcción**: el **índice de PoT** (`slot`). Medido con la peor
> familia: **`F = 5,3 h` (slot) frente a 15,6 h (blue_score)**; garantizado sin estadística:
> **`m ≤ 1 + λ·S_max[s]` ⇒ `F ≤ 68,5 h`** con `S_max = 150 s`.

---

## 0 · Verificación independiente del agente principal

| Comprobación | Resultado |
|---|---|
| Commit `0598413` | **Solo su directorio** (25 ficheros, 0 fuera) |
| `AUDITA_SCRIPTS.py` (8 scripts) | **0 marcas** · criterio α en los 8 · **12 semillas en todo número** |
| **`F ∝ ln m`**, recalculado por mí (Blom) | `m=2,54` → 5,6 h · `5,77` → 15,5 h · `151` → **68,0 h** · `10⁴` → **143 h**. Coincide |
| **B3** `r8f_b3_prop7.py`, ejecutado por mí | **Reproduce:** Lema A4-slot en todas las filas (769/769, 455/455, 142/142, 85/85), incluidas las que violan la monotonía estricta |
| **B1** (`m_SLOT` vs `m_BS`, mismas semillas) | Re-ejecución completa **en curso** (`salida_b1_slot.rerun-principal.txt`) |
| Citas de Kaspa | **Reales:** `protocol.rs:153` (`blue_score = bs(sp) + |mergeset_blues|`), `:250` (tope `k+1`), y **su propia corrección**: `post_pow_validation.rs:85` recorre **solo `mergeset_reds`** |

---

## 1 · Parte A · La cota de `m` por argumento

- **Satura en `D`** (profundidad de `retro`): el nivel `D=64` ejecuta 307 estrategias nuevas y aporta **0**
  en 21 umbrales × 12 semillas × 4 α. **Mecanismo DEMOSTRADO:** `check_blue_candidate`
  (`protocol.rs:250`) tiñe de rojo el bloque cuyo anticono azul pasa de `k`, y «cadena ⊆ azules» ⇒ no
  puede ser ancla. Medido: `%en cadena` cae de 100 % a **0,3 %** en `d=2`.
- **Satura en `W`** (ventana de ataque): niveles 120 y 260 ejecutan 2 856 nuevas, aportan **0**.
- **NO satura en `C`** (copias): **la familia explícita que refuta la saturación — D9-f la da contra su
  propio resultado**: `m_BS = 1,881 + 0,491·log₂(C)`. ×17 copias mueven `F` de 12,5 h a 17,3 h. La
  cierran `mergeset_size_limit = 180` y U3″. **Con el ancla `slot`, a `α=0,40` incluso las copias
  saturan** (2,980 clavado, `aporta = 0,00` con 96 corridas nuevas).
- **Lema B1 (DEMOSTRADO):** `blue_score(ancla) − T ∈ [0, k]` (`protocol.rs:153` + `:250`), 0 violaciones.
  Ventana `2k/λ_azul ≈ 61 s`; anchura del menú medida **38,2 s máx**: factor 13 de holgura.
- **Cota determinista para `blue_score`** (Cota D, corregida por D9-f mismo): la finalidad — `m ≤ 815 617`,
  **`F ≈ 227 h`**. Es un punto fijo, y es 24× peor que la del `slot`.

## 2 · Parte B · El cuarto ancla — por `slot` (índice de PoT)

**Definición:** `I_j :=` el bloque de la cadena seleccionada con **menor `blue_work` entre los de
`slot ≥ T_j`**, con `T_j = j·I` un índice de PoT fijo (R-FIN-13: `slot` = índice de PoT, infalsificable).

**Cota E, POR CONSTRUCCIÓN (DEMOSTRADO el enunciado, PLAUSIBLE el conteo):** el ancla `A` cumple
`slot(sp(A)) < T_j ≤ slot(A)` y por R-FIN-1a `slot(A) − slot(sp(A)) ≤ S_max`, luego
**`slot(A) ∈ [T_j, T_j + S_max)`** sin ninguna hipótesis estadística. Como `slot` lo fija el PoT y `λ` el
retarget, el número de billetes en esa ventana es `λ·S_max[s]` en media:

```
m_SLOT ≤ 1 + λ·S_max[s]
```

| `S_max[s]` | cota de `m` | `F` garantizada | ¿cubre el gap medido (15,9 s)? |
|---:|---:|---:|---|
| 3 | 4 | 10,3 h | **no** (37 % de rozaduras) |
| 15 | 16 | 30,4 h | al límite |
| **20-30** | 21-31 | **35-41 h** | sí |
| **150** (D9-d) | 151 | **68,5 h** | sí, con holgura |

**Para `blue_score` no existe la análoga**: no es un reloj; el atacante fabrica bloques con
`blue_score ∈ [T, T+k]` en cualquier instante posterior. **Es una cota que el diseñador ajusta** moviendo
`S_max` — y con ello aparece la **pinza `S_max ↔ steering`** (§B4bis): `S_max[s] ≥ 20` por el gap medido,
`S_max[s] ≤ 30` si se quiere `F ≤ 41 h` de garantía; `S_max = 150` compra tolerancia a particiones a
costa de garantía (68,5 h).

**Medido, mismas 12 semillas y misma familia literal que D9-e:** **`m_SLOT = 2,54` donde `m_BS = 6,05`**;
con retención 3,64 ↔ 8,54. `ancla≠ = 67 %` (la comparación no es vacía). Robusta a la granularidad
(±1,1 %).

**Prop. 7 la cubre — DEMOSTRADO, con una hipótesis MENOS:** Lema A4-slot, **13 110/13 110**, incluidos
85/85 a `α=0,40` donde el 29 % de las aristas viola la monotonía estricta. **Corrección a D9-e:** su
Lema A4 **no necesita monotonía** — «el primer índice con la propiedad» lo fija el prefijo. La versión
correcta es más fuerte, y es la que permite el traslado al `slot`.

## 3 · B0 · Hallazgo no pedido, grave: «slot» tiene tres escalas incompatibles

R-FIN-7 escribe `F = 11 520 slots` para 3,2 h ⇒ en el diseño **1 slot = 1 s**. Con `λ = 1 bloque/s`,
**R-FIN-1a estricta (`slot(sp) < slot(B)`) invalidaría el 23,7-29,3 % de las aristas de la cadena
seleccionada bajo ataque** (12 semillas, 2 055 aristas a `α=0,40`):

| granularidad `τ` | `α=0` | `α=0,25` | `α=0,40` |
|---|---:|---:|---:|
| **1 s** (lectura literal) | 0,80 % | **23,67 %** | **29,34 %** |
| 0,1 s | 0,00 % | 3,28 % | 4,14 % |
| 0,02 s | 0,00 % | 0,95 % | 1,36 % |

Y con `τ = 0,02 s`, `S_max = 150 slots` son **3 s**: R-FIN-1a mordería la operación normal (gap medio ~2 s,
cola 15 s). **Punto viable medido: `τ ≈ 0,1 s`** (10 slots de PoT por intervalo de bloque), **R-FIN-1a
relajada a `slot(sp) ≤ slot(B)`** (el Lema A4-slot lo soporta), y **`S_max` en segundos**.
**LAGUNA:** la duración real de un slot de PoT de Autonomys no está en ninguna fuente local.

## 4 · Las constantes (peor `α = 0,10`)

```
ancla slot:        I = 4 200 s (1,17 h)   F = 5,3 h    c NO EXISTE (no hay contador)
ancla blue_score:  I = 3,42 h             F = 15,6 h   c = 11 960 azules
garantía (slot, S_max = 150 s):  m ≤ 151  ⇒  F ≤ 68,5 h
```

## 5 · Correcciones a rondas anteriores (aplicadas)

- **D9-e, Lema A4:** no necesita monotonía estricta de `blue_score`. — **D9-c, A4:** `merge_depth_bound`
  acota lo que un bloque **fusiona**, no de dónde **cuelga** (`post_pow_validation.rs:85`, bucle sobre
  `mergeset_reds`); lo que acota de dónde cuelga es la **finalidad** (`processor.rs:1033`). — **Yo:**
  «`I`, `c`, `F` sin dimensionar» era una sobreafirmación: `F ∝ ln m`.

## 6 · Errores declarados por D9-f (dos, ambos de método)

Su primer barrido `D` saturaba por **degeneración del simulador** (`retro n` se clava contra la longitud de
la cadena a `P=30`), no por el protocolo — habría firmado una saturación falsa; corregido con `P=120` y
marca `DEGEN`. Y su primera cota determinista usaba `merge_depth_bound`, que es falso (arriba); la cota
real es **peor** (227 h, no 126 h). También estuvo a punto de presentar `equiv≠ = 0` como evidencia cuando
es teorema del Lema A4b.

## 7 · Decisiones (autónomas, con el mandato de Katana)

1. **El ancla pasa a `slot`** (cuarta): gana en las cuatro dimensiones — `m` a la mitad, garantía 227 h →
   68,5 h, `c` desaparece, y con ella la palanca de `λ_chain`; Prop. 7 la cubre con una hipótesis menos.
2. **`τ ≈ 0,1 s`, R-FIN-1a no estricta, `S_max` en segundos**; la pinza `S_max ↔ steering` escrita.
3. **Constantes declaradas contra su cota:** `I = 4 200 s`, `F = 5,3 h` **medidos** (familia de D9-e);
   `F ≤ 68,5 h` **garantizado** (`S_max = 150 s`). Ya no hay `c`.
4. **Siguiente:** (a) obtener la duración real del slot de PoT de Autonomys (clonar `subspace`); (b) **D8
   adversarial** sobre el diseño completo — es la primera vez que hay reglas **y** constantes.

**Balance de la noche:** cuatro anclas —orden (cuenta rojos), posición (cuenta saltos), `blue_score`
(cuenta azules, sin reloj), `slot` (reloj infalsificable)— y la lección es una sola: **el inyector hay que
leerlo de una magnitud que el atacante no pueda fabricar a coste cero, y la única del DAG que cumple eso
es el índice del PoT.**
