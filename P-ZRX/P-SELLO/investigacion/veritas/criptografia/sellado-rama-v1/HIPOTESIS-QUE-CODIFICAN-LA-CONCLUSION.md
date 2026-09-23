# HIPÓTESIS QUE CODIFICAN LA CONCLUSIÓN — sellado-rama-v1

Una hipótesis «codifica la conclusión» cuando, si es falsa, el veredicto del informe cambia.
Cada una lleva: enunciado, dónde se comprueba, y **qué la refutaría**.

---

## H1 · H-TIPS — la tasa de cambio de punta

**Enunciado.** Con bloques Poisson de tasa `λ` y propagación `Δ`, un bloque referencia las puntas
del sub-DAG visible `{j : t_j ≤ t − Δ}`; entonces el número medio de padres (y de puntas
concurrentes) es `1 + λ·Δ`, y la punta seleccionada avanza a tasa `λ`.

**Dónde.** `src/modelo.jl` (`padres`, `puntas_concurrentes`); Monte Carlo de eventos en
`src/referencia.jl` (`mc_puntas`, `mc_puntas_r123`); artefacto `resultados/F2-mc-puntas.tsv`;
tests «modelo de punta» y «Monte Carlo».

**Qué la refutaría.** Que la simulación del modelo diera un número de padres sistemáticamente
distinto de `1 + λ·Δ` (el test exige < 10 %), o que las reglas del DAG de ZEROX permitieran
producir sobre puntas viejas sin perder producción — en ese caso el presupuesto `W` sería mayor y
habría que rehacer F2. **Las reglas del DAG no están cerradas** (`SPEC.md` en preparación), así que
H1 es una **entrada de escenario**, no una regla de consenso.

## H2 · H-PRESUPUESTO — el presupuesto del honesto

**Enunciado.** El honesto recibe la punta `Δ` después de su creación y debe producir dentro del
slot `τ`; si ata `n_puntas` puntas a la vez, dispone de `W = (τ − Δ)/n_puntas` por re-ligadura, y
la tasa exigida es `λ·n_puntas`.

**Dónde.** `src/modelo.jl` (`presupuesto_honesto`); `resultados/F2-religadura.tsv`; tests
«presupuesto del honesto: bordes».

**Qué la refutaría.** Un diseño en el que el honesto no necesite atar la punta (por ejemplo, atar
una **época** o un prefijo profundo): pero entonces dos ramas que bifurcan dentro de ese prefijo
comparten el objeto y **no hay rivalidad** — es el caso que `F2-profundo` publica. La única
profundidad que da rivalidad es `d = 0`, que devuelve H2.

## H3 · H-COSTE / H-PUENTE-ESPACIO — el umbral de sustitución

**Enunciado.** Sobre la superficie `α* = (1 − β_d − 2β_x)/2` (P-PRESTAMO F1, identidad de
**espacio**), el atacante prefiere `β_x` sobre `β_d` por unidad de coste en cuanto
`c_d > c_x/2`; el gap de α* al sustituir todo el espacio tramposo `s` es exactamente `s/2`.

**Dónde.** `src/modelo.jl` (`alpha_estrella`, `umbral_backfire`); `src/referencia.jl`
(`dano_por_coste`, `ventaja_bx_sobre_bd`, `validar_umbral`); `src/validacion.jl` (`validar_gap`);
`resultados/F5-alfa-sustitucion.tsv`; tests «F5».

**Qué la refutaría.** Que el puente espacio → tasa existiera y diera una razón `c_d/c_x` distinta
de la que se supone. **El puente no existe** (`P-ZRX/PROPUESTAS-VIABLES.md` fila 5, F0; `P-PRESTAMO`
H-PUENTE): `c_d` y `c_x` son **entradas** y este instrumento **no las fija**. La parte de α* es
aritmética exacta; la parte de sustitución está **condicionada a H-COSTE** y así se etiqueta.

## H4 · H-DETERMINISTA — el objeto es público y regenerable

**Enunciado.** `Sellar`/`Religar` son deterministas y públicos, y el objeto es función de
`(clave, índice, historia)`. Es la hipótesis H1 del Teorema de `P-ZRX/P-COBERTURA/`.

**Dónde.** `resultados/F2-religadura.tsv`, `F2-materializacion.tsv`, `F4-honesto.tsv`.

**Qué la refutaría.** Un `Religar` con aleatoriedad **secreta** que el adversario no conozca. Eso
es la vía (iv) de `P-COBERTURA`, y este informe la trata aparte (F3): el secreto es del **propio
granjero**, luego es neutral entre SUS ramas; solo impide que un **tercero** regenere.

## H5 · H-PROPIEDAD — qué cuenta como «espacio propio»

**Enunciado.** Para que `O_A` y `O_B` cuenten como objetos distintos, deben diferir en `δ` bytes
que haya que **materializar**; el espacio compartido es `S − δ`. La fracción de espacio
independiente es `δ/S`.

**Dónde.** `src/modelo.jl` (`delta_max_piezas`, `fraccion_materializable`,
`veces_presupuesto`); `resultados/F2-materializacion.tsv`; `resultados/F4-honesto.tsv`.

**Qué la refutaría.** Que «poseer `O_B`» pudiera acreditarse sin poseer bytes distintos — esto es,
una prueba sucinta que distinga «almacenado» de «regenerado». **Es exactamente lo que
`P-ZRX/P-COBERTURA/` demuestra imposible** para el formato fijado (Teorema y Corolario 4). Si esa
prueba existiera, H5 sobraría y la vía podría revivir.

## H6 · H-ANCESTRÍA — un atado a prefijo no distingue bifurcaciones en la punta

**Enunciado.** Dos bloques con el **mismo conjunto de padres** tienen exactamente la misma
ancestría; por tanto una etiqueta derivada de la ancestría no puede distinguir dos ramas que
bifurcan en la punta.

**Dónde.** `src/rapido.jl` (`ancestria`, `pares_mismo_padre`); `src/validacion.jl`
(`validar_ancestria`); test «lema de circularidad».

**Qué la refutaría.** Un contraejemplo: dos bloques con los mismos padres y ancestrías distintas
(imposible por definición de ancestría) — o un esquema que distinga ramas por algo **que no sea la
ancestría** y esté disponible **antes** de producir el bloque. Ese algo es, precisamente, el
conjunto de padres elegido; por eso la refutación principal **no es** este lema, sino H5: elegir el
conjunto de padres sí etiqueta la rama, pero entonces hay que **materializar** el objeto de esa
rama, y ahí manda el presupuesto de H2.

---

## Lo que NO es una hipótesis de este instrumento

- `t_tabla`, `r`, `N_TiB`, `Piece::SIZE` — **entradas medidas o verificadas en fuente**
  (`mediciones/hardware.tsv`, P-INTENTO M1).
- `λ`, `τ`, `Δ`, `Δ̄`, `S_max`, `n_puntas`, `η_h`, `η_a`, `c_d`, `c_x` — **entradas**; el
  instrumento no fija ninguna.
- El veredicto de F3 — se apoya en el Teorema de `P-COBERTURA` (citado, no re-demostrado) y en la
  aritmética de H2/H5, no en una hipótesis nueva.
