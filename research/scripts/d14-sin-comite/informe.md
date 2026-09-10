# D14C — Inventario de irreversibilidad SIN comité para ZEROX

**Fecha:** 2026-09-10 · **Ronda:** 14C (14A = DAGKNIGHT, 14B = instancias de comité).
**Restricción vinculante de Katana (2026-09-10):** «Descarta todas aquellas opciones que impliquen
un comité central que tome decisiones; busco descentralización y seguridad.»
**Prioridad declarada:** bajar el tiempo de irreversibilidad lo más posible.
**Encargo:** inventariar mecanismos de irreversibilidad/finalidad que **no usen comité de decisión**
—ni fijo ni muestreado como subconjunto que decide— con fuente primaria, tiempo, supuestos, si
exigen dinero y viabilidad en ZEROX (PoAS + DAG GHOSTDAG, sin staking).
**Alcance:** la ronda 14A ya estudió DAGKNIGHT y no se repite; se usa como referencia. No se tocó
ningún fichero fuera de `research/scripts/d14-sin-comite/`. No se ejecutó git (instrucción de la
ronda; `METODO-AGENTES.md:6` pide commit por punto: queda como la única desviación del método).

---

## 0 · Definiciones y método

**Irreversibilidad operativa.** Segundos desde que un bloque entra en la cadena hasta que no puede
salir de ella: (a) **determinista** si una regla del protocolo lo prohíbe (finalidad por regla), o
(b) **probabilista** si la probabilidad de salir es menor que `ε`, bajo un adversario declarado `α`.
Las dos cosas no son intercambiables y la tabla las separa.

**«Comité» para esta ronda.** Conjunto de participantes, fijo o muestreado, cuyos votos/firmas
**deciden** el resultado de consenso. Quedan fuera por la restricción: BFT con validador
registrado, comités por sortición (Algorand, P-040/F3), conjuntos de validadores con stake
(Avalanche desplegado) y el acelerador+comité de Thunderella. **No** son comité: una regla de
selección de cadena que cada nodo evalúa localmente (GHOSTDAG, PHANTOM, SPECTRE, DAGKNIGHT,
Prism) ni el timelord, que es una carrera determinista sin coordinación.

**Método.** Solo fuentes primarias: papers descargados a `fuentes/` (Prism arXiv:1810.08092v4,
Thunderella ePrint 2017/913, Avalanche arXiv:1906.08936v2, Chia Green Paper 12-jun-2026), fuentes
locales ya verificadas (`research/fuentes/`) y código de Autonomys en
`/home/katana/zeo/fuentes/subspace`. Los números propios están en `calcula_numeros.py`
(`salida_numeros.txt`), aritmética sobre constantes publicadas, no simulación. Etiquetas:
DEMOSTRADO / VERIFICADO / PLAUSIBLE / REFUTADO / LAGUNA.

**Control positivo.** No aplica: esta ronda es inventario, no medición estocástica. Los números
medidos que se citan vienen de las rondas 9c, 10c, 12, 13 y 14A, con su propio control.

---

## 1 · Resumen ejecutivo

1. **Sin comité no existe finalidad determinista rápida, y no es una carencia de ingeniería: es un
   teorema.** Lewis-Pye y Roughgarden: *«No protocol is both adaptive and has finality»*
   (`research/fuentes/lewispye-roughgarden-cap.txt:759`). Todo mecanismo permissionless
   (adaptativo) es, por necesidad, probabilista. La única finalidad determinista sin comité es la
   **regla dura de parada** de ZEROX: `C-REORG-07`, 11 999 bloques = **3,33 h** (`SPEC.md:1797-1804`,
   `:1514`).
2. **Lo más rápido sin comité y con orden total es DAGKNIGHT**, ya medido en ZEROX por 14A:
   **4-17 s** de media a `ε=0,05`, mínimo **0,36 s**; pero el atacante puede inflar `k*` y devolver
   el suelo a **90-250 s** (`research/scripts/d14-dagknight/informe.md:127-130, 179-183`). El
   DAGKNIGHT completo (rank + tie-breaking) no está implementado: **LAGUNA**.
3. **Avalanche cae bajo la prohibición.** No es un comité fijo, pero la muestra aleatoria de `k`
   nodos **es** el subconjunto que decide; sin registro ni Sybil-control, el atacante llena la
   muestra, y ponderarla por espacio exige una tabla determinista (el comité muestreado de P-040).
   Además el despliegue real exige **2 000 AVAX** de stake por validador
   (`docs.avax.network/docs/primary-network`, 2026-09-10). **REFUTADO.**
4. **Thunderella cae por diseño:** camino rápido = **acelerador + comité** con 3/4 honestos; el
   fallback es la cadena lenta (`fuentes/thunderella-2017-913.txt:155-179`). **REFUTADO** por la
   restricción.
5. **Prism es líderless y sin comité, pero su finalidad rápida es para transacciones honestas sin
   doble gasto**; la latencia de un doble gasto **crece y puede superar a la cadena más larga** al
   acercarse `β=0,5` (`fuentes/prism-1810.08092.txt:1413-1425`). Su cota teórica con `D=4 s` es
   **7,1 h** a `β=0,25` (constantes del paper, muy holgadas). Portarlo a PoAS no está analizado y
   sufre el doble dipping. **LAGUNA**, no recomendado para v1.
6. **El PoT/VDF no da finalidad: da reloj y anti-long-range.** Chia demuestra que sin el componente
   temporal el espacio solo no es seguro (`fuentes/chia-greenpaper-20260612.txt:1324-1330`, cita a
   Baig-Pietrzak). La confirmación sigue siendo probabilista por profundidad (ecs. 13/17,
   `:1260-1330`). Es ortogonal, ya está en el diseño y **no baja el suelo**.
7. **P-040/F3 —la recomendación de las rondas 12-14B— queda excluida por la restricción nueva**:
   su comité es por sorteo ponderado derivado del espacio (R-FIN-16, `K=4 000`). No se refuta su
   técnica; se cae por decisión de Katana. Lo mismo vale para BFT, Algorand, Filecoin F3 y el
   checkpoint firmado único (`C-CHK`).

---

## 2 · Tabla comparativa — ordenada por tiempo de irreversibilidad

«Comité» = conjunto fijo o muestreado que decide. «Encaja» = con PoAS + DAG GHOSTDAG + sin staking
sin rehacer el núcleo. Los tiempos son de la fuente citada; el `α` y los supuestos van en §3.

| # | Mecanismo | T_irrev (normal) | T_irrev (`α` alto / ataque) | Tipo | ¿Comité? | ¿Dinero? | ¿Encaja? | Coste por nodo | Etiqueta |
|---|---|---|---|---|---|---|---|---|---|
| 1 | **C-CHK · checkpoint firmado único** (`SPEC.md:1904-1938`) | **0 s** (una sola vez en la vida de la cadena) | — | Determinista por firma | No (un firmante) | No | Sí, ya en SPEC | Verificación de 1 firma | **REFUTADO** como mecanismo general: centraliza |
| 2 | **Avalanche Snowball/Snowman** (`fuentes/avalanche-1906.08936.txt:63-90`) | **1,35 s** medidos, 3 400 tps (abstract) | Seguridad degrada suave; viveza fuerte solo `f=O(√n)` | Probabilista `ε` | **Sí, muestreado** (`sample(N\u,k)`, `:318-319`) | **Sí en despliegue: 2 000 AVAX** | No sin registro/espacio-peso | `O(1)` msgs/ronda, `O(log n)` rondas; validador 24/7 | **VERIFICADO** el número · **REFUTADO** para ZEROX |
| 3 | **Prism** (`fuentes/prism-1810.08092.txt:1340-1366`) | Cota `c1(β)·D`: con `D=4 s`, **7,1 h** a `β=0,25` y **28,9 h** a `β=0,33` (cota del paper, holgada); la simulación da mucho menos | Doble gasto: la latencia **crece y supera a la cadena más larga** cerca de `β=0,5` (`:1413-1425`) | Probabilista; orden total eventual | **No** | **No** (PoW; en PoAS, doble dipping) | LAGUNA: sin análisis en PoAS | `m` cadenas de votantes (sim: `m=1 000`, 1 bloque/10 s); comunicación alta | **DEMOSTRADO** en su modelo PoW · **LAGUNA** en PoAS |
| 4 | **Thunderella** (`fuentes/thunderella-2017-913.txt:14-22, 155-179`) | «Instantáneo» = retardo real de red (camino rápido) | Fallback a cadena lenta; consistencia con 1/2 honesto + comité | Determinista en el camino rápido | **Sí: acelerador + comité 3/4** | No en el paper PoW, pero el comité hay que elegirlo | No | Comité + mensajes BFT; líder designado | **DEMOSTRADO** en su modelo · **REFUTADO** por la restricción |
| 5 | **Comités BFT** (Tendermint, HotStuff-2, GRANDPA, Casper FFG) | **2-6 retardos de red** (segundos) | La seguridad se mantiene; la viveza se para | Determinista | **Sí, fijo/registrado** | **Sí: depósito + slashing** | No sin registro | Validador 24/7, BLS, comunicación lineal/BA | **DEMOSTRADO** · **REFUTADO** para ZEROX (ronda 13) |
| 6 | **DAGKNIGHT** (referencia 14A) | **4-17 s** media a `ε=0,05`; mínimo **0,36 s**; a `ε=10⁻¹²`, 16-109 s | Ataque de inflación de `k*`: `Δ≥16` → suelo **90-250 s**; `Δ≤4` la ganancia sobrevive | Probabilista; cliente fija `ε` | **No** | **No** | **Sí** (sustituye la regla de orden) | Cómputo del k-cluster; sin certificado; no medido en ZEROX | **DEMOSTRADO** en su modelo · **VERIFICADO** en ZEROX sano · **REFUTADO** el `k*` crudo · **LAGUNA** el completo |
| 7 | **SPECTRE** (`fuentes/phantom-ghostdag.txt:824-837, 917-932`) | **21 s** en el ejemplo del paper | Orden solo por pares; sin orden total (ciclos de Condorcet) | Probabilista | **No** | **No** | No: no da orden total para UTXO | Orden por pares, barato | **DEMOSTRADO** · **REFUTADO** como núcleo |
| 8 | **P-040 / F3-style** (`research/dag-poas-capa-finalidad.md`) | **~30 s** normal (certificado cada 30 s) | `α=0,33`: **se para el 41 %** de instancias; fallback `F=2 h` | Determinista mientras vive | **Sí, muestreado por espacio** (sorteo ponderado, `K=4 000`) | No por adelantado; quema recompensa no madura | Sí, diseñada para esto | 0,76 GB/año certificados BLS; tabla de poder | **PLAUSIBLE** · **EXCLUIDO** por la restricción nueva |
| 9 | **GHOSTDAG/PHANTOM (baseline)** (`fuentes/phantom-ghostdag.txt:824-837`; 10c) | **45 s** ejemplo del paper; ZEROX: suelo **100-134 s**, medido 97-146 s; comerciante a `10⁻¹²`: **241-871 s** | `α=0,33` pesimista: **2 931 s** a `10⁻¹²`; riesgo 1,5e-6 a 600 s y 7,1e-36 a 1 800 s | Probabilista | **No** | **No** | Es el núcleo actual | Cabeceras 21,5 GB/año; PoT 9,6 % de núcleo | **VERIFICADO** |
| 10 | **Profundidad anclada al PoT/VDF** (Chia/Autonomys/Filecoin) | Chia ~**30 s**/bloque × profundidad; Autonomys **6 s**/bloque × profundidad; Filecoin EC **7,5 h** | Chia: `space_h·vdf_h > space_a·vdf_a·1,47` → honesto ≥ **59,5 %** con VDF iguales | Probabilista (el VDF no finaliza) | **No** (timelord permisionless) | **No** | Sí: el PoT ya está en PoAS | Verificación PoT 96,1 ms/slot = 9,6 % núcleo; timelord 1 CPU | **DEMOSTRADO** (Chia) · **VERIFICADO** (código) |
| 11 | **Baseline + finalidad dura `C-REORG-07`** (`SPEC.md:1797-1804`) | Regla: **3,33 h** (11 999 bloques a `λ=1`) | Fail-stop: el nodo se detiene, no reorganiza | **Determinista por regla** | **No** | **No** | Es el SPEC vivo | Ninguno nuevo | **VERIFICADO** |

**Lectura.** Las filas 1-5 son las únicas sub-minuto, y **todas** son comité, dinero o firma
central (1) o no dan orden total (7). Las filas 6, 9, 10 y 11 son las que sobreviven a la
restricción; entre ellas, la más rápida es DAGKNIGHT (fila 6), condicionada a la LAGUNA del
protocolo completo. La finalidad determinista sin comité más rápida es la regla dura de 3,33 h
(fila 11).

---

## 3 · Mecanismo por mecanismo

### 3.1 · Confirmación por peso del DAG: GHOSTDAG, PHANTOM, SPECTRE y DAGKNIGHT

**Qué son (2-4 líneas).** GHOSTDAG/PHANTOM ordenan un DAG de bloques con el `k`-cluster: los bloques
azules son los que tienen a lo sumo `k` bloques en su anticono, y la cadena seleccionada crece por
`blue_work` (`research/fuentes/phantom-ghostdag.txt:635-659`). SPECTRE ordena **por pares** usando
el DAG como voto, sin orden total. DAGKNIGHT elige el `k` mínimo adaptativo por vista y deja la
confirmación al cliente (`research/fuentes/dagknight.txt:996-1007`).

**Fuente con línea.**
- GHOSTDAG/PHANTOM: `research/fuentes/phantom-ghostdag.txt:619-634` (usa `Dmax` conocido vía `k`;
  SPECTRE no lo necesita), `:635-659` (definición de `k`), `:810-823` (regla del comerciante),
  `:824-837` (ejemplo: `λ=1`, `2D=7 s`, `k=16`, `α≤0,25`, `ε=0,1 %` → **45 s** GHOSTDAG, **21 s**
  SPECTRE), `:884-893` (Kaspa real: 70,4 % ≤10 s; máximo observado 746 s), `:917-932` (SPECTRE sin
  orden total; PHANTOM sí).
- Cota de *freeloading* `3k+1`: `:1202-1203`; Lema 10: `:1205-1238`; `:1369-1371` (ventaja máxima
  `3k`). Es el origen del suelo `3k/((1−α)λ)`.
- DAGKNIGHT: `research/fuentes/dagknight.txt:996-999` («evaluating the function risk – is done by
  the client locally, outside the context of consensus»), `:1007` (cota optimista), `:1021-1027`
  (pesimista, cota exponencial), `:328-367` (teoremas), `:182-197` (fig. 3: 12/6/1,2 s).

**Tiempo de irreversibilidad.** GHOSTDAG: 45 s en el ejemplo del paper; en ZEROX el suelo publicado
es `3k/((1−α)λ) = 100/120/134,3/150 s` para `α=0,10/0,25/0,33/0,40` con `k=30`, `λ=1`
(`research/dag-poas-catalogo-problemas-ataques.md:63`, D6; medido 97,1-145,8 s en
`d14-dagknight/informe.md:120`). Comerciante a `10⁻¹²`: 241 s (`α=0,10`), 482 s (`α=0,25`), 871 s
(`α=0,33`); pesimista D8: 674 s y 2 931 s (`d13-finalidad/f2-alternativas-latencia.md:84-90`).
SPECTRE: 21 s en el ejemplo, pero **sin orden total** —inservible para un UTXO general—. DAGKNIGHT:
4-17 s (`ε=0,05`), mínimo 0,36 s, 16-109 s (`ε=10⁻¹²`) (`d14-dagknight/informe.md:127-130`).

**Seguridad.** Umbral <50 % de recurso; ZEROX publica 33 % operativo y frontera de flujo único
46,9 % (`Δ` pequeño), 38,3 % a `Δ=16 s`, 32,4 % a `Δ=20 s` (`research/dag-poas-ancla-de-orden.md:156`;
`catalogo:62`, D5). GHOSTDAG necesita `Dmax` conocido y paga no ser responsivo al retardo real
(`phantom-ghostdag.txt:830-837`). DAGKNIGHT no usa parámetro de latencia: el cliente fija su cota
`D` local; en pesimista la cota es exponencial (`dagknight.txt:1021-1027`). **CAP:** los cuatro son
adaptativos y por tanto **sin finalidad** (`lewispye-roughgarden-cap.txt:759`).

**¿Comité?** No. **¿Dinero?** No. **¿Encaja?** GHOSTDAG es el núcleo; DAGKNIGHT lo sustituye sin
capa nueva; SPECTRE no sirve de núcleo. **Coste por nodo.** GHOSTDAG: cabeceras 21,5 GB/año y PoT
9,6 % de núcleo (`catalogo:58,61`); DAGKNIGHT: cómputo del k-cluster, sin certificado, coste en
ZEROX no medido (14A). **Etiquetas:** GHOSTDAG **VERIFICADO**; SPECTRE **REFUTADO** como núcleo;
DAGKNIGHT **VERIFICADO** en red sana, **REFUTADO** el `k*` crudo, **LAGUNA** el protocolo completo.

**Qué habría que demostrar antes de escribirlo (DAGKNIGHT).** (i) Implementar Alg. 2/4 completas
con el *rank* y el tie-breaking que mitiga la inflación de `k*` (`dagknight.txt:823-840`), no
implementado en 14A; (ii) re-derivar R-FIN-6, `F`, R-FIN-12 y R-FIN-8′/13′ bajo `k` variable
(`d14-dagknight/informe.md:143-154`); (iii) medir el coste de cómputo con `λ=1` y el `Δ` real (E1);
(iv) el control positivo del paper sigue **LAGUNA** (no publica su regla de cliente).

### 3.2 · Avalanche Snowball/Snowman sobre peso de espacio

**Qué es.** Familia Snow: cada nodo muestrea `k` pares al azar en cada ronda y adopta el color
mayoritario; Snowball añade contadores de confianza y decide tras `β` muestras consecutivas
(`fuentes/avalanche-1906.08936.txt:63-90`). Avalanche lo usa sobre un DAG de transacciones y
Snowman es la variante lineal. Es líderless y metastable.

**Fuente con línea.** `fuentes/avalanche-1906.08936.txt:63-90` (muestreo repetido, estado
«irreversible», `O(1)` mensajes/ronda, `O(log n)` rondas), `:255-274` (Sybil: *«can adopt any Sybil
control mechanism, although proof-of-stake is most aligned»*), `:289-307` (no asume que todos los
miembros se conozcan; discrepancias acotadas en Apéndice A.7; bootstrapping seguro), `:318-319`
(`K := sample(N\u, k)`), `:452-457` (modelo: `n` nodos, `k≤n`). Despliegue: 1,35 s y 3 400 tps
(abstract); stake de 2 000 AVAX por validador (`docs.avax.network/docs/primary-network`,
2026-09-10).

**Tiempo.** 1,35 s medidos en el despliegue del paper. **Seguridad.** Probabilista; la viveza fuerte
exige `f=O(√n)`; la seguridad depende de que la muestra sea mayoritariamente honesta; el protocolo
**no** resuelve Sybil. **¿Comité?** **Sí, en el sentido de la restricción.** No es un comité fijo,
pero el subconjunto muestreado **es** quien decide la preferencia de cada ronda. Sin registro, las
identidades son gratis y el atacante llena la muestra; para ponderar por espacio haría falta una
tabla determinista de pesos —exactamente la R-FIN-15 de P-040—, lo que convierte el sondeo en un
**comité muestreado ponderado por espacio**. **Cae bajo la prohibición.** **¿Dinero?** El protocolo
no tiene slashing, pero el despliegue exige stake para entrar. **¿Encaja?** No sin registro;
**LAGUNA** el híbrido espacio-ponderado, y aun así sería comité. **Coste por nodo:** `O(1)`
mensajes/ronda, `O(log n)` rondas, estado ligero; validador con stake y 24/7 en la práctica.
**Etiqueta: VERIFICADO** el número · **REFUTADO** para ZEROX por restricción y por Sybil.

**Respuesta directa a las preguntas del encargo.** ¿Es comité o sondeo abierto? Es un **sondeo
abierto con muestra aleatoria**: cualquier nodo puede preguntar, pero la decisión efectiva la toma
el subconjunto muestreado. ¿Cómo se muestrea sin registro? En el paper, de `N\u` (el conjunto
conocido de pares) con *bootstrapping* seguro; sin registro, `N` es el *peer set* de gossip, que es
atacable por Sybil. ¿Se puede usar el espacio como peso sin tabla fija? No de forma limpia: la única
fuente de peso verificable sin registro son los bloques ya en el DAG, y el atacante controla parte
de ese DAG; derivar la muestra de ahí reabre el sesgo de ancla. **Conclusión: no sobrevive.**

### 3.3 · Prism

**Qué es.** Protocolo PoW **líderless y sin comité** que descompone la blockchain en tres
funcionalidades (proponer, votar, ordenar) sobre un árbol de proponentes y `m` cadenas de votantes;
confirma una **lista** de ledgers candidatos y da orden total **eventual** (`fuentes/prism-1810.08092.txt:24-33`).

**Fuente con línea.** `fuentes/prism-1810.08092.txt:24-33` (abstract: β<50 %, throughput óptimo,
latencia ∝ `D`, orden total eventual), `:153-163` (contribución principal), `:1240-1284`
(constantes `c1(β)`, `c2(β)`), `:1340-1366` (Teorema 4.8), `:1380-1425` (simulaciones y doble
gasto), `:1443-1453` (ataque de censura, +15-20 s).

**Tiempo.** `E[τ] < max(c1(β)·D, c2(β)·(Bv/C)·ln(1/ε))` (Teorema 4.8). Evaluado en ZEROX con
`D=4 s`: `c1(0,25)≈6 404` → **7,12 h**; `c1(0,33)≈26 044` → **28,94 h** (`calcula_numeros.py`). El
paper avisa que las constantes son holgadas y su simulación (`D=1 s`, `m=1 000`, 1 bloque/10 s)
da valores mucho menores, pero **no publica el número exacto** en el texto: **LAGUNA**. En el
ataque de balanceo la latencia honesta se multiplica por ~2; la de un **doble gasto crece y puede
superar a la cadena más larga** al acercarse `β=0,5` (`:1413-1425`).

**Seguridad.** β<50 % en PoW; el modelo asume el proceso de Poisson de bloques; **no hay análisis
bajo PoSpace** y el doble dipping multiplicaría al adversario (Chia: ×1,47 con contramedida,
`chia-greenpaper-20260612.txt:178-199`). **¿Comité?** No. **¿Dinero?** No. **¿Encaja?** La
asignación de roles por hash es portable, pero la contramedida de aleatoriedad correlacionada de
Chia no encaja en la estructura de Prism; **LAGUNA**. **Coste por nodo:** `m` cadenas de votantes
(sim: 1 000), tasa de bloque alta y ancho de banda; en ZEROX `λ=1/s` el coste no está medido.
**Etiqueta: DEMOSTRADO** en su modelo PoW · **LAGUNA** en PoAS · **REFUTADO** como mecanismo de
finalidad de transacciones en conflicto (el doble gasto degrada al baseline).

### 3.4 · Thunderella

**Qué es.** Camino rápido asíncrono (acelerador + comité que firma) y camino lento síncrono
(cadena de bloques). Con 3/4 honestos y acelerador honesto, confirma tan rápido como el retardo
real de red; si algo falla, cae a la cadena lenta con mayoría honesta
(`fuentes/thunderella-2017-913.txt:14-22`).

**Fuente con línea.** `fuentes/thunderella-2017-913.txt:155-179` (camino rápido: líder + comité,
>3/4 de firmas = notarizado), `:216-241` (selección de comité: todos, submuestra por oráculo
aleatorio, o «recent miners»/«stakeholders»), `:311-313` (el 3/4 es ajustado), `:14-22` (abstract).

**Tiempo.** «Instantáneo» = retardo real de red en el camino rápido. **Seguridad.** Consistencia
con 1/2 honesto + mayoría del comité; viveza optimista con 3/4 + acelerador honesto; fallback
síncrono. **¿Comité?** **Sí: acelerador designado + comité**, y en permissionless el comité se
elige entre mineros recientes (requiere cadena *fair*) o stakeholders. **¿Dinero?** No en el paper
PoW, pero el comité hay que formarlo. **¿Encaja?** No. **Coste por nodo:** mensajes BFT + líder
designado. **Etiqueta: DEMOSTRADO** en su modelo · **REFUTADO** por la restricción (y por el
supuesto 3/4 + *fairness*).

### 3.5 · Finalidad anclada al PoT/VDF

**Qué es.** El PoT (VDF secuencial AES en Autonomys; Wesolowski sobre grupos de clase en Chia) da
un **reloj verificable**: nadie puede computar el futuro más rápido que el tiempo real. Eso impide
la *simulación sin coste* y los ataques de rango largo, y ancla la profundidad de confirmación al
tiempo físico. **No es un mecanismo de acuerdo**: no decide nada por sí mismo.

**Fuente con línea.**
- Chia Green Paper 12-jun-2026 (copia en `fuentes/chia-greenpaper-20260612.txt`): `:178-199`
  (seguridad `space_h·vdf_h > space_a·vdf_a·1,47`; double dipping; solo hace falta **un** timelord
  activo, y puede haber varios), `:216-218` (bloque = 28,125-37,5 s de VDF), `:269-309` (VDF,
  timelords sin recompensa, competición), `:1160-1200` (probabilidad de doble gasto con `k`
  bloques), `:1260-1330` (ecs. 13/17; disponibilidad dinámica; `f>1,47`; PoSpace solo es inseguro,
  cita a Baig-Pietrzak).
- Autonomys (código local): `SLOT_PROBABILITY = (1,6)` → 6 s/bloque
  (`crates/subspace-runtime-primitives/src/lib.rs:48`), `SLOT_DURATION = 1000 ms`
  (`crates/subspace-runtime/src/lib.rs:145`). `confirmation_depth_k = 100` es **profundidad de
  archivado**, no finalidad de usuario (`sc-consensus-subspace/src/archiver.rs:601-603`; la
  finalidad de segmentos es `FINALIZATION_DEPTH_IN_SEGMENTS = 5`, `archiver.rs:82-88`).
- ZEROX: C-TIMELORD-01..04 en `research/timelord-redundancia-informe.md:116-121`: cualquier nodo
  puede ser timelord, sin identidad, permiso ni staking; VDF determinista → competición sin
  coordinación (`:82-88`).
- Filecoin EC: 900 épocas = **7,5 h** de finalización probabilista, y F3 (comité) es lo que la
  bajó a decenas de segundos (`research/fuentes/fip-0086.md:16,21,45,57-58`).

**Tiempo.** El de la profundidad: Chia ~30 s/bloque; Autonomys 6 s/bloque; Filecoin 7,5 h para su
umbral de 900 épocas. En ZEROX, `λ=1/s`: profundidad `d` → `d` segundos, con el mismo suelo
`3k/((1−α)λ)` de GHOSTDAG. **Seguridad.** Chia: honesto ≥59,5 % del producto espacio×VDF con
VDF iguales (1,47/(1+1,47), `calcula_numeros.py`); double dipping ×1,47; disponibilidad dinámica
`f>1,47`. **¿Comité?** No. **¿Dinero?** No. **¿Encaja?** Sí: el PoT ya está en PoAS; el timelord es
una carrera determinista y descentralizable. **Coste por nodo:** verificación de PoT 96,1 ms/slot =
9,6 % de un núcleo (`catalogo:61`, D4); timelord: una CPU rápida. **Etiqueta: DEMOSTRADO** en el
modelo de Chia · **VERIFICADO** en el código de Autonomys · la afirmación «el VDF da finalidad» es
**REFUTADA**.

**Respuesta directa.** ¿Es descentralizable? Sí: al ser el VDF determinista, varios timelords
producen el mismo flujo y no hay nada que acordar; el riesgo residual es de **viveza** (si no
queda ningún timelord, la cadena se para) y se mitiga con checkpoints y arranque sin permiso
(`timelord-redundancia-informe.md:125-130`). ¿Latencia? La de la profundidad; el VDF **no la baja**,
solo impide que el atacante la comprima o reescriba historia antigua.

### 3.6 · Excluidos por comité y otros revisados

| Mecanismo | Qué da | Por qué queda fuera | Etiqueta |
|---|---|---|---|
| **Comités BFT** (Tendermint, HotStuff-2, GRANDPA, Casper) | Segundos, determinista | Comité fijo + depósito/slashing; rompe adaptividad (`d13-finalidad/f2:49,155-185`) | DEMOSTRADO · **REFUTADO** para ZEROX |
| **Algorand** (sortición criptográfica) | Finalidad determinista | Comité muestreado por sorteo: el caso canónico de la prohibición (`cap-adaptividad-finalidad.txt:32`) | DEMOSTRADO · **EXCLUIDO** |
| **P-040 / F3-style** | ~30 s; 0,76 GB/año | Comité por sorteo ponderado por espacio, `K=4 000` (R-FIN-16) | PLAUSIBLE · **EXCLUIDO** por la restricción nueva |
| **Filecoin F3** | 30 s frente a 7,5 h | Comité de SPs con QAP ≥2/3 (`fip-0086.md:57`) | VERIFICADO · **EXCLUIDO** |
| **Spacemesh** (Hare + Tortoise) | Malla PoST con orden | Hare es BFT por comité; proyecto muerto de facto (quiebra may-2025) | REFUTADO |
| **C-CHK · checkpoint firmado único** | 0 s, una vez | Firmante único: confianza centralizada; ya en SPEC solo como bootstrap de red joven (`SPEC.md:1904-1938`) | REFUTADO como mecanismo general |
| **HotPoW** (quórums de PoW) | Finalidad tras 3 bloques | En PoAS la Definición 1 no se cumple: `POA` pasa de 1,27e-12 a **0,5166** (`d12-quorum/informe.md:614-644`) | **REFUTADO** en PoAS |
| **Conflux / GHAST** | DAG PoW con cadena pivote y orden total | Alternativa DAG sin comité, pero no mejora la latencia de GHOSTDAG; ataque de viveza mitigado con GHAST (`research/dag-consenso-poas.md:85-88`) | DEMOSTRADO en su modelo · no aporta |
| **Bitcoin-NG / Inclusive** | Throughput y fairness | Los bloques clave siguen siendo lentos; Inclusive añade throughput, no seguridad (`phantom-ghostdag.txt:894-916`) | REFUTADO como vía de finalidad |
| **CAP dual rule** (regla de usuario) | Separa adaptividad y finalidad por usuario | Su regla de finalidad es **Algorand BA**, un comité (`cap-adaptividad-finalidad.txt:176-180`) | DEMOSTRADO · **EXCLUIDO** |

---

## 4 · El techo teórico: CAP adaptividad-finalidad

Lewis-Pye y Roughgarden prueban que **«No protocol is both adaptive and has finality»**
(`research/fuentes/lewispye-roughgarden-cap.txt:759`; definición de adaptativo en `:727`). En un
sistema permissionless como ZEROX, «adaptativo» no es opcional: el número de participantes varía y
no hay registro. La consecuencia para esta ronda es directa: **ningún mecanismo sin comité puede
dar finalidad determinista**, y no porque nadie lo haya diseñado, sino porque está demostrado que
no existe. Las dos únicas salidas son (a) finalidad probabilista por profundidad, con el suelo y
las tablas de las rondas 9c/10c, o (b) una regla de parada dura como `C-REORG-07`, que cambia
disponibilidad por seguridad y por eso es lenta (3,33 h). El paper de Sankagiri et al. muestra que
el compromiso se puede resolver **por usuario** con dos reglas de confirmación
(`cap-adaptividad-finalidad.txt:79-83`), pero su regla de finalidad es un BA con comité: la
restricción de Katana cierra esa puerta.

---

## 5 · Coste por nodo (resumen)

| Mecanismo | Coste nuevo por nodo |
|---|---|
| GHOSTDAG (baseline) | Cabeceras 21,5 GB/año (`q=1`); PoT 9,6 % de núcleo; orden del DAG |
| DAGKNIGHT | Cómputo del `k`-cluster adaptativo; sin certificado; **no medido en ZEROX** |
| SPECTRE | Orden por pares, barato; inútil sin orden total |
| Prism | `m` cadenas de votantes + tasa de bloque alta + ancho de banda; no medido en ZEROX |
| Avalanche | `O(1)` msgs/ronda y `O(log n)` rondas; en despliegue, validador 24/7 con stake |
| Thunderella | Mensajes BFT + líder designado |
| P-040/F3 | 0,76 GB/año de certificados BLS + tabla de poder + GossiPBFT sin portar |
| PoT/VDF | Verificación 9,6 % de núcleo; timelord 1 CPU; ya en el diseño |
| `C-REORG-07` | Ninguno; el coste es la parada del nodo en una partición >3,33 h |

---

## 6 · Qué habría que demostrar antes de escribir cada candidato

1. **DAGKNIGHT completo (mejor candidato no-comité).** Implementar Alg. 2/4 con *rank* y
   tie-breaking (`dagknight.txt:823-840`); re-derivar R-FIN-6, `F`, R-FIN-12 y R-FIN-8′/13′ con `k`
   variable (`d14-dagknight/informe.md:143-154`); medir coste con `λ=1` y `Δ` real (E1); y decidir
   si el `k*` completo resiste el ataque de inflación. Sin eso, solo hay un resultado de red sana.
2. **Prism en PoAS.** Analizar el doble dipping en su estructura (¿la aleatoriedad correlacionada de
   Chia es portable a las cadenas de votantes?); evaluar `c1/c2` con `D=4 s` y `Bv/C` de ZEROX;
   medir la latencia de doble gasto; simular con `λ=1/s`. Hoy es LAGUNA.
3. **PoT/VDF como ancla.** Demostrar que el PoT de ZEROX impide el ataque de rango largo en su
   modelo (Chia lo prueba con su VDF y su déficit; ZEROX usa AES, no grupos de clase); medir el
   coste de `verify_sequential` por slot (pendiente de las rondas 10a/anti-DoS); y publicar que la
   finalidad sigue siendo probabilista por profundidad.
4. **Baseline.** Medir `Δ` real (E1) y recalcular `k` con la ec. (2) completa; publicar las tablas
   de riesgo al comerciante. Es lo único que se puede mejorar hoy sin tocar el núcleo.
5. **`C-REORG-07`.** Documentar el camino de recuperación del nodo detenido (P-016), sin el cual la
   regla deja nodos congelados.

---

## 7 · Veredicto

| Punto | Resultado | Etiqueta |
|---|---|---|
| **Restricción «sin comité»** | Elimina BFT, Algorand, Avalanche desplegado, Thunderella, P-040/F3, Filecoin F3 y el checkpoint firmado único | **EXCLUIDOS** por decisión de Katana |
| **Finalidad determinista rápida sin comité** | No existe: teorema CAP adaptividad-finalidad (`lewispye-roughgarden-cap.txt:759`) | **REFUTADO** |
| **Confirmación probabilista por peso de DAG** | GHOSTDAG: 45 s ejemplo; ZEROX 100-134 s de suelo, 241-871 s a `10⁻¹²`; sin comité ni dinero | **VERIFICADO** |
| **SPECTRE** | 21 s pero sin orden total: no sirve de núcleo | **REFUTADO** como núcleo |
| **DAGKNIGHT** | 4-17 s (`ε=0,05`) en red sana; el `k*` crudo es manipulable a 90-250 s; el protocolo completo es LAGUNA | **VERIFICADO** sano · **REFUTADO** el crudo · **LAGUNA** el completo |
| **Avalanche** | 1,35 s, pero muestra = subconjunto que decide y Sybil sin resolver; despliegue con stake | **VERIFICADO** el número · **REFUTADO** para ZEROX |
| **Prism** | Líderless sin comité; latencia ∝ `D` con constantes enormes; el doble gasto degrada al baseline; sin análisis en PoAS | **DEMOSTRADO** PoW · **LAGUNA** PoAS |
| **Thunderella** | Acelerador + comité 3/4 | **REFUTADO** por la restricción |
| **PoT/VDF** | No da finalidad; da reloj y anti-rango-largo; timelord descentralizable sin permiso; no baja el suelo | **DEMOSTRADO** · **VERIFICADO** |
| **Finalidad dura sin comité** | `C-REORG-07`: 11 999 bloques = 3,33 h, fail-stop | **VERIFICADO** |

### Recomendación

**Cuál sobrevive a la restricción.** Solo cuatro familias: (1) la **confirmación probabilista por
profundidad** que ya existe, con su regla dura `C-REORG-07`; (2) **DAGKNIGHT** como regla de orden
adaptativa y confirmación por cliente; (3) el **PoT/VDF** como ancla temporal y anti-rango-largo,
que ya está en el diseño; (4) **Prism** como línea de investigación, no como v1.

**Cuál es el mejor para ZEROX.** **DAGKNIGHT completo** (no el `k*` crudo de 14A): es el único
mecanismo sin comité, sin dinero y con orden total que baja el suelo de 100-134 s a **4-17 s** en
red sana, y su versión completa con *rank* + tie-breaking es la única esperanza conocida de
sobrevivir al ataque de inflación. Condición de adopción: implementar el protocolo completo y
re-auditar con la ronda adversarial; si no supera la inflación de `k*`, **se queda el baseline**.
La alternativa segura es publicar las tablas de riesgo del baseline y mantener `C-REORG-07` como
única finalidad determinista (3,33 h). **No adoptar Avalanche, Thunderella, BFT ni P-040/F3**: la
restricción los excluye y, en el caso de P-040, la restricción llega después de que la ronda 12 la
recomendara —queda retirada como candidata de consenso—.

---

## 8 · Errores propios y hallazgos

1. **Hallazgo: `confirmation_depth_k` de Autonomys NO es finalidad de cadena.** La ronda 13 lo citó
   como «finalidad por profundidad = 100 bloques ≈ 600 s» (`d13-finalidad/f2:253`). Verificado en
   el código: el parámetro gobierna el **archivado** (`archiver.rs:601-603`) y la finalidad de
   segmentos es `FINALIZATION_DEPTH_IN_SEGMENTS = 5` (`archiver.rs:82-88`). Autonomys no tiene
   gadget de finalidad rápida; su confirmación es probabilista por profundidad, como el resto de
   PoST sin comité. *Qué cambió:* la fila 10 de la tabla usa 6 s/bloque y profundidad de archivado,
   no una finalidad de 600 s.
2. **Hallazgo: discrepancia `q` en el SPEC.** `C-SLOT-01` publica `q = 120` (`SPEC.md:1853-1854`,
   implicando `T=120 s`), mientras P-041 fijó `λ = 1 bloque/s` (`SPEC.md:945-946, 1514, 1620`). La
   ronda 14A y este informe usan `λ=1`, que es el valor vigente de P-041. No resuelvo la
   discrepancia (fuera del encargo); queda anotada.
3. **No localicé ningún mecanismo llamado «Colored»** en la literatura de finalidad. Interpreto que
   la intención era Conflux/GHAST o el coloreado de GHOSTDAG; ambos están cubiertos (§3.6). Si era
   otra cosa, es LAGUNA.
4. **La cota de Prism no es usable como latencia.** Al evaluar `c1(β)` con `D=4 s` sale 7,1-28,9 h,
   y el propio paper dice que sus constantes son holgadas y que caracterizar las exactas es trabajo
   futuro (`prism-1810.08092.txt:1368-1371`). No se usa como número de ZEROX; se reporta como cota.
5. **No ejecuté git** (instrucción de la ronda), aunque `METODO-AGENTES.md:6` pide commit por punto.
   Única desviación del método.

---

## 9 · Reproducción y auditoría

```
cd research/scripts/d14-sin-comite
python3 calcula_numeros.py          # -> salida_numeros.txt
python3 ../AUDITA_SCRIPTS.py .      # -> salida_auditoria.txt
```

```
$ python3 research/scripts/AUDITA_SCRIPTS.py research/scripts/d14-sin-comite/
Scripts analizados: 1

======================================================================
Sospechas totales: 0
```

Sin sospechas T1/T2/T3/T3b/T4. El script es aritmética sobre constantes publicadas (no hay
simulación estocástica, luego no aplican semillas ni el criterio `α` de simulación).

---

## Fuentes

**Locales (research/fuentes/).** `phantom-ghostdag.txt` · `dagknight.txt` ·
`lewispye-roughgarden-cap.txt` · `cap-adaptividad-finalidad.txt` · `fip-0086.md` · `hotpow.txt` ·
`research/dag-poas-catalogo-problemas-ataques.md` · `research/dag-poas-ancla-de-orden.md` ·
`research/dag-poas-capa-finalidad.md` · `research/dag-consenso-poas.md` ·
`research/timelord-redundancia-informe.md` · `research/scripts/d13-finalidad/f2-alternativas-latencia.md` ·
`research/scripts/d14-dagknight/informe.md` · `research/scripts/d12-quorum/informe.md` ·
`research/scripts/d9-ronda10c/informe.md` · `SPEC.md`.

**Primarias descargadas (research/scripts/d14-sin-comite/fuentes/).**
- Prism: arXiv:1810.08092v4, *Deconstructing the Blockchain to Approach Physical Limits*
  (`prism-1810.08092.pdf/.txt`).
- Thunderella: ePrint 2017/913, Pass y Shi (`thunderella-2017-913.pdf/.txt`).
- Avalanche: arXiv:1906.08936v2, Team Rocket et al. (`avalanche-1906.08936.pdf/.txt`).
- Chia: Green Paper vigente 12-jun-2026, `docs.chia.net/files/ChiaGreenPaper_20260612.pdf`
  (`chia-greenpaper-20260612.pdf/.txt`).
- Autonomys: `/home/katana/zeo/fuentes/subspace` (`@ f8842d0`), código citado por fichero y línea.

**Web (consultada 2026-09-10).** `https://docs.avax.network/docs/primary-network` (stake de
2 000 AVAX por validador).
