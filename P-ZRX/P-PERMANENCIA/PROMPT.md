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

ADAPTACIÓN DEL BLOQUE ANTERIOR A ESTE ENCARGO: es una **comparación de diseño con un modelo cuantitativo
pequeño** (estadística de auditorías y coste de hacer trampa), no una campaña de simulación ni de
medición. **Máximo 4 hilos** (hay otros encargos en la misma máquina; el tope conjunto es 24), corridas de
minutos. Julia en CPU con `./veritas/julia.sh`; **nada de Python** y **no ejecutes benchmarks de Rust**:
las cifras de hardware que necesitas ya están medidas y se te dan abajo como entradas.

# ENCARGO P-PERMANENCIA — Qué prueba de que una parcela existe y sigue ahí aguanta la regeneración

## 0 · Por qué existe este encargo

La solución candidata de ZEROX contra el sembrador, el alquiler corto, el «cobrar y borrar» y el espacio
prestado (**`P-ZRX/P-PERMANENCIA/CANDIDATA.md`**, copia congelada: léela entera, anexo incluido) descansa
en dos afirmaciones sobre una parcela registrada:

1. **que existía entera antes del reto** (pasos 1–2: registro de la raíz y maduración con retos), y
2. **que sigue existiendo** (pasos 4 y 7: la recompensa retenida se libera si responde a auditorías).

`P-ZRX/P-SEMBRADOR/` ya dejó escrito el problema de la primera: **una raíz no demuestra que los bytes
existan** —se puede comprometer una raíz sin haber calculado las hojas—, y **no existe** una prueba
sucinta de que un compromiso abarca la codificación completa de una parcela Autonomys (la «C1» de ese
informe). Ese hueco **bloquea todo el paquete**.

Y el 2026-09-21 `P-ZRX/P-INTENTO/` midió algo que amenaza a la segunda: **regenerar una pieza cuesta
0,8 segundos de un núcleo**. Un granjero podría **borrar la parcela, conservar solo el árbol de
compromisos y regenerar la pieza que le pidan** cada vez que le auditen: liberaría su recompensa retenida
sin almacenar nada. **Una auditoría por muestreo de piezas probablemente no demuestra almacenamiento.**

El validador (Claude) planteó una **hipótesis**, que **tú debes confirmar o refutar**:

> La prueba de permanencia tiene que exigir **lo mismo que exige farmear**: responder **en cada slot sobre
> la parcela entera**, que es justo lo que no se puede regenerar a tiempo. Una forma: **pruebas
> parciales** —soluciones con un umbral más fácil que el de bloque— cuyo **número por periodo estima
> estadísticamente el tamaño real del lote**, como hacen los *pools* de Chia para medir el espacio de sus
> miembros. **Si se sostiene, podría sustituir a la prueba criptográfica de cobertura completa que hoy
> bloquea el paquete** —no criptográfica, sino económicamente—.

**Modelo de amenaza (de Katana, obligatorio):** se asume que un ente con mucha capacidad atacará. «No
compensa» **no es un argumento de seguridad**: para cada esquema entrega el **coste absoluto de hacer
trampa** —núcleos, GPUs o bytes por TiB simulado— además del relativo, y di qué lo vuelve **imposible** y
qué solo **caro**.

## 1 · Entradas medidas (no las vuelvas a medir; úsalas como un punto de una función)

De `P-ZRX/P-INTENTO/investigacion/` (Ryzen 9 9950X3D, `subspace @ f8842d0`, gobernador `powersave`).
**Etiqueta: medido, sin revalidar; parte de las corridas coincidieron con carga ajena.** Son una **cota
superior del coste del atacante** (mejor kernel, GPU o ASIC la bajan): trátalas como el valor nominal de
símbolos que **barres** (al menos ×1, ×1/10 y ×1/100 de coste).

| Símbolo | Qué es | Valor medido |
|---|---|---|
| `t_tabla` | generar la tabla de una pieza, 1 núcleo | 809 ms |
| `r_cpu` | mejor agregado de una CPU de 16 núcleos | 25,03 tablas/s |
| `t_reto` | probar una tabla ya generada contra un reto más | 0,49 µs (1,4 ns en lote) |
| `t_ganador` | camino que solo paga el intento que gana | 23,0 ms |
| `m_tabla` | memoria viva por tabla | 5 MiB |
| GPU | — | **no medida** (la documentación de Autonomys da ≈ 17× el ploteo en CPU: **cifra ajena, nunca medida**; úsala solo como escenario etiquetado) |
| ploteo honesto completo | sector de 1 000 piezas, 32 hilos | 83,6 s (`research/coste-ploteo-medido.md`, histórica) |

De `P-ZRX/P-REVELACION/investigacion/` (**medido, sin revalidar**): la **ventana de adelanto** de un
atacante con reloj más rápido es `≈ L` slots sin segundo VDF (entre 7 175 y 8 030 con `L = 7 200`) y
`(L + I)(1 − 1/ρ)` con él. **Importa aquí**: quien conoce `w` retos futuros puede preparar respuestas
con antelación. `w` es un símbolo; bárrelo de `1` a `10⁵`.

## 2 · Los esquemas a comparar

Como mínimo estos, **con la misma ficha para todos**, y los que encuentres:

- **E1 · Prueba sucinta de cobertura completa** (la «C1» de P-SEMBRADOR): ¿existe para el formato de
  Autonomys (siete tablas por registro, KZG por registro, codificación por sector)? Qué se sabe en la
  literatura, a qué coste de probador y de verificador, y qué cambiaría del formato. Es estado del arte y
  factibilidad, **no** una construcción nueva.
- **E2 · Aperturas aleatorias con plazo** (muestreo de piezas): `c` piezas por auditoría, plazo `D_a`.
- **E3 · Pruebas parciales** (la hipótesis): soluciones con umbral fácil sobre los retos ordinarios.
- **E4 · Sellado secuencial** (estilo PoRep): solo como referencia; P-REVELACION ya midió que el sellado
  tendría que durar del orden de la ventana de adelanto (horas por sector con `F` de horas).
- **E5 · Farmear y nada más**: que la única prueba de permanencia sea seguir ganando bloques. Es la línea
  base: ¿qué varianza tiene para un granjero pequeño, y cuánto tarda en notarse que una parcela ya no está?

**Ficha por esquema:** mecanismo en cinco líneas · **qué demuestra exactamente y qué no** (existencia
previa al reto / permanencia / tamaño) · **estrategia óptima del tramposo** (almacenar una fracción `s` y
regenerar el resto; regenerar todo; preparar respuestas con la ventana `w`) y su **coste absoluto por
TiB simulado**, como función de `(t_tabla, r, w, D_a, c, tamaño del lote)` · coste para el honesto (IOPS,
CPU, y sobre todo **bytes en cadena por lote y periodo**: todos los parciales no caben; estudia muestreo
o agregación, p. ej. comprometer el conjunto y abrir `k` al azar) · **tasa de fallo de un honesto** con
disponibilidad `a < 1` (apagones, red) · qué cambia del formato de parcela y de la solución · madurez
(existe desplegado / en papel / por inventar) · evidencia y qué habría que medir.

## 3 · Las preguntas

**F1 · ¿Cae E2 ante la regeneración?** Con los valores medidos: ¿para qué `(c, D_a)` deja de poder
responder un tramposo que no almacena nada, y cuántos núcleos le cuesta por lote auditado? ¿Es ese
`(c, D_a)` asumible para un granjero doméstico con HDD, y cabe la respuesta en la cadena? Si la respuesta
es «solo con `c` grande y plazo corto», dilo: eso ya es casi E3.

**F2 · ¿Se sostiene E3?** (a) **Estadística:** si los parciales de un lote de `N` piezas en un periodo
siguen una Poisson de media `∝ N`, ¿qué error tiene la estimación del tamaño y cuánto tarda en
distinguirse un lote entero de uno al `s·100 %`, para lotes de 1, 10 y 100 TiB? Da la **tasa de falsos
fallos** de un honesto con disponibilidad `a`. (b) **Trampa con ventana:** quien conoce `w` retos futuros
puede regenerar el lote **una vez por ventana** y preparar todos sus parciales: coste
`≈ N / (r · w)` CPUs **continuas**. Calcúlalo por TiB, con y sin segundo VDF, con CPU medida y con el
escenario GPU. ¿A partir de qué `w` farmear sin almacenar sale más barato que el disco, **en hardware, no
en dinero**? (c) **Atajos:** ¿puede el tramposo responder parciales con menos que la tabla entera?
(`P-ZRX/P-INTENTO/` no encontró atajo en el cono de tablas; podable ≤ 9,2 %.)

**F3 · ¿Puede E3 sustituir a E1?** Para las **dos** afirmaciones por separado: (i) «existía entera antes
del reto» —parciales **durante la maduración** `M`, con retos impredecibles—; (ii) «sigue existiendo».
¿Qué garantía da, **económica con su coste absoluto**, frente a la criptográfica de E1? ¿Qué le falta?
¿Qué le pasa al sembrador con un lote **registrado pero no almacenado**?

**F4 · Interacción con el resto del paquete.** Cuánta recompensa retenida y durante cuánto tiempo
necesita cada esquema para que «borrar» no compense (en periodos de auditoría, no en moneda); y qué le
pide cada uno al **registro** (`PlotBatchId` debe ligar la codificación a la clave y al lote, o los mismos
bytes se re-registran tras un castigo).

**F5 · Recomendación.** Una, marcada como tuya, con lo que cierra, lo que paga y lo que reabre. Si ninguna
aguanta sin expulsar al granjero doméstico, **ese es el resultado y vale lo mismo**.

## 4 · El instrumento

`P-ZRX/P-PERMANENCIA/investigacion/veritas/almacenamiento/permanencia-v1/`, estructura de LINEO §1. Todo
sale de **funciones** de los símbolos del §1 y §2. Referencia exacta para las colas de Poisson y binomial
(`Rational{BigInt}` o aritmética de intervalos) antes de cualquier aproximación normal; **una
aproximación normal en lotes pequeños es justo donde falla**. Si usas Monte Carlo: RNG por réplica, con
semillas **no consecutivas**, e intervalos de confianza.

## 5 · Zona de trabajo y huellas

**Escribes SOLO en `P-ZRX/P-PERMANENCIA/investigacion/`.** No edites ni muevas nada de `SPEC.md`,
`TAREAS.md`, `ci/`, `crates/`, `prototipos/`, `research/`, `veritas/`, `PDF/` ni del resto de `P-ZRX/`.
En `P-ZRX/P-PERMANENCIA/` son de solo lectura `PROMPT.md`, `CANDIDATA.md` y `ENTRADA.sha256`. Al empezar
y al terminar, desde la raíz:

```bash
LC_ALL=C sha256sum -c P-ZRX/P-PERMANENCIA/ENTRADA.sha256
git -C /home/katana/zeo/ZEROX status --short
date
```

con las tres salidas en `PROGRESO.md`.

## 6 · Lecturas (ábrelas antes de citarlas)

`veritas/LINEO.md` entero · `P-ZRX/P-PERMANENCIA/CANDIDATA.md` entero ·
`P-ZRX/P-SEMBRADOR/investigacion/INFORME.md` entero (fichas A, B, C, E y G; qué ve y qué no ve el
verificador) · `P-ZRX/P-INTENTO/investigacion/INFORME.md` (de dónde salen las cifras del §1 y sus
límites) · `P-ZRX/P-REVELACION/investigacion/INFORME.md` §1 (la ventana) · en el código fijado
`PDF/autonomys-subspace/` @ `f8842d0`: `PDF/autonomys-subspace/crates/subspace-farmer-components/src/auditing.rs` (qué lee un
granjero por slot y por sector), `PDF/autonomys-subspace/crates/subspace-farmer-components/src/proving.rs`,
`PDF/autonomys-subspace/crates/subspace-verification/src/lib.rs`,
`PDF/autonomys-subspace/crates/subspace-core-primitives/src/solutions.rs` (rango de solución y su calibración) ·
`research/time-memory-tradeoff.md` y `research/chia-parcelas-comprimidas.md` (vocabulario y trampas; sus
resultados **no se trasladan** sin más a Autonomys) · `research/fuentes/` · `research/README.md`.
**Fuentes externas primarias** —Filecoin (WinningPoSt / WindowPoSt y sellado), Spacemesh (PoST, NIPoST),
el protocolo de *pools* de Chia (parciales)—: **ábrelas**; si no tienes red, **dilo** y marca cada una
«no verificada». **No inventes citas.**

## 7 · Entregables (`P-ZRX/P-PERMANENCIA/investigacion/`)

- `INFORME.md` — **su primera línea es la respuesta**: si las aperturas por muestreo caen ante la
  regeneración; si las pruebas parciales se sostienen; y si pueden sustituir a la prueba de cobertura
  completa, para qué afirmación y con qué garantía. Después las fichas, F1–F5 y la tabla comparativa.
- `DECISIONES-PENDIENTES.md` — las bifurcaciones reales para Katana.
- `PROGRESO.md` — bitácora con `date`, `uptime` y las comprobaciones de entrada y salida.
- El instrumento, con `HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md`.

## 8 · Reglas de validez

- **No cites un archivo, una línea ni un artículo sin abrirlo.** Rutas completas desde la raíz.
- **Etiqueta cada afirmación:** `demostrado`, `verificado en fuente`, `medido` (de qué instrumento y con
  qué alcance), `derivado`, `estimado`, `propuesto`, `no determinado`. **Una cifra de documentación ajena
  no es una medición.**
- **No fijes** ningún parámetro de consenso ni ningún precio: `M`, `D_a`, `c`, el umbral de los parciales,
  el periodo, `ρ_ret`, `T_v` y `w` son entradas. **Ningún resultado es una constante escrita a mano.**
- **No presentes una garantía económica como criptográfica**, ni una mitigación con palabras de cobertura.
- La hipótesis del §0 es del validador: **no la confirmes por deferencia**.
- Cierra con **«Lo que esta investigación NO resuelve»**.

**Si algo de este encargo te parece equivocado —en particular la hipótesis del §0 o el modelo de trampa
con ventana del F2— dilo ANTES de empezar**, en tu primera respuesta y en `PROGRESO.md`. Después Claude
lee tu trabajo cita por cita y repite las comprobaciones clave, y Katana decide.
