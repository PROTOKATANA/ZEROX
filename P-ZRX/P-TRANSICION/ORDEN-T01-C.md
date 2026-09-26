# ORDEN-T01-C — Vectores de rechazo de transacciones para el diferencial Rust

## 1. Identidad y contexto

- **ID:** T01-C. **Estado:** redactada 2026-09-26. **Director:** Claude. **Ejecutor:** DeepSeek.
- **Zona (única escribible):** `/home/katana/zeo/ZEROX/P-ZRX/P-TRANSICION/T01/`.
- **Objetivo único:** completar la cobertura de rechazos de **transacción** que los vectores de T01-B
  apenas ejercitan (0 `ErrSaldo`, 0 `ErrDobleGasto`, 0 `ErrRetiroPendiente`, 3 `ErrAutorizacion`,
  8 `ErrInmaduro`; `REVISION-T01-B.md`), exportándolos a un **fichero aparte** con el mismo formato.
- **Pregunta falsable:** «Cada familia de rechazo de transacción del contrato (v0.1) aparece al menos
  30 veces en el fichero nuevo, con el error esperado construido a mano y confirmado por el oráculo,
  y la relectura independiente da 0 discrepancias.»
- **Desbloquea:** diferencial completo de W03 (ampliación posterior).

## 2. Entradas

Lee íntegros: este archivo; `V-ZRX/LINEO.md`; `P-ZRX/P-TRANSICION/CONTRATO-v0.md` (v0.1);
`P-ZRX/P-TRANSICION/ORDEN-T01-B.md` (formato); tu código y documentos de `T01/`.
Entrada congelada: `P-ZRX/P-TRANSICION/ENTRADA-T01-C.sha256`, al empezar y como último paso.

## 3. Decisiones del director

1. **No cambies la semántica** de `src/Transicion.jl`, `src/seleccion.jl` ni `src/nodo.jl`. Solo
   añades generadores de casos (`src/generadores.jl` o un fichero nuevo) y la exportación.
2. **Familias mínimas** (≥ 30 casos cada una, en varios puntos de la rejilla por defecto y en ambas
   fases cuando aplique), cada caso con el error esperado **escrito a mano** y comprobado contra el
   oráculo: `ErrSaldo` (transferencia que crea valor; depósito que no cuadra; retiro mayor que el
   activo; liberación mayor que lo vencido; importe 0 de R-8; transferencia sin salidas de R-9);
   `ErrDobleGasto` (misma entrada dos veces en una tx y en dos txs del mismo bloque; gasto de una
   salida ya gastada); `ErrRetiroPendiente`; `ErrAutorizacion` (transferencia, depósito, retiro y
   liberación firmados por otra clave); `ErrInmaduro` (coinbase PoW en PoW y cruzando el corte con
   `M_res_slots`; depósito pendiente usado para producir ⇒ `ErrGarantia` aparte); liberación antes de
   `R_slots` (el error que dé el oráculo, declarado); `ErrEmision` (R-6, R-7, R-9); `ErrOperacionFase`
   (liberación y evidencia en PoW).
3. Fichero: `T01/resultados/vectores-transicion-negativos-v0.txt` + `.sha256` (en formato
   `sha256sum`, es decir, `<hash>  <nombre>`), mismo formato de líneas que T01-B; relectura con tu
   lector independiente: 0 discrepancias; determinista.

## 4. Verificación y límites

`test/runtests.jl` sigue pasando; tabla de recuentos por error en el informe. Presupuesto 1 h,
1 hilo, 4 GiB. **Prohibido Python.** Sección «T01-C» en `INFORME.md` y `PROGRESO.md`; `HORAS.log`.
DeepSeek `deepseek-flash`, esfuerzo `high`; LINEO; nada fuera de `T01/`; sin commit ni push; sin
secretos.

## Lanzamiento

    cd /home/katana/zeo/ZEROX/P-ZRX/P-TRANSICION/T01 && \
    ( set -a; . /home/katana/torio/deepseek-harness/.env >/dev/null 2>&1; set +a; \
      node /home/katana/torio/deepseek-harness/apps/cli/lib/bin.js --profile headless \
      "Orden T01-C. Lee íntegro /home/katana/zeo/ZEROX/P-ZRX/P-TRANSICION/ORDEN-T01-C.md y cúmplelo. Antes de escribir código, lee íntegro /home/katana/zeo/ZEROX/V-ZRX/LINEO.md. Si detectas una falta de definición, infórmala antes de editar." \
      > ../T01-C-dsh.stdout 2> ../T01-C-dsh.stderr )
