# Arranque del nuevo ZEROX híbrido — qué heredar y en qué orden

**Fecha:** 2026-09-25. **Estado:** plan técnico, no especificación de consenso.

## 1. Identidad del proyecto y punto de partida

El protocolo propuesto tiene dos fases: **PoW temporal de emisión** y después
**PoAS + PoT + DAG con garantía y obligaciones verificables de sectores**.
Es un consenso híbrido nuevo. «PoSpace-Time» sigue nombrando un componente de
la fase posterior, pero ya no describe por sí solo el protocolo completo.
«PoStake» aquí significa garantía y penalización por faltas demostrables;
no se le asignan turnos, votos de finalidad ni multiplicadores de `blue_work`.
El registro inspirado en Filecoin está aún en investigación, no forma parte
de una regla ratificada.

El árbol de trabajo nuevo tiene 4.659 rutas versionadas eliminadas y unos
pocos documentos nuevos; el código anterior está en
`/home/katana/zeo/.trash/zerox/` y en el commit `9681061`. La carpeta
`.trash/zerox` no es un repositorio Git. Se comprobaron los blobs de nueve
archivos clave (códec DAG, tx, PoAS, GHOSTDAG, firmante, primer hijo dev,
UTXO, PoT y test PoAS): sus hashes coinciden con `9681061`. Eso no
certifica todos los archivos. Antes de portar una pieza, fijar su hash,
revisión, dependencias y licencia. No restaurar el árbol entero sobre el
proyecto nuevo por accidente; trabajar con un checkout aislado de la versión
antigua y portar piezas elegidas.

`D-ZRX/SPEC.md` es una propuesta POS2T no normativa. Fija el reparto
PoAS/PoT frente a stake y plantea PoW temporal, pero deja sin cerrar
algoritmo/dificultad PoW, duración, emisión, corte, ancla PoT, historia PoAS,
depósitos y parámetros de garantía. `P-ZRX/P-REGISTRO-SECTORES/` estudia el
tercer conjunto de mecanismos. Ninguno de estos textos demuestra un nodo
híbrido ejecutable.

## 2. Inventario de reutilización

«Portar» exige compilar en el nuevo árbol, conservar sus vectores y revisar
la interfaz con la nueva especificación. Un test antiguo que pasa solo
demuestra su contrato antiguo.

| Pieza antigua | Clasificación | Uso inicial y límite |
|---|---|---|
| `zx-core`: SHA3/BLAKE3, firmas, codificación, tx, Merkle, importes | Portar si el formato monetario se conserva | Los vectores criptográficos y de serialización son una base útil; nuevas operaciones de stake/sector requieren nuevos tipos y dominios |
| `zx-core::target`, `preimage/block`, `zx-consensus::dificultad`, `bloque`, `fork_choice` | Adaptar para la fase PoW | Hay verificación PoW, target y LWMA lineales. El algoritmo de hash, el target inicial, el retarget y sus constantes pertenecen a la red vieja; el minero fue retirado. No activar sin especificación y mediciones nuevas |
| `/home/katana/zeo/.trash/caliza/` y `/home/katana/zeo/.trash/silicio/` | Auditar como prototipos SHA3 PoW | **Sí existen** fuera de `.trash/zerox`. `caliza` contiene un kernel HIP/CUDA y `silicio` un bucle Rust. No siguen el formato/target del verificador PoW actual y carecen de un test diferencial y de integración demostrado; ver nota siguiente |
| `zx-pot` y adaptadores PoT | Portar la primitiva; rehacer contexto | 32 vectores diferenciales prueban bytes de la primitiva. El flujo, `N(s)`, ancla y reto del primer bloque posterior al corte deben derivarse del historial PoW elegido |
| PoAS/Autonomys, `zx-consensus::poas`, `zx-node::farmer` y `productor_poas` | Portar como línea base y prototipo | El plotter y el verificador reales sirven para comparar diseños. El formato actual prueba una pieza, no alta o permanencia del sector completo; un formato nuevo puede requerir replot y cambiar los vectores |
| `zx-core::preimage::dag`, `wire_dag`, `zx-consensus::ghostdag` | Adaptar tras fijar el formato posterior al corte | Hay códec canónico y oráculo GHOSTDAG; el almacén GHOSTDAG sigue en memoria, con coste e integración causal pendientes. La ruta activa del nodo antiguo seguía lineal |
| `zx-storage::utxo`, almacén y undo; `zx-consensus::validacion` | Portar primitivas, rediseñar proyección | Conservación monetaria y rollback son reutilizables. Faltan estado seleccionado DAG, saldos de garantía, registro de sectores, obligaciones, liquidaciones y undo de todo ello |
| `zx-consensus::firmante` | Adaptar pronto | Registro durable contra doble firma accidental. Debe ligarse a la identidad final de oportunidad y ser la única ruta de firma del productor; no atrapa una rama privada ni un pool que obtiene firmas ciegas |
| `zx-p2p`, `zx-rpc`, `zx-wallet`, `zx-scanner` | Infraestructura potencial | Reutilizar transporte y servicios después de fijar mensajes y reglas de validación. Los mensajes actuales no propagan bloques/altas/pruebas del híbrido completos; las capas wallet/privacidad no fijan consenso |
| `zx-node::cadena`, `contextual`, `sync`, `nodo` | Referencia de ingeniería | Acoplan cabecera y sincronización lineales. No convertirlos en nodo híbrido cambiando solo un enum o un parámetro |

Fuente del estado de integración: `MIGRACION.md`,
`P-ZRX/PIEZAS-DE-CODIGO/HOJA-DE-RUTA.md` y
`P-ZRX/PIEZAS-DE-CODIGO/PROGRESO-0.0.1.md` del archivo antiguo.
El último progreso distingue explícitamente pruebas dev del primer hijo
de admisión, publicación, sincronización y orden DAG activos.
El clon `PDF/autonomys-subspace` está fijado a `f8842d0` y el árbol antiguo
usa `nightly-2026-05-03` por sus features inestables. `Cargo.lock`, el clon
y esa toolchain forman una unidad reproducible para evaluar el formato viejo;
copiar solo un crate sin sus versiones no reproduce las pruebas.

**Corrección de inventario PoW.** `MIGRACION.md` decía que se retiraron
`caliza/` y `silicio/` del workspace; el usuario conservó sus fuentes en
`.trash/` como carpetas hermanas de `zerox/`. Inspección inicial:
`silicio/Cargo.toml` solo declara el paquete, `main.rs` imprime un saludo y
`minero.rs` calcula hashes sin comparación/entrega activa del resultado;
`caliza/CMakeLists.txt` requiere `caxor/proto` ausente de esa carpeta y su
kernel inserta nonce en bytes 48–55 y acepta ceros iniciales, mientras el
verificador conservado usa una preimagen canónica de 108 B con nonce en
96–103 y comparación estricta contra target compacto. No se compiló ni
probó ninguno de los dos. Su posible reutilización es **condicional**:
primero un test diferencial byte a byte contra `zx-core` para SHA3,
preimagen, nonce, endianness y target; luego búsqueda concurrente,
cancelación y reinicio, y finalmente medición de rendimiento. El núcleo
GPU puede servir como fuente de ideas, no como minero válido sin esas pruebas.

## 3. Qué pruebas y cifras sobreviven

| Evidencia antigua | Se puede usar para | No se puede concluir |
|---|---|---|
| Vectores CAVP SHA3, firma y códec de tx; 32 vectores `zx-pot` | Regresión byte a byte de primitivas conservadas | Seguridad del protocolo híbrido |
| `vectores_dag`, oráculos y property tests GHOSTDAG | Regresión del códec y algoritmo bajo sus entradas | Admisión contextual, convergencia de red o efecto de stake/sectores |
| Tests PoAS y `farmer_disco` | Que la solución/pieza actual se genera y verifica; fixture real para la comparación R0 | Prueba de sector completo, antigüedad o retención |
| Tests UTXO/undo y firmante | Invariantes locales portables como diseño de pruebas | Undo del registro, bond, slashing o evidencia en el DAG nuevo |
| `puerta_primer_hijo_dag_dev` | Fixture valioso PoT + PoAS + sello + cuerpo y UTXO local | Bloque admitido o difundido en producción; PoW→PoST real |
| `tres_nodos` | Diseño de un arnés MemoryTransport | Testnet híbrida: cuatro pruebas del hito están ignoradas |
| Identidades matemáticas, formatos y tamaños derivados | Recalcular bajo el mismo algoritmo y los mismos bytes | Que una constante antigua sea parámetro válido para la red nueva |
| Benchmarks PoAS/PoT y simulaciones de ataques | Hipótesis iniciales y comparadores con procedencia | Cotas del adversario, latencia de red o riesgo de reversión nuevos |

No heredar como parámetros: `T=120 s`, `N=90` y target inicial del PoW
lineal; `k=30`, `S_max=150`, `F=2 h` provisional y ventanas PoT;
`N=200_032_000`/`SR=u64::MAX` del perfil dev; `12_000` de madurez,
`SHIFT=26` y cifras de emisión/capacidad; tasas de ploteo, adelanto y
porcentajes de ataque de investigaciones antiguas. Algunos son decisiones
del consenso anterior, otros escenarios o medidas de una máquina. Para
cada número: indicar unidad, definición, revisión, fuente, hardware/red,
adversario y condición de transferencia. Si cambia el formato, el incentivo,
la fase o el calendario, volver a derivar o medir.

## 4. Primer trabajo: contrato de transición, antes del portado grande

Redactar una página normativa provisional con estos invariantes y casos
de rechazo, dejando parámetros simbólicos:

1. Definir las familias de bloque: `PoW_bootstrap` y `PoAS_PoT_DAG`.
   Elegir si PoW será cadena lineal y cómo se selecciona su historia;
   el código antiguo solo implementa esa familia lineal. Ningún bloque
   PoW puede autorizar producción después del corte.
2. Definir emisión y madurez PoW, y desde qué bloque PoW se admiten
   depósitos y, si la prueba de alta lo permite, precompromisos de sector.
   Antes del primer bloque PoST debe existir garantía **madura** y espacio
   **elegible** de productores reales; una recompensa futura no es garantía.
3. Definir el bloque terminal/ancla y qué ocurre con dos ramas PoW
   competidoras, reorg tardío o fallo de activación. Separar altura PoW,
   slot PoT, orden DAG y tiempo real. El historial PoW elegido debe fijar
   la semilla PoT, el historial PoAS y la versión de estado inicial.
4. Resolver el calendario de plot/registro: si la parcela depende de
   aleatoriedad del terminal PoW, no puede estar lista antes de conocerla.
   Se necesita un ancla anterior suficientemente estable, una espera
   posterior al corte o un formato que permita preparar parte del trabajo
   antes. Comprobar seguridad frente al minero que sesga el ancla.
5. Mantener dos contadores separados: oportunidades y `blue_work`
   proceden de PoAS/PoT; stake y sectores crean obligaciones y elegibilidad.
   Definir qué prueba pública activa una sanción. No convertir ausencia de
   auditoría en slashing automático sin evaluar partición y censura.

**Salida de esta etapa:** tabla de transiciones y un oráculo pequeño que
rechace una historia con emisión insuficiente, bond inmaduro, sector
inactivo, ancla ambigua o prueba tardía. Un oráculo con pruebas simuladas
valida contabilidad y orden; no valida criptografía de sector ni seguridad
económica. No elegir `F`, duración PoW o depósito por intuición.

## 5. Orden recomendado de ejecución

| Etapa | Acción | Puerta de salida |
|---|---|---|
| 0 | Congelar arquitectura y contrato de transición del §4 | Dos nodos con la misma historia calculan fase, estado y ancla iguales; todas las variables no decididas quedan visibles |
| 1 | Checkout aislado del commit antiguo; inventario por archivo, hash, licencia y dependencia; ejecutar suites **acotadas** de primitivas | Baseline reproducible de código y tests, sin afirmar que es un nodo híbrido |
| 2 | Prototipo de transición PoW→PoST con datos pequeños, emisión, depósito, registro abstracto y rollback | Conservación monetaria, madurez, activación única, reorg/fallo y primer bloque posterior al corte ensayados |
| 3 | Cerrar PoW real y la seguridad del arranque; auditar `caliza`/`silicio`; ejecutar encargos 01–02 y 05 de sector y modelo de stake | Algoritmo, equivalencia CPU/GPU, coste de ataque, distribución, prueba de alta y coste de auditoría medidos bajo el mismo escenario |
| 4 | Portar PoAS/PoT/DAG y estado seleccionado a una ruta activa, integrar bond y sectores solo tras sus puertas | Bloque completo validado, aplicado, revertido, propagado y recuperado por varios nodos |
| 5 | Testnet adversarial y propuesta de parámetros | Riesgo de reversión, fallos honestos, coste doméstico y concentración dentro de criterios declarados antes de medir |

**Primer hito concreto:** un contrato y un test de transición con PoW
real de dificultad de desarrollo en una **red dev separada** (génesis,
identificador y límites de dificultad explícitos), coinbases que maduran, depósito y
registro de sector; ancla única y primer bloque PoAS + PoT validado con
fixture real. La prueba de sector puede empezar detrás de una interfaz
abstracta, etiquetada como tal. Este hito no equivale todavía a una red
segura ni cierra los encargos de Filecoin.

## 6. Fuentes primarias y locales

- Bitcoin, [whitepaper §§4–6](https://bitcoin.org/bitcoin.pdf): propiedad de
  trabajo acumulado y distribución inicial por recompensa; no proporciona
  parámetros para el PoW temporal de ZEROX.
- Filecoin, [alta de sectores](https://spec.filecoin.io/systems/filecoin_mining/sector/adding_storage/),
  [PoRep](https://spec.filecoin.io/algorithms/pos/porep/) y
  [WindowPoSt](https://spec.filecoin.io/algorithms/pos/post/): tres pruebas
  con papeles distintos, no equivalentes al `SectorId` actual.
- ZEROX, `D-ZRX/SPEC.md` §§0, 3–6, 9;
  `P-ZRX/P-REGISTRO-SECTORES/ANALISIS.md` y encargos 01–05.
- Archivo antiguo: `MIGRACION.md`, `P-ZRX/T-ZRX/INVENTARIO-ABIERTO.md`,
  `P-ZRX/P-COBERTURA/investigacion/INFORME.md` y
  `P-ZRX/PIEZAS-DE-CODIGO/PROGRESO-0.0.1.md`.
