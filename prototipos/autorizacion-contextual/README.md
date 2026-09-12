# Dominio y autorización contextual — prototipo DAV-v0.1

Standalone: no se importa desde el nodo activo. No activa consenso, no certifica bloques PoST/DAG
y no produce una garantía de finalidad. Usa validadores existentes de `zx-core`/`zx-consensus`;
la procedencia del snapshot, del compromiso esperado y del calendario se suministra como oráculo.

[Contrato y límites](../../veritas/consenso/dominio-autorizacion-v1/CONTRATO.md) ·
[Resultados](../../veritas/consenso/dominio-autorizacion-v1/INFORME.md)

## Superficie

- `dominio`: clave económica exacta por red/coordenada/slot y comparación de prefijos declarados.
- `compromiso`: vector ordenado de txid/auth_digest y composición contra un compromiso esperado.
- `autorizar_cuerpo`: perfil transparente ALL con snapshots inmutables y firmas reales.
- `almacen`: capacidades privadas, consultas exactas, no degradación, CAS local por instancia/contexto/revisión.

Los perfiles no soportados se rechazan explícitamente; no se aceptan Orchard, otros HashType,
lock_time no nulo o dependencias intra-cuerpo por una ruta de sustitución.
El compromiso vectorial no es una cabecera firmada y el almacén no aplica transacciones ni paga.

## Reproducción desde ZEROX

```sh
timeout 120s cargo test --offline --locked -j 2 --manifest-path prototipos/autorizacion-contextual/Cargo.toml -- --test-threads=1
timeout 120s cargo clippy --offline --locked -j 2 --manifest-path prototipos/autorizacion-contextual/Cargo.toml --all-targets -- -D warnings
cargo fmt --manifest-path prototipos/autorizacion-contextual/Cargo.toml -- --check
sha256sum -c veritas/consenso/dominio-autorizacion-v1/HUELLAS.sha256
```

El Cargo.lock propio fija resolución de dependencias; las crates locales se fijan además por
huellas y HEAD de referencia con worktree declarado. No se actualizan locks ni fuentes anteriores.
Firmador de fixtures: `ed25519-zebra=4.2.0`, sólo dev-dependency; verificación nativa ZIP-215.
Fixtures deterministas, no Monte Carlo ni benchmark. No Python ni GPU.
