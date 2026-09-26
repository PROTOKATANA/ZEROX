# ORDEN-W06a-B — Diferenciales sin emulación de ids contra los oráculos T01-E y T04-D

- **ID:** W06a-B. **Fecha:** 2026-09-26. **Director:** Claude. **Ejecutor:** DeepSeek. Se lanza tras
  revisar T01E-T04D.
- **Zona (única escribible):** `/home/katana/zeo/ZEROX/deepseek/W06aB/`.
- **Motivo:** `REVISION-W06a.md` («Reserva»): `crates/zx-cadena/tests/diferencial_t04.rs` emula
  colisiones de ids del oráculo añadiendo entradas inexistentes (`detectar_colisiones`, `forzada`), y
  `crates/zx-consensus/tests/diferencial_t01.rs` mantiene un espejo del contador `prox_salida`. Con
  T01-E/T04-D el id de la salida de una liberación es `ID_LIB(clave, nonce, importe)` (inyectivo, como
  F-18) y ninguna de las dos cosas debe hacer falta.
- **Pregunta falsable:** «Sin emulación, el motor y `zx-cadena` coinciden con T01 (v0.2, base y
  negativos) y con T04 (v0.3) en todos los casos, y la cobertura del arnés es idéntica a
  `cobertura-v0.3.txt`.»

## Qué hacer

1. Copia la raíz a `ws.orig/` y `ws/` (enlace `ws/PDF` excluido de la migración). **Primero** ejecuta
   `cargo test --workspace --all-features --locked` en `ws/` sin cambios y guarda el resultado: es la
   primera ejecución completa de la raíz con W05b3 y W06a juntas (`REVISION-W06a.md`, «Migración»).
2. En los dos arneses: el id abstracto `≥ 2⁶²` se decodifica como `(clave, nonce, importe)` y se
   traduce a `(txid, 0)` de la liberación real construida con esos datos; se eliminan
   `detectar_colisiones`, `forzada`, el punto fijo y el espejo de `prox_salida`. Ninguna transacción
   real lleva entradas inventadas.
3. `testdata/`: añade los vectores T01 v0.2 (base y negativos) y T04 v0.3 con `cobertura-v0.3.txt` y
   su `PROCEDENCIA.md`; los arneses pasan a leerlos (conserva los anteriores).
4. Correspondencias: las vigentes (W03, W02b, W06a); **ninguna nueva sin parar**.

## Verificación

| Paso | Qué | Criterio |
|---|---|---|
| V0 | Suite completa de la raíz sin cambios | resultado literal (si falla algo, **para** e informa) |
| V1–V2 | `fmt --check`, `clippy -D warnings --locked` | limpio |
| V3 | `cargo test --workspace --all-features --locked` | todos los previos con su nombre |
| V4 | `diferencial_t01` (v0.2 base y negativos) y `diferencial_t04` (v0.3) | **0 discrepancias**; `grep` de `forzad`, `colision` y `prox_salida` en los arneses: vacío |
| V5 | Cobertura del arnés | idéntica a `cobertura-v0.3.txt` |
| V6 | `dependencias-exactas.sh`, `frontera-crates.sh`; lock sin cambios | OK |

**Prohibido Python.** Presupuesto: **1 h 30 min, 8 hilos, 16 GiB**. Patrón de entregables de las
órdenes W (`cambios.patch`, `MIGRACION.sha256`, `logs/`, `INFORME.md`, `PROGRESO.md`, `HORAS.log`).
Cargo desde `ws/` con `GIT_CEILING_DIRECTORIES`, `CARGO_HOME` y `CARGO_TARGET_DIR` en la zona. DeepSeek
`deepseek-flash`, esfuerzo `high`; LINEO; nada fuera de la zona; sin commit ni push; sin secretos.
Entrada congelada `P-ZRX/P-NODO/ENTRADA-W06a-B.sha256`.

## Lanzamiento

    mkdir -p /home/katana/zeo/ZEROX/deepseek/W06aB && cd /home/katana/zeo/ZEROX/deepseek/W06aB && \
    ( set -a; . /home/katana/torio/deepseek-harness/.env >/dev/null 2>&1; set +a; \
      node /home/katana/torio/deepseek-harness/apps/cli/lib/bin.js --profile headless \
      "Orden W06a-B. Lee íntegro /home/katana/zeo/ZEROX/P-ZRX/P-NODO/ORDEN-W06a-B.md y cúmplelo. Antes de escribir código, lee íntegro /home/katana/zeo/ZEROX/V-ZRX/LINEO.md. Si detectas una falta de definición, infórmala antes de editar." \
      > ../W06aB-dsh.stdout 2> ../W06aB-dsh.stderr )
