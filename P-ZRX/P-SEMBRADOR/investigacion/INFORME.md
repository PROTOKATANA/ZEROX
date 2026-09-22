ZEROX puede eliminar condicionalmente el sembrador sólo si exige, antes del reto y durante más que el adelanto adversarial, un compromiso verificable de la parcela completa (o un sellado secuencial equivalente); con el formato actual únicamente puede mitigarlo y tarifarlo.

# Investigación P-SEMBRADOR

## Resultado y alcance

**[Demostrado respecto de la interfaz fijada]** El ataque es válido contra la prueba de Autonomys copiada en el repositorio. El verificador acepta una prueba ligada a un único registro/pieza y no recibe el sector completo, un compromiso previo de sus bytes ni evidencia del instante en que éstos fueron calculados. Por ello, el atacante que conoce retos futuros puede variar `public_key`, `sector_index`, `history_size` y `piece_offset`, calcular candidatos de una pieza y desechar los fallidos.

**[Demostrado respecto de las reglas escritas]** Ni `history_size` ni `altura_ploteo` demuestran antigüedad física. Identifican el prefijo histórico que determina la parcela y su caducidad. Un atacante puede escoger hoy una referencia antigua que aún sea válida. La sospecha expresada en el encargo queda confirmada.

**[No determinado]** La aritmética final del adelanto de ZEROX sigue abierta. La fórmula histórica no fue rehecha después de decidir que `pot_output` contiene una salida futura; la propia propuesta lo registra en `P-FLUJO/propuesta/PROPUESTA-SPEC.md:644-650,993-995`. Este informe usa el núcleo histórico como función de sensibilidad y no lo eleva a regla de consenso.

**[Conclusión propuesta por esta investigación]** La opción mínima capaz de cerrar el mecanismo es **A1+C1**: registrar antes del reto una raíz/versionado/cardinalidad de la parcela exacta, demostrar que el compromiso abarca su codificación completa y aplicar una edad mayor que una cota explícita del adelanto adversarial. Si no se acepta un registro o acumulador de sectores y el consiguiente cambio de consenso, ninguna candidata estudiada elimina el ataque. D y E pueden reducirlo o cobrarlo, pero no convierten por sí solas al sembrador en almacenamiento honesto.

## Fase 1 — comprobación contra las primitivas reales

### Libertades del atacante y datos impuestos

**[Verificado en fuente]** `SectorId` se deriva de la clave pública, `sector_index` e `history_size` en `PDF/autonomys-subspace/crates/subspace-core-primitives/src/sectors.rs:54-68`. La solución transporta esos campos y `piece_offset` en `PDF/autonomys-subspace/crates/subspace-core-primitives/src/solutions.rs:250-275`; el verificador reconstruye el identificador únicamente con lo presentado en `PDF/autonomys-subspace/crates/subspace-verification/src/lib.rs:228-237`. No aparece en esa ruta un alta previa del sector ni una fecha de creación.

**[Verificado en fuente]** El atacante puede crear claves, variar el índice de sector, declarar una historia pasada todavía válida y recorrer offsets. No puede inventar la pieza ni sus bytes: el índice se deriva de `SectorId`, offset, historia y política de piezas en `PDF/autonomys-subspace/crates/subspace-core-primitives/src/sectors.rs:70-114`; la prueba debe abrir el `record_commitment` contra el compromiso del segmento en `PDF/autonomys-subspace/crates/subspace-verification/src/lib.rs:325-347`.

**[Verificado en fuente]** También vienen impuestos el reto global del PoT y el slot, el s-bucket derivado por XOR, la semilla PoS `H(sector_id || piece_offset)`, la prueba PoS, el rango de solución y los testigos KZG. La derivación está en `PDF/autonomys-subspace/crates/subspace-core-primitives/src/sectors.rs:116-129`; las comprobaciones están en `PDF/autonomys-subspace/crates/subspace-verification/src/lib.rs:234-270`.

### Unidad mínima de un intento dirigido

**[Demostrado por inspección de dependencias]** Basta un registro/pieza, no un sector entero. El plotter codifica cada registro de forma independiente en `PDF/autonomys-subspace/crates/subspace-farmer-components/src/plotting.rs:378-409,616-667`. El prover regenera la tabla y el testigo del `piece_offset` ganador en `PDF/autonomys-subspace/crates/subspace-farmer-components/src/proving.rs:243-329`. El verificador sólo comprueba una prueba PoS, un chunk/testigo KZG y la pertenencia de esa pieza histórica en `PDF/autonomys-subspace/crates/subspace-verification/src/lib.rs:228-350`. `SectorContentsMap` y el checksum son metadatos locales, no entradas de consenso.

**[Verificado en fuente]** Un registro contiene `NUM_CHUNKS` y se extiende a `NUM_S_BUCKETS` en `PDF/autonomys-subspace/crates/subspace-core-primitives/src/pieces.rs:559-570`. La implementación ChiaV2 genera las siete tablas para la semilla del registro y consulta el bucket pedido en `PDF/autonomys-subspace/shared/ab-proof-of-space/src/chiapos.rs:164-205,225-260` y `PDF/autonomys-subspace/crates/subspace-proof-of-space/src/chia_v2.rs:25-36,59-67`. «Parcial» significa aquí una pieza completa; no se ha demostrado un atajo de un solo chunk.

**[Medido históricamente, alcance limitado]** `research/coste-ploteo-medido.md:11-25,180-219` midió sectores de 1.000 piezas y una escala aproximadamente lineal al variar el número de piezas. Dividir ese tiempo por las piezas da un proxy de rendimiento por registro, no una medición del atacante dirigido: el plotter paraleliza registros, escribe datos que el ataque puede omitir y el atacante puede aplazar descarga, erasure coding y KZG hasta hallar PoS.

**[No determinado]** Falta medir `generate_table(seed) → find_proof(target_bucket)` y, cuando existe prueba, la obtención de pieza, el rango y el testigo KZG. También falta determinar si un kernel específico para un bucket reduce el trabajo. No se usa ninguna cifra de precio ni de hardware como conclusión de seguridad.

### Probabilidad e intentos

Sea `R_s` el `solution_range`, `M = 2^64`, `o` la probabilidad de que el s-bucket tenga prueba PoS y `d(R_s) = (2 floor(R_s/2)+1)/M` la fracción inclusiva aceptada por el rango.

**[Derivado bajo hashes uniformes]** La probabilidad por registro y reto es

```text
p(R_s, o) = o · d(R_s).
```

La construcción conserva como máximo un proof por bucket y distribuye hasta `NUM_CHUNKS` pruebas entre `NUM_S_BUCKETS`; para el formato fijado, `o ≈ 1/2`. Por tanto `p ≈ R_s/2^65` y los intentos medios para una solución en un reto son `1/p`. La comparación de distancia usa medio rango en `PDF/autonomys-subspace/crates/subspace-verification/src/lib.rs:148-159`; la calibración upstream que incorpora chunks, buckets y piezas está en `PDF/autonomys-subspace/crates/subspace-core-primitives/src/solutions.rs:22-59`.

**[No determinado]** Una solución PoAS válida no equivale necesariamente a un bloque pagado en el DAG. El modelo conserva `π_DAG`, la probabilidad condicional de publicación, selección y pago. Fijarla a uno sería un límite favorable al atacante, no una propiedad demostrada.

### Trabajo reutilizable

**[Verificado en fuente]** Para una identidad de sector fija, el índice de pieza, la semilla PoS, las tablas, la codificación y los chunks enmascarados no dependen del reto global. Se pueden calcular y almacenar antes y reutilizar: eso es una parcela ordinaria o comprimida. El reto selecciona el bucket y participa en la distancia.

**[Derivado]** Precomputar muchas identidades convierte cómputo adaptativo en un catálogo almacenado; no conserva la ventaja de esperar al reto sin pagar espacio. No se observó reutilización de tablas entre semillas distintas. Los compromisos tiempo-memoria de una instancia fija no prueban una cota para grinding entre identidades; `research/time-memory-tradeoff.md:21-27,95-167,213-230` delimita expresamente ese alcance.

### Antigüedad

**[Verificado en fuente]** El verificador rechaza historia futura, offset inválido y sector expirado en `PDF/autonomys-subspace/crates/subspace-verification/src/lib.rs:274-323`; no verifica cuándo se computó el sector. El plotter usa el `history_size` recibido al construirlo en `PDF/autonomys-subspace/crates/subspace-farmer-components/src/plotting.rs:252-269`.

**[Demostrado respecto del SPEC]** C-EXP vincula referencia, dispersión y caducidad en `SPEC.md:1928-1955`, pero no aporta un compromiso temporal de los bytes. Además, `altura_ploteo` no está en el prefijo cerrado descrito en `SPEC.md:825-845`; la integración entre ambos textos permanece pendiente. R-FIN-10 estabilizaría el hash usado para mapear, pero no fecharía el cálculo (`research/dag-poas-ancla-de-orden.md:383-387`).

### Corrección del modelo histórico

**[Demostrado]** La afirmación histórica de que cada intento debe regenerar un sector entero es falsa para la interfaz verificada. La unidad de aceptación es una pieza. Esto invalida su argumento de latencia y obliga a medir un kernel dirigido.

**[Estimado]** Si el coste es lineal por pieza y el hardware mantiene el mismo rendimiento agregado, dividir a la vez coste e intentos por el número de piezas puede dejar parecido el coste total por solución. Por eso el error de unidad no demuestra por sí solo un factor económico concreto. Sí elimina la justificación de los márgenes históricos como resultados medidos.

**[Verificado en documento histórico]** `research/coste-ploteo-medido.md:70-98` corrige su auditoría serial, pero `research/coste-ploteo-medido.md:108-123` y `research/chia-parcelas-comprimidas.md:70-80` reutilizan una cifra anterior. `research/scripts/d9-ronda10c/informe.md:148-163` modela sectores completos y precios supuestos. Esos márgenes quedan **estimados/no determinados** hasta medir la ruta parcial y `π_DAG`.

## Modelo de margen como función

### Variables, adversario y criterio

El instrumento define:

- `ρ` [adimensional]: aceleración adversarial del reloj secuencial.
- `L`, `I`, `W_dec` [slots]: anticipación de entropía, intervalo de inyección y ventana de decisión.
- `c` [unidad monetaria/intento]: coste total de una unidad atómica dirigida.
- `V` [unidad monetaria/bloque pagado]: valor neto de un bloque que sí resulta pagable.
- `N_h` [piezas elegibles]: espacio honesto expresado en unidades atómicas.
- `λ` [soluciones PoAS/slot]: objetivo del controlador para `N_h`.
- `π_DAG` [bloques pagados/solución válida]: selección y pago condicional en el DAG.

**[Modelo histórico parametrizado]** Para `ρ ≤ 1`, el adversario no alcanza la frontera móvil y `w_core = 0`. Para `ρ > 1`:

```text
A_core(ρ,L,I,W_dec) = max(0, (L - W_dec) + I·(1 - 1/ρ))
w_core = floor(A_core)
```

**[No determinado]** `A_actual` debe rehacerse con el desplazamiento futuro `D`, la semántica exacta de inyección y las fronteras discretas. El instrumento no oculta esa laguna: sus salidas certifican el núcleo introducido, no la regla final.

**[Derivado bajo independencia y uniformidad]** Si una unidad atómica se prueba contra `w` retos conocidos:

```text
q_≥1 = 1 - (1-p)^w
E[intentos hasta algún ganador PoAS] = 1/q_≥1
E[bloques pagados por intento] = w·p·π_DAG
C_bloque = c/(w·p·π_DAG)
M = C_bloque/V
```

El ataque es económicamente rentable en este modelo cuando `M < 1`, indiferente cuando `M = 1` y no rentable cuando `M > 1`. Si el controlador calibra `p ≈ λ/N_h`, entonces:

```text
M ≈ c·N_h / (V·w·λ·π_DAG).
```

**[Derivado]** El umbral de coste es `c* = V·w·λ·π_DAG/N_h`. Aumentar `L`, `I` o `ρ` cuando aumenta `w` amplía linealmente los retos amortizados; aumentar `W_dec` los reduce. Con `w=0` no existe esta modalidad anticipada, aunque ello no demuestra seguridad frente a otras formas de grinding.

**[Verificado por instrumento]** El código usa `H_eff=N_h/λ`, `p=1/H_eff` y `recompensa_efectiva=π_DAG·V`. Para la frontera discreta resta un slot, `A=max(0,(L-1-W_dec)+I(1-1/ρ))`; es la convención `t_(j+1)-1`, no un parámetro de consenso. `q_≥1` se conserva para contar candidatos no vacíos, mientras el margen usa exactamente `μ=w/H_eff`, porque una pieza puede acertar en varios slots.

**[Medido el 2026-09-20, alcance del instrumento]** Pasaron 42 comprobaciones de bordes, umbral, monotonías, sensibilidad a `ρ` y `L` y equivalencia con un oráculo `BigFloat` de 256 bits. JET no detectó errores. El kernel caliente de 100.000 filas tuvo mediana de 1,484472 ms, 0 bytes y 0 asignaciones después del calentamiento en Julia 1.13.0, CPU `znver5`, un hilo. Estos números miden el evaluador matemático, no el ploteo.

**[Barrido adimensional derivado, no estimación de ZEROX]** Las 96 filas generadas cubren ambos lados de la frontera variando todas las entradas. Por ejemplo, con las entradas explícitas `coste/recompensa=10^-6`, `H_eff=10^9`, `I=851` y `W_dec=20`, el instrumento produce:

| `ρ` | `L` [slots] | `w` | `μ=w/H_eff` | margen `M` |
|---:|---:|---:|---:|---:|
| 1 | 3.600 | 0 | 0 | infinito |
| 1,001 | 3.600 | 3.579 | 3,579e-6 | 0,27941 |
| 1,001 | 7.200 | 7.179 | 7,179e-6 | 0,13930 |
| 1,5 | 3.600 | 3.862 | 3,862e-6 | 0,25893 |
| 3 | 7.200 | 7.746 | 7,746e-6 | 0,12910 |

Los valores se eligieron para ejercitar sensibilidad, no por plausibilidad económica o adopción de consenso. El código, comandos, salidas completas y supuestos están en `investigacion/veritas/seguridad/sembrador-v1/INFORME.md`, `investigacion/veritas/seguridad/sembrador-v1/resultados/` e `investigacion/veritas/seguridad/sembrador-v1/HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md`.

## Fase 2 — comparación ordenada

| Orden | Candidata | Qué ataca | Veredicto condicionado | Cambio principal |
|---:|---|---|---|---|
| 1 | A1+C1: compromiso completo previo + edad | adaptación, ploteo parcial y descarte previo | **Elimina** si edad `> sup A_actual` y la prueba obliga a todos los bytes | registro/acumulador, prueba y espera |
| 2 | B: sellado secuencial verificable | adaptación y paralelismo por intento | **Elimina** si la ruta adversarial `> A_actual` y no admite atajo | nueva parcela y prueba sucinta |
| 3 | G: activación PoST por época | adaptación por slot y no permanencia | **Elimina condicionalmente**; migración mayor | conjunto activo y auditorías |
| 4 | D: revelación retardada | adelanto | **Mitiga**, no cierra para todo `ρ` | varias líneas PoT y riesgo de partición |
| 5 | E: pago sujeto a permanencia | descarte del ganador | **Mitiga/tarifa**; los fallidos se desechan | obligaciones y pruebas futuras |
| 6 | C2: subir coste de tabla | ventaja económica por intento | **Mitiga × factor medido** | más coste de alta y posible formato |
| 7 | F/A0/A2 aisladas | señales indirectas | **No sirve** como cierre | falsa antigüedad o cuotas evadibles |

Los veredictos de eliminación son condicionales: dependen de cotas aún no fijadas y exigen cambios que ZEROX no tiene hoy.

## Fichas de candidatas

### A — antigüedad demostrable

**Mecanismo [propuesto].** A1 registra una raíz de la codificación completa, versión, cardinalidad, identidad e historia antes del reto. La activa sólo después de una edad `M_A > sup A_actual + margen de red/finalidad`. Cada solución abre la pieza contra esa raíz y prueba que el alta activa precede al reto. Una raíz de meros `SectorId` o publicada después del reto no acredita bytes completos.

**Qué elimina y veredicto.** **Elimina condicionalmente** la adaptación posterior al reto. El catálogo precomputado sigue siendo posible, pero entonces el adversario tuvo que comprometer y conservar o regenerar datos antes del reto; C1/B debe cerrar la regeneración barata. A0, basado sólo en `history_size`/`altura_ploteo`, **no sirve**. A2, plegado en un bloque anterior de la misma clave, **no sirve aislado**: favorece incumbentes y una clave puede comprometer un catálogo arbitrario.

**Coste [no determinado].** El granjero construye la parcela completa y espera antes de ser elegible. El nodo verifica alta, edad y pertenencia y mantiene un conjunto activo o un acumulador. La cadena transporta altas/bajas, raíz, cardinalidad y versión. Los bytes, CPU, estado y tasa de altas requieren prototipo.

**Qué reabre/compatibilidad.** Revoca «sin registro de sectores», introduce poda y acceso de nuevos granjeros y puede cambiar solución/cabecera. Una transacción de activación comprometida por la raíz existente evita añadir todos los datos a la cabecera, pero la solución necesita identificar y abrir el compromiso. No modifica el PoT estable; depende de que su calendario de adelanto quede cerrado.

**Evidencia y medición.** `SectorId` sólo liga clave, índice e historia (`PDF/autonomys-subspace/crates/subspace-core-primitives/src/sectors.rs:54-68`). Deben medirse construcción/apertura de raíz, estado, altas por segundo, regeneración y grinding de compromisos. Combina con C1, B y E.

### B — sellado secuencial del sector

**Mecanismo [propuesto].** Una réplica ligada a identidad, ticket previo y todos sus bytes se produce mediante una ruta secuencial y se acompaña de prueba sucinta. Si el candidato se elige tras conocer el reto y `T_seal,adv > A_actual`, no llega a tiempo; pre-sellarlo lo convierte en capacidad preparada antes del reto.

**Qué elimina y veredicto.** **Elimina condicionalmente** la adaptación si la cota adversarial incluye GPU/FPGA/ASIC, la dependencia cubre todo el sector y no hay precomputación o regeneración barata. Si el atacante acelera el sellado hasta cruzar la cota, vuelve el ataque. Hoy está propuesto, no demostrado.

**Coste [no determinado].** Alta lenta, memoria temporal, consumo y posible ventaja de hardware especializado. Los nodos necesitan una prueba sucinta; repetir el trabajo secuencial por sector sería inviable. Añade compromiso y prueba, y puede exigir parámetros/circuito.

**Qué reabre/compatibilidad.** Sustituye sustancialmente la parcela Autonomys y probablemente `proof_of_space`. `prototipos/pot-estable` verifica un reloj global, no una codificación de memoria por sector, por lo que no es un sellado reutilizable directamente. No requiere comité, pero sí nueva criptografía y migración.

**Evidencia y medición.** Filecoin separa `CommD`, réplica `CommR`, sellado y prueba en su [especificación de sealing](https://spec.filecoin.io/systems/filecoin_mining/sector/sealing/) y describe Stacked-DRG en la [especificación SDR](https://spec.filecoin.io/algorithms/sdr/). Es precedente, no prueba transferible. Hay que medir ruta crítica y memoria adversarial, tamaño/generación/verificación de prueba y aceleración por plataforma. Combina con A1 y D.

### C — encarecer el intento dirigido

**Mecanismo [propuesto].** C1 hace que una candidatura dependa de todos los registros mediante codificación global o certificado de cómputo completo. C2 aumenta el trabajo de tabla/codificación. Abrir varios registros elegidos por un reto conocido sólo multiplica el coste por el número de aperturas; una raíz presentada tras conocer el reto no prueba que se calculasen las demás hojas.

**Qué elimina y veredicto.** C1 **mitiga por `C_full/C_partial`** y, unido a A1 con espera suficiente, elimina el ploteo adaptativo. C2 **mitiga por un factor medido**, pero castiga también el alta honesta y el hardware futuro erosiona el margen. Ninguna elimina sola por principio.

**Coste [no determinado].** El honesto paga una vez el cómputo completo; el atacante, por intento. Nodo y cadena pagan certificado/compromiso. Una prueba sucinta de siete tablas, KZG y codificación completa no existe en el formato actual.

**Qué reabre/compatibilidad.** Puede invalidar parcelas existentes, cambiar `proof_of_space` y la cabecera. No toca R-FIN-14(e) ni comités. La compatibilidad externa sólo es posible si la nueva prueba cabe en un compromiso ya autenticado, algo aún no diseñado.

**Evidencia y medición.** El auditor actual lee el bucket determinado (`PDF/autonomys-subspace/crates/subspace-farmer-components/src/auditing.rs:198-270`) y el prover reconstruye una pieza (`PDF/autonomys-subspace/crates/subspace-farmer-components/src/proving.rs:243-329`). Debe medirse el cono mínimo de dependencia, no el plotter completo honesto. Combina con A1/B/D.

**Precedente Chia [verificado en fuente primaria, alcance limitado].** La [descripción oficial de Proof of Space](https://github.com/Chia-Network/proofofspace/blob/master/proof_of_space.md) liga el plot a un identificador y busca una prueba para un reto. Esto justifica estudiar coste de tablas y compresión, pero no aporta por sí mismo una fecha de creación ni un alta previa. La documentación de [Proof of Space 2.0](https://github.com/Chia-Network/chia-docs/blob/main/docs/chia-blockchain/consensus/proof-of-space-2.0/new-proof-introduction.md) describe un diseño todavía en desarrollo; no se usa como propiedad disponible de ZEROX. `research/chia-parcelas-comprimidas.md:21-35,64-85` ya advierte que los resultados de compresión/grinding no se trasladan automáticamente a las semillas y piezas de Autonomys.

### D — revelación retardada sin bajar `L`

**Mecanismo [propuesto históricamente].** Una segunda línea secuencial oculta la entropía útil hasta más cerca de su aplicación, manteniendo el reto slot a slot. Reduce `A_actual` y, con ello, la edad o sellado exigidos por A/B.

**Qué elimina y veredicto.** **Mitiga** el adelanto dentro de una región de `ρ`; no lo elimina universalmente. Un compromiso-revelación con secreto requiere custodios/umbral o permite withholding y grinding, incompatibles con las restricciones actuales.

**Coste [estimado por el diseño histórico].** Verificación aproximada `1+L/I` por nodo y varias líneas AES. En una partición, el lado sin líneas suficientes deja de producir. Las cifras finales requieren rehacer el modelo con `pot_output` futuro.

**Qué reabre/compatibilidad.** Puede conservar la parcela Autonomys y R-FIN-14(e) si cada salida sigue dependiendo secuencialmente de la anterior, pero cambia la producción/verificación del PoT y posiblemente sus campos auxiliares. Agrava el riesgo de flujos permanentes del perfil 1a sin regla de adopción. La primitiva AES estable es compatible; falta integrar y medir múltiples líneas.

**Evidencia y medición.** R-FIN-14(h) delimita el efecto en `research/dag-poas-ancla-de-orden.md:277-287`; C-POT conserva retos sin saltos en `P-POT/propuesta/PROPUESTA-SPEC.md:88-107`. Medir `ρ` por plataforma, líneas simultáneas, CPU de nodo y escenarios de partición. Combina con A/B/C; no los sustituye.

### E — permanencia como condición de pago

**Mecanismo [propuesto].** Al ganar, el bloque compromete la raíz exacta de su sector. La coinbase sólo se libera si ese mismo compromiso responde dentro de plazo a retos posteriores impredecibles. La comprobación debe llegar cerca del reto; permitir probar al gastar deja tiempo para regenerar.

**Qué elimina y veredicto.** **Elimina el descarte inmediato del sector ganador**, pero **sólo mitiga el ataque completo**. El sembrador conserva ganadores y desecha todos los intentos fallidos. Su espacio en régimen depende de tasa de victorias, duración y bytes por sector, no de la capacidad que simuló al grindear.

**Coste [no determinado].** El honesto mantiene disponibilidad y arriesga recompensa ante pérdida de disco o red. Nodo y cadena mantienen obligaciones y verifican una o varias auditorías. Deben medirse falsos fallos, almacenamiento adversarial, regeneración dentro del plazo, bytes y CPU.

**Qué reabre/compatibilidad.** C-EMIT-05 fija hoy `COINBASE_MATURITY = 12.000` bloques como mera espera para gastar (`SPEC.md:1609-1610`); esa ventana podría alojar una obligación, pero no la contiene ni demuestra que baste. E debe definir calendario DAG, retos y recepción antes de afirmar compatibilidad. También debe decidir qué ocurre con los bloques pagables por R-FIN-8': azul y `rojo_k` cobran su propia coinbase y la madurez empieza al fusionarlos (`research/dag-poas-ancla-de-orden-auditoria-8b.md:99-109`). Si una recompensa fallida deja de contar, el controlador requiere contabilidad retrospectiva; si cuenta, se quema emisión. Necesita raíz exacta y cambia la solución/parcela o añade una prueba de pertenencia; el PoT estable puede suministrar el reto futuro sin cambiar su primitiva.

**Evidencia y combinación.** Filecoin distingue auditoría de elección y auditoría periódica en [WinningPoSt y WindowPoSt](https://spec.filecoin.io/algorithms/pos/post/). El precedente muestra el patrón, no su adecuación a ZEROX. E combina con A1+C1 y sirve como tarifa de permanencia adicional.

### F — medidas que no bastan

**Mecanismos.** Acotar `ρ`, hacer «ciega» la cadena manteniendo entropía conocida, limitar victorias por identidad o detectar estadísticamente al sembrador.

**Veredicto [demostrado dentro del modelo].** **No sirven como cierre.** El adelanto aparece para cualquier `ρ>1` en el núcleo; ocultar eslabones intermedios no oculta una entropía ya revelada; las identidades gratis evaden cuotas; una estadística no prueba cuándo se creó una parcela y conlleva falsos positivos.

**Coste y reaperturas.** Añaden complejidad, posible subjetividad y discriminación entre identidades sin eliminar adaptación ni descarte. Sólo caben como monitorización o hipótesis explícitas. La evidencia histórica está en `research/dag-poas-ancla-de-orden-auditoria-9c.md:7-19,38-47`, `research/dag-poas-informe-52-problemas.md:318-321` y `research/dag-poas-balizas-auditoria.md:66-75`.

**Compatibilidad [verificado/propuesto].** Estas medidas caben alrededor de la parcela y del PoT actuales, pero precisamente por no cambiar la prueba que liga almacenamiento al reto tampoco cierran el ataque.

### G — activación PoST por época

**Mecanismo [propuesto desde un precedente].** Antes de una época se publica un compromiso de capacidad y una prueba de inicialización/espacio; sólo ese conjunto es elegible y se reaudita. Es A1+E a escala de capacidad, con B opcional.

**Qué elimina y veredicto.** **Elimina condicionalmente** la adaptación por slot si la activación precede al adelanto, la prueba liga espacio único y regenerar dentro de las auditorías no es rentable. Es la solución más completa y la migración más grande.

**Coste [no determinado].** El granjero espera una época, inicializa y audita espacio. Nodo y cadena mantienen activaciones, pruebas y expiración. La lectura de todo el almacenamiento y el acceso del pequeño granjero deben medirse.

**Qué reabre/compatibilidad.** Sustituye explícitamente el modelo sin registro, cambia selección y retarget. No debe copiar PoET ni otra autoridad; ZEROX tendría que usar su PoT. La compatibilidad con la cabecera es baja, aunque la activación podría vivir en transacciones separadas.

**Evidencia y medición.** Spacemesh registra activaciones por época y compromiso de almacenamiento en su [protocolo](https://github.com/spacemeshos/protocol), con especificaciones de [ATX](https://github.com/spacemeshos/protocol/blob/master/atx.md), [NIPoST](https://github.com/spacemeshos/protocol/blob/master/nipost.md) y [PoST](https://github.com/spacemeshos/protocol/blob/master/post.md). Medir estado activo, ancho de banda, auditoría, regeneración y concentración. Combina A1+B+E.

## Recomendación de esta investigación

**[Propuesta propia, no decisión de Katana]** Diseñar primero un prototipo **A1+C1** fuera del SPEC: transacción de activación con raíz exacta, versión y cardinalidad; certificado o esquema de muestreo cuyo alcance se declare con precisión; prueba de pertenencia en la solución; y edad simbólica `M_A > sup A_actual`. Es el cambio mínimo que ataca simultáneamente adaptación y ploteo parcial. Si la prueba completa resulta inviable, el prototipo debe decir «mitiga ×N» y no «elimina».

**[Propuesta propia]** Evaluar B en paralelo sólo como línea de investigación criptográfica, porque puede ofrecer eliminación sin auditorías frecuentes pero introduce el mayor riesgo técnico. Usar D para reducir las cotas temporales y E para cobrar permanencia del ganador una vez que exista una raíz exacta. No fijar parámetros hasta medir el kernel parcial, cerrar `A_actual` con `D`, modelar `π_DAG` y cuantificar alta, prueba, estado y pérdida honesta.

## Lo que esta investigación NO resuelve

- **[No determinado]** La fórmula final del adelanto con `pot_output = salida(slot+D)`, fronteras discretas, reinicios y particiones.
- **[No determinado]** El coste, latencia y memoria del kernel dirigido mínimo en hardware contemporáneo y adversarial.
- **[No determinado]** `π_DAG`: cuántas soluciones sembradas terminan publicadas, seleccionadas y pagadas bajo GHOSTDAG/R-FIN-8'.
- **[No determinado]** Una prueba sucinta de que se codificó un sector Autonomys completo, ni su seguridad de regeneración/compresión.
- **[No determinado]** Una cota creíble de aceleración adversarial para PoT o para un sellado nuevo.
- **[No determinado]** Formato, bytes, CPU, estado y poda de activaciones u obligaciones futuras.
- **[No determinado]** Parámetros de consenso `L`, `F`, `I`, `ρ_max`, edad, número de aperturas o ventanas de auditoría.
- **[No determinado]** La regla de adopción entre flujos y la disponibilidad durante particiones del perfil 1a.
