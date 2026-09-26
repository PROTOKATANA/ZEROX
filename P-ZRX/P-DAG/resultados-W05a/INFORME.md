# INFORME.md — ORDEN-W05a

**Crate nuevo `crates/zx-dag`: GHOSTDAG, comprobación contextual de padres con D-P08, rango
validado, vista causal y la identidad de billete, con la raíz en el terminal PoW (D-P07).**
Sesión: DeepSeek Harness, modelo `deepseek-flash`, esfuerzo `high`. Fecha: 2026-09-26,
01:56–02:08 +02:00. Zona única: `/home/katana/zeo/ZEROX/deepseek/W05a/`. Sin Python, sin
dependencias Rust nuevas, sin `unsafe`, sin commit ni push, nada escrito fuera de la zona. Base:
workspace de la raíz (W01+W02+W04) copiado a `ws.orig/` y `ws/`.

**Pregunta falsable:** «GHOSTDAG portado reproduce exactamente los vectores de sus dos oráculos
antiguos (GDR-v0.2 y rusty-kaspa) y sus tests, con la raíz en el `block_hash` de una cabecera PoW
de 92 B, y la comprobación de padres rechaza toda cabecera PoST sin padres o con un padre PoW que
no sea el terminal.»
**Veredicto: NO REFUTADA — SUPERADO.** Los dos oráculos coinciden (28 DAGs GDR-v0.2 en referencia
y kernel; 180 comprobaciones rusty-kaspa), los 265 tests previos siguen con su nombre y los casos
V6 de D-P08 dan, cada uno, su resultado.

## 1. Veredicto por paso

| Paso | Comando (desde `ws/`, entorno §4) | Veredicto |
|---|---|---|
| V1 | `cargo fmt --all -- --check` | **OK** (exit 0; `logs/V1-fmt.log`) |
| V2 | `cargo clippy --workspace --all-targets --all-features --locked -- -D warnings` | **OK** (exit 0; 0 avisos; `logs/V2-clippy.log`) |
| V3 | `cargo test --workspace --all-features --locked` | **OK** (exit 0; **371 pasan, 0 fallan, 1 ignorado**; `logs/V3-test.log`) |
| V4 | `ghostdag_oraculo`: GDR-v0.2 (`corpus-rust.txt`) y rusty-kaspa (`kaspa-rust.txt`) | **OK** (28 DAGs en cada algoritmo; 180 comprobaciones Kaspa; `logs/V4-oraculo.log`) |
| V5 | Lista de tests portados/sustituidos/retirados | **OK** (`logs/V5-tests.txt`; ningún test de lógica GHOSTDAG retirado) |
| V6 | Casos D-P08 (0 padres; transición 2 padres; `T` extra; PoW ajeno; transición válida con `T`; descendiente PoST válido) | **OK** (`tests/padres_dp08.rs`, 6/6; `logs/V3-test.log`) |
| V7 | `bash ci/dependencias-exactas.sh` (+ `ci/frontera-crates.sh`) | **OK** (10 dependencias exactas; fronteras `zx-consensus` y `zx-dag` → `{zx-core}`; `logs/V7-*.log`) |
| Entrada | `sha256sum -c P-ZRX/P-DAG/ENTRADA-W05a.sha256` al inicio y al final | **OK** en ambos (4/4; `logs/entrada-inicio.log`, `logs/entrada-final.log`) |
| Banco | `cargo test -p zx-dag --release --test ghostdag_bench -- --ignored --nocapture` | **OK** (no exigido por V1–V7; `logs/bench-ghostdag.log`) |

Desglose de V3 (372 nombres listados = 371 pasan + 1 ignorado): `zx-consensus` = 65 + 2
(`pow_dev`) + 14 (`verificador_pow`) = 81; `zx-core` = 148 + 4 (`cavp_sha3_256`) + 1
(`ed25519_no_unicidad`) + 19 (`formato_v0`) + 1 (`oraculo_julia`) + 2 (`parsers_dag_prop`) + 4
(`vectores_dag`) = 179; `zx-pot` = 1 + 3 + 1 = 5; `zx-dag` = 36 (lib) + 16 (`dag_causal`) + 3
(`ghostdag_oraculo`) + 3 (`ghostdag_prop`) + 41 (`ghostdag_rust`) + 6 (`padres_dp08`) = 105, más
el banco ignorado y 1 doc-test (`compile_fail`). Los **265** nombres de W04 siguen presentes con su
mismo nombre (0 ausentes; `logs/.pre-W05a-tests.txt` vs `logs/.post-tests.txt`).

## 2. Falta de definición detectada (informada antes de editar)

**Ninguna impide cumplir la orden tal cual.** Se aplican tres interpretaciones, sin lógica nueva:

1. **Orden de las comprobaciones de D-P08** (§3.4): `0` padres → `CabeceraPostSinPadres`;
   `seleccionado == T` y `count != 1` → `TerminalConPadresExtra`; extra `== T` →
   `TerminalComoPadreExtra`; padre no terminal ni validado → `PadreNoValidado`; después slot,
   anticadena y `prev_hash == sp`. Queda fijado con tests.
2. **`genesis` → `terminal`.** `AlmacenGhostdag` y `ContextoDag::es_terminal` renombran el concepto;
   el coloreo GHOSTDAG no cambia ni un paso.
3. **`bloque_dag.rs` entero.** Se porta `comprobar_compromisos_cuerpo_dag`; se retira un único test
   por depender de `zx_consensus::testigo` (W05b/W03) y otro por depender de `zx-storage` (W06),
   ambos declarados en `logs/V5-tests.txt`.

## 3. Archivos cambiados y por qué

**`crates/zx-dag/` (nuevo):**

| Fichero | Contenido |
|---|---|
| `Cargo.toml`, `README.md` | crate nuevo; solo `zx-core`, `primitive-types`, `thiserror` (+ `proptest` de test, ya en el lock) |
| `src/error.rs` | `ErrorDag`: las 18 variantes usadas por los módulos portados + 3 de D-P08 |
| `src/identidad.rs` | `IdentidadTicket` portado sin cambios de bytes (`huella`, `bytes_canonicos`) y `identidad_de_cabecera` (cuerpo de `Firmante::identidad`) |
| `src/bloque_dag.rs` | `CandidatoSinRango`, `ContextoRangoDag`, `RangoSolucionValidado`, `comprobar_rango_contextual`, `ContextoDag` (sin `es_genesis`, con `es_terminal`), `comprobar_padres_contextual` (D-P08), `comprobar_compromisos_cuerpo_dag` |
| `src/ghostdag.rs` | lógica idéntica; `ErrorDag`, `identidad_de_cabecera`, `AlmacenGhostdag::con_raiz_terminal` (D-P07) y `ContextoDag::es_terminal` |
| `src/dag_causal.rs` | `RegistroEstructural`, `FuenteRegistrosDag`, `PresupuestoVista`, `ErrorVistaCausal`, `VistaPasadoEstructural`; **no** `FuenteIndiceAdmitidos` |
| `tests/ghostdag_rust.rs` (41), `ghostdag_prop.rs` (3), `ghostdag_bench.rs` (1 `#[ignore]`), `ghostdag_oraculo.rs` (3), `dag_causal.rs` (16), `padres_dp08.rs` (6) | portados/adaptados + V6 |

**Raíz del workspace:**

| Fichero | Cambio | Motivo |
|---|---|---|
| `Cargo.toml` | miembro `crates/zx-dag` | D-P13 |
| `Cargo.lock` | única adición `zx-dag 0.0.0` (132 paquetes) | §4; `logs/lock-subconjunto.txt` |
| `ci/frontera-crates.sh` | generalizado a `zx-consensus` y `zx-dag` → `{zx-core}` | D-P13: `zx-dag` no depende de `zx-consensus`/`zx-storage` |
| `.github/workflows/zerox-ci.yml` | comentario y nombre del paso de frontera | documentación |
| `testdata/ghostdag-rank-v1/{corpus-rust.txt,kaspa-rust.txt,PROCEDENCIA.md}` | vectores copiados sin cambios | §3.7 |

## 4. Decisiones aplicadas

- **D-P07.** `AlmacenGhostdag::con_raiz_terminal(params, algoritmo, hash_terminal, sr_raiz)` =
  `nuevo(..., slot 0, sr_raiz, identidad 0)`; `blue_work` de la raíz 0. El primer hijo hereda `w(T)`
  como azul de la raíz (test `con_raiz_terminal_fija_slot_cero_y_hereda_el_peso_de_t`).
- **D-P08.** No hay génesis DAG. `0` padres siempre inválido; transición = único padre `T`; `T` como
  extra o un PoW ajeno ⇒ rechazo. `ContextoDag` pierde `es_genesis` y gana `es_terminal`.
- **D-P13.** `zx-dag` depende solo de `zx-core`, `primitive-types` y `thiserror`; lo vigila
  `ci/frontera-crates.sh`.
- **Parámetros (D-P10…D-P12).** `k = 30`, 15 padres, mergeset 180 y `S_max = 150` se conservan como
  valores por defecto de `Parametros`: **valores del consenso antiguo, condicionales; la red dev
  fijará los suyos**.

## 5. API de `zx-dag`

- **`identidad`**: `IdentidadTicket` (`vigente`, `huella`, `bytes_canonicos`, `slot`);
  `identidad_de_cabecera`; consts `LONGITUD_HUELLA`, `DOMINIO_TICKET_VIGENTE`, `VERSION_ESQUEMA`.
- **`bloque_dag`**: `CandidatoSinRango` (`padres`, `slot`, `height`, `timestamp`, `pot_output`);
  `ContextoRangoDag::rango_esperado`; `RangoSolucionValidado` (`valor`, `bloque`, `validar`,
  `para_oraculos`, `peso`); `comprobar_rango_contextual`; `ContextoDag` (`es_bloque_validado`,
  `esta_en_el_pasado_de`, `slot_de_padre`, `padre_seleccionado`, `es_terminal`);
  `comprobar_padres_contextual`; `comprobar_compromisos_cuerpo_dag`.
- **`ghostdag`**: consts `K_POR_DEFECTO`, `MAX_PADRES_POR_DEFECTO`, `MERGESET_LIMITE_POR_DEFECTO`,
  `S_MAX_POR_DEFECTO`; `Idx`, `ModoSp`, `ModoMerge`, `Algoritmo`, `Parametros`, `Color`,
  `IdentidadGhostdag` (`de_fixture`), `BloqueGhostdag`, `Rank`, `DatosGhostdag`; `peso`,
  `sumar_blue_work`, `hash_de_id_textual`; `AlmacenGhostdag` (`nuevo`, `con_raiz_terminal`,
  `parametros`, `algoritmo`, `len`, `is_empty`, `terminal`, `datos`, `id`, `padres_de`, `rank`,
  `color_en`, `seleccionar_copia`, `cadena_seleccionada`, `punta_virtual`, `orden_aplicacion`,
  `admitir`, `anadir_sintetico`).
- **`dag_causal`**: `RegistroEstructural` (`nuevo`, `hash`, `padres`, `slot`);
  `FuenteRegistrosDag` (`leer`); `PresupuestoVista` (`nuevo`, `max_registros`);
  `VistaPasadoEstructural` (`desde_padres`, `ancestros`, `contiene`, `get`, `len`, `is_empty`);
  `ErrorVistaCausal` (6 variantes).
- **`error`**: `ErrorDag` (21 variantes).
- La raíz reexporta los tipos principales (`AlmacenGhostdag`, `ContextoDag`, `ErrorDag`,
  `IdentidadTicket`, `identidad_de_cabecera`, `RangoSolucionValidado`, `VistaPasadoEstructural`, …).

## 6. Oráculos y banco

- **GDR-v0.2** (`corpus-rust.txt`, 5 085 B, sha256 `dff05e21…f0a8`): **28 DAGs** coinciden con la
  implementación `Referencia` y con la `Kernel`.
- **rusty-kaspa** (`kaspa-rust.txt`, 4 656 B, sha256 `1ab0a081…6922`): **180 comprobaciones**
  (modo `SP_KASPA`/`MERGE_KASPA`, U2/U3 off) en los dos algoritmos.
- Los vectores son artefactos **copiados, no re-validados en el árbol nuevo** (`PROCEDENCIA.md`).
- **Banco release** (`|mergeset| = 179`, `k = 30`, mediana de 21 repeticiones, 1 hilo): coloreo
  **kernel 143,827 µs**, **referencia 84,298 µs**. Coste por bloque (ventana 30):
  1,16–2,60 µs/bloque (kernel) y 1,37–4,31 µs/bloque (referencia) para `n` de 100 a 1600. No es un
  benchmark de red ni de producción.

## 7. Casos V6 (D-P08), uno a uno

| Caso | Resultado |
|---|---|
| Cabecera PoST con 0 padres | `ErrorDag::CabeceraPostSinPadres` (siempre) |
| Transición con 2 padres (seleccionado `T`) | `ErrorDag::TerminalConPadresExtra { declarados: 2 }` |
| Terminal `T` como padre adicional | `ErrorDag::TerminalComoPadreExtra { terminal: T }` |
| Padre PoW ajeno (no `T`) | `ErrorDag::PadreNoValidado { padre: ajeno }` |
| Transición válida con `T` como único padre y almacén con raíz `T` | `Ok(())` |
| Descendiente PoST válido (`P` hijo de `T`) | `Ok(())` |

## 8. Lo que esta orden NO demuestra

- **Admisión en el nodo**: ninguna ruta de `zx-node` llama a `comprobar_padres_contextual` ni a
  `admitir`; la puerta conjunta PoST es W05b.
- **Verificación PoT/PoAS y firma del sello**: no se toca; `admitir` valida **solo** el `SR`.
- **Persistencia**: el almacén es en memoria; `FuenteIndiceAdmitidos` (sobre `zx-storage`) **no** se
  portó (W06).
- **Procedencia causal del `SR` y del flujo**: el `ContextoRangoDag` de los tests es un valor fijo;
  falta el controlador real. El test `el_sr_sintetico_libre_sigue_siendo_una_puerta_trasera` exhibe
  el hueco.
- **Coste de `blue_idents`/U2**: la colección se copia por bloque y no tiene índice acotado; no hay
  cota medida para la ruta de red.
- **Parámetros dev**: `k`, padres, mergeset y `S_max` son los del consenso antiguo (condicionales).
- **Oráculos Julia**: no se recomputaron ni re-validaron en el árbol nuevo; el corpus es copia.
- **`zx-consensus`**: no se modificó ni se portó `firmante`/`testigo`; el registro durable es W06.
- **La CI en GitHub**: no se ejecutó allí.
- **Idoneidad de GHOSTDAG como regla de seguridad**: reproducir un oráculo no prueba que el SPEC sea
  correcto.

## 9. Presupuesto y trazas

Presupuesto: 2 h de reloj, 8 hilos, 16 GiB de RAM, 20 GiB de disco. Consumo real ≈ 12 min de reloj;
`ws` 3,1 MiB, `ws.orig` 2,3 MiB, `.cargo-home` 697 MiB, `target` 1,2 GiB, `ref/` 828 KiB, `logs/`
112 KiB; total de la zona ≈ 1,9 GiB, muy por debajo de los 20 GiB. Toolchain `nightly-2026-05-03`
(`cargo 1.97.0-nightly`, `rustc 1.97.0-nightly`), 8 jobs, `RUST_TEST_THREADS=8`, `RUSTFLAGS=`.
Artefactos: `ws/`, `ws.orig/`, `cambios.patch` (12 348 líneas, 21 ficheros), `MIGRACION.sha256`
(87 huellas, `sha256sum -c` OK), `logs/` (V1–V7, entrada, lock, migración, banco, V5), `INFORME.md`,
`PROGRESO.md`, `HORAS.log`.

## 10. Resumen final (≤ 40 líneas)

1. W05a cumple: crate **nuevo** `crates/zx-dag` con GHOSTDAG, padres contextuales, rango validado y
   vista causal, raíz en el terminal PoW (D-P07/D-P08/D-P13).
2. `zx-dag` = `zx-core` + `primitive-types` + `thiserror`; no depende de `zx-consensus` ni de
   `zx-storage` (lo vigila `ci/frontera-crates.sh`).
3. `ghostdag.rs` con lógica idéntica; `ConsensusError` → `ErrorDag` y `Firmante::identidad` →
   `identidad_de_cabecera`.
4. `AlmacenGhostdag::con_raiz_terminal(params, algoritmo, T, sr_raiz)` = `nuevo(..., slot 0,
   sr_raiz, 0)`; `blue_work` de la raíz 0.
5. `ContextoDag` pierde `es_genesis` y gana `es_terminal`; el almacén real lo implementa con la raíz.
6. D-P08: `0` padres ⇒ `CabeceraPostSinPadres`; transición = único padre `T`;
   `TerminalConPadresExtra`, `TerminalComoPadreExtra` y `PadreNoValidado` con sus casos.
7. `identidad.rs`: `IdentidadTicket` sin cambios de bytes + `identidad_de_cabecera`.
8. `dag_causal.rs` genérico sin `FuenteIndiceAdmitidos`; vista inmutable, determinista y con
   presupuesto local.
9. Vectores GDR-v0.2 y rusty-kaspa copiados a `testdata/ghostdag-rank-v1/` con `PROCEDENCIA.md`.
10. V1 `fmt` OK; V2 `clippy -D warnings` 0 avisos.
11. V3 **371 pasan, 0 fallan, 1 ignorado**; los **265** nombres de W04 siguen (0 ausentes).
12. V4: 28 DAGs GDR-v0.2 en referencia **y** kernel; 180 comprobaciones rusty-kaspa.
13. V5: portados/sustituidos/retirados declarados; 2 retirados (testigo y almacén), ninguno de
    lógica GHOSTDAG.
14. V6: 6 casos D-P08 con su resultado.
15. V7: 10 dependencias exactas; fronteras `zx-consensus` y `zx-dag` → `{zx-core}`.
16. `Cargo.lock`: única adición `zx-dag 0.0.0`; ninguna versión existente cambia.
17. Banco release (ignorado): kernel 143,8 µs / referencia 84,3 µs con `|mergeset| = 179`.
18. «Lo que NO demuestra»: admisión en el nodo, verificación PoT/PoAS, persistencia, controlador de
    `SR`, parámetros dev, oráculos no recomputados.
19. Veredicto: **SUPERADO**; la pregunta falsable no queda refutada.
