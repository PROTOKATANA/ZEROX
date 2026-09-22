# Hipótesis que codifican la conclusión — intento-v1

Este documento existe para que la conclusión del instrumento no quede escondida dentro de una
fórmula. Cada hipótesis lleva: **enunciado**, **estado** (`verificado en fuente`, `medido`,
`derivado`, `no determinado`) y **qué pasaría si fuese falsa**.

---

## H0 · Qué mide exactamente esta investigación

**[Verificado por construcción]** Lo que se mide es una **cota SUPERIOR** del coste del atacante.
El atacante puede tener mejor hardware y un kernel mejor que el de Autonomys: aquí se mide el
código de Autonomys tal cual, en la máquina de referencia, con su API pública. **Ninguna cifra de
este trabajo es el coste mínimo del ataque.**

**[Verificado por construcción]** Lo que se publica es una métrica **sin precios**. No hay ningún
resultado monetario y ningún parámetro de consenso fijado.

---

## H1 · La tabla no depende del reto; el reto solo elige el s-bucket

**[Verificado en fuente]** `ChiaV2TableGenerator::generate` → `Tables::<20>::create_proofs(seed)`
(`crates/subspace-proof-of-space/src/chia_v2.rs:28-36`); `find_proof(challenge_index)` →
`for_s_bucket(SBucket::from(challenge_index as u16))` (`chia_v2.rs:64-68`). El `s_bucket` sale de
los dos primeros bytes LE de `SectorId XOR global_challenge`
(`crates/subspace-core-primitives/src/sectors.rs:32-39,117-123`).

**Si fuese falso:** la amortización de una tabla sobre `w` retos no existiría y todo el encargo
sobraría. **No lo es**: es la línea exacta del código fijado.

---

## H2 · La unidad de aceptación es una pieza, no un sector

**[Verificado en fuente]** El verificador abre una prueba PoS, un chunk y su testigo KZG
(`crates/subspace-verification/src/lib.rs:228-270`); no exige el sector completo, ni su raíz, ni
una fecha de alta. Ya quedó demostrado en `P-SEMBRADOR/investigacion/INFORME.md`; aquí **no se
redescubre**, se usa.

---

## H3 · El test de «gana» se calcula sobre el chunk CRUDO y no necesita el testigo

**[Verificado en fuente]** El verificador hace `masked_chunk = chunk XOR proof.hash()` y evalúa
`calculate_solution_distance(global_challenge, chunk, sector_slot_challenge)`
(`crates/subspace-verification/src/lib.rs:245-254,118-146`); el plotter guarda
`encoded = raw_chunk XOR blake3(proof)` y **cero** donde no hay prueba
(`crates/subspace-farmer-components/src/plotting.rs:646-655`).

**Consecuencia.** Con el mapa de presencia (8 KiB) y el chunk crudo de la pieza (32 B) el atacante
sabe si hay candidato y con qué distancia. El testigo se necesita **solo si gana**.

**Si fuese falso** (si la distancia dependiera del testigo), M2 costaría una extracción de prueba
por acierto y el ganador no se distinguiría del resto. La lectura del código es inequívoca.

---

## H4 · La probabilidad por reto y tabla es `p = o · d(R_s)`

**[Verificado en fuente]** `is_within_solution_range` acepta si
`bidirectional_distance(g, a) <= R_s/2` (`crates/subspace-verification/src/lib.rs:148-159`), lo que
equivale a `2·floor(R_s/2)+1` valores aceptados de `a` sobre `2^64`. **[Hipótesis criptográfica]**
`a = blake3_keyed(sector_slot_challenge, raw_chunk)` se comporta como oráculo aleatorio; no se
demuestra aquí. Bajo esa hipótesis, `d(R_s) = (2·floor(R_s/2)+1)/2^64`.

**[Medido]** `o = 0,5` exacto: `create_proofs` deja **siempre** 32768 pruebas sobre 65536
s-buckets (`banco-rust/src/bin/distribucion.rs`, 32 semillas; `PRUEBAS_MIN = PRUEBAS_MAX = 32768`,
`O_MEDIDO = 0.500000`).

**[Medido, y matiza la hipótesis de uniformidad]** La densidad **no es uniforme**: es ≈ 0,587 por
bucket hasta el índice ≈ 53 000, cae en el tramo 53 000–58 410 y es **exactamente 0** por encima
de ≈ 58 410, porque `create_proofs` corta al alcanzar `NUM_CHUNKS` pruebas
(`shared/ab-proof-of-space/src/chiapos.rs:225-268`). Como el reto elige el bucket de forma
uniforme, la probabilidad **media** sigue siendo exactamente `o = 1/2`, que es lo que entra en el
modelo; pero `p` **no** es constante por bucket y los aciertos de una misma identidad están
correlacionados (se concentran en buckets bajos).

**Si la uniformidad estricta fuese necesaria**, habría que modelar la distribución conjunta de los
`w` buckets. Para la métrica `N_eq`, que es una esperanza sobre buckets uniformes, la media basta y
está medida, no supuesta.

---

## H5 · `N_eq = r·w·τ` compara peras con peras

**[Derivado]** Un granjero honesto con `N` piezas obtiene `N·p` candidatos por slot (cada sector
audita un s-bucket, y ese bucket contiene una entrada por pieza que tenga prueba allí; con densidad
media 1/2 el número esperado de chunks leídos por sector es `P/2`, y `S·P·o·d = N·p`). El sembrador
con `r` tablas/s y `w` retos conocidos obtiene `r·τ·w·p` candidatos por slot. Igualando,
`N_eq = r·w·τ`.

**[Hipótesis]** `π_DAG = 1` en la igualación anterior: se supone que todo candidato se convierte en
bloque pagado. **Eso favorece al atacante** y se declara. El modelo lleva `π_DAG` como entrada.

**[Hipótesis]** Los `w` retos de una misma identidad eligen buckets independientes y uniformes. Se
cumple salvo colisiones de bucket, cuya probabilidad es ≈ `w²/(2·65536)`: despreciable para
`w ≤ 10³`, ≈ 7,6 % de retos colisionados para `w = 10⁴`. **Si importase**, reduciría el número de
buckets distintos, no la media.

---

## H6 · El descuento de M2 es despreciable frente a M1

**[Medido]** El coste de cruzar una tabla ya generada con `w` retos está entre 0,39 ns (bucket
vacío, retorno temprano) y 2,02 µs (bucket alto con prueba), y el camino en lote con un `AND` de
1024 palabras es del orden de cientos de nanosegundos **independiente de `w`**. Frente a
`t_tabla ≈ 0,85 s` por núcleo, el descuento es < 1,5 % incluso con `w = 10⁴` y sin lote.

**Si fuese falso** (si `w·t_reto` fuese comparable a `t_tabla`), `r_efectiva(w)` se separaría de
`r` y la amortización tendría un techo. **No lo es en este rango**, y el instrumento publica
`r_efectiva(w)` junto a `N_eq` para que se vea.

---

## H7 · El atacante puede omitir parte del trabajo del plotter honesto

**[Verificado en fuente + medido]** El atacante no construye ni escribe el sector,
ni `SectorContentsMap`, ni el checksum de sector, ni extrae las 32 768 pruebas: solo necesita las
que caen en sus `w` buckets. Además, como conserva la pieza cruda, puede obtener el polinomio
fuente con `Kzg::poly` (≈ 1,3 ms) en vez de `ErasureCoding::recover_poly` sobre el registro
codificado (≈ 69 ms).

**[Cota medida de lo podable]** `t_create_proofs − t_create` acota lo que ahorraría una poda de la
extracción (no de la construcción de tablas). Se mide en `banco-rust/src/bin/cono.rs`.

---

## H8 · No se ha encontrado poda del cono de tablas

**[Verificado en fuente]** `create_proofs` construye las siete tablas incondicionalmente
(`shared/ab-proof-of-space/src/chiapos.rs:195-268`); `find_proof_raw_internal` recorre
table_7 → table_6 → … → table_2, y cada tabla se construye a partir de la anterior completa
(`table.rs:503-600,725-760`). No hay forma de obtener una entrada de la tabla `n` sin construir la
tabla `n−1` entera.

**Etiqueta obligatoria:** **«no se ha encontrado atajo»**, nunca «no existe».

---

## H9 · Validez de la comparación con los 83,6 s/GiB históricos

**[Medido]** El control se repite con el banco `plotting` del clon en esta máquina. La comparación
correcta es contra `generate_parallel` (que es lo que usa el plotter por registro), **no** contra
`generate` a un hilo. La diferencia entre las dos cifras se explica en el informe, no se supone.

**Si no fuese coherente en orden de magnitud**, habría que buscar la causa antes de publicar
`t_tabla`.

---

## H10 · Lo que este instrumento NO mide

- La anticipación real `w`. Es una **entrada**; su valor lo dará `P-ZRX/P-REVELACION/`.
- El coste de derivar los retos (salida del PoT). Fuera de alcance.
- `π_DAG`. Entrada.
- `N_h` y `α`. Entradas.
- La actividad de la red, los reintentos, la latencia de propagación y la competencia por el pago.
- Un kernel adversarial mejor que el de Autonomys. Por eso la cifra es **cota superior**.
