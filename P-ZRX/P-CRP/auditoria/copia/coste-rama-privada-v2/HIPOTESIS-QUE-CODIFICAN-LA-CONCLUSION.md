# CRP-v0.2 · Hipótesis que codifican la conclusión

Estos supuestos, si se fijan **por definición**, vuelven tautológico el resultado y **no cuentan
como evidencia transferida**. Se listan para que ninguna cifra derivada de ellos se lea como
hallazgo del protocolo.

| # | Supuesto | Qué tautologiza | Tratamiento en v2 |
|---|---|---|---|
| H1 | `λ(s,SR) = s·λ₀·SR/SR₀` y `w ∝ 1/SR` a la vez | la "cancelación" `tasa × peso = cte`. No es una demostración: es la consecuencia de dos definiciones elegidas. | No se usa como teorema. La probabilidad discreta se deriva de las reglas PoAS (distancia circular, `sd ≤ SR/2`, chunks ganadores) y se conserva la fórmula exacta con suelos. |
| H2 | Cuota multistream `Sα/(1−α+Sα)` | el umbral `1/(S+1)`. Testear la misma fórmula no demuestra que `S` flujos se sumen. | Separado en el **control escalar** (acredita la identidad del toy) y el **escenario candidato R-FIN-5** (máximo de ramas, no suma). |
| H3 | `sr_adversario = sr0/K` fijado desde la API | el efecto de varianza por `SR`. | Prohibido: el `SR` del perfil candidato es **derivado** por RCE desde el pasado; el oráculo de la asociación DAG→cohorte se declara. |
| H4 | Ramas iid de igual tasa | `1 − E[F(W_pub)^S]`. | Solo en el control sintético; el escenario real usa máximos medidos y cotas de unión. |
| H5 | Independencia entre `W_pub` y las `W_i` | la identidad del máximo. | Declarada; no se presenta como propiedad medida del DAG. |
| H6 | `d` como entero de bloques | el resultado con granularidad `g`. | Corregido: `d` en unidades de trabajo; `z=g·d`. |
| H7 | Identidad billete = oportunidad | toda §7.2. | Cimiento supuesto (TAREAS §2.2); depende de CBE y C-HDR-03/04, no demostrado aquí. |
| H8 | `p+q=1`, paso ±1 por evento | la ruina clásica. | Baseline declarado; el DAG usa pesos variables y varios bloques por slot. |
| H9 | Desactivar R-FIN-5 y sumar todo en GHOSTDAG | el contrafactual aditivo. | Declarado **inexacto**: GHOSTDAG no suma ramas incompatibles. |

**Regla:** ninguna afirmación de seguridad del informe se apoya en H1–H5 sin declararlo.
