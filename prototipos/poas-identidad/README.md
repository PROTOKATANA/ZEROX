# Identidad PoAS: harness aislado con verificador real

No activa consenso ni modifica el workspace ZEROX. Fuente de las APIs:
`PDF/autonomys-subspace`, commit `f8842d019cdf0f7163421b9644db5a9ff82b2a73`.
El `Cargo.lock` propio fija la resolución offline de sus dependencias; no se afirma
que reproduzca byte a byte el lock del workspace upstream. Usa el nightly ya
fijado por ZEROX, K=20 real y `full-chiapos` para enumerar pruebas; no usa la
característica `testing` ni un verificador simulado.

## Reproducción

Desde ZEROX, con dependencias cacheadas:

```sh
env POAS_GUARDAR_FIXTURE=1 cargo test --offline --locked -j 2 --manifest-path prototipos/poas-identidad/Cargo.toml -- --nocapture --test-threads=1
sha256sum prototipos/poas-identidad/resultados/fixture.txt prototipos/poas-identidad/Cargo.lock prototipos/poas-identidad/tests/identidad_real.rs
```

Presupuesto declarado: 20 minutos, 8 GiB RAM, 8 GiB disco, dos trabajos. Son
límites del encargo, no una garantía de consumo impuesta por este ejecutable.

## Qué comprueba

Genera pruebas PoS con tablas Chia reales y llama a
`verify_solution::<ChiaTable, _>` con `piece_check_params: Some(...)`: PoS, rango,
vínculo chunk/record y record/segmento, límites de offset, historia y caducidad.
Los controles negativos exigen el error concreto para no confundir un rechazo
temprano PoS con el ejercicio de un control posterior.

Para un mismo slot y bucket, dos offsets distintos tienen el mismo chunk y dos
pruebas distintas de una misma pieza son aceptadas. La igualdad de esta última
pareja se comprueba campo a campo mediante `Solution::eq`, tras sustituir sólo
`proof_of_space`. Un rango común `2 * min(distancias)`, calculado con overflow
comprobado, acepta una y rechaza la otra. No mide la ventaja alcanzable antes de
un deadline ni certifica una identidad económica alternativa.

La clave de investigación `(pk, sector_index, history_size, chunk, slot)` colapsa estas tres
soluciones aceptadas. Añadir `piece_offset` separa los dos offsets, pero no las dos
PoS de la misma pieza. Esto exige decidir la equivalencia y elegibilidad en el
contrato; no implica adoptar un hash de prueba como TicketId.

## Frontera de confianza de la fixture

Contexto **sintético**, recibido como input: record constante y segmento formado
por compromisos repetidos, ambos construidos con KZG genuino. No se demuestra
que este segmento sea una historia alcanzable por Archiver o ZEROX, ni se
construye un sector físico. `solution_range = u64::MAX` es sólo el perfil
permisivo del test, nunca un parámetro recomendado de producción.

Semilla de clave pública: `[0x42; 32]`, cuya clave Ed25519 ordinaria está fijada
en el test separado `crates/zx-core/tests/ed25519_no_unicidad.rs`. El PoT recibido
es `[0x35; 16]`; este harness no verifica su cadena de generación. No valida
firmas, cabeceras, recompensa, cuerpo, disponibilidad, DAG ni orden económico.

Parámetros explícitos de fixture: `sector_index=7`, historia=3, máximo de piezas=2,
historia reciente=5, fracción reciente=1/10 y vida mínima=4. Estos últimos valores
pequeños siguen el contexto de pruebas de piezas upstream, no la configuración
de producción. El escalar de record es `[0x17; 31]`. No hay RNG: búsqueda fijada
en slots 1..=4096, con resultado esperado slot=4 y bucket=22412. Un cambio de ese
resultado falla: no se acepta regeneración silenciosa.
