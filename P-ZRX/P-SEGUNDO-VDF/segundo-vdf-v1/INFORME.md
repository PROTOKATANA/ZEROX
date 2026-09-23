# INFORME — segundo VDF, SDV-v1.1 (revisión independiente)

**Veredicto: inconcluso para la seguridad de ZEROX frente a hardware sofisticado.** La afirmación de que dos líneas AES anulan la mejora queda refutada **como conclusión del instrumento**: procedía de omitir la duración secuencial. Tampoco queda demostrada una mejora protocolaria: las series de anclas no son trazas DAG validadas, el hardware adversario y la cadena larga no están medidos y falta resolver el orden de validación.

Por instrucción expresa del usuario, esta propuesta y su auditoría Julia viven únicamente en `P-ZRX/P-SEGUNDO-VDF/segundo-vdf-v1/` hasta que se validen; la pregunta dominante es seguridad, con consenso y rendimiento como temas secundarios. Ningún número adopta `I`, `Lrev`, `ρ_max`, `D`, `N(s)` ni una regla del SPEC. Presupuesto: hasta 24 hilos, 64 GiB de RAM y 8 GiB temporales; ejecución corregida con 4 hilos. Resultados, documentos y Manifest anteriores en `resultados/historico-deepseek-2026-09-23/`. El Manifest original arrastraba la entrada local `RevelacionV1`; `Pkg.resolve()` offline corrigió solo esa entrada y el hash del proyecto, conservando versiones. Modelo SDV-v1.1, Julia CPU, proyecto aislado.

## 1. Modelo causal y alcance de la traza

Para cada época `j` y candidato de ancla `v`, la cadena de revelación tiene semilla completa en `r_jv=max(t_PoT,t_chunk,t_flujo_previo,t_recepción)`, empieza en `b_jv ≥ r_jv` en una línea concreta y acaba en `f_jv = b_jv + Lrev/ρ`. Los cuatro tiempos pueden aportarse al kernel como vectores; sin ellos se aplica el supuesto optimista del escenario. Los intervalos `[b,f)` de una misma línea no se solapan. La barrera exige `τ_j ≥ max(a_j,c_j,f_jv)+1/ρ`, con `c_j` el instante de decisión del ancla, también suministrable. Esperar impone `b ≥ c`; especular permite `b < c` solo con **todos** los bytes de la semilla del candidato y una línea asignada. El PoT principal usa un recurso adicional. `ρ` es velocidad secuencial relativa; la convención `τ_nom=1 s/slot` convierte los tiempos del escenario, sin ser regla de consenso.

`src/modelo.jl` asigna líneas finitas **en orden de época con elección codiciosa de línea**, y registra `r,c,línea,b,f` en `resultados/TRAZA-CAUSAL.txt` para anclas propias, ajenas y mixtas, con ambas semillas. Es una agenda causal válida bajo sus entradas, **no un óptimo adversarial** cuando las semillas se conocen fuera de orden. `revelacion_instantanea=true` fija `f=r` **solo como control ideal**. La semilla C-FLU-12 propia presupone que el PoT anterior alcanzó `s_j+D`; h.1 presupone `s_j`. La ajena presupone recepción de bloque con `chunk` y `pot_output` válidos en `max(t_PoT(s_j),s_j)`. En el modelo la decisión propia coincide con `r` y la ajena con `r+W_dec` si espera. Son **hipótesis favorables al atacante**, no fechas derivadas de una vista DAG.

La disponibilidad real de la semilla requiere además `chunk(I_j)`, flujo previo y, para ancla ajena, recepción y acreditación del bloque. `C-FLU-03/04` decide el ancla con `Chn(V_j(B))`, que puede cambiar antes de `t_j`; el modelo no genera ese sub-DAG ni prueba PoAS, PoT, padres, `C-FLU-14` o `C-FLU-21`. Una lista Bernoulli de «propia/ajena» **no** acredita una traza adversarial válida. Si se especula sobre más de un `chunk(I_j)` o bloques rivales, hay una semilla y una cadena por variante; su cardinalidad y agenda óptima quedan pendientes. `[T_j,T_j+S_max)` contiene `S_max=150` slots enteros, pero puede contener más de 150 candidatos de bloque/chunk. Las cifras de un candidato por época no son cotas de ese conjunto.

El objeto calculado es `V(t)=Φ_a(t)−Φ_h(t)`, ventana de frontera PoT del modelo, **no** probabilidad de reversión, `blue_work` ni finalidad de un pago.

## 2. Resultados reproducidos con alcance preciso

Escenario **elegido para comparar modelos**, no parámetro de consenso: `L=7200`, `S_max=150`, `Lrev=7050`, `I∈{851,4666}` slots; `W_dec=20 s=20 slots` nominales, `D=4` slots y `ρ=2,5`. `J=1500`. Las cuatro columnas siguientes son `V_max` **determinista con anclas ajenas y offset cero**; la espera reproduce REV-v1.0. Fuente: `resultados/REGIMENES.txt`.

| `I` (slots) | sin `(h)` | espera hasta `c`, luego AES | AES causal en líneas finitas | control instantáneo | reducción causal | líneas AES de revelación por caudal |
|---:|---:|---:|---:|---:|---:|---:|
| 851 | 7685,60 | 4865,60 | 4885,60 | 7685,60 | 36,43 % | 9 |
| 4666 | 9974,60 | 7154,60 | 7174,60 | 9974,60 | 28,07 % | 2 |

`⌈Lrev/I⌉` da capacidad para **una semilla por época** si sus llegadas están separadas `I/ρ` en tiempo físico, como aproximación para anclas propias. La traza de anclas ajenas tiene llegadas más separadas y usa una sola línea de revelación. En la agenda que exige dos líneas debe añadirse la línea PoT principal: `I=4666` supone **2+1=3 líneas** adversarias, no «2 frente a 3» como comparación total. Las 3 líneas del timekeeper siguen otra agenda (`⌈L/I⌉+1`), y throughput, simultaneidad, consumo y candidatos no están igualados. Ninguna cantidad de líneas elimina `Lrev/ρ=2820 s` de una cadena cuya semilla acaba de conocerse. REV-v1.0 ya contemplaba una línea de revelación paralela y conservaba esa latencia; el control externo se reproduce dentro de 0,05 slots. El 0 % original solo describe el control instantáneo.

Como **ejemplo de carga, no cota de candidatos**, el artefacto calcula `150` slots × `1/2` variantes de chunk: a `I=4666`, capacidad de `227/454` líneas de revelación; a `I=851`, `1243/2486`. Estas cuentas suponen que todas las semillas están disponibles con la cadencia elegida, y no prueban que esos candidatos existan ni que todas sus cadenas lleguen antes de la decisión. En el DAG puede haber más de una variante por slot y no se conoce un máximo protocolario de chunks relevantes.

Los **q99** de `resultados/ESCENARIOS.txt` son otra medida: `α=0,33` para anclas mixtas, offset geométrico truncado, 64 réplicas, semilla `0x5a5a`, `ρ=2,5`, histograma de 64 slots y extremo inferior del bin. Comparan **sin `(h)` frente a espera REV**, no la agenda causal ni `V_max` determinista.

| `I` | q99 sin `(h)` → espera REV (slots) | factor |
|---:|---:|---:|
| 851 | 9280 → 6464 | 1,436 |
| 4666 | 19008 → 16192 | 1,174 |

El informe anterior ponía `9280→6528` y `19072→16256`: no coincidía con su propio artefacto. `resultados/SEMILLA.txt` compara C-FLU-12 con h.1 bajo los supuestos de disponibilidad anteriores: `V_max` determinista para anclas propias/ajenas y **media de máximos por réplica** para las mixtas. Su igualdad a cuatro decimales es un resultado del modelo de frontera, no equivalencia criptográfica, de DAG ni de todas las distribuciones.

## 3. Calibración y recursos

Con `ρ_max=p/q>1`, el criterio cerrado `ρ*=(Lrev+I)/(I+W_dec)≥ρ_max` equivale exactamente a `I≤(q·Lrev−p·W_dec)/(p−q)`. En el escenario `p/q=5/2`: frontera `14000/3`, `I_max=4666`, `ρ*(4666)=5858/2343≥5/2`. La fila histórica redondeada `I=4767` da `11817/4787<5/2`; usó `L` en vez de `Lrev`. `I≥ρ_max W_dec` e `I>S_max` son restricciones adicionales del perfil; el mínimo entero aquí es 151.

`√(7050/20)≈18,775` es solo una **condición continua necesaria** del criterio cerrado. Optimizando exactamente sobre `I` entero con esas desigualdades, `ρ_max=3713/198≈18,752525` en `I=376`. La expresión `(Lrev+S_max+1)/(W_dec+S_max+1)` usa el primer `I` entero admisible y lleva `≤`; para `I>S_max` real el borde estricto es `(Lrev+S_max)/(W_dec+S_max)`. Son cotas del criterio cerrado y del escenario, no de hardware medido ni de todo protocolo posible.

`prove=1,561347 s/slot` y `verify=0,096147 s/slot` son **medidas históricas de un slot**, Ryzen 9 9950X3D, a `N=200032000` iteraciones. El tamaño nominal de cadena usa **otro** `N=206557520`: `T=7050·N=1456230516000` iteraciones, derivado. Los núcleos y segundos por época de `resultados/COSTE.txt` son **extrapolaciones estimadas** de las medidas de un slot. Su coste real de producir/verificar queda **pendiente**.

La API pública `zx-pot::prove/verify` recibe `NonZeroU32` y deriva la clave de cada semilla. Una llamada nominal llega a 20 slots; encadenar llamadas cambia la clave. También `aes::create/verify_sequential` usa `u32` por tramo: exponerlas solas no resuelve `T`. Haría falta definir segmentos de **clave fija**, sus enlaces y pruebas, la prueba transportada y vectores de equivalencia; el límite teórico es al menos 43 segmentos con ocho contadores `u32`. Los 32 vectores upstream prueban la primitiva actual, no esa ampliación. No se modificó `zx-pot`.

## 4. Consenso y conclusión

Hoy `C-FLU-14` deriva el flujo sin AES porque `C-FLU-12` toma campos de cabecera del pasado validado; `C-POT-08` hace ese paso **antes** de caché y AES. Si `C-FLU-10` pasara a depender de la salida del segundo AES, esa salida tendría que acreditarse desde un contexto anterior a la inyección **antes** de derivar el flujo y consultar `C-POT-07`. La caché indexada por el flujo nuevo no puede acreditar primero la salida que define ese mismo flujo. Sin un orden y prueba no circulares, corresponde **Pendiente**; el instrumento no los resuelve. El nodo real aún carece de verificador PoT/DAG contextual integrado.

El oráculo racional max-plus y el kernel coinciden exactamente en **384** casos (incluidas dos líneas causales), con `Δτ=0`; los controles externos REV/ADL mantienen error máximo `<0,05` slots. Esto valida aritmética del modelo declarado, no sus premisas. `C8/C9` separan revelación instantánea de latencia secuencial. La semilla CLI controla las tablas aleatorias; misma semilla reproduce y distinta semilla cambia salidas pertinentes. El benchmark corregido inició procesos reales de `1/2/4/8/16` hilos: para `R=256`, 12 valores de `ρ`, tiempos `360,85/190,91/119,23/73,61/61,35 ms` en esta corrida; la réplica individual asigna 64 B y usa 0,144–0,146 ms de mediana. Datos completos en `resultados/BENCH-CORREGIDO.txt`; no se reutiliza el escalado anterior.

**Alcance final:** la reducción de `V_max` frente al control sin `(h)` está **derivada y reproducida dentro del modelo causal simplificado**. La tesis «dos líneas anulan la mejora» está **refutada dentro de ese modelo**; el caso 0 % era contrafáctico. La mejora frente a un atacante con hardware sofisticado en ZEROX sigue **inconclusa** hasta acreditar trazas DAG adversariales, candidatos y semillas, medir `ρ_max` y la primitiva larga, resolver validación no circular y traducir `V` a riesgo de finalidad bajo red medida.
