# ORDEN-T01E-T04D — Id de la salida de la liberación como en F-18, en los oráculos T01 y T04

- **ID:** T01E-T04D. **Fecha:** 2026-09-26. **Director:** Claude. **Ejecutor:** DeepSeek.
- **Zonas escribibles (solo estas dos):** `/home/katana/zeo/ZEROX/P-ZRX/P-TRANSICION/T01/` y
  `/home/katana/zeo/ZEROX/P-ZRX/P-DAG/T04/`.
- **Motivo (`P-ZRX/P-NODO/REVISION-W06a.md`, «Reserva»):** T01 da a la salida de una liberación el id
  `prox_salida` (contador por estado que salta al mayor id explícito + 1). En el DAG, dos ramas pueden
  asignar el mismo id a salidas distintas, o el mismo id a una liberación y a una transferencia, y T01
  descarta con `ErrDobleGasto` algo que en el formato real no colisiona: F-18 pone la salida en
  `(txid, 0)`, y el `txid` es único por contenido (F-15 incluye `clave` y `nonce`). El arnés Rust de
  W06a tuvo que **emular** esas colisiones. Arreglar el contador del generador **no basta**.
- **Pregunta falsable:** «Con el id de la salida de la liberación función inyectiva del contenido de la
  operación, T01 y T04 siguen cumpliendo todas sus propiedades, los vectores reexportados se releen sin
  discrepancias y ninguna transacción se descarta ya por coincidencia de ids entre una liberación y
  otra salida.»

## Decisiones del director

1. **Regla del oráculo (T01, `src/Transicion.jl`):** la salida de una liberación de `clave`, `nonce` e
   `importe` recibe el id `ID_LIB(clave, nonce, importe) = 2⁶² + clave·2⁴⁰ + nonce·2²⁰ + importe`, con
   `clave < 2²⁰`, `nonce < 2²⁰`, `importe < 2²⁰` comprobados (fuera de rango ⇒ error explícito del
   oráculo, nunca un id truncado). Los ids **explícitos** (coinbases, transferencias, cambios) deben ser
   `< 2⁶²` (comprobado en `crear_utxos!`). Se **elimina** `prox_salida` del estado (F-18 lo eliminó del
   motor); si aparece en exportaciones o en la tupla de igualdad, se quita documentándolo. Es la única
   regla que cambia: ningún otro resultado de T01 debería moverse salvo los ids de esas salidas.
2. **T01:** tests del paquete, `run.jl` con su semilla habitual y reexportación de
   `vectores-transicion-v0.2.txt` y `vectores-transicion-negativos-v0.2.txt` (formato v0.1; `.sha256`
   en formato `sha256sum`), relectura independiente con 0 discrepancias. Informa cuántos casos cambian
   respecto de v0.1 y por qué (se esperan solo ids de salidas de liberación y lo que dependa de ellos).
   Conserva los v0 y v0.1.
3. **T04:** sin tocar la lógica de `EstadoDAG.jl` ni el generador salvo lo que exija el punto 1;
   reexporta `vectores-estado-dag-v0.3.txt` y `cobertura-v0.3.txt` con los mismos mínimos de T04-C;
   `run.jl --seed 0x5a5a --replicas 200` y `Pkg.test()`; relectura 0 discrepancias. **Cuenta** cuántas
   transacciones de los vectores v0.2 se descartaban por coincidencia de ids de una liberación (el
   artefacto) y confirma que en v0.3 son 0.
4. Casos dirigidos nuevos en T04: **D-14**, dos liberaciones **distintas** (mismo `nonce`, importes
   distintos) de la misma clave en dos ramas hermanas y una transferencia que gasta la salida de una de
   ellas en un bloque de esa rama: al fusionar las ramas, la segunda liberación se descarta con
   `ErrNonce` y la transferencia se aplica o se descarta según exista **su** salida en
   `Estado(past(B))`, nunca por colisión de ids.

Presupuesto 1 h 30 min, 1 hilo, 8 GiB. **Prohibido Python.** Secciones «T01-E» y «T04-D» en los
`INFORME.md` y `PROGRESO.md` de cada zona; `HORAS.log` con `date -Is` real. DeepSeek `deepseek-flash`,
esfuerzo `high`; LINEO; nada fuera de las dos zonas; sin commit ni push; sin secretos. Entrada
congelada `P-ZRX/P-TRANSICION/ENTRADA-T01E-T04D.sha256`.

## Lanzamiento

    cd /home/katana/zeo/ZEROX/P-ZRX/P-TRANSICION && \
    ( set -a; . /home/katana/torio/deepseek-harness/.env >/dev/null 2>&1; set +a; \
      node /home/katana/torio/deepseek-harness/apps/cli/lib/bin.js --profile headless \
      "Orden T01E-T04D. Lee íntegros /home/katana/zeo/ZEROX/P-ZRX/P-TRANSICION/ORDEN-T01E-T04D.md y /home/katana/zeo/ZEROX/P-ZRX/P-NODO/REVISION-W06a.md, y cúmplelo. Lee /home/katana/zeo/ZEROX/V-ZRX/LINEO.md antes de escribir código. Si detectas una falta de definición, infórmala antes de editar." \
      > T01E-T04D-dsh.stdout 2> T01E-T04D-dsh.stderr )
