# Estado de la migración PoSpace-Time + DAG

Actualizado el 10 de septiembre de 2026 durante la limpieza autorizada del repositorio, con una
actualización acotada del 2026-09-22 (véase «Actualización del 2026-09-22»).
Este documento distingue el destino, las piezas implementadas y la evidencia; no añade reglas
de consenso ni convierte propuestas en decisiones. El vault externo no es fuente de vigencia.

## Actualización del 2026-09-22 — cabecera DAG redactada, integración pendiente

Sección acotada a la fecha. No reescribe el relato de la limpieza de septiembre ni convierte
propuestas en decisiones.

- **Redactado en el SPEC.** `SPEC.md` §6.1–§6.2 fijan el layout de la cabecera DAG (C-HDR-01),
  la prefirma (C-HDR-03), el codec único (C-HDR-09) y la justificación PoT (C-HDR-07): prefijo
  PoAS `[0, 492)`, `body_commitment` `[492, 524)`, `parent_count` `[524, 525)`,
  `extra_parents` `[525, 525 + 32·(P−1))` y `sello` al final, con `589 + 32·(P−1)` bytes y
  `1 ≤ P ≤ 15`. El texto normativo del formato no deja nada pendiente; lo que sigue abierto son
  los valores del controlador de rango y de la finalidad, no la cabecera.
- **No integrado en la ruta activa.** La ruta del nodo sigue usando la cabecera lineal de 92 B;
  la discrepancia 92/556 persiste y `el_codigo_alcanza_la_base_poas_de_556` sigue ignorado a
  propósito. La cabecera redactada **no demuestra** que exista un nodo PoST + DAG completo.
- **Resultados históricos frente a comprobaciones de esta actualización.** La verificación de la
  limpieza (`cargo fmt/check/clippy/test`, 10 de septiembre) es **histórica** y pertenece a aquel
  árbol. En la actualización del 2026-09-22 **no se ha reejecutado `cargo test`**: las
  comprobaciones hechas aquí son documentales (`git diff --check`, `ci/citas-spec.sh`) y ningún
  recuento de tests se presenta como «actual». Cualquier cifra de tests debe citarse con su fecha
  y su árbol.

### Ampliación del 2026-09-22 — primitiva PoT incorporada, sin cablear (encargo 03a)

Sección acotada. Corrige, **solo para este incremento**, la nota anterior sobre `cargo test`: aquí
sí se ejecutaron tests y se citan con su comando exacto. El aserto sigue siendo válido para la
cabecera DAG del incremento anterior, que no reejecutó la suite.

- **La primitiva entra al workspace.** `crates/zx-pot` incorpora `prototipos/pot-estable`
  —`subspace-proof-of-time` @ `f8842d0`, 0BSD— sin reescribir el AES. Los ficheros `src/aes.rs`,
  `src/aes/x86_64.rs`, `src/aes/aarch64.rs` y `src/tipos.rs` son **byte a byte idénticos** al
  prototipo; `crates/zx-pot/rustfmt.toml` usa `skip_children` para no reformatearlos. El prototipo
  **no se modifica** y sigue en su sitio como fuente de contraste.
- **Dependencias fijadas, no sustituidas.** `aes = "=0.9.3"` y `blake3 = "=1.8.7"` (más
  `cpufeatures = "=0.2.17"`), exactamente las del lock del prototipo. **No** se intercambió AES por
  el `0.8.4` que ya estaba en el lock raíz por `aes-gcm`: habría cambiado la primitiva. El
  `Cargo.lock` se actualizó con `cargo check -p zx-pot --offline`; las seis bajadas ajenas que la
  re-resolución MSRV-aware hizo (`hermit-abi`, `js-sys`, `wasm-bindgen` ×4) se restauraron para que
  el diff **no baje ninguna versión ajena** —solo añade paquetes y desambigua las referencias
  duplicadas—, y `cargo check -p zx-pot --locked --offline` lo acepta.
- **Los 32 vectores siguen siendo la validación externa.** `cargo test -p zx-pot --locked
  --offline`: 5/5 en verde (1 del AES interno, 3 de la primitiva, 1 del diferencial de 32 vectores).
- **Adaptador puro en `zx-consensus`, no en `zx-core`.** `crates/zx-consensus/src/pot.rs` convierte
  los ocho valores de 16 B del wire a los checkpoints de `zx-pot` **valor a valor, sin `transmute`**,
  y expone `verificar_slot_aes(semilla, N, checkpoints)`. Nunca se llama «validar bloque». La
  proyección `N(s): u64 → NonZeroU32` (`proyectar_iteraciones`) da **error de contexto** —cero,
  `> u32::MAX` o no múltiplo de 16—, no «prueba inválida»; el futuro verificador de bloque lo
  traducirá a `Pendiente`. Los tests de límites no ejecutan AES con valores enormes.
- **Origen causal: pendiente, no acreditado.** La semilla y `N(s)` **no viajan** en los
  checkpoints del wire, pero el adaptador acepta **argumentos libres** y **no acredita su origen
  causal**; esa garantía corresponde al futuro verificador contextual, que no existe.
  `zx-core::wire_dag::verificar_justificacion_pot` **no se ha tocado** y sigue devolviendo
  `IntegracionPotPendiente`; `zx-node` sigue con la cabecera lineal. No se han conectado caché,
  flujo, PoAS ni el controlador de rango, y no se ha fijado `D` ni `N(s)`.
- **Inventario actualizado.** `C-POT-02` (contrato de verificación de un slot, probado) y
  `C-POT-04` (solo la proyección) pasan de `ci/reglas-sin-codigo.txt` a
  `ci/reglas-sin-cablear.txt`; `C-POT-01`, `C-POT-03` y `C-POT-05`…`C-POT-08` siguen sin código.
  Las funciones del adaptador están declaradas en `ci/consenso-pendiente.txt` y
  `ci/frontera-crates.sh` admite `zx-consensus → zx-pot`. Guardianes en verde.
- **Comprobaciones de este incremento, con su árbol.** `cargo fmt --all -- --check`;
  `cargo check --workspace --locked --offline`; `cargo test -p zx-consensus --test pot_slot
  --locked --offline` (7/7); `cargo clippy` con `-D warnings` sobre `zx-pot` (todos los targets) y
  sobre `zx-consensus --lib --test pot_slot`;
  `ci/citas-spec.sh`, `ci/alcance-consenso.sh`, `ci/frontera-crates.sh`,
  `ci/dependencias-exactas.sh` y `git diff --check`. No se ejecutó la suite completa del workspace.
- **Lo que esto NO es.** No resuelve el doble farmeo, no convierte a ZEROX en un nodo que valide
  bloques PoST y no cierra `C-FLU-*`, `C-HDR-07` ni la finalidad. La ruta ARM (`aarch64.rs`) se
  conserva intacta pero **no se ha compilado ni verificado** en esta máquina `x86_64`: sigue usando
  `core::simd` y no se presenta como probada.

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

La base PoAS de 556 bytes describe el prefijo y el sello, y la **cabecera DAG ya está redactada**
en `SPEC.md` §6.1–§6.2 (prefijo fijo `[0, 492)`, `body_commitment`, `parent_count` y
`extra_parents` antes del sello, `589 + 32·(P−1)` bytes con `1 ≤ P ≤ 15`). Que esté redactada
**no significa que el código la implemente**: la ruta activa del nodo sigue ligada a la cabecera
lineal de 92 B y la integración completa sigue pendiente. Los tests que detectan discrepancias
de formato deben conservar su significado: pasar tests del formato existente no puede presentarse
como implementar el nuevo.

## Verificación de la limpieza

Comprobaciones realizadas antes de retirar la caché de compilación:

- `cargo fmt --all -- --check`: correcto.
- `cargo check --offline --locked -j 2 --workspace`: correcto.
- `cargo clippy --offline --locked -j 2 --workspace --all-targets -- -D warnings`: correcto.
- Guardianes de alcance, citas del SPEC, versiones exactas y frontera de crates: correctos.
- `cargo test --offline --locked -j 2 --workspace --no-fail-fast --quiet`: un único test falla,
  `el_spec_dice_el_tamano_real_de_la_cabecera`, por la discrepancia preexistente 92/556.
  *(Ese test se partió en dos el 2026-09-12: `el_spec_conserva_la_base_poas_de_556`, en verde, y
  `el_codigo_alcanza_la_base_poas_de_556`, ignorado. La discrepancia 92/556 sigue viva en el
  segundo; el nombre de arriba ya no existe.)*
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
