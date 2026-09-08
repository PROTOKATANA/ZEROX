# Solución al ataque de copias: el ancla vuelve a la cadena seleccionada

**Fecha:** 2026-09-08 · **Encargo de Katana:** «encuentra una solución» al hallazgo A3 de D9-b
(`dag-poas-ancla-de-orden-auditoria-2.md`): el orden total cuenta los rojos, R-FIN-1 lee de ese
orden, y un billete ya gastado compra posiciones de índice sin límite.
**Scripts:** `.../scratchpad/d9-ronda8b/sol_*.py`, reutilizan el simulador GD de D9-b con desempate
por `solution_distance` (`r8b_gd_sd.py`).

> **La solución es revertir el ancla a la de la ronda 7 —posición en la cadena seleccionada— y
> conservar todo lo demás de la ronda 8. El cambio de ancla que introduje en la ronda 8 fue un
> error mío, y el ataque de D9-b es su consecuencia directa.**

---

## 0 · La corrección que tengo que hacer primero

En la meta-auditoría (§9 y §10 bis) escribí: *«GHOSTDAG garantiza el orden total; no garantiza qué
bloque ocupa una posición dada de la cadena seleccionada»*. Y con eso justifiqué cambiar el ancla al
índice del orden. **Era una sobreafirmación.** El paper construye el orden **a lo largo de la
cadena seleccionada** (§2.4, líneas 290-300 del fichero local, literal):

> *«this greedy inheritance rule induces a chain… `Chn(G) = (genesis = Chn₀(G), Chn₁(G), …)`. The
> final order over all blocks, in GHOSTDAG, follows a similar path as the colouring procedure: We
> order the blockDAG by **first inheriting the order of Bmax on blocks in past(Bmax), then adding
> Bmax itself** to the order, and finally adding blocks outside past(Bmax)… Thus, essentially, **the
> order over blocks becomes robust as the colouring**.»*

Desenrollado: `ord(V) = [génesis] ‖ mergeset(C₁) ‖ C₁ ‖ mergeset(C₂) ‖ C₂ ‖ …` con `C₁, C₂, …` la
cadena seleccionada. **Si la cadena cambia a profundidad `d`, el orden cambia a profundidad ≤ `d`**
(emite bloques distintos). Contrapositivo: **orden estable a profundidad `d` ⇒ cadena estable a
profundidad `d`**. Luego **Prop. 7 sí cubre la cadena seleccionada**, como consecuencia, no como
enunciado. Lo que el paper declara no monótono es el *blue score del virtual* —la punta—, no el
prefijo profundo.

Con eso, la única razón para cambiar el ancla desaparece. Y el cambio trajo el ataque de D9-b.

---

## 1 · Verificación: el mismo ataque contra las dos anclas

Mismo ataque de D9-b (copias de billetes ya gastados publicadas en `T0`, DAG completo, honestos y
atacante a tasa `α`, U3′-filtro, `k=25`, `λ=1`, `Δ=4 s`), leyendo el ancla de las dos formas.

### 1.1 · A profundidad — donde se lee el ancla (`F = 3,2 h`)

`sol_profundidad.py`, `α = 0,25`, ancla creada a distintas distancias de `T0`:

| ancla creada en | menú CADENA | menú ORDEN |
|---|---:|---:|
| `T0+8` (frontera) | 14,3* | 40,7 |
| `T0−10` | **1,0** | **1,0** |
| `T0−30` | **1,0** | **1,0** |
| `T0−60` | **1,0** | **1,0** |
| `T0−120` | **1,0** | **1,0** |

Las copias se ordenan **donde las fusiona la cadena** —en `T0`— y no desplazan nada anterior. El
contraejemplo `r8b_a3_micro` de D9-b (índice 49 → 257) es el caso en que las copias se fusionan
**antes** del índice objetivo: el atacante elige **cuándo** las publica, y por tanto puede atacar el
índice del orden a la profundidad que quiera **si actúa antes de que se llene**. Eso es el frontera.

### 1.2 · En el frontera — donde se decide el *steering*

**El 14,3 de la cadena era un artefacto del simulador.** Instrumentado (`sol_instrumenta.py`, seed
11): lo único que cambia con `j` es la **etiqueta** del bloque honesto —`('h',293)`, `('h',294)`,
`('h',297)`…— porque es `('h', d.n)` y `d.n` es el contador de bloques, que las copias desplazan.
`bw[Z] = 290` constante, `Z` en cadena constante, **estructura idéntica**. Recontado por tiempo de
creación (`sol_menu_real.py`), invariante al renombrado:

| `α` | **menú CADENA real** | **menú ORDEN real** | (por etiqueta, con artefacto) |
|---:|---:|---:|---|
| 0,10 | **1,3** | **30,7** | cadena 27,7 · orden 31,0 |
| 0,25 | **2,0** | **41,0** | cadena 14,3 · orden 40,7 |
| 0,40 | **1,3** | **40,7** | cadena 10,7 · orden 39,3 |

**El ataque de copias es real contra el índice del orden (31-41) y no toca la cadena seleccionada
(1,3-2,0).** El residuo de ~2 en la cadena es `Z`, el bloque *genuino* del atacante, cayendo a veces
en `POS`: es la cuota `α` que `φ_c` ya tarifa.

Separado además de la elección de padres (`sol_variantes.py`, `α=0,25`): sin copias, `Z` solo con
puntas → **1,0**; sin copias, `Z` con `j` honestos antiguos como padres → **1,0**; con copias →
14,3 (artefacto). **Elegir padres no mueve la cadena.** Coincide con la fila «ronda 6» de la
propuesta.

Y descartado que sea el desempate: con `solution_distance` (fijo por billete) en vez de nombre, los
números no cambian (`sol_cadena_sd.py`).

### 1.3 · Por qué es inmune: cadena ⊆ azules, y las copias son rojas

Con U3′-filtro **cero copias son azules en ninguna vista** (`sol_mecanismo.py`: 0/20 en `V`, 0/20 en
cualquier vista posterior, 3 seeds). La cadena seleccionada es un subconjunto de los azules. **Una
copia no puede estar en la cadena, a ninguna profundidad.** No hay mecanismo por el que la desplace.

---

## 2 · La regla que vuelve, y las dos que se adoptan de Kaspa

**R-FIN-1 · Posición e inyector — LA DE LA RONDA 7.** `pos(B) = pos(sp(B)) + 1`. El inyector de la
época `j` visto desde `B` es `I_j(B) :=` el ancestro de la cadena seleccionada de `B` en la posición
`c·j`. Único por cadena, siempre existe, sin campo de cabecera, función de `past(B)`.

Se conservan **sin tocar**: R-FIN-1a (monotonicidad de slot), R-FIN-2..9, y **R-FIN-11** (U2 + U3′
como filtro, de D9-a; D9-b demostró que no tiene circularidad y que restituye «1 billete = 1 bloque»).

**Dos reglas de Kaspa que la propuesta no tenía y necesita**, verificadas en el clon:

- **`max_block_parents`** (`consensus/core/src/config/bps.rs:57-72`): `max(10, min(16, k/2))` →
  **12 a `k=25`**. Un bloque referencia como mucho 12 padres.
- **`mergeset_size_limit`** (`bps.rs:75-80`): `max(180, min(512, 2k))` → **180 a `k=25`**. Y
  `check_mergeset_size_limit` (`header_processor/post_pow_validation.rs:30-37`) devuelve
  `RuleError::MergeSetTooBig` — **el bloque es inválido**. `mergeset_size()` cuenta azules **y
  rojos** (`model/stores/ghostdag.rs:111-113`).

Juntas acotan la única vía que queda a las copias: **vivacidad**. Un portador que referencie 200
copias tiene mergeset 200 > 180 → **inválido** → las copias no se fusionan. Un honesto referencia
≤ 12 padres, cada copia con padres viejos añade ~1 al mergeset → ≤ 12 ≪ 180. Las copias entran a
goteo o quedan como puntas huérfanas. Es la defensa existente de Kaspa; ZEROX tiene que adoptarla
explícitamente.

---

## 3 · Lo que esto restaura y lo que cambia

| | Ronda 8 (orden) | **Solución (cadena)** |
|---|---|---|
| Ataque de copias (D9-b A3) | menú 31-41 | **menú 1,3-2,0** |
| Teorema del ancla | Prop. 7 directo | Prop. 7 **vía** construcción del orden (§0) |
| `c_a = c_h` (BDK Lema 13) | por rederivar | **restaurado**: la ronda 3 lo demostró para posiciones de cadena |
| `c` en unidades del ancla | 2 490 índices | **500 posiciones** (= `I·λ_chain`) |
| `I`, `F`, `k`, `q` | 2 490 s · 3,2 h · 25 · 1 | 2 490 s · 3,2 h · **30** · 1 (`k` corregido en `dag-poas-delta-real.md`) |
| Steering `g` con `m` medido | `m≈40` → 8,7 % | **`m≈1,3-2,0` → 1,0-2,4 %** |
| `W/κ` con `F = 3,2 h` | 1,22 | **1,22, sin cambio** |

El steering **mejora** respecto al 3,6 % que la ronda 7 asumía con `m=4`: el menú medido es menor.

---

## 4 · Lo que sigue sin demostrar

1. **Prop. 7 bajo U3′-filtro + R-FIN-5 + R-FIN-8: PLAUSIBLE, no DEMOSTRADO.** D9-b no lo rompió (cinco
   estrategias con billetes genuinos hasta `α=0,45`, peor caso `δ_ef = 0,0759` frente a la cota
   0,2424), pero su `0,000` es el suelo del instrumento.
2. **D9-b A1, laguna (a):** «la primera en el orden de GHOSTDAG» y «identidad ya azul en `past(sp)`»
   **dan DAGs distintos**. Hay que fijar U3′ en la segunda lectura, que es la implementable y la que
   D9-b demostró sin circularidad.
3. **D9-b A1, laguna (b):** U2 y el filtro exigen retrolectura sin cota, y chocan con la poda.
4. **D9-b A4:** la recursión por épocas entre R-FIN-5/R-FIN-7 y la Propiedad 1 —real, no viciosa, sin
   escribir.
5. **El empalme `φ_c` ⊗ `δ`** (conteo contra peso): **reducido a una restricción de diseño** —exacto
   salvo `ε < 1 %` con `W_RETARGET ≥ 3 083 slots`, `γ ≤ 0,25` (R-FIN-13; `dag-poas-empalme-peso.md`).
   Queda LAGUNA el sesgo del retarget bajo ataque (ronda 3, PLAUSIBLE).
6. **Cliente ligero sin confianza:** muerto, permanente. **Timelord único:** B7.

---

## 5 · Los errores míos de esta sesión, juntos

1. **La meta-auditoría sobreafirmó** que la cadena seleccionada no tiene teorema (§0 de aquí).
2. **El cambio de ancla de la ronda 8** salió de esa sobreafirmación y **abrió** el ataque de D9-b.
3. **Mi primera medida del frontera** (`sol_cadena_alpha.py`, «menú 14») era el artefacto de
   renombrado. Lo cacé instrumentando, no razonando.

Y uno que **no** es mío pero afecta a D9-b: sus menús de `r8b_a3.py` también cuentan por etiqueta y
llevan el mismo artefacto en la parte honesta. **No cambia su conclusión** —el contraejemplo
`r8b_a3_micro` es determinista y por estructura, y el menú real del orden sigue siendo 31-41—, pero
sus `g` de 6,8-12,9 % están algo inflados.

---

## 6 · Balance de las nueve rondas, en una línea

**El diseño que queda en pie es la ronda 7 + dos reglas de la ronda 1 (U2, U3′-filtro) + dos reglas
de Kaspa (`max_block_parents`, `mergeset_size_limit`), con las cuatro constantes derivadas en la
ronda 8.** Todo lo demás de la ronda 8 —la resolución de la ec. (2), `k=25`, `I`, `F`, `q=1`, la
pinza identificada— sobrevive. Lo único que muere es mi cambio de ancla.
