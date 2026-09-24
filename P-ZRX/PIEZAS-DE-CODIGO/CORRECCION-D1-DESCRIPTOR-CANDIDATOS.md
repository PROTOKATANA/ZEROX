# Corrección D1: descriptor verificado y candidatos accesibles

Modelo obligatorio para editar código: `deepseek-v4.1-flash`, esfuerzo `high`. Lee íntegros `README.md`, `MIGRACION.md`, las secciones aplicables de `SPEC.md`, `AGENTS.md` y `ORDEN-D1-PLOTTER-AUDITOR.md`. La presente orden afina D1; no modifica consenso ni el valor de ningún parámetro de red.

## Alcance

Editar solo `crates/zx-node/src/farmer.rs` y `crates/zx-node/tests/farmer_disco.rs`. No tocar otros archivos, ni hacer commit ni push. El árbol tiene cambios concurrentes. Conservar la API de creación exclusiva y las verificaciones ya existentes.

## Fallos que corregir

1. `ParcelaDisco::abrir` verifica un `File` y luego lo descarta. `auditar_slot` abre de nuevo `self.ruta`; entre ambos instantes puede sustituirse la ruta. Guardar el mismo descriptor verificado dentro de `ParcelaDisco` y pasarlo a `audit_plot_sync`. La ruta sigue disponible solo para diagnóstico. Documentar que no se protege contra escritura en sitio sobre el inode verificado; el directorio de parcelas es exclusivo. Probar que, tras abrir, si la ruta se renombra y en su lugar aparece otro archivo, la auditoría usa el descriptor original y devuelve el mismo resultado. Usar la prueba Unix si es necesario.
2. El resumen de auditoría descarta `solution_candidates`, que D2 necesita. Exponer una API pública `auditar_candidatos` que devuelva `Vec<AuditResult<'_, ReadAtOffset<'_, File>>>` prestado de `&self` (ambos tipos públicos están en `subspace_farmer_components`). Mantener `auditar_slot` como envoltorio que produce `ResumenCandidatos` a partir de esa API. El reto debe derivarse una sola vez por llamada; no repetir la auditoría dentro del envoltorio. Documentar que los candidatos no son soluciones válidas y que D2 debe usar `into_solutions` y verificar A1. Añadir test que coteje el número de candidatos reales con el oráculo independiente existente y el resumen. Procurar un slot determinista con al menos un candidato; si los 64 existentes no lo dan, buscar hasta un límite de test explícito y fallar con mensaje, sin fabricar un candidato.
3. `fs::read` de metadata carece de cota y puede agotar memoria si el archivo es gigante. Añadir un límite **local de recursos**, por ejemplo 2 MiB, documentado con unidad, definición, estado elegido y su justificación a partir de `u16::MAX` índices `PieceIndex` de 8 bytes más la metadata fija. Comprobar la longitud del descriptor de metadata **antes** de reservar/leer; leer desde el mismo descriptor medido, con `Read::take` si ayuda. Rechazar exceso con error tipado. Tras decodificar, comprobar `piece_indexes.len() == pieces_in_sector` y `plotted_sector.sector_index == cuerpo.sector_index`; reportar discordancias tipadas. Probar rechazo de metadata sparse sobredimensionada sin cargarla completa y de una metadata bien checksummada pero estructuralmente inconsistente si se puede construir sin duplicar enormes fixtures.

## Verificación

`cargo test -p zx-node --features farmer --locked --test farmer_disco`, `cargo test -p zx-node --locked`, `cargo clippy -p zx-node --all-targets --features farmer --locked -- -D warnings`, `cargo fmt --all -- --check`, `ci/citas-spec.sh`, `ci/frontera-crates.sh`, `ci/dependencias-exactas.sh`, `git diff --check`. Reportar `ci/alcance-consenso.sh` sin falsear su inventario. No escribir auditorías Python.
