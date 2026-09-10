# D13 · F2 — Alternativas para irreversibilidad baja: inventario con tiempo, supuestos y precio

**Fecha:** 2026-09-10 · **Ronda:** 13 (P-040 y alternativas) · **Encargo:** `research/scripts/d13-finalidad/ENCARGO.md` §F2.
**Alcance:** inventario de mecanismos que consiguen irreversibilidad, ordenados por **tiempo de irreversibilidad**.
Prioridad declarada por Katana: **bajar el tiempo de irreversibilidad es el criterio que decide**; el cliente ligero
es secundario. **Este documento no audita P-040** (eso es F1): lo sitúa frente a las alternativas con los números que
su propia propuesta publica y sin auditar, y lo etiqueta como tal.

**Método.** Solo lectura de fuentes primarias locales y web. Cada afirmación lleva fichero y línea o URL. Las
etiquetas son las cinco del método: **DEMOSTRADO** (argumento cerrado), **VERIFICADO** (medido y reproducible),
**PLAUSIBLE** (argumento sin cerrar), **REFUTADO**, **LAGUNA** (falta fuente o medida; se dice qué haría falta).
Números con coma decimal. No se escribió ningún otro fichero; no se ejecutó git.

**Definición operativa de «tiempo de irreversibilidad».** Segundos desde que un bloque entra en la cadena hasta que
no puede salir de ella (a) por regla del protocolo —finalidad determinista— o (b) con probabilidad menor que `ε`
—finalidad probabilista—, bajo un supuesto declarado de adversario `α`. Las dos cosas no son intercambiables y la
tabla las separa.

---

## 1 · Resumen ejecutivo

1. **Por debajo de ~30 s solo hay comités.** Todo lo que baja de medio minuto —BFT clásico, Avalanche desplegado,
   P-040/F3— es un conjunto de validadores conocido votando. La finalidad determinista rápida **no existe sin comité**;
   es lo que dice el análogo CAP de Lewis-Pye y Roughgarden (`research/fuentes/lewispye-roughgarden-cap.txt:28-37`).
2. **El único candidato sin comprar nada es P-040/F3**, y su precio no es la seguridad sino la viveza: **a `α = 0,33`
   se para el 41 % de las instancias** y la cadena vuelve a `F = 2 h` (`research/dag-poas-capa-finalidad.md:157-160`).
   La equivocación, además, obliga a castigar recompensa ya ganada (R-FIN-19): «sin dinero» es matizable, no gratis
   (`research/scripts/d12-quorum/informe.md:614-644`).
3. **Avalanche sin dinero es REFUTADO.** Snowball es rápido (1,35 s medidos) pero su propia §Sybil dice que el control
   de Sybil es un problema aparte, y el despliegue real exige **2.000 AVAX** de stake por validador
   (`https://docs.avax.network/docs/primary-network`). Con identidades gratis el atacante entra en la muestra.
4. **El suelo de 100-134 s no lo baja ningún parámetro del diseño actual** (`research/dag-poas-catalogo-problemas-ataques.md:63`;
   `research/scripts/d9-ronda10c/informe.md:383-387`). Bajarlo exige **cambiar la regla de confirmación** (DAGKNIGHT,
   LAGUNA) o **añadir una capa** (P-040, PLAUSIBLE). Ninguna de las dos está medida en ZEROX.
5. **Lo único con etiqueta VERIFICADO y precio aceptable hoy es el baseline**: esperar. A `α = 0,33` y `δ = 0`, el
   riesgo de reversión ya es `1,5e-06` a los 10 min y `7,1e-36` a los 30 min (`d12-quorum/informe.md:749-754`). La
   decisión real no es «qué gadget», sino si se acepta que la irreversibilidad rápida sea **probabilista y por usuario**.

---

## 2 · Tabla comparativa — ordenada por tiempo de irreversibilidad

Orden de menor a mayor tiempo. «Comité» = conjunto de validadores conocido y acotado. «Compone» = encaja con
GHOSTDAG + PoAS sin rehacer el núcleo.

| # | Mecanismo | T_irrev normal | T_irrev con `α = 0,33` | Tipo | ¿Dinero en juego? | ¿Comité conocido? | ¿Compone con GHOSTDAG+PoAS? | Coste por nodo | Etiqueta |
|---|---|---|---|---|---|---|---|---|---|
| 1 | **Comité BFT** (Tendermint, HotStuff-2, Casper FFG, GRANDPA) | 2-6 retrasos de red: Tendermint 3 pasos (`1807.04938 §I`); HotStuff-2 2 fases (`eprint 2023/397`); GRANDPA `t_r+6T` (`2007.01560 §4.2.2`); Ethereum ~12,8 min (2 épocas) | La seguridad se mantiene; la viveza se para si cae la participación (CAP: no es adaptativo) | Determinista | **Sí**: depósito + slashing (Casper `1710.09437 §2`; Ethereum `ethereum.org/pos`) | **Sí**: `3f+1`, `2f+1` honestos (GRANDPA) | **No sin registro**: una capa BFT rompe adaptividad (`cap-adaptividad-finalidad.txt:271-285`) | Validador 24/7, comunicación lineal (HotStuff) o BA completa; BLS/blst; código de slashing | **DEMOSTRADO** en sus papers · **REFUTADO** para ZEROX por dinero y comité |
| 2 | **Avalanche Snowball/Snowman** | **1,35 s** medidos en despliegue, 3.400 tps (`arXiv:1906.08936` abstract); la web actual reclama <1 s en C-Chain y <100 ms en L1 (`docs.avax.network`, 2026) | Seguridad degrada suave; viveza fuerte solo `f = O(√n)`; encima, rondas polinómicas (`1906.08936 §4.2`) | Probabilista `ε` | **No hay slashing en el protocolo; sí stake en el despliegue** (2.000 AVAX) | **Sí** (validadores con stake); el paper asume `N` compartido (`§4.1`) | **PLAUSIBLE con muestreo ponderado por espacio; LAGUNA**: no hay diseño para GHOSTDAG | `O(1)` mensajes/ronda y `O(log n)` rondas esperadas; registro de validadores | **VERIFICADO** el número · **REFUTADO** «sin dinero» |
| 3 | **DAGKNIGHT** | `O((ln(1/ε)/λ + D)/(1−2α) + D²λ)`; simulado **1,2-12 s** (`D = 0,1-2 s`, `λ = 3,75`, `α = 0,2`, `ε = 0,05`; `dagknight.txt:328-352`, `:182-197`) | Cota exponencial; pagos honestos aún en tiempo cuadrático (`dagknight.txt:352-367`) | Probabilista; el cliente fija `D` | **No** | **No** | **Sí en principio**: es la regla de orden, no una capa; sustituye a GHOSTDAG | Cómputo del orden del DAG; sin certificado; coste en ZEROX **LAGUNA** | **DEMOSTRADO** en su modelo · **LAGUNA** para ZEROX |
| 4 | **P-040 / F3-style** (tabla de poder + GossiPBFT) | **~30 s** en caso normal (certificado cada 30 s; `dag-poas-capa-finalidad.md:164-171`; `ENCARGO.md:22`) | **Se para el 41 % de las instancias**; fallback R-FIN-7 `F = 2 h`; recuperación cuando vuelve la participación (`capa-finalidad.md:157-160`) | Determinista mientras vive | **No por adelantado**; R-FIN-19 quema coinbases no maduras de la clave equivocada (`capa-finalidad.md:99-111`) | **Sí**: tabla de poder derivada de los bloques que cobran, `W_POWER = 3.600 s` | **Sí: está diseñada para esto** (aditiva sobre R-FIN-7) | 0,76 GB/año de certificados (`K = 4.000`, 724 B/30 s); BLS agregada; tabla de poder por instancia; GossiPBFT sin portar | **PLAUSIBLE** (la propuesta se declara «HIPÓTESIS, SIN AUDITAR») |
| 5 | **Doble regla CAP** (checkpointed longest chain) | `e + O(Δ)`, con `e` elegido (`e ≫ d = O(√κΔ)`); no fija segundos (`cap-adaptividad-finalidad.txt:529-545`) | Se para el checkpoint si los checkpointers < 2/3; la regla `k`-deep sigue viva | Determinista (comité) + adaptativa (k-deep) | Depende del protocolo de checkpointing; el paper no lo especifica | **Sí**: checkpointers con 2/3 honestos (`cap-adaptividad-finalidad.txt:519-520`) | **Sí**: es un gadget sobre la cadena más larga; conceptualmente es el molde de P-040 | BA por checkpoint; sin número de coste | **DEMOSTRADO** en su modelo · **PLAUSIBLE** portado a PoAS |
| 6 | **GHOSTDAG / Kaspa** (referencia) | Media de segundos; 70,4 % ≤10 s, 99,9 % ≤10 min; máximo observado 746 s (`phantom-ghostdag.txt:884-893`); 45 s en el ejemplo del paper (`λ=1`, `k=16`, `2D=7`, `α≤0,25`, `ε=0,1 %`, `:824-837`) | Curvas de 10c: 300 s → `2,5e-1`; 600 s → `1,5e-6`; 1.800 s → `7,1e-36` (`d9-ronda10c/informe.md:367-372`) | Probabilista | **No** | **No** | Es el núcleo actual | 21,5 GB/año de cabeceras; PoT 9,6 % de un núcleo (catálogo D1, D4) | **VERIFICADO** |
| 7 | **Baseline R-FIN-7** (profundidad) | Regla: `F = 2 h` (`dag-poas-ancla-de-orden.md:271-273`). Suelo estructural: **100-134 s**, ninguna `F` lo baja. Comerciante a `1e-12`: 241 s (`α=0,1`), 482 s (`α=0,25`), 871 s (`α=0,33`) (`d9-ronda10c/informe.md:393-397`) | A `1e-12`: **871 s** (`δ=0`) y **2.931 s** (pesimista `δ` D8); 674 s a `α=0,25` pesimista (`d9-ronda10c/informe.md:398-400`) | Probabilista | **No** | **No** | Es el baseline | Sin coste nuevo | **VERIFICADO** |
| 8 | **HotPoW** (quórums de PoW) | Finalidad tras **3 bloques** (`hotpow.txt:220-245`); tiempo de commit ≈ tiempo de quórum optimista, robusto a latencia y churn (`§5.1`) | — | Determinista en PoW | **No** (PoW) | **No** | **REFUTADO en PoAS**: la Definición 1 no se cumple; `POA` pasa de `1,27e-12` a **0,52** con cualquier `k` (`d12-quorum/informe.md:614-644`) | Voto de 72 B en PoW; **484 B** en PoAS (`d12 F.1`) | **REFUTADO** para PoAS |
| 9 | **SPECTRE** (referencia) | **21 s** en el mismo ejemplo de GHOSTDAG (`phantom-ghostdag.txt:830-837`) | Orden solo por pares; sin orden total, puede no converger entre bloques próximos (`:918-928`) | Probabilista | **No** | **No** | No da orden total; no sirve para UTXO general | — | **DEMOSTRADO** en su paper · descartado como núcleo |
| 10 | **Cliente ligero** (secundario) | No es irreversibilidad: es verificación | — | — | Weak subjectivity **exige confianza** en un checkpoint reciente (`1710.09437 §4.1`); servidores privados = confianza total | — | #28a: 2-4 GB/año con confianza parcial; #28b: ~120 MB por comprobación; P-040 R-FIN-22: 6,6 MB/año | **PLAUSIBLE** (#28a) · **LAGUNA** (#28b) |

**Lectura de la tabla.** Las filas 1-5 son los únicos mecanismos sub-minuto. Las filas 1, 2 y 5 exigen dinero o
comité; la 4 es la única sin compra y paga en viveza; la 3 no tiene comité pero está sin adaptar. Las filas 6-7 son
lo que hay. La 8 está refutada en nuestro recurso. Ninguna fila baja el suelo de 100-134 s **sin tocar la regla de
confirmación o añadir una capa**.

---

## 3 · Mecanismo por mecanismo

### 3.1 · Baseline: profundidad de confirmación (R-FIN-7) y el suelo estructural

**Qué es.** R-FIN-7 prohíbe reorganizar por debajo de `F` segundos de slot; una punta que lo exigiera se ignora, nunca
apaga el proceso (`research/dag-poas-ancla-de-orden.md:271-273`). `F = 2 h` provisional, decidido; la candidata de
producción es `F = 1 h` condicionada a `Δ_p99 ≤ 14,9 s` (catálogo F3, `dag-poas-catalogo-problemas-ataques.md:97`).

**Tiempo real.** Dos cosas distintas:

- **La regla**: 2 h. No es el tiempo al que el usuario puede aceptar un pago; es la garantía categórica.
- **El suelo**: `3k/((1−α)λ) = 100-134 s` con `k = 30`, `λ = 1/s`. Por debajo **ninguna confirmación es posible**:
  es la ventaja de *freeloading* de `3k` bloques del Lema 10 de GHOSTDAG. No depende de `F`
  (`d9-ronda10c/informe.md:383-387`; catálogo D6, `:63`).

**Lo que espera un comerciante** (`d9-ronda10c/informe.md:393-400`, `brentq` sobre `t`):

| Modelo | `α` | `<10⁻³` | `<10⁻⁶` | `<10⁻⁹` | `<10⁻¹²` |
|---|---:|---:|---:|---:|---:|
| Corregido (`δ=0`) | 0,10 | 159 s | 190 s | 217 s | 241 s |
| Corregido | 0,25 | 283 s | 356 s | 421 s | 482 s |
| Corregido | 0,33 | 460 s | 608 s | 742 s | 871 s |
| Pesimista (`δ` D8) | 0,25 | 381 s | 489 s | 584 s | 674 s |
| Pesimista | 0,33 | 1.298 s | 1.869 s | 2.406 s | 2.931 s |

**Supuestos.** `α` creído por el usuario; `δ` medido por D8 o nulo; `λ = 1` bloque/s; `k = 30`.

**¿Dinero?** No. **¿Comité?** No. **¿Compone?** Es el diseño. **Coste:** ninguno nuevo.

**Etiqueta: VERIFICADO.** Riesgo hoy a `α=0,33`: `1,5e-06` a 10 min y `7,1e-36` a 30 min (`d12-quorum/informe.md:751-752`).
**Consecuencia:** bajar de 100-134 s exige cambiar la regla de confirmación (DAGKNIGHT) o añadir una capa (P-040);
ningún parámetro de `F`, `k` o `λ` lo hace (subir `λ` sube `3k` en bloques igual; `informe-52 §31`, `:560-563`).

### 3.2 · Avalanche Snowball/Snowman

**Qué es.** Familia Snow: muestreo aleatorio de `k` nodos por ronda, umbral `α > k/2`, confianza `β`; Snowball añade
contadores de confianza y decide al alcanzar `β` chits consecutivos (`arXiv:1906.08936 §3.1-3.3`). Avalanche lo usa
sobre un DAG de transacciones: una instancia Snowball por conjunto de conflicto; Snowman es la variante lineal del
C-Chain.

**Tiempo.** **1,35 s** de latencia de confirmación y 3.400 tps en el despliegue medido por el paper (abstract). La web
actual de Avalanche reclama *«Sub-second finality on the shared C-Chain, and under 100 milliseconds on an L1»*
(`https://docs.avax.network/`, 2026). La seguridad es **probabilista** `ε`; la viveza fuerte solo si `f ≤ O(√n)`
(P3), y para `f` mayor las rondas crecen polinómicamente (`§4.2`).

**Supuestos.** Todos los nodos comparten `N` para el análisis de seguridad de Slush (`§4.1`); el propio paper relaja
esto a discrepancias de vista acotadas (`§A.7`) pero **no resuelve Sybil**: *«The consensus protocols presented in
this paper can adopt any Sybil control mechanism, although proof-of-stake is most aligned with their quiescent
operation»* (`§2, Sybil Attacks`).

**¿Peso por espacio?** No en el protocolo: el muestreo es **por nodo**, uniforme sobre el conjunto conocido. Ponderar
por espacio exige muestreo ponderado y una tabla de pesos determinista —exactamente la tabla de R-FIN-15 de P-040—;
no hay diseño ni análisis de ese híbrido en ZEROX. **LAGUNA.**

**¿Composición con GHOSTDAG?** Técnicamente plausible: Avalanche ya vive sobre un DAG y resuelve conflictos; podría
votar la punta de la cadena seleccionada de GHOSTDAG. Pero la seguridad sigue necesitando `N` con resistencia Sybil.
**PLAUSIBLE**, sin instrumento.

**¿Seguridad real sin dinero?** **REFUTADO.** El despliegue exige *«staking at least 2,000 AVAX»* por validador para
entrar en el Primary Network (`https://docs.avax.network/docs/primary-network`), y la home reporta `$1.689 M` en stake
(46,6 % del suministro). El protocolo no tiene slashing —nadie pierde el depósito por equivocarse—, pero el depósito
es la puerta de entrada. Sin él, las identidades son gratis y el atacante llena la muestra.

**Coste por nodo.** `O(1)` mensajes por ronda y `O(log n)` rondas esperadas; estado: preferencia + contadores. Ligero.
**Etiqueta: VERIFICADO** el número; **REFUTADO** «sin dinero en juego».

### 3.3 · DAGKNIGHT

**Qué es.** Generalización sin parámetros de Nakamoto/PHANTOM: en vez de fijar `k`, el protocolo elige en cada
momento el `k` mínimo cuyo `k`-cluster cubre ≥50 % del DAG (`dagknight.txt:112-119`). Tolera <50 % de cómputo,
sin cota de latencia dentro del protocolo; el **cliente** fija localmente su cota `D` sobre la latencia adversarial
reciente (`:233-236`, `:269-288`).

**Tiempo.** Optimista: `O((ln(1/ε)/λ + D)/(1−2α) + D²λ)` (`:328-352`). Simulaciones del paper con `λ = 3,75` bloques/s,
`α = 0,2`, `ε = 0,05`: **12 s** con `D = 2 s`, **6 s** con `D = 1 s`, **1,2 s** con `D = 0,1 s` (`:182-197`).
En pesimista la cota es exponencial en `Dλ/(1−2α)`, pero los pagos honestos se confirman en tiempo cuadrático
(`:352-367`). Teorema de Pass-Shi citado: ningún protocolo responsivo tolera ≥1/3 (`:292-294`); DAGKNIGHT no es
responsivo en sentido estricto, se ajusta a la latencia **adversarial máxima**, no a la observable.

**¿Finalidad o solo orden?** Solo orden + confirmación probabilista por cliente. **No hay certificado ni gadget de
finalidad.** Es un cambio de la regla de orden, no una capa.

**¿Dinero?** No. **¿Comité?** No. **¿Compone?** Sustituiría a GHOSTDAG: mismo DAG, otra regla de orden. No hay
medida para `λ = 1/s`, `k = 30`, `Δ` real de ZEROX; el coste de cómputo por nodo no está medido aquí. **LAGUNA.**

**Etiqueta: DEMOSTRADO** en su modelo · **LAGUNA** para ZEROX. **Qué haría falta:** portar la regla y medir
confirmación y coste con el DAG de ZEROX, `λ = 1`, y el `Δ` real (E1).

### 3.4 · Comité BFT: Tendermint, HotStuff-2, Casper FFG, GRANDPA

**Qué son.**

- **Tendermint**: `n > 3f`, decide en **3 pasos de comunicación** (propose, prevote, precommit) con `2f+1` de poder de
  voto; terminación tras GST por gossip (`arXiv:1807.04938 §I`, `§III`).
- **HotStuff**: vista de **3 fases**, responsivo a la latencia real, comunicación lineal; **HotStuff-2** demuestra que
  **2 fases bastan** dentro de una vista (`arXiv:1803.05069` abstract; `eprint 2023/397`).
- **Casper FFG**: overlay PoS sobre una cadena PoW; validadores con depósito; `2/3` **por depósito**; un checkpoint
  se finaliza con dos enlaces de supermayoría (justificado → hijo directo); violar las condiciones cuesta el depósito
  entero (`arXiv:1710.09437 §2`). En Ethereum: slots de 12 s, épocas de 32 slots, finalidad en 2 épocas ≈ **12,8 min**;
  revertir cuesta ≥1/3 del ETH en stake (`https://ethereum.org/en/developers/docs/consensus-mechanisms/pos/`).
- **GRANDPA**: `3f+1` votantes, `f < n/3`; finaliza en `t_r + 6T` tras GST con primario honesto; *accountable safety*
  identifica `f+1` byzantinos (`arXiv:2007.01560 §4.2.2`, `§4.1`); desplegado en Polkadot.

**Tiempo.** **Segundos** en Tendermint/HotStuff (2-3 retrasos de red), `6T` en GRANDPA, minutos en Casper/Ethereum.
Son los únicos que bajan a segundos de forma **determinista**.

**¿Dinero?** **Sí, en todos** para resistir Sybil y para que el castigo sea creíble: depósito y slashing (Casper,
Ethereum), stake (Polkadot). **¿Comité?** Sí, conocido y acotado.

**¿Compone con GHOSTDAG+PoAS?** **No sin registro.** El paper CAP lo dice de los híbridos: *«Once a miner is elected
as a committee member, it is obliged to stay active... which compromises on the adaptivity property... the whole
protocol loses safety»* (`cap-adaptividad-finalidad.txt:271-285`). Y un comité exige elegirlo: en ZEROX solo hay dos
fuentes posibles, espacio (P-040) o dinero (rechazado).

**Coste de introducirlo.** Validador 24/7 (rompe el granjero doméstico), comunicación lineal por vista (HotStuff) o
BA completa, agregación BLS (ya presente por el KZG, d12 F.5), reglas de slashing y una tabla de poder. Es una
reingeniería del núcleo, no una capa.

**Etiqueta: DEMOSTRADO** en sus papers · **REFUTADO para ZEROX** como mecanismo sin dinero.

### 3.5 · P-040 / F3-style: finalidad lenta por profundidad + certificado advisory

**Qué es.** Capa aditiva sobre el diseño vivo: tabla de poder derivada de los bloques que cobran (R-FIN-15), comité
por sorteo ponderado con prueba de vida (R-FIN-16, `K = 4.000`, `W_VIVO = 1.800 s`), certificado BLS agregado de ≥2/3
de las plazas (R-FIN-17), regla de selección que solo puede **adelantar** la finalidad, nunca retrasarla (R-FIN-18),
y R-FIN-7 como red de seguridad (`research/dag-poas-capa-finalidad.md:58-133`).

**Tiempo.** **~30 s en caso normal** (certificado cada 30 s; `capa-finalidad.md:164-171`; `ENCARGO.md:22`). Bajo
ataque: **se para el 41 % de las instancias a `α = 0,33`**; la cadena sigue por R-FIN-7 y vuelve a certificar cuando
la participación se recupera (`capa-finalidad.md:157-160`). La causa no es un defecto: F3 exige `2/3` del poder
**total**, no de los presentes; con `α = 0,33` haría falta el **99,5 %** de los honestos encendidos
(`capa-finalidad.md:179-188`).

**¿Dinero?** **No por adelantado.** Nadie compra para entrar: el peso es el espacio y el sorteo no exige registro.
Pero la anti-equivocación **sí toca dinero ya ganado**: R-FIN-19 quema las coinbases no maduras de la clave que firma
dos veces y la excluye 30 días (`capa-finalidad.md:99-111`). La propuesta lo declara: *«el castigo es pequeño y no
disuade a un atacante que ya decidió gastar α = 0,3 en espacio»*. Y d12 F.7 demuestra que **sin regla
anti-equivocación la ambigüedad es ~0,5 para cualquier `k`**: una solución PoAS no ata el voto al valor
(`d12-quorum/informe.md:614-644`). Es decir: «sin dinero» es **matizable**, no gratis.

**¿Comité?** **Sí, pero derivado del espacio**, no comprado: es la única forma conocida de tener tabla de poder sin
registro ni stake. **¿Compone?** **Sí: está diseñada para GHOSTDAG+PoAS**, es aditiva y el fallback es R-FIN-7.

**Coste por nodo.** 0,76 GB/año de certificados (`K = 4.000`, 724 B cada 30 s; `capa-finalidad.md:164-171`); una
verificación de firma BLS agregada + mapa de bits por certificado; tabla de poder por instancia; GossiPBFT **no
portado ni leído entero** (laguna declarada, `capa-finalidad.md:304-319`). BLS/blst ya está en la ruta de consenso por
el KZG de la solución (`d12-quorum/informe.md:583-597`), así que su coste declarado principal desaparece.

**Etiqueta: PLAUSIBLE** (la propuesta se declara *«HIPÓTESIS, SIN AUDITAR»*; la auditoría es F1). El número de la
viveza (41 %) y el de la `p` requerida (88,9 % a `α=0,25`) están medidos por ellos mismos y **no verificados** aquí.

### 3.6 · Doble regla de confirmación (CAP / checkpointed longest chain)

**Qué es.** El paper CAP propone que **cada usuario elija** entre dos reglas: la adaptativa (`k`-deep) y la de
finalidad (todo hasta el último checkpoint). Los mineros siguen una única regla de propuesta; los checkpointers
corren un BA (Algorand en el paper) con `2/3` honestos y marcan bloques que estén `k`-deep en una cadena honesta
(CP0-CP3; `cap-adaptividad-finalidad.txt:102-123`, `:506-545`). Es el molde conceptual de P-040 y de los gadgets
Afgjort/GRANDPA que el propio paper compara (`:287-356`).

**Tiempo.** `e + O(Δ)`, con `e` el intervalo entre checkpoints, elegido `≫ d = O(√κΔ)` (`:533-541`). No fija
segundos: la latencia es un parámetro de diseño. **Bajo ataque** se para el checkpoint si los checkpointers bajan de
`2/3`; la regla `k`-deep sigue confirmando (`Theorem 1`, `:563-577`).

**¿Dinero?** El paper no lo especifica: los checkpointers son elegidos por el oráculo; en permissionless haría falta
un mecanismo Sybil (stake o tabla de espacio). **¿Comité?** Sí. **¿Compone?** Sí: es un gadget sobre longest chain;
su traducción a GHOSTDAG+PoAS es exactamente P-040.

**Etiqueta: DEMOSTRADO** en su modelo · **PLAUSIBLE** portado a PoAS (es lo que P-040 hace).

### 3.7 · HotPoW (quórums de PoW) — REFUTADO en PoAS

**Qué es.** Transferir HotStuff al permissionless usando **soluciones de PoW como votos efímeros**: cada solución
(ATV) vota una vez por un valor porque la referencia va dentro del hash del puzzle; finalidad tras **3 bloques**
pipelineados (`hotpow.txt:200-245`, `:279-311`). En simulación tolera latencia, churn y fallo de líder; el tiempo de
commit es ≈ el tiempo de quórum optimista (`§5.1`, `:782-845`).

**Por qué no sirve aquí.** En PoAS el reto sale del PoT y del **slot**, no del valor votado: `verify_solution` no ve
la referencia, y la atadura la pone una firma aparte que firma cuantos valores quiera. La Definición 1 de HotPoW se
rompe y `POA` pasa de `1,27e-12` (`k=64`) a **0,5166**; sin regla anti-equivocación no hay seguridad ninguna
(`d12-quorum/informe.md:614-644`). Arreglarlo exige castigo = dinero en juego. **REFUTADO.**

### 3.8 · Otros mecanismos revisados (y por qué no entran)

| Mecanismo | Qué da | Por qué no entra | Etiqueta |
|---|---|---|---|
| **SPECTRE** | Confirmación por pares en 21 s en el ejemplo de GHOSTDAG (`phantom-ghostdag.txt:830-837`) | No da orden total; puede no converger entre bloques próximos (`:918-928`) | **DEMOSTRADO** en su paper · no apto como núcleo |
| **Autonomys (referencia)** | Finalidad por profundidad `confirmation_depth_k = 100` bloques en producción; a ~6 s/bloque (1 bloque cada 6 slots de 1 s) ≈ **600 s** (`/home/katana/zeo/fuentes/subspace/crates/subspace-runtime-primitives/src/lib.rs:219-225`; parámetros de slot en `dag-poas-ancla-de-orden.md:280-285`) | Es la referencia de la que partimos; confirma que **ni Autonomys tiene finalidad rápida**: usa profundidad | **VERIFICADO** (código) |
| **Checkpoint firmado por un operador** (o por el timekeeper) | 0 s, trivial | Centraliza; rompe **C-TIMELORD-02** («no existe identidad, permiso ni staking asociado al rol de timelord», `research/timelord-redundancia-informe.md:118-120`) y el rechazo de Katana a la confianza | **REFUTADO** |
| **Weak subjectivity** (checkpoints sociales, estilo PoS) | Arranque de cliente ligero sin cadena completa | Reintroduce un checkpoint de confianza; el propio Casper lo defiende con «log on cada 1-2 meses» (`1710.09437 §4.1`). No da irreversibilidad a un nodo completo | **PLAUSIBLE** en PoS · **REFUTADO** como mecanismo de irreversibilidad |
| **Prism, Fruitchains, Bitcoin-NG, SPECTRE lineal** | Throughput/orden, no finalidad | No ofrecen irreversibilidad mejor que la profundidad; no compiten en la columna que decide | **REFUTADO** como vía de finalidad |
| **SNARK del coloreado** (28c) | Cliente ligero sucinto | Coste de prueba altísimo a 1 bloque/s; ninguna implementación; no para v1/v2 (`dag-poas-informe-52-problemas.md:524-526`) | **LAGUNA** |

**Lo que no encontré con fuente:** ningún protocolo de la literatura revisada que dé **finalidad determinista
sub-minuto sin dinero en juego y sin conjunto conocido**. Los candidatos sin dinero son probabilistas (Avalanche sin
stake no resiste Sybil; DAGKNIGHT) o exigen tabla de recurso escaso (espacio: P-040/F3). El análogo CAP de
Lewis-Pye–Roughgarden (`research/fuentes/lewispye-roughgarden-cap.txt:28-37`) es la razón teórica: adaptividad y
finalidad no caben en la misma regla; solo se pueden ofrecer como reglas separadas por usuario (CAP dual, P-040).

---

## 4 · Cliente ligero (secundario): #28a, #28b, weak subjectivity y servidores privados

Prioridad 2 declarada: **no se paga seguridad de irreversibilidad por ganar cliente ligero** (`ENCARGO.md:10-12`).

| Vía | Qué es | Coste anual | Confianza | Etiqueta |
|---|---|---|---|---|
| **#28a · inclusión en la cadena seleccionada + compromiso al DAG** | El cliente sigue solo la cadena lineal y verifica la prueba de Merkle de su transacción; no puede comparar dos cadenas rivales | **2-4 GB/año** (estimación; 21,5 GB/año hoy) | Parcial: confía en que la cadena servida es la de mayor `blue_work` | **PLAUSIBLE** (`informe-52:507-515`) |
| **#28b · muestreo del DAG** | Pide `n` bloques al azar de la ventana `F` y comprueba coloreado y `blue_work` contra el compromiso; `n=200`, `ε=5 %` → detección 99,997 % | ~0,6 MB por muestra, **~120 MB por comprobación** | Probabilística, sin confianza continua | **LAGUNA**: nadie lo ha diseñado para GHOSTDAG (`informe-52:517-522`) |
| **Weak subjectivity** | Checkpoint reciente firmado/social para arrancar | — | **Requiere confianza**; en ZEROX no hay stake que la justifique | **REFUTADO** como mecanismo propio |
| **Certificados P-040 (R-FIN-22)** | Cadena de certificados autosuficiente desde génesis, sin la cadena de bloques | **6,6 MB/año** (certificados de época cada 1 h) | Verificación propia, **sin confiar en nadie** | **PLAUSIBLE** (R-FIN-22 sin auditar; `capa-finalidad.md:235-258`) |
| **Servidores privados (plan B declarado)** | `zx-lightwalletd`: el cliente confía en un servidor propio | 0 en el cliente | Total en el servidor | **PLAUSIBLE** como plan B (`ENCARGO.md:10-12`; `d12-quorum/informe.md:760-774`) |

**Nota de composición:** el certificado P-040 no sustituye al cliente ligero para validar el UTXO set; prueba que un
bloque es final, no qué contiene sin la prueba de Merkle (`capa-finalidad.md:257-258`). El cliente ligero es la
ganancia mayor de P-040, pero **no es la columna que decide** y no se debe elegir P-040 por ella.

---

## 5 · ¿Se puede bajar el tiempo sin dinero en juego? Síntesis

1. **Determinista y sub-minuto:** no, con la literatura revisada. BFT, Avalanche desplegado y Casper/GRANDPA exigen
   depósito; HotPoW está refutado en PoAS. La única vía sin compra es la tabla de espacio (P-040/F3), que no tiene
   finalidad determinista sino «determinista mientras ≥2/3 del poder total firma»: a `α = 0,33` **no funciona**.
2. **Probabilista y más rápido:** DAGKNIGHT es la única promesa con paper y sin comité (1,2-12 s en sus simulaciones),
   pero sustituye la regla de orden y no está medida en ZEROX. La alternativa barata es **publicar el suelo real**:
   la ventaja `3k` es una cota; la medida es `0,56·3k`, o sea suelo real **~60-75 s**, y publicarlo como orientación
   al comerciante es legítimo aunque diseñar con la medida no lo sea (`informe-52 §31`, `:560-563`).
3. **El precio de acortar `F` se paga en frontera:** de 2 h a 1 h baja 2,03-2,59 puntos; con `F = 1 h` el 33 %
   operativo conserva 0,05 puntos en el pesimista —nada— (`d9-ronda10c/informe.md:430-435`). Y el usuario no gana
   riesgo: `prev` no lleva `F` (`:439-441`).
4. **La reformulación útil (d12 H.2):** P-040 no debería venderse como finalidad —donde se para al 33 %— sino como
   **capa de certificados para cliente ligero**; ahí su viveza rota no pierde nada (el fallback es el servidor, donde
   ya está hoy) y su seguridad (6,5e-105) es la que importa. **PLAUSIBLE.**

---

## Veredicto

| Punto | Qué se concluye | Etiqueta | Número |
|---|---|---|---|
| Baseline R-FIN-7 | El suelo de 100-134 s no lo baja ningún parámetro; el comerciante espera 241-2.931 s según `α` y modelo | **VERIFICADO** | `3k/((1−α)λ) = 100-134 s`; `1,5e-6` a 600 s (`α=0,33`, `δ=0`) |
| Avalanche | 1,35 s medidos, sin slashing, pero el despliegue exige 2.000 AVAX; sin Sybil no hay seguridad | **VERIFICADO** el número · **REFUTADO** «sin dinero» | 1,35 s · 3.400 tps · 2.000 AVAX |
| DAGKNIGHT | Orden sin parámetros y confirmación dependiente de `D`; no es finalidad ni está medido aquí | **DEMOSTRADO** en su paper · **LAGUNA** en ZEROX | 1,2-12 s en su simulación |
| Comité BFT | Los únicos que bajan a segundos de forma determinista; exigen dinero, comité y 24/7; rompen adaptividad | **DEMOSTRADO** · **REFUTADO** para ZEROX | Tendermint 3 pasos; GRANDPA `6T`; Ethereum ~12,8 min |
| P-040 / F3 | ~30 s normal; se para el 41 % de instancias a `α=0,33`; no exige compra pero castiga recompensa; diseñada para GHOSTDAG+PoAS | **PLAUSIBLE** | 30 s · 41 % · 0,76 GB/año · 6,6 MB/año |
| CAP dual rule | El molde correcto para separar finalidad y adaptividad por usuario; sin segundos fijos | **DEMOSTRADO** en su modelo · **PLAUSIBLE** en PoAS | `e + O(Δ)` |
| HotPoW | La premisa (voto atado al valor) no se cumple en PoAS | **REFUTADO** | `POA` 1,27e-12 → 0,5166 |
| Sub-minuto sin dinero y sin comité | No existe en la literatura revisada; el CAP lo impide en una sola regla | **REFUTADO** | — |
| Cliente ligero | #28a 2-4 GB/año con confianza parcial; P-040 6,6 MB/año sin confiar; servidores privados como plan B | **PLAUSIBLE** · **LAGUNA** (#28b) | 2-4 GB/año · 6,6 MB/año |

**Recomendación (PLAUSIBLE, condicionada).** No adoptar ningún comité BFT ni Avalanche: exigen dinero o comité y
rompen la adaptividad. Mantener R-FIN-7 como suelo. Tratar P-040 como la única vía de irreversibilidad rápida sin
compra, con **dos condiciones que la cambian**: (a) F1 confirma que el caso normal es realmente ~30 s y que la
caída bajo ataque no retrocede finalidad ya certificada; (b) la medida de campo de `p` del granjero doméstico. Si
alguna falla, P-040 queda como capa de cliente ligero y la irreversibilidad de ZEROX sigue siendo probabilista por
usuario, con el suelo de 100-134 s y las tablas de 10c.

---

## Errores propios

1. **Busqué el arXiv de HotStuff-2 en `2302.12868`, que es un paper de propagación de ondas en multicapas.** La
   fuente correcta es el ePrint `2023/397`. *Qué cambió:* la cita de las 2 fases quedó anclada al ePrint.
2. **Intenté `docs.avax.network/learn/avalanche/avalanche-consensus` y `.../validate/staking`; las dos dan 404.**
   Las rutas vigentes son `/docs/primary-network` (stake de 2.000 AVAX) y la portada (claims de latencia). *Qué
   cambió:* separé el número del paper (1,35 s, VERIFICADO) del marketing actual (<100 ms, no medido por mí).
3. **Confundí un momento «tiempo de irreversibilidad» con «tiempo de commit de HotPoW».** El paper no da segundos:
   da «3 bloques» y el tiempo relativo al quórum. *Qué cambió:* la fila de HotPoW no lleva segundos y se etiqueta
   por su refutación en PoAS, no por su latencia.
4. **No encontré la numeración `#58` del catálogo que cita el ENCARGO.** La capa P-040 está en
   `research/dag-poas-capa-finalidad.md` y el catálogo local llega a `#52` (`dag-poas-informe-52-problemas.md`).
   *Qué cambió:* cito el fichero de la propuesta directamente y dejo la discrepancia de numeración declarada.

## Fuentes

**Locales.** `research/fuentes/{dagknight,phantom-ghostdag,hotpow,cap-adaptividad-finalidad,lewispye-roughgarden-cap}.txt` ·
`research/dag-poas-ancla-de-orden.md` · `research/dag-poas-capa-finalidad.md` · `research/dag-poas-catalogo-problemas-ataques.md` ·
`research/dag-poas-informe-52-problemas.md` · `research/scripts/d9-ronda10c/informe.md` · `research/scripts/d12-quorum/informe.md` ·
`research/timelord-redundancia-informe.md` · código Autonomys en `/home/katana/zeo/fuentes/subspace`
(`crates/subspace-runtime-primitives/src/lib.rs:219-225`).

**Web (consultadas 2026-09-10).** `arXiv:1906.08936` (Snowball/Avalanche) · `arXiv:1807.04938` (Tendermint) ·
`arXiv:1803.05069` (HotStuff) · `eprint.iacr.org/2023/397` (HotStuff-2) · `arXiv:1710.09437` (Casper FFG) ·
`arXiv:2007.01560` (GRANDPA) · `ethereum.org/developers/docs/consensus-mechanisms/pos` ·
`docs.avax.network/docs/primary-network` · `docs.avax.network` (portada).
