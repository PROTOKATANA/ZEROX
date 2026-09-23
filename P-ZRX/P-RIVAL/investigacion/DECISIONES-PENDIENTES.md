# DECISIONES-PENDIENTES — P-RIVAL / TR-v0.1

**En una línea: no hay `θ` útil en la composición aditiva y en la de umbral; en la multiplicativa sí
hay dilución con `θ < 1/2`, pero su moneda es la carrera de hash.** Lo que sigue son las bifurcaciones
que la cuantificación deja abiertas, con su coste, y ninguna se recomienda.

En la **aditiva** (principal) el cierre exige `θ > (1+β_d+2β_x)/(2−ρ+β_d+2β_x) ≥ 1/2`, y con el
atacante en mayoría de trabajo (`ρ ≥ 1`) no existe `θ` que cierre; además la pata **empuja** al
atacante a `β_x` (F4) y **reintroduce PoW** (F5.5). En la **multiplicativa**, `V = [β_d+β_x(1+k)]/(1+k)`
con `k = (ρ_pub/ρ_priv)^{θ/(1−θ)}` **decrece con `θ` cuando el honesto tiene mayoría de trabajo**
(`ρ_pub > ρ_priv`), y puede hacerlo mucho (con `ρ_priv/ρ_pub = 1/10`, `θ = 1/2` recorta `V` un 82 % y
sube `α*` de `0,45` a `0,90`); pero `V > 0` para todo `θ` finito y el atacante puede comprar hash.
Todo lo que hay debajo son consecuencias, no recomendaciones; decide Katana.

| # | Bifurcación | Qué cierra | Coste | Etiqueta |
|---|---|---|---|---|
| **D1** | **No añadir la pata** (seguir con PoST puro, `θ = 0`) | nada nuevo: deja el hueco que motivó el encargo | ninguno; conserva el tablero honesto y el PoW retirado | `derivado` |
| **D2** | **Cerrar el doble farmeo por identidad**, no por peso: adoptar `IDV-01` (billete sin `chunk`, con `piece_offset`) | el doble uso de una oportunidad **deja evidencia** y `β_d` no aporta peso neto; el umbral vuelve a `1/2` por construcción | toca `C-GD-07`; hoy `IDV-01` está marcada **condicionada** (`veritas/consenso/identidad-disponibilidad-v1/CONTRATO-VALIDACION.md` §1); no lo decide este trabajo (`P-PRESTAMO` F3 §3.3) | `derivado` + `verificado en fuente` |
| **D3** | **Cerrar por castigo** (la vía de `P-PRESTAMO`/`P-CLAVE`/`P-TASA`), con la pata fuera | el umbral en horizonte largo, si el castigo es creíble | exige `κq > 0`, evidencia, y **regresividad** medida (`P-TASA` §2.3 da `τ_min = f*·(λIPTh−c_b)/n_extra` y §4.2 la carga `(f*/f)·(…)`: la granja pequeña paga `f*/f`); no lo reabre este encargo | `derivado` |
| **D4** | **Adoptar la pata con `θ ≥ 1/2` en la aditiva** (el único rango que cierra) | el doble farmeo, por imposibilidad (`α* > 1`) **si** el honesto gana además la carrera de hash (`ρ < 1`) | ZEROX pasa a **PoW mayoritario**: se reintroduce la minería retirada (`MIGRACION.md:84-101`), todo granjero debe hashear (≈5,6 núcleos por 100 TiB a `θ = 0,5`; ≈51 a `θ = 0,9`), y entra el diferencial ASIC de una función de *throughput* (F5.3) | `derivado` + `estimado` |
| **D5** | **Adoptar una pata pequeña (`θ < 1/2`) en la aditiva** | **nada** del doble farmeo: la ventaja es invariante o creciente | reintroduce PoW, obliga a hashear al granjero doméstico, **desplaza a `β_x`** y baja el umbral el doble; coste sin contrapartida para el fin declarado | `derivado` |
| **D6** | **Definir la dificultad / el anclaje de la pata, si se explorara igualmente** | la condición de rivalidad: el reto **debe** comprometer la ancestría (si no, hereda la ventana de transferencia y no es rival) | serializa el pipeline del productor (`padres → reto → hash → bloque`) y abre la elección de mergeset/color de GHOSTDAG; mitigaciones en `C-GD-10` y `C-GD-11` (con cinco `<<PENDIENTE>>`) | `derivado de las reglas vigentes`; **no medido** |
| **D7** | **Adoptar la composición multiplicativa con `θ < 1/2`** | **diluye** (no cierra) la ventaja: `V = [β_d+β_x(1+k)]/(1+k)`, decreciente con `θ` si `ρ_pub > ρ_priv` | exige que el honesto **gane la carrera de hash** (mayoría de trabajo) y que la mantenga; el modelo de amenaza permite al atacante comprarla, y con `ρ_pub ≤ ρ_priv` la pata **empeora** el umbral; `V` nunca llega a 0 para `θ` finito; el resto de costes de D4 aplican | `derivado` + `estimado` |

## Lo que **no** es una decisión de este encargo

- **Fijar `θ`**: no se fija; el resultado dice que en la aditiva no hay valor útil y que en la
  multiplicativa el valor depende de una carrera de hash que este trabajo no cuantifica.
- **Fijar `β_d`, `β_x`, `α`, `ρ`, `c` ni la dificultad**: son entradas del modelo.
- **Recomendar adoptar o retirar PoW**: `PROMPT.md` §8 lo prohíbe expresamente.
- **Decidir la identidad de billete** (`C-GD-07` frente a `IDV-01`) ni la credibilidad de `κ`: son
  decisiones de otros encargos; aquí sólo se dice que **sin ellas** la pata no cierra.

## Pendientes que más pueden mover este resultado

1. **La distribución real de `ρ_pub/ρ_priv`** (ventaja de trabajo del honesto frente al atacante):
   **es la magnitud que decide F6 en la composición multiplicativa** y no está medida en ZEROX. Sin
   ella no se puede decir si hay un `θ < 1/2` útil.
2. **`C-GD-11` (*bounded merge depth*)**, con cinco `<<PENDIENTE>>`: sin él no se sabe si el grinding
   de padres de §5.4 es acotable. Es el pendiente que más puede mover F5.
3. **El puente espacio → tasa** (`P-ZRX/P-CRP/auditoria/DEFECTOS.md` C1, ausencia documentada para
   v0.2/v0.3): no existe; F5 es coste aparte.
4. **`e_hash`, `P_plot`, `T_vida` y las potencias de disco**: supuestos declarados; la sensibilidad
   está en `resultados/F5b-sensibilidad-ehash.tsv` y `F5c-disco.tsv`.
