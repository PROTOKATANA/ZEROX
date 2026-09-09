# Los 52 problemas de PoST + DAG: causa, solución propuesta, efecto sobre el número y qué verificar

**2026-09-09, noche, en modo autónomo por mandato de Katana** («investigar y explorar nuevas soluciones que puedan conducir a
un mejor camino para la implementación de PoST + DAG»). Una sección por problema, en el orden y con el número de
`research/dag-poas-catalogo-problemas-ataques.md` (la numeración 1-52 es la de la lista que Katana dejó). Cada sección lleva:
**causa**, **solución o mejora concreta** (mecanismo, no dirección), **cuánto arregla y qué rompe**, **cómo cambia el número**
si es calculable, y **qué hay que verificar** (matemática, simulación o medida). Todo lo que no está medido ni citado va marcado
**HIPÓTESIS** o **ESTIMACIÓN**; lo verificado cita su fuente. Dos agentes corren en paralelo mientras se escribe esto (11a: `k`
frente a `Δ`; 11b: sensores de eclipse); sus números entrarán en las secciones 1 y 2 cuando lleguen y estén verificados.

**Fuentes de partida:** `dag-poas-ancla-de-orden.md` §2 (R-FIN-1..14), auditorías 7, 8a-8c, 9a-9b, informes de las rondas
10a/10b/10c, `dag-poas-mitigaciones-cuatro-riesgos.md`, `pot-aes-asic-chacha.md`, `timelord-redundancia-informe.md`, el paper de
PHANTOM/GHOSTDAG (`research/fuentes/phantom-ghostdag.txt`), DAG KNIGHT (`research/fuentes/dagknight.txt`), BDK19, Kaspa
`@ c338d495`, Autonomys `@ f8842d0`, Chia v2.7.4.

**Convención de números.** Constantes vigentes: `λ = 1 bloque/s`, `τ = 1 s`, `k = 30`, `S_max = 150 s`, `W_dec ≤ 45 s`,
`F = 2 h` provisional, `I = 851 s` (candidato, `ρ_max = 3`), umbral operativo 33 %, `Δ = 4 s` supuesto. Verificación de PoT
96,1 ms/slot, prueba 1,561 s/slot en el 9950X3D.

---

# Parte I · Abiertos, sin contramedida en el diseño

## 1 · Retraso de red adversarial

**Causa.** GHOSTDAG colorea de azul los bloques cuyo anticono es `≤ k`. El anticono de un bloque honesto crece con el retardo
efectivo `Δ` como `≈ 2Δλ` en media; cuando `2Δλ` se acerca a `k`, los bloques honestos empiezan a caer en rojo sin que el
atacante haga nada (`δ₀`), y la carrera de flujo único se juega con menos peso honesto. Medido (9a §5.5, `α = 0`, 12 semillas):
`δ₀` = 0,000 / 0,002 / 0,083 / 0,286 / 0,443 a `Δ` = 4 / 8 / 12 / 16 / 20 s; frontera 46,9 / 46,8 / 44,7 / 38,3 / 32,4 %. Y 10b:
`F` no compra `Δ` (1 h → 2 h tolera 1,9 s más); techo `Δ = 22,7 s` donde `r = 1`. `Δ` tiene dos componentes: la natural
(propagación + verificación + cola de los nodos lentos) y la adversarial (un atacante de red que retrasa a los honestos sin
gastar espacio; fuera del modelo del paper, L1024-1027).

**Soluciones concretas, cuatro capas.**

**1a · Reducir la `Δ` natural (ingeniería, sin consenso).** (i) Bloques compactos C-NET-06..10 y headers-first C-NET-03 (ya en
el SPEC; B7 del plan pendiente). (ii) **Regla nueva: el PoT se verifica por slot al llegar por gossip, nunca por bloque.** Los
`PotCheckpoints` de cada slot llegan por el tema de PoT, se verifican una vez (96,1 ms, paralelizable) y se cachean; un bloque
cuyo slot ya está verificado no añade coste a la validación. Autonomys lo hace así (`gossip.rs:576-600`). Sin esta regla, un
nodo que valide bloques recomputando su justificación paga 96 ms × slots desde el padre en la ruta crítica de propagación.
(iii) Presupuestos C-NET-13/21 para que la cola de los nodos lentos no se dispare bajo carga. **Cuánto arregla:** mantiene
`Δ_p99` cerca de la propagación pura (ESTIMACIÓN: 2-6 s en una red de decenas de nodos con bloques de 128 kB; Kaspa opera a
1 bps con `k = 18` asumiendo `D ≤ 10 s`, `dagknight.txt` §1.1). **Qué rompe:** nada. **Verificar:** `Δ_p99` en red de pruebas.

**1b · Margen en `k`.** Subir `k` desplaza el punto donde `2Δλ` se acerca a `k`. ESTIMACIÓN previa a 11a: `k` tolera hasta
`Δ ≈ k/2 − margen`, es decir `k = 40` → ~20 s, `k = 60` → ~28 s; la ronda 11a lo mide con `δ₀(Δ, k)` real. **Cuánto cuesta:**
`mergeset_size_limit = 6k` y `max_block_parents = k/2` (R-FIN-12): cabecera de ~4 padres pasa a ~5-6 en régimen (ESTIMACIÓN
+32-64 B, +1-2 GB/año); `F_carrera` con `δ = 0` se alarga con `k` (10b B.2: +282 s de `k = 20` a 40); coste de coloreado
GHOSTDAG por bloque crece con `k` (cota `O(k²)` por bloque en el paper de PHANTOM, algoritmo 1; LAGUNA el coste medido en
`rusty-kaspa`). **Qué rompe:** nada cerrado; el punto 20 (griefing del mergeset) sigue cerrado porque `pick_virtual_parents`
escala con `k`. **`k` es constante de consenso:** cambiarla después es hard fork (entra en el coloreado de todo bloque,
`protocol.rs:99-106`). **Decisión:** fijar `k` con la etiqueta de `Δ` tolerado antes del lanzamiento, no después.
**Verificar:** la tabla de 11a; después, `Δ_p99` medido.

**1c · Bajar `λ`.** `2Δλ` cae a la mitad con `λ = 1/2`: la misma `k = 30` toleraría ~32 s (ESTIMACIÓN). **Cuánto cuesta:**
latencia a inclusión 2 s; menos bloques por ventana ⇒ reversión a 600 s peor (la rama (B) a `λ = 1/6` perdía 7 órdenes;
`λ = 1/2` no calculado, 11a E lo calcula); rederivar `I`, `m`, `W_dec`. **Qué rompe:** el punto 8 (sembrador) cambia porque
`W_dec` y `m` se miden en bloques. **Verificar:** 11a E.

**1d · `k` adaptativo (DAG KNIGHT).** Cambio de algoritmo: en vez del máximo `k`-cluster con `k` fijo, el **mínimo `k` tal que
el máximo `k`-cluster cubre ≥ 50 % del DAG** (`dagknight.txt` §1.1, «Minimal k Majority Cluster»). Sin cota de latencia en el
protocolo; el cliente fija localmente una cota de latencia adversarial reciente solo para decidir cuándo confirmar. **Cuánto
arregla:** `δ₀ ≈ 0` para cualquier `Δ` real; un atacante que infla `Δ` **ralentiza las confirmaciones en vez de bajar la
seguridad** (responsividad). Es la única respuesta estructural. **Qué rompe / cuesta:** todo el análisis es para PoW (hashrate);
bajo PoAS habría que rehacer lo que P-038 hizo con GHOSTDAG (nueve rondas): el ancla por slot (R-FIN-1) y el peso
`blue_work` dependen de un `k` fijo; U3″ colorea con `k`; R-FIN-12 usa `6k` y `k/2`. Kaspa lo tiene en prototipo y planificado
para después de Toccata (mitad de 2026); sin red en producción. **HIPÓTESIS de compatibilidad:** el ancla por índice de PoT
(R-FIN-1) sobrevive a KNIGHT porque no depende de `k` sino de `slot` y `blue_work`; U3″ y R-FIN-12 no. **Decisión:** no para
v1; diseñar el nodo con el orden como pieza sustituible (Kaspa ya escribe reglas «compatible with DAGKNIGHT»,
`utxo_validation.rs:231-235`). **Verificar:** un análisis de KNIGHT bajo PoAS con el mismo método (meses).

**1e · Sensor de `Δ` desde el DAG (monitorización, sin consenso).** Cada nodo estima `2Δλ` de la distribución de tamaños de
anticono de los bloques honestos y de la fracción de rojos observada, y la compara con la calibración de `k`. Regla operativa:
si `δ_obs` supera `δ₀(Δ_max)` de forma sostenida (ESTIMACIÓN de umbral: `δ_obs > 0,05` durante 10 min ≈ `Δ_ef > 11 s`), alerta al
operador y a los comerciantes (bajan a confirmaciones más largas). **Cuánto arregla:** no baja `Δ`, pero convierte la LAGUNA
35 en una magnitud observada en producción, y es el mismo sensor que detecta una parásita (10b: `δ_D8 ≡ δ₀(16 s)`). **Qué
rompe:** nada. **Verificar:** en simulación, la relación anticono ↔ `Δ` con la cola real (9a midió que Poisson sobreestima).

**Cómo cambia el número.** Con `k = 40` (ESTIMACIÓN hasta 11a): el 33 % conserva colchón hasta `Δ ≈ 20 s` en vez de 16; con
`λ = 1/2` y `k = 30`, hasta ~32 s a cambio de la reversión a 600 s. Con KNIGHT, el colchón deja de depender de `Δ` y pasa a
depender solo del espacio (46,9 %-50 %), al precio de confirmaciones que se alargan cuando la red va mal.

**Verificar, en orden:** (1) `Δ_p99` en red de pruebas con verificación de PoT dentro y atacante de red; (2) tabla 11a;
(3) la relación anticono ↔ `Δ` para el sensor; (4) KNIGHT bajo PoAS como línea de investigación.

## 2 · Eclipse de un nodo

**Causa.** Un atacante que controle todas las conexiones de la víctima le muestra una vista falsa. En Bitcoin el daño es el doble
gasto contra un comerciante eclipsado. Aquí hay dos daños más, medidos: (a) un granjero con 200 s de retraso pierde el 77 % de
sus bloques como **inválidos** por R-FIN-1a/`S_max` (D8 A3, re-instrumentado); (b) en diseños anteriores el nodo se apagaba
(corregido: R-FIN-7 «ignora, no apaga»). El SPEC solo tiene mDNS apagado (C-NET-14) y límites por prefijo (C-NET-20).

**Solución concreta, tres capas (todas de nodo, ninguna de consenso).**

**2a · La tabla de Bitcoin Core, como reglas C-NET.** Del devwiki *Addrman and eclipse attacks* (leído): desalojo aleatorio
determinista y selección aleatoria de la tabla de direcciones; **feeler connections** (cada ~2 min, una conexión corta a una
dirección de `new` para comprobar que está viva); **test-before-evict** (antes de desalojar una dirección de `tried`, se prueba);
solo las salientes alimentan `tried`; **anchors** (dos pares solo-bloques persisten entre reinicios); **block-relay-only** (dos
salientes que solo relevan bloques, sin tx ni addr); límite de tasa a ADDR no solicitados; diversidad por prefijo con el peso
de Kaspa (`addressmanager/src/lib.rs:421-460`: `ip_weight = 64^(x−y)/n`, `n` = direcciones en el mismo prefijo). **Cuánto
arregla:** en Bitcoin, pasar del 91,7 % de la tabla `tried` a llenar antes de eclipsar; con 8 salientes por prefijo, el
atacante necesita direcciones en muchos prefijos distintos (11b D lo cuantifica contra el esquema de Kaspa). **Qué rompe:**
nada. **Verificar:** 11b D.

**2b · Sensor E1, el reloj.** Regla: sea `slot_pot` el último slot de PoT verificado por el nodo y `t_pared` su reloj local; con la
atadura sello-slot de `DECISIONES.md` §19, `|t_pared − (T0 + slot_pot·τ)| ≤ B`. Si el PoT recibido va por detrás del reloj de pared
más de `B`, el nodo **MUST NOT** producir bloques (serían inválidos por `S_max` o entrarían en un flujo ajeno), **MUST** marcar
«sin reloj», alertar, y renovar todas las salientes (nuevo muestreo de `tried` por prefijo). El atacante no puede falsificar el
PoT (es una cadena AES determinista, R-FIN-14): solo retenerlo. E1 no distingue eclipse de caída del timekeeper, y no hace
falta: en los dos casos la acción correcta es la misma. **ESTIMACIÓN de `B`:** `S_max/2 = 75 s` con deriva NTP de ±1 s y
`Δ_p99 ≤ 16 s` da falsas alarmas ≪ 1/año (11b B lo calcula con una cola lognormal declarada). **Cuánto arregla:** la variante
«retener el PoT» se detecta en `B` segundos. **Qué rompe:** nada.

**2c · Sensor E2, la tasa.** Regla: el nodo cuenta bloques recibidos por ventana de `W` slots; con `λ = 1`, `N ~ Poisson(W)`.
Si `N < n_min(W)`, alarma. ESTIMACIÓN con Poisson puro: para `W = 60 s`, `P(N ≤ 20) ≈ 10⁻¹¹`; umbral `n_min = 30` da falsas
alarmas `≈ 10⁻⁵` por ventana (~5/año con ventanas deslizantes cada minuto; 11b C afina con la varianza real del DAG). Un
eclipse que deje pasar el PoT y filtre bloques honestos entrega `α·λ`: con `α = 0,33`, 20 bloques por minuto, detectable en
1-2 min; con `α = 0`, en 30 s. **Regla del comerciante:** bajo alarma E1 o E2, ninguna transacción se considera confirmada.
**Cuánto arregla:** el doble gasto contra un comerciante eclipsado exige mantenerlo sin alarma, y la única forma es entregarle
el PoT real y ≥ `n_min` bloques por minuto, es decir, bloques honestos reales: entonces ya no está eclipsado del DAG, solo
de una parte, y R-FIN-7 y la fusión de Kaspa lo curan al reconectar. **Qué rompe:** nada; el punto 20 (`shuffle`) ayuda:
padres al azar diversifican de quién se aprende. **Verificar:** 11b C (tiempo de detección, falsas alarmas), y en red.

**2d · El PoT como canal independiente (E3).** Los `PotCheckpoints` son autoverificables y pesan 128 B/slot; relevarlos por
un segundo transporte (otro tema de gossip por pares distintos, o un canal HTTPS de los operadores de timekeeper) obliga al
atacante a cortar dos canales. HIPÓTESIS: coste bajo (4 GB/año ya se pagan); beneficio alto contra la variante «retener».

**Cómo cambia el número.** El 77 % de bloques inválidos de un granjero eclipsado pasa a «0 bloques producidos durante el
eclipse y alarma en ≤ `B` s» (mejor: no pierde recompensa que no habría cobrado y no alimenta al atacante). El doble gasto
contra comerciante pasa de «posible mientras dure el eclipse» a «posible solo si el atacante entrega PoT real y ≥ `n_min`
bloques honestos reales por minuto», que es una partición real y no un eclipse. ESTIMACIÓN de tiempo hasta detección: 30-120 s.

**Verificar:** 11b B/C/D; después, en red: distribución real de retrasos honestos (para `B`) y varianza real de bloques por
ventana (para `n_min`).

## 3 · Timekeeper único

**Causa.** El PoT lo produce quien esté configurado como timekeeper; Autonomys tiene un TODO para arrancar secundarios desde
checkpoints (`source.rs:291`) sin implementar. Sin PoT no hay slots y la red se para. Y `autonomys/subspace#2141` (cerrada
*not planned*): un timekeeper más lento ve sus mensajes rechazados por viejos; cada generación de hardware deja obsoletos a los
demás; *«we are not aware of a mechanism how this could be mitigated»*.

**Solución concreta.**

**3a · Redundancia sin coordinación (B7, C-TIMELORD-01..03), completada.** Cualquier nodo puede producir PoT; varios operadores
lo hacen a la vez; los nodos aceptan el primero válido (todos son idénticos por determinismo). Lo que B7 deja sin escribir y
aquí se propone: **(i) arranque automático de secundario**: todo nodo con el flag `timekeeper=standby` mantiene la cadena AES
al día **verificando** (96 ms/slot) y, si no recibe un checkpoint nuevo en `G` slots (ESTIMACIÓN `G = 3`), pasa a **producir**
desde el último checkpoint verificado; vuelve a standby cuando recibe uno ajeno más adelantado. Es exactamente el TODO de
Autonomys, y no necesita consenso: el PoT es determinista. **(ii) Descubrimiento de standby** por el gossip de PoT (un mensaje
«estoy en standby a `slot s`»), sin identidad. **Cuánto arregla:** la caída del primario cuesta `G` slots de parón, no la red.
**Qué cuesta:** cada standby paga la verificación continua (ya la paga todo nodo) más un núcleo rápido en reserva.
**Qué rompe:** nada.

**3b · La centralización por velocidad (#2141), acotada.** No se puede evitar que el más rápido «gane», pero sí que **importe**:
en este diseño el reloj más rápido no fija el umbral de seguridad (a diferencia de Chia), solo el steering (√ρ, punto 6). Por
eso la política es: **ZEROX opera ≥ 3 timekeepers de clase 14900KS en tres proveedores**, y publica el hardware de referencia;
cualquier tercero con el mismo hardware corre a la par. HIPÓTESIS: con hardware de consumo de gama alta, la dispersión entre
operadores es < 5 % (AESENC 3 ciclos en Raptor Cove y Zen 5, uops.info), así que «el más rápido» es un empate y los
secundarios no quedan obsoletos. **Verificar:** medir `prove` por slot en tres máquinas de gama alta distintas.

**3c · Vivacidad sin ningún timekeeper: degradación en vez de parón.** HIPÓTESIS de regla: si un nodo lleva `G_max` slots
(ESTIMACIÓN 60 s) sin PoT nuevo, entra en modo «reloj degradado» y **no produce bloques**, pero sigue validando y relevando lo
recibido. No hay forma de producir bloques sin PoT (es el reto), y no debe haberla: el diseño de Autonomys lo asume («*if there is
no timekeeper, the chain halts*»). Lo que se compra es que el reinicio sea limpio: al volver el PoT, todos los nodos están en el
mismo estado. **Qué rompe:** nada.

**Cómo cambia el número.** Parón por caída del primario: de «indefinido hasta intervención humana» a `G ≈ 3 s` con standby
automático. Número de timekeepers efectivos: de 1 a ≥ 3 + standbys voluntarios.

**Verificar:** implementar standby en `zx-node` sobre el clon de Autonomys (`sc-proof-of-time`) y probar la conmutación con
`G ∈ {2, 3, 5}`; medir la dispersión de `prove` entre máquinas.

## 4 · Lado de partición sin hardware (solo con el segundo candado)

**Causa.** Con (h), cada época en vuelo exige una cadena AES más; un lado de partición debe sostener `q + 1 = ⌈L/I⌉ + 1` líneas
para que sus revelaciones lleguen a tiempo. Con `I = 851 s`, `L = 2 h`: 10 líneas; con 4 núcleos la revelación llega 3 h
tarde y el lado no produce bloques válidos desde su primer `t_j` aunque conserve todo su espacio (10a B.4, VERIFICADO
aritméticamente sobre el microbanco). Contradice la letra de R-FIN-7 y no se compensa con espacio.

**Solución concreta.**

**4a · Calibrar (h) a `ρ_max = 2,5`** (10a C.5): `I = 4 725 s`, `q + 1 = 3` líneas: cualquier PC de gama alta las sostiene
(10a B.3: 25 líneas simultáneas degradan un 1,7 %). El vector no desaparece, pero su umbral baja de «diez núcleos rápidos» a
«tres», que es el mismo suelo que ya exige el timekeeper de un lado (punto 3). **Cuánto cuesta:** `I + F` sube a 3,3 h
(lookahead frente al sembrador, punto 8). **Qué rompe:** nada cerrado.

**4b · Regla de degradación de época en partición.** HIPÓTESIS de regla: si un lado no puede sostener sus revelaciones, sus
bloques con `slot ≥ t_j` son inválidos (R-FIN-4 con (h.3′)) y el lado deja de producir; al reunirse, R-FIN-5/7 lo tratan como
partición ordinaria. No hay regla que lo evite sin romper (h.3′) (10a A.3: cualquier «si no está la revelación…» hace `flujo`
dependiente de la vista y parte el DAG). Es decir: **no existe contramedida de consenso; solo de calibración (4a) y de
operación** (un lado sin timekeeper ya está muerto sin (h)).

**4c · No adoptar (h)** y admitir `ρ_max = 3` sin candado (10a D.3, 10c E): el vector desaparece con la pieza.

**Cómo cambia el número.** Suelo de hardware de un lado: 10 líneas → 3 (4a) → 1 (4c).

**Verificar:** nada nuevo si se elige 4c; con 4a, el microbanco de 10a en una máquina de 4-8 núcleos con 3 líneas a 1 s/slot.

---

# Parte II · Acotados con número

## 5 · Carrera de bloques

**Causa.** Un atacante con fracción `α` del espacio construye un flujo privado y lo publica dentro de `F`; gana si su
`blue_work` supera al honesto (carrera de Skellam con ventaja inicial `3k`, Lema 10). Frontera de flujo único (unión a 10 años
`< 10⁻¹⁰`): 46,9 % con `F = 5,3 h`, **44,6 % con `F = 2 h`**, 35,1 % en el modelo pesimista (`δ` de D8 ≡ `δ₀(16 s)`); el 33 %
conserva 2,1 puntos en el peor modelo (`verif_frontera_vs_F.py`; 10b). Es el ataque de Nakamoto: ningún protocolo de cadena más
larga lo cierra por debajo del 50 %; los 3-5 puntos que faltan hasta el 50 % son varianza y ventaja inicial.

**Mejoras posibles y cuánto mueven (10b, VERIFICADO):**

| Palanca | Efecto sobre `F_carrera` al 33 % | Efecto sobre la frontera a `F = 2 h` |
|---|---|---|
| `Δ` de 16 → 4 s | ×3,5 más corta | 35,1 → 44,6 % |
| Ventaja `3k → 1,68k` (usar la medida, no la cota) | −3,2 min | ESTIMACIÓN +0,5 puntos |
| Objetivo `10⁻¹⁰ → 10⁻⁶` | −4,1 min | ESTIMACIÓN +0,3 puntos |
| `F` de 2 → 5,3 h | — | +2,3 puntos (44,6 → 46,9) |
| `k` con `δ = 0` | `k`↑ alarga `F` | ESTIMACIÓN ±0,5 puntos |

**Solución estructural que sí subiría el número: finalidad por comité (BFT) sobre el DAG.** Mecanismo: un conjunto de
validadores con identidad (los granjeros con más espacio acreditado en la última ventana, o un conjunto abierto con
staking) firma cada `T_fin` un bloque de la cadena seleccionada con `≥ 2/3`; un bloque firmado es irreversible aunque un
flujo con más `blue_work` aparezca después. Precedente: Filecoin F3 (2025), tras un umbral real del ~20 %. **Cuánto arregla:**
la reversión pasa de «probabilística con umbral 44,6 %» a «imposible por debajo de 1/3 de validadores corruptos», y `F`
podría bajar al `T_fin` del comité (minutos). **Qué rompe:** introduce identidad, un conjunto de validadores con sus
incentivos, y un segundo consenso; contradice P-036 (descentralización) y el modelo «sin permiso desde el bloque 1» (C-CHK-07).
**No para v1.** HIPÓTESIS: si ZEROX lo adopta alguna vez, debería ser como Filecoin, capa opcional que los clientes pueden
ignorar, nunca como sustituto de la regla de `blue_work`.

**Solución barata que no toca consenso: el precio del ataque.** El atacante necesita **poseer** `α` del espacio durante `F`,
no alquilar cómputo. Tres cosas mantienen ese precio alto: (i) parcelas no comprimibles ni regenerables al vuelo (laguna 39);
(ii) el checkpoint de lanzamiento C-CHK-01..07 durante la ventana en que la red es pequeña; (iii) crecimiento del espacio
honesto (marketing, recompensas de arranque). Ninguna cambia el 44,6 %; todas cambian cuánto cuesta llegar a él.

**Cómo cambia el número.** Sin comité: 44,6 % es el techo práctico con `F = 2 h`; 46,9 % con `F = 5,3 h`; el 50 % es
inalcanzable (varianza). Con comité: el número deja de ser una fracción de espacio y pasa a ser 1/3 de un conjunto de
validadores.

**Verificar:** `Δ` (todo depende de él); la ventaja real `3k` en régimen (D8 midió 0,56·3k; 10b: no diseñar con ella);
si alguna vez se estudia el comité, el modelo de incentivos de F3 y su interacción con R-FIN-7.

## 6 · Steering del ancla

**Causa.** El ancla `I_j` es el bloque de la cadena seleccionada con menor `blue_work` entre `slot ≥ T_j`; un atacante con varios
candidatos propios en `[T_j, T_j + S_max)` puede publicar o retener para elegir cuál queda, si sabe cuál le conviene. Saberlo
exige evaluar la época que cada candidato produciría, y con R-FIN-14 (reto secuencial) eso exige calcular la cadena de PoT por
delante: **0 con `ρ ≤ 1`**; con `ρ > 1`, `n_eval = ρ·W_dec` slots por candidato tras un bootstrap de días (9c E1). Con (h),
÷279 en el rango físico y umbral `ρ* ≈ 1 + L/I` (10a).

**Mejoras concretas.**

**6a · Lo que ya hay, bien calibrado.** `I ≥ ρ_max·W_dec` y `I = c_m·√(n_eval/(αλ))/g` (R-FIN-14 (f)). El steering residual
`g` con `ρ = 3` y `I = 851 s` es 3,6 % y crece como `√(ρ/ρ_max)`. Es un impuesto de desigualdad, no de seguridad: el atacante gana
un `g` de bloques de más, no reversiones.

**6b · Reducir `m` (número de candidatos) por construcción.** Hoy `m ≤ 1 + λ·S_max = 151` (cota) y 2,54 medido. Mecanismo:
**ancla por slot exacto**: `I_j` := el bloque de la cadena seleccionada con `slot(B) = T_j` exactamente, y si no hay, el
primero posterior. HIPÓTESIS: reduce el menú de candidatos a los bloques de un solo slot (en media `λ·τ = 1`), luego
`m → 1 + P(dos bloques de cadena en el mismo slot) ≈ 1,2` (ESTIMACIÓN), y `g` baja como `√(m−1)`. **Qué rompe:** hay que
comprobar que no reabre el ataque de la ronda 7 A1 (R-FIN-1a existe para eso) ni el contador de saltos de D9-c: el slot es
índice de PoT, no cuenta, así que en principio no. **Verificar:** repetir D9-f B1 con la regla y medir `m`; 12 semillas.

**6c · Desempate del ancla por `solution_distance` en vez de por `blue_work`.** HIPÓTESIS: entre candidatos del mismo slot,
elegir el de menor `solution_distance` (la magnitud que el atacante no controla: R-FIN-6 ya desempata así) en vez del menor
`blue_work` (que el atacante sí puede afectar reteniendo). Reduce el steering porque el atacante no elige cuál de sus
candidatos «gana» el desempate. **Qué rompe:** el Lema A4-slot (Prop. 7 cubre el ancla) usa `blue_work`; habría que
reescribirlo. **Verificar:** la prueba del lema con el desempate nuevo; simulación de `m`.

**6d · (h)** ya analizada: divide por 279, cuesta `1 + L/I` en verificación.

**Cómo cambia el número.** `g` con `ρ = 3`: 3,6 % hoy; con 6b (ESTIMACIÓN `m ≈ 1,2`) ~1,6 %; con (h) a `ρ ≤ 2,5`, 0,007 %
por época (10a). Y con `ρ ≤ 1` (reloj honesto igual o más rápido), 0 en todos los casos.

**Verificar:** 6b y 6c con el instrumento de D9-f (`r8f_*`) y la clausura de publicación de 9c (laguna 41).

## 7 · Soborno del ancla

**Causa.** D8 A5: `m = b + 1` comprando `b` retenciones ajenas, incluso con `α = 0`. Con R-FIN-14 y `ρ ≤ 1`, tener más
candidatos no compra nada porque no se pueden evaluar (9c E1). Queda la variante de BDK (laguna 40): el sobornante regala su
cadena de PoT adelantada al sobornado, y el sobornado renuncia a su coinbase honesta (R-FIN-8′) — «arbitrarily small stake»
deja de ser cierto.

**Mejoras concretas.** (a) **6b** (ancla por slot exacto) reduce lo que un soborno puede comprar: solo bloques del mismo slot.
(b) **Coste de oportunidad explícito:** con R-FIN-8′ el bloque sobornado que acaba en la rama perdedora no cobra; el precio del
soborno ≥ una coinbase por candidato retenido. ESTIMACIÓN: con `m` útil ≈ 2, el soborno cuesta ≥ 2 coinbases por época y
compra `g ≈ 3,6 %` de una época de `I·λ = 851` bloques ≈ 31 bloques para el sobornante: rentable si `α_sobornante` grande,
no rentable para `α < 6 %` (HIPÓTESIS aritmética: 31·α ≥ 2). (c) **Retención visible:** un bloque publicado más de `S_max`
después de su slot es inválido (R-FIN-1a); un bloque publicado entre `W_dec` y `S_max` es sospechoso de retención y puede
llevar una **penalización de coinbase** (HIPÓTESIS de regla: coinbase × `(1 − (t_pub − slot)/S_max)`, donde `t_pub` se
aproxima por el slot del primer bloque que lo referencia). **Qué rompe:** castiga también al granjero lento honesto; con
`Δ_p99 ≤ 16 s` y `W_dec = 45 s` el castigo honesto sería `< 30 %` en el peor caso y 0 en régimen. Es un intercambio entre
desigualdad y censura de lentos (punto 10). **Verificar:** modelo de soborno con coste de oportunidad (laguna 40) y la
penalización en simulación con retrasos reales.

**Cómo cambia el número.** De «soborno gratis con `α = 0`» a «≥ 2 coinbases por época y solo rentable con `α` grande»;
con (c), el bloque retenido pierde además parte de su propia coinbase.

## 8 · Sembrador rápido (plotter con lookahead)

**Causa.** Un atacante que conozca los retos futuros puede sembrar parcelas específicas para ganarlos y desecharlas.
10c (VERIFICADO en D y F por el principal; A y B en verificación): lookahead honesto **0** bajo R-FIN-14; atacante con `ρ > 1`:
`(F − W_dec) + I(1 − 1/ρ)` slots (el `F` viene de que la entropía del ancla se conoce `F` antes de aplicarse); es un
acantilado en `ρ = 1`: `ρ = 1,001` ya da el 82-96 % de `ρ = 10`, y `ρ` grande solo acorta el bootstrap. Margen frente a un
plotter 10× mejor que la extrapolación: 1,9× a `F = 2 h`, 3,6× a `F = 1 h`; con (h), 2,8-5,5×. El sembrador impone un
**máximo** a `F` (o a `L`).

**Mejoras concretas.**

**8a · Desatar `L` de `F`** (10c E, PLAUSIBLE): el lookahead depende de `L` (rezago con que se aplica la entropía del ancla),
no de `F` (finalidad). Hoy `L = F` sin necesidad. Con `L = 1 h`, `F = 2 h`, `ρ_max = 3`: lookahead 4 146 s, margen 3,6×,
`W/κ = 0,58` dentro del tope literal de BDK, sin (h). **Qué cuesta:** la tolerancia a particiones baja a `L` (un lado
partido más de `L` inyecta entropías distintas ⇒ flujos distintos). **Qué rompe:** hay que comprobar que `L < F` no reabre
«conocer `entropía_j` antes de elegir `I_{j+1}`» (ronda 7 marcó `L ≥ I` como condición; con `L = 1 h > I = 851 s` se cumple).
**Verificar:** repetir 9c C (`W_dec`) y D9-f B1 (`m`) con `L = 1 h`; y la regla de partición con `L`.

**8b · Reto que no dependa de la entropía del ancla hasta el último momento: cadena de PoT «ciega».** HIPÓTESIS de
mecanismo: en vez de inyectar `entropía_j` en `t_j` como semilla, **mezclarla en cada slot**: `semilla(f, s) = blake3(salida(f, s−1)
‖ entropía_j)` para todo `s ≥ t_j`. No cambia nada para `ρ ≤ 1` (ya es 0) y **tampoco** para `ρ > 1` (la entropía sigue
conocida `F` antes): descartado en el análisis; se deja escrito para no repetirlo.

**8c · Reducir la ventaja del plotter por diseño de la parcela.** El sembrador solo sirve si sembrar un sector cuesta menos que
`lookahead/N_sectores_útiles`. Autonomys pone un coste de sector fijo (`coste-ploteo-medido.md`: 69 s en GTX 1070, 4,3 s
extrapolado a GPU 2026). Mecanismo: **subir el coste de sembrado por unidad de espacio probado**, p. ej. exigir que el
`history_size` de la parcela tenga al menos `A` segmentos de antigüedad (C-EXP-04 con `altura_ploteo ≤ blue_work(punta) −
F·λ·w̄`, R-FIN-10) — ya existe y es exactamente esta defensa: una parcela recién sembrada no puede ganar hasta que su
`history_size` madure. **Cuánto arregla:** si la maduración `≥ lookahead`, el sembrador no llega. HIPÓTESIS: hoy la
maduración es `F·λ·w̄` en `blue_work`, es decir ≈ `F` en tiempo; con `L < F` (8a), maduración `F` > lookahead `L`: **el sembrador
queda fuera por construcción**. **Verificar:** que R-FIN-10 (C-EXP-04) se aplique a la parcela, no solo al mapeo, y que la
maduración se cuente desde la publicación del segmento, no desde la siembra.

**Cómo cambia el número.** Margen 1,9× (hoy) → 3,6× (8a) → «sin ventana» si la maduración de parcela supera `L` (8c,
HIPÓTESIS).

**Verificar:** a1/b de 10c (en curso), 8a con `m` y `W_dec` re-medidos, y la lectura de C-EXP-04/R-FIN-10 frente a la parcela.

## 9 · Ráfagas planificadas con adelanto

**Causa.** Con `ρ > 1` el atacante conoce sus victorias antes y planifica retenciones; 10a B.6: una carrera por segundo durante
10 años cuesta 0,46 puntos en la cota, < 0,08 real. LAGUNA: retención selectiva con oráculo de victorias propias.

**Mejora.** Ninguna necesaria: el número está por debajo del ruido de la medida de `δ` (±9 min de `F`). Si (h) se adopta, el
adelanto baja 5,5× (10a). **Verificar:** el oráculo de victorias futuras en `r8c_sim.py` (laguna 41, misma herramienta).

## 10 · Censura por `S_max`

**Causa.** R-FIN-1a exige `slot(B) − slot(sp(B)) ≤ S_max`; un granjero cuya vista va retrasada produce bloques inválidos.
Con `S_max = 150 s`, ~0; con 20 s, 71-77 %. `S_max` se co-determina con `m ≤ 1 + λ·S_max` (steering) y con la tolerancia a
particiones (`f ≥ 9 %`).

**Mejora concreta: `S_max` en dos escalas.** HIPÓTESIS de regla: `S_max_validez = 150 s` (como hoy, para validez) y
`S_max_ancla = 45 s` (= `W_dec`) solo para **ser candidato a ancla**: un bloque publicado más de 45 s después de su slot es
válido y cobra, pero no puede ser `I_j`. **Cuánto arregla:** la cota del steering pasa de `m ≤ 1 + λ·150 = 151` a
`m ≤ 46` sin censurar a nadie (la validez sigue a 150 s). **Qué rompe:** hay que definir «publicado» de forma determinista
(HIPÓTESIS: `slot` del primer bloque de la cadena seleccionada que lo referencia), y comprobar que no reabre D9-c (contador
que el atacante fabrica): el slot del primer referenciador lo fija el PoT, no el atacante, salvo que el atacante sea el
referenciador, y entonces solo puede **retrasar** su candidatura, no adelantarla. **Verificar:** D9-f B1 con la regla.

**Cómo cambia el número.** Censura: 0 (igual). Cota de `m`: 151 → 46; `F ≤ 68,5 h` garantizado → ESTIMACIÓN ≤ 25 h.

## 11 · DoS de verificación del PoT

**Causa.** Verificar cuesta 96,1 ms/slot; un atacante que envíe cabeceras con slots adelantados podría forzar verificaciones.
Asimetría 16,2× a favor del verificador (medida), y las cabeceras con slot por delante del PoT verificado se retienen.

**Mejora concreta.** (a) Regla explícita (1a-ii): PoT por slot al llegar por gossip, una vez; cabeceras cuyo slot supere el PoT
verificado + 10 slots (Autonomys `MAX_SLOTS_IN_THE_FUTURE = 10`, `gossip.rs:30`) se descartan con penalización de peer
(C-NET-05). (b) Verificación en orden aleatorio de checkpoints (10a B.2.b): sube la asimetría a 32,4× contra prefijos largos
correctos. (c) `EXPECTED_POT_VERIFICATION_SPEEDUP` de Autonomys (`gossip.rs:32`, valor 7): si hay más pruebas distintas que
compensa verificar, el nodo calcula la suya. **Cómo cambia el número.** 16,2× → 32,4×; y el trabajo por slot queda acotado a
una verificación por slot por nodo, independiente del número de cabeceras. **Verificar:** en `zx-p2p`, el coste por segundo
bajo inundación de cabeceras con 10 pares maliciosos.

## 12 · Particiones

**Causa.** Dos lados producen flujos distintos tras `F` (o `L`); R-FIN-5 impide referenciar el flujo ajeno; al reunirse, el lado
con menos `blue_work` se descarta. Hasta `F`, tolerada si el lado conserva ≥ 9 % del espacio (`S_max = 150 s`; D9-d A4).

**Mejoras concretas.** (a) **Curación por fusión** (Kaspa): al reunirse antes de `F`, los bloques del lado minoritario se
fusionan como rojos y **cobran** (R-FIN-8′ `rojo_k`): nadie pierde recompensa, solo orden. Ya está. (b) **Después de `F`:**
el lado minoritario se pierde entero. Mecanismo para reducir la pérdida: **detección de partición** por los sensores del
punto 2 (tasa de bloques cae a `f·λ`, PoT sigue) ⇒ el lado minoritario **sabe** que está partido en 1-2 min y puede
**dejar de aceptar transacciones como confirmadas** (los comerciantes de ese lado no entregan mercancía). No evita la pérdida
de bloques, evita el doble gasto. (c) **`L < F`** (8a) reduce la tolerancia a `L`: es el precio del margen frente al sembrador;
con `L = 1 h`, las particiones de 1-2 h pasan de curables a no curables. HIPÓTESIS: particiones de más de 1 h en una red
pública son raras (incidentes BGP típicos de minutos), pero un ataque de red dirigido puede sostenerlas: 12b lo hace visible.
**Cómo cambia el número.** Tolerancia: `F = 2 h` (hoy) o `L = 1 h` (8a); pérdida del lado minoritario tras la ventana: igual;
doble gasto en el lado minoritario: de posible a detectable en ~1-2 min. **Verificar:** 11b (sensores) y la regla de partición
con `L`.

## 13 · Recalibración de iteraciones a mitad de época

**Causa.** R-FIN-9: `slot_iterations` cambia y se aplica en `t_j`; con (h), congelado en `slot(I_j)`. Acotado por regla.

**Mejora.** Ninguna necesaria. HIPÓTESIS de refuerzo: limitar el cambio por época a ±10 % (Autonomys usa un retarget de
iteraciones lento) para que un timekeeper que acelere no fuerce a los demás a quedarse fuera de golpe (#2141). **Verificar:**
el retarget de iteraciones de Autonomys (`pot_parameters_change`, `verifier.rs:270-280`) y su cadencia.

## 14 · Residuo de la cadena parásita

**Causa.** Tras R-FIN-8′/13′ el ataque no renta y no revierte, pero sigue existiendo: bloques honestos en rojo (pagados), y
transacciones que se aplican en el orden del mergeset en vez de en el de llegada. Parasitar sigue siendo gratis a `α` pequeño.

**Mejoras concretas.** (a) **El sensor de `Δ`/parásita (1e)** como métrica: la fracción de rojos sostenida es la firma.
(b) **Hacer que parasitar cueste:** HIPÓTESIS de regla, **coinbase de un bloque rojo escalada por su anticono**: un `rojo_k`
cobra `coinbase × k/|anticone ∩ azules|` (≤ 1). Un bloque honesto que cae en rojo por `Δ` tiene anticono ≈ `k + 2Δλ` y cobra
casi entero; un bloque parásito publicado en ráfaga de `J*` tiene anticono grande y cobra poco. **Qué rompe:** hay que
comprobar que no reabre la inflación (no: solo reduce) ni castiga a los honestos a `Δ` alto (a `Δ = 16 s` un honesto rojo
cobraría ≈ 30/38 = 79 %). Y que la parásita no lo esquive publicando en ráfagas más cortas (entonces `δ` baja: 9a L4). Es
un intercambio con el punto 10. **Verificar:** en `verif_parasita.py` y `r9b_d_coste.py` con la regla, 12 semillas.
**Cómo cambia el número.** Rentabilidad 0,99 → ESTIMACIÓN 0,7-0,8; `δ` igual; honestos a `Δ = 4 s` sin cambio.

## 15 · Tolerancia a particiones = `F` (o `L`)

**Causa y mejora.** Ver 12 y 8a. Es una elección, no un defecto: `L` corto compra margen frente al sembrador y vende
tolerancia. **Cómo cambia el número.** `F = 2 h` / `L = 1 h`. **Decisión de Katana (F1).**

## 16 · Umbral operativo 33 % frente al 46,9 % teórico

**Causa.** El 33 % es lo que se publica con colchón frente a `Δ` no medido y al modelo pesimista. El 46,9 % es la frontera a
`Δ = 4 s`, `F = 5,3 h`; a `F = 2 h`, 44,6 %.

**Mejoras.** (a) Medir `Δ` y publicar el colchón real (si `Δ_p99 ≤ 8 s`, el 33 % tiene 11-14 puntos y se podría publicar
**40 %**; ESTIMACIÓN con la tabla de 10b). (b) Subir el techo teórico: solo el comité (5) o reducir la varianza de la carrera
(bloques más frecuentes: `λ = 2/s` reduce la varianza relativa de Skellam pero sube `2Δλ`; ESTIMACIÓN +0,5-1 punto, no
compensa el coste en `Δ`). **Cómo cambia el número.** Publicado: 33 % → hasta 40 % con `Δ` medido bajo. Teórico: 44,6-46,9 %,
techo 50 %. **Verificar:** `Δ`.

---

# Parte III · Cerrados por regla verificada, o refutados — qué propuesta de arriba podría reabrirlos

No se rehace el análisis. Para cada cierre: la regla que lo sostiene y **qué solución de las partes I, II, IV o V lo tocaría**.

## 17 · Cadena parásita, en lo económico (R-FIN-8′ + R-FIN-13′)

Cierre: `rojo_k` cobra su propia coinbase y aplica sus transacciones; `rojo_U3` inerte; retarget cuenta un bloque por identidad.
Rentabilidad 0,99, `S1_h = 1,0000`, retarget ×1,005 (9b, 12 semillas). **Lo tocarían:** **14b** (coinbase de rojos escalada por
anticono) reduce lo que cobra un rojo: baja la rentabilidad de la parásita (bien) pero también lo que cobra un honesto rojo a
`Δ` alto (hay que re-medir `S1_h`); **7c** (penalización por retención) igual. **1c** (`λ = 1/2`) cambia `k`, `J*` y `δ`: hay
que repetir `verif_parasita.py`. **1d** (KNIGHT) cambia la regla del cluster: la parásita entera se reanaliza.

## 18 · Copias de billete (U2 + U3″ + `rojo_U3` inerte)

Cierre: una azul por identidad; copias rojas válidas pero inertes. **Lo tocarían:** **6b/6c** (ancla por slot exacto, desempate
por `solution_distance`) no tocan el coloreado; **14b** no toca las copias (`rojo_U3` no cobra en ningún caso). **1d** (KNIGHT)
cambia el coloreado: U3″ está definida sobre el mergeset ordenado de GHOSTDAG y habría que redefinirla.

## 19 · Timewarp y grinding del retarget (`slot` = índice de PoT; Lema E1; 13′)

Cierre: el retarget cuenta azules del flujo canónico en una ventana de índices de PoT; la deriva del retarget es factor común.
**Lo tocarían:** **13** (límite ±10 % por época) lo refuerza; **1c** cambia `W_RETARGET` (en slots o en bloques: hay que fijarlo
en slots). Nada de la parte I lo reabre.

## 20 · Griefing del mergeset (`pick_virtual_parents` con presupuesto; `shuffle` obligatorio)

Cierre: un honesto nunca emite `MergeSetTooBig`; el `shuffle` evita que 14-21 honestos queden fuera para siempre.
**Lo tocarían:** **1b** (`k` mayor) escala `6k` y `k/2`: sigue cerrado pero con más padres por cabecera; **1d** (KNIGHT) no tiene
`mergeset_size_limit` fijo: se reanaliza.

## 21 · Grinding por hash en desempates (desempate por `solution_distance`)

Cierre: la magnitud de desempate no la controla el atacante. **Lo tocarían:** **6c** lo **extiende** al ancla (bien). Nada lo reabre.

## 22 · Parásito racional ajeno (deja de serlo con R-FIN-8′)

Cierre: un tercero no gana parasitando. **Lo tocarían:** **14b** lo refuerza (cobra aún menos). **7c** también.

## 23 · Publicación parcial y reparto parasitar-correr (no mejora al atacante)

Cierre: teorema de la ráfaga (`R < A ⟺ gana`), `δ` cae al retener, `adv_max ≤ 43 < 3k`. **Lo tocarían:** vale mientras
`2Δλ ≪ k` (9a); **1b** (subir `k`) lo **refuerza**; **1c** (`λ = 1/2`) lo refuerza; a `Δ ≥ 16 s` con `k = 30` hay que re-medir
(laguna 44).

## 24 · Inundación de revelaciones falsas del candado (asimetría 16-32×, (h.2c))

Cierre: verificar una por época, en orden aleatorio; recomputar si hay demasiadas. Solo existe si se adopta (h). **Lo
tocarían:** **4a** (calibración barata) lo hace aún más barato. Nada lo reabre.

## 25 · Ventana predecible si la revelación llega tarde ((h.3′): se calcula, no se espera)

Cierre: la entropía es función de `past(B)`. **Lo tocarían:** **4b** es exactamente esta regla; **8b** (mezcla por slot) fue
descartada. Nada lo reabre.

## 26 · «Todo granjero conoce sus victorias con antelación» (refutado: lookahead honesto 0)

Cierre: 10c A (en verificación). **Lo tocarían:** **8a** (`L < F`) no lo cambia para `ρ ≤ 1`; **1d** (KNIGHT) tampoco: el
lookahead lo fija el PoT secuencial (R-FIN-14), no el orden. Nada lo reabre.

## 27 · Reloj AES 19× (no es físico)

Cierre: `AESENC` a 3 ciclos y 6,2 GHz es ya hardware; 19× exigiría 25 ps por ronda. **Lo tocarían:** nada. La laguna que
queda es el techo real (38).

---

# Parte IV · Estructurales — cambios de diseño o de arquitectura, no de parámetro

## 28 · Sin cliente ligero: 21,5 GB/año de cabeceras, modelo con servidor

**Causa.** GHOSTDAG no tiene SPV: `blue_work` en cabecera es una afirmación que solo se comprueba coloreando el DAG entero; a
`q = 1` son 21,5 GB/año. Decidido `q = 1` con modelo Zcash (`zx-lightwalletd`).

**Cambios de arquitectura posibles.**

**28a · Pruebas de inclusión sobre la cadena seleccionada + compromiso al DAG.** Mecanismo: cada bloque de la cadena
seleccionada lleva un **compromiso** (raíz de Merkle) al conjunto de bloques que fusiona y a su `blue_work` acumulado
(Kaspa lo tiene en parte: `accepted_id_merkle_root`, `utxo_commitment` en la cabecera, `header.rs`). Un cliente ligero sigue
**solo la cadena seleccionada** (una cadena lineal, ~0,2 bloques/s ⇒ ESTIMACIÓN 4,3 GB/año a 683 B, y con cabeceras de
cadena sin padres extra, ~2 GB/año) y verifica que su transacción está en el `accepted_id_merkle_root` de algún bloque de
cadena. **Qué compra:** SPV con confianza en que la cadena seleccionada que le sirven es la de mayor `blue_work`, que **no
puede verificar** sin el DAG. **Qué no compra:** la comparación entre dos cadenas rivales; el cliente puede ser engañado con
una cadena seleccionada falsa de menor peso. HIPÓTESIS: es el mismo compromiso que acepta Zcash con `lightwalletd`, pero con
un cliente que baja 2-4 GB/año en vez de confiar ciegamente: **mejor que el modelo actual, no SPV sin confianza**.

**28b · Muestreo del DAG (pruebas de peso probabilísticas).** Mecanismo: el cliente pide `n` bloques al azar de la ventana
`F` y comprueba su coloreado local (anticono `≤ k`) y su `blue_work` contra el compromiso de la cadena; un servidor que
mienta sobre `blue_work` en más de una fracción `ε` es detectado con probabilidad `1 − (1−ε)^n`. HIPÓTESIS: con `n = 200`
y `ε = 5 %`, detección 99,997 %. **Qué cuesta:** el coloreado local de un bloque exige su pasado hasta `k` niveles: ~`k²`
cabeceras por muestra (ESTIMACIÓN 900 × 683 B = 0,6 MB por muestra; 120 MB por comprobación). Cabe en un móvil de forma
ocasional, no continua. LAGUNA: nadie lo ha diseñado para GHOSTDAG; es investigación.

**28c · Compromisos sucintos (SNARK) del coloreado.** Mecanismo: el nodo que sirve genera una prueba sucinta de que el
`blue_work` de la punta es el que dice, sobre el DAG de la ventana. HIPÓTESIS: viable en principio (el coloreado es un
cómputo determinista), coste de prueba muy alto a 1 bloque/s y ninguna implementación; no para v1 ni v2.

**Cómo cambia el número.** Cliente ligero: de 21,5 GB/año (imposible en móvil) a 2-4 GB/año (28a) con confianza parcial, o a
~120 MB por comprobación (28b) con confianza probabilística. **Verificar:** que la cabecera de cadena lleve
`accepted_id_merkle_root` y `blue_work` acumulado (leer `rusty-kaspa/consensus/core/src/header.rs`), y diseñar 28b.

## 29 · Verificación de PoT no sucinta

**Causa.** La cadena AES no tiene prueba corta; verificar recomputa en paralelo (1/16 del coste): 9,6 % de un núcleo
continuo; con (h), +0,15 a +0,81 núcleos.

**Cambios posibles.** (a) **Checkpoints firmados por el timekeeper + verificación diferida**: los nodos aceptan los
checkpoints provisionalmente con la firma de un timekeeper conocido y los verifican en segundo plano; un checkpoint
falso se detecta con retraso y se castiga. **Qué rompe:** introduce identidad del timekeeper (C-TIMELORD-02 lo prohíbe) y
una ventana de confianza; no. (b) **VDF con prueba corta solo para la cadena de revelación (h)**: Wesolowski sobre grupos de
clase, verificación en milisegundos; **qué cuesta:** C++/GMP, el problema de interoperabilidad H-001, y un reloj donde el ASIC
de Chia demostró 3-4×; el candado pasaría a depender de un reloj que sí tiene carrera de hardware. No. (c) **Aceptar el
coste y acotarlo**: 9,6 % es asumible; el de (h) se calibra (4a). **Cómo cambia el número.** Sin cambio realista: 0,1 núcleos.
**Verificar:** nada; es una elección hecha (`CLAUDE.md`).

## 30 · Umbral por debajo del 50 %

**Causa.** Varianza de la carrera + ventaja `3k` + `δ₀(Δ)`; y la familia PoST paga además la posibilidad de *double dipping*
(aquí evitada con R-FIN-5).

**Cambios posibles.** (a) Comité BFT (5): el único que lo lleva por encima. (b) Reducir la varianza: bloques más frecuentes
suben `2Δλ` (no compensa); `F` más larga sube el número (2,3 puntos de 2 h a 5,3 h) a costa de todo lo demás. (c) Aceptarlo y
publicarlo con colchón. **Cómo cambia el número.** 44,6-46,9 % teórico; 33-40 % publicado. **Verificar:** `Δ`.

## 31 · Suelo de confirmación de 100-134 s

**Causa.** La ventaja inicial `3k` del atacante en la carrera: hasta que los honestos acumulan `3k` bloques por encima, ninguna
confirmación es posible (10c C, en verificación): `3k/((1−α)λ) ≈ 100-134 s`.

**Cambios posibles.** (a) **Reducir `3k`**: es cota, la real medida es 0,56·3k (D8) ⇒ suelo real ~60-75 s; diseñar con la medida
no es legítimo (10b) pero **publicar** el suelo real como orientación al comerciante sí. (b) **Confirmaciones probabilísticas
antes del suelo:** un comerciante con transacción pequeña acepta riesgo `10⁻³` a los 300 s con `α = 0,25` (tabla de 10c:
`2,2·10⁻⁴`). (c) **`λ` mayor** no ayuda (sube `3k` en bloques igual). (d) Comité (5). **Cómo cambia el número.** 100-134 s
estructural; 60-75 s si se publica la ventaja medida como estimación; minutos con comité. **Verificar:** 10c C (a1/b en curso).

## 32 · Barrera de hardware y centralización del timekeeper

**Causa.** El timekeeper necesita latencia de AES de clase 14900KS; con (h), ×`(q+1)`; el más rápido deja obsoletos a los
demás (#2141).

**Cambios posibles.** (a) **3b**: publicar hardware de referencia y operar ≥ 3; la dispersión entre CPU de gama alta es
pequeña (HIPÓTESIS < 5 %). (b) **Bajar `pot_slot_iterations`** para que una CPU de gama media haga 1 slot/s: sube `ρ` de
cualquier CPU de gama alta a ~1,3-1,5× ⇒ steering `√1,5` (punto 6): intercambio entre descentralización del reloj y steering.
ESTIMACIÓN: con iteraciones para un 7950X (4 ciclos, 5,7 GHz), el 14900KS tendría `ρ = 1,45`. (c) **Aceptar** que el reloj
lo opera ZEROX con redundancia, como Chia opera los suyos, y declararlo como propiedad de descentralización. **Cómo cambia el
número.** Barrera: de «tope del mercado» a «gama media» con (b), a cambio de `ρ_max ≈ 1,5` para cualquiera de gama alta.
**Verificar:** `prove` por slot en 3-4 CPU distintas.

## 33 · Coinbases: 31,5 M salidas/año

**Causa.** Un bloque por segundo, una coinbase por bloque: 31,5 M salidas/año, ~1,3 GB/año de UTXO.

**Cambios posibles.** (a) **Coinbase agregada por época** (Kaspa: la coinbase de un bloque de cadena paga a todos los del
mergeset, `coinbase.rs`): pagar por identidad y por ventana, no por bloque: una salida por granjero cada `I` (ESTIMACIÓN: con
10 000 granjeros y `I = 851 s`, 370 M salidas/año — **peor**, porque hay más granjeros que bloques por época; con `I = 1 día`,
3,6 M/año, mejor ×9). HIPÓTESIS: solo compensa con ventanas largas, y eso choca con la madurez (`COINBASE_MATURITY`). (b)
**Salidas de coinbase consolidables sin firma** (tipo «sweep» automático): no reduce las salidas, reduce lo que el granjero
tiene que gestionar. (c) Aceptar 1,3 GB/año: es menor que las cabeceras. **Cómo cambia el número.** 31,5 M/año → 3,6 M/año
solo con pago diario; el UTXO 1,3 GB/año no es el cuello de botella. **Verificar:** nada urgente.

## 34 · Poda sin resolver

**Causa.** Sin niveles de PoW, no hay la estructura que Kaspa usa (`pruning_depth`, `pruning_point` con prueba de
`ghostdag` a lo largo de niveles). La justificación de PoT pesa 128 B/slot = 4 GB/año y no se ha estudiado si es podable
manteniendo verificabilidad desde el génesis (P-034).

**Cambios posibles.** (a) **Poda de PoT por checkpoint C-CHK-05**: por debajo del checkpoint, un nodo MAY omitir la
justificación; ya está escrito. Generalizarlo: **la propia cadena de PoT es su prueba** (determinista): un nodo que confía en
el último output verificado no necesita los intermedios; guardar un checkpoint por época (`I`) reduce 4 GB/año a
ESTIMACIÓN 37 000 × 16 B = 0,6 MB/año, y quien quiera verificar desde el génesis recomputa (`prove`, ×16). (b) **Poda del DAG
al estilo Kaspa sin niveles**: el `pruning_point` de Kaspa es un bloque de cadena a profundidad `pruning_depth` (30 h) y su
prueba de poda usa niveles de PoW para que un nodo nuevo pueda verificar la cadena de pruning points sin todo el DAG. Sin PoW,
la alternativa es la **prueba de espacio acumulada de la cadena seleccionada**: cada bloque de cadena lleva `blue_work` y la
cadena de anclas `I_j` es verificable con el PoT (R-FIN-1). HIPÓTESIS: un nodo nuevo puede verificar la cadena seleccionada
desde el génesis con solo sus cabeceras y el PoT (4,3 GB/año + 0,6 MB/año con (a)) y aceptar el UTXO en el pruning point con
su `utxo_commitment`, exactamente como Kaspa pero con `blue_work` en lugar de niveles. **Lo que se pierde:** el DAG completo
(los bloques fuera de la cadena) más allá de 30 h; los `rojo_k` que cobraron quedan en el UTXO, no en el DAG. **Verificar:**
leer `rusty-kaspa/consensus/src/processes/pruning_proof/` y comprobar qué usa de los niveles de PoW; diseñar el equivalente.

**Cómo cambia el número.** Estado de un nodo: de «todo desde el génesis» a «cabeceras de cadena + PoT por época + UTXO en el
pruning point» (ESTIMACIÓN 4-5 GB/año + UTXO).

---

# Parte V · Lagunas de medida o de teoría — qué medir, calcular o demostrar, y una estimación acotada

## 35 · `Δ` real

**Qué es.** El retardo efectivo honesto↔honesto con cola (p99), con la verificación de PoT dentro y bajo carga. Todo el colchón
depende de él. **Qué medir.** Red de pruebas con decenas de nodos (`zx-node` con el DAG), latencias inyectadas por región,
bloques a tamaño máximo, un atacante de red que retrase, y el sensor 1e activo. Medir `Δ_p50`, `Δ_p99`, `Δ_max` por hora y la
distribución de anticonos. **Estimación acotada (HIPÓTESIS, no dato):** Kaspa a 1 bps con bloques pequeños asume `D ≤ 10 s` con
`k = 18`; Bitcoin propaga un bloque al 90 % de la red en ~2-4 s con compact blocks (datos públicos de propagación 2023-2025,
no citados aquí: LAGUNA de fuente). Con bloques compactos y PoT por slot, **`Δ_p99` entre 4 y 10 s** es lo esperable en una
red pequeña bien conectada; 16-20 s solo bajo ataque de red o con nodos mal provisionados. **Cómo cambia el número.** Si sale
≤ 8 s, colchón 11-14 puntos y `F` de producción 1 h; si 12-16 s, `k = 40` (1b) y `F = 2 h`; si ≥ 20 s, rediseñar (`λ = 1/2` o KNIGHT).

## 36 · Proposición 7 bajo las reglas añadidas

**Qué es.** La convergencia del orden total de GHOSTDAG está probada sobre GHOSTDAG puro. La propuesta añade U3″ (coloreado
con filtro de identidad), R-FIN-5 (flujos) y R-FIN-8′ (rojos que cobran). Los Lemas A4/A4b/A4-slot transfieren la cobertura
del ancla (141 967/141 967 y 13 110/13 110 casos); la composición completa es PLAUSIBLE. **Qué demostrar.** (i) Que U3″ es un
**posprocesado determinista del mergeset** que no cambia la cadena seleccionada (`blue_work` se calcula con U3″ aplicada, luego
sí la cambia: hay que demostrar que la cambia de forma monótona, es decir, que el `blue_work` con U3″ sigue cumpliendo la
Propiedad 1 del paper); (ii) que R-FIN-5 solo **restringe** el conjunto de DAG válidos (todo DAG con un solo flujo es un DAG de
GHOSTDAG puro), luego Prop. 7 se aplica dentro de cada flujo tal cual — **DEMOSTRABLE en una página, HIPÓTESIS**; (iii) que
R-FIN-8′ no toca el orden (solo qué se aplica), luego no toca Prop. 7 — trivial. El único punto real es (i). **Estimación
acotada.** El riesgo de que (i) falle está acotado por lo medido: nueve rondas de simulación con U3″ y adversario del paper no
han visto una no-convergencia; D9-d midió `δ_ef = 0,129` con U3″ frente a 0,379 con el filtro antiguo. **HIPÓTESIS:** (i) se
demuestra viendo U3″ como una regla de coloreado que solo puede **quitar** azules del mergeset (nunca añadir), y GHOSTDAG con
menos azules por mergeset sigue siendo un `k`-cluster; la monotonía de `blue_work` bajo ancestría (Lema A4b) ya está probada
con peso real. **Cómo cambia el número.** Nada si se demuestra; todo si falla. **Verificar:** una ronda D9 dedicada solo a (i),
con el paper y `r8c_gd.py`.

## 37 · Ventaja inicial `3k` como cota

**Qué es.** El atacante puede empezar la carrera con hasta `3k` bloques de ventaja (cota del paper); medido, 0,56·3k
(D8, con parásita). **Qué medir.** La distribución de la ventaja inicial real en régimen, con y sin parásita, 12 semillas,
`α ∈ {0,25; 0,33; 0,40}`. **Estimación acotada.** ESTIMACIÓN: 1,7k-2,1k a 10 años (10b: extrapolación 2,1k). **Cómo cambia el
número.** `F_carrera` −3,2 min; frontera +0,5 puntos (ESTIMACIÓN). No merece diseñar con ella.

## 38 · Velocidad máxima real de un ASIC de AES

**Qué es.** `ρ_max`. Estimación del principal 1,5-2,5×; Autonomys cita un estudio de Supranational («no significant speedup»)
no localizado; Chia 3,1-3,8× en otra primitiva. **Qué buscar/medir.** (i) El estudio de Supranational (pedirlo a Autonomys;
buscar en su foro y en el repositorio de `subspace` la referencia). (ii) Literatura de AES de latencia mínima en ASIC: una
ronda de AES sin pipeline en 7 nm ≈ 0,25-0,4 ns (HIPÓTESIS, sin fuente), frente a 0,48 ns del AESENC a 6,2 GHz ⇒ `ρ ≈ 1,2-1,9×`.
(iii) Medir `prove` por slot en 3-4 CPU (Zen 5, Raptor Cove, Apple M4: AES en ARMv8 tiene latencia similar). **Cómo cambia el
número.** Si `ρ_max ≤ 2,5`: (h) barato o innecesario; steering sin (h) `g ≤ 3,3 %` con `ρ_max = 3` diseñado. Si `ρ_max ≥ 5`:
(h) necesario y `I` mayor.

## 39 · Compresibilidad de las parcelas de Autonomys

**Qué es.** Si una parcela se puede regenerar al vuelo con GPU más barata que el disco (lección de PoS 2.0 de Chia), el precio
del ataque 5 baja. **Qué medir/leer.** El formato de sector de Autonomys (`subspace-farmer-components`, `sector.rs`): el
sector se deriva de `history_size` + clave + índice con codificación de borrado y una PoS por pieza (`subspace-proof-of-space`,
tabla de Chia k=20 por «chunk»); medir cuánto tarda regenerar un sector (coste-ploteo-medido: 69 s en GTX 1070, 4,3 s
extrapolado) frente a la ventana en que sirve (un slot). **Estimación acotada.** HIPÓTESIS: como el reto exige el sector
completo y la PoS por chunk, «sembrar al vuelo» cuesta ≥ 4 s por sector y sirve para 1 slot: `841 GiB/h` por GPU tope
(10c A.4) frente a `~1 PiB` de red mínima ⇒ un plotter al vuelo cubre `< 0,1 %` del espacio por hora: **no rentable** salvo con
lookahead grande (por eso importa `L`). **Cómo cambia el número.** Si la parcela fuera comprimible ×2 (como Chia), el coste
del ataque 5 baja ×2: el 33 % costaría lo que hoy el 16,5 %. **Verificar:** leer `sector.rs` y `subspace-proof-of-space`;
buscar en el foro de Autonomys «compressed plots».

## 40 · Soborno de BDK portado a espacio

**Qué es.** BDK19 muestra que en PoS un sobornante con poca participación compra bifurcaciones porque el sobornado no pierde
nada al firmar dos ramas. En PoAS bajo R-FIN-8′ el sobornado **renuncia a su coinbase** en la rama perdedora, y no sabe que va a
ganar hasta el slot. **Qué modelar.** Un modelo de soborno con coste de oportunidad: el sobornante paga `≥ coinbase` por
bloque retenido; el beneficio es `g` de bloques en la época siguiente (punto 7). **Estimación acotada.** HIPÓTESIS aritmética
del punto 7: no rentable para `α_sobornante < 6 %`; para `α = 0,33`, compra ~31 bloques por 2 coinbases: rentable ×15.
**Cómo cambia el número.** Si el modelo confirma la rentabilidad a `α` grande, el punto 7 deja de ser «acotado» y necesita 7c
(penalización por retención) o 6b. **Verificar:** el modelo, con `κ+1` de `2κ+1` slots en `F·λ` bloques (10c B.5).

## 41 · `m` con retención posiblemente inflada

**Qué es.** Los simuladores de D8/D9-c..f permitían publicar un hijo de un bloque retenido, imposible en la red real; 9c lo
corrigió con la clausura de publicación. Las `m` «con retención» (2,82-2,96) pueden estar infladas. **Qué medir.** Repetir
D8 A4.2 y D9-f B1 con la clausura de `r9c_lib.py` en `r8c_sim.py`/`d8_lib.py`, 12 semillas. **Estimación acotada.** HIPÓTESIS:
`m` real con retención entre 2,54 (sin retención, medida) y 2,82: el diseño ya usa 2,548. **Cómo cambia el número.** `I`
±10 %. **Verificar:** la re-medición.

## 42 · Resolución de la ventana de decisión

**Qué es.** `W_dec ≤ 45 s` medida con rejilla `{0, 10, 20, 45, …}` y tope de 10 candidatos. **Qué medir.** Rejilla de 5 s y
sin tope, 12 semillas (33 min por corrida en 9c). **Estimación acotada.** `W_dec ∈ [20, 45]` s (el menú vive en los
primeros 10-20 s). **Cómo cambia el número.** `I ≥ ρ_max·W_dec` baja hasta ×2; `ρ*` de (h) sube (10a: `(L+I)/(I+W_dec)`).

## 43 · Unidades de `W` y `κ` en un DAG

**Qué es.** Si `W` (ventana de retarget) se cuenta en bloques del DAG (`λ = 1/s`) y `κ` en bloques de cadena (`λ_chain =
0,2/s`), la razón se multiplica ×5,2-5,8 (10c B.5). **Qué calcular.** Fijar las unidades en el texto de R-FIN-13: **todo en
índices de PoT (slots)**, que es lo que dice la regla («ventana de `W` índices de PoT»); entonces `W/κ` es adimensional y la
razón vieja no aplica. **Estimación acotada.** Con unidades en slots, `W/κ = 1 + I/F` y el criterio BDK (`≤ 1`) es
insatisfacible como 10c demostró; el criterio correcto es el de 10c B (pinza real 1 198-2 488 s). **Verificar:** reescribir
R-FIN-13 con la unidad explícita.

## 44 · Composición de retraso alto y parásita a `Δ ≥ 16 s`

**Qué es.** El teorema de la ráfaga vale mientras `2Δλ ≪ k`; a `Δ = 20 s` `W_pub/H = 0,936 < 1`. **Qué medir.** Repetir el A2
de 9a con `Δ ∈ {12, 16, 20}` (7 200 corridas). **Estimación acotada.** HIPÓTESIS: a `Δ = 16 s` la composición resta 1-3
puntos más sobre los 38,3 %; a 20 s el 33 % ya está perdido sin parásita. **Cómo cambia el número.** Solo a `Δ` alto; con
1b (`k = 40`) se recupera `2Δλ ≪ k` hasta 20 s.

## 45 · Régimen de más de 15 puntas

**Qué es.** `max_block_parents = 15` (`k/2`); el `shuffle` reparte, pero nadie ha medido con > 15 puntas simultáneas (ocurre
con `Δ` alto: `λΔ` puntas). **Qué medir.** Simulación de eventos con `Δ ∈ {16, 24}` (16-24 puntas), midiendo bloques que
quedan fuera y durante cuánto. **Estimación acotada.** HIPÓTESIS: con `shuffle`, ningún bloque queda fuera más de
`k/2/λΔ ≈ 1` ronda; sin `shuffle`, 14-21 fuera para siempre (D9-d). **Cómo cambia el número.** Nada si el shuffle funciona.

## 46 · Economía con precios supuestos

**Qué es.** `A*`, márgenes frente al plotter y almacenamiento de ganadores usan precios de GPU, disco y energía supuestos.
**Qué medir.** Precios de mercado (disco €/TiB, GPU €/h, energía) en la fecha de lanzamiento; recomputar `A*` y el margen.
**Estimación acotada.** El margen 3,6× (8a) es robusto a ±50 % en precios (HIPÓTESIS: el margen escala linealmente con el
precio del ploteo). **Cómo cambia el número.** ±50 %.

## 47 · Parásita y copias a la vez

**Qué es.** 9b no midió la combinación. **Qué medir.** `r9b_d_coste.py` con copias U3 activas, 12 semillas. **Estimación
acotada.** HIPÓTESIS: las copias son `rojo_U3` inertes, no cobran ni cuentan en el retarget: no añaden rentabilidad; ocupan
`mergeset_size_limit` (griefing menor, acotado por `6k`). **Cómo cambia el número.** Rentabilidad 0,99 → 0,99 (HIPÓTESIS).

## 48 · Incentivo a fusionar rojos

**Qué es.** Con coinbase propia, nadie cobra por incluir un rojo; en Kaspa cobra el fusionador (y eso duplica la parásita).
**Qué decidir/medir.** ¿Hace falta incentivo? `pick_virtual_parents` fusiona por defecto (R-FIN-12), sin coste para el
fusionador; el riesgo es un fusionador que **excluya** rojos a propósito (censura de rojos): sus bloques valen igual. HIPÓTESIS:
un incentivo pequeño (1-5 % de la coinbase del rojo al fusionador) no reabre la parásita (9b midió que el 100 % la duplica;
el efecto es lineal ⇒ 5 % ⇒ +5 %). **Verificar:** `r9b_d_coste.py` con reparto 95/5.

## 49 · Bloques fusionados fuera de la ventana del retarget (`mergeset_non_daa`)

**Qué es.** Kaspa excluye del DAA los bloques del mergeset cuyo `daa_score` cae fuera de la ventana. R-FIN-13′ no lo escribe.
**Qué escribir.** Regla: un bloque fusionado con `slot` fuera de la ventana vigente **no cuenta** en `N_obs` (igual que
Kaspa, `daa/window`); sí cobra (R-FIN-8′). **Estimación acotada.** Afecta a bloques con retraso > `W_RETARGET` slots (≥ 3 083 s):
solo particiones; efecto sobre el retarget < 0,1 % (HIPÓTESIS). **Verificar:** leer `rusty-kaspa/consensus/src/processes/window.rs`.

## 50 · Empalme conteo-peso

**Qué es.** `φ_c` está probado sobre conteo; `blue_work` es peso. Acotado por R-FIN-13 (`W ≥ 3 083`, `γ ≤ 0,25`): < 1 %,
< 0,4 puntos; Lema E1 (la deriva se cancela). **Qué demostrar.** Que `Σ w(SR)` sobre azules con retarget acotado es
`(1 ± ε)·conteo·w̄` sobre cualquier ventana `≥ W`: es una cota de variación del retarget, ya calculada
(`dag-poas-empalme-peso.md`). **Estimación.** ε < 1 %. Cerrable con una página.

## 51 · `c_a = c_h` en unidades de índice

**Qué es.** BDK Lema 13 cuenta sobre la cadena seleccionada del propio pasado; el ancla por slot cuenta índices de PoT. Tres
lecturas dan 40,7 / 41,2 / 41,9 %: mueve 1,2 puntos. **Qué demostrar.** Rehacer el Lema 13 con el ancla por slot: los índices
de PoT son los mismos para todos (reloj infalsificable), luego `c_a = c_h` **por construcción** (HIPÓTESIS fuerte: con ancla
por slot la laguna desaparece, porque ya no hay «unidades de índice de orden»). **Cómo cambia el número.** +1,2 puntos si se
confirma. **Verificar:** una página de D9.

## 52 · Coste del PoT por slot o por bloque en las reglas anti-DoS

**Qué es.** `C-NET-03/04` se calibraron con «validar cuesta un SHA3». **Qué escribir.** Con 1a-ii: el coste por cabecera es
O(1) (comparar contra el slot verificado) y el coste por slot es 96,1 ms una vez; el umbral anti-DoS de C-NET-04 pasa a
contarse en slots pendientes de verificar (≤ 10, como Autonomys) y no en trabajo por cabecera. **Estimación.** Presupuesto:
1 núcleo verifica 10 slots/s; con `MAX_SLOTS_IN_THE_FUTURE = 10`, el peor caso por segundo es acotado. **Verificar:**
reescribir C-NET-03/04 y medir bajo inundación (11).

---

# Resumen · Qué tendría más impacto y en qué orden

## Las soluciones con más impacto, ordenadas

| # | Solución | Problemas que toca | Impacto | Coste | Estado |
|---|---|---|---|---|---|
| 1 | **Medir `Δ_p99` en red de pruebas** con el DAG en `zx-node` | 1, 5, 16, 35, 44, 45 | Decide el colchón entero; sin ella todo es condicional | Implementar el nodo (semanas) | Bloqueado por las decisiones de Katana |
| 2 | **Desatar `L` de `F`** (`L = 1 h`, `F = 2 h`, `ρ_max = 3`) | 8, 15, 4 (lo evita), 6 | Margen frente al sembrador 1,9× → 3,6× sin segundo candado; `W/κ` dentro de BDK | Tolerancia a particiones 2 h → 1 h; re-medir `m` y `W_dec` | PLAUSIBLE (10c E); decisión F1 |
| 3 | **PoT por slot, nunca por bloque** (regla en C-NET-03/04) | 1, 11, 52 | Quita 96 ms/slot de la ruta de propagación; acota el DoS | Una regla y su implementación | Redacción pendiente |
| 4 | **Los dos sensores de eclipse + la tabla de Bitcoin Core** como C-NET | 2, 12 | Eclipse detectable en 30-120 s; comerciante protegido | Reglas de nodo, sin consenso | 11b en curso |
| 5 | **`k` con etiqueta de `Δ` tolerado** (posible `k = 40`) | 1, 44, 23 | Colchón hasta 20 s en vez de 16 | +cabeceras, `F_carrera` algo mayor; hard fork si se cambia después | 11a en curso |
| 6 | **Standby automático de timekeeper** (el TODO de Autonomys) | 3, 32 | Parón de «indefinido» a ~3 s | Implementación en `sc-proof-of-time` | Diseño escrito |
| 7 | **Sensor de `Δ`/parásita desde el DAG** | 1, 14, 35 | Convierte la laguna en métrica | Módulo de métricas | Diseño escrito |
| 8 | **Ancla por slot exacto y desempate por `solution_distance`** (6b/6c) | 6, 7, 10 | `m` 2,54 → ~1,2 (ESTIMACIÓN); soborno más caro | Reescribir Lema A4-slot; re-medir | HIPÓTESIS; una ronda D9 |
| 9 | **Demostrar Prop. 7 con U3″** (36) y `c_a = c_h` por slot (51) | 36, 51 | Cierra la única deuda que podría invalidar el diseño; +1,2 puntos | Una ronda D9 de teoría | Pendiente |
| 10 | **Maduración de parcela ≥ `L`** (R-FIN-10 aplicado a la parcela) | 8, 39 | El sembrador queda fuera por construcción | Verificar la lectura de C-EXP-04 | HIPÓTESIS |
| 11 | **Poda por `blue_work` sin niveles de PoW** y PoT por época | 34, 29 | Estado de nodo acotado | Diseño nuevo sobre el pruning de Kaspa | Investigación |
| 12 | **SPV sobre la cadena seleccionada** (28a) | 28 | 21,5 GB/año → 2-4 GB/año con confianza parcial | Compromisos en cabecera de cadena | Investigación |
| 13 | **Segundo candado (h) calibrado a `ρ_max = 2,5`** | 6, 7, 8, 4 | Steering ÷279; margen sembrador 2,8-5,5× | 0,15 núcleos/nodo, 3 líneas, lookahead 3,3 h | Decisión F2; compite con la fila 2 |
| 14 | **DAG KNIGHT bajo PoAS** | 1, 14, 30 | Única respuesta estructural a `Δ` | Meses; sin precedente en producción | Post-beta |
| 15 | **Comité BFT sobre el DAG** | 5, 30, 31 | Único camino por encima del 50 % y a confirmaciones de minutos | Identidad, validadores, segundo consenso | Post-beta, si alguna vez |

## El orden que recomiendo

1. **Esta semana, decisiones de Katana:** F1 (`L` desatada: sí, con `L = 1 h`), F2 (sin candado a `ρ_max = 3`, con (h) como
   opción escrita), F3 (`F = 2 h` hasta medir), F4 (`k` según 11a). Con eso se congelan constantes.
2. **Redacción en el SPEC:** PoT por slot (fila 3), reglas anti-eclipse y sensores (fila 4), `mergeset_non_daa` (49), unidades
   de R-FIN-13 (43), C-NET-03/04 (52).
3. **Implementar el DAG en `zx-node`** con el orden como pieza sustituible, standby de timekeeper (fila 6) y el sensor de
   `Δ` (fila 7).
4. **Medir `Δ`** (fila 1) y, con el número, fijar `F` de producción, `k` definitivo y el umbral publicado.
5. **Una ronda D9 de teoría** (fila 9) y **una D8 adversarial** sobre el diseño corregido entero, con las lagunas 40, 41, 44,
   47, 48 dentro.
6. **Después de la beta:** poda (fila 11), SPV parcial (fila 12), KNIGHT (fila 14).

## Lo que este informe no ha podido cerrar

Todo lo marcado HIPÓTESIS o ESTIMACIÓN. Las dos hipótesis más fuertes, que conviene atacar primero porque cambian más si
fallan: que la maduración de parcela (R-FIN-10) deje al sembrador fuera por construcción (fila 10), y que el ancla por slot
exacto no reabra los ataques de las rondas 7 y D9-c (fila 8). Y las dos medidas sin las que nada de esto tiene colchón
conocido: `Δ_p99` y `ρ_max`.
