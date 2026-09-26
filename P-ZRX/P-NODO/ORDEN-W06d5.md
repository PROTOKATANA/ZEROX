# ORDEN-W06d5 — Robustez del nodo en red: nodo tardío, padres extra, rechazos legítimos, partición PoST

**LINEO (`V-ZRX/LINEO.md`) rige este código Rust** (`AUTO-ZRX.md` §52); aplica sus reglas pertinentes.

## 1. Identidad y contexto

- **ID:** W06d5. **Fecha:** 2026-09-26. **Director:** Claude. **Ejecutor:** subagente **Sonnet**, único.
- **Zona (única escribible):** `/home/katana/zeo/ZEROX/deepseek/W06d5/`.
- **Motivo (`REVISION-W06d4.md`):** tres nodos reales ya cruzan el corte y convergen (V4). Quedan V5 (nodo
  tardío), V6(b) (partición y reunión en PoST) y V7 (`zx-adversario`), cada uno con su causa identificada.
- **Pregunta falsable:** «Con las correcciones de esta orden, un cuarto nodo que llega tarde sincroniza y
  convive sin tirar a los demás; tras una partición en fase PoST de ≥ 20 slots los nodos vuelven a converger;
  y ninguna entrada inválida de `zx-adversario` se acepta ni tira el nodo.»

## 2. Decisiones del director

0. **Primero:** suite completa de la raíz sin cambios (`logs/V0.log`). Es la primera ejecución conjunta de
   W06d4 y SL-4a (evidencia en `zx-core`, motor y `zx-cadena`). Si falla, **para** e informa.
1. **Producir solo con garantía:** el nodo no intenta producir con una clave sin garantía activa `≥ q` en el
   estado de las puntas elegidas (causa de `ErrGarantia` en V5). Test.
2. **Padres extra:** el filtro de padres de `crates/zx-node/src/regimen.rs` excluye **todo** padre, no solo el
   seleccionado, cuyo slot no sea anterior al del bloque (causa de `Padres(SlotDePadrePosterior)`). Test.
3. **Rechazos legítimos:** la regla de W06d1 «bloque propio rechazado ⇒ fallo fatal» se sustituye por:
   rechazo **legítimo** del protocolo (el bloque no cumple una regla por un caso de borde real) ⇒ se registra
   con su motivo y se descarta el bloque, el nodo sigue; **violación de invariante interna** (un estado que
   el propio código garantiza imposible) ⇒ fatal. Enumera qué motivos van a cada lado, con su justificación.
4. **Partición PoST (V6b):** la prueba se calibra para que la reunión ocurra dentro de `F_SLOTS` (más `N_dev`
   o menos tiempo de partición, declarado); lo que sí es una regla (RD-5, `ErrMergeDepth`) no se toca.
5. **`zx-adversario`:** espera a que el objetivo esté suscrito al tema (evento de suscripción de gossipsub)
   antes de publicar; repite E-7 completo.

## 3. Verificación

`fmt --check`, `clippy -D warnings --all-targets --all-features --locked`, `cargo test --workspace
--all-features --locked` (todo lo previo con su nombre + lo nuevo), `dependencias-exactas.sh`,
`frontera-crates.sh`, lock sin cambios de versión; y con procesos reales en `127.0.0.1`: **V4** otra vez
(regresión), **V5**, **V6(b)** y **V7**, con logs conservados. **Prohibido Python.** Presupuesto: **4 h, 8
hilos, 16 GiB**; si se agota, entrega lo hecho y lo que falta.

## 4. Entregables y límites

Patrón de las órdenes W; en `ws.orig/` y `ws/` solo `Cargo.toml`, `Cargo.lock`, `rust-toolchain.toml`,
`crates/`, `testdata/`, `ci/`, `.github/` y el enlace `ws/PDF`. **Un solo ejecutor: prohibido lanzar
subagentes o forks.** Procesos largos en segundo plano con su PID y su log anotados en `PROGRESO.md`
**antes** de esperarlos; al retomar tras un corte, lee primero `PROGRESO.md`. `cambios.patch` y
`MIGRACION.sha256` como **último** paso con `sha256sum -c` en verde. Sin procesos huérfanos. Nada fuera de la
zona; sin git; sin secretos. Entrada congelada: `P-ZRX/P-NODO/ENTRADA-W06d5.sha256`.
