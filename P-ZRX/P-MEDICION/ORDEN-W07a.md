# ORDEN-W07a — Correcciones de red de RI-3a (parte A) e instrumentación del registro según `ESQUEMA-REGISTRO-v1` (parte B)

**LINEO (`V-ZRX/LINEO.md`) rige este código Rust** (`AUTO-ZRX.md` §52); léelo íntegro antes de escribir
código y aplica sus reglas pertinentes (en particular: medir sin alterar lo medido, y trazas verificables).

## 1. Identidad y contexto

- **ID:** W07a. **Fecha:** 2026-09-26 (redactada ≈ 23:00; se congela y lanza tras migrar W06d5).
  **Director:** Claude. **Ejecutor:** DeepSeek (`deepseek-flash`, esfuerzo `high`, DeepSeek Harness).
- **Zona (única escribible):** `/home/katana/zeo/ZEROX/deepseek/W07a/`.
- **Objetivo (dos partes, en este orden):** **parte A**, corregir los tres hallazgos altos de RI-3a y el bajo (§3 bis); **parte B**, que `zx-node` escriba exactamente los eventos y campos de
  `P-ZRX/P-MEDICION/ESQUEMA-REGISTRO-v1.md` §1 (salvo los tres de SL-4b2: `evidencia_detectada`,
  `evidencia_incluida`, `firmante_abstenido`, que añade SL-4b2), **sin cambiar ninguna regla de consenso,
  ningún orden de operaciones de la tubería de admisión ni ninguna decisión del nodo**.
- **Pregunta falsable:** «Con la instrumentación, la suite completa y los diferenciales T01/T04 dan
  exactamente lo mismo que antes; en una ejecución real de tres nodos cada evento del esquema aparece con
  todos sus campos, y el coste de registrar es menor que el 1 % del tiempo de admisión mediano.»
- **Desbloquea:** W07b (mediciones) y SL-4b2 (que parte de esta base). La parte A sí cambia conducta (límites de red): por eso va antes y con sus propias pruebas; la parte B no cambia nada.

## 2. Entradas (congeladas en `P-ZRX/P-MEDICION/ENTRADA-W07a.sha256`)

`ESQUEMA-REGISTRO-v1.md` (**contrato**), `ESCENARIOS-0.0.1.md`, `P-ZRX/P-NODO/PLAN-W06.md`, las órdenes y
revisiones W06d1…W06d5; código: raíz en el commit indicado por la entrada (con W06d5 migrada).

## 3. Decisiones del director

1. **Solo observación.** Los tiempos se toman con `Instant` alrededor de llamadas que ya existen; nada se
   reordena, nada se reintenta, ningún error cambia de clase. Si para medir una etapa hubiera que partir una
   función de otro crate, **no** la partas: mide la llamada entera y decláralo.
2. **Accesos de lectura permitidos fuera de `zx-node`**, solo si hacen falta para un campo del esquema y sin
   cambiar ningún comportamiento: en `zx-cadena`, lectura de `blue_score`, número de bloques admitidos,
   tamaños azul/rojo del mergeset de un bloque admitido y número de transacciones descartadas por fusión en
   un bloque; en `zx-post::servicio_pot`, el instante en que se obtuvo la salida de un slot. Cada acceso nuevo,
   con un test que compare su valor con el que ya calcula el código (no una segunda implementación).
3. **`t_total_ns`** se mide desde la llegada del mensaje al nodo (`bloque_recibido`) hasta el evento final,
   atravesando validación diferida y huérfanos: el instante de llegada viaja con el bloque.
4. **Profundidad de reorganización** (`profundidad_reorg`): número de bloques de la cadena seleccionada
   anterior que no están en la nueva, calculado con la información que `zx-cadena` ya expone o con un acceso
   de lectura del punto 2; `0` cuando la nueva punta extiende a la anterior.
5. Los eventos no críticos **no** hacen `sync` (como hoy); los críticos del esquema, sí.
6. **Parámetro de medición `--dejar-de-producir-en-slot <S>`** (CLI, solo red dev; no es consenso): desde el
   slot `S` el nodo no produce más bloques PoST, pero sigue validando, propagando y sincronizando; evento
   `produccion_detenida` (crítico). Sirve para el reposo antes de comparar estados (`REVISION-W07c.md`).

## 3 bis. Parte A — correcciones de RI-3a (`P-ZRX/P-REVISION-CODIGO/REVISION-RI-3a.md`)

Los tres tests de reproducción de RI-3a (`P-ZRX/P-REVISION-CODIGO/resultados-RI-3a/ri3a_*.rs`) se añaden
como regresiones: **deben fallar en la base** (compruébalo y guarda la salida) y pasar tras la corrección, con
sus aserciones invertidas donde midan el defecto. Correcciones fijadas por el director:

1. **`Peticion::Bloques` (H1):** deduplicar los hashes pedidos conservando el orden, recortar a
   `MAX_BLOQUES_POR_RESPUESTA` y dejar de añadir al llegar a `MAX_RESPUESTA_BYTES`, **antes** de clonar; una
   petición con hashes repetidos penaliza al par como mensaje mal formado (un honesto no la envía).
2. **`leer_acotado` (H2):** reserva **incremental** del presupuesto en trozos de 64 KiB, cada trozo reservado
   antes de leerlo; lo reservado nunca supera lo leído más un trozo. Regresión: siete flujos silenciosos de un
   par retienen como mucho `7 × 64 KiB` y un par honesto sigue siendo atendido.
3. **Cola `TrabajoRed` (H3):** acotada en elementos (`MAX_TRABAJO_RED = 1 024`) y en bytes
   (`MAX_TRABAJO_RED_BYTES = 256 MiB`); llena, descarta lo nuevo **sin bloquear** la red y escribe
   `limite_alcanzado`. El informe declara cómo se recupera un bloque honesto descartado (petición de padres,
   sincronización) y lo prueba con un test.
4. **`cabeceras_desde` (bajo):** índice hash → altura para que cada hash del localizador cueste `O(1)`.

La parte A toca `crates/zx-p2p/src/{servicio.rs, codec.rs, limites.rs}` y `crates/zx-node/src/red/**`;
sus constantes nuevas llevan comentario con su motivo (C-NET). Tras la parte A, suite completa en verde
**antes** de empezar la parte B.

## 4. Plan de verificación

| Paso | Qué | Criterio |
|---|---|---|
| V0 | `sha256sum -c` de la entrada; suite completa de la raíz sin cambios | verde; si no, para |
| VA | Parte A: los tres tests de RI-3a fallan en la base y pasan tras corregir; regresión de recuperación del bloque descartado por la cola llena; suite completa en verde | cada uno con su salida antes y después |
| V1 | Suite completa con la instrumentación; `diferencial_t01` y `diferencial_t04` | mismos tests, mismos resultados, **0 discrepancias** |
| V2 | Test de esquema: un test de integración (en proceso) que produce, recibe, admite y rechaza bloques y comprueba, **evento por evento**, que cada línea es JSON válido con los campos comunes y los de su tipo en el esquema (tabla del §1), sin campos con `0`/`-1` de relleno | todas las filas del §1 (salvo las tres de SL-4b2) cubiertas |
| V3 | Ejecución real: tres nodos en `127.0.0.1` que cruzan el corte y producen ≥ 60 bloques PoST (`N_dev` reducido, declarado; puedes partir de `deepseek/W06d5/scripts_v4.sh`, solo leyéndolo), más un `zx-adversario` que envía dos entradas inválidas; se conservan los tres `registro.jsonl`. El sandbox mata los procesos al terminar cada orden de shell: lanza **un único script** en segundo plano (trabajo del Harness) que arranca los nodos, espera la condición con un tope de tiempo, los detiene y deja los registros | cada tipo de evento del esquema aparece al menos una vez (o se explica por qué no puede aparecer en esa ejecución) |
| V4 | Coste del registro: mediana de `t_admision_ns` con el registro activo frente al tiempo total de escribir los eventos de ese bloque (medido en la misma ejecución) | < 1 %; si no, perfil y decisión escrita |
| V5 | `fmt --check`, `clippy --workspace --all-targets --all-features --locked -- -D warnings`, `ci/dependencias-exactas.sh`, `ci/frontera-crates.sh`, lock sin cambios | limpio |

**Tabla de cobertura** en el informe: tipo de evento → test o ejecución que lo produjo, mínimo 1 por tipo.
**Prohibido Python.** Presupuesto: **3 h, 8 hilos** (4 si otra orden con procesos reales sigue viva), 16 GiB.

## 5. Entregables y límites

Patrón de las órdenes W (`P-ZRX/P-FORMATO/ORDEN-W02.md` §4): `ws.orig/`, `ws/` (solo `Cargo.toml`,
`Cargo.lock`, `rust-toolchain.toml`, `crates/`, `testdata/`, `ci/`, `.github/` y el enlace `ws/PDF`),
`cambios.patch` y `MIGRACION.sha256` como **último** paso con `sha256sum -c` en verde, `logs/`, `run/`,
`INFORME.md` (archivos cambiados, comandos, resultados V0…V5, tabla de cobertura, lo que **no** queda
demostrado, nombre de modelo que devuelve la API), `PROGRESO.md`, `HORAS.log` con `date -Is` real. Entorno
como `deepseek/SL4a/env.sh` con tu zona; caché copiable de `deepseek/SL4a/.cargo-home`.

**Límites de la sesión:** `deepseek-flash`, esfuerzo `high`, solo DeepSeek Harness; LINEO antes del código;
ningún código Python; no cambias reglas ni eliges métricas (si falta una definición, para e informa **antes
de editar**); nada fuera de tu zona; procesos de nodos en segundo plano con PID en `PROGRESO.md` y ninguno
vivo al terminar; ningún `Ok` ficticio; sin commit ni push; no leas ni muestres secretos.

## Lanzamiento

    mkdir -p /home/katana/zeo/ZEROX/deepseek/W07a && cd /home/katana/zeo/ZEROX/deepseek/W07a && \
    ( set -a; . /home/katana/torio/deepseek-harness/.env >/dev/null 2>&1; set +a; \
      node /home/katana/torio/deepseek-harness/apps/cli/lib/bin.js --profile headless \
      "Orden W07a. Lee íntegro /home/katana/zeo/ZEROX/P-ZRX/P-MEDICION/ORDEN-W07a.md y cúmplelo. Antes de escribir código, lee íntegro /home/katana/zeo/ZEROX/V-ZRX/LINEO.md. Si detectas una falta de definición, infórmala antes de editar." )
