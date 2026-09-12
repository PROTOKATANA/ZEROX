# Ficha previa de modelo — finalidad para Cortex

**ID:** `ZEROX-FIN-PRE-001` · **Revisión:** 2 · **Fecha:** 2026-09-10.
**Estado:** cruces documentales consolidados; contratos de protocolo y prueba pendientes (§6).
**Categoría:** finalidad, porque el objeto es la pérdida de un pago después de aceptarlo.

Este documento prepara la validación: **no ejecuta ni certifica cálculos**, no cambia consenso y
no autoriza pagos reales. No se ha creado todavía un motor Julia ni instanciado un proyecto.
Los especialistas de matemáticas/Julia, Rust y C++ contrastaron las fuentes por lectura.
El proceso posterior debe cumplir [LINEO](../../LINEO.md) íntegramente.

## 1. Qué estamos fijando

Hay dos objetos distintos, con identificadores distintos:

| ID | Objeto | Qué se puede afirmar ahora |
|---|---|---|
| **R0: `carrera-nominal-tiempo-fijo-v1`** | Carrera abstracta que originó la tabla de 30 minutos. | Variables, hipótesis, convención de empate y evento definidos en §4; resultados históricos por verificar. |
| **T1: `post-dag-a2prima-pago-v1-pre`** | Pago aplicado en el diseño PoAS + PoT + GHOSTDAG A″, con capa transparente y blindada prevista. | Referencia del diseño y procedencia conocidas; faltan contratos y demostraciones para transferir R0 a T1. |

No se estudia el nodo PoW heredado como si fuera T1. Tampoco se añade en esta ficha una autoridad
de finalidad VDF, Avalanche, un comité ni staking. La prioridad inicial es entender el baseline
de 30 minutos; la optimización de tiempos viene después de definir una comparación válida.

Las reglas de partida de T1 son las enmiendas identificadas en el SPEC y la investigación:

- A″: tasa nominal `λ = 1/s`, slot nominal `τ = 1 s` y monotonicidad **no estricta**.
- GHOSTDAG con `k = 30` como referencia, peso por rango y selección contextual.
- R-FIN-11: U2 y U3″ dinámica; no la variante U3′-filtro.
- R-FIN-12: presupuesto de padres/mergeset y shuffle honesto obligatorio.
- R-FIN-8′: ejecución/recompensa de azules y `rojo_k`; `rojo_U3` inerte.
- R-FIN-13′: retarget que cuenta el conjunto pagable, no sólo azules.
- R-FIN-14(a–g): retos obtenidos de PoT secuencial resembrado; (h) es una alternativa separada.
- R-FIN-7: propuesta de restricción temporal local; su acuerdo global no se da por demostrado.

Fuentes: [SPEC](../../../SPEC.md), §§6–7, 11–13; [ancla](../../../research/dag-poas-ancla-de-orden.md), §2.
La revisión 2 consolida las enmiendas compatibles y corrige residuos en SPEC y ancla. No congela
la implementación ni completa las reglas que faltan. R0 no cambia de evento ni de parámetros.

## 2. Etiquetas de procedencia

Se registran **dos ejes**: de dónde viene un dato y si puede usarse en el modelo elegido.
«Medido» no significa «adoptado», y «adoptado» no significa «implementado».

| Etiqueta | Significado |
|---|---|
| **E** | Elección explícita del usuario o referencia adoptada en el SPEC; indicar cuál. |
| **H** | Hipótesis de un escenario, no observación de la red. |
| **MS** | Resultado medido en una simulación concreta, con instrumento y cobertura limitados. |
| **MH** | Resultado medido en hardware concreto, con versión y carga indicadas. |
| **MR** | Resultado medido en una red ZEROX con el protocolo destino; ninguno disponible aquí para Δ. |
| **D** | Valor derivado; su validez depende de una fórmula y de sus hipótesis. |
| **C** | Candidato o estimación, sin adopción o cota suficiente. |
| **P** | Pendiente de definición, elección, medición o demostración; indicar qué falta. |

Una frase histórica «DECIDIDO por Katana» se identifica como tal, con su fuente. No convierte
automáticamente las recomendaciones cercanas ni los números de una tabla anterior en decisiones.
Las fuentes upstream se fijan por commit en [PDF/README](../../../PDF/README.md); sus valores
describen esos repositorios, no una configuración de ZEROX.

## 3. Registro de parámetros

### 3.0 Origen upstream frente a modificación ZEROX

Autonomys se inspeccionó en `f8842d019cdf0f7163421b9644db5a9ff82b2a73`; Chia en
`f87270c0275904981366651a59a0618aea5144ce`. Son valores del código de esos commits, no una
medición de sus redes ni una afirmación sobre sus versiones actuales. Las rutas abreviadas de
Autonomys parten de [PDF/autonomys-subspace](../../../PDF/autonomys-subspace/).

| Pieza | Valor/semántica de Autonomys | Referencia ZEROX y motivo de separación |
|---|---|---|
| Ritmo | `SLOT_DURATION=1000 ms`; `SLOT_PROBABILITY=(1,6)`, un bloque por seis slots en promedio sin contar colisiones. | A″ mantiene τ nominal de 1 s, pero cambia el objetivo a λ1/s. No conservar `(1,6)` dentro de una conversión espacio↔rango sin adaptarla. |
| Relación padre/hijo | `block_import.rs` rechaza `slot≤parent_slot`. | A″ admite igualdad para el régimen DAG. Es cambio de regla, no optimización de código. |
| Autoría | `BLOCK_AUTHORING_DELAY=4 slots`. | D_aut de ZEROX pendiente; no confundirlo con latencia de red. |
| Entropía | Intervalo `50 bloques`, lookback `2 intervalos`, aplicación `15 slots` después del bloque que la programa. | El ancla DAG usa época por índice PoT y rezago L. No asignar `I=50 s`, `L=15 s` o «lookback=2 bloques» por coincidencia de nombres. |
| PoT de génesis | `206 557 520` iteraciones; comentario de calibración en un 14900KS. | N(s) y hardware de referencia ZEROX pendientes; distinto del ensayo de `200 032 000` iteraciones. |
| Controlador | Era de `2016 bloques`; rango de tipo `u64`; `pieces_to_solution_range` usa `slot_probability` y divisiones enteras ordenadas. | R-FIN-13′ cambia ventana y conjunto contabilizado. La fórmula de espacio necesita revisar entradas, unidades y redondeos. |
| Actualización PoT | `set_pot_slot_iterations` requiere `ensure_root`, aumento y compatibilidad con checkpoints; programa el cambio junto a la inyección. | Se conserva la coincidencia temporal de R-FIN-14, **no se adopta la autoridad root**. Falta la regla ZEROX de actualización. |
| Peso de fork | `calculate_block_fork_weight(SR) = MAX_u64 − SR` (con ajuste especial bajo feature `testing`). | ZEROX propone `⌊2^128/(SR+1)⌋` sobre azules, inspirado en acumulación de trabajo de GHOSTDAG. **No es la fórmula de peso de Autonomys** y requiere justificación propia. |
| Prueba de espacio | `PosProof::K=20`; `ChiaV2Table` usa `ab-proof-of-space` adaptado a s-buckets. | No equivale a adoptar el nodo ni el consenso Chia. Ese K de PoSpace tampoco es `k_GD=30`. |

Fuentes de la tabla: `crates/subspace-runtime/src/lib.rs`, líneas 143–175;
`crates/subspace-runtime-primitives/src/lib.rs`, líneas 46–48;
`crates/sc-consensus-subspace/src/block_import.rs`, línea 368;
`crates/subspace-node/src/chain_spec.rs`, línea 128;
`crates/subspace-core-primitives/src/solutions.rs`, líneas 24–39;
`crates/subspace-verification/src/lib.rs`, líneas 193–205;
`crates/subspace-core-primitives/src/pos.rs`, línea 103; y
`crates/subspace-proof-of-space/src/chia_v2.rs`.
El recorrido de la inyección está en `crates/pallet-subspace/src/lib.rs`, líneas 942–967.
La autorización de cambios de iteraciones está en ese archivo, líneas 631–657, y su programación
en 973–978. Ser un detalle de implementación upstream no lo convierte en decisión de ZEROX.

**Referencia Kaspa separada:** clon local `/home/katana/zeo/fuentes/rusty-kaspa`, commit
`c338d495bec29e4dc8b5149f99e8db6fa916ed4a`. `consensus/core/src/config/bps.rs`, líneas 57–85,
respalda 15 padres y 180 bloques de mergeset para esta referencia k30. En
`consensus/src/pipeline/virtual_processor/processor.rs`, líneas 1071–1118, el shuffle afecta a la
cola de candidatos; el padre seleccionado se añade aparte y el presupuesto filtra/reemplaza
candidatos. No significa «la mitad de los padres finales al azar». Esta política de producción
honesta tampoco introduce aleatoriedad en la decisión del verificador. El portado completo sigue
pendiente: las simulaciones sin ese algoritmo no son automáticamente representativas de T1.
La fórmula propia de ZEROX está en SPEC §11 y `research/dag-poas-empalme-peso.md` §1.

**Chia se mantiene como referencia separada:**
[default_constants.py](../../../PDF/chia-blockchain/chia/consensus/default_constants.py), líneas
14–17 y 38, declara `SLOT_BLOCKS_TARGET=32`, `MAX_SUB_SLOT_BLOCKS=128`, `NUM_SPS_SUB_SLOT=64`
y `SUB_SLOT_TIME_TARGET=600 s`. Ninguna de esas constantes fija el slot de PoT de ZEROX.
Este archivo se leyó como fuente, no se ejecutó. Una prueba de espacio compartida no transfiere
automáticamente el calendario, los límites de bloques ni el teorema de seguridad del otro consenso.

### 3.1 Referencia de carrera R0

Procedencia ejecutable **sólo inspeccionada**: [llamada de ronda 12](../../../research/scripts/d12-quorum/d12_b_composicion.py),
líneas 25–31 y 59–62, que importa [prev](../../../research/scripts/d9-ronda9a/r9a_a3_frontera.py), líneas 37–49.

| Parámetro | Definición y unidad | Valor de referencia | Procedencia / estado |
|---|---|---|---|
| `t_acept` | Tiempo fijado antes de observar la carrera, en segundos del modelo. | `1 800 s` | E: punto de espera que se quiere estudiar; H al identificarlo con una espera física de Cortex. |
| `λ` | Tasa total de eventos antes del descuento honesto, eventos/s. | `1/s` | E: nominal A″; H: tasa homogénea constante de R0. No es una tasa de producción medida. |
| `α` | Fracción que asigna tasa al adversario, adimensional. | `0,33` y `0,40`, en corridas separadas | H: escenarios históricos. El 33 % operativo figura en ancla §2; no mide almacenamiento adversario real. |
| `h_f` | Multiplicador de la tasa honesta, adimensional. | `1` | H: referencia sin merma honesta. Es el quinto argumento de `prev`; **no es velocidad PoT**. |
| `δ` | Descuento honesto, si se utiliza la parametrización `h_f = 1 − δ`. | `0` sólo en R0 nominal | H, no una propiedad demostrada de red. Δ no es un argumento de esta función. |
| `k_GD` | Parámetro de coloración, en número de bloques. | `30` | E: referencia del SPEC §7.3; no se afirma que siga siendo óptimo tras cambiar el retarget. |
| `m_carrera` | Ventaja inicial artificial del adversario, en unidades de conteo. | `3·k_GD = 90` | D: sustitución histórica inspirada en la cota de freeloading. Aplicabilidad a T1 pendiente. No son confirmaciones. |
| `w_ref` | Peso por evento en ambas ramas. | Unitario / constante común | H: permite comparar conteos. No fija el valor de `SR` del protocolo. |
| `ε_pago` | Riesgo máximo que acepta el comercio. | Sin elegir | P: decisión de política comercial; no se deduce de un resultado publicado. |

`α` de R0 es una participación **en la tasa**, no una prueba de que una fracción de discos físicos
produce esa misma fracción efectiva bajo ploteo, disponibilidad, PoT rápido y estrategias adversarias.
La correspondencia con `α_espacio` forma parte del paso R0→T1.

### 3.2 Protocolo destino T1

| Parámetro | Valor documentado y unidad | Procedencia | Uso admisible / pendiente |
|---|---|---|---|
| `τ_nom` | `1 s/slot` | E: SPEC §7.3 y A″ en ancla, nota de R-FIN-7. | Nominal; no garantiza tiempo físico por slot en cualquier equipo. |
| `λ_obj` | `1 bloque/s` nominal | E: mismas fuentes. | Definir tasa física, tasa por slot y eventos de billetes contabilizados; no contar copias como producción nueva. |
| `k_GD` | `30` | E: SPEC §7.3, ancla §2. | Residuo k25 de R-FIN-6 corregido en revisión 2. No derivarlo otra vez del retarget superado. |
| `q` | `1`, con `τ_nom=1` | E histórica: ancla §6. | Razón nominal slots/bloque; no intervalo realizado ni promesa de exactamente un bloque por slot. |
| `max_block_parents` | `15` padres a `k=30` | E de la variante: R-FIN-12. | Conservar presupuesto y shuffle; cambiar k exige revisar límites asociados. |
| `mergeset_size_limit` | `180` bloques a `k=30` | E de la variante: R-FIN-12. | No confundirlo con el peso máximo en bytes del bloque. |
| `S_max_slots` | `150 slots`, equivalentes a `150 s` **nominales** con τ_nom=1 s/slot; limita salto al padre seleccionado. | E histórica: ancla §2/R-FIN-1a; unidades consolidadas en SPEC §7.3. | No es un nuevo valor ni una cota física de red/retención; calendario físico pendiente. |
| `F` | `2 h` provisional | E provisional: SPEC §7.3; bitácora §11. | Restricción de reorg basada en slot; no es `t_acept` ni prueba de acuerdo global. Semántica temporal e integración pendientes. |
| `Δ` | Sin valor físico medido; `4/8/16/20 s` entre los escenarios históricos. Retardo sintético creación→disponibilidad honesta, no RTT ni espera de pago. | H/MS: ronda 11a; `d8-ronda8/d8_lib.py`, líneas 113 y 161: retardo honesto y entrega adversaria instantánea. | Definir modelo de red y luego medirlo. No adoptar 4 s por costumbre. |
| `δ₀(Δ,k,λ)` | Tablas de fracción honesta roja con `α=0`. | MS: [ronda 11a](../../../research/scripts/d9-ronda11a/informe.md), §C.1. | Media experimental; no cota adversarial ni garantía de crecimiento Poisson independiente. |
| `SR(B)` / `w(B)` | `w(B)=⌊2^128/(SR(B)+1)⌋`, sumado sobre azules. | Referencia: SPEC §11, R-FIN-6/13′. | D/P: controlador, bootstrap, dominio y aritmética. SR u64 no implica peso u128: SR=0 da 2^128; ensanchar antes de SR+1. Retarget y peso cuentan objetos diferentes. |
| `W_RETARGET`, `γ` | `W≥3 083 slots, γ≤0,25`; alternativa `W≥12 331, γ≤1`. | D histórica: R-FIN-13 y [empalme de peso](../../../research/dag-poas-empalme-peso.md), §§2–3. | Derivados con tasa azul y F anteriores; no convertirlos en certificación de R-FIN-13′. Recalibración pendiente. |
| `N(s)` | `slot_iterations`, entero por slot. | R-FIN-9/14; kernel PoT upstream. | P: ZEROX no tiene valor final ni calendario de cambios consolidado. No importar una constante de otra máquina como reloj universal. |
| `D_aut` | Retardo de autoría, en slots. | R-FIN-14(d); Autonomys usa un valor propio. | P para ZEROX. No es Δ; determina qué salidas PoT deben acompañar una prueba. |
| `I` | Separación de épocas: hay candidatos, no valor cerrado. | C: R-FIN-14 y rondas 9c/10a. | Definir `I_slots` entero y su duración física; validar conjuntamente restricciones de inyección y adversario. |
| `L` | Rezago entre ancla e inyección. `1 h` es un candidato. | C: [auditoría 9c](../../../research/dag-poas-ancla-de-orden-auditoria-9c.md), §§5 y 7. | No ligar por defecto a F. La etiqueta «decisión F1» contradice la recomendación condicionada del mismo informe; adopción inequívoca pendiente. |
| `ρ_max` | Cociente velocidad de evaluación AES atacante/timekeeper de referencia. `2,5×` procede de una estimación `1,5–2,5×`; `3×` es otro escenario. | C/H: [PoT y hardware](../../../research/pot-aes-asic-chacha.md), §3. | La fuente dice «estimación ... sin paper». No es cota demostrada ni medida del atacante ni ventaja de ploteo. |
| `W_dec` | Máximo observado `45 s`. | MS: [ronda 9c](../../../research/scripts/d9-ronda9c/informe.md), §C. | Búsqueda finita: 12 semillas, horizonte 1 000 s, dos estrategias, tope de candidatos y rejilla de retardos. No es cota universal. |

**Medición hardware que se conserva, sin extrapolar:** ancla, párrafo «Coste del PoT, MEDIDO»:
`200 032 000` iteraciones por slot, Ryzen 9950X3D, ocho checkpoints; producción `1,561 s/slot` y
verificación `96,1 ms/slot`. Son MH históricas de ese ensayo. La referencia Autonomys citada usa
`206 557 520` iteraciones; ni ese cambio ni otro procesador mantienen automáticamente los tiempos.

**No mezclar símbolos:** `m_carrera=90` no es el menú `m_anclas` del steering; `h_f` no es `ρ`;
`D_aut` no es `Δ`; `k_GD` no es un quórum ni `k_ref`; F no es madurez de coinbase.

## 4. Definición matemática de R0

Se reconstruye por lectura la semántica de `prev`, separada de sus aproximaciones numéricas.
Dominio inicial: `λ>0`, `0<α<1`, `0<h_f≤1`, `m_carrera` entero no negativo, `t_acept≥0`
y tasas positivas. Los procesos se definen para `u≥0`.
Los dos escenarios nominales tienen tasa honesta mayor que adversaria.

```text
λ_h = (1 − α) · λ · h_f
λ_a = α · λ

H(u): proceso Poisson homogéneo de tasa λ_h
A(u): proceso Poisson homogéneo de tasa λ_a, independiente de H
H(0) = A(0) = 0
X(u) = H(u) − A(u) − m_carrera
```

Hipótesis: incrementos independientes y estacionarios, pesos iguales, tasas constantes antes y
después de aceptar, una carrera sin restricciones temporales de finalidad. No hay simulación
de bloques, padres, pruebas, transacciones, flujos, red ni retarget dentro de esta función.
El adversario dispone de la ventaja inicial fijada; no de una precadena arbitrariamente grande.

**Evento idealizado reconstruido por inferencia analítica local** (no identificado con el
resultado aproximado y truncado del programa histórico):

```text
E_t = { existe u ≥ t_acept tal que X(u) < 0 }
```

El adversario gana por **adelanto estricto**, no por empate. Estar adelantado en el instante de
aceptación también cuenta. El proceso no absorbe los estados negativos anteriores a `t_acept`;
con `X(0)=-m_carrera`, hacerlo produciría otro experimento.

Para `r=λ_a/λ_h<1`, la regla de captura eventual usada es:

```text
g(d) = 1         si d < 0
g(d) = r^(d+1)   si d ≥ 0
P_R0(t) = E[ g(H(t) − A(t) − m_carrera) ]
```

`H(t)-A(t)` tiene distribución Skellam bajo estos postulados. El `+1` es parte de la convención
de empate y debe mantenerse visible. Si `λ_a≥λ_h>0`, la carrera eventual da captura con
probabilidad 1: no se prolonga la potencia anterior fuera de su dominio.

Esto define un evento de carrera, **no demuestra** que equivalga a revertir un pago de ZEROX.
El horizonte posterior es infinito bajo las tasas fijadas; no son «30 minutos de exposición»
ni una probabilidad agregada durante diez años. F no aparece en esta función.

### Artefactos históricos que no forman parte del modelo

`prev` recorta el soporte a `[-400,59999]`, limita el exponente a 700 y devuelve cero si `α≤0`.
Una implementación nueva debe tratar colas y error numérico explícitamente. El caso sin adversario
necesita especificar también el estado inicial: conservar una ventaja adversaria artificial
positiva y devolver cero por convenio no equivale al evento definido arriba.

Los resultados publicados `7,071·10⁻³⁶` y `1,148·10⁻¹⁰` están en
[salida de ronda 12](../../../research/scripts/d12-quorum/salida_b.txt), línea 15.
Son **D históricas**, no nuevas mediciones. Ni los ceros impresos por underflow ni el truncamiento
numérico permiten publicar irreversibilidad determinista. No se han recalculado aquí.

### Tiempo fijo y número de bloques son modelos diferentes

Esperar hasta observar M eventos honestos fija `H(T_M)=M`; esperar `M/λ_h` segundos deja H aleatorio.
Por tanto, sustituir el tiempo de parada por su media cambia el experimento. Además, un cliente
no conoce la etiqueta «honesto» de cada bloque, y una regla no puede usar información que sólo
se obtuvo después de su supuesto instante de aceptación.

R0 no porta la regla adaptativa de [D14](../../../research/scripts/d14-dagknight/d14k_visible2.py)
ni su conversión a tiempo medio en [D16](../../../research/scripts/d16-gate/gate_igual_eps.py).
Tampoco importa `union10`: el número de oportunidades de ataque y el presupuesto acumulado
de riesgo requieren otro contrato; una unión de eventos no necesita independencia, pero sí
eventos y cotas por oportunidad que correspondan al sistema estudiado.

## 5. Qué significaría aceptar un pago en T1

**Escenario de trabajo propuesto, no política de producción adoptada:** Cortex consulta un nodo
completo propio que verifica pruebas, autorización y estado. Un servidor privado o un cliente
ligero se estudian aparte; no se presume que una respuesta RPC sea prueba de finalidad.

Estados que deben distinguirse:

```text
recibido → incluido → pruebas y autorización válidas → aplicado en el orden DAG → aceptado por Cortex
```

La inclusión no basta: en R-FIN-8′ un bloque puede permanecer en el DAG mientras una transacción
suya pierde un conflicto de ejecución. Para el transparente importa el gasto aplicado al UTXO;
para el blindado, también los commitments, nullifiers, pruebas y reconocimiento del pago por la
wallet. Tener Orchard como dependencia no implementa esa transición.

Para una primera política temporal observable se propone:

1. Fijar `t0` al comienzo de cada intento: el nodo verificador aplica y reconoce el pago en su
   estado y comienza un episodio de aplicación y observación continuas.
2. Medir la espera con reloj monotónico local, no con el timestamp remitido por un productor.
3. Aceptar sólo si el pago sigue aplicado tras el intervalo y no se perdió la continuidad de
   observación; una retirada antes de aceptar cancela el intento. Si el pago vuelve a aplicarse,
   empieza otro con nuevo `t0` y la espera completa. Las condiciones de frescura,
   disponibilidad y recuperación de sincronización aún deben especificarse.
4. Contar como fallo que un pago aceptado deje después de estar aplicado en la historia válida
   adoptada por ese observador, y registrar por separado aceptación de gastos incompatibles por
   dos observadores honestos. Un bloqueo de progreso también se registra, pero no se oculta como
   «éxito de seguridad» ni se confunde con reversión. Gastar legítimamente después el UTXO o la
   nota recibida no retira el hecho histórico del pago y no cuenta como ese fallo.

Esta propuesta de `t0`, continuidad y reinicio no está contenida en `prev`. Condicionar aceptación
a una trayectoria observada puede cambiar su distribución. Hay que definir también si el bloque
de inclusión cuenta en H o queda absorbido en el estado inicial. **No se sustituye t por 1 800
en R0 y se atribuye sin más el resultado a esta política.**

La garantía buscada debe declarar: por pago o acumulada, condicional a aceptación o por intento,
horizonte, adversario permitido, condiciones de red y `ε_pago`. El importe y la política comercial
pueden fijar ε; no modifican retroactivamente el modelo que produjo una cifra.

**Limitación del código actual:** [validar_tx](../../../crates/zx-consensus/src/validacion.rs),
líneas 106–119, declara que no verifica firmas. La autorización existe separadamente en
[satisface](../../../crates/zx-consensus/src/testigo.rs), y el ensamblaje completo no está conectado
en el validador de cuerpo ni en el nodo. [comprobar_cuerpo](../../../crates/zx-node/src/cadena.rs),
líneas 643–668, verifica correspondencia con la cabecera, no gastos, firmas o importes.
Ni esas funciones ni la cabecera PoW de 92 B pueden ser el oráculo completo de T1.

## 6. Resolución de cruces antes de calcular

**Cerrado documentalmente** significa que se eliminó una ambigüedad de referencia, no que el
consenso esté implementado o probado. No se eligieron nuevos I, L, ρ, Δ, W ni ε.

| Punto | Resolución | Estado y trabajo restante |
|---|---|---|
| Unidades / contador de épocas | Índices enteros separados de segundos físicos; R-FIN-9 remite a `T_j=j·I_slots`, no `c·j`. S_max150 se conserva como 150 slots nominales. | **Referencia cerrada** en SPEC §7.3 y ancla R-FIN-1a/2/9. P: calendario, origen, ancla disponible y actualización N(s). |
| `k=25`, slot estricto, U3′-filtro | Corregidos a k30, empate permitido y U3″ dinámica. | **Residuos cerrados** en ancla §2/R-FIN-1a/6. No se alteran resultados de simulaciones antiguas. |
| Límites y shuffle | 15/180 a k30; shuffle de candidatos, no cuota exacta de padres finales. | **Referencia cerrada** contra Kaspa fijado; portado y conformidad de instrumentos pendientes. |
| Peso upstream / ZEROX | MAX_u64−SR y peso recíproco son diseños distintos; ZEROX conserva el segundo. | **Procedencia cerrada**. P: dominio de SR, enteros, overflow, controlador y prueba de seguridad propia. |
| Retarget antiguo / actual | Se excluye λ_real≈1,364/δ_real≈0,267 del controlador sólo azul; R-FIN-13′ exige contar lo pagado, no sólo el peso azul. | **Selección cerrada**, pero unicidad pagable incompleta: véase §6.2. No equivale a medir una nueva λ_real. |
| `I=112,5 s` / S_max150 | No satisface conjuntamente `S_max_slots<I_slots` del perfil que se conserva. | **Combinación excluida**, no refutación de la familia PoT ni elección de otro I. Tampoco hay prueba de finalidad a ese tiempo. |
| Presupuesto PoT | W_dec45 es máximo observado y ρ2,5 estimación. La condición histórica es un presupuesto de evaluación, no irreversibilidad. | **Alcance corregido**. P: cotas, trabajo secuencial, deadline y borde de igualdad (§6.1). |
| Número de anclas | `λS_max` usa una media; no impone máximo de bloques ni por sí sola esperanza para la ventana de selección. | **Cota dura retirada como premisa**. P: máximo protocolario o modelo/cola justificados. No es m_carrera=90. |
| Ventana de peso | Los W históricos y «error<1 %» vienen de otra tasa/F y una aproximación de desviación típica. | **Certificación retirada**; valores preservados como D históricas. P: análisis del controlador y discrepancia diferencial bajo ataque. |
| Pérdida honesta δ | Separadas red, parasitismo y controlador superado. | **Símbolos separados**. P: estrategias y presupuesto conjunto; no gastar todo α dos veces. |
| F / aceptación / L | F2h provisional, t_acept1800 en R0 y L1h candidato son tres objetos, no una sola garantía. | **Roles separados**. P: punto protegido local, política de pago, particiones y acuerdo global. C-CHK no es finalidad general. |
| Instrumentos | Las trazas sin shuffle/S_max no se usan automáticamente contra T1. | **Criterio de admisión fijado**. P: demostrar que cada traza cumple el perfil antes de trasladar resultados. |

### 6.1 Qué queda del argumento de época

Para N fijo, declarar `v_ref` en slots/segundo físico de **producción secuencial** y
`ρ_max=v_A,max/v_ref`. La reexpresión dimensional del presupuesto histórico es:

```text
I_slots ≥ ρ_max · v_ref · W_dec,físico
```

Usar sólo τ_nom como si fuera la duración física del equipo omite una hipótesis. La velocidad
de verificación no es el denominador de ρ; si N cambia, hay que especificar el trabajo del tramo
y su calendario. Además I separa umbrales `jI`, no necesariamente las inyecciones `slot(I_j)+L`.

Inferencia simbólica condicionada al **primer cruce**: si el padre tiene `p<T_j`, el ancla tiene
`b≥T_j` y `b−p≤S_max_slots`, entonces `b<T_j+S_max_slots`. El extremo superior sigue semiabierto.
En ese submodelo `I_slots≥S_max_slots` ya separaría los intervalos; la condición histórica
estricta es suficiente y se conserva, **no se relaja por esta observación**. Antes hay que cerrar
existencia del cruce, selección inequívoca y bootstrap; no se inventa ancla para un conjunto vacío.

La ronda 9c §E.3 sitúa evaluación completa en `ρ≥I/W_dec`, pero R-FIN-14(f) admite igualdad.
Para excluir terminar hasta un deadline inclusivo, esa igualdad no basta: falta decidir el
borde de trabajo/tiempo, no añadir una desigualdad nueva tácitamente. La duración de esta
restricción tampoco es una duración demostrada de finalidad.

La propuesta de 112,5 s se localiza en [D13](../../../research/scripts/d13-finalidad/audita-d8.md),
§5, punto 3, y se repite en [D15](../../../research/scripts/d15-avalanche/audita-d8c.md), §3, punto 3:
proponen anclar confianza en el timelord; no aportan una regla de irreversibilidad demostrada.
No se incorpora esa nueva autoridad al baseline ni se transforma «falta prueba» en refutación.

### 6.2 Unicidad azul no equivale a unicidad pagable

El contrato actual de R-FIN-11/8′/13′ deja este caso sin resolver:

1. Dos copias de la misma identidad están en anticono mutuo: U2, limitado al propio pasado,
   no las invalida por ese solo hecho.
2. Si ambas son rechazadas por k y ninguna copia es azul, la primera roja no consume una
   identidad **azul**; la segunda todavía satisface la descripción de `rojo_k`.
3. R-FIN-8′ declara pagable ese color; la redacción anterior de R-FIN-13′ lo equiparaba a
   «un bloque por identidad». La revisión 2 retira esa equivalencia no justificada, sin
   inventar el paso que la haría cierta.

Es una laguna de especificación, **no un ataque completo ejecutado o demostrado**. La
[auditoría 8b](../../../research/dag-poas-ancla-de-orden-auditoria-8b.md), §§1 y 4, reconoce las
copias hermanas y que no midió parásita+copias conjuntamente. No suple ese paso con evidencia.

Para cerrarlo hay que decidir el conjunto de identidades consumidas, su alcance/persistencia,
el representante determinista entre copias y el efecto sobre recompensa, ejecución y retarget,
también al fusionar en momentos distintos. Debe ser contextual a la historia candidata, no un
filtro global de «primer mensaje recibido». **No se adopta aquí una regla nueva de ganador.**
La elegibilidad de fusiones fuera de ventana es otro problema: deduplicar no lo resuelve.

### 6.3 Orden de cierre restante

Primero el contrato de identidad pagable y el calendario PoT; después dominio/aritmética del
peso y controlador coherente con ese conjunto; finalmente hipótesis de red, política Cortex y
argumento R0→T1. Sólo entonces una cifra de T1 tendría parámetros y evento inequívocos.
R0 queda separado como control histórico ya definido, sin ejecutarlo en esta revisión.

## 7. Qué falta antes de una validación útil en Julia

| Cierre | Responsable / evidencia necesaria | Situación |
|---|---|---|
| Parámetros de R0 y evento de carrera | Esta ficha y el código fuente histórico. | Definidos documentalmente; sin validación numérica nueva. |
| Política de pago y ε | Usuario/Cortex: instante de aceptación, reinicios, riesgo por pago o servicio. | Propuesta en §5; no asumida como decisión final. |
| Red y disponibilidad | Modelo de retrasos, adversario, pérdidas/colas y condiciones de sincronización; después mediciones reproducibles. | Δ real sin medir. Un barrido hipotético deberá etiquetarse H. |
| Semántica DAG completa | Reglas de peso/retarget, unicidad de billetes pagables, orden, conflictos, flujos y calendario de slots. | Residuos consolidados en §6; contratos y demostraciones aún pendientes. |
| Paso R0→T1 | Justificar ventaja 3k, proceso de crecimiento, empates, pesos, estrategia y efecto de F para el evento de pago elegido. | No demostrado. No basta reproducir la tabla. |
| Privacidad y autorización | Verificador completo transparente/blindado y transición de estado, o hipótesis de validez condicional explícita. | No integrado; el submodelo de carrera no audita criptografía ni wallets. |
| Cálculo y precisión | Referencia matemática, control de colas/error, casos de borde, entorno y recursos según LINEO. | Se prepara después de acordar el alcance; no se ejecutó en este paso. |

Es posible validar R0 como **control histórico** sin esperar a implementar todo el nodo. Eso no
cerraría T1 ni permitiría anunciar «Cortex puede entregar el producto». El avance de R0 se informa
separado de la demostración y validación del protocolo destino.

## 8. Versionado y comprobación de esta ficha

Las rutas y secciones citadas identifican la procedencia; [FUENTES.sha256](FUENTES.sha256) fija
los bytes de las fuentes principales **tras la revisión 2**, incluidos cambios no comprometidos
del workspace. [FUENTES-r1.sha256](FUENTES-r1.sha256) conserva las huellas originales de la
revisión 1: es un registro histórico, no la comprobación del estado actual ni una copia de archivos.
Los commits de Autonomys y Chia figuran en PDF/README, sin seguir automáticamente sus ramas nuevas.
Un cambio de tasa, δ, peso, regla de empate, origen del reloj, horizonte o adversario requiere
revisión del modelo; no es una optimización del mismo cálculo.

Trabajo realizado: lectura de SPEC, investigación, instrumentos y Rust; comprobación de rutas,
commits y huellas. **No se ejecutaron Julia, Python, benchmarks ni tests de consenso.**

Las huellas vigentes se comprueban desde la raíz de ZEROX con
`sha256sum --check veritas/finalidad/baseline-30m/FUENTES.sha256`.
Los clones completos permanecen fuera del control de versiones de ZEROX; sí se conservan las
rutas, commits y huellas que permiten identificar la evidencia.

**Cambios de revisión 2:** consolidación en SPEC/ancla, rectificación de alcance del empalme,
procedencia de actualización PoT y shuffle, laguna de unicidad pagable y contratos de unidades.
No cambian las cifras históricas de R0 ni se ejecutan instrumentos de cálculo. La revisión se
contrasta por especialistas Rust, matemáticas/Julia y C++, con comprobaciones documentales.
