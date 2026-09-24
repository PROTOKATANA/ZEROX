# CORRECCIÓN D3 · rutas locales y permisos de clave al reabrir

**Ejecutor:** DeepSeek Harness `deepseek-v4.1-flash`, esfuerzo `high`. Revisión del líder sobre `ORDEN-D3-ALTA-IDENTIDAD-NUEVA-DEV.md`. La entrega inicial pasa 6/6 y CI, pero `IdentidadProductorLocal::abrir_o_crear` usa `metadata()` sobre `productor.key`, que sigue enlaces simbólicos, y no comprueba permisos de una clave existente. Además promete no crear rutas fuera del directorio, pero `alta.lock` y `firmas.log` preexistentes podrían ser symlinks. Son fallos de la frontera local del secreto y de la afirmación documental, no de PoT. No cambies `S_max`, `Registro::abrir`, formato ni tests previos.

## Archivos exactos

- Modificar solo `crates/zx-consensus/src/firmante/alta.rs` y `crates/zx-consensus/tests/alta_firmante_local.rs`.
- No tocar `registro.rs`, `mod.rs`, manifests/lock, SPEC, CI, PDF, red ni binario. No commit/push.

## Cambio requerido

Antes de abrir cualquiera de las tres rutas fijas, inspeccionar con `symlink_metadata` y rechazar explícitamente un enlace simbólico y un objeto de tipo distinto del fichero regular esperado. El directorio de entrada también debe ser un directorio real, no un symlink; si no existe, devolver `DirectorioInvalido` como documenta el enum. Para `alta.lock` y `firmas.log`, si el fichero no existe se permite crearlo en la ruta fija; si existe debe ser regular. No tratar errores de E/S distintos de `NotFound` como ausencia. La comprobación puede quedar en un helper local de `alta.rs` con error tipado y ruta, sin exponer nuevas APIs; se mantiene el bloqueo y se sigue usando `Registro::abrir` en reinicio.

En Unix, al reabrir `productor.key`, exigir que ningún permiso de grupo/otros esté activo (`mode & 0o077 == 0`); de lo contrario, error sin leer la semilla, sin abrir/crear `firmas.log` y sin firmar. El modo de creación sigue `0600`. No imprimir modo ni semilla en el error si ello complica la API; basta un motivo estático. No arreglar permisos automáticamente: fallar cerrado permite al operador revisar el fichero. No añadir código inseguro, dependencia nueva ni protección contra un atacante que cambie el directorio entre comprobación y apertura: la amenaza declarada sigue siendo de accidentes honestos. Ajustar la documentación para no prometer cierre de carreras maliciosas.

## Pruebas

Añadir al test de integración, en Unix: (1) crear identidad, cerrarla, eliminar solo `firmas.log`, cambiar modo de `productor.key` a `0644` y comprobar error de permisos **antes** de recrear registro; (2) `productor.key` como symlink a un fichero regular fuera del directorio de alta ⇒ error, sin abrir registro; (3) `alta.lock` como symlink a un fichero externo inexistente ⇒ error y ese fichero externo sigue ausente; (4) `firmas.log` como symlink a un destino externo inexistente con clave ya existente ⇒ error y el destino externo sigue ausente. Para tests, restaurar permisos si el RAII necesita limpiar; nunca registrar bytes privados. En plataformas no Unix, al menos comprobar rechazo de symlink donde `symlink_metadata` exista; las pruebas de permisos pueden ser `#[cfg(unix)]`. Mantener en verde los seis tests previos.

## Entrega

Ejecutar `cargo test -p zx-consensus --locked --test alta_firmante_local`, `cargo fmt --all -- --check`, `cargo clippy -p zx-consensus --all-targets --locked -- -D warnings`, `cargo check --workspace --locked`, `ci/citas-spec.sh`, `ci/alcance-consenso.sh`, `git diff --check`. Reportar únicamente los cambios nuevos y el resultado; detenerse para revisión. No marcar D3.
