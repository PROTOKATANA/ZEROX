# Faltas de definición detectadas en ORDEN-W07c / ESQUEMA-REGISTRO-v1 — informe previo a editar

**Fecha:** 2026-09-26 (hora real en `HORAS.log`). **Ejecutor:** DeepSeek (`deepseek-flash`, high).
**Regla aplicada:** ORDEN-W07c §5 («si falta una, para e informa **antes de editar**»). Se informa y se
adopta la lectura mínima, literal y determinista que sigue; ninguna de estas lagunas contradice la orden,
todas son huecos de precisión. Si el director corrige alguna, se re-ejecuta V1–V5 y se actualiza el informe.

| # | Hueco | Lectura adoptada |
|---|---|---|
| 1 | §3.4 no dice qué evento tomar si un `hash` tiene dos `bloque_producido`/`bloque_minado` en A (o B lo admite dos veces), ni cómo contar los duplicados. | Producción de A = evento más temprano por `(reloj_pared_ns, reloj_ns, nº de línea)`; admisión de B = la más temprana igual. Se cuentan y publican duplicados. (En los v0 reales de W06d4 no hay duplicados: A 306, B 218, C 304 hashes producidos, todos distintos y 0 compartidos entre nodos.) |
| 2 | §3.4 manda contar las latencias negativas pero no dice si entran en p50/p95/máx. | Entran sin exclusión; además `latencias.tsv` publica `negativos` por par. |
| 3 | §3.6 enumera las columnas de `metricas.tsv` como `n, ausentes, p50, p95, max, unidad`, sin columna de métrica ni de ámbito. | Columnas: `metrica, ambito, n, ausentes, p50, p95, max, unidad`. Necesario para contener latencias por par y total y métricas por nodo en una tabla. |
| 4 | §0/§3.2 piden contar campos ausentes «por métrica» sin definir el denominador. | `ausentes` = nº de eventos candidatos (o de pares, en latencia) de esa métrica cuyo campo requerido falta. El conjunto candidato queda tabulado en `INFORME.md` §Cobertura. |
| 5 | §3.5 no cubre nodos sin `cambio_punta`, <2 nodos, empates de reloj ni episodios que no reconvergen. | Participan sólo nodos con ≥1 `cambio_punta`; <2 o intervalo vacío ⇒ divergencia **no medida** (no 0). Orden `(reloj_pared_ns, reloj_ns, nº línea)`. Episodio sin coincidencia posterior dentro del intervalo ⇒ `truncada=1`, duración hasta el fin (censurada). |
| 6 | §3.6 «tramos de 500» sin borde. | Tramo `k = fld(n_bloques_dag, 500)`, etiqueta `[500k, 500k+499]`. |
| 7 | §2/§3 no fijan agregación de CPU/RSS/E/S/disco ni de dónde sale `CLK_TCK`. | `CLK_TCK` de `<dir>/EJECUCION.txt`; si falta, 100 (USER_HZ) y se declara. `utime/stime` y `read/write` son acumulados ⇒ diferencias entre muestras consecutivas por `reloj_pared_ns`; CPU = `Δticks/CLK_TCK/Δs` (s/s); RSS = valores; disco = último `disco_datos_bytes`. CSV en `<dir>/recursos-<nodo>.csv` (literal de §3.6). |
| 8 | §3 dice «duración del reinicio y de la puesta al día … parcial» en v0, pero los v0 no traen `reinicio_completo`. | `arranque_ns(nodo) = pared(fase=limpio) − pared(fase=inicio)` con los dos `arranque`; se marca parcial/v0. |
| 9 | Un registro con unos nodos v1 y otros v0. | Nodo v1 ⇔ algún `arranque` trae `version_esquema`. La disponibilidad real de cada métrica se decide por presencia de campo, no sólo por versión (los v0 reales difieren: sólo A trae `bloque_red_rechazado`/huérfanos). |
| 10 | §3.6 pide `rechazos.tsv` «por etapa y motivo»; en v0 falta `etapa` y el `motivo` embebe el hash. | Agrupar por (`etapa` tal cual, `motivo` exacto). No se normaliza el motivo: no se inventa taxonomía. |
| 11 | Entorno: la orden fija `JULIA_DEPOT_PATH=<zona>/.julia-depot:`. | En esta máquina una entrada final vacía resuelve a los depósitos de la instalación de juliaup, **no** a `/home/katana/.julia`. Se usa `JULIA_DEPOT_PATH=<zona>/.julia-depot:/home/katana/.julia` (respaldo de sólo lectura) y se registra el comando exacto. |
| 12 | «el nombre de modelo que devuelve la API» que pide §5. | No se lee `~/.dsh` ni secretos. Si el harness no lo expone por variable de entorno, `INFORME.md` declara `deepseek-flash` (high) como el de la orden y anota que no se verificó por API sin tocar configuración secreta. |
| 13 | §3.4 «por par de nodos y total» y §3.6 `latencias.tsv` no fijan columnas. | `latencias.tsv`: `nodo_a, nodo_b, producidos, admitidos, no_admitidos, negativos, n, p50, p95, max` (ns). `metricas.tsv` repite `latencia_propagacion_ns` en ámbito `total` y por par. |

**Nada de esto se resolvió eligiendo métricas distintas** de las del §3 del esquema ni de la orden: sólo se
fijó el detalle determinista que faltaba. Las decisiones quedan señaladas como tales en `INFORME.md`.
