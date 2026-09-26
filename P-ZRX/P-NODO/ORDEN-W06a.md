# ORDEN-W06a — `zx-cadena`: estado del DAG en memoria, con diferencial contra el oráculo T04

## 1. Identidad y contexto

- **ID:** W06a. **Fecha:** 2026-09-26. **Director:** Claude. **Ejecutor:** DeepSeek. Se lanza tras
  migrar W02b (FORMATO v0.1 en el motor) y con los vectores v0.2 de T04-C (los v0.1 de T04-B no sirven:
  `REVISION-T04-B`).
- **Zona (única escribible):** `/home/katana/zeo/ZEROX/deepseek/W06a/`.
- **Objetivo único:** crate nuevo `zx-cadena` (D-N02) que mantiene en memoria el estado del DAG según
  `P-ZRX/P-DAG/CONTRATO-ESTADO-DAG-v0.md` (ED-1…ED-6, RD-1…RD-10): admisión de bloques PoW y PoST,
  GHOSTDAG (`zx-dag`), `Estado(past(B))` de cada bloque, virtual, cadena seleccionada, reorganización
  con undo exacto; y demostrar que coincide con el oráculo T04.
- **Pregunta falsable:** «`zx-cadena`, alimentado con los bloques reales que el arnés construye de
  cada caso de `vectores-estado-dag-v0.2.txt`, da el mismo resultado por bloque (incluidas las
  transacciones descartadas y su motivo), la misma punta seleccionada y el mismo estado canónico que
  T04, en todos los casos.»

## 2. Entradas

Lee íntegros: este archivo; `V-ZRX/LINEO.md`; `P-ZRX/P-DAG/CONTRATO-ESTADO-DAG-v0.md`;
`P-ZRX/P-TRANSICION/CONTRATO-v0.md`; `P-ZRX/P-FORMATO/FORMATO-v0.md` (con v0.1);
`P-ZRX/P-NODO/PLAN-W06.md`; las revisiones de W03, W05a, W02b, T04-B y T04-C; el oráculo T04
(`P-ZRX/P-DAG/T04/src/`, como especificación ejecutable, **no** para traducirlo línea a línea) y sus
vectores `resultados/vectores-estado-dag-v0.2.txt` con su `cobertura-v0.2.txt`. Base: el workspace de la raíz.
Entrada congelada: `P-ZRX/P-NODO/ENTRADA-W06a.sha256`.

## 3. Decisiones del director

1. **Crate `zx-cadena`** (depende de `zx-core`, `zx-consensus`, `zx-dag`; sin red ni disco).
2. **Tipo de entrada:** `BloqueCadena = Pow { hechos, cabecera, txs } | Post { hechos: HechosPost de
   zx-post o su equivalente, padres: Vec<BlockHash>, sr, distancia, identidad, txs }` — lo que
   GHOSTDAG necesita para colorear y ordenar (`C-GD-05`, `C-GD-07`) más lo que el motor necesita.
   La verificación de cabeceras **no** es de esta orden: llega hecha (`pow_valido`,
   `prueba_valida`), como en W03.
3. **Semántica:** exactamente ED-1…ED-6 con RD-1…RD-10 del contrato DAG: PoW en modo estricto sobre su
   padre; PoST con `aplicar_fusion` del motor; `Estado(past(B))` por ED-2 con RD-4 (bloques de cadena
   en su propio slot, fusionados de lado en el del fusionador); garantía del productor en
   `Estado(past(B))` (RD-9, RD-10); `rojo_U3` inerte; `merge_depth` dev (RD-5); virtual con
   `slot(V) = máx` (RD-6); reorganización con undo exacto.
4. Si `aplicar_fusion` de W03 no cumple alguna de RD-1…RD-10 (p. ej. subsidio por `slot(X)`, RD-1;
   coinbase opcional, RD-2), **corrígelo en `zx-consensus::transicion`** con el mínimo cambio,
   documéntalo y demuestra que `diferencial_t01` sigue en 0 discrepancias.
5. **Arnés diferencial** (`crates/zx-cadena/tests/diferencial_t04.rs`): mismo esquema que el de W03
   (claves deterministas, transacciones reales firmadas con `nonce` y coinbases F-16/F-17), más la
   traducción de `padres`, `sr`, `sd`, `ident` y `k` a las entradas de `zx-dag`; compara `RES`, `DESC`,
   `SEL`, `UTXO`, `GAR` y `EST`. Correspondencias: las de W03/W02b; ninguna nueva sin parar.

## 4. Verificación

| Paso | Qué | Criterio |
|---|---|---|
| V1–V2 | `fmt --check`, `clippy -D warnings --locked` | limpio |
| V3 | `cargo test --workspace --all-features --locked` | todo lo previo con su nombre + lo nuevo; `diferencial_t01` sigue en 0 |
| V4 | `diferencial_t04` sobre todos los casos | **0 discrepancias** |
| V4b | El arnés imprime su propia tabla de cobertura (por tipo: aplicadas y descartadas por motivo, casos aleatorios) | idéntica a `cobertura-v0.2.txt`; una diferencia es un fallo aunque V4 dé 0 |
| V5 | Propiedades con `proptest` (semilla fija): IE-1 (conservación), IE-2 (aplicación única), IE-3 (independencia del orden de llegada, permutando la entrega de bloques), IE-4 (undo tras reorganización) | sin fallos |
| V6 | `dependencias-exactas.sh`, `frontera-crates.sh` (añade `zx-cadena → {zx-core, zx-consensus, zx-dag}`) | OK |

**Prohibido Python.** Presupuesto: **3 h, 8 hilos, 16 GiB**.

## 5. Entregables y límites

Patrón W02/W04 (`ws.orig/`, `ws/` con enlace `ws/PDF` excluido, `cambios.patch`, `MIGRACION.sha256`,
`logs/`, `INFORME.md`, `PROGRESO.md`, `HORAS.log`). Ejecuta cargo siempre desde `ws/` con
`GIT_CEILING_DIRECTORIES` apuntando a tu zona. DeepSeek `deepseek-flash`, esfuerzo `high`; LINEO antes
del código; nada fuera de la zona; sin commit ni push; sin secretos; ningún `Ok` ficticio.

## Lanzamiento

    mkdir -p /home/katana/zeo/ZEROX/deepseek/W06a && cd /home/katana/zeo/ZEROX/deepseek/W06a && \
    ( set -a; . /home/katana/torio/deepseek-harness/.env >/dev/null 2>&1; set +a; \
      node /home/katana/torio/deepseek-harness/apps/cli/lib/bin.js --profile headless \
      "Orden W06a. Lee íntegro /home/katana/zeo/ZEROX/P-ZRX/P-NODO/ORDEN-W06a.md y cúmplelo. Antes de escribir código, lee íntegro /home/katana/zeo/ZEROX/V-ZRX/LINEO.md. Si detectas una falta de definición, infórmala antes de editar." \
      > ../W06a-dsh.stdout 2> ../W06a-dsh.stderr )
