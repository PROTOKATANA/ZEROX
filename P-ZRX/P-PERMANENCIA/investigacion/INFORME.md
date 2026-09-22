**E2 cae; E3 se sostiene solo como cota económica y solo para la permanencia (ii).** Las aperturas
aleatorias por muestreo (E2) **no demuestran almacenamiento**: su coste para el tramposo es `c`
tablas por auditoría, **independiente del tamaño del lote**, y con la ventana medida baja a
`c/(r·w)` CPU; con `c=1.000, D_a=60 s` le bastan **0,666 CPU** y con la ventana **0,0056 CPU**. Las
pruebas parciales (E3) **sí** imponen una obligación proporcional al lote —a `w=7.175` slots,
`N/(r·w)=5,84` CPU (16 núcleos) por TiB, es decir **82,9 % del lote forzado a almacenarse**—, pero
esa obligación **es exactamente la que ya impone farmear** (E5): E3 no la encarece, la hace
**observable**. Por eso E3 **no sustituye a E1**: (a) es garantía **económica**, no criptográfica;
(b) depende de `w` y del hardware — el escenario GPU `17×` (**documentación ajena, nunca medida**)
la reduce a `0,343` GPU/TiB y anula el almacenamiento forzado por debajo de `2,9 TiB` por GPU—; (c)
en cadena, **todas** las parciales tienen que quedar ligadas, porque muestrearlas con posiciones
predecibles (el reto sale del PoT, público con `w` slots de antelación) colapsa el coste a `k`
tablas por envío. Para la afirmación **(i) «existía entera antes del reto»** E3 no aporta nada
temporal: no fecha nada y no cubre los bytes; el hueco C1 de `P-SEMBRADOR` **sigue abierto**.

# INFORME — P-PERMANENCIA

**Encargo:** `P-ZRX/P-PERMANENCIA/PROMPT.md`. **Instrumento:**
`P-ZRX/P-PERMANENCIA/investigacion/veritas/almacenamiento/permanencia-v1/` (categoría
`almacenamiento`; Julia 1.13.0, CPU `znver5`, 4 hilos). **Fecha:** 2026-09-21.

**Presupuesto declarado antes de ejecutar:** máximo **4 hilos**, **8 GiB de RAM**, **256 MiB de
disco**, **4 h de pared**. **No se agotó.** Comprobaciones de entrada y salida en `PROGRESO.md`.

**Zona de escritura respetada:** solo `P-ZRX/P-PERMANENCIA/investigacion/`. No se editó ni movió
nada de `SPEC.md`, `TAREAS.md`, `ci/`, `crates/`, `prototipos/`, `research/`, `veritas/` ni del
resto de `P-ZRX/`.

---

## 0 · Respuesta corta, y las tres objeciones que se confirmaron

1. **F1 · E2 cae ante la regeneración, y cae por estructura, no por calibrar mal `(c, D_a)`.** El
   tramposo regenera exactamente las `c` piezas pedidas: `c/(r·D_a)` CPU, sin dependencia de `N`.
   Coste por TiB simulado → 0. Con la ventana, `c/(r·w)` CPU. **[derivado + medido]**
2. **F2 · E3 se sostiene como estadística y como obligación económica en la ventana medida, pero no
   añade coste sobre E5.** La estadística exacta distingue tamaños (un lote de 1 TiB con el 50 %
   almacenado se detecta en 9 periodos; con el 90 %, en 268); la obligación de responder sobre el
   lote entero cuesta `N/(r·w)` CPU, que a `w=7.175` son 5,84 CPU/TiB, ~100× el coste en hardware de
   almacenar. **El cruce «fabricar sale más barato que el disco» está en `w≈8,4·10⁵` slots (≈9,7
   días)**, no en miles. **[derivado]**
3. **F3 · E3 no sustituye a E1.** Para (ii) «sigue existiendo» da una garantía económica
   condicionada; para (i) «existía entera antes del reto» no da nada: no fecha y no cubre los
   bytes. Y **E1 no existe** para el formato fijado: el compromiso de sector cubre la codificación
   de datos públicos, no las tablas caras. **[verificado en fuente + no determinado]**

**Objeciones declaradas antes de empezar** (en `PROGRESO.md` §0): O1, la hipótesis del §0 se reduce
a E5 porque farmear ya exige responder sobre la parcela entera cada slot; O2, E3 mide tamaño
respondido, no edad ni identidad; O3, `r=25,03` es cota superior del atacante; O4, la Poisson es
hipótesis y hay que usar la binomial exacta en lotes pequeños; O5, todo en hardware, nunca en
dinero. **O1, O2 y O4 se confirmaron; O3 y O5 se respetaron como restricciones del modelo.**

---

## 1 · Alcance, método y qué se hereda

**Qué es este informe.** Una **comparación de diseño con un modelo cuantitativo pequeño**, no una
campaña de simulación. Todo sale de funciones de los símbolos del encargo; no se mide hardware
nuevo. Las cifras de hardware son las de `P-ZRX/P-INTENTO/investigacion/INFORME.md` y
`P-ZRX/P-REVELACION/investigacion/INFORME.md`, etiquetadas **medido, sin revalidar**, y tratadas
como **cota superior del coste del atacante**.

**Qué lee de verdad un granjero por slot (verificado en el código fijado).**
`audit_plot_sync` recorre **todos** los sectores y, por sector y slot, lee **un solo s-bucket**
(`PDF/autonomys-subspace/crates/subspace-farmer-components/src/auditing.rs:126-186`), cuyo índice
deriva del reto (`:198-234`). El s-bucket contiene una entrada de 32 B por pieza con prueba en ese
bucket; `map_winning_chunks` (`:237-271`) prueba cada entrada con `is_within_solution_range`
(`PDF/autonomys-subspace/crates/subspace-verification/src/lib.rs:148-159`). Quien gana paga el
camino caro: regenerar la tabla de la pieza y `recover_poly`+`create_witness`
(`PDF/autonomys-subspace/crates/subspace-farmer-components/src/proving.rs:243-329`).

**Qué se almacena realmente.** El plot guarda, por bucket ocupado, `raw_chunk XOR blake3(proof)` y
**cero** donde no hay prueba (`PDF/autonomys-subspace/crates/subspace-farmer-components/src/plotting.rs:616-667`).
La tabla intermedia son siete tablas
(`PDF/autonomys-subspace/shared/ab-proof-of-space/src/chiapos.rs:195-268`;
`…/chiapos/constants.rs:7`: `NUM_TABLES = 7`) y `Proofs<20>` ocupa 5,008 MiB
(`P-ZRX/P-INTENTO/…/INFORME.md` §5). El objeto **caro de recalcular** es la tabla; el plot es su
resultado. `NUM_CHUNKS = 2^15` y `NUM_S_BUCKETS = 2^16`
(`PDF/autonomys-subspace/crates/subspace-core-primitives/src/pieces.rs:404,565`), de donde
`o = 1/2`; `Piece::SIZE = 1.048.672 B` (`…/pieces.rs:1226`).

**Símbolos (entradas, no constantes fijadas).** `N` piezas del lote · `w` slots de adelanto ·
`D_a` plazo de auditoría · `c` aperturas · `qP` parciales por pieza y periodo · `P` slots por
periodo · `a` disponibilidad · `s` fracción almacenada · `σ` cuota del granjero · `M`, `F`,
`ρ_ret`, `T_v` (símbolos). Todo se pasa por CLI y queda en `resultados/*.tsv`.

**Fuentes externas primarias abiertas** (no se cita ninguna sin abrirla): especificación PoSt de
Filecoin, `post.md` de Spacemesh, `nipost.md` de Spacemesh y protocolo de pools de Chia. Las que
solo se leyeron en resumen van marcadas como **no verificado** en su ficha.

---

## 2 · Fichas de los esquemas

### E1 · Prueba sucinta de cobertura completa (la «C1» de P-SEMBRADOR)

**Mecanismo.** Un compromiso publicado **antes** del reto liga clave, lote y la **codificación
completa**; una prueba sucinta demuestra que el compromiso abarca todos los bytes y que se
calcularon. En el formato fijado el compromiso disponible es doble: `record_commitment` (KZG) contra
el compromiso de segmento (`subspace-verification/src/lib.rs:262-347`) y el compromiso de parcela
del `PlotBatchId` que propone `CANDIDATA.md` §1. Ninguno de los dos cubre el objeto caro: la tabla
PoS.

**Qué demuestra exactamente y qué no.** **[verificado en fuente]** El compromiso de sector cubre la
**codificación de datos públicos** (erasure coding + KZG) y el alta de sector; **no** cubre
`blake3(proof)`, que es lo que cuesta 809 ms/pieza. **[no determinado]** No se ha encontrado ninguna
prueba sucinta desplegada para este formato. Lo que existe en la literatura son tres familias
distintas: auditoría probabilística por muestreo (PDP/PoR, y su forma compacta de 40 B, **citas de
resumen, no del cuerpo**); SNARK sobre todo el dataset (PoRep/Filecoin `Seal`, que prueba que la
codificación se generó **correctamente**, no que se conserve después); y jerarquía de compromisos
(el patrón real de Autonomys/Filecoin, que prueba que el sub-objeto está **incluido** en el
compromiso). **[derivado]** Ninguna de las tres da lo que C1 pedía: que el compromiso abarque el
resultado caro sin abrir hojas.

**Estrategia óptima del tramposo y coste absoluto.** **[derivado de medidas]** Si hubiera que
comprometer el resultado caro, el trabajo por TiB es `N·t_tabla = 848.220 s·núcleo = 235,6 h·núcleo`
(`resultados/E1-E4-coste.tsv`). Una prueba de cómputo sobre eso es órdenes de magnitud mayor y **no
se ha medido**: **[no determinado]**. El sembrador no paga nada de esto hoy.

**Coste para el honesto.** Registrar un `PlotBatchId` y probar inclusión: bytes de una transacción
+ aperturas KZG. **[no determinado]** en bytes hasta que exista el formato.

**Tasa de fallo del honesto con `a<1`.** No aplica: es una prueba de alta, no una auditoría
periódica.

**Qué cambia del formato.** **[propuesto]** Alta con raíz de la codificación completa, versión y
cardinalidad (`CANDIDATA.md` §1), y una prueba nueva que cubra las tablas o un sellado (E4).

**Madurez.** **Por inventar** para este formato. Precedente desplegado: Filecoin PoRep (SNARK de
sellado) y el propio esquema de compromisos de Autonomys, que **no** cubre las tablas.

**Evidencia y qué habría que medir.** Medir el circuito/prueba si se intenta; comparar con E4.
**[no determinado]** viabilidad, tamaño de prueba, coste de probador/verificador.

---

### E2 · Aperturas aleatorias con plazo (muestreo de piezas)

**Mecanismo.** El auditor pide abrir `c` piezas al azar por lote; el granjero responde dentro de
`D_a` con el chunk y su testigo KZG. Es la auditoría clásica PDP/PoR.

**Qué demuestra exactamente y qué no.** **[derivado]** Demuestra que `c` posiciones concretas
estaban disponibles en ese instante. **No** demuestra que el lote exista entero, **no** demuestra
permanencia entre auditorías y **no** escala con `N`: el coste del tramposo es `c` tablas.

**Estrategia óptima del tramposo y coste absoluto por TiB.** **[medido + derivado]**

| `c` | `D_a` [s] | CPU sin ventana | CPU con `w=7.175` | Bytes/cadena (todas) | Bytes (comprometer + abrir 10) |
|---:|---:|---:|---:|---:|---:|
| 1.000 | 60 | **0,666** | **0,0056** | 112.000 B | 33.120 B |
| 10.000 | 60 | 6,66 | 0,056 | 1.120.000 B | 321.120 B |
| 100.000 | 600 | 6,66 | 0,557 | 11.200.000 B | 3.201.120 B |

`resultados/E2-plazo.tsv`. **El coste no depende de `N`**: por TiB simulado tiende a cero. El
tramposo que no almacena nada falla solo si `c > r·D_a = 25,03·D_a`; con `D_a=60 s` eso exige
`c > 1.502`, y un solo núcleo ya genera `r=1,24` tablas/s. La ventana lo abarata además a
`c/(r·w)` CPU.

**Coste para el honesto (IOPS, CPU, bytes).** **[derivado]** Un HDD a 10 ms por lectura aleatoria
sirve `D_a/0,010` aperturas (6.000 en 60 s = 100/s); un SSD a 0,1 ms, 600.000. El honesto **no**
genera tablas: lee. Y no cabe en cadena publicar todas las aperturas de todos los lotes; la
alternativa de comprometer el conjunto y abrir `k` reduce bytes, pero cae con la ventana (ver E3).

**Tasa de fallo del honesto con `a<1`.** **[derivado]** Una sola auditoría fallida por apagón
dispara el falso fallo con probabilidad `1−a`; con `a=0,99` y 1.000 lotes por periodo, la
probabilidad de al menos un falso fallo es `1−0,99^1000 ≈ 1`. Hay que tolerar fallos o recalibrar,
y ninguna de las dos cosas está en el diseño.

**Qué cambia del formato.** **[propuesto]** Una prueba de apertura dirigida por reto y un calendario
de auditorías; no cambia la parcela.

**Madurez.** **Desplegado** en Filecoin con otro vocabulario: `WindowPoSt` audita cada sector al
menos una vez cada 24 h, con **10 desafíos por sector** y particiones de 2.349 sectores
([`post.md`](https://github.com/filecoin-project/specs/blob/master/content/algorithms/pos/post.md),
**abierto**). La propia especificación declara que la garantía es **económica**: *«makes it
irrational for a miner to not keep a sealed copy»*, no una prueba de preexistencia.

**Evidencia y qué habría que medir.** Medir aperturas reales desde HDD/SSD con `c` grande y la
probabilidad de fallo con disponibilidad `a`. **[no determinado]** el `(c, D_a)` que un granjero
doméstico sostiene en peor caso.

---

### E3 · Pruebas parciales (la hipótesis del validador)

**Mecanismo.** Parciales = soluciones con **umbral más fácil** sobre los retos ordinarios. El
número por periodo estima el tamaño real del lote, como los *partials* de los pools de Chia para
medir el espacio de sus miembros. La obligación no es «ganar»: es **responder en cada slot sobre la
parcela entera**.

**Qué demuestra exactamente y qué no.** **[derivado · confirmado]** Demuestra, **estadísticamente y
solo como cota económica**, cuánta parcela **responde**. **No demuestra**: (a) cuándo se calculó
—nada en un parcial fecha un instante anterior al reto—; (b) que los bytes respondidos sean los
registrados, salvo que el `PlotBatchId` derive las posiciones (lo hace: `SectorId` liga clave,
índice e historia, `sectors.rs:54-68`, y `derive_piece_index` liga offset e historia,
`sectors.rs:70-114`); (c) que el atacante no regenere dentro de la ventana. Spacemesh dice lo mismo
de su PoST homólogo: *«the protocol does not allow a prover to prove they **stored** the data, since
an adversary can instead store only the initial seed»*
([`post.md`](https://raw.githubusercontent.com/spacemeshos/protocol/master/post.md), **abierto**).

**Estrategia óptima del tramposo y coste absoluto por TiB.** **[derivado]**

| `w` [slots] | Piezas fabricables por CPU | TiB por CPU | **CPU por TiB** | Almacenamiento forzado (1 TiB) |
|---:|---:|---:|---:|---:|
| 1 | 25 | 2,4·10⁻⁵ | 41.890 | 100,0 % |
| 1.000 | 25.030 | 0,0239 | 41,89 | 97,6 % |
| **4.830,6** (con VDF, ρ=2,5) | 120.910 | 0,1153 | **8,672** | **88,5 %** |
| **7.175** (sin VDF) | 179.590 | 0,1713 | **5,838** | **82,9 %** |
| 10⁵ | 2.503.000 | 2,387 | 0,419 | 0 % |
| 10⁶ | 25.030.000 | 23,87 | 0,0419 | 0 % |

`resultados/E3-ventana.tsv`. **Cruces:** fabricar un lote de 1 TiB con una CPU exige
`w = 41.889` slots (11,6 h); **igualar un disco de 20 TB exige `w = 837.779` slots (9,7 días)**;
igualar 1 PiB, `w = 4,72·10⁷` (1,5 años). Con **un núcleo** el coste a `w=7.175` es 118,2 CPU/TiB.
**Escenario GPU `17×` (documentación ajena, NUNCA medida):** a `w=7.175` rinde 2,912 TiB por GPU →
`0,3434` GPU/TiB y **almacenamiento forzado 0 para un lote de 1 TiB**; cruzando 20 TB en
`w=49.281`. **[estimado, escenario]**

**El muestreo de parciales, y por qué la ventana lo rompe.** **[derivado]** Comprometer las `λ`
parciales del periodo y abrir `k` al azar exige `m/λ ≥ (1−γ)^{1/k}`: con `k=1, γ=10⁻²` ya son
**0,99**, y con `k=10`, **0,99899** (`resultados/E3-agregacion.tsv`). Es decir, el muestreo **no**
abarata la obligación… **si las posiciones se eligen después**. Pero el reto sale del PoT, que es
público `w` slots antes: el tramposo **sabe qué `k` posiciones se abren y regenera solo esas `k`**.
Coste `k/(r·P)` CPU, independiente de `N`: `0,0040` CPU con `k=10, P=100, w=7.175`. **Conclusión:
E3 solo sobrevive si TODAS las parciales quedan ligadas**; el muestreo con posiciones predecibles
lo colapsa.

**Coste para el honesto (IOPS, CPU, bytes).** **[derivado]** El honesto no paga cómputo extra: lee
el s-bucket auditado de cada sector cada slot (`auditing.rs:126-186`), que es lo que ya hace para
farmear. En cadena, si van todas las parciales, `λ·b` bytes por lote y periodo: con `qP=10⁻⁵`,
`P=100` y `b=200 B`, son **2.097 B/periodo/TiB** (21 B/slot) y **209.600 B/periodo** para 100 TiB.
**[no determinado]** si eso cabe: el tamaño de bloque es un parámetro de consenso que **no se fija
aquí**.

**Tasa de fallo del honesto con `a<1`.** **[derivado]** Con el umbral `K` calibrado a `a=1`, el
falso fallo por evaluación crece con `1−a`: para 1 TiB y `s=0,9` (T=268 periodos), `a=0,99` da
**5,17·10⁻³** frente a `β=10⁻³` (5,2×), y con `a=0,5` el test es inutilizable sin recalibrar `K` a
`a`. Hay que **declarar `a` y recalibrar** o el falso fallo expulsa al honesto.

**Estadística (colas exactas).** **[medido por el instrumento]** `λ = N·qP` (Poisson). Con
`qP=10⁻⁵, P=100`:

| Lote | `λ`/periodo | `T` (tramposo con `s=0,5`) | `T` (`s=0,9`) | Error relativo del estimador |
|---|---:|---:|---:|---:|
| 1 TiB | 10,48 | **9** | **268** | 10,3 % (T=9) |
| 10 TiB | 104,8 | **1** | **27** | 9,8 % (T=1) |
| 100 TiB | 1.048 | **1** | **3** | 3,1 % (T=1) |

`resultados/E3-estadistica.tsv`. La referencia es **exacta** (`Rational{BigInt}` para
`Σλ^j/j!` y para la binomial; intervalo con redondeo dirigido de MPFR): la discrepancia
Poisson↔binomial exacta en lotes pequeños es `1,52·10⁻³`, dentro de la cota de Le Cam `2np²`
(`4,0·10⁻²`). **En lotes pequeños la Poisson no es la referencia**; el instrumento usa la binomial
allí.

**Qué cambia del formato.** **[propuesto]** Ninguno en la parcela; sí una **prueba de parcial** en
la solución (umbral más fácil), un contador/compromiso por lote y periodo, y una regla de qué
parciales van a la cadena. Requiere decidir el calendario de auditoría (`D_a`, `P`).

**Madurez.** **Parcialmente desplegado, en otro contexto.** Los pools de Chia usan parciales para
estimar espacio: *«The pools use these partial proofs to determine how much space the farmers have
dedicated»*; dificultad 1 ≈ 10 parciales/día/plot k32; objetivo de 300 parciales/día «to ensure
frequent feedback to the farmer, and low variability»
([protocolo de pools de Chia](https://docs.chia.net/chia-blockchain/protocol/pool/pool-protocol/),
**abierto**). Los parciales de Chia **no** van a la cadena. **[derivado]** Ese uso estima espacio
*farmeado*, no permanencia: es el mismo mecanismo, con otro objetivo.

**Evidencia y qué habría que medir.** Medir el falso fallo real con disponibilidad medida; decidir
la política de cadena y **medir sus bytes**; y volver a medir `r` con kernels adversariales
(SIMD/GPU/ASIC) porque `r=25,03` es **cota superior del coste del atacante**, no su mínimo.

---

### E4 · Sellado secuencial (estilo PoRep) — referencia

**Mecanismo.** La parcela se produce por una ruta secuencial ligada a identidad y ticket previo, y
se acompaña de prueba sucinta. Si el candidato se elige tras conocer el reto y el sellado adversarial
dura más que la ventana, no llega a tiempo.

**Qué demuestra exactamente y qué no.** **[derivado, de P-REVELACION]** Demostraría existencia
previa **si** la ruta adversarial supera `w` y **si** no hay atajo. **No** obliga a conservarla
después: un PoRep «fundamentally cannot guarantee that the data is stored redundantly» (resumen de
PoReps, **no verificado en el cuerpo**).

**Estrategia óptima del tramposo y coste absoluto por TiB.** **[derivado]** Otra vez `N·t_tabla` por
TiB para regenerar; el sellado tendría que durar del orden de la ventana (**horas por lote**), no
segundos.

**Coste para el honesto.** **[no determinado]** Alta lenta, memoria temporal, prueba sucinta.
Verificación repetida por sector sería inviable.

**Tasa de fallo del honesto con `a<1`.** No aplica al sellado; sí a las auditorías posteriores.

**Qué cambia del formato.** **[propuesto]** Sustituye sustancialmente la parcela Autonomys y
probablemente `proof_of_space`.

**Madurez.** **Desplegado en Filecoin** (`Seal`, Multi-SNARK; ver ficha E2), **no** para Autonomys.
No es trasladable sin rediseño.

**Evidencia y qué habría que medir.** Ruta crítica del sellado, memoria adversarial, coste de
generar/verificar la prueba y aceleración por plataforma.

---

### E5 · Farmear y nada más (línea base)

**Mecanismo.** La única prueba de permanencia es seguir ganando bloques.

**Qué demuestra exactamente y qué no.** **[derivado]** No demuestra nada: infiere por varianza. La
ausencia de victorias de un granjero con cuota `σ` se nota en `T = −ln(β)/(σ·λ)` slots.

**Estrategia óptima del tramposo y coste absoluto por TiB.** **[derivado · resultado central]** Un
tramposo que quiere **seguir farmeando** sin almacenar tiene que recorrer la parcela entera cada
slot para saber si tiene ganador; con `w` slots de adelanto regenera una vez por ventana:
**`N/(r·w)` CPU = 5,838 CPU/TiB a `w=7.175`** (`resultados/E3-ventana.tsv`). **Es exactamente el
mismo coste que E3.** Si solo quiere **cobrar retenido sin farmear**, con E5 no paga nada mientras
nadie lo note.

**Coste para el honesto.** Lectura de un s-bucket por sector y slot; sin cómputo extra.

**Tasa de fallo del honesto con `a<1`.** **[derivado]** Un honesto con `σ=10⁻²` deja de ganar por
azar durante 691 slots (11,5 min) con probabilidad `β=10⁻³`; con `σ=10⁻⁴`, 69.078 slots (19,2 h);
con `σ=10⁻⁵`, 8,0 días. `resultados/E5-deteccion.tsv`. **Un granjero pequeño es invisible mucho
tiempo.**

**Qué cambia del formato.** Nada.

**Madurez.** **Desplegado** (es el estado actual sin auditorías de permanencia).

**Evidencia y qué habría que medir.** La varianza real depende de `π_DAG` y del DAG de ZEROX, que
**no existe todavía**: **[no determinado]**.

---

## 3 · Las preguntas

### F1 · ¿Cae E2 ante la regeneración?

**Sí, y por estructura.** **[derivado + medido]** El coste es `c` tablas por auditoría, no `c·N`:
para `c=1.000, D_a=60 s`, **0,666 CPU**; el umbral de imposibilidad para una CPU de 16 núcleos es
`c > r·D_a = 1.502`. Como un HDD doméstico sirve 6.000 aperturas en 60 s, el `(c, D_a)` que expulsa
al tramposo de 16 núcleos (`c/D_a > 25,03/s`) lo sirve el honesto de sobra (`c/D_a ≤ 100/s`); pero
cualquier atacante con **cuatro CPU** o una GPU lo vuelve a pasar, y con la ventana medida le bastan
**0,0056 CPU**. **No existe `(c, D_a)` que separe honesto y tramposo sin fijar el hardware del
atacante**, y como el coste por TiB simulado tiende a cero, E2 **no escala**. Respuesta: cae; y como
el encargo anticipa, lo que quedaría es exigir respuesta sobre el lote entero, que es E3/E5.

### F2 · ¿Se sostiene E3?

**(a) Estadística.** **[derivado + medido por el instrumento]** Sí: con colas exactas, 1 TiB se
distingue al 50 % en **9 periodos** y al 90 % en **268**; 100 TiB, en **1** y **3**. El error
relativo del estimador es `1/√(λT)` (10,3 % con T=9 y 1 TiB). Falso fallo de un honesto con `a`:
con `K` calibrado a `a=1`, `a=0,99` da `5,17·10⁻³` para el caso `s=0,9` (5,2×β); con `a` menor hay
que recalibrar. **[derivado]**

**(b) Trampa con ventana.** **[derivado]** `N/(r·w)` CPU continuas: **5,838 CPU/TiB a `w=7.175`**,
**8,672 a `w=4.830,6`** (con VDF), **0,419 a `w=10⁵`**, **0,0419 a `w=10⁶`**. Con CPU medida: 1 CPU
fabrica 0,171 TiB por ventana. **¿A partir de qué `w` sale más barato que el disco, en hardware?**
Cuando una CPU fabrica lo que un disco guarda: **`w = 837.779` slots (9,7 días) para 20 TB**;
`w = 4,72·10⁷` (1,5 años) para 1 PiB. En el escenario GPU `17×` (no medido) el cruce baja a
**`w = 49.281` slots** y una GPU fabrica 2,9 TiB. **[estimado, escenario]**

**(c) Atajos.** **[derivado + verificado en fuente]** No se ha encontrado poda del cono de tablas
(`P-ZRX/P-INTENTO/…/INFORME.md` §8: cota superior de poda 9,2 %); el compromiso tiempo-memoria
`T·S² ∈ Ω(ε²N²)` de `research/time-memory-tradeoff.md:60-100` castiga guardar fracción de tabla,
pero **no** cambia que regenerar una tabla entera desde su semilla cueste `t_tabla`. El atajo real
es otro: **guardar el mapa de presencia** (`found_proofs`, 8 KiB/pieza) — pero **no da la
distancia**, así que no permite contar parciales sin regenerar; y a lo largo de una ventana la
unión de buckets ocupados cubre casi todas las piezas, así que no reduce el coste por ventana. En
Autonomys no se verificó compresión tipo DrPlotter (25,8 %–50 % en Chia,
`research/chia-parcelas-comprimidas.md`); **[no verificado]** si aplica. **Veredicto: E3 se
sostiene como cota económica en la ventana medida, con las tres salvedades de la respuesta corta.**

### F3 · ¿Puede E3 sustituir a E1?

- **(i) «Existía entera antes del reto».** **[derivado]** Parciales durante `M` con retos
  impredecibles obligan a poseer el lote durante `M`… o a pagar `N/(r·w)` CPU. **Es una garantía
  económica, no criptográfica y no temporal**: no fecha el cálculo y no cubre los bytes; y si el
  atacante tiene GPU (escenario 17×, no medido) o un kernel mejor, la cota se erosiona. **No
  sustituye a E1** para esta afirmación. El sembrador de `P-SEMBRADOR` **sigue abierto**.
- **(ii) «Sigue existiendo».** **[derivado]** Sí, como **cota económica**: obliga a almacenar
  `max(0, 1 − r·w/N)` del lote o a pagar `N/(r·w)` CPU continuas; a la ventana medida, un lote de
  1 TiB exige **82,9 %** almacenado (88,5 % con la ventana reducida por VDF), y almacenar es ~100×
  más barato en hardware que regenerar. Con la salvedad de que **todas** las parciales deben quedar
  ligadas y de que la garantía es de hardware, no de criptografía.
- **¿Qué le pasa al sembrador con un lote registrado pero no almacenado?** **[derivado]** Con
  `PlotBatchId` bien derivado, no puede responder sin generarlo: paga `max(0,1−r·w/N)` de espacio o
  `N/(r·w)` CPU. Pero **nada prueba que lo generara antes del reto**; si su hardware mejora o `w`
  crece, el ataque revive. Sin E1/E4, es una **tarifa**, no un cierre.

### F4 · Interacción con el resto del paquete

**[derivado, en periodos, nunca en moneda]**

| Esquema | Detección del borrado | Retención mínima por **tiempo** | Lo que pide al registro |
|---|---|---|---|
| E2 | inmediata si no responde (1 auditoría) | `D_a` + ventana de finalidad | raíz del lote y calendario de auditorías |
| E3 | `T` periodos (1–268 según lote y `s`) | `T` + `F/P` periodos | contador/compromiso por lote y periodo; política de cadena |
| E5 | `−ln(β)/(σλ)` slots (691 con `σ=10⁻²`) | finalidad `F` | ninguno |

`P=100` y `F=7.200` dan `F/P = 72` periodos de retención por finalidad. **El importe** `ρ_ret` es
una entrada monetaria que **este informe no fija** (ver `DECISIONES-PENDIENTES.md`). El
`PlotBatchId` debe ligar codificación, clave y lote, o los mismos bytes se re-registran tras un
castigo: hoy `SectorId` liga clave, índice e historia (`sectors.rs:54-68`) y `derive_piece_index`
liga offset e historia (`:70-114`), pero **no** hay alta previa ni fecha (`P-SEMBRADOR` §Fase 1).

### F5 · Recomendación (propia, no decisión de Katana)

**[propuesta]** **No adoptar E2 como prueba de permanencia.** **Adoptar E3 solo como capa
económica de permanencia (ii), nunca como sustituto de E1**, con estas condiciones: (1) **todas**
las parciales del lote quedan ligadas por periodo —nada de muestrear posiciones predecibles—; (2)
`w` se mantiene corto (la segunda línea VDF lo reduce, y ayuda); (3) el umbral `K` se recalibra por
disponibilidad declarada `a`, o el honesto cae por falso fallo; (4) se mide el coste adversarial
real (GPU, SIMD) antes de declarar ninguna garantía, porque `r=25,03` es cota superior. **E1/E4
siguen siendo el único cierre criptográfico de (i)**, y hoy **no existen** para este formato. Lo que
cierra E3: la permanencia como cota económica. Lo que paga: bytes en cadena y falsos fallos del
honesto. Lo que reabre: la dependencia de `w` y del hardware, y el hueco C1 intacto. Si el
escenario GPU `17×` se confirma, **E3 no expulsa a un atacante con una GPU para lotes pequeños**, y
ese es el resultado.

---

## 4 · Tabla comparativa (misma ficha, mismo escenario)

| | E1 cobertura | E2 muestreo | E3 parciales | E4 sellado | E5 farmear |
|---|---|---|---|---|---|
| **Demuestra (i) existencia previa** | sí, si existiera | no | no (económico) | sí, condicional | no |
| **Demuestra (ii) permanencia** | sí (criptográfica) | no | sí (económica) | sí (económica) | no |
| **Mide tamaño** | sí, exacto | no | sí, estadístico | no | no |
| **Coste tramposo / TiB (w=7.175)** | 235,6 h·núcleo (comprometer) | `c` tablas/auditoría (∝0) | **5,84 CPU** | sellado ≈ ventana | **5,84 CPU** si farmea; 0 si solo cobra |
| **Escala con `N`** | sí | **no** | sí | sí | sí (si farmea) |
| **Bytes en cadena / lote·periodo** | alta + prueba | `c·b` (o `k·b`) | `λ·b` (2.097 B a λ=10,5) | prueba sucinta | 0 |
| **Falso fallo honesto `a<1`** | no aplica | `1−a` por auditoría | `P(Poisson(aλ)≤K)`; 5,2×β con `a=0,99` | no aplica | `e^{−σλT}` |
| **Madurez** | por inventar | desplegado (Filecoin) | parcial (Chia, otro fin) | desplegado (Filecoin) | desplegado |
| **Cambia la parcela** | sí | no | umbral + prueba | sí | no |
| **Cierra el sembrador** | sí (si existiera) | no | no | condicional | no |

---

## 5 · Garantías: qué es criptográfico y qué económico

**[demostrado dentro del modelo]** Todo lo cuantitativo de este informe es **económico**: cotas de
coste en núcleos, GPUs o bytes, condicionadas a `w` y al hardware del atacante. **Nada de E2/E3/E5
es criptográfico.** La única familia que da garantía criptográfica de existencia previa es E1, y no
existe para este formato; E4 la daría con rediseño. Presentar una cota económica con lenguaje de
cobertura sería exactamente lo que el encargo prohíbe.

**Qué lo vuelve imposible y qué solo caro** (modelo de amenaza de Katana, obligatorio):

| Esquema | ¿Imposible o solo caro? | Coste absoluto por TiB simulado | Qué lo rompería |
|---|---|---|---|
| E1 cobertura | **Imposible hoy para el atacante**, porque la prueba **no existe** | — | Que se construya y despliegue |
| E2 muestreo | **Solo caro, y poco**: `c` tablas por auditoría | 0 (no depende de `N`) | 4 CPU, o una GPU, o usar `w` |
| E3 parciales (todas ligadas) | **Solo caro**: 5,84 CPU/TiB a `w=7.175` | **5,84 CPU/TiB**; 0,343 GPU/TiB en el escenario `17×` | `w≳8,4·10⁵` slots, GPU medida, kernel mejor |
| E4 sellado | **Imposible si** el sellado adversarial > `w` y no hay atajo (no demostrado) | sellado ≈ ventana por lote | Sellado acelerado por hardware |
| E5 farmear | **Solo caro para farmear** (mismo 5,84 CPU/TiB); **gratis si solo cobra retenido y nadie audita** | 5,84 CPU/TiB si farmea; 0 si abandona | Auditorías; hardware mejor |

**Ninguna pieza de este estudio vuelve la trampa *imposible***; todas la vuelven *cara*, y la única
familia que podría volverla imposible (un compromiso criptográfico del cálculo caro, E1/E4) **no
existe** para el formato fijado. Esa es la conclusión de seguridad que hay que declarar, sin
adjetivos de cobertura.

---

## 6 · Lo que esta investigación NO resuelve

- **El valor real de `w`**: es un símbolo. P-REVELACION mide 7.175–8.030 (sin VDF) y 4.830,6 a
  `ρ=2,5` (con VDF); el modelo barre de 1 a 10⁶.
- **El coste mínimo del ataque**: `r=25,03` es el mejor agregado medido del código de Autonomys tal
  cual, **cota superior**; un kernel SIMD/GPU/ASIC no se ha medido.
- **La GPU**: no medida en ningún encargo; el `17×` es **documentación ajena**. Sin él, la garantía
  de E3 se sostiene; con él, se anula por debajo de ~2,9 TiB por GPU. **Esta es la bifurcación
  principal.**
- **Si `b` (bytes por parcial) y los bytes en cadena caben**: el tamaño de bloque y el calendario
  son parámetros de consenso que no se fijan.
- **`π_DAG`** y la varianza real del DAG de ZEROX.
- **La integración de E3 con `M`, `ρ_ret` y `T_v`**: son entradas.
- **La existencia de una prueba sucinta de cobertura completa** para el formato fijado: solo se
  concluye «no se ha encontrado», nunca «no puede existir».
- **El modelo de trampa con ventana como cota inferior**: se usó como cota **superior** del coste
  del atacante, tal como el encargo indicó; un atacante mejor la baja.
- **La verificación en el cuerpo** de PDP, PoR compacto, PoReps y KZG: se citan por su resumen o su
  especificación oficial, y así se etiquetan.

---

## 7 · Reproducción

```bash
cd /home/katana/zeo/ZEROX
LC_ALL=C sha256sum -c P-ZRX/P-PERMANENCIA/ENTRADA.sha256
cd P-ZRX/P-PERMANENCIA/investigacion/veritas/almacenamiento/permanencia-v1
export JULIA_DEPOT_PATH="$PWD/../../.julia-depot:/home/katana/.julia"
JULIA_NUM_THREADS=4 OPENBLAS_NUM_THREADS=1 \
  /home/katana/zeo/ZEROX/veritas/julia.sh --project=. test/runtests.jl    # 51 comprobaciones
JULIA_NUM_THREADS=4 OPENBLAS_NUM_THREADS=1 \
  /home/katana/zeo/ZEROX/veritas/julia.sh --project=. bench/benchmarks.jl # tabla de rendimiento
./correr-modelo.sh                                                        # barridos publicados
```

Artefactos: `resultados/E3-ventana.tsv`, `E2-plazo.tsv`, `E3-estadistica.tsv`,
`E3-agregacion.tsv`, `E5-deteccion.tsv`, `E1-E4-coste.tsv`, `VALIDACION.txt`, `BENCH.txt`,
`JET-concreto.txt`. Hipótesis falsables: `HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md`. Bitácora y
huellas: `PROGRESO.md`. Bifurcaciones para Katana: `DECISIONES-PENDIENTES.md`.
