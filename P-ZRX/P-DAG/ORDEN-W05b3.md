# ORDEN-W05b3 — Productor PoST en régimen y servicio PoT local

## 1. Identidad y contexto

- **ID:** W05b3. **Fecha:** 2026-09-26. **Director:** Claude. **Ejecutor:** DeepSeek. Se lanza tras
  migrar W02b; corre en paralelo a W06a y W06b.
- **Zona (única escribible):** `/home/katana/zeo/ZEROX/deepseek/W05b3/`.
- **Hueco que cierra:** `zx_post::producir` (W05b2) solo fabrica el **primer** bloque PoST, hijo del
  terminal. El nodo necesita producir bloques con **varios padres** (puntas del DAG), con la
  justificación PoT que cubre `(slot(sp(B)) + D, slot(B) + D]` desde el padre seleccionado, y
  necesita un servicio PoT local que calcule el flujo único dev slot a slot y responda a la
  verificación. El verificador general ya existe (`verificar_cabecera_conjunta`, `pot_rango`,
  `justificacion`).
- **Pregunta falsable:** «Un DAG de bloques PoST producidos por el productor en régimen (cadenas,
  hermanos del mismo slot y bloques de fusión con varios padres) es aceptado íntegro por la puerta
  conjunta de W05b2 con contextos reales derivados de `zx-dag` y del servicio PoT; y cada alteración
  de la lista negativa §4 V5 es rechazada o queda pendiente con el motivo exacto.»

## 2. Entradas

Lee íntegros: este archivo; `V-ZRX/LINEO.md`; `P-ZRX/P-DAG/DECISIONES-W05.md` (D-P08…D-P13);
`P-ZRX/P-RED-DEV/PERFIL-DEV-v0.md`; `P-ZRX/P-FORMATO/FORMATO-v0.md` (con v0.1);
`P-ZRX/P-DAG/REVISION-W05b2.md`; y el código de `crates/zx-post/` y `crates/zx-dag/` de la raíz.
Base: el workspace de la raíz tras W02b. Entrada congelada: `P-ZRX/P-DAG/ENTRADA-W05b3.sha256`.

## 3. Decisiones del director

1. **Solo `zx-post`** (frontera actual `zx-post → {zx-core, zx-pot, zx-dag, zx-poas}`; no se amplía).
   Módulos nuevos; `producir` de W05b2 se conserva (o se reexpresa sobre el nuevo sin cambiar su
   comportamiento ni sus tests).
2. **`ServicioPot`** (lógica pura, sin hilos propios; el hilo lo pondrá el nodo): arranca de la
   semilla S1 del terminal (D-P09), avanza un slot por llamada con `N_dev` (D-P10: un solo flujo, sin
   inyecciones, `D = 0`), guarda salidas y checkpoints de una ventana acotada y configurable de slots
   (memoria acotada, error explícito fuera de ventana) e implementa `InstantaneaPot` para verificar
   cabeceras ajenas.
3. **`producir_en_regimen`**: entrada = padres ya elegidos por el llamante (`PadresDag`, seleccionado
   primero, ≤ 15 en total), slot objetivo, el `ServicioPot`, una `FuenteSoluciones`, la clave, los
   `ParametrosProductor` y las transacciones del cuerpo (la coinbase v3 la construye el productor con
   el `slot` del bloque, F-17). Salida = bloque DAG con cabecera sellada, justificación y cuerpo. **No**
   elige padres ni decide si la clave tiene garantía: eso es del nodo (`zx-cadena`). Error explícito si
   `slot ≤ slot(sp)` o si el rango excede `MAX_BUNDLES_POT = 150`.
4. **Hallazgo H2 de RI-1b:** `ContextoTransicion::nuevo` debe devolver un error explícito si dos registros validados del mismo slot traen `salida` distinta (hoy `or_insert` lo oculta, `contexto_transicion.rs:176-181`), con test.
5. **Contextos de prueba reales:** en los tests, `ContextoDag` e `InstantaneaPot` se implementan sobre
   `zx-dag` (GHOSTDAG de verdad sobre los bloques producidos) y sobre el `ServicioPot`; ningún mock que
   devuelva «válido».

## 4. Verificación

| Paso | Qué | Criterio |
|---|---|---|
| V1–V2 | `fmt --check`, `clippy -D warnings --locked` | limpio |
| V3 | `cargo test --workspace --all-features --locked` | todo lo previo con su nombre + lo nuevo |
| V4 | Escenarios positivos con `N` pequeño de test y el sector dev de W05b1: cadena de ≥ 8 bloques tras el terminal; dos hermanos del mismo slot de dos claves y un bloque de fusión con ambos como padres; fusión de 3 ramas; hueco de 150 slots entre padre seleccionado y bloque | todos `Comprobada` por `verificar_cabecera_conjunta` |
| V5 | Negativos, cada uno con su motivo exacto: padre seleccionado que no es el que da GHOSTDAG; padres no canónicos o > 15; slot ≤ slot(sp); hueco de 151; checkpoint alterado; `pot_output` alterado; solución de otra clave; sello de otra clave; coinbase v3 con `slot` ≠ bloque (contextual, se documenta dónde se rechaza); padre desconocido (pendiente) | cada uno inválido o pendiente con motivo |
| V6 | Un extremo a extremo con `N_dev` real (138 873 760) de 3 bloques en régimen, en release | `Comprobada`; tiempos de producción y de verificación por bloque en `logs/` |
| V7 | `dependencias-exactas.sh`, `frontera-crates.sh`; lock sin cambios | OK |

**Prohibido Python.** Presupuesto: **2 h, 8 hilos, 16 GiB**.

## 5. Entregables y límites

Patrón W02/W04 (`ws.orig/`, `ws/` con el enlace `ws/PDF` excluido, `cambios.patch`,
`MIGRACION.sha256`, `logs/`, `INFORME.md`, `PROGRESO.md`, `HORAS.log` con `date -Is` real). Cargo
desde `ws/` con `GIT_CEILING_DIRECTORIES` en tu zona y `CARGO_HOME`/`CARGO_TARGET_DIR` en la zona.
DeepSeek `deepseek-flash`, esfuerzo `high`; LINEO antes del código; nada fuera de la zona; sin commit
ni push; sin secretos; ningún `Ok` ficticio. Si el verificador de W05b2 rechaza un bloque honesto en
régimen, **para**: es un hallazgo sobre W05b2, no algo que se arregle aflojando el verificador.

## Lanzamiento

    mkdir -p /home/katana/zeo/ZEROX/deepseek/W05b3 && cd /home/katana/zeo/ZEROX/deepseek/W05b3 && \
    ( set -a; . /home/katana/torio/deepseek-harness/.env >/dev/null 2>&1; set +a; \
      node /home/katana/torio/deepseek-harness/apps/cli/lib/bin.js --profile headless \
      "Orden W05b3. Lee íntegro /home/katana/zeo/ZEROX/P-ZRX/P-DAG/ORDEN-W05b3.md y cúmplelo. Antes de escribir código, lee íntegro /home/katana/zeo/ZEROX/V-ZRX/LINEO.md. Si detectas una falta de definición, infórmala antes de editar." \
      > ../W05b3-dsh.stdout 2> ../W05b3-dsh.stderr )
