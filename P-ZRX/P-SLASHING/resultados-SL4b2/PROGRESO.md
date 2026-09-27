# PROGRESO — SL-4b2

Ejecutor único (subagente Sonnet, sin forks). Zona: `/home/katana/zeo/ZEROX/deepseek/SL4b2/`.

## 2026-09-27T07:56:54+02:00 — arranque

- Leída íntegra `P-ZRX/P-SLASHING/ORDEN-SL4b2-NODO.md`, `V-ZRX/LINEO.md`, `CONTRATO-EVIDENCIA-v0.md`
  (con «Ratificación v0», que prevalece: RAT-1…RAT-4, RAT-2′), `DECISIONES.md`, `REVISION-SL2b.md`,
  `REVISION-SL4a.md`, `REVISION-SL4b1.md`, `REVISION-SL4c.md`, `ESQUEMA-REGISTRO-v1.md`,
  `PERFIL-DEV-v0.md`, `PLAN-W06.md`, `REVISION-W06d6.md`, `REVISION-W06d7.md` (decisión 0, paso previo).

- **V0 (parte 1) — `sha256sum -c P-ZRX/P-SLASHING/ENTRADA-SL4b2.sha256` desde la raíz:** verde, 55/55
  («La suma coincide» en todas). Incluye `V-ZRX/LINEO.md`, que existe en el árbol de trabajo pero está
  **sin commitear** (`git status` lo marca `??`); no pertenece al commit `bb648fb`. Se trata como
  documentación de referencia (no «código»), leída del disco tal como la entrada exige; no se copia a
  `ws.orig/`/`ws/` porque no es código y la orden solo pide reproducir en la zona
  `Cargo.toml/.lock, rust-toolchain.toml, crates/, testdata/, ci/, .github/` + el directorio `PDF`.

- **Discrepancia detectada (declarada, no bloqueante):** el árbol de trabajo actual tiene 4479 archivos
  `D` (borrados sin commitear) y 28 `??`, ajenos a esta orden (reordenación de `P-ZRX/P-2.1`, `veritas/`,
  etc., de otra tarea en curso). Comprobado con
  `git status --porcelain -- crates/ Cargo.lock Cargo.toml rust-toolchain.toml ci/ .github/`: **vacío**,
  sin cambios. Comprobado también `git diff --stat bb648fb HEAD -- crates/ Cargo.lock Cargo.toml
  rust-toolchain.toml ci/ .github/ testdata/`: **vacío** (0 diferencias de código entre `bb648fb` y
  `HEAD` = `a39748b`; solo cambian dos archivos de bitácora/orden). Conclusión: el código en `bb648fb`,
  en `HEAD` y en el árbol de trabajo actual es idéntico; los borrados no tocan nada de lo que esta orden
  puede leer o modificar.

- **Base congelada:** `git archive bb648fb | tar -x -C ws.orig` y lo mismo para `ws/` (extracción
  read-only del árbol del commit, sin tocar el árbol de trabajo del repositorio — cumple «nunca git en
  el repositorio»: no se ha hecho ningún commit, stash, checkout ni reset). `ws.orig` y `ws` son
  idénticos byte a byte (`diff` de listados de archivos vacío). No se modifica `ws.orig/` en adelante.

- Verificado `sha256sum -c` de la entrada **desde dentro de `ws/`**: todas coinciden salvo
  `V-ZRX/LINEO.md` (no existe en `ws/`, por la razón de arriba — es documentación fuera de la zona de
  código, no un archivo que la orden pida reproducir en `ws/`).

## Próximo paso

- V0 (parte 2): compilar y correr la suite completa de `ws.orig` (`cargo test --workspace --all-features
  --locked`, `nice -n 10`, en segundo plano, log anotado aquí con PID antes de esperar).

## 2026-09-27 ~08:00–09:30 — decisiones 0–5 implementadas en `ws/` (código, sin ejecutar aún V1-V7)

Procesos en segundo plano en marcha ahora mismo:
- **PID 2157669** (`ws.orig`): `cargo test --workspace --all-features --locked --no-fail-fast --
  --test-threads=8`. Log: `deepseek/SL4b2/logs/V0-suite-wsorig.log`. Es la mitad de V0 (suite de la
  raíz sin cambios); avanzando limpio (todo `ok` hasta ahora, en `tests/reinicio.rs`).
- **PID 2202701** (`ws/`): `cargo check --workspace --all-features --locked` para validar que las
  decisiones 0-5 no rompen ningún otro crate del workspace (`zx-p2p`, `zx-storage`, etc.). Log:
  `deepseek/SL4b2/logs/check-ws-workspace.log`.

Cambios hechos en `ws/` (ninguno en `ws.orig/`):

- **Decisión 0** (paso previo, `REVISION-W06d7.md`): `crates/zx-node/src/regimen.rs` (nuevo
  `MsgBucle::CambiarTerminal(ServicioPot)`, `Recepcion`/`recibir_o_cambiar_terminal`, bucle `'outer`)
  y `crates/zx-node/src/nodo.rs` (`terminal` local ahora `mut`, `sincronizar_terminal_productor`,
  llamado en el timeout de 50 ms y tras cada mensaje del hilo antes de responder). El hilo productor
  adopta el `ServicioPot` del terminal nuevo sin reiniciar el proceso; una petición de padres del
  terminal viejo se descarta sin contestar (el hilo la abandona).
- **Decisión 1**: `crates/zx-node/src/perfil.rs` — `R_SLOTS = 600` (antes 60), `PLAZO_SLOTS = 300`,
  `M_MARGEN_SLOTS = 60`, `EVP_F_NUM/DEN = 1/1`, `S_MAX_SLOTS = 150`, `MAX_EVIDENCIAS_POR_BLOQUE = 4`,
  `MAX_IDENTIDADES_DETECTOR = 65536`, `parametros_evidencia_dev()`, `puerta_rat3()` (función pura,
  testeable con un perfil que la incumple). `nodo.rs::arrancar` comprueba la puerta **antes** de
  tocar disco (`comprobar_puerta_rat3`, nueva `ErrorNodo::PuertaRat3Incumplida`) y usa
  `Cadena::nueva_con_evidencia`. Tests en `perfil.rs` (la_puerta_rat3_...) y `nodo.rs`
  (`pruebas_puerta_rat3`).
- **Decisión 2**: `crates/zx-post/src/{productor.rs,productor_regimen.rs}` **sin tocar** (ya traían
  `producir_en_regimen_con_firmante`/`ProductoFirmado` de SL-4b1). `regimen.rs` ya no llama a
  `producir_en_regimen` (la insegura): usa `producir_en_regimen_con_firmante` con un `Firmante` único
  por nodo. `nodo.rs`: campo `registro_firmante: Option<Arc<zx_post::firmante::Registro>>`,
  `abrir_registro_firmante_limpio` (arranque limpio, `Registro::nueva`, FIR-12) y
  `abrir_registro_firmante_tras_reinicio` (`Registro::abrir(ruta, slot_actual, 150)`,
  `slot_actual = máx(slot más alto de `cadena.bloques_post()`, `servicio_pot.slot_actual()` del
  terminal)`). Nuevo `MsgProductor::Abstenido{slot,motivo}`; el bucle escribe `firmante_abstenido`
  (crítico) y sigue (`Continuar`).
  - **Declaración (contrato §4, "quítalas de la API pública... o #[cfg(test)]"):** no se cambió la
    visibilidad de `producir_en_regimen`/`producir` en `zx-post` porque `crates/zx-post/tests/
    regimen.rs` y `tests/firmante_productores.rs` (fuera de mi zona editable: no son "tests nuevos")
    las siguen usando como integración externa; `#[cfg(test)]` o `pub(crate)` las habría roto. Se
    verificó por `grep` que `crates/zx-node/**` ya no las nombra en ningún sitio: el nodo es
    inalcanzable desde ellas en la práctica, aunque la API de `zx-post` siga técnicamente pública.
    Candidato para una orden posterior si se quiere cerrar también a nivel de tipos.
- **Decisión 3**: `crates/zx-node/src/evidencia.rs` (nuevo). `DetectorDobleFirma`: indexa por
  `Firmante::identidad` (RAT-1) la primera cabecera vista; `observar()` devuelve
  `Nueva/MismaCabecera/Incidente(Pendiente)/IncidenteYaPendiente`; poda de vistas por ventana
  (`podar_vistas`) y de pendientes por cierre de ventana (`podar_pendientes`, EV-13/14); tope
  `MAX_IDENTIDADES_DETECTOR` con desalojo por slot más viejo (`LimiteAlcanzado`). 7 tests unitarios
  (misma identidad+otro pre_hash, misma cabecera, los 6 campos de la identidad, poda, tope+desalojo,
  tercera cabecera, poda de pendientes). Enganchado en `nodo.rs::admitir_post_interno` vía
  `observar_para_detector`, llamado **después** de que la puerta conjunta pasa (o, en repetición,
  después de lo que ya pasó en una ejecución anterior) y **antes** de que la admisión GHOSTDAG/estado
  decida nada — cubre bloques propios, de red y huérfanos ya resueltos (todos pasan por la misma
  `admitir_post_interno`). Escribe `evidencia_detectada` (con `propia` añadido a los campos del
  esquema, no solo los mínimos) y `limite_alcanzado`.
- **Decisión 4**: `MsgProductor::PeticionPadres` ahora lleva el `slot` objetivo (antes no lo llevaba:
  hacía falta para filtrar «ventana abierta en el slot del bloque»). `MsgBucle::Padres` lleva un 4º
  campo `Vec<Tx>` con hasta `MAX_EVIDENCIAS_POR_BLOQUE` pendientes ya filtradas por el bucle
  (`estado_post(padre_seleccionado)` para «no procesado», `slot_falta ≤ slot_objetivo <
  slot_falta+Plazo_slots` para «ventana abierta»); el hilo las mete en `CuerpoProductor` sin volver a
  decidir nada. Al admitirse el bloque producido, se escribe `evidencia_incluida` por cada una.
  **No** se marca una pendiente como "consumida" al incluirla (a propósito, EV-24/decisión 4: "si el
  bloque sale de la cadena seleccionada, vuelve a ser elegible" — la única fuente de verdad es el
  estado de la punta en cada intento, no un marcado interno).
- **Decisión 5**: `crates/zx-node/src/bin/zx-adversario.rs` — subcomando `doble-firma` (`--clave-indice`,
  `--semilla`, `--plazo-espera-s`, `--repetir`), aditivo (sin subcomando, el binario sigue haciendo
  exactamente la ráfaga E-7/E-8 de siempre). Espera un `BloqueRed::Post` de la clave (vía un canal
  nuevo en `Espia`, alimentado desde `bloque_difundido`), construye la segunda cabecera con
  `timestamp+1` y la resella con la misma clave (`ed25519_zebra`), comprueba localmente
  `Firmante::identidad` igual y `pre_hash` distinto (`assert_eq!`/`assert_ne!`: un fallo aquí sería un
  bug de la propia herramienta), la publica; con `--repetir`, una tercera (`timestamp+2`).

Compilado y verificado con `cargo check -p zx-node --all-features --locked` (lib y bins) tras cada
decisión: **verde** en las cinco. `cargo test -p zx-node ... evidencia:: --no-run`: **verde**
(compila los 7 tests nuevos). Falta: correr esos tests (V1-V3), clippy/fmt, y V4-V7 con procesos
reales.

## 2026-09-27 ~09:00–09:45 — V1-V3 verdes; clippy/fmt de zx-node verdes; preparando V4 real

- `cargo test -p zx-node --all-features --locked --lib`: **49/49 ok** (incluye los 7 de
  `evidencia::tests` y los 3 de `nodo::pruebas_puerta_rat3`, más los ya existentes). V1 y V3
  cubiertos a nivel unitario.
- `cargo clippy -p zx-node --all-targets --all-features --locked -- -D warnings`: encontró 3 fallos
  reales de higiene (enum grande sin boxear en `evidencia::Observacion::Incidente` y en
  `regimen::Recepcion::Mensaje`, un `.clone()` sobre `DagBlockHeader: Copy`, `panic!`/`.expect()` en
  el módulo de test sin el `#[expect(...)]` correcto) — corregidos; segunda pasada **limpia**.
  `cargo fmt --check -p zx-node`: aplicado, limpio.
- **Añadido tras el diseño de V4:** decisión 4 no daba forma de leer `activo`/`congelado` de la
  clave castigada desde fuera (ni `zx-p2p` expone esa consulta, vedado para esta orden, ni el
  `resumen_estado` es más que un hash). Añadido un evento de **diagnóstico** (no forma parte del
  esquema mínimo v1; el analizador de W07c ya declara que ignora tipos desconocidos)
  `garantia_clave_tras_evidencia` (`incident_id`, `clave`, `activo`, `congelado`), escrito por
  `admitir_post_interno` (la tubería única, cubre producción propia/red/repetición) justo tras
  aplicar cualquier bloque que lleve una `EvidenceTx`. Es lo único que permite a V4 comprobar la
  confiscación "leído del estado de los tres nodos" sin tocar `zx-p2p`/`zx-cadena` (vedados).
- Preparando **V4 con procesos reales, una primera repetición** (con el presupuesto de tiempo que
  quede, no se descarta que solo dé tiempo a 1 de las 3 repeticiones que pide la orden — se
  declarará explícitamente si es así):
  - `deepseek/SL4b2/scripts_verif.sh` y `deepseek/SL4b2/ejecutar_v4.sh` (guiones de esta sesión, no
    código del encargo), adaptados por **lectura** de `deepseek/W06d6/scripts_verif.sh` y
    `deepseek/W06d7/ejecutar_v4.sh` (permitido: son zonas de solo lectura para mí).
  - `N_dev = 27 780 000` **reducido y declarado** (≈0,2 s/slot, con la tasa medida de W05b2: 1,389·
    10⁸ iter/s; el propio decisión 4 de la orden permite "N_dev reducido declarado").
  - Build en marcha: `cargo build --release -p zx-node --all-features --locked --bins` — **PID
    2214571** (el proceso bash que lo lanzó; el compilador real es su hijo `cargo`), log
    `deepseek/SL4b2/logs/build-release.log`.
  - CLI de `zx-adversario` verificada (`--help`): el subcomando `doble-firma` aparece con sus 4
    flags; sin subcomando sigue exactamente como antes (aditivo, decisión 5 cumplida).

## 2026-09-27T08:48 aprox — V4 rep1 lanzada (procesos reales)

- Build release terminado (`Finished release profile ... in 4m 10s`), binarios en
  `deepseek/SL4b2/ws/target/release/{zx-node,zx-adversario}`.
- `zx-adversario --help`/`doble-firma --help` verificados: el subcomando es aditivo (sin él, el
  binario sigue haciendo exactamente la ráfaga E-7/E-8 de siempre).
- Lanzado `bash deepseek/SL4b2/ejecutar_v4.sh rep1 43500` en segundo plano. **PID 2232554** (el
  script bash; lanza y mata sus propios A/B/C con PIDs propios en `run-v4-rep1/{A,B,C}/pid`).
  Log: `deepseek/SL4b2/logs/V4-rep1.log`. Puertos 43500/43501/43502 (comprobado con `ss` que
  estaban libres antes de lanzar, dentro del propio script). `N_dev = 27 780 000` (reducido,
  declarado). Se retoma leyendo `logs/V4-rep1.log` y `run-v4-rep1/*/registro.jsonl`.

## V4 rep1 — resultado real (2026-09-27 ~08:45–08:47, procesos reales)

**Extremo a extremo, SUPERADO en lo esencial, con un fallo real encontrado y corregido en el propio
diagnóstico de esta orden (no en las decisiones 0-5):**

- 3 nodos reales A(0,1,2)/B(3,4,5)/C(6,7,8), `N_dev=27 780 000`, cruzaron el corte y llegaron a 20
  bloques PoST en **~18 s** de reloj real (mucho más rápido de lo previsto: `SR_dev` por defecto
  hace que las 9 claves ganen casi todos los slots).
- `zx-adversario doble-firma --clave-indice 0 --semilla 1 --repetir` contra A: encontró el bloque de
  la clave 0 en el slot 9, construyó la segunda cabecera (`timestamp+1`, misma identidad RAT-1,
  `pre_hash` distinto, comprobado localmente), la publicó, y con `--repetir` publicó una tercera
  (`timestamp+2`).
- **`evidencia_detectada`**: sí, en los tres nodos (A con `propia:true`, B y C con `propia:false`),
  mismo `incident_id`, mismo `hash_1`/`hash_2`, `slot_falta:9`. **La tercera cabecera (`--repetir`)
  no generó una segunda `evidencia_detectada`** (comprobado: solo 1 por nodo) — EV-10/EV-12 en
  procesos reales.
- **`evidencia_incluida`**: sí, en A (dos veces, en dos bloques hermanos del slot 10 producidos por
  sus otras dos claves — comparten `evidencias` porque el bucle las calcula una vez por slot).
- **Fallo real encontrado (por mí, con el propio diagnóstico que añadí para esta verificación) y
  corregido antes de repetir:** el primer `garantia_clave_tras_evidencia` leía
  `self.cadena.estado_terminal()`, que la propia documentación de `zx-cadena` dice literalmente que
  es `Estado(T)` del terminal (**el corte PoW→PoST**, no la punta PoST corriente) — así que
  **siempre** iba a mostrar la garantía de antes de cualquier bloque PoST, con o sin confiscación.
  Con esa lectura salía `activo:200, congelado:0` sin cambiar tras el incidente, que a primera vista
  parecía "la confiscación no se aplicó". Señal indirecta de que **sí** se aplicó: A dejó de volver
  a incluir la misma evidencia en los bloques del slot 11 en adelante (mi filtro de decisión 4
  comprueba `estado_post(padre_seleccionado)`, que es la lectura correcta, y ese sí refleja el
  incidente procesado). **Corregido** (`nodo.rs`, el mismo sitio): ahora lee
  `self.cadena.estado_post(&hash)` (el estado **tras el bloque que se acaba de admitir**, la misma
  función de acceso que ya usa correctamente el filtro de inclusión). Recompilado (`cargo check`
  verde); repitiendo V4 (rep2) para confirmar con la lectura corregida antes de dar el paso por
  bueno. **Lección de método (LINEO §"verifica antes de afirmar"): sin este diagnóstico añadido para
  la propia verificación, habría faltado una forma de comprobar la confiscación; y sin repetir tras
  corregirlo, habría podido reportar "confiscación no se aplica" como si fuera un fallo de la
  decisión 4, cuando el fallo estaba en el instrumento de medida.**
- `resumen_estado` final: **CONVERGEN** en los tres (mismo `punta`, mismo `resumen_estado`) tras 37
  slots.
- Logs completos: `deepseek/SL4b2/run-v4-rep1/{A,B,C}/registro.jsonl`,
  `deepseek/SL4b2/logs/V4-rep1.log`.
- Recompilado release tras la corrección (`cargo build --release -p zx-node`, terminado en 42,75 s,
  incremental). Lanzado `bash deepseek/SL4b2/ejecutar_v4.sh rep2 43600` en segundo plano — **PID
  2235685**, log `deepseek/SL4b2/logs/V4-rep2.log`, para confirmar `activo`/`congelado` con la
  lectura corregida antes de dar V4 por superado.

## V4 rep2 — corrección confirmada (2026-09-27 ~08:50)

**`garantia_clave_tras_evidencia` en los tres nodos: `activo:0, congelado:0`** (antes de la
corrección: `activo:200` sin cambiar). Con la lectura correcta (`estado_post(&hash)`), los tres
nodos coinciden en que la garantía de la clave 0 quedó en cero tras el incidente
`1b913eb543b3339382f2ad064c76413f99fe3e894ac605f65b437b340596919e` (slot_falta 22). Resto igual que
rep1: `evidencia_detectada` en los tres (A `propia:true`), la tercera cabecera (`--repetir`) no
generó una segunda detección, `resumen_estado` **CONVERGEN** en los tres al final (41 slots). Esta
vez fue **C** quien incluyó la evidencia (no A): confirma que la inclusión no depende de que sea la
clave propia infractora, cualquier productor de la ventana puede incluirla. A siguió produciendo
bloques en slots posteriores (24, 25, 26, 27, 29…) con sus otras dos claves —consistente con "A no
produce mientras la garantía de la clave 0 sea `< q`", aunque no se aisló por clave individual en el
registro (no hay campo `clave` en `bloque_producido`; esto ya estaba decidido antes de esta orden,
`ESQUEMA-REGISTRO-v1.md`, y no lo cambio). Logs: `deepseek/SL4b2/run-v4-rep2/{A,B,C}/registro.jsonl`.

Lanzada una **tercera repetición** (`rep3`, puerto base 43700, PID 2237747, log
`deepseek/SL4b2/logs/V4-rep3.log`) para completar las 3 que pide la orden. **Nota honesta sobre
"semillas distintas":** las 3 repeticiones comparten `--semilla 1` (la derivación de claves del nodo
y la del adversario **deben** coincidir para que el ataque tenga sentido; no hay una "semilla" de
consenso independiente que variar sin romper esa correspondencia). Lo que varía entre repeticiones
es el resultado real de la carrera de PoW/PoST (timing real de 3 procesos independientes): rep1 tuvo
la falta en el slot 9 y la incluyó A; rep2 en el slot 22 y la incluyó C — realizaciones distintas,
no la misma ejecución repetida con datos idénticos.

## V4 rep3 — tercera repetición, SUPERADA (2026-09-27 ~08:52)

Falta en el slot 12; `evidencia_detectada` en los tres (A `propia:true`); `evidencia_incluida` en A;
`garantia_clave_tras_evidencia` con **`activo:0, congelado:0` en B y C** (confirma otra vez la
confiscación completa, `f=1`); `resumen_estado` **CONVERGEN** en los tres al final (42 slots). **Las
3 repeticiones que pide V4 están completas y las 3 dan el mismo veredicto:** detección en los tres
nodos, ninguna segunda evidencia por la tercera cabecera (`--repetir`), inclusión real, confiscación
a cero verificada de forma independiente en cada nodo, convergencia final. Logs:
`deepseek/SL4b2/run-v4-rep{1,2,3}/`.

**V4: SUPERADA, 3/3 repeticiones con procesos reales.**

## V6 — pérdida del registro del firmante, SUPERADA (2026-09-27 ~08:53–08:57, procesos reales)

3 nodos reales, A produce 16 bloques propios (hasta el slot 34), **`SIGKILL`** a A, se borra
**solo** `datos/firmante.registro` (el almacén se conserva: comprobado con `ls`), se rearranca A con
los mismos datos. Resultado:

- `modo:"reinicio"` en el evento `arranque`; `reinicio_completo` con **83 bloques repetidos**.
- **`firmante_abstenido` con `motivo:"perdida_registro"`: 81 eventos**, desde el slot **57**
  (primer intento de producción tras ponerse al día) hasta el slot **184** — y **produce a partir
  del 185**. `slot_perdida` (el punto de anclaje de la abstención) resultó ser **34**, exactamente
  el último slot que A conocía de sí mismo al morir (no 56 o 57, que es cuando A *empieza* a
  intentar producir tras el reinicio: el reloj PoT real siguió avanzando durante el reinicio y la
  puesta al día, así que el primer intento ya cae bastante después de `slot_perdida`). `34 + 150 =
  184`: **el borde inclusivo (DF-9) se cumple exacto** — abstiene en 184, produce en 185. Confirma
  con procesos reales lo que SL-4b1 ya había probado con tests unitarios.
- **`evidencia_detectada` en B y C: 0 y 0.** Ninguna doble firma observable pese al `SIGKILL` y la
  pérdida del registro: el firmante seguro cumplió su función.
- Sin procesos huérfanos al terminar (comprobado con `ps`/`ss`).
- Logs: `deepseek/SL4b2/run-v6-rep1/{A,B,C}/registro.jsonl`, `deepseek/SL4b2/logs/V6-rep1.log`.

**V6: SUPERADA (1 repetición; la orden no exige un número de repeticiones para V6, a diferencia de
V4).**

## V5 — primer intento: fallo de guion (no del nodo), corregido (2026-09-27 ~08:59-09:01)

Primer lanzamiento (**PID 2243635**): tras el primer `SIGKILL` y reinicio inmediato, A murió con
`error fatal: almacén: ... While lock file: .../storage/LOCK: Resource temporarily unavailable`.
**No es un fallo de la orden ni del nodo**: mi guion `ejecutar_v5.sh` mandaba `kill -9` y relanzaba
**sin esperar** a que el proceso muerto liberara de verdad el `LOCK` de RocksDB (asíncrono tras la
señal) — el mismo tipo de descuido que `deepseek/W06d7/ejecutar_v4.sh` ya documentaba para puertos
reutilizados, aquí con el `LOCK` del almacén. **Corregido:** `matar()` ahora espera (`kill -0` en
bucle, hasta 5 s) a que el PID desaparezca de verdad antes de devolver el control. Limpiado
`run-v5-rep1/` y relanzado — **PID 2245591**, log `deepseek/SL4b2/logs/V5-rep1.log`.

**Segundo hallazgo, mismo tipo de fallo de guion:** con esa corrección, la ejecución **sí** llegó al
final sin `FALLO_FATAL`, pero al revisar el `reloj_ns` de cada evento (reinicia desde ~0 en cada
proceso nuevo) solo había **un** reinicio real, no diez: los 10 `zx-node` sí se lanzaron (10 PIDs
distintos en el log), pero solo el primero sobrevivió — los otros 9 seguramente fallaron al enlazar
el mismo puerto TCP todavía ocupado (el socket en escucha no se libera tan rápido como el `LOCK` de
RocksDB) y terminaron sin que `hay_fatal` lo detectara (el mensaje de ese fallo, `zx-node: no se
pudo arrancar la red: {e}`, es **distinto** del `error fatal` que yo buscaba). **Corregido dos
veces:** `scripts_verif.sh::hay_fatal` ahora busca también `"no se pudo arrancar la red"`;
`ejecutar_v5.sh::matar()` espera además a que el puerto deje de aparecer en `ss -ltn`; y el bucle
comprueba **de verdad** (no supone) que cada iteración produjo un evento `arranque` nuevo, con su
propio fallo declarado si no. Relanzado — **PID 2249479**, log `deepseek/SL4b2/logs/V5-rep1.log`.
Se declara esto en detalle porque es exactamente el tipo de error que `LINEO.md`/la instrucción de
Katana piden no disimular: la primera pasada de V5 habría podido reportarse como "SUPERADA" sin
haber ejercido de verdad los 10 reinicios que pide la orden.

## V5 — SUPERADA de verdad, con los dos fallos de guion corregidos (2026-09-27 ~09:04–09:07)

Tercera pasada, confirmada evento por evento:

- **`arranque`: 11** (1 limpio + 10 reinicios) y **`reinicio_completo`: 10** — los 10 `SIGKILL` (en
  los momentos aleatorios `472, 694, 1735, 488, 374, 1698, 916, 1279, 1067, 1053` ms, `RANDOM=42`)
  produjeron 10 reinicios **reales y confirmados uno a uno** (el guion comprobó un `arranque` nuevo
  tras cada uno, no lo dio por hecho).
- **`firmante_abstenido`: 0** — el registro del firmante sobrevive cada `SIGKILL` (a diferencia de
  V6, aquí no se borra nada), así que nunca hace falta abstenerse.
- **`evidencia_detectada` en B y C: 0 y 0.** Ninguna doble firma observable con 10 caídas y
  reinicios reales del productor honesto.
- Sin procesos huérfanos al terminar (comprobado con `ps`/`ss`).
- Logs: `deepseek/SL4b2/run-v5-rep1/{A,B,C}/registro.jsonl`, `deepseek/SL4b2/logs/V5-rep1.log`.

**V5: SUPERADA.**

## V7 en marcha (2026-09-27 ~09:08)

- `cargo fmt --check` (workspace completo): **limpio**.
- `cargo clippy --workspace --all-targets --all-features --locked -- -D warnings`: **limpio**.
- `ci/dependencias-exactas.sh`: **OK — 24 dependencias con versión exacta**.
- `ci/frontera-crates.sh`: **OK** en las 9 fronteras (incluida `zx-node`, sin cambios: no toqué
  ninguna dependencia nueva entre crates).
- Lanzada la suite completa (`cargo test --workspace --all-features --locked --no-fail-fast --
  --test-threads=8`) en `ws/` (con las decisiones 0-5 aplicadas) — **PID 2255186**, log
  `deepseek/SL4b2/logs/V7-suite-ws.log`. Se compara contra V0 (81 binarios, 0 fallos en `ws.orig`):
  debe seguir siendo 81 binarios (más los nuevos de `zx-node`, ya contados en las 49 unitarias) con
  0 fallos.
- `zx-adversario` **sin subcomando** (la ráfaga E-7/E-8 de siempre) contra un nodo real de esta zona:
  idéntico comportamiento de antes (256 huérfanos aceptados localmente, PoW nonce malo, E-7/E-8 de
  PoST omitidos por seguir en fase PoW); el nodo objetivo terminó los 30s sin ningún `error fatal`,
  con 256 `bloque_red_huerfano` y 1 `bloque_red_rechazado` (el PoW malo) en su registro. Decisión 5
  no rompe la herramienta existente.

## Decisión 0 con procesos reales (E-6b), SUPERADA (2026-09-27 ~09:11-09:17)

`deepseek/SL4b2/ejecutar_e6b.sh` (adaptado por lectura de `deepseek/W06d7/ejecutar_v4.sh`, permitido):
A aislado (mina solo, cruza el corte con su propio terminal), B+C juntos (cruzan con el suyo). Antes
de reunir: A produjo 8 bloques propios, B+C 5 — **predicción: gana el terminal de A** (más peso).
Reunión: se mata y relanza **solo A** con `--red-marcar` hacia B y C; **B y C nunca se paran ni se
reinician** — siguen produciendo sobre su propio terminal (perdedor) en el momento de la reunión,
exactamente el escenario de `REVISION-W06d7.md` ("con la producción en marcha").

**Resultado, verificado en el registro de B (el lado perdedor, que nunca reinició su proceso):**

- `cambio_punta` con **`profundidad_reorg:1`** (tres veces): B se reorganizó de su propio terminal al
  de A, en caliente.
- B produjo **14 bloques en total: 5 antes de la reunión + 9 después**, sin reiniciar su proceso ni
  una sola vez — la prueba directa de que el hilo productor de B adoptó el terminal ganador
  (`MsgBucle::CambiarTerminal`, decisión 0) y siguió produciendo sobre él, en vez de quedarse
  produciendo para siempre sobre la rama que ya pesaba menos (el límite exacto que
  `REVISION-W06d7.md` dejaba abierto y que esta orden cierra).
- `resumen_estado` **CONVERGEN** en los tres al final.

Esto cierra el hueco más importante que había declarado en el primer borrador de `INFORME.md`
("decisión 0 sin prueba dedicada con procesos reales"): ya tiene una, y la decisión 0 queda
demostrada, no solo compilada.

## V7 — suite completa, resultado final: VERDE

`cargo test --workspace --all-features --locked --no-fail-fast -- --test-threads=8` en `ws/` (con
las decisiones 0-5 aplicadas): **81 binarios de test, 0 con fallos, 0 panics** — exactamente el
mismo número de binarios que V0 en `ws.orig` (81/0). `crates/zx-post/tests/regimen.rs` (que sigue
usando `producir_en_regimen`, la insegura, declarado en `DEFINICIONES-FALTANTES.md` §1) pasa sin
tocarla. Sin procesos huérfanos al terminar (comprobado con `ps`). **V7 completo: fmt, clippy,
suite, `ci/dependencias-exactas.sh`, `ci/frontera-crates.sh` y la regresión con procesos reales
(zx-adversario E-7/E-8 sin subcomando, y el ciclo de 3 nodos repetido muchas veces en V4×3/V5/V6/E-6b)
— todos verdes.**

**Nota de limpieza (declarada):** borré `run-e6b-rep1/` y `run-e7/` después de extraer y citar aquí
los eventos relevantes (los `cambio_punta`/`bloque_producido` citados arriba son texto copiado del
registro real, no memoria). No quedan como evidencia en disco, a diferencia de `run-v4-rep{1,2,3}`,
`run-v5-rep1` y `run-v6-rep1`, que sí se conservan íntegros. Si el director quiere los logs crudos de
E-6b/E-7 en disco, hay que repetirlos (los guiones `ejecutar_e6b.sh` y la línea de `zx-adversario`
sin subcomando quedan en la zona).

## V0 — resultado final

**Verde.** `grep "^test result:"` en `logs/V0-suite-wsorig.log`: **81 binarios de test, 0 con
fallos** (unitarios + integración + doc-tests de los 11 crates del workspace, en `ws.orig`, la raíz
en el commit `bb648fb`). Sin cambios respecto a la base: es exactamente la suite que ya pasaba antes
de esta orden.

## 2026-09-27T08:00:30+02:00 — V0 parte 2 en marcha

- **Hallazgo:** `PDF/autonomys-subspace` (dependencia vendorizada por `path`, `crates/zx-poas`) está en
  `.gitignore` (líneas 11-12) y por tanto **ausente** de `git archive bb648fb`. El patrón de las órdenes
  anteriores es que `ws/PDF` es **un enlace** (símlink), no una copia: se reemplazó el `PDF/` vacío de
  `ws.orig` y `ws` por un símlink a `/home/katana/zeo/ZEROX/PDF` (el real, fuera de la zona, solo lectura
  desde aquí). No se modifica nada en `/home/katana/zeo/ZEROX/PDF`.
- Lanzado en segundo plano desde `ws.orig/`: `nice -n 10 env CARGO_BUILD_JOBS=8 cargo test --workspace
  --all-features --locked --no-fail-fast -- --test-threads=8`.
  **PID real del proceso cargo: 2157669.** Log: `deepseek/SL4b2/logs/V0-suite-wsorig.log`.
  Puerto: N/A (no hay red en esta fase). Se retoma leyendo el log cuando termine.
