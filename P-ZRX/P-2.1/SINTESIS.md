# SÍNTESIS §2.1 — qué dejan establecido P-2.1 y P-PUERTA, y qué decide Katana

**Claude, 2026-09-19.** Fusiona las **conclusiones** de dos instrumentos independientes (no su código):
`P-2.1/veritas/consenso/ancla-inyeccion-v2/` (ANCLA-v0.2, DeepSeek, primera pasada) y
`P-PUERTA/veritas/consenso/puerta-cobertura-v1/` (PCO-v0.1, Claude). Es la entrada del encargo de la
`PROPUESTA-SPEC` de la regla de flujo. La primitiva PoT y su verificador van aparte (`P-POT/`, validado,
D-1 y D-2 decididas A/A).

## 1 · Validación

| Instrumento | Reejecución | Código leído | Veredicto |
|---|---|---|---|
| ANCLA-v0.2 | 3 celdas (`hon-4`, `hon-16`, `a3-a45`) **idénticas byte a byte** | GDR real sin modificar; vista cerrada bajo ancestros; clausura de publicación con `assert`; `W_obs` según encargo | **Válido para la primera pasada**, con tres etiquetas estrechas (abajo). Su 4.0 está **retirada** y sustituida por PCO-v0.1 |
| PCO-v0.1 | 239/239 tests en copia aislada; fórmula de cierre recalculada aparte | Peso en enteros exactos; predicado de aceptación verificado en la fuente de Autonomys; sin recortes que oculten error | **Válido**, tras aceptar la objeción del validador sobre R-FIN-7 y corregir dos defectos propios (RNG correlacionado, factor 2) |

## 2 · Lo establecido, con su alcance

1. **`1/(S+1)` (el «4 %») es la regla aditiva y no aplica bajo R-FIN-4/5.** El `SR` se cancela en todo
   instante (demostrado en `Rational{BigInt}`): el peso de un flujo crece con el espacio que lo cubre.
   Residuo: con `SR` impar hay un déficit `1/(SR+1)`, elegible; ≤ 4,9·10⁻⁴ con `SR_MIN = 2^11`,
   despreciable con rangos realistas. **Anotar en §2.3.**
2. **La cola de `W_obs` es exponencial en las 17 celdas medidas; ninguna vía ensayada la vuelve pesada.**
   *Alcance:* V1 con tope de 8 candidatos y ventana `[T, T+45]`; **A3 estática** (todos los bloques al
   mismo observador toda la réplica). **No está medido el equilibrio adaptativo** (partir a los honestos
   en dos mitades y sostener el empate).
3. **Manda la red honesta, no el atacante.** `L_mín(10⁻³)`: ≈0 con Δ nominal; **119** slots (Δ=4 s);
   **1 198** (Δ=10 s); **1 682** (Δ=16 s). A3 con `α=0,45`: **177**. Extrapolado a 10⁻⁹ (cola
   exponencial, `estimado`): ≈360 / ≈3 600 / ≈5 000 slots. **La Δ es simulada (DMS-v0.1), no medida en red.**
4. **Una partición de flujo, si nace:** sin adopción es **permanente por construcción**. Con adopción,
   R-FIN-7 congela a **todos** los nodos a la vez en `t_j + F` (la profundidad de cruzar de flujo es
   `t − t_j`), y con vista común se resuelve a la fuerza. Quedan **dos rendijas**:
   - **desfase de vista** en ese instante: `arcsin(√(τ/F))/π` → **0,27 %** (`F=2 h`, `τ=0,5 s`),
     **0,75 %** (`τ=4 s`), **1,5 %** (`τ=16 s`), condicionado a que la partición haya nacido y a reparto
     simétrico; va como `√(τ/F)`: cuadruplicar `F` solo la divide por dos;
   - **el que sincroniza después**: toma el líder del momento; con deriva nula discrepa de los
     veteranos con probabilidad → 1 mientras el flujo perdedor siga vivo.
5. **La variable que decide la deriva es `(1−c)(s₁−s₂)`, no la cobertura `c`.** Con reparto simétrico la
   deriva es nula para cualquier `c`. Y `c → 1` no es automático: cubrir un flujo tiene **coste fijo**
   (verificar su PoT, 0,09–0,19 núcleos; producirlo, 1,56), así que «cubrir todos» no domina para granjas
   pequeñas. `S_IOPS ≈ 24` a cualquier capacidad.
6. **Dos huecos de redacción dominan el resultado, y son texto, no cálculo** (PCO `PROPUESTA.md` P5):
   qué hace un nodo **sin cadena previa** ante dos flujos, y si un granjero puede **firmar en un flujo que
   no ha seleccionado**. Cerrar cualquiera de los dos apaga el canal dominante.

## 3 · Qué significa

**La familia 1 sobrevive.** Toda la seguridad descansa en que la partición **no nazca** (lo gobierna `L`
frente a Δ) y, si nace, en que **se resuelva en `t_j + F`** (lo gobierna permitir la adopción y cerrar
los dos huecos). **1a (`L ≥ F`) es robusta incluso con Δ = 16 s. 1b (`L = 1 h`) solo con Δ ≤ ~4 s
medida en red real y con el equilibrio adaptativo medido.**

## 4 · Decisiones de Katana para la regla de flujo

| # | Decisión | Opciones y coste | Recomendación de Claude |
|---|---|---|---|
| **DF-1** | Perfil de `L` | **1a** `L ≥ F`: robusta; adelanto de 2 h, margen histórico frente al sembrador 1,91×. **1b** `L < F`: margen 3,6×; exige medir Δ real y el equilibrio adaptativo | **1a ahora**; 1b como optimización tras una testnet |
| **DF-2** | ¿Puede un nodo verificar y adoptar el flujo rival mientras `t − t_j ≤ F`? | **Sí:** la partición entre veteranos se resuelve en `t_j + F` (rendija ≤ ~1 %); paga verificar PoT ajeno durante esa ventana — acotado por presupuesto, que da `Pendiente` y nunca `Inválido` (C-POT-07) — y obliga a reescribir el motivo de R-FIN-5. **No:** cero coste de verificación; toda partición es permanente | **Sí**, con presupuesto |
| **DF-3** | Regla del recién llegado | seguir al más pesado del momento (discrepa de los veteranos); checkpoint/subjetividad débil (ya existe C-CHK para el periodo frágil); o regla objetiva «el flujo canónico es el que lideraba en el slot `t_j + F`» (computable por cualquiera después; hay que estudiar su resistencia a bloques fabricados con slots antiguos) | **estudiarla en la propuesta**; no decidir a ciegas |
| **DF-4** | Producir en un flujo no seleccionado | no se puede prohibir criptográficamente (las identidades son gratis: teorema de `balizas-auditoria.md:71`); sí se puede dejar sin valor económico lo producido en el flujo perdedor | **declararlo**, no legislarlo |

## 5 · Abierto, y fuera de lo que cierra §2.1

`s₁` en el instante en que nace la partición (lo natural es ≈ 1/2: nace cuando dos anclas están casi
empatadas); el equilibrio adaptativo; la Δ real; Prop. 7 bajo U3″ + R-FIN-5 + R-FIN-8′ (la «deuda
principal» de `ancla-de-orden.md` §5); soborno del ancla, sembrador y `ρ > 1` como adversarios simulados.
La segunda pasada de ANCLA-v0.2 (4.B, 4.C, 4.D, cola honda) **afina 1b; no hace falta para escribir 1a.**

## 6 · DECIDIDO por Katana (2026-09-19)

- **DF-1:** perfil **1a, `L ≥ F`**, con `L` atada a `F`.
- **DF-2:** **no se añade regla de adopción.** Bajo 1a la ventana de adopción es `F − L ≤ 0`: flujos
  distintos implican una divergencia de cadena de profundidad `≥ L ≥ F`, que la finalidad ya manda
  ignorar; R-FIN-5 conserva su virtud («nunca verificar el PoT de un flujo ajeno») y no se reabre el DoS.
  *Razonamiento de Claude, sin revisar: va como afirmación a demostrar o refutar en `P-FLUJO/`.* La
  tabla de §4 recomendaba «Sí» a la adopción: **queda superada** — el análisis de PCO-v0.1 toma como
  punto de bifurcación el instante de activación y describe el caso 1b, no el 1a.
- **DF-3 / DF-4:** se reducen a declarar que una partición de flujo equivale a una violación de finalidad.
- De `P-POT`: **D-1 = A** (conservar `blake3`), **D-2 = A** (`pot_output` = salida futura).

Encargo de la propuesta de la regla de flujo: `P-FLUJO/PROMPT.md`.

## 7 · Actualización 2026-09-20

- `P-FLUJO` **refutó** el razonamiento de Claude de §6 («bajo 1a una partición de flujo equivale a una
  violación de finalidad»): R-FIN-7 prohíbe reorganizar, no impide que dos mitades sostengan cadenas
  distintas. 1a se sostiene por: ancla final antes de usarse (**demostrado**), partición que rara vez nace
  (**medido en simulación**) y, si nace, **permanente** (**demostrado**). La ventana de adopción está
  demostradamente vacía: la adopción no es que sobre, es que **no es posible**.
- **DECIDIDO por Katana:** 1a **reconfirmado** sabiendo que no hay cura; **suelo de `L`**:
  `L ≥ máx(F, L_suelo)`; **D-F1 = A** (entropía `chunk ‖ pot_output`); **D-F6 = A** (cota de slot a todos
  los padres). **Sin decidir:** D-F2, D-F3, D-F4, D-F5 (van como provisionales en la propuesta).
- `P-SEMBRADOR` (Codex, validación parcial): al atacante le basta **una pieza**; la antigüedad de una
  parcela **no es demostrable** hoy; los márgenes históricos no son heredables. Eliminarlo exige un
  compromiso previo de la parcela completa (cambio de consenso). **Falta medir el coste de un intento
  dirigido** antes de elegir camino. No bloquea el cierre de §2.1.
- **DECIDIDO por Katana (2026-09-20, segunda tanda):** **D-F2 = A** (`H_d` con etiqueta nueva);
  **D-F3 = C acotada al enunciado** (regla de finalidad nueva en el SPEC con la semántica de R-FIN-7; la
  reconciliación con el código, `COINBASE_MATURITY` y el archivado queda en TAREAS); **D-F4 = A**
  (desigualdad explícita); **D-F5 mejorada** (se escribe que el nodo sin cadena previa aplica la selección
  ordinaria por `blue_work`, más la regla operativa de detección). **No queda ninguna decisión de §2.1
  pendiente.** Órdenes al agente: `P-FLUJO/ADENDA-1.md` y `ADENDA-2.md`.
- **DECIDIDO por Katana (2026-09-20, tercera tanda):** **`L` como definición**,
  `L_slots := máx(F_slots, L_suelo_slots, S_max_slots + 1)` —deja de ser un parámetro libre; más estricto
  que el «≥» aprobado antes, y mejor frente al sembrador—; **corte de la vista de época en `T_j + L_slots`**
  (no en `t_j`, que dependía del ancla); **D-F7 = B**: la regla de finalidad vive en familia propia,
  **`C-FIN-01`** (no `C-FLU-19` ni `C-REORG-08`). Pendiente: respuesta del agente de `P-FLUJO` a la
  objeción del validador sobre la Prop. A (demostrada sobre la cadena del nodo; el ancla se define sobre
  la cadena del virtual de la vista restringida).

## 8 · Corrección 2026-09-20 (tarde) — el razonamiento de Claude sobre DF-2 era falso

El agente de `P-FLUJO` aceptó la objeción del validador a su Prop. A y, al propagarla, **refutó también
la conclusión (c)** que Claude había dado por buena en §6 y §7 de esta síntesis («bajo 1a la ventana de
adopción es `F − L ≤ 0`, vacía»). **Es falsa:** con el ancla definida sobre la vista restringida
(C-FLU-04), dos flujos nacidos en `t_j` comparten todo el DAG con `slot < t_j`; cruzar de flujo cuesta
`≈ t − t_j`, no `t − T_j`. **La ventana de adopción mide `≈ F_slots` y el análisis de PCO-v0.1 NO estaba
superado**: R-FIN-7 congela a todos a la vez en `t_j + F`. La frase de §6 que lo declaraba superado queda
**retirada**.

Consecuencias: **DF-2 («no se añade regla de adopción») se decidió sobre una premisa falsa** y vuelve a
la mesa como **D-F9**. La Prop. A se parte en **A1** (demostrado: desde `t_j`, C-FLU-14 impide que ningún
descendiente válido cambie la inyección ya activada) y **A2** (probabilístico y **no medido**: antes de
`t_j` una rama privada más pesada que la honesta dentro del corte puede cambiar el ancla; es la cola de
una carrera de longitud `L`). Reglas nuevas propuestas: **C-FLU-20** (el productor descarta las puntas
cuya fusión cambiaría una inyección ya activada; ese bloque queda infusionable para siempre) y
**C-FLU-21** (la inyección activada se hereda, no se recalcula). Abiertas: **D-F8** (congelar la vista)
y **D-F9**. D-F7 = B (`C-FIN-01`) está decidida pero **aún sin aplicar** en la propuesta.
- **DECIDIDO por Katana (2026-09-20, cuarta tanda):** **D-F8 = C** (no congelar la vista; la inyección
  activada se hereda, C-FLU-21) y **D-F9 = C** (**se permite adoptar el flujo rival dentro de la ventana
  `F`, con presupuesto**; sustituye a DF-2). D-F7 = B (`C-FIN-01`) se reenvía. Orden al agente:
  `P-FLUJO/ADENDA-3.md`. La adopción cura el nacimiento **espontáneo**; **no** cura un corte de red más
  largo que `L`, donde las cadenas ya divergieron antes de `t_j`.
- **DECIDIDO por Katana (2026-09-20, quinta tanda):** **D-F10 = B** — presupuesto de verificación por par
  **y** cota global por nodo e intervalo; agotada la cota el nodo se queda donde está con `Pendiente` y
  reintenta, nunca `Inválido`. **D-F1…D-F10 decididas: `P-FLUJO` cerrado.** Siguiente: `P-CIERRE/`.
