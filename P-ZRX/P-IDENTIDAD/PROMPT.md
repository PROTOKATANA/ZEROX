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
un **enumerador pequeño y exacto** en Julia sobre DAGs de juguete (el bloque te aplica entero para ese
enumerador). **Máximo 4 hilos**, corridas de minutos. Julia en CPU con `./veritas/julia.sh`; **nada de
Python**. Anota `uptime` antes de cada benchmark.

# ENCARGO P-IDENTIDAD — Qué se rompe si la identidad de billete deja de llevar `chunk`

## 0 · Por qué existe este encargo

`P-ZRX/P-PRESTAMO/investigacion/` (2026-09-21, validado) encontró que **la definición de la identidad de
billete decide si el castigo por doble firma es imprescindible o innecesario**:

- Con la identidad **vigente** `C-GD-07` —`(public_key, sector_index, history_size, chunk, slot)`,
  R-FIN-11—, farmear la misma parcela en dos ramas **aporta peso neto** al atacante: el umbral de deriva
  baja a `(1 − β_d − 2β_x)/2` y **solo un castigo creíble lo sostiene**.
- Con una identidad **sin `chunk` y con `piece_offset`** —la de IDV-01 y la de
  `P-ZRX/T-ZRX/SOLUCION-CANDIDATA-REUTILIZACION.md`—, usar la misma oportunidad en dos ramas **es** la
  infracción: `β_d` **no aporta peso neto** y el umbral se sostiene **sin depender de que el castigo
  funcione**.

Además `P-ZRX/P-EQUIVOCACION/investigacion/` midió que `C-GD-07`, por llevar `chunk`, **deja escapar dos
soluciones distintas de la misma pieza** (su `κ` cae de 1,000 a 0,000 en ese escenario), mientras IDV-01
y la de la candidata dan 1,000.

Es decir: **un cambio de definición podría cerrar por construcción un problema que si no exige construir
un mecanismo económico entero** (evidencia, censura, sobornos, castigo accidental). Por eso es barato y
por eso hay que mirarlo antes que el prototipo.

**Pero nadie ha comprobado qué se rompe al cambiarla**, y `C-GD-07` no es una regla aislada: de la
identidad de billete cuelgan U2, U3″ dinámica, la selección de la copia pagable (P1), el conjunto
consumido que se arrastra por la cadena, el retarget y la emisión. **Ese es tu encargo.**

**El propio SPEC ya lo anticipó.** Al decidir D-F1 quedó escrito (`SPEC.md` §7.1.4, en el bloque
«Decidido por Katana el 2026-09-20»): *«El motivo que más pesa no es criptográfico: es no atar §7.1 a la
identidad del billete (§7.2), que además **puede cambiar** si algún día se adopta un registro de parcelas
contra el sembrador»*. **Ábrelo entero**: ahí mismo se declara el coste de esa decisión —dos billetes
distintos con el mismo `chunk` en el mismo slot y flujo dan la misma entropía— y eso te afecta.

**No decides el cambio.** Entregas el inventario de lo que toca, qué se rompe, qué hay que reescribir y
qué queda sin cerrar, para que Katana decida.

## 1 · Las tres identidades sobre la mesa

| | Campos | Dónde |
|---|---|---|
| **A · vigente** | `(public_key, sector_index, history_size, chunk, slot)` | `SPEC.md` `C-GD-07`, R-FIN-11 |
| **B · IDV-01** | `(dominio económico de red/era, slot, public_key, sector_index, history_size, piece_offset)` | `veritas/consenso/identidad-disponibilidad-v1/CONTRATO-VALIDACION.md` — marcada **«condicionada»** |
| **C · candidata** | `H(dominio, slot, PlotBatchId, sector_index, piece_offset)` | `P-ZRX/T-ZRX/SOLUCION-CANDIDATA-REUTILIZACION.md` — exige registro de parcelas, que **no existe** |

`chunk` es `sol.chunk`, 32 bytes en `[252,284)` de la cabecera; `piece_offset` es `u16` en `[154,156)`
(`SPEC.md` §6.1). **Empieza por entender qué distingue cada campo en la prueba de Autonomys**: qué es una
pieza, qué es un chunk dentro de ella, cuántos chunks ganadores puede haber por pieza y reto, y si dos
soluciones de la misma pieza en el mismo slot son posibles y bajo qué condición. Ábrelo en el código
fijado (`PDF/autonomys-subspace/` @ `f8842d0`), no en prosa:
`PDF/autonomys-subspace/crates/subspace-core-primitives/src/sectors.rs`,
`PDF/autonomys-subspace/crates/subspace-core-primitives/src/solutions.rs`,
`PDF/autonomys-subspace/crates/subspace-verification/src/lib.rs`,
`PDF/autonomys-subspace/shared/ab-proof-of-space/src/chiapos.rs`.

## 2 · Inventario: de qué cuelga la identidad de billete

**Enumera TODO lo que la usa**, abriendo cada sitio. Como mínimo, y busca más:

1. **`C-GD-07` U2** — invalidez de `B` si la identidad está en `padres(B)` o en el pasado estricto.
2. **`C-GD-07` U3″ dinámica** — `rojo_U3` y su exclusión del k-cluster, en el orden de `C-GD-05`.
3. **Unicidad pagable (P1)** y el desempate entre copias (`C-ORD-01`, `C-ORD-02`), `SPEC.md` §7.2.
4. **El conjunto de billetes consumidos** que se arrastra por la cadena seleccionada y se reconstruye en
   reorg (§7.2; el vector `fixture_reorg_libera_billete`). **Lee el párrafo entero**: es contabilidad de
   reorg y no contradice ninguna infracción; una lectura parcial ya produjo una acusación falsa en este
   repositorio.
5. **R-FIN-8′ / R-FIN-13′** — quién cobra y qué conjunto cuenta el retarget.
6. **La entropía de la inyección `C-FLU-12`** — lleva `sol.chunk` del ancla. **Ojo**: `C-FLU-12` usa el
   `chunk` **directamente**, no la identidad de billete. Di si el cambio la toca o no, y si el coste ya
   escrito en §7.1.4 (dos billetes con el mismo `chunk` dan la misma entropía) **cambia de tamaño** con
   cada identidad.
7. **Lo que haya en `crates/`** (`zx-consensus`, `zx-core`) que compute o compare identidades.

Para cada punto: **qué propiedad necesita de la identidad** (unicidad por qué, en qué ámbito), y si esa
propiedad **se conserva, se refuerza o se pierde** con B y con C.

## 3 · Las preguntas

**F1 · Granularidad.** ¿A es **más fina** que B (varios `chunk` por `piece_offset`), o pueden cruzarse?
Si A es más fina, B agrupa soluciones que A separaba: **eso es lo que cierra el doble farmeo** (dos
soluciones de la misma pieza pasan a ser la misma oportunidad) y a la vez **lo que puede romper algo**.
Demuéstralo con la derivación de la prueba PoAS, no por analogía, y comprueba el caso `piece_offset`
igual con `chunk` distinto en el mismo slot: ¿existe?, ¿con qué probabilidad?, ¿lo produce un honesto?

**F2 · U2 y U3″.** Con B o C, ¿sigue siendo cierto que dos bloques honestos independientes **no**
colisionan? Una identidad más gruesa invalida más bloques: **¿cuántos bloques honestos se perderían?**
Enuméralo en DAGs de juguete con GDR-v0.2 (`veritas/consenso/ghostdag-rank-v1/`, oráculo: **no
reimplementes GHOSTDAG**) y da la tasa como función de `λ`, `k` y `Δ`. Es el riesgo más serio del cambio:
si un granjero honesto con dos soluciones de la misma pieza ve invalidado su segundo bloque, el cambio le
cuesta recompensa.

**F3 · Pago y retarget.** Si B agrupa lo que A separaba, **¿se pagan menos bloques?** ¿Cambia la emisión
efectiva o el conjunto que cuenta R-FIN-13′? Cuantifícalo como función, no con un número elegido.

**F4 · El doble farmeo, por construcción.** Demuestra o refuta la afirmación de `P-ZRX/P-PRESTAMO/`: con
B o C, usar la misma oportunidad en dos ramas **no aporta peso neto** porque las dos copias comparten
identidad y P1 solo paga una. **Ojo al alcance:** eso vale dentro de una **historia**; entre **ramas
disjuntas** las dos son válidas y azules cada una en la suya
(`veritas/seguridad/coste-rama-privada-v1/INFORME.md` §6, medido contra GDR). Di **exactamente** qué
cierra el cambio y qué no: si lo que cierra es «no suma al fusionar» pero no «no suma mientras las ramas
están separadas», la conclusión de P-PRESTAMO necesita esa condición escrita.

**F5 · Lo que el cambio NO cierra.** Publicar solo la rama ganadora; la carrera del ancla
(`P-ZRX/P-EQUIVOCACION/` P4/P5); el alquiler exclusivo. Confírmalo o refútalo.

**F6 · Coste de la migración.** Qué reglas hay que reescribir, qué vectores de prueba caducan, qué pasa
con los bloques ya producidos bajo A, y si B se puede adoptar **sin** el registro de parcelas (C sí lo
exige: `PlotBatchId` no existe). Y el bloqueo declarado: **IDV-01 está marcada «condicionada»** — ¿qué
condición, y quién la levanta?

## 4 · El enumerador

`P-ZRX/P-IDENTIDAD/investigacion/veritas/consenso/identidad-billete-v1/`, estructura de LINEO §1.
DAGs de juguete con GDR-v0.2 sin modificar; aritmética entera o `Rational`; para cada DAG y cada una de
las tres identidades: bloques válidos, invalidados por U2, `rojo_U3`, copias pagables y peso total.
**Un test que compara una fórmula consigo misma no es un test**: cada control compara contra el oráculo o
contra una enumeración exhaustiva. Si usas Monte Carlo: RNG por réplica con semillas **no consecutivas**
(las consecutivas de `StableRNG` sesgan el MC, hallazgo de `P-ZRX/P-PUERTA/`), réplicas e IC declarados.

## 5 · Zona de trabajo y huellas

**Escribes SOLO en `P-ZRX/P-IDENTIDAD/investigacion/`.** No edites ni muevas nada de `SPEC.md`,
`TAREAS.md`, `ci/`, `crates/`, `prototipos/`, `research/`, `veritas/`, `PDF/` ni del resto de `P-ZRX/`.
En `P-ZRX/P-IDENTIDAD/` son de solo lectura `PROMPT.md` y `ENTRADA.sha256`. Al empezar y al terminar,
desde la raíz:

```bash
LC_ALL=C sha256sum -c P-ZRX/P-IDENTIDAD/ENTRADA.sha256
git -C /home/katana/zeo/ZEROX status --short
date
```

con las tres salidas en `PROGRESO.md`.

## 6 · Lecturas (ábrelas ENTERAS, no por la línea que otro informe cita)

`veritas/LINEO.md` entero · `SPEC.md` §6.1 (formato de solución), §7.1.4 (`C-FLU-12` y el bloque
«Decidido por Katana el 2026-09-20»), **§7.2 entero** (unicidad pagable, desempate, contexto persistente
y reorg), §11 (`C-GD-05` … `C-GD-11`) · `veritas/consenso/identidad-disponibilidad-v1/` (los cinco
documentos; en especial qué condiciona a IDV-01) · `P-ZRX/P-PRESTAMO/investigacion/INFORME.md` §3.3 y
`DECISIONES-PENDIENTES.md` D1 · `P-ZRX/P-EQUIVOCACION/investigacion/PROPOSICIONES.md` P7 y su
`resultados/kappa-identidad.csv` · `veritas/seguridad/coste-rama-privada-v1/INFORME.md` §6 ·
`P-ZRX/T-ZRX/SOLUCION-CANDIDATA-REUTILIZACION.md` entero · el código fijado del §1 ·
`research/README.md` (todo `research/` es evidencia histórica: **nunca cifras heredables**).

**Advertencia de método, y es la lección del 2026-09-21 en este repositorio:** dos errores el mismo día
salieron de leer una línea citada en vez del documento entero. **No cites un archivo, una línea ni una
regla sin abrir su sección completa.**

## 7 · Entregables (`P-ZRX/P-IDENTIDAD/investigacion/`)

- `INFORME.md` — **su primera línea es la respuesta**: si la identidad se puede cambiar, qué se rompe y
  cuánto cuesta. Después el inventario del §2 y F1–F6.
- `INVENTARIO.md` — una fila por cada regla, vector de prueba o fragmento de código que usa la identidad:
  qué propiedad necesita, si la conserva con B y con C, y qué habría que reescribir.
- `DECISIONES-PENDIENTES.md` — las bifurcaciones reales para Katana, empezando por A / B / C.
- `PROGRESO.md` — bitácora con `date`, `uptime` y las comprobaciones de entrada y salida.
- El enumerador, con `HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md`.

## 8 · Reglas de validez

- **Etiqueta cada afirmación:** `demostrado`, `verificado en fuente`, `enumerado` (con su rejilla),
  `derivado`, `estimado`, `propuesto`, `no determinado`. **Una enumeración finita no es una demostración.**
- **No fijes** ningún parámetro de consenso y **no redactes reglas de SPEC**: propones; el SPEC lo redacta
  Claude y lo decide Katana.
- **No des por buena la conclusión de `P-ZRX/P-PRESTAMO/` por deferencia.** Su F4 es lo que vienes a
  comprobar; un contraejemplo bien construido vale más que una confirmación floja.
- **No presentes una mitigación con palabras de cobertura.**
- Cierra con **«Lo que esta investigación NO resuelve»**.

**Si algo de este encargo te parece equivocado, dilo ANTES de empezar**, en tu primera respuesta y en
`PROGRESO.md`. Después Claude lee tu trabajo cita por cita, y Katana decide.
