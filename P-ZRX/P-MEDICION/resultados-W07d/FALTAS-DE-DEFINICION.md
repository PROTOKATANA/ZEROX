# FALTAS-DE-DEFINICION — ORDEN-W07d

**Ejecutor:** DeepSeek (`deepseek-flash`, esfuerzo `high`). **Fecha:** 2026-09-27.
**Base:** raíz en el commit `20214cb` (`ENTRADA-W07d.sha256` verificada 34/34 en `ws.orig/`).

Se detectaron los huecos de precisión de abajo **antes de editar código**. Ninguno contradice la
orden ni cambia una regla de consenso, un orden de la tubería o una decisión del nodo; en todos los
casos se adopta la lectura determinista mínima y se declara en `INFORME.md`.

1. **`compendio_bloques`: ¿incluye el génesis?** La orden dice «todos los bloques admitidos (PoW y
   PoST)». El génesis se admite y se persiste en el almacén del nodo. Adopto **sí incluirlo**: el
   compendio sale del registro persistido completo (`Almacen::repetir`), que empieza por el génesis.

2. **`compendio_bloques`: codificación exacta.** La orden fija `zx_core::sha3_256_publico` de la
   concatenación de los hashes ordenados por bytes, pero no dice si cada hash entra en bruto o en
   hexadecimal, ni la forma del resultado. Adopto: **32 bytes crudos por hash**
   (`BlockHash::as_bytes()`), concatenados en orden lexicográfico de bytes, y el digest resultante en
   **hexadecimal minúsculo de 64 caracteres** (`Digest::Display`), la misma representación que el
   resto del registro.

3. **`punta` cuando no hay punta seleccionada (fase PoW pura).** `cambio_punta` ya escribe cadena
   vacía en ese caso (su `punta_actual` es `None`). Adopto la **misma convención** para
   `reinicio_completo` y `parada`: `mejor_punta().or(terminal())` y, si no hay, `""`. No se omite el
   campo, para que el conjunto de campos del evento sea fijo.

4. **`motivo` de `parada` bajo señal.** La orden no fija el literal. Adopto `"sigterm"` para
   `SIGTERM` y `"sigint"` para `SIGINT`; el resto de motivos (`"parada_tras_slots"`, `"fin"`) no
   cambian.

5. **Fuente de `n_bloques_dag`.** La orden reutiliza el nombre que ya usan
   `bloque_red_admitido`/`cambio_punta`. Adopto `Cadena::bloques_admitidos()` (PoW + PoST válidos),
   la misma definición que la §1 del esquema, no un conteo nuevo.

6. **Mecanismo de señal.** La orden pide «el manejo mínimo» sin imponer biblioteca. Adopto un
   manejador `signal(2)`/`signal(15)` sobre un flag atómico, sin dependencias nuevas ni `Cargo.lock`
   tocado (`unsafe` mínimo, declarado con `#[expect(unsafe_code)]`).

7. **`bloque_transicion_producido`: ¿crítico?** La orden lo llama «evento de diagnóstico» sin
   marcarlo crítico. Adopto **no crítico**, igual que `bloque_producido`; el momento es justo tras
   la admisión y persistencia del bloque de transición y antes de difundirlo.

8. **`reinicio_completo` con fase PoW pura.** Si el almacén repetido aún no cruzó el corte, no hay
   punta PoST. Se aplica el punto 3 y `resumen_estado` es el del estado virtual PoW; el evento se
   escribe igual (la orden no lo condiciona a que exista terminal).

9. **Espera de los hilos al parar por señal.** La orden no fija si hay que unir los hilos. Adopto:
   el hilo productor se une (responde a `MsgBucle::Parar` de inmediato); el hilo minero se deja
   terminar/detachar tras cerrar su canal, porque `minar(..., u64::MAX, ...)` no es cancelable y un
   `join` podría bloquear la salida ordenada. La parada se escribe antes de devolver.

10. **Test «dos nodos en órdenes distintos».** La orden lo pide como test. Montar dos procesos reales
    con el mismo conjunto de bloques en órdenes distintos excede el presupuesto de esta orden.
    Adopto la comprobación **a nivel de las funciones exactas que usan los nodos**
    (`compendio_de_almacen` sobre dos almacenes con el mismo conjunto en orden y en orden inverso, y
    `resumen_estado` sobre dos estados con las mismas entradas insertadas en distinto orden), y lo
    declaro como límite en el informe.
