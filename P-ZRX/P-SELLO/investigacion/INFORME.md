**F3 · NO EXISTE, y no puede existir para un objeto determinista y público.** Si `Religar` cabe en el
presupuesto del honesto (`T_bajo ≤ W = (τ−Δ)/n_puntas < 1 s`), materializa a lo sumo `r·W` ≈ 6–19 MiB,
así que dos objetos de 1 TiB comparten ≥ 99,998 % de su espacio y no hay «espacio propio»; y si
materializa los ~`S` bytes que harían falta para que fueran objetos distintos, cuesta `S/r` =
11,637 h por TiB, entre 5,7·10⁴ y 1,7·10⁵ veces el presupuesto del honesto. No hay `T_bajo` que cumpla
las dos cosas a la vez. La simulación de `P-ZRX/P-COBERTURA/` §3 se aplica al par `(objeto, rama)` sin
cambiar una palabra. Y **no se ha encontrado** ninguna primitiva fuera de esa clase que lo haga: la vía
del secreto (iv) es **neutral entre las ramas del propio granjero** `[verificado en fuente]`.
**La vía (13) está muerta.**

# INFORME — P-SELLO · ¿Existe un sellado asimétrico: caro de crear, barato de re-ligar a una rama?

**Encargo:** `P-ZRX/P-SELLO/PROMPT.md`. **Instrumento:**
`P-ZRX/P-SELLO/investigacion/veritas/criptografia/sellado-rama-v1/` (categoría `criptografia`
—dominante: la propiedad de rivalidad es una propiedad del objeto y de la prueba—; secundarias
`consenso` y coste). **Julia 1.13.0**, CPU `znver5`, **4 hilos**. **Fecha:** 2026-09-23.

**Presupuesto declarado antes de ejecutar:** máximo **4 hilos**, **8 GiB de RAM**, **2 GiB de disco**
(incluye el depósito Julia propio; los artefactos de cálculo son < 10 MiB), **2 h de pared**. **No se
agotó** (≈ 1 min la corrida completa con JET). Comprobaciones de entrada y salida en `PROGRESO.md`.

**Zona de escritura respetada:** solo `P-ZRX/P-SELLO/investigacion/`. No se editó ni movió nada de
`SPEC.md`, `TAREAS.md`, `ci/`, `crates/`, `prototipos/`, `research/`, `veritas/`, `PDF/` ni del resto
de `P-ZRX/`. `PROMPT.md` y `ENTRADA.sha256` no se tocaron. **No se ejecutó `ab-proof-of-space` ni se
ploteó. Nada de Python.**

---

## 0 · Respuesta corta a las seis preguntas

| | Respuesta en una línea | Etiqueta |
|---|---|---|
| **F1** | La propiedad se formaliza; **«barato de re-ligar y aun así obligatorio de almacenar» es contradictorio** para un objeto determinista y público, porque lo barato de materializar es justo lo que se puede regenerar dentro del plazo. El único escape (secreto) es neutral entre ramas del dueño | `demostrado` + `verificado en fuente` |
| **F2** | La punta cambia a tasa **λ ≈ 1/s**, no «cada pocos segundos»; el honesto tiene **W = (τ−Δ)/n_puntas = 0,250–0,740 s**; debe atar **1,14–1,60** ramas si cubre todas las puntas. El presupuesto entero son **6,3–18,5 tablas** agregadas = **≤ 18,5 MiB** | `derivado` + `medido` (entradas) |
| **F3** | **No existe** para la clase determinista-pública (dicotomía espacio/presupuesto + simulación); **no se ha encontrado** ninguna primitiva fuera de esa clase. Las fuentes abiertas **no** dicen que Filecoin trate «minar varias ramas con el mismo almacenamiento» como problema abierto | `demostrado` + `no encontrado` |
| **F4** | Espacio extra `(k−1)·S`: **+14 % a +39 %** por atar las puntas típicas; CPU de re-ligadura hasta **74 %** del slot; la caducidad pseudoaleatoria **duplica** la frecuencia y exige replotear con el objeto ligado | `derivado` |
| **F5** | Sustituir todo el espacio tramposo `s` de `β_d` a `β_x` baja α* **exactamente `s/2`** (con `s=0,30`: **0,35 → 0,20**). El dispositivo solo no hace daño si `c_d ≤ c_x/2`; como lo que hace es subir `c_d`, **empuja a `β_x`** | `demostrado` (α*) + `derivado, condicionado a H-COSTE` |
| **F6** | **Vía muerta.** No hay cambio de `plotting.rs`/`sectors.rs`/`subspace-verification` que la salve sin que el honesto no pueda re-ligar; replotear la red costaría **235,65 h·núcleo/TiB** y no cerraría la rivalidad | `derivado` |

### 0.1 · Objeciones al encargo, declaradas antes de ejecutar (también en `PROGRESO.md`)

**O1 · El encargo sospecha que la propiedad puede ser contradictoria; lo es, y la razón es la de
`P-COBERTURA`, no una nueva.** Si `Religar` es determinista y público, el Teorema y el Corolario 4 de
`P-ZRX/P-COBERTURA/investigacion/INFORME.md` §3 se aplican al par `(objeto, rama')` tal cual: el
transcripto del que regenera es idéntico y todo predicado sobre el valor es invariante en el tiempo.

**O2 · El «intervalo entre cambios de punta» no es el único régimen, y el encargo no lo distingue.** El
objeto actual se liga a `history_size`, un **prefijo archivado**
(`subspace-core-primitives/src/sectors.rs:54-68`), no a la punta. Atar a un ancestro a profundidad `d`
**no reduce** la tasa de re-ligadura (el ancestro a profundidad `d` avanza con cada bloque que añade la
cadena seleccionada, así que cambia a tasa `λ` igual) y **empeora la rivalidad**: el prefijo atado lo
comparten todas las ramas que bifurcan a profundidad `≤ d`, y el atacante elige la bifurcación más
somera que le convenga. Con `d = 0` el prefijo es la punta y la primera rama privada **también** lo
comparte; la rivalidad solo aparecería a partir del bloque siguiente, cuando las dos ramas ya han
divergido. Es decir: **la profundidad no compra nada y lo único que decide es el coste de re-ligar
tras la divergencia**, que es lo que cuantifica F2. El instrumento publica las dos tasas
(`F2-profundo`).

**O3 · `α*` es espacio y `T_bajo` es tiempo; el puente no existe.** `α* = (1−β_d−2β_x)/2` es una
identidad de **espacio** (`P-PRESTAMO` F1) y `P-ZRX/PROPUESTAS-VIABLES.md` tiene el puente espacio →
tasa en **F0** («ninguna cifra de umbral del repositorio significa lo que dice»). F5 se da en dos
capas separadas y la parte de sustitución queda **condicionada a H-COSTE** con `c_d/c_x` como entrada.

**O4 · La premisa no tiene privilegio.** Si `T_bajo` suficiente para el honesto implica `T_bajo`
suficiente para el atacante, ésa es la refutación; va en la primera línea.

**O5 · Un VDF por rama no es rival** (aviso de `PROPUESTAS-VIABLES` fila 12): dos núcleos, dos ramas.
No se acredita como coste secuencial en el sentido del Corolario 2(ii).

---

## 1 · Alcance, método y entradas congeladas

**Qué es este informe.** Una **decisión estructural** (F1/F3) más un **modelo pequeño y exacto** que la
cuantifica (F2, F4, F5). No se mide hardware nuevo: `t_tabla`, `r`, `Piece::SIZE`, `τ`, `λ`, `Δ` y los
padres típicos son **entradas** etiquetadas. El instrumento es la parte computable: **76
comprobaciones exactas** (contra `Rational{BigInt}`), kernels con **0 asignaciones**, Monte Carlo con
dos RNG independientes y semillas no consecutivas.

**Modelo de amenaza.** El de Katana: un ente con mucha capacidad **atacará**; «no compensa
económicamente» no es argumento de seguridad. Todo se separa en **imposible** y **caro**, y el coste se
publica en hardware, no en moneda.

**Entradas (no se re-miden aquí).**

| Hecho | Valor | Etiqueta | Fuente |
|---|---|---|---|
| `t_tabla` | 809,13 ms/tabla/núcleo | medido | `P-ZRX/P-INTENTO/investigacion/INFORME.md` §5 (M1) |
| `r` | 25,027 tablas/s (24 hilos, forma C) | medido | íd. §5 |
| `N_TiB` | 1.048.480,0088 piezas | derivado | `Piece::SIZE = 1.048.672 B` (`pieces.rs:1226`) |
| `T_alto` (1 TiB) | 235,65 h·núcleo = 11,637 h de máquina | derivado | `N_TiB·t_tabla`, `N_TiB/r` |
| `τ`, `λ` | 1 s/slot, 1 bloque/s | verificado en fuente / entrada | `subspace-runtime/src/lib.rs:145`; `SPEC.md` §7.3 |
| `Δ` | 0,26–0,60 s (Δ_99 p99) | medido | `veritas/finalidad/delta-medido-v1/INFORME.md` §11.2 |
| `Δ̄` | 0,138–0,387 s | derivado | íd. §11.4 |
| padres típicos | 1,14–1,39 = `1 + λΔ̄` | derivado | íd. §11.4 |
| `S_max` | 150 s | nominal | `SPEC.md:2052` |
| objeto caro | tabla PoS de la pieza, 5,008 MiB | medido | `P-INTENTO` §2 (Precisión 1) |
| unidad de aceptación | **una pieza** | verificado en fuente | `subspace-verification/src/lib.rs:228-270`; `P-SEMBRADOR` §Fase 1 |
| ligadura actual | `SectorId = blake3_keyed(pk_hash; [sector_index, history_size])`; semilla `H(sector_id ‖ piece_offset)` | verificado en fuente | `sectors.rs:54-68,126-129`; `plotting.rs:626-627` |

---

## 2 · F1 · La propiedad formalizada, y si es coherente

### 2.1 · Formalización

- **`Sellar(datos, rama) → objeto`**, coste `T_alto`. En el formato fijado, `T_alto` = `N·t_tabla`; para
  1 TiB, **235,65 h·núcleo**.
- **`Religar(objeto, rama') → objeto'`**, coste `T_bajo`. Es la operación que el encargo supone barata.
- **Ventana** `W`: el tiempo que hay entre conocer la rama y tener que responder. Para el honesto,
  `W = (τ−Δ)/n_puntas` (§3). Para el atacante, la misma o menor (§3.4).
- **Requisito de rivalidad:** poseer `objeto` (rama `A`) **no** debe permitir producir peso pleno en
  `B` sin poseer `objeto'`, y `objeto'` debe ocupar **espacio propio**.

### 2.2 · La coherencia: «barato de re-ligar pero obligatorio de almacenar»

**Es contradictorio para la clase determinista-pública, y por dos vías que se refuerzan.**

**(a) Vía de simulación (`demostrado`, citando `P-COBERTURA` §3).** Si `objeto' = Religar(objeto, rama')`
es una función determinista y pública, entonces `objeto'` es función determinista y pública de
`(objeto, rama')`. Un adversario que posee `objeto` y conoce `rama'` ejecuta `Religar` y obtiene
`objeto'` **bit a bit**; no hay nada que la verificación pueda distinguir. Esto es el Teorema de
`P-COBERTURA` con `F' = Religar` y `(clave, i, historia)` sustituido por `(objeto, rama')`. **No usa
ninguna suposición de dureza.**

**(b) Vía de espacio (`demostrado`, aritmética de este instrumento).** Sea `δ` la parte de `objeto'` que
hay que **materializar** de nuevo (los bytes que no comparte con `objeto`). El espacio **propio** de
`objeto'` es `δ`; la fracción independiente es `δ/S`. Para que dos objetos de tamaño `S` sean objetos
distintos, `δ` tiene que ser del orden de `S`. Pero materializar `δ` cuesta `δ/r`, y para caber en la
ventana hace falta `δ ≤ r·W`. Con `W = 0,250–0,740 s` y `r = 25,027 tablas/s`, **`δ ≤ 6,3–18,5 MiB`**.
Entonces:

| Objeto `S` | `δ_max/S` | `T(δ=S)` | `T(δ=S)/W` |
|---|---:|---:|---:|
| 1 GiB | 0,98 %–1,81 % | 40,92 s | **55×–102×** |
| 1 TiB | 5,97·10⁻⁶–1,77·10⁻⁵ | 41.893,96 s = 11,637 h | **5,66·10⁴×–1,68·10⁵×** |
| 1 PiB | 9,3·10⁻⁹–1,7·10⁻⁸ | 11.916,5 h | 5,80·10⁷×–1,07·10⁸× |

`[derivado]` (`resultados/F2-materializacion.tsv`). **Ni siquiera un objeto de 1 GiB se puede re-ligar
dentro del slot**: la operación más barata del ploteo (`t_tabla` = 809 ms/núcleo, 39,96 ms agregados)
es del orden del presupuesto **entero** del honesto.

**(c) La única salida es el secreto, y el secreto es del dueño (`verificado en fuente`).** Si `Religar`
usa aleatoriedad secreta, la simulación (a) no aplica. Pero la vía (iv) de `P-COBERTURA` es una semilla
**del granjero**: sirve para que **un tercero** no regenere, no para que el dueño no regenere **su**
otra rama. Damgård–Ganesh–Orlandi lo formulan exactamente así: el encoding probabilístico hace que el
**servidor** (tercero) no pueda recomputar, porque «the adversary will only see the encoded data but
not the randomness that the client used» `[verificado en fuente]`
(`evidencia-fuentes/pdfs/repstorage.txt:234-240`). Y SpaceMint dice de su nonce secreto: «The nonce
just ensures that the same space cannot be used for two different proofs [14]; thus in a
**single-verifier setting, P can generate the nonce**» `[verificado en fuente]`
(`pdfs/spacemint.txt:422-423`); en una sola cadena el nonce es del prover y **no separa sus ramas**.

**Conclusión de F1.** «`T_bajo` barato **y** obligatorio almacenar» no es una propiedad difícil: es
**vacía** para objetos deterministas y públicos, y **neutral entre ramas** para el único escape
conocido. La asimetría útil que el encargo buscaba —entre operaciones y entre ramas— **no puede
construirse con este tipo de objeto**.

---

## 3 · F2 · El presupuesto temporal del honesto

### 3.1 · ¿Con qué frecuencia cambia la punta? (`derivado`, H-TIPS)

Con `λ ≈ 1 bloque/s` y `Δ = 0,26–0,60 s`, la punta seleccionada avanza a tasa **λ = 1/s**: el honesto
tiene que re-ligar **como máximo una vez por slot**. La formulación «cada pocos segundos» del encargo
es **optimista**: el número es **≤ 1 s**. El número de puntas concurrentes (y de padres medios) es
`1 + λΔ`:

| `Δ̄` [s] | padres = puntas = `1+λΔ̄` | Monte Carlo `StableRNG` | Monte Carlo `Philox4x` | desv. |
|---:|---:|---:|---:|---:|
| 0,138 | 1,138 | 1,1305 | 1,1287 | −0,7 % |
| 0,200 | 1,200 | 1,1846 | 1,1807 | −1,3 % |
| 0,300 | 1,300 | 1,2664 | 1,2627 | −2,6 % |
| 0,387 | 1,387 | 1,3313 | 1,3283 | −4,0 % |

`[derivado + medido por el instrumento]` (`F2-mc-puntas.tsv`, 48 réplicas × 3000 s por celda, dos RNG
independientes que coinciden entre sí dentro del 0,3 %). La desviación negativa crece con `Δ` porque el
modelo funde puntas; **no cambia ninguna conclusión** (la tasa de re-ligadura es `λ`, no `1+λΔ`). El
número de puntas concurrentes **sí** entra en el reparto del presupuesto.

### 3.2 · El presupuesto `W` y su comparación con la operación más barata del ploteo

`W = (τ − Δ)/n_puntas`. Con `n_puntas = 1` (solo la punta seleccionada) y con
`n_puntas = 1 + λΔ` (todas las puntas):

| `Δ` [s] | `n_puntas` | `W` [s] | tasa [1/s] | tablas que caben en `W` | fracción de 1 TiB | `T`(1 TiB)/`W` |
|---:|---:|---:|---:|---:|---:|---:|
| 0,26 | 1 | **0,740** | 1,00 | **18,52** | 1,77·10⁻⁵ | 5,66·10⁴ |
| 0,26 | 1,26 | 0,587 | 1,26 | 14,70 | 1,40·10⁻⁵ | 7,13·10⁴ |
| 0,35 | 1,35 | 0,481 | 1,35 | 12,05 | 1,15·10⁻⁵ | 8,70·10⁴ |
| 0,45 | 1,45 | 0,379 | 1,45 | 9,49 | 9,05·10⁻⁶ | 1,10·10⁵ |
| 0,60 | 1,60 | 0,250 | 1,60 | 6,26 | 5,97·10⁻⁶ | 1,68·10⁵ |

`[derivado]` (`F2-religadura.tsv`). **Comparación pedida por el encargo:** la operación más barata del
ploteo es **una tabla** — 809,13 ms de un núcleo, **39,96 ms agregados** con `r = 25,027`. El
presupuesto entero del honesto (**250–740 ms**) son **6,3–18,5 tablas agregadas**, o sea **≤ 18,5 MiB**
de objeto materializado. **`T_bajo` MUST ser ≤ eso.**

### 3.3 · ¿Cuántas ramas tiene que mantener ligadas el honesto?

Si solo ata la punta seleccionada, **1**. Si quiere no perder producción mientras se resuelven las
bifurcaciones, tiene que atar todas las puntas: **1,14–1,60**. El atacante necesita **2** (pública +
privada). La relación de espacio atacante/honesto es `2/1,26 ≈ 1,59` — **una asimetría de un factor
1,6, no un cierre**. Y atar un prefijo más profundo **no baja la tasa y además regala la primera
bifurcación** (O2): el atacante abre su rama privada en la punta, comparte el objeto, y solo necesita
un segundo objeto cuando las ramas ya han divergido. La defensa no puede ganar por profundidad; lo
único que decide es el coste de re-ligar tras la divergencia.

### 3.4 · El reverso, que decide

Si `T_bajo` es tan pequeño que el honesto llega, **el atacante también llega para cada una de sus
ramas** — y su ventana es **la misma o mayor**: la rama pública la conoce cuando la conoce el honesto,
y la privada la conoce **antes** (la produce él). El coste del doble farmeo es `2·T_bajo`, no
`2·T_alto`. Y `2·T_bajo ≤ 2·W ≤ 1,48 s` **no fuerza dos objetos**: `δ ≤ r·2W ≤ 37 MiB`, todavía
1,7·10⁻⁵ de un TiB. **`T_bajo` suficiente para el honesto implica `T_bajo` suficiente para el
atacante.** Ésa es la refutación.

---

## 4 · F3 · ¿Existe la construcción? Fuentes abiertas

**No existe, y no se ha encontrado ninguna primitiva fuera de la clase refutada.** Todo lo que sigue
se abrió; lo que no se pudo abrir va marcado. El detalle con citas literales está en
`investigacion/EVIDENCIA-P1-P4-FUENTES-ABIERTAS.md` y la evidencia cruda en
`investigacion/evidencia-fuentes/`.

### 4.1 · Filecoin PoRep / SDR — lo que la fuente dice y lo que no

**Sí existe actualización sin re-sellar entero:** **FIP-0019 «Snap Deals»**, método
`Miner.ProveReplicaUpdates`. `[verificado en fuente]` `evidencia-fuentes/fip-0019.md:19`: *"A
one-message protocol for updating any sector with new data without re-sealing."*; `:109`: *"The
Encoding function is cheap and allows for parallel encoding."* **Pero** el propio FIP lista como
trabajo futuro `:289` *"Update protocol that does not require to perform an operation on a full
sector"*, y FIP-0017 `:115` lo dice explícito: *"Note that it requires re-encoding the entire sector
with the new randomness."* **No hay cifra relativa de coste** en FIP-0019/0017/0041/0059/0082/0090/0092/0106
`[no verificado]`. Y **no re-liga a otra rama**: opera sobre el `SectorKey` del sellado original del
sector CC (`fip-0019.md:192`).

**La atadura a la cadena que el encargo pide verificar es real, pero es a la ÉPOCA, no a la rama.**
`[verificado en fuente]` — abierto por mí en
`https://raw.githubusercontent.com/filecoin-project/specs/master/content/systems/filecoin_mining/sector/sealing.md`:

> línea 41: *"Tickets are used as input to calculation of the ReplicaID in order to tie
> Proofs-of-Replication to a given chain, thereby preventing **long-range attacks** (from another
> miner in the future trying to reuse SEALs)."*

> línea 81: *"…an attacker **going back a month in time** to try and create their own chain would have
> to completely regenerate any and all sectors drawing randomness since to use for their fork's
> power."*

Y `algorithms/pos/porep.md:14`: *"The PoRep proof ties together: i) the data itself, ii) the miner
actor … iii) the time when the specific data has been sealed … Time is included as the blockchain
height when sealing took place and the corresponding chain reference is called `SealRandomness`."*
`[verificado en fuente]`.

**Lo que la fuente NO dice, y hay que decirlo:** no se ha encontrado en las fuentes abiertas una
afirmación de que Filecoin identifique «minar varias ramas con el mismo almacenamiento» como problema
abierto ni una regla que lo prohíba. Lo que hay es **prevención de ataques de largo alcance**. Y la
distinción es estructural, no semántica: el ticket se toma de un bloque **finalizado** en la ronda
`X−F` y proviene del beacon/VRF, que **es el mismo para todas las ramas a la misma altura**. Dos ramas
que bifurcan en la punta (menos de `F` de profundidad) comparten ticket, `SealRandomness` y por tanto
`ReplicaID` y sector sellado. **El sellado de Filecoin no distingue ramas coetáneas.** `[derivado de
la fuente abierta]`

**La persistencia es económica, no criptográfica.** `[verificado en fuente]`
`algorithms/pos/post.md:17`: *"makes it irrational for a miner to not keep a sealed copy of the data
(i.e., it is more expensive to seal a copy of the data every time they are asked to submit a
WindowPoSt challenge)"*; el mecanismo es `fault` + slashing del pledge (`post.md:49`,
`storage_mining/_index.md:58-60`). La frase literal «económica y no criptográfica» **no aparece**
`[no verificado]`, pero la garantía es de incentivos.

### 4.2 · Cifrado actualizable (UE) e IVC — no dan lo que hace falta

**UE** (BLMR, eprint 2015/220 §7.3; Boyd et al., CRYPTO 2020): la primitiva **sí** separa crear de
actualizar, pero en el sentido equivocado. `[verificado en fuente]`
`pdfs/ue-crypto2020.txt:13-15`: *"ciphertext generation consists of applying one permutation and one
exponentiation (per message block), while updating ciphertexts requires just one exponentiation."*
Actualizar cuesta **el mismo orden que cifrar un bloque**, el objeto almacenado sigue siendo el
ciphertext, y la actualización la autoriza un **token del cliente** (BLMR: la clave de re-cifrado; Boyd:
*"The token allows the server to update the ciphertexts"*). No hay un objeto caro de crear que se
re-liga. **Verificar la actualización no está definido** en UE (`[no encontrado]`).

**IVC** (Nova, eprint 2021/370): prueba `O(|F|)`, verificación `Oλ(|F|)` `[verificado en fuente]`
(`pdfs/nova.txt:163`). La prueba ata el prefijo `z_i = F^(i)(z_0)` y **no hay operación para re-ligar
un objeto ya computado a otra historia** `[no encontrado]`.
`[no verificado]` el cuerpo de las versiones comprimidas más allá de lo citado.

**PDP dinámico** (Erway–Küpçü–Papamanthou–Tamassia, eprint 2008/432): «update» = insertar/borrar
bloques del fichero; no cambia la ligadura de rama `[verificado en fuente]` (`pdfs/dynpdp.txt`).

### 4.3 · La vía (iv) — semilla secreta — no liga a la rama

`ReplicaID = SHA254(ProverID ‖ SectorID ‖ R_ReplicaID ‖ CommD ‖ PoRepID)` `[verificado en fuente]`
(`evidencia-fuentes/algorithms_sdr_index.md:908,932-940`). `R_ReplicaID` es *"a unique random value"*
del minero (`algorithms/sdr/notation.md`), **neutral entre sus ramas**; `PoRepID`/ticket es público y
ata a la **época** (y solo contra reescrituras profundas, §4.1).

**Propuestas con identificador de cadena:** Tang et al., arXiv:1907.07896 (SecureComm 2019),
`[verificado en fuente]` — *"`id` is an identifier to assure that the prover P cannot reuse the same
disk space to run PoC for different statement"* (`pdfs/multichain-pos.txt:139`). Es **entre cadenas**,
no entre ramas de la misma cadena. SpaceMint (eprint 2015/528) usa el nonce para que el mismo espacio
no sirva a **dos pruebas distintas**, pero admite que en un solo verificador el nonce lo genera el
prover. Subspace liga la semilla a `history_size` — un **prefijo**, con la misma limitación que el
formato fijado. **No se ha encontrado** ninguna construcción de proof-of-space con semilla secreta
**atada a la rama**.

### 4.4 · ¿Re-sellado incremental / re-ligadura barata?

**No se ha encontrado** literatura ni especificación que permita cambiar la ligadura de una réplica a
otra historia/rama pagando menos que un sellado completo. Búsquedas documentadas en
`EVIDENCIA-P1-P4-FUENTES-ABIERTAS.md`: «updatable proof of storage», «incremental SNARK storage»,
«proof of replication update», «re-bind chain», «updatable PoReP». **«No se ha encontrado» no es «no
puede existir»**: lo que **sí** puede afirmarse es la dicotomía de §2.2, que es una demostración sobre
la clase determinista-pública, no una búsqueda fallida.

---

## 5 · F4 · Qué le cuesta al honesto

`[derivado]` (`F4-honesto.tsv`).

| `k` ramas atadas | espacio extra | sobre 1 TiB | coste de plotear lo extra (máquina) | CPU de re-ligadura |
|---:|---:|---:|---:|---:|
| 1,00 | 0 % | 0 | 0 | hasta 74 % |
| 1,14 | +14 % | +0,14 TiB | +1,63 h | hasta 74 % |
| 1,26 | +26 % | +0,26 TiB | +3,03 h | hasta 74 % |
| 1,39 | +39 % | +0,39 TiB | +4,54 h | hasta 74 % |
| 2,00 | +100 % | +1,00 TiB | +11,64 h | hasta 74 % |

- **Espacio:** atar las puntas típicas cuesta **+14 % a +39 %** de disco, y ese disco hay que
  **plotearlo** (0,14–0,39 TiB = 33–92 h·núcleo). El atacante paga 2 objetos por cada rama pública;
  **el honesto ya paga ~1,26**. La defensa es un factor ~1,6, no una barrera.
- **CPU:** si `T_bajo` se lleva al límite, el honesto dedica **`(τ−Δ)/τ = 40 %–74 %`** del slot a
  re-ligar, es decir, hasta tres cuartas partes de su capacidad de generar tablas. **Es el precio de
  un `T_bajo` grande**; con `T_bajo` pequeño, ese precio desaparece — y con él la rivalidad (§2.2).
- **Expiración pseudoaleatoria (ya existente):** `expires_in = blake3(sector_id ‖ segment_commitment)
  mod (min + 4h − check)` (`sectors.rs:141-156`) supone que el sector se **replotear** de forma
  determinista desde `(public_key, sector_index, history_size)`. Un objeto ligado a la rama **rompe esa
  reproducibilidad**: la caducidad obligaría a re-ligar de nuevo (duplicando la frecuencia) y el
  reploteo deja de poder hacerse sin el estado de la rama. `[derivado]`
- **Lo que el honesto no puede comprar:** el tiempo. `W < 1 s` es del protocolo, no del hardware.

---

## 6 · F5 · El efecto `β_d → β_x`, con números

`[demostrado para α*; derivado, condicionado a H-COSTE, para la sustitución]`
(`F5-alfa-sustitucion.tsv`). Superficie de `P-PRESTAMO` F1, verificada en `Rational{BigInt}` con
`g(α*) = 0` exacto en las 36 celdas publicadas:

```text
α*(β_d, β_x, η_h, η_a) = (η_h − η_a·β_d − (η_h+η_a)·β_x) / (η_h+η_a)
```

**El reparto importa el doble de lo que parece.** Para un espacio tramposo total `s`:

| `s` | todo en `β_d` | todo en `β_x` | gap = `s/2` |
|---:|---:|---:|---:|
| 0,10 | 0,45 | 0,40 | **0,05** |
| 0,20 | 0,40 | 0,30 | **0,10** |
| 0,30 | 0,35 | 0,20 | **0,15** |
| 0,40 | 0,30 | 0,10 | **0,20** |

**El dispositivo empuja al atacante al lado peor.** Un sellado que encarezca `β_d` sube `c_d` y deja
`c_x` igual. El daño por unidad de coste es `(1/2)/c_d` para `β_d` y `1/c_x` para `β_x`; el atacante
prefiere `β_x` en cuanto **`c_d > c_x/2`** (`[demostrado]` como comparación aritmética exacta; la
regla coincide con la comparación directa en las 7 razones publicadas). Es decir:

- **margen sin daño:** `c_d ≤ c_x/2`, esto es, el dispositivo no puede **más que duplicar** la ventaja
  de coste de `β_d` respecto de `β_x` sin provocar la sustitución;
- **si se pasa**, el atacante abandona `β_d` del todo y α* cae a `0,5 − s`. Con `s = 0,30`:
  **0,35 → 0,20**: el efecto perverso vale **0,15 de α***, la mitad de todo el espacio tramposo.

**Caveat declarado (O3):** `α*` es espacio y `c_d`, `c_x` son costes; el instrumento **no fija** ni
`c_d` ni `c_x` ni convierte núcleos en fracciones de disco. La parte de α* es aritmética exacta; la
sustitución es cualitativa en su dirección y depende de H-COSTE.

---

## 7 · F6 · Veredicto y qué cambiaría del formato

### 7.1 · Veredicto

**Vía muerta.** No es «vía condicionada a una primitiva que no existe» en el sentido de «espérese a que
llegue»: es **imposible para la clase determinista-pública** (§2.2a/b) y **neutral** para el único
escape conocido (§2.2c). Las tres razones, en orden de fuerza:

1. **Dicotomía espacio/presupuesto** (`demostrado`): `δ ≤ r·W` (6–19 MiB) para que el honesto llegue,
   frente a `δ ≈ S` (1 TiB) para que haya espacio propio. **5,7·10⁴–1,7·10⁵×** de separación.
2. **Simulación** (`demostrado`, `P-COBERTURA` §3): con `Religar` público no hay transcripto que
   distinga almacenado de regenerado.
3. **Búsqueda abierta** (`no encontrado`): ninguna primitiva conocida lo hace; la semilla secreta es
   neutral entre ramas del dueño `[verificado en fuente]`.

### 7.2 · Qué habría que cambiar del formato, y su coste

Aunque no salvaría la vía, el cambio que el encargo pide identificar es:

- `subspace-farmer-components/src/plotting.rs:626-627` — la semilla (`generate_parallel(pos_seed)`)
  tendría que incluir la rama; y `:659-665` el enmascarado.
- `subspace-core-primitives/src/sectors.rs:54-68,126-129` — `SectorId` / `derive_evaluation_seed`
  tendrían que incluir un compromiso de ancestría.
- `subspace-verification/src/lib.rs:228-270` — una verificación nueva de esa ligadura (hoy el
  verificador enmascara él el chunk, `:248-249`, y no ve la forma almacenada).

**Coste de replotear la red:** **235,65 h·núcleo/TiB** (11,64 h de máquina por TiB), o **83,608 s/GiB**
de la medición histórica a 32 hilos. Y como el objeto tendría que re-ligarse por rama, el coste por
rama sería del mismo orden: **inviable dentro del slot**. `[derivado]`

### 7.3 · Lo que sí se puede y no se puede afirmar

- **No se puede** afirmar «existe una construcción que obliga a dos objetos»: §2.2 la refuta.
- **No se puede** afirmar «no puede existir ninguna primitiva»: lo demostrado es para la clase
  determinista-pública. Para el resto, el resultado es **«no se ha encontrado»**.
- **Sí se puede** afirmar que el sellado estático de Filecoin (el mejor desplegado) **no distingue
  ramas coetáneas**: ata a la época/ticket, compartido por las ramas a la misma altura.

---

## 8 · Verificación y rendimiento

### 8.1 · Controles de corrección (test/runtests.jl)

**76 comprobaciones, todas en verde**, con `--check-bounds=yes`. Vías independientes:

| vía | qué es | contra qué se contrasta |
|---|---|---|
| `α*` forma cerrada | identidad de `P-PRESTAMO` | residuo exacto `g(α*)=0`, orientación del signo a los dos lados, y **bisección racional de 200 iteraciones** que no usa la forma cerrada |
| gap `s/2` | aritmética exacta | `g=0` en los dos extremos y diferencia de raíces |
| umbral `c_d = c_x/2` | comparación de daños por coste | comparación directa de los dos racionales y ventaja marginal |
| modelo de punta | `1+λΔ` | Monte Carlo de eventos con **dos RNG** (`StableRNG` y `Philox4x`) y semillas no consecutivas |
| kernels `Float64` | `kernel_presupuesto!`, `kernel_alfa!`, `kernel_materializacion!` | oráculo `Rational{BigInt}` y **0 asignaciones** |
| ancestría | dos hijos del mismo padre | enumeración explícita sobre 200 DAGs aleatorios |

**Cómo se ha evitado el test tautológico** (encargo §4): ninguna comprobación contrasta una fórmula
consigo misma. `α*` se localiza por bisección independiente y **además** se comprueba el residuo exacto
y el signo a los dos lados; el umbral se contrasta con la comparación directa de daños; el modelo de
punta se contrasta con una simulación de eventos de mecánica distinta y con dos generadores
independientes; los kernels se contrastan con el oráculo exacto.

### 8.2 · Tabla de rendimiento (LINEO §6)

`resultados/BENCH.txt`. **Carga ajena ~2,3 con 4 hilos ⇒ «medido con carga ajena».**

| Variante | Tiempo mínimo | Asignaciones | Memoria | Hilos |
|---|---:|---:|---:|---:|
| `kernel_presupuesto!` (257 celdas) | **227,5 µs** | **0** | **0 B** | 4 |
| `kernel_alfa!` (257 celdas) | **24,1 µs** | **0** | **0 B** | 4 |
| `kernel_materializacion!` (257 celdas) | **48,7 µs** | **0** | **0 B** | 4 |
| `mc_puntas_una` (H=2000, 1 réplica) | **1,211 ms** | 3.758 | 455 KB | 1 |
| `alpha_estrella_exacta` (`Rational{BigInt}`) | **711 ns** | 78 | 2,8 KB | 1 |
| `biseccion_raiz` (64 iteraciones, oráculo) | **57,9 µs** | 5.547 | 190 KB | 1 |

**Los kernels calientes tienen 0 asignaciones.** El Monte Carlo **sí** asigna (3.758 por réplica,
arrays temporales de `t`, `r` y del orden de eventos); **no es el cuello**: 48 réplicas × 4 celdas
cuestan < 0,3 s y se declara en vez de esconderse. `@code_warntype`/JET: **0 posibles errores**
(`resultados/JET.txt`). Sin `@fastmath`, sin `@simd`, sin `Float32`; `@inbounds` en los tres kernels
tras los tests de rango, con `--check-bounds=yes` en el perfil de referencia.

---

## 9 · Lo que esta investigación NO resuelve

- **Las reglas del DAG.** El modelo de punta (H-TIPS) es una **entrada de escenario**; `SPEC.md` sigue
  en preparación y las reglas de padres no están cableadas. Si el honesto pudiera producir sobre
  puntas viejas sin perder producción, `W` sería mayor y F2 habría que rehacerlo — pero **la
  rivalidad seguiría cayéndose** por §2.2.
- **`c_d`, `c_x` y el puente espacio → tasa.** No existen (`PROPUESTAS-VIABLES` fila 5, F0). F5 queda
  condicionado a H-COSTE; el instrumento **no fija** ninguna razón de costes.
- **El coste mínimo real del atacante.** `r = 25,027` es el mejor agregado medido del código de
  Autonomys tal cual, **cota superior** del coste del atacante; SIMD/GPU/ASIC no medidos. Una `r`
  mayor **empeora** la dicotomía del honesto, no la mejora.
- **Las cifras de coste de Filecoin SnapDeals.** Solo hay descripción cualitativa; **no verificado**
  ningún ratio update/sellado.
- **El cuerpo de UE, IVC y de la formalización de PoRep.** Se citan de sus textos primarios extraídos;
  no se re-demostró nada de ellos.
- **La viabilidad de una prueba sucinta de cobertura** para este formato: `P-COBERTURA` la declara
  construible en ingeniería; aquí se cita, no se construye.
- **`π_DAG`, `F`, `M`, `ρ_ret`, `T_v` y los parámetros de consenso:** entradas, no fijadas.
- **La migración real.** Nada de esto está implementado en `crates/`; es un modelo.

---

## 10 · Reproducción

```bash
cd /home/katana/zeo/ZEROX
LC_ALL=C sha256sum -c P-ZRX/P-SELLO/ENTRADA.sha256
git -C /home/katana/zeo/ZEROX status --short
cd P-ZRX/P-SELLO/investigacion/veritas/criptografia/sellado-rama-v1
./correr-modelo.sh          # tests + barridos + MC + benchmarks + JET  (≈ 1 min, 4 hilos)
```

**Semilla maestra:** `0x5E110A1A` (no consecutivas por `splitmix64`, test dedicado). **Artefactos:**
`resultados/F2-religadura.tsv`, `F2-materializacion` (dentro del anterior), `F2-mc-puntas.tsv`,
`F4-honesto.tsv`, `F5-alfa-sustitucion.tsv`, `certificado.tsv`, `VALIDACION.txt`, `BENCH.txt`,
`JET.txt`, `TEST.txt`, `RUN.txt`. **Hipótesis falsables:**
`HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md`. **Bitácora y huellas:** `PROGRESO.md`. **Bifurcaciones:**
`DECISIONES-PENDIENTES.md`.
