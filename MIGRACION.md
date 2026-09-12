# Estado de la migración PoSpace-Time + DAG

Actualizado el 10 de septiembre de 2026 durante la limpieza autorizada del repositorio.
Este documento distingue el destino, las piezas implementadas y la evidencia; no añade reglas
de consenso ni convierte propuestas en decisiones. El vault externo no es fuente de vigencia.

## Destino y límites

- PoAS de la familia Autonomys y PoT AES secuencial; orden por DAG.
- Transacciones transparentes y capa blindada Orchard/Halo2 prevista.
- Sin staking ni comités de decisión; política de aceptación elegida por el comercio.
- Cliente ligero secundario; servidores de consulta no se convierten en autoridades de finalidad.

La limpieza retiró los mineros antiguos, su FFI sin consumidores, documentación exclusivamente
PoW, el guardián dependiente del vault, los metadatos locales de Obsidian y la transcripción de
trabajo. La recuperación del contenido retirado se hace desde la copia de seguridad del usuario
o, para archivos versionados, desde el historial de Git.

Se conservan las fuentes de PoSpace y las pruebas de hashes: SHA3, Merkle, firmas, UTXO y
vectores CAVP siguen siendo necesarios aunque se abandone la minería PoW.

Contenido retirado en esta limpieza:

- `caliza/`, `silicio/` y `crates/zx-miner/`, con su entrada del workspace y dependencias FFI.
- `research/regtest-pow.md`, `research/lwma1.md` y `research/sha3-kernel-audit.md`.
- El precursor de Chia de 2019 y su whitepaper comercial de 2022, identificados en `PDF/README.md`.
- `.obsidian/`, `claude-zerox.txt` y el informe preliminar `AUDITORIA-VIABILIDAD-POST-DAG.md`;
  el contexto de ese informe queda sustituido por este documento y las fuentes conservadas.
- El guardián del vault y el job del minero de CI; las comprobaciones Python de CI se sustituyen
  por Bash/awk y Cargo/jq. No se ejecutaron auditorías Python.
- Cachés `__pycache__/` y `target/` (unos 51 GiB de artefactos regenerables de compilación).

Se conserva la evidencia histórica útil de PoST/DAG, incluidas propuestas descartadas, para no
perder contraejemplos ni procedencia. Está separada de las instrucciones activas mediante
`research/README.md`. El vault externo y `.git` no se han modificado.

## Parámetros: referencia de investigación, no configuración congelada

La ficha preparatoria más detallada vive en
[veritas/finalidad/baseline-30m/MODELO.md](veritas/finalidad/baseline-30m/MODELO.md).
Separa la carrera nominal de la seguridad de un pago aplicado en el DAG. Las fuentes upstream
están reunidas y fijadas por commit en [PDF/README.md](PDF/README.md).

| Magnitud | Referencia y estado | Evidencia local |
|---|---|---|
| `lambda` | 1 bloque/s nominal; rama A″ | `research/dag-poas-ancla-de-orden.md`, nota A″ de R-FIN-7 |
| `tau` | 1 s nominal por slot; monotonicidad no estricta en A″ | misma nota; no copiar la frase estricta residual de R-FIN-1a |
| `k` | 30 en los escenarios nominales; el documento aún contiene un 25 residual | mismo documento, §2 y R-FIN-6; consolidación pendiente |
| `alpha` | 0,33 operativo declarado en investigación; 0,40 es otro escenario | mismo documento, §2; no representa espacio adversario medido |
| `Delta` | Sin medir en una red ZEROX con DAG; 4/16/20 s son escenarios | mismo documento, §2; ronda `d9-ronda11a` |
| `S_max` | 150 s en la propuesta; debe comprobarse en trazas de ataque | R-FIN-1a/R-FIN-12 |
| `F` | 2 h provisional en investigación; definición e integración temporal pendientes | mismo documento, §2 y R-FIN-7 |
| `I`, `rho_max`, `L` | No cerrar valores a partir de una tabla de candidatos | R-FIN-14 y sus correcciones; escenarios no equivalen a adopción |
| `W_dec` | 45 s es máximo observado en una búsqueda limitada, no cota universal | `research/scripts/d9-ronda9c/informe.md`, §C |

`R-FIN-13′` cambia el retarget para contar los mismos billetes que cobran por `R-FIN-8′` y declara
superado `dag-poas-delta-real.md`. Los valores antiguos `lambda_real≈1,364` y `delta_real≈0,267`
no son parámetros del controlador corregido. Una tabla histórica puede seguir siendo correcta
para su experimento y dejar de ser aplicable al diseño.

Las curvas nominales de reversión usan `lambda=1`, `k=30`, ventaja inicial `3k=90` y `delta=0`.
No certifican por sí solas `blue_work` variable, red degradada, disponibilidad o composición PoT–DAG.
Los números de finalidad requieren una política de aceptación definida y una cota aplicable.

## Recalibraciones conservadas

El SPEC y las constantes Rust de emisión/capacidad incluyen `SHIFT=26`, cola de `26_666_666`
brek, madurez `12_000`, `N_CORTO=1_000`, `N_LARGO=21_600`, `ZONA_LIBRE=100_000` y
`REF_WEIGHT=384_000`. Esta limpieza no las modifica. El significado de altura, orden de aplicación
y madurez en DAG aún debe cerrarse antes de trasladar esas cuentas a una garantía temporal.

La vida de sectores, el umbral anti-DoS, el bootstrap y la tabla Cortex requieren su propia
adaptación. No escalar todas las constantes mecánicamente por 120 ni sustituir F por un número
determinista de bloques.

## Código reutilizable que todavía necesita migración

| Ruta | Dependencia que impide eliminarla aisladamente |
|---|---|
| `crates/zx-core/src/preimage/block.rs`, `wire.rs` | La cabecera lineal atraviesa serialización, red, almacenamiento y fixtures; Merkle sigue siendo útil. |
| `crates/zx-core/src/target.rs` | Tipos de trabajo y representación heredada usados por consenso y sincronización. |
| `crates/zx-consensus/src/dificultad.rs`, `timestamps.rs` | Retarget antiguo entrelazado con timestamp y contexto; no define el controlador PoST. |
| `crates/zx-consensus/src/fork_choice.rs` | Selección lineal mezclada con claves de caché reutilizables. |
| `crates/zx-consensus/src/bloque.rs` | Prueba de cabecera antigua mezclada con validación útil de dinero, firmas, peso y emisión. |
| `crates/zx-node/src/cadena.rs`, `contextual.rs`, `sync.rs` | Integración lineal pendiente de cabecera, prueba, orden y estado DAG. |
| `crates/zx-storage` | Persistencia reutilizable; no demuestra integración del estado finalizado del DAG. |

Estas piezas quedan para extraer y adaptar su funcionalidad útil. No son una segunda opción de
consenso vigente ni evidencia de que el objetivo tenga el ritmo de bloques del código anterior.
Eliminar toda esa dependencia requiere una migración funcional con contratos de cabecera, pruebas,
rango, orden UTXO y finalidad; no se ha simulado esa migración durante la limpieza.

La base PoAS de 556 bytes no especifica aún la cabecera final con padres DAG. Los tests que
detectan discrepancias de formato deben conservar su significado: pasar tests del formato
existente no puede presentarse como implementar el nuevo.

## Verificación de la limpieza

Comprobaciones realizadas antes de retirar la caché de compilación:

- `cargo fmt --all -- --check`: correcto.
- `cargo check --offline --locked -j 2 --workspace`: correcto.
- `cargo clippy --offline --locked -j 2 --workspace --all-targets -- -D warnings`: correcto.
- Guardianes de alcance, citas del SPEC, versiones exactas y frontera de crates: correctos.
- `cargo test --offline --locked -j 2 --workspace --no-fail-fast --quiet`: un único test falla,
  `el_spec_dice_el_tamano_real_de_la_cabecera`, por la discrepancia preexistente 92/556.
  Las cuatro pruebas ignoradas de `tres_nodos` siguen ignoradas; no se añadieron exclusiones.
- Las pruebas de red necesitaron repetirse fuera del sandbox para abrir sockets/mDNS y pasaron.
- Enlaces locales de los documentos de entrada y READMEs comprobados; `git diff --check` correcto.

Este pase usó las features predeterminadas. No se ejecutaron aquí el backend RocksDB opcional,
benchmarks, ni una auditoría matemática nueva. La siguiente compilación recreará `target/`.

## Límites de las auditorías de finalidad conservadas

1. `R-FIN-7` propone un límite temporal para el DAG. El límite individual por bloques de la
   implementación lineal no prueba su comportamiento ni acuerdo global.
2. La ruta D14 de `d14k_visible2.py` usa `r8c_sim.Mundo`, cuya selección de padres honestos no
   incorpora el shuffle obligatorio de R-FIN-12. La transferencia del ataque al destino necesita
   comprobarse con esa regla.
3. El escenario `retro500` usa un generador que no valida `S_max`. No usar su peor `k_ref` como
   descarte definitivo sin comprobar que la traza cumple el protocolo propuesto.
4. El resultado 12/12 corresponde a escenarios concretos de retención a Delta=16; la tabla de
   `d14-dagknight/informe3.md` contiene 8/12 y 7/12 a Delta=20. La métrica no ejecuta doble gasto.
5. D14 mide un tiempo de parada al observar M bloques honestos; el gate D16 evalúa una carrera a
   tiempo fijo tras convertir M a tiempo medio. El factor publicado no es automáticamente el
   riesgo exacto de la política original. La sustitución `3k` por `3k_ref` sigue sin demostrar.
6. Las latencias de Avalanche sobre espacio son proyecciones de rondas y transporte, no una
   implementación de finalidad ZEROX. Los errores algebraicos del muestreo y su seguridad
   compuesta deben resolverse antes de publicar una garantía.

Los informes originales conservan sus cifras para poder contrastarlos; no se reescriben sus
resultados como si se hubieran vuelto a ejecutar. Las conclusiones que omitan estas condiciones
no deben usarse para aprobar ni descartar una familia de protocolos.

## Regla para el próximo cálculo

Registrar antes de ejecutar: versión del modelo, valores con unidades y fuente, supuestos de red
y adversario, criterio de parada, evento de fallo y precisión numérica. Comprobar que controles y
candidatos usan el mismo escenario y que toda traza satisface las reglas ensayadas.

Todo cálculo nuevo sigue [veritas/LINEO.md](veritas/LINEO.md). La evidencia Python que permanezca
se inspecciona para portar el modelo pertinente a Julia, no se ejecuta como auditoría nueva.
