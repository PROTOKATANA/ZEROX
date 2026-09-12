# Auditoría independiente — comprobación decisiva v1

> **Nota de estado (2026-09-12, promoción a `veritas/`; ampliada el 2026-09-12 con la
> enmienda Z0):** añadida por el ejecutor de la promoción, no por el auditor. Hallazgos
> cerrados después de esta auditoría: **H3** — la
> suite publicada ya ejercita el caso literal de la laguna (`fixture_copias_rojas_sin_azul`,
> tanda 1, junto con desempate de color, fusión posterior y reorg). **H1** — la semántica
> HeldZero quedó decidida por Katana el 2026-09-12 (enmienda Z0: no-op, sin agenda) y
> ejecutada en RCE-v0.1 revisión 2 y ARM-v0.1 revisión 2; esta comprobación la verifica en
> su fila 11 del INFORME (`range_at(40)=200` en Julia y Rust). El resto —H2, H4,
> H5, H6, H7, H8— sigue abierto tal como quedó escrito. Los hallazgos y cifras de este
> documento no se modifican.

Fecha: 2026-09-12. Auditor: Claude (sesión externa a la que escribió `comprobacion-decisiva-v1/`).
Objeto: `veritas/consenso/comprobacion-decisiva-v1/` (en el momento de la auditoría vivía en
`deepseek/comprobacion-decisiva-v1/`; PLAN.md, bitácora, código, resultados, INFORME.md).
Alcance: reproducir los artefactos, verificar la aritmética a mano, contrastar contra el SPEC y
`veritas/`, y buscar huecos entre lo que el INFORME afirma y lo que el código realmente prueba.

## 1 · El problema del SPEC que se resolvió

No era el reloj — ARM-v0.1 ya lo había cerrado. Lo que quedaba abierto está escrito literalmente
en `SPEC.md` §7.2 y en `research/dag-poas-ancla-de-orden.md` (nota bajo R-FIN-8′/13′, 2026-09-10):

> **Laguna de unicidad pagable.** «U3″ registra identidades azules, no todas las que han cobrado…
> Aplicar cada bloque una vez **no garantiza pagar cada billete una vez**. Falta definir **qué
> consume la identidad pagable**, **su contexto persistente** y **el desempate entre copias**,
> incluso en fusiones distintas.»

Con R-FIN-8′/13′ los `rojo_k` cobran y cuentan para el retarget. Eso abrió el agujero: dos copias
paralelas del mismo billete pueden quedar ambas rojas por k, y el SPEC no decía cuál cobra. Si
ambas cobraran, el atacante infla emisión y mete peso extra en `N_obs` → retarget más laxo →
espacio gratis. Es el mismo tipo de fallo (×15) que R-FIN-8′ ya había cerrado para `rojo_U3`,
reaparecido por la puerta de `rojo_k`.

La prueba del instrumento contesta las tres preguntas de la laguna con mecanismo ejecutable, no con
redacción:

| Pregunta del SPEC | Respuesta implementada |
|---|---|
| Qué consume la identidad pagable | el **billete** (`ticket`), no la identidad azul (`objective_winners` → `public.consumed`) |
| Contexto persistente | `Set consumed` arrastrado por la cadena aplicada, con pila `undo` para reorgs |
| Desempate entre copias | `select_key`: P0 `(rank, id)`, P1 `(azul-primero, rank, id)`, determinista, no depende del orden de llegada |

Y `eligible(c) = Blue || RedK` es exactamente el conjunto de R-FIN-13′ (azules + `rojo_k`, fuera
`rojo_U3`). El acoplamiento retarget↔emisión que exige R-FIN-13′ queda demostrado: el mismo
conjunto de ganadores alimenta pagos y `observed`.

## 2 · Verificación: qué se reprodujo

| Comprobación | Resultado |
|---|---|
| `test/runtests.jl --seed 20260912` (`--check-bounds=yes`) | **280/280**, exit 0 — idéntico a `resultados/TESTS.txt` |
| `run.jl --seed 20260912` | salida **byte a byte idéntica** a `resultados/RUN.txt` |
| Aritmética del retarget, a mano contra `controlador.jl` | correcta (ver detalle abajo) |
| Frontera de escritura declarada en PLAN.md/bitácora | cumplida — `deepseek/` es `??` (untracked) en git, sin commits, nada tocado en `veritas/` ni `crates/` |
| Caso de la laguna del SPEC (dos copias `RedK` del mismo billete, sin copia azul) | ejecutado ad-hoc, P0/P1 × Reference/Fast, converge también con orden de entrega invertido |

Recalculado desde `controlador.jl` con la config del fixture
(`initial_range=100, target=10, gain=1/1, clamp=[1/2,2/1], range=[1,1000], activation_delay=1`,
`blend=10`):

- **H700**: corte `(0+1)·10=10`, sello 10 → activación `(10÷10+1)·10=20`. `observed=5` →
  `⌊100·10/5⌋=200`, tope superior `2×100=200` → **200@20** ✓
- **H701**: corte 20, sello 20 → activación 30. Rango activo 200. `observed=1` →
  `⌊200·10/1⌋=2000`, recortado a `2×200=400` → **400@30**, `clamped=true` ✓
- **naive** (agrupando por `(billete, offset, variante)`): `observed=6` → `⌊1000/6⌋=` **166** ✓
- **Economía**: 6 ganadores (bloques 1..5 en H700, bloque 10 en H701; el bloque 6 dedupado por
  billete 1). Pagos `6×500=`**3000**; consumos `5×1000+500=`**5500**; disponibles finales
  106-110 + 1002-1005 + 1010 = **10 UTXOs** ✓
- **Reloj**: recepción 21 → `local_seal=21 ≥ activación 20` → `MissedUpdate` → 100. Recepción 9 →
  sello local 10 < 20 → `Scheduled` → 200. El camino causal da 200 en ambos ✓

No se encontró ningún número inventado ni cifra del INFORME sin artefacto que la respalde. La
bitácora declara dos errores propios corregidos en el camino, lo cual es señal de método correcto,
no de un problema.

## 3 · Lo que sí queda demostrado

El corazón de la etapa A aguanta: orden de entrega, retención de cuerpos y copias no mueven el
dinero ni el rango. El punto no obvio —el que realmente decidía la arquitectura— es que DCM
publica de forma **conjunta** DCM + controlador + economía, y `Pending`/`Invalid` no publican nada
parcial (`modelo.jl` función `replay!`). Sin esa atomicidad, un cuerpo tardío habría dejado medio
estado escrito, y ahí sí divergerían dos nodos.

## 4 · Hallazgos — dónde el INFORME afirma más de lo que midió

**H1 · La discrepancia HeldZero no es "legada", es un fork vivo entre dos implementaciones
propias.** La más grave de los hallazgos.

En `fixture_heldzero`, la ventana vacía en el sello 20 lee el rango activo todavía en 100 (la
propuesta 200@30 no ha activado) y agenda **100@40**. Resultado: el rango sube a 200 en el slot 30
por evidencia real y vuelve a caer a 100 en el slot 40 por una ventana vacía que ni siquiera vio
ese 200. El helper Rust histórico (`FeedbackState.close`, referenciado en
`veritas/consenso/admision-retarget-multivista-v1/MODELO.md`) omite esa propuesta y conserva 200.

Julia y Rust, mismo SPEC, rango distinto tras una ventana vacía. Es exactamente la clase de fallo
que esta comprobación existía para descartar. El INFORME lo declara con honestidad ("HeldZero es
un resultado derivado, no una recomendación") pero `test/runtests.jl` lo fija como esperado
(`@test range_at_40 == 100`), lo que convierte una divergencia no resuelta en contrato. Hay que
decidir cuál semántica es la correcta antes de escribir el nodo, no después.

**H2 · "Distinto orden" está demostrado para exactamente un par de órdenes.** Hay dos colas fijas
(Ana, Bruno), cruzadas con 2 políticas × 2 redondeos. No hay barrido de permutaciones. Y
`runtests.jl` línea 13 es `@test cola_ana == cola_ana` — una tautología: nada asegura que los dos
órdenes sean realmente distintos entre sí (la comprobación real de multiconjunto igual está en la
línea siguiente). Para un resultado que se anuncia como decisivo, esto pide un barrido determinista
de permutaciones o entrelazados adversariales generados, no solo dos calendarios fijos a mano.

**H3 · El caso exacto que nombra la laguna del SPEC no está en el fixture.** La laguna dice "si
ambas copias quedan rojas por k sin copia azul". El fixture usa bloque 1 Azul + bloque 6 RedK (una
sola copia roja). Se ejecutó ad-hoc un fixture con dos `RedK` del mismo billete y sin copia azul,
en P0/P1 × Reference/Fast: el mecanismo aguanta — gana la de menor `rank`, `observed=2`,
`total_paid` correcto, y converge también con el orden de entrega invertido. El mecanismo cubre la
laguna; la suite publicada no la ejercita. Es un vector de una hora que debería añadirse a
`validacion.jl`.

**H4 · "Dos nodos, no dos vistas" está a medias.** Ana y Bruno comparten el mismo objeto
`EconModel`, incluido `context_truth` — el oráculo de validez contextual. Difieren solo en la cola
de entregas. Convergen en parte por construcción: ambos derivan ganadores del mismo catálogo con
la misma política. Lo que se demuestra es "el orden de llegada no cambia el resultado", que es real
y valioso; no es "dos nodos independientes con datos propios acuerdan". El límite ya está declarado
en el INFORME (`range_validation=Pending`), pero conviene que la palabra "nodos" no se lea como más
de lo que hay.

**H5 · La capa económica no conserva valor.** `aplicar_txs!` nunca compara entradas con salidas de
una misma transacción. En el fixture principal se consumen 5500 y se pagan 3000: 2500 desaparecen
sin que nada lo compruebe. Una tx podría igualmente imprimir dinero de la nada. Para el objetivo
"los dos nodos calculan lo mismo" da igual (ambos nodos serían igual de permisivos); para llamarla
"capa económica" falta el invariante `Σsalidas ≤ Σentradas`, aunque sea como aserción del modelo.

**H6 · El `catch ArgumentError → Invalid` mezcla dos cosas distintas** (`modelo.jl`, función
`replay!`). `snapshot` lanza `ArgumentError("counted != payable")` ante una rotura de invariante
interno de consenso, y el `catch` la convierte en el mismo veredicto `Invalid` que un doble gasto
legítimo. Un bug interno quedaría enmascarado como "historia inválida", que es justo lo que los
controles negativos esperan ver. Los errores de dominio (sello antes del corte, cohortes no
consecutivas) sí merecen `Invalid`; los invariantes internos deberían propagarse como fallo, no
convertirse silenciosamente en un veredicto de consenso.

**H7 · El control negativo de copias no ejercita una bifurcación real del nodo.** `peso_naive` se
calcula fuera del nodo; el nodo nunca recorre esa rama. Lo que se demuestra es "agrupar por
`(billete, offset, variante)` da 6 y 166 en vez de 5 y 200", no que el sistema *detecte* a un
atacante en producción. La defensa real es el dedup por billete en `objective_winners`, y toda su
seguridad se reduce a que el billete identifique de verdad la oportunidad — cosa que el fixture
*declara* (bloque 6 con `ticket=1`) y no demuestra. Ese supuesto es el contrato de
`veritas/consenso/contrato-billete-v1/` y debería figurar explícitamente en los límites del
INFORME; no figura.

**H8 · Menores.**
- Bench con `samples=10`: la mediana de 10 muestras es frágil como referencia de coste.
- El kernel UInt128 es más lento que la referencia BigInt en 5 de 6 mediciones del bench; el
  INFORME lo dice honestamente, pero entonces `rapido.jl` no funciona como "kernel más rápido" en
  este rango de profundidades — es una segunda implementación de control, no una optimización.
- Referencia y kernel activan propuestas con algoritmos distintos (rescán total vs. cursor
  incremental); coinciden solo porque los slots de activación resultan monótonos en la cadena
  construida. Ese invariante (monotonicidad de `activation_slot` a lo largo de una cadena) no se
  comprueba explícitamente en ningún test; si dejara de cumplirse, el cursor de `rapido.jl`
  divergiría en silencio de la referencia.

## 5 · Veredicto para el objetivo (PoST + DAG)

El camino es viable y la prueba lo sostiene: la composición DCM + RCE + economía no diverge por
orden de entrega, retención de cuerpos ni copias, y el dedup por billete cierra la laguna de
unicidad pagable del SPEC con mecanismo verificado, no solo con redacción. Nada en estos artefactos
refuta el enfoque PoST+DAG.

Pero la conclusión correcta no es "los 13 requisitos quedan demostrados" tal como dice la tabla del
INFORME. Es: *un fixture bien construido pasa, y hay una divergencia Julia↔Rust sin resolver dentro
del propio controlador de retarget (H1)*. Antes de escribir el nodo, el orden de prioridad sugerido
es: **H1** (decidir la semántica HeldZero — es un fork real, no una nota al pie), **H3** (añadir el
vector de dos copias rojas sin azul, ya verificado que el mecanismo aguanta), **H2** (barrido de
permutaciones de entrega), **H5** (invariante de conservación de valor).

## Reproducibilidad

Comandos ejecutados desde la raíz del repo, entorno idéntico al declarado en
`comprobacion-decisiva-v1/resultados/ENTORNO.txt`:

```bash
env JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 JULIA_PKG_PRECOMPILE_AUTO=0 timeout 120s \
  veritas/julia.sh --project=veritas/consenso/comprobacion-decisiva-v1 --check-bounds=yes \
  veritas/consenso/comprobacion-decisiva-v1/test/runtests.jl --seed 20260912

env JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 JULIA_PKG_PRECOMPILE_AUTO=0 timeout 120s \
  veritas/julia.sh --project=veritas/consenso/comprobacion-decisiva-v1 \
  veritas/consenso/comprobacion-decisiva-v1/run.jl --seed 20260912
```

Ambos exit 0; la segunda salida se comparó byte a byte contra `resultados/RUN.txt` (idéntica). El
caso de H3 (dos copias `RedK` del mismo billete sin copia azul) se ejecutó como script ad-hoc fuera
de `deepseek/`, sin escribir en el árbol de la comprobación; no queda como artefacto versionado —
si se decide incorporarlo, debe añadirse a `validacion.jl`/`test/runtests.jl` con su propio fixture
nombrado, no dejarlo en un script suelto.

Esta auditoría no modificó ningún archivo dentro de `comprobacion-decisiva-v1/`; solo lee sus
artefactos y añade este documento en `deepseek/`.
