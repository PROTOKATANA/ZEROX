# ORDEN-W06d6 — Sincronización por registro de admisión, correcciones de red (RI-3a) y cierre de V5, V6(b) y V7

**LINEO (`V-ZRX/LINEO.md`) rige este código Rust** (`AUTO-ZRX.md` §52: todo el código del proyecto, tests y
arneses incluidos); léelo íntegro antes de escribir código y aplica sus reglas pertinentes.

## 1. Identidad y contexto

- **ID:** W06d6. **Fecha:** 2026-09-27 (redactada ≈ 00:42). **Director:** Claude. **Ejecutor:** subagente
  **Sonnet**, único (integración de red con procesos reales, como W06d1…W06d5).
- **Zona (única escribible):** `/home/katana/zeo/ZEROX/deepseek/W06d6/`. **Tu base es la raíz en el commit de
  `ENTRADA-W06d6.sha256`**; no leas ni uses otras zonas de `deepseek/` salvo las que esta orden cita.
- **Motivo:** `P-ZRX/P-NODO/REVISION-W06d5.md`: V5 (nodo tardío) y V6(b) (partición y reunión en PoST) **no**
  convergen porque el nodo resuelve los huérfanos PoST de uno en uno y la producción los adelanta; el dial de
  arranque no reintenta; V7 queda parcial con el motivo oculto. Y `P-ZRX/P-REVISION-CODIGO/REVISION-RI-3a.md`:
  tres defectos altos de disponibilidad en los mismos archivos de red.
- **Pregunta falsable:** «Con sincronización por páginas del registro de admisión, un cuarto nodo que llega
  tras ≥ 500 bloques PoST alcanza a los demás mientras la red sigue produciendo, y tras una partición PoST de
  ≥ 20 slots (dentro de `F_SLOTS`) los tres nodos fusionan las dos ramas y, en reposo, tienen la misma punta y
  el mismo `resumen_estado`; sin que ninguno de los tres defectos de RI-3a siga reproduciéndose.»
- **Desbloquea:** criterio de cierre de W06 (`PLAN-W06.md` §3), W07a, SL-4b2 y W07b.

## 2. Entradas (congeladas en `P-ZRX/P-NODO/ENTRADA-W06d6.sha256`)

`REVISION-W06d5.md`, `REVISION-RI-3a.md` y `resultados-RI-3a/` (tres tests de reproducción),
`REVISION-RI-3c.md` si existe al congelar, `PLAN-W06.md`, `ORDEN-W06d2…d5.md`, `P-ZRX/P-RED-DEV/PERFIL-DEV-v0.md`.
Los guiones de W06d5 (`deepseek/W06d5/scripts_v4.sh`, `scripts_verif.sh`) se pueden **leer** como punto de
partida del arnés.

## 3. Decisiones del director

1. **Sincronización por registro de admisión** (sustituye a la resolución de huérfanos de uno en uno como vía
   principal de puesta al día; la resolución por padres se queda para los huecos pequeños):
   - Cada nodo mantiene, en la vista de red, la lista de hashes **en el orden en que los admitió** (PoW y PoST;
     es el mismo orden del registro de admisión de `zx-storage`, D-N03′) y sus cuerpos, que ya guarda. Ese orden
     es topológico (un bloque solo se admite tras sus padres) y solo crece.
   - Mensajes nuevos de `zx-p2p` (discriminantes nuevos, sin reordenar los existentes):
     `Peticion::Registro { desde: u64 }` → `Respuesta::Registro { desde: u64, bloques: Vec<BloqueRed>,
     longitud: u64 }`, con como mucho `MAX_BLOQUES_POR_RESPUESTA` bloques y `MAX_RESPUESTA_BYTES` bytes, en el
     orden del registro, empezando en el índice `desde`; `longitud` es la del registro del que responde. El
     saludo (`Respuesta::Estado`) lleva también `longitud`. Decodificación canónica, límites y pruebas
     negativas como el resto de `zx-p2p` (C-NET).
   - El que sincroniza guarda **un cursor por par** (en memoria; empieza en 0 al conectar: descarga el registro
     del par desde el principio y salta sin verificar lo que ya tiene por hash). **Una página en vuelo por
     par**; la siguiente se pide cuando el hilo de consenso ha procesado la anterior (contrapresión, no
     temporizador). Mientras el cursor esté a más de `UMBRAL_SINCRONIZANDO = 64` bloques de la `longitud` del
     par, los bloques PoST de gossip cuyo padre falte **se descartan** en vez de ir al depósito de huérfanos
     (llegarán por el registro). Límite declarado: tras cada reconexión se vuelve a transferir el registro
     entero del par (coste lineal en la historia; aceptable en la red dev, como E-10).
2. **Dial de arranque con reintento:** mientras no haya ninguna conexión establecida, reintentar cada
   dirección de `--red-marcar` con espera creciente (1, 2, 4… hasta 30 s), sin fin; test que falla con el dial
   único y pasa con el reintento.
3. **V7:** el motivo real del rechazo local de gossipsub en `P2pError::Transporte`
   (`crates/zx-p2p/src/servicio.rs:697-707`) y `tracing_subscriber` en `zx-adversario`; después, E-7 completo.
4. **Correcciones de RI-3a** (exactamente las de `REVISION-RI-3a.md`): petición de bloques deduplicada y
   recortada antes de clonar, con penalización por hashes repetidos; reserva **incremental** del presupuesto en
   `leer_acotado` (trozos de 64 KiB); cola `TrabajoRed` acotada (`MAX_TRABAJO_RED = 1 024` elementos y
   `MAX_TRABAJO_RED_BYTES = 256 MiB`), que descarta lo nuevo sin bloquear la red y lo registra; índice hash →
   altura en `cabeceras_desde`. Los tres tests de RI-3a son regresiones: **fallan en la base** (guarda la
   salida) y pasan tras corregir.
5. **Tests pendientes de W06d5:** decisión 1 (no producir sin garantía, en régimen y en la transición),
   decisión 2 (padres extra) y la cola de `Pendiente`.
6. **Parámetro de medición `--dejar-de-producir-en-slot <S>`** (CLI, solo red dev, no es consenso): desde el
   slot `S` el nodo no produce, pero sigue validando, propagando y sincronizando. Sirve para el **reposo**
   antes de comparar estados (`P-ZRX/P-MEDICION/REVISION-W07c.md`).
7. **Paso previo, `REVISION-RI-3c.md`:** (H1, crítico) orden **admitir en `zx-cadena` → persistir → difundir**
   en bloques propios y de red y en las dos familias; un bloque rechazado nunca se persiste; el test de RI-3c
   (`P-ZRX/P-REVISION-CODIGO/resultados-RI-3c/ri3c_nodo.diff`) pasa a regresión, más un punto de inyección de
   fallo entre admitir y persistir que compruebe que el bloque no se difunde y que el nodo reinicia bien.
   (H2) `PruebaPotIncoherente` y `RangoSinAtadura` dejan de ser `Pendiente`: bloque de red → rechazo sin
   penalizar; bloque propio → `Interno`.

## 4. Contrato de implementación

Puedes modificar `crates/zx-p2p/**` y `crates/zx-node/**` (y sus tests). **Vedado:** `zx-core`,
`zx-consensus`, `zx-cadena`, `zx-dag`, `zx-post`, `zx-storage` (si necesitas leer el registro de admisión de
`zx-storage` y no hay API de lectura, **para** y pídela con su firma exacta), `Cargo.lock` sin versiones
nuevas. Ningún `unwrap` fuera de tests; nada de lo que llega de un par puede tirar el nodo.

## 5. Plan de verificación

| Paso | Qué | Criterio |
|---|---|---|
| V0 | `sha256sum -c` de la entrada; suite completa de la raíz sin cambios | verde; si no, para |
| V1 | Tests de `zx-p2p` de los mensajes nuevos: ida y vuelta, no canónicos, sobredimensionados, `desde` fuera de rango | todos |
| V2 | Regresiones de RI-3a y RI-3c (antes/después), inyección de fallo de la decisión 7 y tests de las decisiones 2, 5 | todos, con salida antes y después |
| V3 | **V4 otra vez:** tres nodos cruzan el corte y convergen (regresión) | superado |
| V4 | **V5, nodo tardío**, con `N_dev` real (138 873 760) y `SR_dev = u64::MAX`: D arranca cuando la red lleva ≥ 500 bloques PoST; la red sigue produciendo. Se exige: en ≤ 15 min, la diferencia de slot entre la punta de D y la de A es ≤ 5 durante los 2 últimos minutos; el depósito de huérfanos de D nunca supera su tope; después, reposo (`--dejar-de-producir-en-slot` igual en los cuatro) y **misma punta y mismo `resumen_estado`** en los cuatro | superado en 2 repeticiones |
| V5 | **V6(b), partición PoST:** `{A}` / `{B, C}` durante ≥ 20 slots (dentro de `F_SLOTS`), reunión (técnica del nodo puente de W06d4 u otra, declarada); se exige que cada lado admita bloques de la rama del otro (recuento en los registros), 0 fatales, y tras el reposo misma punta y mismo `resumen_estado` en los tres | superado en 2 repeticiones |
| V6 | **V7, `zx-adversario`:** todas las entradas de E-7 (`P-ZRX/P-MEDICION/ESCENARIOS-0.0.1.md`), cada una rechazada con su motivo, sin cambio de estado; el objetivo no cae | superado |
| V7 | `fmt --check`, `clippy --workspace --all-targets --all-features --locked -- -D warnings`, `cargo test --workspace --all-features --locked` (todo lo previo con su nombre + lo nuevo), `ci/dependencias-exactas.sh`, `ci/frontera-crates.sh` | limpio |

**Tabla de cobertura** en el informe (lección de método 1): por tipo de mensaje nuevo y resultado (página
llena, página corta, `desde` más allá del final, par desconectado a mitad), por tipo de entrada de E-7, y por
decisión de W06d5, mínimo 1 por fila.

**Prohibido Python.** Presupuesto: **5 h, 8 hilos, 24 GiB.** Si se agota, entrega lo hecho y lo que falta, con
la causa. Usa `nice -n 10` en compilaciones (otra orden de revisión puede estar compilando con 4 hilos).

## 6. Entregables y límites

Patrón de las órdenes W (`ws.orig/`, `ws/` con `Cargo.toml`, `Cargo.lock`, `rust-toolchain.toml`, `crates/`,
`testdata/`, `ci/`, `.github/` y el enlace `ws/PDF`; `cambios.patch` y `MIGRACION.sha256` como **último** paso
con `sha256sum -c` en verde; `logs/`, `run/`, `INFORME.md`, `PROGRESO.md`, `HORAS.log` con `date -Is` real).
**Un solo ejecutor: prohibido lanzar subagentes o forks.** Procesos largos en segundo plano con su PID y su log
anotados en `PROGRESO.md` **antes** de esperarlos; al retomar tras un corte, lee primero `PROGRESO.md`. Sin
procesos huérfanos al terminar. Nada fuera de la zona; sin git; sin secretos; ningún `Ok` ficticio ni test
ignorado sin motivo; si una prueba falla, se informa sin ocultarla. **Un criterio de superación mira el
resultado exigido, no un síntoma parecido** (en W06d5 un «superado» de V6(b) solo miraba la reincorporación).
