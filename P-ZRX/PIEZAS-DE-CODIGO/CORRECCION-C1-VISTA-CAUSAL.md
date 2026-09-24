# Corrección a DeepSeek · C1, candidato en su propio pasado

Usa **DeepSeek V4.1 Flash**, esfuerzo `high`, mediante DeepSeek Harness. Corrige únicamente la entrega de [ORDEN-C1-VISTA-CAUSAL.md](ORDEN-C1-VISTA-CAUSAL.md). No hagas commit ni push.

## Hallazgo confirmado por revisiones Rust y matemática

`VistaPasadoEstructural::desde_padres` recibe solo `PadresDag`. Si el candidato `P` declara como padre `A`, y la fuente ofrece `A → P` y `P → génesis`, el recorrido devuelve `P` en `ancestros`. El grafo de la fuente no tiene un ciclo interno, pero el candidato sí quedaría en su propio pasado. La afirmación «sin el candidato» es falsa para esa fuente. El test actual omite `P` de la fuente y no detecta el caso.

## Corrección obligatoria

1. Añade `hash_candidato: BlockHash` a la API `desde_padres` y a todas sus llamadas en los tests. **Antes de leer o insertar** cualquier hash, si coincide con el candidato, devuelve un error tipado propio, por ejemplo `CandidatoEnSuPasado { hash }`, de incoherencia estructural. Esta comprobación precede al presupuesto: incluso con el límite agotado, encontrar el propio hash no debe ocultarse como agotamiento. No devuelvas vista parcial.
2. Añade un test adversarial con el caso `P → A`, fuente `A → P` y `P → génesis`. Verifica explícitamente el error y que no hay vista. Añade también un padre directo igual a `P`, para no depender de que la fuente contenga ese registro. Conserva los tests existentes de diamante, ausencias y ciclo.
3. Ajusta docs y contrato: `VistaPasadoEstructural` es inmutable **después** de construirla, pero la función no puede garantizar una lectura coherente si la fuente cambia durante el recorrido. `FuenteRegistrosDag` para producción debe ser una instantánea estable, con registros inmutables por hash; un `&self` con mutabilidad interior no basta. Esta preparación no instala todavía una fuente de producción ni promete coherencia concurrente. Registra en la doc el presupuesto de número de registros como cota parcial de recursos; el futuro llamante debe fijar un límite local y ejecutar fuera del bucle de red. No añadas un `generacion()` ficticio que una fuente arbitraria pueda mentir ni marques validez PoST.

## Límites de edición y verificación

Solo `crates/zx-node/src/dag_causal.rs` y `crates/zx-node/tests/dag_causal.rs`; `lib.rs` no necesita cambio. No edites CI, otros crates ni documentos del líder. Repite `cargo test -p zx-node --locked --test dag_causal`, `cargo clippy -p zx-node --all-targets --locked -- -D warnings`, `cargo fmt --all -- --check`, `ci/citas-spec.sh`, `ci/alcance-consenso.sh` y `git diff --check`. Reporta los resultados y el límite de concurrencia restante. C1/A2 siguen abiertas.
