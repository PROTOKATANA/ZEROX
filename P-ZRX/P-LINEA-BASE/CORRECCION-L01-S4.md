# CORRECCIÓN-L01-S4 — completar la línea base de `zx-consensus` y del almacén en disco

**ID:** L01-C1. **Fecha:** 2026-09-26. **Director:** Claude. **Ejecutor:** DeepSeek (misma zona y
mismas reglas que `ORDEN-L01.md`, que sigue vigente en todo lo que aquí no se cambia).

## Qué falló y de quién es el error

La entrega de L01 (`deepseek/L01/INFORME.md`) marcó S4 como **FALLA** con
`error: couldn't read 'crates/zx-consensus/tests/../../../SPEC.md'` (`tests/spec_numeros.rs:48`,
`include_str!`). **El error es de la orden**, no del código ni del ejecutor: §4 de `ORDEN-L01.md`
no extraía `SPEC.md`. El director comprobó que es el **único** archivo fuera de la extracción que
incluyen los tests del workspace (`grep` de `include_str!`/`include_bytes!` en `crates/` y
`prototipos/` del archivo, 2026-09-26). Tu decisión de no añadirlo por tu cuenta fue correcta.

Segundo defecto de la orden: §6 atribuía a S3 el almacén diferencial y `matar_a_mitad`, que están
tras `#![cfg(feature = "rocksdb")]`; con la preparación dada compilan a nada (tu informe lo
señaló). Se añade S3b.

## Qué cambia (solo esto)

1. **Extracción adicional**, desde `/home/katana/zeo/ZEROX/deepseek/L01/`:

       git -C /home/katana/zeo/ZEROX archive 9681061 SPEC.md | tar -x -C checkout
       sha256sum checkout/SPEC.md     # debe ser b59905c5f1900076e699f762f3f6604f282790fa5a7ed97527d22d21f9d4e0ae

   Después **regenera** `MANIFIESTO-CHECKOUT.sha256` con el mismo comando de `ORDEN-L01.md` §4 y
   guarda el anterior como `MANIFIESTO-CHECKOUT.antes-C1.sha256`; el único cambio permitido entre
   ambos es la línea de `./SPEC.md`. Compruébalo con `diff` y guarda la salida.
2. **Pasos nuevos**, con las mismas variables de entorno de L01 (`CARGO_HOME`, `CARGO_TARGET_DIR`,
   `CARGO_BUILD_JOBS=16`, `RUST_TEST_THREADS=16`, `RUSTFLAGS` vacío), desde `checkout/`:

   | Paso | Comando | Qué verifica |
   |---|---|---|
   | S4 | `cargo test --locked -p zx-consensus` | Todo el crate (GHOSTDAG + oráculos, PoAS real, PoT, firmante, emisión, LWMA, fork choice, génesis, `spec_numeros`) |
   | S3b | `cargo test --locked -p zx-storage --features rocksdb` | Almacén RocksDB, diferencial y `matar_a_mitad` (lanza subprocesos y los mata) |

   S3b necesita `libclang` para `bindgen` (en esta máquina existe `/usr/lib64/libclang.so.21.1.8`).
   Si falla por entorno, márcalo **BLOQUEADO** con el error literal; no instales nada.
3. Añade las filas a `RESULTADOS.tsv` (no borres las anteriores; marca la fila S4 antigua como
   «sustituida por C1») y una sección «Corrección C1» al final de `INFORME.md` y `PROGRESO.md`.
4. Repite al **final**, después del último paso, la integridad del checkout, `git status
   --porcelain` del clon y `LC_ALL=C sha256sum -c P-ZRX/P-LINEA-BASE/ENTRADA-C1.sha256` (desde
   `/home/katana/zeo/ZEROX`). En L01 la comprobación final de `ENTRADA` se hizo antes de terminar
   S5: esta vez hazla la última.

Conteo de referencia para S4: 422 `#[test]` con 4 `#[ignore]` reales (tu corrección del grep es
correcta). Explica cualquier diferencia.

Todo lo demás de `ORDEN-L01.md` rige igual: sin parches, sin `cargo update`, sin `--ignored`, sin
Python, sin escribir fuera de `deepseek/L01/`, sin commit ni push, sin leer secretos. Presupuesto
de esta corrección: 1 h de reloj, 16 hilos, 48 GiB de RAM.

## Lanzamiento

    cd /home/katana/zeo/ZEROX/deepseek/L01 && \
    ( set -a; . /home/katana/torio/deepseek-harness/.env >/dev/null 2>&1; set +a; \
      node /home/katana/torio/deepseek-harness/apps/cli/lib/bin.js --profile headless \
      "Corrección L01-C1. Lee íntegros /home/katana/zeo/ZEROX/P-ZRX/P-LINEA-BASE/CORRECCION-L01-S4.md y /home/katana/zeo/ZEROX/P-ZRX/P-LINEA-BASE/ORDEN-L01.md, y /home/katana/zeo/ZEROX/V-ZRX/LINEO.md. Cumple la corrección. Si detectas una falta de definición, infórmala antes de actuar." \
      > ../L01-C1-dsh.stdout 2> ../L01-C1-dsh.stderr )
