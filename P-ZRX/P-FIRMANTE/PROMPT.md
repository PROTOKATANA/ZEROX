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

ADAPTACIÓN DEL BLOQUE ANTERIOR A ESTE ENCARGO: **este encargo es de CÓDIGO RUST, no de cálculo Julia.**
El bloque anterior te aplica en su **espíritu** —referencia clara antes que kernel rápido, tests de
bordes y contraejemplos, medir en vez de suponer, distinguir lo demostrado de lo estimado— pero el
lenguaje es **Rust**, con la toolchain del repositorio. **No escribas Julia ni Python aquí.** Si mides
tiempos, anota `uptime` antes. Responde en español.

# ENCARGO P-FIRMANTE — El firmante seguro: que un productor honesto no pueda firmar dos veces la misma oportunidad

## 0 · Por qué existe este encargo

Un granjero honesto puede producir **dos bloques contradictorios sin mala fe**: con dos nodos o
*harvesters* redundantes sobre la misma parcela y vistas distintas de las puntas, o reiniciando tras
perder el estado. Hoy eso le hace **perder trabajo** —solo una copia cobra, `SPEC.md` §7.2— y mañana,
con cualquiera de las reglas económicas que ZEROX estudia, le haría **perder recompensa retenida**.

`P-ZRX/P-FIRMANTE/ESPECIFICACION.md` (copia congelada de
`P-ZRX/P-EQUIVOCACION/investigacion/FALSOS-POSITIVOS.md`, ya validado) trae **la especificación
completa**: el catálogo de conductas honestas que producen esa evidencia y, en su §3, la regla del
firmante seguro con su plazo de abstención derivado. **Léela entera antes de escribir una línea.**

**Lo que la hace valiosa ahora:** es **local**, **no toca el consenso**, **no exige decidir nada antes**
y sirve igual con cualquiera de las reglas económicas que se acaben adoptando. Es lo único del paquete
que se puede construir hoy.

**Lo que NO es, y el informe lo dice expresamente:** un mecanismo de seguridad. *«El firmante seguro es
un filtro de accidentes honestos, no un mecanismo de seguridad.»* Quien quiera doble-firmar borra el
registro o usa otro binario. **No lo presentes como prevención en ningún sitio.**

## 1 · Qué hay que construir

La regla, de `ESPECIFICACION.md` §3.1, literal:

```text
Antes de emitir el sello de un bloque B:
  1. Calcular su identidad de oportunidad TicketId(B).
  2. Consultar el registro persistente por la clave (TicketId(B), slot(B)).
  3. Si NO hay entrada: escribir (TicketId, slot) -> pre_hash(B) de forma ATÓMICA y DURADERA
     (fsync del fichero o commit de la transacción) y sólo entonces firmar.
  4. Si hay entrada con el MISMO pre_hash: firmar (es el mismo bloque; puede reemitirse).
  5. Si hay entrada con OTRO pre_hash: NO firmar. Descartar el candidato.
```

**El punto 3 es el único que importa y el único que se hace mal por defecto: persistir ANTES de firmar,
no después de publicar.** Un registro en memoria, o un `write` sin `fsync`, **no cumple**: un corte de
energía entre la firma y la escritura reproduce exactamente el accidente que se quiere evitar.

**Pérdida del registro:** abstenerse durante `S_max_slots` es **suficiente y es el plazo exacto**
(derivado en §3.2 de `C-GD-04` y `C-HDR-07`: pasado `S_max` ningún bloque nuevo puede reclamar un slot
anterior). Abstenerse más no compra nada; menos deja ventana.

**La identidad que indexa el registro decide si sirve de algo.** §3.4.5: si se indexa por `pre_hash` o
por `block_hash` **no protege nada**, porque los dos `pre_hash` son distintos por construcción. Tiene
que ser la **identidad de oportunidad**. Hoy la vigente es `C-GD-07`/R-FIN-11
—`(public_key, sector_index, history_size, chunk, slot)`— y hay otras dos candidatas sobre la mesa
(`P-ZRX/P-EQUIVOCACION/investigacion/DEFINICION-PROPUESTA.md` §3; `P-ZRX/P-IDENTIDAD/` midió que **dentro
de una historia las tres particionan igual**). **Diséñalo para que la identidad sea un punto de
extensión**, con la vigente como implementación por defecto: así el trabajo no caduca cuando Katana
decida.

## 2 · Dónde vive el código, y una advertencia

**`crates/` es de SOLO LECTURA para ti.** No edites nada ahí. El código va en
`P-ZRX/P-FIRMANTE/prototipo/`, como un crate propio que **depende por ruta** de los crates del
repositorio (`zx-core` para `pre_hash`, la firma Ed25519 y los tipos; `zx-consensus` si te hace falta).
Fija `CARGO_TARGET_DIR` **dentro de tu zona** y usa `--locked`. **Borra `target/` al terminar**, dejando
anotado su tamaño.

Abre antes, para no reimplementar lo que ya existe: `crates/zx-core/src/digest.rs` (la distinción entre
lo que se firma y lo que identifica al bloque: **léela entera, es exactamente tu problema**),
`crates/zx-core/src/firma.rs`, `crates/zx-consensus/src/bloque_dag.rs`. Si algo que necesitas **no
existe** en `crates/`, dilo en el informe y **defínelo en tu prototipo con una nota**, no lo des por
hecho.

## 3 · Lo que el prototipo tiene que demostrar

Con tests, no con prosa:

1. **El caso 5 se cumple**: con entrada previa y otro `pre_hash`, **no firma**.
2. **El caso 4 se cumple**: reemitir el mismo bloque funciona (si no, un nodo que se reinicia y
   republica queda roto).
3. **Durabilidad real.** Una prueba que **mate el proceso entre la escritura y la firma** y compruebe que
   al reiniciar el registro está. Es el punto 3 y es el que se hace mal: si no lo pruebas, no lo has
   hecho. Describe cómo lo pruebas (proceso hijo, `fsync` y `kill -9`, o el mecanismo que elijas).
4. **La abstención tras perder el registro** dura exactamente `S_max_slots` y no más.
5. **Concurrencia**: dos hilos que intentan firmar la misma oportunidad a la vez; solo uno firma.
   Declara qué pasa con **dos procesos** sobre el mismo fichero (bloqueo, o lo que uses) y **qué NO
   cubre**.
6. **La identidad como punto de extensión** funciona con al menos dos implementaciones distintas.

## 4 · Lo que hay que medir

Con `uptime` anotado antes de cada medición:

- **Coste por bloque**: el `fsync` está en el camino crítico de producir un bloque, y ZEROX apunta a
  **1 bloque/s**. Mide la latencia añadida (mediana y cola) en el disco de la máquina, y di **cuánto
  margen del slot consume**. Si resulta ser significativo, propón la alternativa (escritura agrupada,
  `fdatasync`, un WAL) **con su riesgo**: cualquier cosa que retrase la durabilidad reabre el accidente.
- **Tamaño del registro** por unidad de tiempo y **política de poda**: pasado `S_max` una entrada ya no
  puede colisionar, así que se puede podar. Dilo con el criterio, no con un número inventado.

## 5 · Lo que NO cubre, y tiene que estar escrito en el informe

De `ESPECIFICACION.md` §3.4, sin suavizar: dos máquinas que no comparten el registro; un atacante
decidido; una clave robada o compartida; la pérdida honesta del slot tras un reorg —**el firmante seguro
la causa**, es el precio—; y una identidad mal elegida.

## 6 · Zona de trabajo y huellas

**Escribes SOLO en `P-ZRX/P-FIRMANTE/prototipo/` e `P-ZRX/P-FIRMANTE/informe/`.** No edites ni muevas
nada de `SPEC.md`, `TAREAS.md`, `ci/`, **`crates/`**, `prototipos/`, `research/`, `veritas/`, `PDF/` ni
del resto de `P-ZRX/`. En `P-ZRX/P-FIRMANTE/` son de solo lectura `PROMPT.md`, `ESPECIFICACION.md` y
`ENTRADA.sha256`. Al empezar y al terminar, desde la raíz:

```bash
LC_ALL=C sha256sum -c P-ZRX/P-FIRMANTE/ENTRADA.sha256
git -C /home/katana/zeo/ZEROX status --short
date
```

con las tres salidas en `informe/PROGRESO.md`.

## 7 · Entregables

- `prototipo/` — el crate, con sus tests. Sin `target/`.
- `informe/INFORME.md` — **primera línea = la respuesta**: si el firmante seguro es implementable y a qué
  coste por bloque. Después: qué demuestra cada test, las mediciones del §4, y **la lista del §5 sin
  suavizar**.
- `informe/INTEGRACION.md` — **cómo entraría en `crates/`**: qué crate lo alojaría, qué llamada hay que
  añadir y dónde, qué tipos faltan hoy, y qué tests del repositorio habría que tocar. **Como propuesta:
  no lo integres tú.**
- `informe/PROGRESO.md` — bitácora con `date`, `uptime`, las comprobaciones de entrada y salida, el
  tamaño de `target/` antes de borrarlo y la salida de `rustc -Vv`.

## 8 · Reglas de validez

- **No cites un archivo ni una regla sin abrirla.** Rutas completas desde la raíz.
- **Etiqueta cada afirmación:** `demostrado por test`, `medido` (con máquina y carga), `derivado`,
  `propuesto`, `no determinado`.
- **No presentes el firmante seguro como una defensa de seguridad.** Es un filtro de accidentes.
- **No fijes ningún parámetro de consenso** y **no propongas texto de SPEC**: esto es un requisito de
  producción, no una regla.
- Cierra el informe con **«Lo que este prototipo NO resuelve»**.

**Si algo de este encargo te parece equivocado, dilo ANTES de empezar**, en tu primera respuesta y en
`informe/PROGRESO.md`. Después Claude lee tu trabajo, ejecuta tus tests y Katana decide.
