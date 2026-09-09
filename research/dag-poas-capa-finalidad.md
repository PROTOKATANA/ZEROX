# Capa de finalidad ponderada por espacio para ZEROX — propuesta

**Fecha:** 2026-09-09 · **Autor:** agente principal · **Estado: HIPÓTESIS, SIN AUDITAR.**
**Origen:** pregunta de Katana tras descartar el híbrido PoW/PoS y comprobar que el rendimiento de
Solana no viene de su Proof of Stake. Único punto en que un consenso con moneda gana al nuestro:
la **finalidad**. Esta propuesta la ataca **sin moneda y sin tocar quién produce ni quién cobra**.

**Precedente:** Filecoin F3, `FIP-0086`, estado *Final*, en mainnet desde el **29 de abril de 2025**
tras la versión de red 25. Bajó la finalidad de **7,5 h a decenas de segundos**. Citas literales del
FIP verificadas hoy (copia en `$CLAUDE_JOB_DIR/tmp/fip-0086.md`):

> «The participation of each SP is weighted according to its quality-adjusted power (QAP), which is a
> function of the storage power that the SP has committed to the network.»

> «Every certificate output by F3 is signed by ≥ ⅔ of the total QAP, i.e., a super-majority of the
> power table.»

> «EC … continues operating "normally" if F3 assumptions are violated and F3 halts, with the combined
> EC/F3 protocol favoring availability over consistency (in CAP theorem parlance).»

> «Verifying the finality of a tipset from genesis does not require access to the EC chain.»

**Ni una moneda en juego.** El voto pesa por espacio. Es la propiedad que hace que esta capa no
reabra el problema que Katana rechaza de PoS: nadie tiene que comprar nada para participar.

---

## 1 · Lo que NO cambia

| | |
|---|---|
| Quién produce bloques | El granjero, por PoAS. Sin cambios |
| Quién cobra | R-FIN-8′, sin cambios. Sin premine, sin tesorería |
| GHOSTDAG, `blue_work`, ancla por `slot` | Sin cambios (R-FIN-1, 1a, 6, 11, 12, 13, 14) |
| El umbral de consenso | 33 % operativo, frontera 46,9 %. **Esta capa no lo mueve** |
| `F = 2 h` | **Se queda como suelo de degradación.** Es la red de seguridad |

La capa es **aditiva**: si no funciona, la cadena se comporta exactamente como hoy. Es la propiedad
de F3 y es la razón por la que se puede intentar sin arriesgar lo ya ganado en nueve rondas.

## 2 · El problema que Filecoin no tiene y nosotros sí

F3 se apoya en una **tabla de poder on-chain**: el *power actor* `f04` mantiene el QAP de cada
proveedor, su clave de firma y sus faltas. El comité son los actores con ≥ 10 TiB, sin deuda y sin
falta de consenso activa.

**PoAS no registra a nadie.** El granjero es una clave pública que aparece cuando gana. La identidad
es gratis, y D9 lo demostró como teorema en la quinta ronda: ninguna regla de exclusividad por
espacio sobrevive al Sybil de claves, porque partir el espacio entre identidades cuesta lo mismo que
no partirlo.

**La salida: la tabla de poder se deriva de las pruebas, no de un registro.** Cada bloque ya lleva
un sello Ed25519 sobre `pre_hash` bajo la clave del granjero (`C-HDR-03`, `C-HDR-04`), y R-FIN-8′ ya
define exactamente qué bloques cobran, uno por identidad de billete. Contar bloques cobrados por
clave en una ventana **es** una medida del espacio, insesgada en esperanza. Y el Sybil deja de
importar: partir el espacio en N claves reparte el mismo peso total en N trozos.

## 3 · Las reglas

**R-FIN-15 · Tabla de poder derivada.** Para la instancia `n`, sea `A_n` el bloque de la cadena
seleccionada finalizado por la instancia `n − LOOKBACK` (`LOOKBACK = 10`, el valor de F3). La tabla
de poder de la instancia `n` es la función `peso: pk → ℕ` que cuenta, sobre los bloques de
`past(A_n)` con `slot ∈ [slot(A_n) − W_POWER, slot(A_n))`, **los bloques que cobran por R-FIN-8′**
—azules y `rojo_k`— agrupados por la `public_key` de su sello. `W_POWER = 3 600 s`. La tabla es
función de `past(A_n)` y de nada más, luego todo nodo honesto calcula la misma.

> **Por qué los bloques que cobran y no los azules:** es el invariante de R-FIN-13′, *el conjunto
> que el retarget cuenta y el que la emisión paga son el mismo*. Añadir aquí un tercer conjunto
> reabriría la puerta que 9b cerró.

**R-FIN-16 · Comité por sorteo ponderado, con prueba de vida.** El comité de la instancia `n` tiene
**`K = 4 000` plazas** (elegido en §4.D, no en §4.A: lo fija el sesgo del sorteo, no el sorteo limpio). Se sortean con `H(entropía_j(A_n) ‖ n ‖ i)` para `i ∈ [0, K)`, cada plaza
asignada a una clave con probabilidad proporcional a su `peso` en R-FIN-15, **restringida a las
claves con al menos un bloque cobrado en los últimos `W_VIVO = 1 800 s`**. Sorteo determinista: no
hace falta VRF, todo nodo lo reproduce. Una clave puede ocupar varias plazas.

> **Por qué sorteo y no «los K mayores».** Con los mayores, un comité de 400 sobre 10 000 granjeros
> cubre el 67 % del espacio bajo Zipf, y el granjero pequeño nunca vota: es la centralización que el
> proyecto rechaza. Con sorteo ponderado entra en proporción a su espacio, sea del tamaño que sea.
>
> **Por qué `W_VIVO`.** Es la restricción que manda, ver §4.C. El comité debe salir de granjeros de
> los que hay prueba reciente de que están encendidos.

**R-FIN-17 · Certificado de finalidad.** Un certificado para el bloque de cadena `B` en la instancia
`n` es válido si lleva firmas de **≥ ⅔ de las `K` plazas** del comité de `n` sobre
`H("ZZKFinalCert___" ‖ n ‖ hash(B))`. El certificado incluye la firma agregada y el mapa de bits de
firmantes. Un nodo **MUST** verificarlo contra la tabla de R-FIN-15, que es función de la cadena, no
del certificado. La cadena de certificados desde génesis se verifica sola, sin la cadena de bloques.

**R-FIN-18 · Regla de selección con certificado.** Un nodo **MUST NOT** reorganizar por debajo del
bloque certificado más profundo que conozca. En ausencia de certificado rige **R-FIN-7 sin cambios**
(`F = 2 h`). Un certificado nunca invalida un bloque ni apaga el proceso: una punta que exigiera
reorganizar por debajo de él se **ignora**, igual que en R-FIN-7.

> **Prioridad entre las dos finalidades:** manda la más profunda de las dos. El certificado solo
> puede **adelantar** la finalidad, nunca retrasarla, y no puede finalizar nada que R-FIN-7 no
> hubiera finalizado en 2 h.

**R-FIN-19 · Doble firma: prueba pública y quema.** Dos firmas de la misma plaza en la misma
instancia sobre valores distintos son una **prueba de equivocación**. Cualquiera puede incluirla en
un bloque. Efecto: se queman las coinbases **no maduras** de esa `public_key`
(`COINBASE_MATURITY = 100`, R-FIN-8′ punto 9) y la clave queda excluida de las tablas de poder
durante `W_BAN = 30 días`.

> **Esto es el único punto donde la propuesta toca dinero, y a propósito no lo pide por adelantado.**
> El castigo cae sobre la recompensa que el granjero **ya ganó y aún no puede gastar**. Es el
> mecanismo de Filecoin, donde las recompensas no consolidadas son lo primero que se pierde ante una
> falta. Nadie compra nada para entrar; el aval aparece solo al granjear.
> **Honestidad:** el castigo es pequeño y no disuade a un atacante que ya decidió gastar `α = 0,3`
> en espacio. Su función es contra el granjero **racional** que ejecutaría dos clientes por
> descuido o por avaricia, no contra el adversario del modelo.

**R-FIN-20 · Elegibilidad y clave de firma.** Firma la misma `public_key` Ed25519 del sello del
bloque (`C-HDR-04`) si se adopta la variante sin agregación, o la clave BLS que esa clave Ed25519
declare en la coinbase de uno de sus bloques de la ventana, si se adopta la variante agregada (§5).

## 4 · Los números

Calculados hoy. Scripts en `research/scripts/finalidad-espacio/`, con criterio α declarado y
comprobado en los tres.

### A · El comité representa al espacio

`verif_sorteo.py`. Probabilidad de que un atacante con fracción `α` del espacio se lleve una
fracción del comité por azar del sorteo, con `K = 1 000`:

| `α` | ≥ ⅓ del comité: **para** la finalidad | ≥ ⅔ del comité: **finaliza una mentira** |
|---:|---:|---:|
| 0,10 | 5,0e-90 | 0 |
| 0,20 | 2,3e-23 | 2,2e-224 |
| 0,25 | 1,7e-09 | 4,6e-169 |
| 0,30 | 1,1e-02 | 3,3e-126 |
| 0,33 | 4,1e-01 | 6,5e-105 |

**La asimetría es el hallazgo.** Lo grave es baratísimo y lo leve es caro: para que la finalidad
falsa sea imposible basta `K ≈ 170` incluso a `α = 0,33`; para que no se pare hace falta `K ≈ 1 030`
a `α = 0,25` y `K ≈ 6 940` a `α = 0,30`. Se elige `K` por viveza y la seguridad viene gratis.

**Consecuencia que hay que decir en voz alta:** en el umbral operativo publicado, 33 %, esta capa
**no funciona** y no hay `K` que la salve. Se para el 41 % de las instancias y la cadena vuelve a
`F = 2 h`. Es el comportamiento correcto —seguridad antes que velocidad— pero significa que la
finalidad rápida es una **mejora del caso normal, no una garantía del umbral**.

### B · El certificado cabe, pero solo con firma agregada

`verif_certificado.py`, con un certificado cada 30 s:

| Esquema | `K` | Certificado | Coste anual |
|---|---:|---:|---:|
| Ed25519, una firma por plaza | 1 000 | 66 128 B | **69,51 GB** |
| BLS agregada + mapa de bits | 1 000 | 349 B | **0,37 GB** |
| Ed25519, una firma por plaza | 4 000 | 237 728 B | **249,90 GB** |
| BLS agregada + mapa de bits | **4 000** | **724 B** | **0,76 GB** |

Para comparar: las cabeceras de la rama A″ cuestan 21,5 GB/año y el PoT 4,0 GB/año. **Con Ed25519 el
certificado costaría tres veces la cadena entera.** No es viable. Esta capa **obliga a BLS**, y eso
es una decisión de peso que va a §5.

### C · La restricción que manda: el granjero doméstico se apaga

`verif_quorum.py`. F3 exige ⅔ del poder **total** de la tabla, no de los presentes. Si la fracción
de honestos encendidos y firmando es `p`, hay quórum solo si `(1 − α)·p ≥ ⅔`:

| `α` | participación honesta mínima |
|---:|---:|
| 0,10 | 74,1 % |
| 0,20 | 83,3 % |
| 0,25 | **88,9 %** |
| 0,30 | 95,2 % |
| 0,33 | 99,5 % |

Filecoin no sufre esto: sus proveedores son profesionales con `PoSt` continuo y penalización por
falta, encendidos 24/7. **Nuestro granjero objetivo es «un PC dedicado con SSD»**, que se apaga.

Por eso R-FIN-16 sortea el comité **solo entre quienes ganaron un bloque en los últimos 30 minutos**.
Un bloque reciente es prueba de que la máquina estaba encendida hace poco. Con `λ = 1` bloque/s hay
1 800 bloques en esa ventana, suficiente para `K = 1 000` plazas.

**No probado:** que `W_VIVO = 1 800 s` lleve `p` por encima del 88,9 %. Depende de la distribución
real de tiempos de encendido, que no tenemos. Es la primera medida que esta capa necesita, y es
análoga a `Δ`: sin ella los números de arriba son una cota, no una realidad.

**Descartado, con número:** exigir ⅔ de los **presentes** en vez del total. Un atacante que silencia
honestos sube su fracción entre los presentes: con `α = 0,30` y `p = 0,80` pasa a 34,9 % y rompe el
tercio. La regla de Filecoin es la correcta.

### D · El sesgo del sorteo por elección de ancla

`verif_sesgo_sorteo.py`. El atacante que elige entre `m` anclas elige entre `m` comités y se queda
con el mejor: `P = 1 − (1 − p)^m`. Se evalúa con las dos `m` del proyecto: la **medida** por D8 con
retención, `m = 2,955`, y la **garantizada por construcción** de la cota E de D9-f,
`m ≤ 1 + λ·S_max = 151`.

| `K` | `α` | `m` | P(para la finalidad) | P(finaliza una mentira) |
|---:|---:|---:|---:|---:|
| 1 000 | 0,25 | 2,955 | 5,1e-09 | 1,4e-168 |
| 1 000 | 0,25 | 151 | 2,6e-07 | 6,9e-167 |
| 1 000 | 0,30 | 151 | **8,1e-01** | 5,0e-124 |
| 4 000 | 0,25 | 151 | 3,0e-30 | 0 |
| 4 000 | 0,30 | 151 | **3,8e-04** | 0 |
| 4 000 | 0,33 | 151 | 1,00 | 0 |

**Dos conclusiones.** La primera es buena: **la seguridad no se toca**. Ni con la cota pesimista de
151 anclas y `α = 0,33` la finalidad falsa deja de ser imposible, 9,9e-103 con `K = 1 000` y cero
con `K = 4 000`. El *steering* multiplica una probabilidad por 151 y eso no mueve un exponente de
−105.

La segunda obliga a subir `K`: con `K = 1 000` y la cota de 151, un atacante del 30 % **para la
finalidad el 81 % de las veces**. Con `K = 4 000` baja a 3,8e-04. El certificado con firma agregada
pasa de 349 B a 724 B, o sea de 0,37 a **0,76 GB/año**, que sigue siendo la vigésima parte de las
cabeceras. **`K = 4 000`.**

**Lo que este cálculo NO cubre:** el atacante que además elige **qué bloques publica** para cambiar
la tabla de poder de R-FIN-15, no solo el ancla. Eso sigue siendo trabajo de D8 y es el punto 1 del
encargo.

## 5 · Lo que cuesta: BLS entra en la ruta de consenso

Es el precio real y es una **bifurcación de Katana**, porque toca la regla de no meter dependencias
como las que hicieron rechazar a Chia.

| | `blst` (Supranational) | `bls12_381` (zkcrypto) |
|---|---|---|
| Lenguaje | **C y ensamblador**, con enlace desde Rust | **Rust puro**, `no_std` |
| Auditoría | **Sí**, NCC Group enero 2021; verificación formal de Galois en curso | **No.** Su propio README: *«This implementation has not been reviewed or audited»* |
| Producción | Ethereum, Filecoin | Zcash y su ecosistema |

Las dos reglas del proyecto apuntan a lados opuestos: *«adoptar cripto auditada sin modificar»* pide
`blst`; el motivo de rechazar Chia —no meter C++ y GMP en la ruta de consenso de todos los nodos—
empuja al Rust puro.

**Diferencia con el caso Chia, y es sustantiva.** Lo decisivo contra `chiavdf` no fue solo el
lenguaje: fue que **no existe vector de interoperabilidad** entre implementaciones de VDF de grupos
de clases, de modo que el determinismo bit a bit solo estaba verificado dentro de una
implementación. BLS12-381 no está en esa situación: es una curva estandarizada con vectores de
prueba públicos y varias implementaciones independientes que interoperan en producción. El riesgo
tipo H-001 es de otra magnitud. **Comprobación pendiente:** que existan y pasen los vectores del
borrador del CFRG de firmas BLS. No lo he verificado hoy.

**Recomendación:** `blst`, confinado como excepción de FFI **igual que ya se contempla para
`zx-miner`**, y con `bls12_381` de zkcrypto como implementación de contraste en los tests
diferenciales. Motivo: una primitiva no auditada en la ruta de consenso es exactamente el fallo
H-001, y esa lección costó cara. **Es de Katana.**

## 6 · Los ataques que esta capa abre y hoy no existen

1. **La mentira se vuelve permanente.** Hoy un ataque con éxito produce una reorganización, que es
   temporal y visible. Con certificados, un atacante que reúna ⅔ del comité congela su versión
   **para siempre**, y ningún nodo honesto podrá salir de ahí. La probabilidad es 6,5e-105 a
   `α = 0,33` **si el sorteo es limpio**, que nos lleva al siguiente punto.
2. **Sesgo del sorteo — EVALUADO HOY, §4.D.** R-FIN-16 sortea con la entropía del ancla, y sesgar el
   ancla es el *steering* que consumió las rondas 3 a 10. Si el atacante elige entre `m` anclas,
   elige entre `m` comités. **Resultado: no rompe la seguridad y sí la viveza**, y por eso `K` sube
   de 1 000 a 4 000. Detalle en §4.D.
3. **Censura del comité.** ⅓ del comité puede negarse a firmar cualquier cosa que incluya una
   transacción. No rompe nada, pero convierte una censura cara en una censura barata mientras dure.
4. **Amplificación de la partición.** Un lado de una partición con menos de ⅓ del comité no
   certifica. Se suma a la tolerancia ya limitada de R-FIN-7, que exige que el lado conserve ≥ 9 %
   del espacio.

## 7 · Lo que NO está demostrado

- **La `p` real de un granjero doméstico.** §4.C. Sin ella, la viveza es una conjetura.
- **Las plazas de una misma clave caen juntas.** Con `K = 4 000` plazas sobre a lo sumo 1 800 claves
  vivas, una clave grande ocupa varias plazas y, si se apaga, se las lleva todas. El cálculo de §4.C
  trata las ausencias como independientes y por tanto **subestima** la varianza del quórum. Hay que
  rehacerlo con la distribución real de tamaños, o acotar plazas por clave. Error mío al escribir la
  primera versión: lo trataba como si cada plaza fuera un granjero distinto.
- **El sesgo del sorteo por `m`.** §6.2. Es el hueco mayor.
- **Que el protocolo BFT concreto funcione con esta tabla.** Aquí se especifica de dónde sale el
  comité, no cómo acuerda. GossiPBFT de F3 es el candidato: sus fases y su gestión de mensajes
  tardíos están en el FIP y hay implementación de referencia. No se ha portado ni leído entero.
- **Interacción con `S_max` y con el flujo de PoT.** Un certificado cruza flujos; R-FIN-5 dice que un
  bloque nunca referencia otro flujo, pero un certificado no es un bloque.
- **`Δ` sigue sin medir**, y aquí vuelve a mandar: el temporizador de las fases de GossiPBFT se
  calibra con el retardo de red.

## 8 · Encargo para la ronda adversarial

1. **D8 · el sesgo de la TABLA (§4.D, lo que el cálculo no cubre).** El sesgo por elección de ancla
   ya está acotado. Falta el atacante que retiene o publica bloques para cambiar la tabla de poder de
   R-FIN-15 y, con ella, los pesos del sorteo. Instrumento: el de D9-f. Criterio α obligatorio.
2. **D9 · la composición del quórum (§4.C).** ¿Existe una regla de vida que lleve `p` por encima de
   `2/3(1−α)` sin reintroducir un registro? ¿Qué hace un atacante que apaga honestos?
3. **D9 · permanencia (§6.1).** ¿Puede un certificado finalizar algo que R-FIN-7 no habría
   finalizado? Si sí, R-FIN-18 está mal escrita.
4. **D8 · el certificado como vector de DoS.** Coste de verificar certificados inválidos;
   `C-NET-03/04` se calibraron para un SHA3 y ya deben rehacerse por el PoT.

## 9 · Orden recomendado

**Esto va DESPUÉS de cerrar P-038, no en paralelo.** La capa se apoya en la cadena seleccionada y en
el ancla; si el ancla cambia por décima vez, la propuesta se cae con ella. El orden es: cerrar
P-038 con sus costes declarados, medir `Δ`, y entonces abrir esta como P-040.

**Lo que ya está hecho:** el sesgo del sorteo por elección de ancla, §4.D, que era el ataque que
parecía principal. No mata la propuesta; sube `K` a 4 000. Lo que decide ahora si vive es la `p` de
§4.C, y esa es una medida de campo, no una simulación.
