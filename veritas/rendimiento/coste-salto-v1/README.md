# coste-salto — banco en hardware del coste por salto (Q4)

Mide el coste de CPU de la validación antes de reenviar (TAREAS.md §3.1, Q4;
C-NET-12, C-NET-06): cabecera, prueba de espacio, 2 KZG, sello, justificación
PoT contra caché y compromiso Merkle, más el PoT por slot en sus cuatro rutas
(G). Contexto PoAS **sintético** (el mismo que `prototipos/poas-identidad`),
primitivas reales y sin modificar.

## Qué se mide (solo verificación, nunca construcción)

| Op | Qué es |
|---|---|
| A | `verify_solution::<ChiaTable, _>` con `piece_check_params` (PoS K=20 + rango + KZG de chunk y de record + límites de pieza) |
| B-pos | Prueba de espacio sola, `ChiaTable` K=20 (`SolutionPotVerifier::is_proof_valid`) |
| B-kzg | `Kzg::verify` una vez (testigo de chunk, `num_values = Record::NUM_S_BUCKETS` = 65 536, índice = audit_bucket) |
| C | `zx_core::firma::verificar` (Ed25519 ZIP-215, `ed25519-zebra = 4.2.0`) sobre la prefirma de 492 B |
| D-92 | `zx_core::preimage::block::BlockHeader::block_hash` sobre la cabecera implementada (92 B) |
| D-556 | Réplica de `H_d` (`sha3 = 0.12.0`, la misma versión que zx-core) sobre la base PoAS de 556 B (C-HDR-01) |
| E-571 / E-4464 | `zx_core::preimage::block::merkle_root` con 571 y 4 464 txids deterministas (bloque de arranque y techo de Q1) |
| F-1 / F-150 | Comparación de la justificación PoT contra la caché de slots (Q4 salvaguarda 1): 128 B por slot, 1 slot y 150 slots (S_max) |
| G-* | `pot_estable::verify_con_ruta` (pot-estable-rutas) con 200 032 000 iteraciones y 8 checkpoints, rutas forzadas: `avx512f_vaes`, `avx2_vaes`, `aes_sse41`, `crate-aes` (Corrección 1: NO es software, ver «Corrección 1» abajo), `aes-soft` (software real, binario aparte) |
| B-kzg-hist | `Kzg::verify` con los parámetros del banco histórico (`subspace-kzg/benches/kzg.rs`): `num_values = RawRecord::NUM_CHUNKS`, índice 0. Valores con `ChaCha8Rng::seed_from_u64(0)` (el histórico usa `rand::random()`, no determinista) |
| H-571 / H-4464 | `wire::tx_desde_bytes` + `preimage::tx::txid` sobre 571/4 464 transacciones sintéticas de 348 B (Modelo B350, TAREAS.md §3.1 Q1: 2 entradas, 3 salidas P2K, 2 testigos de 64 B) |
| H-txid-571 / H-txid-4464 | Solo `preimage::tx::txid`, sobre transacciones YA decodificadas (decodificar no se cronometra) |

## Corrección 1 (2026-09-14)

Una validación posterior encontró 5 problemas reales en la primera versión del banco
(ver `BITACORA.md` §«Corrección 1» para el detalle completo):

1. **La ruta «genérica» no es AES por software.** El crate `aes` 0.9.3 autodetecta
   AES-NI en tiempo de ejecución (`aes-0.9.3/src/lib.rs:36-46`) y la usa si la CPU la
   tiene — en este Zen 5, la usa. Los ~925-944 ms/slot de esa ruta son AES-NI con la
   implementación del crate `aes`, no software. Renombrada a `G-pot-crate-aes`. Para
   software real hace falta compilar con `--cfg aes_backend="soft"` (operación
   `G-pot-aes-soft`, binario `target-soft/`, ~8,3 s/slot).
2. **La explicación anterior del hueco de KZG (num_values/índice) no se sostenía.**
   `Kzg::verify` cachea las FFT settings y su coste real es `check_proof_single`
   (`subspace-kzg/src/lib.rs:788-816`), que no depende de `num_values` ni del índice.
   Medido con los parámetros exactos del histórico (`B-kzg-hist`): el resultado es
   prácticamente idéntico a `B-kzg` (~583-586 µs en las cuatro configuraciones de la
   matriz, ver `resultados/RESUMEN.md` §6) — **ninguno de los candidatos probados
   (`parallel`, `opt-level="s"`) explica los 1,0773 ms históricos.**
3. Los lotes 1 y 2 de la primera versión se ejecutaron seguidos (ambos ~19:25), no en
   momentos distintos. Esta versión los separa ≥30 min (`REGISTRO.log`).
4. `RESUMEN.md` §1 omitía B-pos, B-kzg y D-92. Corregido: §1 lista TODAS las
   operaciones.
5. El coste por salto de Q4 no incluía calcular los txid antes de la raíz Merkle
   (operaciones H nuevas, dos escenarios en RESUMEN.md §2: relé compacto y cuerpo
   completo).

## Controles (CONTROLES.txt)

Cada operación se mide solo después de que su control positivo dé el resultado
esperado y su control negativo falle con el error concreto. Se ejecutan antes
de cada lote, no cronometrados.

## Harness y estadísticos

Harness propio con `std::time::Instant` (motivo: los entregables exigen
muestras crudas en CSV y medianas reproducibles entre lotes, que Criterion no
exporta; su metodología sigue la alternativa que pide el encargo). Por
operación: calentamiento (mín. 3 llamadas o ~0,5–1,5 s) y ≥30 muestras (≥10
para la ruta genérica del PoT). Publicados: mediana, p10, p90, mínimo y
coeficiente de variación. Criterion 0.8.2 (`default-features = false`)
sí resuelve offline; se usa solo en `benches/ancla.rs` para contrastar con el
ancla de 96,1 ms con el mismo instrumento y semilla que el original.

## Reproducción

Todo offline. Desde `veritas/rendimiento/coste-salto-v1/`, con el toolchain de la
raíz (nightly-2026-05-03, heredado). Cinco compilaciones, cada una con su
`CARGO_TARGET_DIR` (los `target*` no se versionan):

```sh
# 1) base — todas las operaciones A-H, incluida B-kzg-hist y las 4 rutas G de hardware
CARGO_TARGET_DIR=$PWD/target cargo build --release --offline --locked -j 12

# 2) AES software real, SOLO para G-pot-aes-soft (--cfg propaga a todo el binario:
#    no publicar ninguna otra operación de esta compilación, ver Corrección 1 §1)
RUSTFLAGS='--cfg aes_backend="soft"' \
  CARGO_TARGET_DIR=$PWD/target-soft cargo build --release --offline --locked -j 12

# 3) matriz KZG — parallel (Cargo.lock crece con crossbeam-*/rayon*/num_cpus/
#    threadpool; --locked FALLA la primera vez, se resuelve una vez sin --locked,
#    offline, y se fija: ver resultados/DIFF-cargo-lock-parallel.txt)
CARGO_TARGET_DIR=$PWD/target-kzg-parallel cargo build --release --offline --locked \
  --features kzg-parallel -j 12

# 4) matriz KZG — opt-level="s" en rust-kzg-blst y rayon-core (perfil del workspace
#    de Autonomys, Cargo.toml:385-387, que esta zona aislada no hereda por defecto)
CARGO_TARGET_DIR=$PWD/target-kzg-opt-s cargo build --release --offline --locked -j 12 \
  --config 'profile.release.package.rust-kzg-blst.opt-level="s"' \
  --config 'profile.release.package.rayon-core.opt-level="s"'

# 5) matriz KZG — parallel + opt-s a la vez
CARGO_TARGET_DIR=$PWD/target-kzg-ambas cargo build --release --offline --locked \
  --features kzg-parallel -j 12 \
  --config 'profile.release.package.rust-kzg-blst.opt-level="s"' \
  --config 'profile.release.package.rayon-core.opt-level="s"'

# medir (un hilo fijado a un núcleo, sin otra carga en la máquina), lote 1:
taskset -c 8 ./target/release/coste-salto lote --lote 1 --csv resultados/MEDICIONES.csv
taskset -c 8 ./target-soft/release/coste-salto lote --lote 1 --solo G --csv resultados/MEDICIONES.csv
taskset -c 8 ./target-kzg-parallel/release/coste-salto lote --lote 1 --solo B --csv resultados/kzg-parallel.csv
taskset -c 8 ./target-kzg-opt-s/release/coste-salto lote --lote 1 --solo B --csv resultados/kzg-opt-s.csv
taskset -c 8 ./target-kzg-ambas/release/coste-salto lote --lote 1 --solo B --csv resultados/kzg-ambas.csv

# lote 2, ≥30 minutos después, mismos comandos con --lote 2

# comparación de medianas entre lotes (debe quedar dentro del 5 %), por cada CSV:
./target/release/coste-salto comparar --csv resultados/MEDICIONES.csv
./target/release/coste-salto comparar --csv resultados/kzg-parallel.csv   # y opt-s, ambas

# contraste del ancla con Criterion (misma semilla ChaCha8Rng por defecto que
# subspace @ f8842d0 benches/pot.rs) — no repetido en Corrección 1, sigue válido
CARGO_TARGET_DIR=$PWD/target cargo bench --offline --bench ancla
```

Anotar `cat /proc/loadavg` antes y después de cada lote. Durante la ejecución en
`deepseek/`, cada lote se protegió además con un candado con PID (`deepseek/MIDIENDO`) frente a
la sesión que migraba GDR a la vez; fuera de esa convivencia no hace falta.

## Salidas

- `resultados/MEDICIONES.csv`: todas las muestras del binario base y del soft
  (`operacion,detalle,lote,muestra,ns`).
- `resultados/kzg-parallel.csv`, `kzg-opt-s.csv`, `kzg-ambas.csv`: B-pos/B-kzg/
  B-kzg-hist de cada compilación de la matriz (la config «base» está en
  MEDICIONES.csv).
- `resultados/RESUMEN.md`: tablas derivadas de la sección 4 del encargo.
- `INFORME.md`: las 5 preguntas de `veritas/LINEO.md`.
- `BITACORA.md`: orden de trabajo, incidencias y la validación y migración.
- `HUELLAS.sha256`: huella del instrumento y de sus fuentes (`sha256sum -c` desde la raíz).
- `resultados/CONTROLES.txt`: controles positivo/negativo.
- `resultados/ENTORNO.txt`: hardware, toolchain, perfil y protocolo.
- `resultados/DIFF-cargo-lock-parallel.txt`: diff del `Cargo.lock` al añadir
  `kzg-parallel` (solo entradas nuevas).
- `resultados/v1-lotes-seguidos/`: CSV y salidas de la primera versión del
  banco (lotes ejecutados seguidos, sin separación temporal), conservados sin
  modificar.

## Migración (2026-09-14)

Desde `deepseek/prototipos/coste-salto/` y `deepseek/prototipos/pot-estable-rutas/`:

- `veritas/rendimiento/coste-salto-v1/` tiene la misma profundidad que la ruta de origen, así que
  las dependencias `../../../PDF/autonomys-subspace/...` y `../../../crates/zx-core` no cambian.
- `pot-estable-rutas/` vive dentro del instrumento: `Cargo.toml` apunta a `path = "pot-estable-rutas"`
  y lo excluye del workspace (`exclude`), porque tiene su propio `[workspace]`. `Cargo.lock` no
  cambia; compila con `--offline --locked` y los tests de `pot-estable-rutas` pasan.
- `INFORME.md` sube de `resultados/` a la raíz (estructura de LINEO §1) y `PROGRESO-BANCO.md` pasa a
  `BITACORA.md`.
- `--ocupado` sigue siendo opcional; sin él, el binario no comprueba ningún candado.
- `resultados/ENTORNO.txt`, las salidas de los lotes y `BITACORA.md` conservan las rutas de
  `deepseek/` con las que se midió.

## Límites declarados

- Contexto PoAS sintético; no es una historia ZEROX/Archiver acreditada
  (mismo límite que poas-identidad).
- Las rutas sin AVX-512 se midieron FORZADAS en un Zen 5; no equivalen al coste
  en una CPU antigua (otra microarquitectura).
- `G-pot-crate-aes` usa el crate `aes 0.9.3`, que autodetecta AES-NI en tiempo
  de ejecución y la usa en esta CPU: NO es AES por software (Corrección 1 §1).
  `G-pot-aes-soft` es la medición de software real, con `--cfg aes_backend="soft"`
  forzado en TODO el binario (no solo en el crate `aes`): en esa compilación,
  `aes_sse41` (que no pasa por el crate `aes`) se ralentiza ~50 % sin
  explicación encontrada, por eso ese binario NO publica ninguna otra
  operación.
- La matriz KZG (`parallel` / `opt-level="s"` / ambas) no reproduce los
  1,0773 ms históricos: las cuatro configuraciones caen en la misma banda de
  ~583-586 µs. Ninguno de los dos candidatos probados explica la diferencia;
  queda sin explicar (RESUMEN.md §6).
- `F-1` mide 1 ns (cuantización de `as_nanos` con lote de 10 000 comparaciones
  dividido): es el orden de una `memcmp` de 128 B, no una cifra de alta
  resolución.
