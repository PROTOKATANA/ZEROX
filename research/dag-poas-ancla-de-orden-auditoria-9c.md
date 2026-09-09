# Auditoría 9c — Ronda 10c: qué compra de verdad una `F` corta (sembrador, pinza del steering, usuario)

**Pregunta:** el lookahead real bajo R-FIN-14; si la pinza `F ≥ I/(W/κ − 1)` es real o artefacto; qué ve el usuario; qué término
manda en `F` por configuración. · **Fecha:** 2026-09-09, madrugada · **Agente:** D9 en **Opus 5**, relanzado sin presupuesto de
tiempo · **Informe (870 líneas), 10 scripts, 11 salidas, 14 commits solo en su directorio:** `research/scripts/d9-ronda10c/`.

> **VEREDICTO (mío, tras reproducir A.1, B, C.2, D y F):** (1) **El granjero honesto tiene lookahead 0** bajo R-FIN-14: el §4.8 de la
> propuesta («todo granjero conoce sus victorias `L` por adelantado») queda **REFUTADO**. (2) El atacante con `ρ > 1` conserva
> `(F − W_dec) + I(1 − 1/ρ)` slots, y es un **acantilado en `ρ = 1`**: `ρ = 1,001` ya da el 82-96 % de lo que da `ρ = 10`; `ρ`
> grande solo acorta el bootstrap (83 días → 13 min). **El sembrador sobrevive para cualquier `ρ > 1`** (margen frente a un
> plotter 10×: 1,91× a `F = 2 h`, 3,56× a `F = 1 h`, con `ρ = 3`; con (h), 2,8-5,5×, no 26-52× como 10c publicó primero y
> corrigió en §F) **e impone un MÁXIMO a `F`, no un mínimo**. (3) **La pinza es real pero su número era el rincón `ρ → ∞`:**
> 1 198 s (`ρ = 1,5`) / 2 488 s (`ρ = 3`) con `I = 851 s`, no 3 868 s; y **`W/κ = 1,22` no es umbral de nadie** (BDK marca 1,00;
> con `W` recalculada bajo R-FIN-14 y `ρ ≤ 1`, `W/κ = 0,0007`, tres órdenes dentro). (4) **Al usuario le da igual `F`:** la
> reversión `prev` no lleva `F`; a `α = 0,33` espera 217-2 406 s para `10⁻⁹`, y **ninguna confirmación es posible antes de
> ~100-134 s** (ventaja `3k`); `F = 1 h` frente a 2 h no le compra nada y cuesta 2,0-2,6 puntos de frontera (a 1 h el 33 %
> conserva 0,05 puntos en el pesimista). (5) **Hallazgo no pedido, el que más cambia el cuadro:** el lookahead depende de `L`
> (rezago de inyección), no de `F`; hoy `L = F` sin necesidad. **`L = 1 h`, `F = 2 h`, `ρ_max = 3`: margen 3,6×, `W/κ = 0,576`
> dentro de BDK, sin segundo VDF**, a costa de tolerar particiones de 1 h. PLAUSIBLE, y es la decisión F1 de Katana.

---

## 0 · Verificación independiente del agente principal

| Comprobación | Resultado |
|---|---|
| Commits `3496140`…`2c21d37` | **Solo su directorio** (un `__pycache__` colado y retirado, declarado) |
| `AUDITA_SCRIPTS.py` (10 scripts), pasado por mí | 1 marca `[T1]` en `r10c_lib.py:41` (`hf_delta0` ignora `alpha`): es la tesis de 9a, `δ = 0` para todo `α`; falso positivo, leído |
| **`r10c_d_tabla.py`** re-ejecutado por mí | **IDÉNTICO** a `salida_d.txt` |
| **`r10c_f_correccion_h.py`** | **IDÉNTICO** a `salida_f.txt` |
| **`r10c_c2_frontera.py`** (38 min) | **IDÉNTICO** a `salida_c2.txt` salvo marcas de tiempo; reproduce `verif_frontera_vs_F.py` (34,81/28,74 · 42,30/33,31 · 44,57/35,08) |
| **`r10c_a1_lookahead.py`** y **`r10c_b_pinza.py`** | **IDÉNTICOS** a `salida_a1.txt` / `salida_b.txt` salvo marcas de tiempo |
| No re-ejecutados por mí | `r10c_a2_ancla_mc.py` (MC del ancla, 12 semillas), `r10c_c_reversion.py` (control analítico + MC 12 semillas, razones 0,983-1,003 declaradas), `r10c_e_palanca_L.py` |
| Fuentes | Ronda 7 `dag-poas-ancla-de-finalidad.md:319-322` (la forma cerrada `(L+I)(1−1/v)` que 10c reproduce en 24 filas); 9c §B.2 (Autonomys secuencial); BDK19 para `W/κ` |

---

## 1 · El lookahead (A) — VERIFICADO

Dos instrumentos independientes con 0,274 % de discrepancia. Honesto (`ρ = 1`): **0 slots**. Atacante: `(F − W_dec) + I(1 − 1/ρ)`
para `ρ > 1`, 0 para `ρ ≤ 1`. A `F = 2 h`, `I = 851 s`, `α = 0,33`: 7 463 s (`ρ = 1,5`), 7 746 s (`ρ = 3`). Con (h), corregido en
§F: `(L + I)(1 − 1/ρ) − W_dec` = 2 663 / 5 346 / 7 225 s (`ρ` = 1,5 / 3 / 10) — **sí depende de `F`**, en contra de 9c §E.5 y de
acuerdo con la ronda 7. `δ_ancla` medido (12 semillas): media 1-3 s, máximo 10 s: +0,13 % al lookahead, despreciable.

**¿Sembrar a tiempo?** Con ploteo extrapolado a 4,28 s/sector (841 GiB/h por GPU tope): con `ρ ≤ 1`, 0 sectores; núcleo con
`ρ = 3` y `F = 2 h`: margen 1,91×; `F = 1 h`: 3,56×; con (h) a `F = 2 h`: 2,8-5,5×. **El argumento del sembrador sobrevive y
acortar `F` (o `L`) casi duplica el margen.**

## 2 · La pinza (B) — mecanismo PLAUSIBLE, número REFUTADO

`W/κ = 1,22` salió a `F = 3,2 h` en la ronda 7 y se arrastró como umbral; BDK marca `≤ 1,00` y `W/κ = 1 + I/F > 1` siempre bajo
la `W` vieja: criterio insatisfacible. Con `W` recalculada bajo R-FIN-14 (`W = 1 + λD = 5` bloques a `ρ ≤ 1`), `W/κ = 0,0007`.
La pinza real, a `ρ > 1`: **1 198 s (`ρ = 1,5`) / 2 488 s (`ρ = 3`)** con `I = 851 s`. LAGUNA: el porte del ataque de BDK a PoAS
con el coste de oportunidad de R-FIN-8′ (el sobornado pierde su coinbase: rompe «arbitrarily small stake»); y las unidades de
`W` y `κ` en un DAG (×5,2-5,8 si se mezclan bloques del DAG y de cadena).

## 3 · El usuario (C) — VERIFICADO

| `α` | 60 s | 300 s | 600 s | 1 800 s | 3 600 s |
|---|---:|---:|---:|---:|---:|
| 0,10, `δ = 0` | 1 | 6,4e-21 | 1,3e-68 | ~0 | 0 |
| 0,25, `δ = 0` | 1 | 2,2e-4 | 7,4e-19 | 9,5e-87 | 4,4e-191 |
| 0,33, `δ = 0` | 1 | 2,5e-1 | 1,5e-6 | 7,1e-36 | 4,3e-82 |
| 0,33, pesimista | 1 | 9,99e-1 | 5,5e-1 | 2,4e-6 | 1,3e-16 |

`prev` no lleva `F`. Suelo de espera `≈ 3k/((1−α)λ) = 100-134 s`. Lo que se paga por `F = 1 h` frente a 2 h: la frontera baja
2,0-2,6 puntos y el 33 % se queda con 0,05 puntos en el pesimista.

## 4 · Qué término manda (D) — VERIFICADO

| Configuración (`α = 0,33`) | `F_carrera` (mín) | pinza (mín) | usuario | máximo del sembrador (3×) | manda |
|---|---|---|---|---|---|
| `ρ_max = 1` | 0,29 h / 1,00 h pesim. | no existe | nada | sin límite | `F_carrera` |
| `ρ_max = 1,5` | 0,28 / 0,99 h | 0,23 h | nada | 1,32 h | `F_carrera` |
| `ρ_max = 3` sin (h) | 0,28 / 0,99 h | **0,69 h** | nada | 1,21 h | pinza (`δ = 0`) / `F_carrera` (pesim.) |
| `ρ_max = 3` con (h) | 0,28 / 0,99 h | 0,27 h | nada | 1,82 h | `F_carrera` |

A `α = 0,35` pesimista, `F_carrera = 1,92 h` y el núcleo con `ρ > 1` **no cabe** con margen ≥ 3×. El precio de (h): 40,7 % de
un núcleo a `F = 1 h`, 81,3 % a 2 h (`I = 851 s`), coherente con 10a.

## 5 · `L` desatada de `F` (E) — PLAUSIBLE

`L = 1 h`, `F = 2 h`, `ρ_max = 3`: lookahead 4 146 s, margen 3,6×, `W/κ = 0,576` (dentro del tope literal de BDK), sin (h).
Coste: tolerancia a particiones 2 h → 1 h. Condición de la ronda 7 (`L ≥ I`) se cumple (3 600 > 851). **Lo que hay que
comprobar antes de adoptarla:** que `L < F` no reabra «conocer `entropía_j` antes de elegir `I_{j+1}`» (la ronda 7 lo marcó para
`L ≥ I`, y aquí `L > I`); re-medir `W_dec` y `m` con `L = 1 h`; escribir la regla de partición en función de `L`.

## 6 · Errores declarados por el agente

Columnas «(h)» publicadas con una premisa falsa heredada de 9c §E.5 (corregidas en §F: márgenes 2,8-5,5×, no 26-52×; la fuente
que lo desmentía, la ronda 7, la había citado él mismo para otra cosa); tres veces el mismo error de instrumento (horizonte más
corto que el bootstrap); un Monte Carlo con celdas saturadas; una aritmética al vuelo (99,7 % → 82-96 %); `W_dec` no re-medida
(usa la de 9c con su LAGUNA de resolución).

## 7 · Efecto sobre las decisiones

- **F1 (`L` desatada):** es la palanca del sembrador y la alternativa cuantificada al candado. Recomendación del principal: **sí,
  `L = 1 h`, `F = 2 h`**, tras comprobar las tres condiciones de §5.
- **F2 (`ρ_max` / (h)):** con F1 adoptada, (h) compite con margen 2,8-5,5× frente a 3,6× sin (h): la ventaja marginal del candado
  es pequeña frente a su coste. Recomendación del principal: **sin candado, `ρ_max = 3`, (h) como opción escrita** (10a A.6).
- **F3 (`F` de producción):** el usuario no gana nada; la frontera pierde 2 puntos. **Mantener 2 h** salvo que `Δ` medido
  sobre. Corrige lo que Katana entendió («F corta es mejor para el usuario»): mejor solo contra el sembrador, y eso lo hace `L`.
- **§4.8 de la propuesta:** eliminar («previsión propia» no existe bajo R-FIN-14).
- **R-FIN-13 y la pinza:** reescribir `W/κ = 1,22` como lo que es (un valor histórico), y la restricción real de 10c B.
