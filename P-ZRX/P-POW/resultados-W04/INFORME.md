# INFORME.md — ORDEN-W04

**Motor PoW de la red dev en el crate nuevo `crates/zx-consensus`, parametrizado por red.**
Sesión: DeepSeek Harness, modelo `deepseek-flash`, esfuerzo `high`. Fecha: 2026-09-26,
01:38–01:55 +02:00. Zona única: `/home/katana/zeo/ZEROX/deepseek/W04/`.
Sin Python, sin dependencias Rust nuevas, sin `unsafe`, sin commit ni push, nada escrito fuera de la
zona. Base: workspace de la raíz (W01+W02) copiado a `ws.orig/` y `ws/`.

**Pregunta falsable:** «Con los parámetros antiguos, el código parametrizado reproduce exactamente
los resultados de `9681061` (constantes derivadas y tests antiguos portados); con el perfil dev, un
minero CPU produce en segundos cabeceras que el verificador acepta, y el verificador rechaza cada
cabecera inválida de §6 con su error.»
**Veredicto: NO REFUTADA — SUPERADO.** Los tests portados dan los mismos valores, V5 mina y valida
40/40 cabeceras dev, y los 14 casos de `tests/verificador_pow.rs` cubren los rechazos de §6 con su
error explícito.

## 1. Veredicto por paso

| Paso | Comando (desde `ws/`, entorno §4) | Veredicto |
|---|---|---|
| V1 | `cargo fmt --all -- --check` | **OK** (exit 0; `logs/V1-fmt.log`) |
| V2 | `cargo clippy --workspace --all-targets --all-features --locked -- -D warnings` | **OK** (exit 0; 0 avisos; `logs/V2-clippy.log`) |
| V3 | `cargo test --workspace --all-features --locked` | **OK** (exit 0; **265** pasan, 0 fallan; `logs/V3-test.log`) |
| V4 | tests portados de `dificultad`/`fork_choice`/`genesis` con `PARAMETROS_POW_ANTIGUOS` | **OK** (mismos valores; ver §3) |
| V5 | `tests/pow_dev.rs::v5_cadena_dev_minada_y_validada` | **OK** (40/40 válidos; `logs/V5-medicion.log`) |
| V6 | `tests/pow_dev.rs::v6_retarget_dev_responde_y_no_supera_el_maximo` | **OK** (baja con rápido, sube con lento, techo respetado) |
| V7 | `bash ci/dependencias-exactas.sh` (+ `bash ci/frontera-crates.sh`) | **OK** (10 dependencias exactas; frontera `zx-consensus → {zx-core}`) |
| Entrada | `sha256sum -c P-ZRX/P-POW/ENTRADA-W04.sha256` al inicio y al final | **OK** en ambos (4/4; `logs/entrada-inicio.log`) |

Desglose de V3 (265): `zx-consensus` = **65** (lib) + **2** (`pow_dev`: V5+V6) + **14**
(`verificador_pow`) = 81; `zx-core` = **148** (lib) + 4 (`cavp_sha3_256`) + 1 (`ed25519_no_unicidad`)
+ 19 (`formato_v0`) + 1 (`oraculo_julia`) + 2 (`parsers_dag_prop`) + 4 (`vectores_dag`) = 179;
`zx-pot` = 1 + 3 + 1 = 5; doc-tests 0. Antes de W04 eran 182: los **182 siguen presentes con su
mismo nombre** (`logs/.pre-W02-tests.txt` vs `logs/.post-tests.txt`; la lista de desaparecidos está
vacía).

## 2. Archivos cambiados y por qué

**`crates/zx-core/src/` (solo `target.rs` y su reexport):**

| Fichero | Cambio | Motivo |
|---|---|---|
| `target.rs` | `LimitesTarget { min, max }`, `LIMITES_ANTIGUOS`, `LIMITES_AMPLIOS`, `decodificar_con`, `codificar_con`; `CompactBits::decodificar`/`codificar` delegan en `LIMITES_ANTIGUOS` | §3.3: límites de target por red sin cambiar los valores antiguos |
| `lib.rs` | reexport de los cinco símbolos nuevos | uso desde `zx-consensus` |

Los **12 tests antiguos** de `target.rs` pasan sin cambios; se añaden 2 (los límites antiguos
coinciden con `min_target`/`pow_limit`; `0x1e7fffff` se admite con límites amplios y se rechaza con
los antiguos).

**`crates/zx-consensus/` (nuevo):**

| Fichero | Contenido |
|---|---|
| `Cargo.toml`, `README.md` | crate nuevo; solo `zx-core`, `primitive-types`, `thiserror` (+ `proptest` de test, ya en el lock) |
| `src/parametros.rs` | `ParametrosPow { t, n, limites, bits_iniciales, mtp_w }`, derivadas `k/nk/st_cap/t_floor/ftl`, `PARAMETROS_POW_ANTIGUOS`, `PARAMETROS_POW_DEV`, `limites_de(red)` |
| `src/algoritmo.rs` | `trait AlgoritmoPow`, `Sha3Dev` (dev; IPA A-12 abierto) |
| `src/activacion.rs` | ramas; `RAMA_DEV = (CBID_RED_DEV, 0)`; mainnet/testnet sin cambios |
| `src/error.rs` | `ErrorPow` (una variante por rechazo) y `es_permanente()` |
| `src/dificultad.rs` | LWMA-1 portado con `U512`, solvetimes monótonos, `BIAS = 1/1`, clamp por red; `median_time_past` |
| `src/timestamps.rs` | `C-TS-01`, `C-TS-03` (con `ftl` del perfil), `C-TS-05` |
| `src/fork_choice.rs` | `preferir`, `trabajo_acumulado`; **sin** `MAX_REORG_LENGTH` ni `ClaveVentana` |
| `src/genesis.rs` | `ParametrosGenesis`, `GENESIS_{MAINNET,TESTNET,DEV}`, `HASH_GENESIS_{TESTNET,DEV}`, `coinbase_genesis`, `construir`, `comprobar`, `comprobar_al_arrancar`, `target_inicial_bits` |
| `src/verificador.rs` | `ContextoPow`, `validar_cabecera_pow` |
| `src/minero_dev.rs` | `minar(plantilla, target, algo, max_intentos, cancelar)`; nonce desde 0, un hilo, sin `unsafe` |
| `src/lib.rs` | módulos y reexports |
| `tests/pow_dev.rs` | V5 (40 bloques) y V6 (retarget dev) |
| `tests/verificador_pow.rs` | positivos y negativos de §5/§6 |

**CI y lock:** `.github/workflows/zerox-ci.yml` (comentario actualizado + paso de frontera),
`ci/frontera-crates.sh` (adaptado de `9681061` a `zx-consensus → {zx-core}`; `jq` **sí** está
disponible, `logs/V7-frontera.log`), `Cargo.toml` (miembro nuevo), `Cargo.lock` (única adición).

## 3. V4 — tests portados y omitidos

Con `PARAMETROS_POW_ANTIGUOS` (`T=120`, `N=90`, `LIMITES_ANTIGUOS`, `bits_iniciales=0x1c07fff8`,
`mtp_w=11`) los derivados valen **exactamente** `K=491_400`, `NK=44_226_000`, `ST_CAP=720`,
`T_FLOOR=49_140`, `FTL=540` (test `las_constantes_precomputadas_cuadran`, en `parametros.rs`).

| Módulo antiguo | Portados | Omitidos (motivo) |
|---|---|---|
| `dificultad.rs` (14) | **14**: constantes, régimen estable, rápido/lento, suelo ×10, timestamps que retroceden, acotado, determinismo, tamaños de ventana, `BIAS=1`, sesgo del clamp, cota `U512`, MTP (2) | 0 |
| `fork_choice.rs` (11) | **5**: trabajo vs altura, desempate por menor hash, independencia del orden, recálculo, cadena vacía | **6**: `MAX_REORG_LENGTH` (eliminado por §3.7) y `ClaveVentana` (caché de reorg, de la máquina de estados/W03): `el_limite_de_reorg_es_madurez_menos_uno`, `el_borde_de_la_profundidad_maxima`, `un_coinbase_maduro_no_puede_deshacerse`, `la_profundidad_es_la_distancia_al_ancestro_comun`, `el_cache_se_invalida_por_hash_no_por_altura`, `la_igualdad_de_la_clave_solo_mira_el_hash` |
| `timestamps.rs` | 0 (el módulo no traía tests) | 0; se añaden 3 tests nuevos (monotonía, FTL diferible, `timestamp_del_minero`) |
| `genesis.rs` (21) | **21** (mismos nombres; `HASH_GENESIS_TESTNET` sigue congelado) | 0 |
| `activacion.rs` (7) | **6** + dev | **1**: `los_prefijos_magicos_no_son_utf8_valido`, ya cubierto en `zx-core::red` |

La única diferencia de firma necesaria es `comprobar(cabecera, coinbase, red)` —el `bits` del génesis
se valida contra los límites **de su red**, y dev no cabe en los antiguos—; y
`siguiente_target(ventana, &parametros)` / `median_time_past(ultimos, &parametros)`.

## 4. Casos negativos de `validar_cabecera_pow` (§6)

| Caso | Error |
|---|---|
| `branch_id` de mainnet en la red dev | `BranchIdIncorrecto` |
| `prev_hash` distinto | `PrevHashIncorrecto` |
| `height` = padre y = padre + 2 | `AlturaIncorrecta { esperada: 1, encontrada: 0/2 }` |
| `bits` ≠ esperado (canónico) | `BitsIncorrectos` |
| `bits` no canónico (`0x1d0000ff`) | `BitsNoCanonicos` |
| `bits` fuera de límites (`0x1f7fffff`) | `TargetFueraDeRango` |
| `hash_pow == target` y `> target` | `PowInsuficiente` (comparación **estricta**) |
| `ts = ts_padre` | `TimestampNoMonotono` y `es_permanente() == true` |
| `ts > reloj_local + ftl` | `TimestampDemasiadoFuturo` y `es_permanente() == false` |

Además: una cabecera correcta valida (con hash a cero) y una cabecera **minada de verdad** con
`Sha3Dev` también.

## 5. Valores congelados

- `HASH_GENESIS_DEV =
  c72fdb3b37e7571a82ec1e0e973e90d5e95e7ad9fc871772265b1994050c2d59`
  (test `el_hash_del_genesis_dev_esta_congelado` y `el_arranque_dev_valida_y_compara_el_hash`).
- Génesis dev: `Red::Dev`, mensaje `b"ZEROX hibrido red dev v0 - sin valor"`, timestamp
  `1_790_380_800`, `nonce 0`, `bits 0x1e7fffff`, `CBID 0xa8b466a7`.
- Perfil dev: `T=2`, `N=20`, `mtp_w=11`, `limites.min = 2^64`,
  `limites.max = 0x7fffff · 2^216 = 2^239 − 2^216` (recalculado en test), `bits_iniciales=0x1e7fffff`.
  Derivados: `k=420`, `nk=8400`, `st_cap=12`, `t_floor=42`, `ftl=2` (`logs/derivados-dev.log`).
- `Cargo.lock`: de 130 a 131 paquetes; **única** adición `zx-consensus 0.0.0`; ningún paquete
  existente cambia de versión (`logs/lock-subconjunto.txt`).
- V5: 40/40 válidos; intentos/bloque **media 136733**, **máximo 448988**, total 5 469 356; tiempo de
  pared **124,8 s** en perfil `test` (sin `--release`; `logs/V5-medicion.log`). La primera corrida
  dio 161,2 s con carga ajena: no es benchmark.

## 6. Falta de definición detectada (informada antes de editar)

`ORDEN-W04 §3.5` pide `limites.max = decodificar(0x1e7fffff)` con el aviso de parar si `0x1e7fffff`
viola alguna regla de `target.rs`. **Es canónico**; su target `2^239 − 2^216` **supera el
`POW_LIMIT` antiguo** (`2^224 − 1`), que es exactamente lo que `LimitesTarget` existe para
parametrizar por red. No se eligió otro valor: el perfil dev usa sus límites y `decodificar_con` los
aplica. Queda fijado con tres tests. No se detectó ninguna otra falta de definición.

## 7. Lo que esta orden NO demuestra

- **Seguridad del PoW de SHA3-256**: que resista a hash alquilable o que distribuya la emisión.
- **Idoneidad de los parámetros dev** (`T=2`, `N=20`, target fácil): son de desarrollo, elegidos
  para que una red local mine en segundos; **no** son de producción.
- **Algoritmo de producción**: `Sha3Dev` es un parámetro de desarrollo; IPA A-12 sigue abierto.
- **Validación de cuerpo, coinbase y fin del PoW (TRN-05)**: es W03; aquí solo se valida la
  cabecera.
- **Transición PoW → PoST** (TRN-04, TRN-06, corte, FC-3, `F_slots`): fuera de alcance.
- **Profundidad de reorganización**: `MAX_REORG_LENGTH` se eliminó y no se sustituye aquí.
- **PoAS, PoT, GHOSTDAG, nodo, red**: otras órdenes.
- **La CI en GitHub**: no se ejecutó allí.
- **Independencia de la especificación**: que dos implementaciones coincidan no prueba que el SPEC
  sea correcto.

## 8. Presupuesto y trazas

Presupuesto: 2 h de reloj, 8 hilos, 16 GiB de RAM, 20 GiB de disco. Consumo real ≈ 17 min de reloj;
`ws` 2,3 MiB, `ws.orig` 2,2 MiB, `.cargo-home` 697 MiB, `target` 821 MiB, `ref/` 136 KiB (volcado
de solo lectura de las fuentes antiguas portadas); total de la zona ≈ 1,5 GiB, muy por debajo de los
20 GiB. Toolchain `nightly-2026-05-03` (`cargo 1.97.0-nightly`, `rustc 1.97.0-nightly`).
Artefactos: `ws/`, `ws.orig/`, `cambios.patch` (3290 líneas), `MIGRACION.sha256` (70 huellas,
`sha256sum -c` OK), `logs/` (V1–V7, entrada, lock, derivados, V5), `INFORME.md`, `PROGRESO.md`,
`HORAS.log`.

## 9. Resumen final (≤ 40 líneas)

1. W04 cumple: crate **nuevo** `crates/zx-consensus` con el motor PoW dev parametrizado por red.
2. `zx-core/target.rs` gana `LimitesTarget`, `LIMITES_ANTIGUOS`, `LIMITES_AMPLIOS` y
   `decodificar_con`/`codificar_con`; los 12 tests antiguos pasan sin cambios.
3. `ParametrosPow { t, n, limites, bits_iniciales, mtp_w }` con derivadas comprobadas.
4. Con `T=120, N=90`: `K=491400`, `NK=44226000`, `ST_CAP=720`, `T_FLOOR=49140`, `FTL=540`.
5. Perfil dev `T=2, N=20, mtp_w=11, bits_iniciales=0x1e7fffff`, `max=2^239−2^216`.
6. LWMA-1 portado con `U512`, solvetimes monótonos, `BIAS=1/1` y clamp contra los límites de red.
7. Selección por trabajo con desempate por menor hash; `MAX_REORG_LENGTH` eliminado.
8. Timestamps con `ftl` del perfil; futuro es diferible, no permanente.
9. Rama dev única `(CBID_RED_DEV, 0)`; mainnet/testnet conservan la tabla antigua.
10. `validar_cabecera_pow` comprueba rama, padre, altura, `bits`, PoW estricto y timestamps.
11. Génesis dev construido y congelado: `HASH_GENESIS_DEV=c72fdb3b…0c2d59`.
12. Minero CPU dev `minar` con `nonce` desde 0, un hilo, sin `unsafe`.
13. `0x1e7fffff` es canónico; supera `POW_LIMIT` a propósito y solo es legal con límites por red.
14. V1 fmt OK; V2 clippy 0 avisos; V3 265 pasan, 0 fallan; V4 mismos valores.
15. V5 mina y valida 40/40 cabeceras dev (media 136733 intentos, máximo 448988, pared 124,8 s).
16. V6: rápido baja el target, lento lo sube, nunca por encima de `limites.max`.
17. V7: 10 dependencias exactas y frontera `zx-consensus → {zx-core}`.
18. `Cargo.lock` solo añade `zx-consensus 0.0.0`; ninguna versión existente cambia.
19. «Lo que NO demuestra»: seguridad del PoW, parámetros dev, algoritmo de producción, cuerpo y
    transición, PoAS/PoT/GHOSTDAG, CI en GitHub.
20. Veredicto: **SUPERADO**; la pregunta falsable no queda refutada.
