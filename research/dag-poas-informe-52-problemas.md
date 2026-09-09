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
