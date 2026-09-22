# CRP-v0.3 · Contrato

**Categoría Veritas:** `seguridad` (dominante); `consenso` y `rendimiento` (secundarias).
**Entrada congelada:** `ENTRADA.md` = `deepseek/ENCARGO-07v2-coste-rama-privada.md`
(`a8912ba5…5c45`). **Deriva de CRP-v0.2, que no se cierra.** `deepseek/` exclusivamente.

## 1 · Pregunta

`P_win(α,T,d,E,O) = P[W_priv(T) − W_pub(T) > d | E,O]`; `α_prob`, `g_E`, `α_drift`,
`P_eventual` como objetos separados. Aquí además se separan **tres eventos**:

| Objeto | Definición |
|---|---|
| `P_terminal(T)` | masa en `D(T)<0` al cierre **exacto** del horizonte |
| `P_first_passage(≤T)` | probabilidad de visitar `D<0` alguna vez hasta `T` |
| `P_eventual` | límite `T→∞` |

Y `α_prob` se calcula **por evento** y con **cobertura simultánea**; una celda `0/n` se
publica como cota unilateral, nunca como frontera.

## 2 · Correcciones de v0.3 (encargo)

1. Tres eventos separados y `α_prob` por evento.
2. `DescriptorFlujo`/`PotOrigin`/`N(s)` en cada bloque; R-FIN-5 sobre **todo** `past(B)`.
3. Presentación, validación, intento de fusión y **decisión del observador**.
4. `S` flujos generados **conjuntamente** desde oportunidades compartidas (perfecta/iid/derivada).
5. Red: autor-inmediato, `Δ=0` real, drenaje terminal simétrico.
6. Un único productor no genera rojos por latencia consigo mismo.
7. Déficits en unidades de **`blue_work`**; la semilla no cambia con `d`.
8. Barrido `S={1,2,4,8,16,24}`, varios `T/d/Δ/k`, `α` a ambos lados de cada cruce.
9. Intervalos para `α_prob` con cobertura simultánea.
10. `η_h` y `η_a` medidos por separado; si no basta la muestra, curva **inconclusa**.
11. Fixtures U2/U3 con billetes repetidos y fusión compatible/incompatible.
12. Repetición de las tres revisiones independientes.

## 3 · Lo que NO acredita

No ejecuta PoT AES (compatibilidad **estructural** de flujo). El controlador del SPEC sigue
`Pendiente`. No mide `S_adversario`. No promociona R-FIN-5 a consenso. No hereda el veredicto
de CRP-v0.1/v0.2.

## 4 · Criterio de parada

Falta de regla/integración o presupuesto ⇒ `inconcluso`. Un timeout no es evidencia.
