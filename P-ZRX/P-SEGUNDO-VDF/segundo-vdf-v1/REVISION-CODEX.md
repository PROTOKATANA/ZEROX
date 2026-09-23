# Revisión independiente — SDV-v1.1, 2026-09-23

Se inspeccionaron código, artefactos originales, REV-v1.0, primitiva Rust y reglas destino. Los resultados previos, incluidos sus documentos, están preservados en `resultados/historico-deepseek-2026-09-23/`. Esta auditoría conserva una sola copia en `P-ZRX/P-SEGUNDO-VDF/segundo-vdf-v1/` por instrucción posterior del usuario. Las conclusiones de protocolo siguen pendientes.

| Afirmación original | Evidencia comprobada | Veredicto corregido |
|---|---|---|
| Dos líneas AES anulan la reducción | `revelacion_paralela=true` omitía `Lrev/ρ`; el control 0 % equivale a revelación instantánea. Con agenda causal finita, `I=4666`: `V_sin=9974,60`, `V_causal=7174,60`. | Refutada **en el modelo**; el efecto protocolario sigue inconcluso. |
| «2 adversarias frente a 3 honestas» | `⌈Lrev/I⌉=2` cuenta caudal de una revelación/época; falta el PoT principal, latencia y candidatos de chunk. REV-v1.0 ya consideraba línea paralela con latencia. | Comparación de recursos inválida como prueba de ataque. |
| q99 `9280→6528`, `19072→16256` | El artefacto original y el regenerado a `0x5a5a` dicen `9280→6464`, `19008→16192`. | Cifras corregidas; q99 mixto separado de `V_max` determinista. |
| Frontera `I≈4767` satisface `ρ_max=2,5` | Exacto: `I_max=4666`, `ρ*(4666)=5858/2343`; `ρ*(4767)=11817/4787<5/2`. Máximo factible con `I` entero bajo criterio cerrado: `3713/198` en `I=376`. | Fila histórica no cumple; `√352,5` solo cota continua necesaria. |
| `--seed` reproduce todas las tablas aleatorias | `escenarios.jl` fijaba `0x5a5a`; ahora CLI pasa la semilla. Repetirla reproduce cuerpos; cambiarla modifica `ESCENARIOS` y `SEMILLA` mixtos. | Corregido y comprobado. |
| Benchmark 2/4/8/16 hilos | El bucle anterior usaba todos los hilos del proceso para cualquier argumento `nthreads>1`. Nuevas mediciones arrancaron cinco procesos `--threads=N,0`. | Escalado anterior retirado; usar `BENCH-CORREGIDO.txt`. |
| Proyecto Julia congelado | `Manifest.toml` original contenía el paquete local `RevelacionV1` de otra auditoría y `project_hash` desfasado; `Pkg.status()` avisaba. | `Pkg.resolve()` offline sustituyó solo la entrada local y el hash; versiones de dependencias intactas. Original conservado. |
| Basta exponer `aes::create/verify_sequential` | API pública `NonZeroU32`, nueva clave por `prove`; internas también usan `u32` por tramo. `T=1456230516000` nominal requiere al menos 43 segmentos internos. | Hace falta segmentación de clave fija, enlaces y vectores; coste real pendiente. |
| `C-FLU-14` sigue sin AES con segundo VDF | `C-POT-08` ordena flujo antes de caché/AES; `C-FLU-10` dependería de salida adicional no acreditada. | Orden y circularidad pendientes; falta contexto anterior a la inyección. |
| Las series de anclas prueban ataques DAG | No se genera `Chn(V_j(B))`, PoAS/PoT, padres ni consistencia de flujo. | Solo agendas abstractas; no trazas DAG válidas acreditadas. |

## Reproducción ejecutada

Proyecto Julia aislado con `JULIA_DEPOT_PATH=/tmp/segundo-vdf-julia-depot:/home/katana/.julia`, `OPENBLAS_NUM_THREADS=1`, `JULIA_PKG_PRECOMPILE_AUTO=0` y `../../../veritas/julia.sh --project=.`: tras el traslado, `test/runtests.jl` dio **236/236** con `--threads=1,0` y **237/237** con `--threads=4,0` (un control adicional prohíbe etiquetar dos hilos en un proceso de cuatro); `run.jl --modo todo --replicas 64 --seed 0x5a5a` tardó **4,62 s** tras JIT con cuatro hilos y captura de `Pkg.status()`; oráculo racional 384 casos, `Δτ=0`; controles externos error <0,05 slots. La traza de agenda prueba `b≥r`, `f-b=Lrev/ρ`, `E≥max(c,f)` y ausencia de solape por línea. Una prueba retrasa el chunk hasta después de la decisión y exige que la línea espere todos sus bytes; otra comprueba que incluso el control instantáneo espera ese chunk. El control C9 detecta supresión indebida de latencia. `cargo test -p zx-pot --locked --offline`: 5 tests, incluidos los 32 vectores diferenciales.

Reproducción de semillas (cuerpo sin encabezado de fecha, SHA-256): `ESCENARIOS` con `0x5a5a` `7679466b076f6adad0abc6de15720db29bb3dac4363212758baf834c03b63b39`; con `0x5a5b` `8a5e3bc9288d47b1925612202456fe099f8de8c5e64c3a107036cec8eb03d085`, repetida idéntica. Tras usar media de máximos para el patrón mixto, `SEMILLA` con `0x5a5a` `a02e06eb1c5cb55de8e1a834c3523e0696361fc8012d92d95751151c162d1e70`; con `0x5a5b` `a26012e31cb47ec04a0d9ff1e5b59695d01a7228f38493362bf061c1124debf3`; vuelta a `0x5a5a` reprodujo el primero.

Benchmark con procesos reales `1/2/4/8/16` hilos: barrido `R=256`, 12 valores de `ρ`, `360,85/190,91/119,23/73,61/61,35 ms`; checksum serial/paralelo idéntico dentro de cada proceso. Kernel individual: mediana 0,144–0,146 ms, 2 asignaciones/64 B. Son medidas de esta máquina y corrida, no del AES largo.

## Pendientes que impiden un veredicto de seguridad

Validar trazas con C-FLU-03/04/14/21 y PoAS/PoT; fechar todos los bytes del chunk de cada candidato y su decisión real; modelar especulación sobre variantes y agenda óptima; medir velocidad de hardware adversario y segunda cadena de clave fija con vectores; acreditar su salida antes de derivar flujo y caché; medir red y traducir `V` a riesgo de finalidad. **Resultado global: inconcluso.**
