# ORDEN-SL4b3 — Bloque de transición con firmante seguro, funciones sin firmante fuera del alcance del nodo, y tests de inclusión

**LINEO (`V-ZRX/LINEO.md`) rige este código Rust**; léelo íntegro antes de escribir código.

- **ID:** SL-4b3. **Fecha:** 2026-09-27 (≈ 09:48). **Director:** Claude. **Ejecutor:** DeepSeek
  (`deepseek-flash`, esfuerzo `high`). **Zona (única escribible):** `/home/katana/zeo/ZEROX/deepseek/SL4b3/`.
  **Base:** la raíz en el commit de `ENTRADA-SL4b3.sha256`; no leas otras zonas de `deepseek/` salvo
  `deepseek/SL4b2/` (solo lectura). **No modifiques `ws.orig/`** tras copiarlo.
- **Motivo:** `P-ZRX/P-SLASHING/REVISION-SL4b2.md`, defectos 1 y 2.

## Qué hacer (decisiones del director)

1. `producir_bloque_transicion` (`crates/zx-node/src/nodo.rs`) produce con `producir_con_firmante` y el mismo
   firmante del nodo que usa el régimen; si el resultado es `Abstenido`, no produce (evento `firmante_abstenido`
   del esquema) y lo reintenta en el siguiente slot como hoy.
2. Las funciones sin firmante de `zx-post` (`productor::producir`, `productor_regimen::producir_en_regimen`) se
   **renombran** a `producir_sin_firmante` y `producir_en_regimen_sin_firmante`, con documentación «solo tests y
   arneses; no protege contra la doble firma»; se actualizan sus llamantes en tests. Nuevo guardián
   `ci/firmante-obligatorio.sh` (en el estilo de `ci/frontera-crates.sh`, **bash**, sin Python): falla si
   `crates/zx-node/src/` contiene `_sin_firmante`. Se añade al paso de guardianes de
   `.github/workflows/zerox-ci.yml`.
3. Tests unitarios de la inclusión de evidencias en `zx-node` (los de V2 de SL-4b2): pendiente con ventana abierta
   → incluida; incidente ya procesado en el estado base → no; ventana cerrada → no y sale de la lista; bloque
   portador fuera de la cadena seleccionada tras una reorganización → vuelve a ser elegible. Cada uno con su
   aserción.

## Verificación

`fmt --check`, `clippy --workspace --all-targets --all-features --locked -- -D warnings`, `cargo test --workspace
--all-features --locked` (todo lo previo con su nombre + lo nuevo), `ci/dependencias-exactas.sh`,
`ci/frontera-crates.sh`, `ci/firmante-obligatorio.sh` (y comprobar que falla si se reintroduce una llamada, en una
copia). Una ejecución real corta: tres nodos cruzan el corte; el registro del firmante de cada nodo contiene la
entrada del slot de su bloque de transición (léelo con la API de lectura del registro en un test o en la
herramienta que ya exista; no inventes un formato). `cambios.patch` y `MIGRACION.sha256` como último paso.

**Prohibido Python** (también para editar texto). Presupuesto: **1 h 30 min, 8 hilos**, `nice -n 10`.
`INFORME.md`, `PROGRESO.md`, `HORAS.log` (`date -Is` real), nombre de modelo de la API. Nada fuera de la zona; sin
git en el repositorio; sin secretos; ningún `Ok` ficticio; si una prueba falla, se informa. Si detectas una falta
de definición, infórmala **antes de editar**.
