# D13 · F0b — Anti-equivocación sin dinero en juego: el dilema del voto en PoAS

**Agente:** F0b · **Fecha:** 2026-09-10 · **Encargo:** `research/scripts/d13-finalidad/ENCARGO.md` §F0
**Método:** `research/scripts/METODO-AGENTES.md` (cinco etiquetas, citas línea:línea, sin memoria).
**Pregunta:** ¿existe una regla anti-equivocación que restaure la Definición 1 de HotPoW (cada ATV vota
una vez por un valor) **sin dinero en juego**? Si no existe, demostrarlo.

**Fuentes primarias usadas en este informe:**

| Fuente | Ruta | Qué se cita |
|---|---|---|
| Keller y Böhme, *HotPoW* | `research/fuentes/hotpow.txt` | §2-§5, Apéndice A, Tabla A.1 |
| Sankagiri et al., *CAP* | `research/fuentes/cap-adaptividad-finalidad.txt` | CP0-CP3, Apéndice D |
| Lewis-Pye y Roughgarden | `research/fuentes/lewispye-roughgarden-cap.txt` | Def. 3.1-3.4, Teorema 4.1 |
| Bagaria et al., *PoS Security vs Predictability* | `research/fuentes/bdk19.txt` | slashing, ataques overt/covert |
| Autonomys | `/home/katana/zeo/fuentes/subspace` @ `f8842d0` | voto, `verify_solution`, identidad, equivocación |
| Chia | `PDF/chia-blockchain/` v2.7.4 | atadura del plot a la clave |
| d12 | `research/scripts/d12-quorum/informe.md` | §B.2, §B.5, §F.1-F.7, §G.3 |
| Diseño vivo / capa F3 | `research/dag-poas-ancla-de-orden.md`, `research/dag-poas-capa-finalidad.md` | R-FIN-11, R-FIN-14, R-FIN-19 |
| Informes locales | `research/dag-consenso-poas.md`, `research/dag-nativo-poas-propuesta.md`, `research/dag-poas-inyeccion-auditoria.md`, `research/scripts/d9-ronda9b/informe.md` | precedente de equivocación en Autonomys, entropía, autocastigo |

---

## 0 · Veredicto anticipado

> **No existe ninguna regla que restaure la Definición 1 de HotPoW —dos quórums en conflicto exigen
> `2k` ATVs— conservando a la vez las cuatro premisas del PoAS de ZEROX: (i) el voto es una prueba de
> espacio precomputada, (ii) el reto se deriva solo del PoT y del slot, (iii) sin dinero en juego y
> (iv) sin registro/tabla de poder.** Restaurar `2k` obliga a pagar uno de estos cuatro precios:
> un **segundo recurso** (puzzle fresco por voto, variante e), un **registro global con estado**
> (nullifier, variante a), un **castigo ex-post sobre un activo escaso** (dinero o espacio, variantes
> b/c/g), o aceptar que el voto sea un **bloque** (variante d), que restaura `2k` gratis pero es
> profundidad de confirmación y no un gadget (d12 §B.2). La variante (f) reabre el *grinding* y la (h)
> queda LAGUNA. **El dilema estructural es DEMOSTRADO; el teorema de imposibilidad general es
> PLAUSIBLE** (la literatura local prueba una imposibilidad distinta: adaptividad vs finalidad).

---

## 1 · El hecho estructural: por qué la equivocación es gratis en PoAS

### 1.1 · HotPoW: el valor votado está dentro del puzzle

La Definición 1 (`hotpow.txt:281-284`, literal):

> *«A proof-of-work process is a stochastic count process where each event assigns one ability to
> vote (ATV) to one agent. Each ATV can be used by the agent it is assigned to, to vote **once** for
> **one** value.»*

Un voto en HotPoW es un triplete `(r, p, s)` (`hotpow.txt:492-497`):

> *«a vote in HotPoW is a triple (r, p, s), where r is a reference to a previous block, p is the
> public key of the voter, and s is a puzzle solution. A vote (r, p, s) is valid if
> `Hpow(r, p, s) ≤ tv`»*

El valor votado **es** `r`, y `r` está dentro de la preimagen del hash del puzzle. La condición de
quórum lo repite (`hotpow.txt:509-517`) y la validez del bloque la recalcula sobre el padre
(`hotpow.txt:544-555`, línea 18 en `:548`: `h′ ← Hpow(B.parent, p, s)`). Por eso el paper puede
escribir la condición de ambigüedad (`hotpow.txt:301-304`):

> *«Since each ATV can be used for at most one value, ambiguous k-quorums are only possible when the
> proof-of-work process has assigned at least **2k** ATVs.»*

La escasez del voto es lo que sustituye al registro: *«We intentionally allow single nodes providing
multiple votes. **Sibyl attacks are mitigated by the scarcity of votes**»* (`hotpow.txt:517-518`).
Y la seguridad no depende de incentivos **porque el puzzle ata el valor** (`hotpow.txt:726-729`:
*«HotPoW supports incentives for inclusiveness, but its security intentionally does not rely on
incentives»*). Esa frase es la clave de todo este informe: donde HotPoW no necesita dinero, es porque
el puzzle hace el trabajo.

### 1.2 · PoAS: el valor solo está en la firma, no en la prueba

En Autonomys el voto es `Vote::V0` (`sp-consensus-subspace/src/lib.rs:180-197`):

```
V0 { height, parent_hash, slot, solution, proof_of_time, future_proof_of_time }
```

- `parent_hash` es el valor votado (el bloque sobre el que se vota, `:186-188`).
- El hash firmado es el voto entero (`:218-221`), y `check_reward_signature` verifica una firma
  Schnorrkel sobre ese hash bajo la clave del granjero
  (`subspace-verification/src/lib.rs:107-116`). **Una clave firma cuantos mensajes quiera.**
- `verify_solution` **no ve `parent_hash`** (`subspace-verification/src/lib.rs:211-216`): deriva
  `sector_id = (public_key, sector_index, history_size)` (`:228-232`), el reto global de
  `proof_of_time` y **slot** (`:234-236`), y comprueba prueba de espacio, distancia de solución y
  testigo KZG (`:239-260`).
- `Solution` lleva `public_key` y `reward_address` **separados** (`subspace-core-primitives/src/
  solutions.rs:254-275`): la clave que firma es la del plot, no la de la recompensa.

Consecuencia, leída del código: **la misma `solution` con dos `parent_hash` distintos produce dos
votos válidos con dos firmas válidas de la misma clave**. Autonomys lo sabe y lo llama equivocación:
la identidad del voto es `(public_key, sector_index, piece_offset, chunk, slot)`
(`pallet-subspace/src/lib.rs:1591-1597`); si esa clave reaparece con **otra firma** es
`is_equivocating` (`:1603-1621`) y se revocan recompensas (`:1656-1685`). Pero el nodo de consenso
**no hace nada**: `sc-consensus-subspace/src/verifier.rs:401-405` es un `TODO` literal, y el PR
#3072 retiró el slashing (`research/dag-consenso-poas.md:69`). **La equivocación es estructural, no
un descuido de implementación.**

### 1.3 · De `2k` a `k` ATVs: formalización y POA

| | HotPoW (Def. 1) | PoAS (equivocación libre) |
|---|---|---|
| Qué ata el valor | el puzzle: `Hpow(r,p,s) ≤ tv` (`hotpow.txt:492-497`) | la firma: `check_reward_signature` (`subspace-verification:107-116`) |
| ¿La prueba de recurso ve el valor? | **Sí**, `r` está en la preimagen | **No**, el reto es `derive_global_challenge(slot)` (`:234-236`) |
| Ambigüedad ⇒ ATVs necesarios | **`2k`** (`hotpow.txt:301-304`) | **`k`** (las mismas `k` soluciones firman ambos valores) |
| `POA(t)` (Def. 4, `hotpow.txt:305-312`) | `Pr[P(t) ≥ 2k]` | `Pr[P(t) ≥ k]` |
| En `t = t̄ = k/λ` (Cor. 2, `:379-386`) | `P(2k,k)` | `P(k,k) = 1 − e^{−k} Σ_{i=0}^{k−1} k^i/i!` |
| En el tiempo real de quórum `T_{P,k}` | **0** (en `T` hay exactamente `k` ATVs) | **1** (en `T` ya hay `k` ATVs, y cada uno sirve para ambos valores) |

La última fila es más fuerte que la comparación de métricas: no es que la probabilidad suba, es que
**la condición necesaria de ambigüedad pasa de imposible a cierta en el mismo instante `T_{P,k}`**.
La Definición 4 define `POA` como la probabilidad de que el proceso haya asignado ATVs suficientes
para que la ambigüedad sea *posible*; con equivocación libre, el umbral de "suficientes" cae de `2k`
a `k`.

**Advertencia de lectura (ya la hizo d12 §B.5, `informe.md:211-223`):** `POA(t̄)` **no es** la
probabilidad de fallo del protocolo desplegado; el paper evalúa en `t̄` *«in order to isolate the
effect of k»* (`hotpow.txt:374-377`). Con `k = 64` y `λ_v = 1/s`, `POA` vale `1,3e-12` en `t̄` y
`0,5118` en `2t̄` (`hotpow.txt` y d12 §B.5). Lo que este informe afirma es la comparación entre las
dos definiciones **en el mismo instante**, no una cota de despliegue.

### 1.4 · Verificación de la aritmética de d12 §F.7

Control positivo obligatorio del encargo (reproducir `0,2642` y `0,5166`) con el instrumento de
`research/scripts/rendimiento/verif_quorum_soluciones.py:18-30` (misma función `poisson_sf`),
cruzado con `scipy.stats.poisson` y con `mpmath.gammainc` regularizada (`P(a,k)`):

| `k` | `P(Pois(k) ≥ 2k)` — Def. 1 | `P(Pois(k) ≥ k)` — equivocación | d12 §F.7 (`informe.md:629-635`) |
|---:|---:|---:|---|
| 1 (Bitcoin, `λt̄ = 1`) | **0,2642411** | — | 0,2642 (control, `hotpow.txt:403-405`) |
| 16 | 2,761998e-04 | **0,533255** | 2,762e-04 / 0,5333 |
| 32 | 4,144461e-07 | **0,523512** | — |
| 64 | **1,272367e-12** | **0,516624** | **1,272e-12 / 0,5166** |
| 128 | 1,661074e-23 | 0,511754 | — |
| 256 | 3,959042e-45 | 0,508311 | 3,959e-45 / 0,5083 |

**VERIFICADO.** Los tres instrumentos coinciden a los dígitos mostrados; la Tabla A.1 del paper
(`hotpow.txt:1835-1842`: `0,0003`; `1,2e-12`; `4e-45`) queda reproducida. La tabla de d12 §B.5
también se reproduce: `POA(64, 128 s) = P[Pois(128) ≥ 128] = 0,511754` y `POA(64, 256 s) ≈ 1`.
El `194 s` de d12 §B.b es la aritmética trivial `k/(αλ) = 64/0,33 = 193,9 s` (`salida_b.txt:53-57`);
**correcto** (d12 lo etiqueta VERIFICADO con su simulador, no lo re-mido aquí).

### 1.5 · Corrección de una cita de d12

d12 §F.7 (`informe.md:619`) y `d12_b_composicion.py:91` citan `hotpow.txt:437-441` para
`Hpow(r,p,s) ≤ tv`. Esa cita es **incorrecta**: las líneas 437-441 son la Figura 6 y la interfaz de
aplicación. La definición del voto está en **`hotpow.txt:492-497`**, las condiciones de quórum en
**`:509-517`** y la validez de bloque en **`:544-555`** (línea 18 en `:548`). La conclusión de d12 no
cambia; la cita, sí. Se declara en §6.

---

## 2 · Las ocho variantes, una a una

### 2.0 · Tabla resumen

| # | Variante | ¿Restaura `2k`? | Etiqueta | Coste real | Esquive que la mata |
|---|---|---|---|---|---|
| a | Nullifier on-chain por solución | Sí, en cadena única | PLAUSIBLE (sync) / **REFUTADO** (partición) | estado de consenso (≈15 MB acotado a `F=2 h`; ≈64,6 GB/año si no se poda) + certificado deja de ser autoverificable | es **local a la rama**: en partición cada lado acepta su certificado; el split ya ocurrió cuando se ven |
| b | Quema de recompensa + lista negra de clave | Solo como disuasión ex-post | PLAUSIBLE (racional) / **REFUTADO** (prevención) | cero por adelantado; exige prueba vista e incluida | `reward_address` es maleable (`solutions.rs:254-275`); el adversario bizantino no valora la recompensa futura |
| c | Castigo de espacio (plot inelegible `E` épocas) | Solo como disuasión ex-post | **DEMOSTRADO** que la clave ata al plot / PLAUSIBLE disuasión / **REFUTADO** prevención | replotear si se rota clave (Autonomys `sectors.rs:54-68`; Chia `proof_of_space.py:359-364`) | prueba invisible en partición; atacante que abandona el plot; espacio repartido en muchas claves |
| d | Voto = bloque (U2/U3″) | **Sí, gratis** | **DEMOSTRADO** / **REFUTADO como aportación** (d12 §B.2) | ninguno | es profundidad de confirmación: `λ_v = λ_bloque = 1/s` ⇒ el quórum tarda `k` bloques y no aporta información |
| e | Puzzle fresco por voto (PoW/VDF) | **Sí, por construcción** | **DEMOSTRADO** que restaura / PLAUSIBLE encaje | un segundo recurso: un puzzle por voto (`hotpow.txt:492-497`); `λ_v = k/s`; 0,98 TB/año de gossip (d12 §F.4) | no hay esquive al binding; el precio es que **es HotPoW**, lo que ZEROX descartó; ASIC/AES vuelven a la ruta de voto |
| f | Atar el reto al valor | Sí, pero rompe PoAS | **REFUTADO** | no es "replotear por valor": el granjero responde de su plot con probabilidad `α`; el coste real es la pérdida del reto por slot | **grinding**: el productor del valor lo muele; `entropía = blake3(chunk‖pot_output)`, no el hash del bloque, *«para que no se pueda moler con el contenido»* (`dag-nativo-poas-propuesta.md:72-74`) |
| g | Accountable BFT (slashing de depósito) | Sí, bajo supuesto económico | **DEMOSTRADO** (BFT estándar) / coste = dinero | depósito en juego + identidad atada + prueba incluida | ex-post y ciego a partición; hay que valorar el daño y el depósito; R-FIN-19 ya reconoce que no disuade al adversario decidido (`capa-finalidad:105-111`) |
| h | Submuestreo tipo Avalanche | No es el mismo `2k` | **LAGUNA** (sin fuente primaria local) / PLAUSIBLE que la equivocación no añada nada a su modelo bizantino | muestreo + pesos; finalidad probabilística | no da finalidad determinista; liveness atacada (arXiv:2210.03423, citado en `dag-consenso-poas.md:85-86`) |

### 2.1 · (a) Nullifier on-chain por solución

**Mecanismo.** Un conjunto de estado `usadas` con `H(identidad de la solución)`; un certificado que
incluya una solución ya presente es inválido. Fuerza soluciones distintas para `x` y para `y` ⇒ `2k`
ATVs. Es la generalización global del `DuplicateVote` que Autonomys ya tiene **dentro** de un
bloque y su padre (`pallet-subspace/src/lib.rs:1613-1634`).

**Coste.** (1) Estado de consenso. Si se poda al horizonte de finalidad `F = 2 h`
(`dag-poas-ancla-de-orden.md:271-273`), son `64 votos/s × 7 200 s × 32 B ≈ 14,7 MB` — pequeño; sin
podar, `64 votos/s × 31,536e6 s/año × 32 B ≈ 64,6 GB/año` (aritmética propia, VERIFICADO). (2) El
certificado deja de ser autoverificable: verificar un voto exige consultar el estado del nullifier,
que es exactamente lo que d12 §G.3 (`informe.md:691-703`) señala como la frontera entre el quórum y
la capa estilo Filecoin.

**Esquive.** El nullifier es **local a la rama**. En una partición, cada lado tiene su propio
conjunto y acepta su certificado; la regla solo impide la doble inclusión *en la misma cadena*.
Cuando las ramas se reencuentran, el nullifier decide cuál cae, pero si ambas ya finalizaron, el
split es permanente. Y la finalidad (Lewis-Pye Def. 3.4, `lewispye:740-741`) es precisamente la
seguridad **en el escenario parcialmente síncrono**, donde la partición existe. Un nullifier no
restaura la seguridad del quórum en el único escenario que la capa de finalidad debe cubrir.

**Etiqueta:** PLAUSIBLE que restaura `2k` en cadena única; **REFUTADO** como regla de finalidad sin
dinero y sin estado.

### 2.2 · (b) Quema de recompensa del bloque + lista negra de la clave

**Mecanismo.** Probada la doble firma de la misma solución, se quema la recompensa del firmante y se
excluye su clave durante `E` épocas. Es la variante de la recompensa de R-FIN-19
(`dag-poas-capa-finalidad.md:99-111`).

**Coste.** Cero por adelantado: el castigo cae sobre una recompensa ya ganada. **Pero** el
`reward_address` es un campo separado del `public_key` en `Solution` (`subspace-core-primitives/src/
solutions.rs:254-275`), así que "quemar la recompensa" se esquiva usando una dirección nueva; lo que
muerde de verdad es la lista negra de la clave, que sí ata al plot (§2.3).

**Esquive.** (1) La prueba de equivocación exige **ver las dos firmas**; en una partición no se ven,
así que el castigo llega tarde. (2) El adversario bizantino no valora recompensas futuras. La propia
R-FIN-19 lo dice: *«el castigo es pequeño y no disuade a un atacante que ya decidió gastar `α = 0,3`
en espacio. Su función es contra el granjero racional…, no contra el adversario del modelo»*
(`dag-poas-capa-finalidad.md:109-111`).

**Etiqueta:** PLAUSIBLE como disuasión del granjero racional; **REFUTADO** como prevención del
quórum.

### 2.3 · (c) Castigo de espacio: revocar la elegibilidad del plot por `E` épocas

**Mecanismo.** Igual que (b), pero el castigo revoca el plot. La pregunta que lo decide —¿se puede
rotar la clave sin replotear?— tiene respuesta en el código:

- **Autonomys:** `SectorId::new(public_key_hash, sector_index, history_size)`
  (`subspace-core-primitives/src/sectors.rs:54-68`) y `derive_evaluation_seed` deriva del
  `sector_id` (`:126-130`). La prueba de espacio está atada a la clave: **rotar la clave invalida
  los plots y obliga a replotear.** VERIFICADO en el código.
- **Chia:** `plot_public_key = local_pk + farmer_pk` (`chia/types/blockchain_format/
  proof_of_space.py:359-364`) y `plot_id = calculate_plot_id_pk(pool_pk, plot_public_key)`
  (`chia/plotting/create_plots.py:203-207`). La clave del *farmer* está dentro del `plot_id`; solo
  la del *pool* es rotable sin replotear. VERIFICADO en el código.

**Coste.** El castigo es proporcional al espacio del infractor (`E` épocas de recompensa de ese
plot). Es el único castigo no monetario con dientes reales.

**Esquive.** (1) La prueba sigue siendo invisible en partición. (2) Un atacante con muchas claves
sacrifica una: el castigo cae sobre el plot que equivocó, no sobre el espacio total; D9 ya demostró
que ninguna regla de exclusividad por espacio sobrevive al Sybil de claves
(`dag-poas-capa-finalidad.md:47-50`). (3) Un adversario que planea abandonar el plot no paga nada.
(4) Es ex-post: no evita el split.

**Etiqueta:** **DEMOSTRADO** que la clave ata al plot; PLAUSIBLE como disuasión; **REFUTADO** como
prevención sin dinero.

### 2.4 · (d) Voto = bloque (U2/U3″)

**Mecanismo.** El voto es el propio bloque. La identidad de billete de R-FIN-11
(`dag-poas-ancla-de-orden.md:206-211`) es `(public_key, sector_index, history_size, chunk, slot)`;
U2 invalida un bloque cuya identidad esté en `past(B)` y U3″ solo deja un azul por identidad; R-FIN-8′
no paga al `rojo_U3` (`research/scripts/d9-ronda9b/informe.md:443-455`). Dos quórums en conflicto
exigen `2k` identidades distintas ⇒ `2k` ATVs. **Restaura la Definición 1 gratis**, y es la única que
lo hace.

**Coste/esquive.** Ninguno técnico — y por eso mismo no aporta nada: d12 §B.2 lo demostró con tres
argumentos (`informe.md:129-153`): no hay información nueva (es el predicado "`B` tiene `k`
confirmaciones"), `λ_v = λ_bloque = 1/s` hace que el quórum tarde `k` segundos = `k` bloques, y el
atacante forja su certificado en `194 s` a `α = 0,33`. La unicidad no la da la teoría de quórums,
la da la regla de cabeza de HotPoW (Listing 4.6, línea 41, `hotpow.txt:601-609`, la línea 41 en
`:608`), que es R-FIN-7.
**La regla anti-equivocación gratuita ya existe en el DAG: se llama no reutilizar un billete. El
gadget de quórum no puede usarla sin convertirse en profundidad de confirmación.**

**Etiqueta:** **DEMOSTRADO** que restaura `2k`; **REFUTADO** como aportación (d12 §B.2 y §H.1).

### 2.5 · (e) Puzzle fresco por voto (PoW o VDF ligero)

**Mecanismo.** Cada voto exige resolver un puzzle **posterior al valor** y que lo incluya:
`Hpow(r, p, s) ≤ tv` (`hotpow.txt:492-497`), o un VDF sobre `r`. Es exactamente el binding de
HotPoW: cambiar `r` obliga a resolver otro puzzle ⇒ `2k` ATVs. **DEMOSTRADO por el argumento del
paper** (`hotpow.txt:301-304`).

**Coste.** Es el diseño de HotPoW entero. `λ_v = k/λ_bloque` (`hotpow.txt:153-156`: *«HotPoW asks
for k easier puzzles each expected to take 10/k minutes»*); el voto ya no se precomputa (el valor
debe conocerse antes), la generación de votos se acopla a la punta del DAG, y hay que verificar `k`
soluciones por segundo en la variante 2 (`k = 64`: +6,9 % de núcleo sobre el 9,6 % del PoT, d12
§F.6). El tráfico es `0,98 TB/año` a `k = 64` (d12 §F.4) y el voto son 484 B (d12 §F.1).
Si el puzzle es PoW: vuelven ASICs y energía, justo lo que el cambio DECIDIDO a PoAS eliminó. Si es
VDF: vuelve una carrera de hardware AES, del mismo tipo que R-FIN-14(f) ya acota con `ρ_max`
(`dag-poas-ancla-de-orden.md:253-254`).

**Esquive.** No hay esquive al binding. El precio es que **esta variante no es un gadget sobre PoAS:
es HotPoW**, y su seguridad vuelve a depender del recurso que el proyecto descartó. La pregunta "¿sin
dinero en juego?" se responde que sí en la letra (trabajo no es dinero) y no en el espíritu (es un
segundo recurso escaso, con la misma asimetría hardware que motivó el cambio de consenso).

**Etiqueta:** **DEMOSTRADO** que restaura `2k`; PLAUSIBLE el encaje; **cuesta la premisa PoAS.**

### 2.6 · (f) Atar el reto al valor (replotear por valor)

**Mecanismo propuesto.** `reto = H(PoT, slot, valor)` en vez de `H(PoT, slot)`, de modo que una
prueba de espacio solo sirva para el valor que la reta.

**Lo que el código dice del coste.** No es "replotear por valor": el granjero responde de su plot
con probabilidad igual a su fracción de espacio, sin replotear; la auditoría selecciona un chunk y
el granjero lo tiene o no. El coste real es otro: **se pierde la derivación del reto por slot**, que
es lo que impide moler el contenido. La entropía del PoAS de Autonomys es
`blake3(chunk ‖ pot_output)`, *«no el hash del bloque (decisión explícita de Barak 1639 para que no
se pueda moler con el contenido)»* (`dag-nativo-poas-propuesta.md:72-74`), y
`dag-poas-inyeccion-auditoria.md:218` lo repite: *«El hash del bloque, que sí es moldeable
re-firmando, no entra en la entropía.»* R-FIN-14(c) fija el reto como función del PoT y del slot
(`dag-poas-ancla-de-orden.md:243-246`) y R-FIN-14(e) **prohíbe** derivarlo de cualquier función
moldeable (`:250-252`).

**Esquive.** **Grinding.** El productor del valor es el propio granjero: puede cambiar el cuerpo de
su bloque y re-firmarlo hasta que el reto caiga en un chunk que tiene. Con `α = 0,01` de espacio y
un hash por intento, encuentra un impacto en ~100 intentos: su espacio efectivo se amplifica hasta
~1 por un coste de hash trivial. Eso rompe la proporcionalidad espacio-seguridad en que se basa todo
el PoAS.

**Etiqueta:** **REFUTADO** (reabre el grinding que el diseño evita por construcción).

### 2.7 · (g) Seguridad accountable estilo BFT (slashing de depósito)

**Mecanismo.** Cada plaza/voto deposita `D`; dos firmas sobre valores distintos en el mismo slot son
una prueba pública que quema `D`. La literatura local lo respalda: *«one way to minimize NaS attacks
is to require users to deposit stake that can be slashed if the node has a provable deviation (for
example, double-signing blocks)»* (`bdk19.txt:1496-1498`), y los ataques *overt* *«can be penalized
with slashing penalties»* (`bdk19.txt:279-284`).

**Coste.** Dinero en juego: capital inmovilizado, identidad atada al depósito (o Sybil), y una
función de valoración del daño. Es exactamente lo que la pregunta F0 quiere evitar.

**Esquive.** (1) La detección es ex-post y ciega a partición: `bdk19.txt:299-305` llama *covert* al
ataque que *«does not require miners to double-sign blocks, making it indistinguishable from
unexpected network latency»*; en nuestro caso, las dos firmas **sí** son detectables si se ven, pero
no se ven en partición. (2) El adversario sacrifica `D` si el botín lo supera. (3) R-FIN-19 ya
reconoce que su castigo no disuade al adversario decidido (`dag-poas-capa-finalidad.md:109-111`).

**Etiqueta:** **DEMOSTRADO** que restaura `2k` bajo el supuesto económico estándar; **coste = dinero
en juego**, que es la hipótesis que F0 quería negar.

### 2.8 · (h) Submuestreo tipo Avalanche

**Mecanismo.** Muestreo aleatorio repetido con contadores de confianza (Snowball/Snowman) en vez de
un quórum contado por ATVs.

**Respuesta a la pregunta del encargo.** **LAGUNA**: no hay fuente primaria de Avalanche en
`research/fuentes/` (el encargo F2 la lista como *«fuente primaria a traer»*), y no se puede
verificar localmente su argumento de seguridad. Lo que sí se puede decir con fuente local:
(i) su finalidad es **probabilística**, no el `2k` determinista de HotPoW, así que no es una
"restauración" del quórum; (ii) su liveness tiene ataques documentados — *«Avalanche: liveness/DoS
explotando la dependencia de votos entre ancestros (arXiv:2210.03423, 2022; reconocido, la versión
desplegada difiere del whitepaper)»* (`dag-consenso-poas.md:85-86`); (iii) estructuralmente, su
modelo bizantino ya permite que un nodo responda distinto a cada muestreo, que **es** la
equivocación, así que la Definición 1 no se le aplica del mismo modo (PLAUSIBLE, sin fuente local).
No es una vía para restaurar la garantía del quórum; es otro mecanismo, con otro modelo y otro coste.

**Etiqueta:** **LAGUNA** (hace falta el paper de Avalanche); PLAUSIBLE la lectura estructural.

---

## 3 · ¿Existe un teorema de imposibilidad de seguridad sin coste por equivocación?

### 3.1 · Lo que la literatura local SÍ prueba

| Resultado | Enunciado | Fuente |
|---|---|---|
| Lewis-Pye, Teorema 4.1 | *«No protocol is both adaptive and has finality»* | `lewispye:231`, `:759` |
| Definiciones | adaptativo = vivo en el escenario **sin tamaño** (Def. 3.2, `:727-728`); finalidad = seguro en el **parcialmente síncrono** (Def. 3.4, `:740-741`); seguridad = bloques confirmados compatibles (Def. 3.3, `:735-739`) | `lewispye:727-741` |
| Idea de la prueba | *«in the unsized (and partially synchronous) setting … network partitions [are] indistinguishable from waning resource pools»* | `lewispye:774-781` |
| Hipótesis | *«No balance, no voice»*: sin recurso no hay permiso de emisión | `lewispye:754-756` |
| CAP (Sankagiri) | mismo techo: un protocolo adaptativo no puede ofrecer finalidad, y viceversa | `cap:249-258` |
| CAP, CP1 | la recencia es una condición de los checkpoints; PBFT y HotStuff **no** la cumplen: un líder puede bloquear un bloque en privado y finalizarlo tarde | `cap:192-194`, `:529-531`, `:1574-1580` |

### 3.2 · Lo que la literatura local NO prueba

**Ninguna de las tres fuentes locales menciona la equivocación ni la contabilidad de ATVs.** El
Teorema 4.1 es de adaptividad vs finalidad, no de "coste por equivocación". HotPoW **excluye** las
fallas que lo sacarían de su modelo: *«under axiomatic exclusion of the failure modes PoW-1 and
PoW-2»* (`hotpow.txt:1235-1237`, y `:265-275`), y su Definición 1 es una **hipótesis normativa**, no
un teorema. Es decir: HotPoW no demuestra que la Definición 1 se cumpla en todo sistema permissionless;
la **postula** y construye el puzzle para que se cumpla. En PoAS la hipótesis es falsa, y el paper no
tiene nada que decir al respecto. **LAGUNA declarada.**

### 3.3 · El dilema estructural — DEMOSTRADO

Sea un esquema de voto `(π, x, σ)` donde `π` es una prueba de recurso, `x` el valor y `σ` una firma
bajo una clave `pk` de generación libre. Se cumple, leído del código:

1. **La validez de `π` es independiente de `x`**: `verify_solution(π, slot, params)` no recibe el
   valor (`subspace-verification/src/lib.rs:211-216, 228-260`).
2. **La firma es reutilizable**: `check_reward_signature` verifica `σ` sobre el hash del mensaje que
   se le dé (`:107-116`), y una clave firma cualquier número de mensajes.
3. **La identidad del plot es escasa y atada a la clave**: `SectorId::new(public_key_hash, …)`
   (`sectors.rs:54-68`), pero el coste de reutilizar `π` en dos valores no lo paga el protocolo.

Entonces, para `x ≠ y`, la misma `π` produce dos votos válidos, y dos quórums en conflicto exigen
**`k` pruebas, no `2k`**. Para volver a `2k` no hay más que cuatro salidas lógicas:

- **(A) que `π` dependa de `x`** ⇒ hay que recomputar `π` por valor (variantes e/f);
- **(B) que el protocolo impida la reutilización de `π`** ⇒ un registro global de usados (variante a);
- **(C) que reutilizar `π` tenga un castigo sobre un activo escaso** (variantes b/c/g);
- **(D) que el voto sea un objeto escaso atado al valor** ⇒ el bloque (variante d).

No hay una quinta: si `x` no entra en la validez de `π` y no hay registro ni castigo, las dos
utilizaciones son indistinguibles para el protocolo. **DEMOSTRADO** (es la definición de "predicado
independiente del valor").

### 3.4 · El teorema general — PLAUSIBLE

La afirmación fuerte —"en un sistema permissionless no puede haber seguridad sin coste por
equivocación"— **no está probada en las fuentes locales** y no la puedo elevar a DEMOSTRADO sin un
modelo formal. Lo que sí sostienen las fuentes es la mitad que importa:

- La finalidad exige seguridad en el parcialmente síncrono (`lewispye:740-741`), y en ese escenario
  la partición es indistinguible de la caída de recursos (`lewispye:774-781`). Un castigo que
  necesita **ver las dos firmas** no puede actuar antes de que la partición sane; por tanto no puede
  prevenir el split, solo castigarlo después. **DEMOSTRADO** a partir de la definición de finalidad
  y del requisito de detección.
- "No balance, no voice" (`lewispye:754-756`): un protocolo no puede actuar contra quien no tiene
  recurso. En permissionless la identidad es libre, así que el único activo embargable es el recurso
  escaso: espacio (castigo c) o dinero (depósito g). **PLAUSIBLE** como teorema general; hace falta
  un modelo con equivocación explícita que no existe en local.

**Etiqueta global de la sección:** DEMOSTRADO el dilema estructural (A-D); **PLAUSIBLE** el teorema
general de imposibilidad; **LAGUNA** su enunciado formal en un modelo de equivocación.

---

## 4 · Si la única vía es dinero en juego: diseño mínimo y comparación con R-FIN-19

### 4.1 · Diseño mínimo

| Pieza | Contenido mínimo | Fuente/anclaje |
|---|---|---|
| **Depósito** | Cada voto referencia una **reclamación de recompensa no madura** del bloque que contiene la solución (o un depósito UTXO). Sin reclamación, el voto no es válido. No hay capital por adelantado si se usa la coinbase, como R-FIN-19. | `dag-poas-capa-finalidad.md:99-103` (`COINBASE_MATURITY = 100`) |
| **Prueba** | Dos votos firmados con la **misma identidad** `(public_key, sector_index, history_size, chunk, slot)` y **valores distintos**. Es exactamente la condición `Equivocated` de Autonomys (`pallet-subspace/src/lib.rs:1591-1597, 1603-1621`), pero extendida a **certificados y ramas**, no solo a bloque actual + padre. | Autonomys `pallet-subspace/src/lib.rs:1591-1685` |
| **Castigo** | Quema de la reclamación + exclusión de la clave durante `E` épocas. La exclusión ata al plot porque `SectorId` incluye la clave (`sectors.rs:54-68`). | `dag-poas-capa-finalidad.md:99-111` (R-FIN-19) |

### 4.2 · Comparación con R-FIN-19

| | R-FIN-19 (capa F3) | Depósito mínimo del quórum |
|---|---|---|
| Qué se firma | una **plaza** del comité de la instancia | una **solución** usada en un voto de certificado |
| Quién tiene el poder | tabla derivada de bloques cobrados (R-FIN-15/16) | los poseedores de reclamaciones de solución |
| Qué se pierde | coinbases **no maduras** de la clave | reclamación de la solución + clave/plot |
| Capital por adelantado | **no**: es recompensa ya ganada | **no**, si se usa la coinbase; **sí**, si se exige depósito UTXO |
| Detección | prueba pública, incluible en un bloque | ídem, pero extendida a ramas |
| Efecto disuasorio | pequeño: lo dice la propia regla (`:109-111`) | igual o menor (la reclamación es una fracción de una coinbase) |
| Autoverificación del certificado | la tabla va comprometida (R-FIN-21), el certificado se verifica desde génesis | **se pierde**: el estado de reclamaciones hay que consultarlo |

**Qué pierde el quórum frente a F3 si adopta esto.** (1) La ventaja anunciada "sin dinero en juego"
desaparece; (2) "sin tabla de poder / sin registro" desaparece: el conjunto de reclamaciones es un
registro; (3) el certificado deja de ser autoverificable — el mismo defecto que d12 §G.3 usa para
descartar el quórum frente a F3 (`informe.md:691-703`); (4) hereda la debilidad reconocida de
R-FIN-19: castigo ex-post, ciego a partición, pequeño. En resumen: **si el quórum adopta dinero,
converge a F3 con más pasos y sin cliente ligero.** La capa estilo Filecoin ya tiene el mecanismo,
la tabla y el certificado autoverificable; no hay razón para reconstruirlo peor.

---

## 5 · Veredicto

| Punto | Qué se concluye | Etiqueta | Número/fuente |
|---|---|---|---|
| **1.1-1.2** | HotPoW ata el valor dentro del puzzle; PoAS solo en la firma | **DEMOSTRADO** | `hotpow.txt:492-497`; `sp-consensus-subspace/src/lib.rs:180-197`; `subspace-verification/src/lib.rs:211-260` |
| **1.3** | La equivocación libre baja la condición de ambigüedad de `2k` a `k` ATVs | **DEMOSTRADO** | `hotpow.txt:301-304`; `:305-312` |
| **1.4** | La aritmética de d12 §F.7 es correcta; control positivo reproducido | **VERIFICADO** | `k=64`: `1,272367e-12` vs `0,516624`; Bitcoin `0,2642411` |
| **1.5** | d12 cita mal la definición del voto de HotPoW | **VERIFICADO** | cita 437-441; correcto 492-497, 509-517, 548 |
| **(a)** nullifier | Restaura `2k` en cadena única; ciego a partición; deja el certificado con estado | PLAUSIBLE / **REFUTADO** como finalidad | `pallet-subspace:1613-1634`; `lewispye:740-741` |
| **(b)** quema + lista negra | Solo disuade al racional; recompensa maleable; prueba invisible en partición | PLAUSIBLE / **REFUTADO** prevención | `solutions.rs:254-275`; `capa-finalidad:109-111` |
| **(c)** castigo de espacio | La clave ata al plot (rotarla obliga a replotear), pero el castigo es ex-post y Sybil-fragmentable | **DEMOSTRADO** la atadura / **REFUTADO** prevención | `sectors.rs:54-68`; Chia `proof_of_space.py:359-364`; `capa-finalidad:47-50` |
| **(d)** voto = bloque | Restaura `2k` **gratis**, pero es profundidad de confirmación | **DEMOSTRADO** / **REFUTADO** como aportación | d12 `informe.md:129-153`; R-FIN-11 |
| **(e)** puzzle fresco | Restaura `2k` por construcción; cuesta un segundo recurso (PoW/VDF); **es HotPoW** | **DEMOSTRADO** / cuesta la premisa PoAS | `hotpow.txt:153-156, 492-497`; d12 §F.4/F.6 |
| **(f)** reto atado al valor | Reabre el grinding; amplifica el espacio efectivo | **REFUTADO** | `dag-nativo-poas-propuesta.md:72-74`; `dag-poas-inyeccion-auditoria.md:218` |
| **(g)** slashing | Restaura `2k` bajo supuesto económico; coste = dinero | **DEMOSTRADO** / coste = dinero | `bdk19:1496-1498`; R-FIN-19 |
| **(h)** Avalanche | No es el mismo `2k`; sin fuente local no se puede verificar su argumento | **LAGUNA** | `dag-consenso-poas.md:85-86` |
| **3** | Dilema estructural A-D; imposibilidad general | **DEMOSTRADO** / **PLAUSIBLE** | `lewispye:740-741, 754-756, 774-781` |
| **4** | Con dinero, el quórum converge a F3 y pierde autoverificación | **DEMOSTRADO** sobre las reglas | R-FIN-19/21; d12 §G.3 |

**Respuesta a la pregunta F0.** No existe una regla que restaure la Definición 1 **sin pagar uno de
los cuatro precios** (segundo recurso, registro global, castigo sobre activo escaso, o aceptar el
voto-bloque). El único precio no monetario que restaura `2k` de verdad es (e), un puzzle fresco por
voto — que es HotPoW, no PoAS. Si el proyecto mantiene la decisión PoW→PoAS, **la vía quórum de
P-043 se cierra como capa de finalidad sin dinero**: lo que quedaba vivo era la variante 2
(voto aparte), y su seguridad depende de una Definición 1 que PoAS no puede cumplir por construcción.

**Matiz de honestidad sobre el kill criterion de F0.** El encargo dice *«si ninguna variante restaura
`2k` sin dinero en juego, se declara teorema»*. En la letra, (e) lo hace: trabajo no es dinero. En el
espíritu, no: (e) reintroduce el segundo recurso que el cambio DECIDIDO a PoAS eliminó, y su coste
en hardware/energía/ASIC es el mismo que motivó descartar PoW. **Es una bifurcación real que Katana
debe ver:** cerrar P-043 (recomendado, por coherencia con la decisión PoW→PoAS) o aceptar HotPoW
sobre PoAS (variante e), con su coste completo.

---

## 6 · Errores propios y correcciones

1. **Corrijo cinco citas de d12**, todas del mismo tipo (la cita apunta a otra sección del paper):
   | d12 cita | Para qué | Correcto |
   |---|---|---|
   | `hotpow.txt:437-441` | definición del voto `(r,p,s)` | **492-497** (voto), **509-517** (quórum), **548** (línea 18) |
   | `hotpow.txt:200-208` | «k easier puzzles each expected to take 10/k minutes» | **153-156** |
   | `hotpow.txt:392-397` | POA de Bitcoin `0,2642` | **403-405** |
   | `hotpow.txt:1300-1303` | «axiomatic exclusion of the failure modes PoW-1 and PoW-2» | **1235-1237** |
   | `hotpow.txt:597-601` | Listing 4.6, línea 41 (regla de cabeza) | **601-609**, línea 41 en **608** |

   Las citas erróneas están en d12 `informe.md:619` (437-441), `:155` (200-208), `:34` (392-397),
   `:353` (1300-1303), `:143` (597-601) y `d12_b_composicion.py:91` (437-441). Ninguna conclusión de
   d12 cambia; las citas, sí.
2. **Primera estimación mía del coste del nullifier, corregida.** Escribí "estado ilimitado" y luego
   lo medí: acotado al horizonte `F = 2 h` son ~14,7 MB; sin podar, ~64,6 GB/año (aritmética propia
   sobre `λ_v = 64/s` y 32 B por identidad). El coste decisivo de (a) no es el estado: es que es
   **local a la rama**.
3. **No re-mido el `194 s` de d12 §B.b**; verifico que es `64/0,33 = 193,9 s` y cito el resultado de
   d12 como suyo (VERIFICADO por d12), no como mío.
4. **La comparación `1,3e-12 → 0,52` es de la métrica del paper en `t̄`**, no de la probabilidad de
   fallo del protocolo desplegado; d12 §B.5 ya lo advirtió (`informe.md:211-223`) y lo repito en
   §1.3 para que la cita no se lea como cota de despliegue.

## 7 · Lagunas

| # | Qué falta | Qué haría falta |
|---|---|---|
| 1 | Enunciado formal del teorema general de imposibilidad con equivocación | Un modelo tipo Lewis-Pye con dos objetos firmados por ATV; no existe en local |
| 2 | Argumento de seguridad de Avalanche bajo equivocación | El paper de Avalanche (Snowball/Snowman); el encargo F2 lo declara por traer |
| 3 | ¿Puede un plot de Autonomys producir dos soluciones válidas para el mismo slot con `piece_offset` distinto? | Lectura de `verify_solution` y del plotting; afecta a si el nullifier por identidad basta o hay que atarlo también al `piece_offset` |
| 4 | Coste real de una prueba de equivocación incluida en bloque | No medido: verificación de dos firmas + búsqueda de la reclamación; sin instrumento en local |
| 5 | `check_equivocation` de `sc-consensus-slots` (ventana de slots) | No leído; `dag-poas-auditoria.md:426-427` ya lo declara laguna |
