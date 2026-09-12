# zx-p2p

Transporte libp2p, descubrimiento, gossip, codificación y límites de recursos.

Contiene implementación y tests. La red transporta datos; la validación y el estado se coordinan
en `zx-node`. El relay y la sincronización necesitan adaptarse a la cabecera y dependencias DAG.
Estado y contratos pendientes: [MIGRACION.md](../../MIGRACION.md).
