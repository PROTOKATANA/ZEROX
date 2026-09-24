# E1 · Preparación del despacho de anuncios compactos

**Ejecutor:** DeepSeek Harness, `deepseek-v4.1-flash`, esfuerzo `high`. **Estado:** preparación; no cerrar E1 ni cambiar la suscripción activa.

## Fuentes y límite

Lee `AGENTS.md`, `README.md`, `MIGRACION.md`, `SPEC.md` C-NET-02 y C-NET-25…28, y `crates/zx-p2p/src/{servicio,entrante,rele_compacto,config}.rs`. El camino lineal `/blocks/1` sigue activo durante esta preparación. Solo puedes modificar:

- `crates/zx-p2p/src/servicio.rs`
- `crates/zx-p2p/src/entrante.rs`
- tests nuevos dentro de `crates/zx-p2p/tests/` si el acceso a funciones privadas obliga a ello; prefiere tests unitarios en `servicio.rs`.

No modifiques `config.rs`, `behaviour.rs`, `mensaje.rs`, `codec.rs`, `rele_compacto.rs`, `zx-node`, el SPEC, CI, manifests ni lock. No hagas commit ni push. Si descubres que una firma aquí es imposible, informa antes de ampliar archivos.

## Cambio concreto

1. Sustituye el `topico.contains("/blocks/")` de `BucleRed::juzgar` por clasificación **exacta** de estos temas: `/zerox/blocks/1`, `/zerox-testnet/blocks/1`, `/zerox/blocks/2`, `/zerox-testnet/blocks/2`, `/zerox/txs/1` y `/zerox-testnet/txs/1`. Ninguna coincidencia por prefijo o substring. Un tema desconocido devuelve `Veredicto::Ignorar` sin decodificar ni llamar al manejador. Mantén el comportamiento de bloque lineal en `/blocks/1` y de tx en `/txs/1`.
2. Para `/blocks/2`, decodifica exactamente un `AnuncioCompacto` con `AnuncioCompacto::desde_bytes(&m.data, &Presupuesto::default())`; **exige resto vacío**. Un error de formato, presupuesto o bytes residuales devuelve `Rechazar`. Un anuncio bien formado se pasa a un método nuevo `ManejadorEntrante::anuncio_compacto(&self, anuncio: &AnuncioCompacto) -> Veredicto`. Su implementación por defecto devuelve `Ignorar` y documenta que `zx-node` todavía no dispone de validación DAG causal. El default no debe aceptar ni reenviar. No hagas validación PoAS/PoT en `zx-p2p` ni emitas `Aceptar` por el mero éxito del parseo.
3. Mantén la frontera: `zx-p2p` define el trait; `zx-node` lo implementará cuando A2/A3/C1/B3 estén conectados. No añadas llamadas bloqueantes al bucle de libp2p. Cita `C-NET-25`, `C-NET-26` y `C-NET-12` en comentarios precisos: el codec no certifica contenido ni padres. No digas que C-NET-27/28 están implementadas; cola de huérfanos y proveedores alternativos siguen pendientes.

## Pruebas con capacidad de detectar regresiones

- Tabla de clasificación: seis temas exactos y falsos positivos como `/zerox/blocks/2/extra`, `/otra/zerox/blocks/2`, `/zerox/blocks/20`, `/zerox/txs/2`; todos los falsos devuelven desconocido.
- Un `AnuncioCompacto` real de fixture, serializado con `a_bytes`, se decodifica en `/blocks/2` y llega una sola vez al callback compacto; el default o un manejador sin validación da `Ignorar`, **nunca `Rechazar` ni `Aceptar`**. Prueba también la variante testnet.
- El mismo anuncio seguido de un byte residual y uno truncado se rechazan en el tema exacto `/blocks/2`; un `Respuesta::Bloques` lineal no se interpreta como anuncio válido. Un tema desconocido con esos bytes no penaliza.
- El tema `/blocks/1` sigue invocando el callback lineal para su mensaje válido; `/txs/1` conserva su callback. No sustituyas estos tests por una comprobación de constantes.

Si resulta difícil construir `BucleRed` por el `Swarm`, extrae una función de despacho interna que reciba `&impl ManejadorEntrante`, `&str`, `&[u8]` y sea invocada por `juzgar`; prueba esa función. Mantén el presupuesto y la decodificación en un solo lugar. No construyas un `Swarm` falso solo para probar un `match`.

## Comprobación y entrega

Ejecuta `cargo test -p zx-p2p --locked`, `cargo clippy -p zx-p2p --all-targets --locked -- -D warnings`, `cargo fmt --all -- --check`, `ci/citas-spec.sh`, `git diff --check` y `git status --short`. Los tests que necesitan sockets pueden requerir el entorno normal del repositorio; comunica cualquier fallo exacto. Resume cada archivo cambiado y el límite de integración. E1 seguirá abierta hasta que `/blocks/2` sea el tópico activo y el nodo reconstruya, valide, solicite faltantes, retenga huérfanos y anuncie bloques válidos.
