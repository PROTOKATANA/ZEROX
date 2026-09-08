# D8 — Ronda 10a: romper la **revelación retardada por VDF**, R-FIN-14 (h)

**Agente:** D8 (adversarial), Opus 5 · **Fecha:** 2026-09-08 · **Método:** `research/scripts/METODO-AGENTES.md`
**Directorio:** `research/scripts/d8-ronda10a/` (no se toca ningún otro fichero del repositorio).

**Objeto.** La opción (h) de R-FIN-14 (`research/dag-poas-ancla-de-orden.md:284-287`):
`entropía_j = VDF(chunk(I_j) ‖ salida(I_j), L·iter)`, revelada en `t_j = slot(I_j) + L`. El encargo la
presenta con la cota **«steering 0 salvo `ρ ≥ L/W_dec`» (80 con `L = 1 h`, 160 con `L = 2 h`)**.

> **TITULAR (adelanto): esa cota es FALSA y sobra un factor ~18×.** El umbral real de steering bajo (h) es
> **`ρ* = (L + I − 1)/(I + W_dec)`** — **8,98** con `(L, I) = (2 h, 851 s)` y **4,97** con `(1 h, 851 s)` —,
> no 160 ni 80. La razón: el atacante **no espera a que le revelen `entropía_j`; la calcula él**, porque sus
> dos entradas (`chunk(I_j)`, `salida(I_j)`) son públicas o suyas. (h) no le quita el conocimiento: le cobra
> `L/ρ` segundos de reloj **por candidato**, en paralelo con la cadena principal. Aun así **(h) sigue siendo
> una mejora grande y bien definida**: sin (h) el steering renace con **cualquier** `ρ > 1`; con (h) hace falta
> `ρ ≥ 9`, que no existe en silicio (`research/pot-aes-asic-chacha.md` §3, techo estimado 1,5-2,5×).
> Lo que hunde a (h) como núcleo no es el reloj: es el **coste del timekeeper** (§B.3, §C) y el **DoS de
> verificación** (§B.2) si no se escribe la regla que los acota.

---

## A · La regla operativa completa, antes de atacarla

9c dejó (h) en dos líneas de nota. Sin las cuatro decisiones que siguen no hay nada que atacar, así que las
fijo yo, en la lectura **más favorable al diseño** que sea consistente (atacar la versión fuerte, no un
hombre de paja). **Etiqueta del texto entero: PLAUSIBLE** — es una regla candidata mía, no verificada en red.

### A.0 · Notación

`I_j` = ancla de la época `j` (R-FIN-1) · `T_j = j·I` · `S_max = 150 s` · `W_dec ≤ 45 s` (9c §C, medida) ·
`L` = retardo de revelación en slots (= `F` en el diseño vigente) · `iter` = `slot_iterations` vigente
(R-FIN-9) · `ρ = reloj_AES(atacante) / reloj_AES(timekeeper)`.

### A.1 · Quién calcula el VDF de revelación y cuándo empieza — **especulativo sobre el menú, no sobre el ancla**

> **(h.1)** Para cada bloque `X` con `slot(X) ∈ [T_j, T_j + S_max)` que un nodo considere **candidato a `I_j`**,
> el timekeeper **MAY** iniciar, en el instante en que conoce `X` y `salida(f, slot(X))`, la cadena
> `V(X) = AES128_chain^{L·iter}( blake3(chunk(X) ‖ salida(f, slot(X)))[0..16) )`.
> El timekeeper **MUST** haber completado `V(I_j)` para el ancla efectivamente seleccionada **antes de**
> `t_j = slot(I_j) + L`. `entropía_j := blake3(salida_final(V(I_j)))`.

Las dos disciplinas posibles y su condición, escritas:

| Disciplina | Cadenas simultáneas | Condición de puntualidad |
|---|---|---|
| **(i) esperar al ancla** (arranca en `T_j + W_dec`) | `⌈L/I⌉` | dispone de `L − W_dec` para `L·iter` ⇒ **`ρ_tk ≥ L/(L − W_dec)`**: 1,0063 con `L = 2 h`, 1,0127 con `L = 1 h` |
| **(ii) especular** (arranca al ver cada candidato) | `m · ⌈L/I⌉` | `ρ_tk ≥ 1` a secas; `m` medido 2,54, cota `1 + λ·S_max = 151` |

**Esto ya es un hallazgo, y va en contra de (h):** con la disciplina (i) el timekeeper honesto **necesita ser
un 0,63 % más rápido que el nominal para llegar a tiempo**, y el nominal ya es el tope del mercado
(`AESENC` a 3 ciclos y 6,2 GHz, `research/pot-aes-asic-chacha.md` §2). Con la disciplina (ii) no necesita
margen, pero paga `m` veces más núcleos. **La regla honesta es la (ii) con un `m` acotado por política**
(sólo candidatos con `blue_work` compatible), y `W_dec` de gracia como respaldo.

### A.2 · Publicación y verificación

> **(h.2)** La revelación viaja como `PotCheckpoints` de la cadena `V(I_j)`, en el mismo gossip de PoT
> (`/subspace/subspace-proof-of-time/1`, `sc-proof-of-time/src/source/gossip.rs:72`), bajo un tema separado
> `…/reveal/1`. Un nodo **MUST NOT** verificar una revelación cuya semilla no sea exactamente
> `blake3(chunk(X) ‖ salida(f, slot(X)))` para un `X` que él mismo tenga por candidato a `I_j` — es la
> misma defensa que Autonomys aplica al PoT ordinario (`gossip.rs:239-256`: si `proof.seed ≠
> next_slot_input.seed`, `GOSSIP_NEXT_SLOT_MISMATCH` y **no se verifica**).
> **(h.2b)** Un bloque `B` con `slot(B) ≥ t_j` **MUST** poder justificar `entropía_j`: la revelación entra en
> la justificación de PoT de R-FIN-14 (d), acotada como allí.
> **(h.2c) Regla de coste (nueva, y necesaria — §B.2):** un nodo verifica **una sola** revelación por época:
> la del `I_j` de **su** cadena seleccionada. Cualquier otra se archiva sin verificar hasta que una
> reorganización la haga canónica.

### A.3 · Qué pasa si en `t_j` no hay entropía — **la regla que 9c no escribió**

Tres semánticas posibles; sólo una es compatible con R-FIN-4 («función de `past(B)` y de nada más»):

> **(h.3) Continuidad por defecto.** Si en el slot `t_j` ningún bloque de `past(B)` aporta una revelación
> válida de `I_j`, la cadena de PoT **continúa sin inyección**: `semilla(f, t_j) = salida(f, t_j − 1)`, y la
> inyección `j` se aplica en el **primer slot `s ≥ t_j` en que la revelación esté disponible en `past(B)`**,
> con `t'_j := s`. La época `j+1` no se desplaza (`T_{j+1} = (j+1)·I` sigue siendo un índice fijo).

Las dos alternativas y por qué las descarto, dicho en voz alta:
- **«La cadena se para hasta que llegue»** — convierte al timekeeper en un punto único de parada de la red
  entera. Inaceptable: es exactamente lo que `timelord-redundancia-informe.md` §1.2 señala como el defecto de
  Autonomys hoy, y (h) lo multiplicaría por `⌈L/I⌉`.
- **«El bloque que la traiga la aplica»** — hace `flujo` dependiente del orden de llegada y rompe R-FIN-5
  (dos honestos leerían flujos distintos para el mismo `X`). REFUTADA por construcción.

**Coste de (h.3), declarado:** un timekeeper que se retrasa `d` segundos **regala `d` segundos de reto
predecible** (la cadena sigue sin re-sembrar). Es el mismo agujero que (h) venía a cerrar, abierto por el
lado de la vivacidad. Cota: mientras `d ≪ I`, el steering adicional va como `√(d/I)` (fórmula de 9c D.1).

### A.4 · Composición con R-FIN-3/4/5 (partición) y R-FIN-9 (recalibración)

> **(h.4)** La revelación es **por flujo**: `V(X)` se siembra con `salida(f, slot(X))`, luego dos flujos
> distintos producen revelaciones distintas para el mismo `X` y R-FIN-5 sigue siendo una comprobación
> estructural previa a cualquier PoT. En una partición, **cada lado debe sostener sus propias
> `⌈L/I⌉ + 1` cadenas**; un lado sin esa capacidad no produce bloques válidos a partir de su primer `t_j`,
> **aunque conserve espacio** (ver §B.4).
> **(h.5)** `N(s)` (R-FIN-9) se recalibra igual que hoy, pero el **número de iteraciones de la cadena de
> revelación queda congelado en el `N` vigente en `slot(I_j)`**: si se leyera el `N` de `t_j`, el propio
> retarget de iteraciones desplazaría el instante de revelación y `t_j` dejaría de ser determinista.
> **DEMOSTRADO por construcción** (es la única lectura que hace `t_j` función de `past`).

### A.5 · Precedente: la *infused challenge chain* de Chia

Chia ya opera una segunda cadena de VDF cuyo resultado se inyecta en el reto. Leído en el clon v2.7.4:

- **Quién:** el mismo timelord, como una tercera cadena concurrente —
  `PDF/chia-blockchain/chia/timelord/types.py:6-10` (`CHALLENGE_CHAIN`, `REWARD_CHAIN`,
  `INFUSED_CHALLENGE_CHAIN`) y `chia/timelord/timelord.py:351,470` (itera sobre las tres).
- **Cuándo empieza:** cuando el *deficit* del bloque anterior baja de `MIN_BLOCKS_PER_CHALLENGE_BLOCK = 16`
  (`chia/consensus/block_header_validation.py:170`, `chia/consensus/default_constants.py:15`); dura un
  sub-slot (`SUB_SLOT_TIME_TARGET = 600 s`, `default_constants.py:38`).
- **Qué pasa si falta:** **no es opcional.** `block_header_validation.py:204`:
  `assert (sub_slot.infused_challenge_chain is None) == (icc_challenge_hash is None)`; y si el génesis la
  trae, `Err.SHOULD_NOT_HAVE_ICC` (`:162-163`). Su presencia es una **función del pasado**, exactamente como
  exige (h.2b) aquí.
- **Lo que Chia NO hace y (h) sí pediría:** la ICC de Chia dura **un sub-slot** (600 s) y hay **una** viva a
  la vez. (h) con `L = F = 2 h` e `I = 851 s` pide **nueve** vivas a la vez. El precedente **sostiene el
  mecanismo, no la escala.** VERIFICADO (citas leídas); la comparación de escala es mía.

---
