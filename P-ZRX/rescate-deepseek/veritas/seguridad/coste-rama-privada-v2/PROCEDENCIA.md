# CRP-v0.2 · Procedencia

## 1 · Entrada congelada

| Archivo | SHA-256 | Nota |
|---|---|---|
| `deepseek/ENCARGO-07v2-coste-rama-privada.md` | `a8912ba5d8d48ae71685b3ea471d7166df74bebc4f17bd609c4182c1e8795c45` | encargo |
| `deepseek/ENCARGO-07v2-coste-rama-privada.sha256` | `bd3ed51a9c0478aade54e1b3ada5a529644ce155ffa29a1fd76f27c91b27fa32` | sidecar (huella del archivo de huellas) |
| `ENTRADA.md` (copia) | `a8912ba5d8d48ae71685b3ea471d7166df74bebc4f17bd609c4182c1e8795c45` | copia byte a byte; coincide con el original |
| `ENCARGO.sha256` (copia del sidecar) | `bd3ed51a9c0478aade54e1b3ada5a529644ce155ffa29a1fd76f27c91b27fa32` | copia |

`sha256sum -c deepseek/ENCARGO-07v2-coste-rama-privada.sha256` desde la raíz del repositorio:
**OK** (la suma coincide). La entrada no cambió durante la ejecución.

## 2 · Fuentes leídas íntegras o por secciones citadas

| Fuente | Uso |
|---|---|
| `AGENTS.md`, `README.md`, `MIGRACION.md`, `research/README.md`, `veritas/LINEO.md` | método y jerarquía |
| `SPEC.md` §6.1–§7.3, §11 y §§ de finalidad/red/sincronización | texto vigente y reglas pendientes |
| `TAREAS.md` §2.1–§2.4, §2.7–§2.8, §3.1 y §4.1 | estado de integración y pendientes |
| `research/dag-poas-ancla-de-orden.md` (R-FIN-1a, 2–5, 11, 13′, 14; §2) | reglas candidatas |
| `veritas/consenso/ghostdag-rank-v1/` (GDR-v0.2) | oráculo GHOSTDAG reutilizado |
| `veritas/consenso/retarget-causal-endogeno-v1/CONTRATO.md` | núcleo entero RCE rev2 |
| `veritas/consenso/admision-retarget-multivista-v1/CONTRATO.md` | vectores ARM y pendientes |
| `veritas/finalidad/delta-medido-v1/`, `research/coste-ploteo-medido.md` | Δ y coste (contexto) |
| `crates/zx-consensus/src/ghostdag.rs`, `bloque_dag.rs`, `fork_choice.rs` | Rust aislado vs ruta activa |
| `crates/zx-core/src/wire_dag.rs`, `crates/zx-node/src/cadena.rs`, `crates/zx-p2p/src/rele_compacto.rs` | estado de integración |
| `ci/reglas-sin-cablear.txt`, `ci/reglas-sin-codigo.txt`, `ci/consenso-pendiente.txt` | inventario normativo |
| `deepseek/veritas/seguridad/coste-rama-privada-v1/` | baseline CRP-v0.1 |

## 3 · Cronología de la ejecución

| Fecha (UTC) | Paso |
|---|---|
| 2026-09-18 | verificación de huella; copia a `ENTRADA.md`; lectura de fuentes |
| 2026-09-18 | creación de `MATRIZ-AUTORIDAD.md`, `MODELO.md`, `METODO.md` |
| 2026-09-18 | implementación de `src/` (referencia exacta, DP acotada, RCE, R-FIN-5, GDR wrapper, simulador DAG) |
| 2026-09-18 | `test/runtests.jl` (128/128 en verde), `run.jl`, `bench/` |
| 2026-09-18 | revisiones en contexto independiente; `INFORME.md`; `HUELLAS.sha256` |

## 4 · Trazabilidad de los resultados

Cada artefacto de `resultados/` registra Julia 1.13.0, `Sys.CPU_NAME`, hilos y semilla
(`ENTORNO.txt`). La semilla por defecto es `0x5a5a`; `resultados/TESTS.txt` reproduce la suite.
Los benchmarks de I/O son de solo lectura y de page cache caliente (`resultados/IO.txt`); no se
ejecutó `drop_caches` ni se escribió en dispositivos raw.
