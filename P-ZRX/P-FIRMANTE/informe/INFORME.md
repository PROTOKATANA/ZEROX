# INFORME — P-FIRMANTE: el firmante seguro

**El firmante seguro es implementable y su coste medido en el camino crítico de producción es de
~0,81 ms por bloque en el disco de esta máquina (btrfs sobre `/dev/mapper/cr_root`, NVMe), es decir
el 0,099 % del slot de 1 s en el p99 y el 0,29 % en el peor caso de 2 000 mediciones.** No toca el
consenso, no fija ningún parámetro y no es un mecanismo de seguridad: es un **filtro de accidentes
honestos**, y esa frase no es un adorno — marca exactamente qué problemas resuelve y cuáles no.

Todo lo que sigue está etiquetado: `demostrado por test`, `medido`, `derivado`, `propuesto` o
`no determinado`. El prototipo vive en `P-ZRX/P-FIRMANTE/prototipo/`; las instrucciones del encargo
están en `P-ZRX/P-FIRMANTE/PROMPT.md` y la especificación congelada en
`P-ZRX/P-FIRMANTE/ESPECIFICACION.md`.

---

## 1 · Qué se ha construido

Un crate Rust propio, `firmante-seguro`, en `P-ZRX/P-FIRMANTE/prototipo/`, que **depende por ruta**
de `crates/zx-core` (no reimplementa ni el `pre_hash`, ni la firma, ni la identidad de la cabecera).
Tres piezas:

| Módulo | Qué hace | Etiqueta |
|---|---|---|
| `src/identidad.rs` | Qué identifica una oportunidad. Punto de extensión con la definición vigente (`C-GD-07`/R-FIN-11) por defecto y una segunda implementación (IDV-01, con dominio de red) | `demostrado por test` |
| `src/registro.rs` | Dónde se persiste `(identidad, slot) -> pre_hash`: fichero solo-anexar, `fsync` **antes** de devolver, bloqueo de fichero entre procesos, recuperación con truncado de cola y fallo cerrado ante corrupción | `demostrado por test` + `medido` |
| `src/firmante.rs` | La política de `ESPECIFICACION.md` §3.1, literal: decidir → persistir → **y solo entonces** sellar | `demostrado por test` |

Y un ejemplo de medición, `examples/medir_coste.rs`, que mide el camino real de producción (hash de
la prefirma + firma Ed25519 + escritura + `fsync`) contra el disco.

**Lo que no se ha hecho, y hay que decirlo:** no existe ninguna ruta de producción de bloques en el
repositorio. Se comprobó: `pre_hash` solo aparece en `crates/zx-core` (`grep -rn "pre_hash" crates/`
fuera de `zx-core` no devuelve nada) y `crates/zx-node/src/` no tiene productor. Así que este
prototipo **no está integrado en ningún nodo**, no se ha podido medir con carga real de producción,
y su punto de enganche hay que definirlo (ver `informe/INTEGRACION.md`). `no determinado`.

---

## 2 · La regla, y por qué el orden de las operaciones es el contrato

De `ESPECIFICACION.md` §3.1, literal:

```text
Antes de emitir el sello de un bloque B:
  1. Calcular su identidad de oportunidad TicketId(B).
  2. Consultar el registro persistente por la clave (TicketId(B), slot(B)).
  3. Si NO hay entrada: escribir (TicketId, slot) -> pre_hash(B) de forma ATÓMICA y DURADERA
     (fsync del fichero o commit de la transacción) y sólo entonces firmar.
  4. Si hay entrada con el MISMO pre_hash: firmar (es el mismo bloque; puede reemitirse).
  5. Si hay entrada con OTRO pre_hash: NO firmar. Descartar el candidato.
```

`Firmante::firmar` no tiene **ninguna ruta** que escriba el sello antes de que el registro devuelva
`Ok`. El sello es `Ed25519(sk, pre_hash(B))` —el mensaje es el `pre_hash`, no la prefirma ni el
`block_hash`; ver `DagBlockHeader::pre_hash` y `verificar_sello` en
`crates/zx-core/src/preimage/dag.rs`— y se escribe en `header.sello` únicamente en el camino de
éxito. Un candidato descartado sale de `firmar` con el sello que tuviera y el `Resultado` dice cuál
es el desenlace. `demostrado por test`.

### 2.1 · La identidad: el punto que decide si sirve de algo

`ESPECIFICACION.md` §3.4.5: indexar por `pre_hash` o por `block_hash` **no protege nada**, porque
los dos `pre_hash` de un accidente son distintos por construcción. La clave es la **identidad de
oportunidad**, y el índice del registro es `SHA3-256(dominio ‖ versión ‖ campos)`:

- `IdentidadTicket::TicketVigente` — `(public_key, sector_index, history_size, chunk, slot)`, que es
  `C-GD-07`/R-FIN-11 (`SPEC.md` §11). Es la implementación **por defecto**.
- `IdentidadTicket::TicketConRed` — la misma tupla más 32 bytes de dominio de red/era (IDV-01,
  `P-ZRX/P-EQUIVOCACION/investigacion/DEFINICION-PROPUESTA.md` §3), que cierra FP8 de
  `ESPECIFICACION.md`.

Las dos **no comparten espacio de claves** (`demostrado por test`), porque el dominio forma parte de
la preimagen de la huella. Añadir una tercera definición es añadir una variante al `enum`, y el
registro no cambia. `propuesto` como forma de mantener el trabajo vivo hasta que Katana decida.

El `chunk` de la identidad es `sol.chunk` de la cabecera (`SolucionPoas::chunk`, 32 B) y el `slot` es
`header.slot`. La clave del registro guarda **también** el slot, aparte de la huella: es redundante
si la identidad ya lo incluye, pero `ESPECIFICACION.md` §3.1 manda la clave `(TicketId(B), slot(B))`
y si una definición futura dejara de incluir el slot, la clave seguiría siendo la que el encargo
pide. Coste: 8 bytes por entrada. `derivado`.

### 2.2 · `S_max_slots`: parámetro, no constante

`S_max_slots` entra como **parámetro** en `Registro::abrir` y `Firmante::nuevo`. El prototipo trae
`S_MAX_SLOTS_NOMINAL = 150` con su procedencia escrita: `SPEC.md` §7.3 («`S_max = 150 s`
nominales») y `crates/zx-core/src/wire_dag.rs` (`MAX_BUNDLES_POT`, §11 línea 40 del archivo) y
`crates/zx-consensus/src/ghostdag.rs` (`S_MAX_POR_DEFECTO`). **No se ha fijado nada**: el valor de
producción es el del perfil vigente, y el encargo §8 prohíbe que este prototipo lo decida.

La abstención tras perder el registro es exactamente `S_max_slots` (`ESPECIFICACION.md` §3.2):

```text
se firma de nuevo en cuanto  slot_actual > max_slot_del_registro_perdido + S_max_slots
```

Implementado en `Estado::abstencion_hasta`, con `max_slot` = mayor slot jamás escrito en el fichero
(se persiste en la cabecera y también por entrada). `demostrado por test`.

---

## 3 · Qué demuestra cada test

La suite: **17 tests unitarios + 10 de contrato**, en total 27 ejecutados y 3 puntos de entrada de
proceso hijo marcados `#[ignore]` (no son tests normales; ver §3.3). Se ejecutó 40 veces seguidas con
8 hilos sin un solo fallo (`0 / 40`), y los tests unitarios y de contrato pasan también con
`--test-threads=1`.

| Punto del encargo §3 | Test | Qué demuestra |
|---|---|---|
| **1. Caso 5** | `caso_5_con_entrada_previa_y_otro_pre_hash_no_firma` (contrato) y `firmante::tests::caso_5_…` | Con entrada previa y otro `pre_hash`, no firma: el candidato sale **sin sello** (`sello == [0u8; 64]`) y el resultado es `AbstenidoPorConflicto { pre_hash_registrado }`. `demostrado por test` |
| **2. Caso 4** | `caso_4_reemitir_el_mismo_bloque_funciona` (contrato y unidad) | Tras reabrir el registro desde disco, el **mismo** bloque se vuelve a sellar y el sello es idéntico (Ed25519 es determinista), y `verificar_sello()` verifica. `demostrado por test` |
| **3. Durabilidad real** | `durabilidad_el_proceso_muere_entre_la_escritura_y_la_firma` + `control_negativo_sin_escritura_el_conflicto_no_se_detecta` | Ver §3.3 |
| **4. Abstención exacta** | `la_abstencion_tras_perder_el_registro_dura_exactamente_s_max_slots` | Con registro perdido en el slot 1 000: los 150 slots siguientes (1 001…1 150) se rechazan con `EnAbstinencia` y **ninguno** lleva sello; el 1 151 sella. La abstención no compra nada de más. `demostrado por test` |
| **5a. Concurrencia entre hilos** | `concurrencia_dos_hilos_no_firman_los_dos` | Ocho hilos con la misma oportunidad y ocho `pre_hash` distintos: **exactamente uno** sella, siete se abstienen, y solo una cabecera acaba con sello. `demostrado por test` |
| **5b. Dos procesos** | `dos_procesos_sobre_el_mismo_fichero_no_se_pisan` | Ver §3.4 |
| **6. Identidad extensible** | `la_identidad_funciona_con_dos_implementaciones` (contrato y unidad) | La misma tupla bajo la vigente y bajo IDV-01: cada implementación sella su primera aparición y se abstiene ante su propio conflicto, sin mezclarse. `demostrado por test` |

Además, tres tests de las piezas internas:

- `registro::tests::entrada_nueva_conocida_y_conflicto`, `sobrevive_a_reabrir`,
  `un_registro_creado_por_abrir_no_firma_antes_de_s_max`, `la_poda_tira_lo_que_ya_no_puede_colisionar`
  — el registro.
- `registro::tests::una_cola_a_ceros_se_trunca` y `bytes_alterados_en_medio_fallan_cerrado` — la
  recuperación: una **cola a ceros** (escritura que no terminó) se trunca; **bytes alterados en
  medio** con entradas posteriores no vacías fallan cerrado con `Corrupto`. La distinción no es
  cosmética: truncar corrupción en medio perdería entradas posteriores, y olvidar una entrada es la
  única forma de doble-firmar. `demostrado por test`.
- `identidad::tests::*` — la huella cambia con cada campo, el dominio separa implementaciones y
  versiones, y el slot va en la clave. `demostrado por test`.
- `el_descriptor_del_registro_no_sobrevive_a_un_exec` y
  `el_ciclo_abrir_cerrar_reabrir_no_deja_el_cerrojo_vivo` — ver §3.4.1.

### 3.3 · Cómo se prueba la durabilidad (el punto 3, el único que se hace mal por defecto)

**Mecanismo: proceso hijo que se suicida con `SIGABRT` en el punto exacto.** El test padre lanza
`std::env::current_exe()` —el propio binario de test— con `--ignored --exact hijo_persiste_y_aborta`
y la variable `FIRMANTE_PUNTO_DE_ABORTO` puesta. El hijo abre el registro con
`Registro::nueva`, llama a `Registro::resolver` (que escribe y hace `fsync` por el camino real, sin
atajos) y llama a `std::process::abort()`. `abort()` **no** ejecuta destructores, **no** vacía
búferes de biblioteca y **no** sincroniza nada: si la entrada está al reiniciar, es porque el `fsync`
ya había ocurrido. El padre comprueba que el hijo murió por señal (`SIGABRT`), no con salida limpia.

Después, al reiniciar, el test no se conforma con que el fichero exista: comprueba **qué decide el
firmante**:

- el mismo bloque B se **reemite** (`Resultado::Reemitido`), y
- un candidato C con **otro** `pre_hash` y la misma oportunidad se **abstiene**
  (`Resultado::AbstenidoPorConflicto`) y sale sin sello.

**Y hay un control negativo**: exactamente el mismo montaje con el hijo abortando **sin** escribir
(`FIRMANTE_PUNTO_DE_ABORTO=sin-persistir`). En ese caso el registro queda con 0 entradas y el mismo
candidato C **sí sella**. Es lo que demuestra que el primer test no pasa por el mero hecho de
reiniciar: mide la durabilidad, no la reapertura. `demostrado por test`.

### 3.4 · Concurrencia, y qué NO cubre

**Entre hilos:** el registro lleva un `Mutex`; la secuencia mirar-decidir-escribir-`fsync` es
atómica respecto de la clave. `demostrado por test` con 8 hilos.

**Entre procesos:** el registro toma `flock(LOCK_EX)` sobre su descriptor y lo mantiene mientras el
`Registro` vive. Un segundo proceso sobre el mismo fichero acaba con `RegistroError::Bloqueado`. El
test lo monta con un hijo que abre primero, un `flock` directo del padre mantenido 2,5 s, y un
control positivo posterior (liberado el cerrojo, el mismo hijo abre). `demostrado por test`.

**Lo que esto NO cubre, y va sin suavizar** (ver también §5):

1. **Dos procesos, cada uno con su propio registro**: nada los coordina. Dos nodos sobre la misma
   parcela con dos ficheros distintos producen exactamente la evidencia de FP1. El registro solo
   sirve si es **común**, y eso no está especificado hoy (`ESPECIFICACION.md` §3.4.1).
2. **Un registro en red** (NFS, SMB, un volumen compartido): el `fsync` de un sistema de ficheros en
   red no garantiza lo mismo que el de uno local y puede ser diferido o mentir. **No medido aquí.**
   Un registro compartido que mienta al sincronizar **anula la garantía entera**.
3. **Un copiador**: dos procesos podrían copiar el fichero y trabajar en paralelo. El `flock` no lo
   impide.
4. **Un atacante que borre el registro** o use otro binario: nada lo impide. Es la definición de
   «filtro de accidentes, no mecanismo de seguridad».

**Punto 5b bis — una cosa que sí se descubrió y arregló.** El descriptor del registro lleva el
`flock`, y `flock` vive en la *open file description*: si el descriptor sobrevive a un `fork`, el
hijo comparte el cerrojo y **el padre no puede reabrir su propio registro** aunque lo haya cerrado.
Se reprodujo en ~1–4 de cada 10 pasadas de la suite (fallo intermitente de `caso_4` con
`Bloqueado` sobre un fichero recién cerrado). Se arregló en dos pasos, y los dos están:

- **`O_CLOEXEC` en el propio `open(2)`** (`abrir_sin_herederos`, apertura por `libc::open`).
  Pasar `O_CLOEXEC` por `OpenOptions::custom_flags` **no bastó** en esta máquina: el descriptor
  acababa con `flags: 02100002` (`O_RDWR|O_LARGEFILE`) y el fallo seguía.
- **Reintento acotado en la toma del cerrojo** (50 µs a 20 ms durante 2 s). Entre el `fork` y el
  `exec` el cerrojo lo sostiene el hijo: es un **titular transitorio**, no un segundo escritor. Un
  segundo escritor real no lo suelta, así que al agotar el plazo la respuesta sigue siendo
  `Bloqueado`. El reintento no abre ninguna puerta a dos escritores: el cerrojo se sigue tomando
  antes de leer o escribir.

`demostrado por test` (40 pasadas consecutivas sin fallo después del arreglo) y `medido` (el fallo
antes). Efecto lateral declarado: si un segundo proceso mantiene el cerrojo, este `Registro::abrir`
tarda 2 s en fallar en vez de fallar al instante.

---

## 4 · Mediciones (encargo §4)

**Máquina de referencia**: AMD Ryzen 9 9950X3D (16 núcleos), Linux, btrfs sobre
`/dev/mapper/cr_root` con `ssd,space_cache=v2`. `uptime` y `loadavg` anotados antes y después de
cada corrida (están en `informe/PROGRESO.md`). Toolchain: `rustc 1.97.0-nightly (20de910db
2026-05-02)`, perfil `release` (opt-level 3, LTO). Comando exacto:

```bash
cd P-ZRX/P-FIRMANTE/prototipo
CARGO_TARGET_DIR=... cargo run --release --locked --offline --example medir_coste -- 2000 target/mediciones
```

| Variante | mediana | media | p99 | máx |
|---|---|---|---|---|
| **A · el camino real**: `resolver` + `fsync` + sello Ed25519 | **807,7 µs** | 820,1 µs | 988,7 µs | 2 894,1 µs |
| B · `write` sin sincronizar (cota inferior) | 1,8 µs | 1,9 µs | 2,4 µs | 21,5 µs |
| C · `write` + `fdatasync` | 397,9 µs | 403,5 µs | 505,9 µs | 676,3 µs |

`medido`, 2 000 muestras tras 200 de calentamiento de JIT/caché.

**Lectura:**

- El `fsync` cuesta **~806 µs de mediana** (A − B) y es **el 98 %** del coste añadido del camino de
  producción. El resto (hash de la prefirma + firma Ed25519) está por debajo de 2 µs. `medido`.
- Del slot de 1 s (`SPEC.md` §7.3: `λ_obj = 1 bloque/s`, `τ_nom = 1 s/slot`), el firmante consume
  **0,099 % en el p99** y **0,29 % en el peor caso de 2 000**. Margen de sobra: **no** es
  significativo para 1 bloque/s. `medido`.
- **Aviso de método, y es importante:** la primera medición se hizo sobre `/tmp`, que en esta
  máquina es **`tmpfs`** (RAM): daba ~12 µs por bloque. Un `fsync` sobre `tmpfs` no toca ningún
  disco. Las cifras de la tabla son sobre el btrfs real del workspace, y el ejemplo imprime el
  `findmnt` del directorio para que la cifra sea auditable. `medido`.

### 4.1 · ¿Merece la pena `fdatasync`? Propuesta con su riesgo

`fdatasync` baja la mediana de ~806 µs a ~398 µs, la mitad. La entrada de nuestro registro **crece**
el fichero en cada bloque (append de 80 bytes), así que el tamaño también tiene que ser durable y
`fdatasync` no puede saltarse ese metadato; en btrfs `fdatasync` sigue comprometiendo la transacción.
Aun así, **no se ha cambiado la implementación a `fdatasync`** y no se propone como cambio por
defecto:

- **Riesgo:** el ahorro del 50 % de 0,8 ms no compra nada a 1 bloque/s (el margen es del 0,1 %), y
  cualquier cosa que retrase o debilite la durabilidad **reabre exactamente el accidente** que el
  firmante evita. La regla del encargo: «cualquier cosa que retrase la durabilidad reabre el
  accidente».
- **Si algún día importara** (p. ej. con muchos bloques/s o un disco lento), las alternativas
  ordenadas por riesgo creciente serían: (i) `fdatasync` en vez de `fsync`, con el matiz de que el
  fichero crece; (ii) agrupar varios bloques en una escritura y un `fsync` — reduce el coste
  amortizado pero **retrasa la durabilidad de cada uno**, y con ella la garantía; (iii) un WAL con
  `fsync` propio de la entrada antes de firmar (es lo que ya es este registro: un log solo-anexar).
  Las tres necesitarían su propia medición y su propia prueba de durabilidad antes de adoptarse.
  `propuesto`.

### 4.2 · Tamaño del registro y política de poda

Cada entrada ocupa **80 bytes** exactos: `slot` (8) + huella de identidad (32) + `pre_hash` (32) +
comprobación (8). La cabecera, 32 bytes. `medido`.

| Régimen | Tamaño |
|---|---|
| 1 bloque/s | 0,30 MiB/hora · 7,3 MiB/día · **2,59 GiB/año** |
| Por bloque | 80 B |

**Criterio de poda, no número inventado.** `C-GD-04` (`SPEC.md` §11) rechaza todo bloque con
`slot(B) − slot(sp(B)) > S_max_slots`, y `C-HDR-07` ata `pot_bundle_count` a esa diferencia. Pasado
`slot + S_max_slots`, una entrada **ya no puede colisionar** con nada: ninguna producción futura
puede reclamar ese slot. Por eso `Registro::podar` tira las entradas con
`slot + S_max_slots < max_slot` y solo entonces. `derivado` + `demostrado por test`
(`la_poda_tira_lo_que_ya_no_puede_colisionar`).

Con ese criterio el registro **vivo** está acotado por `S_max_slots` entradas (150 entradas ≈ 12 KiB
con el valor nominal), así que el crecimiento de 2,59 GiB/año es **solo si no se poda nunca**. La
poda es una operación de mantenimiento fuera del camino crítico (reescribe el log, `fsync`, y
sustituye el contenido bajo el cerrojo). **Lo que NO está decidido aquí:** cada cuánto se poda, quién
la dispara y si el registro debe tener un límite duro de tamaño. `no determinado`. Y una advertencia:
**podar no es olvidar por completo** — mientras una entrada esté viva, su huella identifica la
oportunidad; una vez podada, la única defensa es que ese slot ya no puede aparecer.

---

## 5 · Lo que este prototipo NO resuelve (de `ESPECIFICACION.md` §3.4, sin suavizar)

1. **Dos máquinas que no comparten el registro.** Es FP1 y FP6 del catálogo. El firmante solo ayuda
   si los dos nodos usan **el mismo** registro, y hoy eso no está especificado. Con dos registros
   distintos, dos nodos sobre la misma parcela siguen firmando dos `pre_hash` de la misma
   oportunidad. Nada en este prototipo lo evita.
2. **Un atacante decidido.** El registro es local. Quien quiera doble-firmar **borra el registro**,
   lo copia antes, o usa un binario que no lo consulte. **El firmante seguro es un filtro de
   accidentes honestos, no un mecanismo de seguridad.** No se presenta como prevención en ningún
   sitio, y no debe presentarse así.
3. **Una clave robada o compartida.** FP6: con la identidad vigente, `public_key` es parte de la
   identidad, así que dos operadores con la misma clave y la misma parcela producen la misma
   evidencia. La consecuencia que importa: si el castigo cae sobre el lote y las recompensas
   retenidas, un tercero con la clave puede **provocar la confiscación** del lote ajeno. Es
   *griefing*, y este prototipo no lo trata.
4. **La pérdida honesta del slot tras un reorg — el firmante seguro la causa.** FP3/FP7:
   `SPEC.md` §7.2 dice que «un billete consumido en una historia abandonada vuelve a estar
   disponible»; el firmante seguro se **niega** a reusarlo y el granjero honesto **pierde** esa
   recompensa tras cada reorg. Es el precio del mecanismo, y es una decisión de diseño, no un fallo
   de implementación. `SPEC.md` §7.2 y la infracción estrecha no pueden convivir sin decidir cuál
   manda; este prototipo no decide.
5. **Una identidad mal elegida.** Si el firmante se indexara por `pre_hash` o por `block_hash`, no
   protegería nada (los dos `pre_hash` son distintos por construcción). Por eso la identidad es un
   punto de extensión y no una constante escondida. Pero una **tercera** definición mal elegida
   —por ejemplo, una que no incluya el `slot`, o que colisione entre redes— rompería la garantía sin
   que este prototipo pueda detectarlo: solo puede probar las dos que implementa.
6. **Y una que el catálogo no lista y este prototipo tampoco arregla:** la **identidad vigente no
   lleva dominio de red** (FP8), así que el mismo billete en mainnet y testnet colisiona. Está
   implementada la variante con dominio, pero **la de por defecto sigue siendo la vigente** por
   mandato del encargo §1; cambiarla es una decisión de Katana.
7. **Registro en red y `fsync` que miente.** Un registro compartido por NFS o similar puede no
   garantizar la durabilidad, y entonces el punto 3 de la regla deja de cumplirse **sin que el
   código pueda saberlo**. No medido.

---

## 6 · Estado de la evidencia, en una tabla

| Afirmación | Etiqueta |
|---|---|
| El caso 5 se cumple: con entrada previa y otro `pre_hash`, no firma | `demostrado por test` |
| El caso 4 se cumple: reemitir el mismo bloque funciona | `demostrado por test` |
| La entrada sobrevive a un `SIGABRT` entre la escritura y la firma, y el conflicto se detecta al reiniciar | `demostrado por test` |
| La abstención tras perder el registro dura exactamente `S_max_slots` | `demostrado por test` |
| Ocho hilos con la misma oportunidad: solo uno sella | `demostrado por test` |
| Un segundo proceso sobre el mismo fichero acaba bloqueado | `demostrado por test` |
| La identidad funciona con dos implementaciones sin mezclar espacios de claves | `demostrado por test` |
| Corrupción en medio del log falla cerrado; cola a ceros se trunca | `demostrado por test` |
| El descriptor del registro no sobrevive a un `exec` | `demostrado por test` |
| El coste añadido por bloque es ~0,81 ms de mediana (~0,1 % del slot en el p99) | `medido` (btrfs/NVMe, carga anotada) |
| 80 B por entrada; 2,59 GiB/año sin podar | `medido` |
| El criterio de poda es `slot + S_max_slots < max_slot` | `derivado` (+ test) |
| `fdatasync` reduciría el coste a la mitad sin cambiar el veredicto | `medido` (no adoptado) |
| El firmante sirve igual con cualquiera de las reglas económicas que se adopten | `derivado` de que es local y previo al consenso |
| Dos nodos con registros distintos siguen produciendo la evidencia | `derivado` (y es lo que el prototipo **no** cubre) |
| Cuánto caduca esto si Katana cambia la identidad | `no determinado` (por eso es un punto de extensión) |

---

## 7 · Comandos para reproducir

```bash
cd /home/katana/zeo/ZEROX/P-ZRX/P-FIRMANTE/prototipo
export CARGO_TARGET_DIR=/home/katana/zeo/ZEROX/P-ZRX/P-FIRMANTE/prototipo/target

# compilar (offline y con el lock fijado)
cargo build --locked --offline --all-targets

# la suite entera
cargo test --locked --offline

# solo el contrato del encargo
cargo test --locked --offline --test firmante_contrato

# lint estricto
cargo clippy --locked --offline --all-targets -- -D warnings

# la medición (§4): el segundo argumento es el directorio, y NO debe ser /tmp (es tmpfs)
cargo run --release --locked --offline --example medir_coste -- 2000 target/mediciones
```

El binario de test tiene tres puntos de entrada marcados `#[ignore]` que **abortan el proceso a
propósito**; no hay que ejecutarlos a mano (`cargo test` no los ejecuta).
