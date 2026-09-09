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
