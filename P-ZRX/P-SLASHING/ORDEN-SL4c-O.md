# ORDEN-SL4c-O — Oráculos T01 y T04: `cbid` ajeno y orden no canónico de la `EvidenceTx` son errores de **forma**

**LINEO (`V-ZRX/LINEO.md`) rige este código Julia**; léelo íntegro antes de escribir código.

## 1. Identidad y contexto

- **ID:** SL-4c-O, en dos partes que se lanzan por separado: **O1** (T01) y **O2** (T04). **Fecha:**
  2026-09-26 (≈ 23:10). **Director:** Claude. **Ejecutor:** DeepSeek (`deepseek-flash`, esfuerzo `high`).
- **Zona escribible:** O1 solo `P-ZRX/P-TRANSICION/T01/` (se lanza desde ahí); O2 solo `P-ZRX/P-DAG/T04/` (se
  lanza desde ahí).
- **Motivo:** `P-ZRX/P-REVISION-CODIGO/REVISION-RI-3b.md` H1. El contrato ratificado dice que una
  `EvidenceTx` con `consensus_branch_id` ajeno (**RAT-1**: «si no, `ErrForma`») o con `pre_hash(H1) ≥_lex
  pre_hash(H2)` (**EV-04**: `ErrForma(OrdenCanonicoInvalido)`) es un error de **forma**, y
  `P-ZRX/P-DAG/CONTRATO-ESTADO-DAG-v0.md` (tabla de la línea 46, fila «Forma de cabecera y de transacciones»)
  dice que un error de forma de una transacción hace **inválido el bloque**. Los oráculos (SL-3/SL-3b) los
  tratan como semánticos (`ErrCbidAjeno`, `ErrOrdenCanonico`): en fusión, descarte y bloque válido. Se
  corrigen al contrato.
- **Pregunta falsable:** «Con la corrección, toda historia cuyo bloque lleva una evidencia con `cbid` ajeno u
  orden no canónico se rechaza entera (T01 y T04, modo estricto y fusión), y nada más cambia: todos los demás
  casos de los vectores v0.4 (T01) y v0.5 (T04) se reproducen idénticos.»

## 2. Decisiones del director

1. **Precedencia fija de las comprobaciones de forma de la v4** (igual en los dos oráculos y, después, en
   Rust): estructura ya vigente (entradas/salidas/testigos, campos inactivos, forma de las dos cabeceras) →
   **`cbid`** (ambas cabeceras con el `consensus_branch_id` de la red local) → **orden canónico**. Nombres de
   error: `ErrForma(EvidenciaCbidAjeno)` y `ErrForma(OrdenCanonicoInvalido)`. Desaparecen `ErrCbidAjeno` y
   `ErrOrdenCanonico` como errores semánticos; la verificación semántica (EV-06 identidad, EV-07 sellos,
   RAT-3, ventana, deduplicación) no cambia de orden ni de resultado.
2. **Efecto:** en modo estricto (T01), como cualquier otro error de forma de una transacción (el bloque es
   inválido); en fusión (T04), el bloque que la contiene es **inválido en la admisión**, no un descarte.
3. **Vectores nuevos:** T01 **v0.5** (`vectores-transicion-v0.5.txt`, `.sha256`, `cobertura-v0.5.txt`) y T04
   **v0.6** (`vectores-estado-dag-v0.6.txt`, `.sha256`, `cobertura-v0.6.txt`), con el mismo formato de línea;
   los v0.4/v0.5 quedan intactos como históricos. **Cobertura mínima** en cada oráculo: ≥ 30 casos con
   `EvidenciaCbidAjeno` y ≥ 30 con `OrdenCanonicoInvalido`, en T04 al menos 10 de cada uno en un bloque que
   además contiene transacciones válidas (para demostrar que invalida el bloque entero), y ≥ 5 con los dos
   defectos a la vez (gana `cbid`, por la precedencia).
4. **Diferencia exacta con los vectores anteriores:** un informe `DIFERENCIAS-v0.4-v0.5.md` (T01) y
   `DIFERENCIAS-v0.5-v0.6.md` (T04) que lista, caso por caso, los que cambian de resultado y por qué; todo caso
   que cambie sin llevar uno de los dos defectos es un **fallo** de esta orden.

## 3. Verificación

`Pkg.test()` en verde (todos los tests previos con su nombre más los nuevos), `run.jl` principal con 0
fallos, relectura de los vectores nuevos con 0 discrepancias, y el listado de diferencias del punto 4.
**Prohibido Python.** Presupuesto: **1 h y 1 hilo** por parte (otra orden usa la máquina con procesos que
dependen del reloj). Sección «SL-4c-O» en `INFORME.md` y `PROGRESO.md` de cada oráculo, con `HORAS.log`
(`date -Is` real) y el nombre de modelo que devuelve la API.

## 4. Límites

`deepseek-flash`, esfuerzo `high`, solo DeepSeek Harness; LINEO antes del código; ningún código Python; no
cambias ninguna otra regla (si el cambio exige tocar otra, para e informa **antes de editar**); nada fuera
de tu zona; sin git; no leas ni muestres secretos. Entrada congelada: `P-ZRX/P-SLASHING/ENTRADA-SL4c-O.sha256`.

## Lanzamiento

    cd /home/katana/zeo/ZEROX/P-ZRX/P-TRANSICION/T01 && ( set -a; . /home/katana/torio/deepseek-harness/.env >/dev/null 2>&1; set +a; \
      node /home/katana/torio/deepseek-harness/apps/cli/lib/bin.js --profile headless \
      "Orden SL-4c-O, parte O1 (oráculo T01). Lee íntegro /home/katana/zeo/ZEROX/P-ZRX/P-SLASHING/ORDEN-SL4c-O.md y cumple la parte O1. Antes de escribir código, lee íntegro /home/katana/zeo/ZEROX/V-ZRX/LINEO.md. Si detectas una falta de definición, infórmala antes de editar." )

    cd /home/katana/zeo/ZEROX/P-ZRX/P-DAG/T04 && ( … igual con «parte O2 (oráculo T04)» … )
