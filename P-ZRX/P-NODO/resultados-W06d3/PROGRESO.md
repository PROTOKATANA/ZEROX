# PROGRESO — W06d3

Ejecutor único (Sonnet), sin subagentes. Zona: `/home/katana/zeo/ZEROX/deepseek/W06d3/`.

## Zona y entorno

- `ws.orig/` y `ws/` copian solo `Cargo.toml`, `Cargo.lock`, `rust-toolchain.toml`, `crates/`,
  `testdata/`, `ci/`, `.github/`, y el enlace `ws/PDF -> /home/katana/zeo/ZEROX/PDF` (y el mismo
  enlace en `ws.orig/`). Ningún documento de `P-ZRX/`, `D-ZRX/`, etc. se copió.
- `CARGO_HOME`/`CARGO_TARGET_DIR` dentro de la zona (`env.sh`). Caché de `.cargo-home` copiada de
  `deepseek/W06d2/.cargo-home` (2,6 GiB, `cp -a`, reflink — instantáneo). `Cargo.lock` verificado
  idéntico al de la raíz antes y durante el trabajo (`diff -q`).

## Decisión 1 — `BloqueRed::Post` lleva `JustificacionPot`

`zx_p2p::mensaje::BloqueRed::Post` ahora tiene el campo `justificacion: JustificacionPot`. El
códec (`zx-p2p/src/codec.rs::bloque_a_bytes`/`bloque_cuerpo`) para la familia PoST usa el mismo
orden de bytes que `zx_core::wire_dag::bloque_dag_a_bytes`/`bloque_dag_desde_bytes` (cabecera ‖
justificación ‖ cuerpo): en la decodificación se llama directamente a `bloque_dag_desde_bytes`, así
que no hay dos parsers para el mismo formato. `zx-p2p::limites::MAX_BLOQUE_RED_BYTES` crece en
`MAX_JUSTIFICACION_POT_CODIFICADA` (19 201 B); el resto de límites derivados (`MAX_GOSSIP_BYTES`,
`MAX_RESPUESTA_BYTES`) se recalculan solos y sus aserciones de compilación siguen en verde.

Sitios que construían `BloqueRed::Post` sin el campo (todos corregidos): `zx-p2p/src/codec.rs` (dos
tests), `zx-p2p/tests/dos_nodos.rs`, `zx-node/src/nodo.rs::admitir_post_interno` (la instantánea para
`VistaRed`), `zx-node/src/bin/zx-adversario.rs`.

## Decisión 2 — verificación real de PoST ajenos por red

Nuevo `Nodo::intentar_admitir_post_de_red` (espejo de `intentar_admitir_pow_de_red`): sin terminal
todavía → `Ignorar` (no juzgable, no es culpa del par); padre declarado (salvo el terminal mismo)
desconocido → huérfano (deposita y pide, igual que PoW); padre conocido e inválido → `Rechazar`; en
otro caso construye el `BloqueDag` y llama a `admitir_post_interno(verificar = true)`, que ya hacía
la verificación real (`verificar_cabecera_conjunta`, GHOSTDAG vía `Cadena::contexto_dag`, o
`ContextoTransicion` solo para el primer bloque tras el terminal).

**Simplificación declarada:** `EstadoCabeceraConjunta::Invalida` y `::Pendiente` llegan a
`intentar_admitir_post_de_red` como el mismo `ErrorNodo::BloquePropioRechazado` (mismo camino que ya
usaba `admitir_post_interno` para un bloque propio) y las dos se tratan como `Rechazar`.
Distinguirlas exigiría un tipo de error más rico en `admitir_post_interno`; no se hizo (fuera del
alcance de esta orden, no bloquea V4/V7).

## Decisión 3 — bifurcaciones PoW por FC-3

- `zx-cadena::Cadena`: nuevos `tips_pow` (puntas PoW conocidas, análogo a `tips_validas` para PoST)
  y `terminal_candidatos` (bloques PoW que, en su propia rama, ya cumplen `es_terminal_condiciones`).
  `admitir_pow` ya validaba cada bloque contra el estado de **su padre declarado** (`self.post.get`
  por hash, no por "última posición"): eso no tenía bug. El bug real era que `self.terminal` se
  fijaba con el **primer** candidato que llegaba y nunca se revisaba. Ahora, mientras
  `self.dag.is_none()` (sin ningún bloque PoST todavía), `Cadena::recalcular_terminal` elige, entre
  los candidatos, el de mayor `Estado::trabajo` acumulado (FC-3, `P-ZRX/P-TRANSICION/ORDEN-T01.md`
  §159: sin sufijo PoST, gana el de más trabajo, no el primero); se congela para siempre en cuanto
  se admite el primer bloque PoST. Nuevos accesores públicos: `mejor_punta_pow()` (para la
  plantilla de minado, exista o no ya un candidato a terminal) y `trabajo_pow(hash)`.
- `zx-node::Nodo`: `historial_pow` deja de ser "todo lo que se ha visto" y pasa a ser "la cadena de
  cabeceras de la punta PoW **seleccionada** hoy"; se reconstruye con `actualizar_seleccion_pow`
  cada vez que `Cadena::mejor_punta_pow()` cambia de rama (con la profundidad de la reorganización
  registrada, evento `reorganizacion_pow`). Nuevo campo `headers_pow: BTreeMap<hash, BlockHeader>`
  (todas las cabeceras PoW válidas conocidas, de cualquier rama): permite reconstruir el historial
  de **cualquier** punta (`historial_hasta`), no solo la seleccionada, y es la base para calcular el
  contexto de validación (target/altura/timestamp) contra el **padre declarado** de un candidato,
  nunca contra `historial_pow.last()` — así es como se admite una bifurcación real con el contexto
  correcto. `intentar_admitir_pow_de_red` ya no rechaza ("`bloque_red_fork_no_soportado`") un bloque
  que extiende un padre válido que no es la punta actual: lo admite, y si resulta más pesado,
  `actualizar_seleccion_pow` conmuta la selección.
- `ServicioPot` de verificación: como el terminal puede desplazarse (FC-3) mientras no exista ningún
  bloque PoST, se reconstruye si `self.terminal_servicio != Some(terminal)` (antes solo se construía
  una vez, `is_none()`), tanto en `admitir_pow_interno` como en `fase_regimen`.
- `CoinbasePropia` gana un campo `bloque: BlockHash` (la que la creó). Tras una reorganización con
  `profundidad > 0`, se podan las entradas cuyo bloque ya no está en la rama seleccionada: sin esto,
  `preparar_depositos` seguiría viendo una coinbase de la rama descartada como "madura y sin
  depositar" y construiría un depósito que gasta un `OutPoint` inexistente en la rama nueva.
  **Límite residual, no resuelto:** el marcado `depositada = true` (en el bucle que recorre `txs` de
  *cualquier* bloque admitido, propio o ajeno) no es sensible a la rama: si el bloque que gastó una
  coinbase queda descartado por una reorganización pero la coinbase en sí sigue viva en la rama
  nueva, `depositada` puede quedar en `true` sin que el gasto exista de verdad en el estado
  seleccionado (deposito perdido, no doble gasto: es conservador, no insegur o). No se ha observado
  en las pruebas de esta orden.

## Hallazgo (no bug mío, pre-existente desde W06d1): `preparar_depositos` reutiliza el mismo nonce

**Encontrado en vivo** en la primera ejecución real de V4 (proceso B, tres nodos reales): B murió
con `error fatal: bloque propio ... rechazado en la admisión: ErrNonce`.

`Nodo::preparar_depositos` lee `nonce = estado.garantias.get(&clave.pk).nonce_siguiente` **una vez**
fuera del bucle `for c in &self.coinbases`, y lo reutiliza para **cada** coinbase madura sin
depositar de la misma clave. Si una clave acumula más de una coinbase madura sin depositar antes de
que la primera tenga éxito (exactamente lo que pasa si el nodo pasa un rato minando en una rama que
tarda en conectarse con la red — ver el hallazgo de la decisión 4 más abajo), el bloque intenta
aplicar dos operaciones de garantía con el **mismo** `nonce` para la misma clave: la primera
incrementa `nonce_siguiente`, la segunda ya no coincide → `ErrNonce` → en modo estricto (PoW) invalida
el bloque entero → bloque propio rechazado → fatal (decisión 4 general de `ORDEN-W06d1`).

**No es un bug de esta orden** (el código de `preparar_depositos` no lo tocó ninguna decisión de
`W06d3`), pero **sí** impide demostrar V4 («0 bloques honestos rechazados») con procesos reales, así
que se corrige aquí: `preparar_depositos` ahora lleva un nonce local por clave, incrementado a
medida que añade depósitos de esa misma clave en el mismo bloque, sembrado con el
`nonce_siguiente` real del estado la primera vez que se usa esa clave.

## Hallazgo — diagnóstico de la decisión 4 (desconexión intermitente de W06d2)

En la misma ejecución de V4, el nodo B pasó **muchos** bloques (altura ~10 a ~58) sin poder admitir
**ningún** bloque de A/C: cada bloque ajeno llegaba por gossip como huérfano cuyo `padre_ausente` es
el hash del huérfano **anterior** (una cadena de huérfanos que nunca llega a su raíz). Causa
identificada por lectura: `intentar_admitir_pow_de_red`/`intentar_admitir_post_de_red` solo piden
activamente el padre que falta (`red.pedir(peer, Peticion::Bloques{...})`) cuando `origen` es
`Some(peer)` — y un bloque que llega por **gossip** (el camino normal de propagación en régimen)
siempre tiene `origen = None` (`TrabajoRed::BloqueDifundido`, "gossipsub no dice quién lo propagó").
La única vía que sí pide activamente el padre que falta es la sincronización basada en el saludo
(`sync::tarea_sincronizacion`), que solo se dispara **al conectar** y cuando el saludo declara una
altura mayor — no hay un reintento periódico. Si el primer bloque de una ráfaga se pierde (mesh de
gossipsub todavía no formado del todo tras conectar — la misma causa raíz que ya documentó
`PROGRESO.md` de `W06d2` para la intermitencia de la ráfaga de huérfanos del adversario), todo lo que
llega después queda depositado como huérfano **sin que nadie vuelva a pedir la raíz**, y el nodo
sigue minando su propia rama en paralelo indefinidamente — exactamente lo observado.

**Esto explica los dos síntomas de W06d2 con una sola causa:** la ráfaga de huérfanos del adversario
(0 eventos en el objetivo pese a que la herramienta "vio" una desconexión) y esta ejecución de V4
(un nodo aislado durante decenas de alturas). No es una penalización (comprobado por lectura:
`ManejoRed::desconectar`/`LimitesPorIp::puntuar` solo se llaman desde el camino de **sincronización**
rechazada, nunca desde gossip — ver `servicio.rs`); es sencillamente que nada vuelve a pedir la raíz
de una cadena de huérfanos que se formó mientras la malla de gossipsub todavía no estaba lista.

**Procedimiento que lo reproduce** (determinista en esta máquina, visto en la primera corrida):
arrancar A (escucha), luego B y C marcando a A casi simultáneamente; dejar minar; en el registro de
al menos uno de los tres aparece una racha larga de `bloque_red_huerfano` cuyo `padre_ausente` de
cada entrada es el `hash` de la entrada anterior, sin ningún `huerfano_resuelto` intermedio.

**Corrección aplicada, dentro del alcance de la decisión 3** (bifurcaciones PoW: sin ella, un nodo
aislado así nunca converge): la tarea de sincronización ya pide el localizador PoW al conectar; se
añade un **reintento periódico** del saludo (`Peticion::Estado`) a cada par ya conectado, no solo al
conectar, para que una divergencia de altura descubierta más tarde (como esta) dispare una nueva
petición de `CabecerasPow` aunque la conexión ya lleve tiempo abierta. Ver `red/sync.rs`.

## Hallazgo — `preparar_depositos`/`preparar_padres`, tres bugs reales encontrados con procesos reales

Ninguno de los tres es reproducible con el arnés en memoria (`MemoryTransport`) ni con un solo
proceso: los tres necesitan latencia de red real y bifurcaciones reales, exactamente lo que esta
orden pide demostrar. Los tres primeros están **corregidos y verificados** (suite completa en
verde tras cada uno); el cuarto queda **declarado, no resuelto**.

1. **Nonce de depósito repetido** (`preparar_depositos`): corregido, ver la sección de la decisión
   3 más arriba.
2. **`ErrPowTrasCorte` en un bloque propio** (`fase_pow`): la comprobación de
   `self.cadena.terminal().is_some()` solo vivía al final del cuerpo del bucle, tras admitir un
   bloque propio; si ese bloque resultaba obsoleto (`continue`, por una punta que avanzó mientras
   se minaba), el bucle volvía a la cabecera sin pasar por ella, y podía minar sobre un padre cuyo
   propio estado ya tenía terminal fijado (por un bloque **de red** admitido en el
   `procesar_trabajo_red_pendiente` de esa misma vuelta) → `ErrPowTrasCorte` → bloque propio
   rechazado → fatal. **Corregido:** el cheque se repite justo después de drenar el trabajo de red,
   antes de decidir si el bloque recién minado sigue sirviendo.
3. **Padre ajeno no registrado en el `ServicioPot` del hilo productor** (`regimen.rs`): el hilo
   productor mantiene su **propia** copia de `ServicioPot` (ver el docstring del módulo, escrito
   para `W06d1` sin red: "todo lo que produce y consume es propio"). En cuanto GHOSTDAG elige como
   padre un bloque **ajeno** (admitido por red en el bucle principal, con su propio
   `servicio_verificacion`), `producir_en_regimen` fallaba con «el padre seleccionado no está
   registrado en el `ServicioPot`»: la copia del hilo nunca supo que ese bloque existía.
   **Corregido:** `MsgBucle::Padres` ahora lleva también `(hash, slot)` de cada padre (seleccionado
   y extras); el hilo productor los registra en su propia copia (tolerando `BloqueDuplicado`,
   el caso normal de un padre que sí produjo él mismo) antes de producir.
4. **`Pot(PasadoIncompleto)` verificando un bloque propio, tras un nodo que se incorpora tarde al
   régimen — NO RESUELTO.** Observado una vez, en la tercera corrida real de V4: el nodo A cruzó el
   corte mucho después que B y C (2 `cambio_punta` frente a ~100 de los otros dos en el mismo
   instante), y su primer bloque propio de régimen se rechazó en la propia admisión con
   `EstadoCabeceraConjunta::Pendiente(Pot(PasadoIncompleto))`
   (`zx_post::pot_rango::verificar_rango_pot_fase_previa`: alguno de los padres declarados —
   seleccionado o un extra— no aparece en `InstantaneaPot::pasado()` del `ServicioPot` de
   **verificación** del bucle principal, `self.servicio_verificacion`, en el instante de verificar).
   Se investigó por lectura (no se reprodujo con instrumentación adicional, por presupuesto): cada
   padre directo de un bloque, para ser un padre válido según `Cadena::tips_validas()`, tuvo que
   pasar antes por `admitir_post_interno` con éxito, que llama **incondicionalmente**
   `actualizar_servicio_verificacion` (y por tanto `registrar_validado`) al terminar — así que en
   teoría todo padre válido en `Cadena` debería estar ya registrado en `servicio_verificacion` para
   cuando se le referencia. No se encontró, dentro del presupuesto de esta sesión, el hueco exacto
   entre esas dos vistas que permite que ocurra lo observado; es plausible que tenga que ver con la
   ventana de retención (`podar()`, 4096 slots — no debería agotarse en una sola ráfaga de
   alcance de ~100 bloques, pero no se descartó con una prueba dirigida) o con algún camino de
   admisión que no pase por `admitir_post_interno` de la forma asumida. **Efecto:** un nodo que se
   incorpora mucho más tarde que sus pares a la fase de régimen puede fallar al producir su primer
   bloque propio. **No impidió** que los otros dos nodos de esa misma corrida siguieran produciendo
   y conviniendo sin caerse (~100 `cambio_punta` cada uno). Procedimiento que lo reprodujo una vez:
   arrancar los tres nodos casi simultáneamente, dejar minar sin intervención; si uno de los tres se
   retrasa lo bastante en cruzar el corte, su primer bloque de régimen puede caer así. Queda para un
   encargo futuro con presupuesto para instrumentar `servicio_verificacion`/`Cadena` en paralelo.

## Hallazgo — una corrida real tardó (o nunca llegó a) cruzar el corte pese a no fallar — NO RESUELTO

**Encontrado en vivo**, corrida final de V4 (tres procesos limpios desde el génesis, mismo
`--semilla`, `--claves 0/1/2` distintas, `N_dev` pequeño): los tres nodos minaron durante casi 9
minutos, llegaron a la altura ~290 **sin ningún error ni bloque propio rechazado**, con
`reorganizacion_pow` casi inexistente (2 en A, 0 en B, 0 en C — no es un problema de bifurcaciones
constantes) y, sin embargo, **ninguno fijó el terminal** (`cambio_punta` en 0 los tres). Con
`H_corte_min = 30` y `W_min` = 30 veces el trabajo de un solo bloque a la dificultad inicial, ni la
altura ni el trabajo acumulado explican el bloqueo: a la altura 290, sobra holgura en los dos. Debe
ser `Φ` (`K_min = 3` claves con `activo ≥ q = 10 ZZK` cada una, `S_min = 30 ZZK` en total) lo que no
se satisface, pero **no se encontró el motivo dentro del presupuesto de esta sesión**.

Se leyó el camino completo del depósito para descartar hipótesis, sin encontrar el fallo:
`preparar_depositos` construye el depósito con el `nonce` correcto (arreglado antes, ver arriba);
`aplicar_garantia` lo acredita como `Pendiente` con `madura_en_altura = altura_del_depósito +
M_dep(3)`; `Aplicador::promover`, llamado en **cada** bloque PoW antes de aplicar sus propias
transacciones, mueve cualquier pendiente vencido a `activo`. Ese mismo camino (con tres claves en
**un solo** proceso) es exactamente lo que prueba `tests/integracion.rs` en verde (455 s). La
diferencia de esta orden es que las tres claves viven en **tres procesos separados**, cada uno con
su propio `self.coinbases` (solo su propia clave) — pero `Φ` se evalúa sobre `Estado::garantias`,
que es parte del estado compartido por red, así que en teoría un depósito de cualquiera de los tres
debería contar igual venga de quien venga. No se instrumentó `activo`/`pendientes` en vivo para
confirmar en qué paso se pierde (presupuesto agotado); es la hipótesis más probable, no un hecho
verificado.

**Efecto:** con el código de esta orden, en la corrida final no se pudo demostrar V4 de extremo a
extremo (cruce del corte con los tres procesos). Corridas **anteriores** de la misma sesión, con
versiones intermedias del código (antes de los últimos dos arreglos de esta lista), **sí** cruzaron
el corte con dos de los tres procesos y produjeron más de 100 bloques PoST en régimen sin caerse
(ver `logs/v4-real-1/`) — así que el mecanismo de fondo (verificación y admisión de PoST por red,
decisión 2) se demostró funcionando; lo que no se pudo repetir de forma limpia en la versión final
fue el cruce del corte con tres procesos deposiando cada uno su propia clave. Ver el veredicto y la
tabla V1–V9 en `INFORME.md` para el alcance exacto de lo demostrado y lo no demostrado.

## Verificación

Ver `INFORME.md` para la tabla V1–V9, los procesos reales lanzados y sus registros
(`logs/v4-real-1/`).
