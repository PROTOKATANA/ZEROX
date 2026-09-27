# BITACORA.md — P-RELOJ / `reloj-adaptativo-v1`

Registro de lo que se hizo, **incluidos los errores**. Lo que se corrigió está con su causa.

## E0 · Apertura

- 2026-09-24 12:15 · `sha256sum -c ENTRADA.sha256`: **5/5 OK**. `git status --short` y `date` en
  `investigacion/PROGRESO.md` E1. Nada de lo que aparecía `M`/`??` era de este encargo.
- Presupuesto declarado **antes** de ejecutar: 4 hilos, 8 GiB, 2 GiB de disco, minutos por corrida.

## E1 · Reproducción del ancla

- `aeslat.c` compilado **desde `medicion-previa/` sin modificarlo**, binario en la zona de
  escritura. Resultado: **7,7230 ns/bloque** frente a 7,7716 → **−0,63 %**. **Ancla reproducida.**
- Decisión que se tomó aquí: no seguir hasta tener **ciclos**, no nanosegundos. Con `perf_event_open`
  se obtienen los dos relojes a la vez y la frecuencia deja de ser una suposición.

## E2 · Latencia de instrucción, y el control que la hace creíble

- `aesinst.c`: latencia y rendimiento por instrucción, con PMU. **`pxor` da 2,000 ciclos** (control
  positivo: es la latencia tabulada en Zen 4/5) y **el bloque del PoT da 42,01 ciclos** = 10 × 4,001
  + 2 del `pxor` y el lazo. Sin esos dos controles la medición no se habría aceptado.
- **`AESENC` xmm: 4,001 ciclos.** Es el número que decide F3 y que contradice la fila resumen de
  uops.info, cuyos propios datos crudos dan ≈ 4,05.

## E3 · El «tercio de latencia»: la medición que lo rompe

- `carga.c` mide la MISMA cadena con 0, 1, 4, 8 y 16 hilos ocupados: **los ciclos no cambian**
  (42,01 ± 0,004) y **la frecuencia baja** (5,393 → 5,350 GHz). Si el tercio fuera arquitectural,
  los ciclos subirían. **No suben.**
- **Consecuencia:** F3 refutada en la dirección que importa. «No se compra con un AMD mejor» es
  falso: **se compra con frecuencia**, y los 4 ciclos de AMD frente a los 3 de Intel no son un suelo
  de `ρ` por fabricante.

## E4 · Verificar: el factor de paralelismo, medido

- `verif8.c`: **8,02×** (escalar frente a AVX-512+VAES con 8 tramos). El valor ideal `K = 8` se
  alcanza.
- `verif16.c`: escala casi lineal hasta **16 carriles**; 2,627 ciclos/bloque, o sea 0,263 ciclos por
  instrucción VAES-512. **Es la cota superior de `K`**, y sin ella `S ≤ ε·K` no se podría escribir.

## E5 · El primer error, y cómo se encontró

- Escribí `sesgo_mediana_adversario` devolviendo **0 sin mayoría**, «porque la mediana es honesta».
  **Falso:** el adversario no necesita la mediana para **desplazarla**; le basta con ocupar
  posiciones. Lo encontró el oráculo por programación dinámica, no yo.

## E6 · El segundo error, y la degradación que lo arregla

- La versión corregida daba una **igualdad**. Sobre un barrido de 660 combinaciones de
  `(W, C, δ, φ)` aparecieron **294 discrepancias**. Se degradó a **cota inferior**, que es el lado
  seguro —promete **menos** ataque del que hay, nunca más— y las discrepancias se **cuentan y se
  publican** en `resultados/manipulacion.md` §3.
- **El error iba en la dirección peligrosa** (habría subestimado el ataque en un informe de
  seguridad), y por eso queda escrito aquí y en `METODO.md` §6.

## E7 · El tercer error: el oráculo no modela el protocolo

- Con `W = 51, C = 48, δ = φ = 0` el oráculo da mediana **2 s** donde la escala honesta daría **25 s**.
  El motivo: modela los timestamps como **una sola cadena monótona global**, y en el protocolo cada
  bloque honesto tiene **su propio reloj**. Está declarado **inconcluso** fuera del régimen de
  mayoría, con el caso que lo rompe escrito en el propio fichero de resultados.

## E8 · El cuarto error: exigir identidad bit a bit donde no la hay

- El test de `simular!` contra `simular_exacto` exigía trazas idénticas. **Fallaba**, y la causa era
  el redondeo del objetivo `τ = N·t_bloque`, no la ley de control. Se cambió el contrato: se
  comparan **los signos de los ajustes** (invariante del modelo) y se **declara** la discrepancia de
  trayectoria (16 y 80 unidades de `N`), que una recurrencia compone.

## E9 · El quinto: el borde de `(ADM)` decide por 1 ULP

- El cociente `t_v/(K·t_p)` en `Float64` no es el binario del cociente real: en la frontera exacta el
  kernel rápido puede dar un veredicto y el oráculo exacto el contrario. **No es un defecto**, es
  aritmética binaria. Se documenta, el test lo comprueba (≤ 1 ULP) y la decisión de borde se toma
  **en `Rational{BigInt}`**.

## E11 · Dos errores que encontró el revisor, corregidos

- **`1,52×` en F3.** Se multiplicó ciclos **por ronda** (1,333) por frecuencia **por bloque** (1,141).
  Con ciclos **por bloque**: 42,01/30 = 1,400 × 1,141 = **1,598**, que coincide con la fila de ns
  (7,739/4,841 = 1,599). El 1,605 del encargo era correcto. **F3 no cambia de veredicto** —la
  latencia en ciclos no es un suelo por fabricante—, pero el número sí.
- **`ε_min = 1/(ρ·K)`.** La correcta es **`ρ/K`**, porque `ρ := t_s/t_f` es la MISMA cantidad que la
  frontera, no su recíproca (`t_p` es el más rápido). `ρ = 3`, `K = 16`: 18,75 % frente a 2,08 %, un
  factor 9. Lo cierra que con `ε = 2,08 %` la tabla da `ρ_max = 0,33`, que no admite ni `S = 1`.
  **F7 no cambia**; la caja sí, y ahora lleva tests de regresión que fallan si se vuelve a invertir.
- Los dos errores son **míos**, los dos los encontró el revisor del informe, y los dos quedan con su
  comprobación escrita. El vocabulario de `ρ` se unificó en `MODELO.md`, el informe, `run.jl`, la
  tabla generada y las funciones de `src/`, para que no vuelva a torcerse por analogía.

## E10 · Cierre

- **1071/1071 aserciones OK. 39/39 casos de validación OK, 25 con rutas independientes.**
- El benchmark decidió **no optimizar**: `simular_rapido!` (16,56 µs) **no gana** a `simular!`
  (16,17 µs), y el oráculo DP (889 ms, 820 MiB) es caro **a propósito** porque es el oráculo.
- Comprobación de salida en `PROGRESO.md`: `sha256sum -c` de entrada (5/5 OK), `git status --short`,
  `date`. `PROMPT.md` y `medicion-previa/` intactos.
