# PROGRESO — ORDEN-W06d1 (relanzamiento)

Ejecutor: Sonnet (único, sin subagentes). Bitácora de decisiones y faltas de definición, registradas
**antes** de editar, con la lectura más conservadora.

## Lectura previa

`ORDEN-W06d1.md` completa (incluida «Relanzamiento»), `V-ZRX/LINEO.md` completo, `PLAN-W06.md`,
`PERFIL-DEV-v0.md`, `ESCENARIOS-0.0.1.md` §1, revisiones W05b2/W05b3/W06a/W06b/W06c. Código migrado:
`zx-cadena`, `zx-storage`, `zx-post` (servicio_pot, contexto_transicion, cabecera_conjunta,
productor, productor_regimen), `zx-farmer` (farmer, productor_poas), `zx-poas` (protocolo_dev,
historia, verificador), `zx-consensus` (genesis, minero_dev, dificultad, verificador, transicion),
`zx-core` (tx, firma, preimage). `crates/zx-post/tests/regimen.rs` se usó como referencia de cableado
real (contextos reales, no mocks): confirma exactamente cómo `ContextoDag`, `ServicioPot` y
`ParcelaDisco` encajan.

## Decisiones del ejecutor (LINEO §"reglas pertinentes": corrección, referencia independiente, casos
límite, control de recursos, reproducibilidad, trazas)

1. **`AlmacenGhostdag::padre_seleccionado` es la vía real de GHOSTDAG** (ya implementa `ContextoDag`
   sobre el almacén real, con `comparar_sp` — ver `crates/zx-dag/src/ghostdag.rs:1507`). Satisface la
   exigencia de «Relanzamiento» punto 3 sin duplicar el algoritmo: el accesor mínimo que hace falta en
   `zx-cadena` es exponer una referencia de solo lectura a su `AlmacenGhostdag` interno (campo `dag`,
   hoy privado). Se añade `Cadena::contexto_dag(&self) -> Option<&AlmacenGhostdag>` con doc y test.
2. **`AlmacenGhostdag::admitir` está explícitamente vetado para `zx-node`** (su propio doc: «ninguna
   ruta de `zx-node` la llama»). La vía correcta es la que usa `zx-cadena::Cadena::admitir` con
   `BloqueCadena::Post(BloquePost{ sr, distancia, identidad, .. })`, precomputando esos tres campos
   fuera (con `RangoSolucionValidado`/`cabecera.rango_solucion` ya verificado por
   `verificar_cabecera_conjunta`, `zx_poas::verificar_solucion_poas` para la distancia, e
   `identidad_de_cabecera` para la identidad).
3. **Límite real encontrado en W06a (`BloquePost.identidad: u64`, dominio de fixture).** `C-GD-07`
   exige la tupla literal `(public_key, sector_index, history_size, chunk, slot)`
   (`IdentidadGhostdag::Billete(IdentidadTicket)`), pero `zx-cadena::bloque::BloquePost` (migrado en
   W06a, revisado y `SUPERADO CON RESERVA`) solo acepta `identidad: u64` en el dominio
   `IdentidadGhostdag::de_fixture` (`Sintetica`/`SinBillete`). No es un accesor que falte: es el tipo
   de un campo de una pieza ya migrada y revisada. Aplicando «para y avisa, no lo parches en
   silencio»: **no se modifica `zx-cadena`** (cambiar el dominio de identidad tocaría el oráculo
   diferencial T04 que W06a ya superó). Se aplica la lectura más conservadora posible dentro de esa
   restricción: `zx-node` deriva `identidad_u64 = u64::from_be_bytes(identidad_de_cabecera(cab)
   .huella()[..8])` (SHA3-256 con dominio propio, `zx-dag/src/identidad.rs`), con `0 → 1` para no
   colisionar jamás con el centinela `SinBillete`. **Esto no es inyectivo** (la huella de 32 B se trunca
   a 8) y por tanto **no reproduce exactamente C-GD-07/U2** para identidades reales: es un compromiso
   documentado, no una prueba de unicidad de billete. Con SHA3-256 de por medio la colisión práctica en
   una red dev de 3 claves y unos pocos miles de bloques es despreciable, pero se declara sin
   maquillar en `INFORME.md` §"lo no demostrado". Alternativa rechazada: ampliar `BloquePost.identidad`
   a `IdentidadGhostdag` completo — es un cambio de forma de una pieza ya migrada y revisada; excede
   el arreglo "mínimo, documentado, uno a uno" que autoriza la orden.
4. **Dependencias nuevas:** se añade `clap = "=4.6.6"` a `[workspace.dependencies]` (pre-aprobada por
   la orden §3.1). `tracing = "=0.1.44"` ya existe en el workspace (de `zx-p2p`); no se usa aquí para
   no mezclar un logger genérico con el registro estructurado exigido. **No se añade `serde`/
   `serde_json`/`tokio`**: no son imprescindibles. El registro JSON de `ESCENARIOS-0.0.1.md` §1 se
   escribe a mano (esquema fijo, sin anidamiento) para no ampliar la lista de dependencias aprobada
   más allá de lo que la orden ya previó. El bucle usa `std::thread` + `std::sync::mpsc`, no `tokio`:
   no hay E/S de red ni asíncrona que lo justifique en esta orden (sin red).
5. **Hilos** (decisión 3 de la orden): bucle de consenso (hilo principal, dueño de `zx-cadena` y
   `zx-storage`); hilo minero PoW (recibe una plantilla, mina con `minero_dev::minar` y un
   `AtomicBool` de cancelación, devuelve el resultado; se detiene tras el corte); hilo PoT (dueño de
   `ServicioPot`, avanza slot a slot, es el reloj); hilo granjero (audita las parcelas locales al
   recibir cada slot del hilo PoT). El hilo PoT, al tener solución, pide al bucle los padres
   canónicos actuales (petición/respuesta por canal, ya que la selección real de padres lee
   `Cadena::contexto_dag()`) y llama él mismo a `producir_en_regimen` (es el único dueño de
   `ServicioPot`); envía el bloque producido al bucle para su verificación y admisión. Sin
   `Arc<Mutex<Cadena>>`: la única mutación de `Cadena` ocurre en el bucle; la lectura de padres para
   producir se hace por petición/respuesta, no por acceso compartido directo.
6. **`zx-storage` es la única persistencia (D-N03′)**: los bloques PoW/PoST admitidos y el registro de
   admisión. El registro estructurado (JSON) es un fichero *aparte*, no consensus-critical, indicado
   por la CLI.
7. **Resumen de estado (decisión 8):** `blake3` sobre una codificación canónica propia de `zx-node`
   (no existe en `zx-cadena` ni `zx-consensus`, confirmado por búsqueda) de UTXO + garantías + emisión
   del `Estado` de la punta seleccionada, sobre colecciones ordenadas (`BTreeMap`/`Vec` ordenado por
   clave canónica). Se documenta el formato exacto en el código (`zx-node/src/estado_resumen.rs`).

8. **Límite real encontrado en W06a (`inicializar_dag` de `zx-cadena` fija `max_padres = 3` y
   `mergeset_limite = 180`, constantes del oráculo T04, no configurables desde `Cadena::nueva`).**
   `PERFIL-DEV-v0.md` §4 dice «Máximo de padres: 15 (antiguo)», pero el DAG interno de `zx-cadena`
   —ya migrado y revisado— nunca acepta más de 3 padres por bloque PoST (`ErrorDag::
   DemasiadosPadresDag` → `MotivoBloque::ErrSinPadre`). No es un accesor que falte, es un límite de
   forma de una pieza ya migrada. Lectura más conservadora: `zx-node` construye siempre `PadresDag`
   con **como mucho 3** elementos (seleccionado + 2 extras), tomando las puntas más relevantes por
   `blue_work`/`sd`/id si hubiera más de 3. Con 3 claves propias en un solo proceso esto no debería
   ejercitarse en la práctica (el número de puntas vivas rara vez supera 3), pero se declara: la
   orden pide «≤ 15» y el nodo entrega «≤ 3» porque es lo que la pieza migrada admite.

9. **Arreglo mínimo a `zx-post` (documentado uno a uno, §5 de la orden).** `ServicioPot` no exponía
   forma de reconstruir su estado sin recalcular el flujo (`avanzar`/`avanzar_hasta` siempre llaman a
   `zx_pot::prove`). La decisión 7 exige exactamente lo contrario al reiniciar: reconstruir «desde
   las salidas PoT de las cabeceras almacenadas… no recalculando el flujo desde `T` (costaría el
   tiempo real transcurrido)». Se añadió `ServicioPot::insertar_calculado(slot, salida, portador)`
   (`crates/zx-post/src/servicio_pot.rs`): inserta una salida/portador ya calculados sin llamar a
   `prove`, exigiendo solo `slot > slot_actual()` (no `== slot_actual()+1` como `avanzar`): el flujo
   es único y global (D-P10), así que dos ramas o dos hermanos del mismo slot comparten exactamente
   la misma `salida(f, slot)` y los huecos intermedios sin bloque nunca son `sp` de nadie (`sp` es
   siempre el slot de un bloque admitido), no hace falta rellenarlos. Dos tests nuevos: reproduce
   exactamente lo que daría `avanzar` (`insertar_calculado_reproduce_avanzar`) y permite huecos pero
   no retroceder (`insertar_calculado_permite_huecos_pero_no_retroceder`). No cambia ningún
   comportamiento existente (es un método nuevo, no toca `avanzar` ni el resto del rasgo
   `InstantaneaPot`).

10. **Hueco encontrado en pruebas (V4): el primer bloque de régimen no tiene `contexto_dag`.**
    `Cadena::contexto_dag()` es `None` hasta la primera admisión PoST (`inicializar_dag` vive dentro
    de `Cadena::admitir_post`), así que el bloque de transición (decisión 6, `producir`, único padre
    posible: el terminal) no se puede verificar con el GHOSTDAG real porque todavía no existe. Se
    verifica ese único bloque con `zx_post::ContextoTransicion` (el contexto dev que `zx-post` ya
    define para exactamente este caso: un solo padre, sin ambigüedad de `sp`); todo bloque posterior
    usa el GHOSTDAG real de `Cadena::contexto_dag()`. No es el mismo riesgo que «Relanzamiento»
    punto 3 (que es sobre bloques con más de un padre candidato: ahí sí hay una elección que
    `ContextoTransicion` no comprueba).

## Errores propios encontrados y corregidos durante las pruebas (V3/V4)

Ninguno de estos es un límite de una pieza migrada: son bugs del código nuevo de esta orden,
encontrados por sus propios tests (V4) y corregidos antes de entregar.

1. **Persistencia ausente de los bloques PoW no génesis.** `admitir_pow_interno` nunca llamaba a
   `Almacen::admitir` salvo para el génesis (que se persiste aparte, en `arranque_limpio`). Un
   reinicio habría perdido toda la fase PoW. Corregido: se persiste (con `sync = true`) antes de
   admitir en `zx-cadena`, y solo en la ruta en vivo (`verificar = true`; en la repetición el bloque
   ya viene del almacén).
2. **`expiry_height` de la coinbase PoW.** F-16/`C-EMIT-04` exige `expiry_height == altura`; el
   constructor lo dejaba en `0`, así que **todo** bloque de altura ≥ 1 se rechazaba con `ErrEmision`
   en el primer intento de V4.
3. **Nonce de depósito leído del contexto equivocado.** `preparar_depositos` leía
   `Cadena::estado_terminal()`, que es `Estado::inicial()` hasta que el terminal se fija (no el
   estado de la punta PoW actual): todo depósito pedía `nonce = 0`, así que el segundo depósito de
   una misma clave fallaba con `ErrNonce`. Corregido: se lee `Cadena::estado_post(&última_cabecera)`.
4. **`Cadena::contexto_dag()` no existe para el primer bloque de régimen** — ver punto 10 arriba.
5. **Reloj de pared por detrás del `timestamp` mínimo (C-TS-03).** Con la dificultad inicial dev
   y el binario en `release`, minar un bloque tarda mucho menos de 1 s; forzar `timestamp >
   ts_padre` (C-TS-01, permanente) sin esperar hace que el reloj de pared se quede atrás y el propio
   bloque viole C-TS-03 (`ts > reloj_local + FTL`, con `FTL = 2 s` en el perfil dev) al admitirse:
   apareció como rechazo fatal a los 4 bloques de altura, en `release`, con `N_dev` de test.
   Corregido: si el `timestamp` elegido va por delante del reloj de pared, el bucle **espera** antes
   de mine (nunca antes: retrasar el `timestamp` violaría C-TS-01 igual de fatal).
6. **Coma que falta en el registro JSON.** `Evento::nueva` dejaba `primero: false` tras escribir ya
   `tipo`, `reloj_ns` y `reloj_pared_ns`: el primer campo que añadía el llamante no llevaba coma
   delante (`..."reloj_pared_ns":123"altura":9...`), JSON inválido. Lo encontró el propio test V4 al
   validar el registro a mano (sin `serde_json`, decisión 4 de dependencias): se fortaleció el test
   para parsear el objeto plano en vez de solo comprobar `{`/`}`.

7. **`ServicioPot` de verificación no se creaba durante la repetición.** Solo `fase_regimen` lo
   inicializaba; `Nodo::arrancar`→`reiniciar` (D-N03′) admite bloques PoST directamente si el
   registro ya los trae (un nodo reabierto tras haber cruzado el corte), y `admitir_post_interno`
   necesita ese servicio para `actualizar_servicio_verificacion` **incluso en repetición**. Sin él,
   reabrir un nodo que ya había producido PoST fallaba siempre en la primera entrada PoST del
   registro. Encontrado por `tests/reinicio.rs` (V5, rondas de régimen). Corregido: se crea en
   cuanto `admitir_pow_interno` ve el terminal fijado (vale tanto para producción en vivo como para
   repetición; `fase_regimen` conserva su propia comprobación, ahora redundante pero inofensiva).

8. **Los tiempos de espera de `tests/reinicio.rs` estaban calibrados solo para `release`.** El
   propio `cargo test --workspace` (V3, sin `--release`) ejecuta el binario `zx-node` **sin
   optimizar**: minar con la dificultad inicial real tarda ~4-5 s/bloque en vez de ~1 s/bloque (que
   ya es el suelo que impone el reloj de pared, no la CPU). Con los tiempos calibrados en `release`,
   V5b y la fase de calentamiento de V5 fallaban en `debug` por quedarse cortos, no por ningún fallo
   del nodo. Corregido con márgenes amplios (75 s y 420 s) que cubren ambos perfiles; medido en las
   dos ejecuciones de esta misma orden (`logs/V4-integracion.log` en `release`, `logs/V3-despues.log`
   en `debug`).
   **Corrección posterior (mismo `V3-despues.log`, tras corregir el punto 8):** ese arreglo dejó
   intacta la fase 1 de V5 (`RONDAS_POW = 4` rondas de calentamiento **previas** al cruce del corte),
   que seguía usando `espera_millis(ronda) = z % 8000` (tiempo de pared fijo, hasta 8 s) heredado del
   diseño anterior a la redacción del punto 8. En `debug`, minar la **primera** altura tarda más de
   8 s en el peor caso (la búsqueda de nonce es probabilística, no un tiempo fijo), así que las 4
   rondas podían — y en la ejecución real de V3-después, lo hicieron — matarse siempre antes de
   admitir ningún bloque: `alturas=[0, 0, 0, 0]`, fallo real de la prueba, no del nodo (el registro
   mostraba minería en curso — evento `bloque_minado` nunca llegó a escribirse a tiempo). Ver punto
   9.
9. **Fase 1 de V5 (`RONDAS_POW`) rediseñada de tiempo fijo a conteo de eventos del registro (mismo
   patrón que la fase 3, régimen, del punto 7 del diseño original).** `espera_millis` medía tiempo de
   pared; se sustituye por esperar a que el número acumulado (append, todo el fichero, entre rondas)
   de eventos `"bloque_minado"` alcance `objetivo_minado(ronda) = ronda` antes de matar, con un
   límite de 180 s por ronda (holgado: en `debug`, ~8-9 s/bloque medido en V5b da margen de sobra
   para 1-4 bloques acumulados). `espera_millis` no se elimina: se reutiliza como una espera
   adicional corta (`% 500` ms) **después** de alcanzar el objetivo, para que el `SIGKILL` no caiga
   siempre justo tras la línea de registro (mismo espíritu que el comentario original: "el `kill` no
   debe estar sincronizado con nada"). Reejecutado `cargo test -p zx-node --test reinicio` en `debug`
   tras el cambio: verde (ver `logs/V5-reinicio-despues-debug.log`).

## Faltas de definición registradas

- La orden no fija el **directorio del sector/parcela** por clave ni su tamaño; se usa el fixture dev
  de `zx-poas`/`zx-farmer` (`PIEZAS_POR_SECTOR_DEV = 2`, `HistoriaGenesis::construir()`), un índice de
  sector distinto por clave (0, 1, 2) y se plotea una vez al arrancar (o se reabre si ya existe en el
  directorio de datos).
- La orden no dice si el depósito debe gastar exactamente el importe de la coinbase o dejar cambio;
  se deposita el importe **exacto** de la primera coinbase madura de cada clave (sin cambio), que ya
  cubre `q = 10 ZZK` con margen (`subsidio_pow = 50`).
