# ORDEN-W02 — Formatos v0 del híbrido en `zx-core`, con oráculo Julia independiente

## 1. Identidad y contexto

- **ID:** W02. **Estado:** redactada 2026-09-26. **Director:** Claude. **Ejecutor:** DeepSeek.
- **Zona (única escribible):** `/home/katana/zeo/ZEROX/deepseek/W02/`.
- **Objetivo único:** implementar en `crates/zx-core` las reglas F-01…F-14 de
  `P-ZRX/P-FORMATO/FORMATO-v0.md` que son de **formato y forma** (códec, `txid`, dominios, firma de
  aceptación, validación estructural sin contexto, red dev), con vectores nuevos generados por un
  **oráculo Julia independiente**, sin romper ningún test ni vector antiguo.
- **Pregunta falsable:** «Las transacciones v2/v3 y la red dev de FORMATO-v0 se pueden codificar,
  hashear y validar estructuralmente de forma canónica, con `txid` idénticos entre Rust y un oráculo
  Julia escrito aparte, sin cambiar un solo byte de los `txid` y vectores v1 de `9681061`.» Se
  refuta con una discrepancia Rust↔Julia, un vector antiguo alterado o un parser que acepta una
  codificación no canónica.
- **Desbloquea:** `P-ZRX/PLAN-0.0.1.md` W03 (máquina de estados) y W04 (motor PoW dev).

## 2. Autoridad y entradas

Lee **íntegros** antes de tocar nada: este archivo; `V-ZRX/LINEO.md` (vinculante para el oráculo
Julia y para los tests); `P-ZRX/P-FORMATO/FORMATO-v0.md` (**la especificación que implementas**);
`P-ZRX/PLAN-0.0.1.md` §3. Código base: el workspace de la raíz del repositorio (commit `29b6bd6`,
`crates/zx-core`, `crates/zx-pot`), que **no** puedes modificar en su sitio.

Entrada congelada: `/home/katana/zeo/ZEROX/P-ZRX/P-FORMATO/ENTRADA-W02.sha256`; compruébala al
empezar y como **último** paso.

## 3. Decisiones ya tomadas por el director

1. Todo lo de FORMATO-v0 §§1–2 y F-12, F-14. **Fuera de esta orden:** génesis (F-13), reglas
   contextuales (posición de la coinbase, `clave == sol.public_key` de F-09, saldos), peso
   (`C-WGT-02`) y todo lo de `zx-consensus`.
2. **Tipo `Tx`.** Añade a `Tx` un campo `extension: ExtensionTx` con
   `enum ExtensionTx { Ninguna, Garantia { tipo: TipoGarantia, clave: ClavePublica, importe: Amount },
   CoinbasePost { clave: ClavePublica, importe: Amount } }` y
   `enum TipoGarantia { Deposito = 1, Retiro = 2, Liberacion = 3 }`. Coherencia obligatoria:
   `version 1 ⇔ Ninguna`, `version 2 ⇔ Garantia`, `version 3 ⇔ CoinbasePost`; la versión 4 y
   cualquier otra no se construyen ni se aceptan (errores distintos: `VersionInactiva(4)` y
   `VersionDesconocida(v)`). Actualiza las construcciones existentes con `ExtensionTx::Ninguna` sin
   cambiar ningún otro valor.
3. **`txid`** exactamente como F-06; **firma de aceptación** exactamente como F-08, con funciones
   públicas `mensaje_aceptacion(tx, cbid) -> [u8; 32]` y
   `verificar_aceptacion(tx, testigo_aceptacion, cbid) -> Result<(), …>` (ZIP-215, reutilizando
   `firma::verificar`).
4. **Etiquetas nuevas** `"ZZKTxIdGarantia_"` y `"ZZKTxSigGarant__"` en `hash.rs`, añadidas a
   `TAGS_FIJAS`; el test existente de unicidad de etiquetas debe seguir pasando y cubrirlas.
5. **Códec** según F-14, en `wire.rs` (`tx_a_bytes`, `tx_desde_bytes`) y en la preimagen.
6. **Validación estructural sin contexto**: función pública
   `validar_forma_tx(tx: &Tx, testigos: &[Vec<u8>]) -> Result<(), ErrorFormaTx>` que aplica: versión
   activa (F-05); recuentos de entradas/salidas/testigos por versión y `tipo` (F-05, F-07, F-08);
   `importe ∈ (0, ZX_VALUE_SANITY_LIMIT]`; `lock_time = 0` y `expiry_height = 0`; sin salidas
   `Lock::Htlc` (F-10); longitud del testigo de aceptación 64 B. **No** comprueba firmas de entradas
   (necesitan el UTXO) ni la posición de la coinbase. Para v1, las transferencias exigen
   `n_in ≥ 1` y `n_out ≥ 1`; una v1 con `n_in = 0` solo es válida como coinbase PoW, lo que esta
   función **no** puede saber: devuelve `Ok` con una marca consultable `es_candidata_coinbase_pow()`
   en el tipo `Tx` y deja la decisión al contexto.
7. **Cabecera PoST**: función pública `validar_forma_cabecera_post(c: &DagBlockHeader) -> Result<(), …>`
   que rechaza `height ≠ 0` (F-03). El parser de cabecera no cambia.
8. **Red dev**: variante `Red::Dev` con `nombre() = "dev"`, `magic()` = primeros 4 bytes de
   `SHA3-256("ZEROX/dev/magic")` (mismo patrón y mismo test de derivación que mainnet/testnet), HRP
   transparente `"dzzk"`; constante `CBID_RED_DEV: u32` según F-12, con un test que la **recalcula**
   de su fórmula. Actualiza todos los `match` sobre `Red`. Ningún valor antiguo de mainnet/testnet
   cambia.
9. **Oráculo Julia independiente** (LINEO): proyecto en `deepseek/W02/oraculo-formato-v0/` con
   `Project.toml`, `Manifest.toml`, `julia-version.toml`, `src/referencia.jl`, `test/runtests.jl`,
   `run.jl`, `INFORME.md`. Implementa **desde FORMATO-v0 y el código de preimagen existente leído como
   especificación, sin traducir el Rust línea a línea**: SHA3-256 (stdlib `SHA`), `H_d`, los
   sub-digest del `txid` v1/v2/v3, el mensaje de aceptación y la codificación de red v1/v2/v3.
   Validación del oráculo: (a) `SHA3-256("")` NIST; (b) reproduce **tres** `txid` v1 de los vectores
   antiguos que ya existan en los tests de `zx-core` (cítalos); (c) produce
   `testdata/formato-v0/vectores.txt` con, al menos, 12 casos: v1 transferencia, v1 coinbase PoW,
   v2 depósito (1 y 3 entradas, con y sin cambio), v2 retiro, v2 liberación, v3 coinbase PoST, con
   `CBID_RED_DEV` y con otro `CBID`: bytes de red en hex, `txid`, mensaje de aceptación. Las claves
   y firmas de los vectores son bytes fijos de prueba (no hace falta firmar en Julia; la firma se
   comprueba en Rust).
10. **Tests Rust nuevos** en `crates/zx-core/tests/formato_v0.rs`: igualdad con cada línea de
    `testdata/formato-v0/vectores.txt` (codificación, `txid`, mensaje); ida y vuelta del códec;
    `validar_forma_tx` y `validar_forma_cabecera_post` con **todos** los casos negativos de §6;
    firma de aceptación válida (clave de prueba determinista con `ed25519-zebra`) y rechazos (otra
    clave, otro `txid`, otra `CBID`, 63/65 bytes).

Si algo no se puede cumplir tal cual, **para** e infórmalo antes de improvisar.

## 4. Contrato de ejecución

    deepseek/W02/
    ├── ws.orig/     copia prístina del workspace de la raíz (solo lectura tras copiarla)
    ├── ws/          copia de trabajo que modificas
    ├── oraculo-formato-v0/
    ├── cambios.patch       diff -ruN ws.orig ws   (sin target ni cachés)
    ├── MIGRACION.sha256    sha256 de cada archivo de ws/ (rutas relativas a ws/)
    ├── .cargo-home/ target/ .julia-depot/
    └── logs/ INFORME.md PROGRESO.md HORAS.log

Copia inicial (desde `/home/katana/zeo/ZEROX`): `Cargo.toml Cargo.lock rust-toolchain.toml crates/
testdata/ ci/ .github/` a `ws.orig/` y a `ws/`. Puedes copiar la caché
`/home/katana/zeo/ZEROX/deepseek/W01/.cargo-home` a tu zona.

Entorno cargo: `CARGO_HOME`, `CARGO_TARGET_DIR` en tu zona, `CARGO_BUILD_JOBS=8`,
`RUST_TEST_THREADS=8`, `RUSTFLAGS=`. Entorno Julia: el de las órdenes T01/T02
(`JULIA_DEPOT_PATH=<zona>/.julia-depot:`, binario
`/home/katana/.julia/juliaup/julia-1.13.0+0.x64.linux.gnu/bin/julia`, `env -u LD_LIBRARY_PATH`,
1 hilo). Sin nuevas dependencias Rust (si crees que hace falta una, para).

## 5. Modelo de amenaza

Bytes de red de un par hostil: el parser no debe entrar en pánico ni aceptar codificaciones no
canónicas (contadores no mínimos, bytes sobrantes, `tipo`/versión fuera de rango, extensiones en
v1, extensión truncada). Un `txid` que coincida entre dos transacciones distintas sería una
colisión de dominio: los tests deben demostrar que cambiar **cualquier** campo de la extensión o la
versión cambia el `txid`.

## 6. Plan de verificación

Casos negativos mínimos (cada uno con su error específico): versión 0, 4, 5 y `u32::MAX`; v1 con
bytes de extensión; v2 con `tipo` 0 y 4; depósito sin entradas; retiro/liberación con entradas o
salidas; v2 con `n_wit ≠ n_in + 1`; testigo de aceptación de 63 y 65 B; `importe = 0` y
`> ZX_VALUE_SANITY_LIMIT`; `lock_time ≠ 0`; `expiry_height ≠ 0`; salida `Htlc`; v3 con entradas,
salidas o testigos; extensión truncada; bytes sobrantes; cabecera PoST con `height = 1` y
`height = u32::MAX`.

Comandos (desde `ws/`, salida en `logs/`):

| Paso | Comando | Criterio |
|---|---|---|
| V1 | `cargo fmt --all -- --check` | limpio |
| V2 | `cargo clippy --workspace --all-targets --all-features --locked -- -D warnings` | 0 avisos |
| V3 | `cargo test --workspace --all-features --locked` | los 161 tests antiguos siguen pasando con el **mismo nombre**, más los nuevos; 0 fallidas |
| V4 | Oráculo: `Pkg.test()` y `run.jl --seed 0x5a5a` | NIST y los 3 `txid` antiguos reproducidos; vectores generados |
| V5 | `diff` de la lista de tests antiguos (de `deepseek/W01/logs`) contra los de V3 | ningún test antiguo desaparece ni cambia de nombre |
| V6 | `git -C /home/katana/zeo/ZEROX show 29b6bd6:<fichero>` comparado con `ws/` para `crates/zx-core/tests/*.rs` y `testdata/` antiguos | vectores antiguos intactos |
| V7 | `bash ci/dependencias-exactas.sh` | OK |

**Prohibido Python.** Ningún test que se autoconfirme: los vectores nuevos vienen del oráculo Julia,
no de la implementación Rust.

## 7. Medición

No hay. Presupuesto: **2 h de reloj, 8 hilos, 16 GiB, 20 GiB de disco**. Criterio: **SUPERADO** si
V1–V7 cumplen; **FALLA** con paso y salida; **INCONCLUSO** si se agota el presupuesto.

## 8. Entregables

`ws/`, `cambios.patch`, `MIGRACION.sha256`, `oraculo-formato-v0/` completo (con su `INFORME.md`
según LINEO), `logs/`, `INFORME.md` (veredicto por paso; lista de archivos cambiados y por qué;
decisiones de nombres de API; casos negativos cubiertos; «Lo que esta orden NO demuestra»:
reglas contextuales, peso, génesis, semántica de estado), `PROGRESO.md`, `HORAS.log`.
Resumen final ≤ 40 líneas en español.

## 9. Límites de la sesión

DeepSeek Harness, `deepseek-flash` («DeepSeek-V41-Flash»), esfuerzo `high`. Lee y aplica
`V-ZRX/LINEO.md` antes de escribir código. Sin Python. Nada fuera de `deepseek/W02/`. Sin commit ni
push. Sin leer secretos. Ningún `Ok` ficticio. Si algo falla, repórtalo literal.

## Lanzamiento

    mkdir -p /home/katana/zeo/ZEROX/deepseek/W02 && cd /home/katana/zeo/ZEROX/deepseek/W02 && \
    ( set -a; . /home/katana/torio/deepseek-harness/.env >/dev/null 2>&1; set +a; \
      node /home/katana/torio/deepseek-harness/apps/cli/lib/bin.js --profile headless \
      "Orden W02. Lee íntegros /home/katana/zeo/ZEROX/P-ZRX/P-FORMATO/ORDEN-W02.md y /home/katana/zeo/ZEROX/P-ZRX/P-FORMATO/FORMATO-v0.md y cúmplelos. Antes de escribir código, lee íntegro /home/katana/zeo/ZEROX/V-ZRX/LINEO.md. Si detectas una falta de definición, infórmala antes de editar." \
      > ../W02-dsh.stdout 2> ../W02-dsh.stderr )
