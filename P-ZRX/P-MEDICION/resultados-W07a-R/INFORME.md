# INFORME — ORDEN-W07a-R: rebase de la instrumentación (W07a) sobre W06d7

**Ejecutor:** DeepSeek (`deepseek-flash`, esfuerzo `high`, DeepSeek Harness). **Fecha:** 2026-09-27
(horas reales en `HORAS.log`). **Zona:** `/home/katana/zeo/ZEROX/deepseek/W07a-R/`.
**Base:** raíz en `5a2e5f9` (con W06d7), copiada a `ws.orig/` y `ws/`; `ENTRADA-W07a-R.sha256`
verificada **46/46** al empezar.

**Falta de definición:** detectada e informada en `FALTAS-DE-DEFINICION.md` (5 huecos del rebase,
resueltos con la lectura mínima; ninguno cambia una regla de consenso ni el orden de la tubería).

## 1. Qué se hizo

Se lleva el **mismo comportamiento** de W07a a la base nueva (W06d7: un DAG por terminal, selección
FC-3 entre terminales, `nodo.rs` con `servicios_verificacion` por terminal):

- **Eventos y campos del §1** de `ESQUEMA-REGISTRO-v1.md` (salvo SL-4b2): `arranque`,
  `reinicio_completo`, `bloque_minado`, `bloque_producido`, `bloque_recibido`, `bloque_red_admitido`,
  `bloque_red_rechazado`, `bloque_red_huerfano`, `huerfano_resuelto`, `huerfano_desalojado`,
  `cambio_punta`, `reorganizacion_pow`, `par_conectado`, `par_desconectado`, `par_penalizado`,
  `limite_alcanzado`, `parada`. `Arc<Registro>` compartido con la red. `Registro::escribir` sigue
  sincronizando los críticos.
- **Los seis eventos de §1 bis, restaurados** con sus campos originales: `dejar_de_producir`
  (crítico), `bloque_red_pendiente`, `bloque_red_ignorado_sin_penalizar`,
  `bloque_post_gossip_descartado_sincronizando`, `bloque_propio_rechazado_legitimo`,
  `bloque_post_de_red_sin_terminal`. No se aplicó su retirada: los emite el nodo además de las trazas
  del §1 (ver `FALTAS-DE-DEFINICION.md` §2–3).
- **Accesos de lectura de `zx-cadena`**, reimplementados sobre `DagTerminal`: `datos_ghostdag`,
  `blue_score`, `mergeset_de`, `bloques_admitidos` y `padre_seleccionado`, resueltos contra el
  terminal **seleccionado**; `crates/zx-cadena/tests/contexto_dag.rs` compara cada uno con lo que ya
  calcula `zx-dag` (no una segunda implementación).
- **Corrección de `reinicio.rs`**: el bloque de transición **no** se registra como
  `bloque_producido` (la base tampoco lo hacía; el §1 no fija su `retraso_slot_ns`). Con eso el
  `SIGKILL` no interrumpe el ploteo de parcelas y el reinicio pasa.

### Archivos cambiados

`crates/zx-cadena/src/{cadena.rs,tests/contexto_dag.rs}`,
`crates/zx-node/src/{main,nodo,regimen}.rs`, `crates/zx-node/src/red/{mod,manejador,sync}.rs`,
`crates/zx-node/tests/{dial_reintento,red_tcp,ri3a_bloques_por_hash_duplicados,ri3a_cola_trabajo_sin_tope}.rs`
(adaptación de constructores) y nuevos `crates/zx-node/tests/{registro_esquema,registro_coste}.rs`.
`Cargo.lock` **sin cambios**. Detalle exacto en `cambios.patch`; hashes en `MIGRACION.sha256`.

## 2. Verificación

| Paso | Qué | Resultado |
|---|---|---|
| Entrada | `sha256sum -c ENTRADA-W07a-R.sha256` sobre la raíz | **46/46** |
| V1 | `cargo test --workspace --all-features --locked` (suite completa; se añadió `--no-fail-fast` para ver todos los objetivos) | **Verde: 832 pasan, 0 fallan, 5 ignorados** (81 objetivos; exit 0) |
| V2 | `registro_esquema` (cruza el corte, reabre y repite) | **Verde** (1/1; 255,83 s) |
| V3 | Tres nodos reales, ≥ 60 PoST, con `--dejar-de-producir-en-slot` | **Verde: 65 bloques PoST distintos; `dejar_de_producir` presente; adversario rechazado** |
| Diferenciales | T01 v0.5 y T04 v0.6 (en la suite) | **Verde: `diferencial_t01` 2/2 (227,32 s), `diferencial_t04` 1/1 (366,05 s), 0 discrepancias** |
| V5 | `fmt --check`, `clippy -D warnings`, guardianes, lock | **Verde** (`fmt` limpio; `clippy --workspace --all-targets --all-features --locked -- -D warnings` EXIT=0; `ci/dependencias-exactas.sh` 24 exactas; `ci/frontera-crates.sh` 9 fronteras; `Cargo.lock` intacto) |
| V4 (cobertura) | 4 tests unitarios nuevos para eventos no observados en V3 | **Verde** (3 + 1; ver §4) |

## 3. V3 en detalle

`v3.sh` lanza A/B/C en `127.0.0.1` (puertos 14901-14903), `N_dev=32` **declarado**, `SR_dev=u64::MAX`
(todos los slots ganan). A y B con `--parada-tras-slots 35`; C con `--dejar-de-producir-en-slot 18`
(única forma de que una misma ejecución produzca `dejar_de_producir` **y** `parada`: el código solo
emite `dejar_de_producir` cuando no hay `--parada-tras-slots`). Un `zx-adversario` envía entradas
inválidas contra A. El script espera a que C esté en reposo y haya ≥ 65 PoST distintos (o `parada` de
A y B) y detiene todo.

- **65 bloques PoST distintos** (producidos + admitidos), ≥ 60.
- **Rechazos del adversario**: 4 `bloque_red_rechazado` (etapa `cabecera`): `Sello(FirmaInvalida)`
  (ZIP-215), `Pot(DiferenciaDeSlots)`, PoW `C-BLK-05 bits esperado …`. Entradas inválidas rechazadas
  sin cambio de estado.
- Tipos observados en los tres registros: `arranque`, `bloque_minado`, `bloque_producido`,
  `bloque_recibido`, `bloque_red_admitido`, `bloque_red_rechazado`, `bloque_red_huerfano`,
  `cambio_punta`, `par_conectado`, `par_desconectado`, `dejar_de_producir`.

### Tabla de cobertura por tipo de evento

| `tipo` | §| Producido por |
|---|---|---|
| `arranque` | §1 | V2 y V3 |
| `reinicio_completo` | §1 | V2 (reapertura) |
| `bloque_minado` | §1 | V2 y V3 |
| `bloque_producido` | §1 | V2 y V3 |
| `bloque_recibido` | §1 | V3 |
| `bloque_red_admitido` | §1 | V3 |
| `bloque_red_rechazado` | §1 | V3 (adversario) |
| `bloque_red_huerfano` | §1 | V3 |
| `huerfano_resuelto` | §1 | Test unitario nuevo (ver §4) |
| `huerfano_desalojado` | §1 | Test unitario nuevo (ver §4) |
| `cambio_punta` | §1 | V2 y V3 |
| `reorganizacion_pow` | §1 | Test existente `pruebas_deposito_sensible_a_la_rama` (fuerza una reorganización PoW) |
| `par_conectado` | §1 | V3 |
| `par_desconectado` | §1 | V3 |
| `par_penalizado` | §1 | **No observado** (exige rechazar un bloque de **sincronización**, o génesis/red ajenos; en V3 las entradas inválidas llegaron por gossip, cuya penalización aplica `zx-p2p` sin exponer el propagador a `zx-node`) |
| `limite_alcanzado` | §1 | Test unitario nuevo (ver §4) |
| `parada` | §1 | V2 |
| `dejar_de_producir` | §1 bis | V3 |
| `bloque_red_pendiente` | §1 bis | **No observado** (exige un bloque PoST de red clasificado `Pendiente` con un terminal candidato ya fijado; el depósito de huérfanos intercepta antes los padres desconocidos) |
| `bloque_red_ignorado_sin_penalizar` | §1 bis | **No observado** (`PruebaPotIncoherente`/`RangoSinAtadura`; no apareció) |
| `bloque_post_gossip_descartado_sincronizando` | §1 bis | **No observado** (requiere que el nodo esté `sincronizando` y reciba por gossip un PoST con padre ausente) |
| `bloque_propio_rechazado_legitimo` | §1 bis | **No observado** (no hubo rechazo legítimo de un bloque propio en V2/V3) |
| `bloque_post_de_red_sin_terminal` | §1 bis | Test unitario nuevo (ver §4) |

## 4. Cobertura añadida en tests

Cuatro tests unitarios nuevos cubren los eventos que V3 no produjo y que un nodo sin red sí puede
recorrer con bloques construidos a mano (sin minar). Los cuatro pasan:

| Evento | Test | Resultado |
|---|---|---|
| `bloque_post_de_red_sin_terminal` | `nodo::pruebas_diagnostico_registro::un_post_sin_terminal_candidato_traza_sin_terminal` | 3/3 en el módulo |
| `huerfano_desalojado` | `nodo::pruebas_diagnostico_registro::el_cupo_por_padre_traza_el_desalojo_de_huerfanos` | idem |
| `huerfano_resuelto` | `nodo::pruebas_diagnostico_registro::un_huerfano_retirado_del_deposito_traza_su_resolucion` | idem |
| `limite_alcanzado` | `red::manejador::tests::cola_llena_traza_el_limite_alcanzado` | 1/1 |

Además, `reorganizacion_pow` ya lo produce el test existente
`nodo::pruebas_deposito_sensible_a_la_rama::preparar_depositos_vuelve_a_depositar_tras_perder_el_bloque_del_deposito`
(fuerza un cambio de rama PoW, `profundidad > 0`).

**Nota de proceso:** los cuatro tests se añadieron **después** de que la suite completa terminara
(los objetivos de `zx-node` ya habían corrido). El código de producción es idéntico al que verificó
la suite; los cuatro tests nuevos se compilaron y ejecutaron aparte (EXIT=0) y `clippy -D warnings`
y `check --all-targets` se re-ejecutaron sobre el árbol final, también verdes.

## 5. Lo que **no** queda demostrado

- Cinco tipos de evento **no observados** en V2/V3 (causas en la tabla §3):
  `par_penalizado`, `bloque_red_pendiente`, `bloque_red_ignorado_sin_penalizar`,
  `bloque_post_gossip_descartado_sincronizando` y `bloque_propio_rechazado_legitimo`. Exigen
  escenarios que V3 no reprodujo (rechazo de un bloque de **sincronización**, clasificación
  `Pendiente` con terminal ya fijado, `PruebaPotIncoherente`/`RangoSinAtadura`, gossip durante
  sincronización, y un rechazo legítimo de un bloque propio). Se declaran, no se imputan.
- `parada` aparece en V2, no en V3: A y B llevaban `--parada-tras-slots`, pero el script cortó al
  alcanzar los 65 PoST antes de que llegaran al slot de parada. `dejar_de_producir` sí aparece en V3.
- El bloque de transición **no** se registra como `bloque_producido` (comportamiento conservado de la
  base; el §1 no fija su `retraso_slot_ns`). Es la corrección que hace pasar `reinicio.rs`.
- El `par` de un bloque de gossip se omite (no computable en `zx-node`); se escribe en los bloques
  de sincronización. Es el mismo límite que documentaba W07a.
- `retraso_slot_ns` se omite para el bloque de transición (no hay hilo productor del que tomarlo).
- El coste del registro no se volvió a medir con V4 en esta orden; se conserva la medición y la
  decisión de `REVISION-W07a.md` §1 (aceptada por el director).

## 6. Incidente de entorno (declarado)

La primera compilación se lanzó desde la raíz de la zona, donde no hay `Cargo.toml`: Cargo subió
hasta `ZEROX/Cargo.toml` y compiló la base **sin instrumentar**. Se detectó al ver que el primer V3
emitía el `arranque` v0 (`fase`) en lugar del v1. Corregido: los comandos se lanzan desde `ws/`
(`env.sh` hace `cd "$Z/ws"`); el primer V3 se descartó y se repitió con el binario correcto
(verificando `version_esquema` en el registro). Los recuentos publicados son de la segunda corrida.

## 7. Modelo

`deepseek-flash`, esfuerzo `high` (el de la orden). No se verificó por API ni se leyeron secretos.

