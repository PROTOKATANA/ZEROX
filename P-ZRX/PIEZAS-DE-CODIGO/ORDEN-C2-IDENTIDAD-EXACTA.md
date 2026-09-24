# Orden C2 parcial · identidad exacta en GHOSTDAG

Ejecutor: DeepSeek Harness, `deepseek-v4.1-flash`, esfuerzo `high`. Leer `AGENTS.md`, `README.md`, `MIGRACION.md`, `SPEC.md` C-GD-07/C-GD-09/C-HDR-06 y `veritas/LINEO.md` entero antes de editar tests de cálculo. No hacer commit ni push. El líder revisará el diff.

## Defecto y objetivo

`crates/zx-consensus/src/ghostdag.rs` guarda `identidad: u64`, usa 0 como «sin billete» y recibe ese número en `admitir`. C-GD-07 requiere igualdad de la tupla literal `(public_key, sector_index, history_size, chunk, slot)`. `IdentidadTicket` en `firmante/identidad.rs` ya representa exactamente esa tupla y `Firmante::identidad(&DagBlockHeader)` la deriva de la cabecera. Una proyección de 82 bytes a `u64` no es inyectiva. C2 no puede activarse así.

Cambiar únicamente el modelo de identidad de GHOSTDAG y tests que dependan de él; conservar fórmulas, coloreo, peso, orden y APIs sintéticas de oráculos. El código sigue sin admisión PoST de nodo y **no** se marca C2.

## API y representación

1. Definir en `ghostdag.rs` una identidad interna/externa tipada, con `SinBillete`, `Billete(IdentidadTicket)` y `Sintetica(u64)` o un equivalente que mantenga **separados** los dominios real y de fixture. La igualdad del caso `Billete` compara la tupla literal mediante `IdentidadTicket::Eq`; jamás `huella()[..8]`, `u64`, hash corto, clave pública sola ni sello. El caso `Sintetica` existe exclusivamente para vectores/oráculos históricos, no es una entrada de producción. El antiguo centinela `0` de fixture corresponde a `SinBillete`; un billete real cuyos bytes sean cero **no** equivale a ausencia.
2. `BloqueGhostdag.identidad`, `AlmacenGhostdag.idents`, `DatosGhostdag.blue_idents`, las firmas de `pasado_contiene_ident`, `colorear_*`, `acumular` y el error `ConsensusError::BilleteDuplicadoU2` usarán la misma identidad exacta/enum (o `Option` tipado), sin doble fuente de igualdad. En U2/U3, `Sintetica(n)` se compara solo con `Sintetica(n)` y `Billete(t)` solo con `Billete(t)`. Evitar `unwrap_or(0)` ante un índice incoherente: devolver error explícito antes de mutar.
3. `AlmacenGhostdag::admitir` no debe aceptar identidad de un llamante: derivarla **de la misma `cabecera`** que aporta hash, slot y SR, con `Firmante::identidad(cabecera)`. Cambiar la firma pública para eliminar el argumento `identidad: u64`. Su doc comment debe dejar claro que esto cierra solo la igualdad de C-GD-07, no la procedencia causal de SR, PoT, PoAS, cuerpo ni C-GD-11.
4. Mantener `anadir_sintetico` y `nuevo` para los oráculos. Si `nuevo` sigue recibiendo `ident_genesis: u64`, convertirlo explícitamente al dominio sintético; el génesis de fixture con cero es ausencia. No permitir que un llamante inserte `Sintetica` por `admitir`. Si un enum público permite construir `Billete` en la vía sintética, documentar que esa vía **nunca** acredita PoST. No llamar a esta vía «validada».
5. No modificar `SPEC.md`, parámetros de `C-GD-11`, código de red, storage ni `firmante/identidad.rs` salvo una necesidad justificada. No cambiar semántica de los vectores GHOSTDAG: su `u64` de fixture pertenece a `Sintetica`.

## Pruebas decisivas

- Dos cabeceras con identidades literales distintas y misma proyección artificial a 64 bits (por ejemplo cambiar un byte del `chunk` fuera de los ocho elegidos por la proyección) no disparan U2 ni U3. Hacer el test contra la nueva API/representación, no contra un helper tautológico.
- La **misma** identidad literal en un descendiente activa U2; en un mergeset activa U3 conforme al algoritmo existente. Verificar `Kernel` y `Referencia` cuando aplique.
- Billete real con campos cero no se trata como `SinBillete`; repetición debe detectarse. El caso `SinBillete` del génesis/fixture no produce U2 falso.
- `admitir` deriva identidad desde la cabecera, no hay parámetro libre; un error de SR deja índices/identidades intactos y el mismo header puede reintentarse correctamente. Mantener los tests anteriores de C-HDR-06.
- Correr la suite GHOSTDAG existente (incluidos oráculo, propiedad, benchmark si compilable), `cargo test -p zx-consensus --locked`, `cargo clippy -p zx-consensus --all-targets --locked -- -D warnings`, `cargo fmt --all -- --check`, `ci/citas-spec.sh`, `ci/alcance-consenso.sh`, `git diff --check`. No alterar inventarios CI para esconder fallos; informar fallo textual si aparece.

Al terminar, informar rutas cambiadas, decisiones de tipos, tests y límites. No hacer commit.
