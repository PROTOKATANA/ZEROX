# Bitácora de la sesión 2026-09-08 — DAG sobre PoST: de «¿sobrevive la ronda 7?» a un diseño con frontera del 46,9 %

**Para quien retome esto en una sesión nueva.** Este documento recoge **todo** lo que se descubrió, decidió y dejó
pendiente el 2026-09-08 (madrugada en modo autónomo, mañana y tarde con Katana). Cada afirmación remite al fichero
que la sostiene. Los informes de los agentes están íntegros en `research/scripts/<ronda>/informe.md`; las
verificaciones del agente principal en `research/dag-poas-ancla-de-orden-auditoria-{3..7,8a,8b,8c}.md`; el diseño
vivo en `research/dag-poas-ancla-de-orden.md`. Commits del día en ZEROX: 93 (rama `rediseno/v1-spec-first`, sin push).

---

## 0 · Resumen ejecutivo

1. **El DAG sobre PoST está vivo y tiene, por primera vez, reglas completas (R-FIN-1..14), constantes casi todas
   fijadas, una frontera de seguridad calculada y verificada, y contramedida escrita para cada ataque encontrado.**
2. **Frontera de flujo único contra un atacante de espacio: 46,9 %** (unión a 10 años `< 10⁻¹⁰`, Skellam con `3k`,
   `F = 19 080 s`), reproducida por tres implementaciones. Las rondas 3-8 y D8 daban 36,5-40,8 % porque **contaban
   dos veces el `α` del atacante** (9a). Umbral operativo publicado: **33 %** (decidido por Katana).
3. **La única condición es `Δ`** (retardo honesto↔honesto efectivo): con 4 s el colchón es 13,9 puntos; con 16 s,
   5,3; con **20 s el 33 % ya no aguanta** (32,4 %). `Δ` no está medido y solo se mide con nodos corriendo.
4. **Los dos ataques de D8 tienen contramedida a nivel de regla:** la cadena parásita deja de rentar con R-FIN-8′
   (+ R-FIN-13′), y el soborno del ancla deja de valer nada con R-FIN-14 (reto por slot desde el PoT secuencial:
   con `ρ ≤ 1` el steering es 0; con `ρ = 1,5`, 68 slots tras días de *bootstrap*).
5. **La economía se arregla por R-FIN-14:** `I` deja de escalar como `1/g²`; `I + F` baja de 8,26 h a 0,76-1,31 h y
   el margen frente a un plotter 10× sube de 0,50× a 3,1-5,4×. **Queda por decidir `ρ_max` y `F`** (palanca P3).
   *(Línea base corregida en §11: el «antes» es 6,14 h / 0,67×, no 8,26 h / 0,50×.)*
6. **Coste del PoT medido:** `verify` 96,1 ms/slot, `prove` 1,561 s/slot (9950X3D). Esta máquina no hace 1 s/slot.

---

## 1 · Cronología de agentes (todos en Opus 5), veredictos y verificación

| Ronda | Dir / auditoría | Pregunta | Veredicto (verificado por el principal) |
|---|---|---|---|
| **D9-c** (madrugada) | `d9-ronda8c/` · `auditoria-3.md` | Mi ancla por posición de cadena | **REFUTADA** (contador de saltos, `m` gratis 4,5-5,25). Aplicado: ancla `blue_score`, U3″ dinámica, R-FIN-12 completa |
| **D9-d** | `d9-ronda8d/` · `auditoria-4.md` | Ancla `blue_score` | Grindable pero la mejor; Lema 9 sobrevive a U3″; `S_max = 150`; R-FIN-7 reescrita; `shuffle` |
| **D9-e** | `d9-ronda8e/` · `auditoria-5.md` | Peso real `Σ w(SR)` | No cambia nada; Lema E1 (deriva del retarget se cancela); `altura := blue_work`; `slot` = índice de PoT; `m` sin cota conocida |
| **D9-f** | `d9-ronda8f/` · `auditoria-6.md` | ¿Cota de `m`? | `F ∝ ln m`; **cuarta ancla por `slot`**: `m ≤ 1 + λ·S_max`, medido `m = 2,54`; B0: escalas de `slot` incompatibles |
| Bench PoT | `6edb903` | Coste de `verify` | 96,1 ms/slot; `prove` 1,561 s/slot (200 032 000 it., avx512f+vaes) |
| **D8** (relanzado 09:56; el primero murió por cuota) | `d8-ronda8/` · `auditoria-7.md` | Diseño completo con constantes | **Cadena parásita** (`δ(0,35) = 0,307`; rentable desde 0,33; umbrales 37,1/36,7 %), **soborno** `m = b+1`, economía 0,67× → 0,50×, `S_max` como arma de censura (20 s → 71-75 % inválidos), `m = 2,955` con retención. Sin vector: dos vistas, cruce en régimen, `3k`, `shuffle`. Todo reproducido idéntico |
| **9a** (relanzado tras cuota; continuó desde disco) | `d9-ronda9a/` · `auditoria-8a.md` | ¿Doble conteo del `α`? | **CORRECTO.** Frontera 46,88 % (`δ = 0`); teorema de la ráfaga (`R < A ⟺ gana`); el contraejemplo del propio Lema 9 no es realizable; parásito ajeno = granjero apagado; **`Δ` decide** (20 s → 32,4 %). 8 scripts reproducidos idénticos |
| **9b** | `d9-ronda9b/` · `auditoria-8b.md` | Palanca P1 (R-FIN-8) | Mi premisa **falsa** (copias rojas válidas: ×15); Kaspa paga al fusionador (duplica la parásita). Correcto: **R-FIN-8′** (`rojo_k` cobra su coinbase; `rojo_U3` inerte) + **R-FIN-13′**. Parásita 1,16-1,55 → 0,99; retarget ×1,45 → ×1,005; orden 40,0 → 41,7 %. 3 scripts idénticos |
| **9c** | `d9-ronda9c/` · `auditoria-8c.md` | Palanca P4 (reto por slot) | **LAGUNA** (reto por slot no escrito); Autonomys secuencial (verificado); **`W_dec ≤ 45 s`**, no depende de `S_max`; `ρ ≤ 1 ⇒` steering 0; **R-FIN-14**; `I+F` 8,26 h → 0,76-1,31 h; `F = max(F_carrera, I/(W/κ−1))`; `I ≥ ρ_max·W_dec`; opción de revelación retardada. c0/d1/e1 y **c4/d2 reproducidos idénticos** por el principal (c4: 33 min) |

---

## 2 · Descubrimientos, con etiqueta

1. **Ancla por índice de PoT** (D9-f): `I_j` = bloque de la cadena seleccionada con menor `blue_work` entre `slot ≥ T_j`;
   `m ≤ 1 + λ·S_max` por construcción; Prop. 7 la cubre (Lema A4-slot). VERIFICADO.
2. **Variante (A″)**: `λ = 1/s`, `τ = 1 s`, R-FIN-1a no estricta (`≤`): 0 violaciones; los 24-29 % de D9-f eran empates
   (`verif_a2prima.py`). VERIFICADO. Decidido por Katana.
3. **Cadena parásita** (D8; modelo cerrado mío en `verif_parasita.py`): la regla k-cluster regala `k` azules honestos de
   ventaja; `J* = kα/(1−2α)`; `δ_ráfaga(J*) = α/(1−α)`; legal, invisible para R-FIN-7. DEMOSTRADO el mecanismo,
   VERIFICADO el `δ`. Composición con el retarget: +0,011 (segundo orden), `verif_composicion_parasita.py`.
4. **Soborno del ancla** (D8): `m = b+1` con `b` retenciones compradas, incluso con `α = 0`. VERIFICADO.
5. **`S_max` como arma de censura** (D8 A3, instrumentado por mí): con `S_max = 20 s` un granjero con 20 s de retraso
   pierde 71-77 % de sus bloques como **inválidos**. `S_max = 150 s` es la única elección segura en red. VERIFICADO.
6. **Doble conteo** (mío, confirmado por 9a): `(1−α)(1−δ)λ` nunca fue el denominador de la carrera (paper L1034-1036:
   `w_H` es el score del bloque virtual honesto e incluye los azules del atacante). Frontera **46,9 %** contra espacio.
   DEMOSTRADO + VERIFICADO (tres implementaciones con controles que reproducen 36,5 y 40,8 %).
7. **`Δ` decide** (9a): `δ₀` natural 0,0000 a 4 s; frontera 38,3 % a 16 s, 32,4 % a 20 s. Un atacante de red sube
   `Δ_ef` sin espacio. VERIFICADO; `Δ` real = LAGUNA.
8. **Copias rojas válidas** (9b): U3″ manda las copias a `mergeset_reds`; pagar rojos sin distinguir = ×15. DEMOSTRADO
   (construcción). Kaspa: el rojo no cobra, cobra el fusionador (`coinbase.rs:121-131`), y eso duplica la parásita.
9. **R-FIN-8′ + R-FIN-13′** (9b): cierran rentabilidad (0,99), reversión (`S1_h = 1,0000`) e inflación del retarget
   (×1,005); `dag-poas-delta-real.md` deja de aplicar (orden 40,0 → 41,7 %). VERIFICADO. **P1 es precondición del 46,9 %.**
10. **Reto por slot no definido** (9c): R-FIN-3 hace el `flujo` constante en la época. LAGUNA cerrada con R-FIN-14.
11. **Autonomys es secuencial** (9c, citas verificadas por mí): `seed_with_entropy` → AES^N → `blake3(pot)` →
    `blake3(rand ‖ slot)`. Lookahead real de Autonomys ≈ 615 s, no 11 s. VERIFICADO.
12. **`W_dec ≤ 45 s`** (9c): la ventana de decisión del ancla la cierra la carrera, no `S_max`; el menú vive en los
    primeros 10-20 s. VERIFICADO (c4 reproducido idéntico por el principal, 33 min).
13. **`ρ ≤ 1 ⇒` steering 0** (9c E1, rehecho por mí): evaluar un candidato exige `pot_out(t_j − 1)`, `L` por delante.
    DEMOSTRADO. Con `ρ > 1`, *bootstrap* de días y `n_eval = ρ·W_dec`.
14. **P4 compra precio, no `α_ef`** (9c D): `I = c_m·√(n_eval/(αλ))/g`; `I+F` 8,26 h → 0,76-1,31 h; margen 0,50× → 3,1-5,4×
    (línea base corregida en §11: 6,14 h / 0,67×).
    Y `F = max(F_carrera, I/(W/κ−1))`; restricción `I ≥ ρ_max·W_dec`. VERIFICADO (d1/d2).
15. **Revelación retardada por VDF** (9c E5; la ronda 7 la descartó): `entropía_j = VDF(chunk ‖ pot_out, L·iter)`
    revelada en `t_j` ⇒ la cadena común no es calculable más allá de `I`; como `L > I`, evaluación 0 para cualquier `ρ`.
    Coste: un VDF más por época (≈ 5 en vuelo), verificación no sucinta (~1/16 del cómputo), una pieza más de consenso.
    **PLAUSIBLE, no medido. Anotada como OPCIÓN, no núcleo** (R-FIN-14 (h)). Katana pidió dejarlo escrito.
16. **Artefacto de instrumento** (9c): `r8c_sim.py`/`d8_lib.py` permiten retener un bloque y publicar un hijo suyo; las
    `m` con retención (D8 A4.2: 2,82-2,96; D9-f: 3,64) pueden estar infladas. LAGUNA, sin cuantificar.
17. **Coste del PoT**: `verify` 96,1 ms/slot ⇒ 9,6 % de un núcleo continuo a `τ = 1 s`; `prove` 1,561 s/slot en un
    9950X3D ⇒ el timekeeper necesita clase 14900KS o menos iteraciones. MEDIDO. LAGUNA: coste por slot vs por bloque
    en `C-NET-03/04` (con `PotCheckpoints` cacheados es por slot).
18. **Eclipse instrumentado** (mío): los bloques válidos de un granjero eclipsado son los que encadena sobre su propio
    bloque anterior (< ~7 s); en régimen 77 % inválidos a 200 s/150 s (D8 publicó 68 %, conservador).

---

## 3 · Decisiones de Katana (todas del 2026-09-08 salvo `q = 1`, anterior)

| Decisión | Estado |
|---|---|
| `q = 1` (cliente ligero con servidor de confianza) | DECIDIDA (antes) |
| Rama (A) → variante **(A″)**: `λ = 1/s`, `τ = 1 s`, R-FIN-1a `≤` | DECIDIDA (`af76527`) |
| **`S_max = 150 s`** | DECIDIDA; confirmada por D8 (red) y 9c (`W_dec` no depende de ella) |
| `F`: publicar medido y garantizado, diseñar con el medido | DECIDIDA; **corregida**: el «68,5 h garantizado» no es garantía de seguridad (0,49× hoy); `F` se recalibra (P3) |
| Umbral publicado 35 % → **33 %** | DECIDIDA (adoptó mi recomendación tras D8); con 9a tiene 13,9 puntos de colchón a `Δ = 4 s` |
| Orden tras D8: **P1 + P2 ahora, verificar P4, después P3**; una pregunta a D9 (doble conteo) | DECIDIDA; ejecutada: 9a/9b/9c en paralelo (Katana levantó el «uno en uno») |
| Revelación retardada por VDF | **Anotada como opción** (R-FIN-14 (h)); sin decidir |
| Palanca P3 (`ρ_max`, `F`) | **PENDIENTE de Katana** (§6.1) |

---

## 4 · Reglas escritas hoy (texto íntegro en `dag-poas-ancla-de-orden.md` §2)

- **R-FIN-8′** (sustituye a R-FIN-8): `rojo_k` cobra su propia coinbase y aplica sus transacciones en el orden de
  consenso de Kaspa (conflicto = descarte silencioso); `rojo_U3` (copia) inerte; sin `red_reward` de Kaspa; sin
  cláusula de profundidad; inválido ≠ rojo; madurez desde el bloque de cadena que fusiona.
- **R-FIN-13′**: el retarget cuenta exactamente lo que cobra (un bloque por identidad).
- **R-FIN-14**: cadena de PoT secuencial por flujo; `reto(f, s) = blake3(blake3(salida(f, s)) ‖ LE64(s))`; validez
  por `sector_slot_challenge`/`solution_distance`; justificación por `PotCheckpoints` acotada a `S_max`; **prohibido**
  todo reto que permita saltar slots; `I ≥ ρ_max·W_dec`; `t_j` distintos; **(h) opción de revelación retardada**.
- Línea de constantes actualizada: umbral 33 %, frontera 46,9 % condicionada a `Δ`, `I`/`F` pendientes.

## 5 · Estado de las constantes

`k = 30` (calibrado a `Δ = 4 s`; aguanta hasta ~16 s) · `q = 1` · `τ = 1 s` · `S_max = 150 s` · `W_RETARGET ≥ 3 083`,
`γ ≤ 0,25` · `max_block_parents = 15`, `mergeset_size_limit = 180` · umbral operativo **33 %** · `W/κ = 1,22` ·
**`I`, `F`: pendientes** (candidatos en `auditoria-8c.md` §3) · **`Δ`: sin medir.**

---

## 6 · Pendientes, en orden

1. **Palanca P3 — bifurcación de Katana.** Elegir `ρ_max` y `F`:

   | Opción | `I` | `F` | `I+F` | Margen B 10× | Qué se paga |
   |---|---:|---:|---:|---:|---|
   | `ρ_max = 1` (`n_eval = 45`) | 491 s | max(0,62 h, `F_carrera`) | 0,76 h | 5,4× | Supone que nadie tiene AES más rápido que el timekeeper |
   | **`ρ_max = 1,5`** (`n_eval = 68`) | 602 s | max(0,76 h, `F_carrera`) | 0,93 h | 4,4× | Margen contra silicio mejor; **recomendación del principal** |
   | `ρ_max = 3` (`n_eval = 135`) | 851 s | max(1,07 h, `F_carrera`) | 1,31 h | 3,1× | Paranoico; `ρ ≥ 3` no existe hoy |
   | Revelación retardada | libre | `F_carrera` | mínimo | máximo | Un VDF más, verificación no sucinta |

   `F_carrera`: 0,34 h a `α = 0,35` con el modelo de 9a (`δ = 0`); 1,85 h con el `δ` pesimista de D8. Recomendación:
   **`ρ_max = 1,5`, `I = 600 s`, `F = 1 h`** (≥ max(0,76; 0,34) con margen; si se prefiere el pesimista, `F = 2 h`),
   lookahead 1,2-2,2 h, margen 3,5×/1,9×. Escribirlo en la propuesta cuando Katana decida.
2. **Medir `Δ`.** Requiere `zx-node` con el DAG implementado: decenas de instancias con latencias inyectadas, carga
   y atacante de red; cola (p99), no media. Es la primera medición que el diseño necesita.
3. ~~Reproducir `r9c_c4`/`r9c_d2`~~ **Hecho tras el cierre: idénticos** (c3 difiere porque diagnosticaba el instrumento antes de corregirlo).
4. **Cuantificar el artefacto de retención** (descubrimiento 16) sobre D8 A4.2 y D9-f: añadir la clausura de
   publicación de `r9c_lib.py` a `r8c_sim.py`/`d8_lib.py` y re-medir `m` con retención.
5. **Ronda adversarial contra el diseño corregido** (R-FIN-8′/13′/14 + 33 % + constantes P3): nadie ha atacado las
   correcciones juntas.
6. Lagunas menores: atacante de red (eclipse) no modelado; régimen `> 15` puntas (`shuffle`); `mergeset_non_daa` en
   R-FIN-13′; incentivo a fusionar rojos (coinbase propia: nadie cobra por incluir); coste de PoT por slot vs por
   bloque en `C-NET-03/04`; parásita + copias a la vez (9b no lo midió).
7. **Cierre de P-038**: recomendación del principal, «viable con costes declarados, condicionada a `Δ`».

---

## 7 · Errores del agente principal en esta sesión (declarados en su momento)

Sobreafirmar que la cadena seleccionada no tenía teorema (→ ancla en el orden, rota por D9-b); «menú 14» artefacto de
renombrado; `m = 1,3-2,0` medido contra un atacante retardado; «`m` sin cota ⇒ constantes sin dimensionar» (es `F ∝ ln m`);
recomendar `c = 16`; 13,2 % con factor de cadena lineal; «decide P-038 en los dos sentidos» (falso); un `print` que
afirmaba «<1e-6» sin calcular; `nan` en `verif_tau_vs_lambda.py`; editar un fichero que D9-c leía; matar el bench con mi
propio `timeout`; **P1 mal escrita** («cada billete paga una vez», «semántica de Kaspa»); **P4 mal enunciada** (fila
`ρ = 1`, atribuir la ventana a `S_max`, decir que baja `α_ef`); **contar dos veces el `α`** en la auditoría 7 (heredado
de las rondas 3-8, corregido por mí y confirmado por 9a).

## 8 · Método vigente para agentes (todo en `dag-modo-autonomo.md` y en los encargos)

Criterio `α` · contadores de cobertura de rama · ≥ 12 semillas · control positivo antes de medir · `AUDITA_SCRIPTS.py`
declarado y cada marca leída · cinco etiquetas · citas con fichero y línea · volcado incremental + commit por punto
solo en su directorio · nada en `/tmp` · errores propios declarados · adversario del paper sin retardo · cota ≠ realidad
· el principal reproduce cada número que decide algo antes de transcribirlo.

## 9 · Rutas

Fuentes: `research/fuentes/{bdk19,phantom-ghostdag}.{pdf,txt}`; Kaspa `/home/katana/zeo/fuentes/rusty-kaspa` @
`c338d495`; Autonomys `/home/katana/zeo/fuentes/subspace` @ `f8842d0`. Scripts del principal: `research/scripts/verif_*.py`,
`AUDITA_SCRIPTS.py`. Agentes: `research/scripts/{d9-ronda8c..f, d8-ronda8, d9-ronda9a..c}/`. Vault: P-038 entradas
1-20 en `NODOS/ZEROX/PREGUNTAS-PARA-KATANA.md`; `PROGRESO.md` (entrada del día). Memoria: `dag-estado-handoff-2026-09-08.md`.

## 10 · Cómo retomar

Leer §0, §5 y §6 de este documento; luego `dag-poas-ancla-de-orden.md` §2 (reglas y constantes) y las auditorías 8a/8b/8c.
Primer trabajo: la decisión P3 de Katana (§6.1). Después, la ronda adversarial
contra el diseño corregido. `Δ` espera al nodo.

---

## 11 · Addendum, noche del 2026-09-08 (sesión nueva tras el /clear)

1. **Retractación de D8 (A4d), integrada.** `d8-ronda8/d8_a4d_correccion.py` y `salida_a4d.txt` (escritos a las 21:17,
   tras el cierre; reproducidos idénticos por el principal): «`m = 2,955` obliga a subir `I` y `F`» comparaba una `m`
   medida a `α = 0,40` con una `I` a `α = 0,10`. Con la pareja consistente, el peor caso sigue siendo la `m = 2,548` del
   diseño: **lookahead 6,14 h, margen 0,67×** (no 8,26 h / 0,50×). Corregido en `auditoria-8c.md` §3 y en la nota de
   palancas. La tabla de P3 no cambia.
2. **Decisiones de Katana:**
   - **P-038 sigue abierta**: «aún no cerramos, seguimos afinando».
   - **`F = 2 h` provisional**, a bajar a **1 h** cuando el diseño corregido sobreviva a su ronda adversarial. **Anotado
     como obligación: `F` se baja en producción** — cuanto más corta, mejor para el usuario y contra el plotter rápido.
     Tarea nueva: **investigar cómo acortar `F`** (palancas conocidas: `F = max(F_carrera, I/(W/κ−1))` ⇒ revelación
     retardada (`n_eval = 0` ⇒ `F = F_carrera ≈ 0,34 h` con el modelo de 9a), `W/κ`, `k`, `Δ`).
   - **`ρ_max`: pendiente.** Katana entre «admitir 3×» y «segundo VDF» (revelación retardada). Sus dos preguntas, con
     fuente en `research/pot-aes-asic-chacha.md`: un reloj 19× para AES **no es alcanzable ni por un Estado** (exige
     ~25 ps por ronda AES; la instrucción `AESENC` ya es hardware a 3 ciclos y 6,2 GHz; Autonomys/Supranational: «no
     significant speedup … even with an ASIC»); **sustituir AES por (X)ChaCha20(-Poly1305) empeora el reloj**, porque
     ChaCha no tiene instrucción de hardware en las CPU y el hueco CPU↔ASIC crece; la «seguridad» de ChaCha en los
     artículos citados es de cifrado AEAD (nonces, canales laterales) y no aplica a un PoT cuya semilla es pública.
3. **Cabecera de P-038 en el vault actualizada** (decía «ancla por corregir», de la ronda 7).
4. **La frontera SÍ depende de `F` — medido** (`research/scripts/verif_frontera_vs_F.py`, instrumento de 9a sin tocar,
   control reproduce 46,8784 % / 36,5431 %). Katana preguntó si acortar `F` es «mejor para la seguridad»: lo es contra el
   *sembrador* (plotter rápido: lookahead `I+F` más corto) y **peor contra el *corredor*** (carrera de bloques dentro de `F`):

   | `F` | `I` | frontera `δ = 0` (9a) | frontera `δ` D8 (pesimista) | unión 10 años a 33 %, `δ = 0` / `δ` D8 |
   |---:|---:|---:|---:|---|
   | 5,3 h | 4 200 s | 46,88 % | 36,54 % | 3,8e-211 / 2,1e-103 |
   | **2 h** | 851 s | **44,57 %** | **35,08 %** | 1,4e-169 / 3,1e-32 |
   | 1,07 h | 851 s | 42,28 % | 33,29 % | 5,0e-83 / 1,7e-12 |
   | 0,34 h | 851 s | 34,81 % | **28,74 %** | 8,7e-16 / **1,0** |

   `F_carrera` (unión 10 años = 1e-10, `I = 851 s`): 33 % → 0,28 h (`δ=0`) / 0,99 h (`δ` D8); 35 % → 0,35 h / 1,92 h.
   **Consecuencia:** el suelo de `F` lo pone el corredor, no el steering. Con `F = 2 h` el 33 % conserva 11,6 puntos
   (`δ=0`) y 2,1 puntos (pesimista); con 20 min el 33 % **cae** en el modelo pesimista. La revelación retardada quita el
   plazo del steering pero no puede bajar `F` por debajo de `F_carrera`; «F corta» tiene un suelo de ~1 h si se quiere
   colchón en el modelo pesimista, ~0,3 h si solo se cree el verificado. Todo a `Δ = 4 s` (`k = 30`).


