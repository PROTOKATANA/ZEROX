# PROCEDENCIA — PPP-v0.1

Instrumento ejecutado por **DeepSeek** en la zona aislada `deepseek/`, según
`ENCARGO-05-poda-post.md` (diseñado por Claude bajo decisión de Katana del 2026-09-17).
**Validado por Claude reejecutando** —no leyendo los `resultados/` del ejecutor— y migrado a
`veritas/consenso/poda-post-v1/` el 2026-09-17.

## 1 · Qué reejecutó Claude, y con qué resultado

| Comprobación | Comando | Resultado |
|---|---|---|
| Suite completa | `./veritas/julia.sh --project=… --check-bounds=yes test/runtests.jl` | **85/85** ✓ |
| Huellas | `sha256sum -c HUELLAS.sha256` **desde la raíz del repo** | **51 archivos, exit 0** ✓ |
| `blue_work` contra GDR-v0.2 | `run.jl --bluework` | **reproducido byte a byte** ✓ |
| Independencia nivel↔padres (D4) | `run.jl --anclaje` | **0 discrepancias** ✓ |
| Certificado de rama privada (D5) | `run.jl --certificado` | **aceptado por el verificador de niveles** ✓ |
| Frontera de la zona aislada | `git status --short` | **idéntico al inicial**; nada fuera de `deepseek/` ✓ |

**Las huellas se verifican desde la raíz del repositorio**, no desde el directorio del instrumento:
`HUELLAS.sha256` incluye rutas de fuentes leídas (`crates/…`, `PDF/…`) además de los artefactos
propios. Ejecutarlo desde dentro del instrumento da 51 «could not be read» y es un falso negativo.

### 1.1 · Dos huellas que ya no coinciden, a propósito

Tras registrar el resultado de esta auditoría, `sha256sum -c` da **`SPEC.md: FAILED` y
`TAREAS.md: FAILED`**. Es correcto y no se «arregla»:

- la huella registrada es la de la versión que el ejecutor **leyó al empezar** (2026-09-17, tras
  cerrar §2.7 y §2.4 en el SPEC), y eso es justamente lo que un registro de procedencia debe fijar;
- las dos se editaron **después**, y se editaron **con el veredicto de este instrumento**: §17 fila
  «Poda» y TAREAS §2.4. Actualizar la huella borraría la prueba de qué versión se auditó.

Es la misma situación que `veritas/finalidad/delta-medido-v1/METODO.md` §84 documenta para
`TAREAS.md`. Las **once** huellas restantes de fuentes —incluidas `veritas/LINEO.md`,
`research/dag-poas-auditoria.md`, `AGENTS.md`, `MIGRACION.md`, el oráculo GDR-v0.2, las fuentes de
Autonomys y `crates/zx-core/src/preimage/dag.rs`— **sí coinciden**, y son las que sostienen los
veredictos.

## 2 · Reejecución tras el recorte de dependencias

El `Project.toml` que entregó el ejecutor era la plantilla de `veritas/plantilla/` **sin recortar**:
28 dependencias declaradas, de las que el instrumento usa **dos** (`BenchmarkTools`, `StableRNGs`)
más stdlib. Es peso muerto —`Nemo`, `Arblib`, `LoopVectorization`, `Tullio`… para un instrumento de
aritmética entera de `Base`— y contradice LINEO §9 y el precedente de `delta-medido-v1`, donde el
recorte sí se hizo.

Claude recortó el proyecto al migrarlo, declarando explícitamente las stdlib usadas, y **reejecutó
todo**:

- `Manifest.toml`: **54 845 → 8 118 bytes**.
- Suite tras el recorte: **85/85** ✓.
- Los **ocho** archivos de `resultados/run-*.txt` regenerados y comparados con los del ejecutor:
  **idénticos** en su contenido sustantivo (difieren sólo en la ruta del proyecto, la fecha y el
  volcado de `Pkg.status`, que son cabecera de entorno).

Ningún veredicto depende del recorte.

## 3 · Observaciones de la validación

**3.1 · Una cifra mal atribuida, no inflada.** `INFORME.md` §1.2 cita «0 discrepancias en **500
pares**» para D4. El artefacto `resultados/run-anclaje.txt` dice **200**. Ambas son reales: el modo
`run.jl --anclaje` usa el valor por defecto `n=200` (`src/validacion.jl:46`) y la suite usa `n=500`
(`test/runtests.jl:49`), y Claude reejecutó las dos. `DERIVACIONES.md` §D4 lo escribe correctamente
como «200–500 pares». Es imprecisión de trazabilidad, no una cifra sin respaldo; se anota porque
`AGENTS.md` exige que cada cifra identifique su fuente.

**3.2 · El alcance del «no» es más estrecho que el titular, y el informe lo dice.** El teorema D5
cubre **predicados de nivel**: enumera los datos de los que `ℓ(B)` puede depender y muestra que
ninguno cumple a la vez (P1) comprobable sin el DAG, (P2) ligado a recurso y (P3) ligado a la
ancestría. Lo que **no** examina es una vía que no es un nivel: una **prueba recursiva** de la
función de transición del consenso (modelo Mina), que no necesita ligar recurso a historia y por
tanto no cae en ninguno de los cinco casos.

`INFORME.md` acota su veredicto («**NO** para los mecanismos examinados») y `PROPUESTA.md` P3.3
menciona la prueba recursiva, pero como **componente** de un esquema de niveles, no como candidata
independiente.

**El alcance corto es del encargo, no de la ejecución.** El `ENCARGO-05` preguntaba «¿existe en PoST
un análogo a los **niveles** de PoW…?», y eso es lo que el instrumento contesta. La vía recursiva se
audita aparte: **encargo 06**, decidido por Katana el 2026-09-17.

## 3.3 · Contradicción interna sobre la población de bloques (revisión externa, 2026-09-18)

**Encontrada por una revisión externa después de migrar, y verificada.** El instrumento se
contradice en un punto que afecta a las cifras de nivel:

- `MODELO.md:18` modela la distancia de un bloque como **`D = min(d_1,…,d_C)`** —«el bloque usa el
  chunk ganador de menor distancia»—, y D1 construye sobre eso toda la fórmula exacta.
- **D6, del mismo informe**, dice que dos chunks ganadores del mismo s-bucket en el mismo slot son
  **dos billetes distintos** (R-FIN-11 incluye `chunk`) y **pueden ser dos bloques**.
- El código upstream respalda la segunda lectura: `map_winning_chunks` devuelve un
  `Vec<ChunkCandidate>` (`PDF/autonomys-subspace/crates/subspace-farmer-components/src/auditing.rs:236`).

**Las dos no pueden ser ambas correctas.** Si cada chunk ganador puede producir su propio bloque, la
población de bloques emitidos no tiene distancia `min(C)`: tiene `C` bloques con distancias
individuales, y las probabilidades de nivel de D1/D2 describen otra cosa.

**Qué no cambia:** el veredicto estructural. D4 (la solución es independiente de los padres) y D5
(el teorema de anclaje) **no dependen** de esta modelización —son sobre a qué se liga el nivel, no
sobre su distribución—, y el «no» a la prueba de poda por niveles se sostiene.

**Qué queda en duda:** las cifras cuantitativas de nivel y multiplicidad (D1, D2, D6,
`run-niveles.txt`, `run-multiples.txt`). Se conservan con esta advertencia, no se borran.

**Dónde se resuelve:** `ENCARGO-07` §3.5.3 lo pone como requisito previo, porque la tasa de
producción de bloques del adversario es la base de la curva `α`.

## 3.4 · Otras dos observaciones de la misma revisión

- **P1/P2/P3 no formalizan la no-transferibilidad.** El teorema D5 exige que `ℓ` sea comprobable sin
  el DAG (P1), ligado a recurso (P2) y ligado a la ancestría (P3). Pero lo que hace funcionar a PoW
  es más fuerte: **el recurso debe pagarse de nuevo por cada ancestría**. Un esquema que combine una
  condición cara pero **transferible** con otra barata ligada a los padres satisface las tres
  propiedades **literalmente** y sigue siendo inseguro. El Caso E argumenta contra esa combinación
  en prosa, pero la formalización no lo captura. El resultado sigue siendo válido para los
  mecanismos examinados; **como teorema general está sobre-enunciado**.
- **El modelo excluye el PoT y sus flujos**, que es donde historias distintas podrían generar retos
  distintos. El Caso C lo trata en prosa; el instrumento no lo modela.

## 4 · Un error de Claude durante la validación, para que no se repita

Al comprobar el Caso B de D5 —que se apoya en que el sello Ed25519 no es único (C-HDR-04)— Claude
informó que `crates/zx-core/tests/ed25519_no_unicidad.rs` **no existía**, y por tanto que el SPEC
citaba un test inexistente. **Era falso.** El test existe y está en su sitio; el `ls` se ejecutó
desde el directorio del instrumento porque el directorio de trabajo había cambiado entre llamadas.
La cita del ejecutor era correcta y el Caso B se sostiene.

Se deja escrito porque la lección es de método: una ruta relativa comprobada desde el directorio
equivocado produce un «no existe» que parece un hallazgo grave. Las comprobaciones de existencia se
hacen con ruta absoluta o tras fijar el directorio.

## 5 · Qué queda fuera de este instrumento

- **`F = 2 h` no se usa en ninguna cifra**, por orden expresa del encargo: es provisional.
- **No se fija ningún parámetro** (`L`, profundidad de poda, tamaños): todo se entrega como función.
- **La hipótesis `solution_distance ≤ SR/2^L` no se adopta como regla.** Se deriva exacta (D1) y se
  muestra que **no es el problema** (D2): el problema es el anclaje, no la probabilidad.
- **El controlador R-FIN-13′ no se audita** (no está especificado); el efecto del retarget va como
  función de `ρ = SR_branch/SR_ref`.
