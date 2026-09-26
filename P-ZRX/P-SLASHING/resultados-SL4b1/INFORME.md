# INFORME — ORDEN-SL4b1 (firmante seguro portado a `zx-post`)

**Ejecutor:** DeepSeek (`deepseek-flash`, esfuerzo `high`, DeepSeek Harness).
**Zona única:** `/home/katana/zeo/ZEROX/deepseek/SL4b1/`.
**Fecha:** 2026-09-26. **Regla de código:** `V-ZRX/LINEO.md` (leído íntegro antes de editar).
**Nombre de modelo que devuelve la API en la sesión:** `deepseek-flash` (perfil `headless`). El
harness no expone el nombre del modelo por variable de entorno (`$DSH_*` solo da `HOME`, `SESSION_ID`
y `SHELL`); se declara el configurado por la orden y el perfil de lanzamiento.

## 1 · Resumen

Se porta el firmante seguro (`C-EVP-06`, FIR-01…FIR-15) al árbol nuevo como `zx_post::firmante`
(`mod.rs`, `identidad.rs`, `registro.rs`), adaptado a la identidad `RAT-1`
(`consensus_branch_id` + la tupla de `C-GD-07`; dominio
`b"ZXRFIRM/ticket-rat1/cbid-c-gd-07"`, `VERSION_ESQUEMA = 2`). Se añaden, **sin cambiar ni borrar**
las funciones existentes, los productores `producir_con_firmante` (primer bloque PoST) y
`producir_en_regimen_con_firmante` (régimen), que construyen **la misma** cabecera y cuerpo que las
rutas antiguas y las sellan **solo** por `&mut Firmante`. `alta.rs` no se porta (§3.5): su papel lo
cubren `Registro::nueva(ruta)` (alta limpia, falla si el fichero existe) y `Registro::abrir`
(recuperación con abstención). No se tocan `crates/zx-node`, `crates/zx-consensus`, `crates/zx-core`
ni `Cargo.toml`/`Cargo.lock`.

## 2 · Archivos cambiados (10)

| Archivo | Estado |
|---|---|
| `crates/zx-post/src/firmante/mod.rs` | nuevo |
| `crates/zx-post/src/firmante/identidad.rs` | nuevo |
| `crates/zx-post/src/firmante/registro.rs` | nuevo |
| `crates/zx-post/src/lib.rs` | modificado (`pub mod firmante`, reexportes) |
| `crates/zx-post/src/productor.rs` | modificado (factoriza construcción; `producir_con_firmante`) |
| `crates/zx-post/src/productor_regimen.rs` | modificado (factoriza; `producir_en_regimen_con_firmante`) |
| `crates/zx-post/tests/firmante_publico.rs` | nuevo |
| `crates/zx-post/tests/firmante_identidad_evidencia.rs` | nuevo |
| `crates/zx-post/tests/firmante_productores.rs` | nuevo |
| `crates/zx-post/tests/firmante_coste.rs` | nuevo (V8, `#[ignore]` justificado) |

`cambios.patch` = `diff -ruN --no-dereference --exclude=PDF ws.orig ws`. `MIGRACION.sha256` lleva
la huella de esos 10 archivos.

## 3 · Falta de definición (informada antes de editar)

Véase `DEFINICIONES-FALTANTES.md` (DF-1…DF-9). Las dos que cambian el resultado observable:

- **DF-1:** el resultado del productor lleva el veredicto del firmante en la variante de bloque,
  `ProductoFirmado::Bloque(BloqueDag, Resultado)`, porque V6(a) exige observar `Reemitido` a través
  del productor. `Abstenido { motivo }` distingue conflicto de pérdida de registro.
- **DF-9 (contradicción V4 ↔ decisión §3.5/FIR-10):** la orden §3.5 dice «abstención hasta
  `slot_actual + s_max_slots`» y FIR-10 fija `abstención_hasta = slot_perdida + S_max_slots`; el
  código antiguo lo implementa de forma **inclusiva** (`slot <= hasta`). V4 pide «niega `s … s+m−1`,
  firma en `s+m`», desplazado en uno. Se siguió la decisión del director y el código antiguo (fuente
  normativa del portado): con `slot_actual = s`, `S_max = m` se abstiene en `s … s+m` y firma en
  `s+m+1`, probado en los dos bordes. Si la dirección quería el borde literal de V4, el cambio es
  `abstener_hasta = s + m - 1`.

## 4 · Verificación V0…V8

### V0 · Entrada congelada y suite base

- `sha256sum -c P-ZRX/P-SLASHING/ENTRADA-SL4b1.sha256`: **10/10**, todas «La suma coincide».
- Suite `zx-post` **antes** de tocar nada (`cargo test -p zx-post --all-features --locked`):
  **verde**, `EXIT=0` (`logs/v0-zx-post.log`). Incluye 34 unit + integración; `v6_` de `regimen` y
  doc-tests sin fallos.

### V1 · Tests portados/adaptados

Ver §5. Todo lo portado del código antiguo (`firmante_local.rs`, `#[test]` de `registro.rs`,
`identidad.rs` y `mod.rs`) pasa. Además se añaden los casos nuevos de SL-4b1.

### V2 · Durabilidad con proceso real

`firmante::tests::durabilidad_el_proceso_muere_entre_la_persistencia_y_la_firma_veinte_veces`:
20 iteraciones. Cada una lanza el propio binario de test con `FIRMANTE_TEST_RUTA/SLOT/CHUNK`, el
hijo reserva `(identidad, slot) -> pre_hash_1` por el camino real (`Registro::resolver`, que escribe
y hace `sync_all`) y llama a `std::process::abort()` **antes de firmar**; el padre comprueba muerte
por `SIGABRT` (señal 6), que `pre_hash_2 ≠ pre_hash_1` se rechaza
(`AbstenidoPorConflicto`) y que `pre_hash_1` se reemite (`Reemitido`). **20/20 verde.**

### V3 · Cola a ceros y bit cambiado en la cabecera

- `registro::tests::una_entrada_completa_a_ceros_tras_una_valida_falla_cerrado` → `Corrupto` y el
  fichero **no** se trunca.
- `registro::tests::una_cola_parcial_falla_cerrado` → `ColaParcial`.
- `registro::tests::un_bit_en_la_cabecera_rompe_el_checksum` y
  `firmante_publico::una_cabecera_manipulada_falla_cerrado_y_no_firma` → `CabeceraCorrupta`; el
  fichero sigue midiendo solo la cabecera.

### V4 · Abstención exacta (FIR-10)

`firmante::tests::la_abstencion_usa_el_perfil_de_registro_abrir` y
`firmante_publico::la_abstencion_depende_del_perfil_de_abrir`: con `abrir` sobre fichero nuevo,
`slot_actual = s`, `S_max = m`, `abstener_hasta = s + m`; se abstiene en `s+m` y firma en `s+m+1`.
`alta_nueva` de `u64::MAX - 1` satura el horizonte y sigue absteniéndose. **Véase DF-9** por el
desplazamiento de uno de la redacción de V4.

### V5 · Identidad = identidad de la evidencia (RAT-1)

`tests/firmante_identidad_evidencia.rs`, 12/12 verde:

- (a) para 5 cabeceras reales firmadas, la igualdad de `Firmante::identidad(..).huella()` coincide,
  par a par, con la igualdad de `zx_core::incident_id_evidencia`.
- (b) `EvidenceTx` v4 de dos cabeceras reales de la misma identidad y distinto `pre_hash`:
  `validar_forma_tx_v4` pasa y `zx_consensus::transicion::aplicar_con_undo` la aplica (`Ok`).
- (c) 6 filas, un campo de identidad por test (incluido `consensus_branch_id`): el firmante las ve
  como oportunidades distintas (`Sellado`) y el motor rechaza —`ErrCbidAjeno` para el `cbid`,
  `ErrSinEvidencia` para los otros cinco—.
- (d) 3 filas (`padres`, cuerpo, `timestamp`): la huella del firmante **no** cambia; con distinto
  `pre_hash` el firmante se abstiene por conflicto. Fila extra: la forma v4 no mira identidad ni
  `cbid`.

### V6 · Productores `_con_firmante`

`tests/firmante_productores.rs` (fixture real: `HistoriaGenesis`, `ParcelaDisco`, `ServicioPot` y
GHOSTDAG reales), 3/3 verde:

- (a) `producir_en_regimen_con_firmante` con los mismos datos que `producir_en_regimen` da un bloque
  **idéntico byte a byte** (`Sellado`); segunda llamada con el mismo firmante → `Reemitido` y bloque
  idéntico; una sola entrada en el registro.
- (b) mismos billete y slot con otro cuerpo → `Abstenido { motivo: Conflicto }`, sin bloque y sin
  ocupar oportunidad.
- (c) el bloque de `_con_firmante` y el antiguo dan el **mismo** `EstadoCabeceraConjunta::Comprobada`
  y los mismos `HechosPost`.
- Extra: `producir_con_firmante` del primer bloque PoST es idéntico byte a byte a `producir`.

### V7 · fmt, clippy, suite, guardianes

| Comando | Resultado |
|---|---|
| `cargo fmt --all -- --check` | limpio |
| `cargo clippy --workspace --all-targets --all-features --locked -- -D warnings` | **EXIT=0**, sin avisos (3m18s; `logs/clippy-workspace.log`) |
| `cargo test --workspace --all-features --locked` | **EXIT=0**: 789 pasan, 0 fallan, 5 ignorados (23:10:08→23:59:08; `logs/test-workspace.log`) |
| `ci/dependencias-exactas.sh` | **OK** — 23 dependencias exactas (`logs/ci-dependencias.log`) |
| `ci/frontera-crates.sh` | **OK** — 9/9 fronteras, `zx-post → {zx-core,zx-pot,zx-dag,zx-poas}` (`logs/ci-frontera.log`) |

`Cargo.lock` idéntico a la raíz (no se declaró ninguna dependencia nueva; `zx-post/Cargo.toml` no se
tocó).

### V8 · Coste

`FIRMANTE_COSTE_DIR=$Z/target/coste cargo test -p zx-post --test firmante_coste -- --ignored --nocapture`
(`logs/coste-firmante.log`), disco de la zona (`/dev/mapper/cr_root`, **btrfs**) y `sync_all` real:

| n | mediana | p99 | media | total |
|---:|---:|---:|---:|---:|
| 2 000 | **3,697 ms** | **4,636 ms** | 3,765 ms | 7,531 s |

Comparado con FIR-14 (≈ 0,81 ms de mediana en el prototipo, NVMe/btrfs): **≈ 4,6× más lento** en esta
máquina/carga. Sigue siendo ≪ 1 s por slot; **no es criterio de aceptación**. No se cambia a
`fdatasync` (FIR-03/FIR-14).

## 5 · Tests portados / adaptados / no portados

### Portados sin cambio de semántica

`firmante::tests`: `caso_5_con_entrada_previa_y_otro_pre_hash_no_firma`,
`caso_4_reemitir_el_mismo_bloque_funciona`,
`la_clave_ajena_no_ocupa_la_oportunidad_ni_muta_el_sello`,
`el_sello_verifica_bajo_la_clave_publica`, `hijo_persiste_y_aborta` (guardado).
`registro::tests`: `entrada_nueva_conocida_y_conflicto`,
`el_formato_declara_version_tres_y_cabecera_de_cincuenta_y_seis`,
`sobrevive_a_reabrir_y_conserva_entradas`,
`una_entrada_completa_a_ceros_tras_una_valida_falla_cerrado`, `una_cola_parcial_falla_cerrado`,
`bytes_alterados_en_medio_fallan_cerrado`, `un_duplicado_conflictivo_falla_cerrado`,
`un_duplicado_identico_no_falla`, `una_magia_ajena_se_rechaza`,
`una_version_desconocida_falla_cerrado`, `un_formato_dos_no_se_migra_en_silencio`,
`un_bit_en_la_cabecera_rompe_el_checksum`, `la_recuperacion_sincroniza_antes_de_autorizar_firma`,
`la_abstencion_de_un_alta_nueva_persiste_tras_dos_reinicios`,
`un_horizonte_que_desborda_u64_sigue_absteniendose`, `el_fallo_de_persistencia_envenena_la_instancia`,
`el_bloqueo_entre_dos_descriptores_se_detecta`, `la_creacion_sincroniza_el_directorio_padre`.
`firmante_publico`: `distinto_padre_mismo_billete_y_slot_se_abstiene`,
`mismo_pre_hash_se_reemite_tras_reinicio`, `billete_o_slot_diferente_puede_firmarse`,
`la_clave_que_no_corresponde_no_ocupa_la_oportunidad`, `dos_hilos_no_firman_dos_hashes`,
`dos_procesos_sobre_el_mismo_fichero_no_firman_dos_hashes`,
`una_cabecera_manipulada_falla_cerrado_y_no_firma`, `un_formato_dos_no_se_migra_en_silencio`,
`la_abstencion_depende_del_perfil_de_abrir`, `hijo_intenta_abrir_y_reporta` (guardado).

### Adaptados (qué cambió)

- **Identidad (`identidad.rs`)**: `(public_key, sector_index, history_size, chunk, slot)` →
  `RAT-1` con `consensus_branch_id` al frente; constructor `vigente` → `rat1`; dominio
  `ZXRFIRM/ticket-vigente/c-gd-07` → `ZXRFIRM/ticket-rat1/cbid-c-gd-07`; `VERSION_ESQUEMA` 1 → 2;
  `bytes_canonicos` añade `cbid` (u32 LE) y la huella incorpora la red. Los tests de identidad
  cubren los seis campos.
- **`Firmante::firmar`**: la abstención por pérdida deja de ser
  `Err(FirmanteError::Registro(EnAbstinencia))` y pasa a `Ok(Resultado::AbstenidoPorPerdida)`
  (DF-3). El test de perfil y el de reinicio se adaptan a esa lectura.
- **`Registro::nueva`**: sustituye a `crear_inicial_sin_historia` de `alta.rs`;
  firma `nueva(ruta)` (DF-2) y se añaden dos tests propios
  (`nueva_falla_si_el_fichero_ya_existe`, `nueva_permite_firmar_de_inmediato`).
- **Durabilidad**: de 1 a **20** iteraciones (V2); el resto igual.
- **Cabeceras de test**: `consensus_branch_id` real (`CBID_RED_DEV` o `7`), sin `0`.
- **`sellar` en los productores**: se factoriza la construcción de la cabecera/cuerpo en una única
  función privada; la ruta antigua sella directo y la nueva por `Firmante`. El comportamiento de las
  funciones antiguas no cambia (comparado byte a byte en V6).

### No portados

- `crates/zx-consensus/src/firmante/alta.rs` y `crates/zx-consensus/tests/alta_firmante_local.rs`
  (§3.5): en 0.0.1 las claves dev se derivan de un índice (`zx-node/src/claves.rs`); la generación
  aleatoria de `alta.rs` no se usa. `Registro::nueva` cubre el alta atómica sin abstención.
- La poda in situ del prototipo (FIR-09): el registro solo crece.
- El punto de extensión a `IDV-01` (RAT-1 lo elimina).

### Añadidos (SL-4b1)

- Unidad: `el_sello_invalido_no_muta_la_cabecera` (DF-5, inyección solo-test),
  `el_error_de_registro_no_se_confunde_con_la_abstencion`,
  `durabilidad_..._veinte_veces`, `nueva_*` (2).
- Integración: `firmante_identidad_evidencia.rs` (12), `firmante_productores.rs` (3),
  `firmante_coste.rs` (1, V8).

## 6 · Tabla de cobertura

Mínimo 1 caso por fila (V2 cuenta como 20; V6 tiene 3 tests con varios casos).

| Resultado / error | Casos (≥1) |
|---|---|
| `Sellado` | `caso_5*`, `caso_4*`, `el_sello_verifica*`, `la_clave_ajena*` (2.ª), `la_abstencion_usa*` (libre), `distinto_padre*` (1.ª), `mismo_pre_hash*` (1.ª), `billete_o_slot*` (×3), `la_clave_que_no_corresponde*` (2.ª), `dos_hilos*` (1), `aborto*` (libre), `v5b*`, `v5c_*` (6), `v5d_*` (3), `v6a*`, `v6b*` (1.ª), `v6_primer*` |
| `Reemitido` | `caso_4*`, `mismo_pre_hash*`, `durabilidad` (20), `v6a*` (2.ª) |
| `AbstenidoPorConflicto` | `caso_5*`, `distinto_padre*`, `durabilidad` (20), `v5d_padres*`, `v5d_cuerpo*`, `v5d_timestamp*`, `v6b*` |
| `AbstenidoPorPerdida` | `la_abstencion_usa_el_perfil*`, `la_abstencion_tras_perder*`, `la_abstencion_depende_del_perfil*` |
| `ClaveNoCoincide` | `la_clave_ajena*`, `la_clave_que_no_corresponde*` |
| `SelloInvalido` | `el_sello_invalido_no_muta_la_cabecera` (DF-5) |
| `Envenenado` | `el_error_de_registro_no_se_confunde*`, `el_fallo_de_persistencia_envenena*` |
| `CabeceraCorrupta` | `un_bit_en_la_cabecera*`, `una_cabecera_manipulada*` |
| `ColaParcial` | `una_cola_parcial_falla_cerrado` |
| `Corrupto` | `una_entrada_completa_a_ceros*`, `bytes_alterados_en_medio*` |
| E/S (`Io`) | `la_recuperacion_sincroniza*`, `nueva_falla_si_el_fichero_ya_existe`, `el_fallo_de_persistencia*` |
| `Bloqueado` | `el_bloqueo_entre_dos_descriptores*`, `dos_procesos_sobre_el_mismo_fichero*` |
| `MagiaInvalida` | `una_magia_ajena_se_rechaza` |
| `VersionInvalida` | `una_version_desconocida*`, `un_formato_dos*` (×2) |
| `DuplicadoConflictivo` | `un_duplicado_conflictivo_falla_cerrado` |
| `TamanoNoRepresentable` | 0 — inalcanzable en 64 bits; no figura en la lista de errores de §4 |

## 7 · Modelo de amenaza (FIR-13)

Cubre accidentes honestos: reinicio tras `SIGKILL`/corte entre reservar y firmar (V2), doble llamada
del productor con dos candidatos del mismo billete (V6), registro truncado o corrompido (V3). **No**
cubre: dos máquinas con registros distintos; clave robada o compartida; un atacante que borre el
registro; `fsync` que mienta (NFS); dos procesos sobre ficheros distintos. No es un mecanismo de
seguridad ni de consenso (FIR-15). `Registro::nueva` es solo para una identidad genuinamente nueva.

## 8 · Fallos, riesgos y lo que no queda demostrado

- **DF-9** (borde de V4) es la única discrepancia de criterio: se implementó el borde de la decisión
  §3.5/FIR-10, no el literal de V4.
- `SelloInvalido` es inalcanzable por la API pública con Ed25519 correcto; se cubre con una
  inyección solo-test (DF-5), no con un camino real.
- `TamanoNoRepresentable` no tiene caso: no es alcanzable en una máquina de 64 bits.
- V8 mide el `fsync` de **esta** máquina y del disco de la zona, no el del prototipo; la comparación
  con FIR-14 (0,81 ms de mediana) es orientativa.
- No se demuestra la integración en el nodo, la detección de equivocación ni el envío de evidencia:
  es SL-4b2.
- No se demuestra FIR-11 (restauración de copia de seguridad): sigue siendo requisito sin test.
- La concurrencia entre procesos se limita al bloqueo de fichero (`flock`); un `fork` entre el
  `fork` y el `exec` puede dar `WouldBlock` transitorio, mitigado con reintentos acotados.
- La identidad aplica RAT-1 y elimina el punto de extensión: una tercera definición de identidad no
  está probada (FIR-13).
