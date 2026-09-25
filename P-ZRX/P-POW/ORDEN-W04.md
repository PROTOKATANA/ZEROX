# ORDEN-W04 — Motor PoW de la red dev: verificador, retarget, selección, génesis y minero CPU

## 1. Identidad y contexto

- **ID:** W04. **Estado:** redactada 2026-09-26; se lanza **después** de migrar W02 a la raíz.
  **Director:** Claude. **Ejecutor:** DeepSeek (portado parametrizado; no requiere el plus).
- **Zona (única escribible):** `/home/katana/zeo/ZEROX/deepseek/W04/`.
- **Objetivo único:** dejar en el workspace un crate `zx-consensus` **nuevo** con el motor PoW de la
  fase de arranque para la red dev (D-P05, D-T01; Katana: SHA3-256 tras interfaz), portando del
  commit `9681061` el retarget LWMA-1, la selección por trabajo, las reglas de timestamp y el génesis
  constructivo, **parametrizados por red** en lugar de constantes, más un minero CPU de desarrollo.
- **Pregunta falsable:** «Con los parámetros antiguos, el código parametrizado reproduce
  exactamente los resultados de `9681061` (constantes derivadas y tests antiguos portados); con el
  perfil dev, un minero CPU produce en segundos cabeceras que el verificador acepta, y el verificador
  rechaza cada cabecera inválida de §6 con su error.» Se refuta con un vector antiguo distinto, un
  rechazo que falta o un bloque dev que no se puede minar en el presupuesto.
- **Desbloquea:** `P-ZRX/PLAN-0.0.1.md` W05/W06 (fase PoW de la ruta vertical), IPA A-13.

## 2. Autoridad y entradas

Lee **íntegros**: este archivo; `V-ZRX/LINEO.md`; `P-ZRX/P-TRANSICION/CONTRATO-v0.md` §0 (D-T01)
y §5 (TRN-04, TRN-05); `P-ZRX/P-FORMATO/FORMATO-v0.md` (F-01, F-12, F-13); `P-ZRX/PLAN-0.0.1.md`.
Código base: el workspace de la raíz (incluye W02 migrada). Código antiguo a portar, **solo
lectura**: `git -C /home/katana/zeo/ZEROX show 9681061:crates/zx-consensus/src/<f>` para
`dificultad.rs`, `fork_choice.rs`, `timestamps.rs`, `genesis.rs`, `activacion.rs`, `bloque.rs`
(solo `validar_cabecera`), `error.rs`, y sus tests en `crates/zx-consensus/tests/` y `src/`.

Entrada congelada: `P-ZRX/P-POW/ENTRADA-W04.sha256` (no incluye el contrato, que se está actualizando; úsalo solo como contexto); compruébala al empezar y como último paso.

## 3. Decisiones ya tomadas por el director

1. **Crate nuevo** `crates/zx-consensus` (miembro del workspace; dependencias: `zx-core`,
   `primitive-types`, `thiserror`, y las de test que ya use el workspace). **No** se porta nada más
   de `zx-consensus` antiguo (ni GHOSTDAG, ni PoT, ni PoAS, ni firmante, ni emisión, ni
   validación de transacciones): son otras órdenes.
2. **Interfaz de algoritmo:** `trait AlgoritmoPow { fn hash_pow(&self, cabecera: &BlockHeader) -> [u8; 32]; }`
   e implementación `Sha3Dev`, cuyo `hash_pow` es exactamente el `block_hash` antiguo
   (`SHA3-256("ZZKBlkHeader____" ‖ cabecera)`, F-01). El `block_hash` de la cabecera **siempre** es el
   SHA3; el `hash_pow` es lo que se compara con el target. Docstring: «parámetro de desarrollo; el
   algoritmo de producción está abierto (IPA A-12)».
3. **Límites de target por red, en `zx-core/src/target.rs`:** añade
   `struct LimitesTarget { min: U256, max: U256 }`, `LIMITES_ANTIGUOS` (= `MIN_TARGET` y `POW_LIMIT`
   actuales, **sin cambiar sus valores**) y funciones `decodificar_con(bits, &LimitesTarget)` /
   `codificar_con(target, &LimitesTarget)`; las funciones actuales delegan en `LIMITES_ANTIGUOS` y
   todos los tests antiguos de `target.rs` siguen pasando sin cambios.
4. **Parámetros PoW por red:** `struct ParametrosPow { t: i64, n: usize, limites: LimitesTarget,
   bits_iniciales: u32, mtp_w: usize }` con funciones derivadas que implementan las fórmulas de los
   comentarios antiguos: `k = N(N+1)T/2`, `nk = N·k`, `st_cap = 6T`, `t_floor = N(N+1)T/20`,
   `ftl = N·T/20`, con aritmética comprobada. Test obligatorio: con `T = 120`, `N = 90`,
   `LIMITES_ANTIGUOS`, `bits_iniciales = 0x1c07fff8`, `mtp_w = 11`, los derivados valen exactamente
   `K = 491_400`, `NK = 44_226_000`, `ST_CAP = 720`, `T_FLOOR = 49_140`, `FTL = 540` (constantes de
   `9681061`).
5. **Perfil dev** `PARAMETROS_POW_DEV` (etiquetado **dev**, con comentario que diga que no son
   parámetros de producción y que se eligieron para que una red local de pruebas mine en segundos):
   `T = 2`, `N = 20`, `limites = { min: 2^64, max: decodificar(0x1e7fffff) }`,
   `bits_iniciales = 0x1e7fffff`, `mtp_w = 11`. Si `0x1e7fffff` no es canónico o viola alguna regla
   de `target.rs`, **para** e infórmalo; no elijas otro valor.
6. **Retarget LWMA-1** portado de `dificultad.rs` con `ParametrosPow` en lugar de constantes, misma
   aritmética U512, mismos solvetimes monótonos, mismo `BIAS = 1/1`, mismo clamp (ahora contra
   `limites`). Los tests antiguos de `dificultad.rs` se portan con los parámetros antiguos y deben
   dar los **mismos** resultados.
7. **Selección por trabajo** (`fork_choice.rs`: `preferir`, `trabajo_acumulado`, desempate por
   menor hash big-endian). **Se elimina** `MAX_REORG_LENGTH` (obsoleto: `R-ZRX/MAPA-RESCATE.md`);
   la profundidad de reorganización en la fase PoW no se limita en esta orden.
8. **Timestamps** (`timestamps.rs`) portados con `ftl` y `mtp_w` del perfil.
9. **Tabla de ramas** mínima (`activacion.rs`): para `Red::Dev`, una sola rama
   `(CBID_RED_DEV, 0)`; para mainnet/testnet, la tabla antigua sin cambios.
10. **Verificador de cabecera PoW**: `validar_cabecera_pow(c: &BlockHeader, ctx: &ContextoPow,
    algo: &impl AlgoritmoPow) -> Result<(), ErrorPow>` con `ContextoPow { red, parametros,
    altura_padre, hash_padre, target_esperado, ts_padre, reloj_local }`: comprueba
    `branch_id` de la rama activa, `prev_hash = hash_padre`, `height = altura_padre + 1`,
    `bits = codificar_con(target_esperado)`, `hash_pow < target` (U256 big-endian, estricto),
    `ts > ts_padre` (`C-TS-01`, rechazo permanente) y `ts ≤ reloj_local + ftl` (`C-TS-03`: error
    **distinto y marcado como no permanente**, que el llamante debe diferir y no cachear). **No** valida el cuerpo, la coinbase ni el fin del PoW
    (TRN-05 es de W03).
11. **Génesis dev** según F-13, portando `genesis.rs` (`coinbase_genesis`, `construir`,
    `comprobar`): `Red::Dev`, mensaje `b"ZEROX hibrido red dev v0 - sin valor"`, `timestamp`
    `1_790_380_800` (2026-09-26 00:00:00 UTC, `≥ TIMESTAMP_MINIMO_GENESIS`), `nonce 0`,
    `bits = bits_iniciales` del perfil dev. Calcula su hash, **congélalo** en `HASH_GENESIS_DEV` y
    añade el test «el hash del génesis dev está congelado» como el de testnet.
12. **Minero CPU dev** (`minero_dev.rs`): `minar(plantilla, target, algo, max_intentos,
    cancelar: &AtomicBool) -> Option<BlockHeader>`, recorriendo el `nonce` (bytes 96–103 de la
    preimagen, `OFFSET_NONCE_PREIMAGEN`) de forma determinista desde 0. Un hilo. Sin `unsafe`.

Si algo no se puede cumplir tal cual, **para** e infórmalo antes de improvisar.

## 4. Contrato de ejecución

Mismo patrón que W02: `deepseek/W04/{ws.orig, ws}` copiados de la raíz
(`Cargo.toml Cargo.lock rust-toolchain.toml crates/ testdata/ ci/ .github/`), trabajo en `ws/`,
`cambios.patch` (`diff -ruN ws.orig ws`, sin `target`), `MIGRACION.sha256`, `logs/`, `INFORME.md`,
`PROGRESO.md`, `HORAS.log`. Caché de cargo copiable desde `deepseek/W02/.cargo-home` o
`deepseek/W01/.cargo-home`. Entorno: `CARGO_HOME`/`CARGO_TARGET_DIR` en tu zona,
`CARGO_BUILD_JOBS=8`, `RUST_TEST_THREADS=8`, `RUSTFLAGS=`. `Cargo.lock`: añadir el crate nuevo no
debe **cambiar la versión** de ningún paquete existente; demuéstralo como en W01
(`logs/lock-subconjunto.txt`). Añade `zx-consensus` a la CI (ya la cubre `--workspace`) y, si portas
`ci/frontera-crates.sh`, ajústalo a `zx-consensus → {zx-core}` (sin `jq` si no está: dilo).

## 5. Modelo de amenaza

Cabeceras de un par hostil: `bits` no canónico o fuera de límites, `hash_pow` igual al target (debe
rechazarse: comparación estricta), timestamps retrasados o futuros, altura o padre falsos, rama de
otra red. Ningún pánico, ningún `unwrap` en código no de test (lints del workspace).

## 6. Plan de verificación

Casos negativos mínimos de `validar_cabecera_pow` (cada uno con su error): `branch_id` de mainnet en
la red dev; `prev_hash` distinto; `height` = padre y = padre + 2; `bits` ≠ esperado; `bits` no
canónico; `hash_pow == target` y `hash_pow > target`; `ts = ts_padre` (no monótono) y
`ts > reloj_local + ftl` (no permanente).

| Paso | Comando / comprobación | Criterio |
|---|---|---|
| V1 | `cargo fmt --all -- --check` | limpio |
| V2 | `cargo clippy --workspace --all-targets --all-features --locked -- -D warnings` | 0 avisos |
| V3 | `cargo test --workspace --all-features --locked` | todos los tests previos (zx-core, zx-pot, W02) pasan con el mismo nombre; los portados y nuevos pasan |
| V4 | Tests portados de `dificultad.rs`, `fork_choice.rs`, `timestamps.rs`, `genesis.rs` con parámetros antiguos | mismos resultados que en `9681061` (lista de tests portados y omitidos, con motivo, en el informe) |
| V5 | Test de integración dev: génesis dev → minar 40 bloques con `Sha3Dev` y `PARAMETROS_POW_DEV`, con timestamps simulados a `T` (no reloj real), retarget en cada bloque, y validar cada cabecera | 40/40 válidos; reporta intentos por bloque (media y máximo) y tiempo de pared |
| V6 | Retarget dev: bloques simulados con solvetime `T/4` durante 40 bloques ⇒ el target baja; con `4T` ⇒ sube, sin superar `limites.max` | comprobado |
| V7 | `bash ci/dependencias-exactas.sh` | OK |

**Prohibido Python.**

## 7. Medición

Solo informativa: intentos por bloque y tiempo de V5 (tiempo de pared con carga ajena posible; no
es benchmark). Presupuesto: **2 h, 8 hilos, 16 GiB, 20 GiB de disco**. **SUPERADO** si V1–V7
cumplen.

## 8. Entregables

`ws/`, `cambios.patch`, `MIGRACION.sha256`, `logs/`, `INFORME.md` (veredicto; archivos; tests
portados/omitidos; valores congelados: `HASH_GENESIS_DEV`, derivados del perfil dev; «Lo que esta
orden NO demuestra»: seguridad del PoW, idoneidad de los parámetros dev, algoritmo de producción,
validación de cuerpo y transición), `PROGRESO.md`, `HORAS.log`. Resumen final ≤ 40 líneas.

## 9. Límites de la sesión

DeepSeek Harness, `deepseek-flash`, esfuerzo `high`. `V-ZRX/LINEO.md` leído y aplicado antes del
código. Sin Python. Nada fuera de `deepseek/W04/`. Sin commit ni push. Sin secretos. Ningún `Ok`
ficticio.

## Lanzamiento

    mkdir -p /home/katana/zeo/ZEROX/deepseek/W04 && cd /home/katana/zeo/ZEROX/deepseek/W04 && \
    ( set -a; . /home/katana/torio/deepseek-harness/.env >/dev/null 2>&1; set +a; \
      node /home/katana/torio/deepseek-harness/apps/cli/lib/bin.js --profile headless \
      "Orden W04. Lee íntegro /home/katana/zeo/ZEROX/P-ZRX/P-POW/ORDEN-W04.md y cúmplelo. Antes de escribir código, lee íntegro /home/katana/zeo/ZEROX/V-ZRX/LINEO.md. Si detectas una falta de definición, infórmala antes de editar." \
      > ../W04-dsh.stdout 2> ../W04-dsh.stderr )
