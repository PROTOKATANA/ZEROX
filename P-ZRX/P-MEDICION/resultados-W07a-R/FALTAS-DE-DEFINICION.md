# Faltas de definición detectadas en ORDEN-W07a-R — informe al director

**Fecha:** 2026-09-27T07:01+02:00 (hora real en `HORAS.log`). **Ejecutor:** DeepSeek
(`deepseek-flash`, esfuerzo `high`). **Regla aplicada:** ORDEN-W07a-R §«Qué hacer» («si detectas
una falta de definición, infórmala **antes de editar**»).

La orden reutiliza el contrato ya ratificado en `REVISION-W07a.md` (12 lagunas de W07a, todas
aceptadas) y no vuelve a plantearlas. Las que siguen son **específicas del rebase** sobre la raíz
con W06d7 y se informan aquí. Ninguna cambia una regla de consenso, el orden de la tubería de
admisión ni una métrica del §3: son huecos de precisión sobre cómo instrumentar sobre la
estructura multi-terminal.

| # | Hueco | Lectura adoptada |
|---|---|---|
| 1 | La orden pide los accesos de lectura de `zx-cadena` «**del terminal seleccionado**» (W06d7 tiene un DAG por terminal). No dice qué devolver para un bloque que pertenece a un terminal **no** seleccionado. | Los accesos `datos_ghostdag`, `blue_score`, `mergeset_de` y `padre_seleccionado` resuelven **solo** contra el `DagTerminal` del terminal seleccionado; un bloque de otro terminal (o un PoW) no está en ese índice y devuelve `None`. `bloques_admitidos` sigue siendo el total global de válidos (PoW+PoST), que es lo que fija el §1. El test de `contexto_dag.rs` compara cada acceso con lo que ya calcula `zx-dag`. |
| 2 | W07a sustituyó el evento `bloque_red_ignorado_sin_penalizar` por un `bloque_red_rechazado` (etapa `cabecera`). La orden pide a la vez «el mismo comportamiento de W07a» (§1) y «**restaurar** los seis eventos retirados» (§1 bis). No dice si en ese caso deben convivir. | Conviven: se emite el evento de diagnóstico restaurado `bloque_red_ignorado_sin_penalizar` (campos originales) **y** la traza de §1 `bloque_red_rechazado` (etapa `cabecera`). Es «solo observación»: el `VeredictoFinal` no cambia. El analizador de W07c ignora el tipo desconocido, así que no hay doble cómputo de métricas. |
| 3 | El §1 bis manda conservar `bloque_red_pendiente` «con sus campos de entonces», pero W07a ya no emitía ninguna traza de rechazo para un bloque `Pendiente`. | Se restaura `bloque_red_pendiente` (hash, familia, motivo, veredicto) junto al `bloque_recibido` de §1; **no** se emite `bloque_red_rechazado`, porque un bloque `Pendiente` no es un rechazo demostrable (se reencola). Es la lectura de W07a, más el evento restaurado. |
| 4 | V3 exige «≥ 60 bloques PoST, con `--dejar-de-producir-en-slot` para que aparezca `dejar_de_producir`». Con esa bandera sola, `fase_regimen` entra en reposo activo **sin fin** y nunca se alcanza `parada` (que exige `--parada-tras-slots`). La orden también pide que el registro tenga «todos los tipos del §1 que esa ejecución puede producir». | Se lanza un **solo** V3 con tres nodos y banderas mixtas: dos nodos con `--parada-tras-slots` (producen, y emiten `parada`) y un tercero con `--dejar-de-producir-en-slot` (emite `dejar_de_producir` y queda en reposo hasta que el script lo detiene). Así el conjunto de registros de la ejecución cubre ambos tipos sin cambiar el código. `parada` queda además cubierta por el test V2. |
| 5 | `registro_esquema` (V2) de W07a trataba cualquier tipo fuera del §1 como error. Con los seis eventos restaurados, la propia §1 bis los admite como diagnóstico. | El test pasa a validar también los seis tipos de §1 bis (tipo desconocido sigue siendo error, pero los seis están declarados con sus campos). Su cobertura mínima en proceso no cambia: los seis, si aparecen, son válidos. |

**Alcance de la información.** El punto 1 se detalla antes de escribir los accesos (se escriben a
continuación); los puntos 2–5 se resuelven en la instrumentación y en el guion de V3. No se ha
detectado ninguna laguna que impida cumplir la orden tal como está escrita.
