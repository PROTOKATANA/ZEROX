# Procedencia — `vectores-estado-dag-v0.2`

Artefactos **copiados sin cambios** desde el oráculo T04-C (`ORDEN-T04-C`, entrega
`/home/katana/zeo/ZEROX/P-ZRX/P-DAG/T04/resultados/`):

| Fichero | sha256 | Origen |
|---|---|---|
| `vectores-estado-dag-v0.2.txt` | `ee783b524c7fcac929fdd3859803205e046c3bab678efed69c5e603d2a94dd73` | `T04/resultados/vectores-estado-dag-v0.2.txt` |
| `vectores-estado-dag-v0.2.sha256` | — | `T04/resultados/vectores-estado-dag-v0.2.sha256` |
| `cobertura-v0.2.txt` | `952787e60de17fa7a037d3fa759173c615ccd6c8c1a5eaa5867a00db6c06212f` | `T04/resultados/cobertura-v0.2.txt` |

`ENTRADA-W06a.sha256` fija las huellas de los dos primeros (`vectores-estado-dag-v0.2.txt` y
`cobertura-v0.2.txt`); la copia se verificó en la comprobación de inicio (23/23).

No se re-validaron en el árbol nuevo: son la **fuente del diferencial** de `zx-cadena`
(`ORDEN-W06a` §4). El arnés `crates/zx-cadena/tests/diferencial_t04.rs` los lee como
especificación ejecutable del estado DAG.
