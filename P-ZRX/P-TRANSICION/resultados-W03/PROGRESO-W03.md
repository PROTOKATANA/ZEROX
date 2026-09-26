# PROGRESO.md — ORDEN-W03

Motor de estado de la transición en `crates/zx-consensus/src/transicion/`, con diferencial contra el
oráculo Julia T01. Zona única: `/home/katana/zeo/ZEROX/deepseek/W03/`.

## Entrada congelada — comprobación de INICIO (2026-09-26T02:32 +02:00)

```
$ cd /home/katana/zeo/ZEROX && LC_ALL=C sha256sum -c P-ZRX/P-TRANSICION/ENTRADA-W03.sha256
P-ZRX/P-TRANSICION/ORDEN-W03.md: OK
P-ZRX/P-TRANSICION/CONTRATO-v0.md: OK
P-ZRX/P-DAG/CONTRATO-ESTADO-DAG-v0.md: OK
P-ZRX/P-FORMATO/FORMATO-v0.md: OK
P-ZRX/P-FORMATO/REVISION-W02.md: OK
V-ZRX/LINEO.md: OK
P-ZRX/P-TRANSICION/T01/resultados/vectores-transicion-v0.txt: OK
exit=0
```

Comprobado a mano el sha256 de los vectores:
`06d95324c01083c297b1d1423845ee3c78f47dc3e7bf314e56d3083a41e6d766` (coincide con el `.sha256`, que
contiene solo el hash, sin formato `sha256sum -c`).

Base de trabajo: copia de la raíz **tal como estaba a las 02:30** (`Cargo.toml` con los cuatro
crates `zx-core`, `zx-pot`, `zx-consensus`, `zx-dag`; W05b1 aún no había tocado la raíz). `ws.orig`
y `ws` son copias idénticas; W03 no depende de `zx-poas` ni de `zx-farmer`.

## Faltas de definición detectadas ANTES de editar (con la lectura aplicada)

1. **`BTreeMap<ClavePublica, Garantia>` y `BTreeMap<OutPoint, EntradaUtxo>` (§3.4) exigen `Ord` en
   `ClavePublica` y `OutPoint`, que hoy no lo implementan** (`ClavePublica` solo deriva
   `Clone/Copy/PartialEq/Eq/Debug`; `OutPoint`, `Clone/Copy/PartialEq/Eq/Debug/Hash`). Lectura
   aplicada: añadir `PartialOrd, Ord` a ambos en `zx-core` (orden lexicográfico de bytes,
   determinista). No cambia wire, hash ni ninguna regla; solo habilita la estructura que la orden
   fija. Descartado usar newtypes para no desviarme del tipo literal de §3.4.
2. **`validar_forma_cabecera_post` no se puede invocar desde `HechosCabecera::PoST`**, porque ese
   enum, tal como lo fija §3.2, no lleva `DagBlockHeader` ni `height`. Lectura aplicada: añadir un
   campo **adicional** `cabecera_post: Option<DagBlockHeader>` a `BloqueTransicion`; el motor lo
   valida cuando está presente (F-03: `height == 0`) y lo ignora si es `None`. El arnés lo rellena
   con una cabecera de altura 0. Es aditivo a §3.2; no cambia ningún campo fijado.
3. **Madurez dual del pendiente.** El oráculo guarda en cada `Pendiente` **dos** madureces
   (`madura_en_altura` y `madura_en_slot`): un depósito creado en fase PoW madura por altura en PoW
   y, tras el corte, por slot (`s0 + M_dep_slots`). Un único `Punto` por pendiente no lo puede
   representar. Lectura aplicada: `Pendiente { importe, madura_en_altura: Option<u32>,
   madura_en_slot: Option<u64> }`, idéntica al oráculo. `Punto` se usa en `EntradaUtxo.creada`.
4. **Génesis abstracto con `padre != 0`.** `HechosCabecera::Genesis { hash }` (§3.2) no lleva padre,
   así que el motor no puede comprobar el `padre` del génesis abstracto. Lectura aplicada: el rechazo
   del segundo génesis sale de que la fase ya no es `Genesis` (coincide con los 3 casos X-01 del
   fichero); el arnés lleva la contabilidad del padre abstracto para el `RES` por bloque.
5. **Cambio en depósitos (FORMATO-v0 F-07) frente a la igualdad exacta de T01 (AMBIGUEDAD-3).**
   F-07 admite cambio (`Σ entradas = Σ salidas + importe`); T01 exige `Σ entradas == importe`
   (sin salidas). Lectura aplicada: el motor implementa F-07 (cambio admitido, tarifa 0), que
   coincide en **todos** los vectores porque todos los depósitos tienen `sal=[]` (comprobado).
   El test unitario V5 «depósito con cambio (F-07)» cubre el caso nuevo.
6. **`validar_forma_tx` antes que nada (§3.6) frente al orden del oráculo.** El oráculo cuenta
   coinbases y posiciones antes de aplicar; el motor valida la forma primero. Comprobado que en los
   35 786 bloques del fichero no hay ninguna transacción con forma inválida salvo las 3 `Evidencia`
   (v4 → `ErrForma(VersionInactiva)`), que §4 mapea expresamente. No hay `importe=0`, ni
   transferencias sin salidas, ni `pow_ok=0` con transacciones, así que no hay divergencia.
7. **`prueba_valida` (PoST).** T01 no tiene ese indicador (usa `peso ≥ 1`); todos los bloques PoST
   del fichero traen `pow_ok=1`. El motor lo comprueba por §3.2 (falso ⇒ `ErrPow`); ningún vector lo
   ejerce.
8. **Alcance de `aplicar_fusion`.** La orquestación completa de ED-1…ED-6 (punto de aplicación,
   orden del mergeset, `rojo_U3`) es de W06a. W03 implementa las primitivas de fusión con el punto
   de aplicación dado, el descarte con motivo y el recorte de la coinbase PoST; se prueba con los
   cuatro tests que pide V5 y se declara **no** demostrado el motor DAG completo.
9. **Colisión de `OutPoint` en transacciones idénticas (detectada durante V4).** Dos coinbases PoW
   idénticas en bloques distintos tienen el mismo `txid` real y colisionan en el UTXO, algo que el
   oráculo no modela porque asigna un id de salida distinto a cada una. Lectura aplicada en el
   **arnés**: cada salida abstracta usa una clave de bloque única derivada de `(id, dueño)` en un
   dominio propio, de modo que cada salida real es distinta sin cambiar ninguna regla ni el render
   (la traducción de vuelta devuelve el dueño abstracto). Para las salidas implícitas de
   `Liberacion`, que el motor crea con `Lock::PubKey{clave}`, se añade al estado un contador
   `prox_salida` y se usa como índice del `OutPoint` (el oráculo hace lo mismo con su `prox_salida`);
   la comparación de UTXO no mira el `OutPoint`, así que no cambia ningún resultado. Sin esto, V4
   daba 5 511 discrepancias por `ErrDobleGasto` en casos con dos coinbases o dos liberaciones
   idénticas. Es una limitación del formato v0 (no hay nonce de transacción) que conviene elevar al
   director para W05/W06.

## Secuencia de trabajo

1. **02:27–02:33 · Lectura y montaje.** Lectura íntegra de `ORDEN-W03.md`, `LINEO.md`,
   `CONTRATO-v0.md` (con ratificaciones), `ORDEN-T01.md` §3, `FORMATO-v0.md`, `REVISION-W02.md`,
   `CONTRATO-ESTADO-DAG-v0.md` §3, el código del oráculo T01 y el código antiguo de `9681061`
   (`validacion.rs`, `testigo.rs`, `emision.rs`, `utxo.rs`). Comprobación de entrada (arriba).
   Copia de `Cargo.toml/Cargo.lock/rust-toolchain.toml/crates/ci/.github/testdata` a `ws.orig` y
   `ws`; `CARGO_HOME` de W05a hardlinkeado a `.cargo-home`. Build base `cargo test --no-run` OK.
2. **02:33–02:50 · Implementación Rust.** `crates/zx-consensus/src/transicion/` (`mod.rs`,
   `error.rs`, `tipos.rs`, `estado.rs`, `aplicar.rs`, `seleccion.rs`, `fusion.rs`, `tests.rs`);
   `pub mod transicion` en `lib.rs`; `ed25519-zebra` como dev-dependency de `zx-consensus`; derivas
   `PartialOrd, Ord` en `OutPoint` y `ClavePublica` de `zx-core` (habilitan las claves `BTreeMap`
   que fija §3.4). Clippy limpio en la primera pasada tras corregir dos avisos.
3. **02:40–03:05 · Arnés diferencial.** Vectores copiados a `ws/testdata/transicion-v0/` con
   `PROCEDENCIA.md`; `tests/diferencial_t01.rs` traduce claves, txs v1/v2/v3/v4, OutPoints, bloques
   y estado canónico, y compara `RES`/`SEL`/`UTXO`/`GAR`/`EST`. Tres pasadas: 5 722 discrepancias
   (colisión de `txid` en salidas), 5 511 (créditos D-T08 mal clasificados), y **0 discrepancias**
   con las dos correcciones anteriores en los 2 055 casos (176,5 s).
4. **03:05–03:15 · Tests unitarios V5 y propiedades V6.** `src/transicion/tests.rs` (testigo real,
   depósito con cambio F-07, MultiSig, coinbase sin salidas, dos coinbases, coinbase PoST en
   posición 2, `clave ≠ productor`, y los cuatro descartes/recorte de fusión); `tests/transicion_prop.rs`
   (proptest con `RngSeed::Fixed(0x5a5a)`, 64 casos: undo exacto, I-1, I-1b y determinismo).
5. **03:15–02:56 · V1–V7 y entregables.** V1 `fmt --check` OK; V2 clippy workspace `-D warnings`
   OK; V3 `cargo test --workspace --all-features --locked` **385 pasan / 0 fallan / 1 ignorado**;
   V4 diferencial 0 discrepancias; V5 8 tests nuevos; V6 2 propiedades proptest; V7 10 dependencias
   exactas y `Cargo.lock` con una sola línea añadida (`ed25519-zebra` en `zx-consensus`), sin ningún
   cambio de versión. `cambios.patch` (18 ficheros, 8,36 MB) y `MIGRACION.sha256` (100 huellas,
   `sha256sum -c` OK).

## Resultado

- V1–V7 **SUPERADO**. V4: **0 discrepancias** en los 2 055 casos, 1 947 con sufijo PoST. Informe por
  nombre de caso en `logs/V4-diferencial.log`.
- Sin dependencia externa nueva: `ed25519-zebra` ya estaba en `Cargo.lock`.

## Incidencia en la comprobación FINAL de la entrada congelada

`sha256sum -c ENTRADA-W03.sha256` al terminar (02:56): **6/7 OK**, con
`P-ZRX/P-DAG/CONTRATO-ESTADO-DAG-v0.md` en `FAILED` (`823984e8…` → `614dc72a…`). La causa es
**externa**: la orden T04 reescribió ese contrato en paralelo (RD-1…RD-10) y lo dejó en el commit
`aa2866f`. W03 no ha escrito fuera de `deepseek/W03/`; su `cambios.patch` no toca ese fichero.
Detalle literal en `logs/entrada-final.log`.


