# CRP-v0.2 · Matriz de validez por escenario

Cada traza se clasifica `Válida`, `Inválida`, `Pendiente` o `Contrafactual`. Una regla ausente
**nunca** se resuelve localmente para obtener `Válida`.

| # | Escenario | Reglas aplicadas | Observador | Clasificación | Por qué |
|---|---|---|---|---|---|
| 1 | Baseline analítico ±1 (flujo compatible, sin rojos) | aritmética + carrera | — | **Válida (demostrado/derivado)** | forma cerrada y DP exacta coinciden |
| 2 | SPEC actualmente escrito | C-HDR-06 `Pendiente`; flujo no cerrado | veterano/nuevo | **Pendiente** | primer dato ausente: ventana del controlador |
| 3 | DAG con red (GDR-v0.2 + vistas locales) | C-GD-01…09, C-ORD-01…03 | veterano | **Válida (medido condicionado)** | rojos y anticonos reales; sin C-GD-11 |
| 4 | Escenario candidato R-FIN-5 | R-FIN-5 estructural + GDR | veterano | **Válida estructural / Pendiente cripto** | `PotOrigin`/`N(s)` no autenticados por fuente |
| 5 | Contrafactual aditivo sin filtro de flujo | suma de ramas | — | **Contrafactual (no regla adoptada)** | cuantifica peligro `S·α`, no representa GHOSTDAG |
| 6 | Regímenes corto y largo | reloj/ventana explícitos | veterano/nuevo | **Corto Válido; largo Pendiente** | falta finalidad/`F`/`Δ` |
| 7 | RCE/ARM como controlador | contrato RCE rev2 + fixture | — | **Válida como instrumento / Pendiente como consenso** | asociación DAG→cohorte es oráculo |
| 8 | Sync sucinto | — | nuevo desde génesis | **Pendiente** | no existe en el SPEC |

## Trazas concretas

| Traza | Resultado | Estado |
|---|---|---|
| Empate vs superación estricta (`d`, `T`) | `(q/p)^d` vs `(q/p)^(d+1)` | demostrado |
| Lattice `g`: `d` trabajo ≡ `d·g` retícula | misma probabilidad | demostrado (test) |
| Vector ARM `W=10,N=5` | rango 100→200 en slot 20 | derivado del contrato |
| Ventana vacía Z0 | no agenda; rango 200 en 40 | derivado del contrato |
| Fixture `rojo_k` conocido | `k+3` hermanos ⇒ al menos un rojo | medido (GDR) |
| Fixture cero rojos | `min(k+1,15)` hermanos ⇒ 0 rojos | medido (GDR) |
| Concurrencia calibrada `k=2` | fracción de réplicas con rojo = 1.0; IC (0.912,1.0) | medido |
| Control `k=30` | 0 rojos; IC sup 0.088 (límite unilateral) | medido |
| Control escalar `S` | `α_drift=1/(S+1)`, `g=0` | demostrado |
| Prefijo R-FIN-5 en `slot(X)` | divergencia futura no invalida pasado | demostrado (test) |
| Descriptor sin autenticar | `Pendiente`, nunca `true` | demostrado (test) |
