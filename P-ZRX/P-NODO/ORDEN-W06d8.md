# ORDEN-W06d8 — Protocolo productor↔bucle robusto (panic de `regimen.rs:438`) y ningún pánico alcanzable en el nodo

**LINEO (`V-ZRX/LINEO.md`) rige este código Rust**; léelo íntegro antes de escribir código.

## 1. Identidad y contexto

- **ID:** W06d8. **Fecha:** 2026-09-27 (≈ 12:21). **Director:** Claude. **Ejecutor:** DeepSeek
  (`deepseek-flash`, esfuerzo `high`).
- **Zona (única escribible):** `/home/katana/zeo/ZEROX/deepseek/W06d8/`. **Base:** la raíz en el commit de
  `ENTRADA-W06d8.sha256`; **no modifiques `ws.orig/`**; no leas otras zonas de `deepseek/` salvo
  `deepseek/W07b/run/E2a-calibracion-intento4-panic-productor/` (solo lectura: los registros del fallo).
- **Motivo (hallazgo de W07b, verificado por el director en el código):** con tres nodos cruzando el corte con
  `SR_dev = u64::MAX` (ráfagas de bloques del mismo slot y reorganizaciones inmediatas), el hilo productor de un
  nodo entró en pánico: `crates/zx-node/src/regimen.rs:438`, «se esperaba Continuar/Parar, llegó Padres». El hilo
  productor y el bucle del nodo hablan por turnos (petición de padres → `Padres` → bloque → `Continuar`/`Parar`);
  cuando `recibir_o_cambiar_terminal` devuelve `Interrumpido` (cambio de terminal en caliente, SL-4b2 decisión 0), el
  productor sigue **sin** consumir la respuesta pendiente, y esa respuesta atrasada llega después, donde se espera
  otra cosa. Hay más `panic!` del mismo tipo en ese protocolo (líneas ≈ 288, 413, 438).
- **Pregunta falsable:** «Con peticiones y respuestas numeradas, el productor descarta toda respuesta atrasada sin
  pánico; ningún mensaje que el bucle pueda enviar tira el hilo; y tres nodos que cruzan el corte con
  `SR_dev = u64::MAX` (el caso que falló) terminan sin pánico en 5 repeticiones.»

## 2. Decisiones del director

1. **Numeración:** cada petición del productor (`PeticionPadres`, `Post`, `Abstenido`) lleva un `id: u64`
   creciente; cada respuesta del bucle (`Padres`, `Continuar`) lleva el `id` al que responde. Al esperar la
   respuesta `n`, el productor **descarta** cualquier respuesta con `id < n` (evento de diagnóstico
   `productor_respuesta_descartada` con ambos `id`), atiende `Parar` siempre, y trata `id > n` como violación de
   invariante (punto 3). `CambiarTerminal` se sigue absorbiendo como hoy.
2. **Sin pánicos alcanzables:** en el código no-test de `zx-node`, enumera **cada** `panic!`, `unreachable!`,
   `expect`, `unwrap` e indexación que pueda fallar, y clasifícalo en una tabla del informe: (a) invariante que el
   propio código garantiza (se deja, con un comentario que cite la garantía) o (b) situación alcanzable por
   carreras, red o datos (se convierte en manejo explícito). Nada alcanzable por un par o por una carrera puede
   quedar como pánico.
3. **Fallo del hilo productor = parada ordenada del nodo, no nodo a medias:** si el hilo productor termina por una
   violación de invariante, el bucle lo detecta, escribe el evento crítico `fallo_productor` con el motivo y el
   proceso **sale con código distinto de cero**. Nunca debe quedar un nodo que valida pero ha dejado de producir sin
   decirlo.

## 3. Verificación

| Paso | Qué | Criterio |
|---|---|---|
| V0 | `sha256sum -c` de la entrada; suite completa sin cambios | verde |
| V1 | Tests del protocolo con un bucle simulado que inyecta: `Padres` atrasado tras `Interrumpido`; `Continuar` duplicado; `Parar` en cada punto de espera; `id` del futuro | sin pánico; descarte, parada o fallo ordenado según el punto 1/3 |
| V2 | Tabla del punto 2 completa, con archivo:línea de cada caso y su clasificación | todos los alcanzables convertidos |
| V3 | **Procesos reales:** tres nodos, una clave por nodo (A = 0, B = 1, C = 2), `SR_dev = u64::MAX`, cruzan el corte y producen ≥ 200 bloques PoST entre los tres; **5 repeticiones** | 0 pánicos, 0 procesos muertos; `productor_respuesta_descartada` aparece si la carrera ocurre (se cuenta) |
| V4 | `fmt --check`, `clippy --workspace --all-targets --all-features --locked -- -D warnings`, `cargo test --workspace --all-features --locked`, los tres guardianes de `ci/` | limpio |

**Prohibido Python** (también para editar texto). Presupuesto: **2 h, 4 hilos, `nice -n 19`** (W07b está calibrando
con procesos reales en la misma máquina). Patrón de las órdenes W (`ws.orig/`, `ws/`, `cambios.patch`,
`MIGRACION.sha256` como último paso), `INFORME.md`, `PROGRESO.md`, `HORAS.log` (`date -Is` real), nombre de modelo.
Archivos permitidos: `crates/zx-node/**`. Nada fuera de la zona; sin git en el repositorio; sin secretos; ningún `Ok`
ficticio. Si falta una definición, infórmala **antes de editar**.
