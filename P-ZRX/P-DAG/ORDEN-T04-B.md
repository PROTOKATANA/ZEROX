# ORDEN-T04-B — Nonce por clave en el oráculo del estado DAG y reexportación

- **ID:** T04-B. **Fecha:** 2026-09-26. **Director:** Claude. **Ejecutor:** DeepSeek. Se lanza tras
  T01-D.
- **Zona (única escribible):** `/home/katana/zeo/ZEROX/P-ZRX/P-DAG/T04/`.
- **Motivo:** FORMATO v0.1 (F-15, nonce por clave de garantía) ya está en el oráculo T01 (T01-D). T04
  incluye el módulo de T01 por `include`; hay que comprobar que todo sigue valiendo en el DAG y
  reexportar los vectores con el nonce para el diferencial de W06a.
- **Pregunta falsable:** «Con F-15, IE-1…IE-6 siguen sin fallos, una operación de garantía repetida en
  dos bloques fusionados se aplica una sola vez (la segunda se descarta con `ErrNonce`), y los
  vectores reexportados se releen sin discrepancias.»

## Decisiones del director

1. No cambies la semántica de T01 ni de T04 salvo lo que F-15 exige en modo fusión: una operación con
   nonce distinto del esperado **se descarta** con motivo `ErrNonce` (contrato DAG §3, fila de
   transacciones que no validan).
2. Casos dirigidos nuevos (resultado construido a mano): la misma operación de retiro en dos bloques
   hermanos fusionados (se aplica la primera en orden `C-GD-05`; la segunda, descartada); dos
   operaciones de la misma clave con nonces `n` y `n+1` en bloques hermanos en orden inverso al
   `C-GD-05` (la de `n+1` se descarta si se aplica primero); repetición tras una reorganización.
3. Reexporta `resultados/vectores-estado-dag-v0.1.txt` con el formato de T04 más `nonce=` en las líneas
   `TX` de depósito, retiro y liberación y en `GAR`; `.sha256` en formato `sha256sum`; relectura
   independiente con 0 discrepancias. Conserva los ficheros v0.
4. `Pkg.test()` y `run.jl --seed 0x5a5a --replicas 200` vuelven a pasar.

Presupuesto 1 h 30 min, 1 hilo, 8 GiB. **Prohibido Python.** Sección «T04-B» en `INFORME.md` y
`PROGRESO.md`; `HORAS.log`. DeepSeek `deepseek-flash`, esfuerzo `high`; LINEO; nada fuera de `T04/`;
sin commit ni push; sin secretos. Entrada congelada `P-ZRX/P-DAG/ENTRADA-T04-B.sha256`.

## Lanzamiento

    cd /home/katana/zeo/ZEROX/P-ZRX/P-DAG/T04 && \
    ( set -a; . /home/katana/torio/deepseek-harness/.env >/dev/null 2>&1; set +a; \
      node /home/katana/torio/deepseek-harness/apps/cli/lib/bin.js --profile headless \
      "Orden T04-B. Lee íntegro /home/katana/zeo/ZEROX/P-ZRX/P-DAG/ORDEN-T04-B.md y la «Corrección v0.1» de /home/katana/zeo/ZEROX/P-ZRX/P-FORMATO/FORMATO-v0.md, y cúmplelo. Lee /home/katana/zeo/ZEROX/V-ZRX/LINEO.md antes de escribir código. Si detectas una falta de definición, infórmala antes de editar." \
      > ../T04-B-dsh.stdout 2> ../T04-B-dsh.stderr )
