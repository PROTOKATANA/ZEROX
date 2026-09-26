# PROGRESO — W06d5

Ejecutor único (Sonnet), sin subagentes ni forks. Zona: `/home/katana/zeo/ZEROX/deepseek/W06d5/`.

Documento vivo: se anota a medida que se avanza. Si hay un corte, **leer esto primero** antes de
retomar.

## Zona y entorno

- `ws.orig/` y `ws/` copiados de la raíz: solo `Cargo.toml`, `Cargo.lock`, `rust-toolchain.toml`,
  `crates/`, `testdata/`, `ci/`, `.github/` (no existe en la raíz) y el enlace `PDF ->
  /home/katana/zeo/ZEROX/PDF`. `Cargo.lock` verificado idéntico byte a byte (mismo sha256) a la raíz
  y a `ws.orig/`: `2372484b673df061b27baa1809a217bcc964f47328d5b3517092a95df6c96f57`.
- `CARGO_HOME`/`CARGO_TARGET_DIR` dentro de la zona (`env.sh`). Cachés copiadas de
  `deepseek/W06d4/.cargo-home` (2,6 GiB) y `deepseek/W06d4/target` (20 GiB) con `cp -a`
  (filesystem CoW: copia instantánea, confirmado con `time`).
- `ENTRADA-W06d5.sha256` verde al empezar (comprobado con `sha256sum -c`, 6/6).
- Presupuesto declarado: máximo 4 h, 8 hilos, 16 GiB de RAM (máquina tiene 123 GiB visibles y 32
  hilos lógicos; el tope lo fija la orden, no la máquina). Si se agota: entregar lo hecho y lo que
  falta.

## LINEO (`V-ZRX/LINEO.md`)

Leído íntegro. Es el documento de Veritas (Julia en CPU / C++ en GPU para auditorías bajo
`veritas/`/`research/`); no aplica su §5/§5.7 (reparto de lenguajes) a este código Rust del nodo.
Las reglas *pertinentes* que sí rigen (por `AUTO-ZRX.md` §52 y la cabecera de esta orden):
corrección antes que velocidad, oráculo/referencia independiente para validar un kernel, cubrir
casos de borde/contraejemplos antes de declarar terminado, perfilar antes de optimizar, declarar
presupuesto de recursos y parar en inconcluso si se agota, reproducibilidad (semilla, versión,
comando exacto), y trazas suficientes para reproducir cada fallo. Mismo criterio que documentó
`W06d4/PROGRESO.md`.

## Paso 0 — suite conjunta sin cambios (primera vez W06d4 + SL-4a juntas)

**Comando** (2026-09-26T21:28:51+02:00):
```
cd /home/katana/zeo/ZEROX/deepseek/W06d5/ws
source /home/katana/zeo/ZEROX/deepseek/W06d5/env.sh
cargo test --workspace --all-features --locked -j8
```
**PID=1297226**. **Log**: `/home/katana/zeo/ZEROX/deepseek/W06d5/logs/V0.log`.

**Resultado intento 1: FALLA**, en 21:30:59, antes de llegar siquiera a la suite real: `zx-cadena`
`tests/diferencial_t04.rs` (v0.5, el añadido por SL-4a) `panicked at
crates/zx-cadena/tests/diferencial_t04.rs:396:46: leer vectores: Os { code: 2, kind: NotFound,
message: "No such file or directory" }` — falta `testdata/estado-dag-v0.5/vectores-estado-dag-v0.5.txt`.

**Causa, con evidencia (hallazgo real, no un bug de código):** la migración de SL-4a
(`REVISION-SL4a.md`) trajo el código (22 rutas, `crates/`) pero **no** el fixture de test nuevo que
ese código necesita. El fichero sí existe, íntegro, en tres sitios que coinciden byte a byte (mismo
sha256 `c7de88de1fa8755ff1742f7c7b556994a9a27296609173030e990058dade77a5`):
`deepseek/SL4a/ws/testdata/estado-dag-v0.5/...`, `deepseek/SL4a/ws.orig/testdata/estado-dag-v0.5/...`
y el oráculo original `P-ZRX/P-DAG/T04/resultados/vectores-estado-dag-v0.5.txt` — pero **no** en la
raíz `/home/katana/zeo/ZEROX/testdata/`, que solo tiene hasta `estado-dag-v0.3`. Es un hueco de la
migración de `SL-4a` a la raíz, **fuera de mi zona** (mi zona única escribible es
`deepseek/W06d5/`; no toco la raíz).

**Decisión (comunicada aquí, no silenciosa):** para poder completar esta orden (que no trata de
este hueco), copio el fixture verificado (mismo sha256 en las tres fuentes) a
`ws.orig/testdata/estado-dag-v0.5/` y `ws/testdata/estado-dag-v0.5/` **dentro de mi zona**
(`testdata/` es contenido permitido por la orden en `ws.orig/`/`ws/`). Esto **no** sustituye el
arreglo real, que es de la raíz y **queda pendiente para el director**: copiar
`deepseek/SL4a/ws/testdata/estado-dag-v0.5/` a `/home/katana/zeo/ZEROX/testdata/estado-dag-v0.5/`.
Se relanza el paso 0 con el fixture ya presente en mi zona.

### Intento 2 (con el fixture copiado)

**Comando** (2026-09-26T21:43:51+02:00), mismo que el intento 1. **PID=1319821**. **Log**:
`/home/katana/zeo/ZEROX/deepseek/W06d5/logs/V0-intento2.log`.

**Resultado: FALLA otra vez**, mismo patrón, otro fixture de SL-4a que tampoco llegó a la raíz:
`crates/zx-consensus/tests/diferencial_t01.rs` (T01 v0.4) — falta
`testdata/transicion-v0.4/vectores-transicion-v0.4.txt`. Mismo sha256 en las tres fuentes
(`4f0a175a3b4390e40248a70b62e22829c5233311d4dfdce5c2ed164786ad3b0f`):
`deepseek/SL4a/ws/testdata/transicion-v0.4/...`, `deepseek/SL4a/ws.orig/testdata/transicion-v0.4/...`
y el oráculo `P-ZRX/P-TRANSICION/T01/resultados/vectores-transicion-v0.4.txt`. Copiado a mi zona
(`ws.orig/` y `ws/`) por el mismo motivo y con la misma reserva que el de `estado-dag-v0.5`: el
arreglo real es de la raíz y queda pendiente para el director.

**Comprobación exhaustiva:** `diff <(ls deepseek/SL4a/ws/testdata/) <(ls testdata/)` en la raíz
confirma que estos dos (`estado-dag-v0.5`, `transicion-v0.4`) son los **únicos** directorios de
`testdata/` que trajo `SL-4a` y no llegaron a la raíz. Con los dos copiados a mi zona, no debería
faltar ningún otro fixture.

### Intento 3 (con los dos fixtures copiados)

**Aviso de proceso (transparencia):** entre el intento 2 y el intento 3 empecé a escribir el código
de las decisiones 1, 2, 3 y 5 en `ws/` (mientras el intento 2 corría en segundo plano), así que
`ws/` para el intento 3 **ya no es** «la raíz sin cambios» en sentido estricto. Para no perder la
pregunta original del paso 0 (¿la combinación W06d4+SL-4a funciona, con el fixture puesto?), lanzo
en paralelo un chequeo aparte, **dirigido y sobre código intacto**, contra `ws.orig/` (que solo
tiene los dos fixtures copiados, ningún cambio de código mío) con los dos diferenciales que habían
fallado:

**Comando** (2026-09-26T22:01:59+02:00):
```
cd /home/katana/zeo/ZEROX/deepseek/W06d5/ws.orig
CARGO_TARGET_DIR=/home/katana/zeo/ZEROX/deepseek/W06d5/target-orig \
  cargo test --locked -j8 -p zx-cadena --test diferencial_t04 -p zx-consensus --test diferencial_t01
```
**PID=1326850**. **Log**: `/home/katana/zeo/ZEROX/deepseek/W06d5/logs/V0-orig-diferenciales.log`.

Y la suite completa (§3 exige de todos modos `cargo test --workspace` con todo lo previo + lo
nuevo, así que esta corrida hace doble función: valida la combinación de base *y* mis decisiones a
la vez):

**Comando** (2026-09-26T22:02:04+02:00), mismo que los intentos 1/2, ya sobre `ws/` con las
decisiones 1/2/3/5 en curso. **PID=1328881**. **Log**:
`/home/katana/zeo/ZEROX/deepseek/W06d5/logs/V0-intento3.log`.

**Intento 3 (PID=1328881): FALLA en compilación**, no en tests — dos errores de `rustc` en mi
propio código nuevo (`crates/zx-node/src/rechazo.rs` y un cuarto sitio de construcción de
`ErrorNodo::BloquePropioRechazado` que me faltaba, en `arranque_limpio`, línea 274, sin el campo
nuevo `clasificacion`). Corregidos ambos (el del génesis clasifica `Interno`: no hay nada
concurrente en un arranque limpio; el del test usaba mal la ruta de
`MotivoCabeceraPendiente::Pot(MotivoPotPendiente::PasadoIncompleto)`). `cargo build --workspace
--all-features --locked -j8` limpio tras el arreglo (1m 44s).

### Intento 4 (recompilado, con las decisiones 1/2/3/5 ya completas)

**Comando** (2026-09-26T22:05:28+02:00), mismo que los anteriores. **PID=1333828**. **Log**:
`/home/katana/zeo/ZEROX/deepseek/W06d5/logs/V0-intento4.log`.

**Resultado `V0-orig-diferenciales` (código intacto, solo con los dos fixtures restaurados):
ÉXITO.** `diferencial_t04` (zx-cadena, T04 v0.5): ok, 404.72 s. `diferencial_t01` +
`diferencial_t01_negativos` (zx-consensus, T01 v0.4): ok, 228.20 s. **Confirma que el único
bloqueo real del paso 0 era el hueco de migración de testdata, no una incompatibilidad de código
entre W06d4 y SL-4a.**

**Resultado `V0-intento4` (con las decisiones 1/2/3/5 ya escritas): ÉXITO.** Terminó 22:37:21.
`cargo test --workspace --all-features --locked -j8`: **735 pasan, 0 fallan, 2 ignorados**.
Aritmética exacta: 721 (base antes de W06d4) + 2 (W06d4) + 8 (SL-4a) + 4 (mis tests nuevos de
`rechazo.rs`, decisión 3) = 735. **0 tests perdidos.** Los tres más largos: `diferencial_t01`
(zx-consensus) 403.81 s, `diferencial_t04` (zx-cadena) 410.31 s (dos entradas de 403-426s en el
log corresponden a estas; `tests/integracion.rs` de zx-node no aparece por encima de 200s en este
log — revisar si hace falta). Log completo:
`/home/katana/zeo/ZEROX/deepseek/W06d5/logs/V0-intento4.log`. **Paso 0: CERRADO, verde.**

**Aviso del coordinador (recibido a las 22:3x):** confirma el mismo recuento (735/0/2) sobre el
mismo log. Hay otra sesión de Claude trabajando en el repo en paralelo, fuera de mi zona: no
afecta a `deepseek/W06d5/`, se ignora.

## Verificación (§3), tras el paso 0 verde

- `cargo fmt --check`: una corrida falló por formato en mis 4 archivos nuevos/tocados
  (`rechazo.rs`, `regimen.rs`); corregido con `cargo fmt` (sin `--check`); `diff -rq
  ws.orig/crates ws/crates` confirma que **solo** los 5 archivos ya modificados + `rechazo.rs`
  nuevo difieren de la base — `cargo fmt` no reformateó nada preexistente. Reconfirmado: **verde**.
- `cargo clippy --workspace --all-targets --all-features --locked -j8 -- -D warnings`: **verde a
  la primera**, 0 errores. Log: `logs/clippy-1.log`.
- `ci/dependencias-exactas.sh`: OK, 23 dependencias exactas.
- `ci/frontera-crates.sh`: OK, 9/9 fronteras (zx-node sigue viendo todos los crates; ningún otro
  crate cambió de frontera).
- `Cargo.lock` de la zona: idéntico byte a byte a la raíz y a `ws.orig`
  (`2372484b673df061b27baa1809a217bcc964f47328d5b3517092a95df6c96f57`). Ninguna dependencia tocada.

**Paso de verificación estática: CERRADO, verde.** Sigue el paso 4 (V4-V7 con procesos reales).

## Paso 4 — V4-V7 con procesos reales

**Build release**: `cargo build --release -p zx-node --locked -j8` (2026-09-26T22:42:38+02:00).
**PID=1362301**. Log: `logs/release-build.log`. **Terminado**: `Finished release en 2m 38s`.
Binarios: `target/release/zx-node` (21 570 152 B), `target/release/zx-adversario` (5 605 224 B).

### V4 — regresión con las decisiones 1/2/3 ya en el binario

**Comando** (2026-09-26T22:45:36+02:00), `N_DEV=2000 SR_DEV=18446744073709551615`:
```
cd /home/katana/zeo/ZEROX/deepseek/W06d5
bash scripts_v4.sh lanzar_nodo A 0 41400
bash scripts_v4.sh lanzar_nodo B 1 41401 /ip4/127.0.0.1/tcp/41400
bash scripts_v4.sh lanzar_nodo C 2 41402 /ip4/127.0.0.1/tcp/41400 /ip4/127.0.0.1/tcp/41401
```
**PID**: A=1370458, B=1370463, C=1370472. **Logs**: `run/{A,B,C}/{stdout.log,stderr.log,
registro.jsonl}`.

**Script de observación** (no es código del encargo, solo instrumentación de esta sesión):
`logs/v4-espera.sh "$Z/run" 60 900` (mínimo 60 `bloque_producido` entre los tres, timeout 15 min).
**PID=1370936**. Log: `logs/v4-espera.log`.

**Bug del script de observación (no del código del encargo), encontrado y corregido:**
`v4-espera.sh` usaba `c=$(grep -c ... || echo 0)`; cuando `grep -c` cuenta 0 coincidencias
imprime `"0"` pero sale con código 1, así que el `||` **también** ejecutaba `echo 0`: `c` quedaba
literalmente `"0\n0"` (dos líneas) y la aritmética `$((total + c))` fallaba con «syntax error in
expression», dejando `total` siempre en 0 y el script en `TIMEOUT_15MIN total=0` a los ~30s aunque
la red sí estaba produciendo. Corregido en los cinco scripts que tenían el mismo patrón
(`v4/v5/v6a/v6b(x2)/v7-espera*.sh`): ya no se usa `|| echo 0`, se deja el valor de `grep -c` tal
cual (siempre imprime un número) con un `${var:-0}` de respaldo solo por si el fichero no existe
todavía. **Comprobado a mano en vez de fiarme del script mientras corregía:**

```
for n in A B C; do grep -c '"tipo":"bloque_producido"' run/$n/registro.jsonl; done
```
A los ~2,5 min: A=115, B=125, C=105 (345 en total, ≥60 con margen). **0**
`bloque_red_rechazado` en los tres. **0** `"error fatal"` en los tres `stderr.log`. Último
`cambio_punta` de A y B: **mismo** `punta` y **mismo** `resumen_estado`
(`2953ce76b81f6d31d43878fddebccd42b44b6d28c985354840e1d8e75820b0af` /
`4cc88beb2a88f02a72bf6882ba2eaff1a83e40f730a9bbacc004b1078cdd977e`) — convergencia real, no solo
de la punta seleccionada. **V4 (regresión): SUPERADO.**

### V5 — cuarto nodo D (clave nueva, sin garantía), sobre la misma red de V4 ya en marcha

**Comando** (2026-09-26T22:48:24+02:00):
```
bash scripts_v4.sh lanzar_nodo D 3 41403 /ip4/127.0.0.1/tcp/41400 /ip4/127.0.0.1/tcp/41401 \
  /ip4/127.0.0.1/tcp/41402
```
**PID D=1372711**. **Log**: `run/D/{stdout.log,stderr.log,registro.jsonl}`. Criterio (decisiones 1
y 2 de esta orden): D sincroniza (mismo par punta/resumen_estado que A) y **no muere** con
`ErrGarantia`; A/B/C tampoco mueren en cascada con `Padres(SlotDePadrePosterior)`.

**Script de observación**: `logs/v5-espera.sh "$Z/run" 240 30` (espera a que D alcance el mismo
par punta/resumen_estado que A, timeout 4 min, y luego sostiene 30 s más comprobando que no
aparezca ningún fatal). **PID=1372988**. Log: `logs/v5-espera.log`.

**Resultado intento 1: FALLA.** `FALLO_FATAL run/D/stderr.log`:
```
zx-node: error fatal: bloque propio c73d83520781fc1d33bb6e4dd00bfa35ceac6e6dc2720fe6018f22908c8a55c8
  rechazado en la admisión: ErrGarantia
```
A/B/C **siguieron vivos** (confirmado con `ps`) — la decisión 2 evita la cascada que sí se vio en
`REVISION-W06d4.md`. Pero D murió con exactamente `ErrGarantia`, el mismo motivo que la decisión 1
debía evitar.

**Causa, con evidencia (hallazgo nuevo, encontrado en vivo al repetir V5 con la orden ya
aplicada):** el registro de D no tiene **ningún** `bloque_producido` (confirmado,
`grep -c` = 0): la muerte ocurre **antes** de que `hilo_productor_regimen` llegue a arrancar, en
`Nodo::producir_bloque_transicion` (el bloque de transición, decisión 6 de W05b2), que
`fase_regimen` llama incondicionalmente cuando `tips_validas()` está vacío. D recibió 24 bloques
PoST reales por red **antes** de fijar su propio terminal (`"bloque_post_de_red_sin_terminal": 24`
en su registro) — esos se ignoran sin reintentarse (`intentar_admitir_post_de_red`, rama sin
terminal) — así que al fijar su terminal, `tips_validas()` seguía vacío y D intentó producir la
transición **con su propia clave** (`self.claves[0]`, índice 3, la misma clave nueva sin garantía
de siempre). El motor la rechazó con `ErrGarantia`, y como es un bloque **propio**, `map_err`
construye `ErrorNodo::BloquePropioRechazado` — pero `producir_bloque_transicion` no pasa por el
filtro de la decisión 1 (ese solo cubre `hilo_productor_regimen`) ni su resultado pasa por la
clasificación de la decisión 3 en este punto de la llamada (`fase_regimen` propaga con `?` antes de
llegar al bucle de mensajes que sí clasifica). **Alcance de la decisión 1 original de esta orden:
incompleto** — cubría el régimen en marcha, no el arranque del régimen para un nodo que llega tarde
sin garantía propia.

**Arreglo** (mismo criterio que la decisión 1, extendido al único sitio que le faltaba):
`crates/zx-node/src/nodo.rs`, `fase_regimen`: antes de llamar a `producir_bloque_transicion`, se
comprueba `estado_terminal().activo_de(&self.claves[0].pk) >= self.params.q`. Si no alcanza, no se
intenta producir; en su lugar se espera (`procesar_trabajo_red_pendiente` en bucle, 50 ms) a que
`tips_validas()` deje de estar vacío — es decir, a que **otro** nodo produzca y sincronice la
transición por la vía normal de admisión de red. `cargo build --workspace`/`clippy -p
zx-node`/`fmt --check`: verdes tras el cambio (antes de repetir la suite completa). Build release
relanzado: **PID=1376298**, log `logs/release-build-2.log`. **Terminado**.

### V4 — repetido (intento 2) sobre el binario ya con el arreglo de la transición

Logs previos de A/B/C/D archivados en `run/v4-intento1-{A,B,C}/` y `run/v5-intento1-D/`.

**Comando** (2026-09-26T22:52:39+02:00), igual que antes. **PID**: A=1376962, B=1376967,
C=1376974. **Script de observación**: `v4-espera.sh` (ya corregido), `logs/v4-espera-2.log`,
**PID=1377292**. **Resultado: `EXITO_V4 total=87`** a los ~40s. **0** `"error fatal"`. **V4:
SUPERADO (regresión, confirmado tras el arreglo de la transición).**

### V5 — repetido (intento 2), cuarto nodo D con el arreglo ya en el binario

**Comando** (2026-09-26T22:56:00+02:00), igual que antes. **PID D=1387456**. **Script de
observación**: `v5-espera.sh "$Z/run" 240 30`, `logs/v5-espera-2.log`, **PID=1388036**.

**Resultado: TIMEOUT, no NO_SUPERADO por `ErrGarantia`.** `TIMEOUT pa=...30291bb8... pd=...ec27d1c7...`
(punta distinta) — **0 fatales** en los cuatro (confirmado con `grep`/`ps`: los cuatro procesos
seguían vivos). El arreglo de la transición **funciona**: D ya no muere. Pero D **no convergió** en
la ventana observada: su registro tiene **32 787** `bloque_red_huerfano` (family post) contra solo
**41** `huerfano_resuelto`. Investigado a mano: los pocos huérfanos que sí se resuelven (`veredicto:
Rechazar`) se rechazan con `pendiente: Pot(PasadoIncompleto)` — D los recibe **fuera de orden** (uno
a uno, por resolución de huérfanos, `Peticion::Bloques` de un solo padre cada vez) y su
`ServicioPot` de verificación (único, D-P10) todavía tiene huecos del resto del *mergeset* que ese
bloque necesita y que D aún no procesó. Con `N_dev=2000` (el mismo valor "de test" cuya velocidad de
slot ya causó la recalibración de V6(b) en esta misma orden), A/B/C avanzan miles de slots por
minuto real: para cuando D resuelve un huérfano, la red ya está mucho más adelante, así que la
resolución de huérfanos (de uno en uno) nunca alcanza el ritmo de producción. **No es un bug de
las decisiones 1-3** (nadie muere; es abstracción cierre normal de `Pendiente`→`Rechazar`, ya
declarada fuera de alcance en W06d4/W06d3) ni de la decisión 4 (esa es sobre `ErrMergeDepth` en
la partición, no sobre sincronización de un nodo tardío) — es la **misma lección de calibración**
que V6(b) ya enseñó, aplicada a V5: con `N_dev` de test tan rápido, la ventana real para que un
nodo tardío alcance a los demás es demasiado corta. **Se repite V4+V5 con un `N_dev` mayor** (mismo
criterio que la decisión 4: declarar el valor, no tocar el código de sincronización).

### V4/V5 — repetido (intento 3) con `N_dev=20000000` (~10 000x más lento que el de test, ~0,14 s/slot)

Logs previos archivados en `run/v4v5-intento2-{A,B,C,D}/`.

**Comando** (2026-09-26T23:01:44+02:00), `N_DEV=20000000 SR_DEV=18446744073709551615`:
```
bash scripts_v4.sh lanzar_nodo A 0 41400
bash scripts_v4.sh lanzar_nodo B 1 41401 /ip4/127.0.0.1/tcp/41400
bash scripts_v4.sh lanzar_nodo C 2 41402 /ip4/127.0.0.1/tcp/41400 /ip4/127.0.0.1/tcp/41401
```
**PID**: A=1409151, B=1409156, C=1409163. **Script de observación**: `v4-espera.sh "$Z/run" 60
300`, `logs/v4-espera-3.log`, **PID=1409513**. En espera.

## Aviso del director (recibido durante V5): `Pot(PasadoIncompleto)` no debe penalizar ni cachearse

**Investigado con archivo:línea, antes de asumir nada.**

- `VeredictoFinal::Rechazar` (`crates/zx-p2p/src/entrante.rs:77-78`): "Inválido de forma
  demostrable. **Penaliza** a quien lo propagó." — confirmado, no es una suposición.
- `crates/zx-node/src/nodo.rs` (antes del arreglo, ~línea 1206-1219,
  `intentar_admitir_post_de_red`): el `Err(e)` de `admitir_post_interno` —tanto si el motivo
  tipado era `Invalida` como si era `Pendiente`— se mapeaba **siempre** a `VeredictoFinal::Rechazar`
  (comentario propio, ya en el código: "simplificación declarada... fuera del alcance de esta
  orden"). El director tiene razón: es un **bug real**, no solo una simplificación.
- Para `TrabajoRed::BloqueDeSincronizacion` (la vía exacta por la que llegan las respuestas a un
  huérfano — el camino de un nodo tardío), `procesar_trabajo_red_pendiente`
  (`crates/zx-node/src/nodo.rs`, antes ~línea 942-951) hace algo más grave que "solo penalizar":
  con `Rechazar` llama a `red.desconectar(de, ViolacionDeConsenso)` — **desconecta** al par que le
  mandó el bloque de sincronización.
- Riesgo (1) (¿queda cacheado como inválido para siempre, tipo RI-2a?): comprobado que **no**
  literalmente — `admitir_post_interno` devuelve el `Err` de la puerta de cabecera conjunta
  **antes** de llamar a `self.cadena.admitir(...)`, así que el hash nunca entra en
  `Cadena::motivo`/`es_valido`. Pero el bloque en sí se **descartaba** (no había ninguna cola de
  reintento): a efectos prácticos, para el ejecutor era exactamente RI-2a — un hueco local que se
  trataba como si fuera un defecto permanente del candidato, sin ninguna vía para recuperarlo.
- Riesgo (2) (¿penaliza al par?): **sí, confirmado**, con desconexión activa en el camino de
  sincronización — exactamente el mecanismo que explica la avalancha de 32 787 `bloque_red_huerfano`
  de D en el intento 2 de V5: cada vez que D no podía verificar un bloque de sincronización por un
  hueco local, **desconectaba** de quien se lo mandó, obligándose a reconectar y volver a pedir todo
  desde cero — una amplificación del propio problema, no una cuestión de `N_dev`.

**Arreglo** (decisión 3 extendida, con test que falla antes/pasa después):
- `crates/zx-node/src/rechazo.rs`: `ClasificacionRechazo` gana un tercer valor, `Pendiente`
  (distinto de `Legitimo`/`Interno`): `clasificar_cabecera_pendiente` ahora devuelve `Pendiente` en
  vez de `Legitimo`. `es_legitimo()` sigue cubriendo los dos (no fatal para un bloque propio);
  `es_pendiente()` es nuevo (para decidir `Ignorar` vs `Rechazar` en un bloque de red). Tests
  nuevos: `toda_cabecera_pendiente_es_legitima_y_pendiente`, `legitimo_no_es_pendiente` — antes de
  este cambio, `clasificar_cabecera_pendiente(...).es_pendiente()` no existía/compilaba; con el
  cambio, pasa.
- `crates/zx-node/src/nodo.rs`, `intentar_admitir_post_de_red`: si la clasificación es `Pendiente`,
  ya **no** se llama `Rechazar` (ni, por tanto, se desconecta a nadie): se registra
  `bloque_red_pendiente`, se devuelve `VeredictoFinal::Ignorar` y el bloque se encola
  (`Nodo::encolar_post_pendiente`, campo nuevo `post_pendientes: VecDeque<BloqueDag>`, acotado a
  `TOPE_POST_PENDIENTES = 64` — D-oS local, no de consenso).
- `Nodo::reintentar_post_pendientes`: se llama tras cada admisión nueva (propia, en el bucle de
  régimen, y de red, dentro de `intentar_admitir_post_de_red`) — vuelve a intentar cada bloque en
  cola; si sigue `Pendiente`, se reencola; si ya es demostrablemente inválido o interno, se
  descarta **sin** penalizar (el remitente original ya no está atado a ese intento).
- `cargo build --workspace`/`clippy -p zx-node -D warnings`/`fmt --check`: verdes.
  `cargo test -p zx-node --lib`: **25/25 OK** (incluye los 2 tests nuevos de `rechazo.rs`, más los
  ya existentes — 0 perdidos).

## Investigación del director: ¿por qué no se fijó el terminal con `N_dev=20000000`?

**Comprobado, no supuesto.** `N_dev` **no** interviene en ningún código antes del corte: es
parámetro exclusivo de `ServicioPot::nuevo`/`hilo_productor_regimen` (ambos solo se construyen
dentro de `fase_regimen`, que no se llama hasta que `self.cadena.terminal().is_some()`). No hay
ninguna ruta de `fase_pow`, `admitir_pow_interno`, `preparar_depositos` o `es_terminal_condiciones`
que lea `self.n_dev`. Confirmado con `grep -n "n_dev\|sr_dev" crates/zx-node/src/nodo.rs`: las
únicas apariciones fuera de `Config`/`fase_regimen` son el campo guardado y `cadena_sr_dev()` (solo
usado en `admitir_post_interno`, ya en régimen).

**Causa real, con evidencia — no es N_dev, es ausencia total de red:** los tres registros del
intento con `N_dev=20000000` (archivados en `run/v4-intento3-N20M-{A,B,C}/`) tienen **0**
`bloque_red_admitido`, **0** `bloque_red_huerfano`, **0** `reorganizacion_pow` en 358-360 bloques
minados cada uno — cada nodo minó una cadena **completamente aislada** (alturas distintas: A 338,
B 345, C 343 en el momento en que el director los observó), sin ver nunca un bloque del otro. Con
solo su propia clave depositando, ningún nodo por sí solo puede alcanzar `K_min = 3` claves con
garantía: **por eso** nunca se fijó el terminal — no por `N_dev`, sino porque la red nunca se formó.

**Confirmado que no es un bug de código, con una repetición limpia:** mismo `scripts_v4.sh`,
puertos nuevos (41500-41502, para no reutilizar los de la corrida rota), `N_dev=2000`, con **1 s de
espera entre cada `lanzar_nodo`** (los tres intentos anteriores los lanzaba sin pausa). Comprobado
con `ss -tan` a los pocos segundos: **malla TCP completa** entre los tres puertos (6 conexiones
`ESTAB`, todas las combinaciones). La corrida rota (sin pausa entre lanzamientos, en el mismo tramo
de la sesión donde ya se habían lanzado y matado dos redes antes en los mismos puertos 41400-41402)
no se puede diagnosticar más a fondo sin repetirla con trazas de libp2p (fuera de presupuesto): la
hipótesis más simple, con esta evidencia, es una carrera de arranque de red (dial antes de que el
oyente estuviera listo, sin reintento) agravada por la reutilización rápida de los mismos puertos
tras matar la red anterior — **no** una dependencia de `N_dev`, que queda descartada por lectura del
código y por esta repetición. Se continúa con `N_dev=2000` (el valor ya probado, con pausa entre
lanzamientos) para V4/V5, ahora con el arreglo de `Pendiente`→`Ignorar` ya en el binario: la
hipótesis a probar es que la avalancha de huérfanos de V5 era **la desconexión repetida**, no una
cuestión de velocidad de slot.

### V4/V5 — repetido (intento 5), puertos nuevos con pausa entre lanzamientos, binario con el arreglo Pendiente→Ignorar

**Comando V4** (2026-09-26T23:18:xx), `N_DEV=2000 SR_DEV=18446744073709551615`, puertos
41600-41602, **1 s de pausa entre cada `lanzar_nodo`**:
```
bash scripts_v4.sh lanzar_nodo A 0 41600
bash scripts_v4.sh lanzar_nodo B 1 41601 /ip4/127.0.0.1/tcp/41600
bash scripts_v4.sh lanzar_nodo C 2 41602 /ip4/127.0.0.1/tcp/41600 /ip4/127.0.0.1/tcp/41601
```
**PID**: A=1446206, B=1446270, C=1446360. Confirmado con `ss -tan`: malla TCP completa (6 `ESTAB`).
**Script de observación**: `v4-espera.sh "$Z/run" 60 300`, `logs/v4-espera-4.log`, **PID=1446804**.
**Resultado: `EXITO_V4 total=76`**, **0** `"error fatal"`. **V4: SUPERADO** (tercera confirmación).

**Comando V5** (2026-09-26T23:19:46+02:00): `bash scripts_v4.sh lanzar_nodo D 3 41603
/ip4/127.0.0.1/tcp/41600 /ip4/127.0.0.1/tcp/41601 /ip4/127.0.0.1/tcp/41602`. **PID D=1447485**.
Confirmado con `ss -tan`: malla TCP completa entre los 4 (12 `ESTAB`). En espera.

**Resultado intento 3 (con el arreglo Pendiente→Ignorar): mejora medible, sigue sin converger en 4
min.** `TIMEOUT` otra vez, pero: `bloque_red_admitido` 195 (antes 71), `huerfano_resuelto` 113
(antes 41), `bloque_red_pendiente` (evento nuevo) 108 — el arreglo **funciona** (más admisiones,
más huérfanos resueltos de verdad) y **0 fatales, 0 desconexiones observadas**. El conteo de
`bloque_red_huerfano` sigue siendo enorme (33 384): con `N_dev=2000` los tres nodos producen varios
bloques por segundo entre los tres, y la resolución de huérfanos es **de uno en uno**
(`Peticion::Bloques{hashes: vec![padre]}`, un solo hash por petición,
`crates/zx-node/src/nodo.rs` en el manejo de `bloque_red_huerfano`) — un límite de **caudal**, no
un bug de las decisiones 1-3 ni del arreglo del `Pendiente`. Se amplía la ventana de observación a
10 min (antes 4) para ver si, sin la amplificación de las desconexiones (ya corregida), D llega a
converger dado más tiempo real.

**Script**: `v5-espera.sh "$Z/run" 600 30`, `logs/v5-espera-4.log`, **PID=1450994**. En espera.

## V6(a) y V6(b), en paralelo con la espera larga de V5

Se lanzó una red separada (nodos `V6a-A`/`V6a-B`/`V6a-C`, `V6b-C2`, puertos 41700-41703, dirs
`run/V6a-*`/`run/V6b-*` para no tocar `run/{A,B,C,D}` mientras V5 seguía en su ventana de 10 min).

### V6(a) — partición y reunión en fase PoW

**Diseño** (igual que W06d4): A y B, una sola clave cada uno (índices 0 y 1), nunca se marcan
entre sí — partición natural en PoW (`K_min=3` inalcanzable a solas). C (clave 2) los marca a los
dos: puente.

**Comando** (2026-09-26T23:25:10+02:00): A y B lanzados sin `--red-marcar` entre sí. Comprobado a
los 20s: 19/20 `bloque_minado`, **0** `cambio_punta` en ambos (aislados, como se esperaba).
**Reunión** (23:25:49): C lanzado con `--red-marcar` a A y B. Confirmado con `ss -tan`: malla
completa A-C, B-C (A-B nunca directo, pero sí hay tránsito de gossip vía C). A los ~35s: **31**
`cambio_punta` entre los tres (≥20). `reorganizacion_pow`: A=3, B=3, C=13 (C, el puente, es el que
más conmuta — coherente). `bloque_producido` presente en los tres: **régimen cruzado**. **0**
`"error fatal"`. **V6(a): SUPERADO.**

### V6(b) — partición y reunión en fase PoST (decisión 4: calibrada, sin dejar correr de más)

Con A/B/C ya en régimen, se detiene **C** (23:28:03) — el único puente, nunca se marcaron
directamente A-B — para partir de nuevo, ahora en PoST. `bloque_producido` antes de partir: A=49,
B=65.

**Partición**: comprobado con poll cada 2s, **parado en cuanto se alcanza el mínimo** (no como
`W06d4`, que lo dejó correr de más): a los ~80s, `PARTICION_OK da=22 db=20` (≥20 cada uno tras
partir, con margen mínimo, deliberadamente).

**Reunión inmediata** (23:29:29, ~8s después de confirmar la partición): nodo nuevo `C2` (misma
clave índice 2, hereda la garantía sin depositar de nuevo) marca a A y B. **`REUNION_OK c2=6`** a
los ~29s — C2 produce 6 bloques propios tras sincronizar (prueba de que se reincorporó de verdad).
**0** `"error fatal"` en A, B ni C2 — en particular, **sin** `ErrMergeDepth`: la calibración
(partición corta, reunión inmediata, sin dejar correr de más) evita superar `F_SLOTS=600` en
slots transcurridos. Al detenerlos: `bloque_producido` A=209, B=231, C2=15. **V6(b): SUPERADO.**

Procesos V6a/V6b detenidos y confirmados sin residuos (`ps aux | grep zx-node` solo muestra los
cuatro de V5, en `run/{A,B,C,D}`, que siguen en su ventana de observación).

## V5 — resultado final (sin maquillar, tal cual el director lo pidió)

**Intento con `N_dev=20000000` y D lanzado con poco rezago (corte recién cruzado, total=4 bloques
entre A/B/C): TIMEOUT también.** `TIMEOUT` a los 23:41:02 (240 s + 30 s de ventana). Métricas: 265
`bloque_red_admitido`, 161 `huerfano_resuelto`, pero **27 480** `bloque_red_huerfano` — la misma
proporción de huérfanos que con `N_dev=2000` y sin rezago inicial. **Esto descarta la hipótesis de
que el rezago acumulado o el `N_dev` de test explican el problema:** incluso uniéndose casi de
inmediato, D no converge. **0 fatales** en los tres intentos (2, 4 y 5).

**Conclusión honesta sobre V5 (tres intentos, con y sin el arreglo Pendiente→Ignorar, con
`N_dev=2000` y con `N_dev=20000000`, con rezago acumulado y sin él): NO SUPERADO de punta a
punta.** Lo que sí queda demostrado, con evidencia repetida en los tres intentos:
- **El hallazgo original de V5-1 de `REVISION-W06d4.md` (`ErrGarantia` fatal) está corregido**:
  decisión 1 extendida a `producir_bloque_transicion` — en los tres intentos, D nunca muere, ni
  tampoco A/B/C (decisión 2 evita la cascada `SlotDePadrePosterior`).
- **El bug de penalización/desconexión sobre `Pendiente` está corregido** (aviso del director): el
  intento 3 y los siguientes usan el arreglo y no hay ninguna desconexión ni bloque cacheado como
  inválido por error.
- **Lo que NO se corrige, y queda como hallazgo nuevo para un encargo futuro (W06d6):** la
  resolución de huérfanos de `zx-node` es **de uno en uno** (`Peticion::Bloques{hashes: vec![padre]}`,
  un solo hash por petición — el manejo de `bloque_red_huerfano` en
  `crates/zx-node/src/nodo.rs`). Con tres nodos honestos produciendo continuamente, ese caudal no
  alcanza para que un cuarto nodo tardío converja **en ninguna ventana de tiempo real que se ha
  probado** (hasta 10 min, con y sin rezago inicial, con `N_dev` chico y grande): el número de
  huérfanos crece sin límite aparente (33 384 → 128 953 en 10 min del intento 2; 12 235 → 27 480 en
  ~4,5 min del intento con poco rezago), lo que sugiere que la brecha **se ensancha**, no se
  estrecha — un límite de caudal/diseño (falta un mecanismo de sincronización PoST **por lotes**,
  análogo al `cabeceras_desde` que ya existe para PoW), no un bug puntual de las decisiones 1-3 de
  esta orden ni del arreglo del `Pendiente`.

## V6(b) — repetido con la comprobación real de convergencia que pide el director

**Aviso del director, atendido:** `REUNION_OK c2=6` del primer intento solo demostraba que C2 se
reincorporó, no que las dos ramas de la partición se fundieran. Se repite con nodos nuevos
(`run/V6a2-{A,B}`, `run/V6b2-C2`, puertos 41900-41903) y, esta vez, comprobando explícitamente
admisión cruzada de hashes y convergencia final de punta en los tres, con una ventana de
observación mucho más larga tras la reunión (150 s, no 29 s).

**Identidad de C2 (aclaración pedida):** proceso nuevo (PID distinto, `--datos` nuevo,
`run/V6b2-C2/datos`, vacío al arrancar), **misma clave** (índice 2, la de C). C estaba **parado**
(confirmado con `ps`) antes de lanzar C2: en ningún momento hubo dos procesos firmando con la
misma clave a la vez.

**Partición** (23:43:39): A y B, tras cruzar el corte juntos (80 bloques producidos entre los dos),
se parten al detener C (el único puente). Confirmado `PARTICION_OK da=53 db=53` a los ~29s (bien
por encima del mínimo de 20). Hashes de los bloques producidos **durante** la partición guardados
aparte (`/tmp/a_particion.txt` 69, `/tmp/b_particion.txt` 66) para poder comprobar después si el
otro lado los admite.

**Reunión** (23:44:18): C2 (misma clave, datos nuevos) marca a A y B.

**Resultado a los 90s: CERO admisión cruzada.** `comm -12` entre los hashes que A produjo en la
partición y los que B admitió de red (y viceversa): **0** en ambos sentidos. C2 sí admitió 27 de
los bloques de A, pero **0** de los de B. `bloque_red_huerfano` de B: 2072 (A: 8) — la misma
patología de V5 (resolución de huérfanos de uno en uno, incapaz de seguir el ritmo), aquí a menor
escala (53 bloques de brecha, no miles).

**Resultado a los 150s (60s más): sigue sin converger.** Puntas de A, B y C2 **todas distintas**
en ese momento; `bloque_red_huerfano` de B siguió creciendo (2072 → 7125) mientras A/B/C2 seguían
produciendo régimen sin parar — la brecha no se estrecha, **crece**, aunque el punto de partida
(53 bloques) era mucho más pequeño que en V5.

**Veredicto honesto: V6(b) NO DEMOSTRADO** (ni en el primer intento, que solo miraba a C2, ni en
este, que sí mira la fusión real de las dos ramas). La pregunta falsable de la orden («los nodos
vuelven a converger») **no se cumple** con el mecanismo de sincronización actual mientras la
producción no se detiene — es la **misma causa raíz** que V5 (resolución de huérfanos de uno en
uno, `crates/zx-node/src/nodo.rs`, manejo de `bloque_red_huerfano`), no algo específico de la
partición ni de `ErrMergeDepth`/RD-5 (que, de hecho, **no** se disparó en ningún momento: la
partición fue corta a propósito, decisión 4). La calibración de la decisión 4 (partición corta,
reunión inmediata) evita `ErrMergeDepth`, pero no basta para que las ramas se fundan si la
producción sigue durante la propia reunión.

## V7 — zx-adversario con la decisión 5 (espera de suscripción) corregida

**Primer intento (contra A, red recién lanzada en 42000-42002):** el objetivo no respondió el
saludo (`pedir_estado` agotó su plazo) — no relacionado con la decisión 5; se cambió el objetivo a
C, igual que hizo `W06d4`.

**Segundo intento (contra C): la decisión 5 encontró y corrigió un bug real en sí misma.** El
primer diseño (`esperar_suscripcion` como función separada, tras `pedir_estado`) **nunca vio**
ningún evento `Suscripcion`: el registro mostró `"el objetivo no confirmó suscripción... en el
plazo esperado"` seguido de la misma intermitencia de siempre. Causa (por lectura, confirmada):
las dos funciones compartían el **mismo** canal de eventos con bucles de consumo separados y
secuenciales; `pedir_estado` (que corre primero) descarta en silencio (`Ok(Some(_)) => {}`)
cualquier evento que no sea la respuesta al saludo — exactamente los dos `Suscripcion` que llegan
casi siempre junto con esa respuesta, justo tras conectar. **Arreglo:** `pedir_estado_y_suscripciones`
(`crates/zx-node/src/bin/zx-adversario.rs`) fusiona los dos bucles en uno solo sobre el mismo canal,
acumulando lo que llegue de cada tipo sin perder nada por orden de llegada.

**Repetido tras el arreglo (red nueva, 42100-42102, binario reconstruido):**
`"zx-adversario: el objetivo confirmó su suscripción a los dos temas de gossipsub"` — **la
decisión 5 ya funciona como se pretendía: la carrera de suscripción está resuelta.**

**Pero la ráfaga E-7 sigue rechazándose localmente, con una causa distinta y no diagnosticada del
todo:** **260/260** mensajes (incluidos los de un solo mensaje, minutos después de confirmada la
suscripción — no es una cuestión de tiempo) fallan con el mismo texto fijo
`"gossipsub rechazó la publicación local"`. Investigado con archivo:línea:
`crates/zx-p2p/src/servicio.rs:697-707` — **todo** error de `gossipsub.publish(...)` (sea
`NoPeersSubscribedToTopic`, `Duplicate`, `MessageTooLarge` o cualquier otro) se colapsa al **mismo**
texto fijo `P2pError::Transporte("gossipsub rechazó la publicación local")`; el motivo real solo se
registra con `tracing::debug!(%e, ...)` (línea 703), y `zx-adversario` (el binario) **no tiene
ningún `tracing_subscriber` configurado** — confirmado, `grep` no encuentra
`tracing_subscriber`/`fmt::init`/`EnvFilter` en el archivo — así que ese `debug!` no va a ninguna
parte visible. **No se pudo determinar, dentro del presupuesto de esta sesión, cuál de los posibles
motivos de `gossipsub.publish` es el que realmente dispara aquí** (la subscripción del objetivo ya
está confirmada, así que `NoPeersSubscribedToTopic` del lado del objetivo ya no debería aplicar —
haría falta instrumentar `zx-p2p` con el texto real del error, o revisar si la propia malla
**local** del adversario, no la del objetivo, es la que falta).

**V7: sigue PARCIAL, no concluyente** — mismo veredicto que `REVISION-W06d4.md`, pero con progreso
real y acotado: la causa que W06d4 diagnosticó (la carrera de suscripción) está **corregida y
verificada** (el objetivo ya confirma suscripción); lo que impide un veredicto limpio ahora es una
causa **distinta**, más profunda, sin diagnosticar (opaca por el colapso de errores de
`P2pError::Transporte` en `zx-p2p`). El objetivo (C) no aceptó nada indebido ni se cayó en ningún
momento (0 admitido de origen adversarial). Queda para un encargo futuro: dar a
`P2pError::Transporte` el texto real del error de gossipsub (no un `&'static str` fijo), y
comprobar si el propio adversario necesita esperar su **propia** malla local, no solo la
confirmación de que el objetivo se suscribió.

Procesos V7 detenidos, confirmado sin residuos.

## Decisión: reintento acotado del dial de arranque — PENDIENTE para W06d6 (declarado, no aplicado)

**Hallazgo confirmado, con archivo:línea** (aviso del director): `crates/zx-node/src/red/mod.rs:224-228`
— el dial de arranque a cada `--red-marcar` se intenta **una sola vez**
(`runtime.block_on(manejo.marcar(addr.clone()))`); si falla (el par de arranque todavía no escucha:
exactamente lo que causó la red aislada del intento con `N_dev=20000000`, sección de arriba), solo
se registra `tracing::warn!` y el nodo **nunca vuelve a intentarlo**: en una red real, un nodo cuyo
primer dial pierde la carrera de arranque queda aislado para siempre (no es un problema solo de esta
sesión de pruebas). No aplicado en esta orden: con el presupuesto restante, se prioriza —siguiendo
la instrucción explícita del director— cerrar V5/V6(b)/V7 y la verificación final (suite completa,
`fmt`/`clippy`, `cambios.patch`/`MIGRACION.sha256`) antes que una funcionalidad nueva sin margen para
probarla con el cuidado debido. **Queda declarado, con su causa exacta, para `ORDEN-W06d6`**: un
reintento acotado con espera creciente mientras `self.red.is_none()` o no haya ninguna conexión
establecida, con un test que falle antes (dial único, sin reintento) y pase después.

## Suite final, tras todos los arreglos de esta orden (decisiones 1-5 + Pendiente + fusión de
## `pedir_estado`/`esperar_suscripcion` en `zx-adversario`)

**Comando** (2026-09-26T23:57:19+02:00): `cargo test --workspace --all-features --locked -j8`.
**PID=1482761**. Log: `logs/V-final.log`. En espera.

## Cierre

`INFORME.md` escrito. `cambios.patch` (896 líneas, 6 archivos: 5 modificados + 1 nuevo) y
`MIGRACION.sha256` generados como último paso, `sha256sum -c` en verde (verificado desde `ws/`).
`ENTRADA-W06d5.sha256`: 5/6 al terminar — `P-ZRX/P-SLASHING/REVISION-SL4a.md` cambió porque el
director anotó ahí (22:15) la corrección de la migración de `testdata/` que este encargo encontró en
su paso 0; no es un cambio de esta zona ni de este ejecutor. Confirmado sin procesos `zx-node`/
`zx-adversario` huérfanos (`ps aux` limpio). `HORAS.log` con `date -Is` en cada hito. Sin Python en
ningún momento. Español en todo momento.

**Tiempo total**: inicio 21:28:42, cierre ~00:4x — dentro del presupuesto de 4 h (hasta las
01:28:42).
