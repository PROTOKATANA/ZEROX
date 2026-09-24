# CORRECCIÓN D2/A3 · congelar y comprobar el compromiso de historia dev

**Ejecutor:** DeepSeek Harness `deepseek-v4.1-flash`, esfuerzo `high`. Fase 2 de `ORDEN-D2-HISTORIA-COMUN-DEV.md`; incremento parcial, no cierra D2/A3. El líder ejecutó en **un segundo proceso independiente** el test de compromiso y obtuvo el mismo valor que tu primer proceso. Ambos midieron exactamente 96 dígitos hex:

`97a1f20f77051b88d60a2f543841dc2934a2e6079c3be1c31a687f43015f547594e8ff9a62753515f943dc1c3f96df96`

## Archivo autorizado y cambio exacto

Editar **solo** `crates/zx-node/src/historia_dag_dev.rs`. No tocar test D1, otro test, `lib.rs`, manifiestos, lockfile, binario, CI, SPEC, PDF ni documentos. No hacer commit ni push. Comprueba `git status --short` antes/después; los cambios previos de esta entrega y los ajenos deben mantenerse intactos.

1. Guardar los 48 bytes anteriores como una constante **privada**, de tipo `SegmentCommitment` o `[u8; 48]`; sin dependencia nueva ni parser hexadecimal en producción. Bytes en orden exacto:

   ```text
   0x97, 0xa1, 0xf2, 0x0f, 0x77, 0x05, 0x1b, 0x88,
   0xd6, 0x0a, 0x2f, 0x54, 0x38, 0x41, 0xdc, 0x29,
   0x34, 0xa2, 0xe6, 0x07, 0x9c, 0x3b, 0xe1, 0xc3,
   0x1a, 0x68, 0x7f, 0x43, 0x01, 0x5f, 0x54, 0x75,
   0x94, 0xe8, 0xff, 0x9a, 0x62, 0x75, 0x35, 0x15,
   0xf9, 0x43, 0xdc, 0x1c, 0x3f, 0x96, 0xdf, 0x96
   ```

2. En `HistoriaDagDev::construir`, **después** de obtener el primer `NewArchivedSegment` y **antes** de devolver `Ok(Self { .. })`, comparar `historial.segment_header.segment_commitment()` contra el literal. Si difiere, devolver `ErrorHistoriaDagDev::CompromisoInesperado { esperado, observado }`, con ambos valores visibles en `Debug` o `Display`. No aceptar el nuevo valor, no derivar el esperado de la ejecución y no crear el objeto en fallo. Mantener los demás errores separados.
3. Extraer el cotejo a una función privada pequeña para permitir un test unitario con un `SegmentCommitment` mutado. Añadir en este mismo archivo un test de que el valor esperado pasa y otro de que un valor con un byte cambiado devuelve exactamente la variante `CompromisoInesperado`. No generar otra historia de 130 MB para probar el error ni introducir `expect/unwrap` en la ruta pública. El test puede usar `expect` con excepción local de lint si hace falta.
4. Actualizar solo los comentarios de este módulo que ahora digan «no literal congelado», para dejar explícito que la receta y el compromiso son del **fixture dev**; no son compromiso de génesis ni parámetros mainnet/testnet. El cotejo detecta divergencia local del archivo, no acredita disponibilidad en red ni valida cabeceras.

## Verificación y entrega

Ejecutar `cargo test -p zx-node --features farmer --locked --lib historia_dag_dev`, `cargo test -p zx-node --features farmer --locked --test historia_dag_dev`, `cargo fmt --all -- --check`, `cargo clippy -p zx-node --all-targets --features farmer --locked -- -D warnings`, `git diff --check`. La batería D1 13/13 ya pasó en fase 1; no repetirla. Informar archivos tocados, resultado de las pruebas y detenerse para revisión del líder. No probar perfiles release ni suites extra.
