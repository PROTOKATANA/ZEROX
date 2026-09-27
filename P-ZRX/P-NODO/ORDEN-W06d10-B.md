# ORDEN-W06d10-B — Lo que depende de la vista local no penaliza al par

**LINEO (`V-ZRX/LINEO.md`) rige este código Rust**; léelo íntegro antes de escribir código.

## 1. Identidad y contexto

- **ID:** W06d10-B. **Fecha:** 2026-09-27 (≈ 23:55). **Director:** Claude. **Ejecutor:** DeepSeek (`deepseek-flash`,
  esfuerzo `high`).
- **Zona (única escribible):** `/home/katana/zeo/ZEROX/deepseek/W06d10-B/`. **Base:** la raíz en el commit de
  `ENTRADA-W06d10-B.sha256` (incluye W06d10 migrada); **no modifiques `ws.orig/`**. Puedes **leer**
  `deepseek/W06d10/` (su `PROGRESO.md` §0.2 es la tabla de partida y sus guiones de V4/V5); ninguna otra zona.
- **Motivo (V1 de W06d10, `P-ZRX/P-NODO/REVISION-W06d10.md`):** tres familias de `VeredictoFinal::Rechazar` dependen de la
  **vista local** del nodo y penalizan al par (ruta de sincronización desde W07a; gossip desde W06d10):
  - **X1:** `ErrorPow::TimestampDemasiadoFuturo` (C-TS-03, `nodo.rs` ≈ 652–661). Depende del reloj local, y el propio
    tipo lo declara no permanente (`es_permanente() == false`).
  - **X2:** `MotivoBloque::ErrLimiteTerminales` (`nodo.rs` ≈ 717–723 y ≈ 1974–1988). Tope **local** de terminales con
    DAG.
  - **X3:** `ErrorNodo::Otro` por fallos **locales** (persistencia, `asegurar_servicios_verificacion`,
    `observar_para_detector`; `nodo.rs` ≈ 730–752 y ≈ 1974–1988).
- **Pregunta falsable:** «Tras la corrección, ninguno de X1–X3 penaliza al par ni deja el bloque marcado como inválido
  para siempre, en ninguna de las dos rutas; lo demostrablemente inválido sigue penalizando igual.»

## 2. Decisiones del director

1. **X1, X2 y X3 → `Ignorar`** en gossip y en sincronización: sin desconexión, sin puntuación, sin `par_penalizado`, y
   **sin cachear el bloque como inválido**, para que pueda volver a juzgarse cuando la vista cambie. X1 debe poder admitirse
   más tarde si vuelve a llegar cuando el reloj local ya lo permita (C-TS-03: se difiere, no se castiga).
2. X3 sigue siendo visible: registra el fallo local con su motivo, en un evento de diagnóstico existente o en uno nuevo
   del §1 bis de `ESQUEMA-REGISTRO-v1.md`. **No cambies** si un fallo local es fatal o no para el nodo: solo cambia lo que
   se le hace al par.
3. Ninguna regla de validez cambia: el bloque sigue sin admitirse mientras no cumpla.
4. Si al revisar encuentras **otro** `Rechazar` que dependa de la vista local y no esté en la tabla de W06d10, infórmalo
   y trátalo igual.

## 3. Contrato

Archivos permitidos: `crates/zx-node/src/{nodo.rs, rechazo.rs, red/sync.rs, red/manejador.rs, error.rs}` y tests.
Vedado el resto, en particular `zx-consensus`, `zx-cadena` y `zx-p2p`; `Cargo.lock` sin cambios.

## 4. Verificación

| Paso | Qué | Criterio |
|---|---|---|
| V0 | `sha256sum -c` de la entrada; suite completa sin cambios | verde |
| V1 | Tests por familia, en las dos rutas: X1 (bloque PoW con `timestamp > reloj + FTL`: `Ignorar`, sin `par_penalizado`, no cacheado; admitido al reenviarlo con el reloj avanzado), X2 (noveno terminal que no supera al peor: `Ignorar`), X3 (fallo local simulado: `Ignorar` y fallo registrado) | todos |
| V2 | Regresión: un bloque demostrablemente inválido sigue dando `Rechazar` y `par_penalizado` en las dos rutas (tests de W06d10 verdes) | verde |
| V3 | **Procesos reales:** 1 repetición de E-7 (guion de W06d10, semilla 101): 4 `par_penalizado` y convergencia W07d; 1 red de tres nodos al slot 150: 0 `par_penalizado` | ambos |
| V4 | `fmt --check`, `clippy --workspace --all-targets --all-features --locked -- -D warnings`, `cargo test --workspace --all-features --locked`, los tres guardianes; T01/T04 en verde | limpio |

**Prohibido Python** (también para editar texto). Presupuesto: **1 h 30 min, 8 hilos**, `nice -n 5`. Patrón de las
órdenes W (`ws.orig/`, `ws/`, `cambios.patch`, `MIGRACION.sha256` como último paso), `INFORME.md`, `PROGRESO.md`,
`HORAS.log` (`date -Is` real), nombre de modelo. Nada fuera de la zona; sin git en el repositorio; sin secretos; ningún
`Ok` ficticio. Si falta una definición, infórmala **antes de editar**.
