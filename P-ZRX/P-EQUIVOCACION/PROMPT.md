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

ADAPTACIÓN DEL BLOQUE ANTERIOR A ESTE ENCARGO: es sobre todo **análisis de reglas escritas**, apoyado en
un **enumerador exhaustivo pequeño** en Julia con aritmética entera exacta (el bloque te aplica entero
para ese enumerador). **Máximo 4 hilos** (hay otros encargos en la misma máquina; el tope conjunto es
24), corridas de minutos. Julia en CPU con `./veritas/julia.sh`; **nada de Python**.

# ENCARGO P-EQUIVOCACION — ¿Alcanza la infracción estrecha a todo el doble farmeo que importa, sin castigar a honestos?

## 0 · Por qué existe este encargo

Para que prestar espacio a una rama privada deje de ser gratis, la solución candidata
(**`P-ZRX/P-EQUIVOCACION/CANDIDATA.md`**, copia congelada: léela entera, anexo incluido) castiga **una
sola** conducta, definida estrecha a propósito:

```text
mismo TicketId y slot   +   dos pre_hash diferentes   +   dos firmas válidas
+   ambas cabeceras válidas en su contexto
```

Su autor advierte de que eso «cubre únicamente duplicar la misma oportunidad» y no, por ejemplo, farmear
ramas distintas en slots alternos. El validador (Claude) planteó una **hipótesis en sentido contrario**,
que **tú debes demostrar o refutar**:

> Bajo el perfil 1a (`L_slots ≥ F_slots`, `C-FLU-01`), dentro de la ventana en que una reorganización es
> posible (profundidad `< F ≤ L`) **las anclas de las inyecciones activas son anteriores a la
> bifurcación**, luego las dos ramas comparten flujo y **tienen los mismos retos**. La identidad de la
> oportunidad **no contiene ni los padres ni la rama**. Entonces quien farmea doble **duplica
> necesariamente la misma oportunidad**, y la infracción estrecha lo alcanza. Su única salida es usar
> cada oportunidad ganadora en **una sola** rama, que es repartir su espacio: **exclusividad por
> oportunidad, impuesta económicamente**.

Si la hipótesis es cierta, la infracción estrecha vale mucho más de lo que parece. Si es falsa, hay que
saber **por dónde se escapa** el tramposo y con qué frecuencia. El resultado que necesita el modelo
económico (`P-ZRX/P-PRESTAMO/`) es un número con su región: **`κ`, la fracción del doble farmeo que deja
evidencia castigable.**

Y la otra mitad, igual de importante: **qué conductas HONESTAS producen esa misma evidencia**, porque el
castigo accidental es lo que hunde estos mecanismos en la práctica.

## 1 · Las reglas que mandan (ábrelas; los números de línea son orientativos)

- **Cabecera y sello:** `pre_hash = H_d("ZZKBlkPreHash___", prefirma)` (`C-HDR-03`) y el sello es una
  firma **Ed25519 sobre `pre_hash`** (`C-HDR-04`), `SPEC.md` §6.2. La evidencia compara **`pre_hash`, no
  `block_hash`**: di con precisión **por qué** (¿admite el SPEC más de un sello válido para el mismo
  `pre_hash`?, ¿qué campos quedan fuera de la prefirma?, `C-HDR-08`: la coinbase va en el cuerpo).
- **Identidad de billete — hay TRES definiciones sobre la mesa y no coinciden:**
  1. `SPEC.md` `C-GD-07` (R-FIN-11): `(public_key, sector_index, history_size, chunk, slot)`;
  2. IDV-01, «clave económica recomendada, **condicionada**»
     (`veritas/consenso/identidad-disponibilidad-v1/CONTRATO-VALIDACION.md`):
     `(dominio económico de red/era, slot, public_key, sector_index, history_size, piece_offset)`;
  3. la de `CANDIDATA.md`: `H(dominio, slot, PlotBatchId, sector_index, piece_offset)`.
  **Reconcílialas**: qué distingue cada una, cuál hace la evidencia **objetiva entre ramas**, y qué pasa
  con cada una **entre flujos distintos** (mismo slot y misma pieza, **reto distinto**).
- **Flujo y ancla:** `C-FLU-01` (perfil 1a), `C-FLU-04` (el ancla se define sobre la vista restringida
  `V_j(B)`), `C-FLU-07` (`t_j = slot(I_j) + L`), `C-FLU-13/14` (validez absoluta; un bloque no referencia
  bloques de otro flujo), `C-FLU-20/21` (la inyección activada se hereda; el productor evita las puntas
  que la cambiarían), `C-FLU-22` (adopción del flujo rival con presupuesto), `SPEC.md` §7.1. **Ojo con
  esta frase del propio SPEC: «Antes de `t_j` no hay regla: hay carrera»** — `V_j(B)` crece sin
  reorganización cuando un bloque fusiona un bloque retenido del corte. Es por donde la hipótesis puede
  romperse.
- **Finalidad:** `C-FIN-01` (no se reorganiza por debajo de `F_slots`; se mide en slots), §12.
- **Bloques tardíos:** `S_max_slots = 150`; un bloque publicado más de `S_max` después de su slot es
  inválido. **Importa para los falsos positivos**: ¿puede un nodo honesto, tras cambiar de rama, producir
  un bloque para un slot **pasado** que ya firmó en la otra?
- **Copias:** `C-GD-07` U2/U3″ y la regla de copias de §7.2 (tras un reorg el billete de la historia
  abandonada «vuelve a estar disponible»). **Hoy el doble uso entre ramas NO es fraude**: tu propuesta
  tiene que decir qué texto del SPEC cambiaría, **sin redactarlo como SPEC**.

## 2 · Parte A — ¿Cuánto doble farmeo deja evidencia? (`κ`)

1. **Formaliza la hipótesis** como proposición con sus premisas, y **demuéstrala o da el contraejemplo**.
   Define «rama privada útil»: bifurca en el slot `s₀`, se publica antes de profundidad `F_slots`. Para
   cada inyección activa en `[s₀, s₀ + F]`, ¿dónde está su ancla respecto de `s₀`? ¿Bajo qué condición
   exacta sobre `(L, F, I, S_max, W_dec)` las dos ramas comparten flujo durante **toda** la ventana?
2. **El escape por el ancla.** Un atacante que **prepara con antelación** una divergencia de ancla
   (reteniendo bloques alrededor del slot `t_j − L`; es la vía «A2» de `P-ZRX/P-FLUJO/`, probabilística y
   no medida) consigue retos distintos en su rama. Entonces la misma pieza ya no gana en las dos, o gana
   con retos distintos: ¿sigue habiendo evidencia? Depende de la definición de identidad (§1). ¿Con qué
   antelación tiene que prepararlo, y no es ese ya el caso de **partición de flujo**, que `C-FLU-14` y
   `C-FIN-01` tratan por otra vía? Delimita con precisión dónde acaba un caso y empieza el otro.
3. **Las otras fugas** que `CANDIDATA.md` lista: slots alternos, soluciones distintas de la misma
   parcela, rama nunca publicada, clave robada o *pool* custodial. Para cada una: ¿es de verdad una fuga
   bajo 1a, o queda reducida a «repartir el espacio», que ya no es doble farmeo?
4. **Enumerador exhaustivo** (Julia, enteros exactos): sobre rejillas pequeñas de
   `(L, F, I, S_max, s₀, profundidad, patrón de retención)` clasifica cada oportunidad ganadora doble
   como **evidencia / sin evidencia** bajo cada una de las tres identidades, y publica
   **`κ(parámetros, identidad)`** como tabla y como región. Es comprobación de la demostración, no su
   sustituto: **si el enumerador y la demostración discrepan, uno de los dos está mal y dices cuál.**

## 3 · Parte B — ¿Qué honestos caerían? (los falsos positivos)

Catálogo **exhaustivo** de conductas sin mala fe que producen `mismo TicketId y slot + dos pre_hash`:

- dos nodos o *harvesters* **redundantes** sobre la misma parcela, con vistas distintas de las puntas
  (con un bloque por segundo en un DAG, ¿con qué frecuencia eligen padres distintos?);
- **reinicio** con pérdida de estado que vuelve a firmar el mismo slot;
- cambio de rama o **adopción del flujo rival** (`C-FLU-22`) seguido de producción para un slot todavía
  dentro de `S_max`;
- retransmisión o reempaquetado del mismo bloque con otro cuerpo (¿cambia el `pre_hash`?: depende de qué
  compromete la prefirma);
- cualquier otra que encuentres leyendo `C-GD-10` (elección de padres) y el productor.

Para cada una: si es posible con las reglas escritas, con qué frecuencia esperable (como función, no como
número inventado), y **qué la evita**. Especifica el **firmante seguro** como requisito de producción:
persistir atómicamente `TicketId → pre_hash` **antes** de firmar y negarse a firmar otro; qué hace si
pierde ese registro (¿abstenerse durante `S_max` slots?); y qué **no** cubre (dos máquinas que no
comparten registro).

## 4 · Parte C — La evidencia como objeto verificable

«Ambas cabeceras válidas en su contexto»: ¿qué necesita un nodo para comprobarlo? Con validez absoluta
(`C-FLU-13`) la validez de `B` es función de `past(B)`: **un nodo que no tiene esa rama no puede
comprobar su cabecera**. Determina la **evidencia mínima** verificable por un nodo que solo tiene la
historia ganadora —¿bastan firma, solución PoAS y reto del slot?, ¿solo si las dos ramas comparten
flujo?— con su tamaño en bytes (de los tamaños de `SPEC.md` §6) y su coste de verificación, y el plazo
en que sigue siendo verificable tras la poda. Di qué impide que alguien **fabrique** una prueba contra un
honesto.

## 5 · Zona de trabajo y huellas

**Escribes SOLO en `P-ZRX/P-EQUIVOCACION/investigacion/`.** Enumerador en
`P-ZRX/P-EQUIVOCACION/investigacion/veritas/consenso/equivocacion-v1/`, con la estructura de LINEO §1.
No edites ni muevas nada de `SPEC.md`, `TAREAS.md`, `ci/`, `crates/`, `prototipos/`, `research/`,
`veritas/`, `PDF/` ni del resto de `P-ZRX/`. En `P-ZRX/P-EQUIVOCACION/` son de solo lectura `PROMPT.md`,
`CANDIDATA.md` y `ENTRADA.sha256`. Al empezar y al terminar, desde la raíz:

```bash
LC_ALL=C sha256sum -c P-ZRX/P-EQUIVOCACION/ENTRADA.sha256
git -C /home/katana/zeo/ZEROX status --short
date
```

con las tres salidas en `PROGRESO.md`.

## 6 · Lecturas (ábrelas antes de citarlas)

`veritas/LINEO.md` entero · `P-ZRX/P-EQUIVOCACION/CANDIDATA.md` entero · `SPEC.md` §6.1–§6.2, §7.1, §7.2,
§11 (`C-GD-05…C-GD-11`) y §12 · `veritas/consenso/identidad-disponibilidad-v1/` (los cinco documentos) ·
`veritas/consenso/regla-flujo-v1/PROPUESTA-SPEC.md` (la demostración de buena fundamentación del ancla y
el caso «A2») · `P-ZRX/P-2.1/SINTESIS.md` §7–§8 (qué se decidió y por qué) ·
`veritas/seguridad/coste-rama-privada-v1/INFORME.md` §6 (U2/U3″ entre ramas disjuntas, medido contra
GDR-v0.2) · `research/README.md`. Precedentes externos (penalización de SpaceMint por la misma prueba en
dos bloques; protección contra doble firma en validadores PoS): solo fuentes primarias que **abras**; lo
que no puedas verificar se marca «no verificada».

## 7 · Entregables (`P-ZRX/P-EQUIVOCACION/investigacion/`)

- `INFORME.md` — **su primera línea es la respuesta**: si la hipótesis del validador es verdadera, falsa
  o verdadera bajo qué condición; cuánto vale `κ`; y si la infracción estrecha se puede definir sin
  castigar a honestos.
- `PROPOSICIONES.md` — cada proposición con premisas, demostración o contraejemplo, y etiqueta.
- `FALSOS-POSITIVOS.md` — el catálogo de la Parte B y la especificación del firmante seguro.
- `DEFINICION-PROPUESTA.md` — la infracción, la identidad de oportunidad recomendada y la evidencia
  mínima, **como propuesta, no como SPEC**; qué reglas vigentes tocaría.
- `DECISIONES-PENDIENTES.md`, `PROGRESO.md` (con `date`, `uptime` y las comprobaciones), y el enumerador
  con `HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md`.

## 8 · Reglas de validez

- **No cites un archivo, una línea ni un artículo sin abrirlo.** Rutas completas desde la raíz. **No
  inventes citas.** Los números de línea del SPEC se mueven: cita por **identificador de regla**.
- **Etiqueta cada afirmación:** `demostrado`, `verificado en fuente`, `medido`/`enumerado` (con su
  rejilla), `derivado`, `propuesto`, `no determinado`. **Una enumeración finita no es una demostración**:
  dilo cuando una proposición solo esté comprobada en rejilla.
- **No fijes** ningún parámetro de consenso: `L`, `F`, `I`, `S_max`, `W_dec`, `D` son entradas.
- **No redactes reglas de SPEC.** Propones; el SPEC lo redacta Claude y lo decide Katana.
- La hipótesis del §0 es del validador: **no la confirmes por deferencia**. Un contraejemplo bien
  construido vale más que una confirmación floja.
- Cierra con **«Lo que esta investigación NO resuelve»**.

**Si algo de este encargo te parece equivocado, dilo ANTES de empezar**, en tu primera respuesta y en
`PROGRESO.md`. Después Claude lee tu trabajo cita por cita, y Katana decide.
