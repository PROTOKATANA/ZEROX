# Corrección C3 · documentación del bootstrap tras F4

**Ejecutor:** DeepSeek Harness `deepseek-v4.1-flash`, esfuerzo `high`.

La revisión del líder halló texto obsoleto en `crates/zx-node/src/bootstrap_dag_dev.rs`: la sección «Qué NO hace» dice que `zx-dag-dev` no acepta `--peer` ni abre sockets. Desde el commit F4 `4ab7064`, el binario sí acepta `--listen`/`--peer` y monta P2P loopback optativo **después** del bootstrap, aunque sin PoST ni difusión de bloques. La afirmación de que *este módulo* no opera la red sigue siendo correcta; la frase sobre el binario ya es falsa.

Modifica **solo los comentarios/documentación** de `crates/zx-node/src/bootstrap_dag_dev.rs` que hayan quedado obsoletos por F4. Di con precisión: sin flags, el bin comprueba bootstrap y sale sin sockets; con `--listen`/`--peer`, abre saludo P2P loopback separado del bootstrap; `--red`/`--datos` no existen; no hay admisión PoST, producción, persistencia ni propagación de bloques. No cambies código, constantes, hash, tests, otras rutas ni documentos. No commit ni push. Ejecuta formato, test de bootstrap y diff check. Informa la frase corregida.
