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

ADAPTACIÓN DEL BLOQUE ANTERIOR A ESTE ENCARGO: es **análisis de arquitectura y de reglas escritas**, con
lectura de fuentes primarias externas. El bloque anterior te aplica **solo si acabas comprobando algo con
números** —y entonces: Julia con `./veritas/julia.sh`, **máximo 4 hilos**, nada de Python—. Lo que se
entrega es un análisis y una propuesta de arquitectura, no un instrumento. Responde en español.

# ENCARGO P-POOLS — ¿Puede el operador de un pool conseguir bloques para otra rama sin sus granjeros?

## 0 · Por qué existe este encargo

Todo el trabajo del 2026-09-21 sobre **espacio prestado** supuso que el atacante tiene que **reclutar**
granjeros: sobornarlos, y por eso se estudió cuánto hay que retenerles para que no acepten
(`P-ZRX/P-PRESTAMO/investigacion/`).

**Hay una vía más barata que no estaba en el mapa: capturar un pool.** Si el operador de un pool puede
producir bloques con el espacio de sus granjeros sin que estos autoricen cada bloque, entonces **controlar
un servidor equivale a controlar todo ese espacio** — sin sobornar a nadie, sin dejar evidencia de
equivocación en la mayoría de los casos, y de forma instantánea. En la notación de `P-ZRX/P-PRESTAMO/`,
sería `β` conseguido a coste casi nulo.

**Verificado antes de escribir este encargo:** la palabra «pool» aparece en `SPEC.md` **solo** como *pool
blindado* (el conjunto de notas de la capa privada, §5). **El pool de farming no existe en el SPEC, ni
como amenaza ni como arquitectura.** Este encargo es para cerrar ese hueco.

**La defensa tiene precedente real:** Chia separa la distribución de recompensas de la construcción de
bloques —el pool gestiona pagos y recibe pruebas parciales, y el granjero conserva la autoridad de firma
y construye el bloque—. **Ábrelo en su documentación oficial**; si no tienes red, **dilo** y marca esa
parte «no verificada», no la inventes.

**Este encargo no reabre ninguna decisión de Katana** y no depende de ninguna medición pendiente.

## 1 · Lo que hay que establecer, en orden

### 1.1 · Qué necesita exactamente un pool para funcionar

Deriva de las reglas y del código, no de la analogía con Chia: **qué tiene que ver el operador y qué
puede quedarse el granjero.** Como mínimo:

- Qué hace falta para **auditar** una parcela y encontrar una solución
  (`PDF/autonomys-subspace/crates/subspace-farmer-components/src/auditing.rs`, `…/proving.rs`).
- Qué entra en la **cabecera** y qué se firma: `pre_hash` y el sello Ed25519 (`SPEC.md` §6.2,
  `C-HDR-03`/`C-HDR-04`), y qué campos quedan **fuera** de la prefirma (`C-HDR-08`: la coinbase va en el
  cuerpo — **importa mucho aquí**: ¿de quién es la recompensa y quién la decide?).
- Qué hace falta para **elegir padres** (`C-GD-10`) y para validar el contexto (flujo `C-FLU-10/14`,
  rango `C-HDR-06`, justificación PoT `C-HDR-07`).
- Qué clave firma qué: la `public_key` de la identidad de billete (`C-GD-07`/R-FIN-11) **¿es la misma**
  que la que firma el sello? Respóndelo abriendo el código y el SPEC: de ahí depende todo lo demás.

### 1.2 · El modelo de amenaza

Un operador hostil —o un atacante que le ha comprometido el servidor— **que no tiene las claves de sus
granjeros**. Para cada arquitectura posible, contesta: **¿puede producir un bloque válido para una rama
que el granjero no elegiría?** Enumera las arquitecturas realistas, al menos:

1. **Pool custodial**: el granjero le entrega la clave. *(Trivial: el pool es el granjero. Sirve de línea
   base y para medir qué se gana con las demás.)*
2. **Pool que firma**: el granjero envía soluciones y el pool construye y firma con una clave del pool.
3. **Firma ciega**: el granjero firma lo que el pool le manda sin validar el contexto.
4. **Chia-like**: el pool recibe **parciales** y gestiona pagos; el granjero valida el contexto,
   construye el bloque y firma. El pool **no elige el contenido**.

Para cada una: qué puede hacer el operador hostil, qué no, y **qué evidencia queda** si lo hace (cruza
con `P-ZRX/P-EQUIVOCACION/`: ¿la doble firma resultante sería atribuible al granjero o al pool?).

### 1.3 · La pregunta central

**¿Se puede impedir por diseño que la arquitectura (3) sea posible?** Es decir: ¿puede el protocolo hacer
que una firma de **parcial** —la prueba de trabajo que el granjero manda al pool para cobrar— **no valga
nunca** como autorización de un bloque? Opciones que debes examinar:

- separación de dominio en lo que se firma (etiquetas distintas, como ya hace `C-HASH-06` con `H_d`);
- que el `pre_hash` comprometa algo que el pool no pueda fijar sin el granjero;
- que la recompensa esté atada a una clave que el pool no controla.

**Di cuáles son reglas de consenso y cuáles son solo recomendaciones de implementación.** Una
recomendación no impide nada a un operador hostil: **no la presentes como si lo hiciera.**

### 1.4 · Qué NO cierra

Que el propietario **colabore voluntariamente**, entregue sus claves o instale un binario modificado.
Ninguna arquitectura lo evita, y hay que decirlo. Lo que se puede cerrar es que **capturar el servidor
baste**.

## 2 · Y una pregunta que sale de aquí, para el modelo económico

`P-ZRX/P-PRESTAMO/` calculó cuánto hay que retener para que un granjero **no acepte un soborno**. Si el
pool puede prestar el espacio **sin** que el granjero se entere, esa cuenta no aplica: no hay a quién
disuadir, y la recompensa retenida del granjero se confisca por algo que **él no hizo**. Dilo con
claridad y deja escrito qué tendría que cambiar en ese modelo. **No rehagas su trabajo.**

## 3 · Zona de trabajo y huellas

**Escribes SOLO en `P-ZRX/P-POOLS/investigacion/`.** No edites ni muevas nada de `SPEC.md`, `TAREAS.md`,
`ci/`, `crates/`, `prototipos/`, `research/`, `veritas/`, `PDF/` ni del resto de `P-ZRX/`. En
`P-ZRX/P-POOLS/` son de solo lectura `PROMPT.md` y `ENTRADA.sha256`. Al empezar y al terminar, desde la
raíz:

```bash
LC_ALL=C sha256sum -c P-ZRX/P-POOLS/ENTRADA.sha256
git -C /home/katana/zeo/ZEROX status --short
date
```

con las tres salidas en `PROGRESO.md`.

## 4 · Lecturas (ábrelas ENTERAS, no por la línea que otro informe cita)

`SPEC.md` §5 (firmas y `C-SIG`), **§6.1 y §6.2 enteras** (formato de cabecera, `pre_hash`, sello,
`C-HDR-08`), §7.1 (`C-FLU-10/11/13/14`), §7.2 (unicidad pagable: **quién cobra**), §11 (`C-GD-07`,
`C-GD-10`) · `crates/zx-core/src/digest.rs` y `crates/zx-core/src/firma.rs` · en el código fijado
`PDF/autonomys-subspace/`:
`PDF/autonomys-subspace/crates/subspace-farmer-components/src/auditing.rs`,
`PDF/autonomys-subspace/crates/subspace-farmer-components/src/proving.rs` y
`PDF/autonomys-subspace/crates/subspace-verification/src/lib.rs` ·
`P-ZRX/P-EQUIVOCACION/investigacion/FALSOS-POSITIVOS.md`
(el firmante seguro y qué cubre) y su `DEFINICION-PROPUESTA.md` ·
`P-ZRX/P-PRESTAMO/investigacion/INFORME.md` §3 (el juego del granjero) ·
`P-ZRX/T-ZRX/AGUJEROS-Y-SOLUCIONES.md` (mapa general) · `research/README.md`.
**Fuentes externas**: la documentación del protocolo de pools de Chia es la principal; **ábrela**, y lo
que no puedas verificar márcalo «no verificada». **No inventes citas.**

**Advertencia de método, lección del 2026-09-21 en este repositorio:** dos errores el mismo día salieron
de leer una línea citada en vez del documento entero. **No cites una regla sin abrir su sección completa.**

## 5 · Entregables (`P-ZRX/P-POOLS/investigacion/`)

- `INFORME.md` — **primera línea = la respuesta**: si un operador hostil puede hoy producir bloques para
  otra rama con el espacio de sus granjeros, y qué arquitectura lo impide. Después §1.1–§1.4 y §2.
- `ARQUITECTURA.md` — la propuesta: qué hace el pool, qué hace el granjero, qué se firma en cada paso y
  **qué regla de consenso haría falta** (si hace falta alguna) para que la firma ciega no sea posible.
  **Como propuesta, no como texto de SPEC.**
- `DECISIONES-PENDIENTES.md` — las bifurcaciones reales para Katana.
- `PROGRESO.md` — bitácora con `date`, `uptime` y las comprobaciones de entrada y salida.

## 6 · Reglas de validez

- **No cites un archivo, una línea ni un artículo sin abrirlo.** Rutas completas desde la raíz.
- **Etiqueta cada afirmación:** `verificado en fuente`, `derivado`, `propuesto`, `no verificada`
  (fuente externa que no pudiste abrir), `no determinado`.
- **Distingue regla de consenso de recomendación de implementación.** Es la distinción que decide si algo
  protege o no contra un operador hostil.
- **No fijes** ningún parámetro de consenso y **no redactes texto de SPEC**.
- **No presentes una mitigación con palabras de cobertura.**
- Cierra con **«Lo que esta investigación NO resuelve»**.

**Si algo de este encargo te parece equivocado, dilo ANTES de empezar**, en tu primera respuesta y en
`PROGRESO.md`. Después Claude lee tu trabajo cita por cita, y Katana decide.
