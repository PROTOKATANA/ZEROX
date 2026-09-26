# ORDEN-T01-D — Nonce por clave de garantía en el oráculo de transición (FORMATO v0.1)

- **ID:** T01-D. **Fecha:** 2026-09-26. **Director:** Claude. **Ejecutor:** DeepSeek. Se lanza
  cuando T01-C haya entregado.
- **Zona (única escribible):** `/home/katana/zeo/ZEROX/P-ZRX/P-TRANSICION/T01/`.
- **Motivo:** `P-ZRX/P-FORMATO/FORMATO-v0.md` §«Corrección v0.1» (F-15): las operaciones de garantía
  sin entradas eran repetibles. El oráculo debe modelar el **nonce por clave** para que el motor Rust
  corregido se valide contra él.
- **Pregunta falsable:** «Con F-15 en el oráculo, toda operación de garantía con nonce distinto del
  esperado se rechaza con `ErrNonce`, una operación repetida nunca se aplica dos veces, y todo lo
  demás (X-01…X-20, I-1…I-7) sigue pasando en la rejilla reducida.»

## Decisiones del director (no las cambies)

1. `Garantia` gana `nonce_siguiente::UInt64` (0 al crearse). Las `Tx` de tipo `Deposito`, `Retiro` y
   `Liberacion` ganan `nonce::UInt64`. Al aplicar una de ellas para la clave `P`: si
   `nonce ≠ nonce_siguiente[P]` ⇒ `ErrNonce` (nombre nuevo del enum `Err`); si coincide, se aplica y
   `nonce_siguiente[P] += 1`. El undo lo restituye. Un depósito a una clave sin registro crea el
   registro con `nonce_siguiente = 0` antes de comprobar.
2. **Orden de comprobación:** el nonce se comprueba **antes** que el resto de reglas de la operación
   (una operación con nonce equivocado da `ErrNonce`, no otro error).
3. Los generadores asignan nonces correctos a toda operación honesta; X-01…X-20 no cambian de
   resultado. Añade casos dirigidos (≥ 30 cada uno, fases PoW y PoST): **repetición** de un retiro y
   de una liberación ya aplicados; nonce saltado (`+1`); nonce viejo; dos operaciones de la misma
   clave en el mismo bloque con nonces `n, n+1` (válidas) y `n, n` (la segunda `ErrNonce`).
4. Reexporta con el mismo formato, añadiendo el campo `nonce=` a las líneas `TX` de esas tres
   operaciones y `nonce=` a cada línea `GAR`:
   `resultados/vectores-transicion-v0.1.txt` (mismos 2 055 casos base regenerados) y
   `resultados/vectores-transicion-negativos-v0.1.txt` (los de T01-C más los de repetición), cada uno
   con su `.sha256` en formato `sha256sum`. Relectura independiente: 0 discrepancias. Conserva los
   ficheros v0 sin tocar.
5. Vuelve a pasar `test/runtests.jl` completo y `run.jl --seed 0x5a5a --replicas 50 --rejilla reducida`.

## Verificación y límites

Recuento por error en el informe (incluido `ErrNonce`), determinismo por hash, sección «T01-D» en
`INFORME.md` y `PROGRESO.md`, `HORAS.log`. Presupuesto 1 h 30 min, 1 hilo, 8 GiB. **Prohibido
Python.** DeepSeek `deepseek-flash`, esfuerzo `high`; LINEO; nada fuera de `T01/`; sin commit ni
push; sin secretos. Entrada congelada: `P-ZRX/P-TRANSICION/ENTRADA-T01-D.sha256`, al empezar y como
último paso. Si una regla del contrato choca con F-15, **para** e infórmalo.

## Lanzamiento

    cd /home/katana/zeo/ZEROX/P-ZRX/P-TRANSICION/T01 && \
    ( set -a; . /home/katana/torio/deepseek-harness/.env >/dev/null 2>&1; set +a; \
      node /home/katana/torio/deepseek-harness/apps/cli/lib/bin.js --profile headless \
      "Orden T01-D. Lee íntegros /home/katana/zeo/ZEROX/P-ZRX/P-TRANSICION/ORDEN-T01-D.md y la «Corrección v0.1» de /home/katana/zeo/ZEROX/P-ZRX/P-FORMATO/FORMATO-v0.md, y cúmplelo. Lee /home/katana/zeo/ZEROX/V-ZRX/LINEO.md antes de escribir código. Si detectas una falta de definición, infórmala antes de editar." \
      > ../T01-D-dsh.stdout 2> ../T01-D-dsh.stderr )
