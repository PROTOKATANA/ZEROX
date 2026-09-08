# Mitigaciones para los cuatro riesgos que el segundo candado no toca

**2026-09-09, madrugada.** Katana pidió analizar mecanismos que mitiguen o resuelvan: (1) el retardo de red que baja la
frontera del 46,9 % al 32,4 %; (2) el aislamiento de nodos (eclipse); (3) la carrera de bloques; (4) la cadena parásita.
Cada mecanismo lleva su fuente, lo que compra, lo que cuesta y una etiqueta (DEMOSTRADO / VERIFICADO / PLAUSIBLE / LAGUNA).
Lo que es propuesta del principal está marcado como tal y no está simulado. Los números de la ronda 10b (llegada durante
la redacción) están marcados «10b, pendiente de verificación por el principal».

Fuentes leídas hoy: `research/dag-poas-ancla-de-orden-auditoria-8a.md` §4 y `d9-ronda9a/informe.md` §5.5 (tabla `Δ`);
`auditoria-7.md` (parásita, eclipse instrumentado); `auditoria-8b.md` (R-FIN-8′/13′); `SPEC.md` C-NET-01..22, C-CHK-01..07,
C-REORG-07; `rusty-kaspa @ c338d495` (`components/addressmanager/src/lib.rs:418-460`, `kaspad/src/args.rs:115-116`,
`consensus/core/src/config/{bps.rs:60-106,constants.rs:70-81}`, `utxo_validation.rs:231-235`); `subspace @ f8842d0`
(`sc-proof-of-time/src/source/gossip.rs:30,576-600`); `research/fuentes/dagknight.{pdf,txt}` (Sutton & Sompolinsky,
eprint 2022/1494, 16 pp.); Bitcoin Core devwiki *Addrman and eclipse attacks*; `research/fuentes/phantom-ghostdag.txt` L1020-1030.

---

## 0 · Resumen

| Riesgo | Se puede «resolver» | Lo que ya hay en el diseño | Mecanismo con precedente | Propuesta nueva (principal) | Qué medir |
|---|---|---|---|---|---|
| **Δ** | No: se **acota** y se **vigila** | `k = 30` aguanta `Δ ≤ 16 s`; C-NET-03/06..10 (headers-first, bloques compactos) | k adaptativo (DAGKnight, Kaspa post-Toccata); verificación de PoT fuera de la ruta crítica (`PotCheckpoints` por gossip) | **sensor de `Δ` desde el propio DAG** (anticono observado) | `Δ_p99` en red de pruebas: la primera medición |
| **Eclipse** | Casi: se **detecta en un minuto** | C-NET-14, C-NET-20 (límites por prefijo), scoring C-NET-05/19; Kaspa: pesos por `PrefixBucket`, 8 salientes | Bitcoin Core: feeler, test-before-evict, anchors, block-relay-only, ban ADDR no pedidos, asmap | **dos sensores baratos: reloj de PoT vs reloj de pared, y bloques por slot** | tiempo hasta detección en simulación de eclipse |
| **Carrera** | No: es el límite de Nakamoto; se **tarifa** | `F = 2 h`, umbral 33 %, R-FIN-7, checkpoint único C-CHK-01..07 | Kaspa: finalidad 12 h, poda 30 h; Filecoin: capa BFT (F3) | nada nuevo: crecer el espacio honesto es la defensa | `Δ` (10b: `F` no compra `Δ`) |
| **Parásita** | Sí en lo económico (hecho); lo residual se **vigila** | R-FIN-8′/13′ (rentabilidad 0,99, reversiones 0), `merge_depth_bound` | Kaspa: `merge_depth` 1 h | el sensor de `Δ` **es** el sensor de parásita (10b: `δ_D8 = δ₀(16 s)`) | parásita + copias; incentivo a fusionar rojos |

---

## 1 · El retardo de red `Δ`

### 1.1 · Qué es exactamente el problema

El modelo de PHANTOM/GHOSTDAG supone un retardo máximo `D` conocido y calibra `k` para que el anticono honesto
supere `k` con probabilidad despreciable (`phantom-ghostdag.txt` L1020-1030; DAGKnight §1.1: *«the parameter k of
PHANTOM represents an upper bound on the network's latency»*). En nuestro diseño `k = 30` está calibrado a `Δ = 4 s`
(`verif_tau_vs_lambda.py`, punto fijo del retarget). Cuando `Δ` real sube, el anticono honesto crece, los bloques honestos
caen en rojo (`δ₀`) y la frontera baja (9a §5.5, medido):

| `Δ` | `δ₀` a `α = 0` | Frontera | vs 33 % |
|---:|---:|---:|---:|
| 4 s | 0,0000 | 46,88 % | +13,9 |
| 8 s | 0,0020 | 46,83 % | +13,8 |
| 12 s | 0,083 | 44,65 % | +11,7 |
| 16 s | 0,286 | 38,33 % | +5,3 |
| 20 s | 0,443 | 32,38 % | −0,6 |

Dos componentes distintas: **`Δ` natural** (propagación + verificación + cola de los nodos lentos) y **`Δ_ef` adversarial**
(un atacante de red que retrasa la propagación entre honestos sin gastar espacio; fuera del modelo del paper).
**10b (pendiente de verificación):** `Δ` es la palanca que manda y **`F` no la compra**: pasar de 1 h a 2 h de `F` tolera
1,9 s más de `Δ`; por encima de `Δ ≈ 22,7 s` ninguna `F` basta; `δ_D8 = 0,2867` y `δ₀(16 s) = 0,2858` son el mismo número.

### 1.2 · Mecanismos

**M1 · Mantener `Δ` natural bajo (ingeniería, sin consenso).** VERIFICADO que existe en el SPEC; sin medir su efecto.
- Bloques compactos (BIP 152) y headers-first: C-NET-03, C-NET-06..10. Pendiente de terminar en `zx-p2p` (B7 del plan).
- **Verificación del PoT fuera de la ruta crítica.** El coste de 96,1 ms/slot es por slot, no por bloque, si los
  `PotCheckpoints` llegan por gossip y se cachean (Autonomys: `gossip.rs:30`, `MAX_SLOTS_IN_THE_FUTURE = 10`; los nodos
  verifican cada slot una vez). Validar un bloque entonces no recomputa nada: comprueba que su justificación coincide con
  la cadena ya verificada. Es la LAGUNA de `C-NET-03/04` de la propuesta, y hay que escribirla así: **el PoT se verifica
  por slot al llegar por gossip; un bloque cuyo slot ya está verificado no añade coste.**
- Tamaño de bloque acotado por `LIMITE(H)` (C-NET-13) y presupuesto agregado de memoria (C-NET-21): evitan que la cola
  de los nodos lentos se dispare bajo carga.
- **Compra:** `Δ_p99` cerca del objetivo de 4-8 s. **Cuesta:** trabajo de implementación ya planificado. **Sin número
  hasta que exista el nodo.**

**M2 · Margen en `k`.** PLAUSIBLE, con número parcial.
`k` tolera `Δ` hasta que `2Δλ` se acerca a `k`: con `k = 30`, ~16 s. Subir `k` a `≈ 2Δλ + margen` (del orden de 60 para
20-24 s; estimación del principal, sin ejecutar el punto fijo) compra tolerancia. **Cuesta:** `mergeset_size_limit = 6k`
y `max_block_parents = k/2` crecen (R-FIN-12), las cabeceras pesan más, y **`F_carrera` se alarga con `k` en el modelo
`δ = 0`** (10b B.2, pendiente de verificación: «`k` grande alarga `F`»; con `δ_real(k)` la acorta 17 %). `k` es constante
de consenso: cambiarla después es hard fork, así que el margen se decide antes del lanzamiento. **Lo que hay que
ejecutar:** `verif_tau_vs_lambda.py` con `D ∈ {8, 12, 16}` para tener `k*(Δ)` y su `F_carrera`.

**M3 · Bajar `λ`.** PLAUSIBLE, sin número intermedio.
`2Δλ` cae a la mitad con `λ = 1/2` (tolerancia ~32 s con `k = 30`). La rama (B) del análisis (`λ = 1/6`) mostró que se
pierden 7 órdenes de reversión a 600 s y la latencia sube a 6 s; `λ = 1/2` no está calculado. **Cuesta:** latencia 2 s,
reversión a 600 s peor (menos bloques), y rederivar `k`, `I`, `m`. Es la palanca más barata en ingeniería y la más cara
en propiedades del DAG.

**M4 · `k` adaptativo: DAGKnight.** LAGUNA grande, vía de largo plazo.
- Qué es (`dagknight.txt`, abstract y §1.1, leídos): *«the first permissionless protocol which contains no a priori
  in-protocol bound over latency»*; la optimización pasa de «máximo `k`-cluster con `k` fijo» a **«mínimo `k` tal que el
  máximo `k`-cluster cubre al menos la mitad del DAG»** (*Minimal k Majority Cluster*). El cliente fija localmente
  *«an upper bound over the maximum adversarial recent latency»* solo para decidir cuándo confirmar; el orden no depende de
  ese parámetro. Tolera hasta 50 % del hashrate.
- Estado en Kaspa: mainnet corre GHOSTDAG; `bps.rs:66-68` («*or moving to the parameterless DAGKNIGHT*») y
  `utxo_validation.rs:231-235` (reglas escritas «*to maintain compatibility with protocols like DAGKNIGHT*») muestran
  que el código se está preparando; prototipo en Rust público; hoja de ruta: después de Toccata (activación prevista
  junio 2026). **No hay red en producción con DAGKnight.**
- **Compra:** `δ₀ ≈ 0` para cualquier `Δ` real sin recalibrar nada; un atacante que infla `Δ` artificialmente **ralentiza
  las confirmaciones en vez de bajar la seguridad** (responsividad). Es la única respuesta estructural al riesgo.
- **Cuesta:** todo el análisis es para PoW (hashrate). Bajo PoAS hubo que rehacer cada teorema de GHOSTDAG (ese es el
  historial entero de P-038: nueve rondas). DAGKnight exigiría lo mismo: meses, sin implementación de referencia. Cambia
  `mergeset`, `blue_work` y el ancla. **No para v1.** Lo que sí se puede hacer ahora: que el orden sea una pieza
  sustituible del nodo (Kaspa lo está haciendo) para no cerrar la puerta.

**M5 · Un sensor de `Δ` leído del propio DAG.** PLAUSIBLE, propuesta del principal, sin simular.
El tamaño del anticono de cada bloque honesto es una medida directa de `2Δλ` (Poisson en el modelo; 9a midió que la cola
real es menor que Poisson). Un nodo puede estimar `Δ_ef` de forma continua a partir de la distribución de anticonos y de
la fracción de rojos observada, y compararla con la calibración de `k`. Si `δ_obs` supera `δ₀(Δ_max)`, o `Δ` real ha
subido o alguien parasita: **en los dos casos el colchón del 33 % se ha erosionado y hay que avisar.** No toca consenso:
es monitorización, se implementa en el nodo y se publica como métrica. **Compra:** convertir una LAGUNA («`Δ` sin medir»)
en una magnitud observada en producción. **Cuesta:** nada de consenso; un módulo de métricas.

**M6 · Contra `Δ_ef` adversarial.** Es un ataque de red, no de espacio: se combate con §2 (eclipse parcial) y con los
presupuestos de C-NET-11/13/21 y el scoring de B7. No hay mecanismo de consenso que lo cierre; solo la diversidad de
pares y el sensor M5 que lo hace visible.

### 1.3 · Recomendación

1. **Medir `Δ_p99`** en red de pruebas con el nodo completo (verificación de PoT incluida, con carga y con un atacante
   de red que retrase). Es la primera medición del diseño; nada la sustituye.
2. **M1 entero** antes de la beta, incluida la regla «PoT por slot, no por bloque» en C-NET-03/04.
3. **Ejecutar M2 con número** (`k*(Δ)` y su `F_carrera` para `Δ ∈ {8, 12, 16}`) y decidir `k` con etiqueta de tolerancia
   antes del lanzamiento, porque después es hard fork. Mi apuesta sin número: `k = 30` si `Δ_p99 ≤ 8 s`; `k = 40` si
   está entre 8 y 12 s.
4. **M5** como métrica del nodo desde el primer día.
5. **M4** como línea de investigación post-beta, y diseñar el nodo con el orden como pieza sustituible.

---

## 2 · El aislamiento de nodos (eclipse)

### 2.1 · Qué es aquí, y qué tiene de distinto bajo PoST

Clásico: el atacante controla todas las conexiones de la víctima y le muestra una vista falsa (doble gasto contra un
comerciante). Específico de este diseño, medido en D8 A3 (`auditoria-7.md`): un granjero aislado o retrasado 200 s
**pierde el 77 % de sus bloques como inválidos** por R-FIN-1a/`S_max`, no como huérfanos; y en diseños anteriores un
eclipse de 15 min podía apagar el nodo (`dag-poas-inyeccion-auditoria.md` hallazgo 3; corregido al eliminar R-INJ-2 y al
reescribir R-FIN-7 «ignora, no apaga»).

### 2.2 · Lo que ya hay

- SPEC: C-NET-14 (mDNS desactivado en mainnet), **C-NET-20 (límites de conexión y baneo por prefijo de red, no por
  `PeerId`)**, C-NET-05/19 (lento ≠ malicioso; condenado no se le vuelve a pedir), C-NET-13/21 (presupuestos).
- Kaspa (adoptable, `rusty-kaspa`): selección de direcciones **ponderada por `PrefixBucket`** para repartir las
  conexiones entre prefijos (`components/addressmanager/src/lib.rs:421-460`, `ip_weight = 64^(x−y)/n`), 8 salientes y
  128 entrantes por defecto (`kaspad/src/args.rs:115-116`).

### 2.3 · Mecanismos con precedente: Bitcoin Core (devwiki *Addrman and eclipse attacks*, leído)

| Contramedida | Versión | Qué hace |
|---|---|---|
| Desalojo aleatorio determinista | pre-0.19 | cada dirección va a un único slot de un único bucket |
| Selección aleatoria | pre-0.19 | sin sesgo hacia sellos recientes; el atacante necesita llenar el 91,7 % de `tried` |
| Más buckets | 2015 | más grupos necesarios para la misma fracción |
| **Feeler connections** | 0.14 | conexiones cortas para comprobar que una dirección de `new` está viva |
| **Test-before-evict** | 0.14 | antes de sustituir una dirección de `tried`, se prueba la vieja |
| No `inbound → tried` | pre-0.19 | solo las salientes alimentan `tried` |
| **Anchors** | 0.21 | dos pares block-relay-only persisten entre reinicios |
| Ban de ADDR no solicitados | 0.22 | límite de tasa a inundaciones de direcciones |
| **Block-relay-only** | 0.19 | dos salientes que solo relevan bloques, sin tx ni addr |
| Asmap (ASN) | propuesto | diversificar por sistema autónomo en vez de por /16 |

Todas son de nodo, no de consenso. Ninguna está hoy en el SPEC de ZEROX salvo la diversidad por prefijo.

### 2.4 · Propuestas nuevas, específicas de PoST (principal; PLAUSIBLE, sin simular)

**E1 · Sensor de reloj.** El PoT es un reloj que el atacante **no puede falsificar**, solo retener o retrasar. Con la
atadura sello-slot propuesta en `DECISIONES.md` §19 (`|timestamp − (TIEMPO_GENESIS + slot·σ)| ≤ B`), un nodo cuyo PoT
recibido va por detrás de su reloj de pared más de `B` sabe que **o está aislado o el timekeeper ha caído**; en los dos
casos MUST NOT producir bloques (serían inválidos por `S_max`) y MUST alertar y renovar pares. Autonomys ya rechaza PoT
«demasiado en el futuro» (`gossip.rs:584`, 10 slots) y «viejo» (`gossip.rs:576-582`); el sensor es la lectura inversa.

**E2 · Sensor de tasa.** Si el atacante deja pasar el PoT real pero filtra los bloques honestos, el nodo ve el reloj
avanzar y llegar solo `α·λ` bloques por segundo en vez de `λ = 1`. En 60 s la probabilidad de ver ≤ 20 bloques con
`λ = 1` es del orden de `10⁻¹¹` (cola de Poisson; cálculo del principal). Un comerciante con este sensor **no confirma**
nada mientras la tasa observada esté fuera de banda. Es la defensa directa contra el doble gasto por eclipse.

**E3 · El PoT como canal independiente.** Los `PotCheckpoints` son autoverificables y pesan 128 B/slot: pueden relevarse
por un segundo transporte (otro tema de gossip, o un canal fuera de banda) que el atacante tendría que cortar también.

### 2.5 · Recomendación

Añadir al SPEC, en B7 (`zx-p2p`), la tabla de Bitcoin Core como reglas C-NET (feeler, test-before-evict, anchors,
block-relay-only, límite de ADDR, diversidad por prefijo con el peso de Kaspa), y E1/E2 como comportamiento obligatorio
del nodo (MUST NOT autor, MUST alertar). Ninguna toca consenso. Medir en simulación el tiempo hasta detección.

---

## 3 · La carrera de bloques

### 3.1 · Qué es y por qué no se «resuelve»

Un atacante con fracción `α` del espacio construye un flujo privado y lo publica dentro de `F`. Es el ataque de Nakamoto:
ningún protocolo de cadena más larga lo cierra por debajo del 50 %. La frontera de flujo único es 46,9 % a `Δ = 4 s` con
`F = 5,3 h` y 44,6 % con `F = 2 h` (`verif_frontera_vs_F.py`). Esos 3-5 puntos por debajo del 50 % son la varianza de la
carrera y la ventaja inicial `3k`. Chia, por comparación, está en ~40 % por el *double dipping* (factor 1,47); aquí no lo
hay porque R-FIN-5 impone un solo flujo.

### 3.2 · Palancas, con número (10b, pendiente de verificación por el principal)

| Palanca | Efecto sobre `F_carrera` al 33 % |
|---|---|
| `Δ` de 4 s a 16 s | ×3,5 |
| `F` de 1 h a 2 h | tolera **1,9 s** más de `Δ` |
| Ventaja `3k → 1,68k` | −3,2 min |
| Objetivo `1e-12 → 1e-6` | −4,1 min |
| `I` de 300 a 4 200 s | +4,7 % |

**Conclusión de 10b:** `F = 2 h` es la más corta que sobrevive a los seis modelos; por debajo de `Δ ≈ 14 s` el suelo de `F`
lo pone el término de steering `I/(W/κ − 1)` (0,62-1,07 h) y no la carrera; producción `F = 1 h` condicionada a
`Δ_p99 ≤ 14,9 s`. **Corrección al principal:** la bitácora §11.4 decía «el suelo lo pone el corredor, no el steering»;
eso vale solo para `Δ ≥ 14 s`.

### 3.3 · Mecanismos

**C1 · Tarifar: `F`, umbral publicado y R-FIN-7.** VERIFICADO. Es lo que hay: 33 % con colchón medido, `F = 2 h`, y la
regla de no reorganizar por debajo de `F` ignorando la punta en vez de apagar el nodo.

**C2 · El checkpoint de lanzamiento (C-CHK-01..07).** VERIFICADO que existe. Un único checkpoint firmado, válido solo
con la red por encima de 3,2 PiB y caducado a los dos años, que fija la rama canónica sin poder acuñar ni censurar. Cubre
exactamente la ventana en que el 33 % del espacio es barato. Es el mecanismo correcto para el arranque y ya está escrito.

**C3 · Precedente de Kaspa: finalidad por profundidad.** `FINALITY_DURATION = 43 200` bloques (12 h),
`PRUNING_DURATION = 108 000` (30 h), `MERGE_DEPTH_DURATION = 3 600` (1 h) (`constants.rs:70-81`). Kaspa, con PoW y umbral
50 %, usa **12 h** de finalidad; ZEROX propone 2 h con umbral 33 %. Nuestra `F` es seis veces más corta con menos margen
de umbral: es coherente con la reversión medida (Skellam con `3k`), pero conviene decirlo con esa comparación delante.

**C4 · Finalidad por comité (BFT sobre el DAG).** LAGUNA, fuera de v1. Filecoin añadió una capa BFT (F3) en 2025 tras
su umbral real del ~20 % (`dag-consenso-poas.md`). Es la única forma de obtener finalidad **por debajo del umbral de
espacio**: un conjunto de validadores firma puntos de la cadena. **Cuesta:** un conjunto de validadores con identidad y
sus incentivos, otra capa de consenso, y una confianza que hoy el diseño no tiene. Se queda como opción post-beta si
alguna vez se quiere finalidad en minutos con umbral por encima del 33 %.

**C5 · La defensa real: espacio honesto.** El coste del ataque es poseer `α` del espacio de la red durante `F`, no
alquilar GPU: por eso importa que las parcelas no sean comprimibles ni regenerables al vuelo (la lección de PoS 2.0 de
Chia, `CLAUDE.md`). LAGUNA a cerrar con `zx-autonomys`: cuál es el compromiso tiempo-memoria real de las parcelas de
Autonomys. Crecer el espacio honesto es lo único que sube el precio del ataque de forma permanente.

### 3.4 · Recomendación

Aceptar la carrera como riesgo tarifado: publicar 33 % con `F = 2 h` y el colchón por modelo (tabla de 10b, tras
verificarla); mantener C-CHK; medir `Δ`; cerrar la LAGUNA de compresibilidad de parcelas; C4 solo post-beta y solo si se
acepta un comité.

---

## 4 · La cadena parásita

### 4.1 · Qué es y qué queda de ella

D8 A1 (`auditoria-7.md` §1.1, modelo cerrado en `verif_parasita.py`): la regla del `k`-cluster regala `k` azules honestos
de ventaja; el atacante publica ráfagas de `J* = kα/(1−2α)` bloques y tiñe de rojo `δ = α/(1−α)` de los honestos. Es
legal, invisible para R-FIN-7 y no cuesta espacio extra. Lo que cerró 9b con **R-FIN-8′ + R-FIN-13′** (VERIFICADO, 12
semillas): rentabilidad 1,16-1,55 → 0,99-1,00; ningún honesto pierde recompensa (`S1_h = 1,0000`); inflación del retarget
×1,45 → ×1,005. Y 9a demostró que el `δ` de la parásita **no entra en la carrera** (doble conteo): la frontera no baja.

Residual, declarado por 9b y 9a: el `δ` en sí (bloques honestos en rojo, ahora pagados), que parasitar es gratis a `α`
pequeño, y tres lagunas: parásita + copias a la vez, incentivo a fusionar rojos (con coinbase propia nadie cobra por
incluir), `mergeset_non_daa`.

### 4.2 · Mecanismos

**P1 · Hecho: R-FIN-8′/13′.** VERIFICADO. Lo que quedaba de daño económico está cerrado.

**P2 · `merge_depth_bound` (Kaspa, adoptado en R-FIN-12).** VERIFICADO que existe. Un bloque parásito más viejo que la
profundidad de fusión (Kaspa: 1 h) no se fusiona salvo kosherizado; acota cuánto puede envejecer una ráfaga antes de
publicarse. No reduce `δ`, reduce la ventana.

**P3 · El sensor de `Δ` es el sensor de parásita.** PLAUSIBLE, y con un dato que lo sostiene: 10b encontró que
`δ_D8 = 0,2867` y `δ₀(16 s) = 0,2858` **son el mismo número**. Desde fuera, una parásita y un `Δ` alto son
indistinguibles, y da igual: los dos erosionan el mismo colchón. La regla operativa es una sola: si la fracción de
rojos observada supera `δ₀(Δ_max)` de forma sostenida, alerta.

**P4 · Reducir `δ` estructuralmente.** No existe dentro de GHOSTDAG: el `k`-cluster es la regla. Bajar `k` reduce el
regalo pero `k` lo fija `Δ`. DAGKnight (§1.2 M4) cambia la regla a «cluster mayoritario», donde un atacante con menos de
la mitad no puede imponer su cluster; qué hace a la parásita es LAGUNA, y sería parte del mismo análisis largo.

**P5 · Cerrar las tres lagunas.** Trabajo de una ronda adversarial: medir parásita + copias con R-FIN-8′; decidir si el
fusionador cobra algo pequeño por incluir rojos (9b midió que pagar al fusionador **duplica** la parásita, así que la
cantidad tendría que ser mucho menor que en Kaspa, o cero); escribir `mergeset_non_daa`.

### 4.3 · Recomendación

Aceptar el residuo como tarifado, publicar el sensor P3 como métrica, y encargar P5 a la siguiente ronda adversarial
sobre el diseño corregido.

---

## 5 · Lo que hay que medir, en orden

1. **`Δ_p99`** en red de pruebas, con verificación de PoT y atacante de red. Decide `k`, `F` de producción y el colchón.
2. **`k*(Δ)` y `F_carrera(k, Δ)`** con `verif_tau_vs_lambda.py` para `Δ ∈ {8, 12, 16}` (M2).
3. **Tiempo hasta detección** de E1/E2 en simulación de eclipse.
4. **Compresibilidad de las parcelas de Autonomys** (C5).
5. **Parásita + copias** e incentivo a fusionar rojos (P5).

Fuentes web consultadas el 2026-09-09: [DAG KNIGHT, eprint 2022/1494](https://eprint.iacr.org/2022/1494) ·
[Bitcoin Core devwiki, Addrman and eclipse attacks](https://github.com/bitcoin-core/bitcoin-devwiki/wiki/Addrman-and-eclipse-attacks) ·
[Kaspa: DAGKnight después de Toccata](https://kaspa.org/kaspa-development-milestones-revealed-2025/).
