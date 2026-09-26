# analisis-artefacto — recuento del artefacto de ids (T04-D)

Instrumento **de solo análisis** para la decisión 3 de `ORDEN-T01E-T04D`: contar
cuántas transacciones de los vectores v0.2 se descartaban porque la salida de una
transferencia chocaba con una salida ya existente de una **liberación** (el
artefacto que T01-E elimina con `ID_LIB`), y confirmar que en v0.3 son 0.

- `contar_artefacto.jl` — relectura parametrizada por módulo; compara las líneas
  `DESC` y `SEL` con el fichero exportado y cuenta las colisiones.
- `EstadoDAGViejo.jl` + `t01_viejo/` — copia **de solo lectura** del oráculo
  (T01 con `prox_salida`, el que exportó v0.2) con una instrumentación mínima en
  `crear_utxos!` (`COLISION_LIB_TX`). No escribe nada de T01.
- `EstadoDAGNuevo.jl` + `t01_nuevo/` — copia del oráculo actual (F-18) con la
  misma instrumentación.
- Los ficheros T04 del módulo (`GDR.jl`, `modelo.jl`, `referencia.jl`,
  `generadores.jl`, …) están copiados en esta carpeta para que `include` no salga
  de `T04/`.

Comando (desde `T04/`):

    env -u LD_LIBRARY_PATH JULIA_DEPOT_PATH=$PWD/.julia-depot JULIA_PKG_OFFLINE=true \
      julia --project=. analisis-artefacto/contar_artefacto.jl

Resultado publicado en `resultados/artefacto-v0.2-v0.3.log`. La copia del T01
viejo reproduce el `DESC` de v0.2 con **0 discrepancias**, lo que valida el
recuento.
