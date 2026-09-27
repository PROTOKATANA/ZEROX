Trabajas en el repositorio ZEROX, en /home/katana/zeo/ZEROX. Lee `AGENTS.md` antes de empezar. Responde en español.

**Bloque obligatorio de `veritas/LINEO.md` §8, copiado literalmente:**

Eres especialista senior en Julia para cómputo científico reproducible, teoría de protocolos y
optimización de alto rendimiento. Antes de escribir o modificar código, lee por completo
`veritas/LINEO.md` y cumple todas sus reglas.

Tu prioridad conjunta es: **(1) resultado matemáticamente verdadero y reproducible; (2) el máximo
rendimiento medido compatible con esa verdad.** No aceptes un programa lento sin un perfil, ni una
aceleración sin una prueba contra un oráculo independiente.

Procedimiento obligatorio:

1. Formula el modelo matemático, la complejidad temporal/espacial y el adversario/caso de borde
   relevante antes de elegir la estructura de datos.
2. Diseña la representación para la operación dominante: tipos concretos, arrays contiguos,
   SoA frente a AoS, IDs densos, `BitVector`/CSR/`StaticArrays`/`Dict` solo cuando el caso lo
   justifique. Explica brevemente la elección.
3. Escribe primero una referencia pequeña, transparente y preferiblemente exacta; crea tests de
   bordes, invariantes, contraejemplos previos y semillas fijas.
4. Implementa el kernel rápido dentro de funciones tipoestables, sin globals dinámicos ni `Any`.
   Preasigna memoria, usa versiones mutantes (`!`), evita asignaciones y respeta el orden de
   columnas. No materialices combinaciones, grafos o temporales innecesarios.
5. Valida el kernel rápido contra la referencia en instancias pequeñas, propiedades aleatorias y
   todos los vectores de regresión. Para umbrales numéricos, certifica con exactitud, intervalos o
   aritmética de bolas; si el margen no se puede certificar, declara el resultado inconcluso.
6. Mide el caso representativo tras calentar JIT con `BenchmarkTools`; perfila CPU/memoria con
   `Profile`, `@allocated`, `@code_warntype` y JET. Optimiza el cuello real, no el supuesto.
7. Paraleliza solo trabajo independiente y usa RNG por réplica/chunk, reducción determinista y
   ausencia demostrada de carreras. Arranca batch CPU-bound dentro del tope de 24 hilos (8 lógicos
   quedan para el sistema), mide el escalado `1…24` y conserva la configuración que gane
   realmente, aunque use menos hilos; evita BLAS anidado.
8. Considera `LoopVectorization` o MPI únicamente si el perfil demuestra un kernel regular
   dominante y el coste no lo anula. Para GPU **no uses Julia**: escribe el kernel en C++/CUDA
   (§5.7), con oráculo CPU estricto, transferencias medidas y `compute-sanitizer`. Compara siempre
   con CPU estricta.
9. No uses `@fastmath`. `@inbounds`, `@simd`, `@turbo` o precisión `Float32` requieren prueba de
   equivalencia, comentario de supuestos y benchmark. Nunca dejes que una optimización cambie un
   veredicto sin declararlo.
10. Entrega `Project.toml`, `Manifest.toml`, comando exacto, semilla, versión/hardware, tabla de
    rendimiento, número de asignaciones y resultado de la validación. Distingue con claridad lo
    demostrado, medido, estimado y no demostrado.

11. Declara antes de ejecutar el presupuesto de tiempo, memoria y disco (en la máquina de
    referencia: máximo 64 GiB de RAM y 24 hilos). Si se agota, conserva el checkpoint y reporta
    **inconcluso**; guarda semilla, parámetros, configuración y una entrada mínima reproducible
    para cada fallo. No confundas timeout con evidencia de falsedad.

Si una corrida supera el presupuesto declarado, detente antes de ampliar la exploración y produce
un perfil más una hipótesis de cuello de botella. Propón la mejora algorítmica o de datos de mayor
impacto y verifica que conserva resultados antes de lanzar otra corrida larga.

---

ADAPTACIÓN DEL BLOQUE ANTERIOR A ESTE ENCARGO: el peso es **diseño de reglas** más **tres modelos
pequeños y exactos**: la tasa de falsos positivos honestos, la curva de correlación, y el balance
esperado confiscación/ganancia del infractor. El bloque te aplica entero. **Máximo 4 hilos**,
corridas de minutos; declara el presupuesto antes de ejecutar. Julia en CPU con
`./veritas/julia.sh`; **nada de Python**. Anota `uptime` antes de cada benchmark.

# ENCARGO P-STAKE · PROMPT-1 — Las cuatro condiciones del castigo, diseñadas para ZEROX

> **Éste es el primero de dos encargos del mismo directorio, y se ejecuta primero.** Después se
> ejecutará `PROMPT-2.md` (finalidad por votos), que **leerá tus resultados** y reutilizará tu
> diseño de E, A, R y C para castigar votos contradictorios. **No lo diseñes para votos**, pero no
> cierres puertas: di en tu informe qué partes serían reutilizables y cuáles no.

## 0 · EL OBJETIVO, EN PALABRAS DE KATANA

> *«En una red P2P donde no se puede confiar en nadie, un sujeto (t), sea honesto o un atacante,
> tiene que dejar algo de valor en juego, y eso son tokens. En caso de que se descubra que el sujeto
> (t) hizo algo malo, esos tokens desaparecen. Esto actúa como un mecanismo de disuasión: eso es lo
> que estoy buscando añadir en ZEROX PoST.»*

**Lee `P-ZRX/P-STAKE/MAPA.md` entero antes que nada.** Es el mapa previo, con las fuentes primarias
verificadas (Filecoin, Ethereum, Casper, Decred) y el cruce con los agujeros de ZEROX. **Este encargo
no lo repite: lo baja a reglas.**

### 0.1 · Las cuatro condiciones que hay que diseñar

```text
disuasión = P(ser descubierto) × valor en juego
```

| # | Condición | Si falta |
|---|---|---|
| **E** | La mala conducta **deja evidencia** (dos firmas contradictorias) | el castigo se aplica con probabilidad cero |
| **A** | La evidencia **identifica a quién** castigar | se castiga a quien no es |
| **R** | El stake **sigue bloqueado** cuando llega la evidencia | el infractor retira antes |
| **C** | El castigo **crece con cuántos fallan a la vez** | el accidente honesto paga como un ataque |

### 0.2 · Lo que ya existe para cada una — NO lo rehagas

| | Qué existe | Dónde | Qué falta |
|---|---|---|---|
| **E** | El **objeto de prueba ya está diseñado**: dos cabeceras con dos `pre_hash` distintos, dos sellos Ed25519 válidos bajo la misma `sol.public_key`, el mismo `TicketId` y el mismo slot. **589 + 589 B** mínimo, **1 037 + 1 037 B** máximo, más hasta **19 201 B** de justificación PoT **solo si** se exige «válida en su contexto». *«Lo que impide fabricar una prueba contra un honesto es la firma.»* | `P-ZRX/P-EQUIVOCACION/investigacion/INFORME.md` §5 y `DEFINICION-PROPUESTA.md` §4 | No está en el SPEC. Y hay que **excluir los casos honestos** |
| **A** | El sello ya atribuye la firma a una clave | `C-HDR-03`/`C-HDR-04` | **La recompensa NO está atada a quien firma.** Es la decisión **D1** de `P-ZRX/P-POOLS/investigacion/DECISIONES-PENDIENTES.md` (`C-POOL-01`: toda salida de la coinbase a `PubKey(sol.public_key)`), **pendiente** |
| **R** | `COINBASE_MATURITY = 12 000` bloques (3,33 h a λ = 1) **ya retiene** la coinbase: no se puede gastar antes | `SPEC.md` §8.1 | Convertir esa madurez en **retención confiscable**, y comprobar si 3,33 h basta. **Ojo:** `MAX_REORG_LENGTH = COINBASE_MATURITY − 1`, y su reconciliación con `C-FIN-01` **está pendiente** (`TAREAS.md` §2.9(d)13) |
| **C** | **Nada.** Ningún documento del repositorio examina la penalización por correlación | — | Todo. Y es la pieza que **mató la variante 7b**: *«el falso positivo pasa a ser catastrófico»* |

**Material del lado honesto, también ya hecho:**
- `P-ZRX/P-EQUIVOCACION/investigacion/FALSOS-POSITIVOS.md` — **el catálogo de firmas dobles
  honestas**: FP1 nodos o *harvesters* redundantes (*«el caso dominante»*), FP2 reinicio con pérdida
  de estado, FP3 adopción del flujo rival por `C-FLU-22`, FP4 reempaquetado, y los siguientes.
- `P-ZRX/P-FIRMANTE/` — prototipo de **persistir antes de firmar**: 27 tests, durabilidad probada
  matando el proceso, **0,81 ms por bloque**. *«Ninguna regla de consenso evita FP1»*; esto sí.
- `SPEC.md` §7.2, contexto persistente: *«un billete consumido en una historia abandonada **vuelve a
  estar disponible** en la rama que prevalece»* (`fixture_reorg_libera_billete`). **Reusar un billete
  tras un reorg es legítimo y parece una equivocación.** Tu definición de E tiene que excluirlo.

### 0.3 · La decisión de colateral que ya está tomada

**El colateral son las recompensas propias retenidas, no moneda comprada.** Dos razones, y las dos
son de Katana:
- Su valor del 2026-09-21 (`P-ZRX/P-RNG/PROMPT.md` §2.1): *«nadie posee monedas que no haya minado.
  Cualquier mecanismo que obligue a **comprar** moneda para empezar a producir queda **excluido**.
  Matiz: una fianza tomada de **recompensas ya ganadas** (no compradas) no viola este valor.»*
- Por eso mismo **este paquete no choca con `AGENTS.md`** (*«No hay staking ni comités»*): la
  candidata de 2026-09-21 ya lo razonó — *«No se exige comprar monedas, por lo que no es staking»*
  (`P-ZRX/T-ZRX/SOLUCION-CANDIDATA-REUTILIZACION.md` §4).

**Precedente verificado:** Filecoin — *«fault fees are slashed first from the soonest-to-vest
unvested block rewards»*.

## 1 · LA PREGUNTA CENTRAL

> **Diseñar E, A, R y C para ZEROX de modo que la equivocación demostrable se castigue con las
> recompensas retenidas del infractor, sin castigar los accidentes honestos, y decir con números qué
> disuade y qué no.**

## 2 · LO QUE ESTÁ FUERA, Y POR QUÉ — no lo reabras

| Fuera | Por qué |
|---|---|
| **La rama privada (`κ = 0`)** | **Demostrado:** sin las dos firmas publicadas no hay evidencia, y *«un castigo infinito aplicado con probabilidad cero disuade cero»* (`P-CLAVE` F6; R-6 del libro de restricciones). **No intentes cubrirla.** Di en el informe qué fracción del doble farmeo queda fuera por esto |
| **La finalidad por votos con stake** (tipo Casper) | **Es `PROMPT-2`**, que se ejecuta después de ti. Choca con la prohibición de **comités** de `AGENTS.md`, que Katana **no** ha revocado (`MAPA.md` §3) |
| **Moneda comprada como colateral** | Excluida por el valor de Katana. **Sí puedes cuantificar** cuánto cerraría, como información para él, **sin proponerla** |
| **Registro de parcelas y maduración** | Refutado: **ningún compromiso puede fechar nada** (`P-COBERTURA` Cor. 4). La candidata de 2026-09-21 los incluía; **esa parte no se revive** |
| **Código en `crates/`** | Hay otro encargo trabajando allí. Y **confiscar coinbases exige el estado UTXO con datos de deshacer** (`TAREAS.md` §2.6), que no existe en la ruta activa. **Este encargo termina en el borrador de reglas** |

## 3 · ENTRADAS CONGELADAS: no se re-miden

- **`κ` por tamaño del atacante** (`P-EQUIVOCACION` §1.2): flujo común `m ≤ 0,05` → **1,000**;
  `m = 1` → **0,455**; `m = 4` → **0,000**; flujo divergente → **0,000**. **El atacante grande no deja
  evidencia ni publicando**: usa soluciones distintas en cada rama.
- **`P-CLAVE`**: el **67,5 %** del espacio vive en claves con saldo < 0,01 (hipótesis H3 de tamaños);
  la clave nueva empieza con **saldo cero**; rotar de clave con `T_v = 3 600` y `T_rot = 360` cuesta
  **×11 en ploteo** y **cero en saldo**.
- **Ethereum** (verificado en `MAPA.md` §1.2): salida forzada de **36 días**; la penalización crece
  con el total castigado en esa ventana; tres faltas; **ningún castigo por no proponer**.
- **Filecoin** (verificado en `MAPA.md` §1.1): recompensas en vesting como colateral; las faltas de
  consenso **las denuncian otros mineros**, y el denunciante **cobra una parte**.

## 4 · LO QUE HAY QUE HACER

### 4.1 · E — Qué cuenta como evidencia, y qué no

- Parte del objeto de `DEFINICION-PROPUESTA.md` §4. **Verifícalo, no lo copies**: que sea
  autocontenido, que no se pueda fabricar contra un honesto, y su tamaño real.
- **Excluye explícitamente los casos honestos**, empezando por el billete liberado tras un reorg
  (§7.2). Recorre `FALSOS-POSITIVOS.md` caso por caso y di, para cada uno: ¿lo excluye la definición,
  lo evita el firmante seguro, o lo absorbe la correlación (4.4)?
- **Segunda falta candidata, y puede no sobrevivir:** firmar un bloque **inválido**. `C-POT-06` ya
  separa `Inválido` de `Pendiente`. Decide si un bloque inválido firmado es **atribuible a malicia**
  sin castigar fallos de software. Si no lo es, **descártala y di por qué**: es un resultado válido.
- **Preservación de la prueba:** si una de las dos cabeceras está en una rama abandonada o podada,
  ¿quién la guarda y durante cuánto? `DEFINICION-PROPUESTA.md` §4 trata el plazo tras la poda.

### 4.2 · A — A quién se castiga

- **Supón `C-POOL-01` adoptada** (la coinbase va a la clave que firma) y diseña sobre ella.
- **Después cuantifica qué se rompe si Katana NO la adopta.** Esa cifra es lo que él necesita para
  decidir D1 de `P-POOLS`.
- **La rotación de claves:** con colateral de recompensas propias, una clave nueva tiene **cero** en
  juego (`P-CLAVE` F4). **No puedes cerrarlo sin moneda comprada o registro**; cuantifica **cuánto
  deja abierto**.

### 4.3 · R — Cuánto tiempo queda retenido lo ganado

- Diseña la retención sobre `COINBASE_MATURITY`. La pregunta: **¿3,33 h es ≥ la ventana de
  detección?** Detección = que las dos cabeceras lleguen a alguien dispuesto a denunciar, más la
  inclusión de la denuncia en un bloque. Da la ventana como **función** de `Δ` y del retardo de
  denuncia, **no como número**.
- **El acoplamiento que no puedes ignorar:** `MAX_REORG_LENGTH = COINBASE_MATURITY − 1`. Si
  alargas la retención tocando la madurez, **mueves la profundidad máxima de reorganización**. Di si
  la retención debe ser un parámetro **separado** de la madurez, y qué cuesta cada opción.
- **El castigo frente a un reorg:** si la denuncia va en un bloque que queda en la rama abandonada,
  el castigo **tiene que deshacerse**, porque la regla de contexto persistente (§7.2) retira íntegros
  los efectos de la rama perdedora. Especifícalo.
- **El precio para el honesto:** retener recompensas más tiempo es liquidez que el granjero honesto
  no tiene. Cuantifícalo: es el mismo producto que en `P-CLAVE` F5 cobraba al honesto.

### 4.4 · C — La correlación: la pieza que nadie ha examinado

- **Diseña la curva:** castigo en función de cuántas claves (o cuánta fracción del espacio estimado)
  cometen la falta en la misma ventana. Parte del mecanismo de Ethereum (`MAPA.md` §1.2) y **di qué
  se traslada y qué no**: allí el conjunto de validadores es conocido; **aquí las identidades son
  gratis y el total en juego no se conoce**.
- **Mide la separación.** Con el catálogo de `FALSOS-POSITIVOS.md`, estima la tasa de firmas dobles
  honestas **con y sin** firmante seguro; y la de un ataque coordinado. **La curva sirve si separa
  las dos distribuciones.** Si no las separa, dilo en la primera línea.
- **El ataque a la correlación:** un atacante puede **trocear** su ataque en el tiempo para quedarse
  siempre en la zona de castigo mínimo, o **provocar** firmas dobles ajenas para subir la correlación
  y hacer que el castigo recaiga en honestos. **Examina los dos.**

### 4.5 · La denuncia

- Quién puede denunciar, cómo se incluye la prueba, y **qué parte de lo confiscado cobra el
  denunciante** (entrada, no número).
- **Que la denuncia no sea un arma:** no puede servir para castigar a un honesto, ni para
  **censurar** denuncias ajenas, ni para que el infractor se **auto-denuncie** y recupere parte de lo
  suyo como denunciante.

### 4.6 · Qué disuade de verdad

El balance esperado del infractor **por tipo de atacante**: pequeño/grande (`m`), con clave
establecida/nueva, con flujo común/divergente, publicado/privado. Para cada uno: **ganancia
esperada frente a confiscación esperada** (`κ × retenido`). **La tabla que Katana necesita es ésta:**
a quién disuade el paquete, a quién no, y por qué.

## 5 · LAS PREGUNTAS

**F1** · ¿**Separa la correlación** los accidentes honestos del ataque coordinado? **Primera línea
del informe.** Si no los separa, el paquete castiga honestos, y eso va antes que todo lo demás.
**F2** · La definición de **E**: qué es evidencia, qué casos honestos excluye y cuáles no. ¿Sobrevive
la segunda falta (bloque inválido firmado)?
**F3** · **A**: el diseño con `C-POOL-01`, y **qué se rompe sin ella**. Cuánto deja abierto la
rotación de claves.
**F4** · **R**: la ventana de detección como función; si la retención va separada de la madurez; el
castigo frente al reorg; el coste de liquidez para el honesto.
**F5** · **La denuncia**: diseño y resistencia a su uso como arma.
**F6** · **La tabla de disuasión** de §4.6.
**F7** · **Veredicto:** qué condiciones quedan diseñadas, cuáles no, y **qué decide Katana**.

## 6 · EL INSTRUMENTO

`P-ZRX/P-STAKE/investigacion-1/veritas/consenso/castigo-v1/`, estructura de LINEO §1 (`CONTRATO.md`,
`MODELO.md`, `METODO.md`, `HIPOTESIS.md`, `PROCEDENCIA.md`, `HUELLAS.sha256`, `BITACORA.md`,
`Project.toml`, `Manifest.toml`, `run.jl`, `src/`, `test/`, `resultados/`).

- **Referencia transparente + kernel rápido**, comparados entre sí.
- **Aritmética exacta** (`Rational{BigInt}` o intervalos) en el balance del infractor y en la curva
  de correlación: son fronteras, y ahí el flotante decide mal.
- **Monte Carlo:** RNG por réplica con semillas **NO consecutivas** —hallazgo de `P-ZRX/P-PUERTA/`—,
  réplicas e IC declarados.
- **`HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md`** obligatorio.
- **Escribe los resultados dentro de la carpeta del instrumento**, nunca en el CWD.
- **El conteo de tests que declares MUST salir de un artefacto que entregues** (`resultados/TESTS.txt`
  o equivalente). Tres de las seis entregas anteriores a `P-ECLIPSE` fallaron en esto.

## 7 · ZONA DE TRABAJO Y HUELLAS

**Escribes SOLO en `P-ZRX/P-STAKE/investigacion-1/`.** No edites ni muevas nada de `SPEC.md`,
`TAREAS.md`, `ci/`, `crates/`, `prototipos/`, `research/`, `veritas/`, `PDF/` ni del resto de
`P-ZRX/`. En `P-ZRX/P-STAKE/` son de solo lectura `PROMPT-1.md`, `PROMPT-2.md` y `MAPA.md`; **no escribas en
`investigacion-2/`**, que es de `PROMPT-2`. Al empezar y al
terminar, desde la raíz:

```bash
LC_ALL=C sha256sum -c P-ZRX/P-STAKE/ENTRADA-1.sha256
git -C /home/katana/zeo/ZEROX status --short
date
```

con las tres salidas en `PROGRESO.md`. **Aviso:** hay otro encargo trabajando en `crates/`, `ci/`,
`Cargo.*` y `P-ZRX/PIEZAS-DE-CODIGO/`; lo que ya aparezca `M` o `??` en tu entrada **no es tuyo**.
**Cita las reglas del SPEC por ID, nunca por número de línea.**

## 8 · LECTURAS (ábrelas ENTERAS)

**Empieza por aquí:** `P-ZRX/P-STAKE/MAPA.md` · `P-ZRX/P-EQUIVOCACION/investigacion/INFORME.md`,
`DEFINICION-PROPUESTA.md` y `FALSOS-POSITIVOS.md` · `P-ZRX/P-CLAVE/investigacion/INFORME.md` ·
`P-ZRX/P-POOLS/investigacion/ARQUITECTURA.md` y `DECISIONES-PENDIENTES.md`.

**Después:** `P-ZRX/P-FIRMANTE/informe/INFORME.md` e `INTEGRACION.md` ·
`P-ZRX/T-ZRX/SOLUCION-CANDIDATA-REUTILIZACION.md` (y `P-ZRX/P-COBERTURA/investigacion/INFORME.md`
para saber qué parte de ella está refutada) · `P-ZRX/T-ZRX/LIBRO-DE-RESTRICCIONES.md` (R-1, R-4,
R-5, R-6, R-9 y R-10 tocan este encargo directamente) · `P-ZRX/T-ZRX/ESTADO-DOBLE-FARMEO.md` ·
`SPEC.md` §7.2 (contexto persistente y billete), §8 (`COINBASE_MATURITY`, `C-EMIT-*`), §12
(`C-FIN-01`, `C-REORG-*`), `C-HDR-03`, `C-HDR-04`, `C-POT-06` · `TAREAS.md` §2.6 y §2.9 ·
`AGENTS.md` · `veritas/LINEO.md`.

**Advertencia de método:** en este repositorio, dos errores del mismo día salieron de leer una línea
citada en vez del documento entero.

## 9 · ENTREGABLES (`P-ZRX/P-STAKE/investigacion-1/`)

- `INFORME.md` — **primera línea = la respuesta a F1.** Después F2-F7.
- `BORRADOR-REGLAS.md` — las reglas redactadas en una familia **provisional `C-PEN-NN`**, marcadas
  **PROPUESTA**. **El nombre de la familia lo decide Katana** (`TAREAS.md` §4.2); verificado libre el
  2026-09-24. **Todos los valores como símbolos.**
- `DECISIONES-PENDIENTES.md` — las bifurcaciones reales para Katana, con el coste de cada rama. Como
  mínimo: **D1 de `P-POOLS`** con la cifra de 4.2, y **retención separada o no de la madurez**.
- `PROGRESO.md` — bitácora con `date`, `uptime` y las comprobaciones de entrada y salida.
- El instrumento, con `HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md`.

## 10 · REGLAS DE VALIDEZ

- **No cites un archivo, una línea ni un artículo sin abrirlo.** Rutas completas desde la raíz.
- **Etiqueta cada afirmación:** `demostrado`, `verificado en fuente`, `medido`, `derivado`,
  `estimado`, `propuesto`, `no determinado`, `no verificado`.
- **«No se ha encontrado» y «no puede existir» son distintas.** Di cuál afirmas, cada vez.
- **No fijes NINGÚN valor:** duración de la retención, ventana y forma de la correlación, parte del
  denunciante, tope de castigo. Son **entradas**. `AGENTS.md`: una regla pendiente no se implementa
  inventando un número.
- **No presentes un encarecimiento como un cierre.** Este paquete **encarece** la equivocación
  publicada; **no cierra** el doble farmeo. Dilo con esas palabras.
- **No ocultes lo que no disuade.** La tabla de §4.6 tiene que tener filas en rojo, y la de la rama
  privada **va a estar en rojo**: eso no es un fallo del encargo, es su resultado.
- **No revoques `AGENTS.md`** ni propongas hacerlo. Analiza y cuantifica; decide Katana.
- Cierra con **«Lo que esta investigación NO resuelve»**.

**Si algo de este encargo te parece equivocado, dilo ANTES de empezar**, en tu primera respuesta y en
`PROGRESO.md`. Después Claude lee tu trabajo cita por cita, y Katana decide.
