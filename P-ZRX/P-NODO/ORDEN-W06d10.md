# ORDEN-W06d10 — Penalizar al par que difunde un bloque demostrablemente inválido

**LINEO (`V-ZRX/LINEO.md`) rige este código Rust**; léelo íntegro antes de escribir código.

## 1. Identidad y contexto

- **ID:** W06d10. **Fecha:** 2026-09-27 (≈ 21:45). **Director:** Claude. **Ejecutor:** DeepSeek
  (`deepseek-flash`, esfuerzo `high`).
- **Zona (única escribible):** `/home/katana/zeo/ZEROX/deepseek/W06d10/`. **Base:** la raíz en el commit de
  `ENTRADA-W06d10.sha256` (el código es idéntico al candidato `3d21b1f`); **no modifiques `ws.orig/`**. Puedes **leer**
  `deepseek/W07b/scripts/` (guiones de red real: `r4.sh` contiene E-7) y `deepseek/W07b/run/R4-rep1/e7e8/` (la
  medición que destapó el hallazgo); ninguna otra zona.
- **Motivo (hallazgo de W07b, E-7, 3/3 repeticiones):** `zx-adversario` difunde por gossipsub bloques con firma
  inválida (ZIP-215), PoT que no coincide y `bits` PoW incorrectos. El nodo los **rechaza** con su motivo y sin cambiar
  de estado, pero **no penaliza al par**: ningún `par_penalizado` en ningún registro. Lectura del director (a confirmar
  por ti con archivo:línea): en la ruta de gossip el veredicto `VeredictoFinal::Rechazar` solo llega a
  `report_message_validation_result(Reject)` (`crates/zx-p2p/src/servicio.rs` ≈ 666–690), y sin puntuación de pares de
  gossipsub configurada eso descarta el mensaje sin coste para quien lo mandó; la desconexión con
  `MotivoDesconexion::ViolacionDeConsenso` y el evento `par_penalizado` solo existen en la ruta de **sincronización**
  (`crates/zx-node/src/nodo.rs` ≈ 1528–1546). Consecuencia: un par puede difundir bloques inválidos sin límite, y cada
  uno cuesta verificación (3–34 ms medidos en W07b).
- **Pregunta falsable:** «Tras la corrección, un par que difunde un bloque demostrablemente inválido queda desconectado
  y penalizado según C-NET-05 y el nodo lo registra (`par_penalizado`); ningún par honesto es penalizado en operación
  normal ni en partición y reunión; en la red dev sobre `127.0.0.1` la penalización del adversario no desconecta ni veta
  a los nodos honestos.»

## 2. Decisiones del director

1. **Misma respuesta en gossip que en sincronización.** Cuando el veredicto final de un bloque difundido es `Rechazar`,
   `zx-p2p` desconecta al **propagador** con `MotivoDesconexion::ViolacionDeConsenso` (puntuación del prefijo según
   C-NET-05/C-NET-20, igual que `desconectar_con_motivo`) y avisa al nodo con un evento de red nuevo (p. ej.
   `EventoRed::ParPenalizado { peer, motivo, accion }`), para que `zx-node` escriba `par_penalizado` (`par`, `motivo`,
   `accion`) según `P-ZRX/P-MEDICION/ESQUEMA-REGISTRO-v1.md`. `Ignorar` **nunca** penaliza. Mantén el
   `report_message_validation_result(Reject)`.
2. **Solo lo demostrablemente inválido penaliza.** Antes de editar, lista en el informe **todos** los caminos por los
   que un bloque de red termina en `VeredictoFinal::Rechazar` (archivo:línea, motivo). Para cada uno, justifica que la
   invalidez **no depende de la vista local** (la juzgaría igual cualquier nodo honesto que tenga sus padres). Todo motivo
   que dependa de la vista local (p. ej. profundidad de reorganización o finalidad `C-FIN-01` frente a la punta propia,
   un terminal que no es el seleccionado, contexto PoT incompleto, huérfanos, duplicados) debe ser `Ignorar`, no
   `Rechazar`; si hoy alguno es `Rechazar`, **infórmalo antes de cambiarlo** (es una decisión de consenso de red, no
   tuya) y no lo toques sin respuesta.
3. **Red dev en `127.0.0.1`.** Todos los procesos de la red dev comparten el prefijo /24 de `127.0.0.1`: vetar ese
   prefijo por culpa del adversario dejaría fuera a los nodos honestos. Comprueba primero, con un test, qué pasa hoy
   (¿el veto de un prefijo corta también las conexiones existentes y rechaza las nuevas de otros pares del mismo
   prefijo?). Corrección: para direcciones **loopback** (`127.0.0.0/8`, `::1`), la penalización es por **`PeerId`**
   (desconexión y veto de ese `PeerId` en memoria, acotado como `MAX_BANEADOS`), no por prefijo. Fuera de loopback, sin
   cambios. Documenta en el código que es una excepción de la red local, no de producción.
4. **`zx-adversario`**: como el primer vector inválido ya le cuesta la conexión, que cada vector de E-7 se envíe desde
   una **identidad nueva** (`PeerId` nuevo y nueva conexión) para que los cuatro lleguen a juzgarse; deja constancia en
   su salida de qué `PeerId` usó en cada vector.
5. Ninguna regla de consenso cambia.

## 3. Contrato

Archivos permitidos: `crates/zx-p2p/src/{servicio.rs, limites_ip.rs, entrante.rs, error.rs, lib.rs}`,
`crates/zx-node/src/{nodo.rs, red/mod.rs, red/manejador.rs, rechazo.rs, bin/zx-adversario.rs}` y tests. Vedado el
resto; `Cargo.lock` sin cambios.

## 4. Verificación

| Paso | Qué | Criterio |
|---|---|---|
| V0 | `sha256sum -c` de la entrada; suite completa sin cambios | verde |
| V1 | Tabla de la decisión 2 (todos los `Rechazar` con su justificación) **antes** de editar | completa |
| V2 | Tests: bloque inválido por gossip → propagador desconectado, puntuado y `par_penalizado`; `Ignorar` (pendiente, huérfano, duplicado, `ImposibleSinPenalizar`) → sin penalización; ruta de sincronización sin cambios | todos |
| V3 | Tests de loopback: el adversario en `127.0.0.1` es vetado por `PeerId` y otros dos pares en `127.0.0.1` siguen conectados y pueden reconectar; fuera de loopback, la puntuación por prefijo sigue igual (tests existentes verdes) | todos |
| V4 | **Procesos reales, E-7 × 3** (guion de `r4.sh`, parte E-7, copiado a tu zona; una clave por nodo, `SR_dev = 13043817825332783104`, `N_dev` real, semillas 101/202/303): los cuatro vectores rechazados con su motivo, **`par_penalizado` en A para cada `PeerId` del adversario**, A sigue conectado a B y C, sin cambio de estado, y tras el reposo los tres con el mismo `resumen_estado` y `compendio_bloques` (método W07d: reabrir cada nodo aislado sobre una **copia** de `datos`) | todo |
| V5 | **Sin falsos positivos:** 3 repeticiones de tres nodos que cruzan el corte hasta el slot 150 y 1 partición E-6 con aislamiento real (`deepseek/W07b/scripts/r3_e6.sh`): **0 `par_penalizado`** entre nodos honestos | 0 |
| V6 | `fmt --check`, `clippy --workspace --all-targets --all-features --locked -- -D warnings`, `cargo test --workspace --all-features --locked`, los tres guardianes; T01/T04 en verde | limpio |

**Prohibido Python** (también para editar texto). Presupuesto: **3 h, 8 hilos**, `nice -n 5`. Patrón de las órdenes W
(`ws.orig/`, `ws/`, `cambios.patch`, `MIGRACION.sha256` como último paso), `INFORME.md`, `PROGRESO.md`, `HORAS.log`
(`date -Is` real), nombre de modelo. Nada fuera de la zona; sin git en el repositorio; sin secretos; ningún `Ok`
ficticio. Si falta una definición, infórmala **antes de editar**.
