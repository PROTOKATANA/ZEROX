# PROPUESTA — ANCLA-v0.1 (propuesta, NO SPEC)

Este documento **no fija reglas**. Propone qué debería exigirse a la regla de anclaje y qué queda
abierto, a la luz de `INFORME.md`.

## 1 · Propiedad mínima que el ancla debería cumplir

> **Propiedad A (estabilidad del ancla).** La posición `N` de la cadena seleccionada de la que se
> toma `entropía_j` y el target slot **MUST** estar a una profundidad `D ≥ D_min(ε)` medida sobre
> el mismo modelo de red que fija `Δ`, con la `Δ` vigente y sin adversario, tal que
> `P(discrepancia)(D) ≤ ε`.

`D_min(ε)` es un **requisito de diseño medido**, no una constante de consenso. Con el modelo
ANCLA-v0.1 y la `Δ` medida: `D_min(10⁻³) = 1`, `D_min(10⁻⁶) = 3`, `D_min(10⁻⁹) ≈ 4` (el último
estimado). **No** debe escribirse `D ≥ F`: la finalidad es otra cosa y no es necesaria para la
unicidad del ancla (ésa es la conclusión del encargo).

## 2 · Propiedad de calibración (ya escrita, no nueva)

`I ≥ ρ_max·W_dec` (R-FIN-14(f)) con `W_dec` **medida** y `ρ_max` decidida por Katana. Bajo el
supuesto `F ≥ I`, esto es la frontera `F ≥ ρ_max·W_dec`, que convierte las dos decisiones
pendientes en un requisito. **No es una propiedad nueva de este instrumento; se cita porque el
mapa la usa.**

## 3 · Lo que este instrumento deja abierto (y no debe cerrarse por omisión)

1. **Política de puntas.** La simulación usa «hasta 15 puntas de la vista del creador». Si la
   política real es otra (p. ej. solo la punta más pesada), el grado de bifurcación cambia y
   `D_min` puede moverse. **LAGUNA declarada, no medida.**
2. **Particiones y eclipse.** Fuera del modelo. La tolerancia a particiones de R-FIN-7 (`F` con
   `S_max`) puede inducir reorgs de profundidad `~λF` que este instrumento **no** cubre. Si el
   ancla debe ser única también tras una partición, el requisito sube y hay que medirlo.
3. **`D_max`.** La lectura de la cota superior como `I` (y de `F` como cota si se exige finalidad)
   es **interpretación del ejecutor**, no texto del encargo. Si la cota superior es otra, el mapa
   cambia de orden, no de signo (porque `D_min` ≪ `I_min`).
4. **`D_min(10⁻⁹)`.** Estimado, no medido. Para medirlo harían falta ~10⁹ unidades independientes.
5. **`ρ` físico.** Se usa 1,5–2,5× de `research/pot-aes-asic-chacha.md` §3. Si Katana decide
   `ρ_max` distinto, la tabla del mapa se recalcula pero la conclusión de holgura se mantiene para
   cualquier `ρ ≲ 20`.

## 4 · Recomendación (marcada como tal)

Bajo el modelo medido, **la opción «flujo global único con inyección desde un prefijo estable» es
viable**: basta que el prefijo esté a **unos pocos slots** de profundidad y que se cumpla
`I ≥ ρ_max·W_dec`. No hace falta la revelación retardada de R-FIN-14(h) **por el motivo del
ATAQUE 1**; (h) sigue siendo una palanca para otros objetivos (acortar `F`, anular steering), pero
su coste (un VDF más en la ruta crítica) no se justifica con lo medido aquí.

**Decisión de Katana, no de este instrumento:** `ρ_max`, `F`, `I` y si se adopta (h).
