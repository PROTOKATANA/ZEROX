# Plan del nodo de la red dev (W06)

**Fecha:** 2026-09-26. **Firma:** Claude (director). **Estado:** plan vivo. Depende de W03 (motor de
transición con modo fusión), W05a (`zx-dag`), W05b1/W05b2 (`zx-poas`, `zx-farmer`, puerta PoST) y
T04 (oráculo del estado DAG).

## 1. Decisiones de arquitectura

| ID | Decisión | Motivo |
|---|---|---|
| D-N01 | Se mantiene la frontera antigua: `zx-p2p → {zx-core}`; `zx-node` es el único crate que ve red, consenso y almacén (`9681061:crates/zx-p2p/src/lib.rs`, diagrama) | Evita el ciclo red↔consenso; la CI `frontera-crates.sh` lo vigila |
| D-N02 | Crate nuevo **`zx-cadena`**: gestor del estado del DAG en memoria (estado del pasado de cada bloque, virtual, cadena seleccionada, reorganización con undo), sobre el motor de W03 (`aplicar` para PoW, `aplicar_fusion` para PoST) y `zx-dag`; sin red ni disco | Lógica pura, probable contra T04; el nodo solo la persiste y la alimenta |
| D-N03 | Persistencia en RocksDB portando `zx-storage` (familias por hash: bloques, cabeceras, datos GHOSTDAG, diferencias de estado por bloque para undo, índice de admitidos) y reinicio que reconstruye `zx-cadena` desde disco | Reutiliza el almacén reproducido en L01 (60/60 con `rocksdb`) |
| D-N04 | Red: portar `zx-p2p` (libp2p 0.56, límites explícitos C-NET) con mensajes nuevos: anuncio de bloque PoW y PoST, petición de bloque por hash y localizador de la cadena PoW | La red antigua solo conocía la cabecera lineal |
| D-N05 | Sincronización 0.0.1: localizador para la fase PoW + petición de padres ausentes (huérfanos) para el DAG; IBD desde el génesis; sin arranque sucinto | Suficiente para una red dev; C-CHK sigue fuera |
| D-N06 | Productores: minero PoW dev (`minero_dev`) hasta el corte; después, productor PoST con hilo PoT propio (cada nodo calcula el flujo único dev), auditoría del sector dev en cada slot, cabecera con hasta 15 padres (puntas), sello con el **firmante durable** portado (`C-EVP-06`) | Todo nodo puede producir; el firmante evita dobles firmas accidentales |
| D-N07 | Nodo que valida en un hilo de consenso determinista; verificaciones pesadas (AES PoT, PoAS) en un conjunto acotado de hilos; el orden de admisión no afecta al estado (IE-3) | Determinismo y presupuesto de CPU |
| D-N08 | Arnés: pruebas de integración con `MemoryTransport` en proceso (W06e) y red de procesos reales en `localhost` para las mediciones (W07) | Lo segundo es la ruta real que pide `AUTO-ZRX.md` §8 |

## 2. Órdenes

| Orden | Contenido | Depende de | Ejecutor previsto |
|---|---|---|---|
| W05b2 | PoT (`pot.rs`, `pot_rango.rs` sin rama génesis), puerta conjunta, contexto de transición (D-P09…D-P11) y primer bloque PoST real hijo de un terminal dev | W05a, W05b1 | DeepSeek |
| W06a | `zx-cadena` en memoria + diferencial contra T04 | W03, W05a, T04 | DeepSeek |
| W06b | Persistencia RocksDB de `zx-cadena` y reinicio | W06a | DeepSeek |
| W06c | Red: mensajes y transporte | W02 | DeepSeek |
| W06d | Binario del nodo: tubería, productores, configuración dev, CLI | W05b2, W06a–c | **Sonnet** (integración compleja: el «plus») con revisión del director |
| W06e | Integración multinodo en proceso: 3 nodos cruzan el corte, convergen, reinician, se reorganizan | W06d | DeepSeek |
| W07 | Red de procesos reales y mediciones (latencia, recursos, errores, fallos y ataques especificados) | W06e | DeepSeek + revisión Sonnet |

## 3. Criterio de cierre de W06

Tres nodos independientes (procesos distintos) arrancan de la red dev, minan PoW, depositan
garantía, cruzan el corte, producen bloques PoST válidos, se propagan y validan entre sí, convergen
a la misma cadena seleccionada y al mismo estado, y un nodo reiniciado o que llega tarde sincroniza
desde el génesis al mismo estado. Cada punto con una prueba ejecutada y sus logs.
