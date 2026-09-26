# SL-2 · Falta de definición detectada antes de escribir código

**Fecha:** 2026-09-26. **Ejecutor:** DeepSeek (`deepseek-flash`). **Entrada congelada:**
`P-ZRX/P-SLASHING/ENTRADA-SL2.sha256` (verificada 8/8). **Orden:** `ORDEN-SL2-CALIBRACION.md`.
Leídos íntegros, además: `PROGRAMA.md`, `ORDEN-SL1-CONTRATO.md`, `resultados-DS2/MODELO.md`,
`REVISION-DS3.md`, `REVISION-DS5.md`, `REVISION-DS6.md`, `CORRECCION-DS6-A.md`, `SINTESIS.md`,
`DS3/src/*` y `V-ZRX/LINEO.md`.

La orden manda: «Si detectas una falta de definición, infórmala antes de editar.» Nada de lo que
sigue **bloquea** la ejecución: cada punto se resuelve con una **decisión declarada** que viaja con
las tablas (columna de etiqueta y `escenarios.tsv`), sin inventar datos. Se distinguen las que son
**ambigüedad de notación** (se resuelven renombrando) de las que **cambian el veredicto** (se
implementan las dos variantes y se publican ambas).

---

## F1 · La fracción confiscada `f` no existe en el modelo ratificado

- **Qué falta.** La orden pide calibrar «fracción confiscada `f`», pero la pérdida del modelo
  ratificado (`DS3/src/modelo.jl:169`, `MODELO` §2.5) es
  `perdida_por_reclutado = ρ_ret·I·T_v + c_r + I·M`, **sin `f`**. `ORDEN-SL1` §3.2 habla de «pérdida
  no correlacionada (fracción fija de la garantía expuesta, parámetro para SL-2)» y su §4.5 de una
  garantía que incluye activo, pendiente, en retirada y créditos de coinbase no maduros. No hay
  fórmula ratificada que diga a qué se aplica `f`.
- **Qué cambia.** `f` puede escalar (a) solo el saldo retenido, (b) toda la garantía expuesta, o
  (c) también los recargos fijos.
- **Resolución SL-2.** Ley base **A (fiel a DS-3)**:
  `L_A(f,ρ_ret,T_v,q_g) = f·(ρ_ret·I·T_v + q_g) + c_r`, con `q_g ≡ I·M` en el caso base (así `f=1`
  reproduce exactamente `ρ_ret I T_v + c_r + I M` de DS-3). Sensibilidad **B**: `f` escala todo,
  `L_B = f·(ρ_ret·I·T_v + q_g + c_r)`. Se barren `f ∈ {0,25; 0,50; 1,00}`.

## F2 · Colisión de símbolo: `q` (garantía M1) contra `q` (`q_gana` del modelo)

- **Qué falta.** `ORDEN-SL2` §1 usa `q` como **garantía** (M1). El modelo ratificado usa `q` como
  **probabilidad de que la evidencia llegue a la historia elegida** (`MODELO` §1, §2.5;
  `region_disuasion(...; q, ...)`), y `escenarios.tsv` la llama `q_gana`.
- **Resolución SL-2.** Se renombra: `q_ev` = probabilidad de inclusión de la evidencia (antes
  `q_gana`); `q_g` = garantía mínima por identidad (M1). Ninguna función de SL-2 usa `q` a secas.

## F3 · `R_slots` (retardo de retiro) no aparece en el modelo

- **Qué falta.** La orden lista `R_slots` entre los parámetros del castigo, y `ORDEN-SL1` §4.4 fija
  la desigualdad `R_slots > plazo + margen`, pero el modelo ratificado no tiene `R_slots` ni define
  su efecto sobre el saldo confiscable.
- **Resolución SL-2.** Se adopta, **declarado**, que el retiro no puede ejecutarse antes de
  `R_slots` y que durante esa ventana el saldo sigue expuesto: horizonte efectivo
  `T_v^eff = T_v + R_slots`. Se barre `R_slots ∈ {0; F; 2F}` con `F = 1019`. La condición de
  viabilidad de SL-1 (`R_slots > F + margen`) es una restricción de **contrato**, no de incentivos, y
  se publica aparte; SL-2 no la recalibra. Efecto neto: `R_slots > 0` solo **refuerza** la disuasión
  y **agrava** la pérdida del honesto (monótono), por lo que no puede abrir la región.

## F4 · «Ingreso anual del honesto» no está definido

- **Qué falta.** La pregunta falsable pide «pérdida esperada anual ≤ 1 % de su ingreso anual», pero
  el modelo no define el ingreso. `DS3` solo dio un `coste_honesto` absoluto (`DEFINICIONES-FALTANTES`
  F9), sin cociente con ingreso.
- **Resolución SL-2.** Se define, declarado, para una **clave representativa** de fracción `f_h`:
  ingreso anual `= λ·f_h·I·T_año` (bloques ganados × emisión), `T_año = 31 536 000 s`;
  pérdida anual esperada `= ε_h · L(·)`, con `ε_h` = tasa de doble firma accidental **por clave y
  año**. Cociente `= ε_h·L / (λ f_h I T_año)`. Se barre `ε_h ∈ {10⁻⁴;10⁻³;10⁻²;10⁻¹}` (la orden) y,
  como sensibilidad de regresividad, `f_h ∈ {10⁻⁶;10⁻³;10⁻¹}` (base: la fracción media observada en
  DS-6). «Ingreso» en u.e.; ZEROX no tiene mercado, así que **el cociente es adimensional** y no
  depende de un precio.

## F5 · Inconsistencia de unidades en `perdida_por_reclutado` (heredada de DS-3)

- **Qué falta.** `MODELO` §2.3 da saldo medio **por clave** `E[B]=ρ_ret I θ/2`, `θ=λ f T_v`, que
  **depende de `f`**; `MODELO` §2.5 usa `ρ_ret I T_v` **sin `f` ni `1/2`** como pérdida «por
  reclutado». Las dos no pueden ser la misma magnitud. `DS3/src/rapido.jl:156` usa
  `coef=ρ_ret I λ T_v/2` (por unidad de espacio); `modelo.jl:169` usa `ρ_ret I T_v` (por reclutado).
- **Qué cambia.** Con `f` medio de una clave (`≈10⁻³`) el saldo retenido por clave es `≈0,9 u.e.`, no
  `1 800 u.e.`; el veredicto de disuasión puede invertirse.
- **Resolución SL-2.** **Vía primaria P1:** se conserva literalmente la fórmula ratificada de DS-3
  (`L` como en F1) para no reabrir el modelo ratificado. **Vía de sensibilidad P2:** se corrige a
  base física `L` con saldo `ρ_ret·I·λ·f_media·T_v/2` por clave. Se publican las dos regiones; si
  difieren en el signo del veredicto, se declara **inconcluso** en esa celda, no se elige la
  favorable. (Nota: P1 es la que reproduce los `510 570 u.e.` de `REVISION-DS5`.)

## F6 · `V` está definido «por reclutado» pero la desigualdad lo usa como total

- **Qué falta.** `MODELO` §1: `V` = «valor del ataque por reclutado». `MODELO` §2.5 escribe `V/N`
  con `N = N_recl`, es decir, `V` **total** dividido por reclutados. Ambas lecturas conviven.
- **Resolución SL-2.** Se interpreta `V` como **valor total del ataque** (la lectura que hace la
  desigualdad) y se publica `V` en la rejilla `{10²;10³;10⁴;10⁵;10⁶}` u.e. El número de reclutados
  no es el fijo `N_recl` de `escenarios.tsv` sino el que impone el ataque:
  `N_paid = max(0, β_d − B(ε)) / f_media` (solo pagan soborno las claves con saldo). La condición de
  disuasión es `N_paid · κ · q_ev · L > V`, que con `B=0` reproduce `N_recl·κq L > V` de DS-3.

## F7 · El umbral de saldo cero depende de `f`

- **Qué falta.** `MODELO` §2.4 define `B(ε) = M(ε/(λ T_v))`: fracción de espacio en claves con saldo
  `< ε`. Si la confiscación es `f < 1`, una clave solo pierde `f·saldo`; la clave «gratis» es la que
  cumple `f·saldo < ε`, es decir `saldo < ε/f`.
- **Resolución SL-2.** Se usa `x = ε/(f·λ·T_v^eff)`. Con `f=1`, `T_v^eff=T_v` reproduce DS-3/DS-6.

## F8 · No estaba fijada la probabilidad de éxito `P*` del ataque

- **Qué falta.** «Reclutar el espacio que falta para ganar una rama privada» no dice con qué
  probabilidad. `DS3` adoptó la rejilla hipótesis `P* ∈ {10⁻⁶;10⁻³;0,5}` (`DEFINICIONES-FALTANTES`
  F2).
- **Resolución SL-2.** Se conserva esa rejilla y se invierte la DP de primera pasada para obtener
  `β_d^min(α,F,P*)`; la región se publica para cada `P*`. La frontera `1−2α` (cruce de deriva) se
  publica como cota superior de `β_d^min`, nunca como sustituto.

## F9 · El `B(ε)` empírico de DS-6 solo cubre dos `T_v` y tres `ε`

- **Qué falta.** `CORRECCION-DS6-A` calculó el `B(ε)` empírico para `T_v∈{3 600;10⁵}`,
  `ε∈{10⁻³;10⁻²;10⁻¹}`. La rejilla de SL-2 necesita más puntos.
- **Resolución SL-2.** Se implementa el **cálculo empírico directo** para cualquier
  `(T_v, ε, f)` (barrido lineal sobre los 2 453 granjeros limpios; sin ajustar ley). Se declara que
  fuera del soporte observado (`x < min tib_i / denom`) el empírico es **0 exacto** por
  construcción, y que es una **cota inferior** de la red (solo cuenta el pool), como en DS-6 A.5.

## F10 · La Pareto «pesimista» de DS-3 choca con el exponente medido

- **Qué falta.** La orden pide la «Pareto de DS-3 (`α_dens ∈ [2,05;3,0]`)» como caso pesimista, pero
  `DS-6` midió `α_dens ≈ 1,11` (global) y `≈1,86` (cola), **ambos ≤ 2**, donde `E[f]` diverge y la
  rama no truncada de `masa_prob` (`DS3/src/modelo.jl:143`) **lanza error**.
- **Resolución SL-2.** Para la Pareto se usa la **forma truncada** `[f_min,1]`
  (`masa_prob` rama `F_max=1`), que es la definición literal de H3 («Pareto truncada [10⁻⁸,1]») y la
  única definida en el régimen medido. Se publica con la etiqueta `hipótesis H3` y se recuerda que
  DS-6 la dejó **sin respaldo**.

---

## Lo que SL-2 **no** decide (frontera con SL-1)

- No fija la forma del contrato (`EvidenceTx`, plazos, deduplicación), solo los números.
- No decide si `f` se aplica al saldo o a la garantía (F1): ofrece la región para las dos leyes.
- No decide el destino de los fondos confiscados.
- No recalibra la viabilidad `R_slots > F + margen` (F3): la toma como restricción de SL-1.
