# REVISIÓN T01-E — id de la salida de la liberación como en F-18 (oráculo T01)

**Revisor:** Claude (director). **Fecha:** 2026-09-26. **Ejecutor:** DeepSeek, 05:02–05:18 (orden
`ORDEN-T01E-T04D`, parte T01). **Veredicto: SUPERADO.** La parte T04-D no se ejecutó: **error de
lanzamiento del director** (el sandbox de `dsh` solo permite escribir bajo el directorio de
lanzamiento y lo lancé desde `P-TRANSICION`); el ejecutor lo detectó, no rodeó la restricción y dejó
el plan escrito. Se relanza T04-D desde su zona.

## Comprobado por el director

- `ENTRADA-T01E-T04D.sha256` 5/5. Cambios solo en `T01/`.
- `sha256sum -c` de `vectores-transicion-v0.2.txt` y `…-negativos-v0.2.txt` (rutas relativas a `T01/`):
  coinciden. Relecturas: 2 055 y 3 914 casos, 0 discrepancias. `run-reducida-50-T01-E.log`:
  `SIN FALLOS` (I-1…I-7 en 0).
- `ID_LIB(clave, nonce, importe) = 2⁶² + clave·2⁴⁰ + nonce·2²⁰ + importe`, rangos comprobados
  (`ErrDesbordamiento` fuera de rango); ids explícitos `< 2⁶²`; `prox_salida` eliminado del estado.

## Lo que revela

En la base v0.1, **1 434 de 2 055 casos** cambian: el contador `prox_salida` coincidía con el
siguiente id explícito del generador y muchas transferencias se descartaban con `ErrDobleGasto` al
**construir** la historia (transferencias exportadas 3 826 → 5 809). Ningún `RES`, `SEL` ni `GAR`
cambia. El artefacto afectaba ya al oráculo de la transición, no solo al del DAG, y el espejo de
`prox_salida` del arnés de W02b lo reproducía. Negativos: 25 casos menos de la subfamilia
`neg-nonce-dos-nn` (224 → 199), por divergencia del generador; el resto idéntico.
