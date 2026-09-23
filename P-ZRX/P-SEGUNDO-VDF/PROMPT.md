# Encargo P-SEGUNDO-VDF — validar la revelación retardada para ZEROX

=== INICIO DEL PROMPT PARA DEEPSEEK — P-SEGUNDO-VDF ===

Trabajas en `/home/katana/zeo/ZEROX`. Responde en español. Katana quiere evaluar seriamente la
incorporación de una **segunda cadena secuencial AES de revelación retardada** para fortalecer
ZEROX frente a un reloj PoT más rápido, incluso el de un atacante con recursos de laboratorio o
estatales. Tu trabajo es intentar validar o refutar **el beneficio neto y el protocolo concreto**,
con el coste de hardware delante. Una mejora de una métrica del modelo no demuestra por sí sola
una mejora de finalidad, ni autoriza cambiar el SPEC.

## Reglas de trabajo

Lee primero `AGENTS.md`, `README.md`, `MIGRACION.md`, `research/README.md`, `TAREAS.md` §2.1 y
§2.9, y las reglas pertinentes de `SPEC.md`: `C-POT-01`…`08`, `C-FLU-01`, `C-FLU-04`…`16`,
`C-FLU-21/22`, `C-NET-31`…`33` y `C-FIN-01`. Lee **íntegro** `veritas/LINEO.md` antes de escribir
un test, simulación o auditoría de cálculo. Consulta `git status --short` y los diffs pertinentes:
el árbol tiene cambios ajenos sin consolidar, incluidos los avances de 03c en `crates/`.
No hagas commit, push, stash ni cambio de rama. No modifiques el vault externo.

**Bloque obligatorio de `veritas/LINEO.md` §8, copiado literalmente:**

> Eres especialista senior en Julia para cómputo científico reproducible, teoría de protocolos y
> optimización de alto rendimiento. Antes de escribir o modificar código, lee por completo
> `veritas/LINEO.md` y cumple todas sus reglas.
>
> Tu prioridad conjunta es: **(1) resultado matemáticamente verdadero y reproducible; (2) el máximo
> rendimiento medido compatible con esa verdad.** No aceptes un programa lento sin un perfil, ni una
> aceleración sin una prueba contra un oráculo independiente.
>
> Procedimiento obligatorio:
>
> 1. Formula el modelo matemático, la complejidad temporal/espacial y el adversario/caso de borde
>    relevante antes de elegir la estructura de datos.
> 2. Diseña la representación para la operación dominante: tipos concretos, arrays contiguos,
>    SoA frente a AoS, IDs densos, `BitVector`/CSR/`StaticArrays`/`Dict` solo cuando el caso lo
>    justifique. Explica brevemente la elección.
> 3. Escribe primero una referencia pequeña, transparente y preferiblemente exacta; crea tests de
>    bordes, invariantes, contraejemplos previos y semillas fijas.
> 4. Implementa el kernel rápido dentro de funciones tipoestables, sin globals dinámicos ni `Any`.
>    Preasigna memoria, usa versiones mutantes (`!`), evita asignaciones y respeta el orden de
>    columnas. No materialices combinaciones, grafos o temporales innecesarios.
> 5. Valida el kernel rápido contra la referencia en instancias pequeñas, propiedades aleatorias y
>    todos los vectores de regresión. Para umbrales numéricos, certifica con exactitud, intervalos o
>    aritmética de bolas; si el margen no se puede certificar, declara el resultado inconcluso.
> 6. Mide el caso representativo tras calentar JIT con `BenchmarkTools`; perfila CPU/memoria con
>    `Profile`, `@allocated`, `@code_warntype` y JET. Optimiza el cuello real, no el supuesto.
> 7. Paraleliza solo trabajo independiente y usa RNG por réplica/chunk, reducción determinista y
>    ausencia demostrada de carreras. Arranca batch CPU-bound dentro del tope de 24 hilos (8 lógicos
>    quedan para el sistema), mide el escalado `1…24` y conserva la configuración que gane
>    realmente, aunque use menos hilos; evita BLAS anidado.
> 8. Considera `LoopVectorization` o MPI únicamente si el perfil demuestra un kernel regular
>    dominante y el coste no lo anula. Para GPU **no uses Julia**: escribe el kernel en C++/CUDA
>    (§5.7), con oráculo CPU estricto, transferencias medidas y `compute-sanitizer`. Compara siempre
>    con CPU estricta.
> 9. No uses `@fastmath`. `@inbounds`, `@simd`, `@turbo` o precisión `Float32` requieren prueba de
>    equivalencia, comentario de supuestos y benchmark. Nunca dejes que una optimización cambie un
>    veredicto sin declararlo.
> 10. Entrega `Project.toml`, `Manifest.toml`, comando exacto, semilla, versión/hardware, tabla de
>     rendimiento, número de asignaciones y resultado de la validación. Distingue con claridad lo
>     demostrado, medido, estimado y no demostrado.
>
> 11. Declara antes de ejecutar el presupuesto de tiempo, memoria y disco (en la máquina de
>     referencia: máximo 64 GiB de RAM y 24 hilos). Si se agota, conserva el checkpoint y reporta
>     **inconcluso**; guarda semilla, parámetros, configuración y una entrada mínima reproducible
>     para cada fallo. No confundas timeout con evidencia de falsedad.
>
> Si una corrida supera el presupuesto declarado, detente antes de ampliar la exploración y produce
> un perfil más una hipótesis de cuello de botella. Propón la mejora algorítmica o de datos de mayor
> impacto y verifica que conserva resultados antes de lanzar otra corrida larga.

**Ubicación actual por instrucción posterior del usuario:** la aritmética, la simulación y el
análisis de coste CPU de esta propuesta viven en `P-ZRX/P-SEGUNDO-VDF/segundo-vdf-v1/`, con
Julia en CPU y proyecto/manifest propios. C++/CUDA solo
si un perfil justifica investigar GPU; nunca Python, ni para ejecutar instrumentos históricos.
Los tests de código Rust existente siguen junto a sus crates. No conviertas un benchmark de un
slot del PoT principal en una medición de la segunda cadena completa.

## 1. Entradas y pregunta exacta

Lee y contrasta, sin tratarlos como autoridad normativa:

- `P-ZRX/P-REVELACION/investigacion/INFORME.md`, los documentos
  `DECISIONES-PENDIENTES.md` y `CORRECCIONES-A-P-ADELANTO.md` de ese mismo directorio, y
  `P-ZRX/P-REVELACION/investigacion/veritas/seguridad/revelacion-v1/`
  (`HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md` y resultados);
- `research/scripts/d8-ronda10a/informe.md` §A.6, **solo como texto histórico**; no ejecutes sus
  programas Python;
- `P-ZRX/T-ZRX/AGUJEROS-Y-SOLUCIONES.md` §2,
  `P-ZRX/T-ZRX/ESTADO-DOBLE-FARMEO.md`, `P-ZRX/P-INTENTO/investigacion/INFORME.md` y
  `research/pot-aes-asic-chacha.md`;
- `crates/zx-pot` y `crates/zx-consensus/src/pot.rs` como estado de la primitiva incorporada, sin
  asumir que ya existe una segunda cadena o un nodo PoST+DAG funcional.

**Pregunta:** para cada escenario de adversario y red declarado, ¿cuánto reduce la segunda cadena
la ventana de adelanto `V` (en slots) y el sesgo del ancla, y qué coste exige al timekeeper, al
nodo que verifica, al nodo que se incorpora tarde y a quien adopta un flujo rival? ¿Hay una
región de parámetros **realizable** donde la mejora sigue en pie bajo el mismo riesgo y escenario?
No presupongas un valor de `ρ_max` por llamar «estatal» al atacante: dinero, paralelismo y razón
de **latencia secuencial** `ρ` son variables distintas. Incluye sensibilidad a ventajas superiores
a la estimación física histórica y deja `ρ_max` pendiente si no hay medida defendible.

## 2. Defectos conocidos que debes resolver antes de publicar una ganancia

1. **Calibración (h.6).** La candidata fija `Lrev = L − S_max` y usa
   `ρ* = (Lrev + I)/(I + W_dec)`, pero calibra `I` con `L` en el numerador. Deriva de nuevo la
   condición `ρ* ≥ ρ_max` con unidades y enteros correctos. Control obligatorio: en el escenario
   histórico `L=7.200` slots, `S_max=150` slots, `W_dec=20 s` convertidos por el modelo con
   `τ_nom=1 s/slot`,
   `ρ_max=2,5`, su tabla usa `I≈4.767` slots y da `ρ*=2,469 < 2,5`. Explica por qué eso no cumple
   su criterio y calcula la frontera correcta **sin adoptarla como parámetro**. Incluye las otras
   restricciones vigentes sobre `I`, la puntualidad honesta y el redondeo de slots.
2. **Escenarios mezclados.** La reducción `V_max=7.685,6 → 4.865,6` slots con `ρ=2,5`, y la edad
   q99 `8.800 → 5.712` slots con `F=7.200`, `α=0,33` y `ρ_max=2,5`, salen de `I=851` slots;
   el coste anunciado de `0,241` núcleos y tres
   líneas usa `I≈4.767`. Reconstruye cada fila con el **mismo** `I`, `L`, `Lrev`, `F`, `D`,
   `W_dec`, `α`, `ρ`, política de adversario, riesgo y hardware en ambas alternativas. Publica
   `ΔV/V_sin` y coste conjuntamente. Etiqueta esas cifras históricas como **escenarios, no
   parámetros elegidos**. Reproduce primero las filas viejas como control y después recalcula.
3. **Semilla causal.** La candidata (h.1) parte de `chunk(I_j) ‖ salida(f,slot(I_j))`; el vigente
   `C-FLU-12` usa `chunk(I_j) ‖ pot_output(I_j)`, con `pot_output` **futuro** en
   `slot(I_j)+D`, y REV modela la disponibilidad de este último. Evalúa ambas variantes con la
   misma comparación y documenta la fecha en que cada entrada se conoce, la resistencia al
   grinding, la unicidad por billete y las posibles dependencias circulares. **No elijas una
   semilla por comodidad de implementación.** Si la elección requiere decisión de Katana,
   entrega ambas y marca el veredicto condicionado.
4. **Orden de consenso.** `C-FLU-10` deriva el flujo de la entropía; `C-FLU-14` y `C-POT-08`
   comprueban consistencia de flujo **antes y sin AES**. Si la entropía requiere otra cadena AES,
   ese orden deja de ser literal en un flujo nuevo o rival. Analiza orden, caché contextual,
   estados `Inválido/Pendiente/Válido`, DoS y presupuesto bajo `C-NET-33`/`C-FLU-22`.
   Señala **todos** los IDs afectados: no afirmes que basta cambiar `C-FLU-12`.
5. **Primitiva y coste real.** La candidata escribe `Lrev·N(slot(I_j))` iteraciones con `N`
   congelado en el ancla. `zx-pot::prove/verify` acepta `NonZeroU32` para **un slot**. Demuestra
   cómo segmentar y verificar la cadena larga sin reiniciar indebidamente la clave AES ni cambiar
   la función; conserva los vectores existentes. Contrasta coste de producción, verificación y
   recuperación de checkpoints; distingue medida en la segunda cadena, medida previa de un slot
   y extrapolación. Si no puedes hacer una medición fiel dentro del presupuesto, deja ese coste
   **pendiente** y la decisión de adopción **inconclusa**.

## 3. Modelo, adversario y controles

Construye primero una referencia clara y exacta para trazas pequeñas; contrástala con un kernel
más rápido solo si el perfil lo justifica. El adversario puede esperar la decisión del ancla o
especular sobre candidatos, poseer rachas de anclas, retener PoT, correr varias líneas y controlar
parte de la red. Declara por separado qué resultados incluyen partición/eclipses y cuáles no.
Comprueba que toda traza adversarial usada cumple `C-FLU-02`, `C-FLU-13/14`, `C-FLU-21/22` y
`C-FIN-01`; una traza fuera de validez no mide seguridad del destino.

Usa entradas emparejadas y semillas comunes para comparar sin/con revelación. Reporta, por
separado: máximo de `V`, distribución temporal (al menos q99 y tasa de excedencia), umbral y
frecuencia de *steering*, disponibilidad/latencia del honesto, consumo por línea, consumo del
verificador y coste de ponerse al día o de verificar una rama rival. Da escenarios con `ρ`
cercano a 1 y con ventajas mayores, incluida sensibilidad más allá del rango ASIC estimado.
`ρ*` es umbral de *steering*, **no** porcentaje de mejora de finalidad; reducir `V` tampoco es
reducir la probabilidad de doble gasto en ese mismo porcentaje. Para relacionarlo con seguridad
económica o finalidad necesitarías un modelo adicional bajo el mismo adversario y riesgo.

Comprueba al menos estos controles independientes: sin segunda cadena recuperas el PoT vigente;
`ρ=1` no crea adelanto por velocidad; la ventaja de `ρ>1` no se anula mágicamente con la
segunda cadena; `ρ→∞` revela el límite del mecanismo; el coste de rachas no se sustituye por una
media; la puntualidad del honesto falla si la revelación llega tarde; un presupuesto agotado es
`Pendiente`, no `Inválido`. Trata el doble farmeo como **control negativo**: un segundo reloj
paralelo no demuestra exclusividad de espacio entre ramas.

## 4. Hardware, red y criterio de decisión

Separa **líneas secuenciales simultáneas** del timekeeper de fracción de núcleo gastada por un
nodo al verificar; mide la primera en hardware representativo o marca el alcance. La medición
de `96,1 ms/slot` y la estimación de `ρ=1,5–2,5` del material histórico **no** son una cota de
un ASIC sofisticado. Estudia también el coste de un nodo sin aceleración AES y el caso C4:
una partición donde un lado tiene menos líneas que las necesarias para continuar o adoptar.
Para `C-FLU-22` y `C-NET-33`, deriva tanto el trabajo mínimo para comprobar una rama rival
dentro de su ventana como un techo frente a inundación; si no hay techo sustentable, dilo.
No confundas volumen de gossip con disponibilidad de checkpoints ni con capacidad de verificar
los que faltan. Evalúa cambios del calendario `N(s)` en `t_j` con `N` congelado para la cadena
extra y comprueba que sigue habiendo puntualidad.

Cada cifra del informe debe traer: valor y unidad; variable y definición; versión del modelo;
fuente; adversario; criterio de aceptación; y estado **elegido, medido, derivado o pendiente**.
Los benchmarks especifican CPU, reloj/frecuencia observada, instrucciones AES disponibles,
versión del código, carga concurrente, hilos y comando. Declara antes de ejecutar presupuesto
de tiempo, RAM, hilos y disco dentro de `LINEO.md`. No extrapoles un benchmark corto a horas
sin comprobar invariantes de la implementación larga y el coste de varias líneas simultáneas.

## 5. Entrega y límites de edición

Entrega en `P-ZRX/P-SEGUNDO-VDF/segundo-vdf-v1/` el proyecto Julia fijado, referencia, tests,
comandos, resultados reproducibles, `CONTRATO.md`, `HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md`
e `INFORME.md`. En el informe, abre con una tabla de **beneficio y hardware bajo el mismo
escenario** y un veredicto por alcance: `VALIDADO EN EL MODELO`, `REFUTADO` o `INCONCLUSO`;
ninguno significa automáticamente «regla lista para producción». Añade un mapa de reglas que
habría que revisar y las decisiones pendientes para Katana. Conserva el modelo REV-v1.0 y sus
resultados sin reescribirlos; documenta cada corrección con un control que habría detectado el
error original. Si algún resultado depende de una fuente primaria externa, identifícala con
versión o fecha y deja claro qué infieres de ella.

No edites `SPEC.md`, `TAREAS.md`, `ci/`, `crates/zx-node/` ni los P-ZRX históricos. No integres
la cadena extra en consenso activo, ni fijes `ρ_max`, `I`, `Lrev`, `F`, `L_suelo`, `D`, `N(s)` o
presupuestos. Para una prueba de implementación, reutiliza la primitiva auditada y comprueba
equivalencia con los vectores upstream y `zx-pot`: no reimplementes AES ni simules una cadena larga
mediante llamadas de un slot que cambian su semántica. Si esa reutilización no es posible en el
instrumento, deja la medición pendiente. **No** declares adoptado el mecanismo ni alteres la
primitiva auditada. Lista todos los archivos modificados,
las pruebas ejecutadas y los límites que impiden afirmar una mejora global de seguridad.

=== FIN DEL PROMPT PARA DEEPSEEK — P-SEGUNDO-VDF ===
