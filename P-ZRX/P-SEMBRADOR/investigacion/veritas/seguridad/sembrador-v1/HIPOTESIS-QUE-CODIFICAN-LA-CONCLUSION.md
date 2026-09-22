# Hipótesis que codifican la conclusión

Este fichero separa las identidades matemáticas del instrumento de las premisas que aún necesitan
evidencia. Fijarlas por definición vuelve condicional —y en parte tautológica— la región de
rentabilidad; por eso el instrumento no la presenta como una garantía del protocolo.

1. **Unidad atómica (`verificado en fuente` + `demostrado por inspección de dependencias`).** Un
   intento es un registro/pieza bajo
   `(public_key, sector_index, history_size, piece_offset)`, no un sector entero. El `SectorId` usa
   clave, índice e historia; el `piece_offset` deriva el registro y la semilla PoS por separado
   (`PDF/autonomys-subspace/crates/subspace-core-primitives/src/sectors.rs:54-127`). La auditoría
   lee solo el `s-bucket` elegido
   (`PDF/autonomys-subspace/crates/subspace-farmer-components/src/auditing.rs:54-103`) y el
   prover reconstruye y prueba el registro ganador
   (`PDF/autonomys-subspace/crates/subspace-farmer-components/src/proving.rs:243-328`). El verificador
   comprueba ese registro, su PoS y sus testigos KZG, sin un compromiso de que los demás registros
   del sector existan (`PDF/autonomys-subspace/crates/subspace-verification/src/lib.rs:228-346`).
   Esa clausura de dependencias demuestra una ruta de intento parcial. Lo **`no determinado`** es
   su coste y el kernel adversarial optimizado: el repositorio upstream no los implementa ni mide.

2. **Calibración del espacio (`verificado en fuente`).** Para `N_h` registros honestos y tasa
   esperada `lambda_sol` de soluciones válidas por slot, el rango se calibra para que la
   probabilidad atómica sea aproximadamente `p = lambda_sol/N_h`. En Autonomys, una tabla tiene
   prueba para el `s-bucket` con factor `NUM_CHUNKS/NUM_S_BUCKETS = 1/2`, y el test de distancia
   aporta aproximadamente `solution_range/2^64`; por tanto `p ≈ solution_range/2^65`. La inversa
   está escrita en `PDF/autonomys-subspace/crates/subspace-core-primitives/src/solutions.rs:26-58`.
   El parámetro `espacio_honesto` del instrumento es el efectivo `H := N_h/lambda_sol = 1/p`, no
   bytes ni GiB sin conversión. Así `H` entra realmente en el resultado.

3. **Reutilización en la ventana (`modelado`).** Una tabla/registro fabricado se prueba contra cada
   uno de los `w` retos futuros conocidos. Los retos se tratan como ensayos independientes, de modo
   que `q = 1-(1-1/H)^w` es la probabilidad de al menos un acierto y
   `mu=E[X]=w/H` es el número esperado de soluciones. Si una implementación exige rehacer trabajo
   por reto, ese trabajo debe entrar en `coste_intento`; si impide la reutilización, este modelo
   deja de aplicar. El número esperado de intentos hasta un candidato no vacío es `1/q`, pero el
   rendimiento de largo plazo es `1/mu` intentos por bloque: `E[X|X>0]=mu/q` cancela el factor `q`.

4. **Coste completo (`pendiente de medir`).** `coste_intento` incluye piezas o acceso archival,
   generación de la tabla PoS parcial, cálculo de chunks/testigos, auditorías de los `w` retos,
   memoria temporal, energía, amortización y almacenamiento hasta el slot ganador. Dividir el
   benchmark de sector completo entre sus piezas no es una medición válida por sí sola: el lote y
   la GPU pueden cambiar el coste marginal.

5. **Pago DAG (`no determinado`).** `recompensa` significa `pi_pago × recompensa_nominal`, con
   `pi_pago` igual a la probabilidad de que una solución válida termine siendo la copia pagable bajo
   selección, P1 y R-FIN-8′. El instrumento no supone `pi_pago = 1`; quien ejecute el barrido debe
   introducir el valor esperado. Tarifas, subsidio y madurez se expresan en la misma unidad que el
   coste.

6. **Ventana del núcleo (`verificado históricamente`, no regla nueva).** En régimen estacionario,
   `rho > 1` da `A = (L - W_dec) + I(1-1/rho)` aproximadamente; `rho <= 1` da cero retos futuros.
   El kernel resta un slot porque la frontera discreta termina en `t_(j+1)-1`, como hizo el
   instrumento histórico validado de ronda 10c. Para sensibilidad, usar `W_dec' = W_dec+1` en la
   fórmula continua equivale a esta convención. Esta diferencia de un slot debe conservarse al
   comparar resultados; no es una constante de consenso.

   La propuesta de flujo conserva `pot_output(B)=salida(f,slot(B)+D)` y declara que el argumento de
   *lookahead* histórico, escrito sobre la salida del propio slot, no se ha rehecho con `+D`
   (`P-FLUJO/propuesta/PROPUESTA-SPEC.md:644-650,993-995`). El instrumento no
   modela `D`: su ventana es el núcleo histórico parametrizado y la integración final queda
   pendiente.

7. **Régimen, no bootstrap (`modelado`).** Para `rho` apenas mayor que uno, alcanzar la ventana
   estacionaria puede tardar días. La rentabilidad que calcula el instrumento vale después de ese
   transitorio y no cobra el capital ni el tiempo del bootstrap.

8. **Distribución y estrategia (`modelado`).** El número de aciertos de una unidad en la ventana es
   binomial, `X ~ Binomial(w,1/H)`, y se cuentan todos sus aciertos pagables en slots distintos. El
   adversario es neutral al riesgo y el margen usa cocientes de expectativas en régimen. No se
   modelan límites de throughput, competencia entre varias soluciones en un slot, propagación,
   orfandad, retarget durante el ataque ni una defensa que exija antigüedad o permanencia. Si una
   regla futura permite como máximo un pago por unidad y ventana, el valor esperado pasa de `mu` a
   `q` y hay que evaluar esa variante.

Con estas hipótesis, `M = coste_intento / (recompensa × mu)` es una identidad: `M < 1` define la
región rentable, `M = 1` su frontera y `M > 1` la región no rentable. La investigación útil consiste
en medir `coste_intento`, `N_h`, `lambda_sol` y `pi_pago`, y en comprobar que la reutilización
realmente es posible.
