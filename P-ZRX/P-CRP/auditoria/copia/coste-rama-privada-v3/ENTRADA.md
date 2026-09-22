# Encargo 07v2 — Umbral de una rama privada bajo flujo PoT, DAG real y red asimétrica

**Ejecutor:** DeepSeek, exclusivamente en la zona aislada `deepseek/`.
**Diseñado para:** corregir y sustituir la evidencia protocolaria de CRP-v0.1, sin borrar ni
reescribir el instrumento anterior.
**Categoría Veritas propuesta:** `seguridad` (dominante); `consenso` y `rendimiento` (secundarias).
**Ruta de trabajo:** `deepseek/veritas/seguridad/coste-rama-privada-v2/`.
**Destino eventual, solo después de validación independiente:**
`veritas/seguridad/coste-rama-privada-v2/`.

CRP-v0.1 queda etiquetado para este encargo como:

> **baseline idealizado útil; veredicto protocolario inconcluso**.

Este encargo no autoriza editar `SPEC.md`, `TAREAS.md`, código del nodo ni instrumentos fuera de
`deepseek/`. No migres, no hagas commit y no conviertas resultados condicionados en reglas.

---

## 0 · Entrada congelada y método de trabajo

Este archivo es una entrada inmutable. La huella esperada, proporcionada por el validador, está en
`deepseek/ENCARGO-07v2-coste-rama-privada.sha256`. El ejecutor **MUST NOT** editar ni el encargo ni
esa huella; sirve contra cambios accidentales, no como firma criptográfica de un tercero.

Antes de crear el proyecto o escribir cualquier artefacto, lee íntegros `AGENTS.md`, `README.md`,
`MIGRACION.md`, `research/README.md` y `veritas/LINEO.md`. Después:

1. Ejecuta `sha256sum -c deepseek/ENCARGO-07v2-coste-rama-privada.sha256` desde la raíz. Si falla,
   detente y no copies la entrada ni crees artefactos.
2. Copia este archivo byte por byte a
   `deepseek/veritas/seguridad/coste-rama-privada-v2/ENTRADA.md`.
3. Registra en `PROCEDENCIA.md` la huella de ambos archivos y comprueba que coinciden.
4. Incluye `ENTRADA.md` y el encargo original en las huellas finales.
5. Si la entrada cambia durante la ejecución, detente: conserva el trabajo como ejecución
   invalidada y no mezcles resultados de las dos versiones.

Lee además, íntegros antes de modelar:

- `deepseek/veritas/seguridad/coste-rama-privada-v1/` completo;
- `SPEC.md` §6.1–§7.3, §11 y las secciones de finalidad, red y sincronización que el modelo use;
- `TAREAS.md` §2.1–§2.4 y los pendientes de red/finalidad aplicables;
- `research/dag-poas-ancla-de-orden.md`, en particular R-FIN-1a, R-FIN-2…5,
  R-FIN-11, R-FIN-13′ y R-FIN-14;
- `veritas/consenso/dominio-autorizacion-v1/`;
- `veritas/consenso/contrato-billete-v1/`,
  `veritas/consenso/identidad-disponibilidad-v1/` y
  `veritas/consenso/disponibilidad-causal-multivista-v1/`;
- `veritas/consenso/ghostdag-rank-v1/`;
- `veritas/consenso/retarget-causal-endogeno-v1/` y
  `veritas/consenso/admision-retarget-multivista-v1/`;
- `veritas/finalidad/delta-medido-v1/`;
- `research/dag-poas-auditoria.md`, únicamente como evidencia histórica del ATAQUE 2;
- las revisiones posteriores sobre flujos e IOPS, incluidas
  `research/dag-poas-candidatos-auditoria.md` y `research/coste-ploteo-medido.md`;
- `PDF/README.md`, el commit upstream fijado y las fuentes primarias pertinentes de PoAS/PoT:
  `auditing.rs`, `proving.rs`, cálculo de distancia, verificador de solución y reloj PoT;
- `crates/zx-core/src/wire_dag.rs`, `crates/zx-consensus/src/ghostdag.rs`,
  `crates/zx-consensus/src/bloque_dag.rs`, `crates/zx-consensus/src/fork_choice.rs`,
  `crates/zx-node/src/cadena.rs`, `crates/zx-p2p/src/rele_compacto.rs`,
  `ci/reglas-sin-cablear.txt`, `ci/reglas-sin-codigo.txt` y `ci/consenso-pendiente.txt`.

Cuando dos documentos discrepen, no elijas por antigüedad ni conveniencia: registra la
contradicción y aplica la jerarquía de `AGENTS.md`/`research/README.md`. La evidencia histórica no
es autoridad normativa. En particular, R-FIN-5, DAV, DCM, RCE y ARM son reglas/contratos candidatos
o instrumentos, no consenso activado por el mero hecho de estar escritos.

Antes de implementar, crea en `MATRIZ-AUTORIDAD.md` una tabla
`regla / fuente / estado normativo / integración / dependencias pendientes / conclusión permitida`.
Usa como mínimo los estados: `SPEC vigente`, `candidata`, `oráculo abstracto`, `implementada sin
cablear`, `integrada`, `pendiente` y `excluida`. La validez de una traza es trivaluada:
`Válida`, `Inválida` o `Pendiente`. Una decisión ausente —incluidos PoT conjunto, flujo,
controlador, C-GD-11 o finalidad aplicable— nunca se resuelve localmente para obtener `Válida`.

Lee `veritas/LINEO.md` completo antes de escribir simulaciones o tests. Julia en CPU; C++/CUDA solo
si el perfil lo justifica. **No crees ni ejecutes auditorías Python.** Los scripts Python históricos
solo pueden inspeccionarse como evidencia para un port explícitamente validado.

Por exigencia de `AGENTS.md`, solicita revisiones independientes de matemáticas/probabilidad, Rust y
semántica upstream, y Julia/numerismo; C++/CUDA solo si se usa. Conserva sus dictámenes como
entregables. Un bloqueo técnico no resuelto impide el cierre aunque la suite propia pase.

---

## 1 · Pregunta y resultado permitido

Pregunta principal:

> Para una fracción adversaria de espacio `α`, ¿cuál es la probabilidad de que una historia privada
> clasificada `Válida` bajo las reglas de su escenario supere estrictamente el
> `blue_work` de la punta pública, en función del horizonte, la red, el controlador y el número de
> flujos PoT que el adversario pueda costear? ¿Qué parte puede atribuirse al protocolo actualmente
> especificado y qué parte solo a un escenario candidato?

Una traza `Pendiente` puede cuantificar sensibilidad, pero **no cuenta como ataque válido** ni se
mezcla en `P_win`; informa por separado qué decisión ausente cambiaría su clasificación.

Usa `W_pub` y `W_priv` para los incrementos de `blue_work` **posteriores al ancestro común**. No
llames “honesto” a todo `W_pub`: si el adversario publica parcialmente, la punta pública puede
contener trabajo suyo. Declara el observador que decide —nodo veterano, nodo nuevo desde génesis,
nodo eclipsado, uno/algunos/todos los honestos— y la regla exacta de adopción.

No existe un único “umbral” sin más argumentos. Define y publica por separado:

```text
P_win(α,T,d,E,O) = P[W_priv(T) − W_pub(T) > d | escenario E, observador O]
α_prob(p₀,T,d,E,O) = inf { α : P_win(α,T,d,E,O) ≥ p₀ }
g_E(α) = lim_{T→∞} E[W_priv(T)−W_pub(T)]/T, si el límite existe
α_drift(E) = frontera(s) entre regiones de signo de g_E(α)
P_eventual(α,d,E,O) = P[algún T: W_priv(T)−W_pub(T) > d]
```

`p₀`, `T`, `d`, el punto de fork, el comienzo del cómputo privado, el instante de presentación y el
observador son parte del resultado. No uses `P=1/2` por defecto ni llames `α_drift` “mínimo de
ataque”. En horizonte finito puede haber probabilidad positiva con deriva adversa. Comprueba la
monotonicidad antes de invertir una curva y propaga los intervalos de confianza a un intervalo para
`α_prob`, no a un único cruce interpolado. Si `g_E` no existe, tiene varias raíces o no es monótona,
declara `α_drift` indefinida o publica todas las raíces y regiones de signo; no elijas una.

Debes separar, sin mezclarlos:

1. **Baseline analítico:** un flujo compatible, eficiencia azul simétrica y controlador acoplado.
2. **SPEC actualmente escrito:** conserva como `Pendiente` la inyección, las dependencias de flujo,
   el controlador y cualquier otra regla no cerrada; no promociones un contrato experimental.
3. **DAG con red:** anticonos, color contextual `rojo_k`, U2/U3″, vistas locales y liberación
   adversaria.
4. **Escenario candidato R-FIN-5:** los bloques cuyos prefijos PoT ya eran incompatibles en el slot
   histórico consultado no pueden incorporarse a la misma historia. El adversario presenta la mejor
   de varias ramas; no suma sus trabajos. Una divergencia futura no invalida retroactivamente un
   bloque cuyo prefijo coincidía en `slot(X)`.
5. **Contrafactual aditivo sin filtro de flujo:** permite sumar trabajo de flujos incompatibles.
   Cuantifica el peligro `S·α`, pero no representa una regla hoy adoptada ni basta desactivar
   R-FIN-5 para garantizar que GHOSTDAG sume todo.
6. **Regímenes corto y largo:** carrera con plazo/deadline frente a comparación long-range bajo un
   reloj y una ventana temporal explícitos. “Tiempo arbitrario” no congela por arte de magia la
   historia honesta.

Resultados finales admisibles:

- **demostrado para una regla vigente e integrada**;
- **demostrado/medido condicionado a supuestos enumerados**;
- **inconcluso porque falta una regla o integración**;
- **contraejemplo válido**.

No se admite “en la liga de PoW”, “solo ingeniería”, “ataque del 4 %” ni “seguro al 50 %” si alguna
hipótesis necesaria permanece pendiente o si la traza no pasa las reglas de su escenario. Una
búsqueda finita de estrategias aporta ataques concretos y cotas inferiores de riesgo; solo una
demostración de exhaustividad o una cota superior sobre **todas** las estrategias admitidas puede
cerrar un umbral protocolario.

---

## 2 · Defectos conocidos de CRP-v0.1 que debes corregir

No basta con añadir tests al v1. Crea v2 separado y trata los puntos siguientes como regresiones
obligatorias.

### D1 · El supuesto DAG era una cadena

`construir_rama_gdr` actualiza las puntas después de cada bloque, incluso dentro del mismo slot, y
deja una sola punta. La salida tiene `n_azules = n_total + 1`: no ejercita anticonos ni `rojo_k`.

**Corrección obligatoria:** simulación por eventos/vistas locales. Los bloques concurrentes se
producen contra la vista disponible en el instante de autoría, antes de recibir bloques todavía en
tránsito. La propagación posterior debe crear puntas, anticonos y rojos reales. Reutiliza GDR-v0.2;
no reimplementes GHOSTDAG.

Incluye un fixture determinista construido para producir un `rojo_k` conocido y otro que deba
producir cero, con anticonos y colores esperados. Añade un escenario estadístico de concurrencia
calibrada cuya tasa/IC esté justificada; no hagas fallar una realización estocástica solo porque
observe cero rojos a baja carga.

### D2 · La DP de granularidad perdía casi toda la masa

El corte fijo 0…60 descartó casi toda la distribución para `g=256` y no renormalizó. Además `d` se
declaró en unidades de trabajo pero se mantuvo como entero de bloques al cambiar `g`.

**Corrección obligatoria:**

- una única unidad explícita para déficit y saltos;
- si cada bloque pesa `1/g`, representar el déficit como `d·g` o usar aritmética racional equivalente;
- soporte adaptativo o colas acotadas analíticamente, nunca un corte fijo llamado “desviaciones”;
- publicar la masa **cruda antes de cualquier renormalización**; queda prohibido ocultar la cola
  renormalizando;
- separar masa del kernel de transición, fuga por frontera de estados y masa absorbida por
  éxito/fracaso;
- propagar la cota por todo el horizonte: una cola por paso `τ` no acredita error final `τ`; usa una
  cota acumulada o DP inferior/superior que asigne la masa omitida a fracaso/éxito y publique
  `[P_L,P_U]`;
- exigir error total ≤ `10⁻¹²` solo cuando sea compatible con la precisión reclamada; si la
  probabilidad está por debajo de la cota numérica, publica únicamente una cota;
- para horizonte infinito, demostrar aparte el error de truncación del dominio de estados;
- referencia independiente para casos pequeños y comparación MC con IC en probabilidades
  observables; un MC ingenuo no valida eventos de probabilidad `10⁻¹²`.

### D3 · Empatar no es superar estrictamente

El contrato exige superar la ventaja pública inicial. Define
`D_n=d+W_pub(n)−W_priv(n)`, con `D_0=d≥0`. Para paseo ±1, con paso `+1` de probabilidad `p=1−α`,
paso `−1` de probabilidad `q=α` y `q<p`, las referencias son:

```text
P(alcanzar empate D=0)       = (q/p)^d
P(superar estrictamente D<0) = (q/p)^(d+1)
```

Para `q≥p`, ambas probabilidades eventuales son 1. En una red con lattice `1/g`, representa
`z=gD` y absorbe la superación estricta en `z≤−1`. Con saltos compuestos se puede saltar sobre 0:
implementa DPs separadas para empate y superación. Declara si se observa tras cada evento o al
cerrar un lote/slot y fija el orden de sucesos simultáneos.

En el borde `d=0`, “alcanzar empate” incluye el instante inicial `n=0`; “superar” exige un evento
posterior que lleve a `D<0`. Añade tests específicos para no depender de `0^0` ni de una convención
implícita.

En GHOSTDAG especifica qué puntas virtuales se comparan. C-GD-08 no cuenta automáticamente el peso
propio de una punta hasta que se incorpora; fija una convención terminal común —sin regalar un hijo
o sentinel a una rama— y separa `blue_work` estricto de los desempates de fork choice por
`solution_distance`/id.

La fórmula `1/(1+ε^(−1/d))`, cuando aplique al evento de empate, converge a `1/2` **desde abajo**.
Añade una regresión textual/numérica para que no vuelva a publicarse `1/2⁺`.

### D4 · `λ ∝ SR` era un supuesto, no una derivación

El v1 definió `λ(s,SR)=s·λ₀·SR/SR₀` y después “demostró” la cancelación contra el peso. Deriva la
probabilidad discreta desde las reglas PoAS que realmente correspondan: distancia circular,
condición `solution_distance ≤ solution_range/2`, todos los chunks ganadores y extremos de dominio.

Separa:

- identidad o cota matemática por chunk;
- número de chunks/sectores auditados;
- ganadores producidos;
- bloques estructuralmente admitidos;
- bloques azules que aportan `blue_work`.

Una fórmula discreta con `floor` puede ser exacta. Lo que no puedes llamar exacto es la
**cancelación/invariancia** si la igualdad no se cumple. Conserva la fórmula exacta con sus suelos y
publica una cota de desviación en los extremos y en el rango operativo respaldado por fuente.

### D5 · El controlador real no se modeló

No fijes directamente `sr_adversario = sr0/K`. Hoy no existe un algoritmo normativo completo del
controlador destino: C-HDR-06 fija causalidad/interfaz, mientras arranque, ventana, redondeos,
fusiones tardías y validación multivista siguen pendientes. RCE/ARM son perfiles candidatos y
reciben parte del contexto como oráculo; no los promociones a consenso.

Por tanto:

- la corrida “controlador del SPEC” queda `Pendiente`, identificando el primer dato ausente;
- implementa por separado el perfil candidato RCE/ARM exactamente como está contratado;
- en ese perfil, cada bloque registra pasado, flujo, conjunto pagable/color contextual,
  observaciones y cálculo que produjeron su `SR`;
- la admisión de rango se ejecuta antes de entregar el bloque a GDR;
- familias como `sr0/K` son solo sensibilidad y no respaldan el veredicto protocolario.

### D6 · Los rojos asimétricos no estaban medidos

Define eficiencia de trabajo, no una fracción global de bloques:

```text
η_x(T) = E[incremento post-fork de blue_work azul de x]
         / E[trabajo bruto elegible post-fork de x]
```

Declara denominador, ventana, punta/contexto de color y estimador; cuenta cada bloque una vez y
excluye el prefijo común. `η` puede depender de `α,Δ,T,estrategia,SR,S`, así que normalmente la
frontera es una raíz implícita, no una constante reusable.

Para una afirmación asintótica define, si existen, la tasa bruta por unidad de recurso
`c_x^∞=lim E[trabajo_bruto_x(T)]/(T·recurso_x)` y
`η_x^∞=lim E[blue_work_x(T)]/E[trabajo_bruto_x(T)]`. Contrasta la fórmula auxiliar contra
`g_E(α)` calculada directamente. Si el retarget/no estacionariedad impide esos límites, no publiques
una frontera de deriva.

Solo para retención total, una rama por lado y límites existentes `c_h^∞,c_a^∞,η_h^∞,η_a^∞`, la
frontera de deriva satisface implícitamente:

```text
α·c_a^∞(α)·η_a^∞(α) = (1−α)·c_h^∞(α)·η_h^∞(α)
```

La forma cerrada `α_drift=c_h^∞·η_h^∞/(c_h^∞·η_h^∞+c_a^∞·η_a^∞)` solo vale si esos términos no
cambian al variar `α`; de lo contrario resuelve la igualdad y publica todas las raíces/regiones.

El factor `S` aparece **únicamente** en el toy/contrafactual aditivo, sustituyendo
`c_a·η_a` por `S·c_a·η_a`. No aplica al máximo de ramas incompatibles ni a publicación parcial.

Reutiliza el generador de topología/eventos o trazas conjuntas pertinentes de DMS-v0.1/r2; no
dibujes Δ marginales iid y los llames vistas de red coherentes. Declara correlaciones, orden de
eventos simultáneos, ventana de autoría, distribución de espacio entre productores, política
C-GD-10, presupuesto adversario de retraso/eclipsado, nodos/aristas controlados y latencia privada.
DMS es una red sintética honesta: si solo se reutiliza una marginal, etiquétalo sensibilidad sin
causalidad DAG. Las tablas históricas de Δ=4/8/12/16 s son controles de regresión, no datos
automáticamente transferibles.

### D7 · Multistream era una identidad tautológica

El v1 implementó `S·α/(1−α+S·α)` y testeó la misma fórmula. Eso no demuestra que `S` flujos puedan
sumarse.

Cada traza del escenario candidato debe llevar un descriptor que incluya `PotOrigin` —dominio,
origen de índices, semilla y `N` inicial autenticados— y eventos ordenados
`(slot_activación, entropía, N_efectivo)`. La pareja `(entropía,t)` no basta si cambia `N(s)`.
Compara prefijos en `slot(X)`, no etiquetas de flujo actuales, y valida separadamente cualquier
horizonte de justificación hasta `slot+D`. Si origen, autenticación, calendario o `N` no están
definidos por una fuente autorizada, el resultado es `Pendiente`.

Antes de colorear o sumar trabajo:

1. comprueba compatibilidad de todo `past(B)` en los slots solicitados;
2. en el escenario candidato R-FIN-5, rechaza incorporar un bloque cuyo prefijo ya era incompatible
   en su slot histórico; una divergencia posterior no invalida el pasado común;
3. conserva el escenario que permite la fusión únicamente como contrafactual inseguro;
4. cuando la incorporación esté prohibida, define historias completas `W₁…W_S` con déficits
   `d₁…d_S`, prefijo común contado una vez y calcula `P(max_i{W_i−d_i} > W_pub)`; la selección ocurre
   al presentar, no cambia por slot salvo estrategia adaptativa separada;
5. mide también el riesgo de split/liveness entre honestos con prefijos temporalmente distintos;
6. no uses U2/U3″ para sanar una incompatibilidad que R-FIN-5 debe rechazar antes.

Genera conjuntamente las ramas desde las mismas parcelas, sectores, oportunidades físicas y
presupuestos de I/O/CPU. No uses RNG marginales independientes por comodidad: los desafíos
determinan la correlación. Controles obligatorios: flujos idénticos/correlación perfecta recuperan
`S=1`; un caso iid sintético con déficit cero recupera
`1−E[F_{W|W_pub}(W_pub)^S]`; y deben cumplirse las cotas de unión
`max_i P(E_i) ≤ P(∪E_i) ≤ min(1,Σ_i P(E_i))`. Para `S` fijo, el máximo solo deja invariante la
deriva si se demuestra concentración suficiente, por ejemplo
`Var(W_i(T))=o(T²)` uniformemente, tasas medias límite e integrabilidad uniforme. Entonces
`E[max_i(W_i−E[W_i])]/T→0`. Si no se demuestra, limita el resultado a medir/acotar el máximo.
Separa siempre `S` fijo de un árbol cuyo número de hojas crece con `T`.

El oráculo GDR no contiene PoT ni descriptor de flujo. Envuelve su entrada con una capa estructural
independiente; no afirmes que GDR verificó R-FIN-5 ni que R-FIN-5 está adoptada.

En el toy aditivo ideal, `S=24` y `α=0,04` son igualdad de tasas (`24·0,04=1−0,04`), no
superación estricta ni victoria finita. Deriva positiva exige `α>0,04`; fuera del toy, esa cifra no
se transfiere automáticamente.

### D8 · El fixture U2/U3″ entre ramas era insuficiente

No acredites “azul en su propia rama” mediante `es_ancestro(x,x)`. El color no es propiedad global
del bloque: registra `(punta/contexto, bloque) → color` e inspecciona conjunto azul y `blue_work`
reales en cada punta. Incluye:

- dos copias del mismo billete en una rama compatible;
- dos ramas disjuntas con el mismo billete y flujo compatible;
- dos ramas con prefijos PoT realmente divergentes;
- intento de fusión de cada caso;
- orden explícito: compatibilidad de flujo, validez, U2 y después color U3″.

### D9 · `S=24` no fue una medición del v1

Separa tres magnitudes:

- `S_escenario`, elegido para un barrido y etiquetado como tal;
- `S_microbenchmark`, observado en la máquina de esta ejecución y limitado al componente realmente
  ejercitado;
- `S_adversario`, cota o distribución respaldada por un perfil de hardware explícito.

No derives `S` de “SSD 100k IOPS” sin una medición compatible. Mide o acota, por flujo:

- lecturas aleatorias efectivas, tamaño y profundidad de cola;
- p50/p95/p99 y rendimiento sostenido, distinguiendo caché de página de almacenamiento;
- núcleos y tiempo de generar/verificar PoT;
- PoAS/KZG y demás CPU por slot;
- margen de utilización estable; no uses el 100 % nominal como capacidad segura;
- competencia entre flujos por CPU, memoria e I/O.

No fabriques un benchmark de 4 TiB si el hardware/dataset no existe. Si solo se puede medir un
microbenchmark o reutilizar evidencia no equivalente, publica una cota y deja `S_adversario`
pendiente. No conviertas `floor(100000/4161)=24` en capacidad acreditada.

Los benchmarks de I/O deben ser de solo lectura, sobre un destino explícito y acotado; no uses
dispositivos raw, `drop_caches`, escrituras destructivas ni datasets enormes dentro del repositorio.
Declara bytes, duración, caché fría/caliente y si el ensayo distingue page cache de almacenamiento.
Un resultado matemático paramétrico `P(α,S)` puede cerrarse condicionado a `S`; solo una afirmación
económica sobre un adversario concreto exige acreditar `S_adversario`.

### D10 · “Ataque gratis” estaba sobre-enunciado

Contabiliza por separado:

- espacio adicional;
- CPU/PoT/IOPS;
- energía;
- recompensa y tarifas a las que se renuncia durante la retención;
- duración real desde la bifurcación hasta la decisión;
- capital/hardware ya hundido frente a coste marginal.

Si el adversario publica la misma producción en la historia honesta, ésta crece con su aportación y
el escenario cambia. Si retiene para obtener `α` contra `1−α`, pierde recompensas durante toda la
carrera pertinente. No sustituyas esa duración por `Δ·conf` sin una derivación y unidades.

La conclusión máxima permitida sin un modelo económico completo es “cero espacio plotteado
adicional bajo los supuestos declarados”, no “ataque gratis”.

---

## 3 · Modelo mínimo obligatorio

### 3.1 Actores y vistas

Implementa múltiples nodos honestos con vistas locales del DAG y al menos un actor adversario. Los
eventos mínimos son: slot PoT, producción, selección de padres desde la vista local, envío,
recepción, validación estructural, compatibilidad de flujo, coloreo GHOSTDAG, retención y
publicación adversaria.

Una réplica debe conservar una traza reproducible que permita verificar por qué cada bloque fue
clasificado `Válido`, `Inválido` o `Pendiente`, y por qué fue azul, `rojo_k` o `rojo_U3` **en cada
contexto que lo fusiona**.

Separa al menos tres consumidores: (a) nodo veterano sujeto a la regla de finalidad/reorg aplicable;
(b) nodo nuevo que descarga y valida la historia completa desde génesis; (c) sync sucinto, hoy no
disponible. Fija ancestro común, punto de fork respecto de checkpoint/finalidad, déficit inicial,
deadline, instante de presentación y regla de adopción. Un eclipse que deja al nodo `Pendiente` no
es automáticamente una victoria de selección.

C-GD-11 conserva decisiones pendientes —métrica, valor, bootstrap, borde y relación con
finalidad/poda— que pueden cambiar si una liberación/fusión es válida. Si una traza las necesita,
no elijas localmente: clasifícala `Pendiente` y, si es útil, estudia perfiles de sensibilidad
claramente separados.

### 3.2 Producción y todos los ganadores

No reduzcas varios chunks ganadores a `min(d₁,…,d_C)` si upstream produce todos los ganadores como
billetes distintos. Deriva el proceso desde sectores, chunks, distancia y SR, o demuestra la
equivalencia exacta de la abstracción usada.

Separa y mapea explícitamente: identidad criptográfica de solución, identidad U2/U3, coordenada de
oportunidad y derecho económico pagable. No presupongas que son la misma clave. R-FIN-13′ cuenta el
conjunto pagable —azules y `rojo_k`, excluyendo `rojo_U3`—, mientras `blue_work` cuenta azules; el
controlador candidato debe consumir el conjunto que su contrato declara.

### 3.3 Flujo PoT

Cada bloque del escenario candidato debe incluir en el modelo al menos:

- `PotOrigin` autenticado y descriptor acumulativo de flujo;
- eventos `(slot_activación, entropía, N_efectivo)` conocidos en cada slot consultado;
- slot y horizonte de la justificación;
- procedencia del descriptor desde `past(B)`;
- resultado candidato R-FIN-5 frente a cada elemento del pasado incorporado, evaluado en
  `slot(X)`, y comprobación separada del horizonte futuro de la prueba.

Si no se ejecuta criptografía PoT AES real, llama al resultado **compatibilidad estructural de
flujo**, no “PoT verificado”. La ausencia del verificador integrado no se sustituye por `true`.
Registra además la tensión entre la caché de una salida por slot de C-NET-31/32 y las alternativas
por flujo; no elijas caché global o `(flujo,slot)` sin regla autorizada.

### 3.4 Estrategias adversarias

Como mínimo:

- retención de una rama y liberación a profundidad/horizonte elegido;
- elección válida de padres;
- rama privada con menor latencia interna que la red honesta;
- `S` ramas PoT incompatibles presentando la mejor;
- contrafactual de suma de `S` flujos;
- creación, abandono y selección adaptativa de ramas, separada del caso de `S` fijo;
- sensibilidad a VDF más rápido como parámetro separado de `α`, sin confundir espacio con
  espacio×velocidad.

Para `S` ramas fijas define `W₁…W_S`, déficits iniciales `d₁…d_S`, prefijo común, instante único de
selección y evento `max_i{W_i(T)−d_i}>W_pub(T)`. Para árboles adaptativos declara cómo puede crecer
el número de hojas con el horizonte y su coste. No afirmes optimalidad. Declara exactamente qué
estrategias se ensayaron, cuáles faltan y qué cota —inferior o superior— aporta cada una.

### 3.5 Escenarios y barridos

Usa una rejilla elegida y etiquetada que cubra, al menos:

- `α` a ambos lados de las fronteras observadas;
- `S ∈ {1,2,4,8,16,24}` como **escenarios**, no capacidades acreditadas;
- varios déficits iniciales y horizontes cortos/largos expresados en unidades de `blue_work`, slots
  y segundos;
- niveles `p₀` predeclarados para `α_prob`, sin privilegiar 0,5 por costumbre;
- red nominal, colas y régimen degradado;
- control simétrico y sensibilidad multivista cuando sea válida.

Refina adaptativamente cerca de cruces con un procedimiento secuencial/cobertura simultánea válido.
Publica el intervalo que acota `α_prob`, nivel de confianza predeclarado, límite unilateral cuando
haya cero éxitos y error de discretización. No inventes constantes de consenso para completar una
celda.

---

## 4 · Referencias y validación independiente

Se requieren tres niveles, con independencia por capa:

1. **Oráculos GHOSTDAG existentes:** referencia y kernel de GDR-v0.2; no reimplementes el coloreo.
2. **Oráculo exacto pequeño nuevo:** enumera calendarios, carreras, probabilidades y el wrapper de
   flujo para casos diminutos; recomputa `blue_work` desde los conjuntos azules devueltos por GDR,
   pero no se presenta como segundo oráculo independiente de GHOSTDAG.
3. **Kernel de escala:** Julia, validado diferencialmente contra la referencia clara de carrera/red,
   los casos exactos y el corpus GDR. Contrasta además el Rust aislado de
   `crates/zx-consensus/src/ghostdag.rs`; distingue `texto destino / instrumento / Rust aislado /
   ruta activa` y no confunde “hay código” con “está cableado en `zx-node`”.

Comprobaciones obligatorias:

- paseo ±1, empate y superación estricta;
- conservación de masa de cada distribución;
- unidades de `d`, peso, slots, segundos, bloques y `blue_work`;
- misma semilla ⇒ mismos resultados con 1 y varios hilos;
- cada traza adversarial satisface las reglas del escenario antes de contar su éxito;
- el escenario candidato R-FIN-5 impide incorporar bloques con prefijo ya incompatible en el slot
  consultado y no invalida por una divergencia futura;
- un **control escalar dedicado**, sin red, rojos, U2/U3, límites ni recursos compartidos, con
  streams iid de igual tasa y suma íntegra, recupera la frontera de deriva
  `α_drift=1/(S+1)`; desactivar R-FIN-5 en el DAG completo no está obligado a recuperarla;
- `S=1`, `Δ=0`, sin rojos y con igualdad de tasas recupera únicamente la frontera media del
  baseline, no necesariamente toda curva finita estricta;
- fixtures deterministas generan los anticonos/colores esperados y el escenario estadístico
  calibrado publica tasa/IC sin exigir rojos donde no corresponden;
- límites de GDR (`k`, padres y mergeset) se ejercitan de verdad;
- casos de borde de SR, suelos enteros y todos los chunks ganadores;
- ningún test compara una función consigo misma como única validación;
- mutation tests fallan al introducir deliberadamente `≥` por `>`, suma por máximo, color global,
  aceptación post-divergencia incompatible o renormalización de masa truncada.

Para la curva corta publica por separado:

- probabilidad de empatar alguna vez;
- probabilidad de superar alguna vez;
- probabilidad de superar antes de un deadline;
- `α_drift`, `α_prob(p₀,T,d,E,O)` y probabilidad eventual como objetos distintos;
- distribución/IC y cotas numéricas, no solo un punto de cruce interpolado ni “mismo orden de
  magnitud”.

---

## 5 · Criterios de aceptación y prohibiciones

El instrumento puede cerrar una **frontera condicionada de escenario** si, simultáneamente:

1. las trazas usan un DAG concurrente con vistas de red;
2. cada bloque contado tiene estado de validez y autoridad explícitos;
3. en el escenario candidato, flujo/R-FIN-5 se evalúa antes de GHOSTDAG;
4. el `SR` de cada bloque del perfil RCE/ARM es derivado, no elegido por el atacante desde la API;
5. rojos honestos y adversarios se miden, no se suponen iguales;
6. la DP acota el error final, conserva masa cruda y usa unidades coherentes;
7. la estrategia de varias ramas distingue máximo de suma;
8. `S` y el hardware quedan como parámetros; cualquier afirmación económica concreta respalda su
   `S_adversario` con medición/cota compatible;
9. corto y largo usan relojes y criterios de éxito explícitos;
10. ninguna regla pendiente se ha rellenado implícitamente y toda conclusión declara si depende de
    ella.

El **umbral protocolario global** solo puede declararse cerrado si, además, no queda una regla
pendiente que pueda cambiar validez/trabajo y existe una demostración de exhaustividad o una cota
superior aplicable a todas las estrategias válidas. Una batería finita de ataques, aunque sea
grande, no cumple ese requisito. Con el SPEC actual, flujo, PoT conjunto, controlador y partes de
C-GD-11/finalidad permanecen pendientes: salvo cambio autoritativo previo y documentado, el
veredicto global debe permanecer inconcluso.

Si falla un criterio del escenario, el veredicto correspondiente es **inconcluso condicionado al
punto que falta**. Eso es un resultado válido; no lo rellenes con una constante elegida.

Prohibido:

- editar el encargo durante la ejecución;
- editar `SPEC.md`, `TAREAS.md` o el código de producción;
- ejecutar auditorías Python;
- llamar “medido” a una fórmula evaluada;
- llamar “válida bajo el protocolo” a una traza que solo pasa un wrapper simbólico de PoT/flujo;
- tratar una simulación de red como cota universal;
- usar `100k IOPS`, 24 flujos, `F`, `I`, `L`, `ρ_max` o un controlador incompleto como hechos
  elegidos;
- reducir el espacio de diseño a dos opciones sin una demostración de exhaustividad;
- heredar el veredicto final de CRP-v0.1;
- ejecutar benchmarks destructivos o escribir en dispositivos raw.

---

## 6 · Entregables

En `deepseek/veritas/seguridad/coste-rama-privada-v2/`:

- `ENTRADA.md` — copia exacta de este encargo;
- `CONTRATO.md` — pregunta, criterios de éxito y lo que no acredita;
- `PROCEDENCIA.md` — huellas de entrada, fuentes y cronología;
- `MATRIZ-AUTORIDAD.md` — texto vigente, contratos candidatos, instrumentos, Rust aislado y ruta
  activa, con estado normativo e integración;
- `MODELO.md` — variables, unidades, adversario, reglas y escenarios;
- `METODO.md` — algoritmos, error numérico, presupuestos y comandos;
- `MATRIZ-VALIDEZ.md` — por escenario, qué reglas se aplican y por qué cada traza es `Válida`,
  `Inválida`, `Pendiente` o contrafactual;
- `INFORME.md` — resultados, límites y veredicto;
- `PROPUESTA.md` — únicamente obligaciones que una futura regla de flujo/controlador debe cumplir;
  no redactes reglas normativas ni números para el SPEC;
- `PROGRESO.md` — decisiones y correcciones con fecha;
- `HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md` — supuestos que, si se fijan por definición, hacen
  tautológico el resultado y por tanto no cuentan como evidencia transferida;
- `REVISION-MATEMATICA.md`, `REVISION-RUST.md`, `REVISION-JULIA.md` y, si corresponde,
  `REVISION-CPP-CUDA.md`, redactadas por revisores independientes;
- `src/`, `test/`, `bench/`, `resultados/`, `Project.toml`, `Manifest.toml` y versión de Julia;
- trazas mínimas reproducibles para todos los contraejemplos;
- `HUELLAS.sha256`, incluyendo `ENTRADA.md`, el encargo y su sidecar, fuentes, tests y resultados.

Cada cifra del informe debe declarar: valor y unidad, definición de la variable, versión del
modelo, fuente, adversario, escenario, criterio de aceptación y estado (`elegido`, `medido`,
`derivado`, `demostrado` o `pendiente`).

Antes de la corrida grande publica presupuesto de RAM, hilos, disco y tiempo. Perfila primero,
elige hilos por benchmark y conserva referencias pequeñas. Si se agota el presupuesto, entrega
checkpoint e **inconcluso**; ningún timeout es evidencia de seguridad.

---

## 7 · Preguntas que el informe debe contestar literalmente

1. ¿Qué parte de `α_drift=1/2` es identidad del baseline y qué parte se verificó bajo un escenario
   DAG con estado de autoridad explícito?
2. ¿Cuáles son `α_drift`, `α_prob(p₀,T,d,E,O)` y `P_eventual`, sin mezclarlos?
3. ¿Cuál es la frontera implícita con eficiencias de trabajo contextual `η_h` y `η_a` y cómo varían
   con escenario/horizonte?
4. ¿Puede una historia del escenario candidato R-FIN-5 incorporar y sumar bloques cuyos prefijos ya
   divergían en el slot histórico consultado? ¿Qué queda pendiente en el SPEC?
5. Si no puede, ¿cuánto aporta elegir el máximo de `S` ramas —fijas o adaptativas— y a qué coste?
6. ¿Qué toy model reproduce `1/(S+1)` como igualdad de deriva y cuánto se aparta de él el
   contrafactual DAG completo?
7. ¿El controlador candidato actualmente escrito permite construir la traza de SR adversarial? Si
   no está completo, ¿qué campo exacto impide decidirlo?
8. ¿Cómo cambia la curva con red y rojos asimétricos, bajo qué topología/trazas conjuntas y con qué
   IC/cota numérica?
9. ¿Qué `S` fue escenario, qué componente midió el microbenchmark y qué puede afirmarse sobre un
   adversario concreto?
10. ¿Cuál es el coste adicional de espacio, CPU, PoT, IOPS, energía y recompensa perdida?
11. ¿Qué cambia para nodo veterano, nodo nuevo desde génesis y sync sucinto inexistente?
12. ¿El resultado es ingeniería, consenso o todavía inconcluso? Responde por escenario, no con una
    sola etiqueta global.

El resumen ejecutivo debe empezar con una tabla
`afirmación / autoridad / estado / condición / evidencia` y terminar con una de estas frases, según
corresponda:

> **Umbral protocolario cerrado mediante cota exhaustiva para todas las estrategias y sin reglas
> relevantes pendientes.**

o

> **Frontera medida para los escenarios ensayados; umbral protocolario inconcluso.**

o

> **Umbral protocolario inconcluso; el baseline idealizado no sustituye las reglas pendientes.**
