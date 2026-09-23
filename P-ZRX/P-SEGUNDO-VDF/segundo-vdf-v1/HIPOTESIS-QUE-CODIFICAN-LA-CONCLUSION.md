# Hipótesis que codifican la conclusión — SDV-v1.1

## Identidades del modelo

1. Para cada candidata, semilla completa en `r`, decisión del ancla en `c`, inicio `b≥r`, fin `f=b+Lrev/ρ`. Una línea no ejecuta dos intervalos `[b,f)` solapados. La barrera se cruza después de `max(a,c,f)` y su propio coste `1/ρ`. Estos límites se prueban en `test/runtests.jl`.
2. `revelacion_instantanea` omite deliberadamente la cadena y sirve solo de control. No se interpreta como adversario físico.
3. `ρ*=(Lrev+I)/(I+W_dec)` es umbral del criterio cerrado de steering. `I_max=⌊(Lrev−ρ_max·W_dec)/(ρ_max−1)⌋` para `ρ_max>1`. Bajo `I≥ρ_max W_dec` e `I>S_max`, el escenario `Lrev=7050,W_dec=20,S_max=150` alcanza `ρ_max=3713/198` en `I=376`; la raíz continua es solo necesaria.
4. `⌈Lrev/I⌉` cuenta throughput de **una candidata por época** separada `I/ρ`, además del PoT principal; no acorta `Lrev/ρ`. El coste para varias variantes de chunk depende de cuántas sean, de su fecha de conocimiento y de la agenda.

## Supuestos explícitos de la simulación

- C-FLU-12 usa `chunk(I_j)‖pot_output(I_j)` con salida de PoT en `s_j+D`; h.1 usa la salida en `s_j`. Para ancla propia, el modelo **supone** que el chunk elegido y el flujo previo ya están disponibles cuando se alcanza esa salida. Para ajena, **supone** recepción del bloque y de todos los bytes al instante `max(t_PoT(s_j),s_j)`. No mide relé ni verifica el bloque.
- La decisión propia se identifica con la disponibilidad de la semilla. Para ajena con `espera=true`, se añade `W_dec`. La decisión real es `Chn(V_j(B))` y podría variar antes de `t_j`; no se calcula aquí.
- Se agenda solo la candidata finalmente elegida, sin enumerar especulación sobre otras anclas, bloques o `chunk(I_j)`. Si se reclama especulación realizable, hay que proporcionar candidatos y tiempos de todos sus ingredientes, agenda de líneas y prueba DAG.
- La asignación codiciosa procesa épocas por índice, aunque en una mezcla una semilla posterior pueda conocerse antes que una anterior. Sus intervalos son causales y disjuntos, pero **no prueban la mejor agenda adversaria**.
- Las anclas propias/ajenas mixtas se sortean Bernoulli con `α=0,33` y offset geométrico truncado. Es una **entrada elegida**, no distribución medida de anclas seleccionadas bajo C-FLU-03/04.
- La frontera parte nivelada en `t=0`; `V_max` retiene ese transitorio. El instrumento no modela red, `blue_work`, PoAS, reorganización, disponibilidad ni aceptación de pago.

## Evidencia y límites

`V_max` causal de 7174,60 frente a 9974,60 slots a `I=4666,ρ=2,5` es **resultado del modelo** con anclas ajenas/offset cero. Los q99 de `ESCENARIOS.txt` son del control de espera con anclas mixtas y bins de 64 slots. Igualdad de las dos variantes de semilla a cuatro decimales solo concierne estas métricas bajo estos supuestos. La coincidencia de oráculo y kernel (384 casos) valida cálculo interno, no validez DAG.

`prove/verify` de un slot se midió a `N=200032000`; el producto `Lrev·N` usa `N=206557520`. Una cadena larga de clave fija y su verificación no se midieron. `ρ_max`, `W_dec`, `α` y `Δ` reales permanecen pendientes. Si la salida AES adicional entra en `C-FLU-10`, su acreditación previa a `C-FLU-14` y a la caché `C-POT-07` está sin resolver; no hay prueba de ausencia de circularidad.

**Conclusión autorizada:** el control instantáneo que produjo 0 % no representa hardware causal; la mejora de frontera persiste en este planificador finito simplificado. La mejora de seguridad protocolaria frente a hardware sofisticado permanece inconclusa.
