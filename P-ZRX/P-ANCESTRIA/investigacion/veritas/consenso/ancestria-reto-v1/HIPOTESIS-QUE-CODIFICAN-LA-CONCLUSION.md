# HIPÓTESIS QUE CODIFICAN LA CONCLUSIÓN — ANR-v0.1

Este fichero existe para que la conclusión no se lea como más fuerte de lo que es. Cada hipótesis
lleva **dónde se usa**, **qué pasaría si es falsa** y **su etiqueta**. Nada de aquí es un parámetro
de consenso: `d`, `c`, `I_slots`, `L_slots`, `F_slots`, `k`, `P`, `λ` son entradas.

---

## H1 · El anclaje a profundidad `d` es una c-correlación de BDK+19 con `c = d + 1`

**Enunciado.** Sea `σ(B)` el ancestro de `B` en su cadena seleccionada a `depth(B) − c` niveles, con
`c = d + 1` (para `d = 0`, `σ(B) = sp(B)`). Si el reto de `B` se deriva de `σ(B)` (y del slot), la
aleatoriedad que gobierna `B` queda determinada por un bloque de la *ventana anterior* de `c` niveles,
y el árbol privado del atacante —visto en generaciones de `c` niveles— es el árbol `T'` del Anexo F
de BDK+19 con parámetro `c`.

**Dónde se usa.** Es lo que convierte `φ_c` en `umbral(d) = 1/(1 + φ_{d+1})` (F2) y lo que fija la
ventana de reutilización en `c = d + 1` bloques (F3, F4).

**Qué sostiene H1 y qué no.**
- *Demostrado en este instrumento*: el **lema de ventana** (`ventana_exhaustiva`, `--oraculos`):
  dos ramas con ancestro común a profundidad `m` comparten `σ` en un bloque de profundidad `n` si y
  sólo si `n − c ≤ m`. De ahí la ventana de `c` bloques.
- *Verificado en fuente*: `c` en BDK+19 es «el número de niveles del árbol privado entre
  actualizaciones de la aleatoriedad» (`research/fuentes/bdk19.txt`, §4 y Anexo F: `RandSource(b)`
  sólo cambia si `depth(b) % c == 0`; Lemma 13: la estrategia óptima es bifurcar en los padres de los
  bloques *godfather*). Esa es la magnitud que H1 identifica con `d + 1`.
- **Lo que H1 NO afirma**: que la regla *literal* de diseño —reto dependiente del ancla **y** del
  slot, `C-POT-03`— sea idéntica a la c-correlación. En BDK la aleatoriedad es **constante** dentro de
  la ventana; con ancla a profundidad `d` **varía** con el slot dentro de la ventana. La regla literal
  da aleatoriedad fresca **adicional**, y por tanto **más** poder al atacante que `c = d + 1`.
  **Dirección del error declarada: si H1 falla, `umbral(d)` es una COTA SUPERIOR de la seguridad
  real, no un valor exacto.** Ninguna cifra de este informe se presenta como exacta bajo la regla
  literal.

**Etiqueta**: *derivado* (con el lema de ventana *demostrado* y la equivalencia *no determinada*).

---

## H2 · El reto depende del ancla y del slot, no del contenido libre del candidato

**Enunciado.** `reto(B, s) = H(aleatoriedad(σ(B), s) ‖ LE64(s))`, y `σ(B)` es función exclusiva de
`past(B)`.

**Por qué importa.** Es lo que deja la propuesta del **lado de la validez absoluta** (§1.4 del
encargo): `σ(B)` no depende de la cadena del observador, sólo de `past(B)`, igual que `C-GD-09` exige
de los datos GHOSTDAG. Si el ancla dependiera de la punta local o del orden de llegada, caería del
lado relativo y reabriría el multistream.

**Etiqueta**: *derivado* (`C-GD-09` + `C-FLU-13` verificados en fuente).

---

## H3 · `R*` (el recurso honesto por ancestría) es positivo y la identidad es gratis

**Enunciado.** P4 se enuncia contra un coste honesto `R* > 0` por ancestría; en PoST el coste es
`espacio × tiempo` (no hay búsqueda de nonce), y crear una identidad nueva cuesta lo mismo por byte
que no crearla.

**Dónde se usa.** En F1 (contraejemplo «cara transferible + barata ligada») y en el contraste con el
teorema de §1.1 del encargo (`research/dag-poas-balizas-auditoria.md:30-38,66-78`).

**Etiqueta**: *verificado en fuente* (el teorema de §1.1) + *derivado* (la forma de `R*`).

---

## H4 · El modelo de grinding es el del Anexo F, no uno propio

**Enunciado.** `φ_c λ_a` es la tasa de crecimiento del árbol privado y `β_c = e^{−λ_h Δ}/(e^{−λ_h Δ} + φ_c)`
el umbral. Se publican las cifras con `Δ = 0` (⇒ `1/(1+φ_c)`) porque `Δ` y `λ_h` son **símbolos**
en el SPEC (`C-POT-01`, §7.3); `umbral_c_retardo` existe en el instrumento para cuando se fijen.

**Qué lo sostiene.**
- *Demostrado*: `φ₁ = e` exacto (`phi_1_simbolico`: `θ* = −e`, `φ₁ = e`), y `umbral(0) = 1/(1+e) =
  26,8941 %` — **el control obligatorio del encargo**.
- *Verificado contra fuente externa*: la Tabla 3 del paper (c = 1..10) se reproduce con discrepancia
  máxima `8,5·10⁻⁶`, y los valores citados en el repositorio (`φ₁₆ = 1,4678`, `φ₅₀ = 1,2815`,
  `φ₁₀₀ = 1,2074`, `φ₂₅₀ = 1,1387`, `φ₅₀₀ = 1,1023`, `φ₁₀₀₀ = 1,0754`, `φ₂₀₀₀ = 1,0556`) con
  discrepancia máxima `4,7·10⁻⁵` (redondeo a 4 cifras).
- *Independiente*: O1 obtiene lo mismo maximizando `Λ_c(t)/t` por sección áurea (ruta distinta de la
  bisección de (39)); coincidencia impresa `0,00·10⁰`.
- *Exacto*: O2 certifica con `Rational{BigInt}` la identidad geométrica y con `BigFloat` que
  `Λ_c(t) = log(Σ_{j≥c} (1/(1−t))^j)`.

**Etiqueta**: *demostrado* (c=1 y control) / *verificado en fuente* (resto).

---

## H5 · La conclusión sobre F4 depende de `I_slots` y `L_slots`, que son símbolos

**Enunciado.** La ventana de reutilización del flujo de hoy es
`t_{j*} − s_x ∈ (0, I_slots + L_slots]` slots, con `j* = min{ j : T_j + L_slots > s_x }`. No se fija
ningún valor: se demuestra la **cota** y se deja la magnitud como función.

**Dónde se usa.** Es la respuesta a F5 y el motivo por el que F4 no es «no puede existir ningún `d`»
sino «no existe un `d` **distinto del que ya está implementado**».

**Qué pasaría si es falsa.** Si la ventana fuese no acotada (por ejemplo si `V_j` no cortara donde
`C-FLU-03` dice, o si `C-FLU-21` no heredara la inyección activada), entonces el diseño de hoy sí
sería `d = ∞` y el encargo tendría razón en su dicotomía. La comprobación es de lectura de reglas
(`C-FLU-03`, `C-FLU-04`, `C-FLU-10`, `C-FLU-12`, `C-FLU-21`), no de simulación.

**Etiqueta**: *derivado de reglas vigentes* (no medido en red).

---

## H6 · El ancla a profundidad `d` no necesita campo nuevo en la cabecera

**Enunciado.** `σ(B)` se deriva de `past(B)`, así que §6.1 no se reabre por el ancla en sí.

**Dónde se usa.** F6 (coste en reglas). **Discrepa** de
`veritas/consenso/poda-post-v1/INFORME.md:144-147`, que anticipa reabrir §6.1 para «un reto ligado a
la ancestría (p. ej. que el desafío dependa del hash de los padres)». El ejemplo del hash de los
padres sí podría exigir campo; `σ(B)` no, porque es derivado (`C-GD-09`) igual que `C-HDR-06` deriva
el rango esperado de `past(B)`.

**Etiqueta**: *derivado*; discrepancia declarada.

---

## H7 · Nada de esto se mide en una red real

El modelo es de reglas y de árbol privado. `Δ` es simulada en el repositorio, no medida
(`P-ZRX/P-2.1/SINTESIS.md` §2.3), `Dmax` no está medido, y la tasa real de sectores/TiB no se mide
aquí. **Toda cifra de umbral es un umbral de modelo, no una medición de red.**
