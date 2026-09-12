# Verificación independiente: identidad, copias y contabilidad del DAG

Fecha: 2026-09-11. Categoría: **consenso**, porque se revisan identidad, orden y estado;
criptografía, economía y almacenamiento son ámbitos secundarios.

## Alcance y resultado

Se contrastan las conclusiones aportadas por otro agente contra fuentes primarias. Sus porcentajes
de confianza y las etiquetas de informes históricos no se usan como evidencia. Participaron
especialistas independientes en Rust, matemáticas/Julia y C++; el principal releyó las rutas
decisivas y ejecutó el test de firmas.

**Resultado:** primer representante elegible canónico + registro contextual es una arquitectura
coherente para unicidad contable, condicionada a cerrar identidad y elegibilidad. No es la única
política determinista posible ni una mejora global demostrada. Se confirma un contraejemplo
estructural entre fusiones y se encuentra un error adicional en el argumento anti-grinding del
SPEC: un firmador Ed25519 determinista no implica una única firma aceptada por el verificador.

Esta revisión contiene lectura de código, argumentos simbólicos y un test Rust del verificador
existente. **No contiene simulación Julia, cotas nuevas de riesgo, benchmarks de finalidad ni una
ejecución PoST+DAG completa.** Se leyó íntegramente `veritas/LINEO.md`; no se creó ni ejecutó Python.
El test Rust se conserva junto a su crate. No se modificaron el SPEC, reglas de consenso,
dependencias ni implementaciones de producción.

## Versiones y procedencia

- ZEROX HEAD: `7b783d469fbae5722a0ae014b5e212ed6999eb2b`, con cambios locales preexistentes.
- Autonomys: `PDF/autonomys-subspace`, commit `f8842d019cdf0f7163421b9644db5a9ff82b2a73`.
- Kaspa: `/home/katana/zeo/fuentes/rusty-kaspa`, commit `c338d495bec29e4dc8b5149f99e8db6fa916ed4a`.
- Verificador probado: `zx-core::firma::verificar`, `ed25519-zebra = 4.2.0`, dependencias del lock local.
- Rust: `1.97.0-nightly (20de910db 2026-05-02)`, toolchain fijado `nightly-2026-05-03`.
  Es el toolchain del proyecto, no una elección de versión Julia para una auditoría numérica.

SHA-256 de los documentos y código consultados al verificar:

```text
2d1d5453fcf79281c49cd9e19ea7f299819bba93465f93dceb84e95602c1b5de  SPEC.md
ef284ca3ad699387d57202dca0a9279a238f9c6f7e2c2100401d23dce41d28e8  research/dag-poas-ancla-de-orden.md
e025e220f1d1ad3ccfdd468802e78976ab4fb3f458f997569d6911e2beeb8990  veritas/finalidad/baseline-30m/MODELO.md
afcf356a89ea9cbf92969de8df6b7ac57df5c4f55ef62e0a934f2a19bba205b3  crates/zx-core/src/firma.rs
b7a36aacb1bc477e223d8ee0a8a36d2f2fffd74276bb4c324c79ead96c9cb763  crates/zx-core/tests/ed25519_no_unicidad.rs
```

## Matriz de conclusiones

| Afirmación revisada | Veredicto y alcance |
|---|---|
| La laguna de unicidad está declarada | Confirmado por lectura: SPEC §7.2 y ancla:368–373. Declarar una laguna no demuestra un exploit completo. |
| «Adjudicación» ya es regla vigente | No. `rg -ni 'adjudicaci' SPEC.md research/` no encuentra coincidencias en el corte leído. El nombre de una propuesta no la invalida ni la convierte en regla. |
| U2 elimina una copia paralela incorporada después | Falso: comprueba el pasado causal de la copia, no su momento de fusión. |
| Roja primero, azul después es alcanzable | Demostrado en el submodelo estructural de §1; validez integral PoST pendiente. |
| Prioridad azul no es implementable | Falso como afirmación general. Puede definirse dentro del lote conocido; no garantiza preferencia sobre azules futuros. |
| Primera elegible + registro asegura unicidad | Demostrado por inducción bajo las hipótesis de §2; no prueba convergencia ni finalidad. |
| Sólo el publicador de copias puede resultar perjudicado | No demostrado. Autenticación del firmante no prueba ausencia de efectos sobre terceros ni corrección de la identidad. |
| Un bucket equivale a un billete | No es el contrato del generador Autonomys: examina varios chunks/piezas candidatos (§3). |
| Añadir `piece_offset` resuelve toda la identidad | No demostrado; tiene fundamento, pero no cierra multiplicidad de pruebas/contextos. |
| Ed25519 determinista impide variar el sello bajo el mismo mensaje | Refutado por ecuación de verificación y test Rust ejecutado (§4). |
| Kaspa paga subsidio a rojos non-DAA sin contarlos | Refutado por código: en esa rama sólo transfiere comisiones (§5). |
| Encontrar un WriteBatch demuestra atomicidad global | No. Hay que delimitar la operación y sus consumidores; Kaspa tiene varios lotes contextualizados (§6). |
| ZEROX sólo guarda cabeceras/alturas/punta | Falso: también hay cuerpos, UTXO y deltas/undo. La integración DAG sigue pendiente. |
| F y tardíos acotados bastan para olvidar identidades | No demostrado; faltan las condiciones de irrelevancia futura (§7). |
| La arquitectura mejora seguridad, rendimiento y tiempo de finalidad | No demostrado por esta revisión. No se asigna un porcentaje de confianza como sustituto de una cota. |

## 1. Contraejemplo estructural entre fusiones

Modelo: GHOSTDAG con pesos propios positivos `w(X)>0`, U2/U3″ destino y un prefijo lineal que
termina en P. Todas las identidades son distintas salvo A/B. `k>=2` es una condición algebraica;
`k=30` es el escenario nominal de investigación, no un parámetro medido aquí.

```text
parents(H_1) = {P}
parents(H_i) = {H_(i-1)}       para i=2,...,k+1
parents(A)   = {P}
parents(B)   = {H_(k+1)}      identidad(B)=identidad(A)
parents(C_A) = {H_(k+1), A}
parents(D)   = {C_A}
parents(C_B) = {D, B}
```

A y B no tienen padres idénticos, pero sí son incomparables causalmente. Denotando H=H_(k+1):

1. C_A selecciona H. A tiene k+1 azules H_i en anticono: queda roja_k.
2. `BW(B)=BW(C_A)=BW(H)+w(H)`, porque B tiene padre único H y A no aporta peso azul a C_A.
3. `BW(D)=BW(C_A)+w(C_A)>BW(B)`: C_B selecciona D sin recurrir al desempate.
4. B tiene exactamente C_A y D en su anticono azul. Cada uno pasa de cero a un compañero azul
   en anticono. Ambas condiciones k-cluster se cumplen para k>=2: B queda azul.
5. A no está en `past(B)`. U2 no invalida B. A nunca fue azul en el contexto heredado, por lo
   que U3″ tampoco excluye B.

Fuentes primarias Kaspa: `consensus/src/processes/ghostdag/protocol.rs:99–105,137–161,193–217`;
el seleccionado se incluye inicialmente en los azules en `model/stores/ghostdag.rs:95–107`.
Fuente de U2/U3″: [ancla de orden](../../../research/dag-poas-ancla-de-orden.md), líneas 227–232.

Con R-FIN-8′, A se aplica en C_A; B, posteriormente en C_B. Un registro de primera adjudicación
suprimiría el segundo subsidio aunque B sea azul. No debe confundirse el conjunto pagable con
el conjunto que aporta blue_work: el propio SPEC §7.2 los distingue.

### Restricciones verificadas y frontera pendiente

Para k=30 se puede asignar, como **vector estructural elegido** en índices de slot:
P=0, H_i=i, A=B=32, C_A=33, D=34, C_B=35. Cumple monotonicidad no estricta y salto del padre
seleccionado <=150 del perfil nominal. No convierte slots en segundos medidos. Hay como máximo
dos padres y mergesets de dos elementos contando el seleccionado, por debajo de 15/180.

El único rojo nuevo es A. El control de merge depth lo admite si la raíz de merge de C_A es P
o un ancestro de P (`header_processor/post_pow_validation.rs:79–95`). No se ha fijado aquí una
profundidad nueva para forzarlo.

**Pendiente:** una solución compartida válida bajo los contextos de rango de A/B, flujo común,
historia/pieza/KZG, firmas y cuerpos, disponibilidad, y las justificaciones PoT del slot futuro
exigido por autoría. No se inventan I/L ni se interpreta como resuelta la integración pendiente.
Por eso esta construcción no se etiqueta como ejecución integral válida ni ataque medido.

## 2. Unicidad demostrable y alternativa determinista

Para cada historia candidata se parte de un registro exacto del prefijo. Cada transición sólo
adjudica una identidad ausente y la inserta; toda aparición posterior encuentra la identidad
presente. Por inducción, hay como máximo una adjudicación por identidad en esa historia.
Al reorganizar hay que revertir/reconstruir tanto el registro como los efectos asociados.

Hipótesis necesarias: identidad justificada, elegibilidad definida, orden canónico total,
actualización coherente y conservación del estado heredado. Se puede consumir aun cuando el
subsidio efectivo sea cero, pero eso es una política propuesta que debe especificarse; no una
regla vigente deducida de la firma. `x=2M` produce subsidio cero por C-EMIT-06.

La misma inducción vale para una política que elija a lo sumo un representante por identidad
dentro del mergeset completo, prefiera azul y respete adjudicaciones heredadas. No es necesario
conocer azules futuros para definir esa alternativa.

Caso que distingue ambas políticas: conservar P, H_i, A y B del ejemplo; añadir Q_1 con padre H,
Q_2 con padre Q_1 y C con padres `{Q_2,A,B}`. C selecciona Q_2 estrictamente. A precede a B por
blue_work y queda roja_k; B sólo tiene Q_1/Q_2 en anticono azul y queda azul. Sin consumo heredado,
primera elegible elige A; prioridad azul intralote elige B. Son reglas distintas y deterministas
en el mismo submodelo. No se ha probado cuál mejora la finalidad o los incentivos.

Mantener cuerpos de perdedores es otro eje: conservar los de rojo_k puede cambiar menos texto;
ejecutar también rojo_U3 revierte su inertización explícita en R-FIN-8′. En cualquier opción,
hay que definir comisiones, conflictos transparentes/blindados y presupuesto de procesamiento.
La firma autentica al productor; no limita los costes de sus payloads a ese productor.

## 3. Identidad: comprobación directa de Autonomys

Las rutas de esta sección son relativas a `PDF/autonomys-subspace`.

- `subspace-farmer-components/src/auditing.rs:203–210,236–270` deriva el bucket del reto y examina
  sus chunks; recoge todos los candidatos dentro del rango.
- `subspace-farmer-components/src/proving.rs:393–407` relaciona posiciones candidatas con
  `piece_offset` y filtra chunks codificados. Distintas piezas no deben identificarse simplemente
  por pertenecer al mismo bucket.
- `pallet-subspace/src/lib.rs:1591–1633` usa exactamente
  `(public_key, sector_index, piece_offset, chunk, slot)` en su deduplicación de autorías/votos
  actual/anterior. No incluye history_size, pero eso no autoriza eliminarlo del diseño ZEROX:
  `subspace-verification/src/lib.rs:228–243` lo usa al derivar el sector.

Estas rutas están bajo `crates/`. La corrección sobre piece_offset queda confirmada: participa
en la semilla PoS; la distancia recibe el reto global, el reto de sector y
`chunk XOR hash(proof_of_space)` (`subspace-verification/src/lib.rs:240–252`).

### Hallazgo adicional: primera prueba generada no equivale a única prueba aceptable

`crates/subspace-proof-of-space/src/chia.rs:58–64` llama a un iterador y toma `.next()`.
El iterador `chiapos/tables.rs:191–219` enumera entradas T7 que coinciden con el prefijo del reto.
El verificador `:296–351` comprueba la prueba presentada y ese prefijo; no exige que sea la primera
entrada, la mínima, ni el resultado del generador.

El test upstream `chiapos/tables/tests.rs:175–178` documenta que cambiar un desempate eligió otra
prueba para el reto 1011; `:280–307` verifica todas las pruebas enumeradas en su barrido. **Estos
tests no se ejecutaron aquí y no contienen una aserción específica de multiplicidad >=2.**

Queda probado por lectura que selección del generador y aceptación son contratos diferentes.
No se presenta una pareja nueva de pruebas PoS revalidada ni dos soluciones PoAS completas
ganadoras para el mismo contexto. PoAS añade KZG, rango, pieza histórica y expiración
(`subspace-verification/src/lib.rs:262–346`). Cambiar la prueba puede cambiar la distancia;
ser una PoS válida no basta para ser una solución ganadora.

Conclusión: piece_offset es candidato fundamentado; no cierra por sí solo la equivalencia de
oportunidades ni la multiplicidad dentro de una misma semilla. Añadir proof_hash sin justificarlo
podría convertir variantes de una misma oportunidad en identidades distintas. No se congela tupla.

## 4. Contraejemplo ejecutado: Ed25519 determinista no impone unicidad

[SPEC.md](../../../SPEC.md), líneas 888–891, extrapola del algoritmo determinista de firma que
el productor no puede variar el sello manteniendo el mensaje. Esa inferencia es falsa bajo el
verificador exigido en C-HDR-04.

Sean una clave ordinaria A=aG, un mensaje M fijo y el orden primo ell. Para cada nonce r:

```text
R = rG
h = SHA512(enc(R) || enc(A) || M) mod ell
S = (r + h*a) mod ell
```

Se satisface SG=R+hA, y por tanto la ecuación cofactored de ZIP-215. El verificador no conoce
el prefijo secreto ni exige r=SHA512(prefix||M). Esta deducción se sigue de
[RFC 8032 §5.1.6–5.1.7](https://www.rfc-editor.org/rfc/rfc8032.html#section-5.1.7) y
[ZIP-215](https://zips.z.cash/zip-0215), y concuerda con `zx-core/src/firma.rs:82–88`.

Se generaron dos firmas con las primitivas ya disponibles de curve25519-dalek 4.1.3 y sha2 0.10.9,
y se comprobaron con el verificador real de ZEROX. No se reimplementaron curvas ni hashes.
Entradas reproducibles del generador de vectores (no firmador de producción):

- semilla Ed25519: 32 bytes 0x42, pública y exclusiva de prueba;
- M: 32 bytes 0x5a;
- a: mitad inicial SHA512(semilla), clamp estándar y reducción módulo ell;
- r_i: SHA512(semilla || etiqueta_i || M), interpretado little-endian y reducido módulo ell;
- etiquetas ASCII: `nonce-de-prueba-1`, `nonce-de-prueba-2`.

Los bytes de clave y ambas firmas se conservan en
[el test Rust](../../../crates/zx-core/tests/ed25519_no_unicidad.rs). El test verifica:

1. La clave coincide con la generada por SigningKey normal de Zebra.
2. La firma estándar repetida sigue siendo idéntica.
3. Las dos firmas alternativas son distintas entre sí y de la estándar.
4. Ambas alternativas son aceptadas con la misma clave y mensaje.
5. Ambas se rechazan al cambiar el mensaje o la clave.

Resultado ejecutado: **correcto**. C-HDR-09 incluye el sello en block_hash: el propietario puede
variar esa preimagen sin variar solución, padres ni cuerpo. No es falsificación de firmas ajenas,
no es un fallo de Ed25519 y no acredita dos bloques DAG completos. La ventaja de consenso requiere
que el hash decida un empate alcanzable; no se ha medido ese efecto ni se afirma coste CPU cero.

## 5. Kaspa: subsidio, comisiones y DAA son conceptos distintos

Fuente: copia y commit Kaspa declarados arriba.

- `consensus/src/processes/difficulty.rs:137–163`: la exclusión non-DAA compara el blue_score del
  bloque con el umbral contextual `max(score_contexto,W_full)-W_full`, donde
  `W_full=window_size*sample_rate`.
- `window.rs:304–318`: un bloque elegible no seleccionado para la muestra retorna None, no NonDaa.
- `difficulty.rs:27–29`: incremento DAA = tamaño del mergeset menos excluidos non-DAA.
- `coinbase.rs:109–113`: excluye azules non-DAA de esas salidas.
- `coinbase.rs:121–131`: rojo non-DAA aporta sólo comisiones; el rojo elegible, subsidio más
  comisiones. El agregado se paga al fusionador, no al productor rojo.

Por tanto, no se puede describir esa rama como acuñación de subsidio sin trabajo contado ni
equiparar non-DAA a llegada tarde o ausencia de la muestra. Tampoco se portan estos criterios
a ZEROX automáticamente.

El contrato ZEROX debe distinguir consumo de billete, elegibilidad de subsidio, observación del
retarget y redistribución de comisiones. Una salida monetaria positiva no es una definición
adecuada de N_obs; tampoco un subsidio cero equivale a ausencia de oportunidad consumida.

## 6. Persistencia: lo existente y lo que no prueba

Kaspa `virtual_processor/processor.rs:503–531` agrupa en un batch diff, multiset, aceptación,
muestra de poda, SMT cuando corresponde y estado UTXO válido. Pero el procesador de cabeceras
persiste GHOSTDAG/exclusión DAA/cabecera/profundidad en otro batch (`header_processor/processor.rs:350–367`),
y el estado virtual/cadena seleccionada en otro (`virtual_processor/processor.rs:924–949`).
No se ha auditado durabilidad/WAL ni toda la recuperación: un batch no demuestra atomicidad global.

ZEROX `crates/zx-storage/src/disco.rs:166–174` guarda cuerpos; `:229–268` agrupa cabeceras/alturas/punta;
`:282–324` finaliza UTXO y su marcador en otro batch. `utxo.rs:37–63` contiene undo y delta.
No existe por ello prueba de integración del estado DAG, identidades, ejecución blindada y retarget.

Diferencia adicional comprobada por lectura: C-REORG-02 exige comparar las salidas creadas con el
contenido esperado; `revertir_bloque` (`utxo.rs:238–247`) sólo comprueba que puede retirarlas por
outpoint y `UndoData.creados` sólo guarda outpoints. No se implementó un arreglo en esta revisión.

## 7. Poda y autocausación: límites de las garantías

Para olvidar una identidad sin conservar información equivalente debe probarse que el olvido no
cambia ninguna decisión de validez, coloración, recompensa, retarget o reconstrucción en ninguna
continuación admitida. Un slot antiguo o una frontera local F no establecen esa equivalencia.

Una ventana de admisión puede ayudar si cubre todos esos usos, pero no se declara suficiente sin
demostrarlo. Tampoco «sin ventana no hay poda» es universal: pueden eliminarse cuerpos que ya no
se necesitan y conservar el registro exacto y las pruebas/metadatos requeridos. Eso no demuestra
un ledger acotado. Poda de cuerpos, compactación exacta y olvido semántico son operaciones distintas.

La firma limita quién puede crear otra cabecera autenticada bajo una clave honesta bien generada;
no prueba que el coste total de las copias sea autocausado. Terceros pueden retransmitir firmas
existentes, y los cuerpos consumen recursos o afectan a transacciones de otros. También hay que
excluir que la identidad agrupe derechos legítimos distintos. No se afirma un ataque nuevo contra
un granjero honesto: se rechaza una garantía general que no se deduce de la autenticación.

## 8. Comprobaciones ejecutadas y decisiones no tomadas

```bash
cargo test --offline --locked -j 2 -p zx-core firma::tests::la_firma_es_determinista -- --exact
cargo test --offline --locked -j 2 -p zx-core --test ed25519_no_unicidad
cargo test --offline --locked -j 2 -p zx-core
cargo clippy --offline --locked -j 2 -p zx-core --test ed25519_no_unicidad -- -D warnings
rustfmt --edition 2024 --check crates/zx-core/tests/ed25519_no_unicidad.rs
git diff --check
```

La suite del crate pasó: 104 tests unitarios, 4 tests SHA3 y 1 regresión nueva; ninguno falló ni
se ignoró. Clippy del nuevo test y la comprobación de formato también pasaron. Esto verifica el
código existente, con componentes heredados, no el consenso PoST+DAG.
No se publican tiempos de ejecución como benchmark. No se ejecutaron tests Autonomys/Kaspa,
pruebas de fallo de disco, simulaciones Julia ni cálculos de riesgo.

Próximos cierres necesarios, sin adoptar reglas aquí:

1. Definir y justificar equivalencia de oportunidad económica, incluidos pieza, prueba y reto.
2. Comparar representante primero vs prioridad azul intralote con consumo heredado; explicitar
   cuerpo perdedor, comisiones y retención. No usar unicidad de sello como defensa anti-grinding.
3. Fijar conjunto/ventana de observación y política de tardíos sin mezclar subsidio con comisiones.
4. Integrar deltas/rollback/versiones y justificar poda antes de tratar la contabilidad como cerrada.
5. Sólo entonces comparar seguridad, rendimiento y tiempo de aceptación de Cortex bajo el mismo
   adversario y riesgo. Esta revisión no justifica adoptar ni descartar una familia de finalidad.
