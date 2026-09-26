# REVISIÓN RI-3a — revisión independiente de la red (`zx-p2p`, `zx-node/src/red/`)

**Revisor de la revisión:** Claude (director). **Fecha:** 2026-09-26 (≈ 23:09). **Ejecutor:** subagente Sonnet,
22:49–23:06. Evidencia: `resultados-RI-3a/` (informe y los tres tests de reproducción, con huellas).
**Veredicto: ACEPTADA.** Tres hallazgos altos confirmados, todos de **disponibilidad** (ninguno hace aceptar un
bloque inválido); uno bajo plausible. Entrada `ENTRADA-RI-3.sha256` verificada por el revisor; `deepseek/W06d5/`
sin tocar.

| # | Hallazgo | Comprobación del director | Decisión |
|---|---|---|---|
| 1 (alta, CONFIRMADO) | `Peticion::Bloques` con el mismo hash repetido hasta 256 veces: `VistaRed::bloques_por_hash` (`crates/zx-node/src/red/vista.rs:147-160`) **clona** cada repetición y `servir` (`crates/zx-p2p/src/servicio.rs:501-509`) recorta a 16 **después**; medido: 157 MB clonados y 453 ms del hilo que atiende el `Swarm` por una petición de ≈ 8 KiB | Leído: el orden es el descrito | **Corregir antes de W07b:** deduplicar y recortar a `MAX_BLOQUES_POR_RESPUESTA` **antes** de clonar, cortar al llegar a `MAX_RESPUESTA_BYTES`, y penalizar la petición con hashes repetidos (un honesto no la envía) |
| 2 (alta, CONFIRMADO) | `leer_acotado` (`crates/zx-p2p/src/codec.rs:215-240`) reserva `max + 1` (≈ 32,4 MiB para una respuesta) **antes** de leer un byte y lo retiene hasta el plazo; siete flujos silenciosos de un solo par agotan el presupuesto agregado de 256 MiB y el nodo deniega a los honestos | Leído: la reserva es previa y del tamaño máximo; el comentario C-NET-21 justifica reservar antes, no reservar el máximo | **Corregir:** reserva **incremental** por trozos (p. ej. 64 KiB) antes de leer cada trozo; lo reservado nunca supera lo leído más un trozo |
| 3 (alta, CONFIRMADO) | La cola `TrabajoRed` hacia el hilo de consenso es un `unbounded_channel` (`crates/zx-node/src/red/mod.rs:203`): 40 960 bloques encolados en 16,7 ms sin rechazo | Leído | **Corregir:** cola acotada en elementos y en bytes; al llenarse, descartar lo nuevo sin bloquear la red, con evento `limite_alcanzado`; declarar que un bloque honesto descartado se recupera por la petición de padres o por la sincronización |
| 4 (baja, PLAUSIBLE) | `cabeceras_desde` recorre todo el historial PoW por cada hash del localizador | Leído | Corregir en la misma orden si es barato (índice hash → altura); si no, IPA |

**Dónde se corrigen:** en **W06d6** (cambio de ≈ 00:42: W06d5 dejó pendiente la sincronización PoST, que toca los
mismos archivos de red; antes se habían asignado a la parte A de W07a); los tres tests de reproducción pasan a ser **regresiones** que
deben fallar antes de la corrección y pasar después.
