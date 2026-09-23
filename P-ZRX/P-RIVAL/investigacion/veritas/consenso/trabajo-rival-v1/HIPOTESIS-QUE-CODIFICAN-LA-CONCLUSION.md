# Hipótesis que codifican la conclusión — TR-v0.1

Cada hipótesis es **falsable** y se declara con su etiqueta. Si una cae, la conclusión que
sostiene cae con ella y se dice cuál.

| # | Hipótesis | Etiqueta | Si es falsa |
|---|---|---|---|
| **H1** | **El espacio es reutilizable entre ramas dentro de la ventana de transferencia**: una misma lectura de disco produce un certificado válido para dos ancestrías que comparten reto (`P-ZRX/P-ANCESTRIA/investigacion/INFORME.md` F1.4). Es lo que hace que `β_d` sume a la privada **sin** restar a la pública. | `derivado de las reglas vigentes` | Con la identidad de billete `IDV-01` (sin `chunk`) el doble uso de una oportunidad **deja evidencia** y `β_d` no aporta peso neto (`P-ZRX/P-PRESTAMO/investigacion/INFORME.md` §3.3): el umbral vuelve a `1/2` y este encargo no tendría objeto. La conclusión de F3–F6 está **condicionada** a que `C-GD-07` siga vigente. |
| **H2** | **El peso de espacio es lineal en el espacio y el de la pata es lineal en los intentos**: `w(B) = ⌊2^128/(SR+1)⌋` (`SPEC.md` C-GD-01) y `blue_work` suma pesos de azules (C-GD-08); con SR fijado por red, la tasa esperada de peso es proporcional al espacio. El trabajo rival `D` (hashes esperados) es lineal en los intentos. | `verificado en fuente` (C-GD-01/C-GD-08) | Si el peso fuese superlineal o el retarget acoplase la pata al rango (R-FIN-13′), las derivadas cambian y hay que rehacer F3/F4. |
| **H3** | **El trabajo rival del atacante en la privada, `ρ_priv`, es una entrada exógena** (no una función de `α`, `β`), y **`ρ ≥ 0`** (trabajo no negativo). En la composición aditiva su efecto es un **desplazamiento de nivel** que cancela en las diferencias; en la multiplicativa, en cambio, **`ρ_pub/ρ_priv` decide el signo de `dV/dθ`**. | `derivado` del modelo adoptado | Si `ρ(α,β)` tuviera estructura —p. ej. el atacante sólo puede comprar hash con su espacio—, el desplazamiento pasa a depender de `β` y hay que resolver el sistema completo (`BASELINE.md` §B.2). Con `ρ < 0` (no físico) la cota `θ_imp ≥ 1/2` deja de valer. |
| **H9** | **En la composición multiplicativa, `ρ_pub > ρ_priv` (el honesto tiene mayoría de trabajo) es lo que hace decrecer `V` con `θ`.** Si el atacante compra hash hasta `ρ_pub ≤ ρ_priv`, la pata no diluye o empeora el umbral. | `derivado` (forma cerrada `V = [β_d+β_x(1+k)]/(1+k)`, `k = (ρ_pub/ρ_priv)^{θ/(1−θ)}`) | Si el atacante **no** pudiera comprar hash, la dilución con `θ < 1/2` sería real y F6 cambiaría a «sí existe punto intermedio»; el modelo de amenaza de Katana dice que sí puede. **Es la hipótesis que decide F6 en la multiplicativa.** |
| **H4** | **La pata no cambia quién cobra ni el conjunto pagable**: el PoW entra como peso (aditivo/multiplicativo) o como condición de validez (umbral), pero no altera R-FIN-8′ ni R-FIN-13′. | `propuesto` (condición de diseño) | Si la pata redefiniese el conjunto pagable, cambia el retarget y con él el reparto honesto: el modelo de espacio de `P-PRESTAMO` deja de aplicarse tal cual. |
| **H5** | **Un reintento de la pata cuesta del presupuesto rival**: elegir otro conjunto de padres para cambiar el reto PoW exige hashes nuevos, del mismo recurso que se reparte. Es la razón por la que el **26,8941 %** de «trunks» (`research/dag-poas-ancla-de-finalidad.md:313-319`) **no** se traslada. | `derivado` para PoW; `no determinado` para una implementación DAG concreta | Si el reto de la pata pudiera re-muestrearse **gratis** (p. ej. el peso dependiera sólo de una etiqueta elegible y no del nonce), reaparece el grinding con `c = 1`, `φ₁ = e` y el descarte del 26,8941 % **sí** aplicaría. Ese es el vector a vigilar en F5. |
| **H6** | **Coste**: el ploteo medido es `83,608 s/GiB` (CPU 32 hilos, histórico) y `69,363 s/GiB` (GTX 1070); la tasa de hash medida del repo es `500 blake3 / 27,5 µs` por hilo. `P_plot`, `T_vida` y `e_hash` son **supuestos** declarados, no medidas. | `medido` (ploteo, hash/s) + `estimado` (vatios, J/hash, vida) | El orden de magnitud de F5 depende de `e_hash`; se publica la sensibilidad en `resultados/F5b-sensibilidad-ehash.tsv`. |
| **H7** | **Modelo de amenaza de Katana**: un ente con mucha capacidad **paga** la pata. El coste se trata como absoluto; «no compensa» no es un argumento de seguridad. | `propuesto` (instrucción del encargo) | Si el atacante **no** pudiera pagar la pata, la compuerta lo detendría por coste — pero eso es «caro», no «imposible», y no cambia la frontera de espacio (F4). |
| **H8** | **Control**: `θ = 0` reproduce `α* = (1 − β_d − 2β_x)/2` exacto en `Rational{BigInt}`. Se comprueba contra la bisección de `g` (ruta independiente), no contra la propia fórmula. | `demostrado` (test) | Si falla, el modelo está mal y **no se sigue**. |

## Hipótesis que **no** se usan

- **No se usa el puente espacio → tasa**: `α`, `β_d`, `β_x` son fracciones de **espacio**; el puente
  no existe en ningún instrumento (`P-ZRX/P-CRP/auditoria/DEFECTOS.md` C1). El coste de F5 es
  aparte y no entra en F3/F4.
- **No se usa Monte Carlo**: el modelo es afín/racional y se resuelve exacto. No hay semilla que
  fijar en F1–F4, F6; la semilla de `run.jl` sólo etiqueta la corrida.
- **No se recalcula el 26,8941 %**: es una entrada congelada del encargo (§1), no una medición
  propia.
- **No se fija** `θ`, `β_d`, `β_x`, `α`, `ρ`, `c`, la dificultad ni ningún parámetro del SPEC.
