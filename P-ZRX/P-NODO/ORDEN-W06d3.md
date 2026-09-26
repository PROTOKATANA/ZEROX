# ORDEN-W06d3 — PoST por red, bifurcaciones PoW y tres nodos de extremo a extremo

## 1. Identidad y contexto

- **ID:** W06d3. **Fecha:** 2026-09-26. **Director:** Claude. **Ejecutor:** subagente **Sonnet**, único,
  con revisor independiente después. Absorbe lo que el plan llamaba W06e (integración multinodo).
- **Zona (única escribible):** `/home/katana/zeo/ZEROX/deepseek/W06d3/`.
- **Motivo (`REVISION-W06d2.md`):** dos huecos (ambos errores del director) impiden demostrar el
  criterio de cierre de W06 (`PLAN-W06.md` §3):
  1. `zx_p2p::mensaje::BloqueRed::Post` lleva cabecera, transacciones y testigos, pero **no la
     justificación PoT**, sin la cual ningún nodo puede verificar un bloque PoST ajeno.
  2. `zx-node` valida cada bloque PoW contra `historial_pow.last()` (su propia punta), no contra su padre
     declarado: no puede seguir una bifurcación PoW ni reorganizarse, aunque `zx-cadena` sí sabe elegir.
- **Pregunta falsable:** «Tres procesos `zx-node` en `127.0.0.1`, desde el génesis, minan, depositan,
  fijan **el mismo** terminal, producen y **verifican por red** bloques PoST ajenos, y convergen a la misma
  punta y al mismo resumen de estado; un cuarto que llega tarde sincroniza al mismo estado; tras una
  partición y reunión (en fase PoW y en fase PoST) vuelven a converger.»

## 2. Entradas

Lee íntegros: este archivo; `V-ZRX/LINEO.md` (rige todo el código, `AUTO-ZRX.md` §52);
`P-ZRX/P-NODO/PLAN-W06.md`; `P-ZRX/P-MEDICION/ESCENARIOS-0.0.1.md`; las revisiones de W06c, W06d1,
W06d2, W06a-C, RI-2a y RI-2b; el código de la raíz. Base: la raíz. Entrada congelada:
`P-ZRX/P-NODO/ENTRADA-W06d3.sha256`.

## 3. Decisiones del director

1. **Formato de red:** `BloqueRed::Post` transporta el `zx_core::wire_dag::BloqueDag` completo
   (cabecera, `JustificacionPot`, cuerpo), con su códec `bloque_dag_a_bytes`/`bloque_dag_desde_bytes`,
   que es también lo que guarda `zx-storage`. La frontera `zx-p2p → {zx-core}` no cambia. Límites de
   tamaño en `zx-p2p::limites` actualizados y declarados.
2. **Verificación de PoST ajenos:** con la justificación, la tubería única verifica cabecera, PoT, PoAS,
   sello y padres (GHOSTDAG real vía `Cadena::contexto_dag`, no el atajo `ContextoTransicion`, salvo en
   el primer bloque tras el terminal, ya documentado) antes de `Aceptar` en la validación diferida.
3. **Bifurcaciones PoW:** el nodo valida cada bloque PoW contra el estado de **su padre declarado** (que
   `zx-cadena` ya mantiene) y su plantilla de minado sigue la punta PoW **seleccionada** por
   `zx-cadena`. Reorganización con undo exacto (ya probado en el diferencial); tests de bifurcación y
   reunión.
4. **Diagnóstico** de la desconexión intermitente de la ráfaga de huérfanos (`REVISION-W06d2.md`, V7): causa
   con evidencia, o, si no se encuentra, el procedimiento que la reproduce.
5. **Prueba de reinicio:** demuestra que ya no es intermitente con **5 ejecuciones seguidas** de
   `cargo test -p zx-node --test reinicio --locked` (no hace falta repetir el workspace entero).

## 4. Verificación

| Paso | Qué | Criterio |
|---|---|---|
| V1–V3 | `fmt --check`, `clippy -D warnings --locked`, `cargo test --workspace --all-features --locked` | limpio; todo lo previo con su nombre |
| V4 | Tres procesos reales desde el génesis cruzan el corte y producen ≥ 60 bloques PoST entre todos, con bloques PoST **ajenos** verificados por red | mismo terminal; misma punta y resumen de estado al terminar; 0 bloques honestos rechazados |
| V5 | Cuarto proceso tras ≥ 200 bloques | sincroniza al mismo resumen |
| V6 | Partición y reunión: (a) en fase PoW, antes del corte; (b) en fase PoST, ≥ 20 slots | convergen; profundidad de reorganización registrada; en (a), un único terminal según FC-3 |
| V7 | `zx-adversario` con entradas PoST: PoAS, PoT y sello malos; coinbase mayor que el subsidio; E-8 (dos bloques de la misma clave y slot) | rechazo con motivo y penalización (E-8: registrado); CPU por entrada inválida medida |
| V8 | 5 ejecuciones seguidas de la prueba de reinicio | 5/5 |
| V9 | `dependencias-exactas.sh`, `frontera-crates.sh`; lock sin cambios de versión | OK |

`N_dev` pequeño en las pruebas; una ejecución de V4 con `N_dev` real, conservada en `logs/`. **Prohibido
Python.** Presupuesto: **4 h, 8 hilos, 16 GiB**.

## 5. Entregables y límites

Patrón de las órdenes W; en `ws.orig/` y `ws/` solo lo necesario para compilar y probar (no los
documentos). **Un solo ejecutor: prohibido lanzar subagentes o forks.** Espera a que terminen tus pruebas
antes de informar; genera `cambios.patch` y `MIGRACION.sha256` como **último** paso. Nada fuera de la zona;
sin git; sin secretos; ningún `Ok` ficticio (si algo no se puede verificar, `Ignorar` y se declara).
