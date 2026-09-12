# AUT-v0.1 — Composición experimental de autorización transparente

Fecha: 2026-09-11. Categoría: consenso; instrumento Rust de integración, no simulación,
benchmark ni cálculo nuevo de finalidad. No activa consenso ni modifica el nodo, ventana,
retarget o los instrumentos IDV/CBE anteriores.

## Resultado y alcance

El crate aislado [autorizacion-contextual](../../../prototipos/autorizacion-contextual/)
añade una API que compone los validadores **reales** existentes:

```text
snapshot owned identificado + cuerpo candidato
    → perfil y estructura + compromisos + dependencias identificadas
    → validar_cuerpo → validar_tx (llamada interna nativa)
    → sighash nativo por entrada → satisface nativo por Lock
    → AutorizacionPerfil, sólo si todas esas comprobaciones pasan
```

`AutorizacionPerfil` **no** significa «bloque plenamente válido». Acredita los controles
enumerados de un perfil transparente sobre el snapshot exacto suministrado. No verifica
cabecera PoST, sello, PoAS, PoT, padres DAG, disponibilidad global ni autenticidad del snapshot.
No aplica UTXO, ni adjudica billetes, ni cobra comisiones o subsidios.

Los tests de integración cubren PubKey, MultiSig y ambas ramas HTLC con firmas Ed25519
reales, no etiquetas de validación. Una firma alterada conserva txid y cabecera, pero falla
en `satisface` y no produce evidencia. Dos autorizaciones MultiSig 1-de-2 diferentes pueden
ser válidas para exactamente la misma cabecera/efectos; no se adopta «primera firma recibida».

## 1. Superficie y límites de las primitivas

Código nativo relevante:

- `crates/zx-consensus/src/bloque.rs::validar_cuerpo`: estructura, Merkle, doble gasto
  intrabloque, importes, peso, emisión; llama a `validar_tx`, no a `satisface`.
- `crates/zx-consensus/src/validacion.rs::validar_tx`: versión, expiración, entradas,
  madurez coinbase, balance y peso; no autoriza firmas ni define el futuro orden DAG.
- `crates/zx-core/src/preimage/tx.rs::sighash`: compromete salidas gastadas en el orden
  de las entradas, con su importe y Lock y el branch ID de la cabecera.
- `crates/zx-consensus/src/testigo.rs::satisface`: verifica PubKey, MultiSig y HTLC,
  consume todo el testigo y usa altura contextual para la rama timeout.

La API añade preflight de todos los Locks de salida y de snapshot mediante el constructor
nativo `Lock::multisig`, para que un literal de enum inválido no evada sus invariantes.
Comprueba también versión, salidas no vacías, altura de coinbase, ausencia de testigos
coinbase y peso máximo por transacción antes de delegar al validador de cuerpo.

**Perfil explícitamente parcial:**

| Entrada | Resultado |
|---|---|
| HashType ALL | Usa `sighash(..., HashType::All, ...)` nativo. |
| Los otros cinco HashType definidos | `NoSoportado`, no reinterpretación como ALL. |
| `lock_time != 0` | `NoSoportado`: la composición no inventa la semántica temporal pendiente. |
| Orchard `Some(...)`, incluso vacío | `NoSoportado`: falta su verificador; nunca aceptación de blindado por omisión. |
| Gasto de una transacción del mismo cuerpo | `NoSoportado`: no simula salida creada como UTXO previo ni inventa orden causal. |
| Transacción sin salidas, incluida coinbase | Fuera del perfil; no autorización parcial silenciosa. |

`HashType` es una selección explícita del perfil experimental, no un nuevo byte adoptado en
wire. El formato actual de testigo P2K contiene la firma de 64 bytes, sin selector HashType.
`sequence` entra en el sighash nativo; no se certifica una semántica de timelock relativo.
El timeout HTLC usa la altura del snapshot declarado, sin convertir slots o ranks DAG en altura.

## 2. Contexto: identificado no significa autenticado

`ContextoIdentificado::desde_snapshot_declarado` consume datos y una lista de estados de
outpoints. Ordena por txid e índice, rechaza duplicados, verifica Locks y alturas de creación,
y conserva la lista **owned e inmutable**, sin callback UTXO que pueda cambiar entre consultas.

Su `context_key` local compromete dominio, ancla causal, red, altura, mediana, emitido,
declaración de completitud y **todos** los outpoints/estados suministrados. Para las salidas
disponibles incluye importe, Lock canónico, altura de creación y condición de coinbase.
La permutación de la lista de entrada no altera la huella; cambiar cualquier dato sí cambia
la preimagen. SHA3-256 aporta resistencia a colisiones, no autenticidad del proveedor.

Estados separados:

- `Disponible(EntradaUtxo)`: permite verificar balance, madurez y autorización.
- `Desconocido` o ausencia de entrada en el snapshot: `Dependencias`, incluso si
  `completo=true`. Un lookup fallido no acredita inexistencia.
- `Inexistente`: ausencia expresamente suministrada por el proveedor; invalidez en ese
  contexto, no prueba de inexistencia por sí misma.
- `Gastado`: devuelve `GastadoEnSnapshot`. **No acredita autorización de la transacción
  recibida**, porque no conserva el Lock histórico para comprobar esa firma.
- `completo=false`: `ContextoIncompleto`, sin token.

Si hay varias causas, el preflight de formato/perfil corre primero; después completitud,
dependencias desconocidas, inexistencia declarada y gastos declarados, en ese orden.
Esto es precedencia de resultados del experimento, no una nueva regla de consenso.
Ninguna de esas rutas publica evidencia parcial. Invalidez de la entrega no es, por sí sola,
invalidez de toda representación de su cabecera.

El constructor **no demuestra** que `completo=true`, las raíces o las salidas correspondan
a un pasado DAG real. El integrador debe obtener el contexto de una fuente causal verificada
y suministrar su `context_key` esperado al almacén. Un llamante puede construir otro snapshot;
el token obtenido sólo acredita validación sobre ese otro snapshot, no sobre el esperado.
Las condiciones de autenticidad y completitud causal de producción siguen pendientes.

## 3. Evidencia y frontera de almacenamiento

`AutorizacionPerfil` tiene campos privados, getters inmutables, `Clone`, y no tiene constructor
público, `Default`, `Deserialize` ni conversión desde bytes. Dos doctests negativos comprueban
que un cliente Rust seguro no puede construirlo con un literal **con todos los campos** ni
mutar el cuerpo a través de su getter. No se promete resistencia frente
a código interno malicioso, corrupción de proceso o `unsafe` externo.

Getters estables:

```rust
body_key() -> [u8; 32]
context_key() -> [u8; 32]
block_hash() -> BlockHash
cuerpo() -> &CuerpoCandidato
resultado() -> BloqueValidado
```

El token conserva un clon owned del candidato, no una referencia mutable al recibido.
`resultado()` conserva el resultado nativo de peso/fees/subsidio del cuerpo; no demuestra
que se haya aplicado un ledger o emitido ese subsidio.

`body_key` es una **clave local de caché**, no el futuro compromiso de autorización de
consenso. Compromete el cuerpo wire nativo **incluida la cabecera**, la matriz completa de
testigos, el perfil HashType y la presencia/contenido Orchard. La cola explícita de testigos
evita que listas sobrantes se pierdan por el comportamiento del encoder nativo.

Los prefijos `ZEROX/experimental/AUT-v1/cuerpo\0` y
`ZEROX/experimental/AUT-v1/contexto\0` son namespaces locales experimentales, no etiquetas
añadidas al SPEC. El hash de cuerpo **no puede introducirse tal cual en la cabecera**:
su dependencia de esa misma cabecera crearía autorreferencia. El compromiso propuesto por
el módulo separado `compromiso` es independiente de ella.

La comprobación criptográfica no decide first-seen, persistencia durable o manejo ABA.
Esas políticas viven en el módulo experimental de almacenamiento del mismo crate y deben
exigir igualdad de cuerpo, contexto y generación esperados antes de publicar evidencia.

## 4. Reproducción y estado de las pruebas

Sin RNG: las claves de fixtures se derivan de semillas públicas `[7;32]` y `[8;32]` mediante
ed25519-zebra **4.2.0**, versión exacta ya usada en ZEROX. Valores pequeños de fixture:
altura 10, UTXO de 100 brek y salida de 90, mediana 100000; no son parámetros nuevos de red.
El borde de madurez usa `COINBASE_MATURITY` nativo, no una conversión propia a segundos.

Cargo/lock aislados; dependencias productivas sólo por path a zx-core y zx-consensus.
No se modifica su código ni el lock del workspace. No hay Python, GPU ni Julia nueva.
LINEO se leyó íntegramente: aquí corresponde ejecutar las primitivas Rust, no un modelo
numérico sustituto. Complejidad no optimizada: recorridos de entradas/salidas y firmas,
lookup binario en snapshot; permanecen las comprobaciones cuadráticas nativas de doble gasto.
No se publica un benchmark ni una mejora de latencia a partir de estos fixtures.

```sh
cargo test --offline --locked -j 2 --manifest-path prototipos/autorizacion-contextual/Cargo.toml --test autorizar -- --test-threads=1
cargo test --offline --locked -j 2 --manifest-path prototipos/autorizacion-contextual/Cargo.toml --doc
cargo clippy --offline --locked -j 2 --manifest-path prototipos/autorizacion-contextual/Cargo.toml --test autorizar -- -D warnings
```

Resultado inicial: **12 tests de autorización aprobados**. Incluyen firma inválida con misma
cabecera/txid; variantes MultiSig válidas; HTLC preimagen/timeout y su borde; estados de
dependencia/gasto/inexistencia; huella contextual; rechazos de perfil; fronteras coinbase y
Locks manuales; madurez/expiración/balance; orden/importes de dos entradas; doble gasto y
testigos sobrantes. El resultado de la corrida conjunta final se registra en el informe de etapa.

Clippy estricto del target `autorizar` pasó sin advertencias. La primera compilación detectó
cuatro préstamos mutables/inmutables simultáneos al ensamblar
firmas de fixtures. Se separó su cálculo del `extend`; no se alteraron las condiciones ni los
resultados esperados. Tras corregirlo, los doce tests pasan en 0,06 s de ejecución observada.
La primera compilación tardó 5,31 s y reportó 438832 KiB de RSS máximo; no son cotas de red ni
benchmarks. Presupuesto de pruebas: 10 minutos, 4 GiB RAM, 2 GiB nuevos de disco y 2 jobs;
no se agotó. El timeout por comando fue 120 s, con devolución asíncrona para no bloquear updates.
