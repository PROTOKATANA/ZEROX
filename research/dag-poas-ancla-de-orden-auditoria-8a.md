# Auditoría 9a — ¿Contamos dos veces el espacio del atacante? — Sí, y la frontera es 46,9 % contra el espacio

**Pregunta única:** `dag-poas-tras-d8-palancas.md` §1 afirma que D8 y las rondas 3-8 metieron el mismo `α` en el
`δ` (rojos honestos, que solo se provocan con bloques publicados) y en la carrera privada (que exige bloques
privados); con presupuestos disjuntos, `r ≤ α/(1−α)` y la frontera de flujo único sería 46,9 %, no 36,5 %.
**¿Es correcto? ¿Dónde se rompe?** · **Fecha:** 2026-09-08, tarde · **Agente:** D9-9a en **Opus 5**, adversarial;
el primer lanzamiento murió por cuota tras L1-L2b y el relanzado **continuó desde el disco** (verificó lo heredado,
lo corrigió en tres puntos y lo commiteó como WIP) · **Informe (658 líneas), 9 scripts, 8 salidas, 12 commits
solo en su directorio:** `research/scripts/d9-ronda9a/`.

> **VEREDICTO (mío, tras reproducir sus scripts):** **la tesis es correcta y 9a no encontró dónde se rompe
> tras seis vías de refutación.** Y la razón es más fuerte que la que yo escribí: el paper define la carrera
> contra `w_H`, el score del **bloque virtual honesto**, que **incluye los azules del atacante**
> (`phantom-ghostdag.txt` L1034-1036, leído por mí): `(1−α)(1−δ)λ` **nunca fue** el denominador. Frontera de
> flujo único (unión 10 años `< 10⁻¹⁰`, Skellam con `3k`, `F = 19 080 s`): **46,88 %** con `δ = 0`, en tres
> implementaciones coincidentes que antes reproducen el 36,5 % (auditoría 7) y el 40,8 % (rondas 3-8) como
> control. **Con una condición que yo no escribí y que decide todo:** `2Δλ ≪ k`. Con `Δ = 4 s` el `δ` natural
> es 0,0000; con `Δ = 16 s` la frontera baja a 38,3 %, y con **`Δ = 20 s` a 32,4 %**, por debajo del 33 %. **El
> número que hay que medir no es `α`, es `Δ`.** Y con la ronda 9b compuesta: **R-FIN-8′ es precondición del
> 46,9 %**, porque sin ella un tercero racional parasita por dinero y cada punto suyo resta un punto de frontera.

---

## 0 · Verificación independiente del agente principal

| Comprobación | Resultado |
|---|---|
| Commits `3fa103f`…`0c09967` | **Solo su directorio**; el `__pycache__` que el primer D9 commiteó, sacado del índice |
| `AUDITA_SCRIPTS.py` (9 scripts) | 4 marcas `[T3b] padres/ph` en `r9a_lib.py` (L132, 267, 321, 393): el mismo falso positivo de D8, leído (rama honesta vs rama del atacante que fusiona la vista honesta a propósito). 0 T1/T2/T3/T4 |
| Paper L1034-1036 | **Literal:** «The honest score `wH(t)` is defined as the score of the virtual block of the honest node at time t» — incluye los azules del atacante |
| Paper L1136-1147 | **Literal:** el Lema 9 reemplaza `k + 2Dλ` azules por `k + 1`; de ahí `k/(k+2Dλ) = 1 − 0,2105` con `k = 30`, `2Dλ = 8`. Es la fuente exacta del `δ = 0,2105` de las rondas 3-8 |
| `protocol.rs:194-212` | **Real:** `check_blue_candidate_with_chain_block` recorre solo `mergeset_blues` — un rojo nunca cuenta en el anticono azul de otro |
| Teorema de la ráfaga, rehecho por mí | Con `R(J) = J(1−α)/α − k` y `A = J`: gana ⟺ `k + J > J(1−α)/α` ⟺ `R < A`. **Trivialmente equivalente**; lo que no es trivial es la lectura: las ráfagas que dejan más rojos que azules son las que **pierden**, y las que pierden no dejan rojos |
| Reparto `α = α_p + α_f` (A2, heredado, 7 200 corridas) | Deriva máxima en `α_p = 0` en las 5 filas; `W_pub/H ≥ 1,0000` en 30 celdas; los 4 controles del encargo pasan (`α_p = 0` → deriva `2α−1` a ±0,004; `α = 0` → 0; `α_f = 0,55` → +0,116) |
| Publicación parcial (A4, heredado sin ejecutar, ejecutado por 9a) | `frac_pub = 1` reproduce el `δ` de D8 exacto; al retener, `δ` **cae** (0,3065 → 0,1033) porque el 99 % de las publicaciones parciales no cambian la cadena |
| **Los 8 scripts re-ejecutados por mí** | `a1` (175 s), `a1b` (148 s), `a2` (258 s, 7 200 corridas), `a3` (18 min), `a4` (150 s), `a5` (13 s), `a6` (50 s), `a7` (0,01 s): **IDÉNTICOS** a `salida_*.txt` línea a línea, salvo el tiempo de ejecución |

---

## 1 · Por qué es correcto — en tres capas

1. **La fuente.** La carrera del paper compara al atacante con `w_H`, el score del bloque virtual honesto, que
   suma **todos** los azules, propios y ajenos. El diseño (desde la ronda 3) puso `(1−α)(1−δ)λ`, que es el ritmo
   de **bloques honestos azules**: una magnitud distinta, y menor.
2. **La cota por evento (Prop. A, heredada y rehecha):** `R ≤ A + |Y_h \ X_h|` — los honestos que un cambio de
   cadena enrojece son a lo sumo los azules del atacante que entran más una holgura de honestos creados en
   `(t_{B′} − Δ, t]` (9a corrige el intervalo que el primer D9 escribió).
3. **El contraejemplo del propio paper, y por qué no se realiza.** El Lema 9 reclama `R = k + 2Dλ = 38` por
   `A = k + 1 = 31` (`R/A = 1,226`). Pero exige que el último bloque publicado tenga score ≥ el del padre
   seleccionado **y no lo comprueba**: con `k = 30` una ráfaga de `k + 1` gana solo si `α > (k+1)/(3k+2) = 0,337`,
   y ahí `R/A = 0,889`. Barrido `J = 1..1000 × 10 α`: 10 000 casos, 0 discrepancias. **E incluso concediendo el
   exceso `2Dλ` por evento**, `argmax_β r(β) = 0` para todo `α < 1/(1+c) = 0,795`.

## 2 · Las seis vías de refutación, todas fallidas

| Vía | Resultado |
|---|---|
| Más de 1 rojo por bloque publicado (37 maniobras: parásita, cadena, abanico, dos parásitas alternas, copias U3″) | máximo absoluto `R/A_azul = 0,995` (3 996 corridas) |
| El flujo privado hereda parásitos publicados | Están en el pasado de las dos cadenas (se cancelan) y lo de fuera está acotado por `3k` (Lema 12), que `prev()` ya concede; en simulación el flujo **pierde el padre seleccionado** y deja de competir |
| Publicar parte y seguir en privado | `δ` cae, `W_pub/H ≥ 1,04`, `adv_max ≤ 43,4 < 3k` |
| Reparto entre parasitar y correr | deriva monótona decreciente en `α_p` |
| Rojos de rojos | no existen (`protocol.rs:194-212`) |
| Parásito **ajeno** | sí baja la frontera: 42,0 / 37,2 / 30,9 % con parásitos del 10 / 20 / 33 % — reproduce mis números a la cuarta cifra. Es «un granjero de esa cuota apagado» |

## 3 · La frontera, en tres implementaciones

| Modelo | Frontera (`10⁻¹⁰` en 10 años) |
|---|---:|
| (a) `δ` de D8 con el mismo `α` dos veces — control, reproduce la auditoría 7 | 36,54 % |
| (b) Lema 9 como tasa, `δ = 0,2105` — control, reproduce las rondas 3-8 | 40,84 % |
| **(c) atacante único, `δ = 0`** | **46,88 %** |
| (d) parásito ajeno racional 10 / 20 / 33 % | 42,03 / 37,18 / 30,90 % |

A `α = 0,35` con `δ = 0`: unión a 10 años `4,8·10⁻¹⁸⁴`. **Y con R-FIN-8′ (9b) el parásito ajeno deja de ser
racional** (ratio 0,99-1,00): el escenario (d) exige un tercero que queme espacio sin ganar nada.

## 4 · La palanca real: `Δ` (LAGUNA, con número)

| `Δ` | `δ₀` medido a `α = 0` | Frontera | vs 33 % |
|---:|---:|---:|---:|
| **4 s** (diseño) | 0,0000 | **46,88 %** | +13,9 |
| 8 s | 0,0020 | 46,83 % | +13,8 |
| 12 s | 0,083 | 44,65 % | +11,7 |
| 16 s | 0,286 | 38,33 % | +5,3 |
| **20 s** | 0,443 | **32,38 %** | **−0,6** |

`k = 30` aguanta hasta `Δ ≈ 16 s` con colchón; el 33 % se pierde en `Δ ≈ 20 s`. Un atacante **de red** (eclipse
parcial, inundación; fuera del modelo del paper, L1024-1027) sube `Δ_ef` sin gastar espacio, y la verificación no
sucinta del PoT (96 ms/slot) sube `Δ` también. **Y la conservación `W_pub/H ≥ 1` se rompe con `Δ` grande**
(`Δ = 20`, `α = 0,35`: 0,936): el teorema de la ráfaga vale mientras `2Δλ ≪ k`, no siempre.

## 5 · Errores declarados (9a) y correcciones que pide

Suyos: contó la fila `α = 0` como discrepancias (400 falsas, corregido); en la implementación rápida sumó la cola
izquierda con `catch = 1` donde vale `r^(d−3k)` — **el control positivo lo cazó**, sesgo `10⁻⁵⁸`, sin efecto;
mató A3 con su propio `timeout`. Del primer D9: intervalo de la holgura mal escrito, rama «honestos ya rojos»
anulada con argumento circular, contraejemplo del paper no citado, `__pycache__` commiteado.

**A `dag-poas-tras-d8-palancas.md` §1 (aplicado cuando 9c termine de leerlo):** (1) `R < A` es *equivalente* a
que la ráfaga gane, no una coincidencia del óptimo; (2) la condición `2Δλ ≪ k` va en la misma frase que el
46,9 %; (3) el 46,9 % es la frontera contra un atacante **de espacio**; contra uno que degrade la red hasta
`Δ_ef = 20 s`, es 32,4 %.

## 6 · Efecto sobre las decisiones

- **33 %:** con el modelo correcto tiene **13,9 puntos** de colchón contra el espacio; el colchón real lo fija `Δ`.
- **R-FIN-8′:** pasa de palanca a **precondición** de la frontera de 46,9 %.
- **La medición que este diseño necesita antes que ninguna otra es `Δ`**, en red de pruebas, con la verificación
  de PoT real dentro.
