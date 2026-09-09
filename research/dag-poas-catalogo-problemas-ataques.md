# Catálogo de problemas y ataques de la propuesta vigente — PoST + DAG, ancla por índice de PoT, R-FIN-1..14

**2026-09-09, madrugada.** Lista completa de lo que la propuesta `research/dag-poas-ancla-de-orden.md` (§2, con R-FIN-8′,
13′ y 14; umbral 33 %; `F = 2 h` provisional) presenta como problema, ataque, coste o laguna, con su estado. Compilada de
las auditorías 3..8c, la bitácora del 2026-09-08 §2/§6, los informes de la ronda 10 (10a y 10b verificados por el
principal en sus scripts decisivos; **10c verificado**), `pot-aes-asic-chacha.md`, `dag-poas-mitigaciones-cuatro-riesgos.md`
y `timelord-redundancia-informe.md`.

**Estados.** CERRADO: regla escrita y verificada que lo neutraliza. ACOTADO: existe, tiene número y se acepta como
precio. ABIERTO: sin contramedida en el diseño. LAGUNA: no medido o no modelado. ESTRUCTURAL: coste que ningún
parámetro arregla. DECISIÓN: depende de una elección pendiente de Katana.

---

## A · Ataques con espacio (contra el consenso)

| # | Ataque | Qué hace el atacante | Número que lo acota | Estado | Fuente |
|---|---|---|---|---|---|
| A1 | **Carrera de bloques (flujo privado)** | Con `α` del espacio construye una historia rival y la publica dentro de `F` | Frontera 46,9 % (`Δ = 4 s`, `F = 5,3 h`); 44,6 % con `F = 2 h`; 35,1 % en el modelo pesimista. Umbral operativo 33 % con 2,1 puntos de colchón en el peor modelo | **ACOTADO** | 9a; `verif_frontera_vs_F.py`; 10b C |
| A2 | **Cadena parásita** | Ráfagas de `J* = kα/(1−2α)` bloques que tiñen de rojo `δ = α/(1−α)` de los honestos; legal e invisible para R-FIN-7 | Rentabilidad 1,16-1,55 → **0,99**; reversiones 64-142 s → 0; retarget ×1,45 → ×1,005. El `δ` no entra en la carrera (doble conteo) | **CERRADO** en lo económico (R-FIN-8′/13′); residuo ACOTADO | D8 A1; 9a; 9b |
| A3 | **Steering del ancla** | Elegir entre sus candidatos a `I_j` el que le da más victorias en la época | 0 con `ρ ≤ 1` (R-FIN-14); con `ρ > 1`, `n_eval = ρ·W_dec` tras bootstrap; con (h), ÷279 hasta `ρ* ≈ 1 + L/I` | **ACOTADO**, condicionado a `ρ_max` (E6) | 9c; 10a B.1 |
| A4 | **Soborno del ancla** | Compra retenciones ajenas: `m = b + 1` candidatos, incluso con `α = 0` | Con `ρ ≤ 1` tener más candidatos no compra nada (no puede evaluarlos) | **ACOTADO**; el porte del soborno de BDK a PoAS con coste de oportunidad de R-FIN-8′ es **LAGUNA** | D8 A5; 10c B.5 |
| A5 | **Sembrador (plotter rápido)** | Conoce retos por adelantado y siembra discos solo para ganarlos | Lookahead honesto **0**; atacante `(F − W_dec) + I(1 − 1/ρ)` si `ρ > 1`, 0 si `ρ ≤ 1`. Margen frente a plotter 10×: 1,9× (`F = 2 h`), 3,6× (`F = 1 h`); con (h) 2,8-5,5× | **ACOTADO**, condicionado a `ρ_max`; palanca `L` desatada de `F` (F1) | 10c A (verificado) |
| A6 | **Copias de billete** (misma identidad, varios bloques) | Inflar recompensa o espacio con el mismo billete | Sin cláusula: ×15 (699 copias rojas por 51 billetes). Con U3″ + `rojo_U3` inerte: 1 azul por identidad | **CERRADO** (R-FIN-11, R-FIN-8′) | D9-c; D9-d; 9b |
| A7 | **Timewarp / grinding del retarget** | Falsificar sellos para mover `solution_range` | `slot` = índice de PoT, no sello; deriva se cancela (Lema E1); un bloque por identidad en `N_obs` | **CERRADO** (R-FIN-13/13′) | D9-e; 9b |
| A8 | **Ráfagas planificadas con adelanto** | Con `ρ > 1` conoce retos antes y planifica retenciones | Una carrera por segundo durante 10 años: −0,46 puntos; caso real < 0,08 | **ACOTADO**; retención selectiva con oráculo propio: **LAGUNA** | 10a B.6 |
| A9 | **Griefing del mergeset** (`MergeSetTooBig`) | Forzar a honestos a fusionar demasiado | `pick_virtual_parents` con presupuesto: un honesto nunca lo emite; `shuffle` obligatorio | **CERRADO** (R-FIN-12); régimen > 15 puntas **LAGUNA** | D9-c A4/A5; D9-d A3 |
| A10 | **Grinding por hash** en desempates | Reintentar hasta ganar el desempate | Desempate por `solution_distance`, nunca por hash | **CERRADO** | ronda 7; R-FIN-6 |
| A11 | **Publicación parcial / reparto parasitar-correr** | Mezclar parásita y carrera para mejorar `δ` o la ventaja | `δ` cae al retener (0,31 → 0,10); `adv_max ≤ 43 < 3k`; teorema de la ráfaga `R < A` | **REFUTADO** como mejora | 9a L3/L4 |
| A12 | **Parásito racional ajeno** (tercero que parasita por dinero) | Un tercero resta frontera al atacante principal | Sin R-FIN-8′: 42/37/31 % con `α_p` = 10/20/33 %. Con R-FIN-8′ no es racional (0,99) | **CERRADO** (precondición del 46,9 %) | 9a L5.2-5.3 |

## B · Ataques de red (sin espacio)

| # | Ataque | Qué hace | Número | Estado | Fuente |
|---|---|---|---|---|---|
| B1 | **Retraso adversarial `Δ_ef`** | Retrasa la propagación entre honestos (inundación, eclipse parcial) | Frontera 38,3 % a 16 s, **32,4 % a 20 s**; `F` no compra `Δ` (1 h → 2 h = 1,9 s); techo duro `Δ ≈ 22,7 s` | **ABIERTO** en consenso; mitigable en red (M1-M6) | 9a §5.5; 10b B.5; mitigaciones §1 |
| B2 | **Eclipse** (aislamiento de un nodo) | Controla todas las conexiones de la víctima | Víctima con 200 s de retraso: **77 %** de sus bloques inválidos; doble gasto contra comerciante eclipsado | **ABIERTO** en el SPEC (solo C-NET-14/20); sensores E1/E2 y tabla de Bitcoin Core propuestos | D8 A3; mitigaciones §2 |
| B3 | **`S_max` como censura** | Un granjero con retraso pierde bloques por R-FIN-1a | `S_max = 20 s`: 71-77 % inválidos; `S_max = 150 s`: ~0 | **ACOTADO** (decidido 150 s) | D8 A3; D9-d |
| B4 | **DoS de verificación del PoT** | Cabeceras con slot adelantado que fuercen verificaciones | Asimetría `prove/verify` 16,2× (32,4× en orden aleatorio); cabeceras adelantadas se retienen | **ACOTADO**; `C-NET-03/04` por slot y no por bloque: **LAGUNA de redacción** | bench PoT; 10a B.2 |
| B5 | **Inundación de revelaciones falsas** (solo con (h)) | Saturar verificadores del segundo VDF | Verificar una por época y en orden aleatorio; Autonomys ya lo hace (`EXPECTED_POT_VERIFICATION_SPEEDUP = 7`) | **REFUTADO** como ataque (si (h.2c)) | 10a B.2 |
| B6 | **Partición de red** | La red se parte más de `F` | Split permanente entre flujos más allá de `F`; hasta `F` tolera si el lado conserva ≥ 9 % del espacio (`S_max = 150`) | **ACOTADO** (R-FIN-7 reescrita) | D9-d A4 |

## C · Vivacidad y operación

| # | Problema | Qué pasa | Número | Estado | Fuente |
|---|---|---|---|---|---|
| C1 | **Timekeeper único** | Sin timekeeper no hay slots: la red se para | Autonomys no arranca secundarios automáticamente (TODO en `source.rs:291`) | **ABIERTO**; B7 propone redundancia operativa (C-TIMELORD-01..03) | `timelord-redundancia-informe.md` |
| C2 | **Timekeeper más lento que 1 slot/s** | Esta máquina hace 1,56 s/slot | Hace falta clase 14900KS (`AESENC` 3 ciclos a 6,2 GHz) o menos iteraciones | **LAGUNA operativa** | bench; `pot-aes-asic-chacha.md` §2 |
| C3 | **Centralización del rol de timekeeper** | El más rápido deja obsoletos a los demás | `autonomys/subspace#2141`, cerrada *not planned*: «no conocemos mitigación» | **ESTRUCTURAL** | mitigaciones §1.2 |
| C4 | **Lado de partición sin hardware** (solo con (h)) | Un lado sin `q+1` líneas de AES no produce bloques válidos aunque tenga espacio | Con 4 núcleos y `q+1 = 10`: revelación 3 h tarde con `F = 2 h`; a `ρ_max = 2,5`, `q+1 = 3` | **ABIERTO si se adopta (h)**; se calibra | 10a B.4 |
| C5 | **Recalibración de iteraciones** (R-FIN-9) | Cambiar `slot_iterations` a mitad de época | Se lee de `c·j` y se aplica en `t_j`; con (h), `N` congelado en `slot(I_j)` | **ACOTADO** | D9-e; 10a (h.5) |
| C6 | **Ventana de reto predecible si la revelación llega tarde** (solo con (h)) | El timekeeper se retrasa `d` s | La regla «continuidad por defecto» **rompía R-FIN-5** y se retiró; con (h.3′) la entropía se calcula, no se espera | **CERRADO** por (h.3′) | 10a A.3 |

## D · Costes estructurales (ningún parámetro los arregla)

| # | Coste | Número | Estado | Fuente |
|---|---|---|---|---|
| D1 | **Sin cliente ligero SPV** | GHOSTDAG no tiene SPV; 21,5 GB/año de cabeceras a `q = 1`; modelo Zcash con servidor (`zx-lightwalletd`) | **ESTRUCTURAL** (decidido `q = 1`) | propuesta §4.1, §6 |
| D2 | **Coinbases y UTXO** | 31,5 M salidas/año, ~1,3 GB/año | ESTRUCTURAL | propuesta §4.6 |
| D3 | **Poda** | Sin niveles de PoW; justificación de PoT 4 GB/año; podabilidad sin investigar (P-034) | **LAGUNA** | propuesta §4.9; DECISIONES §19 |
| D4 | **Verificación de PoT no sucinta** | 96,1 ms/slot = 9,6 % de un núcleo continuo; con (h) +0,15 a +0,81 núcleos según calibración | ESTRUCTURAL (elegido frente a C++/GMP) | bench; 10a C |
| D5 | **Umbral por debajo del 50 %** | 46,9 % teórico, 33 % publicado (Chia ~40 %, Bitcoin 50 %) | ESTRUCTURAL (familia PoST) | 9a |
| D6 | **Suelo de confirmación** | Ninguna confirmación posible antes de `≈ 3k/((1−α)λ) = 100-134 s`, con ninguna `F` | ESTRUCTURAL | 10c C (verificado) |
| D7 | **Barrera de hardware del timekeeper** | Clase 14900KS; con (h) ×`(q+1)` líneas | ESTRUCTURAL / DECISIÓN | 10a B.3 |
| D8 | **Tolerancia a particiones = `F`** (o `L` si se desata) | 2 h; 1 h si `L = 1 h` | ACOTADO / DECISIÓN | R-FIN-7; 10c E |
| D9 | **Previsión propia** | «Todo granjero conoce sus victorias `L` por adelantado» (§4.8) | **REFUTADO** bajo R-FIN-14: lookahead honesto 0 | 10c A (verificado) |

## E · Lagunas de teoría y de medida (lo no demostrado)

| # | Laguna | Qué falta | Cuánto mueve | Fuente |
|---|---|---|---|---|
| E1 | **`Δ` real** | Medir `Δ_p99` con nodos, carga, verificación de PoT y atacante de red | Todo: decide `k`, `F`, colchón. Solo se mide con `zx-node` | 9a; 10b |
| E2 | **Prop. 7 bajo U3″ + R-FIN-5 + R-FIN-8′** | Transferida al ancla por `slot` (Lema A4-slot, 13 110/13 110); la composición completa es PLAUSIBLE, no demostrada | La deuda teórica principal | propuesta §5.1; D9-e/f |
| E3 | **`c_a = c_h` en unidades de índice** | Rehacer BDK Lema 13 con el ancla nueva | 1,2 puntos | propuesta §5.2 |
| E4 | **Empalme conteo ⊗ peso** | Acotado por R-FIN-13 (`W_RETARGET ≥ 3 083`, `γ ≤ 0,25`): < 1 % | < 0,4 puntos | `dag-poas-empalme-peso.md`; D9-e |
| E5 | **`3k` como ventaja real** | Es cota; medido máx real 0,56·3k; diseñar con la medida no es legítimo | Palanca débil: 3,2 min de `F` | D8; 10b B.1 |
| E6 | **`ρ_max` real** | Estudio de Supranational no localizado; estimación propia 1,5-2,5×; ASIC de Chia 3,1-3,8× en otra primitiva | Decide (h) y su calibración | `pot-aes-asic-chacha.md` §5 |
| E7 | **`m` con retención posiblemente inflada** | Los simuladores de D8/D9-c..f permitían publicar un hijo de un bloque retenido | `m` 2,82-2,96 sospechosas; `W_dec` de 9c arrastra el aviso | 9c §2; 10a lagunas |
| E8 | **Resolución de `W_dec`** | Rejilla `{0, 10, 20, 45}` y tope de 10 candidatos | Desconocido | 8c |
| E9 | **Unidades de `W` y `κ` en un DAG** | Bloques del DAG vs bloques de cadena: razón ×5,2-5,8 | Cambia la lectura de la pinza | 10c B.5 |
| E10 | **Compresibilidad de las parcelas** | Compromiso tiempo-memoria real de las parcelas de Autonomys (lección de PoS 2.0 de Chia) | Precio del ataque A1 | `CLAUDE.md`; mitigaciones §3 |
| E11 | **Composición `δ₀(Δ)` + parásita a `Δ ≥ 16 s`** | El teorema de la ráfaga vale mientras `2Δλ ≪ k`; a 20 s `W_pub/H = 0,936` | Colchón a `Δ` alto | 9a; 10b laguna 2 |
| E12 | **Régimen > 15 puntas** (`shuffle`) | Nadie lo ha medido | Desconocido | D8 §5 |
| E13 | **Economía** | Precios supuestos; almacenamiento de ganadores 5,4e-4 del coste GPU a 3,2 PiB | Margen frente a `A*` | propuesta §5.6; `verif_almacen_ganadores.py` |
| E14 | **Parásita + copias a la vez** | 9b no lo midió | Desconocido | 9b |
| E15 | **Incentivo a fusionar rojos** | Con coinbase propia nadie cobra por incluir; pagar al fusionador duplica la parásita | Desconocido | 9b |
| E16 | **`mergeset_non_daa`** | Bloque fusionado con `slot` fuera de la ventana del retarget | Desconocido | 9b; R-FIN-13′ |
| E17 | **Recursión R-FIN-5/7 vs Propiedad 1** | Prop. 7 condicionada a la inducción: hueco L571 del paper | Dos umbrales (orden / flujo) | `dag-poas-recursion-flujos.md` |
| E18 | **Coste de PoT en `C-NET-03/04`** | Por slot vs por bloque | Recalibrar anti-DoS | propuesta; bitácora §2.17 |

## F · Decisiones abiertas (de Katana)

| # | Decisión | Opciones con número | Fuente |
|---|---|---|---|
| F1 | **`L` desatada de `F`** | `L = 1 h`, `F = 2 h`, `ρ_max = 3`: margen frente al sembrador 3,6×, `W/κ = 0,58` dentro de BDK, sin (h); coste: tolerancia a particiones 2 h → 1 h. PLAUSIBLE | 10c E (verificado) |
| F2 | **`ρ_max` y el segundo VDF (h)** | Sin (h): admitir 3× (`I = 851 s`, `F ≥ 0,69-1,07 h` por la pinza). Con (h): seis piezas de 10a; calibración barata (`I = 4 725 s`, 0,15 núcleos, `q+1 = 3`, lookahead 3,3 h) o cara (`I = 851 s`, 0,81 núcleos, `q+1 = 10`, 0,9 h) | 10a D; 10c D |
| F3 | **`F` de producción** | 1 h condicionada a `Δ_p99 ≤ 14,9 s`; a 1 h el 33 % conserva 0,05 puntos en el pesimista, 9 en el verificado; el usuario no gana nada en riesgo (`prev` no lleva `F`) | 10b C; 10c C |
| F4 | **`k` con margen** | 30 aguanta 16 s; 40-60 para 20-24 s a costa de cabeceras y `F_carrera`; es hard fork después | mitigaciones §1.2 M2 |
| F5 | **Cierre de P-038** | Sigue abierta por decisión de Katana («seguimos afinando») | vault P-038 entrada 21 |

---

## Recuento

| Estado | Cuántos |
|---|---|
| CERRADO por regla verificada | 8 (A2 económico, A6, A7, A9, A10, A12, C6, B5) |
| REFUTADO como mejora o ataque | 3 (A11, B5, D9) |
| ACOTADO con número | 12 |
| ABIERTO | 4 (B1, B2, C1, C4 si (h)) |
| ESTRUCTURAL | 7 |
| LAGUNA | 18 |
| DECISIÓN | 5 |

Los cuatro ABIERTOS son los que `dag-poas-mitigaciones-cuatro-riesgos.md` trata mecanismo a mecanismo. La laguna que
manda sobre todas es **E1, `Δ`**: sin ella ninguna de las tablas de arriba tiene su colchón real.
