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

ADAPTACIÓN DEL BLOQUE ANTERIOR A ESTE ENCARGO: es una **auditoría con reejecución** de dos instrumentos
Julia ya escritos, no un instrumento nuevo. El bloque te aplica entero para todo lo que ejecutes y para
cualquier comprobación propia que escribas. **Máximo 8 hilos**: hay otros encargos corriendo en la misma
máquina y el tope conjunto es 24. Julia en CPU con `./veritas/julia.sh` (o `env -u LD_LIBRARY_PATH
julia`); **nada de Python**. Antes de cada corrida anota la salida de `uptime`: tus resultados numéricos
son deterministas y no dependen de la carga, pero **todo tiempo o benchmark que publiques se etiqueta
«medido con carga ajena»** si la carga supera tus propios hilos.

# ENCARGO P-CRP — Auditar CRP-v0.2 y CRP-v0.3 y dejar escrito qué se puede decir hoy del umbral

## 0 · Por qué existe este encargo

`TAREAS.md` §2.9 (e) punto 15 lo dejó escrito el 2026-09-20:

> **CRP-v0.2 y CRP-v0.3 existen en `deepseek/` y NO están validadas ni migradas.** CRP-v0.2 declara en su
> propia cabecera que «sustituye la evidencia protocolaria de CRP-v0.1» (baseline idealizado útil;
> veredicto protocolario inconcluso), y CRP-v0.3 se deriva de CRP-v0.2, «que no se cierra». §2.1 y
> `SPEC.md` §17 citan CRP-v0.1. Hasta que alguien valide v0.2/v0.3 o declare por qué no aplican, hay una
> versión posterior de la evidencia central de §2.1 sin revisar.

Desde entonces ha pasado algo peor que no revisarlas: **el «`α = 1/2`, igual que Bitcoin» de CRP-v0.1 se
ha usado como titular** en una sesión entera de diseño (2026-09-21) sobre el segundo VDF, el sembrador y
la reutilización del espacio entre ramas, y es el **baseline** sobre el que se va a construir el modelo
del espacio prestado (`P-ZRX/P-PRESTAMO/`). El encargo que dio origen a CRP-v0.2 enumera **diez defectos
de CRP-v0.1** (D1–D10) —su «DAG» era una cadena; su DP de granularidad perdía casi toda la masa; empatar
no es superar; `λ ∝ SR` era un supuesto; multistream era una identidad tautológica; «ataque gratis»
estaba sobre-enunciado— y **prohíbe** decir «en la liga de PoW» o «seguro al 50 %» mientras quede una
hipótesis pendiente. **Nadie ha comprobado si v0.2 y v0.3 arreglaron de verdad esos diez defectos.**

`deepseek/` se ha eliminado. Lo único de allí está en `P-ZRX/rescate-deepseek/` (lee su `LEEME.md`).

**Tu trabajo: auditar, reejecutar y dejar un documento que diga, frase por frase, qué puede afirmarse
hoy del umbral de una rama privada y con qué palabras.** No mejoras los instrumentos ni escribes una
v0.4: si encuentras un defecto, lo documentas con su entrada mínima reproducible.

## 1 · Entradas (todas de SOLO LECTURA; sus huellas están en `ENTRADA.sha256`)

- `P-ZRX/rescate-deepseek/encargos/ENCARGO-07v2-coste-rama-privada.md` — el encargo (648 líneas). **Es tu
  vara de medir**: §2 los diez defectos, §3 el modelo mínimo, §4 referencias, §5 criterios de aceptación
  y prohibiciones, §7 las preguntas que el informe debía contestar literalmente.
- `P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/` (45 ficheros) y
  `…/coste-rama-privada-v3/` (46). Cada uno trae `INFORME.md`, `MODELO.md`, `CONTRATO.md`, `METODO.md`,
  `MATRIZ-AUTORIDAD.md`, `MATRIZ-VALIDEZ.md`, `PROCEDENCIA.md`, `PROGRESO.md`,
  `HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md`, tres dictámenes internos (`REVISION-MATEMATICA.md`,
  `REVISION-RUST.md`, `REVISION-JULIA.md`) y `REVISION-RESPUESTA.md`.
- `veritas/seguridad/coste-rama-privada-v1/` — CRP-v0.1, el migrado.
- `veritas/consenso/ghostdag-rank-v1/` — GDR-v0.2, el oráculo de GHOSTDAG que v0.2 y v0.3 reutilizan.

**Aviso práctico, para que no pierdas una hora:** los instrumentos **no arrancan desde donde están
rescatados**. `src/gdr_wrapper.jl` carga GDR con
`joinpath(@__DIR__, "..", "..", "..", "..", "..", "veritas", "consenso", "ghostdag-rank-v1", …)`, que
resolvía a la raíz del repositorio desde `deepseek/veritas/seguridad/…` y ya no. **Copia** v2 y v3 a tu
zona (`cp -a`) y, **solo en tu copia**, sustituye esa ruta por la absoluta del repositorio. Es la **única
modificación permitida**: guarda el `diff` en `PROGRESO.md`. Comprueba además que GDR-v0.2 no ha cambiado
desde el 2026-09-18 (`git log -- veritas/consenso/ghostdag-rank-v1/` y sus `HUELLAS.sha256`); si cambió,
dilo antes de seguir, porque entonces no estás reejecutando lo mismo.

## 2 · Qué hay que comprobar

### 2.1 Reproducibilidad

Tests (`--check-bounds=yes`), `run.jl --seed 0x5a5a --replicas 24` y los comandos de cada `METODO.md`.
Compara tu salida con cada fichero de `resultados/` **ignorando solo fecha, ruta y entorno**. Una cifra
que no reproduzcas es un hallazgo, no una molestia. Comprueba el determinismo con 1, 2, 4 y 8 hilos.

### 2.2 Los diez defectos de CRP-v0.1, uno a uno

**Otro encargo, `P-ZRX/P-CRP1/`, comprueba si esos diez defectos son REALES en el código de CRP-v0.1 y
cuánto mueven sus cifras.** Si `P-ZRX/P-CRP1/auditoria/INFORME.md` existe cuando empieces, léelo: un
defecto que resultó no ser real no hay que «corregirlo». Si no existe, no lo esperes: tu pregunta es otra
—si v0.2 y v0.3 hacen lo que el encargo 07v2 les exigía— y se contesta igual.

Para cada `D1…D10` del encargo §2: qué exigía la «corrección obligatoria», **dónde está en el código**
de v0.2 y de v0.3 (fichero y función), qué test la ejercita, y tu veredicto: **corregido / corregido a
medias / no corregido / no aplicable**, con la evidencia. En particular:

- **D1**: ¿la simulación produce de verdad puntas, anticonos y `rojo_k`, o sigue siendo una cadena? Mira
  la razón azules/total en las trazas, no la descripción.
- **D2**: ¿la DP **conserva masa**? Compruébalo tú sumando; el informe publica `[P_L, P_U]` con error
  ≤ `1e-12`: verifícalo.
- **D3**: `P(empate) = (q/p)^d` frente a `P(superar) = (q/p)^(d+1)`: ¿qué evento usa cada tabla?
- **D7**: ¿hay algún test que **compare una fórmula consigo misma**? Es el defecto original de v0.1 y ha
  reaparecido en otro instrumento de este repositorio el 2026-09-21. Búscalo expresamente en todos los
  tests de v0.2 y v0.3: cada control debe comparar la simulación con algo que no salga de ella.
- **D10**: ¿el coste está desglosado como pedía, o sigue habiendo un «gratis»?

### 2.3 Los quince hallazgos de las revisiones internas

`REVISION-RESPUESTA.md` de v0.3 afirma haber corregido quince hallazgos (H1–H8 matemática, H1/H3 Julia,
H1–H6 Rust). **Comprueba cada corrección en el código y en el resultado que cita**, no en la tabla. Dos
que merecen atención: el atajo por `flujo_id` que relajaba R-FIN-5 (H6) y «`η_a = 1.0` tautológico» (H7).

### 2.4 Lo que ha cambiado en el SPEC desde que se escribieron (2026-09-18)

v0.2 y v0.3 tratan **R-FIN-5 como «candidata»** y dan el umbral por inconcluso, entre otras cosas, por
eso. **Desde el 2026-09-19/20 Katana decidió la validez absoluta y el pasado consistente de flujo, y
están redactados en `SPEC.md` §7.1 como `C-FLU-13` y `C-FLU-14`** (junto a `C-FLU-01`, perfil 1a;
`C-FLU-20/21/22`; `C-FIN-01`). Contesta con precisión:

- ¿El filtro que implementa `src/flujo.jl` de v0.3 (comparar prefijos en `slot(X)`, identidad de objeto
  más autenticación mutua) **es fiel al texto de `C-FLU-14`**? Dónde coincide y dónde no.
- ¿Qué filas de `MATRIZ-AUTORIDAD.md` y `MATRIZ-VALIDEZ.md` cambiarían de «candidata» o «pendiente» a
  «SPEC vigente» con el SPEC de hoy, y cuáles siguen igual? **No las edites: entrega la tabla de cambios.**
- ¿Alguna conclusión de v0.3 **cambia** con `C-FLU-13/14` escritas? ¿O solo cambia su etiqueta?

### 2.5 Trampas que este repositorio ya ha pisado

Semillas: **semillas consecutivas de `StableRNG` sesgan el Monte Carlo** (hallazgo de
`P-ZRX/P-PUERTA/`); mira cómo se derivan las de réplica. Celdas `0/n` presentadas como frontera. Cotas de
búsqueda finita presentadas como cotas sobre **todas** las estrategias. «Autenticado» usado para algo
que no es criptografía. Rejillas gruesas de `α` invertidas sin comprobar monotonía.

## 3 · El entregable que importa: `BASELINE.md`

Un documento corto y citable que sustituya al titular «`α = 1/2`». Para cada uno de los **seis
escenarios** que el encargo §1 obliga a separar —baseline analítico; SPEC actualmente escrito; DAG con
red; escenario con filtro de flujo (hoy `C-FLU-14`); contrafactual aditivo; regímenes corto y largo—:

1. **qué está demostrado, qué medido y qué inconcluso**, con la fila de evidencia;
2. **la frase exacta que se puede escribir** en un documento del proyecto, y **la que NO**;
3. **qué regla o medición pendiente** lo cerraría.

Y una sección aparte: **qué frases de `SPEC.md` (§7.1 y §17) y `TAREAS.md` (§2.1) citan CRP-v0.1 y
cómo deberían quedar**, como propuesta de redacción. **No edites `SPEC.md` ni `TAREAS.md`.**

Cierra `BASELINE.md` con lo que necesita el encargo siguiente: **qué puede tomar `P-ZRX/P-PRESTAMO/`
como punto de partida** para modelar `α` propio más `β` prestado —qué identidad de deriva, bajo qué
hipótesis, con qué eficiencias `η_h`/`η_a`— y qué **no** puede dar por sentado.

## 4 · Zona de trabajo y huellas

**Escribes SOLO en `P-ZRX/P-CRP/auditoria/`** (tus copias de v2 y v3 van en `auditoria/copia/`). No
edites ni muevas nada de `SPEC.md`, `TAREAS.md`, `ci/`, `crates/`, `prototipos/`, `research/`,
`veritas/`, `PDF/` ni del resto de `P-ZRX/` —**incluido `P-ZRX/rescate-deepseek/`**—. En `P-ZRX/P-CRP/`
son de solo lectura `PROMPT.md` y `ENTRADA.sha256`. Al empezar y al terminar, desde la raíz:

```bash
LC_ALL=C sha256sum -c P-ZRX/P-CRP/ENTRADA.sha256
git -C /home/katana/zeo/ZEROX status --short
date
```

con las tres salidas en `PROGRESO.md`. `ENTRADA.sha256` cubre este prompt, el encargo 07v2 y **los 91
ficheros rescatados de v2 y v3**: si alguno cambia entre el principio y el final, primera línea del
informe.

## 5 · Entregables (`P-ZRX/P-CRP/auditoria/`)

- `INFORME.md` — **su primera línea es la respuesta**: si CRP-v0.2 y CRP-v0.3 son válidas dentro de su
  alcance, si de verdad sustituyen a CRP-v0.1, y qué se puede afirmar hoy del umbral. Después §2.1–§2.5.
- `BASELINE.md` — §3.
- `DEFECTOS.md` — cada defecto que encuentres: instrumento, fichero y línea, entrada mínima
  reproducible, qué conclusión toca y cuánto.
- `RECOMENDACION-MIGRACION.md` — si v0.3 (o v0.2) merece migrarse a `veritas/seguridad/`, con qué
  correcciones previas y con qué etiqueta. **No migres tú.**
- `PROGRESO.md` — bitácora con `date`, `uptime`, las comprobaciones de entrada y salida, y el `diff` de
  la ruta de GDR.

## 6 · Reglas de validez

- **No cites un archivo, una línea ni un artículo sin abrirlo.** Rutas completas desde la raíz. Las
  rutas `deepseek/…` que aparecen dentro de los instrumentos hoy son `P-ZRX/rescate-deepseek/…`: al
  citar, usa la ruta que existe.
- **Etiqueta cada afirmación:** `demostrado`, `verificado en fuente`, `reproducido` (lo reejecutaste y
  coincide), `medido`, `derivado`, `estimado`, `no determinado`.
- **No fijes** ningún parámetro de consenso. **No valides por autoridad**: que un instrumento tenga
  tres dictámenes internos no lo hace correcto.
- El veredicto del encargo 07v2 §1 sigue en vigor para ti: **no se admite «en la liga de PoW», «solo
  ingeniería», «ataque del 4 %» ni «seguro al 50 %»** mientras quede una hipótesis necesaria pendiente.
- Cierra el informe con **«Lo que esta auditoría NO resuelve»**.

**Si algo de este encargo te parece equivocado, dilo ANTES de empezar**, en tu primera respuesta y en
`PROGRESO.md`. Después Claude lee tu trabajo cita por cita y repite las comprobaciones clave, y Katana
decide.
