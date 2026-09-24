# Corrección E1 · Inventario de reglas tras despacho parcial

Ejecuta con DeepSeek Harness `deepseek-v4.1-flash`, esfuerzo `high`. La orden anterior prohibía editar `ci/`; la revisión del líder confirma que `ci/citas-spec.sh` queda rojo precisamente porque ahora se citan `C-NET-25/26`. Esta corrección **amplía solo el inventario de dos reglas**, no el alcance de E1.

Archivos permitidos: `ci/reglas-sin-codigo.txt`, `ci/reglas-sin-cablear.txt`. No toques otros archivos, aunque los veas modificados por trabajo previo o concurrente. No hagas commit ni push.

1. Mueve los identificadores `C-NET-25` y `C-NET-26` de `reglas-sin-codigo.txt` a `reglas-sin-cablear.txt`, una sola vez cada uno. Mantén `C-NET-27/28` en `sin-codigo`.
2. Actualiza los comentarios junto a esos IDs para describir el estado exacto: `servicio.rs` clasifica `/blocks/1` y `/blocks/2` por igualdad exacta y decodifica `AnuncioCompacto`; `ManejadorEntrante` tiene callback cuyo default `Ignorar` no admite ni retransmite; `config.rs` continúa suscrito a `/blocks/1` y `zx-node` no valida ni reconstruye el DAG. El canal `/block-relay/1` tampoco está conectado como tal. Así, **ninguna de las dos reglas se cumple en la ruta activa**. La vieja frase que dice que el dispatcher aún usa `contains` debe actualizarse, porque dejó de ser cierta en el código preparado.
3. No muevas C-NET-12, C-NET-06 ni ninguna regla adicional. El archivo `sin-cablear` admite código parcial; no presentes C-NET-25/26 como completas. Comprueba `ci/citas-spec.sh`, `git diff --check` y `git diff -- ci/reglas-sin-codigo.txt ci/reglas-sin-cablear.txt`. Informa del resultado exacto.
