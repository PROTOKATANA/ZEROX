# Hipótesis que codifican la conclusión — ADL-v1.0

Este fichero separa las **identidades** del instrumento de las **premisas** que aún necesitan
evidencia. La conclusión del encargo («`D` resta en el régimen estacionario y `A = L + I − W_dec − D`
no depende de `ρ`») depende de las premisas 1, 2 y 5; si alguna cae, cae con ella.

## Identidades (aritmética, no requieren evidencia)

1. **Contabilidad de fronteras.** Sean `h(t)` y `a(t)` las fronteras de *slots firmables* del
   honesto y del atacante en el instante `t`, y `Γ(t)` el horizonte hasta el que están determinadas
   las inyecciones. Firmar el slot `s` exige (i) `PoT ≥ s + D` y (ii) `s + D ≤ Γ(t)`. De ahí

   ```text
   h(t) = mín( t , Γ(t) − D )        a(t) = mín( ρ·t , Γ(t) − D )
   A(t) = a(t) − h(t)
   ```

   **Es una identidad**, no una hipótesis: se sigue de escribir las dos restricciones. Lo que es
   premisa es *qué* es `Γ(t)` (premisa 2) y que el timekeeper honesto vaya `D` por delante
   (premisa 1).
   *Verificado:* `test/runtests.jl` §9 compara esta forma cerrada contra **Sim-v1**, que no la usa.

2. **`Γ(t) = t + I + L − W_dec`.** El horizonte de determinación del flujo. **Premisa con dos
   respaldos históricos independientes:** la «cota de lookahead `L + I`» de la ronda 7
   (`research/dag-poas-ancla-de-orden.md:249-250`) y «la ventaja máxima sobre el timekeeper es
   `L + I − W_dec`» de la ronda 9c (`research/scripts/d9-ronda9c/informe.md:255-259`). Los dos
   coinciden. **No verificado en red**: es un modelo de régimen, como el histórico.

3. **`L_slots := máx(F_slots, L_suelo_slots, S_max_slots+1)`** — `C-FLU-01`, `SPEC.md:1515`.
   **Verificado en fuente.**

4. **`reto(f,s)` usa `salida(f,s)` y `t_j = slot(I_j) + L`** — `C-POT-03` (`SPEC.md:1376-1390`) y
   `C-FLU-07` (`SPEC.md:1612-1620`). **Verificado en fuente.** Es lo que impide que `D` entre en el
   reto o en la activación, y por tanto la mitad del resultado.

5. **`A_con_h(ρ) = máx(0, (I + W_dec − 1) − (L + I)/ρ)`.** La forma con revelación retardada. Se
   reproduce desde `research/scripts/d8-ronda10a/informe.md:311-314` (ventaja `(L+I)(1−1/ρ)`) y
   `:103-111` (`ρ*`). Sus `ρ*` publicados (9,24 / 8,99) se reproducen con error < 0,1 %.
   **Etiqueta: reproducido, no medido.** El instrumento no simula el VDF.

## Premisas que necesitan evidencia

6. **El timekeeper honesto va `D` por delante de su frontera de bloques.** Es la lectura de
   `C-POT-05` (`SPEC.md:1405-1417`): el bloque del slot `s` lleva `salida(f, s+D)`, luego quien lo
   produce tiene que haber llegado a `s + D`. **Si en cambio el honesto mantuviera su timekeeper *en*
   la frontera y simplemente firmara `D` slots tarde, su frontera sería `t − D` y `D` se cancelaría
   en vez de restar.** Esta es **la premisa que decide el signo de la conclusión**, y es la única de
   las cinco que no tiene hoy respaldo ni en el SPEC ni en una medición: el SPEC fija el campo y la
   justificación, pero no escribe la disciplina de avance del timekeeper. **Se declara, no se
   esconde.** Qué la cerraría: una línea en `C-POT-05`/`C-TIMELORD-*` que fije la disciplina, o la
   medición de `slot(B) + D ≤ (posición del timekeeper)` en el prototipo `prototipos/pot-estable`.

7. **Viabilidad `D ≤ L_slots − W_dec`.** Con `D ≥ L_slots` el bloque del slot `s` necesitaría un
   ancla **futura** y ningún bloque avanzaría. **Derivado** de `C-POT-05` + `C-FLU-07`. Es el dominio
   donde el cálculo del adelanto tiene sentido; fuera de él la pregunta no es de seguridad.

8. **`D` no entra en el reto.** `C-POT-03` y `R-FIN-14(e)`
   (`research/dag-poas-ancla-de-orden.md:272-275`) lo prohíben. **Verificado en fuente.** Si se
   levantara la prohibición, el adelanto ganaría `+D`: se implementa como contrafactual (`A_add`) y
   se publica la región, para que la prohibición se pueda valorar.

9. **El coste de verificación de (h) es `c_v·(1 + L/I)` con `c_v = 96,1 ms/slot`.** `c_v` está
   **medido** en `research/dag-poas-ancla-de-orden.md:342` (`verify`, Ryzen 9 9950X3D, clon
   `subspace` @ `f8842d0`). La forma `1 + L/I` es **reproducida** de la ronda 10a
   (`research/scripts/d8-ronda10a/informe.md:745-755`). **No medido en ZEROX**: no hay
   implementación de las `q + 1` líneas.

10. **Régimen estacionario.** `A_core` y `A_con_h` son modelos de régimen; el **transitorio** (donde
    manda `(ρ−1)·t`) no está incluido. Con `t_obs = 10^6` slots, `ρ_trans ≈ 1,008`; **por debajo de
    ese umbral `A` no es una constante del diseño, es una función del horizonte**, y el instrumento
    lo publica así en lugar de dar un número.

## Lo que el instrumento **no** codifica

- `L_suelo_slots`, `I_slots`, `F_slots`, `W_dec`, `D`, `S_max` y `ρ_max` **no se fijan**: entran como
  símbolos por línea de comandos. Ningún resultado numérico es una constante escrita a mano.
- El VDF de la revelación retardada no se implementa ni se mide: `A_con_h` es la forma cerrada
  publicada.
- No se modela `π_DAG`, propagación, retarget durante el ataque, competencia entre soluciones del
  mismo slot ni el bootstrap completo.
- No se mide `ρ` real: el rango 1,5-2,5× es **estimación** de `research/pot-aes-asic-chacha.md:40-42`,
  cuyo estudio de Supranational sigue sin localizar (laguna heredada, declarada en la fuente).
