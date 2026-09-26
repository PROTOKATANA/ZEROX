# PROGRESO.md — ORDEN-W02b

FORMATO v0.1 (F-15…F-18) en `zx-core` (formato, `txid`, códec, forma),
`zx-consensus::transicion` (estado y reglas) y `zx-post` (productor), más el oráculo de formato
v0.1 y el diferencial contra los vectores v0.1 de T01-D.

**Zona única:** `/home/katana/zeo/ZEROX/deepseek/W02b/`.

## Faltas de definición detectadas ANTES de editar (con la lectura aplicada)

La orden pide informar cualquier falta de definición antes de tocar código. Estas son las que el
director no cerró y la lectura (restrictiva o compatible) con la que se implementan. Ninguna
contradice F-15…F-18; todas son necesarias para que la orden sea ejecutable tal cual.

1. **FD-1 · F-16 choca con la letra de `validar_forma_tx` «sin cambios salvo la nueva anchura».**
   La decisión 1 de §3 deja `validar_forma_tx` como estaba, y esa función (F-10) rechaza
   `expiry_height ≠ 0` para **toda** transacción. Pero F-16 exige que la coinbase PoW tenga
   `expiry_height = altura`; en cualquier bloque de altura `> 0` la validación de forma rechazaría la
   coinbase con `ErrForma(CampoInactivo)` **antes** de que el motor pudiera comprobar F-16, y tanto
   el diferencial como el test V5 «coinbase con `expiry_height ≠ altura` ⇒ `ErrEmision`» serían
   inalcanzables. **Lectura aplicada:** en `validar_forma_tx`, la comprobación `expiry_height == 0`
   exime a las transacciones **candidatas a coinbase PoW** (`version == 1`, `inputs.is_empty()`,
   `ExtensionTx::Ninguna`), exactamente igual que la función ya difiere al contexto la **posición**
   de la coinbase mediante `Tx::es_candidata_coinbase_pow`; el motor (`aplicar_coinbase_pow`) exige
   `expiry_height == altura` y devuelve `ErrEmision` si no. `lock_time == 0` y la prohibición de
   `Htlc` siguen siendo universales; una v1 **con** entradas y cualquier v2/v3 con
   `expiry_height ≠ 0` sigue dando `ErrCampoInactivo`. Es un cambio mínimo, aditivo y localizado.

2. **FD-2 · F-18 y el oráculo T01-D conservan `prox_salida`.** La decisión 3 manda **eliminar**
   `prox_salida` del motor Rust (salida de la liberación fija `(txid, 0)`), pero el oráculo T01-D
   (fuente congelada de los vectores) **no** lo eliminó: `aplicar_liberacion!` sigue asignando la
   salida implícita con `E.prox_salida`. **Lectura aplicada:** el motor Rust elimina el contador y
   usa `(txid, 0)` como manda F-18. El diferencial compara el UTXO por
   `(dueño, valor, origen, altura, slot)` y **no** mira el `OutPoint`, y con F-15 los `txid` de dos
   liberaciones de la misma clave ya no coinciden, así que ambos lados son compatibles sin tocar el
   oráculo (que está fuera de mi zona). No hay que añadir ninguna correspondencia nueva.

3. **FD-3 · Claves de salida artificiales del arnés.** La decisión 4 pide construir sin las claves
   de salida artificiales (`sk_salida(id, dueño)`) que W03 introdujo para que dos coinbases o dos
   liberaciones idénticas no colisionaran en el `OutPoint`; F-15/F-16 las hacen innecesarias.
   **Lectura aplicada:** cada salida se bloquea con la clave real del dueño abstracto
   (`claves.id(dueño)`) y se firma con esa misma clave. Si al correr el diferencial persistiera
   alguna colisión de `OutPoint`, **paro** y lo informo (como ordena la decisión 4), en vez de
   reintroducir claves artificiales en silencio.

4. **FD-4 · Punto de comparación de F-17 en modo fusión.** La orden dice «`slot` de la v3 = slot del
   bloque». En `aplicar_fusion` el punto de aplicación puede ser el slot del bloque que **fusiona**,
   distinto del slot del bloque que **contiene** la v3. **Lectura aplicada:** F-17 compara el `slot`
   de la extensión con `bloque.hechos.slot()` (la cabecera que contiene la coinbase), no con
   `punto_aplicacion`; la madurez del crédito (`M_rec_slots`, RD-1) sigue usando el punto de
   aplicación. En cadena (`aplicar_con_undo`) ambos coinciden.

5. **FD-5 · El diferencial negativo no existe en W03.** La V4 de la orden exige comparar contra
   `vectores-transicion-v0.1.txt` **y** `…-negativos-v0.1.txt`, pero W03 solo dejó un
   `diferencial_t01` que lee el fichero base. **Lectura aplicada:** se amplía el mismo arnés para
   leer **ambos** ficheros v0.1 con el mismo parser y comparación, añadiendo a las correspondencias
   de §4 la única nueva (`ErrNonce ↔ ErrNonce`, decisión 4 de la orden). Los negativos no cambian el
   formato de línea.

6. **FD-6 · El oráculo de formato no modela F-16.** La decisión 2 actualiza el oráculo «a F-15/F-17»,
   no a F-16, y un oráculo de formato sin contexto no puede saber la altura del bloque. **Lectura
   aplicada:** el oráculo v0.1 mantiene `expiry = 0` en todos sus casos (incluida la coinbase v1) y
   añade `nonce` a la v2 y `slot` a la v3; F-16 se cubre en el motor y en el arnés (que construye la
   coinbase con `expiry_height = altura`). Por eso la igualdad v0↔v0.1 se exige solo en los casos
   **v1 no-coinbase**, tal y como pide la orden.

7. **FD-7 · Vectores negativos de T01-C que W03 nunca consumió.** La orden manda leer
   `…-negativos-v0.1.txt` con «las correspondencias de W03 más `ErrNonce`», pero W03 solo corrió el
   fichero base. Al correrlo aparecieron 93 discrepancias en 4 familias, que exigen **dos lecturas
   adicionales** (documentadas aquí antes de aplicarlas):
   - **`neg-autorizacion-deposito` (75 casos).** El vector es un depósito `ent=[]` (sin entradas) con
     `firmante ≠ clave`; el oráculo T01 comprueba la autorización **antes** de consumir entradas y
     da `ErrAutorizacion`, mientras que `validar_forma_tx` (F-07) lo rechaza antes con
     `DepositoSinEntradas` (`ErrForma`). **Lectura aplicada:** mantener la regla de forma (la orden
     pide `validar_forma_tx` «sin cambios» y hay un test previo que la fija) y añadir la
     correspondencia del diferencial `ErrForma(DepositoSinEntradas) → ErrAutorizacion`. Todos los
     vectores que alcanzan ese error combinan `ent=[]` con firmante distinto (comprobado: 75 de 75);
     el caso simétrico con firmante correcto e importe 0 lo captura antes `ImporteCero`.
   - **Salidas de `Liberacion` gastadas (`neg-saldo-transfer-crea-valor`,
     `neg-saldo-deposito-descuadra`, `neg-autorizacion-transfer`, 18 casos).** El oráculo asigna a la
     salida implícita de la liberación el id `prox_salida` (un contador que salta al mayor id
     explícito + 1); la F-18 la crea en `(txid, 0)`. El arnés de W03 no mapeaba esos ids porque el
     fichero base nunca gasta una salida de liberación. **Lectura aplicada:** el `Constructor` del
     arnés mantiene un contador espejo de `prox_salida` y registra el id abstracto → `(txid, 0)`, sin
     reintroducir claves artificiales. Verificado que la cadena base de esos casos es válida, así que
     el contador espejo coincide con el del oráculo.

   Con FD-1…FD-7, **todos** los vectores (`2055` base + `3939` negativos) dan **0 discrepancias**.

## Secuencia de trabajo

1. **Lectura y montaje.** Lectura íntegra de este archivo, `LINEO.md`, `FORMATO-v0.md` con la
   Corrección v0.1, `CONTRATO-v0.md` (v0.1), `CONTRATO-ESTADO-DAG-v0.md` (RD-1…RD-10), los informes
   de W02/W03/W03-R, el oráculo de formato v0, los vectores v0.1 y el oráculo T01-D. Comprobación de
   `ENTRADA-W02b.sha256` al empezar (**47/47 OK**, `exit=0`). Copia de
   `Cargo.toml Cargo.lock rust-toolchain.toml crates/ testdata/ ci/ .github/` a `ws.orig/` y `ws/`
   (idénticos), enlace `PDF`, `.cargo-home` (copia de `~/.cargo`) y `.julia-depot` en la zona.
2. **Oráculo v0.1.** `oraculo-formato-v0.1/` (copia del v0) con `nonce` en la v2 (F-15) y `slot` en
   la v3 (F-17) en el `TxSpec`, `campos_extra`, `txid` y el códec; casos con nonces `0,7,1,2,0xdead,
   3,4,5,6` y slots `0,0x2a`; tests ampliados (85 comprobaciones, verdes). Vectores regenerados
   (semilla `0x5a5a`), copiados a `ws/testdata/formato-v0.1/` con `PROCEDENCIA.md` y `sha256`.
3. **`zx-core`.** `ExtensionTx::Garantia` con `nonce: u64` y `ExtensionTx::CoinbasePost` con
   `slot: u64`; `extension_digest` (F-15/F-17) y códec (F-14) con los campos nuevos; `validar_forma_tx`
   exime del `expiry_height == 0` a las candidatas a coinbase PoW (FD-1). `formato_v0.rs` lee los
   vectores v0.1, comprueba los v1 no-coinbase contra los v0 y cubre nonce/slot.
4. **`zx-consensus`.** `Garantia::nonce_siguiente`; `ErrNonce`; comprobación F-15 al inicio de
   `aplicar_garantia` (todo tipo) con undo por delta; F-16 en `aplicar_coinbase_pow`; F-17 en
   `aplicar_coinbase_post` y en `fusion_post`; F-18 salida `(txid, 0)` y eliminación de `prox_salida`.
   Tests V5 nuevos (dos nonces consecutivos, repetición de retiro y liberación, descarte en fusión
   con `ErrNonce`, nonce antes que saldo, undo del nonce, F-16, F-17).
5. **Arnés diferencial v0.1.** Lee `vectores-transicion-v0.1.txt` y `…-negativos-v0.1.txt` (que se
   copian a `ws/testdata/transicion-v0.1/`); construye coinbases PoW con `expiry_height = altura`,
   coinbases PoST con el `slot` del bloque y garantías con el `nonce` del vector; sin claves de salida
   artificiales; traduce el id abstracto de la liberación a `(txid, 0)`; `GAR` con `nonce`.
6. **`zx-post`.** La coinbase v3 de `construir_bloque` lleva el `slot` de su cabecera; el test de
   extremo a extremo lo comprueba.
7. **Verificación.** `fmt --check` limpio; `clippy --workspace --all-targets --all-features --locked
   -- -D warnings` limpio; `cargo test --workspace --all-features --locked` (resultado en
   `INFORME.md`); diferencial `0` discrepancias en `2055 + 3939` casos.

## Resultado

- **V1** `fmt --check`: limpio.
- **V2** `clippy … -D warnings`: limpio.
- **V3** `cargo test --workspace --all-features --locked`: ver `INFORME.md` (recuento final).
- **V4** Diferencial v0.1: **0 discrepancias** en 2 055 casos base (1 947 con PoST) y **0** en 3 939
  negativos (2 024 `ErrNonce`).
- **V5** Tests propios F-15…F-18: ver `INFORME.md`.
- **V6** Oráculo de formato v0.1 (Julia): 85 comprobaciones verdes; vectores v1 no-coinbase idénticos a
  v0.
- **V7** `dependencias-exactas.sh`, `frontera-crates.sh` y lock: ver `INFORME.md`.

## Incidencia / nota de zona

Todo se escribió dentro de `deepseek/W02b/`. La única escritura fuera de `ws/` fue la copia del
`.cargo-home` y `.julia-depot`, dentro de la zona. No hubo commit ni push.

