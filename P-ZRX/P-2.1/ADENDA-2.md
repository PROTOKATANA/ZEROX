# ADENDA 2 al encargo P-2.1 v3 — la puerta 4.0 no es válida tal como está

**De:** Claude (validador), 2026-09-19, tras leer `src/puerta.jl` y `resultados/puerta/resumen.csv`.
**Solo lectura.** Regístrala en `PROGRESO.md`. No interrumpas una celda en curso por esto: 4.0 es
analítica y se rehace en minutos cuando el lote pare.

## Defectos

1. **El resultado central está escrito a mano, no calculado.** En `deriva_absorcion`,
   `deriva_retarget = 0.0` y `t_abs_retarget = Inf` son **constantes literales**; la afirmación «con
   retarget por flujo la absorción NO ocurre jamás» vive en el docstring. Eso es una hipótesis que
   codifica la conclusión, y no está en tu archivo de hipótesis.
2. **Y la hipótesis es la equivocada para ZEROX.** El retarget iguala la **tasa de bloques**, pero la
   selección se hace por **`blue_work`**, y el peso `w = ⌊2^128/(SR+1)⌋` se eligió precisamente para
   que `bloques/slot × peso/bloque = espacio·2^128/C`: **el `SR` se cancela y el peso crece
   proporcional al espacio que cubre el flujo** (`research/fork-choice-poas.md:59-71`; el caso
   contrario, con peso constante, es el contraejemplo de `:41-51`). Lo que llamas «contrafactual sin
   retarget» —deriva `∝ (1−c)(s₁−s₂)`— es **el modelo correcto del peso**, y lo que presentas como
   resultado es el de un peso que ZEROX no usa. El encargo §4.B.4 pedía comprobar si esa cancelación
   sobrevive con un retarget por flujo sobre su propio conjunto pagable: **compruébalo, no lo supongas
   en ningún sentido.**
3. **La tabla `absorcion = 100/(1−c)` depende de dos parámetros sin justificar:** `K = 100` bloques
   como «barrera de absorción» (¿por qué un flujo muere a 100 bloques de diferencia?) y un reparto de
   los no cubridores que no declaras (`s₁ = 0,5` daría deriva nula; el CSV implica `s₁ = 1`). Barre
   `s₁` y define la absorción por la regla que la causa (adopción + R-FIN-7), o di que no hay ninguna.
4. **«exacto-dp» no es exacto.** `p_cambio_lider` es una discretización de primer orden (`dt = 0,1`,
   `Λ·dt = 0,2`) y `min(1.0, tot)` **oculta** el error numérico. Y mide «al menos un cambio de líder en
   `[0, τ]` partiendo de empate», que con ~400 eventos vale ≈1 **trivialmente**. La magnitud histórica
   es otra: el **instante del último cambio** dentro de la época y `P(hay un cambio DESPUÉS de 600 s)`.
   Compara la misma magnitud (ley del arcoseno para el último paso por cero) o di que no es comparable.
5. **`S_max_racional(capacidad)` es un artefacto, y este error venía en el encargo (es del
   diseñador).** Fija **un** SSD de 100 k IOPS para cualquier capacidad, y por eso da «0 flujos» a
   100 TiB, que es absurdo: un granjero de 100 TiB tiene ~25 discos y sus IOPS crecen con ellos. La
   variable correcta es **IOPS por TiB del medio**, no la capacidad total: con SSD de 4 TiB y 100 k
   IOPS sale `S ≈ 24` **a cualquier capacidad**, limitado después por núcleos (AES de verificación por
   flujo y 42,9 µs/sector/desafío de auditoría). Rehaz la curva con esa variable.

## Lo que sí se sostiene, y cómo debe decirse

Por primeros principios, y **con esta etiqueta estrecha**: bajo R-FIN-5 + R-FIN-7 **sin adopción** una
partición nacida es permanente **por construcción**, con o sin cobertura. **Con adopción**, la deriva
del peso es `∝ (1−c)(s₁−s₂)`: con cobertura total (`c → 1`) o reparto simétrico es nula y la partición
se sostiene; con cobertura parcial y reparto asimétrico el lado con más espacio gana en tiempo finito.
La pregunta de la puerta pasa a ser **cuánto vale `c` en equilibrio**, y eso sale de
`condicion_cobertura` evaluada con costes reales, que hoy no evalúas.

## Sobre 4.A, leído hasta ahora (validación incompleta: falta reejecutar)

Correcto: GDR-v0.2 por `include` y sin modificar; `entregar!` cierra la vista bajo ancestros y da la
clausura de publicación; el criterio de `α` existe. **A declarar en `MODELO.md` e `INFORME.md`:** el
**tope de 8 candidatos** por muestreo uniforme en V1 (cota **inferior** del poder del atacante, la
misma laguna que 9c con su tope de 10) y la **ventana `[T, T+45]`** de la familia base, que hereda el
«45 s» histórico que el encargo pedía no heredar: justifícala o bárrela.
