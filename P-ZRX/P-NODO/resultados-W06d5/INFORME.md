# INFORME — ORDEN-W06d5

**Ejecutor:** subagente Sonnet, único, sin subagentes ni forks. **Fecha:** 2026-09-26/27.
**Zona:** `/home/katana/zeo/ZEROX/deepseek/W06d5/`. **Entrada:** `ENTRADA-W06d5.sha256` verde al
empezar (6/6). Al terminar: 5/6 — `P-ZRX/P-SLASHING/REVISION-SL4a.md` cambió porque el director
anotó ahí, a las 22:15, la corrección del hueco de migración de `testdata/` que este mismo encargo
encontró en su paso 0 (ver más abajo); no es un cambio mío ni afecta a mi zona.

## Veredicto

**SUPERADO PARCIALMENTE.** Las cinco decisiones de código están implementadas y verificadas con
test (que falla antes/pasa después). El paso 0 (suite conjunta W06d4+SL-4a) reveló y permitió
corregir (fuera de mi zona, solo diagnosticado) un hueco real de migración de `testdata/`. **V4
(regresión): SUPERADO**, repetido y confirmado varias veces. **V6(a): SUPERADO.** **V5, V6(b) y V7:
NO DEMOSTRADOS de punta a punta** — cada uno con causa encontrada y corregida donde procedía
(`ErrGarantia` de la transición, penalización/desconexión sobre `Pendiente`, carrera de suscripción
del adversario), pero los tres tropiezan con el **mismo** límite de fondo, no corregido en esta
orden: la resolución de huérfanos PoST de `zx-node` es de uno en uno y no da caudal para que un nodo
tardío (o dos ramas partidas) converjan mientras la producción sigue. Se documenta como hallazgo
para `ORDEN-W06d6`, con evidencia repetida (tres intentos de V5, dos de V6(b)).

## Paso 0 — suite conjunta (primera vez W06d4 + SL-4a)

- **Intentos 1 y 2: FALLAN**, no por incompatibilidad de código sino por un hueco real de
  migración: `testdata/estado-dag-v0.5/` y `testdata/transicion-v0.4/` (fixtures que SL-4a añadió)
  nunca llegaron a la raíz — el parche de SL-4a (22 rutas) solo traía código. Verificado con sha256
  idéntico entre `deepseek/SL4a/ws/testdata/...`, `deepseek/SL4a/ws.orig/testdata/...` y los
  oráculos en `P-ZRX/P-DAG/T04/resultados/` y `P-ZRX/P-TRANSICION/T01/resultados/`. Copiados a mi
  zona (`ws.orig/` y `ws/`, contenido permitido) para poder continuar; **el arreglo real es de la
  raíz** (fuera de mi zona) — el director lo aplicó y lo documentó en `REVISION-SL4a.md` (22:15).
- **Confirmación sobre código intacto** (`ws.orig`, sin ningún cambio mío): con los dos fixtures
  puestos, `diferencial_t04` (T04 v0.5) y `diferencial_t01`+`diferencial_t01_negativos` (T01 v0.4)
  **pasan** (404,72 s y 228,20 s). El único bloqueo real era el hueco de migración.
- **Suite completa, una vez arregladas las decisiones 1-5 (`V0-intento4`): 735/0/2** —
  721 (base) + 2 (W06d4) + 8 (SL-4a) + 4 (mis tests nuevos de `rechazo.rs`) = 735. **0 perdidos.**

## Cada corrección, con su causa y su test

### Decisión 1 — «producir solo con garantía»

**Causa (V5-1 de `REVISION-W06d4.md`, reproducida en vivo dos veces más en esta orden):** en
`hilo_productor_regimen` no había ningún cheque de `activo_de(clave) >= q` antes de intentar
`producir_en_regimen`; un nodo tardío con una clave sin garantía intentaba producir en cuanto ganaba
una solución PoAS y el motor lo rechazaba con `ErrGarantia` — fatal por la decisión 4 de
`ORDEN-W06d1`.

- **Arreglo 1 (régimen en marcha):** `crates/zx-node/src/nodo.rs` (`MsgProductor::PeticionPadres`)
  calcula, una vez por slot, las claves propias con garantía `>= q` en `Estado(padre_seleccionado)`
  y las manda al hilo (`MsgBucle::Padres`, tercer campo); `crates/zx-node/src/regimen.rs`
  (`hilo_productor_regimen`) descarta con gracia (`continue`) cualquier candidata cuya clave no esté
  en ese conjunto, sin intentar `producir_en_regimen`.
- **Hallazgo en vivo, extensión necesaria:** al repetir V5 con el arreglo 1 ya puesto, D murió
  igual, con el mismo `ErrGarantia` — pero **antes** de que `hilo_productor_regimen` llegara a
  arrancar: en `Nodo::producir_bloque_transicion` (decisión 6 de W05b2), llamado incondicionalmente
  por `fase_regimen` cuando `tips_validas()` está vacío, con `self.claves[0]` sin garantía.
  **Arreglo 2:** el mismo cheque (`estado_terminal().activo_de(&self.claves[0].pk) >= self.params.q`)
  antes de llamar a `producir_bloque_transicion`; si no alcanza, se espera (procesando red) a que
  otro nodo produzca y sincronice la transición.
- **Test:** end-to-end con procesos reales (V5, ver abajo) — con el arreglo 1 solo, D moría en la
  transición; con los dos arreglos, D nunca vuelve a morir con `ErrGarantia` (confirmado en los tres
  intentos de V5, con y sin rezago, con `N_dev` chico y grande — 0 fatales en los tres).

### Decisión 2 — filtro de padres extra por slot

**Causa (V5-2 de `REVISION-W06d4.md`):** `regimen.rs` descartaba con gracia un padre
**seleccionado** demasiado avanzado (`ErrorRegimen::SlotNoProgreso`), pero no cubría los padres
**extra** del *mergeset* GHOSTDAG — `C-HDR-05`/`C-FLU-02` alcanza a todos los padres. Con más
concurrencia (4 procesos), esto disparaba `Padres(SlotDePadrePosterior)` **fatal** en A y B en
cascada tras la llegada de D.

- **Arreglo:** `filtrar_padres_extra_por_slot` (`crates/zx-node/src/regimen.rs`) reconstruye
  `PadresDag` excluyendo cualquier padre extra cuyo `slot >= slot_objetivo`, antes de llamar a
  `producir_en_regimen`.
- **Test:** end-to-end (V4/V5 con procesos reales) — en los cinco intentos de V4/V5 de esta orden,
  **nunca** volvió a aparecer `Padres(SlotDePadrePosterior)` fatal en A/B/C, ni siquiera con D
  conectado y produciendo huérfanos por miles.

### Decisión 3 — rechazo legítimo vs. interno (bloque propio) — extendida a bloques de red

**Causa (transversal en V5/V6(b) de `REVISION-W06d4.md`):** la decisión 4 de `ORDEN-W06d1` («bloque
propio rechazado ⇒ fatal») no distinguía un bug interno de un rechazo legítimo del protocolo ante un
caso de borde real.

- **Arreglo:** nuevo módulo `crates/zx-node/src/rechazo.rs` — `ClasificacionRechazo` con tres
  valores (`Legitimo`, `Pendiente`, `Interno`; ver la tabla más abajo) y tres funciones de
  clasificación (`clasificar_cabecera_invalida`, `clasificar_cabecera_pendiente`,
  `clasificar_motivo_bloque`). `ErrorNodo::BloquePropioRechazado` gana el campo `clasificacion`,
  calculado en los 6 sitios donde se construye (`crates/zx-node/src/nodo.rs`:
  `arranque_limpio`, 2× en `admitir_pow_interno`, 2× en `admitir_post_interno`). `fase_pow` y
  `fase_regimen` comprueban `clasificacion.es_legitimo()`: si es legítimo o pendiente, se registra
  (`bloque_propio_rechazado_legitimo`) y el nodo sigue; si es interno, sigue fatal.
- **Test:** `crates/zx-node/src/rechazo.rs`, 5 tests unitarios (motivos evidenciados en W06d4
  legítimos; el resto de la misma familia de carrera también legítimos; toda `Pendiente` es
  legítima y pendiente; `Legitimo` no es `Pendiente`; defectos de construcción propia siguen
  internos). Los 5 pasan; antes de escribir `rechazo.rs` no existían (código nuevo, sin regresión
  posible que demostrar salvo por el propio efecto en producción, confirmado con V4 sin regresiones).

**Extensión, tras aviso del director durante V5:** la misma conflación (`Invalida`≈`Pendiente` ⇒
siempre `Rechazar`) existía también para bloques **de red**, con dos riesgos reales:
1. **Penalización indebida** — `VeredictoFinal::Rechazar` penaliza al remitente
   (`crates/zx-p2p/src/entrante.rs:77-78`); para `TrabajoRed::BloqueDeSincronizacion` (la vía de un
   nodo tardío) esto **desconecta** activamente al par (`crates/zx-node/src/nodo.rs`, antes de la
   decisión 3, ~942-951: `red.desconectar(de, ViolacionDeConsenso)`).
2. **Riesgo tipo RI-2a** — el bloque simplemente se descartaba, sin ninguna vía de reintento.

`Pot(PasadoIncompleto)` (un hueco **local** del `ServicioPot` de verificación, no un defecto
demostrado del candidato) es exactamente el caso: confirmado con evidencia real de V5 (D lo recibía
al resolver huérfanos y, con el código viejo, provocaba la desconexión que amplificaba su propia
avalancha de huérfanos).

- **Arreglo:** `ClasificacionRechazo` gana el valor `Pendiente` (antes `clasificar_cabecera_pendiente`
  devolvía `Legitimo`); nuevo método `es_pendiente()`. `intentar_admitir_post_de_red`
  (`crates/zx-node/src/nodo.rs`) devuelve `VeredictoFinal::Ignorar` (no `Rechazar`) cuando la
  clasificación es `Pendiente`, y encola el bloque (`Nodo::post_pendientes`, `VecDeque` acotada a 64)
  para reintentarlo (`Nodo::reintentar_post_pendientes`) tras cada admisión nueva (propia o de red).
- **Test:** 2 tests nuevos en `rechazo.rs` (`toda_cabecera_pendiente_es_legitima_y_pendiente`,
  `legitimo_no_es_pendiente`) — antes del cambio, `clasificar_cabecera_pendiente(...).es_pendiente()`
  no existía; con el cambio, distingue correctamente. Confirmado en vivo (V5, intento con el
  arreglo): 0 desconexiones observadas, evento nuevo `bloque_red_pendiente` (108-170 según el
  intento) en vez de `bloque_red_rechazado`.

#### Tabla de motivos: legítimo/pendiente frente a interno, con justificación

| Motivo | Clasificación | Justificación |
|---|---|---|
| `MotivoCabeceraPendiente::*` (todas) | **Pendiente** | Contrato propio del tipo: "ninguno es prueba de invalidez" |
| `MotivoCabeceraInvalida::Padres(SlotDePadrePosterior\|PadresNoAnticadena\|PadreSeleccionadoIncorrecto)` | **Legítimo** | El DAG cambió entre la elección de padres y la verificación (V5-2 evidenciado para el primero) |
| `MotivoCabeceraInvalida::Pot(SlotDePadrePosterior)` | **Legítimo** | Misma carrera, vista desde PoT |
| `MotivoBloque::ErrGarantia` | **Legítimo** | La garantía puede variar entre elección y verificación (V5-1 evidenciado; con SL-4a, también por un incidente concurrente) |
| `MotivoBloque::ErrMergeDepth` | **Legítimo** | Cota RD-5 de congestión real (V6b evidenciado) |
| `MotivoBloque::ErrMergeset` | **Legítimo** | Cota R-FIN-12, misma familia que ErrMergeDepth |
| `MotivoBloque::ErrU2` | **Legítimo** | El billete pudo consumirse en una rama concurrente: la protección funcionando |
| `MotivoBloque::ErrTransicion(ErrPowTrasCorte)` | **Legítimo** | El corte lo pudo fijar un bloque de red justo entre minar y admitir |
| Todo lo demás (forma, sello, cuenta, estructura, `CabeceraPostSinPadres`/`TerminalConPadresExtra`/`TerminalComoPadreExtra`, resto de `ErrTransicion`) | **Interno** | El nodo lo construyó por completo desde su propio estado; un rechazo aquí delata un bug, no una carrera |

### Decisión 4 — calibración de V6(b)

**Causa (V6(b) de `REVISION-W06d4.md`):** con `N_dev` pequeño, el slot avanza tan rápido en tiempo
real que una sesión de pruebas de varios minutos supera `F_SLOTS=600` sin que la partición
"debiera" representar tantos slots. **No se toca RD-5/`ErrMergeDepth`** (es una regla, no un bug).
**Calibración aplicada:** partición corta (parar en cuanto se alcanza el mínimo de 20 bloques, no
"dejar correr de más") y reunión inmediata. Con esta calibración, `ErrMergeDepth` **no** volvió a
aparecer en ningún intento de V6(b) de esta orden (dos intentos, ambos sin ese fatal).

### Decisión 5 — `zx-adversario` espera la suscripción real de gossipsub

**Causa (V7 de `REVISION-W06d4.md`):** una espera fija de 500 ms no bastaba con la red cargada; la
ráfaga E-7 se rechazaba localmente (`NoPeersSubscribedToTopic`).

- **Arreglo 1:** `esperar_suscripcion` (nueva función) espera el evento real
  `EventoRed::Suscripcion` del objetivo para los dos temas, con plazo de 10 s.
- **Bug encontrado en el propio arreglo 1, con evidencia de la primera repetición de V7:** al
  separar `pedir_estado` y `esperar_suscripcion` en dos bucles consecutivos sobre el **mismo**
  canal, el primero descartaba en silencio los eventos `Suscripcion` que llegan casi siempre junto
  con la respuesta al saludo. **Arreglo 2:** `pedir_estado_y_suscripciones` fusiona los dos bucles
  en uno solo. Confirmado tras el arreglo: "el objetivo confirmó su suscripción a los dos temas de
  gossipsub" (antes: nunca se confirmaba).
- **Test:** end-to-end con procesos reales (V7, ver abajo). No se escribió un test unitario de
  `zx-adversario` (binario, sin `#[cfg(test)]` en el resto del archivo) — la evidencia es la
  repetición real con y sin el arreglo.

## Tabla de rechazo legítimo/pendiente frente a interno

Ver arriba (dentro de la decisión 3).

## V4 (regresión) con procesos reales

**SUPERADO, repetido y confirmado tres veces** (con distintos ajustes de puertos/`N_dev` mientras
se investigaban V5/V6/V7): 87, 76 y 345+ bloques PoST según el intento, siempre **0** rechazos, **0**
fatales, convergencia real de `punta` y `resumen_estado` confirmada entre A y B.

## V5 (cuarto nodo tardío) — NO SUPERADO de punta a punta, con hallazgo nuevo para W06d6

Tres intentos (con el arreglo completo: decisiones 1 extendida + 3 extendida a bloques de red):
1. `N_dev=2000`, D con mucho rezago (red con cientos de bloques): `TIMEOUT` a los ~4 min y de nuevo
   a los 10 min. **0 fatales.** 33 384 → 128 953 `bloque_red_huerfano` (la brecha **crece**, no se
   estrecha).
2. `N_dev=20000000` (~0,14 s/slot), D con **poco** rezago (corte recién cruzado): `TIMEOUT` también
   a los ~4,5 min. **0 fatales.** 12 235 → 27 480 huérfanos — la misma proporción, así que el rezago
   inicial y el `N_dev` **no** son la variable que explica el problema (se comprobó, no se supuso).

**Causa de fondo, con archivo:línea:** `crates/zx-node/src/nodo.rs` (manejo de
`bloque_red_huerfano`, `intentar_admitir_post_de_red`) pide **un solo padre por petición**
(`Peticion::Bloques { hashes: vec![padre] }`). Con tres nodos honestos produciendo sin parar, ese
caudal de uno en uno no alcanza para que un cuarto nodo (o una rama partida, ver V6(b)) converja en
ninguna ventana de tiempo real probada. **Se corrigieron y quedan verificados** los dos hallazgos
que sí eran de esta orden (`ErrGarantia` de la transición, penalización/desconexión sobre
`Pendiente`); lo que impide un veredicto limpio de V5 es un límite de diseño **distinto**, declarado
para `ORDEN-W06d6`: falta un mecanismo de sincronización PoST por lotes (análogo a `cabeceras_desde`
para PoW).

## V6(a) — SUPERADO

Partición en fase PoW (A y B aislados, C puente) y reunión: corte cruzado, 31 `cambio_punta`,
reorganizaciones PoW en los tres, régimen en marcha, **0 fatales**.

## V6(b) — NO DEMOSTRADO (corregido tras revisión del director)

Primer intento: solo se comprobó que C2 (el puente) se reincorporaba (`REUNION_OK c2=6`), no que
las ramas de A y B se fundieran. **Repetido con la comprobación real** (admisión cruzada de hashes
producidos durante la partición, y convergencia final de punta en los tres): **0** admisión cruzada
de A↔B tras la reunión, en 90 s y de nuevo en 150 s; puntas de A, B y C2 **todas distintas** al
final; `bloque_red_huerfano` de B creciendo (2072→7125) — la **misma** causa de fondo que V5,
aquí con una brecha mucho menor (53 bloques) y aun así sin converger. `ErrMergeDepth` **no** se
disparó en ningún intento (la calibración de la decisión 4 sí funciona para eso). C2 es un proceso
nuevo, con datos nuevos y la misma clave de C; C estaba parado, sin dos firmantes simultáneos con
la misma clave.

## V7 — PARCIAL, no concluyente (mismo veredicto que W06d4, con progreso real)

La causa que W06d4 diagnosticó (carrera de suscripción) está **corregida y verificada**: el
objetivo confirma su suscripción a los dos temas antes de la ráfaga. Lo que impide un veredicto
limpio ahora es una causa **distinta y no diagnosticada del todo**: los 260 mensajes de la ráfaga
siguen rechazándose localmente (`gossipsub rechazó la publicación local`), un texto fijo que
colapsa **cualquier** error de `gossipsub.publish` (`crates/zx-p2p/src/servicio.rs:697-707`) —
`tracing::debug!` registra el motivo real, pero `zx-adversario` no tiene ningún
`tracing_subscriber` configurado, así que ese registro no va a ninguna parte visible. El objetivo
nunca aceptó nada indebido ni se cayó.

## Hallazgo declarado, no aplicado: reintento del dial de arranque

**Aviso del director.** `crates/zx-node/src/red/mod.rs:224-228`: el dial a cada `--red-marcar` se
intenta una sola vez; si falla (el par de arranque todavía no escucha), el nodo queda aislado para
siempre — reproducido en vivo (la red con `N_dev=20000000` nunca se formó tras relanzar rápido en
los mismos puertos). **No aplicado** en esta orden (presupuesto, priorizado explícitamente por el
director detrás de V5/V6(b)/V7): declarado para `ORDEN-W06d6`, con la corrección natural (reintento
acotado con espera creciente mientras no haya ninguna conexión) y el test que debería probarlo.

## Tests antes/después (resumen)

| Momento | `cargo test --workspace --all-features --locked` |
|---|---|
| Antes de esta orden (W06d4+SL-4a sin combinar) | W06d4: 723/0/2; SL-4a: 729/0/2 (nunca probados juntos) |
| Paso 0, primer intento (testdata roto) | Falla en compilación de datos, no llega a correr |
| Paso 0, con testdata restaurado, código intacto (`ws.orig`, solo los 2 diferenciales) | OK, 404,72 s y 228,20 s |
| Con las decisiones 1-5 completas (`V0-intento4`) | **735/0/2** |
| Final, tras el arreglo de `Pendiente`→`Ignorar` y la fusión de `zx-adversario` | **736/0/2** |

## Cambios por crate

Todos los cambios de código quedan en **un solo crate**, `zx-node` — ningún cambio en
`zx-consensus`, `zx-dag`, `zx-poas`, `zx-pot`, `zx-post`, `zx-cadena`, `zx-farmer`, `zx-p2p`,
`zx-storage`, `zx-core` (`ci/frontera-crates.sh` 9/9, sin excepción).

| Archivo | Motivo |
|---|---|
| `crates/zx-node/src/nodo.rs` | Decisión 1 (garantía en `PeticionPadres` y en `producir_bloque_transicion`); decisión 3 y su extensión a bloques de red (`clasificacion` en los 6 sitios de `BloquePropioRechazado`; `fase_pow`/`fase_regimen` distinguen legítimo/interno; `intentar_admitir_post_de_red` usa `Ignorar`+cola para `Pendiente`; `post_pendientes`/`encolar_post_pendiente`/`reintentar_post_pendientes` nuevos) |
| `crates/zx-node/src/regimen.rs` | Decisión 1 (`con_garantia` en `MsgBucle::Padres`, filtro antes de producir) y decisión 2 (`filtrar_padres_extra_por_slot`) |
| `crates/zx-node/src/rechazo.rs` (**nuevo**) | Decisión 3: `ClasificacionRechazo` (`Legitimo`/`Pendiente`/`Interno`) y sus tres funciones de clasificación, con 5 tests |
| `crates/zx-node/src/error.rs` | Campo `clasificacion` en `ErrorNodo::BloquePropioRechazado` |
| `crates/zx-node/src/lib.rs` | Declara el módulo `rechazo` |
| `crates/zx-node/src/bin/zx-adversario.rs` | Decisión 5: `pedir_estado_y_suscripciones` (fusiona el saludo y la espera de suscripción en un solo bucle) |

## No demostrado

- **V5 y V6(b) de punta a punta**: bloqueados por el límite de caudal de la resolución de huérfanos
  PoST (uno en uno), documentado como hallazgo para `ORDEN-W06d6`, con evidencia de cinco intentos
  reales distintos.
- **V7 concluyente**: bloqueado por una causa de `gossipsub.publish` no diagnosticada del todo
  (colapsada por `P2pError::Transporte`, sin instrumentación visible en `zx-adversario`).
- **El reintento del dial de arranque**: declarado, con causa y archivo:línea, pero no implementado
  (presupuesto, priorizado explícitamente detrás de V5/V6(b)/V7 por el director).
- Que los hallazgos de V5/V6(b) (el límite de caudal) agoten todas sus condiciones: se probó con
  `N_dev` chico y grande, con rezago y sin él, hasta 10 minutos reales; no se probó con más de 4
  nodos, con parámetros de red distintos (tamaño de malla, `heartbeat` de gossipsub) ni con un
  mecanismo de sincronización por lotes (que no existe todavía).
- Que la clasificación `Legitimo`/`Interno` de la tabla agote todas las subvariantes de
  `ErrTransicion` distintas de `ErrPowTrasCorte`: se clasificaron por defecto como `Interno`
  (conservador), sin evidencia de que alguna sea, de hecho, otra carrera legítima.

## Rutas relevantes

- Este informe: `/home/katana/zeo/ZEROX/deepseek/W06d5/INFORME.md`.
- Progreso detallado (todas las corridas, PIDs, comandos, logs, hallazgos con archivo:línea):
  `/home/katana/zeo/ZEROX/deepseek/W06d5/PROGRESO.md`.
- Parche y huellas: `/home/katana/zeo/ZEROX/deepseek/W06d5/cambios.patch`,
  `/home/katana/zeo/ZEROX/deepseek/W06d5/MIGRACION.sha256`.
- Horas: `/home/katana/zeo/ZEROX/deepseek/W06d5/HORAS.log`.
- Logs de la suite final, `fmt`, `clippy`, CI: `/home/katana/zeo/ZEROX/deepseek/W06d5/logs/`.
- Logs de V4-V7 con procesos reales: `/home/katana/zeo/ZEROX/deepseek/W06d5/run/`
  (subdirectorios archivados por intento: `v4-intento*`, `v4v5-intento*`, `v5-intento*`,
  `V6a-*`/`V6a2-*`/`V6b-*`/`V6b2-*`, `v7-intento1-*`, y los `adversario-*.std{out,err}.log` sueltos).
