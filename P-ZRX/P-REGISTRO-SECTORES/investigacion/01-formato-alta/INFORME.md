# INFORME — ORDEN-S01 (Encargo 01 de sectores: G1)

**Executor:** DeepSeek Harness, modelo `deepseek-flash`, esfuerzo `high`. **Fecha:** 2026-09-26.
**Zona:** `/home/katana/zeo/ZEROX/deepseek/S01/`. **Investigación aislada:** nada entra en el
workspace ni en el consenso.

**Veredicto G1 (`ANALISIS.md` §5): SUPERADA, en el alcance exacto de §7.** Una solución PoAS real
verificada por el verificador del clon abre el mismo objeto comprometido por R2, con coste medido;
los 15 negativos del modelo de amenaza se rechazan. La separación de §7 se mantiene: R2 demuestra
**pertenencia de la pieza al objeto comprometido**, no la corrección del ploteo, ni preexistencia,
ni permanencia, ni ausencia de doble uso entre ramas.

---

## 1. Faltas de definición e incidencias detectadas

Antes de escribir código se comprobaron las entradas de ORDEN-S01 §3 y se encontraron los puntos que
la orden deja abiertos o resuelve por una vía que no existe en la raíz. **Ninguno bloqueó la
ejecución; todos se resolvieron como la propia orden autoriza y se declaran aquí.** El punto 3
(integridad) se detectó en la comprobación de `ENTRADA-S01.sha256`; el resto, en la lectura previa.

1. **`zx_core::hash` no es reutilizable y `CBID_RED_DEV` no existe.**
   - `crates/zx-core/src/hash.rs` declara `h_d` y `DomainTag` como `pub(crate)` **a propósito**; no
     hay función pública de hash con dominio. La orden permitía «reimplementa `H_d` en 3 líneas»:
     se hizo (`prototipo/src/h_d.rs`), con `sha3 = "=0.12.0"`, la misma versión que pinea `zx-core`.
   - No existe `CBID_RED_DEV` en `zx-core`: solo un `CONSENSUS_BRANCH_ID` que se pasa como argumento
     y el valor de test `0xc478_80ea` de `zx-core`/`zx-consensus`. Se declara
     `CBID_PRUEBA = 0xc478_80ea`, explícitamente **no** un parámetro de red (orden: «si no, un valor
     fijo de prueba declarado»).

2. **Regiones exactas de `SectorContentsMap` y de metadatos.** La orden pide hashear «bytes del
   `SectorContentsMap`» y «bytes de la región de metadatos de registros» sin fijar los cortes. Se
   fijan en `ESPECIFICACION-BYTES.md` §1/§5 como los tramos **tal cual se almacenan** en el archivo
   del plotter: `mapa` = `8192·p + 32` B (incluye el BLAKE3 interno del mapa) y `meta` =
   `p · (48+48+32)` B de `RecordMetadata` SCALE. El resto del archivo (checksum de sector de 32 B,
   `.meta` del plotter y `piece_indexes`) queda **fuera** de R2 y se enumera allí.

3. **Integridad de la entrada congelada: `D-ZRX/RFT-ZRX.md` cambió durante la sesión.**
   `ENTRADA-S01.sha256` exige `86f57b80…`, pero el archivo es `7999481c…` (15 844 B). La causa es
   una escritura concurrente externa: el commit `49e4434` («T02 … RFT-13», 01:38:36) modificó el
   archivo **después** de congelarse la entrada (01:35:00). El diff `HEAD~1..HEAD` **solo añade
   RFT-13** (21 líneas) y **no toca RFT-03, RFT-04 ni RFT-06**, las filas usadas por S01; el hash
   esperado corresponde a `HEAD~1`. Las demás cinco entradas verifican. Se reporta por si el
   director quiere regenerar `ENTRADA-S01.sha256`; no se tocó el archivo.

4. **`max_pieces_in_sector` (decisión propia, declarada).** Los parámetros de plot del fixture son
   `max_pieces_in_sector = 2`. Para medir «al menos tres `pieces_in_sector`» (§6) es imposible
   mantener ese tope; se fija `max_pieces_in_sector = pieces_in_sector` para 2, 3 y 4. Es un
   parámetro de **test**, declarado en `ESPECIFICACION-BYTES.md` §8; no un valor de red.

---

## 2. Qué se reconstruyó y qué se volvió a verificar

**Hecho comprobado en fuente por esta sesión** (clon `f8842d0` en la zona, no el original):

- El verificador real calcula `masked_chunk = chunk XOR proof_of_space.hash()`
  (`subspace-verification/src/lib.rs:248-249`): el chunk de disco es el enmascarado y el verificador
  lo reconstruye desde el chunk sin enmascarar de la solución + el hash de la prueba de espacio.
  Confirmado.
- El orden físico de la región de chunks es s-bucket ascendente y, dentro de cada uno,
  `iter_s_bucket_records` (pieza ascendente); `chunk_location` es la posición global
  (`subspace-farmer-components/src/sector.rs:436-470,521-552`). Confirmado, y es el orden de hojas
  de R2.
- Cada registro aporta exactamente `NUM_CHUNKS = 2^15` chunks usados; `NUM_S_BUCKETS = 2^16`; por
  tanto `n = pieces_in_sector · NUM_CHUNKS` (`sector.rs:582-608`, `pieces.rs:559-570`).
- El mapa se codifica con bitfields Lsb0 de 8192 B por pieza más un BLAKE3 de 32 B
  (`sector.rs:174,176,362-364`).
- El objeto es determinista y público: `SectorId` de la clave/índice/historia (`sectors.rs:56-68`),
  semilla PoS por `(sector_id, piece_offset)` (`:126-129`) y encoding por registro con
  `generate_parallel` (`plotting.rs:616-667`), paralelizado por registro
  (`plotting.rs:384-417`).
- `D-ZRX/RFT-ZRX.md` RFT-03 (un compromiso de valor no fecha nada), RFT-04 (auditar no distingue
  guardado de regenerado en el formato PoAS) y RFT-06 (el sellado ligado a la rama no existe para un
  objeto determinista y público). Releídos íntegros.

**Volcado histórico** (`P-COBERTURA` §§2–3,7 y `P-SEMBRADOR` fase 1) releído: ya concluía que un
compromiso del objeto completo es construible hoy, que no aporta preexistencia, y que la única vía
de cambiar la naturaleza del objeto es romper su determinismo público o su paralelizabilidad.

---

## 3. Matriz variante × propiedad demostrada × coste honesto × evidencia

| Variante | Propiedad demostrada | No demuestra | Coste honesto medido | Evidencia |
|---|---|---|---|---|
| **R0** · sin registro | nada | todo | 0 B; 0 s de compromiso; 0 s de verificación | línea base |
| **R1** · identidad y fecha | identidad de lote `(clave, índice, historia)` + slot de alta; contabilidad | preexistencia (RFT-03) | **32 B**; una SHA3-256 (< 1 µs) | `prototipo/src/r2.rs` `compromiso_r1`; `resultados/resumen-P*.tsv` |
| **R2** · compromiso exacto del sector completo + apertura | la solución ganadora **pertenece** al objeto comprometido: misma clave, índice, `history_size`, versión, mapa, metadatos, cardinalidad y **chunk almacenado** en la posición abierta; un alta repetida o caducada se rechaza | que el objeto sea un ploteo correcto; preexistencia; permanencia; doble uso entre ramas | **32 B** de compromiso; **32–60 ms** construir R2 tras plotear 2–4 MiB; apertura **617–649 B**; **4,5–4,7 µs** verificar la apertura (mediana de 1000) — frente a **1,23–1,25 ms** del verificador PoAS real de la misma solución | §5–§7; `resultados/` |
| **R3** · codificación completa ligada a aleatoriedad posterior | **no implementada** | — | — | razón técnica en §4; RFT-04; `P-COBERTURA` §3 Cor. 1–4 |

### Ataques del modelo de amenaza (§5) y su rechazo

Los 15 negativos se ejecutan en el prototipo y **los 15 se rechazan con el error previsto**
(`resultados/negativos-P*.tsv`).

| Ataque | Error observado |
|---|---|
| solución de otra clave | `ClaveDistinta` |
| solución de otro `sector_index` | `SectorDistinto` |
| solución de otro `history_size` | `HistoriaDistinta` |
| otra versión de formato | `R2NoCoincide` |
| otro `CBID` (dominio/rama) | `R2NoCoincide` |
| hoja con otro `piece_offset` | `PieceOffsetDistinto` |
| hoja con otro `s_bucket` | `SBucketDistinto` |
| `codificado = 0` | `CodificadoNoUno(0)` |
| camino de otra posición | `CaminoNoCoincide` |
| camino de otra hoja (hermano mutado) | `CaminoNoCoincide` |
| R2 de un **segundo sector real** ploteado (índice distinto) | `R2NoCoincide` |
| raíz ajena (misma identidad, `raiz_chunks` distinta) | `R2NoCoincide` |
| `digest_mapa` ajeno | `R2NoCoincide` |
| alta duplicada | `ErrorRegistro::Duplicado` |
| alta caducada | `ErrorRegistro::Caducado` |

---

## 4. Razón de R3 (por qué exige cambiar el formato o el circuito)

R3 pide una prueba de codificación completa ligada a aleatoriedad **posterior** al precompromiso.
Sobre el formato PoAS actual **no se puede construir sin cambiar el objeto o el circuito**, por la
misma razón que RFT-04: el objeto es determinista, público y paralelizable por unidad.

1. **Determinista y público.** `O_i = F(clave, i, historia)` con `F` fijado por
   `SectorId::new` (`sectors.rs:56-68`) y `derive_evaluation_seed` (`:126-129`); el chunk
   enmascarado se produce sin aleatoriedad adicional (`plotting.rs:659-665`,
   `raw_chunk XOR proof.hash()`). Cualquiera recalcula los mismos bytes.
2. **Paralelizable por unidad.** `encode_records` reparte registros entre tareas rayon
   independientes (`plotting.rs:384-417`) y cada `record_encoding` llama a
   `generate_parallel(pos_seed)` (`plotting.rs:627`). No hay profundidad secuencial que un banco de
   núcleos no reduzca.
3. **Simulación exacta dentro de la ventana.** Por (1)+(2), para un reto conocido con `w` slots de
   antelación y plazo `D_a`, un simulador materializa exactamente las unidades que la prueba abre y
   reproduce el transcripto honesto **bit a bit**; si `M_min·t_unidad ≤ R·(w·τ + D_a)`, ningún
   verificador sucinto distingue «guardado» de «regenerado». Es un argumento de información, no de
   dureza (`P-COBERTURA` §3.1–3.2, Cor. 1).
4. **Un compromiso no lo arregla.** Toda raíz Merkle sobre los bytes es un predicado sobre el
   **valor** del objeto, invariante en el tiempo: es consistente con haberlo computado en cualquier
   instante (`P-COBERTURA` Cor. 4; RFT-03). Ni siquiera la PoRep de Filecoin da preexistencia: da
   una **cota inferior** de tiempo (cómputo después de la aleatoriedad), no anterior
   (`fuentes-filecoin/INFORME.md` §2 y §8).
5. **Las salidas cambian el objeto, no la prueba.** Corolarios 2–3 de `P-COBERTURA` §3: latencia
   (i), profundidad secuencial (ii) y materialización simultánea (iii) son desigualdades sobre `R`,
   `w`, `D_a` y `t_unidad` que un adversario con capacidad suficiente satisface; solo **(iv) romper
   la publicidad/determinismo** cambia la naturaleza del objeto. Es decir: o se introduce una semilla
   secreta en lo ploteado, o un sellado secuencial tipo PoRep (y su circuito de verificación), lo
   que pertenece a `ENCARGO-04/05` y no a R2/S01. Por eso R3 se entrega como **no implementada con
   razón técnica**, y no como un `Ok` ficticio.

---

## 5. Prototipo, oráculo y verificación

- **`prototipo/`** (crate independiente, `rust-toolchain.toml = nightly-2026-05-03`, dependencias
  de Autonomys por ruta al clon de la zona, `Cargo.lock` propio de 174 paquetes). Funciones:
  `plotear`, `compromiso_r1`, `compromiso_r2`, `apertura`, `verificar_apertura` y `RegistroSectores`
  (abstracto en memoria: alta, duplicado y caducidad por slot).
- **Verificador real.** La solución ganadora se verifica con
  `subspace_verification::verify_solution::<ChiaTable,_>` **antes** de abrirla contra R2. Positivos:
  apertura válida de 3 soluciones en **3 slots distintos** por cada tamaño (5, 5 y 8 soluciones
  verificadas en total; `resultados/positivos-P*.tsv`).
- **Oráculo Julia independiente** (`oraculo-r2/`, sin Python): recalcula `raiz_chunks`, `R2`,
  `digest_mapa` y `digest_meta` desde el volcado binario del sector, con su propia decodificación
  del mapa y su propio Merkle. **Coincide byte a byte con Rust en los tres tamaños**
  (`resultados/ORACULO-CHECK.tsv`): 12/12 comparaciones.
- **Pruebas.** `cargo test`: 6/6 (H_d, Merkle, R1, versión de R2, registro). `julia test/runtests.jl`:
  5/5 (vector NIST de SHA3-256, separación de dominio y Merkle).

---

## 6. Medición

Comando (desde `deepseek/S01/`), con `RAYON_NUM_THREADS=8`:

```bash
./target/release/s01 <pieces_in_sector> 128 resultados
```

Hardware AMD Ryzen 9 9950X3D (16C/32T), 123 GiB, un solo nodo NUMA; carga media 2–5 durante las
corridas; Rust `1.97.0-nightly (20de910db)`, Julia `1.13.0`; detalle en `ENTORNO.txt`. No es
benchmark de producción (LINEO §7).

### 6.1 Tabla por tamaño (medianas de 3 corridas; verificación de apertura, mediana de 1000)

| `pieces` | bytes sector | hojas `n` | `t_plot` (s) | `t_R2` (s) | RAM pico (MiB) | R1 (B) | R2 (B) | apertura (B) | verif. apertura (µs) | verif. PoAS real (ms) |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 2 | 2 113 856 | 65 536 | 0,447 | 0,0316 | 519 | 32 | 32 | 617 | 4,47 | 1,249 |
| 3 | 3 170 752 | 98 304 | 0,669 | 0,0530 | 518 | 32 | 32 | 649 | 4,66 | 1,246 |
| 4 | 4 227 648 | 131 072 | 0,866 | 0,0599 | 518 | 32 | 32 | 649 | 4,58 | 1,225 |

- `t_plot`: el ploteo real (lo paga el granjero de todas formas); `t_R2`: la pasada extra de
  lectura + hojas + Merkle que pide el registro. **R2 añade ≈ 7 %** del ploteo en P2 y **≈ 7–8 %** en
  P3/P4. La construcción de la historia archivada del fixture (`t_entorno ≈ 3,3 s`, una sola vez por
  proceso) **no** forma parte de `t_plot` ni del coste por sector.
- RAM pico de proceso ≈ 519 MiB, dominada por la historia archivada (≈ 130 MiB), KZG y el erasure
  coding del fixture; el árbol Merkle específico de R2 es `≈ 2·n·32 B` (4–8 MiB). **No es un coste
  por sector de producción.**
- El verificador PoAS real tarda ~1,25 ms; la apertura añade **~4,6 µs (0,4 %)**: el vínculo con el
  registro es barato frente a la verificación que ya se paga.
- Extrapolación **indicativa, no de producción**: `t_R2/bytes` ≈ 14–15 s/GiB ⇒ **≈ 4,3–4,6 h/TiB**
  en un solo hilo de hashing (la ruta de S01 es serial; el prototipo no la optimiza porque el
  presupuesto y el objeto de S01 no lo piden). No se publica como coste de red.

### 6.2 Comparación con R0

| | R0 | R1 | R2 |
|---|---:|---:|---:|
| bytes de estado por sector | 0 | 32 | 32 |
| coste de cómputo de alta | 0 | < 1 µs | 32–60 ms tras plotear |
| bytes de prueba por apertura | 0 | 0 | 617–649 |
| coste de verificación | 0 | 0 | 4,6 µs + 1,23–1,25 ms de PoAS ya existente |

R0 no acredita ninguna capacidad; R1 solo contabilidad; R2 liga la solución al objeto comprometido
con un sobrecoste de verificación del **0,4 %** sobre la verificación PoAS existente.

---

## 7. Qué demuestra R2 y qué NO (separación obligatoria de §7)

**Demuestra.** Fijado el compromiso R2 de un sector, toda solución ganadora verificada por el
verificador real que se abra contra él pertenece al **mismo objeto**: misma clave, índice,
`history_size`, versión, dominio (`CBID`), mapa, metadatos, cardinalidad y, en la posición abierta,
**el mismo chunk almacenado** (`chunk XOR proof_of_space.hash()`, `lib.rs:248-249`). La apertura
enlaza la pieza con el árbol de las `n` hojas y recompone R2; ningún camino de otra posición u otra
raíz pasa. R2 es, con la terminología del encargo, **cobertura del objeto completo** (raíz de los
bytes almacenados + cardinalidad + identidad + versión), no cobertura de una sola pieza.

**No demuestra (y no debe leerse como que lo hace):**

1. **Que el objeto sea un ploteo correcto.** R2 compromete los bytes que se le den; que hayan salido
   del plotter (con su estructura de s-buckets, PoS y KZG) no se verifica al abrir. Solo lo
   impediría una R3 con prueba de cómputo; hoy no existe.
2. **Preexistencia.** Un compromiso de valor es consistente con haber computado el objeto en
   cualquier instante (RFT-03). Que R2 se calcule «después de plotear» es el orden del protocolo,
   no una cota temporal verificable.
3. **Permanencia.** Una apertura demuestra pertenencia en el instante de la prueba, no que los bytes
   siguieran en disco antes ni después (RFT-04). La apertura de S01 ni siquiera lee el disco: el
   verificador reconstruye el chunk desde la solución.
4. **Ausencia de doble uso entre ramas.** Un objeto determinista y público sirve en dos ramas que
   compartan el mismo prefijo; R2 no liga el objeto a una rama (RFT-06).
5. **Que la apertura cubra el sector entero.** La raíz cubre las `n` hojas, pero el trabajo de
   producirla es O(n) hashes no verificados; la apertura de una hoja no reabre las demás. Lo que se
   acredita es la pertenencia al objeto comprometido, y R2 se calculó sobre la lectura completa del
   sector tras plotear (medido).

También quedan fuera del alcance de S01 (declarado): la selección DAG, la elegibilidad, la
recompensa, la caducidad de consenso y el ataque del sembrador (encargos 02–05).

---

## 8. Gastos, incidencias y trazabilidad

- **Presupuesto:** 3 h de reloj, 8 hilos, 32 GiB, 60 GiB. **Consumo real de la fase de cálculo:**
  ~2 min de reloj (ploteo + búsqueda + negativos + 1000 verificaciones); el trabajo total de la
  sesión, incluida lectura de fuentes, redacción y compilación, no agotó el presupuesto. Sin
  tensión de RAM ni disco (disco S01 ≈ 2,2 GiB: `target` + `.cargo-home` + clon + dumps).
- **Prohibiciones respetadas:** sin Python; nada escrito fuera de `deepseek/S01/`; sin `git commit`
  ni `push`; sin secretos; ningún `Ok` ficticio; el clon de Autonomys está intacto
  (`git status --porcelain` vacío).
- **Incidencias:** la única relevante es el cambio concurrente de `D-ZRX/RFT-ZRX.md` (§1.3), ajeno a
  esta sesión.

---

## 9. Reproducción

```bash
cd /home/katana/zeo/ZEROX/deepseek/S01
export CARGO_HOME=$PWD/.cargo-home CARGO_TARGET_DIR=$PWD/target CARGO_BUILD_JOBS=8 RAYON_NUM_THREADS=8
(cd prototipo && cargo build --offline --release)
(cd prototipo && cargo test --offline)

./target/release/s01 2 128 resultados
./target/release/s01 3 128 resultados
./target/release/s01 4 128 resultados

export PATH=/home/katana/torio/.juliaup/bin:$PATH
(cd oraculo-r2 && env -u LD_LIBRARY_PATH julia --project=. test/runtests.jl)
(cd oraculo-r2 && env -u LD_LIBRARY_PATH julia --project=. run.jl ../resultados/sector-P2.dump)
(cd oraculo-r2 && env -u LD_LIBRARY_PATH julia --project=. run.jl ../resultados/sector-P3.dump)
(cd oraculo-r2 && env -u LD_LIBRARY_PATH julia --project=. run.jl ../resultados/sector-P4.dump)
```

Artefactos crudos en `resultados/`: `resumen-P{2,3,4}.tsv`, `positivos-P*.tsv`,
`negativos-P*.tsv`, `sector-P*.dump`, `ORACULO-CHECK.tsv`, `REPETICIONES.tsv`, `RESULTADOS.tsv`.
Logs en `logs/`. Especificación en `ESPECIFICACION-BYTES.md`; método en `METODO.md`; tiempos en
`HORAS.log`.

---

## 10. Cierre

**G1: SUPERADA** con el alcance de §7. La pregunta falsable «¿puede una solución PoAS real demostrar
pertenencia al mismo sector completo que se comprometió, con coste admisible de alta y
verificación?» se responde **sí**: la apertura verifica contra R2 con **32 B de compromiso, 617–649 B
de apertura y 4,6 µs** (0,4 % sobre la verificación PoAS existente), y los 15 negativos del modelo
de amenaza se rechazan. La parte «antes de ser elegible» no es una propiedad de bytes y R2 no la
acredita: eso sigue siendo contabilidad de orden (R1 + regla DAG), preexistencia (RFT-03),
permanencia (RFT-04) o doble uso entre ramas (RFT-06), todas fuera del alcance de S01.
