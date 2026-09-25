# P-ECLIPSE — El adversario de red contra las reglas vigentes (agujero D2)

**Encargo:** `P-ZRX/P-ECLIPSE/PROMPT.md` · **Instrumento:** `investigacion/veritas/consenso/eclipse-red-v1/`
**Fecha:** 2026-09-24 · **Decide:** Katana. Este documento analiza y cuantifica; no decide y no fija
ningún parámetro.

**Etiquetas** (las del encargo §10, usadas sin excepción): `demostrado` · `verificado en fuente` ·
`medido` · `derivado` · `estimado` · `propuesto` · `no determinado` · `no verificado`.
«No se ha encontrado» y «no puede existir» se distinguen cada vez que aparecen.

---

## F1 · ¿Se sostiene §2 — el eclipse fabrica la partición de flujo?

**SÍ SE SOSTIENE, y ahora está derivado, no supuesto.** Con las reglas vigentes, un adversario de
red que **retiene el pasado honesto** de una víctima durante más de `F_slots` slots la deja
**permanentemente** fuera, sin que nadie haya roto una regla de consenso, y el coste se paga en
IP/tiempo, **no en espacio**. La cadena de la derivación (aritmética de enteros, `src/flujo.jl`):

> ⚠️ **LA CONDICIÓN, dicha antes que la conclusión porque es su premisa.** El resultado es
> **condicional a que la retención sea TOTAL**: si a la víctima le queda **una sola** vía al pasado
> honesto, recibe el bloque que cruza `T_j` antes de su activación `t_j`, su vista de época
> converge con la de la red y **no hay partición**. Esa captura total es exactamente el objeto de
> la **sección D** — y la sección D concluye que **el gestor de direcciones de ZEROX no existe**.
> Luego: **F1 está derivado y se sostiene, pero su premisa NO está determinada para ZEROX, porque
> hoy no hay red P2P que capturar.** El agujero es alcanzable en cuanto exista la red y el
> adversario pueda sostener la captura; hoy la pregunta «¿puede?» no tiene respuesta medida.
> (Detalle en `HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md` H-1.)

1. `C-FLU-03` corta la vista de época en `T_j + L_slots`; `C-FLU-04` ancla en el primer bloque de
   `Chn(V_j)` con `slot ≥ T_j`; `C-FLU-07` activa en `t_j = slot(I_j) + L_slots`, y como
   `slot(I_j) ≥ T_j`, se tiene **`t_j ≥ T_j + L_slots`**.
2. `C-FLU-22` da la ventana de adopción `[t_j, s₀ + F_slots)`, con `s₀` el último ancestro común.
   Luego la ventana es **VACÍA** siempre que `s₀ ≤ T_j + L_slots − F_slots`. — `derivado`
3. Si el corte sigue vivo en `T_j + L_slots`, la vista `V_j` diverge, el ancla diverge con ella y
   `C-FLU-10/12` dan **flujos distintos**. `C-FLU-14` impide **fusionarlos** y `C-FIN-01` impide
   **reorganizar** en cuanto `d ≥ F_slots`. Como `s₀ + F_slots ≤ T_j + L_slots`, cuando llega el
   corte de vista la prohibición de `C-FIN-01` **ya está activa**. — `derivado`
4. Duración mínima: `E_min = t_j − s₀ ≥ F_slots` slots = **`F` segundos** (con `σ = 1 s/slot`,
   `C-SLOT-01`). Es decir: **basta un eclipse de duración > `F_slots`**. — `derivado`

**El matiz que cambia el mecanismo, y que hay que decir en la misma frase:** un retraso
**uniforme** de `E < L_slots` **no** fabrica la partición, porque el bloque que cruza `T_j` se
produjo del orden de `L_slots` antes y la víctima ya lo tiene. Lo que la fabrica es **retener el
bloque que cruza `T_j`** —o el pasado que lo contiene—, y como todo bloque honesto posterior
desciende de él, retenerlo equivale a cortar el flujo honesto. **El eje no es el retardo: es la
retención.** — `derivado`, y coherente con que la ronda 11b midiera que un retraso uniforme de
hasta 200 s deja la tasa observada en 0,96–0,99 (11b §A.3, reproducido aquí).

**D2 y D3 son, por tanto, un solo agujero con dos nombres.** La partición de flujo no es solo
«se previene con `L_slots` frente a `Δ`», como dice la ficha D3: esa prevención supone que `Δ` es
una propiedad **natural** de la red, y un adversario de red **elige** cuándo y a quién retrasar.
Lo que `C-FLU-22` cura es el nacimiento **espontáneo**, que es el improbable; el nacimiento
**deliberado** no lo cura ninguna regla vigente. — `derivado`, y el propio SPEC ya lo dice de sí
mismo: su tabla de `C-FLU-22` asigna ventana **VACÍA** al «corte de red más largo que `L`».

### F5 · ¿Son compatibles la cota inferior de `PRESUP_NODO` (~11 min de CPU) y la resistencia a su agotamiento?

**La cota inferior se confirma; la compatibilidad queda INCONCLUSA, y la dirección del defecto no
depende de la medida que falta.** — `derivado`

- **Cota inferior, confirmada:** `PRESUP_NODO` debe bastar para verificar **una** rama rival
  completa = `F_slots` slots × 92 ms. Con `F_slots = 7200` → **662,4 s = 11,04 min**. El «≈11 min»
  del SPEC (`C-NET-33`) es correcto. `F_slots` es **símbolo**: el número sale de `F = 2 h`,
  **provisional de investigación**, y con él se etiqueta.
- **El defecto, y es de diseño antes que de número:** ese presupuesto se dimensiona para trabajo
  **AES** (92 ms/slot) y lo consume el **mismo** presupuesto el paso 1b de `C-POT-08`
  —comprobación **estructural** de `C-FLU-14`, **sin AES**—. El propio SPEC dice de ese paso:
  *«Lo que sí cuesta es recomputar cadena y flujo del sub-DAG ajeno, que es superficie de DoS»*.
  **Un presupuesto dimensionado por la carga cara y consumible por la barata es un defecto
  independientemente de cuánto más barata sea.** El descuento es `92 ms / ms_estructural`.
- **Lo que falta para cerrar el veredicto es UNA medida**: los milisegundos de paso 1b por bloque
  ajeno. **No está medida.** La cifra vecina que sí existe —1,33–9,86 ms por bloque de validar
  antes de reenviar (`veritas/rendimiento/coste-salto-v1`) — **no es** el paso 1b y no se usa como
  si lo fuera.
- `TAREAS.md` §2.9(a)4 ya declara esa rendija «parcialmente bajo control del atacante, que puede
  gastar presupuesto ajeno con tráfico barato del paso 1b». **Este encargo la confirma y la
  convierte en una pinza con dos lados: la cota inferior es aritmética y la superior no está
  derivada.**

---

## 0 · Qué se ha hecho, con qué, y qué garantiza

**El puerto está verificado contra el oráculo, y ésa es la base de todo lo demás.** El encargo
(§4.1) pone una puerta: *«reproduce primero la fila publicada de D8 A3b […] Si tu puerto no la
reproduce, el puerto está mal y se para ahí.»* La puerta está **superada, y no por aproximación**:

| | S=4 | S=20 | S=30 | S=150 | n_C |
|---|---:|---:|---:|---:|---:|
| Publicado (`salida_a3b.txt`, α=0) | 0,8218 | 0,6513 | 0,5920 | 0,5460 | 522 |
| **Este puerto** (`run.jl --control`) | **0,8218** | **0,6513** | **0,5920** | **0,5460** | **522** |
| Publicado (α=0,25) | 0,8806 | 0,7687 | 0,7289 | 0,6816 | 402 |
| **Este puerto** | **0,8806** | **0,7687** | **0,7289** | **0,6816** | **402** |

Coinciden **los promedios a cuatro decimales y los conteos de bloques**. Eso no es una coincidencia
estadística: obliga a que el calendario de eventos, el filtro aleatorio y el DAG sean **los mismos
números**. Para conseguirlo hubo que **portar el RNG de CPython bit a bit** (`MT19937` +
`init_by_array` + sembrado por cadena con SHA-512, `src/pyrng.jl`), porque el instrumento heredado
siembra con cadenas (`random.Random(f"{sem}|…")`) y ningún otro generador reproduce esa secuencia.
— `verificado` (tests + artefactos).

**Y las tres variantes reproducen las tablas publicadas de 11b, incluidos sus conteos** — `verificado`:

| variante | inv S=4/20/30/150 (régimen) | rojo_V | n | publicado |
|---|---|---:|---:|---|
| (ii) filtro `paso=0,00` | 0,7927 / 0,3109 / 0,1762 / 0,0000 | 1,0000 | 193 | ídem |
| (ii) filtro `paso=0,33` | 0,7070 / 0,0047 / 0,0000 / 0,0000 | 0,0093 | 215 | ídem |
| (ii) filtro `paso=0,10` | 0,7316 / 0,0579 / 0,0105 / 0,0000 | 0,0895 | 190 | ídem |
| (iii) retraso `E=20` | 0,7753 / 0,7022 / 0,0056 / 0,0000 | 0,0449 | 178 | ídem |
| (iii) retraso `E=60` | 0,7600 / 0,6743 / 0,6743 / 0,0000 | 1,0000 | 175 | ídem |
| (iii) retraso `E=200` | 0,8167 / 0,7500 / 0,7500 / 0,7500 | 1,0000 | 180 | ídem |
| (i) retiene PoT, `f_v=0,05` | 192 bloques antes / **0** después | — | — | ídem |

**Reutilización declarada, y su frontera.** GHOSTDAG, coloreo, orden y `rank` **no se reimplementan**:
se cargan de `GDR-v0.2` (`veritas/consenso/ghostdag-rank-v1/src/GhostdagRank.jl`) por `include`, que
es legítimo porque su `src/` **no importa ningún paquete externo** (`verificado en fuente`). Lo que
aporta P-ECLIPSE es el calendario Poisson, el retraso, las vistas por nodo, el ataque y los
sensores — todo lo que GDR-v0.2 **no tiene** (0 apariciones de `eclipse`, `poisson`, `retardo`,
`delta` en su `src/`). La equivalencia que permite usar un solo motor para los dos regímenes de peso
—**`SR = 0` en todo bloque da `blue_work = 2^128·|blues|`, que ordena igual que el peso por conteo
histórico**— se **comprueba**, no se supone (test dedicado).

**Y un defecto cazado por los tests, que se declara porque es instructivo:** el primer intento de
CDF normal (fracción continua de Lentz para `erfc`) daba `Φ(1,96) = 0,98896` en vez de `0,97500`, y
arrastrado hacía que `P(D>8)` saliera `0,0045` cuando es **forzosamente** `0,0100` por construcción
de la lognormal. Lo cazó un test de identidad, no una revisión. — `verificado`

**Los sensores E1/E2 también se re-derivan y se comprueban contra 11b** (`src/sensores.jl`, Poisson
y la frontera secuencial en `BigFloat` a 512 bits con la parte combinatoria exacta en
`Rational{BigInt}`):
- E2 · `n_min(W)` con menos de 1 falsa alarma al año: **6 / 23 / 66 / 211** para
  `W = 30/60/120/300` — idénticos a 11b §C.1; y `α` mínima para evadir `W = 300` durante 2 h =
  **0,9249**, idéntica a 11b §C.5. — `verificado`
- E1 · cola de la frontera secuencial: `P(D>8) = 0,0100000000` (identidad por construcción) y
  `P(L>8) = 0,014760`, exactamente el valor publicado. Y `B` reproduce **celda a celda** las dos
  columnas de 11b §B.1 en lognormal —`20,14 / 20,70` (p99=8, ε=0,1), `21,04 / 21,60` (p99=8,
  ε=1,0), `101,43 / 133,20` (p99=16, ε=1,0)— y en Pareto `76,40 / 138,92` (p99=8, ε=1,0) y
  `1 422,41` (p99=16, ε=1,0, columna de excursión). — `verificado`. **Queda UNA celda sin
  reproducir** (§6.7).

---

## 1 · F2 · Qué conclusiones de la ronda 11b sobreviven al régimen de hoy

Régimen histórico: `Δ = 4 s` (nominal, **simulado**), peso por conteo. Régimen vigente: `Δ` de
`DMS-v0.1` (**p99 0,26–0,45 s** con cabecera de 812 B, **0,26–0,60 s** en toda la rejilla) y peso
por `SR` de `C-GD-01` (`w = ⌊2^128/(SR+1)⌋`, con `SR` = `sd`). **La `Δ` de hoy es SIMULADA, no
medida en red desplegada**: `DMS-v0.1` lo declara y aquí se repite en cada fila que la usa.
— `medido` (12 semillas, horizonte 900 s, ventana de régimen `[600, 900] s`; artefacto
`resultados/run-regimen.txt`).

**Sobrevive (estructura):**

1. **La forma cerrada de la variante (ii) es exacta y invariante al régimen.** Con `paso = 0` la
   víctima queda confinada a sus propios bloques y `P(inválido) = e^{−f_v·S_max}` **no depende de
   `Δ` ni del peso**: la fila es idéntica —`0,7927 / 0,3109 / 0,1762 / 0,0000`, `rojo_V = 1,0000`,
   `n = 193`— en las **ocho** combinaciones. — `demostrado` para la forma cerrada, `medido` para la
   coincidencia.
2. **`rojo_V = 1,0000`: el granjero eclipsado pierde el 100 % de su recompensa.** Se mantiene en
   todo régimen y con los dos pesos para `E ≥ 60 s`. El daño no es `S_max`; es que la víctima
   construye una rama privada que se descarta entera. — `medido`
3. **La banda ciega y su transición brusca.** `E = 20 s` es benigno (`rojo_V ≤ 0,045`) y `E = 60 s`
   es catastrófico (`rojo_V ≥ 0,93`) en las ocho combinaciones. El salto está entre 20 y 60 s.
   — `medido`
4. **La estructura de ceguera de los sensores** (E1 ve (i) y (iii), E2 ve (ii); ninguna variante es
   visible a los dos) es una propiedad de qué observa cada sensor, no de las constantes. — `derivado`

**NO sobrevive (magnitud):**

5. **Ninguna cifra publicada de 11b es transferible.** La propia **fila de control se mueve**: con
   `SR = 0` y `Δ = 0,26 s` da `0,8448 / 0,7184 / 0,6628 / 0,6188` frente a `0,8218 / 0,6513 /
   0,5920 / 0,5460` — hasta **+7,3 puntos** en `S = 150`. Con el peso por `SR` y `Δ = 4 s` ya se
   mueve a `0,8199 / 0,6341 / 0,5747 / 0,5268`, y a `Δ = 0,26 s` da `0,8506 / 0,7050 / 0,6475 /
   0,6034`. — `medido`
6. **El peso por `SR` cambia conclusiones de segundo orden.** Lo más visible: `rojo_V` de la
   variante (iii) con `E = 60 s` cae de `1,0000` (conteo) a **`0,9543`** (SR) en los tres valores
   de `Δ` de hoy: un **4,6 %** de los bloques de la víctima deja de perderse. No cambia el
   veredicto, pero sí cualquier cifra que se hubiera citado sin recalcular. — `medido`
7. **La no monotonía en `Δ` es la prueba de que no se extrapola.** `iii E=20`, `S=20`: `0,7022`
   (`Δ=4`) → `0,6011` (`Δ=0,26`) → `0,7640` (`Δ=0,60`). **No es monótona en `Δ`**, así que
   interpolar entre los dos regímenes tampoco es legítimo. — `medido`

**Consecuencia para el repositorio:** el defecto 3 que el encargo atribuía a la ronda 11b —«usa un
peso por conteo; hoy `C-GD-01` pesa por `SR`»— **está confirmado y cuantificado**, y el defecto 2
—«está en Python»— queda reparado: el modelo vive ahora en Julia y reproduce el original.

---

## 2 · F3 · Sección D: IP y prefijos para capturar las salientes

**Lo primero, porque cambia la etiqueta de todo el punto: EL GESTOR DE DIRECCIONES DE ZEROX NO
EXISTE.** — `verificado en fuente`

- `crates/zx-p2p/src/limites.rs:174` → `MAX_PEERS_SALIENTES = 24` (**no 8**); `:182` entrantes = 72;
  `:185` total = 96; `:190` por peer = 1; `:195` pendientes = 32.
- `limites_ip.rs:75-104` agrupa por `/24` (IPv4) y `/64` (IPv6) **sólo** para límites y baneo
  (`MAX_POR_PREFIJO = 3`, `limites_ip.rs:46`).
- `limites_ip.rs:288-298`: `handle_established_outbound_connection` **no registra nada**; las
  **salientes no se contabilizan por prefijo**. Consecuencia de código: al desconectar por consenso,
  `prefijos_de(peer)` está vacío para un peer marcado por nosotros y **no se banea prefijo alguno**.
- **No se ha encontrado** `addrman`, tabla `tried`/`new`, `PrefixBucket`, ASN, `feeler`,
  `test-before-evict`, `anchor`, `block-relay-only`, bootstrap de Kademlia, suscripción a gossipsub
  ni bucle que mantenga un objetivo de salientes (grep exhaustivo; 0 coincidencias).

Por tanto **la cuenta es sobre un DISEÑO PROPUESTO**, como el encargo previó.

**Control de Heilman, con fuente abierta.** El artículo está en el repositorio
(`research/fuentes/heilman2015-eclipse.txt`) y se abrió: 8 salientes y 117 entrantes (`txt:233-236`);
`tried` = 64 buckets × 64 = 4096 (`txt:301-302`); `new` = 256 × 64 = 16384 (`txt:331-332`); grupo =
`/16` IPv4, IPv6 normal `/32`, Hurricane Electric `/36`, Tor 4 bits (`txt:307-310`, `344-348`);
`ADDR` admite 1000 direcciones y >1000 → lista negra (`txt:266-274`); 90 % con `f = 72 %` de `tried`
(`txt:557-559`); con selección aleatoria, 90 % exige `f = 98,7 %` (`txt:560-561`); peor caso con
CM1+2+6: 163K direcciones para 50 % y 284K para 90 % (`txt:1309-1311`). — `verificado en fuente`

**Y una advertencia de método que el encargo pidió reproducir y que hay que decir:** **el artículo
NO contiene una tabla de 50 %/90 % con IPs y prefijos `/16`.** Ese 50 % del ataque original sólo
está en la Figura 2, una gráfica. Los «50 %» que el texto escribe son **bajo contramedidas**.
— `verificado en fuente`

**Contramedidas, con fuente abierta por el autor de este informe** (API de GitHub):

| Contramedida | Cifra | Fuente | Etiqueta |
|---|---|---|---|
| `feeler` | 5540 IPs para ~50 % (frente a 595) | PR #8282 (merge 2016-08-25, 0.13.1) y PR #9037 | `modelo` del propio autor |
| `test-before-evict` | 620 IPs para ~50 % (frente a 595) | PR #9037 (merge 2018-03-06, 0.17.0) | `modelo` |
| ambas | 8600 IPs (×14,5 sobre 595) | PR #9037 | `modelo` |
| obsoletas en `tried` | «the lowest was **72 percent** stale, the highest was **95 percent** stale» | PR #8282, cuerpo | `medición` del autor |
| `anchor` (CM5) | **NO ENCONTRADO** número en el artículo; Core **nunca** implementó esa tabla | artículo §7; PR #17428 (0.21.0) para los *anchors* actuales | `no determinado` |
| `block-relay-only` | **NO está en el artículo**: es de Core 0.19.0 (PR #15759, 2019) | notas 0.19.0 | `verificado en fuente` |
| límite `ADDR` | hasta 1000 direcciones; >1000 → lista negra | artículo `txt:266-274`; `MAX_ADDR_TO_SEND` | `verificado en fuente` |

**El resultado estructural, en el modelo de selección uniforme** (producto hipergeométrico **exacto**
en `Rational{BigInt}`, `src/captura.jl`): 50 % exige `f = 0,5^(1/ω)` y 90 % exige `f = 0,9^(1/ω)` de
los grupos. — `derivado`

| `ω` | grupos para 50 % | grupos para 90 % |
|---:|---:|---:|
| 8 (Bitcoin 0.9.3, Kaspa) | 0,9170 | 0,9869 |
| 10 (8 + 2 `block-relay-only`) | 0,9330 | 0,9895 |
| **24 (ZEROX, `limites.rs:174`)** | **0,9716** | **0,9956** |

Sobre `/16` (65536 grupos) eso es 63 691 y 65 246 prefijos para `ω = 24`. **Es una cota SUPERIOR
del coste**: el atacante no necesita *poseer* el prefijo, le basta con que la víctima lo elija.
La cota inferior real depende de la tabla que se construya, y **no existe**.

**Aplicación a Kaspa** (`verificado en fuente`): `PrefixBucket` es `/16` en IPv4 y **`/64` en IPv6
nativa** (`utils/src/networking.rs:38-68`) — un espacio enorme, diversidad barata para el atacante;
`outbound_target = 8` (`kaspad/src/args.rs:115`) con una **inconsistencia del propio repositorio**
(`inbound_limit: 128` en `:116` frente a `--maxinpeers default: 117` en `:624`); `MAX_ADDRESSES =
4096` (`components/addressmanager/src/lib.rs:27`); y una **discrepancia doc/código de un exponente**
en el peso: el comentario dice `64^(x−y)/n` y el código `64^(MAX+1−y)/n = 64^(4−y)/n`
(`lib.rs:421-457`). La consecuencia que importa: la «normalización por prefijo» **divide el peso por
el número de IP del mismo `PrefixBucket`**, así que acumular IP en un solo `/16` **se penaliza**: el
recurso escaso deja de ser «IPs» y pasa a ser **«prefijos distintos»**. Kaspa **no tiene** `tried`,
`new`, frescura, evicción, `feeler`, `test-before-evict` ni `anchor` (grep: 0 coincidencias), luego
**las cifras de contramedidas de Heilman NO acotan a Kaspa**. No existe medición publicada de la
resistencia a eclipse de kaspad. — `no determinado`

**Qué parte de Heilman sobrevive al cambio de pila, dicho explícitamente:** sobrevive **el modelo
de captura por prefijo** (`p^(1/ω)`), que es una cuenta de elección sin reemplazo y no depende de
Bitcoin. **No sobrevive** el mecanismo: el ataque de Heilman vive de llenar `tried` con `ADDR` no
solicitado, del sesgo por frescura, de la evicción por edad y del **reinicio** para forzar la
selección. `libp2p` no tiene nada de eso: la identidad es un `PeerId` (clave pública) con
multiaddr, y **generar `PeerId` es casi gratis**, así que «X miles de direcciones» **no acota un
Sybil en libp2p**. Y en un DAG el «éxito» no es monopolizar la cadena: es retraso de finalidad,
sesgo del tipset y vistas divergentes. — `derivado`

---

## 3 · F4 · El coste absoluto del adversario de red

**No en fracción de espacio: en IP, prefijos, tiempo y ancho de banda.** — `derivado` sobre
`medido` donde se dice.

| Concepto | Cifra | Etiqueta |
|---|---|---|
| Espacio requerido | **CERO** para (i) y para las tres variantes con `α = 0` (11b §A.1, reproducido) | `medido` |
| IP/prefijos | los de la sección D: **no determinados** porque el gestor no existe; cota superior `0,9716` de los grupos para 50 % con `ω = 24` | `derivado` |
| Duración | **> `F_slots` slots** para partición permanente; `> 60 s` para el 100 % de pérdida de recompensa | `derivado` / `medido` |
| Ancho de banda si el atacante **cursa** el tráfico | `E=7200` slots: **0,72–1,44 GB** (0,80–1,60 Mbit/s sostenidos); `E=86400`: 8,6–17,3 GB | `derivado` sobre el tamaño de bloque del SPEC |
| Ancho de banda **real del ataque** | **≈ 0**: el atacante **retiene**, no cursa. El coste es **sostener la ocupación de las salientes** frente a la renovación de pares | `derivado` |
| `α` que lo abarata | **ninguno**: `α = 0` es el óptimo para (i), (ii) y (iii) en cuanto a coste. Con `α > 0` el atacante **paga espacio** y, en (ii), **daña menos** (`rojo_V` de 1,0000 a 0,0479 con `α = 0,10`; 0,0000 con `α = 0,33`, 11b §A.2 reproducido) | `medido` |

**La asimetría que decide:** el atacante que **retiene** gasta ancho de banda ≈ 0 y no necesita
espacio; lo único que necesita es **que la víctima no pueda cambiar de pares**. Por eso el borrador
de regla que más pesa no es un umbral de ancho de banda: es **`MUST` renovar pares** (ver
`BORRADORES-C-NET.md`). — `derivado`

---

## 4 · F6 · Borradores `C-NET-34+` y qué hay que medir antes de fijar cada valor

Los textos están en `BORRADORES-C-NET.md`, numerados desde **`C-NET-34`** (`C-NET-10` está retirada
con tombstone y **su número NO se reutiliza**), marcados **PROPUESTA**, y **sin fijar un solo
valor**: `B`, `W`, `n_min`, los presupuestos, `E`, `α` y los umbrales son **entradas**. Lo que hay
que medir en red real antes de fijar cada uno está en la tabla final de ese documento. — `propuesto`

---

## 5 · F7 · Veredicto

**Queda CERRADO (por regla, no por medición):**
- El multistream, por `C-FLU-13/14` (validez absoluta). Ya estaba decidido; este encargo no lo toca.
- F1 en su dirección: **el eclipse fabrica la partición de flujo**, y la duración mínima es
  `> F_slots`. Es una derivación sobre las reglas vigentes, no una simulación. — `demostrado`

**Queda ACOTADO:**
- El daño de las tres variantes con las reglas vigentes, con el puerto verificado: **100 % de la
  recompensa del granjero eclipsado** para `E ≥ 60 s`, con **cero espacio** y ancho de banda ≈ 0.
- La cota inferior de `PRESUP_NODO`: 11,04 min de CPU con `F_slots = 7200`. — `derivado`
- La captura de salientes en el modelo uniforme: `0,9716` de los grupos para 50 % con `ω = 24`.
  — `derivado`

**Queda ABIERTO:**
- **La cota superior de `PRESUP_NODO`** (el SPEC la declara no derivada) y, con ella, **la
  compatibilidad de F5**: falta **una** medida, los ms de paso 1b por bloque ajeno. — `no determinado`
- **El coste real en IP/prefijos**, porque el gestor de direcciones **no existe**: hoy el modelo
  no aplica. — `no determinado`
- **La `Δ` real**: la de hoy es **simulada**. Hasta que haya nodos corriendo, `L_suelo_slots` y el
  suelo de `F` siguen sin poder fijarse, y F2 sólo puede decir «la estructura sobrevive, las cifras
  no». — `no determinado`
- **La viabilidad de E2**, que depende de `s_λ` (inestabilidad de `λ`), no medida. — `no determinado`
- **El colateral honesto de `C-FLU-20`**, que el SPEC declara pendiente (`TAREAS.md` §2.9): aquí se
  da la forma (`≈ E/I_slots` épocas afectadas) y se dice que el número no existe. — `no determinado`

**Lo que decide Katana, en una línea cada cosa** (detalle y coste de cada rama en
`DECISIONES-PENDIENTES.md`): si se acepta que la partición deliberada es un fallo de modelo y no un
estado a gestionar; si se cablea la renovación obligatoria de pares; y si se mide el paso 1b antes
de intentar fijar `PRESUP_NODO`.

---

## 6 · Contradicciones y defectos encontrados (método)

El encargo pide **anotar** las contradicciones, no resolverlas en silencio. Las encontradas:

1. **`PROMPT.md` §4.2 dice «el agrupamiento que use el gestor de direcciones real» y, en el mismo
   punto, que si no existe se diga. No existe.** Además el encargo §0.1 afirma que el diseño «hoy
   solo tiene diversidad por prefijo (`C-NET-20`)»: `verificado en fuente`, `C-NET-20` es límite y
   baneo por prefijo, y la **diversidad como selección de pares no está implementada** — sólo
   declarada en `research/`. La premisa del encargo es imprecisa, y se anota.
2. **`C-FLU-20` vs el encargo:** el encargo dice que un bloque tardío que cambiaría un ancla ya
   activada queda «infusionable para siempre». El SPEC lo dice con esas palabras. Coinciden.
3. **`AGUJEROS-Y-SOLUCIONES.md` §3.2 propone el registro de parcelas con maduración y
   `LIBRO-DE-RESTRICCIONES.md` R-2 lo declara descartado.** Son de fechas 2026-09-21 y 2026-09-23:
   **manda la fecha posterior**, y no afecta a este encargo, pero se anota porque el encargo pide
   anotar toda contradicción encontrada.
4. **La ronda 11b tiene una columna que su propio texto no explica.** Su tabla §C.1 de sensibilidad
   a `s_λ` publica `n_min = 0` con `W = 300, s_λ = 0,20`, pero la función que el propio informe
   declara (`n_min_poisson`, sobre `μ = λW`) **no toma `s_λ` como argumento**. Esta re-derivación
   reproduce **exactamente** su columna `s_λ = 0` (6 / 23 / 66 / 211) y su columna de `α`
   (0,9249), pero **no** su columna `s_λ > 0`. **Es un defecto del instrumento histórico**: una
   tabla cuya cuenta no está escrita no es verificable. — `verificado`
5. **Kaspa tiene dos inconsistencias internas**, ambas `verificado en fuente`:
   `inbound_limit: 128` (`args.rs:116`) frente a `--maxinpeers default: 117` (`args.rs:624`); y el
   peso documentado `64^(x−y)` frente al implementado `64^(4−y)` (`addressmanager/src/lib.rs:421`
   vs `:451`).
6. **La cifra de `Δ` que el encargo da como «medida» es simulada.** `DMS-v0.1` lo declara; el
   encargo §3 también. Se usa con esa etiqueta en cada tabla.
7. **Una celda de 11b §B.1 no se reproduce, y la parametrización sí queda identificada.** 11b dice
   «Pareto ajustada a la misma mediana y p99» sin escribir la forma. **El ajuste estándar**
   —`a = ln 50 / ln(p99/mediana)`, escala `x_m = mediana / 2^(1/a)`— la reproduce **exactamente**:
   `76,40 / 138,92` (p99=8, ε=1) y `1 422,41` (p99=16, ε=1, excursión) salen idénticos a lo
   publicado. **La parametrización, por tanto, no está documentada pero sí determinada por el
   resultado.** Lo que **no** se reproduce es una sola celda: la de Pareto `p99=16` **por slot**,
   donde 11b publica `50 691,69` y aquí sale `20 048,48` (factor ≈2,5). No se ha encontrado la
   causa; lo más probable es una truncación distinta de la cola secuencial a esa distancia
   (la frontera se evalúa a `x ≈ 5·10^4`), pero **eso es una hipótesis, no un hallazgo**. Se anota.
   — `verificado` el desajuste, `no determinado` su causa.
   *Y el aviso se mantiene:* el primer ajuste que probé —`a = ln 100/ln(p99/mediana)`— daba
   `54,80 / 81,71` y `724,48`, **muy lejos** de lo publicado. Dos ajustes «razonables» de la misma
   frase difieren en un factor >2 en `B`. **El resultado de 11b «`B` es hipersensible a la forma de
   la cola» queda confirmado en su dirección y ahora también en su fragilidad documental.**

---

## 7 · Lo que esta investigación NO resuelve

- **No mide `Δ` en red real.** Usa la `Δ` **simulada** de `DMS-v0.1`. Todo resultado de F2 que
  dependa de `Δ` hereda esa etiqueta.
- **No construye ni propone un gestor de direcciones.** La sección D da el modelo de captura sobre
  un **diseño propuesto** y declara que el vigente no tiene ninguno. No hay coste en IP real.
- **No mide el paso 1b de `C-POT-08`.** Sin esa cifra, F5 queda **inconclusa** en su compatibilidad,
  aunque la dirección del defecto esté identificada.
- **No mide `s_λ`.** Sin ella, la viabilidad de E2 y su `n_min` no se pueden fijar.
- **No mide el colateral honesto de `C-FLU-20`.** Da la forma, no el número.
- **No simula la partición de flujo de extremo a extremo.** F1 es una **derivación** sobre
  `C-FLU-03/04/07/22` y `C-FIN-01`; el instrumento **no** construye dos vistas con dos flujos y
  anclas propias y comprueba la divergencia. Ese paso queda **propuesto y no ejecutado**: exige
  GHOSTDAG restringido a `V_j(B)` por nodo, que GDR-v0.2 no ofrece.
- **No re-mide nada en hardware.** El coste de 92 ms/slot de PoT y los 1,33–9,86 ms por salto se
  **citan** de `veritas/rendimiento/coste-salto-v1`; no se reejecutaron.
- **No decide.** `F_slots`, `L_suelo_slots`, `I_slots`, `PRESUP_PAR`, `PRESUP_NODO`, `B`, `W`,
  `n_min`, `E` y `α` siguen siendo **símbolos o entradas**. Ningún valor nuevo se fija aquí.
- **No convierte un sensor en un cierre.** E1 y E2 **hacen visible** el eclipse;
  **no lo impiden**. Un eclipse de `E ≥ 60 s` con `α = 0` cuesta el 100 % de la recompensa de la
  víctima aunque E1 lo detecte en ~25 s. La detección no es la defensa.
