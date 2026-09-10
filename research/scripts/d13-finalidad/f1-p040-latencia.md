# F1 · ¿Son reales los ~30 s? Auditoría de latencia de la capa de finalidad P-040 (estilo F3)

**Agente:** F1 · **Fecha:** 2026-09-10 · **Encargo:** `research/scripts/d13-finalidad/ENCARGO.md` §F1.
**Método:** `research/scripts/METODO-AGENTES.md` (sin presupuesto de tiempo; LAGUNA nunca por falta de tiempo).
**Restricción de esta entrega:** un solo fichero. No se crean scripts en el directorio; los cálculos propios van
embebidos y son reproducibles (ver §10). No se ha modificado ningún otro fichero del repositorio.

**Prioridad declarada por Katana:** bajar el tiempo de irreversibilidad lo más posible. El cliente ligero es secundario.
Por eso el informe ordena todo alrededor de una pregunta: **¿los ~30 s son un suelo, una elección o una suposición?**

**Fuentes primarias leídas enteras antes de medir**

| Fuente | Ruta | Qué se usa |
|---|---|---|
| Propuesta auditada | `research/dag-poas-capa-finalidad.md` (343 líneas) | R-FIN-15..22, §4, §5, §6, §7 |
| Ronda 12 | `research/scripts/d12-quorum/informe.md` (892 líneas) | E (cara a cara), F (certificado), G (frontera/cliente), H (decisión) |
| Diseño vivo | `research/dag-poas-ancla-de-orden.md` §2 (R-FIN-1..14) | `F = 2 h`, `S_max`, `m ≤ 1 + λ·S_max`, R-FIN-7 |
| Catálogo | `research/dag-poas-catalogo-problemas-ataques.md` | B1 (`Δ`), D1, D6 (suelo), E1 |
| FIP-0086 (F3) | `/home/katana/.claude/jobs/6438c0a0/tmp/fip-0086.md` (1 147 líneas, `status: Final`, `:6`) | Toda la mecánica de F3/GossiPBFT |
| Código Autonomys | `/home/katana/zeo/fuentes/subspace` @ `f8842d0` | `blst`/KZG ya en consenso |
| Scripts | `research/scripts/finalidad-espacio/*.py` | Re-ejecutados; salidas verificadas |

**Nota de fuente (LAGUNA acotada).** El arXiv `2301.07668` que cita el encargo **no es GossiPBFT**: es un paper de
visión por computador (*Behind the Scenes*, `cs.CV`). La búsqueda en arXiv por «GossiPBFT» devuelve **0 resultados**.
La fuente primaria del protocolo es el FIP-0086, que está en estado *Final* y trae el pseudocódigo completo; el
material suplementario de corrección vive en `filecoin-project/go-f3`. **LAGUNA:** latencia empírica medida en
mainnet de Filecoin, que no se ha podido traer (el panel `f3.filecoin.io` no responde).

---

## 1 · Cómo funciona F3, con la letra delante

Todo lo que sigue se apoya en estas piezas, no en la memoria. Cita = `fip-0086.md:línea`.

| Pieza | Valor en F3 | Cita |
|---|---|---|
| Época (slot de EC) | **30 s** | `:39` |
| Instancias | **una por época** | `:704` |
| Tabla de poder de la instancia `i` | del tipset finalizado por `i − 10`; `PowerTableLookback = 10` | `:96`, `:111`, `:200-201` |
| Arranque de la instancia | espera a `EC.CurrentEpoch() >= finalizedTipsets[i-1].Head().epoch + 2` | `:183` |
| Valor que se decide | **una cadena** (prefijo), no un bloque suelto | `:151`, `:316-317`, `:617` |
| Pasos | **3 pasos de comunicación** en el caso bueno; «within tens of seconds» | `:255` |
| `Δ` | inicial **6 s**; timeout de fase `2Δ`; por ronda `2Δ·BackOffExponent^ronda` | `:711-713`, `:442`, `:509` |
| Quórum | **≥ ⅔ del QAP total** de la tabla | `:57`, `:389` |
| Seguridad | adversario **< ⅓ QAP** | `:65`, `:248` |
| Si F3 se para | EC sigue a 900 épocas; disponibilidad sobre consistencia | `:58` |
| Comité | **todos** los participantes elegibles, sin sorteo | `:1125` |
| Finalidad | «sub-epoch … only limited by the network speed» | `:938` |

**La diferencia estructural con ZEROX, y es la que decide este informe:** F3 no sortea comité; el comité es la tabla
de poder entera (`:1125`), y por eso `α < ⅓` se aplica directamente. R-FIN-16 **sí sortea** (`K = 4 000` plazas,
`capa-finalidad.md:71-75`), y eso introduce una probabilidad por instancia de que el atacante **supere el umbral
⅓ dentro del comité muestreado** — un suceso que F3 no tiene y que la propuesta no evaluó (§4.A solo evalúa ⅓ y ⅔
sobre `α` fijo, sin la varianza del sorteo en la condición de seguridad; ver §3.4).

---

## 2 · P1 · Tiempo real de irreversibilidad en caso normal

### 2.1 · La cadena de retardo real de F3

Con la tabla del §1, la latencia de un tipset de época `E` en F3 es:

```
t_final(E) = (tiempo hasta que arranca la instancia que lo propone) + T_cons
           ≈ 1 época (30 s) + T_cons,   con T_cons = 3-4 rondas de mensajes
```

El `+2` del pseudocódigo es **relativo al último finalizado**, y el head avanza una época por instancia: el tipset
finalizado tiene ~1 época de edad cuando la instancia arranca (`:183`, `:704`). El FIP publica la latencia como
«tens of seconds» (`:16`, `:255`, `:1135`) y «sub-epoch» (`:938`). **VERIFICADO en la fuente primaria.**

**`LOOKBACK = 10` no suma latencia.** Retrasa la **tabla de poder** (10 instancias = 5 min a épocas de 30 s), no el
tipset finalizado (`:96`, `:200-201`). R-FIN-15 copia esa semántica (`capa-finalidad.md:60-65`): `A_n` es el bloque
finalizado por la instancia `n − 10`, y la tabla se deriva de `past(A_n)`. Conclusión: **la latencia del certificado
no es `10 × cadencia`**. Lo que sí hace el lookback es **envejecer la tabla** (ver §2.4).

### 2.2 · El «~30 s» de la propuesta no está derivado: es una suposición

Búsqueda en la propuesta y en los scripts: **ninguna regla de R-FIN-15..22 fija la cadencia de instancias.** El 30 s
aparece solo en:

| Sitio | Texto | Naturaleza |
|---|---|---|
| `capa-finalidad.md:164` | «con un certificado cada 30 s» | supuesto del cálculo de bytes |
| `verif_certificado.py:26,30-31` | `cada 30s` / `cada 10s` | **hard-code** |
| `verif_cliente_ligero.py:25` | `(30, "cada 30 s")` | **hard-code** |
| `verif_rendimiento.py:38` | `{'finalidad': '2 h' → '~30 s', 'quien': 'capa'}` | impresión, sin derivación |

**DEMOSTRADO:** el «~30 s» es la **cadencia de certificados asumida**, no una latencia derivada. Y la cadencia 30 s
viene de la **época de Filecoin** (`:39`), no de ZEROX, donde `λ = 1 bloque/s` (`ancla-de-orden.md:156, :298`).
La propuesta importa el número de F3 sin importar la restricción que lo justificaba.

### 2.3 · El mínimo alcanzable y qué parámetro lo fija

La latencia del caso bueno **no es `6Δ`**: los timeouts (`2Δ`) son cotas superiores, y el FIP permite cerrar cada
fase en cuanto llega el quórum, sin esperar el timeout (`:715`). El caso bueno es **3-4 rondas secuenciales de
mensajes** (`:255`), cada una con el tiempo real de entrega. Por tanto:

| Escenario | Espera de instancia | `T_cons` | Latencia de irreversibilidad |
|---|---:|---:|---:|
| F3 real (época 30 s, `+2`), `Δ = 6 s` | 30-60 s | 18-24 s | **48-84 s** (publicado: «tens of seconds») |
| P-040 con cadencia 30 s, instancias encadenadas | 0-30 s (media 15) | 10-30 s | **25-60 s** |
| P-040 con cadencia 5 s, red `Δ ≈ 2 s` | 0-5 s | 5-15 s | **5-20 s** |
| **Mínimo con `Δ ≈ 1 s`** | 0-1 s | **3-6 s** | **3-7 s** |

**El parámetro que fija el mínimo es el número de rondas BFT (3-4) y el tiempo real de entrega; `Δ` fija los
timeouts, no el caso bueno.** La cadencia de 30 s es una **decisión de ancho de banda y estabilidad de la tabla**,
no un suelo de seguridad. Si la prioridad es irreversibilidad, la cadencia debe bajarse hasta donde lo permita el
gossip. Coste del certificado a `K = 4 000`, 724 B (`capa-finalidad.md:171`, VERIFICADO en `verif_certificado.py`):

| Cadencia | Certificados/año | GB/año | Comparación |
|---:|---:|---:|---|
| 30 s | 1 051 200 | **0,76** | vigésima parte de las cabeceras (21,5 GB) |
| 10 s | 3 153 600 | 2,28 | — |
| **5 s** | 6 307 200 | **4,57** | **candidata: 5× menos que las cabeceras** |
| 2 s | 15 768 000 | 11,41 | la mitad de las cabeceras |
| 1 s | 31 536 000 | 22,83 | **más que las cabeceras** |

**El suelo del protocolo es 3-7 s, pero el mínimo *realista* lo fija el gossip del consenso, no el certificado.**
A `K = 4 000` el protocolo intercambia ~4 mensajes por miembro y por instancia; la estimación de §6.4 da
**~3,5 TB/año por nodo a cadencia 30 s** y **~21 TB/año a 5 s**, inasumible para un nodo doméstico. Hasta que eso se
mida y se optimice (mensajes parciales, agregación, muestreo), la cadencia publicable es **10-30 s**; el certificado
de 724 B (0,76-2,28 GB/año) no es el cuello de botella. La afirmación correcta es: **el «~30 s» no es un suelo de
seguridad ni del protocolo; es una elección de cadencia —hoy forzada por el gossip no medido— y el protocolo podría
bajar a 3-7 s si el gossip bajara con él.**

### 2.4 · El lookback envejece la tabla y la prueba de vida

R-FIN-15 deriva la tabla de `past(A_n)` con `A_n` finalizado por la instancia `n − 10`, y R-FIN-16 exige «al menos
un bloque cobrado en los últimos `W_VIVO = 1 800 s`» **antes de `A_n`** (`capa-finalidad.md:60-75`). A cadencia `c`,
el bloque más reciente elegible tiene `10·c` segundos de antigüedad. A `c = 30 s`: **300 s**. La ventana de poder
`W_POWER = 3 600 s` cubre entonces `[ahora − 3 900, ahora − 300]`. **DEMOSTRADO sobre el texto:** la «prueba de vida»
es menos reciente de lo que §4.C asume, y el lookback de 10 instancias importa para la viveza aunque no para la
latencia. Con cadencia corta (2-5 s) el efecto es despreciable (20-50 s).

### 2.5 · Qué compra la capa frente al DAG crudo

Instrumento del diseño (`prev()` de `d9-ronda9a/r9a_a3_frontera.py:37-49`, OFFSET `3k = 90`, `hf = 1,0`), riesgo de
reversión **sin** capa de finalidad:

| Espera | `α = 0,10` | `α = 0,25` | `α = 0,33` | `α = 0,40` |
|---:|---:|---:|---:|---:|
| 30 s | 1,000 | 1,000 | **1,000** | 1,000 |
| 134 s | 6,3e-02 | 9,8e-01 | **0,9999** | 1,000 |
| 300 s | 6,4e-21 | 2,2e-04 | 2,5e-01 | 9,6e-01 |
| 600 s | 1,3e-68 | 7,4e-19 | **1,5e-06** | 1,2e-01 |
| 1 800 s | 3,8e-316 | 9,5e-87 | **7,1e-36** | 1,1e-10 |

A `α = 0,33`, d12 §D.6 necesita **871 s** para 1e-12 sin capa. **La capa sí compra algo real:** sustituye ese suelo
probabilístico por una finalidad por regla a la latencia del certificado, **condicionada a que se cumpla la
seguridad BFT** (§3.4). Este es el argumento más fuerte a favor de P-040 y hay que decirlo.

### 2.6 · Veredicto P1

| Afirmación | Etiqueta | Número |
|---|---|---|
| F3 finaliza en «tens of seconds» con épocas de 30 s y `Δ = 6 s` | **VERIFICADO** | `fip-0086.md:16, :255` |
| El «~30 s» de P-040 es un supuesto de cadencia, no una derivación | **DEMOSTRADO** | `verif_certificado.py:26` |
| `LOOKBACK = 10` no suma latencia al certificado; envejece la tabla | **DEMOSTRADO** | 300-3 900 s a `c = 30 s` |
| Mínimo alcanzable = 3-4 rondas BFT + espera de instancia | **DEMOSTRADO** | 3-7 s con `Δ ≈ 1 s` |
| La capa mejora el riesgo del DAG crudo en el caso normal | **DEMOSTRADO** | 1,000 → 0 a 30 s; sin capa 871 s a 1e-12 |

---

## 3 · P2 · Bajo ataque `α = 0,33`

### 3.1 · Tres sucesos distintos que la propuesta mezcla

En un comité sorteado de `K = 4 000` plazas, con `A ~ Binom(K, α)` plazas del atacante:

| Suceso | Condición | Qué rompe |
|---|---|---|
| **E1 · el atacante bloquea** | `A ≥ ⅓K` (retiene su firma) | **viveza**: no hay ⅔ |
| **E2 · el atacante forja solo** | `A ≥ ⅔K` | **seguridad**: certificado falso sin honestos |
| **E3 · los honestos no llegan** | `H ~ Binom(K−A, p)` y `H < ⅔K` | **viveza** por participación `p` |

La propuesta llama «se para la finalidad» a E1 (`capa-finalidad.md:145`) y «finaliza una mentira» a E2 (`:145`).
**Falta E1 como condición de seguridad:** el umbral de seguridad de GossiPBFT es **< ⅓** (`fip-0086.md:65, :248`),
no < ⅔. Eso se trata en §3.4.

### 3.2 · El 41 % no es el número del diseño

`verif_sorteo.py` y `verif_sesgo_sorteo.py`, re-ejecutados hoy, con `α = 0,33`:

| `K` | `m` (anclas) | P(E1) = P(A ≥ ⅓K) | P(E2) = P(A ≥ ⅔K) |
|---:|---:|---:|---:|
| 1 000 | 1 | **4,06e-01** ← el «41 %» | 6,54e-105 |
| 4 000 | 1 | **3,24e-01** | 0 (subdesborda) |
| 4 000 | 2,955 (**medido**, D8 A4.2) | **6,92e-01** | 0 |
| 4 000 | 151 (**cota garantizada**, R-FIN-1a) | **1,00** | 0 |

**REFUTADO el «41 %» como número del diseño.** El 41 % es `K = 1 000`, `m = 1`, que es la configuración que §4.D
**abandona** al subir a `K = 4 000` (`capa-finalidad.md:229`). Con el `K` final y la cota de *steering* que el propio
§4.D usa, la capa se para en el **69 %** de las instancias (con el `m` medido) y en el **100 %** (con la cota). Es
decir: **el `K = 4 000` compró seguridad frente a `m` y no compró viveza**; el diseño es peor que el 41 % que
declara, no mejor.

Anualizado a cadencia 30 s (**1 051 200 instancias/año**):

| `α` | P(E1)/instancia (`m = 1`) | Paradas/año | Con `m = 151` |
|---:|---:|---:|---:|
| 0,25 | 2,0e-32 | ~0 | 3,0e-30 |
| 0,28 | 7,4e-14 | ~0 | 1,1e-11 |
| 0,30 | 2,5e-06 | 2,7 | **3,8e-04 → 400/año** |
| 0,32 | 3,5e-02 | 37 038 | ~1 |
| **0,33** | **3,24e-01** | **340 999** | **1,00** |

### 3.3 · Fallback y tiempo de recuperación

- **Fallback:** **R-FIN-7 sin cambios**, `F = 2 h` (`ancla-de-orden.md:156, :271-273`). La cadena sigue creciendo:
  R-FIN-7 **ignora la punta, no apaga el proceso** (`:271-273`), y es la propiedad que el propio FIP declara
  («EC continues operating normally if F3 halts», `fip-0086.md:58`). **DEMOSTRADO por la regla.**
- **Recuperación:** las instancias son independientes (entropía nueva, comité nuevo), luego el número de instancias
  hasta la primera que cierra es geométrico. Si el atacante solo bloquea cuando `A ≥ ⅓K`:
  - `m = 1`, `α = 0,33`: `E[instancias] = 1/(1−0,324) = 1,48` → **~44 s** a 30 s.
  - `m = 2,955`: `1/(1−0,692) = 3,25` → **~97 s**.
  - `m = 151`: nunca (E1 = 1,00).
  **Matiz honesto:** el atacante no es pasivo; puede elegir *cuándo* bloquear y *qué* bloque atacar. La garantía
  publicable no es 44-97 s: es **2 h hasta que el ataque cese**. Con `α = 0,33` sostenido y la cota de `m`, **la
  capa no vuelve**.

### 3.4 · ¿Se mantiene la seguridad (nunca dos finalidades)?

La respuesta tiene dos capas y la propuesta solo vio una.

1. **`p` no rompe la seguridad. DEMOSTRADO.** El quórum exige ≥ ⅔ del poder **total** de la tabla
   (`fip-0086.md:57, :389`), no de los presentes. Un honesto apagado deja su plaza en la tabla pero no firma; el
   atacante no hereda esas plazas. Por eso `p` bajo solo rompe la viveza (§4). La propuesta acierta al rechazar el
   quórum sobre presentes (`capa-finalidad.md:201-203`).
2. **`α ≥ ⅓` dentro del comité sí invalida la garantía, y a `α = 0,33` ocurre en el 32-100 % de las instancias.**
   El argumento de seguridad de GossiPBFT es el clásico de PBFT: dos quórums de ⅔ **intersecan en ≥ ⅓**, y si el
   adversario tiene **< ⅓**, la intersección contiene un honesto que tendría que haber firmado dos veces — imposible.
   Con `A ≥ ⅓K`, la intersección puede ser toda del atacante y **la demostración no aplica** (`fip-0086.md:65, :248`).
   La propuesta calcula `P(A ≥ ⅔K)` («forja solo») y concluye «la seguridad no se toca» (`capa-finalidad.md:221-224`),
   pero **el umbral correcto es ⅓, no ⅔**. La probabilidad de que la condición de seguridad falle, `P(A ≥ ⅓K)`, es
   **0,324** a `α = 0,33`, `K = 4 000`, `m = 1`, y **1,00** con la cota de `m = 151`.

**Riesgo anual de que la condición `A < ⅓K` falle** (1 051 200 instancias/año; `m = 1`; con `m = 3` casi idéntico
porque la cola es vertical):

| Objetivo anual | `α` máximo admisible |
|---|---:|
| < 1e-12 | **27,0 %** |
| < 1e-6 | **28,2 %** |
| < 1e-2 | **29,2 %** |

**Conclusión:** la capa **no** es una garantía de seguridad al 33 % publicado; lo es hasta `α ≈ 28 %` para un riesgo
anual de 1e-6. **REFUTADO** el «la seguridad no se toca» tal como está escrito. Que la violación de la condición
produzca *de hecho* dos certificados en conflicto exige un ataque de equivocación con cambios de vista que **no se
construye aquí: LAGUNA** (haría falta portar y analizar GossiPBFT entero, como el propio §7 pide).

### 3.5 · Veredicto P2

| Afirmación | Etiqueta | Número |
|---|---|---|
| El 41 % es `K = 1 000`, `m = 1`; el diseño `K = 4 000` se para el 32,4 % (`m = 1`), 69 % (`m = 2,955`), 100 % (`m = 151`) | **REFUTADO el 41 % como diseño / VERIFICADO el resto** | 340 999 paradas/año a `α = 0,33` |
| Fallback `F = 2 h`; la cadena sigue | **DEMOSTRADO** | R-FIN-7; `fip-0086.md:58` |
| Recuperación = 1 instancia si el ataque cesa; nunca si persiste | **DEMOSTRADO** (independencia) | 44-97 s / nunca |
| `p` no rompe seguridad; `α ≥ ⅓` en el comité sí invalida la garantía | **DEMOSTRADO** | 0,324 a `α = 0,33`, `m = 1` |
| Garantía anual de seguridad | **VERIFICADO** | `α ≤ 28,2 %` para 1e-6/año |
| Ataque concreto de doble finalidad con `A ≥ ⅓K` | **LAGUNA** | requiere portar GossiPBFT |

---

## 4 · P3 · La `p` del granjero doméstico: qué rompe y qué no

### 4.1 · Seguridad: `p` no la toca

Ya demostrado en §3.4.1: el quórum es sobre el **total** de la tabla; los honestos apagados no suman al atacante.
**Seguridad independiente de `p`.** (Condición: que la tabla no esté manipulada; el ataque D8 a la tabla sigue
abierto, `capa-finalidad.md:323-325`.)

### 4.2 · Viveza: umbral media-campo

`verif_quorum.py:14-17` (VERIFICADO): quórum ⟺ `(1 − α)·p ≥ ⅔`.

| `α` | `p` mínima |
|---:|---:|
| 0,00 | **66,7 %** |
| 0,10 | 74,1 % |
| 0,20 | 83,3 % |
| 0,25 | **88,9 %** |
| 0,28 | 92,6 % |
| 0,30 | **95,2 %** |
| 0,33 | **99,5 %** |

**Con la prioridad puesta en irreversibilidad:** si `p` cae por debajo de esa línea, la capa se para y la
irreversibilidad vuelve a `F = 2 h`. El valor de la capa **para irreversibilidad** es, por tanto, condicional a
`p ≥ 88,9 %` si el atacante tiene el 25 %, y a `p ≥ 95,2 %` si tiene el 30 %. `p` es **la primera medida de campo**
que hay que hacer, como la propuesta misma declara (`capa-finalidad.md:304-306`).

### 4.3 · Tabla exacta con sortición (el umbral media-campo no basta)

`verif_quorum.py` tabla B usa `n_h = int(K(1−α))` fijo y **no integra la varianza del sorteo**. La probabilidad
exacta por instancia, `A ~ Binom(K, α)`, `H ~ Binom(K−A, p)`, `P(no quórum) = Σ_A P(A)·P(H < ⅔K)`, con `K = 4 000`
(cálculo propio, §10):

| `α` \ `p` | 0,90 | 0,95 | 0,98 | 0,99 | 0,995 | 1,00 |
|---:|---:|---:|---:|---:|---:|---:|
| 0,00 | 0 | 0 | 0 | 0 | 0 | 0 |
| 0,10 | 1,7e-102 | 1,4e-196 | 5,1e-280 | 3,1e-314 | 0 | 0 |
| 0,20 | 7,4e-14 | 8,9e-41 | 6,6e-66 | 4,8e-76 | 1,8e-81 | 3,8e-87 |
| 0,25 | **1,3e-01** | 1,3e-10 | 5,6e-22 | 6,7e-27 | 1,4e-29 | 2,0e-32 |
| 0,30 | **1,00** | **5,9e-01** | 4,3e-03 | 1,6e-04 | 2,3e-05 | 2,5e-06 |
| 0,33 | **1,00** | **1,00** | **9,1e-01** | **6,7e-01** | **5,0e-01** | **3,2e-01** |

**Hallazgo:** a `α = 0,25`, `p = 0,90` la media-campo pasa (0,75 × 0,90 = 0,675 ≥ 0,667) pero la instancia falla el
**12,9 %** de las veces por la varianza del sorteo. El umbral media-campo es una condición necesaria, no suficiente;
la tabla exacta es la que decide.

### 4.4 · La tabla mide espacio-tiempo: el umbral real en espacio es menor que 33 %

R-FIN-15 cuenta **bloques que cobran** en `[slot(A_n) − 3 600, slot(A_n))` (`capa-finalidad.md:60-65`). El peso de
una clave es proporcional a su **espacio × tiempo encendido**, no a su espacio. Si el atacante está siempre
encendido (`u_a = 1`) y los honestos no (`u_h < 1`), el umbral de viveza pasa a ser en **espacio**:

```
α_max = u_h / (2·u_a + u_h)          [derivado de R-FIN-15 + quórum ⅔ de R-FIN-17]
```

| `u_h` (honesto) | `α_max` en **espacio** |
|---:|---:|
| 1,00 | 33,3 % |
| 0,95 | 32,2 % |
| 0,90 | 31,0 % |
| **0,80** | **28,6 %** |
| 0,70 | 25,9 % |

**DEMOSTRADO sobre el texto de R-FIN-15 y R-FIN-17.** Es un número que la propuesta no tiene: **el umbral operativo
de 33 % no se traslada a la capa**; con granjeros domésticos al 80 % de encendido y un atacante siempre encendido,
la capa se para con solo el **28,6 % del espacio**. Refuerza la conclusión de §3.2-3.4.

### 4.5 · Plazas correlacionadas por clave: `K_eff ≈ 40`, no 4 000

§7 de la propuesta declara el error: «las plazas de una misma clave caen juntas … subestima la varianza del quórum»
(`capa-finalidad.md:307-311`). Cuantificación con el modelo Zipf(1) que el propio `verif_certificado.py:60-70` usa:
`Σ w_k² = H_G^(2)/H_G²`, y la varianza de la participación efectiva es `Σ w_k²·p(1−p)`, equivalente a un comité
independiente de tamaño `K_eff = 1/Σ w_k²`:

| Granjeros `G` en la ventana | `Σ w²` | `K_eff` |
|---:|---:|---:|
| 600 | 0,0338 | 29,6 |
| 1 200 | 0,0280 | 35,8 |
| **1 800** (`W_VIVO` a 1 bloque/s) | **0,0252** | **39,6** |
| 3 600 | 0,0214 | 46,7 |

**PLAUSIBLE (modelo Zipf):** para la **varianza de encendido**, el comité se comporta como uno de ~40 plazas, no
4 000. La tabla exacta de §4.3 (que sí modela plazas independientes) **optimiza la viveza**; con `K_eff ≈ 40` la
cola de fallo es mucho más ancha. No cambia la seguridad (la del atacante se muestrea con reemplazo, §3.1), pero sí
la viveza. La propuesta ya pide rehacerlo con la distribución real (`:310-311`); esto le pone número al hueco.

### 4.6 · Veredicto P3

| Afirmación | Etiqueta | Número |
|---|---|---|
| Seguridad independiente de `p` | **DEMOSTRADO** | ⅔ del total de la tabla |
| Viveza: `p ≥ (2/3)/(1−α)` | **VERIFICADO** | 88,9 % a `α = 0,25`; 95,2 % a `α = 0,30` |
| Con sortición, la media-campo no basta | **VERIFICADO** | 12,9 % de fallo a `α = 0,25`, `p = 0,90` |
| La tabla mide espacio-tiempo; umbral en espacio | **DEMOSTRADO** | 28,6 % con `u_h = 0,80` |
| `K_eff ≈ 40` por correlación de claves | **PLAUSIBLE** (Zipf) | `W_VIVO = 1 800 s` |

---

## 5 · P4 · Sensibilidad a `Δ` (sin medir)

### 5.1 · Qué temporizadores dependen de `Δ`

| Temporizador | Fórmula | Cita |
|---|---|---|
| Timeout de fase | `2Δ` | `fip-0086.md:442` |
| `Δ` inicial de instancia | **6 s** | `:713` |
| Timeout por ronda | `2Δ·BackOffExponent^ronda` | `:509` |
| Multiplicador de QUALITY | `timeout · quality_timeout_multiplier` | `:456`, `:717` |
| Arranque de instancia | `+2` épocas (no `Δ`) | `:183` |
| **Arranque de instancia en ZEROX** | **no definido en R-FIN-15..22** | `capa-finalidad.md:60-133` |

### 5.2 · Latencia frente a `Δ`

Modelo: caso bueno = 3-4 rondas de entrega (~`Δ` cada una si la red tarda el orden de `Δ`); columna «+1 ronda
fallida» = `10Δ` = timeout de ronda 0 (`2Δ`) + timeout de ronda 1 con backoff ×2 (`4Δ`) + 3-4 rondas de la ronda 1
(~`4Δ`). Es una estimación de orden de magnitud, no una cota: el `BackOffExponent` y el multiplicador de QUALITY son
elecciones de implementación (`fip-0086.md:456, :509, :580, :717`).

| `Δ` | 3 rondas | 4 rondas | +1 ronda fallida (10Δ) | Lectura |
|---:|---:|---:|---:|---|
| 1 s | 3 s | 4 s | ~10 s | mínimo real |
| 2 s | 6 s | 8 s | ~20 s | objetivo sano |
| **4 s** | **12 s** | **16 s** | **~40 s** | condición de d12 §E.2 |
| 6 s (F3) | 18 s | 24 s | ~60 s | el de Filecoin |
| 10 s | 30 s | 40 s | ~100 s | — |
| **16 s** | **48 s** | **64 s** | **~160 s** | frontera DAG 38,3 % |
| **20 s** | **60 s** | **80 s** | **~200 s** | frontera DAG 32,4 % |

**DEMOSTRADO** (aritmética sobre los timeouts del FIP). `Δ` **no** fija el caso bueno; fija los timeouts y, con
ellos, el coste de una ronda perdida.

### 5.3 · Si `Δ` sale 16-20 s: la capa y la cadena a la vez

- La capa: **48-80 s** en el caso bueno, **160-200 s** con una ronda perdida. Los ~30 s quedan muertos.
- La cadena de debajo: la frontera de flujo único cae a **38,3 % a 16 s** y **32,4 % a 20 s**
  (`dag-poas-catalogo-problemas-ataques.md:36`, 9a §5.5), frente al **33 % operativo publicado**
  (`ancla-de-orden.md:156`). A 20 s el DAG está **por debajo del umbral**: la capa no es el problema principal.
- `Δ` es **E1 del catálogo** («la que manda sobre todas», `dag-poas-catalogo-problemas-ataques.md:72`) y sigue
  **sin medir**. La propuesta lo declara en §7 (`capa-finalidad.md:318-319`).
- Condición de d12 §E.2 para abrir P-040: **`Δ_p99 < 4 s`** (`d12-quorum/informe.md:513-515`).

### 5.4 · Veredicto P4

| Afirmación | Etiqueta | Número |
|---|---|---|
| Timeouts `2Δ`, `Δ₀ = 6 s`, backoff exponencial | **VERIFICADO** | `fip-0086.md:442, :509, :713` |
| `Δ = 16-20 s` ⇒ capa 48-80 s (hasta 160-200 s) | **DEMOSTRADO** (aritmética) | — |
| `Δ = 16-20 s` ⇒ frontera del DAG 38,3/32,4 % | **VERIFICADO** | catálogo B1 |
| `Δ` real de ZEROX | **LAGUNA** | hace falta `zx-node` en red |

---

## 6 · P5 · Sesgo del sorteo y criptografía

### 6.1 · Sesgo por elección de ancla (`m`)

Reproducido `verif_sesgo_sorteo.py` (VERIFICADO). La cota es `m ≤ 1 + λ·S_max = 151` con `S_max = 150 s`
(`ancla-de-orden.md:167-170, :188`); la medida de D8 es `m = 2,955` (`capa-finalidad.md:210`).

| `K` | `α` | `m` | P(parada) | P(mentira) |
|---:|---:|---:|---:|---:|
| 1 000 | 0,33 | 151 | 1,00 | 9,87e-103 |
| 4 000 | 0,30 | 1 / 3 / 151 | 2,5e-06 / 7,6e-06 / **3,8e-04** | 0 |
| 4 000 | 0,33 | 1 / 3 / 151 | 0,324 / 0,692 / **1,00** | 0 |

Lectura correcta de §4.D: **`K = 4 000` compra la seguridad frente al *steering* (P(mentira) = 0 con `m = 151`) y
no compra la viveza** (P(parada) = 1,00 con `m = 151`). La tabla del script usa `ceil(m)` (`verif_sesgo_sorteo.py:31`),
conservador; y el `best-of-m` supone que el atacante evalúa las `m` anclas, algo que R-FIN-14(e) limita — la cota
`m = 151` es de R-FIN-1a, no una evaluación gratis. **PLAUSIBLE** el mecanismo; **VERIFICADO** el cálculo.

### 6.2 · ¿Exige BLS12-381? Sí

`fip-0086.md:918-920`: **BLS12-381**, firmas en **G2**, claves en **G1**, agregación **BDN** con BLAKE2X XOF
(`:920-931`). La alternativa Ed25519 de R-FIN-20 (`capa-finalidad.md:113-115`) es inviable por bytes:
`verif_certificado.py` re-ejecutado:

| Esquema | `K` | Certificado | GB/año a 30 s |
|---|---:|---:|---:|
| Ed25519 (1 firma/plaza) | 1 000 | 66 128 B | **69,51** |
| BLS agregada + bitmap | 1 000 | 349 B | 0,37 |
| Ed25519 (1 firma/plaza) | **4 000** | **264 128 B** | **277,65** |
| BLS agregada + bitmap | **4 000** | **724 B** | **0,76** |

**Error de transcripción encontrado en `capa-finalidad.md:170`:** la fila «Ed25519, `K = 4 000` → 237 728 B,
249,90 GB» es en realidad la salida de `K = 3 600` de `verif_certificado.py:27`; el valor correcto para `K = 4 000`
es **264 128 B / 277,65 GB/año**. No cambia la conclusión (Ed25519 es inviable en ambos casos), pero la tabla hay
que corregirla.

### 6.3 · `blst` vs Rust puro: el coste ya está pagado, pero falta la mitad

- **`blst` ya está en la ruta de consenso de todos los nodos** si ZEROX hereda el PoAS/KZG de Autonomys:
  `rust-kzg-blst` en `Cargo.toml:180`, `shared/subspace-kzg/Cargo.toml:24`, y `kzg.verify(...)` dentro de
  `verify_solution` en `crates/subspace-verification/src/lib.rs:263`. **VERIFICADO en el código.** La «bifurcación»
  de §5 de la propuesta (`capa-finalidad.md:260-286`) **ya está resuelta**: es dependencia del consenso, no de la
  capa.
- **Lo que falta no es la curva, es el esquema.** F3 no usa BLS «a secas»: exige agregación **resistente a
  rogue-key** (BDN, `fip-0086.md:361, :920-931`), cuyos coeficientes dependen de **todas** las claves del comité.
  R-FIN-17/R-FIN-20 no lo mencionan; sin BDN o prueba de posesión, un atacante puede registrar una clave calculada
  para forjar una firma agregada. Y R-FIN-20 («clave BLS que esa clave Ed25519 declare en la coinbase»,
  `capa-finalidad.md:113-115`) es, de hecho, **un registro de claves** — la propiedad «sin registro» que §2 reivindica
  se pierde en la clave de firma. **DEMOSTRADO sobre el FIP + el texto de la propuesta.**

### 6.4 · Coste de verificación por nodo

- **Medido:** `kzg.verify = 1,0773 ms` [1,0719; 1,0887], Criterion, `subspace-kzg` (d12 §F.6,
  `d12-quorum/informe.md:599-604`). **Ese número es KZG, no BLS.**
- **No medido:** la verificación de una firma BLS agregada con BDN. La propuesta usa **2 ms como supuesto**
  (`verif_certificado.py:51`, comentario «orden de magnitud»), no como medida. El propio FIP advierte que verificar
  evidencias exige **agregar O(K) claves públicas** y recalcular los coeficientes BDN (`fip-0086.md:700, :924-929`):
  el coste dominante es `O(K)`, no los 2 emparejamientos. Para `K = 4 000` eso puede ser decenas de ms por
  certificado — irrelevante a 30 s de cadencia (0,007 % de núcleo), **relevante si se baja la cadencia a 1-2 s**.
  **LAGUNA:** medir `blst` con BDN y `K = 4 000`.
- **Coste que la propuesta no cuenta:** el gossip del consenso. `K` miembros × 3-4 mensajes × ~200 B por instancia.
  A `K = 4 000` y 30 s: **~0,11 MB/s ≈ 3,5 TB/año por nodo** (orden de magnitud, PLAUSIBLE). `capa-finalidad.md:162-175`
  solo cuenta el certificado de 724 B (0,76 GB/año); el protocolo que lo produce cuesta tres órdenes más. A cadencia
  5 s serían ~21 TB/año — inasumible. **El coste de bajar la cadencia no es el certificado, es el gossip.** Este es
  el freno real al «mínimo alcanzable» de §2.3, y hay que medirlo antes de prometer 5-10 s.

### 6.5 · Veredicto P5

| Afirmación | Etiqueta | Número |
|---|---|---|
| `K = 4 000` compra seguridad frente a `m = 151`; no viveza | **VERIFICADO** | P(mentira) = 0; P(parada) = 1,00 |
| BLS12-381 obligatoria; Ed25519 inviable | **VERIFICADO** | 277,65 GB/año vs 0,76 |
| `blst` ya en consenso vía KZG | **VERIFICADO** | `Cargo.toml:180`, `lib.rs:263` |
| Falta BDN/PoP (rogue-key) y R-FIN-20 es un registro | **DEMOSTRADO** | `fip-0086.md:361, :920-931` |
| Coste BLS agregada real | **LAGUNA** | `kzg.verify` = 1,0773 ms es KZG |
| Gossip del consenso a `K = 4 000`/30 s | **PLAUSIBLE** | ~3,5 TB/año/nodo |

---

## 7 · P6 · Verificación de la afirmación del catálogo #58

La afirmación («no funciona en el umbral del 33 %: es mejora del caso normal, no garantía») está en
`capa-finalidad.md:157-160` y en el vault `NODOS/ZEROX/PROBLEMAS.md:76` (entrada 58, truncada allí). Nota: el
`dag-poas-catalogo-problemas-ataques.md` del repo **no tiene** una entrada #58; la fuente de la cita es la propuesta
y el vault.

**Veredicto: VERIFICADA, y reforzada por tres correcciones.**

1. **El número del 41 % es de otra configuración** (`K = 1 000`, `m = 1`). El diseño final `K = 4 000` se para el
   32,4 % con `m = 1`, el 69,2 % con el `m` medido y el 100 % con la cota. La capa **no funciona al 33 %**, y
   funciona *menos* de lo que el 41 % sugiere.
2. **La seguridad tampoco está garantizada al 33 %.** La propuesta solo calculó `P(A ≥ ⅔K)`; el umbral BFT es `⅓`.
   `P(A ≥ ⅓K)` a `α = 0,33` es 0,324 (`m = 1`) y 1,00 (`m = 151`). Para que la garantía aguante un año con riesgo
   < 1e-6, `α` debe quedarse en **≤ 28,2 %**.
3. **La viveza exige además `p ≥ (2/3)/(1−α)`**: 88,9 % a `α = 0,25`, 95,2 % a `α = 0,30`, y el umbral en espacio
   baja a 28,6 % si el atacante está siempre encendido y los honestos al 80 %.

**Etiqueta: VERIFICADO** (con el número corregido). La frase «mejora del caso normal, no garantía del umbral» es
exactamente correcta.

---

## 8 · Errores propios

1. **Apliqué primero la «dominación estricta» de d12 §D.6 a esta capa.** Está mal: D.6 es del gadget de quórum de
   HotPoW, donde los honestos firman «lo que creen» sin BFT. La capa F3 decide un **prefijo de cadena** con
   GossiPBFT (`fip-0086.md:151, :617`) y cambia la regla de selección (R-FIN-18); el certificado **no hereda** el
   suelo probabilístico `prev(α, d)`. *Qué cambió:* la crítica correcta es el umbral BFT `< ⅓` (§3.4), no la
   dominación. La capa sí compra finalidad real en el caso normal (§2.5).
2. **El «41 %» del catálogo #58 es el número de `K = 1 000`, no del diseño `K = 4 000`.** *Qué cambió:* el diseño
   se para más, no menos.
3. **El umbral de seguridad es ⅓, no ⅔.** La propuesta concluye «la seguridad no se toca» mirando `P(A ≥ ⅔K)`.
   *Qué cambió:* aparece un riesgo de seguridad a `α = 0,33` del 32-100 % por instancia, y un umbral anual de
   `α ≈ 28 %`.
4. **R-FIN-15 mide espacio-tiempo, no espacio.** El umbral de la capa en espacio es `u_h/(2u_a+u_h)`, no 33 %.
5. **La fila Ed25519 `K = 4 000` de §4.B es la de `K = 3 600`** (error de transcripción de la propuesta).
6. **R-FIN-17 certifica «un bloque», no un prefijo de cadena.** GossiPBFT decide cadenas (`fip-0086.md:151, :617`);
   sin esa precisión, el certificado puede fijar una rama perdedora. Especificación incompleta, no error de cálculo.
7. **El gossip del consenso no está contado.** El certificado de 724 B no es el coste del protocolo que lo produce.
8. **AUDITA_SCRIPTS.py** sobre `research/scripts/d13-finalidad/` (restricción de un solo fichero: no hay scripts
   nuevos): `Scripts analizados: 0 — Sospechas totales: 0`. Los cálculos propios van embebidos en §10.

---

## 9 · Veredicto

### 9.1 · Tabla punto → etiqueta → número

| Punto | Conclusión | Etiqueta | Número |
|---|---|---|---|
| P1 · normal | ~30 s es **plausible solo** con `p` alto y `Δ` bajo; es cadencia asumida, no derivada | **PLAUSIBLE** | 25-60 s a `c = 30 s` |
| P1 · mínimo | 3-4 rondas BFT + espera; `Δ` fija timeouts, no el caso bueno | **DEMOSTRADO** | **3-7 s** con `Δ ≈ 1 s` |
| P1 · LOOKBACK | no suma latencia; envejece tabla y prueba de vida | **DEMOSTRADO** | 300-3 900 s a `c = 30 s` |
| P1 · valor | sustituye el suelo probabilístico (871 s a 1e-12, `α = 0,33`) por regla | **DEMOSTRADO** | prev(30 s) = 1,000 |
| P2 · parada | 41 % es `K = 1 000`; el diseño para 32,4 / 69 / 100 % | **REFUTADO / VERIFICADO** | 340 999 paradas/año |
| P2 · fallback | R-FIN-7, `F = 2 h`; recuperación 1 instancia si cesa, nunca si persiste | **DEMOSTRADO** | 44-97 s / nunca |
| P2 · seguridad | garantía BFT exige `A < ⅓K`; falla 32-100 % a `α = 0,33` | **DEMOSTRADO** + **REFUTADO** «no se toca» | `α ≤ 28,2 %` anual 1e-6 |
| P3 · `p` | seguridad no depende de `p`; viveza `p ≥ (2/3)/(1−α)` | **DEMOSTRADO / VERIFICADO** | 88,9 % a `α = 0,25` |
| P3 · uptime | tabla espacio-tiempo: umbral en espacio 28,6 % a `u_h = 80 %` | **DEMOSTRADO** | 25,9-33,3 % |
| P3 · claves | `K_eff ≈ 40` por correlación de plazas | **PLAUSIBLE** | Zipf(1), `G = 1 800` |
| P4 · `Δ` | timeouts `2Δ`; `Δ = 16-20 s` ⇒ 48-80 s y frontera 32-38 % | **VERIFICADO / DEMOSTRADO** | `Δ` real **LAGUNA** |
| P5 · BLS | obligatoria; `blst` ya pagado; falta BDN/PoP; verify sin medir | **DEMOSTRADO / LAGUNA** | `kzg.verify` 1,0773 ms |
| P5 · bytes | Ed25519 `K = 4 000` real: 264 128 B, no 237 728 B | **REFUTADO** el dato de §4.B | 277,65 GB/año |
| P5 · gossip | ~3,5 TB/año/nodo a `K = 4 000`/30 s, no contado | **PLAUSIBLE** | frena bajar la cadencia |
| P6 · #58 | «no funciona al 33 %: mejora del caso normal, no garantía» | **VERIFICADO y reforzado** | — |

### 9.2 · Respuesta a la prioridad declarada

- **Tiempo normal:** con `p ≥ 88,9 %` (`α = 0,25`) y `Δ_p99 ≤ 4 s`, la capa da **~25-60 s** a la cadencia asumida de
  30 s. El suelo del protocolo son **3-7 s** (`Δ ≈ 1 s`, 3-4 rondas), pero el mínimo *realista* lo fija el gossip del
  consenso (~3,5 TB/año/nodo a `K = 4 000`/30 s, §6.4), que hoy empuja la cadencia publicable a 10-30 s. Hasta medir
  el gossip, no se puede prometer menos de ~10-30 s.
- **Tiempo bajo ataque `α = 0,33`:** la capa **no garantiza nada**: se para el 32,4 % (mejor caso), el 69 % (steering
  medido) o el 100 % (cota) de las instancias; la garantía de seguridad BFT también se cae; el suelo vuelve a
  **2 h** y no se recupera mientras el ataque siga.
- **Condición que cambiaría la recomendación:** medir `p` y `Δ`. Si `p < 88,9 %` (a `α = 0,25`) o `Δ_p99 > 4 s`, la
  capa **no vale como capa de irreversibilidad**; queda el uso de cliente ligero (secundario, y R-FIN-22 sin auditar).
  Si `p` supera el 95 % y `Δ_p99 ≤ 4 s`, vale como mejora del caso normal **con el suelo de 2 h declarado**, y el
  mínimo se compra bajando la cadencia — con el coste de gossip medido antes.
- **No escribir R-FIN-15..22 en el SPEC** antes de esas dos medidas y de cerrar el ataque D8 a la tabla. El «~30 s»
  no es un número demostrado: es una elección de cadencia importada de Filecoin.

---

## 10 · Reproducción

Los scripts existentes se re-ejecutaron sin modificarlos (`research/scripts/finalidad-espacio/*.py`). Los cálculos
propios de §3.2, §4.3, §4.4, §4.5, §5.2 y §6.1 se hicieron con Python 3 + SciPy 1.17.1; fragmentos exactos:

```python
# §3.2 y §6.1 — sucesos del comité, K=4000
from scipy.stats import binom
import math
K=4000
p13=lambda a: binom.sf(math.ceil(K/3)-1, K, a)
p23=lambda a: binom.sf(math.ceil(2*K/3)-1, K, a)
best=lambda p,m: 1-(1-p)**m if p>1e-12 else p*m
# a=0.33 -> p13=3.244e-01 ; m=3 -> 6.916e-01 ; m=151 -> 1.00 ; p23=0

# §4.3 — P(no quórum) exacta con sortición
need=math.ceil(2*K/3)
pnq=lambda a,p: sum(binom.pmf(A,K,a)*(1 if K-A<need else binom.cdf(need-1,K-A,p))
                    for A in range(K+1) if binom.pmf(A,K,a)>1e-300)

# §4.5 — K_eff con Zipf(1)
H=sum(1/i for i in range(1,1801)); H2=sum(1/i**2 for i in range(1,1801))
print(1/(H2/H**2))   # 39.6
```

**Salida de `python3 research/scripts/AUDITA_SCRIPTS.py research/scripts/d13-finalidad/`:**

```
Scripts analizados: 0
Sospechas totales: 0
```

*(No hay scripts nuevos: la restricción de esta entrega es un solo fichero. Los cálculos embebidos de arriba son la
reproducción.)*
