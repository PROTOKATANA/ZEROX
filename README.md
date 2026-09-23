# ZEROX

ZEROX desarrolla una red **PoSpace-Time + DAG**, con transacciones transparentes y una capa
blindada prevista sobre Orchard/Halo2. El recurso de consenso es almacenamiento archival
(PoAS, familia Autonomys) acompañado de Proof of Time. Cortex consume la red como aplicación.

El proyecto está en migración. El repositorio conserva componentes reutilizables y un prototipo
PoT; **todavía no contiene un nodo PoST + DAG completo**. La limpieza documental no cambia esa
situación ni certifica el consenso propuesto.

## Documentos de entrada

- [Continuidad de trabajo](CONTINUIDAD.md): punto de reanudación, hallazgos, evidencia guardada y siguiente fase propuesta.
- [ZEROX en números](ZEROX-EN-NUMEROS.md): métricas contrastadas, hipótesis y pendientes vigentes.
- [SPEC.md](SPEC.md): contrato en preparación para PoST + DAG y reglas comunes.
- [MIGRACION.md](MIGRACION.md): parámetros, estado de implementación y límites de la evidencia.
- [Ficha previa de finalidad](veritas/finalidad/baseline-30m/MODELO.md): modelo de carrera, procedencia de parámetros y cierres pendientes antes de validar en Julia.
- [research/README.md](research/README.md): índice de investigación útil y su vigencia.
- [veritas/LINEO.md](veritas/LINEO.md): proceso obligatorio para cálculos y auditorías nuevas.
- [AGENTS.md](AGENTS.md): instrucciones de trabajo locales.

El vault externo de Obsidian está desactualizado. No hace falta acceder a él para trabajar en
este repositorio y no fija las decisiones ni los parámetros actuales.

## Componentes

| Directorio | Contenido y estado |
|---|---|
| `crates/zx-core` | Tipos, codificación, hashes, firmas y transacciones; cabecera pendiente de migrar. |
| `crates/zx-consensus` | Validación transparente, emisión y capacidad; selección y prueba de bloque pendientes del DAG. |
| `crates/zx-pot` | Primitiva PoT AES de Autonomys (`subspace-proof-of-time` @ `f8842d0`, 0BSD) con 32 vectores diferenciales; verifica **un slot**, no un bloque. |
| `crates/zx-storage` | Estado UTXO y persistencia; integración del estado y orden DAG pendiente. |
| `crates/zx-p2p`, `crates/zx-node` | Transporte, límites y sincronización reutilizables; nodo aún ligado al formato lineal. |
| `crates/zx-mempool` | Admisión y tarifas; integración con el nodo pendiente. |
| `crates/zx-rpc`, `crates/zx-wallet` | Interfaces previstas; todavía esqueletos. |
| `crates/zx-lightwalletd`, `crates/zx-scanner` | Servicios previstos de consulta y scanning. |
| `prototipos/pot-estable` | Prototipo original del PoT AES, conservado **sin cambios**; su incorporación al workspace es `crates/zx-pot`. |
| `research`, `PDF`, `testdata` | Investigación, fuentes de PoSpace y vectores criptográficos que siguen siendo útiles. |
| `veritas` | Julia CPU y C++/CUDA para las auditorías que lo justifiquen. |

La capa blindada es parte del destino del proyecto; su ausencia actual no autoriza sustituirla
por una solución distinta. No se incorporan staking ni comités de decisión.

La primitiva PoT está incorporada y probada, pero **no cableada**: `zx-consensus` expone el
adaptador de un slot AES y un núcleo de rango con tres estados. Ese núcleo exige una instantánea
del pasado DAG validado que todavía no tiene derivador de producción.
`zx-core::wire_dag::verificar_justificacion_pot` sigue devolviendo `IntegracionPotPendiente` y
`zx-node` continúa con la cabecera lineal. Esto **no** resuelve el doble farmeo ni convierte a
ZEROX en un nodo que valide bloques PoST.

## Comprobación del código

```bash
cargo fmt --all -- --check
cargo check --workspace --locked
cargo test --workspace --locked
```

Estas comprobaciones se refieren al código existente. Su éxito no demostraría que el protocolo
PoST + DAG esté implementado ni que las tablas de finalidad sean aplicables. Las diferencias
de migración se documentan en [MIGRACION.md](MIGRACION.md).

Hay un fallo conocido y conservado en `spec_numeros`: la cabecera de código aún mide 92 bytes,
frente a los 556 de la base PoAS lineal del SPEC. No debe ocultarse ni interpretarse como que
556 bytes ya resuelven el formato DAG. Los tests de red también necesitan poder abrir sockets.
