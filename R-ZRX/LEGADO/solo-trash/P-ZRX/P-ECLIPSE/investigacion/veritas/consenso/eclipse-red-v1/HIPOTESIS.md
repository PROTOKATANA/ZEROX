# HIPÓTESIS — `eclipse-red-v1`

Supuestos del instrumento, cada uno con su etiqueta y su consecuencia. El autoexamen adversarial
—qué pasaría si se eligiera al revés— está en `HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md`, que es
donde el encargo lo pide.

## Del oráculo heredado (se conservan porque el control los necesita)

| # | Hipótesis | Etiqueta | Fuente |
|---|---|---|---|
| H-A | `λ = 1 bloque/s`, `Δ = 4 s` nominal, `k = 30`, `mp = 15`, `msl = 180` | `verificado en fuente` | 11b `informe.md` §encabezado, `r8c_sim.py:24` |
| H-B | El atacante ve todo al instante y no paga `Δ` | `verificado en fuente` | `r8c_sim.py:33-37` (modelo del artículo) |
| H-C | La víctima **no** corre timelord propio (variante (i)) | `propuesto` | 11b §A.1, coherente con `CLAUDE.md` |
| H-D | Los bloques de la víctima **sí llegan** a la red honesta con `Δ` | `propuesto` | caso más favorable al atacante que sigue siendo coherente |
| H-E | `S_max = 150` como **medida** (R-FIN-1a), **no** como filtro de admisión | `verificado en fuente` | `r8c_gd.add` no comprueba `s_max`; el puerto pasa `s_max = typemax` para no cambiar el DAG |
| H-F | Orden de candidatos `(−bw, id)`, **sin `sd`**, con el `sp` de consenso recalculado con `sd` | `verificado en fuente` | `r8c_sim._padres` + `r8c_gd._key` |
| H-G | `rojo_V` = fuera del blueset de la vista pública **final** | `propuesto` | definición de 11b; el 0,77/0,75 de 11b §A.0 depende de esto |

## Del régimen vigente (lo nuevo)

| # | Hipótesis | Etiqueta | Consecuencia si es falsa |
|---|---|---|---|
| H-H | La `Δ` de hoy es la de `DMS-v0.1`: p99 **0,26–0,45 s** (cabecera 812 B) y **0,26–0,60 s** (rejilla) | **`medido` en simulación**, NO en red | Cambia toda magnitud de F2. La no monotonía con `Δ` prohíbe interpolar |
| H-I | El peso por `SR` usa `SR = solution_distance` del bloque | `propuesto` | Es la magnitud disponible en el simulador; `C-GD-01` exige que el `SR` sea el rango validado, que aquí se modela como `sd` |
| H-J | La equivalencia `SR = 0` ⟺ peso por conteo | **`demostrado`** y comprobado | Si fallara, la reutilización de GDR para el control sería ilegítima |

## De los sensores

| # | Hipótesis | Etiqueta | Consecuencia si es falsa |
|---|---|---|---|
| H-K | La frontera de PoT es **secuencial** (`C-POT-01`) y un slot retrasado la atasca | `verificado en fuente` (regla) | Sin ella, la cola de E1 sería la marginal y `B` bajaría |
| H-L | Cola del retardo honesto: lognormal (la que pide el encargo) y Pareto, ambas ajustadas a mediana y p99 | `propuesto` | `B` va de ~21 s a ~1 422 s. **Por eso no se fija `B`** |
| H-M | Retardos iid entre slots | `propuesto` | Extrapolar seis órdenes de magnitud más allá del p99 es una hipótesis, no un dato |
| H-N | `s_λ` (inestabilidad de `λ`) entra como `μ = (1−s_λ)·λW` | `propuesto` | **11b no documenta cómo entra**; su columna `s_λ>0` no se reproduce y se anota como defecto |

## De la captura de salientes

| # | Hipótesis | Etiqueta | Consecuencia si es falsa |
|---|---|---|---|
| H-O | Selección **uniforme sin reemplazo** de las `ω` salientes | `propuesto` | Con selección sesgada el requisito cambia en órdenes de magnitud (Heilman: 595 IP frente a 163 000) |
| H-P | El recurso escaso es la **IP/prefijo** | `propuesto` | En `libp2p` el `PeerId` es gratis y **no** es una IP: la cuenta no acota un Sybil |
| H-Q | Un grupo = `/16` IPv4 (o `PrefixBucket` de Kaspa) | `verificado en fuente` | Bitcoin y Kaspa agrupan así; **ZEROX no tiene agrupamiento por prefijo para seleccionar** |

## De la partición de flujo

| # | Hipótesis | Etiqueta | Consecuencia si es falsa |
|---|---|---|---|
| H-R | **La captura de la víctima es TOTAL** (ninguna vía al pasado honesto) | `propuesto`, **CRÍTICO** | Con una sola conexión honesta, **no hay partición**. Es la premisa de F1 y **no está determinada para ZEROX** (ver H-1 del autoexamen) |
| H-S | El atacante retiene el bloque que cruza `T_j` y sus descendientes | `derivado` H-R | Es el mecanismo; retener un bloque es equivalente a cortar el flujo |
| H-T | `slot(I_j) = T_j` para la cota de `E_min` | `derivado` | Es el caso que **minimiza** la duración, luego `E_min = F_slots` es **cota inferior exacta** |
| H-U | `92 ms` por slot de PoT y `1,33–9,86 ms` por salto | `medido` en hardware ajeno | Se **citan**; no se reejecutan. Cambian la cota de `PRESUP_NODO` proporcionalmente |
| H-V | El bloque típico mide 100–200 KB (para el coste en bytes) | `verificado en fuente` (`SPEC.md` §16.3) | Cambia el coste en GB proporcionalmente, no su orden |

## Riesgo de etiqueta ancha, que es el error característico de la serie

`PROMPT.md` §4.5 avisa: *«el error característico de esta serie es el alcance estrecho con etiqueta
ancha»*. Los dos sitios donde este trabajo podría caer en él, y cómo se han acotado:

1. **F1 se apoya en H-R**, que es una **premisa no determinada** para ZEROX. Se declara en la
   **primera línea** del informe, con la condición nombrada, en vez de presentar F1 como
   incondicional. Queda etiquetado `derivado` (la aritmética es correcta) y **no** `demostrado`
   (la premisa no está establecida).
2. **La sección D da una cota SUPERIOR del coste en prefijos.** El atacante no necesita **poseer**
   el prefijo, le basta con que la víctima lo **elija**. Se dice en cada fila; no se presenta como
   «el coste del adversario».
