# Disponibilidad y autorización: APIs reales existentes

Fecha: 2026-09-11. Categoría: consenso; secundarios: red, almacenamiento y criptografía.
Estado: **caracterización ejecutada; DA0 no implementado ni validado de extremo a extremo**.
Se siguió [LINEO](../../LINEO.md): sin Python, sin GPU ni simulación nueva.

## Alcance y método

Se añadieron exclusivamente nueve tests Rust en
[disponibilidad_real.rs](../../../crates/zx-node/tests/disponibilidad_real.rs).
Usan `BloqueRed`, wire, Merkle, `Cadena`, `AlmacenEnMemoria`, `ConjuntoEnMemoria`,
`validar_tx`, `validar_cuerpo`, `sighash` y `testigo::satisface` **reales**.
La firma del fixture se genera con Ed25519 de la dependencia existente `libp2p`;
se verifica con la ruta real `satisface → zx_core::firma::verificar` (ZIP215).
No se inventó un validador ni un almacén stub, ni se añadieron dependencias.

La cabecera lineal existente sirve solamente como contenedor de compromisos del fixture.
No se mina, no se llama a `validar_cabecera`, no se adopta esa cabecera y **no se presenta
PoW como validación PoST**. El test del almacén llama directamente a `guardar_bloque`;
no afirma haber atravesado el filtro de cabeceras conocidas de la ruta de red.
No se editó producción ni se activó consenso, ventana de elegibilidad o retarget.

## Resultados y límite exacto

| Caso/API real | Resultado comprobado | Qué no demuestra |
|---|---|---|
| `AlmacenCadena::cuerpo` sin clave | `Ok(None)`; `tiene_cuerpo=false` | Disponibilidad global o invalidez |
| Bytes `[0xff]` almacenados | Wire rechaza; `tiene_cuerpo=true`; `Cadena::bloque=None` | Que el peer originó la corrupción; que volverá a pedirse |
| Wire completo/truncado | Roundtrip exacto; truncado rechazado | Autenticación o correspondencia Merkle |
| Efectos distintos con misma cabecera | `RaizNoCoincide`; no reemplaza el cuerpo bueno | Invalidez permanente de la cabecera: puede llegar el cuerpo correspondiente |
| Efectos/cabecera iguales, testigo válido/inválido | Mismo txid, Merkle y blockhash; distinto `auth_digest`; firma válida frente a rechazo criptográfico real | Que una entrega con firma mala invalide todas las autorizaciones del mismo compromiso |
| Composición explícita `validar_cuerpo → sighash → satisface` | Fixture P2K admitido; firma mala rechazada sobre el mismo pasado UTXO | Un validador completo de producción, otros locks, PoST/DAG o DA global |
| Testigo interno de 63 bytes | Pasa `comprobar_cuerpo`; `satisface` rechaza formato | Autorización completa por la barrera C-NET-23 |
| Falta un vector exterior de testigos | `TestigosDescuadrados` | Qué otra entrega completa puede obtenerse |
| Mismo gasto, UTXO presente frente a retirado/desconocido | Presente admite; ambos ausentes producen `EntradaInexistenteOGastada` | Distinguir gasto conflictivo de dependencia contextual incompleta sin procedencia del estado |
| Dos copias de la tx dentro de un cuerpo con Merkle recalculado | Barrera de correspondencia admite; `validar_cuerpo` rechaza `DobleGastoEnBloque` | Aplicar a este cuerpo la omisión de tx repetida del modelo abstracto M0 |

### H-DA-01 — Alto, abierto: correspondencia no equivale a autorización

`comprobar_cuerpo` sólo comprueba presencia, alineación exterior, Merkle y peso por tx
([cadena.rs:672](../../../crates/zx-node/src/cadena.rs#L672)).
Más importante: `validar_cuerpo` llama a `validar_tx`, pero **ninguna de estas dos APIs
integra `satisface`** en su recorrido actual
([bloque.rs:185](../../../crates/zx-consensus/src/bloque.rs#L185),
[validacion.rs:114](../../../crates/zx-consensus/src/validacion.rs#L114)).
El test de autorización demuestra que ambas admiten el fixture con firma inválida,
mientras [testigo.rs:71](../../../crates/zx-consensus/src/testigo.rs#L71) lo rechaza.
No debe derivarse un certificado `CompletoValido` de esos nombres de API.
Un noveno test compone explícitamente las APIs reales: recupera las salidas del UTXO,
recalcula cada sighash y verifica los testigos del fixture P2K/`HashType::All`.
Esta composición rechaza la firma mala sin cambiar el pasado y vive sólo en tests;
no resuelve selección/autenticación del contexto causal ni introduce un adaptador de consenso.

`txid` compromete efectos, no firmas; `auth_digest` distingue los testigos
([tx.rs:147](../../../crates/zx-core/src/preimage/tx.rs#L147),
[tx.rs:305](../../../crates/zx-core/src/preimage/tx.rs#L305), SPEC C-TX-01/C-BLK-01).
Por ello, antes de adaptar DA0 se necesitan al menos estas distinciones conceptuales:

- **Rechazo de entrega/autorización concreta:** bytes malformados, raíz ajena, firma mala.
  No implica invalidar permanentemente la cabecera ni todas sus autorizaciones posibles.
- **Dependencia pendiente:** falta cuerpo o contexto necesario; no equivale a prueba de invalidez.
- **Invalidez de contenido comprometido:** requiere evidencia sobre el contenido realmente
  comprometido y la regla/contexto aplicable, no sólo un fallo de descarga o testigo sustituible.
- **Conflicto de ejecución contextual:** requiere un pasado completo y su regla DAG;
  no se deduce simplemente de `buscar(outpoint)==None`.

Estas distinciones refinan la entrada al modelo, no cambian por sí solas el contrato M0.
Una futura caché de autorización necesita la entrada completa y el contexto relevante;
ni txid ni blockhash solos identifican el testigo verificado.

### H-DA-02 — Alto, abierto: reemplazo por blockhash sin preservar autorización verificada

`guardar_bloque` serializa después de C-NET-23 y escribe por blockhash
([cadena.rs:444](../../../crates/zx-node/src/cadena.rs#L444)). En memoria, `insert`
reemplaza el valor ([memoria.rs:86](../../../crates/zx-storage/src/memoria.rs#L86)).
El test demuestra **mala→buena repara** y **buena→mala degrada**, con idéntica cabecera.
El backend disco también usa `put_cf` por hash
([disco.rs:166](../../../crates/zx-storage/src/disco.rs#L166)); esto se revisó por lectura,
no se ejecutó una prueba RocksDB.

La ruta de red exige previamente cabecera conocida, pero guarda sin puerta de autorización
([nodo.rs:173](../../../crates/zx-node/src/nodo.rs#L173)). Este documento no atribuye al
test directo una prueba de explotación de red. Falta definir conservación/reparación de
autorizaciones y protección de recursos; no se recomienda almacenar copias ilimitadas.

### H-DA-03 — Medio, abierto: ausencia, corrupción y contexto incompleto

`Cadena::bloque` transforma ausencia/error/decodificación fallida en `None`
([cadena.rs:484](../../../crates/zx-node/src/cadena.rs#L484)); `cuerpos_que_faltan`
consulta existencia de bytes, no autorización ni decodificación
([cadena.rs:463](../../../crates/zx-node/src/cadena.rs#L463)).
No existe aquí una clasificación completa `Pending / entrega rechazada / validado`.
Igualmente, la búsqueda UTXO no informa si el estado es incompleto, si hubo un gasto previo
o si la referencia nunca existió. Son necesarios contexto identificado y su completitud.

### H-DA-04 — Abierto: M0 no sustituye las reglas de cuerpo ni la capa blindada

El doble gasto **dentro del mismo cuerpo** incumple C-BLK-09 y se rechaza por el validador
actual. No es el conflicto entre cuerpos/mergesets que un modelo DAG podría resolver
sin invalidar el cuerpo originario. Separar validación en el pasado causal de B y ejecución
en el contexto C requiere reglas y adaptación explícitas; estas pruebas no las adoptan.

SPEC §9 declara Orchard pendiente. No hay en esta superficie un cuerpo blindado ZEROX
integrado que permita probar autorización, nullifiers, anclas y disponibilidad completos.
La dependencia o las investigaciones Orchard no equivalen a esa integración.
Tampoco se ha probado publicación atómica de ledger de billetes + UTXO + blindado +
recuento/emisión/contexto ni el requisito DA0 de todos los cuerpos, incluidos perdedores.

## Reproducción y recursos

```bash
/usr/bin/time -v timeout 600s cargo test --offline --locked -j 2 -p zx-node --test disponibilidad_real
```

Resultado ejecutado: **9 passed, 0 failed**, tests 0,01 s; ejecución final incremental
0,46 s de pared; RSS máximo informado por `time`: 693556 KiB. No es benchmark ni medida
agregada de toda la máquina; 4 GiB era el presupuesto, no se instaló un límite cgroup.
La primera compilación de siete tests tardó 5,98 s; después pasaron ocho y finalmente nueve.
Sin aleatoriedad: clave y fixtures fijos; sin cálculos probabilísticos ni tolerancias numéricas.
Compromisos y veredictos se cotejan exactamente. No se reclama optimización de rendimiento.

Control estático adicional: el primer pase de Clippy del agente principal detectó advertencias
por `unwrap`/`expect`, índices deliberados del fixture y un patrón con campos sobre una variante
unitaria. Se corrigió el patrón y se añadieron `#[expect(..., reason = ...)]` exclusivamente en
este instrumento para los panics de test y accesos de fixtures conocidos, siguiendo el patrón
local. No se modificaron lints ni validadores de producción. Verificación posterior:

```bash
rustfmt --check --edition 2024 crates/zx-node/tests/disponibilidad_real.rs
timeout 600s cargo clippy --offline --locked -j 2 -p zx-node --test disponibilidad_real -- -D warnings
```

Ambos terminaron con código 0; Clippy sin advertencias. Los nueve tests se volvieron a ejecutar
y pasaron después de esta corrección, sin cambios en sus casos ni veredictos.

Entorno existente: `rustc 1.97.0-nightly (20de910db 2026-05-02)`,
`cargo 1.97.0-nightly (4f9b52075 2026-05-01)`, `Cargo.lock` del workspace, modo offline/locked.
HEAD de referencia `7b783d469fbae5722a0ae014b5e212ed6999eb2b`, con cambios de trabajo
preexistentes y concurrentes preservados; HEAD solo no contiene estos tests nuevos.
Se registra la nightly existente, no se declara una validación de release estable.
