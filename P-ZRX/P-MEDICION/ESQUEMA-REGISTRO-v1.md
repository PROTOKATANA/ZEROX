# Esquema del registro estructurado del nodo, v1 (contrato entre W07a, W07b y W07c)

**Fecha:** 2026-09-26. **Firma:** Claude (director). **Estado:** contrato de diseño; lo implementa W07a en
`zx-node`, lo produce W07b en las ejecuciones y lo consume el analizador de W07c. Sustituye a los requisitos
del §1 de `ESCENARIOS-0.0.1.md` en lo que concreta; no cambia ninguna regla de consenso.

## 0. Reglas generales

- Un archivo por nodo y ejecución, **una línea JSON por evento**, UTF-8, sin líneas vacías. El nodo escribe
  con `sync` los eventos marcados «crítico»; los demás pueden perderse en un `SIGKILL` (el analizador lo
  tolera: una última línea truncada se descarta y se cuenta).
- Campos comunes a todo evento, en este orden: `tipo` (texto), `reloj_ns` (entero, reloj monotónico del
  proceso en ns), `reloj_pared_ns` (entero, `CLOCK_REALTIME` en ns desde la época Unix). **Las latencias
  entre nodos se calculan con `reloj_pared_ns`** (mismo anfitrión, mismo reloj); las duraciones dentro de un
  nodo, con `reloj_ns` o con los campos `t_*_ns`.
- Hashes en hexadecimal minúsculo de 64 caracteres (como hoy). `familia` ∈ {`pow`, `post`}. `par` = el
  `PeerId` de libp2p en texto; `"local"` si el bloque lo produjo el propio nodo.
- Un campo que el nodo no puede calcular se **omite** (no se escribe `0` ni `-1`). El analizador trata la
  ausencia como «no medido» y la cuenta; nunca la imputa.
- Enteros sin signo en decimal. Tiempos siempre en ns. Tamaños siempre en bytes de la serialización de red.
- `version_esquema: 1` aparece en `arranque`. Un registro sin él es v0 (W06d1…W06d5): el analizador lo
  acepta y solo calcula lo que v0 permite (§3).

## 1. Eventos

| `tipo` | Cuándo | Campos (además de los comunes) | Crítico |
|---|---|---|---|
| `arranque` | al terminar el arranque | `version_esquema`, `n_dev`, `sr_dev`, `claves` (texto `0,1`), `peer_id` (si hay red), `red_escuchar` (si hay), `modo` ∈ {`limpio`, `reinicio`} | sí |
| `reinicio_completo` | al terminar la repetición del almacén | `bloques_repetidos`, `duracion_ns` | sí |
| `bloque_minado` | bloque PoW propio admitido localmente | `hash`, `altura`, `bytes`, `n_txs` | no |
| `bloque_producido` | bloque PoST propio admitido y persistido | `hash`, `slot`, `n_padres`, `n_txs`, `bytes`, `retraso_slot_ns` (desde que el nodo tuvo la salida PoT de ese slot hasta este evento), `azules_mergeset`, `rojos_mergeset` | no |
| `bloque_recibido` | bloque llegado por red, **antes** de verificar nada | `hash`, `familia`, `par`, `bytes` | no |
| `bloque_red_admitido` | admitido y persistido | `hash`, `familia`, `par`, `slot` (post) o `altura` (pow), `n_padres` (post), `bytes`, `t_cabecera_ns` (post: puerta conjunta sello + PoT + PoAS + padres; pow: verificación PoW), `t_admision_ns` (`zx-cadena`: GHOSTDAG y estado), `t_persistencia_ns`, `t_total_ns` (de `bloque_recibido` a este evento, cola incluida), `n_bloques_dag` (bloques admitidos en la cadena tras admitir este), `azules_mergeset`, `rojos_mergeset` (post), `txs_descartadas` (post: descartes por fusión en este bloque) | no |
| `bloque_red_rechazado` | rechazado | `hash`, `familia`, `par`, `etapa` ∈ {`decodificacion`, `limite`, `cabecera`, `admision`, `persistencia`}, `motivo` (texto exacto del error), `t_hasta_rechazo_ns` (de `bloque_recibido` al rechazo) | no |
| `bloque_red_huerfano` | retenido a la espera de un padre | `hash`, `familia`, `par`, `padres_ausentes` | no |
| `huerfano_resuelto` / `huerfano_desalojado` | sale de la lista de huérfanos | `hash`, `motivo` (solo desalojado) | no |
| `cambio_punta` | cambia la punta seleccionada | `punta`, `resumen_estado`, `blue_score`, `profundidad_reorg` (bloques de la cadena seleccionada anterior que dejan de estar en la nueva; `0` si solo la extiende) | no |
| `reorganizacion_pow` | como hoy | los de hoy | no |
| `par_conectado` / `par_desconectado` | conexión libp2p | `par`, `direccion` | no |
| `par_penalizado` | el nodo penaliza o expulsa a un par | `par`, `motivo`, `accion` ∈ {`puntos`, `expulsion`, `veto`} | no |
| `limite_alcanzado` | un límite C-NET descarta algo | `par`, `limite`, `detalle` | no |
| `evidencia_detectada` | (SL-4b2) segunda cabecera con la misma identidad | `incident_id`, `clave`, `slot_falta`, `hash_1`, `hash_2` | sí |
| `evidencia_incluida` | (SL-4b2) el nodo mete la `EvidenceTx` en su bloque | `incident_id`, `bloque` | no |
| `firmante_abstenido` | (SL-4b2) el firmante no firma | `slot`, `motivo` ∈ {`conflicto`, `perdida_registro`} | sí |
| `parada` | salida ordenada | `motivo` | sí |

## 2. Muestras de recursos (las escribe el arnés de W07b, no el nodo)

Un CSV por nodo y ejecución, `recursos-<nodo>.csv`, una fila por segundo, leída de `/proc/<pid>/`:
`reloj_pared_ns,pid,utime_ticks,stime_ticks,rss_kib,read_bytes,write_bytes,disco_datos_bytes`
(`disco_datos_bytes` = tamaño del directorio de datos, muestreado cada 10 s y repetido entre muestras).
`CLK_TCK` y el tamaño de página se registran en la cabecera de la ejecución (`EJECUCION.txt`).

## 3. Métricas que el analizador calcula (y de qué eventos)

| Métrica | Eventos | En v0 |
|---|---|---|
| Latencia de propagación A → B (p50, p95, máx; por par de nodos y total) | `bloque_producido`/`bloque_minado` de A y `bloque_red_admitido` de B con el mismo `hash`, por `reloj_pared_ns` | sí |
| Tiempo por etapa de verificación (mediana, p95) | `t_cabecera_ns`, `t_admision_ns`, `t_persistencia_ns` | no |
| Tiempo de admisión frente a `n_bloques_dag` (IPA B-12), en tramos de 500 bloques | `t_admision_ns`, `n_bloques_dag` | no |
| Bloques por slot; padres por bloque; fracción de rojos | `bloque_producido`, `bloque_red_admitido` (`slot`, `n_padres`, `*_mergeset`) | no |
| Rechazos por `etapa` y `motivo`; coste hasta el rechazo | `bloque_red_rechazado` | parcial (motivo) |
| Divergencia: fracción del tiempo en que las puntas seleccionadas no coinciden; tiempo hasta converger tras un suceso | `cambio_punta` de todos los nodos | sí |
| Estado final igual | último `resumen_estado` de cada nodo | sí |
| Profundidad de reorganización | `profundidad_reorg`, `reorganizacion_pow` | parcial |
| CPU, RSS, E/S y disco por nodo | CSV del §2 | no |
| Duración del reinicio y de la puesta al día | `reinicio_completo`, `arranque`, `cambio_punta` | parcial |

## 1 bis. Eventos de diagnóstico (añadido 2026-09-27, `REVISION-W07a.md`)

El §1 fija el **mínimo**; el nodo puede escribir además eventos de diagnóstico, que el analizador ignora sin
error (tipo desconocido). Se conservan estos, introducidos por W06d5/W06d6, con sus campos de entonces:
`dejar_de_producir` (el nodo alcanza el slot de `--dejar-de-producir-en-slot`; **crítico**: marca el inicio
del reposo), `bloque_red_pendiente`, `bloque_red_ignorado_sin_penalizar`,
`bloque_post_gossip_descartado_sincronizando`, `bloque_propio_rechazado_legitimo` y
`bloque_post_de_red_sin_terminal`. Ningún evento existente se retira sin decisión del director.
