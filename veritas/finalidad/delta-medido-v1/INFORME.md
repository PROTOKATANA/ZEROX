# Δ medido en red sintética P2P — `delta-medido-v1`

**Categoría:** finalidad (la carpeta destino es `veritas/finalidad/`), porque Δ es el parámetro
del que dependen la carrera nominal R0 y la seguridad del pago en T1; la medición en sí es de
red. **Revisión 2 (2026-09-13)** — enmienda de sesgo declarada, decisión de Katana del
2026-09-13 (TAREAS.md §3.1) y medición r2 con los objetos del presupuesto Q2; detalle en
`ENMIENDA-R2.md`. Estado: **esto mide, no decide, no congela, no migra**. Ninguna cifra de este
informe es `MR`, ninguna queda «adoptada» ni «lista para SPEC».

---

## 1. Encargo y alcance

Tarea 3.1 de `TAREAS.md` («**`Δ` sin medir**»): «MIGRACION: "la primera medición que el diseño
necesita". Casi todo lo demás se calibra contra él». El «Orden recomendado» la pone primera:
«**`Δ` (3.1)** desde ya — es medición, no diseño, y desbloquea el nivel 3 entero».

Fila `Delta` de MIGRACION.md: «Sin medir en una red ZEROX con DAG; 4/16/20 s son escenarios».
Fila `Δ` de `veritas/finalidad/baseline-30m/MODELO.md` §3.2: «Sin valor físico medido; 4/8/16/20 s
entre los escenarios históricos. Retardo sintético creación→disponibilidad honesta, no RTT ni
espera de pago» — y su §2: **no hay ningún resultado `MR` disponible para Δ**.

Hasta hoy, en todas las simulaciones del repo (d8, d9-ronda9a, d9-ronda11a), Δ entró como
**constante fijada a mano**: `d8_lib.py:113/161` (`llega[bid] = t + DELTA`), escenarios
4/8/12/16/20/24/32 s en `d9-ronda11a/informe.md` §C.1. Esta auditoría cierra esa brecha con un
**modelo de red explícito** (topología, latencia por enlace, ancho de banda, tamaño de bloque,
inundación hop-by-hop) y **mide** Δ dentro de ese modelo, con etiquetas de procedencia honestas.

Alcance declarado: N ∈ {100, 1000, 10000}, dos topologías, 12 réplicas por combinación,
horizonte de creación 600 s con λ=1. Δ = tiempo desde la creación de un bloque honesto hasta
que la fracción q ∈ {50, 90, 99, 100} de los nodos honestos lo ha recibido íntegro.

## 2. Modelo de red

Cada supuesto lleva su etiqueta de procedencia (MODELO.md §2): **E** elección/referencia del
SPEC, **H** hipótesis de escenario, **MS** medida en simulación concreta, **MH** medida en
hardware, **MR** medida en red ZEROX (ninguna disponible), **D** derivada, **C** candidato,
**P** pendiente.

| Eje | Supuesto | Etiqueta y fuente |
|---|---|---|
| Topología | Grafo aleatorio **d-regular** (d=8) por configuración + conmutación de aristas (30·E conmutaciones), y **G(n,p)** Erdős–Rényi con p = d/(n−1), re-muestreados hasta conectividad | **H** (elección de escenario del instrumento). d=8: número de pares típico de un nodo P2P (Bitcoin/Kaspa usan ~8 salientes); sin medición ZEROX. Regular: grado acotado realista; ER: grado variable (cola) — barridos para ver el efecto |
| N nodos | 100 / 1000 / 10000, 100 % honestos | **H** (escenarios; no existe red ZEROX). La fracción que no reenvía queda como trabajo futuro (§8) |
| Latencia por enlace | Lognormal **por enlace no dirigido**, mediana 80 ms, p99 500 ms; una muestra por arista, fija en la corrida | **H**. Precedente en el repo: `d8-ronda11b/r11b_lib.py:240-242` modela retardo honesto con cola lognormal. Mediana 80 ms/p99 500 ms: orden de magnitud típico de latencias de internet entre nodos; no es una observación de la red destino. Barrido: mediana 30/80/200 ms |
| Ancho de banda | Subida por nodo 10 Mbit/s base; barrido 2/10/50 Mbit/s | **H**. 50 Mbps es el equipo supuesto del «Modelo B350» (`ZEROX-EN-NUMEROS.md` L156); 2 Mbps, escenario conservador residencial; 10 Mbps, intermedio. Sin medición ZEROX |
| Tamaño de bloque | 683 B base; barrido 683 B / 100 kB / 1 MB; caso extra 128 kB | **D** para 683 B: «λΔ=4 puntas simultáneas la cabecera lleva ~4 padres (32 B cada uno): ~683 B» (`research/dag-poas-ancla-de-orden.md` §6, L478; consolidado en `ZEROX-EN-NUMEROS.md` L173). La base PoAS de 556 B es **E** (C-HDR-01) pero no es la cabecera DAG final. 128 kB: tamaño usado en la estimación histórica de red del repo (`dag-poas-informe-52-problemas.md` L42). 1 MB: régimen de carga. **P**: la cabecera DAG definitiva no existe (TAREAS 1.4) |
| Propagación | Inundación (flooding) hop-by-hop: cada nodo reenvía cada bloque una sola vez, al primer recibo, a **todos** sus vecinos; recibo duplicado ignorado | **H** (modelo simplificado de gossip, declarado; el protocolo de red ZEROX no existe, TAREAS 1.4). Semántica heredada del modelo histórico: honestos siempre reenvían |
| Cola de transmisión | **Serial por nodo**: d transmisiones consecutivas de t_tx = 8·tam_bloque/ancho_banda segundos; las de bloques distintos se encolan FIFO | **H** (store-and-forward clásico). Sesgo declarado en §8 |
| Procesado por salto | 0 s base; barrido 0/0,1 s | **H** del escenario 0,1 s: orden de la verificación PoT medida `verify = 96,1 ms/slot` (ancla, «Coste del PoT, MEDIDO», **MH**). Si se adopta «verificar PoT por slot al llegar por gossip» (informe-52 §1a-ii), el coste por bloque es ≪ 0,1 s |
| Creación de bloques | Poisson homogéneo λ = 1/s en [0, 600 s); creador uniforme entre nodos | **E** λ=1/s nominal A″ (SPEC §7.3). El creador dispone del bloque en t=0 de su creación |
| Semántica de Δ | Δ_q(b) = (instante en que ⌈q·n/100⌉ nodos han recibido b) − t_creación(b), q ∈ {50, 90, 99, 100} | Definición de esta medición (**MS**); el creador cuenta con Δ=0 |

Referencias de diseño externas usadas para contexto (no como insumos): rusty-kaspa @ `c338d495`
fija `NETWORK_DELAY_BOUND = 5` s (`consensus/core/src/config/constants.rs:13`) como cota
estimada de retardo para derivar k — **D** upstream. `dagknight.txt` (~L110): «value of 18,
reflecting an assumption of D ≤ 10 seconds» — **D** histórica. La estimación previa del repo
«Δ_p99 ≈ 2–6 s en una red de decenas de nodos con bloques de 128 kB» (informe-52 L42) — **D**
histórica, contrastada en §5 con esta medición.

### 2.1 Sesgo del modelo de propagación (declarado en la revisión 2)

El modelo reenvía el **bloque completo** a **todos** los vecinos (también a quien lo envió), en
serie (`src/rapido.jl:151-158`), y en el caso base el procesado por salto cuesta **0 s**. El
SPEC exige otra cosa en la ruta crítica:

- **R-NET-01 · Relé compacto** (SPEC.md:2509-2511): se anuncia cabecera e identificadores
  cortos; los identificadores usan clave derivada de la cabecera y la sal de transporte
  (R-NET-02, SPEC.md:2513-2514). Un bloque compacto de Q2 mide ≈812 B + 6 B/tx, no la copia
  completa con transacciones.
- **C-NET-12 · Validar antes de retransmitir** (SPEC.md:2496-2498): un bloque recibido por
  difusión MUST validarse contra `zx-consensus` antes de reenviarse; el caso base de este
  modelo (t_proc = 0 s) es por tanto una **cota inferior** de la Δ real, no la Δ.
- **C-NET-06** (SPEC.md:2162-2165): no se emite un anuncio compacto sin validar que la cabecera
  compromete cada transacción y construye sobre un estado verificado.

Consecuencias sobre las cifras (recalificación en §5): el modelo no mide el relé compacto de
ZEROX, sino una inundación de copias completas; tampoco modela el canal de reenvío de
transacciones ni el mempool. Todo lo que dependa de esos supuestos se etiqueta en §5 y §11 como
dependiente del modelo. La r2 (§11) mide objetos de distinto tamaño **con el mismo modelo de
inundación** y declara ese sesgo.

## 3. Método

- **Instrumento:** simulación de eventos discretos en Julia (CPU, sin GPU). Dos motores
  independientes: `referencia.jl` (oráculo legible con escaneo lineal del siguiente evento)
  y `rapido.jl` (heap binario SoA preasignado, 0 asignaciones en el bucle de eventos).
  Equivalencia **bit a bit** validada en instancias pequeñas + casos calculados a mano.
- **Corridas:** barrido principal 2 topologías × 3 N = 6 combinaciones × **12 réplicas**;
  sensibilidad: 11 combinaciones × 12 réplicas a n=1000; casos extra: 128 kB (12 réplicas) y
  1 MB con T=300 s (12 réplicas, control de divergencia). Total 7200+ bloques por combinación
  del barrido principal.
- **Semillas:** maestra `0x5a5a`, derivada por (combo, réplica) con el finalizador splitmix64
  (documentado en `modelo.jl`); cada réplica con su propio `StableRNG`, sin RNG compartido.
  **Determinismo comprobado:** dos ejecuciones idénticas difieren sólo en el tiempo de pared.
- **Paralelismo:** réplicas independientes con `Threads.@threads`; reducción determinista por
  orden de réplica. Escalado medido 1→24 hilos (LINEO §7): ver §7. Se conserva 24.
- **Recortes y por qué:** N máximo 10000 (el paso a N=100000 habría costado ≈10× más: los
  eventos crecen linealmente en N·d·H, ≈ 40 min/1 hilo por corrida, sin ganancia de información
  para el objetivo; N=10000 ya muestra la asíntota). Sin tercera topología small-world: el
  encargo pide ≥2; regular y ER cubren los extremos de grado constante/variable. 12 réplicas
  (el mínimo histórico del repo, p. ej. d9-ronda11a). No se simulan τ/slots ni PoT: Δ es
  tiempo de pared de propagación, no calendario de slots.
- **Presupuesto (declarado antes de ejecutar):** máximo 64 GiB RAM y 24 hilos (topes de la
  máquina). Uso real por réplica < 150 MB; barrido principal en 13,9 s de pared con 24 hilos.

## 4. Resultados

Percentiles del pool de Δ por bloque (≈7200 bloques por combinación, 12 réplicas), en segundos.
Base: d=8, latencia mediana 80 ms / p99 500 ms, 10 Mbit/s, 683 B, sin procesado, λ=1, T=600 s.

| Topología | N | Δ_50 med / p90 / p99 | Δ_90 med / p90 / p99 | Δ_99 med / p90 / p99 | Δ_100 med / p90 / p99 |
|---|---|---|---|---|---|
| regular | 100 | 0,147 / 0,172 / 0,199 | 0,192 / 0,218 / 0,243 | 0,222 / 0,251 / 0,278 | 0,236 / 0,270 / 0,303 |
| regular | 1000 | 0,226 / 0,250 / 0,274 | 0,272 / 0,296 / 0,321 | 0,305 / 0,330 / 0,353 | 0,337 / 0,367 / 0,394 |
| regular | 10000 | 0,304 / 0,328 / 0,352 | 0,350 / 0,374 / 0,399 | 0,384 / 0,408 / 0,433 | 0,440 / 0,474 / 0,519 |
| erdos_renyi | 100 | 0,144 / 0,182 / 0,230 | 0,193 / 0,232 / 0,284 | 0,234 / 0,278 / 0,332 | 0,263 / 0,335 / 0,386 |
| erdos_renyi | 1000 | 0,217 / 0,252 / 0,311 | 0,267 / 0,303 / 0,362 | 0,321 / 0,357 / 0,416 | 0,435 / 0,782 / 1,198 |
| erdos_renyi | 10000 | 0,289 / 0,323 / 0,377 | 0,339 / 0,373 / 0,427 | 0,391 / 0,426 / 0,481 | 0,794 / 1,228 / 2,170 |

Lectura: con bloques de tamaño cabecera y supuestos residenciales, **todo el rango Δ_50..Δ_100
queda por debajo de 0,6 s** en redes regulares y por debajo de ~2,2 s (p99 de Δ_100) en ER
grande. La ER tiene cola más larga en Δ_100 (nodos de grado bajo en la periferia); en Δ_50 es
similar a la regular. Crecer N de 100 a 10000 sube Δ_100 mediano ≈ 0,44→0,79 s (ER) — la
propagación escala con el diámetro (~log N), no con N.

## 5. Comparación con los escenarios históricos

Los escenarios históricos fijaban Δ **constante** en 4/8/12/16/20/24/32 s (`d9-ronda11a/informe.md`
§C.1; MIGRACION fila Delta). Dónde caen estas mediciones (**MS**):

| Medición (Δ_100, mediana) | Valor | ¿A qué escenario histórico corresponde? |
|---|---|---|
| Cabecera 683 B @ 10 Mbit/s, regular, n=10000 | **0,44 s** | Muy por debajo del mínimo histórico (4 s) |
| Cabecera 683 B, ER, n=10000 (p99 de Δ_100) | 2,17 s | Todavía por debajo de 4 s |
| 100 kB @ 10 Mbit/s, regular, n=1000 | 3,05 s | Bajo 4 s, cerca |
| **128 kB @ 10 Mbit/s, regular, n=1000** | **5,13 s** (Δ_50 med 3,62; Δ_100 p90 8,71) | **Dentro de la banda 4–8 s**: el escenario Δ=4 s corresponde a esta carga en el cuantil medio; Δ=8 s cubre su p90 |
| 1 MB @ 10 Mbit/s, n=1000 | divergente (1997 s a T=600; 1026 s a T=300) | Sin correspondencia: régimen saturado, no un Δ finito (§6) |

Conclusiones honestas (las tres quedaron **recalificadas en la r2** — 2026-09-13 — por el sesgo
de modelo de §2.1: no se borran, se declara de qué dependen):

1. Bajo los supuestos de cabecera compacta (683 B) y subida residencial (10 Mbit/s), **Δ medido
   es ~1 orden de magnitud menor que el escenario mínimo histórico de 4 s**: los escenarios
   4–32 s son conservadores respecto a este modelo.
   **Recalificado en r2:** es una cota de un modelo que reenvía copias completas y valida en
   0 s; el relé compacto (R-NET-01) y el coste de validación (C-NET-12) no están modelados, de
   modo que la cifra no se presenta como «la Δ de la red de ZEROX», sino como medida MS del
   modelo de inundación de §2.
2. La banda 4–8 s **no es irrealista**: se alcanza con bloques de ~128 kB a 10 Mbit/s — la
   estimación previa del repo («2–6 s … bloques de 128 kB», informe-52 L42) queda confirmada
   en orden de magnitud por esta medición independiente.
   **Recalificado en r2:** «128 kB corresponde a la banda 4–8 s» es una afirmación **sobre el
   modelo** (mandar 128 kB × 8 pares en serie a 10 Mbit/s). El SPEC no propaga 128 kB por el
   enlace: propaga la cabecera y los IDs cortos. La conclusión vale para la inundación de
   copias completas, no como predicción de la red destino.
3. Los escenarios ≥16 s exigen algo que este modelo base no tiene: bloques grandes con subida
   baja, retardo adversarial, nodos que no reenvían, o coste de validación por salto grande.
   No se afirma que sean imposibles: se afirma que no salen del modelo honesto base.
   **Recalificado en r2:** el caso base usa t_proc = 0 s, que contradice C-NET-12; sólo vale
   como cota inferior. La sensibilidad con t_proc = 0,1 s (§6) y la r2 (§11) cubren parte del
   hueco; el coste real por salto sale del banco en hardware (Q4, TAREAS.md).

## 6. Análisis de sensibilidad

n=1000 regular; un eje cada vez (Δ_100 mediano):

| Eje | Valores | Δ_50 med | Δ_100 med | Efecto |
|---|---|---|---|---|
| Mediana de latencia por enlace | 0,03 / 0,08 / 0,2 s | 0,073 / 0,226 / 0,678 | 0,118 / 0,337 / 0,932 | ~lineal (×2,5 de latencia → ×2,7 de Δ) |
| Ancho de banda (683 B) | 2 / 10 / 50 Mbit/s | 0,275 / 0,226 / 0,217 | 0,402 / 0,337 / 0,325 | Débil a tamaño cabecera (t_tx=2,7 ms → 8 saltos ≈ 0,1 s) |
| Tamaño de bloque (10 Mbit/s) | 683 B / 100 kB / 1 MB | 0,226 / 2,152 / 1141,8 | 0,337 / 3,047 / 1997,7 | **Dominante**: t_tx = 0,55 ms / 80 ms / 800 ms por enlace |
| Retardo de procesado por salto | 0 / 0,1 s | 0,228 / 0,657 | 0,340 / 0,898 | ~0,1 s × nº de saltos (~5,6) |
| N (regular, §4) | 100 / 1000 / 10000 | 0,147 / 0,226 / 0,304 | 0,236 / 0,337 / 0,440 | Logarítmico (diámetro) |
| Topología | regular vs ER (§4) | ±5 % | hasta ×1,8 en cola (ER) | Grado variable alarga Δ_100 |

**Qué domina:** el producto `tam_bloque / ancho_banda` (tiempo de transmisión por enlace)
multiplicado por el grado y λ — la carga de reenvío. A tamaño de cabecera, domina la latencia
por enlace; a partir de ~100 kB, domina la transmisión. El régimen 1 MB está **saturado**:
utilización ρ = λ·d·t_tx = 1·8·0,8 s = 6,4 > 1 → las colas crecen sin cota y Δ diverge con el
horizonte (1997 s a T=600 frente a 1026 s a T=300 — control verificado, no es artefacto).
Es la «cola de los nodos lentos» que el repo ya anticipaba (informe-52 §1a-iii): con bloques
grandes hay que bajar λ, subir ancho de banda o compactar, no esperar que la red lo absorba.
**Recalificado en r2:** la saturación a 1 MB sale de mandar copias completas a 8 pares en
serie; con el relé compacto (R-NET-01) el enlace no ve esos bytes. La r2 (§11) mide el control
de saturación del bloque completo en el techo de Q1 (ρ = 1,0005 a 100 Mbit/s) con el mismo
modelo, y lo publica como evidencia de cola no estacionaria, no como Δ.

Ruido entre réplicas: el combo base repetido 4 veces con semillas distintas da Δ_100 med
0,335 / 0,337 / 0,338 / 0,340 — dispersión ±0,7 %.

## 7. Las 5 preguntas de LINEO §0

1. **Complejidad temporal/espacial y parámetro dominante.** Por corrida: eventos =
   H·(2E+1) ≈ H·N·d; cada evento cuesta O(log P) en el heap con P = bloques en vuelo × N·d ≈
   λ·Δ·N·d; más H ordenamientos de N elementos. Total O(H·N·d·log(λΔNd) + H·N·log N).
   Espacio O(N·H) (matriz de llegadas) + O(λΔNd) (heap) + O(N). **Domina N** (lineal),
   después d. Caso peor usado: N=10000, d=8, H≈600 → 48 M eventos, ~4 s por corrida a 1 hilo.
2. **Perfil de CPU, memoria y asignaciones tras compilar.** `bench/benchmarks.jl` →
   `resultados/BENCH.txt`: kernel con **0 bytes y 0 asignaciones** en la corrida caliente
   (n=20/1000/10000); n=10000 con ~30 bloques en 229 ms. `bench/perfil.jl` →
   `resultados/PERFIL.txt`: tiempo dominado por las operaciones del heap (`pop_evento!`,
   `correr!`); `allocated_bytes=0`. El kernel de una corrida es monohilo; el paralelismo está
   entre réplicas. Escalado (24 réplicas fijas, n=10000): 96,2 / 48,7 / 25,5 / 13,2 / 9,3 /
   6,26 s con 1/2/4/8/16/24 hilos = **15,4× a 24**; la eficiencia cae tras 8 hilos (acceso de
   memoria del heap + hyperthreading) pero 24 gana extremo a extremo → se conserva 24
   (`resultados/escalado/ESCALADO.txt`).
3. **Oráculo contra el que se validó.** `referencia.jl`: motor de eventos con selección por
   escaneo lineal, estructura de datos distinta (Vector de structs), en instancias n ≤ 20; más
   casos **calculados a mano** en los tests: camino de 4 nodos con lat=1 s, t_tx=0 →
   llegadas [0, 1, 2, 3]; estrella con t_tx=0,5 s → [0, 0,5, 1,5, 2,0]; camino con t_tx=0,25 s
   y lat=1 s → [0, 1,25, 2,75, 4,25]; procesado 0,5 s/salto → [0, 1,5, 3,0, 4,5]. Equivalencia
   referencia↔rápido **bit a bit** + invariantes en 9 configuraciones × 3 semillas
   (`validar_equivalencia`). Suite: 25040 asserts en verde en la r1; 25 598 tras la r2 y su
   corrección (§10).
4. **Tipos numéricos y error de redondeo.** Tiempos en Float64; conteos, índices y rangos de
   cuantil en enteros (`cld(q·n, 100)` — la decisión de «cuántos nodos» es discreta, no se
   decide con flotantes). Sin `@fastmath` ni Float32; `@inbounds` sólo tras los tests de
   rangos, con comentario de la prueba. Los casos a mano usan fracciones binarias exactas
   (1/4, 1/2, 1), de modo que la comparación es exacta, no con tolerancia. Error de redondeo
   relativo ≈1e-13 en las sumas: irrelevante frente a los umbrales reportados (0,001 s).
   No hay NaN; Inf = «no recibido», excluido por el invariante de conexidad que se comprueba
   en cada corrida.
5. **Semilla, versión, Manifest, hardware e hilos.** Semilla maestra `0x5a5a`, derivación
   splitmix64 por (combo, réplica), `StableRNGs` por réplica; Julia 1.13.0; `Manifest.toml`
   versionado (BenchmarkTools 1.8.0, DataStructures 0.19.6, Distributions 0.25.131,
   StableRNGs 1.0.4); Ryzen 9 9950X3D (16C/32T), 123 GiB RAM; 24 hilos de cómputo,
   `OPENBLAS_NUM_THREADS=1`; git `f1a10a84e6d8057de2914d608b449c71ae25e959`. Capturado en
   `resultados/*/ENTORNO.txt` junto a tiempos de pared/CPU y `Pkg.status()`.

## 8. Límites conocidos — lo que NO se puede afirmar

- **No hay MR**: no existe una red ZEROX. Todo lo medido es **MS** en un modelo sintético con
  supuestos H explícitos. Ningún valor de aquí es «el Δ de ZEROX».
- **El modelo es una simplificación declarada**: sin pérdida de paquetes/retransmisiones, sin
  churn de nodos, sin colas de recepción, sin coste real de verificación criptográfica, sin
  el protocolo de red ZEROX (que no existe, TAREAS 1.4), sin τ/slots ni PoT.
- **100 % honesto**: no se modela una fracción que no reenvía ni retardo adversarial (los dos
  componentes de la Δ «natural vs adversarial» del informe-52 §2). Trabajo futuro.
- **Cola serial por nodo**: frente a un reparto justo de ancho de banda entre pares, el modelo
  serial entrega las copias tempranas antes (optimista para Δ_50) y la última copia igual
  (d·t_tx en ambos casos). A tamaño de cabecera la diferencia es ≤5 ms; a ≥100 kB el efecto
  es de segundos y se declara, no se disimula.
- **Latencia estática por arista** (una muestra por corrida): no modela jitter temporal.
- **El régimen saturado (ρ>1) es un resultado, no un fallo**: con 1 MB a 1 bloque/s y 10 Mbit/s
  la red física no puede propagar; se verifica con el control de horizonte (§6).
- **La muestra no es un barrido completo del espacio de parámetros**: 2 topologías, 3 N,
  12 réplicas; el barrido «3 topologías × 4 N × 24 réplicas» habría costado ≈4× más
  (~1 h de CPU) sin cambiar el orden de magnitud de las conclusiones.
- Δ mide propagación de un objeto de tamaño `tam_bloque`; no incluye aceptación de pago
  (`t_acept`), ni `D_aut`, ni F, ni L, ni I (símbolos separados en MODELO.md §3.2).
- **La r2 no modela el reenvío de transacciones ni el mempool**: el canal de difusión de
  transacciones (con su retardo de propagación, la «segunda Δ» de Q5/v2a) no existe en este
  modelo; toda la Δ medida es la del canal de bloques. Consecuencia: en el techo de Q1, la
  cuenta pesimista de TAREAS Q1 hace que el reenvío de transacciones ocupe **toda la subida**
  del nodo de referencia (ρ = 1,0 con 100 Mbit/s), de modo que la Δ medida del anuncio
  compacto en el techo (§11) es **optimista** salvo que se cumpla la regla de transporte
  condicionante de Q1 (prioridad de bloques y presupuesto de reenvío de transacciones).
- **El sesgo de §2.1 afecta a todo**: medir objetos «compactos» (812 B, 4 238 B, 27 596 B)
  con un modelo que reenvía el objeto completo a los 8 vecinos en serie no reproduce el relé
  compacto de R-NET-01; a esas tamaños la diferencia de bytes por salto es la misma (el
  objeto transmitido es el mismo), pero no hay competencia con el canal de transacciones ni
  coste de validación, y la cola serial por nodo sigue siendo la del modelo (§8).

## 9. Decisiones de Katana (2026-09-13)

Las cinco preguntas abiertas de la revisión 1 quedaron **decididas por Katana el 2026-09-13**;
la autoridad es `TAREAS.md` §3.1 (preguntas Q1–Q5), donde están el motivo, las fuentes y las
consecuencias completas. Resumen de una o dos líneas por decisión:

1. **Q1 — Ancho de banda de referencia: 100 Mbit/s de SUBIDA** (techo ≈1,56 MB/s por nodo
   con la cuenta pesimista de 8 pares; ≈4 464 tx/s de 350 B). Referencia de planificación por
   política de marketplace, no requisito; ninguna regla la comprueba. Líneas típicas por
   debajo (EE. UU. 59,67 Mbit/s, etc.) no podrán reenviar toda la carga sostenida; el reenvío
   se concentra en los nodos mejor conectados. Condición: una regla de transporte que hoy no
   existe (cola prioritaria para bloques/PoT, presupuesto de reenvío de transacciones,
   reenvío por anuncio y petición).
2. **Q2 — Presupuesto compacto para la ruta crítica:** cabecera ≤ ~1 kB típica (556 B base +
   32 B/padre + 128 B/slot PoT) y ≤ ~20 kB peor caso (16 padres, 150 slots = 20 268 B);
   anuncio compacto ≤ ~28 kB en el techo (27 596 B). Es presupuesto de diseño para 1.4, no
   formato congelado. Relé compacto obligatorio en la ruta crítica.
3. **Q3 — Ningún estadístico único:** la distribución completa de Δ ponderada por espacio
   entra en δ₀; para las reglas temporales duras basta una comprobación de cordura en régimen
   estable (§11.6); valor provisional Δ_99 en su p99 (§11.3, con etiqueta obligatoria); la
   media ponderada por producción es estadístico descriptivo de tamaño (padres típicos).
4. **Q4 — Consenso antes de reenviar, transacciones después; PoT por slot con caché y
   verificación bajo demanda.** El coste por salto queda acotado por construcción; el coste
   real sale de un banco en hardware (paso 2 del orden de Q5).
5. **Q5 — Adversario en un v2 partido:** v2a = red bajo ataque (sin GHOSTDAG); v2b = efecto en
   seguridad (con GHOSTDAG en Julia). Orden: enmienda v1 y migración → banco en hardware →
   v2a → GHOSTDAG (TAREAS 1.3 + 1.2) → v2b.

La r2 de este informe implementa la parte de medición que estas decisiones exigen del v1
(§11); el resto del plan vive en TAREAS.md §3.1 y en el orden recomendado.

## 10. Reproducción

Comandos desde la raíz del repositorio (los mismos que en `METODO.md`).

```bash
# 1. Tests (verde: 25598 asserts)
env -u LD_LIBRARY_PATH veritas/julia.sh \
  --project=veritas/finalidad/delta-medido-v1 --check-bounds=yes \
  veritas/finalidad/delta-medido-v1/test/runtests.jl

# 2. Barrido principal (las tablas de §4)
JULIA_NUM_THREADS=24 OPENBLAS_NUM_THREADS=1 \
  env -u LD_LIBRARY_PATH veritas/julia.sh \
  --project=veritas/finalidad/delta-medido-v1 \
  veritas/finalidad/delta-medido-v1/run.jl

# 3. Sensibilidad (las tablas de §6)
JULIA_NUM_THREADS=24 OPENBLAS_NUM_THREADS=1 \
  env -u LD_LIBRARY_PATH veritas/julia.sh \
  --project=veritas/finalidad/delta-medido-v1 \
  veritas/finalidad/delta-medido-v1/run.jl --sensibilidad

# 4. Benchmark y perfil (BENCH.txt / PERFIL.txt en resultados/)
JULIA_NUM_THREADS=4 OPENBLAS_NUM_THREADS=1 \
  env -u LD_LIBRARY_PATH veritas/julia.sh \
  --project=veritas/finalidad/delta-medido-v1 \
  veritas/finalidad/delta-medido-v1/bench/benchmarks.jl
```

Artefactos en `resultados/`: `barrido-principal/{corridas,resumen}.csv`, `sensibilidad/…`,
`escalado/…`, `extra/` (128 kB y 1 MB-T300), `ENTORNO.txt`, `RUN.txt`, `BENCH.txt`,
`PERFIL.txt`. El `INFORME.md` es la fuente de verdad; los CSV son traza.

Comandos de la r2 (los resultados de §11):

```bash
# 5. Rejilla r2 (5 objetos × 2 anchos × 2 topologías × 3 N; §11.2)
JULIA_NUM_THREADS=24 OPENBLAS_NUM_THREADS=1 \
  env -u LD_LIBRARY_PATH veritas/julia.sh \
  --project=veritas/finalidad/delta-medido-v1 \
  veritas/finalidad/delta-medido-v1/run.jl --r2 --r2-subtarea rejilla

# 6. Hipótesis de concentración de espacio (§11.4)
JULIA_NUM_THREADS=24 OPENBLAS_NUM_THREADS=1 \
  env -u LD_LIBRARY_PATH veritas/julia.sh \
  --project=veritas/finalidad/delta-medido-v1 \
  veritas/finalidad/delta-medido-v1/run.jl --r2 --r2-subtarea concentracion

# 7. Sensibilidad t_proc = 0,1 s (§11.5)
JULIA_NUM_THREADS=24 OPENBLAS_NUM_THREADS=1 \
  env -u LD_LIBRARY_PATH veritas/julia.sh \
  --project=veritas/finalidad/delta-medido-v1 \
  veritas/finalidad/delta-medido-v1/run.jl --r2 --r2-subtarea tproc

# 8. Control de saturación (§11.7; sus cuantiles NO son Δ)
JULIA_NUM_THREADS=24 OPENBLAS_NUM_THREADS=1 \
  env -u LD_LIBRARY_PATH veritas/julia.sh \
  --project=veritas/finalidad/delta-medido-v1 \
  veritas/finalidad/delta-medido-v1/run.jl --r2 --r2-subtarea saturacion
```

Los CSV de la r2 añaden columnas `rho` y `regimen`, y las trazas de medias
(`medias_bloque-<id>.csv`, `medias_nodo-<id>.csv`, y `media_bloque_espacio-<id>.csv` en la
subtarea de concentración). Reproducibilidad r2: dos ejecuciones completas de los cuatro modos
son idénticas salvo `segundos_pared`, `ENTORNO.txt` y `RUN.txt`.

**Trazas no versionadas (2026-09-14).** Las trazas de medias no están en el repositorio. Su
huella está en `TRAZAS.sha256`, y `METODO.md` explica cómo regenerarlas en una copia y
comprobarlas. No regeneres en su sitio: sobrescribe archivos versionados.

---

## 11. Medición r2 (2026-09-13): objetos de Q2, ρ, régimen y medias de llegada

**Procedencia:** todas las cifras de esta sección son **MS** (medidas con este instrumento),
sobre el modelo de §2 con el sesgo declarado en §2.1. Etiquetas heredadas: tamaños **D**
(presupuesto de Q2, TAREAS.md), anchos **E** (decisión Q1), reparto de espacio **H** (sin
datos reales, §11.4). Comandos en §10; derivaciones previas en `ENMIENDA-R2.md` §2;
reproducibilidad: dos ejecuciones idénticas salvo `segundos_pared`.

### 11.1 Base r2

Igual que la r1 (topologías regular y erdos_renyi, d=8, N ∈ {100, 1000, 10000}, latencia
lognormal mediana 80 ms / p99 500 ms, λ=1, T=600 s, 12 réplicas, semilla maestra 0x5a5a)
pero con ancho de banda **100 Mbit/s** (referencia, Q1) y **59,67 Mbit/s** (línea típica de
EE. UU., sensibilidad) y con los objetos del presupuesto de Q2:

| Objeto | Bytes | ρ @100 Mbit/s | ρ @59,67 |
|---|---|---:|---:|
| cabecera: 556 B + 1 padre + 1 slot | 716 | 0,0005 | 0,0008 |
| cabecera: 556 B + 4 padres + 1 slot | 812 | 0,0005 | 0,0009 |
| anuncio compacto, bloque de arranque (571 tx) | 4 238 | 0,0027 | 0,0045 |
| cabecera peor caso (16 padres, 150 slots) | 20 268 | 0,0130 | 0,0217 |
| anuncio compacto en el techo (4 464 tx) | 27 596 | 0,0177 | 0,0296 |
| bloque completo en el techo (CONTROL) | 1 563 212 | 1,0005 | 1,6766 |

ρ = λ·d·t_tx = 1·8·(8·tamaño/ancho); todos los valores redondeados a 4 decimales están
verificados por test (runtests.jl, testset «r2: tamaños de objeto y ρ»). Los cinco objetos
estables tienen ρ<1 (`estable`); el bloque completo del techo es el único `saturado`.

### 11.2 Rejilla estable: Δ_99 p99 por objeto, topología y N

5 objetos × 2 anchos × 2 topologías × 3 N = 60 combos × 12 réplicas; valores del pool
(≈7200 bloques por combo). Δ_99 en su p99, segundos:

| Objeto (B) | ancho | regular n=100 / 1000 / 10000 | erdos_renyi n=100 / 1000 / 10000 |
|---|---|---|---|
| 716 | 100 Mbit/s | 0,266 / 0,342 / 0,416 | 0,318 / 0,397 / 0,455 |
| 716 | 59,67 | 0,266 / 0,343 / 0,419 | 0,325 / 0,391 / 0,459 |
| 812 | 100 Mbit/s | 0,262 / 0,341 / 0,415 | 0,306 / 0,382 / 0,453 |
| 812 | 59,67 | 0,264 / 0,344 / 0,419 | 0,309 / 0,393 / 0,461 |
| 4 238 | 100 Mbit/s | 0,277 / 0,352 / 0,426 | 0,346 / 0,403 / 0,471 |
| 4 238 | 59,67 | 0,276 / 0,356 / 0,435 | 0,341 / 0,412 / 0,477 |
| 20 268 | 100 Mbit/s | 0,293 / 0,383 / 0,472 | 0,374 / 0,447 / 0,519 |
| 20 268 | 59,67 | 0,327 / 0,414 / 0,510 | 0,364 / 0,476 / 0,566 |
| 27 596 | 100 Mbit/s | 0,315 / 0,406 / 0,494 | 0,378 / 0,455 / 0,542 |
| 27 596 | 59,67 | 0,354 / 0,445 / 0,542 | 0,403 / 0,500 / 0,604 |

Lectura: en todo el rango del presupuesto Q2, Δ_99 p99 queda en **0,26–0,60 s**, dominada por
la latencia por enlace más que por t_tx (pasar de 59,67 a 100 Mbit/s mejora ≤ 0,06 s). La ER
tiene cola más larga (grado variable), y crecer N sube Δ como log N (misma pauta que la r1).

### 11.3 Valor provisional de Q3: Δ_99 en su p99

Con la base r2 (**cabecera de 4 padres 812 B a 100 Mbit/s**), el provisional de Q3 es
**0,26–0,45 s** según topología y N (regular: 0,262/0,341/0,415; ER: 0,306/0,382/0,453); el
anuncio de arranque (4 238 B a 100 Mbit/s) da **0,28–0,47 s** (regular: 0,277/0,352/0,426;
ER: 0,346/0,403/0,471); con el anuncio del techo (27 596 B) sube a **0,32–0,54 s**
(regular: 0,315/0,406/0,494; ER: 0,378/0,455/0,542). Valores del pool, `r2-rejilla/resumen.csv`.

> **Etiqueta obligatoria (TAREAS Q3):** Δ_99 en su p99 representa «casi toda la red, casi
> siempre» y sirve para las herramientas históricas que exigen una Δ constante. No es el
> argumento de seguridad: ese es δ₀ medido (TAREAS Q3).

### 11.4 Δ̄ ponderada por producción y padres típicos (Q3)

Δ̄ uniforme (media de llegada por bloque, ponderación de producción uniforme) en la rejilla:
**0,138–0,387 s** según objeto, topología y N (extremos: 812 B regular n=100 → 0,138 s;
27 596 B regular n=10000 → 0,387 s).

Hipótesis de concentración **H** (sin datos reales): «el 10 % de los nodos tiene el 50 % del
espacio» — cuotas enteras (9, 1) sobre los nodos 1..n÷10; la cuota gobierna A LA VEZ quién
crea cada bloque (sorteo ∝ cuota) y el peso de cada observador (media por bloque ponderada).
Regla (i): como los creadores se sortean ∝ cuota, cada bloque ya representa una unidad de
producción y la Δ̄ es la **media simple** de las medias ponderadas por observador (pesar
además por el creador contaría la cuota dos veces; corregido en la validación de Claude,
`ENMIENDA-R2.md` §6). Subconjunto: n=1000, objetos 4 238 B y 27 596 B, 100 Mbit/s, ambas
topologías (12 réplicas):

| Objeto | topología | Δ̄ uniforme | Δ̄ espacio (regla i) | fracción de creadores en el top-10 % |
|---|---|---|---|---|
| 4 238 | regular | 0,2193 | 0,2194 | 0,47–0,55 (esperado 0,50) |
| 4 238 | erdos_renyi | 0,2148 | 0,2146 | 0,47–0,55 |
| 27 596 | regular | 0,2578 | 0,2577 | 0,48–0,54 |
| 27 596 | erdos_renyi | 0,2601 | 0,2566 | 0,47–0,53 |

En grafos aleatorios (regular y Erdős–Rényi) los nodos son intercambiables, así que
concentrar el espacio por número de nodo —sin relación con la posición en la red— deja Δ̄
igual **por construcción** (las diferencias medidas son del ruido del estimador, ≤1,4 %). La
subtarea comprueba el estimador, no el efecto de concentrar el espacio. La hipótesis
relevante —espacio correlacionado con la centralidad— queda como entrada del **v2b** y no se
implementa aquí.

**Padres típicos derivados ≈ 1 + λ·Δ̄** (etiqueta **D**, estadístico DESCRIPTIVO de tamaño,
no de seguridad): con Δ̄ ∈ [0,138; 0,387] → **1,14–1,39 padres** en el régimen estable de la
rejilla r2 (los «~4 padres» históricos del ancla se estimaron con Δ = 4 s; aquí la Δ̄ medida
es un orden menor).

### 11.5 Sensibilidad t_proc = 0,1 s (cota superior de Q4, opción descartada)

Objeto 4 238 B, 100 Mbit/s, n=1000, ambas topologías, t_proc = 0,1 s por salto (la opción de
verificar el PoT en cada bloque que Q4 descartó; el coste real por salto sale del banco en
hardware): Δ_99 p99 = **0,902 s** (regular) y **1,014 s** (ER), frente a 0,352 / 0,403 con
t_proc = 0. El incremento ≈ 0,55–0,61 s ≈ 0,1 s × ~5,6 saltos, coherente con la r1 §6. Con la
decisión Q4 (PoT por slot con caché, consenso antes de reenviar), el coste por bloque en la
ruta crítica no es este: es la validación de cabecera/pruebas, pendiente del banco en
hardware.

### 11.6 Comprobación de cordura (Q3, reglas duras)

Máxima Δ_100 observada en **todas** las corridas de régimen estable (r1 y r2), frente a
S_max/10 = 15 s y F = 7 200 s:

| Conjunto | Máx Δ_100 (s) |
|---|---:|
| r1 barrido (683 B @ 10 Mbit/s, estable) | 2,41 |
| r1 sensibilidad sin 1 MB (incl. 100 kB @ 10 Mbit/s) | 8,63 |
| r2 rejilla completa (estable) | 2,32 |
| r2 concentración (estable) | 0,88 |
| r2 t_proc = 0,1 s (estable) | 1,40 |

**Máximo estable conjunto: 8,63 s < 15 s = S_max/10 ≪ 7 200 s = F.** La red da abasto con la
carga en régimen estable. (El caso saturado se lista aparte, §11.7, y no participa: por eso
la comprobación exige régimen estable, TAREAS Q3.)

### 11.7 Control de saturación: bloque completo en el techo (evidencia, NO Δ)

1 563 212 B, regular, n=1000, 100 Mbit/s, T=300 y T=600, 12 réplicas. ρ = 1,0005 → saturado.
**Sus cuantiles NO se publican como Δ**: se publican como evidencia de que la cola no es
estacionaria (Δ crece con el horizonte):

| Horizonte | Δ̄ (s) | Δ_50 med (s) | Δ_99 p99 (s) | Δ_100 med / máx (s) |
|---|---:|---:|---:|---:|
| T=300 | 9,27 | 8,79 | 33,89 | 12,29 / 43,08 |
| T=600 | 18,10 | 17,25 | 63,19 | 24,09 / 79,11 |

Todas las cifras crecen al duplicar el horizonte: la cola no es estacionaria, como exige la
cuenta pesimista de Q2 (ρ = 1,0005 en el techo). El bloque completo del techo **no puede
propagarse en régimen** por la subida del nodo de referencia; el anuncio compacto (§11.2) sí.
(La r1 con 1 MB @ 10 Mbit/s dio ρ = 6,4 y Δ_100 máx 3 428,7 s: divergente, mismo fenómeno con
mayor margen.)

