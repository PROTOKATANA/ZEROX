# ORDEN-W03 — Motor de estado de la transición en Rust, con diferencial contra el oráculo T01

## 1. Identidad y contexto

- **ID:** W03. **Estado:** redactada 2026-09-26; se lanza cuando W04 esté migrada (crea
  `zx-consensus`) y T01-B haya producido `vectores-transicion-v0.txt`. **Director:** Claude.
  **Ejecutor:** DeepSeek (con revisión independiente posterior por un subagente Sonnet).
- **Zona (única escribible):** `/home/katana/zeo/ZEROX/deepseek/W03/`.
- **Objetivo único:** implementar en `crates/zx-consensus/src/transicion/` la máquina de estados del
  contrato `CONTRATO-v0.1` (interfaces por defecto CUT-HWΦ, FC-3, SEC-0) sobre los tipos **reales**
  de `zx-core` (transacciones v1/v2/v3, `OutPoint`, `ClavePublica`, firmas), con aplicación, undo
  exacto por delta y selección, y demostrar **diferencialmente** que coincide con el oráculo Julia
  T01 en todos sus vectores.
- **Pregunta falsable:** «El motor Rust, alimentado con los bloques reales que el arnés construye a
  partir de cada caso de `vectores-transicion-v0.txt`, da el mismo resultado por bloque, la misma
  punta y el mismo estado canónico que el oráculo T01, en todos los casos.» Se refuta con una
  discrepancia.
- **Desbloquea:** `PLAN-0.0.1.md` W05/W06; IPA A-01, A-03, C-01, C-06 en código.

## 2. Autoridad y entradas

Lee íntegros: este archivo; `V-ZRX/LINEO.md`; `P-ZRX/P-TRANSICION/CONTRATO-v0.md` **incluido su
apartado «Ratificaciones v0.1»**; `P-ZRX/P-TRANSICION/ORDEN-T01.md` §3 (decisiones 1–15, que el
motor también cumple salvo lo que diga §3 de esta orden); `P-ZRX/P-FORMATO/FORMATO-v0.md`;
`P-ZRX/P-FORMATO/REVISION-W02.md` (observación para W03). Vectores:
`P-ZRX/P-TRANSICION/T01/resultados/vectores-transicion-v0.txt` (y su `.sha256`). Oráculo de
referencia para dudas de semántica: el código de `P-ZRX/P-TRANSICION/T01/src/` (**léelo como
especificación ejecutable; no lo traduzcas línea a línea**). Código antiguo a portar (solo
lectura): `git -C /home/katana/zeo/ZEROX show 9681061:crates/zx-consensus/src/validacion.rs`,
`…/testigo.rs`, `…/emision.rs` (solo la forma de `acumular`), `crates/zx-storage/src/utxo.rs`
(diseño de `UndoData`) y sus tests.

Entrada congelada: `P-ZRX/P-TRANSICION/ENTRADA-W03.sha256`, al empezar y como último paso.

## 3. Decisiones ya tomadas por el director

1. **Ubicación:** módulo `transicion` en `crates/zx-consensus` (el crate lo crea W04). Dependencias
   ya presentes en el workspace; si necesitas otra, **para**.
2. **Entradas del motor:** `HechosCabecera` (enum por familia) con lo que las verificaciones de
   cabecera, que **no** son de esta orden, ya han decidido: `Genesis { hash }`,
   `PoW { hash, padre, altura: u32, trabajo: U256, pow_valido: bool }`,
   `PoST { hash, padre, slot: u64, productor: ClavePublica, peso: u128, prueba_valida: bool,
   requisito_declarado: u64 }`; y `BloqueTransicion { hechos, txs: Vec<(Tx, Vec<Vec<u8>>)> }`.
   `pow_valido`/`prueba_valida` falsos ⇒ `ErrPow` (como `pow_ok` en T01).
3. **Parámetros:** `ParametrosTransicion` con los símbolos del contrato (`H_dep`, `M_cb`, `M_dep`,
   `H_corte_min` en `u32`; `W_min: U256`; `S_min`, `q`: `Amount`; `K_min: u32`; `M_res_slots`,
   `M_dep_slots`, `M_rec_slots`, `R_slots`: `u64`; `F_slots: Option<u64>`), más
   `subsidio_pow: fn(u32) -> Amount` y `subsidio_post: fn(u64) -> Amount`. **Ningún valor por
   defecto** en esta orden: los fijará la red dev (W06).
4. **Estado canónico:** `BTreeMap<OutPoint, EntradaUtxo>` con `EntradaUtxo { valor, lock, origen:
   {CoinbasePow, Tx, Liberacion}, creada: Punto }`, `Punto = Altura(u32) | Slot(u64)`;
   `BTreeMap<ClavePublica, Garantia>` con activo, pendientes, en retirada, congelado (0) y créditos
   (D-T08); `emitido`, `quemado` en `i128`; fase; terminal; altura; trabajo acumulado; último slot;
   peso del sufijo.
5. **Undo por delta**, no por copia: por cada bloque se guarda el valor previo (`Option`) de cada
   `OutPoint` y de cada `ClavePublica` tocados y los escalares previos; `deshacer` los restituye.
   Propiedad obligatoria: `deshacer(aplicar(E, B)) == E` (igualdad estructural).
6. **Autorización real:** entradas con `Lock::PubKey` y `Lock::MultiSig` se verifican con el sighash
   `SIGHASH_ALL` de `C-SIG` (portando `testigo::satisface`); `Lock::Htlc` no puede existir
   (`validar_forma_tx` lo impide). La aceptación de v2 con `verificar_aceptacion` (W02). Se llama a
   `validar_forma_tx` y `validar_forma_cabecera_post` antes que nada.
7. **Coinbase:** PoW = v1, **primera** transacción del bloque, sin entradas y **con al menos una
   salida** (observación de REVISION-W02), `Σ salidas ≤ subsidio_pow(h) + tarifas(B)`; génesis =
   `C-GEN-03` (salidas no entran en el UTXO). PoST = v3, primera, `clave == productor` (F-09),
   `importe ≤ subsidio_post(slot) + tarifas(B)` → crédito pendiente (D-T08). Una sola coinbase por
   bloque. `Emitido` como en ORDEN-T01 §3.11.
8. **Selección:** función pura FC-3 y `NodoEnLinea` con huérfanos y `C-FIN-01`, idénticos en
   semántica a T01 (incluidas las AMBIGÜEDADES ratificadas). El identificador para desempates es el
   `BlockHash` real (menor en orden de bytes big-endian).
9. **Errores:** enum `ErrorTransicion` con **los mismos nombres** que el `Err` de T01 (incluidos
   `ErrRetiroPendiente` y `ErrSinPadre`) más los propios de lo real, cada uno con su correspondencia
   declarada: `ErrFirma` → equivale a `ErrAutorizacion` de T01; `ErrForma(ErrorFormaTx)` → ver §4.
10. **Arnés diferencial** (`crates/zx-consensus/tests/diferencial_t01.rs`), que lee el fichero de
    vectores y, por caso: deriva claves Ed25519 deterministas por clave abstracta
    (`semilla = SHA3-256("zx-t01-clave" ‖ k u64 LE)`, con `ed25519-zebra`); construye transacciones
    **reales** v1/v2/v3 firmadas por el `firmante` abstracto (si `firmante ≠ dueño`, la firma no
    verifica: así se ejercita la autorización real); mantiene la correspondencia id abstracto de
    salida → `OutPoint` real; convierte `trabajo`, `peso`, alturas y slots; ejecuta el motor en el
    **orden de entrega** del fichero; y compara `RES`, `SEL` y el estado canónico traducido de vuelta a
    claves abstractas (`UTXO` como multiconjunto ordenado, `GAR`, `EST`).

## 4. Correspondencias fijadas para el diferencial

| Caso de T01 | Resultado Rust aceptado como igual |
|---|---|
| `Evidencia` en PoW (`ErrOperacionFase`) o en PoST (`ErrFueraDeAlcanceV0`) | la v4 no se puede construir: el arnés espera `ErrForma(VersionInactiva)` y lo cuenta como coincidencia |
| `firmante ≠ dueño` o `firmante ≠ clave` (`ErrAutorizacion`) | `ErrFirma` o `ErrAutorizacion` |
| Salida o entrada inexistente (`ErrSaldo`/`ErrDobleGasto` según T01) | el mismo nombre; si Rust da otro, es **discrepancia** |
| R-8 importe 0 (`ErrSaldo`) | `ErrForma(ImporteCero)` |
| R-9 transferencia con entradas y sin salidas (`ErrSaldo`) | `ErrForma(TransferenciaSinSalidas)` |
| R-6/R-7/R-9 coinbase fuera de lugar, sin salidas o transferencia sin entradas (`ErrEmision`) | `ErrEmision` |
| Cualquier otro | nombre idéntico |

Cualquier otra diferencia es discrepancia: no añadas correspondencias por tu cuenta; si crees que
hace falta una, **para** e infórmala con el caso mínimo.

## 5. Modelo de amenaza

Bloques y transacciones de un par hostil sobre historias con reorganizaciones: firmas de otra clave,
entradas repetidas en el mismo bloque o en la misma tx, coinbase en posición distinta de la primera,
dos coinbases, coinbase PoST a otra clave, depósitos con importe que no cuadra, liberación antes de
`R_slots`, gasto de `coinbase_pow` inmadura, bloque PoST sin garantía. Ninguna ruta puede entrar en
pánico (lints del workspace).

## 6. Plan de verificación

| Paso | Qué | Criterio |
|---|---|---|
| V1–V2 | `fmt --check`, `clippy -D warnings --locked` | limpio |
| V3 | `cargo test --workspace --all-features --locked` | todo lo previo pasa con el mismo nombre + lo nuevo |
| V4 | `diferencial_t01`: todos los casos del fichero | **0 discrepancias**; informe por nombre de caso |
| V5 | Tests unitarios propios (no cubiertos por T01): depósito con cambio (F-07), MultiSig, coinbase PoW sin salidas rechazada, dos coinbases, coinbase PoST en posición 2, `clave ≠ productor` | cada uno con su error |
| V6 | Propiedades con `proptest` (semilla fija, como el resto del workspace): undo exacto e I-1 sobre secuencias aleatorias de bloques válidos del arnés | sin fallos |
| V7 | `bash ci/dependencias-exactas.sh`; `Cargo.lock` sin cambios de versión | OK |

**Prohibido Python.**

## 7. Medición

No hay. Presupuesto: **3 h, 8 hilos, 16 GiB, 20 GiB de disco**. **SUPERADO** si V1–V7 cumplen.

## 8. Entregables

Patrón W02/W04: `ws.orig/`, `ws/`, `cambios.patch`, `MIGRACION.sha256`, `logs/`, `INFORME.md`
(veredicto; tabla de casos del diferencial; correspondencias usadas; API final; «Lo que esta orden
NO demuestra»: verificación de cabeceras, persistencia en disco, red, parámetros de la red dev),
`PROGRESO.md`, `HORAS.log`. Resumen final ≤ 40 líneas.

## 9. Límites de la sesión

DeepSeek Harness, `deepseek-flash`, esfuerzo `high`; LINEO antes del código; sin Python; nada fuera
de `deepseek/W03/`; sin commit ni push; sin secretos; ningún `Ok` ficticio; fallos literales.

## Lanzamiento

    mkdir -p /home/katana/zeo/ZEROX/deepseek/W03 && cd /home/katana/zeo/ZEROX/deepseek/W03 && \
    ( set -a; . /home/katana/torio/deepseek-harness/.env >/dev/null 2>&1; set +a; \
      node /home/katana/torio/deepseek-harness/apps/cli/lib/bin.js --profile headless \
      "Orden W03. Lee íntegro /home/katana/zeo/ZEROX/P-ZRX/P-TRANSICION/ORDEN-W03.md y cúmplelo. Antes de escribir código, lee íntegro /home/katana/zeo/ZEROX/V-ZRX/LINEO.md. Si detectas una falta de definición, infórmala antes de editar." \
      > ../W03-dsh.stdout 2> ../W03-dsh.stderr )
