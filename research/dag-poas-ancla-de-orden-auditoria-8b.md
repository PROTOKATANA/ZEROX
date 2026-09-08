# Auditoría 9b — Palanca P1: R-FIN-8 y los rojos que cobran

**Pregunta:** ¿es segura, exacta y suficiente la palanca P1 de `dag-poas-tras-d8-palancas.md` §2 («los rojos con
billete válido cobran, sus transacciones se aplican, el retarget cuenta todos los válidos», presentada como «la
semántica de Kaspa»)? · **Fecha:** 2026-09-08, tarde · **Agente:** 9b en **Opus 5**, fresco, en paralelo con 9a y 9c
por orden de Katana · **Informe (606 líneas), 3 scripts, 4 salidas, 6 commits solo en su directorio:**
`research/scripts/d9-ronda9b/`.

> **VEREDICTO (mío, tras reproducir sus tres scripts):** P1 **tal como la escribí está mal en dos sitios y bien en
> el fondo.** (1) Mi premisa «con U2 + U3″ cada billete paga una vez» es **FALSA**: U3″ dinámica deja **una** copia
> azul por identidad y las demás **rojas, válidas y fusionadas** (`r8c_gd.py:222-231` las manda a `mergeset_reds`);
> pagar rojos sin distinguir por qué son rojos reabre la inflación de la ronda 1 con factor **×15**
> (`max_block_parents`), medido constructivamente: 13-699 copias rojas por billete. (2) «Semántica de Kaspa» no es
> lo que P1 quiere: en Kaspa **el rojo no cobra, cobra el fusionador** (`coinbase.rs:121-131`, leído por mí), y esa
> variante **duplica** la rentabilidad de la parásita (ratio 1,50-2,79) porque el atacante fusiona a los honestos
> que enrojece y se queda con su subsidio. **Lo que sí:** con la distinción `rojo_k` / `rojo_U3` y la coinbase
> **propia** de cada bloque cobrador (R-FIN-8′), la rentabilidad de la parásita pasa de **1,16-1,55 a 0,99-1,00**,
> ningún honesto pierde su recompensa (`S1_h = 1,0000`: se acaban las reversiones de 64-142 s), y con el retarget
> contando un bloque por identidad (R-FIN-13′) la inflación bajo ataque cae de **×1,452 a ×1,005**: la nota
> `dag-poas-delta-real.md` **deja de aplicar** y el umbral de orden sube 40,0 → **41,7 %** por sí solo.

---

## 0 · Verificación independiente del agente principal

| Comprobación | Resultado |
|---|---|
| Commits `68db4fd`…`82223ea` | **Solo su directorio** |
| `AUDITA_SCRIPTS.py` (3 scripts) | 1 marca `[T3b] d/d2` en `r9b_a_copias.py:105`, leída: dos DAG de dos controles distintos, nunca comparados. Falso positivo. 12 semillas en los dos scripts estadísticos |
| Citas de Kaspa @ `c338d495`, leídas por mí | `coinbase.rs:117-131`: `red_reward` suma subsidio+fees de `mergeset_reds` y lo paga **al bloque fusionador** ✓ · `utxo_validation.rs:106-176, 308-314`: transacciones de todo bloque fusionado (rojos incluidos) validadas y aceptadas, `.skip(1)` salta solo la coinbase ✓ · `block_depth.rs:109-119` `kosherizing_blues` ✓ · `post_pow_validation.rs:79-81` `check_bounded_merge_depth` ✓ |
| U3″ en el simulador (`r8c_gd.py:222-231`) | Los filtrados van a `mergeset_reds` y **siguen siendo bloques válidos del DAG**: la copia es roja, no inválida. Mi premisa era falsa por construcción |
| **Los tres scripts re-ejecutados por mí** | `r9b_a_copias.py` (0,1 s), `r9b_c_retarget.py` (111 s), `r9b_d_coste.py` (77 s): salidas **IDÉNTICAS** a `salida_{a,c,d}.txt` línea a línea |
| Control positivo de D | Reproduce `d8-ronda8/salida_a1e.txt` a ±0,0015 (diferencia de agregación declarada) |

---

## 1 · Lo que refuta (A) — mi premisa

U2 invalida un bloque cuya identidad esté **en su propio pasado**; dos copias hermanas en anticono mutuo son válidas.
U3″ deja una azul y el resto rojas. Construcción: `n = 14` copias del mismo billete colgadas de `H0`, `m` bloques
del atacante con padres `(B_{j−1}, 14 copias frescas)`:

| `m` | rojos de `X` | billetes reales | bloques pagados bajo P1 literal | ×/billete |
|---:|---:|---:|---:|---:|
| 1 | 13 | 2 | 15 | 7,50 |
| 5 | 69 | 6 | 75 | 12,50 |
| 50 | 699 | 51 | 750 | **14,71** |

Controles: `n = 0` → 0 copias; copia colgada de copia → `U2`; 21 padres → `TooManyParents`; `u3_mode='off'` → 25
azules (el ×N de peso que U3″ cerró). Asíntota `×15 = max_block_parents`. `mergeset_size_limit = 180` no muerde.
**Y con R-FIN-13 contando «todos los válidos», el retarget se infla ×14,4 por la misma vía.** El invariante que 9b
enuncia y que yo no había visto: **el conjunto que el retarget cuenta y el conjunto que la emisión paga tienen que
ser el mismo**; si no, o la emisión corre por delante (y el atacante captura la diferencia) o `λ_real` se infla.

## 2 · Lo que confirma (B, D) — el fondo de P1, con la redacción correcta

Tres semánticas medidas sobre la parásita de D8 (12 semillas, 1 800 s, `J` de `salida_a1e.txt`):

| `α` | S0 vigente (azules cobran) | **S1 = R-FIN-8′ (azul y `rojo_k` cobran su propia coinbase)** | S2 Kaspa literal (fusionador cobra) |
|---:|---:|---:|---:|
| 0,10 | 0,319 | 0,976 | 0,996 |
| 0,25 | 0,996 | 0,999 | **1,498** |
| 0,33 | **1,160** | **0,996** | **2,029** |
| 0,35 | **1,271** | **0,997** | 2,069 |
| 0,40 | **1,548** | **0,988** | **2,792** |

`S1_h = 1,0000` exacto en toda fila. **S1 quita el premio y también el castigo** (a `α = 0,10` parasitar pasa de
costar el 68 % del ingreso a ser gratis): el ataque sigue existiendo, `δ` sigue igual; lo que desaparece es la
razón económica para hacerlo y la reversión de transacciones honestas.

## 3 · El retarget (C.8) — el beneficio mayor, que yo mencioné de pasada

| `α` | inflación contando azules (R-FIN-13 vigente) | **contando azules + `rojo_k`** |
|---:|---:|---:|
| 0,00 | 1,000 | 1,000 |
| 0,25 | 1,184 | 1,000 |
| 0,35 | 1,316 | 1,001 |
| 0,40 | **1,452** | **1,005** |

La inflación medida (×1,45) es del orden de la que `dag-poas-delta-real.md` derivó (×1,36 a `k = 30`). Con R-FIN-13′
esa nota deja de aplicar: `δ_real → δ` nominal (0,267 → 0,211), umbral de orden 40,0 → **41,7 %**, `r = 1` 42,3 →
**43,1 %**. Nota: esto es independiente del doble conteo que audita 9a; si 9a confirma, se suman.

## 4 · Lo que 9b deja abierto (declarado)

- **No midió parásita + copias a la vez** (en `MundoL9` cada evento lleva identidad única). Un atacante podría componer
  las dos; con R-FIN-8′ las copias no cobran ni cuentan, así que la composición solo añade plazas de mergeset.
- **Incentivo a fusionar:** con la coinbase propia nadie cobra por incluir a un rojo; Kaspa paga al fusionador por eso.
  R-FIN-12 adopta `pick_virtual_parents` como consenso, así que la inclusión no depende del incentivo — PLAUSIBLE, no
  medido. Variante mínima si hiciera falta: solo las **comisiones** del rojo al fusionador.
- **`mergeset_non_daa`:** Kaspa excluye del conteo y del subsidio los bloques con `blue_score` por debajo de la
  ventana; R-FIN-13 define su ventana por índice de PoT y no dice qué pasa con un fusionado cuyo `slot` cae fuera.
- `r8c_gd.py` no implementa `check_bounded_merge_depth`; la construcción de §1 supone `m ≤ merge_depth` (holgado).
- Errores propios de 9b, nueve, entre ellos aceptar el encuadre del encargo («semántica de Kaspa») media hora antes
  de comprobarlo en `coinbase.rs:131`. **El encuadre era mío.**

## 5 · Texto que va a la propuesta (de 9b, §E.2-E.3; lo aplico cuando 9a y 9c terminen de leerla)

**R-FIN-8′:** dos causas de rojez, `rojo_k` (rojo por el k-cluster, billete único) y `rojo_U3` (copia). Cobran
azules y `rojo_k`, **su propia coinbase** sujeta a `C-EMIT-03` con su propio `H` (no el `red_reward` de Kaspa;
`C-HDR-08` y `C-EMIT-03` no se tocan); `rojo_U3` no cobra nada y su cuerpo es inerte. Se aplican las transacciones
de azules y `rojo_k` en el orden de consenso de Kaspa (mergeset por `blue_work` ascendente, desempate por
`solution_distance` y hash, azules y `rojo_k` entrelazados); conflicto = descarte silencioso, gana el primero del
orden; cada bloque se aplica una sola vez, en el primer bloque de cadena que lo fusiona. Sin cláusula de
profundidad (fuera de `merge_depth` el fusionador es inválido; el rojo kosherizado cobra). Inválido ≠ rojo.
`COINBASE_MATURITY` desde el bloque de cadena que fusionó. Por qué solo el dueño puede producir un `rojo_U3`: dos
firmas Ed25519 sobre dos `pre_hash` con la misma `public_key` (`C-HDR-03/04`).
**R-FIN-13′:** `N_obs` cuenta exactamente los bloques que cobran por R-FIN-8′: **un bloque por identidad** (azules
+ `rojo_k`); las copias no cuentan.

## 6 · Efecto sobre las decisiones

P1 **sí, corregida**: es una regla (dos, con la enmienda), no toca `C-EMIT-03` ni `C-HDR-08`, cierra la rentabilidad,
la reversión y la inflación del retarget, y regala 1,7 puntos de umbral de orden. Lo que no hace es quitar el `δ`:
eso es lo que decide 9a.
