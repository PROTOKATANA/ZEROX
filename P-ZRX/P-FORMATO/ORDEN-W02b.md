# ORDEN-W02b — FORMATO v0.1 en todas las capas: nonce por clave, coinbases únicas

## 1. Identidad y contexto

- **ID:** W02b. **Fecha:** 2026-09-26. **Director:** Claude. **Ejecutor:** DeepSeek. Se lanza cuando
  estén migradas W03-R y W05b2 y existan los vectores de T01-D.
- **Zona (única escribible):** `/home/katana/zeo/ZEROX/deepseek/W02b/`.
- **Objetivo único:** implementar la **Corrección v0.1** de `P-ZRX/P-FORMATO/FORMATO-v0.md`
  (F-15…F-18) en `zx-core` (formato, `txid`, códec, forma), `zx-consensus::transicion` (estado y
  reglas) y `zx-post` (productor), actualizar el oráculo de formato y validar el motor contra los
  vectores v0.1 de T01-D.
- **Pregunta falsable:** «Con F-15…F-18, ninguna operación de garantía se puede aplicar dos veces,
  ninguna coinbase PoW repite `txid`, el motor coincide con T01-D en todos sus casos (incluidos los de
  repetición) y los `txid` y bytes v1 no-coinbase siguen siendo los de `9681061`.» Se refuta con una
  repetición aceptada, una discrepancia o un vector v1 alterado.

## 2. Entradas

Lee íntegros: este archivo; `V-ZRX/LINEO.md`; `P-ZRX/P-FORMATO/FORMATO-v0.md` (entero, con la
Corrección v0.1); `P-ZRX/P-TRANSICION/CONTRATO-v0.md` (v0.1); `P-ZRX/P-DAG/CONTRATO-ESTADO-DAG-v0.md`
(RD-1…RD-10); los informes de W02, W03 y W03-R (`P-ZRX/P-FORMATO/resultados-W02/`,
`deepseek/W03/INFORME.md`, `deepseek/W03R/INFORME.md`); el oráculo de formato
`P-ZRX/P-FORMATO/oraculo-formato-v0/`; los vectores
`P-ZRX/P-TRANSICION/T01/resultados/vectores-transicion-v0.1.txt` y
`vectores-transicion-negativos-v0.1.txt`. Base: el workspace de la raíz.
Entrada congelada: `P-ZRX/P-FORMATO/ENTRADA-W02b.sha256`, al empezar y como último paso.

## 3. Decisiones del director

1. **`zx-core`:** `ExtensionTx::Garantia` gana `nonce: u64` y `CoinbasePost` gana `slot: u64`, en el
   orden de F-15/F-17 dentro de `extension_digest` y del códec (F-14: tras las salidas, antes de los
   testigos). `validar_forma_tx` sin cambios salvo la nueva anchura; la regla de F-16 y la igualdad
   `slot` de F-17 son **contextuales** (motor), no de forma.
2. **Oráculo de formato** (`oraculo-formato-v0` copiado a tu zona como `oraculo-formato-v0.1`):
   actualizado a F-15/F-17 y regenerado `testdata/formato-v0.1/vectores.txt`; los tests Rust de
   `formato_v0.rs` pasan a leer los v0.1 **y** siguen comprobando que los casos v1 no-coinbase
   coinciden con los v0 (bytes y `txid` idénticos).
3. **Motor (`zx-consensus::transicion`):** `Garantia` con `nonce_siguiente`; comprobación F-15 antes
   que el resto de reglas de la operación (`ErrNonce`; en `aplicar_fusion`, descarte con motivo
   `ErrNonce`); undo del nonce; F-16 (`expiry_height == altura` en la coinbase PoW; génesis a altura 0)
   y F-17 (`slot` de la v3 = slot del bloque) ⇒ `ErrEmision`; F-18: salida de la liberación
   `(txid, 0)` y **se elimina** `prox_salida`.
4. **Arnés diferencial:** lee los dos ficheros v0.1; construye coinbases PoW con
   `expiry_height = altura`, coinbases PoST con `slot` del bloque y operaciones de garantía con el
   `nonce` del vector; sin claves de salida artificiales para evitar colisiones (F-15/F-16 las hacen
   innecesarias; si aún colisiona algo, **para** e infórmalo). Correspondencias: las de W03 más
   `ErrNonce ↔ ErrNonce`.
5. **Productor (`zx-post`):** la coinbase v3 que construye lleva el `slot` de su cabecera.

## 4. Verificación

| Paso | Qué | Criterio |
|---|---|---|
| V1–V2 | `fmt --check`, `clippy -D warnings --locked` | limpio |
| V3 | `cargo test --workspace --all-features --locked` | todos los tests previos con su nombre, más los nuevos |
| V4 | Diferencial contra `vectores-transicion-v0.1.txt` y `…-negativos-v0.1.txt` | 0 discrepancias |
| V5 | Tests propios: repetición de retiro/liberación (estricto: bloque inválido; fusión: descarte), dos coinbases PoW idénticas salvo altura (distintos `txid`), coinbase PoW con `expiry_height` ≠ altura, v3 con `slot` ≠ bloque | cada uno con su resultado |
| V6 | Oráculo de formato v0.1 (Julia): tests y vectores; v1 no-coinbase idénticos a v0 | OK |
| V7 | `dependencias-exactas.sh`, `frontera-crates.sh`; lock sin cambios de versión | OK |

**Prohibido Python.** Presupuesto: **2 h, 8 hilos, 16 GiB**.

## 5. Entregables y límites

Patrón W02/W04 (`ws.orig/`, `ws/`, `cambios.patch`, `MIGRACION.sha256`, `logs/`, `INFORME.md`,
`PROGRESO.md`, `HORAS.log`), más `oraculo-formato-v0.1/`. DeepSeek `deepseek-flash`, esfuerzo `high`;
LINEO antes del código; nada fuera de la zona; sin commit ni push; sin secretos; ningún `Ok` ficticio.

## Lanzamiento

    mkdir -p /home/katana/zeo/ZEROX/deepseek/W02b && cd /home/katana/zeo/ZEROX/deepseek/W02b && \
    ( set -a; . /home/katana/torio/deepseek-harness/.env >/dev/null 2>&1; set +a; \
      node /home/katana/torio/deepseek-harness/apps/cli/lib/bin.js --profile headless \
      "Orden W02b. Lee íntegro /home/katana/zeo/ZEROX/P-ZRX/P-FORMATO/ORDEN-W02b.md y cúmplelo. Antes de escribir código, lee íntegro /home/katana/zeo/ZEROX/V-ZRX/LINEO.md. Si detectas una falta de definición, infórmala antes de editar." \
      > ../W02b-dsh.stdout 2> ../W02b-dsh.stderr )
