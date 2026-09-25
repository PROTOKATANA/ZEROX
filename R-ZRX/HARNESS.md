# Ruta de ejecución DeepSeek — verificación y bloqueos

**Autor:** Claude (director técnico bajo `AUTO-ZRX.md`). **Fecha de verificación:** 2026-09-26
(horas tomadas de `date -Is`). Este documento registra qué se comprobó de la ruta exigida por
`AUTO-ZRX.md` §1 y qué la bloquea. No contiene ni cita secretos.

## Exigencia

`AUTO-ZRX.md` §1 fija: DeepSeek Harness (`dsh`) en `/home/katana/torio/deepseek-harness`,
modelo **`deepseek-v4.1-flash`**, esfuerzo **`high`**, lanzamiento
`dsh --profile headless "<orden>"` o, sin `dsh` en `PATH`,
`node /home/katana/torio/deepseek-harness/apps/cli/lib/bin.js --profile headless "<orden>"`.

## Hechos comprobados (2026-09-26 ~00:31–00:35)

| Hecho | Evidencia |
|---|---|
| El Harness existe en la ruta indicada | `ls /home/katana/torio/deepseek-harness`; `apps/cli/package.json`: `@deepseek-ai/dsh` `0.1.5-rc.2`; `git rev-parse HEAD` = `c291e7961a515f6d7af9304e7fd1d257929aef26` (commit 2026-09-10) |
| `dsh` no está en `PATH`; `node` v24.18.1 sí | `which dsh` → no encontrado |
| El catálogo del adaptador no tiene el id literal `deepseek-v4.1-flash`; el id `deepseek-flash` se presenta como **«DeepSeek-V41-Flash»** | `packages/llm/llm-deepseek/src/index.ts:92-101` (`DEFAULT_MODELS`, primer elemento) |
| La configuración compuesta del perfil `headless` elige `provider: deepseek-official`, `model: deepseek-flash` | `bin.js --profile headless --dump-config` (fila `agent-default-model`) |
| El esfuerzo por defecto es `high` | `~/.dsh/settings.yaml` → `agent-default-model.reasoningEffort: high`; además el adaptador resuelve a `high` si se omite (`index.ts:128-133`) |
| El historial antiguo usó la misma ruta | `.trash/zerox/P-ZRX/PIEZAS-DE-CODIGO/HOJA-DE-RUTA.md`: «ruta `deepseek-official/deepseek-flash` (catálogo local: DeepSeek-V41-Flash), esfuerzo `high`» |
| Sandbox `workspace-write` en Linux | `packages/sandbox/sandbox-local/src/profiles.ts:16-22`: `--ro-bind / /`, `--tmpfs /tmp` **por llamada**, `--bind <workspace>`; la red no se aísla. Todo fuera del directorio de trabajo es de solo lectura |
| Aprobaciones en headless | `packages/interaction/user-approval/src/index.ts:68`: sin contestador, la petición de ampliar permisos **falla cerrada** |

**Interpretación (decisión de director):** «deepseek-v4.1-flash» de `AUTO-ZRX.md` se identifica con
el id de catálogo `deepseek-flash` («DeepSeek-V41-Flash») de este Harness, el mismo que se usó en
las órdenes de 0.0.1 antiguas. **Riesgo residual:** `deepseek-flash` es un alias del proveedor;
si el proveedor lo reasignara, el informe de cada sesión debe registrar el nombre de modelo que
devuelve la API. Cada orden exige ese registro.

## Consecuencias del sandbox para las órdenes

- El directorio de trabajo de cada sesión es la **única** zona escribible: la orden debe lanzarse
  con `cwd` en su zona de ejecución, nunca en la raíz del repositorio.
- `/tmp` se vacía entre llamadas: cachés y temporales van dentro de la zona (p. ej.
  `CARGO_HOME`, `CARGO_TARGET_DIR`, `JULIA_DEPOT_PATH` apuntando a subdirectorios de la zona).
- `~/.cargo`, `~/.rustup`, `~/.julia` y el archivo `.trash/` son legibles, no escribibles.
- El límite por orden de shell es `timeoutMs: 60000` (fila `bash-sandbox` de la configuración
  compuesta); las compilaciones largas deben ir en segundo plano (`job_output`).

## BLOQUEO B-HARNESS-01 (abierto)

**2026-09-26 ~00:35.** Una sesión de prueba mínima lanzada desde la sesión de Claude Code
(`bin.js --profile headless "<prueba de ruta sin herramientas>"`, `cwd` en el scratchpad) terminó
con código 1 y:

    dsh: MISSING_CREDENTIAL: llm-deepseek: no API key for provider route "deepseek-official"; ...

No se consumió ningún token de DeepSeek ni se ejecutó ninguna orden. **No se inspeccionan ni se
buscan credenciales**: la acción que falta es externa y corresponde a Katana (dejar la clave
disponible para el proceso que lanza las órdenes, p. ej. mediante el servicio de credenciales del
Harness o el entorno de arranque).

**Efecto:** hasta resolverlo, ninguna orden se ejecuta. Las órdenes se redactan completas y se
guardan en `P-ZRX/` listas para lanzar con el comando de su §«Lanzamiento». Ninguna entrega de este
periodo afirma haber usado DeepSeek.

## B-HARNESS-01 — resuelto (2026-09-26 01:03)

Katana confirmó que DeepSeek funciona. Causa (nota de memoria de sesión, diagnosticada sin leer el
valor): `dsh` carga `.env` solo del directorio de lanzamiento y de `~/.dsh/.env`; la clave está en
el `.env` del repositorio del Harness. Como cada orden se lanza con `cwd` en su zona, el director
lanza así, **sin leer, imprimir ni copiar** el archivo:

    ( set -a; . /home/katana/torio/deepseek-harness/.env >/dev/null 2>&1; set +a; \
      cd <zona> && node /home/katana/torio/deepseek-harness/apps/cli/lib/bin.js --profile headless "<orden>" )

Prueba 01:03:27: salida 0, respuesta `deepseek-flash OK`; el razonamiento cita su prompt de
sistema «You are a coding agent powered by the deepseek-flash model». **Riesgo:** el sandbox monta
`/` en solo lectura, así que la sesión de DeepSeek *puede leer* ese `.env`; cada orden le prohíbe
leer o exponer secretos.
