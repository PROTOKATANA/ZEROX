# zx-storage

Almacenamiento de bloques, cabeceras y estado UTXO, con backend en memoria y backend de disco
RocksDB tras la feature `rocksdb`.

Contiene implementación y tests de atomicidad y recuperación. El orden y estado del DAG, el
árbol de commitments y el conjunto de nullifiers blindados siguen pendientes de integración.
Estado y contratos pendientes: [MIGRACION.md](../../MIGRACION.md).
