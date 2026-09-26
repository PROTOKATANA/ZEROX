# PROGRESO.md — ORDEN-W05a

Crate **nuevo** `crates/zx-dag`: GHOSTDAG, comprobación contextual de padres con D-P08, rango
validado, vista causal y la identidad de billete, con la raíz en el terminal PoW (D-P07).
Zona única: `/home/katana/zeo/ZEROX/deepseek/W05a/`.

## Entrada congelada — comprobación de INICIO (2026-09-26T01:58 +02:00)

`sha256sum -c P-ZRX/P-DAG/ENTRADA-W05a.sha256` desde la raíz; coinciden las 4 huellas
(`logs/entrada-inicio.log`):

```
P-ZRX/P-DAG/ORDEN-W05a.md: La suma coincide
P-ZRX/P-DAG/DECISIONES-W05.md: La suma coincide
P-ZRX/PLAN-0.0.1.md: La suma coincide
V-ZRX/LINEO.md: La suma coincide
exit=0
```

`LINEO.md` se leyó íntegro antes de escribir código. Como Veritas es Julia/C++ y esta orden es Rust
de consenso, sus reglas aplicables se traducen así: oráculos **consumidos como vectores** (no
recomputados), determinismo explícito en los tests, aritmética entera comprobada (`checked_*`, sin
floats), nada de `unsafe`, y presupuesto declarado (2 h, 8 hilos, 16 GiB, 20 GiB).

## Falta de definición detectada e informada antes de editar

**Ninguna impide cumplir la orden tal cual.** Se declaran tres interpretaciones, aplicadas sin
improvisar lógica nueva:

1. **Orden de las comprobaciones de D-P08** (§3.4): `0` padres → `CabeceraPostSinPadres`;
   `seleccionado == T` con `count != 1` → `TerminalConPadresExtra`; algún extra `== T` →
   `TerminalComoPadreExtra`; después, padre no terminal ni validado → `PadreNoValidado`; y el resto
   (slot, anticadena, `prev_hash == sp`) sin cambios. Cuando un mismo bloque podría incumplir dos
   reglas, gana el orden en que la orden las enumera; queda fijado con tests.
2. **`genesis` → `terminal`.** El campo y el accesor internos de `AlmacenGhostdag` y el método
   `ContextoDag::es_genesis` pasan a `terminal`/`es_terminal`; **no** cambia ni un paso del coloreo
   GHOSTDAG. El `#[must_use] genesis()` público se renombra a `terminal()`.
3. **`bloque_dag.rs` entero.** Se porta también `comprobar_compromisos_cuerpo_dag` (solo necesita
   `zx-core`). El único test de ese módulo que no aplica es
   `un_testigo_invalido_puede_coincidir_con_el_compromiso`, que usa `zx_consensus::testigo`
   (W05b/W03): se retira declarándolo en el informe, junto con el test del adaptador de almacén.

## Secuencia de trabajo

1. **01:56–01:58 · Lectura y montaje.** Lectura íntegra de `ORDEN-W05a.md`, `V-ZRX/LINEO.md`,
   `DECISIONES-W05.md`, `CONTRATO-v0.md` §0/TRN-06 y `PLAN-0.0.1.md`; comprobación de la entrada;
   extracción del código antiguo de `9681061` a `ref/`. Copia del workspace raíz a `ws.orig/` y
   `ws/`; copia de `.cargo-home` de W04 (697 MiB).
2. **01:58–02:02 · Crate `zx-dag`.** `Cargo.toml`, `README.md`, `lib.rs`, `error.rs` (`ErrorDag`),
   `identidad.rs` (con `identidad_de_cabecera`), `bloque_dag.rs` (D-P08), `ghostdag.rs`
   (`con_raiz_terminal`, `es_terminal`, lógica idéntica) y `dag_causal.rs` (sin
   `FuenteIndiceAdmitidos`).
3. **02:02 · Vectores.** `testdata/ghostdag-rank-v1/{corpus-rust.txt,kaspa-rust.txt}` copiados sin
   cambios desde `9681061`, con `PROCEDENCIA.md` (origen, commit, sha256, instrumento, «no
   re-validado en el árbol nuevo»); rutas del test solo cambiadas de segmento.
4. **02:02–02:03 · Tests.** Portados `ghostdag_rust.rs`, `ghostdag_prop.rs`, `ghostdag_bench.rs`,
   `ghostdag_oraculo.rs`, `dag_causal.rs`; nuevos `padres_dp08.rs` (V6) y las pruebas de
   `con_raiz_terminal` (D-P07). Primer clippy: una `expect` de lint sin cumplir en `padres_dp08.rs`;
   corregida (se eliminó la expectativa sobrante).
5. **02:03–02:07 · V1–V7.** `fmt` y `clippy -D warnings` limpios; `cargo test` **371 pasan, 0
   fallan, 1 ignorado**; los **265** nombres previos siguen (0 ausentes); oráculos GDR-v0.2 (28
   DAGs) y rusty-kaspa (180 comprobaciones) coinciden; `ci/dependencias-exactas.sh` (10) y
   `ci/frontera-crates.sh` (`zx-consensus` y `zx-dag` → `{zx-core}`) OK.
6. **02:06–02:07 · Banco y entregables.** Banco release (ignorado) ejecutado; `cambios.patch` (21
   ficheros), `MIGRACION.sha256` (87 huellas, `sha256sum -c` OK),
   `logs/lock-subconjunto.txt` (única adición `zx-dag 0.0.0`).

## Resultado

- V1 `fmt` OK; V2 `clippy -D warnings` 0 avisos; V3 371/0/1 (107 nombres nuevos, 265 previos
  intactos); V4 oráculos exactos; V5 tabla de portados/sustituidos/retirados en `logs/V5-tests.txt`
  (ningún test de lógica GHOSTDAG retirado); V6 seis casos D-P08 con su resultado; V7 OK.
- `zx-dag` es la **única** adición al `Cargo.lock`; ninguna versión existente cambia.
- Veredicto: **SUPERADO**.
