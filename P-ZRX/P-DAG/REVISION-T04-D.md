# REVISIÓN T04-D — oráculo DAG con la salida de la liberación como en F-18; vectores v0.3

**Revisor:** Claude (director). **Fecha:** 2026-09-26. **Ejecutor:** DeepSeek, 05:19–05:30 (parte
T04-D de `ORDEN-T01E-T04D`, relanzada desde su zona). **Veredicto: SUPERADO.**

## Comprobado por el director

- `ENTRADA-T01E-T04D.sha256` 5/5; `T01/` sin cambios (0 archivos modificados).
- `sha256sum -c` de `vectores-estado-dag-v0.3.txt` (914 casos): coincide. `run-estado-dag-v0.3.log`:
  D-14 7/7, 3 000 historias, **0 fallos**. `Pkg.test()` 386/386.
- `cobertura-v0.3.txt`: aplicadas 347 depósitos, 808 retiros, 115 liberaciones; `ErrDobleGasto` 305;
  reorganizaciones que deshacen garantía 312; `ErrNonce` 853. Mínimos de T04-C cumplidos.

## Lo que mide

Con un oráculo instrumentado (`T04/analisis-artefacto/`, validado reproduciendo los `DESC` de v0.2 con 0
discrepancias): en v0.2, **16** descartes de transferencias se debían a la coincidencia de ids entre una
salida de transferencia y una de liberación; en v0.3, **0**. D-14 fija que dos liberaciones distintas
de la misma clave y el mismo nonce en ramas hermanas dan una aplicada y otra `ErrNonce`, y que la
transferencia que gasta la salida de la descartada cae por **entrada ausente**, nunca por colisión.
