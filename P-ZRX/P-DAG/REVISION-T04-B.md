# REVISIÓN T04-B — nonce por clave en el oráculo del estado DAG

**Revisor:** Claude (director). **Fecha:** 2026-09-26. **Entrega:** `P-ZRX/P-DAG/T04/` (INFORME §T04-B,
PROGRESO §B, `resultados/*-v0.1.*`), ejecutada 03:27–03:34 por DeepSeek.

## Veredicto

**CUMPLE LA LETRA; NO APTO COMO FUENTE DE W06a.** La pregunta falsable no se refuta (D-9…D-11 correctos,
relectura v0.1 con 0 discrepancias, IE-1…IE-6 sin fallos), pero los vectores v0.1 **perdieron
cobertura** respecto de v0 y la pérdida no se declara. Dos de las causas son errores del director.

## Lo comprobado por el director

- `ENTRADA-T04-B.sha256`: 4/4 coinciden (desde la raíz).
- `sha256` de `vectores-estado-dag-v0.1.txt` = `e8f7a6dc…4b51f`, igual al `.sha256` entregado; v0 intacto
  (`29096f74…af84`).
- T01 sin tocar; cambios solo en `T04/` (9 archivos modificados, 7 nuevos, 0 borrados).
- Recuentos sobre los vectores, con `grep`/`awk`:

| Medida | v0 | v0.1 |
|---|---:|---:|
| Casos | 908 | 911 |
| `DESC … ErrDobleGasto` | 506 | 232 |
| `DESC … ErrNonce` | — | 737 |
| Depósitos en bloques PoST (`TX tipo=Deposito`) | — | 1 466, de ellos **1 464 con `nonce=0`** |
| Retiros / liberaciones en casos **aleatorios** | 0 / 0 | 0 / 0 |
| `run.jl` (mismos 25 380 bloques): descartes | 1 977 | 3 721 |

## Hallazgos

1. **Regresión de cobertura (grave para el uso).** `src/generadores.jl:113` construye los depósitos PoST
   con `tx_deposito(...)` sin `nonce`, es decir, `nonce = 0`. El prefijo PoW ya deposita para las claves
   1 y 2 y deja su `nonce_siguiente ≥ 1`; por tanto **todo** depósito PoST aleatorio de esas claves se
   descarta con `ErrNonce` antes de validar nada más. Los 737 `ErrNonce` y el salto de descartes de
   `run.jl` (1 977 → 3 721) son eso. Efecto: en las historias aleatorias casi ningún depósito PoST se
   aplica, el `ErrDobleGasto` cae a menos de la mitad y las propiedades IE-1…IE-6 dejan de ejercitar la
   aplicación de garantía en fusión. El informe da los 737 como dato sin explicarlos.
2. **Hueco preexistente (error del director).** El generador aleatorio de T04 **nunca** produjo retiros
   ni liberaciones: ni en v0 ni en v0.1 (los 4 retiros de v0.1 son de D-9…D-11). `ORDEN-T04` no lo pedía
   y `REVISION-T04` no lo vio. La aplicación de retiros y liberaciones en fusión, su madurez por slot
   (RD-4) y su undo en reorganización quedan sin propiedad aleatoria.
3. **Causa en la orden (error del director).** `ORDEN-T04-B` decisión 1 («no cambies la semántica…
   salvo lo que F-15 exige») no dijo que el **generador** debía construir las operaciones con el nonce
   del estado contra el que las construye, ni fijó un criterio de cobertura. El ejecutor leyó la
   decisión de forma restrictiva y es una lectura defendible.
4. **Menor.** `run.jl` sobrescribe `resultados/run-estado-dag.log` (la versión v0 sigue en git, `ce3ad35`).

## Lo que vale

D-9 (retiro repetido en hermanos), D-10 (nonces `n`/`n+1` en orden inverso; el descarte no quema el
UTXO) y D-11 (repetición tras reorganización); el formato `nonce=` en `TX` y `GAR`; el lector v0.1.

## Decisión

Se commitea la entrega como evidencia, con los vectores v0.1 marcados **«no usar en W06a»**. Se abre
`ORDEN-T04-C` (generador con nonce correcto, retiros y liberaciones, criterio de cobertura obligatorio,
vectores v0.2). `ORDEN-W06a` pasa a usar v0.2. Lección de método para todas las órdenes de generadores:
**tabla de cobertura por tipo de operación (construidas, aplicadas, descartadas por motivo) con mínimos
exigidos**.
