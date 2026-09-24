# D1 · Exclusiones de workspace para enlazar el farmer auditado

Ejecutor: DeepSeek Harness `deepseek-v4.1-flash`, esfuerzo `high`. `DECISIONES-0.0.1.md` D1-CARGO A quedó elegida **PROVISIONALMENTE** bajo `PROMPT.md` §4.1. Esta es una excepción acotada a la zona original de trabajo; no cambia consenso ni parámetros.

**Único archivo editable:** `Cargo.toml` de la raíz de ZEROX. No edites `Cargo.lock` todavía, ni archivos de `crates/`, `PDF/`, `ci/`, `SPEC.md`, `research/`, `veritas/` u otros. No hagas commit ni push.

Lee `AGENTS.md`, `README.md`, `MIGRACION.md`, este documento y `Cargo.toml` antes de modificar. En `[workspace].exclude`, añade exactamente estos cuatro paquetes del clon fijado `PDF/autonomys-subspace`:

- `PDF/autonomys-subspace/crates/subspace-farmer-components`
- `PDF/autonomys-subspace/crates/subspace-archiving`
- `PDF/autonomys-subspace/shared/subspace-data-retrieval`
- `PDF/autonomys-subspace/crates/subspace-erasure-coding`

Conserva las cinco exclusiones A1 existentes y todos los demás campos. Ajusta el comentario de la lista para explicar que A1 usa cinco paquetes y D1 añade cuatro, y que cada paquete debe resolver la herencia `workspace = true` contra el workspace del clon, no el de ZEROX. No añadas dependencias ni cambies versiones. No copies código upstream.

**Corrección de ruta hecha durante la ejecución:** la primera versión de esta orden indicaba `crates/subspace-data-retrieval`, que no existe. DeepSeek comprobó el manifiesto real del clon y añadió `shared/subspace-data-retrieval`; el líder verificó el paquete en esa ruta. La línea corregida de arriba refleja lo que efectivamente se necesita. No se añadió una quinta exclusión.

Comprueba `git diff -- Cargo.toml`, `git diff --check` y `git status --short Cargo.toml Cargo.lock`. Si `Cargo.lock` cambia, detente e informa sin intentar revertir trabajo ajeno. El líder inspeccionará el diff y ejecutará la orden principal D1 en otro paso.
