# Tras D8: qué mueve la seguridad y qué no — el doble conteo, y cuatro palancas

**Fecha:** 2026-09-08, tarde · **Autor:** agente principal, **sin auditar** (va a D9 como pregunta única) ·
**Pregunta de Katana:** «¿qué podemos hacer para que los ataques de D8 no sean viables, sin perder el DAG?»

## 1 · Corrección previa: D8 (y las rondas 3-8, yo incluido) contamos dos veces el espacio del atacante

Todo umbral de flujo único se calculó con `r = α/((1−α)(1−δ))`, metiendo **el mismo `α`** en el `δ` (rojos honestos
que el atacante provoca) y en la carrera privada. Pero `δ` solo se provoca con bloques **publicados** (la parásita
publica cada ráfaga; el evento del Lema 9 publica `k+1`), y la carrera de doble gasto necesita bloques **privados**.
Son presupuestos disjuntos: `α = α_p + α_f`. Con la parásita en su óptimo, rojos por bloque del atacante = 1
(`J*` rojos por `J*` bloques), luego el `blue_work` público crece a `(1−α−α_p) + α_p = 1−α` y
`r = α_f/(1−α) ≤ α/(1−α)`: **parasitar nunca ayuda al que corre** (DEMOSTRADO a nivel de tasas; el `δ` natural
medido a `α=0` es 0,0000). Recalculado con el `prev()` de D8 (Skellam, `3k`, `F = 19 080 s`, `10⁻¹⁰` en 10 años):

| Modelo | Frontera de flujo único |
|---|---:|
| `δ` de D8 con el mismo `α` en los dos sitios (lo publicado en la auditoría 7) | 36,5 % |
| Lema 9 como tasa, `δ = 0,2105` (rondas 3-8) | 40,8 % |
| **Atacante único, `δ = 0`** | **46,9 %** |
| Atacante + parásita racional ajena del 10 / 20 / 33 % | 42,0 / 37,2 / 30,9 % para el atacante (suma 52-64 %) |

Lo que el `δ` de la parásita sí hace: (i) **convierte a terceros racionales en peso adversario** mientras sea
rentable (R-FIN-8), (ii) **revierte transacciones** de bloques honestos que vuelve rojos (R-FIN-8, 64-142 s),
(iii) infla `λ_real` si el retarget cuenta solo azules. Las tres son de reglas, no de GHOSTDAG.

## 2 · Palancas

**P1 · R-FIN-8 → semántica de Kaspa.** Los rojos con billete válido dentro de `merge_depth` **cobran** y sus
transacciones **se aplican en el orden del mergeset si no entran en conflicto**; el retarget cuenta **todos** los
bloques válidos. Cierra (i), (ii), (iii): sin ganancia, sin reversión, sin inflación. Coste: re-verificar que la
«inflación ×10» (ronda 1) y el «espacio gratis» (ronda 3) que motivaron R-FIN-8 ya no existen con U2 + U3″ (cada
billete paga una vez) — PLAUSIBLE, no comprobado. Es la palanca más barata: una regla.

**P2 · Umbral operativo 33 %.** Con la frontera corregida (≥ 40,8 %) tiene ≥ 7,8 puntos; absorbe el steering
comprado (`α_ef(33 %, m=151) = 34,5-35,8 %`) y `Δ` sin medir.

**P3 · Recalibrar `(g, I, F)` para la economía.** `F` no sale de la carrera (F_min a `α=0,35`: 0,34 h con
`δ=0`, 1,85 h con el `δ` pesimista de D8), sale de la pinza del steering `F = I/(W/κ−1)`, `I = (c_m/g)²/(αλ)`.
Aceptando más steering en `α = 0,10`:

| `g` objetivo | `I` | `F` | `I+F` | margen B plotter 10× | margen B hoy | `α_ef(33 %)` con `m=2,8` / `m=151` |
|---:|---:|---:|---:|---:|---:|---:|
| 3,6 % (actual) | 4 890 s | 6,17 h | 7,53 h | 0,54× | 5,4× | 33,5 / 34,5 % |
| 5 % | 2 535 s | 3,20 h | 3,90 h | 1,05× | 10,5× | 33,6 / 35,0 % |
| **7 %** | 1 293 s | 1,63 h | 1,99 h | **2,06×** | 20,6× | 33,9 / **35,8 %** |
| 10 % | 634 s | 0,80 h | 0,98 h | 4,20× | 42,0× | 34,3 / 37,0 % |

(`m = 2,822`; con la `m = 2,955` final de D8 los tiempos suben ~10 %: `g = 7 %` → `I ≈ 1 500 s`, `F ≈ 1,9 h`,
lookahead ≈ 2,3 h, margen ≈ 1,8×.) Coste: un granjero del 10 % que compre `m ≈ 20` gana ~16 % más bloques por
época — desigualdad, no seguridad.

**P4 · Ventana de decisión del steering acotada por el PoT (a verificar en el diseño).** Autonomys re-siembra el
PoT con la entropía (`seed_with_entropy`, `pot.rs:288`) y deriva el reto de cada slot del PoT **secuencial**
(`derive_global_challenge`, `lib.rs:110`). Si ZEROX hace lo mismo, evaluar un candidato exige calcular su cadena de
PoT slot a slot, y **la elección del ancla se cierra en ~`S_max` (150 s) o en la carrera `k` (~45 s), no en `L`**:
el atacante solo puede evaluar `ρ·S_max ≈ 150-225` slots de cada candidato, no la época entera. El steering baja
por `√(n_eval/I)`: ×0,42 a `I = 1 293 s`, ×0,23 a `I = 4 200 s`. **La propuesta no escribe cómo deriva el reto por
slot** (R-FIN-2 solo fija la entropía). Si sigue a Autonomys, todas las rondas sobreestimaron el steering 2-5×; si
no, cambiarlo es gratis (el `verify` de 96 ms/slot ya se paga).

**Descartado (analizado hoy):** tocar el coloreado de GHOSTDAG con reglas de puntualidad por slot. Eximir bloques
«tardíos» del anticono quita la cota `k` (una cadena que fusiona todo gana siempre); penalizar bloques «no
referenciados» crea un vector de griefing con `α` pequeño (12 % de bloques honestos a rojo con ventanas de 15).

## 3 · Orden recomendado

P1 y P2 ya. Verificar P4 en la propuesta (una lectura). Después P3 con la `m = 2,955` y el `g` que P4 permita.
Y lanzar **una** pregunta a D9: ¿es correcto el argumento de presupuestos disjuntos de §1? Si lo es, la frontera
real es 41-47 % y el 33 % tiene el colchón que a 35 % no tenía. `Δ` sigue sin medir.

---

## 4 · Correcciones tras las rondas 9a, 9b y 9c (2026-09-08, tarde-noche)

**§1, por 9a (`dag-poas-ancla-de-orden-auditoria-8a.md`) — la tesis es CORRECTA, y hay que escribirla así:**
1. «Rojos por bloque publicado ≤ 1 en el óptimo» no es una coincidencia: **`R < A` es equivalente a que la ráfaga
   gane** (teorema de la ráfaga); las que dejan más rojos que azules son las que pierden, y las que pierden no
   dejan rojos. La razón de fondo es más fuerte: el paper define la carrera contra `w_H`, el score del **bloque
   virtual honesto**, que incluye los azules del atacante (`phantom-ghostdag.txt` L1034-1036); `(1−α)(1−δ)λ`
   nunca fue el denominador.
2. **La condición `2Δλ ≪ k` va en la misma frase que el 46,9 %.** El `δ` natural es 0,0000 a `Δ = 4 s` y solo ahí:
   a `Δ = 16 s` la frontera es 38,3 %; a **`Δ = 20 s`, 32,4 %**.
3. **El 46,9 % es la frontera contra un atacante de espacio.** Contra uno que degrade la red hasta `Δ_ef = 20 s`,
   es 32,4 %. `Δ` es la medición que el diseño necesita antes que ninguna otra.

**P1, por 9b (`auditoria-8b.md`) — mal escrita, bien de fondo:** «con U2 + U3″ cada billete paga una vez» es falso
(las copias son rojas pero válidas: ×15 si se pagan sin distinguir); «semántica de Kaspa» no es lo que queremos
(en Kaspa cobra el fusionador, y eso duplica la parásita). Lo correcto es **R-FIN-8′** (`rojo_k` cobra su propia
coinbase y aplica; `rojo_U3` inerte) + **R-FIN-13′** (un bloque por identidad). Y P1 no es «la palanca más
barata»: es **precondición** del 46,9 % (sin ella un tercero racional parasita por dinero y resta frontera).

**P4, por 9c (`auditoria-8c.md`) — correcta en mecanismo, conservadora en número, mal enunciada:** la ventana de
decisión es **`W_dec ≤ 45 s`** y no la fija `S_max` sino la carrera; con `ρ ≤ 1` el steering es **0**, no
`W_dec` (la fila `ρ = 1` de §2 estaba mal); y lo que P4 compra no es bajar `α_ef` (a `g` fijo es una identidad)
sino el **precio** de `g`: `I + F` de 8,26 h a 0,76-1,31 h, margen 0,50× → 3,1-5,4×. Regla nueva **R-FIN-14** y
restricción `I ≥ ρ_max·W_dec`. Con la pinza desactivada, `F = max(F_carrera, I/(W/κ − 1))`.

**P3 queda por decidir con estos números** (elección de `ρ_max` y de `F`): tabla en `auditoria-8c.md` §3.
