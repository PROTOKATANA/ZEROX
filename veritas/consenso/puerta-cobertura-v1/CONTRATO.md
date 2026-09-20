# CONTRATO — PCO-v0.1 · ¿Se sostiene sola una partición de flujo?

**Instrumento:** PCO-v0.1 (`P-PUERTA/veritas/consenso/puerta-cobertura-v1/`).
**Categoría (LINEO §1):** `consenso`. Motivo: el objeto es la regla de selección (`blue_work`,
R-FIN-4/5/7/13′) y la dinámica del líder entre flujos. Secundarios: `economía` (§3, cobertura
racional) y `almacenamiento` (IOPS por TiB).
**Fecha de apertura:** 2026-09-19.

---

## 1 · Qué calcula

1. **La tasa de peso de un flujo, en enteros exactos.** Dado el predicado de aceptación de
   Autonomys (`solution_distance ≤ SR/2` con distancia bidireccional) y `C-GD-01`
   (`w = ⌊2^128/(SR+1)⌋`), calcula en `BigInt`/`Rational{BigInt}` la razón
   `tasa_peso(P,SR) / (P·2^64)` y decide **si el `SR` se cancela**, por separado para `SR` par y
   `SR` impar, con el suelo entero incluido y sin coma flotante.
2. **La dinámica de la diferencia de peso entre dos flujos**, en sus dos regímenes (retarget
   convergido y transitorio pre-convergencia), como proceso de Poisson compuesto con saltos
   `+w₁`/`−w₂`. De ahí, como **funciones** de `(c, s₁, λ, F)`:
   - `L(t)` = P(el signo del líder vuelva a cambiar después de `t`), con horizonte infinito;
   - `t(ε)` para `ε ∈ {10⁻³, 10⁻⁶, 10⁻⁹}`;
   - `P(dos nodos congelados en flujos distintos)` bajo la regla que R-FIN-7 dice **por su letra**
     —cota a la **profundidad** de la reorganización, luego congelamiento simultáneo en `t_j+F`—,
     como función del desfase de vista `τ`; más el canal de quien sincroniza después, `L(F)`.

> ⚠️ **Corregido el 2026-09-19 tras objeción del validador.** La primera versión de este contrato
> prometía esta magnitud «bajo la regla de absorción derivada de adopción + R-FIN-7», y la regla que
> implementé —«`F` desde que el nodo adoptó»— **no era la de R-FIN-7**, que acota profundidad y no
> antigüedad. Ver `PROGRESO.md` y `MODELO.md` §2.3.
3. **La condición de cobertura racional**, como función de los costes marginales (IOPS,
   núcleos de auditoría, verificación del PoT, producción del PoT) y de `P(gana el flujo)`;
   y `S_máx` como función de los **IOPS por TiB del medio**, no de la capacidad.
4. **La magnitud de arcoseno**: el instante del último cambio de líder dentro de un horizonte
   declarado, y su contraste con la ronda 3.

## 2 · Qué NO acredita

- **No** acredita ningún valor de `F`, `L`, `I`, `ρ_max`, `Δ`, `k`, `λ` ni precio alguno. Todo
  se entrega como función o región. Los costes físicos (µs/sector, lecturas/slot, s/slot de PoT)
  se toman de mediciones ya existentes en el repositorio, citadas con su archivo y línea, y son
  **parámetros de entrada**, no resultados de este instrumento.
- **No** acredita la Propiedad 7 de PHANTOM/GHOSTDAG ni su versión condicional (hueco L571 del
  paper, declarado en `research/dag-poas-recursion-flujos.md:31-35`). Este instrumento supone
  que la partición **ya nació** y no calcula la probabilidad de que nazca (eso es P-2.1 §4.A).
- **No** acredita nada con atacante. Todo el análisis es **sin adversario**: los desvíos son los
  del muestreo honesto. Un adversario puede cambiar el signo de cualquier conclusión de §2.
- **No** acredita la fracción azul `β` de GHOSTDAG. `β` entra como **función paramétrica
  declarada** (anticono Poisson, ver `HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md`); el resultado se
  entrega como dependencia de `β₁/β₂`, no como un número con `β` fijado.
- **No** acredita que el reparto `s₁/s₂` ni la cobertura `c` tengan ningún valor concreto en una
  red real. Son ejes de barrido.
- **No** es una especificación. `PROPUESTA.md` es propuesta.

## 3 · Presupuesto declarado ANTES de ejecutar (LINEO §7)

| Recurso | Tope declarado | Motivo |
|---|---:|---|
| Hilos de cómputo | **2** | Otro agente ocupa 24 en `P-2.1/`; el tope de máquina es 24. El cálculo es analítico y el Monte Carlo es pequeño. |
| RAM | **4 GiB** | Sumas de Poisson en ventanas de `O(√μ)` y réplicas MC con estado `isbits`. |
| Disco temporal | **200 MiB** | CSV de resultados y el volcado del barrido. |
| Tiempo de pared total | **3 h** | Si se agota: checkpoint, estado **inconcluso**, y se reporta qué celda quedó sin cerrar. |
| Corrida individual | **5 min** | Si una celda lo supera, se para, se perfila y se reporta la hipótesis de cuello. |

Si el presupuesto se agota, el instrumento conserva `resultados/*.csv` parciales y el informe
declara **inconcluso** la parte no cerrada, con semilla y parámetros de la celda.

## 4 · Régimen numérico

- **Exacto en enteros** (`BigInt`, `Rational{BigInt}`) para todo el punto 1: pesos, rangos,
  suelos y razones de cancelación. Coma flotante **prohibida** ahí (`C-GD-01`).
- **`Float64` + `SpecialFunctions.gamma_inc`** para el barrido de `L(t)`, con truncación de
  ventana **acotada por colas de Poisson exactas**, nunca por corte arbitrario.
- **`Arblib` (aritmética de bolas)** para certificar todo número publicado de `L(t)`, de la raíz
  de Lundberg `R` y de la tasa `I`. Si una bola contiene el umbral, el resultado es
  **inconcluso** y se dice.
- **Prohibido** `min(1.0, ·)` o cualquier recorte. La descomposición usada
  (`L = P(D≤0) + P(D̃>0)`, ambos sumandos positivos y ≤ 1 por construcción) no necesita recorte.
- Monte Carlo: **`Random123`/Philox contracontador** (LINEO §5.1), con el índice de réplica como
  clave —no semillas consecutivas—, e intervalo de confianza de Clopper–Pearson (exacto), nunca ±1σ.

## 5 · Criterio de terminación

El instrumento termina cuando: (a) la referencia exacta y el kernel rápido coinciden en el
dominio de la referencia; (b) todo número publicado tiene bola de Arb que lo contiene; (c) hay
un test que **falla** si cualquier resultado se sustituye por una constante literal; (d) los
cuatro entregables del encargo tienen su función, su etiqueta y su condición.
