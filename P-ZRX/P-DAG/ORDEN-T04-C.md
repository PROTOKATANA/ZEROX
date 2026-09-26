# ORDEN-T04-C — Generador del oráculo DAG con nonce correcto, retiros y liberaciones; vectores v0.2

- **ID:** T04-C. **Fecha:** 2026-09-26. **Director:** Claude. **Ejecutor:** DeepSeek.
- **Zona (única escribible):** `/home/katana/zeo/ZEROX/P-ZRX/P-DAG/T04/`.
- **Motivo:** `REVISION-T04-B`: el generador aleatorio construye los depósitos PoST con `nonce = 0`
  (casi todos se descartan con `ErrNonce`) y nunca genera retiros ni liberaciones. Los vectores v0.1 no
  sirven como fuente del diferencial de W06a.
- **Pregunta falsable:** «Con un generador que construye depósitos, retiros y liberaciones con el nonce
  del estado contra el que se construyen (y una fracción controlada con nonce erróneo), IE-1…IE-6 siguen
  sin fallos y los vectores v0.2 cumplen los mínimos de cobertura de la tabla §3.» Se refuta con un
  fallo de propiedad o con un mínimo incumplido.

## 1. Decisiones del director

1. **Semántica intacta.** No se toca `P-ZRX/P-TRANSICION/T01/` ni la lógica de `EstadoDAG.jl`. Solo
   cambian `src/generadores.jl`, `src/dirigidos.jl`, `exportar.jl`, `run.jl`, `src/lector_vectores.jl`
   (si hace falta) y `test/`. **Si una propiedad IE falla, para:** minimiza el caso, guárdalo en
   `resultados/fallo-T04-C-<n>.txt` e infórmalo; no corrijas el oráculo.
2. **Operaciones del generador** (`generar_dag_aleatorio`), construidas contra `S = A.post[pv]` como
   ahora:
   - tipo elegido entre transferencia, depósito, retiro y liberación **entre los factibles en `S`**
     (retiro: `activo > 0` y sin retirada en curso; liberación: importe vencido > 0 en el `slot` del
     bloque nuevo, con la regla de `aplicar_liberacion!`); pesos de partida 0,35 / 0,30 / 0,20 / 0,15;
   - importe: depósito, el valor de la salida (como ahora); retiro, uniforme en `1:activo`;
     liberación, uniforme en `1:vencido`;
   - `nonce = nonce_de(S, clave)`; con probabilidad **0,10**, un nonce erróneo (`n + 1`, o `n − 1` si
     `n > 0`, al 50 %);
   - puedes subir `npost` hasta 16 si hace falta para alcanzar los mínimos; nada más de la rejilla cambia.
3. **Casos dirigidos nuevos** (resultado construido a mano, como D-1…D-11):
   - **D-12:** retiro y liberación en la rama A, y una transferencia que gasta la salida de la
     liberación en un bloque posterior de A; reorganización a la rama B (sin ellos): la salida de la
     liberación desaparece, la garantía vuelve al estado previo y la transferencia no existe; vuelta a A:
     todo reaparece una sola vez.
   - **D-13:** liberación en un bloque X que, validado en su propio slot `s`, **no** está vencida
     (`inicio + R_slots > s`) y cuyo fusionador Y tiene `slot(Y) ≥ inicio + R_slots`. Documenta qué da
     el oráculo en `Estado(past(Y))` según RD-4 (operación aplicada en el slot del fusionador) y en la
     vista de X; si el contrato admite dos lecturas, **para** e infórmalo antes de fijar el resultado.
4. **Vectores v0.2:** `resultados/vectores-estado-dag-v0.2.txt` con el formato v0.1 (cabecera con la
   versión), `.sha256` en formato `sha256sum` (ruta relativa a `T04/`), relectura independiente con 0
   discrepancias. Conserva v0 y v0.1. `run.jl` escribe `resultados/run-estado-dag-v0.2.log` sin
   sobrescribir los anteriores.
5. `Pkg.test()` y `run.jl --seed 0x5a5a --replicas 200` vuelven a pasar.

## 2. Tabla de cobertura (obligatoria)

`resultados/cobertura-v0.2.txt`, generada por código Julia (no a mano), para los casos **aleatorios**
de los vectores v0.2 y, aparte, para `run.jl`: por tipo (Transferencia, Depósito, Retiro, Liberación)
en bloques PoST, **construidas**, **aplicadas** en `Estado` de la punta seleccionada final y
**descartadas** por motivo; más el número de reorganizaciones que deshacen al menos una operación de
garantía aplicada.

## 3. Mínimos exigidos en los vectores v0.2 (casos aleatorios)

| Medida | Mínimo |
|---|---|
| Depósitos PoST aplicados | ≥ 150 |
| Retiros aplicados | ≥ 100 |
| Liberaciones aplicadas | ≥ 100 |
| `ErrNonce` | ≥ 30 y ≤ 25 % de las operaciones de garantía construidas |
| `ErrDobleGasto` | ≥ 200 |
| Reorganizaciones que deshacen una operación de garantía | ≥ 20 |

Si un mínimo no se alcanza con `npost ≤ 16` y los pesos del §1.2 ajustados, **no** lo rebajes: entrega
la tabla, di cuál falla y por qué.

Presupuesto 1 h 30 min, 1 hilo, 8 GiB. **Prohibido Python.** Sección «T04-C» en `INFORME.md` y
`PROGRESO.md`; `HORAS.log` con `date -Is` real. DeepSeek `deepseek-flash`, esfuerzo `high`; LINEO; nada
fuera de `T04/`; sin commit ni push; sin secretos. Entrada congelada `P-ZRX/P-DAG/ENTRADA-T04-C.sha256`.

## Lanzamiento

    cd /home/katana/zeo/ZEROX/P-ZRX/P-DAG/T04 && \
    ( set -a; . /home/katana/torio/deepseek-harness/.env >/dev/null 2>&1; set +a; \
      node /home/katana/torio/deepseek-harness/apps/cli/lib/bin.js --profile headless \
      "Orden T04-C. Lee íntegros /home/katana/zeo/ZEROX/P-ZRX/P-DAG/ORDEN-T04-C.md y /home/katana/zeo/ZEROX/P-ZRX/P-DAG/REVISION-T04-B.md, y cúmplelo. Lee /home/katana/zeo/ZEROX/V-ZRX/LINEO.md antes de escribir código. Si detectas una falta de definición, infórmala antes de editar." \
      > ../T04-C-dsh.stdout 2> ../T04-C-dsh.stderr )
