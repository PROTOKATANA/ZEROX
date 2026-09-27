# Escenarios de medición de 0.0.1 (W07) y lo que el nodo debe exponer (W06d)

**Fecha:** 2026-09-26. **Firma:** Claude (director). **Estado:** especificación de diseño; se ajusta
cuando exista el nodo. Origen: `AUTO-ZRX.md` §8 (latencia, recursos, tasas de error, ataques y fallos
especificados) y `P-ZRX/PLAN-0.0.1.md` §1.

**Alcance honesto:** procesos reales en `localhost`, un solo reloj, sin latencia de red real salvo la
que se inyecte. **No** mide una red pública adversarial (`AUTO-ZRX.md` §7): cada resultado se etiqueta
**medición real reproducida** con su máquina, carga y semilla, y ninguno se extrapola a producción.

## 1. Lo que el nodo tiene que exponer (requisitos para W06d)

1. **Registro estructurado** (una línea JSON por evento, reloj monotónico en ns y reloj de pared):
   bloque recibido (par, hash, familia, bytes), verificación por etapa (PoW; PoT; PoAS; firma; estado)
   con duración, admitido o rechazado (motivo exacto), transacciones descartadas (motivo), cambio de
   punta seleccionada, profundidad de reorganización, bloque producido (slot, padres, tiempo desde el
   inicio del slot), eventos de par (conexión, penalización, límite alcanzado), arranque y reinicio
   (duración de la repetición).
2. **Resumen del estado canónico** consultable (hash del estado de la punta seleccionada: UTXO +
   garantía + emisión) para comparar nodos sin volcar el estado.
3. **Configuración reproducible:** semilla de claves dev, `SR_dev`, `N_dev`, pares, puertos, directorio
   de datos, papel (minero PoW, productor PoST o ambos); negarse a arrancar si la red no es `Red::Dev`
   (`PERFIL-DEV-v0.md` §5).
4. **Herramienta adversarial separada** (binario de pruebas, no un modo del nodo) que habla el
   protocolo `zx-p2p` y envía lo del §3 E-7/E-8.

## 2. Métricas comunes

Latencia de propagación (producción en A → admisión en B: p50, p95, máx.); tiempo de admisión GHOSTDAG **frente a la profundidad del DAG** (IPA B-12: crece con la historia; declarar el límite de duración); tiempo de verificación por
etapa; bloques por slot y padres por bloque; fracción de rojos; número de puntas; CPU, RSS y disco por
nodo (muestreo cada 1 s de `/proc`); tasa de rechazos por motivo; divergencia (slots en que los nodos
no comparten punta seleccionada) y tiempo hasta converger.

## 3. Escenarios

| ID | Escenario | Inyección | Resultado exigido | Se mide |
|---|---|---|---|---|
| E-1 | Arranque y corte | 3 nodos desde el génesis dev minan, depositan `≥ q` cada uno y cruzan el corte | los 3 fijan el **mismo** terminal `T` y producen bloques PoST válidos | tiempo al corte, hashrate PoW por nodo, tiempo al primer bloque PoST |
| E-2 | Régimen PoST | 30 min de producción con `SR_dev` calibrado (≈ 1 bloque por slot) | sin rechazos de bloques honestos | todas las métricas del §2 |
| E-3 | Convergencia | en reposo tras E-2 | mismo `SEL` y mismo resumen de estado en los 3 | tiempo hasta converger |
| E-4 | Muerte y reinicio | `SIGKILL` a un nodo en fase PoST; rearranque | reabre sin corrupción, repite, se pone al día; estado igual al de los pares | duración de la repetición y de la puesta al día |
| E-5 | Llegada tardía | un 4.º nodo arranca tras ≥ 500 bloques | sincroniza desde el génesis (PoW por localizador, DAG por padres) al mismo estado | tiempo de IBD, bytes transferidos |
| E-6 | Partición y reunión | `{A}` / `{B, C}` durante M slots (ambos lados producen); reunión. Variante E-6b: partición **durante la fase PoW** cerca del corte | tras reunir, un único `SEL` y estado; descartes con motivo; en E-6b, un único `T` según FC-3 | profundidad de reorganización, tiempo a converger, transacciones descartadas |
| E-7 | Entradas inválidas | desde la herramienta adversarial: PoW con nonce malo; PoST con prueba PoAS mala, PoT malo, firma mala, coinbase mayor que el subsidio, padres inexistentes en ráfaga, operación de garantía repetida, mensaje sobredimensionado | cada una rechazada con su motivo, sin cambio de estado; el par penalizado según los límites `C-NET` | coste de CPU por entrada inválida antes del rechazo (amplificación) |
| E-8 | Equivocación | la misma clave firma dos bloques PoST del mismo slot | **se registra** qué ocurre; `C-EVP` está inactivo en 0.0.1: no hay castigo y se declara como límite. **Nota del director (2026-09-27): superado; SL-4 activó el castigo y `ORDEN-W07b` exige E-8 con castigo activo (rige la orden).** | ambos bloques, su color y su efecto en recompensas |
| E-9 | Retención del terminal | un minero retiene el bloque que cruzaría el corte y lo publica tarde | descriptivo (A-07 abierto): qué `T` fijan los nodos y cuándo | retraso del corte, reorganizaciones |

Cada escenario: 3 repeticiones con semillas distintas (fijadas y registradas), receta de un comando,
registros crudos conservados con `sha256`, y resultado por repetición (no solo la media).

## 4. Lo que 0.0.1 no mide (se dice en el informe)

Relevo de transacciones (0.0.1 incluye las propias de cada nodo), latencia de red WAN, más de ~5
nodos, adversario con más espacio o más hash que los honestos (solo simulado: T02, IPA X), sectores
Filecoin (`SEC-0`), evidencia y castigo (`C-EVP`/`C-SLA` inactivos).
