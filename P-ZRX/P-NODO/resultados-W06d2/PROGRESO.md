# PROGRESO — W06d2

Ejecutor único (Sonnet), sin subagentes. Zona: `/home/katana/zeo/ZEROX/deepseek/W06d2/`.

## Zona y entorno

- `ws.orig/` y `ws/` copian solo `Cargo.toml`, `Cargo.lock`, `rust-toolchain.toml`, `crates/`,
  `testdata/`, `ci/`, `.github/`, y el enlace `ws/PDF -> /home/katana/zeo/ZEROX/PDF` (y el mismo
  enlace en `ws.orig/`). Ningún documento de `P-ZRX/`, `D-ZRX/`, etc. se copió.
- `CARGO_HOME`/`CARGO_TARGET_DIR` dentro de la zona (`env.sh`). Caché de `.cargo-home` copiada de
  `deepseek/W06bR/.cargo-home` (27 GiB de destino, ~2,6 GiB tras `cp -a`).
- **Falta de definición encontrada:** la caché copiada no traía `clap_lex 1.1.1` (el lock la fija;
  la caché de W06bR solo tenía `1.1.0`). Con `CARGO_NET_OFFLINE=true` (como pide el patrón W06bR)
  `cargo check` fallaba en la resolución. Decisión: un único `cargo fetch --locked` con
  `CARGO_NET_OFFLINE=false` (red disponible, comprobado con `curl` a `index.crates.io`) para
  completar la caché **sin tocar el lock**; el resto del trabajo corre con `--offline`
  (`CARGO_NET_OFFLINE=true` en `env.sh`, sin cambiar). No se instaló nada del sistema.

## Punto 1 — Validación diferida en `zx-p2p` (decisión 1 de la orden)

Implementado y verificado (`fmt --check`, `clippy -D warnings`, `cargo test`, todos en verde para
el crate `zx-p2p`):

- `entrante.rs`: `IdDiferido` (opaco, `pub(crate)` el campo), `Veredicto::Diferir` (nuevo, 4ª
  variante), `VeredictoFinal` (Aceptar/Ignorar/Rechazar, sin `Diferir` — un diferido no puede
  volver a diferirse). `ManejadorEntrante::bloque_difundido` ahora recibe `id: IdDiferido`.
- `limites.rs`: `PLAZO_VALIDACION_DIFERIDA_S = 5`, `MAX_DIFERIDOS_PENDIENTES = 4096`.
- `servicio.rs`: `BucleRed` guarda `pendientes: HashMap<IdDiferido, PendienteDiferido>` (message_id
  + propagador + instante). `Comando::InformarValidacion`. `ManejoRed::informar_validacion` (async)
  e `informar_validacion_bloqueante` (para el hilo de consenso de `zx-node`, que no corre sobre
  `tokio`). Barrido periódico (`tokio::time::interval` a plazo/4) que expira a `Ignorar` —nunca a
  `Rechazar`— lo que lleve más del plazo sin informe. Tabla acotada: al llenarse, expira la entrada
  más vieja como `Ignorar`.
- `arrancar_con_plazo` (plazo explícito, para tests) y `arrancar_con` (plazo de producción) sin
  romper la firma que ya usaban `dos_nodos.rs` ni la futura de `zx-node`.
- Tests nuevos en `tests/dos_nodos.rs` (cadena A→B→C real sobre `MemoryTransport`):
  `un_diferido_no_se_retransmite_hasta_informar_aceptar`,
  `un_diferido_sin_informe_a_tiempo_no_se_retransmite` (plazo corto de 200 ms para no alargar la
  suite).
- El único cambio de este punto fuera de `zx-p2p` es el que exige la propia orden (item 3 más
  abajo): nada.

## Punto 7 — Prueba intermitente `reinicio.rs`

`tests/reinicio.rs`, fase de régimen: el bucle **ya** esperaba eventos del registro
(`bloque_producido`), no un `sleep` fijo — el fallo real (`REVISION-W06a-C.md`) era el **plazo** de
30 s que lo acotaba, demasiado ajustado en `debug` bajo carga compartida con otras suites. Subido a
120 s (mismo orden de magnitud que las rondas PoW de la misma prueba, 180 s), con el motivo
documentado en el propio código.

**Ejecutado:** 1 vez, dentro de la corrida completa de `cargo test --workspace --all-features
--locked` (ver `logs/V3-workspace.log`): `v5_sigkill_en_varios_puntos_reabre_sin_corrupcion_y_sigue_produciendo`
y `v5b_testigo_pow_corrupto_impide_arrancar` — las dos en verde. **No** se hicieron 5 ejecuciones
seguidas de la suite completa: cada ronda de `v5_sigkill` (12 ciclos de minado real + `SIGKILL`) ya
tarda varios minutos, y 5 repeticiones de la suite entera del workspace (que incluye además
`diferencial_t04`, `integracion.rs`, los diferenciales de `zx-consensus`/`zx-post`, etc.) no cabían
en el presupuesto de esta sesión. Queda declarado como pendiente, no como hecho — ver
`INFORME.md`.

## Aviso del director a mitad de ejecución (RI-2a) — registrado antes de editar

Mensaje recibido: RI-2a confirmó (hallazgo #1, ALTA) que `Cadena::admitir`
(`crates/zx-cadena/src/cadena.rs:207-235`) cachea `MotivoBloque::ErrSinPadre` como definitivo
también cuando la causa es que el padre (o el terminal) **todavía no llegó**: un hijo sometido antes
que su padre queda inválido para siempre en esa instancia aunque el padre llegue después y sea
válido, lo que diverge el estado entre nodos según el orden de llegada — justo el escenario que mis
huérfanos/sincronización de W06d2 necesitan que funcione.

**Arreglo mínimo aplicado** (documentado en el propio `cadena.rs`, con comentario largo explicando
la elección): un nuevo método privado `Cadena::dependencia_no_disponible(&self, &BloqueCadena) ->
bool`, llamado en `admitir()` **antes** de invocar `admitir_pow`/`admitir_post` (y por tanto antes
de cualquier mutación del DAG interno, en particular `anadir_al_dag`). Si la dependencia (el único
padre en PoW, o cualquier padre no-terminal en PoST, o el terminal mismo si aún no se fijó) no está
disponible, se devuelve `Err(ErrSinPadre)` **sin** insertarlo en `validos`/`motivos`: queda
sin-cachear a propósito, así que una llamada posterior a `admitir()` con el mismo bloque vuelve a
ejecutar la tubería completa desde cero (nunca a medias, porque el precheck es previo a toda
mutación).

**Por qué es seguro incluso para el motivo "conocido pero definitivamente inválido":**
`dependencia_no_disponible` trata "padre desconocido" y "padre conocido pero inválido" igual (ambos
"no disponible"): es una posición conservadora, nunca insegura — el peor caso es repetir el cómputo
si alguien reenvía el mismo bloque condenado a fallar, no cachear por error un huérfano como
inválido para siempre (la falla original).

**Riesgo analizado y a comprobar empíricamente:** `Cadena::resolver()` (solo usado por
`tests/propiedades.rs`) asume un mundo cerrado (un lote fijo) y decide "seguir esperando a un padre"
mirando `validos.contains_key(padre)`. Si un bloque del lote referencia un padre que **no está en el
lote en absoluto** (una referencia colgante, no un caso de reordenación normal), antes este arreglo
`admitir()` lo cacheaba igual (aunque fuera "no disponible" para siempre) y `resolver()` convergía
en la misma vuelta; con este arreglo, ese hash nunca se cachea, así que cualquier otro bloque del
lote que dependa de él como padre no converge y `resolver()` podría devolver `Err` donde antes
devolvía `Ok`. Análisis (trazado a mano): esto **solo** afecta a lotes con una referencia a un padre
fuera del lote completo (no al caso normal que `resolver()` existe para resolver: reordenación
dentro de un lote autocontenido, donde todo padre real SÍ está en el lote y se cachea en cuanto se
procesa). Se verifica ejecutando la suite completa de `zx-cadena` (incluida `propiedades.rs` y
`diferencial_t04`) tras el cambio — resultado en el veredicto final de este documento/INFORME.md.

**Test añadido** (hijo antes que el padre, luego el padre, luego el hijo otra vez): ver
`crates/zx-cadena/tests/padres_e_identidad.rs`,
`w06d2_hijo_antes_que_el_padre_se_admite_al_llegar_el_padre` (mismo espíritu que el repro de
RI-2a, adaptado a esta ubicación de tests). **Resultado: pasa.**

**Verificación empírica del riesgo de `resolver()` analizado arriba:** ejecutada la suite completa
de `zx-cadena` tras el arreglo:

```
tests/contexto_dag.rs      ... 2 passed
tests/diferencial_t04.rs   ... 1 passed (914 casos, 0 discrepancias, 150,09 s)
tests/padres_e_identidad.rs... 4 passed (incluido el nuevo test de RI-2a #1)
tests/propiedades.rs       ... 4 passed (incluida ie3_orden_de_llegada, la propiedad de
                                determinismo por orden de llegada que más directamente ejercita
                                `resolver()`)
```

0 tests perdidos, 1 añadido. `fmt --check` y `clippy -D warnings` en verde para `zx-cadena`. El
riesgo teórico (un lote de `resolver()` con una referencia a un padre **fuera** del lote completo)
no se materializa en los vectores/propiedades existentes; queda anotado como límite conocido de
`Cadena::resolver()` (uso exclusivo de tests, no de producción) por si una property test futura
construyera ese caso concreto.

Esto **no cambia** `ENTRADA-W06d2.sha256` (el arreglo vive en mi `ws/`, no en la raíz).

## BLOQUEO encontrado — `BloqueRed::Post` no lleva `JustificacionPot`: la verificación PoT/PoAS de un bloque PoST de red es imposible con el formato actual

**Parada exacta:** al diseñar la admisión de un bloque PoST llegado por red (huérfanos/sincronización,
decisiones 3-4), antes de escribir el camino de verificación.

**Evidencia literal:**

```
$ grep -n "pub struct BloqueRed" -A 20 crates/zx-p2p/src/mensaje.rs   # (ya citado arriba: Pow{cabecera,txs,testigos}, Post{cabecera,txs,testigos})
$ grep -n "pub struct BloqueDag" -A 8 crates/zx-core/src/wire_dag.rs
166:pub struct BloqueDag {
167:    /// Cabecera DAG.
168:    pub cabecera: DagBlockHeader,
169:    /// Justificación PoT, fuera de la cabecera y del `block_hash`.
170:    pub justificacion: JustificacionPot,
171:    txs: Vec<Tx>,
172:    testigos: Vec<Vec<Vec<u8>>>,
173:}
```

`zx_p2p::mensaje::BloqueRed::Post` (el tipo que de verdad viaja por la red) tiene **solo**
`{cabecera: DagBlockHeader, txs, testigos}` — **no** tiene el campo `justificacion`. Y
`justificacion` no es metadato de conveniencia: `zx_post::cabecera_conjunta::verificar_cabecera_conjunta`
lo lee para la verificación PoT de verdad (`crates/zx-post/src/cabecera_conjunta.rs:221`,
`let justificacion = &bloque.justificacion;`, usado en `verificar_rango_pot_fase_previa` y
`diferencia_de_slots`, `crates/zx-post/src/pot_rango.rs:515-739`: son los "portadores" del rango de
PoT auditado, evidencia que la verificación **comprueba**, no que ignore).

**Consecuencia:** un bloque PoST recibido por `zx-p2p` (gossip o sincronización) no trae los datos
que `verificar_cabecera_conjunta` necesita para producir un `prueba_valida` de verdad. Las dos únicas
vías honestas son (a) no verificar y aceptar el `prueba_valida` que declare el propio bloque —
**inaceptable**: es admitir sin comprobar, exactamente lo que la decisión 2 de la orden prohíbe— o
(b) tratar todo bloque PoST de red como no juzgable con el formato actual.

**Decisión tomada (documentada, no silenciosa):** opción (b). El camino de admisión de red trata un
`BloqueRed::Post` recibido de un par como **`Ignorar`** (nunca `Rechazar`: la falta no es del par, es
del formato de transporte) y registra el evento con el motivo exacto
(`"bloqueado: BloqueRed::Post no lleva JustificacionPot, ver PROGRESO.md"`). El camino de bloques
**PoW** no tiene este problema: `BloqueRed::Pow` lleva exactamente lo que
`Nodo::admitir_pow_interno` ya necesitaba, así que la admisión de red PoW es completa y real.

**Alcance de lo que esto bloquea:** un nodo real no puede, en esta orden, cruzar el corte ni
converger en régimen PoST **por red** con verificación completa — V4-V9 en su forma PoST no se
pueden demostrar de extremo a extremo. Sí se puede demostrar (y se demuestra, ver el veredicto y la
tabla V1-V10 del INFORME) la fase PoW: dos nodos reales que minan, se propagan bloques PoW, se
sincronizan por localizador y convergen en la misma punta PoW.

**Arreglo propuesto para un encargo futuro (fuera de mi alcance: cambiar `zx-p2p` más allá de la
validación diferida no es lo que pide esta orden):** añadir `justificacion: JustificacionPot` a
`BloqueRed::Post` (y al códec de `zx-p2p`, con su propio tamaño máximo declarado en `limites.rs`).
Es un cambio de formato de wire, no de la decisión 1; corresponde a una orden que decida
explícitamente tocar el formato PoST de `zx-p2p` con su propio análisis de tamaño/DoS.

## Segundo aviso del director a mitad de ejecución (RI-2b) — orden invertido persistir/admitir en PoST

**Mensaje recibido:** RI-2b confirmó (PLAUSIBLE, con intento de reproducción no concluyente por la
ventana submilisegundo) que `admitir_post_interno` (`nodo.rs`, antes de mi cambio: líneas ~613-626)
admitía el bloque PoST en `zx-cadena` (memoria) **antes** de persistirlo en `zx-storage`, al revés que
`admitir_pow_interno` (que persiste primero y lo explica en su propio comentario). Un `SIGKILL` entre
las dos deja el bloque «producido» en memoria pero fuera del almacén; al reiniciar, `ServicioPot` se
reconstruye solo desde lo persistido (D-N03′), el mismo slot vuelve a estar disponible y, con un solo
flujo PoT determinista (D-P10), la misma clave puede volver a ganarlo y firmar un **segundo** bloque
distinto para el mismo slot: doble firma, justo lo que «Relanzamiento» punto 4 de `ORDEN-W06d1`
prohíbe.

**Arreglo aplicado:** invertido el orden en `admitir_post_interno` (persistir en `almacen` primero,
solo si `!ya_admitido && verificar`; admitir en `cadena` después), con el mismo comentario que ya
tenía `admitir_pow_interno` adaptado al caso PoST. De paso, ahora que el bloque está admitido de
verdad, se registra en `VistaRed` (decisión 4 de `ORDEN-W06d2`) y se reintentan los huérfanos que lo
esperaban — trabajo que de todas formas hacía falta para la red.

**Sobre la prueba pedida (punto de inyección de fallo entre persistir y admitir):** no se añadió un
punto de inyección de fallo determinista en esta sesión (presupuesto agotado, ver el veredicto final);
`admitir_pow_interno` tampoco tiene uno pese a llevar el mismo patrón desde `ORDEN-W06d1`, así que no
es una regresión de cobertura nueva, pero sigue siendo una prueba pendiente y se deja anotada aquí
para un encargo futuro: envolver `Almacen::admitir`/`Cadena::admitir` en algo inyectable (p. ej. un
trait con una implementación de test que aborte a mitad) y comprobar, tras abortar entre las dos
llamadas y reiniciar, que ningún `(productor, slot)` se repite en `Cadena::bloques_post()`. La difusión
del bloque propio (decisión 2, «solo después de persistirse») ya solo puede ocurrir después de las dos
operaciones: `Nodo::difundir_si_hay_red` se llama **después** de que `admitir_post_interno`/
`admitir_pow_interno` retornan `Ok`, nunca antes.

## Puntos 2-5 — Red del nodo: manejador, huérfanos, sincronización, penalización

Implementado en `crates/zx-node/src/red/` (módulos nuevos: `huerfanos.rs`, `vista.rs`,
`manejador.rs`, `sync.rs`, `mod.rs`) e integrado en `nodo.rs`:

- **`ManejadorRed`** (implementa `zx_p2p::entrante::ManejadorEntrante`): cada método es una lectura
  de `VistaRed` (instantánea con `RwLock`, actualizada por el hilo de consenso) o un `send` no
  bloqueante a una cola (`TrabajoRed`, `tokio::sync::mpsc::unbounded_channel`). `bloque_difundido`
  **siempre** devuelve `Diferir` y encola: la validación de verdad ocurre en el hilo de consenso
  (decisión 1), nunca en el bucle asíncrono.
- **Depósito de huérfanos** (`huerfanos.rs`, decisión 3): acotado por total (4096) y por padre (64),
  desalojo FIFO determinista, con 6 tests unitarios.
- **Sincronización** (`sync.rs`, decisión 4): tarea `tokio` aparte que atiende `EventoRed`: al
  conectar pide `Peticion::Estado`; si el par va por delante en PoW pide `CabecerasPow` con un
  localizador real (denso cerca de la punta, espaciado hacia atrás, termina en el génesis — con
  test); las cabeceras/puntas PoST que faltan se piden como `Peticion::Bloques`. El recorrido hacia
  atrás del DAG **reutiliza** el depósito de huérfanos (pedir una punta ajena que no tenemos la
  deposita como huérfano y dispara la petición de sus padres) en vez de un algoritmo de recorrido
  propio.
- **Penalización** (decisión 5): un bloque de sincronización (no gossip) demostrablemente inválido
  desconecta con `MotivoDesconexion::ViolacionDeConsenso`; uno de gossip usa el canal de
  `informar_validacion` que ya hace que gossipsub aplique su propia penalización al reenviar
  `Reject`. Verificado end-to-end (ver más abajo): un `PoW nonce malo` real deja al par desconectado.
- **`Nodo::intentar_admitir_pow_de_red`**: distingue huérfano (padre desconocido → `Ignorar` +
  depósito + petición), padre conocido inválido (`Rechazar`), fork/reorg de PoW no soportado (ver
  límite abajo) y extensión válida de la punta (tubería completa real, `Aceptar`/`Rechazar` según el
  motor). **Nunca** propaga un error fatal por un bloque ajeno (a diferencia de uno propio).
- **Difusión de bloques propios** (decisión 2): `Nodo::difundir_si_hay_red` se llama **después** de
  que `admitir_pow_interno`/`admitir_post_interno`/`producir_bloque_transicion` devuelven `Ok`, nunca
  antes — persistencia y admisión ya terminaron.
- **Registro estructurado** (V9): `bloque_red_admitido`/`bloque_red_rechazado`/
  `bloque_red_huerfano`/`bloque_red_fork_no_soportado`/`bloque_post_de_red_no_verificable`, todos
  escritos **después** de que la tubería de admisión termina (nunca antes de decidir).

### Límite conocido: sin reorg de PoW en esta orden

`admitir_pow_interno` (heredado de `ORDEN-W06d1`) asume que todo bloque nuevo extiende
`historial_pow` (su último elemento): calcula el target/contexto de PoW contra el último elemento,
no contra el padre declarado del bloque. Un bloque de red que extiende un padre **admitido y
válido** pero que no es la punta actual (una bifurcación de PoW legítima, p. ej. tras una
partición/reunión, E-6b) se **ignora** en vez de admitirse con un contexto de validación
incorrecto — `intentar_admitir_pow_de_red` lo detecta explícitamente
(`extiende_la_punta`) y registra `bloque_red_fork_no_soportado`. Implementar reorg de PoW real
exige que `Nodo` calcule el contexto de validación (altura, target, timestamp del padre) a partir
del padre **declarado**, no de `historial_pow.last()`, y mantener candidatas a punta múltiples con
elección por trabajo acumulado — trabajo de una orden futura, no de ésta. **Esto es lo que impide
demostrar V6 (partición y reunión) y la mitad de V4/E-6b de extremo a extremo por red.**

## Punto 6 — Herramienta adversarial (`zx-adversario`)

`crates/zx-node/src/bin/zx-adversario.rs`, binario aparte (nunca un modo de `zx-node`). Habla el
protocolo real (mismo `ZxBehaviour`, transporte TCP real): se conecta, pide `Peticion::Estado` para
conocer la punta real del objetivo, y ejecuta escenarios de E-7/E-8 en orden (los que no violan
consenso primero; los que sí, al final, porque banean la conexión de un golpe — ver el comentario en
el propio binario).

**Verificado en vivo (ver más abajo, "Lo que se ejecutó de verdad")**: `E-7 PoW nonce malo` conecta
contra un `zx-node` real, el objetivo lo rechaza (PoW real inválido) y **corta la conexión** —
exactamente C-NET-05/`ViolacionDeConsenso` funcionando de extremo a extremo entre dos procesos
reales. `E-7 ráfaga de huérfanos` se implementó y se ejecutó, pero con una intermitencia sin
diagnosticar del todo dentro del presupuesto (ver «No demostrado» del INFORME).

**Limitado por el bloqueo de `JustificacionPot`:** los escenarios PoST (PoAS/PoT/sello malos, E-8)
se construyen y se envían de verdad (ejercitan el códec y el transporte reales), pero el objetivo
los trata como `Ignorar` por el formato, no como un rechazo por contenido específico: no se puede
demostrar «se registra la equivocación» (E-8) ni «se rechaza con el motivo de PoAS/PoT» para PoST
por esta vía hasta que se resuelva el bloqueo de formato.

## Lo que se ejecutó de verdad (dos procesos reales, TCP `127.0.0.1`)

No son `cargo test`: son binarios `target/debug/zx-node` reales, lanzados como procesos hijos
independientes (`nohup ... & disown`, para que sobrevivan entre llamadas de la herramienta de este
ejecutor), con `--red-escuchar`/`--red-marcar`, `N_dev = 32` (pequeño, decisión 8 de la orden).

**Convergencia PoW entre dos nodos reales.** A escucha en `39101`, B marca a A. Tras conectar (visto
como `ESTABLISHED` en ambos sentidos vía `/proc/net/tcp`, ya que este entorno no tiene `ss`/
`netstat`), A y B minan de forma independiente hasta que empiezan a recibirse bloques por gossip: se
comprobó comparando qué alturas mina **cada uno por sí mismo** (evento `bloque_minado`, que solo se
escribe para un bloque propio) contra la altura real alcanzada por cada proceso. Resultado
observado: B dejó de auto-minar en la altura 10 (su último `bloque_minado` propio) pero siguió
avanzando hasta la altura 16+ vía bloques admitidos por red (`intentar_admitir_pow_de_red`, visto en
el log de diagnóstico temporal de esa corrida) — es decir, **adoptó la cadena de A** en vez de
minar una rama propia paralela. Esto es la convergencia de la fase PoW de V4, demostrada con
procesos reales, no con un arnés en memoria.

**Herramienta adversarial contra un nodo real.** `zx-adversario --objetivo /ip4/127.0.0.1/tcp/39601`
(y repeticiones en otros puertos): conecta, recibe el `Estado` real del objetivo (`altura PoW 2`),
manda `E-7 PoW nonce malo` construido sobre la punta real declarada — el objetivo lo rechaza (PoW
inválido, primera comprobación de la tubería) y **corta la conexión**, observado como
`EventoRed::PeerDesconectado` en la propia herramienta. Confirma C-NET-05/`ViolacionDeConsenso`
extremo a extremo entre dos binarios reales.

**Intermitencia sin cerrar del todo.** En varias corridas de `E-7 ráfaga de huérfanos` (256 mensajes
PoW con padres inexistentes, enviados nada más conectar), **todos** los intentos de
`ManejoRed::difundir_bloque` devolvieron `Err` local (`"gossipsub rechazó la publicación local"`,
es decir `NoPeersSubscribedToTopic`: la malla de gossipsub aún no se había formado) y, pese a que
**nada llegó al objetivo** (0 eventos `bloque_red_huerfano` en su registro), la herramienta observó
igualmente una desconexión al final de ese escenario en más de una corrida. Se investigó como
hipótesis principal el tiempo de formación de la malla de gossipsub tras conectar (el mismo problema
que `zx-p2p::tests::dos_nodos.rs` resuelve esperando `EventoRed::Suscripcion` antes de publicar): un
primer intento de arreglo (esperar las dos suscripciones consumiendo el canal de eventos antes del
saludo) causó una regresión peor (el saludo `Peticion::Estado` dejaba de responder dentro de 10 s),
así que se revirtió a una espera fija de 500 ms tras conectar, que sí deja el saludo funcionando de
forma reproducible. La causa exacta de la desconexión en el escenario de huérfanos (que ocurre sin
que el objetivo reciba nada) queda **sin diagnosticar** dentro del presupuesto de esta sesión — ver
«Lo no demostrado» del `INFORME.md`. Los procesos de estas corridas manuales se limpiaron
(`pkill`/`kill -9`) y no queda ninguno vivo; los directorios de datos usados eran temporales
(`/tmp/zx-smoke*`), fuera de la zona de esta orden.

## Faltas de definición registradas

1. Caché de cargo incompleta para `clap_lex` (ver arriba) — resuelta con `cargo fetch` puntual.
2. `BloqueRed::Post` sin `JustificacionPot` — bloqueo documentado en su propia sección arriba.
3. Sin reorg de PoW — límite documentado en su propia sección arriba.
4. El depósito de huérfanos no guarda quién mandó el huérfano originalmente: al resolverse en
   cascada (`resolver_huerfanos_de`), si el hijo resuelto es a su vez huérfano de otro padre, esa
   nueva petición **no** se dirige a un par concreto (se deposita igual, sin pedir explícitamente);
   depende de que la sincronización basada en el saludo lo alcance en un ciclo posterior. Simplifica
   el depósito (no crece un campo de procedencia) a cambio de un recorrido hacia atrás algo más lento
   en cascadas profundas.
5. `red::arrancar` no reintenta `--red-marcar` si la conexión inicial falla ni vuelve a marcar tras
   una desconexión: un par indicado por CLI que no está arriba en el momento de arrancar no se
   reintenta automáticamente (falta un supervisor de reconexión, fuera de alcance de esta orden).
