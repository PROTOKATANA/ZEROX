# Ronda 14B · Capa de comité con instancias continuas: el mínimo de irreversibilidad y su techo de gossip

**Agente:** d14-instancia · **Fecha:** 2026-09-10
**Encargo:** `ENCARGO.md` de este directorio. **Método:** `research/scripts/METODO-AGENTES.md`.
**Prioridad declarada:** bajar el tiempo de irreversibilidad lo más posible; el cliente ligero es secundario.
**Restricciones respetadas:** solo se escribió en `research/scripts/d14-instancia/`; no se modificó ningún otro
fichero; **no se ejecutó `git`** (el encargo de esta sesión lo prohíbe expresamente, por encima de
`METODO-AGENTES.md` §2, así que no hay commits); las fuentes web se guardaron en `fuentes/` para citarlas con línea.

> ⛔ **DESCARTADA COMO VÍA (decisión de Katana, 2026-09-10).** «Descarta todas aquellas opciones que
> impliquen un comité central que tome decisiones; busco descentralización y seguridad.» Toda capa
> de comité —incluida esta, aunque sus miembros se deriven del espacio y no pongan dinero— queda
> fuera. Este informe se conserva **como documentación del coste y del techo de gossip** de esa
> familia, no como camino de implementación. La única vía viva para bajar la irreversibilidad sin
> comité es la confirmación adaptativa de `research/scripts/d14-dagknight/`.

---

## 0 · Instrumentos, fuentes y control positivo

| Instrumento | Qué hace | Salida |
|---|---|---|
| `modelo_trafico.py` | tráfico por nodo de las tres topologías y mínimo `c` viable por presupuesto | `salida_trafico.txt` |
| `modelo_latencia.py` | `media = c/2 + r·Δ` y cota `c + r·Δ`; mínimo por presupuesto; motores | `salida_latencia.txt` |
| `modelo_seguridad.py` | `P(E1)`, viveza exacta con sortición, `α_max(c)`, `p_min(c)`, recuperación, `m` anclas | `salida_seguridad.txt` |
| `frontera_pareto.py` | tupla `(c, K, motor)` por presupuesto con las restricciones | `salida_pareto.txt` |
| `AUDITA_SCRIPTS.py` | detector de tautologías (T1/T2/T3/T4) | `salida_auditoria.txt` |

**Fuentes primarias usadas** (leídas en la línea citada):

| Fuente | Ruta | Qué se usa |
|---|---|---|
| FIP-0086 (F3) | `research/fuentes/fip-0086.md` | épocas 30 s `:39`, una instancia/época `:54,:704`, `+2` `:183`, 3 pasos `:255`, `Δ=6 s` y `2Δ` `:442,:509,:713`, QUALITY ≤99 tipsets `:654`, evidencia O(K) `:700,:924-929`, sub-época `:938`, VRF `:466,:1124` |
| d13 F1 | `research/scripts/d13-finalidad/f1-p040-latencia.md` | votos/certificado `§6.2`, latencia `§2.3`, viveza `§4.3`, `Δ` `§5.2` |
| d13 audita D9 | `research/scripts/d13-finalidad/audita-d9.md` | gossip 2,04 TB cifra 19; modelo de latencia §3.3; binomiales cifras 7–10 |
| d12 §F.1 | `research/scripts/d12-quorum/informe.md:524-545` | voto de PoAS = 484 B |
| Propuesta P-040 | `research/dag-poas-capa-finalidad.md` | R-FIN-15..22 `:60-133`; `K=4000` y sesgo `§4.D` `:205-233`; `m=2,822` en `research/dag-poas-ancla-de-orden.md:156` |
| Simplex | `fuentes/simplex-2023-463.txt` (ePrint 2023/463) | Tabla 1 `:206`, contribuciones `:245-265`, líder `:356-358`, Teorema 3.2 `:685`, O(n) multicasts `:769` |
| Algorand BA* | `fuentes/algorand-1607.01341v9.md` (arXiv:1607.01341v9) | `Λ+12,4λ` `:229`, bucle de 3 pasos `:240`, sortición secreta `:248-258`, 200 B `:1151`, `n≈1500` `:1290`, `8λ+Λ` `:1440` |
| Cordial Miners | `fuentes/cordial-miners-2205.09174v6.md` (arXiv:2205.09174v6) | O(n) caso bueno `:58,:116`, latencias `:152`, olas `:202`, líder `:564`, caso bueno=longitud de ola `:604`, esperado 4,5 `:610`, bits `:612-614` |

**Control positivo (obligatorio, METODO §4).** El instrumento reproduce tres números ya publicados antes de
medir: `484 B × 4000 × 1 051 200 = 2,0351 TB/año` (audita-d9 cifra 19: 2,04), `P[Bin(4000; 0,33) ≥ 1334] =
0,324391` (audita-d9 cifra 7: 0,3244) y la tabla de viveza de F1 §4.3 celda a celda (`0,25/0,90 → 1,292e-1`
frente a `1,3e-1`; `0,30/0,95 → 5,855e-1`; `0,33/0,98 → 9,093e-1`; `0,33/1,00 → 3,244e-1`). Los tres pasan.

---

## 1 · Modelo de tráfico: dónde está de verdad el techo del gossip (P1)

### 1.1 Las tres topologías y la fórmula

- **(a) gossip completo de votos.** Cada nodo retransmite los `f` votos de los `K` miembros por instancia:
  subida = bajada = `f·K·s_v` B/instancia. A `K=4000`, `s_v=484 B`, `f=1` y `c=30 s`:
  `484×4000×1 051 200/1e12 = 2,0351 TB/año` — el ancla verificada de `audita-d9.md` cifra 19.
- **(b) líder/agregador.** Los `K` miembros envían su voto al líder (el líder recibe `K·s_v`), y el líder
  difunde el certificado BLS de **724 B** (`f1-p040-latencia.md` §6.2). El nodo más cargado es el líder.
- **(c) agregación jerárquica.** `G` grupos de `g=K/G`; el jefe de grupo agrega `g` votos en
  `96 + ceil(g/8)` B (firma BLS agregada + mapa de bits) y lo manda al jefe global, que difunde los 724 B.
  `G` se elige para equilibrar los dos cuellos de bajada (`g·s_v` y `G·(96+g/8)`).

**Unidades.** TB decimal = `1e12 B` (el mismo del ancla: 2,04). En TiB (`2^40`) el ancla son **1,8509 TiB/año**.
`N(c) = 365·24·3600/c`: a 30 s **1 051 200** instancias/año; a 1 s **31 536 000**. Mbps decimal = `1e6 bit/s`.
**`Δ` no entra en este modelo**: es un parámetro de latencia/timeout, no de bytes; por eso las tablas de P1
no llevan columna `Δ` (sí la lleva P2).

### 1.2 Bytes/año por nodo · gossip completo · `s_v=484 B` (fragmento)

| `K` | `c` | `f=1` TB/año | `f=3` TB/año | `f=4` TB/año | `f=4` TiB/año |
|---:|---:|---:|---:|---:|---:|
| 4000 | 30 | 2,0351 | 6,1054 | **8,1405** | 7,4037 |
| 4000 | 5 | 12,2107 | 36,6322 | 48,8430 | 44,4224 |
| 4000 | 1 | 61,0537 | 183,1611 | **244,2148** | 222,1121 |
| 1000 | 30 | 0,5088 | 1,5263 | 2,0351 | 1,8509 |
| 500 | 30 | 0,2544 | 0,7632 | 1,0176 | 0,9255 |

`f=1` es el voto único; `f=3–4` son las fases de GossiPBFT (QUALITY/PREPARE/COMMIT ± DECIDE). El ancla
2,04 TB es `f=1`; el rango **6,1–8,1 TB** de `audita-d9.md` cifra 19 es `f=3–4`. El script imprime la
rejilla completa y la razón `f=4/f=1` sale 4,0000 en todas las celdas (escala lineal con `f` y con `1/c`).

### 1.3 Mínimo `c` viable por presupuesto de subida (`c = f·K·s_v/B`)

| Presupuesto | `K=500` | `K=1000` | `K=2000` | `K=4000` | `K=4000`, `s_v=200` |
|---|---:|---:|---:|---:|---:|
| **50 Mbps** (6,25 MB/s), `f=4` | 0,1549 s | 0,3098 s | 0,6195 s | **1,2390 s** | 0,5120 s |
| **1 Gbps** (125 MB/s), `f=4` | 0,0077 s | 0,0155 s | 0,0310 s | **0,0620 s** | 0,0256 s |
| **10 Gbps** (1,25 GB/s), `f=4` | 0,0008 s | 0,0015 s | 0,0031 s | **0,0062 s** | 0,0026 s |
| 50 Mbps, `f=3` | 0,1162 s | 0,2323 s | 0,4646 s | 0,9293 s | — |
| 50 Mbps, `f=1` | 0,0387 s | 0,0774 s | 0,1549 s | 0,3098 s | — |

**Líder/agregador.** El cuello es la **bajada del líder**: `c = K·s_v/B`. A `K=4000`, `s_v=484`:
**0,3098 s** (50 Mbps), **0,0155 s** (1 Gbps), **0,0015 s** (10 Gbps). La subida estricta del líder es solo el
certificado: `724/6,25e6 = 0,116 ms`. Si el presupuesto se interpreta como subida pura, el líder no limita;
si cubre subida+bajada (lectura conservadora), limita como se ha dicho. Bytes/año a `c=30`: líder
**2,036 TB** (recibe `K` votos), nodo normal **0,0013 TB**; red total `K·(s_v+724)` = **5,079 TB/año**.

**Jerárquica.** Para `K=4000`, `s_v=484` el óptimo es `G=125` grupos de `g=32`: cuello de bajada
**15 488 B/instancia** (el jefe de grupo recibe `32×484`; el jefe global recibe `125×100`), o sea
`c = 0,002478 s` a 50 Mbps y `0,000124 s` a 1 Gbps. Bytes/año a `c=30`: jefe de grupo **0,0163 TB**,
jefe global **0,0127 TB**, miembro **0,0005 TB**. La jerarquía reduce el tráfico del nodo más cargado
**~125×** (de 1,936 MB a 15,5 kB por instancia) frente al gossip completo y al pico del líder, pero
concentra confianza en dos niveles de jefes (targetables).

### 1.4 La sensibilidad que decide si el techo es real (LAGUNA)

El encargo fija `s_v ∈ {200, 484} B`, pero `audita-d9.md` §2.6 avisa de que el mensaje real de GossiPBFT
**no está medido**: las QUALITY llevan la cadena propuesta (hasta 99 tipsets, `fip-0086.md:654`) y las
evidencias llevan agregados BLS y RLE de firmantes. Barrido a `K=4000`, `f=4`, 50 Mbps:

| `s_v` | `c_min` | TB/año a `c=30` |
|---:|---:|---:|
| 200 B | 0,5120 s | 3,364 |
| **484 B** | **1,2390 s** | 8,140 |
| 1 000 B | 2,5600 s | 16,819 |
| 4 096 B | 10,4858 s | 68,891 |
| 68 000 B (QUALITY con 99 tipsets, cota) | **174,0800 s** | 1 143,706 |

La cota de 68 kB sale de las cabeceras del diseño vivo: 21,5 GB/año a `λ=1` bloque/s son
`21,5e9/31,536e6 ≈ 682 B` por bloque; 99 tipsets de un bloque ≈ 67,5 kB (`fip-0086.md:654` limita el
valor a 100 tipsets). Es un orden de magnitud, no una medida: **PLAUSIBLE**.

**Conclusión de P1.** Con los tamaños del encargo, el techo del gossip doméstico es **c ≥ 1,24 s**
(`K=4000`, 4 votos de 484 B, 50 Mbps) y el de un servidor de 1 Gbps es **c ≥ 62 ms**. La afirmación de
`f1-p040-latencia.md` §2.3/§6.4 de que a 5 s son «~21 TB/año, inasumible» **se refuta como problema de
ancho de banda**: 48,84 TB/año a 5 s (con `f=4`) son **12,4 Mbps** sostenidos, dentro de un 50 Mbps
doméstico; era un problema de **volumen mensual** (~4 TB/mes), no de tasa. El techo vuelve a mandar solo
si el mensaje real es del orden del QUALITY con cadena (68 kB → 174 s): eso es **LAGUNA** hasta medir el
`GossiPBFTMessage` real.

**Etiquetas P1:** fórmula y aritmética **DEMOSTRADO**; ancla 2,04 TB y sus múltiplos **VERIFICADO**
(reproducido por el instrumento); «el techo doméstico es ~1,24 s» **DEMOSTRADO** bajo el modelo de
retransmisión `f·K·s_v`; «el techo real depende del tamaño de mensaje» **PLAUSIBLE**; el 68 kB de QUALITY
**LAGUNA**.

---

## 2 · Modelo de latencia e irreversibilidad (P2)

Modelo del encargo (`audita-d9.md` §3.3): `latencia = espera[0,c] + T_cons`, **media `c/2 + T_cons`**,
**cota `c + T_cons`**, con `T_cons = r·Δ`, `r = 3–4` entregas BFT (`fip-0086.md:255`).

### 2.1 Tabla base · media / cota (s) · `r=3` y `r=4`

| `c` | `Δ=1` r3 | `Δ=4` r3 | `Δ=6` r3 | `Δ=16` r3 | `Δ=1` r4 | `Δ=4` r4 | `Δ=6` r4 | `Δ=16` r4 |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 30 | 18,00/33,00 | 27,00/42,00 | 33,00/48,00 | 63,00/78,00 | 19,00/34,00 | 31,00/46,00 | 39,00/54,00 | 79,00/94,00 |
| 10 | 8,00/13,00 | 17,00/22,00 | 23,00/28,00 | 53,00/58,00 | 9,00/14,00 | 21,00/26,00 | 29,00/34,00 | 69,00/74,00 |
| 5 | 5,50/8,00 | 14,50/17,00 | 20,50/23,00 | 50,50/53,00 | 6,50/9,00 | 18,50/21,00 | 26,50/29,00 | 66,50/69,00 |
| 2 | 4,00/5,00 | 13,00/14,00 | 19,00/20,00 | 49,00/50,00 | 5,00/6,00 | 17,00/18,00 | 25,00/26,00 | 65,00/66,00 |
| **1** | **3,50/4,00** | **12,50/13,00** | **18,50/19,00** | **48,50/49,00** | **4,50/5,00** | **16,50/17,00** | **24,50/25,00** | **64,50/65,00** |

**δ frente a Δ, y es la corrección clave.** El caso bueno de un BFT responsivo cierra cada fase cuando
llega el quórum, sin esperar el timeout (`fip-0086.md:715`). `T_cons = r·δ` con la **entrega real δ**;
`Δ` solo fija los timeouts (`2Δ`, `:442`) y la recuperación. El FIP mide δ: «reach almost all participants
within 6 seconds, with a majority receiving them even after 2 seconds» (`fip-0086.md:711`). Por tanto las
tablas de arriba son el caso **δ=Δ** (conservador): con `Δ=6` de timeout y `δ=1 s` real, el caso bueno es
3–4 s; con `δ=2 s` reales, 6–8 s; el timeout no entra. `Δ` real de ZEROX sigue **LAGUNA** (condición de
d12: `Δ_p99 < 4 s`, `d12-quorum/informe.md:513-515`).

### 2.2 Mínimo alcanzable con el presupuesto de red de un nodo

`c_min` de P1 + `media = c_min/2 + r·δ` (con `δ = Δ` en la tabla):

| Presupuesto | `c_min` (f=4, 484 B) | `r=3`, δ=1 | `r=3`, δ=4 | `r=3`, δ=6 | `r=4`, δ=4 | `r=4`, δ=6 |
|---|---:|---:|---:|---:|---:|---:|
| **50 Mbps** doméstico | 1,2390 s | **3,62 s** | **12,62 s** | **18,62 s** | 16,62 s | 24,62 s |
| **1 Gbps** servidor | 0,0620 s | 3,03 s | 12,03 s | 18,03 s | 16,03 s | 24,03 s |
| **10 Gbps** servidor | 0,0062 s | 3,00 s | 12,00 s | 18,00 s | 16,00 s | 24,00 s |
| 50 Mbps con `s_v=200` | 0,5120 s | 3,26 s | 12,26 s | 18,26 s | 16,26 s | 24,26 s |
| 50 Mbps con líder | 0,3098 s | 3,15 s | 12,15 s | 18,15 s | 16,15 s | 24,15 s |
| 50 Mbps jerárquica | 0,0025 s | 3,00 s | 12,00 s | 18,00 s | 16,00 s | 24,00 s |

**El presupuesto de red aporta menos de 0,7 s** entre un nodo doméstico y un servidor de 10 Gbps. El
mínimo lo fija `T_cons = r·δ`: **3,0–4,0 s** con δ=1, **12–16 s** con δ=4 (condición de d12), **18–24 s**
con δ=6 (default del FIP). Para bajar de ahí solo hay dos palancas: reducir `δ` (red) o reducir `r`
(motor). El gossip no es la palanca.

### 2.3 Motores: `T_cons` y extremo a extremo

| Motor | `T_cons` (entregas) | e2e (δ) | Caso bueno | Supuestos |
|---|---|---|---|---|
| GossiPBFT (F3) | 3–4 | 4–5 | 3 fases + DECIDE; espera de instancia | FIP Final, go-f3, BLS+BDN, VRF |
| **Simplex** | **3** | 5 | propuesta 3δ + 2δ de espera | PKI, firmas, PRF/CRS; prueba simple |
| Cordial Miners (ES) | 3 | 4–6 | ola de 3 rondas; esperado 4,5 | DAG, líder por ola, sin RB |
| BA* (Algorand) | **8** | 8–32 | `8λ+Λ` líder honesto; esperado `(12/p_h+10)λ+Λ` | VRF, firmas únicas, sortición secreta |

Fuentes: `fip-0086.md:255,441-454`; `fuentes/simplex-2023-463.txt:206,685`; `fuentes/cordial-miners-2205.09174v6.md:152,604,610`;
`fuentes/algorand-1607.01341v9.md:229,240,1440`. **Etiquetas P2:** la aritmética `c/2+T_cons` **DEMOSTRADO**;
`δ` real **LAGUNA**; el `8λ+Λ` de BA* **VERIFICADO en fuente** (no medido).

---

## 3 · Motores: rondas, mensajes, recuperación y targetabilidad (P3)

### 3.1 GossiPBFT (FIP-0086, estado Final, implementación go-f3)

- **Rondas:** 3 fases por ronda (QUALITY/CONVERGE, PREPARE, COMMIT) + fase DECIDE fuera del bucle
  (`fip-0086.md:441-454`); el FIP publica «three communication steps» (`:255`). Una instancia por época
  (`:704`), con finalización sub-época permitida (`:938`).
- **Mensajes:** cada participante hace *broadcast* en cada fase; la verificación de evidencias agrega
  `O(K)` claves públicas (`:700, :924-929`). Con `K=4000` son `4K = 16 000` difusiones/instancia y
  `4K(K−1) ≈ 6,4e7` mensajes punto a punto por instancia; a `c=1 s` eso son ~64 M msg/s agregados.
  El mensaje real no está medido (LAGUNA de P1).
- **Recuperación tras parada:** sin view-change; los timeouts crecen `2Δ·BackOffExponent^ronda`
  (`:509`); las QUALITY tardías se aceptan en cualquier ronda/fase (`:654`). La cadena de debajo sigue
  (`:58`). Es la recuperación más simple de los cuatro.
- **Targetabilidad:** **líderless** (no hay un líder que silenciar), pero el comité es **público**
  (F3 usa todos los elegibles, `:1125`; en P-040 el sorteo de R-FIN-16 es determinista y público,
  `capa-finalidad.md:71-75`). El VRF solo auto-asigna el ticket de CONVERGE (`:466, :1124`), no oculta
  quién está en el comité. Un atacante que conozca la tabla puede DoSear a los miembros exactos.

### 3.2 Simplex (ePrint 2023/463, Chan–Pass)

- **Rondas:** confirmación de propuesta **3δ** y tiempo de bloque 2δ (Tabla 1, `:206`); extremo a extremo
  **5δ** (Teorema 3.2, `:685`). Es el óptimo de la literatura para líderes rotatorios.
- **Mensajes:** `O(n)` multicasts por iteración (`:769`) — propuesta + voto + finalize —, es decir `O(n²)`
  punto a punto, con subsampling `polylog(λ)`/lineal (`:245-265`). Sin erasure codes.
- **Recuperación:** voto por bloque *dummy* tras un temporizador de 3Δ (`:302-400`); a diferencia de los
  protocolos «streamlined», Simplex no tiene el retraso extra de 2Δ antes de proponer cuando el líder
  anterior cayó (`:816-820`); esperado pesimista `3,5δ+1,5Δ`, peor caso `4δ+ω(logλ)(3Δ+δ)` (`:245-260`).
  Requiere una secuencia de líderes honestos; el líder se conoce por adelantado (`L_h = H*(h) mod n`,
  `:356-358`) → **targetable** en su forma base; el subsampling puede hacerlo privado.

### 3.3 Algorand BA* (arXiv:1607.01341v9)

- **Rondas:** BA* binario es un bucle de 3 pasos, un mensaje por jugador y paso, con probabilidad >1/3 de
  terminar por vuelta (`:240`); el bloque tarda `8λ+Λ` con líder honesto y `(12/p_h+10)λ+Λ` en esperanza
  (`:1440`), con `λ` = propagación de 1 500 mensajes de 200 B (`:229, :1151`).
- **Mensajes:** por paso solo habla el comité seleccionado (~1 500 verificadores, `:1290`); el gossip
  propaga esos ~1 500 mensajes de 200 B por paso. La complejidad por nodo es `O(comité)` por paso, no `O(K)`.
- **Recuperación:** **player replaceability** (`:256-258`): cada paso usa un conjunto nuevo e independiente;
  no hay view-change y un comité corrupto no contamina el siguiente.
- **Targetabilidad:** **la resuelve**. La sortición es **secreta por paso** con credenciales VRF
  (`:248-250`): cada usuario comprueba en privado si está seleccionado y solo se revela al actuar; el
  adversario no sabe a quién atacar antes de que el mensaje esté en la red. Es el único de los cuatro cuyo
  diseño trata la targetabilidad del comité como parte del protocolo.

### 3.4 Cordial Miners (arXiv:2205.09174v6, DISC 2023)

- **Rondas:** ES, ola de 3 rondas; caso bueno = longitud de ola = **3** (`:202, :604`); esperado 4,5
  (`:610`). La versión asíncrona: ola de 5, bueno 5, esperado 7,5 (`:152`).
- **Mensajes:** un bloque por minero y ronda (sin RB); caso bueno `O(n)` amortizado por transacción, peor
  caso `O(n²)` (`:58, :116, :612-614`). Es el que menos mensajes necesita para cadencia corta.
- **Recuperación:** **sin view-change**: el blocklace crece; si una ola no tiene líder final, una ola
  posterior ordena lo pendiente; los equivocadores se excluyen localmente y se excomulgan (`:564-614`).
- **Targetabilidad:** en ES el líder se elige por adelantado con un método determinista (p. ej. round-robin,
  `:564`) → targetable; la versión asíncrona elige el líder retrospectivamente con una moneda compartida
  (`:564, :572`), lo que lo hace impredecible a costa de 7,5 rondas esperadas.

### 3.5 Tabla comparativa

| | GossiPBFT | Simplex | BA* | Cordial Miners |
|---|---|---|---|---|
| `T_cons` caso bueno | 3–4 | **3** | 8λ | **3** (ES) |
| e2e típico | 4–5 δ | 5 δ | 8–32 λ | 4–6 rondas |
| Mensajes por nodo/ronda | 3–4 broadcasts | 3 multicasts | comité por paso | **1 bloque** |
| Recuperación | timeouts, sin view-change | dummy + timeout | reemplazo por paso | sin view-change |
| Líder | ninguno (leaderless) | público/rotatorio | secreto | público (ES) |
| Comité | público | público (subsampling opcional) | **secreto por paso** | público |
| Implementación | **go-f3 (FIP Final)** | paper | Algorand mainnet | paper (DISC) |

**Respuesta directa a la pregunta del encargo:** sí, la sortición secreta por paso de BA* **resuelve** la
targetabilidad del comité público: oculta la composición hasta que el miembro actúa y el reemplazo por paso
hace inútil corromper el comité actual. El precio es `8λ+Λ` en el caso bueno (≈2× las 3–4 entregas de
GossiPBFT/Simplex) y la maquinaria de VRF/credenciales. En un comité derivado del espacio el peso es
espacio-tiempo, así que la credencial debe atar la prueba de espacio (si no, el Sybil de claves reparte el
mismo peso); la semilla de la sortición debe ser impredecible (PoT/cadena previa), no el ancla elegible —
si no, se reintroduce el *steering* de R-FIN-16.

---

## 4 · Seguridad y viveza: los umbrales que de verdad limitan `c` (P4)

### 4.1 Seguridad · `P(E1) = P[Bin(K,α) ≥ ⌈K/3⌉]` (el atacante alcanza ⅓ del comité)

| `K` | `α=0,25` | `α=0,28` | `α=0,30` | `α=0,33` |
|---:|---:|---:|---:|---:|
| 500 | 1,595e-05 | 4,656e-03 | 5,473e-02 | 4,412e-01 |
| 1000 | 1,697e-09 | 1,050e-04 | 1,092e-02 | 4,056e-01 |
| 2000 | 3,985e-17 | 9,205e-08 | 6,501e-04 | 3,777e-01 |
| **4000** | **2,016e-32** | **7,377e-14** | **2,525e-06** | **3,244e-01** |

Con `m` anclas (`best-of-m`, `capa-finalidad.md` §4.D): a `α=0,33`, `K=4000`, `m=1/2,822/2,955/151` →
**0,324 / 0,669 / 0,686 / 1,000**. La cota de `m=151` hace la parada segura; el `m` vivo es 2,822
(`dag-poas-ancla-de-orden.md:156`). El umbral de seguridad de GossiPBFT es **<⅓**, no <⅔
(`fip-0086.md:65, :248`): la propuesta original solo calculaba `P(A≥⅔K)` y por eso decía «la seguridad no
se toca»; con el umbral correcto, a `α=0,33` la condición de seguridad falla en el 32–100 % de las
instancias (con `m=151`, siempre).

### 4.2 El presupuesto anual endurece los dos umbrales al bajar `c`

`α_max` para riesgo anual < 1e-6 y < 1e-12 (K=4000, m=1):

| `c` | `N/año` | `α_max(1e-6)` | `α_max(1e-12)` |
|---:|---:|---:|---:|
| 30 s | 1 051 200 | 28,2431 % | 27,0490 % |
| 10 s | 3 153 600 | 28,1371 % | 26,9646 % |
| 5 s | 6 307 200 | 28,0715 % | 26,9119 % |
| 2 s | 15 768 000 | 27,9860 % | 26,8431 % |
| **1 s** | 31 536 000 | **27,9223 %** | **26,7916 %** |
| 0,1 s | 315 360 000 | 27,7163 % | 26,6214 % |

Bajar `c` de 30 a 1 s cuesta **0,32 pp** de `α_max` (1e-6): pequeño pero real. Con `m=151` el coste es
mayor en términos absolutos: `α_max(1e-6)` a `K=4000` cae de 27,7769 % (c=30) a 27,4836 % (c=1).

### 4.3 Viveza · `p` de encendido (la restricción más dura)

P(no quórum) exacta con sortición, `K=4000`, `m=1` (el atacante que censura retiene sus votos; los
honestos deben llegar solos a ⅔K):

| `α` \ `p` | 0,90 | 0,95 | 0,98 | 1,00 |
|---:|---:|---:|---:|---:|
| 0,25 | 1,292e-01 | 1,308e-10 | 5,586e-22 | 2,016e-32 |
| 0,28 | 9,933e-01 | 9,276e-03 | 4,489e-08 | 7,377e-14 |
| 0,30 | 1,000 | 5,855e-01 | 4,293e-03 | 2,525e-06 |
| 0,33 | 1,000 | 1,000 | 9,093e-01 | 3,244e-01 |

**`p` mínimo para un riesgo anual de parada dado** (K=4000, m=1):

| `α` | c=30: 1e-2 / 1e-6 | c=5: 1e-2 / 1e-6 | c=1: 1e-2 / 1e-6 |
|---|---|---|---|
| 0,25 | 0,9434 / 0,9568 | 0,9463 / 0,9590 | **0,9487 / 0,9610** |
| 0,28 | 0,9827 / 0,9966 | 0,9857 / 0,9990 | **0,9882 / imposible** |
| 0,30 | imposible | imposible | imposible |
| 0,33 | imposible | imposible | imposible |

**Hallazgo.** A `α=0,28` y `c ≤ 2 s` **ningún `p`** mantiene el riesgo anual de parada por debajo de 1e-6
(el suelo `P(E1)=7,377e-14` por instancia supera `1e-6/N(c)`). La palanca real de la capa no es la
cadencia: es `p` (encendido del granjero doméstico, medida de campo pendiente) y `α` (≤ 28 %). A `α=0,30`
ni el objetivo 1e-2 es alcanzable. Esto refuerza a `f1-p040-latencia.md` §4: la capa es mejora del caso
normal, no garantía del umbral.

**`m` anclas en viveza** (`best-of-m`): a `α=0,28`, `p=0,98`: `P(parada)` = 4,49e-08 (m=1), 1,33e-07
(m=2,955), **6,78e-06** (m=151). A `α=0,30`, `p=0,98`, `m=151`: **0,478** por instancia. La cota de 151
anclas que protege la seguridad (`P(mentira)=0`) es la que **rompe la viveza**, exactamente como dijo §4.D.

### 4.4 Recuperación tras parada

Instancias independientes (entropía nueva, comité nuevo): el número hasta la primera que cierra es
geométrico. Con el atacante pasivo que bloquea cuando `A ≥ ⅓K`:

| Escenario | `P(E1)` | `E[instancias]` | c=30 | c=5 | c=1 |
|---|---:|---:|---:|---:|---:|
| `α=0,25`, m=1 | 2,016e-32 | 1,00 | 30,0 s | 5,0 s | 1,0 s |
| `α=0,30`, m=1 | 2,525e-06 | 1,00 | 30,0 s | 5,0 s | 1,0 s |
| `α=0,33`, m=1 | 3,244e-01 | 1,48 | 44,4 s | 7,4 s | 1,5 s |
| `α=0,33`, m=2,822 | 6,693e-01 | 3,02 | 90,6 s | 15,1 s | 3,0 s |
| `α=0,33`, m=151 | 1,000 | ∞ | nunca | nunca | nunca |

Con el atacante activo (elige cuándo y qué ataca) la garantía publicable no es 1,5–3 s: es **2 h hasta
que el ataque cese** (`R-FIN-7` sin cambios, `ancla-de-orden.md:271-273`; `fip-0086.md:58`). Con `α=0,33`
sostenido y la cota de `m`, la capa no vuelve.

### 4.5 Comité público frente a secreto: el ataque que no cuantifica el umbral

Con el comité **público** (R-FIN-16 es determinista, `capa-finalidad.md:71-75`), el atacante conoce las
`K=4000` plazas. Para **parar** la instancia solo tiene que silenciar las plazas honestas que faltan para
el quórum de ⅔:

| `α` | plazas del atacante `A` | honestas `K−A` | plazas honestas a silenciar (`K−A−⌈2K/3⌉+1`) |
|---:|---:|---:|---:|
| 0,00 | 0 | 4000 | 1 334 (33,3 %) |
| 0,25 | 1000 | 3000 | 334 (8,3 %) |
| 0,28 | 1120 | 2880 | **214 (5,3 %)** |

Es decir: a `α=0,28`, un DoS dirigido contra **214 claves conocidas** (5,3 % del comité) detiene la capa
—mucho más barato que el umbral de ⅓—. Con `m` anclas el atacante elige además el comité que más le
conviene. La **sortición secreta por paso** de BA* elimina la ventaja: el atacante no sabe a quién atacar
hasta que el voto está en la red, y el reemplazo por paso hace que el comité siguiente sea otro. Sin ella,
la capa de P-040 es **targeteable de forma determinista**, y eso no lo arregla subir `K`.

**Etiquetas P4:** binomiales y `α_max` **VERIFICADO** (control contra D9/F1); `p_min` **VERIFICADO
COMPUTACIONALMENTE**; el ataque de DoS dirigido **DEMOSTRADO** sobre el texto (público + umbral ⅔);
«BA* lo resuelve» **VERIFICADO en fuente**; la `p` real **LAGUNA** (medida de campo).

---

## 5 · Frontera de Pareto y recomendación (P5)

Con `K=4000` (el `K` que compra seguridad frente a `m=151`, `capa-finalidad.md:229`) y las restricciones
(i) presupuesto de subida, (ii) `α ≤ α_max(c)` para 1e-6 anual, (iii) `p ≥ p_min(c)` si existe:

| Presupuesto | Topología | `c_min` | Mejor motor | Media (δ=1) | Media (δ=4) | Media (δ=6) |
|---|---|---:|---|---:|---:|---:|
| **50 Mbps** doméstico | gossip completo | 1,2390 s | Simplex/GossiPBFT (r=3) | **3,62 s** | **12,62 s** | **18,62 s** |
| 50 Mbps | líder/agregador | 0,3098 s | Simplex/GossiPBFT | 3,15 s | 12,15 s | 18,15 s |
| 50 Mbps | jerárquica | 0,0025 s | Simplex/GossiPBFT | 3,00 s | 12,00 s | 18,00 s |
| **1 Gbps** servidor | gossip completo | 0,0620 s | Simplex/GossiPBFT | 3,03 s | 12,03 s | 18,03 s |
| **10 Gbps** servidor | gossip completo | 0,0062 s | Simplex/GossiPBFT | 3,00 s | 12,00 s | 18,00 s |
| cualquiera | cualquiera | — | **BA*** (comité secreto) | 8,00 s | 32,00 s | 48,00 s |

**Tupla recomendada (prioridad: mínima irreversibilidad):**
**`(c = 1,24 s, K = 4000, GossiPBFT)`** con gossip completo en un nodo doméstico de 50 Mbps, o
**`(c = 1 s, K = 4000, GossiPBFT)`** con líder/agregador (el líder necesita `K·s_v/c = 1,94 MB/s` de
bajada). `c = 1,24 s` es el **suelo** del enlace; `c = 2 s` deja margen y cuesta +0,38 s de media. Coste:
**media 12,62–16,62 s con δ=4 s** (condición de d12), **18,62–24,62 s con δ=6 s** (default FIP),
**3,62–4,62 s si δ=1 s**. La seguridad exige `α ≤ 27,94 %` (1e-6/año) y la viveza `p ≥ 94,9 %` a
`α=0,25`; a `α=0,28`, `p ≥ 98,8 %` (1e-2/año) y el 1e-6 es inalcanzable a `c ≤ 2 s`.

**Caveat de cadencia del motor.** La tabla usa el modelo del encargo (`media = c/2 + T_cons`), que supone
instancias encadenadas cada `c` independientemente de la ronda. Eso vale para GossiPBFT si se pipelinean
instancias (el FIP admite sub-época, `:938`) y para Cordial Miners (1 bloque por ronda). En cambio Simplex
solo propone un bloque por iteración, con tiempo de bloque 2δ: si `c < 2δ`, la espera real es 2δ y su e2e
es `5δ` (`:206, :685`), no `c/2 + 3δ`. Con δ=4 s eso es 20 s frente a los 12,62 s de GossiPBFT pipelined;
la ventaja de Simplex es la simplicidad de la prueba y el `r=3` fijo, no la cadencia.

**Motor recomendado: GossiPBFT** (FIP-0086 Final, go-f3, leaderless, `r=3–4`), a `c = 1–2 s` y `K=4000`:
**12,6–16,6 s de media con δ=4 s** y 18,6–24,6 s con δ=6 s. Es el que da el mínimo con menos supuestos de
despliegue (especificación Final + implementación de referencia + pruebas en material suplementario). El
**mínimo absoluto** lo da **Simplex** (`r=3` fijo, `O(n)` multicasts, prueba más simple, responsivo), pero
su tiempo de bloque 2δ lo penaliza si `c < 2δ`. Si la targetabilidad del comité público entra en el
modelo, **BA*** (sortición secreta por paso) es el único que la resuelve, a cambio de `8λ` (≈2×). **Cordial
Miners** es el que permite cadencia corta sin multiplicar gossip (1 bloque/ronda, `O(n)` en el caso bueno)
y sin view-change, pero su líder ES es público y es el más nuevo.

**Techo que limita de verdad:** no es el ancho de banda. Con los tamaños del encargo, el gossip doméstico
permite `c ≥ 1,24 s` (subida de 62 Mbps a `c=1 s`, 4 votos de 484 B) y un servidor permite `c ≥ 62 ms`;
la irreversibilidad la fija `T_cons = r·δ` (3–4 entregas). El techo solo volvería a mandar si el mensaje
real fuese el QUALITY con cadena (~68 kB → `c ≥ 174 s`): **LAGUNA** hasta medir `GossiPBFTMessage`.

---

## 6 · Veredicto

| Punto | Conclusión | Etiqueta | Número |
|---|---|---|---|
| P1 · gossip completo | `f·K·s_v` por nodo; ancla 2,04 TB reproducida | **VERIFICADO** | 2,0351 TB/año (f=1, K=4000, 30 s) |
| P1 · techo doméstico | `c ≥ 1,24 s` (4 votos 484 B, 50 Mbps); 62 ms a 1 Gbps | **DEMOSTRADO** | 1,2390 s / 0,0620 s |
| P1 · líder/jerarquía | el cuello es la bajada del líder; la jerarquía la reduce ~125× | **DEMOSTRADO** | 0,3098 s / 0,0025 s |
| P1 · «21 TB/año es inasumible» | falso como ancho de banda: son 12,4 Mbps a 5 s | **REFUTADO** | 48,84 TB/año = 12,39 Mbps |
| P1 · QUALITY con cadena | si el mensaje real es ~68 kB, `c ≥ 174 s` | **LAGUNA** | medir `GossiPBFTMessage` |
| P2 · latencia | media `c/2 + T_cons`, cota `c + T_cons` | **DEMOSTRADO** | 12,50/13,00 s (c=1, r=3, Δ=4) |
| P2 · δ vs Δ | el caso bueno va a δ; Δ fija timeouts | **VERIFICADO en fuente** | FIP `:711, :713` |
| P2 · mínimo doméstico | 3,62 / 12,62 / 18,62 s (δ=1/4/6) | **DEMOSTRADO** (δ dado) | `c_min=1,24 s` |
| P2 · mínimo servidor | 3,03 / 12,03 / 18,03 s | **DEMOSTRADO** (δ dado) | `c_min=0,062 s` |
| P3 · motores | `T_cons` 3–4 (GossiPBFT), 3 (Simplex/Cordial), 8λ (BA*) | **VERIFICADO en fuente** | Tabla §3.5 |
| P3 · targetabilidad | BA* la resuelve con sortición secreta por paso | **VERIFICADO en fuente** | Algorand `:248-258` |
| P4 · seguridad | umbral <⅓; `α_max(1e-6)` 28,24 % a 30 s → 27,92 % a 1 s | **VERIFICADO** | 340 999 paradas/año a α=0,33 |
| P4 · viveza | `p ≥ 94,9 %` (α=0,25, 1e-6); a α=0,28, 1e-6 imposible a c≤2 s | **VERIFICADO** | `p_min` tabla §4.3 |
| P4 · DoS dirigido | comité público: 214 plazas (5,3 %) silencian la capa a α=0,28 | **DEMOSTRADO** | R-FIN-16 público |
| P5 · recomendación | `(c=1,24 s, K=4000, GossiPBFT)`; BA* si el comité debe ser secreto | **PLAUSIBLE** | 12,62–16,62 s con δ=4 s |
| P5 · techo real | `δ` y `r`, no el ancho de banda; LAGUNA si QUALITY grande | **DEMOSTRADO / LAGUNA** | — |

**Respuesta a la pregunta del encargo.** El mínimo de irreversibilidad de la capa con cadencia `c < 30 s`
es **`c/2 + 3–4·δ`**: **3,6 s** con `c = 1,24 s` y `δ = 1 s`; **12,6 s** con `δ = 4 s` (la condición de
d12); **18,6 s** con `δ = 6 s` (el default del FIP). El techo de gossip doméstico (`c ≥ 1,24 s` con 4
votos de 484 B) apenas aporta 0,6 s frente a un servidor. El motor que da ese mínimo con menos supuestos
para desplegar es **GossiPBFT** (FIP Final + go-f3, leaderless, `r=3–4`); el de mínimo absoluto es
**Simplex** (`r=3`); y si la targetabilidad del comité público entra en el modelo, **BA*** es el único que
la resuelve, a cambio de `8λ` (≈2×). La restricción que de verdad impide prometer menos de ~12 s no es la
red: es `δ` (sin medir), `α ≤ 28 %` y `p ≥ 95–99 %` (sin medir).

---

## 7 · Errores propios

1. **Confundí el evento de seguridad con la condición de viveza.** Mi primera `p_parada_exacta` calculaba
   `H < need − A` (el atacante cuenta para el quórum), y daba 0 en toda la tabla. El atacante que censura
   **retiene** sus votos: los honestos necesitan `⅔K` solos (F1 §4.3). Corregido; el control positivo
   contra las cuatro celdas publicadas pasa.
2. **`alpha_max` con `m=151` reventaba** por `log1p(−1)` cuando `p→1` y por `−inf` cuando `p` subdesborda.
   Corregido con centinelas finitos (`_log_riesgo`).
3. **En el primer volcado del tráfico puse mal el bytes/año del miembro jerárquico** (0,016 TB en vez de
   0,0005) y etiqueté como «red total» la cifra del líder. Corregido en el script y en el informe.
4. **La tabla de motores de `modelo_latencia.py` mezclaba `T_cons` con extremo a extremo** (GossiPBFT sin
   espera, Simplex con espera). Reescrita separando `T_cons` y `e2e`.
5. **El suelo técnico de `c` en la frontera** (`max(cmin, 0.05)`) no es una restricción del protocolo: es
   mío, para no dividir por cero. Lo declaré en el script; en la recomendación uso `c ≥ 1 s` doméstico por
   margen sobre el pico, no por el protocolo.

---

## 8 · Auditoría `AUDITA_SCRIPTS.py`

Salida exacta sobre `research/scripts/d14-instancia/`:

```
Scripts analizados: 4

======================================================================
Sospechas totales: 0
```

No hay marcas T1 (parámetro del atacante sin usar), T2 (literal que sobrescribe un cálculo), T3 (comparación
consigo mismo / mismo RHS) ni T4 (menos de 12 semillas). El criterio α se cumple: `modelo_seguridad.py`
cambia con `α` en las tres tablas que dependen de él (E1, viveza, `α_max`) y `frontera_pareto.py` resuelve
`α_max(c)`; `modelo_trafico.py` y `modelo_latencia.py` no dependen de `α` porque son modelos de bytes y de
tiempo, no de adversario.
