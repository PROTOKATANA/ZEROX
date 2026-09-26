# Procedencia — `vectores-estado-dag-v0.3`

Artefactos **copiados sin cambios** desde el oráculo T04-D
(`P-ZRX/P-DAG/T04/resultados/`; `REVISION-T04-D.md`, corrección F-18: la salida de una liberación
es `ID_LIB(clave, nonce, importe)` y se elimina la colisión de ids del generador v0.2).

| Fichero | sha256 |
|---|---|
| `vectores-estado-dag-v0.3.txt` | `016ad975cddea854349ef57241acbeb2f6b84f45d1035c765f245d54c9c748e1` |
| `cobertura-v0.3.txt` | `3d4aeb7226a0ce4567b08826df8afa43ee6f3ad90d036dc511b5e80533bcdf1c` |

Ambas huellas coinciden con las fijadas en `P-ZRX/P-NODO/ENTRADA-W06a-B.sha256` y se
reverificaron con `sha256sum` al migrarlas.

`vectores-estado-dag-v0.3.txt` (914 casos: D-1…D-14 + 900 `aleatorio`) es la especificación
ejecutable de `crates/zx-cadena/tests/diferencial_t04.rs`; `cobertura-v0.3.txt` es la tabla de
cobertura de T04-D, de la que el arnés compara la sección `vectores-v0.3 (casos aleatorios)`.
El apartado `run.jl` de `cobertura-v0.3.txt` es evidencia de T04-D y no es exigible al arnés.
Los vectores v0.2 se conservan sin tocar en `testdata/estado-dag-v0.2/`.
