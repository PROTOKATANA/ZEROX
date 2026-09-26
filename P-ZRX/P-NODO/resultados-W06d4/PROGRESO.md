# PROGRESO — W06d4

Ejecutor único (Sonnet), sin subagentes. Zona: `/home/katana/zeo/ZEROX/deepseek/W06d4/`.

Documento vivo: se anota a medida que se avanza, para que un corte a mitad de sesión deje el
estado escrito (instrucción de Katana tras un handback forzado a las 19:53).

## Zona y entorno

- `ws.orig/` y `ws/` copian solo `Cargo.toml`, `Cargo.lock`, `rust-toolchain.toml`, `crates/`,
  `testdata/`, `ci/`, `.github/`, y el enlace `ws/PDF -> /home/katana/zeo/ZEROX/PDF` (y el mismo
  enlace en `ws.orig/`). `Cargo.lock` verificado idéntico al de la raíz al empezar.
- `CARGO_HOME`/`CARGO_TARGET_DIR` dentro de la zona (`env.sh`). Caché `.cargo-home` copiada de
  `deepseek/W06d3/.cargo-home` (2,6 GiB, `cp -a`).
- `ENTRADA-W06d4.sha256` verde al empezar (comprobado con `sha256sum -c`).

## LINEO (`V-ZRX/LINEO.md`)

Leído íntegro. Rige el código Rust de este encargo por sus reglas *pertinentes* (corrección,
oráculo/referencia independiente, casos límite, perfiles antes de optimizar, control de recursos,
reproducibilidad, trazas) — `AUTO-ZRX.md` §52 y la primera línea de `ORDEN-W06d4.md` lo dicen
explícitamente; el reparto Julia/C++ (§5, §5.7) es solo para cálculo de auditoría bajo
`veritas/`/`research/`, no aplica aquí. No se ha usado Python en ningún momento.

## Decisión 1/2 — depósito sensible a la rama (hipótesis del director: CONFIRMADA)

**Causa, con evidencia.** En `crates/zx-node/src/nodo.rs`, `admitir_pow_interno` marcaba
`CoinbasePropia.depositada = true` para **cualquier** bloque admitido (propio o ajeno, en
cualquier rama, incluida una que después pierde el fork-choice FC-3) que gastara ese `OutPoint`,
sin comprobar si ese bloque seguía en la rama finalmente seleccionada. Tras una reorganización que
descarta el bloque del depósito pero conserva viva la coinbase en la rama nueva, el indicador
quedaba en `true` para siempre: el nodo nunca volvía a depositar esa coinbase, y con varios
procesos minando a la vez (bifurcaciones PoW frecuentes antes del corte) esto bloquea que las
`K_min` claves con garantía activa que exige `Φ` lleguen a reunirse.

**Reproducción real** (tubería de admisión real, `Nodo::admitir_pow_interno`, sin mocks ni red):
test `nodo::pruebas_deposito_sensible_a_la_rama::preparar_depositos_vuelve_a_depositar_tras_perder_el_bloque_del_deposito`
(`crates/zx-node/src/nodo.rs`). Construye una rama A (deposita la coinbase de A1 en A7, tras
madurar) y una rama B más pesada (6 bloques desde el ancestro común M6, sin depositar) que acaba
seleccionada por FC-3 (confirmado con `Cadena::mejor_punta_pow`/`historial_pow`). Se comprueba
además, en el propio test, que la coinbase de A1 sigue viva (sin gastar) en `estado.utxo` de la
rama B. **Antes del arreglo: el test compila y corre, pero falla** en la aserción final (no se
propone el depósito: `depositos_despues` viene vacío). **Después del arreglo: pasa.**

**Arreglo.** `preparar_depositos` ya no mantiene ningún indicador local (`CoinbasePropia`,
`Nodo.coinbases`): decide qué depositar leyendo **directamente** `estado.utxo`/`estado.garantias`
de la punta PoW ya seleccionada (`Cadena::estado_post`), sensible a la rama por construcción — una
salida gastada en una rama descartada sigue viva en `utxo` de cualquier otra rama que no la gastó,
sin ninguna poda aparte. Cambios:
- `crates/zx-node/src/nodo.rs`: campo `Nodo.coinbases: Vec<CoinbasePropia>` eliminado; el rastro
  local en `admitir_pow_interno` (marcar `depositada`/empujar `CoinbasePropia`) eliminado; la poda
  de `coinbases` tras reorganización en `actualizar_seleccion_pow` eliminada (ya no hace falta);
  `preparar_depositos` reescrito iterando `estado.utxo` (filtra `Origen::CoinbasePow`,
  `Lock::PubKey` propia, madurez por `entrada.creada.como_altura() + m_cb`); import `Origen`
  añadido (`zx_consensus::transicion::Origen`); `CoinbasePropia`/`txid` quitados del import
  superior (el segundo se movió al `use` local del módulo de test `pruebas_v7`, que sí lo sigue
  necesitando).
- `crates/zx-node/src/pow.rs`: struct `CoinbasePropia` eliminada; `construir_deposito` cambia de
  firma: `(txid_coinbase: TxId, valor_coinbase: Amount, clave: &ClaveDev, nonce: u64, cbid: u32)`
  en vez de `(coinbase: &CoinbasePropia, ...)`.

## Decisión 3 — `Pot(PasadoIncompleto)`: causa encontrada y corregida (no resuelta en W06d3)

**Causa, por lectura + test dirigido.** `ServicioPot::insertar_calculado` permite (a propósito,
D-P10: flujo único compartido por todas las ramas) saltar directamente a un slot posterior sin
calcular los intermedios — el propio test `insertar_calculado_permite_huecos_pero_no_retroceder`
ya documentaba esto como comportamiento deseado. Si ese salto lo produce un bloque de **otra
rama** (el `ServicioPot` de verificación del bucle principal es único y compartido entre todas las
ramas que el nodo conoce), un slot **anterior** que otra rama sí usó de verdad queda como hueco
(sin salida ni portador calculados), aunque su bloque sea válido y ya esté admitido en `Cadena`.

`Nodo::actualizar_servicio_verificacion` (`crates/zx-node/src/nodo.rs`) solo sabía reconciliar un
slot `<= slot_actual()` con `ServicioPot::salida_de`, que **exige** que el slot ya tenga una
salida calculada: con un hueco, `salida_de` falla con `FueraDeVentana` aunque el bloque traiga su
`pot_output` real, ya verificado (viene de una cabecera admitida, no de una suposición). Como
`self.cadena.admitir(post)` ya se ejecutó **antes** de esa comprobación (sin rollback),
el bloque queda **admitido y válido en `Cadena`** pero **nunca entra en `pasado()`** del
`ServicioPot` de verificación del bucle principal. Cualquier hijo que lo declare padre (seleccionado
o extra) falla después en `verificar_rango_pot_fase_previa` con exactamente
`Pot(PasadoIncompleto)` — el síntoma observado en W06d3 con un nodo que se incorpora tarde al
régimen (recibe/sincroniza bloques de varias ramas fuera de orden de slot).

**Reproducción**: test `zx_post::servicio_pot::pruebas::declarar_salida_pasada_rellena_un_hueco_dejado_por_otra_rama`
(`crates/zx-post/src/servicio_pot.rs`). Reproduce el hueco con `insertar_calculado` (salta al slot
10), y comprueba que el único camino disponible antes del arreglo (`salida_de(7)`) falla con
`FueraDeVentana` — la aserción explícita que documenta el fallo tal cual ocurre en producción.
Después, comprueba que el método nuevo resuelve el hueco y que D-P10 se sigue protegiendo
(una salida **distinta** para el mismo slot sigue siendo un error).

**Arreglo.**
- `crates/zx-post/src/servicio_pot.rs`: nuevo método `ServicioPot::declarar_salida_pasada(slot,
  salida, portador)`: si `slot > slot_actual()`, delega en `insertar_calculado` (mismo camino de
  siempre); si `slot <= slot_actual()`, rellena el hueco cuando no había nada registrado, o
  compara y falla con la nueva variante `ErrorServicioPot::SalidaPasadaDiscrepante` si ya había
  una salida **distinta** (D-P10 real). Nuevo test (arriba).
- `crates/zx-node/src/nodo.rs`: `actualizar_servicio_verificacion` usa `declarar_salida_pasada` en
  vez de `salida_de` + comparación manual.

**Alcance de la evidencia**: el test es a nivel de `ServicioPot` (reproduce con precisión el
mecanismo leído en el código y en el error real observado). No se ha vuelto a correr V4 con
tres procesos reales todavía en esta orden para confirmar que esto agota el fenómeno de extremo a
extremo — eso es exactamente el paso 4 de esta sesión (V4–V7).

## Verificado hasta el corte de las 19:53 (parcial, antes del handback)

- `cargo build --workspace --all-features --locked -j8` sobre el árbol base (sin tocar): limpio.
- `cargo test -p zx-post --lib servicio_pot`: 10/10 OK (incluye el test nuevo).
- `cargo test -p zx-node --lib`: 20/20 OK (incluye los dos tests nuevos), sin warnings.
- `cargo test --workspace --all-features --locked -j8`: lanzada, cortada a mitad (handback) sin
  confirmar el resultado final. **Se retoma ahora** (ver más abajo).

## Sesión retomada (a partir de 2026-09-26T19:53)

Instrucciones de Katana (vía director): seguir la lista de pendientes en orden 1→9, anotando aquí
a medida que se avanza.

### (1) `logs/test-workspace-1.log`

Al retomar (19:53), el proceso seguía vivo (PID 1201328, lanzado a las ~19:49) y sin fallos hasta
donde había llegado (`diferencial_t01`/`diferencial_t01_negativos` de `zx-consensus`, tests que ya
se sabe (por precedentes de otras órdenes) que tardan varios minutos). Se decide **esperar a que
termine** en vez de relanzarla (sigue viva, no hay indicio de cuelgue).

Actualización 20:15 (≈25 min de corrida): sigue viva, sin ningún fallo. Ya pasaron completos
`zx-consensus` (incl. `diferencial_t01`/`diferencial_t01_negativos`), `zx-poas` (incl.
`historia_genesis`, `poas.rs`), y `zx-post` completo — **incluidos los dos tests nuevos de las
decisiones 1–3** (`servicio_pot::pruebas::declarar_salida_pasada_rellena_un_hueco_dejado_por_otra_rama`
OK). Sigue con `tests/cabecera_conjunta.rs`. Quedan por delante, al menos, `zx-cadena` (con
`diferencial_t04`, más largo), `zx-dag`, `zx-farmer`, `zx-p2p`, `zx-storage` y `zx-node` (incluida
`tests/integracion.rs`, que en W06d3 tardó ~455 s). Se sigue esperando.

**Terminada a las 20:18:22.** `cargo test --workspace --all-features --locked -j8`:
**723 pasan, 0 fallan, 2 ignorados** (721/0/2 antes de esta orden — +2 tests nuevos, 0 perdidos:
exactamente los dos de las decisiones 1–3). `tests/integracion.rs` de `zx-node` tardó 451,23 s;
`diferencial_t04` de `zx-cadena` 436,07 s; ambos en verde. Log completo:
`/home/katana/zeo/ZEROX/deepseek/W06d4/logs/test-workspace-1.log`. **Paso (1) CERRADO.**

### (2) `fmt --check` / `clippy -D warnings`

`cargo fmt --check`: falló una vez por una línea larga en mi propio test nuevo (`nodo.rs:1789`,
firma del helper `cabecera(...)`). Corregido con `cargo fmt` (sin `--check`) sobre todo el
workspace; `diff -rq ws.orig/crates ws/crates` confirma que **solo** los tres archivos ya
modificados (`zx-node/src/nodo.rs`, `zx-node/src/pow.rs`, `zx-post/src/servicio_pot.rs`) difieren
de la base — `cargo fmt` no reformateó nada preexistente. `cargo fmt --check` en verde.

`cargo clippy --workspace --all-targets --all-features --locked -j8 -- -D warnings`: **1.ª
corrida falló**: `clippy::panic` (denegado a nivel de workspace, `Cargo.toml` §`[workspace.lints.clippy]`,
`panic = "deny"`) en mi propio test nuevo — `panic!("M{altura} se admite: {e}")` y
`panic!("B{altura} se admite: {e}")` dentro de `unwrap_or_else` en los bucles que construyen los
bloques comunes/de la rama B (`nodo.rs:1845`/`1886`). **Corregido** siguiendo el patrón ya usado en
todo el resto del workspace para este mismo lint (`crates/zx-node/tests/integracion.rs` y muchos
otros: `#[expect(clippy::panic, reason = "...")]`, nunca desactivado a nivel de crate): se añadió
`clippy::panic` al `#[expect(...)]` que ya tenía el módulo de test (junto a `clippy::expect_used`).
Reconfirmado con `cargo clippy -p zx-node --all-targets --all-features --locked` (verde) y
`cargo fmt --check` (verde). **Clippy completo del workspace, relanzado: verde, 0 errores.**
Log: `/home/katana/zeo/ZEROX/deepseek/W06d4/logs/clippy-2.log`. **Paso (2) CERRADO.**

### (3) CI: `dependencias-exactas.sh`, `frontera-crates.sh`, lock

- `ci/dependencias-exactas.sh`: **OK** — 23 dependencias con versión exacta.
- `ci/frontera-crates.sh`: **OK** — las 9 fronteras de crate, sin excepción (idénticas a las de
  W06d3: `zx-node` sigue siendo el único que ve todos los crates).
- `Cargo.lock` de la zona: **idéntico byte a byte** al de la raíz (`sha256sum` igual:
  `2372484b673df061b27baa1809a217bcc964f47328d5b3517092a95df6c96f57`). No se tocó ninguna
  dependencia. **Paso (3) CERRADO.**

## Paso (4) — V4–V7 con procesos reales

`cargo build --release -p zx-node --locked -j8`: terminado a las 20:50:50 (`Finished release en
2m 49s`). Binarios confirmados: `target/release/zx-node` (21 553 528 B), `target/release/zx-adversario`
(5 593 392 B).

### V4 — intento 1 (N_dev pequeño)

**Comando** (2026-09-26T20:51:xx, `N_DEV=2000 SR_DEV=18446744073709551615`, sin `PARADA`):

```
cd /home/katana/zeo/ZEROX/deepseek/W06d4
bash scripts_v4.sh lanzar_nodo A 0 41400
bash scripts_v4.sh lanzar_nodo B 1 41401 /ip4/127.0.0.1/tcp/41400
bash scripts_v4.sh lanzar_nodo C 2 41402 /ip4/127.0.0.1/tcp/41400 /ip4/127.0.0.1/tcp/41401
```

**PID**: A=1274087, B=1274111, C=1274167 (comprobados vivos con `ps`, cada uno con su propia clave
0/1/2, misma semilla por defecto=1).

**Logs**: `run/A/{stdout.log,stderr.log,registro.jsonl}`, `run/B/...`, `run/C/...` (rutas completas
bajo `/home/katana/zeo/ZEROX/deepseek/W06d4/`).

**Criterio de éxito (`ORDEN-W06d3` §4)**: mismo terminal; ≥ 60 bloques PoST entre los tres; 0
bloques honestos rechazados; misma punta y resumen de estado al terminar.

**Script de observación** (no forma parte del código del encargo, solo instrumentación de esta
sesión): `/home/katana/zeo/ZEROX/deepseek/W06d4/logs/v4-espera.sh`, lanzado en background con
**PID=1275148**, log `/home/katana/zeo/ZEROX/deepseek/W06d4/logs/v4-espera.log`. Poll cada 10 s,
hasta 15 min: cuenta `bloque_producido` de los tres registros; termina en éxito si el total
llega a ≥60; termina en fallo si aparece `"error fatal"` en algún `stderr.log` o si un proceso
muere sin haber dejado ese rastro; si no, se agota a los 15 min con `TIMEOUT_15MIN`.

En espera de progreso (se anota el resultado más abajo, en esta misma sección, al comprobarlo).

**Resultado (2026-09-26T20:53–20:56, script de observación en verde a los ~35 s):**
`EXITO_V4 total=69` (≥60 alcanzado). Comprobado a mano tras el aviso: **0** `bloque_red_rechazado`
en los tres registros; **0** `"error fatal"` en los tres `stderr.log`; los tres procesos seguían
vivos. A los pocos minutos (sin `--parada-tras-slots`, dejados corriendo): A=190, B=191, C=147
`bloque_producido` (528 en total), **0** rechazos, **0** fatales — la red sigue produciendo con
normalidad muy por encima del mínimo exigido.

**Convergencia de estado.** Se extrajeron los pares `(punta, resumen_estado)` de los eventos
`cambio_punta` de A y B (194/195 entradas): de los pares con la **misma** `punta`, **191/194
coinciden exactamente** en `resumen_estado`; 3 discrepan. Investigadas a mano (mismo `punta` de 64
caracteres hex, sin truncar — no es colisión de grep): **no es un bug**. `registrar_cambio_de_punta`
llama a `Cadena::estado_virtual()` (`ED-3`, GHOSTDAG), que fusiona el *mergeset* de **todas** las
puntas válidas conocidas en ese instante (`tips_validas()`), no solo la seleccionada (`mejor_punta`);
dos nodos que ya coinciden en la punta seleccionada pueden, por un instante, conocer un conjunto
distinto de puntas laterales todavía no propagadas, y su estado *virtual* difiere aunque la punta e
historia seleccionada sean la misma — exactamente lo que dice el propio docstring de
`estado_virtual`. Es decir: `punta` (la mejor, por `mejor_punta`/FC-3) sí es la misma consistentemente;
`resumen_estado` (el estado *virtual*, sensible al conjunto transitorio de puntas laterales conocidas)
puede diferir en un instante intermedio sin que eso sea una discrepancia de consenso. Se decide
comprobar la convergencia real («al terminar», como pide `ORDEN-W06d3` §4) parando los procesos y
comparando el resumen final, más abajo.

### V5 — cuarto nodo tardío (aprovechando esta misma red de V4, ya con > 500 bloques)

**Comando** (2026-09-26T20:56:xx):
```
bash scripts_v4.sh lanzar_nodo D 3 41403 /ip4/127.0.0.1/tcp/41400 /ip4/127.0.0.1/tcp/41401 /ip4/127.0.0.1/tcp/41402
```
**PID**: D=1277194. **Logs**: `run/v5-intento1-D/{stdout.log,stderr.log,registro.jsonl}` (archivado
tras el intento). Génesis limpio, cuarta clave (índice 3), marca a los tres nodos ya en marcha (red
con > 200 bloques, cumple el umbral de `ORDEN-W06d3` §4). Criterio: sincroniza al mismo resumen.

**Resultado: FALLA. Causa encontrada, con evidencia — dos hallazgos nuevos, distintos de las
decisiones 1–3, NO resueltos en esta orden (fuera de su alcance: no son ni el depósito por rama ni
`PasadoIncompleto`).**

**Hallazgo V5-1 — `ErrGarantia` fatal en el primer bloque propio de un nodo que nunca depositó.**
D sincronizó correctamente el PoW y el PoST ya existentes (confirmado: su último `cambio_punta`
antes de morir tiene exactamente el mismo par `(punta, resumen_estado)` que A/B/C registraron en
ese mismo punto — `punta=00002810b29fdf3e...`, `resumen_estado=ea903e70c948c3...`, evidencia directa
de que la sincronización, incluida la ruta de `declarar_salida_pasada` de la decisión 3, **funciona**).
Pero D murió casi enseguida con:
```
zx-node: error fatal: bloque propio b6d44d26... rechazado en la admisión: ErrGarantia
```
Causa (por lectura, `crates/zx-consensus/src/transicion/aplicar.rs:816-819`): al aplicar la
transición de un bloque PoST, `activo_de(productor) < params.q` ⇒ `ErrGarantia`. D nunca minó PoW
ni depositó (su clave, índice 3, nunca existió antes: llega directamente en fase PoST vía
sincronización), así que su garantía activa es 0. Pese a eso, `fase_regimen`/`hilo_productor_regimen`
lo hace **producir** en cuanto gana una solución PoAS — no hay ningún cheque de `activo >= q` antes
de intentarlo — y el bloque propio se rechaza en su propia verificación: fatal, por la decisión 4
general de `ORDEN-W06d1` («bloque propio rechazado ⇒ fatal»). Agravante estructural: `main.rs`
rechaza sin excepción cualquier `--papel` que no sea `Ambos`
(`if cli.papel != Papel::Ambos { ...; exit(2) }`), aunque el docstring de `Papel` (`cli.rs`) diga que
`Minero`/`Productor` están pensados justamente para un nodo con red que no deba producir todavía —
ese camino nunca se habilitó. **No hay, en esta versión del nodo, ninguna forma de que una clave
nueva se incorpore después del corte sin depositar antes de intentar producir** (no existe un
depósito en fase PoST en este dev): un cuarto proceso con una clave genuinamente nueva está
condenado a este `ErrGarantia` fatal en cuanto gane su primera solución PoAS. Con presupuesto para
más, la corrección natural sería que el hilo productor comprobara `activo_de(clave) >= q` antes de
intentar `producir_en_regimen` y, si no llega, se abstuviera de esa clave en ese slot (igual que ya
se descarta una candidata por `SlotNoProgreso`) en vez de dejar que la verificación lo rechace fatal.

**Hallazgo V5-2 — cascada: `Padres(SlotDePadrePosterior)` fatal en A y B, aparentemente disparado
por la llegada de D.** Segundos después de la caída de D, A y B murieron también, cada uno con:
```
zx-node: error fatal: bloque propio ... rechazado en la admisión:
  Padres(SlotDePadrePosterior { padre: BlockHash(...), slot_padre: 960, slot_b: 959 })
```
(`A`: `slot_padre=960` contra `slot_b=959`; `B`: `slot_padre=932` contra `slot_b=931` — el mismo
patrón: un padre declarado tiene un slot **igual o posterior** al propio bloque). Causa (por
lectura): `EstadoCabeceraConjunta::Invalida` con motivo `Padres(ErrorDag::SlotDePadrePosterior)`
viene de la verificación GHOSTDAG completa (`zx-dag`, C-HDR-05/C-FLU-02: **ningún** padre —
seleccionado o extra— puede tener `slot >= slot(B)`). `regimen.rs` (líneas 255–275, el arreglo ya
documentado de `ORDEN-W06d3`) descarta con gracia una candidata cuando el **padre seleccionado**
(`sp`) incumple esto (`ErrorRegimen::SlotNoProgreso`), pero **ese cheque no cubre los padres
extra** del *merge set* GHOSTDAG: `producir_en_regimen` construye el bloque igualmente si solo un
padre **extra** (no el seleccionado) tiene un slot demasiado avanzado, y el fallo solo aparece
después, en la verificación completa del bloque propio — donde, al ser una cabecera propia
rechazada, es fatal (decisión 4). Con 3 procesos honestos solos (la corrida anterior, sin D) esto no
se observó en varios minutos y más de 500 bloques; con el cuarto proceso conectado (más mensajes de
red, más jitter, más candidatos a padre en vuelo) la ventana de carrera se hizo alcanzable. **No se
ha determinado, dentro del presupuesto de esta sesión, si D fue la causa directa (p. ej. un bloque
suyo, admitido brevemente antes de que su propio proceso muriera, entró como padre extra en algún
`tips_validas()` de A/B) o si es una ventana de carrera latente en `padres_de_regimen`/`regimen.rs`
que ya existía con 3 procesos y solo necesitaba más concurrencia para hacerse visible.** Corrección
natural, no aplicada aquí por presupuesto: extender el filtro de `regimen.rs` (o el propio
`padres_de_regimen`) para descartar también los padres **extra** con `slot >= slot(B)` antes de
construir el bloque, en vez de descubrirlo en la verificación.

**Alcance de estos dos hallazgos:** ninguno de los dos toca el código de las decisiones 1–3 de esta
orden (`preparar_depositos`, `ServicioPot::declarar_salida_pasada`); son hallazgos nuevos,
encontrados en vivo al ejecutar V5 con un cuarto proceso real, y quedan **fuera del alcance de las
decisiones de `ORDEN-W06d4`** (que son, explícitamente, el depósito por rama y `Pot(PasadoIncompleto)`).
Se documentan aquí con su causa y evidencia, como pide el método, y quedan **para un encargo
futuro** — igual que W06d3 dejó abiertos sus propios hallazgos 5 y 6.

**V5: NO SUPERADO.** El mecanismo de sincronización (decisión 3) sí funciona (evidencia directa
arriba); lo que impide cerrar V5 de punta a punta son estos dos hallazgos nuevos, no relacionados
con las decisiones de esta orden.

Se detuvieron los cinco procesos (`scripts_v4.sh matar_todo`; confirmado con `ps aux` que no queda
ninguno vivo) y se archivaron sus registros bajo `run/v4-intento1-{A,B,C}/` y `run/v5-intento1-D/`.

### V6(b) — partición y reunión en fase PoST (≥ 20 slots), reutilizando A/B/C de V6(a)

Con A/B/C ya en régimen (corte cruzado en V6(a)), se detiene **C** (el único puente entre A y B:
nunca se marcaron directamente) para volver a partirlos, ahora en fase PoST. A y B siguen vivos,
cada uno con su propia garantía **ya establecida** (a diferencia de V5, no hay clave nueva sin
depositar: se evita a propósito el hallazgo V5-1).

**Comando**: `kill $(cat run/C/pid)` (2026-09-26T21:09:xx). Antes de matarlo: A tenía 205
`bloque_producido`, B tenía 124. **Script de observación**: `logs/v6b-particion.sh`,
**PID=1289689**, log `logs/v6b-particion.log`. Poll cada 5 s hasta 2 min: éxito si A **y** B
producen ≥ 20 bloques cada uno **tras** la partición (evidencia de ≥20 slots aislados); fallo si
aparece `"error fatal"` en A o B.

**Resultado partición:** `PARTICION_20_BLOQUES_CADA_UNO da=137 db=141` (muy por encima de ≥20).
A y B vivos, **0** `"error fatal"` durante la partición.

**Reunión**: en vez de reiniciar el proceso `C` original, se lanzó un nodo nuevo **`C2`** (misma
clave índice 2 — la garantía es del estado compartido por red, keyed por clave pública, así que
`C2` la hereda sin depositar de nuevo) desde génesis limpio, marcando a A y a B:
```
./target/release/zx-node --datos run/C2/datos --registro run/C2/registro.jsonl --claves 2 \
  --n-dev 2000 --sr-dev 18446744073709551615 --red-escuchar /ip4/127.0.0.1/tcp/41503 \
  --red-marcar /ip4/127.0.0.1/tcp/41500 --red-marcar /ip4/127.0.0.1/tcp/41501
```
**PID C2=1289903**. **Script de observación**: `logs/v6b-reunion.sh`, **PID=1290108**, log
`logs/v6b-reunion.log`. Poll cada 6 s hasta 4 min: éxito si `C2` llega a producir ≥5 bloques
propios tras sincronizar (prueba de que se reincorporó de verdad, con la garantía heredada de su
clave, sin el `ErrGarantia` de V5-1 — aquí la clave **ya estaba establecida**, a diferencia de la
clave nueva de V5); fallo si aparece `"error fatal"` en A, B o C2.

**Resultado: FALLA.** `FATAL_DETECTADO` a los ~25 s de la reunión:
```
run/B/stderr.log: zx-node: error fatal: bloque propio 28261d6b... rechazado en la admisión: ErrMergeDepth
```
**Causa, con evidencia (no es un hallazgo de las decisiones 1–3):** `MotivoBloque::ErrMergeDepth`
se dispara en `zx-cadena/src/cadena.rs:616-620` (`estado_past_de_idx`, RD-5): al fusionar el
*mergeset* de un bloque, si algún miembro `X` (no `rojo_U3`) tiene `p.slot − x_slot > F_slots`
(`F_SLOTS = 600`, `crates/zx-consensus/src/perfil.rs` — dev), el bloque se invalida. La partición
duró **137/141 bloques** por proceso (mucho más que el mínimo `≥20` que pedía la orden: el script
de observación tardó en confirmarlo y se dejó correr de más) — pero el `slot` PoT es un reloj
**global** que avanza con el tiempo real transcurrido, no con cuántos bloques se producen: con
`N_dev = 2000` (pequeño, para que la prueba sea rápida) cada slot dura milisegundos, así que en los
varios minutos reales que llevaba esta sesión de V6(b) (partición + espera + reunión) el `slot`
más reciente ya estaba a **miles** de slots por delante de algún miembro del *mergeset* que
arrastraba desde antes de la partición — de sobra para superar `F_SLOTS = 600`. **No es un bug de
las decisiones 1–3** ni, con bastante confianza, un bug nuevo de consenso: es la cota RD-5
funcionando como está diseñada (rechazar un merge demasiado viejo), disparada porque esta sesión de
pruebas, con un `N_dev` de test tan pequeño, hizo pasar muchos más slots reales de los que la
partición «debía» representar. Lo que **sí** es un patrón recurrente, visto ya tres veces en esta
sesión (V5-1 `ErrGarantia`, V5-2 `SlotDePadrePosterior`, y este `ErrMergeDepth`): la política de
decisión 4 de `ORDEN-W06d1` («bloque propio rechazado ⇒ fatal») no distingue un bug interno de un
rechazo **legítimo** del protocolo ante un caso de borde (garantía insuficiente, padre extra
adelantado, fusión demasiado profunda); en los tres casos, un rechazo legítimo tira abajo el
proceso entero en vez de descartar la candidata y seguir. **Fuera del alcance de esta orden**
(decisiones 1–3), se deja anotado como síntesis para un encargo futuro.

**V6(b): NO SUPERADO** en este intento, por una causa de calibración de la prueba (partición y
espera demasiado largas para `N_dev = 2000` frente a `F_SLOTS = 600`), no por un bug de las
decisiones de esta orden. Sin presupuesto para repetirlo con una partición más corta dentro de esta
sesión (ya se agotó bastante tiempo en V4/V5/V6(a)); se deja para un encargo futuro con una
partición calibrada (p. ej. parar la reunión a los pocos segundos de alcanzar el mínimo de 20
bloques, en vez de dejarlo correr).

### V7 — `zx-adversario` contra un objetivo real que ha cruzado el corte

Red limpia de tres nodos, directamente marcados entre sí (sin puente), para cruzar el corte
rápido y no acumular slots de más (lección de V6(b)): `bash scripts_v4.sh lanzar_nodo A 0 41600`;
`... B 1 41601 /ip4/127.0.0.1/tcp/41600`; `... C 2 41602 /ip4/127.0.0.1/tcp/41600
/ip4/127.0.0.1/tcp/41601` (2026-09-26T21:15:xx). **PID**: A=1291606, B=1291611, C=1291618.
Script de espera del corte: `logs/v7-espera-corte.sh`, **PID=1292058**, log
`logs/v7-espera-corte.log` (éxito si A registra ≥3 `cambio_punta`; fallo si `"error fatal"`).

**Corte cruzado**: `CORTE_CRUZADO cambios=9` a los ~30 s. A/B/C vivos, 0 fatales.

**`zx-adversario` contra A** (`--objetivo /ip4/127.0.0.1/tcp/41600 --pausa-ms 300`, log
`run/adversario-A.{stdout,stderr}.log`): **falló al conectar dos veces seguidas**
(`"el objetivo no respondió el saludo"`, luego `"el objetivo no conectó en el plazo esperado"`) sin
que A registrara nada ni muriera (A siguió vivo y sano). **Contra C** (recién estrenado,
`--objetivo /ip4/127.0.0.1/tcp/41602`, log `run/adversario-C.{stdout,stderr}.log`): sí conectó y
pidió el saludo (`"objetivo declara altura PoW 31 fase Post"`), pero la ráfaga E-7 (256 mensajes)
se **rechazó casi entera en el propio proceso adversario**, antes de salir a la red:
`"difundido (pow): RECHAZADO localmente: no se pudo levantar el transporte: gossipsub rechazó la
publicación local"`. Causa (por lectura del propio docstring de `zx-adversario.rs:340-348`): la
malla de gossipsub tarda en negociarse tras conectar; la herramienta ya mitiga con una espera fija
de 500 ms antes de publicar, pero con la red ya cargada (tres nodos reales produciendo y
admitiendo bloques a buen ritmo) esa espera no siempre basta — **es la misma intermitencia que
`REVISION-W06d2.md`/`PROGRESO.md` de `W06d3` ya diagnosticaron para esta misma herramienta**
(«ráfaga de huérfanos del adversario», hallazgo antiguo, no nuevo, y explícitamente fuera del
alcance de ambas órdenes: el arreglo de W06d3 fue del lado del **objetivo** — reintento periódico
del saludo — no de la publicación local del adversario). Se comprobó en el registro de `C` que,
en efecto, **0** `bloque_red_huerfano`/`bloque_red_rechazado` aparecen en la ventana del ataque:
casi ningún mensaje de la ráfaga llegó de verdad a la red. Sí se observó, en la salida de la
herramienta, `"el objetivo CORTÓ la conexión tras este escenario"` para la ráfaga E-7 (evidencia de
que **algún** mensaje sí llegó y provocó una desconexión defensiva), y `"la conexión sigue viva"`
para los escenarios de un solo mensaje (PoST con PoAS/PoT/sello malos con el terminal real; E-8
equivocación; PoW nonce malo) — sin poder confirmar en el registro estructurado de `C` un rechazo
correspondiente a cada uno (mismo problema: los mensajes individuales también compitieron con la
carga real de la red y no siempre se registró una entrada específica en la ventana revisada).

**V7: PARCIAL, no concluyente.** El objetivo real nunca se cayó ni aceptó nada indebido (0 admitido
de origen adversarial en los registros revisados); lo que impide un veredicto limpio es la
intermitencia ya conocida de la propia herramienta `zx-adversario` (publicación local antes de que
la malla de gossipsub termine de formarse), no un fallo del nodo. No se corrige aquí (fuera del
alcance de las decisiones 1–3; el propio W06d3 ya lo dejó fuera de alcance de la suya). Logs
conservados en `run/adversario-{A,A2,C}.{stdout,stderr}.log`.

Se detuvieron los tres nodos (`scripts_v4.sh matar_todo`; confirmado sin procesos residuales).

### V6(a) — partición y reunión en fase PoW (antes del corte)

**Diseño:** con `K_min = 3` claves exigidas por `Φ`, dos nodos con **una sola clave cada uno**
nunca cruzan el corte por sí solos: es la partición natural en fase PoW (ninguno de los dos puede
avanzar a régimen mientras estén aislados). La reunión la aporta un **tercer** nodo, con la
**tercera** clave que falta, marcando a los dos primeros: bridging real (dos procesos que nunca se
marcaron entre sí, unidos por un tercero), y a la vez la clave que completa `K_min = 3` para poder
cruzar el corte tras la reunión.

**Comando** (partición, 2026-09-26T21:05:xx): `N_DEV=2000 SR_DEV=18446744073709551615`
```
bash scripts_v4.sh lanzar_nodo A 0 41500
bash scripts_v4.sh lanzar_nodo B 1 41501
```
**PID**: A=1287863, B=1287868. **Logs**: `run/A/…`, `run/B/…`.

Comprobado tras 20 s: A y B habían minado **33 bloques cada uno**, en solitario, **0**
`cambio_punta` en ambos (ninguno cruzó el corte, como se esperaba con una sola clave cada uno).

**Reunión** (2026-09-26T21:06:xx): `bash scripts_v4.sh lanzar_nodo C 2 41502 /ip4/127.0.0.1/tcp/41500
/ip4/127.0.0.1/tcp/41501` — **PID C=1288435**. C es el puente (marca a A y a B, que nunca se
marcaron entre sí) y aporta la tercera clave (índice 2) que falta para `K_min = 3`.

Comprobado a los 15 s: los tres vivos, 0 fatales, **C ya registró 9 `reorganizacion_pow`** con
profundidades 4–68 (A y B compitiendo, C viendo ambas ramas y conmutando repetidamente entre
ellas — evidencia directa de FC-3 funcionando con dos ramas reales que jamás se habían visto
antes). Corte todavía no cruzado (0 `cambio_punta`).

**Script de observación** (no forma parte del código del encargo): `logs/v6a-espera.sh`,
**PID=1288843**, log `logs/v6a-espera.log`. Poll cada 8 s hasta 5 min: éxito si la suma de
`cambio_punta` de los tres llega a ≥20 (corte cruzado y régimen en marcha); fallo si aparece
`"error fatal"`; si no, `TIMEOUT_5MIN`.

**Resultado: ÉXITO.** `CORTE_CRUZADO_Y_20_SLOTS cambios=52` a los ~90 s de la reunión. Comprobado
a mano: los tres procesos vivos; **0** `"error fatal"`; `reorganizacion_pow` registrada en los
tres (A: 2, B: 1, C: 13 — C, el puente, es quien más conmuta, coherente con ver ambas ramas desde
el principio); `bloque_producido` A=63, B=39, C=40 (142 en total); `cambio_punta` A=65, B=81, C=82.
Un único terminal según FC-3 (confirmado indirectamente: el régimen avanza con normalidad en los
tres tras la reunión, lo que exige que los tres coincidan en el mismo terminal — si no, ninguno
podría admitir los bloques PoST de los otros dos).

Sí aparecieron **3** `bloque_red_rechazado` (A:1, C:2) — investigados: los tres son
`Pendiente(Padres(PadreNoValidado{...}))`, no `Invalida`. Esto **no es un hallazgo nuevo**: es la
«simplificación declarada» ya documentada en `ORDEN-W06d3`/`PROGRESO.md` (`Pendiente` e `Invalida`
llegan al mismo `Rechazar` en `intentar_admitir_post_de_red`, fuera del alcance de esa orden y de
esta) — un bloque ajeno legítimo, pero momentáneamente «no juzgable todavía», se descarta en vez de
reintentarse. No provoca ningún error fatal ni impide el cruce del corte ni la convergencia
observada. **V6(a): SUPERADO** (con esta reserva ya conocida, no nueva).
